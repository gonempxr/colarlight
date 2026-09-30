extends SceneTree
## Preview sheet of the pointer hand, every depth's diver, deposit and ore,
## and people holding things (needs a real renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1440x900 \
##     -s res://tests/diver_sheet.gd -- out.png MODE [zoom] [t] [x] [y]
## MODE: pointer | divers | swing | ores | people. t freezes the clock;
## x/y shift the view (sheet points) for magnified crops.

class Sheet extends Control:
	var t := 0.0
	var fixed_t := -1.0
	var zoom := 1.0
	var origin := Vector2.ZERO
	var mode := "divers"

	func _process(d: float) -> void:
		t = fixed_t if fixed_t >= 0.0 else t + d
		queue_redraw()

	func _draw() -> void:
		Art.push(self, Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		Art.push(self, -origin)
		Art.flat(self, PackedVector2Array([Vector2(-50, -50), Vector2(3000, -50), Vector2(3000, 3000), Vector2(-50, 3000)]), Color("7fc8e8"))
		match mode:
			"pointer":
				_pointer()
			"divers":
				_divers()
			"swing":
				_swing()
			"ores":
				_ores()
			"people":
				_people()
		Art.pop(self)
		Art.pop(self)

	func _pointer() -> void:
		var bgs := [Color("7fc8e8"), Color("f8d898"), Color("35507e"), Color("ffffff")]
		for i in 4:
			Art.flat(self, PackedVector2Array([Vector2(i * 300, 0), Vector2(i * 300 + 300, 0), Vector2(i * 300 + 300, 700), Vector2(i * 300, 700)]), bgs[i])
		for i in 8:
			var c := Vector2(90 + (i % 4) * 300, 140 + floori(i / 4.0) * 300)
			PointerArt.draw(self, c, t + i * PointerArt.PERIOD / 8.0, true, -0.5, 1.0)
			Art.disc(self, c, 2.0, Color.RED)
		PointerArt.hand(self, Vector2(1300, 120), 0.0, Vector2(2.0, 2.0))

	func _divers() -> void:
		var arms := ["pick", "pick", "pick", "swim", "rope", "cheer", "idle"]
		for i in Art.DEPTH_STYLE.size():
			var st: Dictionary = Art.DEPTH_STYLE[i]
			var c := Vector2(70 + (i % 10) * 200, 150 + floori(i / 10.0) * 250)
			var arm: String = arms[i % 7]
			Chars.diver(self, c, 1.2, st["suit"], 1.0, 0.0, t, arm, fposmod(t * 0.7 + i * 0.13, 1.0), i % 3 == 1, st["ore"], "happy", false, t + i, i)
			OreArt.deposit(self, c + Vector2(110, 0), 55, i, i * 31 + 3, t, 4)
			Art.text(self, c + Vector2(30, 40), "%d %s" % [i, OreArt.KINDS[i]], 16)

	func _swing() -> void:
		# One diver per tier through the dig cycle, frozen at set phases.
		for tier in Chars.GEAR_TIERS:
			var d := tier * 3
			var st: Dictionary = Art.DEPTH_STYLE[d]
			for k in 6:
				var ph: float = [0.2, 0.52, 0.59, 0.62, 0.645, 0.72][k]
				var c := Vector2(60 + k * 220, 100 + tier * 115)
				Chars.diver(self, c, 0.9, st["suit"], 1.0, 0.0, 0.0, "dig", ph, false, st["ore"], "focus", false, t, d)
				OreArt.deposit(self, c + Vector2(80, 0), 50, d, d * 31 + 3, t, 3)
				Art.disc(self, c + Chars.dig_tip(tier) * 0.9, 2.5, Color.RED)

	func _ores() -> void:
		for i in Art.DEPTH_STYLE.size():
			var c := Vector2(90 + (i % 10) * 195, 130 + floori(i / 10.0) * 250)
			Art.flat(self, PackedVector2Array([c + Vector2(-95, -120), c + Vector2(100, -120), c + Vector2(100, 110), c + Vector2(-95, 110)]), Art.DEPTH_STYLE[i]["water"])
			Art.flat(self, PackedVector2Array([c + Vector2(-95, 0), c + Vector2(100, 0), c + Vector2(100, 40), c + Vector2(-95, 40)]), Art.DEPTH_STYLE[i]["floor"])
			OreArt.deposit(self, c + Vector2(10, 2), 70, i, i * 31 + 3, t, 5)
			OreArt.deposit(self, c + Vector2(60, -70), 40, i, i * 7 + 1, t, 3)
			for k in 3:
				OreArt.chunk(self, c + Vector2(-70 + k * 22, 28), 9.0, i, k * 0.6)
			Chars.item(self, "sack", c + Vector2(-70, -90), Art.DEPTH_STYLE[i]["ore"], i)
			Art.text(self, c + Vector2(0, 100), "%d %s" % [i, OreArt.KINDS[i]], 16)

	func _people() -> void:
		var holds := ["sack", "coinbag", "briefcase", "wrench", "hammer", "clipboard", "coinbag", "sack", "hammer", "coinbag", "clipboard"]
		var arms := [0.2, 0.3, 0.15, 0.3, 2.2 - absf(sin(t * 7.0)) * 1.6, 1.2, 1.9, 2.5, 0.4, 0.3, 1.2]
		for i in holds.size():
			var l := Chars.manager_look(["d0", "d1", "d2", "d3", "d4", "d5", "boat", "plant", "x", "boat2", "plant2"][i])
			Chars.person(self, Vector2(80 + i * 150, 190), 1.4, 1.0 if i % 2 == 0 else -1.0, l, {"emotion": "happy", "arm_r": arms[i], "arm_l": -0.3, "hold": holds[i]})
		for i in 9:
			var l := Chars.manager_look("plant")
			var a := 2.2 - float(i) / 8.0 * 1.6
			Chars.person(self, Vector2(80 + i * 150, 420), 1.4, 1.0, l, {"emotion": "focus", "arm_r": a, "arm_l": 0.3, "hold": "hammer"})
		for i in 6:
			var st: Dictionary = Art.DEPTH_STYLE[i * 4]
			var arm: String = ["swim", "rope", "rope", "swim", "cheer", "idle"][i]
			Chars.diver(self, Vector2(80 + i * 200, 650), 1.3, st["suit"], -1.0 if i < 3 else 1.0, 0.0, t, arm, 0.0, i < 3, st["ore"], "happy", false, t + i * 0.3, i * 4)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://diver_sheet.png"
	var s := Sheet.new()
	s.mode = args[1] if args.size() > 1 else "divers"
	if args.size() > 2:
		s.zoom = float(args[2])
	if args.size() > 3 and float(args[3]) >= 0.0:
		s.fixed_t = float(args[3])
	if args.size() > 5:
		s.origin = Vector2(float(args[4]), float(args[5]))
	root.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
