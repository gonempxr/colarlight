extends SceneTree
## The same sprites at the scales the game draws them (phone shore ~0.5,
## divers ~0.6-1, previews ~2), to compare outline widths on screen:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1200x520 -s res://tests/outline_sheet.gd -- out.png

class Sheet extends Control:
	func _draw() -> void:
		Art.flat(self, PackedVector2Array([Vector2(0, 0), Vector2(1200, 0), Vector2(1200, 520), Vector2(0, 520)]), Color("bfe8ff"))
		var scales := [0.5, 0.75, 1.0, 1.5, 2.2]
		var x := 30.0
		for s: float in scales:
			Chars.person(self, Vector2(x + 30 * s, 230), s, 1.0, Chars.manager_look("boat"), {"emotion": "happy"})
			Chars.diver(self, Vector2(x + 30 * s, 500), s * 0.9, Art.DEPTH_STYLE[0]["suit"], 1.0, 0.0, 0.0, "idle", 0.0, false, Art.GOLD, "happy", false, 0.0)
			Art.push(self, Vector2(x + 95 * s, 230 - 12 * s), 0.0, Vector2(s, s))
			PetArt.draw(self, "octopus", 0.0, -1.0, false)
			Art.pop(self)
			Art.text(self, Vector2(x + 50 * s, 30), "x%.2f" % s, 18, Art.INK, 0)
			x += 60.0 + 150.0 * s

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://outlines.png"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var s := Sheet.new()
	s.size = Vector2(1200, 520)
	root.add_child(s)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
