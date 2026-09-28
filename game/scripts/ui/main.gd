extends Control
## Main screen. Phone (portrait): top bar, scrolling ocean, upgrade sheet
## sliding up from the bottom. PC (landscape): top bar, ocean on the left,
## upgrade panel docked on the right.

const WIDE_ASPECT := 1.05
const REFRESH_SEC := 0.1
const SIDE_W := 540.0
const TOAST_SEC := 3.0

var _hud: Hud
var _scroller: Scroller
var _world: World
var _panel: UpgradePanel
var _modal: Modal
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _wide := false
var _sheet_open := false
var _refresh_left := 0.0
## Tests and screenshots skip the title screen.
static var show_title := true


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Art.SEA_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scroller = Scroller.new()
	add_child(_scroller)
	_world = World.new()
	_scroller.set_content(_world)
	_world.stage_selected.connect(_on_stage_selected)

	_panel = UpgradePanel.new()
	_panel.closed.connect(_close_sheet)
	add_child(_panel)

	_hud = Hud.new()
	_hud.prestige_pressed.connect(_open_prestige)
	_hud.settings_pressed.connect(_open_settings)
	_hud.avatar_pressed.connect(_open_avatar)
	add_child(_hud)

	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"ToastPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_label)
	add_child(_toast)

	_modal = Modal.new()
	add_child(_modal)

	GameState.changed.connect(_refresh)
	GameState.milestone_reached.connect(_on_milestone)
	GameState.rush_started.connect(func(): _show_toast(tr("RUSH")); Sfx.play("rush"))
	Settings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()
	if show_title:
		var title := TitleScreen.new()
		title.started.connect(_after_title)
		add_child(title)
	else:
		_after_title()


func _after_title() -> void:
	var report := GameState.take_offline_report()
	if not report.is_empty():
		_open_offline(report)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SEC
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_F8:
			GameState.debug_grant()
		KEY_F9:
			GameState.reset_progress()


func _layout() -> void:
	var view := get_viewport_rect().size
	_wide = view.x > view.y * WIDE_ASPECT
	var hud_h := 112.0
	_hud.position = Vector2.ZERO
	_hud.size = Vector2(view.x, hud_h)
	if _wide:
		var side := minf(SIDE_W, view.x * 0.4)
		var world_w := view.x - side - 36.0
		_scroller.position = Vector2(12, hud_h)
		_scroller.size = Vector2(world_w, view.y - hud_h)
		_scroller.zoom = clampf(world_w / 960.0, 1.0, 1.7)
		_scroller.scroll_to(_scroller.scroll)
		_panel.set_docked(true)
		_panel.visible = true
		_panel.position = Vector2(view.x - side - 12.0, hud_h + 12.0)
		_panel.custom_minimum_size = Vector2(side, 0)
		_panel.reset_size()
	else:
		_scroller.position = Vector2(0, hud_h - 8.0)
		_scroller.size = Vector2(view.x, view.y - hud_h + 8.0)
		_scroller.zoom = 1.0
		_scroller.scroll_to(_scroller.scroll)
		_panel.set_docked(false)
		_panel.custom_minimum_size = Vector2(view.x, 0)
		_panel.size = Vector2(view.x, 0)
		_panel.visible = _sheet_open
		_place_sheet()
	_toast.size = Vector2(minf(620.0, view.x - 40.0), 0)
	_toast.position = Vector2((view.x - _toast.size.x) / 2.0, hud_h + 20.0)


func _place_sheet() -> void:
	var view := get_viewport_rect().size
	_panel.reset_size()
	_panel.position = Vector2(0, view.y - _panel.size.y)


func _on_stage_selected(key: String) -> void:
	_panel.show_stage(key)
	if not _wide:
		_sheet_open = true
		_panel.visible = true
		_place_sheet.call_deferred()


func _close_sheet() -> void:
	Sfx.play("click")
	_sheet_open = false
	if not _wide:
		_panel.visible = false


func _refresh() -> void:
	_world.surface.refresh()
	for row in _world.rows:
		row.refresh()
	if _panel.visible:
		_panel.refresh()
		if not _wide:
			_place_sheet()
		else:
			_panel.reset_size()


func _on_settings_changed() -> void:
	_refresh()
	if _modal.visible:
		_modal.rebuild()


func _on_milestone(key: String, level: int) -> void:
	var name := ""
	match key:
		"boat":
			name = tr("STAGE_BOAT")
		"plant":
			name = tr("STAGE_PLANT")
		_:
			name = tr("DEPTH_%s" % String(GameState.stage_data(key)["id"]).to_upper())
	_show_toast(tr("MILESTONE_TOAST") % [name, level])
	Sfx.play("milestone")


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SEC)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


# --- Dialogs ------------------------------------------------------------------

func _open_settings() -> void:
	var confirm_reset := [false]
	_modal.open(func(m: Modal):
		m.title(tr("SETTINGS"))
		m.button("%s: %s" % [tr("LANGUAGE"), Settings.LANGUAGE_NAMES[Settings.language]], func(): Settings.next_language(), &"BlueButton")
		m.button("%s: %s" % [tr("SOUND"), tr("ON") if Settings.sound else tr("OFF")], func(): Settings.set_sound(not Settings.sound), &"BlueButton")
		m.button("%s: %s" % [tr("MUSIC"), tr("ON") if Settings.music else tr("OFF")], func(): Settings.set_music(not Settings.music), &"BlueButton")
		var reset: Button
		reset = m.button(tr("RESET"), func():
			if confirm_reset[0]:
				GameState.reset_progress()
				_modal.close()
			else:
				confirm_reset[0] = true
				reset.text = tr("RESET_CONFIRM"), &"RedButton")
		m.text(tr("CREDITS"), 16, Art.INK_SOFT)
		m.button(tr("CLOSE"), func(): _modal.close(), &"CreamButton"))


func _open_avatar() -> void:
	_modal.open(func(m: Modal):
		AvatarEditor.build(m, func(): _modal.close()))


func _open_prestige() -> void:
	_modal.open(func(m: Modal):
		m.title(tr("PRESTIGE"))
		m.text(tr("OCEAN") % (GameState.prestige_count + 1), 26, Color("1c7fb8"))
		var mult := Balance.prestige_mult(GameState.prestige_count + 1)
		m.text(tr("PRESTIGE_DESC") % NumFormat.short(mult))
		if GameState.next_depth() != "":
			m.text(tr("PRESTIGE_NEED_DEPTHS"), 24, Color("d8363c"))
		var go := m.button(tr("PRESTIGE_GO") % NumFormat.short(GameState.prestige_cost()), func():
			if GameState.prestige():
				Sfx.play("prestige")
				_modal.close()
				_scroller.scroll_to(0.0), &"GoldButton")
		go.disabled = not GameState.can_prestige()
		m.button(tr("CLOSE"), func(): _modal.close(), &"CreamButton"))


func _open_offline(report: Dictionary) -> void:
	_modal.open(func(m: Modal):
		m.text(tr("OFFLINE") % NumFormat.duration(report["seconds"]), 24)
		m.title("+" + NumFormat.short(report["coins"]))
		m.button(tr("COLLECT"), func(): Sfx.play("coins"); _modal.close(), &"GoldButton"))
