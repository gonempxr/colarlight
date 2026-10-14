class_name AtlasScreen
extends Control
## The Atlas of the Deep on its own screen (league games, Atlas autoload):
## a sonar map of act I's nodes under the Murk; tap a node to see it, pick
## runes and dive. A running dive opens the DiveScreen. Opened by
## main.open_atlas().

var main: Node
var _sel := Atlas.START_NODE
var _picked: Array = []
var _map: Control
var _panel: VBoxContainer
var _res_label: Label
var _t := 0.0


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func node_name(id: String) -> String:
	return t("ATLAS_N_" + id.to_upper())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The first open node not yet cleared is the one to look at.
	for id in Atlas.NODES:
		if Atlas.node_state(id) == "open":
			_sel = id
			break
	var bg := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): AtlasArt.draw_bg(ci, s, tt), Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(_top_bar())
	col.add_child(_resources())
	_map = Control.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(0, 300)
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.gui_input.connect(_on_map_input)
	var view := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_map(ci, s, tt), Vector2.ZERO, true)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.add_child(view)
	col.add_child(_map)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	col.add_child(_panel)
	_fill_panel()
	Atlas.changed.connect(_on_changed)
	Sfx.play("start")
	if not Atlas.dive.is_empty():
		(func(): open_dive()).call_deferred()


func _process(delta: float) -> void:
	_t += delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _on_changed() -> void:
	if is_inside_tree():
		_refresh_resources()
		_fill_panel()


# --- Top ------------------------------------------------------------------------------

func _top_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.theme_type_variation = &"RedButton"
	back.icon = Icons.get_icon("close", 34)
	back.custom_minimum_size = Vector2(76, 76)
	back.pressed.connect(close)
	h.add_child(back)
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 80)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.draw.connect(func(): UiTheme.draw_banner(banner, Rect2(Vector2.ZERO, banner.size), Color("2b3fa8")))
	banner.resized.connect(banner.queue_redraw)
	banner.add_child(_banner_label(t("ATLAS_TITLE"), 30, 0, -26, Art.WHITE, 10))
	banner.add_child(_banner_label(t("ATLAS_ACT1"), 18, 40, -8, Color("bff4ff"), 6))
	h.add_child(banner)
	var gear := Button.new()
	gear.theme_type_variation = &"BlueButton"
	gear.icon = Icons.get_icon("gear", 36)
	gear.custom_minimum_size = Vector2(76, 76)
	gear.tooltip_text = t("ATLAS_CREW")
	gear.pressed.connect(func(): Sfx.play("click"); main._top.open(func(m): _crew(m)))
	h.add_child(gear)
	return h


func _banner_label(text: String, px: int, top: float, bottom: float, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## Charts by tier, shards and runes on one dark glass strip.
func _resources() -> Control:
	var p := Views.card(Color("142a6b"))
	_res_label = Label.new()
	_res_label.add_theme_font_size_override("font_size", 19)
	_res_label.add_theme_color_override("font_color", Color("dff6ff"))
	_res_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_label.custom_minimum_size.x = 200
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(_res_label)
	_refresh_resources()
	return p


func _refresh_resources() -> void:
	var parts := []
	for tier in range(2, Atlas.MAX_TIER + 1):
		var n := Atlas.chart_count(tier)
		if n > 0:
			parts.append("T%d×%d" % [tier, n])
	var charts := t("ATLAS_CHARTS") + ": " + (" ".join(parts) if not parts.is_empty() else "T1 ∞")
	var nr := 0
	for r in Atlas.runes:
		nr += int(Atlas.runes[r])
	_res_label.text = "%s · %s: %d · %s: %d" % [charts, t("ATLAS_SHARDS"), Atlas.shards, t("ATLAS_RUNES"), nr]


# --- Map ------------------------------------------------------------------------------

func _node_pos(id: String, s: Vector2) -> Vector2:
	var p: Vector2 = Atlas.NODES[id]["pos"]
	var pad := Vector2(40, 34)
	# Never wider than tall (a wide PC screen keeps the map's shape).
	var w := minf(s.x - pad.x * 2.0, (s.y - pad.y * 2.0) * 1.1)
	var x0 := (s.x - w) / 2.0
	return Vector2(x0 + p.x * w, pad.y + p.y * (s.y - pad.y * 2.0))


func _draw_map(ci: CanvasItem, s: Vector2, tt: float) -> void:
	var week := OnlineRules.week_id(Clock.now())
	for id in Atlas.NODES:
		if Atlas.node_state(id) == "fog":
			AtlasArt.draw_murk(ci, _node_pos(id, s), tt)
	var drawn := {}
	for id in Atlas.NODES:
		for n in Atlas.NODES[id]["links"]:
			var key: String = id + n if id < n else n + id
			if drawn.has(key):
				continue
			drawn[key] = true
			AtlasArt.draw_link(ci, _node_pos(id, s), _node_pos(n, s), Atlas.cleared.has(id) or Atlas.cleared.has(n))
	for id in Atlas.NODES:
		var st := Atlas.node_state(id)
		AtlasArt.draw_node(ci, _node_pos(id, s), st, int(Atlas.NODES[id]["tier"]), Atlas.NODES[id].get("citadel", false),
			id == _sel, st != "fog" and Atlas.bounty_at(id, week) != "", tt)


func _on_map_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		at = event.position
	if at.x < 0.0:
		return
	var best := ""
	var best_d := 56.0
	for id in Atlas.NODES:
		var d := at.distance_to(_node_pos(id, _map.size))
		if d < best_d:
			best_d = d
			best = id
	if best != "" and best != _sel:
		Sfx.play("pop")
		_sel = best
		_picked = []
		_fill_panel()
	_map.accept_event()


# --- The chosen node ------------------------------------------------------------------

func _fill_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()
	var node: Dictionary = Atlas.NODES[_sel]
	var tier := int(node["tier"])
	var st := Atlas.node_state(_sel)
	var card := Views.card(Color("142a6b"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := Views.label("%s · %s" % [node_name(_sel), t("ATLAS_TIER") % tier], 22, Color("ffe08a"), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var info := ""
	match st:
		"fog":
			info = t("ATLAS_FOG")
		"cleared":
			info = t("ATLAS_CLEARED") + " ✓"
		_:
			info = t("ATLAS_INTRO") if _sel == Atlas.START_NODE and Atlas.cleared.is_empty() else ""
	if Atlas.act_done() and _sel == "boss1":
		info = t("ATLAS_ACT_DONE")
	var bounty := Atlas.bounty_at(_sel, OnlineRules.week_id(Clock.now())) if st != "fog" else ""
	if bounty != "":
		info = (info + "\n" if info != "" else "") + "☠ " + t("ATLAS_K_BOUNTY") + " " + t("ATLAS_B_" + bounty.to_upper())
	if info != "":
		var l := Views.label(info, 18, Color("dfe4ff"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	_panel.add_child(card)
	if st == "fog":
		return
	# Runes the player has: toggles, up to the node's slots.
	var owned := Atlas.RUNES.keys().filter(func(r): return int(Atlas.runes.get(r, 0)) > 0)
	if not owned.is_empty():
		var hint := Views.label(t("ATLAS_RUNES_HINT") % Atlas.rune_slots(tier), 17, Color("b9c2f0"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(hint)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		for r in owned:
			var b := Button.new()
			var on: bool = r in _picked
			b.text = "%s ×%d" % [t("ATLAS_RUNE_" + r.to_upper()), int(Atlas.runes[r])]
			b.tooltip_text = t("ATLAS_RUNE_" + r.to_upper() + "_D")
			b.theme_type_variation = &"SlimPurpleButton" if on else &"SlimCreamButton"
			b.custom_minimum_size = Vector2(0, 52)
			b.pressed.connect(func():
				Sfx.play("click")
				if r in _picked:
					_picked.erase(r)
				elif _picked.size() < Atlas.rune_slots(tier):
					_picked.append(r)
				_fill_panel())
			row.add_child(b)
		_panel.add_child(row)
		for r in _picked:
			var d := Views.label("• " + t("ATLAS_RUNE_" + r.to_upper() + "_D"), 17, Color("ffb4f0"))
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_panel.add_child(d)
	if Atlas.chart_count(tier) <= 0:
		var l := Views.label(t("ATLAS_NO_CHART") % tier, 19, Color("ffb4a8"), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(l)
		return
	var go := Button.new()
	go.text = t("ATLAS_DIVE") + ("" if tier <= 1 else "  (%s)" % (t("ATLAS_TIER") % tier))
	go.theme_type_variation = &"GoldButton"
	go.custom_minimum_size = Vector2(0, 84)
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(func():
		if Atlas.start_dive(_sel, _picked):
			_picked = []
			open_dive())
	_panel.add_child(go)


func open_dive() -> void:
	if Atlas.dive.is_empty():
		return
	var d := DiveScreen.new()
	d.main = main
	add_child(d)
	d.tree_exited.connect(func():
		if is_inside_tree():
			_refresh_resources()
			_fill_panel())


# --- Crew gear ------------------------------------------------------------------------

func _crew(m: Modal) -> void:
	m.title(t("ATLAS_CREW"))
	m.banner(UiTheme.BANNER_BLUE)
	m.text("%s: %d" % [t("ATLAS_SHARDS"), Atlas.shards], 22, Art.INK)
	for kind in Atlas.CREW:
		var c := Views.card(Color("eef5ff"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		c.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Views.label("%s · %s" % [t("ATLAS_CREW_" + kind.to_upper()), t("ATLAS_CREW_LV") % int(Atlas.crew[kind])], 22, Art.INK, true))
		var d := Views.label(t("ATLAS_CREW_" + kind.to_upper() + "_D"), 18, Art.INK_SOFT)
		d.custom_minimum_size.x = 140
		v.add_child(d)
		h.add_child(v)
		var cost := Atlas.crew_cost(kind)
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 64)
		if cost <= 0:
			b.text = t("ATLAS_CREW_MAX")
			b.disabled = true
		else:
			b.text = "%d %s" % [cost, t("ATLAS_SHARDS")]
			b.theme_type_variation = &"GoldButton" if Atlas.shards >= cost else &"CreamButton"
			b.pressed.connect(func():
				if Atlas.upgrade_crew(kind):
					Sfx.play("upgrade")
					m.rebuild()
				else:
					Sfx.play("deny"))
		h.add_child(b)
		m.add(c)
