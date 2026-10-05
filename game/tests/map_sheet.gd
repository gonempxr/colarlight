extends SceneTree
## World map preview:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/map_sheet.gd -- out.png <location> <ready 0|1> [map|confirm|mini] [lang]
## "mini" draws the mini-map for all four worlds, small and big;
## "islands" the four islands lit and as silhouettes (run at 1800x1200).


class Islands extends Control:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var ma: GDScript = load("res://scripts/ui/map_art.gd")
		Art.flat(self, Art.rrect_pts(Rect2(Vector2.ZERO, size), 0), Color("6ec3f2"))
		var k := minf(size.x / 1900.0, size.y / 1150.0)
		for i in 8:
			var c := Vector2(240 + (i % 4) * 470, 300 + (i / 4) * 560) * k
			Art.push(self, c, 0.0, Vector2(k, k))
			var w: String = ma.WORLDS[i % 4]
			ma.island(self, w, ma.CURRENT if i < 4 else (ma.NEXT if i == 4 else ma.LOCKED), t, 0)
			if i < 4:
				ma.nodes(self, w, 2)
				ma.markers(self, w, t)
				var b: Vector3 = ma.boat_at(w, 0.3)
				ma.boat(self, Vector2(b.x, b.y), b.z, w, true, t)
			Art.pop(self)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://map_sheet.png"
	var loc := int(args[1]) if args.size() > 1 else 0
	var ready := args.size() > 2 and args[2] == "1"
	var mode: String = args[3] if args.size() > 3 else "map"
	var lang: String = args[4] if args.size() > 4 else "en"
	TranslationServer.set_locale(lang)
	await process_frame
	var mv: GDScript = load("res://scripts/ui/map_view.gd")
	var goals := [{"id": "sites", "have": 10 if ready else 7, "need": 10}, {"id": "foremen", "have": 10 if ready else 4, "need": 10},
			{"id": "managers", "have": 5 if ready else 3, "need": 5}, {"id": "evo", "have": 12 if ready else 5, "need": 12}]
	mv.set("demo", {"location": loc, "goals": goals, "cost": 2.5e9 * pow(8.0, loc), "coins": 3.1e9 * pow(8.0, loc) if ready else 4.2e8 * pow(8.0, loc),
			"can": ready, "boat": 0.3, "boat2": 0.8})
	var host := Control.new()
	host.theme = load("res://scripts/ui/ui_theme.gd").build()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	if mode == "islands":
		var isl := Islands.new()
		isl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(isl)
	elif mode == "mini":
		var bg := ColorRect.new()
		bg.color = Color("4fb3ee")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(bg)
		var mm: GDScript = load("res://scripts/ui/mini_map.gd")
		for i in 8:
			var m: Control = mm.new()
			m.set("location_override", i % 4 + (4 if i == 7 else 0))
			m.set("big", i >= 4)
			m.position = Vector2(30 + (i % 4) * 175, 40 + (i / 4) * 220)
			host.add_child(m)
	else:
		var v: Control = mv.new()
		host.add_child(v)
		if mode == "confirm":
			await process_frame
			v.set("_confirm", true)
			v.call("_build_panel")
			v.call("_layout")
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
