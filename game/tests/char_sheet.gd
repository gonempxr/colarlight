extends SceneTree
## Preview sheet of characters and props (needs a real renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1400x1000 -s res://tests/char_sheet.gd -- out.png

class Sheet extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	var zoom := 1.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("7fc8e8"))
		Art.push(self, Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		_draw_all()
		Art.pop(self)
	func _draw_all() -> void:
		var emos := Chars.EMOTIONS.keys()
		for i in emos.size():
			var l := Chars.manager_look(["d0", "d1", "d2", "d3", "d4", "d5", "boat", "plant", "x"][i])
			Chars.person(self, Vector2(80 + i * 140, 170), 1.2, 1.0, l, {"emotion": emos[i], "arm_r": 0.6, "hold": ["sack", "coinbag", "briefcase", "wrench", "hammer", "clipboard", "", "", ""][i]})
			Art.text(self, Vector2(80 + i * 140, 200), emos[i], 18)
		for i in 8:
			var key: String = ["d0", "d1", "d2", "d3", "d4", "d5", "boat", "plant"][i]
			Chars.portrait(self, Vector2(80 + i * 140, 290), 50, Chars.manager_look(key), "happy", false, Art.DEPTH_STYLE[i % 6]["water"].lightened(0.3))
		var arms := ["swim", "rope", "pick", "idle", "cheer"]
		for i in 6:
			var st: Dictionary = Art.DEPTH_STYLE[i]
			Chars.diver(self, Vector2(80 + i * 140, 520), 1.2, st["suit"], 1.0, 0.0, t, arms[i % 5], fposmod(t, 1.0), i % 2 == 0, st["ore"], emos[i], false, t)
		for i in 6:
			var st: Dictionary = Art.DEPTH_STYLE[i]
			Art.crystals(self, Vector2(80 + i * 140, 640), 60, st, i, 5)
		Art.coin(self, Vector2(950, 620), 30)
		Art.lock(self, Vector2(1030, 620), 30)
		Art.gear(self, Vector2(1110, 620), 30, Art.GOLD, t)
		Art.fish(self, Vector2(1200, 620), 30, Art.CORAL, 1.0, t)
		Art.seaweed(self, Vector2(1280, 660), 80, Color("3fbf7f"), t, 0.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 9:
			Chars.person(self, Vector2(80 + i * 140, 860), 1.2, -1.0 if i % 2 else 1.0, Chars.random_look(rng), {"emotion": "happy", "walk": fposmod(t + i * 0.1, 1.0), "arm_l": -0.4, "arm_r": 0.4})

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://sheet.png"
	var s := Sheet.new()
	s.size = Vector2(1400, 1000)
	if OS.get_cmdline_user_args().size() > 1:
		s.zoom = float(OS.get_cmdline_user_args()[1])
	root.add_child(s)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
