class_name OnlineView
extends RefCounted
## Dialogs of the online features (Online autoload): the real players'
## leaderboard, the promo code field, inviting friends and the thank-you
## dialog for founder, promo and invite gifts. Opened from the Profile, the
## Settings and the Rivals League (OnlineView.*_buttons), shown by OnlineHook.
## Everything waits for the network without blocking: a "Loading…" line,
## then the content, or "Online is not available right now".

## Leaderboard tab: "week" or "all".
static var tab := "week"
## Boards and invite info being fetched / fetched for the open dialog.
static var _boards := {}
static var _link := ""
static var _friends := -1
static var _asked := {}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


# --- Entry points (one line each in the screens that show them) --------------------

## Profile: the players' board and the invite button, under the Rivals League.
static func profile_buttons(m: Modal, main: Node) -> void:
	var board := m.button(t("ONLINE_BUTTON"), func(): Sfx.play("click"); open_board(main), &"BlueButton")
	board.icon = Icons.get_icon("star", 36)
	var inv := m.button(t("INVITE"), func(): Sfx.play("click"); open_invite(main), &"Button")
	inv.icon = Icons.get_icon("people", 36)
	var ach := m.button("%s  ·  %d/%d" % [t("ACH_BUTTON"), Achievements.count(), Achievements.LIST.size()],
		func(): Sfx.play("click"); SocialView.open_achievements(main), &"GoldButton")
	ach.icon = Icons.get_icon("star", 36)
	var club := m.button(t("CLUB_MY") if Online.in_club() else t("CLUB_FIND"), func(): Sfx.play("click"); SocialView.open_clubs(main), &"Button")
	club.icon = Icons.get_icon("people", 36)


## Settings, the player section: promo code and invites.
static func settings_buttons(box: Container, m: Modal, main: Node) -> void:
	for b in [["PROMO", "gift", &"GoldButton", func(): open_promo(main)],
			["INVITE", "people", &"Button", func(): open_invite(main)],
			["ONLINE_BUTTON", "star", &"BlueButton", func(): open_board(main)]]:
		var go: Callable = b[3]
		var btn := m.button(t(b[0]), func(): Sfx.play("click"); go.call(), b[2])
		btn.icon = Icons.get_icon(b[1], 32)
		btn.reparent(box, false)


## Rivals League (computer characters): a way to the real players' board.
static func rivals_link(m: Modal, main: Node) -> void:
	var b := m.button(t("ONLINE_BUTTON"), func(): Sfx.play("click"); open_board(main), &"BlueButton")
	b.icon = Icons.get_icon("star", 34)


static func open_board(main: Node) -> void:
	_boards = {}
	main._modal.open(func(m): board(m, main))


static func open_promo(main: Node) -> void:
	main._top.open(func(m): promo(m, main))


static func open_invite(main: Node) -> void:
	_link = ""
	_friends = -1
	_asked = {}
	main._modal.open(func(m): invite(m, main))


# --- Leaderboard ------------------------------------------------------------------------

static func board(m: Modal, main: Node) -> void:
	m.title(t("ONLINE_BOARD"))
	_account(m, main)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): FounderArt.podium(ci, s / 2.0 + Vector2(0, 10), 1.5, tt), Vector2(120, 92), true))
	var sub := VBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Real people only (the Rivals League's computer characters have their
	# own board): a green "Real players" tag and a line saying so.
	sub.add_child(_real_tag())
	var sl := Views.label(t("ONLINE_BOARD_SUB"), 20, Art.INK_SOFT)
	sl.custom_minimum_size.x = 160
	sub.add_child(sl)
	head.add_child(sub)
	m.add(head)
	if not Online.available():
		_offline(m, func(): open_board(main))
		return
	# Two rows of tabs: the races (week, season, all time), then friends and clubs.
	for line in [[["week", "ONLINE_WEEK"], ["month", "ONLINE_MONTH"], ["all", "ONLINE_ALL"]],
			[["friends", "ONLINE_FRIENDS"], ["clubs", "ONLINE_CLUBS"]]]:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 8)
		for tb in line:
			var b := Button.new()
			b.text = t(tb[1])
			b.theme_type_variation = &"SlimPurpleButton" if tab == tb[0] else &"SlimCreamButton"
			b.custom_minimum_size = Vector2(0, 58)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			var id: String = tb[0]
			b.pressed.connect(func():
				Sfx.play("click")
				tab = id
				m.rebuild())
			tabs.add_child(b)
		Views.fit_button_row(tabs, 22)
		m.add(tabs)
	match tab:
		"week":
			m.text(t("ONLINE_WEEK_HINT"), 18, Art.INK_SOFT)
		"month":
			m.text(t("SEASON_HINT") % SocialView.month_name(int(Online.data["month"])), 18, Art.INK_SOFT)
		"friends":
			m.text(t("FRIENDS_HINT"), 18, Art.INK_SOFT)
		"clubs":
			m.text(t("CLUBS_HINT"), 18, Art.INK_SOFT)
		_:
			m.text(t("ONLINE_ALL_HINT"), 18, Art.INK_SOFT)
	var kind := tab
	var got: Dictionary = _boards.get(kind, {})
	if got.is_empty():
		_boards[kind] = {"loading": true}
		Online.fetch_board(kind, func(res: Dictionary):
			_boards[kind] = res
			if m.is_open() and tab == kind:
				m.rebuild())
		got = _boards[kind]
	if got.get("loading", false):
		m.text(t("ONLINE_LOADING"), 24, Art.INK_SOFT)
		return
	if not got.get("ok", false):
		_offline(m, func():
			_boards.erase(kind)
			m.rebuild())
		return
	var rows: Array = got["rows"]
	if kind == "clubs":
		var my := m.button(t("CLUB_MY") if Online.in_club() else t("CLUB_FIND"), func(): Sfx.play("click"); SocialView.open_clubs(main), &"GoldButton")
		my.icon = Icons.get_icon("people", 34)
		SocialView.club_rows(m, main, got)
		return
	if kind == "week":
		var my_rank := int(got.get("rank", 0))
		for i in rows.size():
			if rows[i]["you"]:
				my_rank = i + 1
		m.add(_race(rows, my_rank, Online.score("week")))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var mine_shown := false
	for i in rows.size():
		var r: Dictionary = rows[i]
		mine_shown = mine_shown or r["you"]
		var card := _row(i + 1, r)
		SocialView.on_tap(card, func(): SocialView.open_profile(main, r))
		list.add_child(card)
	if rows.size() <= 1 and kind == "friends":
		m.text(t("FRIENDS_EMPTY"), 22, Art.INK)
	elif rows.is_empty():
		m.text(t("ONLINE_EMPTY"), 22, Art.INK)
	else:
		m.text(t("CARD_TAP"), 17, Art.INK_SOFT)
	m.add(list)
	if not mine_shown and kind != "friends":
		var me := {"uid": Online.uid, "name": Online.board_name(), "score": Online.score(kind), "a": "", "you": true}
		var rank := int(got.get("rank", 0))
		if rank > 0:
			m.text(t("ONLINE_YOUR_PLACE") % rank, 21, Art.INK)
			m.add(_row(rank, me))
		else:
			m.text(t("ONLINE_YOUR_SCORE") % NumFormat.short(Online.score(kind)), 21, Art.INK)
	var name_row := m.row(10)
	var nl := Views.label(t("ONLINE_NAME") % Online.board_name(), 19, Art.INK_SOFT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.custom_minimum_size.x = 140
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(nl)
	var rename := Button.new()
	rename.theme_type_variation = &"CreamButton"
	rename.icon = Icons.get_icon("pencil", 30)
	rename.text = t("ONLINE_RENAME")
	rename.custom_minimum_size = Vector2(0, 60)
	rename.add_theme_font_size_override("font_size", 19)
	rename.pressed.connect(func():
		Sfx.play("click")
		main.ask_name(Profiles.current_id, func():
			Online.claim_name(func(_r: String):
				Online.submit_soon()
				if m.is_open():
					m.rebuild())))
	name_row.add_child(rename)
	match Online.name_state():
		"taken":
			m.text(t("ONLINE_NAME_TAKEN") % Online.wanted_name(), 19, Color("c8372d"))
		"rude":
			m.text(t("ONLINE_NAME_RUDE"), 19, Color("c8372d"))
	var inv := m.button(t("INVITE"), func(): Sfx.play("click"); open_invite(main), &"GoldButton")
	inv.icon = Icons.get_icon("people", 34)


## The account: who is playing and where the progress is kept, with the
## way to log in that this page allows (CrazyGames account on CrazyGames,
## Google on our own site; nothing else on CrazyGames, by their rules).
static func _account(m: Modal, main: Node) -> void:
	var card := Views.card(Color("eaf6ff"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		Chars.portrait(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, Settings.avatar, "happy", Chars.blinking(tt, 3.0), Color("bfe8ff")), Vector2(64, 64), true))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var name := Views.label(Profiles.player_name(), 23, Art.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size.x = 80
	v.add_child(name)
	var line := ""
	var btn_text := ""
	var go := Callable()
	if Platform.cg_accounts():
		var u := Platform.cg_user()
		if u != "":
			line = t("ACCOUNT_CG_IN") % u
		else:
			line = t("ACCOUNT_CG_HINT")
			btn_text = t("ACCOUNT_CG_SIGN_IN")
			go = func(): Platform.cg_sign_in()
	elif CloudSave.google_available():
		var u := CloudSave.google_user()
		if u != "":
			line = t("ACCOUNT_GOOGLE_IN") % u
		else:
			line = t("CLOUD_HINT")
			btn_text = t("CLOUD_SIGN_IN")
			go = func(): main.google_sign_in()
	else:
		line = t("ACCOUNT_LOCAL")
	var l := Views.label(line, 18, Art.INK_SOFT)
	l.custom_minimum_size.x = 120
	v.add_child(l)
	m.add(card)
	if btn_text != "":
		var b := m.button(btn_text, func(): Sfx.play("click"); go.call(), &"BlueButton")
		b.icon = Icons.get_icon("people", 32)


## This week's race: the place, how far the next place is, the prizes.
static func _race(rows: Array, rank: int, mine: float) -> Control:
	var card := Views.card(Color("fff4d6"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := Views.label(t("RACE_TITLE"), 25, Art.GOLD_DARK.darkened(0.25), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var gap := 0.0
	var target := 0.0
	if rank == 1:
		v.add_child(_center(Views.label(t("RACE_LEAD"), 21, Art.GREEN_DARK, true)))
	elif rank > 1 and rank - 2 < rows.size():
		target = float(rows[rank - 2]["score"])
		gap = maxf(0.0, target - mine)
		v.add_child(_center(Views.label(t("RACE_PLACE") % rank, 21, Art.INK, true)))
		v.add_child(_center(Views.label(t("RACE_TO_NEXT") % [NumFormat.short(gap + 1.0), rank - 1], 19, Art.INK_SOFT)))
	elif rank > 1:
		v.add_child(_center(Views.label(t("RACE_PLACE") % rank, 21, Art.INK, true)))
	if target > 0.0:
		var f := clampf(mine / target, 0.0, 1.0)
		v.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
			var r := Rect2(Vector2(8, s.y / 2.0 - 9), Vector2(s.x - 16, 18))
			Art.t_rect(ci, r, 9.0, Color("e8d9b0"), 2.5, 0.0)
			if f > 0.02:
				Art.t_rect(ci, Rect2(r.position, Vector2(maxf(18.0, r.size.x * f), r.size.y)), 9.0, Art.GOLD, 2.5, 0.5), Vector2(0, 30)))
	var prizes := Views.label(t("RACE_PRIZES"), 17, Art.INK_SOFT)
	prizes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prizes.custom_minimum_size.x = 160
	v.add_child(prizes)
	var sat := Views.label(t("RACE_X2"), 17, Color("2a8a4a"), true)
	sat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sat.custom_minimum_size.x = 160
	v.add_child(sat)
	return card


static func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 160
	return l


static func _row(place: int, row: Dictionary) -> Control:
	var you: bool = row["you"]
	var card := Views.card(Color("ffe9a0") if you else Color("fffaf0"))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	if you:
		sb.line = Art.GOLD_DARK.darkened(0.35)
		sb.line_w = 5.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): RivalsView._draw_place(ci, s / 2.0, place),
			Vector2(46 if place < 100 else 64, 56)))
	var look := Settings.avatar if you else _look(str(row.get("a", "")))
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		Chars.portrait(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, look, "happy", false, Color("ffd98a") if you else Color("bfe8ff")),
			Vector2(54, 54)))
	var text := str(row["name"])
	if you:
		text = t("ONLINE_YOU") + " · " + text
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_theme_constant_override("separation", 0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := Views.label(text, 21, Art.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size.x = 60
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nv.add_child(name)
	var tier := Online.title() if you else int(Online.parse_profile(str(row.get("p", "")))["t"])
	if tier > 0:
		nv.add_child(SocialView.title_pill(tier, 14))
	h.add_child(nv)
	var score := Views.label(NumFormat.short(float(row["score"])), 22, Color("1c7fb8") if not you else Art.INK, true)
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(Views.icon("coin", 30))
	h.add_child(score)
	return card


static var _looks := {}


static func _look(a: String) -> Dictionary:
	if not _looks.has(a):
		_looks[a] = Settings.sanitize_look(JSON.parse_string(a) if a.begins_with("{") and a.length() <= 300 else null)
	return _looks[a]


## Green pill: "Real players" with a little globe (the Rivals League has
## "Computer" pills).
static func _real_tag() -> Control:
	var wrap := HBoxContainer.new()
	var pill := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("d8f7d4"), 10, 0)
	sb.shadow = 0.0
	sb.line_w = 2.0
	sb.content_margin_left = 6
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	row.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_globe(ci, s / 2.0, 9.0), Vector2(22, 22)))
	var l := Views.label(t("ONLINE_REAL"), 17, Art.GREEN_DARK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	wrap.add_child(pill)
	return wrap


static func _draw_globe(ci: CanvasItem, c: Vector2, r: float) -> void:
	var disc := Art.circle_pts(c, r, 20)
	Art.toon(ci, disc, Art.BLUE, 1.6, 0.0)
	Art.flat(ci, Art.clipped(Art.union([Art.ellipse_pts(c + Vector2(-3, -2), Vector2(4, 3), 10, 0.4),
			Art.ellipse_pts(c + Vector2(4, 3), Vector2(3, 4), 10, -0.3)]), disc), Art.GREEN)
	Art.ring(ci, disc, Art.INK, 1.6)


## The "not available" card with a retry button.
static func _offline(m: Modal, retry: Callable) -> void:
	var c := Views.card(Color("e8eefc"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	c.add_child(v)
	var head := Views.label(t("ONLINE_OFF"), 24, Art.INK, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size.x = 200
	v.add_child(head)
	var hint := Views.label(t("ONLINE_OFF_HINT"), 19, Art.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 200
	v.add_child(hint)
	var b := Button.new()
	b.text = t("ONLINE_RETRY")
	b.theme_type_variation = &"BlueButton"
	b.custom_minimum_size.y = 64
	b.pressed.connect(func(): Sfx.play("click"); retry.call())
	v.add_child(b)
	m.add(c)


# --- Promo code ---------------------------------------------------------------------------

static func promo(m: Modal, main: Node) -> void:
	m.title(t("PROMO"))
	m.add(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_ticket(ci, s / 2.0, tt), Vector2(0, 90), true))
	m.text(t("PROMO_HINT"), 21, Art.INK_SOFT)
	var edit := LineEdit.new()
	edit.max_length = 24
	edit.placeholder_text = t("PROMO_PLACEHOLDER")
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size.y = 84
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	m.add(edit)
	var msg := m.text("", 20, Art.RED)
	msg.visible = false
	var ok := m.button(t("PROMO_OK"), func(): pass, &"GoldButton")
	var submit := func(_x = "") -> void:
		var res := Online.redeem(edit.text)
		match str(res["result"]):
			"ok":
				Sfx.play("unlock")
				var info := Online.take_thanks()
				m.open(func(mm): thanks(mm, main, info if not info.is_empty() else res["reward"]))
			"used":
				Sfx.play("deny")
				msg.text = t("PROMO_USED")
				msg.visible = true
			_:
				Sfx.play("deny")
				msg.text = t("PROMO_BAD")
				msg.visible = true
				Wardrobe._shake(edit)
	ok.pressed.connect(submit)
	edit.text_submitted.connect(submit)
	edit.text_changed.connect(func(_s): msg.visible = false)
	edit.grab_focus.call_deferred()


## A golden ticket with a star.
static func _draw_ticket(ci: CanvasItem, c: Vector2, tt: float) -> void:
	Art.push(ci, c, -0.06, Vector2.ONE)
	var body := Art.rrect_pts(Rect2(-62, -30, 124, 60), 10)
	var bites := Art.union([Art.circle_pts(Vector2(-62, 0), 9, 14), Art.circle_pts(Vector2(62, 0), 9, 14)])
	var shape := Geometry2D.clip_polygons(body, bites)
	Art.toon(ci, shape[0] if not shape.is_empty() else body, Art.GOLD, 3.0, 0.5)
	for i in 6:
		Art.flat(ci, Art.rrect_pts(Rect2(-36, -22 + i * 8, 2, 4), 1), Art.GOLD_DARK)
	Art.toon(ci, FounderArt.star5(Vector2(12, 0), 18.0), Art.WHITE, 2.5, 0.0)
	Art.pop(ci)
	var k := int(tt * 2.5) % 2
	FounderArt.star(ci, c + Vector2(70, -30), 6.0 if k == 0 else 4.0, Art.WHITE)
	FounderArt.star(ci, c + Vector2(-72, 26), 4.0 if k == 1 else 3.0, Art.GOLD)


# --- Invite friends ---------------------------------------------------------------------

static func invite(m: Modal, main: Node) -> void:
	m.title(t("INVITE"))
	m.add(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): FounderArt.letter(ci, s / 2.0, 1.5, tt), Vector2(0, 100), true))
	m.text(t("INVITE_HINT") % [OnlineRules.INVITE_PEARLS, OnlineRules.INVITE_CAP], 21, Art.INK)
	if not Online.available():
		_offline(m, func(): open_invite(main))
		return
	if not _asked.has("link"):
		_asked["link"] = true
		Online.invite_link(func(link: String):
			_link = link if link != "" else "-"
			if m.is_open():
				m.rebuild())
	if not _asked.has("friends"):
		_asked["friends"] = true
		Online.check_invites(func(n: int):
			_friends = n
			if m.is_open():
				m.rebuild())
	var c := Views.card(Color("fff1c2"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	# The link itself, to copy by hand when sharing is blocked (it can be
	# selected but not changed).
	var field := LineEdit.new()
	field.text = _link if _link != "-" else ""
	field.text_changed.connect(func(_s):
		var at := field.caret_column
		field.text = _link if _link != "-" else ""
		field.caret_column = mini(at, field.text.length()))
	field.placeholder_text = t("ONLINE_LOADING") if _link == "" else t("ONLINE_OFF")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 19)
	field.custom_minimum_size.y = 60
	v.add_child(field)
	var share := Button.new()
	share.text = t("INVITE_SHARE")
	share.icon = Icons.get_icon("people", 34)
	share.theme_type_variation = &"GoldButton"
	share.custom_minimum_size.y = 76
	share.disabled = _link == "" or _link == "-"
	share.pressed.connect(func():
		Sfx.play("click")
		Online.share(t("INVITE_TEXT_SHARE"), _link, func(res: String):
			if res == "copied" and is_instance_valid(share):
				# Said on the button itself (a toast would hide under the dialog).
				share.text = t("INVITE_COPIED")
				share.icon = Icons.get_icon("check", 30)
				Sfx.play("pop")
			elif res == "error":
				field.select_all()
				field.grab_focus()))
	v.add_child(share)
	m.add(c)
	var friends := Views.label(t("INVITE_FRIENDS") % maxi(0, _friends) if _friends >= 0 else t("ONLINE_LOADING"), 22, Art.INK, true)
	friends.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add(friends)
	if not Online.has_exclusive():
		var hint := Views.card(Color("efe6ff"))
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 10)
		hint.add_child(hh)
		hh.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_cap(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, tt), Vector2(70, 70), true))
		var hl := Views.label(t("INVITE_CAP_ITEM"), 20, Art.INK, true)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.custom_minimum_size.x = 140
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hh.add_child(hl)
		m.add(hint)


## The player's face in the Founder Cap.
static func _draw_cap(ci: CanvasItem, c: Vector2, r: float, tt: float) -> void:
	var look := Settings.avatar.duplicate()
	look["hat"] = "founder"
	Chars.portrait(ci, c, r, look, "happy", Chars.blinking(tt, 3.0), Color("ffd98a"))


# --- Thank-you dialog ---------------------------------------------------------------------

## info: Online's gift {"kind": founder|promo|join|inviter, "pearls", "boost" (s), "item", "n"}.
static func thanks(m: Modal, main: Node, info: Dictionary) -> void:
	var kind := str(info.get("kind", ""))
	var n := int(info.get("n", 0))
	m.add(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		if kind == "founder":
			FounderArt.medal(ci, s / 2.0 + Vector2(0, 18), 54.0, n, tt)
		elif kind == "week" or kind == "season":
			FounderArt.podium(ci, s / 2.0 + Vector2(0, 14), 1.7, tt)
		elif kind in ["join", "inviter"]:
			FounderArt.letter(ci, s / 2.0 + Vector2(0, 6), 1.7, tt)
		else:
			_draw_ticket(ci, s / 2.0, tt), Vector2(0, 140), true))
	m.title(t("THANKS_WEEK_TITLE") if kind == "week" else (t("THANKS_SEASON_TITLE") if kind == "season" else t("THANKS_TITLE")))
	match kind:
		"season":
			m.text(t("THANKS_SEASON") % n if n > 0 else t("THANKS_SEASON_ALL"), 25, Art.GOLD_DARK.darkened(0.2))
		"week":
			m.text(t("THANKS_WEEK") % n if n > 0 else t("THANKS_WEEK_ALL"), 25, Art.GOLD_DARK.darkened(0.2))
		"founder":
			m.text(t("THANKS_FOUNDER") % [n, OnlineRules.FOUNDER_MAX], 26, Art.GOLD_DARK.darkened(0.2))
		"promo":
			m.text(t("THANKS_PROMO"), 24, Art.GREEN_DARK)
		"join":
			m.text(t("THANKS_JOIN"), 24, Color("1c7fb8"))
		"inviter":
			m.text(t("THANKS_INVITER") % n, 24, Color("1c7fb8"))
	if kind != "week" and kind != "season":
		var c := Views.card(Color("fff1c2"))
		var msg := Views.label(t("THANKS_TEXT"), 25, Art.INK, true)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.custom_minimum_size.x = 200
		c.add_child(msg)
		m.add(c)
	var chips := {"pearls": int(info.get("pearls", 0)), "boost": int(float(info.get("boost", 0.0)) / 60.0)}
	m.add(Views.reward_chips(chips))
	if bool(info.get("item", false)):
		var ic := Views.card(Color("efe6ff"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		ic.add_child(h)
		h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_cap(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, tt), Vector2(80, 80), true))
		var il := Views.label(t("THANKS_ITEM"), 22, Color("6a3fc0"), true)
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il.custom_minimum_size.x = 140
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(il)
		m.add(ic)
	# Lambdas capture locals by value: the button is reached through an array.
	var ok := [null]
	ok[0] = m.button(t("THANKS_OK"), func():
		var b: Button = ok[0]
		var from: Vector2 = b.get_global_rect().get_center() if is_instance_valid(b) else main.get_viewport_rect().size / 2.0
		if int(info.get("pearls", 0)) > 0:
			main.celebrate({"pearls": int(info.get("pearls", 0))}, from)
		m.close(), &"GoldButton")
