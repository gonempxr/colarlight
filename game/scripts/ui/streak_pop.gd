class_name StreakPop
extends Control
## The little party for the first small action of a new day: a card slides
## in under the top bar, the flame grows, the count ticks up with a "+1",
## and the day's reward (more on milestone days) flies into the top bar.
## It never blocks play: it goes away by itself; a tap opens the streak screen.

signal tapped

const SHOW_SEC := 3.6
const W := 430.0
const H := 118.0

## main.gd: celebrate(r, from, sound) and where the card hangs from the top.
var main: Node
var top_y := 120.0
var _card: PanelContainer
var _art: ArtView
var _title: Label
var _sub: Label
var _res: Dictionary = {}
var _age := 99.0
var _given := false
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var sb := UiTheme.panel_box(Color("fff6e0"), 26, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", sb)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Sfx.play("click")
			hide_pop()
			tapped.emit())
	_card.visible = false
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(h)
	_art = ArtView.make(_paint, Vector2(150, 100), true)
	h.add_child(_art)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_title = Views.label("", 24, Color("e0641c"), true)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_sub = Views.label("", 17, Art.INK_SOFT)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_sub)


## Shows the party for a Progress.streak_lit result.
func show_result(res: Dictionary) -> void:
	_res = res
	_age = 0.0
	_given = false
	var n := int(res.get("count", 1))
	if res.get("broken", false):
		_title.text = t("STREAK_WELCOME_BACK")
		_sub.text = t("STREAK_NEW_FLAME")
	elif int(res.get("milestone", 0)) > 0:
		_title.text = StreakView.days_text(n) + "!"
		_sub.text = t("STREAK_MILESTONE")
	elif int(res.get("old", 0)) <= 0:
		_title.text = t("STREAK_FIRST")
		_sub.text = t("STREAK_FIRST_SUB")
	else:
		_title.text = StreakView.days_text(n) + "!"
		_sub.text = t("STREAK_KEEP_GOING")
	if int(res.get("ice_used", 0)) > 0:
		_sub.text = t("STREAK_ICE_SAVED")
	elif res.get("ice_earned", false):
		_sub.text = t("STREAK_ICE_EARNED")
	# Over everything opened later (the puzzle, fishing).
	get_parent().move_child(self, -1)
	_layout()
	_card.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var y := _card.position.y
	if Settings.reduce_motion:
		_card.modulate.a = 1.0
	else:
		_card.position.y = -_card.size.y - 20.0
		_card.modulate.a = 1.0
		_tween.tween_property(_card, "position:y", y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(SHOW_SEC)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.4)
	_tween.parallel().tween_property(_card, "position:y", y - 30.0, 0.4).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _card.visible = false)
	Sfx.play("milestone" if int(res.get("milestone", 0)) > 0 else "unlock")
	Sfx.voice("woohoo" if int(res.get("milestone", 0)) > 0 else "yay", 1.1)
	Settings.buzz(40)


func hide_pop() -> void:
	_give()
	if _tween:
		_tween.kill()
	_card.visible = false


func is_showing() -> bool:
	return _card.visible


func _layout() -> void:
	var view := get_viewport_rect().size
	var w := minf(W, view.x - 24.0)
	_card.custom_minimum_size = Vector2(w, H)
	_title.custom_minimum_size.x = w - 150.0 - 40.0
	_sub.custom_minimum_size.x = w - 150.0 - 40.0
	_card.reset_size()
	_card.size = Vector2(w, maxf(H, _card.get_combined_minimum_size().y))
	_card.position = Vector2(roundf((view.x - w) / 2.0), top_y)


func _process(delta: float) -> void:
	if not _card.visible:
		return
	_age += delta
	if _age > 0.75 and not _given:
		_give()


## Hands out the reward once the flame has grown (pearls fly to the top bar).
func _give() -> void:
	if _given:
		return
	_given = true
	var r: Dictionary = Progress.take_streak_reward()
	if r.is_empty() or main == null:
		return
	var from := _art.get_global_rect().position + Vector2(48, 60)
	main.celebrate(r, from, false)
	Sfx.play("coins")


func _paint(ci: CanvasItem, s: Vector2, _tt: float) -> void:
	var a := _age
	# The flame grows from the old size with a little overshoot.
	var g := clampf(a / 0.6, 0.0, 1.0)
	var e := 1.0 + 0.25 * sin(g * PI) if not Settings.reduce_motion else 1.0
	var base := Vector2(48, s.y - 8.0)
	if a < 1.2:
		var k := clampf(1.0 - a / 1.2, 0.0, 1.0)
		var c := base + Vector2(0, -38)
		for i in 10:
			var ang := TAU * i / 10.0 + floorf(a * 10.0) * 0.05
			var ray := Color(1.0, 0.8, 0.3, 0.45 * k)
			Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(ang - 0.14), sin(ang - 0.14)) * 70.0, c + Vector2(cos(ang + 0.14), sin(ang + 0.14)) * 70.0]),
					PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
	Art.push(ci, base, 0.0, Vector2.ONE * snappedf(e * (0.75 + 0.25 * g), 0.05))
	StreakArt.flame(ci, Vector2.ZERO, 22.0, StreakArt.phase(a, 8.0), true, true)
	Art.pop(ci)
	var n := int(_res.get("count", 1))
	var shown := n if a > 0.45 else maxi(0, int(_res.get("old", 0)) if not _res.get("broken", false) else 0)
	var bump := 1.0 + 0.3 * sin(clampf((a - 0.45) / 0.3, 0.0, 1.0) * PI)
	Art.push(ci, Vector2(112, s.y / 2.0 + 4.0), 0.0, Vector2.ONE * snappedf(bump, 0.05))
	Art.text(ci, Vector2(0, 14), str(shown), 44, Color("ffb347"), 9)
	Art.pop(ci)
	if a > 0.45 and a < 1.8:
		var k := (a - 0.45) / 1.35
		Art.text(ci, Vector2(124, 30 - k * 26.0), "+1", 24, Color(1.0, 0.95, 0.6, 1.0 - k * k), 6)


static func t(key: String) -> String:
	return TranslationServer.translate(key)
