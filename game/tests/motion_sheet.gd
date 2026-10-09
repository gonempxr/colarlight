extends SceneTree
## Frames of the shore while the boats sail and the lift runs, to check
## that the moving sprites (Art slots, SceneSprite, the cabin) line up:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/motion_sheet.gd -- /tmp/seq   (writes /tmp/seq_0.png ... _7)
func _initialize():
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://dbg.json"
	gs.reset()
	var pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.tutorial_step = 99
	pr.daily_last = pr.today()
	for f in Content.FEATURES:
		pr.features[f] = true
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "lift": 40, "boat": 45, "plant": 41, "boat2": 5, "plant2": 3}, true)
	for k in gs.stage_keys():
		gs.managers[k] = true
	gs.hold = 1e6
	gs.pit = 1e6
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var out := OS.get_cmdline_user_args()[0]
	for shot in 8:
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.crop(img.get_width(), mini(img.get_height(), 560))
		img.save_png("%s_%d.png" % [out, shot])
	quit()
