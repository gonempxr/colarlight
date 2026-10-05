class_name EvoCard
extends PanelContainer
## Card for the workers' evolution next to the lift and boat cards (room 1;
## the PC side column): the worker's look now and the next one, the income
## bonus, and a button with the next form's price that opens the evolution
## panel. Same build as StageCard (name tab, picture, button) so the cards
## in a row line up.

signal open_panel

var hero := false
var narrow := false
var _name: Label
var _pic: ArtView
var _rate: Label
var _btn: PriceButton
var _sig := []
var _check_left := 0.0


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var head := PanelContainer.new()
	var hsb := ToonBox.make(Color("a46cf0"), 12, 0)
	hsb.line_w = 3.0
	hsb.gloss = 0.25
	hsb.content_margin_left = 10
	hsb.content_margin_right = 10
	hsb.content_margin_top = 2
	hsb.content_margin_bottom = 4
	head.add_theme_stylebox_override("panel", hsb)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.heavy_font())
	_name.add_theme_font_size_override("font_size", 19)
	_name.add_theme_constant_override("outline_size", 6)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.custom_minimum_size = Vector2(40, 55 if narrow else 0)
	head.add_child(_name)
	_name.resized.connect(_fit_name)
	_pic = ArtView.make(_draw_pic, Vector2(0, 170.0 if hero and not narrow else (150.0 if hero else 84.0)), true)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pic)
	_rate = Label.new()
	_rate.theme_type_variation = &"InkLabel"
	_rate.add_theme_font_size_override("font_size", 18)
	_rate.add_theme_color_override("font_color", Art.GREEN_DARK)
	_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate.clip_text = true
	box.add_child(_rate)
	if narrow:
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gap)
	_btn = PriceButton.new()
	_btn.custom_minimum_size = Vector2(0, 62)
	_btn.add_theme_font_size_override("font_size", 22 if narrow else 24)
	_btn.pressed.connect(_on_press)
	box.add_child(_btn)
	if narrow:
		# The stage cards keep a line for "Bottleneck" under their button.
		var tag := Label.new()
		tag.theme_type_variation = &"InkLabel"
		tag.add_theme_font_size_override("font_size", 16)
		tag.text = " "
		box.add_child(tag)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and not Scroller.is_drag():
			_on_press())
	refresh()


func _on_press() -> void:
	if Scroller.is_drag():
		return
	Sfx.play("click")
	open_panel.emit()


func button() -> Control:
	return _btn


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0 and is_visible_in_tree():
		_check_left = 0.2
		refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sig = []
		refresh()


func refresh() -> void:
	if _btn == null:
		return
	var gs := GameState
	var e: int = gs.evo
	var done := e >= Balance.EVO_FORMS
	var cost: float = 0.0 if done else gs.evo_cost(e + 1)
	var sig := [e, gs.coins >= cost, NumFormat.short(cost), TranslationServer.get_locale(), gs.location]
	if sig == _sig:
		return
	_sig = sig
	_name.text = tr("EVO_BOARD")
	_fit_name()
	_rate.text = tr("EVO_CARD_BONUS") % roundi((Balance.evo_mult(e) - 1.0) * 100.0) if e > 0 else tr("EVO_CARD_EACH")
	if done:
		_btn.set_price(tr("EVO_ALL"), "", "coin")
		_btn.theme_type_variation = _v(&"BlueButton")
	else:
		_btn.set_price("", NumFormat.short(cost), "coin", "arrow")
		_btn.theme_type_variation = _v(&"GoldButton" if gs.coins >= cost else &"DarkButton")


func _fit_name() -> void:
	var fs := StageCard._fit_size(_name, 19, _name.size.x) if _name.size.x > 60.0 else 19
	if _name.get_theme_font_size("font_size") != fs:
		_name.add_theme_font_size_override("font_size", fs)


func _v(variation: StringName) -> StringName:
	return StringName("Slim" + String(variation)) if narrow else variation


## The look now, an arrow, and the next one (or a crown when all are bought).
func _draw_pic(ci: CanvasItem, s: Vector2, t: float) -> void:
	var w: String = GameState.world_id()
	var e: int = GameState.evo
	Art.t_rect(ci, Rect2(Vector2(2, 2), s - Vector2(4, 4)), 12.0, Color("efe4ff"), 0.0, 0.0)
	var box := minf(s.y - 6.0, s.x * 0.44)
	if e >= Balance.EVO_FORMS:
		Art.glow(ci, s / 2.0, box * 0.6, Color(Art.GOLD, 0.4))
		WorkerLooks.draw_card(ci, s / 2.0, box * 1.1, w, e, true, t)
		return
	if narrow:
		# Three cards in a row: just the next look, big.
		Art.glow(ci, s / 2.0, s.y * 0.5, Color(WorkerLooks.rarity_color(e + 1), 0.45))
		WorkerLooks.draw_card(ci, s / 2.0, minf(s.y - 6.0, s.x - 8.0), w, e + 1, true, t)
		return
	var a := Vector2(s.x * 0.27, s.y / 2.0)
	var b := Vector2(s.x * 0.73, s.y / 2.0)
	WorkerLooks.draw_card(ci, a, box * 0.86, w, e, true, t)
	Art.glow(ci, b, box * 0.55, Color(WorkerLooks.rarity_color(e + 1), 0.45))
	WorkerLooks.draw_card(ci, b, box, w, e + 1, true, t)
	var bob := 0.0 if Settings.reduce_motion else sin(t * 4.0) * 2.0
	var m := Vector2(s.x / 2.0 + bob, s.y / 2.0)
	Art.toon(ci, PackedVector2Array([m + Vector2(-8, -9), m + Vector2(8, 0), m + Vector2(-8, 9)]), Art.GOLD, 2.5, 0.0)
