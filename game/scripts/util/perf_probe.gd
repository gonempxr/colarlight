class_name PerfProbe
extends CanvasLayer
## Frame-rate readout for checking speed on real devices, from the page
## address (web only):
##   ?fps=1            a small counter in the corner: frames per second,
##                     the average and the worst frame of the last second
##   ?bench=late       a busy late-game world in a throwaway save (nothing
##                     is saved, the player's own saves are not touched),
##                     with the counter. Also: &world=0..3 &room=0..2
##                     &q=high|low (graphics quality for this visit only)
## The numbers are also put into window.coralightPerf for automated runs.

var _label: Label
var _frames := 0
var _acc := 0.0
var _worst := 0.0
var _proc := 0.0
var _history: Array[float] = []


static func _param(name: String) -> String:
	if not OS.has_feature("web"):
		return OS.get_environment("CORALIGHT_" + name.to_upper())
	return str(JavaScriptBridge.eval("(function(){try{return new URLSearchParams(window.location.search).get('%s')||''}catch(e){return ''}})()" % name, true))


## Called first thing by Main: sets up a bench world if asked and adds the
## counter. Returns the room to open (-1: as usual).
static func attach(main: Node) -> int:
	var bench := _param("bench")
	var room := -1
	if bench != "":
		_setup_bench(main.get_tree().root, bench, int(_param("world")))
		if _param("q") in ["high", "low", "auto"]:
			main.get_tree().root.get_node("Settings").quality = _param("q")
		main.get_script().show_title = false
		room = int(_param("room")) if _param("room") != "" else -1
	if bench != "" or _param("fps") != "":
		main.add_child(PerfProbe.new())
	if bench == "cpu":
		main.get_tree().create_timer(2.0).timeout.connect(_cpu_bench.bind(main))
	return room


## ?bench=cpu: microseconds per call of the drawing kit and per diver, to
## compare this browser's speed with the native numbers of
## tests/bench_art.gd and tests/bench_chars.gd.
static func _cpu_bench(main: Node) -> void:
	var cv := Node2D.new()
	main.add_child(cv)
	var pts := Art.ellipse_pts(Vector2.ZERO, Vector2(20, 14))
	var line_pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 5), Vector2(20, 3), Vector2(30, 9), Vector2(40, 2), Vector2(50, 6)])
	var out := {}
	var n := 4000
	var t0 := Time.get_ticks_usec()
	for i in n:
		Art.toon(cv, pts, Art.CORAL, 3.0, 1.0)
		if i % 200 == 199:
			Art.flush()
	out["toon"] = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	for i in n:
		Art.polyline(cv, line_pts, Art.INK, 3.0)
		if i % 200 == 199:
			Art.flush()
	out["polyline"] = float(Time.get_ticks_usec() - t0) / n
	var m := 300
	t0 = Time.get_ticks_usec()
	for i in m:
		Chars.diver(cv, Vector2.ZERO, 0.78, Art.CORAL, 1.0, 0.0, i * 0.05, "swim", 0.0, false, Art.GOLD, "happy", false, i * 0.05, 0)
		Art.flush()
	out["diver"] = float(Time.get_ticks_usec() - t0) / m
	var s := 0.0
	t0 = Time.get_ticks_usec()
	for i in 200000:
		s += sin(i * 0.001)
	out["loop_200k_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	cv.queue_free()
	print("CPU BENCH ", out)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.coralightCpu = %s;" % JSON.stringify(out), true)


static func _setup_bench(root: Node, kind: String, world: int) -> void:
	for n in ["GameState", "Progress", "Fishing", "Rivals"]:
		var node := root.get_node_or_null(n)
		if node:
			node.autosave_enabled = false
			node.save_path = "user://bench_%s.json" % n.to_lower()
	var gs = root.get_node("GameState")
	gs.reset()
	var pr = root.get_node("Progress")
	pr.reset()
	pr.tutorial_step = 99
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.daily_last = pr.today()
	if kind == "start":
		gs.coins = 12.0
		return
	for k in gs.stage_keys():
		gs.levels[k] = 150
		gs.managers[k] = true
	gs.levels.merge({"lift": 300, "boat": 300, "plant": 300}, true)
	gs.coins = 1e12
	gs.evo = 4
	gs.location = clampi(world, 0, 3)


func _ready() -> void:
	layer = 128
	_label = Label.new()
	_label.position = Vector2(6, 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)
	_label.text = "…"


func _process(delta: float) -> void:
	_frames += 1
	_acc += delta
	_worst = maxf(_worst, delta)
	_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	if _acc < 1.0:
		return
	var fps := _frames / _acc
	_history.append(fps)
	if _history.size() > 30:
		_history.pop_front()
	var avg_ms := _acc / _frames * 1000.0
	var proc_ms := _proc / _frames * 1000.0
	_label.text = "%d fps  avg %.1f ms  worst %.0f ms  cpu %.1f ms  busy %.1f ms  L%d" % [roundi(fps), avg_ms, _worst * 1000.0, proc_ms, FrameGovernor.busy_now, FrameGovernor.level]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.coralightPerf = {fps: %.2f, avg_ms: %.2f, worst_ms: %.2f, cpu_ms: %.2f, busy_ms: %.2f, level: %d, history: %s};"
				% [fps, avg_ms, _worst * 1000.0, proc_ms, FrameGovernor.busy_now, FrameGovernor.level, JSON.stringify(_history)], true)
	_frames = 0
	_acc = 0.0
	_worst = 0.0
	_proc = 0.0
