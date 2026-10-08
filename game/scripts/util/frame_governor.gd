class_name FrameGovernor
extends Node
## Keeps the game smooth on slow devices: with graphics on "auto" it
## watches how long each frame really takes (the script work and the
## drawing, from the start of a frame to the moment it is handed to the
## screen) and, while the device can't keep up with 60 frames a second,
## steps down one level at a time:
##   0  everything (moving sprites change shape 30 times a second)
##   1  sprites and card pictures change shape 20 times a second
##   2  low quality: no soft outline edges, fewer screen pixels on the web
##   3  the scenery and the sprites animate 15-20 times a second
## Movement (divers, boats, the lift, scrolling) stays at the full frame
## rate on every level. It never steps back up during a session, so it
## can't flicker between two levels; a new session starts from 0 again.
## Mostly the time the game itself spends counts. Frames that come slowly
## while the game has little to do mean the graphics chip can't keep up:
## after a longer wait that steps down to low quality too (fewer pixels and
## triangles), but no further.

signal level_changed(level: int)

const LEVELS := 4
## A frame of 60 fps is 16.7 ms; the game should leave the browser some.
const BUSY_MS := 12.0
const WINDOW_SEC := 1.0
## Slow windows in a row before stepping down.
const SLOW_WINDOWS := 3
## Frames slower than this (ms) while the game itself is quick: the
## graphics chip is the limit; GPU_WINDOWS such windows in a row step down.
const GPU_FRAME_MS := 25.0
const GPU_WINDOWS := 6
## Seconds to wait after the start and after each step (caches refill).
const SETTLE_SEC := 4.0

static var level := 0
## Game work per frame (ms) in the last window, for PerfProbe.
static var busy_now := 0.0

var _start_us := 0
var _busy_us := 0
var _frames := 0
var _acc := 0.0
var _slow := 0
var _gpu_slow := 0
var _settle := SETTLE_SEC
var _last_busy_ms := 0.0


func _ready() -> void:
	process_priority = -100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	level = 0
	apply()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)


func _process(delta: float) -> void:
	_start_us = Time.get_ticks_usec()
	_acc += delta
	if _acc < WINDOW_SEC:
		return
	if _frames == 0:
		# Nothing was drawn (headless, or the page was hidden): no data.
		_acc = 0.0
		_busy_us = 0
		return
	var busy_ms := _busy_us / 1000.0 / _frames
	var frame_ms := _acc * 1000.0 / _frames
	_last_busy_ms = busy_ms
	busy_now = busy_ms
	_acc = 0.0
	_busy_us = 0
	_frames = 0
	if _settle > 0.0:
		_settle -= WINDOW_SEC
		return
	if Settings.quality != "auto" or level >= LEVELS - 1:
		_slow = 0
		return
	_slow = _slow + 1 if busy_ms > BUSY_MS else 0
	_gpu_slow = _gpu_slow + 1 if busy_ms <= BUSY_MS and frame_ms > GPU_FRAME_MS and level < 2 else 0
	if _slow >= SLOW_WINDOWS or _gpu_slow >= GPU_WINDOWS:
		_slow = 0
		_gpu_slow = 0
		_settle = SETTLE_SEC
		level += 1
		apply()
		level_changed.emit(level)


func _on_post_draw() -> void:
	if _start_us > 0:
		_busy_us += Time.get_ticks_usec() - _start_us
		_frames += 1


## Average milliseconds of game work per frame in the last window.
func busy_ms() -> float:
	return _last_busy_ms


## Sets the rates of the current level (Art, ArtView and World read them).
static func apply() -> void:
	Art.shape_hz = 30.0 if level == 0 else (20.0 if level <= 2 else 15.0)
	World.anim_hz = 30.0 if level <= 2 else 20.0
	Settings.auto_low = level >= 2
