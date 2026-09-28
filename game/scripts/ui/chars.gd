class_name Chars
extends RefCounted
## Every character: chibi people (workers, the businessman, managers, the
## player's avatar) and divers in brass helmets. Faces carry emotions.
##
## A "look" describes a person: skin, hair, hair color, hat, face extra,
## outfit color and clothes. A "pose" describes the moment: emotion,
## blink, arm angles, walk phase and what the right hand holds.

const SKINS: Array[Color] = [Color("ffe2c8"), Color("f8caa0"), Color("e3aa7a"), Color("c4885c"), Color("8e5b3c"), Color("603c28")]
const HAIR_COLORS: Array[Color] = [Color("3b2a20"), Color("7a4a2a"), Color("f0bd52"), Color("d8562e"), Color("eeeae2"), Color("ff7ab8"), Color("5ab8ff"), Color("8a6cf0")]
const HAIR_STYLES: Array[String] = ["short", "spiky", "long", "bun", "curly", "mohawk", "bald"]
const HATS: Array[String] = ["none", "tophat", "hardhat", "captain", "sailor", "beanie", "cap", "pirate", "crown", "flower"]
const EXTRAS: Array[String] = ["none", "glasses", "sunglasses", "mustache", "beard", "freckles"]
const OUTFITS: Array[Color] = [Color("35507e"), Color("3aa6f0"), Color("ff7a59"), Color("5cd05f"), Color("8a6cf0"), Color("ffc93c"), Color("ef5350"), Color("2bc8b4")]
const CLOTHES: Array[String] = ["suit", "shirt", "overalls", "sailor", "vest", "lab"]

const EMOTIONS := {
	# eyes, mouth, brows
	"happy": ["open", "smile", ""],
	"joy": ["arc", "grin", "raised"],
	"focus": ["narrow", "tongue", "angry"],
	"wow": ["wide", "o", "raised"],
	"sleepy": ["closed", "flat", ""],
	"strain": ["x", "wavy", "worried"],
	"rich": ["star", "grin", "raised"],
	"sad": ["open", "frown", "worried"],
	"bored": ["narrow", "flat", ""],
}


static func look(skin: int, hair: String, hair_color: int, hat: String, extra: String, outfit: int, clothes: String) -> Dictionary:
	return {"skin": skin, "hair": hair, "hair_color": hair_color, "hat": hat, "extra": extra, "outfit": outfit, "clothes": clothes}


## Stage managers: each has a personality of their own.
static func manager_look(key: String) -> Dictionary:
	match key:
		"d0": return look(1, "short", 4, "beanie", "beard", 2, "sailor")
		"d1": return look(3, "bun", 5, "flower", "freckles", 5, "shirt")
		"d2": return look(0, "curly", 4, "none", "glasses", 7, "shirt")
		"d3": return look(4, "short", 0, "hardhat", "mustache", 3, "overalls")
		"d4": return look(2, "long", 0, "pirate", "none", 4, "shirt")
		"d5": return look(1, "spiky", 6, "none", "sunglasses", 7, "lab")
		"boat": return look(2, "short", 1, "captain", "beard", 0, "sailor")
		"plant": return look(3, "short", 0, "hardhat", "glasses", 2, "vest")
	return default_avatar()


static func default_avatar() -> Dictionary:
	return look(1, "short", 1, "tophat", "none", 0, "suit")


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	return look(rng.randi_range(0, SKINS.size() - 1), HAIR_STYLES[rng.randi_range(0, HAIR_STYLES.size() - 1)],
			rng.randi_range(0, HAIR_COLORS.size() - 1), HATS[rng.randi_range(0, HATS.size() - 1)],
			EXTRAS[rng.randi_range(0, EXTRAS.size() - 1)], rng.randi_range(0, OUTFITS.size() - 1),
			CLOTHES[rng.randi_range(0, CLOTHES.size() - 1)])


static func _skin(l: Dictionary) -> Color:
	return SKINS[clampi(int(l.get("skin", 1)), 0, SKINS.size() - 1)]


static func _hair_color(l: Dictionary) -> Color:
	return HAIR_COLORS[clampi(int(l.get("hair_color", 0)), 0, HAIR_COLORS.size() - 1)]


static func _outfit(l: Dictionary) -> Color:
	return OUTFITS[clampi(int(l.get("outfit", 0)), 0, OUTFITS.size() - 1)]


## Natural blinking: true for ~0.12 s every few seconds, offset per character.
static func blinking(t: float, seed: float) -> bool:
	return fposmod(t + seed * 1.7, 3.3 + fposmod(seed, 1.0)) < 0.12


# --- Face ------------------------------------------------------------------------

## Face in head space (head radius 20). `look_dir` shifts pupils.
static func face(ci: CanvasItem, emotion: String, blink: bool, skin: Color, look_dir: Vector2 = Vector2.ZERO) -> void:
	var e: Array = EMOTIONS.get(emotion, EMOTIONS["happy"])
	var eyes: String = e[0]
	var mouth: String = e[1]
	var brows: String = e[2]
	if blink and eyes in ["open", "wide", "narrow"]:
		eyes = "closed"
	# Cheeks.
	Art.flat(ci, Art.ellipse_pts(Vector2(-11.5, 8.5), Vector2(4, 2.6), 12), Color(1.0, 0.45, 0.5, 0.35))
	Art.flat(ci, Art.ellipse_pts(Vector2(11.5, 8.5), Vector2(4, 2.6), 12), Color(1.0, 0.45, 0.5, 0.35))
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(7.0 * sx, 1.5)
		match eyes:
			"open", "wide", "narrow":
				var big := 1.18 if eyes == "wide" else 1.0
				Art.toon(ci, Art.ellipse_pts(c, Vector2(4.3, 5.3) * big, 16), Art.WHITE, 1.2, 0.0)
				var pupil := c + look_dir * 1.6 + Vector2(0.4, 0.6)
				var pr := Vector2(2.5, 3.1) * (0.8 if eyes == "wide" else 1.0)
				Art.flat(ci, Art.ellipse_pts(pupil, pr, 12), Art.INK)
				Art.flat(ci, Art.circle_pts(pupil + Vector2(-0.9, -1.3), 1.1, 8), Art.WHITE)
				if eyes == "narrow":
					# Heavy lid over the top half.
					Art.flat(ci, PackedVector2Array([c + Vector2(-5.6, -6.5), c + Vector2(5.6, -6.5), c + Vector2(5.6, -0.6), c + Vector2(-5.6, -0.2 + sx * 0.8)]), skin)
					Art.line(ci, c + Vector2(-5.0, -0.2 + sx * 0.8), c + Vector2(5.0, -0.6), Art.INK, 1.6)
			"arc":
				Art.arc(ci, c + Vector2(0, 2.5), 3.8, PI + 0.35, TAU - 0.35, 10, Art.INK, 2.2)
			"closed":
				Art.arc(ci, c + Vector2(0, -1.0), 3.8, 0.35, PI - 0.35, 10, Art.INK, 2.0)
			"x":
				Art.line(ci, c + Vector2(-3, -3), c + Vector2(3, 0), Art.INK, 2.0)
				Art.line(ci, c + Vector2(-3, 3), c + Vector2(3, 0), Art.INK, 2.0) if sx > 0 else Art.line(ci, c + Vector2(3, 3), c + Vector2(-3, 0), Art.INK, 2.0)
				if sx < 0:
					Art.line(ci, c + Vector2(3, -3), c + Vector2(-3, 0), Art.INK, 2.0)
			"star":
				Art.toon(ci, Art.star_pts(c, 5.2, 2.3, 5), Art.GOLD, 1.0, 0.0)
		match brows:
			"angry":
				Art.line(ci, c + Vector2(-3.5 * sx, -8.5), c + Vector2(3.0 * sx, -6.0), Art.INK, 1.8)
			"worried":
				Art.line(ci, c + Vector2(-3.5 * sx, -6.5), c + Vector2(3.0 * sx, -9.0), Art.INK, 1.8)
			"raised":
				Art.arc(ci, c + Vector2(0, -6.5), 3.5, PI + 0.5, TAU - 0.5, 8, Art.INK, 1.6)
	# Nose.
	Art.flat(ci, Art.ellipse_pts(Vector2(0.5, 7.0), Vector2(2.0, 1.4), 10), Art.shade_of(skin, 0.18))
	var m := Vector2(0.5, 12.0)
	match mouth:
		"smile":
			Art.arc(ci, m + Vector2(0, -2.5), 4.0, 0.45, PI - 0.45, 10, Art.INK, 1.8)
		"grin":
			var pts := PackedVector2Array([m + Vector2(-5.2, -1.6), m + Vector2(5.2, -1.6), m + Vector2(3.8, 2.6), m + Vector2(0, 4.2), m + Vector2(-3.8, 2.6)])
			Art.toon(ci, pts, Color("7a1f33"), 1.2, 0.0)
			Art.flat(ci, Art.ellipse_pts(m + Vector2(0, 2.4), Vector2(2.6, 1.3), 10), Color("ff7f93"))
			Art.flat(ci, PackedVector2Array([m + Vector2(-4.2, -1.4), m + Vector2(4.2, -1.4), m + Vector2(3.9, -0.3), m + Vector2(-3.9, -0.3)]), Art.WHITE)
		"tongue":
			Art.arc(ci, m + Vector2(0, -2.5), 3.6, 0.5, PI - 0.5, 10, Art.INK, 1.8)
			Art.toon(ci, Art.ellipse_pts(m + Vector2(2.4, 1.6), Vector2(1.8, 2.2), 10), Color("ff7f93"), 1.0, 0.0)
		"o":
			Art.toon(ci, Art.ellipse_pts(m + Vector2(0, 0.5), Vector2(2.4, 3.0), 12), Color("7a1f33"), 1.2, 0.0)
		"flat":
			Art.line(ci, m + Vector2(-2.8, 0), m + Vector2(2.8, 0), Art.INK, 1.8)
		"frown":
			Art.arc(ci, m + Vector2(0, 2.8), 3.6, PI + 0.5, TAU - 0.5, 10, Art.INK, 1.8)
		"wavy":
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(m + Vector2(-4.5 + i * 1.5, sin(i * 2.2) * 1.0))
			Art.polyline(ci, pts, Art.INK, 1.6)


## Sweat drop, "Zzz", "!" and other little marks around a head.
static func mark(ci: CanvasItem, kind: String, at: Vector2, t: float) -> void:
	match kind:
		"sweat":
			var y := fposmod(t * 1.5, 1.0) * 6.0
			Art.toon(ci, PackedVector2Array([at + Vector2(0, -6 + y), at + Vector2(3.5, 1 + y), at + Vector2(0, 4 + y), at + Vector2(-3.5, 1 + y)]), Color("9fe6ff"), 1.3, 0.0)
		"zzz":
			for i in 3:
				var f := fposmod(t * 0.6 + i / 3.0, 1.0)
				Art.text(ci, at + Vector2(f * 14.0 + i * 3.0, -f * 26.0), "z", int(12 + f * 8), Color(1, 1, 1, 1.0 - f), 3)
		"!":
			Art.text(ci, at + Vector2(0, sin(t * 12.0) * 2.0), "!", 26, Art.GOLD, 5)
		"heart":
			var s := 1.0 + sin(t * 10.0) * 0.12
			Art.push(ci, at, 0.0, Vector2(s, s))
			Art.toon(ci, Art.union([Art.circle_pts(Vector2(-3.2, -2), 3.8, 14), Art.circle_pts(Vector2(3.2, -2), 3.8, 14),
					PackedVector2Array([Vector2(-6.6, -0.6), Vector2(6.6, -0.6), Vector2(0, 7.5)])]), Color("ff5d8f"), 1.4, 0.0)
			Art.pop(ci)
		"note":
			Art.text(ci, at + Vector2(sin(t * 3.0) * 3.0, 0), "♪", 22, Art.WHITE, 4)


# --- Heads -------------------------------------------------------------------------

## Head at the origin, radius 20, with hair, hat and face extras.
static func head(ci: CanvasItem, l: Dictionary, emotion: String, blink: bool, look_dir: Vector2 = Vector2.ZERO) -> void:
	var skin := _skin(l)
	var hc := _hair_color(l)
	var hair: String = l.get("hair", "short")
	var hat: String = l.get("hat", "none")
	var extra: String = l.get("extra", "none")
	# Behind the head.
	match hair:
		"long":
			Art.t_rect(ci, Rect2(-23, -16, 46, 44), 18, hc, 2.5, 0.6)
		"bun":
			Art.t_circle(ci, Vector2(0, -25), 9.5, hc, 2.5, 0.6)
	for sx: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(19.5 * sx, 3), 5.0, skin, 2.2, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(19.8 * sx, 3.3), 2.2, 10), Art.shade_of(skin, 0.2))
	Art.toon(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(20, 19.5), 36), skin, 2.5, 0.55)
	face(ci, emotion, blink, skin, look_dir)
	match extra:
		"beard":
			var beard := Art.smooth_pts(PackedVector2Array([Vector2(-19, 3), Vector2(-15, 15), Vector2(-7, 24), Vector2(0, 27),
					Vector2(7, 24), Vector2(15, 15), Vector2(19, 3), Vector2(13, 10), Vector2(6, 9.5), Vector2(0.5, 9), Vector2(-5, 9.5), Vector2(-13, 10)]), 3)
			Art.toon(ci, beard, hc, 2.2, 0.5)
			Art.toon(ci, PackedVector2Array([Vector2(-4, 11.5), Vector2(4.5, 11.5), Vector2(3, 14.5), Vector2(0.5, 15.5), Vector2(-2.5, 14.5)]), Color("7a1f33"), 1.2, 0.0)
		"mustache":
			for sx: float in [-1.0, 1.0]:
				Art.toon(ci, PackedVector2Array([Vector2(0.5, 8.5), Vector2(0.5 + 4 * sx, 7.5), Vector2(0.5 + 9 * sx, 10.5),
						Vector2(0.5 + 10.5 * sx, 8.0), Vector2(0.5 + 8 * sx, 12.5), Vector2(0.5 + 3 * sx, 11.2)]), hc, 1.5, 0.0)
		"glasses":
			for sx: float in [-1.0, 1.0]:
				Art.arc(ci, Vector2(7 * sx, 1.5), 6.3, 0, TAU, 20, Art.INK, 2.0)
				Art.flat(ci, Art.circle_pts(Vector2(7 * sx, 1.5), 5.4, 16), Color(0.75, 0.95, 1.0, 0.25))
			Art.line(ci, Vector2(-1, 0.5), Vector2(1, 0.5), Art.INK, 2.0)
		"sunglasses":
			for sx: float in [-1.0, 1.0]:
				Art.toon(ci, Art.rrect_pts(Rect2(7 * sx - 6, -3, 12, 8.5), 3.5), Color("2a2240"), 1.4, 0.0)
				Art.line(ci, Vector2(7 * sx - 3.5, -1), Vector2(7 * sx - 1, -1), Color(1, 1, 1, 0.7), 1.4)
			Art.line(ci, Vector2(-1.5, -0.5), Vector2(1.5, -0.5), Art.INK, 2.0)
		"freckles":
			for p: Vector2 in [Vector2(-12, 7), Vector2(-9.5, 9.5), Vector2(-13.5, 10), Vector2(12, 7), Vector2(9.5, 9.5), Vector2(13.5, 10)]:
				Art.flat(ci, Art.circle_pts(p, 0.9, 6), Color("b5653c"))
	# Hair on top.
	if hat in ["none", "flower", "crown"] or hair in ["long", "bun"]:
		_hair_front(ci, hair, hc)
	elif hair != "bald":
		# Tufts peeking out from under a hat.
		Art.toon(ci, PackedVector2Array([Vector2(-20, -4), Vector2(-17, -12), Vector2(-12, -8), Vector2(-14, 2)]), hc, 1.8, 0.0)
		Art.toon(ci, PackedVector2Array([Vector2(20, -4), Vector2(17, -12), Vector2(12, -8), Vector2(14, 2)]), hc, 1.8, 0.0)
	_hat(ci, hat)


static func _hair_front(ci: CanvasItem, hair: String, hc: Color) -> void:
	match hair:
		"short", "long", "bun":
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-21, 1), Vector2(-21, -12), Vector2(-10, -22), Vector2(4, -23),
					Vector2(17, -16), Vector2(21, -4), Vector2(20, 3), Vector2(14, -6), Vector2(4, -9), Vector2(-4, -6), Vector2(-12, -8), Vector2(-17, -4)]), 3), hc, 2.3, 0.5)
		"spiky":
			var pts := PackedVector2Array()
			var ctrl := [Vector2(-21, 2), Vector2(-24, -10), Vector2(-17, -12), Vector2(-20, -24), Vector2(-9, -19), Vector2(-6, -31),
					Vector2(2, -20), Vector2(10, -30), Vector2(12, -18), Vector2(23, -22), Vector2(19, -10), Vector2(24, -4), Vector2(20, 2),
					Vector2(12, -6), Vector2(4, -10), Vector2(-5, -6), Vector2(-14, -6)]
			for v in ctrl:
				pts.append(v)
			Art.toon(ci, pts, hc, 2.3, 0.5)
		"curly":
			var circles := []
			for i in 9:
				var a := PI + i * PI / 8.0
				circles.append(Art.circle_pts(Vector2(cos(a) * 18.0, sin(a) * 16.0 - 3.0), 7.5, 14))
			Art.toon(ci, Art.union(circles), hc, 2.3, 0.5)
		"mohawk":
			var pts := PackedVector2Array([Vector2(-6, -14), Vector2(-9, -26), Vector2(-3, -22), Vector2(0, -33), Vector2(4, -23), Vector2(10, -28), Vector2(8, -14), Vector2(0, -18)])
			Art.toon(ci, pts, hc, 2.3, 0.4)
		"bald":
			Art.flat(ci, Art.ellipse_pts(Vector2(-7, -12), Vector2(5, 2.5), 12, -0.5), Color(1, 1, 1, 0.45))


static func _hat(ci: CanvasItem, hat: String) -> void:
	match hat:
		"tophat":
			Art.t_rect(ci, Rect2(-15, -52, 30, 36), 5, Color("2e2a3d"), 2.5, 0.5)
			Art.t_rect(ci, Rect2(-15, -26, 30, 7), 2, Art.GOLD, 0.0, 0.0)
			Art.t_ellipse(ci, Vector2(0, -17), Vector2(25, 5.5), Color("2e2a3d"), 2.5, 0.3)
		"hardhat":
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(Vector2(cos(a) * 22.0, -10.0 + sin(a) * 18.0))
			Art.toon(ci, dome, Color("ffcf33"), 2.5, 0.6)
			Art.t_rect(ci, Rect2(-27, -13, 54, 7), 3.5, Color("f4b400"), 2.5, 0.0)
			Art.t_rect(ci, Rect2(-3, -30, 6, 18), 3, Color("ffe07a"), 0.0, 0.0)
			Art.t_circle(ci, Vector2(0, -18), 4.5, Color("fff6c2"), 2.0, 0.0)
		"captain":
			Art.toon(ci, PackedVector2Array([Vector2(-19, -14), Vector2(-24, -30), Vector2(-14, -36), Vector2(14, -36), Vector2(24, -30), Vector2(19, -14)]), Art.WHITE, 2.5, 0.6)
			Art.t_rect(ci, Rect2(-19, -19, 38, 7), 2, Color("2e2a3d"), 2.0, 0.0)
			Art.t_ellipse(ci, Vector2(3, -12), Vector2(19, 4.5), Color("2e2a3d"), 2.2, 0.0)
			Art.t_circle(ci, Vector2(0, -27), 4.5, Art.GOLD, 1.8, 0.0)
		"sailor":
			Art.t_ellipse(ci, Vector2(0, -21), Vector2(17, 10), Art.WHITE, 2.5, 0.6)
			Art.t_rect(ci, Rect2(-21, -17, 42, 8), 4, Art.WHITE, 2.5, 0.0)
			Art.t_rect(ci, Rect2(-17, -21, 34, 4), 2, Art.BLUE, 0.0, 0.0)
		"beanie":
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(Vector2(cos(a) * 20.5, -9.0 + sin(a) * 17.0))
			Art.toon(ci, dome, Color("e8484f"), 2.5, 0.5)
			Art.t_rect(ci, Rect2(-22, -13, 44, 9), 4, Color("c93239"), 2.5, 0.0)
			Art.t_circle(ci, Vector2(0, -28), 6, Art.WHITE, 2.2, 0.3)
		"cap":
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(Vector2(cos(a) * 21.0, -8.0 + sin(a) * 16.0))
			Art.toon(ci, dome, Art.CORAL, 2.5, 0.5)
			Art.t_ellipse(ci, Vector2(17, -8), Vector2(15, 4), Art.shade_of(Art.CORAL, 0.25), 2.2, 0.0)
			Art.t_circle(ci, Vector2(0, -24), 2.5, Art.shade_of(Art.CORAL, 0.25), 1.5, 0.0)
		"pirate":
			var pts := Art.smooth_pts(PackedVector2Array([Vector2(-30, -12), Vector2(-16, -20), Vector2(-12, -34), Vector2(0, -30),
					Vector2(12, -34), Vector2(16, -20), Vector2(30, -12), Vector2(0, -16)]), 3)
			Art.toon(ci, pts, Color("2e2a3d"), 2.5, 0.4)
			Art.t_circle(ci, Vector2(0, -24), 4.2, Art.WHITE, 1.2, 0.0)
			Art.flat(ci, Art.circle_pts(Vector2(-1.5, -24.5), 1.0, 6), Art.INK)
			Art.flat(ci, Art.circle_pts(Vector2(1.5, -24.5), 1.0, 6), Art.INK)
		"crown":
			var pts := PackedVector2Array([Vector2(-15, -14), Vector2(-17, -32), Vector2(-8, -23), Vector2(0, -36), Vector2(8, -23), Vector2(17, -32), Vector2(15, -14)])
			Art.toon(ci, pts, Art.GOLD, 2.5, 0.6)
			Art.t_circle(ci, Vector2(0, -19), 3, Art.RED, 1.5, 0.0)
			Art.t_circle(ci, Vector2(-9, -18), 2.2, Art.BLUE, 1.2, 0.0)
			Art.t_circle(ci, Vector2(9, -18), 2.2, Art.GREEN, 1.2, 0.0)
		"flower":
			var c := Vector2(13, -15)
			for i in 5:
				var a := TAU * i / 5.0
				Art.t_circle(ci, c + Vector2(cos(a), sin(a)) * 5.5, 4.5, Color("ff8fc0"), 1.6, 0.0)
			Art.t_circle(ci, c, 3.5, Art.GOLD, 1.6, 0.0)


## Round portrait: shoulders and head inside a colored frame.
static func portrait(ci: CanvasItem, center: Vector2, r: float, l: Dictionary, emotion: String, blink: bool, bg: Color) -> void:
	Art.push(ci, center, 0.0, Vector2.ONE * (r / 50.0))
	var disc := Art.circle_pts(Vector2.ZERO, 46.0, 40)
	Art.toon(ci, Art.circle_pts(Vector2.ZERO, 46.0, 40), bg, 4.0, 0.0)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-10, -18), 30.0, 28), disc), Color(1, 1, 1, 0.18))
	var shoulders := Art.clipped(Art.rrect_pts(Rect2(-36, 24, 72, 50), 22), disc)
	_torso_colors(ci, shoulders, l, 1.0)
	Art.push(ci, Vector2(0, 0), 0.0, Vector2(1.3, 1.3))
	head(ci, l, emotion, blink)
	Art.pop(ci)
	Art.arc(ci, Vector2.ZERO, 46.0, 0, TAU, 48, Art.INK, 4.0)
	Art.pop(ci)


static func _torso_colors(ci: CanvasItem, shape: PackedVector2Array, l: Dictionary, s: float) -> void:
	var outfit := _outfit(l)
	var clothes: String = l.get("clothes", "shirt")
	match clothes:
		"suit":
			Art.toon(ci, shape, Art.shade_of(outfit, 0.1), 0.0, 0.4)
			Art.flat(ci, PackedVector2Array([Vector2(-8, 24) * s, Vector2(8, 24) * s, Vector2(0, 44) * s]), Art.WHITE)
			Art.toon(ci, PackedVector2Array([Vector2(-3, 26) * s, Vector2(3, 26) * s, Vector2(4.5, 40) * s, Vector2(0, 45) * s, Vector2(-4.5, 40) * s]), Art.RED, 1.2, 0.0)
		"overalls":
			Art.toon(ci, shape, Color("f2f2f2"), 0.0, 0.4)
			Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-14 * s, 32 * s, 28 * s, 60 * s), 5 * s), shape), outfit)
			Art.flat(ci, Art.circle_pts(Vector2(-9, 35) * s, 2.0 * s, 8), Art.GOLD)
			Art.flat(ci, Art.circle_pts(Vector2(9, 35) * s, 2.0 * s, 8), Art.GOLD)
		"sailor":
			Art.toon(ci, shape, Art.WHITE, 0.0, 0.4)
			for i in 3:
				Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-60, (36 + i * 9) * s, 120, 3.5 * s), 1), shape), Art.BLUE)
			Art.flat(ci, PackedVector2Array([Vector2(-14, 23) * s, Vector2(14, 23) * s, Vector2(0, 36) * s]), outfit)
		"vest":
			Art.toon(ci, shape, Color("4a78c2"), 0.0, 0.4)
			var vest := Art.clipped(PackedVector2Array([Vector2(-60, 20) * s, Vector2(-5, 20) * s, Vector2(-2, 90) * s, Vector2(-60, 90) * s]), shape)
			var vest2 := Art.clipped(PackedVector2Array([Vector2(60, 20) * s, Vector2(5, 20) * s, Vector2(2, 90) * s, Vector2(60, 90) * s]), shape)
			Art.flat(ci, vest, Color("ff9a2e"))
			Art.flat(ci, vest2, Color("ff9a2e"))
			Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-60, 38 * s, 120, 4 * s), 1), shape), Color("fff27a"))
		"lab":
			Art.toon(ci, shape, Art.WHITE, 0.0, 0.4)
			Art.flat(ci, PackedVector2Array([Vector2(-7, 23) * s, Vector2(7, 23) * s, Vector2(0, 40) * s]), outfit)
		_:
			Art.toon(ci, shape, outfit, 0.0, 0.4)
			Art.flat(ci, Art.ellipse_pts(Vector2(0, 24) * s, Vector2(9, 4) * s, 14), Art.shade_of(outfit, 0.3))


# --- Full body people -----------------------------------------------------------

## Chibi person standing at `pos` (feet), ~95 px tall at scale 1.
## pose keys: emotion, blink, arm_l, arm_r (radians from straight down,
## positive = forward), walk (phase, <0 = standing), hold (item), look,
## bob (squash 0..1), tilt (head tilt).
static func person(ci: CanvasItem, pos: Vector2, scale: float, facing: float, l: Dictionary, pose: Dictionary) -> void:
	var bob: float = pose.get("bob", 0.0)
	var sq := 1.0 - bob * 0.06
	Art.push(ci, pos, 0.0, Vector2(scale * facing / sq * 1.0, scale * sq))
	var skin := _skin(l)
	var outfit := _outfit(l)
	var clothes: String = l.get("clothes", "shirt")
	var pants := Color("3a3f5c") if clothes != "overalls" else outfit
	if clothes == "suit":
		pants = Art.shade_of(outfit, 0.15)
	var walk: float = pose.get("walk", -1.0)
	# Shadow on the ground.
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 1), Vector2(17, 3.5), 16), Color(0, 0, 0, 0.18))
	# Legs.
	for sx: float in [-1.0, 1.0]:
		var swing := sin(walk * TAU + (0.0 if sx < 0 else PI)) * 0.5 if walk >= 0.0 else 0.0
		Art.push(ci, Vector2(6.0 * sx, -18), swing)
		Art.t_rect(ci, Rect2(-4.5, -2, 9, 17), 4, pants, 2.2, 0.0)
		Art.t_ellipse(ci, Vector2(2.5, 15.5), Vector2(7, 4), Color("3b2a2a"), 2.2, 0.0)
		Art.pop(ci)
	# Back arm.
	_arm(ci, Vector2(-13, -41), pose.get("arm_l", 0.1), l, false, "")
	# Body.
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-12, -46), Vector2(12, -46), Vector2(15, -30), Vector2(15, -17), Vector2(0, -15), Vector2(-15, -17), Vector2(-15, -30)]), 3)
	Art.toon(ci, body, Art.INK, 2.5, 0.0)
	Art.push(ci, Vector2(0, -71))
	_torso_colors(ci, Art.moved(body, Vector2(0, 71)), l, 1.0)
	Art.pop(ci)
	Art.polyline(ci, body, Art.INK, 2.5, true)
	# Belt for pants.
	if clothes in ["shirt", "vest", "sailor", "lab"]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-16, -21, 32, 6), 1), body), pants)
	# Head.
	Art.push(ci, Vector2(1, -68), pose.get("tilt", 0.0))
	head(ci, l, pose.get("emotion", "happy"), pose.get("blink", false), pose.get("look", Vector2.ZERO))
	Art.pop(ci)
	# Front arm with the held item.
	_arm(ci, Vector2(13, -41), pose.get("arm_r", -0.1), l, true, pose.get("hold", ""), pose.get("hold_color", Art.GOLD))
	Art.pop(ci)


static func _arm(ci: CanvasItem, shoulder: Vector2, angle: float, l: Dictionary, front: bool, hold: String, hold_color: Color = Art.GOLD) -> void:
	var clothes: String = l.get("clothes", "shirt")
	var sleeve := _outfit(l)
	match clothes:
		"suit":
			sleeve = Art.shade_of(sleeve, 0.1)
		"overalls", "sailor", "lab":
			sleeve = Color("f2f2f2") if clothes != "lab" else Art.WHITE
		"vest":
			sleeve = Color("4a78c2")
	Art.push(ci, shoulder, -angle)
	Art.t_rect(ci, Rect2(-4.5, -3, 9, 20), 4.5, sleeve, 2.2, 0.0)
	var glove := Color("5a5f7a") if clothes in ["overalls", "vest"] else _skin(l)
	Art.t_circle(ci, Vector2(0, 18), 5.0, glove, 2.2, 0.0)
	if front and hold != "":
		item(ci, hold, Vector2(0, 19), hold_color)
	Art.pop(ci)


## Things people carry, drawn at the hand.
static func item(ci: CanvasItem, kind: String, at: Vector2, color: Color) -> void:
	match kind:
		"sack":
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([at + Vector2(-9, 6), at + Vector2(-5, 2), at + Vector2(5, 2), at + Vector2(10, 8), at + Vector2(12, 20), at + Vector2(0, 25), at + Vector2(-12, 20)]), 3), Color("c7934f"), 2.2, 0.6)
			Art.crystal(ci, at + Vector2(-2, 5), 9, 3.5, -0.3, color, 1.5)
			Art.crystal(ci, at + Vector2(4, 5), 11, 3.5, 0.25, color.lightened(0.25), 1.5)
			Art.t_rect(ci, Rect2(at + Vector2(-6, 0), Vector2(12, 4)), 2, Color("8e552c"), 1.5, 0.0)
		"coinbag":
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([at + Vector2(-6, 2), at + Vector2(6, 2), at + Vector2(13, 12), at + Vector2(12, 24), at + Vector2(0, 28), at + Vector2(-12, 24), at + Vector2(-13, 12)]), 3), Color("e7d3a8"), 2.2, 0.6)
			Art.t_rect(ci, Rect2(at + Vector2(-7, 0), Vector2(14, 5)), 2, Color("8e552c"), 1.5, 0.0)
			Art.coin(ci, at + Vector2(0, 16), 6.5)
		"briefcase":
			Art.arc(ci, at + Vector2(0, 4), 4.0, PI, TAU, 10, Art.INK, 2.5)
			Art.t_rect(ci, Rect2(at + Vector2(-11, 4), Vector2(22, 16)), 3, Color("8e552c"), 2.2, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(at + Vector2(-2, 9), Vector2(4, 3)), 1), Art.GOLD)
		"wrench":
			Art.push(ci, at, 0.4)
			Art.t_rect(ci, Rect2(-2.5, -6, 5, 22), 2, Art.METAL, 1.8, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-6, 12), Vector2(-2, 14), Vector2(-2, 18), Vector2(2, 18), Vector2(2, 14), Vector2(6, 12), Vector2(5, 22), Vector2(-5, 22)]), Art.METAL, 1.8, 0.0)
			Art.pop(ci)
		"hammer":
			Art.push(ci, at, 0.0)
			Art.t_rect(ci, Rect2(-2.5, -14, 5, 24), 2, Art.WOOD, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-10, -20, 20, 9), 2.5, Art.METAL, 2.0, 0.4)
			Art.pop(ci)
		"clipboard":
			Art.t_rect(ci, Rect2(at + Vector2(-8, -2), Vector2(16, 20)), 2, Art.WOOD, 1.8, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(at + Vector2(-6, 1), Vector2(12, 15)), 1), Art.WHITE)
			for i in 3:
				Art.line(ci, at + Vector2(-4, 5 + i * 4), at + Vector2(4, 5 + i * 4), Art.INK_SOFT, 1.2)


# --- Divers --------------------------------------------------------------------------

## Diver in a brass helmet, feet at `pos`, ~80 px tall at scale 1.
## arm: "swim" | "rope" | "pick" | "idle" | "cheer"; hit 0..1 swings the pick.
static func diver(ci: CanvasItem, pos: Vector2, scale: float, suit: Color, facing: float, tilt: float,
		kick: float, arm: String, hit: float, carry: bool, ore: Color, emotion: String, blink: bool, t: float = 0.0) -> void:
	Art.push(ci, pos, tilt * facing, Vector2(scale * facing, scale))
	var dark := Art.shade_of(suit, 0.35)
	var flip := Color("2f3a5c")
	# Legs with big flippers.
	for sx: float in [-1.0, 1.0]:
		var a := sin(kick * TAU + (0.0 if sx < 0 else PI)) * 0.45
		Art.push(ci, Vector2(5.0 * sx, -17), a)
		Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, suit if sx > 0 else dark, 2.2, 0.0)
		Art.toon(ci, PackedVector2Array([Vector2(-5, 9), Vector2(5, 9), Vector2(18, 14), Vector2(21, 19), Vector2(16, 21), Vector2(-5, 19)]), flip, 2.2, 0.3)
		Art.pop(ci)
	# Air tank on the back.
	Art.t_rect(ci, Rect2(-23, -50, 11, 30), 5.5, Art.METAL, 2.2, 0.6)
	Art.t_rect(ci, Rect2(-23, -40, 11, 4), 1, Art.RED, 0.0, 0.0)
	# Back arm.
	_diver_arm(ci, Vector2(-11, -39), _arm_angle(arm, hit, t, false), suit, false, "", ore)
	# Suit.
	Art.t_rect(ci, Rect2(-13, -46, 26, 32), 11, suit, 2.5, 0.8)
	Art.t_rect(ci, Rect2(-13, -24, 26, 5), 1, Color("5b3a22"), 0.0, 0.0)
	Art.t_rect(ci, Rect2(-3, -25, 6, 7), 1.5, Art.GOLD, 1.2, 0.0)
	if carry:
		# Sack on the hip.
		Art.push(ci, Vector2(-4, -26))
		item(ci, "sack", Vector2.ZERO, ore)
		Art.pop(ci)
	# Brass helmet with a porthole for the face.
	Art.t_rect(ci, Rect2(-16, -52, 34, 9), 4, Color("d19230"), 2.5, 0.0)
	Art.t_circle(ci, Vector2(2, -70), 21, Art.BRASS, 2.8, 0.7)
	Art.t_rect(ci, Rect2(-3, -95, 10, 6), 2, Color("d19230"), 2.2, 0.0)
	Art.t_circle(ci, Vector2(-15, -71), 5, Color("d19230"), 2.0, 0.0)
	Art.t_circle(ci, Vector2(6, -70), 14.5, Color("b8782a"), 2.2, 0.0)
	Art.t_circle(ci, Vector2(6, -70), 12, Color("dff8ff"), 0.0, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(6.5, -68.5), 11, 24), Color("ffd9b8"))
	Art.push(ci, Vector2(6, -70), 0.0, Vector2(0.58, 0.58))
	face(ci, emotion, blink, Color("ffd9b8"))
	Art.pop(ci)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(0, -76), 7, 14), Art.circle_pts(Vector2(6, -70), 12, 24)), Color(1, 1, 1, 0.5))
	for b: Vector2 in [Vector2(6, -86.5), Vector2(-9, -76), Vector2(-9, -63), Vector2(21, -76), Vector2(21, -63)]:
		Art.flat(ci, Art.circle_pts(b, 1.8, 8), Color("9a5f1a"))
	# Front arm with the tool.
	_diver_arm(ci, Vector2(11, -39), _arm_angle(arm, hit, t, true), suit, true, "pick" if arm == "pick" else "", ore)
	Art.pop(ci)


static func _arm_angle(arm: String, hit: float, t: float, front: bool) -> float:
	match arm:
		"swim":
			return sin(t * 5.0 + (0.0 if front else PI)) * 0.6 + 1.2
		"rope":
			return 2.6 if front else 2.3
		"pick":
			return lerpf(2.7, 0.9, hit) if front else 0.4
		"cheer":
			return 2.8 + sin(t * 14.0) * 0.2 if front else -2.8 - sin(t * 14.0) * 0.2
	return 0.2 if front else -0.1


static func _diver_arm(ci: CanvasItem, shoulder: Vector2, angle: float, suit: Color, front: bool, tool: String, ore: Color) -> void:
	Art.push(ci, shoulder, -angle)
	Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, suit if front else Art.shade_of(suit, 0.35), 2.2, 0.0)
	Art.t_circle(ci, Vector2(0, 17), 5.0, Color("4a4f6a"), 2.2, 0.0)
	if tool == "pick":
		Art.push(ci, Vector2(0, 17), -PI / 2.0 + 0.2)
		Art.t_rect(ci, Rect2(-2.5, -4, 30, 5), 2.5, Art.WOOD, 1.8, 0.0)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(26, -14), Vector2(31, -6), Vector2(32, 6), Vector2(27, 16), Vector2(29, 4), Vector2(28, -4)]), 2), Art.METAL, 2.0, 0.3)
		Art.pop(ci)
	Art.pop(ci)
