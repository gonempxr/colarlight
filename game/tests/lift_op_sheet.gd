extends SceneTree
## Zoomed sheet of the lift operator at the winch on the raft: every lift
## look (rows) with and without the operator hired, idle and with the trip
## frozen at crank phases 0, 0.25, 0.5 and 0.75 (columns):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1920x1080 \
##     -s res://tests/lift_op_sheet.gd -- out.png [hired: 0|1|2 = both] [zoom]

const LEVELS := [1, 10, 25, 75, 150, 250]
const PHASES := [-1.0, 0.0, 0.25, 0.5, 0.75]
## World area around the winch and the operator.
const AREA := Rect2(0, 318, 120, 160)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://lift_op_sheet.png"
	var hired_arg := int(args[1]) if args.size() > 1 else 2
	var zoom := float(args[2]) if args.size() > 2 else 3.0
	await process_frame
	root.get_node("Settings").language = "en"
	TranslationServer.set_locale("en")
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://lift_op_sheet.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://lift_op_sheet_progress.json"
	pr.reset()
	pr.tutorial_step = 9
	pr.daily_last = pr.today()
	gs.levels.merge({"d0": 34, "d1": 27, "boat": 45, "plant": 41}, true)
	gs.coins = 1000.0
	gs.pit = 50.0
	var dn: GDScript = load("res://scripts/ui/day_night.gd")
	dn.fixed_phase = 0.25
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main := current_scene
	var world: Control = main._world
	var lift = world.lift
	main._scroller.zoom = zoom
	main._scroller.scroll_to(AREA.position.y - 40.0)
	gs.set_process(false)
	var hired_list: Array = [false, true] if hired_arg == 2 else [hired_arg == 1]
	var tiles: Array[Image] = []
	var tile_size := Vector2i.ZERO
	for hired in hired_list:
		for lv in LEVELS:
			for ph in PHASES:
				gs.levels["lift"] = lv
				gs.managers["lift"] = hired
				gs.pit = 50.0
				lift.refresh()
				if ph < 0.0:
					gs._timer["lift"] = -1.0
					lift._idle_since = lift._t - 1.0
				else:
					gs._timer["lift"] = 0.2 * gs.cycle_time("lift")
					gs._load["lift"] = 5.0
					lift._last_p = 0.2
					lift._crank = ph * TAU
					lift.freeze_crank = true
				for i in 4:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				var xf: Transform2D = root.get_final_transform() * world.get_global_transform_with_canvas()
				var a: Vector2 = xf * AREA.position
				var b: Vector2 = xf * AREA.end
				var r := Rect2i(Vector2i(a), Vector2i(b - a))
				tiles.append(img.get_region(r))
				tile_size = r.size
	var cols := PHASES.size()
	var rows := tiles.size() / cols
	var pad := 6
	var sheet := Image.create(cols * (tile_size.x + pad) + pad, rows * (tile_size.y + pad) + pad, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("241a3a"))
	for i in tiles.size():
		var t: Image = tiles[i]
		t.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile_size), Vector2i(pad + (i % cols) * (tile_size.x + pad), pad + (i / cols) * (tile_size.y + pad)))
	sheet.save_png(out)
	print("sheet ", sheet.get_size(), " tile ", tile_size)
	dn.fixed_phase = -1.0
	quit()
