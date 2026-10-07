extends SceneTree
## Where the frame time goes, per script (needs a renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/perf_attr.gd -- [phone] [room=0|1|2] [world=0..3] [scroll=px] [attr] [frames=N]
## Prints the average frame cost (process + render cpu) and, with "attr",
## how much each script's nodes cost: all nodes running that script are
## hidden and stop processing, and the saving is reported.

var _vp: RID


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var opt := {"room": "0", "world": "0", "scroll": "0", "frames": "60"}
	for a in args:
		if "=" in a:
			var kv := a.split("=")
			opt[kv[0]] = kv[1]
		else:
			opt[a] = "1"
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	OS.low_processor_usage_mode_sleep_usec = 1
	await process_frame
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://perf_attr_save.json"
	gs.reset()
	var pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://perf_attr_progress.json"
	pr.reset()
	pr.tutorial_step = 99
	for f in load("res://scripts/data/content.gd").FEATURES:
		pr.features[f] = true
	pr.daily_last = pr.today()
	for k in gs.stage_keys():
		gs.levels[k] = 150
		gs.managers[k] = true
	gs.levels.merge({"lift": 300, "boat": 300, "plant": 300}, true)
	gs.coins = 1e12
	gs.evo = 4
	if gs.get("location") != null:
		gs.set("location", int(opt["world"]))
	load("res://scripts/ui/main.gd").show_title = false
	if opt.has("phone"):
		root.get_node("Settings").quality = "low"
	else:
		root.get_node("Settings").quality = "high"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await process_frame
	var main = current_scene
	if opt.has("lowart"):
		# Low-power art (no soft edges) at the full frame schedule.
		Art.low_power = true
		Art.clear_cache()
		load("res://scripts/ui/world.gd").half_rate = false
		main._world.repaint_still()
	if opt.has("halfrate"):
		load("res://scripts/ui/world.gd").half_rate = true
	var room := int(opt["room"])
	if room != 0:
		main.show_room(room, false)
	if float(opt["scroll"]) > 0.0:
		main._scroller.scroll_to(float(opt["scroll"]))
	for i in 30:
		await process_frame
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	var frames := int(opt["frames"])
	spikes = opt.has("spikes")
	var prof: Variant = load("res://scripts/util/prof.gd") if opt.has("prof") and ResourceLoader.exists("res://scripts/util/prof.gd") else null
	if prof:
		prof.reset()
	var base := await _measure(frames)
	if prof:
		var keys: Array = prof.total.keys()
		keys.sort_custom(func(a, b): return prof.total[a] > prof.total[b])
		var sum := 0.0
		for k in keys:
			sum += prof.total[k]
		print("PROF per frame (sum of wrapped %.2f ms):" % (sum / 1000.0 / frames))
		for k in keys.slice(0, 30):
			print("  %6.3f ms  %5.1f calls  %s" % [prof.total[k] / 1000.0 / frames, float(prof.calls[k]) / frames, k])
	print("BASE world=%s room=%d %s: frame %.2f ms (process %.2f, render cpu %.2f, worst %.1f), %d calls, %d prims" % [opt["world"], room, "phone" if opt.has("phone") else "pc", base[0], base[4], base[1], base[5], base[2], base[3]])
	if opt.has("attr") or opt.has("kids"):
		var groups := {}
		if opt.has("kids"):
			# Each child of the node at main.<kids> on its own (by name),
			# plus "<self process>" = only that node's own _process off.
			var host: Node = main.get(opt["kids"]) if opt["kids"] != "1" else main._world
			for c in host.get_children():
				if c is CanvasItem and c.visible:
					groups[str(c.get_index()) + ":" + c.name + ":" + (c.get_script().resource_path.get_file() if c.get_script() else c.get_class())] = [c]
		else:
			_collect(main, groups)
		var rows := []
		for path in groups:
			var nodes: Array = groups[path]
			var saved := []
			for n in nodes:
				saved.append([n, n.visible, n.is_processing()])
				n.visible = false
				n.set_process(false)
				if opt.has("noproc"):
					n.visible = true
			for i in 3:
				await process_frame
			var m := await _measure(frames / 2)
			for s in saved:
				s[0].visible = s[1]
				s[0].set_process(s[2])
			var gain: float = base[0] - m[0]
			rows.append([gain, path, nodes.size(), base[3] - m[3], base[2] - m[2]])
			for i in 3:
				await process_frame
		if opt.has("bycalls"):
			rows.sort_custom(func(a, b): return a[4] > b[4])
		else:
			rows.sort_custom(func(a, b): return a[0] > b[0])
		for r in rows.slice(0, 25):
			print("  %6.2f ms  %-40s x%d  prims %d  calls %d" % [r[0], r[1].get_file(), r[2], r[3], r[4]])
	quit()


var spikes := false


func _measure(frames: int) -> Array:
	## Median frame: wall time (headless runs unthrottled, so wall = CPU),
	## process time, render cpu; mean draw calls and primitives.
	var wall := []
	var proc := []
	var rcpu := []
	var calls := 0.0
	var prims := 0.0
	var t := Time.get_ticks_usec()
	var prof: Variant = load("res://scripts/util/prof.gd") if ResourceLoader.exists("res://scripts/util/prof.gd") else null
	var snap := {}
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now - t) / 1000.0)
		t = now
		if prof and spikes:
			if wall[-1] > 25.0 and not snap.is_empty():
				var diff := []
				for k in prof.total:
					var d: float = prof.total[k] - snap.get(k, 0)
					if d > 1000 and not k.begins_with("Art.flushed"):
						diff.append([d / 1000.0, k])
				diff.sort_custom(func(a, b): return a[0] > b[0])
				print("SPIKE frame %d: %.1f ms  " % [i, wall[-1]], diff.slice(0, 8))
			snap = prof.total.duplicate()
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		rcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return [_median(wall), _median(rcpu), calls / frames, prims / frames, _median(proc), wall.max()]


func _median(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


## Visible CanvasItems with a script, grouped by script path. A node whose
## ancestor already runs the same script is skipped (hiding the top hides it).
func _collect(n: Node, groups: Dictionary) -> void:
	for c in n.get_children():
		if c is CanvasItem and c.visible and c.get_script() != null:
			var p: String = c.get_script().resource_path
			if p != "" and not p.ends_with("main.gd"):
				if not groups.has(p):
					groups[p] = []
				groups[p].append(c)
		_collect(c, groups)
