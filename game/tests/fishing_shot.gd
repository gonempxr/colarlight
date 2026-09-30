extends SceneTree
## Screenshots of the fishing screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/fishing_shot.gd -- out.png [lang] [mode]
## modes: sheet (every fish + silhouettes), idle, wait, bite, reel,
##   catch:<fish id>, full, escaped, helper, land, bucket, book, shop.
## Uses its own save files, never the player's.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://fishing.png"
	var lang := args[1] if args.size() > 1 else "en"
	var mode := args[2] if args.size() > 2 else "idle"
	await process_frame
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	var fishing := root.get_node("Fishing")
	var progress := root.get_node("Progress")
	for n: Node in [gs, fishing, progress]:
		n.autosave_enabled = false
	gs.save_path = "user://shot_game.json"
	progress.save_path = "user://shot_progress.json"
	fishing.save_path = "user://shot_fishing.json"
	gs.reset()
	fishing.reset()
	fishing.rng.seed = 7
	gs.coins = 12500.0
	var bg := ColorRect.new()
	bg.color = Art.SEA_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	if mode == "sheet":
		await _sheet()
	else:
		await _screen(mode, fishing)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()


func _sheet() -> void:
	var v := ArtView.make(func(ci: CanvasItem, s: Vector2, t: float):
		Art.flat(ci, Art.rrect_pts(Rect2(Vector2.ZERO, s), 0.0), Color("cfeaff"))
		var ids := FishData.ids()
		var cols := 4
		var cw := s.x / cols
		var ch := 150.0
		for i in ids.size():
			var p := Vector2(cw * (i % cols) + cw / 2.0, ch * (i / cols) + 80.0)
			var r := FishData.rarity_of(ids[i])
			FishArt.glow(ci, p, 60.0, r, 0.4)
			Art.push(ci, p, 0.0, Vector2.ONE * 1.3)
			FishArt.draw(ci, ids[i], 0.6 + i * 0.3)
			Art.pop(ci)
			Art.text(ci, p + Vector2(0, 66), ids[i], 18, FishData.rarity_color(r), 5)
		var y := ch * ceilf(ids.size() / float(cols)) + 60.0
		for i in 4:
			Art.push(ci, Vector2(cw * i + cw / 2.0, y), 0.0, Vector2.ONE * 1.1)
			FishArt.draw(ci, ids[i * 5 % ids.size()], 0.0, 1.0, false, true)
			Art.pop(ci)
		for i in 4:
			Art.push(ci, Vector2(cw * i + cw / 2.0, y + 130.0), 0.0, Vector2.ONE * 1.3)
			FishArt.draw(ci, ids[(i * 5 + 3) % ids.size()], 0.0, 1.0, true)
			Art.pop(ci)
		Art.push(ci, Vector2(cw * 0.5, y + 260.0))
		FishArt.bucket(ci, 3, 0.0, true)
		Art.pop(ci)
		Art.push(ci, Vector2(cw * 1.5, y + 230.0))
		FishArt.book(ci, 0.0)
		Art.pop(ci)
		Art.push(ci, Vector2(cw * 2.5, y + 230.0))
		FishArt.rod_icon(ci, 0.0)
		Art.pop(ci), Vector2.ZERO, false)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	var tr := TextureRect.new()
	tr.texture = FishArt.icon(96)
	tr.position = Vector2(560, 1380)
	root.add_child(tr)
	for i in 5:
		await process_frame


func _screen(mode: String, fishing: Node) -> void:
	var screen: Control = load("res://scripts/fishing/fishing_screen.gd").new()
	root.add_child(screen)
	for i in 10:
		await process_frame
	match mode:
		"wait":
			screen.debug_state("wait")
		"bite":
			screen.debug_state("bite")
		"reel":
			screen.debug_state("reel")
		"escaped":
			screen.debug_state("escaped")
		"helper":
			fishing.helper = 2
			for i in 4:
				fishing.keep(fishing.make_fish(i % 2))
			fishing.helper_timer = fishing.helper_interval() * 0.6
			screen.debug_state("wait")
		"land":
			screen.debug_state("reel")
			screen._speed = 0.0
			screen._hits = FishData.REEL_HITS - 1
			screen._marker = screen._zone
			screen._reel_tap()
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 450:
				await process_frame
		"full", "bucket":
			for i in fishing.capacity():
				fishing.keep(fishing.make_fish([0, 0, 1, 0, 2, 1, 0, 3, 0, 4][i % 10]))
			if mode == "bucket":
				screen.open_panel("bucket")
			else:
				screen.debug_state("catch:golden")
		"book":
			for id in FishData.ids().slice(0, 11):
				fishing.record(fishing.make_fish(FishData.rarity_of(id)).merged({"id": id}, true))
			fishing.record({"id": "koi", "size": 60.0, "value": 10.0})
			screen.open_panel("book")
		"shop":
			fishing.rod = 2
			fishing.helper = 1
			screen.open_panel("shop")
		_:
			if mode.begins_with("catch:"):
				screen.debug_state(mode)
	if mode == "land":
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await process_frame
