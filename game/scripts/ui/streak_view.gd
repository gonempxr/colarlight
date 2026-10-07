class_name StreakView
extends RefCounted
## The streak screen (big flame, current and best, the week, ice cubes and
## the milestone rewards shown in advance) and the small "today" strip the
## daily gift screen shows on top, so the gift and the flame feel like one
## thing. Kind wording only: no timers, no "you will lose it".

const WEEK_DAYS := 7


static func t(key: String) -> String:
	return TranslationServer.translate(key)


## "5 days in a row" with the right plural form (Russian has three).
static func days_text(n: int) -> String:
	return t(_plural_key("STREAK_DAYS", n)) % n


static func days_short(n: int) -> String:
	return t(_plural_key("STREAK_DAY_N", n)) % n


static func _plural_key(base: String, n: int) -> String:
	if TranslationServer.get_locale().begins_with("ru"):
		var m10 := n % 10
		var m100 := n % 100
		if m10 == 1 and m100 != 11:
			return base + "_ONE"
		if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
			return base + "_FEW"
		return base + "_MANY"
	return base + ("_ONE" if n == 1 else "_MANY")


static func weekday(date: String) -> String:
	var d := Time.get_datetime_dict_from_unix_time(Progress.day_number(date) * 86400 + 43200)
	return t("WEEKDAY_%d" % int(d.get("weekday", 0)))


## The big flame with soft rays (lit) and the count on its belly.
static func _big_flame(px: float) -> ArtView:
	var lit: bool = Progress.streak_today()
	return ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var base := Vector2(s.x / 2.0, s.y - 14.0)
		if lit:
			var c := base + Vector2(0, -px * 0.9)
			for i in 10:
				var a := floorf(tt * 6.0) / 6.0 * 0.35 + TAU * i / 10.0
				var ray := Color(1.0, 0.78, 0.3, 0.3)
				Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a - 0.13), sin(a - 0.13)) * px * 2.2, c + Vector2(cos(a + 0.13), sin(a + 0.13)) * px * 2.2]),
						PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
		Art.flat(ci, Art.ellipse_pts(base + Vector2(0, 2), Vector2(px * 0.95, px * 0.18), 20), Color(0.14, 0.1, 0.3, 0.18))
		var bob := 1.0 + 0.03 * sin(floorf(tt * 8.0) / 8.0 * 2.4)
		Art.push(ci, base, 0.0, Vector2(1.0 / bob, bob))
		StreakArt.flame(ci, Vector2.ZERO, px, StreakArt.phase(tt, 7.0 if lit else 2.0), lit, true)
		Art.pop(ci), Vector2(0, px * 2.6 + 24.0), true)


## One day of the week strip: the weekday and a flame, an ice cube, a calm
## sleepy flame for today (not played yet) or a soft empty dot.
static func _day_cell(day: Dictionary, px: float) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_today: bool = day["state"] == "today" or day["date"] == Progress.today()
	var name := Views.label(weekday(day["date"]), int(px * 0.5), Art.INK if is_today else Art.INK_SOFT, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(name)
	var st: String = day["state"]
	var paint := func(ci: CanvasItem, s: Vector2, _tt: float) -> void:
		var c := Vector2(s.x / 2.0, s.y / 2.0)
		if is_today:
			Art.flat(ci, Art.circle_pts(c, px * 0.62, 24), Color(1.0, 0.85, 0.4, 0.35))
		if st == "play":
			StreakArt.flame(ci, c + Vector2(0, px * 0.48), px * 0.3, 1, true, false)
		elif st == "ice":
			StreakArt.ice(ci, c, px * 0.62)
		elif st == "today":
			StreakArt.flame(ci, c + Vector2(0, px * 0.48), px * 0.3, 1, false, false)
		else:
			Art.flat(ci, Art.circle_pts(c, px * 0.13, 12), Color(0.42, 0.35, 0.55, 0.35))
	v.add_child(ArtView.make(paint, Vector2(px, px)))
	return v


static func week_strip(px: float = 44.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	for day in Progress.streak_week("", WEEK_DAYS):
		h.add_child(_day_cell(day, px))
	return h


## Ice cubes held (and empty slots up to the most you can hold).
static func ice_row(px: float = 34.0) -> Control:
	var have: int = Progress.streak_freezes
	return ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		for i in Content.STREAK_FREEZE_MAX:
			StreakArt.ice(ci, Vector2(px * 0.6 + i * px * 1.15, s.y / 2.0), px * 0.85, i >= have, -0.12 + i * 0.2),
		Vector2(px * 1.15 * Content.STREAK_FREEZE_MAX + 4.0, px))


## Reward chips of a milestone: pearls, a chest of coins, an item.
static func reward_chips(m: Dictionary, px: int = 20) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if int(m.get("pearls", 0)) > 0:
		h.add_child(Views.chip("pearl", "+%d" % int(m["pearls"]), px))
	if float(m.get("coins_min", 0.0)) > 0.0:
		h.add_child(Views.chip("chest", NumFormat.short(Progress.coins_for_minutes(float(m["coins_min"]))), px))
	var item := str(m.get("item", ""))
	if item != "":
		var name := Views.label(t("ITEM_" + item.to_upper()), px, Color("b0306a"), true)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_item_icon(item, px + 14))
		row.add_child(name)
		h.add_child(row)
	return h


static func _item_icon(id: String, px: int) -> Control:
	var c := Content.cosmetic(id)
	return ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		var mid := s / 2.0
		if str(c.get("slot", "")) == "hat":
			Art.push(ci, mid + Vector2(0, s.y * 0.32), 0.0, Vector2.ONE * (s.y / 52.0))
			StreakArt.hat(ci)
			Art.pop(ci)
		else:
			var p: Array = Content.BOAT_PAINTS.get(str(c.get("art", "")), [])
			var hull: Color = p[0] if p.size() > 0 else Art.CORAL
			var stripe: Color = p[1] if p.size() > 1 else Art.GOLD
			Art.push(ci, mid)
			var body := PackedVector2Array([Vector2(-s.x * 0.45, -2), Vector2(s.x * 0.45, -2), Vector2(s.x * 0.3, s.y * 0.3), Vector2(-s.x * 0.32, s.y * 0.3)])
			Art.toon(ci, body, hull, 2.0, 0.4)
			Art.flat(ci, PackedVector2Array([Vector2(-s.x * 0.42, 1), Vector2(s.x * 0.42, 1), Vector2(s.x * 0.4, 4), Vector2(-s.x * 0.4, 4)]), stripe)
			Art.t_rect(ci, Rect2(-s.x * 0.15, -s.y * 0.3, s.x * 0.3, s.y * 0.28), 3, p[2] if p.size() > 2 else Art.WHITE, 2.0, 0.3)
			Art.pop(ci), Vector2(px, px))


# --- The streak screen ---------------------------------------------------------------

static func build(m: Modal, main: Node) -> void:
	_give_waiting(main)
	var n: int = Progress.streak_shown()
	var lit: bool = Progress.streak_today()
	m.title(t("STREAK"))
	if Progress.streak_will_restart():
		m.text(t("STREAK_WELCOME"), 22, Color("1c7fb8"))
	m.add(_big_flame(64.0))
	var big := m.text(days_text(n), 34, Color("e0641c"))
	big.add_theme_font_override("font", UiTheme.heavy_font())
	big.add_theme_constant_override("line_spacing", -6)
	m.text(t("STREAK_LIT_TODAY") if lit else t("STREAK_HOW"), 20, Art.INK_SOFT)
	var c := Views.card(Color("fff6e0"))
	c.add_child(week_strip(46.0))
	m.add(c)
	# Best record and ice cubes side by side.
	var row := m.row(10)
	var best := Views.card(Color("f3ecff"))
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	best.add_child(bv)
	var bl := Views.label(t("STREAK_BEST"), 18, Art.INK_SOFT, true)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bl)
	var bn := Views.chip("star", days_short(Progress.streak_best), 24)
	bv.add_child(bn)
	row.add_child(best)
	var ice := Views.card(Color("e6f7ff"))
	ice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var iv := VBoxContainer.new()
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	ice.add_child(iv)
	var il := Views.label(t("STREAK_ICE"), 18, Art.INK_SOFT, true)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(il)
	var ir := CenterContainer.new()
	ir.add_child(ice_row(34.0))
	iv.add_child(ir)
	row.add_child(ice)
	m.text(t("STREAK_ICE_HINT") % [Content.STREAK_FREEZE_EVERY, Content.STREAK_FREEZE_MAX], 18, Art.INK_SOFT)
	# Milestones: what each one gives, shown before it is reached.
	var head := m.text(t("STREAK_REWARDS"), 26)
	head.add_theme_font_override("font", UiTheme.heavy_font())
	var next: Dictionary = Progress.streak_next_milestone()
	for ms in Content.STREAK_MILESTONES:
		m.add(_milestone_row(ms, n, ms == next))
	if Progress.daily_ready():
		var b := m.button(t("STREAK_TO_GIFT"), func(): pass, &"GoldButton")
		b.pressed.connect(func():
			m.close()
			(func(): main.open_feature("daily")).call_deferred())


static func _milestone_row(ms: Dictionary, n: int, is_next: bool) -> Control:
	var days := int(ms["days"])
	var got: bool = Progress.streak_claimed.has(str(days))
	var c := Views.card(Color("eaffea") if got else (Color("fff1c2") if is_next else Color("fffaf0")))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	var badge := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		StreakArt.flame(ci, Vector2(s.x / 2.0, s.y - 4.0), 14.0, 3, got or is_next, true)
		Art.text(ci, Vector2(s.x / 2.0, s.y - 9.0), str(days), 17 if days < 100 else 14, Art.WHITE, 5), Vector2(48, 52))
	h.add_child(badge)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	h.add_child(mid)
	mid.add_child(Views.label(days_text(days), 20, Art.INK, true))
	mid.add_child(reward_chips(ms, 18))
	if is_next and not got:
		mid.add_child(Views.bar(n, days, "%d / %d" % [mini(n, days), days]))
	if got:
		var right := CenterContainer.new()
		right.add_child(Views.icon("check", 40))
		h.add_child(right)
	return c


static func _give_waiting(main: Node) -> void:
	var r: Dictionary = Progress.take_streak_reward()
	if not r.is_empty() and main.has_method("celebrate"):
		main.celebrate(r, main.get_viewport_rect().size / 2.0, false)


# --- The strip on the daily gift screen ------------------------------------------------

## Flame, "N days in a row" and the week, as one tappable card.
static func today_card(main: Node, m: Modal) -> Control:
	var n: int = Progress.streak_shown()
	var lit: bool = Progress.streak_today()
	var c := Views.card(Color("fff6e0"))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Sfx.play("click")
			m.close()
			(func(): main.open_streak()).call_deferred())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		StreakArt.flame(ci, Vector2(s.x / 2.0, s.y - 3.0), 17.0, StreakArt.phase(tt, 7.0 if lit else 2.0), lit, true), Vector2(46, 50), true))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	tv.add_child(Views.label(days_text(n), 22, Color("e0641c"), true))
	var sub := t("STREAK_LIT_TODAY") if lit else (t("STREAK_WELCOME_SHORT") if Progress.streak_will_restart() else t("STREAK_HOW_SHORT"))
	tv.add_child(Views.label(sub, 16, Art.INK_SOFT))
	var more := Views.icon("right", 26)
	top.add_child(more)
	v.add_child(week_strip(38.0))
	for ctl in v.find_children("*", "Control", true, false):
		(ctl as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
