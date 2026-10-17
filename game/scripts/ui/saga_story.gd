class_name SagaStory
extends Control
## Story scenes of the saga (Top League games), comic style: a framed
## picture on top, the Keeper of the Deep (an old diver who has guarded the
## Coral Light for forty years) speaking in a box below. Shown once each:
## "intro" (entering the league), "pre_<boss>" (before a guard's first
## fight) and "post_<boss>" (after it is beaten). Tap: the text finishes,
## then the next page. Opened by main.open_story(id, done).

signal finished

## story id -> pages [picture, text key]. Pictures: keeper, murk, acts,
## boss:<id>, won:<id>.
const STORIES := {
	"intro": [["keeper", "STORY_INTRO_1"], ["murk", "STORY_INTRO_2"], ["boss:crabblack", "STORY_INTRO_3"], ["acts", "STORY_INTRO_4"]],
	"act2": [["atlantis", "STORY_ACT2_1"], ["tides", "STORY_ACT2_2"], ["relics", "STORY_ACT2_3"], ["boss:automaton", "STORY_ACT2_4"]],
	"act3": [["rlyeh", "STORY_ACT3_1"], ["rifts", "STORY_ACT3_2"], ["boss:ancient_one", "STORY_ACT3_3"], ["boss:deep_one_priest", "STORY_ACT3_4"]],
}
const TYPE_CPS := 55.0

var id := ""
var _pages: Array = []
var _page := 0
var _pic: ArtView
var _text: Label
var _next: Button
var _typing := 0.0


static func t(k: String) -> String:
	return TranslationServer.translate(k)


## The pages of story `sid` ([] if there is none).
static func pages_of(sid: String) -> Array:
	if STORIES.has(sid):
		return STORIES[sid]
	var parts := sid.split("_", true, 1)
	if parts.size() == 2 and MineBoss.BOSSES.has(parts[1]):
		if parts[0] == "pre":
			return [["boss:" + parts[1], "STORY_PRE_" + parts[1].to_upper()]]
		if parts[0] == "post":
			return [["won:" + parts[1], "STORY_POST_" + parts[1].to_upper()]]
	return []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pages = pages_of(id)
	var bg := ArtView.make(_draw_bg, Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(minf(620.0, get_viewport_rect().size.x - 36.0), 0)
	center.add_child(col)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	var skip := Button.new()
	skip.theme_type_variation = &"DarkButton"
	skip.text = t("STORY_SKIP")
	skip.add_theme_font_size_override("font_size", 22)
	skip.pressed.connect(func(): Sfx.play("click"); _finish())
	top.add_child(skip)
	col.add_child(top)
	_pic = ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_pic(ci, s, tt), Vector2(0, clampf(get_viewport_rect().size.y * 0.42, 260.0, 380.0)), true)
	col.add_child(_pic)
	# The Keeper's speech box.
	var box := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("f3ecff"), 24, 6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	box.add_theme_stylebox_override("panel", sb)
	col.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	box.add_child(inner)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	var face := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): keeper_face(ci, s / 2.0, 28.0, tt), Vector2(62, 62), true)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(face)
	var nm := Views.label(t("STORY_KEEPER"), 26, Color("6a3cc0"), true)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.add_child(nm)
	inner.add_child(who)
	_text = Views.label("", 24, Art.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 112)
	inner.add_child(_text)
	_next = Button.new()
	_next.theme_type_variation = &"PurpleButton"
	_next.custom_minimum_size = Vector2(0, 74)
	_next.pressed.connect(_advance)
	col.add_child(_next)
	_show(0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _show(i: int) -> void:
	_page = i
	if i >= _pages.size():
		_finish()
		return
	_text.text = t(_pages[i][1])
	_text.visible_ratio = 0.0
	_typing = 0.0
	_next.text = t("STORY_GO") if i == _pages.size() - 1 else t("STORY_NEXT")
	_pic.queue_redraw()


func _process(delta: float) -> void:
	if _text and _text.visible_ratio < 1.0:
		_typing += delta
		var n := maxi(1, _text.get_total_character_count())
		_text.visible_ratio = minf(1.0, _typing * TYPE_CPS / n) if not Settings.reduce_motion else 1.0


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		if e.keycode == KEY_ESCAPE:
			_finish()
		else:
			_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		return
	Sfx.play("click")
	_show(_page + 1)


func _finish() -> void:
	if is_queued_for_deletion():
		return
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


# --- Drawing -------------------------------------------------------------------------

func _draw_bg(ci: CanvasItem, s: Vector2, tt: float) -> void:
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("1a0d3a"), Color("1a0d3a"), Color("07061c"), Color("07061c")]))
	for i in 18:
		var p := Vector2(fposmod(i * 211.0, s.x), fposmod(i * 137.0 - snappedf(tt * (8.0 + i % 5 * 3.0), 2.0), s.y))
		Art.dot(ci, p, 1.5 + i % 3, Color("c9a3ff", 0.35))


func _draw_pic(ci: CanvasItem, s: Vector2, tt: float) -> void:
	if _page >= _pages.size():
		return
	draw_picture(ci, s, str(_pages[_page][0]), tt)


## A comic panel: an ink frame, a slight tilt, a scene inside.
static func draw_picture(ci: CanvasItem, s: Vector2, pic: String, tt: float) -> void:
	tt = snappedf(tt, 1.0 / 20.0)
	var r := Rect2(Vector2(6, 6), s - Vector2(12, 12))
	Art.push(ci, s / 2.0, -0.015)
	var lr := Rect2(r.position - s / 2.0, r.size)
	Art.t_rect(ci, lr.grow(6.0), 18.0, Color("f3ecff"), 4.0, 0.0)
	var inner := Art.rrect_pts(lr, 12.0)
	var deep := Color("08123a")
	var top := Color("3a2a8a")
	if pic.begins_with("won"):
		top = Color("4a7ad8")
	elif pic == "murk":
		top = Color("2a0d40")
	Art.grad(ci, PackedVector2Array([lr.position, Vector2(lr.end.x, lr.position.y), lr.end, Vector2(lr.position.x, lr.end.y)]),
		PackedColorArray([top, top, deep, deep]))
	Art.pop(ci)
	Art.push(ci, r.position, 0.0)
	var c := r.size / 2.0
	var k := clampf(minf(r.size.x / 420.0, r.size.y / 330.0), 0.6, 1.4)
	_seabed(ci, r.size)
	if pic == "keeper":
		Art.glow(ci, c + Vector2(0, -10), 150.0 * k, Color("ff8ae0", 0.25))
		keeper(ci, c + Vector2(0, 20 * k), 1.25 * k, tt)
	elif pic == "murk":
		_murk_scene(ci, r.size, c, k, tt)
	elif pic == "acts":
		_acts(ci, r.size, k, tt)
	elif pic == "atlantis":
		_atlantis(ci, r.size, c, k, tt)
	elif pic == "rlyeh":
		Art.glow(ci, c + Vector2(0, -40 * k), 150.0 * k, Color("7dff6a", 0.22))
		for i in 4:
			RlyehArt.monolith(ci, Vector2(r.size.x * (0.1 + i * 0.27), r.size.y - 16.0), (90.0 + (i % 2) * 50.0) * k, 14.0 * k, (i - 1.5) * 0.12, RlyehArt.STONE)
		RlyehArt.idol(ci, Vector2(c.x, r.size.y - 30.0 * k), 2.6 * k, Color("4a6a5a"))
		MurkVeil.eye(ci, Vector2(30, 40) * k, 10.0 * k, fmod(tt, 3.0) < 0.2, false)
		keeper(ci, Vector2(r.size.x - 62 * k, r.size.y - 56 * k), 0.5 * k, tt)
	elif pic == "rifts":
		var rc := Vector2(c.x - 40 * k, r.size.y - 50.0 * k)
		Art.glow(ci, rc, 120.0 * k, Color("7dff6a", 0.3))
		Art.toon(ci, PackedVector2Array([rc + Vector2(-70, 8) * k, rc + Vector2(-20, -20) * k, rc + Vector2(10, -6) * k, rc + Vector2(60, -24) * k,
			rc + Vector2(74, 4) * k, rc + Vector2(16, 24) * k]), Color("0a0a12"), 3.0, 0.0, Color("7dff6a"))
		for i in 3:
			Art.push(ci, rc + Vector2(-40 + i * 40, 0) * k, (i - 1) * 0.5, Vector2(2.6, 2.6) * k)
			OreArt.tentacle(ci, tt * 1.4 + i * 2.0, Color("4a6a5a"))
			Art.pop(ci)
		keeper(ci, Vector2(r.size.x - 62 * k, r.size.y - 56 * k), 0.5 * k, tt)
	elif pic == "tides":
		_tides(ci, r.size, c, k, tt)
	elif pic == "relics":
		Art.glow(ci, c, 160.0 * k, Color("ffd84a", 0.3))
		for i in 3:
			var a := tt * 0.8 + i * TAU / 3.0
			Art.push(ci, c + Vector2(cos(a) * 95.0, sin(a) * 34.0 - 20.0) * k, 0.0)
			RelicView.draw_icon(ci, Vector2.ZERO, (26.0 + i * 4.0) * k, {"kind": Relics.KINDS[5 + i], "rarity": i + 1}, tt)
			Art.pop(ci)
		keeper(ci, Vector2(r.size.x - 70 * k, r.size.y - 60 * k), 0.55 * k, tt)
	elif pic.begins_with("boss:"):
		Art.glow(ci, c, 170.0 * k, Color("b04cff", 0.35))
		BossArt.draw(ci, pic.trim_prefix("boss:"), c + Vector2(0, 10 * k), 0.95 * k, tt, 0.0, 0.5)
		MurkVeil.eye(ci, Vector2(30, 40) * k, 10.0 * k, fmod(tt, 3.0) < 0.2, false)
		MurkVeil.eye(ci, Vector2(r.size.x - 30 * k, 60 * k), 9.0 * k, fmod(tt + 1.0, 3.5) < 0.2, true)
	elif pic.begins_with("won:"):
		for i in 6:
			var x := r.size.x * (0.1 + i * 0.17)
			Art.grad(ci, PackedVector2Array([Vector2(x - 14, 0), Vector2(x + 14, 0), Vector2(x + 60, r.size.y), Vector2(x - 30, r.size.y)]),
				PackedColorArray([Color(1, 0.95, 0.7, 0.35), Color(1, 0.95, 0.7, 0.35), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
		Art.glow(ci, c, 140.0 * k, Color("ffe08a", 0.4))
		Art.push(ci, c + Vector2(0, 30 * k), -0.25)
		BossArt.draw(ci, pic.trim_prefix("won:"), Vector2.ZERO, 0.7 * k, 0.0, 0.6, 0.0)
		Art.pop(ci)
		for i in 3:
			var a := tt * 3.0 + i * TAU / 3.0
			Art.flat(ci, Art.star_pts(c + Vector2(cos(a) * 60.0, -50.0 + sin(a) * 16.0) * k, 12.0 * k, 5.0 * k, 5), Color("ffd45a"))
		keeper(ci, Vector2(r.size.x - 70 * k, r.size.y - 60 * k), 0.55 * k, tt)
	Art.pop(ci)


## Act II: the sunken city, columns and a golden dome under sun rays.
static func _atlantis(ci: CanvasItem, s: Vector2, c: Vector2, k: float, tt: float) -> void:
	for i in 5:
		var x := s.x * (0.12 + i * 0.2)
		Art.grad(ci, PackedVector2Array([Vector2(x - 10, 0), Vector2(x + 10, 0), Vector2(x + 50, s.y), Vector2(x - 30, s.y)]),
			PackedColorArray([Color(1, 0.9, 0.55, 0.3), Color(1, 0.9, 0.55, 0.3), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	var base := Vector2(c.x, s.y - 40.0 * k)
	Art.glow(ci, base + Vector2(0, -120 * k), 130.0 * k, Color("ffd84a", 0.3 + 0.05 * sin(tt * 2.0)))
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(base + Vector2(cos(a) * 92.0, -130.0 + sin(a) * 60.0) * k)
	Art.toon(ci, dome, AtlantisArt.GOLD, 3.0, 0.0)
	Art.t_rect(ci, Rect2(base + Vector2(-108, -134) * k, Vector2(216, 14) * k), 4.0, AtlantisArt.MARBLE, 3.0, 0.0)
	for i in 6:
		AtlantisArt.column(ci, base + Vector2(-90 + i * 36, 0) * k, 120.0 * k, 9.0 * k, AtlantisArt.MARBLE, i == 4)
	Art.t_rect(ci, Rect2(base + Vector2(-118, 0) * k, Vector2(236, 14) * k), 4.0, AtlantisArt.MARBLE_DARK, 3.0, 0.0)
	keeper(ci, Vector2(s.x - 62 * k, s.y - 56 * k), 0.5 * k, tt)


## Act II: the tide rises and falls (lift and boats / the mines).
static func _tides(ci: CanvasItem, s: Vector2, c: Vector2, k: float, tt: float) -> void:
	Art.dot(ci, Vector2(s.x * 0.8, s.y * 0.2), 26.0 * k, Color("fff4c8"))
	var lvl := s.y * (0.45 + 0.12 * sin(tt * 0.9))
	var top := PackedVector2Array()
	for i in 21:
		var x := s.x * i / 20.0
		top.append(Vector2(x, lvl + sin(tt * 2.0 + i * 0.7) * 6.0 * k))
	var water := top.duplicate()
	water.append(Vector2(s.x, s.y))
	water.append(Vector2(0, s.y))
	Art.flat_now(ci, water, Color("2a8ed8", 0.55))
	for i in top.size() - 1:
		Art.line(ci, top[i], top[i + 1], Color(1, 1, 1, 0.8), 3.0 * k)
	for i in 4:
		AtlantisArt.column(ci, Vector2(s.x * (0.12 + i * 0.12), s.y - 10.0), (60.0 + i * 18.0) * k, 7.0 * k, AtlantisArt.MARBLE, i == 1)
	AtlantisArt.cog(ci, Vector2(s.x * 0.68, s.y - 50.0 * k), 34.0 * k, 10, AtlantisArt.BRONZE, tt)
	keeper(ci, Vector2(s.x - 62 * k, s.y - 56 * k), 0.5 * k, tt)


static func _seabed(ci: CanvasItem, s: Vector2) -> void:
	var hills := Art.smooth_pts(PackedVector2Array([Vector2(-20, s.y + 20), Vector2(-20, s.y - 40), Vector2(s.x * 0.3, s.y - 62),
		Vector2(s.x * 0.6, s.y - 34), Vector2(s.x + 20, s.y - 56), Vector2(s.x + 20, s.y + 20)]), 4)
	var c := Art.clipped(hills, Art.rrect_pts(Rect2(Vector2.ZERO, s), 12.0))
	if c.size() >= 3:
		Art.flat(ci, c, Color("0a0a2a"))


## The Murk closing in on the Coral Light: clouds with eyes, a tentacle.
static func _murk_scene(ci: CanvasItem, s: Vector2, c: Vector2, k: float, tt: float) -> void:
	var light := Vector2(c.x, s.y - 70 * k)
	Art.glow(ci, light, 110.0 * k, Color("ff8ae0", 0.45))
	Art.crystal(ci, light + Vector2(0, 20 * k), 70.0 * k, 26.0 * k, 0.0, Color("ff9ae6"))
	Art.crystal(ci, light + Vector2(-22 * k, 22 * k), 44.0 * k, 18.0 * k, -0.35, Color("7ae8ff"))
	Art.crystal(ci, light + Vector2(22 * k, 22 * k), 40.0 * k, 16.0 * k, 0.35, Color("c9a3ff"))
	var clouds := [Vector2(0.08, 0.2), Vector2(0.25, 0.08), Vector2(0.75, 0.1), Vector2(0.92, 0.25), Vector2(0.05, 0.55), Vector2(0.95, 0.6)]
	for i in clouds.size():
		var p: Vector2 = clouds[i] * s
		var bob := snappedf(sin(tt * 1.2 + i) * 4.0, 1.0)
		Art.flat(ci, Art.circle_pts(p + Vector2(0, bob), 64.0 * k, 24), Color("1a0626", 0.92))
		Art.flat(ci, Art.circle_pts(p + Vector2(40, 20 + bob) * k, 44.0 * k, 20), Color("1a0626", 0.92))
		MurkVeil.eye(ci, p + Vector2(8, 6 + bob) * k, 10.0 * k, fmod(tt + i * 0.7, 3.0) < 0.2, i % 2 == 1)
	Art.push(ci, Vector2(-4, s.y * 0.45), 0.35 + snappedf(sin(tt) * 0.1, 0.02), Vector2(k * 1.3, k * 1.3))
	MurkVeil.tentacle(ci)
	Art.pop(ci)
	Art.push(ci, Vector2(s.x + 4, s.y * 0.38), PI - 0.3 - snappedf(sin(tt + 1.0) * 0.1, 0.02), Vector2(k * 1.2, -k * 1.2))
	MurkVeil.tentacle(ci)
	Art.pop(ci)


## The saga's road: the Twilight Zone, Atlantis and R'lyeh side by side.
static func _acts(ci: CanvasItem, s: Vector2, k: float, tt: float) -> void:
	var w := s.x / 3.0
	var by := s.y - 50.0
	var names := ["I", "II", "III"]
	for i in 3:
		var cx := w * (i + 0.5)
		if i == 0:
			Art.glow(ci, Vector2(cx, by - 70), 80.0 * k, Color("ff8ae0", 0.45))
			for j in 3:
				Art.crystal(ci, Vector2(cx - 30 + j * 30, by), (90.0 - absi(j - 1) * 30.0) * k, 18.0 * k, (j - 1) * 0.2, Color("ff9ae6") if j == 1 else Color("7ae8ff"))
		elif i == 1:
			# Atlantis: a golden dome on columns.
			Art.glow(ci, Vector2(cx, by - 80), 80.0 * k, Color("ffd45a", 0.35))
			Art.t_rect(ci, Rect2(cx - 50 * k, by - 18 * k, 100 * k, 18 * k), 4.0, Color("e6d3a0"), 2.5, 0.3)
			for j in 4:
				Art.t_rect(ci, Rect2(cx - 44 * k + j * 26 * k, by - 80 * k, 12 * k, 62 * k), 3.0, Color("f1e4c0"), 2.5, 0.4)
			Art.t_rect(ci, Rect2(cx - 54 * k, by - 92 * k, 108 * k, 14 * k), 4.0, Color("e6d3a0"), 2.5, 0.3)
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(cx - 46 * k, by - 92 * k), Vector2(cx, by - 140 * k), Vector2(cx + 46 * k, by - 92 * k)]), 4), Color("ffc93c"), 2.5, 0.6)
		else:
			# R'lyeh: crooked green spires, a huge eye, a tentacle.
			Art.glow(ci, Vector2(cx, by - 80), 80.0 * k, Color("6aff9a", 0.3))
			for j in 3:
				var x := cx - 32 * k + j * 32 * k
				var h := (110.0 - absi(j - 1) * 34.0) * k
				Art.toon(ci, PackedVector2Array([Vector2(x - 14 * k, by), Vector2(x + 12 * k, by), Vector2(x + 18 * k * (1 - j), by - h), Vector2(x - 2 * k, by - h - 10 * k)]), Color("2f6a52"), 2.5, 0.5)
			var blink := fmod(tt, 4.0) < 0.2
			MurkVeil.eye(ci, Vector2(cx, by - 150 * k), 20.0 * k, blink, false)
		Art.text(ci, Vector2(cx, 40), names[i], int(30 * k) + 4, Color("ffd45a"), 6)
	for i in 2:
		Art.line(ci, Vector2(w * (i + 1), 20), Vector2(w * (i + 1), s.y - 20), Color(1, 1, 1, 0.15), 2.0)


# --- The Keeper of the Deep ----------------------------------------------------------

## The old diver-keeper: a brass helmet with a round window (a white beard
## and kind eyes inside), a patched green suit and the Coral Light lantern.
## About 220 px tall at k = 1, feet at (0, 100).
static func keeper(ci: CanvasItem, at: Vector2, k: float, tt: float) -> void:
	var bob := snappedf(sin(tt * 1.6) * 3.0, 1.0)
	Art.push(ci, at + Vector2(0, bob), 0.0, Vector2(k, k))
	var suit := Color("2f7a6a")
	var brass := Color("d9a441")
	# Legs and boots.
	for s in [-1.0, 1.0]:
		Art.toon(ci, Art.rrect_pts(Rect2(s * 22 - 12, 40, 24, 50), 10.0), suit.darkened(0.15), 3.0, 0.5)
		Art.toon(ci, Art.rrect_pts(Rect2(s * 22 - 16, 82, 32, 18), 8.0), Color("3a3046"), 3.0, 0.4)
	# Body with a patch and a belt.
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-46, -30), Vector2(46, -30), Vector2(50, 50), Vector2(-50, 50)]), 4), suit, 3.0, 0.8)
	Art.toon(ci, Art.rrect_pts(Rect2(-48, 22, 96, 12), 4.0), Color("6a4a2a"), 2.5, 0.3)
	Art.t_rect(ci, Rect2(-8, 21, 16, 14), 3.0, brass, 2.5, 0.3)
	Art.toon(ci, Art.rrect_pts(Rect2(14, -14, 22, 20), 4.0), Color("8ad0b0"), 2.0, 0.2)
	# The arm with the lantern (right).
	Art.toon(ci, Art.rrect_pts(Rect2(38, -24, 22, 54), 10.0), suit.darkened(0.08), 3.0, 0.6)
	var lp := Vector2(66, 34 + bob * 0.5)
	Art.line(ci, Vector2(52, 26), lp + Vector2(0, -26), Art.INK, 3.0)
	Art.glow(ci, lp, 60.0, Color("ff8ae0", 0.5))
	Art.t_rect(ci, Rect2(lp.x - 16, lp.y - 24, 32, 6), 3.0, brass, 2.5, 0.2)
	Art.t_rect(ci, Rect2(lp.x - 16, lp.y + 18, 32, 6), 3.0, brass, 2.5, 0.2)
	Art.crystal(ci, lp + Vector2(0, 18), 38.0, 16.0, 0.0, Color("ff9ae6"), 2.0)
	for x in [-14.0, 14.0]:
		Art.line(ci, lp + Vector2(x, -18), lp + Vector2(x, 18), Art.INK, 2.5)
	# Other arm.
	Art.toon(ci, Art.rrect_pts(Rect2(-60, -24, 22, 50), 10.0), suit.darkened(0.08), 3.0, 0.6)
	Art.t_circle(ci, Vector2(-49, 30), 11.0, brass, 2.5, 0.4)
	# The helmet.
	keeper_face(ci, Vector2(0, -70), 56.0, tt)
	Art.pop(ci)


## The Keeper's helmet with his face in the window (also the speech-box
## portrait), radius `r` around `c`.
static func keeper_face(ci: CanvasItem, c: Vector2, r: float, tt: float) -> void:
	var brass := Color("d9a441")
	var u := r / 56.0
	Art.t_circle(ci, c, r, brass, 3.0, 0.7)
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		Art.t_circle(ci, c + Vector2(cos(a), sin(a)) * r * 0.86, 4.0 * u, Color("f2d27a"), 2.0, 0.0)
	var win := r * 0.66
	Art.t_circle(ci, c, win + 6.0 * u, Color("b07f2a"), 3.0, 0.0)
	Art.t_circle(ci, c, win, Color("1d4a6a"), 2.5, 0.0)
	# Face: skin, white bushy brows, kind eyes, a big white beard.
	Art.flat(ci, Art.circle_pts(c + Vector2(0, -2) * u, win * 0.8, 24), Color("ffcf9e"))
	var blink := fmod(snappedf(tt, 0.05), 4.0) < 0.15
	for s in [-1.0, 1.0]:
		var e := c + Vector2(s * 12, -8) * u
		if blink:
			Art.line(ci, e - Vector2(4, 0) * u, e + Vector2(4, 0) * u, Art.INK, 2.5 * u)
		else:
			Art.flat(ci, Art.circle_pts(e, 4.0 * u, 10), Art.INK)
			Art.flat(ci, Art.circle_pts(e + Vector2(-1.2, -1.4) * u, 1.4 * u, 6), Art.WHITE)
		Art.flat(ci, Art.ellipse_pts(e + Vector2(s * 2, -9) * u, Vector2(9, 4.5) * u, 12, s * 0.2), Art.WHITE)
	Art.flat(ci, Art.ellipse_pts(c + Vector2(0, 2) * u, Vector2(6, 5) * u, 12), Color("f0a07a"))
	Art.flat(ci, Art.smooth_pts(PackedVector2Array([c + Vector2(-26, 2) * u, c + Vector2(-10, 10) * u, c + Vector2(10, 10) * u, c + Vector2(26, 2) * u,
		c + Vector2(20, 26) * u, c + Vector2(0, 36) * u, c + Vector2(-20, 26) * u]), 3), Color("f4f2ee"))
	Art.flat(ci, Art.ellipse_pts(c + Vector2(0, 10) * u, Vector2(9, 3) * u, 10), Color("c9b9a8"))
	# Glass shine.
	Art.flat(ci, Art.ellipse_pts(c + Vector2(-win * 0.45, -win * 0.5), Vector2(win * 0.22, win * 0.12), 12, -0.6), Color(1, 1, 1, 0.45))
