extends SceneTree
## Nothing on the main screen teleports: plays ~16 s of the real main scene
## at a fixed 60 fps while the player taps the lift, the boat and a site,
## upgrades the lift and the boat mid-trip, starts a rush, flies coins to
## the top bar and switches rooms, and records every frame where the lift
## cabin, the boats, the divers, the flying coins and the room slide are.
## A jump is a step much bigger than the steps just before and after it,
## measured in pixels per second of game time so an uneven frame (a run
## without --fixed-fps) does not read as a jump.
##   godot --headless --path . --resolution 390x844 --fixed-fps 60 -s res://tests/test_motion.gd [-- raw]
## "raw" draws straight from GameState's progress (the old way) to show
## what the check catches.

const FRAMES := 960

var gs: Node
var main: Node
var _series := {}
var _limits := {}
var _dt := 1.0 / 60.0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	var raw := "raw" in OS.get_cmdline_user_args()
	load("res://scripts/ui/motion.gd").off = raw
	gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_motion_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://test_motion_progress.json"
	pr.reset()
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "lift": 40, "boat": 45, "plant": 41}, true)
	for k in ["d0", "d1", "d2", "lift", "boat", "plant"]:
		gs.managers[k] = true
	gs.coins = 1e9
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	main = current_scene
	var world = main._world
	var fx = main._fx
	for f in FRAMES:
		# What the player does.
		if f >= 60 and f < 420 and f % 18 == 0:
			gs.tap("lift")
			gs.tap("boat")
			gs.tap("d0")
		if f == 450:
			gs.upgrade("lift", 60)
			gs.upgrade("boat", 60)
			gs.upgrade("d0", 40)
		if f == 520:
			gs.rush_left = 6.0
		if f == 600:
			fx.fly("coin", Vector2(200, 600), Vector2(80, 40), 8)
		if f == 700:
			main.show_room(1)
		if f == 760:
			main.show_room(2)
		if f == 830:
			main.show_room(0)
		await process_frame
		_dt = clampf(main.get_process_delta_time(), 1.0 / 240.0, 0.25)
		# Where things are now.
		_rec("lift cabin", world.lift.cabin_pos(), 2.0)
		_rec("boat", world.surface.boat_world_pos(), 2.0)
		for site in 3:
			for j in mini(3, gs.divers("d%d" % site)):
				_rec("diver d%d/%d" % [site, j], world.divers.diver_at(site, j), 2.0)
		for c in fx.get_children():
			if c is TextureRect:
				_rec("coin %d" % c.get_instance_id(), c.position, 2.0)
		_rec("room slide", Vector2(main._slide * 400.0, 0.0), 2.0)
	var bad := 0
	var worst := ""
	var worst_v := 0.0
	for name in _series:
		var pts: Array = _series[name]
		# Steps scaled to a 60 fps frame: px moved / frame time / 60.
		var d: Array[float] = []
		for i in range(1, pts.size()):
			d.append((pts[i]["p"] as Vector2).distance_to(pts[i - 1]["p"]) / (float(pts[i]["dt"]) * 60.0))
		for i in d.size():
			if d[i] > worst_v:
				worst_v = d[i]
				worst = name
			# A frame hitch (a slow frame without --fixed-fps) moves things
			# by the time that passed: not a teleport, so it is not judged.
			var hitch := false
			for k in range(maxi(1, i), mini(pts.size(), i + 3)):
				hitch = hitch or float(pts[k]["dt"]) > 1.6 / 60.0
			# The first and last steps have nothing to compare with.
			if hitch or i == 0 or i + 1 >= d.size():
				continue
			var before := d[i - 1] if i > 0 else 0.0
			var after := d[i + 1] if i + 1 < d.size() else 0.0
			if d[i] > 4.0 * maxf(before, after) + float(_limits[name]):
				print("JUMP %s: %.1f px per 60 fps frame (%.1f before, %.1f after) at step %d of %d" % [name, d[i], before, after, i, d.size()])
				bad += 1
				if OS.get_environment("MOTION_DEBUG") != "":
					for k in range(maxi(0, i - 3), mini(pts.size(), i + 4)):
						print("   ", k, " ", pts[k])
	print("motion: %d series, %d frames, fastest %.1f px/frame (%s), %d jumps" % [_series.size(), FRAMES, worst_v, worst, bad])
	DirAccess.remove_absolute("user://test_motion_save.json")
	DirAccess.remove_absolute("user://test_motion_progress.json")
	quit(1 if bad > 0 else 0)


func _rec(name: String, p: Vector2, eps: float) -> void:
	if not _series.has(name):
		_series[name] = []
		_limits[name] = eps
	_series[name].append({"p": p, "dt": _dt})
