class_name Hud
extends Control
## Top bar: the player's avatar (opens the look editor), coins and income
## in a pill with the rush meter, Dive Deeper (prestige) and settings.
## Phone: one bar across the top with the pill in the middle.
## PC ("notch"): only the coin pill stays, hanging from the top edge in the
## middle like a MacBook notch; the bar with the buttons hides above the
## screen and slides down when the mouse comes near the top (or the notch
## is clicked, for touch screens).

const NOTCH_REVEAL_Y := 90.0
const HIDE_DELAY := 0.9

signal prestige_pressed
signal settings_pressed
signal avatar_pressed

var _coins: Label
var _coin_icon: TextureRect
var _rate: Label
var _pearls: Label
var _pearl_icon: TextureRect
var _pearl_bump := 0.0
var _rush: ProgressBar
var _rush_label: Label
var _prestige: Button
var _avatar: Control
var _shown_coins := 0.0
var _t := 0.0
var _slow_left := 0.0
var _bump := 0.0
var _blink := false
var _bar: PanelContainer
var _row: HBoxContainer
var _pill: PanelContainer
var _pill_slot: Control
var _notch := false
var _reveal := 1.0
## PC: width of the ocean area on the left. The bar and the notch stay over
## it, so the side column (boat and plant tabs) is never covered.
var area_w := 0.0
var _reveal_hold := 0.0
var _intro_show := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = PanelContainer.new()
	var sb := ToonBox.make(Color("1f3f73"), 28, 6)
	sb.open_top = true
	sb.gloss = 0.0
	sb.shadow = 0.3
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8 + 6 + 4
	_bar.add_theme_stylebox_override("panel", sb)
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)
	_row = row

	_avatar = Control.new()
	_avatar.custom_minimum_size = Vector2(80, 80)
	_avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_avatar.tooltip_text = tr("AVATAR")
	_avatar.draw.connect(_draw_avatar)
	_avatar.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Sfx.play("click")
			avatar_pressed.emit())
	row.add_child(_avatar)

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.x = 240
	pill.draw.connect(_draw_notch_frame)
	pill.gui_input.connect(_on_pill_input)
	row.add_child(pill)
	_pill = pill
	_style_pill(false)
	# Takes the pill's place in the bar while the pill hangs as a notch.
	_pill_slot = Control.new()
	_pill_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pill_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_slot.visible = false
	row.add_child(_pill_slot)
	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", -4)
	pill.add_child(mid)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 6)
	mid.add_child(coin_row)
	var coin := TextureRect.new()
	coin.texture = Icons.get_icon("coin", 44)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin.custom_minimum_size = Vector2(44, 44)
	coin_row.add_child(coin)
	_coins = Label.new()
	_coins.add_theme_font_override("font", UiTheme.heavy_font())
	_coins.add_theme_font_size_override("font_size", 42)
	_coins.add_theme_color_override("font_color", Art.GOLD)
	_coins.add_theme_constant_override("outline_size", 9)
	coin_row.add_child(_coins)
	_coin_icon = coin
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 6)
	mid.add_child(sub)
	_rate = Label.new()
	_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate.add_theme_font_size_override("font_size", 19)
	_rate.add_theme_color_override("font_color", Color("9ff0c0"))
	_rate.add_theme_constant_override("outline_size", 5)
	sub.add_child(_rate)
	_pearl_icon = TextureRect.new()
	_pearl_icon.texture = Icons.get_icon("pearl", 26)
	_pearl_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_pearl_icon.custom_minimum_size = Vector2(26, 26)
	sub.add_child(_pearl_icon)
	_pearls = Label.new()
	_pearls.add_theme_font_override("font", UiTheme.heavy_font())
	_pearls.add_theme_font_size_override("font_size", 21)
	_pearls.add_theme_color_override("font_color", Color("f1e6ff"))
	_pearls.add_theme_constant_override("outline_size", 6)
	sub.add_child(_pearls)
	_rush = ProgressBar.new()
	_rush.show_percentage = false
	_rush.max_value = 1.0
	_rush.custom_minimum_size = Vector2(0, 12)
	_rush.add_theme_stylebox_override("fill", _rush_fill())
	mid.add_child(_rush)
	_rush_label = Label.new()
	_rush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rush_label.add_theme_font_override("font", UiTheme.heavy_font())
	_rush_label.add_theme_font_size_override("font_size", 19)
	_rush_label.add_theme_color_override("font_color", Color("ff9fd0"))
	_rush_label.visible = false
	mid.add_child(_rush_label)

	_prestige = Button.new()
	_prestige.theme_type_variation = &"PurpleButton"
	_prestige.custom_minimum_size = Vector2(80, 80)
	_prestige.icon = Icons.get_icon("helmet", 46)
	_prestige.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prestige.tooltip_text = tr("PRESTIGE")
	_prestige.pressed.connect(func(): Sfx.play("click"); prestige_pressed.emit())
	row.add_child(_prestige)

	var settings := Button.new()
	settings.theme_type_variation = &"BlueButton"
	settings.custom_minimum_size = Vector2(80, 80)
	settings.icon = Icons.get_icon("gear", 40)
	settings.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.pressed.connect(func(): Sfx.play("click"); settings_pressed.emit())
	row.add_child(settings)
	_shown_coins = GameState.coins
	GameState.coins_earned.connect(func(_a): _bump = 1.0)
	Progress.pearls_earned.connect(func(_a): _pearl_bump = 1.0)
	Settings.changed.connect(_avatar.queue_redraw)
	resized.connect(_place)
	_pill.resized.connect(func(): if _notch: _place())


## Screen points where flying rewards land.
func coin_target() -> Vector2:
	return _coin_icon.get_global_rect().get_center()


func pearl_target() -> Vector2:
	if _pearl_icon.visible:
		return _pearl_icon.get_global_rect().get_center()
	return _coin_icon.get_global_rect().get_center() + Vector2(0, 40)


func bump(kind: String) -> void:
	_slow_left = 0.0
	if kind == "pearl":
		_pearl_bump = 1.0
	else:
		_bump = 1.0


## PC layout: the pill becomes a notch at the top middle and the bar hides.
func set_notch(on: bool) -> void:
	if on == _notch:
		_place()
		return
	_notch = on
	_pill.get_parent().remove_child(_pill)
	if on:
		add_child(_pill)
		_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_intro_show = 3.0
	else:
		_row.add_child(_pill)
		_row.move_child(_pill, 1)
		_pill.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		_reveal = 1.0
	_pill_slot.visible = on
	_style_pill(on)
	_place()


func is_notch() -> bool:
	return _notch


## Lowest point of the sliding bar on PC (0 while hidden), so things in the
## top corners can move out of its way.
func bar_bottom() -> float:
	if not _notch or not _bar.visible:
		return 0.0
	return maxf(0.0, _bar.position.y + _bar.size.y)


## Height the HUD takes from the top of the screen (the notch on PC).
func used_height() -> float:
	return _pill.size.y if _notch else size.y


func _style_pill(notch: bool) -> void:
	var psb := ToonBox.make(Color("122850") if not notch else Color("14305e"), 22 if not notch else 30, 0)
	psb.gloss = 0.0
	psb.line_w = 3.0 if not notch else 4.0
	psb.shadow = 0.0 if not notch else 0.35
	psb.open_top = notch
	psb.content_margin_left = 10 if not notch else 34
	psb.content_margin_right = 14 if not notch else 38
	psb.content_margin_top = 2 if not notch else 6
	psb.content_margin_bottom = 4 if not notch else 12
	_pill.add_theme_stylebox_override("panel", psb)
	_pill.custom_minimum_size.x = 240 if not notch else 320
	_pill.mouse_filter = Control.MOUSE_FILTER_STOP if notch else Control.MOUSE_FILTER_IGNORE
	_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if notch else Control.CURSOR_ARROW
	_pill.queue_redraw()


func _place() -> void:
	var w := area_w if _notch and area_w > 0.0 else size.x
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(w, size.y)
	if _notch:
		_pill.reset_size()
		_pill.position = Vector2(roundf((w - _pill.size.x) / 2.0), 0.0)


## Thin gold frame inside the notch, following its rounded lower corners.
func _draw_notch_frame() -> void:
	if not _notch:
		return
	var s := _pill.size
	var r := Rect2(Vector2(9, -40), Vector2(s.x - 18, s.y + 40 - 9))
	Art.polyline(_pill, Art.rrect_pts(r, 22.0, 6), Color(1.0, 0.82, 0.35, 0.55), 2.0, true)


func _on_pill_input(e: InputEvent) -> void:
	# Touch screens have no hover: a tap on the notch shows the buttons.
	if _notch and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_reveal_hold = 4.0


static func _rush_fill() -> ToonBox:
	var b := ToonBox.make(Color("ff6fae"), 7, 0)
	b.line_w = 2.5
	b.gloss = 0.35
	b.set_content_margin_all(0)
	return b


func _draw_avatar() -> void:
	var s := _avatar.size
	Chars.portrait(_avatar, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, Settings.avatar, "happy", Chars.blinking(_t, 1.0), Color("ffd98a"))
	# Little pencil badge: this opens the look editor.
	Art.t_circle(_avatar, Vector2(s.x - 12, s.y - 12), 12, Art.CORAL, 3.0, 0.0)
	Art.push(_avatar, Vector2(s.x - 12, s.y - 12), -0.8)
	Art.flat(_avatar, Art.rrect_pts(Rect2(-7, -2.5, 12, 5), 1), Art.WHITE)
	Art.flat(_avatar, PackedVector2Array([Vector2(5, -2.5), Vector2(9, 0), Vector2(5, 2.5)]), Art.WHITE)
	Art.pop(_avatar)


func _process(delta: float) -> void:
	_t += delta
	if _notch:
		_update_reveal(delta)
	_bump = maxf(0.0, _bump - delta * 4.0)
	var blink := Chars.blinking(_t, 1.0)
	if blink != _blink:
		_blink = blink
		_avatar.queue_redraw()
	# Count up smoothly instead of jumping.
	var target := GameState.coins
	if absf(target - _shown_coins) < 1.0 or target < _shown_coins:
		_shown_coins = target
	else:
		_shown_coins = lerpf(_shown_coins, target, minf(1.0, delta * 10.0))
	_coins.text = NumFormat.short(_shown_coins)
	_set_pop(_coins, 1.0 + _bump * 0.08)
	_pearl_bump = maxf(0.0, _pearl_bump - delta * 4.0)
	_set_pop(_pearls, 1.0 + _pearl_bump * 0.25)
	# The rest changes slowly: ten times a second is plenty.
	_slow_left -= delta
	if _slow_left > 0.0:
		return
	_slow_left = 0.1
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(GameState.income_rate())
	var has_pearls := Progress.pearls_total > 0 or Progress.has_feature("shop")
	_pearl_icon.visible = has_pearls
	_pearls.visible = has_pearls
	_pearls.text = str(Progress.pearls)
	var rushing := GameState.is_rushing()
	var boosted := GameState.boost_left > 0.0
	_rush.visible = not rushing and not boosted and GameState.rush_meter > 0.0
	_rush.value = GameState.rush_meter
	_rush_label.visible = rushing or boosted
	if rushing:
		_rush_label.text = "%s %d" % [tr("RUSH"), ceili(GameState.rush_left)]
		_rush_label.add_theme_color_override("font_color", Color("ff9fd0"))
	elif boosted:
		_rush_label.text = "×2  %s" % NumFormat.duration(GameState.boost_left)
		_rush_label.add_theme_color_override("font_color", Art.GOLD)
	_prestige.tooltip_text = tr("PRESTIGE")
	_prestige.theme_type_variation = &"GoldButton" if GameState.can_prestige() else &"PurpleButton"


## Scales a label about its middle, touching it only when something changed
## (setting a transform every frame costs a canvas update).
static func _set_pop(l: Control, s: float) -> void:
	var pivot := l.size / 2.0
	if l.pivot_offset != pivot:
		l.pivot_offset = pivot
	var sc := Vector2.ONE * s
	if l.scale != sc:
		l.scale = sc


func _update_reveal(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var near := mouse.x < _bar.size.x and (mouse.y < NOTCH_REVEAL_Y or (_reveal > 0.5 and mouse.y < _bar.size.y + 6.0))
	var modal_open := false
	for c in get_parent().get_children():
		if c is Modal and c.visible:
			modal_open = true
	_intro_show = maxf(0.0, _intro_show - delta)
	_reveal_hold = maxf(0.0, _reveal_hold - delta)
	if near or _intro_show > 0.0:
		_reveal_hold = maxf(_reveal_hold, HIDE_DELAY)
	var want := 1.0 if _reveal_hold > 0.0 and not modal_open else 0.0
	if Settings.reduce_motion:
		_reveal = want
	else:
		_reveal = move_toward(_reveal, want, delta * (5.0 if want > _reveal else 3.0))
	var e := _reveal * _reveal * (3.0 - 2.0 * _reveal)
	_bar.position.y = -(_bar.size.y + 12.0) * (1.0 - e)
	_bar.visible = _reveal > 0.001
