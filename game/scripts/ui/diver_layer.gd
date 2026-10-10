class_name DiverLayer
extends Control
## Top layer of the ocean: every diver, and effects (floating "+N" texts,
## tap ripples, confetti, sparkles). The lift in the shaft is LiftView.
## A diver's trip follows its site's cycle: swim from its spot at the cave
## mouth to the vein, dig three times, swim back to the lift's crate at the
## shaft, toss the sack into it and swim back to its spot. Every phase
## starts where the last one ended (poses blend, divers turn around), and
## idle divers (no manager, no tap) doze at that same spot.

const DIVER_SCALE := 0.78
const SWIM_OUT_END := 0.14
const DIG_END := 0.56
const SWIM_BACK_END := 0.8
const DROP_END := 0.88
## Where each diver works, from the deposit: x, y (px) and facing. The
## first two work the vein (one standing, one hovering above), the others
## get small veins of their own further left.
const SPOTS: Array[Vector3] = [Vector3(-58, 0, 1), Vector3(-44, -80, 1), Vector3(-150, 0, 1), Vector3(-200, -80, 1), Vector3(-250, -2, 1)]
## Divers hovering at work lean forward so the tool reaches down.
const HOVER_TILT := 0.45
## The arms of a worker walking in an air world (volcano, acid, moon):
## WorkerLooks draws "walk"; the pose dict carries the stride phase.
const WALK_ARM := "walk"
## Height of the scaffold walkway the high spots stand on in air worlds.
const SCAFFOLD_Y := -84.0
## How far past the edge of the view a site is still drawn.
const _SITE_MARGIN := 60.0
static var _KEYS: Array[String] = _make_keys()

var world: World
var _t := 0.0
var _kick := 0.0
var _kick_rate := 1.8
## id (site * 10 + diver) -> DiverSprite; the effects' sprite on top.
var _sprites := {}
var _fx: FxSprite
var _fx_shown := false
var _tint := Color.WHITE
var _floaters: Array[Dictionary] = []
var _ripples: Array[Vector3] = []
var _parts: Array[Dictionary] = []
var _idle_since := {}
## Diver suit colors from the wardrobe (empty = each depth's own color).
static var suit_paint: Array = []
var _dig_phase := {}
var _trip := {}
## What every diver of the site being drawn shares (see _begin_site).
var _s_key := ""
var _s_style: Dictionary
var _s_ledge := 0.0
var _s_crate := Vector2.ZERO
var _s_dp := Vector2.ZERO
var _s_mood := ""
var _s_wide := 1.0
var _s_rushing := false
var _s_walk := false
## The bought evolution form (GameState.evo), read every frame so a
## purchase shows at once. "world" + "form" go to Chars.diver's pose.
var _s_form := 0
var _rng := RandomNumberGenerator.new()


static func _make_keys() -> Array[String]:
	var out: Array[String] = []
	for i in Balance.DEPTHS.size():
		out.append("d%d" % i)
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx = FxSprite.new()
	_fx.layer = self
	add_child(_fx)


## Rising texts at once are capped: each costs a text draw every frame.
const FLOATERS_MAX := 5


func float_text(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	if _floaters.size() >= FLOATERS_MAX:
		return
	_floaters.append({"pos": pos, "text": text, "color": color, "age": 0.0, "size": 34 if big else 26})


func tap_ripple(pos: Vector2) -> void:
	_ripples.append(Vector3(pos.x, pos.y, 0.0))


func confetti(at: Vector2, count: int) -> void:
	var colors := [Art.GOLD, Art.CORAL, Art.TEAL, Color("ff8fc0"), Art.PURPLE, Art.GREEN]
	for i in count:
		var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
		_parts.append({"kind": "confetti", "pos": at, "vel": Vector2(cos(a), sin(a)) * _rng.randf_range(160, 380),
				"color": colors[i % colors.size()], "age": 0.0, "life": _rng.randf_range(1.0, 1.6), "rot": _rng.randf() * TAU})


func sparkle(at: Vector2, count: int) -> void:
	for i in count:
		var a := TAU * i / count + _rng.randf_range(-0.3, 0.3)
		_parts.append({"kind": "star", "pos": at, "vel": Vector2(cos(a), sin(a)) * _rng.randf_range(80, 160),
				"color": Art.GOLD, "age": 0.0, "life": 0.7, "rot": 0.0})


## A thing flying on an arc from a to b (sacks, coin bags).
## `depth` >= 0 fills a sack with that site's ore.
func throw_item(kind: String, a: Vector2, b: Vector2, color: Color, seconds: float = 0.6, depth: int = -1) -> void:
	_parts.append({"kind": "throw", "item": kind, "a": a, "b": b, "color": color, "age": 0.0, "life": seconds, "pos": a, "vel": Vector2.ZERO, "rot": 0.0, "depth": depth})


func _process(delta: float) -> void:
	_t += delta
	# The flipper kick speeds up in a rush (a phase that adds up, so a rush
	# starting or ending never jumps the legs).
	_kick_rate = Motion.damp(_kick_rate, 3.0 if GameState.is_rushing() else 1.8, 4.0, delta)
	_kick += delta * _kick_rate
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i]["age"] += delta
		if _floaters[i]["age"] > 1.4:
			_floaters.remove_at(i)
	for i in range(_ripples.size() - 1, -1, -1):
		var r := _ripples[i]
		r.z += delta
		_ripples[i] = r
		if r.z > 0.5:
			_ripples.remove_at(i)
	for i in range(_parts.size() - 1, -1, -1):
		var p := _parts[i]
		p["age"] += delta
		if p["kind"] == "throw":
			var f: float = clampf(p["age"] / p["life"], 0.0, 1.0)
			var a: Vector2 = p["a"]
			var b: Vector2 = p["b"]
			var h := clampf(a.distance_to(b) * 0.35, 30.0, 70.0)
			p["pos"] = a.lerp(b, f) + Vector2(0, -sin(f * PI) * h)
			p["rot"] = f * TAU
		else:
			p["vel"] += Vector2(0, 520.0 if p["kind"] == "confetti" else 0.0) * delta
			p["vel"] *= Motion.drag(0.985, delta)
			p["pos"] += p["vel"] * delta
			p["rot"] += delta * 8.0
		if p["age"] > p["life"]:
			_parts.remove_at(i)
	var tick := World.anim_tick()
	_update_divers(tick)
	if tick:
		queue_redraw()
	# Effects move every frame (a few cheap shapes): flying sacks stay smooth.
	if not (_parts.is_empty() and _ripples.is_empty() and _floaters.is_empty()) or _fx_shown:
		_fx_shown = not (_parts.is_empty() and _ripples.is_empty() and _floaters.is_empty())
		_fx.queue_redraw()
	if self_modulate != _tint:
		_tint = self_modulate
		for c in get_children():
			(c as CanvasItem).self_modulate = _tint


# --- Divers as sprites ---------------------------------------------------------------
#
# Every diver is its own little canvas item (DiverSprite) under this layer.
# Where it is changes every frame (just its transform: smooth at any frame
# rate), its pose is redrawn on the scene's animation ticks (World's frame
# schedule: every frame on PCs, every other one on phones). So on a phone
# the divers glide at the screen's full rate while their drawing costs what
# it did at the half rate.

class DiverSprite extends Node2D:
	var layer: DiverLayer
	var id := 0
	var st := {}

	func _draw() -> void:
		layer._paint_diver(self, st)


class FxSprite extends Node2D:
	var layer: DiverLayer

	func _draw() -> void:
		layer._draw_fx(self)


func _sprite(id: int) -> DiverSprite:
	var sp: DiverSprite = _sprites.get(id)
	if sp != null:
		return sp
	sp = DiverSprite.new()
	sp.layer = self
	sp.id = id
	sp.self_modulate = self_modulate
	_sprites[id] = sp
	add_child(sp)
	# Keep them in id order (later divers of a site in front), the effects on top.
	var at := 0
	for c in get_children():
		if c is DiverSprite and (c as DiverSprite).id < id:
			at = c.get_index() + 1
	move_child(sp, at)
	move_child(_fx, -1)
	return sp


## Places every diver for this frame and hands the redraw to its sprite.
func _update_divers(redraw: bool) -> void:
	var gs := GameState
	var view := world.visible_rect()
	var seen := {}
	for i in Balance.DEPTHS.size():
		var key: String = _KEYS[i]
		if not gs.is_open(key):
			continue
		var n: int = gs.divers(key)
		var p: float = Motion.progress(key)
		if p < 0.0:
			if not _idle_since.has(key):
				_idle_since[key] = _t
		else:
			_idle_since.erase(key)
		var row_top := World.row_y(i)
		if row_top > view.end.y + _SITE_MARGIN or row_top + World.ROW_H < view.position.y - _SITE_MARGIN:
			continue
		_begin_site(i, key)
		for j in n:
			var st := _diver_state(i, j, p, view)
			if st.is_empty():
				continue
			var id := i * 10 + j
			var sp := _sprite(id)
			seen[id] = true
			sp.position = st["pos"]
			if not sp.visible:
				sp.visible = true
				sp.st = st
				sp.queue_redraw()
			elif redraw:
				sp.st = st
				sp.queue_redraw()
	for id in _sprites:
		if not seen.has(id):
			var sp: DiverSprite = _sprites[id]
			if sp.visible:
				sp.visible = false


func _draw() -> void:
	var gs := GameState
	var view := world.visible_rect()
	# Only one "Tap!" bubble at a time, so the screen stays calm; during
	# the tutorial its own hand is the only pointer (two hands confused
	# new players).
	var hinted := Progress.tutorial_step < Tutor.DONE
	for key in ["lift", "boat", "plant"]:
		if gs.cycle_progress(key) < 0.0 and not gs.has_manager(key):
			var has_ore: bool = gs.pit > 0.0 if key == "lift" else (gs.hold > 0.0 if key == "boat" else gs.dock > 0.0)
			if has_ore:
				var at: Vector2
				match key:
					"lift":
						at = world.lift.hint_pos()
					"boat":
						at = world.surface.boat_world_pos() + Vector2(10, -150)
					_:
						at = world.surface.plant_world_pos() + Vector2(70, -185)
				if not hinted and view.grow(60.0).has_point(at):
					hinted = true
					_draw_tap_hint(at)
	for i in Balance.DEPTHS.size():
		var key: String = _KEYS[i]
		if not gs.is_open(key):
			continue
		var n: int = gs.divers(key)
		var p: float = Motion.progress(key)
		# A site far off screen has nothing to draw (a diver never strays
		# more than a row's height from its ledge).
		var row_top := World.row_y(i)
		if row_top > view.end.y + _SITE_MARGIN or row_top + World.ROW_H < view.position.y - _SITE_MARGIN:
			continue
		_begin_site(i, key)
		_draw_veins(i, n, view)
		if p < 0.0 and not gs.has_manager(key):
			var hint_at := Vector2(world.rows[i].deposit_pos().x - 40, World.row_y(i) + 70)
			if not hinted and view.has_point(hint_at):
				hinted = true
				_draw_tap_hint(hint_at)



## Tap ripples, flying things and floating numbers, over the divers.
func _draw_fx(ci: CanvasItem) -> void:
	for r in _ripples:
		var f := r.z / 0.5
		Art.arc(ci, Vector2(r.x, r.y), 12.0 + f * 70.0, 0, TAU, 28, Color(1, 1, 1, 0.7 * (1.0 - f)), 5.0 * (1.0 - f) + 1.0)
	_draw_parts(ci)
	for fl in _floaters:
		# Pops up with a little overshoot, rises and slows, fades at the end.
		var age: float = fl["age"]
		var a := clampf((1.4 - age) / 0.4, 0.0, 1.0)
		var pop := 0.45 + 0.55 * Motion.ease_out_back(age / 0.32, 2.2)
		var rise := 56.0 * Motion.ease_out_cubic(age / 1.4)
		Art.push(ci, fl["pos"] - Vector2(0, rise), 0.0, Vector2(pop, pop))
		Art.text(ci, Vector2.ZERO, fl["text"], fl["size"], Color(fl["color"], a), 7)
		Art.pop(ci)


func _draw_parts(ci: CanvasItem) -> void:
	for p in _parts:
		var a: float = snappedf(clampf(1.0 - (p["age"] - p["life"] * 0.7) / (p["life"] * 0.3), 0.0, 1.0), 0.05)
		match p["kind"]:
			"confetti":
				Art.push(ci, p["pos"], p["rot"], Vector2(1.0, absf(sin(p["rot"])) + 0.2))
				Art.flat(ci, Art.rrect_pts(Rect2(-5, -3, 10, 6), 1, 1), Color(p["color"], a))
				Art.pop(ci)
			"star":
				Art.push(ci, p["pos"], p["rot"])
				Art.toon(ci, Art.star_pts(Vector2.ZERO, 8, 3.5, 4), Color(p["color"], a), 1.5, 0.0)
				Art.pop(ci)
			"throw":
				# Stretches a little along the arc, squashes as it lands.
				var f: float = clampf(p["age"] / p["life"], 0.0, 1.0)
				var sq := 1.0 + 0.12 * sin(f * PI) - 0.18 * maxf(0.0, f - 0.85) / 0.15
				Art.push(ci, p["pos"], sin(p["rot"]) * 0.4, Vector2(2.0 - sq, sq))
				Chars.item(ci, p["item"], Vector2(0, -12), p["color"], int(p.get("depth", -1)))
				Art.pop(ci)


func _draw_tap_hint(at: Vector2) -> void:
	# The bubble bobs softly; the hand below it taps on its own rhythm.
	var bob := (0.5 - 0.5 * cos(_t * 3.2)) * 8.0
	var text := tr("TAP_HINT")
	var font := UiTheme.heavy_font()
	var fs := 24
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	Art.push(self, at + Vector2(0, -bob))
	var box := Rect2(Vector2(-tw / 2.0 - 16, -44), Vector2(tw + 32, 46))
	var tail := PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, 14)])
	Art.toon(self, Art.union([Art.rrect_pts(box, 16), tail]), Art.WHITE, 3.0, 0.3)
	Art.text(self, Vector2(0, -12), text, fs, Art.INK, 0)
	Art.pop(self)
	PointerArt.draw(self, at + Vector2(10, 40), _t, not Settings.reduce_motion, -0.45, 0.8)


## Small veins of ore for the third diver on (the first two share the big
## deposit): they appear as the site hires more divers.
func _draw_veins(site: int, n: int, view: Rect2) -> void:
	var ledge := _s_ledge
	var dp := _s_dp
	var vis := view.grow(80.0)
	var walk := _s_walk
	for j in range(1 if walk else 2, mini(n, SPOTS.size())):
		var sp := _spot(j)
		var high := sp.y < -20.0
		if walk and not high and j < 2:
			continue
		var at := Vector2(dp.x + sp.x + 50.0, ledge + (sp.y + (0.0 if walk else 12.0) if high else 0.0))
		if not vis.has_point(at):
			continue
		# The vein glows and sways slowly: drawn once per quarter second.
		# (each vein on its own beat, so they don't all redraw in one frame)
		var tq := int(_t * 4.0 + ((site * 5 + j * 3) % 8) / 8.0)
		var key := hash([40, site, j, tq, walk])
		Art.push(self, Vector2(at.x, ledge))
		if not Art.cache_begin(self, key):
			if high and walk:
				# Air worlds: a wooden scaffold with a ladder; the worker
				# climbs up and digs a vein on the walkway.
				_scaffold(sp.y)
			elif high:
				# A rock pillar holds the vein up where the hovering diver works.
				Art.toon(self, _PILLAR, (Art.DEPTH_STYLE[site]["rock"] as Color).lightened(0.12), 3.0, 0.6)
			OreArt.deposit(self, Vector2(0, at.y - ledge), 30.0 if high else 36.0, site, site * 13 + j, tq * 0.25, 2, false)
			Art.cache_end(self, key)
		Art.pop(self)


## Scaffold under a high spot of an air world, drawn around its vein (the
## worker stands 50 px left of the vein, on top of the ladder).
func _scaffold(top: float) -> void:
	var wood := Color("b07a48")
	var dark := Color("7a4e30")
	if WorldLook.world == "moon":
		wood = Color("aab4c8")
		dark = Color("6c7690")
	for x in [-62.0, 24.0]:
		Art.t_rect(self, Rect2(x, top, 7.0, -top), 2.0, dark, 2.5, 0.6)
	# Ladder where the worker climbs.
	Art.line(self, Vector2(-58, 0), Vector2(-58, top), Art.INK, 7.0)
	Art.line(self, Vector2(-42, 0), Vector2(-42, top), Art.INK, 7.0)
	Art.line(self, Vector2(-58, 0), Vector2(-58, top), wood, 3.5)
	Art.line(self, Vector2(-42, 0), Vector2(-42, top), wood, 3.5)
	var y := -10.0
	while y > top + 4.0:
		Art.line(self, Vector2(-58, y), Vector2(-42, y), wood, 3.0)
		y -= 14.0
	# Walkway.
	Art.t_rect(self, Rect2(-74, top, 112, 9), 3.0, wood, 3.0, 0.7)
	Art.line(self, Vector2(-70, top + 4.5), Vector2(34, top + 4.5), dark, 1.5)


## The pose of a diver at point p (0..1) of its trip: where it is, which
## way it faces, its arms and what it carries. Every phase begins exactly
## where the previous one ends, so nothing ever jumps.
static func trip_pose(p: float, home: Vector2, spot: Vector2, spot_facing: float, hover: bool, crate: Vector2, swim_bob: float, walk: bool = false) -> Dictionary:
	var sp := Vector3(0, 0, spot_facing)
	# Walking (air worlds): no swim arcs, no bob, no swim lean.
	var arc := 0.0 if walk else 1.0
	if walk:
		swim_bob = 0.0
		hover = false
	var pos: Vector2
	var facing := 1.0
	var turn := 1.0
	var tilt := 0.0
	var move_arm := WALK_ARM if walk else "swim"
	var arm := move_arm
	var arm_from := ""
	var blend := 1.0
	var hit := 0.0
	var carry := false
	var sling := 0.0
	var kick_amp := 1.0
	var emo := "happy"
	var trip: String = "out"
	if p < SWIM_OUT_END:
		var f := p / SWIM_OUT_END
		var e := _ease(f)
		var b := _bump(f)
		var settle := smoothstep(0.6, 1.0, f) if hover else 0.0
		pos = _path(home, spot, e, walk) + Vector2(0, -sin(f * PI) * (22.0 + (34.0 if sp.z < 0.0 else 0.0)) * arc + swim_bob * maxf(b, settle))
		tilt = lerpf(0.5 * b * arc, HOVER_TILT, settle)
		kick_amp = maxf(b, 0.6 * settle)
		arm_from = "idle"
		blend = smoothstep(0.0, 0.2, f)
		if sp.z < 0.0:
			turn = cos(PI * smoothstep(0.78, 1.0, f))
	elif p < DIG_END:
		var f := (p - SWIM_OUT_END) / (DIG_END - SWIM_OUT_END)
		trip = "dig"
		pos = spot + (Vector2(0, swim_bob) if hover else Vector2.ZERO)
		facing = sp.z
		tilt = HOVER_TILT if hover else 0.0
		arm = "dig"
		arm_from = move_arm
		blend = smoothstep(0.0, 0.07, f)
		hit = fposmod(f * 3.0, 1.0)
		kick_amp = 0.6 if hover else 0.0
		emo = "focus"
	elif p < SWIM_BACK_END:
		var f := (p - DIG_END) / (SWIM_BACK_END - DIG_END)
		var e := _ease(f)
		var b := _bump(f)
		trip = "back"
		var lift := (1.0 - smoothstep(0.0, 0.4, f)) if hover else 0.0
		pos = _path(spot, crate, e, walk) + Vector2(0, -sin(f * PI) * 22.0 * arc + swim_bob * maxf(b, lift))
		facing = -1.0
		if sp.z > 0.0:
			# Turn around on the spot first.
			facing = 1.0
			turn = cos(PI * smoothstep(0.0, 0.22, f))
		tilt = maxf(0.5 * b * arc, HOVER_TILT * lift)
		carry = true
		arm_from = "dig"
		blend = smoothstep(0.0, 0.22, f)
		kick_amp = maxf(maxf(b, 0.6 * lift), 0.6 * smoothstep(0.75, 1.0, f))
		emo = "joy" if f < 0.3 else "happy"
	elif p < DROP_END:
		var f := (p - SWIM_BACK_END) / (DROP_END - SWIM_BACK_END)
		# At the lift's crate: toss the sack in.
		pos = crate + Vector2(0, -sin(f * PI) * 6.0 * arc)
		facing = -1.0
		arm = "cheer"
		arm_from = move_arm
		blend = smoothstep(0.0, 0.3, f)
		carry = f < 0.45
		kick_amp = 0.6
		emo = "joy"
		trip = "drop_carry" if carry else "drop"
	else:
		var g := (p - DROP_END) / (1.0 - DROP_END)
		trip = "home"
		# Back to the spot at the cave mouth.
		var b := _bump(g, 0.3)
		pos = crate.lerp(home, _ease(g)) + Vector2(0, -sin(g * PI) * 10.0 * arc + swim_bob * b)
		facing = 1.0
		turn = -cos(PI * smoothstep(0.0, 0.3, g))
		tilt = 0.4 * b * arc
		kick_amp = maxf(b, 0.6 * (1.0 - smoothstep(0.0, 0.3, g)))
		if g < 0.5:
			arm = move_arm
			arm_from = "cheer"
			blend = smoothstep(0.0, 0.3, g)
		else:
			arm = "idle"
			arm_from = move_arm
			blend = smoothstep(0.7, 1.0, g)
	return {"pos": pos, "facing": facing, "turn": turn, "tilt": tilt, "arm": arm, "arm_from": arm_from, "blend": blend,
			"hit": hit, "carry": carry, "sling": sling, "kick_amp": kick_amp, "emo": emo, "trip": trip}


static var _PILLAR := Art.smooth_pts(PackedVector2Array([Vector2(-22, 3), Vector2(-14, -30), Vector2(-15, -62), Vector2(-9, -71),
		Vector2(4, -73), Vector2(14, -66), Vector2(13, -34), Vector2(22, 3)]), 3)


## SPOTS[j], spread out a little more in the wide caves of big screens.
func _spot(j: int) -> Vector3:
	var sp: Vector3 = SPOTS[j % SPOTS.size()]
	if sp.x < -100.0:
		sp.x *= _s_wide
	if _s_walk and sp.y < -20.0:
		# Air worlds: no hovering; the worker stands on a scaffold.
		sp.y = SCAFFOLD_Y
	return sp


## From a to b. Swimmers go straight; walkers walk along the floor and
## climb the scaffold ladder (up at the end, down at the start).
static func _path(a: Vector2, b: Vector2, e: float, walk: bool) -> Vector2:
	if not walk or absf(a.y - b.y) < 8.0:
		return a.lerp(b, e)
	if b.y < a.y:
		return Vector2(lerpf(a.x, b.x, smoothstep(0.0, 0.7, e)), lerpf(a.y, b.y, smoothstep(0.7, 1.0, e)))
	return Vector2(lerpf(a.x, b.x, smoothstep(0.3, 1.0, e)), lerpf(a.y, b.y, smoothstep(0.0, 0.3, e)))


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 0 at both ends of a phase, 1 in the middle (lift off, tilt, kick).
static func _bump(f: float, edge: float = 0.25) -> float:
	return smoothstep(0.0, edge, f) * (1.0 - smoothstep(1.0 - edge, 1.0, f))


## Where diver j of a site stands when idle, and where each trip starts.
func home_pos(site: int, j: int) -> Vector2:
	return Vector2(World.CAVE_L + 40.0 + j * 26.0, World.row_y(site) + DepthRow.LEDGE_Y + 2.0)


## The things every diver of a site shares, worked out once per site.
func _begin_site(site: int, key: String) -> void:
	_s_key = key
	_s_style = Art.DEPTH_STYLE[site]
	_s_ledge = World.row_y(site) + DepthRow.LEDGE_Y + 2.0
	_s_crate = LiftView.crate_pos(site)
	_s_dp = world.rows[site].deposit_pos()
	_s_mood = world.mood(key)
	_s_wide = clampf((world.scene_right() - World.CAVE_L) / 340.0, 1.0, 1.8)
	_s_rushing = GameState.is_rushing()
	_s_walk = not WorldLook.is_water()
	var evo = GameState.get("evo")
	_s_form = int(evo) if evo != null else 0


## Diver j of the site begun with _begin_site at cycle progress p: where it
## is and how it looks now ({} when it is off screen), plus what happens
## this frame (a dig's sound, a sack tossed into the crate).
func _diver_state(site: int, j: int, p: float, view: Rect2) -> Dictionary:
	var st := _s_style
	var key := _s_key
	var suit: Color = st["suit"] if suit_paint.is_empty() else suit_paint[j % suit_paint.size()]
	var ore: Color = st["ore"]
	var ledge := _s_ledge
	var home := home_pos(site, j)
	var crate_at := _s_crate
	var crate := Vector2(crate_at.x + 36.0 + j * 6.0, ledge - 4.0)
	var sp := _spot(j)
	var spot := Vector2(_s_dp.x + sp.x, ledge + sp.y)
	var walk := _s_walk
	var hover := sp.y < -20.0 and not walk
	var mood := _s_mood
	var hop := world.hop(key, j)
	var blink := Chars.blinking(_t, site * 3.1 + j * 1.3)
	var rushing := _s_rushing
	var seed := site * 0.7 + j
	var id := site * 10 + j
	if p < 0.0:
		# Dozing at the cave mouth until someone taps.
		var at := home - Vector2(0, hop)
		if not view.grow(60.0).has_point(at):
			return {}
		var idle: float = _t - float(_idle_since.get(key, _t))
		var emo := mood if mood != "" else ("sleepy" if idle > 5.0 else "bored")
		var mark := ""
		if emo == "sleepy" and j == 0:
			mark = "zzz"
		elif mood == "wow" and j == 0:
			mark = "!"
		return {"idle": true, "pos": at, "suit": suit, "ore": ore, "arm": "cheer" if mood == "joy" else "idle", "emo": emo,
				"blink": blink, "t": _t + seed, "site": site, "form": _s_form, "mark": mark}
	# Later divers start a little later and catch up, so they never jump.
	var lag := j * 0.03
	p = clampf((p - lag) / (1.0 - lag), 0.0, 1.0)
	var kick := _kick + seed
	var swim_bob := sin(_t * 4.2 + seed) * 3.0
	var st8 := trip_pose(p, home, spot, sp.z, hover, crate, swim_bob, walk)
	var pos: Vector2 = st8["pos"]
	var facing: float = st8["facing"]
	var turn: float = st8["turn"]
	var tilt: float = st8["tilt"]
	var arm: String = st8["arm"]
	var arm_from: String = st8["arm_from"]
	var blend: float = st8["blend"]
	var hit: float = st8["hit"]
	var carry: bool = st8["carry"]
	var emo: String = st8["emo"]
	var trip: String = st8["trip"]
	var chips := -1.0
	var tip := Vector2.ZERO
	if trip == "dig":
		var phase := hit
		var before: float = _dig_phase.get(id, phase)
		_dig_phase[id] = phase
		var tier := Chars.gear_tier(site)
		tip = pos + (Chars.dig_tip(tier) * DIVER_SCALE * Vector2(facing, 1.0)).rotated(tilt * facing)
		if before < Chars.DIG_IMPACT and phase >= Chars.DIG_IMPACT and view.has_point(tip):
			Sfx.play("dig")
			if randf() < 0.06:
				Sfx.voice("hup", randf_range(1.0, 1.4))
		var busy := 0.22 if Chars.swings(Chars.tool_of(tier)) else 0.3
		if phase >= Chars.DIG_IMPACT and phase < Chars.DIG_IMPACT + busy and view.grow(40.0).has_point(tip):
			chips = (phase - Chars.DIG_IMPACT) / busy
	elif trip == "drop":
		var was: String = _trip.get(id, "")
		if was == "drop_carry" and view.grow(80.0).has_point(pos):
			# Toss the sack into the lift's crate.
			var hand := pos + Vector2(-14, -60) * DIVER_SCALE
			throw_item("sack", hand, crate_at + Vector2(0, -24), ore, 0.3, site)
	_trip[id] = trip
	if not view.grow(80.0).has_point(pos):
		return {}
	if rushing and emo in ["happy", "focus"]:
		emo = "focus"
	if mood != "":
		emo = mood
		if mood == "joy" and arm in ["swim", "idle"] and not carry:
			arm = "cheer"
			arm_from = ""
	pos.y -= hop
	var pose := {"turn": turn, "kick_amp": st8["kick_amp"], "sling": st8["sling"], "world": WorldLook.world, "form": _s_form}
	if walk:
		# HOOK for W-Chars: "walk" is the stride phase for the legs.
		pose["walk"] = fposmod(kick * 0.5, 1.0)
	if arm_from != "" and blend < 1.0:
		pose["arm_from"] = arm_from
		pose["blend"] = blend
	return {"idle": false, "pos": pos, "suit": suit, "ore": ore, "facing": facing, "tilt": tilt, "kick": kick, "arm": arm, "hit": hit,
			"carry": carry, "emo": emo, "blink": blink, "t": _t + seed, "site": site, "pose": pose, "id": id,
			"chips": chips, "tip": tip - pos, "sweat": rushing and j == 0, "turn": turn}


## Draws a diver's state around its sprite's origin (the sprite stands at
## its position).
func _paint_diver(ci: CanvasItem, d: Dictionary) -> void:
	if d.is_empty():
		return
	if d["idle"]:
		Chars.diver(ci, Vector2.ZERO, DIVER_SCALE, d["suit"], 1.0, 0.0, 0.0, d["arm"], 0.0, false, d["ore"], d["emo"], d["blink"], d["t"], d["site"],
				{"world": WorldLook.world, "form": d["form"]})
		match d["mark"]:
			"zzz":
				Chars.mark(ci, "zzz", Vector2(20, -80), _t)
			"!":
				Chars.mark(ci, "!", Vector2(0, -92), _t)
		return
	var facing: float = d["facing"]
	if float(d["chips"]) >= 0.0:
		_draw_chips(ci, d["tip"], d["chips"], d["site"], facing, d["id"])
	Chars.diver(ci, Vector2.ZERO, DIVER_SCALE, d["suit"], facing, d["tilt"], d["kick"], d["arm"], d["hit"], d["carry"], d["ore"], d["emo"],
			d["blink"], d["t"], d["site"], d["pose"])
	if d["sweat"]:
		Chars.mark(ci, "sweat", Vector2(-16 * facing * float(d["turn"]), -76), _t)


## Where diver j of a site is drawn now (the jump checks of test_motion).
func diver_at(site: int, j: int) -> Vector2:
	var key: String = _KEYS[site]
	_begin_site(site, key)
	var p := Motion.progress(key)
	var home := home_pos(site, j)
	var hop := world.hop(key, j)
	if p < 0.0:
		return home - Vector2(0, hop)
	var lag := j * 0.03
	p = clampf((p - lag) / (1.0 - lag), 0.0, 1.0)
	var sp := _spot(j)
	var spot := Vector2(_s_dp.x + sp.x, _s_ledge + sp.y)
	var crate := Vector2(_s_crate.x + 36.0 + j * 6.0, _s_ledge - 4.0)
	var st8 := trip_pose(p, home, spot, sp.z, sp.y < -20.0 and not _s_walk, crate, sin(_t * 4.2 + site * 0.7 + j) * 3.0, _s_walk)
	return (st8["pos"] as Vector2) - Vector2(0, hop)


## Bits of the site's ore flying off the tool, and a flash where it hits.
func _draw_chips(ci: CanvasItem, at: Vector2, f: float, site: int, facing: float, id: int) -> void:
	var tool := Chars.tool_of(Chars.gear_tier(site))
	for k in 4:
		# Thrown back toward the diver and up, then falling.
		var a := -PI * 0.5 - facing * (0.35 + k * 0.32) + sin(id * 1.7 + k) * 0.15
		var sp := 30.0 + 8.0 * ((id + k) % 3)
		var p := at + Vector2(cos(a), sin(a)) * _ease(f) * sp + Vector2(0, f * f * 22.0)
		OreArt.chip(ci, p, 3.4 * (1.0 - f * 0.35), site, f * 6.0 * facing + k)
	var s := 1.0 - f * 0.6
	match tool:
		"laser":
			Art.glow(ci, at, 22.0 * s + 4.0, Color(1, 1, 1, 0.5 * (1.0 - f)), 12)
		"drill":
			Art.glow(ci, at, 16.0, Color(1, 0.95, 0.8, 0.45 * (1.0 - f)), 12)
		"plasma":
			Art.glow(ci, at, 24.0 * s + 4.0, Color(Chars.PLASMA, 0.5 * (1.0 - f)), 12)
		"trident":
			Art.glow(ci, at, 20.0 * s + 4.0, Color(Chars.AQUA, 0.5 * (1.0 - f)), 12)
			Art.arc(ci, at, 6.0 + f * 22.0, 0, TAU, 16, Color(1, 1, 1, 0.6 * (1.0 - f)), 2.0)
		"hammer":
			Art.glow(ci, at, 26.0 * s + 4.0, Color(1, 0.9, 0.5, 0.45 * (1.0 - f)), 12)
			Art.push(ci, at, f * 2.0, Vector2(s, s) * 1.2)
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 14, 4, 4), Color(1, 0.95, 0.7, snappedf(1.0 - f, 0.05)), 1.2, 0.0)
			Art.pop(ci)
		_:
			Art.push(ci, at, 0.0, Vector2(s, s))
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 14, 4, 4), Color(1, 1, 0.8, snappedf(1.0 - f, 0.05)), 1.2, 0.0)
			Art.pop(ci)


func pos_hint(x: float, y: float) -> Vector2:
	return Vector2(x, y - 30.0)
