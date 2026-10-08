extends SceneTree
## Script cost of the workers' gear levels and skins (no renderer needed):
##   godot --headless --path . -s res://tests/bench_gear.gd
## Draws every world's 4 gear levels, a pattern skin and a costume skin in
## the world poses and prints microseconds each (after the caches warm up).

func _initialize() -> void:
	await process_frame
	var cv := Node2D.new()
	root.add_child(cv)
	var rid := cv.get_canvas_item()
	var n := 300
	var arms := ["swim", "dig", "idle", "walk"]
	for w: String in ["ocean", "volcano", "acid", "moon"]:
		var codes := [WorkerLooks.code(0), WorkerLooks.code(1), WorkerLooks.code(2), WorkerLooks.code(3), WorkerLooks.code(3, 4), WorkerLooks.code(3, 12)]
		var line := []
		for c: int in codes:
			_pass(cv, w, c, arms, n, rid)
			var t0 := Time.get_ticks_usec()
			_pass(cv, w, c, arms, n, rid)
			line.append("%d" % roundi(float(Time.get_ticks_usec() - t0) / (n * arms.size())))
		print("%s: levels 1-4, pattern skin, costume: %s us each" % [w, ", ".join(line)])
	quit()


func _pass(cv: Node2D, w: String, c: int, arms: Array, n: int, rid: RID) -> void:
	for arm: String in arms:
		for i in n:
			var f := float(i) / n
			Chars.diver(cv, Vector2(100, 100), 0.78, Color.WHITE, 1.0, 0.2, f * 3.0, arm, fmod(f * 5.0, 1.0), i % 3 == 0, Color("ffc6d6"), "happy", i % 17 == 0, f * 10.0, 0, {"turn": 1.0, "kick_amp": 0.8, "world": w, "form": c})
			if i % 20 == 19:
				Art.flush()
				RenderingServer.canvas_item_clear(rid)
	Art.flush()
	RenderingServer.canvas_item_clear(rid)
