class_name PointerArt
extends RefCounted
## Cartoon pointing hand for the tutorial and hints: a chubby hand with an
## index finger, curled fingers, a thumb, a white cuff and a sleeve, drawn
## with the toon kit. `draw` animates it tapping: the hand glides in, presses
## with a little squash, a ring pulses out from the fingertip, then it lifts.

const PERIOD := 1.45            # seconds per tap loop
const REACH := 26.0             # how far the hand pulls back between taps
const SKIN := Color("ffd9b5")
const NAIL := Color("fff0e6")
const CUFF := Color("ffffff")
const SLEEVE := Color("3aa6f0")

const _PRESS_AT := 0.40         # loop point where the fingertip touches
const _LIFT_AT := 0.56          # ...and where it starts to lift again
static var _SHADOW := Art.ellipse_pts(Vector2.ZERO, Vector2(13, 7), 14)


static func _ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## How far the hand is from its target (0 = touching) and how squashed
## (0..1) it is at loop time t.
static func tap_state(t: float) -> Vector2:
	var u := fposmod(t, PERIOD) / PERIOD
	if u < _PRESS_AT:
		return Vector2(REACH * (1.0 - _ease_io(u / _PRESS_AT)), 0.0)
	if u < _LIFT_AT:
		var k := (u - _PRESS_AT) / (_LIFT_AT - _PRESS_AT)
		var pk := sin(k * PI)
		return Vector2(-3.0 * pk, pk)
	return Vector2(REACH * _ease_out((u - _LIFT_AT) / (1.0 - _LIFT_AT)), 0.0)


## Draws the hand with its fingertip at `pos`.
## t: clock in seconds. press: true = tapping loop with a ring pulse,
## false = a calm hover (reduced motion, or pointing at something to read).
## angle: finger direction, 0 = straight up; the default leans it so the hand
## comes in from the lower right. size: 1.0 is ~90 px long.
static func draw(ci: CanvasItem, pos: Vector2, t: float, press: bool = true, angle: float = -0.5, size: float = 1.0) -> void:
	var dist := 0.0
	var squash := 0.0
	if press:
		var st := tap_state(t)
		dist = st.x
		squash = st.y
		_rings(ci, pos, t, size)
	else:
		dist = REACH * 0.35 * (0.5 + 0.5 * sin(t * TAU / 1.6))
	var back := Vector2(0, 1).rotated(angle)
	# Soft shadow under the fingertip: darker as the finger gets close.
	var near := 1.0 - clampf(dist / REACH, 0.0, 1.0)
	Art.push(ci, pos + Vector2(3, 5) * size, 0.0, Vector2.ONE * (0.6 + (1.0 - near) * 0.5) * size)
	Art.flat_now(ci, _SHADOW, Color(0.05, 0.02, 0.15, 0.10 + 0.16 * near))
	Art.pop(ci)
	var sc := Vector2(1.0 + 0.07 * squash, 1.0 - 0.11 * squash) * size
	hand(ci, pos + back * dist * size, angle + 0.07 * (dist / REACH), sc)


## The hand alone, fingertip at `pos`, rotated and scaled (no animation).
static func hand(ci: CanvasItem, pos: Vector2, angle: float = -0.5, scale: Vector2 = Vector2.ONE) -> void:
	Art.push(ci, pos, angle, scale)
	# Sleeve and cuff sit under the wrist.
	Art.toon(ci, PackedVector2Array([Vector2(-7, 82), Vector2(29, 80), Vector2(31, 104), Vector2(-9, 106)]), SLEEVE, 3.2, 0.6)
	Art.line_c(ci, PackedVector2Array([Vector2(-3, 96), Vector2(27, 94)]), Color(1, 1, 1, 0.35), 3.0)
	# Fist: the three curled fingers make the bumps on its right side.
	Art.toon(ci, _fist(), SKIN, 3.2, 0.45)
	for y: float in [44.0, 55.0]:
		Art.line_c(ci, PackedVector2Array([Vector2(25.5, y), Vector2(14, y + 0.5)]), Color(Art.INK, 0.5), 1.8)
	for y: float in [38.0, 49.0, 60.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(24, y), Vector2(2.2, 1.4), 8), Color(1, 1, 1, 0.55))
	# Index finger.
	Art.t_rect(ci, Rect2(-8, 0, 16, 48), 8, SKIN, 3.2, 0.3)
	Art.t_rect(ci, Rect2(-4.5, 3.5, 9, 9), 4, NAIL, 0.0, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-3, 4.5, 3, 5), 1.5, 2), Color(1, 1, 1, 0.8))
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, 18), Vector2(1.6, 7), 10), Color(1, 1, 1, 0.45))
	# Thumb folded across the curled fingers.
	Art.push(ci, Vector2(-2, 61), -0.42)
	Art.t_rect(ci, Rect2(-13, -6.5, 27, 13), 6.5, SKIN, 3.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -2.5), Vector2(5, 1.5), 10), Color(1, 1, 1, 0.45))
	Art.pop(ci)
	# Cuff over the wrist.
	Art.t_rect(ci, Rect2(-10, 74, 42, 13), 5, CUFF, 3.2, 0.5)
	Art.pop(ci)


static func _fist() -> PackedVector2Array:
	return Art.smooth_pts(PackedVector2Array([Vector2(-9, 34), Vector2(6, 31), Vector2(21, 31), Vector2(28.5, 37),
			Vector2(26, 44), Vector2(29.5, 49), Vector2(27, 55), Vector2(29, 61), Vector2(25, 70), Vector2(14, 78),
			Vector2(-2, 78), Vector2(-11, 70), Vector2(-12, 50)]), 3)


## Two rings pulsing out from the fingertip every time it presses.
static func _rings(ci: CanvasItem, pos: Vector2, t: float, size: float) -> void:
	var u := fposmod(t, PERIOD) / PERIOD
	for k in 2:
		var f := (u - _PRESS_AT - k * 0.1) / 0.55
		if f < 0.0 or f > 1.0:
			continue
		var e := _ease_out(f)
		var a := (1.0 - f) * (0.9 - k * 0.3)
		Art.arc(ci, pos, (10.0 + e * 34.0) * size, 0, TAU, 32, Color(1, 1, 1, a), (6.0 - 4.0 * f) * size)
	# Little flash at the moment of contact.
	var c := (u - _PRESS_AT) / 0.16
	if c >= 0.0 and c <= 1.0:
		Art.dot(ci, pos, (5.0 + 9.0 * c) * size, Color(1, 1, 0.85, 0.55 * (1.0 - c)))
