class_name EvoPanel
extends RefCounted
## The workers' evolution (a wide dialog): the look the workers wear now,
## the next form big with its price and a Buy button, and all 13 forms of
## this world in a grid: owned ones in color with a check, the next three
## in color with their price, the rest as dark silhouettes with "?" and a
## lock. Each form gives +10% income in this world; forms are not needed
## to open the next world (the panel says so).

const SHOWN_AHEAD := 3

## The form just bought pops in the grid (and the big card) once.
static var _fresh := -1


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func build(m: Modal, main: Node) -> void:
	var gs := GameState
	var w: String = gs.world_id()
	var e: int = gs.evo
	m.title(t("EVO_BOARD"))
	var sub := m.text(t("EVO_SUB") % WorldLook.name_of(gs.location), 22, Color("7a4fc4"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The next form, big, with its price (or the last one, all done).
	var next := mini(e + 1, Balance.EVO_FORMS)
	var done := e >= Balance.EVO_FORMS
	var shown := e if done else next
	var hero := Views.card(Color("f3e9ff"))
	var hsb: ToonBox = hero.get_theme_stylebox("panel")
	hsb.line = WorkerLooks.rarity_color(shown).darkened(0.3)
	hsb.line_w = 5.0
	var hv := HBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero.add_child(hv)
	var fresh := _fresh
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		var pop := 1.0
		if fresh == shown and tt < 0.6 and not Settings.reduce_motion:
			pop = 0.7 + 0.3 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.08
		Art.glow(ci, c, s.y * 0.55, Color(WorkerLooks.rarity_color(shown), 0.45))
		if not Settings.reduce_motion:
			for i in 8:
				var a := tt * 0.5 + i * TAU / 8.0
				Art.toon(ci, Art.star_pts(c + Vector2(cos(a), sin(a)) * s.y * 0.44, 5.0, 2.2, 4, a), Color(1, 0.95, 0.6, 0.8), 0.0, 0.0)
		Art.push(ci, c, 0.0, Vector2(pop, pop))
		WorkerLooks.draw_card(ci, Vector2.ZERO, s.y * 0.95, w, shown, true, tt)
		Art.pop(ci), Vector2(190, 200), true)
	hv.add_child(pic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	hv.add_child(info)
	info.add_child(_rarity_chip(shown))
	var name := Views.label(t(WorkerLooks.name_key(w, shown)), 30, Art.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = 160
	info.add_child(name)
	var perk := Views.label(t("EVO_PERK"), 21, Art.GREEN_DARK, true)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.custom_minimum_size.x = 160
	info.add_child(perk)
	if done:
		info.add_child(Views.label(t("EVO_ALL"), 24, Color("7a4fc4"), true))
	else:
		var cost: float = gs.evo_cost(next)
		var buy := PriceButton.new()
		buy.custom_minimum_size = Vector2(0, 80)
		buy.add_theme_font_size_override("font_size", 28)
		buy.set_price(t("EVO_BUY"), NumFormat.short(cost), "coin")
		buy.theme_type_variation = &"GoldButton" if gs.coins >= cost else &"DarkButton"
		buy.pressed.connect(func(): _buy(m, main, buy))
		info.add_child(buy)
		if gs.coins < cost:
			var need := Views.label(t("EVO_NEED") % NumFormat.short(cost - gs.coins), 18, Art.INK_SOFT)
			need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			need.custom_minimum_size.x = 160
			info.add_child(need)
	m.add(hero)
	# Bonus so far and "not needed for the next world".
	var bonus := roundi((Balance.evo_mult(e) - 1.0) * 100.0)
	var note := Views.card(Color("eaf6ff"))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 4)
	note.add_child(nv)
	var have := Views.label(t("EVO_HAVE") % [e, Balance.EVO_FORMS, bonus], 22, Art.INK, true)
	have.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	have.custom_minimum_size.x = 200
	nv.add_child(have)
	var opt := Views.label(t("EVO_OPTIONAL"), 18, Art.INK_SOFT)
	opt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opt.custom_minimum_size.x = 200
	nv.add_child(opt)
	m.add(note)
	# Every form of this world.
	var grid := GridContainer.new()
	var v := m.get_viewport_rect().size
	grid.columns = 4 if v.x >= 600.0 else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for f in WorkerLooks.FORMS:
		grid.add_child(_cell(w, f, e, fresh))
	m.add(grid)
	_fresh = -1


static func _rarity_chip(form: int) -> Control:
	var r := WorkerLooks.rarity(form)
	var l := Views.label(t(WorkerLooks.RARITY_KEYS[r]), 18, Art.WHITE, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Art.INK)
	var sb := ToonBox.make(WorkerLooks.rarity_color(form), 12, 0)
	sb.line_w = 3.0
	sb.gloss = 0.25
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


## owned (color + check), next three (color + price), or hidden (silhouette,
## "?" and a lock).
static func _cell(w: String, f: int, e: int, fresh: int) -> Control:
	var owned := f <= e
	var ahead := f > e and f <= e + SHOWN_AHEAD
	var rc := WorkerLooks.rarity_color(f)
	var card := Views.card(Color("fffaf0") if owned or ahead else Color("3b3060"))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.line = rc.darkened(0.35) if owned or ahead else Art.INK
	sb.line_w = 5.0 if f == e else 4.0
	if f == e:
		sb.fill = Color("fff1c2")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		if owned or ahead:
			Art.flat(ci, Art.circle_pts(c, s.y * 0.42, 28), Color(rc, 0.22))
		var pop := 1.0
		if fresh == f and tt < 0.6 and not Settings.reduce_motion:
			pop = 0.6 + 0.4 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.1
		Art.push(ci, c, 0.0, Vector2(pop, pop))
		WorkerLooks.draw_card(ci, Vector2.ZERO, s.y, w, f, owned or ahead, tt)
		Art.pop(ci)
		if not owned and not ahead:
			Art.text(ci, c + Vector2(0, 12), "?", 44, Color(1, 1, 1, 0.9), 8)
			Art.lock(ci, Vector2(s.x - 18, 18), 13.0)
		elif owned:
			var k := Vector2(s.x - 16, 16)
			Art.t_circle(ci, k, 12.0, Art.GREEN, 2.5, 0.0)
			Art.polyline(ci, PackedVector2Array([k + Vector2(-5, 0), k + Vector2(-1, 4), k + Vector2(6, -4)]), Art.WHITE, 3.0), Vector2(0, 112), true)
	v.add_child(pic)
	var name_text := t(WorkerLooks.name_key(w, f)) if owned or ahead else "???"
	var name := Views.label(name_text, 16, Art.INK if owned or ahead else Color("cfc6ef"), true)
	_two_lines(name, 16)
	v.add_child(name)
	var line: Label
	if f == e:
		line = Views.label(t("EVO_NOW"), 16, Color("b8860b"), true)
	elif owned:
		line = Views.label(t(WorkerLooks.RARITY_KEYS[WorkerLooks.rarity(f)]), 15, rc.darkened(0.35), true)
	elif ahead:
		var cost: float = GameState.evo_cost(f)
		line = Views.label(NumFormat.short(cost), 18, Art.GOLD_DARK if GameState.coins >= cost and f == e + 1 else Art.INK_SOFT, true)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 4)
		h.add_child(Views.icon("coin", 20))
		h.add_child(line)
		v.add_child(h)
		return card
	else:
		line = Views.label(t("EVO_LATER"), 15, Color("cfc6ef"), true)
	_one_line(line)
	v.add_child(line)
	return card


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
			for w in l.text.split(" ", false):
				if font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > l.size.x:
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
