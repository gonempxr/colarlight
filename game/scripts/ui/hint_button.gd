class_name HintButton
extends Control
## Round lightbulb button: tap it for the best next step. It glows and
## wiggles with a "!" when there is something worth doing right now.

signal pressed

const SIZE := 84.0

var urgent := false
var _t := 0.0
var _down := false
var _press := 0.0
var _check_left := 0.0
var _redraw_left := 0.0
var _drawn_urgent := false
var _urgent_at := -99.0
const WIGGLE_SEC := 10.0
var main: Node


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("HINT_TITLE")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			Sfx.play("click")
			pressed.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	_press = move_toward(_press, 1.0 if _down else 0.0, delta * 10.0)
	_check_left -= delta
	if _check_left <= 0.0 and main:
		_check_left = 1.0
		urgent = bool(Hints.pick(main)["urgent"])
	if urgent and not _drawn_urgent:
		_urgent_at = _t
	var wig := 0.0
	# It wiggles for a little while when a hint turns up, then only glows.
	if urgent and not Settings.reduce_motion and _t - _urgent_at < WIGGLE_SEC:
		wig = sin(_t * 10.0) * 0.08 * maxf(0.0, sin(_t * 1.8))
	rotation = wig
	scale = Vector2.ONE * (1.0 - _press * 0.08)
	# Only the urgent glow moves; a calm bulb repaints when it changes.
	_redraw_left -= delta
	if urgent != _drawn_urgent or (urgent and _redraw_left <= 0.0):
		_drawn_urgent = urgent
		_redraw_left = 1.0 / 30.0
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	if urgent:
		# Soft glow rings.
		var p := fmod(_t, 1.4) / 1.4
		Art.arc(self, c, SIZE * 0.46 + p * 16.0, 0, TAU, 32, Color(1.0, 0.86, 0.3, 0.5 * (1.0 - p)), 4.0)
	Art.t_circle(self, c, SIZE * 0.44, Color("fff4d6") if urgent else Color("e9f3ff"), 4.0, 0.6)
	draw_bulb(self, c + Vector2(0, 2), SIZE * 0.3, _t, urgent)
	if urgent:
		var b := c + Vector2(SIZE * 0.32, -SIZE * 0.32)
		Art.t_circle(self, b, 13.0, Art.RED, 3.0, 0.0)
		Art.text(self, b + Vector2(0, 1), "!", 20, Art.WHITE, 0)


## A cartoon lightbulb centred at `c` with radius `r`; `lit` adds rays.
static func draw_bulb(ci: CanvasItem, c: Vector2, r: float, t: float, lit: bool) -> void:
	if lit:
		for i in 8:
			var a := -PI / 2.0 + (i - 3.5) * 0.42
			var len := r * (0.45 + 0.12 * sin(t * 4.0 + i))
			var from := c + Vector2(cos(a), sin(a)) * (r * 1.15)
			Art.line(ci, from, from + Vector2(cos(a), sin(a)) * len, Color(1.0, 0.78, 0.2, 0.9), maxf(2.0, r * 0.12))
	var glass := Color("ffe066") if lit else Color("fff3b8")
	# Glass: a round top narrowing to the neck.
	var pts := Art.smooth_pts(PackedVector2Array([
		c + Vector2(-r * 0.42, r * 0.62), c + Vector2(-r * 0.62, r * 0.05), c + Vector2(-r * 0.92, -r * 0.45),
		c + Vector2(-r * 0.6, -r * 1.0), c + Vector2(0, -r * 1.12), c + Vector2(r * 0.6, -r * 1.0),
		c + Vector2(r * 0.92, -r * 0.45), c + Vector2(r * 0.62, r * 0.05), c + Vector2(r * 0.42, r * 0.62)]), 3)
	Art.toon(ci, pts, glass, maxf(2.5, r * 0.11), 0.6)
	# Shine and filament.
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-r * 0.4, -r * 0.55), Vector2(r * 0.16, r * 0.28), 12, -0.5), Color(1, 1, 1, 0.75))
	Art.polyline(ci, PackedVector2Array([c + Vector2(-r * 0.25, r * 0.5), c + Vector2(-r * 0.2, -r * 0.2), c + Vector2(0, -r * 0.05),
			c + Vector2(r * 0.2, -r * 0.2), c + Vector2(r * 0.25, r * 0.5)]), Color("e08a1e"), maxf(1.5, r * 0.08))
	# Screw base.
	Art.t_rect(ci, Rect2(c + Vector2(-r * 0.45, r * 0.6), Vector2(r * 0.9, r * 0.5)), r * 0.12, Color("a9b3c9"), maxf(2.0, r * 0.1), 0.5)
	Art.line(ci, c + Vector2(-r * 0.4, r * 0.85), c + Vector2(r * 0.4, r * 0.85), Color("6f7a94"), maxf(1.5, r * 0.07))
	Art.t_rect(ci, Rect2(c + Vector2(-r * 0.22, r * 1.08), Vector2(r * 0.44, r * 0.2)), r * 0.1, Color("4a4f6a"), maxf(1.5, r * 0.08), 0.0)
