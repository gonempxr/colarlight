class_name PaintLayer
extends Control
## A drawing layer that repaints only when its owner asks (or on resize).
## Used for the parts of a scene that don't move, so they cost nothing
## per frame. `painter` is called with this layer as the canvas item.

var painter: Callable


func _init(p: Callable, behind: bool = true) -> void:
	painter = p
	show_behind_parent = behind
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	painter.call(self)
