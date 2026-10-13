class_name OnlineView
extends RefCounted
## Dialogs of the online features (Online autoload): the real players'
## leaderboard, the promo code field, inviting friends and the thank-you
## dialog for founder, promo and invite gifts. Opened from the Profile, the
## Settings and the Rivals League (OnlineView.*_buttons), shown by OnlineHook.
## Everything waits for the network without blocking: a "Loading…" line,
## then the content, or "Online is not available right now".

## Rows built when a board opens (the rest after "Show more").
const FIRST_ROWS := 30
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

## Profile tiles: the players' board, clubs, invites, the guide.
static func profile_items(main: Node) -> Array:
	return [
		["star", t("ONLINE_BUTTON"), &"BlueButton", func(): open_board(main)],
		["people", t("CLUB_MY") if Online.in_club() else t("CLUB_FIND"), &"Button", func(): SocialView.open_clubs(main)],
		["people", t("INVITE"), &"Button", func(): open_invite(main)],
		["quests", t("GUIDE_TITLE"), &"PurpleButton", func(): GuideView.open(main)],
	]


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


static func open_board(main: Node, want := "") -> void:
	if want != "":
		tab = want
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
	m.banner(UiTheme.BANNER_GOLD)
	# Real people only (the Rivals League's computer characters have their
	# own board): a green "Real players" tag and a line saying so.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_real_tag())
	var sl := Views.label(t("ONLINE_BOARD_SUB"), 17, Art.INK_SOFT)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size.x = 120
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(sl)
	m.add(head)
	if not Online.available():
		_offline(m, func(): open_board(main))
		return
	# Two rows of tabs: the races (week, season, all time), then friends and clubs.
	for line in [[["week", "ONLINE_WEEK"], ["month", "ONLINE_MONTH"], ["all", "ONLINE_ALL"]],
			[["puzzle", "ONLINE_PUZZLE"], ["friends", "ONLINE_FRIENDS"], ["clubs", "ONLINE_CLUBS"]]]:
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
	GuideView.mark({"week": "board", "month": "season", "puzzle": "puzzle_board", "friends": "friends", "clubs": "clubs", "all": "board"}.get(tab, "board"))
	match tab:
		"week":
			m.text(t("ONLINE_WEEK_HINT"), 18, Art.INK_SOFT)
		"puzzle":
			m.text(t("PUZZLE_BOARD_HINT"), 18, Art.INK_SOFT)
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
	var unit := "star" if kind == "puzzle" else "coin"
	var my_at := -1
	for i in rows.size():
		if rows[i]["you"]:
			my_at = i
	if rows.size() <= 1 and kind == "friends":
		m.text(t("FRIENDS_EMPTY"), 22, Art.INK)
	elif rows.is_empty():
		m.text(t("ONLINE_EMPTY"), 22, Art.INK)
	else:
		m.add(_podium(rows, unit, main))
	if kind == "week":
		m.add(_race(rows, my_at + 1 if my_at >= 0 else int(got.get("rank", 0)), Online.score("week")))
	# The player's own place right under the podium (the list is long).
	if my_at >= 3:
		m.text(t("ONLINE_YOUR_PLACE") % (my_at + 1), 20, Art.INK)
		m.add(_row(my_at + 1, rows[my_at], unit))
	elif my_at < 0 and kind != "friends":
		var me := {"uid": Online.uid, "name": Online.board_name(), "score": Online.score(kind), "a": "", "you": true}
		var rank := int(got.get("rank", 0))
		if rank > 0:
			m.text(t("ONLINE_YOUR_PLACE") % rank, 20, Art.INK)
			m.add(_row(rank, me, unit))
		else:
			m.text(t("ONLINE_YOUR_SCORE") % NumFormat.short(Online.score(kind)), 20, Art.INK)
	if rows.size() > 3:
		m.text(t("CARD_TAP"), 17, Art.INK_SOFT)
	# Places 4 to 100: the first ones at once, the rest on a tap (a phone
	# builds them in a moment, without a hitch when the board opens).
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	m.add(list)
	var add_rows := func(from: int, to: int) -> void:
		for i in range(from, mini(to, rows.size())):
			var r: Dictionary = rows[i]
			var card := _row(i + 1, r, unit)
			SocialView.on_tap(card, func(): SocialView.open_profile(main, r))
			list.add_child(card)
	add_rows.call(3, FIRST_ROWS)
	if rows.size() > FIRST_ROWS:
		var more := Button.new()
		more.text = t("ONLINE_MORE") % (rows.size() - FIRST_ROWS)
		more.theme_type_variation = &"CreamButton"
		more.custom_minimum_size.y = 68
		m.add(more)
		more.pressed.connect(func():
			Sfx.play("click")
			add_rows.call(FIRST_ROWS, rows.size())
			more.queue_free())
	_account(m, main)
	if Online.admin:
		var lb := m.button(t("LEADER_BANS") % Online.ban_list().size(), func(): Sfx.play("click"); SocialView.open_bans(main), &"RedButton")
		lb.icon = Icons.get_icon("people", 32)
	_my_id(m)
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


## The player's own online id with a copy button (the leader adds theirs
## in the Firebase console; it also helps when someone asks for help).
static func _my_id(m: Modal) -> void:
	if Online.uid == "":
		return
	var row := m.row(8)
	var l := Views.label(t("MY_ID") % Online.uid, 17, Art.INK_SOFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := Button.new()
	b.text = t("INVITE_COPY")
	b.theme_type_variation = &"CreamButton"
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func():
		Sfx.play("click")
		DisplayServer.clipboard_set(Online.uid)
		b.text = t("COPIED"))
	row.add_child(b)


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


## The top three on pedestals: gold in the middle with a crown, silver on
## the left, bronze on the right. Tap one for the player's card.
static func _podium(rows: Array, unit: String, main: Node) -> Control:
	var card := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("3a6fd8"), 18, 4)
	sb.shadow = 0.0
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", sb)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, PODIUM_H)
	card.add_child(stack)
	var rays := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _podium_back(ci, s), Vector2(0, PODIUM_H))
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(rays)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 0)
	stack.add_child(h)
	for place in [2, 1, 3]:
		var col: Control
		if place <= rows.size():
			var r: Dictionary = rows[place - 1]
			col = ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _podium_col(ci, s, place, r, unit), Vector2(0, PODIUM_H))
			SocialView.on_tap(col, func(): SocialView.open_profile(main, r))
		else:
			col = ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _podium_col(ci, s, place, {}, unit), Vector2(0, PODIUM_H))
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_stretch_ratio = 1.15 if place == 1 else 1.0
		h.add_child(col)
	return card


const PODIUM_H := 268.0


## Sun rays and sparkles behind the winners.
static func _podium_back(ci: CanvasItem, s: Vector2) -> void:
	var c := Vector2(s.x / 2.0, 92.0)
	var n := 14
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := a0 + TAU / float(n) * 0.5
		var far := s.length()
		Art.flat(ci, PackedVector2Array([c, c + Vector2.from_angle(a0) * far, c + Vector2.from_angle(a1) * far]), Color(1, 1, 1, 0.08))
	Art.flat(ci, Art.circle_pts(c, 70.0, 28), Color(1, 0.95, 0.6, 0.16))
	for p in [Vector2(0.12, 0.16), Vector2(0.86, 0.12), Vector2(0.94, 0.42), Vector2(0.05, 0.47), Vector2(0.3, 0.07), Vector2(0.7, 0.3)]:
		Art.flat(ci, Art.star_pts(Vector2(p.x * s.x, p.y * s.y), 6.0, 2.2, 4), Color(1, 1, 0.85, 0.7))


## One winner: portrait (crown or medal), name, score and the pedestal.
static func _podium_col(ci: CanvasItem, s: Vector2, place: int, r: Dictionary, unit: String) -> void:
	var tall: float = {1: 86.0, 2: 62.0, 3: 46.0}[place]
	var fill: Color = {1: Art.GOLD, 2: Color("d9e2ef"), 3: Color("e8a06a")}[place]
	var w := minf(s.x - 6.0, 108.0)
	var base := Rect2(Vector2((s.x - w) / 2.0, s.y - tall - 6.0), Vector2(w, tall))
	Art.t_rect(ci, base, 10.0, fill, 3.0, 0.8)
	Art.flat(ci, Art.rrect_pts(Rect2(base.position + Vector2(6, 5), Vector2(w - 12, 7)), 3.5), Color(1, 1, 1, 0.45))
	Art.text(ci, Vector2(s.x / 2.0, base.position.y + minf(tall, 60.0) * 0.5 + 16.0), str(place), 34 if place == 1 else 28, Art.WHITE, 7)
	if r.is_empty():
		return
	var you := bool(r.get("you", false))
	var pr := 40.0 if place == 1 else 32.0
	var score_y := base.position.y - 12.0
	var name_y := score_y - 30.0
	var pc := Vector2(s.x / 2.0, name_y - 24.0 - pr)
	var look := Settings.avatar if you else _look(str(r.get("a", "")))
	Chars.portrait(ci, pc, pr, look, "happy", false, Color("ffd98a") if you else Color("bfe8ff"))
	Art.ring(ci, Art.circle_pts(pc, pr + 1.5, 32), fill, 4.0)
	if place == 1:
		_crown(ci, pc + Vector2(0, -pr - 6.0), 1.0)
	else:
		Art.t_circle(ci, pc + Vector2(pr * 0.72, pr * 0.72), 11.0, fill, 2.5, 0.6)
	var name := str(r.get("name", ""))
	if you:
		name = t("ONLINE_YOU")
	Art.text(ci, Vector2(s.x / 2.0, name_y), _fit(name, s.x - 6.0, 19), 19, Color("fff3a8") if you else Art.WHITE, 6)
	# The score on a dark pill.
	var txt := NumFormat.short(float(r.get("score", 0.0)))
	var tw := UiTheme.heavy_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var pw := minf(tw + 38.0, s.x - 4.0)
	var pill := Rect2(Vector2((s.x - pw) / 2.0, score_y - 19.0), Vector2(pw, 26.0))
	Art.t_rect(ci, pill, 13.0, Color("1d3f86"), 2.5, 0.0)
	var ic := pill.position + Vector2(14.0, 13.0)
	if unit == "star":
		Art.toon(ci, Art.star_pts(ic, 10.0, 4.5, 5), Art.GOLD, 2.0, 0.0)
	else:
		Art.coin(ci, ic, 9.0)
	Art.text(ci, Vector2(pill.position.x + 26.0 + (pw - 30.0) / 2.0, score_y), txt, 18, Art.WHITE, 0)


## A gold crown with three points and jewels.
static func _crown(ci: CanvasItem, c: Vector2, k: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * k)
	var pts := PackedVector2Array([Vector2(-20, 4), Vector2(-24, -16), Vector2(-10, -6), Vector2(0, -22),
		Vector2(10, -6), Vector2(24, -16), Vector2(20, 4)])
	Art.toon(ci, pts, Art.GOLD, 3.0, 0.6)
	for p in [Vector2(-24, -16), Vector2(0, -22), Vector2(24, -16)]:
		Art.t_circle(ci, p, 3.5, Color("ff7f8f"), 2.0, 0.0)
	Art.t_circle(ci, Vector2(0, -3), 3.5, Color("5fd0ff"), 2.0, 0.0)
	Art.pop(ci)


## The text cut with "…" to fit `w` pixels.
static func _fit(text: String, w: float, px: int) -> String:
	var f := UiTheme.heavy_font()
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
		return text
	var cut := text
	while cut.length() > 1 and f.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		cut = cut.left(cut.length() - 1)
	return cut + "…"


static func _row(place: int, row: Dictionary, unit := "coin") -> Control:
	var you: bool = row["you"]
	var card := Views.card(Color("ffe9a0") if you else (Color("fffaf0") if place % 2 == 0 else Color("eef5ff")))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	if you:
		sb.line = Art.GOLD_DARK.darkened(0.35)
		sb.line_w = 5.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	card.add_child(h)
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_rank(ci, s / 2.0, place),
			Vector2(44 if place < 100 else 58, 50)))
	var look := Settings.avatar if you else _look(str(row.get("a", "")))
	h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		Chars.portrait(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, look, "happy", false, Color("ffd98a") if you else Color("bfe8ff")),
			Vector2(48, 48)))
	var text := str(row["name"])
	if you:
		text = t("ONLINE_YOU") + " · " + text
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_theme_constant_override("separation", 0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := Views.label(text, 20, Art.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size.x = 60
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nv.add_child(name)
	var tier := Online.title() if you else int(Online.parse_profile(str(row.get("p", "")))["t"])
	if tier > 0:
		nv.add_child(SocialView.title_pill(tier, 14))
	h.add_child(nv)
	# The score on a pill.
	var pill := PanelContainer.new()
	var psb := UiTheme.panel_box(Color("dcebff") if not you else Color("fff6d0"), 12, 0)
	psb.shadow = 0.0
	psb.line_w = 2.0
	psb.content_margin_left = 4
	psb.content_margin_right = 8
	psb.content_margin_top = 0
	psb.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", psb)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 3)
	pill.add_child(ph)
	ph.add_child(Views.icon(unit, 26))
	var score := Views.label(NumFormat.short(float(row["score"])), 20, Color("1c5fa8") if not you else Art.INK, true)
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(score)
	h.add_child(pill)
	return card


## The place: a medal for the top three, a number on a round badge after.
static func _draw_rank(ci: CanvasItem, c: Vector2, place: int) -> void:
	if place <= 3:
		RivalsView._draw_place(ci, c, place)
		return
	var w := 34.0 if place < 100 else 48.0
	Art.t_rect(ci, Rect2(c - Vector2(w / 2.0, 15.0), Vector2(w, 30.0)), 15.0, Color("4a7fe0") if place <= 10 else Color("9fb4d6"), 2.5, 0.0)
	Art.text(ci, c + Vector2(0, 8), str(place), 19, Art.WHITE, 5)


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
		elif kind == "week" or kind == "season" or kind == "puzzle":
			FounderArt.podium(ci, s / 2.0 + Vector2(0, 14), 1.7, tt)
		elif kind in ["join", "inviter"]:
			FounderArt.letter(ci, s / 2.0 + Vector2(0, 6), 1.7, tt)
		else:
			_draw_ticket(ci, s / 2.0, tt), Vector2(0, 140), true))
	m.title({"week": t("THANKS_WEEK_TITLE"), "season": t("THANKS_SEASON_TITLE"), "puzzle": t("THANKS_PUZZLE_TITLE")}.get(kind, t("THANKS_TITLE")))
	match kind:
		"puzzle":
			m.text(t("THANKS_PUZZLE") % n if n > 0 else t("THANKS_PUZZLE_ALL"), 25, Art.GOLD_DARK.darkened(0.2))
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
	if not kind in ["week", "season", "puzzle"]:
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
