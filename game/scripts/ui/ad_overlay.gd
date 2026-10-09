class_name AdOverlay
extends Control
## Stand-in for a real ad with the "test" provider (?ads=test): a dark screen
## that says it is a pretend ad, counts down 3 seconds and ends as watched.
## Skip ends it early with no reward, to try the failure path too.

var _left := 0.0
var _total := 1.0
var _count: Label
var _bar: ProgressBar
var _title: Label
var _note: Label
var _skip: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.1, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("fffaf0"), 26, 6)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = 420
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	_title = _label("", 40, true)
	box.add_child(_title)
	_note = _label("", 21, false)
	box.add_child(_note)
	_count = _label("3", 64, true)
	_count.add_theme_color_override("font_color", Color("1c7fb8"))
	box.add_child(_count)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, 22)
	box.add_child(_bar)
	_skip = Button.new()
	_skip.theme_type_variation = &"CreamButton"
	_skip.custom_minimum_size = Vector2(0, 68)
	_skip.pressed.connect(func(): _end(false))
	box.add_child(_skip)
	Platform.test_ad_requested.connect(_show)


func _label(s: String, px: int, heavy: bool) -> Label:
	var l := Views.label(s, px, Art.INK, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _show(seconds: float, kind: String = "rewarded") -> void:
	_total = maxf(0.1, seconds)
	_left = _total
	_title.text = tr("AD_TEST")
	_note.text = tr("AD_TEST_BREAK") if kind == "midgame" else tr("AD_TEST_NOTE")
	_skip.text = tr("AD_SKIP_BREAK") if kind == "midgame" else tr("AD_SKIP")
	visible = true
	_update()


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		_end(true)
		return
	_update()


func _update() -> void:
	_count.text = str(ceili(_left))
	_bar.value = 1.0 - _left / _total


func _end(ok: bool) -> void:
	visible = false
	Platform.finish_test_ad(ok)
