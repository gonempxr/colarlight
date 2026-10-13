extends Node
## Trusted time (Clock autoload). Everything that pays for time passing —
## offline earnings, the daily gift and streak, the coins-for-pearls
## cooldown, boosts, fishing, the challenge of the day, weeks and seasons —
## asks Clock.now() instead of the device clock, so moving the computer's
## clock forward or back gives nothing.
##
## On the web the page asks its own server for the time (the HTTP Date
## header, see web shell `coralightClock`) before the game even starts.
## From then on time runs on the monotonic tick counter: changing the
## device clock while playing has no effect. Without an answer (offline,
## desktop builds, tests) the device clock is used, but it can never go
## back past the last time seen (kept in user://clock.json).

const SAVE_PATH := "user://clock.json"
const POLL_SEC := 0.5
## Keep asking the page this long for the server's answer.
const WAIT_SEC := 30.0
const SAVE_SEC := 60.0

## True once the server's time is known.
var synced := false
## Server time minus device time at the sync (seconds), for the record.
var offset := 0.0

var _base := 0.0
var _base_us := 0
var _poll := 0.0
var _waited := 0.0
var _save_left := SAVE_SEC
var _last_seen := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	var device := Time.get_unix_time_from_system()
	# The device clock never takes time back past what was already seen.
	_rebase(maxf(device, _last_seen))
	_try_js()


func _process(delta: float) -> void:
	if not synced and OS.has_feature("web") and _waited < WAIT_SEC:
		_waited += delta
		_poll -= delta
		if _poll <= 0.0:
			_poll = POLL_SEC
			_try_js()
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = SAVE_SEC
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


## Trusted Unix time in seconds.
func now() -> float:
	return _base + float(Time.get_ticks_usec() - _base_us) / 1e6


## Today's date ("YYYY-MM-DD") in the player's time zone, by trusted time.
func today() -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(now()) + bias)


## Tests: pretend the server said `unix`.
func set_server_time(unix: float) -> void:
	_sync(unix)


func _rebase(unix: float) -> void:
	_base = unix
	_base_us = Time.get_ticks_usec()


func _sync(server: float) -> void:
	offset = server - Time.get_unix_time_from_system()
	synced = true
	if OS.has_feature("web"):
		print("Clock: server time, device off by %d s" % int(-offset))
	_rebase(server)
	_save()


func _try_js() -> void:
	if synced or not OS.has_feature("web"):
		return
	var v = JavaScriptBridge.eval("(function(){try{var c=window.coralightClock;return (c&&c.server)?String(c.server+(performance.now()-c.at)/1000):''}catch(e){return ''}})()", true)
	var s := str(v)
	if s != "" and s.is_valid_float():
		var server := s.to_float()
		# Sanity: after 2024 and not absurdly far from the device.
		if server > 1.7e9 and absf(server - Time.get_unix_time_from_system()) < 3.0e8:
			_sync(server)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary and (d.get("seen") is float or d.get("seen") is int):
		var seen := float(d["seen"])
		# A saved time far in the future (a clock pushed forward before this
		# version) is not trusted as a floor.
		if seen < Time.get_unix_time_from_system() + 7 * 86400.0:
			_last_seen = seen


func _save() -> void:
	_last_seen = maxf(_last_seen, now())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seen": _last_seen, "synced": synced}))
