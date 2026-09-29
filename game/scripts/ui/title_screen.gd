class_name TitleScreen
extends Control
## First screen: the logo drops in over the living ocean, bubbles rise and
## a big Play button pops up. A new player types their name here; a known
## one gets a hello and can switch to another player.
## On the web the first tap also unlocks audio, so music starts here.

signal started
signal players_pressed

var _logo: TextureRect
var _play: Button
var _hello: Label
var _name: LineEdit
var _switch: Button
var _t := 0.0
var _leaving := false
var _intro := 0.0
var _bubbles: Array[Vector3] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/logo.svg")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_hello = Label.new()
	_hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hello.add_theme_font_override("font", UiTheme.heavy_font())
	_hello.add_theme_font_size_override("font_size", 38)
	_hello.add_theme_constant_override("outline_size", 10)
	add_child(_hello)
	_name = LineEdit.new()
	_name.max_length = Profiles.NAME_MAX
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size = Vector2(420, 84)
	_name.text_submitted.connect(func(_t): _on_play())
	add_child(_name)
	_play = Button.new()
	_play.theme_type_variation = &"GoldButton"
	_play.add_theme_font_size_override("font_size", 44)
	_play.custom_minimum_size = Vector2(340, 116)
	_play.pressed.connect(_on_play)
	add_child(_play)
	_switch = Button.new()
	_switch.theme_type_variation = &"BlueButton"
	_switch.icon = Icons.get_icon("people", 38)
	_switch.add_theme_font_size_override("font_size", 22)
	_switch.custom_minimum_size = Vector2(0, 70)
	_switch.pressed.connect(func(): Sfx.play("click"); players_pressed.emit())
	add_child(_switch)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		_bubbles.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(4.0, 13.0)))
	Profiles.switched.connect(_update_player)
	_update_player()
	_layout()
	get_viewport().size_changed.connect(_layout)


func _update_player() -> void:
	var name := Profiles.player_name()
	_name.visible = name == ""
	_hello.text = tr("HELLO") % name if name != "" else tr("WHATS_YOUR_NAME")
	_switch.visible = Profiles.list.size() > 1 or name != ""
	if is_inside_tree():
		_layout()


func _layout() -> void:
	var v := get_viewport_rect().size
	var lw := minf(v.x - 40.0, 900.0)
	_logo.size = Vector2(lw, lw * 0.33)
	_logo.position = Vector2((v.x - lw) / 2.0, v.y * 0.14)
	_logo.pivot_offset = _logo.size / 2.0
	var y := _logo.position.y + _logo.size.y + v.y * 0.05
	_hello.size = Vector2(v.x - 40.0, 50)
	_hello.position = Vector2(20, y)
	y += 70.0
	_name.size = Vector2(minf(460.0, v.x - 60.0), 84)
	_name.position = Vector2((v.x - _name.size.x) / 2.0, y)
	y += 120.0 if _name.visible else 30.0
	_play.size = _play.custom_minimum_size
	_play.position = Vector2((v.x - _play.size.x) / 2.0, maxf(y, v.y * 0.52))
	_play.pivot_offset = _play.size / 2.0
	_switch.reset_size()
	_switch.position = Vector2((v.x - _switch.size.x) / 2.0, _play.position.y + _play.size.y + 30.0)


func _process(delta: float) -> void:
	_t += delta
	_intro = minf(1.0, _intro + delta / 1.1)
	_play.text = tr("PLAY")
	_switch.text = tr("SWITCH_PLAYER")
	_name.placeholder_text = tr("NAME_PLACEHOLDER")
	if not _leaving:
		# Intro: the logo drops in with a bounce, then the rest pops in.
		var drop := 1.0 - _ease_bounce(clampf(_intro / 0.75, 0.0, 1.0))
		if Settings.reduce_motion:
			drop = 0.0
		_logo.rotation = sin(_t * 1.3) * 0.02
		_logo.scale = Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.015)
		_logo.position.y = get_viewport_rect().size.y * 0.14 - drop * 520.0
		var pop := clampf((_intro - 0.55) / 0.45, 0.0, 1.0)
		_play.scale = Vector2.ONE * _ease_back(pop) * (1.0 + absf(sin(_t * 3.0)) * 0.05 * pop)
		_hello.modulate.a = pop
		_name.modulate.a = pop
		_switch.modulate.a = pop
	queue_redraw()


static func _ease_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func _ease_bounce(x: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if x < 1.0 / d1:
		return n1 * x * x
	elif x < 2.0 / d1:
		x -= 1.5 / d1
		return n1 * x * x + 0.75
	elif x < 2.5 / d1:
		x -= 2.25 / d1
		return n1 * x * x + 0.9375
	x -= 2.625 / d1
	return n1 * x * x + 0.984375


func _draw() -> void:
	# Dim the scene, a slow sunburst behind the logo and bubbles drifting up.
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
	for b in _bubbles:
		var y := fposmod(b.y - _t * (0.04 + b.z * 0.004), 1.0) * (v.y + 40.0) - 20.0
		var x := b.x * v.x + sin(_t * 1.5 + b.x * 20.0) * 10.0
		Art.arc(self, Vector2(x, y), b.z, 0, TAU, 16, Color(1, 1, 1, 0.55), 2.5)
		Art.disc(self, Vector2(x - b.z * 0.35, y - b.z * 0.35), b.z * 0.25, Color(1, 1, 1, 0.6))


func _on_play() -> void:
	if _leaving:
		return
	if _name.visible:
		var name := Profiles.clean_name(_name.text)
		if name == "":
			# A name lets each child find their own game: a gentle nudge.
			Sfx.play("deny")
			_name.grab_focus()
			var x0 := _name.position.x
			var tw := create_tween()
			for i in 3:
				tw.tween_property(_name, "position:x", x0 + 12.0, 0.04)
				tw.tween_property(_name, "position:x", x0 - 12.0, 0.04)
			tw.tween_property(_name, "position:x", x0, 0.04)
			return
		Profiles.set_name_of(Profiles.current_id, name)
	_leaving = true
	Sfx.play("start")
	Sfx.start_music()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_property(_logo, "position:y", _logo.position.y - 120.0, 0.35).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		started.emit()
		queue_free())
