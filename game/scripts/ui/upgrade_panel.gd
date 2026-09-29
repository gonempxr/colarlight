class_name UpgradePanel
extends PanelContainer
## Details and buying for one stage: what it does, output now and after
## the purchase, next milestone, x1 / x10 / MAX.
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


func _on_buy() -> void:
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
	match key:
		"boat":
			name = tr("STAGE_BOAT")
			desc = tr("DESC_BOAT")
			what = tr("STAT_CARRY")
		"plant":
			name = tr("STAGE_PLANT")
			desc = tr("DESC_PLANT")
			what = tr("STAT_PROCESS")
		_:
			name = tr("DEPTH_%s" % String(data["id"]).to_upper())
			desc = tr("DESC_DEPTH")
			what = tr("STAT_OUTPUT")
	_title.text = "%s · %s" % [name, tr("LEVEL") % gs.get_level(key)]
	_desc.text = desc
	var level: int = gs.get_level(key)
	var ms := Balance.milestones(level)
	var next_ms := Balance.MILESTONE_FIRST if ms == 0 else ms * Balance.MILESTONE_STEP
	var lines: Array[String] = []
	lines.append("%s: %s" % [what, tr("PER_SEC") % NumFormat.rate(gs.rate(key))])
	if GameState.depth_index(key) >= 0:
		lines.append("%s: %d" % [tr("STAT_DIVERS"), gs.divers(key)])
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
	var bg: Color = Art.DEPTH_STYLE[i]["water"] if i >= 0 else Art.SKY_TOP
	var frame := Rect2(Vector2(2, 2), s - Vector2(4, 4))
	Art.t_rect(_hero, frame, 18, bg, 4.0, 0.0)
	var ground := Rect2(Vector2(6, s.y - 46), Vector2(s.x - 12, 40))
	if i >= 0:
		var st: Dictionary = Art.DEPTH_STYLE[i]
		Art.t_rect(_hero, ground, 14, st["floor"], 0.0, 0.0)
		Art.flat(_hero, Art.circle_pts(Vector2(s.x - 110, s.y - 70), 80, 32), Color(st["ore"], 0.15))
		Art.crystals(_hero, Vector2(s.x - 100, s.y - 36), 90, st, i * 31 + 3, 5)
		var hit := fposmod(_t * 1.4, 1.0)
		Chars.diver(_hero, Vector2(s.x - 210, s.y - 30), 1.3, st["suit"], 1.0, 0.0, 0.0, "pick",
				1.0 - absf(hit * 2.0 - 1.0), false, st["ore"], "focus", Chars.blinking(_t, 3.0), _t)
	else:
		Art.t_rect(_hero, ground, 14, Art.SEA_TOP, 0.0, 0.0)
		Art.push(_hero, Vector2(s.x - 170, s.y - 34 + sin(_t * 1.6) * 3.0), sin(_t * 1.4) * 0.03, Vector2(1.1, 1.1))
		if key == "boat":
			Props.boat(_hero, _t, 2, Art.DEPTH_STYLE[0]["ore2"], GameState.has_manager("boat"), "happy", Chars.blinking(_t, 7.0))
		else:
			Art.pop(_hero)
			Art.push(_hero, Vector2(s.x - 250, s.y - 36), 0.0, Vector2(1.0, 1.0))
			Props.plant(_hero, _t, true, _t * 3.0, 0.0)
		Art.pop(_hero)
	# The manager, or an empty chair waiting for one.
	if GameState.has_manager(key):
		Chars.portrait(_hero, Vector2(70, s.y / 2.0), 56, Chars.manager_look(key), "happy", Chars.blinking(_t, 5.0), bg.lightened(0.4))
	else:
		Art.t_circle(_hero, Vector2(70, s.y / 2.0), 52, Color(1, 1, 1, 0.25), 3.0, 0.0)
		Art.text(_hero, Vector2(70, s.y / 2.0 + 12), "?", 40, Art.WHITE, 7)
