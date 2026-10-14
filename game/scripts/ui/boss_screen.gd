class_name BossScreen
extends Control
## A mine boss fight (MineBoss, GameState.boss_*) on its own screen.
## Ready card -> fight (MineBoss.FIGHT_SEC): a ring shrinks onto a glowing
## weak spot; tap while it is on it. A hit takes GameState.boss_hit() off the
## boss's health (a perfect tap twice), times the combo (+10% per hit in a
## row, up to x2). A miss (or a ring that runs out) breaks the combo and
## costs MISS_SEC of the clock. Health 0: won (GameState.defeat_boss pays,
## the site can be opened). Time up: lost, the boss heals; try again.
## Opened by main.open_boss(key).

const MISS_SEC := 2.0
const COMBO_STEP := 0.1
const COMBO_MAX := 2.0
const RING_R := 130.0

var main: Node
## The guarded site ("d3"...).
var key := ""
var _boss := ""
var _state := "ready"
var _hp := 1.0
var _hp_max := 1.0
var _left := MineBoss.FIGHT_SEC
var _combo := 0
var _t := 0.0
var _ring_t := 0.0
var _pause := 0.0
var _hurt := 0.0
var _spot := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
## Floating words and numbers: [pos, text, color, age, size].
var _pops: Array = []
## Bubbles of a hit: [pos, vel, age].
var _bubbles: Array = []
var _fight: Control
var _hud: Control
var _panel: VBoxContainer


static func t(k: String) -> String:
	return TranslationServer.translate(k)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_boss = GameState.boss_at(key)
	_hp_max = maxf(1.0, GameState.boss_hp(key))
	_hp = _hp_max
	var bg := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_bg(ci, s, tt), Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_fight = Control.new()
	_fight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fight.mouse_filter = Control.MOUSE_FILTER_STOP
	_fight.draw.connect(_draw_fight)
	_fight.gui_input.connect(_on_input)
	add_child(_fight)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(_top_bar())
	_hud = Control.new()
	_hud.custom_minimum_size = Vector2(0, 92)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	col.add_child(_hud)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	col.add_child(_panel)
	_new_spot()
	_show_panel()
	Sfx.play("start")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _top_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.theme_type_variation = &"RedButton"
	back.icon = Icons.get_icon("close", 34)
	back.custom_minimum_size = Vector2(76, 76)
	back.pressed.connect(close)
	h.add_child(back)
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 76)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.draw.connect(func(): UiTheme.draw_banner(banner, Rect2(Vector2.ZERO, banner.size), Color("c0369a")))
	banner.resized.connect(banner.queue_redraw)
	var l := Label.new()
	l.text = t(MineBoss.name_key(_boss))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_bottom = -6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_constant_override("outline_size", 10)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	banner.add_child(l)
	h.add_child(banner)
	return h


# --- Drawing --------------------------------------------------------------------------

func _draw_bg(ci: CanvasItem, s: Vector2, tt: float) -> void:
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("6a46d8"), Color("6a46d8"), Color("161650"), Color("161650")]))
	# Light rays from above.
	for i in 5:
		var x := s.x * (0.08 + i * 0.22)
		var sway := snappedf(sin(tt * 0.4 + i) * 20.0, 4.0)
		Art.grad(ci, PackedVector2Array([Vector2(x - 30 + sway, 0), Vector2(x + 30 + sway, 0), Vector2(x + 150, s.y * 0.85), Vector2(x - 50, s.y * 0.85)]),
			PackedColorArray([Color(1, 0.85, 1, 0.12), Color(1, 0.85, 1, 0.12), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	DeepArt.draw_seabed(ci, s, tt)
	for i in 14:
		var bx := fposmod(i * 97.0, s.x)
		var by := s.y - fposmod(snappedf(tt * (24.0 + i * 3.0), 2.0) + i * 131.0, s.y + 40.0)
		Art.ring(ci, Art.circle_pts(Vector2(bx, by), 4.0 + i % 4 * 2.0, 12), Color(1, 1, 1, 0.22), 2.0)


func _center() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.47)


func _scale() -> float:
	return clampf(minf(size.x / 300.0, size.y / 560.0), 0.9, 2.0)


func _draw_fight() -> void:
	var ci := _fight
	var c := _center()
	var k := _scale()
	var anger := 1.0 - _hp / _hp_max if _state == "fight" else 0.0
	Art.glow(ci, c, 210.0 * k, Color(1.0, 0.6, 0.95, 0.16))
	if _state == "won":
		# Knocked out: tipped over, sunk a little, stars circling.
		Art.push(ci, c + Vector2(0, 40.0 * k), -0.25)
		BossArt.draw(ci, _boss, Vector2.ZERO, k * 0.92, 0.0, 1.0, 0.0)
		Art.pop(ci)
		for i in 4:
			var a := _t * 2.4 + i * TAU / 4.0
			var p := c + Vector2(cos(a) * 70.0, sin(a) * 18.0 - 110.0) * k
			Art.toon(ci, Art.star_pts(Vector2(snappedf(p.x, 1.0), snappedf(p.y, 1.0)), 12.0, 5.0, 5), Art.GOLD, 2.4, 0.0)
	else:
		BossArt.draw(ci, _boss, c, k, _t, _hurt, anger)
	if _state == "fight":
		var spot := c + _spot * k
		Art.glow(ci, spot, 34.0, Color(1.0, 0.86, 0.3, 0.6))
		Art.t_circle(ci, spot, 13.0, Color("ffe066"), 3.0, 0.0)
		Art.t_circle(ci, spot, 5.0, Art.WHITE, 0.0, 0.0)
		if _pause <= 0.0:
			var u := _ring_t / _cycle()
			var good := MineBoss.judge(_boss, u)
			var rr := maxf(3.0, RING_R * (1.0 - u) + 13.0 * u / MineBoss.SPOT_AT)
			Art.arc(ci, spot, snappedf(rr, 0.5), 0.0, TAU, 44, Color("7fffb0") if good == 2 else (Color("bff8ff") if good == 1 else Art.WHITE), 6.0 if good > 0 else 4.0)
	for b in _bubbles:
		var a: float = 1.0 - float(b[2]) / 0.6
		Art.ring(ci, Art.circle_pts(b[0], 5.0 + float(b[2]) * 10.0, 12), Color(1, 1, 1, snappedf(a, 0.05)), 2.4)
	for p in _pops:
		var a2: float = clampf(1.4 - float(p[3]), 0.0, 1.0)
		var col: Color = p[2]
		Art.text(ci, p[0] + Vector2(0, -float(p[3]) * 60.0), str(p[1]), int(p[4]), Color(col, snappedf(a2, 0.05)), 8)


func _draw_hud() -> void:
	var s := _hud.size
	# Health bar.
	var bar := Rect2(4, 6, s.x - 8, 40)
	Art.t_rect(_hud, bar, 20.0, Color("2a1050"), 3.5, 0.0)
	var f := clampf(_hp / _hp_max, 0.0, 1.0)
	if f > 0.005:
		Art.t_rect(_hud, Rect2(bar.position, Vector2(maxf(40.0, bar.size.x * f), bar.size.y)), 20.0, Color("ff4a7a"), 3.5, 0.6)
	Art.text(_hud, bar.get_center() + Vector2(0, 9), "%s / %s" % [NumFormat.short(_hp), NumFormat.short(_hp_max)], 22, Art.WHITE, 7)
	# The clock.
	var tb := Rect2(40, 54, s.x - 80, 26)
	Art.t_rect(_hud, tb, 13.0, Color("10204a"), 3.0, 0.0)
	var tf := clampf(_left / MineBoss.FIGHT_SEC, 0.0, 1.0)
	if tf > 0.01:
		Art.t_rect(_hud, Rect2(tb.position, Vector2(maxf(26.0, tb.size.x * tf), tb.size.y)), 13.0, Color("6af8ff") if tf > 0.25 else Color("ffd23f"), 3.0, 0.5)
	Art.text(_hud, tb.get_center() + Vector2(0, 7), "%d %s" % [ceili(_left), t("BOSS_SEC")], 18, Art.WHITE, 6)
	if _combo >= 2:
		Art.text(_hud, Vector2(s.x - 22, 72), "×%.1f" % _mult(), 22, Color("ffe066"), 7)


# --- Fight ----------------------------------------------------------------------------

func _cycle() -> float:
	return float(MineBoss.data(_boss)["cycle"])


func _mult() -> float:
	return minf(COMBO_MAX, 1.0 + COMBO_STEP * maxi(0, _combo - 1))


func _new_spot() -> void:
	var spots := [Vector2(-40, -20), Vector2(30, -40), Vector2(0, 20), Vector2(50, 10), Vector2(-60, 30), Vector2(20, -70)]
	_spot = spots[_rng.randi() % spots.size()]


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta * 3.0)
	for p in _pops:
		p[3] = float(p[3]) + delta
	_pops = _pops.filter(func(p): return float(p[3]) < 1.4)
	for b in _bubbles:
		b[0] = b[0] + b[1] * delta
		b[2] = float(b[2]) + delta
	_bubbles = _bubbles.filter(func(b): return float(b[2]) < 0.6)
	if _state == "fight":
		_left -= delta
		if _pause > 0.0:
			_pause -= delta
		else:
			_ring_t += delta
			if _ring_t >= _cycle():
				_judge(0)
		if _left <= 0.0 and _state == "fight":
			_end(false)
	_fight.queue_redraw()
	_hud.queue_redraw()


func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap or _state != "fight" or _pause > 0.0:
		return
	_fight.accept_event()
	_judge(MineBoss.judge(_boss, _ring_t / _cycle()))


func _judge(grade: int) -> void:
	var spot := _center() + _spot * _scale()
	_ring_t = 0.0
	_pause = 0.22
	if grade == 0:
		_combo = 0
		_left = maxf(0.0, _left - MISS_SEC)
		_pops.append([spot, t("BOSS_MISS"), Color("ff8a9a"), 0.0, 28])
		Sfx.play("deny")
		return
	_combo += 1
	var dmg := GameState.boss_hit(key, grade == 2) * _mult()
	_hp = maxf(0.0, _hp - dmg)
	_hurt = 1.0
	_pops.append([spot + Vector2(0, -20), "-" + NumFormat.short(dmg), Color("ffffff"), 0.0, 30])
	if grade == 2:
		_pops.append([spot + Vector2(0, -60), t("BOSS_PERFECT"), Color("7fffb0"), 0.0, 32])
	for i in 6:
		var a := TAU * i / 6.0
		_bubbles.append([spot, Vector2(cos(a), sin(a)) * 120.0, 0.0])
	Sfx.play("tap" if grade == 1 else "coins")
	_new_spot()
	if _hp <= 0.0:
		_end(true)


func _start() -> void:
	_state = "fight"
	_hp = _hp_max
	_left = MineBoss.FIGHT_SEC
	_combo = 0
	_ring_t = 0.0
	_pause = 0.8
	_show_panel()
	Sfx.play("dive")


func _end(won: bool) -> void:
	_state = "won" if won else "lost"
	_combo = 0
	Sfx.play("milestone" if won else "deny")
	_show_panel()


# --- Panels ---------------------------------------------------------------------------

func _show_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()
	match _state:
		"fight":
			var hint := Views.label(t("BOSS_HINT"), 19, Color("dfe4ff"), true)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_panel.add_child(hint)
		"ready":
			_card(t("BOSS_READY") % [NumFormat.short(_hp_max), NumFormat.short(GameState.boss_hit(key)), int(MineBoss.FIGHT_SEC)], Color("dfe4ff"))
			_button(t("BOSS_FIGHT"), &"GoldButton", _start)
		"won":
			var got := GameState.defeat_boss(key)
			var text := t("BOSS_WON") % [int(got.get("pearls", 0)), NumFormat.short(float(got.get("coins", 0.0)))]
			_card(text, Color("7fffb0"))
			_button(t("BOSS_COLLECT"), &"GoldButton", close)
		"lost":
			_card(t("BOSS_LOST"), Color("ffb4a8"))
			_button(t("BOSS_AGAIN"), &"GoldButton", _start)


func _card(text: String, color: Color) -> void:
	var card := Views.card(Color("2a1e6a"))
	var l := Views.label(text, 20, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)
	_panel.add_child(card)


func _button(text: String, variation: StringName, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	_panel.add_child(b)
