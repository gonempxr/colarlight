class_name FishingScreen
extends Control
## Full-screen fishing on the pier: cast, wait for the float to dip, tap in
## time, reel the fish in with a simple timing game, then keep it in the
## bucket or sell it. Also the bucket, the fish book and the upgrades (rod,
## bucket, fisherman). All state lives in the Fishing autoload; this screen
## only shows it and calls it. Coins are added by Fishing itself.
##
## Usage (main.gd, like the puzzle):
##   var f := FishingScreen.new()      # or load("res://scripts/fishing/fishing_screen.gd").new()
##   add_child(f)
##   move_child(f, _fx.get_index())    # under the flying-coins layer
##   f.setup()                         # optional; setup({"panel": "book"}) opens a panel
##   f.sold.connect(func(coins, from): ...)       # optional: every sale
##   f.finished.connect(func(result): ...)         # when the player leaves
##
## sold(coins: float, from: Vector2) fires on every sale (one fish, the
##   catch card or "sell all"); `from` is the canvas position of the sale.
##   The coins are already added; the screen flies coins into its own
##   counter, so main doesn't need to do anything.
## finished(result) fires once when the player closes the screen, which
##   then fades out and frees itself.
##   result = {"coins": float (sold this visit), "caught": int, "sold": int}.

signal sold(coins: float, from: Vector2)
signal finished(result: Dictionary)

const TOP_H := 96.0
const BTN_H := 118.0
const CAST_SEC := 0.7
const LAND_SEC := 0.95
const AWAY_SEC := 1.7

var _bg: Control
var _scene: Control
var _hud: Control
var _fx: Control
var _card_layer: Control
var _modal: Modal
var _close: Button
var _action: Button
var _menu := {}
var _menu_labels := {}

var _wide := false
var _k := 1.0
var _horizon := 400.0
var _deck := Rect2()
var _player := Vector2.ZERO
var _helper_pos := Vector2.ZERO
var _helper_float := Vector2.ZERO
var _bucket_pos := Vector2.ZERO
var _target := Vector2.ZERO
var _reel_rect := Rect2()
var _pill := Rect2()

var _state := "idle"
var _st := 0.0
var _t := 0.0
var _fish := {}
var _wait_len := 3.0
var _hits := 0
var _misses := 0
var _marker := 0.0
var _dir := 1.0
var _zone := 0.5
var _zone_w := 0.3
var _speed := 0.7
var _line_pull := 0.0
var _jerk := 0.0
var _shake := 0.0
var _hint := ""
var _hint_col := Art.WHITE
var _hint_t := 0.0
var _last_tap := -1.0
var _land_from := Vector2.ZERO
var _card_info := {}
var _helper_jerk := 0.0
var _coin_bump := 0.0
var _bucket_bump := 0.0
var _shown_coins := 0.0
var _visit := {"coins": 0.0, "caught": 0, "sold": 0}
var _done := false
var _touch_input := false
var _acc := 0.0

var _drops: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _flyers: Array[Dictionary] = []
var _shadows: Array[Vector3] = []
var _clouds: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.build()
	_touch_input = not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	_rng.randomize()
	for i in 5:
		_shadows.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.3)))
	for i in 4:
		_clouds.append(Vector3(_rng.randf(), _rng.randf_range(0.2, 0.75), _rng.randf_range(0.8, 1.3)))
	_bg = _layer(_draw_bg)
	_scene = _layer(_draw_scene)
	_hud = _layer(_draw_hud)
	_close = Button.new()
	_close.theme_type_variation = &"CreamButton"
	_close.icon = Icons.get_icon("close", 34)
	_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close.custom_minimum_size = Vector2(84, 84)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	add_child(_close)
	_action = Button.new()
	_action.name = "Action"
	_action.theme_type_variation = &"GoldButton"
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 42)
	_action.add_theme_constant_override("outline_size", 9)
	_action.pressed.connect(func(): _on_action())
	add_child(_action)
	_menu_button("bucket", &"BlueButton", func(ci: CanvasItem, s: Vector2, tt: float):
		Art.push(ci, Vector2(s.x / 2.0, s.y - 4.0), 0.0, Vector2.ONE * (s.y / 62.0) * (1.0 + _bucket_bump * 0.2))
		FishArt.bucket(ci, Fishing.bucket.size(), tt, Fishing.is_full())
		Art.pop(ci))
	_menu_button("book", &"PurpleButton", func(ci: CanvasItem, s: Vector2, tt: float):
		Art.push(ci, s / 2.0, 0.0, Vector2.ONE * (s.y / 66.0))
		FishArt.book(ci, tt)
		Art.pop(ci))
	_menu_button("shop", &"Button", func(ci: CanvasItem, s: Vector2, tt: float):
		Art.push(ci, s / 2.0, 0.0, Vector2.ONE * (s.y / 66.0))
		FishArt.rod_icon(ci, tt)
		Art.pop(ci)
		if _any_affordable():
			Art.t_circle(ci, Vector2(s.x / 2.0 + s.y * 0.42, s.y * 0.12), 10.0, Art.RED, 2.2, 0.0))
	_card_layer = Control.new()
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_layer)
	_modal = Modal.new()
	add_child(_modal)
	_modal.closed.connect(_refresh_buttons)
	_fx = _layer(_draw_fx)
	Fishing.helper_caught.connect(_on_helper_caught)
	Fishing.changed.connect(_refresh_buttons)
	get_viewport().size_changed.connect(_layout)
	_shown_coins = float(GameState.coins)
	_layout()
	_set_state("idle")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	var away := Fishing.take_offline_catch()
	if away > 0:
		_say(tr("FISHING_OFFLINE") % away, Art.GOLD, 3.5)


func _layer(painter: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter)
	add_child(c)
	return c


func _menu_button(id: String, variation: StringName, painter: Callable) -> void:
	var b := Button.new()
	b.name = id.capitalize()
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		open_panel(id))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 0)
	b.add_child(box)
	var art := ArtView.make(painter, Vector2(0, 58), true)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	add_child(b)
	_menu[id] = b
	_menu_labels[id] = l


## Optional: {"panel": "bucket" | "book" | "shop"} opens that panel at once.
func setup(opts: Dictionary = {}) -> void:
	var p := str(opts.get("panel", ""))
	if p != "":
		(func(): open_panel(p)).call_deferred()


# --- Layout -------------------------------------------------------------------------------

func _layout() -> void:
	var v := get_viewport_rect().size
	_wide = v.x > v.y * 1.05
	_k = clampf(minf(v.x, v.y * 0.75) / 720.0, 0.85, 1.5)
	for c: Control in [_bg, _scene, _hud, _fx]:
		c.position = Vector2.ZERO
		c.size = v
	var margin := 16.0
	_close.size = _close.custom_minimum_size
	_close.position = Vector2(v.x - _close.size.x - margin, margin + (TOP_H - _close.size.y) / 2.0)
	_pill = Rect2(margin, margin + 8.0, minf(340.0, v.x * 0.5), TOP_H - 16.0)
	var menu_w := 0.0
	if _wide:
		_horizon = v.y * 0.36
		_deck = Rect2(-20, v.y * 0.62, v.x * 0.36 + 20.0, 30.0)
		_player = Vector2(v.x * 0.15, _deck.position.y)
		_bucket_pos = Vector2(v.x * 0.24, _deck.position.y)
		_helper_pos = Vector2(v.x * 0.45, v.y * 0.8)
		_target = Vector2(v.x * 0.62, v.y * 0.54)
		var bw := 230.0
		var aw := 380.0
		var gap := 18.0
		var total := bw * 3.0 + aw + gap * 3.0
		var x := (v.x - total) / 2.0
		var y := v.y - BTN_H - 26.0
		_place(_menu["bucket"], Rect2(x, y, bw, BTN_H))
		_place(_menu["book"], Rect2(x + bw + gap, y, bw, BTN_H))
		_place(_action, Rect2(x + (bw + gap) * 2.0, y, aw, BTN_H))
		_place(_menu["shop"], Rect2(x + (bw + gap) * 2.0 + aw + gap, y, bw, BTN_H))
		menu_w = bw
	else:
		_horizon = v.y * 0.27
		_deck = Rect2(-20, v.y * 0.67, v.x * 0.58 + 20.0, 28.0)
		_player = Vector2(v.x * 0.16, _deck.position.y)
		_bucket_pos = Vector2(v.x * 0.33, _deck.position.y)
		_helper_pos = Vector2(v.x * 0.66, v.y * 0.785)
		_target = Vector2(v.x * 0.7, v.y * 0.5)
		var gap := 14.0
		var bw := floorf((v.x - margin * 2.0 - gap * 2.0) / 3.0)
		var y := v.y - BTN_H - 24.0
		for i in 3:
			_place(_menu[["bucket", "book", "shop"][i]], Rect2(margin + i * (bw + gap), y, bw, BTN_H))
		var aw := minf(460.0, v.x - 120.0)
		_place(_action, Rect2((v.x - aw) / 2.0, y - BTN_H - 22.0, aw, BTN_H + 6.0))
		menu_w = bw
	for id in _menu_labels:
		_menu_labels[id].add_theme_font_size_override("font_size", 22 if menu_w >= 200.0 else 19)
	var rw := minf(600.0, v.x - 70.0)
	_reel_rect = Rect2(clampf(_target.x - rw / 2.0, 35.0, v.x - rw - 35.0), _horizon - 40.0 if not _wide else _target.y - 320.0, rw, 84.0)
	_refresh_buttons()
	if _card_layer.get_child_count() > 0:
		_place_card()


func _place(c: Control, r: Rect2) -> void:
	c.custom_minimum_size = r.size
	c.position = r.position.round()
	c.size = r.size.round()
	c.pivot_offset = c.size / 2.0


func _refresh_buttons() -> void:
	if _menu.is_empty():
		return
	_menu_labels["bucket"].text = "%s %d/%d" % [tr("FISHING_BUCKET"), Fishing.bucket.size(), Fishing.capacity()]
	_menu_labels["book"].text = "%s %d/%d" % [tr("FISHING_BOOK"), Fishing.found(), FishData.SPECIES.size()]
	_menu_labels["shop"].text = tr("FISHING_SHOP")
	for id in _menu_labels:
		var l: Label = _menu_labels[id]
		var fs := 22 if _menu[id].size.x >= 200.0 else 19
		var font := UiTheme.heavy_font()
		while fs > 14 and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _menu[id].size.x - 20.0:
			fs -= 1
		l.add_theme_font_size_override("font_size", fs)
	_update_action()


func _update_action() -> void:
	if _action == null:
		return
	var text := ""
	var style := &"GoldButton"
	match _state:
		"idle", "away":
			text = tr("FISHING_CAST")
		"cast", "wait":
			text = tr("FISHING_WAIT")
			style = &"DarkButton"
		"bite":
			text = tr("FISHING_PULL")
			style = &"RedButton"
		"reel":
			text = tr("FISHING_REEL")
			style = &"Button"
		_:
			text = tr("FISHING_WAIT")
			style = &"DarkButton"
	_action.text = text
	_action.theme_type_variation = style
	var fs := 42
	var font := UiTheme.heavy_font()
	while fs > 24 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _action.size.x - 40.0:
		fs -= 2
	_action.add_theme_font_size_override("font_size", fs)


# --- Input ----------------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_on_action()
		accept_event()
	elif _touch_input and e is InputEventScreenTouch and e.index == 0 and e.pressed:
		_on_action()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_ESCAPE:
			if _modal.visible:
				_modal.close()
			elif _card_layer.get_child_count() > 0:
				_card_choice("keep" if not Fishing.is_full() else "sell")
			else:
				close()
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER:
			if not _modal.visible and _card_layer.get_child_count() == 0:
				_on_action()
				get_viewport().set_input_as_handled()


## The one big action: cast, pull, reel (a tap anywhere does the same).
func _on_action() -> void:
	if _done or _modal.visible or _card_layer.get_child_count() > 0:
		return
	# Two taps in the same instant (button + screen) count once.
	if _t - _last_tap < 0.08:
		return
	_last_tap = _t
	match _state:
		"idle", "away":
			_cast()
		"cast", "wait":
			_say(tr("FISHING_TOO_EARLY"), Color("bff3ff"), 1.3)
			Sfx.play("tap", 0.8)
		"bite":
			_start_reel()
		"reel":
			_reel_tap()


# --- States ---------------------------------------------------------------------------------

func _set_state(s: String) -> void:
	_state = s
	_st = 0.0
	_update_action()
	match s:
		"idle":
			_say(tr("FISHING_TAP_CAST"), Art.WHITE, 99.0)
			if Fishing.is_full():
				_say(tr("FISHING_BUCKET_FULL"), Color("ffd0d0"), 99.0)


func _cast() -> void:
	_fish = Fishing.roll_fish()
	_wait_len = _rng.randf_range(FishData.WAIT_SEC.x, FishData.WAIT_SEC.y)
	_line_pull = 0.0
	_set_state("cast")
	_say("", Art.WHITE, 0.0)
	Sfx.play("tap", 0.7)
	Settings.buzz(15)


func _start_reel() -> void:
	var r := FishData.rarity_of(str(_fish["id"]))
	_hits = 0
	_misses = 0
	_marker = 0.0
	_dir = 1.0
	_speed = FishData.reel_speed(r, Fishing.rod)
	_zone_w = FishData.reel_zone(r, Fishing.rod)
	_new_zone()
	_set_state("reel")
	_say(tr("FISHING_HINT_REEL"), Color("b6f36a"), 99.0)
	Sfx.play("upgrade", 0.9)
	Settings.buzz(30)
	_splash(_line_end(), 10, 1.2)


func _new_zone() -> void:
	# Away from the marker so the next hit needs a moment of waiting.
	for i in 8:
		_zone = _rng.randf_range(_zone_w / 2.0 + 0.03, 1.0 - _zone_w / 2.0 - 0.03)
		if absf(_zone - _marker) > 0.25:
			break


func _reel_tap() -> void:
	var inside := absf(_marker - _zone) <= _zone_w / 2.0 + FishData.REEL_MARGIN
	var p := _reel_rect.position + Vector2(_reel_rect.size.x * _marker, _reel_rect.size.y / 2.0)
	if inside:
		_hits += 1
		_jerk = 1.0
		_line_pull = float(_hits) / FishData.REEL_HITS
		_float_text(tr("FISHING_HIT"), p + Vector2(0, -70), Color("b6f36a"), 46)
		_sparkle(p, 8)
		_splash(_line_end(), 12, 1.3)
		Sfx.play("pop", 1.0 + 0.15 * _hits)
		Settings.buzz(25)
		if _hits >= FishData.REEL_HITS:
			_land()
		else:
			_new_zone()
	else:
		_misses += 1
		_shake = 1.0
		_float_text(tr("FISHING_MISS"), p + Vector2(0, -70), Color("ffb0b0"), 42)
		Sfx.play("deny", 1.1)
		if _misses >= FishData.REEL_MISSES:
			_escape(tr("FISHING_ESCAPED"))
		else:
			_zone_w = FishData.reel_zone(FishData.rarity_of(str(_fish["id"])), Fishing.rod, _misses)


func _land() -> void:
	_land_from = _line_end()
	_card_info = Fishing.record(_fish)
	_visit["caught"] = int(_visit["caught"]) + 1
	_set_state("land")
	_say("", Art.WHITE, 0.0)
	_splash(_land_from, 22, 1.8)
	Sfx.play("chest")
	var r := FishData.rarity_of(str(_fish["id"]))
	if r >= FishData.EPIC:
		Sfx.voice("woohoo")
	else:
		Sfx.voice("wow" if r >= FishData.RARE else "yay", 1.1)


func _escape(msg: String) -> void:
	Fishing.note_escaped()
	_splash(_line_end(), 8, 0.9)
	_set_state("away")
	_say(msg, Color("bff3ff"), AWAY_SEC + 0.6)
	Sfx.voice("hmm")


# --- Per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_st += delta
	match _state:
		"cast":
			if _st >= CAST_SEC:
				_splash(_target, 8, 0.8)
				_ring(_target, 0.8)
				Sfx.play("dive", 1.2)
				_set_state("wait")
		"wait":
			if fposmod(_st, 1.1) < delta:
				_ring(_target, 0.5)
			if _st >= _wait_len:
				_set_state("bite")
				var r := FishData.rarity_of(str(_fish["id"]))
				_say(tr("FISHING_BITE"), FishData.rarity_color(r).lightened(0.3), FishData.BITE_WINDOW)
				_splash(_target, 10 + r * 3, 1.0)
				_ring(_target, 1.0)
				Sfx.play("pop", 0.8)
				Sfx.play("dive", 1.5)
				Settings.buzz(40)
		"bite":
			if fposmod(_st, 0.35) < delta:
				_ring(_target, 0.6)
			if _st >= FishData.BITE_WINDOW:
				_escape(tr("FISHING_TOO_SLOW"))
		"reel":
			_marker += _dir * _speed * delta
			if _marker >= 1.0:
				_marker = 1.0
				_dir = -1.0
			elif _marker <= 0.0:
				_marker = 0.0
				_dir = 1.0
			if fposmod(_st, 0.25) < delta:
				_splash(_line_end(), 3, 0.6)
		"land":
			if _st >= LAND_SEC:
				_show_card()
		"away":
			if _st >= AWAY_SEC:
				_set_state("idle")
	_jerk = maxf(0.0, _jerk - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_helper_jerk = maxf(0.0, _helper_jerk - delta * 2.0)
	_coin_bump = maxf(0.0, _coin_bump - delta * 3.0)
	_bucket_bump = maxf(0.0, _bucket_bump - delta * 3.0)
	_hint_t -= delta
	_shown_coins = lerpf(_shown_coins, float(GameState.coins), minf(1.0, delta * 8.0))
	if absf(_shown_coins - float(GameState.coins)) < 1.0:
		_shown_coins = float(GameState.coins)
	_update_fx(delta)
	_scene.queue_redraw()
	_hud.queue_redraw()
	_acc += delta
	if _acc >= (1.0 / 20.0 if Art.low_power else 1.0 / 30.0):
		_acc = 0.0
		_bg.queue_redraw()
	_action.scale = Vector2.ONE * (1.0 + (0.05 * absf(sin(_t * 8.0)) if _state == "bite" else (0.025 * sin(_t * 3.0) if _state in ["idle", "away"] else 0.0)))


func _say(text: String, col: Color, sec: float) -> void:
	_hint = text
	_hint_col = col
	_hint_t = sec


## Where the line ends: the float, pulled closer while reeling.
func _line_end() -> Vector2:
	var near := Vector2(_deck.end.x + 50.0 * _k, _deck.position.y + 40.0 * _k)
	var p := _target.lerp(near, _line_pull * 0.55)
	if _state == "reel":
		p += Vector2(sin(_t * 9.0) * 10.0, cos(_t * 7.0) * 4.0) * _k
	return p


# --- Effects -------------------------------------------------------------------------------

func _splash(at: Vector2, n: int, power: float) -> void:
	if Settings.reduce_motion:
		n = maxi(1, n / 3)
	for i in n:
		var a := -PI / 2.0 + _rng.randf_range(-0.9, 0.9)
		var sp := _rng.randf_range(180.0, 420.0) * power * _k
		_drops.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "age": 0.0, "life": _rng.randf_range(0.45, 0.8), "s": _rng.randf_range(4.0, 8.0) * _k})
	_ring(at, power)


func _ring(at: Vector2, power: float) -> void:
	_rings.append({"p": at, "age": 0.0, "life": 0.9, "r": 50.0 * power * _k})


func _sparkle(at: Vector2, n: int, col: Color = Color(1.0, 0.96, 0.6)) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		_stars.append({"p": at, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(90.0, 300.0), "age": 0.0, "life": _rng.randf_range(0.5, 0.8), "c": col, "s": _rng.randf_range(0.8, 1.4)})


func _float_text(s: String, at: Vector2, col: Color, size_px: int) -> void:
	_texts.append({"s": s, "p": at, "c": col, "size": size_px, "age": 0.0, "life": 1.0})


## Coins (kind "coin") or a fish (kind "fish", id) flying across the screen.
func _fly(kind: String, from: Vector2, to: Vector2, n: int, id: String = "") -> void:
	for i in n:
		_flyers.append({"kind": kind, "id": id, "from": from + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 30)) * (0.0 if kind == "fish" else 1.0),
				"to": to, "age": -0.05 * i, "life": 0.7 if kind == "coin" else 0.6, "bend": _rng.randf_range(-120, 120)})


func _update_fx(delta: float) -> void:
	for d in _drops:
		d["age"] += delta
		d["v"].y += 1100.0 * delta
		d["p"] += d["v"] * delta
	_drops = _drops.filter(func(d): return d["age"] < d["life"])
	for s in _stars:
		s["age"] += delta
		s["v"] *= 0.94
		s["p"] += s["v"] * delta
	_stars = _stars.filter(func(s): return s["age"] < s["life"])
	for arr: Array in [_rings, _texts]:
		for x in arr:
			x["age"] += delta
	_rings = _rings.filter(func(r): return r["age"] < r["life"])
	_texts = _texts.filter(func(x): return x["age"] < x["life"])
	for f in _flyers:
		f["age"] += delta
		if f["age"] >= f["life"] and not f.has("done"):
			f["done"] = true
			if f["kind"] == "coin":
				_coin_bump = 1.0
				Sfx.play("coins", 1.2)
			else:
				_bucket_bump = 1.0
				Sfx.play("pop", 1.2)
	_flyers = _flyers.filter(func(f): return not f.has("done"))
	_fx.queue_redraw()


# --- The catch card -------------------------------------------------------------------------

func _show_card() -> void:
	_set_state("card")
	var fish := _fish
	var id := str(fish["id"])
	var r := FishData.rarity_of(id)
	var col := FishData.rarity_color(r)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.18, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var rarity := Label.new()
	rarity.text = tr(FishData.rarity_key(r))
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_font_override("font", UiTheme.heavy_font())
	rarity.add_theme_font_size_override("font_size", 40 if r < FishData.LEGENDARY else 48)
	rarity.add_theme_color_override("font_color", col.lightened(0.15))
	rarity.add_theme_constant_override("outline_size", 10)
	box.add_child(rarity)
	var is_new: bool = _card_info.get("new", false)
	var is_record: bool = _card_info.get("record", false)
	var art := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := Vector2(s.x / 2.0, s.y / 2.0 + 6.0)
		FishArt.glow(ci, c, 130.0, r, tt)
		var pop := minf(1.0, tt / 0.35)
		var sc := (sin(pop * PI * 0.5) + sin(pop * PI) * 0.25) * (2.6 + 0.4 * FishData.size_share(id, float(fish["size"])))
		Art.push(ci, c, sin(tt * 1.4) * 0.05, Vector2.ONE * maxf(0.05, sc))
		FishArt.draw(ci, id, tt, 1.0, true)
		Art.pop(ci)
		if r >= FishData.RARE:
			FishArt.sparkles(ci, c, 150.0, tt, 4 + r * 2)
		if is_new or is_record:
			Art.push(ci, Vector2(s.x - 70.0, 34.0), 0.18 + sin(tt * 3.0) * 0.05, Vector2.ONE * (1.0 + 0.06 * sin(tt * 6.0)))
			var label := tr("FISHING_NEW") if is_new else tr("FISHING_RECORD")
			var w := UiTheme.heavy_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 30.0
			Art.t_rect(ci, Rect2(-w / 2.0, -24, w, 48), 24, Art.RED if is_new else Art.GREEN, 3.0, 0.4)
			Art.text(ci, Vector2(0, 10), label, 28, Art.WHITE, 7)
			Art.pop(ci), Vector2(0, 280), true)
	box.add_child(art)
	var nm := Label.new()
	nm.theme_type_variation = &"InkLabel"
	nm.text = tr(FishData.name_key(id))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_override("font", UiTheme.heavy_font())
	nm.add_theme_font_size_override("font_size", 44)
	box.add_child(nm)
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 26)
	var size_l := Views.label(tr("FISHING_CM") % _cm(float(fish["size"])), 30, Art.INK_SOFT, true)
	size_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(size_l)
	info.add_child(Views.chip("coin", NumFormat.short(float(fish["value"])), 32))
	box.add_child(info)
	if Fishing.is_full():
		var full := Views.label(tr("FISHING_BUCKET_FULL"), 26, Color("d8363c"), true)
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(full)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	if Fishing.is_full():
		_card_button(row, tr("FISHING_RELEASE"), &"CreamButton", "release")
		_card_button(row, tr("FISHING_SELL"), &"GoldButton", "sell", true)
	else:
		_card_button(row, tr("FISHING_SELL"), &"GoldButton", "sell", true)
		_card_button(row, tr("FISHING_KEEP"), &"Button", "keep")
	_card_layer.add_child(panel)
	_place_card()
	# Wrapped labels know their height only once they have a width.
	(func():
		await get_tree().process_frame
		_place_card()).call()
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	var v := get_viewport_rect().size
	_sparkle(v / 2.0, 10 + r * 6, col.lightened(0.4))
	if r >= FishData.EPIC:
		_sparkle(v / 2.0 + Vector2(-160, -120), 12)
		_sparkle(v / 2.0 + Vector2(160, -120), 12)
		Sfx.play("milestone")
	if r == FishData.LEGENDARY:
		for i in 3:
			get_tree().create_timer(0.2 + i * 0.25).timeout.connect(func():
				if is_inside_tree():
					_sparkle(v / 2.0 + Vector2(_rng.randf_range(-250, 250), _rng.randf_range(-300, 100)), 16, [Art.GOLD, Color("ff9fd0"), Color("7be0ff")][i]))
		Sfx.play("prestige", 1.2)


func _card_button(row: HBoxContainer, text: String, style: StringName, choice: String, with_coin: bool = false) -> void:
	var b := Button.new()
	b.name = choice.capitalize()
	b.text = text
	b.theme_type_variation = style
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 30)
	if with_coin:
		b.icon = Icons.get_icon("coin", 40)
	b.pressed.connect(func(): _card_choice(choice))
	row.add_child(b)


func _place_card() -> void:
	var panel := _card_layer.get_node_or_null("Card") as PanelContainer
	if panel == null:
		return
	var v := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(560.0, v.x - 40.0), 0)
	panel.size = Vector2.ZERO
	panel.reset_size()
	panel.position = ((v - panel.size) / 2.0).round()
	panel.pivot_offset = panel.size / 2.0


func _card_choice(choice: String) -> void:
	if _state != "card":
		return
	var panel := _card_layer.get_node_or_null("Card") as Control
	var from := panel.get_global_rect().get_center() if panel else get_viewport_rect().size / 2.0
	match choice:
		"keep":
			if Fishing.keep(_fish):
				_fly("fish", from, _menu["bucket"].get_global_rect().get_center(), 1, str(_fish["id"]))
				Sfx.play("click")
		"sell":
			var coins := Fishing.sell_fish(_fish)
			_paid(coins, from)
		"release":
			_splash(_target, 10, 1.0)
			Sfx.play("dive")
	for c in _card_layer.get_children():
		_card_layer.remove_child(c)
		c.queue_free()
	_fish = {}
	_line_pull = 0.0
	_set_state("idle")
	_refresh_buttons()


func _paid(coins: float, from: Vector2) -> void:
	if coins <= 0.0:
		return
	_visit["coins"] = float(_visit["coins"]) + coins
	_visit["sold"] = int(_visit["sold"]) + 1
	_fly("coin", from, _pill.position + Vector2(40, _pill.size.y / 2.0), clampi(int(3 + log(coins) / log(10.0)), 4, 12))
	_float_text("+" + NumFormat.short(coins), from + Vector2(0, -50), Art.GOLD, 48)
	Sfx.play("coins")
	Sfx.voice("yay", 1.1)
	Settings.buzz(30)
	sold.emit(coins, from)


func _cm(v: float) -> String:
	return ("%.1f" % v) if v < 100.0 else str(roundi(v))


# --- The fisherman -------------------------------------------------------------------------

func _on_helper_caught(fish: Dictionary) -> void:
	if not is_inside_tree():
		return
	_helper_jerk = 1.0
	var water := _helper_float if _helper_float != Vector2.ZERO else _helper_pos
	_splash(water, 6, 0.8)
	_fly("fish", water, _bucket_pos + Vector2(0, -50.0 * _k), 1, str(fish["id"]))
	_float_text(tr("FISHING_HELPER_GOT"), _helper_pos + Vector2(0, -210.0 * _k), Color("b6f36a"), 30)
	_refresh_buttons()


func _any_affordable() -> bool:
	for kind in Fishing.UPGRADES:
		if Fishing.can_buy(kind):
			return true
	return false


# --- Panels ----------------------------------------------------------------------------------

## Opens "bucket", "book" or "shop".
func open_panel(id: String) -> void:
	if _card_layer.get_child_count() > 0:
		return
	match id:
		"bucket":
			_modal.open(_build_bucket, {"wide": _wide})
		"book":
			_modal.open(_build_book, {"wide": true})
		"shop":
			_modal.open(_build_shop)


func _grid_cols(min_w: float) -> int:
	var v := get_viewport_rect().size
	var w := minf(Modal.WIDE_WIDTH if _wide else Modal.WIDTH, v.x - 32.0) - 60.0
	return maxi(2, int(w / min_w))


func _build_bucket(m: Modal) -> void:
	m.title("%s  %d/%d" % [tr("FISHING_BUCKET"), Fishing.bucket.size(), Fishing.capacity()])
	if Fishing.bucket.is_empty():
		m.add(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			Art.push(ci, Vector2(s.x / 2.0, s.y - 10.0), 0.0, Vector2.ONE * 2.0)
			FishArt.bucket(ci, 0, tt)
			Art.pop(ci), Vector2(0, 140), true))
		m.text(tr("FISHING_BUCKET_EMPTY"), 26)
		m.button(tr("FISHING_CAST"), func(): Sfx.play("click"); m.close(), &"GoldButton")
		return
	var all := m.button("%s  %s" % [tr("FISHING_SELL_ALL"), NumFormat.short(Fishing.bucket_value())], func():
		var from := get_viewport_rect().size / 2.0
		var coins := Fishing.sell_all()
		Sfx.play("coins")
		m.close()
		_paid(coins, from), &"GoldButton")
	all.name = "SellAll"
	all.icon = Icons.get_icon("coin", 44)
	all.custom_minimum_size.y = 92
	all.add_theme_font_size_override("font_size", 32)
	var grid := GridContainer.new()
	grid.columns = _grid_cols(150.0)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var n := Fishing.bucket.size()
	for k in n:
		var i := n - 1 - k
		var f: Dictionary = Fishing.bucket[i]
		var id := str(f["id"])
		var r := FishData.rarity_of(id)
		var c := Views.card(Color("fffaf0"))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		c.add_child(v)
		v.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			var ctr := s / 2.0
			Art.flat(ci, Art.rrect_pts(Rect2(Vector2.ZERO, s), 14.0), Color(FishData.rarity_color(r), 0.22))
			Art.push(ci, ctr, 0.0, Vector2.ONE * minf(s.x / 125.0, s.y / 80.0))
			FishArt.draw(ci, id, tt + i)
			Art.pop(ci), Vector2(0, 86), true))
		var nl := Views.label(tr(FishData.name_key(id)), 18, Art.INK, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(nl)
		var sl := Views.label(tr("FISHING_CM") % _cm(float(f["size"])), 16, Art.INK_SOFT)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
		var sell := Button.new()
		sell.theme_type_variation = &"GoldButton"
		sell.text = NumFormat.short(float(f["value"]))
		sell.icon = Icons.get_icon("coin", 30)
		sell.custom_minimum_size = Vector2(0, 62)
		sell.focus_mode = Control.FOCUS_NONE
		sell.add_theme_font_size_override("font_size", 24)
		sell.pressed.connect(func():
			var from := sell.get_global_rect().get_center()
			if i < Fishing.bucket.size():
				_paid(Fishing.sell_at(i), from)
				m.rebuild())
		v.add_child(sell)
		grid.add_child(c)
	m.add(grid)


func _build_book(m: Modal) -> void:
	m.title(tr("FISHING_BOOK"))
	var total := FishData.SPECIES.size()
	m.add(Views.bar(Fishing.found(), total, tr("FISHING_FOUND") % [Fishing.found(), total]))
	if Fishing.found() < total:
		m.text(tr("FISHING_BOOK_HINT"), 21, Art.INK_SOFT)
	for r in 5:
		var head := Views.label(tr(FishData.rarity_key(r)).trim_suffix("!").trim_suffix("！").trim_prefix("¡"), 26, FishData.rarity_color(r).darkened(0.25), true)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add(head)
		var grid := GridContainer.new()
		grid.columns = _grid_cols(185.0) if _wide else 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for id in FishData.of_rarity(r):
			var known := Fishing.has_found(id)
			var c := Views.card(Color("fff6dc") if known else Color("e9ecf4"))
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 2)
			c.add_child(v)
			v.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
				var ctr := s / 2.0
				if known:
					FishArt.glow(ci, ctr, s.y * 0.55, r, tt)
				Art.push(ci, ctr, 0.0, Vector2.ONE * minf(s.x / 120.0, s.y / 84.0))
				FishArt.draw(ci, id, tt + r, 1.0, false, not known)
				Art.pop(ci)
				if not known:
					Art.text(ci, ctr + Vector2(0, 14), "?", 40, Art.WHITE, 8), Vector2(0, 92), known))
			var nl := Views.label(tr(FishData.name_key(id)) if known else "???", 18, Art.INK, true)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nl)
			if known:
				var st := Views.label(tr("FISHING_CAUGHT_N") % Fishing.count_of(id), 16, Art.INK_SOFT)
				st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(st)
				var best := Views.label(tr("FISHING_BEST") % (tr("FISHING_CM") % _cm(Fishing.best_of(id))), 16, Color("1f8a4c"))
				best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(best)
			grid.add_child(c)
		m.add(grid)


func _build_shop(m: Modal) -> void:
	m.title(tr("FISHING_SHOP"))
	m.add(Views.chip("coin", NumFormat.short(GameState.coins), 30))
	for kind in Fishing.UPGRADES:
		var lv: int = Fishing.level(kind)
		var c := Views.card(Color("fffaf0"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		c.add_child(h)
		h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			var ctr := s / 2.0
			Art.t_circle(ci, ctr, 48.0, Color("cfeaff"), 3.0, 0.0)
			match kind:
				"rod":
					Art.push(ci, ctr, 0.0, Vector2.ONE * 1.2)
					FishArt.rod_icon(ci, tt)
				"bucket":
					Art.push(ci, ctr + Vector2(0, 32), 0.0, Vector2.ONE * 1.1)
					FishArt.bucket(ci, 2 + lv, tt)
				_:
					Art.push(ci, ctr + Vector2(0, 42), 0.0, Vector2.ONE * 0.8)
					Chars.person(ci, Vector2.ZERO, 1.0, 1.0, _helper_look(), {"emotion": "happy" if lv > 0 else "sleepy", "blink": Chars.blinking(tt, 3.0), "arm_r": 0.6})
			Art.pop(ci), Vector2(110, 110), true))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		h.add_child(v)
		var title_key: String = {"rod": "FISHING_ROD", "bucket": "FISHING_BUCKET_UP", "helper": "FISHING_HELPER"}[kind]
		v.add_child(Views.label(tr(title_key), 26, Art.INK, true))
		if lv > 0 or kind != "helper":
			var ll := Views.label(tr("FISHING_LEVEL") % (lv + (1 if kind != "helper" else 0)), 18, Color("1c7fb8"), true)
			v.add_child(ll)
		var desc := ""
		match kind:
			"rod":
				desc = tr("FISHING_ROD_DESC")
			"bucket":
				desc = tr("FISHING_BUCKET_DESC") % Fishing.capacity()
			_:
				desc = tr("FISHING_HELPER_HIRE_DESC") if lv == 0 else tr("FISHING_HELPER_DESC") % roundi(Fishing.helper_interval())
		v.add_child(Views.label(desc, 18, Art.INK_SOFT))
		var b := Button.new()
		b.name = "Buy" + kind.capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 70)
		b.add_theme_font_size_override("font_size", 24)
		if Fishing.is_maxed(kind):
			b.text = tr("FISHING_MAX")
			b.disabled = true
		else:
			var verb := tr("FISHING_HIRE") if kind == "helper" and lv == 0 else tr("FISHING_BUY")
			b.text = "%s  %s" % [verb, NumFormat.short(Fishing.upgrade_cost(kind))]
			b.icon = Icons.get_icon("coin", 32)
			b.theme_type_variation = &"GoldButton"
			b.disabled = not Fishing.can_buy(kind)
			b.pressed.connect(func():
				if Fishing.buy(kind):
					Sfx.play("hire" if kind == "helper" and Fishing.helper == 1 else "upgrade")
					_sparkle(b.get_global_rect().get_center(), 10)
					m.rebuild()
				else:
					Sfx.play("deny"))
		v.add_child(b)
		m.add(c)


static func _helper_look() -> Dictionary:
	return Chars.look(2, "short", 4, "beanie", "beard", 3, "overalls")


# --- Leaving -----------------------------------------------------------------------------------

func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	if _modal.visible:
		_modal.close()
	# A fish on the card still goes to the bucket (or gets sold) on the way out.
	if _state == "card" and not _fish.is_empty():
		if not Fishing.keep(_fish):
			_paid(Fishing.sell_fish(_fish), get_viewport_rect().size / 2.0)
	Fishing.save_game()
	finished.emit(_visit.duplicate())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## For screenshots and tests: jump to a moment ("wait", "bite", "reel",
## "escaped", "catch:<fish id>").
func debug_state(s: String) -> void:
	_fish = Fishing.roll_fish()
	match s:
		"wait":
			_set_state("wait")
			_wait_len = 99.0
		"bite":
			_set_state("wait")
			_wait_len = 0.0
		"reel":
			_start_reel()
			_hits = 1
			_line_pull = 1.0 / FishData.REEL_HITS
			_marker = clampf(_zone - _zone_w * 0.9, 0.05, 0.95)
			_speed = 0.0
		"escaped":
			_escape(tr("FISHING_ESCAPED"))
		_:
			if s.begins_with("catch:"):
				var id := s.substr(6)
				_fish = {"id": id, "size": FishData.size_from_roll(id, 0.8), "value": FishData.price(id, FishData.size_from_roll(id, 0.8), Fishing.base_rate())}
				_card_info = Fishing.record(_fish)
				_show_card()


func state() -> String:
	return _state


# --- Drawing: the world ------------------------------------------------------------------------

func _draw_bg() -> void:
	var ci := _bg
	var v := ci.size
	var hz := _horizon
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(v.x, 0), Vector2(v.x, hz), Vector2(0, hz)]),
			PackedColorArray([Art.SKY_TOP, Art.SKY_TOP, Art.SKY_BOTTOM, Art.SKY_BOTTOM]))
	Art.push(ci, Vector2(v.x * 0.82, hz * 0.42), 0.0, Vector2.ONE * _k)
	Props.sun(ci, _t)
	Art.pop(ci)
	for c in _clouds:
		var x := fposmod(c.x + _t * 0.006 * c.z, 1.2) * (v.x + 200.0) - 150.0
		Art.push(ci, Vector2(x, hz * c.y), 0.0, Vector2.ONE * c.z * _k)
		Props.cloud(ci, int(c.z * 100.0))
		Art.pop(ci)
	Art.push(ci, Vector2(v.x * 0.3, hz + 2.0), 0.0, Vector2(1.6, 1.3) * _k)
	Props.far_island(ci, 260.0, Color("7fb0d8"))
	Art.pop(ci)
	Art.push(ci, Vector2(v.x * 0.72, hz + 2.0), 0.0, Vector2(1.0, 0.8) * _k)
	Props.far_island(ci, 200.0, Color("8fc0e4"))
	Art.pop(ci)
	# Sea.
	var mid := lerpf(hz, v.y, 0.45)
	Art.grad(ci, PackedVector2Array([Vector2(0, hz), Vector2(v.x, hz), Vector2(v.x, mid), Vector2(0, mid)]),
			PackedColorArray([Art.SEA_TOP, Art.SEA_TOP, Art.SEA_MID, Art.SEA_MID]))
	Art.grad(ci, PackedVector2Array([Vector2(0, mid), Vector2(v.x, mid), v, Vector2(0, v.y)]),
			PackedColorArray([Art.SEA_MID, Art.SEA_MID, Art.SEA_DEEP, Art.SEA_DEEP]))
	Art.flat(ci, PackedVector2Array([Vector2(0, hz - 2), Vector2(v.x, hz - 2), Vector2(v.x, hz + 4), Vector2(0, hz + 4)]), Color(1, 1, 1, 0.5))
	# Sun glitter on the water.
	for i in 14:
		var gx := v.x * 0.82 + sin(i * 2.3) * 70.0 * (1.0 + i * 0.08)
		var gy := hz + 14.0 + i * 16.0
		var a := 0.25 + 0.25 * sin(_t * 3.0 + i * 1.7)
		Art.flat(ci, PackedVector2Array([Vector2(gx - 16, gy), Vector2(gx, gy - 2.5), Vector2(gx + 16, gy), Vector2(gx, gy + 2.5)]), Color(1, 1, 0.9, snappedf(a, 0.05)))
	# Gentle wave lines.
	for row in 7:
		var y := lerpf(hz + 30.0, v.y - 40.0, row / 6.0)
		var amp := (4.0 + row * 1.2) * _k
		var len := (60.0 + row * 14.0) * _k
		for j in 5:
			var x0 := fposmod(j * v.x / 4.0 + row * 97.0 + _t * (12.0 + row * 3.0), v.x + len * 2.0) - len
			var pts := PackedVector2Array()
			for s in 7:
				var f := s / 6.0
				pts.append(Vector2(x0 + f * len, y - sin(f * PI) * amp))
			Art.polyline(ci, pts, Color(1, 1, 1, 0.18 + 0.03 * (6 - row)), 3.0)
	# Fish shadows passing by.
	for sh in _shadows:
		var dir := 1.0 if sh.x < 0.5 else -1.0
		var f := fposmod(sh.x * 7.0 + _t * 0.025 * sh.z, 1.0)
		var x := lerpf(-80.0, v.x + 80.0, f) if dir > 0.0 else lerpf(v.x + 80.0, -80.0, f)
		var y := lerpf(hz + 80.0, v.y - 160.0, sh.y) + sin(_t + sh.x * 10.0) * 8.0
		_shadow(ci, Vector2(x, y), 34.0 * sh.z * _k, dir, 0.16)
	_draw_pier(ci, v)


func _shadow(ci: CanvasItem, p: Vector2, len: float, dir: float, alpha: float) -> void:
	Art.push(ci, p, 0.0, Vector2(dir, 1.0) * (len / 30.0))
	var col := Color(0.03, 0.12, 0.3, alpha)
	Art.flat(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(30, 11), 18), col)
	Art.push(ci, Vector2(-28, 0), sin(_t * 6.0 + p.y) * 0.25)
	Art.flat(ci, PackedVector2Array([Vector2(2, 0), Vector2(-14, -10), Vector2(-14, 10)]), col)
	Art.pop(ci)
	Art.pop(ci)


func _draw_pier(ci: CanvasItem, v: Vector2) -> void:
	var d := _deck
	var post_h := minf(170.0 * _k, v.y - d.position.y)
	var n := maxi(3, int(d.size.x / (120.0 * _k)))
	for i in n:
		var x := d.position.x + 40.0 + (d.size.x - 70.0) * i / float(n - 1)
		var r := Rect2(x - 12.0 * _k, d.position.y + 10.0, 24.0 * _k, post_h)
		Art.t_rect(ci, r, 6.0, Art.WOOD_DARK, 3.0, 0.3)
		var wy := d.position.y + post_h * 0.55
		Art.push(ci, Vector2(x, wy), 0.0, Vector2(1.0, 0.3))
		Art.arc(ci, Vector2.ZERO, (26.0 + 5.0 * sin(_t * 2.0 + i)) * _k, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 4.0)
		Art.pop(ci)
		Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, wy - 4.0, r.size.x, r.end.y - wy + 4.0), 4.0), Color(Art.SEA_MID, 0.45))
	# Deck: planks with a front face.
	var face := Rect2(d.position.x, d.position.y, d.size.x, d.size.y + 12.0 * _k)
	Art.t_rect(ci, face, 8.0, Art.WOOD_DARK, 3.5, 0.0)
	Art.t_rect(ci, Rect2(d.position.x, d.position.y - 14.0 * _k, d.size.x, d.size.y), 8.0, Art.WOOD, 3.5, 0.5)
	var plank := 46.0 * _k
	var x := d.position.x + plank
	while x < d.end.x - 10.0:
		Art.line(ci, Vector2(x, d.position.y - 12.0 * _k), Vector2(x, d.position.y + d.size.y - 16.0 * _k), Art.WOOD_DARK, 2.0)
		x += plank
	for i in int(d.size.x / (plank * 2.0)):
		Art.flat(ci, Art.circle_pts(Vector2(d.position.x + plank * (2.0 * i + 1.5), d.position.y + d.size.y * 0.5 + 2.0), 2.5 * _k, 8), Art.INK_SOFT)


func _draw_scene() -> void:
	var ci := _scene
	var s := _ps()
	var sh := Vector2(sin(_t * 60.0), cos(_t * 47.0)) * _shake * 5.0 if not Settings.reduce_motion else Vector2.ZERO
	# Water around the float.
	for r in _rings:
		var f: float = r["age"] / r["life"]
		Art.push(ci, r["p"], 0.0, Vector2(1.0, 0.32))
		Art.arc(ci, Vector2.ZERO, lerpf(10.0, r["r"], f), 0.0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - f)), 4.0 * (1.0 - f * 0.5))
		Art.pop(ci)
	# The fish coming to the float.
	if _state in ["wait", "bite", "reel"] and not _fish.is_empty():
		var r := FishData.rarity_of(str(_fish["id"]))
		var len := (26.0 + r * 5.0) * _k
		var alpha := 0.28
		var p := _line_end() + Vector2(0, 34.0 * _k)
		if _state == "wait":
			var f := clampf(_st / maxf(0.1, _wait_len), 0.0, 1.0)
			p += Vector2((1.0 - f) * 260.0 * _k, 60.0 * (1.0 - f) * _k)
			alpha *= f
		_shadow(ci, p, len, -1.0, alpha)
	# Fisherman helper.
	if Fishing.helper > 0:
		_draw_helper(ci, s * 0.85)
	# Bucket on the pier.
	Art.push(ci, _bucket_pos + Vector2(0, -12.0 * _k), 0.0, Vector2.ONE * _k * 1.05 * (1.0 + _bucket_bump * 0.15))
	FishArt.bucket(ci, Fishing.bucket.size(), _t, Fishing.is_full())
	Art.pop(ci)
	# The player with the rod.
	var pose := _player_pose()
	var feet := _player + Vector2(0, -12.0 * _k)
	Chars.person(ci, feet, s, 1.0, Settings.avatar, pose)
	var hand := _hand(feet, s, float(pose["arm_r"]))
	var ang := _rod_angle()
	var rod_len := 110.0 * s
	var bend := 0.0
	if _state == "reel" or _state == "bite":
		bend = (0.18 + 0.12 * sin(_t * 14.0) + _jerk * 0.2) * rod_len
	var dirv := Vector2(cos(ang), sin(ang))
	var nrm := dirv.orthogonal()
	var rod := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		rod.append(hand - dirv * rod_len * 0.12 + dirv * rod_len * f * 1.12 - nrm * bend * f * f)
	var tip := rod[rod.size() - 1]
	# Line from the tip to the float (drawn before the rod so the rod is on top).
	var end := _float_pos() + sh
	var sag := 0.0
	match _state:
		"wait":
			sag = 60.0 * _k
		"idle", "away", "card":
			sag = 0.0
		"cast":
			sag = 20.0 * _k
	var line := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		line.append(tip.lerp(end, f) + Vector2(0, sin(f * PI) * sag))
	Art.polyline(ci, line, Color(Art.INK, 0.35), 4.0)
	Art.polyline(ci, line, Color(1, 1, 1, 0.9), 2.0)
	Art.stroke(ci, rod, Art.WOOD, 7.0 * _k, 2.5)
	Art.stroke(ci, PackedVector2Array([rod[0], rod[2]]), Color("3a3f5c"), 8.0 * _k, 2.5)
	Art.t_circle(ci, hand + dirv * rod_len * 0.05 + nrm * 10.0 * _k, 9.0 * _k, Art.METAL, 2.5, 0.4)
	# The float, or the fish splashing on the line.
	if _state == "land":
		var f := clampf(_st / LAND_SEC, 0.0, 1.0)
		var to := _player + Vector2(90.0, -260.0) * _k
		var p := _land_from.lerp(to, f)
		p.y -= sin(f * PI) * 200.0 * _k
		Art.push(ci, p, sin(f * TAU * 2.0) * 0.4 - 0.3, Vector2.ONE * s * (0.7 + 0.5 * f))
		FishArt.draw(ci, str(_fish["id"]), _t * 2.0, -1.0 if f < 0.5 else 1.0, true)
		Art.pop(ci)
	elif _state != "card":
		var bs := _k * 1.3
		FishArt.bobber(ci, end, bs)
		if _state == "bite" or _state == "reel":
			Art.push(ci, end + Vector2(0, 6.0 * _k), 0.0, Vector2(1.0, 0.3))
			Art.flat(ci, Art.circle_pts(Vector2.ZERO, 22.0 * _k, 20), Color(1, 1, 1, 0.5))
			Art.pop(ci)
	if _state == "bite":
		var r := FishData.rarity_of(str(_fish["id"]))
		var bang := "!" if r < FishData.RARE else ("!!" if r < FishData.LEGENDARY else "!!!")
		var pop := minf(1.0, _st / 0.2)
		var p := _target + Vector2(0, -110.0 * _k)
		Art.push(ci, p, sin(_t * 18.0) * 0.08, Vector2.ONE * _k * (0.5 + pop * 0.5 + 0.08 * sin(_t * 12.0)))
		Art.t_circle(ci, Vector2.ZERO, 44.0, FishData.rarity_color(r) if r >= FishData.RARE else Art.WHITE, 4.0, 0.4)
		Art.toon(ci, PackedVector2Array([Vector2(-12, 34), Vector2(12, 34), Vector2(0, 58)]), FishData.rarity_color(r) if r >= FishData.RARE else Art.WHITE, 4.0, 0.0)
		Art.text(ci, Vector2(0, 22), bang, 64, Art.RED if r < FishData.RARE else Art.WHITE, 8)
		Art.pop(ci)


func _draw_helper(ci: CanvasItem, s: float) -> void:
	# The fisherman fishes from a little rowboat that rocks on the waves.
	var bob := sin(_t * 1.6) * 4.0 * _k
	var base := _helper_pos + Vector2(0, bob)
	var rock := sin(_t * 1.2) * 0.04
	var full := Fishing.is_full()
	var pose := {"emotion": "sleepy" if full else ("joy" if _helper_jerk > 0.3 else "happy"), "blink": Chars.blinking(_t, 7.0),
			"arm_r": 1.05 + _helper_jerk * 0.5, "arm_l": 0.4}
	var feet := base + Vector2(-10.0, 6.0) * _k
	Chars.person(ci, feet, s, 1.0, _helper_look(), pose)
	var hand := _hand(feet, s, float(pose["arm_r"]))
	var ang := -0.7 - _helper_jerk * 0.5
	var dirv := Vector2(cos(ang), sin(ang))
	var tip := hand + dirv * 80.0 * s
	var water := Vector2(tip.x + 18.0 * _k, _helper_pos.y + 4.0 * _k + sin(_t * 2.0) * 3.0 * _k)
	_helper_float = water
	Art.polyline(ci, PackedVector2Array([tip, water]), Color(1, 1, 1, 0.85), 1.8)
	Art.stroke(ci, PackedVector2Array([hand - dirv * 12.0 * s, tip]), Art.WOOD, 5.0 * _k, 2.2)
	Art.push(ci, base, rock, Vector2.ONE * _k)
	var hull := Art.smooth_pts(PackedVector2Array([Vector2(-92, -34), Vector2(-40, -26), Vector2(40, -26), Vector2(96, -38), Vector2(70, 8), Vector2(-66, 8)]), 3)
	Art.toon(ci, hull, Color("e8744a"), 3.5, 0.6)
	Art.t_rect(ci, Rect2(-88, -36, 180, 11), 5.0, Art.WOOD, 3.0, 0.3)
	Art.flat(ci, Art.rrect_pts(Rect2(-60, -12, 118, 6), 3.0), Color(1, 1, 1, 0.35))
	Art.pop(ci)
	Art.push(ci, _helper_pos + Vector2(0, 8.0 * _k), 0.0, Vector2(1.0, 0.3))
	Art.arc(ci, Vector2.ZERO, (98.0 + 4.0 * sin(_t * 2.0)) * _k, 0.0, TAU, 28, Color(1, 1, 1, 0.4), 5.0)
	Art.pop(ci)
	FishArt.bobber(ci, water, _k * 0.8)
	# How long until his next fish: a little ring, or "Zzz" while the bucket is full.
	var p := feet + Vector2(-58.0, -150.0) * _k
	if full:
		for i in 3:
			var f := fposmod(_t * 0.5 + i / 3.0, 1.0)
			Art.text(ci, p + Vector2(f * 30.0 * _k, -f * 50.0 * _k), "z", int((24 + i * 6) * _k), Color(1, 1, 1, 1.0 - f), 6)
	else:
		Art.t_circle(ci, p, 18.0 * _k, Art.CREAM, 3.0, 0.0)
		var prog := Fishing.helper_progress()
		if prog > 0.01:
			Art.arc(ci, p, 11.0 * _k, -PI / 2.0, -PI / 2.0 + TAU * prog, 20, Art.GREEN, 6.0 * _k)


func _player_pose() -> Dictionary:
	var emo := "happy"
	var arm := 1.2
	match _state:
		"cast":
			var f := _st / CAST_SEC
			arm = 1.2 + (0.9 * sin(minf(f / 0.35, 1.0) * PI * 0.5) if f < 0.35 else 0.9 - 1.3 * minf((f - 0.35) / 0.25, 1.0))
			emo = "focus"
		"wait":
			emo = "happy"
		"bite":
			emo = "wow"
		"reel":
			emo = "strain" if _jerk > 0.3 else "focus"
			arm = 0.9 + _jerk * 0.3
		"land", "card":
			emo = "joy"
			arm = 1.5
		"away":
			emo = "sad"
	return {"emotion": emo, "blink": Chars.blinking(_t, 1.0) and emo in ["happy", "focus"], "arm_r": arm, "arm_l": 0.5,
			"bob": 0.5 * absf(sin(_t * 10.0)) if _state == "land" else 0.0}


## Scale of the people on the pier.
func _ps() -> float:
	return _k * (2.0 if _wide else 2.35)


## Canvas position of the front hand for a person drawn by Chars.person.
func _hand(feet: Vector2, s: float, arm: float) -> Vector2:
	var local := Vector2(13, -41) + Vector2(0, 18).rotated(-arm)
	return feet + local * s


func _rod_angle() -> float:
	var up := -1.15
	match _state:
		"cast":
			var f := _st / CAST_SEC
			if f < 0.35:
				return up - 0.9 * sin(f / 0.35 * PI * 0.5)
			return up - 0.9 + 1.4 * minf((f - 0.35) / 0.25, 1.0)
		"wait":
			return -0.55 + sin(_t * 1.5) * 0.02
		"bite":
			return -0.5 + sin(_t * 20.0) * 0.05
		"reel":
			return -0.75 - _jerk * 0.35
	return up


## Where the float is drawn: on the rod tip, flying, bobbing or dipping.
func _float_pos() -> Vector2:
	var s := _ps()
	var feet := _player + Vector2(0, -12.0 * _k)
	var pose := _player_pose()
	var hand := _hand(feet, s, float(pose["arm_r"]))
	var ang := _rod_angle()
	var tip := hand + Vector2(cos(ang), sin(ang)) * 110.0 * s
	match _state:
		"idle", "away", "card":
			return tip + Vector2(0, 80.0 * _k + sin(_t * 2.0) * 4.0)
		"cast":
			var f := clampf((_st / CAST_SEC - 0.4) / 0.6, 0.0, 1.0)
			if f <= 0.0:
				return tip + Vector2(0, 80.0 * _k)
			var p := (tip + Vector2(0, 80.0 * _k)).lerp(_target, f)
			p.y -= sin(f * PI) * 220.0 * _k
			return p
		"wait":
			return _target + Vector2(0, sin(_t * 2.6) * 4.0 * _k)
		"bite":
			return _target + Vector2(sin(_t * 30.0) * 3.0, 14.0 + absf(sin(_t * 9.0)) * 10.0) * _k
		"reel", "land":
			return _line_end()
	return _target


# --- Drawing: HUD --------------------------------------------------------------------------------

func _draw_hud() -> void:
	var ci := _hud
	var v := ci.size
	# Coins.
	var r := _pill
	Art.t_rect(ci, Rect2(r.position + Vector2(0, 5), r.size), r.size.y / 2.0, Art.shade_of(Color("1f3f73"), 0.3), 3.5, 0.0)
	Art.t_rect(ci, r, r.size.y / 2.0, Color("1f3f73"), 3.5, 0.0)
	var cb := 1.0 + _coin_bump * 0.25
	Art.push(ci, r.position + Vector2(r.size.y / 2.0 + 4.0, r.size.y / 2.0), 0.0, Vector2.ONE * cb)
	Art.coin(ci, Vector2.ZERO, r.size.y * 0.36)
	Art.pop(ci)
	Art.push(ci, r.position + Vector2(r.size.y + 14.0, r.size.y / 2.0 + 15.0), 0.0, Vector2.ONE * (1.0 + _coin_bump * 0.12))
	Art.text(ci, Vector2.ZERO, NumFormat.short(_shown_coins), 42, Art.GOLD if _coin_bump > 0.3 else Art.WHITE, 8, false)
	Art.pop(ci)
	# Hint banner.
	if _hint != "" and _hint_t > 0.0 and _state != "card":
		var a := clampf(_hint_t * 3.0, 0.0, 1.0)
		var font := UiTheme.heavy_font()
		var fs := 40
		while fs > 22 and font.get_string_size(_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > v.x - 60.0:
			fs -= 2
		var y := _pill.end.y + 70.0 if not _wide else _pill.end.y + 60.0
		if _state == "reel":
			y = _reel_rect.end.y + 56.0
		var wob := 1.0 + (0.04 * sin(_t * 6.0) if _state in ["idle", "bite"] else 0.0)
		Art.push(ci, Vector2(v.x / 2.0, y), 0.0, Vector2.ONE * wob)
		Art.text(ci, Vector2.ZERO, _hint, fs, Color(_hint_col, a), 9)
		Art.pop(ci)
	if _state == "reel":
		_draw_reel(ci)


func _draw_reel(ci: CanvasItem) -> void:
	var r := _reel_rect
	var sh := Vector2(sin(_t * 70.0), 0) * _shake * 8.0 if not Settings.reduce_motion else Vector2.ZERO
	var box := Rect2(r.position - Vector2(18, 18) + sh, r.size + Vector2(36, 36))
	Art.t_rect(ci, Rect2(box.position + Vector2(0, 6), box.size), 30, Art.shade_of(Art.CREAM_DARK, 0.3), 4.0, 0.0)
	Art.t_rect(ci, box, 30, Art.CREAM, 4.0, 0.0)
	var bar := Rect2(r.position + sh, r.size)
	Art.t_rect(ci, bar, 22, Color("1f5f96"), 3.5, 0.0)
	# The green zone (with its forgiving edges shown softly).
	var zx := bar.position.x + bar.size.x * (_zone - _zone_w / 2.0)
	var zw := bar.size.x * _zone_w
	var zr := Rect2(zx, bar.position.y + 6.0, zw, bar.size.y - 12.0)
	Art.flat(ci, Art.rrect_pts(zr.grow_individual(bar.size.x * FishData.REEL_MARGIN, 0, bar.size.x * FishData.REEL_MARGIN, 0), 16), Color(0.45, 0.95, 0.45, 0.25))
	var pulse := 0.85 + 0.15 * sin(_t * 8.0)
	Art.flat(ci, Art.rrect_pts(zr, 16), Color(Art.GREEN, pulse))
	Art.flat(ci, Art.rrect_pts(Rect2(zr.position + Vector2(6, 4), Vector2(zr.size.x - 12, 8)), 4), Color(1, 1, 1, 0.45))
	# The marker: a little fish swimming back and forth.
	var mx := bar.position.x + bar.size.x * _marker
	var my := bar.get_center().y
	var inside := absf(_marker - _zone) <= _zone_w / 2.0 + FishData.REEL_MARGIN
	Art.line(ci, Vector2(mx, bar.position.y - 8.0), Vector2(mx, bar.end.y + 8.0), Art.INK, 7.0)
	Art.line(ci, Vector2(mx, bar.position.y - 8.0), Vector2(mx, bar.end.y + 8.0), Art.WHITE, 3.0)
	Art.t_circle(ci, Vector2(mx, my), 27.0, Color("fff3b0") if inside else Art.CREAM, 3.5, 0.4)
	Art.push(ci, Vector2(mx, my), 0.0, Vector2.ONE * 0.36)
	FishArt.draw(ci, "sardine" if _fish.is_empty() else str(_fish["id"]), _t * 2.0, _dir, inside, true)
	Art.pop(ci)
	# Hits so far.
	for i in FishData.REEL_HITS:
		var p := Vector2(bar.get_center().x + (i - (FishData.REEL_HITS - 1) / 2.0) * 44.0, box.position.y - 4.0)
		Art.t_circle(ci, p, 16.0, Art.GOLD if i < _hits else Color("c9c3d9"), 3.0, 0.4)
		if i < _hits:
			Art.flat(ci, Art.star_pts(p, 10.0, 4.5, 5), Color("fff3b0"))
	# Tries left: small hearts on the frame, top right.
	for i in FishData.REEL_MISSES:
		var hp := Vector2(box.end.x - 34.0 - i * 32.0, box.position.y - 2.0)
		var on := i < FishData.REEL_MISSES - _misses
		_heart(ci, hp, on)


func _heart(ci: CanvasItem, p: Vector2, on: bool) -> void:
	Art.push(ci, p, 0.0, Vector2.ONE * 0.9)
	var pts := Art.smooth_pts(PackedVector2Array([Vector2(0, -6), Vector2(8, -13), Vector2(15, -5), Vector2(0, 12), Vector2(-15, -5), Vector2(-8, -13)]), 3)
	Art.toon(ci, pts, Art.RED if on else Color("c9c3d9"), 2.5, 0.4)
	Art.pop(ci)


# --- Drawing: effects ----------------------------------------------------------------------------

func _draw_fx() -> void:
	var ci := _fx
	for d in _drops:
		var f: float = d["age"] / d["life"]
		Art.push(ci, d["p"], 0.0, Vector2.ONE * float(d["s"]) / 6.0 * (1.0 - f * 0.5))
		Art.disc(ci, Vector2.ZERO, 6.0, Color(0.85, 0.97, 1.0, snappedf(1.0 - f * f, 0.1)))
		Art.pop(ci)
	for s in _stars:
		var f: float = s["age"] / s["life"]
		Art.push(ci, s["p"], s["age"] * 5.0, Vector2.ONE * float(s["s"]) * (1.0 - f))
		Art.flat(ci, Art.star_pts(Vector2.ZERO, 12.0, 4.0, 4), s["c"])
		Art.pop(ci)
	for fl in _flyers:
		if fl["age"] < 0.0:
			continue
		var f := clampf(fl["age"] / fl["life"], 0.0, 1.0)
		var e := f * f * (3.0 - 2.0 * f)
		var from: Vector2 = fl["from"]
		var to: Vector2 = fl["to"]
		var p := from.lerp(to, e)
		p += (to - from).orthogonal().normalized() * sin(f * PI) * float(fl["bend"]) * 0.5
		p.y -= sin(f * PI) * 90.0
		if fl["kind"] == "coin":
			Art.coin(ci, p, 22.0 * (1.0 + sin(f * PI) * 0.3))
		else:
			Art.push(ci, p, sin(f * TAU) * 0.5, Vector2.ONE * lerpf(1.1, 0.5, f) * _k)
			FishArt.draw(ci, str(fl["id"]), _t * 2.0, 1.0, true)
			Art.pop(ci)
	for tx in _texts:
		var f: float = tx["age"] / tx["life"]
		var sc := minf(1.0, f * 6.0) * (1.0 + 0.25 * sin(minf(f * 6.0, 1.0) * PI))
		if f > 0.75:
			sc *= 1.0 - (f - 0.75) / 0.25
		Art.push(ci, tx["p"] + Vector2(0, -50.0 * f), 0.0, Vector2.ONE * maxf(sc, 0.01))
		Art.text(ci, Vector2(0, tx["size"] * 0.35), tx["s"], tx["size"], tx["c"], 9)
		Art.pop(ci)
