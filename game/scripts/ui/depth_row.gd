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
	var water: Color = Art.water_color(0.15 + index * 0.13)
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
	Art.crystals(self, Vector2(cave.end.x - 22, LEDGE_Y - 40), 46, st, index * 7 + 1, 3)
	Art.crystals(self, Vector2(dp.x, LEDGE_Y + 2), 70, st, index * 31 + 3, 5)
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
			for i in 3:
				Art.push(self, Vector2(lerpf(x0, x1, i / 2.0), y + 2), 0.0, Vector2.ONE * (1.0 + (i % 2) * 0.3))
				Props.coral(self, [Color("ff6f91"), Color("ffa84a"), Color("c86bff")][i], i + index, _t)
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
			for i in 3:
				var cx := lerpf(x0, x1, i / 2.0)
				Art.crystal(self, Vector2(cx, y + 2), 26 + (i % 2) * 14, 8, -0.2 + i * 0.2, Color("8f7bff"), 2.2)
			Art.push(self, Vector2(mid, CAVE_TOP + 90 + sin(_t) * 10.0))
			Props.jelly(self, _t, Color("ff9fe0"))
			Art.pop(self)


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
