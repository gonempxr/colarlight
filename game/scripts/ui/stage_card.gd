class_name StageCard
extends PanelContainer
## Compact cream card for one stage: a coloured name tab, manager portrait,
## level with milestone bar, output per second and an upgrade button that
## opens the upgrade panel. The boat and the plant also show their building
## stage (1..15). With `hero` the card also shows a picture of the stage
## (the PC side column).

var key := ""
var world: World
var hero := false

var _name: Label
var _level: Label
var _rate: Label
var _bar: ProgressBar
var _upgrade: Button
var _manager: ManagerBadge
var _tag: Label
var _head: PanelContainer
var _stage: Label
var _pic: ArtView


func _init(stage_key: String) -> void:
	key = stage_key


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
	_name.custom_minimum_size.x = 150
	_head.add_child(_name)
	if key in ["boat", "plant"]:
		_stage = Label.new()
		_stage.theme_type_variation = &"SoftLabel"
		_stage.add_theme_font_override("font", UiTheme.heavy_font())
		_stage.add_theme_font_size_override("font_size", 16)
		_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stage.custom_minimum_size.x = 150
		box.add_child(_stage)
	if hero:
		_pic = ArtView.make(_draw_hero, Vector2(0, 150), true)
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


static func head_color(stage_key: String) -> Color:
	match stage_key:
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
	match key:
		"boat":
			var bs := minf(0.9, s.y * 0.62 / Props.boat_height(Props.current_stage("boat")))
			Art.push(ci, Vector2(s.x * 0.5, s.y * 0.7), 0.0, Vector2(bs, bs))
			Props.boat(ci, t, 2, Art.DEPTH_STYLE[0]["ore2"], GameState.has_manager("boat"), "happy", Chars.blinking(t, 7.0))
			Art.pop(ci)
		"plant":
			Art.flat(ci, Art.rrect_pts(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), 14.0), Color("f5d58f"))
			var ps := minf(0.75, s.y * 0.72 / Props.plant_height(Props.current_stage("plant")))
			Art.push(ci, Vector2(s.x * 0.5, s.y * 0.8), 0.0, Vector2(ps, ps))
			Props.plant(ci, t, GameState.cycle_progress("plant") >= 0.0, t * 2.0, 0.0)
			Art.pop(ci)


func _on_upgrade() -> void:
	if Scroller.is_drag():
		return
	Sfx.play("click")
	world.select(key)


func refresh() -> void:
	var gs := GameState
	var data := GameState.stage_data(key)
	var level: int = gs.get_level(key)
	match key:
		"boat":
			_name.text = tr("STAGE_BOAT")
		"plant":
			_name.text = tr("STAGE_PLANT")
		_:
			_name.text = tr("DEPTH_%s" % String(data["id"]).to_upper())
	if _stage:
		var st := Balance.building_stage(level)
		_stage.text = "%s  ★%d/%d" % [tr("%s_STAGE_%d" % [key.to_upper(), st]), st, Balance.BUILDING_STAGES]
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
