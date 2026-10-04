class_name MapArt
extends RefCounted
## Drawings of the world map: one floating island per world (ocean, volcano,
## acid swamp, moon), the bridges and glowing paths between them, the boats
## and the markers. Locked islands are dark silhouettes that keep their
## telling outline (the volcano cone, the mushroom caps, the dome) with a
## big "?" and a padlock.
##
## Every island is drawn around its own origin: the middle of its flat top.
## The top is an ellipse of about RX x RY, the cliffs hang below it. The
## static part is cached as one piece (Art.cache_begin); only small things
## move (waterfalls, smoke, bubbles, boats).

const WORLDS: Array[String] = ["ocean", "volcano", "acid", "moon"]

## Island states on the map.
const DONE := 0
const CURRENT := 1
const NEXT := 2
const LOCKED := 3

const RX := 200.0
const RY := 100.0
const SIDE := 46.0
const HANG := 150.0
## Bounds of an island with everything on it (smoke, labels), for layout.
const BOUNDS := Rect2(-215, -250, 430, 540)

## Boat trip phases, the same as on the surface: it loads at the mine,
## sails, unloads at the factory and sails back.
const LOAD_END := 0.12
const SAIL_END := 0.45
const UNLOAD_END := 0.58

const SIL_FILL := Color("17112b")
const SIL_RIM := Color("3b3266")

## Colors per world: top, cliff side, underside, medium (the boat's water),
## its rim, the light of its path and the teaser rim of its silhouette.
const LOOK := {
	"ocean": {"top": Color("f8d898"), "side": Color("e3aa66"), "under": Color("4596c8"), "under2": Color("63b6dd"),
		"med": Color("43d3df"), "med_rim": Color("1c88b6"), "path": Color("8ff3ff"), "tease": Color("5fe0ff"),
		"boat": Color("ef5350"), "boat2": Color("3aa6f0")},
	"volcano": {"top": Color("62526a"), "side": Color("4a3c52"), "under": Color("392d42"), "under2": Color("4f4058"),
		"med": Color("ff8a1e"), "med_rim": Color("c2410c"), "path": Color("ffc04a"), "tease": Color("ff7a2a"),
		"boat": Color("5d6b80"), "boat2": Color("8a7aa0")},
	"acid": {"top": Color("78a84a"), "side": Color("6a5440"), "under": Color("54406a"), "under2": Color("6a5384"),
		"med": Color("a8ff3e"), "med_rim": Color("4f9a1c"), "path": Color("d4ff7a"), "tease": Color("9cff4a"),
		"boat": Color("ffb238"), "boat2": Color("ff6fae")},
	"moon": {"top": Color("d6d3e6"), "side": Color("aaa5c4"), "under": Color("858099"), "under2": Color("9a95b0"),
		"med": Color("8c87b8"), "med_rim": Color("5d5890"), "path": Color("7ff0ff"), "tease": Color("8ad8ff"),
		"boat": Color("f2f4ff"), "boat2": Color("ffd23f")},
}

## Where things stand on each island (local coordinates): the mine, the
## factory, the office, the boat's route (mine -> factory) and the level nodes.
const SPOTS := {
	"ocean": {"mine": Vector2(122, -30), "factory": Vector2(-22, -14), "office": Vector2(-112, -52),
		"boat": [Vector2(104, -24), Vector2(76, -10), Vector2(40, -8), Vector2(14, -16)],
		"nodes": [Vector2(-140, 46), Vector2(-50, 70), Vector2(42, 70), Vector2(128, 50)]},
	"volcano": {"mine": Vector2(-118, -8), "factory": Vector2(118, -6), "office": Vector2(150, -52),
		"boat": [Vector2(-92, 8), Vector2(-40, 18), Vector2(20, 16), Vector2(88, 10)],
		"nodes": [Vector2(-140, 50), Vector2(-50, 72), Vector2(42, 72), Vector2(130, 52)]},
	"acid": {"mine": Vector2(-122, -10), "factory": Vector2(116, -10), "office": Vector2(20, -64),
		"boat": [Vector2(-94, 8), Vector2(-40, 20), Vector2(24, 18), Vector2(84, 8)],
		"nodes": [Vector2(-140, 50), Vector2(-50, 72), Vector2(42, 72), Vector2(130, 52)]},
	"moon": {"mine": Vector2(-126, -6), "factory": Vector2(118, -14), "office": Vector2(-30, -62),
		"boat": [Vector2(-98, 12), Vector2(-40, 22), Vector2(26, 20), Vector2(86, 6)],
		"nodes": [Vector2(-140, 50), Vector2(-50, 72), Vector2(42, 72), Vector2(130, 52)]},
}

## Small hue turn for the repeats (tier 1+), so a second ocean looks new.
static var _shift := 0.0
## Reduce motion: the view sets it, the moving bits then hold still.
static var still := false
static var _tops := {}
static var _sil := {}


static func world_of(location: int) -> String:
	return WORLDS[posmod(location, WORLDS.size())]


static func spots(world: String) -> Dictionary:
	return SPOTS.get(world, SPOTS["ocean"])


static func look(world: String) -> Dictionary:
	return LOOK.get(world, LOOK["ocean"])


static func _c(col: Color) -> Color:
	if _shift == 0.0:
		return col
	var h := col.h
	return Color.from_hsv(fposmod(h + _shift, 1.0), col.s, col.v, col.a)


# --- Island body -------------------------------------------------------------------------

static func top_pts(world: String) -> PackedVector2Array:
	if _tops.has(world):
		return _tops[world]
	var seed := float(WORLDS.find(world)) * 1.7 + 0.5
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var r := 1.0 + 0.035 * sin(3.0 * a + seed) + 0.025 * sin(7.0 * a + seed * 2.3)
		pts.append(Vector2(cos(a) * RX * r, sin(a) * RY * r))
	_tops[world] = pts
	return pts


## The cliff band under the front edge of the top.
static func _side_pts(top: PackedVector2Array) -> PackedVector2Array:
	var half := top.size() / 2
	var pts := PackedVector2Array()
	for i in half + 1:
		pts.append(top[i])
	for i in range(half, -1, -1):
		pts.append(top[i] + Vector2(0, SIDE))
	return pts


## The chunky rock hanging under the island, made of blocks like the concept.
static func _under_pts(top: PackedVector2Array, seed: int) -> PackedVector2Array:
	var half := top.size() / 2
	var pts := PackedVector2Array()
	for i in half + 1:
		pts.append(top[i] + Vector2(0, SIDE - 3))
	var x0 := top[half].x + 10.0
	var x1 := top[0].x - 10.0
	var steps := 11
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in steps:
		var xa := lerpf(x0, x1, float(k) / steps)
		var xb := lerpf(x0, x1, float(k + 1) / steps)
		var xm := ((xa + xb) / 2.0) / x1
		var d := SIDE + 34.0 + HANG * pow(maxf(0.0, 1.0 - xm * xm), 1.3) * rng.randf_range(0.78, 1.08)
		pts.append(Vector2(xa + 1.5, d))
		pts.append(Vector2(xb - 1.5, d))
	return pts


## Block seams on the underside (x of each block edge and its depth).
static func _seams(ci: CanvasItem, under: PackedVector2Array, col: Color) -> void:
	var half := 25
	for i in range(half + 1, under.size() - 1, 2):
		var a := under[i]
		var b := under[i + 1]
		var x := b.x + 1.5
		Art.line_c(ci, PackedVector2Array([Vector2(x, SIDE + 18), Vector2(x, maxf(b.y, under[mini(i + 2, under.size() - 1)].y) - 8)]), col, 2.5)
		Art.line_c(ci, PackedVector2Array([Vector2(a.x + 6, SIDE + 46 + float(i % 3) * 22), Vector2(b.x - 6, SIDE + 46 + float(i % 3) * 22)]), col, 2.0)


static func _body(ci: CanvasItem, world: String, seed: int) -> void:
	var lk := look(world)
	var top := top_pts(world)
	var under := _under_pts(top, seed)
	Art.toon(ci, under, _c(lk["under"]), 3.5, 1.0)
	_seams(ci, under, Art.shade_of(_c(lk["under"]), 0.35))
	# Lighter block faces on the underside.
	for i in range(26, under.size() - 1, 4):
		var a := under[i]
		var b := under[i + 1]
		Art.flat(ci, Art.rrect_pts(Rect2(a.x + 5, SIDE + 10, b.x - a.x - 10, (a.y - SIDE) * 0.45), 4), Color(_c(lk["under2"]), 0.6))
	var side := _side_pts(top)
	Art.toon(ci, side, _c(lk["side"]), 3.5, 0.8)
	for i in range(2, 24, 3):
		var p := top[i]
		Art.line_c(ci, PackedVector2Array([p + Vector2(0, 8), p + Vector2(0, SIDE - 6)]), Art.shade_of(_c(lk["side"]), 0.3), 2.5)
	Art.toon(ci, top, _c(lk["top"]), 3.5, 0.5)


## A few rocks floating around the island.
static func _debris(ci: CanvasItem, col: Color, spots_list: Array, rim: float = 2.5) -> void:
	for d in spots_list:
		var c: Vector2 = d[0]
		var s: float = d[1]
		var pts := PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(-s * 0.3, -s), c + Vector2(s * 0.8, -s * 0.7),
				c + Vector2(s, s * 0.2), c + Vector2(s * 0.2, s), c + Vector2(-s * 0.8, s * 0.6)])
		Art.toon(ci, pts, col, rim, 0.8)


const DEBRIS := [[Vector2(-212, 96), 13.0], [Vector2(214, 120), 10.0], [Vector2(-170, 210), 9.0], [Vector2(186, 220), 12.0]]


# --- Small props ----------------------------------------------------------------------------

static func _palm(ci: CanvasItem, base: Vector2, h: float, lean: float) -> void:
	var trunk := PackedVector2Array()
	for i in 6:
		var f := i / 5.0
		trunk.append(base + Vector2(lean * h * f * f, -h * f))
	Art.stroke(ci, trunk, Color("b67a42"), 7.0, 2.5)
	for i in range(1, 5):
		var p := trunk[i]
		Art.line_c(ci, PackedVector2Array([p + Vector2(-3.5, 0), p + Vector2(3.5, -1)]), Color("8e552c"), 1.8)
	var top := trunk[5]
	for k in 6:
		var a := -PI / 2.0 + (k - 2.5) * 0.62
		var dir := Vector2(cos(a), sin(a))
		var nrm := dir.orthogonal()
		var len := h * 0.62
		var droop := Vector2(0, len * 0.45 * absf(dir.x))
		var leaf := Art.smooth_pts(PackedVector2Array([top, top + dir * len * 0.5 + nrm * 8.0 + droop * 0.4,
				top + dir * len + droop, top + dir * len * 0.5 - nrm * 4.0 + droop * 0.5]), 4)
		Art.toon(ci, leaf, Color("4cc35a") if k % 2 == 0 else Color("6fdc5c"), 2.5, 0.5)
	Art.t_circle(ci, top + Vector2(-4, 4), 4.5, Color("8a5a2c"), 2.0, 0.3)
	Art.t_circle(ci, top + Vector2(4, 5), 4.5, Color("8a5a2c"), 2.0, 0.3)


static func _bush(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var pts := Art.union([Art.circle_pts(at + Vector2(-s * 0.6, 0), s * 0.7, 14), Art.circle_pts(at + Vector2(0, -s * 0.4), s * 0.85, 16),
			Art.circle_pts(at + Vector2(s * 0.65, 0), s * 0.65, 14)])
	Art.toon(ci, pts, col, 2.5, 0.7)


static func _coral(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	Art.stroke(ci, PackedVector2Array([base, base + Vector2(0, -s)]), col, s * 0.28, 2.0)
	Art.stroke(ci, PackedVector2Array([base + Vector2(0, -s * 0.4), base + Vector2(-s * 0.45, -s * 0.8)]), col, s * 0.22, 2.0)
	Art.stroke(ci, PackedVector2Array([base + Vector2(0, -s * 0.55), base + Vector2(s * 0.42, -s * 0.95)]), col, s * 0.22, 2.0)


static func _star_badge(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	Art.toon(ci, Art.star_pts(at, r, r * 0.46, 5), col, 2.2, 0.5)


## Little house with a star over the door: the office.
static func _house(ci: CanvasItem, at: Vector2, s: float, wall: Color, roof: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(-27, -32, 54, 32), 4, wall, 3.0, 0.7)
	for i in 3:
		Art.line_c(ci, PackedVector2Array([Vector2(-25, -24 + i * 8), Vector2(25, -24 + i * 8)]), Art.shade_of(wall, 0.25), 1.6)
	Art.toon(ci, PackedVector2Array([Vector2(-36, -28), Vector2(0, -60), Vector2(36, -28), Vector2(30, -24), Vector2(-30, -24)]), roof, 3.0, 0.8)
	Art.t_rect(ci, Rect2(-8, -20, 16, 20), 6, Color("5a3a26"), 2.5, 0.0)
	_star_badge(ci, Vector2(0, -36), 8.5, Art.GOLD)
	Art.t_rect(ci, Rect2(13, -24, 10, 10), 2, Art.GLASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-23, -24, 10, 10), 2, Art.GLASS, 2.0, 0.0)
	Art.pop(ci)


## Wooden hut on stilts with a pier: the ocean's office.
static func _hut(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(-34, -4, 68, 9), 3, Art.WOOD, 2.5, 0.5)
	Art.t_rect(ci, Rect2(-27, -36, 54, 34), 4, Color("d9965a"), 3.0, 0.7)
	for i in 4:
		Art.line_c(ci, PackedVector2Array([Vector2(-27 + 13.5 * (i + 0.5), -34), Vector2(-27 + 13.5 * (i + 0.5), -4)]), Color("a96a3a"), 1.6)
	Art.toon(ci, PackedVector2Array([Vector2(-38, -30), Vector2(-20, -60), Vector2(20, -60), Vector2(38, -30), Vector2(30, -26), Vector2(-30, -26)]), Color("e8b65a"), 3.0, 0.8)
	for i in 5:
		Art.line_c(ci, PackedVector2Array([Vector2(-26 + i * 13, -58), Vector2(-32 + i * 16, -30)]), Color("c48a32"), 1.6)
	Art.t_rect(ci, Rect2(-8, -24, 16, 22), 6, Color("6a3e22"), 2.5, 0.0)
	_star_badge(ci, Vector2(0, -42), 9.0, Art.GOLD)
	Art.pop(ci)


## Hall with a sawtooth roof and a chimney: the factory.
static func _factory(ci: CanvasItem, at: Vector2, s: float, wall: Color, roof: Color, trim: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(16, -62, 12, 40), 2, trim, 2.5, 0.6)
	Art.t_rect(ci, Rect2(14, -64, 16, 6), 2, Art.shade_of(trim, 0.3), 2.0, 0.0)
	for k in 3:
		var x := -32.0 + k * 20.0
		Art.toon(ci, PackedVector2Array([Vector2(x, -30), Vector2(x, -46), Vector2(x + 20, -30)]), roof, 2.5, 0.6)
	Art.t_rect(ci, Rect2(-32, -32, 64, 32), 3, wall, 3.0, 0.7)
	Art.t_rect(ci, Rect2(-26, -25, 12, 9), 2, Art.GLASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(14, -25, 12, 9), 2, Art.GLASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-8, -18, 16, 18), 3, Art.shade_of(trim, 0.4), 2.5, 0.0)
	Art.gear(ci, Vector2(0, -24), 6.5, Art.GOLD, 0.2, 8)
	Art.pop(ci)


## Glass-domed lab with a flask sign: the acid world's factory.
static func _lab(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(22, -58, 9, 34), 2, Color("8a94a8"), 2.5, 0.5)
	Art.t_circle(ci, Vector2(-2, -32), 26, Color(0.75, 1.0, 0.6, 0.85), 3.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(-12, -42), Vector2(6, 9), 14, 0.5), Color(1, 1, 1, 0.55))
	# Flask inside the dome.
	Art.toon(ci, PackedVector2Array([Vector2(-6, -48), Vector2(2, -48), Vector2(2, -40), Vector2(10, -24), Vector2(-14, -24), Vector2(-6, -40)]), Color("b6ff5a"), 2.2, 0.4)
	Art.t_rect(ci, Rect2(-36, -24, 72, 24), 4, Color("e7ecf5"), 3.0, 0.7)
	Art.t_rect(ci, Rect2(-36, -26, 72, 7), 3, Color("7cc84a"), 2.5, 0.0)
	Art.t_rect(ci, Rect2(-7, -16, 14, 16), 3, Color("4a5368"), 2.5, 0.0)
	Art.t_rect(ci, Rect2(14, -17, 12, 8), 2, Art.GLASS, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-28, -17, 12, 8), 2, Art.GLASS, 2.0, 0.0)
	Art.pop(ci)


## Round hangar with a dish: the moon's factory.
static func _hangar(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.stroke(ci, PackedVector2Array([Vector2(22, -30), Vector2(22, -58)]), Color("9aa3bd"), 3.0, 2.0)
	Art.toon(ci, Art.ellipse_pts(Vector2(26, -62), Vector2(13, 6), 16, -0.5), Color("eef2ff"), 2.5, 0.5)
	Art.t_circle(ci, Vector2(30, -66), 2.5, Art.RED, 1.5, 0.0)
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(Vector2(cos(a) * 36, sin(a) * 34))
	Art.toon(ci, dome, Color("c9d2e6"), 3.0, 0.8)
	for i in 3:
		var x := -18.0 + i * 18.0
		Art.line_c(ci, PackedVector2Array([Vector2(x, -sqrt(maxf(0.0, 1.0 - x * x / 1296.0)) * 32), Vector2(x, -2)]), Color("97a2bd"), 2.0)
	Art.t_rect(ci, Rect2(-12, -20, 24, 20), 8, Color("3e4660"), 2.5, 0.0)
	Art.t_rect(ci, Rect2(-36, -6, 72, 6), 2, Art.GOLD, 2.5, 0.0)
	Art.pop(ci)


## Dome observatory with a telescope: the moon's office.
static func _observatory(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	# Telescope first, the dome covers its foot.
	Art.push(ci, Vector2(8, -50), -0.75)
	Art.t_rect(ci, Rect2(-8, -44, 16, 46), 5, Color("dfe6ff"), 3.0, 0.6)
	Art.t_rect(ci, Rect2(-10, -48, 20, 9), 3, Color("5fd0ff"), 2.5, 0.0)
	Art.pop(ci)
	Art.t_rect(ci, Rect2(-36, -30, 72, 30), 4, Color("e9edfa"), 3.0, 0.7)
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(Vector2(cos(a) * 32, -28 + sin(a) * 30))
	Art.toon(ci, dome, Color("f7f9ff"), 3.0, 0.8)
	Art.toon(ci, PackedVector2Array([Vector2(-4, -57), Vector2(8, -57), Vector2(8, -30), Vector2(-4, -30)]), Color("4a5578"), 2.0, 0.0)
	Art.t_rect(ci, Rect2(-10, -24, 20, 24), 8, Art.GOLD, 2.5, 0.0)
	Art.t_rect(ci, Rect2(14, -22, 12, 10), 3, Color("5fd0ff"), 2.0, 0.0)
	Art.t_rect(ci, Rect2(-26, -22, 12, 10), 3, Color("5fd0ff"), 2.0, 0.0)
	_star_badge(ci, Vector2(0, -40), 7.0, Art.GOLD)
	Art.pop(ci)


## Raft with a little crane over the dive spot: the ocean's mine.
static func _raft(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_ellipse(ci, Vector2(0, 2), Vector2(30, 9), Color(0.1, 0.35, 0.55, 0.0), 0.0, 0.0)
	Art.t_rect(ci, Rect2(-30, -8, 60, 14), 4, Art.WOOD, 3.0, 0.6)
	for i in 4:
		Art.line_c(ci, PackedVector2Array([Vector2(-30 + 12 * (i + 1), -7), Vector2(-30 + 12 * (i + 1), 5)]), Art.WOOD_DARK, 1.6)
	Art.stroke(ci, PackedVector2Array([Vector2(-16, -8), Vector2(-4, -50)]), Art.WOOD_DARK, 4.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(8, -8), Vector2(-4, -50)]), Art.WOOD_DARK, 4.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(-8, -46), Vector2(26, -42)]), Art.GOLD_DARK, 4.0, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(24, -42), Vector2(24, -14)]), Art.INK, 2.0)
	Art.t_rect(ci, Rect2(17, -16, 14, 10), 2, Art.WOOD, 2.2, 0.0)
	Art.crystals(ci, Vector2(-14, -8), 16, {"ore": Color("ffc6d6"), "ore2": Color("ff8fb0")}, 3, 3)
	Art.pop(ci)


## Mine door in a rock face with rails and an ore cart.
static func _mine(ci: CanvasItem, at: Vector2, s: float, rock: Color, ore: Color, ore2: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	var mound := Art.union([Art.ellipse_pts(Vector2(0, -20), Vector2(40, 30), 22), Art.ellipse_pts(Vector2(-22, -6), Vector2(24, 16), 16),
			Art.ellipse_pts(Vector2(24, -8), Vector2(22, 16), 16)])
	Art.toon(ci, mound, rock, 3.0, 0.9)
	Art.t_rect(ci, Rect2(-14, -34, 28, 34), 10, Color("1a1226"), 0.0, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-16, -36)]), Art.WOOD, 5.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(16, 0), Vector2(16, -36)]), Art.WOOD, 5.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(-21, -37), Vector2(21, -37)]), Art.WOOD, 6.0, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-8, 0), Vector2(-14, 16)]), Art.INK, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(8, 0), Vector2(16, 16)]), Art.INK, 2.0)
	# Cart with ore.
	Art.push(ci, Vector2(22, 10))
	Art.crystals(ci, Vector2(0, -10), 15, {"ore": ore, "ore2": ore2}, 5, 3)
	Art.toon(ci, PackedVector2Array([Vector2(-13, -12), Vector2(13, -12), Vector2(10, 0), Vector2(-10, 0)]), Color("7a8496"), 2.5, 0.6)
	Art.t_circle(ci, Vector2(-6, 1), 3.5, Art.INK, 0.0, 0.0)
	Art.t_circle(ci, Vector2(6, 1), 3.5, Art.INK, 0.0, 0.0)
	Art.pop(ci)
	Art.t_circle(ci, Vector2(-20, -28), 3.5, Art.GOLD, 2.0, 0.0)
	Art.pop(ci)


## Drill tower over a crater: the moon's mine.
static func _rig(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.toon(ci, Art.ellipse_pts(Vector2(0, 0), Vector2(36, 13), 22), Color("8e89a8"), 3.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 2), Vector2(28, 9), 20), Color("5d587a"))
	Art.stroke(ci, PackedVector2Array([Vector2(-16, 2), Vector2(-4, -54)]), Color("b8c2da"), 4.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(16, 2), Vector2(4, -54)]), Color("b8c2da"), 4.0, 2.0)
	for i in 3:
		var y := -12.0 - i * 14.0
		var w := 13.0 - i * 3.2
		Art.line_c(ci, PackedVector2Array([Vector2(-w, y), Vector2(w, y - 8)]), Color("7c87a5"), 2.0)
	Art.t_rect(ci, Rect2(-7, -62, 14, 10), 3, Art.GOLD, 2.5, 0.0)
	Art.crystals(ci, Vector2(26, 4), 16, {"ore": Color("6fe8ff"), "ore2": Color("c08cff")}, 7, 3)
	Art.pop(ci)


static func _mushroom(ci: CanvasItem, base: Vector2, h: float, w: float, cap: Color) -> void:
	var stem := PackedVector2Array([base + Vector2(-w * 0.16, 0), base + Vector2(-w * 0.11, -h), base + Vector2(w * 0.11, -h), base + Vector2(w * 0.16, 0)])
	Art.toon(ci, stem, Color("f3e6c8"), 3.0, 0.6)
	var cap_pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap_pts.append(base + Vector2(cos(a) * w * 0.5, -h + 6 + sin(a) * w * 0.42))
	cap_pts.append(base + Vector2(w * 0.4, -h + 10))
	cap_pts.append(base + Vector2(-w * 0.4, -h + 10))
	Art.toon(ci, cap_pts, cap, 3.0, 0.8)
	for d in [Vector2(-0.22, -0.18), Vector2(0.12, -0.3), Vector2(0.3, -0.08), Vector2(-0.05, -0.05)]:
		Art.t_ellipse(ci, base + Vector2(d.x * w, -h + d.y * w), Vector2(w * 0.07, w * 0.05), Color("fff6e4"), 0.0, 0.0)


static func _crater(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	Art.toon(ci, Art.ellipse_pts(at, Vector2(r, r * 0.45), 18), Art.shade_of(col, 0.18), 2.2, 0.0)
	Art.flat(ci, Art.ellipse_pts(at + Vector2(0, r * 0.08), Vector2(r * 0.78, r * 0.3), 16), Art.shade_of(col, 0.32))


## Pool or river of the world's medium (water, lava, acid, moon dust).
static func _medium(ci: CanvasItem, world: String, blobs: Array) -> void:
	var lk := look(world)
	var polys := []
	for b in blobs:
		polys.append(Art.ellipse_pts(b[0], b[1], 22))
	var pts := Art.union(polys)
	Art.toon(ci, pts, _c(lk["med"]), 3.0, 0.0, Art.shade_of(_c(lk["med_rim"]), 0.3))
	var inner := Geometry2D.offset_polygon(pts, -7.0, Geometry2D.JOIN_ROUND)
	if inner.size() > 0:
		Art.flat(ci, inner[0], _c(lk["med"]).lightened(0.18))


# --- Worlds ---------------------------------------------------------------------------------

static func _ocean(ci: CanvasItem) -> void:
	_body(ci, "ocean", 11)
	var lk := look("ocean")
	# Corals and starfish on the hanging blocks.
	_coral(ci, Vector2(-120, 120), 22, Color("ff7ab0"))
	_coral(ci, Vector2(-40, 168), 26, Color("b07cff"))
	_coral(ci, Vector2(60, 156), 22, Color("ff9a5a"))
	_coral(ci, Vector2(118, 112), 18, Color("ff7ab0"))
	_star_badge(ci, Vector2(-80, 140), 8, Color("ff8a3d"))
	_star_badge(ci, Vector2(20, 205), 7, Color("ffd23f"))
	# Waterfall off the right edge.
	Art.flat(ci, PackedVector2Array([Vector2(160, 30), Vector2(190, 18), Vector2(194, 210), Vector2(166, 230)]), Color(0.62, 0.93, 1.0, 0.85))
	Art.flat(ci, PackedVector2Array([Vector2(170, 30), Vector2(180, 26), Vector2(184, 220), Vector2(174, 224)]), Color(1, 1, 1, 0.5))
	# Grass hill, lagoon.
	var hill := Art.union([Art.ellipse_pts(Vector2(-102, -40), Vector2(84, 44), 24), Art.ellipse_pts(Vector2(-160, -10), Vector2(36, 28), 16)])
	Art.toon(ci, hill, Color("7ad65e"), 3.0, 0.7)
	_medium(ci, "ocean", [[Vector2(66, -20), Vector2(98, 40)], [Vector2(150, 8), Vector2(42, 24)], [Vector2(178, 22), Vector2(16, 12)]])
	Art.flat(ci, Art.ellipse_pts(Vector2(60, -14), Vector2(30, 7), 14), Color(1, 1, 1, 0.35))
	# Pier from the factory into the lagoon.
	Art.t_rect(ci, Rect2(-6, -22, 30, 8), 2, Art.WOOD, 2.2, 0.0)
	_palm(ci, Vector2(-170, -16), 64, -0.35)
	_palm(ci, Vector2(-46, -70), 58, 0.25)
	_palm(ci, Vector2(160, -50), 60, 0.3)
	_bush(ci, Vector2(-150, 22), 13, Color("5cc84f"))
	_hut(ci, spots("ocean")["office"], 0.95)
	_factory(ci, spots("ocean")["factory"], 0.85, Color("fff6e4"), Art.RED, Color("ff8a3d"))
	_raft(ci, spots("ocean")["mine"], 0.8)
	Art.t_ellipse(ci, Vector2(-180, 40), Vector2(9, 5), Color("ffc6d6"), 2.0, 0.4)
	_star_badge(ci, Vector2(90, 52), 7, Color("ff8a3d"))
	_debris(ci, _c(lk["under"]), DEBRIS)


static func _volcano(ci: CanvasItem) -> void:
	_body(ci, "volcano", 23)
	var lk := look("volcano")
	var lava := _c(lk["med"])
	var hot := Color("ffd23f")
	# Lavafall from the bottom tip.
	Art.toon(ci, PackedVector2Array([Vector2(-14, 150), Vector2(10, 150), Vector2(14, 290), Vector2(-10, 290)]), lava, 2.5, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-4, 152), Vector2(3, 152), Vector2(5, 288), Vector2(-2, 288)]), hot)
	# Glowing cracks on the underside.
	for c in [[Vector2(-120, 80), Vector2(-104, 116), Vector2(-112, 140)], [Vector2(90, 76), Vector2(104, 110)], [Vector2(-30, 90), Vector2(-40, 130), Vector2(-26, 170)]]:
		Art.line_c(ci, PackedVector2Array(c), lava, 4.0)
	# The cone.
	var cone := PackedVector2Array([Vector2(-108, -8), Vector2(-86, -46), Vector2(-62, -88), Vector2(-46, -132), Vector2(-26, -168),
			Vector2(30, -172), Vector2(48, -128), Vector2(74, -86), Vector2(96, -44), Vector2(116, -6)])
	Art.toon(ci, cone, _c(Color("57475f")), 3.5, 0.9)
	for r in [[Vector2(-70, -50), Vector2(-40, -110)], [Vector2(70, -48), Vector2(40, -120)], [Vector2(-10, -40), Vector2(0, -130)]]:
		Art.line_c(ci, PackedVector2Array(r), _c(Color("463850")), 3.0)
	# Crater and its lava flows.
	Art.toon(ci, Art.ellipse_pts(Vector2(2, -170), Vector2(30, 9), 18), lava, 3.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(2, -170), Vector2(20, 5), 14), hot)
	for f in [[Vector2(-14, -166), Vector2(-30, -120), Vector2(-24, -80), Vector2(-48, -30)], [Vector2(16, -166), Vector2(34, -116), Vector2(56, -60), Vector2(50, -14)]]:
		Art.stroke(ci, PackedVector2Array(f), lava, 9.0, 2.0)
		Art.line_c(ci, PackedVector2Array(f), hot, 3.0)
	# Smoke plume.
	var smoke := Art.union([Art.circle_pts(Vector2(-6, -194), 22, 18), Art.circle_pts(Vector2(20, -206), 20, 18),
			Art.circle_pts(Vector2(-26, -214), 18, 16), Art.circle_pts(Vector2(4, -228), 20, 18)])
	Art.toon(ci, smoke, Color("736a80"), 3.0, 0.6)
	# Lava river for the boat.
	_medium(ci, "volcano", [[Vector2(-80, 12), Vector2(44, 15)], [Vector2(-10, 20), Vector2(56, 15)], [Vector2(70, 12), Vector2(46, 14)]])
	Art.line_c(ci, PackedVector2Array([Vector2(-110, 12), Vector2(-40, 20), Vector2(30, 18), Vector2(100, 10)]), hot, 2.5)
	_mine(ci, spots("volcano")["mine"], 0.95, _c(Color("4d3e55")), Color("ff6a1a"), Color("ffd05a"))
	_factory(ci, spots("volcano")["factory"], 0.85, _c(Color("8a7a92")), _c(Color("c2410c")), Color("5a5068"))
	_house(ci, spots("volcano")["office"], 0.75, _c(Color("9a8a9e")), Color("e05a2a"))
	for c in [Vector2(-170, 30), Vector2(160, 40), Vector2(-60, 60)]:
		Art.crystal(ci, c, 18, 6, 0.2, Color("ff8a3d"))
	_debris(ci, _c(lk["under"]), DEBRIS)


static func _acid(ci: CanvasItem) -> void:
	_body(ci, "acid", 37)
	var lk := look("acid")
	# Slime drips off the edge.
	for d in [[Vector2(-150, 50), 70.0], [Vector2(40, 98), 110.0], [Vector2(150, 54), 60.0]]:
		var p: Vector2 = d[0]
		var l: float = d[1]
		Art.stroke(ci, PackedVector2Array([p, p + Vector2(0, l)]), _c(lk["med"]), 7.0, 2.0)
		Art.t_circle(ci, p + Vector2(0, l + 6), 6, _c(lk["med"]), 2.0, 0.3)
	_mushroom(ci, Vector2(-120, -46), 100, 96, _c(Color("ff5a8a")))
	_mushroom(ci, Vector2(-40, -80), 140, 120, _c(Color("b06cff")))
	_mushroom(ci, Vector2(150, -40), 84, 80, _c(Color("ff8a3d")))
	_mushroom(ci, Vector2(80, -84), 60, 56, _c(Color("ff5a8a")))
	# Acid swamp for the boat.
	_medium(ci, "acid", [[Vector2(-80, 12), Vector2(46, 16)], [Vector2(-8, 22), Vector2(58, 17)], [Vector2(66, 12), Vector2(44, 15)]])
	for b in [Vector2(-60, 10), Vector2(10, 22), Vector2(56, 10)]:
		Art.t_circle(ci, b, 4, Color("e6ffb0"), 1.8, 0.0)
	_mine(ci, spots("acid")["mine"], 0.95, _c(Color("5a7a3e")), Color("a8ff3e"), Color("f0ff9a"))
	_lab(ci, spots("acid")["factory"], 0.95)
	# Office: a little mushroom house.
	var o: Vector2 = spots("acid")["office"]
	Art.t_rect(ci, Rect2(o + Vector2(-20, -28), Vector2(40, 28)), 6, Color("fff1d0"), 3.0, 0.6)
	_mushroom(ci, o + Vector2(0, -6), 26, 74, _c(Color("ef5350")))
	Art.t_rect(ci, Rect2(o + Vector2(-6, -16), Vector2(12, 16)), 5, Color("6a3e22"), 2.2, 0.0)
	_star_badge(ci, o + Vector2(0, -23), 5.5, Art.GOLD)
	for r in [Vector2(-176, 20), Vector2(176, 18), Vector2(100, 46)]:
		for k in 3:
			Art.stroke(ci, PackedVector2Array([r + Vector2(k * 5, 0), r + Vector2(k * 5 + (k - 1) * 3, -16 - k * 3)]), Color("4f9a1c"), 2.5, 1.5)
	_debris(ci, _c(lk["under"]), DEBRIS)


static func _moon(ci: CanvasItem) -> void:
	_body(ci, "moon", 41)
	var lk := look("moon")
	for c in [[Vector2(-120, 110), 16.0], [Vector2(-20, 170), 14.0], [Vector2(80, 120), 18.0], [Vector2(20, 90), 11.0]]:
		Art.t_circle(ci, c[0], c[1], Art.shade_of(_c(lk["under"]), 0.25), 2.2, 0.0)
	for c in [[Vector2(-150, -40), 22.0], [Vector2(60, -70), 16.0], [Vector2(150, 30), 18.0], [Vector2(-60, 56), 14.0], [Vector2(170, -30), 10.0]]:
		_crater(ci, c[0], c[1], _c(lk["top"]))
	_medium(ci, "moon", [[Vector2(-80, 14), Vector2(46, 15)], [Vector2(-8, 22), Vector2(60, 16)], [Vector2(66, 12), Vector2(46, 15)]])
	for c in [[Vector2(-180, 30), 0.3, Color("6fe8ff")], [Vector2(-168, 34), -0.2, Color("c08cff")], [Vector2(178, 40), -0.3, Color("c08cff")],
			[Vector2(110, -84), 0.2, Color("6fe8ff")]]:
		Art.crystal(ci, c[0], 26, 8, c[1], c[2])
	_observatory(ci, spots("moon")["office"], 1.0)
	_hangar(ci, spots("moon")["factory"], 0.9)
	_rig(ci, spots("moon")["mine"], 0.9)
	_debris(ci, _c(lk["under"]), DEBRIS)


# --- Silhouettes ----------------------------------------------------------------------------

## The shapes whose outline tells what the locked island is.
static func sil_polys(world: String) -> Array:
	if _sil.has(world):
		return _sil[world]
	var top := top_pts(world)
	var polys := [_under_pts(top, 7), _side_pts(top), top]
	match world:
		"ocean":
			for p in [Vector2(-170, -80), Vector2(-46, -128), Vector2(176, -110)]:
				polys.append(Art.union([Art.ellipse_pts(p, Vector2(34, 14), 16), Art.ellipse_pts(p + Vector2(-20, 10), Vector2(18, 12), 12),
						Art.ellipse_pts(p + Vector2(20, 10), Vector2(18, 12), 12)]))
				polys.append(Art.rrect_pts(Rect2(p + Vector2(-4, 0), Vector2(8, 70)), 3))
			polys.append(PackedVector2Array([Vector2(-150, -60), Vector2(-132, -112), Vector2(-92, -112), Vector2(-74, -60)]))
		"volcano":
			polys.append(PackedVector2Array([Vector2(-108, -8), Vector2(-62, -88), Vector2(-26, -168), Vector2(30, -172), Vector2(74, -86), Vector2(116, -6)]))
			for c in [[Vector2(-6, -194), 24.0], [Vector2(20, -206), 22.0], [Vector2(-26, -214), 20.0], [Vector2(4, -230), 22.0]]:
				polys.append(Art.circle_pts(c[0], c[1], 18))
		"acid":
			for m in [[Vector2(-120, -46), 100.0, 96.0], [Vector2(-40, -80), 140.0, 120.0], [Vector2(150, -40), 84.0, 80.0], [Vector2(80, -84), 60.0, 56.0]]:
				var b: Vector2 = m[0]
				var h: float = m[1]
				var w: float = m[2]
				var cap := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					cap.append(b + Vector2(cos(a) * w * 0.5, -h + 6 + sin(a) * w * 0.42))
				cap.append(b + Vector2(w * 0.4, -h + 10))
				cap.append(b + Vector2(-w * 0.4, -h + 10))
				polys.append(cap)
				polys.append(PackedVector2Array([b + Vector2(-w * 0.16, 4), b + Vector2(-w * 0.11, -h + 4), b + Vector2(w * 0.11, -h + 4), b + Vector2(w * 0.16, 4)]))
		"moon":
			var o: Vector2 = spots("moon")["office"]
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(o + Vector2(cos(a) * 34, -28 + sin(a) * 32))
			dome.append(o + Vector2(38, 2))
			dome.append(o + Vector2(-38, 2))
			polys.append(dome)
			var tube := PackedVector2Array()
			for p in [Vector2(-10, -48), Vector2(10, -48), Vector2(10, 4), Vector2(-10, 4)]:
				tube.append(o + Vector2(8, -50) + p.rotated(-0.75))
			polys.append(tube)
			var f: Vector2 = spots("moon")["factory"]
			polys.append(PackedVector2Array([f + Vector2(-34, 0), f + Vector2(-30, -22), f + Vector2(0, -32), f + Vector2(30, -22), f + Vector2(34, 0)]))
			polys.append(PackedVector2Array([f + Vector2(16, -20), f + Vector2(18, -54), f + Vector2(38, -66), f + Vector2(26, -50), f + Vector2(24, -20)]))
			for c in [[Vector2(-180, 30), 0.3], [Vector2(178, 40), -0.3], [Vector2(110, -84), 0.2]]:
				var bb: Vector2 = c[0]
				var up := Vector2(0, -1).rotated(c[1])
				var rt := Vector2(1, 0).rotated(c[1])
				polys.append(PackedVector2Array([bb - rt * 10 + up * -2, bb - rt * 10 + up * 20, bb + up * 30, bb + rt * 10 + up * 20, bb + rt * 10 + up * -2]))
	for d in DEBRIS:
		var c: Vector2 = d[0]
		var s: float = d[1]
		polys.append(PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(-s * 0.3, -s), c + Vector2(s * 0.8, -s * 0.7),
				c + Vector2(s, s * 0.2), c + Vector2(s * 0.2, s), c + Vector2(-s * 0.8, s * 0.6)]))
	_sil[world] = polys
	return polys


## Dark silhouette: one rim pass under all the shapes, then the fill, so the
## overlaps read as one outline.
static func _silhouette(ci: CanvasItem, world: String, rim: Color) -> void:
	var polys := sil_polys(world)
	for p in polys:
		var g := Geometry2D.offset_polygon(p, 4.0, Geometry2D.JOIN_ROUND)
		if g.size() > 0:
			Art.flat(ci, g[0], rim)
	for p in polys:
		Art.flat(ci, p, SIL_FILL)
	# A soft inner light along the top edge.
	var top := top_pts(world)
	var arc := PackedVector2Array()
	for i in range(28, 45):
		arc.append(top[i] * 0.94)
	Art.line_c(ci, arc, Color(rim, 0.35), 3.0)


# --- Public drawing -----------------------------------------------------------------------

## One island at the current origin. state: DONE, CURRENT, NEXT or LOCKED.
## lit_nodes: how many level nodes glow (current island).
static func island(ci: CanvasItem, world: String, state: int, t: float, tier: int = 0) -> void:
	var dark := state == NEXT or state == LOCKED
	_shift = 0.0 if tier <= 0 else 0.07 * float(tier)
	var key := hash(["isl", world, dark, state == NEXT, tier])
	if not Art.cache_begin(ci, key):
		if dark:
			var rim := SIL_RIM if state == LOCKED else Color(look(world)["tease"], 0.75).lerp(SIL_RIM, 0.35)
			_silhouette(ci, world, rim)
		else:
			match world:
				"volcano": _volcano(ci)
				"acid": _acid(ci)
				"moon": _moon(ci)
				_: _ocean(ci)
		Art.cache_end(ci, key)
	if not dark:
		_fx(ci, world, t)
	_shift = 0.0


static func nodes(ci: CanvasItem, world: String, lit: int) -> void:
	var lk := look(world)
	var i := 0
	for p: Vector2 in spots(world)["nodes"]:
		var on := i < lit
		Art.toon(ci, Art.ellipse_pts(p + Vector2(0, 5), Vector2(17, 7), 18), Color("6a7390") if not on else Art.GOLD_DARK, 2.5, 0.0)
		Art.toon(ci, Art.ellipse_pts(p, Vector2(17, 7), 18), Color("aeb6cc") if not on else Art.GOLD, 2.5, 0.0)
		Art.flat(ci, Art.ellipse_pts(p, Vector2(9, 3.5), 14), Color(lk["path"], 0.9) if on else Color("8a93ab"))
		i += 1


## Moving bits of a lit island.
static func _fx(ci: CanvasItem, world: String, t: float) -> void:
	if still:
		t = 0.0
	match world:
		"ocean":
			for i in 5:
				var f := fposmod(t * 0.9 + i / 5.0, 1.0)
				var y := 40.0 + f * 170.0
				Art.dot(ci, Vector2(172 + (i % 3) * 6, y), 2.5, Color(1, 1, 1, 0.8 * (1.0 - f)))
			for i in 3:
				var f := fposmod(t * 0.6 + i / 3.0, 1.0)
				Art.dot(ci, Vector2(176 + sin(i * 2.0) * 10, 226 - f * 10), 4.0 + f * 5.0, Color(1, 1, 1, 0.6 * (1.0 - f)))
		"volcano":
			var pulse := 0.5 + 0.5 * sin(t * 2.4)
			Art.glow(ci, Vector2(2, -170), 46, Color(1.0, 0.6, 0.2, 0.25 + 0.2 * pulse))
			for i in 4:
				var f := fposmod(t * 0.25 + i / 4.0, 1.0)
				var c := Vector2(10 + sin(t * 0.7 + i) * 10 + f * 20, -214 - f * 70)
				Art.dot(ci, c, 10.0 + f * 12.0, Color(0.5, 0.46, 0.56, 0.75 * (1.0 - f)))
			for i in 5:
				var f := fposmod(t * 0.5 + i / 5.0, 1.0)
				Art.dot(ci, Vector2(-160 + i * 80 + sin(t + i) * 8, 40 - f * 120), 2.0, Color(1.0, 0.7, 0.2, 1.0 - f))
		"acid":
			for i in 6:
				var f := fposmod(t * 0.45 + i / 6.0, 1.0)
				var x := -90.0 + i * 32.0
				Art.dot(ci, Vector2(x + sin(t * 2.0 + i) * 3, 14 - f * 40), 2.0 + f * 3.0, Color(0.85, 1.0, 0.5, 0.9 * (1.0 - f)))
			for i in 3:
				var f := fposmod(t * 0.35 + i / 3.0, 1.0)
				Art.dot(ci, Vector2(110 + i * 6, -60 - f * 50), 3.0 + f * 4.0, Color(0.7, 1.0, 0.4, 0.8 * (1.0 - f)))
		"moon":
			var b := 0.5 + 0.5 * sin(t * 3.0)
			Art.dot(ci, spots("moon")["factory"] + Vector2(27, -59), 3.0, Color(1.0, 0.3, 0.3, 0.4 + 0.6 * b))
			Art.glow(ci, spots("moon")["office"] + Vector2(-28, -96), 14, Color(0.5, 0.95, 1.0, 0.3 * b))


## "?" and padlock over a locked island; `pulse` makes the next one breathe.
static func mystery(ci: CanvasItem, at: Vector2, t: float, pulse: bool) -> void:
	var k := 1.0 + (0.06 * sin(t * 3.0) if pulse else 0.0)
	if pulse:
		Art.glow(ci, at + Vector2(0, -30), 90, Color(1.0, 0.85, 0.3, 0.22))
	Art.push(ci, at, 0.0, Vector2(k, k))
	Art.text(ci, Vector2(-8, 16), "?", 120, Art.GOLD, 16)
	Art.lock(ci, Vector2(30, 6), 30)
	Art.pop(ci)


## Planted flag and a green check on a finished island.
static func done_mark(ci: CanvasItem, at: Vector2, t: float) -> void:
	Art.stroke(ci, PackedVector2Array([at, at + Vector2(0, -64)]), Art.WOOD_DARK, 4.0, 2.0)
	var wave := sin(t * 4.0) * 2.0
	Art.toon(ci, PackedVector2Array([at + Vector2(2, -64), at + Vector2(36, -56 + wave), at + Vector2(2, -44)]), Art.RED, 2.5, 0.3)
	Art.t_circle(ci, at + Vector2(22, -10), 15, Art.GREEN, 3.0, 0.5)
	Art.polyline(ci, PackedVector2Array([at + Vector2(14, -10), at + Vector2(20, -4), at + Vector2(30, -17)]), Art.WHITE, 4.5)


## Map pins over the mine, factory and office of the current island.
static func markers(ci: CanvasItem, world: String, t: float) -> void:
	var sp := spots(world)
	var i := 0
	for k in ["mine", "factory", "office"]:
		var p: Vector2 = sp[k] + Vector2(0, -78 + sin(t * 2.5 + i) * 3.0)
		if world == "moon" and k == "office":
			p.y -= 16
		Art.toon(ci, PackedVector2Array([p + Vector2(-7, 12), p + Vector2(7, 12), p + Vector2(0, 24)]), Art.WHITE, 2.5, 0.0)
		Art.t_circle(ci, p, 16, Art.WHITE, 3.0, 0.4)
		match k:
			"mine":
				Art.push(ci, p, -0.6)
				Art.stroke(ci, PackedVector2Array([Vector2(0, 9), Vector2(0, -7)]), Art.WOOD, 3.0, 1.5)
				Art.toon(ci, PackedVector2Array([Vector2(-10, -6), Vector2(0, -11), Vector2(10, -6), Vector2(0, -8)]), Color("9aa3bd"), 2.0, 0.0)
				Art.pop(ci)
			"factory":
				Art.gear(ci, p, 10, Color("ff8a3d"), t * 0.8, 8)
			"office":
				_star_badge(ci, p, 10, Art.GOLD)
		i += 1


## Position and facing of a boat on its route for cycle progress p
## (-1 = idle, waits at the mine). Returns Vector3(x, y, facing).
static func boat_at(world: String, p: float, lane: float = 0.0) -> Vector3:
	var route: Array = spots(world)["boat"]
	var f := 0.0
	var facing := 1.0
	if p >= LOAD_END and p < SAIL_END:
		f = smoothstep(LOAD_END, SAIL_END, p)
	elif p >= SAIL_END and p < UNLOAD_END:
		f = 1.0
	elif p >= UNLOAD_END:
		f = 1.0 - smoothstep(UNLOAD_END, 1.0, p)
		facing = -1.0
	var pos := _along(route, f) + Vector2(0, lane)
	var dir: Vector2 = route[route.size() - 1] - route[0]
	return Vector3(pos.x, pos.y, facing * signf(dir.x if dir.x != 0.0 else 1.0))


static func _along(route: Array, f: float) -> Vector2:
	var total := 0.0
	for i in route.size() - 1:
		total += (route[i] as Vector2).distance_to(route[i + 1])
	var want := total * clampf(f, 0.0, 1.0)
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var d := a.distance_to(b)
		if want <= d or i == route.size() - 2:
			return a.lerp(b, clampf(want / maxf(d, 0.001), 0.0, 1.0))
		want -= d
	return route[0]


## Little boat (or lava tug / swamp pontoon / moon hover), origin at the waterline.
static func boat(ci: CanvasItem, at: Vector2, facing: float, world: String, loaded: bool, t: float, second: bool = false) -> void:
	var lk := look(world)
	var hull: Color = lk["boat2"] if second else lk["boat"]
	var s := 0.82 if second else 1.0
	var bob := sin(t * 3.0 + (1.0 if second else 0.0)) * 1.2
	Art.push(ci, at + Vector2(0, bob), 0.0, Vector2(facing * s, s))
	if world == "moon":
		Art.glow(ci, Vector2(0, 6), 22, Color(0.5, 0.95, 1.0, 0.45))
	else:
		Art.flat_now(ci, Art.ellipse_pts(Vector2(-6, 3), Vector2(22, 4), 12), Color(1, 1, 1, 0.45))
	if loaded:
		Art.t_rect(ci, Rect2(-12, -17, 9, 9), 2, Art.GOLD, 2.0, 0.0)
		Art.t_rect(ci, Rect2(-4, -15, 8, 7), 2, Color("ffb238"), 2.0, 0.0)
	Art.t_rect(ci, Rect2(2, -20, 10, 12), 3, Art.WHITE, 2.2, 0.0)
	Art.t_rect(ci, Rect2(4, -18, 6, 4), 1, Art.GLASS, 0.0, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-18, -9), Vector2(20, -9), Vector2(13, 4), Vector2(-14, 4)]), hull, 2.5, 0.6)
	Art.line(ci, Vector2(-16, -4), Vector2(17, -4), Art.WHITE, 2.0)
	Art.pop(ci)


## Rope bridge (wooden planks) or a glowing path between two islands.
static func bridge(ci: CanvasItem, a: Vector2, b: Vector2, lit: bool, glowing: bool, t: float) -> void:
	var n := maxi(6, int(a.distance_to(b) / 16.0))
	var pts := PackedVector2Array()
	var sag := minf(30.0, a.distance_to(b) * 0.12)
	for i in n + 1:
		var f := float(i) / n
		pts.append(a.lerp(b, f) + Vector2(0, sin(f * PI) * sag))
	if glowing:
		var col := Color("7ff0ff") if lit else Color("3b3266")
		Art.polyline(ci, pts, Color(col, 0.35), 16.0)
		for i in n + 1:
			var f := float(i) / n
			var r := 4.0 + (1.5 * sin(t * 4.0 - f * 8.0) if lit else 0.0)
			Art.dot(ci, pts[i], r, col if lit else Color(col, 0.9))
		return
	var wood := Art.WOOD if lit else Color("2a2342")
	var rope := Color("8e552c") if lit else Color("1d1733")
	var up := Vector2(0, -12)
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x) * 6.0
	for i in n:
		var c := (pts[i] + pts[i + 1]) / 2.0
		var plank := PackedVector2Array([c - dir * 6 - nrm, c + dir * 6 - nrm, c + dir * 6 + nrm, c - dir * 6 + nrm])
		Art.toon(ci, plank, wood, 2.0, 0.0, Art.INK if lit else Color("0d0a18"))
	var top := PackedVector2Array()
	for p in pts:
		top.append(p + up)
	Art.polyline(ci, top, rope, 2.5)
	for i in range(0, n + 1, 2):
		Art.line(ci, pts[i], pts[i] + up, rope, 2.0)
	Art.stroke(ci, PackedVector2Array([a + Vector2(0, 6), a + up * 1.6]), wood, 4.0, 1.5)
	Art.stroke(ci, PackedVector2Array([b + Vector2(0, 6), b + up * 1.6]), wood, 4.0, 1.5)


## The glowing path over an island through its level nodes, from `from` to `to`.
static func path(ci: CanvasItem, world: String, from: Vector2, to: Vector2, lit: bool) -> void:
	var nodes: Array = spots(world)["nodes"].duplicate()
	var dir := (to - from).normalized()
	nodes.sort_custom(func(p, q): return (p as Vector2).dot(dir) < (q as Vector2).dot(dir))
	var ctrl := PackedVector2Array([from])
	for p in nodes:
		ctrl.append(p)
	ctrl.append(to)
	var col: Color = look(world)["path"] if lit else Color("3b3266")
	Art.line_c(ci, ctrl, Color(col, 0.4), 14.0)
	Art.line_c(ci, ctrl, col, 5.0)


## Dark starry space behind a moon island.
static func space(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var key := hash(["space", r])
	Art.push(ci, c)
	if not Art.cache_begin(ci, key):
		var blob := Art.union([Art.ellipse_pts(Vector2.ZERO, Vector2(r, r * 0.86), 40), Art.ellipse_pts(Vector2(r * 0.4, -r * 0.4), Vector2(r * 0.6, r * 0.5), 30),
				Art.ellipse_pts(Vector2(-r * 0.5, r * 0.3), Vector2(r * 0.55, r * 0.45), 30)])
		var grown := Geometry2D.offset_polygon(blob, 22.0, Geometry2D.JOIN_ROUND)
		if grown.size() > 0:
			Art.flat(ci, grown[0], Color(0.35, 0.3, 0.75, 0.35))
		Art.flat(ci, blob, Color("1d1d5c"))
		Art.flat(ci, Art.ellipse_pts(Vector2(r * 0.25, -r * 0.2), Vector2(r * 0.55, r * 0.3), 30, -0.5), Color(0.45, 0.25, 0.75, 0.35))
		Art.flat(ci, Art.ellipse_pts(Vector2(-r * 0.3, r * 0.25), Vector2(r * 0.45, r * 0.22), 30, 0.4), Color(0.2, 0.45, 0.85, 0.3))
		# Ringed planet and a small one.
		var pl := Vector2(r * 0.62, -r * 0.55)
		Art.t_circle(ci, pl, 24, Color("b48cff"), 3.0, 0.8)
		Art.toon(ci, Art.ellipse_pts(pl, Vector2(40, 9), 24, -0.3), Color(0, 0, 0, 0), 2.5, 0.0, Color("ffd98a"))
		Art.t_circle(ci, Vector2(-r * 0.7, -r * 0.45), 12, Color("ff9a6a"), 2.5, 0.7)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 22:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * r * 0.9
			Art.disc(ci, Vector2(cos(a) * d, sin(a) * d * 0.85), rng.randf_range(1.0, 2.4), Color(1, 1, 1, rng.randf_range(0.5, 0.9)))
		Art.cache_end(ci, key)
	for i in 5:
		var p := Vector2(cos(i * 1.9) * r * 0.75, sin(i * 2.7) * r * 0.6)
		var tw := 0.5 + 0.5 * sin(t * 2.0 + i * 1.3)
		Art.push(ci, p, 0.0, Vector2.ONE * (0.6 + tw * 0.5))
		Art.flat_now(ci, Art.star_pts(Vector2.ZERO, 10, 3.5, 4), Color(1.0, 0.95, 0.6, 0.6 + tw * 0.4))
		Art.pop(ci)
	Art.pop(ci)


## Fluffy cloud.
static func cloud(ci: CanvasItem, at: Vector2, s: float, seed: int) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	var key := hash(["mcloud", seed])
	if not Art.cache_begin(ci, key):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var parts := [Art.rrect_pts(Rect2(-60, -10, 120, 26), 13)]
		for i in 5:
			parts.append(Art.circle_pts(Vector2(-44 + i * 22 + rng.randf_range(-4, 4), -10 - rng.randf_range(2, 14) - (8.0 if i in [1, 2, 3] else 0.0)), rng.randf_range(16, 24), 20))
		Art.toon(ci, Art.union(parts), Color(1, 1, 1, 0.95), 3.0, 0.5, Color("8cc6ea"))
		Art.cache_end(ci, key)
	Art.pop(ci)


## Wooden name plate under an island ("★2" for the repeats).
static func plate(ci: CanvasItem, at: Vector2, label: String, state: int, tier: int, size: int = 26) -> void:
	var font := UiTheme.heavy_font()
	var s := label
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 40.0
	if tier > 0:
		w += 54.0
	var fill := Art.CREAM
	match state:
		CURRENT: fill = Art.GOLD
		DONE: fill = Color("bff0b0")
		NEXT: fill = Color("4a3f7a")
		LOCKED: fill = Color("2a2342")
	var r := Rect2(at.x - w / 2.0, at.y - size * 0.95, w, size * 1.6)
	Art.t_rect(ci, r, size * 0.8, fill, 3.5, 0.6)
	var tx := at.x - (27.0 if tier > 0 else 0.0)
	var dark := state == NEXT or state == LOCKED
	Art.text(ci, Vector2(tx, at.y + size * 0.36), s, size, Art.WHITE if dark else Art.INK, 7 if dark else 0)
	if tier > 0:
		var sc := Vector2(r.end.x - 34.0, at.y - size * 0.15)
		Art.toon(ci, Art.star_pts(sc, 21, 10, 5), Art.GOLD, 2.5, 0.5)
		Art.text(ci, sc + Vector2(0, 7), str(tier + 1), 18, Art.INK, 0)


## The current island in miniature inside a round frame (the mini-map),
## static part clipped to the circle. p1/p2: boat cycle progress (p2 < -1.5
## = no second boat).
static func mini(ci: CanvasItem, center: Vector2, radius: float, world: String, tier: int, p1: float, p2: float, t: float) -> void:
	var k := radius / 150.0
	var view := Vector2(0, -20)
	_shift = 0.0 if tier <= 0 else 0.07 * float(tier)
	var key := hash(["mini", world, tier, radius])
	Art.push(ci, center)
	if not Art.cache_begin(ci, key):
		var start := Art.rec_mark()
		var bg: Color = Color("1d1d5c") if world == "moon" else Color("8fd6ff")
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, radius, 40), bg)
		if world == "moon":
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			for i in 10:
				Art.disc(ci, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, -0.2)) * radius * 0.8, 1.6, Color(1, 1, 1, 0.8))
		else:
			Art.flat(ci, Art.ellipse_pts(Vector2(-radius * 0.5, radius * 0.75), Vector2(radius * 0.5, radius * 0.2), 20), Color(1, 1, 1, 0.8))
		Art.push(ci, -view * k, 0.0, Vector2(k, k))
		match world:
			"volcano": _volcano(ci)
			"acid": _acid(ci)
			"moon": _moon(ci)
			_: _ocean(ci)
		Art.pop(ci)
		Art.fit_recorded(start, Vector2.ZERO, radius - 1.0, Vector2.ZERO, 1.0)
		Art.cache_end(ci, key)
	Art.push(ci, -view * k, 0.0, Vector2(k, k))
	var route: Array = spots(world)["boat"]
	var line := PackedVector2Array()
	for p in route:
		line.append(p)
	Art.line_c(ci, line, Color(1, 1, 1, 0.55), 5.0)
	if p2 > -1.5:
		var b2 := boat_at(world, p2, 9.0)
		boat(ci, Vector2(b2.x, b2.y), b2.z, world, p2 >= LOAD_END and p2 < UNLOAD_END, t, true)
	var b1 := boat_at(world, p1)
	boat(ci, Vector2(b1.x, b1.y), b1.z, world, p1 >= LOAD_END and p1 < UNLOAD_END, t)
	Art.pop(ci)
	Art.pop(ci)
	_shift = 0.0
