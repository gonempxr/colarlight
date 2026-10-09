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

## One look per work site, by site id: rock, floor, ore colors, worker
## suit, the room's inside ("water": cave water, or the air of a dry cave)
## and its decor. Ocean sites first (plus the old ones of the 15-site
## ocean), then the volcano, the acid swamp and the moon.
const SITE_STYLE := {
	"shells": {"rock": Color("e3aa6c"), "floor": Color("f8d898"), "ore": Color("ffc6d6"), "ore2": Color("ff8fb0"), "suit": Color("ff8a3d"), "water": Color("2a9cc6"), "deco": "shells"},
	"coral": {"rock": Color("d9845c"), "floor": Color("f5c690"), "ore": Color("ff5d73"), "ore2": Color("ffa84a"), "suit": Color("ffd23f"), "water": Color("2283b6"), "deco": "coral"},
	"pearl": {"rock": Color("a88fc8"), "floor": Color("ded0ee"), "ore": Color("fbf8ff"), "ore2": Color("c6d4ff"), "suit": Color("ff6fae"), "water": Color("1f6aa8"), "deco": "pearls"},
	"copper": {"rock": Color("927668"), "floor": Color("c8ab94"), "ore": Color("f08a45"), "ore2": Color("ffc185"), "suit": Color("7fd34e"), "water": Color("1a5692"), "deco": "wreck"},
	"emerald": {"rock": Color("51817c"), "floor": Color("8cb8aa"), "ore": Color("3ee08f"), "ore2": Color("b0ffd9"), "suit": Color("9b72ff"), "water": Color("15457c"), "deco": "kelp"},
	"crystal": {"rock": Color("45427a"), "floor": Color("7470b0"), "ore": Color("b58cff"), "ore2": Color("f0e3ff"), "suit": Color("2de2c5"), "water": Color("102e60"), "deco": "glow"},
	"gold": {"rock": Color("7a5a34"), "floor": Color("d4b06a"), "ore": Color("ffd23f"), "ore2": Color("fff1a8"), "suit": Color("ef5350"), "water": Color("12304f"), "deco": "wreck"},
	"ice": {"rock": Color("7fa6c4"), "floor": Color("e4f4ff"), "ore": Color("bff4ff"), "ore2": Color("ffffff"), "suit": Color("ff6fae"), "water": Color("0f3358"), "deco": "ice"},
	"lava": {"rock": Color("4a2622"), "floor": Color("8a3a24"), "ore": Color("ff6a1a"), "ore2": Color("ffd05a"), "suit": Color("2de2c5"), "water": Color("2a1420"), "deco": "lava"},
	"glow": {"rock": Color("1f3a48"), "floor": Color("3a6a78"), "ore": Color("5affd8"), "ore2": Color("e0fff6"), "suit": Color("ff5ab4"), "water": Color("061c2a"), "deco": "mushrooms"},
	"atlantis": {"rock": Color("3a4a70"), "floor": Color("9aaccc"), "ore": Color("ffd98a"), "ore2": Color("fff6d8"), "suit": Color("2de2c5"), "water": Color("0a1a3a"), "deco": "ruins"},
	"kraken": {"rock": Color("1e2a3a"), "floor": Color("3e5068"), "ore": Color("b24aff"), "ore2": Color("e8c8ff"), "suit": Color("ffd23f"), "water": Color("0a0f22"), "deco": "tentacles"},
	"whale": {"rock": Color("34455a"), "floor": Color("7c8ea0"), "ore": Color("f0e2c0"), "ore2": Color("9fe0ff"), "suit": Color("ff8a3d"), "water": Color("0a2030"), "deco": "whale"},
	"heart": {"rock": Color("1c2a5a"), "floor": Color("4a64a8"), "ore": Color("4de8ff"), "ore2": Color("e8ffff"), "suit": Color("ffc93c"), "water": Color("0a1450"), "deco": "heart"},
	# Volcano: dark basalt tunnels lit by torches, magma veins and channels.
	"ash": {"rock": Color("4a4450"), "floor": Color("7a7078"), "ore": Color("c4bcc6"), "ore2": Color("ff9a4a"), "suit": Color("ff8a3d"), "water": Color("2e2630"), "deco": "ash"},
	"obsidian": {"rock": Color("3c3248"), "floor": Color("6a5e78"), "ore": Color("3a2e52"), "ore2": Color("c4a8ff"), "suit": Color("ffd23f"), "water": Color("261e32"), "deco": "obsidian"},
	"sulfur": {"rock": Color("4c4436"), "floor": Color("8a7c4a"), "ore": Color("ffe03a"), "ore2": Color("fff6a0"), "suit": Color("4fb3ee"), "water": Color("2e2a20"), "deco": "sulfur"},
	"ruby": {"rock": Color("4a3038"), "floor": Color("7a5058"), "ore": Color("ff3d6e"), "ore2": Color("ffb0c4"), "suit": Color("2de2c5"), "water": Color("2e1c24"), "deco": "crystals"},
	"magma": {"rock": Color("4a2a26"), "floor": Color("7a4030"), "ore": Color("ff6a1a"), "ore2": Color("ffd05a"), "suit": Color("2de2c5"), "water": Color("2e1a1a"), "deco": "lava"},
	"fire_opal": {"rock": Color("4c3434"), "floor": Color("845a48"), "ore": Color("ff8a3a"), "ore2": Color("7ae8ff"), "suit": Color("9b72ff"), "water": Color("2e2020"), "deco": "opal"},
	"garnet": {"rock": Color("46283a"), "floor": Color("744458"), "ore": Color("c8203e"), "ore2": Color("ff8a9a"), "suit": Color("ffd23f"), "water": Color("2a1824"), "deco": "crystals"},
	"ember": {"rock": Color("3e2a28"), "floor": Color("6e4232"), "ore": Color("ff5a1a"), "ore2": Color("ffc93c"), "suit": Color("4fb3ee"), "water": Color("281a1a"), "deco": "embers"},
	"phoenix": {"rock": Color("4c2a22"), "floor": Color("84503a"), "ore": Color("ffb02e"), "ore2": Color("ff4a2a"), "suit": Color("2de2c5"), "water": Color("2e1a16"), "deco": "phoenix"},
	"dragon": {"rock": Color("40202a"), "floor": Color("703c3a"), "ore": Color("ff5a2a"), "ore2": Color("ffd23f"), "suit": Color("2de2c5"), "water": Color("28141a"), "deco": "dragon"},
	# Acid swamp: mossy caves with glowing pools and mushrooms.
	"slime": {"rock": Color("5e6e40"), "floor": Color("a8c86a"), "ore": Color("8aff5a"), "ore2": Color("e0ffb0"), "suit": Color("ffd23f"), "water": Color("44583c"), "deco": "slime"},
	"moss": {"rock": Color("54643c"), "floor": Color("8eaa5c"), "ore": Color("5ac83a"), "ore2": Color("d2f58e"), "suit": Color("ff8a3d"), "water": Color("3c5034"), "deco": "moss"},
	"shroom": {"rock": Color("544870"), "floor": Color("9484b0"), "ore": Color("d07aff"), "ore2": Color("ffd0ff"), "suit": Color("7fd34e"), "water": Color("3c3456"), "deco": "mushrooms"},
	"bubble": {"rock": Color("44645e"), "floor": Color("80aca4"), "ore": Color("9affe8"), "ore2": Color("ffffff"), "suit": Color("ff6fae"), "water": Color("30504c"), "deco": "bubbles"},
	"venom": {"rock": Color("54386a"), "floor": Color("9466ae"), "ore": Color("b04aff"), "ore2": Color("ecaaff"), "suit": Color("7fd34e"), "water": Color("3e2a52"), "deco": "venom"},
	"amber": {"rock": Color("70502e"), "floor": Color("ca965c"), "ore": Color("ffb02e"), "ore2": Color("fff0a0"), "suit": Color("2de2c5"), "water": Color("54402a"), "deco": "amber"},
	"radiant": {"rock": Color("365440"), "floor": Color("60926e"), "ore": Color("b8ff3a"), "ore2": Color("f6ffc8"), "suit": Color("ff6fae"), "water": Color("284432"), "deco": "radiant"},
	"jade": {"rock": Color("34604e"), "floor": Color("6eaa8c"), "ore": Color("3ac88a"), "ore2": Color("b8ffe0"), "suit": Color("ff8a3d"), "water": Color("264a3e"), "deco": "lanterns"},
	"orchid": {"rock": Color("604060"), "floor": Color("ac80aa"), "ore": Color("ff7ad0"), "ore2": Color("fff0fa"), "suit": Color("7fd34e"), "water": Color("483048"), "deco": "orchids"},
	"goo_king": {"rock": Color("40345a"), "floor": Color("72609a"), "ore": Color("7aff4a"), "ore2": Color("ffe14a"), "suit": Color("ff5ab4"), "water": Color("2c2444"), "deco": "goo"},
	# Moon: tunnels with metal supports, crystals and space rocks.
	"dust": {"rock": Color("70748a"), "floor": Color("bcc0cf"), "ore": Color("dfe3ee"), "ore2": Color("9fe0ff"), "suit": Color("ff8a3d"), "water": Color("4a5068"), "deco": "base"},
	"meteor": {"rock": Color("524c62"), "floor": Color("908aa2"), "ore": Color("ff8a4a"), "ore2": Color("ffd08a"), "suit": Color("4fb3ee"), "water": Color("3a3650"), "deco": "crater"},
	"crater_ice": {"rock": Color("5e7290"), "floor": Color("cce2f2"), "ore": Color("bff4ff"), "ore2": Color("ffffff"), "suit": Color("ff6fae"), "water": Color("3a4c68"), "deco": "ice"},
	"moonstone": {"rock": Color("5e5e80"), "floor": Color("aaaacc"), "ore": Color("e8f0ff"), "ore2": Color("b0c8ff"), "suit": Color("ffd23f"), "water": Color("42426a"), "deco": "crystals"},
	"star": {"rock": Color("363666"), "floor": Color("6262a4"), "ore": Color("ffd23f"), "ore2": Color("fff6c0"), "suit": Color("ff5ab4"), "water": Color("24244e"), "deco": "stars"},
	"comet": {"rock": Color("405272"), "floor": Color("8494b8"), "ore": Color("8fe8ff"), "ore2": Color("ffffff"), "suit": Color("ff8a3d"), "water": Color("2a3a5a"), "deco": "comet"},
	"nebula": {"rock": Color("44326a"), "floor": Color("7462a6"), "ore": Color("ff6ad8"), "ore2": Color("9aaaff"), "suit": Color("2de2c5"), "water": Color("2c2050"), "deco": "void"},
	"alien_egg": {"rock": Color("365446"), "floor": Color("74948a"), "ore": Color("6aff8a"), "ore2": Color("e0ffd0"), "suit": Color("ff8a3d"), "water": Color("243e36"), "deco": "alien"},
	"ufo": {"rock": Color("424258"), "floor": Color("8282a0"), "ore": Color("a8bcd8"), "ore2": Color("6affe8"), "suit": Color("ffd23f"), "water": Color("2c2c44"), "deco": "ufo"},
	"cosmic_heart": {"rock": Color("242e64"), "floor": Color("5068ac"), "ore": Color("c86bff"), "ore2": Color("ffd0ff"), "suit": Color("ffc93c"), "water": Color("161e56"), "deco": "heart"},
}


static func _styles_for(ids: Array, tier: int = 0) -> Array[Dictionary]:
	var shift: float = 0.0 if tier <= 0 else [0.045, -0.045, 0.08, -0.08, 0.11, -0.11][(tier - 1) % 6]
	var out: Array[Dictionary] = []
	for id in ids:
		var st: Dictionary = SITE_STYLE.get(id, SITE_STYLE["shells"])
		if shift != 0.0:
			st = st.duplicate()
			for k in ["rock", "floor", "water"]:
				var c: Color = st[k]
				st[k] = Color.from_hsv(fposmod(c.h + shift, 1.0), c.s, c.v, c.a)
		out.append(st)
	return out


## Ids of the current world's sites, in Balance.DEPTHS order (WorldLook sets them).
static var site_ids: Array[String] = ["shells", "coral", "pearl", "copper", "emerald", "crystal", "gold", "ice", "lava",
		"glow", "atlantis", "kraken", "whale", "dragon", "heart"]
## One look per site of the current world, indexed like Balance.DEPTHS.
static var DEPTH_STYLE: Array[Dictionary] = _styles_for(site_ids)


static func set_world_sites(ids: Array[String], tier: int = 0) -> void:
	site_ids = ids.duplicate()
	DEPTH_STYLE = _styles_for(ids, tier)


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
	var hit = _gget(k)
	if hit != null:
		return hit
	var acc: PackedVector2Array = polys[0]
	for i in range(1, polys.size()):
		var merged := Geometry2D.merge_polygons(acc, polys[i])
		var best := 0.0
		for p in merged:
			var a := absf(_area(p))
			if a > best and not Geometry2D.is_polygon_clockwise(p) == Geometry2D.is_polygon_clockwise(acc) or a > best:
				best = a
				acc = p
	_gset(k, acc)
	return acc


## Part of `pts` inside `clip` (cached), e.g. shoulders inside a portrait.
static func clipped(pts: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var k := hash(["clip", pts, clip])
	var hit = _gget(k)
	if hit != null:
		return hit
	var res := PackedVector2Array()
	var best := 0.0
	for p in Geometry2D.intersect_polygons(pts, clip):
		var a := absf(_area(p))
		if a > best:
			best = a
			res = p
	_gset(k, res)
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
	_slots.clear()
	_geo.clear()
	_cols.clear()
	_ready.clear()
	_geo_old.clear()
	_cols_old.clear()
	_ready_old.clear()
	_pc.clear()
	_pc_old.clear()
	_pc_verts = 0


# Caches in two generations: when the young one is full it becomes the old
# one and a new young one starts; a hit in the old one moves back. Shapes
# used every frame always survive, one-off shapes (animated points, fading
# colors) fall out, and there is never a moment when everything has to be
# rebuilt at once (a full clear cost a 70 ms hitch).
const GEO_GEN := 6000
const COLS_GEN := 5000
const READY_GEN := 6000
static var _geo_old := {}
static var _cols_old := {}
static var _ready_old := {}


static func _gget(k: int) -> Variant:
	var v = _geo.get(k)
	if v == null:
		v = _geo_old.get(k)
		if v != null:
			_gset(k, v)
	return v


static func _gset(k: int, v: Variant) -> void:
	if _geo.size() >= GEO_GEN:
		_geo_old = _geo
		_geo = {}
	_geo[k] = v


static func _cget(k: int) -> Variant:
	var v = _cols.get(k)
	if v == null:
		v = _cols_old.get(k)
		if v != null:
			_cset(k, v)
	return v


static func _cset(k: int, v: Variant) -> void:
	if _cols.size() >= COLS_GEN:
		_cols_old = _cols
		_cols = {}
	_cols[k] = v


static func _rget(k: int) -> Variant:
	var v = _ready.get(k)
	if v == null:
		v = _ready_old.get(k)
		if v != null:
			_rset(k, v)
	return v


static func _rset(k: int, v: Variant) -> void:
	if _ready.size() >= READY_GEN:
		_ready_old = _ready
		_ready = {}
	_ready[k] = v


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
const INK_FOLLOW := 0.15
const INK_FOLLOW_UP := 0.5
const _INK_STEPS := 4.0           # steps per doubling of the scale
static var _ink_det := -1.0
## Outline widths are multiplied by this while a part drawn bigger than its
## body (a character's enlarged head) must keep the body's line width.
static var ink_mul := 1.0
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
	w *= ink_mul
	if w <= 0.0 or _st == 0:
		return w
	return snappedf(w * pow(2.0, _st / _INK_STEPS * ((INK_FOLLOW if _st < 0 else INK_FOLLOW_UP) - 1.0)), 0.05)


static var _st := 0


## Soft edge width in local units: about one canvas pixel at any scale
## (a fixed local width blurred big previews and vanished on small sprites).
static func _aa() -> float:
	return AA if _st == 0 else AA * pow(2.0, -_st / _INK_STEPS)


static func _geo_for(pts: PackedVector2Array, w: float, shade: float) -> Array:
	return _geo_inked(pts, _ink(w), shade)


## _geo_for with the outline width already through _ink.
static func _geo_inked(pts: PackedVector2Array, w: float, shade: float) -> Array:
	var k := hash([pts, w, shade, fringe_min, _st])
	var g = _gget(k)
	if g != null:
		return g
	g = _build(pts, w, shade)
	_gset(k, g)
	return g


# --- Ready shapes ---------------------------------------------------------------------
#
# A drawn shape is its triangles plus a color per vertex. Both are cached
# together under one key (the shape's points, widths, scale step and
# colors), so drawing a shape seen before is one hash, one lookup and one
# paste. Shapes whose colors animate are snapped by the callers (alpha in
# steps), and the cache is simply dropped when it grows too big.

static var _ready := {}


static func _ready_get(k: int) -> Variant:
	return _rget(k)


static func _ready_set(k: int, g: Array, fill: Color, line: Color) -> Array:
	var e: Array
	var v: PackedVector2Array = g[0]
	if v.is_empty():
		e = [v, PackedColorArray()]
	else:
		e = [v, _colors_for(g, fill, line)]
	_rset(k, e)
	return e


## Builds a shape once: [vertices, counts] where the vertices are the
## outline, its soft edge, the fill, the shadow band and the highlight, in
## that order, and counts holds how many vertices each part has.
static func _build(pts: PackedVector2Array, w: float, shade: float) -> Array:
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


## _solid, cached (for shapes drawn again and again in one color).
static func _solid_c(color: Color, n: int) -> PackedColorArray:
	var k := hash(["s", color, n])
	var c = _cget(k)
	if c != null:
		return c
	c = _solid(color, n)
	_cset(k, c)
	return c


static func _solid(color: Color, n: int) -> PackedColorArray:
	var c := PackedColorArray()
	c.resize(n)
	c.fill(color)
	return c


## Colors for a soft edge band of `n` vertices (see _fringe).
static func _fringe_cols(color: Color, n: int) -> PackedColorArray:
	var k := hash(["f", color, n])
	var c = _cget(k)
	if c != null:
		return c
	c = PackedColorArray()
	c.resize(n)
	var clear := Color(color, 0.0)
	for i in n:
		c[i] = color if _QUAD_ALPHA[i % 6] > 0.5 else clear
	_cset(k, c)
	return c


static func _colors_for(g: Array, fill: Color, line: Color) -> PackedColorArray:
	var k := hash([g[1], fill, line])
	var c = _cget(k)
	if c != null and c.size() == g[0].size():
		return c
	var n: PackedInt32Array = g[1]
	c = PackedColorArray()
	c.append_array(_solid(line, n[0]))
	c.append_array(_fringe_cols(line, n[1]))
	c.append_array(_solid(fill, n[2]))
	c.append_array(_solid(shade_of(fill), n[3]))
	c.append_array(_solid(Color(1, 1, 1, 0.3 * fill.a), n[4]))
	_cset(k, c)
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
	if e == null:
		e = _pc_old.get(key)
		if e != null:
			_pc_store(key, e)
	if e != null:
		_put(ci, e[0], e[1])
		return true
	# A part inside a part (or a slot) is recorded on its own too, then
	# pasted into the outer one.
	_rec_start(key)
	return false


## What is being recorded, saved while a part inside it records.
static var _rec_saves: Array = []


static func _rec_start(key: int) -> void:
	_rec_saves.append([_rec, _rv, _rc, _rec_key, _rec_xf, _rec_stack, _xf, _stack, _slot_stamp])
	var base := _rec_xf * _xf if _rec else _xf
	_rec = true
	_rec_key = key
	_rv = PackedVector2Array()
	_rc = PackedColorArray()
	_rec_xf = base
	_rec_stack = []
	_xf = Transform2D.IDENTITY
	_stack = []


## Ends the innermost recording: returns its [vertices, colors] and goes
## back to what was being drawn (or recorded) before it.
static func _rec_finish() -> Array:
	var out := [_rv, _rc]
	var st: Array = _rec_saves.pop_back()
	_rec = st[0]
	_rv = st[1]
	_rc = st[2]
	_rec_key = st[3]
	_rec_xf = st[4]
	_rec_stack = st[5]
	_xf = st[6]
	_stack = st[7]
	_slot_stamp = st[8]
	return out


## The part cache has two generations like the shape caches (see _gget):
## when the young one holds PART_CACHE_VERTS / 2 vertices it becomes the
## old one. Parts drawn every frame move back on their next use, so they
## are never all thrown away at once (that cost a big hitch every few
## seconds while time-stepped parts filled the cache).
static var _pc_old := {}


static func _pc_store(key: int, e: Array) -> void:
	var n := (e[0] as PackedVector2Array).size()
	if _pc_verts + n > PART_CACHE_VERTS / 2:
		_pc_old = _pc
		_pc = {}
		_pc_verts = 0
	_pc[key] = e
	_pc_verts += n


static func cache_end(ci: CanvasItem, key: int) -> void:
	key = hash([key, _scale_step(_rec_xf)])
	if not _rec or _rec_key != key:
		return
	var r := _rec_finish()
	_pc_store(key, [r[0], r[1]])
	_put(ci, r[0], r[1])


# --- Sprite slots -------------------------------------------------------------------
#
# A moving sprite (a diver, a boat) whose shape animates: its look is
# recorded into its own slot and pasted at the current transform on every
# frame, so it MOVES at the full frame rate while its SHAPE (limbs, faces)
# is redrawn only when `stamp` changes (the caller steps it at SHAPE_HZ):
#
#   Art.push(ci, pos)
#   if not Art.slot_begin(ci, id, Art.shape_stamp(phase)):
#       ...draw the sprite at Vector2.ZERO as usual...
#       Art.slot_end(ci, id)
#   Art.pop(ci)
#
# One slot per id (the newest shape only), so slots never flood. Like
# parts, nothing that draws text or uses CanvasItem.draw_* may go inside.

## How often moving sprites change shape (frames per second of their
## limbs); low power redraws them a bit less often, and FrameGovernor
## lowers it on slow devices. Movement is not stepped.
const SHAPE_HZ := 30.0
const SHAPE_HZ_LOW := 20.0
static var shape_hz := SHAPE_HZ
const _SLOT_REC := 0x51074E7
static var _slots := {}
static var _slot_stamp := 0


## The shape step for a sprite: changes SHAPE_HZ times a second. `phase`
## (0..1) spreads the sprites over the frames so they don't all redraw at once.
static func shape_stamp(t: float, phase: float = 0.0) -> int:
	return floori(t * (minf(shape_hz, SHAPE_HZ_LOW) if low_power else shape_hz) + phase)


static func slot_begin(ci: CanvasItem, id: int, stamp: int) -> bool:
	stamp = hash([stamp, _scale_step(_rec_xf * _xf if _rec else _xf), fringe_min])
	var e = _slots.get(id)
	if e != null and e[2] == stamp:
		e[3] = _pc_tick
		_put(ci, e[0], e[1])
		return true
	_rec_start(id ^ _SLOT_REC)
	_slot_stamp = stamp
	return false


static func slot_end(ci: CanvasItem, id: int) -> void:
	if not _rec or _rec_key != id ^ _SLOT_REC:
		return
	var stamp := _slot_stamp
	var r := _rec_finish()
	if _slots.size() > 300:
		for k in _slots.keys():
			if _slots[k][3] < _pc_tick - 2:
				_slots.erase(k)
	_slots[id] = [r[0], r[1], stamp, _pc_tick]
	_put(ci, r[0], r[1])


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
	# Clip the triangles against the circle (as a 48-gon, inside it). The
	# clipping itself is native (Geometry2D); the colors of the new corners
	# are blended from the triangle's own (barycentric).
	var ring := PackedVector2Array()
	ring.resize(48)
	for i in 48:
		var ang := TAU * i / 48.0
		ring[i] = c + Vector2(cos(ang), sin(ang)) * r
	var inner := r * cos(PI / 48.0)
	var inner2 := inner * inner
	var ov := _rv.slice(0, start)
	var oc := _rc.slice(0, start)
	for i in range(start, n - 2, 3):
		var p0 := _rv[i]
		var p1 := _rv[i + 1]
		var p2 := _rv[i + 2]
		if p0.distance_squared_to(c) <= inner2 and p1.distance_squared_to(c) <= inner2 and p2.distance_squared_to(c) <= inner2:
			ov.append(p0)
			ov.append(p1)
			ov.append(p2)
			oc.append(_rc[i])
			oc.append(_rc[i + 1])
			oc.append(_rc[i + 2])
			continue
		# Far outside (all corners beyond the circle on one side): dropped.
		var lo := p0.min(p1).min(p2)
		var hi := p0.max(p1).max(p2)
		if lo.x > c.x + r or hi.x < c.x - r or lo.y > c.y + r or hi.y < c.y - r:
			continue
		var c0 := _rc[i]
		var c1 := _rc[i + 1]
		var c2 := _rc[i + 2]
		var e1 := p1 - p0
		var e2 := p2 - p0
		var den := e1.x * e2.y - e2.x * e1.y
		if absf(den) < 1e-9:
			continue
		for poly in Geometry2D.intersect_polygons(PackedVector2Array([p0, p1, p2]), ring):
			var pc := PackedColorArray()
			pc.resize(poly.size())
			for j in poly.size():
				var d := poly[j] - p0
				var u := (d.x * e2.y - e2.x * d.y) / den
				var v := (e1.x * d.y - d.x * e1.y) / den
				pc[j] = c0 * (1.0 - u - v) + c1 * u + c2 * v
			for idx in Geometry2D.triangulate_polygon(poly):
				ov.append(poly[idx])
				oc.append(pc[idx])
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
	w = _ink(w)
	var k := hash([pts, w, shade, fringe_min, _st, fill, line])
	var e = _rget(k)
	if e == null:
		e = _ready_set(k, _geo_inked(pts, w, shade), fill, line)
	_put(ci, e[0], e[1])


## Flat filled polygon without outline, triangulated once.
static func flat(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	# No outline and no bands: the triangles don't depend on the scale.
	var k := hash([pts, color, 7])
	var e = _rget(k)
	if e == null:
		var st := _st
		_st = 0
		e = _ready_set(k, _geo_inked(pts, 0.0, 0.0), color, color)
		_st = st
	_put(ci, e[0], e[1])


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
	var k := hash(["c", c, r, w, shade, fringe_min, _st, fill])
	var e = _rget(k)
	if e == null:
		var gk := hash(["c", c, r, w, shade, fringe_min, _st])
		var g = _gget(gk)
		if g == null:
			g = _build(circle_pts(c, r), w, shade)
			_gset(gk, g)
		e = _ready_set(k, g, fill, INK)
	_put(ci, e[0], e[1])


static func t_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, w: float = 3.0, shade: float = 1.0) -> void:
	w = _ink(w)
	var k := hash(["r", r, radius, w, shade, fringe_min, _st, fill])
	var e = _rget(k)
	if e == null:
		var gk := hash(["r", r, radius, w, shade, fringe_min, _st])
		var g = _gget(gk)
		if g == null:
			g = _build(rrect_pts(r, radius), w, shade)
			_gset(gk, g)
		e = _ready_set(k, g, fill, INK)
	_put(ci, e[0], e[1])


static func t_ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, fill: Color, w: float = 3.0, shade: float = 1.0, rot: float = 0.0) -> void:
	w = _ink(w)
	var k := hash(["e", c, radii, w, shade, rot, fringe_min, _st, fill])
	var e = _rget(k)
	if e == null:
		var gk := hash(["e", c, radii, w, shade, rot, fringe_min, _st])
		var g = _gget(gk)
		if g == null:
			g = _build(ellipse_pts(c, radii, 0, rot), w, shade)
			_gset(gk, g)
		e = _ready_set(k, g, fill, INK)
	_put(ci, e[0], e[1])


## Filled disc with a soft edge (bubbles, dots, rivets).
static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	_ink(0.0)
	var k := hash(["d", r, _st])
	var g = _gget(k)
	if g == null:
		var ring := circle_pts(Vector2.ZERO, r, clampi(int(r * 1.6), 8, 40))
		var fr := _fringe(ring, _aa())
		var v := _tris(ring)
		g = [v, fr]
		_gset(k, g)
	var fv: PackedVector2Array = g[0]
	var fr2: PackedVector2Array = g[1]
	var save := _xf
	_xf = _xf * Transform2D(0.0, c)
	_put(ci, fv, _solid_c(color, fv.size()))
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
	var g = _gget(k)
	if g == null:
		g = _poly_geo(pts, color, width, true)
		_gset(k, g)
	_put(ci, g[0], g[1])


static func _poly_geo(pts: PackedVector2Array, color: Color, width: float, closed: bool) -> Array:
	var n := pts.size()
	# Low power: no soft edges, the core covers about as much instead.
	var soft := not low_power
	var aa := _aa()
	var hw := width / 2.0 if soft else (width + aa) / 2.0
	var edge := hw + aa
	var left := PackedVector2Array()
	left.resize(n)
	for i in n:
		var p := pts[i]
		var prev: Vector2
		var next: Vector2
		if closed:
			prev = pts[i - 1] if i > 0 else pts[n - 1]
			next = pts[i + 1] if i < n - 1 else pts[0]
		else:
			prev = pts[i - 1] if i > 0 else p
			next = pts[i + 1] if i < n - 1 else p
		var d1 := (p - prev).normalized() if p != prev else (next - p).normalized()
		var d2 := (next - p).normalized() if next != p else d1
		var nrm := (d1 + d2).orthogonal().normalized()
		if nrm == Vector2.ZERO:
			nrm = d1.orthogonal()
		left[i] = nrm / maxf(0.4, nrm.dot(d2.orthogonal()))
	var segs := n if closed else n - 1
	var per := 18 if soft else 6
	var v := PackedVector2Array()
	v.resize(segs * per)
	var o := 0
	for i in segs:
		var j := i + 1 if i < n - 1 else 0
		var a := pts[i]
		var b := pts[j]
		var la := left[i]
		var lb := left[j]
		# core
		var a0 := a + la * hw
		var a1 := a - la * hw
		var b0 := b + lb * hw
		var b1 := b - lb * hw
		v[o] = a0
		v[o + 1] = b0
		v[o + 2] = b1
		v[o + 3] = a0
		v[o + 4] = b1
		v[o + 5] = a1
		if soft:
			# soft edges on both sides
			var a2 := a + la * edge
			var b2 := b + lb * edge
			var a3 := a - la * edge
			var b3 := b - lb * edge
			v[o + 6] = a0
			v[o + 7] = b0
			v[o + 8] = b2
			v[o + 9] = a0
			v[o + 10] = b2
			v[o + 11] = a2
			v[o + 12] = a1
			v[o + 13] = b1
			v[o + 14] = b3
			v[o + 15] = a1
			v[o + 16] = b3
			v[o + 17] = a3
		o += per
	return [v, _poly_cols(color, segs, soft)]


## Vertex colors of a polyline of `segs` segments (see _poly_geo).
static func _poly_cols(color: Color, segs: int, soft: bool) -> PackedColorArray:
	var k := hash(["pl", color, segs, soft])
	var c = _cget(k)
	if c != null:
		return c
	var per := 18 if soft else 6
	c = PackedColorArray()
	c.resize(segs * per)
	c.fill(color)
	if soft:
		var clear := Color(color, 0.0)
		for i in segs:
			var o := i * per
			for q in [8, 10, 11, 14, 16, 17]:
				c[o + q] = clear
	_cset(k, c)
	return c


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
	# A unit fan (cached per n), scaled to r; colors cached per color.
	var gk := hash(["glow", n])
	var v = _gget(gk)
	if v == null:
		v = PackedVector2Array()
		v.resize(n * 3)
		var prev := Vector2(1, 0)
		for i in n:
			var a := TAU * (i + 1) / n
			var p := Vector2(cos(a), sin(a))
			v[i * 3] = Vector2.ZERO
			v[i * 3 + 1] = prev
			v[i * 3 + 2] = p
			prev = p
		_gset(gk, v)
	var ck := hash(["glow", n, color])
	var cols = _cget(ck)
	if cols == null:
		cols = PackedColorArray()
		cols.resize(n * 3)
		cols.fill(Color(color, 0.0))
		for i in n:
			cols[i * 3] = color
		_cset(ck, cols)
	var save := _xf
	_xf = _xf * Transform2D(0.0, Vector2(r, r), 0.0, c)
	_put(ci, v, cols)
	_xf = save


## Disc whose size or color changes every frame (bubbles, sparks, glows):
## radius snapped to 0.25 px so the geometry cache stays small, colors not
## cached (animated alpha would flood the color cache).
static func dot(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	r = maxf(0.25, snappedf(r, 0.25))
	# Alpha in steps of 5%: the colors of the animated dots are cached too.
	color.a = snappedf(color.a, 0.05)
	var k := -int(r * 4.0) - 1
	var g = _gget(k)
	if g == null:
		var ring_pts := circle_pts(Vector2.ZERO, r, clampi(int(r * 1.6), 8, 40))
		g = [_tris(ring_pts), _fringe(ring_pts, AA)]
		_gset(k, g)
	var fv: PackedVector2Array = g[0]
	var save := _xf
	_xf = _xf * Transform2D(0.0, c)
	_put(ci, fv, _solid_c(color, fv.size()))
	if not low_power and (r >= DOT_FRINGE_MIN or fringe_min < 1.0):
		var fr: PackedVector2Array = g[1]
		_put(ci, fr, _fringe_cols(color, fr.size()))
	_xf = save


## Open line through fixed points (geometry cached): details drawn every
## frame in the same place, like ribs on a shell or facets on a gem.
static func line_c(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var k := hash(["lc", pts, color, width])
	var g = _gget(k)
	if g == null:
		g = _poly_geo(pts, color, width, false)
		_gset(k, g)
	_put(ci, g[0], g[1])


## Arc that never changes (geometry cached), see arc().
static func arc_c(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, color: Color, width: float) -> void:
	var k := hash(["ac", c, r, a0, a1, n, color, width])
	var g = _gget(k)
	if g == null:
		var pts := PackedVector2Array()
		var full := absf(a1 - a0) >= TAU - 0.001
		var count := n if full else n + 1
		for i in count:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		g = _poly_geo(pts, color, width, full)
		_gset(k, g)
	_put(ci, g[0], g[1])
