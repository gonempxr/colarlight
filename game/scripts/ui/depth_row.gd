class_name DepthRow
extends Control
## One dive site: a cave cut into layered rock, the dive shaft on the
## left, an ore vein at the far end and the site's card on the right.
## Closed sites are boarded up; the next one shows an Open button.

const CAVE_TOP := 26.0
const CAVE_BOTTOM := 234.0
const LEDGE_Y := 200.0

var world: World
var index := 0

var card: StageCard
var _open_btn: Button
var _lock_label: Label
var _t := 0.0
var _flash := 0.0
var _bg: PaintLayer
var _bg_sig := []


func key() -> String:
	return "d%d" % index


func style() -> Dictionary:
	return Art.DEPTH_STYLE[index]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bg = PaintLayer.new(_draw_bg)
	add_child(_bg)
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
	_open_btn = Button.new()
	_open_btn.theme_type_variation = &"GoldButton"
	_open_btn.custom_minimum_size = Vector2(270, 74)
	_open_btn.pressed.connect(_on_open)
	add_child(_open_btn)
	GameState.cycle_finished.connect(_on_cycle_finished)
	refresh()


func _on_open() -> void:
	if Scroller.is_drag():
		return
	if GameState.open_depth(key()):
		Sfx.play("unlock")
		_flash = 1.0
	else:
		Sfx.play("deny")


func _on_cycle_finished(k: String, _amount: float) -> void:
	if k == key():
		_flash = maxf(_flash, 0.4)


func refresh() -> void:
	var open := GameState.is_open(key())
	card.visible = open
	var is_next := GameState.next_depth() == key()
	_open_btn.visible = not open and is_next
	_lock_label.visible = not open
	var name := tr("DEPTH_%s" % String(Balance.DEPTHS[index]["id"]).to_upper())
	if not open:
		_lock_label.text = name if is_next else "???"
		_open_btn.text = "%s  %s" % [tr("OPEN"), NumFormat.short(GameState.unlock_cost(key()))]
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
	if World.anim_tick() and world.is_visible_band(position.y, position.y + size.y):
		queue_redraw()
	# The still background repaints only when something it shows changes.
	var sig := [GameState.is_open(key()), GameState.next_depth() == key(), size, TranslationServer.get_locale()]
	if sig != _bg_sig:
		_bg_sig = sig
		_bg.queue_redraw()
	# Keep the lock label centered when the site opens or closes.
	if _lock_label.visible != (not GameState.is_open(key())):
		_notification(NOTIFICATION_RESIZED)


func _draw_bg(ci: CanvasItem) -> void:
	var st := style()
	var rock: Color = st["rock"]
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
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 97 + 5
	for i in 16:
		var p := Vector2(rng.randf_range(4, w - 4), rng.randf_range(10, h - 10))
		var r := rng.randf_range(4, 9)
		Art.t_ellipse(ci, p, Vector2(r * 1.3, r), rock.lightened(0.12), 2.0, 0.5, rng.randf_range(-0.5, 0.5))
	# The shaft the divers use.
	var shaft := Rect2(World.SHAFT_L, -2, World.SHAFT_R - World.SHAFT_L, h + 4)
	var water: Color = Art.water_color(0.15 + index * 0.85 / maxf(1.0, Art.DEPTH_STYLE.size() - 1.0))
	Art.grad(ci, PackedVector2Array([shaft.position, Vector2(shaft.end.x, shaft.position.y), shaft.end, Vector2(shaft.position.x, shaft.end.y)]), PackedColorArray([water, water, water.darkened(0.1), water.darkened(0.1)]))
	# Cave and the passage from the shaft.
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	var inner: Color = st["water"]
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
	# Mine frame.
	Art.push(ci, Vector2(World.CAVE_L + 22, LEDGE_Y + 2))
	Props.mine_frame(ci, 150, 76)
	Art.pop(ci)
	# Depth sign.
	Art.push(ci, Vector2(World.CAVE_L + 60, CAVE_TOP + 48), -0.04)
	Art.t_rect(ci, Rect2(-40, -17, 80, 34), 6, Art.CREAM, 3.0, 0.3)
	Art.text(ci, Vector2(0, 8), tr("DEPTH_METERS") % ((index + 1) * 50), 20, Art.INK, 0)
	Art.pop(ci)


func _cave_poly() -> PackedVector2Array:
	return Art.union([Art.rrect_pts(cave_rect(), 38, 6), Art.rrect_pts(Rect2(World.SHAFT_R - 6, 118, 40, CAVE_BOTTOM - 118), 12, 3)])


## The moving parts: lantern, decor, the glowing ore vein.
func _draw() -> void:
	if not GameState.is_open(key()):
		return
	var st := style()
	var cave := cave_rect()
	var cave_poly := _cave_poly()
	Art.push(self, Vector2(cave.get_center().x + 20, CAVE_TOP + 4))
	Props.lantern(self, _t + index, Color("ffd780"))
	Art.pop(self)
	_draw_decor(st, cave)
	# Ore vein, glowing on each delivery.
	var dp := deposit_pos()
	var glow := 0.12 + 0.05 * sin(_t * 2.0 + index) + _flash * 0.3
	Art.flat(self, Art.clipped(Art.circle_pts(Vector2(cave.end.x - 30, LEDGE_Y - 50), 90, 32), cave_poly), Color(st["ore"], glow))
	OreArt.deposit(self, Vector2(cave.end.x - 22, LEDGE_Y - 40), 46, index, index * 7 + 1, _t, 3, false)
	OreArt.deposit(self, Vector2(dp.x, LEDGE_Y + 2), 70, index, index * 31 + 3, _t, 5)
	# Edge of the cave drawn again over the vein so it stays inside.
	Art.ring(self, cave_poly, Art.INK, 5.0)


func _draw_decor(st: Dictionary, cave: Rect2) -> void:
	var y := LEDGE_Y
	var x0 := World.CAVE_L + 130.0
	var x1 := cave.end.x - 140.0
	var mid := (x0 + x1) / 2.0
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
		Art.lock(ci, Vector2(size.x / 2.0, 36), 20)
	Art.ring(ci, cave_poly, Art.INK, 5.0)
