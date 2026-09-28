extends Node
## The whole economy: dive sites -> boat -> plant -> coins.
## Registered as the GameState autoload. UI only reads from here and calls actions.
##
## Stage keys: "d0".."d5" (dive sites, shallow to deep), "boat", "plant".
## A stage without a manager runs one cycle per tap; with a manager it loops.
## Divers put ore into `hold` (at the boat), the boat moves it to `dock`
## (on shore), the plant turns dock ore into coins.

signal changed
signal cycle_started(key: String, amount: float)
signal cycle_finished(key: String, amount: float)
signal milestone_reached(key: String, level: int)
signal rush_started
signal coins_earned(amount: float)

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
var hold := 0.0
var dock := 0.0
var rush_meter := 0.0
var rush_left := 0.0

## Per-stage cycle state: seconds elapsed in the current cycle (-1 = idle)
## and the amount the cycle carries.
var _timer: Dictionary = {}
var _load: Dictionary = {}
var _autosave_left := Balance.AUTOSAVE_SEC
var _offline_report: Dictionary = {}


func _ready() -> void:
	reset()
	load_game()


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
	_reset_run()


func _reset_run() -> void:
	levels = {}
	managers = {}
	for key in stage_keys():
		levels[key] = 0
		managers[key] = false
		_timer[key] = -1.0
		_load[key] = 0.0
	levels["d0"] = 1
	levels["boat"] = 1
	levels["plant"] = 1
	hold = 0.0
	dock = 0.0
	rush_meter = 0.0
	rush_left = 0.0
	_offline_report = {}


# --- Queries ------------------------------------------------------------------

static func stage_keys() -> Array[String]:
	var keys: Array[String] = []
	for i in Balance.DEPTHS.size():
		keys.append("d%d" % i)
	keys.append("boat")
	keys.append("plant")
	return keys


static func depth_index(key: String) -> int:
	return int(key.substr(1)) if key.begins_with("d") else -1


static func stage_data(key: String) -> Dictionary:
	match key:
		"boat":
			return Balance.BOAT
		"plant":
			return Balance.PLANT
	return Balance.DEPTHS[depth_index(key)]


func get_level(key: String) -> int:
	return levels.get(key, 0)


func has_manager(key: String) -> bool:
	return managers.get(key, false)


func is_open(key: String) -> bool:
	return get_level(key) > 0


func income_mult() -> float:
	return Balance.prestige_mult(prestige_count)


## Coins per second this stage can handle.
func rate(key: String) -> float:
	return Balance.output(stage_data(key)["value"], get_level(key)) * income_mult()


func dives_rate() -> float:
	var total := 0.0
	for i in Balance.DEPTHS.size():
		total += rate("d%d" % i)
	return total


## Coins per second with every stage automated: the weakest link.
func income_rate() -> float:
	return minf(dives_rate(), minf(rate("boat"), rate("plant")))


## Which group limits income: "dives", "boat" or "plant".
func bottleneck() -> String:
	var d := dives_rate()
	var b := rate("boat")
	var p := rate("plant")
	if d <= b and d <= p:
		return "dives"
	return "boat" if b <= p else "plant"


func cycle_time(key: String) -> float:
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


func can_prestige() -> bool:
	return next_depth() == "" and coins >= prestige_cost()


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
	var before := Balance.milestones(get_level(key))
	levels[key] = get_level(key) + count
	if Balance.milestones(levels[key]) > before:
		milestone_reached.emit(key, levels[key])
	changed.emit()
	return true


func open_depth(key: String) -> bool:
	if key != next_depth() or coins < unlock_cost(key):
		return false
	coins -= unlock_cost(key)
	levels[key] = 1
	changed.emit()
	return true


func hire_manager(key: String) -> bool:
	if not is_open(key) or has_manager(key) or coins < manager_cost(key):
		return false
	coins -= manager_cost(key)
	managers[key] = true
	changed.emit()
	return true


## Player tapped a stage: starts a cycle if idle and fills the rush meter.
func tap(key: String) -> bool:
	if not is_open(key):
		return false
	_add_rush()
	if _timer[key] >= 0.0:
		return false
	return _start_cycle(key)


func prestige() -> bool:
	if not can_prestige():
		return false
	prestige_count += 1
	coins = 0.0
	_reset_run()
	changed.emit()
	save_game()
	return true


## Runs the economy forward. Live play uses cycles; `seconds` may be large.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	rush_meter = maxf(0.0, rush_meter - RUSH_DECAY * seconds)
	var speed := RUSH_SPEED if rush_left > 0.0 else 1.0
	rush_left = maxf(0.0, rush_left - seconds)
	for key in stage_keys():
		if not is_open(key):
			continue
		if _timer[key] < 0.0 and has_manager(key):
			_start_cycle(key)
		if _timer[key] < 0.0:
			continue
		_timer[key] += seconds * speed
		while _timer[key] >= cycle_time(key):
			var leftover: float = _timer[key] - cycle_time(key)
			_finish_cycle(key)
			if not has_manager(key) or not _start_cycle(key):
				break
			_timer[key] = leftover


func _start_cycle(key: String) -> bool:
	var amount := cycle_capacity(key)
	match key:
		"boat":
			amount = minf(hold, amount)
			if amount <= 0.0:
				return false
			hold -= amount
		"plant":
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
	match key:
		"boat":
			dock += amount
		"plant":
			_earn(amount)
		_:
			hold += amount
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


## Time away: only stages with managers work. Uses smooth flows instead of
## cycles so 8 hours cost a few thousand cheap steps.
func simulate_offline(seconds: float) -> float:
	var earned := 0.0
	var dives := 0.0
	for i in Balance.DEPTHS.size():
		var key := "d%d" % i
		if has_manager(key):
			dives += rate(key)
	var boat := rate("boat") if has_manager("boat") else 0.0
	var plant := rate("plant") if has_manager("plant") else 0.0
	var left := seconds
	while left > 0.0:
		var dt := minf(OFFLINE_STEP, left)
		left -= dt
		hold += dives * dt
		var moved := minf(hold, boat * dt)
		hold -= moved
		dock += moved
		var made := minf(dock, plant * dt)
		dock -= made
		earned += made
		# Once nothing flows the rest of the time adds nothing but ore piles.
		if dives == 0.0 and moved == 0.0 and made == 0.0:
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
		"hold": hold,
		"dock": dock,
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
	for key in stage_keys():
		if saved_levels is Dictionary:
			var minimum := 0 if depth_index(key) > 0 else 1
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
	hold = maxf(0.0, _num(data.get("hold"), 0.0))
	dock = maxf(0.0, _num(data.get("dock"), 0.0))


static func _num(value, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback
