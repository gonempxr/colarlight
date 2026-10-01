extends SceneTree
## Economy checks without UI:
##   godot --headless --path . -s res://tests/test_economy.gd
## Exit code 0 means every check passed.

const TEST_SAVE := "user://test_economy.json"

var _script: GDScript
var _failures := 0
var _checks := 0


func _initialize() -> void:
	# load(), not preload(): a compile error must fail the run, not skip it.
	_script = load("res://scripts/autoload/game_state.gd")
	if _script == null or not _script.can_instantiate():
		print("FAIL: game_state.gd does not compile")
		quit(1)
		return
	test_formulas()
	test_bulk_and_affordable()
	test_tap_runs_one_cycle()
	test_foreman_and_kept_automation()
	test_chain_moves_ore_to_coins()
	test_manager_loops()
	test_boat_waits_for_ore()
	test_bottleneck()
	test_open_depth_in_order()
	test_milestone_signal()
	test_rush()
	test_tap_cap()
	test_offline_only_with_managers()
	test_save_load_roundtrip()
	test_corrupted_save()
	test_prestige()
	test_num_format()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _fresh() -> Node:
	var gs: Node = _script.new()
	gs.save_path = TEST_SAVE
	gs.autosave_enabled = false
	gs.reset()
	DirAccess.remove_absolute(TEST_SAVE)
	return gs


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func test_formulas() -> void:
	check(Balance.milestones(9) == 0, "no milestone below 10")
	check(Balance.milestones(10) == 1, "milestone at 10")
	check(Balance.milestones(24) == 1 and Balance.milestones(25) == 2, "next at 25")
	check(Balance.milestones(50) == 3, "then every 25")
	check(near(Balance.output(2.0, 10), 2.0 * 10 * 2), "output doubles at 10")
	check(Balance.output(2.0, 0) == 0.0, "closed stage outputs nothing")
	check(near(Balance.upgrade_cost(6.0, 1), 6.0), "first upgrade costs cost0")
	check(near(Balance.upgrade_cost(6.0, 3), 6.0 * 1.08 * 1.08), "cost grows 8% per level")
	check(Balance.divers_at(1) == 1 and Balance.divers_at(10) == 2, "divers grow with milestones")
	check(Balance.divers_at(500) == Balance.MAX_DIVERS, "divers capped")


func test_bulk_and_affordable() -> void:
	var sum := 0.0
	for i in 10:
		sum += Balance.upgrade_cost(6.0, 5 + i)
	check(near(Balance.bulk_cost(6.0, 5, 10), sum), "bulk cost equals sum of steps")
	check(Balance.affordable_levels(6.0, 5, sum) == 10, "affordable exactly 10")
	check(Balance.affordable_levels(6.0, 5, sum - 0.01) == 9, "one cent short gives 9")
	check(Balance.affordable_levels(6.0, 5, 1.0) == 0, "can't afford any")


func test_tap_runs_one_cycle() -> void:
	var gs := _fresh()
	check(gs.is_auto("d0") and not gs.is_auto("lift") and not gs.is_auto("boat") and not gs.is_auto("plant"), "divers work alone, lift, boat and plant need taps")
	check(gs.cycle_progress("d0") < 0.0, "idle before the first tick")
	check(gs.tap("d0"), "tap starts dive")
	gs.advance(gs.cycle_time("d0") * 0.5)
	check(near(gs.cycle_progress("d0"), 0.5), "halfway through the dive")
	check(gs.tap("d0"), "tap while diving helps")
	check(near(gs.cycle_progress("d0"), 0.5 + Balance.TAP_BOOST), "tap pushes the dive forward")
	gs.advance(gs.cycle_time("d0") * (0.5 - Balance.TAP_BOOST))
	check(near(gs.pit, gs.cycle_capacity("d0")), "one dive leaves one load in the crate")
	check(gs.hold == 0.0, "divers no longer bring ore to the raft")
	check(gs.cycle_progress("d0") >= 0.0, "divers go again on their own")
	check(not gs.tap("boat"), "boat has nothing to carry yet")
	check(gs.tap("lift"), "lift runs on tap")
	gs.advance(gs.cycle_time("lift"))
	check(gs.cycle_progress("lift") < 0.0, "lift without operator stops after one trip")
	check(gs.hold > 0.0, "lift brought the ore up to the raft")
	check(gs.tap("boat"), "boat sails on tap")
	gs.advance(gs.cycle_time("boat"))
	check(gs.cycle_progress("boat") < 0.0, "boat without captain stops after one trip")
	check(not gs.tap("d1"), "closed site can't be tapped")
	gs.free()


func test_foreman_and_kept_automation() -> void:
	var gs := _fresh()
	var base: float = gs.rate("d0")
	gs.coins = 1e6
	check(gs.hire_manager("d0"), "hire foreman")
	check(near(gs.rate("d0"), base * Balance.FOREMAN_MULT), "foreman doubles the site")
	check(gs.hire_manager("boat") and gs.hire_manager("plant"), "hire captain and plant manager")
	check(gs.is_auto("boat") and gs.is_auto("plant"), "boat and plant automated")
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
	gs.coins = 1e12
	check(gs.prestige(), "dive")
	check(gs.is_auto("boat") and gs.is_auto("plant"), "automation survives the dive")
	check(not gs.has_manager("d0"), "foremen are hired again")
	gs.boost_left = 10.0
	check(near(gs.rate("plant"), Balance.output(Balance.PLANT["value"], 1) * 3.0 * 2.0), "boost doubles income")
	gs.bonus = {"plant": 1.5}
	gs.boost_left = 0.0
	check(near(gs.rate("plant"), Balance.output(Balance.PLANT["value"], 1) * 3.0 * 1.5), "stage bonus applies")
	gs.free()
	DirAccess.remove_absolute(TEST_SAVE)


func test_chain_moves_ore_to_coins() -> void:
	var gs := _fresh()
	gs.tap("d0")
	gs.advance(gs.cycle_time("d0"))
	check(gs.tap("lift"), "lift goes down for the ore")
	gs.advance(gs.cycle_time("lift"))
	var ore: float = gs.hold
	check(gs.tap("boat"), "boat sails with ore")
	check(near(gs.hold, maxf(0.0, ore - gs.cycle_capacity("boat"))), "boat loads up to capacity")
	gs.advance(gs.cycle_time("boat"))
	check(gs.dock > 0.0, "boat unloads on shore")
	check(gs.tap("plant"), "plant starts with ore on dock")
	gs.advance(gs.cycle_time("plant"))
	check(gs.coins > 0.0, "plant turns ore into coins")
	check(near(gs.coins, gs.total_earned), "earned tracked")
	gs.free()


func test_manager_loops() -> void:
	var gs := _fresh()
	gs.coins = 1000.0
	check(gs.hire_manager("d0"), "hire diver foreman")
	check(not gs.hire_manager("d0"), "no second manager")
	check(not gs.hire_manager("d1"), "no manager for a closed site")
	check(near(gs.coins, 1000.0 - Balance.DEPTHS[0]["manager"]), "manager paid")
	var t: float = gs.cycle_time("d0")
	for i in 10:
		gs.advance(t / 4.0)
	check(near(gs.pit, gs.cycle_capacity("d0") * 2.0), "manager keeps diving: 2.5 cycles -> 2 loads")
	check(gs.cycle_progress("d0") >= 0.0, "still diving")
	gs.free()


func test_boat_waits_for_ore() -> void:
	var gs := _fresh()
	gs.managers["boat"] = true
	gs.advance(10.0)
	check(gs.cycle_progress("boat") < 0.0, "boat with manager waits while hold is empty")
	check(not gs.tap("boat"), "tapping an empty boat does nothing")
	gs.hold = 1.0
	gs.advance(0.01)
	check(gs.cycle_progress("boat") >= 0.0, "boat leaves once there is ore")
	gs.free()


func test_bottleneck() -> void:
	var gs := _fresh()
	for key in gs.stage_keys():
		gs.managers[key] = gs.is_open(key)
	gs.levels["plant"] = 100
	gs.levels["boat"] = 100
	gs.levels["lift"] = 100
	check(gs.bottleneck() == "dives", "divers limit when lift, boat and plant are strong")
	check(near(gs.income_rate(), gs.dives_rate()), "income is the weakest link")
	gs.levels["d0"] = 400
	check(gs.bottleneck() == "boat", "boat limits when divers are strong")
	gs.levels["lift"] = 20
	check(gs.bottleneck() == "lift" and near(gs.income_rate(), gs.lift_rate()), "a weak lift is the bottleneck")
	# A long stretch of play should earn about income_rate per second.
	gs.levels = {"d0": 30, "d1": 0, "d2": 0, "d3": 0, "d4": 0, "d5": 0, "lift": 40, "boat": 40, "plant": 40}
	# Warm up: the first ore needs a dive, a boat trip and a plant cycle to become coins.
	for i in 300:
		gs.advance(0.1)
	var start: float = gs.coins
	for i in 600:
		gs.advance(0.1)
	var per_sec: float = (gs.coins - start) / 60.0
	check(absf(per_sec - gs.income_rate()) < gs.income_rate() * 0.15, "live chain earns ~income_rate (%.2f vs %.2f)" % [per_sec, gs.income_rate()])
	gs.free()


func test_open_depth_in_order() -> void:
	var gs := _fresh()
	check(gs.next_depth() == "d1", "next site is d1")
	check(not gs.open_depth("d2"), "can't skip a site")
	check(not gs.open_depth("d1"), "can't open without coins")
	gs.coins = Balance.DEPTHS[1]["unlock"]
	check(gs.open_depth("d1"), "opens with exact coins")
	check(gs.get_level("d1") == 1 and gs.coins == 0.0, "open sets level 1 and spends")
	check(gs.next_depth() == "d2", "then d2")
	gs.free()


func test_milestone_signal() -> void:
	var gs := _fresh()
	var hits := []
	gs.milestone_reached.connect(func(key, level): hits.append([key, level]))
	gs.coins = 1e9
	check(gs.upgrade("d0", 8), "buy 8 levels")
	check(hits.is_empty(), "no milestone at level 9")
	check(gs.upgrade("d0", 1), "buy to 10")
	check(hits.size() == 1 and hits[0] == ["d0", 10], "milestone signal at 10")
	var before: float = gs.coins
	var cost: float = gs.upgrade_cost("plant", 5)
	check(gs.upgrade("plant", 5) and near(before - gs.coins, cost), "bulk upgrade charges bulk cost")
	gs.coins = 0.0
	check(not gs.upgrade("plant"), "can't upgrade broke")
	gs.free()


func test_rush() -> void:
	var gs := _fresh()
	var started := [0]
	gs.rush_started.connect(func(): started[0] += 1)
	for i in 13:
		gs.tap_clock += 0.12
		gs.tap("d0")
	check(started[0] == 1 and gs.is_rushing(), "13 quick taps start a rush")
	gs.tap("plant")
	check(gs.rush_meter == 0.0, "meter doesn't fill during rush")
	var gs2 := _fresh()
	gs2.managers["d0"] = true
	gs2.advance(0.0001)
	gs2.rush_left = 10.0
	gs2.advance(gs2.cycle_time("d0") / 2.0)
	check(near(gs2.pit, gs2.cycle_capacity("d0")), "rush doubles speed")
	gs.free()
	gs2.free()


## An autoclicker (100 taps in a second) gets no more than Balance.TAP_CAP
## taps' worth per target, and no faster rush; a human pace keeps every tap.
func test_tap_cap() -> void:
	var gs := _fresh()
	var counted := [0]
	gs.tapped.connect(func(_k: String): counted[0] += 1)
	gs.tap("d0")
	var before: float = gs.cycle_progress("d0")
	var effective := 1
	for i in 99:
		gs.advance(0.01)
		if gs.tap("d0"):
			effective += 1
	var cap: int = Balance.TAP_CAP
	check(effective <= cap and counted[0] <= cap, "100 taps in 1 s count as at most %d (%d)" % [cap, effective])
	check(effective >= cap - 1, "the cap still lets %d taps count (%d)" % [cap, effective])
	var pushed: float = gs.cycle_progress("d0") - before
	check(pushed <= cap * Balance.TAP_BOOST + 0.01 / gs.cycle_time("d0") * 100.0 + 0.05, "100 taps push the dive no more than the cap allows (%.2f)" % pushed)
	check(gs.rush_meter <= cap * gs.RUSH_PER_TAP + 0.001 and not gs.is_rushing(), "100 taps in 1 s fill the rush meter like %d (%.2f)" % [cap, gs.rush_meter])
	# Many targets at once: the rush meter still fills at most at the cap.
	var gs2 := _fresh()
	gs2.levels["d1"] = 1
	gs2.levels["d2"] = 1
	for i in 30:
		gs2.tap("d0")
		gs2.tap("d1")
		gs2.tap("d2")
	check(gs2.rush_meter <= cap * gs2.RUSH_PER_TAP + 0.001, "taps on many targets share the rush cap (%.2f)" % gs2.rush_meter)
	# A fast human (8 taps a second) is never capped.
	var gs3 := _fresh()
	var ok := 0
	for i in 40:
		gs3.advance(0.125)
		if gs3.tap("d0"):
			ok += 1
	check(ok == 40, "8 taps a second all count (%d of 40)" % ok)
	# The cap is per target: the lift and the boat still take their own taps.
	var gs4 := _fresh()
	gs4.pit = 100.0
	for i in 20:
		gs4.tap("d0")
	check(gs4.tap("lift"), "capped dive taps do not block the lift")
	gs.free()
	gs2.free()
	gs3.free()
	gs4.free()


func test_offline_only_with_managers() -> void:
	var gs := _fresh()
	check(gs.simulate_offline(3600.0) == 0.0, "no coins offline without lift, boat and plant managers")
	check(gs.pit > 0.0 and gs.hold == 0.0, "divers still fill the crates offline, the lift waits")
	gs.pit = 0.0
	for key in ["d0", "lift", "boat", "plant"]:
		gs.managers[key] = true
	gs.levels["d0"] = 20
	gs.levels["lift"] = 30
	gs.levels["boat"] = 30
	gs.levels["plant"] = 30
	var earned: float = gs.simulate_offline(3600.0)
	check(absf(earned - gs.income_rate() * 3600.0) < gs.income_rate() * 5.0, "offline earns income_rate per second")
	gs.managers["plant"] = false
	check(gs.simulate_offline(3600.0) == 0.0, "no plant manager, no coins offline")
	gs.free()


func test_save_load_roundtrip() -> void:
	var gs := _fresh()
	gs.coins = 1234.5
	gs.levels["d0"] = 17
	gs.levels["d1"] = 3
	gs.levels["boat"] = 9
	gs.managers["d0"] = true
	gs.prestige_count = 2
	gs.hold = 5.0
	check(gs.save_game(), "save ok")
	# Pretend the save is 2 minutes old: without boat/plant managers nothing is earned.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	data["saved_at"] = float(data["saved_at"]) - 120.0
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	gs.free()
	var loaded: Node = _script.new()
	loaded.save_path = TEST_SAVE
	loaded.autosave_enabled = false
	loaded.reset()
	check(loaded.load_game(), "load ok")
	check(near(loaded.coins, 1234.5), "coins restored")
	check(loaded.get_level("d0") == 17 and loaded.get_level("d1") == 3 and loaded.get_level("boat") == 9, "levels restored")
	check(loaded.has_manager("d0") and not loaded.has_manager("boat"), "managers restored")
	check(loaded.prestige_count == 2, "prestige restored")
	check(loaded.pit > 0.0 and near(loaded.hold, 5.0), "diver manager kept diving offline into the crates")
	check(loaded.take_offline_report().is_empty(), "no coins, no report")
	loaded.free()
	DirAccess.remove_absolute(TEST_SAVE)


func test_corrupted_save() -> void:
	var gs := _fresh()
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(not gs.load_game(), "broken json rejected")
	f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"coins": -5, "levels": {"d0": "x", "d1": 0, "d2": 7, "boat": -3}, "managers": {"d2": true}}))
	f.close()
	check(gs.load_game(), "partial save accepted")
	check(gs.coins == 0.0, "negative coins clamped")
	check(gs.get_level("d0") == 1, "first site always open")
	check(gs.get_level("d2") == 0 and not gs.has_manager("d2"), "site past a closed one stays closed")
	check(gs.get_level("boat") == 1, "boat never below level 1")
	gs.free()
	DirAccess.remove_absolute(TEST_SAVE)


func test_prestige() -> void:
	var gs := _fresh()
	gs.coins = 1e12
	check(not gs.can_prestige(), "prestige needs the gate depth open")
	check(gs.prestige_gate_depth() == Balance.DEPTHS[5]["id"], "first gate is the sixth depth")
	for i in 5:
		gs.levels["d%d" % i] = maxi(1, gs.levels["d%d" % i])
	check(not gs.can_prestige(), "one short of the gate")
	gs.levels["d5"] = 1
	check(gs.can_prestige(), "gate open and enough coins")
	check(gs.next_depth() != "", "deeper depths may stay closed")
	var before: float = gs.rate("plant")
	check(gs.prestige(), "prestige works")
	check(gs.prestige_count == 1 and gs.coins == 0.0, "counter up, coins reset")
	check(gs.get_level("d1") == 0 and gs.get_level("plant") == 1, "levels reset")
	check(near(gs.rate("plant"), Balance.output(Balance.PLANT["value"], 1) * 3.0), "income x3 after first prestige")
	check(before > 0.0, "sanity")
	check(near(gs.prestige_cost(), Balance.PRESTIGE_COST * Balance.PRESTIGE_COST_GROWTH), "next prestige costs more")
	check(gs.prestige_gate_depth() == Balance.DEPTHS[7]["id"], "each Dive needs two depths deeper")
	gs.prestige_count = 50
	check(gs.prestige_gate_depth() == Balance.DEPTHS[Balance.DEPTHS.size() - 1]["id"], "gate stops at the last depth")
	gs.free()
	DirAccess.remove_absolute(TEST_SAVE)


func test_num_format() -> void:
	check(NumFormat.short(7.9) == "7", "small numbers floor")
	check(NumFormat.short(1000.0) == "1.0K", "1000 is 1.0K")
	check(NumFormat.short(999999.0) == "999K", "never rounds up to 1000K")
	check(NumFormat.short(3.4e7) == "34.0M", "millions")
	check(NumFormat.short(2.5e15) == "2.5aa", "after T comes aa")
	check(NumFormat.short(2.5e18) == "2.5ab", "then ab")
	check(NumFormat.rate(0.64) == "0.6", "rates keep a decimal")
	check(NumFormat.duration(3909.0) == "1:05:09", "hours format")
	check(NumFormat.duration(247.0) == "4:07", "minutes format")
