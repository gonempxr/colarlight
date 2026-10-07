class_name FishingScene
extends RefCounted
## The place you fish from, in the current world's colors (WorldLook):
##   ocean   - a wooden pier over the sea,
##   volcano - a basalt ledge over thick glowing magma (with fire fish),
##   acid    - a mossy boardwalk over a bubbling swamp with lily pads,
##   moon    - the rim of a crater full of starry space goo.
## FishingScreen draws the sky and the "water" with back(), the ledge the
## player stands on with ledge(), the fisherman's raft with raft(), and asks
## for the splash, ripple and fish-shadow colors.

const OCEAN := 0
const VOLCANO := 1
const ACID := 2
const MOON := 3

var world := OCEAN
var look: Dictionary = {}
var _stars: Array[Vector3] = []
var _plates: Array[Dictionary] = []
var _pads: Array[Vector3] = []
var _bubbles: Array[Vector3] = []
var _clouds: Array[Vector3] = []
var _shadows: Array[Vector3] = []


func _init(world_index: int = 0, world_look: Dictionary = {}) -> void:
	world = posmod(world_index, 4)
	look = world_look if not world_look.is_empty() else WorldLook.LOOKS[WorldLook.WORLDS[world]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + world
	for i in 70:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.4)))
	for i in 40:
		_plates.append({"x": (i / 8) * 0.21 + rng.randf_range(0.0, 0.08), "row": i % 8, "w": rng.randf_range(1.0, 1.6), "seed": rng.randi() % 1000, "sp": rng.randf_range(0.6, 1.4)})
	for i in 6:
		_pads.append(Vector3(rng.randf(), rng.randf_range(0.15, 0.85), rng.randf_range(0.8, 1.25)))
	for i in 7:
		_bubbles.append(Vector3(rng.randf(), rng.randf_range(0.1, 0.9), rng.randf()))
	for i in 4:
		_clouds.append(Vector3(rng.randf(), rng.randf_range(0.2, 0.75), rng.randf_range(0.8, 1.3)))
	for i in 5:
		_shadows.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.3)))


func col(key: String, fallback: Color = Color.MAGENTA) -> Color:
	var c = look.get(key, null)
	return c if c is Color else fallback


func sea(i: int) -> Color:
	var arr: Array = look.get("sea", [Art.SEA_TOP, Art.SEA_MID, Art.SEA_DEEP, Art.SEA_ABYSS])
	return arr[clampi(i, 0, arr.size() - 1)]


func sky(i: int) -> Color:
	var arr: Array = look.get("day", [Art.SKY_TOP, Color("8fd2f7"), Art.SKY_BOTTOM])
	return arr[clampi(i, 0, arr.size() - 1)]


## Splash drops.
func drop_color() -> Color:
	return [Color(0.85, 0.97, 1.0), Color(1.0, 0.78, 0.3), Color(0.78, 1.0, 0.45), Color(0.82, 0.78, 1.0)][world]


## Ripple rings on the surface.
func ring_color() -> Color:
	return [Color(1, 1, 1), Color(1.0, 0.9, 0.55), Color(0.9, 1.0, 0.7), Color(0.8, 0.75, 1.0)][world]


func shadow_color(alpha: float) -> Color:
	match world:
		VOLCANO:
			return Color(0.25, 0.02, 0.02, alpha * 1.6)
		ACID:
			return Color(0.05, 0.18, 0.08, alpha * 1.3)
		MOON:
			return Color(0.75, 0.85, 1.0, alpha * 0.8)
	return Color(0.03, 0.12, 0.3, alpha)


## Hint text color that reads on this world's sky.
func hint_color() -> Color:
	return Art.WHITE


# --- Sky and water -------------------------------------------------------------------

func back(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	_sky(ci, v, hz, t, k)
	match world:
		OCEAN:
			_ocean(ci, v, hz, t, k)
		VOLCANO:
			_magma(ci, v, hz, t, k)
		ACID:
			_swamp(ci, v, hz, t, k)
		MOON:
			_crater(ci, v, hz, t, k)
	_fish_shadows(ci, v, hz, t, k)


func _band(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	Art.grad(ci, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), PackedColorArray([c0, c0, c1, c1]))


func _sky(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	_band(ci, 0, v.x, 0, hz * 0.55, sky(0), sky(1))
	_band(ci, 0, v.x, hz * 0.55, hz + 2.0, sky(1), sky(2))
	match world:
		OCEAN:
			Art.push(ci, Vector2(v.x * 0.82, hz * 0.42), 0.0, Vector2.ONE * k)
			Props.sun(ci, t)
			Art.pop(ci)
			_clouds_draw(ci, v, hz, t, k, Art.WHITE, Color("7fb8e0"))
			Art.push(ci, Vector2(v.x * 0.3, hz + 2.0), 0.0, Vector2(1.6, 1.3) * k)
			Props.far_island(ci, 260.0, Color("7fb0d8"))
			Art.pop(ci)
			Art.push(ci, Vector2(v.x * 0.72, hz + 2.0), 0.0, Vector2(1.0, 0.8) * k)
			Props.far_island(ci, 200.0, Color("8fc0e4"))
			Art.pop(ci)
		VOLCANO:
			# A hazy hot sun, smoke clouds and two volcanoes on the horizon.
			var sp := Vector2(v.x * 0.8, hz * 0.4)
			_glow(ci, sp, 110.0 * k, Color(1.0, 0.85, 0.45, 0.35))
			Art.t_circle(ci, sp, 34.0 * k, Color("ffd27a"), 3.0, 0.3)
			_clouds_draw(ci, v, hz, t, k, Color("8a6a72"), Color("5a3a48"))
			_volcano_far(ci, Vector2(v.x * 0.24, hz + 2.0), 1.25 * k, t, 0.0)
			_volcano_far(ci, Vector2(v.x * 0.7, hz + 2.0), 0.8 * k, t, 1.7)
		ACID:
			var sp := Vector2(v.x * 0.8, hz * 0.42)
			_glow(ci, sp, 100.0 * k, Color(0.95, 1.0, 0.6, 0.35))
			Art.t_circle(ci, sp, 32.0 * k, Color("f4ffb0"), 3.0, 0.3)
			_clouds_draw(ci, v, hz, t, k, Color("eef8e0"), Color("8ab89a"))
			_swamp_far(ci, v, hz, k)
		MOON:
			for s in _stars:
				var p := Vector2(s.x * v.x, s.y * hz * 0.95)
				var tw := 0.55 + 0.45 * sin(t * (1.0 + s.z) + s.x * 40.0)
				Art.push(ci, p, 0.0, Vector2.ONE * snappedf(s.z * (0.6 + 0.4 * tw), 0.1) * k)
				Art.flat(ci, Art.star_pts(Vector2.ZERO, 4.0, 1.3, 4), Color(1, 1, 0.92, 0.9))
				Art.pop(ci)
			_earth(ci, Vector2(v.x * 0.8, hz * 0.38), 30.0 * k, t)
			_crater_far(ci, v, hz, k)


func _clouds_draw(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float, fill: Color, line: Color) -> void:
	for c in _clouds:
		var x := fposmod(c.x + t * 0.006 * c.z, 1.2) * (v.x + 200.0) - 150.0
		Art.push(ci, Vector2(x, hz * c.y), 0.0, Vector2.ONE * c.z * k)
		Props.cloud(ci, int(c.z * 100.0), fill, line)
		Art.pop(ci)


func _glow(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var n := 20
	var clear := Color(color, 0.0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]), PackedColorArray([color, clear, clear]))


func _volcano_far(ci: CanvasItem, base: Vector2, s: float, t: float, phase: float) -> void:
	Art.push(ci, base, 0.0, Vector2.ONE * s)
	var far := col("far", Color("8a5a66"))
	var cone := Art.smooth_pts(PackedVector2Array([Vector2(-150, 2), Vector2(-60, -60), Vector2(-24, -96), Vector2(24, -96), Vector2(60, -60), Vector2(150, 2)]), 3)
	Art.flat(ci, cone, far)
	# Lava running down from the crater.
	Art.flat(ci, PackedVector2Array([Vector2(-22, -96), Vector2(22, -96), Vector2(12, -88), Vector2(4, -60), Vector2(-2, -84), Vector2(-14, -70), Vector2(-12, -90)]), Color("ff8a2a"))
	Art.flat(ci, PackedVector2Array([Vector2(-20, -97), Vector2(20, -97), Vector2(14, -93), Vector2(-14, -93)]), Color("ffd23f"))
	# Smoke puffs.
	for i in 4:
		var f := fposmod(t * 0.12 + i / 4.0 + phase, 1.0)
		var p := Vector2(sin(f * 3.0 + phase) * 14.0 + f * 40.0, -100.0 - f * 120.0)
		Art.push(ci, p, 0.0, Vector2.ONE * snappedf(0.5 + f * 0.9, 0.05))
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, 20.0, 16), Color(0.35, 0.25, 0.3, snappedf(0.5 * (1.0 - f), 0.05)))
		Art.pop(ci)
	Art.pop(ci)


func _swamp_far(ci: CanvasItem, v: Vector2, hz: float, k: float) -> void:
	var far := col("far", Color("6a9a82"))
	# A low treeline with droopy willows and giant mushrooms.
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, hz + 2), Vector2(-20, hz - 22 * k), Vector2(v.x * 0.2, hz - 30 * k), Vector2(v.x * 0.45, hz - 18 * k),
			Vector2(v.x * 0.7, hz - 28 * k), Vector2(v.x + 20, hz - 16 * k), Vector2(v.x + 20, hz + 2)]), 3), far.lightened(0.15))
	for i in 3:
		var x := v.x * (0.12 + i * 0.36)
		Art.push(ci, Vector2(x, hz + 2), 0.0, Vector2.ONE * k * (1.0 - i * 0.15))
		Art.flat(ci, PackedVector2Array([Vector2(-5, 0), Vector2(-3, -60), Vector2(3, -60), Vector2(5, 0)]), far)
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-40, -48), Vector2(-30, -78), Vector2(0, -88), Vector2(30, -78), Vector2(40, -48), Vector2(28, -38), Vector2(18, -50), Vector2(0, -44), Vector2(-18, -50), Vector2(-28, -38)]), 3), far)
		Art.pop(ci)
	for i in 2:
		var x := v.x * (0.32 + i * 0.4)
		Art.push(ci, Vector2(x, hz + 2), 0.0, Vector2.ONE * k * 0.9)
		Art.flat(ci, PackedVector2Array([Vector2(-6, 0), Vector2(-5, -34), Vector2(5, -34), Vector2(6, 0)]), far.darkened(0.1))
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-30, -30), Vector2(-20, -50), Vector2(0, -56), Vector2(20, -50), Vector2(30, -30)]), 3), far.darkened(0.1))
		Art.pop(ci)


func _earth(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	_glow(ci, c, r * 2.6, Color(0.5, 0.75, 1.0, 0.3))
	Art.t_circle(ci, c, r, Color("3a8af0"), 3.0, 0.4)
	Art.push(ci, c, 0.0, Vector2.ONE * (r / 30.0))
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-18, -14), Vector2(-4, -20), Vector2(4, -8), Vector2(-6, 2), Vector2(-16, -2)]), 2), Color("5cd05f"))
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(6, 6), Vector2(18, 2), Vector2(20, 14), Vector2(8, 20)]), 2), Color("5cd05f"))
	Art.flat(ci, Art.rrect_pts(Rect2(-22, -4 + sin(t * 0.3) * 2.0, 24, 5), 2.5), Color(1, 1, 1, 0.7))
	Art.pop(ci)


func _crater_far(ci: CanvasItem, v: Vector2, hz: float, k: float) -> void:
	var far := col("far", Color("5a6288"))
	var rim := col("sand", Color("c4c8d6"))
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, hz + 2), Vector2(-20, hz - 20 * k), Vector2(v.x * 0.15, hz - 34 * k), Vector2(v.x * 0.35, hz - 14 * k),
			Vector2(v.x * 0.62, hz - 38 * k), Vector2(v.x * 0.85, hz - 18 * k), Vector2(v.x + 20, hz - 26 * k), Vector2(v.x + 20, hz + 2)]), 3), far)
	# The far crater wall catches light at its top.
	Art.flat(ci, PackedVector2Array([Vector2(-20, hz - 4 * k), Vector2(v.x + 20, hz - 4 * k), Vector2(v.x + 20, hz + 3), Vector2(-20, hz + 3)]), rim.darkened(0.25))
	for i in 3:
		Art.push(ci, Vector2(v.x * (0.2 + i * 0.3), hz - 22 * k + i * 5.0), 0.0, Vector2(1.0, 0.35) * k)
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, 16.0 - i * 3.0, 16), far.darkened(0.2))
		Art.pop(ci)


# Ocean ------------------------------------------------------------------------------

func _ocean(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var mid := lerpf(hz, v.y, 0.45)
	_band(ci, 0, v.x, hz, mid, sea(0), sea(1))
	_band(ci, 0, v.x, mid, v.y, sea(1), sea(2))
	Art.flat(ci, PackedVector2Array([Vector2(0, hz - 2), Vector2(v.x, hz - 2), Vector2(v.x, hz + 4), Vector2(0, hz + 4)]), Color(1, 1, 1, 0.5))
	for i in 14:
		var gx := v.x * 0.82 + sin(i * 2.3) * 70.0 * (1.0 + i * 0.08)
		var gy := hz + 14.0 + i * 16.0
		var a := 0.25 + 0.25 * sin(t * 3.0 + i * 1.7)
		Art.flat(ci, PackedVector2Array([Vector2(gx - 16, gy), Vector2(gx, gy - 2.5), Vector2(gx + 16, gy), Vector2(gx, gy + 2.5)]), Color(1, 1, 0.9, snappedf(a, 0.05)))
	_waves(ci, v, hz, t, k, Color(1, 1, 1, 1), 0.18)


func _waves(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float, c: Color, alpha: float) -> void:
	for row in 7:
		var y := lerpf(hz + 30.0, v.y - 40.0, row / 6.0)
		var amp := (4.0 + row * 1.2) * k
		var len := (60.0 + row * 14.0) * k
		for j in 5:
			var x0 := fposmod(j * v.x / 4.0 + row * 97.0 + t * (12.0 + row * 3.0), v.x + len * 2.0) - len
			var pts := PackedVector2Array()
			for s in 7:
				var f := s / 6.0
				pts.append(Vector2(x0 + f * len, y - sin(f * PI) * amp))
			Art.polyline(ci, pts, Color(c, alpha + 0.03 * (6 - row)), 3.0)


# Volcano: thick glowing magma under a cooling crust ----------------------------------

func _magma(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var a := lerpf(hz, v.y, 0.35)
	_band(ci, 0, v.x, hz, a, Color("ffd23f"), sea(1))
	_band(ci, 0, v.x, a, v.y, sea(1), sea(2))
	# The glow line on the horizon.
	Art.flat(ci, PackedVector2Array([Vector2(0, hz - 3), Vector2(v.x, hz - 3), Vector2(v.x, hz + 5), Vector2(0, hz + 5)]), Color(1.0, 0.95, 0.6, 0.85))
	# A cooling crust in plates; the hot magma glows in the cracks between.
	var crust := Color("4a1c1e")
	var rim := Color("ffd23f")
	for p in _plates:
		var row: int = p["row"]
		var f := (row + 0.5) / 8.0
		var y := lerpf(hz + 10.0, v.y + 20.0, pow(f, 1.2))
		var scale := lerpf(0.3, 1.25, f) * k * float(p["w"])
		var span := v.x + 260.0 * scale
		var x := fposmod(float(p["x"]) * span + t * 4.0 * float(p["sp"]) * (0.4 + f), span) - 130.0 * scale
		Art.push(ci, Vector2(x, y), 0.0, Vector2(scale, scale * 0.55))
		var shape := _plate_shape(int(p["seed"]))
		Art.push(ci, Vector2(0, -3), 0.0, Vector2.ONE * 1.08)
		Art.flat(ci, shape, Color(rim, 0.7))
		Art.pop(ci)
		var c := crust.lerp(sea(2), 0.35 * (1.0 - f))
		Art.flat(ci, shape, c)
		Art.flat(ci, Art.clipped(Art.moved(shape, Vector2(0, -22)), shape), c.lightened(0.12))
		Art.pop(ci)
	# Glowing ribbons of fresh lava.
	for row in 5:
		var y := lerpf(hz + 26.0, v.y - 30.0, row / 4.0)
		var len := (70.0 + row * 20.0) * k
		for j in 3:
			var x0 := fposmod(j * v.x / 2.6 + row * 131.0 + t * (6.0 + row * 2.0), v.x + len * 2.0) - len
			var pts := PackedVector2Array()
			for s in 7:
				var q := s / 6.0
				pts.append(Vector2(x0 + q * len, y - sin(q * PI) * (3.0 + row) * k))
			Art.polyline(ci, pts, Color(1.0, 0.92, 0.5, 0.35), (3.0 + row * 0.6) * k)
	# Bubbles that swell and pop.
	for b in _bubbles:
		var ph := fposmod(t * 0.35 + b.z, 1.0)
		var p := Vector2(b.x * v.x, lerpf(hz + 30.0, v.y - 60.0, b.y))
		var sc := lerpf(0.4, 1.3, b.y) * k
		if ph < 0.7:
			var r := snappedf(ph / 0.7, 0.05) * 14.0 * sc
			if r > 1.0:
				Art.push(ci, p, 0.0, Vector2(1.0, 0.75))
				Art.t_circle(ci, Vector2(0, -r * 0.4), r, Color("ffb43a"), 2.0, 0.4)
				Art.disc(ci, Vector2(-r * 0.35, -r * 0.8), r * 0.25, Color(1, 1, 0.8, 0.8))
				Art.pop(ci)
		else:
			var q := (ph - 0.7) / 0.3
			Art.push(ci, p, 0.0, Vector2(1.0, 0.35))
			Art.arc(ci, Vector2.ZERO, (14.0 + q * 24.0) * sc, 0.0, TAU, 18, Color(1.0, 0.9, 0.5, snappedf(0.8 * (1.0 - q), 0.05)), 3.0)
			Art.pop(ci)


func _plate_shape(seed: int) -> PackedVector2Array:
	if _plate_cache.has(seed):
		return _plate_cache[seed]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array()
	var n := 9
	for i in n:
		var a := TAU * i / n
		var r := rng.randf_range(0.7, 1.0)
		pts.append(Vector2(cos(a) * 110.0 * r, sin(a) * 60.0 * r))
	var out := Art.smooth_pts(pts, 2)
	_plate_cache[seed] = out
	return out


var _plate_cache := {}


# Acid swamp ---------------------------------------------------------------------------

func _swamp(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var mid := lerpf(hz, v.y, 0.45)
	_band(ci, 0, v.x, hz, mid, sea(0), sea(1))
	_band(ci, 0, v.x, mid, v.y, sea(1), sea(2))
	Art.flat(ci, PackedVector2Array([Vector2(0, hz - 2), Vector2(v.x, hz - 2), Vector2(v.x, hz + 4), Vector2(0, hz + 4)]), Color(0.95, 1.0, 0.7, 0.6))
	_waves(ci, v, hz, t * 0.6, k, Color(0.9, 1.0, 0.65), 0.16)
	# Lily pads drifting.
	for p in _pads:
		var y := lerpf(hz + 30.0, v.y - 80.0, p.y)
		var sc := lerpf(0.45, 1.2, p.y) * k * p.z
		var x := fposmod(p.x * (v.x + 200.0) + t * 4.0 * p.z, v.x + 200.0) - 100.0
		Art.push(ci, Vector2(x, y + sin(t * 1.3 + p.x * 9.0) * 2.0), 0.0, Vector2(sc, sc * 0.45))
		var pad := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(34, -18), Vector2(40, 8), Vector2(18, 34), Vector2(-20, 34), Vector2(-40, 8), Vector2(-34, -18), Vector2(-6, -36), Vector2(6, -36)]), 2)
		Art.toon(ci, pad, Color("4caa3a"), 3.0, 0.4)
		Art.line(ci, Vector2(0, 0), Vector2(-14, 20), Color("2f7a2a"), 2.0)
		Art.line(ci, Vector2(0, 0), Vector2(16, 18), Color("2f7a2a"), 2.0)
		if int(p.x * 10.0) % 2 == 0:
			Art.push(ci, Vector2(8, 4), 0.0, Vector2(1.0, 2.2))
			for i in 5:
				var a := TAU * i / 5.0
				Art.toon(ci, Art.ellipse_pts(Vector2(cos(a), sin(a)) * 6.0, Vector2(6, 3.6), 10, a), Color("ff9fd0"), 1.6, 0.0)
			Art.disc(ci, Vector2.ZERO, 3.4, Color("ffe066"))
			Art.pop(ci)
		Art.pop(ci)
	# Bubbles rising and popping.
	for b in _bubbles:
		var ph := fposmod(t * 0.5 + b.z, 1.0)
		var p := Vector2(b.x * v.x, lerpf(hz + 30.0, v.y - 60.0, b.y))
		var sc := lerpf(0.4, 1.2, b.y) * k
		if ph < 0.75:
			var r := snappedf(ph / 0.75, 0.1) * 9.0 * sc
			if r > 1.0:
				Art.t_circle(ci, p + Vector2(0, -r * 0.5), r, Color(0.8, 1.0, 0.55, 0.85), 1.8, 0.0)
				Art.disc(ci, p + Vector2(-r * 0.3, -r * 0.9), r * 0.28, Color(1, 1, 1, 0.8))
		else:
			var q := (ph - 0.75) / 0.25
			Art.push(ci, p, 0.0, Vector2(1.0, 0.35))
			Art.arc(ci, Vector2.ZERO, (9.0 + q * 18.0) * sc, 0.0, TAU, 16, Color(0.9, 1.0, 0.7, snappedf(0.8 * (1.0 - q), 0.05)), 2.5)
			Art.pop(ci)


# Moon: a crater full of starry space goo -----------------------------------------------

func _crater(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var mid := lerpf(hz, v.y, 0.45)
	var top := Color("4a3a9a")
	var deep := Color("1a1240")
	_band(ci, 0, v.x, hz, mid, top, Color("2a2070"))
	_band(ci, 0, v.x, mid, v.y, Color("2a2070"), deep)
	# Nebula clouds glowing in the goo.
	_glow(ci, Vector2(v.x * 0.3, lerpf(hz, v.y, 0.4)), 180.0 * k, Color(0.9, 0.4, 1.0, 0.22))
	_glow(ci, Vector2(v.x * 0.8, lerpf(hz, v.y, 0.7)), 220.0 * k, Color(0.3, 0.9, 1.0, 0.18))
	Art.flat(ci, PackedVector2Array([Vector2(0, hz - 2), Vector2(v.x, hz - 2), Vector2(v.x, hz + 4), Vector2(0, hz + 4)]), Color(0.8, 0.75, 1.0, 0.6))
	# Stars in the goo, twinkling.
	for i in 40:
		var s := _stars[i]
		var p := Vector2(s.x * v.x, lerpf(hz + 16.0, v.y, s.y))
		var tw := 0.5 + 0.5 * sin(t * (1.4 + s.z) + s.y * 30.0)
		Art.push(ci, p, 0.0, Vector2.ONE * snappedf(s.z * (0.4 + 0.6 * tw), 0.1) * k)
		Art.flat(ci, Art.star_pts(Vector2.ZERO, 4.0, 1.2, 4), Color(1, 1, 1, 0.75))
		Art.pop(ci)
	_waves(ci, v, hz, t * 0.5, k, Color(0.8, 0.75, 1.0), 0.14)


# Fish passing by -------------------------------------------------------------------------

func _fish_shadows(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	for sh in _shadows:
		var dir := 1.0 if sh.x < 0.5 else -1.0
		var f := fposmod(sh.x * 7.0 + t * 0.025 * sh.z, 1.0)
		var x := lerpf(-80.0, v.x + 80.0, f) if dir > 0.0 else lerpf(v.x + 80.0, -80.0, f)
		var y := lerpf(hz + 80.0, v.y - 160.0, sh.y) + sin(t + sh.x * 10.0) * 8.0
		shadow(ci, Vector2(x, y), 34.0 * sh.z * k, dir, 0.16, t)


## A fish shape under the surface (fire fish in magma, glowing in space).
func shadow(ci: CanvasItem, p: Vector2, len: float, dir: float, alpha: float, t: float) -> void:
	Art.push(ci, p, 0.0, Vector2(dir, 1.0) * (len / 30.0))
	var c := shadow_color(alpha)
	if world == VOLCANO:
		Art.flat(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(36, 16), 18), Color(1.0, 0.95, 0.5, alpha * 1.2))
	Art.flat(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(30, 11), 18), c)
	Art.push(ci, Vector2(-28, 0), sin(t * 6.0 + p.y) * 0.25)
	Art.flat(ci, PackedVector2Array([Vector2(2, 0), Vector2(-14, -10), Vector2(-14, 10)]), c)
	Art.pop(ci)
	Art.pop(ci)


# --- What you stand on ----------------------------------------------------------------

## deck: the walkable top edge (position.y is where feet stand).
func ledge(ci: CanvasItem, d: Rect2, v: Vector2, t: float, k: float) -> void:
	match world:
		OCEAN:
			_pier(ci, d, v, t, k, Art.WOOD, Art.WOOD_DARK, false)
		VOLCANO:
			_basalt(ci, d, v, t, k)
		ACID:
			_pier(ci, d, v, t, k, Color("8a6a44"), Color("5c4430"), true)
		MOON:
			_moon_rock(ci, d, v, t, k)


func _pier(ci: CanvasItem, d: Rect2, v: Vector2, t: float, k: float, wood: Color, dark: Color, mossy: bool) -> void:
	var post_h := minf(170.0 * k, v.y - d.position.y)
	var n := maxi(3, int(d.size.x / (120.0 * k)))
	var water := sea(1)
	for i in n:
		var x := d.position.x + 40.0 + (d.size.x - 70.0) * i / float(n - 1)
		var r := Rect2(x - 12.0 * k, d.position.y + 10.0, 24.0 * k, post_h)
		Art.t_rect(ci, r, 6.0, dark, 3.0, 0.3)
		var wy := d.position.y + post_h * 0.55
		Art.push(ci, Vector2(x, wy), 0.0, Vector2(1.0, 0.3))
		Art.arc(ci, Vector2.ZERO, (26.0 + 5.0 * sin(t * 2.0 + i)) * k, 0.0, TAU, 20, Color(ring_color(), 0.45), 4.0)
		Art.pop(ci)
		Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, wy - 4.0, r.size.x, r.end.y - wy + 4.0), 4.0), Color(water, 0.5))
		if mossy:
			Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, wy - 18.0 * k, r.size.x, 14.0 * k), 5.0), Color("4caa3a", 0.85))
			if i % 2 == 1:
				Art.push(ci, Vector2(x + 10.0 * k, d.position.y + 34.0 * k), 0.3, Vector2.ONE * k)
				_mushroom(ci, Color("ff8a4c"), 1.0)
				Art.pop(ci)
	var face := Rect2(d.position.x, d.position.y, d.size.x, d.size.y + 12.0 * k)
	Art.t_rect(ci, face, 8.0, dark, 3.5, 0.0)
	Art.t_rect(ci, Rect2(d.position.x, d.position.y - 14.0 * k, d.size.x, d.size.y), 8.0, wood, 3.5, 0.5)
	var plank := 46.0 * k
	var x := d.position.x + plank
	while x < d.end.x - 10.0:
		Art.line(ci, Vector2(x, d.position.y - 12.0 * k), Vector2(x, d.position.y + d.size.y - 16.0 * k), dark, 2.0)
		x += plank
	for i in int(d.size.x / (plank * 2.0)):
		Art.flat(ci, Art.circle_pts(Vector2(d.position.x + plank * (2.0 * i + 1.5), d.position.y + d.size.y * 0.5 + 2.0), 2.5 * k, 8), Art.INK_SOFT)
	if mossy:
		# Moss on the planks, slime dripping off the edge, reeds.
		for i in 4:
			var mx := d.position.x + d.size.x * (0.15 + i * 0.24)
			Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(mx - 22 * k, d.position.y - 14 * k), Vector2(mx + 18 * k, d.position.y - 14 * k), Vector2(mx + 12 * k, d.position.y - 8 * k), Vector2(mx - 16 * k, d.position.y - 7 * k)]), 2), Color("6cc24a", 0.9))
			var drip := fposmod(t * 0.4 + i * 0.3, 1.0)
			Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(mx - 5 * k, d.end.y), Vector2(mx + 5 * k, d.end.y), Vector2(mx + 2 * k, d.end.y + (6.0 + drip * 10.0) * k), Vector2(mx - 2 * k, d.end.y + (6.0 + drip * 10.0) * k)]), 2), Color("9be03a", 0.9))
		_reeds(ci, Vector2(d.end.x + 30.0 * k, d.position.y + 70.0 * k), k, t)


func _mushroom(ci: CanvasItem, cap: Color, s: float) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2.ONE * s)
	Art.t_rect(ci, Rect2(-4, -2, 8, 12), 3.0, Art.CREAM, 2.0, 0.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-12, 0), Vector2(-9, -9), Vector2(0, -13), Vector2(9, -9), Vector2(12, 0)]), 2), cap, 2.4, 0.3)
	Art.disc(ci, Vector2(-4, -6), 2.0, Art.WHITE)
	Art.disc(ci, Vector2(4, -8), 1.6, Art.WHITE)
	Art.pop(ci)


func _reeds(ci: CanvasItem, at: Vector2, k: float, t: float) -> void:
	for i in 4:
		var sway := sin(t * 1.2 + i) * 0.06
		Art.push(ci, at + Vector2(i * 12.0 * k, 0), sway, Vector2.ONE * k)
		var h := 70.0 + i * 12.0
		Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(2, -h * 0.5), Vector2(0, -h)]), Color("4caa3a"), 3.5, 2.0)
		if i % 2 == 0:
			Art.t_rect(ci, Rect2(-4, -h - 18, 8, 22), 4.0, Color("7a4a2a"), 2.2, 0.3)
		Art.pop(ci)


func _basalt(ci: CanvasItem, d: Rect2, v: Vector2, t: float, k: float) -> void:
	var top := col("sand", Color("5c5262"))
	var dark := col("sand_dark", Color("433a4c"))
	var bottom := v.y + 20.0
	var x0 := d.position.x
	var x1 := d.end.x
	# Glow of the magma on the cliff foot.
	_band(ci, x0, x1 + 30.0 * k, bottom - 120.0 * k, bottom, Color(1.0, 0.5, 0.1, 0.0), Color(1.0, 0.55, 0.1, 0.45))
	# The face: hexagonal basalt columns.
	var cw := 38.0 * k
	var i := 0
	var x := x0
	while x < x1 + cw * 0.5:
		var h_off: float = [0.0, 10.0, 4.0, 14.0][i % 4] * k
		var col_r := Rect2(x, d.position.y - 4.0 * k + h_off, cw, bottom - d.position.y)
		Art.t_rect(ci, col_r, 5.0, dark if i % 2 == 0 else dark.lightened(0.06), 3.0, 0.4)
		Art.line(ci, Vector2(x + cw * 0.5, col_r.position.y + 8.0 * k), Vector2(x + cw * 0.5, bottom), Color(Art.INK, 0.25), 2.0)
		i += 1
		x += cw
	# Top slab.
	var slab := Art.smooth_pts(PackedVector2Array([Vector2(x0, d.position.y - 16.0 * k), Vector2(x1 - 10.0 * k, d.position.y - 18.0 * k), Vector2(x1 + 12.0 * k, d.position.y - 4.0 * k),
			Vector2(x1, d.position.y + 14.0 * k), Vector2(x0, d.position.y + 14.0 * k)]), 2)
	Art.toon(ci, slab, top, 3.5, 0.5)
	for j in 3:
		var cx := x0 + (x1 - x0) * (0.25 + j * 0.28)
		Art.line(ci, Vector2(cx, d.position.y - 12.0 * k), Vector2(cx + 8.0 * k, d.position.y + 8.0 * k), Color(Art.INK, 0.3), 2.0)
	# Glowing cracks.
	var g := Color(1.0, 0.6, 0.15, snappedf(0.6 + 0.3 * sin(t * 2.0), 0.05))
	for c in [Vector2(x0 + 0.5 * cw, 50.0), Vector2(x0 + 3.5 * cw, 90.0)]:
		var p0 := Vector2(c.x, d.position.y + c.y * k)
		Art.polyline(ci, PackedVector2Array([p0, p0 + Vector2(5, 14) * k, p0 + Vector2(-3, 26) * k, p0 + Vector2(4, 40) * k, p0 + Vector2(-2, 54) * k]), g, 3.0 * k)
	# Magma lapping at the foot.
	var lap := PackedVector2Array()
	for s in 9:
		var q := s / 8.0
		lap.append(Vector2(lerpf(x0 - 10.0, x1 + 40.0 * k, q), bottom - 36.0 * k + sin(t * 2.0 + q * 9.0) * 4.0 * k))
	lap.append(Vector2(x1 + 40.0 * k, bottom))
	lap.append(Vector2(x0 - 10.0, bottom))
	Art.flat_now(ci, lap, sea(1))


func _moon_rock(ci: CanvasItem, d: Rect2, v: Vector2, t: float, k: float) -> void:
	var top := col("sand", Color("c4c8d6"))
	var dark := col("sand_dark", Color("989db2"))
	var bottom := v.y + 20.0
	var x0 := d.position.x
	var x1 := d.end.x
	var wall := Art.smooth_pts(PackedVector2Array([Vector2(x0, d.position.y), Vector2(x1, d.position.y), Vector2(x1 + 26.0 * k, d.position.y + 60.0 * k),
			Vector2(x1 + 10.0 * k, bottom), Vector2(x0, bottom)]), 2)
	Art.toon(ci, wall, dark, 3.5, 0.4)
	var slab := Art.smooth_pts(PackedVector2Array([Vector2(x0, d.position.y - 16.0 * k), Vector2(x1 - 20.0 * k, d.position.y - 20.0 * k), Vector2(x1 + 8.0 * k, d.position.y - 6.0 * k),
			Vector2(x1 + 4.0 * k, d.position.y + 14.0 * k), Vector2(x0, d.position.y + 14.0 * k)]), 2)
	Art.toon(ci, slab, top, 3.5, 0.5)
	# Little craters.
	for c in [Vector3(0.2, 0.0, 9.0), Vector3(0.55, 0.0, 6.0), Vector3(0.8, 0.0, 8.0)]:
		Art.push(ci, Vector2(x0 + (x1 - x0) * c.x, d.position.y - 4.0 * k), 0.0, Vector2(1.0, 0.4) * k)
		Art.t_circle(ci, Vector2.ZERO, c.z, dark, 2.0, 0.0)
		Art.pop(ci)
	for c in [Vector3(0.3, 60.0, 14.0), Vector3(0.7, 110.0, 10.0), Vector3(0.45, 170.0, 12.0)]:
		Art.push(ci, Vector2(x0 + (x1 - x0) * c.x, d.position.y + c.y * k), 0.0, Vector2.ONE * k)
		Art.t_circle(ci, Vector2.ZERO, c.z, dark.darkened(0.12), 2.5, 0.0)
		Art.arc(ci, Vector2.ZERO, c.z, PI * 0.1, PI * 0.9, 8, Color(1, 1, 1, 0.35), 2.0)
		Art.pop(ci)
	# Glow of the space goo at the foot.
	_band(ci, x0, x1 + 30.0 * k, bottom - 80.0 * k, bottom, Color(0.6, 0.5, 1.0, 0.0), Color(0.6, 0.5, 1.0, 0.35))


# --- The fisherman's raft ---------------------------------------------------------------

## His boat (ocean), a basalt raft (volcano), a lily pad (acid), a hover disc
## (moon); origin at the waterline, in the screen's scale k.
func raft(ci: CanvasItem, base: Vector2, rock: float, t: float, k: float) -> void:
	Art.push(ci, base, rock, Vector2.ONE * k)
	match world:
		OCEAN:
			var hull := Art.smooth_pts(PackedVector2Array([Vector2(-92, -34), Vector2(-40, -26), Vector2(40, -26), Vector2(96, -38), Vector2(70, 8), Vector2(-66, 8)]), 3)
			Art.toon(ci, hull, Color("e8744a"), 3.5, 0.6)
			Art.t_rect(ci, Rect2(-88, -36, 180, 11), 5.0, Art.WOOD, 3.0, 0.3)
			Art.flat(ci, Art.rrect_pts(Rect2(-60, -12, 118, 6), 3.0), Color(1, 1, 1, 0.35))
		VOLCANO:
			var slab := Art.smooth_pts(PackedVector2Array([Vector2(-90, -30), Vector2(-30, -36), Vector2(50, -32), Vector2(92, -24), Vector2(80, 8), Vector2(-80, 8)]), 2)
			Art.toon(ci, slab, Color("4a4250"), 3.5, 0.5)
			Art.polyline(ci, PackedVector2Array([Vector2(-70, 4), Vector2(-20, -2), Vector2(40, 2), Vector2(76, -2)]), Color(1.0, 0.6, 0.15, 0.8), 3.0)
			Art.line(ci, Vector2(-20, -30), Vector2(-10, -8), Color(Art.INK, 0.3), 2.0)
		ACID:
			var pad := Art.smooth_pts(PackedVector2Array([Vector2(0, -30), Vector2(80, -36), Vector2(104, -18), Vector2(80, 4), Vector2(-80, 4), Vector2(-104, -18), Vector2(-80, -36), Vector2(-10, -40)]), 2)
			Art.toon(ci, pad, Color("4caa3a"), 3.5, 0.5)
			Art.line(ci, Vector2(0, -30), Vector2(-60, -6), Color("2f7a2a"), 2.5)
			Art.line(ci, Vector2(0, -30), Vector2(60, -8), Color("2f7a2a"), 2.5)
		MOON:
			var g := snappedf(0.35 + 0.15 * sin(t * 3.0), 0.05)
			_glow(ci, Vector2(0, 14), 70.0, Color(0.5, 0.9, 1.0, g))
			Art.t_ellipse(ci, Vector2(0, -16), Vector2(98, 20), Color("aab4cc"), 3.5, 0.5)
			Art.t_ellipse(ci, Vector2(0, -22), Vector2(80, 10), Color("dfe6f5"), 2.5, 0.0)
			for i in 5:
				Art.disc(ci, Vector2(-60 + i * 30, -8), 4.0, Color("7ff0ff") if int(t * 3.0) % 5 != i else Art.WHITE)
	Art.pop(ci)
