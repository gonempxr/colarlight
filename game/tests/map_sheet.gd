extends SceneTree
## World map preview:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/map_sheet.gd -- out.png <location> <ready 0|1> [map|confirm|hint|mini|islands] [lang]
## "mini" draws the mini-map for every world, small and big (run at 900x500);
## "islands" every island lit and as silhouettes, plus the "Soon!" islands
## (run at 1800x1200).


class Islands extends Control:
	var t := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var ma: GDScript = load("res://scripts/ui/map_art.gd")
		Art.flat(self, Art.rrect_pts(Rect2(Vector2.ZERO, size), 0), Color("6ec3f2"))
		var n: int = ma.WORLDS.size()
		var cols: int = n + ma.SOON_WORLDS.size()
		var k := minf(size.x / (cols * 470.0 + 20.0), size.y / 1150.0)
		for i in cols * 2:
			var c := Vector2(240 + (i % cols) * 470, 300 + (i / cols) * 560) * k
			Art.push(self, c, 0.0, Vector2(k, k))
			var col: int = i % cols
			var lit: bool = i < cols and col < n
			var w: String = ma.WORLDS[col] if col < n else ma.SOON_WORLDS[col - n]
			# Top row lit (and the "Soon!" islands), bottom row the silhouettes.
			var st: int = ma.SOON if col >= n else (ma.CURRENT if lit else (ma.NEXT if col % 2 == 0 else ma.LOCKED))
			ma.island(self, w, st, t, 0)
			if lit:
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
	await process_frame
	TranslationServer.set_locale(lang)
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
		var nw: int = load("res://scripts/ui/map_art.gd").WORLDS.size()
		for i in nw * 2:
			var m: Control = mm.new()
			m.set("location_override", i % nw)
			m.set("big", i >= nw)
			m.position = Vector2(30 + (i % nw) * 175, 40 + (i / nw) * 220)
			host.add_child(m)
	else:
		var v: Control = mv.new()
		host.add_child(v)
		if mode == "hint":
			await process_frame
			v.set("_hint_loc", loc + 1)
			v.set("_hint_left", 99.0)
		if mode == "confirm":
			await process_frame
			v.set("_confirm", true)
			v.call("_build_panel")
			v.call("_layout")
	for i in 8:
		await process_frame
	if OS.get_environment("MAP_DEBUG") != "":
		for n in host.find_children("*", "PanelContainer", true, false):
			print(n.size, " min ", n.get_combined_minimum_size())
		for n in host.find_children("*", "VBoxContainer", true, false):
			print("box ", n.size, " min ", n.get_combined_minimum_size())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
