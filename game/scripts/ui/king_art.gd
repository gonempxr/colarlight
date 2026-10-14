class_name KingArt
extends RefCounted
## The live crown of the board's no. 1 (Online.crown): a big royal gold
## crown worn only while that player holds the first place. It is drawn on
## top of their character (portraits, the fisher) for themselves and for
## everyone who sees them on the boards. Not a wardrobe item: it goes as
## soon as someone overtakes them.

## The hat id the crown takes on a full figure (Chars._hat), see look().
const HAT := "king_live"


## `l` (an avatar look) wearing the crown instead of its hat.
static func look(l: Dictionary) -> Dictionary:
	var d := l.duplicate()
	d["hat"] = HAT
	return d


## The crown, standing on `at` (bottom center), `w` px wide; `t` makes the
## jewels sparkle and the glow breathe (in steps, so shapes stay cached).
static func crown(ci: CanvasItem, at: Vector2, w: float, t: float, tilt: float = 0.0) -> void:
	var pulse := snappedf(0.5 + 0.5 * sin(t * 2.4), 0.25)
	Art.push(ci, at, tilt, Vector2.ONE * (w / 64.0))
	Art.glow(ci, Vector2(0, -24), 50.0, Color(1.0, 0.82, 0.25, 0.28 + 0.12 * pulse), 16)
	# Red velvet inside, seen between the points.
	Art.toon(ci, _VELVET, Color("c81e3c"), 2.6, 0.5)
	# The orb and cross on the top.
	Art.t_circle(ci, Vector2(0, -50), 6.0, Art.GOLD, 2.6, 0.5)
	Art.t_rect(ci, Rect2(-1.8, -66, 3.6, 12), 1.2, Art.GOLD, 2.2, 0.0)
	Art.t_rect(ci, Rect2(-6, -62, 12, 3.6), 1.2, Art.GOLD, 2.2, 0.0)
	# Five tall points on a heavy band.
	Art.toon(ci, _BODY, Art.GOLD, 3.0, 0.7)
	Art.flat(ci, _BODY_SHINE, Color(1, 1, 1, 0.35))
	for p: Vector2 in _TIPS:
		Art.t_circle(ci, p, 4.4, Color("fff8e8"), 2.0, 0.4)
	Art.t_rect(ci, Rect2(-31, -14, 62, 14), 5, Art.GOLD_DARK, 2.8, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-27, -12, 54, 3), 1.5), Color(1, 1, 1, 0.4))
	# Jewels: a big ruby in the middle, sapphires and emeralds around.
	Art.toon(ci, _RUBY, Color("ff2d55"), 2.2, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(-2, -32), Vector2(1.6, 3.2), 8, 0.4), Color(1, 1, 1, 0.75))
	for k in 4:
		var x := -21.0 + k * 14.0
		Art.t_ellipse(ci, Vector2(x, -7), Vector2(4.2, 3.6), Color("2f8cff") if k % 2 == 0 else Color("2fd08a"), 1.6, 0.4)
	# Sparkles hopping between the jewels.
	for k in 3:
		var ph := fposmod(t * 0.8 + k * 0.33, 1.0)
		var s := snappedf(sin(ph * PI), 0.25)
		if s > 0.0:
			Art.push(ci, _SPARKS[k], 0.0, Vector2.ONE * s)
			Art.toon(ci, _STAR, Color(1, 1, 0.92), 0.0, 0.0)
			Art.pop(ci)
	Art.pop(ci)


## The crown over a round portrait (center `c`, radius `r`): sits on the
## top of the ring, a little tilted, bigger than any hat.
## `low` keeps it inside the top edge (the HUD portrait at the screen's top).
static func on_portrait(ci: CanvasItem, c: Vector2, r: float, t: float, low := false) -> void:
	if low:
		crown(ci, c + Vector2(r * 0.1, -r * 0.12), r * 1.25, t, 0.14)
	else:
		crown(ci, c + Vector2(r * 0.12, -r * 0.42), r * 1.6, t, 0.12)


static var _BODY := PackedVector2Array([Vector2(-31, -2), Vector2(-34, -38), Vector2(-22, -22), Vector2(-15, -42), Vector2(-7, -26),
	Vector2(0, -48), Vector2(7, -26), Vector2(15, -42), Vector2(22, -22), Vector2(34, -38), Vector2(31, -2)])
static var _BODY_SHINE := Art.clipped(PackedVector2Array([Vector2(-40, -30), Vector2(-24, -30), Vector2(-30, 0), Vector2(-40, 0)]), _BODY)
static var _VELVET := Art.smooth_pts(PackedVector2Array([Vector2(-26, -14), Vector2(-22, -34), Vector2(-8, -44), Vector2(8, -44),
	Vector2(22, -34), Vector2(26, -14)]), 2)
static var _TIPS: Array[Vector2] = [Vector2(-34, -40), Vector2(-15, -44), Vector2(15, -44), Vector2(34, -40)]
static var _RUBY := PackedVector2Array([Vector2(0, -38), Vector2(6, -31), Vector2(0, -22), Vector2(-6, -31)])
static var _STAR := Art.star_pts(Vector2.ZERO, 7.0, 1.8, 4)
static var _SPARKS: Array[Vector2] = [Vector2(-26, -30), Vector2(10, -46), Vector2(24, -10)]
