class_name RodArt
extends RefCounted
## The fishing rods: 20 levels in each world (ocean, volcano, acid swamp,
## moon), after Mark's rod sheet (docs/concept/rods.txt). Every level keeps
## the same rod and adds the one change listed for it, so the silhouette
## stays and the detail grows. Toon style like the rest: thick INK outline,
## chunky parts, world materials.
##
## The rod is drawn along a centerline from the butt (f = 0) to the tip
## (f = 1) given in canvas space, so the fishing screen can bend it; parts
## sit at fractions of its length in "rod units" (a rod is 110 units long,
## the part sizes scale with it). The line and the float/hook are separate
## calls because the screen draws them in its own order.
##
##   RodArt.rod(ci, centerline, world, level, t)        # world 0..3, level 1..20
##   RodArt.line(ci, pts, world, level, t, width, wet)
##   RodArt.bob(ci, at, scale, world, level, t)         # float, hook or magnet
##   RodArt.icon(ci, world, level, t)                   # the whole rod in a ~120 px box
##   RodArt.length_mult(world, level)                   # longer from level 4

const OCEAN := 0
const VOLCANO := 1
const ACID := 2
const MOON := 3
const KEYS: Array[String] = ["OCEAN", "VOLCANO", "ACID", "MOON"]
const LEVELS := 20
const UNIT := 110.0
const SIL := Color("46406e")
## Parts (reels, rings, vials) are drawn this much bigger than the rod's
## own scale so they read on small ladder icons.
const PART := 1.3

static var _p := PackedVector2Array()
static var _cum := PackedFloat32Array()
static var _len := 1.0
static var _sc := 1.0
static var _sil := false


# --- Names ------------------------------------------------------------------------------

## "Sea rod", "Volcano rod", ...
static func name_key(world: int) -> String:
	return "FISHING_ROD_" + KEYS[posmod(world, 4)]


## What level `level` (1..20) adds, e.g. "Blue grip wrap".
static func level_key(world: int, level: int) -> String:
	return "ROD_%s_%d" % [KEYS[posmod(world, 4)], clampi(level, 1, LEVELS)]


# --- Geometry -------------------------------------------------------------------------

static func length_mult(world: int, level: int) -> float:
	var m := 1.0
	if level >= 4:
		m += 0.1
	if world == MOON and level >= 4:
		m += 0.04
	return m


static func _setup(pts: PackedVector2Array) -> void:
	_p = pts
	_cum = PackedFloat32Array()
	_cum.resize(pts.size())
	var acc := 0.0
	_cum[0] = 0.0
	for i in range(1, pts.size()):
		acc += pts[i].distance_to(pts[i - 1])
		_cum[i] = acc
	_len = maxf(acc, 0.001)


static func _at(f: float) -> Vector2:
	var d := clampf(f, 0.0, 1.0) * _len
	for i in range(1, _p.size()):
		if _cum[i] >= d:
			var seg := _cum[i] - _cum[i - 1]
			var u := (d - _cum[i - 1]) / seg if seg > 0.0 else 0.0
			return _p[i - 1].lerp(_p[i], u)
	return _p[_p.size() - 1]


static func _ang(f: float) -> float:
	var a := _at(clampf(f - 0.02, 0.0, 1.0))
	var b := _at(clampf(f + 0.02, 0.0, 1.0))
	return (b - a).angle()


static func _sub(f0: float, f1: float, n: int = 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(_at(lerpf(f0, f1, float(i) / n)))
	return out


## Local frame at fraction f: x along the rod, +y the underside, rod units.
static func _in(ci: CanvasItem, f: float, rot: float = 0.0) -> void:
	Art.push(ci, _at(f), _ang(f) + rot, Vector2.ONE * _sc * PART)


static func _out(ci: CanvasItem) -> void:
	Art.pop(ci)


static func _c(col: Color) -> Color:
	return Color(SIL, col.a) if _sil else col


static func _ink() -> float:
	return clampf(2.6 * sqrt(_sc), 1.6, 3.6)


## Tapered outlined tube along the rod from f0 to f1 (widths in rod units).
static func _tube(ci: CanvasItem, f0: float, f1: float, w0: float, w1: float, col: Color, n: int = 4) -> void:
	var ink := _ink()
	var pts := _sub(f0, f1, n)
	for i in n:
		var w := lerpf(w0, w1, (i + 0.5) / n) * _sc
		Art.polyline(ci, PackedVector2Array([pts[i], pts[i + 1]]), Art.INK, w + ink * 2.0)
	Art.disc(ci, pts[0], (w0 * _sc + ink * 2.0) / 2.0, Art.INK)
	Art.disc(ci, pts[n], (w1 * _sc + ink * 2.0) / 2.0, Art.INK)
	var c := _c(col)
	for i in n:
		var w := lerpf(w0, w1, (i + 0.5) / n) * _sc
		Art.polyline(ci, PackedVector2Array([pts[i], pts[i + 1]]), c, w)
	Art.disc(ci, pts[0], w0 * _sc / 2.0, c)
	Art.disc(ci, pts[n], w1 * _sc / 2.0, c)
	if not _sil:
		# A thin shine along the top side.
		var hi := PackedVector2Array()
		for i in n + 1:
			var f := lerpf(f0, f1, float(i) / n)
			var w := lerpf(w0, w1, float(i) / n) * _sc
			hi.append(_at(f) + Vector2.from_angle(_ang(f) - PI / 2.0) * w * 0.22)
		Art.polyline(ci, hi, Color(1, 1, 1, 0.35), maxf(1.0, lerpf(w0, w1, 0.5) * _sc * 0.22))


## A band (ring, sleeve, wrap) around the rod at f, `w` units long.
static func _band(ci: CanvasItem, f: float, w: float, thick: float, col: Color, shade: float = 0.3) -> void:
	_in(ci, f)
	w /= PART
	thick = (thick + 1.0) / PART
	Art.t_rect(ci, Rect2(-w / 2.0, -thick / 2.0, w, thick), minf(w, thick) * 0.3, _c(col), 2.0, shade)
	_out(ci)


static func _soft(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _sil or col.a <= 0.01:
		return
	var n := 18
	var clear := Color(col, 0.0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]),
				PackedColorArray([col, clear, clear]))


static func _q(x: float, step: float = 0.1) -> float:
	return snappedf(x, step)


# --- Palettes ---------------------------------------------------------------------------

## blank, handle, accent, reel, glow of each world.
const PAL := [
	{"blank": Color("b8743e"), "blank2": Color("d08a4e"), "handle": Color("7a4a2a"), "accent": Color("2f6ee8"), "reel": Color("c98249"), "metal": Color("cbd5e1"), "glow": Color("7ff0ff")},
	{"blank": Color("4a4250"), "blank2": Color("5c5262"), "handle": Color("ecdcc4"), "accent": Color("ff7a1e"), "reel": Color("2a2230"), "metal": Color("8a7e8c"), "glow": Color("ffb43a")},
	{"blank": Color("5d8a3c"), "blank2": Color("6fa046"), "handle": Color("2f3a35"), "accent": Color("b6f36a"), "reel": Color("e8c64a"), "metal": Color("b8c4a8"), "glow": Color("b6ff5a")},
	{"blank": Color("c9d3e6"), "blank2": Color("e2e8f4"), "handle": Color("3a3f6e"), "accent": Color("8a6cf0"), "reel": Color("dfe6f5"), "metal": Color("aab4cc"), "glow": Color("7ff0ff")},
]


static func pal(world: int, key: String) -> Color:
	return PAL[posmod(world, 4)][key]


# --- The whole rod in a box -------------------------------------------------------------

## The rod (diagonal, tip top right), its line and float, centered at (0,0)
## in a ~120 px box. silhouette: a dark shape for levels not reached yet.
static func icon(ci: CanvasItem, world: int, level: int, t: float, silhouette: bool = false) -> void:
	var m := length_mult(world, level)
	var tip := Vector2(34, -42)
	var dir := Vector2(-0.68, 0.73).normalized()
	var length := 104.0 * m
	var butt := tip + dir * length
	# Keep it inside the box: the butt can't go past the bottom left.
	var over := maxf(0.0, butt.y - 50.0)
	tip.y -= over * 0.5
	butt = tip + dir * length
	var shift := Vector2(-(butt.x + tip.x) / 2.0 + 2.0, 0)
	tip += shift
	butt += shift
	var bend := 0.06 + (0.05 if world == OCEAN and level >= 15 else 0.0)
	var pts := PackedVector2Array()
	var nrm := (tip - butt).orthogonal().normalized()
	for i in 9:
		var f := i / 8.0
		pts.append(butt.lerp(tip, f) + nrm * sin(f * PI * 0.5) * f * bend * length * -1.0)
	var end := Vector2(tip.x + 4.0, tip.y + 58.0)
	var sag := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		sag.append(pts[8].lerp(end + Vector2(0, -12), f) + Vector2(sin(f * PI) * 3.0, 0))
	var was := _sil
	_sil = silhouette
	line(ci, sag, world, level, t, 1.8, true)
	rod(ci, pts, world, level, t)
	bob(ci, end, 0.95, world, level, t)
	_sil = was


# --- The rod -----------------------------------------------------------------------------

## Draws the rod along `pts` (butt first, tip last, canvas space).
static func rod(ci: CanvasItem, pts: PackedVector2Array, world: int, level: int, t: float) -> void:
	if pts.size() < 2:
		return
	_setup(pts)
	_sc = _len / (UNIT * length_mult(world, level))
	var lv := clampi(level, 1, LEVELS)
	if lv >= LEVELS:
		_aura(ci, world, t)
	match posmod(world, 4):
		OCEAN:
			_ocean(ci, lv, t)
		VOLCANO:
			_volcano(ci, lv, t)
		ACID:
			_acid(ci, lv, t)
		MOON:
			_moon(ci, lv, t)


## The legendary rod's glow and twinkles.
static func _aura(ci: CanvasItem, world: int, t: float) -> void:
	if _sil:
		return
	var g := pal(world, "glow")
	for i in 6:
		var f := 0.12 + i * 0.17
		_soft(ci, _at(f), (16.0 - i * 1.2) * _sc, Color(g, 0.22))
	for i in 4:
		var k := fposmod(t * 0.5 + i * 0.25, 1.0)
		var p := _at(0.2 + i * 0.22) + Vector2.from_angle(_ang(0.5) - PI / 2.0 + (i % 2) * PI) * (9.0 + 5.0 * k) * _sc
		var s := _q(sin(k * PI), 0.1) * 4.0 * _sc
		if s > 0.2:
			Art.flat(ci, Art.star_pts(p, s, s * 0.35, 4), Color(1, 1, 0.85, 0.95))


# --- Ocean: wood, steel, blue, turquoise, coral, pearl ------------------------------------

static func _ocean(ci: CanvasItem, lv: int, t: float) -> void:
	var blank := pal(OCEAN, "blank") if lv < 20 else Color("5fc8d8")
	var handle := pal(OCEAN, "handle")
	var hf := 0.25
	# Blank: one piece, two from level 13 (with a sleeve).
	if lv >= 13:
		_tube(ci, hf - 0.02, 0.6, 6.0, 4.4, blank)
		_tube(ci, 0.6, 1.0, 4.2, 2.4, pal(OCEAN, "blank2") if lv < 20 else Color("bff0f8"))
		_band(ci, 0.6, 9.0, 8.0, Art.BRASS)
	else:
		_tube(ci, hf - 0.02, 1.0, 6.0, 2.6, blank)
	# Line guides.
	if lv >= 4:
		for f in [0.46, 0.68, 0.88]:
			_in(ci, f)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, Art.INK, 2.6)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, _c(pal(OCEAN, "metal")), 1.2)
			_out(ci)
	# Handle (with the blue wrap from level 2).
	_tube(ci, 0.0, hf, 9.0, 8.0, Color("2f6ee8") if lv >= 2 else handle)
	if lv >= 2 and not _sil:
		_in(ci, hf / 2.0)
		for i in 5:
			var x := -11.0 + i * 5.5
			Art.line(ci, Vector2(x - 2.0, -3.6), Vector2(x + 2.0, 3.6), Color("1c4fb8"), 1.6)
		_out(ci)
	# Wave pattern on the butt.
	if lv >= 9:
		_band(ci, 0.03, 7.0, 10.5, Art.TEAL, 0.4)
		if not _sil:
			_in(ci, 0.03)
			Art.polyline(ci, PackedVector2Array([Vector2(-3, 1), Vector2(-1.5, -1.5), Vector2(0, 1), Vector2(1.5, -1.5), Vector2(3, 1)]), Art.WHITE, 1.3)
			_out(ci)
	# Coral insert and pearl rivet.
	if lv >= 16:
		_band(ci, 0.14, 5.0, 9.5, Art.CORAL, 0.4)
		_in(ci, 0.14)
		Art.t_circle(ci, Vector2(0, -1), 2.2, _c(Color("fff4f8")), 1.4, 0.0)
		_out(ci)
	# Sea-metal ring at the end of the handle, a second one up the blank.
	if lv >= 6:
		_band(ci, hf, 4.0, 10.0, Color("9fd0d8"))
	if lv >= 12:
		_band(ci, 0.42, 3.5, 7.6, Color("9fd0d8"))
	# Bite bubble.
	if lv >= 11:
		_in(ci, 0.34)
		var wob := _q(sin(t * 3.0) * 0.8, 0.2)
		Art.line(ci, Vector2(0, -3), Vector2(0, -6), Art.INK, 2.0)
		Art.t_circle(ci, Vector2(0, -9.5 + wob), 4.2, _c(Color(0.75, 0.95, 1.0)), 1.8, 0.0)
		if not _sil:
			Art.disc(ci, Vector2(-1.4, -11 + wob), 1.2, Art.WHITE)
		_out(ci)
	# Tip: a little fin, then the pearl, then the trident.
	if lv >= 15:
		_in(ci, 0.93)
		Art.toon(ci, PackedVector2Array([Vector2(-4, -1), Vector2(3, -1), Vector2(-3, -7)]), _c(Art.TEAL), 1.6, 0.0)
		_out(ci)
	if lv >= 20:
		_in(ci, 1.0)
		for k in [-1.0, 0.0, 1.0]:
			var tipp := Vector2(9.0 - absf(k) * 2.0, k * 5.0)
			Art.stroke(ci, PackedVector2Array([Vector2(-2, k * 1.5), Vector2(3, k * 4.0), tipp]), _c(Color("e9f6ff")), 1.4, 1.2)
			Art.toon(ci, PackedVector2Array([tipp + Vector2(3.5, 0), tipp + Vector2(-0.5, -2.0), tipp + Vector2(-0.5, 2.0)]), _c(Color("e9f6ff")), 1.2, 0.0)
		_out(ci)
	if lv >= 19:
		_in(ci, 1.0)
		Art.t_circle(ci, Vector2(1, 0), 2.8, _c(Color("fff4f8")), 1.4, 0.0)
		_out(ci)
	# The reel.
	if lv >= 3:
		var rf := hf - 0.05
		_in(ci, rf)
		Art.t_rect(ci, Rect2(-3, 0, 6, 6), 1.5, _c(pal(OCEAN, "metal")), 1.8, 0.0)
		var r := 8.0 if lv < 14 else 7.0
		var c := Vector2(0, 10.5)
		if lv >= 18:
			Art.t_circle(ci, c + Vector2(-5.5, 0.5), r * 0.75, _c(pal(OCEAN, "metal")), 2.0, 0.3)
			Art.t_rect(ci, Rect2(-10, 13, 6, 3), 1.5, _c(Art.RED), 1.6, 0.0)
		Art.t_circle(ci, c, r, _c(Color("e8f0f8") if lv >= 8 else pal(OCEAN, "reel")), 2.2, 0.4)
		if lv >= 14:
			Art.t_circle(ci, c, r * 0.68, _c(Color("2f6ee8")), 1.6, 0.3)
		if lv >= 19:
			if not _sil:
				_soft(ci, _here(c), 9.0 * _sc, Color(0.5, 0.95, 1.0, _q(0.35 + 0.15 * sin(t * 3.0), 0.05)))
			Art.toon(ci, PackedVector2Array([c + Vector2(0, -4.2), c + Vector2(3, 0), c + Vector2(0, 4.2), c + Vector2(-3, 0)]), _c(Color("7ff0ff")), 1.4, 0.0)
		else:
			Art.t_circle(ci, c, 2.0, _c(Art.WOOD_DARK if lv < 8 else Color("8a95a8")), 1.2, 0.0)
		if lv >= 8:
			# Bail over the reel and a crank with a smooth knob.
			Art.arc(ci, c, r + 2.6, PI * 0.95, PI * 2.05, 10, Art.INK, 2.6)
			Art.arc(ci, c, r + 2.6, PI * 0.95, PI * 2.05, 10, _c(pal(OCEAN, "metal")), 1.2)
			_crank(ci, c, r, t, Color("2f6ee8"))
		_out(ci)


## Point `local` of the current local frame in canvas space (for glows).
static func _here(local: Vector2) -> Vector2:
	return Art._xf * local


static func _crank(ci: CanvasItem, c: Vector2, r: float, t: float, knob: Color) -> void:
	var a := 0.6
	var e := c + Vector2(cos(a), sin(a)) * (r + 3.0)
	Art.line(ci, c, e, Art.INK, 3.2)
	Art.line(ci, c, e, _c(Art.METAL), 1.5)
	Art.t_circle(ci, e, 2.4, _c(knob), 1.4, 0.0)


# --- Volcano: basalt, obsidian, ceramic, heat-proof metal; coal, red, orange, magma --------

static func _volcano(ci: CanvasItem, lv: int, t: float) -> void:
	var blank := pal(VOLCANO, "blank") if lv < 20 else Color("231a2c")
	var hf := 0.25
	var magma := Color("ff8a2a")
	var pulse := _q(0.5 + 0.5 * sin(t * 2.4), 0.1)
	if lv >= 4:
		_tube(ci, hf - 0.02, 0.56, 6.2, 4.6, blank)
		_tube(ci, 0.56, 1.0, 4.4, 2.6, Color("5c5262") if lv < 20 else Color("2e2238"))
		_band(ci, 0.56, 8.0, 8.4, Color("3a3340"), 0.5)
		if not _sil:
			_in(ci, 0.56)
			Art.line(ci, Vector2(-2.5, -3), Vector2(2.5, 3), Color("6e6070"), 1.2)
			_out(ci)
	else:
		_tube(ci, hf - 0.02, 1.0, 6.2, 2.8, blank)
	if lv >= 20 and not _sil:
		# Purple sheen of obsidian along the blank.
		Art.polyline(ci, _sub(0.3, 0.95, 6), Color("9a6cff", 0.45), 1.6 * _sc)
	# Line guides (heat-proof).
	if lv >= 4:
		for f in [0.45, 0.68, 0.88]:
			_in(ci, f)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, Art.INK, 2.6)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, _c(Color("c8a080")), 1.2)
			_out(ci)
	# Ceramic handle, heat wrap from level 2.
	_tube(ci, 0.0, hf, 9.4, 8.2, pal(VOLCANO, "handle"))
	if lv >= 2 and not _sil:
		_in(ci, hf / 2.0)
		for i in 4:
			var x := -9.0 + i * 6.0
			Art.t_rect(ci, Rect2(x - 1.6, -4.4, 3.2, 8.8), 1.0, Color("d8402a"), 1.2, 0.0)
		_out(ci)
	# Molten glass inserts.
	if lv >= 12:
		_in(ci, 0.1)
		for x in [-6.0, 4.0]:
			Art.t_ellipse(ci, Vector2(x, -1.2), Vector2(2.6, 1.8), _c(Color("ff6a2a")), 1.3, 0.0)
			if not _sil:
				Art.disc(ci, Vector2(x - 0.8, -1.8), 0.7, Color("ffe0a0"))
		_out(ci)
	# Butt cap of basalt.
	_band(ci, 0.015, 4.0, 10.5, Color("3a3340"), 0.5)
	# Volcanic glass ring.
	if lv >= 5:
		_band(ci, 0.4, 3.6, 8.4, Color("e04a2a"), 0.2)
		if not _sil:
			_in(ci, 0.4)
			Art.line(ci, Vector2(-0.6, -3), Vector2(-0.6, 1), Color(1, 0.85, 0.6, 0.8), 1.0)
			_out(ci)
	# Temperature gauge on top of the handle.
	if lv >= 6:
		_in(ci, 0.19)
		Art.t_rect(ci, Rect2(-2, -7, 4, 3), 1.0, _c(Color("3a3340")), 1.4, 0.0)
		Art.t_circle(ci, Vector2(0, -10.5), 4.4, _c(Art.CREAM), 1.8, 0.0)
		if not _sil:
			var a := -PI * 0.75 + 0.4 * sin(t * 1.3)
			Art.line(ci, Vector2(0, -10.5), Vector2(0, -10.5) + Vector2.from_angle(_q(a, 0.1)) * 3.2, Color("d8202a"), 1.2)
		_out(ci)
	# Sensor of bubbles and eruptions: a little antenna with a light.
	if lv >= 11:
		_in(ci, 0.36)
		Art.line(ci, Vector2(0, -3), Vector2(1, -10), Art.INK, 1.6)
		Art.t_circle(ci, Vector2(1, -11), 2.2, _c(Color("ffd23f") if pulse > 0.5 else Color("ff7a1e")), 1.2, 0.0)
		_out(ci)
	# Safe thermal flow indicator: three lights.
	if lv >= 16:
		_in(ci, 0.31)
		Art.t_rect(ci, Rect2(-6, -6.5, 12, 4), 1.4, _c(Color("2e2630")), 1.4, 0.0)
		if not _sil:
			for i in 3:
				var on := int(t * 2.0) % 3 == i
				Art.disc(ci, Vector2(-3.5 + i * 3.5, -4.5), 1.2, [Color("5cd05f"), Color("ffd23f"), Color("ff5a2a")][i].lightened(0.3 if on else 0.0))
		_out(ci)
	# Heat sink tip: glows at level 15, red-orange at 20.
	if lv >= 15:
		_band(ci, 0.97, 5.0, 4.6, Color("c8a080") if lv < 20 else Color("ff5a2a"), 0.2)
		if lv >= 20:
			_soft(ci, _at(1.0), 9.0 * _sc, Color(1.0, 0.5, 0.15, 0.55))
	# Heat shield behind the reel.
	if lv >= 10:
		_in(ci, hf - 0.1)
		Art.t_rect(ci, Rect2(-1.6, 1, 3.2, 16), 1.2, _c(Color("8a7e8c")), 1.6, 0.0)
		_out(ci)
	# The reel.
	if lv >= 3:
		_in(ci, hf - 0.05)
		Art.t_rect(ci, Rect2(-3, 0, 6, 6), 1.5, _c(Color("6e6070")), 1.8, 0.0)
		var c := Vector2(0, 11)
		var r := 8.0
		if lv >= 17:
			# Cooling fins around the reel.
			for i in 8:
				var a := TAU * i / 8.0
				Art.push(ci, c, a)
				Art.t_rect(ci, Rect2(r - 1.0, -1.3, 4.0, 2.6), 0.8, _c(Color("8a7e8c")), 1.2, 0.0)
				Art.pop(ci)
		if lv >= 20 and not _sil:
			_soft(ci, _here(c), 14.0 * _sc, Color(1.0, 0.45, 0.1, 0.35 + pulse * 0.25))
		Art.t_circle(ci, c, r, _c(pal(VOLCANO, "reel")), 2.2, 0.4)
		if not _sil:
			Art.arc(ci, c, r - 2.0, PI * 1.1, PI * 1.6, 6, Color("9a6cff", 0.7), 1.4)
		if lv >= 8:
			# Ceramic heat cover over the top half.
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([c + Vector2(-r - 1.5, 0.5), c + Vector2(-r, -r * 0.6), c + Vector2(0, -r - 2.0), c + Vector2(r, -r * 0.6), c + Vector2(r + 1.5, 0.5)]), 2), _c(pal(VOLCANO, "handle")), 1.8, 0.3)
		if lv >= 14:
			# Heat exchanger: a little grille.
			for i in 3:
				Art.line(ci, c + Vector2(-4, 1.5 + i * 2.2), c + Vector2(4, 1.5 + i * 2.2), _c(Color("8a7e8c")), 1.0)
		if lv >= 18:
			for x in [-3.2, 3.2]:
				Art.t_circle(ci, c + Vector2(x, -1), 2.0, _c(magma.lightened(0.2 * pulse)), 1.2, 0.0)
		if lv >= 19:
			Art.toon(ci, PackedVector2Array([c + Vector2(0, -4.5), c + Vector2(3.2, -0.5), c + Vector2(0, 3.5), c + Vector2(-3.2, -0.5)]), _c(Color("3a1a4a") if lv < 20 else Color("ffb43a")), 1.4, 0.0)
			if not _sil:
				Art.disc(ci, c + Vector2(-0.8, -2.0), 0.9, Color("c8a0ff") if lv < 20 else Art.WHITE)
		_crank(ci, c, r, t, Color("d8402a"))
		_out(ci)


# --- Acid swamp: rubber, glass vials, mushrooms, slime ----------------------------------

static func _acid(ci: CanvasItem, lv: int, t: float) -> void:
	var blank := pal(ACID, "blank")
	var hf := 0.25
	var slime := Color("9be03a")
	var pulse := _q(0.5 + 0.5 * sin(t * 2.0), 0.1)
	if lv >= 13:
		_tube(ci, hf - 0.02, 0.58, 6.2, 4.6, blank)
		_tube(ci, 0.58, 1.0, 4.3, 2.6, pal(ACID, "blank2"))
		_in(ci, 0.58)
		Art.t_ellipse(ci, Vector2.ZERO, Vector2(5.0, 5.4), _c(Color("8a4ac0")), 1.8, 0.3)
		_out(ci)
	else:
		_tube(ci, hf - 0.02, 1.0, 6.2, 2.8, blank)
	# Rubber ring guides.
	if lv >= 4:
		for f in [0.45, 0.68, 0.88]:
			_in(ci, f)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, Art.INK, 3.0)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, _c(Color("b07cff")), 1.6)
			_out(ci)
	# Black rubber handle, ribbed from level 2.
	_tube(ci, 0.0, hf, 9.4, 8.4, pal(ACID, "handle"))
	if lv >= 2 and not _sil:
		_in(ci, hf / 2.0)
		for i in 5:
			Art.line(ci, Vector2(-10.0 + i * 5.0, -4.2), Vector2(-10.0 + i * 5.0, 4.2), Color("8ad84a"), 1.8)
		_out(ci)
	# Moss on the butt.
	if lv >= 9:
		_in(ci, 0.03)
		for p in [Vector2(-2, -4.5), Vector2(2, -4.2), Vector2(0, 4.6), Vector2(-3.5, 3.6)]:
			Art.t_circle(ci, p, 2.4, _c(Color("4caa3a")), 1.2, 0.0)
		_out(ci)
	# Slime drip insert and an amber rivet.
	if lv >= 16:
		_in(ci, 0.15)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-4, -4.6), Vector2(4, -4.6), Vector2(3.6, 1.0), Vector2(1.5, 5.5 + pulse), Vector2(-0.5, 1.0), Vector2(-3.6, 2.0)]), 2), _c(slime), 1.4, 0.0)
		Art.t_circle(ci, Vector2(-7, 0), 1.9, _c(Color("ffb43a")), 1.2, 0.0)
		_out(ci)
	# Glass vials clipped on the handle and the blank.
	if lv >= 6:
		_vial(ci, 0.18, slime, pulse, false, t)
	if lv >= 12:
		_vial(ci, 0.47, Color("c070ff"), pulse, false, t + 1.3)
	# Bite indicator: a bubbling flask.
	if lv >= 11:
		_vial(ci, 0.34, Color("6af0c0"), pulse, true, t)
	# A tiny mushroom on the tip; the crown of mushrooms at level 20.
	if lv >= 15:
		_in(ci, 0.95)
		_shroom(ci, Vector2(0, -3.5), 3.6, Color("e04a8a"))
		if lv >= 20:
			_shroom(ci, Vector2(-5, -2.5), 2.6, Color("b07cff"))
			_shroom(ci, Vector2(5.5, -2.0), 2.8, Color("ffb43a"))
		_out(ci)
	if lv >= 19:
		_in(ci, 1.0)
		Art.t_circle(ci, Vector2(1.5, 0), 2.6, _c(Color(0.75, 1.0, 0.6, 0.9)), 1.4, 0.0)
		_out(ci)
	# The reel: a jar lid.
	if lv >= 3:
		_in(ci, hf - 0.05)
		Art.t_rect(ci, Rect2(-3, 0, 6, 6), 1.5, _c(Color("2f3a35")), 1.8, 0.0)
		var c := Vector2(0, 11)
		var r := 8.0
		if lv >= 18:
			# Slime tank beside a second reel.
			Art.t_circle(ci, c + Vector2(-6, 1), 5.6, _c(pal(ACID, "reel")), 1.8, 0.3)
			Art.t_rect(ci, Rect2(c.x + 5, c.y - 9, 6, 11), 2.5, _c(Color(0.6, 0.95, 0.4, 0.9)), 1.6, 0.0)
		if lv >= 20 and not _sil:
			_soft(ci, _here(c), 14.0 * _sc, Color(0.6, 1.0, 0.25, 0.3 + pulse * 0.25))
		Art.t_circle(ci, c, r, _c(pal(ACID, "reel") if lv < 20 else Color("6fd04a")), 2.2, 0.4)
		if not _sil:
			# The lid's ridges.
			for i in 10:
				var a := TAU * i / 10.0
				Art.line(ci, c + Vector2.from_angle(a) * (r - 2.2), c + Vector2.from_angle(a) * r, Color("b08a2a"), 1.0)
		if lv >= 8:
			Art.arc(ci, c, r + 1.0, 0.0, TAU, 16, Art.INK, 1.6)
			Art.arc(ci, c, r + 1.0, PI * 0.2, PI * 0.8, 6, _c(Color("e04a8a")), 2.4)
			_crank(ci, c, r, t, Color("e04a8a"))
		if lv >= 14:
			Art.t_circle(ci, c, r * 0.62, _c(Color("e04a8a")), 1.6, 0.2)
			if not _sil:
				for p in [Vector2(-1.8, -1.2), Vector2(1.6, -1.8), Vector2(0.4, 1.6)]:
					Art.disc(ci, c + p, 0.9, Art.WHITE)
		if lv >= 19:
			Art.toon(ci, PackedVector2Array([c + Vector2(0, -4.5), c + Vector2(2.8, 0), c + Vector2(0, 4.5), c + Vector2(-2.8, 0)]), _c(Color("b6ff5a")), 1.4, 0.0)
		elif lv < 14:
			Art.t_circle(ci, c, 2.0, _c(Color("b08a2a")), 1.2, 0.0)
		_out(ci)


static func _vial(ci: CanvasItem, f: float, liquid: Color, pulse: float, bubbling: bool, t: float) -> void:
	_in(ci, f)
	var r := Rect2(-2.6, -15, 5.2, 11)
	Art.t_rect(ci, Rect2(-1.2, -5, 2.4, 3), 0.6, _c(Art.METAL), 1.2, 0.0)
	Art.t_rect(ci, r, 2.6, _c(Color(0.85, 1.0, 0.95, 0.9)), 1.6, 0.0)
	if not _sil:
		Art.flat(ci, Art.rrect_pts(Rect2(r.position.x + 0.8, r.position.y + 4.5 - pulse, r.size.x - 1.6, r.size.y - 5.3 + pulse), 1.6), liquid)
		Art.line(ci, Vector2(-1.2, -13), Vector2(-1.2, -9), Color(1, 1, 1, 0.8), 0.9)
	Art.t_rect(ci, Rect2(-3.0, -17, 6.0, 2.6), 1.0, _c(Color("8a5a3a")), 1.2, 0.0)
	if bubbling and not _sil:
		for i in 3:
			var k := fposmod(t * 0.8 + i / 3.0, 1.0)
			Art.disc(ci, Vector2(sin(i * 2.0 + k * 6.0) * 1.5, -18 - k * 9.0), _q(1.4 * (1.0 - k) + 0.4, 0.2), Color(liquid, 1.0 - k))
	_out(ci)


static func _shroom(ci: CanvasItem, at: Vector2, r: float, cap: Color) -> void:
	Art.t_rect(ci, Rect2(at.x - r * 0.3, at.y - r * 0.2, r * 0.6, r * 1.1), r * 0.2, _c(Art.CREAM), 1.2, 0.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(-r * 0.7, -r * 0.8), at + Vector2(0, -r * 1.05), at + Vector2(r * 0.7, -r * 0.8), at + Vector2(r, 0)]), 2), _c(cap), 1.4, 0.2)
	if not _sil:
		Art.disc(ci, at + Vector2(-r * 0.35, -r * 0.5), r * 0.18, Art.WHITE)
		Art.disc(ci, at + Vector2(r * 0.35, -r * 0.35), r * 0.14, Art.WHITE)


# --- Moon: light metal, composite, glass, light filament; navy, violet, teal, gold ---------

static func _moon(ci: CanvasItem, lv: int, t: float) -> void:
	var hf := 0.25
	var teal := Color("5ef0e0")
	var pulse := _q(0.5 + 0.5 * sin(t * 3.0), 0.1)
	# Telescopic from level 4: three segments, each a bit thinner.
	if lv >= 4:
		_tube(ci, hf - 0.02, 0.52, 6.2, 5.4, pal(MOON, "blank"))
		_tube(ci, 0.52, 0.76, 4.6, 4.0, pal(MOON, "blank2"))
		_tube(ci, 0.76, 1.0, 3.4, 2.6, Color("f2f5fb"))
		_band(ci, 0.52, 3.0, 7.4, Color("8a95b8"))
		_band(ci, 0.76, 3.0, 5.8, Color("8a95b8"))
	else:
		_tube(ci, hf - 0.02, 1.0, 6.0, 2.8, pal(MOON, "blank"))
	if lv >= 4:
		for f in [0.46, 0.68, 0.88]:
			_in(ci, f)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, Art.INK, 2.6)
			Art.arc(ci, Vector2(0, 5.5), 2.6, 0.0, TAU, 10, _c(teal), 1.2)
			_out(ci)
	# Navy handle; a violet magnetic pad from level 2; stardust from 12.
	_tube(ci, 0.0, hf, 9.2, 8.2, pal(MOON, "handle"))
	if lv >= 2:
		_in(ci, hf * 0.55)
		Art.t_rect(ci, Rect2(-7, -3.4, 14, 6.8), 3.0, _c(Color("8a6cf0")), 1.4, 0.0)
		if not _sil:
			for i in 3:
				Art.disc(ci, Vector2(-4.0 + i * 4.0, 0), 0.9, Color("d8ccff"))
		_out(ci)
	if lv >= 12 and not _sil:
		_in(ci, 0.06)
		for p in [Vector2(-3, -2), Vector2(2, 1.5)]:
			Art.flat(ci, Art.star_pts(p, 2.2, 0.9, 4), Art.GOLD)
		_out(ci)
	_band(ci, 0.015, 3.6, 10.2, Color("aab4cc"))
	# Gyroscope on the body.
	if lv >= 11:
		_in(ci, 0.4)
		Art.t_circle(ci, Vector2(0, -7.5), 3.4, _c(Color("dfe6f5")), 1.4, 0.2)
		Art.push(ci, Vector2(0, -7.5), _q(t * 1.5, 0.15))
		Art.arc(ci, Vector2.ZERO, 5.2, 0.0, TAU, 14, Art.INK, 2.2)
		Art.arc(ci, Vector2.ZERO, 5.2, 0.0, TAU, 14, _c(Art.GOLD), 1.0)
		Art.pop(ci)
		_out(ci)
	# Radar dish with a sweep.
	if lv >= 16:
		_in(ci, 0.31)
		Art.line(ci, Vector2(0, -3), Vector2(0, -7), Art.INK, 1.6)
		Art.push(ci, Vector2(0, -8), -0.5 + 0.4 * _q(sin(t * 1.4), 0.1))
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-5, -1), Vector2(0, 2.2), Vector2(5, -1), Vector2(0, 0.6)]), 2), _c(Color("dfe6f5")), 1.3, 0.0)
		Art.pop(ci)
		_out(ci)
	# Beacon near the tip.
	if lv >= 6:
		_in(ci, 0.86)
		Art.t_circle(ci, Vector2(0, -4.4), 2.2, _c(Color("ff5a7a") if pulse > 0.5 else Color("ffd0dc")), 1.2, 0.0)
		if pulse > 0.5:
			_soft(ci, _here(Vector2(0, -4.4)), 6.0 * _sc, Color(1.0, 0.4, 0.5, 0.45))
		_out(ci)
	# Micro thruster on the tip.
	if lv >= 15:
		_in(ci, 0.985)
		Art.t_rect(ci, Rect2(-3, -3.2, 5, 6.4), 1.4, _c(Color("8a95b8")), 1.4, 0.0)
		if not _sil:
			var fl := 2.0 + 1.5 * _q(absf(sin(t * 9.0)), 0.25)
			Art.flat(ci, PackedVector2Array([Vector2(-3, -1.8), Vector2(-3 - fl * 1.6, 0), Vector2(-3, 1.8)]), Color("7ff0ff", 0.85))
		_out(ci)
	# Debris shield in front of the reel.
	if lv >= 10:
		_in(ci, hf + 0.02)
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-1, 2), Vector2(2.5, 9), Vector2(1, 18), Vector2(-1.5, 18), Vector2(0, 9), Vector2(-3, 2)]), 2), _c(Color(0.75, 0.9, 1.0, 0.85)), 1.4, 0.0)
		_out(ci)
	# The reel with its orbit disk.
	if lv >= 3:
		_in(ci, hf - 0.05)
		Art.t_rect(ci, Rect2(-3, 0, 6, 6), 1.5, _c(Color("8a95b8")), 1.8, 0.0)
		var c := Vector2(0, 11)
		var r := 7.5
		if lv >= 8:
			# Satellite panels.
			for s in [-1.0, 1.0]:
				Art.line(ci, c, c + Vector2(s * (r + 4.0), -1), Art.INK, 1.6)
				Art.t_rect(ci, Rect2(c.x + s * (r + 3.0) - (6.0 if s < 0 else 0.0), c.y - 4.5, 6, 6.5), 1.0, _c(Color("2f6ee8")), 1.4, 0.0)
				if not _sil:
					Art.line(ci, Vector2(c.x + s * (r + 6.0), c.y - 4.0), Vector2(c.x + s * (r + 6.0), c.y + 1.5), Color("9fd4ff"), 0.8)
		if lv >= 18:
			Art.t_circle(ci, c + Vector2(-5.5, 3.5), 5.0, _c(pal(MOON, "reel")), 1.8, 0.3)
			if not _sil:
				Art.disc(ci, c + Vector2(-5.5, 3.5), 1.8, Color("b07cff"))
		Art.t_ellipse(ci, c, Vector2(r + 4.5, 2.6), _c(Color("8a6cf0")), 1.6, 0.0)
		if lv >= 20 and not _sil:
			_soft(ci, _here(c), 15.0 * _sc, Color(0.55, 0.9, 1.0, 0.3 + pulse * 0.25))
		Art.t_circle(ci, c, r, _c(pal(MOON, "reel") if lv < 14 else Color("6a5ab8")), 2.2, 0.4)
		if lv >= 14 and not _sil:
			Art.arc(ci, c, r - 1.6, 0.0, TAU, 14, Art.GOLD, 1.2)
		if lv >= 5:
			Art.arc(ci, c, r + 2.2, 0.0, TAU, 18, Color(teal, 0.9) if not _sil else SIL, 1.6)
		if lv >= 20:
			Art.t_circle(ci, c, 3.6, _c(Color("bff8ff")), 1.4, 0.0)
			if not _sil:
				Art.flat(ci, Art.star_pts(c, 3.0, 1.2, 4, _q(t, 0.2)), Art.WHITE)
		else:
			Art.t_circle(ci, c, 2.2, _c(Color("8a95b8")), 1.2, 0.0)
		_crank(ci, c, r, t, Color("8a6cf0"))
		if lv >= 17:
			# Two thin orbital rings turning around the reel.
			for k in 2:
				Art.push(ci, c, _q(t * (0.8 + k * 0.5) + k * 1.4, 0.1), Vector2(1.0, 0.36))
				Art.arc(ci, Vector2.ZERO, r + 6.0 + k * 2.0, 0.0, TAU, 20, Art.INK, 1.8)
				Art.arc(ci, Vector2.ZERO, r + 6.0 + k * 2.0, 0.0, TAU, 20, _c(Art.GOLD if k == 0 else teal), 0.9)
				Art.pop(ci)
		_out(ci)


# --- The line ------------------------------------------------------------------------------

## The fishing line through `pts` (tip first). `wet`: the float is in the water.
static func line(ci: CanvasItem, pts: PackedVector2Array, world: int, level: int, t: float, width: float = 2.0, wet: bool = false) -> void:
	if pts.size() < 2:
		return
	var lv := clampi(level, 1, LEVELS)
	var col := Color(1, 1, 1, 0.92)
	var glow := Color(0, 0, 0, 0)
	match posmod(world, 4):
		OCEAN:
			if lv >= 7:
				col = Color("cdeeff")
				width *= 0.85
			if lv >= 17 and wet:
				glow = Color(0.6, 0.95, 1.0, 0.35)
		VOLCANO:
			col = Color("efe2d4")
			if lv >= 7:
				col = Color("8a7470")
				glow = Color(1.0, 0.5, 0.15, 0.2)
			if lv >= 20:
				glow = Color(1.0, 0.45, 0.1, 0.4)
		ACID:
			if lv >= 7:
				col = Color("c8f87a")
				glow = Color(0.6, 1.0, 0.3, 0.3)
		MOON:
			if lv >= 7:
				col = Color("bff8ff")
				glow = Color(0.4, 0.95, 1.0, 0.3)
			if lv >= 19:
				col = Color("f0fcff")
				glow = Color(0.65, 0.55, 1.0, 0.5)
	if _sil:
		col = SIL
		glow.a = 0.0
	if glow.a > 0.0:
		Art.polyline(ci, pts, glow, width * 3.6)
	Art.polyline(ci, pts, Color(Art.INK, 0.35), width * 2.0)
	Art.polyline(ci, pts, col, width)
	if _sil:
		return
	# Sparkles running down the line.
	var sparkle := (world == OCEAN and lv >= 17 and wet) or (world == MOON and lv >= 19) or (world == VOLCANO and lv >= 20)
	if sparkle:
		var n := pts.size() - 1
		for k in 3:
			var f := fposmod(t * 0.45 + k / 3.0, 1.0)
			var i := mini(int(f * n), n - 1)
			var p := pts[i].lerp(pts[i + 1], f * n - i)
			var s := width * (1.6 + 0.6 * sin(f * PI))
			Art.flat(ci, Art.star_pts(p, s * 1.6, s * 0.5, 4), Color(1, 1, 0.9, 0.9) if world != VOLCANO else Color("ffd080"))
	# Slime drips on the acid line.
	if world == ACID and lv >= 17 and wet:
		for k in 2:
			var f := fposmod(t * 0.3 + k * 0.5, 1.0)
			var i := mini(int((0.3 + k * 0.3) * (pts.size() - 1)), pts.size() - 1)
			Art.disc(ci, pts[i] + Vector2(0, 2.0 + f * 14.0), _q(width * (1.2 - f * 0.5), 0.2), Color(0.7, 1.0, 0.3, 1.0 - f))


# --- Float / hook --------------------------------------------------------------------------

## The float (ocean, swamp), the heat-proof float and hook (volcano) or the
## magnetic hook (moon) at `at` (the line's end), ~26 px at s = 1.
static func bob(ci: CanvasItem, at: Vector2, s: float, world: int, level: int, t: float) -> void:
	var lv := clampi(level, 1, LEVELS)
	Art.push(ci, at, 0.0, Vector2.ONE * s)
	match posmod(world, 4):
		OCEAN:
			_ocean_bob(ci, lv, t)
		VOLCANO:
			_volcano_bob(ci, lv, t)
		ACID:
			_acid_bob(ci, lv, t)
		MOON:
			_moon_bob(ci, lv, t)
	Art.pop(ci)


static func _ocean_bob(ci: CanvasItem, lv: int, t: float) -> void:
	Art.line(ci, Vector2(0, -16), Vector2(0, -9), Art.INK, 3.0)
	if lv >= 20 and not _sil:
		_soft(ci, _here(Vector2.ZERO), 22.0, Color(0.7, 0.95, 1.0, _q(0.4 + 0.15 * sin(t * 3.0), 0.05)))
	if lv >= 10:
		# Pearly, with a blue stripe.
		Art.t_circle(ci, Vector2.ZERO, 10.0, _c(Color("f4f0ff")), 2.6, 0.4)
		Art.toon(ci, Art.clipped(Art.circle_pts(Vector2.ZERO, 10.0, 20), Art.rrect_pts(Rect2(-12, -2.8, 24, 5.6), 0.1, 1)), _c(Color("2f6ee8")), 0.0, 0.0)
		if not _sil:
			Art.flat(ci, Art.ellipse_pts(Vector2(3, -5), Vector2(3, 2), 8, 0.4), Color("ffd0f0", 0.6))
	else:
		Art.t_circle(ci, Vector2.ZERO, 10.0, _c(Art.WHITE), 2.6, 0.4)
		Art.toon(ci, Art.clipped(Art.circle_pts(Vector2.ZERO, 10.0, 20), Art.rrect_pts(Rect2(-12, -12, 24, 12), 0.1, 1)), _c(Art.RED), 0.0, 0.0)
	Art.arc(ci, Vector2.ZERO, 10.0, 0.0, TAU, 20, Art.INK, 2.6)
	if not _sil:
		Art.flat(ci, Art.ellipse_pts(Vector2(-4, -5), Vector2(3, 2), 8, -0.5), Color(1, 1, 1, 0.8))
	if lv >= 5:
		# A little shell on top.
		Art.push(ci, Vector2(0, -10), 0.0)
		Art.toon(ci, PackedVector2Array([Vector2(-5, 0), Vector2(-4, -4), Vector2(0, -6), Vector2(4, -4), Vector2(5, 0), Vector2(0, 1.5)]), _c(Color("ffb0a0") if lv < 20 else Color("fff0f8")), 1.8, 0.2)
		if not _sil:
			for x in [-2.0, 0.0, 2.0]:
				Art.line(ci, Vector2(x * 0.5, 0), Vector2(x * 1.6, -4.5), Color("d87a6a"), 0.9)
		Art.pop(ci)
	if lv >= 20 and not _sil:
		Art.toon(ci, PackedVector2Array([Vector2(0, -3.5), Vector2(2.6, 0), Vector2(0, 3.5), Vector2(-2.6, 0)]), Color("7ff0ff"), 1.2, 0.0)


static func _volcano_bob(ci: CanvasItem, lv: int, t: float) -> void:
	Art.line(ci, Vector2(0, -16), Vector2(0, -9), Art.INK, 3.0)
	# The hook under the float (obsidian from 9, two from 13).
	if lv >= 9:
		var n := 2 if lv >= 13 else 1
		for k in n:
			var x := 0.0 if n == 1 else (-3.5 + k * 7.0)
			Art.line(ci, Vector2(x, 8), Vector2(x, 16), Art.INK, 2.6)
			Art.arc(ci, Vector2(x + 2.5, 16), 3.0, 0.0, PI, 6, Art.INK, 3.2)
			Art.arc(ci, Vector2(x + 2.5, 16), 3.0, 0.0, PI, 6, _c(Color("4a2a5a")), 1.4)
	if lv >= 20 and not _sil:
		_soft(ci, _here(Vector2.ZERO), 22.0, Color(1.0, 0.5, 0.1, _q(0.4 + 0.15 * sin(t * 3.0), 0.05)))
	var body := Art.smooth_pts(PackedVector2Array([Vector2(0, -11), Vector2(8, -2), Vector2(6, 7), Vector2(0, 10), Vector2(-6, 7), Vector2(-8, -2)]), 3)
	Art.toon(ci, body, _c(Color("ecdcc4") if lv < 20 else Color("2a1e30")), 2.6, 0.4)
	Art.toon(ci, Art.clipped(body, Art.rrect_pts(Rect2(-12, -12, 24, 9), 0.1, 1)), _c(Color("e04a2a") if lv < 20 else Color("ff7a1e")), 0.0, 0.0)
	Art.ring(ci, body, Art.INK, 2.6)
	if not _sil:
		Art.flat(ci, Art.ellipse_pts(Vector2(-3, -6), Vector2(2.2, 1.6), 8, -0.5), Color(1, 1, 1, 0.75))


static func _acid_bob(ci: CanvasItem, lv: int, t: float) -> void:
	Art.line(ci, Vector2(0, -16), Vector2(0, -9), Art.INK, 3.0)
	if lv >= 20 and not _sil:
		_soft(ci, _here(Vector2.ZERO), 22.0, Color(0.6, 1.0, 0.3, _q(0.4 + 0.15 * sin(t * 3.0), 0.05)))
	if lv >= 10:
		# A glass bubble with goo inside (a glowing vial at level 20).
		if lv >= 20:
			Art.t_rect(ci, Rect2(-6, -10, 12, 19), 5.5, _c(Color(0.85, 1.0, 0.95, 0.95)), 2.4, 0.0)
			if not _sil:
				Art.flat(ci, Art.rrect_pts(Rect2(-4.5, -3, 9, 10.5), 4.0), Color("9be03a"))
			Art.t_rect(ci, Rect2(-6.5, -12.5, 13, 4), 1.6, _c(Color("8a5a3a")), 1.6, 0.0)
		else:
			Art.t_circle(ci, Vector2.ZERO, 10.0, _c(Color(0.85, 1.0, 0.95, 0.95)), 2.6, 0.0)
			if not _sil:
				var goo := 1.5 * sin(t * 2.0)
				Art.flat(ci, Art.clipped(Art.circle_pts(Vector2.ZERO, 8.0, 18), Art.rrect_pts(Rect2(-10, _q(-1.0 + goo, 0.5), 20, 12), 0.1, 1)), Color("9be03a"))
		if not _sil:
			Art.flat(ci, Art.ellipse_pts(Vector2(-3.5, -5), Vector2(2.6, 1.8), 8, -0.5), Color(1, 1, 1, 0.85))
		return
	# A mushroom cap float (glowing spots from level 5).
	Art.t_rect(ci, Rect2(-3.5, -1, 7, 10), 3.0, _c(Art.CREAM), 2.2, 0.0)
	var cap := Art.smooth_pts(PackedVector2Array([Vector2(-11, 1), Vector2(-9, -7), Vector2(0, -11), Vector2(9, -7), Vector2(11, 1)]), 3)
	Art.toon(ci, cap, _c(Color("8a4ac0")), 2.6, 0.4)
	if not _sil:
		var spot := Color("e8ff9a") if lv >= 5 else Art.WHITE
		for p in [Vector2(-5, -4), Vector2(3, -7), Vector2(6, -2)]:
			Art.disc(ci, p, 1.9, spot)
		if lv >= 5:
			_soft(ci, _here(Vector2(0, -4)), 12.0, Color(0.8, 1.0, 0.4, 0.25))


static func _moon_bob(ci: CanvasItem, lv: int, t: float) -> void:
	Art.line(ci, Vector2(0, -16), Vector2(0, -8), Art.INK, 3.0)
	if lv >= 20 and not _sil:
		_soft(ci, _here(Vector2.ZERO), 24.0, Color(0.55, 0.9, 1.0, _q(0.4 + 0.15 * sin(t * 3.0), 0.05)))
	Art.t_circle(ci, Vector2(0, -7), 3.6, _c(Color("aab4cc")), 1.8, 0.0)
	if lv >= 9:
		# Magnetic claws: one, two from level 13.
		var n := 2 if lv >= 13 else 1
		for k in n:
			var x := 0.0 if n == 1 else (-5.0 + k * 10.0)
			Art.push(ci, Vector2(x, 0), 0.0 if n == 1 else (-0.25 + k * 0.5))
			Art.t_circle(ci, Vector2(0, -1), 4.6, _c(Color("6a5ab8")), 2.0, 0.3)
			for s in [-1.0, 0.0, 1.0]:
				var tipp := Vector2(s * 5.5, 9.5 - absf(s) * 1.5)
				Art.stroke(ci, PackedVector2Array([Vector2(s * 2.5, 1), Vector2(s * 4.5, 5), tipp]), _c(Color("dfe6f5")), 1.8, 1.4)
			if not _sil:
				Art.disc(ci, Vector2(0, -1), 1.6, Color("7ff0ff") if lv < 20 else Art.WHITE)
			Art.pop(ci)
		return
	# A simple U magnet.
	var u := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		u.append(Vector2(cos(a) * 7.5, -2 + sin(a) * 8.0))
	for i in 9:
		var a := PI - PI * i / 8.0
		u.append(Vector2(cos(a) * 3.2, -2 + sin(a) * 3.6))
	Art.toon(ci, PackedVector2Array([Vector2(-7.5, -6), Vector2(-3.2, -6), Vector2(-3.2, -2), Vector2(-7.5, -2)]), _c(Art.METAL), 2.0, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(3.2, -6), Vector2(7.5, -6), Vector2(7.5, -2), Vector2(3.2, -2)]), _c(Art.METAL), 2.0, 0.0)
	Art.toon(ci, u, _c(Art.RED), 2.2, 0.3)
