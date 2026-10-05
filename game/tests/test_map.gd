extends SceneTree
## World map logic: boat positions, gate flow (button -> confirm -> open),
## silhouettes and the mini-map signal.
##   godot --headless --path . -s res://tests/test_map.gd

var ok := 0
var bad := 0


func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		print("FAIL: ", what)


func _buttons(n: Node) -> Array:
	return n.find_children("*", "Button", true, false)


func _initialize() -> void:
	await process_frame
	var ma: GDScript = load("res://scripts/ui/map_art.gd")
	var mv: GDScript = load("res://scripts/ui/map_view.gd")
	# World chain and tiers.
	check(ma.world_of(0) == "ocean" and ma.world_of(1) == "volcano" and ma.world_of(2) == "acid" and ma.world_of(3) == "moon", "world order")
	check(ma.world_of(5) == "volcano" and mv.tier_of(5) == 1 and mv.tier_of(3) == 0, "repeats and tiers")
	# Boat: waits at the mine, reaches the factory, comes back.
	for w in ma.WORLDS:
		var route: Array = ma.spots(w)["boat"]
		var idle: Vector3 = ma.boat_at(w, -1.0)
		check(Vector2(idle.x, idle.y).distance_to(route[0]) < 0.5, w + ": idle boat at the mine")
		var mid: Vector3 = ma.boat_at(w, 0.5)
		check(Vector2(mid.x, mid.y).distance_to(route[route.size() - 1]) < 0.5, w + ": unloading at the factory")
		var back: Vector3 = ma.boat_at(w, 0.8)
		check(back.z * mid.z < 0.0, w + ": boat turns around")
		check(ma.sil_polys(w).size() >= 4, w + ": silhouette shapes")
	# Gate flow.
	var goals := [{"id": "sites", "have": 10, "need": 10}, {"id": "foremen", "have": 10, "need": 10},
			{"id": "managers", "have": 5, "need": 5}, {"id": "evo", "have": 12, "need": 12}]
	mv.set("demo", {"location": 0, "goals": goals, "cost": 100.0, "coins": 50.0, "can": false, "boat": -1.0, "boat2": -2.0})
	var host := Control.new()
	host.theme = load("res://scripts/ui/ui_theme.gd").build()
	root.add_child(host)
	var v: Control = mv.new()
	host.add_child(v)
	await process_frame
	check(mv.location_ready(), "ready with all goals")
	check(mv.lit_nodes() == 4, "all nodes lit")
	var gold := _buttons(v).filter(func(b): return b.theme_type_variation == &"GoldButton")
	check(gold.size() == 1 and gold[0].disabled, "open button disabled without coins")
	(mv.get("demo") as Dictionary)["coins"] = 500.0
	(mv.get("demo") as Dictionary)["can"] = true
	v.call("refresh")
	await process_frame
	gold = _buttons(v).filter(func(b): return b.theme_type_variation == &"GoldButton")
	check(gold.size() == 1 and not gold[0].disabled, "open button enabled")
	var opened := [-1]
	v.connect("location_opened", func(l): opened[0] = l)
	var closed := [false]
	v.connect("closed", func(): closed[0] = true)
	gold[0].emit_signal("pressed")
	await process_frame
	check(v.get("_confirm") == true, "confirm step shown")
	check(opened[0] == -1, "not opened before confirming")
	var no := _buttons(v).filter(func(b): return b.theme_type_variation == &"CreamButton")
	check(no.size() == 1, "not-yet button")
	no[0].emit_signal("pressed")
	await process_frame
	check(v.get("_confirm") == false, "not yet goes back")
	gold = _buttons(v).filter(func(b): return b.theme_type_variation == &"GoldButton")
	gold[0].emit_signal("pressed")
	await process_frame
	var yes := _buttons(v).filter(func(b): return b.theme_type_variation == &"GoldButton")
	yes[0].emit_signal("pressed")
	await process_frame
	check(opened[0] == 1, "location_opened(1) emitted")
	check(mv.cur_location() == 1, "location advanced")
	v.call("close")
	check(closed[0] and not v.visible, "closed signal")
	# Mini-map tap.
	var mm: Control = load("res://scripts/ui/mini_map.gd").new()
	host.add_child(mm)
	await process_frame
	var taps := [0]
	mm.connect("open_map", func(): taps[0] += 1)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	mm.call("_gui_input", e)
	var e2 := e.duplicate()
	e2.pressed = false
	mm.call("_gui_input", e2)
	check(taps[0] == 1, "mini-map tap opens the map")
	# Without demo values the map reads the real gate (sites, foremen, managers).
	mv.set("demo", {})
	check(mv.goals().size() == 3, "real gate goals")
	check(mv.world_name(0) != "", "world name")
	print("%d passed, %d failed" % [ok, bad])
	quit(1 if bad > 0 else 0)
