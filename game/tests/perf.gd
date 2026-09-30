extends SceneTree
## Rough frame-cost check on the busiest screen (needs a renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 -s res://tests/perf.gd
## Prints average milliseconds per frame for script + drawing work.

func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://perf_save.json"
	gs.reset()
	gs.levels.merge({"d0": 150, "d1": 120, "d2": 100, "d3": 80, "d4": 60, "d5": 40, "lift": 300, "boat": 300, "plant": 300}, true)
	for k in gs.stage_keys():
		gs.managers[k] = true
	gs.coins = 1e9
	load("res://scripts/ui/main.gd").show_title = false
	if "phone" in OS.get_cmdline_user_args():
		load("res://scripts/ui/world.gd").half_rate = true
		load("res://scripts/ui/art.gd").low_power = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await process_frame
	var main = current_scene
	var only: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	match only:
		"no_divers":
			main._world.divers.visible = false
		"no_rows":
			for r in main._world.rows:
				r.visible = false
		"no_surface":
			main._world.surface.visible = false
		"no_hud":
			main._hud.visible = false
		"no_world":
			main._scroller.visible = false
		"nothing":
			main._scroller.visible = false
			main._hud.visible = false
			main._panel.visible = false
		"no_badges":
			for r in main._world.rows:
				r.card._manager.visible = false
			main._world.surface.boat_card._manager.visible = false
			main._world.surface.plant_card._manager.visible = false
	for scroll in [0.0, 900.0, 1800.0]:
		main._scroller.scroll_to(scroll)
		for i in 20:
			await process_frame
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var t0 := Time.get_ticks_usec()
		var proc := 0.0
		var rcpu := 0.0
		var rgpu := 0.0
		var calls := 0.0
		var prims := 0.0
		for i in 120:
			await process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 120.0
		print("scroll %d: %.2f ms/frame wall, %.2f ms process, render cpu %.2f ms, gpu %.2f ms, %d draw calls, %d primitives" % [scroll, ms, proc / 120.0 * 1000.0, rcpu / 120.0, rgpu / 120.0, calls / 120.0, prims / 120.0])
	DirAccess.remove_absolute("user://perf_save.json")
	quit()
