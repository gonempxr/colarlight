class_name RelicView
extends RefCounted
## The relics screen (saga loot): the party's worn relics (3 per hero), the
## bag, melting into shards and rerolling properties. Also the drop card shown
## after a won boss fight.

## The bag relic picked to put on a hero (index into GameState.relics, -1: none).
static var _pick := -1


static func t(k: String) -> String:
	return TranslationServer.translate(k)


## A relic's look: a rarity-coloured gem in a gold setting with its kind's mark.
static func draw_icon(ci: CanvasItem, c: Vector2, r: float, rel: Dictionary, tt: float = 0.0) -> void:
	var rar := int(rel.get("rarity", 0))
	var col: Color = Relics.RARITY_COLORS[rar]
	if rar >= 2:
		Art.dot(ci, c, r * (1.25 + 0.06 * sin(tt * 3.0)), Color(col, 0.25))
	var kind := str(rel.get("kind", ""))
	var sides := 6 if kind.ends_with("ring") or kind.ends_with("seal") else (4 if kind.ends_with("eye") or kind.ends_with("fang") else 8)
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides - PI / 2.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	Art.toon(ci, pts, Color("e8b830"), 2.5, 0.0)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.68)
	Art.toon(ci, inner, col, 2.0, 0.0)
	Art.dot(ci, c + Vector2(-r * 0.22, -r * 0.24), r * 0.16, Color(1, 1, 1, 0.8))


static func _icon(rel: Dictionary, px: float = 56.0) -> Control:
	return ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): draw_icon(ci, s / 2.0, s.x * 0.4, rel, tt), Vector2(px, px), int(rel.get("rarity", 0)) >= 2)


## "Rare Siren Comb" plus one line per property.
static func _text(rel: Dictionary, px: int = 20) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rar := int(rel.get("rarity", 0))
	var name := Views.label(t("RELIC_K_" + str(rel.get("kind", "")).to_upper()) + "  " + "★".repeat(rar + 1), px + 2, Relics.RARITY_COLORS[rar].darkened(0.35), true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	for a in rel.get("affixes", []):
		var l := Views.label(Relics.describe(a, WorldLook.site_name), px, Art.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	return col


## The card under "You won!" in a boss fight.
static func drop_card(rel: Dictionary) -> Control:
	var card := Views.card(Color("fff4d8"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_icon(rel, 64.0))
	var col := _text(rel, 18)
	var head := Views.label(t("RELIC_MELTED") % int(rel.get("shards", 0)) if rel.get("melted", false) else t("RELIC_FOUND"), 18, Color("8a5a00"), true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	col.move_child(head, 0)
	row.add_child(col)
	card.add_child(row)
	return card


static func _btn(text: String, variation: StringName, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b


static func build(m: Modal, _main: Node) -> void:
	m.title(t("RELIC_TITLE"))
	m.banner(UiTheme.BANNER_PURPLE)
	if _pick >= GameState.relics.size():
		_pick = -1
	var top := m.row(10)
	var shards := Views.label(t("RELIC_SHARDS") % GameState.relic_shards, 24, Color("6a3cc0"), true)
	shards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(shards)
	# The worn totals.
	var sums := []
	for st in Relics.STATS:
		if st != "site" and GameState.relic(st) > 0.0:
			sums.append(Relics.describe({"stat": st, "v": GameState.relic(st)}))
	for i in GameState.site_count():
		if GameState.relic("site", i) > 0.0:
			sums.append(Relics.describe({"stat": "site", "v": GameState.relic("site", i), "site": i}, WorldLook.site_name))
	var tot := m.text(t("RELIC_TOTAL") + "  " + (", ".join(sums) if not sums.is_empty() else t("RELIC_NONE")), 20, Art.INK_SOFT)
	tot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The party, three slots each.
	for c in Party.members(GameState.saga_beaten()):
		var card := Views.card(Color("efe6ff"))
		var col := VBoxContainer.new()
		var head := HBoxContainer.new()
		var worn := []
		for i in GameState.relics.size():
			if str(GameState.relics[i].get("hero", "")) == c:
				worn.append(i)
		var name := Views.label(t(Party.name_key(c)) + "  %d/%d" % [worn.size(), Relics.SLOTS], 24, Color("6a3cc0"), true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		if _pick >= 0 and worn.size() < Relics.SLOTS:
			var hero: String = c
			head.add_child(_btn(t("RELIC_PUT"), &"SlimGoldButton", func():
				GameState.wear_relic(_pick, hero)
				_pick = -1
				m.rebuild()))
		col.add_child(head)
		for i in worn:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(_icon(GameState.relics[i], 48.0))
			row.add_child(_text(GameState.relics[i], 18))
			var at: int = i
			var off := _btn(t("RELIC_OFF"), &"SlimCreamButton", func():
				GameState.take_off_relic(at)
				m.rebuild())
			off.disabled = GameState.bag_relics().size() >= Relics.BAG
			row.add_child(off)
			col.add_child(row)
		card.add_child(col)
		m.add(card)
	# The bag.
	var bag := []
	for i in GameState.relics.size():
		if str(GameState.relics[i].get("hero", "")) == "":
			bag.append(i)
	m.text(t("RELIC_BAG") % [bag.size(), Relics.BAG], 24, Color("6a3cc0"))
	if bag.is_empty():
		var e := m.text(t("RELIC_EMPTY"), 20, Art.INK_SOFT)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in bag:
		var rel: Dictionary = GameState.relics[i]
		var rar := int(rel["rarity"])
		var card := Views.card(Color("fff4d8") if i == _pick else Color("fffaf0"))
		var col := VBoxContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon(rel, 56.0))
		row.add_child(_text(rel, 19))
		col.add_child(row)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		var at: int = i
		for b in [
				_btn(t("RELIC_CANCEL") if i == _pick else t("RELIC_WEAR"), &"SlimPurpleButton", func():
					_pick = -1 if _pick == at else at
					m.rebuild()),
				_btn(t("RELIC_REROLL") % Relics.REROLL[rar], &"SlimBlueButton", func():
					GameState.reroll_relic(at)
					m.rebuild()),
				_btn(t("RELIC_MELT") % Relics.SALVAGE[rar], &"SlimDarkButton", func():
					_pick = -1
					GameState.salvage_relic(at)
					m.rebuild())]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 19)
			btns.add_child(b)
		btns.get_child(1).disabled = GameState.relic_shards < Relics.REROLL[rar]
		col.add_child(btns)
		card.add_child(col)
		m.add(card)
