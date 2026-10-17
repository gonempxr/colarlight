class_name BossArtRlyeh
extends RefCounted
## Act III's guards (R'lyeh) for BossArt.draw: the Deep One Priest, the
## Shoggoth, the Priest of Dagon, the Star-Spawn and the Ancient One (three
## phases). Same rules as BossArt: about 260 px wide at scale 1, toon
## outlines, big eyes, motion only through pushes of fixed shapes.

const SKIN := Color("4aa88a")
const SKIN_DARK := Color("2a6a5a")
const ROBE := Color("3a2a5a")
const SLIME := Color("7dff6a")
const VIOLET := Color("8a4cf0")
const BONE := Color("e8e0c8")
const BLACK := Color("1a2422")

## The Ancient One's phase 1..3 (BossScreen sets it before drawing).
static var phase := 1
## The Star-Spawn is up in the water, out of reach (BossScreen sets it).
static var flying := false


static func draw(ci: CanvasItem, id: String, t: float, hurt: float, anger: float) -> bool:
	match id:
		"deep_one_priest":
			_priest(ci, t, hurt, anger)
		"shoggoth":
			_shoggoth(ci, t, hurt, anger)
		"dagon_priest":
			_dagon(ci, t, hurt, anger)
		"star_spawn":
			_spawn(ci, t, hurt, anger)
		"ancient_one":
			_ancient(ci, t, hurt, anger)
		_:
			return false
	return true


## A tentacle hanging from (0, 0) down `len` px, swaying with `t`.
static func _hang(ci: CanvasItem, len: float, w: float, col: Color, t: float, seed: float) -> void:
	var sway := snappedf(sin(t * 1.8 + seed) * 0.25, 0.05)
	Art.push(ci, Vector2.ZERO, sway)
	var pts := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.7, len * 0.5), Vector2(w * 0.6, len * 0.85), Vector2(w * 1.6, len),
		Vector2(w * 0.9, len * 0.86), Vector2(w * 0.5, len * 0.5), Vector2(w, 0)])
	Art.toon(ci, Art.smooth_pts(pts, 3), col, 3.0, 0.5)
	for k in 3:
		Art.t_circle(ci, Vector2(w * 0.1, len * (0.25 + k * 0.2)), w * 0.25, col.lightened(0.35), 1.2, 0.0)
	Art.pop(ci)


# --- The Deep One Priest ----------------------------------------------------------------

static func _priest(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var bob := snappedf(sin(t * 1.6 * sp) * 5.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-50, -50), Vector2(-90, 110), Vector2(90, 110), Vector2(50, -50)]), 3), ROBE, 4.4, 1.0)
	for k in 3:
		RlyehArt._glyph(ci, Vector2(-40 + k * 40, 50), 10.0, Color(SLIME, 0.8), k)
	# The staff with a green orb.
	var sw := snappedf(sin(t * 2.0 * sp) * 0.08, 0.02)
	Art.push(ci, Vector2(-92, 10), sw - 0.1)
	Art.t_rect(ci, Rect2(-5, -150, 10, 230), 3.0, Color("5a4a3a"), 3.0, 0.4)
	Art.glow(ci, Vector2(0, -164), 34.0, Color(SLIME, 0.45))
	Art.t_circle(ci, Vector2(0, -164), 16.0, SLIME, 3.0, 0.3)
	Art.pop(ci)
	# Webbed hands.
	for s: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(s * 70, 20), 16.0, SKIN, 3.0, 0.5)
	# The fish head: wide mouth, gill frills, big round eyes.
	Art.push(ci, Vector2(0, -88))
	for s: float in [-1.0, 1.0]:
		Art.toon(ci, PackedVector2Array([Vector2(s * 40, -10), Vector2(s * 76, -40), Vector2(s * 70, 0), Vector2(s * 78, 24), Vector2(s * 40, 20)]), SKIN_DARK, 3.0, 0.5)
	Art.toon(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(54, 46), 24), SKIN, 4.0, 0.8)
	for s: float in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 24, -10), 16.0, Color("ffe066"), hurt, maxf(0.4, anger), s)
	BossArt.mouth(ci, Vector2(0, 20), 30.0, 0.3 + 0.5 * anger + 0.3 * hurt, 6)
	# A tall priest's hood.
	Art.toon(ci, PackedVector2Array([Vector2(-40, -30), Vector2(0, -100), Vector2(40, -30)]), ROBE.lightened(0.1), 3.4, 0.6)
	Art.t_circle(ci, Vector2(0, -56), 7.0, SLIME, 2.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)


# --- The Shoggoth -----------------------------------------------------------------------

static func _shoggoth(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var wob := snappedf(sin(t * 3.0 * sp) * 0.04, 0.01)
	Art.push(ci, Vector2(0, 20), 0.0, Vector2(1.0 + wob, 1.0 - wob))
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-120, 90), Vector2(-130, 10), Vector2(-90, -70), Vector2(-30, -110), Vector2(40, -100),
		Vector2(100, -60), Vector2(130, 20), Vector2(120, 90)]), 4)
	Art.toon(ci, body, BLACK.lightened(0.12), 4.4, 1.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-30, -60), Vector2(50, 18), 16, -0.3), Color(SLIME, 0.25))
	# Eyes everywhere, blinking out of step.
	var eyes := [Vector3(-60, -40, 16), Vector3(10, -70, 20), Vector3(70, -20, 14), Vector3(-90, 20, 11), Vector3(40, 30, 17),
		Vector3(-20, 10, 12), Vector3(90, 50, 10), Vector3(-50, 60, 9)]
	for i in eyes.size():
		var e: Vector3 = eyes[i]
		var shut := fmod(t + i * 0.7, 3.4) < 0.15
		BossArt.eye(ci, Vector2(e.x, e.y), e.z, SLIME if i % 2 == 0 else Color("ff5a7a"), 1.0 if shut else hurt, anger, 1.0 if i % 2 == 0 else -1.0)
	# Mouths.
	BossArt.mouth(ci, Vector2(-10, 60), 26.0, 0.4 + 0.4 * anger + 0.3 * hurt, 5)
	BossArt.mouth(ci, Vector2(80, -60), 14.0, 0.3 + 0.3 * anger, 3)
	Art.pop(ci)


# --- The Priest of Dagon ----------------------------------------------------------------

static func _dagon(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var bob := snappedf(sin(t * 1.3 * sp) * 4.0, 1.0)
	Art.push(ci, Vector2(0, bob))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-56, -60), Vector2(-100, 116), Vector2(-40, 104), Vector2(0, 118), Vector2(40, 104),
		Vector2(100, 116), Vector2(56, -60)]), 3), Color("1e3a3a"), 4.4, 1.0)
	Art.toon(ci, PackedVector2Array([Vector2(-20, -60), Vector2(20, -60), Vector2(14, 110), Vector2(-14, 110)]), Color("c8a040"), 2.6, 0.4)
	# The curse orb in its claws.
	var pulse := snappedf(0.5 + 0.5 * sin(t * 3.0), 0.25)
	Art.glow(ci, Vector2(80, -10), 44.0 + 10.0 * pulse, Color(VIOLET, 0.4))
	Art.t_circle(ci, Vector2(80, -10), 20.0, VIOLET, 3.0, 0.4)
	Art.t_circle(ci, Vector2(80, -10), 8.0, SLIME, 0.0, 0.0)
	for s: float in [-1.0, 1.0]:
		Art.toon(ci, PackedVector2Array([Vector2(s * 60 + 10, 10), Vector2(s * 76 + 10, -26), Vector2(s * 94 + 10, 6)]), SKIN, 2.6, 0.4)
	# A fish-shaped mitre over a scaly face.
	Art.push(ci, Vector2(0, -100))
	Art.toon(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(40, 42), 22), SKIN, 4.0, 0.8)
	for s: float in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 17, 0), 12.0, Color("ff5a7a"), hurt, maxf(0.6, anger), s)
	BossArt.mouth(ci, Vector2(0, 22), 18.0, 0.2 + 0.5 * anger + 0.3 * hurt, 4)
	Art.toon(ci, PackedVector2Array([Vector2(-38, -24), Vector2(-28, -96), Vector2(0, -126), Vector2(28, -96), Vector2(38, -24)]), Color("c8a040"), 3.4, 0.5)
	Art.toon(ci, PackedVector2Array([Vector2(-16, -100), Vector2(0, -116), Vector2(16, -100), Vector2(0, -84)]), Color("1e3a3a"), 2.2, 0.0)
	Art.t_circle(ci, Vector2(0, -60), 9.0, SLIME, 2.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)


# --- The Star-Spawn ---------------------------------------------------------------------

static func _spawn(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger
	var up := -150.0 if flying else 0.0
	var bob := snappedf(sin(t * 2.4 * sp) * 8.0, 1.0)
	Art.push(ci, Vector2(0, up + bob), 0.0, Vector2(0.8, 0.8) if flying else Vector2.ONE)
	# Bat wings.
	var flap := snappedf(sin(t * (8.0 if flying else 3.0)) * 0.25, 0.05)
	for s: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(s * 50, -40), s * flap)
		Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(s * 70, -80), Vector2(s * 150, -60), Vector2(s * 120, -20), Vector2(s * 140, 20), Vector2(s * 90, 10), Vector2(s * 60, 40)]), VIOLET.darkened(0.3), 3.4, 0.6)
		Art.pop(ci)
	# Body.
	Art.toon(ci, Art.ellipse_pts(Vector2(0, 20), Vector2(64, 70), 24), SKIN_DARK, 4.4, 1.0)
	# The octopus head with a tentacle beard.
	for k in 5:
		Art.push(ci, Vector2(-36 + k * 18, -20))
		_hang(ci, 70.0 + (k % 2) * 16.0, 7.0, SKIN, t, k)
		Art.pop(ci)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-56, -20), Vector2(-60, -90), Vector2(0, -130), Vector2(60, -90), Vector2(56, -20)]), 3), SKIN, 4.0, 0.8)
	for s: float in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 22, -62), 14.0, SLIME, hurt, maxf(0.4, anger), s)
	Art.pop(ci)


# --- The Ancient One --------------------------------------------------------------------

static func _ancient(ci: CanvasItem, t: float, hurt: float, anger: float) -> void:
	var sp := 1.0 + anger * 0.5
	var bob := snappedf(sin(t * 1.0 * sp) * 6.0, 1.0)
	var awake := phase >= 3
	Art.push(ci, Vector2(0, bob), 0.0, Vector2(1.15, 1.15))
	if awake:
		Art.glow(ci, Vector2(0, -60), 200.0, Color(1.0, 0.2, 0.3, 0.2))
	# Wings behind (spread wider each phase).
	var spread := 0.15 * (phase - 1)
	for s: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(s * 60, -60), s * (-0.2 + spread))
		Art.toon(ci, PackedVector2Array([Vector2(0, 20), Vector2(s * 60, -90), Vector2(s * 150, -110), Vector2(s * 120, -60), Vector2(s * 160, -20), Vector2(s * 100, -10), Vector2(s * 80, 40)]), BLACK.lightened(0.15), 3.4, 0.6)
		Art.pop(ci)
	# Shoulders.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-120, 110), Vector2(-110, 10), Vector2(-60, -30), Vector2(60, -30), Vector2(110, 10), Vector2(120, 110)]), 3), SKIN_DARK, 4.4, 1.0)
	# The tentacle beard: hangs in phase 1, reaches out from phase 2.
	for k in 7:
		var x := -54 + k * 18
		Art.push(ci, Vector2(x, -10), (k - 3) * (0.12 if phase >= 2 else 0.03))
		_hang(ci, (90.0 if phase >= 2 else 60.0) + (k % 3) * 14.0, 8.0, SKIN, t, k * 0.9)
		Art.pop(ci)
	# The great head.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-70, -10), Vector2(-80, -110), Vector2(-30, -170), Vector2(30, -170), Vector2(80, -110), Vector2(70, -10)]), 3), SKIN, 4.4, 0.9)
	# Eyes: shut in phase 1 (but a third eye watches), all open later.
	for s: float in [-1.0, 1.0]:
		if phase == 1:
			Art.line(ci, Vector2(s * 28 - 16, -80), Vector2(s * 28 + 16, -80), Art.INK, 4.0)
		else:
			BossArt.eye(ci, Vector2(s * 28, -80), 18.0, Color("ff3a5a") if awake else SLIME, hurt, maxf(0.5, anger), s)
	BossArt.eye(ci, Vector2(0, -126), 12.0 if phase == 1 else 15.0, Color("ffe066"), hurt, 0.0)
	Art.pop(ci)
