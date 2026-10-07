class_name EvoPanel
extends RefCounted
## The workers' gear and skins (a wide dialog with two tabs).
## Gear: the next gear level big with its price and a Buy button, then all
## four levels of this world in a row (owned ones with a check, the others
## with their price: nothing is hidden). Each level is a big income boost
## in this world; gear is not needed to open the next world (the panel
## says so).
## Skins: the world's skins by rarity (rare, epic, legendary), bought with
## pearls at a shown price, each with a small income bonus in this world
## while the workers wear it. Legendary skins stay a silhouette with "?"
## until the player has the pearls for them.

## "gear" or "skins".
static var tab := "gear"
## The level or skin just bought pops in once.
static var _fresh := -1
static var _fresh_skin := ""


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func build(m: Modal, main: Node) -> void:
	var gs := GameState
	m.title(t("EVO_BOARD"))
	var sub := m.text(t("EVO_SUB") % WorldLook.name_of(gs.location), 22, Color("7a4fc4"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for tb: Array in [["gear", "TAB_GEAR"], ["skins", "TAB_SKINS"]]:
		var b := Button.new()
		b.text = t(tb[1])
		b.theme_type_variation = &"PurpleButton" if tab == tb[0] else &"CreamButton"
		b.custom_minimum_size = Vector2(150, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		var id: String = tb[0]
		b.pressed.connect(func():
			Sfx.play("click")
			tab = id
			m.rebuild())
		tabs.add_child(b)
	m.add(tabs)
	if tab == "skins":
		_skins(m, main)
	else:
		_gear(m, main)


# --- Gear ---------------------------------------------------------------------------

static func _gear(m: Modal, main: Node) -> void:
	var gs := GameState
	var w: String = gs.world_id()
	var e: int = gs.evo
	var done := e >= Balance.EVO_FORMS
	var shown := e if done else e + 1
	var fresh := _fresh
	var hero := Views.card(Color("f3e9ff"))
	var hsb: ToonBox = hero.get_theme_stylebox("panel")
	hsb.line = WorkerLooks.GEAR_COLORS[shown].darkened(0.35)
	hsb.line_w = 5.0
	var hv := HBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero.add_child(hv)
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		var pop := 1.0
		if fresh == shown and tt < 0.6 and not Settings.reduce_motion:
			pop = 0.7 + 0.3 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.08
		Art.glow(ci, c, s.y * 0.55, Color(WorkerLooks.GEAR_COLORS[shown], 0.45))
		if not Settings.reduce_motion:
			for i in 8:
				var a := tt * 0.5 + i * TAU / 8.0
				Art.toon(ci, Art.star_pts(c + Vector2(cos(a), sin(a)) * s.y * 0.44, 5.0, 2.2, 4, a), Color(1, 0.95, 0.6, 0.8), 0.0, 0.0)
		Art.push(ci, c, 0.0, Vector2(pop, pop))
		WorkerLooks.draw_card(ci, Vector2.ZERO, s.y * 0.95, w, shown, true, tt)
		Art.pop(ci), Vector2(190, 210), true)
	hv.add_child(pic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	hv.add_child(info)
	info.add_child(chip(t("GEAR_LEVEL") % (shown + 1), WorkerLooks.GEAR_COLORS[shown]))
	var name := Views.label(t(WorkerLooks.gear_key(w, shown)), 28, Art.INK, true)
	_wrap(name, 160)
	info.add_child(name)
	if done:
		info.add_child(_wrap(Views.label(t("GEAR_MAX"), 24, Color("7a4fc4"), true), 160))
	else:
		info.add_child(_wrap(Views.label(t("GEAR_PERK") % _step_pct(shown), 21, Art.GREEN_DARK, true), 160))
		var cost: float = gs.evo_cost(shown)
		var buy := PriceButton.new()
		buy.custom_minimum_size = Vector2(0, 80)
		buy.add_theme_font_size_override("font_size", 28)
		buy.set_price(t("EVO_BUY"), NumFormat.short(cost), "coin")
		buy.theme_type_variation = &"GoldButton" if gs.coins >= cost else &"DarkButton"
		buy.pressed.connect(func(): _buy(m, main, buy))
		info.add_child(buy)
		if gs.coins < cost:
			info.add_child(_wrap(Views.label(t("EVO_NEED") % NumFormat.short(cost - gs.coins), 18, Art.INK_SOFT), 160))
	m.add(hero)
	# The four levels, all with their price (kids see what comes next).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for g in WorkerLooks.GEARS:
		row.add_child(_level_cell(w, g, e, fresh))
	m.add(row)
	# Bonus so far and "not needed for the next world".
	var note := Views.card(Color("eaf6ff"))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 4)
	note.add_child(nv)
	nv.add_child(_wrap(Views.label(t("GEAR_TOTAL") % _pct(Balance.evo_mult(e)), 22, Art.INK, true), 200))
	nv.add_child(_wrap(Views.label(t("GEAR_OPTIONAL"), 18, Art.INK_SOFT), 200))
	m.add(note)
	_fresh = -1


## Extra income of gear level `level` over the one before it, in percent.
static func _step_pct(level: int) -> int:
	return roundi((Balance.evo_mult(level) / Balance.evo_mult(level - 1) - 1.0) * 100.0)


static func _pct(mult: float) -> int:
	return roundi((mult - 1.0) * 100.0)


static func _level_cell(w: String, g: int, e: int, fresh: int) -> Control:
	var owned := g <= e
	var col: Color = WorkerLooks.GEAR_COLORS[g]
	var card := Views.card(Color("fff1c2") if g == e else Color("fffaf0"))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.line = col.darkened(0.4)
	sb.line_w = 5.0 if g == e else 4.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		Art.flat(ci, Art.circle_pts(c, minf(s.x, s.y) * 0.44, 28), Color(col, 0.25))
		var pop := 1.0
		if fresh == g and tt < 0.6 and not Settings.reduce_motion:
			pop = 0.6 + 0.4 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.1
		Art.push(ci, c, 0.0, Vector2(pop, pop))
		WorkerLooks.draw_card(ci, Vector2.ZERO, minf(s.y, s.x * 1.05), w, g, true, tt)
		Art.pop(ci)
		if owned:
			var k := Vector2(s.x - 14, 14)
			Art.t_circle(ci, k, 11.0, Art.GREEN, 2.5, 0.0)
			Art.polyline(ci, PackedVector2Array([k + Vector2(-5, 0), k + Vector2(-1, 4), k + Vector2(6, -4)]), Art.WHITE, 3.0), Vector2(0, 104), true)
	pic.clip_contents = true
	v.add_child(pic)
	var lv := Views.label(t("GEAR_LEVEL") % (g + 1), 16, col.darkened(0.45), true)
	_one_line(lv)
	v.add_child(lv)
	var line: Control
	if g == e:
		var l := Views.label(t("EVO_NOW"), 15, Color("b8860b"), true)
		_one_line(l)
		line = l
	elif owned:
		var l := Views.label("+%d%%" % _pct(Balance.evo_mult(g)), 16, Art.GREEN_DARK, true)
		_one_line(l)
		line = l
	else:
		var cost: float = GameState.evo_cost(g)
		var l := Views.label(NumFormat.short(cost), 17, Art.GOLD_DARK if GameState.coins >= cost and g == e + 1 else Art.INK_SOFT, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 3)
		h.add_child(Views.icon("coin", 18))
		h.add_child(l)
		line = h
	v.add_child(line)
	return card


# --- Skins --------------------------------------------------------------------------

static func _skins(m: Modal, main: Node) -> void:
	var gs := GameState
	var w: String = gs.world_id()
	var top := m.row(10)
	var hint := Views.label(t("SKINS_HINT"), 19, Art.INK_SOFT)
	_wrap(hint, 180)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hint)
	var pearls := Views.chip("pearl", str(Progress.pearls), 30)
	pearls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pearls)
	var list := Content.skins_of(w)
	var v := m.get_viewport_rect().size
	var cols := 4 if v.x >= 600.0 else 3
	for r in range(1, 4):
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 10)
		head.add_child(chip(t(WorkerLooks.RARITY_KEYS[r]), WorkerLooks.RARITY_COLORS[r]))
		var bonus := Views.label(t("SKIN_BONUS") % roundi(Balance.SKIN_BONUS[r] * 100.0), 20, Art.GREEN_DARK, true)
		bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
		head.add_child(bonus)
		m.add(head)
		var grid := GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for i in list.size():
			if int(list[i]["rarity"]) == r:
				grid.add_child(_skin_cell(m, main, w, i, list[i]))
		m.add(grid)
	_fresh_skin = ""


static func _skin_cell(m: Modal, main: Node, w: String, i: int, sk: Dictionary) -> Control:
	var id: String = sk["id"]
	var r: int = sk["rarity"]
	var owned: bool = Progress.has_skin(id)
	var on: bool = Progress.skin_of(w) == id
	var price := Content.skin_price(id)
	# Legendary skins are a surprise until the pearls for them are there.
	var hidden := not owned and r >= 3 and Progress.pearls < price
	var rc: Color = WorkerLooks.RARITY_COLORS[r]
	var card := Views.card(Color("fff1c2") if on else (Color("3b3060") if hidden else Color("fffaf0")))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.line = rc.darkened(0.35) if not hidden else Art.INK
	sb.line_w = 5.0 if on else 4.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var look := WorkerLooks.code(GameState.evo, i)
	var fresh := _fresh_skin == id
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		if not hidden:
			Art.flat(ci, Art.circle_pts(c, minf(s.x, s.y) * 0.44, 28), Color(rc, 0.22))
		var pop := 1.0
		if fresh and tt < 0.6 and not Settings.reduce_motion:
			pop = 0.6 + 0.4 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.1
		Art.push(ci, c, 0.0, Vector2(pop, pop))
		WorkerLooks.draw_card(ci, Vector2.ZERO, minf(s.y, s.x * 1.05), w, look, not hidden, tt)
		Art.pop(ci)
		if hidden:
			Art.text(ci, c + Vector2(0, 12), "?", 44, Color(1, 1, 1, 0.9), 8)
			Art.lock(ci, Vector2(s.x - 18, 18), 13.0)
		elif on:
			var k := Vector2(s.x - 16, 16)
			Art.t_circle(ci, k, 12.0, Art.GREEN, 2.5, 0.0)
			Art.polyline(ci, PackedVector2Array([k + Vector2(-5, 0), k + Vector2(-1, 4), k + Vector2(6, -4)]), Art.WHITE, 3.0), Vector2(0, 116), true)
	pic.clip_contents = true
	v.add_child(pic)
	var name := Views.label("???" if hidden else t(WorkerLooks.skin_key(sk)), 16, Color("cfc6ef") if hidden else Art.INK, true)
	_two_lines(name, 16)
	v.add_child(name)
	var b: Button
	if on or owned:
		b = Button.new()
		b.text = t("WEARING") if on else t("WEAR")
		b.theme_type_variation = &"Button" if on else &"BlueButton"
		b.pressed.connect(func(): _wear(m, id))
	else:
		var pb := PriceButton.new()
		pb.set_price("", str(price), "pearl")
		pb.theme_type_variation = &"GoldButton" if Progress.pearls >= price else &"DarkButton"
		pb.pressed.connect(func(): _buy_skin(m, main, pb, id))
		b = pb
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = true
	v.add_child(b)
	return card


static func _wear(m: Modal, id: String) -> void:
	Progress.wear_skin(id)
	WorkerLooks.refresh_worn()
	Progress.save_game()
	Sfx.play("pop")
	m.rebuild()


static func _buy_skin(m: Modal, main: Node, b: Control, id: String) -> void:
	if not Progress.buy_skin(id):
		Sfx.play("deny")
		Wardrobe._shake(b)
		return
	WorkerLooks.refresh_worn()
	_fresh_skin = id
	Sfx.play("unlock")
	Sfx.voice("yay", 1.2)
	Settings.buzz(40)
	if main.has_method("_show_toast"):
		main._show_toast(t("SKIN_BOUGHT") % t(WorkerLooks.skin_key(Content.skin(id))))
	m.rebuild()


# --- Shared bits ---------------------------------------------------------------------

## A colored pill with white outlined text (rarity, level).
static func chip(text: String, col: Color) -> Control:
	var l := Views.label(text, 18, Art.WHITE, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Art.INK)
	var sb := ToonBox.make(col, 12, 0)
	sb.line_w = 3.0
	sb.gloss = 0.25
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


static func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


## Up to two centered lines (long names wrap, then shrink); always two
## lines tall so the cells in a row line up.
static func _two_lines(l: Label, fs: int) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.max_lines_visible = 2
	l.custom_minimum_size = Vector2(40, l.get_theme_font("font").get_height(fs) * 2.0 - 6.0)
	l.add_theme_constant_override("line_spacing", -3)
	l.resized.connect(func():
		if l.size.x <= 1.0:
			return
		var font := l.get_theme_font("font")
		var f := fs
		while f > 11:
			# Every word must fit the width, and the whole name two lines.
			var ok := true
			for word in l.text.split(" ", false):
				if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > l.size.x:
					ok = false
			if ok and font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, l.size.x, f, 3, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y <= font.get_height(f) * 2.0 + 1.0:
				break
			f -= 1
		if l.get_theme_font_size("font_size") != f:
			l.add_theme_font_size_override("font_size", f))


## One centered line that shrinks to the card (no wrapping, no overflow).
static func _one_line(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 40
	l.resized.connect(func():
		if l.size.x > 1.0:
			var fs := StageCard._fit_size(l, l.get_theme_font_size("font_size"), l.size.x)
			l.add_theme_font_size_override("font_size", maxi(fs, 12)))


static func _buy(m: Modal, main: Node, b: Control) -> void:
	var gs := GameState
	var from := b.get_global_rect().get_center()
	if not gs.buy_evo():
		Sfx.play("deny")
		Wardrobe._shake(b)
		return
	_fresh = gs.evo
	Sfx.play("unlock")
	Sfx.voice("yay", 1.2)
	Settings.buzz(40)
	if main.has_method("on_evo_bought"):
		main.on_evo_bought(from)
	m.rebuild()
