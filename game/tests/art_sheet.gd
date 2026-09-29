extends SceneTree
## Preview sheet of artifacts, fragments, pets, hats and match-3 tiles:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1600x1400 -s res://tests/art_sheet.gd -- out.png [zoom] [x] [y] [t]
## zoom/x/y render a magnified crop whose top-left corner is sheet point (x, y);
## t freezes the animation clock at that time (default: runs ~10 frames).

class Sheet extends Control:
	var t := 0.0
	var fixed_t := -1.0
	var zoom := 1.0
	var origin := Vector2.ZERO

	func _process(d: float) -> void:
		t = fixed_t if fixed_t >= 0.0 else t + d
		queue_redraw()

	func _draw() -> void:
		Art.push(self, Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		Art.push(self, -origin)
		Art.flat(self, PackedVector2Array([Vector2(-50, -50), Vector2(1700, -50), Vector2(1700, 1500), Vector2(-50, 1500)]), Color("7fc8e8"))
		_artifacts()
		_pets()
		_hats()
		_tiles()
		Art.pop(self)
		Art.pop(self)

	func _artifacts() -> void:
		for i in ArtifactArt.IDS.size():
			var c := Vector2(110 + (i % 6) * 200, 110 + floori(i / 6.0) * 200)
			Art.push(self, c)
			ArtifactArt.background(self, 190.0)
			ArtifactArt.draw(self, ArtifactArt.IDS[i], t + i * 0.7)
			Art.pop(self)
		for i in ArtifactArt.IDS.size():
			var c := Vector2(1330 + (i % 4) * 78, 70 + floori(i / 4.0) * 90)
			Art.push(self, c, 0.0, Vector2(1.3, 1.3))
			ArtifactArt.fragment(self, ArtifactArt.IDS[i], t + i * 0.9)
			Art.pop(self)

	func _pets() -> void:
		for row in 4:
			var facing := 1.0 if row % 2 == 0 else -1.0
			var happy := row >= 2
			for i in PetArt.IDS.size():
				var c := Vector2(70 + i * 130, 470 + row * 95)
				Art.push(self, c, 0.0, Vector2(2, 2))
				PetArt.draw(self, PetArt.IDS[i], t + i * 0.37 + row * 0.2, facing, happy)
				Art.pop(self)

	func _hats() -> void:
		var hairs := ["short", "long", "spiky", "curly", "bun", "short", "long", "mohawk", "bald", "short", "curly", "spiky", "long", "short"]
		for i in HatsArt.IDS.size():
			var l := Chars.look(i % 6, hairs[i], i % 8, "none", "none", i % 8, Chars.CLOTHES[i % 6])
			var c := Vector2(60 + i * 112, 905)
			var r := 44.0
			Chars.portrait(self, c, r, l, "happy", false, Art.DEPTH_STYLE[i % 6]["water"].lightened(0.3))
			Art.push(self, c, 0.0, Vector2.ONE * (r / 50.0))
			Art.push(self, Vector2.ZERO, 0.0, Vector2(1.3, 1.3))
			HatsArt.draw(self, HatsArt.IDS[i])
			Art.pop(self)
			Art.pop(self)
			var feet := Vector2(60 + i * 112, 1160)
			var facing := 1.0 if i % 2 == 0 else -1.0
			Chars.person(self, feet, 1.0, facing, l, {"emotion": "happy"})
			Art.push(self, feet, 0.0, Vector2(facing, 1.0))
			Art.push(self, Vector2(1, -68))
			HatsArt.draw(self, HatsArt.IDS[i])
			Art.pop(self)
			Art.pop(self)

	func _tiles() -> void:
		var x := 44.0
		var y := 1250.0
		var cells: Array = []
		for k in TileArt.KINDS:
			cells.append(["tile", k, false])
		for k in TileArt.KINDS:
			cells.append(["tile", k, true])
		for k in TileArt.SPECIALS:
			cells.append(["special", k, false])
		cells.append(["sand", "", 1])
		cells.append(["sand", "", 2])
		cells.append(["bubble", "pearl", 1])
		cells.append(["bubble", "fish", 2])
		for i in cells.size():
			var c := Vector2(x + i * 64, y)
			Art.flat(self, Art.rrect_pts(Rect2(c - Vector2(29, 29), Vector2(58, 58)), 8), Color(0.08, 0.2, 0.45, 0.35 if i % 2 == 0 else 0.25))
			Art.push(self, c)
			var e: Array = cells[i]
			match e[0]:
				"tile":
					TileArt.draw(self, e[1], t + i * 0.3, e[2])
				"special":
					TileArt.special(self, e[1], t + i * 0.3)
				"sand":
					TileArt.blocker(self, "sand", e[2])
				"bubble":
					TileArt.draw(self, e[1], t)
					TileArt.blocker(self, "bubble", e[2])
			Art.pop(self)
		# The same pieces bigger, on a board, to check readability.
		var board := ["pearl", "shell", "starfish", "coral", "fish", "urchin", "fish", "pearl", "coral", "starfish", "urchin", "shell"]
		for i in board.size():
			var c := Vector2(44 + i * 64, 1340)
			Art.flat(self, Art.rrect_pts(Rect2(c - Vector2(29, 29), Vector2(58, 58)), 8), Color(0.08, 0.2, 0.45, 0.35 if i % 2 == 0 else 0.25))
			Art.push(self, c)
			TileArt.draw(self, board[i], t + i * 0.5)
			Art.pop(self)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://art_sheet.png"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var s := Sheet.new()
	s.size = Vector2(1600, 1400)
	if args.size() > 1:
		s.zoom = float(args[1])
	if args.size() > 3:
		s.origin = Vector2(float(args[2]), float(args[3]))
	if args.size() > 4:
		s.fixed_t = float(args[4])
	root.add_child(s)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
