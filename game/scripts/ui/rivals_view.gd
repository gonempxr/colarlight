class_name RivalsView
extends RefCounted
## The Rivals League board (Rivals autoload): the player's weekly place
## among made-up sea characters, each a sea creature in a little costume
## inside a round frame. A line under the title and a "Computer" tag on
## every rival say plainly that they are computer characters, not players
## (kids rule). A line under the board says how close the next rival is.
## Last week's pearls are collected here.

## Per rival: frame colour and costume, in the pet's own coordinates.
## hat: a Chars hat (or "bicorne" / "mortarboard"), at/s/rot place it;
## glasses: eye centres; tusks: walrus whiskers and tusks at that point.
const LOOKS := {
	"octo": {"bg": Color("c9b8ff"), "hat": "bicorne", "at": Vector2(1, -18), "s": 0.62, "rot": -0.08, "ps": 1.38, "off": Vector2(0, 7)},
	"crab": {"bg": Color("ffd2a8"), "hat": "captain", "at": Vector2(0, -19), "s": 0.42, "rot": 0.0, "ps": 1.28, "off": Vector2(0, 10)},
	"walrus": {"bg": Color("bfe8ff"), "hat": "cap", "at": Vector2(9, -13), "s": 0.42, "rot": 0.12, "tusks": Vector2(9.2, -1.5), "ps": 1.45, "off": Vector2(5, 9)},
	"shark": {"bg": Color("b8f0e0"), "hat": "sailor", "at": Vector2(6, -6), "s": 0.4, "rot": 0.1, "ps": 1.45, "off": Vector2(5, 7)},
	"seahorse": {"bg": Color("ffd0e4"), "hat": "flower", "at": Vector2(-8, -12), "s": 0.55, "rot": 0.0, "ps": 1.6, "off": Vector2(-2, 6)},
	"puffer": {"bg": Color("ffe9a8"), "hat": "mortarboard", "at": Vector2(3, -15), "s": 0.5, "rot": -0.1, "glasses": [Vector2(4, -4), Vector2(11.5, -4)], "glass_r": 3.6, "ps": 1.55, "off": Vector2(2, 7)},
	"turtle": {"bg": Color("d4f5b8"), "hat": "beanie", "at": Vector2(19, -12), "s": 0.36, "rot": 0.1, "glasses": [Vector2(16.5, -6.3), Vector2(22.4, -6.3)], "glass_r": 3.0, "ps": 1.38, "off": Vector2(1, 8)},
}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func rival_name(id: String) -> String:
	return t("RIVAL_" + id.to_upper())


static func build(m: Modal, main: Node) -> void:
	m.title(t("RIVALS"))
	m.text(t("RIVALS_SUB_CPU"), 20, Art.INK_SOFT)
	if Rivals.reward_pending():
		var c := Views.card(Color("fff1c2"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		c.add_child(h)
		var trophy := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
			SideButton.draw_trophy(ci, s / 2.0, minf(s.x, s.y) * 0.36), Vector2(64, 64))
		h.add_child(trophy)
		var l := Views.label(t("RIVALS_LAST") % int(Rivals.last.get("place", 0)), 23, Art.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		var b := Button.new()
		b.theme_type_variation = &"GoldButton"
		b.text = "+%d" % int(Rivals.last.get("pearls", 0))
		b.icon = Icons.get_icon("pearl", 30)
		b.custom_minimum_size = Vector2(130, 64)
		b.pressed.connect(func():
			var from := b.get_global_rect().get_center()
			var n := Rivals.claim()
			if n > 0:
				main.celebrate({"pearls": n}, from)
			m.rebuild())
		h.add_child(b)
		m.add(c)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var rows: Array = Rivals.board()
	for i in rows.size():
		list.add_child(_row(i + 1, rows[i]))
	m.add(list)
	var goal := chase_text(rows)
	if goal != "":
		var gc := Views.card(Color("dff3ff"))
		var gl := Views.label(goal, 21, Color("1c5f8f"), true)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.custom_minimum_size.x = 200
		gc.add_child(gl)
		m.add(gc)
	m.text(t("RIVALS_HOW"), 19, Art.INK_SOFT)
	var r: Array[int] = Rivals.REWARDS
	m.text(t("RIVALS_REWARDS") % [r[0], r[1], r[2]], 19, Art.INK_SOFT)


## The motivation line: how many stars to pass the rival just above, or a
## cheer when the player leads ("" when there is no board).
static func chase_text(rows: Array) -> String:
	for i in rows.size():
		if not rows[i]["you"]:
			continue
		if i == 0:
			return t("RIVALS_TOP")
		var above: Dictionary = rows[i - 1]
		var gap := maxf(1.0, float(above["score"]) - float(rows[i]["score"]) + 1.0)
		return t("RIVALS_GAP") % [rival_name(str(above["id"])), NumFormat.short(gap)]
	return ""


static func _row(place: int, row: Dictionary) -> Control:
	var you: bool = row["you"]
	var card := Views.card(Color("ffe9a0") if you else Color("fffaf0"))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	if you:
		sb.line = Art.GOLD_DARK.darkened(0.35)
		sb.line_w = 5.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var medal := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_place(ci, s / 2.0, place), Vector2(46, 64))
	h.add_child(medal)
	var id: String = row["id"]
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		var c := s / 2.0
		var rr := minf(s.x, s.y) / 2.0 - 2.0
		if you:
			Chars.portrait(ci, c, rr, Settings.avatar, "happy", false, Color("ffd98a"))
		else:
			portrait(ci, c, rr, id), Vector2(64, 64))
	h.add_child(pic)
	var name := Views.label(t("RIVALS_YOU") + " · " + str(Profiles.find(Profiles.current_id).get("name", "")) if you else rival_name(id), 22, Art.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.custom_minimum_size.x = 60
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if you:
		h.add_child(name)
	else:
		# Rivals: the name with a small "Computer" tag under it.
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(name)
		col.add_child(_cpu_tag())
		h.add_child(col)
	var score := Views.label("★ " + NumFormat.short(float(row["score"])), 23, Color("1c7fb8") if not you else Art.INK, true)
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(score)
	return card


## Small grey pill with a screen icon and "Computer".
static func _cpu_tag() -> Control:
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", 0)
	var pill := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("e3e7f2"), 10, 0)
	sb.shadow = 0.0
	sb.line_w = 2.0
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	var icon := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_screen(ci, s / 2.0), Vector2(18, 18))
	row.add_child(icon)
	var l := Views.label(t("RIVALS_CPU"), 15, Color("5a6280"), true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	tag.add_child(pill)
	return tag


## A tiny computer screen on a stand.
static func _draw_screen(ci: CanvasItem, c: Vector2) -> void:
	Art.t_rect(ci, Rect2(c + Vector2(-7, -6), Vector2(14, 10)), 2.0, Color("7fc8e8"), 1.6, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(c + Vector2(-2, 4), Vector2(4, 3)), 0.5), Art.INK)
	Art.flat(ci, Art.rrect_pts(Rect2(c + Vector2(-5, 6.5), Vector2(10, 2)), 1.0), Art.INK)


## Places 1-3 get a gold, silver or bronze medal; the rest a plain number.
static func _draw_place(ci: CanvasItem, c: Vector2, place: int) -> void:
	if place <= 3:
		var cols := [Art.GOLD, Color("d9e2ef"), Color("e8a06a")]
		Art.toon(ci, PackedVector2Array([c + Vector2(-9, -24), c + Vector2(-2, -24), c + Vector2(3, -8), c + Vector2(-4, -8)]), Art.BLUE, 2.5, 0.0)
		Art.toon(ci, PackedVector2Array([c + Vector2(9, -24), c + Vector2(2, -24), c + Vector2(-3, -8), c + Vector2(4, -8)]), Art.RED, 2.5, 0.0)
		Art.t_circle(ci, c + Vector2(0, 4), 15.0, cols[place - 1], 3.0, 0.6)
		Art.text(ci, c + Vector2(0, 11), str(place), 19, Art.WHITE, 5)
	else:
		Art.text(ci, c + Vector2(0, 9), str(place), 26, Art.INK_SOFT, 0)


## A rival in a round frame, like the player portraits.
static func portrait(ci: CanvasItem, center: Vector2, r: float, id: String) -> void:
	var look: Dictionary = LOOKS.get(id, LOOKS["crab"])
	var art := ""
	for rv in Rivals.RIVALS:
		if rv["id"] == id:
			art = rv["art"]
	Art.push(ci, center, 0.0, Vector2.ONE * (r / 50.0))
	var disc := Art.circle_pts(Vector2.ZERO, 46.0, 32)
	Art.toon(ci, disc, look["bg"], 4.0, 0.0)
	Art.flat(ci, Art.clipped(Art.circle_pts(Vector2(-10, -18), 30.0, 28), disc), Color(1, 1, 1, 0.2))
	# The creature with its hat, sized and moved to sit inside the ring.
	var ps: float = look.get("ps", 1.5)
	Art.push(ci, look.get("off", Vector2.ZERO), 0.0, Vector2(ps, ps))
	draw_rival(ci, id, art, look, 0.0)
	Art.pop(ci)
	Art.arc_c(ci, Vector2.ZERO, 46.0, 0, TAU, 32, Art.INK, 4.0)
	Art.pop(ci)


## The creature with its costume, in pet coordinates (~44 px wide).
static func draw_rival(ci: CanvasItem, id: String, art: String, look: Dictionary, tt: float) -> void:
	PetArt.draw(ci, art, tt, 1.0, false)
	# PetArt bobs its pets; the costume follows the same bob.
	var sd := float(maxi(PetArt.IDS.find(art), 0)) * 0.61
	Art.push(ci, Vector2(0, sin(tt * 2.4 + sd) * 1.5))
	if look.has("tusks"):
		_tusks(ci, look["tusks"])
	if look.has("glasses"):
		var gr: float = look.get("glass_r", 3.4)
		var g: Array = look["glasses"]
		for p: Vector2 in g:
			Art.arc(ci, p, gr, 0.0, TAU, 14, Art.INK, 1.4)
			Art.flat(ci, Art.circle_pts(p, gr - 0.6, 12), Color(1, 1, 1, 0.25))
		Art.line(ci, g[0] + Vector2(gr, 0), g[1] - Vector2(gr, 0), Art.INK, 1.3)
	Art.push(ci, look["at"], look["rot"], Vector2.ONE * float(look["s"]))
	match str(look["hat"]):
		"bicorne":
			_bicorne(ci)
		"mortarboard":
			_mortarboard(ci)
		var h:
			Chars._hat(ci, h)
	Art.pop(ci)
	Art.pop(ci)


## Walrus: a bushy moustache and two small tusks under the nose.
static func _tusks(ci: CanvasItem, at: Vector2) -> void:
	for sx: float in [-1.0, 1.0]:
		var base := at + Vector2(2.2 * sx, 2.0)
		Art.toon(ci, PackedVector2Array([base + Vector2(-1.1, 0), base + Vector2(1.1, 0), base + Vector2(0.4 * sx, 6.5)]), Color("fffaf0"), 1.2, 0.0)
	Art.toon(ci, Art.union([Art.ellipse_pts(at + Vector2(-2.6, 0.6), Vector2(3.2, 2.0), 12), Art.ellipse_pts(at + Vector2(2.6, 0.6), Vector2(3.2, 2.0), 12)]), Color("8d7a6a"), 1.3, 0.3)
	Art.flat(ci, Art.ellipse_pts(at + Vector2(0, -1.2), Vector2(1.7, 1.2), 8), Art.INK)


## Admiral's two-pointed hat with gold trim and a cockade.
static func _bicorne(ci: CanvasItem) -> void:
	var pts := Art.smooth_pts(PackedVector2Array([Vector2(-34, 2), Vector2(-20, -10), Vector2(-8, -24), Vector2(8, -24),
			Vector2(20, -10), Vector2(34, 2), Vector2(0, -4)]), 3)
	Art.toon(ci, pts, Color("2e3a6e"), 2.5, 0.5)
	Art.polyline(ci, Art.smooth_pts(PackedVector2Array([Vector2(-30, -1), Vector2(-12, -8), Vector2(12, -8), Vector2(30, -1)]), 3), Art.GOLD, 2.5)
	Art.t_circle(ci, Vector2(0, -12), 5.0, Art.RED, 2.0, 0.0)
	Art.t_circle(ci, Vector2(0, -12), 2.2, Art.GOLD, 0.0, 0.0)


## Professor's square cap with a tassel.
static func _mortarboard(ci: CanvasItem) -> void:
	Art.t_rect(ci, Rect2(-13, -12, 26, 12), 3, Color("3a3350"), 2.5, 0.3)
	Art.toon(ci, PackedVector2Array([Vector2(-30, -16), Vector2(0, -26), Vector2(30, -16), Vector2(0, -6)]), Color("4a4266"), 2.5, 0.4)
	Art.line(ci, Vector2(0, -16), Vector2(20, -12), Art.GOLD, 2.0)
	Art.line(ci, Vector2(20, -12), Vector2(21, 0), Art.GOLD, 2.0)
	Art.t_circle(ci, Vector2(21, 1), 2.5, Art.GOLD, 1.5, 0.0)
	Art.t_circle(ci, Vector2(0, -16), 2.4, Art.GOLD, 1.2, 0.0)
