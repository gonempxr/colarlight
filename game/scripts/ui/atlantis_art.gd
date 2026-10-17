class_name AtlantisArt
extends RefCounted
## Atlantis' mine (the saga, act II), like ReefArt for the Twilight Zone:
## walls of white marble blocks with gold seams and blue orichalcum veins,
## broken columns sunk in the stone; halls of clear blue water with a far
## colonnade, golden god rays and caustics; mosaic floors; marble arches
## with gold capitals as mine frames; bronze shaft braces with a cog. All
## still shapes (DepthRow's background layer), plus the sites' decor.

const MARBLE := Color("f2ecdf")
const MARBLE_DARK := Color("c9bfa8")
const GOLD := Color("ffc93c")
const BRONZE := Color("c7843a")
const BRONZE_DARK := Color("8a5424")
const ORICHALCUM := Color("4af0e0")
const MOSAIC: Array[Color] = [Color("2a8ed8"), Color("ffc93c"), Color("f2ecdf"), Color("4af0e0"), Color("e0603c")]


## Masonry around a hall: `rock` is the site's color (marble turning
## blue-grey deeper down), `index` seeds the layout.
static func rock(ci: CanvasItem, w: float, h: float, rock_c: Color, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 157 + 11
	var top := rock_c.lightened(0.05)
	var low := rock_c.darkened(0.22)
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, low, low]))
	# Ashlar: courses of cut blocks, each lit on top and shaded below.
	var y := 6.0
	var row := 0
	while y < h:
		var bh := 38.0 + (row % 2) * 6.0
		var x := -(row % 2) * 46.0 - rng.randf_range(0.0, 20.0)
		while x < w:
			var bw := rng.randf_range(74.0, 112.0)
			var depth := clampf((y + bh / 2.0) / h, 0.0, 1.0)
			var tone := rock_c.lerp(low, depth * 0.5).lightened(rng.randf_range(-0.03, 0.05))
			var r := Rect2(x + 2.0, y + 2.0, bw - 4.0, bh - 4.0)
			Art.flat(ci, Art.rrect_pts(r, 3.0), tone)
			Art.flat(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + 5), Vector2(r.position.x, r.position.y + 5)]), tone.lightened(0.12))
			Art.flat(ci, PackedVector2Array([Vector2(r.position.x, r.end.y - 5), Vector2(r.end.x, r.end.y - 5), r.end, Vector2(r.position.x, r.end.y)]), Art.shade_of(tone, 0.18))
			# A carved meander on some blocks.
			if rng.randf() < 0.18:
				_meander(ci, Rect2(r.position.x + 10, r.position.y + bh * 0.35, r.size.x - 20, 10), Color(Art.shade_of(tone, 0.25), 0.8))
			x += bw
		# Gold seam under the course.
		Art.flat(ci, PackedVector2Array([Vector2(0, y + bh - 2.0), Vector2(w, y + bh - 2.0), Vector2(w, y + bh), Vector2(0, y + bh)]), Color(GOLD, 0.45))
		y += bh
		row += 1
	# Orichalcum veins through the stone.
	for k in 2:
		var p := Vector2(rng.randf_range(20.0, w - 140.0), rng.randf_range(24.0, h - 24.0))
		var pts := PackedVector2Array([p])
		for j in 6:
			pts.append(pts[j] + Vector2(rng.randf_range(14, 26), rng.randf_range(-9, 9)))
		Art.line_c(ci, pts, Color(ORICHALCUM, 0.18), 9.0)
		Art.line_c(ci, pts, Color(ORICHALCUM, 0.6), 3.2)
		Art.line_c(ci, pts, Color("e8ffff"), 1.2)
	# A broken column sunk into the wall.
	var cx := rng.randf_range(w * 0.15, w * 0.85)
	column(ci, Vector2(cx, h - 4.0), rng.randf_range(54.0, 80.0), 13.0, rock_c.lightened(0.08), true)
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 6), Vector2(0, 6)]), Color(Art.SHADE, 0.45))


## A Greek key band in a rectangle.
static func _meander(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var x := r.position.x
	var pts := PackedVector2Array()
	while x + 12.0 < r.end.x:
		pts.append_array(PackedVector2Array([Vector2(x, r.end.y), Vector2(x, r.position.y), Vector2(x + 8, r.position.y),
			Vector2(x + 8, r.end.y - 4), Vector2(x + 4, r.end.y - 4)]))
		x += 12.0
	if pts.size() >= 2:
		Art.line_c(ci, pts, col, 1.6)


## A fluted column standing on `foot` (`broken`: a jagged top, no capital).
static func column(ci: CanvasItem, foot: Vector2, hgt: float, half: float, col: Color, broken: bool = false) -> void:
	var t := foot.y - hgt
	Art.t_rect(ci, Rect2(foot.x - half - 5, foot.y - 8, half * 2 + 10, 8), 2.0, col.darkened(0.08), 2.0, 0.0)
	var shaft := PackedVector2Array([Vector2(foot.x - half, foot.y - 8), Vector2(foot.x - half + 1, t + 6), Vector2(foot.x + half - 1, t + 6), Vector2(foot.x + half, foot.y - 8)])
	if broken:
		shaft = PackedVector2Array([Vector2(foot.x - half, foot.y - 8), Vector2(foot.x - half + 1, t + 10), Vector2(foot.x - half * 0.3, t),
			Vector2(foot.x + half * 0.2, t + 9), Vector2(foot.x + half - 1, t + 3), Vector2(foot.x + half, foot.y - 8)])
	Art.toon(ci, shaft, col, 2.2, 0.5)
	for k in 3:
		var fx := foot.x - half * 0.55 + k * half * 0.55
		Art.line(ci, Vector2(fx, foot.y - 10), Vector2(fx, t + (14.0 if broken else 8.0)), Color(Art.shade_of(col, 0.22), 0.8), 1.6)
	if not broken:
		Art.t_rect(ci, Rect2(foot.x - half - 6, t - 2, half * 2 + 12, 9), 2.0, GOLD, 2.2, 0.3)
		Art.t_circle(ci, Vector2(foot.x - half - 4, t + 5), 4.0, GOLD, 1.6, 0.0)
		Art.t_circle(ci, Vector2(foot.x + half + 4, t + 5), 4.0, GOLD, 1.6, 0.0)


## Clear blue water in a hall: light under the ceiling, a far colonnade
## with a dome, golden god rays and caustics.
static func hall(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, inner: Color, glow: Color, index: int, ledge_y: float) -> void:
	var hi := inner.lightened(0.25)
	var lo := inner.darkened(0.3)
	for i in 3:
		var y0 := lerpf(cave.position.y - 10, cave.end.y + 10, i / 3.0)
		var y1 := lerpf(cave.position.y - 10, cave.end.y + 10, (i + 1) / 3.0)
		var band := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 10, y0), Vector2(cave.end.x + 10, y0), Vector2(cave.end.x + 10, y1), Vector2(cave.position.x - 10, y1)]), cp)
		if band.size() >= 3:
			Art.flat(ci, band, hi.lerp(lo, (i + 0.5) / 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 59 + 7
	# The far city: a colonnade and, sometimes, a dome.
	var far := Color(inner.lightened(0.12), 0.55)
	var base := ledge_y + 4.0
	var x := cave.position.x + rng.randf_range(30.0, 70.0)
	var roof_l := x
	while x < cave.end.x - 30.0:
		var cr := Art.clipped(PackedVector2Array([Vector2(x - 5, base), Vector2(x - 5, base - 78), Vector2(x + 5, base - 78), Vector2(x + 5, base)]), cp)
		if cr.size() >= 3:
			Art.flat(ci, cr, far)
		x += 34.0
	var roof := Art.clipped(PackedVector2Array([Vector2(roof_l - 12, base - 78), Vector2(x - 22, base - 78), Vector2(x - 22, base - 88), Vector2((roof_l + x) / 2.0, base - 110), Vector2(roof_l - 12, base - 88)]), cp)
	if roof.size() >= 3:
		Art.flat(ci, roof, far)
	if index % 2 == 1:
		var dc := Vector2(cave.position.x + cave.size.x * 0.7, base - 96)
		var dome := Art.clipped(Art.ellipse_pts(dc, Vector2(46, 40), 20), cp)
		if dome.size() >= 3:
			Art.flat(ci, dome, Color(glow.lerp(inner, 0.5), 0.35))
	# Golden god rays.
	for i in 3:
		var rx := cave.position.x + cave.size.x * (0.16 + 0.3 * i) + (index % 3) * 14.0
		var rw := 24.0 + 14.0 * ((i + index) % 2)
		var ray := Art.clipped(PackedVector2Array([Vector2(rx, cave.position.y - 4), Vector2(rx + rw, cave.position.y - 4),
			Vector2(rx + rw + 56.0, cave.end.y), Vector2(rx + 30.0, cave.end.y)]), cp)
		if ray.size() >= 3:
			Art.flat(ci, ray, Color(1.0, 0.9, 0.55, 0.09))
	for k in 5:
		var y := cave.position.y + 14.0 + k * 9.0
		var pts := PackedVector2Array()
		var cx := cave.position.x + 20.0
		while cx < cave.end.x - 10.0:
			pts.append(Vector2(cx, y + sin(cx * 0.05 + k * 1.7 + index) * 5.0))
			cx += 18.0
		if pts.size() >= 2:
			Art.line_c(ci, pts, Color(1, 1, 1, 0.1 - k * 0.014), 2.0)


## A mosaic floor: a lit lip, a band of colored tiles, a gold border.
static func floor(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, sand: Color, glow: Color, index: int, ledge_y: float, bottom: float, left: float) -> void:
	var lip := Art.clipped(PackedVector2Array([Vector2(left, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y + 6), Vector2(left, ledge_y + 6)]), cp)
	if lip.size() >= 3:
		Art.flat(ci, lip, Color(MARBLE, 0.85))
	var gold := Art.clipped(PackedVector2Array([Vector2(left, ledge_y + 6), Vector2(cave.end.x + 10, ledge_y + 6), Vector2(cave.end.x + 10, ledge_y + 9), Vector2(left, ledge_y + 9)]), cp)
	if gold.size() >= 3:
		Art.flat(ci, gold, GOLD)
	# Tiles: a checker of small squares in the mosaic colors.
	var y := ledge_y + 13.0
	var r := 0
	while y < bottom - 10.0:
		var x := left + 24.0 + (r % 2) * 9.0
		while x < cave.end.x:
			var c: Color = MOSAIC[(int(x / 18.0) + r * 2 + index) % MOSAIC.size()]
			var tile := Art.clipped(PackedVector2Array([Vector2(x, y), Vector2(x + 14, y), Vector2(x + 14, y + 9), Vector2(x, y + 9)]), cp)
			if tile.size() >= 3:
				Art.flat(ci, tile, Color(c.lerp(sand, 0.45), 0.85))
			x += 18.0
		y += 12.0
		r += 1
	var foot := Art.clipped(PackedVector2Array([Vector2(left, bottom - 12), Vector2(cave.end.x + 10, bottom - 12), Vector2(cave.end.x + 10, bottom + 10), Vector2(left, bottom + 10)]), cp)
	if foot.size() >= 3:
		Art.flat(ci, foot, Color(Art.SHADE, 0.3))
	Art.glow(ci, Vector2(cave.end.x - 70, ledge_y + 18), 18.0, Color(glow, 0.3), 10)


## The mine frame: two marble columns with gold capitals under a carved
## lintel with a sun disc. (0, 0) = left foot.
static func arch_portal(ci: CanvasItem, h: float, w: float) -> void:
	for x: float in [0.0, w]:
		column(ci, Vector2(x, 0), h, 8.0, MARBLE)
	Art.t_rect(ci, Rect2(-18, -h - 18, w + 36, 16), 3.0, MARBLE, 2.8, 0.5)
	_meander(ci, Rect2(-12, -h - 14, w + 24, 8), Color(MARBLE_DARK, 0.9))
	var c := Vector2(w * 0.5, -h - 22)
	Art.toon(ci, PackedVector2Array([c + Vector2(-26, 4), c + Vector2(0, -16), c + Vector2(26, 4)]), MARBLE, 2.4, 0.4)
	Art.glow(ci, c + Vector2(0, -3), 14.0, Color(ORICHALCUM, 0.45), 10)
	Art.t_circle(ci, c + Vector2(0, -3), 5.0, GOLD, 1.8, 0.0)


## The brace across the lift shaft: a bronze beam with a turning cog.
static func shaft_brace(ci: CanvasItem, l: float, r: float) -> void:
	Art.t_rect(ci, Rect2(l, 7, r - l, 11), 3.0, BRONZE, 2.4, 0.5)
	for x in [l + 8.0, (l + r) / 2.0, r - 8.0]:
		Art.t_circle(ci, Vector2(x, 12.5), 2.8, GOLD, 1.4, 0.0)
	cog(ci, Vector2(r - 4, 26), 9.0, 8, BRONZE)
	Art.glow(ci, Vector2(r - 4, 26), 12.0, Color(ORICHALCUM, 0.35), 10)


## A bronze cog with `teeth` around a gold hub.
static func cog(ci: CanvasItem, c: Vector2, r: float, teeth: int, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var a := rot + TAU * (i / float(teeth * 2))
		var rr := r if i % 2 == 0 else r * 0.78
		pts.append(c + Vector2(cos(a - 0.12), sin(a - 0.12)) * rr)
		pts.append(c + Vector2(cos(a + 0.12), sin(a + 0.12)) * rr)
	Art.toon(ci, pts, col, 2.0, 0.4)
	Art.t_circle(ci, c, r * 0.36, GOLD, 1.6, 0.0)


## Atlantis' cave decor ("at_*" decos). Returns false for other decos.
static func decor(ci: CanvasItem, st: Dictionary, x0: float, x1: float, mid: float, y: float, top: float, t: float, index: int) -> bool:
	var deco := str(st["deco"])
	if not deco.begins_with("at_"):
		return false
	var ore: Color = st["ore"]
	var ore2: Color = st["ore2"]
	var glow: Color = st.get("glow", ore)
	var turn := snappedf(t * 0.6, 0.1)
	match deco:
		"at_columns":
			# A row of standing and fallen columns.
			column(ci, Vector2(x0, y + 4), 96.0, 11.0, MARBLE)
			column(ci, Vector2(x1 + 10, y + 4), 70.0, 11.0, MARBLE, true)
			Art.push(ci, Vector2(mid + 20, y - 4), -0.08)
			Art.toon(ci, Art.rrect_pts(Rect2(-46, -10, 92, 20), 8.0), MARBLE.darkened(0.05), 2.2, 0.5)
			for k in 3:
				Art.line(ci, Vector2(-40, -4 + k * 4), Vector2(40, -4 + k * 4), Color(MARBLE_DARK, 0.8), 1.4)
			Art.pop(ci)
		"at_mosaic":
			# A broken mosaic panel leaning on the wall, tiles scattered.
			var p := Vector2(x0 + 10, y + 2)
			Art.t_rect(ci, Rect2(p.x - 34, p.y - 64, 68, 62), 3.0, MARBLE, 2.4, 0.4)
			for i in 4:
				for j in 4:
					Art.flat(ci, Art.rrect_pts(Rect2(p.x - 28 + i * 14, p.y - 58 + j * 14, 12, 12), 1.5), MOSAIC[(i + j * 2) % MOSAIC.size()])
			for k in 5:
				var q := Vector2(lerpf(mid - 40, x1, k / 4.0), y + 2 - (k % 2) * 3)
				Art.flat(ci, Art.rrect_pts(Rect2(q.x - 4, q.y - 8, 8, 8), 1.5), MOSAIC[k % MOSAIC.size()])
		"at_gears":
			# Brass machines still turning in the dark.
			cog(ci, Vector2(x0 + 4, y - 40), 26.0, 12, BRONZE, turn)
			cog(ci, Vector2(x0 + 40, y - 22), 16.0, 9, BRONZE_DARK.lightened(0.2), -turn * 1.6)
			cog(ci, Vector2(x1 + 6, y - 30), 20.0, 10, BRONZE, -turn * 1.2)
			Art.glow(ci, Vector2(x0 + 4, y - 40), 18.0, Color(ORICHALCUM, 0.3), 10)
		"at_amphoras":
			for p: Vector3 in [Vector3(x0, y + 4, 0.0), Vector3(x0 + 34, y + 4, 0.25), Vector3(x1 + 10, y + 4, -0.15)]:
				Art.push(ci, Vector2(p.x, p.y), p.z, Vector2(1.2, 1.2))
				amphora(ci, ore, ore2)
				Art.pop(ci)
		"at_statue":
			# A fallen statue's head, half buried, gold laurel on it.
			var c := Vector2(x0 + 14, y - 22)
			Art.toon(ci, Art.ellipse_pts(c, Vector2(30, 26), 18, -0.2), MARBLE, 2.6, 0.5)
			Art.line(ci, c + Vector2(-12, -2), c + Vector2(-4, -2), Art.INK, 2.4)
			Art.line(ci, c + Vector2(4, -4), c + Vector2(12, -4), Art.INK, 2.4)
			Art.line_c(ci, PackedVector2Array([c + Vector2(-6, 12), c + Vector2(0, 14), c + Vector2(6, 12)]), Art.INK, 2.0)
			for k in 5:
				Art.t_ellipse(ci, c + Vector2(-24 + k * 12, -22 + absf(k - 2) * 4), Vector2(6, 3), GOLD, 1.4, 0.0, 0.6 - k * 0.3)
			Art.toon(ci, PackedVector2Array([Vector2(x1 - 20, y + 4), Vector2(x1 - 8, y - 18), Vector2(x1 + 30, y - 16), Vector2(x1 + 40, y + 4)]), MARBLE.darkened(0.06), 2.2, 0.4)
		"at_harp":
			# A golden harp humming with the siren's song.
			var c := Vector2(x0 + 10, y + 2)
			Art.glow(ci, c + Vector2(0, -40), 34.0, Color(glow, 0.35), 12)
			Art.polyline(ci, Art.smooth_pts(PackedVector2Array([c, c + Vector2(-20, -30), c + Vector2(-14, -66), c + Vector2(14, -70)]), 3), GOLD, 6.0)
			Art.line(ci, c, c + Vector2(16, -70), GOLD.darkened(0.15), 5.0)
			for k in 5:
				var fx := -12.0 + k * 6.0
				Art.line(ci, c + Vector2(fx * 0.6, -6 - k), c + Vector2(fx + 4, -60 - k * 2), Color(ore2, 0.9), 1.4)
			var nb := snappedf(sin(t * 2.0) * 4.0, 1.0)
			for k in 2:
				Art.dot(ci, c + Vector2(30 + k * 18, -50 - k * 14 + nb), 3.0, Color(glow, 0.8))
		"at_trident":
			# A great trident stuck in the floor, orichalcum on its prongs.
			var c := Vector2(x1, y + 4)
			Art.t_rect(ci, Rect2(c.x - 4, c.y - 110, 8, 110), 2.0, GOLD, 2.0, 0.4)
			for dx: float in [-18.0, 0.0, 18.0]:
				var tip := c + Vector2(dx, -150 if dx == 0.0 else -136)
				Art.toon(ci, PackedVector2Array([c + Vector2(dx - 4, -112), tip + Vector2(-4, 12), tip, tip + Vector2(4, 12), c + Vector2(dx + 4, -112)]), GOLD, 2.0, 0.4)
				Art.glow(ci, tip + Vector2(0, 8), 10.0, Color(ORICHALCUM, 0.45), 8)
			Art.t_rect(ci, Rect2(c.x - 24, c.y - 116, 48, 8), 3.0, GOLD.darkened(0.1), 2.0, 0.3)
		"at_seals":
			# A throne step with royal seals and the king's lost crown.
			Art.t_rect(ci, Rect2(x0 - 30, y - 22, 120, 26), 3.0, MARBLE, 2.4, 0.4)
			Art.t_rect(ci, Rect2(x0 - 16, y - 42, 92, 22), 3.0, MARBLE.darkened(0.04), 2.4, 0.4)
			var cr := Vector2(x0 + 30, y - 46)
			Art.toon(ci, PackedVector2Array([cr + Vector2(-16, 0), cr + Vector2(-18, -16), cr + Vector2(-8, -8), cr + Vector2(0, -20), cr + Vector2(8, -8), cr + Vector2(18, -16), cr + Vector2(16, 0)]), GOLD, 2.2, 0.5)
			Art.t_circle(ci, cr + Vector2(0, -6), 3.0, ORICHALCUM, 1.2, 0.0)
		"at_stars":
			# A bronze star chart (an orrery) turning slowly.
			var c := Vector2(mid, top + 70)
			Art.line(ci, Vector2(c.x, top), c, BRONZE_DARK, 3.0)
			Art.arc(ci, c, 34.0, 0.0, TAU, 24, Color(BRONZE, 0.9), 2.4)
			Art.arc(ci, c, 20.0, 0.0, TAU, 18, Color(GOLD, 0.9), 2.0)
			Art.t_circle(ci, c, 8.0, GOLD, 2.0, 0.3)
			Art.t_circle(ci, c + Vector2(cos(turn), sin(turn)) * 34.0, 5.0, ORICHALCUM, 1.6, 0.0)
			Art.t_circle(ci, c + Vector2(cos(-turn * 1.7), sin(-turn * 1.7)) * 20.0, 4.0, Color("e0603c"), 1.4, 0.0)
		_:
			return false
	return true


## A two-handled amphora standing on (0, 0), about 40 px tall.
static func amphora(ci: CanvasItem, c: Color, c2: Color) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-4, 0), Vector2(-14, -10), Vector2(-15, -24), Vector2(-7, -34),
		Vector2(-5, -42), Vector2(5, -42), Vector2(7, -34), Vector2(15, -24), Vector2(14, -10), Vector2(4, 0)]), 3)
	for s: float in [-1.0, 1.0]:
		Art.polyline(ci, PackedVector2Array([Vector2(5 * s, -38), Vector2(14 * s, -38), Vector2(12 * s, -28)]), Art.INK, 3.6)
		Art.polyline(ci, PackedVector2Array([Vector2(5 * s, -38), Vector2(14 * s, -38), Vector2(12 * s, -28)]), c.darkened(0.1), 2.0)
	Art.toon(ci, body, c, 2.2, 0.6)
	Art.flat(ci, PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2(13, -16), Vector2(-13, -16)]), c2)
	Art.t_rect(ci, Rect2(-7, -46, 14, 5), 1.5, c.darkened(0.1), 1.6, 0.0)


## Atlantis' own ores (OreArt): pieces about 40 px tall standing on (0, 0).
static func ore_piece(ci: CanvasItem, kind: String, c: Color, c2: Color, t: float, i: int) -> void:
	var pulse := snappedf(0.5 + 0.5 * sin(t * 2.2 + i * 1.3), 0.25)
	match kind:
		"mosaic_tile":
			# A slab of mosaic: four colored tiles in a marble frame.
			Art.push(ci, Vector2(0, -16), -0.15 + (i % 3) * 0.15)
			Art.t_rect(ci, Rect2(-18, -16, 36, 32), 3.0, MARBLE, 2.4, 0.5)
			for k in 4:
				Art.flat(ci, Art.rrect_pts(Rect2(-14 + (k % 2) * 15, -12 + (k / 2) * 14, 13, 12), 1.5), c if (k + i) % 2 == 0 else c2)
			Art.pop(ci)
		"bronze_gear":
			cog(ci, Vector2(0, -18), 18.0, 10, c, i * 0.3)
			Art.t_circle(ci, Vector2(0, -18), 4.0, c2, 1.4, 0.0)
		"amphora":
			amphora(ci, c, c2)
		"trident_shard":
			Art.glow(ci, Vector2(0, -22), 22.0, Color(c2, 0.3 + 0.2 * pulse))
			Art.t_rect(ci, Rect2(-3, -20, 6, 20), 1.5, c, 2.0, 0.4)
			for dx: float in [-10.0, 0.0, 10.0]:
				var tip := Vector2(dx, -44 if dx == 0.0 else -36)
				Art.toon(ci, PackedVector2Array([Vector2(dx - 3, -18), tip + Vector2(-3, 8), tip, tip + Vector2(3, 8), Vector2(dx + 3, -18)]), c, 2.0, 0.5)
			Art.t_rect(ci, Rect2(-14, -22, 28, 6), 2.0, c.darkened(0.1), 1.8, 0.2)
			Art.t_circle(ci, Vector2(0, -19), 3.0, c2, 1.2, 0.0)
		"automaton_core":
			# A bronze sphere with a glowing orichalcum heart.
			Art.glow(ci, Vector2(0, -18), 24.0, Color(c2, 0.35 + 0.25 * pulse))
			Art.t_circle(ci, Vector2(0, -18), 17.0, c, 2.4, 0.6)
			for a in 4:
				var d := Vector2(cos(a * PI / 2.0 + 0.4), sin(a * PI / 2.0 + 0.4)) * 13.0
				Art.t_circle(ci, Vector2(0, -18) + d, 2.2, GOLD, 1.2, 0.0)
			Art.t_circle(ci, Vector2(0, -18), 7.0, c2, 1.8, 0.0)
			Art.disc(ci, Vector2(-2, -20), 2.4, Color(1, 1, 1, 0.85))
		"siren_harp":
			Art.glow(ci, Vector2(0, -22), 22.0, Color(c2, 0.3 + 0.2 * pulse))
			Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(-8, 0), Vector2(-14, -20), Vector2(-8, -40), Vector2(10, -40)]), 3), Art.INK, 6.0)
			Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(-8, 0), Vector2(-14, -20), Vector2(-8, -40), Vector2(10, -40)]), 3), c, 3.6)
			Art.line(ci, Vector2(-8, 0), Vector2(10, -40), c.darkened(0.15), 3.0)
			for k in 4:
				Art.line(ci, Vector2(-9 + k * 1.5, -6 - k * 4), Vector2(-6 + k * 4, -38), Color(c2, 0.9), 1.2)
		_:
			Art.crystal(ci, Vector2.ZERO, 40, 8, 0.0, c, 2.0)
