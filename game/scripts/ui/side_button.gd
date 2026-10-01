class_name SideButton
extends Control
## Round buttons under the lightbulb, same size and look:
## - "boost": a gold "×2" coin with a little play badge: watch an optional
##   ad for x2 coins. Shown only where ads exist (Platform.ads_available()).
##   Dimmed while the boost is full (4 h).
## - "rivals": a trophy that opens the Rivals League, shown while last
##   week's pearls wait to be collected (red "!"). The league is also in
##   the Profile.

signal pressed

const SIZE := 76.0

var kind := "boost"
var _t := 0.0
var _down := false
var _press := 0.0
var _check_left := 0.0
var _dim := false
var _badge := false
## Boost: time left shown on a gold tag under the coin ("" = no boost).
var _tag := ""
var _mouse_seen := false


static func make(k: String) -> SideButton:
	var b := SideButton.new()
	b.kind = k
	return b


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("BOOST_BTN" if kind == "boost" else "RIVALS")


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
		tooltip_text = tr("BOOST_BTN" if kind == "boost" else "RIVALS")


func _process(delta: float) -> void:
	_t += delta
	var p := move_toward(_press, 1.0 if _down else 0.0, delta * 10.0)
	if p != _press:
		_press = p
		scale = Vector2.ONE * (1.0 - _press * 0.08)
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.25
	var dim := false
	var badge := false
	var tag := ""
	if kind == "boost":
		dim = not GameState.can_ad_boost()
		var left: float = GameState.boost_left
		if left > 0.0:
			tag = NumFormat.duration(left)
	else:
		badge = bool(Rivals.reward_pending())
	if dim != _dim or badge != _badge or tag != _tag:
		_dim = dim
		_badge = badge
		_tag = tag
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := SIZE * 0.44
	if kind == "boost":
		Art.t_circle(self, c, r, Color("fff4d6") if not _dim else Color("e3e6ef"), 4.0, 0.6)
		draw_boost(self, c, r * 0.78, _dim)
		if _tag != "":
			# Gold tag with the time left, hanging over the bottom edge.
			var font := UiTheme.heavy_font()
			var w := font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16.0
			var tag := Rect2(c.x - w / 2.0, SIZE - 16.0, w, 24.0)
			Art.t_rect(self, tag, 9.0, Art.GOLD, 3.0, 0.4)
			Art.text(self, Vector2(c.x, SIZE + 1.5), _tag, 17, Art.INK, 0)
	else:
		Art.t_circle(self, c, r, Color("e9f3ff"), 4.0, 0.6)
		draw_trophy(self, c + Vector2(0, 1), r * 0.62)
		if _badge:
			var b := c + Vector2(SIZE * 0.32, -SIZE * 0.32)
			Art.t_circle(self, b, 12.0, Art.RED, 3.0, 0.0)
			Art.text(self, b + Vector2(0, 7), "!", 19, Art.WHITE, 0)


## A big coin with "×2" and a small round play badge (an ad to watch).
static func draw_boost(ci: CanvasItem, c: Vector2, r: float, dim: bool = false) -> void:
	Art.push(ci, c + Vector2(-r * 0.08, 0), 0.0, Vector2.ONE * (r / 20.0))
	Art.t_circle(ci, Vector2.ZERO, 20, Art.GOLD_DARK if not dim else Color("a9b0c2"), 3.0, 0.0)
	Art.t_circle(ci, Vector2(0, -1.5), 16, Art.GOLD if not dim else Color("cfd4e0"), 0.0, 0.8)
	Art.flat(ci, Art.ellipse_pts(Vector2(-9, -10), Vector2(3.5, 2.2), 12, -0.6), Color(1, 1, 1, 0.85))
	Art.pop(ci)
	var fs := int(round(r * 1.1))
	Art.text(ci, c + Vector2(-r * 0.1, r * 0.38), "×2", fs, Art.WHITE, maxi(5, int(r * 0.3)))
	# Play badge, bottom right.
	var b := c + Vector2(r * 0.84, r * 0.42)
	var br := r * 0.42
	Art.t_circle(ci, b, br, Art.CORAL if not dim else Color("9aa3bd"), maxf(2.5, r * 0.1), 0.3)
	var tri := PackedVector2Array([b + Vector2(-br * 0.32, -br * 0.48), b + Vector2(br * 0.55, 0), b + Vector2(-br * 0.32, br * 0.48)])
	Art.flat(ci, tri, Art.WHITE)


## Gold cup with handles on a small stand.
static func draw_trophy(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.push(ci, c, 0.0, Vector2.ONE * (r / 20.0))
	# Handles behind the cup.
	for s in [-1.0, 1.0]:
		var h := Art.smooth_pts(PackedVector2Array([Vector2(13 * s, -14), Vector2(25 * s, -15), Vector2(24 * s, -3), Vector2(12 * s, 3)]), 4)
		Art.polyline(ci, h, Art.INK, 7.0)
		Art.polyline(ci, h, Art.GOLD_DARK, 3.0)
	var cup := Art.smooth_pts(PackedVector2Array([Vector2(-17, -20), Vector2(17, -20), Vector2(15, -2), Vector2(6, 8), Vector2(-6, 8), Vector2(-15, -2)]), 3)
	Art.toon(ci, cup, Art.GOLD, 3.0, 0.7)
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -11), Vector2(3, 6), 10, 0.2), Color(1, 1, 1, 0.7))
	Art.toon(ci, Art.star_pts(Vector2(2, -7), 6.5, 3.0, 5), Color("fff3b8"), 0.0, 0.0)
	Art.t_rect(ci, Rect2(-4, 7, 8, 7), 2, Art.GOLD_DARK, 2.5, 0.0)
	Art.t_rect(ci, Rect2(-12, 13, 24, 8), 3, Art.WOOD, 3.0, 0.4)
	Art.pop(ci)
