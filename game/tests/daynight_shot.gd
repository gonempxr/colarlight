extends SceneTree
## Strip of the main screen at several times of day, side by side:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/daynight_shot.gd -- out.png [phases] [boat_level] [plant_level] [crop_h]
## phases: comma list of day phases 0..1 (0 sunrise, 0.25 noon, 0.5 sunset,
## 0.75 midnight), default "0.02,0.25,0.47,0.52,0.75,0.97".
## crop_h: window pixels kept from the top (default: whole window).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://daynight.png"
	var phases := (args[1] if args.size() > 1 else "0.02,0.25,0.47,0.52,0.75,0.97").split(",")
	var boat_level := int(args[2]) if args.size() > 2 else 45
	var plant_level := int(args[3]) if args.size() > 3 else 41
	var crop_h := int(args[4]) if args.size() > 4 else 0
	await process_frame
	root.get_node("Settings").language = "en"
	TranslationServer.set_locale("en")
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://daynight_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://daynight_progress.json"
	pr.reset()
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.tutorial_step = 7
	pr.daily_last = pr.today()
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "boat": boat_level, "plant": plant_level}, true)
	for k in ["d0", "d1", "boat", "plant"]:
		gs.managers[k] = true
	gs.coins = 48250.0
	gs.hold = 1840.0
	gs.dock = 620.0
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	for i in 60:
		gs.advance(0.05)
		await process_frame
	var dn: GDScript = load("res://scripts/ui/day_night.gd")
	var shots: Array[Image] = []
	for ph in phases:
		dn.fixed_phase = float(ph)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if crop_h > 0 and crop_h < img.get_height():
			img = img.get_region(Rect2i(0, 0, img.get_width(), crop_h))
		shots.append(img)
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var strip := Image.create(w * shots.size() + 8 * (shots.size() - 1), h, false, shots[0].get_format())
	strip.fill(Color.BLACK)
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 8), 0))
	strip.save_png(out)
	quit()
