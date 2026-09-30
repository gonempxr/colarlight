class_name Chars
extends RefCounted
## Every character: chibi people (workers, the businessman, managers, the
## player's avatar) and divers, whose gear gets fancier every three depths
## (brass helmet, scuba, full-face mask, hard suit, heat suit, exo-suit,
## crystal suit, abyss mech, mythic armour, ocean-king suit) along with
## their tool (pick, drill, laser, plasma drill, trident, king's hammer).
## Faces carry emotions.
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
		# The lift operator at the winch on the raft.
		"lift": return look(5, "curly", 0, "cap", "mustache", 3, "overalls")
		"boat": return look(2, "short", 1, "captain", "beard", 0, "sailor")
		"plant": return look(3, "short", 0, "hardhat", "glasses", 2, "vest")
		# The second boat's captain and the second plant's manager.
		"boat2": return look(4, "long", 3, "sailor", "freckles", 1, "sailor")
		"plant2": return look(0, "long", 1, "hardhat_blue", "none", 6, "lab")
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
					Art.line_c(ci, PackedVector2Array([c + Vector2(-5.0, -0.2 + sx * 0.8), c + Vector2(5.0, -0.6)]), Art.INK, 1.6)
			"arc":
				Art.arc_c(ci, c + Vector2(0, 2.5), 3.8, PI + 0.35, TAU - 0.35, 10, Art.INK, 2.2)
			"closed":
				Art.arc_c(ci, c + Vector2(0, -1.0), 3.8, 0.35, PI - 0.35, 10, Art.INK, 2.0)
			"x":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, 0)]), Art.INK, 2.0)
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3, 3), c + Vector2(3, 0)]), Art.INK, 2.0) if sx > 0 else Art.line_c(ci, PackedVector2Array([c + Vector2(3, 3), c + Vector2(-3, 0)]), Art.INK, 2.0)
				if sx < 0:
					Art.line_c(ci, PackedVector2Array([c + Vector2(3, -3), c + Vector2(-3, 0)]), Art.INK, 2.0)
			"star":
				Art.toon(ci, Art.star_pts(c, 5.2, 2.3, 5), Art.GOLD, 1.0, 0.0)
		match brows:
			"angry":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3.5 * sx, -8.5), c + Vector2(3.0 * sx, -6.0)]), Art.INK, 1.8)
			"worried":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3.5 * sx, -6.5), c + Vector2(3.0 * sx, -9.0)]), Art.INK, 1.8)
			"raised":
				Art.arc_c(ci, c + Vector2(0, -6.5), 3.5, PI + 0.5, TAU - 0.5, 8, Art.INK, 1.6)
	# Nose.
	Art.flat(ci, Art.ellipse_pts(Vector2(0.5, 7.0), Vector2(2.0, 1.4), 10), Art.shade_of(skin, 0.18))
	var m := Vector2(0.5, 12.0)
	match mouth:
		"smile":
			Art.arc_c(ci, m + Vector2(0, -2.5), 4.0, 0.45, PI - 0.45, 10, Art.INK, 1.8)
		"grin":
			var pts := PackedVector2Array([m + Vector2(-5.2, -1.6), m + Vector2(5.2, -1.6), m + Vector2(3.8, 2.6), m + Vector2(0, 4.2), m + Vector2(-3.8, 2.6)])
			Art.toon(ci, pts, Color("7a1f33"), 1.2, 0.0)
			Art.flat(ci, Art.ellipse_pts(m + Vector2(0, 2.4), Vector2(2.6, 1.3), 10), Color("ff7f93"))
			Art.flat(ci, PackedVector2Array([m + Vector2(-4.2, -1.4), m + Vector2(4.2, -1.4), m + Vector2(3.9, -0.3), m + Vector2(-3.9, -0.3)]), Art.WHITE)
		"tongue":
			Art.arc_c(ci, m + Vector2(0, -2.5), 3.6, 0.5, PI - 0.5, 10, Art.INK, 1.8)
			Art.toon(ci, Art.ellipse_pts(m + Vector2(2.4, 1.6), Vector2(1.8, 2.2), 10), Color("ff7f93"), 1.0, 0.0)
		"o":
			Art.toon(ci, Art.ellipse_pts(m + Vector2(0, 0.5), Vector2(2.4, 3.0), 12), Color("7a1f33"), 1.2, 0.0)
		"flat":
			Art.line_c(ci, PackedVector2Array([m + Vector2(-2.8, 0), m + Vector2(2.8, 0)]), Art.INK, 1.8)
		"frown":
			Art.arc_c(ci, m + Vector2(0, 2.8), 3.6, PI + 0.5, TAU - 0.5, 10, Art.INK, 1.8)
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
	look_dir = Vector2(snappedf(look_dir.x, 0.1), snappedf(look_dir.y, 0.1))
	var key := hash([23, l, emotion, blink, look_dir, Art.fringe_min])
	if Art.cache_begin(ci, key):
		return
	_head_draw(ci, l, emotion, blink, look_dir)
	Art.cache_end(ci, key)


static func _head_draw(ci: CanvasItem, l: Dictionary, emotion: String, blink: bool, look_dir: Vector2) -> void:
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
				Art.arc_c(ci, Vector2(7 * sx, 1.5), 6.3, 0, TAU, 20, Art.INK, 2.0)
				Art.flat(ci, Art.circle_pts(Vector2(7 * sx, 1.5), 5.4, 16), Color(0.75, 0.95, 1.0, 0.25))
			Art.line_c(ci, PackedVector2Array([Vector2(-1, 0.5), Vector2(1, 0.5)]), Art.INK, 2.0)
		"sunglasses":
			for sx: float in [-1.0, 1.0]:
				Art.toon(ci, Art.rrect_pts(Rect2(7 * sx - 6, -3, 12, 8.5), 3.5), Color("2a2240"), 1.4, 0.0)
				Art.line_c(ci, PackedVector2Array([Vector2(7 * sx - 3.5, -1), Vector2(7 * sx - 1, -1)]), Color(1, 1, 1, 0.7), 1.4)
			Art.line_c(ci, PackedVector2Array([Vector2(-1.5, -0.5), Vector2(1.5, -0.5)]), Art.INK, 2.0)
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
	if hat in HatsArt.IDS:
		HatsArt.draw(ci, hat)
		return
	match hat:
		"tophat":
			Art.t_rect(ci, Rect2(-15, -52, 30, 36), 5, Color("2e2a3d"), 2.5, 0.5)
			Art.t_rect(ci, Rect2(-15, -26, 30, 7), 2, Art.GOLD, 0.0, 0.0)
			Art.t_ellipse(ci, Vector2(0, -17), Vector2(25, 5.5), Color("2e2a3d"), 2.5, 0.3)
		"hardhat", "hardhat_blue":
			var blue := hat == "hardhat_blue"
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(Vector2(cos(a) * 22.0, -10.0 + sin(a) * 18.0))
			Art.toon(ci, dome, Color("3aa6f0") if blue else Color("ffcf33"), 2.5, 0.6)
			Art.t_rect(ci, Rect2(-27, -13, 54, 7), 3.5, Color("1f7fd0") if blue else Color("f4b400"), 2.5, 0.0)
			Art.t_rect(ci, Rect2(-3, -30, 6, 18), 3, Color("9fdcff") if blue else Color("ffe07a"), 0.0, 0.0)
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
	# Drawn once per face, mood and blink; the blink is just another entry.
	var key := hash([24, l, emotion, blink, bg, Art.fringe_min])
	if Art.cache_begin(ci, key):
		Art.pop(ci)
		return
	var disc := Art.circle_pts(Vector2.ZERO, 46.0, 32)
	Art.toon(ci, disc, bg, 4.0, 0.0)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-10, -18), 30.0, 28), disc), Color(1, 1, 1, 0.18))
	var shoulders := Art.clipped(Art.rrect_pts(Rect2(-36, 24, 72, 50), 22), disc)
	_torso_colors(ci, shoulders, l, 1.0)
	Art.push(ci, Vector2(0, 0), 0.0, Vector2(1.3, 1.3))
	head(ci, l, emotion, blink)
	Art.pop(ci)
	Art.arc_c(ci, Vector2.ZERO, 46.0, 0, TAU, 32, Art.INK, 4.0)
	Art.cache_end(ci, key)
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
## bob (squash 0..1), tilt (head tilt), hand_l / hand_r (Vector2: the hand
## reaches that point in the person's own units, feet at the origin; the arm
## bends at the elbow to get there, for gripping a crank or a rail);
## no_arms (true: the arms are left out, to be drawn with reach_arms over
## something the person stands behind).
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
	# Shadow on the ground and legs (the walk cycle in 16 steps).
	var wq := -1 if walk < 0.0 else int(fposmod(walk, 1.0) * 16.0 + 0.5) % 16
	var leg_key := hash([20, pants, wq])
	if not Art.cache_begin(ci, leg_key):
		Art.flat(ci, Art.ellipse_pts(Vector2(0, 1), Vector2(17, 3.5), 16), Color(0, 0, 0, 0.18))
		for sx: float in [-1.0, 1.0]:
			var swing := sin(wq / 16.0 * TAU + (0.0 if sx < 0 else PI)) * 0.5 if wq >= 0 else 0.0
			Art.push(ci, Vector2(6.0 * sx, -18), swing)
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 17), 4, pants, 2.2, 0.0)
			Art.t_ellipse(ci, Vector2(2.5, 15.5), Vector2(7, 4), Color("3b2a2a"), 2.2, 0.0)
			Art.pop(ci)
		Art.cache_end(ci, leg_key)
	var arms: bool = not pose.get("no_arms", false)
	# Back arm.
	if not arms:
		pass
	elif pose.has("hand_l"):
		_reach(ci, Vector2(-13, -41), pose["hand_l"], l, false)
	else:
		_arm(ci, Vector2(-13, -41), pose.get("arm_l", 0.1), l, false, "")
	# Body and belt.
	var body_key := hash([21, l, Art.fringe_min])
	if not Art.cache_begin(ci, body_key):
		var body := Art.smooth_pts(PackedVector2Array([Vector2(-12, -46), Vector2(12, -46), Vector2(15, -30), Vector2(15, -17), Vector2(0, -15), Vector2(-15, -17), Vector2(-15, -30)]), 3)
		Art.toon(ci, body, Art.INK, 2.5, 0.0)
		Art.push(ci, Vector2(0, -71))
		_torso_colors(ci, Art.moved(body, Vector2(0, 71)), l, 1.0)
		Art.pop(ci)
		Art.polyline(ci, body, Art.INK, 2.5, true)
		if clothes in ["shirt", "vest", "sailor", "lab"]:
			Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-16, -21, 32, 6), 1), body), pants)
		Art.cache_end(ci, body_key)
	# Head.
	Art.push(ci, Vector2(1, -68), pose.get("tilt", 0.0))
	head(ci, l, pose.get("emotion", "happy"), pose.get("blink", false), pose.get("look", Vector2.ZERO))
	Art.pop(ci)
	# Front arm with the held item.
	if not arms:
		pass
	elif pose.has("hand_r"):
		_reach(ci, Vector2(13, -41), pose["hand_r"], l, true)
	else:
		_arm(ci, Vector2(13, -41), pose.get("arm_r", -0.1), l, true, pose.get("hold", ""), pose.get("hold_color", Art.GOLD))
	Art.pop(ci)


static func _arm(ci: CanvasItem, shoulder: Vector2, angle: float, l: Dictionary, front: bool, hold: String, hold_color: Color = Art.GOLD) -> void:
	var aq := roundi(angle / ARM_STEP)
	var key := hash([22, l, front, hold, hold_color, aq, Art.fringe_min])
	if Art.cache_begin(ci, key):
		return
	angle = aq * ARM_STEP
	var clothes: String = l.get("clothes", "shirt")
	var sleeve := _outfit(l)
	match clothes:
		"suit":
			sleeve = Art.shade_of(sleeve, 0.1)
		"overalls", "sailor", "lab":
			sleeve = Color("f2f2f2") if clothes != "lab" else Art.WHITE
		"vest":
			sleeve = Color("4a78c2")
	var glove := Color("5a5f7a") if clothes in ["overalls", "vest"] else _skin(l)
	var tool := front and hold in TOOLS
	Art.push(ci, shoulder, -angle)
	if tool:
		# Held by the end of the handle, the head sticking out past the fist.
		Art.push(ci, Vector2(0, 18), -0.55)
		_tool_item(ci, hold)
		Art.pop(ci)
	Art.t_rect(ci, Rect2(-4.5, -3, 9, 20), 4.5, sleeve, 2.2, 0.0)
	Art.t_circle(ci, Vector2(0, 18), 5.0, glove, 2.2, 0.0)
	Art.pop(ci)
	if front and hold != "" and not tool:
		var hand := shoulder + Vector2(sin(angle), cos(angle)) * 18.0
		hang(ci, hold, hand, angle, hold_color)
		# Fingers wrap over the handle / knot.
		Art.push(ci, hand)
		Art.t_circle(ci, Vector2.ZERO, 5.0, glove, 2.2, 0.0)
		Art.pop(ci)
	Art.cache_end(ci, key)


## Both arms of a person drawn with no_arms, in front of everything drawn
## since: the hands reach `hand_l` / `hand_r` (person units, as in person).
static func reach_arms(ci: CanvasItem, pos: Vector2, scale: float, facing: float, l: Dictionary, hand_l: Vector2, hand_r: Vector2, bob: float = 0.0) -> void:
	var sq := 1.0 - bob * 0.06
	Art.push(ci, pos, 0.0, Vector2(scale * facing / sq, scale * sq))
	_reach(ci, Vector2(-13, -41), hand_l, l, false)
	_reach(ci, Vector2(13, -41), hand_r, l, true)
	Art.pop(ci)


## An arm from `shoulder` whose hand ends at `hand` (person units, snapped
## to whole units so the shape cache holds a few dozen reaches at most):
## upper arm and forearm with the elbow bent outward (away from the body)
## and down, straight when the hand is at full reach.
static func _reach(ci: CanvasItem, shoulder: Vector2, hand: Vector2, l: Dictionary, front: bool) -> void:
	var to := hand.round()
	var key := hash([23, l, front, shoulder, to, Art.fringe_min])
	if Art.cache_begin(ci, key):
		return
	var d := to - shoulder
	var n := maxf(4.0, d.length())
	var half := minf(n * 0.5, REACH_SEG)
	var bend := sqrt(maxf(0.0, REACH_SEG * REACH_SEG - half * half))
	var side := d.orthogonal().normalized()
	# Elbow out to the shoulder's side of the body, and never above the line.
	if side.x * signf(shoulder.x) < 0.0 or (absf(side.x) < 0.3 and side.y < 0.0):
		side = -side
	var elbow := shoulder + d * 0.5 + side * bend
	var sleeve := sleeve_color(l)
	var glove := glove_color(l)
	for seg: Array in [[shoulder, elbow, sleeve], [elbow, to, sleeve]]:
		var a: Vector2 = seg[0]
		var e: Vector2 = seg[1]
		var v := e - a
		Art.push(ci, a, atan2(-v.x, v.y))
		Art.t_rect(ci, Rect2(-4.5, -3, 9, v.length() + 3.0), 4.5, seg[2], 2.2, 0.0)
		Art.pop(ci)
	Art.t_circle(ci, to, 5.0, glove, 2.2, 0.0)
	Art.cache_end(ci, key)


## Upper arm and forearm of a reaching arm (person units).
const REACH_SEG := 13.0


static func sleeve_color(l: Dictionary) -> Color:
	var clothes: String = l.get("clothes", "shirt")
	match clothes:
		"suit":
			return Art.shade_of(_outfit(l), 0.1)
		"overalls", "sailor":
			return Color("f2f2f2")
		"lab":
			return Art.WHITE
		"vest":
			return Color("4a78c2")
	return _outfit(l)


## Work gloves with overalls and vests, else bare hands.
static func glove_color(l: Dictionary) -> Color:
	return Color("5a5f7a") if l.get("clothes", "shirt") in ["overalls", "vest"] else _skin(l)


## Things held by a handle: they point out of the fist.
const TOOLS := ["wrench", "hammer"]


## Draws a carried thing so it hangs straight down from the hand (sacks,
## bags, the briefcase) or is held upright (clipboard); when the arm is
## raised over the shoulder it is lifted above the hand instead.
## `arm_angle` is the arm's angle from straight down (the rotation to undo).
## `rot` turns it (to undo a body lean, or to let it sway).
static func hang(ci: CanvasItem, kind: String, hand: Vector2, arm_angle: float, color: Color, depth: int = -1, rot: float = 0.0) -> void:
	var up := smoothstep(1.55, 2.2, absf(arm_angle))
	match kind:
		"clipboard":
			Art.push(ci, hand + Vector2(-1, -15), -0.1)
			item(ci, kind, Vector2.ZERO, color, depth)
			Art.pop(ci)
		_:
			var h := 26.0 if kind != "briefcase" else 20.0
			Art.push(ci, hand + Vector2(0, -h * up - 2.0 * (1.0 - up)), rot * (1.0 - up * 0.7))
			item(ci, kind, Vector2.ZERO, color, depth)
			Art.pop(ci)


static func _tool_item(ci: CanvasItem, kind: String) -> void:
	match kind:
		"hammer":
			Art.t_rect(ci, Rect2(-2.6, -4, 5.2, 26), 2.4, Art.WOOD, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-10, 18, 20, 9), 2.5, Art.METAL, 2.0, 0.4)
			Art.t_rect(ci, Rect2(-11, 19, 4, 7), 1.5, Art.shade_of(Art.METAL, 0.2), 1.4, 0.0)
		"wrench":
			Art.t_rect(ci, Rect2(-2.5, -4, 5, 22), 2, Art.METAL, 1.8, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-6, 16), Vector2(-2, 18), Vector2(-2, 22), Vector2(2, 22), Vector2(2, 18),
					Vector2(6, 16), Vector2(5, 26), Vector2(-5, 26)]), Art.METAL, 1.8, 0.0)
			Art.line_c(ci, PackedVector2Array([Vector2(-1, 0), Vector2(-1, 14)]), Color(1, 1, 1, 0.6), 1.2)


## Things people carry, drawn with their top (the part held) at `at`.
## `depth` >= 0 fills a sack with that dive site's ore (see OreArt).
static func item(ci: CanvasItem, kind: String, at: Vector2, color: Color, depth: int = -1) -> void:
	Art.push(ci, at)
	match kind:
		"sack":
			Art.toon(ci, _SACK, Color("c7934f"), 2.2, 0.6)
			if depth >= 0 and Art.low_power:
				OreArt.chunk(ci, Vector2(0.5, 2), 6.5, depth, 0.1)
			elif depth >= 0:
				OreArt.chunk(ci, Vector2(-3.5, 3), 5.5, depth, -0.3)
				OreArt.chunk(ci, Vector2(4, 2), 6.5, depth, 0.25)
			else:
				Art.crystal(ci, Vector2(-2, 5), 9, 3.5, -0.3, color, 1.5)
				Art.crystal(ci, Vector2(4, 5), 11, 3.5, 0.25, color.lightened(0.25), 1.5)
			Art.t_rect(ci, Rect2(-6, 0, 12, 4), 2, Color("8e552c"), 1.5, 0.0)
			Art.flat(ci, Art.ellipse_pts(Vector2(-6, 14), Vector2(2, 4), 8, 0.3), Color(1, 1, 1, 0.25))
		"coinbag":
			Art.toon(ci, _COINBAG, Color("e7d3a8"), 2.2, 0.6)
			Art.t_rect(ci, Rect2(-7, 0, 14, 5), 2, Color("8e552c"), 1.5, 0.0)
			Art.coin(ci, Vector2(0, 16), 6.5)
		"briefcase":
			Art.arc_c(ci, Vector2(0, 4), 4.0, PI, TAU, 10, Art.INK, 2.5)
			Art.t_rect(ci, Rect2(-11, 4, 22, 16), 3, Color("8e552c"), 2.2, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(-2, 9, 4, 3), 1), Art.GOLD)
		"wrench", "hammer":
			_tool_item(ci, kind)
		"clipboard":
			Art.t_rect(ci, Rect2(-8, -2, 16, 20), 2, Art.WOOD, 1.8, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(-6, 1, 12, 15), 1), Art.WHITE)
			Art.t_rect(ci, Rect2(-4, -4, 8, 4), 1.5, Art.METAL, 1.2, 0.0)
			for i in 3:
				Art.line_c(ci, PackedVector2Array([Vector2(-4, 5 + i * 4), Vector2(4, 5 + i * 4)]), Art.INK_SOFT, 1.2)
	Art.pop(ci)


static var _SACK := Art.smooth_pts(PackedVector2Array([Vector2(-9, 6), Vector2(-5, 2), Vector2(5, 2), Vector2(10, 8), Vector2(12, 20), Vector2(0, 25), Vector2(-12, 20)]), 3)
static var _COINBAG := Art.smooth_pts(PackedVector2Array([Vector2(-6, 2), Vector2(6, 2), Vector2(13, 12), Vector2(12, 24), Vector2(0, 28), Vector2(-12, 24), Vector2(-13, 12)]), 3)


# --- Divers --------------------------------------------------------------------------
#
# Gear gets fancier the deeper the site: tier = depth / 3.
#   0 brass helmet + pick        1 scuba mask, fins, tank + steel pick
#   2 full-face mask, head lamp  3 armored hard-suit + drill
#   4 heat suit, orange visor    5 sci-fi exo-suit, thrusters + laser cutter
#   6 glowing crystal suit with a halo of bubbles + laser cutter
#   7 abyss mech: armored helm, reactor pack with jets + plasma drill
#   8 mythic armour: golden crested helm, cuirass, shield + trident
#   9 ocean king: crowned glass dome, ermine and cape + king's hammer
# The suit color (per depth or the wardrobe paint) stays the main color.
# Swung tools (pick, hammer) are drawn behind the head, so a raised tool
# passes behind the helmet and never across the face.

const GEAR_TIERS := 10
const SHOULDER_F := Vector2(11, -39)
const SHOULDER_B := Vector2(-11, -39)
const ARM_LEN := 17.0
## Point of the dig cycle (0..1) where the tool hits the deposit.
const DIG_IMPACT := 0.64
const ARM_STEP := 0.05


static func gear_tier(depth: int) -> int:
	return clampi(depth / 3, 0, GEAR_TIERS - 1)


## "pick" (tiers 0-2), "drill" (3-4), "laser" (5-6), "plasma" (7),
## "trident" (8) or "hammer" (9).
static func tool_of(tier: int) -> String:
	if tier >= 9:
		return "hammer"
	if tier == 8:
		return "trident"
	if tier == 7:
		return "plasma"
	if tier >= 5:
		return "laser"
	if tier >= 3:
		return "drill"
	return "pick"


## Depth whose ore color this is (for callers that pass no depth), else 0.
## Swung tools follow the pick's wind-up and strike; the others brace
## and push in (see dig_pose).
static func swings(tool: String) -> bool:
	return tool == "pick" or tool == "hammer"


static func _depth_for_ore(ore: Color) -> int:
	for i in Art.DEPTH_STYLE.size():
		if (Art.DEPTH_STYLE[i]["ore"] as Color).is_equal_approx(ore):
			return i
	return 0


static func _ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x)


## The swing of the dig cycle at phase u (0..1): slow wind-up with the tool
## raised over the head, a short pause, a fast strike (impact at DIG_IMPACT),
## a small recoil and a settle. Returns [arm angle, wrist bend, body lean,
## body lunge (px forward)].
static func dig_pose(u: float, tier: int) -> Array:
	u = fposmod(u, 1.0)
	if not swings(tool_of(tier)):
		# Drill / laser: brace back, then push in and hold while it works.
		var lunge := 0.0
		var lean := 0.0
		var a := 1.45
		if u < 0.5:
			var e := _ease_io(u / 0.5)
			lean = -0.07 * e
			lunge = -3.0 * e
			a = 1.45 + 0.12 * e
		elif u < DIG_IMPACT:
			var e := _ease_io((u - 0.5) / (DIG_IMPACT - 0.5))
			lean = lerpf(-0.07, 0.06, e)
			lunge = lerpf(-3.0, 5.0, e)
			a = lerpf(1.57, 1.42, e)
		elif u < 0.88:
			lean = 0.06
			lunge = 5.0
			a = 1.42
		else:
			var e := _ease_io((u - 0.88) / 0.12)
			lean = lerpf(0.06, 0.0, e)
			lunge = lerpf(5.0, 0.0, e)
			a = lerpf(1.42, 1.45, e)
		return [a, 0.0, lean, lunge]
	var rest := 1.55
	if u < 0.5:
		var e := _ease_io(u / 0.5)
		return [lerpf(rest, 2.35, e), lerpf(0.0, -0.62, e), lerpf(0.0, -0.12, e), 0.0]
	if u < 0.56:
		var e := _ease_out((u - 0.5) / 0.06)
		return [lerpf(2.35, 2.42, e), lerpf(-0.62, -0.68, e), lerpf(-0.12, -0.14, e), 0.0]
	if u < DIG_IMPACT:
		var k := (u - 0.56) / (DIG_IMPACT - 0.56)
		var e := k * k * k
		return [lerpf(2.42, 1.35, e), lerpf(-0.68, 0.05, e), lerpf(-0.14, 0.09, e), lerpf(0.0, 3.0, e)]
	if u < 0.78:
		var k := (u - DIG_IMPACT) / (0.78 - DIG_IMPACT)
		var e := _ease_out(k)
		return [lerpf(1.35, rest, e) + 0.1 * sin(k * PI), lerpf(0.05, 0.0, e), lerpf(0.09, 0.03, e), lerpf(3.0, 1.0, e)]
	var e := _ease_io((u - 0.78) / 0.22)
	return [rest, 0.0, lerpf(0.03, 0.0, e), lerpf(1.0, 0.0, e)]


## Where the tool meets the deposit, in the diver's own space (scale 1,
## facing +x, feet at 0,0): chips and sparks fly from here.
static func dig_tip(tier: int) -> Vector2:
	match tool_of(tier):
		"drill":
			return Vector2(78, -44)
		"laser":
			return Vector2(86, -43)
		"plasma":
			return Vector2(82, -45)
		"trident":
			return Vector2(88, -45)
		"hammer":
			return Vector2(56, -14)
	return Vector2(56, -13)


## Diver, feet at `pos`, ~80 px tall at scale 1.
## arm: "swim" | "rope" | "dig" | "pick" | "idle" | "cheer".
##   dig: `hit` is the phase of the dig cycle (0..1, see dig_pose);
##   pick: `hit` 0 = tool raised, 1 = struck (a simple back-and-forth).
## carry: holds a sack of ore (in the hand, or on the back on the rope).
## depth: dive site (gear tier and ore look); -1 = guess from `ore`.
## pose (optional): "arm_from" + "blend" (0..1) ease from another arm pose,
## "turn" (-1..1) squashes x while turning around, "kick_amp" (0..1) how
## hard the legs kick, "sling" (0..1) moves a carried sack from the hand
## to the back.
static func diver(ci: CanvasItem, pos: Vector2, scale: float, suit: Color, facing: float, tilt: float,
		kick: float, arm: String, hit: float, carry: bool, ore: Color, emotion: String, blink: bool, t: float = 0.0,
		depth: int = -1, pose: Dictionary = {}) -> void:
	if depth < 0:
		depth = _depth_for_ore(ore)
	var tier := gear_tier(depth)
	var st: Dictionary = Art.DEPTH_STYLE[clampi(depth, 0, Art.DEPTH_STYLE.size() - 1)]
	var tool := tool_of(tier)
	_small = scale < 1.0
	_depth = clampi(depth, 0, Art.DEPTH_STYLE.size() - 1)
	var digging := arm in ["dig", "pick"]
	# Arm angles (radians from straight down, + = forward), wrist, lean.
	var fa := 0.0
	var ba := 0.0
	var wrist := 0.0
	var lean := 0.0
	var lunge := 0.0
	var swim := arm == "swim"
	var fr := _arm_pair(arm, hit, t, tier, carry)
	fa = fr[0]
	ba = fr[1]
	wrist = fr[2]
	lean = fr[3]
	lunge = fr[4]
	var blend: float = pose.get("blend", 1.0)
	if blend < 1.0 and pose.has("arm_from"):
		var from := _arm_pair(pose["arm_from"], 0.0, t, tier, carry)
		var e := _ease_io(blend)
		fa = lerpf(from[0], fa, e)
		ba = lerpf(from[1], ba, e)
		wrist = lerpf(from[2], wrist, e)
		lean = lerpf(from[3], lean, e)
		lunge = lerpf(from[4], lunge, e)
	var turn: float = pose.get("turn", 1.0)
	var sx := facing * (1.0 if turn >= 0.0 else -1.0) * maxf(0.08, absf(turn))
	# Idle breathing / swim bob.
	var breathe := sin(t * 2.2) * 0.012 if not swim else 0.0
	Art.push(ci, pos, tilt * facing, Vector2(scale * sx, scale * (1.0 + breathe)))
	Art.push(ci, Vector2(lunge, 0), lean)
	var dark := Art.shade_of(suit, 0.35)
	var rope := arm == "rope"
	var kick_amp: float = pose.get("kick_amp", 0.0 if kick == 0.0 else 1.0)
	_diver_legs(ci, tier, suit, dark, kick, t, st, kick_amp)
	_diver_back(ci, tier, suit, dark, t, (swim or rope) and kick_amp > 0.3, st)
	# The sack goes over the back while both hands climb the rope.
	var sling: float = pose.get("sling", 1.0 if rope else 0.0)
	var hand := SHOULDER_F + Vector2(sin(fa), cos(fa)) * ARM_LEN
	var back_at := Vector2(-18, -44)
	if carry and sling > 0.5:
		var e := _ease_io((sling - 0.5) * 2.0)
		Art.push(ci, hand.lerp(back_at, e), lerpf(-(lean + tilt), 0.35 + sin(t * 6.0) * 0.08, e))
		item(ci, "sack", Vector2.ZERO, ore, depth)
		Art.pop(ci)
	_diver_arm(ci, SHOULDER_B, ba, suit, false, tier, st)
	_diver_torso(ci, tier, suit, dark, t, st)
	if digging:
		_tool(ci, tool, tier, fa, wrist, hit, t, st, arm)
	_diver_head(ci, tier, suit, dark, emotion, blink, t, st)
	_diver_arm(ci, SHOULDER_F, fa, suit, true, tier, st)
	if carry and sling <= 0.5:
		var e := _ease_io(sling * 2.0)
		hang(ci, "sack", hand.lerp(back_at, e * 0.3), fa, ore, depth, -(lean + tilt) + sin(t * 3.0) * 0.12)
		_glove(ci, hand, tier, st)
	_diver_fx(ci, tier, t, swim, st)
	Art.pop(ci)
	Art.pop(ci)


## [front arm, back arm, wrist, lean, lunge] for an arm pose.
static func _arm_pair(arm: String, hit: float, t: float, tier: int, carry: bool) -> Array:
	match arm:
		"swim":
			var s := sin(t * 5.0)
			if carry:
				return [0.55 + sin(t * 3.0) * 0.08, 1.2 - s * 0.6, 0.0, 0.0, 0.0]
			return [1.2 + s * 0.6, 1.2 - s * 0.6, 0.0, 0.0, 0.0]
		"rope":
			var s := sin(t * 6.0)
			return [2.6 + s * 0.22, 2.45 - s * 0.22, 0.0, 0.0, 0.0]
		"dig":
			var p := dig_pose(hit, tier)
			return [p[0], 0.35 + (p[0] - 1.5) * 0.25, p[1], p[2], p[3]]
		"pick":
			var h := clampf(hit, 0.0, 1.0)
			if not swings(tool_of(tier)):
				var p := dig_pose(lerpf(0.5, DIG_IMPACT, h), tier)
				return [p[0], 0.35, 0.0, p[2], p[3]]
			return [lerpf(2.42, 1.35, h), 0.35 + lerpf(0.23, -0.04, h), lerpf(-0.68, 0.05, h), lerpf(-0.14, 0.09, h), lerpf(0.0, 3.0, h)]
		"cheer":
			var w := sin(t * 12.0) * 0.2
			return [2.8 + w, -2.8 - w, 0.0, 0.0, 0.0]
	# idle
	var b := sin(t * 2.2) * 0.05
	return [0.25 + b, -0.12 - b, 0.0, 0.0, 0.0]


# --- Diver parts ---------------------------------------------------------------

static func _diver_legs(ci: CanvasItem, tier: int, suit: Color, dark: Color, kick: float, t: float, st: Dictionary, amp: float = 1.0) -> void:
	# Each leg is drawn once per suit and knee bend (in steps of 0.06 rad,
	# about half a pixel at the toe) and turned at the hip.
	for sx: float in [-1.0, 1.0]:
		var ph := kick * TAU + (0.0 if sx < 0 else PI)
		var a := sin(ph) * 0.45 * amp
		var fq := roundi(-cos(ph) * 0.3 * amp / 0.06)
		var near := sx > 0
		Art.push(ci, Vector2(5.0 * sx, -17), a)
		var key := _dk(1, suit, fq + 16, int(near))
		if not Art.cache_begin(ci, key):
			_leg_shape(ci, tier, suit if near else dark, near)
			Art.push(ci, Vector2(0, 11), fq * 0.06)
			_foot(ci, tier, near, t, st, suit)
			Art.pop(ci)
			Art.cache_end(ci, key)
		Art.pop(ci)


static func _leg_shape(ci: CanvasItem, tier: int, leg: Color, near: bool) -> void:
	match tier:
		3:
			Art.t_rect(ci, Rect2(-5.5, -2, 11, 14), 5, leg, 2.2, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(-6, 3, 12, 4), 2, 2), Art.shade_of(Art.METAL, 0.1 if near else 0.35))
		4:
			Art.t_rect(ci, Rect2(-5, -2, 10, 14), 4.5, leg, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 5, 10, 3), 1, Color(1, 0.6, 0.2, 0.9) if near else Color(0.8, 0.45, 0.2, 0.9), 0.0, 0.0)
		7:
			Art.t_rect(ci, Rect2(-6, -2, 12, 14), 5.5, Art.shade_of(MECH, 0.0 if near else 0.3), 2.2, 0.0)
			Art.flat(ci, _KNEE, leg)
		8:
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, leg, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5.5, 3, 11, 9), 3.5, Art.shade_of(MYTH_GOLD, 0.0 if near else 0.3), 0.0, 0.0)
		9:
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, Art.shade_of(KING_WHITE, 0.0 if near else 0.3), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 4, 10, 3), 1, Art.shade_of(MYTH_GOLD, 0.0 if near else 0.3), 0.0, 0.0)
		_:
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, leg, 2.2, 0.0)


static func _foot(ci: CanvasItem, tier: int, near: bool, t: float, st: Dictionary, suit: Color) -> void:
	var k := 0.0 if near else 0.3
	match tier:
		0:
			Art.toon(ci, _FIN0, Art.shade_of(Color("2f3a5c"), k * 0.5), 2.2, 0.0)
		1:
			Art.toon(ci, _FIN1, Art.shade_of(Color("ffcf33"), k), 2.2, 0.0)
			Art.line_c(ci, PackedVector2Array([Vector2(4, 4), Vector2(19, 7)]), Art.shade_of(Color("e0a51c"), k), 1.6)
		2:
			Art.toon(ci, _FIN1, Art.shade_of(Color("2a2f45"), k * 0.5), 2.2, 0.0)
			Art.flat(ci, PackedVector2Array([Vector2(15, 4), Vector2(22, 5.5), Vector2(23.5, 10), Vector2(16, 10)]), Art.shade_of(suit.lightened(0.2), k))
		3:
			Art.toon(ci, _BOOT, Art.shade_of(Color("8a94a8"), k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 7, 17, 3), 1.5, Art.shade_of(Color("4a5068"), k), 0.0, 0.0)
		4:
			Art.toon(ci, _BOOT, Art.shade_of(Color("dfe4ec"), k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 7, 17, 3), 1.5, Art.shade_of(Color("ff9a1f"), k), 0.0, 0.0)
		5:
			Art.toon(ci, _BOOT, Art.shade_of(Color("e9eef6"), k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 7.5, 17, 2.5), 1.2, Color(NEON, 0.9 - k), 0.0, 0.0)
		6:
			var c: Color = st["ore"]
			Art.toon(ci, _FIN6, Color(Art.shade_of(c.lightened(0.2), k), 0.9), 2.2, 0.0)
			Art.flat(ci, PackedVector2Array([Vector2(6, 2), Vector2(22, 7), Vector2(14, 7)]), Color(1, 1, 1, 0.5 - k))
		7:
			Art.toon(ci, _MECH_BOOT, Art.shade_of(MECH_LIGHT, k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 8, 21, 2.2), 1.0, Color(PLASMA, 0.9 - k), 0.0, 0.0)
		8:
			Art.toon(ci, _FIN1, Color(Art.shade_of(AQUA, k), 0.85), 2.2, 0.0)
			Art.flat(ci, PackedVector2Array([Vector2(8, 2), Vector2(22, 5), Vector2(14, 6)]), Color(1, 1, 1, 0.45 - k))
			Art.t_rect(ci, Rect2(-6, -2, 12, 6), 2.5, Art.shade_of(MYTH_GOLD, k), 0.0, 0.0)
		_:
			Art.toon(ci, _FIN9, Color(Art.shade_of(Color("7fe8ff"), k), 0.85), 2.2, 0.0)
			Art.toon(ci, _BOOT, Art.shade_of(MYTH_GOLD, k), 2.2, 0.0)


static var _FIN0 := PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(18, 3), Vector2(21, 8), Vector2(16, 10), Vector2(-5, 8)])
static var _FIN1 := Art.smooth_pts(PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(14, 1), Vector2(23, 3),
		Vector2(26, 8), Vector2(22, 11), Vector2(8, 10), Vector2(-5, 8)]), 2)
static var _FIN6 := PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(24, 0), Vector2(30, 6), Vector2(22, 11), Vector2(-5, 8)])
static var _BOOT := Art.smooth_pts(PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(7, 3), Vector2(13, 5), Vector2(12, 10), Vector2(-6, 10)]), 2)
static var _MECH_BOOT := Art.smooth_pts(PackedVector2Array([Vector2(-7, -2), Vector2(7, -2), Vector2(8, 2), Vector2(16, 4), Vector2(16, 10), Vector2(-7, 10)]), 2)
static var _FIN9 := Art.smooth_pts(PackedVector2Array([Vector2(-4, -1), Vector2(6, -1), Vector2(18, -2), Vector2(30, 1), Vector2(26, 7),
		Vector2(33, 13), Vector2(18, 11), Vector2(-4, 9)]), 2)
const NEON := Color("7df9ff")
## Abyss mech (tier 7), mythic armour (8) and the ocean king (9).
const MECH := Color("4a5270")
const MECH_LIGHT := Color("8a94b8")
const MECH_CORE := Color("22263a")
const PLASMA := Color("ff4fd8")
const MYTH_GOLD := Color("f2b632")
const MYTH_DARK := Color("c07a1c")
const AQUA := Color("4de8ff")
const KING_WHITE := Color("f4f7ff")
const KING_CAPE := Color("c0304a")


static func _diver_back(ci: CanvasItem, tier: int, suit: Color, dark: Color, t: float, moving: bool, st: Dictionary) -> void:
	# What moves on the pack, in steps: the cape's sway (9) and the crystals'
	# glow (the last tier). The jets of tiers 5 and 7 are drawn after the cache.
	var dyn := 0
	if tier == 9:
		dyn = roundi((sin(t * 2.0) * 0.05 + (0.22 if moving else 0.0)) / 0.02)
	elif tier == 6 or tier > 9:
		dyn = roundi((0.5 + 0.5 * sin(t * 2.0)) * 6.0)
	var key := _dk(2, suit, dyn)
	if not Art.cache_begin(ci, key):
		_back_static(ci, tier, suit, st, dyn)
		Art.cache_end(ci, key)
	match tier:
		5:
			# Thruster jets: flickering cones of light.
			for k in 2:
				var x := -27.0 + k * 7.0
				var fl := 0.75 + 0.25 * sin(t * 31.0 + k * 2.0)
				var jl := (16.0 if moving else 7.0) * fl
				Art.flat_now(ci, PackedVector2Array([Vector2(x + 1, -23), Vector2(x + 8, -23), Vector2(x + 4.5, -23 + jl)]), Color(NEON, 0.75))
				Art.flat_now(ci, PackedVector2Array([Vector2(x + 2.5, -23), Vector2(x + 6.5, -23), Vector2(x + 4.5, -23 + jl * 0.6)]), Color(1, 1, 1, 0.85))
		7:
			Art.dot(ci, Vector2(-21, -40), 3.2, Color(PLASMA, 0.6 + 0.4 * sin(t * 4.0)))
			# Twin plasma jets under the pack.
			var jl := (15.0 if moving else 6.0) * (0.75 + 0.25 * sin(t * 29.0))
			for x: float in [-26.0, -16.0]:
				Art.push(ci, Vector2(x, -21), 0.0, Vector2(1.0, jl / 10.0))
				Art.flat(ci, _JET, Color(PLASMA, 0.75))
				Art.flat(ci, _JET_IN, Color(1, 1, 1, 0.85))
				Art.pop(ci)


static func _back_static(ci: CanvasItem, tier: int, suit: Color, st: Dictionary, dyn: int) -> void:
	match tier:
		0:
			Art.t_rect(ci, Rect2(-23, -50, 11, 30), 5.5, Art.METAL, 2.2, 0.6)
			Art.t_rect(ci, Rect2(-23, -40, 11, 4), 1, Art.RED, 0.0, 0.0)
		1:
			Art.t_rect(ci, Rect2(-19, -57, 6, 6), 2, Color("5a5f7a"), 1.8, 0.0)
			Art.t_rect(ci, Rect2(-25, -53, 13, 34), 6.5, Color("ffcf33"), 2.2, 0.6)
			Art.t_rect(ci, Rect2(-25, -44, 13, 3.5), 1, Art.shade_of(Color("ffcf33"), 0.35), 0.0, 0.0)
		2:
			for k in 2:
				var x := -26.0 + k * 6.0
				Art.t_rect(ci, Rect2(x, -52, 10, 32), 5, Art.shade_of(Color("5b6485"), 0.2 - k * 0.2), 2.2, 0.5)
				Art.t_rect(ci, Rect2(x, -46, 10, 3), 1, suit, 0.0, 0.0)
		3:
			Art.t_rect(ci, Rect2(-27, -54, 16, 34), 5, Color("8a94a8"), 2.4, 0.6)
			for k in 3:
				Art.line_c(ci, PackedVector2Array([Vector2(-24, -47 + k * 6), Vector2(-15, -47 + k * 6)]), Color("4a5068"), 1.8)
			Art.t_circle(ci, Vector2(-19, -26), 3, suit, 1.6, 0.0)
		4:
			Art.t_rect(ci, Rect2(-27, -55, 15, 36), 6, Color("dfe4ec"), 2.4, 0.6)
			Art.t_rect(ci, Rect2(-27, -44, 15, 5), 1, Color("ff9a1f"), 0.0, 0.0)
			Art.stroke(ci, PackedVector2Array([Vector2(-14, -52), Vector2(-8, -56)]), Color("9aa3b5"), 2.5, 1.5)
		5:
			for k in 2:
				var x := -27.0 + k * 7.0
				Art.t_rect(ci, Rect2(x, -54, 9, 26), 4, Color("e9eef6") if k == 1 else Color("c9d2e2"), 2.2, 0.5)
				Art.toon(ci, PackedVector2Array([Vector2(x + 1, -29), Vector2(x + 8, -29), Vector2(x + 9.5, -23), Vector2(x - 0.5, -23)]), Color("4a5068"), 2.0, 0.0)
				Art.t_rect(ci, Rect2(x + 3, -50, 3, 14), 1.5, NEON, 0.0, 0.0)
		7:
			Art.t_rect(ci, Rect2(-28, -63, 14, 8), 2, MECH_LIGHT, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-30, -57, 18, 36), 6, MECH, 2.4, 0.3)
			Art.t_circle(ci, Vector2(-21, -40), 5.5, MECH_CORE, 1.8, 0.0)
		8:
			# A round golden shield on the back with a trident on it.
			Art.t_circle(ci, Vector2(-20, -40), 14, MYTH_DARK, 2.4, 0.4)
			Art.flat(ci, _SHIELD_IN, MYTH_GOLD)
			Art.flat(ci, _SHIELD_MARK, MYTH_DARK)
		9:
			# The royal cape, flowing back while swimming.
			Art.push(ci, Vector2(-8, -53), dyn * 0.02)
			Art.toon(ci, _CAPE, KING_CAPE, 2.4, 0.0)
			Art.flat(ci, _CAPE_LINING, Art.shade_of(KING_CAPE, 0.4))
			Art.pop(ci)
		_:
			var c: Color = st["ore"]
			var g := dyn / 6.0
			Art.dot(ci, Vector2(-20, -44), 16.0 + g * 3.0, Color(c, 0.14))
			Art.crystal(ci, Vector2(-14, -34), 30, 5, -0.75, c, 2.0)
			Art.crystal(ci, Vector2(-15, -42), 36, 5.5, -0.3, st["ore2"], 2.0)
			Art.crystal(ci, Vector2(-14, -28), 20, 4, -1.2, c.lightened(0.2), 1.8)


static func _diver_torso(ci: CanvasItem, tier: int, suit: Color, dark: Color, t: float, st: Dictionary) -> void:
	# The pulse of the lights on the chest, in 6 steps.
	var dyn := 0
	match tier:
		5:
			dyn = roundi((0.7 + 0.3 * sin(t * 4.0)) * 6.0)
		7:
			dyn = roundi((0.75 + 0.25 * sin(t * 4.0)) * 6.0)
		9:
			dyn = roundi(maxf(0.0, sin(t * 3.2)) * 6.0)
		6:
			dyn = roundi((0.5 + 0.5 * sin(t * 2.5)) * 6.0)
	var key := _dk(3, suit, dyn)
	if Art.cache_begin(ci, key):
		return
	_torso_static(ci, tier, suit, dark, st, dyn / 6.0)
	Art.cache_end(ci, key)


static func _torso_static(ci: CanvasItem, tier: int, suit: Color, dark: Color, st: Dictionary, pulse: float) -> void:
	match tier:
		0:
			Art.t_rect(ci, Rect2(-13, -46, 26, 32), 11, suit, 2.5, 0.8)
			Art.t_rect(ci, Rect2(-13, -24, 26, 5), 1, Color("5b3a22"), 0.0, 0.0)
			Art.t_rect(ci, Rect2(-3, -25, 6, 7), 1.5, Art.GOLD, 1.2, 0.0)
			Art.t_rect(ci, Rect2(-16, -52, 34, 9), 4, Color("d19230"), 2.5, 0.0)
		1:
			Art.t_rect(ci, Rect2(-13, -47, 26, 33), 11, suit, 2.5, 0.8)
			Art.flat(ci, Art.rrect_pts(Rect2(-13, -40, 6, 20), 3), dark)
			Art.line_c(ci, PackedVector2Array([Vector2(3, -44), Vector2(3, -26)]), Art.shade_of(suit, 0.5), 1.6)
			# Vest straps and a weight belt.
			Art.t_rect(ci, Rect2(-12, -46, 5, 22), 2, Color("2f3a5c"), 1.6, 0.0)
			Art.t_rect(ci, Rect2(-13, -24, 26, 5), 1.5, Color("2f3a5c"), 0.0, 0.0)
			for x: float in [-7.0, 2.0]:
				Art.flat(ci, Art.rrect_pts(Rect2(x, -25.5, 6, 7), 1.5, 2), Color("9aa3b5"))
		2:
			Art.t_rect(ci, Rect2(-13, -47, 26, 33), 11, suit, 2.5, 0.8)
			Art.flat(ci, PackedVector2Array([Vector2(-11, -45), Vector2(-6, -45), Vector2(8, -24), Vector2(3, -24)]), Color("2a2f45"))
			Art.flat(ci, PackedVector2Array([Vector2(6, -45), Vector2(11, -45), Vector2(-3, -24), Vector2(-8, -24)]), Color("2a2f45"))
			Art.t_circle(ci, Vector2(0, -36), 3.2, Color("d0d7e2"), 1.4, 0.0)
			Art.t_rect(ci, Rect2(-13, -24, 26, 4.5), 1.5, Color("2a2f45"), 0.0, 0.0)
			Art.t_rect(ci, Rect2(-3, -25, 6, 6.5), 1.5, Color("d0d7e2"), 1.2, 0.0)
		3:
			Art.t_rect(ci, Rect2(-15, -49, 30, 36), 12, suit, 2.6, 0.8)
			Art.t_rect(ci, Rect2(-10, -44, 20, 16), 5, Art.shade_of(suit, 0.2), 1.8, 0.3)
			for p: Vector2 in [Vector2(-7, -41), Vector2(7, -41), Vector2(-7, -31), Vector2(7, -31)]:
				Art.flat(ci, Art.circle_pts(p, 1.4, 8), Color("dfe4ec"))
			Art.t_rect(ci, Rect2(-15, -24, 30, 6), 2, Color("8a94a8"), 1.8, 0.0)
			Art.t_rect(ci, Rect2(-18, -54, 38, 10), 5, Color("8a94a8"), 2.5, 0.4)
		4:
			Art.t_rect(ci, Rect2(-14, -48, 28, 35), 11, suit, 2.5, 0.8)
			Art.t_rect(ci, Rect2(-10, -44, 20, 17), 6, Color("dfe4ec"), 1.8, 0.4)
			Art.t_rect(ci, Rect2(-10, -38, 20, 3.5), 1, Color("ff9a1f"), 0.0, 0.0)
			Art.t_rect(ci, Rect2(-14, -24, 28, 5), 1.5, Color("9aa3b5"), 0.0, 0.0)
			Art.t_rect(ci, Rect2(-17, -54, 36, 10), 5, Color("dfe4ec"), 2.5, 0.4)
		5:
			Art.t_rect(ci, Rect2(-14, -48, 28, 35), 11, Color("2a2f45"), 2.5, 0.5)
			Art.toon(ci, _EXO_CHEST, suit, 2.0, 0.6)
			var g := pulse
			Art.t_rect(ci, Rect2(-12, -24, 24, 3), 1.5, Color(NEON, g), 0.0, 0.0)
			Art.polyline(ci, PackedVector2Array([Vector2(-8, -43), Vector2(-3, -34), Vector2(3, -34), Vector2(8, -43)]), Color(NEON, g), 2.0)
			Art.t_circle(ci, Vector2(0, -38), 3.4, Color(NEON, 1.0), 1.5, 0.0)
			Art.t_rect(ci, Rect2(-17, -54, 36, 9), 4.5, Color("e9eef6"), 2.5, 0.3)
			Art.t_rect(ci, Rect2(-13, -51, 28, 2.5), 1, Color(NEON, g), 0.0, 0.0)
		7:
			Art.t_rect(ci, Rect2(-15, -49, 30, 36), 12, MECH, 2.6, 0.8)
			Art.toon(ci, _MECH_CHEST, suit, 2.0, 0.0)
			Art.flat(ci, _MECH_CORE_PTS, MECH_CORE)
			Art.dot(ci, Vector2(0, -37), 2.8, Color(PLASMA, pulse))
			Art.t_rect(ci, Rect2(-15, -24, 30, 6), 2, MECH_LIGHT, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-3, -25, 6, 8), 1.5, PLASMA, 0.0, 0.0)
			Art.t_rect(ci, Rect2(-19, -56, 40, 11), 5, MECH_LIGHT, 2.5, 0.0)
		8:
			Art.t_rect(ci, Rect2(-14, -48, 28, 35), 11, suit, 2.5, 0.8)
			Art.t_rect(ci, Rect2(-13, -25, 26, 10), 2, MYTH_DARK, 0.0, 0.0)
			Art.flat(ci, _SKIRT_STRIPS, Art.shade_of(suit, 0.2))
			Art.toon(ci, _CUIRASS, MYTH_GOLD, 2.2, 0.6)
			Art.flat(ci, _CUIRASS_GEM, AQUA)
			Art.t_rect(ci, Rect2(-18, -55, 38, 10), 5, MYTH_GOLD, 2.5, 0.0)
		9:
			var c: Color = st["ore"]
			Art.t_rect(ci, Rect2(-14, -48, 28, 35), 11, suit, 2.5, 0.8)
			Art.flat(ci, _KING_TRIM, MYTH_GOLD)
			Art.t_rect(ci, Rect2(-14, -24, 28, 5), 1.5, MYTH_GOLD, 0.0, 0.0)
			Art.flat(ci, _BELT_JEWEL, Color("ff3d6e"))
			# Ermine collar and the ocean-heart pendant, beating.
			Art.t_rect(ci, Rect2(-19, -57, 40, 12), 6, KING_WHITE, 2.5, 0.3)
			for p: Vector2 in [Vector2(-12, -50), Vector2(-3, -51), Vector2(7, -50), Vector2(15, -51)]:
				Art.flat(ci, Art.ellipse_pts(p, Vector2(1.1, 2.0), 6), Art.INK)
			var beat := pulse * 0.1
			Art.dot(ci, Vector2(0, -36), 7.5, Color(c, 0.3))
			Art.push(ci, Vector2(0, -36), 0.0, Vector2.ONE * (0.36 + beat * 0.36))
			Art.toon(ci, OreArt.HEART_LO, c, 4.5, 0.0)
			Art.flat(ci, _GLINT6, Color(1, 1, 1, 0.75))
			Art.pop(ci)
		_:
			var c: Color = st["ore"]
			var c2: Color = st["ore2"]
			var g := pulse
			Art.t_rect(ci, Rect2(-14, -48, 28, 35), 11, suit, 2.5, 0.8)
			Art.toon(ci, _CRYSTAL_PLATE, Color(c, 0.9), 1.8, 0.0)
			Art.flat(ci, PackedVector2Array([Vector2(0, -44), Vector2(9, -36), Vector2(0, -26)]), Color(c2, 0.55))
			Art.dot(ci, Vector2(0, -36), 3.2 + g, Color(c2, 0.9))
			Art.t_rect(ci, Rect2(-14, -24, 28, 5), 1.5, Art.shade_of(c, 0.3), 0.0, 0.0)
			Art.t_rect(ci, Rect2(-17, -54, 36, 10), 5, c.lightened(0.25), 2.5, 0.4)


static var _EXO_CHEST := Art.smooth_pts(PackedVector2Array([Vector2(-12, -45), Vector2(12, -45), Vector2(13, -33), Vector2(7, -27),
		Vector2(-7, -27), Vector2(-13, -33)]), 2)
static var _CRYSTAL_PLATE := PackedVector2Array([Vector2(0, -46), Vector2(11, -36), Vector2(0, -24), Vector2(-11, -36)])
static var _JET := PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 10)])
static var _JET_IN := PackedVector2Array([Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, 6)])
static var _MECH_CHEST := PackedVector2Array([Vector2(-12, -46), Vector2(12, -46), Vector2(13, -36), Vector2(6, -29), Vector2(-6, -29), Vector2(-13, -36)])
static var _CUIRASS := Art.smooth_pts(PackedVector2Array([Vector2(-13, -47), Vector2(13, -47), Vector2(13, -34), Vector2(9, -26),
		Vector2(0, -24), Vector2(-9, -26), Vector2(-13, -34)]), 2)
static var _KING_TRIM := Art.rrect_pts(Rect2(-3, -46, 6, 22), 2, 2)
## Cape, hanging from its anchor between the shoulders (0,0).
static var _CAPE := Art.smooth_pts(PackedVector2Array([Vector2(-4, -3), Vector2(7, -1), Vector2(6, 14), Vector2(0, 30), Vector2(-8, 42),
		Vector2(-22, 47), Vector2(-27, 40), Vector2(-19, 22), Vector2(-13, 6)]), 3)
static var _CAPE_LINING := Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(-30, 20), Vector2(-10, 30), Vector2(-4, 40),
		Vector2(-20, 52), Vector2(-34, 44)]), 2), _CAPE)


const FACE_SKIN := Color("ffd9b8")
## Where the face sits in each gear tier's helmet: position and scale.
const FACE_AT: Array = [
	[Vector2(6, -70), 0.58], [Vector2(5, -66), 0.62], [Vector2(5, -67), 0.6], [Vector2(7, -70), 0.6], [Vector2(6, -68), 0.6],
	[Vector2(5, -65), 0.62], [Vector2(5, -66), 0.62], [Vector2(8, -70), 0.58], [Vector2(8, -66), 0.6], [Vector2(5, -65), 0.62]]


## The helmet with its face is drawn once per mood and blink (the lamp's
## pulse in steps), then pasted.
static func _diver_head(ci: CanvasItem, tier: int, suit: Color, dark: Color, emotion: String, blink: bool, t: float, st: Dictionary) -> void:
	# The pulse of the lamp (tiers 5 and 7) in 6 steps.
	var dyn := 0
	if tier == 5:
		dyn = roundi((0.6 + 0.4 * sin(t * 5.0)) * 6.0)
	elif tier == 7:
		dyn = roundi((0.6 + 0.4 * sin(t * 4.0)) * 6.0)
	var key := hash([4, _depth, suit, emotion, blink, dyn, _small])
	if Art.cache_begin(ci, key):
		return
	_head_pre(ci, tier, suit, st, dyn / 6.0)
	var fa: Array = FACE_AT[mini(tier, 9)]
	var fs: float = fa[1]
	Art.push(ci, fa[0], 0.0, Vector2(fs, fs))
	_face_draw(ci, emotion, blink, FACE_SKIN)
	Art.pop(ci)
	_head_post(ci, tier, suit, st, dyn / 6.0)
	Art.cache_end(ci, key)


static func _head_pre(ci: CanvasItem, tier: int, suit: Color, st: Dictionary, pulse: float) -> void:
	var skin := FACE_SKIN
	var c: Color = st["ore"]
	var c2: Color = st["ore2"]
	var g := pulse
	match tier:
		0:
			# Brass helmet with a porthole for the face.
			Art.t_circle(ci, Vector2(2, -70), 21, Art.BRASS, 2.8, 0.7)
			Art.t_rect(ci, Rect2(-3, -95, 10, 6), 2, Color("d19230"), 2.2, 0.0)
			Art.t_circle(ci, Vector2(-15, -71), 5, Color("d19230"), 2.0, 0.0)
			_porthole_pre(ci, Vector2(6, -70), 14.5, 12.0, Color("b8782a"))
		1:
			# Neoprene hood, the face, a mask and a regulator.
			var hood := Art.shade_of(suit, 0.55)
			Art.t_circle(ci, Vector2(1, -68), 19, hood, 2.6, 0.5)
			Art.flat(ci, _FACE_EDGE, Art.shade_of(hood, 0.2))
			Art.flat(ci, _FACE_OPEN, skin)
			# Mask strap and rim, the face seen through the glass, a glint.
			Art.line_c(ci, PackedVector2Array([Vector2(-17, -72), Vector2(-5, -71)]), Art.INK, 3.5)
			Art.toon(ci, _MASK_RIM, Color("ff6f61"), 1.6, 0.0)
			Art.flat(ci, _MASK_GLASS, skin.lerp(Color(0.75, 0.95, 1.0), 0.35))
		2:
			var hood := Color("2a2f45")
			Art.t_circle(ci, Vector2(1, -68), 19.5, hood, 2.6, 0.5)
			Art.toon(ci, _FULL_MASK, Color("ffb52e"), 2.4, 0.4)
			Art.toon(ci, _FULL_GLASS, skin, 1.8, 0.0)
		3:
			# Hard-suit dome: metal, a big front window, rivets and a lamp.
			Art.t_circle(ci, Vector2(2, -71), 22, Color("a9b4c8"), 2.8, 0.7)
			Art.t_rect(ci, Rect2(-19, -73, 42, 6), 2, suit, 0.0, 0.0)
			Art.t_circle(ci, Vector2(-15, -71), 5.5, Color("8a94a8"), 2.0, 0.0)
			Art.flat(ci, Art.circle_pts(Vector2(-15, -71), 3, 10), Color(0.75, 0.95, 1.0, 0.8))
			_porthole_pre(ci, Vector2(7, -70), 14.5, 12.5, Color("6a7488"))
		4:
			# Heat-proof hood with a big orange visor.
			Art.toon(ci, _HEAT_HOOD, Color("dfe4ec"), 2.6, 0.6)
			Art.toon(ci, _VISOR, skin, 2.2, 0.0)
		5:
			# Glass bubble helmet over a sleek cap, with an antenna light.
			Art.t_circle(ci, Vector2(3, -68), 16.5, skin, 2.2, 0.3)
			Art.toon(ci, _CAP5, Color("2a2f45"), 1.8, 0.3)
		7:
			# Armored mech helm: a wide visor, an ear light, a fin on top.
			Art.toon(ci, _MECH_FIN, suit, 2.2, 0.3)
			Art.t_rect(ci, Rect2(-18, -93, 42, 42), 15, MECH, 2.8, 0.6)
			Art.t_circle(ci, Vector2(-16, -72), 6.5, MECH_LIGHT, 2.2, 0.0)
			Art.dot(ci, Vector2(-16, -72), 2.6, Color(PLASMA, pulse))
			Art.t_rect(ci, Rect2(-7.5, -85.5, 31, 28), 9.5, suit, 0.0, 0.0)
			Art.flat(ci, _MECH_VISOR, skin)
		8:
			# Atlantean helm: a gold dome with a fin crest, the face open.
			Art.toon(ci, _CREST, suit, 2.2, 0.0)
			Art.t_circle(ci, Vector2(2, -71), 21, MYTH_GOLD, 2.8, 0.6)
			Art.toon(ci, _MYTH_OPEN, skin, 2.0, 0.0)
		9:
			# The ocean king: a glass dome with a crown on top.
			Art.t_circle(ci, Vector2(3, -68), 16.5, skin, 2.2, 0.3)
			Art.toon(ci, _CAP5, KING_CAPE, 1.8, 0.3)
		_:
			# Crystal dome: faceted, glowing, the face inside.
			Art.t_circle(ci, Vector2(3, -68), 16, skin, 2.2, 0.3)


static func _head_post(ci: CanvasItem, tier: int, suit: Color, st: Dictionary, pulse: float) -> void:
	var skin := FACE_SKIN
	var c: Color = st["ore"]
	var c2: Color = st["ore2"]
	var g := pulse
	match tier:
		0:
			_porthole_post(ci, Vector2(6, -70), 12.0)
			for b: Vector2 in [Vector2(6, -86.5), Vector2(-9, -76), Vector2(-9, -63), Vector2(21, -76), Vector2(21, -63)]:
				Art.flat(ci, Art.circle_pts(b, 1.8, 8), Color("9a5f1a"))
		1:
			Art.flat(ci, Art.rrect_pts(Rect2(-1, -72, 4, 3), 1.2), Color(1, 1, 1, 0.7))
			Art.t_rect(ci, Rect2(4, -59.5, 7, 5), 2.2, Color("3a3f5c"), 1.6, 0.0)
			Art.line_c(ci, _HOSE, Art.INK, 5.2)
			Art.line_c(ci, _HOSE, Color("3a3f5c"), 2.4)
		2:
			Art.flat(ci, _FULL_GLASS, Color(0.7, 0.95, 1.0, 0.1))
			Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-2, -76), Vector2(6, 3), 12, -0.5), _FULL_GLASS), Color(1, 1, 1, 0.55))
			Art.t_rect(ci, Rect2(2, -56, 8, 5), 2, Color("3a3f5c"), 1.6, 0.0)
			# Head lamp.
			Art.t_rect(ci, Rect2(-2, -91, 11, 8), 3, Color("3a3f5c"), 2.0, 0.0)
			Art.t_circle(ci, Vector2(8, -87), 3.2, Color("fff6c2"), 1.6, 0.0)
		3:
			_porthole_post(ci, Vector2(7, -70), 12.5)
			for a in 8:
				var ang := TAU * a / 8.0
				Art.flat(ci, Art.circle_pts(Vector2(7, -70) + Vector2(cos(ang), sin(ang)) * 13.3, 1.2, 6), Color("dfe4ec"))
			Art.t_rect(ci, Rect2(-3, -96, 12, 7), 2.5, Color("6a7488"), 2.2, 0.0)
			Art.t_circle(ci, Vector2(9, -92.5), 3, Color("fff6c2"), 1.6, 0.0)
		4:
			Art.flat(ci, _VISOR, Color(1.0, 0.55, 0.1, 0.5))
			Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(-8, -84), Vector2(0, -84), Vector2(-8, -60), Vector2(-14, -60)]), _VISOR), Color(1, 0.95, 0.8, 0.55))
			for k in 3:
				Art.line_c(ci, PackedVector2Array([Vector2(-14, -88 + k * 5), Vector2(-9, -89 + k * 5)]), Color("b9c2d0"), 1.6)
		5:
			Art.flat(ci, Art.circle_pts(Vector2(2, -70), 21.5, 22), Color(0.75, 0.97, 1.0, 0.2))
			Art.arc_c(ci, Vector2(2, -70), 21.5, 0, TAU, 22, Art.INK, 2.6)
			Art.arc_c(ci, Vector2(2, -70), 18.5, PI * 1.05, PI * 1.45, 5, Color(1, 1, 1, 0.8), 2.6)
			Art.flat(ci, Art.circle_pts(Vector2(15, -80), 2.2, 8), Color(1, 1, 1, 0.8))
			Art.line_c(ci, PackedVector2Array([Vector2(-8, -89), Vector2(-12, -99)]), Art.INK, 2.4)
			Art.dot(ci, Vector2(-12, -100), 3.2, Art.INK)
			Art.dot(ci, Vector2(-12, -100), 2.2, Color(NEON, g))
			Art.dot(ci, Vector2(-12, -100), 5.0, Color(NEON, 0.25 * g))
		7:
			Art.flat(ci, _MECH_VISOR, Color(PLASMA, 0.1))
			Art.flat(ci, _MECH_GLINT, Color(1, 1, 1, 0.5))
		8:
			Art.t_rect(ci, Rect2(-6, -86, 29, 5.5), 2.5, MYTH_DARK, 0.0, 0.0)
			Art.flat(ci, _BROW_GEM, AQUA)
			Art.arc_c(ci, Vector2(2, -71), 20.5, PI * 1.05, PI * 1.4, 5, Color(1, 1, 1, 0.75), 2.2)
		9:
			Art.flat(ci, Art.circle_pts(Vector2(2, -70), 21.5, 22), Color(0.8, 0.95, 1.0, 0.18))
			Art.arc_c(ci, Vector2(2, -70), 21.5, 0, TAU, 12, Art.INK, 2.6)
			Art.arc_c(ci, Vector2(2, -70), 18.5, PI * 1.05, PI * 1.45, 4, Color(1, 1, 1, 0.8), 2.6)
			Art.t_rect(ci, Rect2(-14, -53, 32, 5), 2.5, MYTH_GOLD, 2.0, 0.0)
			Art.toon(ci, _KING_CROWN, MYTH_GOLD, 2.2, 0.0)
			for k in 3:
				Art.flat(ci, _KING_GEMS[k], KING_JEWELS[k])
				Art.flat(ci, _KING_PEARLS[k], KING_WHITE)
		_:
			Art.flat(ci, _CRYSTAL_DOME, Color(c, 0.25))
			for k in 3:
				Art.line_c(ci, PackedVector2Array([_CRYSTAL_DOME[k * 2], Vector2(2, -70)]), Color(c2, 0.35), 1.2)
			Art.ring(ci, _CRYSTAL_DOME, Art.INK, 2.6)
			Art.polyline(ci, PackedVector2Array([_CRYSTAL_DOME[5], _CRYSTAL_DOME[6], _CRYSTAL_DOME[7]]), Color(1, 1, 1, 0.7), 2.0)
			Art.crystal(ci, Vector2(-4, -89), 14, 3.5, -0.35, c, 1.8)
			Art.crystal(ci, Vector2(3, -91), 18, 4, 0.0, c2, 1.8)
			Art.crystal(ci, Vector2(10, -89), 13, 3.5, 0.4, c, 1.8)


static var _FACE_OPEN := Art.ellipse_pts(Vector2(5, -66), Vector2(13, 13.5), 20)
static var _FACE_EDGE := Art.ellipse_pts(Vector2(5, -66), Vector2(15.2, 15.7), 20)
static var _MASK_RIM := Art.rrect_pts(Rect2(-3, -73.5, 17, 10), 4.5)
static var _MASK_GLASS := Art.rrect_pts(Rect2(-1, -71.5, 13, 6), 2.5)
static var _HOSE := PackedVector2Array([Vector2(8, -55), Vector2(4, -50), Vector2(-4, -50)])
## Diver drawn small (in the world, not the big hero): simpler face.
static var _small := false
## Depth of the diver being drawn (its ore colors shape some parts).
static var _depth := 0


## Part cache key of a diver's part: which part, the site (its look), the
## suit and two small numbers (mood, pulse, flags). Plain integer maths,
## because every part of every diver asks for one on every redraw.
static func _dk(part: int, suit: Color, a: int = 0, b: int = 0) -> int:
	return (part << 56) | (_depth << 50) | ((a & 0xFFF) << 38) | ((b & 0x3F) << 32) | suit.to_rgba32()
static var _FULL_MASK := Art.smooth_pts(PackedVector2Array([Vector2(-8, -80), Vector2(5, -86), Vector2(17, -80), Vector2(20, -66),
		Vector2(15, -53), Vector2(5, -50), Vector2(-5, -54), Vector2(-10, -66)]), 3)
static var _FULL_GLASS := Art.smooth_pts(PackedVector2Array([Vector2(-5, -78), Vector2(5, -82), Vector2(15, -78), Vector2(17, -67),
		Vector2(13, -57), Vector2(5, -55), Vector2(-3, -58), Vector2(-7, -67)]), 3)
static var _HEAT_HOOD := Art.smooth_pts(PackedVector2Array([Vector2(-19, -52), Vector2(-21, -72), Vector2(-12, -89), Vector2(4, -93),
		Vector2(18, -86), Vector2(23, -70), Vector2(22, -52)]), 3)
static var _VISOR := Art.smooth_pts(PackedVector2Array([Vector2(-10, -80), Vector2(4, -84), Vector2(18, -79), Vector2(20, -66),
		Vector2(16, -56), Vector2(4, -54), Vector2(-9, -57), Vector2(-12, -68)]), 3)
static var _CAP5 := Art.smooth_pts(PackedVector2Array([Vector2(-13, -64), Vector2(-14, -76), Vector2(-4, -85), Vector2(9, -84),
		Vector2(18, -76), Vector2(10, -78), Vector2(0, -76), Vector2(-7, -70)]), 3)
static var _MECH_FIN := PackedVector2Array([Vector2(-8, -89), Vector2(12, -89), Vector2(7, -103), Vector2(-4, -101)])
static var _MECH_VISOR := Art.rrect_pts(Rect2(-5, -83, 26, 23), 7.5)
static var _MECH_GLINT := Art.clipped(PackedVector2Array([Vector2(-6, -70), Vector2(-6, -76), Vector2(8, -86), Vector2(14, -86)]), _MECH_VISOR)
static var _CREST := Art.smooth_pts(PackedVector2Array([Vector2(-20, -76), Vector2(-24, -90), Vector2(-14, -103), Vector2(2, -109),
		Vector2(12, -100), Vector2(4, -92), Vector2(-6, -88)]), 3)
static var _MYTH_OPEN := Art.ellipse_pts(Vector2(8, -67), Vector2(12.5, 13), 20)
static var _KING_CROWN := PackedVector2Array([Vector2(-11, -88), Vector2(-13, -103), Vector2(-5, -96), Vector2(2, -107),
		Vector2(9, -96), Vector2(17, -103), Vector2(15, -88)])
const KING_JEWELS: Array[Color] = [Color("ff3d6e"), Color("4de8ff"), Color("4fe08a")]
static var _CRYSTAL_DOME := PackedVector2Array([Vector2(-19, -62), Vector2(-20, -76), Vector2(-10, -89), Vector2(4, -92),
		Vector2(17, -86), Vector2(23, -73), Vector2(21, -58), Vector2(10, -50), Vector2(-8, -51)])


## The face inside a diver's mask: the full face when drawn big, a cheaper
## one (dark eyes, a mouth, cheeks) at world size where details are ~1 px.
static func _diver_face(ci: CanvasItem, emotion: String, blink: bool, skin: Color) -> void:
	var key := hash([25, emotion, blink, skin, _small, Art.fringe_min])
	if Art.cache_begin(ci, key):
		return
	_face_draw(ci, emotion, blink, skin)
	Art.cache_end(ci, key)


static func _face_draw(ci: CanvasItem, emotion: String, blink: bool, skin: Color) -> void:
	if not _small:
		face(ci, emotion, blink, skin)
		return
	var e: Array = EMOTIONS.get(emotion, EMOTIONS["happy"])
	var eyes: String = e[0]
	var mouth: String = e[1]
	if blink and eyes in ["open", "wide", "narrow", "star"]:
		eyes = "closed"
	Art.flat(ci, _CHEEK_L, Color(1.0, 0.45, 0.5, 0.35))
	Art.flat(ci, _CHEEK_R, Color(1.0, 0.45, 0.5, 0.35))
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(7.0 * sx, 1.5)
		match eyes:
			"arc":
				Art.arc_c(ci, c + Vector2(0, 2.5), 3.8, PI + 0.4, TAU - 0.4, 5, Art.INK, 2.6)
			"closed":
				Art.arc_c(ci, c + Vector2(0, -1.0), 3.8, 0.4, PI - 0.4, 5, Art.INK, 2.4)
			"x":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, 3)]), Art.INK, 2.2)
				Art.line_c(ci, PackedVector2Array([c + Vector2(3, -3), c + Vector2(-3, 3)]), Art.INK, 2.2)
			"narrow":
				Art.flat(ci, _MINI_EYE_NARROW[0 if sx < 0 else 1], Art.INK)
			_:
				Art.flat(ci, _MINI_EYE[0 if sx < 0 else 1], Art.INK)
				Art.flat(ci, _MINI_GLINT[0 if sx < 0 else 1], Art.WHITE)
	var m := Vector2(0.5, 12.0)
	match mouth:
		"grin", "o":
			Art.flat(ci, _MINI_GRIN if mouth == "grin" else _MINI_O, Color("7a1f33"))
		"flat", "wavy":
			Art.line_c(ci, PackedVector2Array([m + Vector2(-3, 0), m + Vector2(3, 0)]), Art.INK, 2.0)
		"frown":
			Art.arc_c(ci, m + Vector2(0, 2.8), 3.6, PI + 0.5, TAU - 0.5, 5, Art.INK, 2.0)
		_:
			Art.arc_c(ci, m + Vector2(0, -2.5), 4.0, 0.45, PI - 0.45, 6, Art.INK, 2.0)


static var _CHEEK_L := Art.ellipse_pts(Vector2(-11.5, 8.5), Vector2(4, 2.6), 10)
static var _CHEEK_R := Art.ellipse_pts(Vector2(11.5, 8.5), Vector2(4, 2.6), 10)
static var _MINI_EYE: Array[PackedVector2Array] = [Art.ellipse_pts(Vector2(-6.6, 2.1), Vector2(3.0, 3.8), 10), Art.ellipse_pts(Vector2(7.4, 2.1), Vector2(3.0, 3.8), 10)]
static var _MINI_EYE_NARROW: Array[PackedVector2Array] = [Art.ellipse_pts(Vector2(-6.6, 3.2), Vector2(3.2, 1.8), 8), Art.ellipse_pts(Vector2(7.4, 3.2), Vector2(3.2, 1.8), 8)]
static var _MINI_GLINT: Array[PackedVector2Array] = [Art.circle_pts(Vector2(-7.6, 0.6), 1.2, 6), Art.circle_pts(Vector2(6.4, 0.6), 1.2, 6)]
static var _MINI_GRIN := PackedVector2Array([Vector2(-4.7, 10.4), Vector2(5.7, 10.4), Vector2(4.3, 14.6), Vector2(0.5, 16.2), Vector2(-3.3, 14.6)])
static var _MINI_O := Art.ellipse_pts(Vector2(0.5, 12.5), Vector2(2.4, 3.0), 8)


static func _porthole_pre(ci: CanvasItem, c: Vector2, rim: float, glass: float, rim_color: Color) -> void:
	Art.t_circle(ci, c, rim, rim_color, 2.2, 0.0)
	Art.t_circle(ci, c, glass, Color("dff8ff"), 0.0, 0.0)
	Art.flat(ci, Art.circle_pts(c + Vector2(0.5, 1.5), glass - 1.0, 24), FACE_SKIN)


static func _porthole_post(ci: CanvasItem, c: Vector2, glass: float) -> void:
	Art.flat(ci, Art.clipped(Art.circle_pts(c + Vector2(-6, -6), 7, 14), Art.circle_pts(c, glass, 24)), Color(1, 1, 1, 0.5))


static func _diver_arm(ci: CanvasItem, shoulder: Vector2, angle: float, suit: Color, front: bool, tier: int, st: Dictionary) -> void:
	# A stiff piece: sleeve and glove are drawn once and turned at the shoulder.
	Art.push(ci, shoulder, -angle)
	var key := _dk(5, suit, int(front))
	if not Art.cache_begin(ci, key):
		_arm_shape(ci, suit, front, tier, st)
		Art.cache_end(ci, key)
	Art.pop(ci)


static func _arm_shape(ci: CanvasItem, suit: Color, front: bool, tier: int, st: Dictionary) -> void:
	var c := suit if front else Art.shade_of(suit, 0.35)
	match tier:
		3:
			Art.t_rect(ci, Rect2(-5.5, -3, 11, 19), 5.5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 5, 12, 4), 2, Art.shade_of(Color("8a94a8"), 0.0 if front else 0.35), 1.6, 0.0)
		4:
			Art.t_rect(ci, Rect2(-5, -3, 10, 19), 5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 8, 10, 3), 1, Color("ff9a1f") if front else Color("c07020"), 0.0, 0.0)
		5:
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-1, 0, 2.2, 12), 1, Color(NEON, 0.9 if front else 0.5), 0.0, 0.0)
		7:
			Art.t_rect(ci, Rect2(-6, -3, 12, 19), 6, MECH if front else Art.shade_of(MECH, 0.35), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-1.1, 6, 2.2, 8), 1, Color(PLASMA, 0.9 if front else 0.5), 0.0, 0.0)
			Art.toon(ci, _PAULDRON, c, 2.2, 0.0)
		8:
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 7, 10, 6), 2, MYTH_GOLD if front else MYTH_DARK, 0.0, 0.0)
		9:
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 9, 10, 4), 1.5, MYTH_GOLD if front else MYTH_DARK, 0.0, 0.0)
		_:
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
	if tier == 2 and front:
		Art.t_rect(ci, Rect2(-4.5, 9, 9, 5), 1.5, Color("2a2f45"), 1.4, 0.0)
		Art.flat(ci, Art.rrect_pts(Rect2(-2.8, 10, 5.6, 3), 1), Color("7df9a0"))
	_glove(ci, Vector2(0, ARM_LEN), tier, st, front)


static func _glove(ci: CanvasItem, at: Vector2, tier: int, st: Dictionary, front: bool = true) -> void:
	var g := Color("4a4f6a")
	match tier:
		1, 2:
			g = Color("2f3a5c")
		3:
			g = Color("8a94a8")
		4:
			g = Color("dfe4ec")
		5:
			g = Color("2a2f45")
		6:
			g = (st["ore2"] as Color)
		7:
			g = MECH_LIGHT
		8:
			g = MYTH_GOLD
		9:
			g = KING_WHITE
	if not front:
		g = Art.shade_of(g, 0.3)
	# Pushed so the cached circle is reused wherever the hand is.
	Art.push(ci, at)
	Art.t_circle(ci, Vector2.ZERO, 6.0 if tier == 7 else (5.2 if tier == 3 else 5.0), g, 2.2, 0.0)
	Art.pop(ci)


## The dig tool, held in the front hand (drawn behind the head so a raised
## pick goes over and behind the helmet, never across the face).
static func _tool(ci: CanvasItem, tool: String, tier: int, angle: float, wrist: float, hit: float, t: float, st: Dictionary, arm: String) -> void:
	var hand := SHOULDER_F + Vector2(sin(angle), cos(angle)) * ARM_LEN
	match tool:
		"pick", "hammer":
			Art.push(ci, hand, -angle + wrist)
			var key := _dk(6, Color.BLACK)
			if not Art.cache_begin(ci, key):
				if tool == "pick":
					_pick(ci, tier)
				else:
					_hammer(ci, st)
				Art.cache_end(ci, key)
			Art.pop(ci)
		"drill", "laser", "plasma", "trident":
			# Held level, pointing forward; it works while pressed in.
			var u := fposmod(hit, 1.0) if arm == "dig" else lerpf(0.5, DIG_IMPACT, clampf(hit, 0.0, 1.0))
			var on := u >= DIG_IMPACT - 0.02 and u < 0.9
			Art.push(ci, hand, 0.0)
			match tool:
				"drill":
					_drill(ci, tier, t, on)
				"laser":
					_laser(ci, tier, t, on, st)
				"plasma":
					_plasma(ci, t, on)
				_:
					_trident(ci, t, on)
			Art.pop(ci)


## Pick in hand space: the fist at 0,0, the handle along +y, the head at
## its end with the long point facing -x (the way the swing goes).
static func _pick(ci: CanvasItem, tier: int) -> void:
	var handle := Art.WOOD
	var head := Color("a9b4c8")
	match tier:
		1:
			handle = Art.WOOD_DARK
			head = Color("d5e2f0")
		2:
			handle = Color("3a3f5c")
			head = Color("e3ecf7")
	Art.t_rect(ci, Rect2(-2.6, -6, 5.2, 38), 2.6, handle, 1.8, 0.0)
	if tier >= 1:
		Art.flat(ci, Art.rrect_pts(Rect2(-3.2, -5, 6.4, 9), 2, 2), Color("ef5350") if tier == 1 else Color("ffcf33"))
	Art.toon(ci, _PICK_HEAD, head, 2.0, 0.4)
	Art.line_c(ci, PackedVector2Array([Vector2(-14, 27.6), Vector2(-4, 27.8)]), Color(1, 1, 1, 0.65), 1.4)
	Art.t_rect(ci, Rect2(-4, 25.5, 8, 10), 2, Art.GOLD if tier == 2 else Art.shade_of(head, 0.25), 1.6, 0.0)


static var _PICK_HEAD := Art.smooth_pts(PackedVector2Array([Vector2(4, 26.5), Vector2(-6, 26.5), Vector2(-14, 27.5), Vector2(-20, 26),
		Vector2(-17, 30), Vector2(-8, 33.5), Vector2(4, 34), Vector2(11, 34.5), Vector2(12.5, 30), Vector2(11, 27)]), 2)


static func _drill(ci: CanvasItem, tier: int, t: float, on: bool) -> void:
	var body := Color("ffb52e") if tier == 3 else Color("ef5350")
	var big := 1.0 if tier == 3 else 1.15
	var shake := Vector2(sin(t * 57.0), cos(t * 43.0)) * 0.8 if on else Vector2.ZERO
	Art.push(ci, shake, 0.0, Vector2(big, big))
	var spinq := int(fposmod(t * (14.0 if on else 1.0), 1.0) * 8.0) % 8
	var key := _dk(7, Color.BLACK, spinq)
	if Art.cache_begin(ci, key):
		Art.pop(ci)
		return
	# Grip under the fist, motor body on top, chuck and a spiral bit.
	Art.t_rect(ci, Rect2(-3.5, -6, 7, 12), 3, Color("3a3f5c"), 1.8, 0.0)
	Art.t_rect(ci, Rect2(-8, -14, 30, 11), 5, body, 2.2, 0.5)
	Art.t_rect(ci, Rect2(-5, -12, 4, 7), 1.5, Art.shade_of(body, 0.35), 0.0, 0.0)
	Art.t_rect(ci, Rect2(21, -12.5, 6, 8), 2, Color("5a5f7a"), 1.8, 0.0)
	Art.toon(ci, _DRILL_BIT, Color("cbd5e1"), 1.8, 0.0)
	var spin := spinq / 8.0
	for k in 3:
		var x := 28.0 + (k + spin) * 4.5
		if x < 40.0:
			var hw := 3.8 * (1.0 - (x - 27.0) / 16.0)
			Art.line(ci, Vector2(x - 1.2, -8.5 - hw), Vector2(x + 1.2, -8.5 + hw), Color("7c8aa5"), 1.4)
	Art.cache_end(ci, key)
	Art.pop(ci)


static var _DRILL_BIT := PackedVector2Array([Vector2(27, -12.5), Vector2(38, -10), Vector2(44, -8.5), Vector2(38, -7), Vector2(27, -4.5)])


static func _laser(ci: CanvasItem, tier: int, t: float, on: bool, st: Dictionary) -> void:
	var glow: Color = NEON if tier == 5 else (st["ore"] as Color)
	var body := Color("e9eef6") if tier == 5 else (st["ore2"] as Color).lerp(Color.WHITE, 0.4)
	var key := _dk(8, Color.BLACK, int(on))
	if not Art.cache_begin(ci, key):
		Art.t_rect(ci, Rect2(-3.5, -6, 7, 12), 3, Color("2a2f45"), 1.8, 0.0)
		Art.toon(ci, _LASER_BODY, body, 2.2, 0.5)
		Art.t_rect(ci, Rect2(2, -12.5, 16, 2.6), 1, Color(glow, 0.9), 0.0, 0.0)
		Art.t_rect(ci, Rect2(26, -13.5, 5, 9), 2, Color("2a2f45"), 1.8, 0.0)
		Art.disc(ci, Vector2(31.5, -9), 3.2, Color(glow, 1.0 if on else 0.6))
		Art.cache_end(ci, key)
	var pulse := 0.5 + 0.5 * sin(t * 30.0)
	if on:
		# The cutting beam, reaching the deposit.
		var len := 22.0
		Art.flat_now(ci, PackedVector2Array([Vector2(31, -11.5), Vector2(31 + len, -10.5), Vector2(31 + len, -7.5), Vector2(31, -6.5)]), Color(glow, 0.55 + 0.2 * pulse))
		Art.line(ci, Vector2(31, -9), Vector2(31 + len, -9), Color(1, 1, 1, 0.95), 1.6)
		Art.dot(ci, Vector2(31 + len, -9), 5.0 + pulse * 3.0, Color(glow, 0.45))
		Art.dot(ci, Vector2(31 + len, -9), 2.5 + pulse, Color(1, 1, 1, 0.95))


static var _LASER_BODY := Art.smooth_pts(PackedVector2Array([Vector2(-7, -15), Vector2(20, -15), Vector2(27, -12), Vector2(27, -5),
		Vector2(20, -3), Vector2(-7, -3)]), 2)


## Tier 7: a chunky plasma drill with a spinning cone of light.
static func _plasma(ci: CanvasItem, t: float, on: bool) -> void:
	var shake := Vector2(sin(t * 53.0), cos(t * 41.0)) * 0.7 if on else Vector2.ZERO
	Art.push(ci, shake, 0.0, Vector2(1.1, 1.1))
	var spinq := int(fposmod(t * (12.0 if on else 1.0), 1.0) * 8.0) % 8
	var key := _dk(9, Color.BLACK, spinq)
	if not Art.cache_begin(ci, key):
		Art.t_rect(ci, Rect2(-3.5, -6, 7, 12), 3, MECH_CORE, 1.8, 0.0)
		Art.t_rect(ci, Rect2(-9, -16, 30, 13), 5, MECH, 2.2, 0.0)
		Art.flat(ci, _PLASMA_STRIPE, PLASMA)
		Art.t_rect(ci, Rect2(20, -17, 6, 16), 2, MECH_LIGHT, 1.8, 0.0)
		Art.toon(ci, _PLASMA_CONE, Color("ffc2f2"), 1.8, 0.0)
		var spin := spinq / 8.0
		for k in 3:
			var x := 27.0 + (k + spin) * 5.5
			if x < 44.0:
				var hw := 6.3 * (1.0 - (x - 26.0) / 20.0)
				Art.line(ci, Vector2(x - 1.2, -9 - hw), Vector2(x + 1.2, -9 + hw), PLASMA, 1.6)
		Art.cache_end(ci, key)
	if on:
		var pulse := 0.5 + 0.5 * sin(t * 30.0)
		Art.dot(ci, Vector2(46, -9), 6.0 + pulse * 3.0, Color(PLASMA, 0.45))
		Art.dot(ci, Vector2(46, -9), 2.5 + pulse, Color(1, 1, 1, 0.95))
	Art.pop(ci)


static var _PLASMA_CONE := PackedVector2Array([Vector2(26, -15.5), Vector2(46, -9.6), Vector2(46, -8.4), Vector2(26, -2.5)])


## Tier 8: a golden trident, thrust into the vein.
static func _trident(ci: CanvasItem, t: float, on: bool) -> void:
	if not Art.cache_begin(ci, _dk(10, Color.BLACK)):
		Art.t_rect(ci, Rect2(-16, -11.2, 58, 4.4), 2, MYTH_DARK, 1.8, 0.0)
		Art.flat(ci, _TRIDENT_GRIP, MYTH_GOLD)
		Art.toon(ci, _TRIDENT, MYTH_GOLD, 2.0, 0.0)
		Art.flat(ci, _TRIDENT_GEM, AQUA)
		Art.cache_end(ci, _dk(10, Color.BLACK))
	if on:
		var pulse := 0.5 + 0.5 * sin(t * 24.0)
		for p: Vector2 in [Vector2(57, -9), Vector2(53, -17.5), Vector2(53, -0.5)]:
			Art.dot(ci, p, 3.5 + pulse * 2.5, Color(AQUA, 0.55))
			Art.dot(ci, p, 1.4 + pulse, Color(1, 1, 1, 0.95))


static var _TRIDENT := Art.union([Art.rrect_pts(Rect2(38, -20, 5, 22), 2, 2),
		PackedVector2Array([Vector2(42, -10.6), Vector2(52, -11), Vector2(52, -14), Vector2(58, -9), Vector2(52, -4), Vector2(52, -7), Vector2(42, -7.4)]),
		PackedVector2Array([Vector2(41, -20), Vector2(50, -20), Vector2(50, -22), Vector2(55, -17.5), Vector2(50, -15), Vector2(50, -16.8), Vector2(41, -16.8)]),
		PackedVector2Array([Vector2(41, -1.2), Vector2(50, -1.2), Vector2(50, -3), Vector2(55, -0.5), Vector2(50, 2), Vector2(41, 2)])])


## Tier 9: the king's hammer in hand space (the fist at 0,0, the handle
## along +y like the pick, the striking face toward -x).
static func _hammer(ci: CanvasItem, st: Dictionary) -> void:
	Art.t_rect(ci, Rect2(-2.8, -7, 5.6, 36), 2.8, MYTH_GOLD, 1.8, 0.0)
	Art.flat(ci, _HAMMER_GRIP, KING_CAPE)
	Art.t_rect(ci, Rect2(-15, 24, 27, 14), 4, KING_WHITE, 2.2, 0.0)
	Art.flat(ci, _HAMMER_BANDS[0], MYTH_GOLD)
	Art.flat(ci, _HAMMER_BANDS[1], MYTH_GOLD)
	Art.push(ci, Vector2(-1.5, 31), 0.0, Vector2(0.3, 0.3))
	Art.toon(ci, OreArt.HEART_LO, st["ore"], 5.0, 0.0)
	Art.pop(ci)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, 27), Vector2(1.6, 1.0), 6), Color(1, 1, 1, 0.8))


## Bubbles, lamp light and halos around the diver.
static func _diver_fx(ci: CanvasItem, tier: int, t: float, swim: bool, st: Dictionary) -> void:
	# Breathing bubbles rise from the helmet in little bursts.
	var src := Vector2(-6, -92) if tier == 0 else Vector2(-2, -86)
	if tier == 1:
		src = Vector2(12, -56)
	for k in 3:
		var f := fposmod(t * 0.45 + k * 0.33, 1.0)
		if f < 0.75:
			var p := src + Vector2(sin(f * 9.0 + k) * 3.0 - f * 6.0, -f * 34.0)
			var r := 1.6 + f * 2.2
			# One dot per bubble: a white rim over a blue tint looked the same
			# at this size.
			Art.dot(ci, p, r + 0.6, Color(0.9, 0.98, 1.0, 0.5 * (1.0 - f / 0.75)))
	match tier:
		2:
			# Soft cone of light from the head lamp.
			Art.grad(ci, PackedVector2Array([Vector2(11, -90), Vector2(52, -104), Vector2(52, -66), Vector2(11, -84)]),
					PackedColorArray([Color(1, 0.97, 0.75, 0.35), Color(1, 0.97, 0.75, 0.0), Color(1, 0.97, 0.75, 0.0), Color(1, 0.97, 0.75, 0.35)]))
		3:
			Art.grad(ci, PackedVector2Array([Vector2(12, -95), Vector2(50, -108), Vector2(50, -76), Vector2(12, -90)]),
					PackedColorArray([Color(1, 0.97, 0.75, 0.3), Color(1, 0.97, 0.75, 0.0), Color(1, 0.97, 0.75, 0.0), Color(1, 0.97, 0.75, 0.3)]))
		6:
			# Halo of bubbles orbiting the head.
			var c: Color = st["ore2"]
			for k in 7:
				var a := t * 1.4 + TAU * k / 7.0
				var p := Vector2(2, -76) + Vector2(cos(a) * 30.0, sin(a) * 9.0 - 18.0)
				var near := sin(a) * 0.5 + 0.5
				Art.dot(ci, p, 2.6 + near * 1.6, Color(c, 0.45 + near * 0.3))
				Art.disc(ci, p + Vector2(-0.8, -0.8), 1.0, Color(1, 1, 1, 0.8))
		9:
			# Little sparkles circling the king.
			for k in 3:
				var a := t * 1.1 + TAU * k / 3.0
				var p := Vector2(2, -50) + Vector2(cos(a) * 32.0, sin(a) * 14.0 - 16.0)
				Art.push(ci, p, t * 2.0 + k, Vector2.ONE * (0.6 + 0.4 * (sin(a) * 0.5 + 0.5)))
				Art.toon(ci, _SPARK, Color(1.0, 0.93, 0.6, 0.95), 0.0, 0.0)
				Art.pop(ci)


static var _SPARK := Art.star_pts(Vector2.ZERO, 5.0, 1.3, 4)
static var _HAMMER_GRIP := Art.rrect_pts(Rect2(-3.4, -4, 6.8, 9), 2, 1)
static var _HAMMER_BANDS: Array[PackedVector2Array] = [Art.rrect_pts(Rect2(-14, 25, 3.5, 12), 1, 1), Art.rrect_pts(Rect2(7.5, 25, 3.5, 12), 1, 1)]
static var _TRIDENT_GRIP := Art.rrect_pts(Rect2(-4.5, -12, 9, 6), 2, 1)
static var _TRIDENT_GEM := Art.circle_pts(Vector2(41, -9), 2.4, 8)
static var _BROW_GEM := Art.circle_pts(Vector2(8, -83), 2.6, 8)
static var _PLASMA_STRIPE := PackedVector2Array([Vector2(-6, -13.5), Vector2(16, -13.5), Vector2(16, -11), Vector2(-6, -11)])
static var _CUIRASS_GEM := Art.circle_pts(Vector2(0, -31.5), 3.0, 8)
static var _BELT_JEWEL := Art.circle_pts(Vector2(0, -21.5), 2.8, 8)
static var _PAULDRON := Art.ellipse_pts(Vector2(0, -1), Vector2(8, 6.5), 12)
static var _MECH_CORE_PTS := Art.circle_pts(Vector2(0, -37), 4.6, 10)
static var _KNEE := Art.circle_pts(Vector2(0, 5), 3.2, 8)
static var _GLINT6 := Art.ellipse_pts(Vector2(-7, -7), Vector2(3, 4.5), 6, 0.6)
static var _SHIELD_IN := Art.circle_pts(Vector2(-20, -40), 10, 14)
## A little trident on the shield (one flat shape).
static var _SHIELD_MARK := PackedVector2Array([Vector2(-21, -32), Vector2(-21, -41), Vector2(-24.5, -44), Vector2(-24.5, -48), Vector2(-23.3, -48),
		Vector2(-23.3, -45), Vector2(-21, -43), Vector2(-21, -49), Vector2(-19, -49), Vector2(-19, -43), Vector2(-16.7, -45), Vector2(-16.7, -48),
		Vector2(-15.5, -48), Vector2(-15.5, -44), Vector2(-19, -41), Vector2(-19, -32)])
static var _SKIRT_STRIPS := Art.rrect_pts(Rect2(-3, -24, 6, 8.5), 1.5, 1)
static var _KING_GEMS: Array[PackedVector2Array] = [Art.circle_pts(Vector2(-5, -91.5), 1.9, 6), Art.circle_pts(Vector2(2, -91.5), 1.9, 6), Art.circle_pts(Vector2(9, -91.5), 1.9, 6)]
static var _KING_PEARLS: Array[PackedVector2Array] = [Art.circle_pts(Vector2(-11, -104), 2.2, 8), Art.circle_pts(Vector2(2, -108), 2.2, 8), Art.circle_pts(Vector2(15, -104), 2.2, 8)]
