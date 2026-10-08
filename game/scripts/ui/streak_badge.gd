class_name StreakBadge
extends Control
## The small flame + day count in the top bar's coin pill. Bright when
## today already counted, a calm sleepy flame while it waits (no timers,
## no warnings). Tap: the streak screen. Hidden until the daily gift opens.

signal pressed

const H := 34.0
const FONT_PX := 22

var _t := 0.0
var _ph := -1
var _count := -1
var _lit := false
var _pop := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(56, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = tr("STREAK")
	Progress.streak_lit.connect(func(_r): _pop = 1.0)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		tooltip_text = tr("STREAK")


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		Sfx.play("click")
		pressed.emit()
		accept_event()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()


## Bigger touch target than the drawing (fingers are not mice).
func _has_point(p: Vector2) -> bool:
	return Rect2(Vector2(-10, -12), size + Vector2(20, 24)).has_point(p)


func _refresh() -> void:
	var on: bool = Progress.has_feature("daily")
	visible = on
	if not on:
		return
	var n: int = Progress.streak_shown()
	var lit: bool = Progress.streak_today()
	var w := 30.0 + UiTheme.heavy_font().get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x + 6.0
	if absf(custom_minimum_size.x - w) > 0.5:
		custom_minimum_size.x = w
	if n != _count or lit != _lit:
		_count = n
		_lit = lit
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 10.0) != int((_t - delta) * 10.0):
		_refresh()
	if not visible:
		return
	_pop = maxf(0.0, _pop - delta * 1.5)
	var ph := StreakArt.phase(_t, 7.0 if _lit else 2.5)
	if ph != _ph or _pop > 0.0:
		_ph = ph
		queue_redraw()


func _draw() -> void:
	var s := size
	var grow := 1.0 + sin(_pop * PI) * 0.35
	var fr := 10.0 * grow
	Art.push(self, Vector2(15, s.y - 3.0))
	StreakArt.flame(self, Vector2.ZERO, snappedf(fr, 1.0), maxi(_ph, 0), _lit, true)
	Art.pop(self)
	var col := Color("ffd27a") if _lit else Color("d9d0ee")
	Art.text(self, Vector2(31, s.y / 2.0 + FONT_PX * 0.36), str(maxi(_count, 0)), FONT_PX, col, 6, false)
