class_name DepthRow
extends Control
## One dive site: rock ledge with an ore deposit, its card on the left.
## Closed sites show a lock and, for the next one, an Unlock button.

var world: World
var index := 0

var card: StageCard
var _open_btn: Button
var _lock_label: Label
var _t := 0.0
var _flash := 0.0


func key() -> String:
	return "d%d" % index


func style() -> Dictionary:
	return Art.DEPTH_STYLE[index]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	card = StageCard.new(key())
	card.world = world
	card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(card)

	_lock_label = Label.new()
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock_label.add_theme_font_size_override("font_size", 24)
	add_child(_lock_label)
	_open_btn = Button.new()
	_open_btn.theme_type_variation = &"GoldButton"
	_open_btn.custom_minimum_size = Vector2(260, 70)
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
		_flash = maxf(_flash, 0.35)


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
		card.position = Vector2(world.card_x(), 14)
		var cx := size.x / 2.0
		_lock_label.size = Vector2(size.x - 80, 40)
		_lock_label.position = Vector2(40, 70)
		_open_btn.size = _open_btn.custom_minimum_size
		_open_btn.position = Vector2(cx - _open_btn.size.x / 2.0, 124)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag() or not GameState.is_open(key()):
			return
		if event.position.x < world.scene_right():
			if GameState.tap(key()):
				Sfx.play("dive")
			world.divers.tap_ripple(event.position + position)


func deposit_pos() -> Vector2:
	return Vector2(world.scene_right() - 80.0, World.ROW_H * 0.66)


func ledge_y() -> float:
	return World.ROW_H * 0.72


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var st := style()
	var open := GameState.is_open(key())
	var rock: Color = st["rock"]
	var right := world.scene_right()
	var ly := ledge_y()
	# Rock shelf reaching out from the left wall, under the dive rope.
	var pts := PackedVector2Array([Vector2(0, ly - 16), Vector2(right - 10, ly - 4), Vector2(right + 20, ly + 26),
			Vector2(right - 30, World.ROW_H + 4), Vector2(0, World.ROW_H + 4)])
	draw_colored_polygon(pts, rock.darkened(0.25))
	var top := PackedVector2Array([Vector2(0, ly - 16), Vector2(right - 10, ly - 4), Vector2(right + 4, ly + 10), Vector2(0, ly)])
	draw_colored_polygon(top, rock.lightened(0.15))
	# Left wall.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(22, 0), Vector2(34, World.ROW_H), Vector2(0, World.ROW_H)]), rock.darkened(0.4))
	if not open:
		draw_rect(Rect2(0, 0, size.x, World.ROW_H), Color(0.01, 0.03, 0.1, 0.55))
		Art.lock(self, Vector2(size.x / 2.0, 40), 22, Color(1, 1, 1, 0.8))
		return
	for i in 3:
		Art.seaweed(self, Vector2(World.ROPE_X + 70 + i * 24, ly - 8), 44 + i * 12, Color("2fae7d").darkened(index * 0.08), _t, i + index)
	var coral: Color = st["ore2"]
	Art.blob(self, Vector2(World.ROPE_X + 190, ly - 12), 14, coral.darkened(0.2), index * 11)
	# Ore deposit, glowing on each delivery.
	var dp := deposit_pos()
	Art.crystals(self, Vector2(dp.x, ly - 2), 62, st, index * 31 + 3, 5)
	if _flash > 0.0:
		draw_circle(Vector2(dp.x, ly - 30), 64, Color(st["ore"], 0.25 * _flash))
	var font := UiTheme.body_font()
	draw_string(font, Vector2(World.ROPE_X + 14, 30), tr("DEPTH_METERS") % ((index + 1) * 50), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))
