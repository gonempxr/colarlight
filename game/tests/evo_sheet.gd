extends SceneTree
## Preview sheets of the workers' gear and skins and the player's outfits
## (needs a real renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1600x900 \
##     -s res://tests/evo_sheet.gd -- out.png MODE [world[:code]] [zoom] [t] [x] [y]
## MODE: gear (the 4 gear levels of every world, big) | skins (every skin
## of `world` on each gear level) | forms (gear and skins of `world`: idle,
## dig, walk/swim rows) | cards (revealed and silhouette cards of `world`) |
## small (every world at world size: dig and walk) | poses (one look code in
## every pose) | player (every outfit).

class Sheet extends Control:
	var t := 0.0
	var fixed_t := -1.0
	var zoom := 1.0
	var origin := Vector2.ZERO
	var mode := "forms"
	var world := "ocean"
	var form := 0

	func _process(d: float) -> void:
		t = fixed_t if fixed_t >= 0.0 else t + d
		queue_redraw()

	func _draw() -> void:
		Art.push(self, Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		Art.push(self, -origin)
		var bg: Color = {"ocean": Color("7fc8e8"), "volcano": Color("e8a07f"), "acid": Color("a8d890"), "moon": Color("8a90c0")}.get(world, Color("7fc8e8"))
		Art.flat(self, PackedVector2Array([Vector2(-50, -50), Vector2(4000, -50), Vector2(4000, 4000), Vector2(-50, 4000)]), bg)
		match mode:
			"forms":
				_forms()
			"gear":
				_gear()
			"skins":
				_skins()
			"cards":
				_cards()
			"small":
				_small()
			"poses":
				_poses()
			"player":
				_player()
		Art.pop(self)
		Art.pop(self)

	func _w(pos: Vector2, scale: float, f: int, arm: String, hit: float, carry: bool, emo: String, w: String = "", facing: float = 1.0) -> void:
		var ww := world if w == "" else w
		Chars.diver(self, pos, scale, Color.WHITE, facing, 0.0, t * 1.4, arm, hit, carry, Art.GOLD, emo, Chars.blinking(t, f * 1.3), t + f * 0.3, 0,
				{"world": ww, "form": f})

	## Look codes shown by "forms" and "cards": the 4 gear levels, then every
	## skin of the world on gear level 2.
	func _codes() -> Array[int]:
		var out: Array[int] = []
		for g in WorkerLooks.GEARS:
			out.append(WorkerLooks.code(g))
		for i in Content.skins_of(world).size():
			out.append(WorkerLooks.code(1, i))
		return out

	func _gear() -> void:
		for wi in 4:
			var w: String = WorkerLooks.WORLDS[wi]
			for g in WorkerLooks.GEARS:
				var x := 110.0 + g * 380.0
				var y := 200.0 + wi * 215.0
				_w(Vector2(x, y), 1.9, WorkerLooks.code(g), "idle", 0.0, false, "happy", w)
				_w(Vector2(x + 170, y), 1.3, WorkerLooks.code(g), "dig", fposmod(t * 0.7 + g * 0.13, 1.0), false, "focus", w)

	func _skins() -> void:
		var list := Content.skins_of(world)
		for g in WorkerLooks.GEARS:
			for i in list.size() + 1:
				var x := 50.0 + i * 103.0
				_w(Vector2(x, 200 + g * 215), 1.25, WorkerLooks.code(g, i - 1), "idle", 0.0, false, "happy")
				if g == 0:
					Art.text(self, Vector2(x, 40), str(list[i - 1]["id"]).substr(str(list[i - 1]["id"]).find("_") + 1) if i > 0 else "base", 14)

	func _forms() -> void:
		var codes := _codes()
		for n in codes.size():
			var f: int = codes[n]
			var x := 70.0 + n * 98.0
			_w(Vector2(x, 160), 1.0, f, "idle", 0.0, false, "happy")
			_w(Vector2(x, 330), 1.0, f, "dig", fposmod(t * 0.7 + f * 0.13, 1.0), false, "focus")
			_w(Vector2(x, 500), 1.0, f, "swim" if world == "ocean" else "walk", 0.0, f % 3 == 1, "joy")
			_w(Vector2(x, 670), 1.0, f, "cheer", 0.0, false, "joy")
			_w(Vector2(x, 840), 1.0, f, "rope", 0.0, f % 2 == 0, "strain")
			Art.text(self, Vector2(x + 10, 30), str(f), 18)

	func _cards() -> void:
		var codes := _codes()
		for n in codes.size():
			var f: int = codes[n]
			var c := Vector2(80 + (n % 9) * 150, 110 + floori(n / 9.0) * 170)
			Art.t_rect(self, Rect2(c - Vector2(66, 66), Vector2(132, 132)), 14, Color(1, 1, 1, 0.35), 3.0, 0.0)
			WorkerLooks.draw_card(self, c, 132, world, f, true, t)
			var c2 := c + Vector2(0, 360)
			Art.t_rect(self, Rect2(c2 - Vector2(66, 66), Vector2(132, 132)), 14, Color("3a3060"), 3.0, 0.0)
			WorkerLooks.draw_card(self, c2, 132, world, f, false, t)
		for n in codes.size():
			var f: int = codes[n]
			var c := Vector2(1380 + (n % 3) * 66, 520 + floori(n / 3.0) * 70)
			Art.t_rect(self, Rect2(c - Vector2(30, 30), Vector2(60, 60)), 8, Color("3a3060") if n > 4 else Color(1, 1, 1, 0.35), 2.0, 0.0)
			WorkerLooks.draw_card(self, c, 60, world, f, n <= 4, t)

	func _small() -> void:
		for wi in 4:
			var w: String = WorkerLooks.WORLDS[wi]
			var codes: Array[int] = []
			for g in WorkerLooks.GEARS:
				codes.append(WorkerLooks.code(g))
			for i in Content.skins_of(w).size():
				codes.append(WorkerLooks.code(3, i))
			for n in codes.size():
				var f: int = codes[n]
				var x := 40.0 + n * 72.0
				_w(Vector2(x, 100 + wi * 200), 0.62, f, "dig", fposmod(t * 0.7 + f * 0.13, 1.0), false, "focus", w)
				_w(Vector2(x + 20, 190 + wi * 200), 0.62, f, "swim" if w == "ocean" else "walk", 0.0, f % 2 == 0, "happy", w, -1.0)

	func _poses() -> void:
		var arms := ["idle", "dig", "pick", "swim", "walk", "rope", "cheer", "show"]
		var emos := Chars.EMOTIONS.keys()
		for i in arms.size():
			_w(Vector2(90 + i * 190, 200), 1.4, form, arms[i], fposmod(t * 0.7, 1.0), i == 3, "happy")
		for i in emos.size():
			_w(Vector2(80 + i * 130, 450), 1.4, form, "idle", 0.0, false, emos[i])
			Art.text(self, Vector2(80 + i * 130, 480), emos[i], 16)
		_w(Vector2(80, 700), 1.4, form, "idle", 0.0, false, "happy", "", 1.0)
		Chars.diver(self, Vector2(250, 700), 1.4, Color.WHITE, 1.0, 0.0, t, "idle", 0.0, false, Art.GOLD, "happy", true, t, 0, {"world": world, "form": form})

	func _player() -> void:
		var outfits := ["outfit_casual", "outfit_captain", "outfit_pirate", "outfit_chef", "outfit_scientist", "outfit_astronaut",
				"outfit_knight", "outfit_wizard", "outfit_king", "outfit_superhero"]
		var poses := ["idle", "wave", "cheer", "collect"]
		var looks := [Chars.default_avatar(), Chars.look(3, "long", 3, "flower", "freckles", 2, "shirt"), Chars.look(4, "curly", 0, "cap", "glasses", 4, "overalls")]
		for i in outfits.size():
			var x := 80.0 + i * 150.0
			for j in 3:
				var p: String = poses[(i + j) % poses.size()] if j > 0 else "stand"
				Chars.player(self, Vector2(x, 200 + j * 230), 1.4, looks[j], outfits[i], {"pose": p, "t": t})
			Art.text(self, Vector2(x, 900), outfits[i].substr(7), 16)
			Art.t_rect(self, Rect2(Vector2(x - 40, 760), Vector2(80, 80)), 10, Color(1, 1, 1, 0.4), 2.0, 0.0)
			Chars.outfit_icon(self, Vector2(x, 800), 80, outfits[i])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://evo_sheet.png"
	var s := Sheet.new()
	s.mode = args[1] if args.size() > 1 else "forms"
	if args.size() > 2:
		var w := args[2]
		if ":" in w:
			s.form = int(w.split(":")[1])
			w = w.split(":")[0]
		s.world = w
	if args.size() > 3:
		s.zoom = float(args[3])
	if args.size() > 4 and float(args[4]) >= 0.0:
		s.fixed_t = float(args[4])
	if args.size() > 6:
		s.origin = Vector2(float(args[5]), float(args[6]))
	root.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
