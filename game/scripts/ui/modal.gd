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
var _scroll: ScrollContainer
var _box: VBoxContainer
var _x: Button
var _builder: Callable
var _wide := false
var _tween: Tween
var _closing := false


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
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
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
	_builder.call(self)
	_relayout()
	(func(): _scroll.scroll_vertical = keep).call_deferred()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var quick := 0.08 if Settings.reduce_motion else 0.14
	_tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), quick)
	_tween.tween_property(self, "modulate:a", 0.0, quick)
	_tween.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0
		_closing = false
		closed.emit())


func is_open() -> bool:
	return visible and not _closing


func _animate_in() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	_panel.scale = Vector2(0.8, 0.8) if not Settings.reduce_motion else Vector2.ONE
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	var max_h := v.y - 150.0
	_scroll.custom_minimum_size.y = minf(natural, max_h)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if natural > max_h else ScrollContainer.SCROLL_MODE_DISABLED
	_panel.reset_size()
	_panel.size = Vector2(w, _panel.get_combined_minimum_size().y)
	_panel.position = ((v - _panel.size) / 2.0).round()
	_panel.pivot_offset = _panel.size / 2.0
	_x.position = _panel.position + Vector2(_panel.size.x - _x.custom_minimum_size.x * 0.75, -_x.custom_minimum_size.y * 0.3)


# --- Helpers for builders -------------------------------------------------------

func title(text: String) -> Label:
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
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


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
