class_name Tutor
extends Control
## First-minutes guide: one goal at a time, a bouncing hand pointing at the
## thing to tap and a short speech bubble. Each step starts when it makes
## sense (enough coins, ore waiting) and ends when the player does it.
## Progress.tutorial_step remembers where the player is.

const STEPS := ["tap_divers", "upgrade", "tap_boat", "tap_plant", "hire_boat", "hire_plant", "open_depth"]
const DONE := 7

var main: Node
var _t := 0.0
var _taps := 0
var _target := Vector2.ZERO
var _has_target := false
var _text := ""
var _bubble: PanelContainer
var _label: Label
var _last_step := -1


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
	GameState.upgraded.connect(func(k, _c): if k == "d0" and _step() == 1: _next())
	GameState.manager_hired.connect(func(k):
		if (k == "boat" and _step() == 4) or (k == "plant" and _step() == 5):
			_next())
	GameState.depth_opened.connect(func(_k): if _step() == 6: _next())


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
		2:
			skip = GameState.has_manager("boat")
		3:
			skip = GameState.has_manager("plant")
		4:
			skip = GameState.has_manager("boat")
		5:
			skip = GameState.has_manager("plant")
		6:
			skip = GameState.is_open("d1")
	if skip:
		Progress.advance_tutorial(s + 1)


## Screen point to point at for the current step, or null while waiting.
func _find_target() -> Variant:
	var world: World = main._world
	var s := _step()
	match s:
		0:
			var row: DepthRow = world.rows[0]
			return _world_point(row.position + Vector2(row.deposit_pos().x - 40, 150))
		1:
			if GameState.coins >= GameState.upgrade_cost("d0"):
				return _control_point(world.rows[0].card._upgrade)
		2:
			if GameState.hold > 0.0 and GameState.cycle_progress("boat") < 0.0:
				return _world_point(world.surface.boat_world_pos() + Vector2(0, -40))
		3:
			if GameState.dock > 0.0 and GameState.cycle_progress("plant") < 0.0:
				return _world_point(world.surface.plant_world_pos() + Vector2(40, -80))
		4:
			if GameState.coins >= GameState.manager_cost("boat"):
				return _control_point(world.surface.boat_card._manager)
		5:
			if GameState.coins >= GameState.manager_cost("plant"):
				return _control_point(world.surface.plant_card._manager)
		6:
			if GameState.coins >= GameState.unlock_cost("d1"):
				return _control_point(world.rows[1]._open_btn)
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
	var target = _find_target() if active and s < DONE else null
	_has_target = target != null and target.x > -9000.0
	if _has_target:
		_target = target
		# Bring the target into view once per step.
		if s != _last_step:
			_last_step = s
			var view := get_viewport_rect()
			if not view.grow(-80).has_point(_target):
				main.scroll_to_screen_point(_target)
				return
		_text = tr("TUT_" + STEPS[s].to_upper())
	_bubble.visible = _has_target
	if _has_target:
		_label.text = _text
		var v := get_viewport_rect().size
		_bubble.custom_minimum_size.x = minf(520.0, v.x - 40.0)
		_bubble.reset_size()
		var below := _target.y < v.y * 0.45
		var y := _target.y + 130.0 if below else _target.y - 130.0 - _bubble.size.y
		_bubble.position = Vector2(clampf(_target.x - _bubble.size.x / 2.0, 20.0, v.x - _bubble.size.x - 20.0), clampf(y, 120.0, v.y - _bubble.size.y - 20.0))
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	var bounce := absf(sin(_t * 4.0)) * 18.0 if not Settings.reduce_motion else 6.0
	# Soft ring pulsing around the target.
	var pr := fmod(_t, 1.2) / 1.2
	Art.arc(self, _target, 30.0 + pr * 36.0, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - pr)), 6.0)
	# The hand, pointing up-left at the target from below-right.
	var p := _target + Vector2(26, 34) + Vector2(1, 1) * bounce * 0.7
	Art.push(self, p, -0.55)
	var skin := Color("ffd0a8")
	Art.t_rect(self, Rect2(-9, -46, 18, 40), 9, skin, 3.5, 0.3)                     # finger
	Art.t_rect(self, Rect2(-20, -14, 44, 44), 14, skin, 3.5, 0.4)                   # palm
	Art.t_ellipse(self, Vector2(-20, 6), Vector2(10, 7), skin, 3.0, 0.2, -0.6)      # thumb
	Art.t_rect(self, Rect2(-18, 26, 40, 14), 5, Color("3aa6f0"), 3.0, 0.3)          # sleeve
	Art.flat(self, Art.ellipse_pts(Vector2(-3, -38), Vector2(3, 5)), Color(1, 1, 1, 0.6))
	Art.pop(self)
