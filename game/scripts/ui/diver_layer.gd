class_name DiverLayer
extends Control
## Top layer of the ocean: the dive rope, every diver, and effects
## (floating "+N" texts, tap ripples, confetti, sparkles).
## A diver's trip follows its site's cycle: swim to the vein, dig three
## times, swim back, climb the rope to the raft, drop the sack, dive back.
## Idle divers (no manager, no tap) doze at the cave mouth.

const DIVER_SCALE := 0.78
const SWIM_OUT_END := 0.12
const DIG_END := 0.46
const SWIM_BACK_END := 0.56
const ASCEND_END := 0.78
const DROP_END := 0.84

var world: World
var _t := 0.0
var _floaters: Array[Dictionary] = []
var _ripples: Array[Vector3] = []
var _parts: Array[Dictionary] = []
var _idle_since := {}
## Diver suit colors from the wardrobe (empty = each depth's own color).
static var suit_paint: Array = []
var _dig_phase := {}
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
func throw_item(kind: String, a: Vector2, b: Vector2, color: Color, seconds: float = 0.6) -> void:
	_parts.append({"kind": "throw", "item": kind, "a": a, "b": b, "color": color, "age": 0.0, "life": seconds, "pos": a, "vel": Vector2.ZERO, "rot": 0.0})


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
			p["pos"] = a.lerp(b, f) + Vector2(0, -sin(f * PI) * 70.0)
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
	var deepest := 0
	for i in Balance.DEPTHS.size():
		if gs.is_open("d%d" % i):
			deepest = i
	var view := world.visible_rect()
	# Rope from the raft's pulley down to the deepest open site.
	var rope_top := World.SURFACE_Y - 112.0
	var rope_bottom := World.row_y(deepest) + DepthRow.LEDGE_Y - 4.0
	Art.line(self, Vector2(World.ROPE_X, rope_top), Vector2(World.ROPE_X, rope_bottom), Art.INK, 7.0)
	Art.line(self, Vector2(World.ROPE_X, rope_top), Vector2(World.ROPE_X, rope_bottom), Color("e8c48a"), 3.5)
	var y := rope_top + 30.0
	while y < rope_bottom:
		if y > view.position.y - 20.0 and y < view.end.y + 20.0:
			Art.disc(self, Vector2(World.ROPE_X, y), 3.5, Color("c89a5a"))
		y += 36.0
	Art.t_circle(self, Vector2(World.ROPE_X, rope_bottom), 7, Art.WOOD_DARK, 2.5, 0.0)
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
		for j in n:
			_draw_diver(i, j, p, view)
		if p < 0.0 and not gs.has_manager(key):
			var hint_at := Vector2(world.rows[i].deposit_pos().x - 40, World.row_y(i) + 70)
			if view.has_point(hint_at):
				_draw_tap_hint(hint_at)
	for key in ["boat", "plant"]:
		if gs.cycle_progress(key) < 0.0 and not gs.has_manager(key):
			var has_ore: bool = gs.hold > 0.0 if key == "boat" else gs.dock > 0.0
			if has_ore:
				var at: Vector2 = world.surface.boat_world_pos() + Vector2(10, -150) if key == "boat" \
						else world.surface.plant_world_pos() + Vector2(70, -185)
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
		var a: float = clampf(1.0 - (p["age"] - p["life"] * 0.7) / (p["life"] * 0.3), 0.0, 1.0)
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
				Art.push(self, p["pos"], sin(p["rot"]) * 0.4)
				Chars.item(self, p["item"], Vector2(0, -12), p["color"])
				Art.pop(self)


func _draw_tap_hint(at: Vector2) -> void:
	var bounce := absf(sin(_t * 4.0)) * 10.0
	var text := tr("TAP_HINT")
	var font := UiTheme.heavy_font()
	var fs := 24
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	Art.push(self, at + Vector2(0, -bounce))
	var box := Rect2(Vector2(-tw / 2.0 - 16, -44), Vector2(tw + 32, 46))
	var tail := PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, 14)])
	Art.toon(self, Art.union([Art.rrect_pts(box, 16), tail]), Art.WHITE, 3.0, 0.3)
	Art.text(self, Vector2(0, -12), text, fs, Art.INK, 0)
	# Pointing hand.
	var hand := Vector2(tw / 2.0 + 30, -10)
	Art.t_circle(self, hand, 9, Art.WHITE, 2.5, 0.3)
	Art.t_rect(self, Rect2(hand + Vector2(-3.5, -22), Vector2(7, 18)), 3.5, Art.WHITE, 2.5, 0.0)
	Art.pop(self)


func _draw_diver(site: int, j: int, p: float, view: Rect2) -> void:
	var st: Dictionary = Art.DEPTH_STYLE[site]
	var key := "d%d" % site
	var suit: Color = st["suit"] if suit_paint.is_empty() else suit_paint[j % suit_paint.size()]
	var ore: Color = st["ore"]
	var row_top := World.row_y(site)
	var ledge := row_top + DepthRow.LEDGE_Y + 2.0
	var rope_x := World.ROPE_X + 10.0 + j * 5.0
	var surface := World.SURFACE_Y - 14.0
	var dig_x := world.rows[site].deposit_pos().x - 58.0 - j * 30.0
	var mood := world.mood(key)
	var hop := world.hop(key, j)
	var blink := Chars.blinking(_t, site * 3.1 + j * 1.3)
	var rushing := GameState.is_rushing()
	var seed := site * 0.7 + j
	if p < 0.0:
		# Dozing at the cave mouth until someone taps.
		var at := Vector2(World.CAVE_L + 40.0 + j * 26.0, ledge - hop)
		if not view.has_point(at):
			return
		var idle: float = _t - float(_idle_since.get(key, _t))
		var emo := mood if mood != "" else ("sleepy" if idle > 5.0 else "bored")
		Chars.diver(self, at, DIVER_SCALE, suit, 1.0, 0.0, 0.0, "cheer" if mood == "joy" else "idle", 0.0, false, ore, emo, blink, _t)
		if emo == "sleepy" and j == 0:
			Chars.mark(self, "zzz", at + Vector2(20, -80), _t)
		elif mood == "wow" and j == 0:
			Chars.mark(self, "!", at + Vector2(0, -92), _t)
		return
	p = clampf(p - j * 0.03, 0.0, 1.0)
	var kick := _t * (3.0 if rushing else 1.8) + seed
	var pos: Vector2
	var facing := 1.0
	var tilt := 0.0
	var arm := "swim"
	var hit := 0.0
	var carry := false
	var emo := "happy"
	if p < SWIM_OUT_END:
		var f := p / SWIM_OUT_END
		pos = Vector2(lerpf(World.CAVE_L - 10.0, dig_x, smoothstep(0.0, 1.0, f)), ledge - 18.0 + sin(_t * 5.0 + seed) * 4.0)
		tilt = 0.5
	elif p < DIG_END:
		var f := (p - SWIM_OUT_END) / (DIG_END - SWIM_OUT_END)
		hit = fposmod(f * 3.0, 1.0)
		pos = Vector2(dig_x, ledge)
		arm = "pick"
		hit = 1.0 - absf(hit * 2.0 - 1.0) if hit < 0.5 else smoothstep(0.5, 0.62, hit)
		emo = "focus"
		kick = 0.0
		var phase := fposmod(f * 3.0, 1.0)
		var id := site * 10 + j
		var before: float = _dig_phase.get(id, phase)
		_dig_phase[id] = phase
		if before < 0.55 and phase >= 0.55 and view.has_point(pos_hint(dig_x, ledge)):
			Sfx.play("dig")
			if randf() < 0.06:
				Sfx.voice("hup", randf_range(1.0, 1.4))
		if phase > 0.55 and phase < 0.75:
			_draw_chips(Vector2(dig_x + 42, ledge - 20), phase, ore)
	elif p < SWIM_BACK_END:
		var f := (p - DIG_END) / (SWIM_BACK_END - DIG_END)
		pos = Vector2(lerpf(dig_x, rope_x, smoothstep(0.0, 1.0, f)), ledge - 18.0 + sin(_t * 5.0 + seed) * 4.0)
		facing = -1.0
		tilt = 0.5
		carry = true
		emo = "joy" if f < 0.3 else "happy"
	elif p < ASCEND_END:
		var f := (p - SWIM_BACK_END) / (ASCEND_END - SWIM_BACK_END)
		pos = Vector2(rope_x, lerpf(ledge - 10.0, surface, smoothstep(0.0, 1.0, f)))
		facing = -1.0
		arm = "rope"
		carry = true
	elif p < DROP_END:
		pos = Vector2(rope_x + 6.0, surface - absf(sin((p - ASCEND_END) / (DROP_END - ASCEND_END) * PI)) * 10.0)
		arm = "cheer"
		emo = "joy"
	else:
		var f := (p - DROP_END) / (1.0 - DROP_END)
		pos = Vector2(rope_x, lerpf(surface, ledge - 10.0, smoothstep(0.0, 1.0, f)))
		facing = -1.0
		arm = "rope"
	if not view.grow(60.0).has_point(pos):
		return
	if rushing and emo in ["happy", "focus"]:
		emo = "focus"
	if mood != "":
		emo = mood
		if mood == "joy" and arm in ["swim", "idle"]:
			arm = "cheer"
	pos.y -= hop
	Chars.diver(self, pos, DIVER_SCALE, suit, facing, tilt, kick, arm, hit, carry, ore, emo, blink, _t + seed)
	if rushing and j == 0:
		Chars.mark(self, "sweat", pos + Vector2(-16 * facing, -76), _t)


func _draw_chips(at: Vector2, phase: float, ore: Color) -> void:
	var f := (phase - 0.55) / 0.2
	for k in 4:
		var a := -2.4 + k * 0.5
		var p := at + Vector2(cos(a), sin(a)) * f * 34.0 + Vector2(0, f * f * 14.0)
		Art.push(self, p, f * 4.0 + k)
		Art.toon(self, PackedVector2Array([Vector2(-3, -3), Vector2(3, -2), Vector2(2, 3), Vector2(-3, 2)]), ore, 1.2, 0.0)
		Art.pop(self)
	var s := 1.0 - f * 0.6
	Art.push(self, at, 0.0, Vector2(s, s))
	Art.toon(self, Art.star_pts(Vector2.ZERO, 14, 4, 4), Color(1, 1, 0.8, 1.0 - f), 1.2, 0.0)
	Art.pop(self)


func pos_hint(x: float, y: float) -> Vector2:
	return Vector2(x, y - 30.0)
