class_name UiTheme
extends RefCounted
## Builds the game's Theme in code: fonts (Nunito + Chinese fallback),
## chunky "candy" buttons and panels.

const FONT_BOLD := "res://assets/fonts/Nunito-Bold.ttf"
const FONT_BLACK := "res://assets/fonts/Nunito-Black.ttf"
const FONT_CJK := "res://assets/fonts/NotoSansSC-Bold-subset.ttf"

static var _body: Font
static var _heavy: Font


static func body_font() -> Font:
	if _body == null:
		_body = _load_font(FONT_BOLD)
	return _body


## Heavier face for numbers and titles.
static func heavy_font() -> Font:
	if _heavy == null:
		_heavy = _load_font(FONT_BLACK)
	return _heavy


static func _load_font(path: String) -> Font:
	var f: FontFile = load(path)
	var cjk: FontFile = load(FONT_CJK)
	var fv := FontVariation.new()
	fv.base_font = f
	fv.fallbacks = [cjk]
	return fv


static func button_box(color: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.border_color = color.darkened(0.35)
	sb.border_width_bottom = 2 if pressed else 7
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10 + (5 if pressed else 0)
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


static func panel_box(color: Color, radius: int = 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 26
	t.set_color("font_color", "Label", Art.WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("outline_size", "Label", 4)

	_style_button(t, "Button", Art.GREEN)
	# Variations: blue (neutral), gold (money), red (danger), dark (off).
	for v in [["BlueButton", Color("2f8cff")], ["GoldButton", Color("ffb627")], ["RedButton", Art.RED], ["DarkButton", Color("2b4a78")]]:
		t.set_type_variation(v[0], "Button")
		_style_button(t, v[0], v[1])

	t.set_stylebox("panel", "PanelContainer", panel_box(Color("0d2a55f2")))
	t.set_type_variation("SheetPanel", "PanelContainer")
	var sheet := panel_box(Color("0e2f5ff7"), 28)
	sheet.corner_radius_bottom_left = 0
	sheet.corner_radius_bottom_right = 0
	t.set_stylebox("panel", "SheetPanel", sheet)
	t.set_type_variation("ToastPanel", "PanelContainer")
	t.set_stylebox("panel", "ToastPanel", panel_box(Color("0b1a33ee"), 20))
	t.set_type_variation("CardPanel", "PanelContainer")
	var card := panel_box(Color("0b2248d9"), 20)
	card.content_margin_left = 12
	card.content_margin_right = 12
	card.content_margin_top = 10
	card.content_margin_bottom = 10
	t.set_stylebox("panel", "CardPanel", card)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.35)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Art.GOLD
	bar_fill.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("outline_size", "ProgressBar", 0)
	return t


static func _style_button(t: Theme, type: String, color: Color) -> void:
	t.set_stylebox("normal", type, button_box(color))
	t.set_stylebox("hover", type, button_box(color.lightened(0.1)))
	t.set_stylebox("pressed", type, button_box(color.darkened(0.08), true))
	t.set_stylebox("disabled", type, button_box(Color("5a6b85")))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, Art.WHITE)
	t.set_color("font_hover_color", type, Art.WHITE)
	t.set_color("font_pressed_color", type, Art.WHITE)
	t.set_color("font_focus_color", type, Art.WHITE)
	t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.6))
	t.set_color("font_outline_color", type, Color(0, 0, 0, 0.3))
	t.set_constant("outline_size", type, 5)
	t.set_font("font", type, heavy_font())
	t.set_font_size("font_size", type, 26)
