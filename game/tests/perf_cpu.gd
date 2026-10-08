extends SceneTree
## Script cost per frame of the busy main screen with no GPU in the way
## (what a single-threaded phone browser pays on its CPU for the game's
## scripts and drawing commands before rendering):
##   godot --headless --path . --resolution 390x844 --fixed-fps 60 -s res://tests/perf_cpu.gd [-- phone]
## Prints the median and the 90th percentile milliseconds per frame at
## three scroll positions (the shore, the work sites, deeper), several
## rounds each so a busy machine's noise shows. "phone" runs with the
## phone settings (half-rate scene, low power drawing).

func _initialize() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://perf_cpu_save.json"
	gs.reset()
	var pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://perf_cpu_progress.json"
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
	var args := OS.get_cmdline_user_args()
	var w = main._world
	for a in args:
		match a:
			"no_divers": w.divers.visible = false
			"no_rows":
				for r in w.rows:
					r.visible = false
			"no_surface": w.surface.visible = false
			"no_lift": w.lift.visible = false
			"no_hud": main._hud.visible = false
			"no_dock": main._dock.visible = false
			"no_tabs": main._tabs.visible = false
			"no_world": main._scroller.visible = false
			"no_sea":
				w.set_process(false)
			"no_cards":
				for r in w.rows:
					r.card.visible = false
				w.surface.boat_card.visible = false
				w.lift.card.visible = false
				main._evo_card.visible = false
	var out := []
	for scroll in [0.0, 900.0, 1800.0]:
		main._scroller.scroll_to(scroll)
		for i in 60:
			await process_frame
		var ms: Array[float] = []
		for i in 360:
			var t0 := Time.get_ticks_usec()
			await process_frame
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		ms.sort()
		out.append("scroll %d: median %.2f ms, p90 %.2f ms" % [scroll, ms[ms.size() / 2], ms[int(ms.size() * 0.9)]])
	for l in out:
		print(l)
	DirAccess.remove_absolute("user://perf_cpu_save.json")
	DirAccess.remove_absolute("user://perf_cpu_progress.json")
	quit()
