class_name ChestBubble
extends Control
## A treasure chest in a big bubble that floats in the shallow water when
## Progress has one ready. Tapping it pops the bubble and opens the chest.

signal opened(reward: Dictionary, at: Vector2)

const R := 58.0

var world: World
var _t := 0.0
var _appear := 0.0
var _pop := -1.0


func _ready() -> void:
	size = Vector2(R * 2.4, R * 2.4)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pop < 0.0:
		var r := Progress.open_chest()
		if r.is_empty():
			return
		accept_event()
		_pop = 0.0
		Sfx.play("chest")
		Sfx.voice("wow", 1.2)
		Settings.buzz(30)
		opened.emit(r, get_global_rect().get_center())


func _process(delta: float) -> void:
	var want := Progress.chest_ready
	if _pop >= 0.0:
		_pop += delta
		if _pop > 0.35:
			_pop = -1.0
			_appear = 0.0
	elif want and not visible:
		_appear = 0.0
	visible = want or _pop >= 0.0
	if not visible:
		return
	_t += delta
	_appear = minf(1.0, _appear + delta * 1.5)
	# Drift slowly left and right in the band between the surface and the rock.
	var w := world.scene_right() if world.size.x > 0.0 else 600.0
	var x := w * 0.55 + sin(_t * 0.35) * w * 0.12
	var y := World.SURFACE_Y + 92.0 + sin(_t * 1.7) * 8.0 + (1.0 - _appear) * 60.0
	position = Vector2(x, y) - size / 2.0
	if World.anim_tick():
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var pop := maxf(0.0, _pop)
	var k := ease(_appear, -2.0) * (1.0 + pop * 1.4)
	var a := 1.0 - pop / 0.35 if _pop >= 0.0 else 1.0
	Art.push(self, c, sin(_t * 1.3) * 0.08, Vector2(k, k))
	if _pop < 0.0:
		# Chest.
		Art.t_rect(self, Rect2(-34, -6, 68, 38), 7, Color("b8743a"), 3.0, 0.6)
		Art.toon(self, Art.smooth_pts(PackedVector2Array([Vector2(-34, -2), Vector2(-30, -26), Vector2(0, -34), Vector2(30, -26), Vector2(34, -2)]), 4), Color("d8924a"), 3.0, 0.5)
		Art.t_rect(self, Rect2(-8, -12, 16, 20), 4, Art.GOLD, 2.5, 0.3)
		Art.line(self, Vector2(-24, -24), Vector2(-24, 30), Art.GOLD, 4.0)
		Art.line(self, Vector2(24, -24), Vector2(24, 30), Art.GOLD, 4.0)
		# Glow peeking out of the lid.
		Art.flat(self, Art.ellipse_pts(Vector2(0, -3), Vector2(30, 4)), Color(1.0, 0.95, 0.5, 0.5 + 0.3 * sin(_t * 4.0)))
	# The bubble.
	Art.disc(self, Vector2.ZERO, R, Color(0.75, 0.95, 1.0, 0.18 * a))
	Art.arc(self, Vector2.ZERO, R, 0, TAU, 40, Color(1, 1, 1, 0.85 * a), 4.0)
	Art.arc(self, Vector2.ZERO, R - 10, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.8 * a), 6.0)
	Art.disc(self, Vector2(R * 0.45, -R * 0.5), 5.0, Color(1, 1, 1, 0.8 * a))
	# Sparkles around.
	if _pop < 0.0:
		for i in 3:
			var ph := _t * 1.8 + i * 2.1
			var s := maxf(0.0, sin(ph)) * 7.0
			var p := Vector2(cos(i * 2.2 + 0.4), sin(i * 2.2 + 0.4)) * (R + 8.0)
			Art.flat(self, Art.star_pts(p, s, s * 0.35, 4), Color(1, 0.95, 0.6, 0.9))
	Art.pop(self)
