class_name Art
extends RefCounted
## Palette and code-drawn sprites. Everything visual is drawn here so a
## later swap to real sprites touches one file.

const SKY_TOP := Color("5ec6ff")
const SKY_BOTTOM := Color("c9f3ff")
const SEA_TOP := Color("22c3d3")
const SEA_MID := Color("0f73a8")
const SEA_DEEP := Color("0b3b7a")
const SEA_ABYSS := Color("06163d")
const SAND := Color("f4d58d")
const SAND_DARK := Color("d9a95b")
const GRASS := Color("5fd068")
const WOOD := Color("b5783f")
const WOOD_DARK := Color("7d4f26")
const INK := Color("0b1a33")
const WHITE := Color("ffffff")
const GOLD := Color("ffc93c")
const GOLD_DARK := Color("d98e04")
const GREEN := Color("35c46a")
const GREEN_DARK := Color("1f8f4a")
const RED := Color("ef4b4b")
const PANEL := Color("0d2a55e6")
const PANEL_LIGHT := Color("16427d")

## Per dive site: rock, ore, glow and diver suit colors.
const DEPTH_STYLE: Array[Dictionary] = [
	{"rock": Color("3f7fb0"), "ore": Color("ffd6e0"), "ore2": Color("ff9fbc"), "suit": Color("ff8a3d")},
	{"rock": Color("356f9f"), "ore": Color("ff6f91"), "ore2": Color("ffb347"), "suit": Color("ffd23f")},
	{"rock": Color("2d5d8f"), "ore": Color("f2f6ff"), "ore2": Color("b9d4ff"), "suit": Color("ff5fa2")},
	{"rock": Color("284c7c"), "ore": Color("e98a4f"), "ore2": Color("ffc08a"), "suit": Color("8be04e")},
	{"rock": Color("233f6c"), "ore": Color("35e08f"), "ore2": Color("9bffcf"), "suit": Color("9b6bff")},
	{"rock": Color("1e325c"), "ore": Color("8f7bff"), "ore2": Color("e2d9ff"), "suit": Color("2de2c5")},
]


static func water_color(t: float) -> Color:
	## t: 0 at the surface, 1 at the bottom of the world.
	if t < 0.25:
		return SEA_TOP.lerp(SEA_MID, t / 0.25)
	if t < 0.6:
		return SEA_MID.lerp(SEA_DEEP, (t - 0.25) / 0.35)
	return SEA_DEEP.lerp(SEA_ABYSS, clampf((t - 0.6) / 0.4, 0.0, 1.0))


static func rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	ci.draw_colored_polygon(pts, color)


static func blob(ci: CanvasItem, center: Vector2, radius: float, color: Color, seed: int, bumps: int = 7) -> void:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var offs: Array[float] = []
	for i in bumps:
		offs.append(rng.randf_range(0.78, 1.0))
	for i in 32:
		var a := TAU * i / 32.0
		var f := float(i) / 32.0 * bumps
		var r := lerpf(offs[int(f) % bumps], offs[(int(f) + 1) % bumps], f - floorf(f))
		pts.append(center + Vector2(cos(a), sin(a) * 0.8) * radius * r)
	ci.draw_colored_polygon(pts, color)


## Coin icon: gold disc with a darker rim and a shine.
static func coin(ci: CanvasItem, center: Vector2, r: float) -> void:
	ci.draw_circle(center, r, GOLD_DARK)
	ci.draw_circle(center + Vector2(0, -r * 0.08), r * 0.86, GOLD)
	ci.draw_circle(center + Vector2(0, -r * 0.08), r * 0.55, GOLD_DARK.lerp(GOLD, 0.55))
	ci.draw_circle(center + Vector2(-r * 0.3, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.8))


## Crystal cluster used for ore deposits and ore piles.
static func crystals(ci: CanvasItem, base: Vector2, size: float, style: Dictionary, seed: int, count: int = 4) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var x := base.x + (float(i) - (count - 1) / 2.0) * size * 0.42 + rng.randf_range(-4, 4)
		var h := size * rng.randf_range(0.6, 1.15) * (1.0 - absf(float(i) - (count - 1) / 2.0) * 0.18)
		var w := size * 0.26
		var tilt := rng.randf_range(-0.25, 0.25)
		var up := Vector2(0, -1).rotated(tilt)
		var right := Vector2(1, 0).rotated(tilt)
		var b := Vector2(x, base.y)
		var pts := PackedVector2Array([b - right * w, b - right * w + up * h * 0.75, b + up * h, b + right * w + up * h * 0.75, b + right * w])
		ci.draw_colored_polygon(pts, style["ore"] if i % 2 == 0 else style["ore2"])
		var shine := PackedVector2Array([b - right * w * 0.5 + up * h * 0.1, b - right * w * 0.5 + up * h * 0.7, b + up * h * 0.92, b + up * h * 0.1])
		ci.draw_colored_polygon(shine, Color(1, 1, 1, 0.3))


## A diver seen from the side. `swim` animates the flippers (0..1 loop),
## `angle` tilts the body, `facing` is 1 (right) or -1 (left).
## `tool`: "" | "pick" (arm raised by `hit` 0..1) | "bag" (carrying ore).
static func diver(ci: CanvasItem, pos: Vector2, scale: float, suit: Color, facing: float,
		angle: float, swim: float, tool: String = "", hit: float = 0.0, bag_color: Color = Color.WHITE) -> void:
	var xf := Transform2D(angle, Vector2(scale * facing, scale), 0.0, pos)
	ci.draw_set_transform_matrix(xf)
	var dark := suit.darkened(0.35)
	# Flippers kick.
	var kick := sin(swim * TAU) * 0.35
	for s: float in [-1.0, 1.0]:
		var a: float = kick * s
		var hip := Vector2(-26, 2 + s * 3)
		var tip := hip + Vector2(-26, 0).rotated(a)
		ci.draw_colored_polygon(PackedVector2Array([hip + Vector2(0, -4), tip + Vector2(0, -7).rotated(a), tip + Vector2(0, 7).rotated(a), hip + Vector2(0, 4)]), dark)
	# Tank on the back.
	rounded_rect(ci, Rect2(-20, -17, 26, 9), 4, Color("c9d3df"))
	# Body.
	rounded_rect(ci, Rect2(-28, -9, 44, 18), 9, suit)
	rounded_rect(ci, Rect2(-10, -9, 6, 18), 2, dark)
	# Head + mask.
	ci.draw_circle(Vector2(20, -2), 11, suit)
	rounded_rect(ci, Rect2(19, -9, 12, 10), 4, Color("163a5c"))
	rounded_rect(ci, Rect2(21, -8, 8, 7), 3, Color("bff6ff"))
	ci.draw_circle(Vector2(23, -6), 1.6, WHITE)
	# Arm and tool.
	match tool:
		"pick":
			var arm := -1.2 + hit * 1.9
			var shoulder := Vector2(8, -4)
			var hand := shoulder + Vector2(16, 0).rotated(arm)
			ci.draw_line(shoulder, hand, dark, 6, true)
			var head := hand + Vector2(10, 0).rotated(arm)
			ci.draw_line(hand, head, WOOD_DARK, 4, true)
			ci.draw_line(head + Vector2(0, -8).rotated(arm), head + Vector2(0, 8).rotated(arm), Color("c9d3df"), 4, true)
		"bag":
			ci.draw_line(Vector2(6, 2), Vector2(12, 14), dark, 5, true)
			ci.draw_circle(Vector2(10, 22), 10, Color("a8793f"))
			ci.draw_circle(Vector2(7, 19), 3, bag_color)
			ci.draw_circle(Vector2(13, 22), 3, bag_color.lightened(0.3))
		_:
			ci.draw_line(Vector2(8, 0), Vector2(22, 8), dark, 6, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Boat seen from the side, `bob` rocks it. Cargo 0..1 fills crates.
static func boat(ci: CanvasItem, pos: Vector2, scale: float, facing: float, bob: float, cargo: float, cargo_color: Color) -> void:
	var xf := Transform2D(sin(bob * TAU) * 0.04, Vector2(scale * facing, scale), 0.0, pos + Vector2(0, sin(bob * TAU) * 3))
	ci.draw_set_transform_matrix(xf)
	# Cabin.
	rounded_rect(ci, Rect2(-40, -54, 40, 34), 6, WHITE)
	rounded_rect(ci, Rect2(-34, -48, 12, 11), 3, Color("7fd8ff"))
	rounded_rect(ci, Rect2(-18, -48, 12, 11), 3, Color("7fd8ff"))
	rounded_rect(ci, Rect2(-44, -60, 48, 8), 4, RED)
	# Chimney.
	rounded_rect(ci, Rect2(-14, -76, 10, 18), 3, INK.lightened(0.2))
	# Cargo crates.
	var crates := int(ceil(clampf(cargo, 0.0, 1.0) * 3.0))
	for i in crates:
		var c := Rect2(6 + i * 20, -40, 18, 18)
		rounded_rect(ci, c, 3, WOOD)
		ci.draw_circle(c.get_center(), 5, cargo_color)
	# Hull.
	var hull := PackedVector2Array([Vector2(-70, -22), Vector2(78, -22), Vector2(62, 6), Vector2(-58, 6)])
	ci.draw_colored_polygon(hull, RED)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-68, -18), Vector2(76, -18), Vector2(73, -12), Vector2(-66, -12)]), WHITE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-62, 0), Vector2(66, 0), Vector2(62, 6), Vector2(-58, 6)]), RED.darkened(0.35))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Round manager portrait. kind: "dive" | "boat" | "plant".
static func manager(ci: CanvasItem, center: Vector2, r: float, kind: String, tint: Color) -> void:
	ci.draw_circle(center, r, tint.darkened(0.3))
	ci.draw_circle(center, r * 0.9, tint.lightened(0.35))
	var skin := Color("f2c29b")
	var face := center + Vector2(0, r * 0.12)
	# Shoulders.
	ci.draw_circle(center + Vector2(0, r * 0.95), r * 0.62, tint.darkened(0.1))
	ci.draw_circle(face, r * 0.42, skin)
	ci.draw_circle(face + Vector2(-r * 0.15, -r * 0.02), r * 0.06, INK)
	ci.draw_circle(face + Vector2(r * 0.15, -r * 0.02), r * 0.06, INK)
	ci.draw_arc(face + Vector2(0, r * 0.1), r * 0.16, 0.3, PI - 0.3, 8, INK, maxf(1.5, r * 0.05), true)
	match kind:
		"boat":
			rounded_rect(ci, Rect2(face + Vector2(-r * 0.5, -r * 0.58), Vector2(r, r * 0.3)), r * 0.1, WHITE)
			rounded_rect(ci, Rect2(face + Vector2(-r * 0.55, -r * 0.32), Vector2(r * 1.1, r * 0.1)), r * 0.05, INK)
			ci.draw_circle(face + Vector2(0, -r * 0.44), r * 0.08, GOLD)
		"plant":
			ellipse(ci, face + Vector2(0, -r * 0.34), Vector2(r * 0.5, r * 0.3), GOLD)
			rounded_rect(ci, Rect2(face + Vector2(-r * 0.6, -r * 0.2), Vector2(r * 1.2, r * 0.1)), r * 0.05, GOLD_DARK)
		_:
			rounded_rect(ci, Rect2(face + Vector2(-r * 0.36, -r * 0.2), Vector2(r * 0.72, r * 0.26)), r * 0.1, Color("163a5c"))
			rounded_rect(ci, Rect2(face + Vector2(-r * 0.3, -r * 0.16), Vector2(r * 0.6, r * 0.18)), r * 0.08, Color("bff6ff"))


## Small fish swimming along x; `t` animates the tail.
static func fish(ci: CanvasItem, pos: Vector2, size: float, color: Color, facing: float, t: float) -> void:
	var xf := Transform2D(0.0, Vector2(size * facing, size), 0.0, pos)
	ci.draw_set_transform_matrix(xf)
	var wag := sin(t * TAU * 2.0) * 0.3
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.9, 0), Vector2(-1.5, -0.45).rotated(wag), Vector2(-1.5, 0.45).rotated(wag)]), color.darkened(0.2))
	ellipse(ci, Vector2.ZERO, Vector2(1.0, 0.55), color)
	ci.draw_circle(Vector2(0.55, -0.12), 0.12, WHITE)
	ci.draw_circle(Vector2(0.58, -0.12), 0.06, INK)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Swaying seaweed strand.
static func seaweed(ci: CanvasItem, base: Vector2, height: float, color: Color, t: float, seed: float) -> void:
	var pts := PackedVector2Array()
	var segs := 8
	for i in segs + 1:
		var f := float(i) / segs
		var sway := sin(t * 1.4 + seed + f * 2.2) * 10.0 * f
		pts.append(base + Vector2(sway, -height * f))
	for i in segs:
		var w := lerpf(8.0, 2.0, float(i) / segs)
		ci.draw_line(pts[i], pts[i + 1], color, w, true)


## Simple up-arrow icon for upgrade buttons (a glyph may be missing in web fonts).
static func arrow_up(ci: CanvasItem, center: Vector2, s: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -s), center + Vector2(s * 0.9, 0), center + Vector2(s * 0.35, 0),
		center + Vector2(s * 0.35, s), center + Vector2(-s * 0.35, s), center + Vector2(-s * 0.35, 0),
		center + Vector2(-s * 0.9, 0)]), color)


static func lock(ci: CanvasItem, center: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(center + Vector2(0, -s * 0.35), s * 0.45, PI, TAU, 16, color, s * 0.18, true)
	rounded_rect(ci, Rect2(center + Vector2(-s * 0.7, -s * 0.3), Vector2(s * 1.4, s * 1.1)), s * 0.2, color)
	ci.draw_circle(center + Vector2(0, s * 0.2), s * 0.15, INK)


static func gear(ci: CanvasItem, center: Vector2, r: float, color: Color, rot: float, teeth: int = 8) -> void:
	var pts := PackedVector2Array()
	for i in teeth * 4:
		var a := rot + TAU * i / (teeth * 4.0)
		var rr := r if (i % 4) < 2 else r * 0.78
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)
	ci.draw_circle(center, r * 0.32, color.darkened(0.4))
