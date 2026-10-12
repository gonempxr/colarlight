class_name PassView
extends RefCounted
## The sea pass dialog (BattlePass): level and XP, "take all", how XP is
## earned, and the 30 levels with their rewards.


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func open(main: Node) -> void:
	GuideView.mark("pass")
	BattlePass.tick()
	main._modal.open(func(m): build(m, main))


static func build(m: Modal, main: Node) -> void:
	m.title(t("BP_TITLE"))
	m.text(t("BP_CHAPTER") % BattlePass.chapter(), 22, Color("1c7fb8"))
	m.text(t("BP_FREE"), 18, Art.GREEN_DARK)
	# Level and XP.
	var head := Views.card(Color("e6f4ff"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	head.add_child(h)
	var lv := BattlePass.level()
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): draw_badge(ci, s / 2.0, 34.0, lv), Vector2(84, 84)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	v.add_child(Views.label(t("BP_LEVEL") % [lv, BattlePass.LEVELS], 22, Art.INK, true))
	if lv < BattlePass.LEVELS:
		var into := BattlePass.xp() - lv * BattlePass.XP_LEVEL
		v.add_child(Views.bar(float(into), float(BattlePass.XP_LEVEL), "%d / %d XP" % [into, BattlePass.XP_LEVEL]))
	else:
		v.add_child(Views.label(t("BP_DONE"), 18, Art.GREEN_DARK, true))
	m.add(head)
	var wait := BattlePass.waiting()
	if wait > 0:
		var take := [null]
		take[0] = m.button(t("BP_TAKE") % wait, func():
			var b: Button = take[0]
			var from: Vector2 = b.get_global_rect().get_center()
			var got := BattlePass.claim_all()
			Sfx.play("unlock")
			if not got.is_empty():
				main.celebrate({"coins": float(got["coins"]), "pearls": int(got["pearls"]), "boost": int(got["boost"]) / 60}, from)
			m.rebuild(), &"GoldButton")
		take[0].icon = Icons.get_icon("gift", 34)
	# How to earn XP.
	var how := Views.card(Color("fffaf0"))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	how.add_child(hv)
	hv.add_child(Views.label(t("BP_HOW"), 20, Art.INK, true))
	for k in ["challenge", "daily", "quest", "badge", "chest", "star", "fish", "minute"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Views.icon({"challenge": "star", "daily": "gift", "quest": "quests", "badge": "star", "chest": "chest",
			"star": "puzzle", "fish": "fishing", "minute": "bolt"}[k], 28))
		var l := Views.label(t("BP_XP_" + k.to_upper()), 17, Art.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
		row.add_child(l)
		var xl := Views.label("+%d XP" % int(BattlePass.XP[k]), 17, Color("1c7fb8"), true)
		xl.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(xl)
		hv.add_child(row)
	m.add(how)
	# The levels.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	for i in BattlePass.LEVELS:
		list.add_child(_level_row(i + 1, lv))
	m.add(list)


static func _level_row(n: int, lv: int) -> Control:
	var got := n <= BattlePass.taken()
	var ready := n <= lv and not got
	var r := BattlePass.reward(n)
	var big := r.has("item")
	var c := Views.card(Color("ffe9a0") if ready else (Color("eaffea") if got else (Color("f3ecff") if big else Color("fffaf0"))))
	var sb: ToonBox = c.get_theme_stylebox("panel")
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): draw_badge(ci, s / 2.0, 20.0, n, n > lv), Vector2(50, 50)))
	if r.has("item"):
		var id := str(r["item"])
		var item := Content.cosmetic(id)
		if item.get("slot") == "hat":
			var look := Settings.avatar.duplicate()
			look["hat"] = str(item["art"])
			h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
				Chars.portrait(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, look, "happy", false, Color("e3d6ff")), Vector2(56, 56)))
		else:
			h.add_child(Views.icon("wardrobe", 44))
		var name := Views.label(t("ITEM_" + id.to_upper()), 19, Color("6a3fc0"), true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.custom_minimum_size.x = 80
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(name)
		if int(r.get("pearls", 0)) > 0:
			h.add_child(Views.chip("pearl", "+%d" % int(r["pearls"]), 18))
	else:
		var icon := "pearl"
		var text := ""
		if r.has("pearls"):
			text = "+%d" % int(r["pearls"])
		elif r.has("coins_min"):
			icon = "coin"
			text = "+" + NumFormat.short(Progress.coins_for_minutes(float(r["coins_min"])))
		else:
			icon = "bolt"
			text = "×2 · " + t("MINUTES") % (int(r["boost"]) / 60)
		var chip := Views.chip(icon, text, 20)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.alignment = BoxContainer.ALIGNMENT_BEGIN
		h.add_child(chip)
	if got:
		h.add_child(Views.icon("check", 30))
	elif ready:
		h.add_child(Views.pill(t("BP_READY"), Art.RED, Art.WHITE, 15))
	else:
		h.add_child(Views.icon("lock", 28))
	return c


## A round level badge: a blue ring with the number (grey when not reached).
static func draw_badge(ci: CanvasItem, c: Vector2, r: float, n: int, locked: bool = false) -> void:
	Art.t_circle(ci, c, r, Color("2a7fd4") if not locked else Color("a7b0c4"), maxf(2.0, r * 0.1), 0.5)
	Art.t_circle(ci, c, r * 0.76, Color("7fd0ff") if not locked else Color("d3d8e3"), 0.0, 0.0)
	Art.text(ci, c + Vector2(0, r * 0.34), str(n), int(r * 0.95), Art.WHITE, maxi(3, int(r * 0.2)))


## The side button's picture: a ticket with a star and an anchor line.
static func draw_icon(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.push(ci, c, -0.18, Vector2.ONE * (r / 20.0))
	var ticket := Art.rrect_pts(Rect2(-20, -13, 40, 26), 5.0)
	Art.toon(ci, ticket, Color("ffd23f"), 3.0, 0.5)
	Art.flat(ci, Art.circle_pts(Vector2(-20, 0), 5.0, 12), Color("e9f3ff"))
	Art.flat(ci, Art.circle_pts(Vector2(20, 0), 5.0, 12), Color("e9f3ff"))
	Art.toon(ci, Art.star_pts(Vector2(-3, 0), 9.0, 4.2, 5), Color("ff7f8f"), 2.0, 0.0)
	for i in 3:
		Art.line(ci, Vector2(9, -7 + i * 7), Vector2(14, -7 + i * 7), Art.GOLD_DARK, 2.0)
	Art.pop(ci)
