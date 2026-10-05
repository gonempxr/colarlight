extends SceneTree
## The lift: divers -> crates (pit) -> lift -> raft (hold). Manual vs its
## operator, time away, Dive Deeper, save/load, saves from before the lift,
## the tutorial remap, and the lift in the world, its card and the panel.
##   godot --headless --path . --resolution 390x844 -s res://tests/test_lift.gd

const TEST_SAVE := "user://test_lift.json"

var _script: GDScript
var _failures := 0
var _checks := 0


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _fresh() -> Node:
	var gs: Node = _script.new()
	gs.save_path = TEST_SAVE
	gs.autosave_enabled = false
	gs.reset()
	DirAccess.remove_absolute(TEST_SAVE)
	return gs


func _initialize() -> void:
	# Let the autoloads load their own saves first, then take them over.
	await process_frame
	_script = load("res://scripts/autoload/game_state.gd")
	test_flow()
	test_manual_vs_operator()
	test_capacity_and_trip_time()
	test_offline()
	test_prestige()
	test_save_load()
	test_old_save_migration()
	test_tutorial_remap()
	await test_ui()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute(TEST_SAVE)
	quit(1 if _failures > 0 else 0)


func test_flow() -> void:
	var gs := _fresh()
	check(gs.is_open("lift") and gs.get_level("lift") == 1, "the lift starts open at level 1")
	check("lift" in gs.stage_keys(), "lift is a stage")
	check(gs.stage_keys().find("lift") < gs.stage_keys().find("boat"), "the lift runs before the boat each tick")
	gs.managers["d0"] = true
	gs.advance(gs.cycle_time("d0") + 0.01)
	var dug: float = gs.pit
	check(dug > 0.0 and gs.hold == 0.0, "a dive fills the crates, not the raft")
	check(gs.cycle_progress("lift") < 0.0, "the lift waits for a tap")
	var started := []
	gs.cycle_started.connect(func(k, a): if k == "lift": started.append(a))
	check(gs.tap("lift"), "a tap sends the lift")
	check(started.size() == 1 and near(started[0], minf(dug, gs.cycle_capacity("lift"))), "a trip takes what waits, up to its capacity")
	check(gs.lift_trip_depth == 0, "the trip goes down to the deepest open depth")
	var pit_after: float = gs.pit
	gs.advance(gs.cycle_time("lift") * 0.5)
	check(gs.hold == 0.0, "nothing arrives before the trip ends")
	gs.advance(gs.cycle_time("lift") * 0.5 + 0.001)
	check(near(gs.hold, float(started[0])), "the trip unloads on the raft")
	check(gs.pit >= pit_after, "divers keep filling the crates meanwhile")
	check(gs.lift_trip_depth == -1, "trip over")
	gs.free()


func test_manual_vs_operator() -> void:
	var gs := _fresh()
	gs.pit = 1e6
	check(not gs.is_auto("lift"), "no operator: manual")
	check(gs.tap("lift"), "one trip per tap")
	gs.advance(gs.cycle_time("lift") * 3.0)
	check(gs.cycle_progress("lift") < 0.0, "a manual lift stops after its trip")
	var one: float = gs.hold
	check(near(one, gs.cycle_capacity("lift")), "one full trip")
	# Tapping a running lift pushes it forward.
	gs.tap("lift")
	gs.tap("lift")
	check(gs.cycle_progress("lift") >= Balance.TAP_BOOST * 0.99, "taps push the running trip")
	gs.coins = Balance.LIFT["manager"]
	check(gs.hire_manager("lift") and gs.coins == 0.0, "hire the operator")
	check(gs.is_auto("lift"), "the operator runs it")
	var t: float = gs.cycle_time("lift")
	gs.advance(t * 4.0 + 0.01)
	check(gs.hold > one + gs.cycle_capacity("lift") * 3.0, "trips go on by themselves")
	# An empty pit: the operator waits and leaves as soon as ore comes.
	var gs2 := _fresh()
	gs2.managers["lift"] = true
	gs2.advance(10.0)
	check(gs2.cycle_progress("lift") >= 0.0 or gs2.hold > 0.0, "the operator takes the divers' ore up")
	gs2.pit = 0.0
	gs2.levels["d0"] = 0
	gs2.levels["d0"] = 1
	var gs3 := _fresh()
	gs3.managers["lift"] = true
	gs3.advance(0.5)
	check(gs3.cycle_progress("lift") < 0.0 and not gs3.tap("lift"), "no ore waiting: the lift stays up")
	gs.free()
	gs2.free()
	gs3.free()


func test_capacity_and_trip_time() -> void:
	var gs := _fresh()
	var t0: float = gs.cycle_time("lift")
	check(near(t0, Balance.LIFT["cycle"]), "a trip to the first depth")
	gs.levels["d1"] = 1
	gs.levels["d2"] = 1
	check(near(gs.cycle_time("lift"), Balance.LIFT["cycle"] + 2.0 * Balance.LIFT["cycle_step"]), "deeper shafts, longer trips")
	check(near(gs.cycle_capacity("lift"), gs.rate("lift") * gs.cycle_time("lift")), "a trip carries rate x time")
	# Opening a depth mid-trip does not change the running trip.
	gs.levels["d2"] = 0
	gs.pit = 100.0
	gs.tap("lift")
	gs.advance(1.0)
	var p: float = gs.cycle_progress("lift")
	gs.levels["d2"] = 1
	check(near(gs.cycle_progress("lift"), p), "the running trip keeps its depth")
	# The bottleneck and the income.
	for k in gs.stage_keys():
		gs.managers[k] = gs.is_open(k)
	gs.levels["d0"] = 200
	gs.levels["boat"] = 300
	gs.levels["plant"] = 300
	check(gs.bottleneck() == "lift", "a weak lift is the bottleneck")
	check(near(gs.income_rate(), gs.lift_rate()), "and limits income")
	gs.levels["lift"] = 400
	check(gs.bottleneck() != "lift", "upgrading it moves the bottleneck")
	check(Balance.lift_look(1) == 1 and Balance.lift_look(10) == 2 and Balance.lift_look(250) == Balance.LIFT_LOOKS.size(), "looks at the level milestones")
	gs.coins = 1e9
	gs.levels["lift"] = 8
	gs.upgrade("lift", 4)
	check(gs.upgraded_from.get("lift") == 8 and gs.get_level("lift") == 12, "the level before an upgrade is kept (for the new-look toast)")
	gs.free()


func test_offline() -> void:
	var gs := _fresh()
	for k in ["d0", "boat", "plant"]:
		gs.managers[k] = true
	gs.levels["d0"] = 20
	gs.levels["boat"] = 30
	gs.levels["plant"] = 30
	gs.levels["lift"] = 30
	check(gs.simulate_offline(600.0) == 0.0, "no operator: nothing comes up while away")
	check(gs.pit > 0.0 and gs.hold == 0.0, "the ore waits in the crates")
	gs.pit = 0.0
	gs.managers["lift"] = true
	var earned: float = gs.simulate_offline(3600.0)
	check(absf(earned - gs.income_rate() * 3600.0) < gs.income_rate() * 5.0, "with the operator: income_rate per second")
	gs.levels["lift"] = 2
	gs.pit = 0.0
	gs.hold = 0.0
	gs.dock = 0.0
	var slow: float = gs.simulate_offline(3600.0)
	check(near(slow, gs.lift_rate() * 3600.0, 0.01) and gs.pit > 0.0, "a weak lift limits time away too (%.1f vs %.1f)" % [slow, gs.lift_rate() * 3600.0])
	gs.free()


func test_prestige() -> void:
	var gs := _fresh()
	gs.coins = 1e12
	gs.levels["lift"] = 120
	check(gs.hire_manager("lift"), "operator hired")
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
		gs.managers[key] = true
	gs.pit = 500.0
	check(gs.advance_location(), "next location")
	check(gs.get_level("lift") == 1, "the lift starts again at level 1")
	check(gs.has_manager("lift"), "and keeps its operator")
	check(gs.pit == 0.0, "the crates are emptied")
	gs.free()


func test_save_load() -> void:
	var gs := _fresh()
	gs.levels["lift"] = 23
	gs.managers["lift"] = true
	gs.pit = 77.0
	gs.hold = 5.0
	check(gs.save_game(), "save")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	check(data.has("pit") and data["levels"].has("lift"), "the save has the lift and the pit")
	gs.free()
	var loaded := _fresh_no_delete()
	check(loaded.load_game(), "load")
	check(loaded.get_level("lift") == 23 and loaded.has_manager("lift"), "lift level and operator restored")
	check(loaded.pit >= 0.0 and loaded.pit + loaded.hold >= 77.0, "the pit is restored (the operator may have moved some up)")
	loaded.free()
	# A broken level can't close the lift.
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": {"d0": 3, "lift": -4, "boat": 2, "plant": 2}, "pit": -3, "managers": {}}))
	f.close()
	var broken := _fresh_no_delete()
	check(broken.load_game(), "load broken")
	check(broken.get_level("lift") == 1 and broken.pit == 0.0, "lift never below level 1, pit never negative")
	broken.free()
	DirAccess.remove_absolute(TEST_SAVE)


func _fresh_no_delete() -> Node:
	var gs: Node = _script.new()
	gs.save_path = TEST_SAVE
	gs.autosave_enabled = false
	gs.reset()
	return gs


## A save from before the lift (no "lift", no "pit") must not crash or stall.
func test_old_save_migration() -> void:
	for case in [
		{"levels": {"d0": 34, "d1": 27, "d2": 12, "boat": 45, "plant": 41}, "managers": {"d0": true, "boat": true, "plant": true}, "prestige": 0},
		{"levels": {"d0": 150, "d1": 120, "d2": 100, "d3": 80, "d4": 60, "d5": 40, "boat": 300, "plant": 300, "boat2": 120, "plant2": 110}, "managers": {"boat": true, "plant": true, "boat2": true}, "prestige": 3},
		{"levels": {"d0": 5, "boat": 3, "plant": 2}, "managers": {}, "prestige": 0},
	]:
		var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": 2, "saved_at": Time.get_unix_time_from_system(), "coins": 500.0,
				"prestige_count": case["prestige"], "levels": case["levels"], "managers": case["managers"], "hold": 40.0, "dock": 3.0}))
		f.close()
		var gs := _fresh_no_delete()
		check(gs.load_game(), "old save loads")
		var chain: float = minf(gs.dives_rate(), minf(gs.boats_rate(), gs.plants_rate()))
		check(gs.get_level("lift") >= 1 and gs.lift_rate() >= chain, "lift opened fast enough for the old chain (lv %d, %.4f vs %.4f)" % [gs.get_level("lift"), gs.lift_rate(), chain])
		check(gs.bottleneck() != "lift", "the lift is not the new bottleneck")
		check(gs.lift_rate() < chain * 3.0 or gs.get_level("lift") == 1, "and not given away much stronger than needed")
		check(gs.has_manager("lift") == bool(case["managers"].get("boat", false)), "operator only if the boat had a captain")
		check(gs.hold >= 39.99, "old ore stays on the raft (%.2f, %.2f)" % [gs.hold, gs.pit])
		# It keeps flowing: the old chain earns about as before.
		for k in gs.stage_keys():
			if gs.is_open(k) and gs.depth_index(k) >= 0:
				gs.managers[k] = true
		if gs.has_manager("lift"):
			gs.managers["plant"] = true
			gs.managers["vault"] = true
			var before: float = gs.coins
			for i in 900:
				gs.advance(0.1)
			var start: float = gs.coins
			for i in 600:
				gs.advance(0.1)
			var per_sec: float = (gs.coins - start) / 60.0
			check(per_sec > gs.income_rate() * 0.8, "migrated chain keeps earning (%.4f vs %.4f)" % [per_sec, gs.income_rate()])
			check(gs.coins > before, "coins grow")
		gs.free()
	DirAccess.remove_absolute(TEST_SAVE)


func test_tutorial_remap() -> void:
	var pr: Node = root.get_node("Progress")
	var path: String = pr.save_path
	pr.save_path = "user://test_lift_progress.json"
	var tutor: GDScript = load("res://scripts/ui/tutor.gd")
	var old_done := 7
	# A finished v1 tutorial lands on the first step of the rooms (9: the
	# accountant, the evolution and the map come next).
	for pair in [[0, 0], [1, 1], [2, 1], [4, 5], [5, 7], [6, 8], [old_done, 9]]:
		var f := FileAccess.open(pr.save_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": 1, "tutorial_step": pair[0]}))
		f.close()
		pr.reset()
		pr.load_game()
		check(pr.tutorial_step == pair[1], "old tutorial step %d -> %d (got %d)" % [pair[0], pair[1], pr.tutorial_step])
	pr.tutorial_step = 3
	pr.save_game()
	pr.reset()
	pr.load_game()
	check(pr.tutorial_step == 3, "new saves keep their step")
	check(tutor.STEPS.size() == tutor.DONE and "tap_lift" in tutor.STEPS and "hire_lift" in tutor.STEPS, "the tutorial teaches the lift")
	DirAccess.remove_absolute(pr.save_path)
	pr.save_path = path
	pr.reset()


func test_ui() -> void:
	var gs: Node = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_lift_ui.json"
	gs.reset()
	var pr: Node = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://test_lift_ui_progress.json"
	pr.reset()
	pr.tutorial_step = 0
	pr.daily_last = pr.today()
	gs._offline_report = {}
	gs.bonus = {}
	root.get_node("Settings").language = "en"
	TranslationServer.set_locale("en")
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 8:
		await process_frame
	var main = current_scene
	var world = main._world
	var lift = world.lift
	check(lift != null and main.stage_card("lift") == lift.card, "the lift and its card are in the world")
	# Phone: the lift's card joins the boat and plant cards in the sky row.
	var lift_r: Rect2 = lift.card.get_rect()
	var boat_r: Rect2 = world.surface.boat_card.get_rect()
	var plant_r: Rect2 = world.surface.plant_card.get_rect()
	check(lift.card.visible and is_equal_approx(lift_r.position.y, boat_r.position.y), "the lift card is in the card row (%s vs %s)" % [lift_r, boat_r])
	check(lift_r.end.x <= boat_r.position.x - 8.0 and not lift_r.intersects(plant_r), "it sits left of the boat card, overlapping none (%s %s)" % [lift_r, boat_r])
	check(lift_r.size.x >= lift.CARD_MIN_W, "it is wide enough (%.0f)" % lift_r.size.x)
	var bulb: Rect2 = main._hint_btn.get_global_rect()
	check(not lift.card.get_global_rect().intersects(bulb), "it leaves the hint bulb clear")
	check(lift_r.end.y < world.SURFACE_Y - 150.0, "it stays in the sky, above the raft's crew (%.0f)" % lift_r.end.y)
	check(absf(lift_r.size.y - boat_r.size.y) < 12.0, "as tall as the boat card (%.0f vs %.0f)" % [lift_r.size.y, boat_r.size.y])
	check(lift.card._name.text.find("★1") >= 0, "the card shows the lift's look (%s)" % lift.card._name.text)
	for row in world.rows:
		if row.card.visible:
			check(not lift_r.intersects(Rect2(row.position + row.card.position, row.card.size)), "the lift card covers no depth card")
	# The tutorial walks through the lift: divers, lift, boat, plant.
	gs.tap("d0")
	gs.advance(gs.cycle_time("d0") + 0.05)
	for i in 3:
		gs.tap("d0")
	await process_frame
	check(pr.tutorial_step == 1, "after tapping the divers: the lift step (%d)" % pr.tutorial_step)
	await process_frame
	await process_frame
	check(main._tutor._has_target, "the hand points at the lift (pit %.2f, lift %.2f, busy %s, modal %s)" % [gs.pit, gs.cycle_progress("lift"), main.is_busy(), main._modal.visible])
	var sheet_before: bool = main._sheet_open
	lift.tap()
	check(pr.tutorial_step == 2, "tapping the lift completes the step")
	check(main._sheet_open == sheet_before, "a hand-run lift tap does not cover the phone screen")
	for i in 60:
		gs.advance(0.1)
		await process_frame
	check(gs.hold > 0.0, "the lift brought the ore up")
	await process_frame
	check(main._tutor._has_target, "then the hand points at the boat (hold %.2f, boat %.2f, busy %s, step %d)" % [gs.hold, gs.cycle_progress("boat"), main.is_busy(), pr.tutorial_step])
	# Crates follow the pit.
	gs.pit = 0.0
	gs.managers["d0"] = true
	for i in 30:
		gs.advance(0.2)
		await process_frame
	await create_timer(0.6).timeout
	var shown := 0.0
	for c in lift._crates:
		shown += c
	check(absf(shown - gs.pit) <= maxf(0.5, gs.pit * 0.05), "the crates show the waiting ore (%.2f vs %.2f)" % [shown, gs.pit])
	# The hint bulb teaches the lift when ore piles up and nobody sends it.
	pr.tutorial_step = tutor_done()
	pr.daily_last = pr.today()
	gs.coins = 0.0
	gs.pit = 50.0
	gs.hold = 0.0
	gs.dock = 0.0
	gs._timer["lift"] = -1.0
	var h: Dictionary = load("res://scripts/ui/hints.gd").pick(main)
	check(h["id"] == "tap_lift", "hint: tap the lift (%s)" % h["id"])
	gs.coins = Balance.LIFT["manager"]
	h = load("res://scripts/ui/hints.gd").pick(main)
	check(h["id"] == "hire_lift", "hint: hire its operator (%s)" % h["id"])
	check((h["point"] as Callable).call() != null, "the hint points at the lift card's portrait")
	# The panel for the lift: stats and the hire button.
	main._on_stage_selected("lift")
	await process_frame
	var panel = main._panel
	check(panel.key == "lift" and panel._title.text.begins_with("Lift"), "panel shows the lift (%s)" % panel._title.text)
	check(panel._stats.text.find("Per trip") >= 0 and panel._stats.text.find("Waiting") >= 0, "panel: capacity, trip time and waiting ore")
	check(panel._hire.visible, "panel offers the operator")
	panel._on_hire()
	check(gs.has_manager("lift") and not panel._hire.visible, "hired from the panel")
	main._close_sheet()
	await create_timer(0.4).timeout
	# The card's button opens the panel; its level follows upgrades.
	lift.card._upgrade.pressed.emit()
	await process_frame
	check(main._sheet_open and main._panel.key == "lift", "the card's button opens the lift in the panel")
	main._close_sheet()
	await create_timer(0.4).timeout
	gs.coins = 1e6
	check(gs.upgrade("lift", 9), "upgrade to 10")
	main._refresh()
	check(lift.card._level.text.find("10") >= 0 and lift.card._name.text.find("★2") >= 0, "card shows the level and the new look (%s)" % lift.card._name.text)
	await process_frame
	check(lift.look() == 2, "the lift's look changed")
	DirAccess.remove_absolute("user://test_lift_ui.json")
	DirAccess.remove_absolute("user://test_lift_ui_progress.json")


func tutor_done() -> int:
	return load("res://scripts/ui/tutor.gd").DONE
