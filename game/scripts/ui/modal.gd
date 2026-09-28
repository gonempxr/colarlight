class_name Modal
extends Control
## Dimmed full-screen overlay with a centered panel. Tap outside closes.
## Content is rebuilt by `build` each time it opens so texts follow the language.

var _panel: PanelContainer
var _box: VBoxContainer
var _builder: Callable


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_panel.add_child(_box)


func open(builder: Callable) -> void:
	_builder = builder
	rebuild()
	visible = true


func rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	_builder.call(self)


func close() -> void:
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel:
		_panel.custom_minimum_size.x = minf(560.0, size.x - 40.0)


# --- Helpers for builders -------------------------------------------------------

func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", 38)
	_box.add_child(l)
	return l


func text(value: String, size_px: int = 24, color: Color = Color(1, 1, 1, 0.9)) -> Label:
	var l := Label.new()
	l.text = value
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


func button(label: String, action: Callable, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = label
	b.theme_type_variation = variation
	b.custom_minimum_size.y = 76
	b.pressed.connect(action)
	_box.add_child(b)
	return b
