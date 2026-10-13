class_name TileJungle
extends RefCounted
## The Jungle Ruins match-3 set (TileWorlds world 4): the six pieces, the
## jungle specials (dragonfly line-clearers, a temple stone bomb, the sun
## disc) and the blockers (carved temple stone, a vine net).
##
## Same rules as TileArt: centered at (0,0), fit a 56x56 cell, every kind has
## its own color AND silhouette (kids, small phone cells):
##   0 banana bunch (lemon yellow, three crescents)
##   1 parrot (blue macaw head with a big hooked beak)
##   2 hibiscus (hot pink five-lobed flower with a long stamen)
##   3 coconut (brown ball with three "eyes" and a green sprout)
##   4 golden idol mask (orange gold, stepped crown, turquoise eyes)
##   5 tiger's-eye gem (emerald, faceted, a gold cat's-eye band that slides)
## Animated values are stepped (snappedf) or done with push/pop so the shape
## caches stay small; the board caches each piece per animation step.

const _W := 3.0
const LEAF := Color("3fbf4a")
const LEAF_DARK := Color("23863a")
const TURQ := Color("3fe0d0")
const GOLD := Color("ffc93c")
const STONE := Color("d9bb7c")
const STONE_DARK := Color("a8844a")


static func piece(ci: CanvasItem, slot: int, t: float, col: Color) -> void:
	_shadow(ci)
	match slot:
		0: _banana(ci, t, col)
		1: _parrot(ci, t, col)
		2: _hibiscus(ci, t, col)
		3: _coconut(ci, t, col)
		4: _idol(ci, t, col)
		5: _gem(ci, t, col)


# --- Shared bits -------------------------------------------------------------------------

## A soft contact shadow under every piece: the pieces sit ON the board.
static func _shadow(ci: CanvasItem) -> void:
	Art.flat(ci, Art.ellipse_pts(Vector2(1, 22), Vector2(19, 5), 18), Color(0.04, 0.12, 0.08, 0.28))


static func _shine(ci: CanvasItem, c: Vector2, radii: Vector2, rot: float, a: float = 0.85) -> void:
	Art.flat(ci, Art.ellipse_pts(c, radii, 14, rot), Color(1, 1, 1, a))


static func _twinkle(ci: CanvasItem, pos: Vector2, size: float, t: float, phase: float) -> void:
	var s := snappedf(maxf(0.0, sin(t * 2.6 + phase)), 0.1)
	if s < 0.1:
		return
	Art.push(ci, pos, 0.0, Vector2(s, s) * size)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 1.0, 0.24, 4), Color(1, 1, 1, 0.95))
	Art.pop(ci)


## Quadratic bezier.
static func _qb(a: Vector2, b: Vector2, c: Vector2, f: float) -> Vector2:
	return a.lerp(b, f).lerp(b.lerp(c, f), f)


## A crescent along the curve a-b-c, `w` thick in the middle.
static func _crescent(a: Vector2, b: Vector2, c: Vector2, w: float, n: int = 12, end_w: float = 0.8) -> PackedVector2Array:
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var p := _qb(a, b, c, f)
		var d := (_qb(a, b, c, minf(1.0, f + 0.02)) - _qb(a, b, c, maxf(0.0, f - 0.02))).normalized().orthogonal()
		var hw := end_w + w * 0.5 * pow(sin(PI * f), 0.75)
		l.append(p + d * hw)
		r.append(p - d * hw)
	r.reverse()
	l.append_array(r)
	return l


## A pointed leaf from `base` along `dir` (radians), `len` long.
static func leaf_pts(len: float, width: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var f := float(i) / n
		pts.append(Vector2(f * len, -sin(PI * f) * width * (1.0 - 0.35 * f)))
	for i in range(n - 1, 0, -1):
		var f := float(i) / n
		pts.append(Vector2(f * len, sin(PI * f) * width * (1.0 - 0.35 * f) * 0.85))
	return pts


static func leaf(ci: CanvasItem, at: Vector2, rot: float, len: float, width: float, col: Color, w: float = 2.2) -> void:
	Art.push(ci, at, rot)
	Art.toon(ci, leaf_pts(len, width), col, w, 0.5)
	Art.line(ci, Vector2(len * 0.08, 0), Vector2(len * 0.82, -width * 0.08), Art.shade_of(col, 0.3), maxf(1.0, w * 0.55))
	Art.pop(ci)


# --- 0 Banana bunch -------------------------------------------------------------------------

static func _banana(ci: CanvasItem, t: float, col: Color) -> void:
	var sway := snappedf(sin(t * 1.6), 0.25) * 0.05
	Art.push(ci, Vector2(0, -20), sway)
	var tip := Color("5a3a1a")
	var ridge := col.lightened(0.45)
	# Back two bananas, then the front one; each from the crown down.
	for k: int in [0, 2, 1]:
		var rot: float = [-0.62, 0.0, 0.62][k]
		var len: float = [36.0, 42.0, 36.0][k]
		Art.push(ci, Vector2.ZERO, rot)
		var a := Vector2(0, 2)
		var b := Vector2(-15, len * 0.48)
		var c := Vector2(3, len)
		var body := _crescent(a, b, c, 13.0 if k == 1 else 12.0)
		var shade_col := col if k == 1 else col.darkened(0.06)
		Art.toon(ci, body, shade_col, _W, 0.55)
		# The ridge along the banana, its green-brown tips.
		var rp := PackedVector2Array()
		for i in 7:
			var f := 0.18 + 0.62 * i / 6.0
			rp.append(_qb(a, b, c, f) + Vector2(-2.6, 0))
		Art.polyline(ci, rp, Color(ridge, 0.75), 2.2)
		Art.flat(ci, Art.circle_pts(c + Vector2(-0.4, -0.6), 2.4, 10), tip)
		if k == 1:
			_shine(ci, _qb(a, b, c, 0.42) + Vector2(-3.5, 0), Vector2(1.8, 6.5), 0.25, 0.8)
		Art.pop(ci)
	# The crown where they meet: a green-brown stalk.
	Art.toon(ci, Art.rrect_pts(Rect2(-5.5, -7, 11, 11), 3.5), Color("8aa83a"), 2.6, 0.4)
	Art.toon(ci, Art.rrect_pts(Rect2(-3, -12, 6, 7), 2.0), Color("6a7a2a"), 2.2, 0.2)
	Art.pop(ci)
	_twinkle(ci, Vector2(14, 6), 5.0, t, 0.4)


# --- 1 Parrot (blue macaw) ------------------------------------------------------------------

static func _parrot(ci: CanvasItem, t: float, col: Color) -> void:
	var bob := snappedf(sin(t * 2.2), 0.25)
	Art.push(ci, Vector2(-1, 2 + bob * 0.8), bob * 0.06)
	var dark := Color("1f62c8")
	var yellow := Color("ffd23a")
	# Crest feathers.
	for k in 3:
		Art.push(ci, Vector2(-5 + k * 4.0, -15), -0.9 + k * 0.32)
		Art.toon(ci, leaf_pts(13.0 - k * 1.5, 4.2), col.lightened(0.08 * k), 2.2, 0.3)
		Art.pop(ci)
	# Wing behind (dark blue with green-tipped feathers).
	Art.push(ci, Vector2(-12, 10), 2.3)
	Art.toon(ci, leaf_pts(18.0, 8.0), dark, 2.4, 0.3)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(16, 0), 6.0, 12), leaf_pts(18.0, 8.0)), Color("3ad08a"))
	Art.pop(ci)
	# Head.
	var head := Art.ellipse_pts(Vector2(-2, 0), Vector2(18, 19), 34)
	Art.toon(ci, head, col, _W, 0.6)
	# Yellow chest at the bottom.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-4, 20), Vector2(16, 10), 22), head), yellow)
	# White face patch with little feather stripes.
	var face := Art.ellipse_pts(Vector2(5, -1), Vector2(9.5, 8.5), 22, -0.2)
	Art.flat(ci, face, Color("f6fbff"))
	for i in 3:
		Art.line(ci, Vector2(1 + i * 2.6, 4.5 + i * 0.4), Vector2(3 + i * 2.6, 6.5), Color("4a5a80"), 1.0)
	# Eye (blinks).
	var blink := fposmod(t + 0.7, 3.3) < 0.13
	if blink:
		Art.arc(ci, Vector2(4.5, -3), 3.5, 0.2, PI - 0.2, 8, Art.INK, 2.0)
	else:
		Art.t_circle(ci, Vector2(4.5, -3), 4.4, Color("fff4c8"), 1.8, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(5.2, -2.6), 2.6, 12), Art.INK)
		Art.flat(ci, Art.circle_pts(Vector2(4.4, -3.8), 1.0, 8), Art.WHITE)
	# Big hooked beak.
	var upper := Art.smooth_pts(PackedVector2Array([Vector2(10, -6), Vector2(18, -8), Vector2(25, -2), Vector2(24, 8), Vector2(20, 5), Vector2(15, 2), Vector2(10, 2)]), 3)
	Art.toon(ci, upper, Color("3a3448"), 2.6, 0.4)
	var lower := Art.smooth_pts(PackedVector2Array([Vector2(10, 2), Vector2(17, 3), Vector2(19, 8), Vector2(12, 9)]), 2)
	Art.toon(ci, lower, Color("2a2436"), 2.2, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(16, -4.5), Vector2(4, 1.4), 10, -0.2), Color(1, 1, 1, 0.45))
	# Rosy cheek and the gloss on the head.
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, 6), Vector2(3.2, 2.0), 10), Color(1.0, 0.55, 0.6, 0.55))
	_shine(ci, Vector2(-10, -9), Vector2(5, 3), -0.7, 0.7)
	Art.pop(ci)


# --- 2 Hibiscus -------------------------------------------------------------------------------

static func _flower_pts(r0: float, r1: float, ruffle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 90
	for i in n:
		var a := TAU * i / n - PI / 2.0
		var lobe := pow(absf(cos(2.5 * (a + PI / 2.0))), 0.55)
		var r := r0 + (r1 - r0) * lobe + ruffle * sin(a * 30.0) * lobe
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _hibiscus(ci: CanvasItem, t: float, col: Color) -> void:
	var g := 1.0 + snappedf(sin(t * 2.0), 0.25) * 0.035
	Art.push(ci, Vector2(0, 1), 0.3 + snappedf(sin(t * 0.9), 0.25) * 0.06, Vector2(g, g))
	var petals := _flower_pts(11.0, 25.0, 0.9)
	Art.toon(ci, petals, col, _W, 0.5)
	# The deep red heart and veins to each petal.
	Art.flat(ci, _flower_pts(5.0, 10.0, 0.0), Color("b0103e"))
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		Art.line(ci, Vector2(cos(a), sin(a)) * 6.0, Vector2(cos(a), sin(a)) * 18.0, Art.shade_of(col, 0.28), 1.6)
		Art.flat(ci, Art.ellipse_pts(Vector2(cos(a - 0.35), sin(a - 0.35)) * 15.0, Vector2(4.2, 1.8), 10, a - 0.35 + PI / 2.0), Color(1, 1, 1, 0.3))
	# The long stamen with its yellow pollen.
	Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(6, -8), Vector2(11, -17)]), Color("ffe08a"), 2.6, 1.6)
	for p: Vector2 in [Vector2(11, -18), Vector2(14, -16), Vector2(9, -20.5), Vector2(13.5, -20)]:
		Art.t_circle(ci, p, 1.9, Color("ffd23a"), 1.2, 0.0)
	Art.t_circle(ci, Vector2(10.5, -16), 1.6, Color("ff3a4a"), 1.0, 0.0)
	Art.pop(ci)
	_twinkle(ci, Vector2(-15, -12), 5.0, t, 1.9)


# --- 3 Coconut --------------------------------------------------------------------------------

static func _coconut(ci: CanvasItem, t: float, col: Color) -> void:
	var wob := snappedf(sin(t * 1.8), 0.25) * 0.07
	Art.push(ci, Vector2(0, 20), wob)
	Art.push(ci, Vector2(0, -20))
	# A sprout of two palm leaves on top.
	leaf(ci, Vector2(1, -17), -2.3, 16.0, 5.0, LEAF, 2.2)
	leaf(ci, Vector2(1, -17), -0.75, 18.0, 5.5, Color("54d05a"), 2.2)
	var body := Art.ellipse_pts(Vector2(0, 3), Vector2(20, 19), 36)
	Art.toon(ci, body, col, _W, 0.65)
	# Hairy fibres.
	var fib := col.lightened(0.28)
	for p: Vector3 in [Vector3(-12, -4, 0.5), Vector3(-6, 12, -0.4), Vector3(9, 13, 0.6), Vector3(13, 0, -0.5), Vector3(-14, 7, 0.9), Vector3(2, 17, 0.2), Vector3(-9, -10, -0.6)]:
		Art.push(ci, Vector2(p.x, p.y), p.z)
		Art.line(ci, Vector2(-3, 0), Vector2(3, 0), fib, 1.4)
		Art.line(ci, Vector2(-2, 2), Vector2(2.5, 2), Color(fib, 0.6), 1.2)
		Art.pop(ci)
	# The three dark "eyes" (look like a surprised little face).
	for p: Vector2 in [Vector2(-5, -6), Vector2(5, -6), Vector2(0, 2)]:
		Art.flat(ci, Art.ellipse_pts(p, Vector2(2.8, 3.2), 12), Color("3a2210"))
		Art.flat(ci, Art.circle_pts(p + Vector2(-0.8, -1.0), 0.9, 6), Color(1, 1, 1, 0.5))
	_shine(ci, Vector2(-9, -8), Vector2(5.5, 3.2), -0.7, 0.55)
	Art.pop(ci)
	Art.pop(ci)


# --- 4 Golden idol mask -----------------------------------------------------------------------

static func _idol(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, 1), snappedf(sin(t * 1.3), 0.25) * 0.04)
	var dark := Art.shade_of(col, 0.34)
	# Stepped crown (like the temple pyramid).
	var crown := PackedVector2Array([Vector2(-21, -8), Vector2(-21, -14), Vector2(-15, -14), Vector2(-15, -20), Vector2(-8, -20), Vector2(-8, -26),
			Vector2(8, -26), Vector2(8, -20), Vector2(15, -20), Vector2(15, -14), Vector2(21, -14), Vector2(21, -8)])
	Art.toon(ci, crown, col.darkened(0.08), 2.6, 0.4)
	# Ear plugs.
	for sx: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(21 * sx, 3), 5.0, col, 2.4, 0.4)
		Art.t_circle(ci, Vector2(21 * sx, 3), 2.4, TURQ, 1.4, 0.0)
	# Face.
	var face := Art.smooth_pts(PackedVector2Array([Vector2(-19, -12), Vector2(19, -12), Vector2(19, 8), Vector2(12, 21), Vector2(-12, 21), Vector2(-19, 8)]), 2)
	Art.toon(ci, face, col, _W, 0.6)
	# Brow band with a turquoise gem.
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-22, -12, 44, 5), 1.0), face), dark)
	Art.toon(ci, PackedVector2Array([Vector2(0, -18), Vector2(4, -13), Vector2(0, -8), Vector2(-4, -13)]), TURQ, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-1, -16), Vector2(0.6, -14.5), Vector2(-1.8, -13)]), Color(1, 1, 1, 0.8))
	# Eyes: carved slots with glowing turquoise pupils.
	var glow := snappedf(0.5 + 0.5 * sin(t * 2.4), 0.25)
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(8 * sx, -2)
		Art.toon(ci, Art.ellipse_pts(e, Vector2(5.6, 3.4), 14), Color("4a2a0a"), 1.8, 0.0)
		Art.flat(ci, Art.circle_pts(e, 3.4 + glow * 1.6, 12), Color(TURQ, 0.25 + 0.2 * glow))
		Art.flat(ci, Art.circle_pts(e, 2.2, 10), TURQ.lightened(0.3 * glow))
	# Nose ridge and a grinning mouth with teeth.
	Art.flat(ci, PackedVector2Array([Vector2(-2, -1), Vector2(2, -1), Vector2(4, 8), Vector2(-4, 8)]), col.lightened(0.18))
	Art.line(ci, Vector2(-4, 8), Vector2(4, 8), dark, 1.6)
	Art.t_rect(ci, Rect2(-9, 11, 18, 6), 2.5, Color("4a2a0a"), 1.8, 0.0)
	for i in 4:
		Art.flat(ci, Art.rrect_pts(Rect2(-7.5 + i * 4.0, 11.5, 3.0, 2.6), 0.8), Color("fff3c8"))
	# Engraved cheek marks.
	for sx: float in [-1.0, 1.0]:
		Art.polyline(ci, PackedVector2Array([Vector2(14 * sx, 4), Vector2(11 * sx, 7), Vector2(14 * sx, 10)]), dark, 1.6)
	_shine(ci, Vector2(-11, -6), Vector2(2.4, 5), 0.3, 0.7)
	Art.pop(ci)
	_twinkle(ci, Vector2(-14, -20), 6.0, t, 2.2)


# --- 5 Tiger's-eye gem ------------------------------------------------------------------------

static func _gem(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, snappedf(sin(t * 2.0), 0.25) * 1.2))
	# An upright hexagon cut, flat top table.
	var gem := PackedVector2Array([Vector2(-10, -23), Vector2(10, -23), Vector2(20, -9), Vector2(20, 9), Vector2(10, 23), Vector2(-10, 23), Vector2(-20, 9), Vector2(-20, -9)])
	Art.toon(ci, gem, col, _W, 0.5)
	var table := PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(12, -5), Vector2(12, 5), Vector2(7, 14), Vector2(-7, 14), Vector2(-12, 5), Vector2(-12, -5)])
	Art.flat(ci, table, col.lightened(0.12))
	# Facet lines from the table to the rim.
	var fc := Art.shade_of(col, 0.3)
	for i in gem.size():
		Art.line(ci, table[i], gem[i], Color(fc, 0.8), 1.4)
	Art.flat(ci, PackedVector2Array([gem[2], gem[3], table[3], table[2]]), Color(fc, 0.35))
	Art.flat(ci, PackedVector2Array([gem[4], gem[5], table[5], table[4]]), Color(fc, 0.45))
	# The gold cat's-eye band: slides across the stone as the light moves.
	var slide := snappedf(sin(t * 1.4), 0.125) * 5.0
	var band := PackedVector2Array([Vector2(slide - 2.6, -14), Vector2(slide + 2.6, -14), Vector2(slide + 3.4, 0), Vector2(slide + 2.6, 14),
			Vector2(slide - 2.6, 14), Vector2(slide - 3.4, 0)])
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(slide, 0), Vector2(8.0, 15.0), 18), table), Color(1.0, 0.85, 0.3, 0.35))
	Art.flat(ci, Art.clipped(band, table), Color("ffe27a"))
	Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(slide - 0.8, -12), Vector2(slide + 0.8, -12), Vector2(slide + 0.8, 12), Vector2(slide - 0.8, 12)]), table), Color(1, 1, 0.9, 0.95))
	_shine(ci, Vector2(-6, -10), Vector2(3.5, 2), -0.6, 0.85)
	Art.pop(ci)
	_twinkle(ci, Vector2(14, -16), 6.0, t, 0.9)


# --- Specials ---------------------------------------------------------------------------------

## "rocket_h"/"rocket_v": a zooming dragonfly; "bomb": a carved temple stone
## ball with a fizzing vine fuse; "rainbow": the turning golden sun disc.
static func special(ci: CanvasItem, kind: String, t: float) -> void:
	match kind:
		"rocket_h":
			_dragonfly(ci, t, 0.0)
		"rocket_v":
			_dragonfly(ci, t, -PI / 2.0)
		"bomb":
			_stone_bomb(ci, t)
		"rainbow":
			_sun_disc(ci, t)


static func _dragonfly(ci: CanvasItem, t: float, rot: float) -> void:
	Art.push(ci, Vector2.ZERO, rot)
	# The line it clears: a bright green streak.
	Art.flat(ci, Art.rrect_pts(Rect2(-28, -6, 56, 12), 6), Color(0.7, 1.0, 0.6, 0.28))
	Art.flat(ci, Art.rrect_pts(Rect2(-28, -2.5, 56, 5), 2.5), Color(1, 1, 0.8, 0.6))
	Art.push(ci, Vector2(snappedf(sin(t * 9.0), 0.25) * 1.0, 0), 0.0, Vector2(1.1, 1.1))
	# Wings flutter (two steps).
	var up := int(t * 14.0) % 2 == 0
	var wing := Color(0.85, 1.0, 1.0, 0.75)
	for sy: float in [-1.0, 1.0]:
		for k in 2:
			Art.push(ci, Vector2(2 - k * 6.0, 0), sy * (PI / 2.0 - (0.35 if up else 0.6)) + (0.0 if k == 0 else sy * -0.55))
			Art.toon(ci, Art.ellipse_pts(Vector2(10, 0), Vector2(10.5, 3.6), 16), wing, 1.8, 0.0)
			Art.line(ci, Vector2(2, 0), Vector2(17, 0), Color(0.3, 0.6, 0.7, 0.6), 1.0)
			Art.pop(ci)
	# Long segmented tail, thorax and the big-eyed head.
	Art.toon(ci, TileArt._capsule(Vector2(-22, 0), Vector2(-2, 0), 3.0), Color("1fb8a8"), 2.2, 0.0)
	for i in 3:
		Art.line(ci, Vector2(-18 + i * 5.0, -2.6), Vector2(-18 + i * 5.0, 2.6), Color("0e6a62"), 1.2)
	Art.t_ellipse(ci, Vector2(3, 0), Vector2(7, 5.2), Color("2fd2c0"), 2.4, 0.5)
	for sy: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(11, 3.6 * sy), 4.0, Color("ffd23a"), 2.0, 0.3)
		Art.flat(ci, Art.circle_pts(Vector2(12, 3.4 * sy), 1.8, 8), Art.INK)
		Art.flat(ci, Art.circle_pts(Vector2(11.4, 3.0 * sy - 0.6), 0.7, 6), Art.WHITE)
	Art.pop(ci)
	Art.pop(ci)


static func _stone_bomb(ci: CanvasItem, t: float) -> void:
	var g := 1.0 + snappedf(sin(t * 5.0), 0.25) * 0.08
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(g, g))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 28.0, 32), Color(1.0, 0.45, 0.15, 0.3))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 23.0, 32), Color(1.0, 0.6, 0.2, 0.3))
	Art.pop(ci)
	var body := Art.circle_pts(Vector2(0, 3), 18.0, 34)
	Art.toon(ci, body, Color("8a7f9a"), _W, 0.7)
	# Carved sun glyph that glows.
	var on := snappedf(0.5 + 0.5 * sin(t * 6.0), 0.25)
	var glyph := Color("ff7a1e").lerp(Color("ffe27a"), on)
	Art.flat(ci, Art.circle_pts(Vector2(0, 4), 13.0, 20), Color(1.0, 0.6, 0.15, 0.25 + 0.2 * on))
	Art.ring(ci, Art.circle_pts(Vector2(0, 4), 6.5, 18), glyph, 2.6)
	for i in 8:
		var a := TAU * i / 8.0
		Art.line(ci, Vector2(0, 4) + Vector2(cos(a), sin(a)) * 9.5, Vector2(0, 4) + Vector2(cos(a), sin(a)) * 13.0, glyph, 2.2)
	Art.flat(ci, Art.circle_pts(Vector2(0, 4), 3.0, 12), glyph)
	# Moss patch and a leaf.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-10, 16), Vector2(10, 6), 16), body), Color("5cbf3a"))
	_shine(ci, Vector2(-8, -6), Vector2(4.5, 2.6), -0.7, 0.55)
	# Vine fuse with a fizzing spark.
	Art.stroke(ci, PackedVector2Array([Vector2(4, -14), Vector2(9, -20), Vector2(14, -21)]), Color("4caa3a"), 3.0, 1.6)
	leaf(ci, Vector2(8, -19), -2.2, 8.0, 3.0, LEAF, 1.6)
	var sp := snappedf(1.0 + 0.35 * sin(t * 18.0), 0.25)
	Art.push(ci, Vector2(15, -22), snappedf(t * 6.0, 0.5), Vector2(sp, sp))
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 6.5, 2.6, 6), Color("ffd23a"))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 2.2, 8), Art.WHITE)
	Art.pop(ci)


static func _sun_disc(ci: CanvasItem, t: float) -> void:
	var g := 1.0 + snappedf(sin(t * 4.0), 0.25) * 0.06
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(g, g))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 28.0, 32), Color(1, 0.95, 0.6, 0.3))
	Art.pop(ci)
	# Rainbow rays turning behind the disc: it matches any color.
	var cols := [Color("ff4d5e"), Color("ff9a3c"), Color("ffd23f"), Color("5cd05f"), Color("3aa6f0"), Color("9a6cf0")]
	Art.push(ci, Vector2.ZERO, snappedf(t * 0.8, 0.05))
	for i in 12:
		var a := TAU * i / 12.0
		Art.push(ci, Vector2.ZERO, a)
		Art.toon(ci, PackedVector2Array([Vector2(13, -4.5), Vector2(26, 0), Vector2(13, 4.5)]), cols[i % 6], 2.0, 0.0)
		Art.pop(ci)
	Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 15.0, GOLD, _W, 0.7)
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, 11.0, 24), Art.GOLD_DARK, 1.6)
	# A smiling sun face.
	for sx: float in [-1.0, 1.0]:
		Art.arc(ci, Vector2(4.5 * sx, -2), 2.4, PI + 0.3, TAU - 0.3, 6, Art.INK, 1.8)
	Art.arc(ci, Vector2(0, 2), 4.5, 0.4, PI - 0.4, 8, Art.INK, 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, 3), Vector2(2.2, 1.4), 8), Color(1.0, 0.5, 0.4, 0.55))
	Art.flat(ci, Art.ellipse_pts(Vector2(7, 3), Vector2(2.2, 1.4), 8), Color(1.0, 0.5, 0.4, 0.55))
	_shine(ci, Vector2(-6, -8), Vector2(4, 2.2), -0.7, 0.75)
	for i in 3:
		Art.push(ci, Vector2.ZERO, t * 1.2 + TAU * i / 3.0)
		_twinkle(ci, Vector2(24, 0), 5.5, t, i * 2.1)
		Art.pop(ci)


# --- Blockers ---------------------------------------------------------------------------------

## "sand": a carved temple stone block (2+ layers: a big cracked block
## overgrown with vines). "bubble": a net of vines over a piece.
static func blocker(ci: CanvasItem, kind: String, layers: int) -> void:
	match kind:
		"sand":
			_stone(ci, layers)
		"bubble":
			_vines(ci, layers)


static func _stone(ci: CanvasItem, layers: int) -> void:
	var block := Art.rrect_pts(Rect2(-27, -27, 54, 54), 7)
	var fill := STONE if layers < 2 else Color("c4a468")
	Art.toon(ci, block, fill, _W, 0.6)
	var line := Art.shade_of(fill, 0.38)
	# Carved border and a glyph in the middle (a sun or a serpent eye).
	Art.ring(ci, Art.rrect_pts(Rect2(-20, -20, 40, 40), 4), Color(line, 0.85), 2.0)
	if layers >= 2:
		Art.ring(ci, Art.circle_pts(Vector2(0, -1), 8.5, 20), line, 2.4)
		Art.flat(ci, Art.circle_pts(Vector2(0, -1), 3.0, 10), line)
		for i in 4:
			var a := PI / 4.0 + TAU * i / 4.0
			Art.line(ci, Vector2(cos(a), sin(a)) * 11.0 + Vector2(0, -1), Vector2(cos(a), sin(a)) * 15.0 + Vector2(0, -1), line, 2.2)
		# A crack and a vine growing over the corner.
		Art.polyline(ci, PackedVector2Array([Vector2(-27, 6), Vector2(-17, 9), Vector2(-12, 16), Vector2(-4, 18)]), Art.INK, 1.8)
		Art.stroke(ci, Art.smooth_pts(PackedVector2Array([Vector2(28, -27), Vector2(16, -18), Vector2(20, -4), Vector2(10, 8), Vector2(14, 22), Vector2(6, 28)]), 3), Color("4caa3a"), 3.0, 1.6)
		for p: Vector3 in [Vector3(16, -18, -2.6), Vector3(20, -4, 0.4), Vector3(10, 8, -2.8), Vector3(14, 22, 0.2)]:
			leaf(ci, Vector2(p.x, p.y), p.z, 10.0, 3.6, LEAF if int(p.y) % 2 == 0 else Color("5cd05a"), 1.6)
	else:
		Art.polyline(ci, PackedVector2Array([Vector2(-9, 6), Vector2(-9, -8), Vector2(9, -8), Vector2(9, 2), Vector2(-3, 2), Vector2(-3, -3), Vector2(3, -3)]), line, 2.4)
		Art.flat(ci, Art.ellipse_pts(Vector2(-14, 16), Vector2(9, 5), 14), Color("6cc24a", 0.9))
		Art.flat(ci, Art.ellipse_pts(Vector2(-8, 19), Vector2(6, 3.5), 12), Color("4caa3a", 0.9))
	Art.flat(ci, Art.ellipse_pts(Vector2(-17, -20), Vector2(5, 2), 10, -0.3), Color(1, 1, 1, 0.45))


static func _vines(ci: CanvasItem, layers: int) -> void:
	# A light green tint, then vines crossing the cell with little leaves.
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 26.0, 32), Color(0.5, 1.0, 0.6, 0.16 if layers < 2 else 0.26))
	var vine := Color("3f9a34")
	var lines := [
		PackedVector2Array([Vector2(-27, -18), Vector2(-8, -12), Vector2(10, 2), Vector2(27, 14)]),
		PackedVector2Array([Vector2(-26, 16), Vector2(-6, 8), Vector2(12, -8), Vector2(26, -20)]),
	]
	if layers >= 2:
		lines.append(PackedVector2Array([Vector2(-6, -27), Vector2(-2, -8), Vector2(3, 10), Vector2(0, 27)]))
	for l: PackedVector2Array in lines:
		Art.stroke(ci, Art.smooth_pts(l, 3), vine, 2.6 if layers < 2 else 3.6, 1.6)
	# Leaves out at the edges so the piece under it stays easy to see.
	for p: Vector3 in [Vector3(-22, -17, -2.6), Vector3(22, 12, 0.5), Vector3(-21, 14, 2.6), Vector3(21, -17, -0.6)]:
		leaf(ci, Vector2(p.x, p.y), p.z, 10.0, 3.8, LEAF if p.x < 0 else Color("5cd05a"), 1.6)
	if layers >= 2:
		for p: Vector3 in [Vector3(-5, -24, -1.4), Vector3(1, 22, 1.7)]:
			leaf(ci, Vector2(p.x, p.y), p.z, 10.0, 3.8, Color("54c050"), 1.6)
	# A small pink flower on the corner.
	Art.push(ci, Vector2(18, -20), 0.0, Vector2(0.26, 0.26))
	Art.toon(ci, _flower_pts(10.0, 22.0, 0.0), Color("ff6aa8"), 6.0, 0.3)
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 6.0, 12), Color("ffe04a"))
	Art.pop(ci)
