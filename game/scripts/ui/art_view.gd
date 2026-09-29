class_name ArtView
extends Control
## A small canvas that draws toon art through a callable:
## painter.call(ci: CanvasItem, size: Vector2, t: float). Animated views
## redraw every frame (every other frame on low power); still ones once.

var painter: Callable
var animated := false
var _t := 0.0


static func make(p: Callable, min_size: Vector2, is_animated: bool = false) -> ArtView:
	var v := ArtView.new()
	v.painter = p
	v.custom_minimum_size = min_size
	v.animated = is_animated
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _process(delta: float) -> void:
	if not animated or not is_visible_in_tree():
		return
	_t += delta
	if not Art.low_power or Engine.get_process_frames() % 2 == 0:
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size, _t)
