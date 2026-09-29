class_name ArtifactArt
extends RefCounted
## Sunken treasures for the museum and the match-3 level goals. Each one is
## drawn in local space centered at (0,0) and fits inside a circle of radius
## ~80. `t` only drives the sparkles, never the shapes. Callers place them
## with Art.push/pop.

const IDS: Array[String] = ["compass", "bell_shell", "pearl_crown", "amphora", "ship_wheel", "diving_watch",
		"fish_idol", "crystal_lantern", "trident", "treasure_key", "star_map", "sun_medallion"]

const GOLD_LIGHT := Color("ffe38a")
const GOLD_DEEP := Color("c7771a")
const RUBY := Color("ff3d63")
const SAPPHIRE := Color("3a7ff0")
const EMERALD := Color("2fd08a")
const PEARL := Color("fff3f8")


static func draw(ci: CanvasItem, id: String, t: float) -> void:
	match id:
		"compass": _compass(ci, t)
		"bell_shell": _bell_shell(ci, t)
		"pearl_crown": _pearl_crown(ci, t)
		"amphora": _amphora(ci, t)
		"ship_wheel": _ship_wheel(ci, t)
		"diving_watch": _diving_watch(ci, t)
		"fish_idol": _fish_idol(ci, t)
		"crystal_lantern": _crystal_lantern(ci, t)
		"trident": _trident(ci, t)
		"treasure_key": _treasure_key(ci, t)
		"star_map": _star_map(ci, t)
		"sun_medallion": _sun_medallion(ci, t)


## Soft underwater backdrop from (-size/2,-size/2) to (size/2,size/2):
## lighter water on top, light rays from the top left, sand at the bottom.
static func background(ci: CanvasItem, size: float) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2.ONE * (size / 200.0))
	var top := Color("8fe0ea")
	var mid := Color("3fb0d4")
	var low := Color("2a86b8")
	Art.grad(ci, PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(100, 0), Vector2(-100, 0)]), PackedColorArray([top, top, mid, mid]))
	Art.grad(ci, PackedVector2Array([Vector2(-100, 0), Vector2(100, 0), Vector2(100, 100), Vector2(-100, 100)]), PackedColorArray([mid, mid, low, low]))
	var square := PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)])
	for r: Array in [[-0.35, 22.0], [0.05, 14.0], [0.42, 26.0], [0.78, 12.0]]:
		var a: float = r[0]
		var w: float = r[1]
		var d := Vector2(cos(PI / 4.0 + a * 0.6), sin(PI / 4.0 + a * 0.6))
		var n := d.orthogonal()
		var o := Vector2(-110, -110) + n * a * 90.0
		var ray := PackedVector2Array([o - n * w * 0.3, o + n * w * 0.3, o + d * 300.0 + n * w, o + d * 300.0 - n * w])
		Art.flat(ci, Art.clipped(ray, square), Color(1, 1, 1, 0.13))
	var sand := Art.smooth_pts(PackedVector2Array([Vector2(-104, 66), Vector2(-60, 58), Vector2(-14, 68), Vector2(34, 60), Vector2(80, 66),
			Vector2(104, 60), Vector2(104, 104), Vector2(-104, 104)]), 4)
	Art.flat(ci, Art.clipped(sand, square), Art.SAND)
	var ripple := Art.smooth_pts(PackedVector2Array([Vector2(-104, 84), Vector2(-50, 80), Vector2(0, 86), Vector2(60, 80),
			Vector2(104, 84), Vector2(104, 104), Vector2(-104, 104)]), 4)
	Art.flat(ci, Art.clipped(ripple, square), Color(Art.SAND_DARK, 0.45))
	for p: Vector2 in [Vector2(-80, 76), Vector2(-40, 90), Vector2(52, 74), Vector2(84, 92)]:
		Art.t_ellipse(ci, p, Vector2(5, 3.4), Color("c9b6a8"), 1.8, 0.4)
	Art.push(ci, Vector2(-6, 82), -0.3, Vector2(0.55, 0.55))
	_shell(ci, Color("ffb3c7"))
	Art.pop(ci)
	Art.push(ci, Vector2(70, 78), 0.4, Vector2(0.55, 0.55))
	_starfish(ci, Color("ff8a5c"))
	Art.pop(ci)
	for b: Vector3 in [Vector3(-84, -40, 3.5), Vector3(-78, -58, 2.5), Vector3(86, 10, 3.0), Vector3(80, -8, 2.0)]:
		Art.ring(ci, Art.circle_pts(Vector2(b.x, b.y), b.z, 12), Color(1, 1, 1, 0.55), 1.4)
	Art.pop(ci)


## Small glowing broken piece of an artifact (~40 px), a "collect me" drop.
static func fragment(ci: CanvasItem, id: String, t: float) -> void:
	var pulse := 1.0 + sin(t * 3.0) * 0.07
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(pulse, pulse))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 25.0, 30), Color(1.0, 0.9, 0.5, 0.2))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 20.5, 28), Color(1.0, 0.95, 0.7, 0.28))
	Art.pop(ci)
	Art.push(ci, Vector2.ZERO, t * 0.6)
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := d.orthogonal()
		var ln := 27.0 if i % 2 == 0 else 23.0
		Art.flat(ci, PackedVector2Array([d * 14.0 + n * 2.6, d * ln, d * 14.0 - n * 2.6]), Color(1.0, 0.96, 0.7, 0.55))
	Art.pop(ci)
	Art.push(ci, Vector2(0, sin(t * 2.4) * 1.2), sin(t * 1.8) * 0.08)
	# A pale tablet piece: smooth rounded top-left, broken zig-zag bottom-right.
	var shard := PackedVector2Array([Vector2(-19, -1), Vector2(-17, -11), Vector2(-9, -18), Vector2(2, -20), Vector2(12, -16),
			Vector2(17, -9), Vector2(13, -4), Vector2(19, 2), Vector2(12, 8), Vector2(15, 15), Vector2(6, 13), Vector2(2, 19),
			Vector2(-4, 13), Vector2(-10, 18), Vector2(-13, 10), Vector2(-19, 9)])
	Art.toon(ci, shard, Color("fff0c8"), 2.4, 0.5)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-8, -10), 14.0, 20), shard), Color(1, 1, 1, 0.4))
	Art.push(ci, Vector2(0, -1), 0.0, Vector2(0.2, 0.2))
	draw(ci, id, t)
	Art.pop(ci)
	Art.pop(ci)
	_sparkle(ci, Vector2(15, -16), 6.0, t, 0.0)
	_sparkle(ci, Vector2(-17, 13), 4.5, t, 2.4)


# --- Shared bits ----------------------------------------------------------------------

## Four-point twinkle that grows and fades with t (scale only).
static func _sparkle(ci: CanvasItem, pos: Vector2, size: float, t: float, phase: float) -> void:
	var s := maxf(0.0, sin(t * 2.2 + phase))
	if s < 0.08:
		return
	Art.push(ci, pos, 0.0, Vector2(s, s) * size)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 1.0, 0.22, 4), Color(1, 1, 1, 0.95))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 0.3, 8), Color(1, 1, 0.85, 1.0))
	Art.pop(ci)


## Round cut gem with a facet and a glint.
static func _gem(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float = 2.2) -> void:
	Art.t_circle(ci, c, r, col, w, 0.7)
	Art.flat(ci, Art.circle_pts(c + Vector2(r * 0.1, r * 0.08), r * 0.55, 8), col.lightened(0.28))
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-r * 0.36, -r * 0.4), Vector2(r * 0.34, r * 0.2), 8, -0.6), Color(1, 1, 1, 0.9))


static func _oval_gem(ci: CanvasItem, c: Vector2, radii: Vector2, col: Color, rot: float = 0.0) -> void:
	Art.t_ellipse(ci, c, radii, col, 2.2, 0.7, rot)
	Art.flat(ci, Art.ellipse_pts(c, radii * 0.55, 8, rot), col.lightened(0.28))
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-radii.x * 0.35, -radii.y * 0.42).rotated(rot), radii * Vector2(0.3, 0.18), 8, rot - 0.5), Color(1, 1, 1, 0.9))


static func _pearl(ci: CanvasItem, c: Vector2, r: float, w: float = 2.0) -> void:
	Art.t_circle(ci, c, r, PEARL, w, 0.7)
	Art.flat(ci, Art.circle_pts(c + Vector2(-r * 0.35, -r * 0.38), r * 0.3, 8), Color(1, 1, 1, 0.95))


static func _ring(ci: CanvasItem, c: Vector2, r: float, col: Color, width: float) -> void:
	Art.arc(ci, c, r, 0, TAU, 28, Art.INK, width + 5.0)
	Art.arc(ci, c, r, 0, TAU, 28, col, width)


## Small scallop shell and starfish decorations (local copies so the
## artifacts don't depend on Props).
static func _shell(ci: CanvasItem, color: Color) -> void:
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


static func _starfish(ci: CanvasItem, color: Color) -> void:
	Art.toon(ci, Art.smooth_pts(Art.star_pts(Vector2.ZERO, 14, 6, 5), 2), color, 2.2, 0.4)
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		Art.flat(ci, Art.circle_pts(Vector2(cos(a), sin(a)) * 6.0, 1.3, 6), Color(1, 1, 1, 0.6))


# --- Artifacts ------------------------------------------------------------------------

static func _compass(ci: CanvasItem, t: float) -> void:
	var c := Vector2(0, 10)
	_ring(ci, Vector2(0, -63), 10.0, Art.GOLD, 5.5)
	Art.t_rect(ci, Rect2(-10, -58, 20, 12), 4, GOLD_DEEP, 3.0, 0.3)
	Art.flat(ci, Art.rrect_pts(Rect2(-7, -56, 14, 3), 1.5), GOLD_LIGHT)
	# Brass case, engraved rim.
	Art.t_circle(ci, c, 62, GOLD_DEEP, 3.0, 0.6)
	Art.t_circle(ci, c + Vector2(0, -1.5), 57, Art.GOLD, 0.0, 0.6)
	Art.arc(ci, c, 52.5, 0, TAU, 56, GOLD_DEEP, 2.0)
	for i in 24:
		var a := TAU * i / 24.0
		Art.flat(ci, Art.circle_pts(c + Vector2(cos(a), sin(a)) * 55.5, 1.3, 6), GOLD_DEEP)
	# Red north marker on the rim.
	Art.toon(ci, PackedVector2Array([c + Vector2(-6, -60), c + Vector2(6, -60), c + Vector2(0, -50)]), Art.RED, 2.0, 0.0)
	# Dial face with ticks.
	var face := Art.circle_pts(c, 47.0, 48)
	Art.toon(ci, face, Art.CREAM, 2.5, 0.3)
	for i in 32:
		var a := TAU * i / 32.0
		var d := Vector2(cos(a), sin(a))
		var ln := 7.0 if i % 8 == 0 else (5.0 if i % 4 == 0 else 3.0)
		Art.line(ci, c + d * (43.5 - ln), c + d * 43.5, Art.INK_SOFT if i % 4 != 0 else Art.INK, 2.2 if i % 4 == 0 else 1.3)
	# Compass rose.
	Art.toon(ci, Art.star_pts(c, 25.0, 6.0, 4, -PI / 4.0), Art.TEAL, 2.0, 0.0)
	Art.toon(ci, Art.star_pts(c, 37.0, 8.0, 4), SAPPHIRE, 2.2, 0.0)
	for i in 4:
		var d := Vector2(0, -1).rotated(PI / 2.0 * i)
		Art.flat(ci, PackedVector2Array([c, c + d * 36.0, c + d.rotated(PI / 4.0) * 7.5]), Art.shade_of(SAPPHIRE, 0.35))
		var d2 := d.rotated(PI / 4.0)
		Art.flat(ci, PackedVector2Array([c, c + d2 * 24.0, c + d2.rotated(PI / 4.0) * 5.6]), Art.shade_of(Art.TEAL, 0.35))
	# Needle: red north, silver south.
	Art.toon(ci, PackedVector2Array([c + Vector2(0, -32), c + Vector2(7, 0), c + Vector2(-7, 0)]), Art.RED, 2.2, 0.0)
	Art.flat(ci, PackedVector2Array([c + Vector2(0, -32), c + Vector2(7, 0), c]), Art.shade_of(Art.RED, 0.3))
	Art.toon(ci, PackedVector2Array([c + Vector2(-7, 0), c + Vector2(7, 0), c + Vector2(0, 32)]), Art.WHITE, 2.2, 0.0)
	Art.flat(ci, PackedVector2Array([c, c + Vector2(7, 0), c + Vector2(0, 32)]), Art.METAL)
	Art.t_circle(ci, c, 6.5, Art.GOLD, 2.2, 0.5)
	Art.flat(ci, Art.circle_pts(c + Vector2(-1.6, -1.6), 1.8, 8), Art.WHITE)
	# Glass shine.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(c + Vector2(-20, -24), Vector2(30, 13), 24, -0.75), face), Color(1, 1, 1, 0.4))
	Art.flat(ci, Art.clipped(Art.ellipse_pts(c + Vector2(26, 26), Vector2(14, 5), 16, -0.75), face), Color(1, 1, 1, 0.3))
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-38, -26), Vector2(8, 4), 12, -0.9), Color(1, 1, 1, 0.55))
	_sparkle(ci, Vector2(44, -34), 11.0, t, 0.0)
	_sparkle(ci, Vector2(-50, 50), 8.0, t, 2.2)
	_sparkle(ci, Vector2(10, -63), 7.0, t, 4.1)


static func _bell_shell(ci: CanvasItem, t: float) -> void:
	var pink := Color("ffa9c4")
	_ring(ci, Vector2(0, -66), 9.0, Art.GOLD, 5.0)
	Art.t_ellipse(ci, Vector2(0, -53), Vector2(17, 9), GOLD_DEEP, 3.0, 0.5)
	# Pearl clapper peeking out below the lip.
	Art.stroke(ci, PackedVector2Array([Vector2(0, 30), Vector2(-3, 52)]), GOLD_DEEP, 3.0, 2.0)
	_pearl(ci, Vector2(-4, 58), 11.0, 2.6)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-18, -54), Vector2(18, -54), Vector2(30, -32), Vector2(35, -4),
			Vector2(43, 22), Vector2(60, 38), Vector2(0, 40), Vector2(-60, 38), Vector2(-43, 22), Vector2(-35, -4), Vector2(-30, -32)]), 4)
	Art.toon(ci, body, pink, 3.0, 0.7)
	# Fluted ridges like a scallop shell.
	for k in range(-4, 4):
		var q := PackedVector2Array([Vector2(k * 5.0, -50), Vector2((k + 1) * 5.0, -50), Vector2((k + 1) * 17.0, 42), Vector2(k * 17.0, 42)])
		if k % 2 == 0:
			Art.flat(ci, Art.clipped(q, body), Color(1, 1, 1, 0.28))
	for k in range(-3, 4):
		var q := PackedVector2Array([Vector2(k * 5.0 - 0.9, -50), Vector2(k * 5.0 + 0.9, -50), Vector2(k * 17.0 + 1.6, 42), Vector2(k * 17.0 - 1.6, 42)])
		Art.flat(ci, Art.clipped(q, body), Art.shade_of(pink, 0.4))
	# Gold band with gems near the top.
	var band := Art.clipped(Art.rrect_pts(Rect2(-60, -40, 120, 10), 1), body)
	Art.toon(ci, band, Art.GOLD, 2.2, 0.0)
	for x: float in [-18.0, 0.0, 18.0]:
		_gem(ci, Vector2(x, -35), 3.6 if x != 0.0 else 4.6, SAPPHIRE if x != 0.0 else RUBY, 1.6)
	# Scalloped pearly lip.
	var lip := []
	lip.append(Art.rrect_pts(Rect2(-63, 32, 126, 10), 4))
	for i in 9:
		lip.append(Art.circle_pts(Vector2(-60 + i * 15.0, 43), 8.5, 16))
	Art.toon(ci, Art.union(lip), Color("fff0f4"), 3.0, 0.5)
	for i in 9:
		Art.flat(ci, Art.circle_pts(Vector2(-60 + i * 15.0, 44), 2.0, 8), Color("ffc4d6"))
	# A little starfish stuck to the side.
	Art.push(ci, Vector2(-24, 2), -0.35, Vector2(0.8, 0.8))
	_starfish(ci, Color("ffb13b"))
	Art.pop(ci)
	Art.flat(ci, Art.ellipse_pts(Vector2(-18, -22), Vector2(4, 12), 12, 0.35), Color(1, 1, 1, 0.5))
	_sparkle(ci, Vector2(30, -40), 10.0, t, 0.8)
	_sparkle(ci, Vector2(48, 58), 8.0, t, 3.0)
	_sparkle(ci, Vector2(-12, -64), 6.0, t, 5.0)


static func _pearl_crown(ci: CanvasItem, t: float) -> void:
	Art.push(ci, Vector2(0, 10))
	# Velvet cap seen between the points.
	Art.toon(ci, Art.ellipse_pts(Vector2(0, -2), Vector2(52, 40), 32), Color("c8304f"), 3.0, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(-14, -22), Vector2(14, 8), 12, -0.3), Color(1, 1, 1, 0.25))
	var peaks: Array[Vector2] = [Vector2(-56, -34), Vector2(-28, -46), Vector2(0, -60), Vector2(28, -46), Vector2(56, -34)]
	var crown := PackedVector2Array([Vector2(-60, 50), Vector2(60, 50), Vector2(63, 10), peaks[4], Vector2(42, 0), peaks[3], Vector2(14, -8),
			peaks[2], Vector2(-14, -8), peaks[1], Vector2(-42, 0), peaks[0], Vector2(-63, 10)])
	Art.toon(ci, crown, Art.GOLD, 3.0, 0.6)
	# Engraved teardrop gems on each point.
	for i in 5:
		var p := peaks[i]
		var col := [EMERALD, SAPPHIRE, RUBY, SAPPHIRE, EMERALD][i] as Color
		var base := Vector2(p.x * 0.93, p.y + 26.0)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([base + Vector2(0, -11), base + Vector2(5, 1), base + Vector2(0, 6), base + Vector2(-5, 1)]), 3), col, 1.8, 0.4)
		Art.flat(ci, Art.circle_pts(base + Vector2(-1.4, -1.5), 1.5, 6), Color(1, 1, 1, 0.9))
	# Band.
	Art.t_rect(ci, Rect2(-65, 18, 130, 34), 8, GOLD_DEEP, 3.0, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-60, 22, 120, 4), 2), GOLD_LIGHT)
	Art.line(ci, Vector2(-60, 46), Vector2(60, 46), Color("a85d10"), 2.0)
	for i in 13:
		_pearl(ci, Vector2(-57 + i * 9.5, 18), 3.6, 1.3)
	_oval_gem(ci, Vector2(0, 35), Vector2(12, 9.5), RUBY)
	for sx: float in [-1.0, 1.0]:
		_gem(ci, Vector2(29 * sx, 35), 7.0, SAPPHIRE)
		_gem(ci, Vector2(52 * sx, 35), 5.0, EMERALD)
	# Pearls on the points.
	for i in 5:
		_pearl(ci, peaks[i] + Vector2(0, -5), 12.0 if i == 2 else 7.5, 2.5)
	Art.pop(ci)
	_sparkle(ci, Vector2(12, -64), 10.0, t, 0.5)
	_sparkle(ci, Vector2(-56, -40), 7.0, t, 2.6)
	_sparkle(ci, Vector2(40, 52), 8.0, t, 4.3)


static func _amphora(ci: CanvasItem, t: float) -> void:
	var col := Color("ec8a4e")
	var dark := Color("4a2a44")
	var cream := Color("ffe8c2")
	for sx: float in [-1.0, 1.0]:
		Art.stroke(ci, PackedVector2Array([Vector2(12 * sx, -52), Vector2(30 * sx, -58), Vector2(43 * sx, -48), Vector2(46 * sx, -32), Vector2(40 * sx, -16)]),
				Art.shade_of(col, 0.12), 7.0, 3.0)
	Art.t_rect(ci, Rect2(-26, 50, 52, 16), 5, Art.shade_of(col, 0.15), 3.0, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-26, 56, 52, 4), 1), dark)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-14, -64), Vector2(14, -64), Vector2(14, -40), Vector2(44, -20), Vector2(53, 6),
			Vector2(41, 36), Vector2(18, 54), Vector2(-18, 54), Vector2(-41, 36), Vector2(-53, 6), Vector2(-44, -20), Vector2(-14, -40)]), 4)
	Art.toon(ci, body, col, 3.0, 0.7)
	# Painted bands: a wave frieze and a row of dots.
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-70, -44, 140, 5), 1), body), dark)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-70, -8, 140, 22), 1), body), dark)
	var wave := PackedVector2Array()
	for i in 23:
		var x := -44.0 + i * 4.0
		wave.append(Vector2(x, 3.0 - sin(i * PI / 3.0) * 5.0))
	Art.polyline(ci, wave, cream, 2.4)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-70, 26, 140, 4), 1), body), dark)
	for i in 7:
		Art.flat(ci, Art.circle_pts(Vector2(-30 + i * 10.0, 20), 1.8, 8), dark)
	for i in 5:
		Art.flat(ci, Art.circle_pts(Vector2(-20 + i * 10.0, -24), 1.8, 8), dark)
	# Lip with the dark opening.
	Art.t_rect(ci, Rect2(-24, -76, 48, 13), 6, col.lightened(0.08), 3.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -73), Vector2(16, 2.6), 14), Color("5a2e2a"))
	# Crack, shine, barnacles and a starfish from the sea floor.
	Art.polyline(ci, PackedVector2Array([Vector2(22, -30), Vector2(17, -22), Vector2(23, -17), Vector2(19, -10)]), Art.shade_of(col, 0.55), 2.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-31, 18), Vector2(5, 16), 14, 0.35), Color(1, 1, 1, 0.3))
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -56), Vector2(2.6, 6), 10), Color(1, 1, 1, 0.35))
	for b: Vector3 in [Vector3(33, 36, 6.0), Vector3(42, 24, 4.5), Vector3(24, 46, 4.0), Vector3(44, 38, 3.0)]:
		Art.t_circle(ci, Vector2(b.x, b.y), b.z, Color("eee6d8"), 2.0, 0.4)
		Art.flat(ci, Art.circle_pts(Vector2(b.x, b.y - 0.5), b.z * 0.42, 8), Color("8a7d70"))
	Art.push(ci, Vector2(-34, -24), -0.4, Vector2(0.85, 0.85))
	_starfish(ci, Color("ff6f7e"))
	Art.pop(ci)
	_sparkle(ci, Vector2(-40, 42), 9.0, t, 1.0)
	_sparkle(ci, Vector2(30, -66), 8.0, t, 3.4)


static func _ship_wheel(ci: CanvasItem, t: float) -> void:
	var c := Vector2(0, -8)
	var wood := Art.WOOD
	# Pedestal.
	Art.toon(ci, PackedVector2Array([Vector2(-20, 20), Vector2(20, 20), Vector2(34, 72), Vector2(-34, 72)]), Art.WOOD_DARK, 3.0, 0.3)
	Art.t_rect(ci, Rect2(-40, 66, 80, 10), 4, GOLD_DEEP, 3.0, 0.3)
	Art.flat(ci, Art.rrect_pts(Rect2(-12, 40, 24, 16), 3), Art.shade_of(Art.WOOD_DARK, 0.3))
	for i in 8:
		var a := -PI / 2.0 + TAU * i / 8.0
		Art.push(ci, c, a)
		Art.t_rect(ci, Rect2(8, -4, 46, 8), 3, wood, 2.5, 0.0)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(50, -4.5), Vector2(56, -7.5), Vector2(64, -6), Vector2(70, -4.5),
				Vector2(71.5, 0), Vector2(70, 4.5), Vector2(64, 6), Vector2(56, 7.5), Vector2(50, 4.5)]), 3), wood if i != 0 else Art.GOLD, 2.5, 0.0)
		Art.flat(ci, Art.rrect_pts(Rect2(54, -2.5, 12, 2.2), 1), Color(1, 1, 1, 0.35))
		Art.pop(ci)
	# Rim with a brass inlay.
	Art.arc(ci, c, 40, 0, TAU, 56, Art.INK, 17.0)
	Art.arc(ci, c, 40, 0, TAU, 56, wood, 11.0)
	Art.arc(ci, c, 36.5, 0, TAU, 56, Art.shade_of(wood, 0.3), 2.5)
	Art.arc(ci, c, 41, 0, TAU, 56, Art.BRASS, 3.0)
	for i in 8:
		var a := -PI / 2.0 + TAU * i / 8.0
		Art.t_circle(ci, c + Vector2(cos(a), sin(a)) * 40.0, 3.2, Art.GOLD, 1.5, 0.0)
	# Hub.
	Art.t_circle(ci, c, 16, Art.GOLD, 3.0, 0.6)
	Art.t_circle(ci, c, 8.5, GOLD_DEEP, 2.2, 0.0)
	Art.toon(ci, Art.star_pts(c, 6.5, 2.6, 4), GOLD_LIGHT, 0.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-7, -8), Vector2(4, 2.2), 10, -0.7), Color(1, 1, 1, 0.8))
	# Red ribbon tied to the king spoke.
	var k := c + Vector2(0, -60)
	Art.toon(ci, PackedVector2Array([k + Vector2(1, 1), k + Vector2(14, 16), k + Vector2(10, 22), k + Vector2(7, 15), k + Vector2(-2, 3)]), Art.RED, 2.2, 0.0)
	Art.toon(ci, PackedVector2Array([k + Vector2(0, 2), k + Vector2(4, 20), k + Vector2(-1, 24), k + Vector2(-2, 16), k + Vector2(-3, 3)]), Art.shade_of(Art.RED, 0.2), 2.2, 0.0)
	Art.t_ellipse(ci, k + Vector2(-8, -1), Vector2(8, 4.5), Art.RED, 2.2, 0.0, 0.35)
	Art.t_ellipse(ci, k + Vector2(8, -1), Vector2(8, 4.5), Art.RED, 2.2, 0.0, -0.35)
	Art.t_circle(ci, k, 3.8, Art.shade_of(Art.RED, 0.15), 2.0, 0.0)
	_sparkle(ci, Vector2(36, -58), 9.0, t, 0.3)
	_sparkle(ci, Vector2(-8, -16), 7.0, t, 2.5)
	_sparkle(ci, Vector2(-54, 40), 7.0, t, 4.5)


static func _diving_watch(ci: CanvasItem, t: float) -> void:
	var c := Vector2(0, -4)
	var strap := Color("ff8a3d")
	# Straps: holes on top, buckle at the bottom.
	Art.t_rect(ci, Rect2(-20, -78, 40, 46), 13, strap, 3.0, 0.4)
	for y: float in [-68.0, -58.0, -48.0]:
		Art.t_circle(ci, Vector2(0, y), 2.6, Art.shade_of(strap, 0.5), 1.5, 0.0)
	Art.t_rect(ci, Rect2(-20, 26, 40, 40), 4, strap, 3.0, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-16, 30, 3, 32), 1.5), Color(1, 1, 1, 0.3))
	Art.t_rect(ci, Rect2(-25, 56, 50, 17), 5, Art.GOLD, 3.0, 0.4)
	Art.t_rect(ci, Rect2(-18, 61, 36, 7), 2, Art.shade_of(strap, 0.3), 2.0, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(0, 53), Vector2(0, 64)]), Art.METAL, 2.5, 1.5)
	# Lugs and crown.
	Art.t_rect(ci, Rect2(-27, -46, 54, 16), 5, GOLD_DEEP, 3.0, 0.3)
	Art.t_rect(ci, Rect2(-27, 22, 54, 16), 5, GOLD_DEEP, 3.0, 0.3)
	Art.t_rect(ci, Rect2(40, -13, 13, 18), 4, Art.GOLD, 2.5, 0.4)
	for i in 3:
		Art.line(ci, Vector2(44 + i * 3.0, -10), Vector2(44 + i * 3.0, 2), GOLD_DEEP, 1.4)
	# Case, bezel and dial.
	Art.t_circle(ci, c, 46, Art.GOLD, 3.0, 0.6)
	Art.t_circle(ci, c, 41, Color("233a73"), 2.5, 0.0)
	for i in 60:
		if i % 5 != 0:
			continue
		var a := -PI / 2.0 + TAU * i / 60.0
		var d := Vector2(cos(a), sin(a))
		if i == 0:
			continue
		Art.line(ci, c + d * 33.5, c + d * 38.5, Art.WHITE, 2.4 if i % 15 == 0 else 1.6)
	Art.toon(ci, PackedVector2Array([c + Vector2(-6.5, -39.5), c + Vector2(6.5, -39.5), c + Vector2(0, -31.5)]), Color("b9ffcf"), 1.8, 0.0)
	var dial := Art.circle_pts(c, 30.0, 40)
	Art.toon(ci, dial, Color("1f63b0"), 2.5, 0.0)
	Art.flat(ci, Art.clipped(Art.circle_pts(c + Vector2(-8, -10), 26.0, 28), dial), Color(1, 1, 1, 0.12))
	for i in 12:
		var a := -PI / 2.0 + TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		if i % 3 == 0:
			Art.push(ci, c + d * 24.0, a)
			Art.t_rect(ci, Rect2(-3.5, -2.2, 7, 4.4), 1.5, Color("dfffe8"), 1.4, 0.0)
			Art.pop(ci)
		else:
			Art.t_circle(ci, c + d * 24.0, 2.3, Color("dfffe8"), 1.2, 0.0)
	# Hands at 10:10, red seconds hand.
	Art.push(ci, c, -PI / 2.0 + TAU * 10.2 / 12.0)
	Art.toon(ci, PackedVector2Array([Vector2(-3, -3.2), Vector2(12, -3.6), Vector2(18, 0), Vector2(12, 3.6), Vector2(-3, 3.2)]), Color("dfffe8"), 1.8, 0.0)
	Art.pop(ci)
	Art.push(ci, c, -PI / 2.0 + TAU * 10.0 / 60.0)
	Art.toon(ci, PackedVector2Array([Vector2(-3, -2.6), Vector2(20, -2.8), Vector2(27, 0), Vector2(20, 2.8), Vector2(-3, 2.6)]), Color("dfffe8"), 1.8, 0.0)
	Art.pop(ci)
	Art.push(ci, c, -PI / 2.0 + TAU * 34.0 / 60.0)
	Art.line(ci, Vector2(-7, 0), Vector2(25, 0), Art.RED, 1.8)
	Art.t_circle(ci, Vector2(18, 0), 2.4, Art.RED, 1.2, 0.0)
	Art.pop(ci)
	Art.t_circle(ci, c, 3.6, Art.GOLD, 1.6, 0.0)
	# Glass shine.
	Art.flat(ci, Art.clipped(Art.ellipse_pts(c + Vector2(-14, -16), Vector2(22, 9), 20, -0.75), dial), Color(1, 1, 1, 0.3))
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-32, -24), Vector2(7, 3.5), 12, -0.9), Color(1, 1, 1, 0.6))
	for b: Vector3 in [Vector3(58, -40, 5.0), Vector3(64, -56, 3.5), Vector3(54, -66, 2.5)]:
		Art.ring(ci, Art.circle_pts(Vector2(b.x, b.y), b.z, 14), Color("2f7fc0"), 2.0)
		Art.flat(ci, Art.circle_pts(Vector2(b.x - b.z * 0.35, b.y - b.z * 0.35), b.z * 0.3, 6), Color(1, 1, 1, 0.9))
	_sparkle(ci, Vector2(-40, -44), 9.0, t, 0.7)
	_sparkle(ci, Vector2(36, 50), 7.0, t, 3.2)


static func _fish_idol(ci: CanvasItem, t: float) -> void:
	var stone := Color("56c2ad")
	# Stepped stone pedestal with gold trim.
	Art.t_rect(ci, Rect2(-60, 54, 120, 18), 5, Art.shade_of(stone, 0.1), 3.0, 0.5)
	Art.t_rect(ci, Rect2(-44, 36, 88, 22), 5, stone, 3.0, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-57, 57, 114, 3.5), 1.5), Art.GOLD)
	Art.flat(ci, Art.rrect_pts(Rect2(-41, 39, 82, 3.5), 1.5), Art.GOLD)
	for i in 4:
		Art.arc(ci, Vector2(-24 + i * 16.0, 54), 6.0, PI + 0.2, TAU - 0.2, 8, Art.shade_of(stone, 0.4), 2.0)
	for x: float in [-48.0, 48.0]:
		_gem(ci, Vector2(x, 64), 3.6, RUBY, 1.4)
	Art.t_rect(ci, Rect2(-10, 12, 20, 26), 4, GOLD_DEEP, 3.0, 0.4)
	# Fins behind the body.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-36, -24), Vector2(-60, -54), Vector2(-72, -48), Vector2(-60, -20),
			Vector2(-73, 6), Vector2(-62, 12), Vector2(-36, -14)]), 3), GOLD_DEEP, 3.0, 0.4)
	for i in 3:
		Art.line(ci, Vector2(-42, -19), Vector2(-64 + i * 1.0, -44 + i * 24.0), Color("a85d10"), 1.8)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, -46), Vector2(-6, -70), Vector2(6, -72), Vector2(24, -48)]), 3), GOLD_DEEP, 3.0, 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(-6, 0), Vector2(-16, 16), Vector2(6, 4)]), GOLD_DEEP, 2.5, 0.0)
	var body := Art.smooth_pts(PackedVector2Array([Vector2(60, -22), Vector2(47, -43), Vector2(18, -55), Vector2(-16, -50), Vector2(-42, -28),
			Vector2(-44, -16), Vector2(-18, 2), Vector2(16, 8), Vector2(46, -2)]), 4)
	Art.toon(ci, body, Art.GOLD, 3.0, 0.7)
	# Scales and gill.
	for row in 3:
		for col in 4 - row:
			var p := Vector2(-24 + col * 12.0 + row * 6.0, -38 + row * 10.0)
			Art.arc(ci, p, 6.0, 0.25, PI - 0.25, 8, Color("d08a1c"), 2.0)
	Art.arc(ci, Vector2(42, -24), 19.0, PI * 0.62, PI * 1.38, 12, Color("c47a14"), 2.4)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(4, -46), Vector2(30, 6), 20, -0.1), body), Color(1, 1, 1, 0.4))
	# Pectoral fin, gem eye and a smile.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(10, -22), Vector2(-8, -12), Vector2(-4, -4), Vector2(14, -14)]), 3), GOLD_DEEP, 2.5, 0.0)
	Art.t_circle(ci, Vector2(38, -31), 9.0, Art.GOLD, 2.5, 0.0)
	_gem(ci, Vector2(38, -31), 6.5, EMERALD, 2.0)
	Art.arc(ci, Vector2(53, -20), 5.0, 0.4, PI * 0.8, 8, Art.INK, 2.2)
	_gem(ci, Vector2(20, -44), 3.5, RUBY, 1.4)
	_sparkle(ci, Vector2(-50, -62), 9.0, t, 0.2)
	_sparkle(ci, Vector2(58, -52), 7.0, t, 2.9)
	_sparkle(ci, Vector2(40, 26), 7.0, t, 4.8)


static func _crystal_lantern(ci: CanvasItem, t: float) -> void:
	# Glow.
	Art.flat(ci, Art.circle_pts(Vector2(0, 4), 76.0, 44), Color(0.78, 0.62, 1.0, 0.16))
	Art.flat(ci, Art.circle_pts(Vector2(0, 4), 58.0, 40), Color(0.8, 0.7, 1.0, 0.2))
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var d := Vector2(cos(a), sin(a))
		Art.flat(ci, PackedVector2Array([Vector2(0, 4) + d * 46.0 + d.orthogonal() * 4.0, Vector2(0, 4) + d * 70.0, Vector2(0, 4) + d * 46.0 - d.orthogonal() * 4.0]), Color(1, 0.95, 1.0, 0.4))
	# Handle and cap.
	Art.arc(ci, Vector2(0, -56), 15.0, PI, TAU, 18, Art.INK, 10.0)
	Art.arc(ci, Vector2(0, -56), 15.0, PI, TAU, 18, Art.BRASS, 5.0)
	Art.t_circle(ci, Vector2(0, -56), 6.5, GOLD_DEEP, 2.5, 0.3)
	Art.toon(ci, PackedVector2Array([Vector2(-18, -54), Vector2(18, -54), Vector2(38, -34), Vector2(-38, -34)]), Art.BRASS, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-41, -38, 82, 9), 4, GOLD_DEEP, 3.0, 0.0)
	# Glass with the glowing crystal.
	var glass := Art.rrect_pts(Rect2(-31, -30, 62, 68), 6)
	Art.toon(ci, glass, Color("e4fbff"), 3.0, 0.0)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(0, 10), 30.0, 32), glass), Color(0.78, 0.6, 1.0, 0.45))
	Art.flat(ci, Art.circle_pts(Vector2(0, 12), 16.0, 24), Color(1, 1, 1, 0.5))
	Art.crystal(ci, Vector2(-13, 36), 30, 8, -0.35, Color("7fe0ff"), 2.4)
	Art.crystal(ci, Vector2(14, 36), 34, 8, 0.3, Color("ff8fd0"), 2.4)
	Art.crystal(ci, Vector2(0, 37), 56, 12, 0.0, Color("b58cff"), 2.6)
	Art.flat(ci, Art.rrect_pts(Rect2(-24, -24, 5, 54), 2.5), Color(1, 1, 1, 0.55))
	Art.flat(ci, Art.rrect_pts(Rect2(-16, -24, 2.5, 30), 1.2), Color(1, 1, 1, 0.45))
	for sx: float in [-1.0, 1.0]:
		Art.t_rect(ci, Rect2(31 * sx - 4, -32, 8, 72), 3, Art.BRASS, 2.5, 0.0)
	# Base.
	Art.toon(ci, PackedVector2Array([Vector2(-38, 38), Vector2(38, 38), Vector2(30, 54), Vector2(-30, 54)]), Art.BRASS, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-43, 52, 86, 12), 5, GOLD_DEEP, 3.0, 0.3)
	for x: float in [-18.0, 0.0, 18.0]:
		_gem(ci, Vector2(x, 45), 3.6 if x != 0.0 else 4.5, [SAPPHIRE, RUBY, SAPPHIRE][int(x / 18.0) + 1], 1.4)
	_sparkle(ci, Vector2(-50, -40), 9.0, t, 0.0)
	_sparkle(ci, Vector2(48, -10), 7.0, t, 2.0)
	_sparkle(ci, Vector2(8, -12), 8.0, t, 4.0)


static func _arrowhead(tip: Vector2) -> PackedVector2Array:
	return PackedVector2Array([tip, tip + Vector2(11, 22), tip + Vector2(4.5, 18), tip + Vector2(-4.5, 18), tip + Vector2(-11, 22)])


static func _trident(ci: CanvasItem, t: float) -> void:
	Art.push(ci, Vector2(2, 0), 0.22)
	var head := Art.union([
		PackedVector2Array([Vector2(-44, -56), Vector2(-44, -44), Vector2(-38, -32), Vector2(-24, -24), Vector2(0, -20), Vector2(24, -24),
				Vector2(38, -32), Vector2(44, -44), Vector2(44, -56), Vector2(34, -56), Vector2(34, -46), Vector2(29, -38), Vector2(18, -33),
				Vector2(0, -31), Vector2(-18, -33), Vector2(-29, -38), Vector2(-34, -46), Vector2(-34, -56)]),
		Art.rrect_pts(Rect2(-5, -64, 10, 46), 2),
		_arrowhead(Vector2(0, -80)),
		_arrowhead(Vector2(-39, -72)),
		_arrowhead(Vector2(39, -72)),
	])
	# Shaft with teal wraps and a pearl pommel.
	Art.t_rect(ci, Rect2(-5.5, -14, 11, 80), 4, GOLD_DEEP, 3.0, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-3.5, -10, 2.5, 70), 1.2), GOLD_LIGHT)
	for y: float in [8.0, 34.0]:
		Art.t_rect(ci, Rect2(-7.5, y, 15, 12), 3, Art.TEAL, 2.2, 0.0)
		Art.line(ci, Vector2(-6, y + 4), Vector2(6, y + 2), Art.shade_of(Art.TEAL, 0.4), 1.4)
		Art.line(ci, Vector2(-6, y + 9), Vector2(6, y + 7), Art.shade_of(Art.TEAL, 0.4), 1.4)
	Art.t_rect(ci, Rect2(-9, 60, 18, 9), 3, Art.GOLD, 2.5, 0.0)
	_pearl(ci, Vector2(0, 73), 6.5, 2.2)
	Art.toon(ci, head, Art.GOLD, 3.0, 0.5)
	Art.line(ci, Vector2(0, -60), Vector2(0, -34), GOLD_DEEP, 2.0)
	for sx: float in [-1.0, 1.0]:
		Art.line(ci, Vector2(39 * sx, -54), Vector2(39 * sx, -44), GOLD_DEEP, 2.0)
		Art.flat(ci, Art.circle_pts(Vector2(39 * sx - 2, -64), 1.5, 6), Color(1, 1, 1, 0.8))
	Art.flat(ci, Art.circle_pts(Vector2(-2, -72), 1.6, 6), Color(1, 1, 1, 0.8))
	# Collar with a big sapphire.
	Art.t_rect(ci, Rect2(-14, -26, 28, 14), 5, GOLD_DEEP, 3.0, 0.3)
	_gem(ci, Vector2(0, -19), 6.0, SAPPHIRE, 2.0)
	for sx: float in [-1.0, 1.0]:
		_gem(ci, Vector2(24 * sx, -26), 3.2, RUBY, 1.4)
	Art.pop(ci)
	# Red cloth tied below the head, fluttering to the right (screen space).
	var k := Vector2(4, -6)
	Art.toon(ci, PackedVector2Array([k + Vector2(1, -2), k + Vector2(22, 6), k + Vector2(30, 2), k + Vector2(26, 12), k + Vector2(2, 4)]), Art.RED, 2.2, 0.0)
	Art.toon(ci, PackedVector2Array([k + Vector2(0, 1), k + Vector2(16, 16), k + Vector2(18, 25), k + Vector2(10, 20), k + Vector2(-2, 5)]), Art.shade_of(Art.RED, 0.2), 2.2, 0.0)
	Art.t_circle(ci, k, 4.0, Art.shade_of(Art.RED, 0.1), 2.0, 0.0)
	_sparkle(ci, Vector2(-32, -74), 9.0, t, 0.6)
	_sparkle(ci, Vector2(48, -30), 7.0, t, 2.7)
	_sparkle(ci, Vector2(-22, 50), 7.0, t, 4.6)


static func _treasure_key(ci: CanvasItem, t: float) -> void:
	# A red tassel hanging from the bow (drawn first so it hangs behind).
	Art.stroke(ci, PackedVector2Array([Vector2(-44, -18), Vector2(-50, -2), Vector2(-52, 12)]), Art.RED, 2.5, 1.8)
	Art.t_circle(ci, Vector2(-52, 14), 5.0, Art.GOLD, 2.2, 0.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-57, 17), Vector2(-47, 17), Vector2(-44, 34), Vector2(-52, 38), Vector2(-60, 34)]), 3), Art.RED, 2.5, 0.4)
	for i in 3:
		Art.line(ci, Vector2(-55 + i * 3.0, 22), Vector2(-56 + i * 4.0, 34), Art.shade_of(Art.RED, 0.35), 1.4)
	Art.push(ci, Vector2(0, 0), PI / 4.0)
	var bow := Art.union([Art.circle_pts(Vector2(-44, -14), 15.0, 24), Art.circle_pts(Vector2(-44, 14), 15.0, 24),
			Art.circle_pts(Vector2(-59, 0), 15.0, 24), Art.circle_pts(Vector2(-33, 0), 12.0, 20)])
	var bit := PackedVector2Array([Vector2(38, 3), Vector2(60, 3), Vector2(60, 30), Vector2(54, 30), Vector2(54, 22), Vector2(47, 22),
			Vector2(47, 30), Vector2(38, 30)])
	Art.toon(ci, bit, Art.GOLD, 3.0, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(41, 8, 16, 3), 1.5), GOLD_LIGHT)
	Art.t_rect(ci, Rect2(-36, -5.5, 98, 11), 5.5, Art.GOLD, 3.0, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-22, -3.5, 70, 2.8), 1.4), GOLD_LIGHT)
	Art.t_circle(ci, Vector2(64, 0), 6.5, GOLD_DEEP, 3.0, 0.0)
	Art.t_rect(ci, Rect2(20, -8, 7, 16), 3, GOLD_DEEP, 2.5, 0.0)
	Art.t_rect(ci, Rect2(-24, -9, 8, 18), 3, GOLD_DEEP, 2.5, 0.0)
	Art.toon(ci, bow, Art.GOLD, 3.0, 0.0)
	Art.arc(ci, Vector2(-47, 0), 13.5, 0, TAU, 28, GOLD_DEEP, 2.4)
	for p: Vector2 in [Vector2(-44, -22), Vector2(-44, 22), Vector2(-66, 0)]:
		_pearl(ci, p, 3.4, 1.4)
	Art.pop(ci)
	# The ruby is drawn upright so its glint stays top-left.
	_gem(ci, Vector2(-47, 0).rotated(PI / 4.0), 8.0, RUBY, 2.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(-47, 0).rotated(PI / 4.0) + Vector2(-2, -18), Vector2(7, 3), 12, -0.2), Color(1, 1, 1, 0.45))
	_sparkle(ci, Vector2(50, 22), 9.0, t, 0.4)
	_sparkle(ci, Vector2(-8, -62), 8.0, t, 2.6)
	_sparkle(ci, Vector2(8, 10), 6.0, t, 4.4)


static func _star_map(ci: CanvasItem, t: float) -> void:
	var paper := Color("f7e4b6")
	Art.push(ci, Vector2(0, 2), 0.0, Vector2(0.95, 0.95))
	# Wax seal ribbon tails behind the paper.
	Art.toon(ci, PackedVector2Array([Vector2(34, 48), Vector2(42, 48), Vector2(38, 78), Vector2(33, 72), Vector2(28, 78)]), SAPPHIRE, 2.5, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(44, 46), Vector2(52, 50), Vector2(56, 76), Vector2(50, 71), Vector2(45, 76)]), Art.shade_of(SAPPHIRE, 0.2), 2.5, 0.0)
	var sheet := Art.smooth_pts(PackedVector2Array([Vector2(-54, -54), Vector2(54, -54), Vector2(57, 0), Vector2(55, 50), Vector2(38, 56),
			Vector2(18, 51), Vector2(0, 56), Vector2(-20, 51), Vector2(-38, 57), Vector2(-55, 50), Vector2(-57, 0)]), 4)
	Art.toon(ci, sheet, paper, 3.0, 0.4)
	for p: Vector2 in [Vector2(-46, 30), Vector2(44, -40), Vector2(-40, -38)]:
		Art.flat(ci, Art.circle_pts(p, 3.0, 10), Color(0.75, 0.55, 0.3, 0.25))
	# Round sky chart.
	var sky := Art.circle_pts(Vector2(0, 2), 40.0, 44)
	Art.toon(ci, sky, Color("1d2d6b"), 2.5, 0.0)
	Art.ring(ci, Art.ellipse_pts(Vector2(0, 2), Vector2(16, 40), 32), Color(1, 1, 1, 0.14), 1.4)
	Art.ring(ci, Art.circle_pts(Vector2(0, 2), 22.0, 32), Color(1, 1, 1, 0.14), 1.4)
	Art.line(ci, Vector2(-40, 2), Vector2(40, 2), Color(1, 1, 1, 0.14), 1.4)
	Art.arc(ci, Vector2(0, 2), 40.0, 0, TAU, 48, Art.GOLD, 3.0)
	var stars: Array[Vector2] = [Vector2(-24, -14), Vector2(-10, -22), Vector2(4, -8), Vector2(-4, 14), Vector2(16, 20), Vector2(26, 6)]
	var chain := PackedVector2Array()
	for s in stars:
		chain.append(s)
	Art.polyline(ci, chain, Color(1.0, 0.85, 0.4, 0.8), 1.6)
	for i in stars.size():
		var r := 5.5 if i % 2 == 0 else 4.0
		Art.flat(ci, Art.star_pts(stars[i], r, r * 0.36, 4), GOLD_LIGHT)
	for p: Vector2 in [Vector2(-30, 10), Vector2(-18, 28), Vector2(8, -30), Vector2(30, -10), Vector2(-6, 34), Vector2(14, -18)]:
		Art.flat(ci, Art.circle_pts(p, 1.3, 6), Color(1, 1, 1, 0.9))
	# Crescent moon, upper right.
	Art.t_circle(ci, Vector2(22, -18), 8.5, Color("fff4c2"), 1.8, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(26.5, -21.5), 7.5, 20), Color("1d2d6b"))
	# Top roll with golden knobs.
	Art.t_rect(ci, Rect2(-60, -70, 120, 20), 10, Color("ecd29a"), 3.0, 0.5)
	Art.line(ci, Vector2(-54, -56), Vector2(54, -56), Art.shade_of(paper, 0.3), 1.8)
	for sx: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(64 * sx, -60), 7.5, GOLD_DEEP, 3.0, 0.4)
		Art.flat(ci, Art.circle_pts(Vector2(64 * sx - 2, -62), 2.0, 8), Color(1, 1, 1, 0.7))
	# Compass star and a wax seal.
	Art.toon(ci, Art.star_pts(Vector2(-40, 40), 10.0, 2.8, 4), Art.RED, 1.8, 0.0)
	Art.toon(ci, Art.star_pts(Vector2(-40, 40), 6.0, 2.0, 4, -PI / 4.0), Art.INK_SOFT, 1.2, 0.0)
	Art.t_circle(ci, Vector2(42, 46), 12.0, Color("d9344c"), 3.0, 0.5)
	Art.toon(ci, Art.star_pts(Vector2(42, 45), 6.0, 2.6, 5), Color("ff6f7e"), 0.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(37, 40), Vector2(3, 1.8), 8, -0.6), Color(1, 1, 1, 0.6))
	Art.pop(ci)
	_sparkle(ci, Vector2(-8, -18), 8.0, t, 0.9)
	_sparkle(ci, Vector2(24, 20), 7.0, t, 3.1)
	_sparkle(ci, Vector2(-56, -40), 7.0, t, 5.0)


static func _sun_medallion(ci: CanvasItem, t: float) -> void:
	var c := Vector2(0, 12)
	# Ribbon.
	Art.toon(ci, PackedVector2Array([Vector2(-26, -74), Vector2(-8, -76), Vector2(8, -44), Vector2(-6, -40)]), SAPPHIRE, 3.0, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(26, -74), Vector2(8, -76), Vector2(-8, -44), Vector2(6, -40)]), Art.shade_of(SAPPHIRE, 0.2), 3.0, 0.0)
	Art.line(ci, Vector2(-17, -73), Vector2(0, -42), Color(1, 1, 1, 0.5), 2.0)
	_ring(ci, Vector2(0, -50), 7.0, Art.GOLD, 4.0)
	# Rays.
	Art.toon(ci, Art.star_pts(c, 66.0, 44.0, 16), Color("ff9f1c"), 3.0, 0.0)
	Art.toon(ci, Art.star_pts(c, 57.0, 43.0, 16, -PI / 2.0 + PI / 16.0), Art.GOLD, 2.5, 0.0)
	# Disc with an engraved rim and little rubies.
	Art.t_circle(ci, c, 45.0, Art.GOLD, 3.0, 0.6)
	Art.arc(ci, c, 39.0, 0, TAU, 48, GOLD_DEEP, 2.2)
	for i in 24:
		var a := TAU * i / 24.0
		if i % 6 == 3:
			continue
		Art.flat(ci, Art.circle_pts(c + Vector2(cos(a), sin(a)) * 42.0, 1.2, 6), GOLD_DEEP)
	for i in 4:
		var a := PI / 4.0 + PI / 2.0 * i
		_gem(ci, c + Vector2(cos(a), sin(a)) * 42.0, 4.2, RUBY, 1.6)
	var face_c := c + Vector2(0, 1)
	Art.t_circle(ci, face_c, 33.0, Color("ffd95e"), 2.2, 0.5)
	# Sleepy-happy sun face.
	for sx: float in [-1.0, 1.0]:
		var e := face_c + Vector2(11 * sx, -5)
		Art.flat(ci, Art.ellipse_pts(e, Vector2(4.2, 5.4), 14), Art.INK)
		Art.flat(ci, Art.circle_pts(e + Vector2(-1.3, -2.0), 1.6, 8), Art.WHITE)
		Art.flat(ci, Art.circle_pts(e + Vector2(1.4, 1.8), 0.8, 6), Art.WHITE)
		Art.flat(ci, Art.ellipse_pts(face_c + Vector2(19 * sx, 6), Vector2(5, 3.2), 12), Color(1.0, 0.45, 0.45, 0.45))
		Art.arc(ci, e + Vector2(0, -9), 4.0, PI + 0.5, TAU - 0.5, 8, GOLD_DEEP, 2.0)
	var m := face_c + Vector2(0, 9)
	Art.toon(ci, PackedVector2Array([m + Vector2(-7, -1), m + Vector2(7, -1), m + Vector2(5, 3.5), m + Vector2(0, 5.5), m + Vector2(-5, 3.5)]), Color("b8324a"), 1.8, 0.0)
	Art.flat(ci, Art.ellipse_pts(m + Vector2(0, 3), Vector2(3, 1.5), 10), Color("ff8fa0"))
	Art.flat(ci, Art.clipped(Art.ellipse_pts(face_c + Vector2(-12, -18), Vector2(16, 7), 16, -0.5), Art.circle_pts(face_c, 33.0, 40)), Color(1, 1, 1, 0.35))
	_sparkle(ci, Vector2(-44, -30), 10.0, t, 0.1)
	_sparkle(ci, Vector2(50, 50), 8.0, t, 2.3)
	_sparkle(ci, Vector2(30, -24), 6.0, t, 4.4)
