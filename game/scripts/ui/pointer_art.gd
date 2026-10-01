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
## Back of a right hand: the index finger points up, the three other fingers
## curl into stacked knuckle rolls on the right, the thumb lies across them.
static func hand(ci: CanvasItem, pos: Vector2, angle: float = -0.5, scale: Vector2 = Vector2.ONE) -> void:
	Art.push(ci, pos, angle, scale)
	# Sleeve under the wrist.
	Art.toon(ci, PackedVector2Array([Vector2(-10, 84), Vector2(30, 82), Vector2(32, 106), Vector2(-12, 108)]), SLEEVE, 3.0, 0.6)
	Art.line_c(ci, PackedVector2Array([Vector2(-6, 98), Vector2(27, 96.5)]), Color(1, 1, 1, 0.35), 3.0)
	# Index finger (its base hides behind the hand).
	Art.toon(ci, _finger(), SKIN, 3.0, 0.3)
	Art.flat(ci, Art.rrect_pts(Rect2(-5, 2.5, 10, 11), 4.5), NAIL)
	Art.flat(ci, Art.rrect_pts(Rect2(-3.2, 4.6, 2.6, 4.6), 1.3, 2), Color(1, 1, 1, 0.85))
	Art.flat(ci, Art.ellipse_pts(Vector2(-4.2, 22), Vector2(1.5, 6), 10), Color(1, 1, 1, 0.45))
	Art.line_c(ci, PackedVector2Array([Vector2(-3, 30), Vector2(3, 30)]), Color(Art.INK, 0.35), 1.4)
	# Back of the hand.
	Art.toon(ci, _palm(), SKIN, 3.0, 0.45)
	# Curled fingers: three knuckle rolls, the lower ones in front.
	for i in 3:
		var y := 33.0 + i * 11.0
		Art.t_rect(ci, Rect2(7 - i * 0.5, y, 22.5 - i, 12.5), 6.2, SKIN, 2.6, 0.35)
		Art.flat(ci, Art.ellipse_pts(Vector2(24 - i * 0.6, y + 3.6), Vector2(2.4, 1.3), 8), Color(1, 1, 1, 0.6))
	# Thumb across the front.
	Art.push(ci, Vector2(3, 66), -0.38)
	Art.t_rect(ci, Rect2(-15, -7, 30, 14), 7, SKIN, 2.8, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(7, -4.6, 6, 7.6), 3.0), NAIL)
	Art.flat(ci, Art.ellipse_pts(Vector2(-3, -3.4), Vector2(6, 1.4), 10), Color(1, 1, 1, 0.45))
	Art.pop(ci)
	# Cuff over the wrist.
	Art.t_rect(ci, Rect2(-13, 76, 46, 14), 6, CUFF, 3.0, 0.5)
	Art.pop(ci)


static var _finger_pts := PackedVector2Array()
static var _palm_pts := PackedVector2Array()


static func _finger() -> PackedVector2Array:
	if _finger_pts.is_empty():
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			pts.append(Vector2(cos(a) * 8.0, 8.0 + sin(a) * 8.0))
		pts.append_array([Vector2(9.0, 30), Vector2(9.5, 44), Vector2(-9.5, 44), Vector2(-9.0, 30)])
		_finger_pts = pts
	return _finger_pts


static func _palm() -> PackedVector2Array:
	if _palm_pts.is_empty():
		_palm_pts = Art.smooth_pts(PackedVector2Array([Vector2(-11, 42), Vector2(-7, 34), Vector2(4, 31), Vector2(16, 32),
				Vector2(22, 40), Vector2(23, 62), Vector2(19, 75), Vector2(6, 81), Vector2(-6, 79), Vector2(-12, 68)]), 3)
	return _palm_pts


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
