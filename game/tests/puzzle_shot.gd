extends SceneTree
## Screenshot of the puzzle screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 720x1280 \
##     -s res://tests/puzzle_shot.gd -- out.png [board|anim|win|out] [level] [lang]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://puzzle.png"
	var mode := args[1] if args.size() > 1 else "board"
	var n := int(args[2]) if args.size() > 2 else 12
	var lang := args[3] if args.size() > 3 else "en"
	await process_frame
	for l in ["en", "ru", "es", "zh"]:
		var res := load("res://i18n/puzzle.%s.translation" % l)
		if res:
			TranslationServer.add_translation(res)
	TranslationServer.set_locale(lang)
	var bg := ColorRect.new()
	bg.color = Art.SEA_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var screen: Control = load("res://scripts/puzzle/puzzle_screen.gd").new()
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
		"out":
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
