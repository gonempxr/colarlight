class_name StarView
extends RefCounted
## World stars, the endgame (GameState.get_star): the dialog that shows the
## stars of every world, the bonus they give, this world's checklist and
## price, the "Get a star" button (asked twice: the world starts over) and
## the gifts for stars owned in all. Opened from the map, the lightbulb and
## the toast when a world is ready.

const GOLD := Color("ffbf2e")
const GOLD_DARK := Color("b8730a")


static func t(key: String) -> String:
	return TranslationServer.translate(key)


## Gift items for stars owned in all, in Balance.STAR_GIFTS order.
static func gifts() -> Array:
	var out := []
	for n in Balance.STAR_GIFTS:
		for c in Content.COSMETICS:
			if c.get("goal", "") == "stars_%d" % n:
				out.append([n, c])
	return out


static func build(m: Modal, main: Node, confirm: bool = false) -> void:
	var gs := GameState
	m.title(t("NIGHTMARE_TITLE") if Balance.saga else t("STAR_TITLE"))
	m.banner(UiTheme.BANNER_PURPLE if Balance.saga else UiTheme.BANNER_GOLD)
	if Balance.saga:
		var nm := m.text(t("NIGHTMARE_TEXT") if gs.saga_done else t("NIGHTMARE_LOCKED"), 20, Color("6a3cc0"))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not gs.stars_unlocked():
		m.text(t("STAR_LOCKED"), 22, Art.INK_SOFT)
		m.button(t("THANKS_OK"), func(): Sfx.play("click"); m.close(), &"BlueButton")
		return
	m.text(t("STAR_INTRO") % int(round(Balance.STAR_BONUS * 100.0)), 20, Art.INK_SOFT)
	m.add(_worlds_row())
	var total: int = gs.total_stars()
	var bonus := Views.pill(t("STAR_BONUS_NOW") % int(round((gs.star_mult() - 1.0) * 100.0)), Color("2fae5a"), Art.WHITE, 22)
	bonus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.add(bonus)
	# This world: the checklist, the price and the button.
	var l: int = gs.location
	var n: int = gs.stars_of(l)
	var card := Views.card(Color("fff6dc"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := Views.label(t("STAR_NEXT") % [WorldLook.name_of(l), n + 1], 26, Art.INK, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	if not gs.location_ready():
		v.add_child(_centered(t("STAR_GOALS_FIRST"), 20))
		for g in gs.location_goals():
			v.add_child(_goal_row(g))
	var cost: float = gs.star_cost()
	var have: float = gs.coins + gs.vault
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 8)
	var pl := Views.label(t("STAR_PRICE"), 22, Art.INK, true)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	pl.custom_minimum_size.x = 0
	price.add_child(pl)
	price.add_child(Views.icon("coin", 32))
	var pv := Views.label(NumFormat.short(cost), 28, Art.INK if have >= cost else Color("c0392b"), true)
	pv.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.add_child(pv)
	v.add_child(price)
	if have < cost:
		v.add_child(_centered(t("MAP_YOU_HAVE") % NumFormat.short(have), 19))
	var gain := _centered(t("STAR_GAIN") % [Balance.star_pearls(n), int(round(Balance.STAR_BONUS * 100.0))], 19)
	gain.add_theme_color_override("font_color", Art.GREEN_DARK)
	v.add_child(gain)
	m.add(card)
	if confirm and gs.can_get_star():
		m.text(t("STAR_CONFIRM") % WorldLook.name_of(l), 22, Color("c0392b"))
		var row := m.row(14)
		var no := Button.new()
		no.theme_type_variation = &"CreamButton"
		no.text = t("MAP_NO")
		no.custom_minimum_size = Vector2(0, 80)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		no.pressed.connect(func():
			Sfx.play("click")
			m.open(func(mm): build(mm, main, false)))
		row.add_child(no)
		var yes := Button.new()
		yes.theme_type_variation = &"GoldButton"
		yes.text = t("STAR_YES")
		yes.custom_minimum_size = Vector2(0, 80)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.size_flags_stretch_ratio = 1.4
		yes.pressed.connect(func():
			if GameState.get_star():
				Sfx.play("prestige")
				m.close()
				if main and main.has_method("on_star_gained"):
					main.on_star_gained())
		row.add_child(yes)
	else:
		var go := m.button("★ " + t("STAR_GET"), func():
			Sfx.play("click")
			m.open(func(mm): build(mm, main, true)), &"GoldButton")
		go.add_theme_font_size_override("font_size", 30)
		go.disabled = not gs.can_get_star()
	m.text(t("STAR_OTHER_WORLDS"), 18, Art.INK_SOFT)
	# Gifts for stars in all.
	m.add(_gifts_row(total))


static func _centered(text: String, px: int) -> Label:
	var l := Views.label(text, px, Art.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Every world with its island and its stars.
static func _worlds_row() -> Control:
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 4)
	for l in range(0, Balance.last_location() + 1):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var w := WorldLook.world_of(l)
		var here: bool = l == GameState.location
		var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			if here:
				Art.glow(ci, s / 2.0, s.x * 0.55, Color(GOLD, 0.45))
			var k := minf(s.x, s.y) / 470.0
			Art.push(ci, s / 2.0 + Vector2(0, 4), 0.0, Vector2(k, k))
			MapArt.island(ci, w, MapArt.CURRENT if here else MapArt.DONE, tt * 0.5)
			Art.pop(ci), Vector2(84, 70))
		pic.custom_minimum_size = Vector2(64, 60)
		pic.tooltip_text = WorldLook.name_of(l)
		cell.add_child(pic)
		var st := Views.label("★ %d" % GameState.stars_of(l), 24, GOLD_DARK, true)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		st.custom_minimum_size.x = 0
		cell.add_child(st)
		grid.add_child(cell)
	return grid


static func _goal_row(g: Dictionary) -> Control:
	var have := int(g["have"])
	var need := int(g["need"])
	var ok := have >= need
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Views.icon("check" if ok else "star_off", 26))
	var l := Views.label(t("MAP_GOAL_" + String(g["id"]).to_upper()), 20, Art.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var c := Views.label("%d/%d" % [mini(have, need), need], 20, Art.GREEN_DARK if ok else Art.INK, true)
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	c.custom_minimum_size.x = 0
	h.add_child(c)
	return h


## Gifts for stars owned in all: the item, how many stars, done or not.
static func _gifts_row(total: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head := Views.label(t("STAR_GIFTS"), 22, Art.INK, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for g in gifts():
		var need: int = g[0]
		var c: Dictionary = g[1]
		var got := total >= need or Progress.is_owned(str(c["id"]))
		var card := Views.card(Color("dff7d2") if got else Color("fffaf0"))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		card.add_child(cv)
		var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			Wardrobe._draw_item(ci, c, s, tt), Vector2(80, 64))
		pic.custom_minimum_size = Vector2(70, 58)
		pic.modulate = Color.WHITE if got else Color(1, 1, 1, 0.55)
		cv.add_child(pic)
		var lbl := Views.label(("✓ " if got else "") + "★ %d" % need, 20, Art.GREEN_DARK if got else GOLD_DARK, true)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.custom_minimum_size.x = 0
		cv.add_child(lbl)
		grid.add_child(card)
	v.add_child(grid)
	return v
