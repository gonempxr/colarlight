class_name StreakArt
extends RefCounted
## Toon drawings for the streak: the flame buddy (bright when today
## counted, a calm sleepy flame while it waits), ice cubes (streak freezes)
## and the flame hat. Shapes are built from FLICKER quantized phases so the
## Art shape cache stays small; sizes are placed with Art.push.

const FLICKER := 8
const ORANGE := Color("ff7a2b")
const YELLOW := Color("ffc93c")
const CORE := Color("fff3b0")
const SLEEP_OUT := Color("b9a7d6")
const SLEEP_IN := Color("e0d6f2")
const ICE := Color("a8e6ff")
const ICE_DARK := Color("6cc4ee")
const CHEEK := Color(1.0, 0.45, 0.5, 0.45)

static var _shapes := {}


## Flicker phase (0..FLICKER-1) for a time in seconds.
static func phase(t: float, speed: float = 8.0) -> int:
	return int(floor(t * speed)) % FLICKER


## The flame buddy standing on `base` (bottom middle), `r` its half width.
## lit: bright colours and open eyes; else a calm sleepy flame.
static func flame(ci: CanvasItem, base: Vector2, r: float, ph: int, lit: bool = true, face: bool = true) -> void:
	var rr := snappedf(r, 0.5)
	Art.push(ci, base)
	var outer := _flame_pts(rr, ph, 0)
	Art.toon(ci, outer, ORANGE if lit else SLEEP_OUT, clampf(rr * 0.12, 1.6, 4.0), 0.35)
	Art.flat(ci, _flame_pts(rr, ph, 1), YELLOW if lit else SLEEP_IN)
	Art.flat(ci, _flame_pts(rr, ph, 2), CORE if lit else Color(1, 1, 1, 0.55))
	if face and rr >= 12.0:
		_face(ci, rr, lit)
	Art.pop(ci)


## A little ice cube (one streak freeze). empty: just a faint slot.
static func ice(ci: CanvasItem, c: Vector2, s: float, empty: bool = false, tilt: float = -0.12) -> void:
	var h := snappedf(s, 0.5) / 2.0
	Art.push(ci, c, tilt)
	var box := Art.rrect_pts(Rect2(-h, -h, h * 2.0, h * 2.0), h * 0.38, 4)
	if empty:
		Art.ring(ci, box, Color(0.42, 0.55, 0.75, 0.45), maxf(1.5, h * 0.12))
		Art.pop(ci)
		return
	Art.toon(ci, box, ICE, clampf(h * 0.16, 1.6, 3.5), 0.45)
	# Top face and shine.
	Art.flat(ci, Art.rrect_pts(Rect2(-h * 0.72, -h * 0.78, h * 1.44, h * 0.42), h * 0.18, 3), Color(1, 1, 1, 0.55))
	Art.flat(ci, Art.ellipse_pts(Vector2(-h * 0.45, -h * 0.05), Vector2(h * 0.1, h * 0.28), 10, 0.2), Color(1, 1, 1, 0.8))
	if h >= 9.0:
		var e := h * 0.11
		Art.flat(ci, Art.circle_pts(Vector2(-h * 0.22, h * 0.15), e, 10), Art.INK)
		Art.flat(ci, Art.circle_pts(Vector2(h * 0.32, h * 0.15), e, 10), Art.INK)
		Art.arc(ci, Vector2(h * 0.05, h * 0.3), h * 0.16, 0.3, PI - 0.3, 8, Art.INK, maxf(1.2, h * 0.07))
		Art.flat(ci, Art.circle_pts(Vector2(-h * 0.42, h * 0.38), h * 0.1, 8), Color(1.0, 0.6, 0.75, 0.6))
		Art.flat(ci, Art.circle_pts(Vector2(h * 0.52, h * 0.38), h * 0.1, 8), Color(1.0, 0.6, 0.75, 0.6))
	Art.pop(ci)


## The flame hat (head space of HatsArt: head radius 20 at the origin): a
## gold band with a smiling flame and two little ones.
static func hat(ci: CanvasItem) -> void:
	Art.arc(ci, Vector2(0, 1), 23.0, PI + 0.32, TAU - 0.32, 20, Art.INK, 7.0)
	Art.arc(ci, Vector2(0, 1), 23.0, PI + 0.32, TAU - 0.32, 20, Art.GOLD, 4.0)
	flame(ci, Vector2(-13, -15), 5.5, 2, true, false)
	flame(ci, Vector2(13, -15), 5.5, 5, true, false)
	flame(ci, Vector2(0, -19), 10.0, 0, true, true)


static func _face(ci: CanvasItem, r: float, lit: bool) -> void:
	var ey := -r * 0.55
	var ex := r * 0.36
	var er := r * 0.15
	if lit:
		for sx: float in [-1.0, 1.0]:
			Art.flat(ci, Art.ellipse_pts(Vector2(ex * sx, ey), Vector2(er * 0.85, er * 1.1), 12), Art.INK)
			Art.flat(ci, Art.circle_pts(Vector2(ex * sx - er * 0.25, ey - er * 0.4), er * 0.38, 8), Art.WHITE)
		Art.arc(ci, Vector2(0, ey + r * 0.2), r * 0.24, 0.25, PI - 0.25, 10, Art.INK, maxf(1.4, r * 0.09))
	else:
		for sx: float in [-1.0, 1.0]:
			Art.arc(ci, Vector2(ex * sx, ey - er * 0.2), er * 0.9, 0.2, PI - 0.2, 8, Art.INK, maxf(1.2, r * 0.07))
		Art.arc(ci, Vector2(0, ey + r * 0.28), r * 0.14, 0.3, PI - 0.3, 8, Art.INK, maxf(1.2, r * 0.07))
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.circle_pts(Vector2(r * 0.6 * sx, ey + r * 0.3), r * 0.13, 8), CHEEK)


## Flame outline at half width r, base at the origin (it grows upwards).
## layer 0: outer, 1: the yellow middle, 2: the pale core.
static func _flame_pts(r: float, ph: int, layer: int) -> PackedVector2Array:
	var k := "%s|%d|%d" % [r, ph, layer]
	if _shapes.has(k):
		return _shapes[k]
	var a := TAU * ph / FLICKER
	var sw := sin(a) * 0.09
	var sw2 := sin(a + 2.1) * 0.08
	var hop := cos(a) * 0.07
	var c: Array[Vector2]
	match layer:
		0:
			c = [Vector2(0, 0), Vector2(0.75, -0.12), Vector2(1.0, -0.62), Vector2(0.88, -1.15),
				Vector2(0.62 + sw2, -1.62 + hop), Vector2(0.38, -1.32), Vector2(0.08 + sw, -2.2 - hop),
				Vector2(-0.3, -1.45), Vector2(-0.6 + sw2, -1.78 + hop), Vector2(-0.86, -1.18),
				Vector2(-1.0, -0.62), Vector2(-0.75, -0.12)]
		1:
			c = [Vector2(0, -0.12), Vector2(0.55, -0.24), Vector2(0.7, -0.7), Vector2(0.5, -1.15),
				Vector2(0.08 + sw * 0.8, -1.62 - hop * 0.6), Vector2(-0.45, -1.2), Vector2(-0.7, -0.7),
				Vector2(-0.55, -0.24)]
		_:
			c = [Vector2(0, -0.22), Vector2(0.32, -0.3), Vector2(0.4, -0.55), Vector2(0.06 + sw * 0.6, -0.98),
				Vector2(-0.4, -0.55), Vector2(-0.32, -0.3)]
	var pts := PackedVector2Array()
	for p in c:
		pts.append(p * r)
	pts = Art.smooth_pts(pts, 4)
	_shapes[k] = pts
	return pts
