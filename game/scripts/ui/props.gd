class_name Props
extends RefCounted
## Scenery and machines, drawn in local space with Art's toon kit.
## Callers place them with Art.push/pop.
##
## The boat and the plant have 15 looks each (Balance.building_stage):
##   Props.boat_at_stage(ci, stage, t, ...)  and  Props.plant_at_stage(ci, stage, t, ...)
## draw any of them; Props.boat / Props.plant draw the player's current one.
## Every stage keeps the same anchor points, so crew and ore line up:
##   boat  - origin at the waterline, facing +x; deck (sailor's feet) at
##           (52, -40); crates on the deck at x 6..81; ~200 px long.
##   plant - origin on the ground under the left wall, ~150 px wide;
##           conveyor drops ore into the hopper at (-15, -58); the door
##           (coins come out) at (121, -44).

## Boat paint from the wardrobe: hull, stripe, cabin roof, chimney, flag
## (empty = each stage's own colors).
static var boat_paint: Array = []
## Wind for flags and sails (0..1) and the side it blows to in the local
## space of the thing being drawn (+1 = towards +x). Set by the world.
static var wind := 0.5
static var downwind := 1.0

const LIT := Color("ffe38a")
const LAMP_OFF := Color("fff3c4")
const STAGES := 15


static func _paint(i: int, fallback: Color) -> Color:
	return boat_paint[i] if boat_paint.size() > i else fallback


## Stage of the player's boat or plant right now (1..15).
## (Looks GameState up at run time so Props also loads in test scripts.)
static func current_stage(key: String) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GameState") if tree else null
	if gs == null:
		return 1
	var level: int = gs.get_level(key)
	return Balance.building_stage(level)


# --- Small helpers -------------------------------------------------------------------

## Polygon with cached triangles but a color that may change every frame
## (glows, twinkles): no outline.
static func glow_poly(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var g: Array = Art._geo_for(pts, 0.0, 0.0)
	var v: PackedVector2Array = g[0]
	if not v.is_empty():
		Art._put(ci, v, Art._solid(color, v.size()))


## Soft round light: `color` in the middle fading to clear at radius r.
static func halo(ci: CanvasItem, c: Vector2, r: float, color: Color, n: int = 20) -> void:
	if color.a <= 0.003:
		return
	var v := PackedVector2Array()
	var cols := PackedColorArray()
	var clear := Color(color, 0.0)
	var prev := c + Vector2(r, 0)
	for i in n:
		var a := TAU * (i + 1) / n
		var p := c + Vector2(cos(a), sin(a)) * r
		v.append_array([c, prev, p])
		cols.append_array([color, clear, clear])
		prev = p
	Art._put(ci, v, cols)


## Outlined polygon whose shape changes every frame (flags, sails).
static func live(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 2.5) -> void:
	Art.flat_now(ci, pts, fill)
	Art.polyline(ci, pts, Art.INK, w, true)


## Rounds a 0..1 amount to steps, for colors of cached shapes.
static func _q(x: float, steps: float = 16.0) -> float:
	return roundf(clampf(x, 0.0, 1.0) * steps) / steps


## Pole with a flag flapping downwind.
static func flag(ci: CanvasItem, base: Vector2, h: float, color: Color, t: float, size: float = 1.0) -> void:
	var top := base + Vector2(0, -h)
	Art.stroke(ci, PackedVector2Array([base, top]), Art.WOOD_DARK, 3.0, 1.5)
	var d := downwind
	var len := 26.0 * size * (0.8 + wind * 0.25)
	var hh := 15.0 * size
	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for i in 6:
		var f := i / 5.0
		var wave := sin(t * (4.0 + wind * 5.0) - f * 3.4) * f * (1.5 + wind * 3.0) * size
		var droop := f * f * (1.0 - wind) * 7.0 * size
		top_edge.append(top + Vector2(d * (1.5 + f * len), 1.0 + wave + droop))
		bottom_edge.append(top + Vector2(d * (1.5 + f * len), hh * (1.0 - f * 0.3) + wave + droop))
	bottom_edge.reverse()
	top_edge.append_array(bottom_edge)
	live(ci, top_edge, color, 2.0)
	Art.disc(ci, top, 3.0, Art.GOLD)


## Lantern body (lit or not); the glow itself is drawn by *_lights.
static func lamp(ci: CanvasItem, at: Vector2, lit: float) -> void:
	Art.t_rect(ci, Rect2(at + Vector2(-5, -9), Vector2(10, 3)), 1, Color("3a3f5c"), 1.6, 0.0)
	Art.t_rect(ci, Rect2(at + Vector2(-4, -6), Vector2(8, 11)), 3, LAMP_OFF.lerp(LIT, _q(lit, 4.0)), 1.8, 0.0)
	Art.t_rect(ci, Rect2(at + Vector2(-5, 5), Vector2(10, 3)), 1, Color("3a3f5c"), 1.6, 0.0)


static func _window(ci: CanvasItem, r: Rect2, radius: float, lit: float, bars: bool = true) -> void:
	Art.t_rect(ci, r, radius, Art.GLASS.lerp(LIT, _q(lit, 8.0)), 2.3, 0.0)
	if bars and r.size.x > 20.0:
		Art.line(ci, Vector2(r.get_center().x, r.position.y + 2), Vector2(r.get_center().x, r.end.y - 2), Art.INK, 1.8)
	if lit < 0.5:
		Art.flat(ci, PackedVector2Array([r.position + Vector2(4, 3), r.position + Vector2(9, 3), r.position + Vector2(5, r.size.y - 3), r.position + Vector2(3, r.size.y - 3)]), Color(1, 1, 1, 0.5))


static func _captain(ci: CanvasItem, at: Vector2, emotion: String, blink: bool, s: float = 0.5) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Chars.head(ci, Chars.manager_look("boat"), emotion, blink)
	Art.pop(ci)


# --- Sky -------------------------------------------------------------------------------

## Fluffy cloud, `seed` picks the shape.
static func cloud(ci: CanvasItem, seed: int, fill: Color = Art.WHITE, line: Color = Color("7fb8e0")) -> void:
	Art.toon(ci, cloud_shape(seed), fill, 3.0, 0.6, line)


static func cloud_shape(seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var circles := [Art.rrect_pts(Rect2(-46, -6, 92, 22), 11)]
	for i in 4:
		var x := -30.0 + i * 20.0 + rng.randf_range(-4, 4)
		circles.append(Art.circle_pts(Vector2(x, -6 - rng.randf_range(0, 12) - (8.0 if i in [1, 2] else 0.0)), rng.randf_range(13, 20), 20))
	return Art.union(circles)


## Smiling sun. `spin` turns the rays, `wink` 0..1 closes the left eye,
## `warm` 0..1 turns it sunset orange.
static func sun(ci: CanvasItem, t: float, spin: float = 0.0, wink: float = 0.0, warm: float = 0.0) -> void:
	var w := _q(warm, 12.0)
	var core := Color("ffe066").lerp(Color("ff9a3c"), w)
	var ray_c := Color(1.0, 0.93, 0.55).lerp(Color(1.0, 0.62, 0.35), w)
	halo(ci, Vector2.ZERO, 92.0, Color(ray_c, 0.35 + w * 0.2))
	var pulse := 1.0 + sin(t * 2.2) * 0.06
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.12 + spin
		var len := (60.0 + (i % 2) * 12.0) * (pulse if i % 2 == 0 else 2.0 - pulse)
		var ray := PackedVector2Array([Vector2(cos(a - 0.11), sin(a - 0.11)) * 40.0, Vector2(cos(a), sin(a)) * len, Vector2(cos(a + 0.11), sin(a + 0.11)) * 40.0])
		Art.flat_now(ci, ray, Color(ray_c, 0.7))
	Art.t_circle(ci, Vector2.ZERO, 36, core, 3.0, 0.5)
	# Face: rosy cheeks, eyes (one winks) and a smile.
	Art.disc(ci, Vector2(-17, 8), 6.0, Color(1.0, 0.5, 0.4, 0.45))
	Art.disc(ci, Vector2(17, 8), 6.0, Color(1.0, 0.5, 0.4, 0.45))
	if wink > 0.5:
		Art.arc(ci, Vector2(-11, -4), 5.0, PI * 1.15, PI * 1.85, 8, Art.INK, 2.6)
	else:
		Art.t_ellipse(ci, Vector2(-11, -5), Vector2(3.4, 4.6), Art.INK, 0.0, 0.0)
		Art.disc(ci, Vector2(-10, -7), 1.3, Art.WHITE)
	Art.t_ellipse(ci, Vector2(11, -5), Vector2(3.4, 4.6), Art.INK, 0.0, 0.0)
	Art.disc(ci, Vector2(12, -7), 1.3, Art.WHITE)
	Art.arc(ci, Vector2(0, 3), 10.0, 0.35, PI - 0.35, 12, Art.INK, 2.8)


## Friendly full moon; `wink` 0..1 opens one sleepy eye.
static func moon(ci: CanvasItem, t: float, wink: float = 0.0) -> void:
	halo(ci, Vector2.ZERO, 80.0, Color(0.85, 0.9, 1.0, 0.28 + sin(t * 1.3) * 0.04))
	Art.t_circle(ci, Vector2.ZERO, 30, Color("fff4c8"), 3.0, 0.45)
	Art.t_circle(ci, Vector2(12, -12), 6, Color("f1ddb0"), 0.0, 0.0)
	Art.t_circle(ci, Vector2(-14, 12), 4, Color("f1ddb0"), 0.0, 0.0)
	Art.t_circle(ci, Vector2(15, 12), 3, Color("f1ddb0"), 0.0, 0.0)
	Art.disc(ci, Vector2(-15, 5), 5.0, Color(1.0, 0.6, 0.6, 0.35))
	Art.disc(ci, Vector2(13, 5), 5.0, Color(1.0, 0.6, 0.6, 0.35))
	# Sleepy closed eyes; a tap opens one for a moment.
	Art.arc(ci, Vector2(-9, -3), 4.5, 0.2, PI - 0.2, 8, Art.INK, 2.4)
	if wink > 0.5:
		Art.t_ellipse(ci, Vector2(9, -3), Vector2(3.0, 4.0), Art.INK, 0.0, 0.0)
		Art.disc(ci, Vector2(10, -5), 1.2, Art.WHITE)
	else:
		Art.arc(ci, Vector2(9, -3), 4.5, 0.2, PI - 0.2, 8, Art.INK, 2.4)
	Art.arc(ci, Vector2(0, 5), 6.0, 0.4, PI - 0.4, 10, Art.INK, 2.4)


## Four-point twinkle star (color may change every frame).
static func star(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(size, size))
	glow_poly(ci, Art.star_pts(Vector2.ZERO, 4.0, 1.2, 4), color)
	Art.pop(ci)


## Faraway island silhouette on the horizon.
static func far_island(ci: CanvasItem, width: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(-width * 0.3, -16), Vector2(-width * 0.1, -26),
			Vector2(width * 0.12, -20), Vector2(width * 0.32, -10), Vector2(width / 2.0, 0)])
	Art.flat(ci, Art.smooth_pts(pts, 4), color)


## Rocky islet with a lighthouse, far away; origin at the waterline under
## the tower. `haze` is the far color the tower fades into. The lamp sits
## at LIGHTHOUSE_LAMP.
const LIGHTHOUSE_LAMP := Vector2(0, -122)


static func lighthouse(ci: CanvasItem, rock: Color, haze: Color, lit: float) -> void:
	var cliff := Art.smooth_pts(PackedVector2Array([Vector2(-78, 2), Vector2(-56, -22), Vector2(-26, -44), Vector2(18, -50),
			Vector2(40, -34), Vector2(70, -18), Vector2(96, 2)]), 4)
	Art.flat(ci, cliff, rock)
	var k := 0.45
	var white := Art.WHITE.lerp(haze, k)
	var red := Art.RED.lerp(haze, k)
	var ink := Art.INK.lerp(haze, 0.3)
	var body := PackedVector2Array([Vector2(-11, -44), Vector2(-7, -106), Vector2(7, -106), Vector2(11, -44)])
	Art.toon(ci, body, white, 2.0, 0.0, ink)
	for y: float in [-58.0, -84.0]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-14, y - 6, 28, 12), 1), body), red)
	Art.toon(ci, Art.rrect_pts(Rect2(-13, -110, 26, 6), 2), red.darkened(0.2), 2.0, 0.0, ink)
	Art.toon(ci, Art.rrect_pts(Rect2(-7, -128, 14, 18), 3), LAMP_OFF.lerp(LIT, _q(lit, 6.0)), 2.0, 0.0, ink)
	Art.toon(ci, PackedVector2Array([Vector2(-10, -127), Vector2(0, -138), Vector2(10, -127)]), red.darkened(0.2), 2.0, 0.0, ink)


## Seagull, wings flapping with `flap` (-1..1).
static func gull(ci: CanvasItem, flap: float, color: Color = Art.WHITE) -> void:
	var up := flap * 12.0
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 3, -2), Vector2(side * 12, -4 - up * 0.6), Vector2(side * 21, -3 - up),
				Vector2(side * 13, 1 - up * 0.4), Vector2(side * 3, 4)])
		live(ci, wing, color, 2.0)
	Art.t_ellipse(ci, Vector2(0, 1), Vector2(9, 5), color, 2.0, 0.4)
	Art.toon(ci, PackedVector2Array([Vector2(8, 0), Vector2(15, 2), Vector2(8, 3.5)]), Art.GOLD, 1.5, 0.0)
	Art.disc(ci, Vector2(5, -1), 1.4, Art.INK)


# --- Dive platform (raft) --------------------------------------------------------

## Raft with a small crane over the dive rope; origin = rope at waterline.
## `pile` 0..5 draws an old-style heap of ore (the world uses ore_chest).
## `lamp_lit` lights the lantern under the crane arm (at RAFT_LAMP).
const RAFT_LAMP := Vector2(-30, -100)


static func raft(ci: CanvasItem, t: float, pile: int, ore: Color, lamp_lit: float = 0.0) -> void:
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
	# Lantern swinging under the arm.
	Art.push(ci, Vector2(-30, -114), sin(t * 1.7) * 0.12)
	Art.line(ci, Vector2(0, 0), Vector2(0, 6), Art.INK, 1.6)
	lamp(ci, Vector2(0, 14), lamp_lit)
	Art.pop(ci)
	# Flag.
	var d := downwind
	downwind = 1.0
	flag(ci, Vector2(-47, -124), 30, Art.CORAL, t, 0.95)
	downwind = d
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


## Treasure chest for waiting ore; origin at the middle of its bottom,
## ~64 wide and ~52 tall with the lid shut. `fill` 0..1 is how full it is
## (gems rise above the rim, spill over when full), `lid` 0..1 how far the
## lid is open (hinged on the left).
static func ore_chest(ci: CanvasItem, t: float, fill: float, lid: float, ore: Color, seed: int = 3) -> void:
	var wood := Color("b8743a")
	var wood_light := Color("d8924a")
	var band := Art.GOLD
	var style := {"ore": ore, "ore2": ore.lightened(0.4)}
	var f := clampf(fill, 0.0, 1.0)
	# Gems spilled on the ground when it is full.
	if f > 0.75:
		Art.crystals(ci, Vector2(-38, 0), 16.0, style, seed + 5, 2)
		Art.crystals(ci, Vector2(39, 0), 13.0, style, seed + 9, 2)
	# Lid behind the gems when open.
	var open := clampf(lid, 0.0, 1.3)
	if open > 0.02:
		_chest_lid(ci, open, wood_light, band)
		# Warm glow from inside.
		halo(ci, Vector2(0, -34), 44.0, Color(1.0, 0.95, 0.6, 0.35 * minf(open, 1.0) * (0.3 + f * 0.7)))
	if f > 0.0:
		var h := 10.0 + f * 26.0
		var n := 3 if f < 0.4 else (4 if f < 0.75 else 5)
		Art.crystals(ci, Vector2(0, -28), h, style, seed, n)
		if f > 0.45:
			Art.crystals(ci, Vector2(-14, -28), h * 0.7, style, seed + 2, 2)
			Art.crystals(ci, Vector2(15, -28), h * 0.75, style, seed + 3, 2)
	# Body.
	Art.t_rect(ci, Rect2(-32, -32, 64, 32), 6, wood, 3.0, 0.6)
	Art.flat(ci, Art.rrect_pts(Rect2(-29, -18, 58, 2.5), 1), Art.shade_of(wood, 0.35))
	for x: float in [-20.0, 20.0]:
		Art.t_rect(ci, Rect2(x - 4, -32, 8, 32), 2, band, 2.0, 0.0)
	Art.t_rect(ci, Rect2(-7, -30, 14, 13), 3, band, 2.2, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-1.8, -26), Vector2(1.8, -26), Vector2(2.5, -20), Vector2(-2.5, -20)]), Art.INK)
	if open <= 0.02:
		_chest_lid(ci, 0.0, wood_light, band)
	# A little sparkle on the gems.
	if f > 0.0 and open > 0.1:
		var s := maxf(0.0, sin(t * 2.3 + seed)) * 6.0
		Art.flat_now(ci, Art.star_pts(Vector2(8, -40 - f * 22.0), s, s * 0.35, 4), Color(1, 1, 1, 0.9))


static func _chest_lid(ci: CanvasItem, open: float, wood: Color, band: Color) -> void:
	Art.push(ci, Vector2(-32, -32), -open * 1.15)
	var shape := Art.smooth_pts(PackedVector2Array([Vector2(0, 2), Vector2(1, -8), Vector2(14, -17), Vector2(32, -19),
			Vector2(50, -17), Vector2(63, -8), Vector2(64, 2)]), 3)
	Art.toon(ci, shape, wood if open < 0.6 else Art.shade_of(wood, 0.3), 3.0, 0.5)
	for x: float in [12.0, 52.0]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(x - 4, -24, 8, 28), 1), shape), band)
	Art.pop(ci)


## Rounded tag with a gem and a number, pointing down at `at` (its tip).
## `pop` 0..1 makes it swell for a moment when the number grows.
static func number_tag(ci: CanvasItem, at: Vector2, text: String, ore: Color, pop: float = 0.0) -> void:
	var font := UiTheme.heavy_font()
	var fs := 20
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := roundf(tw + 38.0)
	var s := 1.0 + ease(clampf(pop, 0.0, 1.0), 2.0) * 0.28
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.toon(ci, PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(0, -3)]), Art.CREAM, 2.5, 0.0)
	Art.t_rect(ci, Rect2(-w / 2.0, -44, w, 30), 15, Art.CREAM, 3.0, 0.35)
	Art.crystal(ci, Vector2(-w / 2.0 + 14, -21), 16, 5.5, 0.0, ore, 1.6)
	Art.text(ci, Vector2(-w / 2.0 + 26, -22), text, fs, Art.INK, 0, false)
	Art.pop(ci)


# --- Boat ------------------------------------------------------------------------------

## The player's boat at its current stage (kept for older callers).
static func boat(ci: CanvasItem, t: float, crates: int, ore: Color, captain: bool, cap_emotion: String, blink: bool, crew: Callable = Callable()) -> void:
	boat_at_stage(ci, current_stage("boat"), t, crates, ore, captain, cap_emotion, blink, crew)


## Boat look `stage` (1..15, see BOAT_STAGE_* names), origin at the
## waterline, facing +x. crates 0..3 of `ore` on deck; `captain` puts the
## boat manager at the helm; `crew` is called at the moment the sailor
## should be drawn (between cabin and hull, feet at (52, -40)); `night`
## 0..1 lights the lamps and windows (their glow: boat_lights).
static func boat_at_stage(ci: CanvasItem, stage: int, t: float, crates: int = 0, ore: Color = Art.GOLD, captain: bool = false,
		cap_emotion: String = "happy", blink: bool = false, crew: Callable = Callable(), night: float = 0.0) -> void:
	var o := {"t": t, "crates": crates, "ore": ore, "captain": captain, "emo": cap_emotion, "blink": blink, "crew": crew, "night": night}
	match clampi(stage, 1, STAGES):
		1: _boat_rowboat(ci, o)
		2: _boat_sailboat(ci, o)
		3: _boat_fishing(ci, o)
		4: _boat_launch(ci, o)
		5: _boat_tug(ci, o)
		6: _boat_trawler(ci, o)
		7: _boat_paddle(ci, o)
		8: _boat_freighter(ci, o)
		9: _boat_hover(ci, o)
		10: _boat_catamaran(ci, o)
		11: _boat_hydrofoil(ci, o)
		12: _boat_container(ci, o)
		13: _boat_subcarrier(ci, o)
		14: _boat_yacht(ci, o)
		15: _boat_ark(ci, o)


## Chimney tops (local, facing +x) where smoke comes out; empty = none.
static func boat_smoke_points(stage: int) -> PackedVector2Array:
	match stage:
		5: return PackedVector2Array([Vector2(-14, -130)])
		6: return PackedVector2Array([Vector2(-48, -148)])
		7: return PackedVector2Array([Vector2(-64, -168), Vector2(-38, -168)])
		8: return PackedVector2Array([Vector2(-73, -160)])
		12: return PackedVector2Array([Vector2(-88, -162)])
	return PackedVector2Array()


## Top of the boat above the waterline (for effects above it).
static func boat_height(stage: int) -> float:
	return [0, 80, 160, 132, 90, 130, 150, 170, 162, 100, 182, 100, 162, 136, 124, 150][clampi(stage, 1, STAGES)]


## Night glow of the lamps and windows, drawn with the boat's transform
## on a layer that the night does not darken. amount 0..1.
static func boat_lights(ci: CanvasItem, stage: int, t: float, amount: float) -> void:
	if amount <= 0.01:
		return
	var flick := 0.92 + sin(t * 7.0) * 0.04 + sin(t * 3.1) * 0.04
	# Lamps (size <= 10) get a bright core; windows (where the captain
	# sits) only a soft halo, so the face stays visible.
	for s: Vector3 in _boat_light_spots(clampi(stage, 1, STAGES)):
		var window := s.z > 10.0
		halo(ci, Vector2(s.x, s.y), s.z * (2.4 if window else 3.2), Color(1.0, 0.85, 0.45, (0.22 if window else 0.42) * amount * flick))
		if not window:
			Art.disc(ci, Vector2(s.x, s.y), s.z * 0.55, Color(1.0, 0.95, 0.7, 0.9 * amount))


## x, y, size of each light (lamps and lit windows).
static func _boat_light_spots(stage: int) -> Array[Vector3]:
	match stage:
		1: return [Vector3(-62, -66, 8)]
		2: return [Vector3(-4, -164, 8)]
		3: return [Vector3(0, -136, 8), Vector3(-40, -67, 11)]
		4: return [Vector3(-30, -84, 8), Vector3(-26, -55, 11)]
		5: return [Vector3(-33, -68, 13), Vector3(-78, -92, 7)]
		6: return [Vector3(-6, -136, 8), Vector3(-58, -63, 13), Vector3(-58, -99, 9)]
		7: return [Vector3(-2, -118, 8), Vector3(-7, -100, 11), Vector3(-80, -67, 8), Vector3(-44, -67, 8)]
		8: return [Vector3(-2, -124, 8), Vector3(-75, -103, 13)]
		9: return [Vector3(-30, -96, 8), Vector3(-20, -63, 12)]
		10: return [Vector3(-18, -184, 8), Vector3(-51, -58, 11)]
		11: return [Vector3(-30, -92, 8), Vector3(-20, -60, 12)]
		12: return [Vector3(96, -92, 8), Vector3(-88, -114, 12)]
		13: return [Vector3(-14, -134, 8), Vector3(-14, -86, 12), Vector3(-56, -64, 7)]
		14: return [Vector3(-30, -124, 8), Vector3(-8, -84, 11), Vector3(-40, -60, 12)]
		15: return [Vector3(-58, -150, 10), Vector3(-26, -168, 10), Vector3(-58, -60, 11)]
	return []


static func _hull(ci: CanvasItem, ctrl: PackedVector2Array, fill: Color, stripe: Color, stripe_y: float, stripe_h: float,
		bottom: Color, bottom_y: float) -> PackedVector2Array:
	var hull := Art.smooth_pts(ctrl, 3)
	Art.toon(ci, hull, fill, 3.2, 0.7)
	if stripe.a > 0.0:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-160, stripe_y, 320, stripe_h), 2), hull), stripe)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-160, bottom_y, 320, 40), 2), hull), bottom)
	return hull


static func _portholes(ci: CanvasItem, xs: Array, y: float, night: float, r: float = 5.5) -> void:
	var glass := Color("7fd8ff").lerp(LIT, _q(night, 4.0))
	for x: float in xs:
		Art.t_circle(ci, Vector2(x, y), r, Art.METAL, 2.0, 0.0)
		Art.flat(ci, Art.circle_pts(Vector2(x, y), r - 2.0, 12), glass)


static func _crates(ci: CanvasItem, n: int, ore: Color, x0: float = 6.0, y: float = -58.0) -> void:
	for i in n:
		var c := Rect2(x0 + i * 25, y, 23, 23)
		Art.t_rect(ci, c, 3, Art.WOOD, 2.5, 0.5)
		Art.line(ci, c.position + Vector2(4, 4), c.end - Vector2(4, 4), Art.WOOD_DARK, 2.0)
		Art.line(ci, Vector2(c.position.x + 4, c.end.y - 4), Vector2(c.end.x - 4, c.position.y + 4), Art.WOOD_DARK, 2.0)
		Art.crystal(ci, c.position + Vector2(11.5, 1), 12, 4.5, 0.2 * (i - 1), ore, 1.6)


static func _deck_stuff(ci: CanvasItem, o: Dictionary) -> void:
	_crates(ci, o["crates"], o["ore"])
	var crew: Callable = o["crew"]
	if crew.is_valid():
		crew.call()


static func _cabin_glass(ci: CanvasItem, win: Rect2, radius: float, o: Dictionary, head_at: Vector2, head_s: float = 0.5) -> void:
	var night: float = o["night"]
	Art.t_rect(ci, win, radius, Art.GLASS.lerp(LIT, _q(night * 0.7, 4.0)), 2.5, 0.0)
	if o["captain"]:
		_captain(ci, head_at, o["emo"], o["blink"], head_s)
	Art.flat(ci, PackedVector2Array([win.position + Vector2(3, 3), win.position + Vector2(10, 3), win.position + Vector2(5, win.size.y - 3),
			win.position + Vector2(2, win.size.y - 3)]), Color(1, 1, 1, 0.45))


static func _chimney(ci: CanvasItem, x: float, top: float, bottom: float, w: float, body: Color, band: Color) -> void:
	Art.t_rect(ci, Rect2(x - w / 2.0, top + 4, w, bottom - top - 4), 3, body, 2.8, 0.6)
	Art.t_rect(ci, Rect2(x - w / 2.0, top + 12, w, 7), 1, band, 0.0, 0.0)
	Art.t_rect(ci, Rect2(x - w / 2.0 - 3, top, w + 6, 8), 3, Color("3a3f5c"), 2.5, 0.0)


static func _sail(ci: CanvasItem, mast_x: float, top: float, foot: float, back: float, cloth: Color, stripe: Color, t: float) -> void:
	# Luff along the mast, leech curving out in the wind.
	var bulge := (6.0 + wind * 10.0) + sin(t * 1.7) * 1.5
	var luff := PackedVector2Array()
	var leech := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		luff.append(Vector2(mast_x - 2.0, lerpf(top, foot, f)))
		var p := Vector2(lerpf(mast_x - 2.0, back, f), lerpf(top, foot, f))
		leech.append(p + Vector2(-0.8, -0.6).normalized() * bulge * sin(PI * f))
	var sail := PackedVector2Array()
	for i in range(6, -1, -1):
		sail.append(luff[i])
	for i in range(1, 7):
		sail.append(leech[i])
	live(ci, sail, cloth, 2.6)
	# Colored band across the lower part.
	var band := PackedVector2Array([luff[4], leech[4], leech[5], luff[5]])
	Art.flat_now(ci, band, stripe)
	Art.polyline(ci, PackedVector2Array([luff[4], leech[4]]), Art.INK, 1.5)
	Art.polyline(ci, PackedVector2Array([luff[5], leech[5]]), Art.INK, 1.5)


# 1. Rowboat -------------------------------------------------------------------------

static func _boat_rowboat(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	Art.stroke(ci, PackedVector2Array([Vector2(-60, -30), Vector2(-62, -60)]), Art.WOOD_DARK, 3.0, 1.5)
	lamp(ci, Vector2(-62, -66), night)
	if o["captain"]:
		Art.t_rect(ci, Rect2(-54, -48, 22, 14), 5, Chars.OUTFITS[0], 2.2, 0.0)
		_captain(ci, Vector2(-43, -60), o["emo"], o["blink"], 0.48)
	_deck_stuff(ci, o)
	var hull := _hull(ci, PackedVector2Array([Vector2(-70, -34), Vector2(10, -36), Vector2(62, -40), Vector2(80, -48), Vector2(68, -18),
			Vector2(44, 3), Vector2(-48, 3), Vector2(-70, -16)]), _paint(0, Art.WOOD), Color(0, 0, 0, 0), 0, 0, _paint(1, Art.WOOD_DARK), -2)
	for y: float in [-26.0, -15.0]:
		Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-100, y, 200, 2.5), 1), hull), Art.shade_of(_paint(0, Art.WOOD), 0.35))
	Art.line(ci, Vector2(-68, -35), Vector2(78, -47), Art.INK, 2.5)
	# Oar pulling through the water.
	var sw := sin(t * 2.4) * 0.3
	Art.push(ci, Vector2(-4, -36), 0.95 + sw)
	Art.stroke(ci, PackedVector2Array([Vector2(0, -10), Vector2(0, 50)]), Color("e0b07a"), 4.0, 2.0)
	Art.t_ellipse(ci, Vector2(0, 55), Vector2(6, 11), Color("e0b07a"), 2.2, 0.0)
	Art.pop(ci)
	Art.t_circle(ci, Vector2(-4, -36), 3.5, Art.METAL, 1.8, 0.0)


# 2. Sailboat ------------------------------------------------------------------------

static func _boat_sailboat(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	Art.t_rect(ci, Rect2(-8, -158, 8, 122), 3, Art.WOOD_DARK, 2.5, 0.0)
	_sail(ci, -4, -150, -54, -76, Art.CREAM, _paint(4, Art.CORAL), t)
	Art.stroke(ci, PackedVector2Array([Vector2(-4, -52), Vector2(-80, -52)]), Art.WOOD, 4.0, 2.0)
	lamp(ci, Vector2(-4, -164), night)
	if o["captain"]:
		Art.t_rect(ci, Rect2(-66, -48, 22, 14), 5, Chars.OUTFITS[0], 2.2, 0.0)
		_captain(ci, Vector2(-55, -60), o["emo"], o["blink"], 0.48)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-80, -34), Vector2(10, -36), Vector2(70, -40), Vector2(90, -48), Vector2(78, -18),
			Vector2(54, 4), Vector2(-56, 4), Vector2(-78, -14)]), _paint(0, Color("2f7fd8")), _paint(1, Art.WHITE), -30, 6, Color("2d3b6b"), -5)
	_portholes(ci, [-40.0, -14.0], -17, night, 4.5)
	Art.line(ci, Vector2(-78, -35), Vector2(88, -47), Art.INK, 2.5)
	# Rudder and tiller.
	Art.stroke(ci, PackedVector2Array([Vector2(-78, -36), Vector2(-62, -46)]), Art.WOOD_DARK, 3.0, 1.5)


# 3. Fishing boat --------------------------------------------------------------------

static func _boat_fishing(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Mast and the fishing boom out over the bow.
	Art.t_rect(ci, Rect2(-4, -132, 8, 96), 3, Art.WOOD_DARK, 2.5, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(0, -126), Vector2(88, -118)]), Art.WOOD, 4.0, 2.0)
	var bob := sin(t * 1.8) * 3.0
	Art.line(ci, Vector2(88, -118), Vector2(92, -10 + bob), Color(1, 1, 1, 0.85), 1.6)
	Art.t_circle(ci, Vector2(92, -8 + bob), 4, Art.RED, 1.8, 0.0)
	flag(ci, Vector2(0, -132), 16, _paint(4, Art.GOLD), t, 0.7)
	lamp(ci, Vector2(0, -136), night)
	# Wheelhouse.
	Art.t_rect(ci, Rect2(-66, -86, 50, 50), 7, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-72, -94, 62, 12), 5, _paint(2, Art.RED), 3.0, 0.4)
	_cabin_glass(ci, Rect2(-58, -78, 34, 22), 6, o, Vector2(-41, -62))
	# Net heap at the stern.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-96, -36), Vector2(-92, -52), Vector2(-80, -56), Vector2(-70, -48), Vector2(-68, -36)]), 3), Color("3f8f6a"), 2.5, 0.5)
	for i in 3:
		Art.line(ci, Vector2(-92 + i * 7, -50), Vector2(-86 + i * 7, -38), Color("2a6a4a"), 1.5)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-96, -36), Vector2(20, -38), Vector2(90, -46), Vector2(80, -16), Vector2(62, 4), Vector2(-66, 4),
			Vector2(-92, -14)]), _paint(0, Color("35a37a")), _paint(1, Art.WHITE), -32, 6, Color("2d3b6b"), -6)
	for x: float in [-50.0, 30.0]:
		Art.t_circle(ci, Vector2(x, -22), 6, Color("ff8a3d"), 2.2, 0.3)
		Art.flat(ci, Art.rrect_pts(Rect2(x - 6, -23, 12, 2.5), 1), Art.WHITE)
	Art.line(ci, Vector2(-94, -37), Vector2(88, -47), Art.INK, 2.5)


# 4. Motor launch --------------------------------------------------------------------

static func _boat_launch(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	flag(ci, Vector2(-82, -36), 38, _paint(4, Art.GOLD), t, 0.85)
	# Outboard motor.
	Art.stroke(ci, PackedVector2Array([Vector2(-96, -34), Vector2(-96, 2)]), Color("5a5f7a"), 5.0, 2.0)
	Art.t_rect(ci, Rect2(-108, -62, 24, 30), 7, Color("3a3f5c"), 2.8, 0.5)
	Art.t_rect(ci, Rect2(-106, -60, 20, 6), 3, _paint(3, Art.CORAL), 0.0, 0.0)
	# Windshield cabin with a canopy.
	Art.toon(ci, PackedVector2Array([Vector2(-54, -36), Vector2(-50, -72), Vector2(-10, -72), Vector2(16, -36)]), Art.CREAM, 3.0, 0.4)
	var win := PackedVector2Array([Vector2(-44, -66), Vector2(-14, -66), Vector2(6, -44), Vector2(-44, -44)])
	Art.toon(ci, win, Art.GLASS.lerp(LIT, _q(night * 0.7, 4.0)), 2.2, 0.0)
	if o["captain"]:
		_captain(ci, Vector2(-26, -52), o["emo"], o["blink"])
	Art.flat(ci, PackedVector2Array([Vector2(-40, -63), Vector2(-34, -63), Vector2(-38, -47), Vector2(-41, -47)]), Color(1, 1, 1, 0.45))
	Art.t_rect(ci, Rect2(-60, -80, 56, 9), 4, _paint(2, Art.TEAL), 2.8, 0.3)
	lamp(ci, Vector2(-30, -86), night)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-90, -34), Vector2(30, -38), Vector2(104, -54), Vector2(92, -22), Vector2(64, 4), Vector2(-70, 4),
			Vector2(-88, -12)]), _paint(0, Art.WHITE), _paint(1, Art.BLUE), -28, 7, Color("2d3b6b"), -5)


# 5. Steam tug (the classic boat) ----------------------------------------------------

static func _boat_tug(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	flag(ci, Vector2(-78, -34), 50, _paint(4, Art.GOLD), t)
	_chimney(ci, -14, -128, -88, 20, _paint(3, Art.GOLD), Art.RED)
	# Cabin.
	Art.t_rect(ci, Rect2(-62, -92, 58, 58), 8, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-68, -100, 70, 13), 6, _paint(2, Art.TEAL), 3.0, 0.4)
	_cabin_glass(ci, Rect2(-53, -80, 40, 24), 6, o, Vector2(-33, -63))
	lamp(ci, Vector2(-78, -92), night)
	# Life ring.
	Art.t_circle(ci, Vector2(-14, -52), 9, Art.WHITE, 2.5, 0.0)
	for i in 4:
		Art.arc(ci, Vector2(-14, -52), 6.5, i * PI / 2.0, i * PI / 2.0 + PI / 4.0, 6, Art.RED, 4.5)
	Art.flat(ci, Art.circle_pts(Vector2(-14, -52), 3.5, 12), Art.CREAM)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-84, -38), Vector2(20, -38), Vector2(98, -44), Vector2(84, -14),
			Vector2(66, 8), Vector2(-62, 8), Vector2(-80, -12)]), _paint(0, Art.RED), _paint(1, Art.WHITE), -33, 8, Color("2d3b6b"), -4)
	_portholes(ci, [-44.0, -18.0, 8.0, 34.0], -15, night)
	Art.line(ci, Vector2(-80, -40), Vector2(94, -46), Art.INK, 2.5)


# 6. Cargo trawler -------------------------------------------------------------------

static func _boat_trawler(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Crane mast with a boom and a swinging hook over the front deck.
	Art.t_rect(ci, Rect2(-10, -132, 9, 96), 3, Color("ff9f1c"), 2.5, 0.3)
	Art.stroke(ci, PackedVector2Array([Vector2(-6, -124), Vector2(80, -108)]), Color("ff9f1c"), 5.0, 2.2)
	var swing := sin(t * 1.3) * 0.12
	Art.push(ci, Vector2(80, -108), swing)
	Art.line(ci, Vector2.ZERO, Vector2(0, 30), Art.INK, 1.8)
	Art.arc(ci, Vector2(0, 38), 6.0, -PI * 0.5, PI * 0.9, 10, Art.INK, 5.0)
	Art.arc(ci, Vector2(0, 38), 6.0, -PI * 0.5, PI * 0.9, 10, Art.METAL, 2.5)
	Art.pop(ci)
	lamp(ci, Vector2(-6, -138), night)
	flag(ci, Vector2(-98, -36), 44, _paint(4, Art.GOLD), t)
	_chimney(ci, -48, -150, -118, 18, _paint(3, Art.GOLD), Art.RED)
	# Two-storey bridge.
	Art.t_rect(ci, Rect2(-90, -86, 64, 50), 7, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-82, -116, 48, 34), 6, Art.CREAM, 3.0, 0.4)
	Art.t_rect(ci, Rect2(-88, -124, 60, 10), 4, _paint(2, Color("ff9f1c")), 2.8, 0.3)
	_cabin_glass(ci, Rect2(-80, -76, 44, 24), 6, o, Vector2(-58, -59))
	_window(ci, Rect2(-76, -108, 16, 14), 4, night, false)
	_window(ci, Rect2(-56, -108, 16, 14), 4, night, false)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-102, -36), Vector2(20, -38), Vector2(100, -46), Vector2(88, -16), Vector2(70, 6), Vector2(-80, 6),
			Vector2(-100, -14)]), _paint(0, Color("35507e")), _paint(1, Art.WHITE), -32, 7, Color("d8453c"), -6)
	_portholes(ci, [-60.0, -34.0, -8.0, 18.0, 44.0], -18, night, 4.5)
	Art.line(ci, Vector2(-100, -37), Vector2(98, -47), Art.INK, 2.5)


# 7. Paddle steamer ------------------------------------------------------------------

static func _boat_paddle(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	for x: float in [-64.0, -38.0]:
		Art.t_rect(ci, Rect2(x - 7, -160, 14, 76), 3, Color("3a3f5c"), 2.8, 0.4)
		Art.t_rect(ci, Rect2(x - 7, -146, 14, 6), 1, Art.RED, 0.0, 0.0)
		Art.toon(ci, PackedVector2Array([Vector2(x - 11, -160), Vector2(x - 7, -168), Vector2(x - 3, -162), Vector2(x, -170),
				Vector2(x + 3, -162), Vector2(x + 7, -168), Vector2(x + 11, -160), Vector2(x + 8, -154), Vector2(x - 8, -154)]), _paint(3, Art.GOLD), 2.2, 0.0)
	flag(ci, Vector2(-100, -36), 52, _paint(4, Art.RED), t)
	# Long cabin with a roof deck, the pilot house on top.
	Art.t_rect(ci, Rect2(-96, -86, 104, 50), 8, Art.CREAM, 3.0, 0.5)
	for i in 5:
		_window(ci, Rect2(-88 + i * 18, -76, 12, 18), 6, night, false)
	Art.t_rect(ci, Rect2(-102, -94, 116, 10), 4, _paint(2, Art.RED), 2.8, 0.3)
	for i in 7:
		Art.line(ci, Vector2(-96 + i * 17, -94), Vector2(-96 + i * 17, -102), Art.INK, 2.0)
	Art.line(ci, Vector2(-98, -102), Vector2(8, -102), Art.INK, 2.2)
	Art.t_rect(ci, Rect2(-24, -112, 34, 22), 6, Art.CREAM, 2.8, 0.4)
	Art.t_rect(ci, Rect2(-28, -118, 42, 8), 4, _paint(2, Art.RED), 2.5, 0.2)
	_cabin_glass(ci, Rect2(-20, -108, 26, 15), 5, o, Vector2(-7, -97), 0.36)
	lamp(ci, Vector2(-2, -124), night)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-104, -36), Vector2(20, -38), Vector2(100, -44), Vector2(88, -16), Vector2(70, 6), Vector2(-82, 6),
			Vector2(-102, -14)]), _paint(0, Art.WHITE), _paint(1, Art.RED), -32, 6, Color("2d3b6b"), -5)
	Art.line(ci, Vector2(-102, -37), Vector2(98, -45), Art.INK, 2.5)
	# Paddle wheel on the side, turning, under its housing.
	Art.push(ci, Vector2(-40, -20), t * 2.2)
	Art.t_circle(ci, Vector2.ZERO, 26, Color("8e552c"), 2.8, 0.0)
	Art.t_circle(ci, Vector2.ZERO, 19, Color("5a3a2a"), 0.0, 0.0)
	for i in 8:
		Art.push(ci, Vector2.ZERO, TAU * i / 8.0)
		Art.t_rect(ci, Rect2(-3, -30, 6, 22), 2, Art.WOOD, 2.0, 0.0)
		Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 6, Art.GOLD, 2.0, 0.0)
	Art.pop(ci)
	var housing := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		housing.append(Vector2(-40, -24) + Vector2(cos(a), sin(a)) * 34.0)
	Art.toon(ci, housing, _paint(2, Art.RED), 3.0, 0.4)
	for i in 5:
		var a := PI + PI * (i + 1) / 6.0
		Art.line(ci, Vector2(-40, -25), Vector2(-40, -24) + Vector2(cos(a), sin(a)) * 30.0, Color(1, 1, 1, 0.8), 2.0)


# 8. Coastal freighter ---------------------------------------------------------------

static func _boat_freighter(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Mast with a cross spar and a lamp.
	Art.t_rect(ci, Rect2(-6, -124, 8, 88), 3, Art.METAL, 2.5, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(-16, -108), Vector2(12, -108)]), Art.METAL, 4.0, 2.0)
	lamp(ci, Vector2(-2, -130), night)
	_chimney(ci, -73, -160, -128, 18, _paint(3, Color("ff7043")), Art.WHITE)
	flag(ci, Vector2(-108, -36), 40, _paint(4, Art.GOLD), t)
	# Bridge tower at the stern with a spinning radar.
	Art.t_rect(ci, Rect2(-104, -122, 52, 86), 7, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-110, -130, 64, 10), 4, _paint(2, Color("35507e")), 2.8, 0.3)
	_cabin_glass(ci, Rect2(-96, -114, 42, 22), 6, o, Vector2(-75, -98))
	for i in 3:
		_portholes(ci, [-94.0 + i * 15.0], -74, night, 4.5)
	Art.stroke(ci, PackedVector2Array([Vector2(-58, -130), Vector2(-58, -140)]), Art.METAL, 3.0, 1.5)
	Art.push(ci, Vector2(-58, -142), 0.0, Vector2(cos(t * 2.4), 1.0))
	Art.t_rect(ci, Rect2(-13, -3, 26, 6), 3, Art.WHITE, 2.0, 0.0)
	Art.pop(ci)
	# Hatch covers.
	for i in 2:
		Art.t_rect(ci, Rect2(-46 + i * 25, -52, 22, 14), 3, Color("3fae7a"), 2.5, 0.3)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-112, -36), Vector2(20, -38), Vector2(106, -48), Vector2(92, -16), Vector2(74, 6),
			Vector2(-88, 6), Vector2(-110, -12)]), _paint(0, Color("e8553e")), _paint(1, Art.WHITE), -33, 6, Color("2d3b6b"), -5)
	_portholes(ci, [-30.0, -4.0, 22.0, 48.0], -17, night, 4.5)
	Art.line(ci, Vector2(-110, -37), Vector2(104, -49), Art.INK, 2.5)


# 9. Hovercraft ----------------------------------------------------------------------

static func _boat_hover(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Big fan in a ring at the stern.
	Art.t_rect(ci, Rect2(-100, -82, 8, 40), 2, Color("5a5f7a"), 2.2, 0.0)
	Art.t_circle(ci, Vector2(-80, -80), 30, Color("5a5f7a"), 3.0, 0.3)
	Art.t_circle(ci, Vector2(-80, -80), 23, Color("2e3246"), 0.0, 0.0)
	Art.push(ci, Vector2(-80, -80), t * 9.0)
	for i in 3:
		Art.push(ci, Vector2.ZERO, TAU * i / 3.0)
		Art.t_ellipse(ci, Vector2(0, -11), Vector2(5, 11), Art.METAL, 1.8, 0.0)
		Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 5, _paint(3, Art.CORAL), 1.8, 0.0)
	Art.pop(ci)
	Art.toon(ci, PackedVector2Array([Vector2(-116, -66), Vector2(-104, -66), Vector2(-100, -38), Vector2(-114, -38)]), _paint(2, Art.TEAL), 2.5, 0.0)
	# Cabin dome with a band of windows.
	var cabin := Art.smooth_pts(PackedVector2Array([Vector2(-62, -40), Vector2(-60, -74), Vector2(-34, -90), Vector2(4, -84), Vector2(30, -40)]), 3)
	Art.toon(ci, cabin, Art.CREAM, 3.0, 0.5)
	var band := Art.clipped(Art.rrect_pts(Rect2(-80, -74, 120, 22), 3), cabin)
	Art.flat(ci, band, Art.GLASS.lerp(LIT, _q(night * 0.7, 4.0)))
	if o["captain"]:
		_captain(ci, Vector2(-20, -60), o["emo"], o["blink"])
	Art.ring(ci, band, Art.INK, 2.2)
	Art.t_rect(ci, Rect2(-40, -96, 20, 6), 3, _paint(2, Art.TEAL), 2.2, 0.0)
	lamp(ci, Vector2(-30, -102), night)
	_deck_stuff(ci, o)
	# Body on an air cushion that wobbles.
	Art.t_rect(ci, Rect2(-92, -46, 192, 20), 9, _paint(0, Color("ff9f1c")), 3.0, 0.6)
	Art.flat(ci, Art.rrect_pts(Rect2(-88, -40, 184, 4), 1), _paint(1, Art.WHITE))
	Art.push(ci, Vector2(0, -12), 0.0, Vector2(1.0, 1.0 + sin(t * 9.0) * 0.05))
	var puffs := [Art.rrect_pts(Rect2(-98, -14, 202, 16), 8)]
	for i in 9:
		puffs.append(Art.circle_pts(Vector2(-84 + i * 22, 0), 13, 18))
	Art.toon(ci, Art.union(puffs), Color("2e3246"), 3.0, 0.5)
	for i in 8:
		Art.arc(ci, Vector2(-73 + i * 22, 2), 5.0, PI * 0.2, PI * 0.8, 6, Color("4a4f6a"), 2.0)
	Art.pop(ci)
	# Spray around the skirt.
	for i in 5:
		var f := fposmod(t * 1.6 + i * 0.2, 1.0)
		var x := -100.0 + i * 50.0 + f * 12.0
		Art.disc(ci, Vector2(x, 2 - f * 10.0), 3.5 * (1.0 - f) + 1.0, Color(1, 1, 1, 0.8 * (1.0 - f)))


# 10. Catamaran ----------------------------------------------------------------------

static func _boat_catamaran(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	var hull_c := _paint(0, Art.WHITE)
	var ctrl := PackedVector2Array([Vector2(-92, -28), Vector2(20, -30), Vector2(100, -36), Vector2(92, -12), Vector2(72, 2),
			Vector2(-72, 2), Vector2(-90, -10)])
	# Far hull, a little behind.
	Art.push(ci, Vector2(12, -8))
	Art.toon(ci, Art.smooth_pts(ctrl, 3), Art.shade_of(hull_c, 0.35), 3.0, 0.0)
	Art.pop(ci)
	# Mast and a big striped sail.
	Art.t_rect(ci, Rect2(-22, -180, 8, 138), 3, Art.METAL, 2.5, 0.0)
	_sail(ci, -18, -172, -58, -88, Art.WHITE, _paint(4, Art.TEAL), t)
	Art.stroke(ci, PackedVector2Array([Vector2(-18, -56), Vector2(-90, -56)]), Art.METAL, 4.0, 2.0)
	lamp(ci, Vector2(-18, -186), night)
	# Cabin with solar panels on the roof.
	Art.t_rect(ci, Rect2(-74, -74, 48, 34), 8, Art.CREAM, 3.0, 0.5)
	_cabin_glass(ci, Rect2(-68, -68, 34, 20), 6, o, Vector2(-51, -54))
	Art.t_rect(ci, Rect2(-78, -80, 56, 8), 2, Color("27418a"), 2.5, 0.0)
	for i in 3:
		Art.line(ci, Vector2(-64 + i * 14, -79), Vector2(-64 + i * 14, -73), Color("7fb8ff"), 1.4)
	# Deck across both hulls.
	Art.t_rect(ci, Rect2(-88, -44, 180, 10), 4, Art.WOOD, 2.8, 0.4)
	_deck_stuff(ci, o)
	_hull(ci, ctrl, hull_c, _paint(1, Art.TEAL), -24, 5, Color("2d3b6b"), -4)


# 11. Hydrofoil ----------------------------------------------------------------------

static func _boat_hydrofoil(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Foils under the hull cut the water.
	for x: float in [-56.0, 62.0]:
		Art.t_rect(ci, Rect2(x - 4, -20, 8, 24), 2, Art.METAL, 2.2, 0.0)
		Art.t_ellipse(ci, Vector2(x, 3), Vector2(22, 4), Art.METAL, 2.2, 0.0)
		for i in 3:
			var f := fposmod(t * 2.2 + i / 3.0, 1.0)
			Art.disc(ci, Vector2(x - 18 - f * 26.0, -2 - sin(f * PI) * 10.0), 3.0 * (1.0 - f) + 1.0, Color(1, 1, 1, 0.85 * (1.0 - f)))
	flag(ci, Vector2(-94, -34), 34, _paint(4, Art.RED), t, 0.8)
	# Streamlined cabin.
	var cabin := Art.smooth_pts(PackedVector2Array([Vector2(-80, -40), Vector2(-74, -70), Vector2(-40, -86), Vector2(0, -80), Vector2(30, -62), Vector2(40, -40)]), 3)
	Art.toon(ci, cabin, _paint(2, Art.CREAM), 3.0, 0.5)
	var band := Art.clipped(Art.rrect_pts(Rect2(-80, -72, 130, 18), 3), cabin)
	Art.flat(ci, band, Art.GLASS.lerp(LIT, _q(night * 0.7, 4.0)))
	if o["captain"]:
		_captain(ci, Vector2(-20, -58), o["emo"], o["blink"])
	Art.ring(ci, band, Art.INK, 2.2)
	lamp(ci, Vector2(-30, -92), night)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-96, -40), Vector2(20, -40), Vector2(110, -52), Vector2(98, -26), Vector2(72, -14), Vector2(-80, -14),
			Vector2(-96, -24)]), _paint(0, Color("eef1f8")), _paint(1, Art.RED), -33, 6, Color("35507e"), -22)
	Art.line(ci, Vector2(-94, -41), Vector2(106, -53), Art.INK, 2.5)


# 12. Container ship -----------------------------------------------------------------

static func _boat_container(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	_chimney(ci, -88, -162, -136, 18, _paint(3, Art.RED), Art.WHITE)
	flag(ci, Vector2(-118, -36), 40, _paint(4, Art.GOLD), t)
	# Bridge tower.
	Art.t_rect(ci, Rect2(-110, -132, 44, 96), 7, Art.CREAM, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-116, -140, 56, 10), 4, _paint(2, Color("35507e")), 2.8, 0.3)
	_cabin_glass(ci, Rect2(-104, -124, 32, 20), 5, o, Vector2(-88, -108))
	for i in 3:
		_window(ci, Rect2(-104 + i * 11, -92, 8, 10), 2, night, false)
	# Stacks of colorful containers.
	var cols := [Art.RED, Art.BLUE, Art.GOLD, Art.GREEN, Art.TEAL, Art.PURPLE, Art.CORAL, Color("35507e")]
	var k := 0
	for row in 3:
		var n := 3 if row < 2 else 2
		for i in n:
			var r := Rect2(-62 + i * 22 + row * 11, -54 - row * 16, 22, 16)
			var c: Color = cols[k % cols.size()]
			k += 1
			Art.t_rect(ci, r, 2, c, 2.3, 0.3)
			for j in 3:
				Art.line(ci, Vector2(r.position.x + 5 + j * 6, r.position.y + 3), Vector2(r.position.x + 5 + j * 6, r.end.y - 3), Art.shade_of(c, 0.3), 1.4)
	# Bow mast.
	Art.t_rect(ci, Rect2(92, -86, 7, 48), 2, Art.METAL, 2.2, 0.0)
	lamp(ci, Vector2(96, -92), night)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-120, -36), Vector2(20, -38), Vector2(110, -46), Vector2(98, -16), Vector2(80, 6), Vector2(-94, 6),
			Vector2(-118, -12)]), _paint(0, Color("2a4fb8")), _paint(1, Art.WHITE), -33, 5, Color("d8453c"), -8)
	Art.line(ci, Vector2(-118, -37), Vector2(108, -47), Art.INK, 2.5)


# 13. Sub-carrier ------------------------------------------------------------------

static func _boat_subcarrier(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	# Crane at the stern holding a little yellow submarine.
	Art.t_rect(ci, Rect2(-104, -124, 10, 88), 3, Color("ff9f1c"), 2.5, 0.3)
	Art.t_rect(ci, Rect2(-106, -128, 58, 9), 3, Color("ff9f1c"), 2.5, 0.3)
	Art.line(ci, Vector2(-56, -120), Vector2(-56, -86), Art.INK, 2.0)
	Art.push(ci, Vector2(-56, -68), sin(t * 1.2) * 0.06)
	Art.t_rect(ci, Rect2(-6, -22, 14, 10), 3, _paint(3, Art.GOLD), 2.2, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(4, -22), Vector2(4, -30), Vector2(10, -30)]), Art.METAL, 2.5, 1.2)
	Art.t_ellipse(ci, Vector2.ZERO, Vector2(28, 14), _paint(3, Art.GOLD), 2.8, 0.6)
	Art.t_circle(ci, Vector2(10, 0), 5.5, Art.METAL, 2.0, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(10, 0), 3.5, 12), Color("7fd8ff").lerp(LIT, _q(night, 4.0)))
	Art.t_circle(ci, Vector2(-6, 1), 4, Art.METAL, 1.8, 0.0)
	Art.push(ci, Vector2(-30, 0), 0.0, Vector2(1.0, cos(t * 8.0)))
	Art.t_ellipse(ci, Vector2(0, 0), Vector2(3, 8), Art.METAL, 1.6, 0.0)
	Art.pop(ci)
	Art.pop(ci)
	# Bridge with a radar dome.
	Art.t_rect(ci, Rect2(-36, -106, 44, 70), 7, Color("eef1f8"), 3.0, 0.5)
	_cabin_glass(ci, Rect2(-30, -98, 32, 22), 6, o, Vector2(-14, -80))
	Art.t_rect(ci, Rect2(-40, -112, 52, 9), 4, _paint(2, Color("35507e")), 2.6, 0.2)
	Art.stroke(ci, PackedVector2Array([Vector2(-14, -112), Vector2(-14, -118)]), Art.METAL, 3.0, 1.5)
	Art.t_circle(ci, Vector2(-14, -126), 10, Art.WHITE, 2.5, 0.5)
	lamp(ci, Vector2(-14, -140), night)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-114, -36), Vector2(20, -38), Vector2(104, -46), Vector2(94, -16), Vector2(76, 6), Vector2(-90, 6),
			Vector2(-112, -12)]), _paint(0, Color("3d5a80")), _paint(1, Art.GOLD), -33, 6, Color("24304a"), -6)
	_portholes(ci, [-80.0, -54.0, -28.0, -2.0, 24.0], -18, night, 4.5)
	Art.line(ci, Vector2(-112, -37), Vector2(102, -47), Art.INK, 2.5)


# 14. Golden yacht -------------------------------------------------------------------

static func _boat_yacht(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	var tint := Color("2d3b6b")
	flag(ci, Vector2(-100, -36), 44, _paint(4, Art.GOLD), t)
	# Three decks stepping up, dark window bands and gold trims.
	Art.t_rect(ci, Rect2(-92, -72, 116, 34), 12, Art.WHITE, 3.0, 0.4)
	Art.t_rect(ci, Rect2(-84, -64, 96, 13), 6, tint.lerp(LIT, _q(night * 0.6, 4.0)), 2.0, 0.0)
	Art.t_rect(ci, Rect2(-76, -98, 84, 28), 10, Art.WHITE, 3.0, 0.4)
	Art.t_rect(ci, Rect2(-68, -91, 44, 12), 5, tint.lerp(LIT, _q(night * 0.6, 4.0)), 2.0, 0.0)
	_cabin_glass(ci, Rect2(-20, -94, 24, 20), 6, o, Vector2(-8, -79), 0.42)
	Art.t_rect(ci, Rect2(-58, -116, 50, 20), 8, Art.WHITE, 3.0, 0.4)
	Art.arc(ci, Vector2(-33, -114), 16.0, PI, TAU, 12, Art.INK, 7.0)
	Art.arc(ci, Vector2(-33, -114), 16.0, PI, TAU, 12, Art.GOLD, 3.5)
	lamp(ci, Vector2(-30, -134), night)
	Art.line(ci, Vector2(-88, -71), Vector2(20, -71), Art.GOLD, 3.0)
	Art.line(ci, Vector2(-72, -97), Vector2(4, -97), Art.GOLD, 3.0)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-104, -36), Vector2(30, -40), Vector2(112, -56), Vector2(98, -22), Vector2(72, 4), Vector2(-82, 4),
			Vector2(-102, -14)]), _paint(0, Art.WHITE), _paint(1, Art.GOLD), -30, 6, Color("1f2a4e"), -6)
	Art.line(ci, Vector2(-100, -21), Vector2(96, -25), _paint(1, Art.GOLD), 2.0)
	# Sparkles.
	for i in 3:
		var ph := t * 1.6 + i * 2.1
		var s := maxf(0.0, sin(ph)) * 7.0
		var p := Vector2(-80 + i * 70, -110 + (i % 2) * 40)
		Art.flat_now(ci, Art.star_pts(p, s, s * 0.35, 4), Color(1, 0.95, 0.6, 0.95))


# 15. Crystal ark --------------------------------------------------------------------

static func _boat_ark(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var night: float = o["night"]
	var glow := 0.5 + 0.5 * sin(t * 2.0)
	halo(ci, Vector2(-58, -120), 60.0, Color(0.55, 0.95, 1.0, 0.25 + glow * 0.15))
	halo(ci, Vector2(-26, -130), 66.0, Color(1.0, 0.6, 0.95, 0.22 + (1.0 - glow) * 0.15))
	# Crystal masts.
	Art.crystal(ci, Vector2(-58, -78), 76, 14, -0.06, Color("8ef0ff"), 2.8)
	Art.crystal(ci, Vector2(-26, -80), 92, 16, 0.05, Color("ff9ff0"), 2.8)
	Art.crystal(ci, Vector2(-84, -78), 44, 9, -0.25, Color("b58cff"), 2.4)
	# A gem floating above, turning.
	Art.push(ci, Vector2(-42, -186 + sin(t * 1.8) * 5.0), 0.0, Vector2(cos(t * 1.5), 1.0))
	Art.toon(ci, PackedVector2Array([Vector2(0, -12), Vector2(9, -2), Vector2(0, 12), Vector2(-9, -2)]), Color("fff27a"), 2.2, 0.0)
	Art.pop(ci)
	flag(ci, Vector2(-112, -38), 44, _paint(4, Color("5affd8")), t)
	# Arched hall with stained glass.
	Art.t_rect(ci, Rect2(-100, -82, 84, 46), 14, Color("efe6ff"), 3.0, 0.5)
	var stained := [Color("8ef0ff"), Color("ff9ff0"), Color("fff27a")]
	for i in 3:
		if i == 1:
			_cabin_glass(ci, Rect2(-66, -74, 16, 26), 8, o, Vector2(-58, -58), 0.36)
		else:
			Art.t_rect(ci, Rect2(-90 + i * 24, -74, 16, 26), 8, stained[i].lerp(LIT, _q(night * 0.5, 4.0)), 2.2, 0.0)
	_deck_stuff(ci, o)
	_hull(ci, PackedVector2Array([Vector2(-112, -38), Vector2(20, -40), Vector2(106, -56), Vector2(92, -18), Vector2(72, 6), Vector2(-88, 6),
			Vector2(-110, -14)]), _paint(0, Color("5b3fa8")), _paint(1, Color("5affd8")), -32, 5, Color("2a1e5a"), -6)
	# Gems set into the hull.
	var gems := [Color("8ef0ff"), Color("ff9ff0"), Color("fff27a"), Color("5affd8"), Color("ff9ff0")]
	for i in 5:
		var p := Vector2(-78 + i * 34, -19)
		Art.toon(ci, PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)]), gems[i], 2.0, 0.0)
	# Star at the bow.
	Art.push(ci, Vector2(104, -60), sin(t * 2.0) * 0.2)
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 11, 5, 5), Color("fff27a"), 2.2, 0.0)
	Art.pop(ci)
	for i in 4:
		var ph := t * 1.7 + i * 1.6
		var s := maxf(0.0, sin(ph)) * 7.0
		var p := Vector2(-100 + i * 58, -150 + (i % 2) * 60)
		Art.flat_now(ci, Art.star_pts(p, s, s * 0.35, 4), Color(0.9, 1.0, 1.0, 0.95))


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


## Palm tree swaying in the wind; `shake` 0..1 (a tap) makes it wobble hard.
## `coconuts` how many still hang (0..2). Crown top at PALM_TOP.
const PALM_TOP := Vector2(-11, -96)


static func palm(ci: CanvasItem, t: float, wind_amount: float = 0.5, shake: float = 0.0, coconuts: int = 2) -> void:
	var sway := sin(t * (0.9 + wind_amount * 0.8)) * (0.02 + wind_amount * 0.035) + wind_amount * 0.04
	sway += sin(t * 14.0) * shake * 0.12
	var trunk := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		trunk.append(Vector2(sin(i * 0.3) * 6.0 - i * 1.5 + sway * 90.0 * f * f, -i * 16.0))
	for i in 6:
		Art.push(ci, trunk[i], atan2(trunk[i + 1].x - trunk[i].x, -(trunk[i + 1].y - trunk[i].y)))
		Art.toon(ci, PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(6, -17), Vector2(-6, -17)]), Art.WOOD, 2.3, 0.0)
		Art.pop(ci)
	var top := trunk[6]
	for i in 6:
		var a := -PI + i * PI / 5.0 + sin(t * (1.2 + wind_amount) + i) * (0.04 + wind_amount * 0.05) + sway * 1.4 \
				+ sin(t * 16.0 + i) * shake * 0.2
		Art.push(ci, top, a)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -4), Vector2(26, -10), Vector2(50, 2), Vector2(26, 6), Vector2(0, 4)]), 3), Color("3fb35a"), 2.3, 0.5)
		Art.pop(ci)
	if coconuts >= 1:
		Art.t_circle(ci, top + Vector2(-4, 4), 5, Color("8a5a2c"), 2.0, 0.0)
	if coconuts >= 2:
		Art.t_circle(ci, top + Vector2(5, 5), 5, Color("8a5a2c"), 2.0, 0.0)


# --- Plant ---------------------------------------------------------------------------

## The player's plant at its current stage (kept for older callers).
static func plant(ci: CanvasItem, t: float, working: bool, gear_rot: float, flash: float) -> void:
	plant_at_stage(ci, current_stage("plant"), t, working, gear_rot, flash)


## Plant look `stage` (1..15, see PLANT_STAGE_* names); origin on the
## ground under the left wall. `working` spins the machines and lights the
## windows, `gear_rot` turns the gears (default: from t), `flash` 0..1
## swells the coin sign after a payout, `night` 0..1 lights the windows
## (their glow: plant_lights).
static func plant_at_stage(ci: CanvasItem, stage: int, t: float, working: bool = true, gear_rot: float = INF,
		flash: float = 0.0, night: float = 0.0) -> void:
	var gr := t * 3.0 if is_inf(gear_rot) else gear_rot
	var lit := maxf(1.0 if working else 0.0, night)
	var o := {"t": t, "working": working, "gear": gr, "flash": flash, "lit": lit, "night": night}
	var s := clampi(stage, 1, STAGES)
	match s:
		1: _plant_tent(ci, o)
		2: _plant_shack(ci, o)
		3: _plant_workshop(ci, o)
		4: _plant_factory(ci, o)
		5: _plant_brick(ci, o)
		6: _plant_conveyor(ci, o)
		7: _plant_twin(ci, o)
		8: _plant_refinery(ci, o)
		9: _plant_lab(ci, o)
		10: _plant_solar(ci, o)
		11: _plant_turbine(ci, o)
		12: _plant_dome(ci, o)
		13: _plant_robot(ci, o)
		14: _plant_palace(ci, o)
		15: _plant_citadel(ci, o)
	for w: Array in _plant_windows(s):
		_window(ci, w[0], w[1], lit, w[1] < 8.0)
	_hopper(ci, s)


## Chimney tops (local) where smoke (or steam) comes out.
static func plant_smoke_points(stage: int) -> PackedVector2Array:
	match stage:
		2: return PackedVector2Array([Vector2(31, -146)])
		3: return PackedVector2Array([Vector2(30, -156)])
		4: return PackedVector2Array([Vector2(31, -176)])
		5: return PackedVector2Array([Vector2(28, -202)])
		6: return PackedVector2Array([Vector2(28, -146)])
		7: return PackedVector2Array([Vector2(27, -212), Vector2(61, -192)])
		8: return PackedVector2Array([Vector2(96, -196)])
		9: return PackedVector2Array([Vector2(130, -120)])
		13: return PackedVector2Array([Vector2(132, -124)])
	return PackedVector2Array()


## Top of the plant above its ground (for effects above it).
static func plant_height(stage: int) -> float:
	return [0, 124, 144, 156, 176, 202, 170, 212, 200, 176, 132, 200, 150, 160, 186, 200][clampi(stage, 1, STAGES)]


## Night glow of the windows, drawn with the plant's transform on a layer
## the night does not darken. amount 0..1.
static func plant_lights(ci: CanvasItem, stage: int, t: float, amount: float) -> void:
	if amount <= 0.01:
		return
	var s := clampi(stage, 1, STAGES)
	for w: Array in _plant_windows(s):
		var r: Rect2 = w[0]
		var i := int(r.position.x)
		var flick := 0.9 + sin(t * 3.0 + i) * 0.05 + sin(t * 7.3 + i * 0.3) * 0.05
		halo(ci, r.get_center(), maxf(r.size.x, r.size.y) * 1.3 + 8.0, Color(1.0, 0.82, 0.4, 0.34 * amount * flick))
		glow_poly(ci, Art.rrect_pts(r.grow(-2.0), maxf(1.0, float(w[1]) - 2.0)), Color(1.0, 0.93, 0.6, 0.85 * amount))
	for p: Vector3 in _plant_lamps(s):
		halo(ci, Vector2(p.x, p.y), p.z * 3.0, Color(1.0, 0.85, 0.5, 0.45 * amount))
		Art.disc(ci, Vector2(p.x, p.y), p.z * 0.5, Color(1.0, 0.96, 0.75, 0.9 * amount))


## Windows of each stage: [Rect2, corner radius].
static func _plant_windows(stage: int) -> Array:
	match stage:
		2: return [[Rect2(14, -66, 34, 26), 4.0], [Rect2(60, -66, 30, 26), 4.0]]
		3: return [[Rect2(14, -84, 30, 26), 5.0]]
		4: return [[Rect2(14, -78, 32, 26), 5.0], [Rect2(58, -78, 32, 26), 5.0], [Rect2(102, -78, 32, 26), 5.0]]
		5: return [[Rect2(14, -94, 28, 36), 13.0], [Rect2(60, -94, 28, 36), 13.0], [Rect2(106, -94, 28, 36), 13.0]]
		6: return [[Rect2(10, -82, 22, 22), 5.0], [Rect2(40, -82, 22, 22), 5.0], [Rect2(70, -82, 22, 22), 5.0]]
		7: return [[Rect2(12, -96, 30, 22), 5.0], [Rect2(58, -96, 30, 22), 5.0], [Rect2(104, -96, 30, 22), 5.0],
				[Rect2(12, -64, 30, 22), 5.0], [Rect2(58, -64, 30, 22), 5.0]]
		8: return [[Rect2(84, -68, 24, 20), 5.0], [Rect2(116, -68, 24, 20), 5.0]]
		9: return [[Rect2(14, -78, 28, 28), 14.0], [Rect2(52, -78, 28, 28), 14.0]]
		10: return [[Rect2(8, -62, 88, 34), 4.0]]
		11: return [[Rect2(12, -72, 26, 22), 5.0], [Rect2(46, -72, 26, 22), 5.0], [Rect2(80, -72, 26, 22), 5.0]]
		12: return [[Rect2(10, -44, 26, 20), 5.0], [Rect2(46, -44, 26, 20), 5.0]]
		13: return [[Rect2(10, -84, 32, 24), 4.0]]
		14: return [[Rect2(26, -86, 18, 30), 9.0], [Rect2(58, -86, 18, 30), 9.0], [Rect2(90, -86, 18, 30), 9.0]]
		15: return [[Rect2(16, -70, 24, 24), 12.0], [Rect2(58, -54, 22, 22), 11.0]]
	return []


## Extra lamps (x, y, size): lanterns, beacons.
static func _plant_lamps(stage: int) -> Array[Vector3]:
	match stage:
		1: return [Vector3(96, -60, 10)]
		8: return [Vector3(96, -186, 6)]
		9: return [Vector3(75, -140, 14)]
		12: return [Vector3(75, -80, 22)]
		13: return [Vector3(128, -152, 6)]
		14: return [Vector3(75, -186, 8)]
		15: return [Vector3(48, -206, 12)]
	return []


static func _door(ci: CanvasItem, color: Color, radius: float = 4.0) -> void:
	Art.t_rect(ci, Rect2(104, -44, 34, 44), radius, color, 2.8, 0.4)
	Art.t_circle(ci, Vector2(131, -22), 2.5, Art.GOLD, 1.2, 0.0)


static func _coin_sign(ci: CanvasItem, r: Rect2, flash: float, color: Color = Color("35507e")) -> void:
	Art.t_rect(ci, r, 8, color, 3.0, 0.3)
	Art.coin(ci, r.get_center(), minf(r.size.y * 0.36, 11.0) + flash * 3.0)


static func _hopper(ci: CanvasItem, stage: int) -> void:
	var c := Art.WOOD if stage <= 3 else (Art.GOLD if stage == 14 else (Color("b58cff") if stage == 15 else Art.METAL))
	if stage <= 3:
		Art.stroke(ci, PackedVector2Array([Vector2(-28, -42), Vector2(-30, 0)]), Art.WOOD_DARK, 4.0, 2.0)
		Art.stroke(ci, PackedVector2Array([Vector2(-2, -42), Vector2(0, 0)]), Art.WOOD_DARK, 4.0, 2.0)
	Art.toon(ci, PackedVector2Array([Vector2(-34, -64), Vector2(4, -64), Vector2(-4, -40), Vector2(-24, -40)]), c, 2.8, 0.5)
	Art.t_rect(ci, Rect2(-20, -42, 22, 12), 2, Color("5a5f7a"), 2.2, 0.0)


static func _saw_roof(ci: CanvasItem, y: float, color: Color, teeth: int = 3) -> void:
	var step := 165.0 / teeth
	var roof := PackedVector2Array([Vector2(-8, y + 4)])
	for i in teeth:
		roof.append(Vector2(-8 + i * step, y - 26))
		roof.append(Vector2(-8 + (i + 1) * step, y))
	roof.append(Vector2(157, y + 4))
	Art.toon(ci, roof, color, 3.2, 0.5)
	for i in teeth:
		Art.flat(ci, PackedVector2Array([Vector2(-4 + i * step, y - 20), Vector2(0 + i * step, y - 20), Vector2(0 + i * step, y - 4), Vector2(-4 + i * step, y - 4)]), Art.GLASS)


static func _big_gears(ci: CanvasItem, o: Dictionary, color: Color = Art.GOLD) -> void:
	var gr: float = o["gear"]
	Art.gear(ci, Vector2(14, -22), 16, color, gr)
	Art.gear(ci, Vector2(40, -12), 10, Color("ffb13b"), -gr * 1.6, 6)


# 1. Sorting tent ---------------------------------------------------------------------

static func _plant_tent(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	flag(ci, Vector2(75, -96), 28, Art.GOLD, t, 0.8)
	var tent := PackedVector2Array([Vector2(-2, 0), Vector2(8, -60), Vector2(75, -98), Vector2(142, -60), Vector2(152, 0)])
	Art.toon(ci, tent, Art.CREAM, 3.2, 0.4)
	for i in 5:
		var x0 := -20.0 + i * 38.0
		var stripe := PackedVector2Array([Vector2(x0, 4), Vector2(x0 + 18, 4), Vector2(75 + (x0 + 18 - 75) * 0.12, -100), Vector2(75 + (x0 - 75) * 0.12, -100)])
		Art.flat(ci, Art.clipped(stripe, tent), Art.RED)
	# Bunting along the eaves.
	var bunting := PackedVector2Array()
	for i in 8:
		bunting.append(Vector2(8 + i * 19.4, -60 + sin(i / 7.0 * PI) * 6.0))
	Art.polyline(ci, bunting, Art.INK, 2.0)
	var flags := [Art.GOLD, Art.TEAL, Art.BLUE]
	for i in 7:
		var p := bunting[i].lerp(bunting[i + 1], 0.5)
		Art.toon(ci, PackedVector2Array([p + Vector2(-6, -1), p + Vector2(6, -1), p + Vector2(0, 9)]), flags[i % 3], 1.8, 0.0)
	# Open flap for the door.
	Art.toon(ci, PackedVector2Array([Vector2(104, 0), Vector2(121, -50), Vector2(138, 0)]), Color("5a3a2a"), 2.5, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(121, -50), Vector2(104, 0), Vector2(98, 0)]), Art.CREAM_DARK, 2.2, 0.0)
	# Sorting table with baskets of ore.
	Art.t_rect(ci, Rect2(10, -30, 64, 8), 3, Art.WOOD, 2.5, 0.3)
	for x: float in [16.0, 66.0]:
		Art.stroke(ci, PackedVector2Array([Vector2(x, -22), Vector2(x, 0)]), Art.WOOD_DARK, 3.0, 1.5)
	for i in 2:
		Art.t_rect(ci, Rect2(16 + i * 30, -42, 24, 13), 4, Color("d9a066"), 2.2, 0.3)
		Art.crystal(ci, Vector2(28 + i * 30, -41), 10, 4.0, 0.2 - i * 0.4, Color("ff8fb0") if i == 0 else Color("7fd8ff"), 1.5)
	# Lantern at the entrance and the coin sign.
	Art.line(ci, Vector2(96, -76), Vector2(96, -68), Art.INK, 1.6)
	lamp(ci, Vector2(96, -60), o["night"])
	_coin_sign(ci, Rect2(48, -90, 40, 22), o["flash"])


# 2. Wooden shack ---------------------------------------------------------------------

static func _plant_shack(ci: CanvasItem, o: Dictionary) -> void:
	Art.t_rect(ci, Rect2(26, -138, 10, 62), 2, Art.METAL, 2.3, 0.0)
	Art.t_rect(ci, Rect2(22, -144, 18, 8), 2, Color("5a5f7a"), 2.3, 0.0)
	Art.t_rect(ci, Rect2(0, -86, 150, 86), 4, Art.WOOD, 3.2, 0.5)
	for i in 9:
		Art.line(ci, Vector2(14 + i * 15, -80), Vector2(14 + i * 15, -4), Art.WOOD_DARK, 1.8)
	Art.push(ci, Vector2(75, -92), -0.08)
	Art.t_rect(ci, Rect2(-90, -9, 180, 16), 3, Color("8fa3b8"), 3.0, 0.4)
	for i in 11:
		Art.line(ci, Vector2(-82 + i * 16, -6), Vector2(-82 + i * 16, 5), Color("6f8298"), 1.6)
	Art.pop(ci)
	_door(ci, Art.WOOD_DARK)
	_coin_sign(ci, Rect2(98, -70, 46, 20), o["flash"])


# 3. Gear workshop --------------------------------------------------------------------

static func _plant_workshop(ci: CanvasItem, o: Dictionary) -> void:
	var gr: float = o["gear"]
	Art.t_rect(ci, Rect2(18, -150, 24, 70), 3, Color("c0503e"), 3.0, 0.5)
	Art.t_rect(ci, Rect2(14, -156, 32, 9), 3, Color("3a3f5c"), 2.8, 0.0)
	Art.t_rect(ci, Rect2(2, -98, 146, 70), 4, Color("e8b87a"), 3.2, 0.4)
	Art.toon(ci, PackedVector2Array([Vector2(-10, -94), Vector2(75, -136), Vector2(160, -94)]), Color("d65a4a"), 3.2, 0.5)
	Art.t_rect(ci, Rect2(0, -34, 150, 34), 4, Color("a8a4b8"), 3.2, 0.5)
	for i in 5:
		Art.line(ci, Vector2(12 + i * 30, -30), Vector2(12 + i * 30, -4), Color("8a86a0"), 1.8)
	Art.line(ci, Vector2(4, -17), Vector2(100, -17), Color("8a86a0"), 1.8)
	# Big gear on the front, turning while it works.
	Art.gear(ci, Vector2(76, -64), 24, Art.GOLD, gr * 0.7)
	Art.gear(ci, Vector2(108, -80), 11, Color("ffb13b"), -gr * 1.5, 6)
	Art.coin(ci, Vector2(75, -108), 9 + float(o["flash"]) * 3.0)
	_door(ci, Art.WOOD_DARK)


# 4. Small factory (the classic plant) ------------------------------------------------

static func _plant_factory(ci: CanvasItem, o: Dictionary) -> void:
	Art.t_rect(ci, Rect2(18, -168, 26, 84), 4, Color("d65a4a"), 3.0, 0.5)
	for i in 3:
		Art.flat(ci, Art.rrect_pts(Rect2(18, -160 + i * 22, 26, 7), 1), Color("fff1e0"))
	Art.t_rect(ci, Rect2(14, -174, 34, 10), 3, Color("3a3f5c"), 2.8, 0.0)
	Art.t_rect(ci, Rect2(0, -100, 150, 100), 6, Art.CREAM, 3.2, 0.5)
	_saw_roof(ci, -100, Art.TEAL)
	_door(ci, Art.WOOD)
	_coin_sign(ci, Rect2(44, -150, 62, 28), o["flash"])
	_big_gears(ci, o)


# 5. Brick works ----------------------------------------------------------------------

static func _plant_brick(ci: CanvasItem, o: Dictionary) -> void:
	var brick := Color("c85a44")
	Art.t_rect(ci, Rect2(14, -196, 28, 92), 4, Color("b34a3a"), 3.0, 0.5)
	for i in 3:
		Art.flat(ci, Art.rrect_pts(Rect2(14, -186 + i * 26, 28, 6), 1), Color("fff1e0"))
	Art.t_rect(ci, Rect2(10, -202, 36, 10), 3, Color("3a3f5c"), 2.8, 0.0)
	Art.t_rect(ci, Rect2(0, -110, 150, 110), 6, brick, 3.2, 0.5)
	for r in 8:
		var y := -100.0 + r * 12.0
		Art.flat(ci, Art.rrect_pts(Rect2(3, y, 144, 2), 0.5), Art.shade_of(brick, 0.3))
		for k in 5:
			var x := 18.0 + k * 30.0 + (15.0 if r % 2 == 0 else 0.0)
			if x < 146.0:
				Art.flat(ci, Art.rrect_pts(Rect2(x, y - 10, 2, 10), 0.5), Art.shade_of(brick, 0.3))
	Art.t_rect(ci, Rect2(-6, -120, 162, 12), 3, Color("e8d5b0"), 3.0, 0.3)
	_coin_sign(ci, Rect2(52, -144, 56, 24), o["flash"])
	_door(ci, Art.WOOD_DARK, 12.0)
	_big_gears(ci, o)


# 6. Conveyor hall --------------------------------------------------------------------

static func _plant_conveyor(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var working: bool = o["working"]
	Art.t_rect(ci, Rect2(20, -140, 16, 44), 3, Color("d65a4a"), 2.8, 0.4)
	Art.t_rect(ci, Rect2(16, -146, 24, 8), 3, Color("3a3f5c"), 2.5, 0.0)
	# Tower with a bucket elevator.
	Art.t_rect(ci, Rect2(98, -170, 48, 80), 5, Color("dfe6f0"), 3.0, 0.4)
	var slot := Rect2(110, -162, 22, 60)
	Art.t_rect(ci, slot, 3, Color("3a3f5c"), 2.2, 0.0)
	for k in 4:
		var y := slot.end.y - 10.0 - fposmod((t * 22.0 if working else 0.0) + k * 15.0, 52.0)
		Art.t_rect(ci, Rect2(113, y, 16, 8), 2, Art.GOLD, 1.6, 0.0)
	Art.t_rect(ci, Rect2(94, -176, 56, 9), 3, Art.TEAL, 2.8, 0.2)
	# Hall with a round roof.
	Art.t_rect(ci, Rect2(0, -98, 150, 98), 6, Art.CREAM, 3.2, 0.5)
	var roof := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		roof.append(Vector2(lerpf(-8, 102, f), -94 - sin(f * PI) * 22.0))
	roof.append(Vector2(102, -90))
	roof.append(Vector2(-8, -90))
	Art.toon(ci, roof, Art.TEAL, 3.0, 0.5)
	# Belt from the roof up into the tower.
	Art.stroke(ci, PackedVector2Array([Vector2(40, -118), Vector2(100, -150)]), Color("3a3f5c"), 9.0, 2.2)
	if working:
		for k in 3:
			var f := fposmod(t * 0.5 + k / 3.0, 1.0)
			Art.crystal(ci, Vector2(40, -118).lerp(Vector2(100, -150), f) + Vector2(0, -4), 9, 3.5, -0.5, Color("ff8fb0"), 1.4)
	_coin_sign(ci, Rect2(102, -94, 40, 22), o["flash"])
	# Roll-up door.
	Art.t_rect(ci, Rect2(104, -44, 34, 44), 3, Color("aab6c8"), 2.8, 0.2)
	for i in 5:
		Art.line(ci, Vector2(106, -38 + i * 8), Vector2(136, -38 + i * 8), Color("7a8698"), 1.6)
	_big_gears(ci, o)


# 7. Twin chimneys --------------------------------------------------------------------

static func _plant_twin(ci: CanvasItem, o: Dictionary) -> void:
	for c: Vector3 in [Vector3(27, -206, 26), Vector3(61, -186, 24)]:
		var x := c.x
		Art.t_rect(ci, Rect2(x - c.z / 2.0, c.y + 6, c.z, -c.y - 100), 4, Color("e8ecf5"), 3.0, 0.5)
		for i in 3:
			Art.flat(ci, Art.rrect_pts(Rect2(x - c.z / 2.0, c.y + 14 + i * 26, c.z, 10), 1), Art.RED)
		Art.t_rect(ci, Rect2(x - c.z / 2.0 - 4, c.y, c.z + 8, 10), 3, Color("3a3f5c"), 2.8, 0.0)
	Art.t_rect(ci, Rect2(0, -112, 150, 112), 6, Color("d7dce8"), 3.2, 0.5)
	_saw_roof(ci, -112, Art.TEAL, 4)
	_coin_sign(ci, Rect2(96, -68, 42, 20), o["flash"])
	_door(ci, Color("5a6f9a"))
	_big_gears(ci, o)


# 8. Refinery -------------------------------------------------------------------------

static func _plant_refinery(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var working: bool = o["working"]
	# Column with platforms and a flare stack.
	Art.t_rect(ci, Rect2(56, -190, 22, 110), 6, Color("e8ecf5"), 3.0, 0.5)
	for y: float in [-170.0, -140.0, -110.0]:
		Art.t_rect(ci, Rect2(50, y, 34, 5), 1, Art.GOLD, 2.0, 0.0)
	Art.t_rect(ci, Rect2(92, -180, 8, 100), 2, Color("aab6c8"), 2.4, 0.0)
	var fl := (1.0 if working else 0.45) * (1.0 + sin(t * 11.0) * 0.12)
	Art.push(ci, Vector2(96, -182), sin(t * 5.0) * 0.08, Vector2(fl, fl))
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-7, 0), Vector2(-4, -12), Vector2(0, -22), Vector2(4, -12), Vector2(7, 0)]), 3), Color("ff9a3c"), 2.0, 0.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-3.5, 0), Vector2(0, -12), Vector2(3.5, 0)]), 3), Color("fff27a"), 0.0, 0.0)
	Art.pop(ci)
	# Round tank on legs.
	for x: float in [8.0, 36.0]:
		Art.stroke(ci, PackedVector2Array([Vector2(x, -110), Vector2(x, 0)]), Color("aab6c8"), 4.0, 2.0)
	Art.t_circle(ci, Vector2(22, -112), 26, Art.WHITE, 3.0, 0.6)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-10, -116, 70, 7), 1), Art.circle_pts(Vector2(22, -112), 26)), Art.TEAL)
	# Pipes.
	Art.stroke(ci, PackedVector2Array([Vector2(46, -100), Vector2(56, -100)]), Art.METAL, 5.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(78, -120), Vector2(92, -120)]), Art.METAL, 5.0, 2.0)
	# Main building.
	Art.t_rect(ci, Rect2(44, -82, 106, 82), 6, Art.CREAM, 3.2, 0.5)
	Art.t_rect(ci, Rect2(40, -88, 114, 10), 3, Color("35507e"), 2.8, 0.2)
	_coin_sign(ci, Rect2(50, -52, 44, 22), o["flash"])
	_door(ci, Color("5a6f9a"))
	Art.gear(ci, Vector2(22, -22), 16, Art.GOLD, float(o["gear"]))


# 9. Crystal lab ----------------------------------------------------------------------

static func _plant_lab(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var glow := 0.5 + 0.5 * sin(t * 2.2)
	halo(ci, Vector2(75, -142), 70.0, Color(0.55, 0.95, 1.0, 0.28 + glow * 0.2))
	Art.t_rect(ci, Rect2(52, -114, 46, 16), 4, Color("aab6c8"), 2.8, 0.3)
	Art.crystal(ci, Vector2(75, -112), 62, 17, 0.0, Color("8ef0ff"), 2.8)
	Art.crystal(ci, Vector2(60, -112), 30, 8, -0.4, Color("b58cff"), 2.2)
	Art.crystal(ci, Vector2(91, -112), 34, 8, 0.4, Color("ff9ff0"), 2.2)
	# Vent pipe and satellite dish.
	Art.t_rect(ci, Rect2(124, -118, 12, 22), 2, Art.METAL, 2.3, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(20, -100), Vector2(20, -112)]), Art.METAL, 3.0, 1.5)
	Art.push(ci, Vector2(20, -116), -0.5 + sin(t * 0.7) * 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(-12, -2), Vector2(12, -2), Vector2(8, 4), Vector2(-8, 4)]), Art.WHITE, 2.2, 0.0)
	Art.pop(ci)
	Art.t_rect(ci, Rect2(0, -100, 150, 100), 18, Color("f4f7ff"), 3.2, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(3, -40, 144, 7), 1), Art.TEAL)
	# Bubbling flask tube by the door.
	Art.t_rect(ci, Rect2(88, -78, 14, 34), 7, Color(0.6, 1.0, 0.9, 0.9), 2.2, 0.0)
	for k in 3:
		var f := fposmod(t * 0.8 + k / 3.0, 1.0)
		Art.disc(ci, Vector2(95 + sin(f * 9.0 + k) * 2.0, -48 - f * 26.0), 2.2, Color(1, 1, 1, 0.9 * (1.0 - f)))
	_coin_sign(ci, Rect2(100, -90, 44, 22), o["flash"], Color("8a6cf0"))
	_door(ci, Color("7fd8ff"), 6.0)
	Art.gear(ci, Vector2(22, -22), 14, Color("b58cff"), float(o["gear"]))


# 10. Solar factory -------------------------------------------------------------------

static func _plant_solar(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	Art.t_rect(ci, Rect2(0, -96, 150, 96), 8, Color("eef3fa"), 3.2, 0.5)
	# Tilted solar panels on the roof, a glint sweeping across.
	var roof := PackedVector2Array([Vector2(-8, -92), Vector2(158, -92), Vector2(146, -130), Vector2(4, -130)])
	Art.toon(ci, roof, Color("27418a"), 3.0, 0.0)
	for i in 5:
		var x := 4.0 + i * 30.0
		Art.line(ci, Vector2(x + 4, -128), Vector2(x - 2, -94), Color("7fb8ff"), 1.6)
	Art.line(ci, Vector2(-2, -111), Vector2(152, -111), Color("7fb8ff"), 1.6)
	var g := fposmod(t * 0.25, 1.4) - 0.2
	var gx := lerpf(-10, 160, g)
	var glint := PackedVector2Array([Vector2(gx, -128), Vector2(gx + 14, -128), Vector2(gx + 2, -94), Vector2(gx - 12, -94)])
	if g > -0.1 and g < 1.1:
		Art.flat_now(ci, Art.clipped(glint, roof), Color(1, 1, 1, 0.35))
	Art.stroke(ci, PackedVector2Array([Vector2(20, -92), Vector2(20, -80)]), Art.METAL, 3.0, 1.5)
	_coin_sign(ci, Rect2(100, -84, 44, 22), o["flash"], Color("2bc8b4"))
	_door(ci, Color("7fd8ff"), 5.0)
	_big_gears(ci, o, Color("5cd05f"))


# 11. Turbine plant -------------------------------------------------------------------

static func _plant_turbine(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var spin := t * (1.2 + wind * 2.2) + (t * 1.5 if o["working"] else 0.0)
	for c: Vector3 in [Vector3(16, -190, 1.0), Vector3(134, -170, 0.85)]:
		var hub := Vector2(c.x, c.y)
		Art.toon(ci, PackedVector2Array([hub + Vector2(-3, 4), hub + Vector2(3, 4), hub + Vector2(6, -c.y - 94), hub + Vector2(-6, -c.y - 94)]), Art.WHITE, 2.5, 0.3)
		Art.push(ci, hub, spin * c.z + c.x, Vector2(c.z, c.z))
		for i in 3:
			Art.push(ci, Vector2.ZERO, TAU * i / 3.0)
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-3, 0), Vector2(-5, -20), Vector2(0, -44), Vector2(4, -20), Vector2(3, 0)]), 2), Art.WHITE, 2.2, 0.3)
			Art.pop(ci)
		Art.t_circle(ci, Vector2.ZERO, 6, Art.GREEN, 2.2, 0.0)
		Art.pop(ci)
	Art.t_rect(ci, Rect2(0, -96, 150, 96), 8, Color("e6f4ea"), 3.2, 0.5)
	var roof := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		roof.append(Vector2(lerpf(-8, 158, f), -92 - sin(f * PI) * 16.0))
	Art.toon(ci, roof, Art.GREEN, 3.0, 0.5)
	_coin_sign(ci, Rect2(48, -126, 54, 22), o["flash"], Art.GREEN_DARK)
	_door(ci, Color("5a6f9a"))
	_big_gears(ci, o, Art.GREEN)


# 12. Glass dome ----------------------------------------------------------------------

static func _plant_dome(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var c := Vector2(75, -56)
	var dome := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		dome.append(c + Vector2(cos(a) * 72.0, sin(a) * 80.0))
	# Garden inside: glowing crystals and a little tree.
	halo(ci, c + Vector2(0, -24), 70.0, Color(0.6, 1.0, 0.85, 0.3 + sin(t * 1.6) * 0.06))
	Art.flat(ci, dome, Color(0.72, 0.95, 1.0, 1.0))
	Art.crystals(ci, c + Vector2(-32, 0), 34, {"ore": Color("8ef0ff"), "ore2": Color("b58cff")}, 5, 3)
	Art.crystals(ci, c + Vector2(34, 0), 30, {"ore": Color("ff9ff0"), "ore2": Color("fff27a")}, 8, 3)
	Art.stroke(ci, PackedVector2Array([c, c + Vector2(0, -40)]), Art.WOOD, 5.0, 2.0)
	Art.t_circle(ci, c + Vector2(0, -52), 20, Art.GREEN, 2.5, 0.5)
	Art.t_circle(ci, c + Vector2(-8, -56), 4, Art.CORAL, 1.5, 0.0)
	Art.t_circle(ci, c + Vector2(8, -46), 4, Art.GOLD, 1.5, 0.0)
	# Frame and shine.
	Art.ring(ci, dome, Art.INK, 3.0)
	for side: float in [-1.0, 1.0]:
		var m := PackedVector2Array()
		for i in 9:
			var a := PI * 1.5 + side * PI * 0.5 * i / 8.0
			m.append(c + Vector2(cos(a) * 40.0, sin(a) * 80.0))
		Art.polyline(ci, m, Color("5a5f7a"), 2.2)
	Art.line(ci, c, c + Vector2(0, -80), Color("5a5f7a"), 2.2)
	Art.line(ci, c + Vector2(-62, -40), c + Vector2(62, -40), Color("5a5f7a"), 2.2)
	Art.arc(ci, c, 60.0, PI * 1.12, PI * 1.35, 8, Color(1, 1, 1, 0.8), 5.0)
	Art.t_rect(ci, Rect2(71, -146, 8, 14), 2, Art.GOLD, 2.2, 0.0)
	Art.t_circle(ci, Vector2(75, -150), 6, Art.GOLD, 2.2, 0.3)
	# Base.
	Art.t_rect(ci, Rect2(-6, -58, 162, 58), 8, Color("e8e0f0"), 3.2, 0.5)
	_coin_sign(ci, Rect2(80, -50, 20, 20), o["flash"], Color("8a6cf0"))
	_door(ci, Color("7fd8ff"), 6.0)


# 13. Robot factory -------------------------------------------------------------------

static func _plant_robot(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	var working: bool = o["working"]
	# Antenna with a blinking light.
	Art.stroke(ci, PackedVector2Array([Vector2(128, -110), Vector2(128, -148)]), Art.METAL, 3.0, 1.5)
	var blink := 1.0 if fposmod(t, 1.2) < 0.6 else 0.3
	Art.t_circle(ci, Vector2(128, -152), 5, Art.RED.lerp(Color("ffb0a0"), blink - 0.3), 2.0, 0.0)
	# Robot arm on the roof.
	var a1 := -0.5 + (sin(t * 1.6) * 0.45 if working else 0.0)
	var a2 := 1.2 + (sin(t * 1.6 + 1.2) * 0.5 if working else 0.0)
	Art.t_rect(ci, Rect2(28, -124, 26, 16), 4, Color("ff9f1c"), 2.6, 0.3)
	Art.push(ci, Vector2(41, -120), a1)
	Art.t_rect(ci, Rect2(-5, -44, 10, 46), 4, Color("ff9f1c"), 2.5, 0.3)
	Art.push(ci, Vector2(0, -42), a2)
	Art.t_rect(ci, Rect2(-4, -34, 8, 36), 3, Color("ffb13b"), 2.3, 0.3)
	Art.stroke(ci, PackedVector2Array([Vector2(-6, -34), Vector2(-8, -42)]), Art.METAL, 3.0, 1.2)
	Art.stroke(ci, PackedVector2Array([Vector2(6, -34), Vector2(8, -42)]), Art.METAL, 3.0, 1.2)
	Art.crystal(ci, Vector2(0, -36), 12, 4.5, 0.0, Color("ff8fb0"), 1.5)
	Art.t_circle(ci, Vector2.ZERO, 5, Art.METAL, 2.0, 0.0)
	Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 6, Art.METAL, 2.0, 0.0)
	Art.pop(ci)
	Art.t_rect(ci, Rect2(122, -120, 18, 12), 2, Color("5a5f7a"), 2.3, 0.0)
	Art.t_rect(ci, Rect2(0, -112, 150, 112), 6, Color("aab6c8"), 3.2, 0.5)
	for i in 8:
		Art.disc(ci, Vector2(10 + i * 18.5, -104), 2.0, Color("7a8698"))
	# Screen with a robot face.
	Art.t_rect(ci, Rect2(54, -94, 56, 36), 6, Color("1f2a4e"), 3.0, 0.0)
	var eye := 0.2 if fposmod(t, 3.3) < 0.15 else 1.0
	for x: float in [70.0, 94.0]:
		Art.push(ci, Vector2(x, -80), 0.0, Vector2(1.0, eye))
		Art.t_rect(ci, Rect2(-5, -6, 10, 12), 4, Color("5affd8"), 0.0, 0.0)
		Art.pop(ci)
	Art.arc(ci, Vector2(82, -72), 8.0, 0.3, PI - 0.3, 8, Color("5affd8"), 2.5)
	_coin_sign(ci, Rect2(10, -52, 40, 20), o["flash"])
	# Sliding door with hazard stripes.
	Art.t_rect(ci, Rect2(104, -44, 34, 44), 3, Color("ffd23f"), 2.8, 0.2)
	for i in 4:
		var y := -40.0 + i * 11.0
		Art.flat(ci, Art.clipped(PackedVector2Array([Vector2(104, y + 6), Vector2(110, y), Vector2(138, y + 20), Vector2(132, y + 26)]),
				Art.rrect_pts(Rect2(104, -44, 34, 44), 3)), Color("3a3f5c"))
	Art.gear(ci, Vector2(66, -22), 14, Art.METAL, float(o["gear"]))


# 14. Golden palace -------------------------------------------------------------------

static func _plant_palace(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	# Central onion dome with a spire.
	var dome := Art.smooth_pts(PackedVector2Array([Vector2(44, -102), Vector2(40, -128), Vector2(58, -152), Vector2(75, -172),
			Vector2(92, -152), Vector2(110, -128), Vector2(106, -102)]), 3)
	Art.toon(ci, dome, Art.GOLD, 3.2, 0.7)
	Art.stroke(ci, PackedVector2Array([Vector2(75, -172), Vector2(75, -186)]), Art.GOLD, 3.0, 1.5)
	Art.disc(ci, Vector2(75, -188), 4.0, Art.GOLD)
	# Side towers with small gold domes and flags.
	for x: float in [-4.0, 126.0]:
		Art.t_rect(ci, Rect2(x, -128, 28, 128), 4, Art.CREAM, 3.0, 0.4)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(x - 2, -126), Vector2(x + 14, -156), Vector2(x + 30, -126)]), 3), Art.GOLD, 3.0, 0.6)
		flag(ci, Vector2(x + 14, -154), 20, Art.RED, t + x, 0.7)
		_window(ci, Rect2(x + 8, -112, 12, 20), 6.0, float(o["lit"]), false)
	# Main hall with columns.
	Art.t_rect(ci, Rect2(20, -104, 110, 104), 5, Color("fff6e4"), 3.2, 0.4)
	Art.t_rect(ci, Rect2(16, -108, 118, 10), 3, Art.GOLD, 2.8, 0.3)
	for i in 5:
		var x := 24.0 + i * 22.0
		Art.t_rect(ci, Rect2(x, -54, 8, 54), 2, Art.WHITE, 2.2, 0.2)
		Art.t_rect(ci, Rect2(x - 2, -56, 12, 4), 1, Art.GOLD, 1.6, 0.0)
	_coin_sign(ci, Rect2(52, -134, 46, 22), o["flash"], Color("d8363c"))
	_door(ci, Art.GOLD_DARK, 12.0)
	for i in 3:
		var ph := t * 1.5 + i * 2.1
		var s := maxf(0.0, sin(ph)) * 7.0
		Art.flat_now(ci, Art.star_pts(Vector2(10 + i * 64, -150 + (i % 2) * 30), s, s * 0.35, 4), Color(1, 0.95, 0.6, 0.95))


# 15. Coral citadel -------------------------------------------------------------------

static func _plant_citadel(ci: CanvasItem, o: Dictionary) -> void:
	var t: float = o["t"]
	halo(ci, Vector2(48, -206), 46.0, Color(0.55, 0.95, 1.0, 0.3 + sin(t * 2.0) * 0.1))
	# Coral spires with pearls on top.
	var spires := [[Vector2(8, 0), 150.0, 16.0, Color("ff7a8a")], [Vector2(48, 0), 190.0, 20.0, Color("ff9fb8")],
			[Vector2(112, 0), 168.0, 18.0, Color("b58cff")], [Vector2(142, 0), 128.0, 14.0, Color("ffa84a")]]
	for s: Array in spires:
		var b: Vector2 = s[0]
		var h: float = s[1]
		var w: float = s[2]
		var pts := Art.smooth_pts(PackedVector2Array([b + Vector2(-w, 0), b + Vector2(-w * 0.8, -h * 0.5), b + Vector2(-w * 0.55, -h * 0.85),
				b + Vector2(0, -h), b + Vector2(w * 0.55, -h * 0.85), b + Vector2(w * 0.8, -h * 0.5), b + Vector2(w, 0)]), 3)
		Art.toon(ci, pts, s[3], 3.0, 0.6)
		for k in 3:
			Art.disc(ci, b + Vector2(-w * 0.3 + k * w * 0.3, -h * (0.3 + k * 0.18)), 2.5, Color(1, 1, 1, 0.5))
		Art.t_circle(ci, b + Vector2(0, -h - 6), 7, Color("fbf8ff"), 2.2, 0.4)
	Art.crystal(ci, Vector2(48, -202), 26, 8, 0.0, Color("8ef0ff"), 2.2)
	# Scallop shell dome.
	var c := Vector2(80, -84)
	var shell := PackedVector2Array([c + Vector2(0, 8)])
	for i in 15:
		var a := PI + PI * i / 14.0
		var r := 52.0 + (4.0 if i % 2 == 0 else 0.0)
		shell.append(c + Vector2(cos(a), sin(a)) * r)
	Art.toon(ci, shell, Color("ffd6e0"), 3.0, 0.5)
	for i in 6:
		var a := PI + PI * (i + 1) / 7.0
		Art.line(ci, c + Vector2(0, 4), c + Vector2(cos(a), sin(a)) * 48.0, Color("f0a8bc"), 2.2)
	Art.t_circle(ci, c + Vector2(0, -8), 8, Color("fbf8ff"), 2.2, 0.4)
	# Body.
	Art.t_rect(ci, Rect2(0, -86, 150, 86), 16, Color("ff9fb8"), 3.2, 0.5)
	_coin_sign(ci, Rect2(96, -80, 44, 22), o["flash"], Color("8a6cf0"))
	_door(ci, Color("b58cff"), 16.0)
	for k in 4:
		var f := fposmod(t * 0.35 + k / 4.0, 1.0)
		var p := Vector2(20 + k * 38 + sin(f * 7.0 + k) * 4.0, -60 - f * 150.0)
		Art.arc(ci, p, 3.0 + f * 2.0, 0, TAU, 10, Color(1, 1, 1, 0.7 * (1.0 - f)), 1.5)
	Art.gear(ci, Vector2(22, -22), 14, Color("5affd8"), float(o["gear"]))


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
