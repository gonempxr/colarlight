class_name UiTheme
extends RefCounted
## Builds the game's Theme in code: Nunito Black for titles, numbers and
## buttons, Rubik for body text (both with a Chinese fallback),
## chunky outlined cartoon buttons and warm cream panels.
##
## Text on the ocean is white with a thick ink outline; text on cream
## panels is ink without an outline (theme variations InkLabel/SoftLabel).

const FONT_BOLD := "res://assets/fonts/Rubik-SemiBold.ttf"
const FONT_BLACK := "res://assets/fonts/Nunito-Black.ttf"
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
		# "Slim..." twins with narrow side margins (three cards in a row).
		t.set_type_variation("Slim" + type, "Button")
		_style_button(t, "Slim" + type, BUTTON_COLORS[type], 7.0)
	# Cream buttons carry ink text.
	for type in ["CreamButton", "SlimCreamButton"]:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(c, type, Art.INK)
		t.set_constant("outline_size", type, 0)

	t.set_stylebox("panel", "PanelContainer", panel_box(Art.CREAM))
	t.set_type_variation("SheetPanel", "PanelContainer")
	var sheet := panel_box(Art.CREAM, 30, 0)
	sheet.open_bottom = true
	sheet.content_margin_top = 20
	sheet.content_margin_bottom = 24
	t.set_stylebox("panel", "SheetPanel", sheet)
	t.set_type_variation("ToastPanel", "PanelContainer")
	# Calm notification card: deep navy, thin gold frame, soft shadow.
	var toast := panel_box(Color(0.09, 0.1, 0.24, 0.94), 26, 0)
	toast.line = Color("ffcf5a")
	toast.line_w = 2.5
	toast.shadow = 0.35
	toast.content_margin_left = 30
	toast.content_margin_right = 30
	toast.content_margin_top = 14
	toast.content_margin_bottom = 16
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
	# Text fields (player names).
	var field := ToonBox.make(Color.WHITE, 16, 0)
	field.gloss = 0.0
	field.content_margin_left = 18
	field.content_margin_right = 18
	field.content_margin_top = 10
	field.content_margin_bottom = 10
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := ToonBox.make(Color("fffbe8"), 16, 0)
	field_focus.gloss = 0.0
	field_focus.line = Color("1c7fb8")
	field_focus.content_margin_left = 18
	field_focus.content_margin_right = 18
	field_focus.content_margin_top = 10
	field_focus.content_margin_bottom = 10
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", Art.INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(Art.INK_SOFT, 0.6))
	t.set_color("caret_color", "LineEdit", Color("1c7fb8"))
	t.set_color("selection_color", "LineEdit", Color("9fd8ff"))
	t.set_font("font", "LineEdit", heavy_font())
	t.set_font_size("font_size", "LineEdit", 34)
	t.set_constant("caret_width", "LineEdit", 3)
	# Sliders: a chunky track, gold fill and a big round knob (easy for small fingers).
	var track := ToonBox.make(Color("3b3563"), 10, 0)
	track.gloss = 0.0
	track.line_w = 3.0
	track.set_content_margin_all(8)
	var filled := ToonBox.make(Art.GOLD, 10, 0)
	filled.line_w = 3.0
	filled.gloss = 0.3
	filled.set_content_margin_all(8)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", Icons.get_icon("knob", 44))
	t.set_icon("grabber_highlight", "HSlider", Icons.get_icon("knob", 48))
	t.set_constant("center_grabber", "HSlider", 1)
	# Thin rounded scroll bars in dialogs.
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = Color(0, 0, 0, 0.08)
	sbar.set_corner_radius_all(6)
	sbar.content_margin_left = 6
	sbar.content_margin_right = 6
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(Art.INK, 0.35)
	grab.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", sbar)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", grab)
	t.set_color("font_color", "TooltipLabel", Art.INK)
	t.set_constant("outline_size", "TooltipLabel", 0)
	return t


static func _style_button(t: Theme, type: String, color: Color, side: float = -1.0) -> void:
	var boxes := {"normal": ToonBox.make(color), "hover": ToonBox.make(color.lightened(0.08)),
			"pressed": ToonBox.make(color.darkened(0.06), 18.0, 6.0, true), "disabled": ToonBox.make(Color("b9bfd1"))}
	boxes["disabled"].gloss = 0.1
	for k: String in boxes:
		var b: ToonBox = boxes[k]
		if side >= 0.0:
			b.content_margin_left = side
			b.content_margin_right = side
		t.set_stylebox(k, type, b)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, Art.WHITE)
	t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.85))
	t.set_color("font_outline_color", type, Art.INK)
	t.set_constant("outline_size", type, 7)
	t.set_font("font", type, heavy_font())
	t.set_font_size("font_size", type, 26)
	t.set_constant("h_separation", type, 8)
