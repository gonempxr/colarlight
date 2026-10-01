extends Node
## The Rivals League: a weekly board of the player and a few clearly made-up
## sea characters (Captain Crab, Old Walrus, ...). They are game characters,
## shown as such, never as real players. Registered as the Rivals autoload.
##
## The player earns league stars (★) by playing: upgrade levels, managers,
## new depths and buildings, quests, puzzles, fish, chests, the daily gift
## and Dive Deeper. Taps give nothing (no autoclicker races).
##
## A rival's score follows a fixed schedule for the week (its own day by
## day pace, the same every time the board is opened) mixed with half of
## the player's own stars, so the board stays close: rivals are just ahead
## or just behind, and every evening of play moves the player up. The
## strongest rival needs a really good week. Nothing is random at run time.
##
## When a new week starts (Monday), last week's place gives a few pearls,
## collected on the board.

signal changed

const WEEK_SEC := 7 * 24 * 3600
## 1970-01-05 was a Monday: weeks start on Monday 00:00 local time.
const MONDAY_OFFSET := 4 * 24 * 3600
## Expected stars in a first week, before the player's own pace is known.
const START_PACE := 900.0
const MIN_PACE := 250.0
## Stars per action.
const POINTS := {
	"upgrade": 1, "hire": 10, "open": 25, "quest": 15, "puzzle": 20,
	"fish": 3, "chest": 5, "daily": 10, "prestige": 100,
}
## Pearls for places 1..8 (only with at least one star that week).
const REWARDS: Array[int] = [25, 15, 10, 6, 4, 3, 2, 1]
## id, pet art, strength (how far ahead of the player's usual week).
const RIVALS := [
	{"id": "octo", "art": "octopus", "strength": 1.55},
	{"id": "crab", "art": "crab", "strength": 1.3},
	{"id": "walrus", "art": "seal", "strength": 1.1},
	{"id": "shark", "art": "shark_pup", "strength": 0.9},
	{"id": "seahorse", "art": "seahorse", "strength": 0.72},
	{"id": "puffer", "art": "puffer", "strength": 0.52},
	{"id": "turtle", "art": "turtle", "strength": 0.34},
]
const POLL_SEC := 2.0

var save_path := "user://rivals.json"
var autosave_enabled := true
## Week number (weeks since the Monday above) these stars belong to.
var week := -1
var points := 0
## The player's usual stars per week (smoothed over past weeks).
var pace := START_PACE
## Last finished week: {"week", "place", "pearls", "claimed"}.
var last: Dictionary = {}
## Counters seen at the last poll (stars come from their growth).
var _seen: Dictionary = {}
var _poll_left := 0.0
var _save_left := 10.0
## Tests move the clock with this many seconds.
var time_offset := 0.0


func _ready() -> void:
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("rivals.json")
		profiles.switched.connect(_on_profile_switched)
	reset()
	load_game()
	GameState.upgraded.connect(func(_k, count): add_points("upgrade", count))
	GameState.manager_hired.connect(func(_k): add_points("hire"))
	GameState.depth_opened.connect(func(_k): add_points("open"))
	Progress.quest_done.connect(func(_i): add_points("quest"))


func reset() -> void:
	week = current_week()
	points = 0
	pace = START_PACE
	last = {}
	_seen = _counters()


func _on_profile_switched() -> void:
	# The old player's stars go to the old file first.
	if autosave_enabled:
		save_game()
	save_path = Profiles.file("rivals.json")
	reset()
	load_game()
	changed.emit()


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL_SEC
		poll()
	# Tests switch the game's saving off; the league follows it.
	if autosave_enabled and GameState.autosave_enabled:
		_save_left -= delta
		if _save_left <= 0.0:
			_save_left = 10.0
			save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled and is_inside_tree():
				save_game()


# --- Time ------------------------------------------------------------------------

func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


## Local time zone, so the week turns at the player's Monday midnight.
func _local(t: float) -> float:
	return t + float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0


func current_week() -> int:
	return floori((_local(now()) - MONDAY_OFFSET) / WEEK_SEC)


## 0..1: how much of this week has passed.
func week_frac() -> float:
	var t := _local(now()) - MONDAY_OFFSET
	return clampf((t - float(current_week()) * WEEK_SEC) / WEEK_SEC, 0.0, 1.0)


# --- Stars ---------------------------------------------------------------------------

func add_points(kind: String, count: int = 1) -> void:
	_roll_week()
	var n := int(POINTS.get(kind, 0)) * maxi(0, count)
	if n <= 0:
		return
	points += n
	changed.emit()


## Counters other parts of the game keep; their growth gives stars.
func _counters() -> Dictionary:
	var c := {
		"puzzle": int(Progress.stats.get("puzzles_won", 0)),
		"chest": int(Progress.stats.get("chests", 0)),
		"daily": int(Progress.stats.get("daily_claimed", 0)),
		"prestige": int(GameState.prestige_count),
		"fish": 0,
	}
	var fishing := get_node_or_null("/root/Fishing")
	if fishing:
		var st = fishing.get("stats")
		if st is Dictionary:
			c["fish"] = int(st.get("caught", 0))
	return c


func poll() -> void:
	_roll_week()
	var now_c := _counters()
	for k in now_c:
		var grown := int(now_c[k]) - int(_seen.get(k, now_c[k]))
		if grown > 0:
			add_points(k, grown)
	_seen = now_c


## A new week: last week's place gives pearls (if the player played).
func _roll_week() -> void:
	var w := current_week()
	if w == week:
		return
	if w > week and week >= 0:
		var place := place_of(points, week, 1.0)
		var pearls := REWARDS[place - 1] if points > 0 and place <= REWARDS.size() else 0
		last = {"week": week, "place": place, "pearls": pearls, "claimed": pearls == 0}
		pace = maxf(MIN_PACE, pace * 0.5 + float(points) * 0.5) if points > 0 else pace
	week = w
	points = 0
	changed.emit()


func reward_pending() -> bool:
	return not last.is_empty() and not bool(last.get("claimed", true))


## Collects last week's pearls; returns how many (0 when nothing waits).
func claim() -> int:
	if not reward_pending():
		return 0
	last["claimed"] = true
	var n := int(last.get("pearls", 0))
	Progress.add_pearls(n)
	changed.emit()
	if autosave_enabled:
		save_game()
	return n


# --- The board -----------------------------------------------------------------------

## A small whole-number hash, the same on every run and platform.
static func _mix(a: int, b: int, c: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(posmod(h, 1000)) / 1000.0


## 0..1: share of its week a rival has done by `frac`, day by day (some
## days busier than others), smooth inside a day.
static func schedule(rival: int, w: int, frac: float) -> float:
	var days: Array[float] = []
	var total := 0.0
	for d in 7:
		var v := 0.55 + 0.9 * _mix(rival + 1, w, d)
		days.append(v)
		total += v
	var x := clampf(frac, 0.0, 1.0) * 7.0
	var done := 0.0
	for d in 7:
		if x >= d + 1:
			done += days[d]
		else:
			done += days[d] * (x - d)
			break
	return done / total


## A rival's stars in week `w` at `frac` of it, against `player` stars.
func rival_score(i: int, w: int, frac: float, player: int) -> int:
	var s: float = RIVALS[i]["strength"]
	# A tiny lead-in so the board is not all zeros on Monday morning.
	var own := pace * (schedule(i, w, frac) * 0.5) + 6.0 * s
	return int(round(s * (own + float(player) * 0.5)))


## 1-based place of `player` stars on the board of week `w` at `frac`.
## Ties go to the player.
func place_of(player: int, w: int, frac: float) -> int:
	var place := 1
	for i in RIVALS.size():
		if rival_score(i, w, frac, player) > player:
			place += 1
	return place


## The board now, best first: [{"id", "art", "score", "you"}].
func board() -> Array:
	_roll_week()
	var frac := week_frac()
	var rows: Array = [{"id": "you", "art": "", "score": points, "you": true}]
	for i in RIVALS.size():
		rows.append({"id": RIVALS[i]["id"], "art": RIVALS[i]["art"], "score": rival_score(i, week, frac, points), "you": false})
	rows.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["you"])
	return rows


func place() -> int:
	_roll_week()
	return place_of(points, week, week_frac())


# --- Save ----------------------------------------------------------------------------

func save_game() -> bool:
	var data := {"week": week, "points": points, "pace": pace, "last": last, "seen": _seen}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(tmp, save_path) == OK


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		return false
	var d: Dictionary = json.data
	week = int(_f(d.get("week"), current_week()))
	points = maxi(0, int(_f(d.get("points"), 0.0)))
	pace = maxf(MIN_PACE, _f(d.get("pace"), START_PACE))
	last = d.get("last", {}) if d.get("last", {}) is Dictionary else {}
	var seen = d.get("seen", {})
	if seen is Dictionary:
		# Growth while the file was away (other saves loaded since) counts
		# from what this file last saw.
		for k in _seen:
			_seen[k] = int(_f(seen.get(k), _seen[k]))
	_roll_week()
	return true


static func _f(v, fallback: float) -> float:
	if (v is float or v is int) and is_finite(float(v)):
		return float(v)
	return fallback
