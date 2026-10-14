extends SceneTree
## Preview of the mine bosses (BossArt), calm on top, hit and angry below:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1500x700 \
##     -s res://tests/boss_sheet.gd -- out.png


class Sheet extends Control:
	func _draw() -> void:
		Art.grad(self, PackedVector2Array([Vector2.ZERO, Vector2(1500, 0), Vector2(1500, 700), Vector2(0, 700)]),
			PackedColorArray([Color("5b3fcf"), Color("5b3fcf"), Color("1c1c62"), Color("1c1c62")]))
		var ids := ["crabblack", "mother_jelly", "shadow_eel", "kraken", "warden"]
		for i in ids.size():
			BossArt.draw(self, ids[i], Vector2(150 + i * 300, 190), 0.85, 1.3)
			BossArt.draw(self, ids[i], Vector2(150 + i * 300, 520), 0.85, 2.1, 0.6, 1.0)


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://boss_sheet.png"
	await process_frame
	var s := Sheet.new()
	s.size = Vector2(1500, 700)
	root.add_child(s)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
