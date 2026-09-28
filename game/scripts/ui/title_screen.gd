class_name TitleScreen
extends Control
## First screen: the logo over the living ocean and a big Play button.
## On the web the first tap also unlocks audio, so music starts here.

signal started

var _logo: TextureRect
var _play: Button
var _t := 0.0
var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/logo.svg")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_play = Button.new()
	_play.theme_type_variation = &"GoldButton"
	_play.add_theme_font_size_override("font_size", 40)
	_play.custom_minimum_size = Vector2(330, 110)
	_play.pressed.connect(_on_play)
	add_child(_play)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var v := get_viewport_rect().size
	var lw := minf(v.x - 40.0, 900.0)
	_logo.size = Vector2(lw, lw * 0.33)
	_logo.position = Vector2((v.x - lw) / 2.0, v.y * 0.2)
	_play.size = _play.custom_minimum_size
	_play.position = Vector2((v.x - _play.size.x) / 2.0, v.y * 0.62)
	_play.pivot_offset = _play.size / 2.0
	_logo.pivot_offset = _logo.size / 2.0


func _process(delta: float) -> void:
	_t += delta
	_play.text = tr("PLAY")
	if not _leaving:
		_logo.rotation = sin(_t * 1.3) * 0.02
		_logo.scale = Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.015)
		_play.scale = Vector2.ONE * (1.0 + absf(sin(_t * 3.0)) * 0.05)
	queue_redraw()


func _draw() -> void:
	# Dim the scene and put a slow sunburst behind the logo.
	var v := size
	var top := Color(0.05, 0.08, 0.25, 0.72)
	var low := Color(0.05, 0.08, 0.25, 0.45)
	Art.grad(self, PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), Vector2(v.x, v.y), Vector2(0, v.y)]), PackedColorArray([top, top, low, low]))
	var c := _logo.position + _logo.size / 2.0
	var r := maxf(v.x, v.y)
	for i in 16:
		var a := _t * 0.12 + TAU * i / 16.0
		var ray := Color(1.0, 0.9, 0.5, 0.09)
		Art.grad(self, PackedVector2Array([c, c + Vector2(cos(a - 0.09), sin(a - 0.09)) * r, c + Vector2(cos(a + 0.09), sin(a + 0.09)) * r]), PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))


func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("start")
	Sfx.start_music()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_property(_logo, "position:y", _logo.position.y - 120.0, 0.35).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		started.emit()
		queue_free())
