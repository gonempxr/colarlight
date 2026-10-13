class_name JungleBoard
extends RefCounted
## The Jungle Ruins puzzle board's scenery (PuzzleScreen, world 4):
##   still()   - drawn once per layout: the sky through the canopy, a stepped
##               pyramid and broken temple columns in the haze, tree trunks,
##               hanging vines and the big leaves of the canopy;
##   ambient() - every background frame: sun rays breathing, pollen motes,
##               leaves drifting down and butterflies (only a few shapes,
##               all moved with push/pop, so it stays cheap);
##   ground(), side_prop(), frame_deco() - the mossy temple floor, the
##               big decorations beside the board on wide screens and the
##               carved stone frame with vines and flowers.

const SKY_TOP := Color("d6f5a8")
const SKY_MID := Color("58c088")
const SKY_LOW := Color("1a5e46")
const HAZE := Color("5fb088")
const RUIN := Color("4f9a76")
const RUIN_DARK := Color("3a7e60")
const CANOPY := [Color("1f6a3a"), Color("2a8a45"), Color("3aa852")]
const LEAF := Color("3fbf4a")
const LEAF_DARK := Color("23863a")
const STONE := Color("d9bb7c")
const STONE_DARK := Color("a8844a")
const MOSS := Color("5cbf3a")
const FLOWERS := [Color("ff4a86"), Color("ffa21e"), Color("ffe03a"), Color("d45cf0")]


# --- Still scenery ------------------------------------------------------------------------

static func still(ci: CanvasItem, v: Vector2, board: Rect2) -> void:
	var lo := v.y * 0.62
	_grad(ci, Rect2(0, 0, v.x, lo), SKY_TOP, SKY_MID)
	_grad(ci, Rect2(0, lo, v.x, v.y - lo + 2.0), SKY_MID, SKY_LOW)
	# A big soft sun glow up behind the leaves.
	Art.glow(ci, Vector2(v.x * 0.62, v.y * 0.05), maxf(v.x, v.y) * 0.45, Color(1.0, 0.98, 0.75, 0.55), 24)
	# Far: a stepped pyramid in the haze, its top above the board.
	var k := clampf(minf(v.x, v.y) / 700.0, 0.6, 1.6)
	# On a phone only the strip over the board shows: the pyramid's top
	# must sit in it.
	var py := board.position.y - (110.0 if v.x < v.y else 40.0) * k
	var ptop := Vector2(v.x * 0.5, maxf(py, v.y * 0.17))
	# Pale far treetops behind it.
	_crowns(ci, v, ptop.y + 70.0 * k, k, HAZE.lightened(0.2))
	_pyramid(ci, ptop, k * 1.15, HAZE.darkened(0.22))
	_crowns(ci, v, ptop.y + 120.0 * k, k * 1.2, HAZE.darkened(0.05))
	if v.x > v.y:
		_pyramid(ci, Vector2(v.x * 0.16, v.y * 0.46), k * 0.75, HAZE)
		_pyramid(ci, Vector2(v.x * 0.86, v.y * 0.42), k * 0.85, HAZE.darkened(0.04))
	# A misty treeline between the far ruins and the near ones.
	var tl := PackedVector2Array([Vector2(-10, v.y)])
	var n := 14
	for i in n + 1:
		var x := v.x * i / float(n)
		tl.append(Vector2(x, v.y * 0.5 - 18.0 * k * (1.0 + sin(i * 2.7)) + (i % 2) * 14.0 * k))
	tl.append(Vector2(v.x + 10, v.y))
	Art.flat(ci, Art.smooth_pts(tl, 3), Color(RUIN, 0.55))
	# Near: broken temple columns and a stone arch on the sides.
	_column(ci, Vector2(v.x * 0.06, v.y * 0.95), 1.25 * k, 0.55, 0)
	_column(ci, Vector2(v.x * 0.95, v.y * 0.9), 1.1 * k, 0.8, 1)
	if v.x > v.y:
		_column(ci, Vector2(v.x * 0.22, v.y * 0.92), 0.95 * k, 0.4, 2)
		_column(ci, Vector2(v.x * 0.79, v.y * 0.94), 1.0 * k, 0.65, 3)
		_arch(ci, Vector2(v.x * 0.88, v.y * 0.62), k)
		_arch(ci, Vector2(v.x * 0.12, v.y * 0.66), k * 0.9)
	# Tree trunks at the edges with roots and lianas.
	_trunk(ci, Vector2(-8.0 * k, v.y), v.y, 46.0 * k, 1.0)
	_trunk(ci, Vector2(v.x + 8.0 * k, v.y), v.y, 52.0 * k, -1.0)
	# Hanging vines from the canopy.
	var vr := RandomNumberGenerator.new()
	vr.seed = 31
	var vines := 6 if v.x < v.y else 11
	for i in vines:
		var x := v.x * (0.04 + 0.92 * (i + vr.randf_range(0.0, 0.6)) / vines)
		var len := v.y * vr.randf_range(0.12, 0.3)
		_vine(ci, Vector2(x, 0), len, k, vr.randi() % 1000)
	# The canopy: three rows of big leaves across the top.
	_canopy(ci, v, maxf(k, 0.9))


## A row of round far treetops with their top around y.
static func _crowns(ci: CanvasItem, v: Vector2, y: float, k: float, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(y)
	Art.flat(ci, PackedVector2Array([Vector2(-20, y + 30.0 * k), Vector2(v.x + 20, y + 30.0 * k), Vector2(v.x + 20, v.y), Vector2(-20, v.y)]), col)
	var x := -20.0
	while x < v.x + 40.0:
		var r := rng.randf_range(22.0, 40.0) * k
		Art.flat(ci, Art.circle_pts(Vector2(x, y + r + rng.randf_range(-10.0, 16.0) * k), r, 18), col)
		x += r * 1.4


static func _grad(ci: CanvasItem, r: Rect2, a: Color, b: Color) -> void:
	Art.grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([a, a, b, b]))


## A stepped pyramid with a little temple on top; `top` is its top center.
static func _pyramid(ci: CanvasItem, top: Vector2, s: float, col: Color) -> void:
	Art.push(ci, top, 0.0, Vector2.ONE * s)
	var steps := 6
	for i in steps:
		var w := 46.0 + i * 30.0
		var y := 24.0 + i * 22.0
		Art.flat(ci, Art.rrect_pts(Rect2(-w / 2.0, y, w, 23.0), 2.0), col.darkened(0.03 * (i % 2)))
		Art.flat(ci, PackedVector2Array([Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Vector2(w / 2.0, y + 3.0), Vector2(-w / 2.0, y + 3.0)]), col.lightened(0.12))
	# The stairs up the middle.
	Art.flat(ci, PackedVector2Array([Vector2(-10, 24), Vector2(10, 24), Vector2(22, 24 + steps * 22.0), Vector2(-22, 24 + steps * 22.0)]), col.darkened(0.08))
	for i in steps * 3:
		var y := 26.0 + i * 7.3
		var hw := 10.0 + i * 0.68
		Art.line(ci, Vector2(-hw, y), Vector2(hw, y), col.lightened(0.08), 1.2)
	# The temple on top with a dark door.
	Art.flat(ci, Art.rrect_pts(Rect2(-18, 0, 36, 25), 2.0), col.lightened(0.05))
	Art.flat(ci, PackedVector2Array([Vector2(-22, 2), Vector2(22, 2), Vector2(16, -6), Vector2(-16, -6)]), col.lightened(0.1))
	Art.flat(ci, Art.rrect_pts(Rect2(-6, 9, 12, 16), 5.0), col.darkened(0.25))
	# Bushes growing on the steps.
	for p: Vector3 in [Vector3(-40, 70, 9.0), Vector3(52, 104, 11.0), Vector3(-66, 128, 10.0), Vector3(30, 50, 7.0)]:
		Art.flat(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 12), col.darkened(0.12))
		Art.flat(ci, Art.circle_pts(Vector2(p.x + p.z * 0.8, p.y + 2), p.z * 0.8, 10), col.darkened(0.12))
	Art.pop(ci)


## A broken carved column: `base` its bottom, `h` 0..1 how much is left.
static func _column(ci: CanvasItem, base: Vector2, s: float, h: float, seed: int) -> void:
	Art.push(ci, base, 0.0, Vector2.ONE * s)
	var height := 120.0 + 200.0 * h
	var w := 44.0
	var col := RUIN.lerp(STONE, 0.35)
	# Shaft with drums.
	var top := -height
	var broken := PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(-w / 2.0, top + 8), Vector2(-w * 0.2, top), Vector2(0, top + 10),
			Vector2(w * 0.25, top + 3), Vector2(w / 2.0, top + 14), Vector2(w / 2.0, 0)])
	Art.toon(ci, broken, col, 3.0, 0.5)
	var drum := 46.0
	var y := -drum
	while y > top + 16:
		Art.line(ci, Vector2(-w / 2.0 + 2, y), Vector2(w / 2.0 - 2, y), Art.shade_of(col, 0.3), 2.0)
		y -= drum
	for x: float in [-10.0, 0.0, 10.0]:
		Art.line(ci, Vector2(x, -6), Vector2(x, top + 18), Color(Art.shade_of(col, 0.25), 0.6), 1.6)
	# Base block.
	Art.toon(ci, Art.rrect_pts(Rect2(-w * 0.7, -18, w * 1.4, 22), 3.0), col.darkened(0.05), 3.0, 0.4)
	# Moss and a vine around it.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-6, top + 12), Vector2(20, 10), 16), broken), Color(MOSS, 0.9))
	var vine := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		vine.append(Vector2(sin(f * TAU * 1.5 + seed) * w * 0.55, -10.0 - f * (height - 30.0)))
	Art.stroke(ci, Art.smooth_pts(vine, 2), LEAF_DARK, 3.2, 1.6)
	for i in 4:
		var f := 0.15 + i * 0.22
		var p := vine[int(f * 8.0)]
		TileJungle.leaf(ci, p, -PI / 2.0 + (0.9 if i % 2 == 0 else -0.9) + PI * float(i % 2), 16.0, 5.5, LEAF if i % 2 == 0 else Color("5cd05a"), 2.0)
	Art.pop(ci)


## A stone arch half hidden in the leaves.
static func _arch(ci: CanvasItem, c: Vector2, s: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * s)
	var col := RUIN.lerp(STONE, 0.25)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		outer.append(Vector2(cos(a) * 70.0, sin(a) * 70.0))
		inner.append(Vector2(cos(a) * 46.0, sin(a) * 46.0))
	var shape := PackedVector2Array([Vector2(-70, 80)])
	shape.append_array(outer)
	shape.append(Vector2(70, 80))
	shape.append(Vector2(46, 80))
	inner.reverse()
	shape.append_array(inner)
	shape.append(Vector2(-46, 80))
	Art.toon(ci, shape, col, 3.0, 0.5)
	# Keystone and block seams.
	Art.toon(ci, PackedVector2Array([Vector2(-9, -72), Vector2(9, -72), Vector2(6, -46), Vector2(-6, -46)]), col.lightened(0.08), 2.4, 0.3)
	for i: int in [3, 5, 7, 9]:
		var a := PI + PI * i / 12.0
		Art.line(ci, Vector2(cos(a), sin(a)) * 47.0, Vector2(cos(a), sin(a)) * 69.0, Art.shade_of(col, 0.3), 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-30, -50), Vector2(26, 12), 16, -0.6), Color(MOSS, 0.85))
	Art.pop(ci)


static func _trunk(ci: CanvasItem, base: Vector2, h: float, w: float, side: float) -> void:
	var col := Color("6a4a2e")
	var pts := PackedVector2Array([Vector2(base.x - w * side * 0.2, base.y + 4), Vector2(base.x - w * side * 0.1, base.y - h * 0.3),
			Vector2(base.x + w * side * 0.25, base.y - h * 0.7), Vector2(base.x + w * side * 0.1, -10),
			Vector2(base.x + w * side * 1.0, -10), Vector2(base.x + w * side * 1.05, base.y - h * 0.65),
			Vector2(base.x + w * side * 0.95, base.y - h * 0.3), Vector2(base.x + w * side * 1.6, base.y + 4)])
	Art.toon(ci, Art.smooth_pts(pts, 3), col, 3.5, 0.5)
	# Bark lines and a liana.
	for i in 5:
		var y := base.y - h * (0.12 + i * 0.18)
		Art.line(ci, Vector2(base.x + w * side * 0.45, y), Vector2(base.x + w * side * 0.7, y - 22.0), col.darkened(0.25), 2.2)
	var liana := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		liana.append(Vector2(base.x + w * side * (0.7 + 0.5 * sin(f * 9.0)), base.y - h * f))
	Art.stroke(ci, Art.smooth_pts(liana, 2), LEAF_DARK, 3.0, 1.6)


## One hanging vine: a wavy strand with leaves and maybe a flower at the end.
static func _vine(ci: CanvasItem, top: Vector2, len: float, k: float, seed: int) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		pts.append(top + Vector2(sin(f * 7.0 + seed) * 10.0 * k * f, len * f))
	Art.stroke(ci, Art.smooth_pts(pts, 3), Color("2f7a2a"), 3.4 * maxf(k, 0.8), 1.8)
	for i in range(1, 7):
		var p := pts[i]
		var sd := 1.0 if (i + seed) % 2 == 0 else -1.0
		TileJungle.leaf(ci, p, PI / 2.0 - sd * 1.1, 18.0 * maxf(k, 0.8), 6.5 * maxf(k, 0.8), LEAF if i % 2 == 0 else Color("2fa04a"), 2.0)
	if seed % 3 == 0:
		flower(ci, pts[6] + Vector2(0, 6.0 * k), 0.42 * k, FLOWERS[seed % FLOWERS.size()])


static func flower(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	Art.push(ci, at, 0.4, Vector2.ONE * s)
	Art.toon(ci, TileJungle._flower_pts(10.0, 24.0, 0.8), col, 5.0, 0.4)
	Art.flat(ci, TileJungle._flower_pts(4.0, 9.0, 0.0), col.darkened(0.35))
	Art.flat(ci, Art.circle_pts(Vector2(6, -8), 3.5, 10), Color("ffe04a"))
	Art.pop(ci)


## Big leaves along the top edge, in three depths.
static func _canopy(ci: CanvasItem, v: Vector2, k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for row in 3:
		var n := int(v.x / (70.0 * k)) + 3
		var y := (row * 26.0 - 30.0) * k + (36.0 if v.x < v.y else 0.0)
		for i in n:
			var x := (i + rng.randf_range(-0.3, 0.3)) * v.x / float(n - 2) - 20.0
			var len := (80.0 + rng.randf_range(0.0, 50.0) - row * 10.0) * k
			var rot := PI / 2.0 + rng.randf_range(-0.9, 0.9)
			var col: Color = CANOPY[row]
			Art.push(ci, Vector2(x, y + rng.randf_range(-10.0, 30.0) * k), rot)
			if row == 2 and i % 3 == 1:
				monstera(ci, len * 0.9, col)
			else:
				Art.toon(ci, TileJungle.leaf_pts(len, len * 0.28), col, 3.0, 0.4)
				Art.line(ci, Vector2(len * 0.06, 0), Vector2(len * 0.85, 0), col.darkened(0.25), 2.4)
				for j in 3:
					var f := 0.25 + j * 0.2
					Art.line(ci, Vector2(len * f, 0), Vector2(len * (f + 0.12), -len * 0.15), col.darkened(0.2), 1.6)
					Art.line(ci, Vector2(len * f, 0), Vector2(len * (f + 0.12), len * 0.12), col.darkened(0.2), 1.6)
			Art.pop(ci)


## A split monstera leaf pointing along +x.
static func monstera(ci: CanvasItem, len: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 22
	for i in n + 1:
		var f := float(i) / n
		var r := sin(PI * f) * len * 0.42
		# Splits: every other step goes in a bit.
		var cut := 0.55 if (i % 4 == 2 and f > 0.15 and f < 0.85) else 1.0
		pts.append(Vector2(f * len, -r * cut))
	for i in range(n - 1, 0, -1):
		var f := float(i) / n
		var r := sin(PI * f) * len * 0.4
		var cut := 0.55 if (i % 4 == 0 and f > 0.15 and f < 0.85) else 1.0
		pts.append(Vector2(f * len, r * cut))
	Art.toon(ci, pts, col, 3.0, 0.45)
	Art.line(ci, Vector2(0, 0), Vector2(len * 0.9, 0), col.darkened(0.3), 2.6)


# --- Moving bits ------------------------------------------------------------------------------

## Sun rays, pollen, drifting leaves and butterflies. `seeds` are fixed
## random numbers per thing (Vector3 x, y, z in 0..1 / sizes).
static func ambient(ci: CanvasItem, v: Vector2, t: float, seeds: Array[Vector3], low: bool) -> void:
	# Soft sun rays slanting down through the canopy gaps.
	var rays := 4 if low else 6
	for i in rays:
		var x := v.x * (0.1 + i * 0.17) + sin(t * 0.25 + i * 1.7) * 18.0
		var w := (40.0 + (i % 3) * 26.0) * maxf(1.0, v.x / 900.0)
		var len := v.y * (0.8 + 0.12 * (i % 2))
		var a := snappedf(0.2 + 0.09 * sin(t * 0.7 + i * 1.3), 0.01)
		var ray := Color(1.0, 0.98, 0.7, a)
		var clear := Color(ray, 0.0)
		var drift := len * 0.32
		Art.grad(ci, PackedVector2Array([Vector2(x - w * 0.25, 0), Vector2(x + w * 0.25, 0), Vector2(x + w + drift, len), Vector2(x - w + drift, len)]),
				PackedColorArray([ray, ray, clear, clear]))
	# Pollen motes glinting in the light.
	var motes := 8 if low else 14
	for i in mini(motes, seeds.size()):
		var s: Vector3 = seeds[i]
		var y := fposmod(s.y + t * 0.012 * (0.5 + s.z * 0.1), 1.0)
		var x := s.x * v.x + sin(t * 0.8 + s.x * 30.0) * 16.0
		var tw := snappedf(0.35 + 0.55 * absf(sin(t * 1.6 + i)), 0.05)
		Art.glow(ci, Vector2(x, y * v.y), s.z * 1.6, Color(1.0, 1.0, 0.75, tw * 0.6), 10)
		Art.disc(ci, Vector2(x, y * v.y), snappedf(s.z * 0.35, 0.25), Color(1, 1, 0.9, tw))
	# Leaves drifting down, turning and swinging.
	var leaves := 4 if low else 7
	for i in leaves:
		var s: Vector3 = seeds[(i * 3 + 1) % seeds.size()]
		var f := fposmod(s.y + t * (0.025 + 0.01 * (i % 3)), 1.0)
		var y := f * (v.y + 80.0) - 40.0
		var x := s.x * v.x + sin(t * 1.1 + i * 2.0) * 40.0
		var rot := sin(t * 1.4 + i) * 1.1 + i
		var flip := snappedf(cos(t * 2.0 + i * 1.3), 0.2)
		var sz := 0.9 + 0.5 * fposmod(s.z, 1.0)
		Art.push(ci, Vector2(x, y), rot, Vector2(1.0, flip if absf(flip) > 0.2 else 0.2) * sz)
		Art.toon(ci, TileJungle.leaf_pts(22.0, 7.0), LEAF if i % 2 == 0 else Color("8ad84a"), 2.0, 0.3)
		Art.line(ci, Vector2(2, 0), Vector2(18, 0), LEAF_DARK, 1.2)
		Art.pop(ci)
	# Butterflies fluttering on wavy paths.
	var flies := 2 if low else 4
	for i in flies:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var f := fposmod(t * (0.018 + 0.005 * i) + i * 0.27, 1.0)
		var x := lerpf(-40.0, v.x + 40.0, f) if dir > 0.0 else lerpf(v.x + 40.0, -40.0, f)
		var y := v.y * (0.16 + 0.19 * i) + sin(t * 1.3 + i * 2.1) * 34.0 + sin(t * 5.0 + i) * 5.0
		butterfly(ci, Vector2(x, y), t * 9.0 + i * 1.7, FLOWERS[(i + 1) % FLOWERS.size()] if i != 0 else Color("3aa0ff"), 0.9 + 0.15 * (i % 2), dir)


## A little butterfly at `at`; `ph` the flap phase.
static func butterfly(ci: CanvasItem, at: Vector2, ph: float, col: Color, s: float, dir: float = 1.0) -> void:
	var flap := snappedf(0.25 + 0.75 * absf(sin(ph)), 0.125)
	Art.push(ci, at, 0.25 * dir, Vector2(dir, 1.0) * s)
	for sx: float in [-1.0, 1.0]:
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(sx * flap, 1.0))
		Art.toon(ci, Art.ellipse_pts(Vector2(8, -5), Vector2(8, 6.5), 14, -0.4), col, 2.0, 0.3)
		Art.toon(ci, Art.ellipse_pts(Vector2(6, 5), Vector2(5, 4), 12, 0.5), col.darkened(0.15), 2.0, 0.2)
		Art.flat(ci, Art.circle_pts(Vector2(9, -6), 2.2, 8), Color(1, 1, 1, 0.75))
		Art.pop(ci)
	Art.toon(ci, Art.rrect_pts(Rect2(-1.6, -8, 3.2, 16), 1.6), Color("3a2a40"), 1.6, 0.0)
	Art.line(ci, Vector2(0, -8), Vector2(-3, -13), Art.INK, 1.2)
	Art.line(ci, Vector2(0, -8), Vector2(3, -13), Art.INK, 1.2)
	Art.pop(ci)


# --- Ground and props -------------------------------------------------------------------------

## The mossy temple floor from y down: a grassy lip, dark earth, a few
## old flagstones in a path and grass tufts.
static func ground(ci: CanvasItem, v: Vector2, y: float) -> void:
	var top := PackedVector2Array([Vector2(-10, y + 26), Vector2(v.x * 0.18, y + 8), Vector2(v.x * 0.42, y + 22), Vector2(v.x * 0.66, y + 4),
			Vector2(v.x * 0.88, y + 18), Vector2(v.x + 10, y + 10), Vector2(v.x + 10, v.y + 10), Vector2(-10, v.y + 10)])
	var shape := Art.smooth_pts(top, 3)
	# A tall floor (phones) gets bigger plants.
	var g := clampf((v.y - y) / 170.0, 1.0, 2.0)
	Art.toon(ci, shape, Color("4a7a30"), 4.0, 0.5)
	# Darker earth further down.
	Art.flat(ci, Art.clipped(Art.moved(shape, Vector2(0, 30)), shape), Color("3a6428"))
	# A light grassy lip along the top edge.
	var lip := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 25:
		var f := i / 24.0
		var p := _edge_y(top, f * v.x)
		lip.append(Vector2(f * v.x, p - 1.0))
		low.append(Vector2(f * v.x, p + 9.0 + 3.0 * sin(i * 1.9)))
	low.reverse()
	lip.append_array(low)
	Art.flat(ci, lip, Color("7cc44a"))
	# Old flagstones: a path of a few slabs, smaller further up.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var rows := 3
	for r in rows:
		var ry := y + 36.0 + r * (v.y - y - 30.0) / rows
		var n := 3 + r
		for i in n:
			if rng.randf() < 0.3:
				continue
			var w := (36.0 + r * 12.0) * rng.randf_range(0.8, 1.2) * g
			var cx := v.x * (i + 0.5) / n + rng.randf_range(-12.0, 12.0)
			var slab := Rect2(cx - w / 2.0, ry, w, (14.0 + r * 5.0) * g)
			var c := STONE.lerp(Color("7a9a58"), rng.randf_range(0.3, 0.5))
			Art.t_rect(ci, slab, 5.0, c, 2.4, 0.4)
			Art.flat(ci, Art.ellipse_pts(slab.position + Vector2(slab.size.x * 0.25, 2), Vector2(w * 0.22, 3.5), 12), Color(MOSS, 0.9))
	# A row of ferns behind the path.
	var fx := 20.0
	var fi := 0
	while fx < v.x:
		fern(ci, Vector2(fx, _edge_y(top, fx) + 34.0 * g), (0.75 + 0.2 * (fi % 2)) * g, LEAF if fi % 2 == 0 else Color("2fa04a"))
		fx += rng.randf_range(80.0, 130.0) * g
		fi += 1
	# Lush bushes along the very bottom (in front), big leaves in the corners.
	var bx := -30.0
	var bi := 0
	while bx < v.x + 30.0:
		var br := rng.randf_range(34.0, 52.0) * g
		var bc: Color = [Color("2f8a3a"), Color("3aa852"), Color("23863a")][bi % 3]
		Art.toon(ci, Art.circle_pts(Vector2(bx, v.y + br * 0.35), br, 20), bc, 3.0, 0.4)
		if bi % 3 == 1:
			flower(ci, Vector2(bx + 6.0, v.y - br * 0.35), 0.45 * g, FLOWERS[bi % FLOWERS.size()])
		bx += br * 1.5
		bi += 1
	for sd: float in [-1.0, 1.0]:
		var corner := Vector2(0.0 if sd < 0.0 else v.x, v.y + 10.0)
		for j in 3:
			Art.push(ci, corner, -PI / 2.0 + sd * (0.35 + j * 0.32))
			monstera(ci, (110.0 - j * 18.0) * g, [LEAF, Color("2fa04a"), Color("5cd05a")][j])
			Art.pop(ci)
	# Grass tufts all along.
	for i in int(v.x / 26.0) + 1:
		var gx := i * 26.0 + rng.randf_range(-6.0, 6.0)
		var gy := _edge_y(top, gx) + rng.randf_range(6.0, 40.0) * (1.0 if i % 3 != 0 else 2.5)
		if gy > v.y - 4.0:
			continue
		_tuft(ci, Vector2(gx, gy), rng.randf_range(0.7, 1.2) * g, Color("6cc24a") if i % 2 == 0 else Color("8ad84a"))


## y of the ground's (straight-segment) top edge at x.
static func _edge_y(top: PackedVector2Array, x: float) -> float:
	for i in range(1, 6):
		if x <= top[i].x or i == 5:
			var a := top[i - 1]
			var b := top[i]
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(1.0, b.x - a.x), 0.0, 1.0))
	return top[0].y


static func _tuft(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	Art.push(ci, at, 0.0, Vector2.ONE * s)
	Art.toon(ci, PackedVector2Array([Vector2(-7, 0), Vector2(-9, -10), Vector2(-4, -3), Vector2(-1, -14), Vector2(2, -3), Vector2(7, -11), Vector2(6, 0)]), col, 1.8, 0.2)
	Art.pop(ci)


## A fern of fronds fanning up from `base`.
static func fern(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	Art.push(ci, base, 0.0, Vector2.ONE * s)
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.45
		Art.push(ci, Vector2.ZERO, a)
		var len := 52.0 - absf(i - 2) * 8.0
		Art.stroke(ci, PackedVector2Array([Vector2.ZERO, Vector2(len * 0.5, -4), Vector2(len, 2)]), col.darkened(0.2), 2.4, 1.4)
		for j in 5:
			var f := 0.2 + j * 0.16
			var p := Vector2(len * f, -3.0 * sin(f * PI))
			var l := 13.0 * (1.0 - f * 0.6)
			Art.push(ci, p, -1.0)
			Art.toon(ci, TileJungle.leaf_pts(l, l * 0.3), col, 1.6, 0.2)
			Art.pop(ci)
			Art.push(ci, p, 1.0)
			Art.toon(ci, TileJungle.leaf_pts(l, l * 0.3), col, 1.6, 0.2)
			Art.pop(ci)
		Art.pop(ci)
	Art.pop(ci)


## Small things on the floor along the bottom of the screen.
static func floor_prop(ci: CanvasItem, i: int) -> void:
	match i % 5:
		0:
			fern(ci, Vector2(0, 6), 0.7, LEAF)
		1:
			Art.push(ci, Vector2(0, -6), 0.0, Vector2.ONE * 0.6)
			TileJungle.piece(ci, 3, 0.0, Color("9a6234"))
			Art.pop(ci)
		2:
			fern(ci, Vector2(0, 6), 0.6, Color("5cd05a"))
			flower(ci, Vector2(6, -18), 0.5, FLOWERS[0])
		3:
			# A fallen carved stone head.
			Art.push(ci, Vector2(0, -8), -0.25, Vector2.ONE * 0.7)
			stone_head(ci)
			Art.pop(ci)
		4:
			Art.push(ci, Vector2(0, -6), 0.0, Vector2.ONE * 0.55)
			TileJungle.piece(ci, 0, 0.0, Color("ffe03a"))
			Art.pop(ci)


## A carved stone head (the idol mask in moss-covered stone).
static func stone_head(ci: CanvasItem) -> void:
	var col := Color("b8a070")
	var face := Art.smooth_pts(PackedVector2Array([Vector2(-22, -26), Vector2(22, -26), Vector2(24, 10), Vector2(14, 26), Vector2(-14, 26), Vector2(-24, 10)]), 2)
	Art.toon(ci, face, col, 3.2, 0.6)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-26, -26, 52, 8), 1.0), face), Art.shade_of(col, 0.3))
	for sx: float in [-1.0, 1.0]:
		Art.toon(ci, Art.ellipse_pts(Vector2(9 * sx, -6), Vector2(6, 3.6), 14), Color("4a3a20"), 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-3, -4), Vector2(3, -4), Vector2(5, 8), Vector2(-5, 8)]), col.lightened(0.12))
	Art.t_rect(ci, Rect2(-10, 13, 20, 6), 2.5, Color("4a3a20"), 1.8, 0.0)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-14, -22), Vector2(16, 9), 16), face), Color(MOSS, 0.9))
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(18, 22), Vector2(10, 6), 14), face), Color(MOSS, 0.85))


## The big decoration beside the board (wide screens): a stone idol statue
## on the left, a banana plant with a parrot on the right.
static func side_prop(ci: CanvasItem, s: float, t: float) -> void:
	if s < 0.0:
		Art.push(ci, Vector2(0, -10), 0.0, Vector2.ONE * 1.25)
		# Plinth, then the head on it.
		Art.toon(ci, Art.rrect_pts(Rect2(-34, -20, 68, 34), 4.0), Color("a89060"), 3.5, 0.5)
		Art.line(ci, Vector2(-30, -8), Vector2(30, -8), Art.shade_of(Color("a89060"), 0.3), 2.0)
		Art.push(ci, Vector2(0, -50))
		stone_head(ci)
		# Its eyes light up now and then.
		var on := snappedf(maxf(0.0, sin(t * 0.9)), 0.25)
		if on > 0.0:
			for sx: float in [-1.0, 1.0]:
				Art.glow(ci, Vector2(9 * sx, -6), 10.0, Color(0.3, 1.0, 0.85, 0.55 * on))
				Art.flat(ci, Art.circle_pts(Vector2(9 * sx, -6), 2.2, 10), Color(0.6, 1.0, 0.9, on))
		Art.pop(ci)
		fern(ci, Vector2(-36, 14), 0.8, LEAF)
		fern(ci, Vector2(38, 14), 0.7, Color("5cd05a"))
		Art.pop(ci)
	else:
		Art.push(ci, Vector2(0, 0), 0.0, Vector2.ONE * 1.2)
		banana_plant(ci, t)
		Art.push(ci, Vector2(-62, -112), 0.0, Vector2(-1.0, 1.0) * 0.9)
		TileJungle.piece(ci, 1, t, Color("3a9cff"))
		Art.pop(ci)
		fern(ci, Vector2(-30, 16), 0.7, LEAF)
		fern(ci, Vector2(30, 16), 0.6, Color("5cd05a"))
		Art.pop(ci)


## A banana plant: a thick stem, long arching leaves and a hanging bunch.
static func banana_plant(ci: CanvasItem, t: float) -> void:
	var stem := Color("7a9a3a")
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-9, 16), Vector2(-7, -60), Vector2(-5, -130), Vector2(5, -130), Vector2(8, -60), Vector2(10, 16)]), 2), stem, 3.0, 0.5)
	for i in 3:
		Art.line(ci, Vector2(-5, -20 - i * 38), Vector2(6, -34 - i * 38), stem.darkened(0.25), 2.0)
	# Arching leaves: crescents curving out and down from the top.
	for i in 6:
		var sd := -1.0 if i % 2 == 0 else 1.0
		var reach := 70.0 + (i / 2) * 22.0
		var lift := 70.0 - (i / 2) * 26.0
		var a := Vector2(0, -128)
		var b := a + Vector2(sd * reach * 0.55, -lift)
		var c := a + Vector2(sd * reach, -lift * 0.2 + 40.0)
		var col := LEAF if i % 3 == 0 else (Color("2fa04a") if i % 3 == 1 else Color("5cd05a"))
		Art.toon(ci, TileJungle._crescent(a, b, c, 34.0 - (i / 2) * 4.0, 14, 1.0), col, 3.0, 0.45)
		var rib := PackedVector2Array()
		for j in 9:
			rib.append(TileJungle._qb(a, b, c, j / 8.0))
		Art.polyline(ci, rib, col.darkened(0.3), 2.2)
	# The bunch and its purple flower bud.
	Art.push(ci, Vector2(12, -112), 0.15)
	TileJungle.piece(ci, 0, 0.0, Color("ffe03a"))
	Art.pop(ci)
	Art.toon(ci, Art.ellipse_pts(Vector2(16, -76), Vector2(7, 11), 16, 0.2), Color("9a3a7a"), 2.6, 0.4)


## Carved stone frame details: block seams, moss, vines draped over the top
## edge with flowers, carved sun discs on the corners.
static func frame_deco(ci: CanvasItem, outer: Rect2, inner: Rect2, pad: float, tile: float) -> void:
	var seam := Art.shade_of(STONE, 0.32)
	var step := maxf(40.0, tile * 1.2)
	# Seams across the frame band, every block.
	var x := outer.position.x + step
	while x < outer.end.x - step * 0.5:
		Art.line(ci, Vector2(x, outer.position.y + 3), Vector2(x, inner.position.y - 3), seam, 2.0)
		Art.line(ci, Vector2(x + step * 0.5, inner.end.y + 3), Vector2(x + step * 0.5, outer.end.y - 3), seam, 2.0)
		x += step
	var y := outer.position.y + step
	while y < outer.end.y - step * 0.5:
		Art.line(ci, Vector2(outer.position.x + 3, y), Vector2(inner.position.x - 3, y), seam, 2.0)
		Art.line(ci, Vector2(inner.end.x + 3, y + step * 0.5), Vector2(outer.end.x - 3, y + step * 0.5), seam, 2.0)
		y += step
	# Little carved zigzag along the top band.
	var zz := PackedVector2Array()
	var zy := outer.position.y + pad * 0.5
	var zx := outer.position.x + pad * 1.6
	var up := true
	while zx < outer.end.x - pad * 1.6:
		zz.append(Vector2(zx, zy + (-pad * 0.14 if up else pad * 0.14)))
		zx += pad * 0.42
		up = not up
	if zz.size() > 1:
		Art.polyline(ci, zz, Color(seam, 0.7), 1.8)
	# Moss on the lower corners and the sides.
	for p: Vector3 in [Vector3(0.0, 1.0, 1.0), Vector3(1.0, 1.0, 0.8), Vector3(0.0, 0.55, 0.6), Vector3(1.0, 0.3, 0.55)]:
		var c := Vector2(lerpf(outer.position.x + pad * 0.5, outer.end.x - pad * 0.5, p.x), lerpf(outer.position.y, outer.end.y - pad * 0.4, p.y))
		var side := p.y < 0.9
		var rr := (Vector2(pad * 0.36, pad * 1.6) if side else Vector2(pad * 1.4, pad * 0.36)) * p.z
		Art.flat(ci, Art.ellipse_pts(c, rr, 16), Color(MOSS, 0.92))
		Art.flat(ci, Art.ellipse_pts(c + rr * Vector2(0.3, 0.3), rr * 0.6, 14), Color("4caa3a", 0.92))
	# Vines draped over the top edge, sagging between three hooks.
	var k := clampf(tile / 70.0, 0.6, 1.5)
	var hooks := [outer.position.x + pad * 0.5, outer.position.x + outer.size.x * 0.36, outer.position.x + outer.size.x * 0.7, outer.end.x - pad * 0.5]
	var vy := outer.position.y + pad * 0.35
	for i in hooks.size() - 1:
		var a := Vector2(float(hooks[i]), vy)
		var b := Vector2(float(hooks[i + 1]), vy + (pad * 0.3 if i == 1 else 0.0))
		var sag := pad * (0.45 + 0.15 * i)
		var pts := PackedVector2Array()
		for j in 11:
			var f := j / 10.0
			pts.append(a.lerp(b, f) + Vector2(0, sin(f * PI) * sag))
		Art.stroke(ci, pts, Color("3f9a34"), 3.4 * k, 1.8)
		for j in range(1, 10, 2):
			var sd := 1.0 if (j + i) % 4 == 1 else -1.0
			TileJungle.leaf(ci, pts[j], PI / 2.0 + sd * 0.9, 15.0 * k, 5.5 * k, LEAF if j % 4 == 1 else Color("5cd05a"), 2.0)
		# A short strand hanging down.
		var mid := pts[5]
		var hang := PackedVector2Array([mid, mid + Vector2(3, 10) * k, mid + Vector2(-2, 22) * k])
		Art.stroke(ci, hang, Color("3f9a34"), 2.6 * k, 1.6)
		TileJungle.leaf(ci, hang[2], PI / 2.0 + 0.3, 12.0 * k, 4.5 * k, LEAF, 1.8)
	# Flowers on the vines.
	for p: Vector3 in [Vector3(0.36, 0.0, 0.0), Vector3(0.7, 0.3, 1.0), Vector3(0.12, 0.6, 3.0)]:
		flower(ci, Vector2(outer.position.x + outer.size.x * p.x, vy + pad * p.y), 0.55 * k, FLOWERS[int(p.z)])
	# Carved sun discs on the four corners.
	for c: Vector2 in [outer.position + Vector2(pad * 0.5, pad * 0.5), Vector2(outer.end.x - pad * 0.5, outer.position.y + pad * 0.5),
			Vector2(outer.position.x + pad * 0.5, outer.end.y - pad * 0.5), outer.end - Vector2(pad * 0.5, pad * 0.5)]:
		Art.push(ci, c, 0.0, Vector2.ONE * (pad / 26.0))
		sun_stone(ci)
		Art.pop(ci)


## A round carved stone with a sun on it (frame corners), ~ r 16.
static func sun_stone(ci: CanvasItem) -> void:
	Art.t_circle(ci, Vector2.ZERO, 16.0, Color("e8cc8a"), 3.0, 0.6)
	var line := Art.shade_of(STONE, 0.35)
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, 11.0, 22), line, 2.0)
	Art.t_circle(ci, Vector2.ZERO, 5.0, Color("ffc93c"), 2.0, 0.3)
	for i in 8:
		var a := TAU * i / 8.0
		Art.line(ci, Vector2(cos(a), sin(a)) * 6.5, Vector2(cos(a), sin(a)) * 10.0, line, 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -8), Vector2(4, 2), 10, -0.6), Color(1, 1, 1, 0.5))
