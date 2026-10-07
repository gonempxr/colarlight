class_name DepthRow
extends Control
## One dive site: a cave cut into layered rock, the dive shaft on the
## left, an ore vein at the far end and the site's card on the right.
## Closed sites are boarded up; the next one shows an Open button.

const CAVE_TOP := 26.0
const CAVE_BOTTOM := 234.0
const LEDGE_Y := 200.0
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _lock_label:
		card.position = Vector2(world.card_x(), 16)
		var cx := (World.CAVE_L + world.scene_right()) / 2.0
		if not GameState.is_open(key()):
			cx = size.x / 2.0
		_lock_label.size = Vector2(size.x - 80, 40)
		_lock_label.position = Vector2(cx - _lock_label.size.x / 2.0, 64)
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
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), rock)
	for i in 3:
		var y := 40.0 + i * 78.0
		var band := PackedVector2Array()
		for k in 9:
			band.append(Vector2(lerpf(-10, w + 10, k / 8.0), y + sin(k * 1.9 + index * 2.0 + i) * 7.0))
		for k in 9:
			band.append(Vector2(lerpf(w + 10, -10, k / 8.0), y + 18.0 + sin((8 - k) * 1.7 + index + i) * 6.0))
		Art.flat(ci, band, Art.shade_of(rock, 0.1))
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 7), Vector2(0, 7)]), Art.shade_of(rock, 0.3))
	_wall_details(ci, w, h, rock)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 97 + 5
	for i in 16:
		var p := Vector2(rng.randf_range(4, w - 4), rng.randf_range(10, h - 10))
		var r := rng.randf_range(4, 9)
		Art.t_ellipse(ci, p, Vector2(r * 1.3, r), rock.lightened(0.12), 2.0, 0.5, rng.randf_range(-0.5, 0.5))
	# The shaft the divers use.
	var shaft := Rect2(World.SHAFT_L, -2, World.SHAFT_R - World.SHAFT_L, h + 4)
	var f := 0.15 + index * 0.85 / maxf(1.0, Art.DEPTH_STYLE.size() - 1.0)
	var water: Color = Art.calm(Art.water_color(f)) if WorldLook.is_water() else WorldLook.shaft_color(f)
	Art.grad(ci, PackedVector2Array([shaft.position, Vector2(shaft.end.x, shaft.position.y), shaft.end, Vector2(shaft.position.x, shaft.end.y)]), PackedColorArray([water, water, water.darkened(0.1), water.darkened(0.1)]))
	# Cave and the passage from the shaft.
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	var inner: Color = Art.calm(st["water"])
	Art.toon(ci, cave_poly, inner, 5.0, 0.0)
	# Soft darker back wall.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(cave.get_center() + Vector2(0, -20), Vector2(cave.size.x * 0.42, cave.size.y * 0.36), 30), cave_poly), inner.lightened(0.08))
	Art.flat(ci, PackedVector2Array([Vector2(World.SHAFT_L + 4, 120), Vector2(World.SHAFT_R + 2, 120), Vector2(World.SHAFT_R + 2, CAVE_BOTTOM - 2), Vector2(World.SHAFT_L + 4, CAVE_BOTTOM - 2)]), inner)
	# Shaft walls.
	for x: float in [World.SHAFT_L, World.SHAFT_R]:
		var y1 := 118.0 if x == World.SHAFT_R else h + 2.0
		Art.line(ci, Vector2(x, -2), Vector2(x, y1), Art.INK, 5.0)
		if x == World.SHAFT_R:
			Art.line(ci, Vector2(x, CAVE_BOTTOM), Vector2(x, h + 2), Art.INK, 5.0)
	# Wooden brace across the shaft.
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
	Art.flat(ci, Art.clipped(floor_pts, cave_poly), st["floor"])
	# Mine frame (metal supports on the moon).
	Art.push(ci, Vector2(World.CAVE_L + 22, LEDGE_Y + 2))
	if WorldLook.world == "moon":
		_metal_frame(ci, 150, 76)
	else:
		Props.mine_frame(ci, 150, 76)
	Art.pop(ci)
	_room_furniture(ci, cave)
	# Depth sign.
	Art.push(ci, Vector2(World.CAVE_L + 60, CAVE_TOP + 48), -0.04)
	Art.t_rect(ci, Rect2(-40, -17, 80, 34), 6, Art.CREAM, 3.0, 0.3)
	Art.text(ci, Vector2(0, 8), tr("DEPTH_METERS") % ((index + 1) * 50), 20, Art.INK, 0)
	Art.pop(ci)


## The cave plus the doorway to the shaft. The doorway's floor runs on
## level with the cave floor (past the cave's rounded corner, so there is no
## bump next to the lift crate) and its side towards the shaft is open.
func _cave_poly() -> PackedVector2Array:
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
		Art.ring(ci, poly, Art.INK, 5.0)
	else:
		Art.polyline(ci, pts, Art.INK, 5.0)


## The moving parts: lantern, decor, the glowing ore vein.
func _draw() -> void:
	if not GameState.is_open(key()):
		return
	var st := style()
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	_cp = cave_poly
	_draw_lamps(cave)
	_draw_decor(st, cave)
	# Ore vein, glowing on each delivery.
	var dp := deposit_pos()
	var glow := 0.12 + 0.05 * sin(_t * 2.0 + index) + _flash * 0.3
	Art.flat(self, Art.clipped(Art.circle_pts(Vector2(cave.end.x - 30, LEDGE_Y - 50), 90, 32), cave_poly), Color(st["ore"], glow))
	OreArt.deposit(self, Vector2(cave.end.x - 22, LEDGE_Y - 40), 46, index, index * 7 + 1, _t, 3, false)
	OreArt.deposit(self, Vector2(dp.x, LEDGE_Y + 2), 70, index, index * 31 + 3, _t, 5)


## Edge of the cave, drawn again over the vein so the glow stays inside.
func _draw_edge(ci: CanvasItem) -> void:
	if GameState.is_open(key()):
		_cave_edge(ci, _cave_poly())


func _draw_decor(st: Dictionary, cave: Rect2) -> void:
	var y := LEDGE_Y
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
	if _draw_decor_world(st, cave):
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
	else:
		# Inside the cave, between its top edge and the "???" label.
		Art.lock(ci, Vector2(size.x / 2.0, CAVE_TOP + 22.0), 16)
	_cave_edge(ci, cave_poly)



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
			for k in 3:
				var x := rng.randf_range(20.0, w - 40.0)
				var y := 20.0 if k % 2 == 0 else h - 20.0
				var pts := PackedVector2Array([Vector2(x, y)])
				for j in 4:
					pts.append(pts[j] + Vector2(rng.randf_range(10, 26), rng.randf_range(-8, 8)))
				Art.line_c(ci, pts, Color("ff7a2a"), 3.0)
				Art.line_c(ci, pts, Color("ffd45a"), 1.2)
		"acid":
			for k in 5:
				var p := Vector2(rng.randf_range(10, w - 10), 6.0)
				Art.toon(ci, Art.moved(_MOSS_TOP, p), Color("6cc24a"), 2.0, 0.3)
		"moon":
			for k in 4:
				var p := Vector2(rng.randf_range(20, w - 20), rng.randf_range(16, h - 16))
				Art.t_ellipse(ci, p, Vector2(7, 4), Art.shade_of(rock, 0.25), 1.6, 0.0)
			for k in 2:
				var p := Vector2(rng.randf_range(20, w - 20), h - 12.0)
				Art.crystal(ci, p, 14, 4, rng.randf_range(-0.3, 0.3), Color("9fe0ff"), 1.6)


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
			var bob := snappedf(sin(_t * 1.6) * 2.0, 0.5)
			Art.glow(self, Vector2(0, -26 + bob), 40.0, Color(1.0, 0.6, 0.2, 0.35), 14)
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
				Art.push(self, Vector2(lerpf(x0 + 20, x1 - 10, k), y + 2 - snappedf(hopf * 10.0, 1.0)), 0.0, Vector2(sq, 2.0 - sq) * (0.9 + k * 0.2))
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
			Art.push(self, c, snappedf(_t * 0.2, 0.02))
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
