class_name FounderArt
extends RefCounted
## The exclusive "Founder" look and the online dialogs' pictures: the golden
## captain's cap (a wardrobe hat, HatsArt space: head at the origin, radius
## 20), the founder medal, the leaderboard podium and the invite letter.

const GOLD_HI := Color("ffe27a")
const NAVY := Color("2e3a6e")
const PEARL := Color("fff4fb")
const SHELL := Color("ffb3c9")


## Golden captain's cap with a navy band, a gold rope and a pearl in a
## shell on the front.
static func hat(ci: CanvasItem) -> void:
	# Crown of the cap: a wide golden top leaning back a little.
	var top := Art.smooth_pts(PackedVector2Array([Vector2(-20, -15), Vector2(-27, -27), Vector2(-20, -36), Vector2(0, -39),
			Vector2(20, -36), Vector2(27, -27), Vector2(20, -15)]), 3)
	Art.toon(ci, top, Art.GOLD, 2.5, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-9, -32), Vector2(10, 3.5), 14, -0.15), top), Color(1, 1, 1, 0.5))
	# Band and rope.
	Art.t_rect(ci, Rect2(-21, -21, 42, 8), 2.5, NAVY, 2.2, 0.0)
	Art.polyline(ci, PackedVector2Array([Vector2(-18, -18.5), Vector2(-6, -16.5), Vector2(6, -16.5), Vector2(18, -18.5)]), GOLD_HI, 2.0)
	for x: float in [-18.0, 18.0]:
		Art.t_circle(ci, Vector2(x, -18), 2.0, Art.GOLD, 1.2, 0.0)
	# Visor.
	Art.t_ellipse(ci, Vector2(2, -12.5), Vector2(19, 4.5), NAVY, 2.2, 0.0)
	Art.arc(ci, Vector2(2, -13.5), 15.0, 0.35, PI - 0.35, 10, Color(1, 1, 1, 0.35), 1.4)
	# The badge: a pearl in a scallop shell with gold leaves either side.
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(0, -27), 0.0, Vector2(sx, 1))
		Art.t_ellipse(ci, Vector2(-9, 1), Vector2(5, 2.4), Art.GOLD_DARK, 1.4, 0.0, -0.5)
		Art.t_ellipse(ci, Vector2(-12, -2.5), Vector2(4, 2), Art.GOLD_DARK, 1.4, 0.0, -0.9)
		Art.pop(ci)
	var shell := PackedVector2Array([Vector2(0, -21)])
	for i in 11:
		var a := PI + 0.25 + (PI - 0.5) * i / 10.0
		var rr := 7.5 + (0.9 if i % 2 == 0 else 0.0)
		shell.append(Vector2(0, -24) + Vector2(cos(a), sin(a)) * rr)
	Art.toon(ci, shell, SHELL, 1.8, 0.3)
	for x: float in [-3.0, 0.0, 3.0]:
		Art.line(ci, Vector2(0, -22), Vector2(x * 1.6, -29.5), Art.shade_of(SHELL, 0.2), 1.0)
	Art.t_circle(ci, Vector2(0, -25), 3.3, PEARL, 1.5, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(-1.1, -26.1), 1.0, 6), Art.WHITE)
	# A twinkle on the gold.
	star(ci, Vector2(17, -33), 3.2, Art.WHITE)


## A small four-pointed sparkle.
static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI / 2.0 + TAU * i / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.32))
	Art.flat(ci, pts, col)


## Five-pointed star outline points.
static func star5(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts


## The founder medal: ribbon, a gold disc and the number (n = 0: a star).
static func medal(ci: CanvasItem, c: Vector2, r: float, n: int, tt: float = 0.0) -> void:
	Art.push(ci, c, roundf(sin(tt * 1.8) * 4.0) / 4.0 * 0.06, Vector2.ONE * (r / 40.0))
	Art.toon(ci, PackedVector2Array([Vector2(-22, -54), Vector2(-6, -54), Vector2(8, -14), Vector2(-8, -14)]), Art.BLUE, 3.0, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(22, -54), Vector2(6, -54), Vector2(-8, -14), Vector2(8, -14)]), Art.CORAL, 3.0, 0.0)
	var disc := Art.circle_pts(Vector2(0, 6), 30.0, 40)
	Art.toon(ci, disc, Art.GOLD, 3.5, 0.6)
	Art.ring(ci, Art.circle_pts(Vector2(0, 6), 23.0, 36), Art.GOLD_DARK, 2.5)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-10, -6), Vector2(14, 7), 16, -0.5), disc), Color(1, 1, 1, 0.45))
	if n > 0:
		Art.text(ci, Vector2(0, 16), "#%d" % n, 22 if n < 100 else 18, Art.WHITE, 6)
	else:
		Art.toon(ci, star5(Vector2(0, 7), 14.0), Art.WHITE, 2.5, 0.0)
	Art.pop(ci)
	var k := int(tt * 3.0) % 3
	star(ci, c + Vector2(r * 0.85, -r * 0.55), r * (0.16 if k == 0 else 0.11), Art.WHITE)
	star(ci, c + Vector2(-r * 0.9, r * 0.1), r * (0.11 if k == 1 else 0.07), Art.WHITE)


## Three-step podium with a gold star over the middle (leaderboard header).
static func podium(ci: CanvasItem, c: Vector2, s: float, tt: float = 0.0) -> void:
	Art.push(ci, c, 0.0, Vector2(s, s))
	var steps := [[Rect2(-36, -8, 24, 22), Color("d9e2ef"), "2"], [Rect2(-12, -20, 24, 34), Art.GOLD, "1"], [Rect2(12, -2, 24, 16), Color("e8a06a"), "3"]]
	for st in steps:
		Art.t_rect(ci, st[0], 3, st[1], 2.5, 0.4)
		var r: Rect2 = st[0]
		Art.text(ci, Vector2(r.get_center().x, r.position.y + 15), str(st[2]), 13, Art.WHITE, 4)
	var bob := roundf(sin(tt * 2.2) * 2.0) * 0.75
	Art.toon(ci, star5(Vector2(0, -31 + bob), 9.0), Art.GOLD, 2.2, 0.4)
	Art.pop(ci)


## A letter with a heart seal flying out of a shell (invite dialog).
static func letter(ci: CanvasItem, c: Vector2, s: float, tt: float = 0.0) -> void:
	Art.push(ci, c + Vector2(0, roundf(sin(tt * 2.0) * 2.0)), -0.08, Vector2(s, s))
	Art.t_rect(ci, Rect2(-24, -16, 48, 32), 4, Art.CREAM, 2.5, 0.3)
	Art.polyline(ci, PackedVector2Array([Vector2(-22, -14), Vector2(0, 3), Vector2(22, -14)]), Art.INK, 2.2)
	Art.polyline(ci, PackedVector2Array([Vector2(-22, 14), Vector2(-7, -1)]), Art.INK_SOFT, 1.6)
	Art.polyline(ci, PackedVector2Array([Vector2(22, 14), Vector2(7, -1)]), Art.INK_SOFT, 1.6)
	var heart := Art.union([Art.circle_pts(Vector2(-3, 1), 3.6, 12), Art.circle_pts(Vector2(3, 1), 3.6, 12),
			PackedVector2Array([Vector2(-6.4, 2.4), Vector2(6.4, 2.4), Vector2(0, 9.5)])])
	Art.toon(ci, heart, Art.CORAL, 1.6, 0.3)
	Art.pop(ci)
	star(ci, c + Vector2(30 * s, -18 * s), 4.0 * s, Art.GOLD)
	star(ci, c + Vector2(-32 * s, 14 * s), 3.0 * s, Art.WHITE)
