class_name OreArt
extends RefCounted
## What each dive site digs up: the deposit at the end of the cave, the
## chunk a diver carries in the sack and the chips that fly off the pick.
## Every site has its own shape (shells, coral, pearls in clams, copper
## nuggets, ... fallen stars) colored by its Art.DEPTH_STYLE ore colors.
##
## Pieces are drawn in a unit space where one piece is ~40 px tall and
## stands on (0, 0), then placed with Art.push, so their geometry is cached.

const KINDS: Array[String] = ["shells", "coral", "pearl", "copper", "emerald", "crystal", "amber", "sapphire", "gold",
		"ruby", "ice", "lava", "jade", "moon", "fossil", "obsidian", "glow", "atlantis", "meteor", "kraken", "star"]
## Kinds that give off light (a soft pulsing glow behind them).
const GLOWING: Array[String] = ["lava", "moon", "glow", "atlantis", "meteor", "star", "kraken"]
## Kinds that sit in a mound of rock.
const IN_ROCK: Array[String] = ["copper", "lava", "fossil", "meteor", "obsidian"]


static func kind_of(depth: int) -> String:
	return KINDS[clampi(depth, 0, KINDS.size() - 1)]


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
		if big and kind in ["gold", "kraken", "atlantis", "pearl"]:
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
		"kraken", "atlantis":
			piece(ci, kind, Vector2(0, 16 * s), s * 1.3, 0.0, st, 0.0, 1)
		"pearl", "copper", "moon", "lava", "meteor", "sapphire", "star", "fossil":
			piece(ci, kind, Vector2(0, 20 * s), s * 1.3, 0.0, st, 0.0, 1)
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
		"star", "moon", "glow":
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 5.0, 2.2, 4), st["ore2"], 1.2, 0.0)
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
		"glow", "gold", "atlantis", "jade", "moon", "pearl", "copper", "fossil", "lava", "meteor", "star", "kraken":
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
