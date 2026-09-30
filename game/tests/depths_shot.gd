extends SceneTree
## Screenshot of the dive sites with every depth open (needs a real renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/depths_shot.gd -- out.png FIRST_DEPTH [steps] [ui_scale]
## Scrolls so depth FIRST_DEPTH is at the top; `steps` advances the game
## (0.05 s each) first so divers are mid-trip.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://depths.png"
	var first := int(args[1]) if args.size() > 1 else 6
	var steps := int(args[2]) if args.size() > 2 else 90
	var ui_scale := float(args[3]) if args.size() > 3 else 1.0
	await process_frame
	root.get_node("Settings").language = "en"
	root.get_node("Settings").ui_scale = ui_scale
	TranslationServer.set_locale("en")
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://depths_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://depths_progress.json"
	pr.reset()
	pr.tutorial_step = 9
	for f in load("res://scripts/data/content.gd").FEATURES:
		pr.features[f] = true
	pr.daily_last = pr.today()
	for k in gs.stage_keys():
		gs.levels[k] = 150
		gs.managers[k] = true
	gs.coins = 1e22
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	# Only our own steps move the game, so the shot shows the phase we ask for.
	gs.set_process(false)
	gs.set_physics_process(false)
	for i in steps:
		gs.advance(0.05)
		await process_frame
	main._scroller.scroll_to((620.0 + 260.0 * first - 40.0) * main._scroller.zoom)
	for i in 12:
		gs.advance(0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
