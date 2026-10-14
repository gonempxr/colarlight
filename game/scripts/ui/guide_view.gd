class_name GuideView
extends RefCounted
## "Everything in the game": one list of every feature with a picture, a
## line on what it is for, and a button that opens it (or when it opens).
## New, never-opened things wear a red "NEW" pill. Reached from the
## lightbulb, the profile and the settings; "What's new" (once after an
## update) shows only the new ones.
##
## Seen marks live in Progress.stats as "g_<id>" (per profile).

## Bump when "What's new" should show again (with new WHATS_NEW ids).
const NEWS_VERSION := 3
const WHATS_NEW := ["pass", "challenge", "ach", "clubs", "season", "puzzle_board", "friends", "titles", "jungle", "stars", "board"]
## What the "What's new" dialog of this NEWS_VERSION lists.
const NEWS_NOW := ["jungle", "stars", "board", "pass"]
## The update's notes shown on top of "What's new" (NEWS_NOTE_<n>).
const NEWS_NOTES := 6
## Long enough in the game to be told about news (new players learn as they go).
const NEWS_AFTER_SEC := 300.0

static var section := ""


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func mark(id: String) -> void:
	if int(Progress.stats.get("g_" + id, 0)) == 0:
		Progress.stats["g_" + id] = 1


static func seen(id: String) -> bool:
	return int(Progress.stats.get("g_" + id, 0)) > 0


## Every entry: [id, icon, group, available, opener (Callable or null)].
## group: "base" (the business), "fun" (things to do), "online" (with others).
static func entries(main: Node) -> Array:
	var online := Online.present()
	var list := [
		["mine", "helmet", "base", true, func(): main.show_room(0)],
		["managers", "people", "base", true, func(): main.show_room(0)],
		["factory", "gear", "base", true, func(): main.show_room(1)],
		["office", "coin", "base", true, func(): main.show_room(2)],
		["evo", "helmet", "base", main._evo_shown(), func(): main.open_evolution()],
		["map", "play", "base", true, func(): main.open_map()],
		["jungle", "play", "base", true, func(): main.open_map()],
		["stars", "star", "base", GameState.stars_unlocked(), func(): main.open_stars()],
		["hint", "bolt", "base", true, null],
		["daily", "gift", "fun", Progress.has_feature("daily"), func(): main.open_feature("daily")],
		["streak", "bolt", "fun", Progress.has_feature("daily"), func(): main.open_streak()],
		["chests", "chest", "fun", Progress.has_feature("chests"), null],
		["quests", "quests", "fun", Progress.has_feature("quests"), func(): main.open_feature("quests")],
		["challenge", "star", "fun", Progress.has_feature("quests"), func(): main.open_feature("quests")],
		["puzzle", "puzzle", "fun", Progress.has_feature("puzzle"), func(): main.open_feature("puzzle")],
		["museum", "museum", "fun", Progress.has_feature("museum"), func(): main.open_feature("museum")],
		["fishing", "fishing", "fun", Progress.has_feature("fishing"), func(): main.open_feature("fishing")],
		["shop", "wardrobe", "fun", Progress.has_feature("shop"), func(): main.open_feature("shop")],
		["rivals", "star", "fun", Progress.has_feature("quests"), func(): main.open_rivals()],
		["ach", "star", "fun", true, func(): SocialView.open_achievements(main)],
		["pass", "gift", "fun", Progress.has_feature("quests"), func(): PassView.open(main)],
	]
	if online:
		list.append_array([
			["board", "star", "online", true, func(): OnlineView.open_board(main, "week")],
			["season", "star", "online", true, func(): OnlineView.open_board(main, "month")],
			["puzzle_board", "puzzle", "online", true, func(): OnlineView.open_board(main, "puzzle")],
			["titles", "star", "online", true, func(): OnlineView.open_board(main, "week")],
			["clubs", "people", "online", true, func(): SocialView.open_clubs(main)],
			["friends", "people", "online", true, func(): OnlineView.open_invite(main)],
			["x2day", "coin", "online", true, null],
			["promo", "gift", "online", true, func(): OnlineView.open_promo(main)],
		])
	return list


static func open(main: Node, only_new := false) -> void:
	main._modal.open(func(m): build(m, main, only_new))


## What's new, once per NEWS_VERSION for players who have played a while.
static func news_due() -> bool:
	return int(Progress.stats.get("news_v", 0)) < NEWS_VERSION and float(Progress.stats.get("play_time", 0.0)) >= NEWS_AFTER_SEC


static func build(m: Modal, main: Node, only_new := false) -> void:
	if only_new:
		Progress.stats["news_v"] = NEWS_VERSION
		m.text(t("NEW_FEATURE"), 24, Color("d8363c"))
		m.title(t("GUIDE_NEWS_TITLE"))
		m.add(_notes())
		m.text(t("GUIDE_NEWS_HINT"), 20, Art.INK_SOFT)
	else:
		m.title(t("GUIDE_TITLE"))
		m.text(t("GUIDE_INTRO"), 20, Art.INK_SOFT)
	var all := entries(main)
	for group in ["base", "fun", "online"]:
		var rows := all.filter(func(e): return e[2] == group and (not only_new or e[0] in NEWS_NOW))
		if rows.is_empty():
			continue
		if not only_new:
			var head := Views.label(t("GUIDE_GROUP_" + group.to_upper()), 24, Color("6a3fc0"), true)
			head.custom_minimum_size.x = 200
			m.add(head)
		for e in rows:
			m.add(_entry(m, e))
	m.button(t("THANKS_OK"), func(): Sfx.play("click"); m.close(), &"BlueButton")


## The update's notes: a short list on a gold card.
static func _notes() -> Control:
	var c := Views.card(Color("fff4d6"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	for i in range(1, NEWS_NOTES + 1):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := Views.icon("star", 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		var l := Views.label(t("NEWS_NOTE_%d" % i), 19, Art.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
		h.add_child(l)
		v.add_child(h)
	return c


static func _entry(m: Modal, e: Array) -> Control:
	var id := str(e[0])
	var avail: bool = e[3]
	var go = e[4]
	var fresh := avail and go != null and not seen(id) and (id in WHATS_NEW or Progress.fresh.has(id))
	var c := Views.card(Color("fff4d6") if fresh else (Color("fffaf0") if avail else Color("eef0f4")))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	var ic := Views.icon(id if id in ["fishing"] else str(e[1]), 48) if avail else Views.icon("lock", 44)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var name := Views.label(t("GUIDE_" + id.to_upper()), 21, Art.INK if avail else Art.INK_SOFT, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(name)
	if fresh:
		top.add_child(Views.pill(t("NEW"), Color("e0483e"), Art.WHITE, 15))
	v.add_child(top)
	var d := Views.label(t("GUIDE_%s_D" % id.to_upper()) if avail else t("GUIDE_%s_LOCK" % id.to_upper()), 17, Art.INK_SOFT)
	d.custom_minimum_size.x = 140
	v.add_child(d)
	if avail and go != null:
		var b := Button.new()
		b.text = t("OPEN_IT")
		b.theme_type_variation = &"GoldButton" if fresh else &"CreamButton"
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 19)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var open_it: Callable = go
		b.pressed.connect(func():
			Sfx.play("click")
			mark(id)
			m.close()
			open_it.call())
		h.add_child(b)
	return c
