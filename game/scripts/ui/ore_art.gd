class_name OreArt
extends RefCounted
## What each dive site digs up: the deposit at the end of the cave, the
## chunk a diver carries in the sack and the chips that fly off the pick.
## Every site has its own shape (shells, coral, pearls in clams, copper
## nuggets, ... fallen stars) colored by its Art.DEPTH_STYLE ore colors.
##
## Pieces are drawn in a unit space where one piece is ~40 px tall and
## stands on (0, 0), then placed with Art.push, so their geometry is cached.

## The art kind of each site id (the id itself when it has its own art).
## Sites come from the current world (Art.site_ids, set by WorldLook).
const KIND_OF := {"magma": "lava", "crater_ice": "ice", "moonstone": "moon", "nebula": "void", "cosmic_heart": "heart",
		"shroom": "glow", "garnet": "garnet", "ember": "ember"}
## Kinds that give off light (a soft pulsing glow behind them).
const GLOWING: Array[String] = ["lava", "moon", "glow", "atlantis", "meteor", "star", "kraken",
		"vent", "storm", "dragon", "void", "time", "heart", "ember", "phoenix", "radiant", "slime", "comet", "alien_egg",
		"ufo", "fire_opal", "goo_king"]
## Kinds that sit in a mound of rock.
const IN_ROCK: Array[String] = ["copper", "lava", "fossil", "meteor", "obsidian", "storm", "ash", "garnet", "moss", "dust"]
## Kinds with a big centerpiece of their own (loose pieces lie in front of it).
const CENTERPIECE: Array[String] = ["gold", "kraken", "atlantis", "pearl", "vent", "whale", "mirror", "dragon", "crown", "void", "time", "heart",
		"phoenix", "goo_king", "alien_egg", "ufo"]


static func kind_of(depth: int) -> String:
	var ids: Array[String] = Art.site_ids
	var id := ids[clampi(depth, 0, ids.size() - 1)]
	return KIND_OF.get(id, id)


static func style_of(depth: int) -> Dictionary:
	return Art.DEPTH_STYLE[clampi(depth, 0, Art.DEPTH_STYLE.size() - 1)]


## Deposit standing on `base` (bottom center), about `size` px tall, made of
## `count` pieces. `seed` varies the layout, `t` animates glows and sways.
## big = false leaves out the centerpiece (chest, clam, column, tentacles)
## and the rock mound: a small vein in a wall.
static func deposit(ci: CanvasItem, base: Vector2, size: float, depth: int, seed: int, t: float, count: int = 5, big: bool = true) -> void:
	var st := style_of(depth)
	var kind := kind_of(depth)
	var ore: Color = st["ore"]
	var s := size / 40.0
	if kind in GLOWING:
		var g := 0.3 + 0.1 * sin(t * 2.2 + seed)
		Art.glow(ci, base + Vector2(0, -size * 0.4), size * 0.95, Color(ore, g))
	if kind in IN_ROCK and big:
		_mound(ci, base, s * 0.8, st, kind)
	match kind if big else "":
		"gold":
			_chest(ci, base + Vector2(0, 1), s * 0.95, st, t)
		"kraken":
			for k in 2:
				Art.push(ci, base + Vector2((k * 2 - 1) * size * 0.34, 2), 0.0, Vector2((k * 2 - 1) * s, s) * (1.1 - k * 0.2))
				tentacle(ci, t * 1.3 + k * 2.1)
				Art.pop(ci)
		"atlantis":
			Art.push(ci, base + Vector2(-size * 0.2, 2), -0.08, Vector2(s, s) * 1.4)
			column(ci)
			Art.pop(ci)
		"pearl":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.45)
			_clam(ci, ore, st["ore2"], t, seed)
			Art.pop(ci)
		"vent", "whale", "mirror", "dragon", "crown", "void", "time", "heart", "phoenix", "goo_king", "alien_egg", "ufo":
			centerpiece(ci, kind, base, s, st, t, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var order: Array[int] = []
	for i in count:
		order.append(i)
	order.sort_custom(func(a, b): return absf(a - (count - 1) / 2.0) > absf(b - (count - 1) / 2.0))
	var specs := []
	for i in count:
		specs.append([rng.randf_range(-3, 3), rng.randf_range(0.7, 1.05), rng.randf_range(-0.22, 0.22)])
	for i in order:
		var off := float(i) - (count - 1) / 2.0
		var x: float = base.x + off * size * 0.3 + specs[i][0]
		var h: float = specs[i][1] * (1.0 - absf(off) * 0.17)
		var rot: float = (specs[i][2] + off * 0.14) * _tilt(kind)
		var y := base.y + 2.0
		if big and kind in CENTERPIECE:
			# Loose treasure in front of the big piece.
			h *= 0.55
			y += 4.0
		piece(ci, kind, Vector2(x, y), s * h, rot, st, t, i + seed)


## One piece standing on `at`; `s` = 1.0 is ~40 px tall.
static func piece(ci: CanvasItem, kind: String, at: Vector2, s: float, rot: float, st: Dictionary, t: float, i: int) -> void:
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	Art.push(ci, at, rot, Vector2(s, s))
	match kind:
		"shells":
			if i % 2 == 0:
				_scallop(ci, ore, ore2)
			else:
				_conch(ci, ore2, ore)
		"coral":
			_coral(ci, ore, ore2, t, i)
		"pearl":
			_pearl(ci, ore, ore2)
		"copper":
			_nugget(ci, ore, ore2, i)
		"emerald":
			_prism(ci, ore, ore2)
		"crystal":
			Art.crystal(ci, Vector2.ZERO, 40, 8, 0.0, ore if i % 2 == 0 else ore2, 2.0)
		"amber":
			_amber(ci, ore, ore2, i % 2 == 0)
		"sapphire":
			_hex_gem(ci, ore, ore2)
		"gold":
			if i % 2 == 0:
				_bar(ci, ore, ore2)
			else:
				_coins(ci, ore, ore2)
		"ruby":
			if i % 3 == 1:
				_cut_gem(ci, ore, ore2)
			else:
				Art.crystal(ci, Vector2.ZERO, 46, 5.5, 0.0, ore if i % 2 == 0 else ore.lightened(0.15), 2.0)
		"ice":
			_ice(ci, ore, ore2, i)
		"lava":
			_lava_rock(ci, ore, ore2, t, i)
		"jade":
			_tablet(ci, ore, ore2, i)
		"moon":
			_moonstone(ci, ore, ore2, t, i)
		"fossil":
			if i % 2 == 0:
				_ammonite(ci, ore, ore2)
			else:
				_bone(ci, ore2)
		"obsidian":
			_shard(ci, ore, ore2, i)
		"glow":
			_mushroom(ci, ore, ore2, t, i)
		"atlantis":
			_relic(ci, ore, ore2, i)
		"meteor":
			_meteorite(ci, ore, ore2, t, i)
		"kraken":
			_cut_gem(ci, ore, ore2)
		"star":
			_star(ci, ore, ore2, t, i)
		"vent", "whale", "mirror", "storm", "dragon", "crown", "void", "time", "heart":
			abyss_piece(ci, kind, ore, ore2, t, i)
		"ash", "sulfur", "fire_opal", "garnet", "ember", "phoenix", "slime", "moss", "bubble", "venom", "radiant", \
				"goo_king", "dust", "comet", "alien_egg", "ufo":
			world_piece(ci, kind, ore, ore2, t, i)
		_:
			Art.crystal(ci, Vector2.ZERO, 40, 8, 0.0, ore, 2.0)
	Art.pop(ci)


## A single loose piece centered on `at` (sack contents, a carried chunk,
## the ore pile); `size` is about its half height in px.
static func chunk(ci: CanvasItem, at: Vector2, size: float, depth: int, rot: float = 0.0) -> void:
	var kind := kind_of(depth)
	var st := style_of(depth)
	var s := size / 20.0
	Art.push(ci, at, rot)
	match kind:
		"gold":
			piece(ci, kind, Vector2(0, 10 * s), s * 1.5, 0.0, st, 0.0, 0)
		"kraken", "atlantis", "time":
			piece(ci, kind, Vector2(0, 16 * s), s * 1.3, 0.0, st, 0.0, 1)
		"pearl", "copper", "moon", "lava", "meteor", "sapphire", "star", "fossil", "dragon", "ash", "fire_opal", "garnet", \
				"slime", "moss", "bubble", "dust", "comet", "ufo", "alien_egg":
			piece(ci, kind, Vector2(0, 20 * s), s * 1.3, 0.0, st, 0.0, 1)
		"crown", "void", "heart":
			piece(ci, kind, Vector2(0, 16 * s), s * 1.3, 0.0, st, 0.0, 0)
		_:
			piece(ci, kind, Vector2(0, 20 * s), s, 0.0, st, 0.0, 0)
	Art.pop(ci)


## A small fragment knocked off the deposit (flying chips).
static func chip(ci: CanvasItem, at: Vector2, size: float, depth: int, rot: float) -> void:
	var st := style_of(depth)
	var kind := kind_of(depth)
	var c: Color = st["ore"]
	Art.push(ci, at, rot, Vector2(size, size) / 4.0)
	match kind:
		"star", "moon", "glow", "storm", "crown", "heart", "radiant", "comet", "void", "dust":
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 5.0, 2.2, 4), st["ore2"], 1.2, 0.0)
		"slime", "bubble", "venom", "goo_king":
			Art.t_circle(ci, Vector2.ZERO, 3.0, c, 1.2, 0.0)
		"ember", "phoenix":
			Art.toon(ci, _CHIP, Color("ffb02e"), 1.2, 0.0)
		"dragon":
			Art.toon(ci, _CHIP, c.lightened(0.2), 1.2, 0.0)
		"mirror":
			Art.toon(ci, _CHIP, Color("eef4ff"), 1.2, 0.0)
		"pearl":
			Art.t_circle(ci, Vector2.ZERO, 3.2, c, 1.2, 0.0)
		"lava":
			Art.toon(ci, _CHIP, c.lightened(0.2), 1.2, 0.0)
		"obsidian":
			Art.toon(ci, _CHIP, Color("2b2340"), 1.2, 0.0)
		_:
			Art.toon(ci, _CHIP, c, 1.2, 0.0)
	Art.pop(ci)


static var _CHIP := PackedVector2Array([Vector2(-3, -3), Vector2(3, -2), Vector2(2, 3), Vector2(-3, 2)])


# --- Pieces (unit space, standing on 0,0, ~40 tall) ---------------------------------

static func _tilt(kind: String) -> float:
	match kind:
		"glow", "gold", "atlantis", "jade", "moon", "pearl", "copper", "fossil", "lava", "meteor", "star", "kraken", \
				"vent", "whale", "dragon", "crown", "void", "time", "heart", "ash", "fire_opal", "slime", "moss", "bubble", \
				"venom", "goo_king", "dust", "comet", "alien_egg", "ufo":
			return 0.35
	return 1.0


static func _mound(ci: CanvasItem, base: Vector2, s: float, st: Dictionary, kind: String) -> void:
	var rock: Color = st["rock"]
	match kind:
		"lava":
			rock = Color("3b2427")
		"meteor":
			rock = Color("3a2c46")
		"obsidian":
			rock = Color("2b2340")
		"storm":
			rock = Color("2a2c44")
		"ash", "garnet":
			rock = Color("4a4250")
		"dust":
			rock = Color("8a8ea2")
	Art.push(ci, base + Vector2(0, 3), 0.0, Vector2(s, s))
	Art.toon(ci, _MOUND, Art.shade_of(rock, 0.1), 2.2, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(-12, -12), Vector2(6, 2.5), 10, -0.2), Color(1, 1, 1, 0.14))
	Art.pop(ci)


static var _MOUND := Art.smooth_pts(PackedVector2Array([Vector2(-36, 1), Vector2(-30, -10), Vector2(-16, -19),
		Vector2(0, -21), Vector2(18, -18), Vector2(31, -9), Vector2(37, 1)]), 3)


static func _scallop(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _SCALLOP, c, 2.0, 0.4)
	for k in range(1, 7):
		var a := lerpf(PI + 0.45, TAU - 0.45, k / 7.0)
		Art.line_c(ci, PackedVector2Array([Vector2(0, -3), Vector2(cos(a) * 17.0, -8.0 + sin(a) * 17.0)]), Art.shade_of(c, 0.22), 1.6)
	Art.toon(ci, PackedVector2Array([Vector2(-8, -1), Vector2(8, -1), Vector2(6, -6), Vector2(-6, -6)]), c2, 1.6, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -20), Vector2(4, 2), 10, -0.6), Color(1, 1, 1, 0.55))


static var _SCALLOP := _scallop_pts()


static func _scallop_pts() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(3, -1), Vector2(-3, -1)])
	for k in 17:
		var a := lerpf(PI + 0.3, TAU - 0.3, k / 16.0)
		var r := 21.0 + (1.8 if k % 2 == 0 else 0.0)
		pts.append(Vector2(cos(a) * r, -8.0 + sin(a) * r))
	return pts


static func _conch(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _CONCH, c, 2.0, 0.5)
	for k in 3:
		var y := -30.0 + k * 9.0
		Art.arc_c(ci, Vector2(0, y + 10.0), 10.0 + k * 1.5, PI + 0.5, TAU - 0.4, 5, Art.shade_of(c, 0.25), 1.6)
	Art.toon(ci, Art.ellipse_pts(Vector2(4, -9), Vector2(5, 7.5), 14, 0.3), c2.lightened(0.3), 1.6, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -24), Vector2(1.8, 4), 8, 0.3), Color(1, 1, 1, 0.55))


static var _CONCH := Art.smooth_pts(PackedVector2Array([Vector2(0, -40), Vector2(7, -30), Vector2(13, -16),
		Vector2(12, -3), Vector2(4, 1), Vector2(-7, 0), Vector2(-12, -10), Vector2(-8, -26)]), 3)


static func _coral(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	# One cached branchy outline, gently rocking from its foot.
	Art.push(ci, Vector2.ZERO, sin(t * 1.5 + i) * 0.045)
	Art.toon(ci, _CORAL, c, 2.0, 0.0)
	for tip: Vector2 in _CORAL_TIPS:
		Art.dot(ci, tip, 3.4, c2)
		Art.dot(ci, tip + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.6))
	Art.pop(ci)


const _CORAL_BRANCHES := [[Vector2(0, 0), Vector2(1, -18), Vector2(-1, -32)], [Vector2(0, -10), Vector2(-10, -20), Vector2(-15, -34)],
		[Vector2(1, -14), Vector2(11, -24), Vector2(12, -38)], [Vector2(-10, -20), Vector2(-5, -38)]]
static var _CORAL := _coral_pts()
static var _CORAL_TIPS := PackedVector2Array([Vector2(-1, -32), Vector2(-15, -34), Vector2(12, -38), Vector2(-5, -38)])


static func _coral_pts() -> PackedVector2Array:
	var polys := []
	for b: Array in _CORAL_BRANCHES:
		polys.append(Geometry2D.offset_polyline(PackedVector2Array(b), 3.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0])
	return Art.union(polys)


static func _clam(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var open := 0.5 + 0.5 * sin(t * 1.3 + i)
	var shell := Color("b7a3d6")
	Art.push(ci, Vector2(0, -8), -0.35 - open * 0.3)
	Art.toon(ci, _CLAM_LID, shell.lightened(0.1), 2.0, 0.4)
	Art.pop(ci)
	Art.push(ci, Vector2(0, -open * 2.0))
	Art.t_circle(ci, Vector2(1, -11), 8, c, 2.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -9), Vector2(3, 4), 10), Color(c2, 0.6))
	Art.flat(ci, Art.circle_pts(Vector2(-2, -14), 2.4, 8), Color(1, 1, 1, 0.9))
	Art.pop(ci)
	Art.toon(ci, _CLAM_BOTTOM, shell, 2.0, 0.4)
	for k in 4:
		Art.line_c(ci, PackedVector2Array([Vector2(-9 + k * 6, -2), Vector2(-7 + k * 4.5, -6)]), Art.shade_of(shell, 0.25), 1.4)


static var _CLAM_BOTTOM := Art.smooth_pts(PackedVector2Array([Vector2(-18, -8), Vector2(0, -6), Vector2(18, -8), Vector2(12, 0), Vector2(0, 1), Vector2(-12, 0)]), 3)
static var _CLAM_LID := _lid_pts()


static func _lid_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 13.0))
	return pts


static func _pearl(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.t_circle(ci, Vector2(0, -10), 10, c, 2.0, 0.5)
	Art.flat(ci, _PEARL_SHEEN, Color(c2, 0.7))
	Art.flat(ci, Art.circle_pts(Vector2(-3.5, -13.5), 2.8, 10), Color(1, 1, 1, 0.95))


static var _PEARL_SHEEN := Art.clipped(Art.circle_pts(Vector2(4, -7), 8, 16), Art.circle_pts(Vector2(0, -10), 10, 20))


static func _nugget(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _NUGGET, c, 2.0, 0.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -17), Vector2(5, 2.6), 12, -0.3), Color(c2, 0.9))
	Art.flat(ci, Art.ellipse_pts(Vector2(7, -9), Vector2(2.4, 1.6), 8), Color(c2, 0.8))
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -5), Vector2(3.2, 2), 10, 0.4), Color("56c9a0"))
	Art.flat(ci, Art.circle_pts(Vector2(-6, -18), 1.6, 8), Color(1, 1, 1, 0.8))
	Art.pop(ci)


static var _NUGGET := Art.smooth_pts(PackedVector2Array([Vector2(-15, 0), Vector2(-17, -9), Vector2(-10, -19), Vector2(0, -24),
		Vector2(9, -21), Vector2(16, -13), Vector2(15, -3), Vector2(7, 1)]), 3)


static func _prism(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _PRISM, c, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(3, 0), Vector2(3.5, -30), Vector2(9, -28), Vector2(8, 0)]), Art.shade_of(c, 0.25))
	Art.flat(ci, PackedVector2Array([Vector2(-4, -36), Vector2(4, -36), Vector2(3.5, -30), Vector2(-3.5, -30)]), c2)
	Art.flat(ci, PackedVector2Array([Vector2(-6, -3), Vector2(-6.5, -28), Vector2(-3.5, -30), Vector2(-3, -3)]), Color(1, 1, 1, 0.35))
	Art.line_c(ci, PackedVector2Array([Vector2(-3.5, -30), Vector2(3.5, -30)]), Color(c2, 0.9), 1.2)


static var _PRISM := PackedVector2Array([Vector2(-8, 0), Vector2(-9, -28), Vector2(-4, -36), Vector2(4, -36), Vector2(9, -28), Vector2(8, 0)])


static func _amber(ci: CanvasItem, c: Color, c2: Color, bug: bool) -> void:
	Art.toon(ci, _DROP, Color(c, 0.95), 2.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(1, -11), Vector2(6, 7), 14), Color(c2, 0.45))
	if bug:
		var b := Color("5a2e10")
		Art.flat(ci, Art.ellipse_pts(Vector2(-1, -9), Vector2(4, 2), 10, 0.2), Color(1, 1, 1, 0.35))
		Art.flat(ci, Art.ellipse_pts(Vector2(1, -12), Vector2(3, 1.8), 10, -0.3), b)
		Art.flat(ci, Art.circle_pts(Vector2(4, -13.5), 1.4, 8), b)
		for k in 3:
			var x := -1.0 + k * 1.6
			Art.line_c(ci, PackedVector2Array([Vector2(x, -12), Vector2(x - 1.5, -8.5)]), b, 0.9)
			Art.line_c(ci, PackedVector2Array([Vector2(x, -12.5), Vector2(x - 1.0, -16)]), b, 0.9)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -20), Vector2(2, 5), 10, 0.35), Color(1, 1, 1, 0.7))


static var _DROP := Art.smooth_pts(PackedVector2Array([Vector2(0, -38), Vector2(7, -24), Vector2(12, -11), Vector2(8, -1),
		Vector2(0, 1), Vector2(-8, -1), Vector2(-12, -11), Vector2(-7, -24)]), 3)


static func _hex_gem(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _HEX, c, 2.0, 0.0)
	Art.flat(ci, _HEX_IN, c.lightened(0.18))
	for k in 6:
		Art.line_c(ci, PackedVector2Array([_HEX[k], _HEX_IN[k]]), Color(c2, 0.7), 1.2)
	Art.flat(ci, PackedVector2Array([_HEX[3], _HEX[4], _HEX_IN[4], _HEX_IN[3]]), Art.shade_of(c, 0.25))
	Art.flat(ci, PackedVector2Array([_HEX[0], _HEX[5], _HEX_IN[5], _HEX_IN[0]]), Color(1, 1, 1, 0.3))
	Art.toon(ci, Art.star_pts(Vector2(-4, -22), 4.5, 1.2, 4), Color(1, 1, 1, 0.95), 0.0, 0.0)


static var _HEX := _ngon(Vector2(0, -16), 16.0, 6, -PI / 2.0)
static var _HEX_IN := _ngon(Vector2(0, -16), 8.0, 6, -PI / 2.0)


static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := rot + TAU * k / n
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 1.05))
	return pts


static func _cut_gem(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _GEM, c, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-9, -20), Vector2(9, -20), Vector2(0, -2)]), Art.shade_of(c, 0.2))
	Art.flat(ci, PackedVector2Array([Vector2(-9, -20), Vector2(-5, -26), Vector2(5, -26), Vector2(9, -20)]), c.lightened(0.25))
	Art.line_c(ci, PackedVector2Array([Vector2(-14, -20), Vector2(14, -20)]), Color(c2, 0.8), 1.2)
	Art.flat(ci, PackedVector2Array([Vector2(-13, -20), Vector2(-9, -20), Vector2(-2, -4)]), Color(1, 1, 1, 0.3))
	Art.toon(ci, Art.star_pts(Vector2(-4, -23), 3.5, 1.0, 4), Color(1, 1, 1, 0.95), 0.0, 0.0)


static var _GEM := PackedVector2Array([Vector2(-14, -20), Vector2(-8, -27), Vector2(8, -27), Vector2(14, -20), Vector2(0, 0)])


static func _bar(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(12, -9), Vector2(8, -14), Vector2(-8, -14), Vector2(-12, -9)]), c, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-12, -9), Vector2(12, -9), Vector2(8, -14), Vector2(-8, -14)]), c2)
	Art.flat(ci, PackedVector2Array([Vector2(12, -9), Vector2(15, 0), Vector2(11, 0), Vector2(9, -9)]), Art.shade_of(c, 0.3))
	Art.t_rect(ci, Rect2(-5, -6.5, 10, 4), 1.5, Art.shade_of(c, 0.2), 0.0, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-9, -12), Vector2(-3, -12)]), Color(1, 1, 1, 0.8), 1.4)


static func _coins(ci: CanvasItem, c: Color, c2: Color) -> void:
	for k in 3:
		Art.t_ellipse(ci, Vector2(0, -3 - k * 4.5), Vector2(10, 3.6), Art.shade_of(c, 0.12), 1.8, 0.0)
	Art.t_ellipse(ci, Vector2(0, -16), Vector2(10, 3.6), c2, 1.8, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -16), Vector2(5, 1.6), 10), Color(c, 0.9))


static func _chest(ci: CanvasItem, at: Vector2, s: float, st: Dictionary, t: float) -> void:
	var c: Color = st["ore"]
	var c2: Color = st["ore2"]
	Art.push(ci, at, 0.0, Vector2(s, s))
	# Open lid behind, the pile of gold, then the box.
	Art.toon(ci, PackedVector2Array([Vector2(-22, -26), Vector2(22, -26), Vector2(20, -44), Vector2(-20, -44)]), Color("8e552c"), 2.2, 0.0)
	Art.t_rect(ci, Rect2(-20, -40, 40, 4), 1, c, 0.0, 0.0)
	Art.toon(ci, _GOLD_PILE, c, 2.0, 0.0)
	for p: Vector2 in [Vector2(-10, -28), Vector2(4, -31), Vector2(12, -26)]:
		Art.flat(ci, Art.ellipse_pts(p, Vector2(4.5, 2), 10), c2)
	Art.t_rect(ci, Rect2(-23, -25, 46, 25), 3, Art.WOOD, 2.2, 0.4)
	for x: float in [-15.0, 15.0]:
		Art.flat(ci, PackedVector2Array([Vector2(x - 3, -25), Vector2(x + 3, -25), Vector2(x + 3, 0), Vector2(x - 3, 0)]), c)
	Art.t_rect(ci, Rect2(-4, -20, 8, 9), 2, c, 1.6, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(0, -15.5), 1.4, 8), Art.INK)
	var tw := 0.5 + 0.5 * sin(t * 4.0)
	Art.push(ci, Vector2(8, -36), t * 0.8, Vector2.ONE * (0.6 + tw * 0.5))
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 5, 1.4, 4), Color(1, 1, 1, 0.95), 0.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)


static var _GOLD_PILE := Art.smooth_pts(PackedVector2Array([Vector2(-21, -24), Vector2(-14, -31), Vector2(-4, -35),
		Vector2(8, -34), Vector2(17, -30), Vector2(21, -24)]), 3)


static func _ice(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0 - (i % 3) * 0.12))
	Art.toon(ci, _ICE, Color(c, 0.9), 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(1, 0), Vector2(2, -33), Vector2(8, -28), Vector2(9, 0)]), Color(Art.shade_of(c, 0.15), 0.8))
	Art.toon(ci, _ICE_CAP, c2, 1.4, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-5, -6), Vector2(-4, -24)]), Color(1, 1, 1, 0.8), 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-1.5, -4), Vector2(-1, -12)]), Color(1, 1, 1, 0.6), 1.4)
	Art.pop(ci)


static var _ICE := PackedVector2Array([Vector2(-9, 0), Vector2(-10, -27), Vector2(-3, -40), Vector2(8, -28), Vector2(9, 0)])
static var _ICE_CAP := Art.smooth_pts(PackedVector2Array([Vector2(-10.5, -27), Vector2(-3, -41), Vector2(8.5, -28),
		Vector2(6, -25), Vector2(2, -28), Vector2(-3, -24), Vector2(-7, -26)]), 2)


static func _lava_rock(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var pulse := snappedf(0.65 + 0.35 * sin(t * 3.0 + i * 1.7), 0.05)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _NUGGET, Color("3b2427"), 2.0, 0.5)
	var cracks := [[Vector2(-12, -6), Vector2(-5, -12), Vector2(-7, -19)], [Vector2(-5, -12), Vector2(4, -14), Vector2(10, -20)],
			[Vector2(4, -14), Vector2(7, -5)]]
	for cr in cracks:
		Art.polyline(ci, PackedVector2Array(cr), Color(c, pulse), 3.4)
	for cr in cracks:
		Art.polyline(ci, PackedVector2Array(cr), Color(c2, pulse), 1.4)
	Art.dot(ci, Vector2(-5, -12), 2.4, Color(c2, pulse))
	Art.pop(ci)


static func _tablet(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.t_rect(ci, Rect2(-11, -36, 22, 36), 6, c, 2.0, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-8, -33, 16, 30), 4, 3), c.lightened(0.12))
	var d := Art.shade_of(c, 0.35)
	if i % 2 == 0:
		Art.arc_c(ci, Vector2(0, -19), 5.0, 0, TAU, 10, d, 2.0)
		Art.disc(ci, Vector2(0, -19), 1.6, d)
		Art.line_c(ci, PackedVector2Array([Vector2(-4, -9), Vector2(4, -9)]), d, 1.6)
	else:
		Art.arc_c(ci, Vector2(0, -20), 5.5, PI * 0.2, PI * 1.8, 10, d, 2.0)
		Art.line_c(ci, PackedVector2Array([Vector2(0, -26), Vector2(0, -8)]), d, 1.6)
		Art.line_c(ci, PackedVector2Array([Vector2(-4, -12), Vector2(4, -12)]), d, 1.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -31), Vector2(2.5, 1.5), 8), Color(1, 1, 1, 0.6))


static func _moonstone(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var sheen := Color("b9c4ff")
	Art.toon(ci, _MOONSTONE, c, 2.0, 0.5)
	Art.flat(ci, _MOON_SHEEN, Color(sheen, snappedf(0.55 + 0.25 * sin(t * 2.0 + i), 0.05)))
	Art.flat(ci, _CRESCENT, Color("8f9cf0"))
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -21), Vector2(3.2, 1.8), 10, -0.4), Color(c2, 0.95))


static var _MOONSTONE := Art.smooth_pts(PackedVector2Array([Vector2(-13, -2), Vector2(-15, -13), Vector2(-9, -23), Vector2(2, -26),
		Vector2(12, -20), Vector2(15, -9), Vector2(10, 0), Vector2(0, 1)]), 3)
static var _MOON_SHEEN := Art.clipped(Art.circle_pts(Vector2(8, -6), 12, 18), _MOONSTONE)
static var _CRESCENT := _crescent_pts()


static func _crescent_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 9:
		var a := lerpf(-PI * 0.7, PI * 0.7, k / 8.0)
		pts.append(Vector2(1, -12) + Vector2(cos(a + PI), sin(a + PI)) * 6.0)
	for k in 9:
		var a := lerpf(PI * 0.55, -PI * 0.55, k / 8.0)
		pts.append(Vector2(3.2, -12) + Vector2(cos(a + PI), sin(a + PI)) * 4.6)
	return pts


static func _ammonite(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.t_circle(ci, Vector2(0, -14), 14, c, 2.0, 0.5)
	Art.line_c(ci, _SPIRAL, Art.shade_of(c, 0.4), 1.8)
	for k in 5:
		var a := k * 1.1
		var r := 11.5 * exp(-a * 0.12)
		Art.line_c(ci, PackedVector2Array([Vector2(0, -14) + Vector2(cos(-a), sin(-a)) * r, Vector2(0, -14) + Vector2(cos(-a), sin(-a)) * (r + 2.6)]), Art.shade_of(c, 0.3), 1.3)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -21), Vector2(3, 1.8), 10, -0.6), Color(c2, 0.9))


static var _SPIRAL := _spiral_pts()


static func _spiral_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 20:
		var a := k * 0.6
		var r := 11.5 * exp(-a * 0.12)
		pts.append(Vector2(0, -14) + Vector2(cos(-a), sin(-a)) * r)
	return pts


static func _bone(ci: CanvasItem, c: Color) -> void:
	Art.toon(ci, _BONE, c, 2.0, 0.4)
	Art.line_c(ci, PackedVector2Array([Vector2(-7, -7.5), Vector2(7, -7.5)]), Color(1, 1, 1, 0.7), 1.4)


static var _BONE := Art.union([Art.rrect_pts(Rect2(-12, -9, 24, 6), 3, 2), Art.circle_pts(Vector2(-13, -9), 3.8, 10),
		Art.circle_pts(Vector2(-13, -3), 3.8, 10), Art.circle_pts(Vector2(13, -9), 3.8, 10), Art.circle_pts(Vector2(13, -3), 3.8, 10)])


static func _shard(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	var body := Color("2b2340")
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _SHARD, body, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-2, -40), Vector2(4, -24), Vector2(1, 0), Vector2(-4, 0)]), Color(c, 0.55))
	Art.flat(ci, PackedVector2Array([Vector2(4, -24), Vector2(9, -30), Vector2(8, 0), Vector2(1, 0)]), Color(c, 0.25))
	Art.line_c(ci, PackedVector2Array([Vector2(-2, -38), Vector2(-7.5, -18)]), Color(c2, 0.9), 1.4)
	Art.line_c(ci, PackedVector2Array([Vector2(8.5, -28), Vector2(7.5, -8)]), Color(c2, 0.6), 1.2)
	Art.pop(ci)


static var _SHARD := PackedVector2Array([Vector2(-7, 0), Vector2(-10, -17), Vector2(-2, -41), Vector2(4, -25), Vector2(10, -31), Vector2(8, 0)])


static func _mushroom(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var pulse := snappedf(0.5 + 0.5 * sin(t * 2.4 + i * 1.3), 0.05)
	Art.glow(ci, Vector2(0, -24), 20.0, Color(c, 0.2 + 0.2 * pulse), 12)
	Art.push(ci, Vector2.ZERO, sin(t * 1.4 + i) * 0.06, Vector2(1.0, 1.0 + 0.04 * pulse))
	Art.t_rect(ci, Rect2(-4, -22, 8, 22), 4, Color("e8fff8"), 2.0, 0.4)
	Art.toon(ci, _CAP, c, 2.0, 0.5)
	Art.flat(ci, PackedVector2Array([Vector2(-13, -21), Vector2(13, -21), Vector2(9, -18), Vector2(-9, -18)]), Art.shade_of(c, 0.3))
	for p: Vector3 in [Vector3(-6, -28, 2.6), Vector3(4, -31, 2.0), Vector3(8, -24, 1.6), Vector3(-1, -24, 1.4)]:
		Art.dot(ci, Vector2(p.x, p.y), p.z, Color(c2, 0.7 + 0.3 * pulse))
	Art.pop(ci)


static var _CAP := Art.smooth_pts(PackedVector2Array([Vector2(-15, -20), Vector2(-12, -29), Vector2(-3, -35), Vector2(6, -34),
		Vector2(13, -28), Vector2(15, -20), Vector2(0, -18)]), 3)


## Broken marble column, standing on 0,0, ~40 tall.
static func column(ci: CanvasItem) -> void:
	var marble := Color("e3ecfb")
	Art.t_rect(ci, Rect2(-12, -4, 24, 5), 1.5, marble, 2.0, 0.3)
	Art.toon(ci, PackedVector2Array([Vector2(-9, -4), Vector2(9, -4), Vector2(9, -34), Vector2(5, -38), Vector2(1, -33), Vector2(-3, -40), Vector2(-9, -36)]), marble, 2.0, 0.4)
	for x: float in [-5.0, 0.0, 5.0]:
		Art.line_c(ci, PackedVector2Array([Vector2(x, -6), Vector2(x, -31)]), Color("a9b8d8"), 1.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -20), Vector2(1.5, 10), 8), Color(1, 1, 1, 0.5))
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -12), Vector2(3, 2), 8), Color("7fcfa0"))


static func _relic(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	if i % 2 == 0:
		# A little golden crown.
		Art.toon(ci, PackedVector2Array([Vector2(-13, 0), Vector2(-15, -18), Vector2(-7, -10), Vector2(0, -22), Vector2(7, -10), Vector2(15, -18), Vector2(13, 0)]), c, 2.0, 0.5)
		Art.t_circle(ci, Vector2(0, -6), 3, Color("3fd0ff"), 1.4, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(-8, -5), 1.6, 8), Color(c2, 0.9))
		Art.flat(ci, Art.circle_pts(Vector2(8, -5), 1.6, 8), Color(c2, 0.9))
	else:
		# A golden medallion with a trident on it.
		Art.t_circle(ci, Vector2(0, -13), 13, c, 2.0, 0.5)
		Art.arc_c(ci, Vector2(0, -13), 9.5, 0, TAU, 18, Art.shade_of(c, 0.25), 1.4)
		var d := Art.shade_of(c, 0.4)
		Art.line_c(ci, PackedVector2Array([Vector2(0, -5), Vector2(0, -20)]), d, 1.8)
		Art.arc_c(ci, Vector2(0, -17), 5.0, 0.0, PI, 8, d, 1.8)
		Art.line_c(ci, PackedVector2Array([Vector2(-5, -17), Vector2(-5, -21)]), d, 1.6)
		Art.line_c(ci, PackedVector2Array([Vector2(5, -17), Vector2(5, -21)]), d, 1.6)
		Art.flat(ci, Art.ellipse_pts(Vector2(-5, -19), Vector2(2.4, 1.4), 8, -0.6), Color(c2, 0.95))


static func _meteorite(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var hot := 0.6 + 0.4 * sin(t * 3.0 + i * 1.3)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.crystal(ci, Vector2(5, -16), 24, 5, 0.45, c, 1.8)
	Art.toon(ci, _NUGGET, Color("6a5478"), 2.0, 0.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -9), Vector2(4.5, 3.2), 12), Color("4a3858"))
	Art.arc_c(ci, Vector2(-7, -9), 4.5, 0.3, PI - 0.3, 5, Color(1, 1, 1, 0.3), 1.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(8, -6), Vector2(2.6, 1.9), 10), Color("4a3858"))
	Art.polyline(ci, PackedVector2Array([Vector2(-14, -14), Vector2(-5, -18), Vector2(2, -15)]), Color(c, hot), 2.2)
	Art.polyline(ci, PackedVector2Array([Vector2(-14, -14), Vector2(-5, -18), Vector2(2, -15)]), Color(1, 1, 1, hot * 0.8), 0.9)
	Art.crystal(ci, Vector2(-9, -17), 16, 4, -0.55, c2, 1.6)
	Art.pop(ci)


## Kraken tentacle rising from 0,0 and curling over toward +x (~50 tall).
## Built as one outline and one fill polygon each frame (it sways), so it
## stays cheap: two polygons and a few sucker dots.
static func tentacle(ci: CanvasItem, t: float, c: Color = Color("c2457a")) -> void:
	var n := 12
	var spine := PackedVector2Array([Vector2.ZERO])
	var p := Vector2.ZERO
	for k in n:
		# Walk up, turning more and more toward the tip so it curls over.
		var f := float(k) / n
		var th := f * f * 3.1 + sin(t + f * 2.5) * 0.18 * f
		p += Vector2(sin(th), -cos(th)) * lerpf(6.0, 3.2, f)
		spine.append(p)
	Art.flat_now(ci, _tentacle_poly(spine, 2.0), Art.INK)
	Art.flat_now(ci, _tentacle_poly(spine, 0.0), c)
	for k in range(1, n - 1, 2):
		var d := (spine[k + 1] - spine[k]).normalized().orthogonal()
		Art.dot(ci, spine[k] - d * lerpf(3.5, 1.2, float(k) / n), lerpf(2.4, 1.2, float(k) / n), Color("ffc3dc"))


## Outline of a tapered tube along `spine` (11 px wide at the root, 3.5 at
## the tip), grown by `grow` px, with a rounded tip.
static func _tentacle_poly(spine: PackedVector2Array, grow: float) -> PackedVector2Array:
	var n := spine.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n:
		var d := (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var hw := lerpf(11.0, 3.5, float(k) / (n - 1)) / 2.0 + grow
		left.append(spine[k] + d.orthogonal() * hw)
		right.append(spine[k] - d.orthogonal() * hw)
	var tip_d := (spine[n - 1] - spine[n - 2]).normalized()
	var tip_r := 3.5 / 2.0 + grow
	var out := PackedVector2Array()
	out.append_array(left)
	for k in range(1, 4):
		out.append(spine[n - 1] + tip_d.orthogonal().rotated(PI * k / 4.0) * tip_r)
	right.reverse()
	out.append_array(right)
	return out


static func _star(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var tw := sin(t * 3.0 + i * 1.9)
	Art.glow(ci, Vector2(0, -18), 22.0 + tw * 2.0, Color(c, 0.35), 12)
	Art.push(ci, Vector2(0, -18), tw * 0.08, Vector2.ONE * (1.0 + tw * 0.05))
	Art.toon(ci, _STAR, c, 2.0, 0.5)
	Art.flat(ci, _STAR_IN, Color(c2, 0.7))
	if i % 2 == 0:
		Art.flat(ci, Art.ellipse_pts(Vector2(-3.5, 0), Vector2(1.4, 2.0), 8), Art.INK)
		Art.flat(ci, Art.ellipse_pts(Vector2(3.5, 0), Vector2(1.4, 2.0), 8), Art.INK)
		Art.arc_c(ci, Vector2(0, 2.5), 2.2, 0.4, PI - 0.4, 6, Art.INK, 1.2)
	Art.pop(ci)


static var _STAR := Art.smooth_pts(Art.star_pts(Vector2.ZERO, 19, 9, 5), 2)
static var _STAR_IN := Art.smooth_pts(Art.star_pts(Vector2(-1, -2), 9, 4.5, 5), 2)


# --- The abyss (depths 21-29) ----------------------------------------------------------
#
# Each kind has its own pieces and a big centerpiece. Animated values are
# snapped or applied through Art.push, so the shape cache stays small.

const JEWELS: Array[Color] = [Color("ff3d6e"), Color("3fb0ff"), Color("4fe08a")]
const BRASS := Color("d8963a")
const VOID_BODY := Color("150a24")


static func abyss_piece(ci: CanvasItem, kind: String, c: Color, c2: Color, t: float, i: int) -> void:
	match kind:
		"vent":
			if i % 2 == 0:
				_sulfur(ci, c, c2, i)
			else:
				_chimney(ci, c, c2, t, i)
		"whale":
			if i % 2 == 0:
				_vertebra(ci, c, c2)
			else:
				_ambergris(ci, c, c2, t, i)
		"mirror":
			_mirror_shard(ci, c, c2, t, i)
		"storm":
			_storm_crystal(ci, c, c2, t, i)
		"dragon":
			match i % 3:
				0:
					_scale(ci, c, c2, i)
				1:
					_ember(ci, c, c2, t, i)
				_:
					_coins(ci, Color("ffd23f"), Color("fff1a8"))
		"crown":
			match i % 3:
				0:
					_crown(ci, c, c2, i)
				1:
					_chalice(ci, c, c2, i)
				_:
					var j: Color = JEWELS[(i / 3) % JEWELS.size()]
					_cut_gem(ci, j, j.lightened(0.5))
		"void":
			_orb(ci, c, c2, t, i)
		"time":
			if i % 4 == 0:
				_hourglass(ci, c, c2, t, i)
			else:
				_watch(ci, c, c2, t, i)
		"heart":
			if i % 3 == 2:
				_sea_pearl(ci, c, c2)
			else:
				_heart_gem(ci, c, c2, t, i)


## The big piece of an abyss deposit, standing on `base`; `s` = size / 40.
static func centerpiece(ci: CanvasItem, kind: String, base: Vector2, s: float, st: Dictionary, t: float, seed: int) -> void:
	var c: Color = st["ore"]
	var c2: Color = st["ore2"]
	match kind:
		"vent":
			# A black smoker with tube worms at its foot.
			Art.push(ci, base + Vector2(-8 * s, 2), 0.0, Vector2(s, s) * 1.45)
			_chimney(ci, c, c2, t, seed)
			Art.pop(ci)
			for k in 3:
				Art.push(ci, base + Vector2((13 + k * 5) * s, 3), sin(t * 1.6 + k * 1.3) * 0.1, Vector2(s, s) * (0.9 - k * 0.15))
				tube_worm(ci, 22.0 - k * 3.0)
				Art.pop(ci)
		"whale":
			Art.push(ci, base + Vector2(-10 * s, 3), 0.0, Vector2(s, s) * 0.95)
			whale_skull(ci, c, c2, t)
			Art.pop(ci)
		"mirror":
			Art.push(ci, base + Vector2(-4 * s, 2), -0.05, Vector2(s, s) * 0.82)
			_standing_mirror(ci, c, c2, t)
			Art.pop(ci)
		"dragon":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.1)
			Art.toon(ci, _HOARD, Color("ffc93c"), 2.0, 0.4)
			for p: Vector2 in [Vector2(-16, -8), Vector2(12, -9), Vector2(-4, -14), Vector2(22, -4)]:
				Art.flat(ci, Art.ellipse_pts(p, Vector2(4, 1.8), 10), Color("fff1a8"))
			var wob := snappedf(sin(t * 9.0) * 0.1 * maxf(0.0, sin(t * 0.9 + seed)), 0.02)
			Art.push(ci, Vector2(2, -12), wob)
			dragon_egg(ci, c, c2, t)
			Art.pop(ci)
			Art.pop(ci)
		"crown":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.12)
			Art.t_rect(ci, Rect2(-24, -12, 48, 12), 5, Color("c0304a"), 2.2, 0.5)
			for x: float in [-23.0, 23.0]:
				Art.flat(ci, Art.circle_pts(Vector2(x, -2), 2.8, 8), Color("ffc93c"))
			Art.push(ci, Vector2(0, -9), 0.0, Vector2(1.35, 1.35))
			_crown(ci, c, c2, 0)
			Art.pop(ci)
			var tw := 0.5 + 0.5 * sin(t * 3.3 + seed)
			Art.push(ci, Vector2(13, -38), t * 0.7, Vector2.ONE * (0.5 + tw * 0.6))
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 5, 1.4, 4), Color(1, 1, 1, 0.95), 0.0, 0.0)
			Art.pop(ci)
			Art.pop(ci)
		"void":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 0.95)
			Art.toon(ci, _PEDESTAL, Color("2b2340"), 2.0, 0.4)
			Art.flat(ci, _PEDESTAL_TOP, Color(c, 0.55))
			Art.push(ci, Vector2(0, -34 + snappedf(sin(t * 1.3 + seed) * 3.0, 0.5)), 0.0)
			void_orb(ci, c, c2, t, 1.6, true)
			Art.pop(ci)
			Art.pop(ci)
		"time":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s))
			Art.push(ci, Vector2(-17, -40), t * 0.6, Vector2.ONE * 0.65)
			Art.toon(ci, _GEAR, Color("b07a34"), 3.0, 0.0)
			Art.pop(ci)
			Art.push(ci, Vector2.ZERO, 0.0, Vector2(1.25, 1.25))
			_hourglass(ci, c, c2, t, seed)
			Art.pop(ci)
			Art.pop(ci)
		"phoenix":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.1)
			Art.toon(ci, _NEST_SMALL, Color("a8743a"), 2.0, 0.5)
			Art.push(ci, Vector2(0, -6), 0.0, Vector2(0.9, 0.9))
			dragon_egg(ci, c, c2, t)
			Art.pop(ci)
			Art.pop(ci)
		"goo_king":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.3)
			_slime(ci, c, c2, 0)
			Art.push(ci, Vector2(0, -26), 0.0, Vector2(0.6, 0.6))
			_crown(ci, Color("ffc93c"), Color("fff6c0"), 0)
			Art.pop(ci)
			Art.pop(ci)
		"alien_egg":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.05)
			Art.toon(ci, _NEST_SMALL, Color("4a6a5a"), 2.0, 0.5)
			for k in 2:
				Art.push(ci, Vector2(-9 + k * 18, -6), 0.0, Vector2(0.75, 0.75))
				_alien_egg(ci, c, c2, t, k)
				Art.pop(ci)
			Art.pop(ci)
		"ufo":
			Art.push(ci, base + Vector2(0, 2), -0.18, Vector2(s, s) * 1.25)
			_ufo(ci, c, c2, t, seed)
			Art.pop(ci)
		"heart":
			Art.push(ci, base + Vector2(0, 2), 0.0, Vector2(s, s) * 1.1)
			Art.toon(ci, _SCALLOP, Color("ffc93c"), 2.0, 0.4)
			for k in range(1, 7):
				var a := lerpf(PI + 0.45, TAU - 0.45, k / 7.0)
				Art.line_c(ci, PackedVector2Array([Vector2(0, -3), Vector2(cos(a) * 17.0, -8.0 + sin(a) * 17.0)]), Color("e0921c"), 1.6)
			var bob := snappedf(sin(t * 1.8 + seed) * 2.0, 0.5)
			heart_rays(ci, Vector2(0, -30 + bob), 34.0, c, t)
			Art.push(ci, Vector2(0, -14 + bob), 0.0, Vector2(1.05, 1.05))
			_heart_gem(ci, c, c2, t, 0)
			Art.pop(ci)
			Art.pop(ci)


# vent -----------------------------------------------------------------

static func _sulfur(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 4 == 2 else 1.0, 1.0))
	Art.push(ci, Vector2(-8, 1), -0.45, Vector2(0.55, 0.55))
	Art.toon(ci, _SULFUR, Art.shade_of(c, 0.12), 2.6, 0.0)
	Art.pop(ci)
	Art.toon(ci, _SULFUR, c, 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(1, -37), Vector2(10, -19), Vector2(7, 0), Vector2(1, 0)]), Art.shade_of(c, 0.22))
	Art.flat(ci, PackedVector2Array([Vector2(-1, -36), Vector2(-8, -19), Vector2(-4, -19)]), c2)
	Art.line_c(ci, PackedVector2Array([Vector2(-6, -4), Vector2(-7, -17)]), Color(1, 1, 1, 0.55), 1.4)
	Art.pop(ci)


static var _SULFUR := PackedVector2Array([Vector2(-7, 0), Vector2(-10, -18), Vector2(0, -38), Vector2(10, -19), Vector2(7, 0)])


static func _chimney(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var hot := snappedf(0.7 + 0.3 * sin(t * 3.0 + i * 1.3), 0.1)
	var rock := Color("3b3434")
	Art.toon(ci, _CHIMNEY, rock, 2.0, 0.5)
	for y: float in [-12.0, -24.0]:
		Art.line_c(ci, PackedVector2Array([Vector2(-8.2 + (y + 24.0) * -0.05, y), Vector2(0, y + 1.5), Vector2(8.4 + (y + 24.0) * 0.06, y)]), Color("241e22"), 1.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -6), Vector2(4.5, 2.4), 10, 0.3), c)
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -18), Vector2(2.6, 1.8), 8), c2)
	Art.flat(ci, Art.ellipse_pts(Vector2(-3, -29), Vector2(2.2, 1.5), 8), c)
	Art.flat(ci, _CHIMNEY_MOUTH, Color(1.0, 0.55, 0.2, hot))
	# Dark smoke pouring out of the top.
	for k in 3:
		var f := fposmod(t * 0.45 + k / 3.0 + i * 0.21, 1.0)
		Art.dot(ci, Vector2(sin(f * 5.0 + k + i) * 2.5 + f * 5.0, -36.0 - f * 28.0), 3.0 + f * 5.5, Color(0.42, 0.37, 0.4, 0.8 * (1.0 - f)))


static var _CHIMNEY := Art.smooth_pts(PackedVector2Array([Vector2(-11, 0), Vector2(-8, -12), Vector2(-7, -24), Vector2(-5, -34),
		Vector2(5, -34), Vector2(7, -24), Vector2(8, -12), Vector2(12, 0)]), 2)
static var _CHIMNEY_MOUTH := Art.ellipse_pts(Vector2(0, -34), Vector2(4.5, 1.8), 10)


## A tube worm `h` px tall standing on 0,0: white tube, red plume.
static func tube_worm(ci: CanvasItem, h: float) -> void:
	Art.t_rect(ci, Rect2(-2.2, -h, 4.4, h), 2.2, Color("f4efe6"), 1.6, 0.0)
	Art.push(ci, Vector2(0, -h), 0.0, Vector2(0.75, 0.75))
	Art.toon(ci, _PLUME, Color("ef3a4a"), 1.8, 0.0)
	Art.pop(ci)


static var _PLUME := Art.smooth_pts(PackedVector2Array([Vector2(-2, 1), Vector2(-5, -3), Vector2(-4, -7), Vector2(0, -9),
		Vector2(4, -7), Vector2(5, -3), Vector2(2, 1)]), 2)


# whale ----------------------------------------------------------------

static func _vertebra(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.toon(ci, _VERTEBRA, c, 2.0, 0.4)
	Art.flat(ci, _CENTRUM, Art.shade_of(c, 0.15))
	Art.flat(ci, _CANAL, Art.shade_of(c, 0.55))
	Art.flat(ci, Art.ellipse_pts(Vector2(-10, -16), Vector2(3, 1.2), 8), Color(1, 1, 1, 0.6))
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -6), Vector2(2, 1.4), 8), Color(c2, 0.5))


static var _CENTRUM := Art.circle_pts(Vector2(1, -8), 5.5, 10)
static var _CANAL := Art.circle_pts(Vector2(0, -20.5), 2.6, 8)
static var _VERTEBRA := Art.union([Art.circle_pts(Vector2(0, -9), 9.0, 18), Art.rrect_pts(Rect2(-17, -19, 34, 6), 3, 2),
		PackedVector2Array([Vector2(-4, -18), Vector2(4, -18), Vector2(1.8, -38), Vector2(-1.8, -38)])])


static func _ambergris(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var wax := c.lerp(Color("a89468"), 0.55)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 4 == 1 else 1.0, 0.85))
	Art.toon(ci, _NUGGET, wax, 2.0, 0.5)
	Art.arc_c(ci, Vector2(-3, -12), 6.0, 0.4, 3.6, 5, Color(c, 0.8), 1.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -18), Vector2(3.5, 1.8), 10, -0.3), Color(1, 1, 1, 0.5))
	Art.dot(ci, Vector2(7, -15), 1.6, Color(c2, 0.5 + 0.4 * sin(t * 2.0 + i)))
	Art.pop(ci)


## A whale skull lying on its jaw (~80 wide, ~28 tall), snout to +x.
static func whale_skull(ci: CanvasItem, c: Color, c2: Color, t: float) -> void:
	Art.toon(ci, _SKULL, c, 2.2, 0.5)
	Art.line_c(ci, PackedVector2Array([Vector2(-26, -5), Vector2(0, -6), Vector2(36, -3)]), Art.shade_of(c, 0.3), 1.6)
	for k in 6:
		Art.line_c(ci, PackedVector2Array([Vector2(6 + k * 5, -5), Vector2(6 + k * 5, -1.5)]), Art.shade_of(c, 0.25), 1.2)
	Art.flat(ci, _SKULL_EYE, Color("2a2438"))
	Art.dot(ci, Vector2(-17, -14), 2.2 + 0.6 * sin(t * 2.0), Color(c2, 0.9))
	Art.flat(ci, Art.ellipse_pts(Vector2(-20, -22), Vector2(6, 1.6), 10, -0.2), Color(1, 1, 1, 0.55))


static var _SKULL := Art.smooth_pts(PackedVector2Array([Vector2(-34, 0), Vector2(-36, -12), Vector2(-28, -24), Vector2(-14, -28),
		Vector2(2, -22), Vector2(20, -13), Vector2(38, -6), Vector2(40, 0)]), 3)
static var _SKULL_EYE := Art.ellipse_pts(Vector2(-17, -14), Vector2(5.5, 4.2), 12, 0.2)


# mirror ---------------------------------------------------------------

static func _mirror_shard(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var k := i % _MSHARDS.size()
	var shape: PackedVector2Array = _MSHARDS[k]
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, shape, c, 2.0, 0.0)
	Art.flat(ci, _MSHARD_LOW[k], Color("7d8cc0"))
	# A glint sweeps up the glass now and then.
	var sweep := fposmod(t * 0.35 + i * 0.27, 1.0)
	for g in 2:
		var a := snappedf(clampf(1.0 - absf(sweep * 3.0 - 1.0 - g * 0.6) * 2.5, 0.0, 1.0), 0.25)
		if a > 0.0:
			Art.flat(ci, _MSHARD_GLINT[k * 2 + g], Color(1, 1, 1, 0.3 + 0.6 * a))
	Art.line_c(ci, PackedVector2Array([shape[1] + Vector2(1.5, 0), shape[2] + Vector2(0.5, 2.5)]), Color(c2, 0.9), 1.4)
	Art.pop(ci)


static var _MSHARDS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-8, 0), Vector2(-11, -22), Vector2(-3, -40), Vector2(6, -30), Vector2(10, 0)]),
	PackedVector2Array([Vector2(-10, 0), Vector2(-7, -28), Vector2(2, -36), Vector2(9, -18), Vector2(7, 0)]),
	PackedVector2Array([Vector2(-6, 0), Vector2(-9, -16), Vector2(-1, -44), Vector2(8, -24), Vector2(6, 0)]),
]
static var _MSHARD_LOW: Array[PackedVector2Array] = _shard_parts(0)
static var _MSHARD_GLINT: Array[PackedVector2Array] = _shard_parts(1)


static func _shard_parts(which: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for sh: PackedVector2Array in _MSHARDS:
		if which == 0:
			out.append(Art.clipped(PackedVector2Array([Vector2(-20, 0), Vector2(-20, -12), Vector2(20, -20), Vector2(20, 0)]), sh))
		else:
			for g in 2:
				var y := -14.0 - g * 12.0
				out.append(Art.clipped(PackedVector2Array([Vector2(-20, y + 10), Vector2(-20, y + 5), Vector2(20, y - 12), Vector2(20, y - 7)]), sh))
	return out


static func _standing_mirror(ci: CanvasItem, c: Color, c2: Color, t: float) -> void:
	var frame := Color("b8c4dc")
	for x: float in [-10.0, 10.0]:
		Art.t_rect(ci, Rect2(x - 3, -6, 6, 6), 2, Art.shade_of(frame, 0.2), 1.8, 0.0)
	Art.t_ellipse(ci, Vector2(0, -32), Vector2(19, 27), frame, 2.4, 0.4)
	Art.toon(ci, _MIRROR_GLASS, Color("dfeaff"), 1.6, 0.0)
	Art.flat(ci, _MIRROR_LOW, Color("8fa4d8"))
	var sweep := fposmod(t * 0.3, 1.0)
	for g in 2:
		var a := snappedf(clampf(1.0 - absf(sweep * 3.0 - 1.0 - g * 0.5) * 2.0, 0.0, 1.0), 0.25)
		Art.flat(ci, _MIRROR_GLINT[g], Color(1, 1, 1, 0.35 + 0.55 * a))
	Art.t_circle(ci, Vector2(0, -60), 4, c2, 1.8, 0.0)
	Art.t_circle(ci, Vector2(0, -60), 2, Color("ff8fc0"), 0.0, 0.0)
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.circle_pts(Vector2(17.5 * sx, -32), 2.2, 8), c)


static var _MIRROR_GLASS := Art.ellipse_pts(Vector2(0, -32), Vector2(14.5, 22), 24)
static var _MIRROR_LOW := Art.clipped(PackedVector2Array([Vector2(-20, -10), Vector2(-20, -24), Vector2(20, -30), Vector2(20, -10)]), _MIRROR_GLASS)
static var _MIRROR_GLINT: Array[PackedVector2Array] = [
	Art.clipped(PackedVector2Array([Vector2(-20, -32), Vector2(-20, -40), Vector2(20, -58), Vector2(20, -50)]), _MIRROR_GLASS),
	Art.clipped(PackedVector2Array([Vector2(-20, -22), Vector2(-20, -25), Vector2(20, -43), Vector2(20, -40)]), _MIRROR_GLASS),
]


# storm ----------------------------------------------------------------

static func _storm_crystal(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var flick := snappedf(0.55 + 0.45 * absf(sin(t * 7.0 + i * 2.3) * sin(t * 2.9 + i)), 0.25)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.crystal(ci, Vector2.ZERO, 42, 8, 0.0, c, 2.0)
	Art.line_c(ci, _BOLT_IN, Color(c2, flick), 2.0)
	Art.dot(ci, Vector2(0, -41), 2.2 + flick * 2.0, Color(c2, 0.6 + 0.4 * flick))
	Art.pop(ci)
	# A crackle of electricity every now and then.
	var f := fposmod(t * 0.9 + i * 0.37, 1.0)
	if f < 0.1:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t * 0.9 + i * 0.37) * 7 + i
		var pts := PackedVector2Array([Vector2(0, -41)])
		var end := Vector2(rng.randf_range(-22, 22), rng.randf_range(-30, -16))
		for k in range(1, 4):
			pts.append(pts[0].lerp(end, k / 4.0) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)))
		pts.append(end)
		Art.polyline(ci, pts, Color(c, 0.8), 3.0)
		Art.polyline(ci, pts, Color(1, 1, 1, 0.95), 1.2)


static var _BOLT_IN := PackedVector2Array([Vector2(-1, -5), Vector2(3, -15), Vector2(-2, -22), Vector2(2, -33)])


## A zigzag lightning bolt from `a` to `b` (new shape each strike: `seed`).
static func bolt(ci: CanvasItem, a: Vector2, b: Vector2, seed: int, c: Color, alpha: float, width: float = 4.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array([a])
	var n := 6
	var side := (b - a).orthogonal().normalized()
	for k in range(1, n):
		pts.append(a.lerp(b, float(k) / n) + side * rng.randf_range(-9, 9))
	pts.append(b)
	Art.polyline(ci, pts, Color(c, 0.7 * alpha), width + 3.0)
	Art.polyline(ci, pts, Color(1, 1, 1, alpha), width * 0.45)


# dragon ---------------------------------------------------------------

static func _scale(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.push(ci, Vector2(-8, 1), -0.3, Vector2(0.62, 0.62))
	Art.toon(ci, _SCALE, Art.shade_of(c, 0.25), 2.8, 0.0)
	Art.pop(ci)
	Art.toon(ci, _SCALE, c, 2.0, 0.5)
	Art.line_c(ci, PackedVector2Array([Vector2(0, -5), Vector2(0, -31)]), Art.shade_of(c, 0.35), 1.8)
	Art.line_c(ci, _SCALE_RIM, c2, 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -24), Vector2(1.8, 5), 8, 0.3), Color(1, 1, 1, 0.45))
	Art.pop(ci)


static var _SCALE := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-10, -10), Vector2(-12, -24), Vector2(-7, -34),
		Vector2(0, -37), Vector2(7, -34), Vector2(12, -24), Vector2(10, -10)]), 2)
static var _SCALE_RIM := PackedVector2Array([Vector2(-9, -25), Vector2(-5, -32), Vector2(0, -34), Vector2(5, -32), Vector2(9, -25)])


static func _ember(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var hot := snappedf(0.6 + 0.4 * sin(t * 4.0 + i * 1.7), 0.1)
	Art.toon(ci, _DROP, c.lerp(Color("ff9a2a"), 0.4), 2.0, 0.4)
	Art.flat(ci, PackedVector2Array([Vector2(0, -36), Vector2(9, -14), Vector2(0, -1)]), Art.shade_of(c, 0.2))
	Art.flat(ci, _FLAME, Color(c2, hot))
	Art.flat(ci, _FLAME_CORE, Color(1, 1, 0.9, hot))
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -22), Vector2(1.8, 5), 8, 0.35), Color(1, 1, 1, 0.6))


static var _FLAME := Art.smooth_pts(PackedVector2Array([Vector2(0, -26), Vector2(4, -16), Vector2(5, -8), Vector2(0, -4), Vector2(-5, -8), Vector2(-3, -15)]), 2)
static var _FLAME_CORE := Art.smooth_pts(PackedVector2Array([Vector2(0, -17), Vector2(2.4, -10), Vector2(0, -6.5), Vector2(-2.4, -10)]), 2)
static var _HOARD := Art.smooth_pts(PackedVector2Array([Vector2(-32, 0), Vector2(-24, -9), Vector2(-10, -15), Vector2(6, -16),
		Vector2(22, -10), Vector2(32, 0)]), 3)


## A dragon egg (~34 tall, standing on 0,0) with glowing cracks.
static func dragon_egg(ci: CanvasItem, c: Color, c2: Color, t: float) -> void:
	var hot := snappedf(0.55 + 0.45 * sin(t * 2.6), 0.1)
	var shell := Art.shade_of(c, 0.3)
	Art.toon(ci, _EGG, shell, 2.2, 0.6)
	for p: Vector2 in [Vector2(-5, -24), Vector2(4, -24), Vector2(-8, -16), Vector2(8, -18)]:
		Art.arc_c(ci, p, 4.0, 0.2, PI - 0.2, 4, Art.shade_of(shell, 0.3), 1.3)
	Art.line_c(ci, _EGG_CRACK, Color(c2, hot), 2.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -27), Vector2(2.6, 5), 10, 0.4), Color(1, 1, 1, 0.45))


static var _EGG := Art.smooth_pts(PackedVector2Array([Vector2(0, -36), Vector2(9, -30), Vector2(13, -16), Vector2(10, -4),
		Vector2(0, 0), Vector2(-10, -4), Vector2(-13, -16), Vector2(-9, -30)]), 3)
static var _EGG_CRACK := PackedVector2Array([Vector2(-6, -12), Vector2(-2, -16), Vector2(1, -12), Vector2(5, -17), Vector2(8, -14)])


# crown ----------------------------------------------------------------

static func _crown(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.toon(ci, _CROWN, c, 2.0, 0.5)
	Art.t_rect(ci, Rect2(-14, -7, 28, 5), 2, Art.shade_of(c, 0.18), 0.0, 0.0)
	for k in 3:
		Art.flat(ci, _CROWN_GEMS[k], JEWELS[(k + i) % 3])
		Art.flat(ci, _CROWN_PEARLS[k], Color("fbf8ff"))
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -13), Vector2(1.6, 3.4), 8, 0.3), Color(c2, 0.9))


static var _CROWN_GEMS: Array[PackedVector2Array] = [Art.circle_pts(Vector2(-8, -4.5), 2.2, 6), Art.circle_pts(Vector2(0, -4.5), 2.2, 6), Art.circle_pts(Vector2(8, -4.5), 2.2, 6)]
static var _CROWN_PEARLS: Array[PackedVector2Array] = [Art.circle_pts(Vector2(-15, -21), 2.4, 8), Art.circle_pts(Vector2(0, -25), 2.4, 8), Art.circle_pts(Vector2(15, -21), 2.4, 8)]
static var _CROWN := PackedVector2Array([Vector2(-14, 0), Vector2(-15, -19), Vector2(-7, -11), Vector2(0, -23),
		Vector2(7, -11), Vector2(15, -19), Vector2(14, 0)])


static func _chalice(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.t_ellipse(ci, Vector2(0, -2), Vector2(9, 3), Art.shade_of(c, 0.15), 1.8, 0.0)
	Art.t_rect(ci, Rect2(-2.5, -16, 5, 14), 1.5, c, 1.6, 0.0)
	Art.toon(ci, _CUP, c, 2.0, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -36), Vector2(11, 2.4), 12), Art.shade_of(c, 0.4))
	Art.flat(ci, _CHALICE_GEM, JEWELS[(i / 3 + 1) % 3])
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -29), Vector2(1.4, 3.4), 8), Color(c2, 0.9))


static var _CHALICE_GEM := Art.circle_pts(Vector2(0, -26), 3.0, 8)
static var _CUP := Art.smooth_pts(PackedVector2Array([Vector2(-12, -36), Vector2(12, -36), Vector2(10, -24), Vector2(3, -16),
		Vector2(-3, -16), Vector2(-10, -24)]), 2)


# void -----------------------------------------------------------------

static func _orb(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	Art.flat(ci, _ORB_SHADOW, Color(0, 0, 0, 0.3))
	Art.push(ci, Vector2(0, -16 + snappedf(sin(t * 1.6 + i * 1.1) * 2.5, 0.5)))
	void_orb(ci, c, c2, t, 1.0, i % 2 == 1)
	Art.pop(ci)


static var _ORB_SHADOW := Art.ellipse_pts(Vector2(0, -1), Vector2(9, 2.2), 12)


## A dark orb of radius 13 * `r` centered on 0,0, lit by a purple rim;
## `ring` adds a tilted ring around it.
static func void_orb(ci: CanvasItem, c: Color, c2: Color, t: float, r: float, ring: bool) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(r, r))
	Art.dot(ci, Vector2.ZERO, 18.0, Color(c, 0.22))
	if ring:
		Art.push(ci, Vector2.ZERO, -0.35, Vector2(1.0, 0.3))
		Art.arc_c(ci, Vector2.ZERO, 20.0, PI, TAU, 8, Color(c2, 0.7), 3.0)
		Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 13, VOID_BODY, 2.0, 0.0)
	Art.push(ci, Vector2.ZERO, t * 0.8)
	Art.arc_c(ci, Vector2.ZERO, 6.0, 0.0, 3.8, 5, Color(c, 0.45), 1.6)
	Art.pop(ci)
	Art.arc_c(ci, Vector2.ZERO, 11.0, -0.35, 1.9, 6, c, 2.6)
	Art.toon(ci, _ORB_GLINT, Color(1, 1, 1, 0.9), 0.0, 0.0)
	if ring:
		Art.push(ci, Vector2.ZERO, -0.35, Vector2(1.0, 0.3))
		Art.arc_c(ci, Vector2.ZERO, 20.0, 0.0, PI, 8, c2, 3.0)
		Art.pop(ci)
	Art.pop(ci)


static var _ORB_GLINT := Art.star_pts(Vector2(-4.5, -5), 3.2, 0.9, 4)
static var _PEDESTAL := PackedVector2Array([Vector2(-16, 0), Vector2(-11, -6), Vector2(-8, -14), Vector2(8, -14), Vector2(11, -6), Vector2(16, 0)])
static var _PEDESTAL_TOP := PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(5, -12), Vector2(-5, -12)])


# time -----------------------------------------------------------------

static func _hourglass(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var level := snappedf(fposmod(t * 0.08 + i * 0.31, 1.0), 0.1)
	for x: float in [-9.0, 9.0]:
		Art.t_rect(ci, Rect2(x - 1.2, -37, 2.4, 34), 0.0, Art.shade_of(BRASS, 0.2), 0.0, 0.0)
	Art.toon(ci, _GLASS, Color(c2, 0.35), 1.6, 0.0)
	if level < 1.0:
		Art.push(ci, Vector2(0, -20), 0.0, Vector2(1.0, 1.0 - level))
		Art.flat(ci, _SAND_TOP, c)
		Art.pop(ci)
		Art.line_c(ci, PackedVector2Array([Vector2(0, -20), Vector2(0, -7)]), c, 1.3)
	Art.push(ci, Vector2(0, -6), 0.0, Vector2(1.0, maxf(0.1, level)))
	Art.flat(ci, _SAND_BOT, c)
	Art.pop(ci)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -29), Vector2(1.2, 3.5), 8), Color(1, 1, 1, 0.7))
	Art.t_rect(ci, Rect2(-12, -41, 24, 5), 2, BRASS, 1.8, 0.0)
	Art.t_rect(ci, Rect2(-12, -5, 24, 5), 2, BRASS, 1.8, 0.0)


static var _GEAR := Art.gear_pts(20.0, 8)
static var _GLASS := PackedVector2Array([Vector2(-7, -36), Vector2(7, -36), Vector2(6.5, -29), Vector2(4.5, -24), Vector2(1.5, -20),
		Vector2(4.5, -16), Vector2(6.5, -11), Vector2(7, -5), Vector2(-7, -5), Vector2(-6.5, -11), Vector2(-4.5, -16), Vector2(-1.5, -20),
		Vector2(-4.5, -24), Vector2(-6.5, -29)])
## Top sand in its bulb, anchored at the neck (0, -20); the bottom pile
## anchored at the floor of the glass (0, -6).
static var _SAND_TOP := PackedVector2Array([Vector2(-5.5, -9), Vector2(5.5, -9), Vector2(4.5, -5), Vector2(1, 0), Vector2(-1, 0), Vector2(-4.5, -5)])
static var _SAND_BOT := Art.smooth_pts(PackedVector2Array([Vector2(-6, 1), Vector2(-4, -3), Vector2(0, -8), Vector2(4, -3), Vector2(6, 1)]), 2)


static var _WATCH_KNOB := PackedVector2Array([Vector2(-2.5, -28), Vector2(2.5, -28), Vector2(3, -33), Vector2(0, -35), Vector2(-3, -33)])
static var _WATCH_FACE := Art.circle_pts(Vector2(0, -15), 11, 14)


static func _watch(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var ctr := Vector2(0, -15)
	Art.toon(ci, _WATCH_KNOB, BRASS, 1.4, 0.0)
	Art.t_circle(ci, ctr, 14, BRASS, 2.0, 0.0)
	Art.flat(ci, _WATCH_FACE, c.lerp(c2, 0.75))
	Art.push(ci, ctr, t * 1.2 + i)
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, -8.5)]), Art.INK, 1.6)
	Art.pop(ci)
	Art.push(ci, ctr, t * 0.1 + i * 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, -5.5)]), c.darkened(0.3), 2.2)
	Art.pop(ci)
	Art.flat(ci, Art.circle_pts(ctr, 1.6, 8), Art.INK)
	Art.flat(ci, Art.ellipse_pts(ctr + Vector2(-6, -6), Vector2(3, 1.5), 8, -0.7), Color(1, 1, 1, 0.6))


# heart ----------------------------------------------------------------

## The heart gem, ~32 tall, standing on its tip at 0,0; it beats.
static func _heart_gem(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var beat := maxf(0.0, sin(t * 3.2 + i)) * 0.07
	Art.push(ci, Vector2(0, -15), 0.0, Vector2.ONE * (1.0 + beat))
	Art.toon(ci, HEART, c, 2.0, 0.0)
	Art.flat(ci, _HEART_SHADE, Art.shade_of(c, 0.28))
	Art.flat(ci, _HEART_IN, c.lerp(c2, 0.35))
	for p: Vector2 in [Vector2(-7, -9), Vector2(7, -9), Vector2(0, 13)]:
		Art.line_c(ci, PackedVector2Array([Vector2(0, -2), p]), Color(c2, 0.6), 1.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -9), Vector2(2, 3.5), 8, 0.6), Color(1, 1, 1, 0.8))
	Art.toon(ci, Art.star_pts(Vector2(5, -8), 3.2, 0.9, 4), Color("ffd0ec"), 0.0, 0.0)
	Art.pop(ci)


## Heart outline centered on 0,0 (~30 wide, ~32 tall, tip down).
static var HEART := Art.smooth_pts(PackedVector2Array([Vector2(0, -8), Vector2(5, -14), Vector2(11, -15), Vector2(15, -10),
		Vector2(14, -2), Vector2(8, 7), Vector2(0, 15), Vector2(-8, 7), Vector2(-14, -2), Vector2(-15, -10), Vector2(-11, -15), Vector2(-5, -14)]), 3)
## The same heart with few points, for small copies (pendants, badges).
static var HEART_LO := Art.smooth_pts(PackedVector2Array([Vector2(0, -8), Vector2(6, -15), Vector2(14, -12), Vector2(14, -2),
		Vector2(0, 15), Vector2(-14, -2), Vector2(-14, -12), Vector2(-6, -15)]), 2)
static var _HEART_IN := Art.smooth_pts(PackedVector2Array([Vector2(0, -3), Vector2(4, -7), Vector2(7, -5), Vector2(6, 0),
		Vector2(0, 6), Vector2(-6, 0), Vector2(-7, -5), Vector2(-4, -7)]), 2)
static var _HEART_SHADE := Art.clipped(PackedVector2Array([Vector2(2, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-4, 20)]), HEART)


static func _sea_pearl(ci: CanvasItem, c: Color, c2: Color) -> void:
	Art.t_circle(ci, Vector2(0, -10), 10, c2, 2.0, 0.4)
	Art.flat(ci, _PEARL_SHEEN, Color(c, 0.75))
	Art.flat(ci, Art.circle_pts(Vector2(-3.5, -13.5), 2.8, 10), Color(1, 1, 1, 0.95))
	Art.flat(ci, Art.circle_pts(Vector2(4, -5), 1.4, 8), Color("ffb8e0"))


## Soft rays of light turning around `c` (the finale's heart).
static func heart_rays(ci: CanvasItem, c: Vector2, r: float, color: Color, t: float, n: int = 6) -> void:
	var clear := Color(color, 0.0)
	var col := Color(color, 0.35)
	for k in n:
		var a := t * 0.25 + TAU * k / n
		var d1 := Vector2.from_angle(a - 0.12) * r
		var d2 := Vector2.from_angle(a + 0.12) * r
		Art.grad(ci, PackedVector2Array([c, c + d1, c + d2]), PackedColorArray([col, clear, clear]))


# --- The volcano, swamp and moon sites ---------------------------------------------------

## One piece of the newer worlds' kinds (unit space, ~40 tall, on 0,0).
static func world_piece(ci: CanvasItem, kind: String, c: Color, c2: Color, t: float, i: int) -> void:
	match kind:
		"ash":
			_ash(ci, c, c2, t, i)
		"sulfur":
			_sulfur(ci, c, c2, i)
		"fire_opal":
			_opal(ci, c, c2, i)
		"garnet":
			if i % 3 == 1:
				_cut_gem(ci, c, c2)
			else:
				_hex_gem(ci, c, c2)
		"ember":
			_ember(ci, c, c2, t, i)
		"phoenix":
			_feather(ci, c, c2, i)
		"slime", "goo_king":
			if kind == "goo_king" and i % 3 == 2:
				_crown(ci, Color("ffc93c"), Color("fff6c0"), i)
			else:
				_slime(ci, c, c2, i)
		"moss":
			_moss(ci, c, c2, i)
		"bubble":
			_bubbles(ci, c, c2, i)
		"venom":
			_flask(ci, c, c2, i)
		"radiant":
			Art.crystal(ci, Vector2.ZERO, 40, 8, 0.0, c if i % 2 == 0 else c2.lerp(c, 0.4), 2.0)
			Art.flat(ci, Art.ellipse_pts(Vector2(-2, -24), Vector2(1.6, 6), 8), Color(1, 1, 1, 0.6))
		"dust":
			_dust(ci, c, c2, t, i)
		"comet":
			_comet(ci, c, c2, i)
		"alien_egg":
			_alien_egg(ci, c, c2, t, i)
		"ufo":
			_ufo(ci, c, c2, t, i)


static var _NEST_SMALL := Art.smooth_pts(PackedVector2Array([Vector2(-22, 0), Vector2(-24, -6), Vector2(-16, -10), Vector2(0, -8),
		Vector2(16, -10), Vector2(24, -6), Vector2(22, 0)]), 3)


## A lump of grey pumice with an ember in it.
static func _ash(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _NUGGET, c, 2.0, 0.6)
	for p: Vector3 in [Vector3(-6, -14, 2.2), Vector3(5, -18, 1.8), Vector3(8, -7, 2.0), Vector3(-9, -5, 1.6)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 8), Art.shade_of(c, 0.3))
	var hot := snappedf(0.6 + 0.4 * sin(t * 3.0 + i), 0.1)
	Art.flat(ci, Art.circle_pts(Vector2(-1, -10), 3.0, 10), Color(c2, hot))
	Art.pop(ci)


## A fire opal: an oval cabochon with sparkling colored flecks.
static func _opal(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.toon(ci, _OPAL, c, 2.0, 0.4)
	Art.flat(ci, _OPAL_FLECK_A, Color(c2, 0.9))
	Art.flat(ci, _OPAL_FLECK_B, Color("ff6ad8", 0.8))
	Art.flat(ci, _OPAL_FLECK_C, Color("9aff6a", 0.8))
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -24), Vector2(2.4, 5), 8, 0.4), Color(1, 1, 1, 0.7))


static var _OPAL := Art.ellipse_pts(Vector2(0, -16), Vector2(13, 16), 22)
static var _OPAL_FLECK_A := Art.ellipse_pts(Vector2(4, -20), Vector2(4, 2.4), 10, 0.5)
static var _OPAL_FLECK_B := Art.ellipse_pts(Vector2(-4, -10), Vector2(3.4, 2.0), 10, -0.4)
static var _OPAL_FLECK_C := Art.ellipse_pts(Vector2(5, -8), Vector2(2.2, 1.6), 8)


## A phoenix feather: a flame-shaped feather with a bright quill.
static func _feather(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _FEATHER, c, 2.0, 0.4)
	Art.flat(ci, _FEATHER_TIP, c2)
	Art.line_c(ci, PackedVector2Array([Vector2(0, 0), Vector2(1, -20), Vector2(4, -36)]), Color("fff0b0"), 1.8)
	Art.pop(ci)


static var _FEATHER := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-7, -10), Vector2(-9, -24), Vector2(-2, -38), Vector2(4, -40),
		Vector2(9, -28), Vector2(8, -14), Vector2(2, -4)]), 3)
static var _FEATHER_TIP := Art.clipped(Art.ellipse_pts(Vector2(2, -36), Vector2(9, 8), 14), _FEATHER)


## A cute slime blob with a face.
static func _slime(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.toon(ci, _SLIME, c, 2.2, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -18), Vector2(3, 2), 10, -0.5), Color(c2, 0.9))
	for sx: float in [-1.0, 1.0]:
		Art.t_ellipse(ci, Vector2(sx * 5, -11), Vector2(1.8, 2.6), Art.INK, 0.0, 0.0)
	Art.arc_c(ci, Vector2(0, -8), 3.0, 0.4, PI - 0.4, 6, Art.INK, 1.6)


static var _SLIME := Art.smooth_pts(PackedVector2Array([Vector2(-14, 0), Vector2(-13, -9), Vector2(-7, -18), Vector2(0, -22),
		Vector2(7, -18), Vector2(13, -9), Vector2(14, 0)]), 3)


## A rock with a soft moss cap.
static func _moss(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(-1.0 if i % 2 else 1.0, 1.0))
	Art.toon(ci, _NUGGET, Color("7a7468"), 2.0, 0.6)
	Art.toon(ci, _MOSS_CAP, c, 1.8, 0.4)
	for p: Vector2 in [Vector2(-6, -21), Vector2(4, -23), Vector2(10, -16)]:
		Art.flat(ci, Art.circle_pts(p, 1.6, 6), c2)
	Art.pop(ci)


static var _MOSS_CAP := Art.smooth_pts(PackedVector2Array([Vector2(-17, -10), Vector2(-10, -20), Vector2(0, -26), Vector2(10, -22),
		Vector2(17, -13), Vector2(10, -11), Vector2(4, -14), Vector2(-4, -11), Vector2(-10, -13)]), 2)


## A cluster of shiny bubbles.
static func _bubbles(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	for b: Vector3 in [Vector3(-6, -9, 9), Vector3(7, -10, 7), Vector3(1, -24, 8)]:
		Art.t_circle(ci, Vector2(b.x, b.y), b.z, Color(c, 0.8), 2.0, 0.3)
		Art.flat(ci, Art.ellipse_pts(Vector2(b.x - b.z * 0.35, b.y - b.z * 0.35), Vector2(b.z * 0.28, b.z * 0.18), 8, -0.6), Color(c2, 0.95))


## A round potion flask of swamp venom.
static func _flask(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.t_rect(ci, Rect2(-4, -38, 8, 12), 2, Art.GLASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-5, -42, 10, 5), 2, Color("a8743a"), 1.8, 0.0)
	Art.t_circle(ci, Vector2(0, -14), 14, Art.GLASS, 2.2, 0.0)
	Art.flat(ci, _FLASK_LIQUID, c)
	Art.flat(ci, Art.circle_pts(Vector2(4, -10), 2.2, 8), c2)
	Art.flat(ci, Art.circle_pts(Vector2(-3, -6), 1.5, 8), c2)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -20), Vector2(2, 4), 8, 0.4), Color(1, 1, 1, 0.7))


static var _FLASK_LIQUID := Art.clipped(Art.rrect_pts(Rect2(-14, -16, 28, 18), 1), Art.circle_pts(Vector2(0, -14), 12, 20))


## A heap of glittering moon dust.
static func _dust(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	Art.toon(ci, _DUST, c, 2.0, 0.5)
	var tw := snappedf(0.5 + 0.5 * sin(t * 3.0 + i), 0.1)
	for p: Vector2 in [Vector2(-6, -10), Vector2(5, -14)]:
		Art.flat(ci, Art.circle_pts(p, 1.6, 6), Color(c2, 0.6 + tw * 0.4))
	Art.push(ci, Vector2(2, -22), 0.0, Vector2.ONE * (0.4 + tw * 0.4))
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 6, 1.5, 4), Color(1, 1, 1, 0.9), 0.0, 0.0)
	Art.pop(ci)


static var _DUST := Art.smooth_pts(PackedVector2Array([Vector2(-17, 0), Vector2(-10, -10), Vector2(0, -17), Vector2(10, -10), Vector2(17, 0)]), 3)


## A small icy comet with its glowing tail.
static func _comet(ci: CanvasItem, c: Color, c2: Color, i: int) -> void:
	Art.flat(ci, _COMET_TAIL, Color(c, 0.5))
	Art.toon(ci, _COMET, c.lerp(Color.WHITE, 0.3), 2.0, 0.5)
	Art.flat(ci, Art.circle_pts(Vector2(-3, -16), 2.2, 8), Art.shade_of(c, 0.2))
	Art.flat(ci, Art.ellipse_pts(Vector2(4, -20), Vector2(2, 3), 8, 0.4), Color(c2, 0.9))


static var _COMET := Art.smooth_pts(PackedVector2Array([Vector2(-10, -4), Vector2(-12, -16), Vector2(-4, -26), Vector2(8, -24), Vector2(12, -12), Vector2(6, -2)]), 3)
static var _COMET_TAIL := PackedVector2Array([Vector2(-6, -24), Vector2(-26, -40), Vector2(-30, -30), Vector2(-10, -10)])


## An alien egg: speckled and softly glowing.
static func _alien_egg(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	var hot := snappedf(0.6 + 0.4 * sin(t * 2.0 + i * 1.3), 0.1)
	Art.toon(ci, _EGG, c, 2.2, 0.5)
	for p: Vector3 in [Vector3(-5, -24, 2.6), Vector3(5, -16, 3.0), Vector3(-4, -10, 2.0), Vector3(4, -28, 1.8)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 8), Color(c2, hot))
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -27), Vector2(2.6, 5), 10, 0.4), Color(1, 1, 1, 0.45))


## A little flying saucer with a glass dome and blinking lights.
static func _ufo(ci: CanvasItem, c: Color, c2: Color, t: float, i: int) -> void:
	Art.t_ellipse(ci, Vector2(0, -16), Vector2(9, 8), Art.GLASS, 2.0, 0.0)
	Art.t_ellipse(ci, Vector2(0, -9), Vector2(20, 6), c, 2.2, 0.5)
	for k in 3:
		var on := fposmod(t * 2.0 + k * 0.33 + i * 0.2, 1.0) < 0.5
		Art.flat(ci, Art.circle_pts(Vector2(-10 + k * 10, -8), 2.0, 8), c2 if on else Art.shade_of(c2, 0.4))
	Art.t_rect(ci, Rect2(-7, -4, 14, 4), 2, Art.shade_of(c, 0.2), 1.6, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-3, -19), Vector2(2, 3), 8, 0.4), Color(1, 1, 1, 0.7))

