class_name ToonBox
extends StyleBox
## Cartoon box used for every button and panel: dark outline, a darker
## "3D" base under the face, a soft gloss on top and an optional drop
## shadow. Pressed buttons sink into their base.

var fill := Color.WHITE
var line := Art.INK
var line_w := 4.0
var depth := 6.0
var radius := 18.0
var gloss := 0.22
var shadow := 0.2
var pressed := false
## Sheets glued to the screen bottom: square off the lower corners by
## drawing past the bottom edge.
var open_bottom := false
var open_top := false


static func make(color: Color, r: float = 18.0, d: float = 6.0, is_pressed: bool = false) -> ToonBox:
	var b := ToonBox.new()
	b.fill = color
	b.radius = r
	b.depth = d
	b.pressed = is_pressed
	b.content_margin_left = 16 + b.line_w
	b.content_margin_right = 16 + b.line_w
	b.content_margin_top = 8 + b.line_w + (d if is_pressed else 0.0)
	b.content_margin_bottom = 8 + b.line_w + (0.0 if is_pressed else d)
	return b


func _flat(color: Color, r: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	# 4 px of corner per segment is smooth at any size the boxes come in.
	sb.corner_detail = clampi(ceili(r / 4.0), 3, 8)
	return sb


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if open_bottom:
		rect.size.y += radius * 2.0 + depth
	if open_top:
		rect.position.y -= radius * 2.0
		rect.size.y += radius * 2.0
	if shadow > 0.0 and not open_bottom:
		# A soft drop shadow lifts every card and button off the scene.
		var sh := _flat(Color(0, 0, 0, 0), radius)
		sh.shadow_color = Color(0.04, 0.02, 0.14, shadow)
		sh.shadow_size = 7
		sh.shadow_offset = Vector2(0, 5)
		sh.draw(to_canvas_item, rect.grow(-2))
	# Outline around everything.
	_flat(line, radius).draw(to_canvas_item, rect)
	var inner := rect.grow(-line_w)
	var r := maxf(2.0, radius - line_w)
	var sink := depth if pressed else 0.0
	if depth > 0.0:
		_flat(Art.shade_of(fill, 0.38), r).draw(to_canvas_item, Rect2(inner.position + Vector2(0, sink), inner.size - Vector2(0, sink)))
	var face := Rect2(inner.position + Vector2(0, sink), inner.size - Vector2(0, depth))
	_flat(fill, r).draw(to_canvas_item, face)
	# The lower part of the face a touch darker: light from above.
	if face.size.y > 16.0:
		var low := Rect2(face.position + Vector2(0, face.size.y * 0.55), Vector2(face.size.x, face.size.y * 0.45))
		_flat(Color(Art.SHADE, 0.07), minf(r, low.size.y / 2.0)).draw(to_canvas_item, low)
	if gloss > 0.0 and face.size.y > 12.0:
		var g := Rect2(face.position + Vector2(r * 0.35 + 3, 3), Vector2(face.size.x - r * 0.7 - 6, face.size.y * 0.38))
		_flat(Color(1, 1, 1, gloss), minf(r, g.size.y / 2.0)).draw(to_canvas_item, g)
