class_name LiftCard
extends StageCard
## The lift's compact card: one row (manager slot, name and level, upgrade
## button) in the water at the top of the shaft. Only phones with a big UI
## size use it, where the sky's card row has no room for a third card
## (LiftView picks); it never covers the depth cards. A tap on the card
## itself taps the lift like a tap on the cabin.

var lift: LiftView


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_manager = ManagerBadge.new(key)
	row.add_child(_manager)

	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 2)
	mid.custom_minimum_size.x = 118
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	_head = PanelContainer.new()
	var hsb := ToonBox.make(head_color("lift"), 10, 0)
	hsb.line_w = 3.0
	hsb.gloss = 0.25
	hsb.content_margin_left = 8
	hsb.content_margin_right = 8
	hsb.content_margin_top = 0
	hsb.content_margin_bottom = 2
	_head.add_theme_stylebox_override("panel", hsb)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_head)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.heavy_font())
	_name.add_theme_font_size_override("font_size", 17)
	_name.add_theme_constant_override("outline_size", 6)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_head.add_child(_name)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	mid.add_child(line)
	_level = Label.new()
	_level.theme_type_variation = &"InkLabel"
	_level.add_theme_font_override("font", UiTheme.heavy_font())
	_level.add_theme_font_size_override("font_size", 20)
	line.add_child(_level)
	_rate = Label.new()
	_rate.theme_type_variation = &"InkLabel"
	_rate.add_theme_font_size_override("font_size", 17)
	_rate.add_theme_color_override("font_color", Art.GREEN_DARK)
	_rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_rate)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(80, 12)
	_bar.max_value = 1.0
	mid.add_child(_bar)
	_tag = Label.new()
	_tag.theme_type_variation = &"InkLabel"
	_tag.add_theme_font_size_override("font_size", 15)
	_tag.add_theme_color_override("font_color", Color("d8363c"))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.visible = false
	mid.add_child(_tag)

	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(112, 62)
	_upgrade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_upgrade.add_theme_font_size_override("font_size", 22)
	_upgrade.icon = Icons.get_icon("arrow", 26)
	_upgrade.expand_icon = false
	_upgrade.pressed.connect(_on_upgrade)
	row.add_child(_upgrade)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag() or lift == null:
			return
		lift.tap(true)
		accept_event()


func show_unit(_stage_key: String) -> void:
	refresh()


func refresh() -> void:
	if _level == null:
		return
	var gs := GameState
	var level: int = gs.get_level("lift")
	_name.text = "%s ★%d" % [Views.stage_name("lift"), Balance.lift_look(level)]
	_level.text = tr("LEVEL") % level
	_rate.text = "+" + tr("PER_SEC") % NumFormat.rate(gs.rate("lift"))
	var ms := Balance.milestones(level)
	var prev := 0 if ms == 0 else (Balance.MILESTONE_FIRST if ms == 1 else (ms - 1) * Balance.MILESTONE_STEP)
	var next := Balance.MILESTONE_FIRST if ms == 0 else ms * Balance.MILESTONE_STEP
	_bar.value = float(level - prev) / float(maxi(1, next - prev))
	var cost: float = gs.upgrade_cost("lift")
	_upgrade.text = NumFormat.short(cost)
	_upgrade.theme_type_variation = &"" if gs.coins >= cost else &"DarkButton"
	var neck: bool = StageCard.bottleneck_cached() == "lift" and StageCard.next_depth_cached() != "d1"
	_tag.visible = neck
	_tag.text = tr("BOTTLENECK")
	_bar.visible = not neck
	_manager.queue_redraw()
