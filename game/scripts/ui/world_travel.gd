class_name WorldTravel
extends Control
## The trip to another opened world: two banks of fluffy clouds roll in
## from the sides and meet in the middle, the world changes behind them,
## then they part and drift away, showing the new world. The clouds take
## the colors of the world being left on the way in and of the new world
## on the way out (ash over the volcano, mist over the acid swamp).
## With reduce motion it is a short soft fade instead.
##
## WorldTravel.start(parent, to_world, swap): `swap` runs once the screen
## is fully covered; the node frees itself at the end.

const CLOSE := 0.62
const HOLD := 0.24
const OPEN := 0.85

var _from := "ocean"
var _to := "ocean"
var _swap: Callable
var _t := 0.0
var _swapped := false
var _fast := false
## Long frames right after the swap (the world rebuilds) are not counted,
## so the clouds never jump when they start to part.
var _skip := 0


static func start(parent: Node, from_world: String, to_world: String, swap: Callable) -> WorldTravel:
	var w := WorldTravel.new()
	w._from = from_world
	w._to = to_world
	w._swap = swap
	w._fast = Settings.reduce_motion
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(w)
	return w


func _process(delta: float) -> void:
	if _skip > 0:
		_skip -= 1
		delta = 0.0
	_t += minf(delta, 1.0 / 30.0)
	var close := 0.18 if _fast else CLOSE
	if not _swapped and _t >= close:
		_swapped = true
		_t = close
		_skip = 2
		if _swap.is_valid():
			_swap.call()
	if _t >= close + _hold() + _open():
		queue_free()
	queue_redraw()


func _hold() -> float:
	return 0.06 if _fast else HOLD


func _open() -> float:
	return 0.3 if _fast else OPEN


## 0 = open, 1 = fully covered.
func cover() -> float:
	var close := 0.18 if _fast else CLOSE
	if _t < close:
		var k := _t / close
		# Ease in-out: starts gently, meets softly.
		return k * k * (3.0 - 2.0 * k)
	var k2 := clampf((_t - close - _hold()) / _open(), 0.0, 1.0)
	# Ease out: they part quickly and drift the last bit.
	return 1.0 - (1.0 - pow(1.0 - k2, 3.0))


func _colors() -> Array:
	var w := _to if _swapped else _from
	var c := WorldArt.cloud_colors(w, 1.0)
	if c.is_empty():
		return [Color("fbfdff"), Color("8cc6ea"), Color("d4e8f8")]
	return [c[0].lightened(0.25), c[1], c[0].lightened(0.05)]


func _draw() -> void:
	var v := size
	var c := cover()
	if _fast:
		draw_rect(Rect2(Vector2.ZERO, v), Color(_colors()[0], c))
		return
	if c <= 0.001:
		return
	var cols := _colors()
	# A soft veil under the clouds so the world dims as they gather.
	draw_rect(Rect2(Vector2.ZERO, v), Color(cols[0].darkened(0.1), 0.35 * c))
	var bob := sin(_t * 2.6) * 6.0
	var r := clampf(minf(v.x, v.y) * 0.28, 90.0, 230.0)
	for side: float in [-1.0, 1.0]:
		# The bank's leading edge: off screen when open, past the middle when
		# shut. A shadowy back row runs a little ahead of the bright front row.
		# Both front rows meet a little past the middle (their dips overlap).
		var edge := lerpf(-r * 3.2, v.x * 0.5 + r * 0.22, c)
		for layer in 2:
			var ahead := (r * 0.55 if layer == 0 else 0.0) * sin(c * PI)
			var x := edge + ahead if side < 0.0 else v.x - edge - ahead
			var dy := (bob if layer == 0 else -bob * 0.6) * side
			Art.push(self, Vector2(x, dy))
			Art.toon(self, _bank(v.y, r * (0.8 if layer == 0 else 1.0), side > 0.0, layer), cols[2] if layer == 0 else cols[0], 3.4, 0.55, cols[1])
			if layer == 1:
				# Big single clouds riding just ahead of the bank's edge.
				for i in 4:
					var py := v.y * (0.12 + 0.25 * i) + (r * 0.3 if side > 0.0 else 0.0)
					var px := -side * (r * (1.3 + 0.9 * float(i % 2)))
					Art.push(self, Vector2(px, py - dy * 0.5), 0.0, Vector2.ONE * (r / 52.0))
					var a := smoothstep(0.0, 0.4, c)
					Props.cloud(self, 41 + i + (10 if side > 0.0 else 0), Color(cols[0].lightened(0.4), a), Color(cols[1], 0.45 * a))
					Art.pop(self)
			Art.pop(self)
	# A few loose puffs that run ahead of the banks and fade as they meet.
	var lead := sin(c * PI)
	if lead > 0.02:
		for i in 4:
			var side := -1.0 if i % 2 == 0 else 1.0
			var y := v.y * (0.2 + 0.2 * i)
			var px := v.x * 0.5 + side * (v.x * 0.5 + 40.0) * (1.0 - c) - side * 40.0
			Art.push(self, Vector2(px, y + bob), 0.0, Vector2.ONE * (1.1 + 0.15 * i))
			Props.cloud(self, 31 + i, Color(cols[0], lead), Color(cols[1], lead))
			Art.pop(self)


## One bank of clouds with its edge at x = 0 and its body off to the left
## (or to the right for the right bank), covering the whole height with
## round puffs bulging out of the edge.
var _banks := {}
func _bank(h: float, size: float, right: bool, layer: int) -> PackedVector2Array:
	var key := Vector4i(int(h), int(size), 1 if right else 0, layer)
	if _banks.has(key):
		return _banks[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = (7 if right else 3) + layer * 11
	var d := 1.0 if right else -1.0
	var x0 := 10.0 * d
	var x1 := 4000.0 * d
	var parts := [PackedVector2Array([Vector2(minf(x0, x1), -80), Vector2(maxf(x0, x1), -80), Vector2(maxf(x0, x1), h + 80), Vector2(minf(x0, x1), h + 80)])]
	var y := -size * 0.5 + layer * size * 0.45
	while y < h + size:
		var r := size * rng.randf_range(0.75, 1.2)
		parts.append(Art.circle_pts(Vector2(d * (r * 0.55 + rng.randf_range(-14, 14)), y), r, 28))
		y += r * rng.randf_range(1.05, 1.35)
	var pts := Art.union(parts)
	_banks[key] = pts
	return pts
