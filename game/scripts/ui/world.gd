class_name World
extends Control
## The ocean cross-section: sky and shore on top, dive sites below.
## Owns the layout numbers the other scene parts use and draws the water.

signal stage_selected(key: String)

const TOP_H := 600.0
const SURFACE_Y := 420.0
const ROW_H := 250.0
const BOTTOM_H := 170.0
const CARD_W := 206.0
const CARD_MARGIN := 12.0
const ROPE_X := 96.0

var surface: SurfaceView
var rows: Array[DepthRow] = []
var divers: DiverLayer

var _t := 0.0
var _bubbles: Array[Vector3] = []   # x, y, radius
var _fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rng.seed = 7
	surface = SurfaceView.new()
	surface.world = self
	add_child(surface)
	for i in Balance.DEPTHS.size():
		var row := DepthRow.new()
		row.world = self
		row.index = i
		add_child(row)
		rows.append(row)
	divers = DiverLayer.new()
	divers.world = self
	add_child(divers)
	custom_minimum_size.y = height()
	for i in 6:
		_fish.append({"y": _rng.randf_range(0.1, 0.95), "x": _rng.randf(), "speed": _rng.randf_range(0.02, 0.05),
				"dir": 1.0 if i % 2 == 0 else -1.0, "size": _rng.randf_range(9, 16),
				"color": [Color("ffd23f"), Color("ff7b54"), Color("7be0ff"), Color("ff9fd0")][i % 4]})


static func height() -> float:
	return TOP_H + ROW_H * Balance.DEPTHS.size() + BOTTOM_H


static func row_y(index: int) -> float:
	return TOP_H + ROW_H * index


## Cards sit in a column on the right; the scene uses the rest.
func card_x() -> float:
	return size.x - CARD_MARGIN - CARD_W


func scene_right() -> float:
	return card_x() - 12.0


func select(key: String) -> void:
	stage_selected.emit(key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		size.y = height()
		surface.position = Vector2.ZERO
		surface.size = Vector2(size.x, TOP_H)
		for row in rows:
			row.position = Vector2(0, row_y(row.index))
			row.size = Vector2(size.x, ROW_H)
		divers.position = Vector2.ZERO
		divers.size = size


func _process(delta: float) -> void:
	_t += delta
	var bottom := height() - BOTTOM_H * 0.4
	if _bubbles.size() < 34 and _rng.randf() < delta * 8.0:
		_bubbles.append(Vector3(_rng.randf_range(0.0, size.x), _rng.randf_range(SURFACE_Y + 200.0, bottom), _rng.randf_range(2.0, 6.0)))
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.y -= delta * (30.0 + b.z * 10.0)
		b.x += sin(_t * 2.0 + b.y * 0.02) * delta * 8.0
		_bubbles[i] = b
		if b.y < SURFACE_Y + 6.0:
			_bubbles.remove_at(i)
	for f in _fish:
		f["x"] = fposmod(f["x"] + f["speed"] * f["dir"] * delta, 1.2)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := height()
	# Water column as a vertical gradient strip.
	var bands := 12
	for i in bands:
		var y0 := lerpf(SURFACE_Y, h, float(i) / bands)
		var y1 := lerpf(SURFACE_Y, h, float(i + 1) / bands)
		var c0 := Art.water_color(float(i) / bands)
		var c1 := Art.water_color(float(i + 1) / bands)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
				PackedColorArray([c0, c0, c1, c1]))
	# Sun rays fading into the depth.
	for i in 5:
		var x := w * (0.12 + i * 0.2) + sin(_t * 0.3 + i) * 20.0
		var spread := 40.0 + i * 8.0
		var ray := Color(1, 1, 1, 0.07)
		draw_polygon(PackedVector2Array([Vector2(x - 12, SURFACE_Y), Vector2(x + 12, SURFACE_Y),
				Vector2(x + spread + 80, SURFACE_Y + 900), Vector2(x - spread + 80, SURFACE_Y + 900)]),
				PackedColorArray([ray, ray, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	# Fish in the background.
	for f in _fish:
		var fx: float = (f["x"] - 0.1) * w
		var fy: float = lerpf(SURFACE_Y + 60.0, h - BOTTOM_H, f["y"])
		Art.fish(self, Vector2(fx, fy + sin(_t + fy) * 6.0), f["size"], Color(f["color"], 0.55), f["dir"], _t + fy)
	# Sea floor.
	var floor_y := h - BOTTOM_H + 40.0
	var pts := PackedVector2Array([Vector2(0, h)])
	for i in 13:
		var x := w * i / 12.0
		pts.append(Vector2(x, floor_y + sin(i * 1.7) * 18.0))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, Color("0c1d45"))
	for i in 7:
		Art.seaweed(self, Vector2(w * (0.08 + i * 0.14), floor_y + 30), 70 + (i % 3) * 25, Color("1e7a6b"), _t, i)
	for b in _bubbles:
		draw_arc(Vector2(b.x, b.y), b.z, 0, TAU, 12, Color(1, 1, 1, 0.45), 1.5, true)
		draw_circle(Vector2(b.x - b.z * 0.3, b.y - b.z * 0.3), b.z * 0.25, Color(1, 1, 1, 0.5))
