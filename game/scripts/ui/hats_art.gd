class_name HatsArt
extends RefCounted
## Cosmetic hats for the avatar, drawn in the same head space as
## Chars._hat: head centered at the origin with radius 20, hats sitting
## over the top of the head (drawn after Chars.head with hat "none").
## Hoods (dino, frog, shark) are a cap over the head top with a face opening.

const IDS: Array[String] = ["cat_ears", "bunny_ears", "dino_hood", "unicorn", "party", "headphones", "flower_crown", "viking", "chef", "wizard", "frog", "shark_hood", "astronaut", "pumpkin"]

const W := 2.5


static func draw(ci: CanvasItem, id: String) -> void:
	match id:
		"cat_ears": _cat_ears(ci)
		"bunny_ears": _bunny_ears(ci)
		"dino_hood": _dino_hood(ci)
		"unicorn": _unicorn(ci)
		"party": _party(ci)
		"headphones": _headphones(ci)
		"flower_crown": _flower_crown(ci)
		"viking": _viking(ci)
		"chef": _chef(ci)
		"wizard": _wizard(ci)
		"frog": _frog(ci)
		"shark_hood": _shark_hood(ci)
		"astronaut": _astronaut(ci)
		"pumpkin": _pumpkin(ci)


# --- Shared bits ------------------------------------------------------------------------

## Thin headband over the top of the head.
static func _band(ci: CanvasItem, col: Color) -> void:
	Art.arc(ci, Vector2(0, 1), 23.0, PI + 0.32, TAU - 0.32, 20, Art.INK, 6.5)
	Art.arc(ci, Vector2(0, 1), 23.0, PI + 0.32, TAU - 0.32, 20, col, 3.5)


## Hood over the head top with a round face opening; side flaps come down
## past the ears.
static func _hood() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := deg_to_rad(150.0)
	var a1 := deg_to_rad(390.0)
	for i in 25:
		var a := lerpf(a0, a1, i / 24.0)
		pts.append(Vector2(0, -4) + Vector2(cos(a), sin(a)) * 26.0)
	pts.append(Vector2(18.5, 9))
	for i in 17:
		var a := TAU - PI * i / 16.0
		pts.append(Vector2(0, 2) + Vector2(cos(a) * 18.5, sin(a) * 14.0))
	pts.append(Vector2(-18.5, 9))
	return pts


## The face opening's edge (for trims and teeth).
static func _opening(i: float, n: float) -> Vector2:
	var a := TAU - PI * i / n
	return Vector2(0, 2) + Vector2(cos(a) * 18.5, sin(a) * 14.0)


static func _trim(ci: CanvasItem, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var p := _opening(i, 16.0)
		pts.append(p + (p - Vector2(0, 2)).normalized() * -1.8)
	Art.polyline(ci, pts, col, 3.4)


static func _tube(ctrl: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
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
	return left


static func _flower(ci: CanvasItem, c: Vector2, r: float, petal: Color) -> void:
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		Art.t_circle(ci, c + Vector2(cos(a), sin(a)) * r, r * 0.95, petal, 1.5, 0.0)
	Art.t_circle(ci, c, r * 0.7, Art.GOLD, 1.5, 0.0)
	Art.flat(ci, Art.circle_pts(c + Vector2(-r * 0.2, -r * 0.2), r * 0.25, 6), Color(1, 1, 1, 0.8))


static func _shine(ci: CanvasItem, c: Vector2, radii: Vector2, rot: float) -> void:
	Art.flat(ci, Art.ellipse_pts(c, radii, 12, rot), Color(1, 1, 1, 0.55))


# --- Hats --------------------------------------------------------------------------------

static func _cat_ears(ci: CanvasItem) -> void:
	var fur := Color("ff9f43")
	var inner := Color("ffc2d4")
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(sx, 1))
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-22, -11), Vector2(-21, -28), Vector2(-18, -37), Vector2(-12, -32), Vector2(-4, -21)]), 3), fur, W, 0.5)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-17.5, -16), Vector2(-17, -29), Vector2(-9.5, -22)]), 3), inner, 0.0, 0.0)
		Art.line(ci, Vector2(-15, -31), Vector2(-11, -34), Art.shade_of(fur, 0.3), 1.6)
		Art.pop(ci)
	_band(ci, Color("ff5d8f"))


static func _bunny_ears(ci: CanvasItem) -> void:
	var fur := Color("fffafc")
	var inner := Color("ffb8d0")
	Art.push(ci, Vector2(-9, -26), -0.18)
	Art.t_ellipse(ci, Vector2(0, -14), Vector2(6.5, 17), fur, W, 0.5)
	Art.t_ellipse(ci, Vector2(0, -13), Vector2(3.2, 12), inner, 0.0, 0.0)
	Art.pop(ci)
	# Right ear flops over halfway up.
	Art.push(ci, Vector2(9, -26), 0.2)
	Art.t_ellipse(ci, Vector2(0, -8), Vector2(6.5, 11), fur, W, 0.5)
	Art.t_ellipse(ci, Vector2(0, -7), Vector2(3.2, 7), inner, 0.0, 0.0)
	Art.push(ci, Vector2(1, -15), 1.25)
	Art.t_ellipse(ci, Vector2(0, -8), Vector2(6, 10), fur, W, 0.3)
	Art.t_ellipse(ci, Vector2(0, -7), Vector2(2.8, 6), inner, 0.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)
	_band(ci, Color("ff8fc0"))
	Art.t_circle(ci, Vector2(-15, -17), 3.2, Art.WHITE, 1.5, 0.0)


static func _dino_hood(ci: CanvasItem) -> void:
	var green := Color("6fd46b")
	var spike := Color("ffb33c")
	for s: Vector3 in [Vector3(-17, -22, -0.75), Vector3(-6, -30, -0.22), Vector3(6, -30, 0.22), Vector3(17, -22, 0.75)]:
		Art.push(ci, Vector2(s.x, s.y), s.z)
		Art.toon(ci, PackedVector2Array([Vector2(-6, 3), Vector2(0, -10), Vector2(6, 3)]), spike, W, 0.0)
		Art.pop(ci)
	Art.toon(ci, _hood(), green, W, 0.5)
	for p: Vector3 in [Vector3(-20, -8, 2.4), Vector3(-15, -20, 1.8), Vector3(21, -3, 1.8), Vector3(15, -21, 2.4)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), Art.shade_of(green, 0.25))
	_trim(ci, Color("fff09a"))
	# Little teeth along the opening.
	for i: float in [5.0, 8.0, 11.0]:
		var p := _opening(i, 16.0)
		Art.toon(ci, PackedVector2Array([p + Vector2(-2.2, -0.8), p + Vector2(2.2, -0.8), p + Vector2(0, 2.8)]), Art.WHITE, 1.1, 0.0)
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(8 * sx, -20)
		Art.t_ellipse(ci, e, Vector2(3.4, 3.8), Art.WHITE, 1.6, 0.0)
		Art.flat(ci, Art.circle_pts(e + Vector2(0.5, 0.6), 2.0, 10), Art.INK)
		Art.flat(ci, Art.circle_pts(e + Vector2(1.1, -0.2), 0.7, 6), Art.WHITE)
	_shine(ci, Vector2(-10, -25), Vector2(5, 2), -0.5)


static func _unicorn(ci: CanvasItem) -> void:
	var fur := Color("fff6fb")
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(15 * sx, -18), 0.45 * sx)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-5, 2), Vector2(-3, -9), Vector2(0, -13), Vector2(3, -9), Vector2(5, 2)]), 3), fur, W, 0.3)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-2.5, 1), Vector2(0, -8), Vector2(2.5, 1)]), 3), Color("ffb8d0"), 0.0, 0.0)
		Art.pop(ci)
	# Pastel mane curls.
	var manes := [Color("ff9fd6"), Color("b89cff"), Color("8fd8ff")]
	for i in 3:
		Art.t_circle(ci, Vector2(-7 + i * 6.5, -24 - (3.0 if i == 1 else 0.0)), 5.5, manes[i], 2.0, 0.3)
	# Spiral horn.
	var horn := Art.smooth_pts(PackedVector2Array([Vector2(-6.5, -23), Vector2(6.5, -23), Vector2(3, -40), Vector2(1, -55), Vector2(-1, -40)]), 3)
	Art.toon(ci, horn, Color("ffe89a"), W, 0.5)
	for i in 4:
		var y := -27.0 - i * 6.5
		var hw := lerpf(5.5, 1.8, i / 3.0)
		Art.line(ci, Vector2(-hw, y + 1.5), Vector2(hw, y - 1.5), Color("ffb347"), 1.6)
	_shine(ci, Vector2(-1.5, -36), Vector2(1.2, 5), 0.1)
	_band(ci, Color("ff9fd6"))
	_flower(ci, Vector2(-16, -16), 2.8, Color("ffd1e6"))


static func _party(ci: CanvasItem) -> void:
	Art.push(ci, Vector2(0, -17), 0.18)
	var cone := PackedVector2Array([Vector2(-13, 1), Vector2(13, 1), Vector2(1, -35)])
	Art.toon(ci, cone, Color("ff6fae"), W, 0.4)
	for i in 3:
		var y := -6.0 - i * 9.5
		var band := PackedVector2Array([Vector2(-20, y), Vector2(20, y - 5), Vector2(20, y - 1), Vector2(-20, y + 4)])
		Art.flat(ci, Art.clipped(band, cone), Color("ffd23f"))
	for p: Vector2 in [Vector2(-5, -8), Vector2(5, -15), Vector2(-1, -22), Vector2(6, -3)]:
		Art.flat(ci, Art.circle_pts(p, 1.4, 8), Color("3aa6f0"))
	Art.toon(ci, Art.union([Art.circle_pts(Vector2(1, -37), 4.5, 14), Art.circle_pts(Vector2(-3, -39), 3.2, 12),
			Art.circle_pts(Vector2(5, -39.5), 3.2, 12), Art.circle_pts(Vector2(1, -42), 3.2, 12)]), Color("fff27a"), 2.2, 0.3)
	var ruff := []
	for i in 7:
		ruff.append(Art.circle_pts(Vector2(-13 + i * 4.33, 1), 3.0, 12))
	Art.toon(ci, Art.union(ruff), Art.WHITE, 2.2, 0.3)
	Art.pop(ci)


static func _headphones(ci: CanvasItem) -> void:
	var col := Color("7b6cff")
	Art.arc(ci, Vector2(0, 0), 25.0, PI + 0.12, TAU - 0.12, 24, Art.INK, 9.5)
	Art.arc(ci, Vector2(0, 0), 25.0, PI + 0.12, TAU - 0.12, 24, col, 5.0)
	Art.arc(ci, Vector2(0, 0), 25.5, PI + 0.9, PI + 1.6, 8, Color(1, 1, 1, 0.5), 1.8)
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(22 * sx, 1), 0.0, Vector2(sx, 1))
		Art.t_rect(ci, Rect2(-3, -9, 5, 19), 2, Color("3a3f5c"), 2.2, 0.0)
		Art.t_rect(ci, Rect2(0, -11, 9, 23), 4.5, col, W, 0.5)
		Art.t_circle(ci, Vector2(4.5, 0.5), 2.6, Color("ff8fc0"), 1.4, 0.0)
		Art.pop(ci)


static func _flower_crown(ci: CanvasItem) -> void:
	var vine := PackedVector2Array()
	for i in 17:
		var a := PI + 0.15 + (PI - 0.3) * i / 16.0
		vine.append(Vector2(0, -7) + Vector2(cos(a) * 22.0, sin(a) * 12.0))
	Art.polyline(ci, vine, Art.INK, 5.0)
	Art.polyline(ci, vine, Color("4fbf5a"), 2.4)
	for i in [2, 6, 10, 14]:
		var p := vine[i]
		Art.t_ellipse(ci, p + Vector2(0, -2.5), Vector2(3.6, 2), Art.GREEN, 1.4, 0.0, 0.5 if i < 8 else -0.5)
	var cols := [Color("ff8fc0"), Color("fff27a"), Color("ffffff"), Color("b89cff"), Color("ff9f6e")]
	for k in 5:
		var i := 1 + k * 3 + (1 if k > 1 else 0)
		_flower(ci, vine[mini(i, 16)], 3.9 if k == 2 else 3.3, cols[k])


static func _viking(ci: CanvasItem) -> void:
	var horn := Color("fff2d6")
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(sx, 1))
		var h := _tube(PackedVector2Array([Vector2(-15, -16), Vector2(-26, -21), Vector2(-33, -31), Vector2(-33, -44)]), 11.0, 2.0)
		Art.toon(ci, h, horn, W, 0.4)
		for p: Array in [[Vector2(-27, -19), Vector2(-24, -27)], [Vector2(-33, -27), Vector2(-28, -32)]]:
			Art.line(ci, p[0], p[1], Color("e2c79c"), 1.6)
		Art.pop(ci)
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(Vector2(cos(a) * 22.0, -10.0 + sin(a) * 19.0))
	Art.toon(ci, dome, Color("b8c4d6"), W, 0.6)
	Art.t_rect(ci, Rect2(-3, -29, 6, 18), 2, Art.BRASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-24, -15, 48, 8), 3, Art.BRASS, W, 0.0)
	for x: float in [-17.0, -9.0, 9.0, 17.0]:
		Art.flat(ci, Art.circle_pts(Vector2(x, -11), 1.5, 8), Color("9a5f1a"))
	_shine(ci, Vector2(-10, -22), Vector2(5, 2.2), -0.5)


static func _chef(ci: CanvasItem) -> void:
	var puff := Art.union([Art.circle_pts(Vector2(-11, -37), 10.0, 20), Art.circle_pts(Vector2(0, -44), 12.0, 22),
			Art.circle_pts(Vector2(11, -37), 10.0, 20), Art.rrect_pts(Rect2(-15, -38, 30, 14), 3)])
	Art.toon(ci, puff, Art.WHITE, W, 0.5)
	Art.arc(ci, Vector2(-6, -38), 6.0, PI + 0.6, TAU - 0.4, 8, Color("d6dbe6"), 1.6)
	Art.arc(ci, Vector2(6, -44), 7.0, PI + 0.4, TAU - 0.6, 8, Color("d6dbe6"), 1.6)
	Art.t_rect(ci, Rect2(-17, -27, 34, 12), 3, Art.WHITE, W, 0.3)
	for x: float in [-9.0, -3.0, 3.0, 9.0]:
		Art.line(ci, Vector2(x, -25), Vector2(x, -17), Color("d6dbe6"), 1.4)


static func _wizard(ci: CanvasItem) -> void:
	var col := Color("6a4fd8")
	var cone := Art.smooth_pts(PackedVector2Array([Vector2(-14, -18), Vector2(-6, -36), Vector2(0, -47), Vector2(10, -55), Vector2(19, -56),
			Vector2(13, -50), Vector2(8, -42), Vector2(11, -30), Vector2(14, -18)]), 3)
	Art.toon(ci, cone, col, W, 0.5)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-20, -25, 40, 5), 1), cone), Art.GOLD)
	Art.toon(ci, Art.star_pts(Vector2(-2, -34), 4.5, 1.9, 5), Art.GOLD, 1.4, 0.0)
	Art.toon(ci, Art.star_pts(Vector2(5, -44), 3.0, 1.3, 5), Art.GOLD, 1.2, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(7, -30), 1.3, 6), Color("fff27a"))
	Art.toon(ci, Art.star_pts(Vector2(19.5, -56), 4.0, 1.8, 5), Color("fff27a"), 1.4, 0.0)
	Art.t_ellipse(ci, Vector2(0, -17), Vector2(28, 6), Art.shade_of(col, 0.12), W, 0.3)
	Art.flat(ci, Art.ellipse_pts(Vector2(-10, -19), Vector2(8, 1.4), 10), Color(1, 1, 1, 0.3))


static func _frog(ci: CanvasItem) -> void:
	var green := Color("7ed957")
	Art.toon(ci, _hood(), green, W, 0.5)
	_trim(ci, Color("c8f5a0"))
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(10 * sx, -27)
		Art.t_circle(ci, e, 8.0, green, W, 0.4)
		Art.t_circle(ci, e + Vector2(0, 0.5), 5.2, Art.WHITE, 1.4, 0.0)
		Art.flat(ci, Art.ellipse_pts(e + Vector2(0.6, 1.0), Vector2(2.6, 3.0), 10), Art.INK)
		Art.flat(ci, Art.circle_pts(e + Vector2(1.4, -0.4), 1.0, 6), Art.WHITE)
		Art.flat(ci, Art.ellipse_pts(Vector2(18 * sx, -14), Vector2(3, 2), 10), Color(1.0, 0.45, 0.55, 0.55))
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(3 * sx, -17), Vector2(1.1, 0.8), 8), Art.shade_of(green, 0.45))


static func _shark_hood(ci: CanvasItem) -> void:
	var col := Color("7d9dc8")
	Art.toon(ci, PackedVector2Array([Vector2(-9, -25), Vector2(3, -46), Vector2(7, -46), Vector2(6, -38), Vector2(11, -25)]), Art.shade_of(col, 0.1), W, 0.3)
	Art.toon(ci, _hood(), col, W, 0.5)
	_trim(ci, Art.WHITE)
	for i: float in [3.0, 5.5, 8.0, 10.5, 13.0]:
		var p := _opening(i, 16.0)
		Art.toon(ci, PackedVector2Array([p + Vector2(-2.0, -0.8), p + Vector2(2.0, -0.8), p + Vector2(0, 2.6)]), Art.WHITE, 1.1, 0.0)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var c := Vector2(21.5 * sx - 2.6 * k * sx, -1.0 + k * 0.5)
			Art.arc(ci, c, 3.5, PI - 0.9 if sx < 0 else -0.9, PI + 0.9 if sx < 0 else 0.9, 5, Art.shade_of(col, 0.3), 1.3)
		var e := Vector2(13 * sx, -21)
		Art.flat(ci, Art.ellipse_pts(e, Vector2(2.3, 2.7), 10), Art.INK)
		Art.flat(ci, Art.circle_pts(e + Vector2(0.6, -0.8), 0.8, 6), Art.WHITE)
	_shine(ci, Vector2(-9, -25), Vector2(5, 2), -0.4)


static func _astronaut(ci: CanvasItem) -> void:
	Art.stroke(ci, PackedVector2Array([Vector2(15, -24), Vector2(21, -38)]), Art.METAL, 2.5, 2.0)
	Art.t_circle(ci, Vector2(21.5, -39.5), 3.4, Art.RED, 1.8, 0.0)
	Art.t_rect(ci, Rect2(-23, 20, 46, 10), 4, Color("e8edf5"), W, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-20, 23.5, 40, 3), 1.5), Art.BLUE)
	Art.flat(ci, Art.circle_pts(Vector2(0, -1), 29.0, 44), Color(0.72, 0.92, 1.0, 0.22))
	Art.ring(ci, Art.circle_pts(Vector2(0, -1), 29.0, 44), Art.INK, 7.0)
	Art.ring(ci, Art.circle_pts(Vector2(0, -1), 29.0, 44), Color("f2f6ff"), 3.5)
	Art.arc(ci, Vector2(0, -1), 23.5, PI + 0.35, PI + 1.25, 10, Color(1, 1, 1, 0.8), 4.0)
	Art.flat(ci, Art.circle_pts(Vector2(-6, -24), 1.8, 8), Color(1, 1, 1, 0.9))
	Art.arc(ci, Vector2(0, -1), 24.0, 0.3, 0.9, 6, Color(1, 1, 1, 0.45), 2.5)
	Art.t_rect(ci, Rect2(-31, -6, 5, 9), 2, Color("ffd23f"), 1.8, 0.0)


static func _pumpkin(ci: CanvasItem) -> void:
	var col := Color("ff8c1a")
	# Worn low so it hugs the top of the head.
	Art.push(ci, Vector2(0, 7), 0.0, Vector2(1.12, 1.05))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-2.5, -38), Vector2(2.5, -38), Vector2(2.5, -45), Vector2(5.5, -49),
			Vector2(3, -51), Vector2(-1.5, -46)]), 2), Color("7a5230"), 2.0, 0.0)
	Art.t_ellipse(ci, Vector2(8, -46), Vector2(5.5, 3), Art.GREEN, 2.0, 0.0, -0.4)
	var body := Art.union([Art.ellipse_pts(Vector2(-10, -29), Vector2(11, 11.5), 24), Art.ellipse_pts(Vector2(10, -29), Vector2(11, 11.5), 24),
			Art.ellipse_pts(Vector2(0, -30), Vector2(11, 12.5), 24)])
	Art.toon(ci, body, col, W, 0.6)
	for sx: float in [-1.0, 1.0]:
		Art.polyline(ci, PackedVector2Array([Vector2(4 * sx, -40), Vector2(6.5 * sx, -30), Vector2(4.5 * sx, -19)]), Art.shade_of(col, 0.25), 1.8)
	# Glowing jack-o'-lantern face.
	var glow := Color("ffe066")
	for sx: float in [-1.0, 1.0]:
		Art.toon(ci, PackedVector2Array([Vector2(8 * sx - 3, -30), Vector2(8 * sx + 3, -30), Vector2(8 * sx, -35)]), glow, 1.5, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-8, -25), Vector2(-4, -24), Vector2(-2, -26), Vector2(0, -24), Vector2(2, -26), Vector2(4, -24),
			Vector2(8, -25), Vector2(4, -21), Vector2(-4, -21)]), glow, 1.5, 0.0)
	_shine(ci, Vector2(-12, -35), Vector2(3.5, 2), -0.6)
	Art.pop(ci)
