class_name ManagerBadge
extends Control
## Round manager slot. Empty: a "+" with the hire price, tap to hire.
## Hired: the manager's portrait, blinking and reacting with the stage.

const SIZE := 64.0

var key := ""
var world: World
var _pressed := false
var _t := 0.0
var _sig := []


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


func _process(delta: float) -> void:
	_t += delta
	if not GameState.has_manager(key) or not is_visible_in_tree():
		return
	if not get_global_rect().intersects(get_viewport_rect()):
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
	Art.toon(self, Art.circle_pts(c, r - 3.0, 32), Color("e9dcc4") if not can else Color("fff1c7"), 3.0, 0.0)
	var dash := Art.GOLD_DARK if can else Art.INK_SOFT
	for i in 12:
		var a := TAU * i / 12.0
		Art.arc(self, c, r - 9.0, a, a + TAU / 24.0, 4, dash, 3.0)
	var plus := Art.GREEN if can else Color("b9bfd1")
	Art.toon(self, Art.union([Art.rrect_pts(Rect2(c.x - 13, c.y - 4.5, 26, 9), 4.5), Art.rrect_pts(Rect2(c.x - 4.5, c.y - 13, 9, 26), 4.5)]), plus, 2.5, 0.0)
	var txt := NumFormat.short(gs.manager_cost(key))
	Art.text(self, Vector2(c.x, SIZE + 16), txt, 17, Art.GOLD if can else Art.WHITE, 5)


func _world() -> World:
	if world:
		return world
	var n := get_parent()
	while n and not n is World:
		n = n.get_parent()
	world = n as World
	return world
