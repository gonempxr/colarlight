extends SceneTree
## Store art drawn from the game's own pieces (Art, Chars, OreArt): a hero
## diver digging at a treasure, the crew, the reef and the logo.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1920x1080 \
##     -s res://tests/promo_art.gd -- out.png banner|portrait|square|icon
## banner 1920x1080, portrait 800x1200, square 800x800 (logo), icon 512x512
## (no text, for small tiles and the page icon).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://promo.png"
	var kind := args[1] if args.size() > 1 else "banner"
	await process_frame
	var art := PromoArt.new()
	art.kind = kind
	root.add_child(art)
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()


class PromoArt extends Control:
	static var HIT := 0.12
	var kind := "banner"
	var _logo: Texture2D
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var v := get_viewport_rect().size
		var share: float = {"banner": 0.5, "portrait": 0.9, "square": 0.82}.get(kind, 0.0)
		if share > 0.0:
			var svg := FileAccess.get_file_as_string("res://assets/logo.svg")
			var probe := Image.new()
			probe.load_svg_from_string(svg, 1.0)
			var img := Image.new()
			img.load_svg_from_string(svg, v.x * share / probe.get_width())
			_logo = ImageTexture.create_from_image(img)

	func _draw() -> void:
		var v := size
		_rng.seed = 7
		match kind:
			"banner":
				_banner(v)
			"portrait":
				_portrait(v)
			"square":
				_square(v)
			_:
				_icon(v)
		Art.flush()

	# --- scenes -----------------------------------------------------------

	func _banner(v: Vector2) -> void:
		var floor_y := v.y * 0.80
		_water(v, Vector2(v.x * 0.62, -v.y * 0.25))
		_far_reef(v, floor_y - v.y * 0.04, 0.9)
		_kelp_row(v, floor_y, [0.04, 0.09, 0.93, 0.975], v.y * 0.42)
		_seabed(v, floor_y)
		var s := v.y / 1080.0
		# Treasure on the right, the hero digging at it.
		var chest := Vector2(v.x * 0.74, floor_y + 18 * s)
		Art.glow(self, chest + Vector2(0, -90 * s), 420 * s, Color(1.0, 0.85, 0.35, 0.55))
		OreArt.deposit(self, chest, 260 * s, 6, 3, 0.4, 7)
		OreArt.deposit(self, Vector2(v.x * 0.90, floor_y + 22 * s), 170 * s, 5, 1, 0.2, 5)
		OreArt.deposit(self, Vector2(v.x * 0.10, floor_y + 22 * s), 190 * s, 1, 4, 0.3, 6)
		OreArt.deposit(self, Vector2(v.x * 0.24, floor_y + 26 * s), 150 * s, 2, 2, 0.6, 4)
		OreArt.deposit(self, Vector2(v.x * 0.40, floor_y + 30 * s), 110 * s, 0, 5, 0.1, 4)
		_diver(Vector2(v.x * 0.56, floor_y + 6 * s), 4.3 * s, 1.0, "pick", HIT, false, 0, "joy")
		# The crew: one swims up with a full sack, one comes down to help.
		_diver(Vector2(v.x * 0.335, v.y * 0.66), 2.3 * s, 1.0, "swim", 0.0, true, 1, "joy", -0.35, 0.6)
		_diver(Vector2(v.x * 0.88, v.y * 0.40), 1.7 * s, -1.0, "swim", 0.0, true, 2, "happy", 0.25, 1.7)
		_fish_school(v, Vector2(v.x * 0.14, v.y * 0.42), 6, 34 * s, 1.0)
		_fish_school(v, Vector2(v.x * 0.90, v.y * 0.58), 3, 36 * s, -1.0)
		_bubbles(v, Vector2(v.x * 0.60, v.y * 0.42), 9, 34 * s)
		_bubbles(v, Vector2(v.x * 0.36, v.y * 0.48), 6, 26 * s)
		_vignette(v)
		_logo_at(Vector2(v.x * 0.30, v.y * 0.25))

	func _portrait(v: Vector2) -> void:
		var floor_y := v.y * 0.83
		_water(v, Vector2(v.x * 0.5, -v.y * 0.2))
		_far_reef(v, floor_y - v.y * 0.03, 1.0)
		_kelp_row(v, floor_y, [0.05, 0.95], v.y * 0.36)
		_seabed(v, floor_y)
		var s := v.x / 800.0
		var chest := Vector2(v.x * 0.68, floor_y + 14 * s)
		Art.glow(self, chest + Vector2(0, -70 * s), 330 * s, Color(1.0, 0.85, 0.35, 0.55))
		OreArt.deposit(self, chest, 210 * s, 6, 3, 0.4, 7)
		OreArt.deposit(self, Vector2(v.x * 0.11, floor_y + 18 * s), 150 * s, 1, 4, 0.3, 5)
		OreArt.deposit(self, Vector2(v.x * 0.93, floor_y + 22 * s), 120 * s, 5, 1, 0.2, 4)
		_diver(Vector2(v.x * 0.36, floor_y + 4 * s), 3.5 * s, 1.0, "pick", HIT, false, 0, "joy")
		_diver(Vector2(v.x * 0.74, v.y * 0.55), 2.0 * s, -1.0, "swim", 0.0, true, 1, "joy", 0.3, 0.6)
		_diver(Vector2(v.x * 0.22, v.y * 0.47), 1.5 * s, 1.0, "swim", 0.0, true, 2, "happy", -0.3, 1.7)
		_fish_school(v, Vector2(v.x * 0.80, v.y * 0.38), 4, 30 * s, -1.0)
		_bubbles(v, Vector2(v.x * 0.45, v.y * 0.55), 8, 26 * s)
		_vignette(v)
		_logo_at(Vector2(v.x * 0.5, v.y * 0.18))

	func _square(v: Vector2) -> void:
		var floor_y := v.y * 0.84
		_water(v, Vector2(v.x * 0.5, -v.y * 0.25))
		_far_reef(v, floor_y - v.y * 0.03, 1.0)
		_seabed(v, floor_y)
		var s := v.x / 800.0
		var chest := Vector2(v.x * 0.72, floor_y + 14 * s)
		Art.glow(self, chest + Vector2(0, -60 * s), 300 * s, Color(1.0, 0.85, 0.35, 0.6))
		OreArt.deposit(self, chest, 190 * s, 6, 3, 0.4, 7)
		OreArt.deposit(self, Vector2(v.x * 0.08, floor_y + 18 * s), 130 * s, 1, 4, 0.3, 5)
		_diver(Vector2(v.x * 0.40, floor_y + 4 * s), 3.0 * s, 1.0, "pick", HIT, false, 0, "joy")
		_diver(Vector2(v.x * 0.84, v.y * 0.50), 1.5 * s, -1.0, "swim", 0.0, true, 1, "joy", 0.3, 0.6)
		_bubbles(v, Vector2(v.x * 0.5, v.y * 0.56), 7, 24 * s)
		_vignette(v)
		_logo_at(Vector2(v.x * 0.5, v.y * 0.21))

	## The page icon: the hero's face up close, a gold coin and bubbles.
	func _icon(v: Vector2) -> void:
		_water(v, Vector2(v.x * 0.3, -v.y * 0.3))
		var s := v.x / 512.0
		Art.glow(self, Vector2(v.x * 0.72, v.y * 0.62), 300 * s, Color(1.0, 0.86, 0.4, 0.5))
		_seabed(v, v.y * 0.9)
		OreArt.deposit(self, Vector2(v.x * 0.80, v.y * 0.95), 190 * s, 6, 3, 0.4, 6)
		_diver(Vector2(v.x * 0.36, v.y * 1.02), 4.1 * s, 1.0, "pick", HIT, false, 0, "joy")
		_bubbles(v, Vector2(v.x * 0.86, v.y * 0.42), 5, 26 * s)
		_vignette(v)

	# --- pieces -----------------------------------------------------------

	func _water(v: Vector2, sun: Vector2) -> void:
		var top := Color("7fe6ee")
		var mid := Color("23a6cf")
		var deep := Color("12508f")
		Art.grad(self, PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), Vector2(v.x, v.y * 0.45), Vector2(0, v.y * 0.45)]),
				PackedColorArray([top, top, mid, mid]))
		Art.grad(self, PackedVector2Array([Vector2(0, v.y * 0.45), Vector2(v.x, v.y * 0.45), v, Vector2(0, v.y)]),
				PackedColorArray([mid, mid, deep, deep]))
		# Sun rays from above the surface.
		var r := v.length() * 1.3
		for i in 11:
			var a := PI * 0.5 + (i - 5) * 0.13 + _rng.randf_range(-0.03, 0.03)
			var w := _rng.randf_range(0.018, 0.04)
			var c := Color(1.0, 1.0, 0.86, _rng.randf_range(0.10, 0.2))
			Art.grad(self, PackedVector2Array([sun, sun + Vector2(cos(a - w), sin(a - w)) * r, sun + Vector2(cos(a + w), sin(a + w)) * r]),
					PackedColorArray([c, Color(c, 0.0), Color(c, 0.0)]))
		# Caustic light on the surface band.
		for i in 14:
			var p := Vector2(_rng.randf_range(0, v.x), _rng.randf_range(0, v.y * 0.12))
			Art.flat(self, Art.ellipse_pts(p, Vector2(_rng.randf_range(40, 110), _rng.randf_range(6, 12)) * v.y / 1080.0), Color(1, 1, 1, 0.12))

	func _far_reef(v: Vector2, y: float, h: float) -> void:
		var far := Color("2a7fb3")
		var pts := PackedVector2Array([Vector2(0, v.y)])
		var n := 14
		for i in n + 1:
			var x := v.x * i / n
			pts.append(Vector2(x, y - (sin(i * 1.7) * 0.5 + 0.5) * v.y * 0.09 * h - v.y * 0.03))
		pts.append(Vector2(v.x, v.y))
		Art.flat(self, pts, Color(far, 0.55))
		# Faint coral fans on the far rocks.
		for i in 6:
			var x := v.x * (0.08 + i * 0.17) + _rng.randf_range(-30, 30)
			Art.flat(self, Art.ellipse_pts(Vector2(x, y - v.y * 0.1), Vector2(46, 34) * v.y / 1080.0 * h), Color("4a9ccc", 0.6))

	func _kelp_row(v: Vector2, floor_y: float, xs: Array, h: float) -> void:
		for x_share in xs:
			for k in 2:
				var x: float = v.x * x_share + k * 26.0 * v.y / 1080.0
				var pts := PackedVector2Array()
				var hh := h * (1.0 - k * 0.25)
				for j in 9:
					var u := j / 8.0
					pts.append(Vector2(x + sin(u * 5.0 + k) * 22.0 * v.y / 1080.0, floor_y + 20 - u * hh))
				Art.polyline(self, pts, Art.INK, 22.0 * v.y / 1080.0)
				Art.polyline(self, pts, Art.GREEN if k == 0 else Art.GREEN_DARK, 14.0 * v.y / 1080.0)

	func _seabed(v: Vector2, y: float) -> void:
		var pts := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var x := v.x * i / n
			pts.append(Vector2(x, y + sin(i * 0.9) * v.y * 0.012 - sin(i * 0.31) * v.y * 0.02))
		pts.append(Vector2(v.x + 20, v.y + 20))
		pts.append(Vector2(-20, v.y + 20))
		Art.toon(self, pts, Art.SAND, 5.0, 1.0)
		# Pebbles and shells in the sand.
		for i in 18:
			var p := Vector2(_rng.randf_range(0, v.x), _rng.randf_range(y + v.y * 0.05, v.y))
			Art.flat(self, Art.ellipse_pts(p, Vector2(_rng.randf_range(6, 14), _rng.randf_range(3, 6)) * v.y / 1080.0), Art.SAND_DARK)

	func _diver(at: Vector2, sc: float, facing: float, arm: String, hit: float, carry: bool, depth: int, emo: String,
			tilt: float = 0.0, t: float = 0.0) -> void:
		var suit: Color = Art.DEPTH_STYLE[depth]["suit"]
		var ore: Color = Art.DEPTH_STYLE[depth]["ore"]
		# A soft shadow on the sand for the ones standing.
		if arm in ["pick", "dig", "cheer", "idle"]:
			Art.flat(self, Art.ellipse_pts(at + Vector2(0, 2), Vector2(34, 7) * sc), Color(Art.SHADE, 0.25))
		Chars.diver(self, at, sc, suit, facing, tilt, 0.6 if arm == "swim" else 0.0, arm, hit, carry, ore, emo, false, t, depth,
				{"kick_amp": 1.0 if arm == "swim" else 0.0})

	func _fish_school(v: Vector2, c: Vector2, n: int, sz: float, facing: float) -> void:
		var cols := [Art.GOLD, Art.CORAL, Color("ff8fc0"), Art.TEAL]
		for i in n:
			var p := c + Vector2(_rng.randf_range(-1, 1) * sz * 3.2, _rng.randf_range(-1, 1) * sz * 1.8)
			Art.fish(self, p, sz * _rng.randf_range(0.8, 1.15), cols[i % cols.size()], facing, i * 0.7)

	func _bubbles(v: Vector2, c: Vector2, n: int, r: float) -> void:
		for i in n:
			var p := c + Vector2(_rng.randf_range(-0.6, 0.6) * r * 2.5, -i * r * 1.6 - _rng.randf_range(0, r))
			var rr := r * _rng.randf_range(0.35, 0.8)
			Art.disc(self, p, rr, Color(0.85, 0.97, 1.0, 0.16))
			Art.polyline(self, Art.ellipse_pts(p, Vector2(rr, rr)), Color(1, 1, 1, 0.75), maxf(2.0, rr * 0.14), true)
			Art.disc(self, p + Vector2(-rr * 0.38, -rr * 0.38), rr * 0.22, Color(1, 1, 1, 0.9))

	func _vignette(v: Vector2) -> void:
		var e := Color(Art.SEA_ABYSS, 0.0)
		var d := Color(Art.SEA_ABYSS, 0.35)
		var w := minf(v.x, v.y) * 0.18
		Art.grad(self, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, v.y), Vector2(0, v.y)]), PackedColorArray([d, e, e, d]))
		Art.grad(self, PackedVector2Array([Vector2(v.x - w, 0), Vector2(v.x, 0), v, Vector2(v.x - w, v.y)]), PackedColorArray([e, d, d, e]))

	func _logo_at(c: Vector2) -> void:
		if _logo == null:
			return
		Art.flush()
		var ls := Vector2(_logo.get_size())
		Art.push(self, c, 0.0, Vector2(1.0, 0.5))
		Art.glow(self, Vector2.ZERO, ls.x * 0.62, Color(0.04, 0.12, 0.32, 0.35), 40)
		Art.pop(self)
		Art.flush()
		draw_texture(_logo, c - ls * 0.5)
