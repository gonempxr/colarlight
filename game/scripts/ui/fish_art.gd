class_name FishArt
extends RefCounted
## The fishing species (~100 px long at scale 1), drawn in local space
## centered at (0,0) and facing right, in the game's toon style: thick ink
## outline, shade band, big shiny eyes and a smile. Animation comes from `t`
## through transforms only (tail wag, fin flaps, blinks), so shapes stay
## cached. Also the bucket, the book and the rod used by the fishing UI, and
## a dock icon texture.
##
##   FishArt.draw(ci, "clownfish", t)                 # normal
##   FishArt.draw(ci, "koi", t, 1.0, true)            # happy (catch card)
##   FishArt.draw(ci, "golden", t, 1.0, false, true)  # unknown: silhouette

const W := 2.6
const W2 := 2.0
const SIL := Color("46406e")

static var _sil := false
## The world the fish live in (0 ocean, 1 volcano: fire fish, 2 acid swamp:
## slimy greens, 3 moon: space fish). Colors are turned into the world's
## range and a little world effect is added around them.
static var world := 0
## Hue ranges the colors are squeezed into, per world.
const WORLD_HUES := [Vector2(0.0, 1.0), Vector2(-0.03, 0.13), Vector2(0.17, 0.42), Vector2(0.5, 0.86)]


## facing: 1 = right, -1 = left. silhouette = dark shape without details.
static func draw(ci: CanvasItem, id: String, t: float, facing: float = 1.0, happy: bool = false, silhouette: bool = false) -> void:
	_sil = silhouette
	var sd := float(maxi(FishData.ids().find(id), 0)) * 0.73
	var blink := not happy and not silhouette and fposmod(t + sd, 3.4 + fposmod(sd, 0.9)) < 0.13
	var speed := 11.0 if happy else 5.0
	var tt := t * speed / 5.0 + sd
	var bob := sin(t * 2.2 + sd) * 1.5
	if world != 0 and not silhouette:
		_world_back(ci, t + sd)
	Art.push(ci, Vector2(0, bob), sin(t * 1.3 + sd) * 0.03, Vector2(facing, 1.0))
	match id:
		"sardine": _sardine(ci, tt, blink, happy)
		"perch": _perch(ci, tt, blink, happy)
		"goby": _goby(ci, tt, blink, happy)
		"flounder": _flounder(ci, tt, blink, happy)
		"mackerel": _mackerel(ci, tt, blink, happy)
		"clownfish": _clownfish(ci, tt, blink, happy)
		"tang": _tang(ci, tt, blink, happy)
		"puffer": _puffer(ci, tt, blink, happy)
		"butterfly": _butterfly(ci, tt, blink, happy)
		"catfish": _catfish(ci, tt, blink, happy)
		"angelfish": _angelfish(ci, tt, blink, happy)
		"lionfish": _lionfish(ci, tt, blink, happy)
		"swordfish": _swordfish(ci, tt, blink, happy)
		"angler": _angler(ci, tt, blink, happy)
		"koi": _koi(ci, tt, blink, happy)
		"rainbow": _rainbow(ci, tt, blink, happy)
		"golden": _golden(ci, tt, blink, happy)
		"star_whale": _star_whale(ci, tt, blink, happy)
	Art.pop(ci)
	if world != 0 and not silhouette:
		_world_front(ci, t + sd)
	_sil = false


## A color moved into the current world's palette (greys stay).
static func _w(col: Color) -> Color:
	if world == 0 or col.s < 0.12:
		return col
	var r: Vector2 = WORLD_HUES[world]
	var s := minf(1.0, col.s * 1.05 + (0.08 if world == 1 else 0.0))
	return Color.from_hsv(fposmod(r.x + col.h * (r.y - r.x), 1.0), s, col.v, col.a)


static func _world_back(ci: CanvasItem, t: float) -> void:
	var g: Color = [Color.WHITE, Color(1.0, 0.55, 0.15, 0.12), Color(0.6, 1.0, 0.3, 0.1), Color(0.55, 0.8, 1.0, 0.14)][world]
	Art.flat(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(56, 32), 20), g)


static func _world_front(ci: CanvasItem, t: float) -> void:
	for i in 3:
		var f := fposmod(t * 0.6 + i / 3.0, 1.0)
		var a := snappedf(1.0 - f, 0.1)
		match world:
			1:
				# Embers rising off a fire fish.
				Art.disc(ci, Vector2(-14.0 + i * 14.0 + sin(f * 6.0 + i) * 4.0, -16.0 - f * 26.0), snappedf(2.6 - f * 1.4, 0.2), Color(1.0, 0.75 - 0.3 * f, 0.2, a))
			2:
				# Slime dripping off.
				Art.disc(ci, Vector2(-10.0 + i * 12.0, 12.0 + f * 18.0), snappedf(2.4 - f, 0.2), Color(0.65, 1.0, 0.3, a))
			3:
				# Tiny stars circling a space fish.
				var ang := t * 1.2 + TAU * i / 3.0
				Art.flat(ci, Art.star_pts(Vector2(cos(ang) * 46.0, sin(ang) * 22.0), 4.0, 1.4, 4), Color(1.0, 1.0, 0.85, 0.85))


## Soft glow and turning rays behind a fish (catch card, book), in the
## rarity's color. Stronger for rarer fish.
static func glow(ci: CanvasItem, c: Vector2, r: float, rarity: int, t: float) -> void:
	var col := FishData.rarity_color(rarity)
	if rarity >= FishData.RARE:
		var n := 8 + rarity * 2
		for i in n:
			var a := t * (0.3 + 0.1 * rarity) + TAU * i / n
			var ray := Color(col, 0.22 + 0.06 * rarity)
			Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a - 0.11), sin(a - 0.11)) * r * 1.25, c + Vector2(cos(a + 0.11), sin(a + 0.11)) * r * 1.25]),
					PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
	for k in 3:
		Art.flat(ci, Art.circle_pts(c, r * (0.55 + 0.2 * k), 28), Color(col, 0.13))


## Little four-point twinkles around a fish (rare and up).
static func sparkles(ci: CanvasItem, c: Vector2, r: float, t: float, n: int, col: Color = Color(1.0, 0.97, 0.7)) -> void:
	for i in n:
		var a := TAU * i / n + t * 0.35
		var f := fposmod(t * 0.8 + i * 0.37, 1.0)
		var s := sin(f * PI)
		var p := c + Vector2(cos(a), sin(a) * 0.75) * r * (0.75 + 0.3 * fposmod(i * 0.61, 1.0))
		Art.push(ci, p, 0.0, Vector2.ONE * s)
		Art.flat(ci, Art.star_pts(Vector2.ZERO, 9.0, 2.6, 4), col)
		Art.pop(ci)


# --- Shared parts ------------------------------------------------------------------------

static func _c(col: Color) -> Color:
	return Color(SIL, col.a) if _sil else _w(col)


## Closed fish body from nose (L, nose_y) to the tail joint (-B), height 2H.
static func _body_pts(L: float, B: float, H: float, belly: float = 1.0, nose_y: float = 0.0) -> PackedVector2Array:
	return Art.smooth_pts(PackedVector2Array([
		Vector2(L, nose_y), Vector2(L * 0.62, -H * 0.84), Vector2(L * 0.05, -H), Vector2(-B * 0.55, -H * 0.7),
		Vector2(-B, -H * 0.24), Vector2(-B, H * 0.24), Vector2(-B * 0.55, H * 0.68 * belly),
		Vector2(L * 0.05, H * belly), Vector2(L * 0.66, H * 0.74 * belly)]), 4)


static func _tail_pts(kind: String, s: float) -> PackedVector2Array:
	match kind:
		"fork":
			return PackedVector2Array([Vector2(3, -s * 0.22), Vector2(-s * 0.95, -s * 0.95), Vector2(-s * 0.58, 0), Vector2(-s * 0.95, s * 0.95), Vector2(3, s * 0.22)])
		"moon":
			return Art.smooth_pts(PackedVector2Array([Vector2(3, -s * 0.16), Vector2(-s * 0.5, -s * 0.62), Vector2(-s * 0.98, -s * 1.22),
					Vector2(-s * 0.68, 0), Vector2(-s * 0.98, s * 1.22), Vector2(-s * 0.5, s * 0.62), Vector2(3, s * 0.16)]), 2)
		"veil":
			return Art.smooth_pts(PackedVector2Array([Vector2(3, -s * 0.24), Vector2(-s * 0.7, -s * 0.85), Vector2(-s * 1.45, -s * 0.78),
					Vector2(-s * 1.2, -s * 0.12), Vector2(-s * 1.55, s * 0.55), Vector2(-s * 0.85, s * 0.92), Vector2(3, s * 0.24)]), 3)
		"fan":
			return Art.smooth_pts(PackedVector2Array([Vector2(3, -s * 0.3), Vector2(-s * 0.6, -s * 0.95), Vector2(-s * 1.05, -s * 0.6),
					Vector2(-s * 1.1, 0), Vector2(-s * 1.05, s * 0.6), Vector2(-s * 0.6, s * 0.95), Vector2(3, s * 0.3)]), 3)
	# round
	return Art.smooth_pts(PackedVector2Array([Vector2(3, -s * 0.28), Vector2(-s * 0.55, -s * 0.72), Vector2(-s * 1.0, -s * 0.38),
			Vector2(-s * 1.0, s * 0.38), Vector2(-s * 0.55, s * 0.72), Vector2(3, s * 0.28)]), 3)


static func _tail(ci: CanvasItem, joint: Vector2, kind: String, s: float, col: Color, t: float, amount: float = 0.16) -> void:
	Art.push(ci, joint, sin(t * 6.0) * amount)
	Art.toon(ci, _tail_pts(kind, s), _c(col), W, 0.3)
	if not _sil:
		for k in [-1.0, 0.0, 1.0]:
			Art.line(ci, Vector2(-s * 0.15, k * s * 0.12), Vector2(-s * 0.7, k * s * 0.42), Color(Art.shade_of(_w(col), 0.3), 0.5), 1.6)
	Art.pop(ci)


static func _fin(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	Art.toon(ci, pts, _c(col), W2, 0.25)


## Side fin that flaps; pivot at `at`, points back and down.
static func _pec(ci: CanvasItem, at: Vector2, col: Color, t: float, size: float = 1.0) -> void:
	if _sil:
		return
	col = _w(col)
	Art.push(ci, at, 0.45 + sin(t * 7.0) * 0.25, Vector2.ONE * size)
	Art.toon(ci, PackedVector2Array([Vector2(2, -1.5), Vector2(-5, -6), Vector2(-13, -7), Vector2(-11, -2), Vector2(-14, 3), Vector2(-5, 3.5), Vector2(2, 1.5)]), col, W2, 0.0)
	var ray := Color(Art.shade_of(col, 0.45), 0.7)
	Art.line(ci, Vector2(-1, -1), Vector2(-10, -5), ray, 1.3)
	Art.line(ci, Vector2(-1, 0.5), Vector2(-11, 1.5), ray, 1.3)
	Art.pop(ci)


static func _eye(ci: CanvasItem, c: Vector2, r: float, blink: bool, happy: bool) -> void:
	if _sil:
		return
	if happy:
		Art.arc(ci, c + Vector2(0, r * 0.45), r * 0.85, PI + 0.4, TAU - 0.4, 10, Art.INK, maxf(2.0, r * 0.42))
		return
	if blink:
		Art.arc(ci, c + Vector2(0, -r * 0.3), r * 0.85, 0.4, PI - 0.4, 10, Art.INK, maxf(2.0, r * 0.4))
		return
	Art.t_circle(ci, c, r, Art.WHITE, 2.0, 0.0)
	Art.flat(ci, Art.ellipse_pts(c + Vector2(r * 0.18, r * 0.04), Vector2(r * 0.64, r * 0.74), 16), Art.INK)
	Art.flat(ci, Art.circle_pts(c + Vector2(r * 0.4, -r * 0.3), r * 0.26, 8), Art.WHITE)
	Art.flat(ci, Art.circle_pts(c + Vector2(-r * 0.05, r * 0.36), r * 0.12, 6), Art.WHITE)


static func _smile(ci: CanvasItem, c: Vector2, w: float, happy: bool) -> void:
	if _sil:
		return
	if happy:
		var pts := PackedVector2Array([c + Vector2(-w, -w * 0.3), c + Vector2(w, -w * 0.3), c + Vector2(w * 0.6, w * 0.6), c + Vector2(-w * 0.5, w * 0.7)])
		Art.toon(ci, pts, Color("8a2140"), 1.4, 0.0)
	else:
		Art.arc(ci, c + Vector2(0, -w * 0.55), w, 0.55, PI - 0.55, 8, Art.INK, 1.9)


static func _cheek(ci: CanvasItem, c: Vector2, r: float) -> void:
	if not _sil:
		Art.flat(ci, Art.ellipse_pts(c, Vector2(r, r * 0.6), 12), Color(1.0, 0.4, 0.55, 0.45))


## A pattern shape (band, patch) cut to the body and filled flat.
static func _paint(ci: CanvasItem, shape: PackedVector2Array, body: PackedVector2Array, col: Color) -> void:
	if _sil:
		return
	var p := Art.clipped(shape, body)
	if p.size() >= 3:
		Art.flat(ci, p, _w(col))


static func _band(x: float, w: float, h: float, tilt: float = 0.0, y0: float = -1.0, y1: float = 1.0) -> PackedVector2Array:
	var top := h * y0 - 6.0
	var bot := h * y1 + 6.0
	return PackedVector2Array([Vector2(x - w / 2.0 + tilt * top, top), Vector2(x + w / 2.0 + tilt * top, top), Vector2(x + w / 2.0 + tilt * bot, bot), Vector2(x - w / 2.0 + tilt * bot, bot)])


static func _belly(ci: CanvasItem, body: PackedVector2Array, L: float, H: float, col: Color, span: float = 0.62) -> void:
	_paint(ci, Art.ellipse_pts(Vector2(L * 0.05, H * 0.98), Vector2(L * 1.1 * span / 0.62, H * 0.6), 24), body, col)


static func _back(ci: CanvasItem, body: PackedVector2Array, L: float, H: float, col: Color) -> void:
	_paint(ci, Art.ellipse_pts(Vector2(-L * 0.05, -H * 1.02), Vector2(L * 1.3, H * 0.55), 24), body, col)


static func _gloss(ci: CanvasItem, body: PackedVector2Array, c: Vector2, radii: Vector2) -> void:
	_paint(ci, Art.ellipse_pts(c, radii, 16, -0.12), body, Color(1, 1, 1, 0.3))


static func _body(ci: CanvasItem, body: PackedVector2Array, col: Color) -> void:
	Art.toon(ci, body, _c(col), W, 0.6)


# --- Common -----------------------------------------------------------------------------

static func _sardine(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 42.0
	var B := 24.0
	var H := 12.5
	var body := _body_pts(L, B, H)
	_tail(ci, Vector2(-B + 2, 0), "fork", 18.0, Color("86ade0"), t)
	_fin(ci, PackedVector2Array([Vector2(-10, -H + 2), Vector2(6, -H + 1), Vector2(-12, -H - 9)]), Color("86ade0"))
	_fin(ci, PackedVector2Array([Vector2(-14, H - 3), Vector2(-4, H - 1), Vector2(-16, H + 6)]), Color("86ade0"))
	_body(ci, body, Color("b9d6f2"))
	_back(ci, body, L, H, Color("4a78c0"))
	_belly(ci, body, L, H, Color("f2f8ff"))
	if not _sil:
		for x in [10.0, 1.0, -8.0]:
			Art.flat(ci, Art.circle_pts(Vector2(x, -2.5), 1.9, 8), Color("2d4a8a", 0.75))
	_gloss(ci, body, Vector2(8, -7), Vector2(18, 3))
	_pec(ci, Vector2(18, 4), Color("9fc0ea"), t, 0.8)
	_eye(ci, Vector2(28, -2), 6.2, blink, happy)
	_smile(ci, Vector2(38, 4), 3.0, happy)


static func _perch(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 36.0
	var B := 24.0
	var H := 18.0
	var body := _body_pts(L, B, H)
	var fin := Color("ff8a4c")
	_tail(ci, Vector2(-B + 2, 0), "fork", 16.0, fin, t)
	_fin(ci, PackedVector2Array([Vector2(-16, -H + 4), Vector2(-14, -H - 9), Vector2(-9, -H - 1), Vector2(-5, -H - 12), Vector2(-1, -H - 2),
			Vector2(3, -H - 12), Vector2(7, -H - 2), Vector2(11, -H - 9), Vector2(15, -H + 3)]), Color("7fa04a"))
	_fin(ci, PackedVector2Array([Vector2(-14, H - 3), Vector2(-4, H - 2), Vector2(-15, H + 8)]), fin)
	_body(ci, body, Color("cfd85c"))
	_belly(ci, body, L, H, Color("f6f0b5"))
	for i in 5:
		_paint(ci, _band(20.0 - i * 9.5, 6.0 - i * 0.4, H, 0.1, -1.0, 0.35), body, Color("4f7f3a", 0.85))
	_gloss(ci, body, Vector2(6, -11), Vector2(16, 3.5))
	_fin(ci, PackedVector2Array([Vector2(12, H - 4), Vector2(18, H - 3), Vector2(10, H + 7)]), fin)
	_pec(ci, Vector2(16, 3), fin, t, 0.9)
	_eye(ci, Vector2(23, -4), 7.0, blink, happy)
	_cheek(ci, Vector2(24, 5), 4.0)
	_smile(ci, Vector2(33, 5), 3.2, happy)


static func _goby(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 32.0
	var B := 20.0
	var H := 16.0
	var body := _body_pts(L, B, H, 1.05, 2.0)
	var fin := Color("e8b07a")
	_tail(ci, Vector2(-B + 2, 0), "round", 13.0, fin, t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-15, -H + 5), Vector2(-11, -H - 6), Vector2(-4, -H - 7), Vector2(0, -H + 3)]), 3), fin)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(2, -H + 2), Vector2(6, -H - 6), Vector2(12, -H - 5), Vector2(15, -H + 4)]), 3), fin)
	_body(ci, body, Color("dcae74"))
	_belly(ci, body, L, H, Color("f7e3bd"))
	for p: Vector3 in [Vector3(-10, -6, 3.2), Vector3(-2, 2, 2.6), Vector3(6, -8, 2.4), Vector3(-14, 4, 2.2), Vector3(12, 1, 2.0)]:
		_paint(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), body, Color("a86f3c", 0.8))
	_gloss(ci, body, Vector2(2, -10), Vector2(14, 3))
	_pec(ci, Vector2(10, 6), fin, t, 1.0)
	# Big eyes on top of the head.
	_eye(ci, Vector2(13, -14), 6.5, blink, happy)
	_eye(ci, Vector2(22, -12), 7.5, blink, happy)
	_cheek(ci, Vector2(22, 3), 4.5)
	_smile(ci, Vector2(29, 5), 4.2, happy)


static func _flounder(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 34.0
	var B := 24.0
	var H := 22.0
	# Frilly fin all around the flat body.
	var frill := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var k := 1.0 + 0.05 * sin(a * 14.0)
		frill.append(Vector2(4 + cos(a) * 33.0 * k, sin(a) * 28.0 * k))
	_tail(ci, Vector2(-B - 3, 0), "round", 11.0, Color("b3875a"), t, 0.12)
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(1.0, 1.0 + sin(t * 4.0) * 0.02))
	Art.toon(ci, frill, _c(Color("b3875a")), W2, 0.0)
	Art.pop(ci)
	var body := _body_pts(L, B, H, 1.0, 1.0)
	_body(ci, body, Color("c99d6c"))
	for p: Vector3 in [Vector3(-12, -8, 3.4), Vector3(-2, 8, 3.0), Vector3(-16, 8, 2.6), Vector3(4, -4, 2.2), Vector3(12, 10, 2.4)]:
		_paint(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), body, Color("8a613e", 0.8))
	for p: Vector3 in [Vector3(-6, -12, 2.4), Vector3(-20, 0, 2.0), Vector3(8, 4, 2.0)]:
		_paint(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), body, Color("f0d4a8"))
	_gloss(ci, body, Vector2(0, -14), Vector2(16, 3))
	# Both eyes on one side, a bit silly.
	_eye(ci, Vector2(14, -14), 5.8, blink, happy)
	_eye(ci, Vector2(24, -8), 5.8, blink, happy)
	_cheek(ci, Vector2(22, 6), 4.0)
	_smile(ci, Vector2(31, 6), 3.4, happy)


static func _mackerel(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 44.0
	var B := 26.0
	var H := 13.0
	var body := _body_pts(L, B, H)
	var fin := Color("3f8a9c")
	_tail(ci, Vector2(-B + 2, 0), "fork", 18.0, fin, t)
	_fin(ci, PackedVector2Array([Vector2(-2, -H + 2), Vector2(10, -H + 1), Vector2(0, -H - 9)]), fin)
	for i in 3:
		var x := -12.0 - i * 4.0
		_fin(ci, PackedVector2Array([Vector2(x + 2, -H * 0.6 + i), Vector2(x - 2, -H * 0.6 + i), Vector2(x - 1, -H * 0.6 - 5 + i)]), fin)
		_fin(ci, PackedVector2Array([Vector2(x + 2, H * 0.55 - i), Vector2(x - 2, H * 0.55 - i), Vector2(x - 1, H * 0.55 + 5 - i)]), fin)
	_body(ci, body, Color("5fb3c4"))
	_back(ci, body, L, H, Color("2f6f8f"))
	for i in 6:
		_paint(ci, _band(24.0 - i * 8.0, 3.2, H, 0.45, -1.0, -0.15), body, Color("1f4a66"))
	_belly(ci, body, L, H, Color("eef7f7"))
	_gloss(ci, body, Vector2(12, -2), Vector2(20, 2.5))
	_pec(ci, Vector2(20, 3), fin, t, 0.85)
	_eye(ci, Vector2(31, -2), 6.2, blink, happy)
	_smile(ci, Vector2(41, 4), 3.0, happy)


# --- Uncommon ---------------------------------------------------------------------------

static func _clownfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 32.0
	var B := 20.0
	var H := 18.0
	var body := _body_pts(L, B, H)
	var orange := Color("ff7a2a")
	_tail(ci, Vector2(-B + 2, 0), "round", 15.0, orange, t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-15, -H + 4), Vector2(-11, -H - 8), Vector2(0, -H - 10), Vector2(8, -H - 5), Vector2(12, -H + 2)]), 3), orange)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, H - 4), Vector2(-9, H + 7), Vector2(-1, H + 5), Vector2(2, H - 2)]), 3), orange)
	_body(ci, body, orange)
	for b: Vector2 in [Vector2(18, 9.0), Vector2(-1, 10.0), Vector2(-17, 6.0)]:
		_paint(ci, _band(b.x, b.y + 4.0, H, 0.08), body, Art.INK)
		_paint(ci, _band(b.x, b.y, H, 0.08), body, Art.WHITE)
	_gloss(ci, body, Vector2(4, -12), Vector2(14, 3))
	_pec(ci, Vector2(12, 5), orange, t)
	_eye(ci, Vector2(26, -4), 6.8, blink, happy)
	_cheek(ci, Vector2(27, 5), 3.5)
	_smile(ci, Vector2(30, 6), 3.0, happy)


static func _tang(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 32.0
	var B := 22.0
	var H := 22.0
	var body := _body_pts(L, B, H)
	var yellow := Color("ffd23f")
	var navy := Color("1b1f4a")
	_tail(ci, Vector2(-B + 2, 0), "moon", 14.0, yellow, t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, -H + 8), Vector2(-10, -H - 6), Vector2(8, -H - 7), Vector2(18, -H + 4)]), 3), Color("2a50b8"))
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, H - 8), Vector2(-10, H + 5), Vector2(6, H + 6), Vector2(14, H - 4)]), 3), Color("2a50b8"))
	_body(ci, body, Color("2f6ee8"))
	_paint(ci, Art.ellipse_pts(Vector2(-3, -5), Vector2(27, 11), 24, -0.08), body, navy)
	_paint(ci, Art.ellipse_pts(Vector2(-6, -4), Vector2(13, 4.5), 16, -0.08), body, Color("2f6ee8"))
	_paint(ci, Art.ellipse_pts(Vector2(-19, 0), Vector2(4, 8), 12), body, yellow)
	_gloss(ci, body, Vector2(4, -16), Vector2(14, 3))
	_pec(ci, Vector2(14, 6), yellow, t)
	_eye(ci, Vector2(24, -4), 7.0, blink, happy)
	_cheek(ci, Vector2(24, 7), 3.6)
	_smile(ci, Vector2(31, 5), 3.0, happy)


static func _puffer(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var puff := 1.0 + sin(t * 2.4) * 0.04
	Art.push(ci, Vector2(2, 0), 0.0, Vector2(puff, puff))
	_tail(ci, Vector2(-23, 0), "round", 10.0, Color("e8c060"), t, 0.25)
	var spikes := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var r := 31.0 if i % 2 == 0 else 24.0
		spikes.append(Vector2(cos(a) * r * 1.02, sin(a) * r * 0.95))
	Art.toon(ci, spikes, _c(Color("d8b060")), W2, 0.0)
	var body := Art.ellipse_pts(Vector2.ZERO, Vector2(26, 24), 32)
	_body(ci, body, Color("f2d27a"))
	_paint(ci, Art.ellipse_pts(Vector2(2, 16), Vector2(24, 14), 24), body, Color("fff4d6"))
	for p: Vector3 in [Vector3(-8, -12, 3.0), Vector3(2, -17, 2.4), Vector3(-15, -2, 2.6), Vector3(-4, -3, 2.0), Vector3(8, -9, 2.0)]:
		_paint(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), body, Color("b0804a", 0.85))
	_gloss(ci, body, Vector2(-4, -16), Vector2(12, 4))
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-6, -22), Vector2(-3, -30), Vector2(3, -29), Vector2(4, -22)]), 3), Color("e8c060"))
	_pec(ci, Vector2(6, 4), Color("e8c060"), t, 0.9)
	_eye(ci, Vector2(14, -7), 7.6, blink, happy)
	_cheek(ci, Vector2(17, 4), 4.2)
	if not _sil:
		if happy:
			_smile(ci, Vector2(24, 4), 3.4, true)
		else:
			Art.t_circle(ci, Vector2(25, 4), 3.4, Color("d0587a"), 2.0, 0.0)
	Art.pop(ci)


static func _butterfly(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(36, 2), Vector2(22, -10), Vector2(8, -24), Vector2(-10, -22), Vector2(-20, -8),
			Vector2(-20, 8), Vector2(-10, 22), Vector2(8, 24), Vector2(22, 10)]), 4)
	var yellow := Color("ffd23f")
	_tail(ci, Vector2(-18, 0), "round", 12.0, Color("fff2b0"), t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, -22), Vector2(-14, -27), Vector2(-26, -14), Vector2(-19, -4)]), 3), Color("ffc21a"))
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 22), Vector2(-14, 27), Vector2(-26, 14), Vector2(-19, 4)]), 3), Color("ffc21a"))
	_body(ci, body, yellow)
	_paint(ci, Art.ellipse_pts(Vector2(28, 0), Vector2(14, 20), 20), body, Color("fffbe8"))
	_paint(ci, _band(20.0, 7.5, 24.0, -0.12), body, Color("2a2440"))
	_paint(ci, Art.circle_pts(Vector2(-9, -10), 7.0, 16), body, Art.WHITE)
	_paint(ci, Art.circle_pts(Vector2(-9, -10), 5.0, 16), body, Color("2a2440"))
	_gloss(ci, body, Vector2(4, -17), Vector2(12, 3))
	_pec(ci, Vector2(10, 6), Color("fff2b0"), t)
	if not _sil and not blink and not happy:
		Art.t_circle(ci, Vector2(20, -4), 6.6, Art.WHITE, 2.0, 0.0)
	_eye(ci, Vector2(20, -4), 5.2, blink, happy)
	_smile(ci, Vector2(34, 4), 2.2, happy)


static func _catfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 42.0
	var B := 26.0
	var H := 15.0
	var body := _body_pts(L, B, H, 1.0, 3.0)
	var fin := Color("7a7fa6")
	_tail(ci, Vector2(-B + 2, 0), "round", 15.0, fin, t)
	_fin(ci, PackedVector2Array([Vector2(-2, -H + 2), Vector2(10, -H + 2), Vector2(0, -H - 12)]), fin)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-20, -H + 6), Vector2(-16, -H - 2), Vector2(-10, -H + 2)]), 3), fin)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-22, H - 5), Vector2(-14, H + 5), Vector2(-2, H + 3), Vector2(0, H - 3)]), 3), fin)
	_body(ci, body, Color("8f94b8"))
	_back(ci, body, L, H, Color("6a6f96"))
	_belly(ci, body, L, H, Color("e0e2f4"))
	_gloss(ci, body, Vector2(8, -7), Vector2(20, 2.5))
	# Whiskers sway a little.
	Art.push(ci, Vector2(38, 3), sin(t * 2.0) * 0.08)
	for w: PackedVector2Array in [PackedVector2Array([Vector2(0, 0), Vector2(7, 3), Vector2(12, 8), Vector2(14, 15), Vector2(12, 21)]),
			PackedVector2Array([Vector2(0, -2), Vector2(9, -5), Vector2(16, -4), Vector2(21, 0), Vector2(23, 5)])]:
		Art.polyline(ci, w, Art.INK, 3.4)
		Art.polyline(ci, w, _c(Color("b8bcdc")), 1.4)
	Art.pop(ci)
	_pec(ci, Vector2(18, 5), fin, t, 0.9)
	_eye(ci, Vector2(29, -5), 5.6, blink, happy)
	_cheek(ci, Vector2(30, 5), 3.6)
	_smile(ci, Vector2(37, 6), 5.0, happy)


# --- Rare -------------------------------------------------------------------------------

static func _angelfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(28, 0), Vector2(16, -16), Vector2(0, -22), Vector2(-14, -14), Vector2(-18, -4),
			Vector2(-18, 4), Vector2(-14, 14), Vector2(0, 22), Vector2(16, 16)]), 4)
	var blue := Color("3a8af0")
	Art.push(ci, Vector2(4, 0))
	_tail(ci, Vector2(-16, 0), "fan", 16.0, blue, t)
	var sway := sin(t * 3.0) * 0.06
	Art.push(ci, Vector2(-6, -16), sway)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(4, -4), Vector2(-2, -20), Vector2(-24, -34), Vector2(-16, -16), Vector2(-10, 2)]), 3), blue)
	Art.pop(ci)
	Art.push(ci, Vector2(-6, 16), -sway)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(4, 4), Vector2(-2, 20), Vector2(-24, 34), Vector2(-16, 16), Vector2(-10, -2)]), 3), blue)
	Art.pop(ci)
	_body(ci, body, Color("ffd84a"))
	for x in [12.0, 1.0, -10.0]:
		_paint(ci, _band(x, 3.6, 22.0, 0.0), body, Color("3a6fe0"))
	_paint(ci, Art.circle_pts(Vector2(12, -15), 4.5, 12), body, Color("3a6fe0"))
	_gloss(ci, body, Vector2(2, -14), Vector2(10, 3))
	if not _sil:
		Art.polyline(ci, PackedVector2Array([Vector2(8, 16), Vector2(4, 30), Vector2(-2, 42)]), Art.INK, 4.0)
		Art.polyline(ci, PackedVector2Array([Vector2(8, 16), Vector2(4, 30), Vector2(-2, 42)]), blue, 2.0)
	_pec(ci, Vector2(8, 4), Color("ffe790"), t)
	_eye(ci, Vector2(17, -3), 6.2, blink, happy)
	_cheek(ci, Vector2(18, 6), 3.4)
	_smile(ci, Vector2(26, 3), 2.6, happy)
	Art.pop(ci)


static func _lionfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 34.0
	var B := 22.0
	var H := 16.0
	var body := _body_pts(L, B, H)
	var red := Color("d8452e")
	var membrane := Color("ff9a7a", 0.85)
	_tail(ci, Vector2(-B + 2, 0), "round", 14.0, Color("ffc0a8"), t)
	# Long dorsal spines with little flags.
	for i in 6:
		var x := -12.0 + i * 5.0
		var top := Vector2(x - 6.0, -H - 20.0 - (6.0 if i % 2 == 0 else 0.0))
		var sway := sin(t * 2.5 + i) * 1.5
		top.x += sway
		if not _sil:
			Art.toon(ci, PackedVector2Array([Vector2(x, -H + 3), top, Vector2(x + 4, -H + 3)]), membrane, 1.4, 0.0)
		Art.line(ci, Vector2(x + 1, -H + 2), top, _c(Color("8a2a1e")), 2.0)
	# Big fan fins behind the body.
	Art.push(ci, Vector2(8, 4), sin(t * 2.0) * 0.1)
	var fan := PackedVector2Array([Vector2(0, 0)])
	for i in 7:
		var a := 1.7 + i * 0.28
		fan.append(Vector2(cos(a), sin(a)) * (34.0 + (i % 2) * 6.0))
	Art.toon(ci, fan, _c(membrane), W2, 0.0)
	if not _sil:
		for i in 7:
			var a := 1.7 + i * 0.28
			Art.line(ci, Vector2.ZERO, Vector2(cos(a), sin(a)) * (34.0 + (i % 2) * 6.0), red, 2.0)
	Art.pop(ci)
	_body(ci, body, Color("fff0e2"))
	for i in 8:
		_paint(ci, _band(26.0 - i * 7.0, 4.0, H, 0.15), body, red if i % 2 == 0 else Color("b8352a"))
	_gloss(ci, body, Vector2(4, -10), Vector2(14, 3))
	_eye(ci, Vector2(25, -4), 6.2, blink, happy)
	if not _sil:
		Art.polyline(ci, PackedVector2Array([Vector2(24, -10), Vector2(26, -17), Vector2(22, -21)]), Art.INK, 3.6)
		Art.polyline(ci, PackedVector2Array([Vector2(24, -10), Vector2(26, -17), Vector2(22, -21)]), Color("ffc0a8"), 1.6)
	_cheek(ci, Vector2(26, 5), 3.4)
	_smile(ci, Vector2(32, 5), 2.8, happy)


static func _swordfish(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 40.0
	var B := 30.0
	var H := 13.0
	Art.push(ci, Vector2(-10, 0), 0.0, Vector2(0.8, 0.8))
	var body := _body_pts(L, B, H)
	var dark := Color("2d4a8a")
	_tail(ci, Vector2(-B + 2, 0), "moon", 20.0, dark, t, 0.12)
	_fin(ci, PackedVector2Array([Vector2(12, -H + 3), Vector2(4, -H - 24), Vector2(-4, -H - 20), Vector2(-4, -H + 2)]), dark)
	_fin(ci, PackedVector2Array([Vector2(-14, H - 3), Vector2(-20, H + 9), Vector2(-24, H - 1)]), dark)
	Art.toon(ci, PackedVector2Array([Vector2(36, -3), Vector2(84, 1), Vector2(36, 4)]), _c(Color("c4cce0")), W2, 0.0)
	_body(ci, body, Color("5a7fc8"))
	_back(ci, body, L, H, dark)
	_belly(ci, body, L, H, Color("e4ecf8"))
	_gloss(ci, body, Vector2(10, -4), Vector2(20, 2.5))
	Art.push(ci, Vector2(18, 5), 0.5 + sin(t * 6.0) * 0.15)
	_fin(ci, PackedVector2Array([Vector2(2, -2), Vector2(-16, 6), Vector2(-4, 3)]), dark)
	Art.pop(ci)
	_eye(ci, Vector2(27, -3), 6.0, blink, happy)
	_smile(ci, Vector2(36, 4), 2.6, happy)
	Art.pop(ci)


static func _angler(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(28, 4), Vector2(20, -14), Vector2(2, -22), Vector2(-16, -16), Vector2(-22, -4),
			Vector2(-22, 6), Vector2(-14, 18), Vector2(4, 22), Vector2(22, 16)]), 4)
	var purple := Color("5b3f8e")
	Art.push(ci, Vector2(4, 4))
	_tail(ci, Vector2(-20, 0), "round", 13.0, Color("7c63b4"), t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-12, -16), Vector2(-16, -26), Vector2(-6, -24), Vector2(-2, -20)]), 3), Color("7c63b4"))
	# The glowing lure, bobbing on its stalk.
	var bulb := Vector2(36, -38 + sin(t * 3.0) * 3.0)
	if not _sil:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		Art.flat(ci, Art.circle_pts(bulb, 14.0 + pulse * 4.0, 20), Color(1.0, 0.95, 0.5, 0.18))
		Art.flat(ci, Art.circle_pts(bulb, 9.0 + pulse * 2.0, 16), Color(1.0, 0.95, 0.5, 0.3))
	var stalk := PackedVector2Array([Vector2(8, -20), Vector2(12, -36), Vector2(24, -46), bulb])
	Art.polyline(ci, stalk, Art.INK, 5.0)
	Art.polyline(ci, stalk, _c(Color("7c63b4")), 2.6)
	Art.t_circle(ci, bulb, 5.5, _c(Color("fff27a")), 2.0, 0.0)
	_body(ci, body, purple)
	_paint(ci, Art.ellipse_pts(Vector2(4, 18), Vector2(22, 10), 20), body, Color("7a62a8"))
	for p: Vector3 in [Vector3(-10, -10, 2.6), Vector3(-2, -16, 2.0), Vector3(-15, 2, 2.2), Vector3(-6, 6, 1.8)]:
		_paint(ci, Art.circle_pts(Vector2(p.x, p.y), p.z, 10), body, Color("7c63b4"))
	# Big toothy grin (a friendly one).
	if not _sil:
		var mouth := Art.clipped(Art.ellipse_pts(Vector2(22, 8), Vector2(11, 7), 20), body)
		if mouth.size() >= 3:
			Art.flat(ci, mouth, Color("2a1840"))
		for i in 4:
			var x := 14.0 + i * 4.0
			Art.toon(ci, PackedVector2Array([Vector2(x - 1.8, 3.5), Vector2(x + 1.8, 3.5), Vector2(x, 7.5)]), Art.WHITE, 1.0, 0.0)
		Art.flat(ci, Art.ellipse_pts(Vector2(20, 11.5), Vector2(4, 2), 10), Color("ff7f93"))
	_gloss(ci, body, Vector2(-2, -15), Vector2(10, 3))
	_pec(ci, Vector2(0, 8), Color("7c63b4"), t)
	_eye(ci, Vector2(14, -8), 5.8, blink, happy)
	Art.pop(ci)


# --- Epic ----------------------------------------------------------------------------------

static func _koi(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 40.0
	var B := 24.0
	var H := 15.0
	var body := _body_pts(L, B, H)
	var red := Color("ff5a2a")
	var veil := Color("ffe4d6", 0.95)
	Art.push(ci, Vector2(6, 0))
	_tail(ci, Vector2(-B + 2, 0), "veil", 20.0, veil, t, 0.2)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-12, -H + 3), Vector2(-6, -H - 8), Vector2(8, -H - 7), Vector2(14, -H + 2)]), 3), veil)
	_body(ci, body, Color("fffaf2"))
	_paint(ci, Art.ellipse_pts(Vector2(20, -7), Vector2(11, 7), 16, 0.3), body, red)
	_paint(ci, Art.ellipse_pts(Vector2(-2, 1), Vector2(10, 9), 16, -0.2), body, red)
	_paint(ci, Art.ellipse_pts(Vector2(-17, -6), Vector2(6, 5), 12), body, red)
	_paint(ci, Art.circle_pts(Vector2(6, -9), 2.4, 8), body, Color("2a2440"))
	_paint(ci, Art.circle_pts(Vector2(-10, 7), 2.0, 8), body, Color("2a2440"))
	_gloss(ci, body, Vector2(6, -8), Vector2(18, 2.5))
	if not _sil:
		for w: PackedVector2Array in [PackedVector2Array([Vector2(38, 4), Vector2(42, 7), Vector2(44, 11)]), PackedVector2Array([Vector2(35, 6), Vector2(36, 10), Vector2(34, 13)])]:
			Art.polyline(ci, w, Color(Art.INK, 0.8), 1.8)
	_pec(ci, Vector2(20, 6), Color("ffd0b8"), t, 1.1)
	_eye(ci, Vector2(28, -3), 5.6, blink, happy)
	_cheek(ci, Vector2(29, 5), 3.4)
	_smile(ci, Vector2(37, 4), 3.0, happy)
	Art.pop(ci)


static func _rainbow(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 34.0
	var B := 24.0
	var H := 18.0
	var body := _body_pts(L, B, H)
	var hue := snappedf(fposmod(t * 0.05, 1.0), 1.0 / 24.0)
	var fin := Color.from_hsv(fposmod(hue + 0.55, 1.0), 0.35, 1.0, 0.95)
	_tail(ci, Vector2(-B + 2, 0), "fork", 18.0, fin, t)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, -H + 4), Vector2(-10, -H - 10), Vector2(4, -H - 8), Vector2(12, -H + 2)]), 3), Color.from_hsv(fposmod(hue + 0.8, 1.0), 0.35, 1.0))
	_body(ci, body, Color("a8e4ff"))
	for i in 7:
		var h := fposmod(hue + i / 7.0, 1.0)
		_paint(ci, _band(26.0 - i * 7.5, 7.6, H, 0.18), body, Color.from_hsv(h, 0.45, 1.0, 0.9))
	if not _sil:
		for row in 3:
			for k in 5:
				var p := Vector2(16.0 - k * 8.0 - row * 3.0, -8.0 + row * 7.0)
				Art.arc(ci, p, 3.4, -1.2, 1.2, 6, Color(1, 1, 1, 0.55), 1.4)
	_gloss(ci, body, Vector2(4, -12), Vector2(16, 3))
	_pec(ci, Vector2(14, 4), fin, t)
	_eye(ci, Vector2(24, -3), 6.6, blink, happy)
	_cheek(ci, Vector2(25, 6), 3.8)
	_smile(ci, Vector2(31, 5), 3.0, happy)
	if not _sil:
		sparkles(ci, Vector2(0, 0), 46.0, t, 4)


# --- Legendary ------------------------------------------------------------------------------

static func _golden(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var L := 34.0
	var B := 22.0
	var H := 20.0
	var body := _body_pts(L, B, H)
	var gold := Color("ffc93c")
	var veil := Color("ffe07a", 0.95)
	Art.push(ci, Vector2(10, 2))
	_tail(ci, Vector2(-B + 2, 0), "veil", 24.0, veil, t, 0.22)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, -H + 5), Vector2(-14, -H - 12), Vector2(0, -H - 14), Vector2(10, -H + 2)]), 3), veil)
	_fin(ci, Art.smooth_pts(PackedVector2Array([Vector2(-12, H - 5), Vector2(-20, H + 10), Vector2(-4, H + 6)]), 3), veil)
	_body(ci, body, gold)
	_belly(ci, body, L, H, Color("ffe89a"))
	if not _sil:
		for row in 3:
			for k in 4:
				var p := Vector2(10.0 - k * 8.0 - row * 3.0, -9.0 + row * 8.0)
				Art.arc(ci, p, 4.0, -1.2, 1.2, 6, Color("e0921c", 0.7), 1.6)
	_gloss(ci, body, Vector2(4, -14), Vector2(15, 3.5))
	_pec(ci, Vector2(14, 5), veil, t)
	# A little crown: this is the fish that grants wishes.
	Art.push(ci, Vector2(14, -H - 1), -0.12 + sin(t * 1.5) * 0.04)
	var crown := PackedVector2Array([Vector2(-10, 0), Vector2(-11, -13), Vector2(-5, -6), Vector2(0, -16), Vector2(5, -6), Vector2(11, -13), Vector2(10, 0)])
	Art.toon(ci, crown, _c(Color("ffd23f")), W2, 0.5)
	if not _sil:
		Art.t_circle(ci, Vector2(0, -4), 2.6, Color("ff5a8a"), 1.4, 0.0)
		for x in [-11.0, 0.0, 11.0]:
			Art.flat(ci, Art.circle_pts(Vector2(x, -14.0 if x != 0.0 else -17.0), 2.0, 8), Art.WHITE)
	Art.pop(ci)
	_eye(ci, Vector2(24, -3), 6.8, blink, happy)
	if not _sil and not happy and not blink:
		for k in 3:
			var a := -2.2 + k * 0.35
			Art.line(ci, Vector2(24, -3) + Vector2(cos(a), sin(a)) * 6.5, Vector2(24, -3) + Vector2(cos(a), sin(a)) * 10.0, Art.INK, 1.8)
	_cheek(ci, Vector2(25, 6), 4.0)
	_smile(ci, Vector2(31, 5), 3.2, happy)
	Art.pop(ci)
	if not _sil:
		sparkles(ci, Vector2(0, 0), 52.0, t, 6)


static func _star_whale(ci: CanvasItem, t: float, blink: bool, happy: bool) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(40, 4), Vector2(36, -12), Vector2(18, -22), Vector2(-6, -20), Vector2(-26, -10),
			Vector2(-38, -3), Vector2(-38, 3), Vector2(-24, 10), Vector2(0, 16), Vector2(26, 17)]), 4)
	var deep := Color("3b3f9e")
	Art.push(ci, Vector2(6, 2))
	Art.push(ci, Vector2(-36, 0), -0.25 + sin(t * 3.0) * 0.15)
	Art.toon(ci, _tail_pts("moon", 16.0), _c(Color("4a4fb8")), W, 0.3)
	Art.pop(ci)
	_body(ci, body, deep)
	_paint(ci, Art.ellipse_pts(Vector2(10, 18), Vector2(32, 11), 24), body, Color("8b90e8"))
	if not _sil:
		var belly := Art.clipped(Art.ellipse_pts(Vector2(10, 18), Vector2(32, 11), 24), body)
		for i in 4:
			var groove := Art.clipped(_band(22.0 - i * 8.0, 1.6, 20.0, -0.15, 0.25, 1.2), belly)
			if groove.size() >= 3:
				Art.flat(ci, groove, Color("6a6fd0"))
		# Twinkling stars on the back.
		for i in 7:
			var p := Vector2(24.0 - i * 9.0, -12.0 + (i % 3) * 5.0 - (3.0 if i % 2 == 0 else 0.0))
			var s := 0.7 + 0.4 * sin(t * 3.0 + i * 1.9)
			Art.push(ci, p, 0.0, Vector2.ONE * s)
			Art.flat(ci, Art.star_pts(Vector2.ZERO, 4.6, 1.5, 4), Color("fff6a8"))
			Art.pop(ci)
	_gloss(ci, body, Vector2(10, -16), Vector2(16, 3))
	Art.push(ci, Vector2(14, 8), 0.6 + sin(t * 3.5) * 0.25)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(2, -2), Vector2(-8, -3), Vector2(-16, 4), Vector2(-6, 6)]), 3), _c(Color("4a4fb8")), W2, 0.0)
	Art.pop(ci)
	_eye(ci, Vector2(27, -3), 5.6, blink, happy)
	_cheek(ci, Vector2(28, 6), 4.0)
	_smile(ci, Vector2(34, 7), 4.6, happy)
	# A spout of sparkles.
	if not _sil:
		for i in 5:
			var f := fposmod(t * 0.6 + i * 0.2, 1.0)
			var p := Vector2(14.0 + (i - 2) * f * 6.0, -24.0 - f * 26.0)
			Art.push(ci, p, 0.0, Vector2.ONE * sin(f * PI))
			Art.flat(ci, Art.star_pts(Vector2.ZERO, 5.0, 1.6, 4), Color("bff3ff"))
			Art.pop(ci)
	Art.pop(ci)


# --- Fishing UI props -------------------------------------------------------------------

## Wooden bucket, bottom center at (0,0), ~60 px wide. `n` fish tails poke out.
static func bucket(ci: CanvasItem, n: int, t: float, full: bool = false) -> void:
	Art.arc(ci, Vector2(0, -44), 26.0, PI, TAU, 16, Art.INK, 6.0)
	Art.arc(ci, Vector2(0, -44), 26.0, PI, TAU, 16, Art.METAL, 2.6)
	var tails := mini(n, 4)
	var cols := [Color("ff7a2a"), Color("5fb3c4"), Color("ffd23f"), Color("b07cff")]
	for i in tails:
		var x := -14.0 + i * 9.5
		Art.push(ci, Vector2(x, -46), -0.35 + i * 0.25 + sin(t * 4.0 + i) * 0.12)
		Art.toon(ci, PackedVector2Array([Vector2(-3, 2), Vector2(-9, -12), Vector2(0, -7), Vector2(9, -12), Vector2(3, 2)]), cols[i], 2.0, 0.0)
		Art.pop(ci)
	var body := PackedVector2Array([Vector2(-30, -46), Vector2(30, -46), Vector2(24, 0), Vector2(-24, 0)])
	Art.toon(ci, body, Art.WOOD, 2.8, 0.6)
	for x in [-12.0, 0.0, 12.0]:
		Art.line(ci, Vector2(x * 1.15, -44), Vector2(x * 0.92, -2), Art.WOOD_DARK, 1.6)
	for y in [-36.0, -10.0]:
		var w := lerpf(30.0, 24.0, (y + 46.0) / 46.0)
		Art.t_rect(ci, Rect2(-w - 1.5, y - 3.5, w * 2.0 + 3.0, 7.0), 3.0, Art.METAL, 2.0, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-24, -44, 48, 5), 2.5), Color("3a2418", 0.55))
	if full:
		Art.t_circle(ci, Vector2(26, -44), 11.0, Art.RED, 2.2, 0.0)
		Art.text(ci, Vector2(26, -37), "!", 20, Art.WHITE, 0)


## Book of fish, centered, ~64 px.
static func book(ci: CanvasItem, t: float) -> void:
	Art.t_rect(ci, Rect2(-26, -30, 52, 60), 8, Color("2f6ee8"), 2.8, 0.4)
	Art.t_rect(ci, Rect2(-20, -24, 44, 50), 5, Art.CREAM, 0.0, 0.0)
	Art.t_rect(ci, Rect2(-26, -30, 52, 56), 8, Color("3a8af0"), 2.8, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-26, -30, 10, 56), 4), Color("2f6ee8"))
	Art.push(ci, Vector2(4, -2), sin(t * 2.0) * 0.06, Vector2(0.44, 0.44))
	draw(ci, "clownfish", t)
	Art.pop(ci)


## Fishing rod with a reel and a float, centered, ~64 px.
static func rod_icon(ci: CanvasItem, t: float) -> void:
	Art.stroke(ci, PackedVector2Array([Vector2(-22, 26), Vector2(24, -28)]), Art.WOOD, 5.0, 2.2)
	Art.t_circle(ci, Vector2(-12, 16), 7.0, Art.METAL, 2.2, 0.3)
	Art.line(ci, Vector2(24, -28), Vector2(26, 6), Art.INK, 1.6)
	bobber(ci, Vector2(26, 12 + sin(t * 3.0) * 2.0), 0.7)


## Red and white float, center at `at`.
static func bobber(ci: CanvasItem, at: Vector2, s: float = 1.0) -> void:
	Art.push(ci, at, 0.0, Vector2.ONE * s)
	Art.line(ci, Vector2(0, -16), Vector2(0, -9), Art.INK, 3.0)
	Art.t_circle(ci, Vector2.ZERO, 10.0, Art.WHITE, 2.6, 0.4)
	Art.toon(ci, Art.clipped(Art.circle_pts(Vector2.ZERO, 10.0, 20), Art.rrect_pts(Rect2(-12, -12, 24, 12), 0.1, 1)), Art.RED, 0.0, 0.0)
	Art.arc(ci, Vector2.ZERO, 10.0, 0.0, TAU, 20, Art.INK, 2.6)
	Art.flat(ci, Art.ellipse_pts(Vector2(-4, -5), Vector2(3, 2), 8, -0.5), Color(1, 1, 1, 0.8))
	Art.pop(ci)


## Dock / feature icon (SVG texture): an orange fish over a float.
static func icon(px: int = 54) -> Texture2D:
	var k := "fish_icon@%d" % px
	if _icons.has(k):
		return _icons[k]
	var ink := "#241a3a"
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>" \
			+ "<path d='M14 30 L3 19 L5 41 Z' fill='#ffb13b' stroke='%s' stroke-width='4' stroke-linejoin='round'/>" % ink \
			+ "<ellipse cx='32' cy='30' rx='22' ry='16' fill='#ff7a2a' stroke='%s' stroke-width='4.5'/>" % ink \
			+ "<path d='M24 15 C26 22 26 38 24 45' fill='none' stroke='#ffffff' stroke-width='5'/>" \
			+ "<circle cx='43' cy='27' r='6' fill='#ffffff' stroke='%s' stroke-width='3'/>" % ink \
			+ "<circle cx='44.5' cy='27.5' r='3.4' fill='%s'/>" % ink \
			+ "<path d='M44 37 Q48 40 52 36' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round'/>" % ink \
			+ "<circle cx='50' cy='54' r='7' fill='#ffffff' stroke='%s' stroke-width='3.5'/>" % ink \
			+ "<path d='M43 54 A7 7 0 0 1 57 54 Z' fill='#ef5350'/>" \
			+ "<path d='M50 44 L50 47' stroke='%s' stroke-width='3'/>" % ink \
			+ "</svg>"
	var img := Image.new()
	if img.load_svg_from_string(svg, px / 64.0) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_icons[k] = tex
	return tex


static var _icons := {}
