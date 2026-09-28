class_name AvatarPreview
extends Control
## Big animated preview of the player's avatar for the look editor.

var _t := 0.0
var _cheer_at := -9.0


func cheer() -> void:
	_cheer_at = _t


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y - 14.0)
	Art.push(self, c)
	Art.t_ellipse(self, Vector2(0, 0), Vector2(110, 20), Art.CREAM_DARK, 3.0, 0.0)
	Art.pop(self)
	var since := _t - _cheer_at
	var hop := absf(sin(since * PI / 0.35)) * 22.0 * maxf(0.0, 1.0 - since / 0.7) if since < 0.7 else 0.0
	var cheering := since < 0.9
	Chars.person(self, c + Vector2(0, -4 - hop), 2.1, 1.0, Settings.avatar,
			{"emotion": "joy" if cheering else "happy", "blink": Chars.blinking(_t, 2.0),
			"arm_r": 2.7 if cheering else 0.3 + sin(_t * 2.0) * 0.1, "arm_l": -2.7 if cheering else -0.2,
			"hold": "" if cheering else "briefcase"})
