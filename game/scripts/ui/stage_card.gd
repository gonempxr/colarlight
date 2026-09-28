class_name StageCard
extends PanelContainer
## Compact cream card for one stage: name, manager portrait, level with
## milestone bar, output per second and an upgrade button that opens the
## upgrade panel.

var key := ""
var world: World

var _name: Label
var _level: Label
var _rate: Label
var _bar: ProgressBar
var _upgrade: Button
var _manager: ManagerBadge
var _tag: Label


func _init(stage_key: String) -> void:
	key = stage_key


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_name = Label.new()
	_name.theme_type_variation = &"InkLabel"
	_name.add_theme_font_override("font", UiTheme.heavy_font())
	_name.add_theme_font_size_override("font_size", 19)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = 150
	box.add_child(_name)

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
	_bar.custom_minimum_size = Vector2(80, 14)
	_bar.max_value = 1.0
	lv.add_child(_bar)
	_rate = Label.new()
	_rate.theme_type_variation = &"InkLabel"
	_rate.add_theme_font_size_override("font_size", 19)
	_rate.add_theme_color_override("font_color", Art.GREEN_DARK)
	lv.add_child(_rate)

	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(0, 62)
	_upgrade.add_theme_font_size_override("font_size", 24)
	_upgrade.icon = Icons.get_icon("arrow", 30)
	_upgrade.expand_icon = false
	_upgrade.pressed.connect(_on_upgrade)
	box.add_child(_upgrade)

	_tag = Label.new()
	_tag.theme_type_variation = &"InkLabel"
	_tag.add_theme_font_size_override("font_size", 16)
	_tag.add_theme_color_override("font_color", Color("d8363c"))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.visible = false
	box.add_child(_tag)
	refresh()


func _on_upgrade() -> void:
	if Scroller.is_drag():
		return
	Sfx.play("click")
	world.select(key)


func refresh() -> void:
	var gs := GameState
	var data := GameState.stage_data(key)
	match key:
		"boat":
			_name.text = tr("STAGE_BOAT")
		"plant":
			_name.text = tr("STAGE_PLANT")
		_:
			_name.text = tr("DEPTH_%s" % String(data["id"]).to_upper())
	var level: int = gs.get_level(key)
	_level.text = tr("LEVEL") % level
	var ms := Balance.milestones(level)
	var prev := 0 if ms == 0 else (Balance.MILESTONE_FIRST if ms == 1 else (ms - 1) * Balance.MILESTONE_STEP)
	var next := Balance.MILESTONE_FIRST if ms == 0 else ms * Balance.MILESTONE_STEP
	_bar.value = float(level - prev) / float(maxi(1, next - prev))
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(gs.rate(key))
	var cost: float = gs.upgrade_cost(key)
	_upgrade.text = NumFormat.short(cost)
	_upgrade.theme_type_variation = &"" if gs.coins >= cost else &"DarkButton"
	var group := key if key in ["boat", "plant"] else "dives"
	_tag.visible = gs.bottleneck() == group and gs.next_depth() != "d1"
	_tag.text = tr("BOTTLENECK")
	_manager.queue_redraw()
