class_name Modal
extends Control
## Dimmed full-screen overlay with a centered panel that pops in and out.
## Tap outside or the round X closes it. Content is rebuilt by `build` each
## time it opens so texts follow the language; tall content scrolls.

signal closed

const WIDTH := 560.0
const WIDE_WIDTH := 680.0

var _dim: ColorRect
var _panel: PanelContainer
var _col: VBoxContainer
## The title banner on top of the panel (the first title() of a dialog).
var _head: Control
var _head_label: Label
var _scroll: ScrollContainer
var _box: VBoxContainer
var _x: Button
var _builder: Callable
var _wide := false
var _tween: Tween
var _closing := false
var _head_color := UiTheme.BANNER_BLUE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.15, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.dialog_box())
	add_child(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_panel.add_child(_col)
	_head = Control.new()
	_head.custom_minimum_size = Vector2(0, 84)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(func(): UiTheme.draw_banner(_head, Rect2(Vector2.ZERO, _head.size), _head_color))
	_head.resized.connect(_head.queue_redraw)
	_col.add_child(_head)
	_head_label = Label.new()
	_head_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_head_label.offset_left = 18
	_head_label.offset_right = -18
	_head_label.offset_bottom = -6
	_head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_head_label.add_theme_font_override("font", UiTheme.heavy_font())
	_head_label.add_theme_font_size_override("font_size", 38)
	_head_label.add_theme_constant_override("outline_size", 10)
	_head.add_child(_head_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_x = Button.new()
	_x.theme_type_variation = &"RedButton"
	_x.icon = Icons.get_icon("close", 30)
	_x.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_x.custom_minimum_size = Vector2(68, 68)
	_x.pressed.connect(func(): Sfx.play("click"); close())
	add_child(_x)
	get_viewport().size_changed.connect(_layout)


## opts: "wide" (bool) for grids like the wardrobe.
func open(builder: Callable, opts: Dictionary = {}) -> void:
	_builder = builder
	_wide = opts.get("wide", false)
	_closing = false
	_panel.add_theme_stylebox_override("panel", UiTheme.dialog_box(Balance.saga))
	_dim.color = Color(0.1, 0.02, 0.2, 0.68) if Balance.saga else Color(0.05, 0.03, 0.15, 0.6)
	_scroll.scroll_vertical = 0
	rebuild()
	visible = true
	_relayout()
	_animate_in()


func rebuild() -> void:
	var keep := _scroll.scroll_vertical
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_head_label.text = ""
	_head_color = UiTheme.SAGA_BANNER if Balance.saga else UiTheme.BANNER_BLUE
	_builder.call(self)
	_head.visible = _head_label.text != ""
	_head.queue_redraw()
	_relayout()
	(func(): _scroll.scroll_vertical = keep).call_deferred()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var quick := 0.08 if Settings.reduce_motion else 0.16
	_panel.pivot_offset = _panel.size / 2.0
	_x.pivot_offset = _x.size / 2.0
	# The panel ducks away (a quick shrink with a hint of a dip first), the
	# X goes with it, the dim fades.
	_tween.tween_property(_panel, "scale", Vector2(0.88, 0.88), quick).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(_x, "scale", Vector2(0.6, 0.6), quick).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, quick).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0
		_x.scale = Vector2.ONE
		_closing = false
		closed.emit())


func is_open() -> bool:
	return visible and not _closing


func _animate_in() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	# Wait for the layout (wrapped text settles a frame late), so the panel
	# pops from its own centre and doesn't jump when it gets its real size.
	_panel.scale = Vector2(0.8, 0.8) if not Settings.reduce_motion else Vector2.ONE
	_x.scale = Vector2.ZERO if not Settings.reduce_motion else Vector2.ONE
	await get_tree().process_frame
	if _closing or not visible:
		return
	_layout()
	_x.pivot_offset = _x.size / 2.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The X pops in last, with a little spring.
	_tween.tween_property(_x, "scale", Vector2.ONE, 0.32).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Wrapped labels only know their real height once they have a width, so
## the box is measured again a frame later (else it keeps empty space).
func _relayout() -> void:
	_layout.call_deferred()
	await get_tree().process_frame
	_layout()


func _layout() -> void:
	if not is_inside_tree():
		return
	var v := get_viewport_rect().size
	var w := minf(WIDE_WIDTH if _wide else WIDTH, v.x - 32.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_box.custom_minimum_size.x = w - 40.0 - 12.0
	var natural := _box.get_combined_minimum_size().y
	var max_h := v.y - 150.0 - (98.0 if _head.visible else 0.0)
	_scroll.custom_minimum_size.y = minf(natural, max_h)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if natural > max_h else ScrollContainer.SCROLL_MODE_DISABLED
	_panel.reset_size()
	_panel.size = Vector2(w, _panel.get_combined_minimum_size().y)
	_panel.position = ((v - _panel.size) / 2.0).round()
	_panel.pivot_offset = _panel.size / 2.0
	_x.position = _panel.position + Vector2(_panel.size.x - _x.custom_minimum_size.x * 0.8, -_x.custom_minimum_size.y * 0.25)


# --- Helpers for builders -------------------------------------------------------

## The first title of a dialog goes on the banner; later ones (a name
## inside a card...) are big ink lines in the content.
func title(text: String) -> Label:
	if _head_label.text == "":
		_head_label.text = text
		_head.visible = true
		return _head_label
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", 40)
	_box.add_child(l)
	return l


func text(value: String, size_px: int = 24, color: Color = Art.INK) -> Label:
	size_px = maxi(size_px, Views.MIN_PX)
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


## The banner colour (UiTheme.BANNER_*): gold for rewards, purple for
## the pass and online things, blue otherwise.
func banner(color: Color) -> void:
	# The saga's dialogs keep their violet banner instead of the usual blue.
	_head_color = UiTheme.SAGA_BANNER if Balance.saga and color == UiTheme.BANNER_BLUE else color
	_head.queue_redraw()


## Any control (previews, rows of options).
func add(c: Control) -> Control:
	_box.add_child(c)
	return c


func row(separation: int = 10) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	_box.add_child(r)
	return r


func button(label: String, action: Callable, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = label
	b.theme_type_variation = variation
	b.custom_minimum_size.y = 76
	b.pressed.connect(action)
	_box.add_child(b)
	return b


## A button with a price and its currency icon: fmt is a translated string
## with %s where the price goes ("Dive for %s").
func price_button(fmt: String, amount: String, action: Callable, variation: StringName = &"", currency: String = "coin") -> PriceButton:
	var b := PriceButton.new()
	b.theme_type_variation = variation
	b.custom_minimum_size.y = 76
	b.pressed.connect(action)
	_box.add_child(b)
	b.set_price_fmt(fmt, amount, currency)
	return b
