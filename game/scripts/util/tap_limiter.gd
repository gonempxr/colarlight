class_name TapLimiter
extends RefCounted
## Caps how many taps per target count within a sliding time window, so an
## autoclicker gets nothing a fast human finger would not. Taps over the cap
## are simply ignored (never punished). The caller passes its own clock, so
## game time, frame time or a test clock all work.

var cap := 10
var window := 1.0
## key -> times (seconds) of the taps that counted, oldest first.
var _times: Dictionary = {}


func _init(cap_: int = 10, window_: float = 1.0) -> void:
	cap = cap_
	window = window_


## True when a tap on `key` at time `now` counts (and records it).
func allow(key: String, now: float) -> bool:
	var times: Array = _times.get(key, [])
	while not times.is_empty() and (now - float(times[0]) >= window or float(times[0]) > now):
		times.pop_front()
	if times.size() >= cap:
		_times[key] = times
		return false
	times.append(now)
	_times[key] = times
	return true


func clear() -> void:
	_times.clear()
