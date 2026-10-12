class_name PassView
extends RefCounted
## Entry points of the Sea Pass (its screen is PassScreen): open it, the
## "how to get XP" dialog and the side button's picture.


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func open(main: Node) -> void:
	main.open_pass()


## How XP is earned, and the two tracks explained.
static func how(m: Modal) -> void:
	m.title(t("BP_HOW"))
	m.banner(UiTheme.BANNER_PURPLE)
	m.text(t("BP_FREE"), 19, Art.GREEN_DARK)
	var card := Views.card(Color("fffaf0"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	for k in ["challenge", "daily", "quest", "badge", "chest", "star", "fish", "minute"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Views.icon({"challenge": "star", "daily": "gift", "quest": "quests", "badge": "star", "chest": "chest",
			"star": "puzzle", "fish": "fishing", "minute": "bolt"}[k], 30))
		var l := Views.label(t("BP_XP_" + k.to_upper()), 19, Art.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
		row.add_child(l)
		var xl := Views.label("+%d XP" % int(BattlePass.XP[k]), 19, Color("1c7fb8"), true)
		xl.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(xl)
		v.add_child(row)
	m.add(card)
	m.text(t("BP_TRACKS") % BattlePass.BONUS_NEED, 18, Art.INK_SOFT)
	m.button(t("THANKS_OK"), func(): Sfx.play("click"); m.close(), &"BlueButton")


## The side button's picture: a ticket with a star.
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
