extends SceneTree
## Preview of the Rivals League portraits and the two side buttons, big:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1200x620 \
##     -s res://tests/rivals_sheet.gd -- out.png


class Sheet extends Control:
	var rv: GDScript
	var sb: GDScript
	var rivals: Array

	func _draw() -> void:
		Art.flat(self, PackedVector2Array([Vector2(0, 0), Vector2(1240, 0), Vector2(1240, 640), Vector2(0, 640)]), Color("fff6e4"))
		var i := 0
		for r in rivals:
			var c := Vector2(150 + (i % 4) * 300, 150 + (i / 4) * 300)
			rv.portrait(self, c, 120.0, r["id"])
			i += 1
		var c2 := Vector2(1050, 450)
		var k := 1.6
		Art.t_circle(self, c2 + Vector2(-60, 0), 76.0 * 0.44 * k, Color("fff4d6"), 4.0, 0.6)
		sb.draw_boost(self, c2 + Vector2(-60, 0), 76.0 * 0.44 * 0.78 * k)
		Art.t_circle(self, c2 + Vector2(60, 0), 76.0 * 0.44 * k, Color("e9f3ff"), 4.0, 0.6)
		sb.draw_trophy(self, c2 + Vector2(60, 1), 76.0 * 0.44 * 0.62 * k)


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://rivals_sheet.png"
	await process_frame
	var s := Sheet.new()
	s.rv = load("res://scripts/ui/rivals_view.gd")
	s.sb = load("res://scripts/ui/side_button.gd")
	s.rivals = root.get_node("Rivals").RIVALS
	s.size = Vector2(1240, 640)
	root.add_child(s)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
