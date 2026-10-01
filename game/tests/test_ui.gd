extends SceneTree
## Real clicks on the real main scene (headless is fine):
##   godot --headless --path . --resolution 390x844 -s res://tests/test_ui.gd
## Uses its own save file so it never touches the player's progress.

var _failures := 0
var _checks := 0
var gs: Node
var main: Node


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
	gs.save_path = "user://test_ui_save.json"
	gs.reset()
	var progress := root.get_node("Progress")
	progress.autosave_enabled = false
	progress.save_path = "user://test_ui_progress.json"
	progress.reset()
	var profiles := root.get_node("Profiles")
	profiles.set_name_of(profiles.current_id, "Tester")
	TranslationServer.set_locale("en")
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	main = current_scene
	await test_title()
	await test_tap_dive()
	await test_upgrade_sheet()
	await test_hire_manager()
	await test_drag_does_not_press()
	await test_open_depth()
	await test_wheel_scroll()
	await test_dock_appears()
	await test_language_switch()
	await test_new_ocean()
	await test_art_fits()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_ui_save.json")
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Screen position of a point given in world coordinates.
func _world_to_screen(p: Vector2) -> Vector2:
	var world: Control = main._world
	return world.get_global_transform_with_canvas() * p


## Window pixels for a canvas position (the window is smaller than 720x1280).
func _win(canvas_pos: Vector2) -> Vector2:
	return root.get_final_transform() * canvas_pos


func _click(canvas_pos: Vector2) -> void:
	var pos := _win(canvas_pos)
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


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func test_title() -> void:
	var title: Control = null
	for c in main.get_children():
		if c.get_script() and c.get_script().get_global_name() == "TitleScreen":
			title = c
	check(title != null, "title screen shows on start")
	if title == null:
		return
	var row: Control = main._world.rows[0]
	var p: Vector2 = _world_to_screen(row.position + Vector2(row.deposit_pos().x - 40, 150))
	var taps := [0]
	var count := func(_k: String) -> void: taps[0] += 1
	gs.tapped.connect(count)
	await _click(p)
	gs.tapped.disconnect(count)
	check(taps[0] == 0, "title blocks taps on the scene")
	# Let the intro finish (the button pops in).
	await create_timer(1.3).timeout
	await _click(_center(title._play))
	await create_timer(0.8).timeout
	await _frames(2)
	check(not is_instance_valid(title) or not title.is_inside_tree(), "Play closes the title")


func test_tap_dive() -> void:
	var row: Control = main._world.rows[0]
	var p: Vector2 = _world_to_screen(row.position + Vector2(row.deposit_pos().x - 40, 150))
	check(gs.cycle_progress("d0") >= 0.0, "divers work without taps")
	var taps := [0]
	var count := func(k: String) -> void: if k == "d0": taps[0] += 1
	gs.tapped.connect(count)
	await _click(p)
	gs.tapped.disconnect(count)
	check(taps[0] == 1, "tapping the site boosts the dive")


func test_upgrade_sheet() -> void:
	gs.coins = 100.0
	var card: Control = main._world.rows[0].card
	await _click(_center(card._upgrade))
	check(main._panel.visible and main._panel.key == "d0", "card button opens the upgrade sheet")
	await create_timer(0.4).timeout   # the sheet slides up
	var before: int = gs.get_level("d0")
	await _click(_center(main._panel._buy))
	check(gs.get_level("d0") == before + 1, "buy button upgrades")
	await _click(_center(main._panel._modes[1]))
	gs.coins = 1e6
	main._panel.refresh()
	await _click(_center(main._panel._buy))
	check(gs.get_level("d0") == before + 11, "x10 buys ten levels")
	await _click(_center(main._panel._close))
	await create_timer(0.35).timeout   # and slides away
	check(not main._panel.visible, "close hides the sheet")


func test_hire_manager() -> void:
	gs.coins = 1000.0
	var badge: Control = main._world.rows[0].card._manager
	await _click(_center(badge))
	check(gs.has_manager("d0"), "tapping the empty manager slot hires")


func test_drag_does_not_press() -> void:
	var card: Control = main._world.rows[0].card
	var start := _win(_center(card._upgrade))
	var scroll_before: float = main._scroller.scroll
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	down.global_position = start
	root.push_input(down)
	await _frames(1)
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = start - _win(Vector2(0, 12 * (i + 1))) + _win(Vector2.ZERO)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
		await _frames(1)
	var up := down.duplicate()
	up.pressed = false
	up.position = start - _win(Vector2(0, 120)) + _win(Vector2.ZERO)
	up.global_position = up.position
	root.push_input(up)
	await _frames(3)
	check(main._scroller.scroll > scroll_before + 50.0, "dragging from a button scrolls (%.0f -> %.0f)" % [scroll_before, main._scroller.scroll])
	check(not main._panel.visible, "and does not press the button")
	main._scroller.scroll_to(0.0)
	await _frames(2)


func test_open_depth() -> void:
	gs.coins = gs.unlock_cost("d1")
	var row: Control = main._world.rows[1]
	main._scroller.scroll_to(main._world.row_y(1) - 300.0)
	await _frames(3)
	main._refresh()
	await _frames(1)
	await _click(_center(row._open_btn))
	check(gs.is_open("d1"), "unlock button opens the next site")


func test_wheel_scroll() -> void:
	main._scroller.scroll_to(0.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	ev.position = _win(_center(main._scroller))
	ev.global_position = ev.position
	root.push_input(ev)
	await _frames(2)
	check(main._scroller.scroll > 0.0, "mouse wheel scrolls the ocean")


## Regression: the dock (quests, puzzle...) stayed off screen when its first
## feature unlocked mid-game, until the UI size setting forced a re-layout.
func test_dock_appears() -> void:
	var progress := root.get_node("Progress")
	progress.unlock_feature("quests")
	main._refresh()
	await create_timer(0.6).timeout
	var dock: Control = main._dock
	var view: Vector2 = main.get_viewport_rect().size
	var r := dock.get_global_rect()
	check(dock.is_visible_in_tree(), "dock shows once a feature unlocks")
	check(r.size.y > 0.0 and r.end.y <= view.y + 1.0 and r.position.y >= 0.0, "dock sits inside the screen")
	var sr: Rect2 = main._scroller.get_global_rect()
	check(sr.end.y <= r.position.y + 12.0, "ocean ends at the dock (a small tuck under its rounded top)")
	while not main._news.is_empty() or main._modal.visible:
		main._modal.close()
		main._news.clear()
		await _frames(2)


func test_language_switch() -> void:
	var original: String = root.get_node("Settings").language
	main._open_settings()
	await _frames(2)
	root.get_node("Settings").set_language("zh")
	await _frames(3)
	check(TranslationServer.get_locale() == "zh", "language switched")
	check(main._world.surface.boat_card._name.text.begins_with("运输船"), "card text follows the language")
	root.get_node("Settings").set_language(original)
	main._modal.close()


## A Dive Deeper takes the player to a new ocean: other water, sky and
## sand colors, the dive sites tinted, and the ocean's name shown.
func test_new_ocean() -> void:
	var ocean_look := load("res://scripts/ui/ocean_look.gd")
	var art := load("res://scripts/ui/art.gd")
	var day_night := load("res://scripts/ui/day_night.gd")
	check(ocean_look.ocean == 0, "the first ocean is ocean 0")
	var sea0: Color = art.water_color(0.0)
	var sky0: Color = day_night.sky_colors(0.25)[0]
	var row0: Color = main._world.rows[0].style()["water"]
	gs.prestige_count = 1
	await _frames(3)
	check(ocean_look.ocean == 1, "the world follows the ocean count")
	check(not art.water_color(0.0).is_equal_approx(sea0), "new ocean: other water")
	check(not day_night.sky_colors(0.25)[0].is_equal_approx(sky0), "new ocean: other sky")
	check(not main._world.rows[0].style()["water"].is_equal_approx(row0), "new ocean: dive sites tinted")
	var banner_found := false
	for c in main._world.get_children():
		if c.get_class() == "Control" and c.get("name_text") != null:
			banner_found = c.name_text == ocean_look.name_of(1) and c.name_text != ""
	check(banner_found, "the new ocean's name is shown")
	check(ocean_look.name_of(6).ends_with(" II"), "later oceans repeat the looks with a numeral")
	gs.prestige_count = 0
	await _frames(3)
	check(art.water_color(0.0).is_equal_approx(sea0), "back home: the original water")


## Wardrobe items and portraits stay inside their frames.
func test_art_fits() -> void:
	var art := load("res://scripts/ui/art.gd")
	var chars := load("res://scripts/ui/chars.gd")
	var hats := load("res://scripts/ui/hats_art.gd")
	var wardrobe := load("res://scripts/ui/wardrobe.gd")
	var worst := 0.0
	for h in hats.IDS:
		var l: Dictionary = chars.look(0, "short", 0, h, "none", 0, "shirt")
		art.measure_begin()
		chars.portrait(null, Vector2.ZERO, 50.0, l, "happy", false, Color.WHITE)
		var b: Rect2 = art.measure_end()
		worst = maxf(worst, maxf(-b.position.y, b.end.y))
	check(worst <= 50.5, "every hat stays inside the portrait ring (%.1f px of 50)" % worst)
	var s := Vector2(110, 130)
	var outside := 0
	for c in Content.COSMETICS:
		if not c["slot"] in ["pet", "boat", "suit"]:
			continue
		art.measure_begin()
		wardrobe._draw_item(null, c, s, 0.0)
		var b: Rect2 = art.measure_end()
		if b.position.x < -1.0 or b.position.y < -1.0 or b.end.x > s.x + 1.0 or b.end.y > s.y + 1.0:
			outside += 1
			print("  outside its card: ", c["id"], " ", b)
	check(outside == 0, "wardrobe pets, boats and suits fit inside their cards")
