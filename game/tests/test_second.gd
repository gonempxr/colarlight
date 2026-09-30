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
	var coins_before: float = gs.coins
	for i in 200:
		gs.advance(0.1)
	check(gs.hold < 1e6, "boats took ore from the raft")
	check(gs.coins > coins_before, "plants turned it into coins")
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
	# Dive Deeper closes them again but keeps their managers (automation).
	gs.prestige_count = 0
	gs.levels["d5"] = 1
	gs.coins = 1e12
	check(gs.prestige(), "dive deeper")
	check(not gs.is_open("boat2") and gs.has_manager("boat2"), "closed after a dive, captain kept")

	# UI.
	gs.reset()
	gs.coins = 1e9
	gs.levels["d1"] = 1
	gs.levels["d2"] = 1
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	main._refresh()
	await process_frame
	var card = main.stage_card("boat")
	check(card._unit_btns[1].visible, "the boat card shows 1 | 2 once the second boat is for sale")
	card._select_unit(1)
	check(card.key == "boat2" and card._upgrade.text.find("Buy") >= 0, "tab 2 shows the price")
	card._on_upgrade()
	check(gs.is_open("boat2"), "the card's button buys the second boat")
	check(card._level.text.find("1") >= 0, "then the card shows its level")
	main._on_stage_selected("plant2")
	await process_frame
	check(main._panel.key == "plant2" and main._panel._buy.text.find("Buy") >= 0, "panel offers to buy the second plant")
	main._panel._on_buy()
	check(gs.is_open("plant2"), "panel buys it")
	check(main.stage_card("plant").key == "plant2", "the plant card follows the panel")
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_second_save.json")
	quit(1 if _failures > 0 else 0)
