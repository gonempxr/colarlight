extends SceneTree
## Preview of the tutorial pointing hand at its in-game sizes and zoomed:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 900x500 -s res://tests/pointer_sheet.gd -- out.png

class Sheet extends Control:
	func _draw() -> void:
		Art.flat(self, PackedVector2Array([Vector2(0, 0), Vector2(900, 0), Vector2(900, 500), Vector2(0, 500)]), Color("35c9d2"))
		Art.flat(self, PackedVector2Array([Vector2(450, 0), Vector2(900, 0), Vector2(900, 500), Vector2(450, 500)]), Color("f8d898"))
		PointerArt.hand(self, Vector2(120, 60), -0.5, Vector2(3, 3))
		PointerArt.hand(self, Vector2(560, 60), 0.0, Vector2(2.4, 2.4))
		PointerArt.draw(self, Vector2(380, 330), 0.0, false, -0.5, 1.15)
		PointerArt.draw(self, Vector2(380, 420), 0.55, true, -0.5, 1.15)
		PointerArt.draw(self, Vector2(780, 340), 0.0, false, -0.45, 0.8)
		PointerArt.draw(self, Vector2(860, 330), 0.6, true, -0.45, 0.8)

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://pointer.png"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var s := Sheet.new()
	s.size = Vector2(900, 500)
	root.add_child(s)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
