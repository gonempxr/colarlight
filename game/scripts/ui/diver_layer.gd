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

var world: World
var _t := 0.0
var _floaters: Array[Dictionary] = []
var _ripples: Array[Vector3] = []
var _parts: Array[Dictionary] = []
var _idle_since := {}
## Diver suit colors from the wardrobe (empty = each depth's own color).
static var suit_paint: Array = []
var _dig_phase := {}
var _trip := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func float_text(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
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
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i]["age"] += delta
		_floaters[i]["pos"] += Vector2(0, -46.0 * delta)
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
			p["vel"] *= 0.985
			p["pos"] += p["vel"] * delta
			p["rot"] += delta * 8.0
		if p["age"] > p["life"]:
			_parts.remove_at(i)
	if World.anim_tick():
		queue_redraw()


func _draw() -> void:
	var gs := GameState
	var view := world.visible_rect()
	for i in Balance.DEPTHS.size():
		var key := "d%d" % i
		if not gs.is_open(key):
			continue
		var n: int = gs.divers(key)
		var p: float = gs.cycle_progress(key)
		if p < 0.0:
			if not _idle_since.has(key):
				_idle_since[key] = _t
		else:
			_idle_since.erase(key)
		_draw_veins(i, n, view)
		for j in n:
			_draw_diver(i, j, p, view)
		if p < 0.0 and not gs.has_manager(key):
			var hint_at := Vector2(world.rows[i].deposit_pos().x - 40, World.row_y(i) + 70)
			if view.has_point(hint_at):
				_draw_tap_hint(hint_at)
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
				if view.grow(60.0).has_point(at):
					_draw_tap_hint(at)
	for r in _ripples:
		var f := r.z / 0.5
		Art.arc(self, Vector2(r.x, r.y), 12.0 + f * 70.0, 0, TAU, 28, Color(1, 1, 1, 0.7 * (1.0 - f)), 5.0 * (1.0 - f) + 1.0)
	_draw_parts()
	for fl in _floaters:
		var a := clampf(1.4 - fl["age"], 0.0, 1.0)
		var pop := 1.0 + maxf(0.0, 0.25 - fl["age"]) * 2.0
		Art.push(self, fl["pos"], 0.0, Vector2(pop, pop))
		Art.text(self, Vector2.ZERO, fl["text"], fl["size"], Color(fl["color"], a), 7)
		Art.pop(self)


func _draw_parts() -> void:
	for p in _parts:
		var a: float = snappedf(clampf(1.0 - (p["age"] - p["life"] * 0.7) / (p["life"] * 0.3), 0.0, 1.0), 0.05)
		match p["kind"]:
			"confetti":
				Art.push(self, p["pos"], p["rot"], Vector2(1.0, absf(sin(p["rot"])) + 0.2))
				Art.flat(self, Art.rrect_pts(Rect2(-5, -3, 10, 6), 1, 1), Color(p["color"], a))
				Art.pop(self)
			"star":
				Art.push(self, p["pos"], p["rot"])
				Art.toon(self, Art.star_pts(Vector2.ZERO, 8, 3.5, 4), Color(p["color"], a), 1.5, 0.0)
				Art.pop(self)
			"throw":
				# Stretches a little along the arc, squashes as it lands.
				var f: float = clampf(p["age"] / p["life"], 0.0, 1.0)
				var sq := 1.0 + 0.12 * sin(f * PI) - 0.18 * maxf(0.0, f - 0.85) / 0.15
				Art.push(self, p["pos"], sin(p["rot"]) * 0.4, Vector2(2.0 - sq, sq))
				Chars.item(self, p["item"], Vector2(0, -12), p["color"], int(p.get("depth", -1)))
				Art.pop(self)


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
	var ledge := World.row_y(site) + DepthRow.LEDGE_Y + 2.0
	var dp: Vector2 = world.rows[site].deposit_pos()
	for j in range(2, mini(n, SPOTS.size())):
		var sp := _spot(j)
		var high := sp.y < -20.0
		var at := Vector2(dp.x + sp.x + 50.0, ledge + (sp.y + 12.0 if high else 0.0))
		if not view.grow(80.0).has_point(at):
			continue
		if high:
			# A rock pillar holds the vein up where the hovering diver works.
			Art.push(self, Vector2(at.x, ledge))
			Art.toon(self, _PILLAR, (Art.DEPTH_STYLE[site]["rock"] as Color).lightened(0.12), 3.0, 0.6)
			Art.pop(self)
		OreArt.deposit(self, at, 32.0 if high else 36.0, site, site * 13 + j, _t, 2, false)


## The pose of a diver at point p (0..1) of its trip: where it is, which
## way it faces, its arms and what it carries. Every phase begins exactly
## where the previous one ends, so nothing ever jumps.
static func trip_pose(p: float, home: Vector2, spot: Vector2, spot_facing: float, hover: bool, crate: Vector2, swim_bob: float) -> Dictionary:
	var sp := Vector3(0, 0, spot_facing)
	var pos: Vector2
	var facing := 1.0
	var turn := 1.0
	var tilt := 0.0
	var arm := "swim"
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
		pos = home.lerp(spot, e) + Vector2(0, -sin(f * PI) * (22.0 + (34.0 if sp.z < 0.0 else 0.0)) + swim_bob * maxf(b, settle))
		tilt = lerpf(0.5 * b, HOVER_TILT, settle)
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
		arm_from = "swim"
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
		pos = spot.lerp(crate, e) + Vector2(0, -sin(f * PI) * 22.0 + swim_bob * maxf(b, lift))
		facing = -1.0
		if sp.z > 0.0:
			# Turn around on the spot first.
			facing = 1.0
			turn = cos(PI * smoothstep(0.0, 0.22, f))
		tilt = maxf(0.5 * b, HOVER_TILT * lift)
		carry = true
		arm_from = "dig"
		blend = smoothstep(0.0, 0.22, f)
		kick_amp = maxf(maxf(b, 0.6 * lift), 0.6 * smoothstep(0.75, 1.0, f))
		emo = "joy" if f < 0.3 else "happy"
	elif p < DROP_END:
		var f := (p - SWIM_BACK_END) / (DROP_END - SWIM_BACK_END)
		# At the lift's crate: toss the sack in.
		pos = crate + Vector2(0, -sin(f * PI) * 6.0)
		facing = -1.0
		arm = "cheer"
		arm_from = "swim"
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
		pos = crate.lerp(home, _ease(g)) + Vector2(0, -sin(g * PI) * 10.0 + swim_bob * b)
		facing = 1.0
		turn = -cos(PI * smoothstep(0.0, 0.3, g))
		tilt = 0.4 * b
		kick_amp = maxf(b, 0.6 * (1.0 - smoothstep(0.0, 0.3, g)))
		if g < 0.5:
			arm = "swim"
			arm_from = "cheer"
			blend = smoothstep(0.0, 0.3, g)
		else:
			arm = "idle"
			arm_from = "swim"
			blend = smoothstep(0.7, 1.0, g)
	return {"pos": pos, "facing": facing, "turn": turn, "tilt": tilt, "arm": arm, "arm_from": arm_from, "blend": blend,
			"hit": hit, "carry": carry, "sling": sling, "kick_amp": kick_amp, "emo": emo, "trip": trip}


static var _PILLAR := Art.smooth_pts(PackedVector2Array([Vector2(-22, 3), Vector2(-14, -30), Vector2(-15, -62), Vector2(-9, -71),
		Vector2(4, -73), Vector2(14, -66), Vector2(13, -34), Vector2(22, 3)]), 3)


## SPOTS[j], spread out a little more in the wide caves of big screens.
func _spot(j: int) -> Vector3:
	var sp: Vector3 = SPOTS[j % SPOTS.size()]
	if sp.x < -100.0:
		var wide := clampf((world.scene_right() - World.CAVE_L) / 340.0, 1.0, 1.8)
		sp.x *= wide
	return sp


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 0 at both ends of a phase, 1 in the middle (lift off, tilt, kick).
static func _bump(f: float, edge: float = 0.25) -> float:
	return smoothstep(0.0, edge, f) * (1.0 - smoothstep(1.0 - edge, 1.0, f))


## Where diver j of a site stands when idle, and where each trip starts.
func home_pos(site: int, j: int) -> Vector2:
	return Vector2(World.CAVE_L + 40.0 + j * 26.0, World.row_y(site) + DepthRow.LEDGE_Y + 2.0)


func _draw_diver(site: int, j: int, p: float, view: Rect2) -> void:
	var st: Dictionary = Art.DEPTH_STYLE[site]
	var key := "d%d" % site
	var suit: Color = st["suit"] if suit_paint.is_empty() else suit_paint[j % suit_paint.size()]
	var ore: Color = st["ore"]
	var row_top := World.row_y(site)
	var ledge := row_top + DepthRow.LEDGE_Y + 2.0
	var home := home_pos(site, j)
	var crate_at := LiftView.crate_pos(site)
	var crate := Vector2(crate_at.x + 36.0 + j * 6.0, ledge - 4.0)
	var dp: Vector2 = world.rows[site].deposit_pos()
	var sp := _spot(j)
	var spot := Vector2(dp.x + sp.x, ledge + sp.y)
	var hover := sp.y < -20.0
	var mood := world.mood(key)
	var hop := world.hop(key, j)
	var blink := Chars.blinking(_t, site * 3.1 + j * 1.3)
	var rushing := GameState.is_rushing()
	var seed := site * 0.7 + j
	var id := site * 10 + j
	if p < 0.0:
		# Dozing at the cave mouth until someone taps.
		var at := home - Vector2(0, hop)
		if not view.grow(60.0).has_point(at):
			return
		var idle: float = _t - float(_idle_since.get(key, _t))
		var emo := mood if mood != "" else ("sleepy" if idle > 5.0 else "bored")
		Chars.diver(self, at, DIVER_SCALE, suit, 1.0, 0.0, 0.0, "cheer" if mood == "joy" else "idle", 0.0, false, ore, emo, blink, _t + seed, site)
		if emo == "sleepy" and j == 0:
			Chars.mark(self, "zzz", at + Vector2(20, -80), _t)
		elif mood == "wow" and j == 0:
			Chars.mark(self, "!", at + Vector2(0, -92), _t)
		return
	# Later divers start a little later and catch up, so they never jump.
	var lag := j * 0.03
	p = clampf((p - lag) / (1.0 - lag), 0.0, 1.0)
	var kick := _t * (3.0 if rushing else 1.8) + seed
	var swim_bob := sin(_t * 4.2 + seed) * 3.0
	var st8 := trip_pose(p, home, spot, sp.z, hover, crate, swim_bob)
	var pos: Vector2 = st8["pos"]
	var facing: float = st8["facing"]
	var turn: float = st8["turn"]
	var tilt: float = st8["tilt"]
	var arm: String = st8["arm"]
	var arm_from: String = st8["arm_from"]
	var blend: float = st8["blend"]
	var hit: float = st8["hit"]
	var carry: bool = st8["carry"]
	var sling: float = st8["sling"]
	var kick_amp: float = st8["kick_amp"]
	var emo: String = st8["emo"]
	var trip: String = st8["trip"]
	if trip == "dig":
		var phase := hit
		var before: float = _dig_phase.get(id, phase)
		_dig_phase[id] = phase
		var tier := Chars.gear_tier(site)
		var tip := pos + (Chars.dig_tip(tier) * DIVER_SCALE * Vector2(facing, 1.0)).rotated(tilt * facing)
		if before < Chars.DIG_IMPACT and phase >= Chars.DIG_IMPACT and view.has_point(tip):
			Sfx.play("dig")
			if randf() < 0.06:
				Sfx.voice("hup", randf_range(1.0, 1.4))
		var busy := 0.22 if Chars.swings(Chars.tool_of(tier)) else 0.3
		if phase >= Chars.DIG_IMPACT and phase < Chars.DIG_IMPACT + busy and view.grow(40.0).has_point(tip):
			_draw_chips(tip, (phase - Chars.DIG_IMPACT) / busy, site, facing, id)
	elif trip == "drop":
		var was: String = _trip.get(id, "")
		if was == "drop_carry" and view.grow(80.0).has_point(pos):
			# Toss the sack into the lift's crate.
			var hand := pos + Vector2(-14, -60) * DIVER_SCALE
			throw_item("sack", hand, crate_at + Vector2(0, -24), ore, 0.3, site)
	_trip[id] = trip
	if not view.grow(80.0).has_point(pos):
		return
	if rushing and emo in ["happy", "focus"]:
		emo = "focus"
	if mood != "":
		emo = mood
		if mood == "joy" and arm in ["swim", "idle"] and not carry:
			arm = "cheer"
			arm_from = ""
	pos.y -= hop
	var pose := {"turn": turn, "kick_amp": kick_amp, "sling": sling}
	if arm_from != "" and blend < 1.0:
		pose["arm_from"] = arm_from
		pose["blend"] = blend
	Chars.diver(self, pos, DIVER_SCALE, suit, facing, tilt, kick, arm, hit, carry, ore, emo, blink, _t + seed, site, pose)
	if rushing and j == 0:
		Chars.mark(self, "sweat", pos + Vector2(-16 * facing * turn, -76), _t)


## Bits of the site's ore flying off the tool, and a flash where it hits.
func _draw_chips(at: Vector2, f: float, site: int, facing: float, id: int) -> void:
	var tool := Chars.tool_of(Chars.gear_tier(site))
	for k in 4:
		# Thrown back toward the diver and up, then falling.
		var a := -PI * 0.5 - facing * (0.35 + k * 0.32) + sin(id * 1.7 + k) * 0.15
		var sp := 30.0 + 8.0 * ((id + k) % 3)
		var p := at + Vector2(cos(a), sin(a)) * _ease(f) * sp + Vector2(0, f * f * 22.0)
		OreArt.chip(self, p, 3.4 * (1.0 - f * 0.35), site, f * 6.0 * facing + k)
	var s := 1.0 - f * 0.6
	match tool:
		"laser":
			Art.glow(self, at, 22.0 * s + 4.0, Color(1, 1, 1, 0.5 * (1.0 - f)), 12)
		"drill":
			Art.glow(self, at, 16.0, Color(1, 0.95, 0.8, 0.45 * (1.0 - f)), 12)
		"plasma":
			Art.glow(self, at, 24.0 * s + 4.0, Color(Chars.PLASMA, 0.5 * (1.0 - f)), 12)
		"trident":
			Art.glow(self, at, 20.0 * s + 4.0, Color(Chars.AQUA, 0.5 * (1.0 - f)), 12)
			Art.arc(self, at, 6.0 + f * 22.0, 0, TAU, 16, Color(1, 1, 1, 0.6 * (1.0 - f)), 2.0)
		"hammer":
			Art.glow(self, at, 26.0 * s + 4.0, Color(1, 0.9, 0.5, 0.45 * (1.0 - f)), 12)
			Art.push(self, at, f * 2.0, Vector2(s, s) * 1.2)
			Art.toon(self, Art.star_pts(Vector2.ZERO, 14, 4, 4), Color(1, 0.95, 0.7, snappedf(1.0 - f, 0.05)), 1.2, 0.0)
			Art.pop(self)
		_:
			Art.push(self, at, 0.0, Vector2(s, s))
			Art.toon(self, Art.star_pts(Vector2.ZERO, 14, 4, 4), Color(1, 1, 0.8, snappedf(1.0 - f, 0.05)), 1.2, 0.0)
			Art.pop(self)


func pos_hint(x: float, y: float) -> Vector2:
	return Vector2(x, y - 30.0)
