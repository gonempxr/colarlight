extends SceneTree
## Balance probe for the puzzle levels (not a test):
##   godot --headless --path . -s res://tests/sim_puzzle.gd -- [levels] [seeds]
## For each level: moves a greedy (hint) player and a random player need
## with unlimited moves, and the win rate within the level's move budget.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var levels := int(args[0]) if args.size() > 0 else 40
	var seeds := int(args[1]) if args.size() > 1 else 20
	print("lvl kinds frag sand/2 bub moves | greedy med p90 win% | random med p90 win%")
	for n in range(1, levels + 1):
		var lv := PuzzleLevels.level(n)
		var row := "%3d %d %d %d/%d %d %3d |" % [n, lv["kinds"], lv["fragments"], lv["sand"], lv["sand2"], lv["bubbles"], lv["moves"]]
		for greedy in [true, false]:
			var used := []
			var wins := 0
			for s in seeds:
				var l2 := lv.duplicate()
				l2["seed"] = lv["seed"] + s * 101
				l2["moves"] = 300
				var m := Match3.new(l2)
				var rng := RandomNumberGenerator.new()
				rng.seed = s + 5
				while m.state == Match3.PLAYING:
					var mv := m.find_hint() if greedy else _random_move(m, rng)
					m.swap(mv[0], mv[1])
				used.append(m.moves_used)
				if m.moves_used <= lv["moves"]:
					wins += 1
			used.sort()
			row += " %3d %3d %3d%% |" % [used[used.size() / 2], used[int(used.size() * 0.9)], wins * 100 / seeds]
		print(row)
	quit()


func _random_move(m: Match3, rng: RandomNumberGenerator) -> Array:
	var all := []
	for y in m.height:
		for x in m.width:
			var a := Vector2i(x, y)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if m._move_score(a, a + d) > 0:
					all.append([a, a + d])
	return all[rng.randi_range(0, all.size() - 1)]
