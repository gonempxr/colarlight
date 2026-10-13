class_name WorldArt
extends RefCounted
## Scenery of the five worlds in the toon style (thick INK outline, soft
## shading), drawn in local space and placed with Art.push / Art.pop like
## Props. The surface of each world:
##   ocean    sandy beach, palm, lighthouse, wooden hut (Props has most of it)
##   volcano  basalt shore, a smoking volcano behind, lava river, stone hut
##   acid     mossy mud shore, giant mushrooms, twisted trees, mushroom house
##   moon     grey regolith with craters, Earth in a black sky, dome base
##   jungle   golden temple stone, a turquoise river, a hut on stilts, a
##            stepped pyramid and a waterfall far away (see "Jungle ruins")
## Shapes are built once (static vars) and moved with Art.push, so the
## geometry cache stays small.

const INK := Art.INK


# --- Sky -----------------------------------------------------------------------------

## The Earth hanging in the moon's sky (~34 px radius).
static func earth(ci: CanvasItem, at: Vector2, t: float) -> void:
	Props.halo(ci, at, 70.0, Color(0.55, 0.8, 1.0, 0.25))
	Art.push(ci, at)
	Art.t_circle(ci, Vector2.ZERO, 34, Color("3a8ee8"), 3.0, 0.5)
	for blob: PackedVector2Array in _LANDS:
		Art.flat(ci, blob, Color("5cc860"))
	Art.flat(ci, _EARTH_CLOUD, Color(1, 1, 1, 0.75))
	Art.flat(ci, _EARTH_SHINE, Color(1, 1, 1, 0.28))
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, 34, 40), INK, 3.0)
	Art.pop(ci)


static var _DISC := Art.circle_pts(Vector2.ZERO, 32.5, 40)
static var _LANDS: Array[PackedVector2Array] = [
	Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(-26, -14), Vector2(-12, -24), Vector2(-2, -16), Vector2(-8, -4), Vector2(-4, 8), Vector2(-16, 12), Vector2(-28, 2)]), 3), _DISC),
	Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(8, -8), Vector2(22, -14), Vector2(32, -2), Vector2(24, 14), Vector2(12, 22), Vector2(6, 8)]), 3), _DISC),
	Art.clipped(Art.ellipse_pts(Vector2(-6, 26), Vector2(14, 5), 14), _DISC),
]
static var _EARTH_CLOUD := Art.clipped(Art.union([Art.rrect_pts(Rect2(-30, -4, 26, 6), 3), Art.rrect_pts(Rect2(4, 4, 30, 5), 2.5),
		Art.rrect_pts(Rect2(-12, -30, 22, 5), 2.5)]), _DISC)
static var _EARTH_SHINE := Art.clipped(Art.circle_pts(Vector2(-12, -12), 16, 20), _DISC)


## A friendly ringed planet (the moon world's night light); `wink` 0..1
## opens one sleepy eye, like Props.moon.
static func planet(ci: CanvasItem, t: float, wink: float = 0.0) -> void:
	Props.halo(ci, Vector2.ZERO, 82.0, Color(0.85, 0.75, 1.0, 0.26 + sin(t * 1.3) * 0.04))
	Art.toon(ci, _RING_BACK, Color("ffd59a"), 2.6, 0.0)
	Art.t_circle(ci, Vector2.ZERO, 28, Color("b48cff"), 3.0, 0.45)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-30, -10, 60, 6), 3), Art.circle_pts(Vector2.ZERO, 26, 30)), Color("9a72f0"))
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-30, 8, 60, 5), 2), Art.circle_pts(Vector2.ZERO, 26, 30)), Color("d0b4ff"))
	Art.disc(ci, Vector2(-13, 5), 4.5, Color(1.0, 0.6, 0.7, 0.4))
	Art.disc(ci, Vector2(13, 5), 4.5, Color(1.0, 0.6, 0.7, 0.4))
	Art.arc(ci, Vector2(-8, -3), 4.0, 0.2, PI - 0.2, 8, INK, 2.4)
	if wink > 0.5:
		Art.t_ellipse(ci, Vector2(8, -3), Vector2(3.0, 4.0), INK, 0.0, 0.0)
		Art.disc(ci, Vector2(9, -5), 1.2, Art.WHITE)
	else:
		Art.arc(ci, Vector2(8, -3), 4.0, 0.2, PI - 0.2, 8, INK, 2.4)
	Art.arc(ci, Vector2(0, 4), 5.0, 0.4, PI - 0.4, 10, INK, 2.4)
	Art.toon(ci, _RING_FRONT, Color("ffd59a"), 2.6, 0.0)


static var _RING_BACK := _ring_half(true)
static var _RING_FRONT := _ring_half(false)


static func _ring_half(back: bool) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var a := (PI + PI * i / 16.0) if back else (PI * i / 16.0)
		outer.append(Vector2(cos(a) * 50.0, sin(a) * 11.0).rotated(-0.25))
		inner.append(Vector2(cos(a) * 36.0, sin(a) * 6.5).rotated(-0.25))
	inner.reverse()
	outer.append_array(inner)
	return outer


## A drifting space rock (the moon's "clouds"); `seed` picks the shape.
static func asteroid(ci: CanvasItem, seed: int, fill: Color, line: Color) -> void:
	var k := seed % _ROCKS.size()
	Art.toon(ci, _ROCKS[k], fill, 2.8, 0.6, line)
	for c: Vector3 in _ROCK_PITS[k]:
		Art.t_ellipse(ci, Vector2(c.x, c.y), Vector2(c.z, c.z * 0.75), Art.shade_of(fill, 0.22), 0.0, 0.0)


static var _ROCKS: Array[PackedVector2Array] = [
	Art.smooth_pts(PackedVector2Array([Vector2(-30, 2), Vector2(-24, -14), Vector2(-6, -20), Vector2(14, -16), Vector2(28, -4), Vector2(24, 10), Vector2(4, 14), Vector2(-18, 12)]), 3),
	Art.smooth_pts(PackedVector2Array([Vector2(-22, 0), Vector2(-16, -14), Vector2(0, -18), Vector2(18, -10), Vector2(22, 4), Vector2(8, 14), Vector2(-12, 12)]), 3),
	Art.smooth_pts(PackedVector2Array([Vector2(-36, 0), Vector2(-26, -12), Vector2(-4, -16), Vector2(20, -14), Vector2(34, -2), Vector2(22, 10), Vector2(-14, 12)]), 3),
	Art.smooth_pts(PackedVector2Array([Vector2(-16, 0), Vector2(-10, -12), Vector2(6, -14), Vector2(16, -2), Vector2(8, 10), Vector2(-8, 10)]), 3),
]
const _ROCK_PITS := [[Vector3(-12, -4, 5), Vector3(10, 2, 4), Vector3(2, -12, 3)], [Vector3(-6, -4, 5), Vector3(8, 4, 3)],
		[Vector3(-16, -2, 5), Vector3(4, -6, 4), Vector3(20, 0, 3)], [Vector3(0, -2, 4)]]


## Ash cloud (volcano) or swamp mist (acid): a cloud with its own colors.
static func cloud_colors(world: String, day: float) -> Array:
	match world:
		"volcano":
			return [Color("8a7a84").lerp(Color("4a3a48"), 1.0 - day), Color("4e3e4c").lerp(Color("2a1e2a"), 1.0 - day)]
		"acid":
			return [Color("d8f0c0").lerp(Color("4a6a5e"), 1.0 - day), Color("7aa88a").lerp(Color("23403a"), 1.0 - day)]
		"moon":
			return [Color("a6a2b4").lerp(Color("6a6880"), 1.0 - day * 0.5), Color("4a4660")]
	return []


## A fire bird (volcano's gulls): orange wings and a little flame tail.
static func ember_bird(ci: CanvasItem, flap: float, t: float) -> void:
	var up := flap * 11.0
	Art.toon(ci, _FLAME_TAIL, Color("ffc93c"), 1.8, 0.0)
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 3, -2), Vector2(side * 12, -4 - up * 0.6), Vector2(side * 20, -3 - up),
				Vector2(side * 12, 1 - up * 0.4), Vector2(side * 3, 4)])
		Props.live(ci, wing, Color("ff7a3a"), 2.0)
	Art.t_ellipse(ci, Vector2(0, 1), Vector2(8.5, 5), Color("ff9a3a"), 2.0, 0.4)
	Art.toon(ci, PackedVector2Array([Vector2(8, 0), Vector2(14, 2), Vector2(8, 3.5)]), Color("ffe066"), 1.5, 0.0)
	Art.disc(ci, Vector2(5, -1), 1.4, INK)


static var _FLAME_TAIL := Art.smooth_pts(PackedVector2Array([Vector2(-6, -1), Vector2(-16, -6), Vector2(-13, 0), Vector2(-20, 4), Vector2(-6, 4)]), 2)


## A dragonfly (the swamp's birds): long body and four glassy wings.
static func dragonfly(ci: CanvasItem, flap: float, color: Color) -> void:
	for k in 2:
		var a := (-0.35 - flap * 0.4) if k == 0 else (0.25 + flap * 0.4)
		Art.push(ci, Vector2(-2 + k * 4, -3), a)
		Art.toon(ci, _WING, Color(0.85, 1.0, 0.95, 0.75), 1.6, 0.0)
		Art.pop(ci)
		Art.push(ci, Vector2(-2 + k * 4, -3), PI - a)
		Art.toon(ci, _WING, Color(0.85, 1.0, 0.95, 0.75), 1.6, 0.0)
		Art.pop(ci)
	Art.toon(ci, _DF_BODY, color, 1.8, 0.4)
	Art.t_circle(ci, Vector2(11, -1), 4.5, color.lightened(0.2), 1.8, 0.3)
	Art.disc(ci, Vector2(13, -2), 1.4, INK)


static var _WING := Art.ellipse_pts(Vector2(0, -9), Vector2(3.5, 10), 12)
static var _DF_BODY := Art.smooth_pts(PackedVector2Array([Vector2(8, -3), Vector2(-18, -1), Vector2(-20, 0.5), Vector2(-18, 2), Vector2(8, 2)]), 2)


## A tiny satellite crossing the moon's sky (its "birds"); the dish turns.
static func satellite(ci: CanvasItem, t: float, blink: bool) -> void:
	for sx: float in [-1.0, 1.0]:
		Art.t_rect(ci, Rect2(sx * 9 - (16 if sx < 0 else 0), -5, 16, 10), 2, Color("3a6ad8"), 1.8, 0.0)
		Art.line(ci, Vector2(sx * 9 + sx * 8, -5), Vector2(sx * 9 + sx * 8, 5), Color("8ab4ff"), 1.2)
	Art.t_rect(ci, Rect2(-8, -7, 16, 14), 3, Color("e8ecf4"), 2.0, 0.4)
	Art.line(ci, Vector2(0, -7), Vector2(0, -13), INK, 1.6)
	Art.disc(ci, Vector2(0, -14), 2.2, Color("ff5a5a") if blink else Color("8a3a3a"))


# --- Ground bits ------------------------------------------------------------------------

## A small dark rock with glowing cracks; origin on the ground.
static func hot_rock(ci: CanvasItem, tint: Color, k: int) -> void:
	Art.toon(ci, _HOT_ROCK, Color("4a3c48") * tint, 2.4, 0.5)
	Art.line_c(ci, _CRACKS[k % _CRACKS.size()], Color("ff8a2a"), 2.2)


static var _HOT_ROCK := Art.smooth_pts(PackedVector2Array([Vector2(-16, 1), Vector2(-14, -9), Vector2(-4, -15), Vector2(8, -13), Vector2(16, -5), Vector2(15, 1)]), 2)
static var _CRACKS: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-8, -10), Vector2(-3, -5), Vector2(4, -7), Vector2(9, -2)]),
		PackedVector2Array([Vector2(-10, -3), Vector2(-2, -9), Vector2(3, -4)]), PackedVector2Array([Vector2(2, -13), Vector2(0, -6), Vector2(6, -2)])]


## A cute toadstool, ~30 px tall; origin at its foot. `sway` tilts the cap.
static func mushroom(ci: CanvasItem, cap: Color, sway: float, k: int) -> void:
	Art.toon(ci, _STEM, Color("fff1d8"), 2.2, 0.4)
	Art.push(ci, Vector2(0, -16), sway)
	Art.toon(ci, _CAP, cap, 2.4, 0.5)
	for p: Vector3 in _SPOTS[k % 2]:
		Art.t_ellipse(ci, Vector2(p.x, p.y), Vector2(p.z, p.z * 0.8), Color(1, 1, 1, 0.9), 0.0, 0.0)
	Art.pop(ci)


static var _STEM := Art.smooth_pts(PackedVector2Array([Vector2(-5, 0), Vector2(-4, -10), Vector2(-3.5, -18), Vector2(3.5, -18), Vector2(4, -10), Vector2(5, 0)]), 2)
static var _CAP := Art.smooth_pts(PackedVector2Array([Vector2(-15, 2), Vector2(-13, -6), Vector2(-6, -12), Vector2(0, -13), Vector2(6, -12), Vector2(13, -6), Vector2(15, 2)]), 3)
const _SPOTS := [[Vector3(-7, -5, 2.6), Vector3(4, -8, 2.2), Vector3(9, -2, 1.8)], [Vector3(-4, -8, 2.4), Vector3(7, -4, 2.6), Vector3(-10, -1, 1.6)]]


## A crater: a raised rim and a dark hollow; origin at its middle.
static func crater(ci: CanvasItem, ground: Color, r: float) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(r / 30.0, r / 30.0))
	Art.toon(ci, _CRATER_RIM, ground.lightened(0.12), 2.2, 0.0)
	Art.flat(ci, _CRATER_IN, Art.shade_of(ground, 0.3))
	Art.flat(ci, _CRATER_LIP, Art.shade_of(ground, 0.12))
	Art.pop(ci)


static var _CRATER_RIM := Art.ellipse_pts(Vector2(0, -2), Vector2(30, 8), 24)
static var _CRATER_IN := Art.ellipse_pts(Vector2(0, -1), Vector2(22, 5), 22)
static var _CRATER_LIP := Art.clipped(Art.ellipse_pts(Vector2(0, -4), Vector2(22, 4), 20), _CRATER_IN)


## A glowing pool (magma or acid) set in the ground; origin at its middle.
static func pool(ci: CanvasItem, c: Color, c2: Color, s: float = 1.0) -> void:
	Art.glow(ci, Vector2(0, -6), 60.0 * s, Color(c, 0.3), 16)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(s, s))
	Art.toon(ci, _POOL_RIM, Color("3a2e3a"), 2.4, 0.0)
	Art.flat(ci, _POOL_IN, c)
	Art.flat(ci, _POOL_CORE, c2)
	Art.pop(ci)


static var _POOL_RIM := Art.ellipse_pts(Vector2(0, -2), Vector2(46, 10), 26)
static var _POOL_IN := Art.ellipse_pts(Vector2(0, -2), Vector2(40, 7), 26)
static var _POOL_CORE := Art.ellipse_pts(Vector2(-6, -3), Vector2(22, 3), 18)


## Three crystals growing from one spot; origin at their foot.
static func crystal_cluster(ci: CanvasItem, c: Color) -> void:
	Art.crystal(ci, Vector2(-10, 2), 26, 7, -0.35, c.darkened(0.08), 2.2)
	Art.crystal(ci, Vector2(10, 2), 22, 6, 0.35, c.lightened(0.15), 2.2)
	Art.crystal(ci, Vector2(0, 2), 38, 8, 0.0, c, 2.2)


# --- The shore --------------------------------------------------------------------------

## The shore of a world; origin at the waterline where it begins, extends
## +x for `width` (and past it, under the screen edge).
static func island(ci: CanvasItem, world: String, width: float) -> void:
	if world == "ocean":
		Props.island(ci, width)
		return
	var base := WorldLook.color("sand")
	var top := WorldLook.color("grass")
	var ground := Art.smooth_pts(PackedVector2Array([Vector2(-6, 30), Vector2(6, -8), Vector2(30, -34), Vector2(70, -60),
			Vector2(width * 0.5, -66), Vector2(width + 40, -64), Vector2(width + 40, 30)]), 4)
	Art.toon(ci, ground, base, WorldLook.EDGE, 0.8)
	var crust := PackedVector2Array([Vector2(56, -58), Vector2(width * 0.5, -72), Vector2(width + 40, -70), Vector2(width + 40, -52)])
	for i in 8:
		var x := width + 30.0 - (width - 40.0) * (i + 0.5) / 8.0
		crust.append(Vector2(x, -54.0 + (5.0 if i % 2 == 0 else 0.0)))
	match world:
		"volcano":
			Art.toon(ci, Art.smooth_pts(crust, 3), top, 3.0, 0.5)
			# Basalt columns on the face and glowing cracks.
			for p: Vector3 in [Vector3(40, -18, 0), Vector3(96, -30, 1), Vector3(170, -28, 2)]:
				if p.x < width:
					Art.line_c(ci, Art.moved(_CRACKS[int(p.z)], Vector2(p.x, p.y)), Color("ff8a2a"), 2.4)
			for p: Vector2 in [Vector2(30, -14), Vector2(140, -40)]:
				if p.x < width:
					Art.t_rect(ci, Rect2(p.x - 7, p.y - 10, 14, 12), 2, Art.shade_of(base, 0.15), 2.0, 0.0)
		"acid":
			Art.toon(ci, Art.smooth_pts(crust, 3), top, 3.0, 0.6)
			# Moss dripping over the edge.
			for i in 6:
				var x := 70.0 + i * (width - 60.0) / 6.0
				Art.toon(ci, Art.moved(_DRIP, Vector2(x, -54.0 + (5.0 if i % 2 == 0 else 0.0))), top, 2.0, 0.0)
			for p: Vector2 in [Vector2(40, -20), Vector2(110, -36)]:
				Art.t_ellipse(ci, p, Vector2(8, 4), WorldLook.color("sand_dark"), 1.8, 0.0)
		"jungle":
			_jungle_shore(ci, width, base, top, crust)
		"moon":
			Art.toon(ci, Art.smooth_pts(crust, 3), top, 3.0, 0.4)
			for p: Vector3 in [Vector3(44, -20, 0.5), Vector3(118, -36, 0.4), Vector3(width * 0.6, -63, 0.55)]:
				Art.push(ci, Vector2(p.x, p.y))
				crater(ci, base, 30.0 * p.z)
				Art.pop(ci)


static var _DRIP := Art.smooth_pts(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(3, 7), Vector2(0, 11), Vector2(-3, 7)]), 2)


## The workers' house of each world; origin on the ground under its left
## wall, about 150 wide and 130 tall. `lit` 0..1 lights the windows, `door`
## 0..1 opens the door (a tap), `t` animates small things.
const HOUSE_W := 150.0


static func house(ci: CanvasItem, world: String, t: float, lit: float, door: float) -> void:
	match world:
		"volcano":
			_stone_hut(ci, t, lit, door)
		"acid":
			_mushroom_house(ci, t, lit, door)
		"moon":
			_dome_base(ci, t, lit, door)
		"jungle":
			_stilt_hut(ci, t, lit, door)
		_:
			_beach_hut(ci, t, lit, door)


## Points (house-local) where the night glow goes: x, y, radius.
static func house_lights(world: String) -> Array[Vector3]:
	match world:
		"volcano":
			return [Vector3(104, -58, 30), Vector3(140, -96, 24)]
		"acid":
			return [Vector3(48, -62, 26), Vector3(104, -62, 26)]
		"moon":
			return [Vector3(54, -54, 26), Vector3(96, -54, 26), Vector3(140, -128, 18)]
		"jungle":
			return [Vector3(98, -87, 28), Vector3(146, -96, 20)]
	return [Vector3(102, -64, 28), Vector3(16, -100, 18)]


static func _door(ci: CanvasItem, r: Rect2, color: Color, open: float, round: bool = false) -> void:
	var radius := r.size.x / 2.0 if round else 4.0
	Art.t_rect(ci, r, radius, Color("3a2430"), 2.6, 0.0)
	var w := r.size.x * (1.0 - 0.75 * open)
	Art.t_rect(ci, Rect2(r.position, Vector2(w, r.size.y)), minf(radius, w / 2.0), color, 2.4, 0.4)
	Art.disc(ci, Vector2(r.position.x + w - 5.0, r.position.y + r.size.y * 0.55), 2.2, Art.GOLD)


## Wooden beach hut with a straw roof, porch steps and a star on the door.
static func _beach_hut(ci: CanvasItem, t: float, lit: float, door: float) -> void:
	for x: float in [14.0, 136.0]:
		Art.t_rect(ci, Rect2(x - 5, -18, 10, 22), 2, Art.WOOD_DARK, 2.2, 0.0)
	Art.t_rect(ci, Rect2(4, -24, 142, 10), 3, Art.WOOD, 2.6, 0.4)
	Art.t_rect(ci, Rect2(14, -96, 122, 74), 4, Color("e0a466"), 2.8, 0.6)
	for i in 4:
		Art.line(ci, Vector2(16, -78 + i * 16), Vector2(134, -78 + i * 16), Color("b87a44"), 1.8)
	Art.toon(ci, _HUT_ROOF, Color("f2c860"), 3.0, 0.6)
	for i in 7:
		var x := 6.0 + i * 22.0
		Art.line(ci, Vector2(x, -94), Vector2(x - 6, -100), Color("c89a3a"), 1.8)
	_door(ci, Rect2(28, -72, 30, 48), Color("8e552c"), door)
	Art.push(ci, Vector2(43, -84))
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 7, 3, 5), Art.GOLD, 1.8, 0.0)
	Art.pop(ci)
	Props._window(ci, Rect2(84, -78, 36, 28), 6, lit)
	Art.t_rect(ci, Rect2(80, -50, 44, 7), 2, Art.WOOD_DARK, 2.0, 0.0)
	Art.push(ci, Vector2(96, -50))
	for k in 3:
		Art.t_circle(ci, Vector2(-8 + k * 8, -4), 4, [Art.CORAL, Color("ff8fc0"), Art.GOLD][k], 1.6, 0.0)
	Art.pop(ci)


static var _HUT_ROOF := Art.smooth_pts(PackedVector2Array([Vector2(-8, -88), Vector2(20, -128), Vector2(75, -146), Vector2(130, -128),
		Vector2(158, -88), Vector2(75, -96)]), 3)


## Basalt-block hut with an iron roof, a chimney and a mine cart.
static func _stone_hut(ci: CanvasItem, t: float, lit: float, door: float) -> void:
	var stone := Color("6e6474")
	Art.t_rect(ci, Rect2(10, -92, 132, 94), 6, stone, 3.0, 0.6)
	for r: Rect2 in _BLOCKS:
		Art.t_rect(ci, r, 3, stone.lightened(0.08), 1.6, 0.0)
	Art.t_rect(ci, Rect2(118, -128, 18, 40), 3, Color("5a5060"), 2.6, 0.4)
	Art.t_rect(ci, Rect2(114, -134, 26, 8), 2, Color("44394c"), 2.4, 0.0)
	Art.toon(ci, _IRON_ROOF, Color("c8603a"), 3.0, 0.5)
	for i in 6:
		var x := 8.0 + i * 26.0
		Art.line(ci, Vector2(x, -94), Vector2(x + 14, -120), Color("a84a2c"), 1.6)
	_door(ci, Rect2(26, -64, 32, 64), Color("6a4a3a"), door)
	Props._window(ci, Rect2(84, -72, 40, 28), 4, lit)
	# A lantern by the door.
	Art.line(ci, Vector2(68, -70), Vector2(68, -60), INK, 1.8)
	Props.lamp(ci, Vector2(68, -50), maxf(lit, 0.5))
	# A mine cart with glowing ore.
	Art.push(ci, Vector2(-30, 0))
	Art.t_circle(ci, Vector2(-10, -4), 5, Color("3a3040"), 2.0, 0.0)
	Art.t_circle(ci, Vector2(12, -4), 5, Color("3a3040"), 2.0, 0.0)
	Art.toon(ci, _CART, Color("8a8494"), 2.4, 0.5)
	Art.t_ellipse(ci, Vector2(1, -24), Vector2(13, 5), Color("ff8a2a"), 1.8, 0.0)
	Art.pop(ci)


static var _BLOCKS: Array[Rect2] = [Rect2(16, -86, 30, 18), Rect2(74, -86, 36, 18), Rect2(112, -64, 26, 18), Rect2(62, -40, 24, 16), Rect2(108, -30, 30, 16)]
static var _IRON_ROOF := PackedVector2Array([Vector2(-6, -86), Vector2(24, -124), Vector2(128, -124), Vector2(158, -86)])
static var _CART := PackedVector2Array([Vector2(-18, -26), Vector2(20, -26), Vector2(16, -6), Vector2(-14, -6)])


## A giant toadstool house with a round door and windows in its stem.
static func _mushroom_house(ci: CanvasItem, t: float, lit: float, door: float) -> void:
	Art.toon(ci, _SHROOM_STEM, Color("fbeccc"), 3.0, 0.6)
	_door(ci, Rect2(60, -58, 32, 58), Color("8e552c"), door, true)
	Props._window(ci, Rect2(34, -76, 26, 26), 13, lit, false)
	Props._window(ci, Rect2(92, -76, 26, 26), 13, lit, false)
	Art.push(ci, Vector2(75, -92), sin(t * 0.8) * 0.015)
	Art.toon(ci, _SHROOM_CAP, Color("ff5a7a"), 3.2, 0.6)
	for p: Vector3 in [Vector3(-44, -18, 9), Vector3(-14, -34, 11), Vector3(22, -30, 9), Vector3(50, -14, 8), Vector3(0, -12, 6)]:
		Art.t_ellipse(ci, Vector2(p.x, p.y), Vector2(p.z, p.z * 0.75), Art.WHITE, 2.0, 0.0)
	Art.pop(ci)
	# Little toadstools at its foot.
	for p: Vector3 in [Vector3(-8, 0, 0.7), Vector3(150, 0, 0.9), Vector3(164, 0, 0.6)]:
		Art.push(ci, Vector2(p.x, p.y), 0.0, Vector2(p.z, p.z))
		mushroom(ci, Color("c86bff") if p.x > 100 else Color("ffd23f"), 0.0, int(p.x))
		Art.pop(ci)


static var _SHROOM_STEM := Art.smooth_pts(PackedVector2Array([Vector2(16, 2), Vector2(22, -40), Vector2(28, -92), Vector2(122, -92),
		Vector2(128, -40), Vector2(134, 2)]), 3)
static var _SHROOM_CAP := Art.smooth_pts(PackedVector2Array([Vector2(-86, 8), Vector2(-76, -18), Vector2(-50, -42), Vector2(-14, -56),
		Vector2(14, -56), Vector2(50, -42), Vector2(76, -18), Vector2(86, 8), Vector2(0, 2)]), 3)


## A white dome base with round windows, an airlock and an antenna.
static func _dome_base(ci: CanvasItem, t: float, lit: float, door: float) -> void:
	Art.t_rect(ci, Rect2(2, -12, 150, 14), 4, Color("9aa2b8"), 2.6, 0.4)
	Art.toon(ci, _DOME, Color("eef2fa"), 3.0, 0.6)
	Art.line_c(ci, _DOME_SEAM, Color("bcc6da"), 2.0)
	for x: float in [54.0, 96.0]:
		Props._window(ci, Rect2(x - 11, -66, 22, 22), 11, lit, false)
	_door(ci, Rect2(64, -42, 24, 32), Color("5a7ab8"), door, false)
	# The antenna with a blinking light.
	Art.stroke(ci, PackedVector2Array([Vector2(130, -64), Vector2(140, -120)]), Color("9aa2b8"), 3.0, 1.6)
	Art.push(ci, Vector2(136, -104), -0.5)
	Art.toon(ci, _DISH, Color("eef2fa"), 2.2, 0.4)
	Art.pop(ci)
	var blink := fposmod(t, 1.6) < 0.5
	Art.t_circle(ci, Vector2(140, -124), 4, Color("ff5a5a") if blink else Color("a03a4a"), 2.0, 0.0)
	# A small flag.
	Props.flag(ci, Vector2(-14, 0), 64, Color("4fb3ee"), t * 0.0, 0.9)


static var _DOME := _dome_pts()
static var _DOME_SEAM := PackedVector2Array([Vector2(20, -40), Vector2(52, -60), Vector2(100, -60), Vector2(132, -40)])
static var _DISH := Art.smooth_pts(PackedVector2Array([Vector2(-16, 0), Vector2(-10, 8), Vector2(0, 11), Vector2(10, 8), Vector2(16, 0)]), 2)


static func _dome_pts() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		pts.append(Vector2(76 + cos(a) * 68.0, -10 + sin(a) * 76.0))
	return pts


## What stands at the right screen edge (the ocean's palm): a charred tree
## with glowing coals (volcano), a giant mushroom (acid), a flag and a
## lander leg (moon). `shake` 0..1 wobbles it after a tap.
const EDGE_TOP := Vector2(-11, -96)


static func edge_prop(ci: CanvasItem, world: String, t: float, wind: float, shake: float) -> void:
	var wob := sin(t * 14.0) * shake * 0.12
	match world:
		"volcano":
			Art.push(ci, Vector2.ZERO, wob * 0.5)
			Art.toon(ci, _DEAD_TREE, Color("4a3a40"), 2.8, 0.5)
			for p: Vector2 in [Vector2(-30, -82), Vector2(-14, -108), Vector2(-46, -60)]:
				Art.t_circle(ci, p, 4, Color("ff8a2a"), 1.6, 0.0)
			Art.pop(ci)
		"acid":
			Art.push(ci, Vector2.ZERO, wob + sin(t * 0.9) * 0.02, Vector2(1.0 - shake * 0.08 * sin(t * 20.0), 1.0 + shake * 0.08 * sin(t * 20.0)))
			Art.toon(ci, _GIANT_STEM, Color("f4e8c8"), 2.8, 0.5)
			Art.push(ci, Vector2(-6, -100))
			Art.toon(ci, _GIANT_CAP, Color("8a6cf0"), 3.0, 0.6)
			for p: Vector3 in [Vector3(-30, -14, 7), Vector3(-6, -26, 8), Vector3(20, -14, 6)]:
				Art.t_ellipse(ci, Vector2(p.x, p.y), Vector2(p.z, p.z * 0.75), Color("c9f0ff"), 1.8, 0.0)
			Art.pop(ci)
			Art.pop(ci)
		"moon":
			Art.push(ci, Vector2(-20, 0), wob)
			var d := Props.downwind
			Props.downwind = -1.0
			Props.flag(ci, Vector2.ZERO, 92, Color("ff5a7a"), 0.0, 1.2)
			Props.downwind = d
			Art.pop(ci)
		"jungle":
			jungle_palm(ci, t, wind, shake, 2)
		_:
			Props.palm(ci, t, wind, shake)


static var _DEAD_TREE := Art.union([
	Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, 2), Vector2(-6, -40), Vector2(-14, -80), Vector2(-14, -116)]), 7.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
	Geometry2D.offset_polyline(PackedVector2Array([Vector2(-10, -64), Vector2(-30, -82), Vector2(-40, -84)]), 4.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
	Geometry2D.offset_polyline(PackedVector2Array([Vector2(-6, -44), Vector2(-46, -60)]), 3.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
])
static var _GIANT_STEM := Art.smooth_pts(PackedVector2Array([Vector2(-14, 2), Vector2(-12, -50), Vector2(-14, -100), Vector2(4, -100), Vector2(2, -50), Vector2(6, 2)]), 3)
static var _GIANT_CAP := Art.smooth_pts(PackedVector2Array([Vector2(-50, 6), Vector2(-42, -14), Vector2(-20, -32), Vector2(4, -36),
		Vector2(26, -28), Vector2(42, -10), Vector2(46, 6), Vector2(0, 0)]), 3)


## A twisted swamp tree (far away, so only a flat silhouette).
static func swamp_tree(ci: CanvasItem, color: Color, k: int) -> void:
	Art.flat(ci, _TREES[k % 2], color)


static var _TREES: Array[PackedVector2Array] = [
	Art.union([Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, 0), Vector2(6, -30), Vector2(-4, -60), Vector2(4, -84)]), 5.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		Geometry2D.offset_polyline(PackedVector2Array([Vector2(2, -50), Vector2(24, -66), Vector2(30, -80)]), 3.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		Geometry2D.offset_polyline(PackedVector2Array([Vector2(-2, -40), Vector2(-22, -52)]), 3.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		Art.ellipse_pts(Vector2(6, -92), Vector2(26, 14), 16), Art.ellipse_pts(Vector2(28, -84), Vector2(16, 10), 12)]),
	Art.union([Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, 0), Vector2(-6, -24), Vector2(4, -50), Vector2(-2, -66)]), 4.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, -36), Vector2(-20, -50), Vector2(-26, -64)]), 3.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0],
		Art.ellipse_pts(Vector2(-4, -74), Vector2(22, 12), 16), Art.ellipse_pts(Vector2(-24, -66), Vector2(12, 8), 12)]),
]


# --- Far away -----------------------------------------------------------------------------

## The big volcano behind the volcano world; origin at its foot (middle),
## ~300 wide and `h` tall. `glow` 0..1 brightens its lava, `poke` 0..1
## after a tap (it rumbles and glows).
static func volcano(ci: CanvasItem, h: float, rock: Color, glow: float, poke: float) -> void:
	Art.push(ci, Vector2(sin(poke * 40.0) * 2.0 * poke, 0), 0.0, Vector2(h / 220.0, h / 220.0))
	Art.toon(ci, _VOLCANO, rock, 3.0, 0.5)
	Art.flat(ci, _VOLCANO_SHADE, Art.shade_of(rock, 0.2))
	var hot := Color("ff7a1e").lerp(Color("ffd45a"), clampf(glow * 0.5 + poke, 0.0, 1.0))
	for s: PackedVector2Array in _STREAMS:
		Art.flat(ci, s, hot)
	Art.flat(ci, _CRATER_GLOW, Color("ffd45a"))
	Art.pop(ci)


static var _VOLCANO := Art.smooth_pts(PackedVector2Array([Vector2(-170, 4), Vector2(-120, -50), Vector2(-70, -130), Vector2(-34, -214),
		Vector2(-20, -220), Vector2(20, -220), Vector2(36, -212), Vector2(76, -128), Vector2(124, -48), Vector2(176, 4)]), 3)
static var _VOLCANO_SHADE := Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(20, -230), Vector2(50, -140), Vector2(110, -40), Vector2(200, 10),
		Vector2(220, -260)]), 2), _VOLCANO)
static var _STREAMS: Array[PackedVector2Array] = [
	Art.clipped(Geometry2D.offset_polyline(PackedVector2Array([Vector2(-10, -218), Vector2(-20, -170), Vector2(-14, -130), Vector2(-36, -80), Vector2(-40, -30)]), 5.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0], _VOLCANO),
	Art.clipped(Geometry2D.offset_polyline(PackedVector2Array([Vector2(12, -218), Vector2(22, -160), Vector2(48, -110), Vector2(56, -60)]), 4.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0], _VOLCANO),
]
static var _CRATER_GLOW := Art.ellipse_pts(Vector2(0, -219), Vector2(18, 4), 14)


## Point (volcano-local, scale 1) where its smoke comes out.
const VOLCANO_TOP := Vector2(0, -222)


## A far crater ridge on the moon's horizon (flat silhouette).
static func ridge(ci: CanvasItem, width: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(-width * 0.38, -18), Vector2(-width * 0.26, -30), Vector2(-width * 0.18, -22),
			Vector2(-width * 0.06, -24), Vector2(width * 0.04, -34), Vector2(width * 0.2, -36), Vector2(width * 0.3, -26), Vector2(width * 0.42, -12), Vector2(width / 2.0, 0)])
	Art.flat(ci, pts, color)


## The landmark far out between the berths (the ocean's lighthouse): a
## glowing lantern tree on a swamp islet, a radar tower on the moon. The
## lamp sits at LANDMARK_LAMP like the lighthouse's.
static func landmark(ci: CanvasItem, world: String, rock: Color, haze: Color, lit: float) -> void:
	match world:
		"acid":
			var cliff := Art.smooth_pts(PackedVector2Array([Vector2(-60, 2), Vector2(-40, -18), Vector2(-10, -28), Vector2(30, -22), Vector2(70, 2)]), 4)
			Art.flat(ci, cliff, rock)
			Art.push(ci, Vector2(0, -24))
			Art.flat(ci, _TREES[0], rock.lerp(haze, 0.2))
			Art.pop(ci)
			Art.line(ci, Vector2(24, -98), Vector2(24, -86), INK.lerp(haze, 0.3), 1.6)
			Art.toon(ci, Art.rrect_pts(Rect2(18, -86, 12, 14), 3), Props.LAMP_OFF.lerp(Color("c8ff6a"), Props._q(lit, 6.0)), 2.0, 0.0, INK.lerp(haze, 0.3))
		"moon":
			var hill := Art.smooth_pts(PackedVector2Array([Vector2(-70, 2), Vector2(-40, -22), Vector2(0, -34), Vector2(40, -24), Vector2(80, 2)]), 4)
			Art.flat(ci, hill, rock)
			var ink := INK.lerp(haze, 0.3)
			var metal := Color("dfe4ee").lerp(haze, 0.4)
			Art.toon(ci, PackedVector2Array([Vector2(-14, -30), Vector2(-3, -110), Vector2(3, -110), Vector2(14, -30)]), metal, 2.0, 0.0, ink)
			for y: float in [-56.0, -82.0]:
				Art.line(ci, Vector2(-10, y), Vector2(10, y - 8), ink, 1.6)
			Art.push(ci, Vector2(0, -112), -0.4)
			Art.toon(ci, _DISH, metal, 2.0, 0.0, ink)
			Art.pop(ci)
			Art.toon(ci, Art.circle_pts(Vector2(0, -122), 5, 12), Props.LAMP_OFF.lerp(Color("ff6a6a"), Props._q(lit, 6.0)), 2.0, 0.0, ink)
		"jungle":
			pyramid(ci, rock, haze, lit)


const LANDMARK_LAMP := Vector2(0, -122)


# --- Water surfaces ---------------------------------------------------------------------

## The front edge of the world's "sea" at the surface (drawn over hulls):
## `wave` holds the crest points left to right.
static func surface_front(ci: CanvasItem, world: String, wave: PackedVector2Array, w: float, sy: float, t: float) -> void:
	var front := wave.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	match world:
		"volcano":
			magma_front(ci, w, sy, t, DayNight.scene_tint())
		"acid":
			goo_front(ci, w, sy, t)
		"moon":
			dust_front(ci, w, sy, t)
		"jungle":
			river_front(ci, wave, w, sy, t)
		_:
			Art.flat_now(ci, front, Color(Art.calm(Art.sea_cols[0]), 0.6))
			Art.polyline(ci, wave, Art.WHITE, 4.0)


static var _PAD := Art.clipped(Art.ellipse_pts(Vector2.ZERO, Vector2(14, 4), 18), Art.union([Art.rrect_pts(Rect2(-16, -6, 30, 12), 1), PackedVector2Array([Vector2(14, -6), Vector2(18, -6), Vector2(18, 6), Vector2(14, 6)])]))


## Heat-proof trim on a lava barge, hover pads under a moon boat, slime on a
## swamp boat. Drawn in the boat's own space (origin at the waterline,
## facing +x) from the stern `e.x` to the bow `e.y` (unscaled).
static func hull_trim(ci: CanvasItem, world: String, e: Vector2, t: float) -> void:
	match world:
		"volcano":
			Art.t_rect(ci, Rect2(-e.x + 8, -8, e.x + e.y - 22, 9), 3, Color("9aa0b4"), 2.2, 0.3)
			for k in int((e.x + e.y - 30) / 22.0) + 1:
				Art.disc(ci, Vector2(-e.x + 16 + k * 22, -3.5), 1.8, Color("5a6070"))
		"acid":
			for k in 3:
				var x := lerpf(-e.x + 20, e.y - 30, k / 2.0)
				Art.toon(ci, Art.moved(_DRIP, Vector2(x, -6)), Color("8ae04a"), 1.6, 0.0)
		"jungle":
			# A garland of flowers along the gunwale.
			for k in 4:
				var x := lerpf(-e.x + 22, e.y - 34, k / 3.0)
				hibiscus(ci, Vector2(x, -9 + (k % 2) * 2), FLOWERS[k % FLOWERS.size()], 0.8)
		"moon":
			for x: float in [-e.x * 0.55, e.y * 0.5]:
				Art.t_rect(ci, Rect2(x - 10, 2, 20, 8), 3, Color("9aa2b8"), 2.0, 0.3)
				var g := 0.6 + 0.3 * sin(t * 9.0 + x)
				Art.flat_now(ci, PackedVector2Array([Vector2(x - 7, 10), Vector2(x + 7, 10), Vector2(x, 18 + g * 8.0)]), Color(0.55, 0.85, 1.0, g))


# --- Magma (the volcano's lava sea) --------------------------------------------------------
## Thick glowing magma, not water: dark cooled crust plates drift slowly on
## a bright orange-yellow skin, heavy bubbles swell and pop with sparks,
## hot currents and darker cool swirls churn slowly inside, heat shimmers
## over it. Shapes are built once and moved with Art.push; no waves.

const MAGMA_HOT := Color("fff3a6")
const MAGMA_SKIN := Color("ffbe2e")
const MAGMA_TOP := Color("ffa324")
const MAGMA_MID := Color("f05a16")
const MAGMA_DEEP := Color("9c2414")
const CRUST := Color("3b2a33")
const CRUST_HOT := Color("ff8a24")


## A glowing color seen through the scene's night tint: lava lights itself.
static func unlit(c: Color, tint: Color) -> Color:
	return Color(minf(1.0, c.r / maxf(tint.r, 0.05)), minf(1.0, c.g / maxf(tint.g, 0.05)), minf(1.0, c.b / maxf(tint.b, 0.05)), c.a)


## Still part: the molten body from the surface `top` to `bottom` and the
## warm haze over the horizon (a still layer).
static func magma_still(ci: CanvasItem, w: float, top: float, bottom: float) -> void:
	var mid := top + (bottom - top) * 0.4
	Art.grad(ci, PackedVector2Array([Vector2(0, top - 70), Vector2(w, top - 70), Vector2(w, top), Vector2(0, top)]),
			PackedColorArray([Color(1.0, 0.5, 0.15, 0.0), Color(1.0, 0.5, 0.15, 0.0), Color(1.0, 0.55, 0.18, 0.42), Color(1.0, 0.55, 0.18, 0.42)]))
	Art.grad(ci, PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, mid), Vector2(0, mid)]),
			PackedColorArray([MAGMA_TOP, MAGMA_TOP, MAGMA_MID, MAGMA_MID]))
	Art.grad(ci, PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, bottom), Vector2(0, bottom)]),
			PackedColorArray([MAGMA_MID, MAGMA_MID, MAGMA_DEEP, MAGMA_DEEP]))
	# Thick, half-cooled magma: darker cells with glowing seams between them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var y := top + 14.0
	var row := 0
	while y < bottom - 6.0:
		var x := -rng.randf_range(0.0, 30.0) - (22.0 if row % 2 == 1 else 0.0)
		var depth := clampf((y - top) / (bottom - top), 0.0, 1.0)
		var cell := Color(0.62, 0.12, 0.04, 0.16 + depth * 0.22)
		while x < w + 30.0:
			var cw := rng.randf_range(34.0, 58.0)
			var chh := rng.randf_range(16.0, 24.0)
			var pts := PackedVector2Array()
			for k in 7:
				var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
				pts.append(Vector2(x + cw / 2.0, y + chh / 2.0) + Vector2(cos(a) * cw * 0.46, sin(a) * chh * 0.46) * rng.randf_range(0.85, 1.05))
			Art.flat(ci, Art.smooth_pts(pts, 2), cell)
			x += cw + rng.randf_range(4.0, 8.0)
		y += 22.0
		row += 1


## Inside the magma (redrawn with the scene): slow cool swirls and hot
## currents, crust chunks drifting down, heavy bubbles rising.
static func magma_body(ci: CanvasItem, w: float, top: float, bottom: float, t: float) -> void:
	var h := bottom - top
	for i in 3:
		var x := fposmod(t * (4.0 + i * 1.3) + i * 157.0, w + 260.0) - 130.0
		var y := top + h * (0.42 + 0.26 * float(i % 2)) + sin(t * 0.27 + i * 1.9) * 7.0
		Art.push(ci, Vector2(x, y), sin(t * 0.18 + i) * 0.12)
		Art.flat(ci, _SWIRLS[i % 2], Color(0.48, 0.05, 0.05, 0.4))
		Art.pop(ci)
	# Glowing ribbons of hotter magma folding slowly through it.
	for i in 3:
		var x := fposmod(t * (6.0 + i * 1.7) + i * 173.0 + 60.0, w + 240.0) - 120.0
		var y := top + h * (0.24 + 0.24 * float(i)) + sin(t * 0.33 + i * 2.6) * 6.0
		Art.push(ci, Vector2(x, y), sin(t * 0.21 + i * 1.3) * 0.1)
		Art.line_c(ci, _RIBBONS[i % 2], Color(1.0, 0.82, 0.2, 0.42), 7.0)
		Art.pop(ci)
	for i in 2:
		var x := fposmod(-t * (3.0 + i) + i * 211.0, w + 200.0) - 100.0
		var y := top + h * (0.3 + 0.22 * float(i)) + sin(t * 0.4 + i * 2.3) * 6.0
		var pulse := snappedf(0.75 + 0.25 * sin(t * 0.9 + i * 2.0), 0.05)
		Art.glow(ci, Vector2(x, y), 52.0, Color(1.0, 0.86, 0.36, 0.4 * pulse), 16)
	# Crust chunks broken off the skin, sinking and turning slowly.
	for i in 3:
		var f := fposmod(t * 0.025 + i * 0.37, 1.0)
		var x := fposmod(t * 5.0 + i * 0.37 * w + 40.0, w + 60.0) - 30.0
		var y := lerpf(top + 22.0, bottom - 16.0, f)
		Art.push(ci, Vector2(x, y), t * 0.15 + i * 2.0, Vector2.ONE * (0.6 + 0.15 * float(i)))
		Art.toon(ci, _CHUNK, CRUST.lerp(MAGMA_DEEP, 0.25 + f * 0.4), 2.0, 0.5)
		Art.line_c(ci, _CHUNK_CRACK, CRUST_HOT, 1.6)
		Art.pop(ci)
	# Heavy bubbles rising slowly, wobbling as they go.
	for i in 6:
		var f := fposmod(t * 0.07 + i * 0.37, 1.0)
		var x := w * fposmod(i * 0.29 + 0.07, 1.0) + sin(t * 0.8 + i) * 4.0
		var y := lerpf(bottom - 18.0, top + 16.0, ease(f, 0.8))
		var r := (4.0 + float(i % 3) * 2.0) * (0.7 + f * 0.5)
		var sq := snappedf(sin(t * 3.0 + i) * 0.08, 0.02)
		Art.push(ci, Vector2(x, y), 0.0, Vector2(1.0 + sq, 1.0 - sq) * snappedf(r / 6.0, 0.05))
		Art.toon(ci, _BUBBLE, MAGMA_SKIN, 2.0, 0.3, Color("b8360e"))
		Art.flat(ci, _BUBBLE_SHINE, Color(1.0, 1.0, 0.85, 0.85))
		Art.pop(ci)


## The magma's front at the surface (over the hulls): the bright skin, the
## crust plates riding it, bubbles that swell and pop with sparks, embers
## and heat shimmer. `tint` is the scene's light (the lava glows anyway).
static func magma_front(ci: CanvasItem, w: float, sy: float, t: float, tint: Color) -> void:
	var crest := PackedVector2Array()
	for i in 25:
		crest.append(Vector2(w * i / 24.0, magma_y(w * i / 24.0, w, sy, t)))
	var front := crest.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	# Heat glow standing over the skin.
	var g := unlit(Color(1.0, 0.62, 0.22, 0.5), tint)
	Art.grad(ci, PackedVector2Array([Vector2(0, sy - 18), Vector2(w, sy - 18), Vector2(w, sy + 1), Vector2(0, sy + 1)]),
			PackedColorArray([Color(g, 0.0), Color(g, 0.0), g, g]))
	Art.flat_now(ci, front, unlit(MAGMA_SKIN, tint))
	Art.polyline(ci, crest, unlit(MAGMA_HOT, tint), 3.5)
	# Bubbles swelling between the plates (drawn first, plates ride over).
	for i in 4:
		var period := 3.4 + i * 0.8
		var cyc := t / period + i * 0.31
		var f := fposmod(cyc, 1.0)
		var x := w * fposmod(i * 0.27 + 0.13 + floorf(cyc) * 0.37, 1.0)
		var y := magma_y(x, w, sy, t)
		if f < 0.78:
			var s := snappedf(ease(f / 0.78, 0.6), 0.05)
			Art.push(ci, Vector2(x, y + 2.0), 0.0, Vector2(0.4 + s * 0.6, s))
			Art.toon(ci, _MDOME, unlit(Color("ffd24a"), tint), 2.0, 0.3, Color("b8360e"))
			Art.flat(ci, _MDOME_SHINE, Color(1, 1, 0.9, 0.8))
			Art.pop(ci)
		else:
			var k := (f - 0.78) / 0.22
			Art.arc(ci, Vector2(x, y), 6.0 + k * 14.0, PI * 1.05, PI * 1.95, 10, unlit(Color(1.0, 0.92, 0.55, 0.9 * (1.0 - k)), tint), 2.5)
			for j in 5:
				var a := -PI / 2.0 + (j - 2) * 0.42
				var d := Vector2(cos(a), sin(a))
				var p := Vector2(x, y) + d * 34.0 * k + Vector2(0, 46.0 * k * k)
				Art.dot(ci, p, 2.6 * (1.0 - k) + 0.6, unlit(Color(1.0, 0.85 - 0.35 * k, 0.3, 1.0 - k), tint))
	# Crust plates of every size drifting on the skin, the bright gaps
	# between them are the cracks.
	var reps := int(ceilf((w + 160.0) / PLATE_SPAN)) + 1
	var drift := fposmod(t * 4.0, PLATE_SPAN)
	for r in reps:
		for i in PLATE_ROW.size():
			var pl: Vector2 = PLATE_ROW[i]
			var x := drift + r * PLATE_SPAN + pl.x - PLATE_SPAN
			if x < -50.0 or x > w + 50.0:
				continue
			var y := magma_y(x, w, sy, t)
			var slope := magma_y(x + 10.0, w, sy, t) - magma_y(x - 10.0, w, sy, t)
			var k := int(pl.y)
			Art.push(ci, Vector2(x, y + 2.5 + float(i % 2) * 2.0), slope / 20.0 + sin(t * 0.5 + i * 1.7) * 0.025)
			Art.toon(ci, _PLATES[k], CRUST, 2.5, 0.7)
			Art.line_c(ci, _PLATE_CRACKS[k], unlit(CRUST_HOT, tint), 1.6)
			Art.pop(ci)
	# Embers lifting off the cracks and heat shimmer over the lava.
	for k in 6:
		var f := fposmod(t * 0.22 + k * 0.17, 1.0)
		var x := fposmod(k * 0.31 + 0.1, 1.0) * w + sin(t * 1.3 + k * 2.0) * 10.0 * f
		Art.dot(ci, Vector2(x, sy - 4.0 - f * 70.0), 2.2 * (1.0 - f) + 0.6, unlit(Color(1.0, 0.75, 0.3, 0.95 * (1.0 - f)), tint))
	for k in 3:
		var f := fposmod(t * 0.2 + k / 3.0, 1.0)
		var x0 := fposmod(k * 0.37 + 0.08, 1.0) * (w - 120.0)
		var pts := PackedVector2Array()
		for j in 9:
			var x := x0 + j * 15.0
			pts.append(Vector2(x, sy - 10.0 - f * 46.0 + sin(x * 0.09 + t * 3.0) * 2.0))
		Art.polyline(ci, pts, Color(1.0, 0.86, 0.62, 0.22 * sin(f * PI)), 2.0)


## Height of the magma's skin at x: a slow, heavy swell (no waves).
static func magma_y(x: float, w: float, sy: float, t: float) -> float:
	var u := x / maxf(w, 1.0) * 24.0
	return sy + sin(t * 0.45 + u * 0.55) * 1.3 + sin(t * 0.29 - u * 0.9) * 0.8


## One repeating stretch of plates: x and which plate (they drift right).
const PLATE_SPAN := 520.0
const PLATE_ROW: Array[Vector2] = [Vector2(0, 3), Vector2(104, 1), Vector2(176, 0), Vector2(300, 2), Vector2(420, 1)]
static var _PLATES: Array[PackedVector2Array] = [
	Art.smooth_pts(PackedVector2Array([Vector2(-28, 2), Vector2(-24, -4), Vector2(-10, -6.5), Vector2(10, -6), Vector2(24, -3), Vector2(28, 2), Vector2(14, 6), Vector2(-14, 6)]), 2),
	Art.smooth_pts(PackedVector2Array([Vector2(-20, 2), Vector2(-16, -5), Vector2(0, -7), Vector2(16, -4.5), Vector2(21, 1.5), Vector2(8, 6), Vector2(-12, 5.5)]), 2),
	Art.smooth_pts(PackedVector2Array([Vector2(-24, 1.5), Vector2(-20, -4), Vector2(-4, -5.5), Vector2(14, -6), Vector2(25, -1), Vector2(22, 5), Vector2(-8, 6)]), 2),
	Art.smooth_pts(PackedVector2Array([Vector2(-36, 2), Vector2(-31, -5), Vector2(-14, -7.5), Vector2(8, -6.5), Vector2(26, -7), Vector2(36, -1.5), Vector2(30, 5.5), Vector2(0, 7), Vector2(-24, 6)]), 2),
]
static var _PLATE_CRACKS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-12, -4), Vector2(-6, 0), Vector2(2, -2), Vector2(6, 2)]),
	PackedVector2Array([Vector2(-6, -4), Vector2(-1, 0), Vector2(7, -1)]),
	PackedVector2Array([Vector2(2, -4), Vector2(6, 0), Vector2(14, -1), Vector2(17, 2)]),
	PackedVector2Array([Vector2(-22, -3), Vector2(-16, 1), Vector2(-9, -2)]),
]
static var _SWIRLS: Array[PackedVector2Array] = [
	Art.smooth_pts(PackedVector2Array([Vector2(-70, 0), Vector2(-40, -14), Vector2(0, -10), Vector2(30, -18), Vector2(66, -4), Vector2(50, 10), Vector2(10, 8), Vector2(-30, 14)]), 3),
	Art.smooth_pts(PackedVector2Array([Vector2(-54, 4), Vector2(-30, -12), Vector2(10, -16), Vector2(50, -6), Vector2(40, 10), Vector2(0, 6), Vector2(-24, 14)]), 3),
]
static var _RIBBONS: Array[PackedVector2Array] = [
	Art.smooth_pts(PackedVector2Array([Vector2(-60, 4), Vector2(-30, -3), Vector2(0, 2), Vector2(26, -4), Vector2(54, 1)]), 4),
	Art.smooth_pts(PackedVector2Array([Vector2(-44, -2), Vector2(-16, 4), Vector2(14, -3), Vector2(42, 3)]), 4),
]
static var _CHUNK := Art.smooth_pts(PackedVector2Array([Vector2(-12, 2), Vector2(-9, -6), Vector2(0, -9), Vector2(10, -5), Vector2(12, 3), Vector2(2, 8), Vector2(-8, 7)]), 2)
static var _CHUNK_CRACK := PackedVector2Array([Vector2(-6, -2), Vector2(-1, 1), Vector2(5, -1)])
static var _BUBBLE := Art.circle_pts(Vector2.ZERO, 6.0, 16)
static var _BUBBLE_SHINE := Art.ellipse_pts(Vector2(-2, -2.4), Vector2(1.8, 1.2), 8, -0.6)
static var _MDOME := _dome_shape(9.0, 7.0)
static var _MDOME_SHINE := Art.ellipse_pts(Vector2(-3, -4.5), Vector2(2.2, 1.3), 8, -0.4)


static func _dome_shape(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(Vector2(rx, 2))
	pts.append(Vector2(-rx, 2))
	return pts


## Bright blobs flowing down the far volcano's lava streams (in the
## volcano's own space at `at`, height `h`).
static func volcano_flow(ci: CanvasItem, at: Vector2, h: float, t: float, tint: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(h / 220.0, h / 220.0))
	for s in _STREAM_LINES.size():
		var line: PackedVector2Array = _STREAM_LINES[s]
		for k in 3:
			var f := fposmod(t * 0.06 + k / 3.0 + s * 0.17, 1.0)
			var p := _along_line(line, f)
			Art.dot(ci, p, 3.4 - s * 0.6, unlit(Color(1.0, 0.95, 0.6, sin(f * PI) * 0.95), tint))
	var pulse := snappedf(0.6 + 0.4 * sin(t * 1.7), 0.05)
	Art.glow(ci, Vector2(0, -222), 40.0, unlit(Color(1.0, 0.7, 0.25, 0.45 * pulse), tint), 14)
	Art.pop(ci)


static var _STREAM_LINES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-10, -218), Vector2(-20, -170), Vector2(-14, -130), Vector2(-36, -80), Vector2(-40, -30)]),
	PackedVector2Array([Vector2(12, -218), Vector2(22, -160), Vector2(48, -110), Vector2(56, -60)]),
]


static func _along_line(line: PackedVector2Array, f: float) -> Vector2:
	var x := f * (line.size() - 1)
	var i := mini(int(x), line.size() - 2)
	return line[i].lerp(line[i + 1], x - i)


# --- Goo (the acid swamp) ----------------------------------------------------------------
## Thick bubbling green goo: a glossy skin with slow heavy bulges, glossy
## bubbles that swell and pop with droplets, lily pads and toadstools on
## floating logs, glowing specks inside and mist drifting over it.

const GOO_SKIN := Color("b6f04a")
const GOO_TOP := Color("8fdc3c")
const GOO_MID := Color("4fae3a")
const GOO_DEEP := Color("1f5a3a")
const GOO_SHINE := Color("f0ffc0")
const GOO_LINE := Color("2f7a2a")


## Still part: the goo's body from `top` to `bottom` with darker sludge
## lumps and pale scum spots, and a green mist over the horizon.
static func goo_still(ci: CanvasItem, w: float, top: float, bottom: float, light: float) -> void:
	var tint := Color(0.55, 0.62, 0.86).lerp(Color.WHITE, light)
	var mid := top + (bottom - top) * 0.45
	Art.grad(ci, PackedVector2Array([Vector2(0, top - 60), Vector2(w, top - 60), Vector2(w, top), Vector2(0, top)]),
			PackedColorArray([Color(0.8, 1.0, 0.7, 0.0), Color(0.8, 1.0, 0.7, 0.0), Color(0.8, 1.0, 0.7, 0.35), Color(0.8, 1.0, 0.7, 0.35)]))
	Art.grad(ci, PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, mid), Vector2(0, mid)]),
			PackedColorArray([GOO_TOP * tint, GOO_TOP * tint, GOO_MID * tint, GOO_MID * tint]))
	Art.grad(ci, PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, bottom), Vector2(0, bottom)]),
			PackedColorArray([GOO_MID * tint, GOO_MID * tint, GOO_DEEP * tint, GOO_DEEP * tint]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in int(w / 26.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(top + 16, bottom - 8))
		var depth := (p.y - top) / (bottom - top)
		var r := rng.randf_range(10, 22)
		Art.flat(ci, Art.ellipse_pts(p, Vector2(r, r * 0.62), 16, rng.randf_range(-0.3, 0.3)), Color(0.08, 0.3, 0.12, 0.12 + depth * 0.14))
	for i in int(w / 40.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(top + 10, bottom - 20))
		Art.flat(ci, Art.ellipse_pts(p, Vector2(rng.randf_range(3, 6), 2.2), 10), Color(0.9, 1.0, 0.6, 0.22))


## Inside the goo (redrawn with the scene): glowing specks, slow glossy
## bubbles rising, and lumps of sludge rolling over.
static func goo_body(ci: CanvasItem, w: float, top: float, bottom: float, t: float) -> void:
	var h := bottom - top
	for i in 3:
		var x := fposmod(t * (3.0 + i) + i * 190.0, w + 200.0) - 100.0
		var y := top + h * (0.35 + 0.25 * float(i % 2)) + sin(t * 0.3 + i * 2.0) * 6.0
		Art.push(ci, Vector2(x, y), sin(t * 0.2 + i) * 0.1)
		Art.flat(ci, _SLUDGE[i % 2], Color(0.06, 0.26, 0.1, 0.3))
		Art.pop(ci)
	for i in 8:
		var p := Vector2(fposmod(i * 0.23 + 0.05, 1.0) * w + sin(t * 0.5 + i * 1.7) * 14.0, top + 20.0 + fposmod(i * 37.0, h - 34.0) + sin(t * 0.7 + i) * 5.0)
		var tw := snappedf(0.5 + 0.5 * sin(t * 2.2 + i * 1.9), 0.1)
		Art.dot(ci, p, 1.6 + tw, Color(0.9, 1.0, 0.5, 0.35 + 0.5 * tw))
	for i in 7:
		var f := fposmod(t * 0.06 + i * 0.29, 1.0)
		var x := w * fposmod(i * 0.31 + 0.11, 1.0) + sin(t * 0.9 + i) * 5.0
		var y := lerpf(bottom - 14.0, top + 14.0, ease(f, 0.8))
		var r := (3.5 + float(i % 3) * 2.2) * (0.75 + f * 0.45)
		var sq := snappedf(sin(t * 2.6 + i) * 0.1, 0.02)
		Art.push(ci, Vector2(x, y), 0.0, Vector2(1.0 + sq, 1.0 - sq) * snappedf(r / 6.0, 0.05))
		Art.toon(ci, _BUBBLE, Color(0.85, 1.0, 0.55, 0.55), 2.0, 0.0, GOO_LINE)
		Art.flat(ci, _BUBBLE_SHINE, Color(1, 1, 1, 0.85))
		Art.pop(ci)


## The goo's front at the surface (over the hulls).
static func goo_front(ci: CanvasItem, w: float, sy: float, t: float) -> void:
	var crest := PackedVector2Array()
	for i in 25:
		crest.append(Vector2(w * i / 24.0, goo_y(w * i / 24.0, w, sy, t)))
	var front := crest.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	Art.flat_now(ci, front, GOO_SKIN)
	Art.polyline(ci, Art.moved(crest, Vector2(0, 4)), Color(GOO_TOP, 0.9), 3.0)
	Art.polyline(ci, crest, GOO_SHINE, 3.0)
	# Bubbles swelling on the skin and popping into droplets.
	for i in 5:
		var period := 2.6 + i * 0.7
		var cyc := t / period + i * 0.27
		var f := fposmod(cyc, 1.0)
		var x := w * fposmod(i * 0.23 + 0.09 + floorf(cyc) * 0.41, 1.0)
		var y := goo_y(x, w, sy, t)
		if f < 0.8:
			var s := snappedf(ease(f / 0.8, 0.5), 0.05) * (0.7 + 0.15 * float(i % 3))
			Art.push(ci, Vector2(x, y + 2.0), 0.0, Vector2(s, s))
			Art.toon(ci, _GOO_DOME, Color(0.8, 1.0, 0.5, 0.92), 2.0, 0.0, GOO_LINE)
			Art.flat(ci, _GOO_DOME_SHINE, Color(1, 1, 1, 0.9))
			Art.pop(ci)
		else:
			var k := (f - 0.8) / 0.2
			Art.arc(ci, Vector2(x, y), 6.0 + k * 12.0, PI * 1.05, PI * 1.95, 10, Color(0.9, 1.0, 0.6, 0.9 * (1.0 - k)), 2.5)
			for j in 4:
				var a := -PI / 2.0 + (j - 1.5) * 0.55
				var p := Vector2(x, y) + Vector2(cos(a), sin(a)) * 26.0 * k + Vector2(0, 40.0 * k * k)
				Art.dot(ci, p, 2.8 * (1.0 - k * 0.5), Color(0.75, 1.0, 0.4, 1.0 - k))
	# Lily pads and a floating log with toadstools, drifting slowly.
	for i in 3:
		var x := fposmod(t * 3.0 + i * w / 3.0 + 40.0, w + 80.0) - 40.0
		var y := goo_y(x, w, sy, t)
		Art.push(ci, Vector2(x, y + 2.0), sin(t * 0.6 + i) * 0.06)
		if i == 1:
			Art.toon(ci, _LOG, Color("8a6a44"), 2.5, 0.5)
			Art.t_ellipse(ci, Vector2(22, -1), Vector2(3.5, 4.5), Color("c8a070"), 2.0, 0.0)
			for m: Vector3 in [Vector3(-12, 0.55, 0), Vector3(2, 0.75, 1), Vector3(12, 0.45, 0)]:
				Art.push(ci, Vector2(m.x, -5), 0.0, Vector2(m.y, m.y))
				mushroom(ci, [Color("ff6fae"), Color("c86bff"), Color("ffd23f")][int(m.z) + (1 if m.x > 0 else 0)], 0.0, int(m.z))
				Art.pop(ci)
		else:
			Art.toon(ci, _PAD, Color("5ab84a"), 2.0, 0.4)
			if i == 2:
				Art.push(ci, Vector2(-4, -3))
				Art.toon(ci, _LILY, Color("ff9fd0"), 1.6, 0.3)
				Art.pop(ci)
		Art.pop(ci)
	# Mist banks drifting over the swamp.
	for k in 3:
		var x := fposmod(t * (5.0 + k * 2.0) + k * w * 0.4, w + 260.0) - 130.0
		Art.push(ci, Vector2(x, sy - 6.0 - float(k % 2) * 10.0))
		Art.flat(ci, _MIST, Color(0.9, 1.0, 0.86, 0.3))
		Art.pop(ci)


## Height of the goo's skin at x: slow thick bulges.
static func goo_y(x: float, w: float, sy: float, t: float) -> float:
	var u := x / maxf(w, 1.0) * 24.0
	return sy + sin(t * 0.6 + u * 0.5) * 1.6 + sin(t * 0.37 - u * 1.1) * 1.0


static var _SLUDGE: Array[PackedVector2Array] = [
	Art.smooth_pts(PackedVector2Array([Vector2(-50, 0), Vector2(-30, -12), Vector2(6, -14), Vector2(40, -8), Vector2(52, 4), Vector2(20, 12), Vector2(-26, 10)]), 3),
	Art.smooth_pts(PackedVector2Array([Vector2(-40, 2), Vector2(-16, -10), Vector2(24, -12), Vector2(44, 0), Vector2(16, 10), Vector2(-20, 10)]), 3),
]
static var _GOO_DOME := _dome_shape(10.0, 9.0)
static var _GOO_DOME_SHINE := Art.ellipse_pts(Vector2(-3.5, -5), Vector2(2.6, 1.6), 8, -0.5)
static var _LOG := Art.rrect_pts(Rect2(-26, -6, 52, 10), 5)
static var _LILY := Art.star_pts(Vector2.ZERO, 5.5, 2.4, 5)
static var _MIST := Art.union([Art.ellipse_pts(Vector2.ZERO, Vector2(90, 12), 24), Art.ellipse_pts(Vector2(-30, -8), Vector2(40, 12), 18),
		Art.ellipse_pts(Vector2(34, -6), Vector2(46, 11), 18)])


# --- Moon dust plain ---------------------------------------------------------------------
## The moon's "sea" is a plain of grey dust: layered regolith seen in cut,
## buried rocks and glinting crystals, craters along the surface, and dust
## puffs that rise slowly and float down (low gravity).

const DUST_TOP := Color("c9cde0")
const DUST_MID := Color("9fa5c2")
const DUST_DEEP := Color("5e6488")


## Still part: the regolith from `top` to `bottom` (layers, rocks, crystals).
static func dust_still(ci: CanvasItem, w: float, top: float, bottom: float, light: float) -> void:
	var tint := Color(0.7, 0.72, 0.9).lerp(Color.WHITE, light)
	var mid := top + (bottom - top) * 0.45
	Art.grad(ci, PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, mid), Vector2(0, mid)]),
			PackedColorArray([DUST_TOP * tint, DUST_TOP * tint, DUST_MID * tint, DUST_MID * tint]))
	Art.grad(ci, PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, bottom), Vector2(0, bottom)]),
			PackedColorArray([DUST_MID * tint, DUST_MID * tint, DUST_DEEP * tint, DUST_DEEP * tint]))
	# Layers of dust and gravel.
	for i in 3:
		var y := top + 30.0 + i * 36.0
		var band := PackedVector2Array()
		for k in 13:
			band.append(Vector2(lerpf(-10, w + 10, k / 12.0), y + sin(k * 1.7 + i * 2.0) * 5.0))
		for k in 13:
			band.append(Vector2(lerpf(w + 10, -10, k / 12.0), y + 9.0 + sin((12 - k) * 1.3 + i) * 4.0))
		Art.flat(ci, band, Color(0.25, 0.27, 0.45, 0.12 + i * 0.03))
	# Craters cut through: dark bowls under the surface with bright rims.
	for c: Vector3 in [Vector3(0.3, 46, 18), Vector3(0.66, 34, 14), Vector3(0.93, 40, 16)]:
		var cx := w * c.x
		var bowl := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			bowl.append(Vector2(cx + cos(a) * c.y, top + 2.0 + sin(a) * c.z))
		Art.flat(ci, bowl, Art.shade_of(DUST_MID * tint, 0.3))
		Art.flat(ci, Art.moved(Art.ellipse_pts(Vector2(cx, top + 4.0), Vector2(c.y * 0.7, c.z * 0.35), 14), Vector2(-c.y * 0.15, 0)), Art.shade_of(DUST_MID * tint, 0.45))
		var rim := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			rim.append(Vector2(cx + cos(a) * c.y, top + 2.0 + sin(a) * c.z))
		Art.polyline(ci, rim, (DUST_TOP * tint).lightened(0.2), 2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in int(w / 60.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(top + 24, bottom - 10))
		var r := rng.randf_range(4.0, 9.0)
		Art.push(ci, p, rng.randf_range(-0.6, 0.6), Vector2(r / 10.0, r / 10.0))
		Art.toon(ci, _MOON_ROCKS[i % 2], (DUST_MID * tint).darkened(0.15), 2.0, 0.6)
		Art.pop(ci)
	for i in 3:
		var p := Vector2(w * (0.2 + i * 0.3) + rng.randf_range(-20, 20), rng.randf_range(top + 50, bottom - 16))
		Art.crystal(ci, p, 16, 5, rng.randf_range(-0.4, 0.4), Color("9fe0ff") if i != 1 else Color("c8a0ff"), 2.0)


## Glints of the crystals and dust drifting very slowly in the cut.
static func dust_body(ci: CanvasItem, w: float, top: float, bottom: float, t: float) -> void:
	for i in 5:
		var p := Vector2(fposmod(i * 0.21 + 0.08, 1.0) * w, top + 24.0 + fposmod(i * 41.0, bottom - top - 40.0))
		var tw := snappedf(0.5 + 0.5 * sin(t * 1.8 + i * 2.3), 0.1)
		if tw > 0.6:
			Art.push(ci, p, 0.0, Vector2.ONE * (tw - 0.4) * 1.6)
			Art.toon(ci, _GLINT, Color(1, 1, 1, 0.9), 0.0, 0.0)
			Art.pop(ci)


## The dust plain's surface over the hulls: its edge with crater rims and
## pebbles, and dust puffs that rise and drift down slowly.
static func dust_front(ci: CanvasItem, w: float, sy: float, t: float) -> void:
	var tint := Color.WHITE
	var edge := PackedVector2Array()
	for i in 25:
		var x := w * i / 24.0
		edge.append(Vector2(x, sy + sin(i * 1.9) * 1.2))
	var front := edge.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	Art.flat(ci, front, DUST_TOP * tint)
	Art.polyline(ci, edge, (DUST_TOP * tint).lightened(0.25), 3.0)
	for c: Vector3 in [Vector3(0.14, 1.5, 0), Vector3(0.47, 1.0, 1), Vector3(0.8, 1.3, 2)]:
		Art.push(ci, Vector2(w * c.x, sy + 7.0), 0.0, Vector2(c.z * 0.1 + 0.9, 0.85) * c.y)
		Art.toon(ci, _CRATER_RIM, (DUST_TOP * tint).lightened(0.1), 2.2, 0.0)
		Art.flat(ci, _CRATER_IN, Art.shade_of(DUST_MID * tint, 0.25))
		Art.flat(ci, _CRATER_LIP, Art.shade_of(DUST_MID * tint, 0.1))
		Art.pop(ci)
	for i in 6:
		var x := w * fposmod(i * 0.17 + 0.04, 1.0)
		Art.t_ellipse(ci, Vector2(x, sy + 3.0), Vector2(4.5, 3.0), (DUST_MID * tint).darkened(0.05), 1.8, 0.4)
	# Dust puffs: kicked up, they rise slowly and sink back (low gravity).
	for i in 3:
		var period := 5.0 + i * 1.3
		var cyc := t / period + i * 0.37
		var f := fposmod(cyc, 1.0)
		var x := w * fposmod(i * 0.29 + 0.18 + floorf(cyc) * 0.43, 1.0)
		for j in 5:
			var a := -PI / 2.0 + (j - 2) * 0.45
			var v := Vector2(cos(a), sin(a)) * 46.0
			var p := Vector2(x, sy) + v * f + Vector2(0, 46.0 * f * f)
			var r := 3.0 + f * 6.0
			Art.dot(ci, p, r, Color(0.92, 0.93, 1.0, 0.55 * (1.0 - f)))


static var _MOON_ROCKS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-12, 3), Vector2(-9, -6), Vector2(1, -9), Vector2(11, -4), Vector2(12, 4), Vector2(3, 8), Vector2(-7, 7)]),
	PackedVector2Array([Vector2(-10, 4), Vector2(-11, -3), Vector2(-3, -8), Vector2(8, -7), Vector2(13, 1), Vector2(6, 7)]),
]
static var _GLINT := Art.star_pts(Vector2.ZERO, 6, 1.4, 4)


## The moon's sky (a still layer): a band of the Milky Way with a soft
## nebula glow and many small stars, fading near the horizon.
static func moon_sky(ci: CanvasItem, w: float, sy: float, stars: float) -> void:
	var a := stars
	if a < 0.02:
		return
	Art.push(ci, Vector2(w * 0.5, sy * 0.42), -0.38)
	Art.flat(ci, _MILKY, Color(0.5, 0.42, 0.95, 0.2 * a))
	Art.flat(ci, _MILKY_CORE, Color(0.78, 0.72, 1.0, 0.18 * a))
	Art.flat(ci, _NEBULA, Color(1.0, 0.45, 0.8, 0.16 * a))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 40:
		var p := Vector2(rng.randf_range(-w * 0.75, w * 0.75), rng.randf_range(-34, 34) * (1.0 - absf(rng.randf_range(-1, 1)) * 0.5))
		Art.disc(ci, p, rng.randf_range(0.8, 1.6), Color(1, 1, 1, rng.randf_range(0.4, 0.9) * a))
	Art.pop(ci)


static var _MILKY := Art.union([Art.ellipse_pts(Vector2.ZERO, Vector2(560, 50), 32), Art.ellipse_pts(Vector2(-180, 8), Vector2(200, 62), 24),
		Art.ellipse_pts(Vector2(200, -6), Vector2(220, 58), 24)])
static var _MILKY_CORE := Art.ellipse_pts(Vector2(0, 2), Vector2(420, 18), 28)
static var _NEBULA := Art.union([Art.ellipse_pts(Vector2(120, -10), Vector2(70, 34), 20), Art.ellipse_pts(Vector2(160, 14), Vector2(50, 24), 16)])


# --- Jungle ruins --------------------------------------------------------------------------
## A clear turquoise jungle river under a warm sunny sky: emerald rainforest
## hills and a waterfall far away, a stepped temple pyramid with a glowing
## sun disc, a golden-stone shore with temple steps, a hut on bamboo stilts,
## a big palm with coconuts and a parrot, lily pads and lotus flowers
## drifting on the current, fish leaping, parrots and butterflies by day,
## fireflies at night. Every shape is built once and placed with Art.push.

const LEAF := Color("2fae4e")
const LEAF_DARK := Color("1f8442")
const LEAF_LIGHT := Color("6ad65a")
const TEMPLE := Color("e2c07c")
const BAMBOO := Color("d2a650")
const BAMBOO_DARK := Color("9a7432")
const THATCH := Color("e4b252")
const RIVER_FOAM := Color("e6fff8")
const PAD := Color("48c25a")
const LOTUS := Color("ff9fd0")
const FLOWERS: Array[Color] = [Color("ff4f6e"), Color("ff8a3d"), Color("ffd23f"), Color("ff6fd0"), Color("b06bff")]
## Where the pyramid's sun disc glows (landmark-local, like LANDMARK_LAMP).
const JUNGLE_LAMP := Vector2(0, -124)
## The jungle palm's crown (edge-prop local).
const JPALM_TOP := Vector2(-20, -132)


## A broad leaf pointing +x from its stem (about 48 long at s = 1).
static func leaf(ci: CanvasItem, at: Vector2, rot: float, s: float, fill: Color) -> void:
	Art.push(ci, at, rot, Vector2(s, s))
	Art.toon(ci, _LEAF, fill, 2.2, 0.5)
	Art.line_c(ci, _LEAF_RIB, Art.shade_of(fill, 0.28), 1.6)
	Art.pop(ci)


static var _LEAF := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(10, -8), Vector2(26, -10), Vector2(40, -5), Vector2(50, 1),
		Vector2(38, 6), Vector2(22, 8), Vector2(8, 5)]), 3)
static var _LEAF_RIB := PackedVector2Array([Vector2(3, 0), Vector2(22, -1), Vector2(42, 1)])


## A serrated palm frond along +x (its tip droops by `droop`).
static func _frond_pts(length: float, width: float, droop: float, n: int) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var x := f * length + (3.0 if i % 2 == 1 else 0.0)
		var y := droop * f * f
		var wd := width * sin(PI * pow(f, 0.75))
		var notch := 0.5 if i % 2 == 1 else 1.0
		top.append(Vector2(x, y - wd * notch))
		bot.append(Vector2(x, y + wd * notch * 0.75))
	bot.reverse()
	top.append_array(bot)
	return top


static func _rib(length: float, droop: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var f := i / 5.0
		pts.append(Vector2(f * length * 0.95, droop * f * f))
	return pts


static var _FRONDS: Array[PackedVector2Array] = [_frond_pts(66, 12, 18, 16), _frond_pts(56, 11, 22, 14), _frond_pts(46, 9, 12, 12)]
static var _FROND_RIBS: Array[PackedVector2Array] = [_rib(66, 18), _rib(56, 22), _rib(46, 12)]


## One palm frond from `at` towards angle `a` (mirrored on the left, so it
## always droops down).
static func frond(ci: CanvasItem, at: Vector2, a: float, k: int, fill: Color, s: float = 1.0) -> void:
	var left := cos(a) < 0.0
	Art.push(ci, at, a, Vector2(s, -s if left else s))
	Art.toon(ci, _FRONDS[k % 3], fill, 2.2, 0.45)
	Art.line_c(ci, _FROND_RIBS[k % 3], Art.shade_of(fill, 0.3), 1.8)
	Art.pop(ci)


## A small fern (four fronds) standing on the ground; origin at its foot.
static func fern(ci: CanvasItem, s: float, fill: Color = LEAF) -> void:
	for a: float in [-2.5, -1.95, -1.2, -0.65]:
		frond(ci, Vector2.ZERO, a, 2, fill if a < -1.5 else fill.lightened(0.08), s * 0.62)


## Hibiscus flower (five round petals and a yellow heart).
static func hibiscus(ci: CanvasItem, at: Vector2, c: Color, s: float = 1.0) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.toon(ci, _HIBISCUS, c, 1.8, 0.35)
	Art.disc(ci, Vector2.ZERO, 2.4, Color("ffe36a"))
	Art.pop(ci)


static func _petals(n: int, d: float, r: float) -> PackedVector2Array:
	var parts := []
	for i in n:
		var a := TAU * i / n - PI / 2.0
		parts.append(Art.circle_pts(Vector2(cos(a), sin(a)) * d, r, 12))
	return Art.union(parts)


static var _HIBISCUS := _petals(5, 4.6, 4.4)


## A pink lotus flower (sits on a lily pad); origin at its foot.
static func lotus(ci: CanvasItem, c: Color = LOTUS) -> void:
	for a: float in [-1.15, 1.15, -0.6, 0.6, 0.0]:
		Art.push(ci, Vector2.ZERO, a)
		Art.toon(ci, _PETAL, c if absf(a) > 0.1 else c.lightened(0.2), 1.6, 0.3)
		Art.pop(ci)
	Art.disc(ci, Vector2(0, -3), 2.4, Color("ffe36a"))


static var _PETAL := Art.smooth_pts(PackedVector2Array([Vector2(0, 1), Vector2(-4, -5), Vector2(0, -12), Vector2(4, -5)]), 2)


## A lily pad (with its notch) lying on the water; origin at its middle.
static func lily_pad(ci: CanvasItem, fill: Color = PAD) -> void:
	Art.toon(ci, _PAD, fill, 2.0, 0.4)
	Art.line_c(ci, _PAD_VEINS, Art.shade_of(fill, 0.22), 1.2)


static var _PAD_VEINS := PackedVector2Array([Vector2(-11, -1), Vector2(0, 0), Vector2(9, -2.5), Vector2(0, 0), Vector2(8, 2.5)])


# --- Jungle sky -----------------------------------------------------------------------------

## The jungle's sky extras (a still layer): golden humid haze over the
## horizon and soft sunbeams fanning down from the sun.
static func jungle_sky(ci: CanvasItem, w: float, sy: float, sun: Vector2, day: float, warm: float) -> void:
	if day < 0.05:
		return
	var haze := Color(1.0, 0.94, 0.66, 0.0)
	Art.grad(ci, PackedVector2Array([Vector2(0, sy - 150), Vector2(w, sy - 150), Vector2(w, sy + 2), Vector2(0, sy + 2)]),
			PackedColorArray([haze, haze, Color(haze, 0.3 * day), Color(haze, 0.3 * day)]))
	if sun.y > sy:
		return
	var a := Props._q(day * (1.0 - warm * 0.5), 8.0) * 0.16
	for i in 6:
		var ang := 0.55 + i * 0.36
		var len := 640.0
		var c := Color(1.0, 0.97, 0.78, a * (1.0 if i % 2 == 0 else 0.6))
		var clear := Color(c, 0.0)
		var spread := 0.05 + (i % 3) * 0.02
		Art.grad(ci, PackedVector2Array([sun, sun + Vector2(cos(ang - spread), sin(ang - spread)) * len, sun + Vector2(cos(ang + spread), sin(ang + spread)) * len]),
				PackedColorArray([c, clear, clear]))


## A vine hanging from the top edge with leaves along it; origin at its top.
## `k` picks one of the vines; sway is done by the caller's push.
static func vine(ci: CanvasItem, k: int, tint: Color) -> void:
	var v: Array = _VINES[k % _VINES.size()]
	Art.line_c(ci, v[0], Color("3d7a32") * tint, 3.4)
	for l: Vector3 in v[1]:
		leaf(ci, Vector2(l.x, l.y), l.z, 0.42, (LEAF if int(l.y) % 3 != 0 else LEAF_LIGHT) * tint)
	if v.size() > 2:
		var f: Vector3 = v[2]
		hibiscus(ci, Vector2(f.x, f.y), FLOWERS[int(f.z)] * tint, 0.8)


static func _vine_shape(len: float, seed: float, flower: int) -> Array:
	var pts := PackedVector2Array()
	var leaves := []
	var n := int(len / 12.0)
	for i in n + 1:
		var f := float(i) / n
		pts.append(Vector2(sin(f * 5.0 + seed) * 6.0 * f, f * len))
	for i in range(1, n + 1, 2):
		var p := pts[i]
		var side := 1.0 if (i / 2) % 2 == 0 else -1.0
		leaves.append(Vector3(p.x, p.y, (0.55 if side > 0 else PI - 0.55) + sin(seed + i) * 0.2))
	var out := [pts, leaves]
	if flower >= 0:
		out.append(Vector3(pts[n].x, pts[n].y + 2.0, flower))
	return out


static var _VINES: Array = [_vine_shape(150, 0.0, 1), _vine_shape(96, 1.3, 3), _vine_shape(210, 2.2, 0), _vine_shape(70, 3.1, -1), _vine_shape(130, 4.4, 2)]


## A cluster of big leaves hanging into the sky from a top corner (the
## canopy); `side` -1 for the left corner, +1 for the right one.
static func canopy(ci: CanvasItem, side: float, tint: Color) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(side, 1))
	for l: Vector4 in _CANOPY:
		var c: Color = [LEAF_DARK, LEAF, LEAF_LIGHT][int(l.w)] * tint
		Art.push(ci, Vector2(l.x, l.y), l.z, Vector2(1.5, 1.5))
		Art.toon(ci, _LEAF, c, 2.4, 0.5)
		Art.line_c(ci, _LEAF_RIB, Art.shade_of(c, 0.28), 1.4)
		Art.pop(ci)
	Art.pop(ci)


const _CANOPY: Array[Vector4] = [Vector4(-10, -14, 0.9, 0), Vector4(30, -18, 1.3, 0), Vector4(70, -16, 1.6, 0), Vector4(-6, 8, 0.45, 1),
		Vector4(40, -6, 1.05, 1), Vector4(84, -10, 1.75, 1), Vector4(14, 20, 1.2, 2), Vector4(110, -16, 1.4, 1), Vector4(56, 6, 1.9, 2)]


## A scarlet macaw flying +x (wings beat with `flap` -1..1).
static func parrot(ci: CanvasItem, flap: float) -> void:
	var up := flap * 12.0
	Art.toon(ci, _MACAW_TAIL, Color("e8323c"), 1.8, 0.2)
	Art.flat(ci, _MACAW_TAIL_TIP, Color("2f7ef0"))
	for side: float in [1.0, -1.0]:
		var tipy := -4.0 - up
		var wing := PackedVector2Array([Vector2(-6, -1), Vector2(-4 + side * 2.0, tipy * 0.5 - 3.0), Vector2(-14 + side * 4.0, tipy - 6.0),
				Vector2(-20 + side * 3.0, tipy - 3.0), Vector2(-12, 3)])
		if side > 0.0:
			# The far wing first, a little darker.
			Props.live(ci, Art.moved(wing, Vector2(5, -1)), Color("2f6ad8"), 1.8)
		else:
			Props.live(ci, wing, Color("2f7ef0"), 2.0)
			var inner := PackedVector2Array([wing[0], wing[1], wing[1].lerp(wing[2], 0.55), wing[4].lerp(wing[3], 0.45), wing[4]])
			Art.flat_now(ci, inner, Color("ffd23f"))
			Art.flat_now(ci, PackedVector2Array([wing[0], wing[1], wing[1].lerp(wing[4], 0.5)]), Color("e8323c"))
	Art.t_ellipse(ci, Vector2(0, 1), Vector2(10, 5.5), Color("e8323c"), 2.0, 0.4)
	Art.t_circle(ci, Vector2(10, -3), 5.5, Color("ef3a40"), 2.0, 0.3)
	Art.t_ellipse(ci, Vector2(11.5, -3), Vector2(3.0, 2.6), Art.WHITE, 0.0, 0.0)
	Art.disc(ci, Vector2(12, -3.5), 1.3, INK)
	Art.toon(ci, _MACAW_BEAK, Color("3a3040"), 1.4, 0.0)
	Art.flat(ci, _MACAW_BEAK_TOP, Color("f4eadc"))


static var _MACAW_TAIL := PackedVector2Array([Vector2(-6, -1), Vector2(-30, 3), Vector2(-33, 7), Vector2(-28, 8), Vector2(-6, 4)])
static var _MACAW_TAIL_TIP := Art.clipped(Art.rrect_pts(Rect2(-34, 0, 9, 10), 1), _MACAW_TAIL)
static var _MACAW_BEAK := Art.smooth_pts(PackedVector2Array([Vector2(14, -6), Vector2(19, -5), Vector2(20, -1), Vector2(17, 1), Vector2(14, -1)]), 2)
static var _MACAW_BEAK_TOP := PackedVector2Array([Vector2(14.5, -5.5), Vector2(18.5, -4.8), Vector2(19, -3), Vector2(15, -3)])


## A macaw sitting (on the palm), looking left; origin at its feet.
static func parrot_sitting(ci: CanvasItem, blink: bool) -> void:
	Art.toon(ci, _SIT_TAIL, Color("e8323c"), 1.8, 0.2)
	Art.flat(ci, _SIT_TAIL_TIP, Color("2f7ef0"))
	Art.t_ellipse(ci, Vector2(0, -12), Vector2(7, 11), Color("e8323c"), 2.0, 0.45)
	Art.toon(ci, _SIT_WING, Color("2f7ef0"), 1.8, 0.3)
	Art.flat(ci, _SIT_WING_BAND, Color("ffd23f"))
	Art.t_circle(ci, Vector2(-2, -25), 6.5, Color("ef3a40"), 2.0, 0.3)
	Art.t_ellipse(ci, Vector2(-4, -25), Vector2(3.4, 3.0), Art.WHITE, 0.0, 0.0)
	if blink:
		Art.line(ci, Vector2(-5.5, -25), Vector2(-2.5, -25), INK, 1.4)
	else:
		Art.disc(ci, Vector2(-4, -25.5), 1.4, INK)
	Art.push(ci, Vector2(6, -22), 0.0, Vector2(-1, 1))
	Art.toon(ci, _MACAW_BEAK, Color("3a3040"), 1.4, 0.0)
	Art.flat(ci, _MACAW_BEAK_TOP, Color("f4eadc"))
	Art.pop(ci)
	for x: float in [-3.0, 3.0]:
		Art.line(ci, Vector2(x, -2), Vector2(x, 1), Color("3a3040"), 2.0)


static var _SIT_TAIL := PackedVector2Array([Vector2(-2, -6), Vector2(4, -6), Vector2(8, 18), Vector2(4, 20)])
static var _SIT_TAIL_TIP := Art.clipped(Art.rrect_pts(Rect2(0, 10, 12, 12), 1), _SIT_TAIL)
static var _SIT_WING := Art.smooth_pts(PackedVector2Array([Vector2(1, -20), Vector2(8, -16), Vector2(9, -4), Vector2(5, 2), Vector2(1, -6)]), 2)
static var _SIT_WING_BAND := Art.clipped(Art.rrect_pts(Rect2(0, -20, 12, 6), 1), _SIT_WING)


## A blue morpho butterfly; `open` 0..1 how far its wings are spread.
static func butterfly(ci: CanvasItem, open: float, c: Color) -> void:
	var o := maxf(0.3, snappedf(open, 0.1))
	for side: float in [-1.0, 1.0]:
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(side * o, 1.0))
		Art.toon(ci, _BF_LOW, c.darkened(0.12), 1.8, 0.2)
		Art.toon(ci, _BF_UP, c, 1.8, 0.2)
		Art.flat(ci, _BF_EDGE, Color(0.12, 0.08, 0.2, 0.45))
		Art.disc(ci, Vector2(10, -7), 1.6, Art.WHITE)
		Art.pop(ci)
	Art.t_ellipse(ci, Vector2(0, 0), Vector2(1.8, 6), Color("2a2238"), 1.2, 0.0)
	Art.line(ci, Vector2(0, -5), Vector2(-3, -11), INK, 1.2)
	Art.line(ci, Vector2(0, -5), Vector2(3, -11), INK, 1.2)


static var _BF_UP := Art.smooth_pts(PackedVector2Array([Vector2(1, -2), Vector2(4, -10), Vector2(12, -12), Vector2(15, -6), Vector2(10, 0), Vector2(2, 1)]), 2)
static var _BF_LOW := Art.smooth_pts(PackedVector2Array([Vector2(1, 0), Vector2(9, 1), Vector2(11, 7), Vector2(6, 10), Vector2(2, 6)]), 2)
static var _BF_EDGE := _bf_edge()


static func _bf_edge() -> PackedVector2Array:
	# The dark rim of the upper wing: the wing minus a smaller copy of it.
	var inner := PackedVector2Array()
	var c := Vector2(5, -5)
	for p in _BF_UP:
		inner.append(c + (p - c) * 0.8)
	var g := Geometry2D.clip_polygons(_BF_UP, inner)
	return g[0] if g.size() > 0 else PackedVector2Array()


## A rainbow arc (after a rain shower); `a` 0..1 fades it.
static func rainbow(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	if a < 0.02:
		return
	var cols: Array[Color] = [Color("ff5a5a"), Color("ffa040"), Color("ffe14a"), Color("6ad65a"), Color("4fb3ee"), Color("9a7aff")]
	for i in cols.size():
		Art.arc(ci, c, r - i * 4.0, PI * 1.08, PI * 1.92, 22, Color(cols[i], snappedf(0.5 * a, 0.05)), 4.2)


# --- Jungle far away -------------------------------------------------------------------------

## Rainforest hills on the horizon (a still layer), three layers fading
## into the humid haze: a far misty ridge with tall kapok trees standing
## over it, a middle canopy of round crowns, and a darker near canopy with
## palms sticking out of it. Mist lies between the layers.
static func jungle_hills(ci: CanvasItem, w: float, sy: float, far_c: Color, near_c: Color, mist: float) -> void:
	var mid_c := far_c.lerp(near_c, 0.5)
	var m := Color(1.0, 0.98, 0.9, 0.0)
	Art.flat(ci, _canopy_line(w, sy, 76.0, 30.0, 12.0, 0.0045, 0.035, 1.2, 8.0), far_c)
	for f: Vector3 in [Vector3(0.06, 0.95, 0), Vector3(0.24, 1.15, 1), Vector3(0.43, 0.85, 0), Vector3(0.62, 1.05, 1), Vector3(0.83, 0.9, 0), Vector3(0.97, 1.1, 1)]:
		var tx := w * f.x
		Art.push(ci, Vector2(tx, _line_y(tx, sy, 76.0, 30.0, 12.0, 0.0045, 0.035, 1.2) + 8.0), 0.0, Vector2(f.y, f.y))
		Art.flat(ci, _KAPOK[int(f.z)], far_c)
		Art.pop(ci)
	Art.grad(ci, PackedVector2Array([Vector2(0, sy - 96), Vector2(w, sy - 96), Vector2(w, sy - 40), Vector2(0, sy - 40)]),
			PackedColorArray([m, m, Color(m, 0.3 * mist), Color(m, 0.3 * mist)]))
	Art.flat(ci, _canopy_line(w, sy, 44.0, 16.0, 14.0, 0.008, 0.052, 0.4, 7.0), mid_c)
	Art.grad(ci, PackedVector2Array([Vector2(0, sy - 52), Vector2(w, sy - 52), Vector2(w, sy - 14), Vector2(0, sy - 14)]),
			PackedColorArray([m, m, Color(m, 0.26 * mist), Color(m, 0.26 * mist)]))
	for f: Vector3 in [Vector3(0.12, 0.9, 1), Vector3(0.35, 0.75, -1), Vector3(0.55, 1.0, 1), Vector3(0.78, 0.8, -1), Vector3(0.9, 0.95, 1)]:
		var tx := w * f.x
		Art.push(ci, Vector2(tx, _line_y(tx, sy, 22.0, 10.0, 12.0, 0.011, 0.07, 2.1) + 6.0), 0.0, Vector2(f.y * f.z, f.y))
		Art.flat(ci, _FAR_PALM, near_c)
		Art.pop(ci)
	Art.flat(ci, _canopy_line(w, sy, 22.0, 10.0, 12.0, 0.011, 0.07, 2.1, 6.0), near_c)


## A canopy silhouette: a slow swell with round tree crowns along its top.
static func _canopy_line(w: float, sy: float, base: float, swell: float, crowns: float, f1: float, f2: float, ph: float, step: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := -10.0
	while x <= w + 10.0:
		pts.append(Vector2(x, _line_y(x, sy, base, swell, crowns, f1, f2, ph)))
		x += step
	pts.append(Vector2(w + 10, sy + 2))
	pts.append(Vector2(-10, sy + 2))
	return pts


static func _line_y(x: float, sy: float, base: float, swell: float, crowns: float, f1: float, f2: float, ph: float) -> float:
	# Crowns of uneven size: two bumpy waves, the bigger one wins.
	var c := maxf(absf(sin(x * f2 + ph)), 0.8 * absf(sin(x * f2 * 1.618 + ph * 2.0)))
	return sy - base - swell * (0.5 + 0.5 * sin(x * f1 + ph)) - crowns * sqrt(c)


static var _KAPOK: Array[PackedVector2Array] = [
	Art.union([Art.rrect_pts(Rect2(-3, -50, 6, 54), 2), Art.ellipse_pts(Vector2(0, -56), Vector2(30, 10), 18), Art.ellipse_pts(Vector2(-16, -62), Vector2(15, 8), 12),
		Art.ellipse_pts(Vector2(12, -64), Vector2(16, 9), 12), Art.ellipse_pts(Vector2(-2, -66), Vector2(10, 7), 10)]),
	Art.union([Art.rrect_pts(Rect2(-2.5, -40, 5, 44), 2), Art.ellipse_pts(Vector2(0, -46), Vector2(22, 8), 16), Art.ellipse_pts(Vector2(10, -51), Vector2(12, 7), 12),
		Art.ellipse_pts(Vector2(-9, -50), Vector2(11, 6), 10)]),
]
static var _FAR_PALM := _far_palm()


static func _far_palm() -> PackedVector2Array:
	var parts := [Geometry2D.offset_polyline(PackedVector2Array([Vector2(0, 2), Vector2(3, -16), Vector2(8, -32)]), 2.2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]]
	for a: float in [-2.7, -2.0, -1.3, -0.6, 0.1]:
		var d := Vector2(cos(a), sin(a))
		parts.append(Art.ellipse_pts(Vector2(8, -32) + d * 12.0 + Vector2(0, 3.0 * absf(d.x)), Vector2(13, 3.5), 12, a + (0.35 if d.x > 0.0 else -0.35)))
	return Art.union(parts)


## A waterfall far away: a mossy cliff with trees on top, the water pouring
## over its lip in two strands with streaks running down, a white foam cloud
## at its foot and spray drifting up. Origin at its foot, `h` tall.
static func waterfall(ci: CanvasItem, h: float, rock: Color, canopy_c: Color, water: Color, t: float, foam: Color = Color.WHITE, poke: float = 0.0) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(h / 120.0, h / 120.0))
	Art.flat(ci, _FALL_CLIFF, rock)
	Art.flat(ci, _FALL_SHADE, rock.darkened(0.14))
	for p: Vector3 in [Vector3(-44, -112, 20), Vector3(-20, -124, 18), Vector3(22, -124, 20), Vector3(46, -110, 18), Vector3(-56, -80, 12), Vector3(58, -74, 12)]:
		Art.flat(ci, Art.ellipse_pts(Vector2(p.x, p.y), Vector2(p.z, p.z * 0.6), 14), canopy_c)
	Art.flat(ci, _FALL_SHEET, water)
	Art.flat(ci, _FALL_LIGHT, water.lightened(0.35))
	Art.pop(ci)
	var s := h / 120.0
	# Streaks running down the two strands.
	for k in 6:
		var x := (-12.0 + k * 4.6 + (3.0 if k > 2 else 0.0)) * s
		var f := fposmod(t * 0.85 + k * 0.29, 1.0)
		var y0 := -h + 4.0 + f * (h - 18.0)
		Art.line(ci, Vector2(x * (1.0 + f * 0.25), y0), Vector2(x * (1.0 + f * 0.3), minf(y0 + 18.0, -10.0)), Color(foam, 0.8), 2.2)
	Art.polyline(ci, PackedVector2Array([Vector2(-17 * s, -h + 3), Vector2(-6 * s, -h - 1), Vector2(6 * s, -h - 1), Vector2(17 * s, -h + 3)]), Color(foam, 0.95), 3.0)
	# The foam cloud at its foot and spray rising off it.
	var puff := 1.0 + snappedf(poke, 0.05) * 0.5
	Art.push(ci, Vector2(0, -4), 0.0, Vector2(s * puff, s * puff))
	Art.flat(ci, _FOAM, Color(foam, 0.9))
	Art.pop(ci)
	for k in 6:
		var f := fposmod(t * 0.3 + k / 6.0, 1.0)
		var p := Vector2((-24.0 + k * 10.0) * s * puff + sin(t + k) * 3.0, -10.0 - f * 26.0 * puff)
		Art.dot(ci, p, (6.0 + f * 8.0) * s * puff, Color(foam, snappedf(0.4 * (1.0 - f) + poke * 0.3, 0.05)))


static var _FALL_CLIFF := Art.smooth_pts(PackedVector2Array([Vector2(-74, 2), Vector2(-66, -50), Vector2(-52, -104), Vector2(-24, -122),
		Vector2(18, -122), Vector2(46, -106), Vector2(62, -58), Vector2(80, 2)]), 3)
static var _FALL_SHADE := Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(18, -130), Vector2(34, -80), Vector2(44, -30), Vector2(90, 4),
		Vector2(100, -140)]), 2), _FALL_CLIFF)
static var _FALL_SHEET := Art.union([PackedVector2Array([Vector2(-16, -120), Vector2(-2, -120), Vector2(-4, -2), Vector2(-20, -2)]),
		PackedVector2Array([Vector2(3, -120), Vector2(16, -120), Vector2(20, -2), Vector2(4, -2)])])
static var _FALL_LIGHT := PackedVector2Array([Vector2(-16, -120), Vector2(-11, -120), Vector2(-14, -2), Vector2(-20, -2)])
static var _FOAM := Art.union([Art.ellipse_pts(Vector2(0, 0), Vector2(30, 8), 18), Art.circle_pts(Vector2(-14, -6), 9, 12),
		Art.circle_pts(Vector2(2, -9), 11, 12), Art.circle_pts(Vector2(17, -5), 8, 12)])


## The stepped temple pyramid far out on the river (the jungle's landmark):
## four tiers, a stair up the middle, a shrine with a sun disc on top
## (glows at JUNGLE_LAMP when `lit`), vines and trees around its foot.
static func pyramid(ci: CanvasItem, rock: Color, haze: Color, lit: float) -> void:
	var ink := INK.lerp(haze, 0.35)
	var stone := TEMPLE.lerp(haze, 0.4)
	var shade := Art.shade_of(stone, 0.2)
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-96, 2), Vector2(-70, -14), Vector2(-20, -22), Vector2(40, -20), Vector2(84, -10), Vector2(104, 2)]), 3), rock)
	for i in 4:
		var hw := 72.0 - i * 15.0
		var y := -14.0 - i * 21.0
		var tier := PackedVector2Array([Vector2(-hw, y), Vector2(hw, y), Vector2(hw - 6.0, y - 21.0), Vector2(-hw + 6.0, y - 21.0)])
		Art.toon(ci, tier, stone, 2.0, 0.0, ink)
		Art.flat(ci, PackedVector2Array([Vector2(hw * 0.45, y - 1.0), Vector2(hw - 1.0, y - 1.0), Vector2(hw - 6.5, y - 20.0), Vector2(hw * 0.45 - 3.0, y - 20.0)]), shade)
		Art.line(ci, Vector2(-hw + 3.0, y - 7.0), Vector2(hw - 3.0, y - 7.0), Color(ink, 0.25), 1.2)
	# The stair up the middle.
	Art.toon(ci, PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(7, -98), Vector2(-7, -98)]), stone.lightened(0.12), 1.8, 0.0, ink)
	for k in 12:
		var y := -18.0 - k * 7.0
		var hw := 10.5 - k * 0.3
		Art.line(ci, Vector2(-hw, y), Vector2(hw, y), Color(ink, 0.45), 1.2)
	# The shrine and its sun disc.
	Art.toon(ci, Art.rrect_pts(Rect2(-15, -114, 30, 18), 2), stone, 2.0, 0.0, ink)
	Art.toon(ci, PackedVector2Array([Vector2(-19, -112), Vector2(19, -112), Vector2(15, -118), Vector2(-15, -118)]), shade, 1.8, 0.0, ink)
	Art.flat(ci, Art.rrect_pts(Rect2(-5, -110, 10, 14), 4), Color(ink, 0.6))
	var gold := Props.LAMP_OFF.lerp(Color("ffcf3a"), 0.55 + 0.45 * Props._q(lit, 6.0)).lerp(haze, 0.15)
	Art.push(ci, JUNGLE_LAMP)
	Art.toon(ci, _SUN_RAYS, gold.darkened(0.08), 1.6, 0.0, ink)
	Art.toon(ci, Art.circle_pts(Vector2.ZERO, 7.5, 16), gold, 1.8, 0.0, ink)
	Art.disc(ci, Vector2(-2, -2), 2.2, Color(1, 1, 1, 0.6))
	Art.pop(ci)
	# Vines over the tiers and trees at its foot.
	var vine_c := Color("3f9a4a").lerp(haze, 0.4)
	for v: PackedVector2Array in _PYR_VINES:
		Art.line_c(ci, v, vine_c, 2.2)
	var tree := LEAF.lerp(haze, 0.45)
	for p: Vector3 in [Vector3(-74, -16, 22), Vector3(-52, -10, 16), Vector3(62, -14, 20), Vector3(84, -8, 16), Vector3(-90, -4, 12)]:
		Art.toon(ci, Art.ellipse_pts(Vector2(p.x, p.y), Vector2(p.z, p.z * 0.7), 14), tree, 1.8, 0.0, ink)


static var _SUN_RAYS := Art.star_pts(Vector2.ZERO, 14, 8, 10)
static var _PYR_VINES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-50, -56), Vector2(-48, -44), Vector2(-52, -34), Vector2(-49, -22)]),
	PackedVector2Array([Vector2(36, -77), Vector2(38, -64), Vector2(35, -52), Vector2(39, -40)]),
	PackedVector2Array([Vector2(-26, -98), Vector2(-25, -88), Vector2(-28, -80)]),
]


# --- Jungle shore -----------------------------------------------------------------------------

## The golden temple-stone shore: carved blocks in its face, temple steps
## down to the river, a mossy top with vines over the edge, ferns, flowers
## and a broken column (island-local, see island()).
static func _jungle_shore(ci: CanvasItem, width: float, base: Color, top: Color, crust: PackedVector2Array) -> void:
	# Carved blocks in the face.
	var block := base.lightened(0.06)
	var groove := Art.shade_of(base, 0.3)
	for r: Rect2 in [Rect2(36, -40, 34, 18), Rect2(74, -50, 40, 20), Rect2(118, -52, 36, 20), Rect2(158, -52, 44, 20), Rect2(206, -52, 38, 20),
			Rect2(52, -18, 40, 18), Rect2(96, -28, 44, 20), Rect2(144, -30, 40, 20), Rect2(188, -30, 44, 20), Rect2(236, -30, 40, 20),
			Rect2(120, -8, 42, 14), Rect2(166, -8, 40, 14), Rect2(210, -8, 44, 14)]:
		if r.position.x > width + 20.0:
			continue
		Art.t_rect(ci, r, 3, block, 1.6, 0.0)
	# Glyphs carved in two blocks.
	for p: Vector2 in [Vector2(94, -40), Vector2(166, -20)]:
		if p.x < width:
			Art.line_c(ci, Art.moved(_GLYPH, p), groove, 1.8)
	# Temple steps down into the water.
	for i in 5:
		var x := 2.0 + i * 11.0
		var y := -8.0 - i * 11.0
		Art.t_rect(ci, Rect2(x, y, 34.0 - i * 2.0, 12), 2, TEMPLE.lerp(base, 0.4) if i % 2 == 0 else TEMPLE, 2.0, 0.3)
	Art.toon(ci, Art.smooth_pts(crust, 3), top, 3.0, 0.6)
	# Moss and vines over the edge.
	for i in 7:
		var x := 72.0 + i * (width - 60.0) / 7.0
		var y := -54.0 + (5.0 if i % 2 == 0 else 0.0)
		Art.toon(ci, Art.moved(_DRIP, Vector2(x, y)), top, 2.0, 0.0)
		if i % 2 == 1:
			Art.line_c(ci, Art.moved(_EDGE_VINE, Vector2(x + 8.0, y)), LEAF_DARK, 2.2)
			leaf(ci, Vector2(x + 10.0, y + 18.0), 1.2, 0.3, LEAF)
			leaf(ci, Vector2(x + 7.0, y + 30.0), 1.9, 0.28, LEAF_LIGHT)
	# A broken column among the ferns, flowers in front.
	if width > 270.0:
		_column(ci, Vector2(width - 40.0, -64.0), 54.0, TEMPLE, 1)
	Art.push(ci, Vector2(44, -48))
	fern(ci, 0.9, LEAF)
	Art.pop(ci)
	for p: Vector3 in [Vector3(206, -66, 1.2), Vector3(246, -66, 0.9), Vector3(width - 6.0, -66, 1.3)]:
		if p.x < width + 10.0:
			Art.push(ci, Vector2(p.x, p.y))
			fern(ci, p.z, LEAF if int(p.x) % 2 == 0 else LEAF_DARK)
			Art.pop(ci)
	for p: Vector3 in [Vector3(214, -70, 0), Vector3(222, -64, 1), Vector3(252, -72, 3), Vector3(50, -54, 2), Vector3(width - 14.0, -70, 4)]:
		if p.x < width + 10.0:
			hibiscus(ci, Vector2(p.x, p.y), FLOWERS[int(p.z)], 0.9)


static var _GLYPH := PackedVector2Array([Vector2(-8, 6), Vector2(-8, -6), Vector2(8, -6), Vector2(8, 4), Vector2(-3, 4), Vector2(-3, -2), Vector2(3, -2)])
static var _EDGE_VINE := PackedVector2Array([Vector2(0, 0), Vector2(3, 10), Vector2(0, 22), Vector2(2, 34)])


## A temple column (broken at the top when `broken` is 1); origin at its foot.
static func _column(ci: CanvasItem, at: Vector2, h: float, stone: Color, broken: int) -> void:
	Art.push(ci, at)
	Art.t_rect(ci, Rect2(-15, -8, 30, 8), 2, stone.darkened(0.08), 2.2, 0.3)
	var body := Art.rrect_pts(Rect2(-11, -h, 22, h - 8), 1)
	if broken == 1:
		body = PackedVector2Array([Vector2(-11, -8), Vector2(11, -8), Vector2(11, -h + 6), Vector2(6, -h), Vector2(1, -h + 7), Vector2(-4, -h + 2), Vector2(-11, -h + 9)])
	Art.toon(ci, body, stone, 2.4, 0.6)
	for x: float in [-5.0, 0.0, 5.0]:
		Art.line(ci, Vector2(x, -12), Vector2(x, -h + 12), Art.shade_of(stone, 0.22), 1.4)
	if broken != 1:
		Art.t_rect(ci, Rect2(-15, -h - 6, 30, 7), 2, stone.darkened(0.08), 2.2, 0.3)
	Art.line_c(ci, PackedVector2Array([Vector2(-11, -h * 0.55), Vector2(-6, -h * 0.5), Vector2(-9, -h * 0.35), Vector2(-4, -h * 0.25)]), LEAF_DARK, 2.0)
	leaf(ci, Vector2(-8, -h * 0.4), 2.4, 0.3, LEAF)
	Art.pop(ci)


## The workers' hut on bamboo stilts: bamboo walls, a thick thatch of
## leaves, a ladder, a porch with a lantern and flowers. When the door
## opens (a tap) a little monkey peeks out.
static func _stilt_hut(ci: CanvasItem, t: float, lit: float, door: float) -> void:
	# Stilts and braces.
	Art.line(ci, Vector2(18, -6), Vector2(62, -44), BAMBOO_DARK, 3.0)
	Art.line(ci, Vector2(104, -44), Vector2(138, -6), BAMBOO_DARK, 3.0)
	for x: float in [18.0, 62.0, 104.0, 138.0]:
		Art.t_rect(ci, Rect2(x - 4.5, -48, 9, 50), 3, BAMBOO, 2.2, 0.3)
		for y: float in [-34.0, -16.0]:
			Art.line(ci, Vector2(x - 4.5, y), Vector2(x + 4.5, y), BAMBOO_DARK, 1.8)
	# The deck.
	Art.t_rect(ci, Rect2(2, -56, 152, 11), 3, Art.WOOD, 2.6, 0.4)
	# Bamboo walls.
	Art.t_rect(ci, Rect2(14, -112, 122, 58), 4, Color("e8c272"), 2.8, 0.6)
	for i in 9:
		var x := 26.0 + i * 12.5
		Art.line(ci, Vector2(x, -110), Vector2(x, -56), Color("c49a48"), 1.8)
	for y: float in [-98.0, -74.0]:
		Art.line(ci, Vector2(16, y), Vector2(134, y), Color(BAMBOO_DARK, 0.55), 1.4)
	# The door (a monkey peeks out when it opens).
	if door > 0.3:
		_monkey_face(ci, Vector2(41, -84), door)
	_door(ci, Rect2(26, -102, 30, 46), Color("8e552c"), door)
	# Round window with leaf shutters.
	Art.t_circle(ci, Vector2(98, -86), 18, BAMBOO_DARK, 2.4, 0.3)
	Art.t_circle(ci, Vector2(98, -86), 13, Art.GLASS.lerp(Props.LIT, Props._q(lit, 8.0)), 2.2, 0.0)
	Art.line(ci, Vector2(85, -86), Vector2(111, -86), BAMBOO_DARK, 2.4)
	Art.line(ci, Vector2(98, -99), Vector2(98, -73), BAMBOO_DARK, 2.4)
	if lit < 0.5:
		Art.flat(ci, _WIN_SHINE, Color(1, 1, 1, 0.6))
	leaf(ci, Vector2(80, -88), PI - 0.2, 0.36, LEAF)
	leaf(ci, Vector2(116, -88), 0.2, 0.36, LEAF)
	# The porch rail and a hanging lantern.
	Art.line(ci, Vector2(136, -74), Vector2(152, -74), BAMBOO_DARK, 2.6)
	Art.t_rect(ci, Rect2(149, -76, 5, 22), 2, BAMBOO, 1.8, 0.0)
	Art.line(ci, Vector2(146, -118), Vector2(146, -106), INK, 1.6)
	Props.lamp(ci, Vector2(146, -96), lit)
	# Flower pots on the deck.
	for p: Vector3 in [Vector3(68, -56, 0), Vector3(128, -56, 3)]:
		Art.push(ci, Vector2(p.x, p.y - 10))
		fern(ci, 0.55, LEAF)
		Art.pop(ci)
		Art.toon(ci, Art.moved(_POT, Vector2(p.x, p.y)), Color("d0713c"), 1.8, 0.4)
		hibiscus(ci, Vector2(p.x + 2, p.y - 18), FLOWERS[int(p.z)], 0.75)
	# The thatch: straw under layers of big leaves.
	Art.toon(ci, _THATCH, THATCH, 3.0, 0.6)
	for i in 7:
		var x := -2.0 + i * 25.0
		Art.line(ci, Vector2(x, -104), Vector2(x - 4.0, -96), Color("b8862e"), 2.0)
	for f: Vector4 in _ROOF_LEAVES:
		frond(ci, Vector2(f.x, f.y), f.z, int(f.w), [LEAF_DARK, LEAF, LEAF_LIGHT][int(f.w)], 0.9)
	# A carved sun ornament on the ridge.
	Art.push(ci, Vector2(76, -160))
	Art.toon(ci, _SUN_RAYS, Art.GOLD_DARK, 1.8, 0.0)
	Art.t_circle(ci, Vector2.ZERO, 7, Art.GOLD, 2.0, 0.3)
	Art.pop(ci)
	# The ladder down to the ground.
	for x: float in [-6.0, 8.0]:
		Art.line(ci, Vector2(x + 6.0, -54), Vector2(x, 2), BAMBOO_DARK, 3.0)
	for k in 4:
		var y := -44.0 + k * 12.0
		var dx := (y + 54.0) / 56.0 * -6.0 + 6.0
		Art.line(ci, Vector2(dx - 6.0, y), Vector2(dx + 8.0, y), BAMBOO, 2.6)


static var _WIN_SHINE := Art.clipped(Art.ellipse_pts(Vector2(92, -92), Vector2(4, 2.4), 10, -0.7), Art.circle_pts(Vector2(98, -86), 12, 20))
static var _THATCH := Art.smooth_pts(PackedVector2Array([Vector2(-12, -100), Vector2(18, -138), Vector2(76, -164), Vector2(134, -138),
		Vector2(164, -100), Vector2(76, -108)]), 3)
static var _POT := PackedVector2Array([Vector2(-7, -11), Vector2(7, -11), Vector2(5, 0), Vector2(-5, 0)])
## Fronds laid over the thatch: x, y, angle, kind (and color).
const _ROOF_LEAVES: Array[Vector4] = [Vector4(76, -160, PI - 0.55, 0), Vector4(76, -160, 0.55, 0), Vector4(48, -146, PI - 0.7, 1),
		Vector4(104, -146, 0.7, 1), Vector4(22, -128, PI - 0.85, 2), Vector4(130, -128, 0.85, 2), Vector4(76, -156, PI - 1.1, 1), Vector4(76, -156, 1.1, 2)]


static func _monkey_face(ci: CanvasItem, at: Vector2, k: float) -> void:
	Art.push(ci, at + Vector2(0, (1.0 - k) * 8.0))
	Art.t_circle(ci, Vector2(-9, -2), 4, Color("8a5a34"), 1.8, 0.0)
	Art.t_circle(ci, Vector2(9, -2), 4, Color("8a5a34"), 1.8, 0.0)
	Art.t_circle(ci, Vector2.ZERO, 9, Color("8a5a34"), 2.0, 0.3)
	Art.t_ellipse(ci, Vector2(0, 2), Vector2(6.5, 5.5), Color("f0c89a"), 0.0, 0.0)
	Art.disc(ci, Vector2(-3, -1), 1.4, INK)
	Art.disc(ci, Vector2(3, -1), 1.4, INK)
	Art.arc(ci, Vector2(0, 3), 2.6, 0.4, PI - 0.4, 6, INK, 1.4)
	Art.pop(ci)


## The jungle's big palm at the screen edge with coconuts, a parrot on it
## (gone while it shakes) and big leaves at its foot; origin at its foot.
static func jungle_palm(ci: CanvasItem, t: float, wind: float, shake: float, coconuts: int) -> void:
	var sway := sin(t * 1.15) * (0.02 + wind * 0.03) + wind * 0.035 + sin(t * 14.0) * shake * 0.11
	var trunk := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		trunk.append(Vector2(-sin(f * 1.4) * 14.0 - f * 6.0 + sway * 110.0 * f * f, -f * 132.0))
	for i in 8:
		var a := atan2(trunk[i + 1].x - trunk[i].x, -(trunk[i + 1].y - trunk[i].y))
		Art.push(ci, trunk[i], a)
		Art.toon(ci, _TRUNK[i], Color("b07a40"), 2.3, 0.3)
		Art.line(ci, Vector2(-_TRUNK_W[i], -2), Vector2(_TRUNK_W[i], -4), Color("7e5228"), 1.6)
		Art.pop(ci)
	var top := trunk[8]
	# Back fronds, coconuts, front fronds.
	for i in 5:
		var a := -PI + 0.15 + i * (PI - 0.3) / 4.0 + sin(t * 1.5 + i) * (0.04 + wind * 0.04) + sway * 1.3 + sin(t * 16.0 + i) * shake * 0.18
		frond(ci, top, a - 0.25, i, LEAF_DARK, 1.05)
	for i in coconuts:
		Art.t_circle(ci, top + Vector2(-6 + i * 9, 6 + (i % 2) * 2), 5.5, Color("7a4e26"), 2.0, 0.3)
	for i in 6:
		var a := -PI + 0.05 + i * (PI - 0.1) / 5.0 + sin(t * 1.3 + i * 1.7) * (0.05 + wind * 0.05) + sway * 1.5 + sin(t * 15.0 + i) * shake * 0.2
		frond(ci, top, a + (0.35 if cos(a) > 0.0 else 0.1), i + 1, LEAF if i % 2 == 0 else LEAF_LIGHT.darkened(0.08), 1.0)
	if shake < 0.08:
		Art.push(ci, top + Vector2(-34, 8))
		parrot_sitting(ci, fposmod(t, 4.0) < 0.15)
		Art.pop(ci)
	# Big leaves at its foot.
	for l: Vector3 in [Vector3(-40, -6, -2.6), Vector3(-26, -4, -2.1), Vector3(-6, -4, -1.0), Vector3(-50, 0, -3.0)]:
		var wob := sin(t * 1.4 + l.x) * 0.04 * (0.5 + wind)
		leaf(ci, Vector2(l.x, l.y), l.z + wob, 0.9, LEAF if l.x > -30.0 else LEAF_DARK)
	for p: Vector3 in [Vector3(-34, -16, 0), Vector3(-18, -12, 3)]:
		hibiscus(ci, Vector2(p.x, p.y), FLOWERS[int(p.z)], 1.0)


const _TRUNK_W: Array[float] = [9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0, 5.5]
static var _TRUNK: Array[PackedVector2Array] = _trunk_parts()


static func _trunk_parts() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i in 8:
		var w0: float = 9.0 - i * 0.5
		out.append(PackedVector2Array([Vector2(-w0, 1), Vector2(w0, 1), Vector2(w0 - 0.5, -17.5), Vector2(-w0 + 0.5, -17.5)]))
	return out


## The tiki torch on the dock (a flame that flickers); origin at its foot.
const TORCH_H := 46.0


static func torch(ci: CanvasItem, t: float, h: float = TORCH_H) -> void:
	Art.t_rect(ci, Rect2(-3, -h, 6, h), 2, BAMBOO, 2.0, 0.3)
	for y: float in [-h * 0.35, -h * 0.7]:
		Art.line(ci, Vector2(-3, y), Vector2(3, y), BAMBOO_DARK, 1.6)
	Art.toon(ci, Art.moved(_BOWL, Vector2(0, -h)), Color("6a4a3a"), 2.0, 0.3)
	var f := snappedf(0.85 + 0.15 * sin(t * 11.0) + 0.08 * sin(t * 17.0 + 1.0), 0.05)
	Art.push(ci, Vector2(0, -h - 6), snappedf(sin(t * 7.0) * 0.08, 0.02), Vector2(1.0, f))
	Art.toon(ci, _FLAME, Color("ff8a2a"), 1.8, 0.0)
	Art.flat(ci, _FLAME_CORE, Color("ffe36a"))
	Art.pop(ci)


static var _BOWL := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(5, 0), Vector2(-5, 0)])
static var _FLAME := Art.smooth_pts(PackedVector2Array([Vector2(-7, 0), Vector2(-6, -8), Vector2(-1, -13), Vector2(0, -20), Vector2(4, -12), Vector2(7, -6), Vector2(6, 0)]), 2)
static var _FLAME_CORE := Art.smooth_pts(PackedVector2Array([Vector2(-3, 0), Vector2(-3, -5), Vector2(0, -10), Vector2(3, -5), Vector2(3, 0)]), 2)


# --- Jungle river -----------------------------------------------------------------------------

## The river's front at the surface (over the hulls): clear turquoise with a
## bright crest, current streaks flowing right, lily pads and lotus flowers
## drifting with ripples around them, sunny glitter and a fish leaping now
## and then.
static func river_front(ci: CanvasItem, wave: PackedVector2Array, w: float, sy: float, t: float) -> void:
	var front := wave.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	Art.flat_now(ci, front, Color(Art.calm(Art.sea_cols[0]), 0.55))
	Art.polyline(ci, wave, RIVER_FOAM, 3.5)
	var day := DayNight.daylight()
	# Current streaks.
	for i in 8:
		var f := fposmod(t * 0.045 + i / 8.0, 1.0)
		var x := f * (w + 80.0) - 40.0
		var y := sy + 7.0 + float(i % 3) * 3.5
		Art.line(ci, Vector2(x - 11, y), Vector2(x + 11, y), Color(1, 1, 1, snappedf(sin(f * PI) * 0.55, 0.05)), 2.0)
	# Lily pads and lotus flowers drifting on the current.
	for i in 5:
		var x := fposmod(t * (3.0 + float(i % 2)) + i * (w + 90.0) / 5.0, w + 90.0) - 45.0
		var y := sy + 4.0 + float(i % 2) * 4.0 + sin(t * 1.3 + i * 2.0) * 0.8
		var ring := fposmod(t * 0.45 + i * 0.31, 1.0)
		Art.push(ci, Vector2(x, y + 2.0), 0.0, Vector2(1.0, 0.32))
		Art.arc(ci, Vector2.ZERO, 16.0 + ring * 18.0, 0.0, TAU, 20, Color(1, 1, 1, snappedf(0.5 * (1.0 - ring), 0.05)), 4.0)
		Art.pop(ci)
		Art.push(ci, Vector2(x, y), sin(t * 0.5 + i) * 0.08, Vector2.ONE * (0.9 + float(i % 3) * 0.12))
		lily_pad(ci, PAD if i % 2 == 0 else PAD.darkened(0.08))
		if i == 1 or i == 3:
			Art.push(ci, Vector2(-2, -1))
			lotus(ci, LOTUS if i == 1 else Color("fff0f6"))
			Art.pop(ci)
		Art.pop(ci)
	# Glitter of the sun on the water.
	if day > 0.2:
		var g := DayNight.glint()
		for i in 9:
			var tw := snappedf(0.5 + 0.5 * sin(t * 2.4 + i * 2.3), 0.1)
			if tw < 0.6:
				continue
			var p := Vector2(fposmod(i * 0.137 + 0.05 + t * 0.004, 1.0) * w, sy + 5.0 + float(i * 5 % 11))
			Art.push(ci, p, 0.0, Vector2.ONE * (tw - 0.45) * 1.6)
			Art.flat(ci, _GLINT, Color(g, snappedf(0.95 * day, 0.1)))
			Art.pop(ci)
	# A fish leaps out of the river and splashes back.
	var cyc := t / 7.0
	var f := fposmod(cyc, 1.0) / 0.16
	if f < 1.4:
		var n := int(floorf(cyc))
		var x0 := w * (0.12 + 0.76 * fposmod(n * 0.618, 1.0))
		var dir := 1.0 if n % 2 == 0 else -1.0
		if f < 1.0:
			var p := Vector2(x0 + dir * f * 46.0, sy - sin(f * PI) * 38.0)
			var ang := atan2(-cos(f * PI) * 38.0 * PI, 46.0)
			Art.push(ci, p, ang * dir)
			Art.fish(ci, Vector2.ZERO, 10.0, [Color("ff9a3d"), Color("ffd23f"), Color("5ad8ff")][posmod(n, 3)], dir, t)
			Art.pop(ci)
		for e: float in [0.0, 1.0]:
			var k := (f - e * 0.9) / 0.45
			if k <= 0.0 or k >= 1.0:
				continue
			var at := Vector2(x0 + dir * e * 46.0, sy + 1.0)
			for j in 4:
				var a := -PI / 2.0 + (j - 1.5) * 0.5
				Art.dot(ci, at + Vector2(cos(a), sin(a)) * 20.0 * k + Vector2(0, 30.0 * k * k), 2.6 * (1.0 - k * 0.5), Color(1, 1, 1, 1.0 - k))
			Art.push(ci, at, 0.0, Vector2(1.0, 0.35))
			Art.arc(ci, Vector2.ZERO, 6.0 + k * 16.0, 0.0, TAU, 16, Color(1, 1, 1, snappedf(0.8 * (1.0 - k), 0.05)), 4.0)
			Art.pop(ci)


# --- Jungle riverbed and depths ----------------------------------------------------------------

## A carved temple block half sunk in the riverbed; origin at its foot.
static func glyph_block(ci: CanvasItem, stone: Color) -> void:
	Art.push(ci, Vector2.ZERO, -0.12)
	Art.t_rect(ci, Rect2(-18, -24, 36, 26), 3, stone, 2.4, 0.6)
	var groove := Art.shade_of(stone, 0.35)
	Art.line_c(ci, _FACE_GLYPH, groove, 2.0)
	Art.disc(ci, Vector2(-6, -14), 2.0, groove)
	Art.disc(ci, Vector2(6, -14), 2.0, groove)
	Art.line_c(ci, PackedVector2Array([Vector2(-18, -16), Vector2(-10, -18), Vector2(-14, -10)]), Color("3fae5a"), 2.4)
	Art.pop(ci)


static var _FACE_GLYPH := PackedVector2Array([Vector2(-12, -20), Vector2(12, -20), Vector2(12, -4), Vector2(-12, -4), Vector2(-12, -20)])


## Smooth river stones; origin on the bed.
static func river_stones(ci: CanvasItem, tint: Color) -> void:
	Art.t_ellipse(ci, Vector2(-10, -4), Vector2(11, 6.5), Color("9aa8a0") * tint, 2.2, 0.6)
	Art.t_ellipse(ci, Vector2(8, -3), Vector2(8, 5), Color("c2b89a") * tint, 2.2, 0.6)
	Art.t_ellipse(ci, Vector2(2, -9), Vector2(6, 4), Color("7f9a94") * tint, 2.0, 0.6)


## An old clay pot lying on the riverbed; origin at its foot.
static func clay_pot(ci: CanvasItem, tint: Color) -> void:
	Art.push(ci, Vector2(0, -8), 1.2)
	Art.toon(ci, Art.moved(_CLAY_POT, Vector2(0, 12)), Color("d0713c") * tint, 2.4, 0.6)
	Art.line(ci, Vector2(-8, 0), Vector2(8, 0), Color("8a3e22") * tint, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-6, 4), Vector2(-3, 6), Vector2(0, 4), Vector2(3, 6), Vector2(6, 4)]), Color("ffd890") * tint, 1.6)
	Art.pop(ci)


static var _CLAY_POT := Art.smooth_pts(PackedVector2Array([Vector2(-5, -24), Vector2(5, -24), Vector2(4, -20), Vector2(10, -14), Vector2(9, -4),
		Vector2(4, 0), Vector2(-4, 0), Vector2(-9, -4), Vector2(-10, -14), Vector2(-4, -20)]), 2)


## A temple column standing in the deep (the floor under the last site).
static func column(ci: CanvasItem, at: Vector2, h: float, stone: Color, broken: int) -> void:
	_column(ci, at, h, stone, broken)


## Reeds and cattails standing in the water, swaying; origin at their foot.
static func reeds(ci: CanvasItem, at: Vector2, t: float, wind: float) -> void:
	for r: Vector4 in _REEDS:
		var sway := snappedf(sin(t * 1.3 + r.w) * (0.03 + wind * 0.04), 0.005)
		Art.push(ci, at + Vector2(r.x, 0), r.z + sway)
		Art.stroke(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, -r.y)]), Color("4caa3e"), 3.0, 1.6)
		if int(r.w) % 2 == 0:
			Art.t_rect(ci, Rect2(-3.5, -r.y - 14.0, 7, 16), 3.5, Color("8a5a34"), 1.8, 0.4)
			Art.line(ci, Vector2(0, -r.y - 14.0), Vector2(0, -r.y - 20.0), Color("4caa3e"), 2.0)
		Art.pop(ci)
	for l: Vector3 in [Vector3(14, -4, -1.2), Vector3(26, -2, -0.6), Vector3(4, -2, -1.9)]:
		Art.push(ci, at + Vector2(l.x, l.y), l.z + snappedf(sin(t * 1.1 + l.x) * 0.04, 0.01), Vector2(0.75, 0.22))
		Art.toon(ci, _LEAF, LEAF, 1.6, 0.3)
		Art.pop(ci)


## Reeds: x, height, lean, seed (even seeds carry a cattail).
const _REEDS: Array[Vector4] = [Vector4(0, 44, -0.08, 0), Vector4(8, 58, 0.02, 1), Vector4(16, 50, 0.1, 2), Vector4(24, 34, 0.18, 3), Vector4(30, 40, 0.22, 4)]
