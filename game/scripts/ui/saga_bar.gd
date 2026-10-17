class_name SagaBar
extends Control
## The saga's progress strip (Top League games), under the room tabs: the
## act, the world's five guards as dots on a line (beaten: gold with a
## tick, the next one glowing, the rest dark) and the Murk meter. A tap
## opens the saga's page (build()): acts, guards, what the Murk does, the
## story again.

signal pressed

const H := 64.0
const FILL := Color("2a1250")
const RIM := Color("9b6cff")
const GOLD := Color("ffd45a")

var _sig := []


static func t(k: String) -> String:
	return TranslationServer.translate(k)


## The guards of the current saga world: [[site key, boss id], ...] in order.
static func guards() -> Array:
	var g: Dictionary = MineBoss.GUARDS.get(GameState.world_id(), {})
	var idx := g.keys()
	idx.sort()
	var out := []
	for i in idx:
		out.append(["d%d" % int(i), str(g[i])])
	return out


const ROMAN: Array[String] = ["I", "II", "III"]


## The act being played (0 = act I): the saga's location.
static func act() -> int:
	return clampi(int(GameState.location), 0, ROMAN.size() - 1)


static func beaten_count() -> int:
	var n := 0
	for g in guards():
		if GameState.bosses.has(g[0]):
			n += 1
	return n


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, H)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			pressed.emit())


func _process(_d: float) -> void:
	if not is_visible_in_tree():
		return
	var sig := [MurkVeil.shown(GameState.murk), GameState.bosses.size(), size, TranslationServer.get_locale(),
		int(Tides.left(GameState.now())) if GameState.has_tides() else -1]
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _draw() -> void:
	draw_bar(self, size)


static func draw_bar(ci: CanvasItem, s: Vector2) -> void:
	var r := Rect2(Vector2(6, 3), s - Vector2(12, 6))
	Art.t_rect(ci, r, r.size.y / 2.0, FILL, 3.0, 0.0)
	Art.ring(ci, Art.rrect_pts(r.grow(-4.0), r.size.y / 2.0 - 4.0), Color(RIM, 0.55), 2.0)
	var cy := r.position.y + r.size.y / 2.0
	# The act.
	Art.text(ci, Vector2(r.position.x + 58, cy + 9), t("SAGA_ACT") % ROMAN[act()], 26, GOLD, 6)
	# The Murk on the right: an eye and a share.
	var m := MurkVeil.shown(GameState.murk)
	var mx := r.end.x - 100.0
	var col := Color("b6ff6a").lerp(Color("ff5ad0"), m)
	MurkVeil.eye(ci, Vector2(mx, cy), 14.0, false, false)
	Art.text(ci, Vector2(mx + 22, cy + 9), "%d%%" % roundi(m * 100.0), 26, col, 6, false)
	# The guards on a line.
	var gs := guards()
	if gs.is_empty():
		return
	var x0 := r.position.x + 130.0
	# Atlantis' tide: which half and how long it lasts.
	if GameState.has_tides():
		var now := GameState.now()
		var up := Tides.high(now)
		var tr := Rect2(Vector2(x0 - 12.0, cy - 17.0), Vector2(150.0, 34.0))
		Art.t_rect(ci, tr, 17.0, Color("2a8ed8") if up else Color("c8a04a"), 2.5, 0.0)
		var l := int(Tides.left(now))
		Art.text(ci, Vector2(tr.position.x + tr.size.x / 2.0, cy + 8), t("TIDE_HIGH_BAR" if up else "TIDE_LOW_BAR") % ("%d:%02d" % [l / 60, l % 60]), 20, Art.WHITE, 5)
		x0 += 160.0
	var x1 := mx - 40.0
	var step := (x1 - x0) / maxf(1.0, gs.size() - 1)
	Art.line(ci, Vector2(x0, cy), Vector2(x1, cy), Color(RIM, 0.6), 3.0)
	var next := true
	for i in gs.size():
		var c := Vector2(x0 + step * i, cy)
		var last := i == gs.size() - 1
		var rad := 20.0 if last else 16.0
		if GameState.bosses.has(gs[i][0]):
			Art.t_circle(ci, c, rad, GOLD, 2.5, 0.4)
			Art.polyline(ci, PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(8, -6)]), Art.INK, 3.5)
			if beaten_count() == gs.size() and last:
				Art.glow(ci, c, 26.0, Color(GOLD, 0.4))
		elif next:
			next = false
			Art.glow(ci, c, 32.0, Color("c06cff", 0.55))
			Art.t_circle(ci, c, rad, Color("8a4cf0"), 2.5, 0.4)
			Art.text(ci, c + Vector2(0, 9), "!", 26, Art.WHITE, 5)
		else:
			Art.t_circle(ci, c, rad, Color("3a2366"), 2.5, 0.0)
			Art.dot(ci, c, 4.0, Color(RIM, 0.7))
		if last:
			Art.toon(ci, Art.star_pts(c + Vector2(0, -rad - 2), 10.0, 4.5, 5), GOLD, 2.0, 0.0)


# --- The saga's page ---------------------------------------------------------------

static func build(m: Modal, main: Node) -> void:
	m.title(t("SAGA_TITLE"))
	m.banner(UiTheme.BANNER_PURPLE)
	var acts := [["I", "SAGA_ACT1"], ["II", "SAGA_ACT2"], ["III", "SAGA_ACT3"]]
	for i in acts.size():
		var a: Array = acts[i]
		# [roman, name, now?]; done acts read "beaten".
		a.append(i == act())
		var card := Views.card(Color("efe6ff") if a[2] else Color("e2dcec"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var act := Views.label(t("SAGA_ACT") % a[0], 24, Color("6a3cc0"), true)
		act.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(act)
		var name := Views.label(t(a[1]), 24, Art.INK if a[2] else Art.INK_SOFT, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		if i < act():
			row.add_child(Views.pill(t("SAGA_BEATEN"), Color("2fae5a")))
		else:
			row.add_child(Views.pill(t("SAGA_NOW") if a[2] else t("SAGA_LATER"), Color("8a4cf0") if a[2] else Color("9aa3bd")))
		card.add_child(row)
		m.add(card)
	# The guards.
	var next := true
	for g in guards():
		var card := Views.card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var id: String = g[1]
		row.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): BossArt.portrait(ci, id, s / 2.0, 30.0, tt), Vector2(64, 64)))
		var name := Views.label(t(MineBoss.name_key(id)), 24, Art.INK, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var state := "SAGA_LOCKED"
		var col := Color("9aa3bd")
		if GameState.bosses.has(g[0]):
			state = "SAGA_BEATEN"
			col = Color("2fae5a")
		elif next:
			next = false
			state = "SAGA_NEXT"
			col = Color("8a4cf0")
		var p := Views.pill(t(state), col)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(p)
		card.add_child(row)
		m.add(card)
	if GameState.location >= 2:
		_world_boss(m, main)
	# Atlantis' tides.
	if GameState.has_tides():
		var tc := Views.card(Color("e2f2ff"))
		var tl := Views.label(t("TIDE_TEXT") % [int(Tides.CYCLE / 60.0), int(Tides.MULT), int(Tides.MULT)], 21, Art.INK)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tc.add_child(tl)
		m.add(tc)
	# The Murk.
	var mk := Views.card(Color("f1e8ff"))
	var col := VBoxContainer.new()
	col.add_child(Views.label(t("MURK_TITLE") % roundi(MurkVeil.shown(GameState.murk) * 100.0), 26, Color("6a3cc0"), true))
	var txt := Views.label(t("MURK_TEXT") % roundi(Murk.LOSS * 100.0), 21, Art.INK)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(txt)
	mk.add_child(col)
	m.add(mk)
	m.button(t("RELIC_BTN") % GameState.relics.size(), func(): m.open(func(mm): RelicView.build(mm, main)), &"GoldButton")
	m.button(t("SAGA_STORY_BTN"), func():
		m.close()
		main.open_story("intro"), &"PurpleButton")


## The league's world boss (WorldBoss) on the saga page: the league's
## progress, my taps, the top divers, Fight and the reward. The board comes
## from Online (fetched again after BOARD_SEC).
static var _wb := {}
static var _wb_at := -1000.0
const BOARD_SEC := 30.0


static func _world_boss(m: Modal, main: Node) -> void:
	var league := OnlineRules.league_id(GameState.now())
	var now := Time.get_ticks_msec() / 1000.0
	if Online.available() and now - _wb_at > BOARD_SEC:
		_wb_at = now
		Online.wb_board(league, func(r: Dictionary):
			_wb = r
			if m.is_open():
				m.rebuild())
	var card := Views.card(Color("dff5e4"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): BossArt.portrait(ci, "ancient_one", s / 2.0, 30.0, tt), Vector2(64, 64)))
	var name := Views.label(t("WB_TITLE"), 24, Color("1e6a3a"), true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name)
	col.add_child(head)
	var total := float(_wb.get("total", 0.0))
	col.add_child(Views.bar(minf(total, WorldBoss.HP), WorldBoss.HP, t("WB_LEAGUE") % [NumFormat.short(total), NumFormat.short(WorldBoss.HP)]))
	var mine := float(GameState.wb["dmg"]) if int(GameState.wb["l"]) == league else 0.0
	var info := Views.label(t("WB_TEXT") % [roundi(mine), WorldBoss.PEARLS], 20, Art.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	var rows: Array = _wb.get("rows", [])
	for i in mini(5, rows.size()):
		col.add_child(Views.label("%d. %s  %s" % [i + 1, rows[i]["name"], NumFormat.short(rows[i]["dmg"])], 19, Art.INK_SOFT))
	if not Online.available():
		col.add_child(Views.label(t("WB_OFFLINE"), 19, Color("b04040")))
	elif total >= WorldBoss.HP and mine > 0.0 and not GameState.wb["claimed"]:
		var b := Button.new()
		b.text = t("WB_CLAIM") % WorldBoss.PEARLS
		b.theme_type_variation = &"GoldButton"
		b.custom_minimum_size.y = 64
		b.pressed.connect(func():
			GameState.wb_claim(total, league)
			m.rebuild())
		col.add_child(b)
	elif total < WorldBoss.HP:
		var b := Button.new()
		b.text = t("WB_FIGHT")
		b.theme_type_variation = &"PurpleButton"
		b.custom_minimum_size.y = 64
		b.pressed.connect(func(): main.open_world_boss())
		col.add_child(b)
	card.add_child(col)
	m.add(card)
