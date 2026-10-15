class_name ReefArt
extends RefCounted
## The Twilight Zone's mine (the saga, act I) with its own volume and
## texture, like the Jungle's temple: dark pillow-basalt rock with lit tops
## and shaded feet, glowing veins, barnacles and coral crust; halls of deep
## water with god rays and caustics; dark sand with shells and glowing
## pebbles; whale-rib mine frames; brass shaft braces. All still shapes
## (DepthRow's background layer, drawn when the row changes).

const VEIN := Color("6af8ff")
const CORAL: Array[Color] = [Color("ff6ad8"), Color("ff9a6a"), Color("3ae2c2"), Color("b48aff")]
const BONE := Color("efe6d2")
const BRASS := Color("d9a441")


## Rock around a hall: `rock` is the site's color, `index` seeds the layout.
static func rock(ci: CanvasItem, w: float, h: float, rock_c: Color, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 173 + 29
	var top := rock_c.lightened(0.06)
	var low := rock_c.darkened(0.32)
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, low, low]))
	# Pillow basalt: rounded boulders packed in rows, lit from above.
	var y := 8.0
	while y < h + 20.0:
		var x := -rng.randf_range(0.0, 50.0)
		while x < w + 30.0:
			var rw := rng.randf_range(70.0, 120.0)
			var rh := rng.randf_range(34.0, 48.0)
			var c := Vector2(x + rw / 2.0, y + rh / 2.0)
			var depth := clampf(c.y / h, 0.0, 1.0)
			var tone := rock_c.lerp(low, depth * 0.6).lightened(rng.randf_range(-0.04, 0.06))
			boulder(ci, c, Vector2(rw / 2.0, rh / 2.0), tone)
			x += rw * rng.randf_range(0.85, 1.0)
		y += rng.randf_range(34.0, 42.0)
	# Glowing veins between the boulders.
	for k in 2:
		var p := Vector2(rng.randf_range(20.0, w - 120.0), rng.randf_range(20.0, h - 20.0))
		var pts := PackedVector2Array([p])
		for j in 6:
			pts.append(pts[j] + Vector2(rng.randf_range(14, 26), rng.randf_range(-10, 10)))
		Art.line_c(ci, pts, Color(VEIN, 0.18), 9.0)
		Art.line_c(ci, pts, Color(VEIN, 0.55), 3.5)
		Art.line_c(ci, pts, Color("e8ffff"), 1.3)
	# Barnacle clusters.
	for k in 3:
		barnacles(ci, Vector2(rng.randf_range(10.0, w - 10.0), rng.randf_range(30.0, h - 16.0)), rng.randi_range(3, 5), rng.randi())
	# Coral crust along the top of the layer.
	for k in 5:
		coral_tuft(ci, Vector2(rng.randf_range(0.0, w), 9.0), CORAL[(k + index) % CORAL.size()], rng.randf_range(0.7, 1.15), rng.randi() % 3)
	# Bioluminescent specks.
	for k in 8:
		var p := Vector2(rng.randf_range(0.0, w), rng.randf_range(12.0, h - 6.0))
		Art.disc(ci, p, rng.randf_range(1.0, 2.0), Color(CORAL[k % CORAL.size()].lightened(0.4), 0.6))
	# The layer's top lip, darker where it meets the hall above.
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 6), Vector2(0, 6)]), Color(Art.SHADE, 0.55))


## One rounded boulder: body, a lit cap, a shaded foot, a soft outline.
static func boulder(ci: CanvasItem, c: Vector2, r: Vector2, tone: Color) -> void:
	var body := Art.ellipse_pts(c, r, 14)
	Art.flat(ci, body, tone)
	var cap := Art.clipped(Art.ellipse_pts(c + Vector2(-r.x * 0.12, -r.y * 0.45), Vector2(r.x * 0.8, r.y * 0.6), 12), body)
	if cap.size() >= 3:
		Art.flat(ci, cap, tone.lightened(0.13))
	var foot := Art.clipped(Art.ellipse_pts(c + Vector2(r.x * 0.1, r.y * 0.62), Vector2(r.x * 0.95, r.y * 0.5), 12), body)
	if foot.size() >= 3:
		Art.flat(ci, foot, Art.shade_of(tone, 0.22))


static func barnacles(ci: CanvasItem, at: Vector2, n: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var p := at + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-6.0, 6.0))
		var r := rng.randf_range(3.5, 6.0)
		Art.toon(ci, PackedVector2Array([p + Vector2(-r, r * 0.6), p + Vector2(-r * 0.5, -r * 0.7), p + Vector2(r * 0.5, -r * 0.7), p + Vector2(r, r * 0.6)]), Color("cfc6e6"), 1.4, 0.4)
		Art.flat(ci, Art.ellipse_pts(p + Vector2(0, -r * 0.55), Vector2(r * 0.42, r * 0.2), 8), Color("2a2050"))


## A small branching coral (kind 0: fan, 1: finger, 2: anemone).
static func coral_tuft(ci: CanvasItem, at: Vector2, color: Color, k: float, kind: int) -> void:
	Art.push(ci, at, 0.0, Vector2(k, k))
	match kind:
		0:
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, 2), Vector2(-16, -10), Vector2(-6, -18), Vector2(6, -18), Vector2(16, -10), Vector2(14, 2)]), 3), color, 2.0, 0.5)
			for x in [-8.0, 0.0, 8.0]:
				Art.line(ci, Vector2(0, 2), Vector2(x, -14), Color(color.darkened(0.3), 0.8), 1.5)
		1:
			for b in [[-8.0, -14.0, -0.3], [0.0, -20.0, 0.0], [8.0, -12.0, 0.35]]:
				Art.push(ci, Vector2(b[0], 2), b[2])
				Art.toon(ci, Art.rrect_pts(Rect2(-3.5, b[1], 7, -b[1]), 3.5), color, 1.8, 0.5)
				Art.disc(ci, Vector2(0, b[1] + 3), 2.2, color.lightened(0.45))
				Art.pop(ci)
		_:
			Art.toon(ci, Art.ellipse_pts(Vector2(0, -3), Vector2(9, 5), 14), color.darkened(0.15), 1.8, 0.4)
			for i in 6:
				var a := -PI + 0.35 + i * (PI - 0.7) / 5.0
				Art.line(ci, Vector2(0, -6), Vector2(cos(a), sin(a)) * 13.0 + Vector2(0, -6), color.lightened(0.2), 2.4)
	Art.pop(ci)


## Deep water in a hall: lighter under the ceiling, dark at the floor,
## coral arches far behind, god rays and caustics from above.
static func hall(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, inner: Color, glow: Color, index: int, ledge_y: float) -> void:
	var hi := inner.lightened(0.22)
	var lo := inner.darkened(0.35)
	var g := PackedVector2Array([cave.position + Vector2(-10, -10), Vector2(cave.end.x + 10, cave.position.y - 10), cave.end + Vector2(10, 10), Vector2(cave.position.x - 10, cave.end.y + 10)])
	var gc := Art.clipped(g, cp)
	if gc.size() >= 3:
		# grad() needs a quad: clip in bands instead (three steps).
		for i in 3:
			var y0 := lerpf(cave.position.y - 10, cave.end.y + 10, i / 3.0)
			var y1 := lerpf(cave.position.y - 10, cave.end.y + 10, (i + 1) / 3.0)
			var band := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 10, y0), Vector2(cave.end.x + 10, y0), Vector2(cave.end.x + 10, y1), Vector2(cave.position.x - 10, y1)]), cp)
			if band.size() >= 3:
				Art.flat(ci, band, hi.lerp(lo, (i + 0.5) / 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 61 + 13
	# Far coral arches and spires, two depths.
	for layer in 2:
		var col := Color(inner.darkened(0.3 + 0.15 * layer), 0.55 + 0.25 * layer)
		var x := cave.position.x + rng.randf_range(20.0, 80.0)
		while x < cave.end.x:
			var hgt := rng.randf_range(50.0, 110.0) * (0.75 + 0.25 * layer)
			var wd := rng.randf_range(30.0, 56.0)
			var spire := PackedVector2Array([Vector2(x - wd, ledge_y + 6), Vector2(x - wd * 0.5, ledge_y - hgt * 0.55), Vector2(x - wd * 0.2, ledge_y - hgt),
				Vector2(x + wd * 0.15, ledge_y - hgt * 0.8), Vector2(x + wd * 0.5, ledge_y - hgt * 0.45), Vector2(x + wd, ledge_y + 6)])
			var sc := Art.clipped(Art.smooth_pts(spire, 3), cp)
			if sc.size() >= 3:
				Art.flat(ci, sc, col)
			x += rng.randf_range(90.0, 150.0)
	# God rays.
	for i in 3:
		var x := cave.position.x + cave.size.x * (0.18 + 0.28 * i) + (index % 3) * 16.0
		var w := 26.0 + 16.0 * ((i + index) % 2)
		var ray := PackedVector2Array([Vector2(x, cave.position.y - 4), Vector2(x + w, cave.position.y - 4),
			Vector2(x + w + 60.0, cave.end.y), Vector2(x + 34.0, cave.end.y)])
		var rc := Art.clipped(ray, cp)
		if rc.size() >= 3:
			Art.flat(ci, rc, Color(glow.lightened(0.5), 0.08))
		var core := PackedVector2Array([Vector2(x + w * 0.3, cave.position.y - 4), Vector2(x + w * 0.7, cave.position.y - 4),
			Vector2(x + w * 0.7 + 40.0, cave.position.y + cave.size.y * 0.7), Vector2(x + w * 0.3 + 26.0, cave.position.y + cave.size.y * 0.7)])
		var cc := Art.clipped(core, cp)
		if cc.size() >= 3:
			Art.flat(ci, cc, Color(1, 1, 1, 0.06))
	# Caustics: a loose net of light lines under the ceiling.
	for k in 5:
		var y := cave.position.y + 14.0 + k * 9.0
		var pts := PackedVector2Array()
		var x := cave.position.x + 20.0
		while x < cave.end.x - 10.0:
			pts.append(Vector2(x, y + sin(x * 0.05 + k * 1.7 + index) * 5.0))
			x += 18.0
		if pts.size() >= 2:
			Art.line_c(ci, pts, Color(1, 1, 1, 0.09 - k * 0.012), 2.0)


## The hall's floor: dark sand with a lit lip, shells, glowing pebbles.
static func floor(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, sand: Color, glow: Color, index: int, ledge_y: float, bottom: float, left: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 83 + 41
	var lip := PackedVector2Array([Vector2(left, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y + 7), Vector2(left, ledge_y + 7)])
	var lc := Art.clipped(lip, cp)
	if lc.size() >= 3:
		Art.flat(ci, lc, Color(sand.lightened(0.25), 0.7))
	var foot := PackedVector2Array([Vector2(left, bottom - 16), Vector2(cave.end.x + 10, bottom - 16), Vector2(cave.end.x + 10, bottom + 10), Vector2(left, bottom + 10)])
	var fc := Art.clipped(foot, cp)
	if fc.size() >= 3:
		Art.flat(ci, fc, Color(Art.SHADE, 0.35))
	for i in 6:
		var c := Vector2(rng.randf_range(cave.position.x + 60, cave.end.x - 40), rng.randf_range(ledge_y + 10, bottom - 12))
		var wd := rng.randf_range(16, 30)
		Art.line_c(ci, PackedVector2Array([c + Vector2(-wd, 2), c + Vector2(-wd * 0.4, -2), c + Vector2(wd * 0.2, 1), c + Vector2(wd, -1)]), Color(Art.shade_of(sand, 0.3), 0.6), 2.0)
	# Shells.
	for i in 2:
		var p := Vector2(rng.randf_range(cave.position.x + 80, cave.end.x - 60), rng.randf_range(ledge_y + 12, bottom - 14))
		Art.push(ci, p, rng.randf_range(-0.5, 0.5), Vector2(0.7, 0.7))
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-10, 4), Vector2(-11, -4), Vector2(0, -11), Vector2(11, -4), Vector2(10, 4)]), 3), Color("f6c6e0"), 2.0, 0.5)
		for x in [-5.0, 0.0, 5.0]:
			Art.line(ci, Vector2(0, 4), Vector2(x, -7), Color("c78ab0"), 1.4)
		Art.pop(ci)
	# Glowing pebbles.
	for i in 5:
		var p := Vector2(rng.randf_range(cave.position.x + 40, cave.end.x - 30), rng.randf_range(ledge_y + 8, bottom - 8))
		var col := glow if i % 2 == 0 else CORAL[i % CORAL.size()]
		Art.glow(ci, p, 10.0, Color(col, 0.35), 10)
		Art.disc(ci, p, rng.randf_range(2.0, 3.2), col.lightened(0.3))


## The mine frame: two whale ribs arching over the entrance, a driftwood
## beam, barnacles and a glowing jar hanging from it. (0, 0) = left foot.
static func rib_portal(ci: CanvasItem, h: float, w: float) -> void:
	for s: float in [0.0, 1.0]:
		var x0 := w * s
		var dir := 1.0 if s == 0.0 else -1.0
		var rib := PackedVector2Array([Vector2(x0 - dir * 6, 0), Vector2(x0 - dir * 10, -h * 0.4), Vector2(x0 - dir * 4, -h * 0.8), Vector2(x0 + dir * 12, -h - 4)])
		var smooth := Art.smooth_pts(PackedVector2Array([rib[0], rib[1], rib[2], rib[3], rib[3] + Vector2(dir * 8, 4), rib[2] + Vector2(dir * 10, 0), rib[1] + Vector2(dir * 8, 0), rib[0] + Vector2(dir * 10, 0)]), 2)
		Art.toon(ci, smooth, BONE, 2.6, 0.6)
		barnacles(ci, Vector2(x0 + dir * 2, -h * 0.35), 3, int(s) + 7)
	Art.t_rect(ci, Rect2(-16, -h - 12, w + 32, 14), 4.0, Color("6a4a5a"), 2.8, 0.5)
	for k in 3:
		var x := -6.0 + k * (w + 12.0) / 2.0
		Art.line(ci, Vector2(x, -h - 10), Vector2(x + 14, -h), Color("4a3040"), 1.6)
	# The jar of glowing plankton.
	var j := Vector2(w * 0.5, -h + 18)
	Art.line(ci, Vector2(j.x, -h - 2), j + Vector2(0, -12), Art.INK, 2.0)
	Art.glow(ci, j, 26.0, Color(VEIN, 0.4), 14)
	Art.t_rect(ci, Rect2(j.x - 8, j.y - 12, 16, 22), 5.0, Color("9afcff"), 2.2, 0.3)
	Art.t_rect(ci, Rect2(j.x - 9, j.y - 15, 18, 5), 2.0, BRASS, 2.0, 0.0)


## The brace across the lift shaft: a brass pipe with rivets and a lamp.
static func shaft_brace(ci: CanvasItem, l: float, r: float) -> void:
	Art.t_rect(ci, Rect2(l, 7, r - l, 11), 5.5, BRASS, 2.4, 0.6)
	for x in [l + 8.0, (l + r) / 2.0, r - 8.0]:
		Art.t_circle(ci, Vector2(x, 12.5), 3.0, Color("f2d27a"), 1.6, 0.0)
	Art.glow(ci, Vector2(r - 2, 24), 14.0, Color(VEIN, 0.45), 10)
	Art.t_circle(ci, Vector2(r - 2, 24), 4.5, Color("9afcff"), 1.8, 0.0)
