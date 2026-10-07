extends SceneTree
## Preview sheet of the streak art: the flame buddy (lit and sleepy, a few
## sizes and flicker phases), ice cubes, the flame hat on a portrait and the
## flame boat paint as the wardrobe shows them:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 900x520 \
##     -s res://tests/streak_sheet.gd -- out.png

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://streak_sheet.png"
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("fff6e0")
	bg.size = Vector2(900, 520)
	root.add_child(bg)
	var sa = load("res://scripts/ui/streak_art.gd")
	var wr = load("res://scripts/ui/wardrobe.gd")
	var av = load("res://scripts/ui/art_view.gd")
	var content = load("res://scripts/data/content.gd")
	var paint := func(ci: CanvasItem, _s: Vector2, _t: float) -> void:
		for i in 4:
			sa.flame(ci, Vector2(70 + i * 120, 190), 50.0, i * 2, true, true)
		sa.flame(ci, Vector2(560, 190), 50.0, 1, false, true)
		for i in 6:
			sa.flame(ci, Vector2(660 + i * 38, 190), 10.0 + i * 1.5, i, i % 2 == 0, true)
		sa.ice(ci, Vector2(60, 280), 60.0)
		sa.ice(ci, Vector2(140, 280), 34.0)
		sa.ice(ci, Vector2(200, 280), 34.0, true)
	var v = av.make(paint, Vector2(900, 320))
	v.size = Vector2(900, 320)
	root.add_child(v)
	for k in 2:
		var id: String = ["hat_flame", "boat_flame"][k]
		var item: Dictionary = content.cosmetic(id)
		var cell = av.make(func(ci: CanvasItem, s: Vector2, t: float): wr._draw_item(ci, item, s, t), Vector2(220, 200))
		cell.position = Vector2(300 + k * 260, 310)
		cell.size = Vector2(220, 200)
		root.add_child(cell)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
