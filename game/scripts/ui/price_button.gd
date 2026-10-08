class_name PriceButton
extends Button
## A button that shows what a price is paid in: [icon] [words] [coin] [amount]
## (or a pearl for pearl prices). The row shrinks to fit narrow buttons:
## first the text gets a little smaller, then the leading icon goes, then
## the text gets smaller still.
## `full_text` holds the plain words and amount ("Upgrade 1.2K").

## Plain text of the label, for tests and tooltips (Button.text stays empty).
var full_text := ""
var _box: HBoxContainer
var _lead: TextureRect
var _pre: Label
var _cur: TextureRect
var _amt: Label
## Words after the price (a few languages put the price mid-sentence).
var _post: Label
var _lead_name := ""
var _cur_name := "coin"
var _shown_fs := 0
var _was_disabled := false


func _init() -> void:
	_box = HBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 6)
	add_child(_box, false, Node.INTERNAL_MODE_FRONT)
	_lead = _icon_rect()
	_pre = _label()
	_cur = _icon_rect()
	_amt = _label()
	_post = _label()
	_post.visible = false
	for c: Control in [_lead, _pre, _cur, _amt, _post]:
		_box.add_child(c)
	# The coin sits snug against its number.
	_cur.custom_minimum_size.x = 0
	resized.connect(_fit)


func _icon_rect() -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A translated "Buy %s"-style string with the price in its %s place.
func set_price_fmt(fmt: String, amount: String, currency: String = "coin", lead: String = "") -> void:
	var at := fmt.find("%s")
	if at < 0:
		set_price(fmt, amount, currency, lead)
		return
	set_price(fmt.substr(0, at).strip_edges(), amount, currency, lead, fmt.substr(at + 2).strip_edges())


## words: text before the price ("" for none); amount: the formatted price;
## currency: "coin" or "pearl"; lead: an icon name before the words ("" for none).
func set_price(words: String, amount: String, currency: String = "coin", lead: String = "", after: String = "") -> void:
	if words == _pre.text and amount == _amt.text and after == _post.text and currency == _cur_name and lead == _lead_name and _shown_fs != 0:
		return
	full_text = ("%s  %s %s" % [words, amount, after]).strip_edges()
	_post.text = after
	_post.visible = after != ""
	text = ""
	icon = null
	_pre.text = words
	_pre.visible = words != ""
	_amt.text = amount
	_cur_name = currency
	_lead_name = lead
	_shown_fs = 0
	_restyle()
	_fit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_restyle()
		NOTIFICATION_DRAW:
			if disabled != _was_disabled:
				_was_disabled = disabled
				_restyle.call_deferred()
			_place()


## Same font and colours as the button's own text (cream buttons use ink).
func _restyle() -> void:
	if _pre == null:
		return
	var col := get_theme_color("font_disabled_color" if disabled else "font_color")
	var outline := get_theme_constant("outline_size")
	for l: Label in [_pre, _amt, _post]:
		l.add_theme_font_override("font", get_theme_font("font"))
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", get_theme_color("font_outline_color"))
		l.add_theme_constant_override("outline_size", outline)
	_shown_fs = 0
	_fit()


## The row inside the button's padding; it sinks with the face when pressed.
func _place() -> void:
	var mode := get_draw_mode()
	var st := "pressed" if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else ("disabled" if mode == DRAW_DISABLED else "normal")
	var sb := get_theme_stylebox(st)
	if sb == null:
		return
	var r := Rect2(Vector2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP)),
			size - Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)))
	if _box.position != r.position or _box.size != r.size:
		_box.position = r.position
		_box.size = r.size


## Width of the row at a font size, with or without the leading icon.
func _row_w(fs: int, with_lead: bool) -> float:
	var font := get_theme_font("font")
	var sep := maxf(3.0, roundf(fs * 0.22))
	var w := 0.0
	var parts := 0
	if with_lead and _lead_name != "":
		w += _icon_px(fs)
		parts += 1
	if _pre.text != "":
		w += font.get_string_size(_pre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		parts += 1
	w += _icon_px(fs) * 0.9 + font.get_string_size(_amt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	parts += 2
	if _post.text != "":
		w += font.get_string_size(_post.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		parts += 1
	return w + sep * (parts - 1) + 4.0


static func _icon_px(fs: int) -> int:
	return roundi(fs * 1.15)


func _fit() -> void:
	if _pre == null:
		return
	var want := get_theme_font_size("font_size")
	var sb := get_theme_stylebox("normal")
	var room := size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0)
	var fs := want
	var with_lead := _lead_name != ""
	if room > 1.0:
		if with_lead and _row_w(fs, true) > room:
			# A slightly smaller font keeps the icon (rows of cards then all
			# show it); only a much smaller one drops it.
			var least := maxi(12, floori(want * 0.8))
			var f2 := fs
			while f2 > least and _row_w(f2, true) > room:
				f2 -= 1
			if _row_w(f2, true) <= room:
				fs = f2
			else:
				with_lead = false
		while fs > 12 and _row_w(fs, with_lead) > room:
			fs -= 1
	_lead.visible = with_lead
	var key := fs * 2 + (1 if with_lead else 0)
	if key == _shown_fs:
		return
	_shown_fs = key
	for l: Label in [_pre, _amt, _post]:
		l.add_theme_font_size_override("font_size", fs)
	var px := _icon_px(fs)
	if _lead_name != "":
		_lead.texture = Icons.get_icon(_lead_name, px)
	_cur.texture = Icons.get_icon(_cur_name, roundi(px * 0.9))
	# A narrower gap between the coin and its number than between words.
	_box.add_theme_constant_override("separation", maxi(3, roundi(fs * 0.22)))
	_place()
