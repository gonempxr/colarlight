class_name Views
extends RefCounted
## Builders for the dialogs shown in the Modal: quests, daily gift, museum,
## feature intros, rewards, settings and players. Each takes the Modal and
## the main screen (for rewards flying into the top bar and navigation).

const QUEST_ICONS := {
	"upgrade": "arrow", "upgrade_stage": "arrow", "tap": "helmet", "earn": "coin",
	"hire": "people", "open": "plus", "puzzle": "puzzle", "chest": "chest",
}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func stage_name(key: String) -> String:
	match key:
		"lift":
			return t("STAGE_LIFT")
		"boat":
			return t("STAGE_BOAT")
		"plant":
			return t("STAGE_PLANT")
		"boat2":
			return t("STAGE_BOAT2")
		"plant2":
			return t("STAGE_PLANT2")
	var i := GameState.depth_index(key)
	if i >= 0:
		return WorldLook.site_name(i)
	return t("DEPTH_%s" % String(GameState.stage_data(key)["id"]).to_upper())


# --- Small widgets -------------------------------------------------------------------

static func icon(name: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Icons.get_icon(name, px)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text: String, px: int = 24, color: Color = Art.INK, heavy: bool = false) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", UiTheme.heavy_font())
	return l


static func card(color: Color = Color("fffaf0")) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiTheme.panel_box(color, 18, 4)
	sb.shadow = 0.0
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


## "[icon] +value" reward chip.
static func chip(icon_name: String, value: String, px: int = 26) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(icon(icon_name, px + 8))
	var l := label(value, px, Art.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return h


## A small outlined pill with one word or number (badges, "Playing").
static func pill(text: String, fill: Color, font_color: Color = Art.WHITE, px: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.pill_box(fill))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, px, font_color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_color == Art.WHITE:
		l.theme_type_variation = &""
		l.add_theme_constant_override("outline_size", 5)
	p.add_child(l)
	return p


## Pearls the player has, as a counter pill (wardrobe, shops).
static func pearl_counter(px: int = 28) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiTheme.pill_box(Color("efe6ff"), 20)
	sb.content_margin_left = 6
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(chip("pearl", str(Progress.pearls), px))
	return p


## One font size for a row of buttons: the biggest (up to `want`) at which
## every label fits its button, so tabs stay on one line in every language.
## Call it again when the row changes size (it hooks itself to `resized`).
static func fit_button_row(row: BoxContainer, want: int, least: int = 13) -> void:
	var fit := func() -> void:
		var buttons: Array[Button] = []
		for b in row.get_children():
			if b is Button and b.visible:
				buttons.append(b)
		if buttons.is_empty() or row.size.x < 2.0:
			return
		# Equal tabs: the children's own sizes are stale until the row
		# sorts them, so work from the row's width.
		var each := (row.size.x - row.get_theme_constant("separation") * (buttons.size() - 1)) / buttons.size()
		var font: Font = buttons[0].get_theme_font("font")
		var fs := want
		while fs > least:
			var ok := true
			for b in buttons:
				var sb: StyleBox = b.get_theme_stylebox("normal")
				var room: float = each - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 16.0) - 4.0
				if b.icon:
					room -= b.icon.get_width() + 6.0
				if font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
					ok = false
					break
			if ok:
				break
			fs -= 1
		for b in buttons:
			if b.get_theme_font_size("font_size") != fs:
				b.add_theme_font_size_override("font_size", fs)
	row.resized.connect(fit)


static func bar(value: float, max_value: float, text: String = "") -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 26)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = maxf(1.0, max_value)
	pb.value = minf(value, max_value)
	pb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pb)
	if text != "":
		var l := Label.new()
		l.text = text
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UiTheme.heavy_font())
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_constant_override("outline_size", 5)
		holder.add_child(l)
	return holder


# --- Quests --------------------------------------------------------------------------

static func quest_text(q: Dictionary) -> String:
	var goal := int(q["goal"])
	match str(q["kind"]):
		"upgrade":
			return t("QUEST_UPGRADE") % goal
		"upgrade_stage":
			return t("QUEST_UPGRADE_STAGE") % [stage_name(q["key"]), goal]
		"tap":
			return t("QUEST_TAP") % goal
		"earn":
			return t("QUEST_EARN") % NumFormat.short(q["goal"])
		"hire":
			return t("QUEST_HIRE")
		"open":
			return t("QUEST_OPEN")
		"puzzle":
			return t("QUEST_PUZZLE")
		"chest":
			return t("QUEST_CHEST") if goal <= 1 else t("QUEST_CHESTS") % goal
		"mine":
			return t("QUEST_MINE") % [stage_name(q["key"]), goal]
	return ""


static func quests(m: Modal, main: Node) -> void:
	m.title(t("QUESTS"))
	# Quests belong to the world being played (they swap with it).
	m.text(t("QUESTS_WORLD") % WorldLook.name_of(GameState.location), 23, Art.INK)
	m.text(t("QUESTS_HINT"), 21, Art.INK_SOFT)
	if Progress.quests.is_empty():
		m.text(t("QUESTS_EMPTY"), 22)
	for i in Progress.quests.size():
		var q: Dictionary = Progress.quests[i]
		var done := Progress.quest_complete(i)
		var c := card(Color("eaffea") if done else Color("fffaf0"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		c.add_child(h)
		if q["kind"] == "mine":
			# This world's own ore from that site.
			var depth := GameState.depth_index(str(q["key"]))
			var ore := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
				OreArt.chunk(ci, s / 2.0 + Vector2(0, 2), 20.0, depth, -0.2), Vector2(56, 56))
			ore.custom_minimum_size = Vector2(56, 56)
			h.add_child(ore)
		else:
			h.add_child(icon(QUEST_ICONS.get(q["kind"], "quests"), 56))
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_theme_constant_override("separation", 6)
		h.add_child(mid)
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		mid.add_child(label(quest_text(q), 22, Art.INK, true))
		var shown := NumFormat.short(q["count"]) + " / " + NumFormat.short(q["goal"])
		mid.add_child(bar(q["count"], q["goal"], shown))
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(right)
		if done:
			# The reward rides on the button: "Claim (pearl) +2".
			var b := PriceButton.new()
			b.custom_minimum_size = Vector2(196, 64)
			b.add_theme_font_size_override("font_size", 22)
			b.set_price(t("CLAIM"), "+%d" % int(q["pearls"]), "pearl")
			var idx := i
			b.pressed.connect(func():
				var from := b.get_global_rect().get_center()
				var r := Progress.claim_quest(idx)
				if not r.is_empty():
					main.celebrate(r, from)
					m.rebuild())
			right.add_child(b)
		else:
			var reward := PanelContainer.new()
			var rsb := UiTheme.pill_box(Color("efe6ff"), 18)
			rsb.content_margin_left = 4
			rsb.content_margin_right = 12
			reward.add_theme_stylebox_override("panel", rsb)
			reward.add_child(chip("pearl", "+%d" % int(q["pearls"]), 22))
			right.add_child(reward)
		m.add(c)


# --- Daily gift ------------------------------------------------------------------------

static func daily_icon(kind: String) -> String:
	return {"coins": "coin", "pearls": "pearl", "boost": "bolt"}.get(kind, "gift")


static func daily_amount(gift: Dictionary, week: int) -> String:
	match str(gift["kind"]):
		"coins":
			return NumFormat.short(Progress.coins_for_minutes(gift["amount"]))
		"pearls":
			return "+%d" % (int(gift["amount"]) + week * 5)
		"boost":
			return "×2 %s" % (t("MINUTES") % int(gift["amount"]))
	return ""


static func daily(m: Modal, main: Node) -> void:
	m.title(t("DAILY"))
	m.add(StreakView.today_card(main, m))
	m.text(t("DAILY_HINT"), 21, Art.INK_SOFT)
	var n := Content.DAILY.size()
	var week := Progress.daily_day / n
	var today_i := Progress.daily_day % n
	var ready := Progress.daily_ready()
	# Days 1-4 on top, 5-6 and a double-wide day 7 (the big one) below.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	var row: HBoxContainer
	for i in n:
		if i == 0 or i == 4:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			rows.add_child(row)
		var gift: Dictionary = Content.DAILY[i]
		var claimed := i < today_i
		var is_today := i == today_i and ready
		var last := i == n - 1
		var c := card(Color("fff1c2") if is_today else (Color("e6e9f2") if claimed else (Color("fff6dc") if last else Color("fffaf0"))))
		if is_today:
			(c.get_theme_stylebox("panel") as ToonBox).line = Color("d98a00")
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_stretch_ratio = 2.0 if last and n == 7 else 1.0
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		c.add_child(v)
		var day := label(t("DAY") % (i + 1), 18, Art.INK_SOFT, true)
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(day)
		v.add_child(icon("check" if claimed else daily_icon(gift["kind"]), 48 if not last else 60))
		var amt := label(daily_amount(gift, week), 17, Art.INK, true)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(amt)
		row.add_child(c)
	m.add(rows)
	if ready:
		var b := m.button(t("CLAIM"), func(): pass, &"GoldButton")
		b.pressed.connect(func():
			var from := b.get_global_rect().get_center()
			var g := Progress.claim_daily()
			if g.is_empty():
				return
			var r := {}
			match str(g["kind"]):
				"coins":
					r["coins"] = g["value"]
				"pearls":
					r["pearls"] = g["value"]
				"boost":
					r["boost"] = g["value"]
			main.celebrate(r, from)
			m.close())
	else:
		m.text(t("DAILY_TOMORROW"), 22, Color("1c7fb8"))


# --- Feature intro and rewards -------------------------------------------------------------

const FEATURE_ICONS := {"daily": "gift", "chests": "chest", "quests": "quests", "shop": "wardrobe", "puzzle": "puzzle", "museum": "museum", "fishing": "fishing"}


static func feature_intro(m: Modal, id: String, on_open: Callable) -> void:
	var burst := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		for i in 12:
			var a := tt * 0.6 + TAU * i / 12.0
			var ray := Color(1.0, 0.85, 0.3, 0.35)
			Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a - 0.12), sin(a - 0.12)) * 150.0, c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 150.0]),
					PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)])), Vector2(0, 170), true)
	var ic := icon(FEATURE_ICONS.get(id, "star"), 128)
	# A full-size CenterContainer keeps the icon centred once the view gets its width.
	var mid := CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.add_child(ic)
	burst.add_child(mid)
	var tw := ic.create_tween().set_loops()
	ic.pivot_offset = Vector2(64, 64)
	tw.tween_property(ic, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	m.text(t("NEW_FEATURE"), 26, Color("d8363c"))
	m.title(t("FEATURE_" + id.to_upper()))
	m.add(burst)
	m.text(t("FEATURE_%s_DESC" % id.to_upper()), 23)
	if on_open.is_valid():
		m.button(t("OPEN_IT"), func(): Sfx.play("click"); m.close(); on_open.call(), &"GoldButton")
	else:
		m.button(t("YAY"), func(): Sfx.play("click"); m.close(), &"GoldButton")


# --- Museum ----------------------------------------------------------------------------------

static func bonus_text(a: Dictionary, level: int) -> String:
	var pct := roundi(a["per_level"] * maxi(1, level) * 100.0)
	return t("BONUS_" + str(a["bonus"]).to_upper()) % pct


static func museum(m: Modal, main: Node) -> void:
	m.title(t("MUSEUM"))
	m.text(t("MUSEUM_HINT"), 21, Art.INK_SOFT)
	if Progress.has_feature("puzzle"):
		var target := Progress.target_artifact()
		if target != "":
			m.button(t("PLAY_FOR") % t("ART_" + target.to_upper()), func(): m.close(); main.open_puzzle(), &"PurpleButton")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for a in Content.ARTIFACTS:
		var id: String = a["id"]
		var st: Dictionary = Progress.artifacts[id]
		var lv: int = st["level"]
		var c := card(Color("fff6dc") if lv > 0 else Color("e9ecf4"))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		c.add_child(v)
		var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			var k := minf(s.x, s.y) / 180.0
			Art.push(ci, s / 2.0, 0.0, Vector2(k, k))
			ArtifactArt.background(ci, 170.0)
			if lv > 0:
				Art.push(ci, Vector2(0, sin(tt * 1.5) * 3.0))
				ArtifactArt.draw(ci, id, tt)
				Art.pop(ci)
			else:
				Art.flat(ci, Art.rrect_pts(Rect2(-85, -85, 170, 170), 20), Color(0.12, 0.1, 0.25, 0.55))
				if st["pieces"] > 0:
					ArtifactArt.fragment(ci, id, tt)
				else:
					Art.text(ci, Vector2(0, 30), "?", 90, Art.WHITE, 10)
			Art.pop(ci), Vector2(0, 150), lv > 0)
		v.add_child(pic)
		var name := label(t("ART_" + id.to_upper()) if lv > 0 else "???", 18, Art.INK, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		var stars := HBoxContainer.new()
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		stars.add_theme_constant_override("separation", -4)
		for i in Content.ARTIFACT_MAX:
			stars.add_child(icon("star" if i < lv else "star_off", 22))
		v.add_child(stars)
		if lv < Content.ARTIFACT_MAX:
			v.add_child(bar(st["pieces"], Progress.pieces_needed(id), "%d/%d" % [st["pieces"], Progress.pieces_needed(id)]))
		var bt := label(bonus_text(a, lv), 16, Color("1f8a4c") if lv > 0 else Art.INK_SOFT)
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bt)
		grid.add_child(c)
	m.add(grid)


# --- Rewards ---------------------------------------------------------------------------------

## Lines for a reward dictionary: coins, pearls, boost (minutes), piece (artifact id).
static func reward_chips(r: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	if float(r.get("coins", 0.0)) > 0.0:
		h.add_child(chip("coin", "+" + NumFormat.short(r["coins"]), 30))
	if int(r.get("pearls", 0)) > 0:
		h.add_child(chip("pearl", "+%d" % int(r["pearls"]), 30))
	if int(r.get("boost", 0)) > 0:
		h.add_child(chip("bolt", "×2 " + t("MINUTES") % int(r["boost"]), 30))
	return h
