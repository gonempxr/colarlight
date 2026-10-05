class_name ArtButton
extends Button
## A chunky theme button with a drawn picture on top and its name under it
## (the office actions: accountant, evolution, outfits, decor). The picture
## is an ArtView: painter.call(ci, size, t). An optional badge (a number or
## "!") sits on the top-right corner.

var painter: Callable
var art_h := 64.0
var _art: ArtView
var _badge: Label
var _fs := 19


static func make(label: String, variation: StringName, p: Callable, pic_h: float = 64.0) -> ArtButton:
	var b := ArtButton.new()
	b.text = label
	b.theme_type_variation = variation
	b.painter = p
	b.art_h = pic_h
	return b


func _ready() -> void:
	clip_text = true
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("outline_size", 6)
	_restyle()
	_art = ArtView.make(painter, Vector2(0, art_h), true)
	add_child(_art)
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_override("font", UiTheme.heavy_font())
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_constant_override("outline_size", 0)
	_badge.add_theme_color_override("font_color", Art.WHITE)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bsb := ToonBox.make(Art.RED, 15, 0)
	bsb.line_w = 3.0
	bsb.gloss = 0.2
	bsb.content_margin_left = 8
	bsb.content_margin_right = 8
	_badge.add_theme_stylebox_override("normal", bsb)
	_badge.visible = false
	add_child(_badge)
	resized.connect(_place)
	_place()


## The text sits under the picture: the button's top margin makes room.
func _restyle() -> void:
	var v := String(theme_type_variation) if theme_type_variation != &"" else "Button"
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := get_theme_stylebox(st, StringName(v))
		if box == null:
			continue
		box = Dock._copy_box(box)
		box.content_margin_top = art_h + 6.0
		box.content_margin_left = 4
		box.content_margin_right = 4
		add_theme_stylebox_override(st, box)


func set_variation(v: StringName) -> void:
	if v != theme_type_variation:
		theme_type_variation = v
		_restyle()


func set_badge(s: String, gold: bool = false) -> void:
	if _badge == null:
		return
	_badge.visible = s != ""
	_badge.text = s
	(_badge.get_theme_stylebox("normal") as ToonBox).fill = Art.GOLD if gold else Art.RED
	_badge.add_theme_color_override("font_color", Art.INK if gold else Art.WHITE)
	_badge.reset_size()
	_place()


## Shrinks the name until it fits the button's width.
func fit_text(most: int = 19) -> void:
	var font := get_theme_font("font")
	var fs := most
	while fs > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 12.0:
		fs -= 1
	if fs != _fs:
		_fs = fs
		add_theme_font_size_override("font_size", fs)


func _place() -> void:
	if _art == null:
		return
	_art.position = Vector2(4, 6)
	_art.size = Vector2(size.x - 8, art_h)
	if _badge.visible:
		_badge.position = Vector2(size.x - _badge.size.x + 6, -10)
	if size.x > 1.0:
		fit_text(19)
