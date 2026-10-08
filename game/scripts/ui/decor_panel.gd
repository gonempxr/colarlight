class_name DecorPanel
extends RefCounted
## The office decor shop: 8 pieces (wallpaper, floor, desk, sofa, aquarium,
## lamp, trophy shelf, plant), 5 levels each, bought with pearls. The chosen
## piece is shown big, now and after the next level, with its price; a row
## of small pictures picks the piece. Every level of every piece: +1% coins.

static var slot := "sofa"
static var _fresh := false
static var _boxes := {}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func build(m: Modal, main: Node) -> void:
	if not slot in Content.DECOR_SLOTS:
		slot = Content.DECOR_SLOTS[0]
	m.title(t("DECOR"))
	var top := m.row(10)
	var how := Views.label(t("DECOR_HOW") % roundi(Balance.DECOR_BONUS * 100.0), 19, Art.INK_SOFT)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.custom_minimum_size.x = 160
	top.add_child(how)
	top.add_child(Views.pearl_counter(28))
	var lv := Progress.decor_level(slot)
	var maxed := lv >= Content.DECOR_MAX
	var cost := Progress.decor_cost(slot)
	# Big card: now -> next level.
	var card := Views.card(Color("fff1c2"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := Views.label("%s  ·  %s" % [t("DECOR_" + slot.to_upper()), t("LEVEL") % lv], 28, Art.INK, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var fresh := _fresh
	_fresh = false
	var s0 := slot
	var pics := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var half := Vector2(s.x / 2.0 - 8.0, s.y)
		if maxed:
			var pop := 1.0
			if fresh and tt < 0.6 and not Settings.reduce_motion:
				pop = 0.7 + 0.3 * ease(tt / 0.6, 0.4) + sin(tt / 0.6 * PI) * 0.08
			_piece(ci, s0, lv, Rect2(Vector2(s.x * 0.2, 0), Vector2(s.x * 0.6, s.y)), tt, pop)
			return
		_piece(ci, s0, lv, Rect2(Vector2.ZERO, half), tt, 1.0)
		var pop2 := 1.0
		if fresh and tt < 0.6 and not Settings.reduce_motion:
			pop2 = 0.7 + 0.3 * ease(tt / 0.6, 0.4)
		Art.glow(ci, Vector2(s.x * 0.75, s.y * 0.5), s.y * 0.5, Color(Art.GOLD, 0.35))
		_piece(ci, s0, lv + 1, Rect2(Vector2(s.x / 2.0 + 8.0, 0), half), tt, pop2)
		var m2 := Vector2(s.x / 2.0, s.y / 2.0)
		Art.toon(ci, PackedVector2Array([m2 + Vector2(-10, -13), m2 + Vector2(12, 0), m2 + Vector2(-10, 13)]), Art.GOLD, 3.0, 0.0),
			Vector2(0, 190), true)
	v.add_child(pics)
	var stars := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		for i in Content.DECOR_MAX:
			var c := Vector2(s.x / 2.0 + (i - (Content.DECOR_MAX - 1) / 2.0) * 34.0, s.y / 2.0)
			Art.toon(ci, Art.star_pts(c, 14.0, 6.5, 5), Art.GOLD if i < lv else Color("d9cfe6"), 2.5, 0.3 if i < lv else 0.0),
			Vector2(0, 34))
	v.add_child(stars)
	if maxed:
		var top_l := Views.label(t("DECOR_MAXED"), 24, Color("2f8f3a"), true)
		top_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(top_l)
	else:
		var buy := PriceButton.new()
		buy.custom_minimum_size = Vector2(0, 80)
		buy.add_theme_font_size_override("font_size", 28)
		buy.set_price(t("DECOR_BUY") % (lv + 1), str(cost), "pearl")
		buy.theme_type_variation = &"GoldButton" if Progress.pearls >= cost else &"DarkButton"
		buy.pressed.connect(func():
			var from := buy.get_global_rect().get_center()
			if Progress.buy_decor(slot):
				_fresh = true
				Sfx.play("unlock")
				Sfx.voice("yay", 1.2)
				Settings.buzz(30)
				if main.has_method("on_decor_bought"):
					main.on_decor_bought(slot, from)
				m.rebuild()
			else:
				Sfx.play("deny")
				Wardrobe._shake(buy)
				Wardrobe.main_toast(m, t("DECOR_NEED_PEARLS")))
		v.add_child(buy)
	m.add(card)
	# All the pieces: tap one to choose it.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for sl: String in Content.DECOR_SLOTS:
		grid.add_child(_chip(sl, m))
	m.add(grid)
	m.text(t("PEARLS_HOW"), 18, Art.INK_SOFT)


static func _chip(sl: String, m: Modal) -> Control:
	var on := sl == slot
	var lv := Progress.decor_level(sl)
	var b := Button.new()
	b.theme_type_variation = &"PurpleButton" if on else &"CreamButton"
	b.custom_minimum_size = Vector2(0, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		Sfx.play("click")
		slot = sl
		m.rebuild())
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		_piece(ci, sl, maxi(lv, 1), Rect2(Vector2(6, 4), s - Vector2(12, 8)), tt, 1.0)
		# Level pips under the picture.
		for i in Content.DECOR_MAX:
			var c := Vector2(s.x / 2.0 + (i - 2) * 13.0, s.y - 4.0)
			Art.t_circle(ci, c, 4.5, Art.GOLD if i < lv else Color(1, 1, 1, 0.6), 2.0, 0.0), Vector2(0, 100), true)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_bottom = -10
	b.add_child(pic)
	b.tooltip_text = t("DECOR_" + sl.to_upper())
	var can := Progress.decor_cost(sl) > 0 and Progress.pearls >= Progress.decor_cost(sl)
	if can and not on:
		var dot := ArtView.make(func(ci: CanvasItem, _s: Vector2, _tt: float): Art.t_circle(ci, Vector2(10, 10), 8.0, Art.GREEN, 2.5, 0.0), Vector2(20, 20))
		dot.position = Vector2(-4, -4)
		b.add_child(dot)
	return b


## One decor piece at `level` fitted into `r` (measured once per piece and
## level, so every level fills its frame).
static func _piece(ci: CanvasItem, sl: String, level: int, r: Rect2, tt: float, pop: float) -> void:
	level = clampi(level, 0, Content.DECOR_MAX)
	match sl:
		"wallpaper", "floor":
			var sq := minf(r.size.x, r.size.y) * 0.86 * pop
			var box := Rect2(r.get_center() - Vector2(sq, sq) / 2.0, Vector2(sq, sq))
			Art.push(ci, box.position)
			if sl == "wallpaper":
				OfficeArt.wallpaper(ci, sq, sq, level)
			else:
				OfficeArt.floor_band(ci, sq, 0.0, sq, level)
			Art.pop(ci)
			Art.polyline(ci, Art.rrect_pts(box, 10.0), Art.INK, 4.0, true)
			return
	var key := "%s:%d" % [sl, level]
	if not _boxes.has(key):
		Art.measure_begin()
		_draw_piece(null, sl, level, 0.0)
		_boxes[key] = Art.measure_end()
	var b: Rect2 = _boxes[key]
	var sc := minf((r.size.x - 4.0) / maxf(b.size.x, 1.0), (r.size.y - 4.0) / maxf(b.size.y, 1.0)) * pop
	sc = minf(sc, 1.6)
	Art.push(ci, r.get_center() - b.get_center() * sc, 0.0, Vector2(sc, sc))
	_draw_piece(ci, sl, level, tt)
	Art.pop(ci)


static func _draw_piece(ci: CanvasItem, sl: String, level: int, tt: float) -> void:
	match sl:
		"desk":
			OfficeArt.desk(ci, level, tt)
		"sofa":
			OfficeArt.sofa(ci, level)
		"aquarium":
			OfficeArt.aquarium(ci, level, tt)
		"lamp":
			OfficeArt.lamp(ci, level, tt, false)
		"trophy":
			OfficeArt.trophy(ci, level, tt)
		"plant":
			OfficeArt.plant(ci, level, tt)
