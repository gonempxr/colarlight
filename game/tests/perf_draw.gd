extends SceneTree
## Script cost of each big drawing on the main screen, called directly
## (no renderer needed):
##   godot --headless --path . --resolution 390x844 -s res://tests/perf_draw.gd [-- phone]
## For the shore (scroll 0) and the work sites (scroll 900) prints the
## microseconds one _draw of each layer costs (median of many), so the
## hot ones can be found and compared before/after a change.

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://perf_draw_save.json"
	gs.reset()
	var pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://perf_draw_progress.json"
	pr.reset()
	pr.tutorial_step = 99
	pr.daily_last = pr.today()
	for f in load("res://scripts/data/content.gd").FEATURES:
		pr.features[f] = true
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
	for k in 2:
		main._news.clear()
		main._top.close()
		main._modal.close()
		for i in 20:
			await process_frame
	var w = main._world
	var art: GDScript = load("res://scripts/ui/art.gd")
	for scroll in [0.0, 900.0]:
		main._scroller.scroll_to(scroll)
		for i in 30:
			await process_frame
		var d = w.divers
		var view: Rect2 = w.visible_rect()
		var line := "scroll %d:" % scroll
		for i in 6:
			if not w.is_visible_band(w.row_y(i) - 60.0, w.row_y(i) + w.ROW_H + 60.0):
				continue
			var key := "d%d" % i
			var n: int = gs.divers(key)
			var us_d: Array[float] = []
			var us_v: Array[float] = []
			for r in 40:
				await process_frame
				var p: float = load("res://scripts/ui/motion.gd").progress(key)
				var t0 := Time.get_ticks_usec()
				d._begin_site(i, key)
				d._draw_veins(i, n, view)
				art.flush()
				var t1 := Time.get_ticks_usec()
				for j in n:
					d._draw_diver(i, j, p, view)
				art.flush()
				var t2 := Time.get_ticks_usec()
				us_v.append(float(t1 - t0))
				us_d.append(float(t2 - t1) / maxf(1.0, n))
				RenderingServer.canvas_item_clear(d.get_canvas_item())
			us_d.sort()
			us_v.sort()
			line += "\n  site %d: %d divers, %.0f us each, veins %.0f us" % [i, n, us_d[20], us_v[20]]
		print(line)
	DirAccess.remove_absolute("user://perf_draw_save.json")
	DirAccess.remove_absolute("user://perf_draw_progress.json")
	quit()
