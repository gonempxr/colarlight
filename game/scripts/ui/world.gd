class_name World
extends Control
## The ocean cross-section: sky and shore on top, dive sites cut into the
## rock below. Owns the layout numbers, the water, and character moods
## (short reactions to what the player does).

signal stage_selected(key: String)

const TOP_H := 620.0
const SURFACE_Y := 470.0
const ROW_H := 260.0
const BOTTOM_H := 210.0
const CARD_W := 206.0
const CARD_MARGIN := 12.0
const ROPE_X := 96.0
const SHAFT_L := 62.0
const SHAFT_R := 130.0
const CAVE_L := 150.0

var surface: SurfaceView
var rows: Array[DepthRow] = []
var divers: DiverLayer

var t := 0.0
var _bubbles: Array[Vector3] = []   # x, y, radius
var _fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## key -> {"emotion", "until", "jump_at"}
var _moods := {}


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
	for i in 5:
		_fish.append({"x": _rng.randf(), "y": _rng.randf_range(SURFACE_Y + 50.0, TOP_H - 50.0), "speed": _rng.randf_range(0.015, 0.04),
				"dir": 1.0 if i % 2 == 0 else -1.0, "size": _rng.randf_range(10, 16),
				"color": [Color("ffd23f"), Color("ff7b54"), Color("7be0ff"), Color("ff9fd0"), Color("b6f36a")][i]})
	GameState.upgraded.connect(_on_upgraded)
	GameState.manager_hired.connect(func(k):
		react(k, "joy", 1.6, true)
		divers.confetti(stage_anchor(k), 18)
		Sfx.voice("yay", 1.1))
	GameState.depth_opened.connect(func(k):
		react(k, "wow", 2.0, true)
		divers.confetti(stage_anchor(k), 36)
		Sfx.voice("woohoo", 1.15))
	GameState.milestone_reached.connect(func(k, _l):
		react(k, "joy", 2.2, true)
		divers.confetti(stage_anchor(k), 30)
		Sfx.voice("woohoo", randf_range(1.0, 1.25)))
	GameState.tapped.connect(_on_tapped)
	GameState.rush_started.connect(func():
		Sfx.voice("woohoo", 1.3)
		for k in GameState.stage_keys():
			react(k, "wow", 1.0, true))


static func height() -> float:
	return TOP_H + ROW_H * Balance.DEPTHS.size() + BOTTOM_H


static func row_y(index: int) -> float:
	return TOP_H + ROW_H * index


## Cards sit in a column on the right; the scene uses the rest.
func card_x() -> float:
	return size.x - CARD_MARGIN - CARD_W


func scene_right() -> float:
	return card_x() - 14.0


func select(key: String) -> void:
	stage_selected.emit(key)


## Part of the world currently on screen (for skipping hidden drawing).
## On phones the scene animates at half the frame rate (scrolling stays
## smooth): drawing the characters is the most expensive thing we do.
static var half_rate := Art.low_power


static func anim_tick() -> bool:
	return not half_rate or Engine.get_process_frames() % 2 == 0


func visible_rect() -> Rect2:
	return get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()


func is_visible_band(y0: float, y1: float) -> bool:
	var r := visible_rect()
	return y1 >= r.position.y - 40.0 and y0 <= r.end.y + 40.0


## World point where a stage's characters are, for effects.
func stage_anchor(key: String) -> Vector2:
	match key:
		"boat":
			return surface.boat_world_pos() + Vector2(0, -60)
		"plant":
			return surface.plant_world_pos() + Vector2(75, -120)
	var i := GameState.depth_index(key)
	return Vector2((CAVE_L + scene_right()) / 2.0, row_y(i) + 120.0)


# --- Moods --------------------------------------------------------------------------

func react(key: String, emotion: String, seconds: float, jump: bool = false) -> void:
	_moods[key] = {"emotion": emotion, "until": t + seconds, "jump_at": t if jump else -99.0}


func mood(key: String) -> String:
	var m: Dictionary = _moods.get(key, {})
	if m.is_empty() or t > float(m["until"]):
		return ""
	return m["emotion"]


## Height of a happy hop for this stage's characters right now.
func hop(key: String, seed: float = 0.0) -> float:
	var m: Dictionary = _moods.get(key, {})
	if m.is_empty():
		return 0.0
	var since := t - float(m["jump_at"]) - seed * 0.08
	if since < 0.0 or since > 0.9:
		return 0.0
	return absf(sin(since * PI / 0.3)) * 16.0 * (1.0 - since / 0.9)


func _on_upgraded(key: String, _count: int) -> void:
	react(key, "joy", 1.2, true)
	divers.sparkle(stage_anchor(key), 8)
	Sfx.voice("yay", randf_range(1.0, 1.3))


func _on_tapped(key: String) -> void:
	if mood(key) == "":
		react(key, "wow", 0.7, true)
		if GameState.cycle_progress(key) < 0.0:
			Sfx.voice("wow", randf_range(1.0, 1.35))


# --- Water ------------------------------------------------------------------------------

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
	t += delta
	if _bubbles.size() < 16 and _rng.randf() < delta * 5.0:
		_bubbles.append(Vector3(_rng.randf_range(SHAFT_L + 8.0, SHAFT_R - 8.0), _rng.randf_range(TOP_H, height() - 80.0), _rng.randf_range(2.0, 5.0)))
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.y -= delta * (40.0 + b.z * 10.0)
		b.x += sin(t * 2.0 + b.y * 0.02) * delta * 6.0
		_bubbles[i] = b
		if b.y < SURFACE_Y + 8.0:
			_bubbles.remove_at(i)
	for f in _fish:
		f["x"] = fposmod(f["x"] + f["speed"] * f["dir"] * delta, 1.3)
	if anim_tick():
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := height()
	# Open water under the surface and in the shaft behind the rows.
	var bands := 10
	for i in bands:
		var y0 := lerpf(SURFACE_Y, h, float(i) / bands)
		var y1 := lerpf(SURFACE_Y, h, float(i + 1) / bands)
		var c0 := Art.water_color(float(i) / bands)
		var c1 := Art.water_color(float(i + 1) / bands)
		Art.grad(self, PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))
	if is_visible_band(SURFACE_Y, TOP_H):
		_draw_top_water(w)
	for b in _bubbles:
		Art.arc(self, Vector2(b.x, b.y), b.z, 0, TAU, 12, Color(1, 1, 1, 0.55), 1.5)
		Art.disc(self, Vector2(b.x - b.z * 0.3, b.y - b.z * 0.3), b.z * 0.28, Color(1, 1, 1, 0.6))
	if is_visible_band(h - BOTTOM_H, h):
		_draw_floor(w, h)


func _draw_top_water(w: float) -> void:
	for i in 6:
		var x := w * (0.1 + i * 0.17) + sin(t * 0.3 + i) * 16.0
		var ray := Color(1, 1, 1, 0.09)
		Art.grad(self, PackedVector2Array([Vector2(x - 14, SURFACE_Y), Vector2(x + 14, SURFACE_Y),
				Vector2(x + 70, TOP_H), Vector2(x + 20, TOP_H)]), PackedColorArray([ray, ray, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	for f in _fish:
		var fx: float = (f["x"] - 0.15) * w
		Art.fish(self, Vector2(fx, f["y"] + sin(t + fx * 0.01) * 5.0), f["size"], f["color"], f["dir"], t + f["y"])
	# Sandy slope above the first dive site, with seaweed.
	for i in 5:
		var x := SHAFT_R + 60.0 + i * (w - SHAFT_R - 120.0) / 4.0
		Art.seaweed(self, Vector2(x, TOP_H - 22), 40 + (i % 3) * 16, Color("47c47a"), t, i)
	var top := PackedVector2Array([Vector2(SHAFT_R, TOP_H + 4)])
	for i in 13:
		var x := lerpf(SHAFT_R, w + 10.0, i / 12.0)
		top.append(Vector2(x, TOP_H - 22.0 - sin(i * 1.3) * 5.0 - (7.0 if i % 3 == 0 else 0.0)))
	top.append(Vector2(w + 10, TOP_H + 4))
	Art.toon(self, top, Art.SAND, 3.0, 0.6)
	var left := PackedVector2Array([Vector2(-10, TOP_H + 4), Vector2(-10, TOP_H - 26), Vector2(20, TOP_H - 30), Vector2(SHAFT_L, TOP_H - 18), Vector2(SHAFT_L, TOP_H + 4)])
	Art.toon(self, left, Art.SAND, 3.0, 0.6)
	for p: Vector2 in [Vector2(SHAFT_R + 40, TOP_H - 22), Vector2(w * 0.55, TOP_H - 26)]:
		Art.push(self, p, 0.2)
		Props.shell(self, Color("ffb3c7"))
		Art.pop(self)


func _draw_floor(w: float, h: float) -> void:
	var floor_y := h - BOTTOM_H + 60.0
	for i in 6:
		Art.seaweed(self, Vector2(w * (0.08 + i * 0.17), floor_y + 20), 60 + (i % 3) * 22, Color("2b8f78"), t, i)
	var pts := PackedVector2Array([Vector2(-10, h + 10)])
	for i in 13:
		pts.append(Vector2(w * i / 12.0, floor_y + sin(i * 1.7) * 14.0))
	pts.append(Vector2(w + 10, h + 10))
	Art.toon(self, pts, Color("2a2f5e"), 3.0, 0.4)
	Art.push(self, Vector2(w * 0.7, floor_y + 20), 0.3)
	Props.anchor(self)
	Art.pop(self)
