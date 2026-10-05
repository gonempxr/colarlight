class_name HandCursor
extends RefCounted
## The cartoon glove cursor on PC (game/assets/cursor): the open hand, and
## the pressing one while a mouse button is held. Touch devices keep the
## system's (no cursor at all). The fingertip is the hotspot (10, 2). On the
## web the cursor is a CSS image-set on the canvas, so Retina/HiDPI screens get
## the sharp @2x picture; natively a HiDPI screen gets the @2x picture.

const HAND := "res://assets/cursor/hand.png"
const PRESS := "res://assets/cursor/hand_press.png"
const HAND2 := "res://assets/cursor/hand@2x.png"
const PRESS2 := "res://assets/cursor/hand_press@2x.png"
const HOTSPOT := Vector2(10, 2)

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
	if OS.has_feature("web"):
		_put_css(down)
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		if not _on:
			Input.set_custom_mouse_cursor(null, shape)
		else:
			Input.set_custom_mouse_cursor(_image(down), shape, HOTSPOT * _scale())


## Native HiDPI screens get the @2x picture.
static func _scale() -> float:
	return 2.0 if DisplayServer.screen_get_scale() >= 1.75 else 1.0


static func _image(down: bool) -> Resource:
	var k := "%s%d" % ["p" if down else "h", int(_scale())]
	if not _imgs.has(k):
		var path: String
		if _scale() > 1.0:
			path = PRESS2 if down else HAND2
		else:
			path = PRESS if down else HAND
		var tex: Texture2D = load(path)
		_imgs[k] = tex
	return _imgs[k]


static var _css_ready := false


## Web: a stylesheet rule beats the cursor style Godot puts on the canvas
## (!important), and image-set picks the 1x or 2x picture by screen density.
static func _put_css(down: bool) -> void:
	if not _css_ready and _on:
		var rule := func(a: String, b: String) -> String:
			var u1 := "url(data:image/png;base64,%s)" % Marshalls.raw_to_base64((load(a) as Texture2D).get_image().save_png_to_buffer())
			var u2 := "url(data:image/png;base64,%s)" % Marshalls.raw_to_base64((load(b) as Texture2D).get_image().save_png_to_buffer())
			var hs := "%d %d" % [int(HOTSPOT.x), int(HOTSPOT.y)]
			return "cursor: %s %s, pointer !important; cursor: -webkit-image-set(%s 1x, %s 2x) %s, pointer !important; cursor: image-set(%s 1x, %s 2x) %s, pointer !important;" % [u1, hs, u1, u2, hs, u1, u2, hs]
		var css: String = "#canvas.hc{%s} #canvas.hc.hcp{%s}" % [rule.call(HAND, HAND2), rule.call(PRESS, PRESS2)]
		JavaScriptBridge.eval("(function(){var s=document.getElementById('hc-style');if(!s){s=document.createElement('style');s.id='hc-style';document.head.appendChild(s);}s.textContent=%s;})()" % JSON.stringify(css), true)
		_css_ready = true
	JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');if(!c)return;c.classList.toggle('hc',%s);c.classList.toggle('hcp',%s);})()" % ["true" if _on else "false", "true" if (_on and down) else "false"], true)
