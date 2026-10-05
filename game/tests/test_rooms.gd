extends SceneTree
## Taps and signals of the factory (room 2) and the office (room 3):
##   godot --headless --path . -s res://tests/test_rooms.gd

var _fails := 0
var _checks := 0


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func _tap(c: Control, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	c._gui_input(e)


func _initialize() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_rooms_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://test_rooms_progress.json"
	for sz: Vector2 in [Vector2(390, 604), Vector2(900, 900), Vector2(844, 262)]:
		await _factory(sz)
		await _office(sz)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _factory(sz: Vector2) -> void:
	var f: Control = load("res://scripts/ui/factory_room.gd").new()
	f.size = sz
	root.add_child(f)
	await process_frame
	var got: Array = []
	f.stage_selected.connect(func(k: String) -> void: got.append(k))
	for key: String in ["plant", "plant2"]:
		var r: Rect2 = f.line_rect(key)
		_ok(r.size.x >= 44.0 and r.size.y >= 44.0, "%s line big enough at %s: %s" % [key, sz, r])
		_ok(Rect2(Vector2.ZERO, sz).grow(2.0).encloses(r), "%s line inside the room at %s: %s" % [key, sz, r])
		_tap(f, r.get_center())
	_ok(got == ["plant", "plant2"], "factory taps select plant and plant2 at %s: %s" % [sz, got])
	_ok(not f.line_rect("plant").intersects(f.line_rect("plant2")), "lines do not overlap at %s" % sz)
	var a: Rect2 = f.card_anchor("plant")
	_ok(a.size.x > 100.0 and Rect2(Vector2.ZERO, sz).encloses(a), "card anchor inside at %s" % sz)
	# A boat trip brings a crate; a plant payout sends a capsule up.
	var gs := root.get_node("GameState")
	gs.cycle_finished.emit("boat", 10.0)
	gs.cycle_finished.emit("plant", 10.0)
	await process_frame
	_ok(f._crates.size() == 1, "boat trip -> crate")
	_ok((f._caps["plant"] as Array).size() == 1, "plant payout -> capsule")
	f.set_insets(60, 40)
	_ok(f.line_rect("plant").end.y <= sz.y - 40 + 2, "insets keep the line above the dock at %s" % sz)
	f.queue_free()
	await process_frame


func _office(sz: Vector2) -> void:
	var o: Control = load("res://scripts/ui/office_room.gd").new()
	o.preview = {"decor": 3, "vault": 0.8, "accountant": true, "evo": 4}
	o.size = sz
	root.add_child(o)
	await process_frame
	var log: Array = []
	o.decor_selected.connect(func(s: String) -> void: log.append("decor:" + s))
	o.open_evolution.connect(func() -> void: log.append("evo"))
	o.open_outfits.connect(func() -> void: log.append("outfits"))
	o.collected.connect(func(amount: float, _p: Vector2) -> void: log.append("collected:%d" % int(amount)))
	for name: String in ["collect", "pile", "player", "board", "wardrobe", "desk", "sofa", "aquarium", "lamp", "trophy", "plant"]:
		var r: Rect2 = o.slot_rect(name)
		_ok(r.size.x >= 44.0 and r.size.y >= 44.0, "%s big enough at %s: %s" % [name, sz, r])
		_ok(Rect2(Vector2.ZERO, sz).grow(30.0).encloses(r), "%s inside the room at %s: %s" % [name, sz, r])
	_tap(o, o.slot_rect("collect").get_center())
	_ok(log.size() == 1 and str(log[0]).begins_with("collected:") and str(log[0]) != "collected:0", "collect at %s: %s" % [sz, log])
	log.clear()
	_tap(o, o.slot_rect("collect").get_center())
	_ok(log.is_empty(), "nothing more to collect at %s: %s" % [sz, log])
	for pair: Array in [["board", "evo"], ["wardrobe", "outfits"]]:
		log.clear()
		_tap(o, o.slot_rect(pair[0]).get_center())
		_ok(log == [pair[1]], "%s -> %s at %s: %s" % [pair[0], pair[1], sz, log])
	for slot: String in ["desk", "sofa", "aquarium", "lamp", "trophy", "plant"]:
		log.clear()
		var r: Rect2 = o.slot_rect(slot)
		_tap(o, r.get_center())
		_ok(log == ["decor:" + slot], "%s tap at %s: %s (thing %s)" % [slot, sz, log, o.thing_at(r.get_center())])
	# Empty wall and floor spots pick wallpaper / floor.
	log.clear()
	_tap(o, Vector2(sz.x * 0.02 + 2, o._to_screen(Vector2(0, o._wall - 4)).y))
	_tap(o, Vector2(sz.x - 3, sz.y - 3))
	_ok(log.size() == 2 and log[0] in ["decor:wallpaper", "outfits", "decor:wardrobe"] and log[1] in ["decor:floor", "decor:plant"], "wall/floor at %s: %s" % [sz, log])
	o.queue_free()
	await process_frame
