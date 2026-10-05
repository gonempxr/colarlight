extends SceneTree
## The three rooms on the real main scene, with real clicks (headless is fine):
##   godot --headless --path . --resolution 390x844 -s res://tests/test_rooms_ui.gd
## Tabs and swipes switch rooms; the vault's Collect; the accountant; an
## evolution form bought from the room-1 card; a decor level bought from
## the office; the outfits tab; the map opened from the mini-map and
## closed; the next location opened from the map's gate; the tutorial
## leads to the factory and the vault; the hand cursor setting. Then the
## same on a PC-shaped window (side column).

var _failures := 0
var _checks := 0
var gs: Node
var pr: Node
var main: Node


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	# Headless windows start tiny (64 x 64): use a phone's.
	root.size = Vector2i(390, 844)
	gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_rooms_ui_save.json"
	gs.reset()
	pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://test_rooms_ui_progress.json"
	pr.reset()
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	TranslationServer.set_locale("en")
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(8)
	main = current_scene
	await test_tabs()
	await test_swipe()
	await test_vault()
	await test_accountant()
	await test_evolution()
	await test_decor()
	await test_outfits()
	await test_map()
	await test_location_advance()
	await test_tutorial()
	await test_cursor_setting()
	await test_wide()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_rooms_ui_save.json")
	DirAccess.remove_absolute("user://test_rooms_ui_progress.json")
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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


func _settle() -> void:
	await create_timer(0.5).timeout
	await _frames(2)


func _close_dialogs() -> void:
	main._news.clear()
	main._top.close()
	main._modal.close()
	if main._map.visible:
		main._map.close()
	await create_timer(0.3).timeout
	await _frames(2)


func _tab(i: int) -> Vector2:
	var tabs: Control = main.room_tabs()
	return tabs.get_global_transform_with_canvas() * tabs.tab_rect(i).get_center()


func _find(n: Node, cls: String, out: Array) -> Array:
	for c in n.get_children(true):
		if c.is_class(cls) or (c.get_script() and c.get_script().get_global_name() == cls):
			out.append(c)
		_find(c, cls, out)
	return out


func _button_with(n: Node, text: String) -> Button:
	for b in _find(n, "Button", []):
		var t: String = str(b.get("full_text")) if b.get("full_text") != null else b.text
		if b.is_visible_in_tree() and t.find(text) >= 0:
			return b
	return null


func test_tabs() -> void:
	check(main.current_room() == 0 and main._scroller.visible, "the game starts in the mine")
	await _click(_tab(1))
	await _settle()
	check(main.current_room() == 1 and main._factory.visible and not main._scroller.visible, "the Factory tab shows the factory")
	check(main.stage_card("plant").is_visible_in_tree(), "the plant's card is in the factory")
	await _click(_tab(2))
	await _settle()
	check(main.current_room() == 2 and main._office.visible and not main._factory.visible, "the Office tab shows the office")
	check(main.office_bar().is_visible_in_tree(), "the office buttons show")
	await _click(_tab(0))
	await _settle()
	check(main.current_room() == 0 and main._scroller.visible and not main._office.visible, "the Mine tab brings the mine back")
	check(main.evo_card().is_visible_in_tree(), "the evolution card is in the mine")
	# A tap on the factory's machine line selects it in the panel.
	main.show_room(1, false)
	await _frames(2)
	var f: Control = main._factory
	var line: Rect2 = f.line_rect("plant")
	await _click(f.get_global_transform_with_canvas() * (line.position + line.size * Vector2(0.3, 0.8)))
	await _settle()
	check(main._panel.key == "plant" and main._panel.visible, "tapping the plant line shows it in the panel (%s)" % main._panel.key)
	main._close_sheet()
	main.show_room(0, false)
	await _settle()


func _drag(from: Vector2, to: Vector2) -> void:
	var a := _win(from)
	var b := _win(to)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	root.push_input(down)
	await _frames(1)
	for i in 8:
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, (i + 1) / 8.0)
		m.global_position = m.position
		m.relative = (b - a) / 8.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
		await _frames(1)
	var up := down.duplicate()
	up.pressed = false
	up.position = b
	up.global_position = b
	root.push_input(up)
	await _frames(2)


func test_swipe() -> void:
	var area: Rect2 = main._area
	var mid := area.get_center() + Vector2(0, area.size.y * 0.1)
	await _drag(mid + Vector2(150, 0), mid - Vector2(150, 0))
	await _settle()
	check(main.current_room() == 1, "swiping left goes to the factory")
	await _drag(mid + Vector2(150, 0), mid - Vector2(150, 0))
	await _settle()
	check(main.current_room() == 2, "and again to the office")
	await _drag(mid - Vector2(150, 0), mid + Vector2(150, 0))
	await _settle()
	check(main.current_room() == 1, "swiping right goes back")
	# Up and down is not a swipe.
	main.show_room(0, false)
	await _frames(2)
	await _drag(mid + Vector2(0, 150), mid - Vector2(0, 150))
	await _settle()
	check(main.current_room() == 0, "a vertical drag scrolls, it does not change the room")
	main._scroller.scroll_to(0.0)


func test_vault() -> void:
	gs.vault = 0.0
	gs.coins = 0.0
	# Without the accountant, finished coins wait in the vault.
	gs.managers["vault"] = false
	gs.dock = 100.0
	gs.tap("plant")
	var t0 := Time.get_ticks_msec()
	while gs.vault <= 0.0 and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	check(gs.vault > 0.0, "the plant's coins land in the vault (%.1f)" % gs.vault)
	# The tab's badge shows whole coins (a first cycle can make less than 1).
	gs.vault = maxf(gs.vault, 25.0)
	gs.vault_changed.emit()
	await create_timer(0.4).timeout
	var tabs: Node = main.room_tabs()
	check(tabs._badge[2] != "", "the Office tab shows the coins waiting")
	main.show_room(2, false)
	await _frames(3)
	var office: OfficeRoom = main._office
	var before: float = gs.coins
	var waiting: float = gs.vault
	await _click(office.get_global_transform_with_canvas() * office.slot_rect("collect").get_center())
	check(gs.vault == 0.0 and gs.coins >= before + waiting - 0.01, "Collect moves the vault into the wallet (%.1f -> %.1f)" % [before, gs.coins])
	await _frames(2)
	check(main._fx._parts.size() > 0, "coins burst out of the vault")


func test_accountant() -> void:
	main.show_room(2, false)
	await _frames(2)
	gs.coins = gs.manager_cost("vault") + 10.0
	var bar: Node = main.office_bar()
	bar.refresh()
	await _click(_center(bar.button("vault")))
	check(gs.has_manager("vault"), "the accountant button hires the accountant")
	gs.vault = 0.0
	gs.dock = 100.0
	gs.tap("plant")
	var coins0: float = gs.coins
	var t0 := Time.get_ticks_msec()
	while gs.coins <= coins0 and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	check(gs.vault == 0.0 and gs.coins > coins0, "with the accountant the coins go straight to the wallet")
	gs.managers["vault"] = false
	main.show_room(0, false)
	await _frames(2)


func test_evolution() -> void:
	await _close_dialogs()
	gs.evo = 0
	gs.coins = gs.evo_cost(1) + 5.0
	var card: Node = main.evo_card()
	card.refresh()
	await _frames(2)
	await _click(_center(card.button()))
	await _settle()
	check(main._modal.visible, "the evolution card opens the panel")
	var texts := []
	for l in _find(main._modal, "Label", []):
		texts.append(l.text)
	check(TranslationServer.translate("EVO_OPTIONAL") in texts, "the panel says forms are optional for the next world")
	check(texts.count("???") == 13 - 1 - 3, "owned + next three shown, the rest hidden (%d hidden)" % texts.count("???"))
	var buy := _button_with(main._modal, TranslationServer.translate("EVO_BUY"))
	check(buy != null, "a Buy button with the price")
	var mult0: float = gs.income_mult()
	if buy:
		await _click(_center(buy))
	await _frames(3)
	check(gs.evo == 1, "Buy buys the next form (evo %d)" % gs.evo)
	check(gs.income_mult() > mult0 * 1.09, "the form adds about +10% income")
	check(main._toast.visible, "a toast names the new look")
	texts.clear()
	for l in _find(main._modal, "Label", []):
		texts.append(l.text)
	check(texts.count("???") == 13 - 2 - 3, "the panel shows one more form (%d hidden)" % texts.count("???"))
	# Too dear: nothing happens.
	gs.coins = 0.0
	main._modal.rebuild()
	await _frames(2)
	buy = _button_with(main._modal, TranslationServer.translate("EVO_BUY"))
	if buy:
		await _click(_center(buy))
	check(gs.evo == 1, "no coins, no form")
	# The office board opens the same panel.
	await _close_dialogs()
	main.show_room(2, false)
	await _frames(2)
	var office: OfficeRoom = main._office
	await _click(office.get_global_transform_with_canvas() * office.slot_rect("board").get_center())
	await _settle()
	check(main._modal.visible and TranslationServer.translate("EVO_BOARD") in _titles(), "the office board opens the evolution panel")
	await _close_dialogs()


func _titles() -> Array:
	var out := []
	for l in _find(main._modal, "Label", []):
		out.append(l.text)
	return out


func test_decor() -> void:
	await _close_dialogs()
	main.show_room(2, false)
	await _frames(2)
	pr.pearls = 200
	pr.decor["sofa"] = 0
	var office: OfficeRoom = main._office
	await _click(office.get_global_transform_with_canvas() * office.slot_rect("sofa").get_center())
	await _settle()
	check(main._modal.visible and load("res://scripts/ui/decor_panel.gd").slot == "sofa", "tapping the sofa opens the decor shop on it")
	var cost: int = pr.decor_cost("sofa")
	var buy: Button = null
	for b in _find(main._modal, "PriceButton", []):
		if b.is_visible_in_tree():
			buy = b
	check(buy != null, "the decor shop has a buy button")
	var bonus0: float = pr.decor_bonus()
	if buy:
		await _click(_center(buy))
	await _frames(3)
	check(pr.decor_level("sofa") == 1 and pr.pearls == 200 - cost, "buying a level costs pearls (lv %d, pearls %d)" % [pr.decor_level("sofa"), pr.pearls])
	check(pr.decor_bonus() > bonus0, "a decor level adds income")
	check(office.decor("sofa") == 1, "the office shows the new sofa")
	# The Decor button picks another piece.
	await _close_dialogs()
	await _click(_center(main.office_bar().button("decor")))
	await _settle()
	check(main._modal.visible and TranslationServer.translate("DECOR") in _titles(), "the Decor button opens the shop")
	await _close_dialogs()


func test_outfits() -> void:
	main.show_room(2, false)
	await _frames(2)
	await _click(_center(main.office_bar().button("outfit")))
	await _settle()
	check(main._modal.visible and load("res://scripts/ui/wardrobe.gd").tab == "outfit", "the Outfits button opens the wardrobe on outfits")
	var names := _titles()
	check(TranslationServer.translate("ITEM_OUTFIT_CAPTAIN") in names, "outfits are listed")
	check(not TranslationServer.translate("TAB_SUITS") in names, "the old diver suits tab is gone")
	pr.owned["outfit_chef"] = true
	pr.equip("outfit_chef")
	check(pr.equipped.get("outfit") == "outfit_chef", "an outfit can be worn")
	await _close_dialogs()
	main.show_room(0, false)
	await _frames(2)


func test_map() -> void:
	await _close_dialogs()
	main.show_room(0, false)
	main._scroller.scroll_to(0.0)
	await _frames(3)
	var mini: Control = main._mini if main._wide else main._mini_world
	check(mini.is_visible_in_tree(), "the mini-map shows in the mine")
	await _click(_center(mini))
	await _frames(3)
	check(main._map.visible, "the mini-map opens the world map")
	await _click(_center(main._map._x))
	await _frames(3)
	check(not main._map.visible, "the map's X closes it")
	main.show_room(1, false)
	await _frames(3)
	check(not mini.is_visible_in_tree(), "the mini-map stays in the mine")
	main.show_room(0, false)
	await _frames(2)


func test_location_advance() -> void:
	await _close_dialogs()
	for i in 10:
		gs.levels["d%d" % i] = maxi(1, gs.get_level("d%d" % i))
		gs.managers["d%d" % i] = true
	for k in gs.AUTOMATED:
		gs.levels[k] = maxi(1, gs.get_level(k))
		gs.managers[k] = true
	check(gs.location_ready(), "the gate's goals are met")
	gs.coins = gs.next_location_cost() * 1.01
	var loc0: int = gs.location
	var pearls0: int = pr.pearls
	main.show_room(2, false)
	main.open_map()
	await _frames(4)
	var go := _button_with(main._map, TranslationServer.translate("OPEN_WORLD").replace("%s", "").strip_edges())
	check(go != null and not go.disabled, "the map's gate offers the next world")
	if go:
		await _click(_center(go))
		await _frames(3)
	var yes := _button_with(main._map, TranslationServer.translate("MAP_YES"))
	check(yes != null, "it asks first")
	if yes:
		await _click(_center(yes))
		await _frames(5)
	check(gs.location == loc0 + 1, "the next location opens (%d)" % gs.location)
	check(main.current_room() == 0, "back in the mine of the new world")
	check(pr.pearls >= pearls0 + 25, "with a pearl gift")
	check(load("res://scripts/ui/world_look.gd").location_now() == gs.location, "the world look follows")
	check(main.evo_card()._sig.size() > 0 and int(main.evo_card()._sig[4]) == gs.location, "the evolution card follows the new world")
	await _click(_center(main._map._x))
	await _frames(3)
	check(not main._map.visible, "the map closes")
	await _close_dialogs()


func test_tutorial() -> void:
	await _close_dialogs()
	gs.reset()
	pr.tutorial_step = 3
	gs.dock = 50.0
	gs.managers["plant"] = false
	# The reset brings back "something new" news: put them away.
	await _frames(2)
	await _close_dialogs()
	main.show_room(0, false)
	await _wait_key("TUT_GO_FACTORY")
	var tutor: Node = main._tutor
	check(tutor._has_target and tutor.key == "TUT_GO_FACTORY", "the tutorial points at the Factory tab (%s)" % tutor.key)
	check(tutor._target.distance_to(_tab(1)) < 5.0, "right at the tab")
	main.show_room(1, false)
	await _wait_key("TUT_TAP_PLANT")
	check(tutor.key == "TUT_TAP_PLANT", "in the factory it points at the machine (%s)" % tutor.key)
	gs.tap("plant")
	await _frames(2)
	check(pr.tutorial_step == 4, "tapping the plant ends the step")
	# The upgrade waits for coins that sit in the vault: collect first.
	gs.coins = 0.0
	gs.vault = gs.upgrade_cost("d0") * 2.0
	main.show_room(0, false)
	await _wait_key("TUT_VAULT")
	check(tutor.key == "TUT_VAULT", "coins in the vault: it points at the Office (%s)" % tutor.key)
	main.show_room(2, false)
	await _wait_key("TUT_COLLECT")
	check(tutor.key == "TUT_COLLECT", "then at Collect (%s)" % tutor.key)
	gs.collect_vault()
	await _wait_key("TUT_GO_MINE")
	check(tutor.key == "TUT_GO_MINE", "then back to the mine (%s)" % tutor.key)
	main.show_room(0, false)
	await _wait_key("TUT_UPGRADE")
	check(tutor.key == "TUT_UPGRADE", "and the upgrade (%s)" % tutor.key)
	pr.tutorial_step = 12
	await _frames(2)


## Waits (up to 3 s) for the tutorial to show `key`.
func _wait_key(key: String) -> void:
	var t0 := Time.get_ticks_msec()
	while main._tutor.key != key and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	if main._tutor.key != key:
		print("  tutor: top=%s map=%s puzzle=%s fish=%s title=%s sheet=%s step=%d" % [main._top.visible, main._map.visible, is_instance_valid(main._puzzle), is_instance_valid(main._fishing), is_instance_valid(main._title), main._sheet_open, pr.tutorial_step])
		var ls := []
		for l in _find(main._top, "Label", []):
			ls.append(l.text)
		print("  top: ", ls.slice(0, 6))


func test_cursor_setting() -> void:
	var st := root.get_node("Settings")
	check(st.hand_cursor == true, "the hand cursor is on by default")
	main._open_settings()
	await _settle()
	var has_row := TranslationServer.translate("HAND_CURSOR") in _titles()
	check(has_row == not load("res://scripts/ui/hand_cursor.gd").touch_device(), "settings have the Hand cursor toggle on PC")
	st.set_value("hand_cursor", false)
	check(st.hand_cursor == false, "it can be turned off")
	st.set_value("hand_cursor", true)
	await _close_dialogs()


func test_wide() -> void:
	root.size = Vector2i(1440, 900)
	await _frames(6)
	if not main._wide:
		print("  (window could not be made wide here; skipping the PC part)")
		root.size = Vector2i(390, 844)
		return
	check(main.room_tabs().floating, "PC: the tabs float under the notch")
	main.show_room(0, false)
	await _frames(4)
	check(main._side_lift.is_visible_in_tree() and main._side_evo.is_visible_in_tree() and not main._side_plant.is_visible_in_tree(), "PC mine: lift, boat and evolution cards")
	main.show_room(1, false)
	await _frames(4)
	check(main._side_plant.is_visible_in_tree() and not main._side_lift.is_visible_in_tree() and main._panel.visible, "PC factory: the plant card and the panel")
	main.show_room(2, false)
	await _frames(4)
	check(main._side_office.is_visible_in_tree() and not main._panel.visible, "PC office: the office card")
	gs.vault = 500.0
	gs.managers["vault"] = false
	main._side_office.refresh()
	await _frames(2)
	var c0: float = gs.coins
	await _click(_center(main._side_office.button("collect")))
	check(gs.vault == 0.0 and gs.coins >= c0 + 499.0, "PC: the card's Collect works")
	var r: Rect2 = main.room_tabs().get_global_rect()
	check(r.position.y >= main._hud.used_height(), "PC: the tabs sit under the notch")
	root.size = Vector2i(390, 844)
	await _frames(4)
