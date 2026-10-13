extends SceneTree
## Screenshot of the puzzle screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 720x1280 \
##     -s res://tests/puzzle_shot.gd -- out.png [board|anim|win|out|out_ad|select|tiles] [level] [lang] [world 0..4]
## tiles: a sheet of the world's six pieces (plain, selected), the specials and the blockers.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://puzzle.png"
	var mode := args[1] if args.size() > 1 else "board"
	var n := int(args[2]) if args.size() > 2 else 12
	var lang := args[3] if args.size() > 3 else "en"
	var world := int(args[4]) if args.size() > 4 else 0
	await process_frame
	for l in ["en", "ru", "es", "zh"]:
		var res := load("res://i18n/puzzle.%s.translation" % l)
		if res:
			TranslationServer.add_translation(res)
	TranslationServer.set_locale(lang)
	if mode == "tiles":
		await _tiles(world)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out)
		quit()
		return
	var bg := ColorRect.new()
	bg.color = Art.SEA_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if mode == "win":
		# Online present: the win panel shows the puzzle board button.
		root.get_node("Online").backend = RefCounted.new()
	var screen: Control = load("res://scripts/puzzle/puzzle_screen.gd").new()
	screen.world = world
	root.add_child(screen)
	screen.setup(PuzzleLevels.level(n), func(r: Dictionary) -> Array:
		return [["coin", "+%d" % (250 * maxi(1, r["fragments"]))], ["pearl", "+%d" % (r["stars"] + 1)]])
	for i in 20:
		await process_frame
	var m: Match3 = screen.model
	match mode:
		"anim":
			# Specials on the board, then a rocket + bomb combo caught mid-blast.
			m.put(Vector2i(1, 2), 0, "rocket_v")
			m.put(Vector2i(5, 1), 0, "rainbow")
			m.put(Vector2i(3, 4), 0, "rocket_h")
			m.put(Vector2i(4, 4), 0, "bomb")
			screen._grid = m.snapshot()
			for i in 30:
				await process_frame
			screen._run(m.swap(Vector2i(3, 4), Vector2i(4, 4)))
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 330:
				await process_frame
		"win":
			m.fragments_collected = m.fragments_needed - 1
			screen._shown_frags = m.fragments_collected
			m.fragments_needed = m.fragments_collected
			var h := m.find_hint()
			screen._run(m.swap(h[0], h[1]))
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 4200:
				await process_frame
		"out", "out_ad":
			if mode == "out_ad":
				# The free +5 is used; with ads on, the second +5 is for an ad.
				root.get_node("Platform").set_provider("test")
				screen._extra_used = true
			m.moves = 1
			m.fragments_collected = 1
			screen._shown_frags = 1
			m.fragments_needed = 99
			var h := m.find_hint()
			screen._run(m.swap(h[0], h[1]))
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 3500:
				await process_frame
			m.fragments_needed = PuzzleLevels.level(n)["fragments"]
		"select":
			var h := m.find_hint()
			screen._selected = h[0]
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 6000:
				await process_frame
		_:
			for i in 40:
				await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()


## Every piece of a world big, then selected, the specials and the blockers.
func _tiles(world: int) -> void:
	TileArt.world = world
	var back := Color(["1a5c96", "3a1a20", "1f3a1a", "1a1a3a", "173d34"][world])
	var v := ArtView.make(func(ci: CanvasItem, s: Vector2, t: float):
		Art.flat(ci, Art.rrect_pts(Rect2(Vector2.ZERO, s), 0.0), back)
		var cell := minf(s.x / 6.0, s.y / 4.5)
		var k := cell / 62.0
		for i in 6:
			for row in 2:
				Art.push(ci, Vector2(cell * (i + 0.5), cell * (row + 0.6)), 0.0, Vector2.ONE * k)
				TileArt.draw(ci, TileArt.KINDS[i], 0.4 + i * 0.5, row == 1)
				Art.pop(ci)
		var extras := [["s", "rocket_h"], ["s", "rocket_v"], ["s", "bomb"], ["s", "rainbow"], ["b", "sand", 1], ["b", "sand", 2]]
		for i in extras.size():
			var e: Array = extras[i]
			Art.push(ci, Vector2(cell * (i + 0.5), cell * 2.8), 0.0, Vector2.ONE * k)
			if e[0] == "s":
				TileArt.special(ci, e[1], 0.3 + i * 0.2)
			else:
				TileArt.blocker(ci, e[1], e[2])
			Art.pop(ci)
		for i in 2:
			Art.push(ci, Vector2(cell * (i + 0.5), cell * 3.9), 0.0, Vector2.ONE * k)
			TileArt.draw(ci, TileArt.KINDS[i + 2], 0.5)
			TileArt.blocker(ci, "bubble", i + 1)
			Art.pop(ci)
		# Small, like on a phone board.
		for i in 6:
			Art.push(ci, Vector2(cell * 2.3 + i * cell * 0.62, cell * 3.9), 0.0, Vector2.ONE * (cell * 0.55 / 62.0))
			TileArt.draw(ci, TileArt.KINDS[i], 0.4)
			Art.pop(ci), Vector2.ZERO, false)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	for i in 5:
		await process_frame
