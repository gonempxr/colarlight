class_name Tutor
extends Control
## First-minutes guide: one goal at a time, a bouncing hand pointing at the
## thing to tap and a short speech bubble. Each step starts when it makes
## sense (enough coins, ore waiting) and ends when the player does it.
## Progress.tutorial_step remembers where the player is.

## Progress keeps the step index; when steps change, Progress remaps old
## saves (Progress.TUTORIAL_V1_TO_V2). Steps 9.. came with the three rooms:
## players who had finished the old tutorial meet the accountant, the
## evolution and the map next.
const STEPS := ["tap_divers", "tap_lift", "tap_boat", "tap_plant", "upgrade", "hire_lift", "hire_boat", "hire_plant", "open_depth",
		"hire_vault", "evo", "map"]
const DONE := 12

var main: Node
var _t := 0.0
var _taps := 0
var _target := Vector2.ZERO
var _has_target := false
## Where the hand is drawn: it glides to a new target (a new step, a hint)
## instead of jumping, and sticks to a target that moves (scrolling).
var _hand := Vector2.ZERO
var _glide_from := Vector2.ZERO
var _glide := 1.0
var _had_target := false
var _glide_target_last := Vector2.ZERO
var _text := ""
var _bubble: PanelContainer
var _label: Label
var _last_step := -1
## A hint from the lightbulb: point here for a few seconds (after the tutorial).
var _hint_point := Callable()
var _hint_text := ""
var _hint_left := 0.0
var _hint_scrolled := false
## The text key the hand shows now (tests read it).
var key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_bubble.theme_type_variation = &"ToastPanel"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 25)
	_bubble.add_child(_label)
	add_child(_bubble)
	# Players from before the tutorial existed skip it.
	if Progress.tutorial_step == 0 and GameState.total_earned > 3000.0:
		Progress.advance_tutorial(DONE)
	GameState.tapped.connect(_on_tapped)
	GameState.upgraded.connect(func(k, _c): if k == "d0" and _step() == 4: _next())
	GameState.manager_hired.connect(func(k):
		if (k == "lift" and _step() == 5) or (k == "boat" and _step() == 6) or (k == "plant" and _step() == 7) or (k == "vault" and _step() == 9):
			_next())
	GameState.depth_opened.connect(func(k): if k == "d1" and _step() == 8: _next())
	GameState.evo_bought.connect(func(_f): if _step() == 10: _next())


## The map was opened (the mini-map's step ends).
func on_map_opened() -> void:
	if _step() == 11:
		_next()


func show_hint(point: Callable, text: String, seconds: float = 7.0) -> void:
	_hint_point = point
	_hint_text = text
	_hint_left = seconds
	_hint_scrolled = false


func _step() -> int:
	return Progress.tutorial_step


func _next() -> void:
	Progress.advance_tutorial(_step() + 1)
	_taps = 0
	Sfx.play("pop", 1.3)


func _on_tapped(key: String) -> void:
	match _step():
		0:
			if key == "d0":
				_taps += 1
				if _taps >= 3:
					_next()
		1:
			if key == "lift":
				_next()
		2:
			if key == "boat":
				_next()
		3:
			if key == "plant":
				_next()


## Skips steps that no longer apply (managers already hired and so on).
func _skip_done() -> void:
	var s := _step()
	var skip := false
	match s:
		1, 5:
			skip = GameState.has_manager("lift")
		2, 6:
			skip = GameState.has_manager("boat")
		3, 7:
			skip = GameState.has_manager("plant")
		8:
			skip = GameState.is_open("d1")
		9:
			skip = GameState.has_manager("vault")
		10:
			skip = GameState.evo > 0
		11:
			skip = GameState.location > 0
	if skip:
		Progress.advance_tutorial(s + 1)


## Coins the step waits for (0: none).
func _step_cost(s: int) -> float:
	match s:
		4:
			return GameState.upgrade_cost("d0")
		5:
			return GameState.manager_cost("lift")
		6:
			return GameState.manager_cost("boat")
		7:
			return GameState.manager_cost("plant")
		8:
			return GameState.unlock_cost("d1")
		9:
			return GameState.manager_cost("vault")
		10:
			return GameState.evo_cost(GameState.evo + 1)
	return 0.0


## Room a step's target lives in.
func _step_room(s: int) -> int:
	match s:
		3, 7:
			return 1
		9:
			return 2
	return 0


## [screen point, text key] for the current step, or null while waiting.
## A target in another room points at that room's tab first; while the
## coins the step needs sit in the vault, it points at the vault first.
func _find_target() -> Variant:
	var s := _step()
	var cost := _step_cost(s)
	var gs := GameState
	if cost > 0.0 and gs.coins < cost and gs.coins + gs.vault >= cost and not gs.has_manager("vault"):
		return _go(2, "collect")
	var p = _step_target(s)
	if p == null:
		return null
	var room := _step_room(s)
	if room != main.current_room():
		return _go(room, "")
	return [p, "TUT_" + STEPS[s].to_upper()]


## Point at the room's tab, or at the vault's Collect once there.
func _go(room: int, what: String) -> Variant:
	if room == main.current_room():
		if what == "collect":
			var office: OfficeRoom = main._office
			var r := office.slot_rect("collect")
			return [office.get_global_transform_with_canvas() * r.get_center(), "TUT_COLLECT"]
		return null
	var tabs: RoomTabs = main.room_tabs()
	var rect := tabs.tab_rect(room)
	var key2 := "TUT_GO_" + String(main.ROOMS[room]).to_upper()
	if what == "collect":
		key2 = "TUT_VAULT"
	return [tabs.get_global_transform_with_canvas() * rect.get_center(), key2]


func _step_target(s: int) -> Variant:
	var world: World = main._world
	match s:
		0:
			var row: DepthRow = world.rows[0]
			return _world_point(row.position + Vector2(row.deposit_pos().x - 40, 150))
		1:
			if GameState.pit > 0.0 and GameState.cycle_progress("lift") < 0.0:
				return _world_point(world.lift.cabin_pos() + Vector2(0, -30))
		2:
			if GameState.hold > 0.0 and GameState.cycle_progress("boat") < 0.0:
				return _world_point(world.surface.boat_world_pos() + Vector2(0, -40))
		3:
			if GameState.dock > 0.0 and GameState.cycle_progress("plant") < 0.0:
				var f: FactoryRoom = main._factory
				return f.get_global_transform_with_canvas() * f.line_rect("plant").get_center()
		4:
			if GameState.coins >= GameState.upgrade_cost("d0"):
				return _control_point(world.rows[0].card._upgrade)
		5:
			if GameState.coins >= GameState.manager_cost("lift"):
				return _control_point(main.stage_card("lift")._manager)
		6:
			if GameState.coins >= GameState.manager_cost("boat"):
				return _control_point(main.stage_card("boat")._manager)
		7:
			if GameState.coins >= GameState.manager_cost("plant"):
				return _control_point(main.stage_card("plant")._manager)
		8:
			if GameState.coins >= GameState.unlock_cost("d1"):
				return _control_point(world.rows[1]._open_btn)
		9:
			if GameState.coins >= GameState.manager_cost("vault"):
				return _control_point(main.office_bar().button("vault"))
		10:
			if GameState.can_buy_evo():
				return _control_point(main.evo_card().button())
		11:
			if GameState.has_manager("vault") and GameState.evo > 0:
				return _control_point(main._mini if main._wide else main._mini_world)
	return null


func _world_point(p: Vector2) -> Vector2:
	return main._world.get_global_transform_with_canvas() * p


func _control_point(c: Control) -> Vector2:
	if c == null or not c.is_visible_in_tree():
		return Vector2(-9999, -9999)
	return c.get_global_rect().get_center()


func _process(delta: float) -> void:
	_t += delta
	var s := _step()
	var active: bool = s < DONE and not main._modal.visible and not main.is_busy()
	if active:
		_skip_done()
		s = _step()
	var found = _find_target() if active and s < DONE else null
	var target = found[0] if found != null else null
	_hint_left = maxf(0.0, _hint_left - delta)
	var hinting := false
	if target == null and _hint_left > 0.0 and _hint_point.is_valid() and not main._modal.visible:
		target = _hint_point.call()
		hinting = target != null
		if hinting and not _hint_scrolled:
			_hint_scrolled = true
			if not get_viewport_rect().grow(-80).has_point(target):
				main.scroll_to_screen_point(target)
				return
	_has_target = target != null and target.x > -9000.0
	if _has_target and hinting:
		_target = target
		_text = _hint_text
		key = ""
	elif _has_target:
		_target = target
		# Bring the target into view once per step.
		if s != _last_step:
			_last_step = s
			var view := get_viewport_rect()
			if not view.grow(-80).has_point(_target):
				main.scroll_to_screen_point(_target)
				return
		key = found[1]
		_text = tr(key)
	_bubble.visible = _has_target
	if _has_target and _had_target and _target.distance_to(_glide_target_last) > 40.0 and not Settings.reduce_motion:
		_glide_from = _hand
		_glide = 0.0
	_glide_target_last = _target
	_glide = minf(1.0, _glide + delta / 0.45)
	_hand = _target if not _had_target else _glide_from.lerp(_target, Motion.ease_in_out(_glide))
	_had_target = _has_target
	if _has_target:
		_label.text = _text
		var v := get_viewport_rect().size
		_bubble.custom_minimum_size.x = minf(520.0, v.x - 40.0)
		_bubble.reset_size()
		var below := _target.y < v.y * 0.45
		var y := _hand.y + 130.0 if below else _hand.y - 130.0 - _bubble.size.y
		_bubble.position = Vector2(clampf(_hand.x - _bubble.size.x / 2.0, 20.0, v.x - _bubble.size.x - 20.0), clampf(y, 120.0, v.y - _bubble.size.y - 20.0))
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	# The hand taps the target from the lower right; its rings pulse out
	# from the fingertip on every press.
	PointerArt.draw(self, _hand + Vector2(6, 8), _t, not Settings.reduce_motion, -0.5, 1.15)
