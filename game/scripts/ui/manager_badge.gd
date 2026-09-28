class_name ManagerBadge
extends Control
## Round manager slot. Empty: a "+" with the hire price, tap to hire.
## Hired: the manager's portrait.

const SIZE := 64.0

var key := ""
var _pressed := false


func _init(stage_key: String) -> void:
	key = stage_key


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 18)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("MANAGER_HINT")


func kind() -> String:
	return key if key in ["boat", "plant"] else "dive"


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


func _draw() -> void:
	var c := Vector2(SIZE / 2.0, SIZE / 2.0)
	var r := SIZE / 2.0 - 2.0
	var gs := GameState
	var tint: Color
	match kind():
		"boat":
			tint = Color("2f8cff")
		"plant":
			tint = Color("ffb627")
		_:
			var i := GameState.depth_index(key)
			tint = Art.DEPTH_STYLE[i]["suit"]
	if gs.has_manager(key):
		Art.manager(self, c, r, kind(), tint)
		return
	var can := gs.coins >= gs.manager_cost(key)
	draw_circle(c, r, Color(0, 0, 0, 0.3))
	draw_arc(c, r - 2, 0, TAU, 32, Art.GOLD if can else Color(1, 1, 1, 0.35), 4, true)
	var plus := Art.GOLD if can else Color(1, 1, 1, 0.6)
	draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), plus, 6, true)
	draw_line(c + Vector2(0, -12), c + Vector2(0, 12), plus, 6, true)
	var font := UiTheme.heavy_font()
	var txt := NumFormat.short(gs.manager_cost(key))
	var fs := 17
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, Vector2(c.x - tw / 2.0, SIZE + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(c.x - tw / 2.0, SIZE + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.GOLD if can else Color(1, 1, 1, 0.7))
