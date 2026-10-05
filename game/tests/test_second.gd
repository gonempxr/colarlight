extends SceneTree
## The second boat and plant: buying, sharing the ore flow, cards and panel.
##   godot --headless --path . --resolution 390x844 -s res://tests/test_second.gd

var _failures := 0
var _checks := 0


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_second_save.json"
	gs.reset()
	var progress := root.get_node("Progress")
	progress.autosave_enabled = false
	progress.save_path = "user://test_second_progress.json"
	progress.reset()
	TranslationServer.set_locale("en")

	# Economy.
	check(not gs.is_open("boat2") and not gs.is_open("plant2"), "second boat and plant start closed")
	check(gs.boats_rate() == gs.rate("boat"), "a closed second boat adds nothing")
	gs.coins = gs.unlock_cost("boat2") - 1.0
	check(not gs.open_building("boat2"), "can't buy without the coins")
	gs.coins = 1e9
	check(gs.open_building("boat2") and gs.open_building("plant2"), "buy both")
	check(not gs.open_building("boat2"), "can't buy twice")
	check(not gs.open_building("d3"), "open_building is only for the second boat/plant")
	check(gs.get_level("boat2") == 1, "bought at level 1")
	check(gs.boats_rate() > gs.rate("boat"), "two boats carry more")
	check(gs.upgrade("boat2") and gs.get_level("boat2") == 2, "second boat upgrades")
	# Both boats move ore from the same raft to the same shore.
	gs.managers["boat"] = true
	gs.managers["boat2"] = true
	gs.managers["plant"] = true
	gs.managers["plant2"] = true
	gs.hold = 1e6
	gs.dock = 0.0
	var coins_before: float = gs.coins + gs.vault
	for i in 200:
		gs.advance(0.1)
	check(gs.hold < 1e6, "boats took ore from the raft")
	check(gs.coins + gs.vault > coins_before, "plants turned it into coins (in the vault)")
	# Offline counts both.
	gs.hold = 1e9
	gs.dock = 0.0
	var off: float = gs.simulate_offline(60.0)
	var expect: float = minf(gs.boats_rate(), gs.plants_rate()) * 60.0
	check(off > expect * 0.8, "offline uses both boats and both plants")
	# Save/load keeps them; a broken value can't open them.
	gs.save_game()
	gs.reset()
	check(not gs.is_open("boat2"), "reset closes them")
	gs.load_game()
	check(gs.get_level("boat2") == 2 and gs.is_open("plant2"), "save keeps them")
	# The next location closes them again but keeps their managers (automation).
	gs.location = 0
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
		gs.managers[key] = true
	gs.coins = 1e12
	check(gs.advance_location(), "next location")
	check(not gs.is_open("boat2") and gs.has_manager("boat2"), "closed in the next location, captain kept")

	# UI.
	gs.reset()
	gs.coins = 1e9
	gs.levels["d1"] = 1
	gs.levels["d2"] = 1
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	main._refresh()
	await process_frame
	var card = main.stage_card("boat")
	check(card._unit_btns[1].visible, "the boat card shows 1 | 2 once the second boat is for sale")
	card._select_unit(1)
	check(card.key == "boat2" and card._upgrade.full_text.find("Buy") >= 0, "tab 2 shows the price")
	card._on_upgrade()
	check(gs.is_open("boat2"), "the card's button buys the second boat")
	check(card._level.text.find("1") >= 0, "then the card shows its level")
	main._on_stage_selected("plant2")
	await process_frame
	check(main._panel.key == "plant2" and main._panel._buy.full_text.find("Buy") >= 0, "panel offers to buy the second plant")
	main._panel._on_buy()
	check(gs.is_open("plant2"), "panel buys it")
	check(main.stage_card("plant").key == "plant2", "the plant card follows the panel")

	# Automating the second units must be obvious, and must work in play.
	await _automation(main, gs)
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_second_save.json")
	quit(1 if _failures > 0 else 0)


func _click(c: Control) -> void:
	var pos: Vector2 = root.get_final_transform() * c.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	root.push_input(down)
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up)
	await process_frame
	await process_frame


## Fresh run: buy the second boat and plant, see the cards switch to them,
## the red dots and the hint ask for their managers, hire them by tapping the
## portraits, then let the game run by itself and watch them work.
func _automation(main, gs: Node) -> void:
	main._close_sheet()
	gs.reset()
	gs.coins = 1e9
	gs.levels["d1"] = 1
	gs.levels["d2"] = 1
	for k in ["d0", "lift", "boat", "plant"]:
		gs.managers[k] = true
	root.get_node("Progress").daily_last = root.get_node("Progress").today()
	main._refresh()
	await process_frame
	var boat = main.stage_card("boat")
	var plant = main.stage_card("plant")
	boat.show_unit("boat")
	plant.show_unit("plant")
	check(gs.open_building("boat2"), "buy the second boat")
	await process_frame
	check(boat.key == "boat2", "after buying, the boat card switches to the new boat")
	check(gs.open_building("plant2"), "buy the second plant")
	await process_frame
	check(plant.key == "plant2", "after buying, the plant card switches to the new plant")
	# Back on tab 1: tab 2 wears a red dot while its manager is affordable.
	boat.show_unit("boat")
	main._refresh()
	check(boat._unit_dots[1].visible and not boat._unit_dots[0].visible, "a red dot on the second boat's tab")
	var money: float = gs.coins
	gs.coins = gs.manager_cost("boat2") - 1.0
	main._refresh()
	check(not boat._unit_dots[1].visible, "no dot while its manager is too dear")
	gs.coins = money
	main._refresh()
	var h: Dictionary = load("res://scripts/ui/hints.gd").pick(main)
	check(h["id"] == "hire_boat2", "the hint bulb asks for the second captain (%s)" % h["id"])
	(h["point"] as Callable).call()
	check(boat.key == "boat2", "the hint switches the card to the second boat")
	# The panel says it plainly too.
	main._on_stage_selected("plant2")
	await process_frame
	check(main._panel._hire.visible and main._panel._hire.full_text.find("Hire") >= 0, "the panel has a clear hire button (%s)" % main._panel._hire.full_text)
	main._close_sheet()
	await create_timer(0.4).timeout
	# Hire both by tapping their portraits on the cards.
	for card in [boat, plant]:
		var unit: String = card.base + "2"
		# The boat's card lives in the mine, the plant's in the factory.
		main.show_room(main.room_of(unit), false)
		await process_frame
		card.show_unit(unit)
		main._refresh()
		await process_frame
		var r: Rect2 = card._manager.get_global_rect()
		if not main.get_viewport_rect().has_point(r.get_center()):
			main.scroll_to_screen_point(r.get_center())
			await create_timer(0.8).timeout
		# A feature can unlock mid-test and pop its news over the cards.
		# Queued news can follow one another: close them all.
		for i in 6:
			var open := false
			for m in [main._modal, main._top]:
				if m.visible:
					open = true
					m.close()
			if not open:
				break
			await create_timer(0.5).timeout
		await _click(card._manager)
		check(gs.has_manager(unit), "tapping the empty portrait hires the %s manager" % unit)
		main._refresh()
		check(not card._unit_dots[1].visible, "the %s dot goes away" % unit)
	# Now nobody taps: the game loop runs and both second units must work.
	var done := {}
	var count := func(k: String, _amount: float) -> void: done[k] = done.get(k, 0) + 1
	gs.cycle_finished.connect(count)
	gs.hold = 1e5
	gs.dock = 1e5
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 20000 and (done.get("boat2", 0) < 2 or done.get("plant2", 0) < 2):
		await process_frame
	gs.cycle_finished.disconnect(count)
	check(done.get("boat2", 0) >= 2, "the second boat sails by itself (%d trips)" % done.get("boat2", 0))
	check(done.get("plant2", 0) >= 2, "the second plant works by itself (%d batches)" % done.get("plant2", 0))
