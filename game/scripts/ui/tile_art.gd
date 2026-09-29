class_name TileArt
extends RefCounted
## Match-3 board pieces, drawn with Art's toon kit in local space and
## centered at (0,0), each fitting a 56x56 cell. Every kind has its own
## color AND its own silhouette so kids and color-blind players can tell
## them apart. Callers place pieces with Art.push/pop.

const KINDS: Array[String] = ["pearl", "shell", "starfish", "coral", "fish", "urchin"]
const SPECIALS: Array[String] = ["rocket_h", "rocket_v", "bomb", "rainbow"]
const BLOCKERS: Array[String] = ["sand", "bubble"]

const PEARL := Color("fff1f7")
const SHELL := Color("ff9a3c")
const STAR := Color("ffd23f")
const CORAL := Color("ff4a5f")
const FISH := Color("3a9bf5")
const URCHIN := Color("a36bff")

const _W := 3.0          # outline width at cell scale


## Board piece. `selected` makes it a little brighter, pulsing, with a glow ring.
static func draw(ci: CanvasItem, kind: String, t: float, selected: bool = false) -> void:
	var lift := 0.0
	if selected:
		lift = 0.14
		var s := 1.06 + sin(t * 7.0) * 0.03
		Art.push(ci, Vector2.ZERO, 0.0, Vector2(s, s))
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, 30.0, 32), Color(1, 1, 1, 0.22))
		Art.flat(ci, Art.circle_pts(Vector2.ZERO, 26.0, 32), Color(1, 1, 1, 0.3))
	match kind:
		"pearl": _pearl(ci, t, lift)
		"shell": _shell(ci, t, lift)
		"starfish": _starfish(ci, t, lift)
		"coral": _coral(ci, t, lift)
		"fish": _fish(ci, t, lift)
		"urchin": _urchin(ci, t, lift)
	if selected:
		Art.ring(ci, Art.circle_pts(Vector2.ZERO, 27.5, 40), Color(1, 1, 1, 0.95), 3.0)
		Art.pop(ci)


static func _c(c: Color, lift: float) -> Color:
	return c.lightened(lift) if lift > 0.0 else c


## Round rod with round ends from a to b (coral branches, mine horns).
static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var ang := (b - a).angle()
	var pts := PackedVector2Array()
	for i in 9:
		var q := ang - PI / 2.0 + PI * i / 8.0
		pts.append(b + Vector2(cos(q), sin(q)) * r)
	for i in 9:
		var q := ang + PI / 2.0 + PI * i / 8.0
		pts.append(a + Vector2(cos(q), sin(q)) * r)
	return pts


## Little 4-point twinkle that grows and shrinks with t.
static func _twinkle(ci: CanvasItem, pos: Vector2, size: float, t: float, phase: float) -> void:
	var s := maxf(0.0, sin(t * 2.6 + phase))
	if s < 0.08:
		return
	Art.push(ci, pos, 0.0, Vector2(s, s) * size)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 1.0, 0.24, 4), Color(1, 1, 1, 0.95))
	Art.pop(ci)


static func _shine(ci: CanvasItem, c: Vector2, radii: Vector2, rot: float) -> void:
	Art.flat(ci, Art.ellipse_pts(c, radii, 14, rot), Color(1, 1, 1, 0.8))


# --- Kinds ---------------------------------------------------------------------------

static func _pearl(ci: CanvasItem, t: float, lift: float) -> void:
	var body := Art.circle_pts(Vector2.ZERO, 21.0, 36)
	Art.toon(ci, body, _c(PEARL, lift), _W, 0.7)
	# Pink sheen on the lower right, then a big glossy highlight.
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(7, 8), 17.0, 28), body), Color(1.0, 0.62, 0.8, 0.35))
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(11, 12), 11.0, 24), body), Color(0.72, 0.62, 1.0, 0.3))
	_shine(ci, Vector2(-7, -9), Vector2(7.5, 4.5), -0.7)
	Art.flat(ci, Art.circle_pts(Vector2(-12.5, -1.5), 2.0, 10), Color(1, 1, 1, 0.85))
	_twinkle(ci, Vector2(10, -11), 6.0, t, 0.0)


static func _shell_body() -> PackedVector2Array:
	var polys := []
	var fan := PackedVector2Array([Vector2(-6, 17), Vector2(6, 17)])
	for i in 13:
		var a := TAU - 0.32 - (PI - 0.64) * i / 12.0
		fan.append(Vector2(0, 14) + Vector2(cos(a), sin(a)) * 25.0)
	polys.append(fan)
	for i in 7:
		var a := PI + 0.36 + (PI - 0.72) * i / 6.0
		polys.append(Art.circle_pts(Vector2(0, 14) + Vector2(cos(a), sin(a)) * 24.0, 5.2, 14))
	return Art.union(polys)


static func _shell(ci: CanvasItem, t: float, lift: float) -> void:
	var col := _c(SHELL, lift)
	Art.push(ci, Vector2(0, -1), sin(t * 1.7) * 0.03)
	# Hinge "ears" behind the fan.
	Art.toon(ci, PackedVector2Array([Vector2(-11, 12), Vector2(11, 12), Vector2(8, 21), Vector2(-8, 21)]), Art.shade_of(col, 0.2), _W, 0.0)
	Art.toon(ci, _shell_body(), col, _W, 0.6)
	for i in 7:
		var a := PI + 0.36 + (PI - 0.72) * i / 6.0
		var d := Vector2(cos(a), sin(a))
		Art.line(ci, Vector2(0, 14) + d * 5.0, Vector2(0, 14) + d * 23.0, Art.shade_of(col, 0.35), 2.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -5), Vector2(5, 2.6), 12, -0.8), Color(1, 1, 1, 0.7))
	Art.flat(ci, Art.circle_pts(Vector2(0, 16), 2.2, 10), Color(1, 1, 1, 0.55))
	Art.pop(ci)


static func _starfish(ci: CanvasItem, t: float, lift: float) -> void:
	var col := _c(STAR, lift)
	Art.push(ci, Vector2(0, 1.5), sin(t * 1.4) * 0.07)
	Art.toon(ci, Art.smooth_pts(Art.star_pts(Vector2.ZERO, 25.0, 11.5, 5), 3), col, _W, 0.6)
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		var d := Vector2(cos(a), sin(a))
		Art.flat(ci, Art.circle_pts(d * 8.0, 2.0, 8), Color("ff9f1c"))
		Art.flat(ci, Art.circle_pts(d * 14.5, 1.5, 8), Color("ff9f1c"))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 3.0, 10), Color("ff9f1c"))
	Art.flat(ci, Art.ellipse_pts(Vector2(-6, -9), Vector2(3.8, 2.0), 10, -1.1), Color(1, 1, 1, 0.75))
	Art.pop(ci)


static func _coral_body() -> PackedVector2Array:
	return Art.union([
		_capsule(Vector2(0, 21), Vector2(0, 3), 6.0),
		_capsule(Vector2(0, 8), Vector2(-12, -6), 5.2),
		_capsule(Vector2(-12, -6), Vector2(-13, -19), 4.6),
		_capsule(Vector2(-12, -4), Vector2(-21, -2), 4.2),
		_capsule(Vector2(0, 5), Vector2(12, -8), 5.2),
		_capsule(Vector2(12, -8), Vector2(9, -21), 4.6),
		_capsule(Vector2(12, -8), Vector2(21, -12), 4.2),
		_capsule(Vector2(0, 4), Vector2(-1, -12), 4.6),
		Art.ellipse_pts(Vector2(0, 21), Vector2(12, 4.5), 16),
	])


static func _coral(ci: CanvasItem, t: float, lift: float) -> void:
	var col := _c(CORAL, lift)
	Art.push(ci, Vector2(0, 21), sin(t * 1.6) * 0.04)
	Art.push(ci, Vector2(0, -21))
	Art.toon(ci, _coral_body(), col, _W, 0.55)
	for p: Vector2 in [Vector2(-13, -19), Vector2(-21, -2), Vector2(9, -21), Vector2(21, -12), Vector2(-1, -12)]:
		Art.flat(ci, Art.circle_pts(p + Vector2(-0.6, -0.6), 2.2, 10), Color("ffb3bd"))
	for p: Vector2 in [Vector2(-6, 2), Vector2(6, 0), Vector2(0, 13), Vector2(-9, -12), Vector2(12, -14)]:
		Art.flat(ci, Art.circle_pts(p, 1.3, 8), Art.shade_of(col, 0.3))
	Art.pop(ci)
	Art.pop(ci)


static func _fish(ci: CanvasItem, t: float, lift: float) -> void:
	var col := _c(FISH, lift)
	var fin := Art.shade_of(col, 0.25)
	Art.push(ci, Vector2(0, sin(t * 2.2) * 1.2))
	# Tail wags behind the body.
	Art.push(ci, Vector2(-12, 0), sin(t * 5.0) * 0.18)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(3, 0), Vector2(-12, -14), Vector2(-9, 0), Vector2(-12, 14)]), 3), fin, _W, 0.0)
	Art.pop(ci)
	Art.toon(ci, PackedVector2Array([Vector2(-8, -10), Vector2(-2, -21), Vector2(8, -18), Vector2(10, -10)]), fin, _W, 0.0)
	var body := Art.ellipse_pts(Vector2(3, 1), Vector2(18, 14), 30)
	Art.toon(ci, body, col, _W, 0.6)
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(3, 12), Vector2(17, 7), 24), body), Color("bfe6ff"))
	# Stripe and side fin.
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-6, -16, 4, 32), 2), body), Art.shade_of(col, 0.2))
	Art.push(ci, Vector2(0, 5), sin(t * 4.0) * 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(0, 0), Vector2(-9, -3), Vector2(-7, 5)]), fin, 2.0, 0.0)
	Art.pop(ci)
	# Big cute eye and a smile.
	Art.t_circle(ci, Vector2(10, -3), 5.8, Art.WHITE, 2.0, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(11.2, -2.6), 3.4, 14), Art.INK)
	Art.flat(ci, Art.circle_pts(Vector2(10.2, -4), 1.3, 8), Art.WHITE)
	Art.arc(ci, Vector2(15.5, 3.5), 3.0, 0.3, PI - 0.9, 6, Art.INK, 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-2, -8), Vector2(4, 2), 10, -0.3), Color(1, 1, 1, 0.6))
	Art.pop(ci)


static func _urchin(ci: CanvasItem, t: float, lift: float) -> void:
	var col := _c(URCHIN, lift)
	Art.push(ci, Vector2.ZERO, sin(t * 1.2) * 0.06)
	Art.toon(ci, Art.star_pts(Vector2.ZERO, 25.5, 14.0, 14), Art.shade_of(col, 0.3), 2.6, 0.0)
	Art.pop(ci)
	Art.toon(ci, Art.circle_pts(Vector2.ZERO, 16.0, 30), col, _W, 0.7)
	for p: Vector2 in [Vector2(-6, 4), Vector2(3, 8), Vector2(7, -1), Vector2(-1, -4), Vector2(-9, -4), Vector2(9, 7)]:
		Art.flat(ci, Art.circle_pts(p, 1.6, 8), Art.shade_of(col, 0.3))
	_shine(ci, Vector2(-5, -8), Vector2(5, 2.8), -0.6)


# --- Specials --------------------------------------------------------------------------

## Power pieces: "rocket_h", "rocket_v", "bomb", "rainbow".
static func special(ci: CanvasItem, kind: String, t: float) -> void:
	match kind:
		"rocket_h":
			_rocket(ci, t, 0.0)
		"rocket_v":
			_rocket(ci, t, -PI / 2.0)
		"bomb":
			_mine(ci, t)
		"rainbow":
			_rainbow(ci, t)


static func _rocket(ci: CanvasItem, t: float, rot: float) -> void:
	Art.push(ci, Vector2.ZERO, rot)
	# Glowing streak across the whole cell shows which line it clears.
	Art.flat(ci, Art.rrect_pts(Rect2(-28, -6, 56, 12), 6), Color(1, 1, 1, 0.3))
	Art.flat(ci, Art.rrect_pts(Rect2(-28, -2.5, 56, 5), 2.5), Color(1, 1, 0.85, 0.6))
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(1.1, 1.1))
	Art.push(ci, Vector2(sin(t * 9.0) * 0.8, 0))
	# Bubbles from the propeller.
	for i in 3:
		var f := fposmod(t * 1.6 + i / 3.0, 1.0)
		Art.push(ci, Vector2(-19.0 - f * 5.0, (i - 1) * 3.5), 0.0, Vector2.ONE * (1.0 - f * 0.6))
		Art.ring(ci, Art.circle_pts(Vector2.ZERO, 2.4, 10), Color(1, 1, 1, 0.9), 1.4)
		Art.pop(ci)
	var fin := Color("3a7ff0")
	Art.toon(ci, PackedVector2Array([Vector2(-7, -5), Vector2(-17, -15), Vector2(-20, -13), Vector2(-16, -4)]), fin, 2.5, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-7, 5), Vector2(-17, 15), Vector2(-20, 13), Vector2(-16, 4)]), fin, 2.5, 0.0)
	Art.toon(ci, _capsule(Vector2(-14, 0), Vector2(8, 0), 8.5), Art.GOLD, 2.8, 0.6)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(7, -8.4), Vector2(17, -6), Vector2(23, 0), Vector2(17, 6), Vector2(7, 8.4)]), 3), Art.RED, 2.8, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-12, -8, 4, 16), 1.5), Art.RED)
	Art.t_circle(ci, Vector2(-0.5, 0), 4.2, Color("bff3ff"), 2.0, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(-1.8, -1.3), 1.3, 8), Art.WHITE)
	Art.flat(ci, Art.rrect_pts(Rect2(-12, -6.5, 17, 2.4), 1.2), Color(1, 1, 1, 0.6))
	Art.toon(ci, Art.rrect_pts(Rect2(-21, -3.5, 5, 7), 1.5), Art.METAL, 2.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)
	Art.pop(ci)


static func _mine(ci: CanvasItem, t: float) -> void:
	# Soft red glow that breathes.
	var g := 1.0 + sin(t * 5.0) * 0.08
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(g, g))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 27.0, 32), Color(1.0, 0.45, 0.35, 0.22))
	Art.pop(ci)
	var body := Color("46558f")
	for i in 8:
		var a := -PI / 2.0 + TAU * (i + 0.5) / 8.0
		Art.push(ci, Vector2.ZERO, a)
		Art.toon(ci, _capsule(Vector2(10, 0), Vector2(20, 0), 3.4), Art.METAL, 2.4, 0.0)
		Art.pop(ci)
	Art.toon(ci, Art.circle_pts(Vector2(0, 2), 16.5, 32), body, _W, 0.7)
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-20, 2, 40, 4), 1), Art.circle_pts(Vector2(0, 2), 16.5, 32)), Art.GOLD)
	# Cute determined face.
	for sx: float in [-1.0, 1.0]:
		Art.flat(ci, Art.ellipse_pts(Vector2(5.5 * sx, -2), Vector2(2.4, 3.0), 10), Art.WHITE)
		Art.flat(ci, Art.circle_pts(Vector2(5.5 * sx + 0.4, -1.6), 1.4, 8), Art.INK)
		Art.line(ci, Vector2(8.5 * sx, -7.5), Vector2(3 * sx, -5.8), Art.WHITE, 1.6)
	Art.arc(ci, Vector2(0, 9), 3.5, PI + 0.5, TAU - 0.5, 8, Art.WHITE, 1.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -8), Vector2(4, 2.2), 10, -0.7), Color(1, 1, 1, 0.5))
	# Blinking light on top.
	Art.t_rect(ci, Rect2(-4, -17.5, 8, 5), 1.5, Art.METAL, 2.0, 0.0)
	var on := fposmod(t, 0.8) < 0.4
	Art.t_circle(ci, Vector2(0, -20), 4.2, Art.RED if on else Color("a8323a"), 2.0, 0.0)
	if on:
		Art.flat(ci, Art.circle_pts(Vector2(-1.2, -21.2), 1.3, 8), Color(1, 1, 1, 0.9))


static func _rainbow_bands() -> Array:
	var cols := [Color("ff4d5e"), Color("ff9a3c"), Color("ffd23f"), Color("5cd05f"), Color("3aa6f0"), Color("9a6cf0")]
	var clip := Art.circle_pts(Vector2.ZERO, 21.0, 36)
	var out := []
	for i in cols.size():
		var r := PackedVector2Array()
		for p: Vector2 in [Vector2(-24 + i * 8, -40), Vector2(-16 + i * 8, -40), Vector2(-16 + i * 8, 40), Vector2(-24 + i * 8, 40)]:
			r.append(p.rotated(0.55))
		out.append([Art.clipped(r, clip), cols[i]])
	return out


static func _rainbow(ci: CanvasItem, t: float) -> void:
	var g := 1.0 + sin(t * 4.0) * 0.06
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(g, g))
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, 28.0, 32), Color(1, 0.95, 0.7, 0.3))
	Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 21.0, Art.WHITE, _W, 0.0)
	for b: Array in _rainbow_bands():
		Art.flat(ci, b[0], b[1])
	var body := Art.circle_pts(Vector2.ZERO, 21.0, 36)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-6, -7), 17.0, 28), body), Color(1, 1, 1, 0.35))
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(6, 22), 18.0, 28), body), Color(0.18, 0.12, 0.38, 0.22))
	_shine(ci, Vector2(-7, -9), Vector2(7, 4), -0.7)
	# Twinkles circling around.
	for i in 3:
		Art.push(ci, Vector2.ZERO, t * 1.2 + TAU * i / 3.0)
		_twinkle(ci, Vector2(22, 0), 5.5, t, i * 2.1)
		Art.pop(ci)


# --- Blockers --------------------------------------------------------------------------

## "sand": sand block filling the cell (1 or 2+ layers look different).
## "bubble": translucent bubble drawn OVER a piece (2+ layers = double wall).
static func blocker(ci: CanvasItem, kind: String, layers: int) -> void:
	match kind:
		"sand":
			_sand(ci, layers)
		"bubble":
			_bubble(ci, layers)


static func _sand(ci: CanvasItem, layers: int) -> void:
	var block := Art.rrect_pts(Rect2(-27, -27, 54, 54), 9)
	if layers >= 2:
		Art.toon(ci, block, Art.SAND_DARK, _W, 0.6)
		# A lighter heap of sand on top of the packed block.
		var heap := Art.clipped(Art.smooth_pts(PackedVector2Array([Vector2(-30, -8), Vector2(-16, -14), Vector2(-4, -10), Vector2(10, -16),
				Vector2(24, -11), Vector2(30, -8), Vector2(30, -40), Vector2(-30, -40)]), 3), block)
		Art.toon(ci, heap, Art.SAND, 2.2, 0.0)
		for p: Vector2 in [Vector2(-16, 4), Vector2(-4, 14), Vector2(12, 6), Vector2(18, 18), Vector2(-19, 19), Vector2(4, -1)]:
			Art.flat(ci, Art.circle_pts(p, 1.6, 8), Art.shade_of(Art.SAND_DARK, 0.3))
		Art.polyline(ci, PackedVector2Array([Vector2(-8, 3), Vector2(-3, 8), Vector2(-6, 13), Vector2(-1, 19)]), Art.shade_of(Art.SAND_DARK, 0.35), 1.8)
		Art.polyline(ci, PackedVector2Array([Vector2(14, -4), Vector2(10, 2), Vector2(13, 8)]), Art.shade_of(Art.SAND_DARK, 0.35), 1.8)
		for p: Vector2 in [Vector2(-18, -20), Vector2(-6, -21), Vector2(8, -20), Vector2(18, -21)]:
			Art.flat(ci, Art.circle_pts(p, 1.3, 8), Art.SAND_DARK)
		Art.push(ci, Vector2(15, -19), 0.3, Vector2(0.36, 0.36))
		_shell_deco(ci, Color("ffb3c7"))
		Art.pop(ci)
	else:
		Art.toon(ci, block, Art.SAND, _W, 0.6)
		for p: Vector2 in [Vector2(-15, -12), Vector2(-3, -17), Vector2(12, -10), Vector2(18, 4), Vector2(-18, 8), Vector2(-6, 16), Vector2(8, 15), Vector2(2, 1)]:
			Art.flat(ci, Art.circle_pts(p, 1.5, 8), Art.SAND_DARK)
		Art.t_ellipse(ci, Vector2(-11, -1), Vector2(5, 3.5), Color("c9b6a8"), 2.0, 0.4)
		Art.flat(ci, Art.ellipse_pts(Vector2(-18, -20), Vector2(5, 2), 10, -0.3), Color(1, 1, 1, 0.5))


static func _bubble(ci: CanvasItem, layers: int) -> void:
	var r := 27.0
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, r, 40), Color(0.72, 0.93, 1.0, 0.3 if layers < 2 else 0.42))
	# Rainbow sheen along the lower right edge.
	Art.arc(ci, Vector2.ZERO, r - 3.5, 0.2, 1.3, 10, Color(1.0, 0.6, 0.85, 0.55), 2.5)
	Art.arc(ci, Vector2.ZERO, r - 3.5, 1.3, 2.2, 8, Color(0.6, 0.8, 1.0, 0.55), 2.5)
	if layers >= 2:
		Art.ring(ci, Art.circle_pts(Vector2.ZERO, r - 7.0, 36), Color(1, 1, 1, 0.7), 2.2)
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, r, 44), Color("2f7fc0"), 4.5 if layers >= 2 else 3.2)
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, r - 0.8, 44), Color(1, 1, 1, 0.9), 1.4)
	Art.arc(ci, Vector2.ZERO, r - 5.5, PI + 0.35, PI + 1.25, 10, Color(1, 1, 1, 0.95), 4.0)
	Art.flat(ci, Art.circle_pts(Vector2(-8, -20), 2.2, 10), Color(1, 1, 1, 0.95))
	Art.flat(ci, Art.ellipse_pts(Vector2(15, 14), Vector2(3.5, 1.8), 10, -0.8), Color(1, 1, 1, 0.6))


## Small scallop shell decoration (local copy so tiles don't depend on Props).
static func _shell_deco(ci: CanvasItem, color: Color) -> void:
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

