class_name DeepArt
## Deep-sea pieces of the saga's art (the Twilight Zone): the seabed
## silhouettes behind the boss fight and the small anglerfish of the mine's
## decor. Fixed shapes, animation in steps (cache friendly).

const LURE := Color("ffd23f")


## Dark silhouettes along the bottom: rock ridges, a sunken ship's hull,
## kelp and a few glowing tube plants (fixed shapes, cached).
static func draw_seabed(ci: CanvasItem, s: Vector2, tt: float) -> void:
	var y := s.y
	var far := Color("0c1a48")
	var near := Color("06102e")
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, y), Vector2(0, y - 90), Vector2(s.x * 0.18, y - 120),
		Vector2(s.x * 0.36, y - 70), Vector2(s.x * 0.58, y - 110), Vector2(s.x * 0.8, y - 64), Vector2(s.x, y - 100), Vector2(s.x, y)]), 4), far)
	# The wreck: a tilted hull with a broken mast.
	var w := Vector2(s.x * 0.72, y - 58)
	Art.flat(ci, PackedVector2Array([w + Vector2(-70, -6), w + Vector2(60, -26), w + Vector2(48, 10), w + Vector2(-56, 22)]), Color("0a1640"))
	Art.flat(ci, PackedVector2Array([w + Vector2(-8, -14), w + Vector2(-2, -15), w + Vector2(10, -86), w + Vector2(4, -86)]), Color("0a1640"))
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, y), Vector2(0, y - 46), Vector2(s.x * 0.25, y - 30),
		Vector2(s.x * 0.5, y - 52), Vector2(s.x * 0.75, y - 24), Vector2(s.x, y - 40), Vector2(s.x, y)]), 4), near)
	for i in 5:
		var x := s.x * (0.06 + i * 0.22)
		Art.seaweed(ci, Vector2(x, y - 20), 70.0 + (i % 3) * 26.0, Color("0b2350"), tt, i * 1.3, 8.0)
	for i in 4:
		var p := Vector2(s.x * (0.14 + i * 0.25), y - 34 - (i % 2) * 10)
		Art.flat(ci, PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(2, -22), p + Vector2(-2, -22)]), Color("103070"))
		Art.glow(ci, p + Vector2(0, -24), 14.0, Color("ff7fe0" if i % 2 == 0 else "5ee0ff", 0.55))


## A deep-sea anglerfish: round dark body, big jaw with teeth, a glowing
## lure on a stalk. `armored` adds plates and a spiky crest (the Warden).
static func draw_angler(ci: CanvasItem, c: Vector2, k: float, tt: float, body: Color, armored: bool = false) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	var bob := snappedf(sin(tt * 2.0) * 2.0, 0.5)
	var lure := Vector2(14, -34 + bob)
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(2, -18), Vector2(6, -34), Vector2(12, -38), lure]), 3), Art.INK, 3.0)
	Art.glow(ci, lure, 16.0, Color(LURE, 0.7))
	Art.t_circle(ci, lure, 4.5, LURE, 2.0, 0.0)
	# Tail fin.
	Art.toon(ci, PackedVector2Array([Vector2(-20, -2), Vector2(-34, -14), Vector2(-31, 0), Vector2(-34, 14)]), body.lightened(0.15), 3.0, 0.4)
	Art.toon(ci, Art.ellipse_pts(Vector2(0, 0), Vector2(24, 20), 24), body, 3.0, 0.7)
	if armored:
		for i in 4:
			var a := -2.4 + i * 0.45
			var p := Vector2(cos(a), sin(a)) * 20.0
			Art.toon(ci, PackedVector2Array([p + Vector2(-5, 2), p + Vector2(cos(a), sin(a)) * 12.0, p + Vector2(5, 2)]), Color("c9a3ff"), 2.5, 0.0)
		Art.toon(ci, Art.ellipse_pts(Vector2(-6, 4), Vector2(10, 8), 14), Color("6a58b0"), 2.5, 0.3)
	# Jaw and teeth.
	Art.toon(ci, PackedVector2Array([Vector2(8, 4), Vector2(26, -2), Vector2(24, 12), Vector2(10, 14)]), Color("1a1238"), 3.0, 0.0)
	for i in 4:
		var x := 11.0 + i * 3.6
		Art.flat(ci, PackedVector2Array([Vector2(x, 3.0 - i * 1.2), Vector2(x + 1.8, 9.0 - i), Vector2(x + 3.4, 2.4 - i * 1.2)]), Art.WHITE)
	Art.t_circle(ci, Vector2(6, -8), 6.5, Art.WHITE, 2.5, 0.0)
	Art.t_circle(ci, Vector2(7.5, -8), 3.2, Color("ff4f6a") if armored else Art.INK, 0.0, 0.0)
	Art.pop(ci)
