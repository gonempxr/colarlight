class_name MiniMap
extends Control
## Small round map button: the current island in miniature with the boat
## sailing between the mine and the factory in step with the real trip, the
## world's name on a ribbon and a "!" when the next world can be opened.
## Tap it -> open_map.

signal open_map

const SIZE := 132.0
const SIZE_BIG := 156.0
const RIBBON := 26.0

## Bigger on PC; set before adding to the tree (or call set_big).
var big := false
## Preview sheets: show this location instead of the current one.
var location_override := -1
var _t := 0.0
var _down := false
var _press := 0.0
var _ready_gate := false
var _check_left := 0.0
var _redraw_left := 0.0
var _name := ""
var _loc := -1


func _ready() -> void:
	set_big(big)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh()


func set_big(on: bool) -> void:
	big = on
	var s := SIZE_BIG if big else SIZE
	custom_minimum_size = Vector2(s, s + RIBBON * 0.6)
	size = custom_minimum_size
	pivot_offset = Vector2(s / 2.0, s / 2.0)
	queue_redraw()


func _refresh() -> void:
	_loc = MapView.cur_location() if location_override < 0 else location_override
	_name = MapView.world_name(_loc)
	tooltip_text = TranslationServer.translate("MAP_TITLE")
	_ready_gate = MapView.can_advance()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			MapView._sfx("click")
			open_map.emit()
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_press = move_toward(_press, 1.0 if _down else 0.0, delta * 10.0)
	scale = Vector2.ONE * (1.0 - _press * 0.08)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.5
		_refresh()
	# The boat moves slowly at this size: 20 frames a second is plenty.
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 1.0 / 20.0
		queue_redraw()


func _draw() -> void:
	var s := SIZE_BIG if big else SIZE
	var r := s / 2.0 - 6.0
	var c := Vector2(s / 2.0, s / 2.0)
	var w := MapView.world_of(_loc)
	MapArt.still = MapView._reduce_motion()
	# Frame: a wooden ring with an ink outline.
	Art.t_circle(self, c + Vector2(0, 3), r + 6.0, Art.shade_of(Art.WOOD_DARK, 0.3), 0.0, 0.0)
	Art.t_circle(self, c, r + 6.0, Art.WOOD, 3.5, 0.6)
	MapArt.mini(self, c, r, w, MapView.tier_of(_loc), MapView.boat_progress("boat"), MapView.boat_progress("boat2"), _t)
	Art.arc_c(self, c, r, 0.0, TAU, 40, Art.INK, 3.0)
	Art.arc_c(self, c, r + 2.5, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.5), 2.5)
	# Name ribbon.
	var fs := 18 if not big else 21
	var font := UiTheme.heavy_font()
	var tw := minf(font.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0, s + 10.0)
	var rr := Rect2(c.x - tw / 2.0, s - RIBBON + 2.0, tw, RIBBON)
	Art.t_rect(self, rr, 11, Art.GOLD, 3.0, 0.5)
	Art.text(self, Vector2(c.x, rr.position.y + RIBBON * 0.74), _name, fs, Art.INK, 0)
	if _ready_gate:
		var pulse := 1.0 + 0.1 * sin(_t * 6.0)
		var b := Vector2(s - 16.0, 16.0)
		Art.push(self, b, 0.0, Vector2(pulse, pulse))
		Art.t_circle(self, Vector2.ZERO, 16, Art.RED, 3.0, 0.5)
		Art.text(self, Vector2(0, 9), "!", 26, Art.WHITE, 0)
		Art.pop(self)
