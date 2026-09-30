extends SceneTree
## Preview sheet of the 15 boat and 15 plant stages and the ore chest:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1600x1500 -s res://tests/stage_sheet.gd -- out.png [zoom] [x] [y] [night]
## zoom/x/y render a magnified crop whose top-left corner is sheet point (x, y);
## night 0..1 lights the windows and lamps.

var props: GDScript = load("res://scripts/ui/props.gd")


class Sheet extends Control:
	var props: GDScript
	var t := 1.3
	var zoom := 1.0
	var origin := Vector2.ZERO
	var night := 0.0

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		Art.push(self, Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		Art.push(self, -origin)
		var bg := Color("8fd2f7").lerp(Color("1b2862"), night)
		Art.flat(self, PackedVector2Array([Vector2(-50, -50), Vector2(1700, -50), Vector2(1700, 1600), Vector2(-50, 1600)]), bg)
		for i in 15:
			var c := Vector2(160 + (i % 5) * 320, 190 + floori(i / 5.0) * 200)
			Art.flat(self, Art.rrect_pts(Rect2(c + Vector2(-150, 0), Vector2(300, 30)), 4), Color("35c9d2"))
			Art.push(self, c)
			props.boat_at_stage(self, i + 1, t + i, 2, Color("ff8fb0"), true, "happy", false, Callable(), night)
			if night > 0.0:
				props.boat_lights(self, i + 1, t, night)
			Art.pop(self)
			Art.text(self, c + Vector2(-140, -150), str(i + 1), 22, Art.WHITE, 5, false)
		for i in 15:
			var c := Vector2(90 + (i % 5) * 320, 870 + floori(i / 5.0) * 230)
			Art.flat(self, Art.rrect_pts(Rect2(c + Vector2(-60, 0), Vector2(280, 20)), 4), Color("72d25a"))
			Art.push(self, c)
			props.plant_at_stage(self, i + 1, t + i, true, t * 3.0, 0.0, night)
			if night > 0.0:
				props.plant_lights(self, i + 1, t, night)
			Art.pop(self)
			Art.text(self, c + Vector2(-60, -190), str(i + 1), 22, Art.WHITE, 5, false)
		# Chests at a few fill levels.
		for i in 5:
			var c := Vector2(80 + i * 90, 1560)
			Art.push(self, c)
			props.ore_chest(self, t, i / 4.0, [0.0, 0.2, 0.35, 1.0, 0.5][i], Color("ff8fb0"), 3)
			Art.pop(self)
			props.number_tag(self, c + Vector2(0, -62), ["0", "12", "340", "1.2K", "88.5M"][i], Color("ff8fb0"))
		Art.pop(self)
		Art.pop(self)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://stage_sheet.png"
	var sheet := Sheet.new()
	sheet.props = props
	if args.size() > 1:
		sheet.zoom = float(args[1])
	if args.size() > 3:
		sheet.origin = Vector2(float(args[2]), float(args[3]))
	if args.size() > 4:
		sheet.night = float(args[4])
	sheet.size = Vector2(1600, 1700)
	root.add_child(sheet)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
