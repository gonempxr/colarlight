class_name Art
extends RefCounted
## Palette and the "toon" drawing kit every sprite is built from:
## a polygon gets a dark outline, a soft shadow band at the bottom and a
## highlight band at the top. Geometry is computed once per shape and
## cached, so sprites are drawn in local space and placed with push/pop.

# --- Palette -------------------------------------------------------------------
const INK := Color("241a3a")          # outlines, dark text
const INK_SOFT := Color("6a5a80")
const SHADE := Color("2d2060")        # shadows lean purple, not grey
const WHITE := Color("ffffff")
const CREAM := Color("fff6e4")
const CREAM_DARK := Color("f1ddb9")
const GOLD := Color("ffc93c")
const GOLD_DARK := Color("e0921c")
const GREEN := Color("5cd05f")
const GREEN_DARK := Color("2f9a45")
const BLUE := Color("3aa6f0")
const CORAL := Color("ff7a59")
const RED := Color("ef5350")
const PURPLE := Color("8a6cf0")
const TEAL := Color("2bc8b4")
const SKY_TOP := Color("4fb3ee")
const SKY_BOTTOM := Color("c4ecff")
const SEA_TOP := Color("35c9d2")
const SEA_MID := Color("1c88b6")
const SEA_DEEP := Color("165290")
const SEA_ABYSS := Color("0e2654")
const SAND := Color("f8d898")
const SAND_DARK := Color("e2aa62")
const GRASS := Color("72d25a")
const WOOD := Color("c98249")
const WOOD_DARK := Color("8e552c")
const METAL := Color("cbd5e1")
const BRASS := Color("f5b843")
const GLASS := Color("bff3ff")

## One look per dive site: rock, floor, ore colors, diver suit, cave water.
const DEPTH_STYLE: Array[Dictionary] = [
	{"rock": Color("e3aa6c"), "floor": Color("f8d898"), "ore": Color("ffc6d6"), "ore2": Color("ff8fb0"), "suit": Color("ff8a3d"), "water": Color("2a9cc6"), "deco": "shells"},  # shells
	{"rock": Color("d9845c"), "floor": Color("f5c690"), "ore": Color("ff5d73"), "ore2": Color("ffa84a"), "suit": Color("ffd23f"), "water": Color("2283b6"), "deco": "coral"},  # coral
	{"rock": Color("a88fc8"), "floor": Color("ded0ee"), "ore": Color("fbf8ff"), "ore2": Color("c6d4ff"), "suit": Color("ff6fae"), "water": Color("1f6aa8"), "deco": "pearls"},  # pearl
	{"rock": Color("927668"), "floor": Color("c8ab94"), "ore": Color("f08a45"), "ore2": Color("ffc185"), "suit": Color("7fd34e"), "water": Color("1a5692"), "deco": "wreck"},  # copper
	{"rock": Color("51817c"), "floor": Color("8cb8aa"), "ore": Color("3ee08f"), "ore2": Color("b0ffd9"), "suit": Color("9b72ff"), "water": Color("15457c"), "deco": "kelp"},  # emerald
	{"rock": Color("45427a"), "floor": Color("7470b0"), "ore": Color("b58cff"), "ore2": Color("f0e3ff"), "suit": Color("2de2c5"), "water": Color("102e60"), "deco": "glow"},  # crystal
	{"rock": Color("7a5a34"), "floor": Color("d4b06a"), "ore": Color("ffd23f"), "ore2": Color("fff1a8"), "suit": Color("ef5350"), "water": Color("12304f"), "deco": "wreck"},  # gold
	{"rock": Color("7fa6c4"), "floor": Color("e4f4ff"), "ore": Color("bff4ff"), "ore2": Color("ffffff"), "suit": Color("ff6fae"), "water": Color("0f3358"), "deco": "ice"},  # ice
	{"rock": Color("4a2622"), "floor": Color("8a3a24"), "ore": Color("ff6a1a"), "ore2": Color("ffd05a"), "suit": Color("2de2c5"), "water": Color("2a1420"), "deco": "lava"},  # lava
	{"rock": Color("1f3a48"), "floor": Color("3a6a78"), "ore": Color("5affd8"), "ore2": Color("e0fff6"), "suit": Color("ff5ab4"), "water": Color("061c2a"), "deco": "mushrooms"},  # glow
	{"rock": Color("3a4a70"), "floor": Color("9aaccc"), "ore": Color("ffd98a"), "ore2": Color("fff6d8"), "suit": Color("2de2c5"), "water": Color("0a1a3a"), "deco": "ruins"},  # atlantis
	{"rock": Color("1e2a3a"), "floor": Color("3e5068"), "ore": Color("b24aff"), "ore2": Color("e8c8ff"), "suit": Color("ffd23f"), "water": Color("0a0f22"), "deco": "tentacles"},  # kraken
	{"rock": Color("34455a"), "floor": Color("7c8ea0"), "ore": Color("f0e2c0"), "ore2": Color("9fe0ff"), "suit": Color("ff8a3d"), "water": Color("0a2030"), "deco": "whale"},  # whale
	{"rock": Color("4a1e24"), "floor": Color("8a4238"), "ore": Color("ff5a2a"), "ore2": Color("ffd23f"), "suit": Color("2de2c5"), "water": Color("2a0c12"), "deco": "dragon"},  # dragon
	{"rock": Color("1c2a5a"), "floor": Color("4a64a8"), "ore": Color("4de8ff"), "ore2": Color("e8ffff"), "suit": Color("ffc93c"), "water": Color("0a1450"), "deco": "heart"},  # heart
]


## The world's water from the surface down (OceanLook sets it per ocean).
static var sea_cols := PackedColorArray([SEA_TOP, SEA_MID, SEA_DEEP, SEA_ABYSS])


static func water_color(t: float) -> Color:
	## t: 0 at the surface, 1 at the bottom of the world.
	if t < 0.25:
		return sea_cols[0].lerp(sea_cols[1], t / 0.25)
	if t < 0.6:
		return sea_cols[1].lerp(sea_cols[2], (t - 0.25) / 0.35)
	return sea_cols[2].lerp(sea_cols[3], clampf((t - 0.6) / 0.4, 0.0, 1.0))


## Backdrop colors (sky, water, rock) a little less saturated, so cards,
## buttons and characters stand out against them.
const CALM := 0.0


static func calm(c: Color, amount: float = CALM) -> Color:
	if amount <= 0.0:
		return c
	var g := c.get_luminance()
	return Color(c.lerp(Color(g, g, g), amount), c.a)


static func shade_of(c: Color, amount: float = 0.24) -> Color:
	return Color(c.lerp(SHADE, amount), c.a)


# --- Shape builders (local space) ------------------------------------------------

static func circle_pts(c: Vector2, r: float, n: int = 0) -> PackedVector2Array:
	return ellipse_pts(c, Vector2(r, r), n)


static func ellipse_pts(c: Vector2, radii: Vector2, n: int = 0, rot: float = 0.0) -> PackedVector2Array:
	if n <= 0:
		n = clampi(int(maxf(radii.x, radii.y) * 0.75), 12, 32)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	return pts


## Rounded rectangle; `seg` steps per corner (0 = as few as look round).
static func rrect_pts(r: Rect2, radius: float, seg: int = 0) -> PackedVector2Array:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	if seg <= 0:
		seg = arc_steps(rad, PI / 2.0, 5)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI / 2.0],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2.0],
		[r.position + Vector2(rad, rad), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + PI / 2.0 * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Steps for an arc of `angle` radians so no chord strays more than
## ARC_TOL px from the curve (small corners need only one or two).
const ARC_TOL := 0.25


static func arc_steps(radius: float, angle: float, most: int) -> int:
	if radius <= ARC_TOL * 2.0:
		return 1
	return clampi(ceili(angle / (2.0 * acos(1.0 - ARC_TOL / radius))), 1, most)


static func moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out


## Smooth closed blob through the given points (Catmull-Rom).
static func smooth_pts(ctrl: PackedVector2Array, steps: int = 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## Merge of several polygons (cached): clouds, bushes, hair.
static func union(polys: Array) -> PackedVector2Array:
	var k := hash(["union", polys])
	if _geo.has(k):
		return _geo[k]
	var acc: PackedVector2Array = polys[0]
	for i in range(1, polys.size()):
		var merged := Geometry2D.merge_polygons(acc, polys[i])
		var best := 0.0
		for p in merged:
			var a := absf(_area(p))
			if a > best and not Geometry2D.is_polygon_clockwise(p) == Geometry2D.is_polygon_clockwise(acc) or a > best:
				best = a
				acc = p
	_geo[k] = acc
	return acc


## Part of `pts` inside `clip` (cached), e.g. shoulders inside a portrait.
static func clipped(pts: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var k := hash(["clip", pts, clip])
	if _geo.has(k):
		return _geo[k]
	var res := PackedVector2Array()
	var best := 0.0
	for p in Geometry2D.intersect_polygons(pts, clip):
		var a := absf(_area(p))
		if a > best:
			best = a
			res = p
	_geo[k] = res
	return res


# --- Toon drawing ----------------------------------------------------------------
#
# Everything is collected into one triangle list per canvas item and sent to
# the renderer as a single call when the item finishes drawing (see flush).
# Thousands of small polygons as separate calls were far too slow on phones.

const AA := 1.0          # soft edge width, in local pixels
## Shapes smaller than this (longest side, local px) get no soft edge.
const FRINGE_MIN := 6.0
## Big previews (the wardrobe, the avatar editor) set this to 0 to keep
## the soft edge on every shape. Part of every cache key.
static var fringe_min := FRINGE_MIN
## The same for discs and dots: radius.
const DOT_FRINGE_MIN := 1.5

## Phones: skip the soft outer edge of outlines (it doubles the triangle
## count; on dense phone screens the difference is hard to see).
static var low_power := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
const _QUAD_ALPHA := [1.0, 1.0, 0.0, 1.0, 0.0, 0.0]

static var _geo := {}
static var _cols := {}
static var _xf := Transform2D.IDENTITY
static var _stack: Array[Transform2D] = []
static var _bci: CanvasItem = null
static var _bv := PackedVector2Array()
static var _bc := PackedColorArray()


## Forgets every cached shape (after low_power changes).
static func clear_cache() -> void:
	_geo.clear()
	_cols.clear()
	_pc.clear()
	_pc_verts = 0


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a / 2.0


static func _bounds(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p:
		r = r.expand(v)
	return r


## Triangle list (3 vertices per triangle, no indices) of a simple polygon.
static func _tris(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p.size() < 3 or absf(_area(p)) < 0.5:
		return out
	for i in Geometry2D.triangulate_polygon(p):
		out.append(p[i])
	return out


## A soft 1px band outside a closed ring: 6 vertices per edge, the outer
## ones transparent (colors come from _QUAD_ALPHA).
static func _fringe(ring: PackedVector2Array, width: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	if n < 3:
		return out
	var sgn := 1.0 if _area(ring) < 0.0 else -1.0
	var nrm := PackedVector2Array()
	nrm.resize(n)
	for i in n:
		var a := ring[(i - 1 + n) % n]
		var b := ring[i]
		var c := ring[(i + 1) % n]
		var n1 := (b - a).orthogonal().normalized()
		var n2 := (c - b).orthogonal().normalized()
		var m := (n1 + n2).normalized()
		var d := maxf(0.35, m.dot(n2))
		nrm[i] = m * sgn * (width / d)
	for i in n:
		var j := (i + 1) % n
		var ai := ring[i]
		var aj := ring[j]
		out.append_array([ai, aj, aj + nrm[j], ai, aj + nrm[j], ai + nrm[i]])
	return out


## Closed ring without the points that lie within `tol` of the line
## joining their neighbours.
static func _simplify(ring: PackedVector2Array, tol: float) -> PackedVector2Array:
	var n := ring.size()
	if n < 8:
		return ring
	var out := PackedVector2Array()
	out.append(ring[0])
	for i in range(1, n):
		var a := out[out.size() - 1]
		var b := ring[i]
		var ac := ring[(i + 1) % n] - a
		var l := ac.length()
		if l > 0.001 and absf(ac.cross(b - a)) < tol * l and (b - a).dot(ac) > 0.0 and (b - a).length() < l:
			continue
		out.append(b)
	return out if out.size() >= 3 else ring


# --- Outline width -------------------------------------------------------------------
#
# Outline widths are given in the shape's local units, so a sprite drawn
# shrunk (the phone shore, small divers) got hairlines and one drawn big (a
# wardrobe preview) got heavy ones. The ink follows the drawing scale only
# part of the way (canvas width = w * scale^INK_FOLLOW), in coarse steps so cached
# shapes stay few; parts in the part cache are keyed by the same step.

## 1 = outlines scale with the drawing; 0 = the same width at any scale.
## Shrunk sprites keep more of their ink (no hairlines on phones); big
## previews thin it a little less, so lines drawn as outlines (glasses,
## brows) stay readable.
const INK_FOLLOW := 0.4
const INK_FOLLOW_UP := 0.7
const _INK_STEPS := 4.0           # steps per doubling of the scale
static var _ink_det := -1.0
static var _ink_step := 0


## Scale step of the current transform (0 = scale 1; +4 = twice as big).
static func _scale_step(xf: Transform2D) -> int:
	var det := absf(xf.determinant())
	if det == _ink_det:
		return _ink_step
	_ink_det = det
	_ink_step = 0 if det <= 0.0 else roundi(log(det) / log(2.0) / 2.0 * _INK_STEPS)
	return _ink_step


## Outline width in local units for the current transform.
## Also notes the scale step for _aa (the soft edge) and the shape keys.
static func _ink(w: float) -> float:
	_st = _scale_step(_rec_xf * _xf if _rec else _xf)
	if w <= 0.0 or _st == 0:
		return w
	return snappedf(w * pow(2.0, _st / _INK_STEPS * ((INK_FOLLOW if _st < 0 else INK_FOLLOW_UP) - 1.0)), 0.05)


static var _st := 0


## Soft edge width in local units: about one canvas pixel at any scale
## (a fixed local width blurred big previews and vanished on small sprites).
static func _aa() -> float:
	return AA if _st == 0 else AA * pow(2.0, -_st / _INK_STEPS)


static func _geo_for(pts: PackedVector2Array, w: float, shade: float) -> Array:
	w = _ink(w)
	var k := hash([pts, w, shade, fringe_min, _st])
	var g = _geo.get(k)
	if g != null:
		return g
	g = _build(pts, w, shade)
	_geo[k] = g
	return g


## Builds a shape once: [vertices, counts] where the vertices are the
## outline, its soft edge, the fill, the shadow band and the highlight, in
## that order, and counts holds how many vertices each part has.
static func _build(pts: PackedVector2Array, w: float, shade: float) -> Array:
	if _geo.size() > 8000:
		_geo.clear()
		_cols.clear()
	var outer := PackedVector2Array()
	var fringe := PackedVector2Array()
	if w > 0.0:
		var best := PackedVector2Array()
		var best_a := 0.0
		for p in Geometry2D.offset_polygon(pts, w, Geometry2D.JOIN_ROUND):
			var a := absf(_area(p))
			if a > best_a:
				best_a = a
				best = p
		# A round offset doubles the points of a smooth shape; drop the
		# ones that don't change it (half the outline triangles).
		best = _simplify(best, 0.2)
		outer = _tris(best)
		# Small shapes (eyes, gloves, rivets, icons) go without the soft edge:
		# at that size it can't be seen, and it is half of their triangles.
		if not outer.is_empty() and not low_power and maxf(_bounds(pts).size.x, _bounds(pts).size.y) >= fringe_min:
			fringe = _fringe(best, _aa())
	var fill := _tris(pts)
	var shadow := PackedVector2Array()
	var hi := PackedVector2Array()
	if shade > 0.0 and not fill.is_empty():
		var r := _bounds(pts)
		var d := clampf(r.size.y * 0.18, 1.5, 16.0) * shade
		# Bands thinner than a pixel can't be seen: skip their triangles.
		if d >= 1.0:
			for p in Geometry2D.clip_polygons(pts, moved(pts, Vector2(0, -d))):
				if Geometry2D.is_polygon_clockwise(p) == Geometry2D.is_polygon_clockwise(pts):
					shadow.append_array(_tris(p))
		var inset: Array[PackedVector2Array] = []
		if d >= 2.0:
			inset = Geometry2D.offset_polygon(pts, -clampf(r.size.y * 0.07, 1.0, 4.0))
		if inset.size() == 1:
			var ip: PackedVector2Array = inset[0]
			for p in Geometry2D.clip_polygons(ip, moved(ip, Vector2(0, d * 0.5))):
				if Geometry2D.is_polygon_clockwise(p) == Geometry2D.is_polygon_clockwise(ip):
					hi.append_array(_tris(p))
	if fill.is_empty():
		outer = PackedVector2Array()
		fringe = PackedVector2Array()
	var v := PackedVector2Array()
	for part in [outer, fringe, fill, shadow, hi]:
		v.append_array(part)
	return [v, PackedInt32Array([outer.size(), fringe.size(), fill.size(), shadow.size(), hi.size()])]


static func _solid(color: Color, n: int) -> PackedColorArray:
	var c := PackedColorArray()
	c.resize(n)
	c.fill(color)
	return c


## Colors for a soft edge band of `n` vertices (see _fringe).
static func _fringe_cols(color: Color, n: int) -> PackedColorArray:
	var k := hash(["f", color, n])
	var c = _cols.get(k)
	if c != null:
		return c
	c = PackedColorArray()
	c.resize(n)
	var clear := Color(color, 0.0)
	for i in n:
		c[i] = color if _QUAD_ALPHA[i % 6] > 0.5 else clear
	_cols[k] = c
	return c


static func _colors_for(g: Array, fill: Color, line: Color) -> PackedColorArray:
	var k := hash([g[1], fill, line])
	var c = _cols.get(k)
	if c != null and c.size() == g[0].size():
		return c
	var n: PackedInt32Array = g[1]
	c = PackedColorArray()
	c.append_array(_solid(line, n[0]))
	c.append_array(_fringe_cols(line, n[1]))
	c.append_array(_solid(fill, n[2]))
	c.append_array(_solid(shade_of(fill), n[3]))
	c.append_array(_solid(Color(1, 1, 1, 0.3 * fill.a), n[4]))
	if _cols.size() > 6000:
		_cols.clear()
	_cols[k] = c
	return c


## Adds already built triangles to the current batch of `ci`.
static func _put(ci: CanvasItem, v: PackedVector2Array, c: PackedColorArray) -> void:
	if v.is_empty():
		return
	if _rec:
		if _xf == Transform2D.IDENTITY:
			_rv.append_array(v)
		else:
			_rv.append_array(_xf * v)
		_rc.append_array(c)
		return
	if ci != _bci:
		flush()
		_bci = ci
		if not RenderingServer.frame_pre_draw.is_connected(flush):
			RenderingServer.frame_pre_draw.connect(flush)
	if _xf == Transform2D.IDENTITY:
		_bv.append_array(v)
	else:
		_bv.append_array(_xf * v)
	_bc.append_array(c)


# --- Part cache --------------------------------------------------------------------
#
# A part of a sprite that looks the same for the same few numbers (a diver's
# torso for one suit and emotion, a manager's portrait) is drawn once into
# a list of triangles and pasted after that with one call. The caller makes
# the key out of those few numbers, snapped so the same ones come back:
#
#   var k := hash([...])
#   if not Art.cache_begin(ci, k):
#       ...draw the part as usual...
#       Art.cache_end(ci, k)
#
# The part is recorded in the local space of the moment of the call, so it
# can sit under any push(). Nothing that draws text or uses CanvasItem.draw_*
# may go inside.

const PART_CACHE_VERTS := 450000

static var _pc := {}
static var _pc_verts := 0
## Counts frames, to drop the parts nobody asked for lately.
static var _pc_tick := 0
static var _rec := false
static var _rec_key := 0
static var _rv := PackedVector2Array()
static var _rc := PackedColorArray()
static var _rec_xf := Transform2D.IDENTITY
static var _rec_stack: Array[Transform2D] = []


## True when the part for `key` was already cached and has been drawn. False
## means: draw it now, then call cache_end with the same key.
static func cache_begin(ci: CanvasItem, key: int) -> bool:
	# Parts drawn at another scale step have other outline widths.
	key = hash([key, _scale_step(_rec_xf * _xf if _rec else _xf)])
	var e = _pc.get(key)
	if e != null:
		e[2] = _pc_tick
		_put(ci, e[0], e[1])
		return true
	if _rec:
		# A part inside a part is recorded as a piece of the outer one.
		return false
	_rec = true
	_rec_key = key
	_rv = PackedVector2Array()
	_rc = PackedColorArray()
	_rec_xf = _xf
	_rec_stack = _stack
	_xf = Transform2D.IDENTITY
	_stack = []
	return false


## Drops the parts not used for a couple of seconds; everything when that
## is not enough.
static func _evict() -> void:
	var cutoff := _pc_tick - 2
	for k in _pc.keys():
		var e: Array = _pc[k]
		if e[2] < cutoff:
			_pc_verts -= (e[0] as PackedVector2Array).size()
			_pc.erase(k)
	if _pc_verts > PART_CACHE_VERTS * 0.8:
		_pc.clear()
		_pc_verts = 0


static func cache_end(ci: CanvasItem, key: int) -> void:
	key = hash([key, _scale_step(_rec_xf)])
	if not _rec or _rec_key != key:
		return
	_rec = false
	_xf = _rec_xf
	_stack = _rec_stack
	if _pc_verts > PART_CACHE_VERTS:
		_evict()
	_pc[key] = [_rv, _rc, _pc_tick]
	_pc_verts += _rv.size()
	_put(ci, _rv, _rc)
	_rv = PackedVector2Array()
	_rc = PackedColorArray()


static var _ms: Array = []


## Measuring: everything drawn between measure_begin and measure_end is
## only collected (not drawn) and measure_end returns its bounds in the
## local space of the begin call.
static func measure_begin() -> void:
	_ms.append([_rec, _rv, _rc, _xf, _stack, _rec_key, _rec_xf])
	_rec = true
	_rec_key = 0
	_rec_xf = Transform2D.IDENTITY
	_rv = PackedVector2Array()
	_rc = PackedColorArray()
	_xf = Transform2D.IDENTITY
	_stack = []


static func measure_end() -> Rect2:
	# Only what can be seen: invisible helpers (alpha ~0) don't count.
	var r := Rect2()
	var any := false
	for i in _rv.size():
		if _rc[i].a < 0.05:
			continue
		if any:
			r = r.expand(_rv[i])
		else:
			r = Rect2(_rv[i], Vector2.ZERO)
			any = true
	var st: Array = _ms.pop_back()
	_rec = st[0]
	_rv = st[1]
	_rc = st[2]
	_xf = st[3]
	_stack = st[4]
	_rec_key = st[5]
	_rec_xf = st[6]
	return r


## While recording a cached part: the number of vertices recorded so far,
## to pass to fit_recorded as the start of a piece. -1 when not recording.
static func rec_mark() -> int:
	return _rv.size() if _rec else -1


## Keeps the piece recorded since `start` (a hat on a portrait's head)
## inside the circle (`center`, `radius`, current local space): first scales
## it about `anchor` by the largest factor >= kmin that fits, then clips
## whatever still sticks out. Only works while recording a cached part.
static func fit_recorded(start: int, center: Vector2, radius: float, anchor: Vector2, kmin: float = 1.0) -> void:
	if not _rec or start < 0 or start >= _rv.size():
		return
	var c := _xf * center
	var r := radius * _xf.get_scale().x
	var a := _xf * anchor
	var n := _rv.size()
	var far := 0.0
	for i in range(start, n):
		far = maxf(far, _rv[i].distance_squared_to(c))
	if far <= r * r:
		return
	if kmin < 1.0:
		var lo := kmin
		var hi := 1.0
		for it in 8:
			var k := (lo + hi) / 2.0
			var ok := true
			for i in range(start, n):
				if (a + (_rv[i] - a) * k).distance_squared_to(c) > r * r:
					ok = false
					break
			if ok:
				lo = k
			else:
				hi = k
		if lo < 1.0:
			for i in range(start, n):
				_rv[i] = a + (_rv[i] - a) * lo
	# Clip the triangles against the circle (as a 48-gon, inside it).
	var ring := PackedVector2Array()
	for i in 48:
		var ang := TAU * i / 48.0
		ring.append(c + Vector2(cos(ang), sin(ang)) * r)
	var inner := r * cos(PI / 48.0)
	var ov := _rv.slice(0, start)
	var oc := _rc.slice(0, start)
	for i in range(start, n - 2, 3):
		var p0 := _rv[i]
		var p1 := _rv[i + 1]
		var p2 := _rv[i + 2]
		if p0.distance_to(c) <= inner and p1.distance_to(c) <= inner and p2.distance_to(c) <= inner:
			ov.append_array([p0, p1, p2])
			oc.append_array([_rc[i], _rc[i + 1], _rc[i + 2]])
			continue
		var pv := PackedVector2Array([p0, p1, p2])
		var pc := PackedColorArray([_rc[i], _rc[i + 1], _rc[i + 2]])
		for e in 48:
			if pv.is_empty():
				break
			var e0 := ring[e]
			var e1 := ring[(e + 1) % 48]
			var nv := PackedVector2Array()
			var nc := PackedColorArray()
			var m := pv.size()
			for j in m:
				var q0 := pv[j]
				var q1 := pv[(j + 1) % m]
				var d0 := (e1 - e0).cross(q0 - e0)
				var d1 := (e1 - e0).cross(q1 - e0)
				if d0 >= 0.0:
					nv.append(q0)
					nc.append(pc[j])
				if (d0 >= 0.0) != (d1 >= 0.0):
					var f := d0 / (d0 - d1)
					nv.append(q0.lerp(q1, f))
					nc.append(pc[j].lerp(pc[(j + 1) % m], f))
			pv = nv
			pc = nc
		for j in range(1, pv.size() - 1):
			ov.append_array([pv[0], pv[j], pv[j + 1]])
			oc.append_array([pc[0], pc[j], pc[j + 1]])
	_rv = ov
	_rc = oc


## Sends the collected triangles as one draw call. Runs by itself when
## another canvas item starts drawing and right before the frame renders
## (a script's _draw runs after the `draw` signal, so that can't be used);
## call it by hand before drawing directly with CanvasItem.draw_*.
static func flush() -> void:
	_pc_tick = Engine.get_process_frames() / 60
	if _bci != null and not _bv.is_empty() and is_instance_valid(_bci):
		RenderingServer.canvas_item_add_triangle_array(_bci.get_canvas_item(), PackedInt32Array(), _bv, _bc)
	_bv = PackedVector2Array()
	_bc = PackedColorArray()
	_bci = null


static func _emit(ci: CanvasItem, g: Array, fill: Color, line: Color) -> void:
	var v: PackedVector2Array = g[0]
	if v.is_empty():
		return
	_put(ci, v, _colors_for(g, fill, line))


## The core call: outlined, shaded polygon. w = outline width (0 = none),
## shade = strength of the shadow/highlight bands (0 = flat).
static func toon(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 3.0, shade: float = 1.0, line: Color = INK) -> void:
	_emit(ci, _geo_for(pts, w, shade), fill, line)


## Flat filled polygon without outline, triangulated once.
static func flat(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	_emit(ci, _geo_for(pts, 0.0, 0.0), color, color)


## Flat polygon that changes every frame (not cached).
static func flat_now(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var v := _tris(pts)
	_put(ci, v, _solid(color, v.size()))


## Triangle or quad with a color per corner (gradients). Corners go around.
static func grad(ci: CanvasItem, p: PackedVector2Array, c: PackedColorArray) -> void:
	if p.size() == 3:
		_put(ci, p, c)
	else:
		_put(ci, PackedVector2Array([p[0], p[1], p[2], p[0], p[2], p[3]]), PackedColorArray([c[0], c[1], c[2], c[0], c[2], c[3]]))


static func t_circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = 3.0, shade: float = 1.0) -> void:
	w = _ink(w)
	var k := hash(["c", c, r, w, shade, fringe_min, _st])
	var g = _geo.get(k)
	if g == null:
		g = _build(circle_pts(c, r), w, shade)
		_geo[k] = g
	_emit(ci, g, fill, INK)


static func t_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, w: float = 3.0, shade: float = 1.0) -> void:
	w = _ink(w)
	var k := hash(["r", r, radius, w, shade, fringe_min, _st])
	var g = _geo.get(k)
	if g == null:
		g = _build(rrect_pts(r, radius), w, shade)
		_geo[k] = g
	_emit(ci, g, fill, INK)


static func t_ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, fill: Color, w: float = 3.0, shade: float = 1.0, rot: float = 0.0) -> void:
	w = _ink(w)
	var k := hash(["e", c, radii, w, shade, rot, fringe_min, _st])
	var g = _geo.get(k)
	if g == null:
		g = _build(ellipse_pts(c, radii, 0, rot), w, shade)
		_geo[k] = g
	_emit(ci, g, fill, INK)


## Filled disc with a soft edge (bubbles, dots, rivets).
static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	_ink(0.0)
	var k := hash(["d", r, _st])
	var g = _geo.get(k)
	if g == null:
		var ring := circle_pts(Vector2.ZERO, r, clampi(int(r * 1.6), 8, 40))
		var fr := _fringe(ring, _aa())
		var v := _tris(ring)
		g = [v, fr]
		_geo[k] = g
	var fv: PackedVector2Array = g[0]
	var fr2: PackedVector2Array = g[1]
	var save := _xf
	_xf = _xf * Transform2D(0.0, c)
	_put(ci, fv, _solid(color, fv.size()))
	if not low_power and (r >= DOT_FRINGE_MIN or fringe_min < 1.0):
		_put(ci, fr2, _fringe_cols(color, fr2.size()))
	_xf = save


## Thick line through `pts` with soft edges (built every call).
static func polyline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, closed: bool = false) -> void:
	if pts.size() < 2:
		return
	_ink(0.0)
	var g := _poly_geo(pts, color, width, closed)
	_put(ci, g[0], g[1])


## Closed outline that never changes shape (cached).
static func ring(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	_ink(0.0)
	var k := hash(["ring", pts, color, width, _st])
	var g = _geo.get(k)
	if g == null:
		g = _poly_geo(pts, color, width, true)
		_geo[k] = g
	_put(ci, g[0], g[1])


static func _poly_geo(pts: PackedVector2Array, color: Color, width: float, closed: bool) -> Array:
	var n := pts.size()
	# Low power: no soft edges, the core covers about as much instead.
	var soft := not low_power
	var aa := _aa()
	var hw := width / 2.0 if soft else (width + aa) / 2.0
	var edge := hw + aa
	var left := PackedVector2Array()
	var dirs := PackedVector2Array()
	left.resize(n)
	dirs.resize(n)
	for i in n:
		var prev: Vector2
		var next: Vector2
		if closed:
			prev = pts[(i - 1 + n) % n]
			next = pts[(i + 1) % n]
		else:
			prev = pts[maxi(i - 1, 0)]
			next = pts[mini(i + 1, n - 1)]
		var d1 := (pts[i] - prev).normalized() if pts[i] != prev else (next - pts[i]).normalized()
		var d2 := (next - pts[i]).normalized() if next != pts[i] else d1
		var nrm := (d1 + d2).orthogonal().normalized()
		if nrm == Vector2.ZERO:
			nrm = d1.orthogonal()
		var s := maxf(0.4, nrm.dot(d2.orthogonal()))
		left[i] = nrm / s
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var clear := Color(color, 0.0)
	var segs := n if closed else n - 1
	for i in segs:
		var j := (i + 1) % n
		var a := pts[i]
		var b := pts[j]
		var la := left[i]
		var lb := left[j]
		# core
		v.append_array([a + la * hw, b + lb * hw, b - lb * hw, a + la * hw, b - lb * hw, a - la * hw])
		c.append_array([color, color, color, color, color, color])
		if not soft:
			continue
		# soft edges on both sides
		v.append_array([a + la * hw, b + lb * hw, b + lb * edge, a + la * hw, b + lb * edge, a + la * edge])
		c.append_array([color, color, clear, color, clear, clear])
		v.append_array([a - la * hw, b - lb * hw, b - lb * edge, a - la * hw, b - lb * edge, a - la * edge])
		c.append_array([color, color, clear, color, clear, clear])
	return [v, c]


static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	polyline(ci, PackedVector2Array([a, b]), color, width)


static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var full := absf(a1 - a0) >= TAU - 0.001
	var count := n if full else n + 1
	for i in count:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	polyline(ci, pts, color, width, full)


## Outlined thick stroke (ropes, stems, handles).
static func stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, w: float = 2.5) -> void:
	w = _ink(w)
	if w > 0.0:
		polyline(ci, pts, INK, width + w * 2.0)
		disc(ci, pts[0], (width + w * 2.0) / 2.0, INK)
		disc(ci, pts[pts.size() - 1], (width + w * 2.0) / 2.0, INK)
	polyline(ci, pts, color, width)
	disc(ci, pts[0], width / 2.0, color)
	disc(ci, pts[pts.size() - 1], width / 2.0, color)


static func push(ci: CanvasItem, pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_stack.append(_xf)
	_xf = _xf * Transform2D(rot, scale, 0.0, pos)


static func pop(ci: CanvasItem) -> void:
	_xf = _stack.pop_back() if not _stack.is_empty() else Transform2D.IDENTITY


## Text with a thick dark outline, centered on x when `center` is set.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color = WHITE,
		outline: int = 6, center: bool = true, font: Font = null) -> void:
	if font == null:
		font = UiTheme.heavy_font()
	var p := pos
	if center:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if ci == _bci:
		flush()
	ci.draw_set_transform_matrix(_xf)
	if outline > 0:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Small shared sprites ------------------------------------------------------------

## Gold coin with a rim, an embossed star and a shine.
static func coin(ci: CanvasItem, center: Vector2, r: float) -> void:
	push(ci, center, 0.0, Vector2.ONE * (r / 20.0))
	t_circle(ci, Vector2.ZERO, 20, GOLD_DARK, 3.0, 0.0)
	t_circle(ci, Vector2(0, -1.5), 16, GOLD, 0.0, 0.8)
	toon(ci, star_pts(Vector2(0, -1), 9.0, 4.2, 5), Color("ffe38a"), 0.0, 0.0)
	flat(ci, ellipse_pts(Vector2(-8, -9), Vector2(3.5, 2.2), 12, -0.6), Color(1, 1, 1, 0.85))
	pop(ci)


static func star_pts(c: Vector2, r_out: float, r_in: float, points: int, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


## Faceted gem sticking out of the ground at `b`, pointing along `tilt`.
static func crystal(ci: CanvasItem, b: Vector2, h: float, w: float, tilt: float, color: Color, outline: float = 2.5) -> void:
	var up := Vector2(0, -1).rotated(tilt)
	var right := Vector2(1, 0).rotated(tilt)
	var pts := PackedVector2Array([b - right * w, b - right * w + up * h * 0.72, b + up * h, b + right * w + up * h * 0.72, b + right * w])
	toon(ci, pts, color, outline, 0.0)
	flat(ci, PackedVector2Array([b + right * w * 0.1, b + up * h * 0.97, b + right * w * 0.96 + up * h * 0.72, b + right * w * 0.96]), shade_of(color, 0.2))
	flat(ci, PackedVector2Array([b - right * w * 0.62 + up * h * 0.12, b - right * w * 0.62 + up * h * 0.66, b - right * w * 0.25 + up * h * 0.82, b - right * w * 0.25 + up * h * 0.12]), Color(1, 1, 1, 0.45))


## Cluster of gems (ore deposits and ore piles).
static func crystals(ci: CanvasItem, base: Vector2, size: float, style: Dictionary, seed: int, count: int = 4) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var order: Array[int] = []
	for i in count:
		order.append(i)
	# Tallest in the middle, drawn last.
	order.sort_custom(func(a, b): return absf(a - (count - 1) / 2.0) > absf(b - (count - 1) / 2.0))
	var specs := []
	for i in count:
		specs.append([rng.randf_range(-3, 3), rng.randf_range(0.65, 1.1), rng.randf_range(-0.28, 0.28)])
	for i in order:
		var off := float(i) - (count - 1) / 2.0
		var x: float = base.x + off * size * 0.34 + specs[i][0]
		var h: float = size * specs[i][1] * (1.0 - absf(off) * 0.16)
		crystal(ci, Vector2(x, base.y), h, size * 0.2, specs[i][2] + off * 0.12, style["ore"] if i % 2 == 0 else style["ore2"], maxf(1.5, size * 0.04))


## Padlock icon.
static func lock(ci: CanvasItem, center: Vector2, s: float) -> void:
	push(ci, center, 0.0, Vector2.ONE * (s / 20.0))
	arc(ci, Vector2(0, -8), 10, PI, TAU, 18, INK, 10)
	arc(ci, Vector2(0, -8), 10, PI, TAU, 18, METAL, 5)
	t_rect(ci, Rect2(-15, -8, 30, 24), 6, GOLD)
	t_circle(ci, Vector2(0, 2), 3.5, INK, 0.0, 0.0)
	flat(ci, PackedVector2Array([Vector2(-1.8, 2), Vector2(1.8, 2), Vector2(2.4, 10), Vector2(-2.4, 10)]), INK)
	pop(ci)


static func gear_pts(r: float, teeth: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in teeth * 4:
		var a := TAU * (i + 0.5) / (teeth * 4.0)
		var rr := r if (i % 4) < 2 else r * 0.76
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


static func gear(ci: CanvasItem, center: Vector2, r: float, color: Color, rot: float, teeth: int = 8) -> void:
	push(ci, center, rot, Vector2.ONE * (r / 20.0))
	toon(ci, gear_pts(20.0, teeth), color, 2.5, 0.6)
	t_circle(ci, Vector2.ZERO, 6.5, shade_of(color, 0.5), 2.0, 0.0)
	pop(ci)


## Small fish; `t` wags the tail.
static func fish(ci: CanvasItem, pos: Vector2, size: float, color: Color, facing: float, t: float) -> void:
	push(ci, pos, 0.0, Vector2(size * facing, size) / 10.0)
	var wag := sin(t * TAU * 2.0) * 0.35
	push(ci, Vector2(-8, 0), wag)
	toon(ci, PackedVector2Array([Vector2(1, 0), Vector2(-8, -6), Vector2(-6, 0), Vector2(-8, 6)]), shade_of(color, 0.15), 1.5, 0.0)
	pop(ci)
	toon(ci, ellipse_pts(Vector2.ZERO, Vector2(10, 6.5), 18), color, 1.5, 0.8)
	flat(ci, PackedVector2Array([Vector2(-2, -6), Vector2(3, -9), Vector2(5, -5)]), shade_of(color, 0.15))
	t_circle(ci, Vector2(5, -1.5), 2.2, WHITE, 1.0, 0.0)
	flat(ci, circle_pts(Vector2(5.6, -1.5), 1.1, 8), INK)
	pop(ci)


## Swaying seaweed strand with an outline.
static func seaweed(ci: CanvasItem, base: Vector2, height: float, color: Color, t: float, seed: float, width: float = 9.0) -> void:
	var pts := PackedVector2Array()
	var segs := 8
	for i in segs + 1:
		var f := float(i) / segs
		pts.append(base + Vector2(sin(t * 1.3 + seed + f * 2.4) * 11.0 * f, -height * f))
	var widths: Array[float] = []
	for i in segs:
		widths.append(lerpf(width, 3.0, float(i) / segs))
	# A tapered strand: outline, body, then light dashes along it.
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in segs + 1:
		var d := (pts[mini(i + 1, segs)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var hw := lerpf(width, 3.0, float(i) / segs) / 2.0
		l.append(pts[i] + d * hw)
		r.append(pts[i] - d * hw)
	r.reverse()
	l.append_array(r)
	flat_now(ci, _grown(l, 2.0), INK)
	flat_now(ci, l, color)
	for i in range(1, segs, 2):
		line(ci, pts[i], pts[i + 1], color.lightened(0.25), widths[i] * 0.3)


static func _grown(p: PackedVector2Array, by: float) -> PackedVector2Array:
	var g := Geometry2D.offset_polygon(p, by, Geometry2D.JOIN_ROUND)
	return g[0] if g.size() > 0 else p


## Up arrow for upgrade buttons.
static func arrow_pts(s: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -s), Vector2(s * 0.95, -s * 0.05), Vector2(s * 0.38, -s * 0.05),
			Vector2(s * 0.38, s * 0.9), Vector2(-s * 0.38, s * 0.9), Vector2(-s * 0.38, -s * 0.05), Vector2(-s * 0.95, -s * 0.05)])


## Soft round glow: `color` in the middle fading to clear at radius `r`.
static func glow(ci: CanvasItem, c: Vector2, r: float, color: Color, n: int = 18) -> void:
	var clear := Color(color, 0.0)
	var v := PackedVector2Array()
	var cols := PackedColorArray()
	var prev := c + Vector2(r, 0)
	for i in n:
		var a := TAU * (i + 1) / n
		var p := c + Vector2(cos(a), sin(a)) * r
		v.append_array([c, prev, p])
		cols.append_array([color, clear, clear])
		prev = p
	_put(ci, v, cols)


## Disc whose size or color changes every frame (bubbles, sparks, glows):
## radius snapped to 0.25 px so the geometry cache stays small, colors not
## cached (animated alpha would flood the color cache).
static func dot(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	r = maxf(0.25, snappedf(r, 0.25))
	# Alpha in steps of 5%: the colors of the animated dots are cached too.
	color.a = snappedf(color.a, 0.05)
	var k := -int(r * 4.0) - 1
	var g = _geo.get(k)
	if g == null:
		var ring_pts := circle_pts(Vector2.ZERO, r, clampi(int(r * 1.6), 8, 40))
		g = [_tris(ring_pts), _fringe(ring_pts, AA)]
		_geo[k] = g
	var fv: PackedVector2Array = g[0]
	var save := _xf
	_xf = _xf * Transform2D(0.0, c)
	_put(ci, fv, _solid(color, fv.size()))
	if not low_power and (r >= DOT_FRINGE_MIN or fringe_min < 1.0):
		var fr: PackedVector2Array = g[1]
		_put(ci, fr, _fringe_cols(color, fr.size()))
	_xf = save


## Open line through fixed points (geometry cached): details drawn every
## frame in the same place, like ribs on a shell or facets on a gem.
static func line_c(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var k := hash(["lc", pts, color, width])
	var g = _geo.get(k)
	if g == null:
		g = _poly_geo(pts, color, width, false)
		_geo[k] = g
	_put(ci, g[0], g[1])


## Arc that never changes (geometry cached), see arc().
static func arc_c(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, color: Color, width: float) -> void:
	var k := hash(["ac", c, r, a0, a1, n, color, width])
	var g = _geo.get(k)
	if g == null:
		var pts := PackedVector2Array()
		var full := absf(a1 - a0) >= TAU - 0.001
		var count := n if full else n + 1
		for i in count:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		g = _poly_geo(pts, color, width, full)
		_geo[k] = g
	_put(ci, g[0], g[1])
