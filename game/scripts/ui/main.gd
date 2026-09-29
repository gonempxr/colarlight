extends Control
## Main screen. Phone (portrait): top bar, scrolling ocean, the feature dock
## at the bottom and the upgrade sheet sliding up over it. PC (landscape):
## top bar, ocean on the left, upgrade panel and dock on the right.
## Also routes the meta game: dialogs, rewards, the puzzle, players.

const WIDE_ASPECT := 1.05
const REFRESH_SEC := 0.1
const SIDE_W := 540.0
const TOAST_SEC := 3.0
const HUD_H := 112.0
const DOCK_H := 128.0
const PUZZLE_SCRIPT := "res://scripts/puzzle/puzzle_screen.gd"
const LEVELS_SCRIPT := "res://scripts/puzzle/puzzle_levels.gd"

var _hud: Hud
var _scroller: Scroller
var _world: World
var _panel: UpgradePanel
var _dock: Dock
var _dock_laid_out := false
var _modal: Modal
## Second dialog layer above the first (names, feature news).
var _top: Modal
var _fx: FxLayer
var _tutor: Tutor
var _puzzle: Control
var _title: TitleScreen
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _wide := false
var _sheet_open := false
var _refresh_left := 0.0
var _news: Array[String] = []
var _started := false
var _sheet_tween: Tween
## Tests and screenshots skip the title screen.
static var show_title := true


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_ui_scale()
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
	_world.chest.opened.connect(func(r, at): celebrate(r, at))

	_dock = Dock.new()
	_dock.pressed.connect(open_feature)
	add_child(_dock)

	_panel = UpgradePanel.new()
	_panel.closed.connect(_close_sheet)
	add_child(_panel)

	_hud = Hud.new()
	_hud.prestige_pressed.connect(_open_prestige)
	_hud.settings_pressed.connect(_open_settings)
	_hud.avatar_pressed.connect(_open_wardrobe)
	add_child(_hud)

	_tutor = Tutor.new()
	_tutor.main = self
	add_child(_tutor)

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
	_top = Modal.new()
	add_child(_top)
	_top.closed.connect(_show_next_news)
	_modal.closed.connect(_show_next_news)
	_fx = FxLayer.new()
	add_child(_fx)
	_fx.arrived.connect(func(kind): _hud.bump(kind))

	GameState.changed.connect(_refresh)
	GameState.milestone_reached.connect(_on_milestone)
	GameState.rush_started.connect(func(): _show_toast(tr("RUSH")); Sfx.play("rush"))
	Progress.feature_unlocked.connect(func(id):
		_news.append(id)
		_show_next_news())
	Progress.artifact_leveled.connect(func(id, lv):
		_show_toast(tr("ARTIFACT_UP") % [tr("ART_" + id.to_upper()), lv]))
	Progress.item_unlocked.connect(func(id):
		_show_toast(tr("ITEM_UNLOCKED"))
		Sfx.play("unlock"))
	Progress.quest_done.connect(func(_i):
		_show_toast(tr("QUEST_DONE"))
		Sfx.play("milestone"))
	Settings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_layout)
	Wardrobe.apply_looks()
	Progress.changed.connect(Wardrobe.apply_looks)
	_layout()
	_refresh()
	if show_title:
		_title = TitleScreen.new()
		_title.started.connect(_after_title)
		_title.players_pressed.connect(open_players)
		add_child(_title)
		move_child(_title, _modal.get_index())
	else:
		_after_title()


func _after_title() -> void:
	_title = null
	_started = true
	var report := GameState.take_offline_report()
	if not report.is_empty():
		_open_offline(report)
	elif Progress.daily_ready():
		open_feature("daily")


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SEC
		_refresh()
	Scroller.locked = _modal.visible or _top.visible or is_instance_valid(_puzzle) or is_instance_valid(_title)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_F8:
			GameState.debug_grant()
			Progress.add_pearls(50)
		KEY_F9:
			GameState.reset_progress()
			Progress.reset_progress()


## True while something covers the ocean (tutorial waits).
func is_busy() -> bool:
	return _top.visible or is_instance_valid(_puzzle) or is_instance_valid(_title) or (_sheet_open and not _wide)


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = Settings.ui_scale
	Art.low_power = Settings.low_quality()
	World.half_rate = Art.low_power


func _layout() -> void:
	var view := get_viewport_rect().size
	_wide = view.x > view.y * WIDE_ASPECT
	var dock_h := DOCK_H if _dock_laid_out else 0.0
	_hud.position = Vector2.ZERO
	_hud.size = Vector2(view.x, HUD_H)
	if _wide:
		var side := minf(SIDE_W, view.x * 0.4)
		var world_w := view.x - side - 36.0
		_scroller.position = Vector2(12, HUD_H)
		_scroller.size = Vector2(world_w, view.y - HUD_H)
		_scroller.zoom = clampf(world_w / 960.0, 1.0, 1.7)
		_scroller.scroll_to(_scroller.scroll)
		_panel.set_docked(true)
		_panel.visible = true
		_panel.position = Vector2(view.x - side - 12.0, HUD_H + 12.0)
		_panel.custom_minimum_size = Vector2(side, 0)
		_panel.reset_size()
		_dock.fit(side)
		_dock.size = Vector2(side, dock_h)
		_dock.position = Vector2(view.x - side - 12.0, view.y - dock_h)
	else:
		_scroller.position = Vector2(0, HUD_H - 8.0)
		_scroller.size = Vector2(view.x, view.y - HUD_H + 8.0 - dock_h + 10.0)
		_scroller.zoom = 1.0
		_scroller.scroll_to(_scroller.scroll)
		_panel.set_docked(false)
		_panel.custom_minimum_size = Vector2(view.x, 0)
		_panel.size = Vector2(view.x, 0)
		_panel.visible = _sheet_open
		_place_sheet()
		_dock.fit(view.x)
		_dock.size = Vector2(view.x, dock_h)
		_dock.position = Vector2(0, view.y - dock_h)
	_toast.size = Vector2(minf(620.0, view.x - 40.0), 0)
	_toast.position = Vector2((view.x - _toast.size.x) / 2.0, HUD_H + 20.0)


func _place_sheet() -> void:
	var view := get_viewport_rect().size
	_panel.reset_size()
	_panel.position = Vector2(0, view.y - _panel.size.y)


func _on_stage_selected(key: String) -> void:
	_panel.show_stage(key)
	if not _wide:
		var was_open := _sheet_open
		_sheet_open = true
		_panel.visible = true
		_place_sheet.call_deferred()
		if not was_open and not Settings.reduce_motion:
			# Slide up from below the screen.
			(func():
				var y := _panel.position.y
				_panel.position.y = get_viewport_rect().size.y
				_sheet_tween = create_tween()
				_sheet_tween.tween_property(_panel, "position:y", y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)).call_deferred()


func _close_sheet() -> void:
	Sfx.play("click")
	_sheet_open = false
	if not _wide:
		if Settings.reduce_motion:
			_panel.visible = false
			return
		_sheet_tween = create_tween()
		_sheet_tween.tween_property(_panel, "position:y", get_viewport_rect().size.y, 0.16).set_ease(Tween.EASE_IN)
		_sheet_tween.tween_callback(func(): if not _sheet_open: _panel.visible = false)


func _refresh() -> void:
	_world.surface.refresh()
	for row in _world.rows:
		row.refresh()
	if _panel.visible:
		_panel.refresh()
		if not _wide:
			if _sheet_open and not (_sheet_tween and _sheet_tween.is_running()):
				_place_sheet()
		else:
			_panel.reset_size()
	# The dock shows itself when a feature opens (Dock.refresh), so compare
	# with what the layout last made room for, not with its visibility.
	var dock_shown := _dock.count() > 0
	if dock_shown != _dock_laid_out:
		_dock_laid_out = dock_shown
		_dock.visible = dock_shown
		_layout()
		if dock_shown and not Settings.reduce_motion:
			var y := _dock.position.y
			_dock.position.y += DOCK_H
			create_tween().tween_property(_dock, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_settings_changed() -> void:
	if not is_equal_approx(get_tree().root.content_scale_factor, Settings.ui_scale) or Art.low_power != Settings.low_quality():
		_apply_ui_scale()
	_refresh()
	if _modal.visible:
		_modal.rebuild()


func _on_milestone(key: String, level: int) -> void:
	_show_toast(tr("MILESTONE_TOAST") % [Views.stage_name(key), level])
	Sfx.play("milestone")


func _show_toast(text: String) -> void:
	_toast_label.text = text
	# Wrapped labels shrink to one word (one character in Chinese), so give
	# the toast the width its text needs, up to the screen width.
	var view := get_viewport_rect().size
	var font := _toast_label.get_theme_font("font")
	var fs := _toast_label.get_theme_font_size("font_size")
	var need := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 60.0
	_toast.custom_minimum_size.x = minf(minf(620.0, view.x - 40.0), need)
	_toast.reset_size()
	_toast.position.x = (view.x - _toast.size.x) / 2.0
	_toast.modulate.a = 1.0
	_toast.visible = true
	_toast.pivot_offset = _toast.size / 2.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	if not Settings.reduce_motion:
		_toast.scale = Vector2(0.7, 0.7)
		_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_SEC)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


## Screen-space point -> scroll the ocean so it sits in the middle.
func scroll_to_screen_point(p: Vector2) -> void:
	var mid := _scroller.global_position.y + _scroller.size.y * 0.45
	var target := _scroller.scroll + (p.y - mid)
	var tw := create_tween()
	tw.tween_method(func(v: float): _scroller.scroll_to(v), _scroller.scroll, clampf(target, 0.0, _scroller.max_scroll()), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Rewards -------------------------------------------------------------------------

## Shows a reward: coins and pearls fly from `from` into the top bar.
## r: {"coins", "pearls", "boost" (minutes)}.
func celebrate(r: Dictionary, from: Vector2) -> void:
	_fx.burst(from, 26)
	var coins := float(r.get("coins", 0.0))
	var pearls := int(r.get("pearls", 0))
	if coins > 0.0:
		_fx.fly("coin", from, _hud.coin_target(), 8)
		_fx.float_text(from + Vector2(0, -40), "+" + NumFormat.short(coins), Art.GOLD)
	if pearls > 0:
		_fx.fly("pearl", from + Vector2(20, 10), _hud.pearl_target(), mini(pearls, 8))
		_fx.float_text(from + Vector2(0, 10), "+%d" % pearls, Color("f1e6ff"), 34)
	if int(r.get("boost", 0)) > 0:
		_fx.float_text(from + Vector2(0, 50), "×2  " + tr("MINUTES") % int(r["boost"]), Art.GOLD, 34)
	Sfx.play("coins")
	Sfx.voice("yay", 1.1)
	Settings.buzz(30)


# --- Features ------------------------------------------------------------------------

func open_feature(id: String) -> void:
	Progress.seen(id)
	match id:
		"daily":
			_modal.open(func(m): Views.daily(m, self))
		"quests":
			_modal.open(func(m): Views.quests(m, self))
		"museum":
			_modal.open(func(m): Views.museum(m, self), {"wide": true})
		"shop":
			_open_wardrobe()
		"puzzle":
			open_puzzle()


func _show_next_news() -> void:
	if _news.is_empty() or _top.visible or _modal.visible or is_instance_valid(_puzzle) or not _started:
		return
	var id: String = _news.pop_front()
	Sfx.play("unlock")
	var opener := Callable()
	if id in ["daily", "quests", "puzzle", "museum", "shop"]:
		opener = func(): open_feature(id)
	_top.open(func(m): Views.feature_intro(m, id, opener))


func _open_wardrobe() -> void:
	_modal.open(func(m): Wardrobe.build(m, self), {"wide": true})


func open_avatar_editor() -> void:
	_modal.open(func(m: Modal):
		AvatarEditor.build(m, func(): _open_wardrobe()))


# --- Puzzle ------------------------------------------------------------------------------

func open_puzzle() -> void:
	if is_instance_valid(_puzzle) or not ResourceLoader.exists(PUZZLE_SCRIPT):
		return
	_modal.close()
	var level: Dictionary = load(LEVELS_SCRIPT).level(Progress.puzzle_level)
	var target := Progress.target_artifact()
	if target != "":
		level["artifact"] = target
	_puzzle = load(PUZZLE_SCRIPT).new()
	add_child(_puzzle)
	move_child(_puzzle, _fx.get_index())
	_puzzle.setup(level, _puzzle_rewards)
	_puzzle.finished.connect(_on_puzzle_finished)
	_puzzle.tree_exited.connect(func():
		_puzzle = null
		_show_next_news())
	Sfx.play("start")


## Called by the puzzle when a level ends (won, or "collect what you got"):
## grants the rewards and returns the lines its end panel shows.
var _last_puzzle_reward := {}


func _puzzle_rewards(result: Dictionary) -> Array:
	var r := Progress.puzzle_reward(result)
	_last_puzzle_reward = r
	var lines: Array = []
	if r["coins"] > 0.0:
		lines.append(["coin", "+" + NumFormat.short(r["coins"])])
	if r["pearls"] > 0:
		lines.append(["pearl", "+%d" % r["pearls"]])
	if r["piece"] != "":
		var id: String = r["piece"]
		if r["level"] > 0:
			lines.append(["museum", tr("ARTIFACT_UP") % [tr("ART_" + id.to_upper()), r["level"]]])
		else:
			var st: Dictionary = Progress.artifacts[id]
			lines.append(["museum", tr("PIECE_OF") % [tr("ART_" + id.to_upper()), st["pieces"], Progress.pieces_needed(id)]])
	return lines


func _on_puzzle_finished(_result: Dictionary) -> void:
	# The rewards were given when the level ended; now let them fly home.
	if not _last_puzzle_reward.is_empty():
		celebrate({"coins": _last_puzzle_reward["coins"], "pearls": _last_puzzle_reward["pearls"]}, get_viewport_rect().size / 2.0)
		_last_puzzle_reward = {}


# --- Players ------------------------------------------------------------------------------

func open_players() -> void:
	_modal.open(func(m): SettingsView.players(m, self))


## Asks for a name. id "" adds a new player.
func ask_name(id: String, done: Callable) -> void:
	_top.open(func(m: Modal):
		m.title(tr("WHATS_YOUR_NAME"))
		var edit := LineEdit.new()
		edit.max_length = Profiles.NAME_MAX
		edit.placeholder_text = tr("NAME_PLACEHOLDER")
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.custom_minimum_size.y = 84
		edit.text = str(Profiles.find(id).get("name", "")) if id != "" else ""
		m.add(edit)
		var r := m.row(10)
		var dice := Button.new()
		dice.theme_type_variation = &"PurpleButton"
		dice.icon = Icons.get_icon("dice", 36)
		dice.custom_minimum_size = Vector2(90, 76)
		dice.pressed.connect(func():
			Sfx.play("pop")
			edit.text = random_name())
		r.add_child(dice)
		var ok := Button.new()
		ok.text = tr("DONE")
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.custom_minimum_size.y = 76
		var submit := func(_t = ""):
			var name := Profiles.clean_name(edit.text)
			if name == "":
				Sfx.play("deny")
				return
			Sfx.play("click")
			if id == "":
				Profiles.add(name)
			else:
				Profiles.set_name_of(id, name)
			m.close()
			done.call()
		ok.pressed.connect(submit)
		edit.text_submitted.connect(submit)
		r.add_child(ok)
		edit.grab_focus.call_deferred())


static func random_name() -> String:
	var names := TranslationServer.translate("RANDOM_NAMES").split(",")
	return names[randi() % names.size()].strip_edges()


func after_profile_switch() -> void:
	_scroller.scroll_to(0.0)
	_refresh()
	_hud.queue_redraw()
	var report := GameState.take_offline_report()
	if not report.is_empty():
		_show_toast(tr("OFFLINE") % NumFormat.duration(report["seconds"]) + " +" + NumFormat.short(report["coins"]))


# --- Dialogs ------------------------------------------------------------------

func _open_settings() -> void:
	_modal.open(func(m): SettingsView.build(m, self))


func _open_prestige() -> void:
	_modal.open(func(m: Modal):
		m.title(tr("PRESTIGE"))
		m.text(tr("OCEAN") % (GameState.prestige_count + 1), 26, Color("1c7fb8"))
		var mult := Balance.prestige_mult(GameState.prestige_count + 1)
		m.text(tr("PRESTIGE_DESC") % NumFormat.short(mult))
		m.text(tr("PRESTIGE_KEEPS"), 21, Art.INK_SOFT)
		if GameState.next_depth() != "":
			m.text(tr("PRESTIGE_NEED_DEPTHS"), 24, Color("d8363c"))
		var go := m.button(tr("PRESTIGE_GO") % NumFormat.short(GameState.prestige_cost()), func():
			if GameState.prestige():
				Sfx.play("prestige")
				Progress.add_pearls(25)
				Progress.save_game()
				_modal.close()
				_fx.burst(get_viewport_rect().size / 2.0, 60)
				_scroller.scroll_to(0.0), &"GoldButton")
		go.disabled = not GameState.can_prestige()
		m.button(tr("CLOSE"), func(): _modal.close(), &"CreamButton"))


func _open_offline(report: Dictionary) -> void:
	_modal.open(func(m: Modal):
		m.text(tr("OFFLINE") % NumFormat.duration(report["seconds"]), 24)
		m.title("+" + NumFormat.short(report["coins"]))
		var b := m.button(tr("COLLECT"), func(): pass, &"GoldButton")
		b.pressed.connect(func():
			celebrate({"coins": report["coins"]}, b.get_global_rect().get_center())
			_modal.close()
			if Progress.daily_ready():
				(func(): open_feature("daily")).call_deferred()))
