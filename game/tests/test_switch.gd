extends SceneTree
## Switching between opened worlds: per-world runs (snapshots), save/load
## with several worlds, migration of older saves, "while you were away"
## income (capped, no boost, not exploitable by quick switching), the gate
## only on the highest world, and quests that belong to their world.
##   godot --headless --path . -s res://tests/test_switch.gd
## Uses its own save files, never the player's.

const GAME_SAVE := "user://test_switch_game.json"
const PROGRESS_SAVE := "user://test_switch_progress.json"

var _failures := 0
var _checks := 0
var gs: Node
var pr: Node


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	pr = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	gs.save_path = GAME_SAVE
	pr.save_path = PROGRESS_SAVE
	test_fresh()
	test_advance_keeps_old_world()
	test_round_trip()
	test_gate_only_on_highest()
	test_cycles_flushed()
	test_away_cap()
	test_away_no_boost_no_rush()
	test_rapid_switching()
	test_save_load()
	test_migration()
	test_quests_per_world()
	test_quest_save()
	test_mine_quest()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute(GAME_SAVE)
	DirAccess.remove_absolute(PROGRESS_SAVE)
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	gs.reset()
	pr.reset()


func _complete_location() -> void:
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
		gs.managers[key] = true


## Completes the active world and opens the next one.
func _open_next() -> bool:
	_complete_location()
	gs.coins = gs.next_location_cost() * 1.5
	return gs.advance_location()


## Everything automated, a few levels: a world that earns while away.
func _automate() -> void:
	for key in ["d0", "d1", "d2", "lift", "boat", "plant"]:
		gs.levels[key] = maxi(gs.levels[key], 10)
		gs.managers[key] = true
	gs.managers["vault"] = true


func test_fresh() -> void:
	_fresh()
	check(gs.max_location == 0, "fresh: max_location 0")
	check(gs.is_max_location(), "fresh: on the highest world")
	check(not gs.switch_location(0), "can't switch to the active world")
	check(not gs.switch_location(1), "can't switch to a world not opened")
	check(not gs.switch_location(-1), "can't switch below 0")
	check(gs.worlds_runs.is_empty(), "no snapshots yet")


func test_advance_keeps_old_world() -> void:
	_fresh()
	gs.levels["d3"] = 0
	_complete_location()
	gs.levels["d3"] = 7
	gs.evo = 2
	gs.managers["vault"] = true
	var cost: float = gs.next_location_cost()
	gs.coins = cost * 1.5
	check(gs.advance_location(), "advance from the highest world")
	check(gs.location == 1 and gs.max_location == 1, "now at 1, max 1")
	var snap: Dictionary = gs.worlds_runs.get("0", {})
	check(not snap.is_empty(), "ocean kept a snapshot")
	check(near(float(snap.get("coins", -1.0)), cost * 0.5), "ocean keeps the coins left after the price")
	check(int(snap["levels"]["d3"]) == 7 and int(snap["gear"]) == 2, "ocean keeps its levels and gear")
	check(gs.coins == 0.0 and gs.evo == 0 and gs.get_level("d3") == 0, "volcano starts fresh")
	check(gs.has_manager("lift") and gs.has_manager("boat") and gs.has_manager("plant") and gs.has_manager("vault"), "automation comes along")
	check(not gs.has_manager("d0"), "foremen do not")


func test_round_trip() -> void:
	_fresh()
	_open_next()
	gs.levels["d0"] = 33
	gs.levels["d1"] = 5
	gs.managers["d1"] = true
	gs.evo = 1
	gs.coins = 1234.0
	gs.vault = 0.0
	var changed := [0]
	var got := [-1]
	var cb := func(l): got[0] = l
	var cb2 := func(): changed[0] += 1
	gs.location_changed.connect(cb)
	gs.changed.connect(cb2)
	check(gs.switch_location(0), "switch to the ocean")
	gs.location_changed.disconnect(cb)
	gs.changed.disconnect(cb2)
	check(got[0] == 0 and changed[0] > 0, "location_changed and changed emitted")
	check(gs.location == 0 and gs.max_location == 1, "in the ocean, max still 1")
	check(gs.get_level("d9") >= 1 and gs.has_manager("d9"), "ocean run restored")
	check(gs.worlds_runs.has("1") and not gs.worlds_runs.has("0"), "volcano put aside, ocean taken out")
	var report: Dictionary = gs.take_away_report()
	check(int(report.get("location", -1)) == 0, "away report for the ocean")
	check(gs.take_away_report().is_empty(), "the report is given once")
	check(gs.switch_location(1), "back to the volcano")
	check(gs.get_level("d0") == 33 and gs.get_level("d1") == 5 and gs.has_manager("d1"), "volcano levels and foreman back")
	check(gs.evo == 1, "volcano gear back")
	check(gs.coins >= 1234.0 and gs.coins < 1234.0 + 1.0, "volcano coins back (no time passed)")
	check(gs.world_id() == "volcano", "world id follows")


func test_gate_only_on_highest() -> void:
	_fresh()
	_open_next()
	gs.switch_location(0)
	_complete_location()
	gs.coins = gs.next_location_cost() * 10.0
	check(gs.location_ready(), "the old world's goals are met")
	check(not gs.can_advance_location(), "no gate on an older world")
	check(not gs.advance_location(), "advance from an older world is impossible")
	check(gs.location == 0 and gs.max_location == 1, "nothing moved")
	gs.switch_location(1)
	_complete_location()
	gs.coins = gs.next_location_cost() * 1.5
	check(gs.can_advance_location(), "gate works on the highest world")
	check(gs.advance_location() and gs.max_location == 2, "advance from the highest world")


func test_cycles_flushed() -> void:
	_fresh()
	_open_next()
	gs.pit = 100.0
	gs.hold = 50.0
	gs.dock = 20.0
	gs.tap("lift")
	gs.tap("boat")
	gs.tap("plant")
	var total: float = gs.pit + gs.hold + gs.dock + gs.cycle_load("lift") + gs.cycle_load("boat") + gs.cycle_load("plant")
	check(gs.cycle_load("lift") > 0.0, "a lift trip is running")
	gs.switch_location(0)
	var snap: Dictionary = gs.worlds_runs["1"]
	var kept: float = float(snap["pit"]) + float(snap["hold"]) + float(snap["dock"])
	check(near(kept, total), "loads in flight go back to their piles (%f vs %f)" % [kept, total])
	check(gs.cycle_progress("lift") < 0.0, "the restored world starts idle")


## Builds two automated worlds (ocean active) and returns the ocean snapshot
## to reuse.
func _two_automated() -> Dictionary:
	_fresh()
	_automate()
	_open_next()
	_automate()
	gs.switch_location(0)
	return (gs.worlds_runs["1"] as Dictionary).duplicate(true)


func _away_pay(snap: Dictionary, seconds: float) -> float:
	var s := snap.duplicate(true)
	s["left_at"] = gs.now() - seconds
	s["coins"] = 0.0
	gs.worlds_runs["1"] = s
	gs.switch_location(1)
	var paid: float = gs.take_away_report().get("coins", 0.0)
	gs.switch_location(0)
	return paid


func test_away_cap() -> void:
	var snap := _two_automated()
	var hour := _away_pay(snap, 3600.0)
	check(hour > 0.0, "an automated world earns while away (%f)" % hour)
	var cap := _away_pay(snap, Balance.OFFLINE_CAP_SEC)
	var past := _away_pay(snap, Balance.OFFLINE_CAP_SEC * 5.0)
	check(near(cap, past, 0.001), "away time is capped (%f vs %f)" % [cap, past])
	check(cap > hour, "more time, more coins (up to the cap)")
	var s := snap.duplicate(true)
	s["left_at"] = gs.now() - Balance.OFFLINE_CAP_SEC * 5.0
	gs.worlds_runs["1"] = s
	gs.switch_location(1)
	check(near(float(gs.take_away_report()["seconds"]), Balance.OFFLINE_CAP_SEC), "reported seconds are capped")
	gs.switch_location(0)
	# Nothing automated: nothing earned.
	var manual := snap.duplicate(true)
	var mg: Dictionary = manual["managers"]
	for k in ["lift", "boat", "plant", "boat2", "plant2"]:
		mg[k] = false
	check(_away_pay(manual, 3600.0) == 0.0, "manual parts don't earn while away")
	var quick := _away_pay(snap, 0.0)
	check(quick == 0.0, "an instant return pays nothing")


func test_away_no_boost_no_rush() -> void:
	var snap := _two_automated()
	var plain := _away_pay(snap, 1800.0)
	gs.boost_end = gs.now() + 3600.0
	var boosted := _away_pay(snap, 1800.0)
	check(near(plain, boosted, 0.001), "the x2 boost is not counted twice for a waiting world (%f vs %f)" % [plain, boosted])
	check(gs.boost_left > 3000.0, "the boost keeps running for the world being played")
	gs.boost_end = 0.0
	gs.rush_left = 3.0
	gs.rush_meter = 0.7
	gs.switch_location(1)
	check(gs.rush_left == 0.0 and gs.rush_meter == 0.0, "rush does not carry over")
	gs.switch_location(0)


## Ten quick switches over ten minutes pay no more than ten minutes away.
func test_rapid_switching() -> void:
	var snap := _two_automated()
	var once := _away_pay(snap, 600.0)
	var s := snap.duplicate(true)
	s["coins"] = 0.0
	var total := 0.0
	for i in 10:
		s["left_at"] = gs.now() - 60.0
		gs.worlds_runs["1"] = s
		var before: float = s["coins"]
		gs.switch_location(1)
		gs.take_away_report()
		total += gs.coins - before
		gs.switch_location(0)
		s = gs.worlds_runs["1"]
	check(total <= once * 1.001 + 1.0, "quick switching never beats staying (%f vs %f)" % [total, once])
	check(total >= once * 0.9, "and pays about the same time (%f vs %f)" % [total, once])
	# Back and forth with no time passing: nothing at all.
	var c0: float = gs.coins
	var c1: float = gs.world_coins(1)
	for i in 20:
		gs.switch_location(1)
		gs.switch_location(0)
	check(gs.coins <= c0 + 1.0 and gs.world_coins(1) <= c1 + 1.0, "ping-pong pays nothing")


func test_save_load() -> void:
	_fresh()
	_open_next()
	gs.levels["d0"] = 21
	_open_next()
	gs.levels["d0"] = 42
	gs.coins = 777.0
	gs.switch_location(1)
	gs.coins = 555.0
	gs.evo = 2
	check(gs.save_game(), "saved")
	gs.reset()
	check(gs.max_location == 0 and gs.worlds_runs.is_empty(), "reset clears the worlds")
	check(gs.load_game(), "loaded")
	check(gs.location == 1 and gs.max_location == 2, "location and max loaded")
	check(gs.worlds_runs.has("0") and gs.worlds_runs.has("2") and not gs.worlds_runs.has("1"), "snapshots loaded")
	check(gs.evo == 2 and gs.coins >= 555.0, "active run loaded")
	check(gs.switch_location(2), "switch after load")
	check(gs.get_level("d0") == 42 and gs.coins >= 777.0 and gs.coins < 778.0, "moon-side run restored from the save")
	check(gs.switch_location(0) and gs.get_level("d9") >= 1, "ocean restored from the save")
	# A broken snapshot in the file is cleaned up, never crashes.
	gs.worlds_runs["2"] = {"coins": "lots", "levels": [1, 2], "gear": 99}
	gs.save_game()
	gs.load_game()
	check(gs.switch_location(2), "switch to a broken snapshot")
	check(gs.coins == 0.0 and gs.evo == Balance.EVO_FORMS and gs.get_level("d0") == 1, "broken values fall back safely")


func test_migration() -> void:
	_fresh()
	# A 3.1 save (no max_location, no worlds_runs) at location 2.
	var lv := {}
	var mg := {}
	for key in gs.stage_keys():
		lv[key] = 3
		mg[key] = true
	var data := {"version": 4, "saved_at": gs.now(), "coins": 5000.0, "location": 2, "gear": 1,
			"levels": lv, "managers": mg, "pit": 0.0, "hold": 0.0, "dock": 0.0, "boost_end": 0.0}
	var f := FileAccess.open(GAME_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(gs.load_game(), "old save loads")
	check(gs.location == 2 and gs.max_location == 2, "max_location = location")
	check(gs.worlds_runs.is_empty(), "no snapshots for the older worlds")
	check(gs.is_opened(0) and gs.is_opened(1) and not gs.is_opened(3), "earlier worlds count as opened")
	check(gs.switch_location(0), "switch to an older world without a snapshot")
	check(gs.coins == 0.0 and gs.get_level("d0") == 1 and gs.get_level("d1") == 0 and gs.evo == 0, "it starts a fresh run")
	check(gs.has_manager("lift") and gs.has_manager("boat") and gs.has_manager("plant") and gs.has_manager("vault"), "with its automation hired")
	check(gs.take_away_report().get("coins", 0.0) == 0.0, "no away income without a snapshot")
	check(not gs.can_advance_location(), "and no gate there")
	check(gs.switch_location(2), "back to the newest world")
	check(gs.get_level("d5") == 3 and gs.evo == 1 and gs.coins >= 5000.0, "newest world's run intact")


func test_quests_per_world() -> void:
	_fresh()
	pr.features["quests"] = true
	pr._fill_quests()
	check(pr.quests.size() == Content.QUEST_SLOTS, "quests filled")
	var q0: Array = pr.quests.duplicate(true)
	check(pr.quest_loc == 0, "quests belong to the ocean")
	_open_next()
	check(pr.quest_loc == 1, "the new world has its own quests")
	check(pr.world_quests.has("0") and pr.world_quests["0"] == q0, "ocean quests wait")
	check(pr.quests.size() == Content.QUEST_SLOTS, "volcano quests filled")
	var q1: Array = pr.quests.duplicate(true)
	gs.switch_location(0)
	check(pr.quests == q0, "switching back brings the ocean quests")
	check(pr.world_quests.get("1") == q1, "volcano quests wait")
	# Progress counts only for the active world's quests.
	pr.quests[0] = {"kind": "tap", "key": "", "goal": 50.0, "count": 0.0, "pearls": 2}
	(pr.world_quests["1"] as Array)[0] = {"kind": "tap", "key": "", "goal": 50.0, "count": 0.0, "pearls": 2}
	pr._count("tap", 3)
	check(float(pr.quests[0]["count"]) == 3.0, "active world's quest counts")
	check(float((pr.world_quests["1"] as Array)[0]["count"]) == 0.0, "waiting world's quest does not")
	gs.switch_location(1)
	check(float(pr.quests[0]["count"]) == 0.0, "volcano tap quest untouched")
	# Earn goals fit the world's economy: same levels, bigger world, bigger goal.
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
	var e1: float = pr.coins_for_minutes(2.0)
	gs.switch_location(0)
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, mini(gs.levels[key], 1))
	var e0: float = pr.coins_for_minutes(2.0)
	check(e1 > e0 * 2.0, "rewards and goals scale with the world (%f vs %f)" % [e1, e0])


func test_quest_save() -> void:
	_fresh()
	pr.features["quests"] = true
	pr._fill_quests()
	_open_next()
	var q1: Array = pr.quests.duplicate(true)
	var q0: Array = (pr.world_quests["0"] as Array).duplicate(true)
	pr.save_game()
	gs.save_game()
	pr.reset()
	check(pr.load_game(), "progress loaded")
	check(pr.quest_loc == 1 and pr.quests.size() == q1.size(), "active quests loaded")
	check(pr.world_quests.has("0") and (pr.world_quests["0"] as Array).size() == q0.size(), "waiting quests loaded")
	# An old progress save (one list, no quest_loc): it goes to the active world.
	var f := FileAccess.open(PROGRESS_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "quests": [{"kind": "tap", "key": "", "goal": 40, "count": 5, "pearls": 2}]}))
	f.close()
	pr.reset()
	check(pr.load_game(), "old progress loads")
	check(pr.quest_loc == gs.location and pr.quests.size() == 1 and pr.quests[0]["kind"] == "tap", "old quests go to the active world")
	check(pr.world_quests.is_empty(), "no other world's quests")
	# Saved for another world than the game's active one: they swap in place.
	f = FileAccess.open(PROGRESS_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "quest_loc": 0, "quests": [{"kind": "tap", "key": "", "goal": 40, "count": 5, "pearls": 2}],
			"world_quests": {"1": [{"kind": "upgrade", "key": "", "goal": 9, "count": 1, "pearls": 2}]}}))
	f.close()
	pr.reset()
	pr.load_game()
	check(gs.location == 1 and pr.quest_loc == 1 and pr.quests.size() >= 1 and pr.quests[0]["kind"] == "upgrade", "mismatched save swaps to the active world")
	check((pr.world_quests["0"] as Array)[0]["kind"] == "tap", "the other list waits")


func test_mine_quest() -> void:
	_fresh()
	pr.features["quests"] = true
	gs.levels["d1"] = 1
	gs.levels["d2"] = 1
	var mine := {}
	for i in 400:
		pr.quests = []
		var q: Dictionary = pr._new_quest()
		if q["kind"] == "mine":
			mine = q
			break
	check(not mine.is_empty(), "a world-flavoured mine quest shows up")
	if mine.is_empty():
		return
	check(gs.is_open(mine["key"]) and gs.depth_index(mine["key"]) >= 0, "it names an open site of this world")
	check(float(mine["goal"]) >= 5.0, "goal at least 5")
	pr.quests = [mine]
	gs.cycle_finished.emit(mine["key"], 1.0)
	gs.cycle_finished.emit("lift", 1.0)
	check(float(pr.quests[0]["count"]) == 1.0, "a finished trip at that site counts once")
	var other := "d0" if mine["key"] != "d0" else "d1"
	gs.cycle_finished.emit(other, 1.0)
	check(float(pr.quests[0]["count"]) == 1.0, "other sites don't count")
	check("mine" in Content.QUEST_KINDS, "mine is a known quest kind (kept on load)")
