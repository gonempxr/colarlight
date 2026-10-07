class_name FxLayer
extends Control
## Screen-space effects above everything: coins and pearls flying into the
## top bar, confetti bursts and floating reward texts. Never takes input.

signal arrived(kind: String)

const MAX_FLYERS := 14

var _parts: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Icons ("coin", "pearl", "star") arc from `from` to `to`, staggered.
func fly(kind: String, from: Vector2, to: Vector2, count: int = 8) -> void:
	count = clampi(count, 1, MAX_FLYERS)
	var tex := Icons.get_icon(kind, 52)
	for i in count:
		var r := TextureRect.new()
		r.texture = tex
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(52, 52)
		r.pivot_offset = Vector2(26, 26)
		r.position = from - r.size / 2.0
		r.scale = Vector2.ZERO
		add_child(r)
		var spread := Vector2(randf_range(-90, 90), randf_range(-90, 30))
		var mid := from + spread
		var delay := i * 0.05
		var dur := 0.55 + randf() * 0.15
		var tw := r.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(r, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(r, "position", mid - r.size / 2.0, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(f: float):
			var a := mid.lerp(to, f)
			a.y -= sin(f * PI) * 60.0
			r.position = a - r.size / 2.0
			r.scale = Vector2.ONE * lerpf(1.0, 0.6, f), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			arrived.emit(kind)
			if i % 3 == 0:
				Sfx.play("coins" if kind == "coin" else "pop", 1.2)
			r.queue_free())


## A burst of confetti at a screen point.
func burst(at: Vector2, count: int = 24) -> void:
	if Settings.reduce_motion:
		count = count / 3
	var colors := [Art.GOLD, Art.CORAL, Color("7be0ff"), Color("b6f36a"), Color("ff9fd0"), Art.WHITE]
	for i in count:
		var a := randf() * TAU
		var sp := randf_range(260.0, 620.0)
		_parts.append({"p": at, "v": Vector2(cos(a), sin(a) * 0.8 - 0.6) * sp, "age": 0.0, "life": randf_range(0.7, 1.2),
				"c": colors[i % colors.size()], "s": randf_range(6.0, 11.0), "r": randf() * TAU})
	queue_redraw()


## A rising text like "+120" at a screen point.
func float_text(at: Vector2, value: String, color: Color = Art.GOLD, size_px: int = 40) -> void:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	add_child(l)
	l.reset_size()
	l.position = at - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 90.0, 1.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	for p in _parts:
		p["age"] += delta
		p["v"].y += 900.0 * delta
		p["v"] *= Motion.drag(0.985, delta)
		p["p"] += p["v"] * delta
		p["r"] += delta * 8.0
	_parts = _parts.filter(func(p): return p["age"] < p["life"])
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var a := clampf(1.0 - (p["age"] / p["life"]) * (p["age"] / p["life"]), 0.0, 1.0)
		var s: float = p["s"]
		Art.push(self, p["p"], p["r"], Vector2(1.0, 0.55 + 0.45 * absf(sin(p["r"]))))
		Art.flat(self, PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, -s * 0.6), Vector2(s, s * 0.6), Vector2(-s, s * 0.6)]), Color(p["c"], a))
		Art.pop(self)
