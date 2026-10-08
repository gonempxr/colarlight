extends SceneTree
## Screenshots of switching worlds (needs a real renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/switch_shot.gd -- /path/prefix ru
## Writes <prefix>_map_here.png (map in the newest world), _map_go.png (the
## ocean picked: "Go to"), _quests_volcano.png, _switched.png (right after
## the switch), _away.png (what the helpers earned), _quests_ocean.png and _map_old.png (map from an older world).

func _shot(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "user://switch"
	var lang := args[1] if args.size() > 1 else "ru"
	await process_frame
	root.get_node("Settings").language = lang
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://switch_shot_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://switch_shot_progress.json"
	pr.reset()
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	pr.pearls = 120
	# The ocean: finished and automated, then the volcano opens.
	for key in gs.stage_keys():
		gs.levels[key] = 25
		gs.managers[key] = true
	gs.managers["vault"] = true
	gs.evo = 2
	pr._fill_quests()
	pr.quests[0]["count"] = pr.quests[0]["goal"]
	gs.coins = gs.next_location_cost() * 1.2
	gs.advance_location()
	# Leave the ocean waiting for 2 hours.
	(gs.worlds_runs["0"] as Dictionary)["left_at"] = gs.now() - 7200.0
	gs.levels.merge({"d0": 30, "d1": 22, "d2": 9, "lift": 30, "boat": 32, "plant": 30}, true)
	gs.managers["d0"] = true
	gs.coins = 3.4e6
	pr.quests = []
	pr._fill_quests()
	pr.quests[1] = pr._new_quest()
	for i in 60:
		var q: Dictionary = pr._new_quest()
		if q["kind"] == "mine":
			pr.quests[2] = q
			break
	pr.quests[2]["count"] = floorf(float(pr.quests[2]["goal"]) * 0.4)
	pr.apply_bonus()
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.2).timeout
	var main := current_scene
	main.open_map()
	await create_timer(1.0).timeout
	await _shot(prefix + "_map_here.png")
	var v = main._map
	var at: Vector2 = (v._pos[0] as Vector2) * v._zoom + v._pan
	v._tap(at)
	await create_timer(1.0).timeout
	await _shot(prefix + "_map_go.png")
	v.close()
	main.open_feature("quests")
	await create_timer(0.8).timeout
	await _shot(prefix + "_quests_volcano.png")
	main._modal.close()
	await create_timer(0.4).timeout
	main.open_map()
	v._tap((v._pos[0] as Vector2) * v._zoom + v._pan)
	await create_timer(0.3).timeout
	v._do_switch(0)
	await create_timer(1.4).timeout
	await _shot(prefix + "_switched.png")
	await create_timer(3.7).timeout
	await _shot(prefix + "_away.png")
	await create_timer(3.0).timeout
	main.open_feature("quests")
	await create_timer(0.8).timeout
	await _shot(prefix + "_quests_ocean.png")
	main._modal.close()
	await create_timer(0.4).timeout
	main.open_map()
	await create_timer(1.0).timeout
	await _shot(prefix + "_map_old.png")
	quit()
