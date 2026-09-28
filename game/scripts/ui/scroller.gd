class_name Scroller
extends Control
## Vertical scroll view with finger drag, mouse wheel and inertia.
## Listens in _input so a drag that starts on a button still scrolls; buttons
## ask `Scroller.is_drag()` and ignore the release that ends a drag.

const DRAG_THRESHOLD := 14.0
const FRICTION := 5.0
const WHEEL_STEP := 120.0

static var _dragged_recently := false

var content: Control
var scroll := 0.0

var _pressing := false
var _press_y := 0.0
var _last_y := 0.0
var _dragging := false
var _velocity := 0.0
var _last_motion_ms := 0


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
	return maxf(0.0, content.size.y - size.y)


func scroll_to(y: float) -> void:
	scroll = clampf(y, 0.0, max_scroll())
	_velocity = 0.0
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var inside := get_global_rect().has_point(event.position)
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if inside and event.pressed:
					var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					_velocity = 0.0
					scroll = clampf(scroll + dir * WHEEL_STEP * maxf(1.0, event.factor), 0.0, max_scroll())
					_apply()
			MOUSE_BUTTON_LEFT:
				if event.pressed and inside:
					_pressing = true
					_dragging = false
					_dragged_recently = false
					_press_y = event.position.y
					_last_y = event.position.y
					_velocity = 0.0
				elif not event.pressed and _pressing:
					_pressing = false
					if _dragging:
						_dragged_recently = true
						# Buttons check the flag during this release; clear it next frame.
						_clear_drag_flag.call_deferred()
					_dragging = false
	elif event is InputEventMouseMotion and _pressing:
		var y: float = event.position.y
		if not _dragging and absf(y - _press_y) > DRAG_THRESHOLD:
			_dragging = true
			_last_y = y
		if _dragging:
			var dy := y - _last_y
			_last_y = y
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, (now - _last_motion_ms) / 1000.0)
			_last_motion_ms = now
			_velocity = lerpf(_velocity, -dy / dt, 0.5)
			scroll = clampf(scroll - dy, 0.0, max_scroll())
			_apply()


func _clear_drag_flag() -> void:
	_dragged_recently = false


func _process(delta: float) -> void:
	if _pressing or absf(_velocity) < 5.0:
		if not _pressing:
			_velocity = 0.0
		return
	scroll = clampf(scroll + _velocity * delta, 0.0, max_scroll())
	_velocity *= exp(-FRICTION * delta)
	if scroll <= 0.0 or scroll >= max_scroll():
		_velocity = 0.0
	_apply()


func _apply() -> void:
	if content == null:
		return
	content.size.x = size.x
	scroll = clampf(scroll, 0.0, max_scroll())
	content.position = Vector2(0, -scroll)
