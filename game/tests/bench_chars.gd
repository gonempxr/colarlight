extends SceneTree
## Script cost and triangle count of characters (no renderer needed):
##   godot --headless --path . -s res://tests/bench_chars.gd
## Draws divers of every gear tier and people into a canvas item outside
## of _draw and prints microseconds and triangles each.

func _initialize() -> void:
	await process_frame
	var cv := Node2D.new()
	root.add_child(cv)
	var rid := cv.get_canvas_item()
	var n := 400
	var t_all_us := 0
	var arms := ["swim", "dig", "idle", "cheer"]
	for tier in 10:
		var depth := _depth_of_tier(tier)
		var us := 0
		for arm in arms:
			for warm in 2:
				if warm == 0:
					_diver_pass(cv, depth, arm, n, rid)
			var t0 := Time.get_ticks_usec()
			_diver_pass(cv, depth, arm, n, rid)
			us += Time.get_ticks_usec() - t0
		print("diver tier %d (depth %d): %.0f us each" % [tier, depth, float(us) / (n * arms.size())])
		t_all_us += us
	print("diver mean: %.0f us" % [float(t_all_us) / (n * 40)])
	var looks := [Chars.manager_look("d0"), Chars.manager_look("lift"), Chars.default_avatar()]
	var t0 := Time.get_ticks_usec()
	for i in n:
		Chars.person(cv, Vector2(200, 200), 0.6, 1.0, looks[i % 3], {"emotion": "happy", "blink": i % 13 == 0})
		if i % 20 == 19:
			Art.flush()
			RenderingServer.canvas_item_clear(rid)
	print("person: %.0f us each" % [float(Time.get_ticks_usec() - t0) / n])
	quit()

func _depth_of_tier(tier: int) -> int:
	for d in Art.DEPTH_STYLE.size():
		if Chars.gear_tier(d) == tier:
			return d
	return 0


func _diver_pass(cv: Node2D, depth: int, arm: String, n: int, rid: RID) -> void:
	for i in n:
		var f := float(i) / n
		Chars.diver(cv, Vector2(100, 100), 0.78, Color("ff8a3d"), 1.0, 0.2, f * 3.0, arm, fmod(f * 5.0, 1.0), i % 3 == 0, Color("ffc6d6"), "happy", i % 17 == 0, f * 10.0, depth, {"turn": 1.0, "kick_amp": 0.8})
		if i % 20 == 19:
			Art.flush()
			RenderingServer.canvas_item_clear(rid)
	Art.flush()
	RenderingServer.canvas_item_clear(rid)
