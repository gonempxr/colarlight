extends Node
## The whole economy: dive sites -> lift -> boat -> plant -> coins.
## Registered as the GameState autoload. UI only reads from here and calls actions.
##
## Stage keys: "d0".."dN" (dive sites, shallow to deep), "lift", "boat", "plant",
## and the second boat and plant, "boat2" and "plant2", bought later in a run
## (closed at level 0). Both boats carry from the same raft to the same
## shore; both plants work the same shore pile.
## Divers always work on their own; a tap pushes their dive forward and a
## site's manager (foreman) doubles its output. The lift, the boat and the
## plant run one cycle per tap until their manager automates them; that
## automation is kept through a Dive (prestige).
## Divers put ore into the crates at their depth (`pit`, one pool), the
## lift brings it up to the raft (`hold`), the boat moves it to `dock`
## (on shore), the plant turns dock ore into coins.

signal changed
signal cycle_started(key: String, amount: float)
signal cycle_finished(key: String, amount: float)
signal milestone_reached(key: String, level: int)
signal rush_started
signal coins_earned(amount: float)
## Player actions, for character reactions and sounds.
signal upgraded(key: String, count: int)
signal manager_hired(key: String)
signal depth_opened(key: String)
signal tapped(key: String)

const SAVE_VERSION := 2
const RUSH_PER_TAP := 0.08
const RUSH_DECAY := 0.15
const RUSH_SEC := 5.0
const RUSH_SPEED := 2.0
## Offline progress is simulated in steps of this many seconds.
const OFFLINE_STEP := 1.0

var save_path := "user://coralight2.json"
var autosave_enabled := true

var coins := 0.0
var total_earned := 0.0
var prestige_count := 0
var levels: Dictionary = {}
var managers: Dictionary = {}
## Ore the divers left in the crates at the depths, waiting for the lift.
var pit := 0.0
var hold := 0.0
var dock := 0.0
var rush_meter := 0.0
var rush_left := 0.0
## Income x2 boost (from pearls, rewards) and its seconds left.
var boost_left := 0.0
## Extra multipliers per stage key from artifacts and the like ("all" = every
## stage). Filled by Progress; not saved here.
var bonus: Dictionary = {}

## Per-stage cycle state: seconds elapsed in the current cycle (-1 = idle)
## and the amount the cycle carries.
var _timer: Dictionary = {}
var _load: Dictionary = {}
## Game seconds run so far (advance()), the clock for the tap cap.
var tap_clock := 0.0
var _taps := TapLimiter.new(Balance.TAP_CAP, Balance.TAP_WINDOW)
var _autosave_left := Balance.AUTOSAVE_SEC
var _offline_report: Dictionary = {}
## Deepest site the running lift trip goes to (-1 while the lift waits).
var lift_trip_depth := -1
## Level of a stage right before its last upgrade (for look changes).
var upgraded_from: Dictionary = {}


func _ready() -> void:
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("game.json")
	reset()
	load_game()


## Profiles switched: load the new player's game.
func switch_profile() -> void:
	save_path = Profiles.file("game.json")
	reset()
	load_game()
	changed.emit()


func _process(delta: float) -> void:
	advance(delta)
	if not autosave_enabled:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = Balance.AUTOSAVE_SEC
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled and is_inside_tree():
				save_game()


func reset() -> void:
	coins = 0.0
	total_earned = 0.0
	prestige_count = 0
	boost_left = 0.0
	managers = {}
	_reset_run()


func _reset_run(keep_automation: bool = false) -> void:
	var kept := {}
	if keep_automation:
		for k in AUTOMATED:
			kept[k] = managers.get(k, false)
	levels = {}
	managers = {}
	for key in stage_keys():
		levels[key] = 0
		managers[key] = kept.get(key, false)
		_timer[key] = -1.0
		_load[key] = 0.0
	levels["d0"] = 1
	levels["lift"] = 1
	levels["boat"] = 1
	levels["plant"] = 1
	pit = 0.0
	hold = 0.0
	dock = 0.0
	lift_trip_depth = -1
	rush_meter = 0.0
	rush_left = 0.0
	_offline_report = {}


# --- Queries ------------------------------------------------------------------

static func stage_keys() -> Array[String]:
	var keys: Array[String] = []
	for i in Balance.DEPTHS.size():
		keys.append("d%d" % i)
	keys.append("lift")
	keys.append_array(BUILDINGS)
	return keys


const BUILDINGS: Array[String] = ["boat", "plant", "boat2", "plant2"]
## Stages that stand still until their manager is hired (kept through a Dive).
const AUTOMATED: Array[String] = ["lift", "boat", "plant", "boat2", "plant2"]


static func is_boat(key: String) -> bool:
	return key == "boat" or key == "boat2"


static func is_plant(key: String) -> bool:
	return key == "plant" or key == "plant2"


## The second boat or plant: bought with coins, not open from the start.
static func is_second(key: String) -> bool:
	return key == "boat2" or key == "plant2"


static func is_lift(key: String) -> bool:
	return key == "lift"


static func depth_index(key: String) -> int:
	return int(key.substr(1)) if key.begins_with("d") else -1


static func stage_data(key: String) -> Dictionary:
	match key:
		"lift":
			return Balance.LIFT
		"boat":
			return Balance.BOAT
		"plant":
			return Balance.PLANT
		"boat2":
			return Balance.BOAT2
		"plant2":
			return Balance.PLANT2
	return Balance.DEPTHS[depth_index(key)]


func get_level(key: String) -> int:
	return levels.get(key, 0)


func has_manager(key: String) -> bool:
	return managers.get(key, false)


func is_open(key: String) -> bool:
	return get_level(key) > 0


func income_mult() -> float:
	return Balance.prestige_mult(prestige_count) * (2.0 if boost_left > 0.0 else 1.0) * float(bonus.get("all", 1.0))


## Does this stage start its next cycle by itself?
func is_auto(key: String) -> bool:
	return depth_index(key) >= 0 or has_manager(key)


## Coins per second this stage can handle.
func rate(key: String) -> float:
	# Artifact bonuses for the boat or the plant count for both of them.
	var group := "boat" if is_boat(key) else ("plant" if is_plant(key) else key)
	var r := Balance.output(stage_data(key)["value"], get_level(key)) * income_mult() * float(bonus.get(group, 1.0))
	if depth_index(key) >= 0:
		r *= float(bonus.get("dives", 1.0))
		if has_manager(key):
			r *= Balance.FOREMAN_MULT
	return r


func dives_rate() -> float:
	var total := 0.0
	for i in Balance.DEPTHS.size():
		total += rate("d%d" % i)
	return total


## Both boats together (a closed one adds nothing).
func boats_rate() -> float:
	return rate("boat") + rate("boat2")


func plants_rate() -> float:
	return rate("plant") + rate("plant2")


func lift_rate() -> float:
	return rate("lift")


## Coins per second with every stage automated: the weakest link.
func income_rate() -> float:
	return minf(minf(dives_rate(), lift_rate()), minf(boats_rate(), plants_rate()))


## Which group limits income: "dives", "lift", "boat" (both boats) or "plant".
func bottleneck() -> String:
	var d := dives_rate()
	var l := lift_rate()
	var b := boats_rate()
	var p := plants_rate()
	if d <= l and d <= b and d <= p:
		return "dives"
	if l <= b and l <= p:
		return "lift"
	return "boat" if b <= p else "plant"


## Index of the deepest open dive site.
func deepest_open() -> int:
	var deepest := 0
	for i in Balance.DEPTHS.size():
		if levels.get("d%d" % i, 0) > 0:
			deepest = i
	return deepest


func cycle_time(key: String) -> float:
	if key == "lift":
		# Deeper shafts make longer trips (each trip carries more). A trip
		# keeps the depth it started with, so opening a depth never jumps it.
		var deep := lift_trip_depth if lift_trip_depth >= 0 else deepest_open()
		return Balance.LIFT["cycle"] + Balance.LIFT["cycle_step"] * deep
	return stage_data(key)["cycle"]


## Amount one full cycle moves.
func cycle_capacity(key: String) -> float:
	return rate(key) * cycle_time(key)


## 0..1 progress of the running cycle, or -1 when idle.
func cycle_progress(key: String) -> float:
	var t: float = _timer.get(key, -1.0)
	return -1.0 if t < 0.0 else clampf(t / cycle_time(key), 0.0, 1.0)


func cycle_load(key: String) -> float:
	return _load.get(key, 0.0)


func upgrade_cost(key: String, count: int = 1) -> float:
	return Balance.bulk_cost(stage_data(key)["cost0"], get_level(key), count)


func max_affordable(key: String) -> int:
	return Balance.affordable_levels(stage_data(key)["cost0"], get_level(key), coins)


func unlock_cost(key: String) -> float:
	return stage_data(key)["unlock"]


func manager_cost(key: String) -> float:
	return stage_data(key)["manager"]


## The next closed dive site, or "" when all are open.
func next_depth() -> String:
	for key in stage_keys():
		if depth_index(key) >= 0 and not is_open(key):
			return key
	return ""


func divers(key: String) -> int:
	return Balance.divers_at(get_level(key))


func prestige_cost() -> float:
	return Balance.prestige_cost(prestige_count)


## Id of the depth that must be open before the next Dive Deeper.
func prestige_gate_depth() -> String:
	return Balance.DEPTHS[Balance.prestige_gate(prestige_count)]["id"]


func prestige_gate_open() -> bool:
	return is_open("d%d" % Balance.prestige_gate(prestige_count))


func can_prestige() -> bool:
	return prestige_gate_open() and coins >= prestige_cost()


func is_rushing() -> bool:
	return rush_left > 0.0


## Report of coins earned while away. Given out once.
func take_offline_report() -> Dictionary:
	var report := _offline_report
	_offline_report = {}
	return report


# --- Actions ------------------------------------------------------------------

func upgrade(key: String, count: int = 1) -> bool:
	if not is_open(key) or count <= 0:
		return false
	var cost := upgrade_cost(key, count)
	if coins < cost:
		return false
	coins -= cost
	upgraded_from[key] = get_level(key)
	var before := Balance.milestones(get_level(key))
	levels[key] = get_level(key) + count
	if Balance.milestones(levels[key]) > before:
		milestone_reached.emit(key, levels[key])
	upgraded.emit(key, count)
	changed.emit()
	return true


## Buys the second boat or plant (level 1).
func open_building(key: String) -> bool:
	if not is_second(key) or is_open(key) or coins < unlock_cost(key):
		return false
	coins -= unlock_cost(key)
	levels[key] = 1
	depth_opened.emit(key)
	changed.emit()
	return true


func open_depth(key: String) -> bool:
	if key != next_depth() or coins < unlock_cost(key):
		return false
	coins -= unlock_cost(key)
	levels[key] = 1
	depth_opened.emit(key)
	changed.emit()
	return true


func hire_manager(key: String) -> bool:
	if not is_open(key) or has_manager(key) or coins < manager_cost(key):
		return false
	coins -= manager_cost(key)
	managers[key] = true
	manager_hired.emit(key)
	changed.emit()
	return true


## Rewards from quests, chests, puzzles and gifts.
func add_coins(amount: float) -> void:
	if amount > 0.0 and is_finite(amount):
		_earn(amount)
		changed.emit()


func add_boost(seconds: float) -> void:
	boost_left = minf(24.0 * 3600.0, boost_left + maxf(0.0, seconds))
	changed.emit()


## Player tapped a stage: starts the cycle if idle, otherwise pushes the
## running one forward a little. Also fills the rush meter.
## Returns true when something happened. Taps over Balance.TAP_CAP per
## second on one target do nothing (returns false).
func tap(key: String) -> bool:
	if not is_open(key):
		return false
	if not _taps.allow(key, tap_clock):
		return false
	if _taps.allow("rush", tap_clock):
		_add_rush()
	tapped.emit(key)
	if _timer[key] >= 0.0:
		_timer[key] += Balance.TAP_BOOST * float(bonus.get("tap", 1.0)) * cycle_time(key)
		return true
	return _start_cycle(key)


func prestige() -> bool:
	if not can_prestige():
		return false
	prestige_count += 1
	coins = 0.0
	_reset_run(true)
	changed.emit()
	save_game()
	return true


## Runs the economy forward. Live play uses cycles; `seconds` may be large.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	tap_clock += seconds
	rush_meter = maxf(0.0, rush_meter - RUSH_DECAY * seconds)
	var speed := RUSH_SPEED if rush_left > 0.0 else 1.0
	rush_left = maxf(0.0, rush_left - seconds)
	boost_left = maxf(0.0, boost_left - seconds)
	for key in stage_keys():
		if not is_open(key):
			continue
		if _timer[key] < 0.0 and is_auto(key):
			_start_cycle(key)
		if _timer[key] < 0.0:
			continue
		_timer[key] += seconds * speed
		while _timer[key] >= cycle_time(key):
			var leftover: float = _timer[key] - cycle_time(key)
			_finish_cycle(key)
			if not is_auto(key) or not _start_cycle(key):
				break
			_timer[key] = leftover


func _start_cycle(key: String) -> bool:
	var amount := cycle_capacity(key)
	if key == "lift":
		amount = minf(pit, amount)
		if amount <= 0.0:
			return false
		pit -= amount
		lift_trip_depth = deepest_open()
	elif is_boat(key):
		amount = minf(hold, amount)
		if amount <= 0.0:
			return false
		hold -= amount
	elif is_plant(key):
		amount = minf(dock, amount)
		if amount <= 0.0:
			return false
		dock -= amount
	_timer[key] = 0.0
	_load[key] = amount
	cycle_started.emit(key, amount)
	return true


func _finish_cycle(key: String) -> void:
	var amount: float = _load[key]
	_timer[key] = -1.0
	_load[key] = 0.0
	if key == "lift":
		hold += amount
		lift_trip_depth = -1
	elif is_boat(key):
		dock += amount
	elif is_plant(key):
		_earn(amount)
	else:
		pit += amount
	cycle_finished.emit(key, amount)


func _earn(amount: float) -> void:
	coins += amount
	total_earned += amount
	coins_earned.emit(amount)


func _add_rush() -> void:
	if rush_left > 0.0:
		return
	rush_meter += RUSH_PER_TAP
	if rush_meter >= 1.0:
		rush_meter = 0.0
		rush_left = RUSH_SEC
		rush_started.emit()


## Time away: divers and automated stages keep working. Uses smooth flows
## instead of cycles so 8 hours cost a few thousand cheap steps.
func simulate_offline(seconds: float) -> float:
	var earned := 0.0
	var dives := dives_rate()
	var lift := lift_rate() if has_manager("lift") else 0.0
	var boat := 0.0
	var plant := 0.0
	for k in BUILDINGS:
		if has_manager(k):
			if is_boat(k):
				boat += rate(k)
			else:
				plant += rate(k)
	var left := seconds
	while left > 0.0:
		var dt := minf(OFFLINE_STEP, left)
		left -= dt
		pit += dives * dt
		var lifted := minf(pit, lift * dt)
		pit -= lifted
		hold += lifted
		var moved := minf(hold, boat * dt)
		hold -= moved
		dock += moved
		var made := minf(dock, plant * dt)
		dock -= made
		earned += made
		# Once nothing flows the rest of the time adds nothing but ore piles.
		if dives == 0.0 and lifted == 0.0 and moved == 0.0 and made == 0.0:
			break
	if earned > 0.0:
		_earn(earned)
	return earned


# --- Save ---------------------------------------------------------------------

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"coins": coins,
		"total_earned": total_earned,
		"prestige_count": prestige_count,
		"levels": levels,
		"managers": managers,
		"pit": pit,
		"hold": hold,
		"dock": dock,
		"boost_left": boost_left,
	}
	# Write to a temp file and swap, so a crash mid-write can't corrupt the save.
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_warning("Save rename failed: %s" % error_string(err))
		return false
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not data is Dictionary:
		push_warning("Save file is corrupted, starting fresh")
		return false
	_apply_save(data)
	var now := Time.get_unix_time_from_system()
	var away := clampf(now - _num(data.get("saved_at"), now), 0.0, Balance.OFFLINE_CAP_SEC)
	var earned := simulate_offline(away)
	if earned > 0.0 and float(bonus.get("offline", 1.0)) > 1.0:
		var extra := earned * (float(bonus["offline"]) - 1.0)
		_earn(extra)
		earned += extra
	boost_left = maxf(0.0, boost_left - away)
	if away >= Balance.OFFLINE_MIN_REPORT_SEC and earned >= 1.0:
		_offline_report = {"seconds": away, "coins": earned}
	changed.emit()
	return true


func reset_progress() -> void:
	reset()
	save_game()
	changed.emit()


## Debug: +coins equal to 10 minutes of current income (at least 1000).
func debug_grant() -> void:
	_earn(maxf(1000.0, income_rate() * 600.0))
	changed.emit()


func _apply_save(data: Dictionary) -> void:
	reset()
	coins = maxf(0.0, _num(data.get("coins"), 0.0))
	total_earned = maxf(coins, _num(data.get("total_earned"), 0.0))
	prestige_count = maxi(0, int(_num(data.get("prestige_count"), 0.0)))
	var saved_levels = data.get("levels", {})
	var saved_managers = data.get("managers", {})
	# Saves from before the lift: it gets set up below, after the rest.
	var old_save: bool = saved_levels is Dictionary and not saved_levels.has("lift")
	for key in stage_keys():
		if saved_levels is Dictionary:
			var minimum := 0 if depth_index(key) > 0 or is_second(key) else 1
			levels[key] = maxi(minimum, int(_num(saved_levels.get(key), minimum)))
		if saved_managers is Dictionary:
			managers[key] = saved_managers.get(key) == true and is_open(key)
	# A deeper site can't be open while a shallower one is closed.
	var closed := false
	for key in stage_keys():
		if depth_index(key) < 0:
			continue
		if closed:
			levels[key] = 0
			managers[key] = false
		elif levels[key] == 0:
			closed = true
	pit = maxf(0.0, _num(data.get("pit"), 0.0))
	hold = maxf(0.0, _num(data.get("hold"), 0.0))
	dock = maxf(0.0, _num(data.get("dock"), 0.0))
	boost_left = clampf(_num(data.get("boost_left"), 0.0), 0.0, 24.0 * 3600.0)
	if old_save:
		_migrate_lift()


## A save from before the lift: open the lift at a level that keeps up with
## the rest of the chain (so nothing suddenly stalls), and let it run by
## itself if the boat already did. Artifact bonuses may be loaded later and
## the lift has none of its own, hence a little headroom.
const LIFT_MIGRATE_HEADROOM := 1.25


func _migrate_lift() -> void:
	var target := minf(dives_rate(), minf(boats_rate(), plants_rate())) * LIFT_MIGRATE_HEADROOM
	var level := 1
	levels["lift"] = level
	while rate("lift") < target and level < 5000:
		level += 1
		levels["lift"] = level
	managers["lift"] = has_manager("boat")


static func _num(value, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback
