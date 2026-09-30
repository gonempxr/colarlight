class_name Scroller
extends Control
## Vertical scroll view with finger drag, mouse wheel, inertia and a soft
## rubber-band stretch past the ends that springs back. The wheel and
## trackpads glide to their target instead of jumping, and a fling keeps
## the speed of the last moments of the drag, not of one jittery event.
## Listens in _input so a drag that starts on a button still scrolls; buttons
## ask `Scroller.is_drag()` and ignore the release that ends a drag.

const DRAG_THRESHOLD := 14.0
const FRICTION := 5.0
const WHEEL_STEP := 110.0
## How quickly the view glides to a wheel target (higher = snappier).
const WHEEL_EASE := 14.0
## A fling uses the finger's speed over this last stretch of the drag.
const FLING_WINDOW_MS := 90

const STRETCH := 0.35
const MAX_STRETCH := 140.0
const SPRING := 14.0

static var _dragged_recently := false
## Set while a dialog or the puzzle covers the ocean.
static var locked := false

var content: Control
var scroll := 0.0
## Content is drawn this many times larger (PC screens show a closer view).
var zoom := 1.0

var _pressing := false
var _press_y := 0.0
var _last_y := 0.0
var _dragging := false
var _velocity := 0.0
var _last_motion_ms := 0
var _wheel_target := 0.0
var _wheeling := false
var _samples: Array[Vector2] = []   # (msec, y) of recent drag moves


static func is_drag() -> bool:
	return _dragged_recently


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_content(node: Control) -> void:
	content = node
	add_child(node)
	_apply()


func max_scroll() -> float:
	if content == null:
		return 0.0
	return maxf(0.0, content.size.y * zoom - size.y)


func scroll_to(y: float) -> void:
	scroll = clampf(y, 0.0, max_scroll())
	_velocity = 0.0
	_wheeling = false
	_apply()


func _wheel_by(amount: float) -> void:
	if not _wheeling:
		_wheel_target = scroll
		_wheeling = true
	_velocity = 0.0
	_wheel_target = clampf(_wheel_target + amount, 0.0, max_scroll())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if locked:
		_pressing = false
		_dragging = false
		return
	if event is InputEventMouseButton:
		var inside := get_global_rect().has_point(event.position)
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if inside and event.pressed:
					var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					# Trackpads send many small steps (factor < 1); mice send whole notches.
					var f: float = event.factor if event.factor > 0.0 else 1.0
					_wheel_by(dir * WHEEL_STEP * minf(f, 4.0))
			MOUSE_BUTTON_LEFT:
				if event.pressed and inside:
					_pressing = true
					_dragging = false
					_dragged_recently = false
					_wheeling = false
					_press_y = event.position.y
					_last_y = event.position.y
					_velocity = 0.0
					_samples.clear()
				elif not event.pressed and _pressing:
					_pressing = false
					if _dragging:
						_velocity = _fling_speed()
						_dragged_recently = true
						# Buttons check the flag during this release; clear it next frame.
						_clear_drag_flag.call_deferred()
					_dragging = false
	elif event is InputEventPanGesture and get_global_rect().has_point(event.position):
		_wheel_by(event.delta.y * 30.0)
	elif event is InputEventMouseMotion and _pressing:
		var y: float = event.position.y
		if not _dragging and absf(y - _press_y) > DRAG_THRESHOLD:
			_dragging = true
			_last_y = y
		if _dragging:
			var dy := y - _last_y
			_last_y = y
			var now := Time.get_ticks_msec()
			_last_motion_ms = now
			_samples.append(Vector2(now, y))
			while _samples.size() > 12:
				_samples.pop_front()
			# Past an end the content follows the finger less and less.
			var over := _overshoot()
			var outward := over != 0.0 and signf(-dy) == signf(over)
			var k := STRETCH * (1.0 - absf(over) / MAX_STRETCH) if outward else 1.0
			if over == 0.0 and (scroll - dy < 0.0 or scroll - dy > max_scroll()):
				k = STRETCH
			scroll = clampf(scroll - dy * maxf(0.05, k), -MAX_STRETCH, max_scroll() + MAX_STRETCH)
			_apply()


## Finger speed (px/s, scroll direction) over the last FLING_WINDOW_MS.
func _fling_speed() -> float:
	var now := Time.get_ticks_msec()
	var first := -1
	for i in _samples.size():
		if now - _samples[i].x <= FLING_WINDOW_MS:
			first = i
			break
	if first < 0 or first >= _samples.size() - 1:
		return 0.0
	var a := _samples[first]
	var b := _samples[_samples.size() - 1]
	var dt := maxf(0.016, (b.x - a.x) / 1000.0)
	return clampf(-(b.y - a.y) / dt, -6000.0, 6000.0)


func _clear_drag_flag() -> void:
	_dragged_recently = false


## How far past the top (<0) or bottom (>0) the view is stretched.
func _overshoot() -> float:
	if scroll < 0.0:
		return scroll
	return maxf(0.0, scroll - max_scroll())


func _process(delta: float) -> void:
	if _pressing:
		return
	var over := _overshoot()
	if over != 0.0:
		# Spring back to the end.
		_velocity = 0.0
		scroll -= over * (1.0 - exp(-SPRING * delta))
		if absf(_overshoot()) < 0.5:
			scroll = clampf(scroll, 0.0, max_scroll())
		_apply()
		return
	if _wheeling:
		scroll = lerpf(scroll, _wheel_target, 1.0 - exp(-WHEEL_EASE * delta))
		if absf(scroll - _wheel_target) < 0.5:
			scroll = _wheel_target
			_wheeling = false
		_apply()
		return
	if absf(_velocity) < 5.0:
		_velocity = 0.0
		return
	scroll += _velocity * delta
	_velocity *= exp(-FRICTION * delta)
	if scroll < 0.0 or scroll > max_scroll():
		# Fling into the end: stretch a little by the leftover speed.
		var edge := 0.0 if scroll < 0.0 else max_scroll()
		scroll = edge + clampf(scroll - edge, -MAX_STRETCH * 0.4, MAX_STRETCH * 0.4)
		_velocity = 0.0
	_apply()


func _apply() -> void:
	if content == null:
		return
	content.scale = Vector2(zoom, zoom)
	content.size.x = size.x / zoom
	if not _pressing and absf(_velocity) < 5.0 and _overshoot() == 0.0:
		scroll = clampf(scroll, 0.0, max_scroll())
	content.position = Vector2(0, -scroll)
