class_name SocialView
extends RefCounted
## Dialogs of the social pack: achievements (badges), a player's profile
## card (tap a name on the board), clubs, the challenge of the day (on top
## of the quests) and the title pill. Data: Achievements, DailyChallenge,
## Online (titles, seasons, clubs).

static var _club := {}
static var _clubs_board := {}
static var _club_msg := ""


static func t(key: String) -> String:
	return TranslationServer.translate(key)


# --- Small pieces ------------------------------------------------------------------------

## Calls `cb` on a tap (not on a drag of the list under it).
static func on_tap(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var down := [Vector2.INF]
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				down[0] = e.global_position
			elif down[0] != Vector2.INF and e.global_position.distance_to(down[0]) < 14.0:
				down[0] = Vector2.INF
				Sfx.play("click")
				cb.call())


## A medal: tier colour (bronze / silver / gold), the icon, grey when locked.
static func badge(icon: String, tier: int, got: bool, px: int = 64) -> Control:
	var col: Color = Achievements.TIER_COLORS[clampi(tier, 0, 2)] if got else Color("c9c4d6")
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		var c := s / 2.0 + Vector2(0, -2)
		var r := minf(s.x, s.y) * 0.36
		var tail := Color("e0483e") if got else Color("a7a2b5")
		for side in [-1.0, 1.0]:
			Art.toon(ci, PackedVector2Array([c + Vector2(side * r * 0.2, r * 0.3), c + Vector2(side * r * 0.85, r * 0.55),
				c + Vector2(side * r * 0.75, r * 1.25), c + Vector2(side * r * 0.5, r * 1.05), c + Vector2(side * r * 0.3, r * 1.3)]), tail, 2.0, 0.4)
		Art.t_circle(ci, c, r, col, 2.5, 0.8)
		Art.t_circle(ci, c, r * 0.74, col.lightened(0.25), 1.6, 0.0), Vector2(px, px))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(art)
	var ic := Views.icon(icon if got else "lock", int(px * 0.42))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.position.y = -2
	if not got:
		ic.modulate = Color(1, 1, 1, 0.75)
	box.add_child(ic)
	return box


## "King of the week" and the like (nothing for 0).
static func title_pill(tier: int, px: int = 16) -> Control:
	var wrap := HBoxContainer.new()
	if tier <= 0:
		return wrap
	var pill := PanelContainer.new()
	var sb := UiTheme.panel_box(OnlineRules.TITLE_COLORS[tier], 10, 0)
	sb.shadow = 0.0
	sb.line_w = 2.0
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	pill.add_child(row)
	row.add_child(Views.icon("star", px + 4))
	var l := Views.label(t(OnlineRules.TITLE_KEYS[tier]), px, Art.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pill)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return wrap


static func month_name(id: int) -> String:
	return t("MONTH_%d" % clampi(id % 100, 1, 12))


# --- Achievements ---------------------------------------------------------------------------

static func open_achievements(main: Node) -> void:
	GuideView.mark("ach")
	main._modal.open(func(m): achievements(m, main))


static func achievements(m: Modal, _main: Node) -> void:
	Achievements.check()
	m.title(t("ACH_TITLE"))
	m.text(t("ACH_COUNT") % [Achievements.count(), Achievements.LIST.size()], 23, Art.INK)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	# Unlocked first, then the closest ones.
	var order: Array = Achievements.LIST.duplicate()
	order.sort_custom(func(a, b):
		var ga := Achievements.has(str(a[0]))
		var gb := Achievements.has(str(b[0]))
		if ga != gb:
			return ga
		var pa: Array = Achievements.progress(str(a[0]))
		var pb: Array = Achievements.progress(str(b[0]))
		return float(pa[0]) / float(pa[1]) > float(pb[0]) / float(pb[1]))
	for a in order:
		var id := str(a[0])
		var got := Achievements.has(id)
		var c := Views.card(Color("fff4d6") if got else Color("fffaf0"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		c.add_child(h)
		h.add_child(badge(str(a[1]), int(a[2]), got, 64))
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_theme_constant_override("separation", 2)
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(mid)
		mid.add_child(Views.label(t("ACH_" + id.to_upper()), 21, Art.INK, true))
		var d := Views.label(t("ACH_" + id.to_upper() + "_D"), 17, Art.INK_SOFT)
		d.custom_minimum_size.x = 120
		mid.add_child(d)
		if not got:
			var p: Array = Achievements.progress(id)
			if float(p[1]) > 1.0:
				mid.add_child(Views.bar(float(p[0]), float(p[1]), NumFormat.short(float(p[0])) + " / " + NumFormat.short(float(p[1]))))
		var chip := Views.chip("check" if got else "pearl", "" if got else "+%d" % int(a[4]), 20)
		h.add_child(chip)
		list.add_child(c)
	m.add(list)


# --- Profile card --------------------------------------------------------------------------

static func open_profile(main: Node, row: Dictionary) -> void:
	main._top.open(func(m): profile(m, row, main))


static func profile(m: Modal, row: Dictionary, main: Node = null) -> void:
	var you: bool = row.get("you", false)
	var p := Online.parse_profile(Online.profile_info() if you else str(row.get("p", "")))
	var look: Dictionary = Settings.avatar if you else OnlineView._look(str(row.get("a", "")))
	var king := Online.row_is_king(row)
	m.add(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var r := minf(s.x, s.y) / 2.0 - 4.0
		Chars.portrait(ci, s / 2.0 + Vector2(0, 8 if king else 0), r - (8.0 if king else 0.0), look, "happy", Chars.blinking(tt, 3.0), Color("bfe8ff"))
		if king:
			KingArt.on_portrait(ci, s / 2.0 + Vector2(0, 8), r - 8.0, tt), Vector2(0, 130), true))
	m.title(str(row.get("name", "")))
	if int(p["t"]) > 0:
		var tr := title_pill(int(p["t"]), 20)
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		m.add(tr)
	var c := Views.card(Color("eaf6ff"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var lines := [["coin", t("CARD_SCORE") % NumFormat.short(float(row.get("score", 0.0)))],
		["star", t("CARD_BADGES") % [int(p["b"]), Achievements.LIST.size()]],
		["play", t("CARD_WORLDS") % int(p["wo"])]]
	if str(p["c"]) != "":
		lines.append(["people", t("CARD_CLUB") % str(p["c"])])
	if int(p["r"]) > 0:
		lines.append(["star", t("CARD_BEST") % int(p["r"])])
	if int(p["f"]) > 0:
		lines.append(["gift", t("CARD_FOUNDER") % int(p["f"])])
	if int(p.get("s", 0)) > 0:
		lines.append(["star", t("CARD_SLEEPER") % int(p["s"])])
	for ln in lines:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Views.icon(str(ln[0]), 32))
		var l := Views.label(str(ln[1]), 21, Art.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		v.add_child(h)
	m.add(c)
	if Online.admin and not you and main != null:
		leader_tools(m, row, main)
	m.button(t("THANKS_OK"), func(): Sfx.play("click"); m.close(), &"BlueButton")


## Only for the leader: kick (off the boards until they play again) or ban
## (off for good, their scores are refused). Each needs a second tap.
static func leader_tools(m: Modal, row: Dictionary, main: Node) -> void:
	var c := Views.card(Color("ffe3dc"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var head := Views.label(t("LEADER_TITLE"), 22, Color("a8281e"), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size.x = 160
	v.add_child(head)
	var status := Views.label(t("LEADER_HINT"), 18, Art.INK_SOFT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size.x = 160
	v.add_child(status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var busy := [false]
	for kind in ["kick", "ban"]:
		var b := Button.new()
		b.text = t("LEADER_KICK") if kind == "kick" else t("LEADER_BAN")
		b.theme_type_variation = &"GoldButton" if kind == "kick" else &"RedButton"
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var armed := [false]
		var ban: bool = kind == "ban"
		b.pressed.connect(func():
			Sfx.play("click")
			if busy[0]:
				return
			if not armed[0]:
				armed[0] = true
				b.text = t("LEADER_SURE")
				status.text = t("LEADER_KICK_D") if not ban else t("LEADER_BAN_D")
				return
			busy[0] = true
			status.text = t("ONLINE_LOADING")
			Online.kick(row, ban, func(res: String):
				busy[0] = false
				if res != "ok":
					status.text = t("LEADER_FAIL")
					status.add_theme_color_override("font_color", Color("c8372d"))
					return
				status.text = t("LEADER_DONE")
				OnlineView._boards = {}
				if main._modal.is_open():
					main._modal.rebuild()
				if m.is_open():
					m.close()))
		h.add_child(b)
	gift_tools(v, row)
	m.add(c)


## Only for the leader: give this player coins ("18ad") and/or open the
## worlds up to one (every world before it fully built). It reaches them
## within a few minutes, in their ordinary game.
static func gift_tools(v: VBoxContainer, row: Dictionary) -> void:
	var head := Views.label(t("GIFT_TITLE"), 21, Color("2a6a8a"), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size.x = 160
	v.add_child(head)
	var amount := LineEdit.new()
	amount.placeholder_text = t("GIFT_COINS")
	amount.max_length = 12
	amount.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.custom_minimum_size = Vector2(0, 56)
	amount.add_theme_font_size_override("font_size", 22)
	v.add_child(amount)
	var world := OptionButton.new()
	world.add_theme_font_size_override("font_size", 20)
	world.custom_minimum_size = Vector2(0, 56)
	world.add_item(t("GIFT_NO_WORLDS"), 0)
	for l in range(1, Balance.LAST_LOCATION + 1):
		world.add_item(t("GIFT_UPTO") % WorldLook.name_of(l), l)
	v.add_child(world)
	var status := Views.label(t("GIFT_HINT"), 17, Art.INK_SOFT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size.x = 160
	v.add_child(status)
	var b := Button.new()
	b.text = t("GIFT_SEND")
	b.theme_type_variation = &"BlueButton"
	b.custom_minimum_size = Vector2(0, 64)
	v.add_child(b)
	var busy := [false]
	b.pressed.connect(func():
		Sfx.play("click")
		if busy[0]:
			return
		var coins := 0.0 if amount.text.strip_edges() == "" else OnlineRules.parse_amount(amount.text)
		var upto := world.get_selected_id() if world.get_selected_id() > 0 else -1
		if coins < 0.0 or (coins == 0.0 and upto < 0):
			status.text = t("GIFT_BAD")
			return
		busy[0] = true
		status.text = t("ONLINE_LOADING")
		Online.send_gift(row, coins, upto, func(res: String):
			busy[0] = false
			status.text = t("GIFT_DONE") % NumFormat.short(coins) if res == "ok" else t("LEADER_FAIL")))


## The leader's list of banned players, each with "Unban".
## The leader's test mode: free coins, pearls, items and worlds, while
## this device stays off every board (Online.set_tester / cheat).
## The leader's saves: copy the whole save as text, or paste one to load it.
static func _tester_saves(m: Modal) -> void:
	var head := Views.label(t("TESTER_SAVES"), 22, Color("a8281e"), true)
	head.custom_minimum_size.x = 160
	m.add(head)
	var copy := m.button(t("TESTER_SAVE_COPY"), func(): pass, &"BlueButton")
	copy.pressed.connect(func():
		Sfx.play("click")
		DisplayServer.clipboard_set(Online.save_text())
		copy.text = t("COPIED"))
	var box := TextEdit.new()
	box.placeholder_text = t("TESTER_SAVE_HINT")
	box.custom_minimum_size = Vector2(0, 110)
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_theme_font_size_override("font_size", 16)
	m.add(box)
	var load_b := m.button(t("TESTER_SAVE_LOAD"), func(): pass, &"RedButton")
	load_b.pressed.connect(func():
		if Online.load_save_text(box.text):
			Sfx.play("unlock")
			load_b.text = t("TESTER_SAVE_OK")
			load_b.disabled = true
		else:
			Sfx.play("deny")
			load_b.text = t("TESTER_SAVE_BAD"))


static func open_tester(main: Node) -> void:
	main._top.open(func(m): tester(m, main))


static func tester(m: Modal, main: Node) -> void:
	m.title(t("TESTER_TITLE"))
	m.banner(UiTheme.BANNER_RED)
	var on := Online.tester()
	m.text(t("TESTER_ON") if on else t("TESTER_TEXT"), 20, Art.INK if on else Art.INK_SOFT)
	if not on:
		m.button(t("TESTER_START"), func():
			Sfx.play("click")
			Online.set_tester(true, func(_r: String):
				if m.is_open():
					m.rebuild()), &"GoldButton")
		return
	m.text(t("TESTER_STARS_NOW") % [GameState.stars_of(GameState.location), GameState.total_stars()], 19, Art.INK)
	for c: Array in [["coins", "TESTER_COINS"], ["pearls", "TESTER_PEARLS"], ["items", "TESTER_ITEMS"], ["fishing", "TESTER_FISHING"],
			["pass", "TESTER_PASS"], ["max", "TESTER_MAX"], ["world", "TESTER_WORLD"], ["all_worlds", "TESTER_ALL_WORLDS"],
			["star", "TESTER_STAR"], ["star10", "TESTER_STAR10"]]:
		if c[0] in ["world", "all_worlds"] and GameState.is_last_location():
			continue
		var kind: String = c[0]
		m.button(t(c[1]), func():
			if Online.cheat(kind):
				Sfx.play("unlock")
				main._show_toast(t("TESTER_DONE"))
				m.rebuild()
			else:
				Sfx.play("deny"), &"GoldButton")
	_tester_saves(m)
	if bool(Online.data["cheated"]):
		m.text(t("TESTER_STAYS"), 18, Art.INK_SOFT)
	else:
		m.button(t("TESTER_STOP"), func():
			Sfx.play("click")
			Online.set_tester(false, func(_r: String):
				if m.is_open():
					m.rebuild()), &"CreamButton")


static func open_bans(main: Node) -> void:
	main._top.open(func(m): bans(m, main))


static func bans(m: Modal, main: Node) -> void:
	m.title(t("LEADER_BANS_TITLE"))
	m.banner(UiTheme.BANNER_RED)
	var list := Online.ban_list()
	if list.is_empty():
		m.text(t("LEADER_NO_BANS"), 21, Art.INK_SOFT)
	for b in list:
		var row := m.row(8)
		var l := Views.label(str(b["name"]) if str(b["name"]) != "" else str(b["uid"]).left(8), 21, Art.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 100
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var u := Button.new()
		u.text = t("LEADER_UNBAN")
		u.theme_type_variation = &"CreamButton"
		u.custom_minimum_size = Vector2(0, 58)
		var id := str(b["uid"])
		u.pressed.connect(func():
			Sfx.play("click")
			u.disabled = true
			Online.unban(id, func(res: String):
				if not m.is_open():
					return
				if res == "ok":
					m.rebuild()
					if main._modal.is_open():
						main._modal.rebuild()
				else:
					u.disabled = false
					u.text = t("LEADER_FAIL_SHORT")))
		row.add_child(u)
	m.button(t("THANKS_OK"), func(): Sfx.play("click"); m.close(), &"BlueButton")


# --- Clubs ---------------------------------------------------------------------------------

static func open_clubs(main: Node, show_id := "") -> void:
	GuideView.mark("clubs")
	_club = {}
	_clubs_board = {}
	_club_msg = ""
	var id := show_id if show_id != "" else str(Online.data["club"])
	main._modal.open(func(m): clubs(m, main, id))


## A club (members, code, join / leave) or, with no id, making or finding one.
static func clubs(m: Modal, main: Node, id: String) -> void:
	m.title(t("CLUB_TITLE"))
	if not Online.available():
		OnlineView._offline(m, func(): open_clubs(main, id))
		return
	if _club_msg != "":
		m.text(_club_msg, 20, Color("c8372d"))
	if id == "":
		_no_club(m, main)
		return
	if _club.is_empty() or str(_club.get("want", "")) != id:
		_club = {"want": id, "loading": true}
		Online.club_info(id, func(info: Dictionary):
			info["want"] = id
			_club = info
			if m.is_open():
				m.rebuild())
	if _club.get("loading", false):
		m.text(t("ONLINE_LOADING"), 24, Art.INK_SOFT)
		return
	if not _club.get("ok", false):
		m.text(t("CLUB_GONE"), 22, Art.INK)
		m.button(t("CLUB_FIND"), func(): Sfx.play("click"); _club = {}; m.close(); open_clubs(main, ""), &"BlueButton")
		return
	var mine := id == str(Online.data["club"])
	var head := Views.card(Color("e6f7ec"))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	var nm := Views.label(str(_club["name"]), 28, Art.GREEN_DARK, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size.x = 160
	hv.add_child(nm)
	for line in [t("CLUB_MEMBERS") % [int(_club["n"]), OnlineRules.CLUB_MAX], t("CLUB_WEEK") % NumFormat.short(float(_club["sum"])),
			t("CLUB_CODE") % id]:
		var l := Views.label(line, 20, Art.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 160
		hv.add_child(l)
	m.add(head)
	if mine:
		m.text(t("CLUB_CODE_HINT"), 18, Art.INK_SOFT)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var members: Array = _club["members"]
	for i in members.size():
		var r: Dictionary = members[i]
		r["a"] = ""
		list.add_child(OnlineView._row(i + 1, r))
	m.add(list)
	if mine:
		var leave := m.button(t("CLUB_LEAVE"), func():
			Sfx.play("click")
			Online.club_leave(func(res: String):
				_club_msg = "" if res == "ok" else t("ONLINE_OFF")
				_club = {}
				if m.is_open():
					m.close()
					open_clubs(main, "")), &"DarkButton")
		leave.icon = Icons.get_icon("close", 30)
	elif int(_club["n"]) < OnlineRules.CLUB_MAX:
		var join := m.button(t("CLUB_JOIN"), func(): Sfx.play("click"); _join(m, main, id), &"GoldButton")
		join.icon = Icons.get_icon("people", 34)
		if Online.in_club():
			m.text(t("CLUB_SWITCH") % str(Online.data["club_name"]), 18, Art.INK_SOFT)
	else:
		m.text(t("CLUB_FULL"), 20, Art.INK_SOFT)


static func _join(m: Modal, main: Node, id: String) -> void:
	Online.club_join(id, func(res: String):
		match res:
			"ok":
				Sfx.play("unlock")
				_club_msg = ""
			"full":
				_club_msg = t("CLUB_FULL")
			"gone":
				_club_msg = t("CLUB_GONE")
			_:
				_club_msg = t("ONLINE_OFF")
		_club = {}
		if m.is_open():
			m.close()
			open_clubs(main, str(Online.data["club"]) if res == "ok" else ""))


static func _no_club(m: Modal, main: Node) -> void:
	m.text(t("CLUB_HINT"), 21, Art.INK)
	# Make one.
	var make := Views.card(Color("fff4d6"))
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	make.add_child(mv)
	var edit := LineEdit.new()
	edit.max_length = 16
	edit.placeholder_text = t("CLUB_NAME_HINT")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size.y = 72
	mv.add_child(edit)
	var create := Button.new()
	create.text = t("CLUB_CREATE")
	create.theme_type_variation = &"GoldButton"
	create.custom_minimum_size.y = 64
	create.icon = Icons.get_icon("plus", 32)
	create.pressed.connect(func():
		Sfx.play("click")
		create.disabled = true
		Online.club_create(edit.text, func(res: String):
			_club_msg = "" if res == "ok" else (t("CLUB_RUDE") if res == "rude" else t("ONLINE_OFF"))
			if m.is_open():
				m.close()
				open_clubs(main, str(Online.data["club"]) if res == "ok" else "")))
	mv.add_child(create)
	m.add(make)
	# Join with a code.
	var code_row := m.row(8)
	var code := LineEdit.new()
	code.max_length = 8
	code.placeholder_text = t("CLUB_CODE_ENTER")
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.custom_minimum_size = Vector2(0, 64)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code)
	var go := Button.new()
	go.text = t("CLUB_JOIN")
	go.theme_type_variation = &"BlueButton"
	go.custom_minimum_size = Vector2(0, 64)
	go.pressed.connect(func():
		Sfx.play("click")
		var c := code.text.strip_edges()
		if not OnlineRules.club_id_ok(c):
			_club_msg = t("CLUB_GONE")
			m.rebuild()
			return
		m.close()
		open_clubs(main, c))
	code_row.add_child(go)
	# This week's clubs.
	m.text(t("CLUB_TOP"), 22, Art.INK)
	_club_list(m, main)


## This week's club board (tap a club to see it).
static func _club_list(m: Modal, main: Node) -> void:
	if _clubs_board.is_empty():
		_clubs_board = {"loading": true}
		Online.fetch_board("clubs", func(res: Dictionary):
			_clubs_board = res
			if m.is_open():
				m.rebuild())
	if _clubs_board.get("loading", false):
		m.text(t("ONLINE_LOADING"), 22, Art.INK_SOFT)
		return
	club_rows(m, main, _clubs_board)


static func club_rows(m: Modal, main: Node, board: Dictionary) -> void:
	var rows: Array = board.get("rows", [])
	if rows.is_empty():
		m.text(t("CLUB_NONE"), 21, Art.INK_SOFT)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := str(r["uid"]) == str(Online.data["club"])
		var c := Views.card(Color("ffe9a0") if mine else Color("fffaf0"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		c.add_child(h)
		var place := i + 1
		h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): RivalsView._draw_place(ci, s / 2.0, place), Vector2(46, 52)))
		h.add_child(Views.icon("people", 38))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		var nl := Views.label(OnlineRules.strip_name(str(r["name"])), 21, Art.INK, true)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.x = 60
		v.add_child(nl)
		v.add_child(Views.label(t("CLUB_MEMBERS") % [int(r.get("n", 0)), OnlineRules.CLUB_MAX], 16, Art.INK_SOFT))
		h.add_child(v)
		h.add_child(Views.icon("coin", 30))
		var sc := Views.label(NumFormat.short(float(r["score"])), 22, Color("1c7fb8"), true)
		sc.autowrap_mode = TextServer.AUTOWRAP_OFF
		sc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(sc)
		var id := str(r["uid"])
		on_tap(c, func():
			m.close()
			open_clubs(main, id))
		list.add_child(c)
	m.add(list)


# --- Challenge of the day ----------------------------------------------------------------------

## The card on top of the quests list.
static func daily_card(m: Modal, main: Node) -> void:
	GuideView.mark("challenge")
	DailyChallenge.refresh()
	var kind := DailyChallenge.kind()
	var p := DailyChallenge.progress()
	var done := DailyChallenge.complete()
	var claimed := DailyChallenge.claimed()
	var c := Views.card(Color("e8e0ff") if not claimed else Color("eef0f4"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	c.add_child(h)
	h.add_child(badge("star", 2, not claimed, 60))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	mid.add_child(Views.label(t("DC_TITLE"), 19, Color("6a3fc0"), true))
	mid.add_child(Views.label(t("DC_" + kind.to_upper()) % NumFormat.short(float(p[1])), 21, Art.INK, true))
	if claimed:
		mid.add_child(Views.label(t("DC_DONE"), 18, Art.GREEN_DARK, true))
	else:
		mid.add_child(Views.bar(float(p[0]), float(p[1]), NumFormat.short(float(p[0])) + " / " + NumFormat.short(float(p[1]))))
		mid.add_child(Views.label(t("DC_SAME"), 16, Art.INK_SOFT))
	if done and not claimed:
		var b := PriceButton.new()
		b.custom_minimum_size = Vector2(176, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.set_price(t("CLAIM"), "+%d" % DailyChallenge.PEARLS, "pearl")
		b.theme_type_variation = &"GoldButton"
		b.pressed.connect(func():
			if DailyChallenge.claim():
				main.celebrate({"pearls": DailyChallenge.PEARLS}, b.get_global_rect().get_center())
			m.rebuild())
		h.add_child(b)
	elif not claimed:
		h.add_child(Views.chip("pearl", "+%d" % DailyChallenge.PEARLS, 20))
	m.add(c)
