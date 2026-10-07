class_name ArtView
extends Control
## A small canvas that draws toon art through a callable:
## painter.call(ci: CanvasItem, size: Vector2, t: float). Animated views
## redraw ANIM_HZ times a second (less on low power); still ones once.
## They are small pictures on cards and panels: gentle bobbing and gears,
## so a lower rate than the world's looks the same. Views scrolled out of
## sight don't redraw at all.

const ANIM_HZ := 30.0
const LOW_HZ := 20.0

## Animated pictures that may redraw in one frame (see _claim).
const BUDGET := 4
const BUDGET_LOW := 3

static var _budget_frame := -1
static var _budget_used := 0

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
		if not get_global_rect().intersects(get_viewport_rect()):
			_wait = 0.1
			return
		# A dialog full of animated pictures shares a budget per frame;
		# the ones left over go on the next frame.
		if not _claim():
			return
		var hz := minf(Art.shape_hz, LOW_HZ if Art.low_power else ANIM_HZ)
		_wait = maxf(_wait + 1.0 / hz, 0.0)
		queue_redraw()


static func _claim() -> bool:
	var f := Engine.get_process_frames()
	if f != _budget_frame:
		_budget_frame = f
		_budget_used = 0
	if _budget_used >= (BUDGET_LOW if Art.low_power else BUDGET):
		return false
	_budget_used += 1
	return true


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size, _t)
