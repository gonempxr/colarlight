class_name Props
extends RefCounted
## Scenery and machines, drawn in local space with Art's toon kit.
## Callers place them with Art.push/pop.


## Fluffy cloud, `seed` picks the shape.
static func cloud(ci: CanvasItem, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var circles := [Art.rrect_pts(Rect2(-46, -6, 92, 22), 11)]
	for i in 4:
		var x := -30.0 + i * 20.0 + rng.randf_range(-4, 4)
		circles.append(Art.circle_pts(Vector2(x, -6 - rng.randf_range(0, 12) - (8.0 if i in [1, 2] else 0.0)), rng.randf_range(13, 20), 20))
	var shape := Art.union(circles)
	Art.toon(ci, shape, Art.WHITE, 3.0, 0.6, Color("7fb8e0"))


static func sun(ci: CanvasItem, t: float) -> void:
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.08
		var ray := PackedVector2Array([Vector2(cos(a - 0.1), sin(a - 0.1)) * 42.0, Vector2(cos(a), sin(a)) * (62.0 + (i % 2) * 10.0), Vector2(cos(a + 0.1), sin(a + 0.1)) * 42.0])
		Art.flat(ci, ray, Color(1.0, 0.95, 0.6, 0.55))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 50, 36), Color(1.0, 0.97, 0.7, 0.35))
	Art.t_circle(ci, Vector2.ZERO, 36, Color("ffe066"), 3.0, 0.5)


## Faraway island silhouette on the horizon.
static func far_island(ci: CanvasItem, width: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(-width * 0.3, -16), Vector2(-width * 0.1, -26),
			Vector2(width * 0.12, -20), Vector2(width * 0.32, -10), Vector2(width / 2.0, 0)])
	Art.flat(ci, Art.smooth_pts(pts, 4), color)


# --- Dive platform (raft) --------------------------------------------------------

## Raft with a small crane over the dive rope; origin = rope at waterline.
## `pile` 0..5 shows how much ore waits for the boat.
static func raft(ci: CanvasItem, t: float, pile: int, ore: Color) -> void:
	# Floats.
	Art.t_ellipse(ci, Vector2(-38, 2), Vector2(20, 12), Art.CORAL, 2.5, 0.7)
	Art.t_ellipse(ci, Vector2(40, 2), Vector2(20, 12), Art.CORAL, 2.5, 0.7)
	Art.flat(ci, Art.rrect_pts(Rect2(-56, -1, 112, 5), 2), Color(1, 1, 1, 0.8))
	# Crane post and arm, the rope hangs from the pulley at x = 0.
	Art.t_rect(ci, Rect2(-52, -118, 11, 106), 3, Art.WOOD_DARK, 2.5, 0.0)
	Art.t_rect(ci, Rect2(-56, -124, 66, 10), 4, Art.WOOD, 2.5, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(-46, -70), Vector2(-20, -118)]), Art.WOOD, 5.0, 2.0)
	Art.push(ci, Vector2(0, -112), t * 2.0)
	Art.t_circle(ci, Vector2.ZERO, 8, Art.METAL, 2.2, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-6, -1.5, 12, 3), 1), Art.INK_SOFT)
	Art.pop(ci)
	# Flag.
	var wave := sin(t * 4.0) * 3.0
	Art.stroke(ci, PackedVector2Array([Vector2(-47, -124), Vector2(-47, -152)]), Art.WOOD_DARK, 3.0, 1.5)
	Art.toon(ci, PackedVector2Array([Vector2(-46, -152), Vector2(-22, -146 + wave), Vector2(-46, -136)]), Art.CORAL, 2.0, 0.0)
	# Deck planks.
	Art.t_rect(ci, Rect2(-66, -16, 132, 15), 5, Art.WOOD, 3.0, 0.6)
	for i in 5:
		Art.line(ci, Vector2(-40 + i * 22, -14), Vector2(-40 + i * 22, -3), Art.WOOD_DARK, 2.0)
	# Hole for the rope.
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -12), Vector2(9, 3), 12), Color("2b4a78"))
	if pile > 0:
		ore_pile(ci, Vector2(40, -15), pile, ore, 11)


## Heap of sacks and gems.
static func ore_pile(ci: CanvasItem, base: Vector2, n: int, ore: Color, seed: int) -> void:
	var style := {"ore": ore, "ore2": ore.lightened(0.35)}
	Art.crystals(ci, base + Vector2(0, 0), 12.0 + n * 4.0, style, seed, clampi(n + 1, 2, 5))
	if n >= 2:
		Chars.item(ci, "sack", base + Vector2(-20, -18), ore)
	if n >= 4:
		Chars.item(ci, "sack", base + Vector2(12, -20), ore)


# --- Boat ------------------------------------------------------------------------------

## Tugboat, origin at the waterline, facing +x. `crates` 0..3 on deck.
## `captain` draws the boat manager in the cabin window.
static func boat(ci: CanvasItem, t: float, crates: int, ore: Color, captain: bool, cap_emotion: String, blink: bool, crew: Callable = Callable()) -> void:
	# Flag at the stern.
	var wave := sin(t * 5.0) * 3.0
	Art.stroke(ci, PackedVector2Array([Vector2(-78, -34), Vector2(-78, -84)]), Art.WOOD_DARK, 3.0, 1.5)
	Art.toon(ci, PackedVector2Array([Vector2(-77, -84), Vector2(-50, -77 + wave), Vector2(-77, -68)]), Art.GOLD, 2.0, 0.0)
	# Chimney with smoke puffs.
	Art.t_rect(ci, Rect2(-24, -124, 20, 36), 3, Art.GOLD, 2.8, 0.6)
	Art.t_rect(ci, Rect2(-24, -116, 20, 8), 1, Art.RED, 0.0, 0.0)
	Art.t_rect(ci, Rect2(-27, -128, 26, 8), 3, Color("3a3f5c"), 2.5, 0.0)
	# Cabin.
	Art.t_rect(ci, Rect2(-62, -92, 58, 58), 8, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-68, -100, 70, 13), 6, Art.TEAL, 3.0, 0.4)
	var win := Rect2(-53, -80, 40, 24)
	Art.t_rect(ci, win, 6, Art.GLASS, 2.5, 0.0)
	if captain:
		Art.push(ci, Vector2(-33, -63), 0.0, Vector2(0.5, 0.5))
		Chars.head(ci, Chars.manager_look("boat"), cap_emotion, blink)
		Art.pop(ci)
	Art.flat(ci, PackedVector2Array([Vector2(-50, -77), Vector2(-40, -77), Vector2(-48, -60), Vector2(-52, -60)]), Color(1, 1, 1, 0.45))
	# Life ring.
	Art.t_circle(ci, Vector2(-14, -52), 9, Art.WHITE, 2.5, 0.0)
	for i in 4:
		Art.arc(ci, Vector2(-14, -52), 6.5, i * PI / 2.0, i * PI / 2.0 + PI / 4.0, 6, Art.RED, 4.5)
	Art.flat(ci, Art.circle_pts(Vector2(-14, -52), 3.5, 12), Art.CREAM)
	# Crates on deck.
	for i in crates:
		var c := Rect2(6 + i * 25, -58, 23, 23)
		Art.t_rect(ci, c, 3, Art.WOOD, 2.5, 0.5)
		Art.line(ci, c.position + Vector2(4, 4), c.end - Vector2(4, 4), Art.WOOD_DARK, 2.0)
		Art.line(ci, Vector2(c.position.x + 4, c.end.y - 4), Vector2(c.end.x - 4, c.position.y + 4), Art.WOOD_DARK, 2.0)
		Art.crystal(ci, c.position + Vector2(11.5, 1), 12, 4.5, 0.2 * (i - 1), ore, 1.6)
	if crew.is_valid():
		crew.call()
	# Hull.
	var hull := Art.smooth_pts(PackedVector2Array([Vector2(-84, -38), Vector2(20, -38), Vector2(98, -44), Vector2(84, -14),
			Vector2(66, 8), Vector2(-62, 8), Vector2(-80, -12)]), 3)
	Art.toon(ci, hull, Art.RED, 3.2, 0.7)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-120, -33, 240, 8), 2), hull), Art.WHITE)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-120, -4, 240, 30), 2), hull), Color("2d3b6b"))
	for x: float in [-44.0, -18.0, 8.0, 34.0]:
		Art.t_circle(ci, Vector2(x, -15), 5.5, Art.METAL, 2.0, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(x, -15), 3.5, 12), Color("7fd8ff"))
	# Rail.
	Art.line(ci, Vector2(-80, -40), Vector2(94, -46), Art.INK, 2.5)


# --- Island, plant and friends ------------------------------------------------------

## Island ground; origin at the waterline where the shore begins, extends +x.
static func island(ci: CanvasItem, width: float) -> void:
	var sand := Art.smooth_pts(PackedVector2Array([Vector2(-6, 30), Vector2(6, -8), Vector2(30, -34), Vector2(70, -60),
			Vector2(width * 0.5, -66), Vector2(width + 40, -64), Vector2(width + 40, 30)]), 4)
	Art.toon(ci, sand, Art.SAND, 3.2, 0.8)
	var grass_ctrl := PackedVector2Array()
	grass_ctrl.append(Vector2(56, -58))
	grass_ctrl.append(Vector2(width * 0.5, -72))
	grass_ctrl.append(Vector2(width + 40, -70))
	grass_ctrl.append(Vector2(width + 40, -52))
	for i in 8:
		var x := width + 30.0 - (width - 40.0) * (i + 0.5) / 8.0
		grass_ctrl.append(Vector2(x, -54.0 + (5.0 if i % 2 == 0 else 0.0)))
	Art.toon(ci, Art.smooth_pts(grass_ctrl, 3), Art.GRASS, 3.0, 0.6)
	for p: Vector2 in [Vector2(40, -20), Vector2(90, -34), Vector2(150, -30)]:
		Art.t_ellipse(ci, p, Vector2(7, 4), Art.SAND_DARK, 1.8, 0.0)


static func palm(ci: CanvasItem, t: float) -> void:
	var trunk := PackedVector2Array()
	for i in 7:
		trunk.append(Vector2(sin(i * 0.3) * 6.0 - i * 1.5, -i * 16.0))
	for i in 6:
		Art.push(ci, trunk[i], atan2(trunk[i + 1].x - trunk[i].x, -(trunk[i + 1].y - trunk[i].y)))
		Art.toon(ci, PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(6, -17), Vector2(-6, -17)]), Art.WOOD, 2.3, 0.0)
		Art.pop(ci)
	var top := trunk[6]
	for i in 6:
		var a := -PI + i * PI / 5.0 + sin(t * 1.2 + i) * 0.05
		Art.push(ci, top, a)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -4), Vector2(26, -10), Vector2(50, 2), Vector2(26, 6), Vector2(0, 4)]), 3), Color("3fb35a"), 2.3, 0.5)
		Art.pop(ci)
	Art.t_circle(ci, top + Vector2(-4, 4), 5, Color("8a5a2c"), 2.0, 0.0)
	Art.t_circle(ci, top + Vector2(5, 5), 5, Color("8a5a2c"), 2.0, 0.0)


## Processing plant; origin at the ground under its left wall. ~150 wide.
static func plant(ci: CanvasItem, t: float, working: bool, gear_rot: float, flash: float) -> void:
	# Chimney.
	Art.t_rect(ci, Rect2(18, -168, 26, 84), 4, Color("d65a4a"), 3.0, 0.5)
	for i in 3:
		Art.flat(ci, Art.rrect_pts(Rect2(18, -160 + i * 22, 26, 7), 1), Color("fff1e0"))
	Art.t_rect(ci, Rect2(14, -174, 34, 10), 3, Color("3a3f5c"), 2.8, 0.0)
	# Hall with a saw-tooth roof.
	Art.t_rect(ci, Rect2(0, -100, 150, 100), 6, Art.CREAM, 3.2, 0.5)
	var roof := PackedVector2Array([Vector2(-8, -96)])
	for i in 3:
		roof.append(Vector2(-8 + i * 55, -126))
		roof.append(Vector2(-8 + (i + 1) * 55, -100))
	roof.append(Vector2(157, -96))
	Art.toon(ci, roof, Art.TEAL, 3.2, 0.5)
	for i in 3:
		Art.flat(ci, PackedVector2Array([Vector2(-4 + i * 55, -120), Vector2(0 + i * 55, -120), Vector2(0 + i * 55, -104), Vector2(-4 + i * 55, -104)]), Art.GLASS)
	# Windows glow while the plant runs.
	var lit := Color("ffe38a") if working else Color("9cc8e8")
	for i in 3:
		var w := Rect2(14 + i * 44, -78, 32, 26)
		Art.t_rect(ci, w, 5, lit, 2.5, 0.0)
		Art.line(ci, w.position + Vector2(16, 2), w.position + Vector2(16, 24), Art.INK, 2.0)
		if working:
			Art.flat(ci, Art.rrect_pts(w.grow(6), 9), Color(1.0, 0.9, 0.4, 0.18 + 0.08 * sin(t * 6.0 + i)))
	# Door and a sign with a coin.
	Art.t_rect(ci, Rect2(104, -44, 34, 44), 4, Art.WOOD, 2.8, 0.4)
	Art.t_circle(ci, Vector2(131, -22), 2.5, Art.GOLD, 1.2, 0.0)
	Art.t_rect(ci, Rect2(44, -150, 62, 28), 8, Color("35507e"), 3.0, 0.3)
	Art.coin(ci, Vector2(75, -136), 10 + flash * 3.0)
	# Hopper where the conveyor drops ore.
	Art.toon(ci, PackedVector2Array([Vector2(-34, -64), Vector2(4, -64), Vector2(-4, -40), Vector2(-24, -40)]), Art.METAL, 2.8, 0.5)
	Art.t_rect(ci, Rect2(-20, -42, 22, 12), 2, Color("5a5f7a"), 2.2, 0.0)
	# Big gear.
	Art.gear(ci, Vector2(14, -22), 16, Art.GOLD, gear_rot)
	Art.gear(ci, Vector2(40, -12), 10, Color("ffb13b"), -gear_rot * 1.6, 6)


## Conveyor belt from `a` to `b` (world points), items slide along by `t`.
static func conveyor(ci: CanvasItem, a: Vector2, b: Vector2, t: float, running: bool, ore: Color) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	# Legs.
	var len := a.distance_to(b)
	for i in 3:
		var p := a.lerp(b, (i + 0.5) / 3.0)
		Art.stroke(ci, PackedVector2Array([p, Vector2(p.x, a.y + 26)]), Color("5a5f7a"), 4.0, 1.8)
	Art.stroke(ci, PackedVector2Array([a, b]), Color("3a3f5c"), 12.0, 2.5)
	var rollers := int(len / 18.0)
	for i in rollers + 1:
		var p := a.lerp(b, float(i) / rollers)
		Art.disc(ci, p, 3.0, Art.METAL)
	if running:
		for i in 4:
			var f := fposmod(t * 0.35 + i / 4.0, 1.0)
			var p := a.lerp(b, f) - n * 9.0
			Art.push(ci, p, atan2(dir.y, dir.x))
			Art.crystal(ci, Vector2(0, 3), 11, 4.5, 0.0, ore, 1.6)
			Art.pop(ci)


# --- Underwater bits -------------------------------------------------------------------

static func lantern(ci: CanvasItem, t: float, hue: Color) -> void:
	var glow := 0.75 + sin(t * 3.0) * 0.08
	Art.flat(ci, Art.circle_pts(Vector2(0, 14), 44, 32), Color(hue, 0.10 * glow))
	Art.flat(ci, Art.circle_pts(Vector2(0, 14), 26, 28), Color(hue, 0.16 * glow))
	Art.line(ci, Vector2(0, -26), Vector2(0, 2), Art.INK, 2.0)
	Art.t_rect(ci, Rect2(-8, 2, 16, 5), 2, Color("3a3f5c"), 2.0, 0.0)
	Art.t_rect(ci, Rect2(-7, 6, 14, 17), 4, Color(hue, 1.0).lightened(0.35), 2.2, 0.0)
	Art.t_rect(ci, Rect2(-8, 22, 16, 5), 2, Color("3a3f5c"), 2.0, 0.0)


## Wooden mine frame (two posts and a beam) for cave mouths.
static func mine_frame(ci: CanvasItem, h: float, w: float) -> void:
	Art.t_rect(ci, Rect2(-6, -h, 12, h), 3, Art.WOOD, 2.5, 0.3)
	Art.t_rect(ci, Rect2(w - 6, -h, 12, h), 3, Art.WOOD, 2.5, 0.3)
	Art.t_rect(ci, Rect2(-14, -h - 8, w + 28, 14), 4, Art.WOOD_DARK, 2.8, 0.4)
	for x: float in [0.0, w]:
		Art.flat(ci, Art.circle_pts(Vector2(x, -h - 1), 2.2, 8), Art.METAL)


static func shell(ci: CanvasItem, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		var r := 14.0 + (2.0 if i % 2 == 0 else 0.0)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.9))
	pts.append(Vector2(5, 3))
	pts.append(Vector2(-5, 3))
	Art.toon(ci, pts, color, 2.2, 0.4)
	for i in 5:
		var a := PI + PI * (i + 1) / 6.0
		Art.line(ci, Vector2(0, 2), Vector2(cos(a), sin(a) * 0.9) * 11.0, Art.shade_of(color, 0.3), 1.6)


static func starfish(ci: CanvasItem, color: Color) -> void:
	Art.toon(ci, Art.smooth_pts(Art.star_pts(Vector2.ZERO, 14, 6, 5), 2), color, 2.2, 0.4)
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		Art.flat(ci, Art.circle_pts(Vector2(cos(a), sin(a)) * 6.0, 1.3, 6), Color(1, 1, 1, 0.6))


static func coral(ci: CanvasItem, color: Color, seed: int, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var branches := [[Vector2(0, 0), Vector2(0, -26)], [Vector2(0, -12), Vector2(-14, -30)], [Vector2(0, -16), Vector2(13, -34)], [Vector2(-10, -24), Vector2(-20, -40)]]
	for b in branches:
		var tip: Vector2 = b[1] + Vector2(sin(t * 1.5 + seed) * 1.5, 0)
		Art.stroke(ci, PackedVector2Array([b[0], tip]), color, 7.0, 2.2)
	for b in branches:
		Art.disc(ci, b[1] + Vector2(sin(t * 1.5 + seed) * 1.5, 0), 3.0, color.lightened(0.3))


static func clam(ci: CanvasItem, open: float, pearl: Color) -> void:
	Art.toon(ci, Art.ellipse_pts(Vector2(0, 0), Vector2(18, 8), 20), Color("b7a3d6"), 2.2, 0.4)
	Art.t_circle(ci, Vector2(0, -4 - open * 2.0), 6, pearl, 1.8, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(-2, -6 - open * 2.0), 1.8, 8), Color(1, 1, 1, 0.9))
	Art.push(ci, Vector2(-16, -1), -0.5 - open * 0.4)
	var lid := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		lid.append(Vector2(16 + cos(a) * 17.0, sin(a) * 10.0))
	Art.toon(ci, lid, Color("c9b8e6"), 2.2, 0.4)
	Art.pop(ci)


static func barrel(ci: CanvasItem) -> void:
	Art.t_rect(ci, Rect2(-14, -36, 28, 36), 8, Color("a8683a"), 2.5, 0.5)
	for y: float in [-30.0, -8.0]:
		Art.flat(ci, Art.rrect_pts(Rect2(-14, y, 28, 4), 1), Color("5a5f7a"))


static func anchor(ci: CanvasItem) -> void:
	var c := Color("7c8aa5")
	Art.stroke(ci, PackedVector2Array([Vector2(0, -40), Vector2(0, -4)]), c, 6.0, 2.2)
	Art.stroke(ci, PackedVector2Array([Vector2(-10, -32), Vector2(10, -32)]), c, 5.0, 2.2)
	Art.arc(ci, Vector2(0, -16), 15, 0.3, PI - 0.3, 14, Art.INK, 10)
	Art.arc(ci, Vector2(0, -16), 15, 0.3, PI - 0.3, 14, c, 5.5)
	Art.arc(ci, Vector2(0, -44), 5, 0, TAU, 12, Art.INK, 6)
	Art.arc(ci, Vector2(0, -44), 5, 0, TAU, 12, c, 2.5)


static func jelly(ci: CanvasItem, t: float, color: Color) -> void:
	var pulse := 1.0 + sin(t * 3.0) * 0.08
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(pulse, 2.0 - pulse))
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(cos(a) * 13.0, sin(a) * 11.0))
	Art.toon(ci, dome, Color(color, 0.85), 2.0, 0.3)
	Art.pop(ci)
	for i in 4:
		var x := -8.0 + i * 5.3
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(Vector2(x + sin(t * 3.0 + k + i) * 2.0, 2.0 + k * 5.0))
		Art.polyline(ci, pts, Color(color, 0.8), 2.0)
	Art.flat(ci, Art.circle_pts(Vector2(-3, -5), 1.6, 8), Art.INK)
	Art.flat(ci, Art.circle_pts(Vector2(4, -5), 1.6, 8), Art.INK)


## Boards nailed across a closed cave.
static func boards(ci: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center()
	for i in 3:
		var y := rect.position.y + rect.size.y * (0.25 + i * 0.25)
		var tilt := (-0.08 if i % 2 == 0 else 0.07)
		Art.push(ci, Vector2(c.x, y), tilt)
		Art.t_rect(ci, Rect2(-rect.size.x / 2.0 - 10, -12, rect.size.x + 20, 24), 4, Art.WOOD if i != 1 else Color("b87440"), 2.8, 0.4)
		for sx: float in [-1.0, 1.0]:
			Art.flat(ci, Art.circle_pts(Vector2(sx * (rect.size.x / 2.0 - 6), 0), 2.5, 8), Art.METAL)
		Art.pop(ci)
