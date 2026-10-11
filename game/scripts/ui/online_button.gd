class_name OnlineButton
extends Control
## Round button under the lightbulb (with the other side buttons): a globe
## with a gold crown, it opens the real players' leaderboard (OnlineView),
## where invites and the player's name are too. Shown wherever online
## exists (our site, CrazyGames, ?online=test), greyed while it is not
## available. main.gd stacks it with the SideButtons.

signal pressed

const SIZE := 76.0

var _down := false
var _press := 0.0
var _check_left := 0.0
var _dim := false
var _mouse_seen := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("ONLINE_BOARD")


func _get_tooltip(at_position: Vector2) -> String:
	if not _mouse_seen or not Rect2(Vector2.ZERO, size).has_point(at_position):
		return ""
	return tooltip_text


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = event.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			Sfx.play("click")
			pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		tooltip_text = tr("ONLINE_BOARD")


func _process(delta: float) -> void:
	var p := move_toward(_press, 1.0 if _down else 0.0, delta * 10.0)
	if p != _press:
		_press = p
		scale = Vector2.ONE * (1.0 - _press * 0.08)
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	var dim: bool = not Online.available()
	if dim != _dim:
		_dim = dim
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	Art.t_circle(self, c, SIZE * 0.44, Color("e9f3ff") if not _dim else Color("e3e6ef"), 4.0, 0.6)
	draw_icon(self, c + Vector2(0, 3), SIZE * 0.27, _dim)


## A globe with a little gold crown on top (the players of the world).
static func draw_icon(ci: CanvasItem, c: Vector2, r: float, dim: bool = false) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * (r / 20.0))
	var disc := Art.circle_pts(Vector2(0, 4), 18.0, 28)
	Art.toon(ci, disc, Art.BLUE if not dim else Color("aab4c8"), 0.0, 0.5)
	var land := Art.union([Art.ellipse_pts(Vector2(-7, 0), Vector2(7, 5), 14, 0.5),
			Art.ellipse_pts(Vector2(8, 10), Vector2(5, 7), 14, -0.4), Art.ellipse_pts(Vector2(-4, 17), Vector2(6, 3), 12, 0.0)])
	Art.flat(ci, Art.clipped(land, disc), Art.GREEN if not dim else Color("c9cfdb"))
	Art.flat(ci, Art.clipped(Art.ellipse_pts(Vector2(-8, -6), Vector2(5, 3), 12, -0.6), disc), Color(1, 1, 1, 0.55))
	Art.ring(ci, disc, Art.INK, 3.0)
	# The crown.
	var crown := PackedVector2Array([Vector2(-11, -11), Vector2(-13, -25), Vector2(-6, -18), Vector2(0, -28),
			Vector2(6, -18), Vector2(13, -25), Vector2(11, -11)])
	Art.toon(ci, crown, Art.GOLD if not dim else Color("cfd4e0"), 2.6, 0.5)
	Art.t_circle(ci, Vector2(0, -16), 2.4, Art.CORAL if not dim else Color("9aa3bd"), 1.4, 0.0)
	Art.pop(ci)
