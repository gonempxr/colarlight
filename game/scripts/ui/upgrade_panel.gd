class_name UpgradePanel
extends PanelContainer
## Details and buying for one stage: what it does, output now and after
## the purchase, next milestone, x1 / x10 / MAX, and hiring its manager
## while it has none (so automating any stage is one clear button).
## Phone: a bottom sheet with a close button. PC: a docked side panel.

signal closed

const MODES := [1, 10, -1]

var key := "d0"
var docked := false

var _title: Label
var _desc: Label
var _stats: Label
var _gain: Label
var _modes: Array[Button] = []
var _buy: Button
var _hire: Button
var _close: Button
var _mode := 0
var _hero: Control
var _t := 0.0


func _ready() -> void:
	theme_type_variation = &"SheetPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	# PC only: an illustration of the stage and its manager on top.
	_hero = Control.new()
	_hero.custom_minimum_size = Vector2(0, 190)
	_hero.visible = docked
	_hero.draw.connect(_draw_hero)
	box.add_child(_hero)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = &"InkLabel"
	_title.add_theme_font_override("font", UiTheme.heavy_font())
	_title.add_theme_font_size_override("font_size", 32)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_close = Button.new()
	_close.icon = Icons.get_icon("close", 30)
	_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close.theme_type_variation = &"RedButton"
	_close.custom_minimum_size = Vector2(64, 64)
	_close.pressed.connect(func(): closed.emit())
	head.add_child(_close)
	_desc = Label.new()
	_desc.theme_type_variation = &"SoftLabel"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 22)
	box.add_child(_desc)
	_stats = Label.new()
	_stats.theme_type_variation = &"InkLabel"
	_stats.add_theme_font_size_override("font_size", 24)
	box.add_child(_stats)
	_hire = Button.new()
	_hire.theme_type_variation = &"GoldButton"
	_hire.custom_minimum_size.y = 64
	_hire.icon = Icons.get_icon("people", 30)
	_hire.add_theme_font_size_override("font_size", 23)
	_hire.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hire.pressed.connect(_on_hire)
	box.add_child(_hire)
	_gain = Label.new()
	_gain.theme_type_variation = &"InkLabel"
	_gain.add_theme_font_override("font", UiTheme.heavy_font())
	_gain.add_theme_font_size_override("font_size", 28)
	_gain.add_theme_color_override("font_color", Art.GREEN_DARK)
	box.add_child(_gain)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	box.add_child(modes)
	for i in MODES.size():
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 60
		b.pressed.connect(_set_mode.bind(i))
		modes.add_child(b)
		_modes.append(b)
	_buy = Button.new()
	_buy.custom_minimum_size.y = 88
	_buy.icon = Icons.get_icon("arrow", 34)
	_buy.add_theme_font_size_override("font_size", 30)
	_buy.pressed.connect(_on_buy)
	box.add_child(_buy)
	refresh()


func show_stage(stage_key: String) -> void:
	key = stage_key
	refresh()


## PC column: the stage picture's height (0 hides it) so the panel fits.
func set_hero_height(h: float) -> void:
	if _hero:
		_hero.custom_minimum_size.y = h
		_hero.visible = docked and h > 0.0


func set_docked(value: bool) -> void:
	docked = value
	if _close:
		_close.visible = not docked
	if _hero:
		_hero.visible = docked
	theme_type_variation = &"PanelContainer" if docked else &"SheetPanel"


func _set_mode(i: int) -> void:
	_mode = i
	Sfx.play("click")
	refresh()


func _count() -> int:
	var m: int = MODES[_mode]
	if m == -1:
		return maxi(1, GameState.max_affordable(key))
	return m


func _on_hire() -> void:
	if GameState.hire_manager(key):
		Sfx.play("hire")
	else:
		Sfx.play("deny")
	refresh()


func _on_buy() -> void:
	if GameState.is_second(key) and not GameState.is_open(key):
		Sfx.play("unlock" if GameState.open_building(key) else "deny")
		refresh()
		return
	var n := _count()
	if GameState.upgrade(key, n):
		Sfx.play("upgrade")
	else:
		Sfx.play("deny")
	refresh()


func refresh() -> void:
	if _title == null:
		return
	var gs := GameState
	var data := GameState.stage_data(key)
	var name := ""
	var desc := ""
	var what := ""
	name = Views.stage_name(key)
	if key == "lift":
		desc = tr("DESC_LIFT")
		what = tr("STAT_CARRY")
	elif GameState.is_boat(key):
		desc = tr("DESC_BOAT")
		what = tr("STAT_CARRY")
	elif GameState.is_plant(key):
		desc = tr("DESC_PLANT")
		what = tr("STAT_PROCESS")
	else:
		desc = tr("DESC_DEPTH")
		what = tr("STAT_OUTPUT")
	if GameState.is_second(key) and not gs.is_open(key):
		# Not bought yet: what it is, what it adds, and its price.
		var price: float = gs.unlock_cost(key)
		_title.text = tr("BUY_%s" % key.to_upper())
		_desc.text = tr("BUY_%s_DESC" % key.to_upper())
		_stats.text = "%s: %s" % [what, tr("PER_SEC") % NumFormat.rate(Balance.output(data["value"], 1) * gs.income_mult())]
		_gain.text = ""
		for b in _modes:
			b.visible = false
		_buy.text = tr("BUY_FOR") % NumFormat.short(price)
		_buy.theme_type_variation = &"GoldButton" if gs.coins >= price else &"DarkButton"
		_hire.visible = false
		_close.visible = not docked
		return
	for b in _modes:
		b.visible = true
	_title.text = "%s · %s" % [name, tr("LEVEL") % gs.get_level(key)]
	# Manager: one clear button while there is none.
	var hired: bool = gs.has_manager(key)
	var foreman := GameState.depth_index(key) >= 0
	_hire.visible = not hired
	if not hired:
		var mc: float = gs.manager_cost(key)
		_hire.text = (tr("PANEL_HIRE_FOREMAN") if foreman else tr("PANEL_HIRE")) % NumFormat.short(mc)
		_hire.theme_type_variation = &"GoldButton" if gs.coins >= mc else &"DarkButton"
		if not foreman:
			desc += " " + tr("PANEL_MANUAL")
	_desc.text = desc
	var level: int = gs.get_level(key)
	var ms := Balance.milestones(level)
	var next_ms := Balance.MILESTONE_FIRST if ms == 0 else ms * Balance.MILESTONE_STEP
	var lines: Array[String] = []
	lines.append("%s: %s" % [what, tr("PER_SEC") % NumFormat.rate(gs.rate(key))])
	if GameState.depth_index(key) >= 0:
		lines.append("%s: %d" % [tr("STAT_DIVERS"), gs.divers(key)])
	if key == "lift":
		lines.append(tr("STAT_TRIP") % [NumFormat.short(gs.cycle_capacity(key)), "%.1f" % gs.cycle_time(key)])
		lines.append(tr("STAT_WAITING") % NumFormat.short(gs.pit))
	lines.append(tr("STAT_MILESTONE") % next_ms)
	_stats.text = "\n".join(lines)
	var n := _count()
	# Same multipliers as now (prestige, boost, foreman, artifacts), next level's output.
	var now_out := Balance.output(data["value"], level)
	var after := gs.rate(key) * Balance.output(data["value"], level + n) / now_out if now_out > 0.0 else 0.0
	_gain.text = "+%s  →  %s" % [tr("PER_SEC") % NumFormat.rate(after - gs.rate(key)), tr("LEVEL") % (level + n)]
	for i in _modes.size():
		var m: int = MODES[i]
		_modes[i].text = tr("BUY_MAX") if m == -1 else "×%d" % m
		_modes[i].theme_type_variation = &"BlueButton" if i == _mode else &"CreamButton"
	var cost: float = gs.upgrade_cost(key, n)
	_buy.text = "%s  %s" % [tr("UPGRADE"), NumFormat.short(cost)]
	_buy.theme_type_variation = &"" if gs.coins >= cost else &"DarkButton"
	_close.visible = not docked


func _process(delta: float) -> void:
	_t += delta
	if _hero and _hero.visible and is_visible_in_tree():
		_hero.queue_redraw()


func _draw_hero() -> void:
	var s := _hero.size
	var i := GameState.depth_index(key)
	if key == "lift":
		LiftView.draw_hero(_hero, s, _t, Balance.lift_look(GameState.get_level(key)))
		_draw_manager(s, Color("2283b6"))
		return
	var bg: Color = Art.DEPTH_STYLE[i]["water"] if i >= 0 else Art.SKY_TOP
	var frame := Rect2(Vector2(2, 2), s - Vector2(4, 4))
	Art.t_rect(_hero, frame, 18, bg, 4.0, 0.0)
	var ground := Rect2(Vector2(6, s.y - 46), Vector2(s.x - 12, 40))
	if i >= 0:
		var st: Dictionary = Art.DEPTH_STYLE[i]
		Art.t_rect(_hero, ground, 14, st["floor"], 0.0, 0.0)
		Art.flat(_hero, Art.circle_pts(Vector2(s.x - 110, s.y - 70), 80, 32), Color(st["ore"], 0.15))
		OreArt.deposit(_hero, Vector2(s.x - 100, s.y - 36), 90, i, i * 31 + 3, _t, 5)
		Chars.diver(_hero, Vector2(s.x - 210, s.y - 30), 1.3, st["suit"], 1.0, 0.0, 0.0, "dig",
				fposmod(_t * 0.7, 1.0), false, st["ore"], "focus", Chars.blinking(_t, 3.0), _t, i)
	else:
		Art.t_rect(_hero, ground, 14, Art.SEA_TOP, 0.0, 0.0)
		# Later stages are taller: shrink them to fit the box.
		var bs := minf(1.1, (s.y - 44.0) / Props.boat_height(Props.current_stage(key)))
		Art.push(_hero, Vector2(s.x - 170, s.y - 34 + sin(_t * 1.6) * 3.0), sin(_t * 1.4) * 0.03, Vector2(bs, bs))
		if GameState.is_boat(key):
			Props.boat(_hero, _t, 2, Art.DEPTH_STYLE[0]["ore2"], GameState.has_manager(key), "happy", Chars.blinking(_t, 7.0), Callable(), key)
		else:
			Art.pop(_hero)
			var ps := minf(1.0, (s.y - 44.0) / Props.plant_height(Props.current_stage(key)))
			Art.push(_hero, Vector2(s.x - 250, s.y - 36), 0.0, Vector2(ps, ps))
			Props.plant(_hero, _t, true, _t * 3.0, 0.0, key)
		Art.pop(_hero)
	_draw_manager(s, bg)


## The manager, or an empty chair waiting for one.
func _draw_manager(s: Vector2, bg: Color) -> void:
	if GameState.has_manager(key):
		Chars.portrait(_hero, Vector2(70, s.y / 2.0), 56, Chars.manager_look(key), "happy", Chars.blinking(_t, 5.0), bg.lightened(0.4))
	else:
		Art.t_circle(_hero, Vector2(70, s.y / 2.0), 52, Color(1, 1, 1, 0.25), 3.0, 0.0)
		Art.text(_hero, Vector2(70, s.y / 2.0 + 12), "?", 40, Art.WHITE, 7)
