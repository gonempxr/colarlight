class_name JungleRiver
extends RefCounted
## Fishing in the Jungle Ruins (FishingScene world 4): a wooden temple pier
## on carved stone pillars over a clear turquoise river. Far away: jungle
## hills, a stepped pyramid and a waterfall; on the water: lily pads with
## lotus flowers, reeds, a mossy stone idol on a little island, dragonflies,
## fireflies glowing in the shade and leaves floating down the current.
##
## The fishing screen redraws its background ~30 times a second, so the
## parts that never move are recorded once (Art.cache_begin) and pasted;
## only a few small things move, each with push/pop on a fixed shape.

const LEAF := Color("3fbf4a")
const LEAF_DARK := Color("23863a")
const MOSS := Color("5cbf3a")
const STONE := Color("d9bb7c")
const STONE_DARK := Color("a8844a")
const WOOD := Color("b8743e")
const WOOD_DARK := Color("7a4a2a")
const LOTUS := [Color("ff7ab8"), Color("fff0f6"), Color("ffd23a")]
## Lily pads: x (of the width), depth 0..1 (far..near), size.
const PADS := [Vector3(0.56, 0.08, 0.9), Vector3(0.38, 0.22, 1.0), Vector3(0.95, 0.5, 1.1), Vector3(0.62, 0.64, 0.95),
		Vector3(0.45, 0.4, 0.8), Vector3(0.86, 0.86, 1.2), Vector3(0.2, 0.04, 0.75)]


# --- Sky and the far shore -----------------------------------------------------------------

static func sky(sc: FishingScene, ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var key := hash(["jsky", v, hz, k])
	if not Art.cache_begin(ci, key):
		_far(sc, ci, v, hz, k)
		Art.cache_end(ci, key)
	_waterfall(ci, v, hz, t, k)
	# Clouds drift over everything far.
	sc._clouds_draw(ci, v, hz * 0.75, t, k * 0.8, Art.WHITE, Color("8cc8d8"))


static func _sun_pos(v: Vector2, hz: float) -> Vector2:
	return Vector2(v.x * 0.8, hz * 0.36)


static func _far(sc: FishingScene, ci: CanvasItem, v: Vector2, hz: float, k: float) -> void:
	var sp := _sun_pos(v, hz)
	sc._glow(ci, sp, 150.0 * k, Color(1.0, 0.97, 0.7, 0.55))
	for i in 12:
		var a := TAU * i / 12.0
		var len := (62.0 + (i % 2) * 16.0) * k
		Art.flat(ci, PackedVector2Array([sp + Vector2.from_angle(a - 0.12) * 40.0 * k, sp + Vector2.from_angle(a) * len, sp + Vector2.from_angle(a + 0.12) * 40.0 * k]),
				Color(1.0, 0.95, 0.6, 0.55))
	Art.t_circle(ci, sp, 34.0 * k, Color("fff2a0"), 3.0, 0.3)
	Art.flat(ci, Art.ellipse_pts(sp + Vector2(-10, -12) * k, Vector2(10, 6) * k, 12, -0.6), Color(1, 1, 1, 0.7))
	# Far blue-green hills.
	var hills := PackedVector2Array([Vector2(-20, hz + 2)])
	for i in 9:
		var x := v.x * i / 8.0
		hills.append(Vector2(x, hz - (40.0 + 34.0 * absf(sin(i * 1.7 + 0.4))) * k))
	hills.append(Vector2(v.x + 20, hz + 2))
	Art.flat(ci, Art.smooth_pts(hills, 3), Color("8cc8b4"))
	# The stepped pyramid on the far hills.
	_pyramid(ci, Vector2(v.x * 0.6, hz - 112.0 * k), 0.62 * k, Color("6aae96"))
	# The waterfall's cliff on the left of the far shore.
	var cx := v.x * 0.24
	var cliff := Art.smooth_pts(PackedVector2Array([Vector2(cx - 110 * k, hz + 2), Vector2(cx - 90 * k, hz - 80 * k), Vector2(cx - 50 * k, hz - 128 * k),
			Vector2(cx - 18 * k, hz - 136 * k), Vector2(cx + 22 * k, hz - 134 * k), Vector2(cx + 60 * k, hz - 110 * k), Vector2(cx + 96 * k, hz - 60 * k),
			Vector2(cx + 120 * k, hz + 2)]), 2)
	Art.flat(ci, cliff, Color("5f9a7e"))
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(cx, hz - 136 * k), Vector2(70, 22) * k, 18), cliff), Color("4f9a5a"))
	# The treeline along the far bank: round crowns and a few palms.
	var rng := RandomNumberGenerator.new()
	rng.seed = 512
	var bank := Color("3f8a5a")
	Art.flat(ci, PackedVector2Array([Vector2(-20, hz - 8.0 * k), Vector2(v.x + 20, hz - 8.0 * k), Vector2(v.x + 20, hz + 3), Vector2(-20, hz + 3)]), bank)
	var x := -20.0
	while x < v.x + 40.0:
		var r := rng.randf_range(14.0, 26.0) * k
		Art.flat(ci, Art.circle_pts(Vector2(x, hz - rng.randf_range(4.0, 16.0) * k), r, 16), bank if int(x) % 3 != 0 else bank.lightened(0.06))
		x += r * 1.3
	for i in 5:
		var px := v.x * (0.08 + i * 0.21) + rng.randf_range(-20.0, 20.0)
		Art.push(ci, Vector2(px, hz - 10.0 * k), rng.randf_range(-0.12, 0.12), Vector2.ONE * k * rng.randf_range(0.55, 0.75))
		_palm_far(ci, Color("2f7a4a"))
		Art.pop(ci)


static func _pyramid(ci: CanvasItem, top: Vector2, s: float, col: Color) -> void:
	Art.push(ci, top, 0.0, Vector2.ONE * s)
	for i in 6:
		var w := 46.0 + i * 30.0
		var y := 24.0 + i * 22.0
		Art.flat(ci, Art.rrect_pts(Rect2(-w / 2.0, y, w, 23.0), 2.0), col.darkened(0.04 * (i % 2)))
		Art.flat(ci, PackedVector2Array([Vector2(-w / 2.0, y), Vector2(w / 2.0, y), Vector2(w / 2.0, y + 3.0), Vector2(-w / 2.0, y + 3.0)]), col.lightened(0.14))
	Art.flat(ci, PackedVector2Array([Vector2(-10, 24), Vector2(10, 24), Vector2(22, 156), Vector2(-22, 156)]), col.darkened(0.1))
	Art.flat(ci, Art.rrect_pts(Rect2(-18, 0, 36, 25), 2.0), col.lightened(0.06))
	Art.flat(ci, PackedVector2Array([Vector2(-22, 2), Vector2(22, 2), Vector2(16, -6), Vector2(-16, -6)]), col.lightened(0.12))
	Art.flat(ci, Art.rrect_pts(Rect2(-6, 9, 12, 16), 5.0), col.darkened(0.3))
	Art.pop(ci)


static func _palm_far(ci: CanvasItem, col: Color) -> void:
	Art.flat(ci, PackedVector2Array([Vector2(-3, 0), Vector2(-1, -70), Vector2(3, -70), Vector2(4, 0)]), col)
	for i in 6:
		var a := -PI + i * PI / 5.0
		Art.push(ci, Vector2(1, -70), a)
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -3), Vector2(20, -8), Vector2(40, 4), Vector2(20, 4), Vector2(0, 3)]), 2), col)
		Art.pop(ci)


## The waterfall: a bright fall with darker streaks running down, mist.
static func _waterfall(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var x := v.x * 0.24
	var top := hz - 124.0 * k
	var w := 30.0 * k
	Art.flat(ci, PackedVector2Array([Vector2(x - w * 0.5, top), Vector2(x + w * 0.5, top), Vector2(x + w * 0.62, hz + 2), Vector2(x - w * 0.62, hz + 2)]), Color("e8fbff"))
	# Streaks falling (stepped so the dashes share their shapes).
	var tt := snappedf(t, 1.0 / 20.0)
	for j in 3:
		var sx := x + (j - 1) * w * 0.28
		for i in 3:
			var f := fposmod(tt * 0.9 + i / 3.0 + j * 0.17, 1.0)
			var y := lerpf(top, hz - 10.0 * k, f)
			Art.push(ci, Vector2(sx, y))
			Art.flat(ci, Art.rrect_pts(Rect2(-1.6 * k, -9.0 * k, 3.2 * k, 18.0 * k), 1.6 * k), Color("8fdcec"))
			Art.pop(ci)
	# Mist puffs at the foot.
	for i in 3:
		var f := fposmod(tt * 0.4 + i / 3.0, 1.0)
		var s := snappedf(0.6 + f * 0.8, 0.1)
		Art.push(ci, Vector2(x + (i - 1) * 16.0 * k, hz - 4.0 * k - f * 10.0 * k), 0.0, Vector2(s, s * 0.7) * k)
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, 16.0, 14), Color(1, 1, 1, snappedf(0.75 * (1.0 - f), 0.05)))
		Art.pop(ci)


# --- The river -------------------------------------------------------------------------------

static func river(sc: FishingScene, ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var key := hash(["jriver", v, hz, k])
	if not Art.cache_begin(ci, key):
		var mid := lerpf(hz, v.y, 0.45)
		sc._band(ci, 0, v.x, hz, mid, sc.sea(0), sc.sea(1))
		sc._band(ci, 0, v.x, mid, v.y, sc.sea(1), sc.sea(2))
		# Reflection of the green bank under the horizon.
		var refl := PackedVector2Array([Vector2(-10, hz)])
		for i in 13:
			refl.append(Vector2(v.x * i / 12.0, hz + (18.0 + 8.0 * sin(i * 2.1)) * k))
		refl.append(Vector2(v.x + 10, hz))
		Art.flat(ci, refl, Color(0.12, 0.42, 0.3, 0.45))
		Art.flat(ci, PackedVector2Array([Vector2(0, hz - 1), Vector2(v.x, hz - 1), Vector2(v.x, hz + 3), Vector2(0, hz + 3)]), Color(1, 1, 1, 0.5))
		# The waterfall's foam pool on the far water.
		Art.flat(ci, Art.ellipse_pts(Vector2(v.x * 0.24, hz + 6.0 * k), Vector2(56, 7) * k, 18), Color(1, 1, 1, 0.55))
		# The stone idol on its little island, and the reeds by it.
		_islet(ci, Vector2(v.x * 0.8, lerpf(hz, v.y, 0.3)), k * 1.05)
		Art.cache_end(ci, key)
	# Sun glints under the sun.
	var sp := _sun_pos(v, hz)
	for i in 12:
		var gx := sp.x + sin(i * 2.3) * 60.0 * (1.0 + i * 0.1)
		var gy := hz + 16.0 + i * 15.0 * k
		var a := snappedf(0.25 + 0.3 * sin(t * 3.0 + i * 1.7), 0.05)
		if a > 0.05:
			Art.flat(ci, PackedVector2Array([Vector2(gx - 15, gy), Vector2(gx, gy - 2.5), Vector2(gx + 15, gy), Vector2(gx, gy + 2.5)]), Color(1, 1, 0.9, a))
	# Current lines flowing to the right.
	sc._waves(ci, v, hz, t * 0.8, k, Color(0.88, 1.0, 0.97), 0.16)
	# Lily pads bobbing, a frog on one of them.
	for i in PADS.size():
		var p: Vector3 = PADS[i]
		var y := lerpf(hz + 30.0 * k, v.y - 60.0 * k, p.y)
		var s := lerpf(0.55, 1.5, p.y) * k * p.z
		var x := p.x * v.x + sin(t * 0.3 + i * 2.0) * 6.0 * k
		Art.push(ci, Vector2(x, y + snappedf(sin(t * 1.2 + i * 1.7), 0.25) * 2.0), snappedf(sin(t * 0.5 + i), 0.25) * 0.05, Vector2(s, s * 0.5))
		var key2 := hash(["jpad", i % 3])
		if not Art.cache_begin(ci, key2):
			_pad(ci, i % 3)
			Art.cache_end(ci, key2)
		Art.pop(ci)
		if i == 2:
			Art.push(ci, Vector2(x - 6.0 * s, y - 10.0 * s), 0.0, Vector2.ONE * s * 0.55)
			_frog(ci, t)
			Art.pop(ci)
	# Leaves and petals floating down the river.
	for i in 3:
		var f := fposmod(t * 0.02 + i * 0.37, 1.0)
		var y := lerpf(hz + 60.0 * k, v.y - 120.0 * k, fposmod(i * 0.43 + 0.2, 1.0))
		var x := lerpf(-40.0, v.x + 40.0, f)
		Art.push(ci, Vector2(x, y + snappedf(sin(t * 1.5 + i), 0.25) * 3.0), snappedf(t * 0.3 + i, 0.1), Vector2(1.0, 0.5) * k)
		Art.toon(ci, TileJungle.leaf_pts(26.0, 8.0), LEAF if i != 1 else Color("ff7ab8"), 2.0, 0.3)
		Art.pop(ci)
	# Dragonflies hovering and darting.
	for i in 2:
		var cyc := fposmod(t * 0.11 + i * 0.5, 1.0)
		var hx := v.x * (0.55 + 0.3 * sin(cyc * TAU + i)) + snappedf(sin(t * 7.0 + i), 0.25) * 3.0
		var hy := lerpf(hz, v.y, 0.18 + 0.12 * i) + sin(cyc * TAU * 2.0) * 30.0 * k
		_dragonfly(ci, Vector2(hx, hy), t + i, k * 0.8, 1.0 if cos(cyc * TAU + i) > 0.0 else -1.0)


static func _pad(ci: CanvasItem, kind: int) -> void:
	var pad := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(34, -18), Vector2(40, 8), Vector2(18, 34), Vector2(-20, 34), Vector2(-40, 8), Vector2(-34, -18), Vector2(-6, -36), Vector2(6, -36)]), 2)
	Art.toon(ci, pad, Color("3fb04a") if kind != 1 else Color("5cc24a"), 3.0, 0.4)
	for a: float in [0.6, 1.4, 2.2, 3.0, 3.8]:
		Art.line(ci, Vector2.ZERO, Vector2(cos(a), sin(a)) * 30.0, Color("2a8a3a"), 2.0)
	if kind == 2:
		return
	# A lotus flower standing on it (squashed pad, so stretch it back).
	Art.push(ci, Vector2(10, -2), 0.0, Vector2(1.0, 2.0))
	var col: Color = LOTUS[kind]
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.42
		Art.push(ci, Vector2(0, 2), a + PI / 2.0)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-6, -8), Vector2(0, -20), Vector2(6, -8)]), 2), col if i % 2 == 0 else col.darkened(0.08), 2.0, 0.3)
		Art.pop(ci)
	Art.t_circle(ci, Vector2(0, -2), 4.0, Color("ffe04a"), 1.6, 0.0)
	Art.pop(ci)


static func _frog(ci: CanvasItem, t: float) -> void:
	var col := Color("6ad84a")
	for sx: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(9 * sx, -12), 7.0, col, 2.4, 0.3)
	Art.t_ellipse(ci, Vector2(0, 0), Vector2(18, 13), col, 2.6, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 6), Vector2(12, 6), 14), Color("d8ffb0"))
	var blink := fposmod(t, 4.1) < 0.14
	for sx: float in [-1.0, 1.0]:
		if blink:
			Art.line(ci, Vector2(9 * sx - 3, -12), Vector2(9 * sx + 3, -12), Art.INK, 1.8)
		else:
			Art.disc(ci, Vector2(9 * sx, -12), 3.6, Art.WHITE)
			Art.disc(ci, Vector2(9 * sx + 0.6, -11.4), 2.2, Art.INK)
	Art.arc(ci, Vector2(0, -1), 6.0, 0.4, PI - 0.4, 8, Art.INK, 1.8)
	# Throat puffs now and then.
	var puff := snappedf(maxf(0.0, sin(t * 2.4)) , 0.25)
	if puff > 0.0:
		Art.t_circle(ci, Vector2(0, 7), 3.0 + puff * 3.0, Color("fff0b0"), 1.6, 0.0)


static func _dragonfly(ci: CanvasItem, at: Vector2, t: float, s: float, dir: float) -> void:
	Art.push(ci, at, 0.0, Vector2(dir, 1.0) * s)
	var up := int(t * 16.0) % 2 == 0
	for sy: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(2, -2), sy * (0.25 if up else 0.55) - PI / 2.0 * 0.0)
		Art.toon(ci, Art.ellipse_pts(Vector2(-2, -8 * sy), Vector2(4, 9), 12, 0.3 * sy), Color(0.85, 1.0, 1.0, 0.7), 1.6, 0.0)
		Art.pop(ci)
	Art.toon(ci, TileArt._capsule(Vector2(-20, 0), Vector2(2, 0), 2.2), Color("1fb8a8"), 1.8, 0.0)
	Art.t_circle(ci, Vector2(5, 0), 4.0, Color("2fd2c0"), 1.8, 0.3)
	Art.disc(ci, Vector2(7, -1.5), 1.5, Art.INK)
	Art.pop(ci)


## A little rocky island with grass, a palm and the mossy stone idol.
static func _islet(ci: CanvasItem, c: Vector2, s: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * s)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 8), Vector2(118, 16), 24), Color(0.05, 0.3, 0.28, 0.35))
	var rock := Art.smooth_pts(PackedVector2Array([Vector2(-110, 6), Vector2(-80, -18), Vector2(-30, -26), Vector2(30, -28), Vector2(84, -16), Vector2(112, 6), Vector2(60, 14), Vector2(-60, 14)]), 3)
	Art.toon(ci, rock, Color("8a8a6a"), 3.0, 0.5)
	Art.flat(ci, Art.clipped(Art.moved(rock, Vector2(0, -10)), rock), Color("5cbf3a"))
	# A palm leaning over the water.
	Art.push(ci, Vector2(64, -18), 0.18, Vector2.ONE * 0.95)
	Props.palm(ci, 0.0, 0.3, 0.0, 2)
	Art.pop(ci)
	# The idol head on a plinth.
	Art.toon(ci, Art.rrect_pts(Rect2(-32, -46, 64, 26), 4.0), Color("a89060"), 3.0, 0.5)
	Art.push(ci, Vector2(-2, -86), 0.0, Vector2.ONE * 1.25)
	JungleBoard.stone_head(ci)
	Art.pop(ci)
	# Reeds and a fern at its feet.
	JungleBoard.fern(ci, Vector2(-56, -14), 0.75, LEAF)
	for i in 4:
		Art.push(ci, Vector2(-96 + i * 9.0, 0), -0.1 + i * 0.07)
		Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(2, -26 - i * 4), Vector2(0, -50 - i * 6)]), Color("4caa3a"), 3.0, 1.6)
		if i % 2 == 0:
			Art.t_rect(ci, Rect2(-3.5, -66 - i * 6, 7, 18), 3.5, Color("7a4a2a"), 2.0, 0.3)
		Art.pop(ci)
	Art.pop(ci)


## The idol's eyes glow and fireflies dance near the shady island.
static func idol_glow(ci: CanvasItem, v: Vector2, hz: float, t: float, k: float) -> void:
	var c := Vector2(v.x * 0.8, lerpf(hz, v.y, 0.3))
	var s := k * 1.05
	var on := snappedf(maxf(0.0, sin(t * 0.7)), 0.1)
	if on > 0.0:
		for sx: float in [-1.0, 1.0]:
			var e := c + (Vector2(-2, -86) + Vector2(9 * sx, -6) * 1.25) * s
			Art.glow(ci, e, 14.0 * s, Color(0.3, 1.0, 0.85, 0.6 * on))
			Art.dot(ci, e, 2.6 * s, Color(0.7, 1.0, 0.95, on))
	for i in 6:
		var ph := t * (0.6 + 0.1 * i) + i * 1.9
		var p := c + Vector2(sin(ph) * 90.0 + cos(ph * 0.7) * 30.0, -60.0 + cos(ph * 1.3) * 40.0) * s
		var a := snappedf(maxf(0.0, sin(t * 2.0 + i * 2.4)), 0.1)
		if a > 0.0:
			Art.glow(ci, p, 9.0 * s, Color(1.0, 1.0, 0.45, 0.5 * a))
			Art.dot(ci, p, 2.0 * s, Color(1.0, 1.0, 0.75, a))


# --- The temple pier ---------------------------------------------------------------------------

static func pier(sc: FishingScene, ci: CanvasItem, d: Rect2, v: Vector2, t: float, k: float) -> void:
	var post_h := minf(190.0 * k, v.y - d.position.y)
	var n := maxi(2, int(d.size.x / (150.0 * k)))
	var xs: Array[float] = []
	for i in n:
		xs.append(d.position.x + 50.0 * k + (d.size.x - 90.0 * k) * i / float(n - 1))
	# Ripple rings around the pillars (moving, outside the cache).
	for i in n:
		var wy := d.position.y + post_h * 0.55
		var rr := snappedf((30.0 + 5.0 * sin(t * 2.0 + i)) * k, 0.5)
		Art.push(ci, Vector2(xs[i], wy), 0.0, Vector2(1.0, 0.3))
		Art.arc(ci, Vector2.ZERO, rr, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 4.0)
		Art.pop(ci)
	var key := hash(["jpier", d, v, k])
	if not Art.cache_begin(ci, key):
		_pier_still(sc, ci, d, v, k, xs, post_h)
		Art.cache_end(ci, key)
	# A torch on the carved post at the end of the pier.
	var post := Vector2(d.end.x - 18.0 * k, d.position.y - 14.0 * k)
	_flame(ci, post + Vector2(0, -98.0) * k, t, k)
	# Reeds by the near right bank, swaying a little.
	Art.push(ci, Vector2(v.x + 6.0 * k, v.y - 30.0 * k), snappedf(sin(t * 1.1), 0.1) * 0.03, Vector2.ONE * k)
	var rk := hash(["jreeds"])
	if not Art.cache_begin(ci, rk):
		_reeds(ci)
		Art.cache_end(ci, rk)
	Art.pop(ci)
	# Big leaves sway at the bottom corner.
	Art.push(ci, Vector2(-10, v.y + 10), snappedf(sin(t * 0.9), 0.1) * 0.03)
	var lk := hash(["jleafs", k])
	if not Art.cache_begin(ci, lk):
		for j in 3:
			Art.push(ci, Vector2.ZERO, -PI / 2.0 + 0.45 + j * 0.35)
			JungleBoard.monstera(ci, (150.0 - j * 22.0) * k, [LEAF, Color("2fa04a"), Color("5cd05a")][j])
			Art.pop(ci)
		Art.cache_end(ci, lk)
	Art.pop(ci)


static func _pier_still(sc: FishingScene, ci: CanvasItem, d: Rect2, v: Vector2, k: float, xs: Array[float], post_h: float) -> void:
	var water := sc.sea(1)
	# Carved sandstone pillars into the water.
	for i in xs.size():
		var x: float = xs[i]
		var r := Rect2(x - 18.0 * k, d.position.y + 8.0, 36.0 * k, post_h)
		Art.t_rect(ci, r, 5.0, STONE.darkened(0.08), 3.0, 0.4)
		# A glyph band and block seams.
		Art.t_rect(ci, Rect2(r.position.x - 3.0 * k, r.position.y + 18.0 * k, r.size.x + 6.0 * k, 16.0 * k), 3.0, STONE, 2.4, 0.3)
		Art.polyline(ci, PackedVector2Array([Vector2(x - 10 * k, r.position.y + 26 * k), Vector2(x - 5 * k, r.position.y + 21 * k), Vector2(x, r.position.y + 26 * k),
				Vector2(x + 5 * k, r.position.y + 21 * k), Vector2(x + 10 * k, r.position.y + 26 * k)]), STONE_DARK, 2.0)
		for j in 3:
			var y := r.position.y + (58.0 + j * 34.0) * k
			Art.line(ci, Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), Art.shade_of(STONE, 0.3), 1.8)
		# Moss at the waterline, the water over the foot.
		var wy := d.position.y + post_h * 0.55
		Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, wy - 20.0 * k, r.size.x, 16.0 * k), 5.0), Color(MOSS, 0.9))
		Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, wy - 4.0, r.size.x, r.end.y - wy + 4.0), 4.0), Color(water, 0.55))
		# A vine hanging down the pillar.
		var vine := PackedVector2Array()
		for j in 6:
			vine.append(Vector2(x + sin(j * 1.3 + i) * 8.0 * k, d.position.y + 14.0 + j * 18.0 * k))
		Art.stroke(ci, Art.smooth_pts(vine, 2), Color("2f7a2a"), 2.6 * k, 1.4)
		for j in range(1, 6, 2):
			TileJungle.leaf(ci, vine[j], PI / 2.0 + (0.9 if j % 4 == 1 else -0.9), 14.0 * k, 5.0 * k, LEAF, 1.8)
	# The deck: a carved stone lip in front, wooden planks on top.
	var face := Rect2(d.position.x, d.position.y, d.size.x, d.size.y + 14.0 * k)
	Art.t_rect(ci, face, 6.0, STONE, 3.5, 0.4)
	var zz := PackedVector2Array()
	var zx := d.position.x + 10.0
	var up := true
	while zx < d.end.x - 10.0:
		zz.append(Vector2(zx, d.position.y + d.size.y * 0.55 + (-5.0 if up else 5.0) * k))
		zx += 12.0 * k
		up = not up
	if zz.size() > 1:
		Art.polyline(ci, zz, STONE_DARK, 2.4)
	Art.t_rect(ci, Rect2(d.position.x, d.position.y - 16.0 * k, d.size.x, d.size.y), 8.0, WOOD, 3.5, 0.5)
	var plank := 42.0 * k
	var x0 := d.position.x + plank
	while x0 < d.end.x - 10.0:
		Art.line(ci, Vector2(x0, d.position.y - 14.0 * k), Vector2(x0, d.position.y + d.size.y - 18.0 * k), WOOD_DARK, 2.0)
		x0 += plank
	# Moss tufts on the lip and a vine with flowers hanging off the front.
	for i in 4:
		var mx := d.position.x + d.size.x * (0.12 + i * 0.25)
		Art.flat(ci, Art.ellipse_pts(Vector2(mx, d.end.y + 8.0 * k), Vector2(20, 7) * k, 14), Color(MOSS, 0.95))
	var hang := PackedVector2Array()
	for j in 9:
		var f := j / 8.0
		hang.append(Vector2(d.position.x + d.size.x * (0.05 + 0.9 * f), d.end.y + 8.0 * k + sin(f * PI * 2.0) * 12.0 * k + 6.0 * k))
	Art.stroke(ci, Art.smooth_pts(hang, 2), Color("2f7a2a"), 2.8 * k, 1.6)
	for j in range(1, 8):
		TileJungle.leaf(ci, hang[j], PI / 2.0 + (0.8 if j % 2 == 0 else -0.8), 13.0 * k, 4.6 * k, LEAF if j % 3 else Color("5cd05a"), 1.8)
	for j in [2, 5]:
		JungleBoard.flower(ci, hang[j] + Vector2(0, 6.0 * k), 0.45 * k, JungleBoard.FLOWERS[j % 4])
	# The carved post at the end of the pier (the torch sits on it).
	var post := Vector2(d.end.x - 18.0 * k, d.position.y - 14.0 * k)
	Art.t_rect(ci, Rect2(post.x - 10.0 * k, post.y - 86.0 * k, 20.0 * k, 88.0 * k), 4.0, Color("8a5a32"), 3.0, 0.4)
	for j in 3:
		Art.push(ci, post + Vector2(0, (-74.0 + j * 24.0) * k), 0.0, Vector2.ONE * k * 0.42)
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(1.0, 0.8))
		JungleBoard.stone_head(ci)
		Art.pop(ci)
		Art.pop(ci)
	Art.t_rect(ci, Rect2(post.x - 13.0 * k, post.y - 96.0 * k, 26.0 * k, 10.0 * k), 3.0, STONE_DARK, 2.6, 0.3)


static func _reeds(ci: CanvasItem) -> void:
	for i in 7:
		var x := -10.0 - i * 13.0
		var h := 110.0 + (i % 3) * 30.0
		Art.stroke(ci, PackedVector2Array([Vector2(x, 20), Vector2(x - 4, -h * 0.5), Vector2(x - 10 + i, -h)]), Color("4caa3a") if i % 2 else Color("3f9a34"), 4.0, 1.8)
		if i % 2 == 0:
			Art.t_rect(ci, Rect2(x - 10 + i - 5, -h - 4, 10, 30), 5.0, Color("7a4a2a"), 2.2, 0.3)
	for j in 3:
		Art.push(ci, Vector2(-30, 20), -PI / 2.0 - 0.5 - j * 0.3)
		Art.toon(ci, TileJungle.leaf_pts(90.0 - j * 10.0, 14.0), Color("5cd05a") if j % 2 else LEAF, 2.6, 0.4)
		Art.pop(ci)


static func _flame(ci: CanvasItem, at: Vector2, t: float, k: float) -> void:
	var f := 1.0 + snappedf(sin(t * 9.0), 0.25) * 0.08
	Art.glow(ci, at + Vector2(0, -8) * k, 44.0 * k, Color(1.0, 0.75, 0.3, 0.35))
	Art.push(ci, at, snappedf(sin(t * 3.0), 0.25) * 0.06, Vector2(1.0 / f, f) * k)
	var outer := Art.smooth_pts(PackedVector2Array([Vector2(0, -30), Vector2(8, -14), Vector2(12, -2), Vector2(0, 4), Vector2(-12, -2), Vector2(-8, -14)]), 3)
	Art.toon(ci, outer, Color("ff8a2a"), 2.6, 0.2)
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -18), Vector2(5, -6), Vector2(0, 1), Vector2(-5, -6)]), 2), Color("ffe27a"))
	Art.pop(ci)


## Big leaves hanging into the top corners (in front of the sky).
static func canopy(ci: CanvasItem, v: Vector2, t: float, k: float) -> void:
	for sd: float in [-1.0, 1.0]:
		var corner := Vector2(-10.0 if sd < 0.0 else v.x + 10.0, -30.0)
		Art.push(ci, corner, snappedf(sin(t * 0.8 + sd), 0.1) * 0.025)
		var key := hash(["jcanopy", sd, k])
		if not Art.cache_begin(ci, key):
			for j in 4:
				var rot := PI / 2.0 + sd * (0.35 + j * 0.3)
				Art.push(ci, Vector2(sd * j * 22.0 * k, 0), rot)
				if j % 2 == 0:
					JungleBoard.monstera(ci, (230.0 - j * 24.0) * k, [Color("1f6a3a"), Color("2a8a45"), Color("3aa852"), Color("2a8a45")][j])
				else:
					Art.toon(ci, TileJungle.leaf_pts((250.0 - j * 26.0) * k, 52.0 * k), Color("2a8a45"), 3.0, 0.4)
					Art.line(ci, Vector2(10, 0), Vector2((220.0 - j * 26.0) * k, 0), Color("1f6a3a"), 2.4)
				Art.pop(ci)
			# A liana hanging down with a flower.
			var vine := PackedVector2Array()
			for j in 7:
				vine.append(Vector2(sd * (60.0 + sin(j * 1.4) * 10.0) * k, j * 30.0 * k))
			Art.stroke(ci, Art.smooth_pts(vine, 2), Color("2f7a2a"), 3.0 * k, 1.6)
			for j in range(1, 7):
				TileJungle.leaf(ci, vine[j], PI / 2.0 + (0.9 if j % 2 == 0 else -0.9), 16.0 * k, 5.6 * k, LEAF, 1.8)
			JungleBoard.flower(ci, vine[6] + Vector2(0, 8.0 * k), 0.5 * k, JungleBoard.FLOWERS[0 if sd < 0.0 else 1])
			Art.cache_end(ci, key)
		Art.pop(ci)


# --- The helper's raft ----------------------------------------------------------------------------

## A bamboo raft tied with rope, a leaf for shade.
static func raft(ci: CanvasItem, t: float) -> void:
	for i in 5:
		var y := -30.0 + i * 7.0
		Art.toon(ci, TileArt._capsule(Vector2(-96 + i * 2.0, y), Vector2(96 - i * 2.0, y), 5.0), Color("c8b45a") if i % 2 == 0 else Color("b8a04a"), 2.4, 0.3)
		for x: float in [-60.0, -10.0, 40.0]:
			Art.line(ci, Vector2(x + i * 1.0, y - 4.5), Vector2(x + i * 1.0, y + 4.5), Color("8a7a3a"), 1.4)
	for x: float in [-74.0, 74.0]:
		Art.t_rect(ci, Rect2(x - 4, -36, 8, 36), 2.0, Color("e8d8a8"), 1.8, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-80, -2, 160, 4), 2.0), Color(1, 1, 1, 0.3))
