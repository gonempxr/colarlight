class_name SurfaceView
extends Control
## Everything above water: sky, the raft over the dive rope, the boat,
## the dock and the processing plant on the island. Cards for the boat and
## the plant sit in the sky row.

const BOAT_SCALE := 0.8

var world: World
var boat_card: StageCard
var plant_card: StageCard

var _t := 0.0
var _smoke: Array[Vector3] = []   # x, y, age
var _gear_rot := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	boat_card = StageCard.new("boat")
	boat_card.world = world
	boat_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(boat_card)
	plant_card = StageCard.new("plant")
	plant_card.world = world
	plant_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(plant_card)
	GameState.cycle_finished.connect(_on_cycle_finished)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and plant_card:
		plant_card.position = Vector2(world.card_x(), 12)
		boat_card.position = Vector2(world.card_x() - 12 - World.CARD_W, 12)


func refresh() -> void:
	boat_card.refresh()
	plant_card.refresh()


func raft_pos() -> Vector2:
	return Vector2(World.ROPE_X, World.SURFACE_Y)


func dock_pos() -> Vector2:
	return Vector2(size.x - 270.0, World.SURFACE_Y - 16.0)


func plant_rect() -> Rect2:
	return Rect2(size.x - 205.0, World.SURFACE_Y - 165.0, 180.0, 95.0)


func boat_x_range() -> Vector2:
	return Vector2(World.ROPE_X + 140.0, dock_pos().x - 95.0)


func _on_cycle_finished(key: String, amount: float) -> void:
	match key:
		"plant":
			var r := plant_rect()
			world.divers.float_text(Vector2(r.get_center().x, r.position.y - 10), "+" + NumFormat.short(amount), Art.GOLD, true)
			Sfx.play("coins")
		"boat":
			world.divers.float_text(dock_pos() + Vector2(0, -40), "+" + NumFormat.short(amount), Color("bff6ff"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag() or event.position.y < 240.0:
			return
		var key := "plant" if event.position.x > size.x - 250.0 else "boat"
		if GameState.tap(key):
			Sfx.play("horn" if key == "boat" else "machine")
		world.divers.tap_ripple(event.position)


func _process(delta: float) -> void:
	_t += delta
	var working := GameState.cycle_progress("plant") >= 0.0
	if working:
		_gear_rot += delta * 3.0
		if randf() < delta * 6.0:
			var r := plant_rect()
			_smoke.append(Vector3(r.position.x + 34, r.position.y - 46, 0.0))
	for i in range(_smoke.size() - 1, -1, -1):
		var s := _smoke[i]
		s.z += delta
		s.y -= delta * 30.0
		s.x += delta * 12.0
		_smoke[i] = s
		if s.z > 2.5:
			_smoke.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var sy := World.SURFACE_Y
	# Sky.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, sy), Vector2(0, sy)]),
			PackedColorArray([Art.SKY_TOP, Art.SKY_TOP, Art.SKY_BOTTOM, Art.SKY_BOTTOM]))
	draw_circle(Vector2(90, 90), 70, Color(1, 0.97, 0.75, 0.35))
	draw_circle(Vector2(90, 90), 46, Color("fff3b0"))
	for i in 3:
		var cx := fposmod(i * 260.0 + _t * (8.0 + i * 3.0), w + 200.0) - 100.0
		var cy := 170.0 + i * 50.0
		for j in 3:
			draw_circle(Vector2(cx + j * 26.0, cy - (10.0 if j == 1 else 0.0)), 22.0 - j * 2.0, Color(1, 1, 1, 0.85))
	_draw_island(w, sy)
	_draw_plant()
	_draw_dock()
	_draw_raft()
	_draw_boat()
	# Water surface with small waves, over the hulls.
	var wave := PackedVector2Array()
	for i in 41:
		var x := w * i / 40.0
		wave.append(Vector2(x, sy + sin(_t * 1.6 + i * 0.7) * 3.0))
	wave.append(Vector2(w, sy + 14))
	wave.append(Vector2(0, sy + 14))
	draw_colored_polygon(wave, Color(Art.SEA_TOP, 0.55))
	for i in 40:
		var x := w * i / 40.0
		draw_line(Vector2(x, sy + sin(_t * 1.6 + i * 0.7) * 3.0), Vector2(x + w / 40.0, sy + sin(_t * 1.6 + (i + 1) * 0.7) * 3.0), Color(1, 1, 1, 0.8), 3, true)
	for s in _smoke:
		draw_circle(Vector2(s.x, s.y), 8.0 + s.z * 8.0, Color(1, 1, 1, 0.5 * (1.0 - s.z / 2.5)))


func _draw_island(w: float, sy: float) -> void:
	var x0 := w - 250.0
	var plateau := sy - 70.0
	draw_colored_polygon(PackedVector2Array([Vector2(x0, sy + 20), Vector2(x0 + 40, plateau + 10), Vector2(x0 + 70, plateau),
			Vector2(w, plateau - 6), Vector2(w, sy + 20)]), Art.SAND)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + 50, plateau + 4), Vector2(x0 + 70, plateau - 4), Vector2(w, plateau - 12),
			Vector2(w, plateau + 2), Vector2(x0 + 70, plateau + 8)]), Art.GRASS)
	# Palm tree.
	var base := Vector2(w - 26, plateau - 6)
	var top := base + Vector2(-10, -70)
	draw_line(base, top, Art.WOOD, 8, true)
	for i in 5:
		var a := -PI * 0.9 + i * PI * 0.45 + sin(_t + i) * 0.05
		draw_line(top, top + Vector2(cos(a), sin(a) * 0.6) * 38, Color("2e9e4f"), 7, true)


func _draw_plant() -> void:
	var r := plant_rect()
	var working := GameState.cycle_progress("plant") >= 0.0
	# Chimney.
	Art.rounded_rect(self, Rect2(r.position.x + 22, r.position.y - 44, 24, 60), 4, Color("8c4a3a"))
	Art.rounded_rect(self, Rect2(r.position.x + 18, r.position.y - 50, 32, 12), 4, Color("6d392d"))
	# Body and roof.
	Art.rounded_rect(self, r, 12, Color("f2f5fa"))
	Art.rounded_rect(self, Rect2(r.position + Vector2(-8, -16), Vector2(r.size.x + 16, 26)), 10, Color("23a6b8"))
	for i in 3:
		var win := Rect2(r.position + Vector2(18 + i * 52, 28), Vector2(34, 26))
		Art.rounded_rect(self, win, 6, Color("ffe38a") if working else Color("8fb7d9"))
	Art.gear(self, r.position + Vector2(r.size.x - 22, r.size.y - 14), 22, Color("ffb627"), _gear_rot)
	# Conveyor from the dock.
	var d := dock_pos()
	draw_line(d + Vector2(20, -6), r.position + Vector2(0, r.size.y - 18), Color("44516b"), 8, true)
	var p := GameState.cycle_progress("plant")
	if p >= 0.0:
		var pos := (d + Vector2(20, -6)).lerp(r.position + Vector2(0, r.size.y - 18), p)
		draw_circle(pos + Vector2(0, -8), 7, Art.DEPTH_STYLE[0]["ore2"])


func _draw_dock() -> void:
	var d := dock_pos()
	var sy := World.SURFACE_Y
	for i in 3:
		draw_line(Vector2(d.x - 40 + i * 30, sy - 12), Vector2(d.x - 40 + i * 30, sy + 26), Art.WOOD_DARK, 6)
	Art.rounded_rect(self, Rect2(d.x - 50, sy - 20, 90, 12), 3, Art.WOOD)
	if GameState.dock > 0.0:
		var n := clampi(int(log(GameState.dock + 1.0) / log(10.0)) + 1, 1, 5)
		Art.crystals(self, Vector2(d.x - 4, sy - 20), 14.0 + n * 4.0, Art.DEPTH_STYLE[1], 5, n)
		_label(Vector2(d.x - 5, sy - 58), NumFormat.short(GameState.dock), Color("bff6ff"))


func _draw_raft() -> void:
	var p := raft_pos()
	var sy := World.SURFACE_Y
	# Buoy flag.
	draw_line(p + Vector2(-44, -6), p + Vector2(-44, -60), Art.WOOD_DARK, 4)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, -60), p + Vector2(-10, -50), p + Vector2(-44, -40)]), Art.RED)
	var bob := sin(_t * 1.6) * 3.0
	for i in 5:
		Art.rounded_rect(self, Rect2(p.x - 58 + i * 23, sy - 12 + bob, 22, 18), 6, Art.WOOD if i % 2 == 0 else Art.WOOD.darkened(0.1))
	if GameState.hold > 0.0:
		var n := clampi(int(log(GameState.hold + 1.0) / log(10.0)) + 1, 1, 5)
		Art.crystals(self, Vector2(p.x + 8, sy - 12 + bob), 14.0 + n * 4.0, Art.DEPTH_STYLE[1], 9, n)
		_label(Vector2(p.x + 8, sy - 52 + bob), NumFormat.short(GameState.hold), Color("bff6ff"))


func _draw_boat() -> void:
	var range := boat_x_range()
	var p := GameState.cycle_progress("boat")
	var x := range.x
	var facing := 1.0
	var cargo := 0.0
	if p >= 0.0:
		var cap := maxf(1.0, GameState.cycle_capacity("boat"))
		if p < 0.45:
			x = lerpf(range.x, range.y, smoothstep(0.0, 0.45, p))
			cargo = GameState.cycle_load("boat") / cap
		elif p < 0.55:
			x = range.y
			cargo = GameState.cycle_load("boat") / cap * (0.55 - p) / 0.1
		else:
			x = lerpf(range.y, range.x, smoothstep(0.55, 1.0, p))
			facing = -1.0
	Art.boat(self, Vector2(x, World.SURFACE_Y + 4), BOAT_SCALE, facing, _t * 0.5, cargo, Art.DEPTH_STYLE[1]["ore"])


func _label(pos: Vector2, text: String, color: Color) -> void:
	var font := UiTheme.heavy_font()
	var fs := 20
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, pos - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.55))
	draw_string(font, pos - Vector2(tw / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
