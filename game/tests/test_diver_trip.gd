extends SceneTree
## Checks that a diver's trip never jumps: position, facing, lean and arm
## angles change only a little between two close points of the cycle, and
## the end of the trip matches its start (and the idle pose).
##   godot --headless --path . -s res://tests/test_diver_trip.gd

func _pose_vals(dl: GDScript, p: float, spot: Vector2, facing: float, hover: bool, tier: int = 0, walk: bool = false) -> Array:
	var home := Vector2(190, 200)
	var crate := Vector2(186, 196)
	var s: Dictionary = dl.trip_pose(p, home, spot, facing, hover, crate, 0.0, walk)
	var turn: float = s["turn"]
	var sx: float = s["facing"] * (1.0 if turn >= 0.0 else -1.0) * maxf(0.08, absf(turn))
	var chars: GDScript = load("res://scripts/ui/chars.gd")
	var a: Array = chars._arm_pair(s["arm"], s["hit"], 0.0, tier, s["carry"])
	var b := s.get("blend", 1.0) as float
	if s["arm_from"] != "" and b < 1.0:
		var f: Array = chars._arm_pair(s["arm_from"], 0.0, 0.0, tier, s["carry"])
		var e: float = chars._ease_io(b)
		a = [lerpf(f[0], a[0], e), lerpf(f[1], a[1], e)]
	return [s["pos"], sx, s["tilt"], a[0], a[1], s["kick_amp"]]


func _initialize() -> void:
	var dl: GDScript = load("res://scripts/ui/diver_layer.gd")
	var bad := 0
	# One gear tier per kind of tool (pick, drill, laser, plasma, trident, hammer).
	var cases := []
	for tier in [0, 3, 5, 7, 8, 9]:
		for spot_def in [[Vector2(372, 200), 1.0, false], [Vector2(386, 120), 1.0, true], [Vector2(472, 198), -1.0, false]]:
			cases.append(spot_def + [tier, false])
	# Air worlds: walking on the floor and climbing a scaffold (no hovering).
	for spot_def in [[Vector2(372, 200), 1.0, false], [Vector2(386, 116), 1.0, false], [Vector2(472, 198), -1.0, false]]:
		cases.append(spot_def + [0, true])
	for spot_def in cases:
		# A jump is a step much bigger than the steps just before and after it.
		var n := 4000
		var vals: Array = []
		for i in range(0, n + 1):
			vals.append(_pose_vals(dl, float(i) / n, spot_def[0], spot_def[1], spot_def[2], spot_def[3], spot_def[4]))
		var names := ["pos", "facing", "tilt", "front arm", "back arm", "kick"]
		var eps := [0.05, 0.002, 0.002, 0.01, 0.01, 0.002]
		for k in 6:
			var d: Array[float] = []
			for i in range(1, n + 1):
				if k == 0:
					d.append((vals[i][0] as Vector2).distance_to(vals[i - 1][0]))
				else:
					d.append(absf(float(vals[i][k]) - float(vals[i - 1][k])))
			for i in range(1, d.size() - 1):
				# A turn flips sides at its thinnest point (8% wide): not a jump.
				var flip: bool = k == 1 and absf(float(vals[i + 1][1])) < 0.081 and absf(float(vals[i][1])) < 0.081
				if d[i] > 4.0 * maxf(d[i - 1], d[i + 1]) + eps[k] and not flip:
					print("JUMP tier %d spot %s: %s changes by %.3f at p=%.4f" % [spot_def[3], spot_def[0], names[k], d[i], float(i + 1) / n])
					bad += 1
		var start := _pose_vals(dl, 0.0, spot_def[0], spot_def[1], spot_def[2], spot_def[3], spot_def[4])
		var end := _pose_vals(dl, 1.0, spot_def[0], spot_def[1], spot_def[2], spot_def[3], spot_def[4])
		if (start[0] as Vector2).distance_to(end[0]) > 0.5 or absf(start[1] - end[1]) > 0.01 or absf(start[3] - end[3]) > 0.01:
			print("LOOP spot %s: end %s != start %s" % [spot_def[0], end, start])
			bad += 1
	print("trip: %d jumps" % bad)
	quit(1 if bad > 0 else 0)
