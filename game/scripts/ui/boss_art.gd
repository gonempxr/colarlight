class_name BossArt
extends RefCounted
## The mine bosses (MineBoss) in the game's toon style: thick INK outlines,
## big shiny eyes, shading bands, glows. Drawn around (0, 0) about 260 px
## wide at scale 1; animation goes through Art.push (rotations, offsets) of
## fixed shapes so the geometry cache stays small.
##
##   BossArt.draw(ci, id, at, k, t, hurt, anger)
## hurt 0..1: just hit (flinch, squint, white flash); anger 0..1: low health
## (angry brows, faster moves, a red glow).

const PURPLE := Color("6a4ae0")


static func draw(ci: CanvasItem, id: String, at: Vector2, k: float, t: float, hurt: float = 0.0, anger: float = 0.0) -> void:
	t = snappedf(t, 1.0 / 30.0)
	hurt = snappedf(clampf(hurt, 0.0, 1.0), 0.1)
	anger = snappedf(clampf(anger, 0.0, 1.0), 0.25)
	var shake := Vector2(snappedf(sin(t * 70.0) * 8.0 * hurt, 1.0), 0.0)
	Art.push(ci, at + shake, 0.0, Vector2(k, k) * (1.0 - 0.06 * hurt))
	if anger > 0.0:
		Art.glow(ci, Vector2(0, -10), 190.0, Color(1.0, 0.25, 0.4, 0.22 * anger))
	match id:
		"crabblack":
			_crab(ci, t, hurt, anger)
		"mother_jelly":
			_jelly(ci, t, hurt, anger)
		"shadow_eel":
			_eel(ci, t, hurt, anger)
		"kraken":
			_kraken(ci, t, hurt, anger)
		_:
			_warden(ci, t, hurt, anger)
	Art.pop(ci)


## A big shiny cartoon eye: white, iris, pupil, two glints. `squint` 0..1
## closes it (hurt); `brow` tilts an angry brow over it (side -1 / 1).
static func eye(ci: CanvasItem, c: Vector2, r: float, iris: Color, squint: float, brow: float = 0.0, side: float = 1.0, look := Vector2(0.15, 0.1)) -> void:
	var open := maxf(0.12, 1.0 - squint)
	Art.t_ellipse(ci, c, Vector2(r, r * open), Art.WHITE, 3.0, 0.3)
	if open > 0.3:
		var ic := c + look * r * 0.35
		Art.flat(ci, Art.ellipse_pts(ic, Vector2(r * 0.62, r * 0.62 * open), 20), iris)
		Art.flat(ci, Art.ellipse_pts(ic, Vector2(r * 0.34, r * 0.34 * open), 16), Art.INK)
		Art.flat(ci, Art.circle_pts(ic + Vector2(-r * 0.22, -r * 0.24 * open), r * 0.16, 10), Art.WHITE)
		Art.flat(ci, Art.circle_pts(ic + Vector2(r * 0.2, r * 0.18 * open), r * 0.08, 8), Color(1, 1, 1, 0.85))
	if brow > 0.0:
		var h := r * (1.05 + 0.1 * open)
		Art.push(ci, c + Vector2(0, -h), side * (0.25 + 0.35 * brow))
		Art.toon(ci, Art.rrect_pts(Rect2(-r * 0.9, -r * 0.16, r * 1.8, r * 0.32), r * 0.16), Art.INK, 0.0, 0.0)
		Art.pop(ci)


## A toothy grin (open: 0..1), white teeth on a dark mouth.
static func mouth(ci: CanvasItem, c: Vector2, w: float, open: float, teeth := 4) -> void:
	var h := 6.0 + 18.0 * open
	var m := Art.smooth_pts(PackedVector2Array([c + Vector2(-w, -2), c + Vector2(0, 2), c + Vector2(w, -2), c + Vector2(w * 0.6, h), c + Vector2(-w * 0.6, h)]), 3)
	Art.toon(ci, m, Color("3a1030"), 2.6, 0.0)
	for i in teeth:
		var x := -w * 0.7 + i * (w * 1.4 / maxf(1.0, teeth - 1))
		Art.flat(ci, PackedVector2Array([c + Vector2(x - 4, 0), c + Vector2(x + 4, 0), c + Vector2(x, 7)]), Art.WHITE)
	if open > 0.3:
		Art.flat(ci, Art.ellipse_pts(c + Vector2(0, h * 0.7), Vector2(w * 0.35, h * 0.2), 12), Color("ff6a8a"))


# --- Captain Crabblack --------------------------------------------------------------

static func _crab(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var shell := Color("2f56c0")
	var shell_hi := Color("6a8cf0")
	var belly := Color("ffd0a0")
	var red := Color("ff5a4a")
	var sp := 1.0 + anger
	var bob := snappedf(sin(t * 2.0 * sp) * 4.0, 1.0)
	# Legs (behind), three a side, stepping.
	for s in [-1.0, 1.0]:
		for i in 3:
			var a := 0.5 + i * 0.3 + snappedf(sin(t * 4.0 * sp + i * 1.4 + s) * 0.12, 0.04)
			Art.push(ci, Vector2(s * (50 + i * 16), 50 + bob), s * a)
			Art.toon(ci, Art.rrect_pts(Rect2(-7, 0, 14, 46), 7), shell.darkened(0.15), 3.0, 0.4)
			Art.toon(ci, PackedVector2Array([Vector2(-7, 44), Vector2(7, 44), Vector2(0, 62)]), shell_hi, 2.6, 0.0)
			Art.pop(ci)
	Art.push(ci, Vector2(0, bob))
	# Eye stalks with big eyes (one under a patch), either side of the hat.
	for s in [-1.0, 1.0]:
		var sway := snappedf(sin(t * 2.4 + s) * 0.12, 0.04)
		Art.push(ci, Vector2(s * 44, -26), sway + s * 0.25)
		Art.toon(ci, Art.rrect_pts(Rect2(-7, -46, 14, 48), 7), shell, 2.8, 0.3)
		if s < 0.0:
			eye(ci, Vector2(0, -56), 22.0, Color("ffd23f"), hurt, anger, s)
		else:
			Art.t_circle(ci, Vector2(0, -56), 22.0, Art.INK, 2.4, 0.0)
			Art.flat(ci, Art.ellipse_pts(Vector2(-6, -62), Vector2(6, 4), 10, -0.4), Color(1, 1, 1, 0.25))
			Art.line_c(ci, PackedVector2Array([Vector2(-26, -74), Vector2(24, -40)]), Art.INK, 3.0)
		Art.pop(ci)
	# The shell: wide, shiny, with a pale belly rim.
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-104, 34), Vector2(-96, -4), Vector2(-60, -30), Vector2(0, -40), Vector2(60, -30), Vector2(96, -4),
		Vector2(104, 34), Vector2(64, 60), Vector2(0, 68), Vector2(-64, 60)]), 4)
	Art.toon(ci, body, shell, 4.0, 1.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-80, 40), Vector2(0, 52), Vector2(80, 40), Vector2(60, 60), Vector2(0, 68), Vector2(-60, 60)]), 3), belly, 0.0, 0.3)
	Art.flat(ci, Art.ellipse_pts(Vector2(-40, -10), Vector2(34, 12), 18, -0.2), Color(shell_hi, 0.9))
	for p in [Vector2(-62, 18), Vector2(60, 20), Vector2(30, -14)]:
		Art.t_circle(ci, p, 7.0, shell_hi, 2.2, 0.0)
	mouth(ci, Vector2(0, 26), 30.0, 0.3 + 0.5 * anger + 0.4 * hurt, 4)
	# Tricorn with a skull, between the eyes.
	Art.push(ci, Vector2(0, -50), snappedf(sin(t * 1.6) * 0.05, 0.02))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-50, 8), Vector2(-32, -24), Vector2(0, -36), Vector2(32, -24), Vector2(50, 8), Vector2(0, -4)]), 3), Color("151530"), 3.4, 0.6)
	Art.toon(ci, Art.rrect_pts(Rect2(-40, -2, 80, 11), 5), Art.GOLD, 2.6, 0.3)
	Art.t_circle(ci, Vector2(0, -14), 10.0, Art.WHITE, 2.4, 0.2)
	for sx in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(sx * 3.8, -16), 2.6, Art.INK, 0.0, 0.0)
	Art.pop(ci)
	Art.arc_c(ci, Vector2(96, 14), 9.0, -0.5, 3.6, 12, Art.GOLD, 4.0)
	# Big claws in front, snapping.
	for s in [-1.0, 1.0]:
		var snap := snappedf(maxf(0.0, sin(t * 3.2 * sp + (0.0 if s < 0.0 else 1.6))) * 0.45, 0.05)
		Art.push(ci, Vector2(s * 104, 22), s * (0.7 + snap * 0.3))
		Art.toon(ci, Art.rrect_pts(Rect2(-11, -54, 22, 58), 11), red, 3.2, 0.5)
		Art.push(ci, Vector2(0, -66), 0.0, Vector2(s, 1.0) * 1.25)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-26, 12), Vector2(-30, -16), Vector2(-14, -40), Vector2(6, -44), Vector2(10, -20), Vector2(4, 0), Vector2(18, 12)]), 3), red, 3.4, 0.8)
		Art.flat(ci, Art.ellipse_pts(Vector2(-16, -22), Vector2(5, 10), 12, 0.3), Color(1, 1, 1, 0.5))
		Art.push(ci, Vector2(10, -18), snap * 1.2)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(22, -14), Vector2(30, -36), Vector2(14, -24), Vector2(4, -10)]), 3), red.darkened(0.08), 3.0, 0.5)
		Art.pop(ci)
		Art.pop(ci)
		Art.pop(ci)
	Art.pop(ci)


# --- Mother Jelly -------------------------------------------------------------------

static func _jelly(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var pink := Color("ff7ae6")
	var deep := Color("c54ad6")
	var sp := 1.0 + anger
	var pulse := snappedf(sin(t * 2.2 * sp) * 0.05, 0.01)
	Art.glow(ci, Vector2(0, -20), 170.0, Color(pink, 0.35))
	# Long tentacles: segments rotated in a wave.
	for i in 7:
		var x := -66.0 + i * 22.0
		var pts := PackedVector2Array()
		for j in 7:
			var y := 36.0 + j * 22.0
			pts.append(Vector2(x + snappedf(sin(t * 2.6 * sp + i * 0.9 + j * 0.7) * (6 + j * 2), 1.0), y))
		Art.polyline(ci, pts, Art.INK, 12.0)
		Art.polyline(ci, pts, deep if i % 2 == 0 else pink, 7.0)
	# Frilly arms in front.
	for i in 4:
		var x := -36.0 + i * 24.0
		Art.push(ci, Vector2(x, 34), snappedf(sin(t * 2.0 + i) * 0.15, 0.05))
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-8, 0), Vector2(-12, 30), Vector2(-4, 60), Vector2(6, 58), Vector2(10, 28), Vector2(8, 0)]), 3), Color("ffb3ee", 0.95), 2.6, 0.3)
		Art.pop(ci)
	# The bell, breathing.
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(1.0 + pulse, 1.0 - pulse))
	var bell := Art.smooth_pts(PackedVector2Array([Vector2(-110, 40), Vector2(-104, -20), Vector2(-70, -76), Vector2(0, -100), Vector2(70, -76), Vector2(104, -20),
		Vector2(110, 40), Vector2(80, 30), Vector2(54, 44), Vector2(26, 32), Vector2(0, 46), Vector2(-26, 32), Vector2(-54, 44), Vector2(-80, 30)]), 3)
	Art.toon(ci, bell, Color(pink, 0.95), 4.0, 0.9)
	# Inner glow pattern.
	for i in 5:
		var a := -2.4 + i * 0.42
		Art.line_c(ci, PackedVector2Array([Vector2(0, -40), Vector2(cos(a), sin(a)) * 80.0 + Vector2(0, -20)]), Color(1, 0.9, 1, 0.45), 4.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-46, -58), Vector2(24, 12), 16, -0.5), Color(1, 1, 1, 0.55))
	for s in [-1.0, 1.0]:
		eye(ci, Vector2(s * 34, -6), 20.0, Color("6af8ff"), hurt, anger, s)
		Art.flat(ci, Art.ellipse_pts(Vector2(s * 58, 16), Vector2(12, 6), 12), Color(1.0, 0.45, 0.7, 0.6))
	mouth(ci, Vector2(0, 22), 18.0, 0.2 + 0.5 * anger + 0.4 * hurt, 3)
	# A crown of little glowing jellies.
	for i in 5:
		var p := Vector2(-48 + i * 24, -96 - (12 if i == 2 else (6 if i % 2 == 1 else 0)))
		Art.glow(ci, p, 16.0, Color("6af8ff", 0.6))
		Art.t_circle(ci, p, 8.0, Color("bff8ff"), 2.4, 0.4)
	Art.pop(ci)
	# Babies orbiting.
	for i in 3:
		var a := t * 0.8 * sp + i * TAU / 3.0
		var p := Vector2(cos(a) * 150.0, sin(a) * 40.0 - 30.0)
		Art.push(ci, Vector2(snappedf(p.x, 2.0), snappedf(p.y, 2.0)), 0.0, Vector2.ONE * 1.3)
		Props.jelly(ci, t + i, Color("ffb3ee") if i % 2 == 0 else Color("9afcff"))
		Art.pop(ci)


# --- Shadow Eel ---------------------------------------------------------------------

static func _eel(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var skin := Color("1f2e5c")
	var stripe := Color("4af0e8")
	var sp := 1.0 + anger
	# An S-shaped body made of rings, waving.
	var pts := PackedVector2Array()
	for i in 16:
		var f := i / 15.0
		var x := lerpf(-150.0, 70.0, f)
		var y := 40.0 * sin(f * 5.0 + t * 2.4 * sp) * (1.0 - f * 0.4) + 30.0
		pts.append(Vector2(x, snappedf(y, 1.0)))
	Art.polyline(ci, pts, Art.INK, 46.0)
	Art.polyline(ci, pts, skin, 38.0)
	Art.polyline(ci, pts, skin.lightened(0.15), 16.0)
	for i in range(1, 15, 2):
		Art.glow(ci, pts[i], 14.0, Color(stripe, 0.5))
		Art.t_circle(ci, pts[i], 5.0, stripe, 2.0, 0.0)
	# Back fin along the body.
	for i in range(2, 14, 3):
		var p := pts[i]
		Art.toon(ci, PackedVector2Array([p + Vector2(-10, -16), p + Vector2(0, -34), p + Vector2(10, -16)]), Color("6a4ae0"), 2.4, 0.2)
	# The head.
	var hp := pts[15] + Vector2(44, -24)
	Art.push(ci, hp, snappedf(sin(t * 2.0) * 0.08, 0.02), Vector2.ONE * 1.4)
	var head := Art.smooth_pts(PackedVector2Array([Vector2(-50, 18), Vector2(-46, -24), Vector2(-10, -46), Vector2(40, -36), Vector2(70, -8), Vector2(66, 14),
		Vector2(30, 30), Vector2(-20, 34)]), 3)
	Art.toon(ci, head, skin, 4.0, 0.9)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -28), Vector2(22, 8), 14, -0.2), Color(1, 1, 1, 0.2))
	# Jaw, open wider when angry or hit.
	var jaw := snappedf(0.2 + 0.4 * anger + 0.4 * hurt + 0.15 * maxf(0.0, sin(t * 3.0)), 0.05)
	Art.push(ci, Vector2(10, 14), jaw * 0.5)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-30, 0), Vector2(56, -2), Vector2(50, 18), Vector2(-20, 20)]), 3), skin.darkened(0.15), 3.4, 0.4)
	for i in 5:
		Art.flat(ci, PackedVector2Array([Vector2(-10 + i * 12, 0), Vector2(-4 + i * 12, 0), Vector2(-7 + i * 12, -8)]), Art.WHITE)
	Art.pop(ci)
	for i in 5:
		Art.flat(ci, PackedVector2Array([Vector2(0 + i * 12, 14), Vector2(6 + i * 12, 14), Vector2(3 + i * 12, 22)]), Art.WHITE)
	eye(ci, Vector2(16, -14), 18.0, Color("ffd23f"), hurt, anger, 1.0, Vector2(0.4, 0.0))
	Art.glow(ci, Vector2(16, -14), 30.0, Color("ffd23f", 0.25))
	Art.pop(ci)


# --- Young Kraken -------------------------------------------------------------------

static func _kraken(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var skin := Color("8a3ac8")
	var spot := Color("c87aff")
	var sp := 1.0 + anger
	# Tentacles curling up (OreArt's tentacle, bigger).
	for i in 6:
		var x := -100.0 + i * 40.0
		var s := 1.0 if i >= 3 else -1.0
		Art.push(ci, Vector2(x, 70), s * (0.2 + i % 3 * 0.15), Vector2(2.2 * s, 2.4))
		OreArt.tentacle(ci, t * 1.2 * sp + i * 0.9, skin)
		Art.pop(ci)
	# The head: a big round dome with spots.
	var head := Art.smooth_pts(PackedVector2Array([Vector2(-96, 50), Vector2(-104, -10), Vector2(-80, -86), Vector2(0, -120), Vector2(80, -86), Vector2(104, -10), Vector2(96, 50),
		Vector2(0, 70)]), 4)
	Art.push(ci, Vector2(0, snappedf(sin(t * 1.8 * sp) * 5.0, 1.0)))
	Art.toon(ci, head, skin, 4.0, 1.0)
	for p in [Vector2(-56, -70), Vector2(-20, -96), Vector2(40, -84), Vector2(70, -40), Vector2(-76, -20)]:
		Art.t_circle(ci, p, 9.0, spot, 2.2, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-40, -84), Vector2(26, 12), 16, -0.5), Color(1, 1, 1, 0.35))
	for s in [-1.0, 1.0]:
		eye(ci, Vector2(s * 40, -6), 26.0, Color("ffd23f"), hurt, anger, s)
	mouth(ci, Vector2(0, 40), 22.0, 0.25 + 0.5 * anger + 0.4 * hurt, 3)
	# A pirate bandana.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-84, -70), Vector2(-40, -104), Vector2(40, -104), Vector2(84, -70), Vector2(40, -86), Vector2(-40, -86)]), 3), Color("e8445a"), 3.0, 0.4)
	for p in [Vector2(-40, -94), Vector2(0, -100), Vector2(40, -94)]:
		Art.t_circle(ci, p, 4.0, Art.WHITE, 0.0, 0.0)
	Art.push(ci, Vector2(88, -74), 0.5 + snappedf(sin(t * 3.0) * 0.15, 0.05))
	Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(28, -10), Vector2(22, 12)]), Color("e8445a"), 2.6, 0.3)
	Art.pop(ci)
	Art.pop(ci)


# --- The Twilight Warden (act I's last guardian) -------------------------------------

static func _warden(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var body := Color("2a1e6a")
	var plate := Color("6af8ff")
	var gold := Art.GOLD
	var sp := 1.0 + anger
	var bob := snappedf(sin(t * 1.6 * sp) * 6.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	# Tail fin.
	Art.push(ci, Vector2(-120, 0), snappedf(sin(t * 3.0 * sp) * 0.2, 0.05))
	Art.toon(ci, PackedVector2Array([Vector2(10, 0), Vector2(-50, -60), Vector2(-36, 0), Vector2(-50, 60)]), Color("5a3ec8"), 3.4, 0.5)
	Art.pop(ci)
	# The lure on its stalk, a lantern of the Coral Light.
	var lure := Vector2(70, -170 + snappedf(sin(t * 2.0) * 6.0, 1.0))
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(10, -96), Vector2(30, -150), Vector2(60, -180), lure]), 3), Art.INK, 7.0)
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(10, -96), Vector2(30, -150), Vector2(60, -180), lure]), 3), Color("4a3a8c"), 3.5)
	Art.glow(ci, lure, 60.0, Color(plate, 0.6))
	Art.toon(ci, PackedVector2Array([lure + Vector2(0, -20), lure + Vector2(14, 0), lure + Vector2(0, 20), lure + Vector2(-14, 0)]), Color("bff8ff"), 3.0, 0.3)
	# Body.
	var b := Art.smooth_pts(PackedVector2Array([Vector2(-130, 10), Vector2(-110, -60), Vector2(-40, -104), Vector2(40, -100), Vector2(110, -60), Vector2(140, 0),
		Vector2(110, 60), Vector2(30, 90), Vector2(-60, 84), Vector2(-120, 50)]), 4)
	Art.toon(ci, b, body, 4.4, 1.0)
	# Armour plates with glowing trim.
	for p in [Vector3(-70, -60, -0.5), Vector3(-20, -84, -0.15), Vector3(36, -80, 0.2), Vector3(-90, 10, -1.2)]:
		Art.push(ci, Vector2(p.x, p.y), p.z)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-26, 10), Vector2(-20, -14), Vector2(0, -22), Vector2(20, -14), Vector2(26, 10)]), 3), Color("4a3ab0"), 3.0, 0.5)
		Art.line_c(ci, PackedVector2Array([Vector2(-20, 4), Vector2(0, -12), Vector2(20, 4)]), plate, 3.0)
		Art.pop(ci)
	# A crest of spikes.
	for i in 5:
		var a := -2.2 + i * 0.32
		var p := Vector2(cos(a), sin(a)) * 96.0 + Vector2(-10, 0)
		Art.toon(ci, PackedVector2Array([p + Vector2(-9, 4), p + Vector2(cos(a), sin(a)) * 30.0, p + Vector2(9, 4)]), Color("c9a3ff"), 3.0, 0.2)
	# The face: a huge jaw with fangs and one great eye.
	var jaw := snappedf(0.2 + 0.35 * anger + 0.4 * hurt + 0.12 * maxf(0.0, sin(t * 2.4)), 0.05)
	Art.push(ci, Vector2(60, 30), jaw * 0.6)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-40, -10), Vector2(80, -16), Vector2(74, 30), Vector2(-20, 34)]), 3), Color("1a1238"), 3.6, 0.2)
	for i in 6:
		Art.flat(ci, PackedVector2Array([Vector2(-20 + i * 15, -10), Vector2(-12 + i * 15, -10), Vector2(-16 + i * 15, 2)]), Art.WHITE)
	Art.pop(ci)
	for i in 6:
		Art.flat(ci, PackedVector2Array([Vector2(44 + i * 15, 22), Vector2(52 + i * 15, 22), Vector2(48 + i * 15, 10)]), Art.WHITE)
	Art.glow(ci, Vector2(60, -30), 54.0, Color(1.0, 0.3, 0.45, 0.3 + 0.3 * anger))
	eye(ci, Vector2(60, -30), 30.0, Color("ff4a7a"), hurt, anger, 1.0, Vector2(0.3, 0.1))
	# A golden circlet with the Warden's gem.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(10, -78), Vector2(60, -96), Vector2(110, -70), Vector2(104, -58), Vector2(60, -82), Vector2(14, -66)]), 3), gold, 3.0, 0.4)
	Art.toon(ci, PackedVector2Array([Vector2(60, -108), Vector2(70, -92), Vector2(60, -78), Vector2(50, -92)]), Color("ff4a7a"), 2.6, 0.3)
	Art.pop(ci)


## A small round portrait of a boss (cards, the mine's lair label).
static func portrait(ci: CanvasItem, id: String, c: Vector2, r: float, t: float) -> void:
	Art.t_circle(ci, c, r, Color("2a1e6a"), 3.0, 0.0)
	draw(ci, id, c + Vector2(0, r * 0.15), r / 170.0, t)
