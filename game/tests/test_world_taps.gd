extends SceneTree
## Taps on the surface world (headless is fine):
##   godot --headless --path . --resolution 390x844 -s res://tests/test_world_taps.gd
## The boat and the plant still take their taps; the sun, clouds, birds,
## fish, palm and lighthouse react; a drag over them does nothing.

var _failures := 0
var _checks := 0
var gs: Node
var main: Node
var surface: Control
var world: Control
var taps: Array[String] = []


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_taps_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://test_taps_progress.json"
	pr.reset()
	pr.tutorial_step = 7
	TranslationServer.set_locale("en")
	load("res://scripts/ui/main.gd").show_title = false
	var dn: GDScript = load("res://scripts/ui/day_night.gd")
	dn.fixed_phase = 0.2
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(8)
	main = current_scene
	world = main._world
	surface = world.surface
	gs.tapped.connect(func(k: String) -> void: taps.append(k))
	gs.hold = 50.0
	await _frames(2)

	taps.clear()
	await _click(surface.boat_world_pos() + Vector2(0, -40))
	check("boat" in taps, "tapping the boat taps the boat")
	taps.clear()
	await _click(surface.plant_world_pos() + Vector2(40, -80))
	check("plant" in taps, "tapping the plant taps the plant")
	taps.clear()
	await _click(surface.raft_pos() + Vector2(0, -60))
	check("boat" in taps, "tapping the raft taps the boat")

	taps.clear()
	var sun: Vector2 = dn.sun_pos(surface.size.x)
	await _click(sun)
	check(taps.is_empty(), "the sun does not tap a stage")
	check(world.pokes.has("sun"), "the sun reacts")

	taps.clear()
	var c: Dictionary = surface._clouds[0]
	await _click(surface._cloud_pos(c))
	check(float(c["poke"]) > 0.0, "a cloud puffs and rains")
	await _frames(20)
	check(surface._rain.size() > 0, "rain falls from the cloud")

	var b: Dictionary = surface._birds[1]
	b["x"] = 200.0
	b["y"] = 300.0
	b["flee"] = -1.0
	b["wait"] = 0.0
	await _frames(1)
	await _click(Vector2(b["x"], b["y"]))
	check(float(b["flee"]) >= 0.0, "a bird flies away")

	var f: Dictionary = world._fish[0]
	var fp: Vector2 = world._fish_pos(f, world.size.x)
	if fp.x > 20.0 and fp.x < world.size.x - 20.0:
		await _click(fp)
		check(world.t - float(f["dart"]) < 1.0, "a fish darts")

	await _click(surface._palm_pos() + load("res://scripts/ui/props.gd").PALM_TOP)
	check(not surface._coconut.is_empty(), "the palm drops a coconut")

	var lh: Vector2 = surface._lighthouse_pos() + Vector2(0, -92)
	if surface._building_at(lh) == "":
		await _click(lh)
		check(surface._lighthouse_poke > 0.0, "the lighthouse flashes")

	# A drag across the sun does not poke it.
	world.pokes.erase("sun")
	await _drag(sun, sun + Vector2(0, 160))
	check(not world.pokes.has("sun"), "a drag does not poke the sun")

	# Night: tapping the moon.
	dn.fixed_phase = 0.72
	main._scroller.scroll_to(0.0)
	await _frames(4)
	await _click(dn.moon_pos(surface.size.x))
	check(world.pokes.has("moon"), "the moon reacts")

	# A new stage: celebrate once.
	var before: int = surface._stage["boat"]
	gs.levels["boat"] = 60
	gs.upgraded.emit("boat", 1)
	await _frames(3)
	check(surface._stage["boat"] > before, "boat stage follows the level")
	check(surface._t - float(surface._stage_fx["boat"]) < 1.0, "a new boat stage is celebrated (%s, %s, %s)" % [before, surface._stage["boat"], surface._t - float(surface._stage_fx["boat"])])

	dn.fixed_phase = -1.0
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_taps_save.json")
	DirAccess.remove_absolute("user://test_taps_progress.json")
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _win(world_pos: Vector2) -> Vector2:
	return root.get_final_transform() * (world.get_global_transform_with_canvas() * world_pos)


func _click(world_pos: Vector2) -> void:
	var pos := _win(world_pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	root.push_input(down)
	await _frames(1)
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up)
	await _frames(2)


func _drag(a: Vector2, b: Vector2) -> void:
	var start := _win(a)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	down.global_position = start
	root.push_input(down)
	await _frames(1)
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = start.lerp(_win(b), (i + 1) / 10.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
		await _frames(1)
	var up := down.duplicate()
	up.pressed = false
	up.position = _win(b)
	up.global_position = up.position
	root.push_input(up)
	await _frames(3)
