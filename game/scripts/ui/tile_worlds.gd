class_name TileWorlds
extends RefCounted
## Match-3 pieces of the other worlds (the ocean ones are in TileArt):
## volcano (lava), acid swamp (mushrooms) and moon (space). Same rules as
## TileArt: centered at (0,0), fit a 56x56 cell, every kind has its own color
## AND silhouette. Slot i replaces TileArt.KINDS[i] in that world.
##
## Volcano: fire opal, obsidian shard, flame, ruby, lava blob, lava rock.
## Acid:    slime drop, mushroom, frog, orchid, amber, glow spore.
## Moon:    moonstone, ringed planet, star, alien, meteor, UFO.
## Jungle:  banana bunch, parrot, hibiscus, coconut, golden idol mask,
##          tiger's-eye gem (and its own specials, blockers: TileJungle).

const _W := 3.0

const COLORS := {
	1: [Color("6fdcff"), Color("4b3a6b"), Color("ffd23a"), Color("e8263f"), Color("ff5a1e"), Color("6e7a8f")],
	2: [Color("8ff03c"), Color("e8423c"), Color("2fc4a0"), Color("d45cf0"), Color("ffae2a"), Color("4fc8ff")],
	3: [Color("e8f4ff"), Color("ff9a4a"), Color("ffe04a"), Color("6ee05a"), Color("d8553a"), Color("a77bff")],
	4: [Color("ffe03a"), Color("3a9cff"), Color("ff4a86"), Color("9a6234"), Color("ffa21e"), Color("2fd27a")],
}


static func color(world: int, slot: int) -> Color:
	return COLORS[world][slot]


static func draw(ci: CanvasItem, world: int, slot: int, t: float, lift: float) -> void:
	var col: Color = COLORS[world][slot]
	if lift > 0.0:
		col = col.lightened(lift)
	match world * 10 + slot:
		10: _opal(ci, t, col)
		11: _obsidian(ci, t, col)
		12: _flame(ci, t, col)
		13: _ruby(ci, t, col)
		14: _lava_blob(ci, t, col)
		15: _lava_rock(ci, t, col)
		20: _slime(ci, t, col)
		21: _mushroom(ci, t, col)
		22: _frog(ci, t, col)
		23: _orchid(ci, t, col)
		24: _amber(ci, t, col)
		25: _spore(ci, t, col)
		30: _moonstone(ci, t, col)
		31: _planet(ci, t, col)
		32: _star(ci, t, col)
		33: _alien(ci, t, col)
		34: _meteor(ci, t, col)
		35: _ufo(ci, t, col)
		40, 41, 42, 43, 44, 45: TileJungle.piece(ci, slot, t, col)


static func _shine(ci: CanvasItem, c: Vector2, radii: Vector2, rot: float, a: float = 0.8) -> void:
	Art.flat(ci, Art.ellipse_pts(c, radii, 14, rot), Color(1, 1, 1, a))


static func _eyes(ci: CanvasItem, at: Vector2, gap: float, r: float) -> void:
	for sx: float in [-1.0, 1.0]:
		var p := at + Vector2(gap * sx, 0)
		Art.t_circle(ci, p, r, Art.WHITE, 2.0, 0.0)
		Art.flat(ci, Art.circle_pts(p + Vector2(0.6, 0.6), r * 0.58, 12), Art.INK)
		Art.flat(ci, Art.circle_pts(p + Vector2(-0.4, -0.8), r * 0.22, 8), Art.WHITE)


static func _twinkle(ci: CanvasItem, pos: Vector2, size: float, t: float, phase: float) -> void:
	var s := maxf(0.0, sin(t * 2.6 + phase))
	if s < 0.08:
		return
	Art.push(ci, pos, 0.0, Vector2(s, s) * size)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 1.0, 0.24, 4), Color(1, 1, 1, 0.95))
	Art.pop(ci)


# --- Volcano -------------------------------------------------------------------------

## Fire opal: a round blue-green orb with flashes of color.
static func _opal(ci: CanvasItem, t: float, col: Color) -> void:
	var body := Art.circle_pts(Vector2.ZERO, 21.0, 36)
	Art.toon(ci, body, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(5, 7), 16.0, 28), body), Color(0.25, 0.45, 1.0, 0.4))
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(9, 11), 9.0, 20), body), Color(1.0, 0.45, 0.7, 0.45))
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-10, 10), 6.0, 14), body), Color(0.6, 1.0, 0.5, 0.4))
	_shine(ci, Vector2(-7, -9), Vector2(7.5, 4.5), -0.7)
	_twinkle(ci, Vector2(11, -10), 6.0, t, 0.5)


## Obsidian: a tall dark glassy shard.
static func _obsidian(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, 2), sin(t * 1.3) * 0.04)
	var shard := PackedVector2Array([Vector2(-4, -25), Vector2(10, -13), Vector2(16, 6), Vector2(6, 22), Vector2(-12, 20), Vector2(-17, 2)])
	Art.toon(ci, shard, col, _W, 0.5)
	Art.flat(ci, PackedVector2Array([Vector2(-4, -25), Vector2(10, -13), Vector2(2, 4), Vector2(-17, 2)]), Color("7a68a8"))
	Art.line(ci, Vector2(2, 4), Vector2(6, 22), Color("2a1f40"), 2.0)
	Art.line(ci, Vector2(2, 4), Vector2(16, 6), Color("2a1f40"), 2.0)
	_shine(ci, Vector2(-6, -12), Vector2(2.5, 7.5), 0.6, 0.75)
	Art.pop(ci)


## Flame: a flickering fire tongue.
static func _flame(ci: CanvasItem, t: float, col: Color) -> void:
	var f := 1.0 + snappedf(sin(t * 7.0), 0.25) * 0.05
	Art.push(ci, Vector2(0, 22), 0.0, Vector2(1.0 / f, f))
	Art.push(ci, Vector2(0, -22))
	var outer := Art.smooth_pts(PackedVector2Array([Vector2(0, -26), Vector2(9, -10), Vector2(18, 4), Vector2(14, 18), Vector2(0, 23),
			Vector2(-14, 18), Vector2(-18, 4), Vector2(-8, -6), Vector2(-4, -14)]), 3)
	Art.toon(ci, outer, col, _W, 0.3)
	var inner := Art.smooth_pts(PackedVector2Array([Vector2(1, -10), Vector2(9, 4), Vector2(8, 15), Vector2(0, 19), Vector2(-8, 15), Vector2(-9, 5)]), 3)
	Art.flat(ci, inner, Color("fff09a"))
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 12), Vector2(4.5, 6), 12), Color("ffffff"))
	Art.pop(ci)
	Art.pop(ci)


## Ruby: a faceted red gem.
static func _ruby(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, 1), sin(t * 1.5) * 0.04)
	var gem := PackedVector2Array([Vector2(-22, -8), Vector2(-12, -20), Vector2(12, -20), Vector2(22, -8), Vector2(0, 22)])
	Art.toon(ci, gem, col, _W, 0.5)
	Art.line(ci, Vector2(-22, -8), Vector2(22, -8), Art.shade_of(col, 0.35), 2.0)
	Art.polyline(ci, PackedVector2Array([Vector2(-12, -20), Vector2(-7, -8), Vector2(0, 22), Vector2(7, -8), Vector2(12, -20)]), Art.shade_of(col, 0.35), 2.0)
	Art.flat(ci, PackedVector2Array([Vector2(-10, -17), Vector2(-3, -17), Vector2(-6, -10)]), Color(1, 1, 1, 0.85))
	_twinkle(ci, Vector2(13, -14), 6.0, t, 1.7)
	Art.pop(ci)


## Lava blob: a cute molten drop with a face.
static func _lava_blob(ci: CanvasItem, t: float, col: Color) -> void:
	var sq := 1.0 + snappedf(sin(t * 3.2), 0.25) * 0.05
	Art.push(ci, Vector2(0, 20), 0.0, Vector2(sq, 1.0 / sq))
	Art.push(ci, Vector2(0, -20))
	var body := Art.smooth_pts(PackedVector2Array([Vector2(0, -21), Vector2(12, -12), Vector2(20, 6), Vector2(16, 18), Vector2(0, 21),
			Vector2(-16, 18), Vector2(-20, 6), Vector2(-12, -12)]), 3)
	Art.toon(ci, body, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(0, 16), Vector2(18, 8), 18), body), Color("ffd23a"))
	_eyes(ci, Vector2(0, 0), 7.0, 4.6)
	Art.arc(ci, Vector2(0, 7), 4.0, 0.3, PI - 0.3, 8, Art.INK, 1.8)
	_shine(ci, Vector2(-8, -11), Vector2(4, 2.4), -0.7, 0.7)
	Art.pop(ci)
	Art.pop(ci)


## Lava rock: a dark spiky rock with glowing cracks.
static func _lava_rock(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2.ZERO, sin(t * 1.1) * 0.05)
	var rock := PackedVector2Array([Vector2(-20, -6), Vector2(-14, -18), Vector2(-2, -15), Vector2(6, -23), Vector2(16, -12),
			Vector2(22, 2), Vector2(14, 18), Vector2(0, 21), Vector2(-16, 16), Vector2(-23, 4)])
	Art.toon(ci, rock, col, _W, 0.6)
	var glow := Color("ffb02a").lerp(Color("ff5a1a"), 0.5 + snappedf(sin(t * 4.0), 0.25) * 0.5)
	Art.polyline(ci, PackedVector2Array([Vector2(-12, -8), Vector2(-4, -2), Vector2(-6, 8), Vector2(2, 14)]), glow, 3.0)
	Art.polyline(ci, PackedVector2Array([Vector2(-4, -2), Vector2(8, -6), Vector2(14, 4)]), glow, 3.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-10, -12), Vector2(4, 2), 10, -0.5), Color(1, 1, 1, 0.45))
	Art.pop(ci)


# --- Acid swamp ----------------------------------------------------------------------

## Slime drop: a bright toxic droplet.
static func _slime(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, snappedf(sin(t * 2.0), 0.25) * 1.2))
	var drop := Art.smooth_pts(PackedVector2Array([Vector2(0, -25), Vector2(10, -8), Vector2(18, 8), Vector2(10, 21), Vector2(-10, 21),
			Vector2(-18, 8), Vector2(-10, -8)]), 3)
	Art.toon(ci, drop, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(6, 12), 12.0, 20), drop), Color(0.2, 0.6, 0.1, 0.35))
	Art.t_circle(ci, Vector2(5, 6), 3.5, Color("d8ffb0"), 1.6, 0.0)
	Art.t_circle(ci, Vector2(-5, 13), 2.2, Color("d8ffb0"), 1.4, 0.0)
	_shine(ci, Vector2(-6, -4), Vector2(3, 6.5), 0.3)
	Art.pop(ci)


## Mushroom: red cap with white dots on a stem.
static func _mushroom(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, 22), sin(t * 1.6) * 0.04)
	Art.push(ci, Vector2(0, -22))
	Art.toon(ci, Art.rrect_pts(Rect2(-7, -2, 14, 24), 6), Color("f4eadc"), _W, 0.5)
	var cap := Art.smooth_pts(PackedVector2Array([Vector2(-24, 2), Vector2(-20, -14), Vector2(0, -24), Vector2(20, -14), Vector2(24, 2)]), 3)
	Art.toon(ci, cap, col, _W, 0.5)
	for p: Vector3 in [Vector3(-11, -8, 4.0), Vector3(4, -15, 3.5), Vector3(13, -5, 3.0), Vector3(-2, -4, 2.5)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 12), Color(1, 1, 1, 0.92))
	Art.pop(ci)
	Art.pop(ci)


## Frog: a round teal frog face.
static func _frog(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, snappedf(absf(sin(t * 2.5)), 0.25) * -1.5))
	var body := Art.ellipse_pts(Vector2(0, 5), Vector2(21, 16), 30)
	for sx: float in [-1.0, 1.0]:
		Art.toon(ci, Art.circle_pts(Vector2(10 * sx, -11), 8.0, 20), col, _W, 0.4)
	Art.toon(ci, body, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(0, 14), Vector2(16, 8), 20), body), Color("c8ffe8"))
	_eyes(ci, Vector2(0, -11), 10.0, 5.0)
	Art.arc(ci, Vector2(0, 2), 8.0, 0.35, PI - 0.35, 10, Art.INK, 2.0)
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(13 * sx, 5), Vector2(3, 1.8), 10), Color(1.0, 0.5, 0.6, 0.6))
	Art.pop(ci)


## Orchid: a five-petal swamp flower.
static func _orchid(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2.ZERO, sin(t * 1.2) * 0.08)
	var petals := []
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		petals.append(Art.ellipse_pts(Vector2(cos(a), sin(a)) * 12.0, Vector2(11, 8), 18, a))
	Art.toon(ci, Art.union(petals), col, _W, 0.5)
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		Art.line(ci, Vector2(cos(a), sin(a)) * 6.0, Vector2(cos(a), sin(a)) * 16.0, Art.shade_of(col, 0.3), 1.8)
	Art.t_circle(ci, Vector2.ZERO, 6.0, Color("ffe04a"), 2.2, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(-1.5, -1.5), 1.8, 8), Color(1, 1, 1, 0.9))
	Art.pop(ci)


## Amber: a honey-colored stone with a tiny bug inside.
static func _amber(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2.ZERO, sin(t * 1.4) * 0.05)
	var stone := Art.smooth_pts(PackedVector2Array([Vector2(-18, -14), Vector2(4, -22), Vector2(20, -10), Vector2(19, 10), Vector2(4, 21),
			Vector2(-16, 15), Vector2(-22, 0)]), 3)
	Art.toon(ci, stone, col, _W, 0.5)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(6, 8), 13.0, 20), stone), Color(0.85, 0.4, 0.05, 0.35))
	Art.flat(ci, Art.ellipse_pts(Vector2(2, 3), Vector2(4, 2.5), 10, 0.4), Color("5a3010"))
	Art.line(ci, Vector2(-1, 1), Vector2(-5, -2), Color("5a3010"), 1.4)
	Art.line(ci, Vector2(4, 6), Vector2(7, 9), Color("5a3010"), 1.4)
	_shine(ci, Vector2(-8, -10), Vector2(6, 3), -0.6)
	_twinkle(ci, Vector2(12, -12), 5.0, t, 2.4)
	Art.pop(ci)


## Glow spore: a fuzzy glowing ball.
static func _spore(ci: CanvasItem, t: float, col: Color) -> void:
	var g := 1.0 + snappedf(sin(t * 3.0), 0.25) * 0.06
	Art.push(ci, Vector2.ZERO, t * 0.3, Vector2(g, g))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 26.0, 28), Color(col, 0.25))
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 22.0, 16.0, 12), Art.shade_of(col, 0.25), 2.4, 0.0)
	Art.pop(ci)
	Art.toon(ci, Art.circle_pts(Vector2.ZERO, 15.0, 28), col, _W, 0.6)
	for p: Vector2 in [Vector2(-5, 3), Vector2(4, -5), Vector2(6, 6)]:
		Art.flat(ci, Art.circle_pts(p, 2.4, 10), Color("e0faff"))
	_shine(ci, Vector2(-5, -7), Vector2(4, 2.4), -0.6)


# --- Moon ----------------------------------------------------------------------------

## Moonstone: a pale glowing round stone with craters.
static func _moonstone(ci: CanvasItem, t: float, col: Color) -> void:
	var body := Art.circle_pts(Vector2.ZERO, 21.0, 36)
	Art.toon(ci, body, col, _W, 0.7)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(7, 8), 16.0, 28), body), Color(0.55, 0.65, 1.0, 0.35))
	for p: Vector3 in [Vector3(6, 7, 4.0), Vector3(-7, 9, 2.6), Vector3(9, -6, 2.4)]:
		Art.t_circle(ci, Vector2(p.x, p.y), p.z, Color("c8d8f0"), 1.4, 0.0)
	_shine(ci, Vector2(-7, -9), Vector2(7, 4), -0.7)
	_twinkle(ci, Vector2(-14, 12), 5.0, t, 0.9)


## Ringed planet.
static func _planet(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2.ZERO, -0.35 + sin(t * 1.0) * 0.05)
	var ring := Art.ellipse_pts(Vector2.ZERO, Vector2(27, 8), 36)
	Art.ring(ci, ring, Art.INK, 7.0)
	Art.ring(ci, ring, Color("ffe0a0"), 3.6)
	var body := Art.circle_pts(Vector2.ZERO, 16.0, 30)
	Art.toon(ci, body, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-18, -4, 36, 5), 2), body), Art.shade_of(col, 0.2))
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-18, 5, 36, 3), 1), body), Art.shade_of(col, 0.2))
	# The front half of the ring over the planet.
	var front := PackedVector2Array()
	for i in 19:
		var a := PI * i / 18.0
		front.append(Vector2(cos(a) * 27.0, sin(a) * 8.0))
	Art.polyline(ci, front, Art.INK, 7.0)
	Art.polyline(ci, front, Color("ffe0a0"), 3.6)
	_shine(ci, Vector2(-6, -8), Vector2(4.5, 2.6), -0.6)
	Art.pop(ci)


## Five-point star with a face.
static func _star(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, 1.5), sin(t * 1.4) * 0.08)
	Art.toon(ci, Art.smooth_pts(Art.star_pts(Vector2.ZERO, 25.0, 12.5, 5), 2), col, _W, 0.6)
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(4.5 * sx, -1), Vector2(1.8, 2.6), 10), Art.INK)
	Art.arc(ci, Vector2(0, 3), 3.0, 0.3, PI - 0.3, 8, Art.INK, 1.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -9), Vector2(3.6, 2.0), 10, -1.1), Color(1, 1, 1, 0.75))
	Art.pop(ci)


## Little green alien head with an antenna.
static func _alien(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, snappedf(sin(t * 2.4), 0.25) * 1.2))
	var bob := snappedf(sin(t * 4.0), 0.25) * 0.15
	Art.push(ci, Vector2(0, -14), bob)
	Art.line(ci, Vector2(0, 0), Vector2(0, -11), Art.INK, 2.4)
	Art.t_circle(ci, Vector2(0, -12), 3.6, Color("ffd23a"), 2.0, 0.0)
	Art.pop(ci)
	var head := Art.smooth_pts(PackedVector2Array([Vector2(0, -17), Vector2(16, -10), Vector2(19, 4), Vector2(9, 19), Vector2(-9, 19),
			Vector2(-19, 4), Vector2(-16, -10)]), 3)
	Art.toon(ci, head, col, _W, 0.6)
	for sx: float in [-1.0, 1.0]:
		Art.toon(ci, Art.ellipse_pts(Vector2(8 * sx, 0), Vector2(5.5, 7.5), 16, -0.35 * sx), Art.INK, 1.5, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(8 * sx - 1.5, -3), 1.8, 8), Art.WHITE)
	Art.arc(ci, Vector2(0, 10), 3.2, 0.3, PI - 0.3, 8, Art.INK, 1.6)
	Art.pop(ci)


## Meteor: a rock with a flaming tail.
static func _meteor(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2.ZERO, -0.6)
	var flick := 1.0 + snappedf(sin(t * 8.0), 0.25) * 0.08
	Art.push(ci, Vector2(-6, 0), 0.0, Vector2(flick, 1.0))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -11), Vector2(-20, -6), Vector2(-26, 0), Vector2(-20, 6), Vector2(0, 11)]), 3), Color("ffb02a"), 2.4, 0.0)
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -6), Vector2(-14, -3), Vector2(-18, 0), Vector2(-14, 3), Vector2(0, 6)]), 3), Color("fff0a0"))
	Art.pop(ci)
	var rock := PackedVector2Array([Vector2(-4, -13), Vector2(8, -14), Vector2(16, -4), Vector2(14, 10), Vector2(2, 15), Vector2(-9, 8), Vector2(-10, -4)])
	Art.toon(ci, rock, col, _W, 0.6)
	for p: Vector3 in [Vector3(6, -4, 3.2), Vector3(2, 7, 2.4), Vector3(10, 6, 1.8)]:
		Art.t_circle(ci, Vector2(p.x, p.y), p.z, Art.shade_of(col, 0.3), 1.2, 0.0)
	Art.pop(ci)


## UFO: a purple saucer with a glass dome and blinking lights.
static func _ufo(ci: CanvasItem, t: float, col: Color) -> void:
	Art.push(ci, Vector2(0, snappedf(sin(t * 2.0), 0.25) * 1.5), sin(t * 1.3) * 0.06)
	Art.toon(ci, Art.ellipse_pts(Vector2(0, -5), Vector2(11, 11), 24), Color("bff3ff"), _W, 0.3)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -9), Vector2(3, 2), 10, -0.6), Color(1, 1, 1, 0.85))
	var saucer := Art.ellipse_pts(Vector2(0, 5), Vector2(25, 9), 32)
	Art.toon(ci, saucer, col, _W, 0.6)
	var on := int(floor(t * 3.0)) % 3
	for i in 3:
		Art.t_circle(ci, Vector2((i - 1) * 11.0, 6), 2.6, Color("ffe04a") if i == on else Color("8a5ad0"), 1.4, 0.0)
	Art.pop(ci)


# --- Blockers and FX colors per world --------------------------------------------------

## The block that fills a cell (ocean: sand) in this world's colors:
## [fill, dark] (volcano ash, swamp moss, moon dust).
static func block_colors(world: int) -> Array:
	match world:
		1: return [Color("8a8090"), Color("5a5262")]
		2: return [Color("7fae4a"), Color("4f7a2a")]
		3: return [Color("c8ccd8"), Color("8f95a8")]
		4: return [Color("d9bb7c"), Color("a8844a")]
	return [Art.SAND, Art.SAND_DARK]


## The bubble over a piece: [tint, rim].
static func bubble_colors(world: int) -> Array:
	match world:
		1: return [Color(1.0, 0.6, 0.3, 0.32), Color("c2501a")]
		2: return [Color(0.6, 1.0, 0.4, 0.32), Color("3f8a1a")]
		3: return [Color(0.75, 0.65, 1.0, 0.32), Color("5a3fb0")]
		4: return [Color(0.55, 1.0, 0.75, 0.22), Color("2f8a3a")]
	return [Color(0.72, 0.93, 1.0, 0.3), Color("2f7fc0")]
