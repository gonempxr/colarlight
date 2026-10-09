extends SceneTree
## Store covers (CrazyGames: 1920x1080, 800x1200, 800x800): the living mine
## without any interface, a soft sunburst and the logo on top.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1920x1080 \
##     -s res://tests/cover_shot.gd -- out.png [logo_width_share] [logo_y_share] [scroll]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://cover.png"
	var logo_w := float(args[1]) if args.size() > 1 else 0.6
	var logo_y := float(args[2]) if args.size() > 2 else 0.2
	var scroll := float(args[3]) if args.size() > 3 else 0.0
	var zoom := float(args[4]) if args.size() > 4 else 0.0
	await process_frame
	root.get_node("Settings").language = "en"
	TranslationServer.set_locale("en")
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://cover_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://cover_progress.json"
	pr.reset()
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	pr.owned["pet_octopus"] = true
	pr.equipped["pet"] = "pet_octopus"
	pr.apply_bonus()
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "d3": 6, "lift": 40, "boat": 45, "plant": 41}, true)
	for k in ["d0", "d1", "d2", "d3", "lift", "boat", "plant"]:
		gs.managers[k] = true
	gs.coins = 48250.0
	gs.hold = 1840.0
	gs.dock = 620.0
	gs.evo = 1
	load("res://scripts/ui/day_night.gd").fixed_phase = 0.2
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	for i in 120:
		gs.advance(0.05)
		await process_frame
	var v: Vector2 = root.get_visible_rect().size
	# Only the background and the mine stay; the mine fills the screen.
	for c in main.get_children():
		if c != main._scroller and not (c is ColorRect):
			if c is CanvasItem:
				c.visible = false
	main._evo_card.visible = false
	main.set_process(false)
	main._scroller.position = Vector2.ZERO
	main._scroller.size = v
	main._scroller.zoom = zoom if zoom > 0.0 else clampf(v.x / 760.0, 1.0, 2.6)
	await process_frame
	main._scroller.scroll_to(scroll)
	var art := CoverArt.new()
	art.logo_w = logo_w
	art.logo_y = logo_y
	root.add_child(art)
	for i in 30:
		gs.advance(0.03)
		_hide_ui(main)
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()


## Cards and buttons get shown again by layout passes: hide them every frame.
func _hide_ui(main: Node) -> void:
	for c in main.get_children():
		if c != main._scroller and not (c is ColorRect) and c is CanvasItem:
			c.visible = false
	for n in main._scroller.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		var path := sc.resource_path if sc != null else ""
		if n is Button or path.ends_with("_card.gd"):
			n.visible = false
			n.modulate.a = 0.0


class CoverArt extends Control:
	var logo_w := 0.6
	var logo_y := 0.2
	var _logo: Texture2D

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := get_viewport_rect().size
		var svg := FileAccess.get_file_as_string("res://assets/logo.svg")
		var probe := Image.new()
		probe.load_svg_from_string(svg, 1.0)
		var img := Image.new()
		img.load_svg_from_string(svg, v.x * logo_w / probe.get_width())
		_logo = ImageTexture.create_from_image(img)

	func _draw() -> void:
		var v := size
		var ls := Vector2(_logo.get_size())
		var c := Vector2(v.x * 0.5, v.y * logo_y + ls.y * 0.5)
		# A soft blue glow behind the logo so it reads over the busy scene.
		for i in 12:
			var k := 1.0 - i / 12.0
			draw_circle(c, ls.x * (0.25 + 0.5 * (i / 12.0)), Color(0.05, 0.12, 0.35, 0.05 * k))
		var r := maxf(v.x, v.y) * 1.2
		for i in 16:
			var a := 0.1 + TAU * i / 16.0
			var ray := Color(1.0, 0.92, 0.55, 0.16)
			draw_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * r, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * r]), PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
		draw_texture(_logo, c - ls * 0.5)
