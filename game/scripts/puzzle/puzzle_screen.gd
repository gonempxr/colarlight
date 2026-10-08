class_name PuzzleScreen
extends Control
## Full-screen match-3 level: bring the artifact fragments to the bottom row.
##
## Usage (from main or any Control that fills the screen):
##   var p := PuzzleScreen.new()
##   add_child(p)
##   p.setup(PuzzleLevels.level(n), func(result: Dictionary) -> Array:
##       return [["coin", "+500"], ["pearl", "+3"]])
##   p.finished.connect(_on_puzzle_finished)
##
## setup(level, rewards) - `level` is a PuzzleLevels.level() dictionary (any
## key may be overridden, e.g. "artifact"). `rewards` is optional: when the
## level ends (win, or "collect what you got") the screen calls it with the
## result dictionary and shows the returned lines ([icon_name, text], icon
## names from Icons) on the end panel. set_rewards_text(lines) replaces them
## at any time. The screen never grants anything itself.
##
## finished(result) fires once, when the player presses Collect / Collect
## what you got / Leave. The screen then fades out and frees itself.
## result = {"level": int, "won": bool, "fragments": int (collected),
##   "fragments_needed": int, "stars": int (0-3, 0 unless won),
##   "moves_left": int, "artifact": String, "left": bool (quit early)}.

signal finished(result: Dictionary)

const MAX_TILE := 110.0
const HINT_DELAY := 5.0
const EXTRA_MOVES := 5
const TOP_H := 124.0
const KIND_COLORS: Array[Color] = [TileArt.PEARL, TileArt.SHELL, TileArt.STAR, TileArt.CORAL, TileArt.FISH, TileArt.URCHIN]
const NO_CELL := Vector2i(-1, -1)

var model: Match3
var level := {}
var artifact := "compass"
## Cell size in pixels.
var tile := 80.0

var _reward_fn: Callable
var _reward_lines: Array = []
var _reward_box: VBoxContainer

var _bg: Control
var _frame: Control
var _board: Control
var _top: Control
var _pause: Button
var _fx: Control
var _overlay: Control
var _confirm: PanelContainer
var _panel: PanelContainer
var _panel_art: Control
var _wide := false
var _top_rect := Rect2()
var _board_rect := Rect2()

var _grid := {}
var _t := 0.0
var _bg_acc := 0.0
var _board_acc := 0.0
var _queue: Array = []
var _step := {}
var _step_t := 0.0
var _step_dur := 0.0
var _anim := ""
var _anim_from := {}
var _pop_in := {}
var _selected := NO_CELL
var _pressing := false
var _press_cell := NO_CELL
var _press_pos := Vector2.ZERO
var _was_selected := false
var _dragged := false
var _touch_input := false
var _idle := 0.0
var _hint: Array = []
var _intro := 3.5
## Seconds the "bring the pieces down" tip still shows at the level start.
var _tip := 0.0
const TIP_SEC := 6.0
var _shake := 0.0
var _shown_moves := 0
var _shown_frags := 0
var _moves_bump := 0.0
var _goal_bump := 0.0
var _extra_used := false
var _ended := false
var _warned_few := false
var _result := {}

var _parts: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _zaps: Array[Dictionary] = []
var _flyers: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _flash := 0.0
var _bubbles: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.build()
	_touch_input = not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	_rng.seed = 11
	_bg = _layer(_draw_bg)
	_frame = _layer(_draw_frame)
	_board = _layer(_draw_board)
	_board.clip_contents = true
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_board_input)
	_top = _layer(_draw_top)
	_pause = Button.new()
	_pause.theme_type_variation = &"CreamButton"
	_pause.icon = Icons.get_icon("close", 34)
	_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.custom_minimum_size = Vector2(84, 84)
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.pressed.connect(_toggle_confirm)
	add_child(_pause)
	_fx = _layer(_draw_fx)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build_confirm()
	for i in 22:
		_bubbles.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(3.0, 9.0)))
	get_viewport().size_changed.connect(_layout)
	if model == null:
		setup(PuzzleLevels.level(1))
	_layout()


func _layer(painter: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter)
	add_child(c)
	return c


## Starts a level. `rewards` (optional) maps the result to reward lines
## [[icon_name, text], ...] shown on the end panel.
func setup(lv: Dictionary, rewards: Callable = Callable()) -> void:
	level = lv.duplicate()
	artifact = String(level.get("artifact", ArtifactArt.IDS[0]))
	_reward_fn = rewards
	model = Match3.new(level)
	_grid = model.snapshot()
	_shown_moves = model.moves
	_shown_frags = 0
	_extra_used = false
	_ended = false
	_warned_few = false
	_intro = 3.5
	_tip = TIP_SEC
	_queue.clear()
	_step = {}
	_anim = ""
	_selected = NO_CELL
	if is_inside_tree():
		_layout()
		_close_panel()


## Replaces the reward lines on the end panel: [[icon_name, text], ...].
func set_rewards_text(lines: Array) -> void:
	_reward_lines = lines
	_fill_rewards()


func is_busy() -> bool:
	return not _step.is_empty() or not _queue.is_empty()


func shown_moves() -> int:
	return _shown_moves


## Canvas position of a cell's center (for tests and effects).
func cell_screen_pos(c: Vector2i) -> Vector2:
	return _board.global_position + _cell_center(c)


# --- Layout -------------------------------------------------------------------------------

func _layout() -> void:
	if model == null or _board == null:
		return
	var v := get_viewport_rect().size
	_wide = v.x > v.y * 1.05
	var margin := 14.0
	var top_w := minf(v.x - margin * 2.0, 900.0)
	_top_rect = Rect2((v.x - top_w) / 2.0, margin, top_w, TOP_H)
	var avail := Rect2(margin, _top_rect.end.y + 34.0, v.x - margin * 2.0, v.y - _top_rect.end.y - 34.0 - margin)
	if not _wide:
		avail.size.y -= 40.0
	var w := model.width
	var h := model.height
	tile = floorf(minf(minf(avail.size.x / (w + 0.7), avail.size.y / (h + 0.7)), MAX_TILE))
	var bs := Vector2(w, h) * tile
	var pos := avail.position + (avail.size - bs) / 2.0
	_board_rect = Rect2(pos.round(), bs)
	for c: Control in [_bg, _frame, _fx, _overlay]:
		c.position = Vector2.ZERO
		c.size = v
	_board.position = _board_rect.position
	_board.size = _board_rect.size
	_top.position = _top_rect.position
	_top.size = _top_rect.size + Vector2(0, 40)
	_pause.size = _pause.custom_minimum_size
	_pause.position = _top_rect.position + Vector2(_top_rect.size.x - _pause.size.x - 18.0, (TOP_H - _pause.size.y) / 2.0 - 2.0)
	_confirm.reset_size()
	_confirm.position = Vector2(_top_rect.end.x - _confirm.size.x - 6.0, _top_rect.end.y + 6.0)
	_frame.queue_redraw()
	_bg.queue_redraw()
	_board.queue_redraw()
	_top.queue_redraw()


func _cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * tile


func _cell_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / tile), floori(local.y / tile))


func _goal_pos() -> Vector2:
	return _top_rect.position + Vector2(62, TOP_H / 2.0)


# --- Input -----------------------------------------------------------------------------------

func _board_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_pointer(e.pressed, e.position)
	elif e is InputEventMouseMotion:
		if _pressing:
			_drag(e.position)
	elif _touch_input:
		# Only when touches don't also arrive as emulated mouse events.
		if e is InputEventScreenTouch and e.index == 0:
			_pointer(e.pressed, e.position)
		elif e is InputEventScreenDrag and e.index == 0 and _pressing:
			_drag(e.position)


func _pointer(pressed: bool, pos: Vector2) -> void:
	if not pressed:
		if _pressing and not _dragged and _was_selected:
			var c := _press_cell
			_selected = NO_CELL
			if model.special_at(c) != "":
				_run(model.activate(c))
		_pressing = false
		return
	_idle = 0.0
	_hint = []
	if is_busy() or _ended or model.state != Match3.PLAYING or _confirm.visible:
		return
	var c := _cell_at(pos)
	if not model.inside(c):
		return
	if _selected != NO_CELL and _selected != c and absi(_selected.x - c.x) + absi(_selected.y - c.y) == 1:
		var a := _selected
		_selected = NO_CELL
		_try_swap(a, c)
		return
	_pressing = true
	_dragged = false
	_press_pos = pos
	_press_cell = c
	_was_selected = _selected == c
	if model.is_swappable(c):
		if _selected != c:
			Sfx.play("tap", 1.2)
		_selected = c
	else:
		_selected = NO_CELL
		_wobble_blocked(c)
	_board.queue_redraw()


func _drag(pos: Vector2) -> void:
	if _dragged:
		return
	var d := pos - _press_pos
	if d.length() < tile * 0.32:
		return
	_dragged = true
	_pressing = false
	var dir := Vector2i(signi(roundi(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(roundi(d.y)))
	_selected = NO_CELL
	if model.is_swappable(_press_cell):
		_try_swap(_press_cell, _press_cell + dir)


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	if not model.inside(b):
		return
	_run(model.swap(a, b))


func _run(steps: Array) -> void:
	_idle = 0.0
	_hint = []
	if model.moves != _shown_moves:
		_shown_moves = model.moves
		_moves_bump = 1.0
	_queue.append_array(steps)
	if _step.is_empty():
		_next_step()


## A tap on sand or a bubble: a little shake so kids see it's stuck.
func _wobble_blocked(c: Vector2i) -> void:
	if not model.inside(c):
		return
	_anim = "blocked"
	_anim_from = {model.idx(c): 0.0}
	_step_t = 0.0
	Sfx.play("deny", 1.3)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and not _ended:
		_toggle_confirm()
		get_viewport().set_input_as_handled()


# --- Step playback ---------------------------------------------------------------------------

func _next_step() -> void:
	if _queue.is_empty():
		_step = {}
		_anim = ""
		_on_settled()
		return
	_step = _queue.pop_front()
	_step_t = 0.0
	_step_dur = _begin(_step)


func _begin(s: Dictionary) -> float:
	if s.has("grid"):
		_grid = s["grid"]
	_anim = ""
	_anim_from = {}
	match s["type"]:
		"swap":
			_anim = "swap"
			_anim_from[model.idx(s["b"])] = Vector2(s["a"])
			_anim_from[model.idx(s["a"])] = Vector2(s["b"])
			Sfx.play("tap")
			return 0.15
		"bad_swap":
			if s["a"] == s["b"] or not model.inside(s["b"]):
				return 0.01
			_anim = "bad"
			_anim_from[model.idx(s["a"])] = Vector2(s["b"])
			_anim_from[model.idx(s["b"])] = Vector2(s["a"])
			Sfx.play("deny")
			return 0.32
		"clear":
			for i in s["cells"].size():
				_pop(s["cells"][i], s["kinds"][i], s["specials"][i])
			var combo: int = s["combo"]
			Sfx.play("pop", 1.0 + 0.08 * mini(combo - 1, 6))
			if combo >= 2:
				_combo_text(combo)
			return 0.13
		"blocker_hit":
			for h in s["hits"]:
				var p := _board.position + _cell_center(h["cell"])
				if h["blocker"] == "sand":
					_burst(p, Art.SAND, 10, 1.0)
					_burst(p, Art.SAND_DARK, 6, 0.8)
				else:
					_rings.append({"c": p, "r0": tile * 0.3, "r1": tile * 0.75, "age": 0.0, "life": 0.3, "color": Color(1, 1, 1, 0.9), "w": 5.0})
					_bubble_burst(p, 6)
			Sfx.play("pop", 1.35)
			return 0.1
		"special_fire":
			return _fire_fx(s)
		"special_made":
			var i := model.idx(s["cell"])
			_pop_in[i] = 0.0
			var p := _board.position + _cell_center(s["cell"])
			_rings.append({"c": p, "r0": tile * 0.2, "r1": tile * 1.1, "age": 0.0, "life": 0.35, "color": Color(1.0, 0.95, 0.6, 0.95), "w": 7.0})
			_sparkles(p, 8)
			Sfx.play("upgrade", 1.1)
			return 0.2
		"fall":
			_anim = "fall"
			var longest := 0.0
			for m in s["moves"]:
				_anim_from[model.idx(m["to"])] = Vector2(m["from"])
				longest = maxf(longest, m["to"].y - m["from"].y)
			for m in s["spawns"]:
				_anim_from[model.idx(m["to"])] = Vector2(m["from"])
				longest = maxf(longest, m["to"].y - m["from"].y)
			return _fall_time(longest) + 0.07
		"fragment_collected":
			var p := _board.position + _cell_center(s["cell"])
			_flyers.append({"from": p, "age": 0.0, "life": 0.75})
			_sparkles(p, 10)
			_rings.append({"c": p, "r0": tile * 0.3, "r1": tile * 1.2, "age": 0.0, "life": 0.4, "color": Color(1.0, 0.9, 0.4, 0.95), "w": 6.0})
			Sfx.play("chest")
			Sfx.play("voice_yay", 1.1)
			return 0.3
		"shuffle":
			for i in model.width * model.height:
				_pop_in[i] = -0.02 * (i % model.width) - 0.03 * (i / model.width)
			_add_text(tr("PZ_SHUFFLE"), _board_rect.get_center(), 64, Art.WHITE)
			Sfx.play("unlock")
			return 0.55
	return 0.05


func _fall_time(cells: float) -> float:
	return 0.09 + sqrt(maxf(cells, 0.0)) * 0.085


func _fire_fx(s: Dictionary) -> float:
	var c: Vector2i = s["cell"]
	var p := _board.position + _cell_center(c)
	for cl in s["cleared"]:
		_pop(cl["cell"], cl["kind"], cl["special"])
	var sp: String = s["special"]
	var dur := 0.3
	match sp:
		"rocket_h", "rocket_v":
			_beam(c, sp == "rocket_h")
			_shake = maxf(_shake, 0.35)
			Sfx.play("unlock", 1.25)
		"cross":
			_beam(c, true)
			_beam(c, false)
			_shake = maxf(_shake, 0.5)
			Sfx.play("unlock", 1.1)
			dur = 0.34
		"cross3":
			for d in [-1, 0, 1]:
				_beam(c + Vector2i(0, d), true)
				_beam(c + Vector2i(d, 0), false)
			_shake = maxf(_shake, 0.7)
			Sfx.play("chest", 1.2)
			dur = 0.38
		"bomb", "bomb5":
			var big := sp == "bomb5"
			_rings.append({"c": p, "r0": tile * 0.3, "r1": tile * (3.0 if big else 1.8), "age": 0.0, "life": 0.35, "color": Color(1.0, 0.85, 0.35, 0.95), "w": 12.0})
			_rings.append({"c": p, "r0": tile * 0.1, "r1": tile * (2.3 if big else 1.3), "age": -0.05, "life": 0.3, "color": Color(1, 1, 1, 0.9), "w": 6.0})
			_burst(p, Art.GOLD, 14 if big else 9, 1.6)
			_burst(p, Art.CORAL, 8, 1.3)
			_shake = maxf(_shake, 0.8 if big else 0.55)
			Sfx.play("chest", 0.8 if big else 0.95)
			dur = 0.4 if big else 0.32
		"rainbow":
			var targets: Array = s.get("targets", [])
			var i := 0
			for tc in targets:
				_zaps.append({"a": p, "b": _board.position + _cell_center(tc), "age": -0.012 * i, "life": 0.32, "seed": i * 7 + 3})
				i += 1
			_rings.append({"c": p, "r0": tile * 0.2, "r1": tile * 1.4, "age": 0.0, "life": 0.4, "color": Color(1, 1, 1, 0.95), "w": 8.0})
			_sparkles(p, 12)
			Sfx.play("milestone", 1.2)
			dur = 0.3 + 0.012 * targets.size()
			if s.has("convert"):
				dur += 0.15
		"board":
			_flash = 1.0
			for r in 3:
				_rings.append({"c": p, "r0": tile * 0.2, "r1": tile * (3.0 + r * 2.0), "age": -0.08 * r, "life": 0.5, "color": Color(1, 0.95, 0.7, 0.9), "w": 12.0})
			_shake = 1.0
			Sfx.play("milestone")
			Sfx.play("voice_woohoo")
			dur = 0.65
	return dur


func _end_step(s: Dictionary) -> void:
	if s["type"] == "fall":
		_anim = ""


func _on_settled() -> void:
	_board.queue_redraw()
	if _ended:
		return
	match model.state:
		Match3.WON:
			_ended = true
			_selected = NO_CELL
			get_tree().create_timer(0.55).timeout.connect(_show_win)
		Match3.LOST:
			_selected = NO_CELL
			get_tree().create_timer(0.45).timeout.connect(_show_out)
		_:
			if model.moves == EXTRA_MOVES and not _warned_few and model.moves < int(level.get("moves", 99)):
				_warned_few = true
				_add_text(tr("PZ_FEW") % model.moves, _board_rect.get_center(), 50, Color("ffd0d0"))


# --- Per frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var speed := 1.0 if _queue.size() < 10 else 1.6
	if not _step.is_empty():
		_step_t += delta * speed
		if _step_t >= _step_dur:
			var done := _step
			_end_step(done)
			_next_step()
	elif _anim == "blocked":
		_step_t += delta
		if _step_t > 0.3:
			_anim = ""
	for k in _pop_in.keys():
		_pop_in[k] += delta
		if _pop_in[k] > 0.35:
			_pop_in.erase(k)
	_moves_bump = maxf(0.0, _moves_bump - delta * 3.0)
	_goal_bump = maxf(0.0, _goal_bump - delta * 2.5)
	_intro = maxf(0.0, _intro - delta)
	if _tip > 0.0:
		_tip = maxf(0.0, _tip - delta)
		_fx.set_meta("dirty", true)
	_flash = maxf(0.0, _flash - delta * 2.2)
	if not is_busy() and not _ended and model.state == Match3.PLAYING and _panel == null:
		_idle += delta
		if _idle > HINT_DELAY and _hint.is_empty():
			_hint = model.find_hint()
	# Shake the board a little on big blasts.
	_shake = maxf(0.0, _shake - delta * 2.5)
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(sin(_t * 71.0), cos(_t * 57.0)) * _shake * 7.0
	_board.position = _board_rect.position + sh
	_frame.position = sh
	_update_fx(delta)
	# Redraws: every frame while something moves, ~30 fps when idle.
	var animating := is_busy() or _anim != "" or not _pop_in.is_empty() or not _hint.is_empty() or _intro > 0.0
	_board_acc += delta
	if animating or _board_acc >= 1.0 / 30.0:
		_board_acc = 0.0
		_board.queue_redraw()
	_bg_acc += delta
	if _bg_acc >= (1.0 / 20.0 if Art.low_power else 1.0 / 30.0):
		_bg_acc = 0.0
		_bg.queue_redraw()
		_top.queue_redraw()
		if _panel_art:
			_panel_art.queue_redraw()
	elif _moves_bump > 0.0 or _goal_bump > 0.0:
		_top.queue_redraw()


# --- Effects ----------------------------------------------------------------------------------

func _pop(c: Vector2i, kind: int, special: String) -> void:
	var p := _board.position + _cell_center(c)
	_ghosts.append({"p": p, "kind": kind, "special": special, "age": 0.0, "life": 0.2})
	var col: Color = KIND_COLORS[kind] if kind >= 0 and kind < KIND_COLORS.size() else Art.GOLD
	_burst(p, col, 3 if Art.low_power else 6, 1.0)
	if _rng.randf() < 0.5:
		_bubble_burst(p, 1 if Art.low_power else 2)


func _burst(p: Vector2, col: Color, n: int, power: float) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(120.0, 360.0) * power * tile / 90.0
		_parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * sp + Vector2(0, -80), "age": 0.0, "life": _rng.randf_range(0.35, 0.6),
				"c": col, "s": _rng.randf_range(0.28, 0.55) * tile / 90.0, "type": "dot"})


func _bubble_burst(p: Vector2, n: int) -> void:
	for i in n:
		_parts.append({"p": p + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-10, 10)), "v": Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-220, -140)),
				"age": 0.0, "life": _rng.randf_range(0.5, 0.8), "c": Color(1, 1, 1, 0.85), "s": _rng.randf_range(0.5, 0.9) * tile / 90.0, "type": "bubble"})


func _sparkles(p: Vector2, n: int) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		_parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(80.0, 260.0), "age": 0.0, "life": _rng.randf_range(0.4, 0.7),
				"c": Color(1.0, 0.95, 0.6), "s": _rng.randf_range(0.6, 1.1) * tile / 90.0, "type": "star"})


func _beam(c: Vector2i, horizontal: bool) -> void:
	if (horizontal and (c.y < 0 or c.y >= model.height)) or (not horizontal and (c.x < 0 or c.x >= model.width)):
		return
	_beams.append({"c": _board.position + _cell_center(c), "h": horizontal, "age": 0.0, "life": 0.34})


func _combo_text(combo: int) -> void:
	var key := "PZ_NICE"
	var col := Color("9ff0c0")
	if combo >= 5:
		key = "PZ_AMAZING"
		col = Color("ff9fd0")
		Sfx.play("voice_woohoo")
	elif combo == 4:
		key = "PZ_SUPER"
		col = Art.GOLD
		Sfx.play("voice_yay")
	elif combo == 3:
		key = "PZ_WOW"
		col = Color("7be0ff")
		Sfx.play("voice_wow")
	_add_text(tr(key), _board_rect.get_center() + Vector2(0, -tile * 1.2), 58 + mini(combo, 6) * 4, col)


func _add_text(s: String, p: Vector2, size_px: int, col: Color) -> void:
	_texts = _texts.filter(func(x): return x["age"] < 0.5)
	_texts.append({"s": s, "p": p, "size": size_px, "c": col, "age": 0.0, "life": 1.1})


func _update_fx(delta: float) -> void:
	var any := _flash > 0.0 or _shake > 0.0
	for p in _parts:
		p["age"] += delta
		if p["type"] == "bubble":
			p["v"].x *= Motion.drag(0.97, delta)
		else:
			p["v"].y += 700.0 * delta
			p["v"] *= Motion.drag(0.97, delta)
		p["p"] += p["v"] * delta
	_parts = _parts.filter(func(p): return p["age"] < p["life"])
	for arr: Array in [_ghosts, _beams, _rings, _zaps, _texts]:
		for x in arr:
			x["age"] += delta
	_ghosts = _ghosts.filter(func(x): return x["age"] < x["life"])
	_beams = _beams.filter(func(x): return x["age"] < x["life"])
	_rings = _rings.filter(func(x): return x["age"] < x["life"])
	_zaps = _zaps.filter(func(x): return x["age"] < x["life"])
	_texts = _texts.filter(func(x): return x["age"] < x["life"])
	for f in _flyers:
		f["age"] += delta
		if f["age"] >= f["life"] and not f.has("done"):
			f["done"] = true
			_shown_frags = mini(_shown_frags + 1, model.fragments_needed)
			_goal_bump = 1.0
			_sparkles(_goal_pos(), 10)
			Sfx.play("coins", 1.2)
	_flyers = _flyers.filter(func(f): return not f.has("done"))
	any = any or not (_parts.is_empty() and _ghosts.is_empty() and _beams.is_empty() and _rings.is_empty() and _zaps.is_empty() and _texts.is_empty() and _flyers.is_empty())
	if any:
		_fx.queue_redraw()
	elif _fx.has_meta("dirty"):
		_fx.remove_meta("dirty")
		_fx.queue_redraw()
	if any:
		_fx.set_meta("dirty", true)


# --- Drawing: background, frame -------------------------------------------------------------

const _RING_PTS_R := 10.0


func _ring_pts() -> PackedVector2Array:
	return Art.circle_pts(Vector2.ZERO, _RING_PTS_R, 20)


func _draw_bg() -> void:
	var v := _bg.size
	var top := Color("46c3dc")
	var mid := Color("1f86bd")
	var low := Color("134e8e")
	Art.grad(_bg, PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), Vector2(v.x, v.y * 0.5), Vector2(0, v.y * 0.5)]), PackedColorArray([top, top, mid, mid]))
	Art.grad(_bg, PackedVector2Array([Vector2(0, v.y * 0.5), Vector2(v.x, v.y * 0.5), v, Vector2(0, v.y)]), PackedColorArray([mid, mid, low, low]))
	# Soft light rays swaying from the surface.
	for i in 6:
		var x := v.x * (0.08 + i * 0.18) + sin(_t * 0.4 + i * 1.7) * 40.0
		var w := 50.0 + (i % 3) * 30.0
		var len := v.y * (0.75 + 0.1 * (i % 2))
		var ray := Color(1, 1, 0.9, 0.09 + 0.03 * sin(_t * 0.9 + i))
		var clear := Color(ray, 0.0)
		Art.grad(_bg, PackedVector2Array([Vector2(x - w * 0.3, 0), Vector2(x + w * 0.3, 0), Vector2(x + w + len * 0.18, len), Vector2(x - w + len * 0.18, len)]),
				PackedColorArray([ray, ray, clear, clear]))
	# Bubbles rising behind the board.
	var rp := _ring_pts()
	for b in _bubbles:
		var y := fposmod(b.y - _t * (0.03 + b.z * 0.006), 1.0)
		var x := b.x * v.x + sin(_t * 1.3 + b.x * 20.0) * 10.0
		Art.push(_bg, Vector2(x, y * (v.y + 40.0) - 20.0), 0.0, Vector2.ONE * (b.z / _RING_PTS_R))
		Art.ring(_bg, rp, Color(1, 1, 1, 0.45), 1.8)
		Art.pop(_bg)
	# A couple of fish passing by on the sides.
	for i in 2:
		var dir := 1.0 if i == 0 else -1.0
		var f := fposmod(_t * 0.035 + i * 0.5, 1.0)
		var fx := lerpf(-60.0, v.x + 60.0, f) if dir > 0 else lerpf(v.x + 60.0, -60.0, f)
		var fy := v.y * (0.3 + 0.35 * i) + sin(_t * 1.1 + i) * 14.0
		Art.fish(_bg, Vector2(fx, fy), 13.0, Color("7be0ff") if i == 0 else Color("ffd23f"), dir, _t)


func _draw_frame() -> void:
	var v := _frame.size
	var r := _board_rect
	var pad := maxf(10.0, tile * 0.2)
	# Sea floor along the bottom of the screen.
	var floor_y := minf(v.y - 60.0, r.end.y + pad + 10.0) if not _wide else v.y - 80.0
	var dunes := PackedVector2Array([Vector2(-10, floor_y + 30), Vector2(v.x * 0.2, floor_y + 5), Vector2(v.x * 0.45, floor_y + 28),
			Vector2(v.x * 0.7, floor_y), Vector2(v.x + 10, floor_y + 22), Vector2(v.x + 10, v.y + 10), Vector2(-10, v.y + 10)])
	Art.toon(_frame, dunes, Art.SAND, 4.0, 0.5)
	for i in 5:
		var sx := v.x * (0.1 + i * 0.2)
		Art.push(_frame, Vector2(sx, v.y - 18.0 - (i % 2) * 14.0), 0.3 * (i - 2), Vector2.ONE * 0.9)
		if i % 2 == 0:
			Props.shell(_frame, Color("ffb3c7") if i == 0 else Color("ffd6a0"))
		else:
			Props.starfish(_frame, Color("ff8a5c"))
		Art.pop(_frame)
	# Coral and seaweed on the sides (more room on PC).
	var side_l := r.position.x - pad
	var side_r := r.end.x + pad
	for s: float in [-1.0, 1.0]:
		var edge := side_l if s < 0 else side_r
		var room := edge if s < 0 else v.x - edge
		if room > 120.0:
			var cx := edge + s * room * 0.5
			for k in 3:
				Art.seaweed(_frame, Vector2(cx + (k - 1) * 34.0 * s, v.y - 30.0), 140.0 + k * 50.0, Color("3fbf6a").lerp(Color("2f9a45"), k * 0.4), 0.0, k * 1.3 + s, 12.0)
			Art.push(_frame, Vector2(cx - s * room * 0.2, v.y - 60.0), 0.0, Vector2.ONE * 1.4)
			Props.coral(_frame, Color("ff7a8a") if s < 0 else Color("b58cff"), 3 if s < 0 else 8, 0.0)
			Art.pop(_frame)
	# The board's frame: a chunky sand-and-coral border.
	var outer := r.grow(pad)
	Art.t_rect(_frame, Rect2(outer.position + Vector2(0, 8), outer.size), pad + 12.0, Art.shade_of(Art.SAND_DARK, 0.3), 4.0, 0.0)
	Art.t_rect(_frame, outer, pad + 12.0, Art.SAND, 4.0, 0.6)
	Art.t_rect(_frame, r.grow(4.0), 14.0, Color("1a5c96"), 3.0, 0.0)
	# Pebbles on the frame.
	var prng := RandomNumberGenerator.new()
	prng.seed = 5
	for i in 18:
		var side := i % 4
		var f := prng.randf_range(0.1, 0.9)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(lerpf(outer.position.x, outer.end.x, f), outer.position.y + pad * 0.5)
			1: p = Vector2(lerpf(outer.position.x, outer.end.x, f), outer.end.y - pad * 0.5)
			2: p = Vector2(outer.position.x + pad * 0.5, lerpf(outer.position.y, outer.end.y, f))
			3: p = Vector2(outer.end.x - pad * 0.5, lerpf(outer.position.y, outer.end.y, f))
		Art.flat(_frame, Art.circle_pts(p, prng.randf_range(1.6, 3.2), 8), Art.SAND_DARK)
	# Checkered cells.
	var light := Color(1, 1, 1, 0.07)
	var dark := Color(0.05, 0.1, 0.3, 0.12)
	for y in model.height:
		for x in model.width:
			var cell := Rect2(r.position + Vector2(x, y) * tile, Vector2(tile, tile))
			Art.flat(_frame, Art.rrect_pts(cell.grow(-2.0), tile * 0.16), light if (x + y) % 2 == 0 else dark)
	# Bottom row glows gold: that's where the pieces go.
	var goal_row := Rect2(r.position + Vector2(0, (model.height - 1) * tile), Vector2(r.size.x, tile))
	Art.grad(_frame, PackedVector2Array([goal_row.position, Vector2(goal_row.end.x, goal_row.position.y), goal_row.end, Vector2(goal_row.position.x, goal_row.end.y)]),
			PackedColorArray([Color(1, 0.85, 0.3, 0.05), Color(1, 0.85, 0.3, 0.05), Color(1, 0.85, 0.3, 0.5), Color(1, 0.85, 0.3, 0.5)]))
	# The goal line: a gold bar along the bottom of the board and a gold tag
	# with arrows hanging under it, so it is clear the pieces go down there.
	var gl := Rect2(r.position.x + 4.0, r.end.y - 5.0, r.size.x - 8.0, 6.0)
	Art.t_rect(_frame, gl, 3.0, Art.GOLD, 2.5, 0.0)
	var tag_w := minf(r.size.x * 0.42, tile * 2.6)
	var tag := Rect2(r.get_center().x - tag_w / 2.0, outer.end.y - pad * 0.6, tag_w, pad * 0.6 + tile * 0.42)
	Art.t_rect(_frame, Rect2(tag.position + Vector2(0, 5), tag.size), tag.size.y * 0.4, Art.shade_of(Art.GOLD, 0.35), 3.0, 0.0)
	Art.t_rect(_frame, tag, tag.size.y * 0.4, Art.GOLD, 3.0, 0.5)
	for k in 3:
		Art.push(_frame, Vector2(tag.get_center().x + (k - 1) * tag_w * 0.3, tag.get_center().y + tag.size.y * 0.06), PI, Vector2.ONE * (tag.size.y / 44.0))
		Art.toon(_frame, Art.arrow_pts(13.0), Art.WHITE, 2.5, 0.0)
		Art.pop(_frame)
	# Corner decorations.
	Art.push(_frame, outer.position + Vector2(pad * 0.2, pad * 1.4), -0.4, Vector2.ONE * (tile / 70.0))
	Props.coral(_frame, Color("ff6f7f"), 2, 0.0)
	Art.pop(_frame)
	Art.push(_frame, Vector2(outer.end.x - pad * 0.3, outer.position.y + pad * 0.5), 0.5, Vector2.ONE * (tile / 80.0))
	Props.starfish(_frame, Color("ffc23f"))
	Art.pop(_frame)
	Art.push(_frame, Vector2(outer.position.x + pad * 0.4, outer.end.y - pad * 0.2), 0.2, Vector2.ONE * (tile / 85.0))
	Props.shell(_frame, Color("ffb3c7"))
	Art.pop(_frame)
	Art.push(_frame, Vector2(outer.end.x - pad * 0.2, outer.end.y - pad * 0.8), 0.0, Vector2.ONE * (tile / 75.0))
	Props.coral(_frame, Color("b58cff"), 6, 0.0)
	Art.pop(_frame)


# --- Drawing: board --------------------------------------------------------------------------

func _draw_board() -> void:
	if _grid.is_empty():
		return
	var w := model.width
	var h := model.height
	var ks: PackedInt32Array = _grid["kind"]
	var sps: PackedInt32Array = _grid["special"]
	var sands: PackedInt32Array = _grid["sand"]
	var bubs: PackedInt32Array = _grid["bubble"]
	var s := tile / 62.0
	var frag_cells: Array[Vector2] = []
	for y in h:
		for x in w:
			var i := y * w + x
			var k := ks[i]
			if k == Match3.EMPTY:
				continue
			var c := Vector2i(x, y)
			var xf := _piece_xf(i, c)
			var pos: Vector2 = xf[0]
			var rot: float = xf[1]
			var sc: Vector2 = xf[2] * s
			Art.push(_board, pos, rot, sc)
			if k == Match3.SAND:
				TileArt.blocker(_board, "sand", sands[i])
			elif k == Match3.FRAGMENT:
				ArtifactArt.fragment(_board, artifact, _t + x * 0.7)
				frag_cells.append(pos)
			else:
				var sel := c == _selected
				var hinted: bool = not _hint.is_empty() and (c == _hint[0] or c == _hint[1])
				if hinted:
					Art.flat(_board, Art.circle_pts(Vector2.ZERO, 30.0, 24), Color(1, 1, 0.8, snappedf(0.28 + 0.12 * sin(_t * 6.0), 0.04)))
				if sps[i] != Match3.NONE:
					if sel:
						Art.flat(_board, Art.circle_pts(Vector2.ZERO, 30.0, 24), Color(1, 1, 1, 0.35))
					TileArt.special(_board, Match3.SPECIAL_NAMES[sps[i]], _t + i * 0.13)
					if sel:
						Art.ring(_board, Art.circle_pts(Vector2.ZERO, 28.0, 32), Color(1, 1, 1, 0.95), 3.0)
				elif k >= 0 and k < TileArt.KINDS.size():
					TileArt.draw(_board, TileArt.KINDS[k], _t + i * 0.37, sel)
				if bubs[i] > 0:
					TileArt.blocker(_board, "bubble", bubs[i])
			Art.pop(_board)
	# Bouncy arrows under the pieces at the start and with the hint.
	if _intro > 0.0 or not _hint.is_empty():
		var bob := absf(sin(_t * 5.0)) * tile * 0.1
		for p in frag_cells:
			Art.push(_board, p + Vector2(0, tile * 0.62 + bob), PI, Vector2.ONE * (tile / 90.0))
			Art.toon(_board, Art.arrow_pts(16.0), Art.GOLD, 3.0, 0.4)
			Art.pop(_board)


## [position, rotation, scale] of the piece in cell i for the current animation.
func _piece_xf(i: int, c: Vector2i) -> Array:
	var pos := _cell_center(c)
	var rot := 0.0
	var sc := Vector2.ONE
	if _anim_from.has(i):
		var from = _anim_from[i]
		match _anim:
			"swap":
				var f := _ease_out(clampf(_step_t / maxf(_step_dur, 0.01), 0.0, 1.0))
				pos = (Vector2(from) + Vector2(0.5, 0.5)).lerp(Vector2(c) + Vector2(0.5, 0.5), f) * tile
			"bad":
				var f := sin(clampf(_step_t / _step_dur, 0.0, 1.0) * PI)
				pos = (Vector2(c) + Vector2(0.5, 0.5)).lerp(Vector2(from) + Vector2(0.5, 0.5), f * 0.42) * tile
				rot = sin(_step_t * 40.0) * 0.12 * f
			"fall":
				var dist: float = c.y - from.y
				var dur := _fall_time(dist)
				var f := clampf(_step_t / dur, 0.0, 1.0)
				pos = (Vector2(from) + Vector2(0.5, 0.5)).lerp(Vector2(c) + Vector2(0.5, 0.5), f * f) * tile
				if _step_t > dur:
					var g := clampf((_step_t - dur) / 0.14, 0.0, 1.0)
					var sq := sin(g * PI) * 0.13 * (1.0 - g * 0.5)
					sc = Vector2(1.0 + sq, 1.0 - sq)
					pos.y += sq * tile * 0.12
			"blocked":
				rot = sin(_step_t * 45.0) * 0.1 * (1.0 - _step_t / 0.3)
	if _pop_in.has(i):
		var a: float = _pop_in[i]
		var f := clampf(a / 0.3, 0.0, 1.0)
		var k := sin(f * PI * 0.5) + sin(f * PI) * 0.3
		sc *= maxf(0.05, k)
	if not _hint.is_empty() and (c == _hint[0] or c == _hint[1]):
		var ph := fposmod(_t, 1.4)
		if ph < 0.6:
			rot += sin(ph * 30.0) * 0.14 * (1.0 - ph / 0.6)
			sc *= 1.0 + 0.06 * sin(ph / 0.6 * PI)
	return [pos, rot, sc]


func _ease_out(f: float) -> float:
	return 1.0 - (1.0 - f) * (1.0 - f)


# --- Drawing: top bar -------------------------------------------------------------------------

func _draw_top() -> void:
	var w := _top_rect.size.x
	var h := TOP_H
	Art.t_rect(_top, Rect2(0, 6, w, h - 6), 28, Art.shade_of(Art.CREAM_DARK, 0.3), 4.0, 0.0)
	Art.t_rect(_top, Rect2(0, 0, w, h - 6), 28, Art.CREAM, 4.0, 0.0)
	Art.flat(_top, Art.rrect_pts(Rect2(20, 6, w - 40, 14), 7), Color(1, 1, 1, 0.55))
	# Goal: the fragment and how many are in.
	var gp := Vector2(62, h / 2.0 - 3.0)
	var gb := 1.0 + _goal_bump * 0.25
	Art.t_circle(_top, gp, 40.0, Color("1a5c96"), 3.5, 0.0)
	Art.push(_top, gp, 0.0, Vector2.ONE * 1.35 * gb)
	ArtifactArt.fragment(_top, artifact, _t)
	Art.pop(_top)
	var goal := "%d/%d" % [_shown_frags, model.fragments_needed]
	var done := _shown_frags >= model.fragments_needed
	Art.push(_top, Vector2(110, h / 2.0 + 14.0), 0.0, Vector2.ONE * (1.0 + _goal_bump * 0.2))
	Art.text(_top, Vector2.ZERO, goal, 44, Art.GREEN if done else Art.WHITE, 8, false)
	Art.pop(_top)
	# Moves: a big bubble badge that bumps when the number changes.
	var few := _shown_moves <= 3 and not _ended
	var mc := Vector2(w / 2.0, h / 2.0 + 4.0)
	var pulse := 1.0 + _moves_bump * 0.18 + (0.05 * absf(sin(_t * 5.0)) if few else 0.0)
	Art.push(_top, mc, 0.0, Vector2.ONE * pulse)
	Art.t_circle(_top, Vector2(0, 5), 62.0, Art.shade_of(Art.CORAL if few else Art.BLUE, 0.4), 4.0, 0.0)
	Art.t_circle(_top, Vector2.ZERO, 62.0, Art.CORAL if few else Art.BLUE, 4.0, 0.5)
	Art.flat(_top, Art.ellipse_pts(Vector2(-20, -32), Vector2(18, 9), 16, -0.5), Color(1, 1, 1, 0.45))
	Art.text(_top, Vector2(0, -24), tr("PZ_MOVES"), 18, Color(1, 1, 1, 0.95), 5)
	Art.text(_top, Vector2(0, 30), str(_shown_moves), 58, Art.WHITE if _moves_bump < 0.5 else Art.GOLD, 9)
	Art.pop(_top)
	# Level number between the badge and the pause button.
	var lt := tr("PZ_LEVEL") % int(level.get("level", 1))
	var font := UiTheme.heavy_font()
	var fs := 26
	var right := w - 84.0 - 30.0
	var left := w / 2.0 + 74.0
	while fs > 16 and font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > right - left:
		fs -= 2
	Art.text(_top, Vector2((left + right) / 2.0, h / 2.0 + 6.0), lt, fs, Art.INK, 0)


# --- Drawing: effects ----------------------------------------------------------------------------

func _draw_fx() -> void:
	var ci := _fx
	var br := Rect2(_board.position, _board_rect.size)
	if _tip > 0.0 and not _ended:
		_draw_tip(ci)
	if _flash > 0.0:
		Art.flat_now(ci, Art.rrect_pts(br.grow(8.0), 18.0), Color(1, 1, 0.9, _flash * 0.6))
	for b in _beams:
		var f: float = b["age"] / b["life"]
		var c: Vector2 = b["c"]
		var reach := _ease_out(minf(1.0, f * 2.2))
		var thick := tile * 0.36 * (1.0 - f * 0.7)
		var col := Color(1.0, 0.97, 0.75, 0.9 * (1.0 - f))
		var glow := Color(1.0, 0.65, 0.3, 0.45 * (1.0 - f))
		if b["h"]:
			var x0 := lerpf(c.x, br.position.x, reach)
			var x1 := lerpf(c.x, br.end.x, reach)
			_band(ci, Vector2(x0, c.y), Vector2(x1, c.y), thick * 1.8, glow)
			_band(ci, Vector2(x0, c.y), Vector2(x1, c.y), thick * 0.7, col)
			if f < 0.55:
				for d: float in [-1.0, 1.0]:
					Art.push(ci, Vector2(x0 if d < 0 else x1, c.y), 0.0, Vector2(d, 1.0) * (tile / 62.0))
					TileArt.special(ci, "rocket_h", _t)
					Art.pop(ci)
		else:
			var y0 := lerpf(c.y, br.position.y, reach)
			var y1 := lerpf(c.y, br.end.y, reach)
			_band(ci, Vector2(c.x, y0), Vector2(c.x, y1), thick * 1.8, glow)
			_band(ci, Vector2(c.x, y0), Vector2(c.x, y1), thick * 0.7, col)
			if f < 0.55:
				for d: float in [-1.0, 1.0]:
					Art.push(ci, Vector2(c.x, y0 if d < 0 else y1), 0.0, Vector2(1.0, d) * (tile / 62.0))
					TileArt.special(ci, "rocket_v", _t)
					Art.pop(ci)
	for g in _ghosts:
		var f: float = g["age"] / g["life"]
		var sc := (1.0 + sin(minf(f * 2.0, 1.0) * PI * 0.5) * 0.3) * (1.0 - maxf(0.0, f - 0.4) / 0.6)
		if sc <= 0.02:
			continue
		Art.push(ci, g["p"], 0.0, Vector2.ONE * sc * tile / 62.0)
		if g["special"] != "":
			TileArt.special(ci, g["special"], _t)
		elif g["kind"] >= 0 and g["kind"] < TileArt.KINDS.size():
			TileArt.draw(ci, TileArt.KINDS[g["kind"]], _t, true)
		Art.pop(ci)
	for z in _zaps:
		if z["age"] < 0.0:
			continue
		var f: float = z["age"] / z["life"]
		var a: Vector2 = z["a"]
		var b: Vector2 = z["b"]
		var zr := RandomNumberGenerator.new()
		zr.seed = z["seed"] + int(_t * 20.0)
		var pts := PackedVector2Array([a])
		var n := (b - a).normalized().orthogonal()
		for k in range(1, 5):
			pts.append(a.lerp(b, k / 5.0) + n * zr.randf_range(-12.0, 12.0))
		pts.append(b)
		var hue := fposmod(z["seed"] * 0.13, 1.0)
		Art.polyline(ci, pts, Color.from_hsv(hue, 0.5, 1.0, 0.55 * (1.0 - f)), 9.0)
		Art.polyline(ci, pts, Color(1, 1, 1, 0.95 * (1.0 - f)), 3.5)
	for r in _rings:
		if r["age"] < 0.0:
			continue
		var f: float = r["age"] / r["life"]
		var rad := lerpf(r["r0"], r["r1"], _ease_out(f))
		var col: Color = r["color"]
		Art.arc(ci, r["c"], rad, 0.0, TAU, 28, Color(col, col.a * (1.0 - f)), maxf(1.0, r["w"] * (1.0 - f * 0.6)))
	var rp := _ring_pts()
	for p in _parts:
		var f: float = p["age"] / p["life"]
		var col: Color = p["c"]
		match p["type"]:
			"dot":
				Art.push(ci, p["p"], 0.0, Vector2.ONE * p["s"] * (1.0 - f * 0.6))
				Art.disc(ci, Vector2.ZERO, 10.0, Color(col, snappedf(1.0 - f * f, 0.1)))
				Art.pop(ci)
			"bubble":
				Art.push(ci, p["p"], 0.0, Vector2.ONE * p["s"])
				Art.ring(ci, rp, Color(1, 1, 1, 0.8), 2.2)
				Art.pop(ci)
			"star":
				Art.push(ci, p["p"], p["age"] * 6.0, Vector2.ONE * p["s"] * (1.0 - f))
				Art.flat(ci, Art.star_pts(Vector2.ZERO, 12.0, 4.0, 4), Color(1.0, 0.97, 0.7))
				Art.pop(ci)
	for fl in _flyers:
		var f := clampf(fl["age"] / fl["life"], 0.0, 1.0)
		var from: Vector2 = fl["from"]
		var to := _goal_pos()
		var e := f * f * (3.0 - 2.0 * f)
		var p := from.lerp(to, e)
		p.x += sin(f * PI) * 90.0 * (1.0 if from.x < to.x + 200.0 else -1.0)
		p.y -= sin(f * PI) * 120.0
		var sc := lerpf(tile / 62.0 * 1.2, 1.35, f) * (1.0 + sin(f * PI) * 0.4)
		Art.push(ci, p, sin(f * TAU) * 0.3, Vector2.ONE * sc)
		ArtifactArt.fragment(ci, artifact, _t)
		Art.pop(ci)
		if int(fl["age"] * 60.0) % 3 == 0:
			_parts.append({"p": p, "v": Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-60, 60)), "age": 0.0, "life": 0.4,
					"c": Color(1, 1, 1), "s": 0.6, "type": "star"})
	for tx in _texts:
		var f: float = tx["age"] / tx["life"]
		var sc := minf(1.0, f * 6.0)
		sc = sc * (1.0 + 0.25 * sin(minf(f * 6.0, 1.0) * PI))
		if f > 0.8:
			sc *= 1.0 - (f - 0.8) / 0.2
		Art.push(ci, tx["p"] + Vector2(0, -40.0 * f), sin(f * 7.0) * 0.04, Vector2.ONE * maxf(sc, 0.01))
		Art.text(ci, Vector2(0, tx["size"] * 0.35), tx["s"], tx["size"], tx["c"], 12)
		Art.pop(ci)


## The level-start tip above the board: bring the pieces down to the gold
## line. Fades in and out (alpha in steps, so the shape cache stays small).
func _draw_tip(ci: CanvasItem) -> void:
	var a := snappedf(clampf(minf(_tip, TIP_SEC - _tip) * 3.0, 0.0, 1.0), 0.1)
	if a <= 0.0:
		return
	var v := _fx.size
	var text := tr("PZ_GOAL_HINT")
	var font := UiTheme.heavy_font()
	var fs := 30
	var max_w := minf(v.x - 40.0, 760.0) - 90.0
	while fs > 16 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 2
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var top := _top_rect.end.y + 34.0
	var bottom := _board_rect.position.y - maxf(10.0, tile * 0.2) - 6.0
	var y := maxf(top, (top + bottom) / 2.0)
	var pill := Rect2(v.x / 2.0 - (tw + 80.0) / 2.0, y - 26.0, tw + 80.0, 52.0)
	Art.t_rect(ci, Rect2(pill.position + Vector2(0, 5), pill.size), 26.0, Color(Art.shade_of(Art.CREAM_DARK, 0.3), a), 3.5, 0.0)
	Art.t_rect(ci, pill, 26.0, Color(Art.CREAM, a), 3.5, 0.0)
	Art.push(ci, Vector2(pill.position.x + 34.0, y + 1.0), PI, Vector2.ONE * 0.9)
	Art.toon(ci, Art.arrow_pts(14.0), Color(Art.GOLD, a), 2.5, 0.0)
	Art.pop(ci)
	Art.text(ci, Vector2(pill.position.x + 56.0 + tw / 2.0, y + fs * 0.36), text, fs, Color(Art.INK, a), 0)


func _band(ci: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var n := (b - a).normalized().orthogonal() * width / 2.0
	var clear := Color(col, 0.0)
	Art.grad(ci, PackedVector2Array([a - n, b - n, b, a]), PackedColorArray([clear, clear, col, col]))
	Art.grad(ci, PackedVector2Array([a, b, b + n, a + n]), PackedColorArray([col, col, clear, clear]))


# --- Panels ------------------------------------------------------------------------------------

func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_confirm.add_child(box)
	var q := Label.new()
	q.theme_type_variation = &"InkLabel"
	q.name = "Q"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_override("font", UiTheme.heavy_font())
	q.add_theme_font_size_override("font_size", 30)
	box.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var leave := Button.new()
	leave.name = "Leave"
	leave.theme_type_variation = &"RedButton"
	leave.custom_minimum_size = Vector2(150, 70)
	leave.pressed.connect(_leave)
	row.add_child(leave)
	var stay := Button.new()
	stay.name = "Stay"
	stay.custom_minimum_size = Vector2(150, 70)
	stay.pressed.connect(_toggle_confirm)
	row.add_child(stay)
	add_child(_confirm)


func _toggle_confirm() -> void:
	if _ended or _panel != null:
		return
	Sfx.play("click")
	_confirm.visible = not _confirm.visible
	if _confirm.visible:
		var box := _confirm.get_child(0)
		box.get_node("Q").text = tr("PZ_LEAVE_Q")
		box.get_child(1).get_node("Leave").text = tr("PZ_LEAVE")
		box.get_child(1).get_node("Stay").text = tr("PZ_STAY")
		_confirm.reset_size()
		_confirm.position = Vector2(_top_rect.end.x - _confirm.size.x - 6.0, _top_rect.end.y + 6.0)


func _leave() -> void:
	if _ended and not _result.is_empty():
		return
	_ended = true
	_confirm.visible = false
	_finish(_make_result(false, true))


func _make_result(won: bool, left: bool = false) -> Dictionary:
	var stars := 0
	if won:
		var budget := maxi(1, int(level.get("moves", 20)))
		var ratio := float(maxi(model.moves, 0)) / budget
		stars = 1 if _extra_used else (3 if ratio >= 0.3 else (2 if ratio >= 0.1 else 1))
	return {"level": int(level.get("level", 1)), "won": won, "fragments": model.fragments_collected,
			"fragments_needed": model.fragments_needed, "stars": stars, "moves_left": maxi(model.moves, 0),
			"artifact": artifact, "left": left}


func _finish(result: Dictionary) -> void:
	if not _result.is_empty():
		return
	_result = result
	finished.emit(result)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _open_panel() -> VBoxContainer:
	_close_panel()
	_confirm.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.18, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "Dim"
	_overlay.add_child(dim)
	_panel = PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_overlay.add_child(_panel)
	return box


func _place_panel() -> void:
	if _panel == null:
		return
	var v := get_viewport_rect().size
	_panel.custom_minimum_size.x = minf(560.0, v.x - 40.0)
	_panel.reset_size()
	_panel.position = (v - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0


func _pop_panel() -> void:
	_place_panel()
	_panel.scale = Vector2(0.6, 0.6)
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween().set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)


func _close_panel() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_panel = null
	_panel_art = null
	_reward_box = null


func _title(box: VBoxContainer, text: String, size_px: int = 40) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", size_px)
	box.add_child(l)
	return l


func _button(box: Container, text: String, variation: StringName, action: Callable, height: float = 84.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	box.add_child(b)
	return b


func _fill_rewards() -> void:
	if _reward_box == null:
		return
	for c in _reward_box.get_children():
		c.queue_free()
	_reward_box.visible = not _reward_lines.is_empty()
	for line in _reward_lines:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = Icons.get_icon(String(line[0]), 44)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var l := Label.new()
		l.theme_type_variation = &"InkLabel"
		l.text = String(line[1])
		l.add_theme_font_override("font", UiTheme.heavy_font())
		l.add_theme_font_size_override("font_size", 32)
		row.add_child(l)
		_reward_box.add_child(row)
	if _panel:
		_place_panel.call_deferred()


func _rewards_for(result: Dictionary) -> void:
	_reward_lines = []
	if _reward_fn.is_valid():
		var lines = _reward_fn.call(result)
		if lines is Array:
			_reward_lines = lines


var _stars := 0
var _stars_t := 0.0


func _show_win() -> void:
	var result := _make_result(true)
	_rewards_for(result)
	var box := _open_panel()
	_title(box, tr("PZ_WIN"), 42)
	_stars = result["stars"]
	_stars_t = _t
	_panel_art = Control.new()
	_panel_art.custom_minimum_size = Vector2(0, 280)
	_panel_art.draw.connect(_draw_win_art)
	box.add_child(_panel_art)
	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 6)
	box.add_child(_reward_box)
	_fill_rewards()
	var collect := _button(box, tr("PZ_COLLECT"), &"GoldButton", func(): Sfx.play("coins"); _finish(result), 92)
	collect.name = "Collect"
	_pop_panel()
	Sfx.play("milestone")
	Sfx.play("voice_woohoo")
	for i in 3:
		get_tree().create_timer(0.35 + i * 0.25).timeout.connect(func():
			if i < _stars and is_inside_tree():
				Sfx.play("pop", 1.0 + i * 0.15))
	var c := get_viewport_rect().size / 2.0
	for i in 3:
		_sparkles(c + Vector2(_rng.randf_range(-200, 200), _rng.randf_range(-250, 50)), 10)
		_burst(c + Vector2(_rng.randf_range(-200, 200), -150), [Art.GOLD, Art.CORAL, Color("7be0ff")][i], 12, 2.0)


func _draw_win_art() -> void:
	var ci := _panel_art
	var s := ci.size
	var c := Vector2(s.x / 2.0, 160)
	# Rotating light rays behind the artifact.
	for i in 12:
		var a := _t * 0.4 + TAU * i / 12.0
		var ray := Color(1.0, 0.88, 0.4, 0.35)
		Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a - 0.12), sin(a - 0.12)) * 130.0, c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 130.0]),
				PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
	Art.push(ci, c, sin(_t * 1.5) * 0.04, Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.03))
	ArtifactArt.draw(ci, artifact, _t)
	Art.pop(ci)
	# Stars pop in one by one.
	for i in 3:
		var age := _t - _stars_t - 0.35 - i * 0.25
		var on := i < _stars and age > 0.0
		var sc := 1.0
		if on:
			var f := clampf(age / 0.3, 0.0, 1.0)
			sc = sin(f * PI * 0.5) + sin(f * PI) * 0.35
		var p := Vector2(s.x / 2.0 + (i - 1) * 84.0, 38.0 + (8.0 if i != 1 else -6.0))
		Art.push(ci, p, (i - 1) * 0.2, Vector2.ONE * (1.15 if i == 1 else 0.95))
		Art.toon(ci, Art.star_pts(Vector2.ZERO, 34.0, 15.0, 5), Color("c9c3d9"), 4.0, 0.0)
		if on:
			Art.push(ci, Vector2.ZERO, 0.0, Vector2.ONE * sc)
			Art.toon(ci, Art.star_pts(Vector2.ZERO, 34.0, 15.0, 5), Art.GOLD, 4.0, 0.6)
			Art.flat(ci, Art.ellipse_pts(Vector2(-8, -10), Vector2(6, 3), 10, -0.6), Color(1, 1, 1, 0.8))
			Art.pop(ci)
		Art.pop(ci)


func _show_out() -> void:
	if _ended or model.state != Match3.LOST:
		return
	var partial := _make_result(false)
	_rewards_for(partial)
	var box := _open_panel()
	_title(box, tr("PZ_OUT"), 40)
	if not _extra_used:
		var sub := _title(box, tr("PZ_SO_CLOSE"), 26)
		sub.theme_type_variation = &"SoftLabel"
	_panel_art = Control.new()
	_panel_art.custom_minimum_size = Vector2(0, 120)
	_panel_art.draw.connect(_draw_out_art)
	box.add_child(_panel_art)
	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 6)
	box.add_child(_reward_box)
	_fill_rewards()
	if not _extra_used:
		var more := _button(box, "%s  (%s)" % [tr("PZ_MORE") % EXTRA_MOVES, tr("PZ_FREE")], &"GoldButton", _extra_moves, 92)
		more.name = "More"
	var take := _button(box, tr("PZ_TAKE"), &"CreamButton" if not _extra_used else &"Button", func():
		_ended = true
		Sfx.play("coins")
		_finish(partial), 76)
	take.name = "Take"
	_pop_panel()
	Sfx.play("deny", 0.8)


func _draw_out_art() -> void:
	var ci := _panel_art
	var s := ci.size
	var n := model.fragments_needed
	var gap := minf(96.0, (s.x - 40.0) / maxf(1.0, n))
	for i in n:
		var p := Vector2(s.x / 2.0 + (i - (n - 1) / 2.0) * gap, 54.0)
		var got := i < model.fragments_collected
		Art.t_circle(ci, p, 40.0, Color("1a5c96") if got else Color("c9c3d9"), 3.5, 0.0)
		if got:
			Art.push(ci, p, 0.0, Vector2.ONE * 1.35)
			ArtifactArt.fragment(ci, artifact, _t + i)
			Art.pop(ci)
		else:
			Art.text(ci, p + Vector2(0, 14), "?", 40, Art.WHITE, 6)


func _extra_moves() -> void:
	if _extra_used:
		return
	_extra_used = true
	model.add_moves(EXTRA_MOVES)
	_shown_moves = model.moves
	_moves_bump = 1.0
	_warned_few = true
	_grid = model.snapshot()
	_close_panel()
	Sfx.play("upgrade")
	_add_text("+%d" % EXTRA_MOVES, _top_rect.position + Vector2(_top_rect.size.x / 2.0, TOP_H + 30.0), 56, Art.GOLD)
