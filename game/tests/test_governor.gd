extends SceneTree
## FrameGovernor steps down on a slow device and not on a fast one (needs
## a renderer: headless draws nothing, so the governor has no data):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tests/test_governor.gd

var _fg: GDScript


class Burner extends Node:
	var ms := 0
	func _process(_d: float) -> void:
		if ms > 0:
			OS.delay_msec(ms)


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1
	await process_frame
	var settings := root.get_node("Settings")
	settings.quality = "auto"
	var fails := 0
	var burner := Burner.new()
	root.add_child(burner)
	var FG: GDScript = load("res://scripts/util/frame_governor.gd")
	_fg = FG
	var gov: Node = FG.new()
	root.add_child(gov)
	# Fast frames: stays at level 0.
	await _run(9.0)
	if _fg.level != 0:
		print("FAIL: a fast device stepped down to %d" % _fg.level)
		fails += 1
	# Slow frames (15 ms of work each): steps down.
	burner.ms = 15
	await _run(9.0)
	if _fg.level < 1:
		print("FAIL: a slow device stayed at level 0")
		fails += 1
	# Still slow: keeps stepping down, one level each SETTLE + SLOW windows.
	await _run(16.0)
	if _fg.level < 3:
		print("FAIL: a slow device stopped at level %d" % _fg.level)
		fails += 1
	var lvl: int = _fg.level
	print("level after slow frames: %d, shape_hz %.0f, auto_low %s" % [lvl, load("res://scripts/ui/art.gd").shape_hz, settings.auto_low])
	# A chosen quality is left alone.
	settings.quality = "high"
	await _run(9.0)
	if _fg.level != lvl:
		print("FAIL: it changed level with quality = high")
		fails += 1
	settings.quality = "auto"
	settings.auto_low = false
	_fg.level = 0
	_fg.apply()
	print("governor tests: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


func _run(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame
