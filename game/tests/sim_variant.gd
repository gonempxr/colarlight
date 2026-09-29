extends SceneTree
func _initialize() -> void:
	for cfg in [
		{"kinds": 5, "fragments": 1, "assist": 0.2}, {"kinds": 5, "fragments": 2, "assist": 0.2}, {"kinds": 5, "fragments": 2, "assist": 0.35},
		{"kinds": 5, "fragments": 3, "assist": 0.35}, {"kinds": 6, "fragments": 2, "assist": 0.35}, {"kinds": 6, "fragments": 2, "assist": 0.5},
		{"kinds": 4, "fragments": 3, "assist": 0.0}, {"kinds": 4, "fragments": 4, "assist": 0.0},
	]:
		var used := []
		for s in 40:
			var l2: Dictionary = cfg.duplicate()
			l2["seed"] = 1000 + s * 37
			l2["moves"] = 300
			var m := Match3.new(l2)
			while m.state == Match3.PLAYING:
				var mv := m.find_hint()
				m.swap(mv[0], mv[1])
			used.append(m.moves_used)
		used.sort()
		print(cfg, " med ", used[20], " p75 ", used[30], " p90 ", used[36], " max ", used[39])
	quit()
