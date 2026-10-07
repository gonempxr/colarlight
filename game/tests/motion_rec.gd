extends SceneTree
## Records a short motion of the main screen frame by frame (needs a
## renderer; --fixed-fps makes every frame exactly 1/60 s):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 --fixed-fps 60 \
##     -s res://tests/motion_rec.gd -- <out_dir> <motion> [frames] [every]
## Writes <out_dir>/<motion>_NNN.png; tools/contact_sheet.py tiles them.
## Motions: idle (the shore: boat, palm, crew), lift (taps send the cabin
## down), boat (the boat sails off), divers (a dive site at work), rooms
## (the Factory tab), swipe (a finger drags to the factory and lets go),
## modal (settings open), close (settings close), sheet (the upgrade sheet),
## coins (coins fly to the top bar), title (the title screen's intro),
## tap (a button pressed and let go).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var motion: String = args[1]
	var frames := int(args[2]) if args.size() > 2 else 30
	var every := int(args[3]) if args.size() > 3 else 1
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://motion_rec_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://motion_rec_progress.json"
	pr.reset()
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	for f in Content.FEATURES:
		pr.features[f] = true
	TranslationServer.set_locale("en")
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "lift": 40, "boat": 45, "plant": 41}, true)
	for k in ["d0", "d1", "d2", "boat", "plant"]:
		gs.managers[k] = true
	gs.coins = 48250.0
	gs.pit = 500.0
	load("res://scripts/ui/main.gd").show_title = motion == "title"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	if motion != "title":
		for i in 60:
			gs.advance(0.05)
			await process_frame
	# No news dialogs over the motion.
	for k in 2:
		main._news.clear()
		main._top.close()
		main._modal.close()
		for i in 20:
			await process_frame
	var world = main._world
	match motion:
		"lift":
			main._scroller.scroll_to(420.0)
		"divers":
			main._scroller.scroll_to(560.0)
		"boat":
			gs._timer["boat"] = gs.cycle_time("boat") * 0.1
		"close":
			main._open_settings()
			for i in 40:
				await process_frame
	for i in 3:
		await process_frame
	var n := 0
	for f in frames * every:
		# The action, on the first recorded frame.
		if f == 1:
			match motion:
				"lift":
					gs.tap("lift")
				"rooms":
					main.show_room(1)
				"modal":
					main._open_settings()
				"close":
					main._modal.close()
				"sheet":
					main._on_stage_selected("d0")
				"coins":
					main._fx.fly("coin", Vector2(200, 600), main._hud.coin_target(), 8)
				"tap":
					_mouse(main, Vector2(195, 790), true)
		if motion == "lift" and f > 1 and f % 9 == 0:
			gs.tap("lift")
		if motion == "tap" and f == 5:
			_mouse(main, Vector2(195, 790), false)
		if motion == "swipe":
			# Down at frame 1, drag 1..13 to the left (slowing), let go.
			var area: Rect2 = main._area
			var x0 := area.end.x - 30.0
			var len := area.size.x * 0.4
			var y := area.get_center().y
			if f == 1:
				_mouse(main, Vector2(x0, y), true)
			elif f > 1 and f <= 13:
				var k := float(f - 1) / 12.0
				_move(main, Vector2(x0 - len * (1.0 - pow(1.0 - k, 2.0)), y + k * 6.0))
			elif f == 14:
				_mouse(main, Vector2(x0 - len, y + 6.0), false)
		await process_frame
		if f % every != 0:
			continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%03d.png" % [out, motion, n])
		n += 1
	DirAccess.remove_absolute("user://motion_rec_save.json")
	DirAccess.remove_absolute("user://motion_rec_progress.json")
	quit()


func _mouse(main: Node, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = root.get_final_transform() * at
	e.global_position = e.position
	root.push_input(e)


func _move(main: Node, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = root.get_final_transform() * at
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)
