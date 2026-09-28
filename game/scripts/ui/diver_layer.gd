class_name DiverLayer
extends Control
## Top layer of the ocean: the dive rope, every diver, floating "+N" texts
## and tap ripples. Divers follow their site's cycle exactly:
## down the rope, swim to the ore, 3 hits, swim back, up to the raft.

const DIVER_SCALE := 0.95
const DESCEND_END := 0.26
const SWIM_OUT_END := 0.38
const DIG_END := 0.66
const SWIM_BACK_END := 0.78

var world: World
var _t := 0.0
var _floaters: Array[Dictionary] = []
var _ripples: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func float_text(pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "age": 0.0, "size": 30 if big else 22})


func tap_ripple(pos: Vector2) -> void:
	_ripples.append(Vector3(pos.x, pos.y, 0.0))


func _process(delta: float) -> void:
	_t += delta
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i]["age"] += delta
		_floaters[i]["pos"] += Vector2(0, -50.0 * delta)
		if _floaters[i]["age"] > 1.3:
			_floaters.remove_at(i)
	for i in range(_ripples.size() - 1, -1, -1):
		var r := _ripples[i]
		r.z += delta
		_ripples[i] = r
		if r.z > 0.5:
			_ripples.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var gs := GameState
	var deepest := 0
	for i in Balance.DEPTHS.size():
		if gs.is_open("d%d" % i):
			deepest = i
	var rope_bottom := World.row_y(deepest) + World.ROW_H * 0.7
	draw_line(Vector2(World.ROPE_X, World.SURFACE_Y), Vector2(World.ROPE_X, rope_bottom), Color(1, 1, 1, 0.45), 3)
	draw_circle(Vector2(World.ROPE_X, rope_bottom), 7, Art.WOOD_DARK)
	for i in Balance.DEPTHS.size():
		var key := "d%d" % i
		if not gs.is_open(key):
			continue
		var n: int = gs.divers(key)
		var p: float = gs.cycle_progress(key)
		for j in n:
			_draw_diver(i, j, p)
		if p < 0.0 and not gs.has_manager(key):
			_draw_tap_hint(Vector2(world.rows[i].deposit_pos().x - 40, World.row_y(i) + 50))
	for key in ["boat", "plant"]:
		if gs.cycle_progress(key) < 0.0 and not gs.has_manager(key):
			var has_ore: bool = gs.hold > 0.0 if key == "boat" else gs.dock > 0.0
			if has_ore:
				var at: Vector2 = Vector2(world.surface.boat_x_range().x, World.SURFACE_Y - 90) if key == "boat" \
						else world.surface.plant_rect().get_center() + Vector2(0, -70)
				_draw_tap_hint(at)
	for r in _ripples:
		draw_arc(Vector2(r.x, r.y), 10.0 + r.z * 90.0, 0, TAU, 28, Color(1, 1, 1, 0.6 * (1.0 - r.z / 0.5)), 4, true)
	var font := UiTheme.heavy_font()
	for f in _floaters:
		var a := clampf(1.3 - f["age"], 0.0, 1.0)
		var fs: int = f["size"]
		var tw := font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos: Vector2 = f["pos"] - Vector2(tw / 2.0, 0)
		draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.6 * a))
		draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f["color"], a))


func _draw_tap_hint(at: Vector2) -> void:
	var bounce := absf(sin(_t * 4.0)) * 10.0
	var text := tr("TAP_HINT")
	var font := UiTheme.heavy_font()
	var fs := 24
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(at + Vector2(-tw / 2.0 - 14, -bounce - 40), Vector2(tw + 28, 44))
	Art.rounded_rect(self, box, 14, Art.WHITE)
	draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x / 2.0 - 10, 43), box.position + Vector2(box.size.x / 2.0 + 10, 43), box.position + Vector2(box.size.x / 2.0, 56)]), Art.WHITE)
	draw_string(font, box.position + Vector2(14, 31), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)


func _draw_diver(site: int, j: int, p: float) -> void:
	var style: Dictionary = Art.DEPTH_STYLE[site]
	var suit: Color = style["suit"]
	var row_top := World.row_y(site)
	var ledge := row_top + world.rows[site].ledge_y() - 26.0
	var rope := World.ROPE_X + 6.0 + j * 12.0
	var surface := World.SURFACE_Y + 24.0 + j * 6.0
	var dig_x := world.rows[site].deposit_pos().x - 60.0 - j * 34.0
	var scale := DIVER_SCALE
	if p < 0.0:
		# Waiting on the raft for a tap.
		var rest := Vector2(World.ROPE_X - 30.0 + site * 12.0 + j * 8.0, World.SURFACE_Y - 18.0 + sin(_t * 2.0 + j) * 2.0)
		if site == 0 or j == 0:
			Art.diver(self, rest, scale * 0.8, suit, 1.0, -1.35, 0.0)
		return
	# Spread divers a little in time so they don't overlap.
	p = clampf(p - j * 0.035, 0.0, 1.0)
	var swim := _t * 2.0 + j * 0.3
	if p < DESCEND_END:
		var f := p / DESCEND_END
		var y := lerpf(surface, ledge, f * f * (3.0 - 2.0 * f))
		Art.diver(self, Vector2(rope, y), scale, suit, 1.0, PI / 2.0, swim)
	elif p < SWIM_OUT_END:
		var f := (p - DESCEND_END) / (SWIM_OUT_END - DESCEND_END)
		Art.diver(self, Vector2(lerpf(rope, dig_x, f), ledge), scale, suit, 1.0, 0.0, swim)
	elif p < DIG_END:
		var f := (p - SWIM_OUT_END) / (DIG_END - SWIM_OUT_END)
		var hit := fposmod(f * 3.0, 1.0)
		var swing := 1.0 - absf(hit * 2.0 - 1.0)
		Art.diver(self, Vector2(dig_x, ledge + 4.0), scale, suit, 1.0, 0.15, _t * 0.5, "pick", swing)
		if hit > 0.85:
			for k in 3:
				var a := -0.8 + k * 0.5
				draw_circle(Vector2(dig_x + 34, ledge - 4) + Vector2(cos(a), sin(a)) * (hit - 0.8) * 120.0, 3, style["ore"])
	elif p < SWIM_BACK_END:
		var f := (p - DIG_END) / (SWIM_BACK_END - DIG_END)
		Art.diver(self, Vector2(lerpf(dig_x, rope, f), ledge), scale, suit, -1.0, 0.0, swim, "bag", 0.0, style["ore"])
	else:
		var f := (p - SWIM_BACK_END) / (1.0 - SWIM_BACK_END)
		var y := lerpf(ledge, surface, f * f * (3.0 - 2.0 * f))
		Art.diver(self, Vector2(rope, y), scale, suit, 1.0, -PI / 2.0, swim, "bag", 0.0, style["ore"])
