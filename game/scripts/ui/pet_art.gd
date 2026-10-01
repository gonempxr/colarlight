class_name PetArt
extends RefCounted
## Little sea companions (~44 px wide at scale 1), drawn in local space
## centered at (0,0), facing right. Idle animation comes from `t` through
## transforms only (bob, fin and tentacle wiggles, blinks swap between two
## constant eye shapes); `happy` shows closed happy eyes and an open smile.

const IDS: Array[String] = ["turtle", "octopus", "crab", "clownfish", "seal", "jellyfish", "axolotl", "puffer", "dolphin", "narwhal", "seahorse", "shark_pup"]

const W := 2.2           # body outline width
const W2 := 1.7          # small parts
const MOUTH := Color("b8455f")
const TONGUE := Color("ff8fa3")


## facing: 1 = right, -1 = left.
static func draw(ci: CanvasItem, id: String, t: float, facing: float = 1.0, happy: bool = false) -> void:
	var sd := float(maxi(IDS.find(id), 0)) * 0.61
	var blink := not happy and fposmod(t + sd * 1.3, 3.2 + fposmod(sd, 0.7)) < 0.14
	var bob := -absf(sin(t * 5.0)) * 3.0 if happy else sin(t * 2.4 + sd) * 1.5
	Art.push(ci, Vector2(0, bob), 0.0, Vector2(facing, 1.0))
	match id:
		"turtle": _turtle(ci, t, blink, happy)
		"octopus": _octopus(ci, t, blink, happy)
		"crab": _crab(ci, t, blink, happy)
		"clownfish": _clownfish(ci, t, blink, happy)
		"seal": _seal(ci, t, blink, happy)
		"jellyfish": _jellyfish(ci, t, blink, happy)
		"axolotl": _axolotl(ci, t, blink, happy)
		"puffer": _puffer(ci, t, blink, happy)
		"dolphin": _dolphin(ci, t, blink, happy)
		"narwhal": _narwhal(ci, t, blink, happy)
		"seahorse": _seahorse(ci, t, blink, happy)
		"shark_pup": _shark_pup(ci, t, blink, happy)
	Art.pop(ci)


# --- Face bits ----------------------------------------------------------------------

## Big shiny eye; blink = closed curve, happy = "^" arch.
static func _eye(ci: CanvasItem, c: Vector2, r: float, blink: bool, happy: bool) -> void:
	if happy:
		Art.flat(ci, _band(c + Vector2(0, r * 0.55), r * 0.95, PI + 0.45, TAU - 0.45, maxf(1.2, r * 0.5)), Art.INK)
	elif blink:
		Art.flat(ci, _band(c + Vector2(0, -r * 0.4), r * 0.95, 0.45, PI - 0.45, maxf(1.1, r * 0.45)), Art.INK)
	else:
		Art.flat(ci, Art.ellipse_pts(c, Vector2(r * 0.84, r), 14), Art.INK)
		Art.flat(ci, Art.circle_pts(c + Vector2(r * 0.22, -r * 0.4), r * 0.38, 8), Art.WHITE)
		Art.flat(ci, Art.circle_pts(c + Vector2(-r * 0.3, r * 0.4), r * 0.18, 6), Art.WHITE)


## Arc of even thickness as a filled shape with rounded ends (crisp at any
## zoom, unlike a polyline whose soft edge grows with the scale).
static func _band(c: Vector2, r: float, a0: float, a1: float, thick: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ro := r + thick / 2.0
	var ri := maxf(r - thick / 2.0, 0.1)
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * ro)
	var e1 := c + Vector2(cos(a1), sin(a1)) * r
	for i in 5:
		var a := a1 + PI * i / 4.0
		pts.append(e1 + Vector2(cos(a), sin(a)) * thick / 2.0)
	for i in 9:
		var a := lerpf(a1, a0, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * ri)
	var e0 := c + Vector2(cos(a0), sin(a0)) * r
	for i in 5:
		var a := a0 + PI + PI * i / 4.0
		pts.append(e0 + Vector2(cos(a), sin(a)) * thick / 2.0)
	return pts


static func _cheek(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.flat(ci, Art.ellipse_pts(c, Vector2(r, r * 0.62), 10), Color(1.0, 0.4, 0.55, 0.5))


## Small cute mouth. Neutral: a thin "w" smile; happy: a little open
## smile with a pink tongue and a fine outline (no heavy dark lips).
static func _mouth(ci: CanvasItem, c: Vector2, w: float, happy: bool) -> void:
	if happy:
		var pts := PackedVector2Array([c + Vector2(-w * 0.8, -w * 0.25)])
		for i in 9:
			var a := lerpf(0.0, PI, i / 8.0)
			pts.append(c + Vector2(cos(a) * w * 0.8, -w * 0.25 + sin(a) * w * 0.85))
		Art.toon(ci, pts, MOUTH, 0.75, 0.0)
		Art.flat(ci, Art.clipped(Art.ellipse_pts(c + Vector2(0, w * 0.55), Vector2(w * 0.5, w * 0.3), 10), pts), TONGUE)
	else:
		Art.flat(ci, _smile(c + Vector2(0, -w * 0.75), w * 1.05, 0.62, clampf(w * 0.42, 0.8, 1.0)), Art.INK)


## Thin smile as a filled crescent (a polyline's soft edge is a whole local
## pixel wide, which made tiny mouths read as thick dark lips).
static func _smile(c: Vector2, r: float, a0: float, thick: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(a0, PI - a0, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for i in 9:
		var a := lerpf(PI - a0, a0, i / 8.0)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r - thick * sin(a)))
	return pts


static func _shine(ci: CanvasItem, c: Vector2, radii: Vector2, rot: float) -> void:
	Art.flat(ci, Art.ellipse_pts(c, radii, 10, rot), Color(1, 1, 1, 0.6))


## Top half of an ellipse plus a straight bottom (domes, shells, bells).
static func _dome(c: Vector2, radii: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


static var _tubes := {}


## Tapered soft tube along a smoothed centerline (tentacles, tails), built
## once per set of control points and cached.
static func _tube(ctrl: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var k := hash([ctrl, w0, w1])
	if _tubes.has(k):
		return _tubes[k]
	var mid := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for s in 4:
			var t := s / 4.0
			var t2 := t * t
			var t3 := t2 * t
			mid.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	mid.append(ctrl[n - 1])
	var m := mid.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var tip := Vector2.ZERO
	for i in m:
		var d := (mid[mini(i + 1, m - 1)] - mid[maxi(i - 1, 0)]).normalized()
		var hw := lerpf(w0, w1, float(i) / (m - 1)) / 2.0
		left.append(mid[i] + d.orthogonal() * hw)
		right.append(mid[i] - d.orthogonal() * hw)
		if i == m - 1:
			tip = mid[i] + d * hw
	right.reverse()
	left.append(tip)
	left.append_array(right)
	_tubes[k] = left
	return left


# --- Pets ------------------------------------------------------------------------------

static func _turtle(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var shell := Color("2f9a5a")
	var skin := Color("a4e37c")
	var rim := Color("f5c94c")
	var paddle := sin(t * 3.0) * 0.35
	Art.push(ci, Vector2(-1, 0), 0.0, Vector2(0.9, 0.9))
	for p: Vector3 in [Vector3(-13, 8, 0.6), Vector3(7, 8, -0.4)]:
		Art.push(ci, Vector2(p.x, p.y), p.z + paddle)
		Art.t_ellipse(ci, Vector2(0, 4), Vector2(3.6, 6), Art.shade_of(skin, 0.2), W2, 0.0)
		Art.pop(ci)
	Art.toon(ci, PackedVector2Array([Vector2(-19, 4), Vector2(-26, 7), Vector2(-19, 9)]), skin, W2, 0.0)
	var dome := _dome(Vector2(-3, 7), Vector2(19, 17))
	Art.toon(ci, dome, shell, W, 0.6)
	# Shell plates: rounded scutes in a lighter green with darker seams,
	# all kept inside the dome (no shape pokes out of the outline).
	var plate := Color("6fcf8a")
	var inner := Art.ellipse_pts(Vector2(-3, 6), Vector2(16, 14.5), 24)
	for sc: Array in [[Vector2(-3, -2), Vector2(5.5, 5.0)], [Vector2(-12.5, 1.5), Vector2(4.2, 4.6)],
			[Vector2(6.5, 1.5), Vector2(4.2, 4.6)], [Vector2(-8, -8.5), Vector2(3.6, 2.6)], [Vector2(2, -8.5), Vector2(3.6, 2.6)]]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(sc[0] - sc[1], sc[1] * 2.0), minf(sc[1].x, sc[1].y) * 0.7), inner), plate)
	_shine(ci, Vector2(-9, -6), Vector2(3.2, 1.6), -0.5)
	Art.t_rect(ci, Rect2(-23, 4, 40, 6), 3, rim, W2, 0.0)
	for p: Vector3 in [Vector3(-11, 9, 0.35), Vector3(9, 9, -0.35)]:
		Art.push(ci, Vector2(p.x, p.y), p.z - paddle)
		Art.t_ellipse(ci, Vector2(0, 3.5), Vector2(3.8, 5.5), skin, W2, 0.0)
		Art.pop(ci)
	Art.push(ci, Vector2(16, -2), sin(t * 1.7) * 0.1)
	Art.toon(ci, Art.circle_pts(Vector2(5, -3), 10.0, 24), skin, W, 0.5)
	_eye(ci, Vector2(3.5, -5), 2.7, blink, happy)
	_eye(ci, Vector2(10, -5), 2.7, blink, happy)
	_cheek(ci, Vector2(12.5, 0), 2.2)
	_mouth(ci, Vector2(7.5, 1.2), 2.2, happy)
	Art.pop(ci)
	Art.pop(ci)


static func _octopus(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ff7eb6")
	var xs := [-13.0, -8.0, -3.0, 3.0, 8.0, 13.0]
	for i in xs.size():
		var x: float = xs[i]
		var spread := x / 13.0 * 0.7 * -1.0
		Art.push(ci, Vector2(x * 0.9, 4), spread + sin(t * 3.0 + i * 1.3) * 0.22)
		var tone := col if i in [0, 2, 3, 5] else Art.shade_of(col, 0.15)
		Art.toon(ci, _tube(PackedVector2Array([Vector2(0, -2), Vector2(0.5, 5), Vector2(-1, 10), Vector2(1, 14), Vector2(5, 15.5), Vector2(6.5, 13)]), 6.0, 2.4), tone, W2, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(-0.3, 8.5), 1.0, 6), Color("ffd0e6"))
		Art.flat(ci, Art.circle_pts(Vector2(1.2, 12.5), 0.8, 6), Color("ffd0e6"))
		Art.pop(ci)
	Art.toon(ci, Art.ellipse_pts(Vector2(0, -5), Vector2(16, 14.5), 30), col, 2.4, 0.6)
	for p: Vector3 in [Vector3(-9, -13, 2.4), Vector3(-12, -5, 1.6), Vector3(8, -15, 1.4)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 8), Color("ffc2dc"))
	_shine(ci, Vector2(-4, -14), Vector2(4, 2), -0.4)
	_eye(ci, Vector2(-4, -3), 3.5, blink, happy)
	_eye(ci, Vector2(7, -3), 3.5, blink, happy)
	_cheek(ci, Vector2(-9, 3), 2.6)
	_cheek(ci, Vector2(12, 3), 2.6)
	_mouth(ci, Vector2(1.5, 3.5), 2.4, happy)


static func _claw() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(1.5, -6.5)])
	for i in 15:
		var a := -0.25 + (TAU - 1.1) * i / 14.0
		pts.append(Vector2(0, -6) + Vector2(cos(a), sin(a)) * 7.0)
	return pts


static func _crab(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ff5d4a")
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			Art.push(ci, Vector2(sx * (9.0 + k * 2.5), 7.0 + k * 1.2), -sx * (0.7 + k * 0.35) + sin(t * 6.0 + k + sx) * 0.1)
			Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(0, 9)]), Art.shade_of(col, 0.12), 2.6, W2)
			Art.pop(ci)
	# Eye stalks.
	for sx: float in [-1.0, 1.0]:
		Art.stroke(ci, PackedVector2Array([Vector2(5 * sx, -6), Vector2(6 * sx, -14)]), col, 2.6, W2)
	var body := Art.ellipse_pts(Vector2(0, 3), Vector2(17, 11), 30)
	Art.toon(ci, body, col, 2.4, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(0, 12), Vector2(14, 5), 16), body), Color("ffb09a"))
	for p: Vector2 in [Vector2(-9, -3), Vector2(-4, -5), Vector2(8, -4)]:
		Art.flat(ci, Art.circle_pts(p, 1.2, 6), Color("ffa08c"))
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(6.2 * sx, -16.5)
		Art.t_circle(ci, e, 4.4, Art.WHITE, W2, 0.0)
		if happy or blink:
			_eye(ci, e + Vector2(0, 0.4), 2.6, blink, happy)
		else:
			Art.flat(ci, Art.circle_pts(e + Vector2(0.8, 0.6), 2.4, 10), Art.INK)
			Art.flat(ci, Art.circle_pts(e + Vector2(1.4, -0.4), 0.9, 6), Art.WHITE)
	_cheek(ci, Vector2(-9, 5), 2.6)
	_cheek(ci, Vector2(9, 5), 2.6)
	_mouth(ci, Vector2(0, 5.5), 2.6, happy)
	# Claws wave, the front one a bit more.
	for sx: float in [-1.0, 1.0]:
		var wave := sin(t * (4.0 if sx > 0 else 3.2)) * (0.22 if happy else 0.12)
		Art.push(ci, Vector2(15.5 * sx, -1), sx * (0.25 + wave), Vector2(sx, 1))
		Art.stroke(ci, PackedVector2Array([Vector2(0, 2), Vector2(3, -5)]), col, 3.5, W2)
		Art.push(ci, Vector2(4, -6), 0.0, Vector2(0.95, 0.95))
		Art.toon(ci, _claw(), col, W, 0.5)
		Art.pop(ci)
		Art.pop(ci)


static func _clownfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ff8a2a")
	Art.push(ci, Vector2(-14, 0), sin(t * 6.0) * 0.25)
	var tail := Art.smooth_pts(PackedVector2Array([Vector2(2, 0), Vector2(-9, -9), Vector2(-6, 0), Vector2(-9, 9)]), 3)
	Art.toon(ci, tail, col, W, 0.0)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-12, -12, 4, 24), 1), tail), Art.INK)
	Art.pop(ci)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-9, -8), Vector2(-3, -15), Vector2(6, -14), Vector2(10, -8)]), 3), col, W, 0.0)
	var body := Art.ellipse_pts(Vector2(1, 0), Vector2(16, 11.5), 30)
	Art.toon(ci, body, col, 2.4, 0.6)
	for x: float in [4.0, -7.0]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(x - 3.6, -20, 7.2, 40), 1), body), Art.INK)
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(x - 2.4, -20, 4.8, 40), 1), body), Art.WHITE)
	_shine(ci, Vector2(-2, -7), Vector2(3.5, 1.8), -0.2)
	Art.push(ci, Vector2(-1, 5), sin(t * 5.0) * 0.3)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-5, -3.5), Vector2(-8.5, -0.5), Vector2(-6, 3.5)]), 3), Art.shade_of(col, 0.1), W2, 0.0)
	Art.pop(ci)
	_eye(ci, Vector2(11, -2), 3.2, blink, happy)
	_cheek(ci, Vector2(12.5, 3.8), 2.2)
	_mouth(ci, Vector2(15.2, 2.6), 1.8, happy)


static func _seal(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("a9bdd6")
	var belly := Color("e8f0fa")
	Art.push(ci, Vector2(-19, 6), sin(t * 3.0) * 0.25)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(1, 0), Vector2(-8, -6), Vector2(-6, 0), Vector2(-9, 6)]), 3), Art.shade_of(col, 0.15), W2, 0.0)
	Art.pop(ci)
	var body := Art.union([Art.ellipse_pts(Vector2(-3, 5), Vector2(17, 9.5), 28), Art.circle_pts(Vector2(9, -4), 11.5, 26)])
	Art.toon(ci, body, col, 2.4, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(2, 12), Vector2(17, 5), 20), body), belly)
	for p: Vector2 in [Vector2(-10, -1), Vector2(-5, -3), Vector2(-14, 3)]:
		Art.flat(ci, Art.circle_pts(p, 1.3, 6), Art.shade_of(col, 0.2))
	Art.push(ci, Vector2(3, 9), -0.2 + sin(t * 3.0) * 0.25)
	Art.t_ellipse(ci, Vector2(-3, 2.5), Vector2(6, 2.8), Art.shade_of(col, 0.12), W2, 0.0, 0.5)
	Art.pop(ci)
	_eye(ci, Vector2(5, -7), 2.7, blink, happy)
	_eye(ci, Vector2(13.5, -7), 2.7, blink, happy)
	_cheek(ci, Vector2(3, -1.5), 2.2)
	_cheek(ci, Vector2(16.5, -1.5), 2.2)
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(9.2 + 2.1 * sx, -1.5), Vector2(2.4, 1.9), 10), belly)
		Art.flat(ci, Art.circle_pts(Vector2(9.2 + 2.4 * sx, -1.3), 0.45, 5), Art.INK_SOFT)
	Art.flat(ci, Art.ellipse_pts(Vector2(9.2, -3.0), Vector2(1.7, 1.2), 8), Art.INK)
	_mouth(ci, Vector2(9.2, 1.8), 1.8, happy)


static func _jellyfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("c9a3ff")
	for i in 4:
		var x := -9.0 + i * 6.0
		Art.push(ci, Vector2(x, 3), sin(t * 2.5 + i * 1.4) * 0.2)
		Art.toon(ci, _tube(PackedVector2Array([Vector2(0, -2), Vector2(1.5, 4), Vector2(-1, 8), Vector2(1.5, 12), Vector2(0, 16)]), 3.2, 1.4), Color("ffb3de"), 1.4, 0.0)
		Art.pop(ci)
	Art.push(ci, Vector2(0, 3), sin(t * 2.0) * 0.12)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(5, 6), Vector2(2, 10), Vector2(3.5, 14), Vector2(-1, 12.5), Vector2(-4, 7)]), 3), Color("f59ad6"), W2, 0.0)
	Art.pop(ci)
	var pulse := 1.0 + sin(t * 3.0) * 0.05
	Art.push(ci, Vector2(0, 4), 0.0, Vector2(pulse, 2.0 - pulse))
	var polys := [_dome(Vector2(0, 0), Vector2(16, 18))]
	for i in 5:
		polys.append(Art.circle_pts(Vector2(-12 + i * 6.0, 0), 3.4, 12))
	var bell := Art.union(polys)
	Art.toon(ci, bell, col, 2.4, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-3, -12), Vector2(9, 5), 16), bell), Color(1, 1, 1, 0.35))
	for p: Vector2 in [Vector2(-11, -8), Vector2(10, -10), Vector2(12, -3)]:
		Art.flat(ci, Art.circle_pts(p, 1.4, 6), Color("e6d4ff"))
	_eye(ci, Vector2(-5, -6), 3.2, blink, happy)
	_eye(ci, Vector2(5, -6), 3.2, blink, happy)
	_cheek(ci, Vector2(-10, -1), 2.4)
	_cheek(ci, Vector2(10, -1), 2.4)
	_mouth(ci, Vector2(0, -0.5), 2.2, happy)
	Art.pop(ci)


static func _axolotl(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ffb0cf")
	var gill := Color("ff5fa2")
	Art.push(ci, Vector2(0, 1), 0.0, Vector2(0.92, 0.92))
	# Feathery gills behind the head.
	var fronds := [[Vector2(-1, -7), -2.1], [Vector2(-2, -3), -2.6], [Vector2(-1, 1), -3.0],
			[Vector2(17, -7), -1.05], [Vector2(18, -3), -0.55], [Vector2(17, 1), -0.12]]
	for i in fronds.size():
		var f: Array = fronds[i]
		Art.push(ci, f[0], f[1] + sin(t * 3.0 + i) * 0.12)
		Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(8.5, 0)]), gill, 3.0, W2)
		for p: Vector2 in [Vector2(4, -2.2), Vector2(7, -2.2), Vector2(4, 2.2), Vector2(7, 2.2)]:
			Art.flat(ci, Art.circle_pts(p, 1.3, 6), gill.lightened(0.2))
		Art.pop(ci)
	Art.push(ci, Vector2(-14, 6), sin(t * 3.0) * 0.2)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(2, -3), Vector2(-7, -5), Vector2(-14, -2), Vector2(-9, 1.5), Vector2(2, 3)]), 3), Art.shade_of(col, 0.08), W2, 0.0)
	Art.pop(ci)
	for x: float in [-12.0, 1.0]:
		Art.t_ellipse(ci, Vector2(x, 12), Vector2(2.4, 3.4), Art.shade_of(col, 0.12), W2, 0.0)
	var body := Art.union([Art.ellipse_pts(Vector2(-5, 6), Vector2(11, 6), 24), Art.ellipse_pts(Vector2(8, -2), Vector2(13, 11), 28)])
	Art.toon(ci, body, col, W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-2, 12), Vector2(12, 3.5), 16), body), Color("ffd6e6"))
	_shine(ci, Vector2(3, -9), Vector2(4, 2), -0.2)
	_eye(ci, Vector2(3.5, -3), 2.5, blink, happy)
	_eye(ci, Vector2(12.5, -3), 2.5, blink, happy)
	_cheek(ci, Vector2(1, 2), 2.2)
	_cheek(ci, Vector2(15, 2), 2.2)
	if happy:
		_mouth(ci, Vector2(8, 2), 2.4, true)
	else:
		Art.flat(ci, _smile(Vector2(8, -1), 4.0, 0.4, 1.0), Art.INK)
	Art.pop(ci)


static func _puffer(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ffd84a")
	Art.push(ci, Vector2(-15, 0), sin(t * 6.0) * 0.3)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(1, 0), Vector2(-7, -6), Vector2(-5, 0), Vector2(-7, 6)]), 3), Color("f5b83a"), W2, 0.0)
	Art.pop(ci)
	var puff := 1.0 + sin(t * 1.6) * 0.05
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(puff, puff))
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 19.5, 14.5, 16), Color("e8a93a"), 2.0, 0.0)
	var body := Art.circle_pts(Vector2.ZERO, 16.0, 30)
	Art.toon(ci, body, col, 2.4, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(1, 11), Vector2(14, 7), 18), body), Color("fff6d6"))
	for p: Vector2 in [Vector2(-6, -10), Vector2(0, -12), Vector2(-10, -4), Vector2(-3, -6)]:
		Art.flat(ci, Art.circle_pts(p, 1.3, 6), Color("d99a2b"))
	_shine(ci, Vector2(-7, -8), Vector2(3.5, 2), -0.6)
	Art.push(ci, Vector2(-4, 4), sin(t * 7.0) * 0.35)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-5, -3), Vector2(-7.5, 0), Vector2(-5, 3)]), 3), Color("f5c040"), W2, 0.0)
	Art.pop(ci)
	_eye(ci, Vector2(4, -4), 3.1, blink, happy)
	_eye(ci, Vector2(11.5, -4), 3.1, blink, happy)
	_cheek(ci, Vector2(2, 2.5), 2.2)
	_cheek(ci, Vector2(14, 2), 2.2)
	if happy:
		_mouth(ci, Vector2(9, 3.5), 2.4, true)
	else:
		Art.toon(ci, Art.ellipse_pts(Vector2(9, 4), Vector2(1.5, 1.8), 10), TONGUE, 0.8, 0.0)
	Art.pop(ci)


static func _dolphin(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("5aa9f0")
	Art.push(ci, Vector2(-23, 0), sin(t * 4.0) * 0.25)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(3, 0), Vector2(-5, -7), Vector2(-9, -7), Vector2(-6, 0), Vector2(-9, 7), Vector2(-5, 7)]), 3), Art.shade_of(col, 0.12), W2, 0.0)
	Art.pop(ci)
	Art.toon(ci, PackedVector2Array([Vector2(-6, -9), Vector2(-13, -19), Vector2(-9, -19), Vector2(3, -10)]), Art.shade_of(col, 0.12), W2, 0.0)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(24, 0), Vector2(19, -3), Vector2(14, -9), Vector2(2, -12), Vector2(-12, -9),
			Vector2(-22, -3), Vector2(-25, 0), Vector2(-20, 3), Vector2(-8, 7), Vector2(6, 8), Vector2(15, 5), Vector2(20, 3)]), 3)
	Art.toon(ci, body, col, W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(5, 9), Vector2(19, 6), 20), body), Color("d6efff"))
	_shine(ci, Vector2(0, -8), Vector2(5, 1.8), -0.1)
	Art.push(ci, Vector2(4, 5), 0.5 + sin(t * 4.0) * 0.2)
	Art.t_ellipse(ci, Vector2(-3, 3), Vector2(5.5, 2.4), Art.shade_of(col, 0.15), W2, 0.0, 0.6)
	Art.pop(ci)
	_eye(ci, Vector2(12, -4), 2.9, blink, happy)
	_cheek(ci, Vector2(14.5, 1), 2.2)
	_mouth(ci, Vector2(19.5, 1.2), 1.9, happy)


static func _narwhal(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("9fb0f0")
	Art.push(ci, Vector2(-17, 3), sin(t * 3.5) * 0.25)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(3, 0), Vector2(-5, -7), Vector2(-9, -6), Vector2(-6, 0), Vector2(-9, 6), Vector2(-5, 7)]), 3), Art.shade_of(col, 0.12), W2, 0.0)
	Art.pop(ci)
	# Spiral tusk.
	Art.toon(ci, PackedVector2Array([Vector2(8, -8), Vector2(14, -5), Vector2(26, -24)]), Color("fff2c8"), W2, 0.0)
	for f: float in [0.25, 0.45, 0.65]:
		var a := Vector2(8, -8).lerp(Vector2(26, -24), f)
		var b := Vector2(14, -5).lerp(Vector2(26, -24), f)
		Art.line(ci, a, b.lerp(a, 0.1) + Vector2(0, 0.8), Color("d9b77a"), 1.1)
	var body := Art.ellipse_pts(Vector2(0, 2), Vector2(18, 12.5), 30)
	Art.toon(ci, body, col, W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(3, 12), Vector2(16, 6), 20), body), Color("e4eaff"))
	for p: Vector2 in [Vector2(-10, -4), Vector2(-5, -7), Vector2(-13, 2), Vector2(-7, 0)]:
		Art.flat(ci, Art.circle_pts(p, 1.3, 6), Art.shade_of(col, 0.25))
	_shine(ci, Vector2(-3, -7), Vector2(4, 1.8), -0.2)
	Art.push(ci, Vector2(2, 9), sin(t * 3.5) * 0.25)
	Art.t_ellipse(ci, Vector2(-3, 2), Vector2(5, 2.4), Art.shade_of(col, 0.15), W2, 0.0, 0.5)
	Art.pop(ci)
	_eye(ci, Vector2(5, -1), 2.7, blink, happy)
	_eye(ci, Vector2(13, -1), 2.7, blink, happy)
	_cheek(ci, Vector2(2.5, 4), 2.2)
	_cheek(ci, Vector2(15.5, 4), 2.2)
	_mouth(ci, Vector2(9, 4.5), 2.0, happy)


static func _seahorse(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("ffb347")
	var fin := Color("ffe08a")
	Art.push(ci, Vector2(-3.5, 0.5), sin(t * 1.8) * 0.06, Vector2(0.86, 0.86))
	# Crest spikes and the curled tail behind the body.
	for p: PackedVector2Array in [PackedVector2Array([Vector2(-3, -19), Vector2(-2, -27), Vector2(3, -21)]),
			PackedVector2Array([Vector2(2, -22), Vector2(6, -28), Vector2(8, -21)])]:
		Art.toon(ci, p, Art.shade_of(col, 0.1), W2, 0.0)
	Art.toon(ci, _tube(PackedVector2Array([Vector2(3, 6), Vector2(1, 14), Vector2(2, 19), Vector2(6, 21.5), Vector2(9.5, 19.5),
			Vector2(9, 16), Vector2(6, 15.5)]), 8.0, 3.0), col, W, 0.0)
	Art.push(ci, Vector2(-4, 0), sin(t * 9.0) * 0.25)
	var fan := Art.smooth_pts(PackedVector2Array([Vector2(1, -5), Vector2(-6, -5), Vector2(-9, 0), Vector2(-6, 5), Vector2(1, 5)]), 3)
	Art.toon(ci, fan, fin, W2, 0.0)
	for a: float in [-0.5, 0.0, 0.5]:
		Art.line(ci, Vector2(0, 0), Vector2(-7, 0).rotated(a), Color("f0b84a"), 1.1)
	Art.pop(ci)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-2, -22), Vector2(5, -24), Vector2(10, -20), Vector2(18, -18), Vector2(20, -14.5),
			Vector2(11, -13), Vector2(9, -9), Vector2(12, -3), Vector2(12.5, 4), Vector2(9, 10), Vector2(3, 12), Vector2(-2, 9),
			Vector2(-4, 2), Vector2(-4, -8), Vector2(-5, -16)]), 3)
	Art.toon(ci, body, col, W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(10, 1), Vector2(5, 10), 16), body), Color("ffe0a8"))
	for y: float in [-3.0, 1.0, 5.0]:
		Art.line(ci, Vector2(7.5, y), Vector2(11.5, y + 0.6), Art.shade_of(col, 0.2), 1.1)
	_shine(ci, Vector2(1, -18), Vector2(3, 1.6), -0.3)
	_eye(ci, Vector2(4.5, -15.5), 3.0, blink, happy)
	_cheek(ci, Vector2(8, -10), 2.0)
	if happy:
		_mouth(ci, Vector2(17.2, -15.6), 1.25, true)
	else:
		Art.flat(ci, Art.circle_pts(Vector2(19.6, -15.2), 0.9, 6), Art.INK)
	Art.pop(ci)


static func _shark_pup(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var col := Color("8aa6d6")
	Art.push(ci, Vector2(-18, 0), sin(t * 5.0) * 0.25)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(2, 0), Vector2(-5, -10), Vector2(-9, -11), Vector2(-7, -2), Vector2(-8, 7), Vector2(-4, 7)]), 3), Art.shade_of(col, 0.12), W2, 0.0)
	Art.pop(ci)
	Art.toon(ci, PackedVector2Array([Vector2(6, -8), Vector2(-2, -19), Vector2(-5, -20), Vector2(-4, -15), Vector2(-8, -8)]), Art.shade_of(col, 0.12), W2, 0.0)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(22, 0), Vector2(18, -6), Vector2(8, -10), Vector2(-6, -9), Vector2(-18, -3),
			Vector2(-20, 0), Vector2(-17, 3), Vector2(-4, 8), Vector2(10, 9), Vector2(19, 5)]), 3)
	Art.toon(ci, body, col, W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(6, 9), Vector2(17, 5.5), 20), body), Color("f2f6ff"))
	for i in 3:
		Art.arc(ci, Vector2(-3 + i * 3.0, 0), 3.5, -0.9, 0.9, 5, Art.shade_of(col, 0.3), 1.1)
	_shine(ci, Vector2(2, -7), Vector2(4.5, 1.6), -0.1)
	Art.push(ci, Vector2(2, 6), 0.3 + sin(t * 4.0) * 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(-4, 8), Vector2(3, 2)]), Art.shade_of(col, 0.12), W2, 0.0)
	Art.pop(ci)
	_eye(ci, Vector2(9, -3), 2.6, blink, happy)
	_eye(ci, Vector2(16, -3), 2.6, blink, happy)
	_cheek(ci, Vector2(7.5, 2.5), 2.0)
	_cheek(ci, Vector2(18.5, 2), 1.6)
	var m := Vector2(13, 3.3)
	if happy:
		_mouth(ci, m, 2.6, true)
		for sx: float in [-1.0, 1.0]:
			Art.flat(ci, PackedVector2Array([m + Vector2(1.6 * sx - 0.9, -0.9), m + Vector2(1.6 * sx + 0.9, -0.9), m + Vector2(1.6 * sx, 0.6)]), Art.WHITE)
	else:
		Art.flat(ci, _smile(m + Vector2(0, -2), 2.8, 0.45, 1.0), Art.INK)
		for sx: float in [-1.0, 1.0]:
			Art.flat(ci, PackedVector2Array([m + Vector2(1.3 * sx - 0.8, 0.5), m + Vector2(1.3 * sx + 0.8, 0.5), m + Vector2(1.3 * sx, 1.8)]), Art.WHITE)
