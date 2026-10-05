class_name HandCursor
extends RefCounted
## The cartoon glove cursor on PC (game/assets/cursor): the open hand, and
## the pressing one while a mouse button is held. Touch devices keep the
## system's (no cursor at all). The fingertip is the hotspot (10, 1); on a
## native HiDPI screen the picture is drawn twice as big.

const HAND := "res://assets/cursor/hand.png"
const PRESS := "res://assets/cursor/hand_press.png"
const HOTSPOT := Vector2(10, 1)

static var _on := false
static var _down := false
static var _imgs := {}
static var _touch := -1


## A phone or tablet (no mouse to show a cursor for).
static func touch_device() -> bool:
	if _touch < 0:
		var t := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
		if not t and OS.has_feature("web"):
			var coarse = JavaScriptBridge.eval("(window.matchMedia && matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches) ? 1 : 0", true)
			t = int(coarse) == 1
		_touch = 1 if t else 0
	return _touch == 1


static func is_on() -> bool:
	return _on


## Turns the glove on or off (Settings "hand cursor"; never on touch).
static func apply(enabled: bool) -> void:
	var want := enabled and not touch_device() and DisplayServer.get_name() != "headless"
	if want == _on:
		return
	_on = want
	_down = false
	_put(false)


## The pressing glove while a mouse button is down.
static func press(down: bool) -> void:
	if not _on or down == _down:
		return
	_down = down
	_put(down)


static func _put(down: bool) -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		if not _on:
			Input.set_custom_mouse_cursor(null, shape)
		else:
			Input.set_custom_mouse_cursor(_image(down), shape, HOTSPOT * _scale())


## Native HiDPI screens (not the web: a CSS cursor is in CSS pixels).
static func _scale() -> float:
	if OS.has_feature("web"):
		return 1.0
	return 2.0 if DisplayServer.screen_get_scale() >= 1.75 else 1.0


static func _image(down: bool) -> Resource:
	var k := "%s%d" % ["p" if down else "h", int(_scale())]
	if not _imgs.has(k):
		var tex: Texture2D = load(PRESS if down else HAND)
		var img := tex.get_image()
		if _scale() > 1.0:
			img.resize(int(img.get_width() * _scale()), int(img.get_height() * _scale()), Image.INTERPOLATE_LANCZOS)
		_imgs[k] = ImageTexture.create_from_image(img)
	return _imgs[k]
