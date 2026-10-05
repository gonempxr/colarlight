class_name PointerArt
extends RefCounted
## Cartoon pointing hand (a white glove) for the tutorial, hints and the PC
## mouse cursor, drawn with the toon kit. `draw` animates it tapping: the hand glides in, presses
## with a little squash, a ring pulses out from the fingertip, then it lifts.

const PERIOD := 1.45            # seconds per tap loop
const REACH := 26.0             # how far the hand pulls back between taps
const GLOVE := Color("fbfcff")
const CUFF := Color("43b4f5")

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
## A white cartoon glove like a classic pointer: the index finger points
## up, the middle, ring and little fingers fold down in steps on the right,
## the thumb sticks out on the left, a blue cuff at the wrist.
static func hand(ci: CanvasItem, pos: Vector2, angle: float = -0.5, scale: Vector2 = Vector2.ONE) -> void:
	Art.push(ci, pos, angle, scale)
	Art.toon(ci, _glove(), GLOVE, 3.2, 0.55)
	# Finger gaps and the thumb crease.
	for l in _creases():
		Art.line_c(ci, l, Art.INK, 2.6)
	# Shine down the index finger and on the knuckles.
	Art.line_c(ci, PackedVector2Array([Vector2(-3.0, 6), Vector2(-3.0, 22)]), Color(1, 1, 1, 0.95), 2.4)
	# Cuff.
	Art.t_rect(ci, Rect2(-3, 76, 44, 14), 5, CUFF, 3.0, 0.5)
	Art.line_c(ci, PackedVector2Array([Vector2(2, 80.5), Vector2(35, 80.5)]), Color(1, 1, 1, 0.55), 2.2)
	Art.pop(ci)


static var _glove_pts := PackedVector2Array()
static var _crease_lines: Array[PackedVector2Array] = []


## Outline of the glove, fingertip at (0, 0), x to the right, y down.
static func _glove() -> PackedVector2Array:
	if _glove_pts.is_empty():
		var c := PackedVector2Array([
			Vector2(-6, 40), Vector2(-6, 7), Vector2(-4.3, 1.8), Vector2(0, 0), Vector2(4.3, 1.8), Vector2(6, 7),
			Vector2(6, 20.5),
			Vector2(10, 19.6), Vector2(15.5, 19.8), Vector2(18.2, 22.6), Vector2(18.8, 27),
			Vector2(22.5, 25.8), Vector2(28, 26), Vector2(30.8, 28.8), Vector2(31.4, 33),
			Vector2(35, 32), Vector2(40, 32.3), Vector2(42.8, 35.3), Vector2(43.4, 40),
			Vector2(43.4, 58), Vector2(38, 79), Vector2(0, 79), Vector2(-1, 69),
			Vector2(-19.5, 45), Vector2(-21.5, 38.5), Vector2(-18, 33.5), Vector2(-12.5, 34.5), Vector2(-8, 38),
		])
		_glove_pts = Art.smooth_pts(c, 4)
	return _glove_pts


static func _creases() -> Array[PackedVector2Array]:
	if _crease_lines.is_empty():
		_crease_lines = [
			PackedVector2Array([Vector2(6, 19.5), Vector2(5.8, 34)]),
			PackedVector2Array([Vector2(18.8, 26), Vector2(18.6, 39)]),
			PackedVector2Array([Vector2(31.4, 32), Vector2(31.2, 44)]),
			PackedVector2Array([Vector2(-6, 39), Vector2(-5, 55)]),
		]
	return _crease_lines


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
