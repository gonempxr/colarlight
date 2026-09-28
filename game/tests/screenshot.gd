extends SceneTree
## Screenshot of the main screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/screenshot.gd -- out.png ru mid 0 [sheet]
## Args: output file, language, scenario (start|mid|late), scroll px, optional "sheet".

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var lang := args[1] if args.size() > 1 else "ru"
	var scenario := args[2] if args.size() > 2 else "mid"
	var scroll := float(args[3]) if args.size() > 3 else 0.0
	var sheet := args.size() > 4 and args[4] == "sheet"
	await process_frame
	root.get_node("Settings").language = lang
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://screenshot_save.json"
	gs.reset()
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
	if sheet:
		main._on_stage_selected("d1")
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
