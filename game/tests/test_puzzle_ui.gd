extends SceneTree
## The puzzle screen driven by real input events (headless is fine):
##   godot --headless --path . --resolution 390x844 -s res://tests/test_puzzle_ui.gd
## Checks the layout at a phone size and at 1600x900, a drag swap, a
## tap-tap swap, a bad swap, running out of moves (+5, then collect) and a win.

var _failures := 0
var _checks := 0
var screen: Control
## Loaded at run time: the screen uses autoloads that don't exist yet when
## this script compiles.
var PuzzleScreen: GDScript
var results: Array = []


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	PuzzleScreen = load("res://scripts/puzzle/puzzle_screen.gd")
	var gs := root.get_node_or_null("GameState")
	if gs and "autosave_enabled" in gs:
		gs.autosave_enabled = false
		gs.save_path = "user://test_puzzle_ui_save.json"
	for l in ["en", "ru", "es", "zh"]:
		var tr_res := load("res://i18n/puzzle.%s.translation" % l)
		if tr_res:
			TranslationServer.add_translation(tr_res)
	var tip_ok := true
	for l in ["en", "ru", "es", "zh"]:
		TranslationServer.set_locale(l)
		tip_ok = tip_ok and TranslationServer.translate("PZ_GOAL_HINT") != "PZ_GOAL_HINT"
	check(tip_ok, "the goal tip is translated in all 4 languages")
	TranslationServer.set_locale("en")
	root.size = Vector2i(390, 844)
	await _frames(4)
	await test_layout("phone")
	await test_swaps()
	await test_out_of_moves()
	await test_win()
	await test_leave()
	root.size = Vector2i(1600, 900)
	await _frames(4)
	await test_layout("wide")
	await test_swaps()
	await test_win()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_puzzle_ui_save.json")
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _open(n: int) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
		await _frames(2)
	results.clear()
	screen = PuzzleScreen.new()
	root.add_child(screen)
	screen.setup(PuzzleLevels.level(n), func(r: Dictionary) -> Array: return [["coin", "+%d" % (r["fragments"] * 100)]])
	screen.finished.connect(func(r: Dictionary): results.append(r))
	await _frames(3)
	check(screen.model != null and screen.is_inside_tree(), "puzzle screen opens (level %d)" % n)
	check(screen._tip > 0.0, "the level starts with the 'bring the pieces down' tip (level %d)" % n)


func _win(canvas_pos: Vector2) -> Vector2:
	return root.get_final_transform() * canvas_pos


func _press(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _win(pos)
	e.global_position = e.position
	root.push_input(e)
	await _frames(1)


func _click(canvas_pos: Vector2) -> void:
	await _press(canvas_pos, true)
	await _press(canvas_pos, false)
	await _frames(1)


func _drag(a: Vector2, b: Vector2) -> void:
	await _press(a, true)
	for i in range(1, 6):
		var m := InputEventMouseMotion.new()
		m.position = _win(a.lerp(b, i / 5.0))
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
		await _frames(1)
	await _press(b, false)


func _settle() -> void:
	for i in 900:
		if not screen.is_busy():
			break
		await process_frame
	await _frames(2)


func _wait_for(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return false


func _button(name: String) -> Button:
	if screen._panel == null:
		return null
	return screen._panel.find_child(name, true, false) as Button


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# --- Tests -----------------------------------------------------------------------------------

func test_layout(label: String) -> void:
	await _open(12)
	var view := screen.get_viewport_rect().size
	var board := Rect2(screen._board.global_position, screen._board.size)
	check(Rect2(Vector2.ZERO, view).encloses(board.grow(8.0)), "%s: board fits the screen (%s in %s)" % [label, board, view])
	check(screen.tile <= PuzzleScreen.MAX_TILE and screen.tile >= 40.0, "%s: tile size %.0f is sane" % [label, screen.tile])
	check(board.position.y > screen._top_rect.end.y + 20.0, "%s: board sits under the top bar" % label)
	check(absf(board.get_center().x - view.x / 2.0) < 2.0, "%s: board is centered" % label)
	check(screen._pause.get_global_rect().end.x <= view.x and screen._pause.get_global_rect().position.y >= 0.0, "%s: pause button on screen" % label)
	if label == "wide":
		check(screen.tile == PuzzleScreen.MAX_TILE, "wide: tiles use the max size")
	else:
		check(board.size.x > view.x * 0.8, "phone: the board uses the width (%.0f of %.0f)" % [board.size.x, view.x])


func test_swaps() -> void:
	await _open(3)
	var m: Match3 = screen.model
	var h := m.find_hint()
	var before := m.moves
	await _drag(screen.cell_screen_pos(h[0]), screen.cell_screen_pos(h[1]))
	check(m.moves == before - 1, "a drag makes the swap (moves %d -> %d)" % [before, m.moves])
	check(screen.shown_moves() == m.moves, "the moves counter drops right away")
	check(screen.is_busy() or m.moves == before - 1, "the cascade plays")
	await _settle()
	check(not screen.is_busy() and screen._grid == m.snapshot(), "after the animation the view matches the model")
	h = m.find_hint()
	before = m.moves
	await _click(screen.cell_screen_pos(h[0]))
	check(screen._selected == h[0], "a tap selects a tile")
	await _click(screen.cell_screen_pos(h[1]))
	check(m.moves == before - 1, "tap then tap a neighbour swaps")
	await _settle()
	# A swap that makes no line wobbles back and costs nothing.
	var bad := []
	for y in m.height:
		for x in m.width - 1:
			var a := Vector2i(x, y)
			if m.is_swappable(a) and m.is_swappable(a + Vector2i(1, 0)) and m._move_score(a, a + Vector2i(1, 0)) == 0:
				bad = [a, a + Vector2i(1, 0)]
				break
		if not bad.is_empty():
			break
	if not bad.is_empty():
		before = m.moves
		await _drag(screen.cell_screen_pos(bad[0]), screen.cell_screen_pos(bad[1]))
		check(m.moves == before, "a bad swap costs no move")
		await _settle()


func test_out_of_moves() -> void:
	await _open(2)
	var m: Match3 = screen.model
	m.fragments_needed = 99
	m.moves = 1
	screen._shown_moves = 1
	var h := m.find_hint()
	await _drag(screen.cell_screen_pos(h[0]), screen.cell_screen_pos(h[1]))
	await _settle()
	check(m.state == Match3.LOST, "out of moves: lost state")
	var shown := await _wait_for(func(): return _button("More") != null)
	check(shown, "out of moves panel offers +5")
	if not shown:
		return
	await _frames(20)
	await _click(_center(_button("More")))
	check(m.state == Match3.PLAYING and m.moves == PuzzleScreen.EXTRA_MOVES, "+5 moves continues the level")
	check(screen._panel == null, "the panel closes")
	m.moves = 1
	screen._shown_moves = 1
	h = m.find_hint()
	await _drag(screen.cell_screen_pos(h[0]), screen.cell_screen_pos(h[1]))
	await _settle()
	shown = await _wait_for(func(): return _button("Take") != null)
	check(shown and _button("More") == null, "second time: no more free moves, only collect")
	if not shown:
		return
	await _frames(20)
	var got := m.fragments_collected
	await _click(_center(_button("Take")))
	check(results.size() == 1, "finished fires once")
	if results.size() == 1:
		var r: Dictionary = results[0]
		check(r["won"] == false and r["fragments"] == got and r["fragments_needed"] == 99 and r["stars"] == 0 and r["level"] == 2, "partial result: %s" % r)
		check(r["artifact"] == PuzzleLevels.level(2)["artifact"] and r["left"] == false and r["moves_left"] == 0, "result names the artifact")


func test_win() -> void:
	await _open(1)
	var m: Match3 = screen.model
	m.fragments_collected = m.fragments_needed
	var h := m.find_hint()
	var budget: int = screen.level["moves"]
	await _drag(screen.cell_screen_pos(h[0]), screen.cell_screen_pos(h[1]))
	await _settle()
	check(m.state == Match3.WON, "win state")
	var shown := await _wait_for(func(): return _button("Collect") != null)
	check(shown, "win panel shows")
	if not shown:
		return
	await _frames(30)
	check(screen._reward_lines.size() == 1 and screen._reward_lines[0][0] == "coin", "win panel shows the caller's reward lines")
	await _click(_center(_button("Collect")))
	check(results.size() == 1, "Collect fires finished")
	if results.size() == 1:
		var r: Dictionary = results[0]
		check(r["won"] and r["stars"] == 3 and r["moves_left"] == budget - 1 and r["fragments"] == r["fragments_needed"] and r["level"] == 1, "win result: %s" % r)
	await create_timer(0.6).timeout   # it fades out first
	check(not is_instance_valid(screen), "the screen frees itself after finishing")


func test_leave() -> void:
	await _open(5)
	await _click(_center(screen._pause))
	check(screen._confirm.visible, "the close button asks first")
	await _click(_center(screen._confirm.find_child("Stay", true, false)))
	check(not screen._confirm.visible and results.is_empty(), "Stay keeps playing")
	await _click(_center(screen._pause))
	await _click(_center(screen._confirm.find_child("Leave", true, false)))
	check(results.size() == 1 and results[0]["won"] == false and results[0]["left"] == true, "Leave ends the level, not won")
