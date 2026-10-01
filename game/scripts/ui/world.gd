class_name World
extends Control
## The ocean cross-section: sky and shore on top, dive sites cut into the
## rock below. Owns the layout numbers, the sky and the water, the clock of
## the day (DayNight), and character moods (short reactions to what the
## player does). The sky (gradient, stars, moon, sun) is drawn here, under
## the water, so the sun and moon sink into the sea.
##
## Drawing is split by how often things change (see the frame schedule):
##   _sky, _sun, _sea  (behind)  sky gradient and stars, sun or moon, water;
##                                repainted a few times a second at most
##   self                        sea life: fish, seaweed, light rays, bubbles
##   _ground, _floor   (front)   sand over the first site, the sea floor;
##                                repainted when the light changes

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
var lift: LiftView
var divers: DiverLayer
var chest: ChestBubble

var t := 0.0
var _bubbles: Array[Vector3] = []   # x, y, radius
var _fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## key -> {"emotion", "until", "jump_at"}
var _moods := {}
## Time of the last tap on "sun" / "moon" (SurfaceView sets them).
var pokes := {}
var _stars: Array[Vector3] = []          # x (0..1 of width), y, size
var _shooting: Array[Dictionary] = []
var _deep_tint := Color.WHITE
var _sky: PaintLayer
var _sun: PaintLayer
var _sea: PaintLayer
var _ground: PaintLayer
var _floor: PaintLayer
## Light the still layers were painted with (see _process).
var _painted_light := -1.0
var _painted_tint := -1.0
var _sun_left := 0.0
var _view := Rect2()
var _view_frame := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rng.seed = 7
	_sky = PaintLayer.new(_paint_sky)
	add_child(_sky)
	_sun = PaintLayer.new(_paint_sun)
	add_child(_sun)
	_sea = PaintLayer.new(_paint_sea)
	add_child(_sea)
	_ground = PaintLayer.new(_paint_ground, false)
	add_child(_ground)
	_floor = PaintLayer.new(_paint_floor, false)
	add_child(_floor)
	surface = SurfaceView.new()
	surface.world = self
	add_child(surface)
	for i in Balance.DEPTHS.size():
		var row := DepthRow.new()
		row.world = self
		row.index = i
		add_child(row)
		rows.append(row)
	lift = LiftView.new()
	lift.world = self
	add_child(lift)
	divers = DiverLayer.new()
	divers.world = self
	add_child(divers)
	chest = ChestBubble.new()
	chest.world = self
	add_child(chest)
	custom_minimum_size.y = height()
	for i in FISH:
		_fish.append({"x": _rng.randf(), "y": _rng.randf_range(SURFACE_Y + 50.0, TOP_H - 50.0), "speed": _rng.randf_range(0.015, 0.04),
				"dir": 1.0 if i % 2 == 0 else -1.0, "size": _rng.randf_range(10, 16), "dart": -99.0, "face": 1.0 if i % 2 == 0 else -1.0,
				"color": [Color("ffd23f"), Color("ff7b54"), Color("7be0ff"), Color("ff9fd0"), Color("b6f36a")][i]})
	var srng := RandomNumberGenerator.new()
	srng.seed = 21
	for i in 46:
		_stars.append(Vector3(srng.randf(), srng.randf_range(12.0, SURFACE_Y - 90.0), srng.randf_range(0.6, 1.5)))
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


# --- Frame schedule ------------------------------------------------------------------
## The scene animates at ANIM_HZ, not at the display's frame rate, and its
## two heavy halves take turns: on PEOPLE frames the divers, the chest and
## the sea life redraw, on SCENERY frames the surface (boats, plant, crew,
## sky life) and the dive sites. So a display frame pays for about half of
## the scene, and a 120 Hz screen doesn't draw it twice as often. Scrolling
## moves the whole world as one transform, so it stays smooth at full rate.
const ANIM_HZ := 30.0
## Low quality (phones by default) animates the scene a little slower.
const LOW_HZ := 30.0
const PEOPLE := 0
const SCENERY := 1
const FISH := 4

static var half_rate := Art.low_power
static var _frame := -1
static var _since: Array[float] = [9.0, 9.0]
static var _fire: Array[bool] = [false, false]
static var _count: Array[int] = [0, 0]
static var _hurry := false


static func _schedule() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var tree := Engine.get_main_loop() as SceneTree
	var dt := clampf(tree.root.get_process_delta_time(), 0.0, 1.0) if tree else 1.0
	var period := 1.0 / (LOW_HZ if half_rate else ANIM_HZ)
	for g in 2:
		_since[g] += dt
		_fire[g] = _hurry
	_hurry = false
	# Normal quality: everything animates on every frame (the web shell
	# already keeps fast screens near 60 fps).
	if not half_rate:
		for g in 2:
			_fire[g] = true
			_since[g] = 0.0
			_count[g] += 1
		return
	# The group waiting longest goes, the other one waits for the next
	# frame. On a slow device the two simply alternate, so every frame costs
	# about half of the scene there too.
	var first := PEOPLE if _since[PEOPLE] >= _since[SCENERY] else SCENERY
	if _since[first] >= period * 0.9:
		_fire[first] = true
	for g in 2:
		if _fire[g]:
			_since[g] = 0.0
			_count[g] += 1


## True on the frames the characters (divers, chest) redraw.
static func anim_tick() -> bool:
	return tick(PEOPLE)


static func tick(group: int) -> bool:
	_schedule()
	return _fire[group]


## How many times `group` has redrawn (to spread slower things over frames).
static func tick_count(group: int) -> int:
	_schedule()
	return _count[group]


## Redraw everything on the next frame (right after a tap).
static func hurry() -> void:
	_hurry = true


## Part of the world currently on screen (for skipping hidden drawing).


func visible_rect() -> Rect2:
	# Asked for dozens of times a frame: worked out once per frame.
	var f := Engine.get_process_frames()
	if f != _view_frame:
		_view_frame = f
		_view = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	return _view


func is_visible_band(y0: float, y1: float) -> bool:
	var r := visible_rect()
	return y1 >= r.position.y - 40.0 and y0 <= r.end.y + 40.0


## World point where a stage's characters are, for effects.
func stage_anchor(key: String) -> Vector2:
	match key:
		"lift":
			return lift.cabin_pos() + Vector2(0, -40)
		"boat":
			return surface.boat_world_pos() + Vector2(0, -60)
		"plant":
			return surface.plant_world_pos() + Vector2(75, -120)
		"boat2":
			return surface.boat2_world_pos() + Vector2(0, -44)
		"plant2":
			return surface.plant2_world_pos() + Vector2(60, -96)
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


# --- Sky and sea life ---------------------------------------------------------------------

func shooting_star(from: Vector2) -> void:
	var dir := Vector2(1.0 if _rng.randf() < 0.5 else -1.0, 0.45).normalized()
	_shooting.append({"p": from, "v": dir * _rng.randf_range(380, 460), "age": 0.0})


func _fish_pos(f: Dictionary, w: float) -> Vector2:
	var fx: float = (f["x"] - 0.15) * w
	return Vector2(fx, f["y"] + sin(t + fx * 0.01) * 5.0)


## A tap in the water: the nearest fish darts away and blows bubbles.
func poke_fish(p: Vector2) -> bool:
	var best := _fish_at(p)
	if best < 0:
		return false
	var f: Dictionary = _fish[best]
	var at := _fish_pos(f, size.x)
	f["dir"] = 1.0 if at.x >= p.x else -1.0
	f["dart"] = t
	for k in 4:
		_bubbles.append(Vector3(at.x + float(f["dir"]) * f["size"] * (0.9 + k * 0.15), at.y - k * 6.0, 2.0 + k * 0.8))
	Sfx.play("pop", 1.5)
	Sfx.play("dive", 1.8)
	hurry()
	return true


## True when a tap at `p` would poke a fish.
func is_fish_at(p: Vector2) -> bool:
	return _fish_at(p) >= 0


func _fish_at(p: Vector2) -> int:
	var best := -1
	var best_d := 46.0
	for i in _fish.size():
		var d := _fish_pos(_fish[i], size.x).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## At night the dive sites dim a little (their cards stay bright).
func _apply_night_tint() -> void:
	var deep := DayNight.deep_tint()
	if deep.is_equal_approx(_deep_tint):
		return
	_deep_tint = deep
	for row in rows:
		row.self_modulate = deep
		for c in row.get_children():
			if c is PaintLayer:
				c.self_modulate = deep
	divers.self_modulate = Color.WHITE.lerp(deep, 0.5)


## Water color at a depth y (shared with the surface so the horizon matches).
static func water_at(y: float) -> Color:
	var f := clampf((y - SURFACE_Y) / (height() - SURFACE_Y), 0.0, 1.0)
	return Art.calm(Art.water_color(f)) * DayNight.sea_tint().lerp(DayNight.deep_tint(), clampf(f * 4.0, 0.0, 1.0))


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
	DayNight.advance(delta)
	_apply_night_tint()
	for i in range(_shooting.size() - 1, -1, -1):
		var s: Dictionary = _shooting[i]
		s["age"] = float(s["age"]) + delta
		s["p"] = s["p"] + s["v"] * delta
		if float(s["age"]) > 1.1:
			_shooting.remove_at(i)
	if _rng.randf() < delta * 0.05 * DayNight.night():
		shooting_star(Vector2(_rng.randf_range(0.1, 0.8) * size.x, _rng.randf_range(40.0, 220.0)))
	if _bubbles.size() < 12 and _rng.randf() < delta * 4.0:
		_bubbles.append(Vector3(_rng.randf_range(SHAFT_L + 8.0, SHAFT_R - 8.0), _rng.randf_range(TOP_H, height() - 80.0), _rng.randf_range(2.0, 5.0)))
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b.y -= delta * (40.0 + b.z * 10.0)
		b.x += sin(t * 2.0 + b.y * 0.02) * delta * 6.0
		_bubbles[i] = b
		if b.y < SURFACE_Y + 8.0:
			_bubbles.remove_at(i)
	for f in _fish:
		var dart := 1.0 + 7.0 * exp(-(t - float(f["dart"])) * 2.5)
		f["x"] = fposmod(f["x"] + f["speed"] * f["dir"] * dart * delta, 1.3)
		f["face"] = move_toward(float(f["face"]), float(f["dir"]), delta * 7.0)
	_repaint_still(delta)
	if tick(PEOPLE) and (is_visible_band(0.0, TOP_H) or is_visible_band(height() - BOTTOM_H, height())):
		queue_redraw()


## Repaints every still layer (after the graphics quality changes).
func repaint_still() -> void:
	for layer: PaintLayer in [_sky, _sun, _sea, _ground, _floor]:
		layer.queue_redraw()
	surface.repaint_still()
	for row in rows:
		row.repaint_still()


## Repaints the still layers only when what they show has changed enough to
## see: the sky and the water follow the clock in quarter-second steps
## (their gradients are cheap), the toon shapes (sand, shells, floor) in
## DayNight steps, as their colors are cached.
func _repaint_still(delta: float) -> void:
	var sky_on := is_visible_band(0.0, SURFACE_Y)
	var light := floorf(DayNight.phase() * DayNight.CYCLE * 4.0)
	if light != _painted_light:
		_painted_light = light
		_sky.queue_redraw()
		_sea.queue_redraw()
	elif sky_on and DayNight.night() > 0.02 and tick(SCENERY) and tick_count(SCENERY) % 4 == 0:
		_sky.queue_redraw()   # twinkling stars
	var tint := DayNight.stepped_phase()
	if tint != _painted_tint:
		_painted_tint = tint
		_ground.queue_redraw()
		_floor.queue_redraw()
	# The sun and the moon move slowly: ten times a second is plenty, but a
	# tap on them plays its spin or wink smoothly.
	_sun_left -= delta
	var poked := t - maxf(float(pokes.get("sun", -99.0)), float(pokes.get("moon", -99.0))) < 1.5
	if sky_on and (_sun_left <= 0.0 or (poked and tick(SCENERY))):
		_sun_left = 0.1
		_sun.queue_redraw()


## Sea life, redrawn with the characters: shooting stars, the light path
## and rays in the water, fish, seaweed and the bubbles leaving the shaft.
func _draw() -> void:
	var w := size.x
	var h := height()
	if is_visible_band(0.0, SURFACE_Y):
		_draw_shooting_stars()
	if is_visible_band(SURFACE_Y, TOP_H):
		_draw_reflection(w)
		_draw_top_water(w)
		# Only the stretch above the first site shows (the rows cover the shaft).
		for b in _bubbles:
			if b.y > TOP_H + b.z:
				continue
			Art.arc(self, Vector2(b.x, b.y), b.z, 0, TAU, 10, Color(1, 1, 1, 0.5), 1.5)
			Art.disc(self, Vector2(b.x - b.z * 0.3, b.y - b.z * 0.3), b.z * 0.28, Color(1, 1, 1, 0.55))
	if is_visible_band(h - BOTTOM_H, h):
		var floor_y := h - BOTTOM_H + 60.0
		for i in 6:
			Art.seaweed(self, Vector2(w * (0.08 + i * 0.17), floor_y + 20), 60 + (i % 3) * 22, Color("2b8f78"), t, i)


## Sky gradient, sunset glow and stars (a still layer).
func _paint_sky(ci: CanvasItem) -> void:
	var w := size.x
	var sy := SURFACE_Y
	var cols := DayNight.sky_colors()
	for i in cols.size():
		cols[i] = Art.calm(cols[i])
	var mid := sy * 0.52
	Art.grad(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, mid), Vector2(0, mid)]), PackedColorArray([cols[0], cols[0], cols[1], cols[1]]))
	Art.grad(ci, PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, sy + 2), Vector2(0, sy + 2)]), PackedColorArray([cols[1], cols[1], cols[2], cols[2]]))
	var night := DayNight.night()
	var warm := DayNight.warmth()
	if warm > 0.02:
		Props.halo(ci, Vector2(DayNight.light_pos(w).x, sy), 300.0, Color(cols[2].lightened(0.35), warm * 0.55), 28)
	if night > 0.02:
		for s in _stars:
			var tw := 0.55 + 0.45 * sin(t * (1.3 + s.z) + s.x * 40.0)
			Props.star(ci, Vector2(s.x * w, s.y), s.z, Color(1.0, 0.97, 0.85, night * tw))


func _draw_shooting_stars() -> void:
	for s in _shooting:
		var age: float = s["age"]
		var a := clampf(1.0 - age / 1.1, 0.0, 1.0) * clampf(age * 6.0, 0.0, 1.0)
		var p: Vector2 = s["p"]
		var v: Vector2 = s["v"]
		Art.grad(self, PackedVector2Array([p, p - v * 0.28 + v.orthogonal().normalized() * 2.0, p - v * 0.28 - v.orthogonal().normalized() * 2.0]),
				PackedColorArray([Color(1, 1, 0.9, a), Color(1, 1, 0.9, 0.0), Color(1, 1, 0.9, 0.0)]))
		Props.star(self, p, 1.6, Color(1, 1, 0.9, a))


## The sun by day, the moon by night (a layer repainted ~10 times a second).
func _paint_sun(ci: CanvasItem) -> void:
	var w := size.x
	var warm := DayNight.warmth()
	var calm: bool = Settings.reduce_motion
	if DayNight.sun_up():
		var k := clampf((t - float(pokes.get("sun", -99.0))) / 1.2, 0.0, 1.0)
		var spin := 0.0 if calm or k >= 1.0 else (1.0 - pow(1.0 - k, 3.0)) * TAU
		var sq := sin(k * PI * 3.0) * (1.0 - k) * 0.14
		Art.push(ci, DayNight.sun_pos(w), 0.0, Vector2(1.0 + sq, 1.0 - sq))
		Props.sun(ci, t, spin, 1.0 if k < 0.8 else 0.0, warm)
		Art.pop(ci)
	else:
		var k := clampf((t - float(pokes.get("moon", -99.0))) / 1.4, 0.0, 1.0)
		var sq := sin(k * PI * 3.0) * (1.0 - k) * 0.12
		Art.push(ci, DayNight.moon_pos(w), sin(k * PI * 2.0) * (1.0 - k) * 0.25, Vector2(1.0 + sq, 1.0 - sq))
		Props.moon(ci, t, 1.0 if k < 0.85 else 0.0)
		Art.pop(ci)


## Open water above the first dive site and around the sea floor (a still
## layer; the dive sites cover everything in between with their own rock
## and shaft, so painting water there would only cost fill rate).
func _paint_sea(ci: CanvasItem) -> void:
	var w := size.x
	var h := height()
	for band: Vector2 in [Vector2(SURFACE_Y, TOP_H + 8.0), Vector2(h - BOTTOM_H - 8.0, h)]:
		var c0 := water_at(band.x)
		var c1 := water_at(band.y)
		Art.grad(ci, PackedVector2Array([Vector2(0, band.x), Vector2(w, band.x), Vector2(w, band.y), Vector2(0, band.y)]), PackedColorArray([c0, c0, c1, c1]))


## Glittering path of sun or moon light on the water.
func _draw_reflection(w: float) -> void:
	var light := DayNight.light_pos(w)
	if light.y > SURFACE_Y + 20.0:
		return
	var up := clampf((SURFACE_Y + 20.0 - light.y) / 60.0, 0.0, 1.0)
	var strength := (0.22 + DayNight.warmth() * 0.5) if DayNight.sun_up() else 0.4 * DayNight.night()
	var c := DayNight.glint()
	for i in 6:
		var y := SURFACE_Y + 12.0 + i * 11.0
		var hw := (38.0 - i * 3.5) * (0.7 + 0.3 * sin(t * 2.1 + i * 1.3))
		var x := light.x + sin(t * 1.3 + i * 1.7) * 6.0
		var a := strength * up * (1.0 - i / 8.0) * (0.6 + 0.4 * sin(t * 3.0 + i))
		var mid := Color(c, a)
		var clear := Color(c, 0.0)
		Art.grad(self, PackedVector2Array([Vector2(x - hw, y), Vector2(x, y - 1.5), Vector2(x, y + 1.5), Vector2(x - hw, y)]), PackedColorArray([clear, mid, mid, clear]))
		Art.grad(self, PackedVector2Array([Vector2(x, y - 1.5), Vector2(x + hw, y), Vector2(x + hw, y), Vector2(x, y + 1.5)]), PackedColorArray([mid, clear, clear, mid]))


## Light rays, fish and seaweed above the first dive site.
func _draw_top_water(w: float) -> void:
	var day := DayNight.daylight()
	var tint := DayNight.deep_tint(DayNight.stepped_phase())
	for i in 5:
		var x := w * (0.1 + i * 0.2) + sin(t * 0.3 + i) * 16.0
		var ray := Color(1, 1, 1, 0.07 * (0.2 + 0.8 * day))
		Art.grad(self, PackedVector2Array([Vector2(x - 14, SURFACE_Y), Vector2(x + 14, SURFACE_Y),
				Vector2(x + 70, TOP_H), Vector2(x + 20, TOP_H)]), PackedColorArray([ray, ray, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	for f in _fish:
		var dart := exp(-(t - float(f["dart"])) * 2.5)
		var face: float = f["face"]
		if absf(face) < 0.15:
			face = 0.15 * signf(face) if face != 0.0 else 0.15
		Art.fish(self, _fish_pos(f, w), f["size"], Color(f["color"]) * tint, face, t * (1.0 + dart * 2.0) + f["y"])
	for i in 5:
		var x := SHAFT_R + 60.0 + i * (w - SHAFT_R - 120.0) / 4.0
		Art.seaweed(self, Vector2(x, TOP_H - 22), 40 + (i % 3) * 16, Color("47c47a") * tint, t, i)


## Sandy slope above the first dive site, with shells (a still layer over
## the seaweed roots).
func _paint_ground(ci: CanvasItem) -> void:
	var w := size.x
	var tint := DayNight.deep_tint(DayNight.stepped_phase())
	var top := PackedVector2Array([Vector2(SHAFT_R, TOP_H + 4)])
	for i in 13:
		var x := lerpf(SHAFT_R, w + 10.0, i / 12.0)
		top.append(Vector2(x, TOP_H - 22.0 - sin(i * 1.3) * 5.0 - (7.0 if i % 3 == 0 else 0.0)))
	top.append(Vector2(w + 10, TOP_H + 4))
	Art.toon(ci, top, Art.SAND * tint, 3.0, 0.6)
	var left := PackedVector2Array([Vector2(-10, TOP_H + 4), Vector2(-10, TOP_H - 26), Vector2(20, TOP_H - 30), Vector2(SHAFT_L, TOP_H - 18), Vector2(SHAFT_L, TOP_H + 4)])
	Art.toon(ci, left, Art.SAND * tint, 3.0, 0.6)
	for p: Vector2 in [Vector2(SHAFT_R + 40, TOP_H - 22), Vector2(w * 0.55, TOP_H - 26)]:
		Art.push(ci, p, 0.2)
		Props.shell(ci, Color("ffb3c7") * tint)
		Art.pop(ci)


## The sea floor under the last dive site, with an old anchor (a still layer).
func _paint_floor(ci: CanvasItem) -> void:
	var w := size.x
	var h := height()
	var floor_y := h - BOTTOM_H + 60.0
	var pts := PackedVector2Array([Vector2(-10, h + 10)])
	for i in 13:
		pts.append(Vector2(w * i / 12.0, floor_y + sin(i * 1.7) * 14.0))
	pts.append(Vector2(w + 10, h + 10))
	Art.toon(ci, pts, Color("2a2f5e"), 3.0, 0.4)
	Art.push(ci, Vector2(w * 0.7, floor_y + 20), 0.3)
	Props.anchor(ci)
	Art.pop(ci)
