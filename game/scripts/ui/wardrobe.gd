class_name Wardrobe
extends RefCounted
## Wardrobe and pearl shop: the player with their pet on top, tabs for
## outfits (the player's clothes in the office), pets, hats, boat paint and
## the pearl shop, and a grid of items.
## Items are bought with pearls (earned by playing) or unlocked by goals;
## nothing here is random and nothing costs real money.

const TABS := [["outfit", "TAB_OUTFITS"], ["pet", "TAB_PETS"], ["hat", "TAB_HATS"], ["boat", "TAB_BOATS"], ["shop", "TAB_SHOP"]]

static var tab := "pet"


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func build(m: Modal, main: Node) -> void:
	m.title(t("WARDROBE"))
	# The player and their pet.
	var preview := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := Vector2(s.x / 2.0 - 30.0, s.y - 12.0)
		Art.t_ellipse(ci, c + Vector2(30, 0), Vector2(150, 18), Art.CREAM_DARK, 3.0, 0.0)
		Chars.player(ci, c + Vector2(0, -4 - absf(sin(tt * 2.2)) * 3.0), _player_scale(s.y - 22.0), Settings.avatar, current_outfit(),
				{"pose": "wave", "t": tt, "blink": Chars.blinking(tt, 2.0), "emotion": "happy"})
		var pet: String = Progress.equipped_art("pet")
		if pet != "":
			Art.push(ci, c + Vector2(125, -50 + sin(tt * 2.6) * 6.0), 0.0, Vector2(1.9, 1.9))
			PetArt.draw(ci, pet, tt, -1.0, true)
			Art.pop(ci), Vector2(0, 230), true)
	m.add(preview)
	var top := m.row(10)
	var look := Button.new()
	look.theme_type_variation = &"BlueButton"
	look.text = t("EDIT_LOOK")
	look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look.custom_minimum_size.y = 68
	look.pressed.connect(func(): Sfx.play("click"); main.open_avatar_editor())
	top.add_child(look)
	top.add_child(Views.pearl_counter(28))
	# Tabs: one row of equal tabs in every language (the words shrink).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for tb in TABS:
		var b := Button.new()
		b.text = t(tb[1])
		b.theme_type_variation = &"SlimPurpleButton" if tab == tb[0] else &"SlimCreamButton"
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 21)
		var id: String = tb[0]
		b.pressed.connect(func():
			Sfx.play("click")
			tab = id
			m.rebuild())
		tabs.add_child(b)
	Views.fit_button_row(tabs, 21)
	m.add(tabs)
	if tab == "shop":
		_shop(m, main)
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for c in Content.COSMETICS:
		if c["slot"] == tab:
			grid.add_child(_cell(c, m))
	m.add(grid)


static var _item_bounds := {}


static func _draw_item(ci: CanvasItem, c: Dictionary, s: Vector2, tt: float) -> void:
	var mid := s / 2.0
	var art: String = c["art"]
	match str(c["slot"]):
		"outfit":
			Chars.outfit_icon(ci, mid + Vector2(0, 2), minf(s.x, s.y) - 6.0, str(c["id"]))
		"hat":
			var look := Settings.avatar.duplicate()
			look["hat"] = art
			Chars.portrait(ci, mid + Vector2(0, 4), minf(s.x, s.y) * 0.4, look, "happy", Chars.blinking(tt, 4.0), Color("bfe8ff"))
		_:
			# Pets, boats and divers: scaled to fit inside the card's picture
			# (bounds measured once at rest, with room for the idle motion).
			var id: String = c["id"]
			if not _item_bounds.has(id):
				Art.measure_begin()
				_draw_art(null, c, 0.0)
				_item_bounds[id] = Art.measure_end()
			var b: Rect2 = _item_bounds[id]
			var most: float = {"pet": 2.3, "boat": 0.62}.get(str(c["slot"]), 1.0)
			var sc := minf(most, minf((s.x - 16.0) / maxf(b.size.x, 1.0), (s.y - 10.0) / maxf(b.size.y, 1.0)))
			Art.push(ci, mid - b.get_center() * sc, 0.0, Vector2(sc, sc))
			_draw_art(ci, c, tt)
			Art.pop(ci)


## One wardrobe item drawn around the origin at scale 1.
static func _draw_art(ci: CanvasItem, c: Dictionary, tt: float) -> void:
	var art: String = c["art"]
	match str(c["slot"]):
		"pet":
			Art.push(ci, Vector2(0, sin(tt * 2.4) * 1.7))
			PetArt.draw(ci, art, tt, 1.0, false)
			Art.pop(ci)
		"boat":
			Props.boat_paint = Content.BOAT_PAINTS.get(art, Content.BOAT_PAINTS["classic"])
			Props.boat(ci, tt, 2, Art.GOLD, false, "happy", false)
			Props.boat_paint = current_boat_paint()


static func _cell(c: Dictionary, m: Modal) -> Control:
	var id: String = c["id"]
	var owned := Progress.is_owned(id)
	var on: bool = Progress.equipped.get(c["slot"], "") == id
	var rarity: int = c.get("rarity", 0)
	var card := Views.card(Color("fff1c2") if on else Color("fffaf0"))
	var sb: ToonBox = card.get_theme_stylebox("panel")
	sb.line = Content.RARITY_COLORS[rarity].darkened(0.35) if rarity > 0 else Art.INK
	sb.line_w = 5.0 if rarity > 0 else 4.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_item(ci, c, s, tt), Vector2(0, 130), true)
	v.add_child(pic)
	if not owned:
		pic.modulate = Color(0.75, 0.75, 0.8) if c["unlock"] == "goal" else Color.WHITE
	var name := Views.label(t("ITEM_" + id.to_upper()), 18, Art.INK, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 21)
	if on:
		b.text = t("WEARING")
		b.theme_type_variation = &"Button"
		b.icon = Icons.get_icon("check", 26)
		b.disabled = not c["slot"] in ["pet", "hat"]
		b.pressed.connect(func(): _equip(id, m))
	elif owned:
		b.text = t("WEAR")
		b.theme_type_variation = &"BlueButton"
		b.pressed.connect(func(): _equip(id, m))
	elif c["unlock"] == "pearls":
		b.text = str(c["price"])
		b.icon = Icons.get_icon("pearl", 30)
		b.theme_type_variation = &"GoldButton" if Progress.pearls >= int(c["price"]) else &"DarkButton"
		b.pressed.connect(func():
			if Progress.buy_item(id):
				_after_equip(id)
				Sfx.play("unlock")
				Sfx.voice("yay", 1.2)
				m.rebuild()
			else:
				Sfx.play("deny")
				_shake(b))
	else:
		var goal: Array = Content.GOALS.get(c.get("goal", ""), ["", 1])
		var have := int(Progress.stats.get(goal[0], 0))
		b.text = "%d/%d" % [mini(have, goal[1]), goal[1]]
		b.icon = Icons.get_icon("lock", 28)
		b.theme_type_variation = &"DarkButton"
		b.tooltip_text = t("GOAL_" + str(c.get("goal", "")).to_upper())
		b.pressed.connect(func(): Sfx.play("deny"); main_toast(m, t("GOAL_" + str(c.get("goal", "")).to_upper())))
		var hint := Views.label(t("GOAL_" + str(c.get("goal", "")).to_upper()), 15, Art.INK_SOFT)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	v.add_child(b)
	return card


static func main_toast(m: Modal, text: String) -> void:
	var main := m.get_parent()
	if main and main.has_method("_show_toast"):
		main._show_toast(text)


static func _shake(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for i in 2:
		tw.tween_property(c, "position:x", x + 8.0, 0.04)
		tw.tween_property(c, "position:x", x - 8.0, 0.04)
	tw.tween_property(c, "position:x", x, 0.04)


static func _equip(id: String, m: Modal) -> void:
	Progress.equip(id)
	_after_equip(id)
	Sfx.play("pop")
	m.rebuild()


## Hats live in the avatar look; boat and suit paint go to the drawing code.
static func _after_equip(id: String) -> void:
	var c := Content.cosmetic(id)
	if c.get("slot") == "hat":
		var look := Settings.avatar.duplicate()
		look["hat"] = Progress.equipped_art("hat") if Progress.equipped_art("hat") != "" else "none"
		Settings.set_avatar(look)
	apply_looks()
	Progress.save_game()


## Pushes the equipped boat paint into the scene's drawing code (the
## workers' looks come from their evolution form now, not from suits).
static func apply_looks() -> void:
	Props.boat_paint = current_boat_paint()
	DiverLayer.suit_paint = []


## The player's outfit id ("outfit_casual" when none is worn).
static func current_outfit() -> String:
	var o := str(Progress.equipped.get("outfit", ""))
	return o if o != "" else "outfit_casual"


static var _player_h := 0.0


## Scale for Chars.player so the player stands `h` px tall.
static func _player_scale(h: float) -> float:
	if _player_h <= 0.0:
		Art.measure_begin()
		Chars.player(null, Vector2.ZERO, 1.0, Settings.avatar, "outfit_casual", {"pose": "stand", "blink": false})
		_player_h = maxf(Art.measure_end().size.y, 1.0)
	return minf(2.4, h / _player_h)


static func current_boat_paint() -> Array:
	var p = Content.BOAT_PAINTS.get(Progress.equipped_art("boat"), [])
	return p if p != null else []


static func _shop(m: Modal, main: Node) -> void:
	m.text(t("SHOP_HINT"), 21, Art.INK_SOFT)
	var offers := [
		["bolt", t("SHOP_BOOST") % Content.BOOST_MIN, Content.BOOST_PRICE, func(): return Progress.buy_boost(), {"boost": Content.BOOST_MIN}],
		["coin", t("SHOP_COINS") % NumFormat.short(Progress.coins_for_minutes(Content.COINS_MIN)), Content.COINS_PRICE,
				func(): return Progress.buy_coins(), {"coins": Progress.coins_for_minutes(Content.COINS_MIN)}],
	]
	for o in offers:
		var card := Views.card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		h.add_child(Views.icon(o[0], 64))
		var l := Views.label(o[1], 23, Art.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var b := Button.new()
		b.text = str(o[2])
		b.icon = Icons.get_icon("pearl", 30)
		b.custom_minimum_size = Vector2(140, 68)
		b.theme_type_variation = &"GoldButton" if Progress.pearls >= int(o[2]) else &"DarkButton"
		var buy: Callable = o[3]
		var shown: Dictionary = o[4]
		b.pressed.connect(func():
			var from := b.get_global_rect().get_center()
			if buy.call():
				main.celebrate(shown, from)
				m.rebuild()
			else:
				Sfx.play("deny")
				_shake(b))
		h.add_child(b)
		m.add(card)
	m.text(t("PEARLS_HOW"), 20, Art.INK_SOFT)
