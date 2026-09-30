extends SceneTree
## Screenshot of the surface with the second boat and plant (needs a renderer):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/world2_shot.gd -- out.png [boat2] [plant2] [phase] [boat] [plant] [d2] [crop_h] [boat2_p] [boat_p]
## boat2/plant2: level of the second boat/plant (0 = closed, for sale once d2 is open);
## phase: day phase 0..1 (-1 = running clock); boat/plant: level of the first ones;
## d2: 1 opens depth d2 (shows the for-sale markers); crop_h: keep that many
## window pixels from the top (0 = all); boat2_p / boat_p: freeze the boats at
## that cycle progress (-1 = let them run); pet: equip that pet cosmetic id
## (e.g. pet_crab, "-" = none); dock / hold: ore at the shore / on the raft
## (-1 = the defaults; 0 lets the plant worker doze).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://world2.png"
	var boat2 := int(args[1]) if args.size() > 1 else 0
	var plant2 := int(args[2]) if args.size() > 2 else 0
	var phase := float(args[3]) if args.size() > 3 else 0.25
	var boat := int(args[4]) if args.size() > 4 else 45
	var plant := int(args[5]) if args.size() > 5 else 41
	var d2 := int(args[6]) if args.size() > 6 else 1
	var crop_h := int(args[7]) if args.size() > 7 else 0
	var boat2_p := float(args[8]) if args.size() > 8 else -1.0
	var boat_p := float(args[9]) if args.size() > 9 else -1.0
	var pet := args[10] if args.size() > 10 else "-"
	var dock := float(args[11]) if args.size() > 11 else -1.0
	var hold := float(args[12]) if args.size() > 12 else -1.0
	await process_frame
	root.get_node("Settings").language = "en"
	TranslationServer.set_locale("en")
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://world2_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://world2_progress.json"
	pr.reset()
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.tutorial_step = 9
	pr.daily_last = pr.today()
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12 if d2 > 0 else 0, "lift": boat, "boat": boat, "plant": plant, "boat2": boat2, "plant2": plant2}, true)
	for k in ["d0", "d1", "boat", "plant", "boat2", "plant2"]:
		gs.managers[k] = gs.levels[k] > 0
	gs.coins = 480250.0
	gs.hold = 1840.0 if hold < 0.0 else hold
	gs.dock = 620.0 if dock < 0.0 else dock
	if pet != "-":
		pr.equipped["pet"] = pet
	var dn: GDScript = load("res://scripts/ui/day_night.gd")
	dn.fixed_phase = phase
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	for i in 60:
		gs.advance(0.05)
		await process_frame
	for pair in [["boat2", boat2_p], ["boat", boat_p]]:
		if float(pair[1]) >= 0.0 and gs.is_open(pair[0]):
			gs._timer[pair[0]] = float(pair[1]) * gs.cycle_time(pair[0])
			gs._load[pair[0]] = maxf(1.0, gs.cycle_capacity(pair[0]))
	gs.set_process(false)
	for i in 12:
		await process_frame
	var main := current_scene
	var s: Control = main._world.surface
	print("surface size ", s.size, " island_x ", s.island_x(), " boat range ", s.boat_x_range(), " zoom ", main._scroller.zoom)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if crop_h > 0 and crop_h < img.get_height():
		img = img.get_region(Rect2i(0, 0, img.get_width(), crop_h))
	img.save_png(out)
	dn.fixed_phase = -1.0
	quit()
