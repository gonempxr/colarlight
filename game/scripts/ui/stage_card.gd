class_name StageCard
extends PanelContainer
## Compact cream card for one stage: a coloured name tab, manager portrait,
## level with milestone bar, output per second and an upgrade button that
## opens the upgrade panel. The boat and the plant also show their building
## stage (1..20) and, once the second one is for sale, "1 | 2" tabs that
## switch the card between the two units (a closed second one shows its
## price and buys it); the lift shows its look (1..6). With `hero` the card
## also shows a picture of the stage (the PC side column). `narrow` cards
## (three in a row) shrink their text to fit instead of wrapping it.

var key := ""
## "boat" or "plant" for building cards (key may be "boat2"), else the key.
var base := ""
var world: World
var hero := false
var narrow := false

var _name: Label
var _name_fs := 0
var _level: Label
var _rate: Label
var _bar: ProgressBar
var _upgrade: Button
var _manager: ManagerBadge
var _tag: Label
var _head: PanelContainer
var _stage: Label
var _pic: ArtView
var _units: HBoxContainer
var _unit_btns: Array[Button] = []
## Red dots on the unit tabs: that unit can hire its manager right now.
var _unit_dots: Array[Control] = []


func _init(stage_key: String) -> void:
	key = stage_key
	base = stage_key


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_head = PanelContainer.new()
	var hsb := ToonBox.make(head_color(key), 12, 0)
	hsb.line_w = 3.0
	hsb.gloss = 0.25
	hsb.content_margin_left = 10
	hsb.content_margin_right = 10
	hsb.content_margin_top = 2
	hsb.content_margin_bottom = 4
	_head.add_theme_stylebox_override("panel", hsb)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_head)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.heavy_font())
	_name.add_theme_font_size_override("font_size", 19)
	_name.add_theme_constant_override("outline_size", 6)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size.x = 40 if narrow else 150
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Head row: [1] name [2]; the unit tabs show once a second one is for sale.
	_units = HBoxContainer.new()
	_units.add_theme_constant_override("separation", 4)
	if narrow:
		# One line, as tall as the unit tabs, on all three cards.
		_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_units.custom_minimum_size.y = 55
	_head.add_child(_units)
	if base in ["boat", "plant"]:
		for i in 2:
			var b := Button.new()
			b.text = str(i + 1)
			b.custom_minimum_size = Vector2(30 if narrow else 34, 32)
			b.add_theme_font_size_override("font_size", 17)
			b.visible = false
			b.pressed.connect(_select_unit.bind(i))
			_unit_btns.append(b)
			var dot := Control.new()
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Bottom-right corner: the card's top edge can sit under the top bar.
			dot.size = Vector2(16, 16)
			b.resized.connect(func() -> void: dot.position = b.size - Vector2(11, 11))
			dot.visible = false
			dot.draw.connect(func() -> void: Art.t_circle(dot, Vector2(8, 8), 7.5, Art.RED, 2.5, 0.3))
			b.add_child(dot)
			_unit_dots.append(dot)
		_units.add_child(_unit_btns[0])
		_units.add_child(_name)
		_units.add_child(_unit_btns[1])
		# Just bought the second one: show it (its manager slot is next).
		GameState.depth_opened.connect(func(k: String) -> void:
			if k == base + "2":
				show_unit(k))
	else:
		_units.add_child(_name)
	# The stage line only on the roomy PC cards; phone cards float over the
	# sky and must stay short (the name tab carries the star count there).
	if base in ["boat", "plant", "lift"] and hero:
		_stage = Label.new()
		_stage.theme_type_variation = &"SoftLabel"
		_stage.add_theme_font_override("font", UiTheme.heavy_font())
		_stage.add_theme_font_size_override("font_size", 16)
		_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stage.custom_minimum_size.x = 100 if narrow else 150
		box.add_child(_stage)
	if hero:
		_pic = ArtView.make(_draw_hero, Vector2(0, 118 if narrow else 150), true)
		_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pic.clip_contents = true
		box.add_child(_pic)
		box.move_child(_pic, 1)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	box.add_child(mid)
	_manager = ManagerBadge.new(key)
	mid.add_child(_manager)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 3)
	mid.add_child(lv)
	_level = Label.new()
	_level.theme_type_variation = &"InkLabel"
	_level.add_theme_font_override("font", UiTheme.heavy_font())
	_level.add_theme_font_size_override("font_size", 25)
	lv.add_child(_level)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(40 if narrow else 80, 14)
	_bar.max_value = 1.0
	lv.add_child(_bar)
	_rate = Label.new()
	_rate.theme_type_variation = &"InkLabel"
	_rate.add_theme_font_size_override("font_size", 19)
	_rate.add_theme_color_override("font_color", Art.GREEN_DARK)
	if narrow:
		# Three in a row: the output line gets the card's whole width.
		_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_rate)
		# Two lines for every stage name, and the buttons of the three cards
		# line up at the bottom.
		if _stage:
			_stage.custom_minimum_size.y = 52
			_stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gap)
	else:
		lv.add_child(_rate)

	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(0, 62)
	_upgrade.add_theme_font_size_override("font_size", 22 if narrow else 24)
	_upgrade.icon = Icons.get_icon("arrow", 26 if narrow else 30)
	_upgrade.expand_icon = false
	_upgrade.pressed.connect(_on_upgrade)
	box.add_child(_upgrade)

	_tag = Label.new()
	_tag.theme_type_variation = &"InkLabel"
	_tag.add_theme_font_size_override("font_size", 16)
	_tag.add_theme_color_override("font_color", Color("d8363c"))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if narrow:
		_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tag.custom_minimum_size.x = 80
	_tag.visible = false
	box.add_child(_tag)
	for l: Label in [_name, _level, _rate]:
		l.resized.connect(_fit_text)
	refresh()


## The bottleneck and the next depth to open cost about 0.1 ms to work out
## (every open site's rate is added up), and every card asks on every
## refresh: they are worked out once per frame for all the cards, and again
## right after a state change.
static var _bn_frame := -1
static var _bn := ""
static var _nd := ""
static var _bn_hooked := false


static func _bn_update() -> void:
	var f := Engine.get_process_frames()
	if f == _bn_frame:
		return
	_bn_frame = f
	_bn = GameState.bottleneck()
	_nd = GameState.next_depth()


static func _bn_bust(_a = null, _b = null) -> void:
	_bn_frame = -1


static func bottleneck_cached() -> String:
	if not _bn_hooked:
		_bn_hooked = true
		GameState.upgraded.connect(_bn_bust)
		GameState.manager_hired.connect(_bn_bust)
		GameState.depth_opened.connect(_bn_bust)
		GameState.changed.connect(_bn_bust)
	_bn_update()
	return _bn


static func next_depth_cached() -> String:
	_bn_update()
	return _nd


static func head_color(stage_key: String) -> Color:
	match stage_key:
		"lift":
			return Color("2bb5a0")
		"boat":
			return Color("3aa6f0")
		"plant":
			return Color("ff8a3d")
	var i := GameState.depth_index(stage_key)
	return Art.DEPTH_STYLE[i]["water"].lightened(0.15) if i >= 0 else Art.BLUE


func _draw_hero(ci: CanvasItem, s: Vector2, t: float) -> void:
	var bg := Color("bfe8ff")
	Art.flat(ci, Art.rrect_pts(Rect2(Vector2.ZERO, s), 14.0), bg)
	Art.flat(ci, Art.rrect_pts(Rect2(0, s.y * 0.62, s.x, s.y * 0.38), 14.0), Color("5ec4e6"))
	# Props.boat/plant draw the current building stage; taller stages shrink to fit.
	match base:
		"lift":
			LiftView.draw_card_hero(ci, s, t, Balance.lift_look(GameState.get_level("lift")), GameState.cycle_progress("lift"))
		"boat":
			var bs := minf(0.9, s.y * 0.62 / Props.boat_height(Props.current_stage(key)))
			Art.push(ci, Vector2(s.x * 0.5, s.y * 0.7), 0.0, Vector2(bs, bs))
			Props.boat(ci, t, 2, Art.DEPTH_STYLE[0]["ore2"], GameState.has_manager(key), "happy", Chars.blinking(t, 7.0), Callable(), key)
			Art.pop(ci)
		"plant":
			Art.flat(ci, Art.rrect_pts(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), 14.0), Color("f5d58f"))
			var ps := minf(0.75, s.y * 0.72 / Props.plant_height(Props.current_stage(key)))
			Art.push(ci, Vector2(s.x * 0.5, s.y * 0.8), 0.0, Vector2(ps, ps))
			Props.plant(ci, t, GameState.cycle_progress(key) >= 0.0, t * 2.0, 0.0, key)
			Art.pop(ci)


## An open unit without a manager whose manager the player can afford.
static func unit_wants_manager(unit: String) -> bool:
	var gs := GameState
	return gs.is_open(unit) and not gs.has_manager(unit) and gs.coins >= gs.manager_cost(unit)


func _on_upgrade() -> void:
	if Scroller.is_drag():
		return
	if GameState.is_second(key) and not GameState.is_open(key):
		Sfx.play("unlock" if GameState.open_building(key) else "deny")
		refresh()
		return
	Sfx.play("click")
	world.select(key)


## 0 = the first boat/plant, 1 = the second one.
func _select_unit(i: int) -> void:
	if Scroller.is_drag():
		return
	Sfx.play("click")
	show_unit(base if i == 0 else base + "2")


func show_unit(stage_key: String) -> void:
	key = stage_key
	_manager.set_key(key)
	refresh()


func refresh() -> void:
	var gs := GameState
	var data := GameState.stage_data(key)
	var level: int = gs.get_level(key)
	_name.text = Views.stage_name(key)
	if not _unit_btns.is_empty():
		var tabs: bool = gs.is_open("d2") or gs.is_open(base + "2")
		_name.custom_minimum_size.x = (40.0 if narrow else 60.0) if tabs or narrow else 150.0
		_name_fs = 16 if tabs and not hero else 19
		_name.autowrap_mode = TextServer.AUTOWRAP_OFF if tabs or narrow else TextServer.AUTOWRAP_WORD_SMART
		for i in 2:
			var on := (i == 1) == gs.is_second(key)
			_unit_btns[i].visible = tabs
			_unit_btns[i].theme_type_variation = _btn(&"BlueButton" if on else &"CreamButton")
		var second_open: bool = gs.is_open(base + "2")
		_unit_btns[1].text = "2" if second_open else ""
		_unit_btns[1].icon = null if second_open else Icons.get_icon("lock", 20)
		for i in 2:
			_unit_dots[i].visible = tabs and unit_wants_manager(base if i == 0 else base + "2")
	var for_sale := gs.is_second(key) and level == 0
	_manager.visible = not for_sale
	_bar.visible = not for_sale
	if for_sale:
		# A closed second boat/plant: its price and what one level would add.
		if _stage:
			_stage.text = tr("BUY_%s_DESC" % key.to_upper())
		_level.text = tr("BUY_%s" % key.to_upper())
		_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(Balance.output(data["value"], 1) * gs.income_mult())
		var price: float = gs.unlock_cost(key)
		_upgrade.text = tr("BUY_FOR") % NumFormat.short(price)
		_upgrade.theme_type_variation = _btn(&"GoldButton" if gs.coins >= price else &"DarkButton")
		_show_tag(false)
		return
	var lift := base == "lift"
	var st := Balance.lift_look(level) if lift else Balance.building_stage(level)
	if _stage:
		_stage.text = "%s  ★%d/%d" % [tr("%s_STAGE_%d" % [base.to_upper(), st]), st, Balance.LIFT_LOOKS.size() if lift else Balance.BUILDING_STAGES]
	elif lift or (base in ["boat", "plant"] and not _unit_btns[1].visible):
		_name.text += " ★%d" % st
	_level.text = tr("LEVEL") % level
	var ms := Balance.milestones(level)
	var prev := 0 if ms == 0 else (Balance.MILESTONE_FIRST if ms == 1 else (ms - 1) * Balance.MILESTONE_STEP)
	var next := Balance.MILESTONE_FIRST if ms == 0 else ms * Balance.MILESTONE_STEP
	_bar.value = float(level - prev) / float(maxi(1, next - prev))
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(gs.rate(key))
	var cost: float = gs.upgrade_cost(key)
	_upgrade.text = NumFormat.short(cost)
	_upgrade.theme_type_variation = _btn(&"" if gs.coins >= cost else &"DarkButton")
	var group := base if base in ["boat", "plant", "lift"] else "dives"
	_show_tag(bottleneck_cached() == group and next_depth_cached() != "d1")
	_tag.text = tr("BOTTLENECK")
	_manager.queue_redraw()
	_fit_text()


## Narrow cards keep the tag's line (see-through) so the three upgrade
## buttons stay in a row.
func _show_tag(on: bool) -> void:
	_tag.visible = on or narrow
	_tag.self_modulate.a = 1.0 if on else 0.0


## A button style, slim (narrow side margins) on narrow cards.
func _btn(variation: StringName) -> StringName:
	if not narrow:
		return variation
	return StringName("Slim" + (String(variation) if variation != &"" else "Button"))


## Shrinks the name, the level and the output line (down to 12 px) where
## their text is wider than the card has room for, in every language.
func _fit_text() -> void:
	if _level == null:
		return
	var fs := _name_fs if _name_fs > 0 else 19
	# Clipped labels ask for no width of their own: the card's width decides
	# and the text shrinks to it.
	var one_line := _name.autowrap_mode == TextServer.AUTOWRAP_OFF
	_name.clip_text = one_line
	if one_line and _name.size.x > 1.0:
		fs = _fit_size(_name, fs, _name.size.x)
	if _name.get_theme_font_size("font_size") != fs:
		_name.add_theme_font_size_override("font_size", fs)
	for pair: Array in [[_level, 25], [_rate, 19]]:
		var l: Label = pair[0]
		l.clip_text = true
		if l.size.x > 1.0:
			var f := _fit_size(l, pair[1], l.size.x)
			if l.get_theme_font_size("font_size") != f:
				l.add_theme_font_size_override("font_size", f)


static func _fit_size(l: Label, want: int, room: float) -> int:
	var font := l.get_theme_font("font")
	var fs := want
	while fs > 12 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room - 2.0:
		fs -= 1
	return fs
