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
	WorldLook.apply(WorldLook.location_now())
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
				"color": [Color("ffd23f"), Color("ff7b54"), Color("7be0ff"), Color("ff9fd0"), Color("b6f36a")][i], "i": i})
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
## Everything on every frame (see _schedule).
static var full_rate := false
## Rate of each half of the scene; FrameGovernor lowers it on slow devices.
static var anim_hz := ANIM_HZ
## A dialog is open over the dimmed scene: it animates slower (CALM_HZ).
static var calm := false
const CALM_HZ := 15.0
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
	var period := 1.0 / minf(minf(anim_hz, CALM_HZ if calm else ANIM_HZ), LOW_HZ if half_rate else ANIM_HZ)
	for g in 2:
		_since[g] += dt
		_fire[g] = _hurry
	_hurry = false
	# Only `full_rate` (tests, preview sheets) animates everything on every
	# frame. Everywhere else the two halves take turns at ANIM_HZ: what moves
	# across the screen (divers, boats, the lift's cabin) has its own canvas
	# items that move on every frame, so the scene still moves smoothly.
	if full_rate:
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
	if WorldLook.world in ["moon", "volcano"]:
		return -1
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
	# A new location (or a loaded save): new colors everywhere and its
	# name shown for a moment.
	var loc := WorldLook.location_now()
	if WorldLook.apply(loc):
		_painted_light = -1.0
		_painted_tint = -1.0
		_bubbles.clear()
		repaint_still()
		for row in rows:
			row._check_now = true
		if loc > 0:
			show_world_name(loc)
	_apply_night_tint()
	for i in range(_shooting.size() - 1, -1, -1):
		var s: Dictionary = _shooting[i]
		s["age"] = float(s["age"]) + delta
		s["p"] = s["p"] + s["v"] * delta
		if float(s["age"]) > 1.1:
			_shooting.remove_at(i)
	if _rng.randf() < delta * 0.05 * DayNight.night():
		shooting_star(Vector2(_rng.randf_range(0.1, 0.8) * size.x, _rng.randf_range(40.0, 220.0)))
	if _bubbles.size() < 12 and _rng.randf() < delta * 4.0 and WorldLook.is_water():
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
	elif sky_on and DayNight.starlight() > 0.02 and tick(SCENERY) and tick_count(SCENERY) % 4 == 0:
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
		if WorldLook.is_water():
			for i in 6:
				Art.seaweed(self, Vector2(w * (0.08 + i * 0.17), floor_y + 20), 60 + (i % 3) * 22, WorldLook.color("weed").darkened(0.3), t, i)
		else:
			_draw_bottom_life(w, floor_y)


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
	var starlight := DayNight.starlight()
	if starlight > 0.02:
		for s in _stars:
			var tw := 0.55 + 0.45 * sin(t * (1.3 + s.z) + s.x * 40.0)
			Props.star(ci, Vector2(s.x * w, s.y), s.z, Color(1.0, 0.97, 0.85, starlight * tw))
	if WorldLook.world == "moon":
		# Phones: small, in the strip of sky under the stage cards.
		var vp := get_viewport_rect().size
		var phone := vp.x < vp.y
		Art.push(ci, Vector2(w * 0.52, SURFACE_Y - 98.0) if phone else Vector2(w * 0.68, 140.0), 0.0, Vector2.ONE * (0.62 if phone else 1.0))
		WorldArt.earth(ci, Vector2.ZERO, t)
		Art.pop(ci)


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
		if WorldLook.world == "moon":
			# On the moon, a ringed planet rises at night instead.
			WorldArt.planet(ci, t, 1.0 if k < 0.85 else 0.0)
		else:
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
		if band.x > TOP_H and not WorldLook.is_water():
			# The dry worlds: deep cave air under the last site.
			c0 = WorldLook.shaft_color(1.0) * DayNight.deep_tint()
			c1 = c0.darkened(0.3)
		elif band.x < TOP_H and WorldLook.world == "volcano":
			WorldArt.magma_still(ci, w, band.x, band.y)
			continue
		elif band.x < TOP_H and WorldLook.world != "ocean":
			c1 = Art.calm(Art.sea_cols[0].lerp(Art.sea_cols[1], 0.75)) * DayNight.sea_tint()
		Art.grad(ci, PackedVector2Array([Vector2(0, band.x), Vector2(w, band.x), Vector2(w, band.y), Vector2(0, band.y)]), PackedColorArray([c0, c0, c1, c1]))


## Glittering path of sun or moon light on the water.
func _draw_reflection(w: float) -> void:
	if WorldLook.world in ["volcano", "moon"]:
		return
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


## What lives above the first site: light rays, fish and seaweed in the
## sea; magma bubbles and fire fish in the lava; reeds, bubbles and frog
## fish in the swamp; drifting dust in the moon's dust sea.
func _draw_top_water(w: float) -> void:
	var day := DayNight.daylight()
	var tint := DayNight.deep_tint(DayNight.stepped_phase())
	var wl := WorldLook.world
	if wl == "ocean":
		for i in 5:
			var x := w * (0.1 + i * 0.2) + sin(t * 0.3 + i) * 16.0
			var ray := Color(1, 1, 1, 0.07 * (0.2 + 0.8 * day))
			Art.grad(self, PackedVector2Array([Vector2(x - 14, SURFACE_Y), Vector2(x + 14, SURFACE_Y),
					Vector2(x + 70, TOP_H), Vector2(x + 20, TOP_H)]), PackedColorArray([ray, ray, Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	elif wl == "volcano":
		# Thick magma: slow currents, sinking crust, heavy bubbles (no fish).
		WorldArt.magma_body(self, w, SURFACE_Y, TOP_H - 14.0, t)
	elif wl == "acid":
		for i in 6:
			var f := fposmod(t * 0.1 + i * 0.41, 1.0)
			var x := w * fposmod(i * 0.23 + 0.1, 1.0) + sin(t * 1.4 + i) * 5.0
			var y := lerpf(TOP_H - 26.0, SURFACE_Y + 8.0, f)
			var r := 3.0 + (i % 3) * 1.6
			Art.arc(self, Vector2(x, y), r, 0, TAU, 10, Color(0.85, 1.0, 0.6, 0.65), 1.6)
	if wl == "ocean" or wl == "acid":
		for f in _fish:
			var dart := exp(-(t - float(f["dart"])) * 2.5)
			var face: float = f["face"]
			if absf(face) < 0.15:
				face = 0.15 * signf(face) if face != 0.0 else 0.15
			Art.fish(self, _fish_pos(f, w), f["size"], _fish_color(f) * tint, face, t * (1.0 + dart * 2.0) + f["y"])
	else:
		# Dust motes drifting in the moon's dust sea.
		for i in 8:
			var f := fposmod(t * 0.02 + i * 0.13, 1.0)
			var p := Vector2(f * (w + 40.0) - 20.0, SURFACE_Y + 30.0 + (i * 37 % 110) + sin(t * 0.7 + i) * 6.0)
			Art.dot(self, p, 2.0, Color(1, 1, 1, 0.35))
	var weed: Color = WorldLook.color("weed")
	if wl == "ocean":
		for i in 5:
			var x := SHAFT_R + 60.0 + i * (w - SHAFT_R - 120.0) / 4.0
			Art.seaweed(self, Vector2(x, TOP_H - 22), 40 + (i % 3) * 16, weed * tint, t, i)
	elif wl == "acid":
		for i in 5:
			var x := SHAFT_R + 60.0 + i * (w - SHAFT_R - 120.0) / 4.0
			Art.seaweed(self, Vector2(x, TOP_H - 22), 54 + (i % 3) * 20, Color("4fae4a") * tint, t * 0.7, i, 7.0)


## Fish colors fit the world (fire fish in lava, frog fish in the swamp).
func _fish_color(f: Dictionary) -> Color:
	var i := int(f["i"])
	match WorldLook.world:
		"volcano":
			return [Color("ffe066"), Color("ff5a3a"), Color("ff9a2a"), Color("ffd0a0"), Color("ff3d6e")][i % 5]
		"acid":
			return [Color("c8ff5a"), Color("b07aff"), Color("5ae0c8"), Color("ff9fd0"), Color("ffe14a")][i % 5]
	return f["color"]


static var _FLOE := Art.smooth_pts(PackedVector2Array([Vector2(-30, 0), Vector2(-24, -9), Vector2(-6, -12), Vector2(14, -10),
		Vector2(28, -6), Vector2(32, 2), Vector2(18, 9), Vector2(-16, 8)]), 3)


## Ice floes bobbing on the cold sea (half under the front wave).
func _draw_ice(w: float) -> void:
	var tint := DayNight.scene_tint(DayNight.stepped_phase())
	for f: Vector3 in [Vector3(0.04, 0.6, 0.0), Vector3(0.21, 0.75, 1.7), Vector3(0.39, 0.55, 3.1), Vector3(0.53, 0.8, 4.4), Vector3(0.7, 0.6, 5.2), Vector3(0.93, 0.85, 2.3)]:
		var p := Vector2(w * f.x, SURFACE_Y + 6.0 + sin(t * 1.3 + f.z) * 1.5)
		Art.push(self, p, sin(t * 0.9 + f.z) * 0.04, Vector2(f.y, f.y))
		Art.toon(self, _FLOE, Color("f4fbff") * tint, 2.5, 0.6)
		Art.flat(self, Art.clipped(Art.moved(_FLOE, Vector2(0, 8)), _FLOE), Color("cfe8f7") * tint)
		Art.pop(self)


## The slope above the first site (sand, basalt, mud or moon dust) with a
## few things lying on it (a still layer over the seaweed roots).
func _paint_ground(ci: CanvasItem) -> void:
	var w := size.x
	var tint := DayNight.deep_tint(DayNight.stepped_phase())
	var top := PackedVector2Array([Vector2(SHAFT_R, TOP_H + 4)])
	for i in 13:
		var x := lerpf(SHAFT_R, w + 10.0, i / 12.0)
		top.append(Vector2(x, TOP_H - 22.0 - sin(i * 1.3) * 5.0 - (7.0 if i % 3 == 0 else 0.0)))
	top.append(Vector2(w + 10, TOP_H + 4))
	var ground := WorldLook.color("sand") * tint
	Art.toon(ci, top, ground, WorldLook.EDGE, 0.6)
	var left := PackedVector2Array([Vector2(-10, TOP_H + 4), Vector2(-10, TOP_H - 26), Vector2(20, TOP_H - 30), Vector2(SHAFT_L, TOP_H - 18), Vector2(SHAFT_L, TOP_H + 4)])
	Art.toon(ci, left, ground, WorldLook.EDGE, 0.6)
	var spots: Array[Vector2] = [Vector2(SHAFT_R + 40, TOP_H - 22), Vector2(w * 0.55, TOP_H - 26), Vector2(w * 0.82, TOP_H - 24)]
	for k in spots.size():
		var p := spots[k]
		match WorldLook.world:
			"ocean":
				if k < 2:
					Art.push(ci, p, 0.2)
					Props.shell(ci, Color("ffb3c7") * tint)
					Art.pop(ci)
			"volcano":
				Art.push(ci, p + Vector2(0, 4), 0.0, Vector2.ONE * (1.0 - k * 0.15))
				WorldArt.hot_rock(ci, tint, k)
				Art.pop(ci)
			"acid":
				Art.push(ci, p + Vector2(0, 4), 0.0, Vector2.ONE * (0.8 + (k % 2) * 0.3))
				WorldArt.mushroom(ci, [Color("ff6fae"), Color("c86bff"), Color("ffd23f")][k] * tint, 0.0, k)
				Art.pop(ci)
			"moon":
				Art.push(ci, p + Vector2(0, 6), 0.0, Vector2.ONE * (1.0 - k * 0.2))
				WorldArt.crater(ci, ground, 30.0)
				Art.pop(ci)


## The bottom of the world under the last site (a still layer): the sea
## floor with an old anchor, or in the dry worlds the mountain's deep rock
## with a magma pool, a glowing acid pool or a crystal cave.
func _paint_floor(ci: CanvasItem) -> void:
	var w := size.x
	var h := height()
	var floor_y := h - BOTTOM_H + 60.0
	var pts := PackedVector2Array([Vector2(-10, h + 10)])
	for i in 13:
		pts.append(Vector2(w * i / 12.0, floor_y + sin(i * 1.7) * 14.0))
	pts.append(Vector2(w + 10, h + 10))
	var bed: Color = WorldLook.color("seabed")
	Art.toon(ci, pts, bed, WorldLook.EDGE, 0.4)
	# A lit top on the floor, so it stands out from the deep water.
	Art.polyline(ci, Art.moved(pts.slice(1, pts.size() - 1), Vector2(0, 5)), bed.lerp(Color.WHITE, 0.16), 5.0)
	match WorldLook.world:
		"ocean":
			Art.push(ci, Vector2(w * 0.7, floor_y + 20), 0.3)
			Props.anchor(ci)
			Art.pop(ci)
		"volcano":
			Art.push(ci, Vector2(w * 0.62, floor_y + 34))
			WorldArt.pool(ci, Color("ff7a1e"), Color("ffd45a"), 1.6)
			Art.pop(ci)
			for k in 3:
				Art.push(ci, Vector2(w * (0.18 + k * 0.3), floor_y + 22 + k * 3), 0.0, Vector2.ONE * (1.3 - k * 0.2))
				WorldArt.hot_rock(ci, Color.WHITE, k)
				Art.pop(ci)
		"acid":
			Art.push(ci, Vector2(w * 0.62, floor_y + 34))
			WorldArt.pool(ci, Color("7ad84a"), Color("e0ff9a"), 1.6)
			Art.pop(ci)
			for k in 4:
				Art.push(ci, Vector2(w * (0.12 + k * 0.24), floor_y + 26), 0.0, Vector2.ONE * (1.4 - (k % 2) * 0.4))
				WorldArt.mushroom(ci, [Color("ff6fae"), Color("c86bff"), Color("5ad8ff"), Color("ffd23f")][k], 0.0, k)
				Art.pop(ci)
		"moon":
			for k in 3:
				Art.push(ci, Vector2(w * (0.22 + k * 0.28), floor_y + 30), 0.0, Vector2.ONE * (1.2 - k * 0.2))
				WorldArt.crystal_cluster(ci, [Color("9fe0ff"), Color("c8a0ff"), Color("8affd0")][k])
				Art.pop(ci)
	_paint_rock_end(ci, w, h - BOTTOM_H)


## The underside of the last site's rock: an outlined, uneven rock edge and
## the dive shaft closed by a rounded stone bottom (the rows cover the top).
## Deep rock is dark, so a lighter lip runs along both outlines and the
## shaft's end is lit from inside: the end reads clearly.
func _paint_rock_end(ci: CanvasItem, w: float, top: float) -> void:
	var last := Balance.DEPTHS.size() - 1
	var rock: Color = Art.calm(WorldLook.room_style(last)["rock"])
	var lip := rock.lerp(Color.WHITE, 0.28)
	var edge := PackedVector2Array([Vector2(-10, top - 12)])
	edge.append(Vector2(w + 10, top - 12))
	var under := PackedVector2Array()
	for i in 15:
		var x := lerpf(w + 10.0, -10.0, i / 14.0)
		var y := top + 16.0 + sin(i * 2.3 + 1.0) * 5.0 + (6.0 if i % 4 == 1 else 0.0)
		# Deeper under the shaft, so the shaft's bottom sits in rock.
		var near := clampf(1.0 - absf(x - (SHAFT_L + SHAFT_R) / 2.0) / 90.0, 0.0, 1.0)
		under.append(Vector2(x, y + near * 30.0))
	edge.append_array(under)
	Art.toon(ci, edge, rock, OUTLINE, 0.0)
	Art.flat(ci, Art.clipped(Art.moved(edge, Vector2(0, -9)), edge), Art.shade_of(rock, 0.18))
	Art.polyline(ci, Art.moved(under, Vector2(0, -5)), Color(lip, 0.55), 2.5)
	# The shaft's end: water down to a rounded stone floor, walls outlined
	# like the shaft above.
	var water: Color = Art.calm(Art.water_color(0.82)) if WorldLook.is_water() else WorldLook.shaft_color(0.85)
	var r := 18.0
	var floor_y := top + 34.0
	var sump := PackedVector2Array([Vector2(SHAFT_L, top - 12), Vector2(SHAFT_R, top - 12)])
	for i in 9:
		var a := lerpf(0.0, PI / 2.0, i / 8.0)
		sump.append(Vector2(SHAFT_R - r + cos(a) * r, floor_y - r + sin(a) * r))
	for i in 9:
		var a := lerpf(PI / 2.0, PI, i / 8.0)
		sump.append(Vector2(SHAFT_L + r + cos(a) * r, floor_y - r + sin(a) * r))
	var wall := sump.slice(2)
	wall.insert(0, Vector2(SHAFT_R, top - 12))
	wall.append(Vector2(SHAFT_L, top - 12))
	# A stone lip around the end, then the water and its outline.
	Art.polyline(ci, Art.moved(wall, Vector2(0, 0)), lip, OUTLINE + 6.0)
	Art.flat(ci, sump, water)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2((SHAFT_L + SHAFT_R) / 2.0, floor_y - 10.0), Vector2(30, 18), 20), sump), water.lightened(0.12))
	Art.polyline(ci, wall, Art.INK, OUTLINE)
	# Pebbles on the shaft floor.
	for p: Vector3 in [Vector3(SHAFT_L + 16, floor_y - 7, 6), Vector3(SHAFT_L + 31, floor_y - 6, 4.5), Vector3(SHAFT_R - 18, floor_y - 7, 5.5)]:
		Art.t_ellipse(ci, Vector2(p.x, p.y), Vector2(p.z * 1.3, p.z), lip, 2.0, 0.4)


## Outline width of the big scenery shapes (rock edges, shaft walls).
const OUTLINE := WorldLook.EDGE


# --- New location banner -----------------------------------------------------------------

## Shows "Location N" and the world's name over the sea for a few seconds.
func show_world_name(n: int) -> void:
	var b := OceanBanner.new()
	b.title = tr("LOCATION_N") % (n + 1)
	b.name_text = WorldLook.name_of(n)
	b.position = Vector2(scene_right() / 2.0 if size.x > 900.0 else size.x / 2.0, SURFACE_Y - 130.0)
	add_child(b)


## Old name (screenshot scenarios and older callers).
func show_ocean_name(n: int) -> void:
	show_world_name(n)


## Life at the bottom of the dry worlds: embers over the magma pool,
## bubbles over the acid pool, sparkles in the moon's crystal cave.
func _draw_bottom_life(w: float, floor_y: float) -> void:
	for k in 6:
		var f := fposmod(t * 0.25 + k / 6.0, 1.0)
		match WorldLook.world:
			"volcano":
				var p := Vector2(w * 0.62 + sin(t + k * 1.7) * 30.0 * f - 30.0 + k * 12.0, floor_y + 30.0 - f * 120.0)
				Art.dot(self, p, 2.6 * (1.0 - f) + 0.8, Color(1.0, 0.75, 0.3, 1.0 - f))
			"acid":
				var p := Vector2(w * 0.62 - 40.0 + k * 16.0 + sin(t * 1.3 + k) * 4.0, floor_y + 30.0 - f * 90.0)
				Art.arc(self, p, 3.0 + f * 3.0, 0, TAU, 10, Color(0.85, 1.0, 0.6, 0.8 * (1.0 - f)), 1.6)
			_:
				var p := Vector2(w * (0.15 + k * 0.14), floor_y - 10.0 - (k % 3) * 20.0)
				var tw := snappedf(0.5 + 0.5 * sin(t * 2.4 + k * 1.9), 0.1)
				Art.push(self, p, 0.0, Vector2.ONE * (0.3 + tw * 0.6))
				Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.6, 4), Color(1, 1, 1, 0.8), 0.0, 0.0)
				Art.pop(self)


class OceanBanner extends Control:
	const LIFE := 4.2
	var title := ""
	var name_text := ""
	var age := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 5

	func _process(delta: float) -> void:
		age += delta
		if age > LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var font := UiTheme.heavy_font()
		var w := maxf(font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x, font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x) + 70.0
		var pop := clampf(age / 0.35, 0.0, 1.0)
		var s := 0.6 + 0.4 * (1.0 - pow(1.0 - pop, 3.0)) + sin(pop * PI) * 0.08
		var fade := clampf((LIFE - age) / 0.6, 0.0, 1.0)
		modulate.a = fade
		Art.push(self, Vector2.ZERO, 0.0, Vector2(s, s))
		Art.t_rect(self, Rect2(-w / 2.0, -52, w, 104), 24, Art.CREAM, 4.0, 0.4)
		Art.t_rect(self, Rect2(-w / 2.0 + 14, -40, w - 28, 26), 13, Color("bfe8ff"), 0.0, 0.0)
		Art.text(self, Vector2(0, -19), title, 26, Color("1c7fb8"), 0)
		Art.text(self, Vector2(0, 34), name_text, 46, Art.INK, 0)
		Art.pop(self)
