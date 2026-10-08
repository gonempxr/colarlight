class_name Motion
extends RefCounted
## Shared motion helpers: easing curves, frame-rate independent smoothing,
## and the shown progress of a stage's cycle.
##
## GameState's cycle progress can leap: a tap pushes a running trip forward
## by a tenth, an upgrade shortens the cycle time, a rush doubles the speed.
## Drawing straight from it makes the lift cabin, the boats and the divers
## teleport. `progress(key)` is what the views draw instead: it follows the
## real progress closely while it runs smoothly and turns a leap into a
## short burst of speed, finishes a cycle before showing the next one, and
## only then shows the stage idle (-1).

## How fast the shown progress closes a gap (1/s). The steady lag while a
## cycle runs is its speed / FOLLOW (a few hundredths of a second).
const FOLLOW := 10.0
## A gap bigger than this (time away, a loaded save, tests jumping ahead)
## is shown at once.
const SNAP := 0.6
## How fast a finished cycle plays out its last bit before going idle.
const FINISH_RATE := 1.5
## A cycle that stops further than this from its end was cut short.
const FINISH_GAP := 0.35

## key -> [shown progress, frame it was worked out]
static var _shown := {}
## Set by tests: show the real progress with no smoothing.
static var off := false


## The progress the views draw for `key` (0..1 running, -1 idle).
static func progress(key: String) -> float:
	var real: float = GameState.cycle_progress(key)
	if off:
		return real
	var frame := Engine.get_process_frames()
	var e: Array = _shown.get(key, [])
	if e.is_empty():
		_shown[key] = [real, frame]
		return real
	if int(e[1]) == frame:
		return _wrap(float(e[0]))
	var frames := frame - int(e[1])
	var tree := Engine.get_main_loop() as SceneTree
	var dt := clampf(tree.root.get_process_delta_time() if tree else 1.0 / 60.0, 0.0, 0.1) * minf(frames, 6)
	e[1] = frame
	var shown: float = e[0]
	if real < 0.0:
		# Far from the end it was stopped, not finished (a reset, a new
		# save): rest at once.
		if shown < 0.0 or frames > 6 or shown < 1.0 - FINISH_GAP:
			e[0] = -1.0
			return -1.0
		# The cycle ended: play out its end, then rest.
		shown = minf(1.0, shown + maxf(FINISH_RATE, (1.0 - shown) * FOLLOW) * dt)
		if shown >= 0.999:
			e[0] = -1.0
			return -1.0
		e[0] = shown
		return shown
	if frames > 6:
		e[0] = real
		return real
	if shown < 0.0:
		# A new cycle from rest starts at 0 (the rest pose) and speeds up
		# into the real one; starting at the real progress (already a frame
		# or more in) lurched and then stalled for the follow to catch up.
		shown = 0.0
	# A new cycle began while the last one is still shown: aim past 1.
	var target := real
	if target < shown - 0.5:
		target += 1.0
	var gap := target - shown
	if absf(gap) > SNAP:
		shown = real
	elif gap > 0.0:
		# (Never backwards: when the real progress falls behind, as after a
		# slower cycle time, the shown one just waits for it.)
		shown += gap * (1.0 - exp(-FOLLOW * dt))
	if shown >= 1.0:
		shown -= 1.0
	e[0] = shown
	return shown


static func _wrap(v: float) -> float:
	return v if v < 1.0 else v - 1.0


## Forget the shown progress (a new save, a new world).
static func reset() -> void:
	_shown.clear()


## When a tap reaction (`dur` seconds long) starts: a new tap restarts it
## only once the last one has mostly played out (restarting a spin or a
## wobble halfway through snaps it back: the twitch of an autoclicker).
static func repoke(last: float, now: float, dur: float) -> float:
	return now if now - last >= dur * 0.75 else last


# --- Smoothing ----------------------------------------------------------------------

## Moves `from` toward `to`, closing the same share of the gap per second at
## any frame rate (rate = 1/s; 10 closes ~63% in 0.1 s).
static func damp(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


static func damp_v(from: Vector2, to: Vector2, rate: float, delta: float) -> Vector2:
	return from.lerp(to, 1.0 - exp(-rate * delta))


## Velocity kept after `delta` seconds when `per_frame60` is kept per 1/60 s
## frame (turns the old `v *= 0.985` into a frame-rate independent drag).
static func drag(per_frame60: float, delta: float) -> float:
	return pow(per_frame60, delta * 60.0)


# --- Easing -------------------------------------------------------------------------

static func ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func ease_out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func ease_in_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


## Ends past 1 and settles back (`s` = how far; 1.70158 is the classic).
static func ease_out_back(x: float, s: float = 1.70158) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + x * x * ((s + 1.0) * x + s)


## A springy settle: 0 -> 1 with a couple of fading wobbles.
static func ease_out_elastic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x <= 0.0 or x >= 1.0:
		return x
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0) + 1.0


## Squash and stretch of a press: (sx, sy) for `k` = 0..1 of the bounce
## after a tap (1 = at rest). Volume stays about the same.
static func squash(k: float, amount: float = 0.14) -> Vector2:
	if k >= 1.0 or k < 0.0:
		return Vector2.ONE
	var w := sin(k * PI * 2.5) * (1.0 - k) * (1.0 - k) * amount
	return Vector2(1.0 + w, 1.0 - w)
