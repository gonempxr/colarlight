extends SceneTree
## Screenshot of the main screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/screenshot.gd -- out.png ru mid 0 [sheet]
## Args: output file, language, scenario (start|mid|late), scroll px,
## optional overlay ("-" for none), optional UI scale (1.0/1.12/1.25): sheet | title | avatar | settings | prestige | quests |
## daily | museum | wardrobe[:tab] | players | feature:<id> | chest | tutorial.
## Scenarios mid and late also open every meta feature and give pearls.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var lang := args[1] if args.size() > 1 else "ru"
	var scenario := args[2] if args.size() > 2 else "mid"
	var scroll := float(args[3]) if args.size() > 3 else 0.0
	var overlay: String = args[4] if args.size() > 4 else ""
	var ui_scale := float(args[5]) if args.size() > 5 else 1.0
	await process_frame
	root.get_node("Settings").language = lang
	root.get_node("Settings").ui_scale = ui_scale
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://screenshot_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://screenshot_progress.json"
	pr.reset()
	var profiles := root.get_node("Profiles")
	profiles.set_name_of(profiles.current_id, "Маша" if lang == "ru" else "Alex")
	if scenario != "start":
		for f in Content.FEATURES:
			pr.features[f] = true
		pr.fresh["puzzle"] = true
		pr.pearls = 135
		pr.pearls_total = 180
		pr.tutorial_step = 7
		pr.artifacts["compass"] = {"level": 2, "pieces": 1}
		pr.artifacts["bell_shell"] = {"level": 1, "pieces": 3}
		pr.artifacts["fish_idol"] = {"level": 0, "pieces": 2}
		pr.owned["pet_crab"] = true
		pr.owned["pet_octopus"] = true
		pr.owned["hat_cat_ears"] = true
		pr.equipped["pet"] = "pet_octopus"
		pr.stats["puzzles_won"] = 4
		pr.chest_ready = overlay == "chest"
		if overlay != "daily":
			pr.daily_last = pr.today()
		pr.apply_bonus()
		pr._fill_quests()
		pr.quests[0]["count"] = pr.quests[0]["goal"]
	match scenario:
		"mid":
			gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "boat": 45, "plant": 41}, true)
			for k in ["d0", "d1", "boat", "plant"]:
				gs.managers[k] = true
			gs.coins = 48250.0
			gs.hold = 1840.0
			gs.dock = 620.0
		"late":
			gs.levels.merge({"d0": 62, "d1": 58, "d2": 42, "d3": 32, "d4": 11, "d5": 1, "boat": 168, "plant": 152}, true)
			for k in gs.stage_keys():
				gs.managers[k] = true
			gs.coins = 6.3e7
		_:
			gs.coins = 12.0
	load("res://scripts/ui/main.gd").show_title = overlay == "title"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	# Let the chain run a bit so divers and the boat are mid-cycle.
	for i in 90:
		gs.advance(0.05)
		await process_frame
	if scroll > 0.0:
		main._scroller.scroll_to(scroll)
	match overlay:
		"sheet":
			main._on_stage_selected("d1")
		"avatar":
			main.open_avatar_editor()
		"quests", "daily", "museum":
			main.open_feature(overlay)
		"players":
			main.open_players()
		"tutorial":
			pr.tutorial_step = 0
		"toast":
			main._show_toast(TranslationServer.translate("QUEST_DONE"))
		"settings":
			main._open_settings()
		"prestige":
			main._open_prestige()
		_:
			if overlay.begins_with("wardrobe"):
				if ":" in overlay:
					load("res://scripts/ui/wardrobe.gd").tab = overlay.split(":")[1]
				main.open_feature("shop")
			elif overlay.begins_with("feature:"):
				main._news.append(overlay.split(":")[1])
				main._started = true
				main._show_next_news()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
