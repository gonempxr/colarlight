class_name ArtView
extends Control
## A small canvas that draws toon art through a callable:
## painter.call(ci: CanvasItem, size: Vector2, t: float). Animated views
## redraw ANIM_HZ times a second (less on low power); still ones once.

const ANIM_HZ := 30.0
const LOW_HZ := 20.0

var painter: Callable
var animated := false
var _t := 0.0
var _wait := 0.0


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
	_wait -= delta
	if _wait <= 0.0:
		# Keep the phase (no drift), but never queue up a burst of redraws.
		_wait = maxf(_wait + 1.0 / (LOW_HZ if Art.low_power else ANIM_HZ), 0.0)
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size, _t)
