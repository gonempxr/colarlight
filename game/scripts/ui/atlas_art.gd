class_name AtlasArt
## Drawings for the Atlas of the Deep: the sonar background, the map nodes
## and the Murk, chamber icons, the deep-sea foes and the side button icon.
## A dark blue abyss with things that glow (jellyfish blue, lure gold,
## Murk violet). Glows are Art.glow fans (cached), animation in steps.

const DEEP_TOP := Color("0a1d52")
const DEEP_BOTTOM := Color("030a24")
const SONAR := Color("5ee0ff")
const MURK := Color("6a3fb8")
const LURE := Color("ffd23f")
const CLEARED := Color("4cf0a0")


## The abyss: a dark gradient, slow sonar rings from the bottom and a few
## glowing specks drifting up.
static func draw_bg(ci: CanvasItem, s: Vector2, tt: float) -> void:
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([DEEP_TOP, DEEP_TOP, DEEP_BOTTOM, DEEP_BOTTOM]))
	var origin := Vector2(s.x / 2.0, s.y * 1.02)
	var reach := s.length()
	for i in 3:
		var k := fposmod(snappedf(tt * 0.12, 0.01) + i / 3.0, 1.0)
		var a := snappedf(0.16 * (1.0 - k), 0.02)
		if a > 0.0:
			Art.arc(ci, origin, maxf(4.0, snappedf(k * reach, 4.0)), PI, TAU, 48, Color(SONAR, a), 3.0)
	draw_seabed(ci, s, tt)
	for i in 18:
		var x := fposmod(i * 83.0 + sin(i * 1.7) * 40.0, s.x)
		var y := s.y - fposmod(snappedf(tt * (8.0 + i % 5 * 3.0), 1.0) + i * 157.0, s.y + 20.0)
		Art.dot(ci, Vector2(x, y), 1.5 + i % 3, Color(SONAR, 0.18 + 0.08 * (i % 3)))


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


## The dive's cave: rock walls closing in, the crew of three divers with
## head lamps bobbing in the middle, and the depth track on the right
## (layer `at` of `count`, the last one the guardian's).
static func draw_cave(ci: CanvasItem, s: Vector2, tt: float, at: int, count: int) -> void:
	var rock := Color("0a1640")
	for side in [-1.0, 1.0]:
		var x0 := 0.0 if side < 0.0 else s.x
		var pts := PackedVector2Array([Vector2(x0, 0)])
		for i in 7:
			var y := s.y * i / 6.0
			pts.append(Vector2(x0 - side * (s.x * (0.1 + 0.06 * sin(i * 1.9 + side))), y))
		pts.append(Vector2(x0, s.y))
		Art.flat(ci, Art.smooth_pts(pts, 3), rock)
	var c := Vector2(s.x * 0.44, s.y * 0.52)
	var k := clampf(s.y / 200.0, 0.7, 1.6)
	for i in 3:
		var p := c + Vector2((i - 1) * 54.0 * k, snappedf(sin(tt * 1.6 + i * 1.7) * 5.0, 1.0) + absf(i - 1) * 14.0 * k)
		draw_diver(ci, p, k)
	# Depth track.
	var x := s.x - 30.0
	var top := 18.0
	var bot := s.y - 18.0
	Art.line_c(ci, PackedVector2Array([Vector2(x, top), Vector2(x, bot)]), Color(SONAR, 0.4), 3.0)
	for i in count:
		var y := lerpf(top, bot, float(i) / maxf(1.0, count - 1.0))
		var last := i == count - 1
		if last:
			Art.t_circle(ci, Vector2(x, y), 11.0, Color("5a1f3a"), 2.5, 0.0)
			draw_skull(ci, Vector2(x, y), 6.5)
		else:
			Art.t_circle(ci, Vector2(x, y), 8.0, CLEARED if i < at else (Color("bff4ff") if i == at else Color("24306a")), 2.5, 0.0)
		if i == at:
			Art.arc(ci, Vector2(x, y), 14.0, 0.0, TAU, 24, Art.WHITE, 2.5)


## A small diver: round brass helmet with a glass, a lamp beam, flippers.
static func draw_diver(ci: CanvasItem, c: Vector2, k: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	Art.grad(ci, PackedVector2Array([Vector2(10, -24), Vector2(10, -16), Vector2(80, 6), Vector2(80, -46)]),
		PackedColorArray([Color(LURE, 0.35), Color(LURE, 0.35), Color(LURE, 0.0), Color(LURE, 0.0)]))
	Art.toon(ci, Art.ellipse_pts(Vector2(-4, 14), Vector2(13, 16), 18), Color("e8742a"), 3.0, 0.6)
	for sx in [-1.0, 1.0]:
		Art.toon(ci, PackedVector2Array([Vector2(-8 + sx * 6, 26), Vector2(-14 + sx * 9, 40), Vector2(-2 + sx * 7, 38)]), Color("2b6fd6"), 2.5, 0.0)
	Art.t_circle(ci, Vector2(0, -8), 15.0, Color("d9a441"), 3.0, 0.6)
	Art.t_circle(ci, Vector2(3, -8), 9.0, Color("9fe6ff"), 2.5, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -12), Vector2(3, 2), 8), Color(1, 1, 1, 0.8))
	Art.glow(ci, Vector2(10, -20), 12.0, Color(LURE, 0.8))
	Art.t_circle(ci, Vector2(10, -20), 3.5, LURE, 2.0, 0.0)
	Art.pop(ci)


## A map node: glowing pearl-like light (open), green and calm (cleared) or
## a dim shape in the Murk (fog). The citadel is bigger with a crown of
## spikes; a skull tag marks a wanted monster.
static func draw_node(ci: CanvasItem, c: Vector2, state: String, tier: int, citadel: bool, selected: bool, bounty: bool, tt: float) -> void:
	var r := 30.0 if citadel else 22.0
	var pulse := snappedf(sin(tt * 2.4 + c.x * 0.05) * 0.5 + 0.5, 0.1)
	match state:
		"fog":
			Art.glow(ci, c, r * 2.0, Color(MURK, 0.35))
			Art.t_circle(ci, c, r * 0.8, Color("2a2350"), 3.0, 0.0)
			Art.text(ci, c + Vector2(0, 8), "?", 22, Color("8f80c9"), 0)
			return
		"cleared":
			Art.glow(ci, c, r * 1.9, Color(CLEARED, 0.28))
			Art.t_circle(ci, c, r, Color("1f7a5a"), 3.0, 0.4)
			Art.t_circle(ci, c, r * 0.62, CLEARED, 0.0, 0.0)
		_:
			Art.glow(ci, c, r * (2.2 + 0.4 * pulse), Color(SONAR, 0.35 + 0.15 * pulse))
			Art.t_circle(ci, c, r, Color("1d5fa8"), 3.0, 0.4)
			Art.t_circle(ci, c, r * 0.62, Color("bff4ff"), 0.0, 0.0)
	if citadel:
		for i in 5:
			var a := -PI / 2.0 + (i - 2) * 0.42
			var p := c + Vector2(cos(a), sin(a)) * r
			Art.toon(ci, PackedVector2Array([p + Vector2(cos(a + 1.4), sin(a + 1.4)) * 6.0, p + Vector2(cos(a), sin(a)) * 14.0,
				p + Vector2(cos(a - 1.4), sin(a - 1.4)) * 6.0]), Color("c9a3ff"), 2.5, 0.0)
	Art.text(ci, c + Vector2(0, 7), "%d" % tier, 20 if not citadel else 24, Art.INK if state != "fog" else Color("8f80c9"), 0)
	if selected:
		Art.arc(ci, c, r + 9.0 + pulse * 3.0, 0.0, TAU, 40, Art.WHITE, 3.0)
	if bounty:
		var b := c + Vector2(r * 0.85, -r * 0.85)
		Art.t_circle(ci, b, 12.0, Art.RED, 2.5, 0.0)
		draw_skull(ci, b, 7.0)


## The Murk over hidden nodes: soft violet clouds (drawn under the nodes).
static func draw_murk(ci: CanvasItem, c: Vector2, tt: float) -> void:
	for i in 3:
		var o := Vector2(cos(i * 2.1 + tt * 0.2), sin(i * 2.1 + tt * 0.2)) * 18.0
		Art.glow(ci, c + Vector2(snappedf(o.x, 2.0), snappedf(o.y, 2.0)), 54.0, Color(MURK, 0.22))


## A link between two nodes: bright when one side is cleared, dotted dim
## otherwise.
static func draw_link(ci: CanvasItem, a: Vector2, b: Vector2, lit: bool) -> void:
	if lit:
		Art.line_c(ci, PackedVector2Array([a, b]), Color(SONAR, 0.55), 5.0)
		Art.line_c(ci, PackedVector2Array([a, b]), Color("dffaff", 0.8), 2.0)
	else:
		var n := maxi(2, int(a.distance_to(b) / 16.0))
		for i in n:
			Art.dot(ci, a.lerp(b, (i + 0.5) / n), 2.0, Color("6c66a8", 0.6))


static func draw_skull(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.flat(ci, Art.circle_pts(c + Vector2(0, -r * 0.15), r * 0.8, 14), Art.WHITE)
	Art.flat(ci, PackedVector2Array([c + Vector2(-r * 0.45, r * 0.3), c + Vector2(r * 0.45, r * 0.3), c + Vector2(r * 0.35, r * 0.8), c + Vector2(-r * 0.35, r * 0.8)]), Art.WHITE)
	for sx in [-1.0, 1.0]:
		Art.flat(ci, Art.circle_pts(c + Vector2(sx * r * 0.32, -r * 0.15), r * 0.22, 8), Art.INK)


# --- Chamber icons --------------------------------------------------------------------

static func draw_chamber(ci: CanvasItem, c: Vector2, r: float, kind: String, tt: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * (r / 30.0))
	match kind:
		"treasure":
			Art.glow(ci, Vector2(0, -2), 40.0, Color(LURE, 0.35))
			Art.t_rect(ci, Rect2(-22, -6, 44, 26), 5.0, Color("b0703a"), 3.0, 0.5)
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-22, -6), Vector2(-20, -22), Vector2(20, -22), Vector2(22, -6)]), 3), Color("c98448"), 3.0, 0.5)
			Art.t_rect(ci, Rect2(-24, -9, 48, 7), 2.0, Art.GOLD, 2.5, 0.0)
			Art.t_rect(ci, Rect2(-5, -6, 10, 11), 2.0, Art.GOLD, 2.5, 0.0)
			Art.coin(ci, Vector2(-12, -26), 6.0)
			Art.coin(ci, Vector2(10, -28), 5.0)
		"monster":
			draw_angler(ci, Vector2.ZERO, 1.0, tt, Color("4a3a8c"))
		"current":
			for i in 3:
				var rr := 22.0 - i * 7.0
				var a0 := snappedf(tt * 2.0, 0.2) + i * 1.3
				Art.arc(ci, Vector2.ZERO, rr, a0, a0 + 4.4, 20, Color("7fe8ff", 0.95 - i * 0.2), 5.0 - i)
		"air":
			for i in 5:
				var p := Vector2(-14 + (i * 13) % 30, 18 - i * 9 - fposmod(snappedf(tt * 14.0, 2.0), 9.0))
				Art.t_circle(ci, p, 5.0 + (i % 3) * 3.0, Color("dffaff"), 2.5, 0.0)
		"mystery":
			Art.glow(ci, Vector2.ZERO, 36.0, Color(MURK, 0.6))
			Art.t_circle(ci, Vector2.ZERO, 22.0, Color("3a2a7a"), 3.0, 0.4)
			Art.text(ci, Vector2(0, 12), "?", 34, Color("e8dcff"), 4)
		"bounty":
			Art.t_rect(ci, Rect2(-20, -26, 40, 50), 4.0, Color("f2dfb0"), 3.0, 0.3)
			draw_skull(ci, Vector2(0, -4), 12.0)
			Art.t_rect(ci, Rect2(-14, 12, 28, 6), 2.0, Art.RED, 0.0, 0.0)
		"boss":
			Art.glow(ci, Vector2.ZERO, 44.0, Color("ff5a7a", 0.4))
			draw_angler(ci, Vector2.ZERO, 1.1, tt, Color("2b1f5c"), true)
	Art.pop(ci)


# --- Foes -----------------------------------------------------------------------------

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


static func draw_crab(ci: CanvasItem, c: Vector2, k: float, tt: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	var snap := snappedf(sin(tt * 3.0) * 0.15, 0.05)
	for s in [-1.0, 1.0]:
		for i in 3:
			Art.polyline(ci, PackedVector2Array([Vector2(s * (10 + i * 6), 8), Vector2(s * (18 + i * 7), 16), Vector2(s * (20 + i * 7), 24)]), Art.INK, 3.5)
		Art.push(ci, Vector2(s * 26, -10), s * (0.4 + snap))
		Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(s * 10, -12), Vector2(s * 4, -16), Vector2(s * 2, -8), Vector2(s * -4, -14)]), Color("2b2b3a"), 3.0, 0.4)
		Art.pop(ci)
	Art.toon(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(26, 16), 24), Color("23233a"), 3.0, 0.7)
	# Captain's hat.
	Art.toon(ci, PackedVector2Array([Vector2(-16, -12), Vector2(16, -12), Vector2(10, -24), Vector2(-10, -24)]), Color("151525"), 3.0, 0.3)
	draw_skull(ci, Vector2(0, -18), 5.0)
	for s in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(s * 7, -4), 4.5, Art.WHITE, 2.0, 0.0)
		Art.t_circle(ci, Vector2(s * 7, -3), 2.2, Color("ff4f6a"), 0.0, 0.0)
	Art.pop(ci)


static func draw_jelly(ci: CanvasItem, c: Vector2, k: float, tt: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	Art.glow(ci, Vector2(0, -6), 46.0, Color("ff7fe0", 0.35))
	for i in 6:
		var x := -15.0 + i * 6.0
		var sway := snappedf(sin(tt * 2.0 + i) * 4.0, 1.0)
		Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(x, 0), Vector2(x + sway, 14), Vector2(x - sway, 28), Vector2(x + sway * 0.5, 40)]), 3), Color("ffb3ee", 0.85), 3.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-24, 2), Vector2(-22, -16), Vector2(0, -30), Vector2(22, -16), Vector2(24, 2)]), 4), Color("e07fd0", 0.92), 3.0, 0.6)
	for s in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(s * 8, -10), 4.0, Art.WHITE, 2.0, 0.0)
		Art.t_circle(ci, Vector2(s * 8, -9), 2.0, Art.INK, 0.0, 0.0)
	Art.pop(ci)


static func draw_eel(ci: CanvasItem, c: Vector2, k: float, tt: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	var pts := PackedVector2Array()
	for i in 9:
		var x := -36.0 + i * 8.0
		pts.append(Vector2(x, snappedf(sin(tt * 3.0 + i * 0.8) * 8.0, 1.0)))
	Art.polyline(ci, pts, Art.INK, 17.0)
	Art.polyline(ci, pts, Color("1f2a44"), 11.0)
	Art.polyline(ci, pts, Color("4fe0ff", 0.6), 2.0)
	var head := pts[pts.size() - 1]
	Art.t_ellipse(ci, head + Vector2(6, 0), Vector2(12, 9), Color("1f2a44"), 3.0, 0.5)
	Art.t_circle(ci, head + Vector2(9, -3), 3.5, Color("4fe0ff"), 0.0, 0.0)
	Art.pop(ci)


## The foe of a fight: by kind and, for a wanted one, by its id.
static func draw_foe(ci: CanvasItem, c: Vector2, k: float, kind: String, bounty: String, tt: float) -> void:
	if kind == "bounty":
		match bounty:
			"crabblack":
				draw_crab(ci, c, k, tt)
			"mother_jelly":
				draw_jelly(ci, c, k, tt)
			_:
				draw_eel(ci, c, k, tt)
	elif kind == "boss":
		Art.glow(ci, c, 80.0 * k, Color("ff5a7a", 0.3))
		draw_angler(ci, c, k * 1.25, tt, Color("2b1f5c"), true)
	else:
		draw_angler(ci, c, k, tt, Color("4a3a8c"))


## Side button icon: a sonar dial with a glowing dot.
static func draw_icon(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.t_circle(ci, c, r, Color("0f2a6b"), 3.0, 0.0)
	Art.arc_c(ci, c, r * 0.62, 0.0, TAU, 24, Color(SONAR, 0.7), 2.0)
	Art.arc_c(ci, c, r * 0.3, 0.0, TAU, 16, Color(SONAR, 0.7), 2.0)
	Art.line_c(ci, PackedVector2Array([c, c + Vector2(r * 0.7, -r * 0.5)]), SONAR, 3.0)
	Art.glow(ci, c + Vector2(r * 0.35, r * 0.3), r * 0.5, Color(LURE, 0.8))
	Art.t_circle(ci, c + Vector2(r * 0.35, r * 0.3), r * 0.14, LURE, 0.0, 0.0)
