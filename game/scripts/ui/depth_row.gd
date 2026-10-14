class_name DepthRow
extends Control
## One dive site: a cave cut into layered rock, the dive shaft on the
## left, an ore vein at the far end and the site's card on the right.
## Closed sites are boarded up; the next one shows an Open button.

const CAVE_TOP := 26.0
const CAVE_BOTTOM := 234.0
const LEDGE_Y := 200.0
## Middle of the padlock in a far closed site (its "???" sits under it).
const LOCK_Y := 92.0
## Rows this close to the screen count as shown (they refresh and repaint).
const ROW_MARGIN := 300.0

var world: World
var index := 0

var card: StageCard
var _open_btn: PriceButton
var _lock_label: Label
var _t := 0.0
var _flash := 0.0
var _bg: PaintLayer
## The cave's edge, drawn over the glowing vein (still, like _bg).
var _edge: PaintLayer
var _bg_sig := []
## Skipped a refresh while far off screen (see refresh_if_shown).
var _stale := false
var _check_now := true
## The cave outline of the frame being drawn (decor clips light to it).
var _cp := PackedVector2Array()


func key() -> String:
	return "d%d" % index


func style() -> Dictionary:
	return WorldLook.room_style(index)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bg = PaintLayer.new(_draw_bg)
	add_child(_bg)
	_edge = PaintLayer.new(_draw_edge, false)
	add_child(_edge)
	card = StageCard.new(key())
	card.world = world
	card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(card)

	_lock_label = Label.new()
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock_label.add_theme_font_override("font", UiTheme.heavy_font())
	_lock_label.add_theme_font_size_override("font_size", 28)
	add_child(_lock_label)
	_open_btn = PriceButton.new()
	_open_btn.theme_type_variation = &"GoldButton"
	_open_btn.custom_minimum_size = Vector2(270, 74)
	_open_btn.pressed.connect(_on_open)
	add_child(_open_btn)
	GameState.cycle_finished.connect(_on_cycle_finished)
	GameState.depth_opened.connect(_on_depth_opened)
	refresh()


func _on_open() -> void:
	if Scroller.is_drag():
		return
	if GameState.open_depth(key()):
		Sfx.play("unlock")
		_flash = 1.0
	else:
		Sfx.play("deny")


func _on_depth_opened(_k: String) -> void:
	_check_now = true


func _on_cycle_finished(k: String, _amount: float) -> void:
	if k == key():
		_flash = maxf(_flash, 0.4)


func repaint_still() -> void:
	_bg.queue_redraw()
	_edge.queue_redraw()


## Periodic refresh from Main: sites far off screen wait until they show.
func refresh_if_shown() -> void:
	if world.is_visible_band(position.y - ROW_MARGIN, position.y + size.y + ROW_MARGIN):
		refresh()
	else:
		_stale = true


func refresh() -> void:
	_stale = false
	var open := GameState.is_open(key())
	card.visible = open
	var is_next := GameState.next_depth() == key()
	_open_btn.visible = not open and is_next
	_lock_label.visible = not open
	var name := WorldLook.site_name(index)
	if not open:
		_lock_label.text = name if is_next else "???"
		_open_btn.set_price(tr("OPEN"), NumFormat.short(GameState.unlock_cost(key())))
		_open_btn.theme_type_variation = &"GoldButton" if GameState.coins >= GameState.unlock_cost(key()) else &"DarkButton"
	else:
		card.refresh()
	_notification(NOTIFICATION_RESIZED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _lock_label:
		card.position = Vector2(world.card_x(), 16)
		var cx := (World.CAVE_L + world.scene_right()) / 2.0
		if not GameState.is_open(key()):
			cx = size.x / 2.0
		_lock_label.size = Vector2(size.x - 80, 40)
		var far := not GameState.is_open(key()) and GameState.next_depth() != key()
		_lock_label.position = Vector2(cx - _lock_label.size.x / 2.0, LOCK_Y + 34.0 if far else 64.0)
		_open_btn.size = _open_btn.custom_minimum_size
		_open_btn.position = Vector2(cx - _open_btn.size.x / 2.0, 118)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag() or not GameState.is_open(key()):
			return
		World.hurry()
		if event.position.x < world.scene_right():
			if GameState.tap(key()):
				Sfx.play("dive")
			else:
				Sfx.play("tap")
			world.divers.tap_ripple(event.position + position)


func deposit_pos() -> Vector2:
	return Vector2(world.scene_right() - 58.0, LEDGE_Y)


func ledge_y() -> float:
	return LEDGE_Y


func cave_rect() -> Rect2:
	return Rect2(World.CAVE_L, CAVE_TOP, world.scene_right() - World.CAVE_L, CAVE_BOTTOM - CAVE_TOP)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	# Keep the lock label centered when the site opens or closes.
	if _lock_label.visible != (not GameState.is_open(key())):
		_notification(NOTIFICATION_RESIZED)
	var shown := world.is_visible_band(position.y, position.y + size.y)
	if _stale and shown:
		refresh()
	# The cave life moves slowly: each site redraws on the SCENERY frames of
	# the world; on low power on every other one (neighbors alternate),
	# about 15 times a second.
	if shown and World.tick(World.SCENERY) and (not Art.low_power or (World.tick_count(World.SCENERY) + index) % 2 == 0):
		queue_redraw()
	# The still background repaints only when something it shows changes
	# (checked every few frames, rows taking turns, or right after a site opens).
	if not _check_now and (Engine.get_process_frames() + index) % 6 != 0:
		return
	_check_now = false
	var sig := [GameState.is_open(key()), GameState.next_depth() == key(), size, TranslationServer.get_locale(), WorldLook.location]
	if sig != _bg_sig:
		_bg_sig = sig
		_bg.queue_redraw()
		_edge.queue_redraw()


func _draw_bg(ci: CanvasItem) -> void:
	var st := style()
	var rock: Color = Art.calm(st["rock"])
	var w := size.x
	var h := World.ROW_H
	# Rock layer with strata and pebbles.
	# Rock lit a little from above, darker towards the next layer.
	var rock_hi := rock.lightened(0.07)
	var rock_lo := rock.darkened(0.1)
	Art.grad(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([rock_hi, rock_hi, rock_lo, rock_lo]))
	var jungle := WorldLook.world == "jungle"
	if WorldLook.world == "volcano":
		_basalt(ci, w, h, rock)
	elif jungle:
		_temple_masonry(ci, w, h, rock)
	for i in (0 if WorldLook.world == "volcano" or jungle else 3):
		var y := 40.0 + i * 78.0
		var band := PackedVector2Array()
		for k in 9:
			band.append(Vector2(lerpf(-10, w + 10, k / 8.0), y + sin(k * 1.9 + index * 2.0 + i) * 7.0))
		for k in 9:
			band.append(Vector2(lerpf(w + 10, -10, k / 8.0), y + 18.0 + sin((8 - k) * 1.7 + index + i) * 6.0))
		Art.flat(ci, band, Art.shade_of(rock, 0.1))
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 7), Vector2(0, 7)]), Art.shade_of(rock, 0.3))
	_wall_details(ci, w, h, rock)
	if not jungle:
		_rock_texture(ci, w, h, rock)
	# The shaft the divers use.
	var shaft := Rect2(World.SHAFT_L, -2, World.SHAFT_R - World.SHAFT_L, h + 4)
	var f := 0.15 + index * 0.85 / maxf(1.0, World.site_rows() - 1.0)
	var water: Color = Art.calm(Art.water_color(f)) if WorldLook.is_water() else WorldLook.shaft_color(f)
	Art.grad(ci, PackedVector2Array([shaft.position, Vector2(shaft.end.x, shaft.position.y), shaft.end, Vector2(shaft.position.x, shaft.end.y)]), PackedColorArray([water, water, water.darkened(0.1), water.darkened(0.1)]))
	# Cave and the passage from the shaft.
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	var inner: Color = Art.calm(st["water"])
	Art.toon(ci, cave_poly, inner, WorldLook.EDGE, 0.0)
	# Soft darker back wall.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(cave.get_center() + Vector2(0, -20), Vector2(cave.size.x * 0.42, cave.size.y * 0.36), 30), cave_poly), inner.lightened(0.08))
	if WorldLook.world == "volcano":
		_magma_cave_light(ci, cave, cave_poly, inner)
	elif jungle:
		_temple_hall(ci, cave, cave_poly, inner, st)
	else:
		_light_beams(ci, cave, cave_poly)
	Art.flat(ci, PackedVector2Array([Vector2(World.SHAFT_L + 4, 120), Vector2(World.SHAFT_R + 2, 120), Vector2(World.SHAFT_R + 2, CAVE_BOTTOM - 2), Vector2(World.SHAFT_L + 4, CAVE_BOTTOM - 2)]), inner)
	# Shaft walls.
	for x: float in [World.SHAFT_L, World.SHAFT_R]:
		var y1 := 118.0 if x == World.SHAFT_R else h + 2.0
		Art.line(ci, Vector2(x, -2), Vector2(x, y1), Art.INK, WorldLook.EDGE)
		if x == World.SHAFT_R:
			Art.line(ci, Vector2(x, CAVE_BOTTOM), Vector2(x, h + 2), Art.INK, WorldLook.EDGE)
	# Wooden brace across the shaft (bamboo and vines in the jungle).
	if jungle:
		_jungle_shaft(ci, h)
	else:
		Art.t_rect(ci, Rect2(World.SHAFT_L - 8, 6, World.SHAFT_R - World.SHAFT_L + 16, 12), 4, Art.WOOD_DARK, 2.5, 0.3)
	if not GameState.is_open(key()):
		_draw_closed(ci, cave, cave_poly)
		return
	# Floor.
	var floor_pts := PackedVector2Array([Vector2(World.SHAFT_L, LEDGE_Y + 4)])
	for k in 10:
		floor_pts.append(Vector2(lerpf(World.SHAFT_L + 20.0, cave.end.x, k / 9.0), LEDGE_Y - 3.0 + sin(k * 2.1 + index) * 3.0))
	floor_pts.append(Vector2(cave.end.x + 10, CAVE_BOTTOM + 10))
	floor_pts.append(Vector2(World.SHAFT_L, CAVE_BOTTOM + 10))
	_back_silhouettes(ci, cave, cave_poly, inner)
	Art.flat(ci, Art.clipped(floor_pts, cave_poly), st["floor"])
	if jungle:
		_temple_floor(ci, cave, cave_poly, st["floor"])
	else:
		_floor_texture(ci, cave, cave_poly, st["floor"])
	if WorldLook.world == "volcano":
		_magma_channel(ci)
	# Mine frame (metal supports on the moon).
	Art.push(ci, Vector2(World.CAVE_L + 22, LEDGE_Y + 2))
	if WorldLook.world == "moon":
		_metal_frame(ci, 150, 76)
	elif jungle:
		_stone_portal(ci, 150, 76, st)
	else:
		Props.mine_frame(ci, 150, 76)
	Art.pop(ci)
	_room_furniture(ci, cave)
	# Depth sign.
	Art.push(ci, Vector2(World.CAVE_L + 60, CAVE_TOP + 48), -0.04)
	if jungle:
		# A carved stone plaque instead of a wooden sign.
		Art.t_rect(ci, Rect2(-44, -19, 88, 38), 5, Color("cdb882"), 3.0, 0.5)
		Art.t_rect(ci, Rect2(-39, -15, 78, 30), 4, Color("eadcae"), 0.0, 0.0)
		for x: float in [-44.0, 44.0]:
			Art.t_circle(ci, Vector2(x, 0), 4.0, Color("34c88a") if index < 6 else Color("ffc93c"), 1.8, 0.0)
	else:
		Art.t_rect(ci, Rect2(-40, -17, 80, 34), 6, Art.CREAM, 3.0, 0.3)
	Art.text(ci, Vector2(0, 8), tr("DEPTH_METERS") % ((index + 1) * 50), 20, Art.INK, 0)
	Art.pop(ci)


## Far rocks and weeds in the blue behind the floor (water worlds): depth.
func _back_silhouettes(ci: CanvasItem, cave: Rect2, cave_poly: PackedVector2Array, inner: Color) -> void:
	if not WorldLook.is_water():
		return
	var far := Color(inner.darkened(0.22), 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 53 + 11
	var x := cave.position.x + 40.0
	var hills := PackedVector2Array([Vector2(cave.position.x, LEDGE_Y + 6)])
	while x < cave.end.x:
		hills.append(Vector2(x, LEDGE_Y - rng.randf_range(16, 46)))
		x += rng.randf_range(50, 90)
	hills.append(Vector2(cave.end.x, LEDGE_Y - 20))
	hills.append(Vector2(cave.end.x, LEDGE_Y + 6))
	Art.flat(ci, Art.clipped(hills, cave_poly), far)
	# Tall swaying weeds, still here (the living ones are in front).
	for i in 4:
		var bx := lerpf(cave.position.x + 70.0, cave.end.x - 60.0, (i + rng.randf()) / 4.0)
		var hgt := rng.randf_range(50, 90)
		var stem := PackedVector2Array()
		for k in 6:
			var u := k / 5.0
			stem.append(Vector2(bx + sin(u * 3.0 + i) * 8.0, LEDGE_Y - u * hgt))
		Art.polyline(ci, stem, Color(inner.darkened(0.3), 0.45), 7.0)


## Sand on the cave floor: a lit lip, ripples and grains.
func _floor_texture(ci: CanvasItem, cave: Rect2, cave_poly: PackedVector2Array, sand: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 71 + 3
	var dark := Art.shade_of(sand, 0.28)
	# A darker band at the foot: the floor turns away from the light.
	var foot := PackedVector2Array([Vector2(World.SHAFT_L, CAVE_BOTTOM - 14), Vector2(cave.end.x + 10, CAVE_BOTTOM - 14),
			Vector2(cave.end.x + 10, CAVE_BOTTOM + 10), Vector2(World.SHAFT_L, CAVE_BOTTOM + 10)])
	Art.flat(ci, Art.clipped(foot, cave_poly), Color(dark, 0.35))
	# Ripples.
	for i in 7:
		var c := Vector2(rng.randf_range(cave.position.x + 60, cave.end.x - 40), rng.randf_range(LEDGE_Y + 8, CAVE_BOTTOM - 12))
		var wdt := rng.randf_range(18, 34)
		Art.line_c(ci, PackedVector2Array([c + Vector2(-wdt, 2), c + Vector2(-wdt * 0.4, -2), c + Vector2(wdt * 0.2, 1), c + Vector2(wdt, -1)]), Color(dark, 0.45), 2.0)
	# Grains.
	for i in 30:
		var p := Vector2(rng.randf_range(cave.position.x + 20, cave.end.x - 20), rng.randf_range(LEDGE_Y + 4, CAVE_BOTTOM - 6))
		Art.disc(ci, p, rng.randf_range(1.0, 2.2), Color(dark, 0.5) if i % 2 else Color(1, 1, 1, 0.35))


## Soft slanted beams of light through the water of the cave (static,
## drawn once with the background).
func _light_beams(ci: CanvasItem, cave: Rect2, cave_poly: PackedVector2Array) -> void:
	var glow := Color(1.0, 1.0, 0.9, 0.13)
	for i in 3:
		var x := cave.position.x + cave.size.x * (0.22 + 0.27 * i) + (index % 3) * 14.0
		var w := 34.0 + 18.0 * ((i + index) % 2)
		var beam := PackedVector2Array([Vector2(x, cave.position.y - 4), Vector2(x + w, cave.position.y - 4),
				Vector2(x + w + 70.0, cave.end.y + 4), Vector2(x + 40.0, cave.end.y + 4)])
		Art.flat(ci, Art.clipped(beam, cave_poly), glow)
	# Soft shade along the cave walls: the middle of the water glows.
	Art.flat(ci, Art.clipped(_wall_band(cave), cave_poly), Color(Art.SHADE, 0.13))
	# A darker band low in the water: depth under the light.
	var low := PackedVector2Array([Vector2(cave.position.x - 4, cave.end.y - cave.size.y * 0.42), Vector2(cave.end.x + 4, cave.end.y - cave.size.y * 0.42),
			Vector2(cave.end.x + 4, cave.end.y + 4), Vector2(cave.position.x - 4, cave.end.y + 4)])
	Art.flat(ci, Art.clipped(low, cave_poly), Color(Art.SHADE, 0.16))


## A ring a little inside the cave's edge (cached per cave size).
static var _bands := {}


func _wall_band(cave: Rect2) -> PackedVector2Array:
	var k := hash(cave)
	if _bands.has(k):
		return _bands[k]
	var outer := Art.rrect_pts(cave.grow(20.0), 52, 6)
	var inner := Art.rrect_pts(cave.grow(-22.0), 30, 6)
	# One polygon: the outer ring, a seam, then the inner ring backwards.
	var ring := PackedVector2Array(outer)
	ring.append(outer[0])
	var rev := inner.duplicate()
	rev.reverse()
	ring.append(inner[inner.size() - 1])
	ring.append_array(rev)
	_bands[k] = ring
	return ring


## The cave plus the doorway to the shaft. The doorway's floor runs on
## level with the cave floor (past the cave's rounded corner, so there is no
## bump next to the lift crate) and its side towards the shaft is open.
func _cave_poly() -> PackedVector2Array:
	var r := cave_rect()
	if r == _poly_rect and not _poly.is_empty():
		return _poly
	_poly_rect = r
	_poly = _make_cave_poly()
	return _poly


var _poly_rect := Rect2()
var _poly := PackedVector2Array()


func _make_cave_poly() -> PackedVector2Array:
	var door := PackedVector2Array([Vector2(World.SHAFT_R - 2.5, 118), Vector2(World.CAVE_L + 44, 118),
			Vector2(World.CAVE_L + 44, CAVE_BOTTOM), Vector2(World.SHAFT_R - 2.5, CAVE_BOTTOM)])
	return Art.union([Art.rrect_pts(cave_rect(), 38, 6), door])


static var _edges := {}


## The cave's outline without the doorway side: an open line that starts
## and ends inside the shaft walls (a closed ring drew a stray line between
## the shaft and the crate).
func _edge_pts(poly: PackedVector2Array) -> PackedVector2Array:
	var k := hash(poly)
	if _edges.has(k):
		return _edges[k]
	var n := poly.size()
	var out := poly
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if a.x < World.SHAFT_R and b.x < World.SHAFT_R:
			out = PackedVector2Array()
			for j in n:
				out.append(poly[(i + 1 + j) % n])
			break
	_edges[k] = out
	return out


func _cave_edge(ci: CanvasItem, poly: PackedVector2Array) -> void:
	var pts := _edge_pts(poly)
	if pts == poly:
		Art.ring(ci, poly, Art.INK, WorldLook.EDGE)
	else:
		Art.polyline(ci, pts, Art.INK, WorldLook.EDGE)


## The vein's glow, clipped to the cave once (it only changes with the hall).
var _glow_key := 0
var _glow_poly := PackedVector2Array()


## The moving parts: lantern, decor, the glowing ore vein.
func _draw() -> void:
	if not GameState.is_open(key()):
		return
	var st := style()
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	_cp = cave_poly
	if WorldLook.world == "volcano":
		_magma_channel_life()
	_draw_lamps(cave)
	_draw_decor(st, cave)
	if WorldLook.world == "jungle":
		_jungle_life(st, cave)
	# Ore vein, glowing on each delivery.
	var dp := deposit_pos()
	var glow := 0.12 + 0.05 * sin(_t * 2.0 + index) + _flash * 0.3
	var gk := hash([cave, LEDGE_Y])
	if gk != _glow_key:
		_glow_key = gk
		_glow_poly = Art.clipped(Art.circle_pts(Vector2(cave.end.x - 30, LEDGE_Y - 50), 90, 32), cave_poly)
	Art.flat(self, _glow_poly, Color(st["ore"], snappedf(glow, 0.02)))
	# The ore moves slowly: drawn four times a second (like the small veins
	# of the divers) and pasted from the cache in between.
	var tq := int(_t * 4.0 + (index % 4) / 4.0)
	var ck := hash([42, index, tq, dp, cave.end.x, WorldLook.location])
	if not Art.cache_begin(self, ck, true):
		var tt := tq / 4.0
		OreArt.deposit(self, Vector2(cave.end.x - 22, LEDGE_Y - 40), 46, index, index * 7 + 1, tt, 3, false)
		OreArt.deposit(self, Vector2(dp.x, LEDGE_Y + 2), 70, index, index * 31 + 3, tt, 5)
		Art.cache_end(self, ck, true)


## Edge of the cave, drawn again over the vein so the glow stays inside.
func _draw_edge(ci: CanvasItem) -> void:
	if GameState.is_open(key()):
		_cave_edge(ci, _cave_poly())
		if WorldLook.world == "jungle":
			_edge_drapes(ci, cave_rect())


func _draw_decor(st: Dictionary, cave: Rect2) -> void:
	var y := LEDGE_Y
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	if _draw_decor_world(st, cave) or _draw_decor_jungle(st, cave):
		return
	match st["deco"]:
		"shells":
			for p: Vector3 in [Vector3(x0, y + 2, 0.2), Vector3(mid + 30, y + 4, -0.3)]:
				Art.push(self, Vector2(p.x, p.y), p.z)
				Props.shell(self, Color("ffb3c7") if p.z > 0 else Color("ffd59e"))
				Art.pop(self)
			Art.push(self, Vector2(mid - 30, y + 6), 0.4)
			Props.starfish(self, Art.CORAL)
			Art.pop(self)
			Art.seaweed(self, Vector2(x1, y), 46, Color("47c47a"), _t, index)
		"coral":
			var cols := [Color("ff6f91"), Color("ffa84a"), Color("c86bff")] if index < 6 else [Color("4fc3ff"), Color("8f8cff"), Color("3fe0d0")]
			for i in 3:
				Art.push(self, Vector2(lerpf(x0, x1, i / 2.0), y + 2), 0.0, Vector2.ONE * (1.0 + (i % 2) * 0.3))
				Props.coral(self, cols[i], i + index, _t)
				Art.pop(self)
		"pearls":
			Art.push(self, Vector2(x0 + 10, y + 2))
			Props.clam(self, 0.5 + 0.5 * sin(_t * 1.2), Color("fbf8ff"))
			Art.pop(self)
			Art.push(self, Vector2(x1, y + 2), 0.0, Vector2(-1, 1))
			Props.clam(self, 0.5 + 0.5 * sin(_t * 1.2 + 2.0), Color("ffd6f0"))
			Art.pop(self)
			Art.seaweed(self, Vector2(mid, y), 60, Color("5fcf9a"), _t, index)
		"wreck":
			Art.push(self, Vector2(x0 + 6, y + 4), 0.15)
			Props.barrel(self)
			Art.pop(self)
			Art.push(self, Vector2(x1, y + 4), -0.4)
			Props.anchor(self)
			Art.pop(self)
		"kelp":
			for i in 4:
				Art.seaweed(self, Vector2(lerpf(x0 - 20, x1 + 20, i / 3.0), y), 110 + (i % 2) * 40, Color("35c98a"), _t, i + index, 11.0)
		"glow":
			var gc: Color = Color("8f7bff") if index < 6 else Color("b9c4ff")
			for i in 3:
				var cx := lerpf(x0, x1, i / 2.0)
				Art.crystal(self, Vector2(cx, y + 2), 26 + (i % 2) * 14, 8, -0.2 + i * 0.2, gc, 2.2)
			Art.push(self, Vector2(mid, CAVE_TOP + 90 + sin(_t) * 10.0))
			Props.jelly(self, _t, Color("ff9fe0") if index < 6 else Color("e6e8ff"))
			Art.pop(self)
		_:
			_draw_decor_deep(st, cave)


## Decor of the deeper sites (amber and below).
func _draw_decor_deep(st: Dictionary, cave: Rect2) -> void:
	var y := LEDGE_Y
	var top := CAVE_TOP + 4.0
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	match st["deco"]:
		"amber":
			# A fallen branch with drops of resin, and a firefly.
			Art.stroke(self, PackedVector2Array([Vector2(x0 - 30, y + 2), Vector2(x0 + 10, y - 6), Vector2(mid + 10, y - 2)]), Art.WOOD_DARK, 9.0, 2.5)
			Art.stroke(self, PackedVector2Array([Vector2(x0 + 10, y - 6), Vector2(x0 + 26, y - 26)]), Art.WOOD_DARK, 5.0, 2.2)
			OreArt.piece(self, "amber", Vector2(x0 - 4, y - 5), 0.5, 0.2, st, _t, 0)
			OreArt.piece(self, "amber", Vector2(mid - 10, y - 4), 0.4, -0.2, st, _t, 1)
			for k in 3:
				OreArt.piece(self, "amber", Vector2(lerpf(x0 - 20, x1 + 20, k / 2.0), top), 0.32 + k * 0.05, PI, st, _t, 1)
			var ff := Vector2(mid + sin(_t * 0.7) * 70.0, top + 70.0 + sin(_t * 1.9) * 18.0)
			Art.glow(self, ff, 16.0, Color(1.0, 0.85, 0.4, 0.45 + 0.2 * sin(_t * 9.0)), 12)
			Art.disc(self, ff, 2.6, Color("fff2b0"))
		"crystals":
			var c: Color = ore.lightened(0.1)
			for p: Vector3 in [Vector3(x0 - 10, 30, -0.3), Vector3(x0 + 8, 44, 0.1), Vector3(x1 + 10, 36, 0.25)]:
				Art.crystal(self, Vector2(p.x, y + 2), p.y, p.y * 0.22, p.z, c if p.y > 40 else ore2, 2.2)
			for p: Vector3 in [Vector3(x0 + 40, 26, 0.15), Vector3(mid + 20, 38, -0.1), Vector3(x1 - 10, 22, 0.2)]:
				Art.crystal(self, Vector2(p.x, top - 2), p.y, p.y * 0.2, PI + p.z, ore2 if p.y > 30 else c, 2.2)
			var tw := snappedf(0.5 + 0.5 * sin(_t * 3.0 + index), 0.05)
			Art.push(self, Vector2(x0 + 8, y - 42), _t, Vector2.ONE * (0.5 + tw * 0.6))
			Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.6, 4), Color(1, 1, 1, 0.9), 0.0, 0.0)
			Art.pop(self)
		"ice":
			for k in 7:
				var x := lerpf(x0 - 50, x1 + 60, k / 6.0)
				var h := 18.0 + float((k * 37 + index) % 5) * 7.0
				Art.push(self, Vector2(x, top - 2), 0.0, Vector2(1.0, h / 30.0))
				Art.toon(self, _ICICLE, Color("dff6ff"), 2.2, 0.0)
				Art.flat(self, _ICICLE_HI, Color(1, 1, 1, 0.8))
				Art.pop(self)
			for p: Vector3 in [Vector3(x0 - 6, 1.0, 0), Vector3(mid + 50, 0.8, 1)]:
				Art.push(self, Vector2(p.x, y + 4), 0.0, Vector2(p.y, p.y))
				Art.toon(self, _SNOW, Color("f4fbff"), 2.2, 0.5)
				Art.pop(self)
			for k in 5:
				var f := fposmod(_t * 0.08 + k * 0.2, 1.0)
				var sp := Vector2(lerpf(x0 - 40, x1 + 40, fposmod(k * 0.37, 1.0)) + sin(_t + k) * 12.0, lerpf(top + 10, y - 10, f))
				Art.push(self, sp, _t * 0.5 + k)
				Art.toon(self, _FLAKE, Color(1, 1, 1, snappedf(0.85 * sin(f * PI), 0.05)), 0.0, 0.0)
				Art.pop(self)
		"lava":
			var hot := snappedf(0.75 + 0.25 * sin(_t * 2.3), 0.05)
			Art.glow(self, Vector2(mid, y - 4), 70.0, Color(ore, 0.35 * hot), 16)
			Art.push(self, Vector2(mid, y + 1))
			Art.toon(self, _POOL, Color("3b2427"), 2.2, 0.0)
			Art.flat(self, _POOL_IN, Color(ore, 1.0))
			Art.flat(self, _POOL_CORE, Color(ore2, hot))
			Art.pop(self)
			for k in 3:
				var f := fposmod(_t * 0.5 + k * 0.37, 1.0)
				var bx := mid - 24.0 + k * 22.0
				Art.arc(self, Vector2(bx, y - 1), 2.0 + f * 5.0, PI, TAU, 8, Color(ore2, 1.0 - f), 2.0)
			# A vent puffing embers.
			Art.push(self, Vector2(x0 - 4, y + 2))
			Art.toon(self, _VENT, Color("4a2c2a"), 2.2, 0.4)
			Art.flat(self, Art.ellipse_pts(Vector2(0, -20), Vector2(5, 2), 10), Color(ore, hot))
			Art.pop(self)
			for k in 4:
				var f := fposmod(_t * 0.4 + k * 0.25, 1.0)
				var ep := Vector2(x0 - 4 + sin(_t * 2.0 + k * 1.7) * 8.0 * f, y - 20.0 - f * 90.0)
				Art.dot(self, ep, 2.2 * (1.0 - f) + 0.6, Color(ore2, 1.0 - f))
		"bones":
			# Whale ribs behind, a fish skeleton on the floor.
			var bone := Color("f1e6cc")
			for k in 4:
				var c := Vector2(x1 - 20 + k * 22, y + 20)
				Art.arc_c(self, c, 56.0 - k * 5.0, PI * 1.08, PI * 1.5, 10, Art.INK, 9.0)
				Art.arc_c(self, c, 56.0 - k * 5.0, PI * 1.08, PI * 1.5, 10, bone, 4.5)
			Art.stroke(self, PackedVector2Array([Vector2(x1 - 76, y - 34), Vector2(x1 + 50, y - 38)]), bone, 5.0, 2.2)
			Art.push(self, Vector2(x0, y - 4), -0.05)
			Art.stroke(self, PackedVector2Array([Vector2(-28, 0), Vector2(14, 0)]), bone, 3.0, 1.8)
			for k in 5:
				var rx := -20.0 + k * 7.0
				Art.stroke(self, PackedVector2Array([Vector2(rx, -7), Vector2(rx + 2, 7)]), bone, 2.2, 1.6)
			Art.toon(self, _FISH_TAIL, bone, 2.0, 0.0)
			Art.toon(self, _FISH_SKULL, bone, 2.0, 0.4)
			Art.flat(self, Art.circle_pts(Vector2(22, -3), 2.6, 10), Art.INK)
			Art.pop(self)
		"ruins":
			Art.push(self, Vector2(x0 - 16, y + 3), 0.04, Vector2(1.9, 1.9))
			OreArt.column(self)
			Art.pop(self)
			Art.push(self, Vector2(x1 + 16, y + 3), -0.06, Vector2(1.4, 1.1))
			OreArt.column(self)
			Art.pop(self)
			Art.push(self, Vector2(mid + 4, y + 2), 0.12)
			Art.t_rect(self, Rect2(-20, -16, 40, 16), 3, Color("c9d6ee"), 2.2, 0.5)
			Art.line_c(self, PackedVector2Array([Vector2(-12, -8), Vector2(12, -8)]), Color("8a9ab8"), 1.6)
			Art.pop(self)
			Art.seaweed(self, Vector2(mid - 40, y), 54, Color("3fbf8f"), _t, index)
			var rune := snappedf(0.5 + 0.5 * sin(_t * 1.6), 0.05)
			Art.arc(self, Vector2(mid, top + 70), 16.0, 0, TAU, 24, Color(ore, 0.25 + 0.35 * rune), 2.5)
			Art.toon(self, Art.star_pts(Vector2(mid, top + 70), 8, 3, 3), Color(ore, 0.3 + 0.4 * rune), 0.0, 0.0)
		"mushrooms":
			for p: Vector3 in [Vector3(x0 - 12, 0.55, 0), Vector3(x0 + 10, 0.4, 1), Vector3(mid + 30, 0.45, 2), Vector3(x1 + 14, 0.6, 3), Vector3(x1 - 6, 0.38, 4)]:
				OreArt.piece(self, "glow", Vector2(p.x, y + 2), p.y, 0.0, st, _t, int(p.z))
			for k in 7:
				var f := fposmod(_t * 0.07 + k * 0.143, 1.0)
				var sp := Vector2(lerpf(x0 - 40, x1 + 40, fposmod(k * 0.61, 1.0)) + sin(_t * 0.8 + k) * 10.0, lerpf(y - 10, top + 20, f))
				Art.dot(self, sp, 2.2, Color(ore, 0.8 * sin(f * PI)))
		"crater":
			Art.push(self, Vector2(mid, y + 2))
			Art.toon(self, _CRATER, Art.shade_of(st["floor"], 0.2), 2.2, 0.3)
			Art.flat(self, _CRATER_IN, Color("2a1830"))
			Art.pop(self)
			Art.glow(self, Vector2(mid, y - 2), 30.0, Color(ore, 0.35 + 0.15 * sin(_t * 3.0)), 12)
			for k in 3:
				var f := fposmod(_t * 0.25 + k * 0.33, 1.0)
				Art.dot(self, Vector2(mid + sin(k * 2.0 + _t) * 10.0, y - 6 - f * 60.0), 4.0 + f * 9.0, Color(0.8, 0.75, 0.9, 0.35 * (1.0 - f)))
			for p: Vector3 in [Vector3(x0 - 10, top + 60, 0.0), Vector3(x1 + 20, top + 84, 1.0)]:
				var bob := sin(_t * 1.2 + p.z * 2.0) * 6.0
				OreArt.piece(self, "meteor", Vector2(p.x, p.y + bob), 0.55, sin(_t * 0.6 + p.z) * 0.2, st, _t, int(p.z))
		"tentacles":
			var dark := Color("5a2a6a")
			Art.push(self, Vector2(x0 - 30, y + 6), 0.0, Vector2(2.2, 2.4))
			OreArt.tentacle(self, _t * 0.9, dark)
			Art.pop(self)
			Art.push(self, Vector2(x1 + 40, y + 6), 0.0, Vector2(-1.9, 2.0))
			OreArt.tentacle(self, _t * 0.9 + 2.0, dark)
			Art.pop(self)
			# Two eyes watching from a crack in the back wall; they blink.
			var open := 0.15 if Chars.blinking(_t * 0.5, index) else 1.0
			for sx: float in [-1.0, 1.0]:
				var e := Vector2(mid + sx * 16.0, top + 62)
				Art.glow(self, e, 16.0, Color(1.0, 0.85, 0.3, 0.3), 10)
				Art.push(self, e, 0.0, Vector2(1.0, open))
				Art.toon(self, _EYE, Color("ffd84a"), 2.0, 0.0)
				Art.flat(self, _PUPIL, Art.INK)
				Art.pop(self)
		"stars":
			for k in 9:
				var sp := Vector2(lerpf(x0 - 60, x1 + 70, fposmod(k * 0.377 + index * 0.1, 1.0)), lerpf(top + 16, y - 30, fposmod(k * 0.618, 1.0)))
				var tw := snappedf(0.5 + 0.5 * sin(_t * (2.0 + k * 0.3) + k), 0.05)
				Art.push(self, sp, 0.0, Vector2.ONE * (0.4 + tw * 0.7))
				Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.8, 4), Color(ore2, 0.5 + 0.5 * tw), 0.0, 0.0)
				Art.pop(self)
			# A shooting star every few seconds.
			var f := fposmod(_t * 0.25 + index, 1.0) / 0.25
			if f < 1.0:
				var a := Vector2(x1 + 60, top + 20).lerp(Vector2(x0 - 40, top + 80), f)
				Art.line(self, a, a + Vector2(34, -14), Color(ore, 0.5 * (1.0 - f)), 3.0)
				Art.dot(self, a, 3.0, Color(1, 1, 1, 1.0 - f * 0.5))
		"lanterns":
			for k in 3:
				Art.seaweed(self, Vector2(lerpf(mid - 30, mid + 40, k / 2.0), y), 80 + k * 20, Color("35c98a"), _t, k + index, 10.0)
			for x: float in [x0 - 6, x1 + 10]:
				Art.push(self, Vector2(x, y + 2))
				_stone_lantern(ore)
				Art.pop(self)
		_:
			_draw_decor_abyss(st, cave)


func _stone_lantern(light: Color) -> void:
	var stone := Color("9fb5ae")
	var flick := snappedf(0.8 + 0.2 * sin(_t * 7.0 + position.y), 0.05)
	Art.t_rect(self, Rect2(-14, -6, 28, 6), 2, stone, 2.2, 0.3)
	Art.t_rect(self, Rect2(-5, -30, 10, 24), 2, stone, 2.2, 0.3)
	Art.glow(self, Vector2(0, -40), 22.0, Color(light, 0.35 * flick), 12)
	Art.t_rect(self, Rect2(-10, -48, 20, 18), 3, stone, 2.2, 0.3)
	Art.flat(self, Art.rrect_pts(Rect2(-6, -45, 12, 12), 2), Color(1.0, 0.95, 0.7, flick))
	Art.toon(self, PackedVector2Array([Vector2(-18, -47), Vector2(18, -47), Vector2(8, -57), Vector2(-8, -57)]), Art.shade_of(stone, 0.2), 2.2, 0.3)
	Art.t_circle(self, Vector2(0, -60), 3.5, stone, 2.0, 0.0)


static var _ICICLE := PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0.5, 30)])
static var _ICICLE_HI := PackedVector2Array([Vector2(-2.5, 2), Vector2(-0.5, 2), Vector2(-0.3, 18)])
static var _FLAKE := PackedVector2Array([Vector2(0, -4), Vector2(1, -1), Vector2(4, 0), Vector2(1, 1), Vector2(0, 4), Vector2(-1, 1), Vector2(-4, 0), Vector2(-1, -1)])
static var _FISH_TAIL := PackedVector2Array([Vector2(-28, 0), Vector2(-38, -8), Vector2(-35, 0), Vector2(-38, 8)])
static var _FISH_SKULL := PackedVector2Array([Vector2(14, -8), Vector2(24, -9), Vector2(32, -2), Vector2(26, 5), Vector2(14, 7)])
static var _EYE := PackedVector2Array([Vector2(-9, 0), Vector2(-5, -4.5), Vector2(0, -5.5), Vector2(5, -4.5), Vector2(9, 0), Vector2(5, 4.5), Vector2(0, 5.5), Vector2(-5, 4.5)])
static var _PUPIL := PackedVector2Array([Vector2(-1.5, -4.5), Vector2(1.5, -4.5), Vector2(1.5, 4.5), Vector2(-1.5, 4.5)])
static var _SNOW := Art.smooth_pts(PackedVector2Array([Vector2(-34, 2), Vector2(-24, -9), Vector2(-8, -15), Vector2(10, -13),
		Vector2(26, -7), Vector2(34, 2)]), 3)
static var _POOL := Art.ellipse_pts(Vector2(0, -2), Vector2(46, 8), 24)
static var _POOL_IN := Art.ellipse_pts(Vector2(0, -2), Vector2(40, 5.5), 24)
static var _POOL_CORE := Art.ellipse_pts(Vector2(-4, -2.5), Vector2(24, 2.6), 18)
static var _VENT := PackedVector2Array([Vector2(-16, 0), Vector2(-6, -21), Vector2(6, -21), Vector2(16, 0)])
static var _CRATER := Art.ellipse_pts(Vector2(0, -3), Vector2(44, 10), 24)
static var _CRATER_IN := Art.ellipse_pts(Vector2(0, -3), Vector2(34, 6), 24)


func _draw_closed(ci: CanvasItem, cave: Rect2, cave_poly: PackedVector2Array) -> void:
	Art.flat(ci, cave_poly, Color(0.02, 0.04, 0.12, 0.55))
	var is_next := GameState.next_depth() == key()
	if is_next:
		Props.boards(ci, Rect2(cave.position.x + 20, cave.position.y + 30, cave.size.x - 40, cave.size.y - 60))
		# The card column rock is empty on closed rows: a lock there.
		Art.lock(ci, Vector2(world.card_x() + World.CARD_W / 2.0, World.ROW_H / 2.0), 30)
		_cave_edge(ci, cave_poly)
		return
	# Deeper, still unknown: darker towards the floor, dark rocks on the
	# ledge, a pair of curious eyes in the dark and the lock over the
	# "???" (drawn after the edge, so it never cuts through it).
	var deep := Color(0.01, 0.02, 0.08, 0.5)
	Art.grad(ci, PackedVector2Array([Vector2(cave.position.x, cave.position.y + cave.size.y * 0.4), Vector2(cave.end.x, cave.position.y + cave.size.y * 0.4),
			cave.end, Vector2(cave.position.x, cave.end.y)]), PackedColorArray([Color(deep, 0.0), Color(deep, 0.0), deep, deep]))
	var rock := Color(0.02, 0.04, 0.12, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 7 + 3
	for k in 4:
		var x := lerpf(cave.position.x + 50.0, cave.end.x - 60.0, (k + rng.randf_range(0.0, 0.6)) / 4.0)
		var w := rng.randf_range(26.0, 48.0)
		var h := rng.randf_range(16.0, 34.0)
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(x - w, LEDGE_Y + 4), Vector2(x - w * 0.6, LEDGE_Y - h * 0.7),
				Vector2(x - w * 0.1, LEDGE_Y - h), Vector2(x + w * 0.5, LEDGE_Y - h * 0.6), Vector2(x + w, LEDGE_Y + 4)]), 2), rock)
	_cave_edge(ci, cave_poly)
	# Left or right of the lock, never next to it.
	var side := rng.randf() < 0.5
	var ex := lerpf(cave.position.x + 60.0, size.x / 2.0 - 80.0, rng.randf()) if side else lerpf(size.x / 2.0 + 80.0, cave.end.x - 60.0, rng.randf())
	var eyes := Vector2(ex, LEDGE_Y - 46.0 - rng.randf_range(0.0, 50.0))
	for sx: float in [-9.0, 9.0]:
		Art.glow(ci, eyes + Vector2(sx, 0), 11.0, Color(1.0, 0.95, 0.55, 0.25), 12)
		Art.flat(ci, Art.ellipse_pts(eyes + Vector2(sx, 0), Vector2(4.5, 3.2), 12), Color(1.0, 0.96, 0.7, 0.85))
		Art.flat(ci, Art.ellipse_pts(eyes + Vector2(sx + 1.2, 0.4), Vector2(1.6, 2.2), 8), Color(0.1, 0.06, 0.2, 0.9))
	Art.lock(ci, Vector2(size.x / 2.0, LOCK_Y), 22)



## Decor of the abyss (hydrothermal vents and below): each site has its
## own set piece. Shapes are cached; motion goes through Art.push or snapped
## values, and light effects are clipped to the cave.
func _draw_decor_abyss(st: Dictionary, cave: Rect2) -> void:
	var y := LEDGE_Y
	var top := CAVE_TOP + 4.0
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	# 1 on wide screens, smaller in the narrow caves of phones.
	var fit := clampf((cave.end.x - World.CAVE_L) / 520.0, 0.55, 1.0)
	match st["deco"]:
		"vents":
			var hot := snappedf(0.75 + 0.25 * sin(_t * 2.1), 0.05)
			Art.glow(self, Vector2(x0 - 14, y - 70), 90.0, Color(1.0, 0.5, 0.2, 0.16 * hot), 16)
			Art.push(self, Vector2(x0 - 14, y + 2), 0.0, Vector2(2.0, 2.3))
			OreArt.abyss_piece(self, "vent", ore, ore2, _t, 1)
			Art.pop(self)
			Art.push(self, Vector2(x1 + 36, y + 2), 0.0, Vector2(1.5, 1.6))
			OreArt.abyss_piece(self, "vent", ore, ore2, _t * 0.9, 3)
			Art.pop(self)
			for k in 5:
				Art.push(self, Vector2(mid - 44 + k * 8, y + 3), sin(_t * 1.5 + k * 1.1) * 0.08)
				OreArt.tube_worm(self, 30.0 + float((k * 7) % 4) * 6.0)
				Art.pop(self)
			for p: Vector3 in [Vector3(x0 + 26, 7, 2.5), Vector3(mid + 30, 9, 3), Vector3(x1 - 10, 6, 2)]:
				Art.flat(self, Art.ellipse_pts(Vector2(p.x, y + 2), Vector2(p.y, p.z), 10), Color(ore, 0.85))
			# Mineral specks shimmering up in the hot water.
			for k in 4:
				var f := fposmod(_t * 0.18 + k * 0.25, 1.0)
				Art.dot(self, Vector2(x0 - 14 + sin(_t + k * 2.0) * 16.0, y - 60 - f * 110.0), 1.8, Color(ore2, 0.7 * sin(f * PI)))
		"whale":
			# A fallen whale: its spine arching over the floor, ribs curving
			# down from it, the skull resting at the far end.
			var bone: Color = ore
			var x_a := x0 - 80.0
			var x_b := x1 + 40.0
			var n := 7
			var spine := PackedVector2Array()
			for k in n:
				var f := float(k) / (n - 1)
				spine.append(Vector2(lerpf(x_a, x_b, f), y - 34.0 - sin(f * PI) * 46.0 * (0.6 + 0.4 * fit)))
			for k in range(1, n - 1):
				var rib := _rib(spine[k], y + 3.0)
				Art.line_c(self, rib, Art.INK, 8.0)
				Art.line_c(self, rib, bone, 4.0)
				Art.dot(self, rib[rib.size() - 1] + Vector2(0, -2), 2.4, Color("ef3a4a"))
			Art.line_c(self, spine, Art.INK, 10.0)
			Art.line_c(self, spine, Art.shade_of(bone, 0.15), 5.0)
			for p in spine:
				Art.t_circle(self, p, 5.5, bone, 2.2, 0.0)
			Art.push(self, Vector2(x_b + 62.0 * fit, y + 4), 0.0, Vector2(1.4, 1.4) * fit)
			OreArt.whale_skull(self, bone, ore2, _t)
			Art.pop(self)
			Art.push(self, spine[0] + Vector2(-8, 4), 0.5)
			Art.toon(self, _FLUKE, bone, 2.2, 0.3)
			Art.pop(self)
			# Ghostly plankton drifting through the bones.
			for k in 4:
				var f := fposmod(_t * 0.05 + k * 0.25, 1.0)
				var gp := Vector2(lerpf(x_a - 20, x_b + 40, f), top + 40 + k * 22 + sin(_t * 0.9 + k) * 10.0)
				Art.glow(self, gp, 10.0, Color(ore2, 0.35), 10)
				Art.disc(self, gp, 1.8, Color(ore2, 0.9))
		"mirror":
			# A brine pool: a lake on the sea floor, still as a mirror.
			Art.push(self, Vector2(mid, y + 3), 0.0, Vector2(fit, 1.0))
			Art.toon(self, _BRINE, Art.shade_of(st["floor"], 0.25), 2.4, 0.0)
			Art.flat(self, _BRINE_IN, Color("c8d6f0"))
			Art.flat(self, _BRINE_LOW, Color("8fa4d8"))
			for k in 2:
				var f := fposmod(_t * 0.4 + k * 0.5, 1.0)
				Art.push(self, Vector2(k * 18.0 - 9.0, -3), 0.0, Vector2(1.0, 0.22) * (0.3 + f))
				Art.arc_c(self, Vector2.ZERO, 30.0, 0, TAU, 20, Color(1, 1, 1, snappedf(0.8 * (1.0 - f), 0.1)), 3.0)
				Art.pop(self)
			Art.pop(self)
			for k in 3:
				var sx := lerpf(x0 - 40, x1 + 50, k / 2.0)
				OreArt.piece(self, "mirror", Vector2(sx, top - 2), 0.7 + (k % 2) * 0.25, PI, st, _t, k)
			# Light from the pool dancing on the ceiling.
			for k in 6:
				var cp := Vector2(lerpf(x0 - 60, x1 + 60, fposmod(k * 0.37, 1.0)) + sin(_t * 1.3 + k) * 8.0, top + 20 + (k % 3) * 12.0)
				Art.dot(self, cp, 2.4 + sin(_t * 2.0 + k * 1.7), Color(1, 1, 1, 0.45))
			for p: Vector3 in [Vector3(x0 - 20, 0.6, 1), Vector3(x1 + 30, 0.5, 2)]:
				OreArt.piece(self, "mirror", Vector2(p.x, y + 2), p.y, 0.15, st, _t, int(p.z))
		"storm":
			var period := 3.4
			var f := fposmod(_t / period + index * 0.31, 1.0)
			var strike := int(floorf(_t / period + index * 0.31))
			if f < 0.1:
				Art.flat(self, _cp, Color(0.75, 0.88, 1.0, snappedf(0.2 * (1.0 - f / 0.1), 0.02)))
			# Rain of sparks.
			for k in 8:
				var g := fposmod(_t * 0.9 + k * 0.137 + k * k * 0.05, 1.0)
				var rx := lerpf(x0 - 70, x1 + 80, fposmod(k * 0.43, 1.0))
				var ry := lerpf(top + 40, y - 6, g)
				Art.line(self, Vector2(rx, ry), Vector2(rx - 3, ry + 9), Color(ore2, 0.35), 1.6)
			var clouds := [Vector3(x0 - 40, top + 22, 1.0), Vector3(mid + 20, top + 14, 1.2), Vector3(x1 + 50, top + 26, 0.9)]
			for k in clouds.size():
				var cl: Vector3 = clouds[k]
				Art.push(self, Vector2(cl.x + sin(_t * 0.3 + k * 2.0) * 10.0, cl.y), 0.0, Vector2.ONE * cl.z * fit)
				Art.toon(self, _CLOUD, Color("3a4466"), 2.4, 0.0)
				Art.flat(self, _CLOUD_LOW, Color("2a3252"))
				Art.pop(self)
			if f < 0.1:
				var rng := RandomNumberGenerator.new()
				rng.seed = strike * 13 + index
				var bx := lerpf(x0 - 40, x1 + 50, rng.randf())
				OreArt.bolt(self, Vector2(bx, top + 30), Vector2(bx + rng.randf_range(-40, 40), y - 2), strike, ore, 1.0 - f / 0.1)
				Art.glow(self, Vector2(bx, y - 4), 30.0, Color(ore2, 0.5 * (1.0 - f / 0.1)), 12)
			OreArt.piece(self, "storm", Vector2(x0 - 30, y + 2), 0.8, -0.15, st, _t, 1)
		"dragon":
			# A dragon asleep on its hoard; it opens an eye at each delivery.
			var s := 0.95 * fit
			var at := Vector2(mid - 10, y + 3)
			Art.push(self, at, 0.0, Vector2(s, s))
			Art.toon(self, _HOARD, Color("ffc93c"), 2.4, 0.4)
			Art.toon(self, _TAIL, Color("2f7a5a"), 2.4, 0.0)
			Art.toon(self, _SPADE, Color("ff7a3a"), 2.2, 0.0)
			var breathe := 1.0 + 0.03 * sin(_t * 1.3)
			Art.push(self, Vector2.ZERO, 0.0, Vector2(1.0, breathe))
			for k in _SPIKES.size():
				var sp: Vector3 = _SPIKES[k]
				Art.push(self, Vector2(sp.x, sp.y), sp.z)
				Art.toon(self, _SPIKE, Color("ff7a3a"), 2.2, 0.0)
				Art.pop(self)
			Art.toon(self, _DRAGON, Color("3a8a64"), 2.6, 0.6)
			Art.flat(self, _BELLY, Color("e8c070"))
			for p: Vector2 in _DSCALES:
				Art.arc_c(self, p, 7.0, 0.3, PI - 0.3, 4, Color("2a6a4c"), 1.6)
			Art.pop(self)
			for h: PackedVector2Array in _HORNS:
				Art.toon(self, h, Color("f1e6cc"), 2.2, 0.3)
			Art.toon(self, _HEAD, Color("3a8a64"), 2.6, 0.5)
			Art.flat(self, _JAW, Color("e8c070"))
			Art.toon(self, _TOOTH, Art.WHITE, 1.4, 0.0)
			Art.flat(self, Art.circle_pts(Vector2(110, -15), 2.2, 8), Art.INK)
			if _flash > 0.05:
				Art.toon(self, _DEYE, Color("ffd84a"), 1.8, 0.0)
				Art.flat(self, _DPUPIL, Art.INK)
			else:
				Art.arc_c(self, Vector2(86, -24), 6.0, 0.3, PI - 0.3, 6, Art.INK, 2.4)
			Art.pop(self)
			# Warm breath: embers and smoke from the nostrils.
			var nose := at + Vector2(112, -15) * s
			Art.glow(self, nose, 14.0, Color(1.0, 0.5, 0.2, 0.3 + 0.15 * sin(_t * 1.3)), 10)
			for k in 2:
				var g := fposmod(_t * 0.35 + k * 0.5, 1.0)
				Art.dot(self, nose + Vector2(6.0 + g * 14.0, -g * 40.0), 3.0 + g * 5.0, Color(0.6, 0.5, 0.5, 0.45 * (1.0 - g)))
		"throne":
			for k in 2:
				var bx := x0 - 40.0 if k == 0 else x1 + 60.0
				Art.push(self, Vector2(bx, top - 2), sin(_t * 1.1 + k * 2.0) * 0.05)
				Art.toon(self, _BANNER, Color("6a3ac0"), 2.4, 0.4)
				Art.flat(self, _BANNER_TRIM, Color("ffc93c"))
				Art.t_rect(self, Rect2(-19, -3, 38, 7), 3, Color("ffc93c"), 2.0, 0.0)
				Art.flat(self, _EMBLEM, Color("ffc93c"))
				Art.flat(self, _EMBLEM_IN, Color(ore2, 0.9))
				Art.pop(self)
			Art.push(self, Vector2(mid + 4, y + 3), 0.0, Vector2.ONE * (0.75 + 0.25 * fit))
			Art.t_rect(self, Rect2(-26, -112, 52, 88), 12, Color("ffc93c"), 2.6, 0.3)
			Art.flat(self, Art.rrect_pts(Rect2(-18, -102, 36, 72), 8), Color("a02848"))
			for x: float in [-26.0, 0.0, 26.0]:
				Art.flat(self, Art.circle_pts(Vector2(x, -114 - (6.0 if x == 0.0 else 0.0)), 5.0, 10), Color("ffc93c"))
			OreArt.piece(self, "crown", Vector2(0, -56), 0.9, 0.0, st, _t, 1)
			for x: float in [-30.0, 22.0]:
				Art.t_rect(self, Rect2(x, -26, 8, 26), 2, Color("e0a52c"), 0.0, 0.0)
			Art.t_rect(self, Rect2(-34, -36, 68, 12), 4, Color("ffc93c"), 2.4, 0.0)
			Art.t_rect(self, Rect2(-29, -44, 58, 10), 5, Color("c0304a"), 2.2, 0.3)
			Art.pop(self)
			for p: Vector3 in [Vector3(x0 - 6, 5, 0), Vector3(x1 + 18, 5, 2)]:
				Art.t_ellipse(self, Vector2(p.x, y + 1), Vector2(p.y + 3, 2.4), Color("ffc93c"), 1.6, 0.0)
			for k in 3:
				var tw := 0.5 + 0.5 * sin(_t * 2.6 + k * 2.1)
				Art.push(self, Vector2(lerpf(x0 - 30, x1 + 40, k / 2.0), top + 60 + (k % 2) * 30), _t * 0.5 + k, Vector2.ONE * (0.4 + tw * 0.6))
				Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.6, 4), Color(1, 0.95, 0.7, 0.9), 0.0, 0.0)
				Art.pop(self)
		"void":
			# A slow whirlpool of nothing in the back wall.
			var c := Vector2(mid + 6, top + 86)
			var pulse := 0.5 + 0.5 * sin(_t * 1.4)
			Art.glow(self, c, 88.0 * fit + 10.0, Color(ore, 0.22 + 0.08 * pulse), 18)
			Art.push(self, c, _t * 0.45, Vector2.ONE * (0.6 + 0.4 * fit))
			for k in 3:
				Art.push(self, Vector2.ZERO, TAU * k / 3.0)
				Art.flat(self, _ARM, Color(ore, 0.55))
				Art.flat(self, _ARM_IN, Color(ore2, 0.45))
				Art.pop(self)
			Art.t_circle(self, Vector2.ZERO, 20, OreArt.VOID_BODY, 2.4, 0.0)
			Art.arc_c(self, Vector2.ZERO, 17.5, 0, TAU, 20, Color(ore2, 0.8), 1.8)
			Art.pop(self)
			for k in 6:
				var g := fposmod(_t * 0.22 + k / 6.0, 1.0)
				var a := g * 5.0 + k * 1.3
				var r := 90.0 * (1.0 - g) * fit + 16.0
				Art.dot(self, c + Vector2(cos(a) * r, sin(a) * r * 0.6), 1.2 + 1.6 * (1.0 - g), Color(ore2, 0.8 * sin(g * PI)))
			for p: Vector3 in [Vector3(x0 - 34, 0.7, 0), Vector3(x1 + 44, 0.55, 1)]:
				Art.push(self, Vector2(p.x, y - 64 + sin(_t * 1.1 + p.z * 2.0) * 7.0))
				OreArt.void_orb(self, ore, ore2, _t, p.y, p.z > 0.5)
				Art.pop(self)
		"clocks":
			var c := Vector2(x0 - 30, top + 70)
			Art.push(self, c + Vector2(0, 30), sin(_t * 2.0) * 0.32)
			Art.line_c(self, _PENDULUM, Art.INK, 4.6)
			Art.line_c(self, _PENDULUM, OreArt.BRASS, 2.2)
			Art.t_circle(self, Vector2(0, 58), 8, OreArt.BRASS, 2.4, 0.5)
			Art.pop(self)
			Art.t_circle(self, c, 34, OreArt.BRASS, 2.6, 0.5)
			Art.t_circle(self, c, 28, ore2, 1.8, 0.0)
			Art.push(self, c)
			for k in 12:
				Art.line_c(self, _TICKS[k], Art.shade_of(ore, 0.35), 2.0 if k % 3 == 0 else 1.2)
			Art.pop(self)
			Art.push(self, c, _t * 0.6)
			Art.line_c(self, PackedVector2Array([Vector2(0, 4), Vector2(0, -22)]), Art.INK, 2.2)
			Art.pop(self)
			Art.push(self, c, _t * 0.05 + 1.0)
			Art.line_c(self, PackedVector2Array([Vector2(0, 3), Vector2(0, -14)]), Art.INK, 3.2)
			Art.pop(self)
			Art.t_circle(self, c, 3, ore, 1.4, 0.0)
			var gc := Vector2(x1 + 50, top + 56)
			for g in 2:
				Art.push(self, gc + Vector2(-30, 28) * fit * g, _t * 0.4 * (1.0 - g * 2.6) - g * 0.2, Vector2.ONE * (1.6 - g * 0.6) * (0.4 + 0.6 * fit))
				Art.toon(self, _GEAR, Color("b07a34") if g == 0 else Color("c98a3a"), 2.0, 0.0)
				Art.t_circle(self, Vector2.ZERO, 6.5, Color("6a4a24"), 1.6, 0.0)
				Art.pop(self)
			# Sand trickling from a crack in the ceiling into a little dune.
			var sx := mid + 24
			Art.line_c(self, PackedVector2Array([Vector2(sx, top), Vector2(sx, y - 4)]), Color(ore, 0.55), 1.4)
			for k in 3:
				var g := fposmod(_t * 0.7 + k / 3.0, 1.0)
				Art.dot(self, Vector2(sx, lerpf(top, y - 4, g)), 1.6, ore)
			Art.push(self, Vector2(sx, y + 2))
			Art.toon(self, _DUNE, ore, 2.0, 0.4)
			Art.pop(self)
			OreArt.piece(self, "time", Vector2(x0 + 14, y + 2), 0.65, 0.1, st, _t, 1)
		"heart":
			# The heart of the ocean beats in the back wall; light pours out.
			var c := Vector2(mid + 4, top + 84)
			var beat := maxf(0.0, sin(_t * 3.2)) * 0.06
			Art.glow(self, c, 110.0 * fit + 20.0, Color(ore, 0.2 + beat * 2.0), 20)
			OreArt.heart_rays(self, c, 150.0 * fit + 30.0, ore2, _t, 8)
			Art.push(self, c, 0.0, Vector2.ONE * (2.6 * fit + 0.6) * (1.0 + beat))
			Art.flat(self, OreArt.HEART, Color("ff8fc8", 0.28))
			Art.pop(self)
			Art.push(self, Vector2(x0 - 30, y + 2), 0.0, Vector2.ONE * 1.2)
			Props.coral(self, Color("ff7ab8"), index, _t)
			Art.pop(self)
			for k in 2:
				var a := _t * 0.5 + k * PI
				Art.fish(self, c + Vector2(cos(a) * 70.0 * fit + 10.0, sin(a) * 26.0), 9.0, Color("ffc93c") if k == 0 else Color("ff8fc8"), -1.0 if sin(a) > 0.0 else 1.0, _t + k)
			for k in 6:
				var g := fposmod(_t * 0.12 + k / 6.0, 1.0)
				var sp := Vector2(lerpf(x0 - 60, x1 + 70, fposmod(k * 0.41, 1.0)) + sin(_t + k) * 8.0, lerpf(y - 10, top + 10, g))
				Art.push(self, sp, _t + k, Vector2.ONE * (0.4 + 0.6 * sin(g * PI)))
				Art.toon(self, Art.star_pts(Vector2.ZERO, 6, 1.5, 4), Color("fff0fa") if k % 2 else Color(ore2), 0.0, 0.0)
				Art.pop(self)
			for p: Vector3 in [Vector3(x0 + 4, 4.0, 0), Vector3(x0 + 16, 3.0, 0), Vector3(x1 + 10, 3.5, 0)]:
				Art.t_circle(self, Vector2(p.x, y - p.y + 1), p.y, Color("f4f0ff"), 1.4, 0.0)
			Art.push(self, Vector2(x1 + 44, y + 2), 0.0, Vector2.ONE * 0.8)
			OreArt.piece(self, "heart", Vector2.ZERO, 1.0, 0.1, st, _t, 2)
			Art.pop(self)


static var _FLUKE := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-10, -12), Vector2(-22, -14), Vector2(-14, -3),
		Vector2(-22, 10), Vector2(-10, 10)]), 2)
static var _BRINE := Art.ellipse_pts(Vector2(0, -2), Vector2(70, 10), 28)
static var _BRINE_IN := Art.ellipse_pts(Vector2(0, -2.5), Vector2(64, 7), 28)
static var _BRINE_LOW := Art.clipped(Art.ellipse_pts(Vector2(8, 2), Vector2(64, 6), 24), _BRINE_IN)
static var _CLOUD := Art.union([Art.circle_pts(Vector2(-30, 0), 16, 18), Art.circle_pts(Vector2(-8, -8), 20, 20),
		Art.circle_pts(Vector2(16, -4), 17, 18), Art.circle_pts(Vector2(34, 2), 12, 14), Art.rrect_pts(Rect2(-42, 0, 84, 14), 7, 3)])
static var _CLOUD_LOW := Art.clipped(Art.rrect_pts(Rect2(-50, 4, 100, 20), 4, 2), _CLOUD)
static var _HOARD := Art.smooth_pts(PackedVector2Array([Vector2(-100, 0), Vector2(-70, -10), Vector2(-30, -16), Vector2(20, -16),
		Vector2(70, -12), Vector2(120, -6), Vector2(135, 0)]), 3)
static var _DRAGON := Art.smooth_pts(PackedVector2Array([Vector2(-72, -4), Vector2(-66, -24), Vector2(-48, -44), Vector2(-20, -56),
		Vector2(10, -54), Vector2(38, -42), Vector2(58, -24), Vector2(64, -6), Vector2(0, -2)]), 3)
static var _BELLY := Art.clipped(Art.ellipse_pts(Vector2(-2, 4), Vector2(62, 18), 24), _DRAGON)
static var _DSCALES: Array[Vector2] = [Vector2(-38, -38), Vector2(-14, -44), Vector2(12, -42), Vector2(-26, -26), Vector2(0, -30), Vector2(26, -28)]
static var _SPIKE := PackedVector2Array([Vector2(-7, 2), Vector2(0, -14), Vector2(7, 2)])
static var _SPIKES: Array[Vector3] = [Vector3(-52, -38, -0.8), Vector3(-30, -51, -0.45), Vector3(-6, -56, -0.1), Vector3(18, -53, 0.25), Vector3(40, -41, 0.6)]
static var _TAIL := Geometry2D.offset_polyline(PackedVector2Array([Vector2(-64, -8), Vector2(-86, -4), Vector2(-104, -8),
		Vector2(-112, -20), Vector2(-104, -30)]), 5.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]
static var _SPADE := PackedVector2Array([Vector2(-104, -30), Vector2(-96, -40), Vector2(-102, -46), Vector2(-112, -40)])
static var _HEAD := Art.smooth_pts(PackedVector2Array([Vector2(58, -28), Vector2(76, -36), Vector2(96, -28), Vector2(118, -20),
		Vector2(121, -8), Vector2(112, 0), Vector2(70, 0), Vector2(56, -10)]), 3)
static var _JAW := Art.clipped(Art.rrect_pts(Rect2(66, -7, 60, 12), 4, 2), _HEAD)
static var _TOOTH := PackedVector2Array([Vector2(100, -7), Vector2(105, -7), Vector2(102.5, -2)])
static var _HORNS: Array[PackedVector2Array] = [PackedVector2Array([Vector2(66, -30), Vector2(50, -52), Vector2(74, -34)]),
		PackedVector2Array([Vector2(78, -34), Vector2(68, -56), Vector2(86, -34)])]
static var _DEYE := Art.ellipse_pts(Vector2(86, -24), Vector2(6, 4.5), 14)
static var _DPUPIL := PackedVector2Array([Vector2(85, -28), Vector2(87, -28), Vector2(87, -20), Vector2(85, -20)])
static var _EMBLEM := PackedVector2Array([Vector2(0, 22), Vector2(12, 34), Vector2(0, 46), Vector2(-12, 34)])
static var _EMBLEM_IN := PackedVector2Array([Vector2(0, 28), Vector2(6, 34), Vector2(0, 40), Vector2(-6, 34)])
static var _BANNER := PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(16, 64), Vector2(0, 54), Vector2(-16, 64)])
static var _BANNER_TRIM := PackedVector2Array([Vector2(-16, 56), Vector2(0, 46), Vector2(16, 56), Vector2(16, 60), Vector2(0, 50), Vector2(-16, 60)])
static var _ARM := _spiral_arm(1.0)
static var _ARM_IN := _spiral_arm(0.45)
static var _GEAR := Art.gear_pts(20.0, 8)
static var _PENDULUM := PackedVector2Array([Vector2(0, 0), Vector2(0, 52)])
static var _TICKS: Array[PackedVector2Array] = _ticks()
static var _DUNE := Art.smooth_pts(PackedVector2Array([Vector2(-18, 1), Vector2(-8, -6), Vector2(0, -8), Vector2(9, -5), Vector2(18, 1)]), 3)


## One rib of the whale: from the spine curving out and down to the floor.
static func _rib(top_pt: Vector2, floor_y: float) -> PackedVector2Array:
	var a := top_pt
	var b := Vector2(top_pt.x - 16.0, floor_y)
	var ctrl := Vector2(top_pt.x - 44.0, lerpf(top_pt.y, floor_y, 0.35))
	var pts := PackedVector2Array()
	for k in 6:
		var f := k / 5.0
		pts.append(a.lerp(ctrl, f).lerp(ctrl.lerp(b, f), f))
	return pts


static func _spiral_arm(w: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in 13:
		var f := k / 12.0
		var a := f * 2.4
		var r := lerpf(18.0, 78.0, f)
		var hw := lerpf(9.0, 1.0, f) * w
		var d := Vector2.from_angle(a)
		left.append(d * (r + hw))
		right.append(d * (r - hw))
	right.reverse()
	left.append_array(right)
	return left


static func _ticks() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for k in 12:
		var d := Vector2.from_angle(TAU * k / 12.0)
		out.append(PackedVector2Array([d * (22.0 if k % 3 == 0 else 24.0), d * 26.5]))
	return out


# --- The rooms of the dry worlds ----------------------------------------------------------

## Veins in the rock around the cave (a still layer): lava veins by the
## volcano, moss on the swamp's rock, pits and crystal specks on the moon.
func _wall_details(ci: CanvasItem, w: float, h: float, rock: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 31 + 7
	match WorldLook.world:
		"volcano":
			# Glowing magma veins branching through the basalt.
			for k in 4:
				var x := rng.randf_range(10.0, w - 60.0)
				var y := rng.randf_range(14.0, 34.0) if k % 2 == 0 else rng.randf_range(h - 30.0, h - 12.0)
				var pts := PackedVector2Array([Vector2(x, y)])
				for j in 6:
					pts.append(pts[j] + Vector2(rng.randf_range(12, 26), rng.randf_range(-9, 9)))
				var fork := PackedVector2Array([pts[3], pts[3] + Vector2(rng.randf_range(6, 14), 14 if y < h / 2.0 else -14), pts[3] + Vector2(rng.randf_range(14, 24), 22 if y < h / 2.0 else -22)])
				for line: PackedVector2Array in [pts, fork]:
					Art.line_c(ci, line, Color(1.0, 0.42, 0.12, 0.45), 6.0)
					Art.line_c(ci, line, VEIN, 3.0)
					Art.line_c(ci, line, Color("ffe08a"), 1.2)
		"acid":
			for k in 5:
				var p := Vector2(rng.randf_range(10, w - 10), 6.0)
				Art.toon(ci, Art.moved(_MOSS_TOP, p), Color("6cc24a"), 2.0, 0.3)
		"jungle":
			_jungle_wall(ci, w, h, rock, rng)
		"moon":
			for k in 4:
				var p := Vector2(rng.randf_range(20, w - 20), rng.randf_range(16, h - 16))
				Art.t_ellipse(ci, p, Vector2(7, 4), Art.shade_of(rock, 0.25), 1.6, 0.0)
			for k in 2:
				var p := Vector2(rng.randf_range(20, w - 20), h - 12.0)
				Art.crystal(ci, p, 14, 4, rng.randf_range(-0.3, 0.3), Color("9fe0ff"), 1.6)


## The rock's surface (a still layer): speckles, a few cracks and stones
## set in the rock with a lit top and a shaded foot.
func _rock_texture(ci: CanvasItem, w: float, h: float, rock: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 97 + 5
	var dark := Art.shade_of(rock, 0.32)
	var lite := rock.lightened(0.16)
	# Speckles: tiny grains of lighter and darker stone.
	for i in 46:
		var p := Vector2(rng.randf_range(2, w - 2), rng.randf_range(8, h - 6))
		var r := rng.randf_range(1.4, 3.0)
		Art.disc(ci, p, r, Color(dark, 0.55) if i % 3 else Color(lite, 0.7))
	# Cracks.
	for i in 3:
		var a := Vector2(rng.randf_range(20, w - 120), rng.randf_range(20, h - 30))
		var line := PackedVector2Array([a])
		for k in 4:
			line.append(line[k] + Vector2(rng.randf_range(14, 26), rng.randf_range(-8, 8)))
		Art.line_c(ci, line, Color(dark, 0.7), 2.2)
		Art.line_c(ci, Art.moved(line, Vector2(0, 2)), Color(lite, 0.35), 1.4)
	# Stones: irregular, outlined in a darker tone of the rock.
	for i in 18:
		var c := Vector2(rng.randf_range(6, w - 6), rng.randf_range(12, h - 10))
		var r := rng.randf_range(5.0, 13.0)
		var pts := PackedVector2Array()
		var n := 7
		for k in n:
			var ang := TAU * k / n + rng.randf_range(-0.2, 0.2)
			pts.append(c + Vector2(cos(ang) * r * rng.randf_range(0.8, 1.25), sin(ang) * r * 0.78 * rng.randf_range(0.8, 1.2)))
		var tone := rock.lightened(rng.randf_range(0.04, 0.14)) if i % 4 else rock.darkened(0.06)
		Art.toon(ci, pts, tone, 1.8, 0.9, dark)


const VEIN := Color("ff7a1e")


## Basalt columns in the volcano's rock (a still layer): tall six-sided
## columns with joints, their tops catching a little light.
func _basalt(ci: CanvasItem, w: float, h: float, rock: Color) -> void:
	var seam := Art.shade_of(rock, 0.4)
	var lit := rock.lightened(0.07)
	var x := -8.0 + float(index % 3) * 7.0
	var k := 0
	while x < w + 10.0:
		var cw := 24.0 + float((k * 7 + index * 3) % 4) * 3.0
		Art.flat(ci, PackedVector2Array([Vector2(x + 2, 0), Vector2(x + cw * 0.38, 0), Vector2(x + cw * 0.34, h), Vector2(x + 2, h)]), lit)
		var line := PackedVector2Array()
		for j in 6:
			line.append(Vector2(x + (2.0 if j % 2 == 0 else -2.0), h * j / 5.0))
		Art.line_c(ci, line, seam, 2.5)
		for j in 2:
			var jy := fposmod(float(k * 53 + j * 97 + index * 31), h - 30.0) + 15.0
			Art.line_c(ci, PackedVector2Array([Vector2(x + 2, jy), Vector2(x + cw - 2, jy + 4.0)]), seam, 2.0)
		x += cw
		k += 1


## The volcano cave's air: lit warm from the magma below, dark up top,
## with basalt columns in the back wall.
func _magma_cave_light(ci: CanvasItem, cave: Rect2, cave_poly: PackedVector2Array, inner: Color) -> void:
	var col := inner.darkened(0.22)
	var x := cave.position.x + 54.0
	var k := 0
	while x < cave.end.x - 30.0:
		var cw := 22.0 + float((k + index) % 3) * 6.0
		var top := cave.position.y + 18.0 + float((k * 5 + index) % 4) * 7.0
		var colm := PackedVector2Array([Vector2(x, cave.end.y), Vector2(x, top + 6), Vector2(x + cw * 0.5, top), Vector2(x + cw, top + 6), Vector2(x + cw, cave.end.y)])
		Art.flat(ci, Art.clipped(colm, cave_poly), col if k % 2 == 0 else col.lightened(0.05))
		x += cw + 4.0
		k += 1
	for i in 3:
		var y0 := LEDGE_Y + 8.0 - (i + 1) * 40.0
		var band := Art.clipped(PackedVector2Array([Vector2(cave.position.x, y0), Vector2(cave.end.x, y0), Vector2(cave.end.x, y0 + 40.0), Vector2(cave.position.x, y0 + 40.0)]), cave_poly)
		Art.flat(ci, band, Color(1.0, 0.42, 0.12, 0.15 - i * 0.045))


## Where the magma channel runs in the cave floor: x of its middle and
## its half width (0 = no room for it).
func _channel() -> Vector2:
	var a := World.CAVE_L + 112.0
	var b := deposit_pos().x - 46.0
	var hw := minf(40.0, (b - a) / 2.0)
	return Vector2((a + b) / 2.0, hw if hw >= 22.0 else 0.0)


## A channel of magma sunk into the front of the floor (still part).
func _magma_channel(ci: CanvasItem) -> void:
	var c := _channel()
	if c.y <= 0.0:
		return
	var at := Vector2(c.x, LEDGE_Y + 15.0)
	Art.t_ellipse(ci, at, Vector2(c.y + 6.0, 10.0), Color("2e2228"), 3.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(at + Vector2(0, 1), Vector2(c.y, 6.5), 24), WorldArt.MAGMA_MID)
	Art.flat(ci, Art.ellipse_pts(at + Vector2(-c.y * 0.15, 0), Vector2(c.y * 0.7, 3.6), 20), WorldArt.MAGMA_SKIN)
	Art.flat(ci, Art.ellipse_pts(at + Vector2(-c.y * 0.25, -1), Vector2(c.y * 0.35, 1.6), 14), WorldArt.MAGMA_HOT)


## Its glow, a crust plate drifting on it and a bubble that pops.
func _magma_channel_life() -> void:
	var c := _channel()
	if c.y <= 0.0:
		return
	var at := Vector2(c.x, LEDGE_Y + 15.0)
	var pulse := snappedf(0.75 + 0.25 * sin(_t * 1.6 + index), 0.05)
	Art.glow(self, at + Vector2(0, -6), c.y + 16.0, Color(1.0, 0.55, 0.2, 0.32 * pulse), 14)
	var drift := sin(_t * 0.35 + index) * c.y * 0.45
	Art.push(self, at + Vector2(drift, 0.5), 0.0, Vector2(0.45, 0.6))
	Art.toon(self, _CHANNEL_CRUST, WorldArt.CRUST, 3.0, 0.6)
	Art.pop(self)
	var f := fposmod(_t * 0.4 + index * 0.37, 1.0)
	var bx := at.x - drift * 0.8 + c.y * 0.3
	if f < 0.75:
		var s := maxf(f / 0.75, 0.05)
		Art.push(self, Vector2(bx, at.y), 0.0, Vector2(0.5 + s * 0.5, s) * 0.7)
		Art.toon(self, _CHANNEL_DOME, Color("ffd24a"), 2.0, 0.3)
		Art.pop(self)
	else:
		var k := (f - 0.75) / 0.25
		for j in 3:
			var d := Vector2(cos(-PI / 2.0 + (j - 1) * 0.5), sin(-PI / 2.0 + (j - 1) * 0.5))
			Art.dot(self, Vector2(bx, at.y) + d * 22.0 * k + Vector2(0, 26.0 * k * k), 2.2 * (1.0 - k) + 0.6, Color(1.0, 0.8, 0.3, 1.0 - k))


static var _CHANNEL_CRUST := Art.smooth_pts(PackedVector2Array([Vector2(-26, 1), Vector2(-20, -5), Vector2(0, -7), Vector2(20, -5), Vector2(26, 1), Vector2(10, 5), Vector2(-12, 5)]), 2)
static var _CHANNEL_DOME := PackedVector2Array([Vector2(-9, 1), Vector2(-8, -4), Vector2(-4, -7.5), Vector2(0, -8.5), Vector2(4, -7.5), Vector2(8, -4), Vector2(9, 1)])


static var _MOSS_TOP := Art.smooth_pts(PackedVector2Array([Vector2(-16, -4), Vector2(16, -4), Vector2(14, 4), Vector2(6, 9), Vector2(0, 5), Vector2(-7, 10), Vector2(-13, 4)]), 2)


## Still things inside the cave of a dry world: glowing cracks in the
## volcano's back wall, hanging moss in the swamp, a rail on the moon.
func _room_furniture(ci: CanvasItem, cave: Rect2) -> void:
	var cp := _cave_poly()
	var x0 := World.CAVE_L + 110.0
	var x1 := cave.end.x - 150.0
	match WorldLook.world:
		"volcano":
			for k in 2:
				var x := lerpf(x0, x1, 0.25 + k * 0.5)
				var crack := PackedVector2Array([Vector2(x, CAVE_TOP + 20), Vector2(x + 8, CAVE_TOP + 46), Vector2(x - 4, CAVE_TOP + 70), Vector2(x + 6, CAVE_TOP + 96)])
				Art.glow(ci, Vector2(x, CAVE_TOP + 58), 40.0, Color(1.0, 0.5, 0.2, 0.25), 14)
				Art.line_c(ci, crack, Color("ff7a2a"), 4.0)
				Art.line_c(ci, crack, Color("ffe08a"), 1.6)
		"acid":
			for k in 6:
				var x := lerpf(World.CAVE_L + 60.0, cave.end.x - 60.0, k / 5.0)
				var len := 18.0 + float((k * 7 + index) % 4) * 9.0
				var strand := Art.clipped(Art.rrect_pts(Rect2(x - 3, CAVE_TOP - 4, 6, len), 3), cp)
				Art.flat(ci, strand, Color("5ab84a"))
				Art.disc(ci, Vector2(x, CAVE_TOP + len - 3), 3.0, Color("8ae04a"))
		"jungle":
			_temple_furniture(ci, cave, cp)
		"moon":
			# A rail along the floor for the ore carts.
			Art.line(ci, Vector2(World.CAVE_L + 30, LEDGE_Y + 10), Vector2(cave.end.x - 40, LEDGE_Y + 10), Color("8a90a8"), 3.0)
			var n := int((cave.end.x - World.CAVE_L - 70.0) / 30.0)
			for k in n:
				var x := World.CAVE_L + 40.0 + k * 30.0
				Art.line(ci, Vector2(x, LEDGE_Y + 7), Vector2(x, LEDGE_Y + 14), Color("6a6e86"), 3.0)


## Metal supports (the moon's mine frame): two girders and a beam with rivets.
func _metal_frame(ci: CanvasItem, h: float, w: float) -> void:
	var steel := Color("aeb6cc")
	for x: float in [0.0, w]:
		Art.t_rect(ci, Rect2(x - 6, -h, 12, h), 2, steel, 2.5, 0.4)
		for k in 3:
			Art.disc(ci, Vector2(x, -h + 30.0 + k * 40.0), 1.8, Color("6a6e86"))
	Art.t_rect(ci, Rect2(-14, -h - 8, w + 28, 14), 3, Color("8a92ac"), 2.8, 0.4)
	for k in 4:
		var x := -4.0 + k * (w + 8.0) / 3.0
		Art.line(ci, Vector2(x, -h - 6), Vector2(x + (w + 8.0) / 6.0, -h + 4), Color("6a6e86"), 2.0)


## The cave's light: a hanging lantern under water, torches by the volcano,
## a glowing mushroom lamp in the swamp, a ceiling lamp on the moon.
func _draw_lamps(cave: Rect2) -> void:
	var at := Vector2(cave.get_center().x + 20, CAVE_TOP + 4)
	match WorldLook.world:
		"volcano":
			for x: float in [World.CAVE_L + 118.0, cave.get_center().x + 40.0]:
				_torch(Vector2(x, CAVE_TOP + 74))
		"acid":
			var flick := snappedf(0.8 + 0.2 * sin(_t * 2.0 + index), 0.05)
			Art.line(self, at, at + Vector2(0, 26), Art.INK, 2.0)
			Art.glow(self, at + Vector2(0, 34), 46.0, Color(0.7, 1.0, 0.45, 0.22 * flick), 16)
			Art.push(self, at + Vector2(0, 26), PI)
			WorldArt.mushroom(self, Color("b8ff5a"), 0.0, index)
			Art.pop(self)
		"jungle":
			for x: float in _torch_xs(cave):
				_jg_torch(Vector2(x, CAVE_TOP + 80))
		"moon":
			Art.glow(self, at + Vector2(0, 30), 60.0, Color(0.8, 0.9, 1.0, 0.22), 16)
			Art.line(self, at, at + Vector2(0, 14), Art.INK, 2.0)
			Art.t_rect(self, Rect2(at.x - 22, at.y + 12, 44, 8), 3, Color("aeb6cc"), 2.2, 0.3)
			Art.t_rect(self, Rect2(at.x - 18, at.y + 19, 36, 4), 2, Color("eaf6ff"), 1.6, 0.0)
		_:
			Art.push(self, at)
			Props.lantern(self, _t + index, Color("ffd780"))
			Art.pop(self)


## A wall torch with a flickering flame; `at` is the top of its handle.
func _torch(at: Vector2) -> void:
	var flick := snappedf(0.85 + 0.15 * sin(_t * 9.0 + at.x * 0.1), 0.05)
	Art.glow(self, at + Vector2(0, -12), 48.0, Color(1.0, 0.6, 0.25, 0.28 * flick), 16)
	Art.push(self, at, 0.12)
	Art.t_rect(self, Rect2(-3, 0, 6, 26), 2, Art.WOOD_DARK, 2.0, 0.0)
	Art.t_rect(self, Rect2(-5, -4, 10, 6), 2, Color("6a6e86"), 2.0, 0.0)
	Art.push(self, Vector2(0, -4), sin(_t * 7.0 + at.x) * 0.1, Vector2(1.0, flick))
	Art.toon(self, _FLAME, Color("ff8a2a"), 2.0, 0.0)
	Art.flat(self, _FLAME_IN, Color("ffe066"))
	Art.pop(self)
	Art.pop(self)


static var _FLAME := Art.smooth_pts(PackedVector2Array([Vector2(-7, 0), Vector2(-6, -9), Vector2(0, -20), Vector2(6, -9), Vector2(7, 0)]), 2)
static var _FLAME_IN := Art.smooth_pts(PackedVector2Array([Vector2(-3.5, -1), Vector2(-3, -6), Vector2(0, -12), Vector2(3, -6), Vector2(3.5, -1)]), 2)


## Decor of the volcano, swamp and moon sites (true when drawn).
func _draw_decor_world(st: Dictionary, cave: Rect2) -> bool:
	var y := LEDGE_Y
	var top := CAVE_TOP + 4.0
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	match st["deco"]:
		"ash":
			for p: Vector3 in [Vector3(x0 - 10, 1.0, 0), Vector3(mid + 30, 0.8, 1)]:
				Art.push(self, Vector2(p.x, y + 3), 0.0, Vector2(p.y, p.y))
				Art.toon(self, _ASH_PILE, Color("8a8290"), 2.2, 0.5)
				Art.pop(self)
			Art.push(self, Vector2(x1 + 10, y + 2))
			Art.toon(self, _VENT, Color("5a4e5c"), 2.2, 0.4)
			Art.flat(self, Art.ellipse_pts(Vector2(0, -20), Vector2(5, 2), 10), Color("ff8a2a"))
			Art.pop(self)
			for k in 3:
				var f := fposmod(_t * 0.3 + k / 3.0, 1.0)
				Art.dot(self, Vector2(x1 + 10 + sin(_t + k * 2.0) * 10.0 * f, y - 24.0 - f * 70.0), 5.0 + f * 9.0, Color(0.6, 0.56, 0.62, 0.45 * (1.0 - f)))
			_embers(Vector2(mid, y), 4, ore2)
		"obsidian":
			for p: Vector3 in [Vector3(x0 - 16, 46, -0.25), Vector3(x0 + 6, 30, 0.2), Vector3(x1 + 14, 40, 0.15)]:
				Art.crystal(self, Vector2(p.x, y + 2), p.y, p.y * 0.24, p.z, Color("3a2e52"), 2.4)
			for p: Vector3 in [Vector3(mid - 20, 30, 0.1), Vector3(mid + 40, 22, -0.2)]:
				Art.crystal(self, Vector2(p.x, top - 2), p.y, p.y * 0.22, PI + p.z, Color("4a3c66"), 2.2)
			var crack := PackedVector2Array([Vector2(x0 + 30, y + 6), Vector2(mid - 10, y + 3), Vector2(mid + 20, y + 7), Vector2(x1 - 10, y + 4)])
			var hot := snappedf(0.7 + 0.3 * sin(_t * 2.0 + index), 0.1)
			Art.line_c(self, crack, Color(1.0, 0.5, 0.2, hot), 4.0)
			Art.line_c(self, crack, Color(1.0, 0.9, 0.5, hot), 1.6)
			var tw := snappedf(0.5 + 0.5 * sin(_t * 3.0 + index), 0.05)
			Art.push(self, Vector2(x0 + 4, y - 38), _t, Vector2.ONE * (0.4 + tw * 0.6))
			Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.6, 4), Color(ore2, 0.9), 0.0, 0.0)
			Art.pop(self)
		"sulfur":
			for p: Vector3 in [Vector3(x0 - 10, 1.4, 0.0), Vector3(x1 + 20, 1.0, 1.7)]:
				Art.push(self, Vector2(p.x, y + 2), 0.0, Vector2(p.y, p.y))
				Art.toon(self, _VENT, Color("8a7a4a"), 2.2, 0.4)
				Art.flat(self, Art.ellipse_pts(Vector2(0, -20), Vector2(5, 2), 10), ore)
				Art.pop(self)
				for k in 3:
					var f := fposmod(_t * 0.35 + k / 3.0 + p.z, 1.0)
					Art.dot(self, Vector2(p.x + sin(_t * 1.3 + k) * 8.0 * f, y - 26.0 * p.y - f * 80.0), 6.0 + f * 10.0, Color(1.0, 0.95, 0.5, 0.4 * (1.0 - f)))
			for k in 3:
				OreArt.piece(self, "sulfur", Vector2(lerpf(x0 + 30, x1 - 20, k / 2.0), y + 3), 0.45 + (k % 2) * 0.15, -0.2 + k * 0.2, st, _t, k)
		"opal":
			# A geode cut open: rainbow rings inside a dark shell.
			Art.push(self, Vector2(mid, y + 2), 0.0, Vector2.ONE * 1.1)
			Art.toon(self, _GEODE, Color("6a4a4a"), 2.4, 0.4)
			Art.flat(self, _GEODE_IN, Color("ffb070"))
			Art.flat(self, _GEODE_MID, Color("7ae8ff"))
			Art.flat(self, _GEODE_CORE, Color("ff7ad0"))
			Art.pop(self)
			var tw := snappedf(0.5 + 0.5 * sin(_t * 2.6 + index), 0.05)
			Art.push(self, Vector2(mid + 8, y - 30), _t * 0.6, Vector2.ONE * (0.5 + tw * 0.6))
			Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.6, 4), Color(1, 1, 1, 0.9), 0.0, 0.0)
			Art.pop(self)
			for x: float in [x0 - 6, x1 + 14]:
				Art.push(self, Vector2(x, y + 3))
				WorldArt.hot_rock(self, Color.WHITE, int(x) % 3)
				Art.pop(self)
		"embers":
			# A brazier of glowing coals.
			var hot := snappedf(0.8 + 0.2 * sin(_t * 5.0 + index), 0.05)
			Art.glow(self, Vector2(mid, y - 30), 70.0, Color(1.0, 0.55, 0.2, 0.3 * hot), 16)
			Art.push(self, Vector2(mid, y + 2))
			Art.t_rect(self, Rect2(-4, -22, 8, 22), 2, Color("5a5060"), 2.2, 0.0)
			Art.toon(self, _BOWL, Color("6e6474"), 2.4, 0.4)
			for k in 4:
				Art.t_circle(self, Vector2(-15 + k * 10, -30 - (k % 2) * 3), 5, Color("ff7a2a") if k % 2 else Color("ffb02e"), 1.6, 0.0)
			Art.push(self, Vector2(0, -34), sin(_t * 6.0) * 0.08, Vector2(1.6, 1.6 * hot))
			Art.toon(self, _FLAME, Color("ff8a2a"), 1.6, 0.0)
			Art.flat(self, _FLAME_IN, Color("ffe066"))
			Art.pop(self)
			Art.pop(self)
			_embers(Vector2(mid, y - 40), 6, ore2)
			for x: float in [x0 - 4, x1 + 16]:
				Art.push(self, Vector2(x, y + 3), 0.0, Vector2.ONE * 1.2)
				WorldArt.hot_rock(self, Color.WHITE, int(x) % 3)
				Art.pop(self)
		"phoenix":
			Art.push(self, Vector2(mid, y + 3))
			Art.toon(self, _NEST, Color("a8743a"), 2.4, 0.5)
			for k in 5:
				Art.line(self, Vector2(-34 + k * 15, -10), Vector2(-24 + k * 15, -2), Color("7a4a24"), 2.0)
			# The soft glow keeps a few cached spots; the egg moves smoothly.
			var bob := sin(_t * 1.6) * 2.0
			Art.glow(self, Vector2(0, -26 + snappedf(bob, 0.5)), 40.0, Color(1.0, 0.6, 0.2, 0.35), 14)
			Art.push(self, Vector2(0, -12 + bob), sin(_t * 8.0) * 0.06 * maxf(0.0, sin(_t * 0.7)))
			OreArt.dragon_egg(self, ore, ore2, _t)
			Art.pop(self)
			Art.pop(self)
			for k in 4:
				var f := fposmod(_t * 0.1 + k * 0.25, 1.0)
				var fp := Vector2(lerpf(x0 - 40, x1 + 40, fposmod(k * 0.37, 1.0)) + sin(_t * 1.5 + k) * 16.0, lerpf(top + 20, y - 10, f))
				Art.push(self, fp, sin(_t * 2.0 + k) * 0.8)
				OreArt.piece(self, "phoenix", Vector2.ZERO, 0.35, 0.0, st, _t, 1)
				Art.pop(self)
		"slime":
			for p: Vector3 in [Vector3(x0 - 10, 1.0, 0), Vector3(mid + 40, 0.7, 1)]:
				Art.push(self, Vector2(p.x, y + 3), 0.0, Vector2(p.y, p.y))
				Art.toon(self, _PUDDLE, ore.darkened(0.1), 2.0, 0.0)
				Art.pop(self)
			for k in 2:
				var hopf := absf(sin(_t * 2.2 + k * 1.7))
				var sq := 1.0 + (1.0 - hopf) * 0.18
				Art.push(self, Vector2(lerpf(x0 + 20, x1 - 10, k), y + 2 - hopf * 10.0), 0.0, Vector2(sq, 2.0 - sq) * (0.9 + k * 0.2))
				_slime_blob(ore, k)
				Art.pop(self)
		"moss":
			Art.push(self, Vector2(mid + 10, y + 3))
			WorldArt.pool(self, Color("7ad84a"), Color("e0ff9a"), 0.9)
			Art.pop(self)
			for k in 5:
				Art.push(self, Vector2(lerpf(x0 - 40, x1 + 40, k / 4.0), y + 4), 0.0, Vector2.ONE * (0.8 + (k % 2) * 0.4))
				Art.toon(self, _TUFT, Color("5ab84a") if k % 2 else Color("8ae04a"), 2.0, 0.3)
				Art.pop(self)
			for k in 4:
				var f := fposmod(_t * 0.1 + k * 0.25, 1.0)
				Art.dot(self, Vector2(mid + 10 + sin(k * 2.0 + _t) * 30.0, y - f * 80.0), 2.0, Color(0.85, 1.0, 0.5, 0.7 * sin(f * PI)))
		"bubbles":
			Art.push(self, Vector2(mid, y + 3))
			WorldArt.pool(self, ore.darkened(0.15), ore2, 1.2)
			Art.pop(self)
			for k in 7:
				var f := fposmod(_t * 0.3 + k / 7.0, 1.0)
				var r := 4.0 + (k % 3) * 3.0
				var bp := Vector2(mid - 40 + k * 13 + sin(_t * 1.4 + k) * 6.0, y - 4 - f * 120.0)
				Art.arc(self, bp, r * (0.6 + f * 0.5), 0, TAU, 14, Color(1, 1, 1, 0.75 * (1.0 - f)), 2.0)
				Art.dot(self, bp + Vector2(-r * 0.3, -r * 0.3), 1.4, Color(1, 1, 1, 0.8 * (1.0 - f)))
			for x: float in [x0 - 8, x1 + 18]:
				Art.push(self, Vector2(x, y + 3))
				WorldArt.mushroom(self, Color("5ad8ff"), 0.0, int(x))
				Art.pop(self)
		"venom":
			Art.push(self, Vector2(mid + 20, y + 3))
			WorldArt.pool(self, ore.darkened(0.2), ore2, 1.0)
			Art.pop(self)
			for x: float in [x0 - 10, x1 + 20]:
				Art.push(self, Vector2(x, y + 3), sin(_t * 0.8 + x) * 0.05)
				Art.toon(self, _THORN_PLANT, Color("4a8a5a"), 2.2, 0.4)
				for p: Vector2 in [Vector2(-8, -30), Vector2(7, -44), Vector2(-4, -56)]:
					Art.t_circle(self, p, 4, ore, 1.6, 0.0)
				Art.pop(self)
			for k in 3:
				var f := fposmod(_t * 0.4 + k / 3.0, 1.0)
				Art.arc(self, Vector2(mid + 4 + k * 14, y - 2 - f * 20.0), 3.0 + f * 3.0, PI, TAU, 8, Color(ore2, 1.0 - f), 1.8)
		"radiant":
			var pulse := snappedf(0.7 + 0.3 * sin(_t * 2.4 + index), 0.05)
			Art.glow(self, Vector2(mid, y - 30), 90.0, Color(ore, 0.25 * pulse), 18)
			for p: Vector3 in [Vector3(x0 - 10, 36, -0.3), Vector3(x0 + 10, 50, 0.1), Vector3(mid + 30, 30, 0.2), Vector3(x1 + 14, 44, -0.15)]:
				Art.crystal(self, Vector2(p.x, y + 2), p.y, p.y * 0.22, p.z, ore if p.y > 40 else ore.lightened(0.2), 2.2)
			for k in 6:
				var f := fposmod(_t * 0.12 + k / 6.0, 1.0)
				var sp := Vector2(lerpf(x0 - 40, x1 + 40, fposmod(k * 0.41, 1.0)), lerpf(y - 10, top + 20, f))
				Art.dot(self, sp, 2.2, Color(ore2, 0.8 * sin(f * PI)))
		"orchids":
			for k in 4:
				Art.push(self, Vector2(lerpf(x0 - 30, x1 + 30, k / 3.0), y + 3), sin(_t * 0.9 + k) * 0.06, Vector2.ONE * (0.9 + (k % 2) * 0.3))
				_orchid(ore if k % 2 == 0 else ore2.darkened(0.15), k)
				Art.pop(self)
			for k in 3:
				var vx := lerpf(x0, x1, k / 2.0) + 20.0
				Art.line_c(self, PackedVector2Array([Vector2(vx, top - 4), Vector2(vx + 6, top + 20), Vector2(vx - 2, top + 40)]), Color("4a8a4a"), 2.6)
				Art.push(self, Vector2(vx - 2, top + 42), PI)
				Art.t_circle(self, Vector2.ZERO, 5, ore, 1.6, 0.3)
				Art.pop(self)
		"goo":
			# The goo king sits on his puddle throne.
			Art.push(self, Vector2(mid, y + 3), 0.0, Vector2(1.4, 1.4))
			Art.toon(self, _PUDDLE, ore.darkened(0.15), 2.0, 0.0)
			var sq := 1.0 + 0.05 * sin(_t * 2.0)
			Art.push(self, Vector2.ZERO, 0.0, Vector2(sq, 2.0 - sq) * 1.3)
			_slime_blob(ore, 2)
			Art.pop(self)
			Art.push(self, Vector2(0, -37), sin(_t * 2.0) * 0.05, Vector2(0.75, 0.75))
			OreArt.piece(self, "crown", Vector2.ZERO, 0.7, 0.0, {"ore": ore2, "ore2": Color("fff6c0")}, _t, 0)
			Art.pop(self)
			Art.pop(self)
			for k in 2:
				Art.push(self, Vector2(x0 - 10 + k * (x1 - x0 + 30), y + 2), 0.0, Vector2.ONE * 0.6)
				_slime_blob(ore.lightened(0.15), k)
				Art.pop(self)
		"base":
			for p: Vector3 in [Vector3(x0 - 10, 0, 0), Vector3(x0 + 18, 0, 1), Vector3(x0 + 4, -24, 2)]:
				Art.t_rect(self, Rect2(p.x - 13, y + 2 + p.y - 24, 26, 24), 3, Color("aeb6cc") if p.z != 1 else Color("8ab4ff"), 2.2, 0.4)
				Art.line(self, Vector2(p.x - 9, y + 2 + p.y - 12), Vector2(p.x + 9, y + 2 + p.y - 12), Color("6a6e86"), 2.0)
			Art.push(self, Vector2(x1 + 16, y + 2))
			var d := Props.downwind
			Props.downwind = -1.0
			Props.flag(self, Vector2.ZERO, 60, Color("ff5a7a"), 0.0, 0.8)
			Props.downwind = d
			Art.pop(self)
			Art.push(self, Vector2(mid + 20, y + 4))
			WorldArt.crater(self, st["floor"], 34.0)
			Art.pop(self)
		"comet":
			var c := Vector2(mid + 10, top + 70)
			Art.glow(self, c, 70.0, Color(ore, 0.25), 16)
			Art.push(self, c, -0.4)
			Art.toon(self, _TAIL_C, Color(ore2, 0.6), 0.0, 0.0)
			Art.pop(self)
			Art.push(self, c, _t * 0.2)
			WorldArt.asteroid(self, 1, Color("a8d8f0"), Art.INK)
			Art.pop(self)
			for p: Vector3 in [Vector3(x0 - 10, 30, -0.2), Vector3(x1 + 14, 26, 0.25)]:
				Art.crystal(self, Vector2(p.x, y + 2), p.y, p.y * 0.25, p.z, ore, 2.2)
			_twinkles(x0, x1, top, y, ore2, 5)
		"alien":
			Art.push(self, Vector2(mid, y + 3))
			Art.toon(self, _NEST, Color("4a6a5a"), 2.4, 0.5)
			for k in 3:
				Art.push(self, Vector2(-18 + k * 18, -10 - (k % 2) * 4), sin(_t * 7.0 + k) * 0.05 * maxf(0.0, sin(_t * 0.6 + k)), Vector2.ONE * (0.7 + (k % 2) * 0.15))
				OreArt.dragon_egg(self, ore, ore2, _t + k)
				Art.pop(self)
			Art.pop(self)
			# Two curious eyes peeking from a hole in the wall; they blink.
			var hole := Vector2(x1 + 10, top + 60)
			Art.t_ellipse(self, hole, Vector2(22, 15), Color("10201a"), 2.4, 0.0)
			var open := 0.15 if Chars.blinking(_t * 0.6, index) else 1.0
			for sx: float in [-1.0, 1.0]:
				Art.push(self, hole + Vector2(sx * 8, 0), 0.0, Vector2(1.0, open))
				Art.t_circle(self, Vector2.ZERO, 5, Color("c8ff8a"), 1.6, 0.0)
				Art.disc(self, Vector2(0, 0.5), 2.2, Art.INK)
				Art.pop(self)
			for x: float in [x0 - 10]:
				Art.push(self, Vector2(x, y + 3))
				WorldArt.mushroom(self, Color("6aff8a"), 0.0, 1)
				Art.pop(self)
		"ufo":
			# A little crashed saucer, its lights still blinking.
			Art.push(self, Vector2(mid, y + 4), -0.22)
			OreArt.piece(self, "ufo", Vector2.ZERO, 1.6, 0.0, st, _t, 0)
			Art.pop(self)
			for k in 3:
				var f := fposmod(_t * 0.25 + k * 0.33, 1.0)
				Art.dot(self, Vector2(mid - 30 + sin(k * 2.0 + _t) * 6.0, y - 10 - f * 60.0), 4.0 + f * 8.0, Color(0.8, 0.8, 0.9, 0.35 * (1.0 - f)))
			for x: float in [x0 - 10, x1 + 20]:
				Art.push(self, Vector2(x, y + 3))
				WorldArt.crystal_cluster(self, ore2)
				Art.pop(self)
		_:
			return false
	return true


func _embers(at: Vector2, n: int, c: Color) -> void:
	for k in n:
		var f := fposmod(_t * 0.35 + k / float(n), 1.0)
		Art.dot(self, at + Vector2(sin(_t * 2.0 + k * 1.7) * 14.0 * f + (k - n / 2.0) * 8.0, -f * 90.0), 2.2 * (1.0 - f) + 0.6, Color(c, 1.0 - f))


func _twinkles(x0: float, x1: float, top: float, y: float, c: Color, n: int) -> void:
	for k in n:
		var sp := Vector2(lerpf(x0 - 60, x1 + 70, fposmod(k * 0.377 + index * 0.1, 1.0)), lerpf(top + 16, y - 30, fposmod(k * 0.618, 1.0)))
		var tw := snappedf(0.5 + 0.5 * sin(_t * (2.0 + k * 0.3) + k), 0.05)
		Art.push(self, sp, 0.0, Vector2.ONE * (0.4 + tw * 0.7))
		Art.toon(self, Art.star_pts(Vector2.ZERO, 7, 1.8, 4), Color(c, 0.5 + 0.5 * tw), 0.0, 0.0)
		Art.pop(self)


## A cute slime with a shine and a face; origin at its bottom.
func _slime_blob(c: Color, k: int) -> void:
	Art.toon(self, _BLOB, c, 2.4, 0.5)
	Art.flat(self, _BLOB_SHINE, Color(1, 1, 1, 0.55))
	var blink := Chars.blinking(_t + k * 1.3, index + k)
	for sx: float in [-1.0, 1.0]:
		if blink:
			Art.line(self, Vector2(sx * 6 - 2, -12), Vector2(sx * 6 + 2, -12), Art.INK, 1.8)
		else:
			Art.t_ellipse(self, Vector2(sx * 6, -12), Vector2(2.0, 2.8), Art.INK, 0.0, 0.0)
	Art.arc(self, Vector2(0, -9), 3.5, 0.4, PI - 0.4, 8, Art.INK, 1.8)


func _orchid(c: Color, k: int) -> void:
	Art.line_c(self, PackedVector2Array([Vector2(0, 0), Vector2(2, -16), Vector2(-1, -30)]), Color("4a8a4a"), 2.6)
	Art.toon(self, _LEAF, Color("5ab84a"), 1.8, 0.3)
	Art.push(self, Vector2(-1, -32))
	for a in 5:
		Art.push(self, Vector2.ZERO, TAU * a / 5.0 + k)
		Art.toon(self, _PETAL, c, 1.6, 0.3)
		Art.pop(self)
	Art.t_circle(self, Vector2.ZERO, 3.5, Color("ffe066"), 1.4, 0.0)
	Art.pop(self)


static var _ASH_PILE := Art.smooth_pts(PackedVector2Array([Vector2(-30, 1), Vector2(-20, -10), Vector2(-4, -16), Vector2(12, -13), Vector2(28, -4), Vector2(32, 1)]), 3)
static var _GEODE := Art.smooth_pts(PackedVector2Array([Vector2(-34, 0), Vector2(-32, -20), Vector2(-16, -36), Vector2(4, -40), Vector2(24, -32), Vector2(34, -14), Vector2(32, 0)]), 3)
static var _GEODE_IN := Art.ellipse_pts(Vector2(0, -18), Vector2(24, 16), 22)
static var _GEODE_MID := Art.ellipse_pts(Vector2(0, -18), Vector2(16, 11), 20)
static var _GEODE_CORE := Art.ellipse_pts(Vector2(0, -18), Vector2(8, 6), 16)
static var _BOWL := Art.smooth_pts(PackedVector2Array([Vector2(-24, -34), Vector2(24, -34), Vector2(18, -22), Vector2(0, -18), Vector2(-18, -22)]), 2)
static var _NEST := Art.smooth_pts(PackedVector2Array([Vector2(-40, 0), Vector2(-42, -10), Vector2(-30, -16), Vector2(0, -14), Vector2(30, -16), Vector2(42, -10), Vector2(40, 0)]), 3)
static var _PUDDLE := Art.ellipse_pts(Vector2(0, -2), Vector2(34, 6), 22)
static var _BLOB := Art.smooth_pts(PackedVector2Array([Vector2(-16, 0), Vector2(-15, -10), Vector2(-8, -20), Vector2(0, -23), Vector2(8, -20), Vector2(15, -10), Vector2(16, 0)]), 3)
static var _BLOB_SHINE := Art.ellipse_pts(Vector2(-7, -16), Vector2(3.5, 2.2), 10, -0.5)
static var _TUFT := Art.smooth_pts(PackedVector2Array([Vector2(-14, 0), Vector2(-12, -6), Vector2(-6, -10), Vector2(0, -8), Vector2(6, -11), Vector2(12, -6), Vector2(14, 0)]), 2)
static var _THORN_PLANT := Art.union([Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, 0), Vector2(-4, -24), Vector2(2, -46), Vector2(-2, -60)]), 3.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		PackedVector2Array([Vector2(-2, -20), Vector2(-14, -26), Vector2(-3, -28)]), PackedVector2Array([Vector2(1, -38), Vector2(13, -44), Vector2(2, -46)])])
static var _TAIL_C := PackedVector2Array([Vector2(0, -14), Vector2(110, -6), Vector2(110, 6), Vector2(0, 14)])
static var _LEAF := Art.smooth_pts(PackedVector2Array([Vector2(1, -8), Vector2(12, -14), Vector2(18, -10), Vector2(10, -6)]), 2)
static var _PETAL := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-5, -7), Vector2(0, -12), Vector2(5, -7)]), 2)


# --- The jungle: temple tunnels ---------------------------------------------------------
#
# Golden sandstone halls built of carved blocks, glyph friezes, vines and
# roots, torches in stone sconces. Shallow halls get daylight through cracks
# and butterflies; deeper ones turn mossy, then jade-lit and golden, with
# glowing glyphs and fireflies. Still parts go in the _bg / _edge layers;
# the moving ones use cached shapes moved with Art.push.

const JG_STONE := Color("cdb882")
const JG_STONE_LIT := Color("eadcae")
const JG_LEAF := Color("3ec85a")
const JG_LEAF_DARK := Color("2a9a4a")
const JG_LEAF_LIGHT := Color("7ae06a")
const JG_VINE := Color("4a9a3a")
const JG_ROOT := Color("8a6a44")
## Warm dark of the halls' shadows (not the cool shade of the sea).
const JG_DUSK := Color("2a1408")
const JG_GOLD := Color("ffc93c")
const JG_JADE := Color("34c88a")
const JG_FLOWERS: Array[Color] = [Color("ff7a3a"), Color("ff4fa8"), Color("ffd23f"), Color("b06aff")]


## Rock around the hall: courses of big carved blocks with moss on top.
func _temple_masonry(ci: CanvasItem, w: float, h: float, rock: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 131 + 17
	var mortar := Art.shade_of(rock, 0.42)
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), mortar)
	var ch := 26.0
	var rows := int(ceil(h / ch))
	for r in rows:
		var y := r * ch
		var x := -float((r * 37 + index * 11) % 50)
		while x < w:
			var bw := rng.randf_range(46.0, 74.0)
			var rect := Rect2(x + 1.5, y + 1.5, bw - 3.0, ch - 3.0)
			var tone := rock.lightened(rng.randf_range(-0.03, 0.1))
			Art.flat(ci, Art.rrect_pts(rect, 3.0, 1), tone)
			Art.flat(ci, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 2, rect.position.y + 3), rect.position + Vector2(2, 3)]), tone.lightened(0.14))
			Art.flat(ci, PackedVector2Array([Vector2(rect.position.x + 2, rect.end.y - 4), Vector2(rect.end.x - 2, rect.end.y - 4), rect.end, Vector2(rect.position.x, rect.end.y)]), Art.shade_of(tone, 0.16))
			var roll := rng.randf()
			if roll < 0.12:
				_carve(ci, _GLYPHS[rng.randi() % _GLYPHS.size()], rect.get_center(), 0.7, tone)
			elif roll < 0.2:
				# A cracked block.
				var a := rect.position + Vector2(bw * 0.3, 3)
				Art.line_c(ci, PackedVector2Array([a, a + Vector2(4, 7), a + Vector2(-1, 13), a + Vector2(5, ch - 6)]), Art.shade_of(tone, 0.4), 1.6)
			x += bw
	# Moss tufts along a few block tops.
	for k in 4:
		var p := Vector2(rng.randf_range(10, w - 10), float(rng.randi_range(0, rows - 1)) * ch + 2.0)
		Art.toon(ci, Art.moved(_MOSS_TOP, p), Color(JG_LEAF, 0.95) if k % 2 else JG_LEAF_DARK, 1.6, 0.3)


## Engraved line art: a dark groove with a lit lower lip.
func _carve(ci: CanvasItem, pts: PackedVector2Array, at: Vector2, s: float, on: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.line_c(ci, pts, Color(1, 1, 1, 0.22), 3.0)
	Art.push(ci, Vector2(0, -1.2))
	Art.line_c(ci, pts, Art.shade_of(on, 0.42), 2.4)
	Art.pop(ci)
	Art.pop(ci)


## Vines and leaves on the rock outside the hall.
func _jungle_wall(ci: CanvasItem, w: float, h: float, rock: Color, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var x := rng.randf_range(0.0, w - 20.0)
		if x > World.SHAFT_L - 10.0 and x < World.SHAFT_R + 10.0:
			x += 90.0
		var v: Array = _VINES[(k + index) % _VINES.size()]
		Art.push(ci, Vector2(x, -2), 0.0, Vector2(1.0, 0.45))
		Art.toon(ci, v[0], JG_LEAF_DARK if k % 2 else JG_LEAF, 2.0, 0.3)
		Art.pop(ci)


## The lift shaft in the jungle: bamboo braces lashed with rope, a vine.
func _jungle_shaft(ci: CanvasItem, h: float) -> void:
	var l := World.SHAFT_L - 8.0
	var r := World.SHAFT_R + 8.0
	for y: float in [7.0, 15.0]:
		Art.t_rect(ci, Rect2(l, y, r - l, 7), 3.5, Color("c4bc5a"), 2.2, 0.3)
		for k in 3:
			var nx := lerpf(l + 12.0, r - 12.0, k / 2.0) + (4.0 if y > 10.0 else 0.0)
			Art.line_c(ci, PackedVector2Array([Vector2(nx, y + 1), Vector2(nx, y + 6)]), Color("8a8a30"), 1.6)
	for x: float in [World.SHAFT_L + 2.0, World.SHAFT_R - 2.0]:
		Art.t_rect(ci, Rect2(x - 4, 5, 8, 19), 2, Color("b08a50"), 1.8, 0.0)
		Art.line_c(ci, PackedVector2Array([Vector2(x - 4, 10), Vector2(x + 4, 13)]), Color("7a5a30"), 1.4)
		Art.line_c(ci, PackedVector2Array([Vector2(x - 4, 16), Vector2(x + 4, 19)]), Color("7a5a30"), 1.4)
	# A vine down the shaft's left wall on every other row.
	if index % 2 == 0:
		Art.push(ci, Vector2(World.SHAFT_L + 4, 20))
		Art.toon(ci, _VINES[index % _VINES.size()][0], JG_LEAF, 2.0, 0.3)
		Art.pop(ci)


## The hall: courses of carved blocks, a glyph frieze, light pooled around
## the torches, daylight through a crack (shallow) or magic light (deep).
func _temple_hall(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, inner: Color, st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 59 + 23
	var mortar := Art.shade_of(inner, 0.38)
	Art.flat(ci, cp, mortar)
	var deep := index >= 6
	var glow: Color = st.get("glow", JG_GOLD)
	var ch := 29.0
	var frieze_y := cave.position.y + 30.0
	var y := cave.position.y - 4.0
	var r := 0
	while y < LEDGE_Y:
		if r == 1:
			_frieze(ci, cave, cp, frieze_y, inner, glow)
			y = frieze_y + 22.0
			r += 1
			continue
		var x := cave.position.x - 30.0 - float((r * 23 + index * 7) % 40)
		while x < cave.end.x + 10.0:
			var bw := rng.randf_range(48.0, 72.0)
			var rect := Rect2(x + 1.5, y + 1.5, bw - 3.0, ch - 3.0)
			var tone := inner.lightened(rng.randf_range(-0.02, 0.09))
			var face := Art.clipped(Art.rrect_pts(rect, 3.0, 1), cp)
			if face.size() >= 3:
				Art.flat(ci, face, tone)
				var lip := Art.clipped(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 3), rect.position + Vector2(0, 3)]), cp)
				if lip.size() >= 3:
					Art.flat(ci, lip, tone.lightened(0.13))
				var low := Art.clipped(PackedVector2Array([Vector2(rect.position.x, rect.end.y - 4), Vector2(rect.end.x, rect.end.y - 4), rect.end, Vector2(rect.position.x, rect.end.y)]), cp)
				if low.size() >= 3:
					Art.flat(ci, low, Art.shade_of(tone, 0.15))
				var inside := Geometry2D.is_point_in_polygon(rect.position, cp) and Geometry2D.is_point_in_polygon(rect.end, cp)
				var roll := rng.randf()
				if inside and roll < 0.16:
					_carve(ci, _GLYPHS[rng.randi() % _GLYPHS.size()], rect.get_center(), 0.75, tone)
				elif inside and deep and roll < 0.24:
					# Gold inlay in the deep halls.
					Art.t_rect(ci, Rect2(rect.get_center() - Vector2(5, 5), Vector2(10, 10)), 2, JG_GOLD, 1.6, 0.3)
			x += bw
		y += ch
		r += 1
	# Light: warm pools around the torches, shade under the ceiling and
	# down the walls.
	for tx: float in _torch_xs(cave):
		Art.glow(ci, Vector2(tx, CAVE_TOP + 74), 150.0, Color(1.0, 0.7, 0.32, 0.26), 20)
		Art.glow(ci, Vector2(tx, CAVE_TOP + 74), 60.0, Color(1.0, 0.82, 0.5, 0.2), 16)
	Art.flat(ci, Art.clipped(_wall_band(cave), cp), Color(JG_DUSK, 0.26))
	# Shadow where the wall meets the floor.
	var foot := PackedVector2Array([Vector2(cave.position.x + 24, LEDGE_Y - 34), Vector2(cave.end.x - 24, LEDGE_Y - 34),
			Vector2(cave.end.x - 24, LEDGE_Y), Vector2(cave.position.x + 24, LEDGE_Y)])
	Art.grad(ci, foot, PackedColorArray([Color(JG_DUSK, 0.0), Color(JG_DUSK, 0.0), Color(JG_DUSK, 0.3), Color(JG_DUSK, 0.3)]))
	var top_shade := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 4, cave.position.y - 4), Vector2(cave.end.x + 4, cave.position.y - 4),
			Vector2(cave.end.x + 4, cave.position.y + 16), Vector2(cave.position.x - 4, cave.position.y + 16)]), cp)
	Art.flat(ci, top_shade, Color(JG_DUSK, 0.26))
	if index <= 3:
		# Daylight falling through a crack in the ceiling.
		var bx := lerpf(cave.position.x + 160.0, cave.end.x - 150.0, 0.35 + 0.2 * (index % 2))
		var beam := PackedVector2Array([Vector2(bx - 8, cave.position.y - 4), Vector2(bx + 12, cave.position.y - 4),
				Vector2(bx + 64, LEDGE_Y + 6), Vector2(bx + 6, LEDGE_Y + 6)])
		Art.flat(ci, Art.clipped(beam, cp), Color(1.0, 0.97, 0.78, 0.16))
		Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(bx + 36, LEDGE_Y + 2), Vector2(34, 7), 18), cp), Color(1.0, 0.95, 0.7, 0.22))
		Art.flat(ci, Art.ellipse_pts(Vector2(bx + 2, cave.position.y + 1), Vector2(12, 3), 12), Color(1.0, 1.0, 0.85, 0.9))
	if index >= 4:
		# Magic light from the depths: soft pools in the site's color.
		var a := clampf(0.08 + (index - 4) * 0.03, 0.0, 0.24)
		Art.glow(ci, Vector2(cave.get_center().x, LEDGE_Y - 40), cave.size.x * 0.42, Color(glow, a), 24)


## The glyph frieze: a carved band of step-frets with round glyph stones;
## its grooves glow in the deeper halls.
func _frieze(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, y: float, inner: Color, glow: Color) -> void:
	var band := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 4, y), Vector2(cave.end.x + 4, y),
			Vector2(cave.end.x + 4, y + 20), Vector2(cave.position.x - 4, y + 20)]), cp)
	var tone := inner.lightened(0.12)
	Art.flat(ci, band, tone)
	Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(cave.position.x - 4, y), Vector2(cave.end.x + 4, y),
			Vector2(cave.end.x + 4, y + 3), Vector2(cave.position.x - 4, y + 3)]), cp), tone.lightened(0.15))
	Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(cave.position.x - 4, y + 17), Vector2(cave.end.x + 4, y + 17),
			Vector2(cave.end.x + 4, y + 20), Vector2(cave.position.x - 4, y + 20)]), cp), Art.shade_of(tone, 0.25))
	var x0 := cave.position.x + 34.0
	var x1 := cave.end.x - 34.0
	var lit := index >= 4
	var x := x0
	var k := 0
	while x + 24.0 < x1:
		if k % 4 == 3:
			Art.t_circle(ci, Vector2(x + 12, y + 10), 6.5, tone.lightened(0.08), 1.8, 0.3)
			if lit:
				Art.glow(ci, Vector2(x + 12, y + 10), 12.0, Color(glow, 0.5), 10)
			Art.flat(ci, Art.circle_pts(Vector2(x + 12, y + 10), 2.6, 8), glow if lit else Art.shade_of(tone, 0.4))
		else:
			var pts := Art.moved(_FRET, Vector2(x, y + 4))
			if lit:
				Art.line_c(ci, pts, Color(glow, 0.35), 4.0)
				Art.line_c(ci, pts, glow.lightened(0.3), 1.6)
			else:
				_carve(ci, pts, Vector2.ZERO, 1.0, tone)
		x += 24.0
		k += 1


## Floor of big flagstones with grass in the seams.
func _temple_floor(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, stone: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 41 + 9
	var seam := Art.shade_of(stone, 0.35)
	var a := World.SHAFT_R + 6.0
	var b := cave.end.x - 30.0
	Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(World.SHAFT_L, LEDGE_Y - 4), Vector2(cave.end.x + 10, LEDGE_Y - 4),
			Vector2(cave.end.x + 10, LEDGE_Y + 2), Vector2(World.SHAFT_L, LEDGE_Y + 2)]), cp), stone.lightened(0.16))
	var rows: Array[float] = [LEDGE_Y + 2.0, LEDGE_Y + 15.0, CAVE_BOTTOM - 4.0]
	for i in 2:
		Art.line_c(ci, PackedVector2Array([Vector2(a, rows[i + 1]), Vector2(b, rows[i + 1])]), seam, 2.0)
		var x := a + 10.0 + float((index * 17 + i * 23) % 30)
		while x < b - 20.0:
			Art.line_c(ci, PackedVector2Array([Vector2(x, rows[i] + 1), Vector2(x - 2.0 - i * 2.0, rows[i + 1] - 1)]), seam, 2.0)
			# A lit edge on each slab.
			Art.line_c(ci, PackedVector2Array([Vector2(x + 2, rows[i] + 2), Vector2(x + 26, rows[i] + 2)]), Color(1, 1, 1, 0.16), 1.6)
			x += rng.randf_range(44.0, 70.0)
	# Grass and little plants in the seams, a few leaves on the floor.
	for k in 6:
		var p := Vector2(rng.randf_range(a + 30, b - 20), rows[1 + k % 2] - 1.0)
		Art.push(ci, p, 0.0, Vector2.ONE * rng.randf_range(0.45, 0.7))
		Art.toon(ci, _TUFT_J, JG_LEAF if k % 2 else JG_LEAF_LIGHT, 1.8, 0.3)
		Art.pop(ci)
	for k in 4:
		var p := Vector2(rng.randf_range(a + 20, b - 10), rng.randf_range(LEDGE_Y + 5, CAVE_BOTTOM - 8))
		Art.push(ci, p, rng.randf_range(-PI, PI), Vector2.ONE * 0.6)
		Art.toon(ci, _LEAF_J, Color("c8a040") if k % 2 else JG_LEAF_DARK, 1.4, 0.2)
		Art.pop(ci)
	var foot := PackedVector2Array([Vector2(World.SHAFT_L, CAVE_BOTTOM - 14), Vector2(cave.end.x + 10, CAVE_BOTTOM - 14),
			Vector2(cave.end.x + 10, CAVE_BOTTOM + 10), Vector2(World.SHAFT_L, CAVE_BOTTOM + 10)])
	Art.flat(ci, Art.clipped(foot, cp), Color(seam, 0.3))


## The doorway into the hall: two stacked stone pillars under a carved
## lintel with a jade (gold, deeper) eye and a vine over it.
func _stone_portal(ci: CanvasItem, h: float, w: float, st: Dictionary) -> void:
	var stone := JG_STONE.lerp(st["floor"], 0.35)
	var gem: Color = JG_JADE if index < 6 else JG_GOLD
	for x: float in [0.0, w]:
		var y := 0.0
		var k := 0
		while y > -h + 4.0:
			var bh := 26.0 if k % 2 == 0 else 22.0
			Art.t_rect(ci, Rect2(x - 9, y - bh, 18, bh), 2.5, stone if k % 2 == 0 else stone.darkened(0.06), 2.4, 0.4)
			y -= bh
			k += 1
		Art.t_rect(ci, Rect2(x - 12, -8, 24, 8), 2, stone.darkened(0.1), 2.4, 0.3)
	Art.t_rect(ci, Rect2(-20, -h - 14, w + 40, 22), 4, stone, 2.8, 0.5)
	Art.t_rect(ci, Rect2(-16, -h - 22, w + 32, 10), 3, stone.lightened(0.06), 2.4, 0.3)
	for k in 2:
		_carve(ci, _FRET, Vector2(-8 + k * (w - 8.0), -h - 8), 0.8, stone)
	Art.t_circle(ci, Vector2(w / 2.0, -h - 3), 6.5, stone.lightened(0.1), 2.0, 0.3)
	Art.t_circle(ci, Vector2(w / 2.0, -h - 3), 3.6, gem, 1.4, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(w / 2.0 - 1.2, -h - 4.4), 1.0, 6), Color(1, 1, 1, 0.9))
	# A vine over the lintel.
	Art.push(ci, Vector2(w + 16, -h - 6), 0.0, Vector2(1.0, 0.8))
	Art.toon(ci, _VINES[(index + 1) % _VINES.size()][0], JG_LEAF, 2.0, 0.3)
	Art.pop(ci)
	Art.push(ci, Vector2(-16, -h - 6), 0.0, Vector2(-0.8, 0.7))
	Art.toon(ci, _VINES[(index + 2) % _VINES.size()][0], JG_LEAF_DARK, 2.0, 0.3)
	Art.pop(ci)


## Still things in the hall: roots from the ceiling, ferns in the corners.
func _temple_furniture(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 13 + 5
	for k in 3:
		var x := lerpf(World.CAVE_L + 140.0, cave.end.x - 90.0, (k + rng.randf_range(0.1, 0.8)) / 3.0)
		var len := rng.randf_range(24.0, 46.0) * (1.3 if index >= 5 else 1.0)
		var root := PackedVector2Array([Vector2(x, CAVE_TOP - 6), Vector2(x + 3, CAVE_TOP + len * 0.4), Vector2(x - 2, CAVE_TOP + len * 0.75), Vector2(x + 1, CAVE_TOP + len)])
		Art.line_c(ci, root, Art.INK, 6.0)
		Art.line_c(ci, root, JG_ROOT, 3.2)
		var fork := PackedVector2Array([root[1], root[1] + Vector2(8, 10), root[1] + Vector2(10, 18)])
		Art.line_c(ci, fork, Art.INK, 4.4)
		Art.line_c(ci, fork, JG_ROOT, 2.0)
	# Ferns at the foot of the walls.
	for p: Vector3 in [Vector3(World.CAVE_L + 112.0, 1.0, 1.0), Vector3(cave.end.x - 16.0, 0.9, -1.0)]:
		Art.push(ci, Vector2(p.x, LEDGE_Y + 4), 0.0, Vector2(p.z, 1.0) * p.y)
		Art.toon(ci, _FERN, JG_LEAF_DARK, 2.0, 0.4)
		Art.toon(ci, _FERN_FRONT, JG_LEAF, 2.0, 0.4)
		Art.pop(ci)


## Phones: the hall is too small for all the greenery.
func _narrow(cave: Rect2) -> bool:
	return cave.end.x - World.CAVE_L < 460.0


## Torch places in the hall (one in narrow halls).
func _torch_xs(cave: Rect2) -> Array[float]:
	var a := World.CAVE_L + 128.0
	var b := cave.end.x - 116.0
	if b - a < 90.0:
		return [a]
	return [a, b]


## A torch in a carved stone sconce, its flame flickering.
func _jg_torch(at: Vector2) -> void:
	var flick := snappedf(0.85 + 0.15 * sin(_t * 9.0 + at.x * 0.1) + 0.05 * sin(_t * 23.0 + at.x), 0.05)
	Art.glow(self, at + Vector2(0, -16), 56.0, Color(1.0, 0.62, 0.25, 0.3 * flick), 16)
	Art.toon(self, Art.moved(_SCONCE, at), JG_STONE, 2.2, 0.4)
	Art.push(self, at + Vector2(0, -2), 0.0)
	Art.t_rect(self, Rect2(-3.5, -8, 7, 16), 2, Art.WOOD_DARK, 2.0, 0.0)
	Art.t_rect(self, Rect2(-6, -12, 12, 6), 2, Color("6a5a3a"), 2.0, 0.0)
	Art.push(self, Vector2(0, -11), sin(_t * 7.0 + at.x) * 0.1, Vector2(1.0, flick) * 1.15)
	Art.toon(self, _FLAME, Color("ff8a2a"), 2.0, 0.0)
	Art.flat(self, _FLAME_IN, Color("ffe066"))
	Art.pop(self)
	Art.pop(self)
	# Sparks rising from it.
	for k in 2:
		var f := fposmod(_t * 0.7 + k * 0.5 + at.x * 0.01, 1.0)
		Art.dot(self, at + Vector2(sin(_t * 3.0 + k * 2.0) * 5.0 * f, -30.0 - f * 34.0), 1.6 * (1.0 - f) + 0.5, Color(1.0, 0.8, 0.35, 1.0 - f))


## Moving life of every jungle hall: vines swaying from the ceiling,
## daylight motes (shallow), fireflies and magic motes (deep).
func _jungle_life(st: Dictionary, cave: Rect2) -> void:
	var glow: Color = st.get("glow", JG_GOLD)
	var top := CAVE_TOP - 2.0
	var xs: Array[float] = [World.CAVE_L + 186.0, lerpf(World.CAVE_L + 170.0, cave.end.x - 70.0, 0.26 + 0.06 * (index % 3 - 1)), cave.end.x - 54.0]
	if _narrow(cave):
		# Phones: one vine, the hall is small.
		xs = [cave.end.x - 64.0]
	for k in xs.size():
		var v: Array = _VINES[(k + index * 2) % _VINES.size()]
		Art.push(self, Vector2(xs[k], top), sin(_t * 0.8 + k * 1.9 + index) * 0.06, Vector2(1.0 if k % 2 else -1.0, 0.8 + 0.25 * ((k + index) % 2)))
		Art.toon(self, v[0], JG_LEAF if k != 1 else JG_LEAF_DARK, 2.0, 0.35)
		var fl: Vector2 = v[1]
		Art.t_circle(self, fl, 3.4, JG_FLOWERS[(k + index) % JG_FLOWERS.size()], 1.4, 0.0)
		Art.dot(self, fl, 1.2, Color("fff2a0"))
		Art.pop(self)
	var x0 := World.CAVE_L + 100.0
	var x1 := cave.end.x - 70.0
	if index <= 3:
		# Dust glittering in the daylight.
		var bx := lerpf(cave.position.x + 160.0, cave.end.x - 150.0, 0.35 + 0.2 * (index % 2))
		for k in 4:
			var f := fposmod(_t * 0.05 + k * 0.25, 1.0)
			var p := Vector2(bx + 6.0 + f * 40.0 + sin(_t * 0.7 + k * 2.0) * 6.0, lerpf(CAVE_TOP + 10.0, LEDGE_Y - 6.0, f))
			Art.dot(self, p, 1.4, Color(1, 1, 0.85, 0.75 * sin(f * PI)))
	if index >= 4:
		var n := 3 + (index - 4)
		for k in n:
			var f := fposmod(_t * 0.045 + k / float(n), 1.0)
			var p := Vector2(lerpf(x0, x1, fposmod(k * 0.379 + f * 0.25, 1.0)) + sin(_t * 0.9 + k * 1.7) * 14.0,
					lerpf(LEDGE_Y - 14.0, CAVE_TOP + 24.0, f) + sin(_t * 1.6 + k) * 6.0)
			var a := sin(f * PI) * (0.6 + 0.4 * sin(_t * 5.0 + k * 2.3))
			Art.glow(self, p, 9.0, Color(glow, snappedf(0.45 * a, 0.05)), 10)
			Art.dot(self, p, 1.8, Color(glow.lightened(0.4), a))


## Leafy clumps hanging over the hall's edge (still, in front of the
## glowing vein, behind the workers).
func _edge_drapes(ci: CanvasItem, cave: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 19 + 3
	var spots: Array[float] = [cave.position.x + 156.0, lerpf(cave.position.x + 220.0, cave.end.x - 80.0, 0.72 + rng.randf() * 0.12), cave.end.x - 30.0]
	if _narrow(cave):
		spots = [cave.end.x - 30.0]
	for k in spots.size():
		var at := Vector2(spots[k], cave.position.y + (6.0 if k != 1 else 0.0))
		Art.push(ci, at, 0.0, Vector2(1.0 if k % 2 == 0 else -1.0, 1.0) * (0.9 + 0.25 * rng.randf()))
		Art.toon(ci, _CLUMP_BACK, JG_LEAF_DARK, 2.2, 0.3)
		Art.toon(ci, _CLUMP, JG_LEAF, 2.2, 0.4)
		for p: Vector2 in _CLUMP_VEINS:
			Art.line_c(ci, PackedVector2Array([Vector2.ZERO, p]), Color(JG_LEAF_DARK, 0.6), 1.2)
		if (k + index) % 2 == 0:
			var fc: Color = JG_FLOWERS[(k + index) % JG_FLOWERS.size()]
			Art.toon(ci, _FLOWER, fc, 1.6, 0.3)
			Art.t_circle(ci, Vector2(6, 10), 2.4, Color("ffe066"), 1.2, 0.0)
		Art.pop(ci)
	# Moss at the bottom corners of the hall.
	for p: Vector2 in [Vector2(cave.position.x + 30.0, CAVE_BOTTOM - 2.0), Vector2(cave.end.x - 34.0, CAVE_BOTTOM - 2.0)]:
		Art.toon(ci, Art.moved(_MOSS_LOW, p), JG_LEAF_DARK, 1.8, 0.3)


# --- Set pieces of the temple halls -------------------------------------------------

## Decor of the jungle halls (true when drawn).
func _draw_decor_jungle(st: Dictionary, cave: Rect2) -> bool:
	var y := LEDGE_Y
	var top := CAVE_TOP + 4.0
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var fit := clampf((cave.end.x - World.CAVE_L) / 520.0, 0.55, 1.0)
	match st["deco"]:
		"jg_clay":
			# Painted urns and a broken pot; a gecko crawling over the wall.
			for p: Vector3 in [Vector3(x0 - 20, 1.25, 1), Vector3(x0 + 10, 0.8, 0), Vector3(x1 + 26, 1.05, 3)]:
				OreArt.piece(self, "clay", Vector2(p.x, y + 3), p.y, 0.0, st, _t, int(p.z))
			for p: Vector3 in [Vector3(mid + 14, 0.45, 0.6), Vector3(mid + 30, 0.4, -0.4), Vector3(mid + 2, 0.35, 1.4)]:
				OreArt.piece(self, "clay", Vector2(p.x, y + 4), p.y, p.z, st, _t, 2)
			_gecko(Vector2(lerpf(x0 - 40, x1 + 50, 0.5 - 0.5 * cos(_t * 0.11 + index)), top + 58 + sin(_t * 0.23) * 14.0), sin(_t * 0.11 + index))
		"jg_cocoa":
			# A cocoa tree's branch grown in through the wall under the
			# ceiling: big leaves, pods hanging and swaying.
			var br := _cocoa_branch(cave.end.x + 10.0, mid - 30.0 * fit, top)
			Art.toon(self, br[0], Color("8a5a34"), 2.6, 0.5)
			Art.line_c(self, br[1], Color("6a4224"), 1.6)
			var bp: PackedVector2Array = br[1]
			for k in 4:
				var lp := bp[mini(bp.size() - 1, 1 + k * 2)]
				Art.push(self, lp, (0.7 if k % 2 else -0.6) + sin(_t * 0.5 + k) * 0.05, Vector2.ONE * (1.0 - 0.12 * (k % 2)))
				Art.toon(self, _BIG_LEAF, JG_LEAF if k % 2 else JG_LEAF_DARK, 2.2, 0.4)
				Art.line_c(self, _BIG_LEAF_VEIN, Color(JG_LEAF_DARK.darkened(0.2), 0.7), 1.4)
				Art.pop(self)
			for k in 3:
				var at := bp[mini(bp.size() - 1, 2 + k * 2)] + Vector2(0, 5)
				Art.line_c(self, PackedVector2Array([at + Vector2(0, -6), at + Vector2(0, 4)]), Color("6a4424"), 2.0)
				Art.push(self, at, sin(_t * 1.3 + k * 2.0) * 0.12)
				OreArt.piece(self, "cocoa", Vector2(0, 32), 0.7, 0.0, st, _t, k)
				Art.pop(self)
			OreArt.jungle_centerpiece(self, "cocoa", Vector2(x0 - 16, y + 2), 0.9, st, _t, 1)
			for k in 2:
				var fly := Vector2(lerpf(x0, x1 + 20, 0.5 + 0.45 * sin(_t * 0.31 + k * 2.5)), top + 50 + k * 34 + sin(_t * 0.9 + k) * 18.0)
				_butterfly(fly, k, Color("3fa8ff") if k == 0 else Color("ff8a3d"))
		"jg_pool":
			_spout_pool(st, mid + 6.0, y, top, fit)
		"jg_coins":
			# A treasure chest spilling coins, an urn tipped over, a coin rolling.
			OreArt.jungle_centerpiece(self, "old_coins", Vector2(mid, y + 2), 1.35 * fit, st, _t, index)
			Art.push(self, Vector2(x0 - 20, y - 4), -1.35, Vector2.ONE * 0.9)
			OreArt.piece(self, "clay", Vector2.ZERO, 1.0, 0.0, Art.SITE_STYLE["clay"], _t, 0)
			Art.pop(self)
			for k in 4:
				OreArt.piece(self, "old_coins", Vector2(x0 + 6 + k * 9, y + 4), 0.32, 1.2 + k * 0.4, st, _t, 2)
			OreArt.piece(self, "old_coins", Vector2(x1 + 30, y + 3), 0.75, 0.0, st, _t, 1)
			var f := fposmod(_t * 0.09 + index * 0.3, 1.0)
			if f < 0.6:
				var rx := lerpf(x1 + 10, x0 + 50, f / 0.6)
				Art.push(self, Vector2(rx, y - 6), -(rx - x0) / 7.0, Vector2.ONE * 0.55)
				OreArt.piece(self, "old_coins", Vector2(0, 14), 1.0, 0.0, st, _t, 0)
				Art.pop(self)
			_twinkles(x0, x1, top, y, Color("fff1a8"), 4)
		"jg_masks":
			_wall_mask(st, Vector2(mid + 4, top + 104), 2.1 * fit + 0.3)
			for p: Vector3 in [Vector3(x0 - 30, top + 46, 0.0), Vector3(x1 + 30, top + 52, 1.0)]:
				Art.line_c(self, PackedVector2Array([Vector2(p.x, p.y - 22), Vector2(p.x, p.y - 34)]), Art.INK, 1.6)
				Art.push(self, Vector2(p.x, p.y - 22), sin(_t * 1.1 + p.z * 2.0) * 0.08)
				OreArt.piece(self, "mask", Vector2(0, 38), 0.95, 0.0, st, _t, int(p.z))
				Art.pop(self)
			for x: float in [x0 - 4, x1 + 10]:
				Art.push(self, Vector2(x, y + 3))
				Art.toon(self, _URN_FIRE, Color("8a8472"), 2.2, 0.4)
				Art.pop(self)
				_small_flame(Vector2(x, y - 14), ore2)
		"jg_jaguar":
			# Two stone jaguars guard the hall, facing each other.
			var gap := 64.0 * fit + 26.0
			for k in 2:
				_jaguar(Vector2(mid + (gap if k == 1 else -gap), y + 3), -1.0 if k == 1 else 1.0, ore, ore2, k, 0.8 + 0.3 * fit)
			# Tiger's eyes set in carved sockets in the wall between them.
			for k in 3:
				var gp := Vector2(mid + (k - 1) * 34.0 * fit, top + 62 + (k % 2) * 16)
				Art.t_circle(self, gp + Vector2(0, -8), 12.0, Color("8a7450"), 2.2, 0.4)
				OreArt.piece(self, "tiger_eye", gp + Vector2(0, 3), 0.5, 0.0, st, _t, k)
			_twinkles(mid - 60, mid + 60, top + 30, top + 120, ore2, 3)
		"jg_idol":
			_idol_altar(st, Vector2(mid, y + 3), top, fit)
		"jg_sun":
			_sun_wall(st, Vector2(mid + 4, top + 84), fit)
			for x: float in [x0 - 10, x1 + 24]:
				Art.push(self, Vector2(x, y + 3))
				Art.toon(self, _URN_FIRE, JG_GOLD, 2.2, 0.5)
				Art.pop(self)
				_small_flame(Vector2(x, y - 14), Color("ffe066"))
			# Marigold petals drifting down.
			for k in 5:
				var f := fposmod(_t * 0.06 + k * 0.2, 1.0)
				var p := Vector2(lerpf(x0 - 50, x1 + 60, fposmod(k * 0.41, 1.0)) + sin(_t * 1.2 + k) * 12.0, lerpf(top + 10, y - 4, f))
				Art.push(self, p, _t * 1.5 + k, Vector2(1.0, 0.6 + 0.4 * sin(_t * 3.0 + k)))
				Art.toon(self, _PETAL_J, Color("ffa02e") if k % 2 else Color("ffd23f"), 1.2, 0.0)
				Art.pop(self)
		"jg_serpent":
			_serpent_wall(st, cave, x0, x1, top, fit)
		"jg_heart":
			_heart_altar(st, Vector2(mid + 4, y + 3), top, x0, x1, fit)
		_:
			return _draw_decor_jungle_deep(st, cave)
	return true


## The sealed halls under the temple heart (Jungle sites 11..15): one set
## piece each, few shapes (the jungle mine is the busiest view).
func _draw_decor_jungle_deep(st: Dictionary, cave: Rect2) -> bool:
	var y := LEDGE_Y
	var top := CAVE_TOP + 4.0
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var glow: Color = st.get("glow", ore)
	var fit := clampf((cave.end.x - World.CAVE_L) / 520.0, 0.55, 1.0)
	match st["deco"]:
		"jg_jade":
			# A jade jaguar on its pedestal between two jade-fire urns.
			Art.glow(self, Vector2(mid, y - 50), 90.0 * fit + 20.0, Color(glow, 0.2), 16)
			OreArt.jungle_deep_centerpiece(self, "jade_jaguar", Vector2(mid, y + 3), 1.15 * fit + 0.3, st, _t, index)
			for x: float in [x0 - 10, x1 + 24]:
				Art.push(self, Vector2(x, y + 3))
				Art.toon(self, _URN_FIRE, Color("6a8a74"), 2.2, 0.4)
				Art.pop(self)
				_small_flame(Vector2(x, y - 14), glow)
			_twinkles(x0, x1, top + 20, y - 40, ore2, 3)
		"jg_scarab":
			# A great scarab carved in the wall, little ones crawling below.
			Art.glow(self, Vector2(mid, top + 80), 70.0 * fit + 20.0, Color(glow, 0.18), 14)
			Art.t_circle(self, Vector2(mid, top + 86), 34.0 * fit + 10.0, Color(st["floor"]).darkened(0.12), 2.4, 0.4)
			Art.arc_c(self, Vector2(mid, top + 86), 28.0 * fit + 8.0, 0, TAU, 24, Color(JG_GOLD, 0.7), 2.0)
			OreArt.piece(self, "emerald_scarab", Vector2(mid, top + 108 + 10.0 * fit), 1.5 * fit + 0.2, 0.0, st, _t, 0)
			for k in 2:
				var f := fposmod(_t * 0.05 + k * 0.5, 1.0)
				var cx := lerpf(x0 - 30, x1 + 40, f if k == 0 else 1.0 - f)
				Art.push(self, Vector2(cx, y + 2), (PI / 2.0) * (1.0 if k == 0 else -1.0), Vector2.ONE * 0.4)
				OreArt.piece(self, "emerald_scarab", Vector2(0, 14), 1.0, 0.0, st, _t, k)
				Art.pop(self)
			for p: Vector3 in [Vector3(x0 - 16, 0.7, 0), Vector3(x1 + 30, 0.6, 1)]:
				OreArt.piece(self, "emerald_scarab", Vector2(p.x, y + 3), p.y, 0.0, st, _t, int(p.z))
		"jg_feather":
			# The quetzal headdress on a stand; loose plumes drift down.
			Art.t_rect(self, Rect2(mid - 5, y - 30, 10, 30), 3, JG_STONE, 2.2, 0.4)
			OreArt.jungle_deep_centerpiece(self, "sky_feather", Vector2(mid, y - 26), 1.25 * fit + 0.25, st, _t, index)
			for k in 3:
				var f := fposmod(_t * 0.05 + k * 0.33, 1.0)
				var p := Vector2(lerpf(x0 - 40, x1 + 50, fposmod(k * 0.37 + 0.1, 1.0)) + sin(_t * 0.9 + k) * 18.0, lerpf(top + 6, y - 10, f))
				Art.push(self, p, sin(_t * 1.1 + k) * 0.6 + 0.9, Vector2.ONE * 0.5)
				OreArt.piece(self, "sky_feather", Vector2(0, 22), 1.0, 0.0, st, _t, k)
				Art.pop(self)
		"jg_rain":
			# Rain crystals grow from the floor; drops fall from the roof
			# into a shallow pool.
			Art.t_ellipse(self, Vector2(mid, y + 1), Vector2(70.0 * fit + 16.0, 7.0), Color(ore, 0.45), 2.0, 0.0)
			for p: Vector3 in [Vector3(x0 - 14, 1.0, 0), Vector3(x1 + 26, 0.85, 1)]:
				OreArt.jungle_deep_centerpiece(self, "rain_crystal", Vector2(p.x, y + 3), p.y, st, _t, int(p.z))
			for k in 3:
				var f := fposmod(_t * 0.45 + k * 0.37, 1.0)
				var dx := mid + (k - 1) * 40.0 * fit
				Art.push(self, Vector2(dx, lerpf(top + 6, y - 6, f)), 0.0, Vector2.ONE * 0.24)
				OreArt.piece(self, "rain_crystal", Vector2(0, 20), 1.0, 0.0, st, _t, 0)
				Art.pop(self)
			_twinkles(x0, x1, top + 10, y - 30, ore2, 3)
		"jg_crown":
			# The sun god's throne hall: the crown on its cushion, golden
			# pillars, heaps of coins.
			Art.glow(self, Vector2(mid, y - 60), 110.0 * fit + 20.0, Color(glow, 0.24), 18)
			for x: float in [mid - 112.0 * fit - 16.0, mid + 112.0 * fit + 16.0]:
				Art.t_rect(self, Rect2(x - 9, top + 10, 18, y - top - 8), 3, JG_GOLD, 2.4, 0.5)
				Art.t_rect(self, Rect2(x - 13, top + 4, 26, 10), 3, Color("e0a52c"), 2.2, 0.3)
				Art.t_rect(self, Rect2(x - 13, y - 8, 26, 10), 3, Color("e0a52c"), 2.2, 0.3)
			Art.t_rect(self, Rect2(mid - 46, y - 16, 92, 16), 3, Color("8a3a2a"), 2.4, 0.4)
			OreArt.jungle_deep_centerpiece(self, "sun_crown", Vector2(mid, y - 13), 1.6 * fit + 0.3, st, _t, index)
			for k in 4:
				OreArt.piece(self, "old_coins", Vector2(x0 + 4 + k * 10, y + 4), 0.32, 1.2 + k * 0.4, st, _t, 2)
			_twinkles(x0, x1, top, y, Color("fff1a8"), 4)
		_:
			return false
	return true


## A little green gecko on the wall, walking along `dir` (sign).
func _gecko(at: Vector2, dir: float) -> void:
	var face := 1.0 if dir >= 0.0 else -1.0
	var step := int(_t * 6.0) % 2
	Art.push(self, at, 0.0, Vector2(face, 1.0))
	for k in 4:
		var lp: Vector2 = [Vector2(6, -3), Vector2(6, 3), Vector2(-6, -3), Vector2(-6, 3)][k]
		var swing := (0.5 if (k + step) % 2 == 0 else -0.5)
		Art.push(self, lp, (-1.0 if lp.y < 0.0 else 1.0) * (PI / 2.0) + swing)
		Art.line_c(self, _GECKO_LEG, Art.INK, 3.6)
		Art.line_c(self, _GECKO_LEG, Color("6ac83a"), 1.8)
		Art.pop(self)
	Art.push(self, Vector2(-10, 0), sin(_t * 3.0) * 0.25)
	Art.line_c(self, _GECKO_TAIL, Art.INK, 5.0)
	Art.line_c(self, _GECKO_TAIL, Color("8ade4a"), 2.8)
	Art.pop(self)
	Art.toon(self, _GECKO, Color("8ade4a"), 2.0, 0.4)
	for p: Vector2 in [Vector2(-4, 0), Vector2(3, -1)]:
		Art.flat(self, Art.circle_pts(p, 1.5, 6), Color("ffb02e"))
	for sy: float in [-2.6, 2.6]:
		Art.flat(self, Art.circle_pts(Vector2(13, sy), 1.4, 6), Art.INK)
	Art.pop(self)


## A fluttering butterfly.
func _butterfly(at: Vector2, k: int, c: Color) -> void:
	var flap := 0.25 + 0.75 * absf(sin(_t * 11.0 + k * 1.3))
	Art.push(self, at, sin(_t * 1.7 + k) * 0.2)
	for sx: float in [-1.0, 1.0]:
		Art.push(self, Vector2.ZERO, 0.0, Vector2(sx * flap, 1.0))
		Art.toon(self, _WING, c, 1.6, 0.3)
		Art.flat(self, _WING_SPOT, Color(1, 1, 1, 0.8))
		Art.pop(self)
	Art.line_c(self, PackedVector2Array([Vector2(0, -5), Vector2(0, 5)]), Art.INK, 2.4)
	Art.pop(self)


## A carved spout head pouring water into a turquoise pool with a lily pad.
func _spout_pool(st: Dictionary, x: float, y: float, top: float, fit: float) -> void:
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var s := 0.7 + 0.3 * fit
	var head := Vector2(x, top + 64)
	var mouth := head + Vector2(0, -8) * 1.15
	# The stream, then the pool over its foot.
	var py := y + 3.0
	Art.flat(self, PackedVector2Array([mouth + Vector2(-4, 0), mouth + Vector2(4, 0), Vector2(x + 6, py - 4), Vector2(x - 6, py - 4)]), Color(ore, 0.75))
	Art.line_c(self, PackedVector2Array([mouth + Vector2(-1, 2), Vector2(x - 2, py - 6)]), Color(1, 1, 1, 0.6), 1.6)
	for k in 4:
		var f := fposmod(_t * 1.4 + k * 0.25, 1.0)
		Art.dot(self, mouth.lerp(Vector2(x, py - 6), f) + Vector2(sin(k * 2.0) * 2.0, 0), 1.6, Color(1, 1, 1, 0.8))
	Art.push(self, head, 0.0, Vector2.ONE * 1.15)
	OreArt.jungle_piece(self, "mask", OreArt.JG_STONE, ore, _t, 0)
	Art.pop(self)
	Art.push(self, Vector2(x, py), 0.0, Vector2(s, 1.0))
	Art.toon(self, _POOL_RIM, Color("b4ad92"), 2.6, 0.5)
	Art.flat(self, _POOL_WATER, ore.darkened(0.12))
	Art.flat(self, _POOL_LIGHT, ore)
	for k in 2:
		var f := fposmod(_t * 0.5 + k * 0.5, 1.0)
		Art.push(self, Vector2(sin(k * 3.0) * 6.0, -4), 0.0, Vector2(1.0, 0.25) * (0.25 + f * 0.9))
		Art.arc_c(self, Vector2.ZERO, 30.0, 0, TAU, 20, Color(ore2, snappedf(0.9 * (1.0 - f), 0.1)), 3.0)
		Art.pop(self)
	Art.push(self, Vector2(26, -4), sin(_t * 0.6) * 0.1)
	Art.toon(self, _LILY, Color("4ac85a"), 1.8, 0.3)
	Art.toon(self, Art.star_pts(Vector2(2, -4), 5, 2.2, 5), Color("ff8ac8"), 1.4, 0.0)
	Art.flat(self, Art.circle_pts(Vector2(2, -4), 1.6, 6), Color("ffe066"))
	Art.pop(self)
	Art.pop(self)
	for p: Vector3 in [Vector3(x - 52 * s, 0.4, 0), Vector3(x + 50 * s, 0.35, 1)]:
		OreArt.piece(self, "turquoise", Vector2(p.x, py), p.y, 0.0, st, _t, int(p.z))
	# Light from the water dancing on the wall.
	for k in 5:
		var cp := Vector2(x + (k - 2) * 26.0 * s + sin(_t * 1.3 + k) * 6.0, top + 100 + (k % 2) * 14.0 + sin(_t * 0.9 + k * 2.0) * 4.0)
		Art.dot(self, cp, 2.2 + sin(_t * 2.0 + k * 1.7), Color(ore2, 0.45))


## A great stone mask in the back wall; its jade eyes glow and blink.
func _wall_mask(st: Dictionary, at: Vector2, s: float) -> void:
	var ore2: Color = st["ore2"]
	var pulse := snappedf(0.6 + 0.4 * sin(_t * 1.6 + index), 0.05)
	Art.glow(self, at + Vector2(0, -60 * s * 0.45), 70.0 * s * 0.5 + 20.0, Color(ore2, 0.16 * pulse), 16)
	Art.push(self, at, 0.0, Vector2(s, s))
	Art.toon(self, _MASK_PLATE, Color("8a8a70"), 2.4, 0.4)
	OreArt.jungle_piece(self, "mask", Color("aaa88a"), ore2, _t, 0)
	if Chars.blinking(_t * 0.4, index):
		for e: PackedVector2Array in OreArt._MASK_EYES:
			Art.flat(self, e, Color("6a6a58"))
	else:
		for ex: float in [-7.0, 7.0]:
			Art.glow(self, Vector2(ex, -23), 8.0, Color(ore2, 0.6 * pulse), 10)
	Art.pop(self)


## A sitting stone jaguar seen from the front, on a carved plinth: golden
## eyes glowing, a gold collar, its tail tip swaying.
func _jaguar(at: Vector2, face: float, ore: Color, ore2: Color, k: int, s: float) -> void:
	var stone := Color("cdb88a")
	var dark := Art.shade_of(stone, 0.42)
	Art.push(self, at, 0.0, Vector2(face, 1.0) * s)
	Art.t_rect(self, Rect2(-28, -12, 56, 12), 3, stone.darkened(0.16), 2.4, 0.4)
	_carve(self, _FRET, Vector2(-8, -9), 0.5, stone.darkened(0.16))
	Art.push(self, Vector2(16, -16), sin(_t * 1.2 + k * 2.0) * 0.12)
	Art.line_c(self, _JAG_TAIL, Art.INK, 7.6)
	Art.line_c(self, _JAG_TAIL, stone, 4.0)
	Art.pop(self)
	Art.toon(self, _JAG_BODY, stone, 2.6, 0.6)
	for p: Vector2 in _JAG_SPOTS:
		Art.flat(self, Art.circle_pts(p, 2.6, 8), dark)
		Art.arc_c(self, p, 4.2, 0.0, TAU, 10, Color(dark, 0.7), 1.2)
	for x: float in [-7.5, 7.5]:
		Art.t_rect(self, Rect2(x - 4.5, -34, 9, 22), 4, stone.lightened(0.06), 2.0, 0.3)
		Art.t_ellipse(self, Vector2(x, -13), Vector2(5.5, 3), stone.lightened(0.1), 1.8, 0.0)
	for e: PackedVector2Array in _JAG_EARS:
		Art.toon(self, e, stone, 2.2, 0.3)
	Art.toon(self, _JAG_HEAD, stone, 2.6, 0.5)
	Art.flat(self, _JAG_MUZZLE, stone.lightened(0.14))
	Art.flat(self, _JAG_NOSE, Color("6a4a3a"))
	Art.line_c(self, _JAG_MOUTH, dark, 1.4)
	for p: Vector2 in [Vector2(-12, -62), Vector2(12, -62), Vector2(0, -72)]:
		Art.flat(self, Art.circle_pts(p, 1.8, 6), dark)
	# Gold collar with a jade stone.
	Art.line_c(self, _JAG_COLLAR, Art.INK, 6.0)
	Art.line_c(self, _JAG_COLLAR, JG_GOLD, 3.4)
	Art.t_circle(self, Vector2(0, -44), 3.2, JG_JADE, 1.4, 0.0)
	var pulse := snappedf(0.6 + 0.4 * sin(_t * 2.0 + k * 1.3), 0.05)
	for x: float in [-6.0, 6.0]:
		Art.glow(self, Vector2(x, -64), 9.0, Color(ore2, 0.6 * pulse), 10)
		Art.toon(self, Art.ellipse_pts(Vector2(x, -64), Vector2(3.6, 2.6), 10), ore2, 1.4, 0.0)
		Art.flat(self, Art.ellipse_pts(Vector2(x, -64), Vector2(0.9, 2.2), 6), Art.INK)
	Art.pop(self)


## The idol's altar in a shaft of light from the ceiling.
func _idol_altar(st: Dictionary, at: Vector2, top: float, fit: float) -> void:
	var stone := Color("c4ad7e")
	var s := 0.85 + 0.35 * fit
	var pulse := snappedf(0.8 + 0.2 * sin(_t * 1.2 + index), 0.05)
	Art.flat(self, PackedVector2Array([Vector2(at.x - 14, top - 6), Vector2(at.x + 14, top - 6), Vector2(at.x + 50 * s, at.y), Vector2(at.x - 50 * s, at.y)]), Color(1.0, 0.96, 0.75, 0.2 * pulse))
	Art.flat(self, PackedVector2Array([Vector2(at.x - 6, top - 6), Vector2(at.x + 6, top - 6), Vector2(at.x + 24 * s, at.y), Vector2(at.x - 24 * s, at.y)]), Color(1.0, 0.98, 0.85, 0.16 * pulse))
	Art.flat(self, Art.ellipse_pts(Vector2(at.x, top - 4), Vector2(14, 4), 12), Color(1.0, 1.0, 0.85, 0.85))
	Art.push(self, at, 0.0, Vector2(s, s))
	Art.t_rect(self, Rect2(-46, -14, 92, 14), 3, stone.darkened(0.1), 2.6, 0.4)
	Art.t_rect(self, Rect2(-32, -28, 64, 14), 3, stone, 2.6, 0.4)
	Art.t_rect(self, Rect2(-20, -40, 40, 12), 3, stone.lightened(0.06), 2.4, 0.4)
	for x: float in [-38.0, 26.0]:
		_carve(self, _FRET, Vector2(x, -9), 0.5, stone.darkened(0.1))
	for x: float in [-26.0, 20.0]:
		Art.t_circle(self, Vector2(x + 3, -21), 3.4, JG_JADE, 1.4, 0.0)
	var bob := snappedf(sin(_t * 1.5) * 2.0, 0.5)
	Art.glow(self, Vector2(0, -64 + bob), 34.0, Color(1.0, 0.85, 0.4, 0.35 * pulse), 14)
	OreArt.piece(self, "idol", Vector2(0, -40 + bob), 1.3, 0.0, st, _t, 0)
	Art.pop(self)
	# Dust glittering in the light.
	for k in 4:
		var f := fposmod(_t * 0.07 + k * 0.25, 1.0)
		var p := Vector2(at.x + sin(_t * 0.8 + k * 1.9) * (10.0 + 26.0 * f), lerpf(top + 6.0, at.y - 10.0, f))
		Art.dot(self, p, 1.5, Color(1, 1, 0.85, 0.85 * sin(f * PI)))


## The great sun disc in the back wall: its rays turn, its face smiles.
func _sun_wall(st: Dictionary, c: Vector2, fit: float) -> void:
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var s := 0.55 + 0.45 * fit
	var pulse := snappedf(0.75 + 0.25 * sin(_t * 1.3), 0.05)
	Art.glow(self, c, 96.0 * s, Color(ore, 0.3 * pulse), 20)
	OreArt.heart_rays(self, c, 120.0 * s, ore2, _t * 0.6, 10)
	Art.push(self, c, _t * 0.12, Vector2(s, s))
	Art.toon(self, _SUN_BIG_RAYS, ore.darkened(0.08), 2.6, 0.3)
	Art.pop(self)
	Art.push(self, c, 0.0, Vector2(s, s))
	Art.t_circle(self, Vector2.ZERO, 42, ore, 2.8, 0.5)
	Art.arc_c(self, Vector2.ZERO, 36.0, 0, TAU, 32, Art.shade_of(ore, 0.3), 2.2)
	for k in 12:
		Art.flat(self, _SUN_DOTS[k], Art.shade_of(ore, 0.25))
	Art.t_circle(self, Vector2.ZERO, 27, ore2, 2.2, 0.3)
	var happy := Chars.blinking(_t * 0.3, index)
	for sx: float in [-1.0, 1.0]:
		if happy:
			Art.arc_c(self, Vector2(sx * 9, -4), 4.0, PI + 0.3, TAU - 0.3, 6, Art.INK, 2.4)
		else:
			Art.arc_c(self, Vector2(sx * 9, -5), 4.0, 0.3, PI - 0.3, 6, Art.INK, 2.4)
		Art.flat(self, Art.circle_pts(Vector2(sx * 15, 5), 3.4, 8), Color(1.0, 0.5, 0.4, 0.45))
	Art.arc_c(self, Vector2(0, 4), 8.0, 0.35, PI - 0.35, 10, Art.INK, 2.6)
	Art.flat(self, Art.ellipse_pts(Vector2(-22, -24), Vector2(4, 8), 10, 0.7), Color(1, 1, 1, 0.5))
	Art.pop(self)


## The feathered serpent winding along the back wall; jade glyphs glow.
func _serpent_wall(st: Dictionary, cave: Rect2, x0: float, x1: float, top: float, fit: float) -> void:
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var a := x0 - 70.0
	var b := x1 + 20.0
	var body := _serpent_body(a, b, top)
	var spine: PackedVector2Array = body[1]
	var pulse := snappedf(0.6 + 0.4 * sin(_t * 1.4 + index), 0.05)
	Art.glow(self, Vector2((a + b) / 2.0, top + 96), (b - a) * 0.55, Color(ore, 0.14 * pulse), 18)
	Art.toon(self, body[0], ore, 2.6, 0.6)
	Art.toon(self, body[2], ore2.lerp(ore, 0.5), 0.0, 0.0)
	for k in range(1, spine.size() - 1, 2):
		Art.arc_c(self, spine[k], 5.0, 0.4, PI - 0.4, 5, Art.shade_of(ore, 0.35), 1.6)
	# Feathers along its back, in red, gold and turquoise.
	var cols: Array[Color] = [Color("ff5a5a"), JG_GOLD, Color("3fd6c8")]
	for k in range(2, spine.size() - 2, 3):
		var d := (spine[k + 1] - spine[k - 1]).normalized()
		Art.push(self, spine[k] - d.orthogonal() * 7.0, d.angle() - PI / 2.0 + sin(_t * 1.6 + k) * 0.12)
		Art.toon(self, _FEATHER_J, cols[(k / 3) % 3], 1.6, 0.3)
		Art.pop(self)
	# Head at the far end, crest of feathers waving.
	var hp := spine[spine.size() - 1]
	var hs := 1.6 + 0.6 * fit
	Art.push(self, hp, 0.0, Vector2(hs, hs))
	for k in 4:
		Art.push(self, Vector2(-2, -7), -1.3 + k * 0.42 + sin(_t * 2.0 + k) * 0.1)
		Art.toon(self, _FEATHER_J, cols[k % 3], 1.6, 0.3)
		Art.pop(self)
	Art.toon(self, _SERP_HEAD_BIG, ore, 2.2, 0.5)
	Art.flat(self, _SERP_JAW, ore2.lerp(ore, 0.3))
	Art.glow(self, Vector2(6, -6), 7.0, Color(Color("ffe066"), 0.6 * pulse), 8)
	Art.flat(self, Art.circle_pts(Vector2(6, -6), 2.2, 8), Color("ffe066"))
	Art.flat(self, Art.ellipse_pts(Vector2(6.4, -6), Vector2(0.8, 1.8), 6), Art.INK)
	if fposmod(_t * 0.5 + index, 2.0) < 0.3:
		Art.line_c(self, PackedVector2Array([Vector2(20, 1), Vector2(26, 2), Vector2(29, 0)]), Color("ff5a7a"), 1.4)
		Art.line_c(self, PackedVector2Array([Vector2(26, 2), Vector2(29, 4)]), Color("ff5a7a"), 1.4)
	Art.pop(self)
	# Jade glyphs pulsing on the wall.
	for k in 3:
		var gp := Vector2(lerpf(a + 30, b - 30, (k + 0.5) / 3.0), top + 34 + (k % 2) * 8)
		var pk := snappedf(0.5 + 0.5 * sin(_t * 1.8 + k * 2.1), 0.1)
		Art.glow(self, gp, 16.0, Color(ore2, 0.4 * pk), 10)
		Art.push(self, gp, 0.0, Vector2(0.7, 0.7))
		Art.line_c(self, _GLYPHS[k % _GLYPHS.size()], Color(ore2, 0.4 + 0.6 * pk), 2.2)
		Art.pop(self)


static var _bodies := {}


## The serpent's body along the wall between a and b: [outline, spine, belly].
func _serpent_body(a: float, b: float, top: float) -> Array:
	var k := hash([a, b, top])
	if _bodies.has(k):
		return _bodies[k]
	var spine := PackedVector2Array()
	var n := maxi(8, int((b - a) / 18.0))
	for i in n + 1:
		var u := float(i) / n
		spine.append(Vector2(lerpf(a, b, u), top + 118.0 - u * 50.0 + sin(u * TAU * 1.4) * 22.0 * (1.0 - u * 0.4)))
	var body := Geometry2D.offset_polyline(spine, 9.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]
	var belly := Geometry2D.offset_polyline(Art.moved(spine, Vector2(0, 4)), 3.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]
	var out := [body, spine, Art.clipped(belly, body)]
	_bodies[k] = out
	return out


## The Heart of the Temple: a stepped altar with gold trim, the ruby heart
## floating over it, glyph stones circling, gold pillars with jade eyes.
func _heart_altar(st: Dictionary, at: Vector2, top: float, x0: float, x1: float, fit: float) -> void:
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var s := 0.7 + 0.3 * fit
	var stone := Color("8a7a6a")
	var c := Vector2(at.x, top + 88)
	var beat := maxf(0.0, sin(_t * 3.2)) * 0.06
	Art.glow(self, c, 110.0 * s + 10.0, Color(ore, 0.22 + beat * 2.0), 20)
	OreArt.heart_rays(self, c, 150.0 * s, ore2, _t, 10)
	for x: float in [at.x - 112.0 * fit - 16.0, at.x + 112.0 * fit + 16.0]:
		Art.t_rect(self, Rect2(x - 9, top + 10, 18, LEDGE_Y - top - 8), 3, JG_GOLD, 2.4, 0.5)
		Art.t_rect(self, Rect2(x - 13, top + 4, 26, 10), 3, Color("e0a52c"), 2.2, 0.3)
		Art.t_rect(self, Rect2(x - 13, LEDGE_Y - 8, 26, 10), 3, Color("e0a52c"), 2.2, 0.3)
		var pk := snappedf(0.6 + 0.4 * sin(_t * 2.0 + x), 0.05)
		for gy: float in [top + 50, top + 110]:
			Art.glow(self, Vector2(x, gy), 12.0, Color(JG_JADE, 0.5 * pk), 10)
			Art.t_circle(self, Vector2(x, gy), 4.2, Color("5affb8"), 1.6, 0.0)
	# Glyph stones circling the heart (the back half behind it).
	var orbit := Vector2(56.0 * s + 8.0, 16.0)
	var stones := []
	for k in 6:
		var a := _t * 0.5 + TAU * k / 6.0
		stones.append([sin(a), c + Vector2(cos(a) * orbit.x, sin(a) * orbit.y), k])
	for e: Array in stones:
		if e[0] < 0.0:
			_glyph_stone(e[1], e[2], 0.75, ore2)
	Art.push(self, at, 0.0, Vector2(s, s))
	Art.t_rect(self, Rect2(-62, -14, 124, 14), 3, stone.darkened(0.1), 2.6, 0.4)
	Art.t_rect(self, Rect2(-46, -28, 92, 14), 3, stone, 2.6, 0.4)
	Art.t_rect(self, Rect2(-30, -42, 60, 14), 3, stone.lightened(0.06), 2.6, 0.4)
	for r: Rect2 in [Rect2(-62, -14, 124, 3), Rect2(-46, -28, 92, 3), Rect2(-30, -42, 60, 3)]:
		Art.t_rect(self, r, 1, JG_GOLD, 0.0, 0.0)
	for x: float in [-38.0, -13.0, 12.0, 37.0]:
		Art.t_circle(self, Vector2(x, -7), 3.0, JG_JADE, 1.2, 0.0)
	Art.pop(self)
	Art.push(self, c + Vector2(0, 16), 0.0, Vector2.ONE * (1.5 * s + 0.4) * (1.0 + beat))
	OreArt.piece(self, "temple_heart", Vector2.ZERO, 1.0, 0.0, st, _t, 0)
	Art.pop(self)
	for e: Array in stones:
		if e[0] >= 0.0:
			_glyph_stone(e[1], e[2], 1.0, ore2)
	for k in 6:
		var g := fposmod(_t * 0.12 + k / 6.0, 1.0)
		var sp := Vector2(lerpf(x0 - 20, x1 + 30, fposmod(k * 0.41, 1.0)) + sin(_t + k) * 8.0, lerpf(at.y - 10, top + 10, g))
		Art.push(self, sp, _t + k, Vector2.ONE * (0.4 + 0.6 * sin(g * PI)))
		Art.toon(self, Art.star_pts(Vector2.ZERO, 6, 1.5, 4), Color("fff0c0") if k % 2 else Color(ore2), 0.0, 0.0)
		Art.pop(self)


func _glyph_stone(p: Vector2, k: int, light: float, glow: Color) -> void:
	Art.push(self, p, sin(_t * 0.7 + k) * 0.2)
	Art.t_rect(self, Rect2(-7, -8, 14, 16), 3, Color("b8a37a").darkened(0.25 * (1.0 - light)), 2.0, 0.3)
	Art.push(self, Vector2.ZERO, 0.0, Vector2(0.38, 0.38))
	Art.line_c(self, _GLYPHS[k % _GLYPHS.size()], Color(glow, 0.5 + 0.5 * light), 3.0)
	Art.pop(self)
	Art.pop(self)


## A small flame on an urn or brazier.
func _small_flame(at: Vector2, c: Color) -> void:
	var flick := snappedf(0.85 + 0.15 * sin(_t * 8.0 + at.x), 0.05)
	Art.glow(self, at + Vector2(0, -8), 26.0, Color(1.0, 0.6, 0.25, 0.3 * flick), 12)
	Art.push(self, at, sin(_t * 6.0 + at.x) * 0.08, Vector2(1.1, flick * 1.1))
	Art.toon(self, _FLAME, Color("ff8a2a"), 1.8, 0.0)
	Art.flat(self, _FLAME_IN, c)
	Art.pop(self)


static func _xf_pts(pts: PackedVector2Array, pos: Vector2, rot: float, s: float) -> PackedVector2Array:
	return Transform2D(rot, Vector2(s, s), 0.0, pos) * pts


## A vine hanging down from 0,0: [outline (stem + leaves), flower spot].
static func _make_vine(length: float, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spine := PackedVector2Array()
	var n := int(length / 9.0) + 2
	for k in n:
		var u := float(k) / (n - 1)
		spine.append(Vector2(sin(u * 3.6 + seed) * 5.0 * u, u * length))
	var parts := [Geometry2D.offset_polyline(spine, 1.8, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]]
	for k in range(1, n):
		var u := float(k) / (n - 1)
		var side := 1.0 if k % 2 == 0 else -1.0
		var a := rng.randf_range(0.35, 0.95)
		var rot := a if side > 0.0 else PI - a
		parts.append(_xf_pts(_LEAF_J, spine[k] + Vector2(-side * 1.0, -1.0), rot, rng.randf_range(0.75, 1.0) * lerpf(1.0, 0.8, u)))
	return [Art.union(parts), spine[n - 1] + Vector2(0, 2)]


static var _LEAF_J := Art.smooth_pts(PackedVector2Array([Vector2(-2, 0), Vector2(4, -4), Vector2(11, -5), Vector2(18, 0), Vector2(11, 4.5), Vector2(4, 4)]), 2)
static var _VINES: Array = [_make_vine(70.0, 3), _make_vine(52.0, 8), _make_vine(92.0, 5), _make_vine(62.0, 11)]
static var _MOSS_LOW := Art.smooth_pts(PackedVector2Array([Vector2(-22, 2), Vector2(-16, -6), Vector2(-6, -9), Vector2(4, -7), Vector2(14, -10), Vector2(22, -3), Vector2(22, 2)]), 2)
static var _TUFT_J := PackedVector2Array([Vector2(-10, 0), Vector2(-8, -10), Vector2(-4, -3), Vector2(-1, -14), Vector2(2, -3), Vector2(6, -11), Vector2(7, -2), Vector2(10, 0)])
static var _FERN := _make_fern(1.0)
static var _FERN_FRONT := _make_fern(0.7)
static var _FRET := PackedVector2Array([Vector2(0, 12), Vector2(0, 0), Vector2(16, 0), Vector2(16, 9), Vector2(6, 9), Vector2(6, 4), Vector2(11, 4)])
static var _GLYPHS: Array[PackedVector2Array] = [
		# Spiral.
		_spiral_glyph(),
		# Eye.
		PackedVector2Array([Vector2(-10, 0), Vector2(-5, -5), Vector2(5, -5), Vector2(10, 0), Vector2(5, 5), Vector2(-5, 5), Vector2(-10, 0), Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0)]),
		# Step pyramid.
		PackedVector2Array([Vector2(-11, 7), Vector2(-7, 7), Vector2(-7, 2), Vector2(-3, 2), Vector2(-3, -3), Vector2(3, -3), Vector2(3, 2), Vector2(7, 2), Vector2(7, 7), Vector2(11, 7)]),
		# Sun cross.
		PackedVector2Array([Vector2(0, -9), Vector2(0, 9), Vector2(0, 0), Vector2(-9, 0), Vector2(9, 0), Vector2(0, 0), Vector2(-6, -6), Vector2(6, 6)]),
		# Zigzag (water).
		PackedVector2Array([Vector2(-11, 3), Vector2(-7, -3), Vector2(-3, 3), Vector2(1, -3), Vector2(5, 3), Vector2(9, -3)])]
static var _SCONCE := PackedVector2Array([Vector2(-9, 8), Vector2(9, 8), Vector2(6, 16), Vector2(2, 22), Vector2(-2, 22), Vector2(-6, 16)])
static var _CLUMP := _make_clump(false)
static var _CLUMP_BACK := _make_clump(true)
static var _CLUMP_VEINS := PackedVector2Array([Vector2(-14, 16), Vector2(-4, 22), Vector2(8, 20), Vector2(16, 12)])
static var _FLOWER := Art.smooth_pts(Art.star_pts(Vector2(6, 10), 7, 3.2, 5), 2)
static var _GECKO := Art.smooth_pts(PackedVector2Array([Vector2(-11, 0), Vector2(-4, -4), Vector2(5, -3.5), Vector2(10, -4), Vector2(16, -1.5),
		Vector2(16, 1.5), Vector2(10, 4), Vector2(5, 3.5), Vector2(-4, 4)]), 2)
static var _GECKO_LEG := PackedVector2Array([Vector2(0, 0), Vector2(4, 1), Vector2(6, -1)])
static var _GECKO_TAIL := PackedVector2Array([Vector2(0, 0), Vector2(-8, 1), Vector2(-14, -2), Vector2(-17, -6), Vector2(-15, -9)])
static var _WING := Art.smooth_pts(PackedVector2Array([Vector2(0, -1), Vector2(6, -9), Vector2(12, -8), Vector2(11, -1), Vector2(8, 3), Vector2(10, 8), Vector2(5, 9), Vector2(0, 2)]), 2)
static var _WING_SPOT := Art.circle_pts(Vector2(8, -5), 1.8, 8)
static var _BIG_LEAF := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-10, 12), Vector2(-12, 30), Vector2(0, 44), Vector2(12, 30), Vector2(10, 12)]), 3)
static var _BIG_LEAF_VEIN := PackedVector2Array([Vector2(0, 2), Vector2(0, 40)])
static var _POOL_RIM := Art.ellipse_pts(Vector2(0, -3), Vector2(60, 11), 28)
static var _POOL_WATER := Art.ellipse_pts(Vector2(0, -4), Vector2(52, 7), 28)
static var _POOL_LIGHT := Art.ellipse_pts(Vector2(-6, -5), Vector2(36, 4), 24)
static var _LILY := PackedVector2Array([Vector2(0, 0), Vector2(9, -1), Vector2(8, 3), Vector2(2, 5), Vector2(-6, 4), Vector2(-9, 0), Vector2(-6, -4), Vector2(0, -5), Vector2(6, -4)])
static var _MASK_PLATE := Art.smooth_pts(PackedVector2Array([Vector2(-22, -42), Vector2(22, -42), Vector2(24, -18), Vector2(16, 4), Vector2(-16, 4), Vector2(-24, -18)]), 2)
static var _URN_FIRE := Art.smooth_pts(PackedVector2Array([Vector2(-8, 0), Vector2(-12, -8), Vector2(-14, -16), Vector2(14, -16), Vector2(12, -8), Vector2(8, 0)]), 2)
static var _JAG_BODY := Art.smooth_pts(PackedVector2Array([Vector2(-19, -12), Vector2(-21, -30), Vector2(-15, -46), Vector2(0, -50),
		Vector2(15, -46), Vector2(21, -30), Vector2(19, -12)]), 3)
static var _JAG_HEAD := Art.smooth_pts(PackedVector2Array([Vector2(-17, -60), Vector2(-14, -70), Vector2(-6, -75), Vector2(6, -75),
		Vector2(14, -70), Vector2(17, -60), Vector2(12, -50), Vector2(0, -47), Vector2(-12, -50)]), 3)
static var _JAG_MUZZLE := Art.ellipse_pts(Vector2(0, -54), Vector2(7.5, 5), 14)
static var _JAG_NOSE := PackedVector2Array([Vector2(-3, -58), Vector2(3, -58), Vector2(0, -55)])
static var _JAG_MOUTH := PackedVector2Array([Vector2(-4, -51), Vector2(0, -53.5), Vector2(4, -51)])
static var _JAG_COLLAR := PackedVector2Array([Vector2(-13, -48), Vector2(-6, -45), Vector2(0, -44), Vector2(6, -45), Vector2(13, -48)])
static var _JAG_SPOTS: Array[Vector2] = [Vector2(-12, -38), Vector2(13, -36), Vector2(-15, -24), Vector2(15, -22), Vector2(0, -40)]
static var _JAG_EARS: Array[PackedVector2Array] = [Art.smooth_pts(PackedVector2Array([Vector2(-16, -66), Vector2(-15, -78), Vector2(-7, -73)]), 2),
		Art.smooth_pts(PackedVector2Array([Vector2(16, -66), Vector2(15, -78), Vector2(7, -73)]), 2)]
static var _JAG_TAIL := PackedVector2Array([Vector2(0, 0), Vector2(10, -2), Vector2(16, -10), Vector2(15, -20), Vector2(10, -24)])
static var _SUN_BIG_RAYS := Art.star_pts(Vector2.ZERO, 62, 44, 16)
static var _SUN_DOTS: Array[PackedVector2Array] = _sun_dots()
static var _PETAL_J := Art.smooth_pts(PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)]), 2)
static var _FEATHER_J := Art.smooth_pts(PackedVector2Array([Vector2(-2.5, 0), Vector2(-4, -8), Vector2(0, -15), Vector2(4, -8), Vector2(2.5, 0)]), 2)
static var _SERP_HEAD_BIG := Art.smooth_pts(PackedVector2Array([Vector2(-8, -8), Vector2(0, -12), Vector2(12, -11), Vector2(22, -4),
		Vector2(22, 3), Vector2(10, 6), Vector2(-2, 6), Vector2(-8, 4)]), 2)
static var _SERP_JAW := Art.clipped(PackedVector2Array([Vector2(-10, 1), Vector2(24, 1), Vector2(24, 8), Vector2(-10, 8)]), _SERP_HEAD_BIG)


static func _spiral_glyph() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := k * 0.62
		pts.append(Vector2(cos(a), sin(a)) * (1.0 + k * 0.62))
	return pts


static func _sun_dots() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for k in 12:
		out.append(Art.circle_pts(Vector2.from_angle(TAU * k / 12.0) * 32.0, 2.4, 8))
	return out


## A fern: fronds fanning up from 0,0 (`s` < 1 = the smaller front set).
static func _make_fern(s: float) -> PackedVector2Array:
	var parts := []
	for k in 5:
		var a := -PI / 2.0 + (k - 2) * 0.42 * (1.0 if s >= 1.0 else 1.25)
		var frond := Art.smooth_pts(PackedVector2Array([Vector2(0, -2.5), Vector2(14, -5), Vector2(30, -3), Vector2(40, 0), Vector2(30, 3), Vector2(14, 5), Vector2(0, 2.5)]), 2)
		parts.append(_xf_pts(frond, Vector2.ZERO, a, s * (0.75 + 0.25 * (1.0 - absf(k - 2) / 2.0))))
	return Art.union(parts)


## A clump of leaves hanging over an edge from 0,0.
static func _make_clump(back: bool) -> PackedVector2Array:
	var parts := []
	var angs: Array = [2.6, 2.0, 1.55, 1.1, 0.55] if not back else [2.9, 2.3, 1.3, 0.3]
	for k in angs.size():
		parts.append(_xf_pts(_LEAF_J, Vector2(0, 0), angs[k], (1.25 if k % 2 == 0 else 1.05) * (1.15 if back else 1.0)))
	parts.append(Art.circle_pts(Vector2.ZERO, 5.0, 10))
	return Art.union(parts)


static var _branches := {}


## The cocoa branch from the wall at x `a` to its tip at `b` under the
## ceiling: [outline, spine].
func _cocoa_branch(a: float, b: float, top: float) -> Array:
	var k := hash([a, b, top])
	if _branches.has(k):
		return _branches[k]
	var spine := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		spine.append(Vector2(lerpf(a, b, u), top + 8.0 + u * 22.0 + sin(u * 5.0) * 5.0))
	# Thick at the wall, thin at the tip.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in spine.size():
		var d := (spine[mini(i + 1, 8)] - spine[maxi(i - 1, 0)]).normalized().orthogonal()
		var hw := lerpf(11.0, 3.0, i / 8.0)
		left.append(spine[i] + d * hw)
		right.append(spine[i] - d * hw)
	right.reverse()
	left.append_array(right)
	var out := [left, spine]
	_branches[k] = out
	return out
