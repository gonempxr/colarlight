class_name ManagerBadge
extends Control
## Round manager slot. Empty: a round "+" button with a "Hire" ribbon and
## the price with a coin under it (gold and gently pulsing when affordable),
## tap to hire. Hired: the manager's portrait, blinking and reacting.

const SIZE := 64.0

var key := ""
var world: World
var _pressed := false
var _t := 0.0
var _sig := []
## Pulse step last drawn (empty slot the player can afford).
var _pulse := -1


func _init(stage_key: String) -> void:
	key = stage_key


## The boat and plant cards switch between the first and the second unit.
func set_key(stage_key: String) -> void:
	key = stage_key
	_sig = []
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 20)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("MANAGER_HINT_DEPTH") if key.begins_with("d") else tr("MANAGER_HINT")
	_t = randf() * 10.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		elif _pressed:
			_pressed = false
			if not Scroller.is_drag() and not GameState.has_manager(key):
				if GameState.hire_manager(key):
					Sfx.play("hire")
				else:
					Sfx.play("deny")
			queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		tooltip_text = tr("MANAGER_HINT_DEPTH") if key.begins_with("d") else tr("MANAGER_HINT")
		queue_redraw()


## 0..10: how far the affordable empty slot is swollen right now (in steps,
## so the drawing cache sees a few sizes, not a new one every frame).
func _pulse_step() -> int:
	if Settings.reduce_motion or GameState.has_manager(key) or GameState.coins < GameState.manager_cost(key):
		return 0
	return roundi(maxf(0.0, sin(_t * 3.2)) * 10.0)


func _process(delta: float) -> void:
	_t += delta
	# Blinks and moods don't need more than the scene's own frame rate.
	if not World.anim_tick() or not is_visible_in_tree():
		return
	if not get_global_rect().intersects(get_viewport_rect()):
		return
	if not GameState.has_manager(key):
		var p := _pulse_step()
		if p != _pulse:
			queue_redraw()
		return
	# Repaint only when the face actually changes (blink, mood, hop).
	var w := _world()
	var sig := [w.mood(key) if w else "", Chars.blinking(_t, key.hash() % 7), roundi(w.hop(key) * 0.4) if w else 0]
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _tint() -> Color:
	match key:
		"lift":
			return Color("9ff0dc")
		"boat", "boat2":
			return Color("8fd0ff")
		"plant", "plant2":
			return Color("ffd98a")
		"vault":
			return Color("e6d2ff")
	return Art.DEPTH_STYLE[GameState.depth_index(key)]["water"].lightened(0.45)


func _draw() -> void:
	var c := Vector2(SIZE / 2.0, SIZE / 2.0)
	var r := SIZE / 2.0 - 1.0
	var gs := GameState
	if gs.has_manager(key):
		var w := _world()
		var emo := w.mood(key) if w else ""
		if emo == "":
			emo = "happy"
		var hop := w.hop(key) * 0.4 if w else 0.0
		Chars.portrait(self, c - Vector2(0, hop), r, Chars.manager_look(key), emo, Chars.blinking(_t, key.hash() % 7), _tint())
		return
	var can := gs.coins >= gs.manager_cost(key)
	_pulse = _pulse_step()
	var sink := 3.0 if _pressed else 0.0
	# The button: a raised disc (gold when affordable) with a white plus.
	var bc := Vector2(c.x, 24.0)
	Art.push(self, bc + Vector2(0, sink), 0.0, Vector2.ONE * (1.0 + _pulse * 0.006))
	var face := Art.GOLD if can else UiTheme.BUTTON_COLORS["DarkButton"]
	if can and _pulse > 0:
		Art.glow(self, Vector2.ZERO, 30.0 + _pulse * 0.4, Color(1.0, 0.93, 0.55, 0.05 * _pulse))
	if sink == 0.0:
		Art.t_circle(self, Vector2(0, 3.5), 22.0, Art.shade_of(face, 0.38), 3.0, 0.0)
	Art.t_circle(self, Vector2.ZERO, 22.0, face, 3.0, 0.0)
	Art.flat(self, Art.ellipse_pts(Vector2(-7, -12), Vector2(8, 4), 16, -0.5), Color(1, 1, 1, 0.45))
	var plus := Art.union([Art.rrect_pts(Rect2(-11.5, -4, 23, 8), 4.0), Art.rrect_pts(Rect2(-4, -11.5, 8, 23), 4.0)])
	Art.toon(self, plus, Art.WHITE, 3.0, 0.0)
	# "Hire" ribbon across the bottom of the disc.
	var word := tr("HIRE")
	var font := UiTheme.heavy_font()
	var ws := 14
	while ws > 10 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, ws).x > SIZE - 12.0:
		ws -= 1
	var pw := minf(SIZE, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, ws).x + 12.0)
	Art.t_rect(self, Rect2(-pw / 2.0, 18.0, pw, 17.0), 8.5, Art.GREEN if can else Color("7d86a3"), 2.5, 0.0)
	Art.text(self, Vector2(0, 27.0 + ws * 0.36), word, ws, Art.WHITE, 4)
	Art.pop(self)
	# The price, with a coin, under the button.
	var txt := NumFormat.short(gs.manager_cost(key))
	var fs := 17
	while fs > 11 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 19.0 > SIZE:
		fs -= 1
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := c.x - (tw + 19.0) / 2.0
	Art.coin(self, Vector2(x0 + 8.0, SIZE + 9.0), 8.0)
	Art.text(self, Vector2(x0 + 19.0, SIZE + 15.0), txt, fs, Art.GOLD if can else Art.WHITE, 5, false)


func _world() -> World:
	if world:
		return world
	var n := get_parent()
	while n and not n is World:
		n = n.get_parent()
	world = n as World
	return world
