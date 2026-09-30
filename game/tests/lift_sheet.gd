extends SceneTree
## Preview sheet of the 6 lift cabin looks (empty and full) and a crate:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1500x700 -s res://tests/lift_sheet.gd -- out.png


class Sheet extends Control:
	var t := 1.3
	var lv: GDScript

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		Art.flat(self, PackedVector2Array([Vector2(0, 0), Vector2(1500, 0), Vector2(1500, 700), Vector2(0, 700)]), Color("2283b6"))
		for i in 6:
			var c := Vector2(130 + i * 240, 300)
			Art.push(self, c, 0.0, Vector2(2.2, 2.2))
			lv.draw_cabin(self, i + 1, t, 0.0 if i % 2 == 0 else 1.0, i % 2 == 1)
			Art.pop(self)
			Art.push(self, c + Vector2(0, 330), 0.0, Vector2(2.2, 2.2))
			lv.draw_cabin(self, i + 1, t, 0.5, true)
			Art.pop(self)
			Art.text(self, c + Vector2(-100, -200), str(i + 1), 22, Art.WHITE, 5, false)


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://lift_sheet.png"
	var s := Sheet.new()
	s.lv = load("res://scripts/ui/lift_view.gd")
	s.size = Vector2(1500, 700)
	root.add_child(s)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
