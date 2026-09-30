class_name Hints
extends RefCounted
## The lightbulb's brain: looks at the game and picks the single most useful
## next step, in plain words a child can follow, plus where to point.
## pick() returns {id, text, urgent, point (Callable -> screen point or
## null), open (feature id to open instead of pointing, or "")}.


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func pick(main: Node) -> Dictionary:
	var gs := GameState
	var world: World = main._world
	if Progress.has_feature("daily") and Progress.daily_ready():
		return _hint("daily", t("HINT_DAILY"), true, Callable(), "daily")
	if Progress.has_feature("quests") and Progress.quests_ready() > 0:
		return _hint("quests", t("HINT_QUESTS"), true, Callable(), "quests")
	for k in GameState.AUTOMATED:
		if gs.is_open(k) and not gs.has_manager(k) and gs.coins >= gs.manager_cost(k):
			var card: StageCard = main.stage_card(k)
			return _hint("hire_" + k, t("HINT_HIRE_" + k.to_upper()), true, func():
				if card.key != k:
					card.show_unit(k)
				return _control(card._manager), "")
	if not gs.has_manager("lift") and gs.pit > 0.0 and gs.cycle_progress("lift") < 0.0:
		return _hint("tap_lift", t("HINT_TAP_LIFT"), true, func(): return _world(world, world.lift.cabin_pos() + Vector2(0, -30)), "")
	if not gs.has_manager("boat") and gs.hold > 0.0 and gs.cycle_progress("boat") < 0.0:
		return _hint("tap_boat", t("HINT_TAP_BOAT"), true, func(): return _world(world, world.surface.boat_world_pos() + Vector2(0, -40)), "")
	if not gs.has_manager("plant") and gs.dock > 0.0 and gs.cycle_progress("plant") < 0.0:
		return _hint("tap_plant", t("HINT_TAP_PLANT"), true, func(): return _world(world, world.surface.plant_world_pos() + Vector2(40, -80)), "")
	# The second boat/plant when ore piles up in front of the first one.
	for k in ["boat2", "plant2"]:
		var group := "boat" if k == "boat2" else "plant"
		if gs.is_open("d2") and not gs.is_open(k) and gs.bottleneck() == group and gs.coins >= gs.unlock_cost(k):
			var card: StageCard = main.stage_card(k)
			return _hint("buy_" + k, t("HINT_" + k.to_upper()), true, func(): return _control(card._unit_btns[1] if card._unit_btns[1].visible else card._upgrade), "")
	var next: String = gs.next_depth()
	if next != "" and gs.coins >= gs.unlock_cost(next):
		var row: DepthRow = world.rows[gs.depth_index(next)]
		return _hint("open_depth", t("HINT_OPEN_DEPTH") % Views.stage_name(next), true, func(): return _control(row._open_btn), "")
	for i in Balance.DEPTHS.size():
		var k := "d%d" % i
		if gs.is_open(k) and not gs.has_manager(k) and gs.coins >= gs.manager_cost(k):
			var card: StageCard = main.stage_card(k)
			return _hint("foreman", t("HINT_FOREMAN") % Views.stage_name(k), true, func(): return _control(card._manager), "")
	if gs.can_prestige():
		return _hint("prestige", t("HINT_PRESTIGE"), true, Callable(), "prestige")
	# Upgrade the slowest part if the player can afford it.
	var weak := _weakest(gs)
	if weak != "" and gs.coins >= gs.upgrade_cost(weak):
		var card: StageCard = main.stage_card(weak)
		return _hint("upgrade", t("HINT_BOTTLENECK") % Views.stage_name(weak), true, func(): return _control(card._upgrade), "")
	if Progress.has_feature("fishing") and _fish_caught(main) < 3:
		return _hint("fishing", t("HINT_FISHING"), false, Callable(), "fishing")
	if Progress.has_feature("puzzle") and int(Progress.stats.get("puzzles_won", 0)) < 3:
		return _hint("puzzle", t("HINT_PUZZLE"), false, Callable(), "puzzle")
	for k in GameState.AUTOMATED:
		if gs.is_open(k) and not gs.has_manager(k):
			var card: StageCard = main.stage_card(k)
			var line: String = t("HINT_SAVE_" + k.to_upper()) % NumFormat.short(gs.manager_cost(k))
			return _hint("save_" + k, line, false, func():
				if card.key != k:
					card.show_unit(k)
				return _control(card._manager), "")
	if next != "":
		var row: DepthRow = world.rows[gs.depth_index(next)]
		return _hint("save_depth", t("HINT_SAVE_DEPTH") % [NumFormat.short(gs.unlock_cost(next)), Views.stage_name(next)], false, func(): return _control(row._open_btn), "")
	if weak != "":
		var card: StageCard = main.stage_card(weak)
		return _hint("upgrade_later", t("HINT_UPGRADE") % Views.stage_name(weak), false, func(): return _control(card._upgrade), "")
	return _hint("tap_divers", t("HINT_TAP_DIVERS"), false, func(): return _world(world, world.rows[0].position + Vector2(world.rows[0].deposit_pos().x - 40, 150)), "")


## Slowest stage: the lift, the boat, the plant, or (when the dives are the limit)
## the cheapest dive site to upgrade.
static func _weakest(gs: Node) -> String:
	var group: String = gs.bottleneck()
	if group != "dives":
		# With two boats (or plants), the cheaper one to upgrade.
		var second := group + "2"
		if gs.is_open(second) and gs.upgrade_cost(second) < gs.upgrade_cost(group):
			return second
		return group
	var best := ""
	var best_cost := INF
	for i in Balance.DEPTHS.size():
		var k := "d%d" % i
		if gs.is_open(k) and gs.upgrade_cost(k) < best_cost:
			best_cost = gs.upgrade_cost(k)
			best = k
	return best


static func _hint(id: String, text: String, urgent: bool, point: Callable, open: String) -> Dictionary:
	return {"id": id, "text": text, "urgent": urgent, "point": point, "open": open}


static func _control(c: Control) -> Variant:
	if c == null or not c.is_visible_in_tree():
		return null
	return c.get_global_rect().get_center()


static func _world(world: World, p: Vector2) -> Variant:
	return world.get_global_transform_with_canvas() * p


## The hint dialog: the tip in big letters, a "Show me" button, and the
## automation checklist so it is obvious that everything can run alone.
static func build(m: Modal, main: Node, h: Dictionary) -> void:
	m.title(t("HINT_TITLE"))
	var bulb := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): HintButton.draw_bulb(ci, s / 2.0, 46.0, tt, true), Vector2(0, 110), true)
	m.add(bulb)
	m.text(h["text"], 26)
	var open: String = h["open"]
	var point: Callable = h["point"]
	if open != "":
		m.button(t("OPEN_IT"), func():
			Sfx.play("click")
			m.close()
			if open == "prestige":
				main._open_prestige()
			else:
				main.open_feature(open), &"GoldButton")
	elif point.is_valid():
		m.button(t("HINT_SHOW"), func():
			Sfx.play("click")
			m.close()
			main._tutor.show_hint(point, h["text"]), &"GoldButton")
	# Automation checklist.
	var card := Views.card(Color("eaf6ff"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(Views.label(t("HINT_AUTO_TITLE"), 24, Art.INK, true))
	var intro := Views.label(t("HINT_AUTO_TEXT"), 19, Art.INK_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	var gs := GameState
	var foremen := 0
	var open_sites := 0
	for i in Balance.DEPTHS.size():
		if gs.is_open("d%d" % i):
			open_sites += 1
			if gs.has_manager("d%d" % i):
				foremen += 1
	var rows := [
		[true, t("HINT_AUTO_DIVERS") + "  (%d/%d)" % [foremen, open_sites]],
		[gs.has_manager("lift"), t("HINT_AUTO_LIFT")],
		[gs.has_manager("boat"), t("HINT_AUTO_BOAT")],
		[gs.has_manager("plant"), t("HINT_AUTO_PLANT")],
	]
	for k in ["boat2", "plant2"]:
		if gs.is_open(k):
			rows.append([gs.has_manager(k), t("HINT_AUTO_" + k.to_upper())])
	for r in rows:
		var h2 := HBoxContainer.new()
		h2.add_theme_constant_override("separation", 10)
		var ic := Views.icon("check" if r[0] else "lock", 34)
		h2.add_child(ic)
		var l := Views.label(r[1], 19, Art.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 200
		h2.add_child(l)
		v.add_child(h2)
	m.add(card)


static func _fish_caught(main: Node) -> int:
	var f := main.get_node_or_null("/root/Fishing")
	return int(f.stats.get("caught", 0)) if f else 0
