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
var shadow := 0.0
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
	sb.corner_detail = 10
	return sb


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if open_bottom:
		rect.size.y += radius * 2.0 + depth
	if open_top:
		rect.position.y -= radius * 2.0
		rect.size.y += radius * 2.0
	if shadow > 0.0:
		_flat(Color(0.05, 0.02, 0.15, shadow), radius + 2).draw(to_canvas_item, Rect2(rect.position + Vector2(0, 6), rect.size))
	# Outline around everything.
	_flat(line, radius).draw(to_canvas_item, rect)
	var inner := rect.grow(-line_w)
	var r := maxf(2.0, radius - line_w)
	var sink := depth if pressed else 0.0
	if depth > 0.0:
		_flat(Art.shade_of(fill, 0.38), r).draw(to_canvas_item, Rect2(inner.position + Vector2(0, sink), inner.size - Vector2(0, sink)))
	var face := Rect2(inner.position + Vector2(0, sink), inner.size - Vector2(0, depth))
	_flat(fill, r).draw(to_canvas_item, face)
	if gloss > 0.0 and face.size.y > 12.0:
		var g := Rect2(face.position + Vector2(r * 0.35 + 3, 3), Vector2(face.size.x - r * 0.7 - 6, face.size.y * 0.38))
		_flat(Color(1, 1, 1, gloss), minf(r, g.size.y / 2.0)).draw(to_canvas_item, g)
