extends SceneTree
## Taps on the surface world (headless is fine):
##   godot --headless --path . --resolution 390x844 -s res://tests/test_world_taps.gd
## The boat takes its taps, the factory signpost opens room 2; the sun, clouds, birds,
## fish, palm and lighthouse react; a drag over them does nothing. The
## second boat and plant: their for-sale signs select them, once bought
## they take their own taps.

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
	pr.tutorial_step = 12
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
	# The plant works in the factory now: its signpost leads there.
	await _click(surface.sign_pos() + Vector2(0, -50))
	check(main.current_room() == 1, "tapping the factory signpost opens the factory")
	main.show_room(0, false)
	await _frames(2)
	taps.clear()
	await _click(surface.raft_pos() + Vector2(0, -60))
	check("boat" in taps, "tapping the raft taps the boat")

	# The lift: its cabin and its winch take taps (a trip) and show it in
	# the panel; the raft next to them still belongs to the boat.
	var lift: Control = world.lift
	gs.pit = 50.0
	taps.clear()
	var selected: Array[String] = []
	world.stage_selected.connect(func(k: String) -> void: selected.append(k))
	await _click(lift.cabin_pos() + Vector2(0, -30))
	check(taps == ["lift"], "tapping the lift's cabin taps the lift (%s)" % [taps])
	check(gs.cycle_progress("lift") >= 0.0, "a tap sends the lift down")
	var wide: bool = main._wide
	check(selected == (["lift"] if wide else []), "a hand-run lift opens the panel only on wide screens (%s)" % [selected])
	gs.managers["lift"] = true
	selected.clear()
	await _click(lift.cabin_pos() + Vector2(0, -30))
	check(selected == ["lift"], "with its operator a tap shows the lift in the panel (%s)" % [selected])
	gs.managers["lift"] = false
	main._close_sheet()
	await create_timer(0.4).timeout
	taps.clear()
	await _click(lift.OPERATOR + Vector2(0, -30))
	check(taps == ["lift"], "tapping the lift's operator taps the lift (%s)" % [taps])
	main._close_sheet()
	await create_timer(0.4).timeout
	taps.clear()
	await _click(surface.raft_pos() + Vector2(0, -60))
	check(taps == ["boat"], "the raft still taps the boat (%s)" % [taps])

	main._close_sheet()
	await create_timer(0.4).timeout


	taps.clear()
	# The sun moves along its arc and can pass behind the stage cards in the
	# sky; tap it at a time of day when it is in the open.
	_open_sky_phase(dn, 0.2, false)
	await _frames(2)
	var sun: Vector2 = dn.sun_pos(surface.size.x)
	await _click(sun)
	check(taps.is_empty(), "the sun does not tap a stage")
	check(world.pokes.has("sun"), "the sun reacts")

	taps.clear()
	# A cloud well inside the screen and clear of the cards (they drift off the edges).
	var c: Dictionary = surface._clouds[0]
	var best := INF
	for cl: Dictionary in surface._clouds:
		var cp: Vector2 = surface._cloud_pos(cl)
		if cp.x < 60.0 or cp.x > surface.size.x - 60.0 or surface._on_card(cp) or surface._building_at(cp) != "":
			continue
		var d := absf(cp.x - surface.size.x * 0.5)
		if d < best:
			best = d
			c = cl
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

	# A fish in the open water (the lift's card floats over part of it).
	var card_rect: Rect2 = world.lift.card.get_rect().grow(50.0)
	for f: Dictionary in world._fish:
		var fp: Vector2 = world._fish_pos(f, world.size.x)
		if fp.x > 20.0 and fp.x < world.size.x - 20.0 and not card_rect.has_point(fp):
			await _click(fp)
			check(world.t - float(f["dart"]) < 1.0, "a fish darts")
			break

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
	main._scroller.scroll_to(0.0)
	await _frames(4)
	_open_sky_phase(dn, 0.72, true)
	await _frames(2)
	await _click(dn.moon_pos(surface.size.x))
	check(world.pokes.has("moon"), "the moon reacts")
	# An autoclicker on the moon: 100 pokes in one go send no more shooting
	# stars than the tap cap allows.
	var stars_before: int = world._shooting.size()
	var moon: Vector2 = dn.moon_pos(surface.size.x)
	for i in 100:
		surface._poke_ambient(moon)
	var stars: int = world._shooting.size() - stars_before
	check(stars <= Balance.TAP_CAP, "100 moon pokes at once send at most %d shooting stars (%d)" % [Balance.TAP_CAP, stars])
	# Same for the sun's sparkles.
	_open_sky_phase(dn, 0.2, false)
	await _frames(2)
	var parts_before: int = world.divers._parts.size()
	for i in 100:
		surface._poke_ambient(dn.sun_pos(surface.size.x))
	var sparks: int = world.divers._parts.size() - parts_before
	check(sparks <= Balance.TAP_CAP * 8, "100 sun pokes at once sparkle at most %d times (%d sparks)" % [Balance.TAP_CAP, sparks])
	_open_sky_phase(dn, 0.72, true)
	await _frames(2)

	# The second boat and plant: for sale once the third dive site is open;
	# a tap on their sign selects them (the upgrade panel sells them).
	selected.clear()
	check(surface.second_state("boat2") == "", "no for-sale signs before the third dive site")
	gs.levels["d2"] = 1
	gs._timer["boat"] = -1.0
	await _frames(3)
	check(surface.second_state("boat2") == "sale" and surface.second_state("plant2") == "sale", "for-sale signs from the third dive site on")
	# (The plants left the shore for the factory room: only boat2 has a sign here.)
	for key in ["boat2"]:
		var r: Rect2 = surface._sign_rect(key)
		selected.clear()
		taps.clear()
		await _tap(r.get_center())
		check(selected == [key], "tapping the %s sign selects it (%s)" % [key, selected])
		check(taps.is_empty(), "the %s sign taps nothing else (%s)" % [key, taps])
	# Bought: they stand in the world and take their own taps.
	gs.coins = 1e12
	check(gs.open_building("plant2") and gs.open_building("boat2"), "buy the second boat and plant")
	await create_timer(0.4).timeout
	check(surface.second_state("boat2") == "open" and surface.second_state("plant2") == "open", "second boat and plant are shown")
	taps.clear()
	selected.clear()
	await _tap(surface.boat2_world_pos() + Vector2(0, -30))
	check("boat2" in taps, "tapping the second boat taps it (%s)" % [taps])
	check(selected.is_empty(), "tapping the second boat selects nothing")
	# On phones the sky cards cover the island; move them away to reach the plants.
	surface.boat_card.visible = false
	surface.plant_card.visible = false
	await _frames(2)
	# Both plants live in the factory room: the shore signpost leads there.
	taps.clear()
	selected.clear()
	var p1: Vector2 = surface.plant_world_pos() + Vector2(40, -60)
	var why := "hit %s, card %s, drag %s" % [surface._building_at(p1), surface._on_card(p1), Scroller.is_drag()]
	await _tap(p1)
	check(taps.is_empty() and selected == ["room:factory"], "the shore signpost opens the factory (%s %s; %s)" % [taps, selected, why])
	main.show_room(0, false)
	surface.boat_card.visible = true
	surface.plant_card.visible = true
	gs.levels["boat2"] = 60
	gs.upgraded.emit("boat2", 1)
	await _frames(3)
	check(surface._stage["boat2"] > 1 and surface._t - float(surface._stage_fx["boat2"]) < 1.0, "a new stage of the second boat is celebrated")

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


## Sets the day phase nearest to [param start] at which the sun (or the
## moon) is not behind a card in the sky.
func _open_sky_phase(dn: GDScript, start: float, night: bool) -> void:
	var cards: Array = [surface.boat_card, surface.plant_card, world.lift.phone_card()]
	for i in 40:
		for sgn in [1.0, -1.0]:
			var ph := fposmod(start + sgn * i * 0.005, 1.0)
			dn.fixed_phase = ph
			var p: Vector2 = dn.moon_pos(surface.size.x) if night else dn.sun_pos(surface.size.x)
			var g: Vector2 = world.get_global_transform_with_canvas() * p
			var covered := false
			for c in cards:
				if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().grow(40.0).has_point(g):
					covered = true
			if not covered and (dn.sun_up() != night):
				return
	dn.fixed_phase = start


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


## A tap released right on the surface (its local space is the world's):
## the headless window is tiny, so real clicks far from the corner land on
## other UI. Tests the surface's own routing, cards included.
func _tap(world_pos: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = world_pos
	up.global_position = _win(world_pos)
	surface._gui_input(up)
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
