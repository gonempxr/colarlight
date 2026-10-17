class_name RlyehArt
extends RefCounted
## R'lyeh's mine (the saga, act III), like AtlantisArt for act II: walls of
## black-green cyclopean blocks set at wrong angles with slime seams and
## carved eyes; halls of murky green water with leaning far monoliths and a
## sick green glow from below; slick black floors; mine frames of two
## leaning monoliths with a glyph; stone braces with a tentacle. All still
## shapes (DepthRow's background layer), plus the sites' decor ("rl_*"),
## R'lyeh's own ores and puzzle pieces.

const STONE := Color("3a4642")
const STONE_DARK := Color("1e2624")
const SLIME := Color("7dff6a")
const FLAME := Color("3aff9a")
const VIOLET := Color("8a4cf0")
const BONE := Color("e8e0c8")
const STAR := Color("c8d0ff")


## Masonry: big tilted blocks (no line is level), slime in the seams, now
## and then a carved eye or a glyph.
static func rock(ci: CanvasItem, w: float, h: float, rock_c: Color, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 211 + 5
	var top := rock_c.lightened(0.04)
	var low := rock_c.darkened(0.3)
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, low, low]))
	var y := 4.0
	var row := 0
	while y < h:
		var bh := rng.randf_range(44.0, 62.0)
		var x := -rng.randf_range(10.0, 60.0)
		var skew := rng.randf_range(-9.0, 9.0)
		while x < w:
			var bw := rng.randf_range(90.0, 150.0)
			var tone := rock_c.lerp(low, clampf((y + bh / 2.0) / h, 0.0, 1.0) * 0.5).lightened(rng.randf_range(-0.04, 0.04))
			var a := Vector2(x + 3.0, y + 3.0 + skew)
			var b := Vector2(x + bw - 3.0, y + 3.0 - skew * 0.6)
			var c := Vector2(x + bw - 3.0 + rng.randf_range(-8.0, 8.0), y + bh - 3.0)
			var d := Vector2(x + 3.0 + rng.randf_range(-8.0, 8.0), y + bh - 3.0 + skew * 0.4)
			Art.flat(ci, PackedVector2Array([a, b, c, d]), tone)
			Art.flat(ci, PackedVector2Array([a, b, b + Vector2(0, 5), a + Vector2(0, 5)]), tone.lightened(0.1))
			var roll := rng.randf()
			var mid := (a + b + c + d) / 4.0
			if roll < 0.1:
				# A carved eye, shut.
				Art.flat(ci, Art.ellipse_pts(mid, Vector2(16, 7), 14), Art.shade_of(tone, 0.3))
				Art.line(ci, mid - Vector2(13, 0), mid + Vector2(13, 0), Color(SLIME, 0.45), 2.0)
			elif roll < 0.2:
				_glyph(ci, mid, 10.0, Color(Art.shade_of(tone, 0.3), 0.9), rng.randi())
			x += bw
		# Slime in the seam under the course.
		var seam := PackedVector2Array()
		for k in 9:
			seam.append(Vector2(lerpf(-10.0, w + 10.0, k / 8.0), y + bh - 1.0 + sin(k * 1.7 + index + row) * 3.0))
		Art.line_c(ci, seam, Color(SLIME, 0.16), 6.0)
		Art.line_c(ci, seam, Color(SLIME, 0.45), 2.0)
		y += bh
		row += 1
	# Drips of slime from a few seams.
	for k in 3:
		var p := Vector2(rng.randf_range(30.0, w - 30.0), rng.randf_range(30.0, h - 40.0))
		Art.flat(ci, PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(1.5, 18), p + Vector2(-1.5, 18)]), Color(SLIME, 0.4))
		Art.dot(ci, p + Vector2(0, 20), 2.4, Color(SLIME, 0.55))
	Art.flat(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 6), Vector2(0, 6)]), Color(Art.SHADE, 0.5))


## A small elder glyph: a ring with a crooked mark through it (seeded).
static func _glyph(ci: CanvasItem, c: Vector2, r: float, col: Color, seed: int) -> void:
	Art.arc(ci, c, r, 0.0, TAU, 14, col, 2.0)
	var a := float(seed % 7) * 0.9
	var p1 := c + Vector2(cos(a), sin(a)) * r * 1.3
	var p2 := c - Vector2(cos(a), sin(a)) * r * 1.3
	Art.polyline(ci, PackedVector2Array([p1, c + Vector2(r * 0.3, -r * 0.4), p2]), col, 2.0)
	Art.dot(ci, c + Vector2(-r * 0.3, r * 0.3), 1.8, col)


## A leaning monolith standing on `foot`.
static func monolith(ci: CanvasItem, foot: Vector2, hgt: float, half: float, lean: float, col: Color) -> void:
	var tip := foot + Vector2(lean * hgt, -hgt)
	Art.toon(ci, PackedVector2Array([foot + Vector2(-half, 0), tip + Vector2(-half * 0.8, 6), tip + Vector2(0, -4),
		tip + Vector2(half * 0.8, 8), foot + Vector2(half, 0)]), col, 2.6, 0.5)
	_glyph(ci, foot.lerp(tip, 0.55), half * 0.45, Color(SLIME, 0.7), int(foot.x))


## Murky green water: lighter under the ceiling, a green glow rising from
## below, far leaning monoliths and, in odd halls, a huge shut eye.
static func hall(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, inner: Color, glow: Color, index: int, ledge_y: float) -> void:
	var hi := inner.lightened(0.12)
	var lo := inner.darkened(0.35)
	for i in 3:
		var y0 := lerpf(cave.position.y - 10, cave.end.y + 10, i / 3.0)
		var y1 := lerpf(cave.position.y - 10, cave.end.y + 10, (i + 1) / 3.0)
		var band := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 10, y0), Vector2(cave.end.x + 10, y0), Vector2(cave.end.x + 10, y1), Vector2(cave.position.x - 10, y1)]), cp)
		if band.size() >= 3:
			Art.flat(ci, band, hi.lerp(lo, (i + 0.5) / 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 83 + 3
	var far := Color(inner.lightened(0.1), 0.6)
	var base := ledge_y + 4.0
	var x := cave.position.x + rng.randf_range(30.0, 60.0)
	while x < cave.end.x - 30.0:
		var hgt := rng.randf_range(60.0, 110.0)
		var lean := rng.randf_range(-0.2, 0.2)
		var m := Art.clipped(PackedVector2Array([Vector2(x - 12, base), Vector2(x - 8 + lean * hgt, base - hgt), Vector2(x + 8 + lean * hgt, base - hgt - 8), Vector2(x + 12, base)]), cp)
		if m.size() >= 3:
			Art.flat(ci, m, far)
		x += rng.randf_range(50.0, 80.0)
	if index % 2 == 1:
		var ec := Vector2(cave.position.x + cave.size.x * 0.62, cave.position.y + cave.size.y * 0.32)
		var lid := Art.clipped(Art.ellipse_pts(ec, Vector2(64, 22), 24), cp)
		if lid.size() >= 3:
			Art.flat(ci, lid, Color(glow.lerp(inner, 0.7), 0.35))
			Art.line(ci, ec - Vector2(56, 0), ec + Vector2(56, 0), Color(glow, 0.35), 3.0)
	# Green glow from below.
	var up := Art.clipped(PackedVector2Array([Vector2(cave.position.x - 10, ledge_y - 40),
		Vector2(cave.end.x + 10, ledge_y - 40), Vector2(cave.end.x + 10, cave.end.y + 10), Vector2(cave.position.x - 10, cave.end.y + 10)]), cp)
	if up.size() >= 3:
		Art.flat(ci, up, Color(glow, 0.07))
	Art.glow(ci, Vector2(cave.get_center().x, ledge_y), 90.0, Color(glow, 0.12), 12)


## A slick black floor with green puddles.
static func floor(ci: CanvasItem, cave: Rect2, cp: PackedVector2Array, sand: Color, glow: Color, index: int, ledge_y: float, bottom: float, left: float) -> void:
	var lip := Art.clipped(PackedVector2Array([Vector2(left, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y - 2), Vector2(cave.end.x + 10, ledge_y + 5), Vector2(left, ledge_y + 5)]), cp)
	if lip.size() >= 3:
		Art.flat(ci, lip, sand.lightened(0.12))
	for k in 3:
		var c := Vector2(left + 60.0 + k * 130.0 + (index % 3) * 20.0, ledge_y + 18.0 + (k % 2) * 10.0)
		if c.x < cave.end.x - 20.0:
			var pd := Art.clipped(Art.ellipse_pts(c, Vector2(26, 5), 14), cp)
			if pd.size() >= 3:
				Art.flat(ci, pd, Color(glow, 0.35))
				Art.line(ci, c + Vector2(-12, -1), c + Vector2(4, -1), Color(1, 1, 1, 0.35), 1.4)
	var foot := Art.clipped(PackedVector2Array([Vector2(left, bottom - 12), Vector2(cave.end.x + 10, bottom - 12), Vector2(cave.end.x + 10, bottom + 10), Vector2(left, bottom + 10)]), cp)
	if foot.size() >= 3:
		Art.flat(ci, foot, Color(Art.SHADE, 0.4))


## The mine frame: two leaning monoliths under a cracked lintel with a
## glowing glyph. (0, 0) = left foot.
static func arch_portal(ci: CanvasItem, h: float, w: float) -> void:
	monolith(ci, Vector2(0, 0), h + 6.0, 10.0, 0.06, STONE)
	monolith(ci, Vector2(w, 0), h, 10.0, -0.05, STONE)
	Art.toon(ci, PackedVector2Array([Vector2(-20, -h - 4), Vector2(w + 22, -h - 14), Vector2(w + 18, -h + 4), Vector2(-16, -h + 10)]), STONE.darkened(0.1), 2.6, 0.5)
	var c := Vector2(w * 0.5, -h - 2)
	Art.glow(ci, c, 16.0, Color(SLIME, 0.45), 10)
	_glyph(ci, c, 6.0, SLIME, 3)


## The brace across the lift shaft: a black stone beam, a tentacle round it.
static func shaft_brace(ci: CanvasItem, l: float, r: float) -> void:
	Art.t_rect(ci, Rect2(l, 7, r - l, 11), 2.0, STONE_DARK, 2.4, 0.5)
	var coil := PackedVector2Array()
	for k in 13:
		var x := lerpf(l + 4.0, r - 4.0, k / 12.0)
		coil.append(Vector2(x, 12.5 + sin(k * 1.6) * 7.0))
	Art.polyline(ci, coil, Art.INK, 6.0)
	Art.polyline(ci, coil, Color("4a6a5a"), 3.4)
	Art.glow(ci, Vector2(r - 6, 12), 10.0, Color(SLIME, 0.3), 8)


## R'lyeh's cave decor ("rl_*" decos). Returns false for other decos.
static func decor(ci: CanvasItem, st: Dictionary, x0: float, x1: float, mid: float, y: float, top: float, t: float, index: int) -> bool:
	var deco := str(st["deco"])
	if not deco.begins_with("rl_"):
		return false
	var ore: Color = st["ore"]
	var glow: Color = st.get("glow", ore)
	var pulse := snappedf(0.5 + 0.5 * sin(t * 2.0 + index), 0.25)
	match deco:
		"rl_monoliths":
			monolith(ci, Vector2(x0, y + 4), 110.0, 16.0, 0.12, STONE)
			monolith(ci, Vector2(x1 + 6, y + 4), 80.0, 13.0, -0.18, STONE.darkened(0.08))
			Art.glow(ci, Vector2(x0 + 6, y - 50), 18.0, Color(glow, 0.2 + 0.2 * pulse), 10)
		"rl_eyes":
			# Eyes open in the wall, blinking out of step.
			for k in 3:
				var c := Vector2(lerpf(x0, x1, k / 2.0), top + 40.0 + (k % 2) * 30.0)
				MurkVeil.eye(ci, c, 12.0 - k * 2.0, fmod(t + k * 1.3, 4.0) < 0.18, k == 1)
		"rl_glyphs":
			# A carved tablet whose glyphs breathe green.
			var p := Vector2(x0 + 10, y + 2)
			Art.toon(ci, PackedVector2Array([p + Vector2(-30, 0), p + Vector2(-26, -70), p + Vector2(28, -76), p + Vector2(32, 0)]), STONE, 2.4, 0.4)
			for k in 3:
				_glyph(ci, p + Vector2(0, -56 + k * 20), 6.0, Color(glow, 0.5 + 0.4 * pulse), k + index)
			Art.glow(ci, p + Vector2(0, -36), 30.0, Color(glow, 0.12 + 0.12 * pulse), 10)
		"rl_tentacles":
			# Tentacles reaching out of cracks in the floor.
			for k in 2:
				var at := Vector2(x0 + 4 if k == 0 else x1 + 10, y + 6)
				Art.push(ci, at, 0.0, Vector2(1.6 - k * 0.3, 1.6 - k * 0.3) * Vector2(1.0 if k == 0 else -1.0, 1.0))
				OreArt.tentacle(ci, t * 1.1 + k * 2.3, Color("4a6a5a") if k == 0 else Color("5a3a7a"))
				Art.pop(ci)
				Art.toon(ci, Art.ellipse_pts(at + Vector2(0, -2), Vector2(18, 5), 12), STONE_DARK, 2.0, 0.0)
		"rl_flames":
			# Braziers of cold green fire.
			for k in 2:
				var at := Vector2(x0 + 4 if k == 0 else x1 + 6, y + 4)
				Art.t_rect(ci, Rect2(at.x - 10, at.y - 34, 20, 34), 2.0, STONE_DARK, 2.2, 0.4)
				Art.t_rect(ci, Rect2(at.x - 18, at.y - 42, 36, 10), 2.0, STONE, 2.2, 0.4)
				var fl := snappedf(sin(t * 7.0 + k * 2.0) * 4.0, 1.0)
				Art.glow(ci, at + Vector2(0, -56), 30.0, Color(glow, 0.3), 10)
				Art.flat_now(ci, PackedVector2Array([at + Vector2(-14, -42), at + Vector2(-8, -60), at + Vector2(-2 + fl, -80), at + Vector2(6, -62), at + Vector2(14, -42)]), Color(glow, 0.85))
				Art.flat_now(ci, PackedVector2Array([at + Vector2(-6, -42), at + Vector2(fl * 0.5, -64), at + Vector2(6, -42)]), Color(1, 1, 1, 0.75))
		"rl_idol":
			# A squat idol of the Sleeper: wings, a tentacled face.
			var c := Vector2(x0 + 14, y + 2)
			Art.glow(ci, c + Vector2(0, -40), 40.0, Color(glow, 0.15 + 0.15 * pulse), 10)
			idol(ci, c, 1.4, ore)
		"rl_stars":
			# Wrong stars in a rift of the ceiling.
			var c := Vector2(mid, top + 40)
			Art.toon(ci, Art.ellipse_pts(c, Vector2(70, 26), 20), Color("0a0a1a"), 2.4, 0.0)
			for k in 6:
				var a := k * 1.7 + index
				var p := c + Vector2(cos(a) * 52.0 * ((k % 3) + 1) / 3.0, sin(a) * 16.0)
				Art.flat(ci, Art.star_pts(p, 5.0 + (k % 2) * 2.0, 2.0, 5 + k % 3), Color(STAR if k % 2 == 0 else glow, 0.6 + 0.4 * pulse))
		_:
			return false
	return true


## The Sleeper's idol standing on (0, 0), about 50 px tall at k = 1.
static func idol(ci: CanvasItem, at: Vector2, k: float, col: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(k, k))
	Art.toon(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-14, -8), Vector2(14, -8), Vector2(16, 0)]), STONE_DARK, 2.0, 0.3)
	for s: float in [-1.0, 1.0]:
		Art.toon(ci, PackedVector2Array([Vector2(8 * s, -30), Vector2(26 * s, -46), Vector2(22 * s, -30), Vector2(14 * s, -20)]), col.darkened(0.2), 2.0, 0.4)
	Art.toon(ci, Art.rrect_pts(Rect2(-11, -34, 22, 26), 8.0), col, 2.2, 0.5)
	Art.toon(ci, Art.ellipse_pts(Vector2(0, -40), Vector2(12, 11), 14), col, 2.2, 0.5)
	for dx: float in [-6.0, -2.0, 2.0, 6.0]:
		Art.line(ci, Vector2(dx, -34), Vector2(dx * 1.2, -24), col.darkened(0.3), 2.4)
	Art.dot(ci, Vector2(-4, -43), 2.2, SLIME)
	Art.dot(ci, Vector2(4, -43), 2.2, SLIME)
	Art.pop(ci)


## R'lyeh's own ores (OreArt): pieces about 40 px tall standing on (0, 0).
static func ore_piece(ci: CanvasItem, kind: String, c: Color, c2: Color, t: float, i: int) -> void:
	var pulse := snappedf(0.5 + 0.5 * sin(t * 2.2 + i * 1.3), 0.25)
	match kind:
		"eye_stone":
			Art.toon(ci, PackedVector2Array([Vector2(-18, 0), Vector2(-20, -22), Vector2(-4, -34), Vector2(16, -28), Vector2(20, 0)]), STONE, 2.2, 0.5)
			MurkVeil.eye(ci, Vector2(0, -16), 9.0, fmod(t + i * 0.9, 5.0) < 0.15, i % 2 == 0)
		"elder_glyph":
			Art.glow(ci, Vector2(0, -20), 22.0, Color(c, 0.2 + 0.2 * pulse))
			Art.toon(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-14, -36), Vector2(14, -38), Vector2(16, 0)]), STONE_DARK, 2.2, 0.4)
			_glyph(ci, Vector2(0, -19), 8.0, c, i)
		"deep_spawn":
			# A little fish-frog thing with big eyes.
			Art.toon(ci, Art.ellipse_pts(Vector2(0, -14), Vector2(18, 14), 18), c, 2.2, 0.6)
			Art.toon(ci, PackedVector2Array([Vector2(14, -16), Vector2(26, -26), Vector2(24, -6)]), c.darkened(0.15), 2.0, 0.4)
			for dx: float in [-8.0, 2.0]:
				Art.t_circle(ci, Vector2(dx, -22), 5.0, c2, 1.6, 0.0)
				Art.dot(ci, Vector2(dx + 1, -22), 2.0, Art.INK)
			Art.line(ci, Vector2(-10, -10), Vector2(4, -8), Art.INK, 2.0)
		"madness_pearl":
			Art.glow(ci, Vector2(0, -16), 22.0, Color(c, 0.25 + 0.2 * pulse))
			Art.t_circle(ci, Vector2(0, -16), 15.0, c, 2.2, 0.5)
			Art.push(ci, Vector2(0, -16), snappedf(t * 1.2, 0.2))
			Art.arc(ci, Vector2(3, 0), 8.0, 0.0, PI * 1.4, 10, c2, 2.4)
			Art.arc(ci, Vector2(-3, 0), 4.0, PI, PI * 2.4, 8, c2, 2.0)
			Art.pop(ci)
			Art.dot(ci, Vector2(-5, -22), 3.0, Color(1, 1, 1, 0.8))
		"green_flame":
			var fl := snappedf(sin(t * 6.0 + i) * 3.0, 1.0)
			Art.glow(ci, Vector2(0, -20), 24.0, Color(c, 0.35))
			Art.flat_now(ci, PackedVector2Array([Vector2(-14, 0), Vector2(-10, -20), Vector2(fl, -42), Vector2(10, -22), Vector2(14, 0)]), c)
			Art.flat_now(ci, PackedVector2Array([Vector2(-6, 0), Vector2(fl * 0.5, -24), Vector2(6, 0)]), c2)
			Art.toon(ci, Art.rrect_pts(Rect2(-16, -4, 32, 8), 3.0), STONE_DARK, 2.0, 0.3)
		"tentacle_ivory":
			# A curved ivory tusk with violet bands.
			var pts := PackedVector2Array()
			var bot := PackedVector2Array()
			for k in 9:
				var f := k / 8.0
				var p := Vector2(-16 + f * 30.0, -f * f * 36.0)
				var wd := lerpf(7.0, 1.0, f)
				pts.append(p + Vector2(0, -wd))
				bot.append(p + Vector2(0, wd))
			bot.reverse()
			pts.append_array(bot)
			Art.toon(ci, pts, c, 2.2, 0.5)
			for f: float in [0.3, 0.6]:
				var p := Vector2(-16 + f * 30.0, -f * f * 36.0)
				Art.line(ci, p + Vector2(-3, -5), p + Vector2(3, 5), c2, 2.4)
		"sleeper_idol":
			Art.glow(ci, Vector2(0, -22), 22.0, Color(c2, 0.15 + 0.2 * pulse))
			idol(ci, Vector2.ZERO, 0.8, c)
		_:
			Art.crystal(ci, Vector2.ZERO, 40, 8, 0.0, c, 2.0)


## R'lyeh's puzzle pieces (TileWorlds world 7, slots 70..75), drawn around
## (0, 0) in a ~44 px cell: eye, tentacle, idol, strange star, green flame,
## elder glyph.
static func tile(ci: CanvasItem, slot: int, t: float, col: Color) -> void:
	match slot % 10:
		0:
			Art.t_circle(ci, Vector2.ZERO, 19.0, Color("2a3430"), 3.0, 0.4)
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-15, 0), Vector2(-6, -9), Vector2(6, -9), Vector2(15, 0), Vector2(6, 9), Vector2(-6, 9)]), 3), col, 2.0, 0.3)
			Art.flat(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(3.2, 8.0), 10), Art.INK)
			Art.dot(ci, Vector2(-4, -4), 2.0, Color(1, 1, 1, 0.8))
		1:
			Art.push(ci, Vector2(-8, 20), 0.0, Vector2(1.3, 1.3))
			OreArt.tentacle(ci, t, col)
			Art.pop(ci)
		2:
			idol(ci, Vector2(0, 20), 0.82, col)
		3:
			var pulse := snappedf(0.5 + 0.5 * sin(t * 2.4), 0.25)
			Art.glow(ci, Vector2.ZERO, 24.0, Color(col, 0.2 + 0.2 * pulse))
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 20.0, 8.0, 7), col, 3.0, 0.5)
			Art.dot(ci, Vector2.ZERO, 3.0, Art.INK)
		4:
			Art.glow(ci, Vector2(0, -2), 24.0, Color(col, 0.3))
			Art.toon(ci, PackedVector2Array([Vector2(-14, 16), Vector2(-12, -2), Vector2(-4, -10), Vector2(0, -22), Vector2(6, -8), Vector2(13, 0), Vector2(14, 16)]), col, 3.0, 0.5)
			Art.flat(ci, PackedVector2Array([Vector2(-6, 16), Vector2(0, -2), Vector2(6, 16)]), Color(1, 1, 1, 0.7))
		_:
			Art.toon(ci, Art.rrect_pts(Rect2(-17, -19, 34, 38), 5.0), Color("3a4642"), 3.0, 0.4)
			_glyph(ci, Vector2.ZERO, 9.0, col, 5)
