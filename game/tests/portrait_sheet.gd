extends SceneTree
## Every hat on a profile portrait (big and HUD-sized) to check that hats
## stay inside the ring:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1200x420 -s res://tests/portrait_sheet.gd -- out.png

class Sheet extends Control:
	func _draw() -> void:
		Art.flat(self, PackedVector2Array([Vector2(0, 0), Vector2(1200, 0), Vector2(1200, 420), Vector2(0, 420)]), Color("fffaf0"))
		var hairs := ["short", "long", "spiky", "curly", "bun", "short", "long", "mohawk", "bald", "short", "curly", "spiky", "long", "short", "short"]
		var ids: Array = ["none"]
		ids.append_array(HatsArt.IDS)
		for i in ids.size():
			var l := Chars.look(i % 6, hairs[i], i % 8, ids[i], "none", i % 8, Chars.CLOTHES[i % 6])
			var c := Vector2(60 + (i % 8) * 145, 80 + floori(i / 8.0) * 150)
			Chars.portrait(self, c, 52, l, "happy", false, Color("bfe8ff"))
			Chars.portrait(self, c + Vector2(0, 0) + Vector2(70, 50), 22, l, "happy", false, Color("ffd98a"))

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://portraits.png"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var s := Sheet.new()
	s.size = Vector2(1200, 420)
	root.add_child(s)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
