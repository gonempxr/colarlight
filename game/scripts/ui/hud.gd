class_name Hud
extends PanelContainer
## Top bar: the player's avatar (opens the look editor), coins and income
## in a pill with the rush meter, Dive Deeper (prestige) and settings.

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
var _bump := 0.0
var _blink := false


func _ready() -> void:
	var sb := ToonBox.make(Color("1f3f73"), 28, 6)
	sb.open_top = true
	sb.gloss = 0.0
	sb.shadow = 0.3
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8 + 6 + 4
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

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
	var psb := ToonBox.make(Color("122850"), 22, 0)
	psb.gloss = 0.0
	psb.line_w = 3.0
	psb.content_margin_left = 10
	psb.content_margin_right = 14
	psb.content_margin_top = 2
	psb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", psb)
	pill.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	pill.custom_minimum_size.x = 240
	row.add_child(pill)
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


## Screen points where flying rewards land.
func coin_target() -> Vector2:
	return _coin_icon.get_global_rect().get_center()


func pearl_target() -> Vector2:
	if _pearl_icon.visible:
		return _pearl_icon.get_global_rect().get_center()
	return _coin_icon.get_global_rect().get_center() + Vector2(0, 40)


func bump(kind: String) -> void:
	if kind == "pearl":
		_pearl_bump = 1.0
	else:
		_bump = 1.0


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
	_coins.pivot_offset = _coins.size / 2.0
	_coins.scale = Vector2.ONE * (1.0 + _bump * 0.08)
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(GameState.income_rate())
	_pearl_bump = maxf(0.0, _pearl_bump - delta * 4.0)
	var has_pearls := Progress.pearls_total > 0 or Progress.has_feature("shop")
	_pearl_icon.visible = has_pearls
	_pearls.visible = has_pearls
	_pearls.text = str(Progress.pearls)
	_pearls.pivot_offset = _pearls.size / 2.0
	_pearls.scale = Vector2.ONE * (1.0 + _pearl_bump * 0.25)
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
