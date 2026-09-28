class_name UiTheme
extends RefCounted
## Builds the game's Theme in code: Rubik (with a Chinese fallback),
## chunky outlined cartoon buttons and warm cream panels.
##
## Text on the ocean is white with a thick ink outline; text on cream
## panels is ink without an outline (theme variations InkLabel/SoftLabel).

const FONT_BOLD := "res://assets/fonts/Rubik-SemiBold.ttf"
const FONT_BLACK := "res://assets/fonts/Rubik-ExtraBold.ttf"
const FONT_CJK := "res://assets/fonts/NotoSansSC-Bold-subset.ttf"

const BUTTON_COLORS := {
	"Button": Color("5cd05f"),
	"BlueButton": Color("3aa6f0"),
	"GoldButton": Color("ffbf2e"),
	"RedButton": Color("ef5350"),
	"PurpleButton": Color("8a6cf0"),
	"DarkButton": Color("9aa3bd"),
	"CreamButton": Color("fff6e4"),
}

static var _body: Font
static var _heavy: Font


static func body_font() -> Font:
	if _body == null:
		_body = _load_font(FONT_BOLD)
	return _body


## Heavier face for numbers, titles and buttons.
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


static func panel_box(color: Color, radius: float = 24.0, depth: float = 6.0) -> ToonBox:
	var b := ToonBox.make(color, radius, depth)
	b.gloss = 0.0
	b.shadow = 0.25
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 16
	b.content_margin_bottom = 16 + depth
	return b


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 26
	t.set_color("font_color", "Label", Art.WHITE)
	t.set_color("font_outline_color", "Label", Art.INK)
	t.set_constant("outline_size", "Label", 7)
	for v in [["InkLabel", Art.INK], ["SoftLabel", Art.INK_SOFT]]:
		t.set_type_variation(v[0], "Label")
		t.set_color("font_color", v[0], v[1])
		t.set_constant("outline_size", v[0], 0)

	for type in BUTTON_COLORS:
		if type != "Button":
			t.set_type_variation(type, "Button")
		_style_button(t, type, BUTTON_COLORS[type])
	# Cream buttons carry ink text.
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "CreamButton", Art.INK)
	t.set_constant("outline_size", "CreamButton", 0)

	t.set_stylebox("panel", "PanelContainer", panel_box(Art.CREAM))
	t.set_type_variation("SheetPanel", "PanelContainer")
	var sheet := panel_box(Art.CREAM, 30, 0)
	sheet.open_bottom = true
	sheet.content_margin_top = 20
	sheet.content_margin_bottom = 24
	t.set_stylebox("panel", "SheetPanel", sheet)
	t.set_type_variation("ToastPanel", "PanelContainer")
	var toast := panel_box(Color("2b2350"), 22, 0)
	toast.line = Art.GOLD
	toast.content_margin_top = 12
	toast.content_margin_bottom = 12
	t.set_stylebox("panel", "ToastPanel", toast)
	t.set_type_variation("CardPanel", "PanelContainer")
	var card := panel_box(Art.CREAM, 20, 6)
	card.content_margin_left = 12
	card.content_margin_right = 12
	card.content_margin_top = 10
	card.content_margin_bottom = 12 + 6
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation("HudPanel", "PanelContainer")

	var bar_bg := ToonBox.make(Color("3b3563"), 7, 0)
	bar_bg.line_w = 2.5
	bar_bg.gloss = 0.0
	bar_bg.set_content_margin_all(0)
	var bar_fill := ToonBox.make(Art.GOLD, 7, 0)
	bar_fill.line_w = 2.5
	bar_fill.gloss = 0.35
	bar_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("outline_size", "ProgressBar", 0)
	t.set_color("font_color", "TooltipLabel", Art.INK)
	t.set_constant("outline_size", "TooltipLabel", 0)
	return t


static func _style_button(t: Theme, type: String, color: Color) -> void:
	t.set_stylebox("normal", type, ToonBox.make(color))
	t.set_stylebox("hover", type, ToonBox.make(color.lightened(0.08)))
	t.set_stylebox("pressed", type, ToonBox.make(color.darkened(0.06), 18.0, 6.0, true))
	var off := ToonBox.make(Color("b9bfd1"))
	off.gloss = 0.1
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, Art.WHITE)
	t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.85))
	t.set_color("font_outline_color", type, Art.INK)
	t.set_constant("outline_size", type, 7)
	t.set_font("font", type, heavy_font())
	t.set_font_size("font_size", type, 26)
	t.set_constant("h_separation", type, 8)
