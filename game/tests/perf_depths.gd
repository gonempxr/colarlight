extends SceneTree
## Frame cost of the deep dive sites, every site open with five divers
## (needs a renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/perf_depths.gd -- [phone] [no_divers|no_rows] [first,first,...]
## For each FIRST depth it scrolls that site to the top and prints the
## average ms per frame (wall, process, render) and primitives, so the new
## sites can be compared with the older deep ones in the same run.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://perf_depths_save.json"
	gs.reset()
	var pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://perf_depths_progress.json"
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
	if "phone" in args:
		# Main applies Settings.low_quality() to Art and World at start.
		root.get_node("Settings").quality = "low"
		load("res://scripts/ui/world.gd").half_rate = true
		load("res://scripts/ui/art.gd").low_power = true
	var firsts: Array[int] = [15, 21, 24, 26]
	for a in args:
		if "," in a or a.is_valid_int():
			firsts.clear()
			for p in a.split(","):
				firsts.append(int(p))
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await process_frame
	var main = current_scene
	if "no_divers" in args:
		main._world.divers.visible = false
	if "no_rows" in args:
		for r in main._world.rows:
			r.visible = false
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for first in firsts:
		main._scroller.scroll_to((620.0 + 260.0 * first - 40.0) * main._scroller.zoom)
		for i in 40:
			await process_frame
		var t0 := Time.get_ticks_usec()
		var proc := 0.0
		var rcpu := 0.0
		var prims := 0.0
		var n := 180
		for i in n:
			await process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("depths %d+: %.2f ms/frame wall, %.2f ms process, render cpu %.2f ms, %d primitives" % [first, ms, proc / n * 1000.0, rcpu / n, prims / n])
	DirAccess.remove_absolute("user://perf_depths_save.json")
	DirAccess.remove_absolute("user://perf_depths_progress.json")
	quit()
