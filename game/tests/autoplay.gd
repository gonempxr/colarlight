extends SceneTree
## Bot player on the real economy, sped up. Checks the pacing that
## balance/sim.py predicts (same buying policy).
##   godot --headless --path . -s res://tests/autoplay.gd [-- --hours=3 --trace]
## Prints when each site opens, managers are hired and prestige becomes affordable.

const STEP := 0.25
const DECIDE_EVERY := 1.0
## An active player notices an idle stage after about this long and taps it.
const TAP_REACTION_SEC := 1.5
const OPEN_WITHIN_SEC := 126.0
const MANAGER_WITHIN_SEC := 300.0

var gs: Node
var _t := 0.0
var _idle_for: Dictionary = {}
var _trace := false


func _initialize() -> void:
	var hours := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hours="):
			hours = float(arg.get_slice("=", 1))
		elif arg == "--trace":
			_trace = true
	gs = load("res://scripts/autoload/game_state.gd").new()
	gs.save_path = "user://autoplay.json"
	gs.autosave_enabled = false
	gs.reset()
	var decide_left := 0.0
	var prestige_at := -1.0
	while _t < hours * 3600.0:
		_tap_idle_stages()
		gs.advance(STEP)
		_t += STEP
		decide_left -= STEP
		if decide_left <= 0.0:
			decide_left = DECIDE_EVERY
			while _buy_something():
				pass
		if gs.can_prestige():
			prestige_at = _t
			_log("PRESTIGE affordable")
			break
	print("end %s: levels %s income %s/s bottleneck %s coins %s" % [
		NumFormat.duration(_t), gs.levels, NumFormat.rate(gs.income_rate()),
		gs.bottleneck(), NumFormat.short(gs.coins)])
	print("RESULT prestige_at=%d" % int(prestige_at))
	gs.free()
	quit(0)


func _log(what: String) -> void:
	print("%s  %s" % [NumFormat.duration(_t), what])


func _tap_idle_stages() -> void:
	for key in gs.stage_keys():
		if not gs.is_open(key) or gs.has_manager(key):
			continue
		if gs.cycle_progress(key) >= 0.0:
			_idle_for[key] = 0.0
			continue
		_idle_for[key] = _idle_for.get(key, 0.0) + STEP
		if _idle_for[key] >= TAP_REACTION_SEC:
			gs.tap(key)
			_idle_for[key] = 0.0


## Income if every open stage were automated; the bot plans with this.
func _potential() -> float:
	var r := [gs.dives_rate(), gs.rate("boat"), gs.rate("plant")]
	if r.min() <= 0.0:
		return 0.0
	var s := 0.0
	for x in r:
		s += 1.0 / pow(x, 4.0)
	return 3.0 / pow(s, 0.25) / pow(3.0, 0.75)


func _buy_something() -> bool:
	var inc := maxf(gs.income_rate(), 0.01)
	var next: String = gs.next_depth()
	if next != "" and gs.unlock_cost(next) <= inc * OPEN_WITHIN_SEC:
		if gs.open_depth(next):
			_log("open " + next)
			return true
		return false  # saving up for it
	for key in gs.stage_keys():
		if gs.is_open(key) and not gs.has_manager(key) and gs.manager_cost(key) <= inc * MANAGER_WITHIN_SEC:
			if gs.hire_manager(key):
				_log("manager " + key)
				return true
			return false
	var best := ""
	var best_score := 0.0
	var base := _potential()
	for key in gs.stage_keys():
		if not gs.is_open(key):
			continue
		var cost: float = gs.upgrade_cost(key)
		# All sites open: save for prestige, only buy small things.
		if next == "" and cost > 0.05 * (gs.prestige_cost() - gs.coins):
			continue
		# A sensible player upgrades what the bottleneck hint points at.
		var group: String = key if key in ["boat", "plant"] else "dives"
		if next == "" and group != gs.bottleneck():
			continue
		gs.levels[key] += 1
		var gain := _potential() - base
		gs.levels[key] -= 1
		if gain <= 0.0:
			continue
		var score := gain / (cost / inc + maxf(0.0, cost - gs.coins) / inc)
		if score > best_score:
			best_score = score
			best = key
	if best != "" and gs.upgrade(best):
		if _trace:
			_log("%s -> %d" % [best, gs.get_level(best)])
		return true
	return false
