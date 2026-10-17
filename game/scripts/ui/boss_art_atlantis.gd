class_name BossArtAtlantis
extends RefCounted
## Act II's guards (Atlantis) for BossArt.draw: the Bronze Automaton, the
## Siren Queen, the Drowned King, the Hydra and the Colossus Gatekeeper.
## Same rules as BossArt: about 260 px wide at scale 1, toon outlines, big
## eyes, motion only through pushes of fixed shapes.

const BRONZE := Color("c7843a")
const BRONZE_HI := Color("e8a85a")
const BRONZE_DARK := Color("7a4a1e")
const GOLD := Color("ffc93c")
const ORI := Color("4af0e0")
const MARBLE := Color("f2ecdf")

## The Hydra's heads still standing (BossScreen sets it before drawing).
static var heads: Array = [true, true, true]
## The Automaton's shield is up (BossScreen sets it before drawing).
static var shielded := false


static func draw(ci: CanvasItem, id: String, t: float, hurt: float, anger: float) -> bool:
	match id:
		"automaton":
			_automaton(ci, t, hurt, anger)
		"siren_queen":
			_siren(ci, t, hurt, anger)
		"drowned_king":
			_king(ci, t, hurt, anger)
		"hydra":
			_hydra(ci, t, hurt, anger)
		"colossus":
			_colossus(ci, t, hurt, anger)
		_:
			return false
	return true


# --- The Bronze Automaton ------------------------------------------------------------

static func _automaton(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var bob := snappedf(sin(t * 2.0 * sp) * 4.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	# Legs and arms: riveted bronze pipes.
	for s in [-1.0, 1.0]:
		Art.t_rect(ci, Rect2(s * 40 - 14, 40, 28, 70), 8.0, BRONZE_DARK, 3.4, 0.4)
		Art.t_rect(ci, Rect2(s * 40 - 20, 100, 40, 18), 6.0, BRONZE, 3.4, 0.4)
		var swing := snappedf(sin(t * 2.4 * sp + s) * 0.2, 0.05)
		Art.push(ci, Vector2(s * 92, -40), s * (0.3 + swing))
		Art.t_rect(ci, Rect2(-14, 0, 28, 80), 10.0, BRONZE_DARK, 3.4, 0.4)
		Art.t_circle(ci, Vector2(0, 92), 22.0, BRONZE, 3.4, 0.5)
		for k in 3:
			Art.t_circle(ci, Vector2(-10 + k * 10, 100), 4.0, GOLD, 1.6, 0.0)
		Art.pop(ci)
	# Body: a barrel chest with a glowing core window.
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-84, 50), Vector2(-96, -30), Vector2(-70, -86), Vector2(70, -86), Vector2(96, -30), Vector2(84, 50)]), 3)
	Art.toon(ci, body, BRONZE, 4.4, 1.0)
	for y: float in [-60.0, -10.0, 34.0]:
		Art.line(ci, Vector2(-86, y), Vector2(86, y), Color(BRONZE_DARK, 0.7), 3.0)
		for k in 6:
			Art.disc(ci, Vector2(-70 + k * 28, y - 7), 3.0, GOLD)
	var pulse := snappedf(0.5 + 0.5 * sin(t * 4.0 * sp), 0.25)
	Art.glow(ci, Vector2(0, -6), 60.0, Color(ORI, 0.35 + 0.3 * pulse))
	Art.t_circle(ci, Vector2(0, -6), 26.0, Color("1a3a5a"), 3.4, 0.0)
	AtlantisArt.cog(ci, Vector2(0, -6), 20.0, 10, ORI, snappedf(t * 1.5 * sp, 0.1))
	# Head: a Greek helmet with a crest, one big lens eye.
	Art.push(ci, Vector2(0, -110))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-52, 30), Vector2(-56, -18), Vector2(-30, -46), Vector2(30, -46), Vector2(56, -18), Vector2(52, 30)]), 3), BRONZE_HI, 4.0, 0.8)
	for k in 7:
		var a := -2.6 + k * 0.32
		var p := Vector2(cos(a), sin(a)) * 50.0 + Vector2(0, -6)
		Art.toon(ci, PackedVector2Array([p + Vector2(-8, 2), p + Vector2(cos(a), sin(a)) * 30.0, p + Vector2(8, 2)]), Color("e0603c"), 2.6, 0.2)
	Art.t_rect(ci, Rect2(-40, -6, 80, 16), 4.0, Color("1a1430"), 3.0, 0.0)
	BossArt.eye(ci, Vector2(0, 2), 18.0, ORI if anger < 0.5 else Color("ff4a5a"), hurt, anger, 1.0)
	Art.pop(ci)
	if shielded:
		# A dome of golden hexes: only skills get through.
		Art.glow(ci, Vector2(0, -30), 210.0, Color(1.0, 0.85, 0.35, 0.3))
		var hexes := Art.circle_pts(Vector2(0, -30), 170.0, 6)
		Art.ring(ci, hexes, Color(GOLD, 0.9), 5.0)
		Art.ring(ci, Art.circle_pts(Vector2(0, -30), 140.0, 6), Color(GOLD, 0.5), 3.0)
	Art.pop(ci)


# --- The Siren Queen -------------------------------------------------------------------

static func _siren(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var skin := Color("bfe8ff")
	var tail := Color("2ad0b0")
	var hair := Color("ff5aa8")
	var bob := snappedf(sin(t * 1.8 * sp) * 6.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	# The tail curling under her, a big fin.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-40, 10), Vector2(-60, 70), Vector2(0, 110), Vector2(80, 100), Vector2(110, 60), Vector2(70, 60),
		Vector2(20, 70), Vector2(30, 10)]), 4), tail, 4.0, 1.0)
	for k in 4:
		Art.arc(ci, Vector2(-20 + k * 24, 70 + k * 4), 12.0, PI, TAU, 8, Color("8af8e0"), 2.4)
	Art.push(ci, Vector2(110, 60), snappedf(sin(t * 3.0 * sp) * 0.25, 0.05))
	Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(50, -40), Vector2(36, 0), Vector2(50, 40)]), Color("1aa890"), 3.2, 0.4)
	Art.pop(ci)
	# Hair flowing behind.
	var flow := snappedf(sin(t * 1.4) * 10.0, 1.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-60, -110), Vector2(-110 - flow, -60), Vector2(-120, 10), Vector2(-80, -10), Vector2(-60, -40), Vector2(60, -40),
		Vector2(80, -10), Vector2(120, 10), Vector2(110 + flow, -60), Vector2(60, -110), Vector2(0, -136)]), 4), hair, 4.0, 0.8)
	# Body and arms holding a golden harp.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-36, 20), Vector2(-42, -30), Vector2(0, -50), Vector2(42, -30), Vector2(36, 20)]), 3), skin, 3.6, 0.6)
	for s in [-1.0, 1.0]:
		Art.t_ellipse(ci, Vector2(s * 16, -22), Vector2(14, 11), Color("ffd23f"), 2.6, 0.4)
	Art.push(ci, Vector2(70, -10), -0.2)
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 40), Vector2(-14, 0), Vector2(-8, -40), Vector2(26, -44)]), 3), Art.INK, 9.0)
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 40), Vector2(-14, 0), Vector2(-8, -40), Vector2(26, -44)]), 3), GOLD, 5.0)
	Art.line(ci, Vector2(0, 40), Vector2(26, -44), GOLD.darkened(0.2), 4.0)
	for k in 4:
		Art.line(ci, Vector2(-2 + k * 2, 30 - k * 8), Vector2(2 + k * 6, -38), Color(1, 1, 1, 0.8), 1.4)
	Art.pop(ci)
	# Head: big eyes, a pearl crown.
	Art.push(ci, Vector2(0, -84))
	Art.t_circle(ci, Vector2.ZERO, 40.0, skin, 3.8, 0.6)
	for s in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 15, 0), 13.0, Color("c25aff"), hurt, anger, s)
	Art.arc(ci, Vector2(0, 18), 9.0, 0.2, PI - 0.2, 8, Art.INK, 2.6)
	for k in 5:
		var a := -2.6 + k * 0.42
		Art.t_circle(ci, Vector2(cos(a), sin(a)) * 42.0, 6.0 if k == 2 else 4.5, Color("fff6e4"), 2.0, 0.0)
	Art.pop(ci)
	# Music notes of her song.
	for k in 3:
		var f := fposmod(t * 0.5 + k / 3.0, 1.0)
		var p := Vector2(-90 + k * 40, -150 - f * 60)
		Art.glow(ci, p, 16.0, Color(1.0, 0.5, 0.8, 0.5 * (1.0 - f)), 8)
		Art.t_circle(ci, p, 6.0, Color("ff9ad8"), 2.0, 0.0)
		Art.line(ci, p + Vector2(5, 0), p + Vector2(5, -20), Art.INK, 2.4)
	Art.pop(ci)


# --- The Drowned King ------------------------------------------------------------------

static func _king(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var robe := Color("2a5a8a")
	var skin := Color("8ad0c0")
	var bob := snappedf(sin(t * 1.4 * sp) * 5.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	# The robe, torn and weedy.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-60, -40), Vector2(-100, 60), Vector2(-90, 110), Vector2(-50, 96), Vector2(-20, 116), Vector2(20, 98),
		Vector2(56, 118), Vector2(96, 100), Vector2(100, 56), Vector2(60, -40)]), 4), robe, 4.4, 1.0)
	for k in 4:
		Art.line_c(ci, PackedVector2Array([Vector2(-70 + k * 44, 30), Vector2(-74 + k * 44, 60), Vector2(-66 + k * 44, 90)]), Color("3ac87a"), 3.0)
	# A golden mantle and chain.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-76, -40), Vector2(0, -10), Vector2(76, -40), Vector2(60, -64), Vector2(-60, -64)]), 3), GOLD, 3.4, 0.5)
	Art.arc(ci, Vector2(0, -40), 34.0, 0.4, PI - 0.4, 10, GOLD.darkened(0.15), 4.0)
	Art.t_circle(ci, Vector2(0, -6), 10.0, ORI, 2.4, 0.0)
	# The trident in his hand.
	var sw := snappedf(sin(t * 2.0 * sp) * 0.1, 0.02) - 0.15 * anger
	Art.push(ci, Vector2(100, -20), sw)
	Art.t_rect(ci, Rect2(-5, -150, 10, 230), 3.0, GOLD, 3.0, 0.4)
	for dx: float in [-24.0, 0.0, 24.0]:
		var tip := Vector2(dx, -196 if dx == 0.0 else -180)
		Art.toon(ci, PackedVector2Array([Vector2(dx - 6, -146), tip + Vector2(-6, 18), tip, tip + Vector2(6, 18), Vector2(dx + 6, -146)]), GOLD, 3.0, 0.4)
	Art.t_rect(ci, Rect2(-32, -156, 64, 12), 4.0, GOLD.darkened(0.12), 3.0, 0.3)
	Art.t_circle(ci, Vector2(0, -6), 16.0, skin, 3.0, 0.4)
	Art.pop(ci)
	# Head: a sunken face, a long beard of weed, a great crown.
	Art.push(ci, Vector2(0, -98))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-34, 30), Vector2(-50, 60), Vector2(-20, 96), Vector2(0, 80), Vector2(20, 96), Vector2(50, 60), Vector2(34, 30)]), 3), Color("3ac87a"), 3.2, 0.6)
	Art.t_circle(ci, Vector2.ZERO, 42.0, skin, 4.0, 0.7)
	for s in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 16, 0), 13.0, Color("ffe066"), hurt, maxf(0.5, anger), s)
	BossArt.mouth(ci, Vector2(0, 22), 14.0, 0.2 + 0.5 * anger + 0.3 * hurt, 3)
	Art.toon(ci, PackedVector2Array([Vector2(-44, -28), Vector2(-50, -76), Vector2(-24, -50), Vector2(0, -88), Vector2(24, -50), Vector2(50, -76), Vector2(44, -28)]), GOLD, 3.4, 0.5)
	for p in [Vector2(-30, -42), Vector2(0, -52), Vector2(30, -42)]:
		Art.t_circle(ci, p, 5.0, ORI, 1.8, 0.0)
	Art.pop(ci)
	Art.pop(ci)


# --- The Hydra --------------------------------------------------------------------------

static func _hydra(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var skin := Color("3a9a6a")
	var belly := Color("d8e8a0")
	# The body: a scaly mound with a tail.
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-120, 100), Vector2(-110, 40), Vector2(-60, 10), Vector2(60, 10), Vector2(110, 40), Vector2(130, 100)]), 4)
	Art.toon(ci, body, skin, 4.4, 1.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-50, 100), Vector2(-40, 50), Vector2(40, 50), Vector2(50, 100)]), 3), belly, 3.2, 0.4)
	for k in 5:
		Art.arc(ci, Vector2(-80 + k * 40, 40), 12.0, PI, TAU, 8, Color(skin.darkened(0.3), 0.8), 2.4)
	# Three necks and heads (a cut one is a stump).
	var bases := [Vector2(-60, 20), Vector2(0, 10), Vector2(60, 20)]
	var tops := [Vector2(-120, -90), Vector2(0, -140), Vector2(120, -90)]
	for i in 3:
		var sway := snappedf(sin(t * 1.8 * sp + i * 1.7) * 10.0, 1.0)
		var b: Vector2 = bases[i]
		var top: Vector2 = tops[i] + Vector2(sway, 0)
		if not bool(heads[i]):
			# A cut neck, a glowing wound where it regrows.
			var mid := b.lerp(top, 0.35)
			Art.polyline(ci, PackedVector2Array([b, mid]), Art.INK, 34.0)
			Art.polyline(ci, PackedVector2Array([b, mid]), skin, 26.0)
			Art.glow(ci, mid, 30.0, Color(1.0, 0.4, 0.4, 0.45))
			Art.t_circle(ci, mid, 12.0, Color("ff6a6a"), 2.4, 0.0)
			continue
		var mid2 := b.lerp(top, 0.5) + Vector2(sign(b.x) * -16.0, 0)
		var neck := Art.smooth_pts(PackedVector2Array([b, mid2, top]), 4)
		Art.polyline(ci, neck, Art.INK, 34.0)
		Art.polyline(ci, neck, skin, 26.0)
		Art.push(ci, top, sign(top.x) * 0.2)
		var head := Art.smooth_pts(PackedVector2Array([Vector2(-34, 16), Vector2(-36, -16), Vector2(-10, -36), Vector2(30, -30), Vector2(54, -6), Vector2(50, 18), Vector2(0, 26)]), 3)
		Art.toon(ci, head, skin, 3.8, 0.8)
		for s in [-1.0, 1.0]:
			Art.toon(ci, PackedVector2Array([Vector2(-14 + s * 14, -30), Vector2(-20 + s * 18, -56), Vector2(-4 + s * 14, -32)]), Color("2a7a4a"), 2.4, 0.3)
		BossArt.eye(ci, Vector2(4, -10), 12.0, Color("ffd23f") if i != 1 else Color("ff5a4a"), hurt, anger, 1.0)
		BossArt.mouth(ci, Vector2(30, 10), 14.0, 0.2 + 0.4 * anger + 0.3 * hurt, 3)
		Art.pop(ci)


# --- The Colossus Gatekeeper ---------------------------------------------------------------

static func _colossus(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger * 0.6
	var stone := MARBLE.darkened(0.06)
	var bob := snappedf(sin(t * 1.0 * sp) * 4.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	# The gate behind him: an arch of marble with a dark doorway.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-140, 110), Vector2(-140, -60), Vector2(-90, -150), Vector2(90, -150), Vector2(140, -60), Vector2(140, 110)]), 3), Color("b8ac94"), 4.0, 0.6)
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-100, 110), Vector2(-100, -50), Vector2(-60, -114), Vector2(60, -114), Vector2(100, -50), Vector2(100, 110)]), 3), Color("0c0c24"))
	MurkVeil.eye(ci, Vector2(-60, -60), 9.0, fmod(t, 3.0) < 0.2, false)
	MurkVeil.eye(ci, Vector2(64, -40), 8.0, fmod(t + 1.2, 3.4) < 0.2, true)
	# Legs, a kilt of bronze plates, a huge torso.
	for s in [-1.0, 1.0]:
		Art.t_rect(ci, Rect2(s * 40 - 20, 50, 40, 64), 6.0, stone, 3.6, 0.6)
	Art.toon(ci, PackedVector2Array([Vector2(-66, 10), Vector2(66, 10), Vector2(76, 64), Vector2(-76, 64)]), BRONZE, 3.6, 0.6)
	for k in 5:
		Art.line(ci, Vector2(-60 + k * 30, 12), Vector2(-66 + k * 33, 62), Color(BRONZE_DARK, 0.8), 2.4)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-70, 14), Vector2(-96, -60), Vector2(-60, -100), Vector2(60, -100), Vector2(96, -60), Vector2(70, 14)]), 3), stone, 4.4, 1.0)
	# Cracks glowing with orichalcum.
	Art.line_c(ci, PackedVector2Array([Vector2(-40, -80), Vector2(-24, -50), Vector2(-34, -20), Vector2(-18, 4)]), Color(ORI, 0.9), 3.0)
	Art.line_c(ci, PackedVector2Array([Vector2(44, -70), Vector2(30, -40), Vector2(40, -10)]), Color(ORI, 0.9), 3.0)
	# Arms: one holds a great bronze shield, the other a stone club.
	var lift := snappedf(maxf(0.0, sin(t * 1.2 * sp)) * 0.4, 0.05)
	Art.push(ci, Vector2(-110, -60), 0.2)
	Art.t_rect(ci, Rect2(-20, 0, 40, 90), 14.0, stone, 3.6, 0.6)
	Art.t_circle(ci, Vector2(-10, 80), 54.0, BRONZE, 4.0, 0.8)
	Art.t_circle(ci, Vector2(-10, 80), 36.0, BRONZE_HI, 2.4, 0.0)
	Art.t_circle(ci, Vector2(-10, 80), 14.0, GOLD, 2.4, 0.0)
	Art.pop(ci)
	Art.push(ci, Vector2(110, -60), -0.4 - lift)
	Art.t_rect(ci, Rect2(-20, 0, 40, 90), 14.0, stone, 3.6, 0.6)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, 80), Vector2(-28, 150), Vector2(0, 176), Vector2(28, 150), Vector2(14, 80)]), 3), Color("9a907c"), 3.6, 0.6)
	Art.pop(ci)
	# Head: a helmet with a tall crest and glowing eyes.
	Art.push(ci, Vector2(0, -126))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-40, 30), Vector2(-46, -16), Vector2(-24, -40), Vector2(24, -40), Vector2(46, -16), Vector2(40, 30)]), 3), BRONZE_HI, 4.0, 0.8)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-10, -38), Vector2(-30, -80), Vector2(20, -90), Vector2(40, -60), Vector2(10, -38)]), 3), Color("e0603c"), 3.0, 0.4)
	Art.t_rect(ci, Rect2(-30, -8, 60, 16), 4.0, Color("140c24"), 3.0, 0.0)
	for s in [-1.0, 1.0]:
		Art.glow(ci, Vector2(s * 14, 0), 18.0, Color(ORI, 0.6))
		Art.t_ellipse(ci, Vector2(s * 14, 0), Vector2(9, 5 * (1.0 - 0.7 * hurt)), ORI if anger < 0.75 else Color("ff4a5a"), 0.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)
