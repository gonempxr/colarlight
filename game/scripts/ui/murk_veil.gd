class_name MurkVeil
extends Control
## "The Murk changes the world" (saga games, the mine room): a violet gloom
## over the rooms that deepens with GameState.murk, eyes opening in the dark
## at the edges and tentacles creeping in from the left. A beaten guard
## sweeps it away with a flash of light (GameState.murk_cleansed).
## Cheap: a few cached shapes moved by Art.push, redrawn REDRAW_HZ times a
## second and only while there is Murk to show; it never takes input.

const REDRAW_HZ := 8.0
## Murk (stepped) at which eyes / tentacles start to show.
const EYES_AT := 0.2
const TENTACLES_AT := 0.4
const EYE_GLOW := Color(0.55, 1.0, 0.35)

var _m := 0.0
var _t := 0.0
var _wait := 0.0
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.murk_cleansed.connect(func(): _flash = 1.0)


## The darkening of the rooms under the veil (a modulate costs nothing to
## draw, unlike a full-screen layer).
static func tint(m: float) -> Color:
	return Color.WHITE.lerp(Color(0.62, 0.5, 0.82), clampf(m, 0.0, 1.0))


## The Murk as the veil shows it (steps of 0.05).
static func shown(m: float) -> float:
	return snappedf(clampf(m, 0.0, 1.0), 0.05)


func _process(delta: float) -> void:
	var on := Balance.saga and is_visible_in_tree()
	if not on:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta / 1.4)
	var m := shown(GameState.murk)
	_wait -= delta
	if m != _m or (_wait <= 0.0 and (m >= EYES_AT or _flash > 0.0)):
		_m = m
		_wait = 1.0 / REDRAW_HZ
		queue_redraw()


func _draw() -> void:
	draw_veil(self, size, _m, snappedf(_t, 1.0 / REDRAW_HZ), _flash)


static func draw_veil(ci: CanvasItem, s: Vector2, m: float, t: float, flash: float = 0.0) -> void:
	if m > 0.0:
		# Darker edges (a vignette).
		var w := 40.0 + 60.0 * m
		var dark := Color(0.08, 0.01, 0.16, 0.6 * m)
		var none := Color(dark, 0.0)
		Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]), PackedColorArray([dark, none, none, dark]))
		Art.grad(ci, PackedVector2Array([Vector2(s.x - w, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y)]), PackedColorArray([none, dark, dark, none]))
		Art.grad(ci, PackedVector2Array([Vector2(0, s.y - w), Vector2(s.x, s.y - w), s, Vector2(0, s.y)]), PackedColorArray([none, none, dark, dark]))
	if m >= TENTACLES_AT:
		var n := clampi(int((m - 0.3) * 6.0), 1, 4)
		for i in n:
			var y := s.y * (0.3 + 0.17 * i)
			var left := i % 2 == 0
			var sway := snappedf(sin(t * 1.3 + i * 1.9) * 0.18, 0.03)
			var k := 1.1 + 0.3 * m
			var base := Vector2(-6.0, y) if left else Vector2(s.x + 6.0, y)
			Art.push(ci, base, (sway + 0.15) if left else (PI - sway - 0.15), Vector2(k, k if left else -k))
			tentacle(ci)
			Art.pop(ci)
	if m >= EYES_AT:
		var n := clampi(int(m * 9.0), 1, 8)
		for i in n:
			var right := i % 2 == 1
			var y := s.y * (0.18 + 0.1 * i) + (18.0 if right else 0.0)
			var x := s.x - 30.0 if right else 30.0
			var blink := fmod(t + i * 1.7, 4.0 + i * 0.5) < 0.25
			eye(ci, Vector2(x, y), 15.0 + 4.0 * (i % 3), blink, right)
	if flash > 0.0:
		var f := snappedf(flash, 0.05)
		Art.flat(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), Color(1.0, 0.95, 0.75, 0.55 * f))
		Art.glow(ci, s / 2.0, maxf(s.x, s.y) * (1.2 - 0.6 * f), Color(1.0, 0.85, 0.4, 0.5 * f), 24)


## An eye in the dark: a glow, a yellow-green almond with a slit pupil (a
## closed line while it blinks).
static func eye(ci: CanvasItem, c: Vector2, r: float, closed: bool, right: bool) -> void:
	Art.glow(ci, c, r * 2.6, Color(EYE_GLOW, 0.22))
	if closed:
		Art.line(ci, c - Vector2(r, 0), c + Vector2(r, 0), Color(EYE_GLOW, 0.8), 2.5)
		return
	var pts := PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.4, -r * 0.55), c + Vector2(r * 0.4, -r * 0.55),
			c + Vector2(r, 0), c + Vector2(r * 0.4, r * 0.55), c + Vector2(-r * 0.4, r * 0.55)])
	Art.toon(ci, Art.smooth_pts(pts, 3), Color("d8ff6a"), 2.0, 0.3, Color("1a0626"))
	var look := Vector2(-r * 0.25 if right else r * 0.25, 0)
	Art.flat(ci, Art.ellipse_pts(c + look, Vector2(r * 0.18, r * 0.5), 10), Color("1a0626"))
	Art.flat(ci, Art.circle_pts(c + look + Vector2(-r * 0.3, -r * 0.25), r * 0.14, 6), Color(1, 1, 1, 0.8))


## A tentacle reaching right from (0, 0): a tapered curl with suckers.
static func tentacle(ci: CanvasItem) -> void:
	var spine := [Vector2(0, 0), Vector2(45, -12), Vector2(90, -2), Vector2(125, 16), Vector2(150, 14), Vector2(168, 2)]
	var widths := [20.0, 16.0, 12.0, 8.0, 5.0, 1.5]
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in spine.size():
		var a: Vector2 = spine[maxi(0, i - 1)]
		var b: Vector2 = spine[mini(spine.size() - 1, i + 1)]
		var nrm := (b - a).normalized().orthogonal()
		top.append(spine[i] + nrm * widths[i])
		bot.append(spine[i] - nrm * widths[i])
	bot.reverse()
	top.append_array(bot)
	Art.toon(ci, Art.smooth_pts(top, 3), Color("4a1a6e"), 3.0, 0.6)
	for i in 4:
		var p: Vector2 = spine[i].lerp(spine[i + 1], 0.5)
		var a: Vector2 = spine[i]
		var nrm: Vector2 = (spine[i + 1] - a).normalized().orthogonal()
		Art.t_circle(ci, p - nrm * (widths[i] * 0.45), maxf(2.0, widths[i] * 0.28), Color("d6a2f0"), 1.5, 0.0)
