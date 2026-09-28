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


func _ready() -> void:
	theme_type_variation = &"SheetPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.heavy_font())
	_title.add_theme_font_size_override("font_size", 32)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_close = Button.new()
	_close.text = "×"
	_close.theme_type_variation = &"DarkButton"
	_close.custom_minimum_size = Vector2(64, 64)
	_close.pressed.connect(func(): closed.emit())
	head.add_child(_close)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 22)
	_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	box.add_child(_desc)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 24)
	box.add_child(_stats)
	_gain = Label.new()
	_gain.add_theme_font_override("font", UiTheme.heavy_font())
	_gain.add_theme_font_size_override("font_size", 28)
	_gain.add_theme_color_override("font_color", Color("8dffb0"))
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
	_buy.custom_minimum_size.y = 84
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
	var after := Balance.output(data["value"], level + n) * gs.income_mult()
	_gain.text = "+%s  →  %s" % [tr("PER_SEC") % NumFormat.rate(after - gs.rate(key)), tr("LEVEL") % (level + n)]
	for i in _modes.size():
		var m: int = MODES[i]
		_modes[i].text = tr("BUY_MAX") if m == -1 else "×%d" % m
		_modes[i].theme_type_variation = &"BlueButton" if i == _mode else &"DarkButton"
	var cost: float = gs.upgrade_cost(key, n)
	_buy.text = "%s  %s" % [tr("UPGRADE"), NumFormat.short(cost)]
	_buy.theme_type_variation = &"" if gs.coins >= cost else &"DarkButton"
	_close.visible = not docked
