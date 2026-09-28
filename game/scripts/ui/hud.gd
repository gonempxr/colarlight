class_name Hud
extends PanelContainer
## Top bar: Dive Deeper (prestige) on the left, coins and income in the
## middle, settings on the right. Under the coins: the rush meter.

signal prestige_pressed
signal settings_pressed

var _coins: Label
var _rate: Label
var _rush: ProgressBar
var _rush_label: Label
var _prestige: Button
var _coin_icon: Control
var _shown_coins := 0.0


func _ready() -> void:
	var sb := UiTheme.panel_box(Color("0b1f45e6"), 0)
	sb.corner_radius_bottom_left = 26
	sb.corner_radius_bottom_right = 26
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	_prestige = Button.new()
	_prestige.theme_type_variation = &"BlueButton"
	_prestige.custom_minimum_size = Vector2(150, 76)
	_prestige.add_theme_font_size_override("font_size", 20)
	_prestige.pressed.connect(func(): Sfx.play("click"); prestige_pressed.emit())
	row.add_child(_prestige)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 8)
	mid.add_child(coin_row)
	_coin_icon = Control.new()
	_coin_icon.custom_minimum_size = Vector2(40, 40)
	_coin_icon.draw.connect(func(): Art.coin(_coin_icon, Vector2(20, 20), 18))
	coin_row.add_child(_coin_icon)
	_coins = Label.new()
	_coins.add_theme_font_override("font", UiTheme.heavy_font())
	_coins.add_theme_font_size_override("font_size", 44)
	_coins.add_theme_color_override("font_color", Art.GOLD)
	coin_row.add_child(_coins)
	_rate = Label.new()
	_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate.add_theme_font_size_override("font_size", 20)
	_rate.add_theme_color_override("font_color", Color("bff6ff"))
	mid.add_child(_rate)
	_rush = ProgressBar.new()
	_rush.show_percentage = false
	_rush.max_value = 1.0
	_rush.custom_minimum_size = Vector2(0, 8)
	mid.add_child(_rush)
	_rush_label = Label.new()
	_rush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rush_label.add_theme_font_override("font", UiTheme.heavy_font())
	_rush_label.add_theme_font_size_override("font_size", 20)
	_rush_label.add_theme_color_override("font_color", Color("ff9fd0"))
	_rush_label.visible = false
	mid.add_child(_rush_label)

	var settings := Button.new()
	settings.theme_type_variation = &"DarkButton"
	settings.custom_minimum_size = Vector2(76, 76)
	settings.icon = _gear_icon()
	settings.pressed.connect(func(): Sfx.play("click"); settings_pressed.emit())
	row.add_child(settings)
	_shown_coins = GameState.coins


func _process(delta: float) -> void:
	# Count up smoothly instead of jumping.
	var target := GameState.coins
	if absf(target - _shown_coins) < 1.0 or target < _shown_coins:
		_shown_coins = target
	else:
		_shown_coins = lerpf(_shown_coins, target, minf(1.0, delta * 10.0))
	_coins.text = NumFormat.short(_shown_coins)
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(GameState.income_rate())
	var rushing := GameState.is_rushing()
	_rush.visible = not rushing and GameState.rush_meter > 0.0
	_rush.value = GameState.rush_meter
	_rush_label.visible = rushing
	if rushing:
		_rush_label.text = "%s %d" % [tr("RUSH"), ceili(GameState.rush_left)]
	_prestige.text = tr("PRESTIGE")
	_prestige.theme_type_variation = &"GoldButton" if GameState.can_prestige() else &"BlueButton"


static var _gear_tex: Texture2D


static func _gear_icon() -> Texture2D:
	if _gear_tex == null:
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		var c := Vector2(19.5, 19.5)
		for y in 40:
			for x in 40:
				var v := Vector2(x, y) - c
				var a := atan2(v.y, v.x)
				var tooth := 17.0 if fposmod(a * 8.0 / TAU, 1.0) < 0.5 else 13.5
				var d := v.length()
				if d <= tooth and d >= 6.0:
					img.set_pixel(x, y, Color.WHITE)
		_gear_tex = ImageTexture.create_from_image(img)
	return _gear_tex
