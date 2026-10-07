class_name WorldArt
extends RefCounted
## Scenery of the four worlds in the toon style (thick INK outline, soft
## shading), drawn in local space and placed with Art.push / Art.pop like
## Props. The surface of each world:
##   ocean    sandy beach, palm, lighthouse, wooden hut (Props has most of it)
##   volcano  basalt shore, a smoking volcano behind, lava river, stone hut
##   acid     mossy mud shore, giant mushrooms, twisted trees, mushroom house
##   moon     grey regolith with craters, Earth in a black sky, dome base
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
	Art.toon(ci, ground, base, 3.2, 0.8)
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
			Art.flat_now(ci, front, Color(Art.sea_cols[0], 0.7))
			Art.polyline(ci, wave, Color("e8ffb0"), 4.0)
			for i in 4:
				var x := fposmod(t * 4.0 + i * w / 4.0 + 40.0, w + 60.0) - 30.0
				Art.push(ci, Vector2(x, sy + 3), sin(t * 0.7 + i) * 0.1)
				Art.toon(ci, _PAD, Color("5ab84a"), 2.0, 0.4)
				Art.pop(ci)
			# Bubbles popping on the swamp.
			for i in 5:
				var f := fposmod(t * 0.5 + i * 0.37, 1.0)
				var x := w * fposmod(i * 0.31 + 0.12, 1.0)
				Art.arc(ci, Vector2(x, sy + 4 - f * 4.0), 3.0 + f * 5.0, PI, TAU, 10, Color(0.9, 1.0, 0.7, 0.9 * (1.0 - f)), 2.0)
		"moon":
			Art.flat_now(ci, front, Color(Art.sea_cols[0], 0.9))
			Art.polyline(ci, wave, Color("eef0f8"), 3.0)
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
	for i in 4:
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
		Art.line_c(ci, _RIBBONS[i % 2], Color(1.0, 0.78, 0.26, 0.5), 7.0)
		Art.pop(ci)
	for i in 3:
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
			Art.push(ci, Vector2(x, y + 2.5), slope / 20.0 + sin(t * 0.5 + i * 1.7) * 0.025)
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
const PLATE_SPAN := 430.0
const PLATE_ROW: Array[Vector2] = [Vector2(0, 3), Vector2(86, 1), Vector2(140, 0), Vector2(226, 2), Vector2(292, 3), Vector2(372, 1)]
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
