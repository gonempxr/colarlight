extends SceneTree
## Preview sheet of the factory (room 2) and the office (room 3):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1700x700 \
##     -s res://tests/rooms_sheet.gd -- out.png <factory|office> <phone|pc|land> [lang]
## Each panel is one room at the device's room size (phone portrait 390x604,
## PC 900x900, phone landscape 844x262) with a different state: decor 0/2/5,
## vault empty/full, plant stages early/late, the second line open, and the
## four world tints. The window must be big enough for the row of panels:
## phone 4 x 400 = 1640 x 640, pc 2 x 910 = 1840 x 940, land 2 x 854 = 1720 x 560.

const SIZES := {"phone": Vector2(390, 604), "pc": Vector2(900, 900), "land": Vector2(844, 262)}

const FACTORY := {
	"phone": [
		{"world": "ocean", "stage": 1, "plant2": false, "working": true, "mgr": false},
		{"world": "volcano", "stage": 6, "stage2": 3, "plant2": true, "working": true, "mgr": true},
		{"world": "acid", "stage": 12, "stage2": 9, "plant2": true, "working": false, "mgr": false},
		{"world": "moon", "stage": 20, "stage2": 18, "plant2": true, "working": true, "mgr": true},
	],
	"pc": [
		{"world": "ocean", "stage": 3, "plant2": false, "working": true, "mgr": false},
		{"world": "volcano", "stage": 16, "stage2": 11, "plant2": true, "working": true, "mgr": true},
	],
	"land": [
		{"world": "acid", "stage": 8, "plant2": false, "working": true, "mgr": true},
		{"world": "moon", "stage": 19, "stage2": 14, "plant2": true, "working": true, "mgr": true},
	],
}

const OFFICE := {
	"phone": [
		{"world": "ocean", "decor": 0, "vault": 0.0, "accountant": false, "evo": 0},
		{"world": "volcano", "decor": 2, "vault": 0.3, "accountant": false, "evo": 3},
		{"world": "acid", "decor": 5, "vault": 1.0, "accountant": true, "evo": 8},
		{"world": "moon", "decor": 3, "vault": 0.7, "accountant": true, "evo": 12},
	],
	"pc": [
		{"world": "ocean", "decor": 0, "vault": 0.05, "accountant": false, "evo": 1},
		{"world": "ocean", "decor": 5, "vault": 1.0, "accountant": true, "evo": 6},
	],
	"land": [
		{"world": "volcano", "decor": 2, "vault": 0.5, "accountant": false, "evo": 2},
		{"world": "moon", "decor": 5, "vault": 1.0, "accountant": true, "evo": 10},
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://rooms_sheet.png"
	var room := args[1] if args.size() > 1 else "factory"
	var device := args[2] if args.size() > 2 else "phone"
	var lang := args[3] if args.size() > 3 else "en"
	await process_frame
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://rooms_sheet_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://rooms_sheet_progress.json"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("241a3a")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var sz: Vector2 = SIZES[device]
	var list: Array = (FACTORY if room == "factory" else OFFICE)[device]
	var script: GDScript = load("res://scripts/ui/factory_room.gd" if room == "factory" else "res://scripts/ui/office_room.gd")
	var cols := 4 if device == "phone" else 1 if device == "pc" and false else 2
	for i in list.size():
		var r: Control = script.new()
		r.preview = list[i]
		r.size = sz
		r.position = Vector2((i % cols) * (sz.x + 10) + 5, floori(i / float(cols)) * (sz.y + 10) + 5)
		root.add_child(r)
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
