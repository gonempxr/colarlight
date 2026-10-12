class_name PassScreen
extends Control
## The Sea Pass on its own screen, like the passes of other games: a deep
## sea background, the level and XP on top, and a track scrolling sideways
## with two rows of reward cards (bonus on top, main below) joined by the
## level line. Tap a glowing card to take it; "Take all" takes every ready
## one. Data: BattlePass. Opened by main.open_pass().

const NODE_H := 76.0

## Card size follows the space the track gets (bigger on tall screens).
var COL_W := 150.0
var CARD_H := 184.0

var main: Node
var _t := 0.0
var _track: ScrollContainer
var _row: HBoxContainer
var _take_all: Button
var _level_view: Control
var _bonus_label: Label
var _drag_from := -1.0
var _drag_scroll := 0.0
var _dragged := false


static func t(key: String) -> String:
	return TranslationServer.translate(key)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GuideView.mark("pass")
	BattlePass.tick()
	var bg := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_bg(ci, s, tt), Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	col.add_child(_top_bar())
	col.add_child(_level_panel())
	col.add_child(_bonus_strip())
	col.add_child(_showcase())
	_track = ScrollContainer.new()
	_track.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_track.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.gui_input.connect(_on_track_input)
	_track.resized.connect(_fit_cards)
	col.add_child(_track)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.add_child(center)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 0)
	center.add_child(_row)
	_fill_track()
	_take_all = Button.new()
	_take_all.theme_type_variation = &"GoldButton"
	_take_all.custom_minimum_size = Vector2(0, 88)
	_take_all.add_theme_font_size_override("font_size", 30)
	_take_all.icon = Icons.get_icon("gift", 40)
	_take_all.pressed.connect(_take_everything)
	col.add_child(_take_all)
	_refresh_take()
	(func(): _scroll_to_level()).call_deferred()
	Sfx.play("start")


func _process(delta: float) -> void:
	_t += delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


# --- Top ------------------------------------------------------------------------------------

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
	banner.custom_minimum_size = Vector2(0, 80)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.draw.connect(func(): UiTheme.draw_banner(banner, Rect2(Vector2.ZERO, banner.size), UiTheme.BANNER_PURPLE))
	banner.resized.connect(banner.queue_redraw)
	var title := Label.new()
	title.text = t("BP_TITLE")
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.offset_bottom = -26
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.heavy_font())
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_constant_override("outline_size", 10)
	banner.add_child(title)
	var sub := Label.new()
	sub.text = t("BP_CHAPTER") % BattlePass.chapter()
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.offset_top = 40
	sub.offset_bottom = -8
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color("ffe9a0"))
	sub.add_theme_constant_override("outline_size", 6)
	banner.add_child(sub)
	h.add_child(banner)
	var how := Button.new()
	how.theme_type_variation = &"BlueButton"
	how.text = "?"
	how.custom_minimum_size = Vector2(76, 76)
	how.add_theme_font_size_override("font_size", 36)
	how.pressed.connect(func(): Sfx.play("click"); main._top.open(func(m): PassView.how(m)))
	h.add_child(how)
	return h


## The level shield and the XP bar on a dark glass panel.
func _level_panel() -> Control:
	_level_view = ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_level(ci, s), Vector2(0, 112))
	return _level_view


func _draw_level(ci: CanvasItem, s: Vector2) -> void:
	var r := Rect2(Vector2(0, 4), s - Vector2(0, 8))
	Art.t_rect(ci, r, 24.0, Color(0.06, 0.08, 0.25, 0.72), 3.0, 0.0)
	var lv := BattlePass.level()
	var c := Vector2(66, s.y / 2.0)
	draw_shield(ci, c, 46.0, lv, true)
	var x0 := 128.0
	var w := s.x - x0 - 24.0
	Art.text(ci, Vector2(x0 + w / 2.0, 42), t("BP_LEVEL") % [lv, BattlePass.LEVELS], 26, Art.WHITE, 7)
	var bar := Rect2(x0, 56, w, 30)
	Art.t_rect(ci, bar, 15.0, Color("1d2457"), 3.0, 0.0)
	var f := float(BattlePass.xp_in_level()) / float(BattlePass.XP_LEVEL)
	if f > 0.02:
		Art.t_rect(ci, Rect2(bar.position, Vector2(maxf(30.0, bar.size.x * f), bar.size.y)), 15.0, Color("5ee0ff"), 3.0, 0.6)
	var label := t("BP_DONE_SHORT") if lv >= BattlePass.LEVELS else "%d / %d XP" % [BattlePass.xp_in_level(), BattlePass.XP_LEVEL]
	Art.text(ci, bar.get_center() + Vector2(0, 8), label, 19, Art.WHITE, 6)


## The bonus track's state: how many challenges of the day are still needed.
func _bonus_strip() -> Control:
	var p := PanelContainer.new()
	var sb := UiTheme.pill_box(Color("6b3fd1") if not BattlePass.bonus_open() else Color("2fae5a"), 18)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	sb.content_margin_left = 14
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(Views.icon("star" if BattlePass.bonus_open() else "lock", 34))
	_bonus_label = Label.new()
	_bonus_label.add_theme_font_size_override("font_size", 19)
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bonus_label.custom_minimum_size.x = 150
	_bonus_label.text = t("BP_BONUS_OPEN") if BattlePass.bonus_open() else \
		t("BP_BONUS_LOCKED") % [mini(BattlePass.challenges_done(), BattlePass.BONUS_NEED), BattlePass.BONUS_NEED]
	h.add_child(_bonus_label)
	return p


## The next big reward (an item, else the next bonus prize), shown large.
func _showcase() -> Control:
	var lv := 0
	var r := {}
	for l in BattlePass.ITEMS:
		if not BattlePass.taken("f", l):
			lv = l
			r = BattlePass.reward("f", l)
			break
	if lv == 0 or not r.has("item"):
		return Control.new()
	var item := Content.cosmetic(str(r["item"]))
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, 170)
	var art := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := Vector2(s.x * 0.28, s.y / 2.0)
		for i in 10:
			var a := TAU * i / 10.0 + snappedf(tt * 0.3, 0.05)
			Art.grad(ci, PackedVector2Array([c, c + Vector2(cos(a - 0.14), sin(a - 0.14)) * 120.0, c + Vector2(cos(a + 0.14), sin(a + 0.14)) * 120.0]),
				PackedColorArray([Color(1.0, 0.9, 0.4, 0.55), Color(1.0, 0.9, 0.4, 0.0), Color(1.0, 0.9, 0.4, 0.0)]))
		Art.flat(ci, Art.circle_pts(c, 58.0, 32), Color(1.0, 0.9, 0.5, 0.25))
		Art.push(ci, c - Vector2(70, 60), 0.0, Vector2.ONE)
		Wardrobe._draw_item(ci, item, Vector2(140, 120), tt)
		Art.pop(ci), Vector2.ZERO, true)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(art)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 0
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	box.resized.connect(func(): v.offset_left = box.size.x * 0.52)
	var a := Label.new()
	a.text = t("BP_SHOWCASE") % lv
	a.add_theme_font_size_override("font_size", 20)
	a.add_theme_color_override("font_color", Color("ffe9a0"))
	a.add_theme_constant_override("outline_size", 6)
	v.add_child(a)
	var n := Label.new()
	n.text = t("ITEM_" + str(r["item"]).to_upper())
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_override("font", UiTheme.heavy_font())
	n.add_theme_font_size_override("font_size", 28)
	n.add_theme_constant_override("outline_size", 9)
	v.add_child(n)
	var only := Label.new()
	only.text = t("BP_ONLY_HERE")
	only.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	only.add_theme_font_size_override("font_size", 16)
	only.add_theme_color_override("font_color", Color("bfe8ff"))
	only.add_theme_constant_override("outline_size", 5)
	v.add_child(only)
	return box


# --- The track ------------------------------------------------------------------------------

func _fill_track() -> void:
	for c in _row.get_children():
		c.queue_free()
	# Row names at the start of the track.
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.custom_minimum_size.x = 92
	for k in ["BP_ROW_BONUS", "", "BP_ROW_MAIN"]:
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(92, CARD_H if k != "" else NODE_H)
		if k != "":
			var l := Label.new()
			l.text = t(k)
			l.add_theme_font_override("font", UiTheme.heavy_font())
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", Color("ffd84a") if k == "BP_ROW_BONUS" else Color("bfe8ff"))
			l.add_theme_constant_override("outline_size", 7)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 86
			holder.add_child(l)
		names.add_child(holder)
	_row.add_child(names)
	for lv in range(1, BattlePass.LEVELS + 1):
		_row.add_child(_column(lv))
	var tail := Control.new()
	tail.custom_minimum_size.x = 40
	_row.add_child(tail)


func _column(lv: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size.x = COL_W
	v.add_child(_card("b", lv))
	v.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_node(ci, s, lv), Vector2(COL_W, NODE_H)))
	v.add_child(_card("f", lv))
	return v


## The level line through the column and the level number on it.
func _draw_node(ci: CanvasItem, s: Vector2, lv: int) -> void:
	var y := s.y / 2.0
	var cur := BattlePass.level()
	var line := Rect2(0, y - 9, s.x, 18)
	Art.flat(ci, Art.rrect_pts(line.grow(3), 6.0), Art.INK)
	Art.flat(ci, Art.rrect_pts(line, 4.0), Color("1d2457"))
	var fill := 0.0
	if lv <= cur:
		fill = 1.0
	elif lv == cur + 1:
		fill = 0.5 * float(BattlePass.xp_in_level()) / float(BattlePass.XP_LEVEL)
	# The left half belongs to the way in, the right half to the way out.
	if lv - 1 <= cur and lv > 1:
		Art.flat(ci, Art.rrect_pts(Rect2(0, y - 9, s.x / 2.0, 18), 4.0), Color("5ee0ff"))
	if fill >= 1.0 and lv < cur:
		Art.flat(ci, Art.rrect_pts(Rect2(s.x / 2.0, y - 9, s.x / 2.0, 18), 4.0), Color("5ee0ff"))
	elif lv == cur and BattlePass.level() < BattlePass.LEVELS:
		var part := float(BattlePass.xp_in_level()) / float(BattlePass.XP_LEVEL)
		if part > 0.02:
			Art.flat(ci, Art.rrect_pts(Rect2(s.x / 2.0, y - 9, s.x / 2.0 * part, 18), 4.0), Color("5ee0ff"))
	draw_shield(ci, Vector2(s.x / 2.0, y), 27.0, lv, lv <= cur)


func _card(row: String, lv: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(COL_W, CARD_H)
	var r := BattlePass.reward(row, lv)
	var art := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_card(ci, s, tt, row, lv, r),
		Vector2(COL_W, CARD_H), BattlePass.ready(row, lv))
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(art)
	# The picture of the reward.
	if r.has("item"):
		var item := Content.cosmetic(str(r["item"]))
		var pw := COL_W * 0.78
		var ph := CARD_H * 0.56
		var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): Wardrobe._draw_item(ci, item, s, tt), Vector2(pw, ph))
		pic.position = Vector2((COL_W - pw) / 2.0, CARD_H * 0.11)
		pic.size = Vector2(pw, ph)
		box.add_child(pic)
	else:
		var icon := "pearl"
		if r.has("coins_min"):
			icon = "coin"
		elif r.has("boost"):
			icon = "bolt"
		var px := int(CARD_H * 0.44)
		var ic := Views.icon(icon, px)
		ic.position = Vector2((COL_W - px) / 2.0, CARD_H * 0.18)
		ic.size = Vector2(px, px)
		box.add_child(ic)
	var amount := Label.new()
	amount.text = _reward_text(r)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_override("font", UiTheme.heavy_font())
	amount.add_theme_font_size_override("font_size", int(CARD_H * 0.13) if not r.has("item") else int(CARD_H * 0.095))
	amount.add_theme_constant_override("outline_size", 7)
	amount.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if r.has("item") else TextServer.AUTOWRAP_OFF
	amount.position = Vector2(8, CARD_H - 14.0 - CARD_H * 0.24)
	amount.size = Vector2(COL_W - 16, CARD_H * 0.22)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(amount)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	SocialView.on_tap(box, func(): _tap(row, lv, box))
	return box


func _reward_text(r: Dictionary) -> String:
	if r.has("item"):
		return t("ITEM_" + str(r["item"]).to_upper())
	if r.has("pearls"):
		return "+%d" % int(r["pearls"])
	if r.has("coins_min"):
		return "+" + NumFormat.short(Progress.coins_for_minutes(float(r["coins_min"])))
	return "×2 " + t("BP_MIN") % (int(r["boost"]) / 60)


## A reward card: colour by kind, a gold frame on items, purple on the
## bonus row; glowing when ready, a check when taken, a lock when not yet.
func _draw_card(ci: CanvasItem, s: Vector2, tt: float, row: String, lv: int, r: Dictionary) -> void:
	var rect := Rect2(Vector2(9, 8), s - Vector2(18, 16))
	var ready := BattlePass.ready(row, lv)
	var taken := BattlePass.taken(row, lv)
	var fill := Color("8a6cf0")
	if r.has("coins_min"):
		fill = Color("f2a516")
	elif r.has("boost"):
		fill = Color("ff7a3c")
	elif r.has("item"):
		fill = Color("ffcf33")
	if row == "b" and not r.has("item"):
		fill = fill.lerp(Color("c04fe0"), 0.35)
	if ready:
		# A pulsing gold glow behind the card (stepped so the cache stays small).
		var pulse := snappedf(0.5 + 0.5 * sin(tt * 4.0), 0.25)
		Art.flat(ci, Art.rrect_pts(rect.grow(6.0 + pulse * 3.0), 22.0), Color(1.0, 0.86, 0.3, 0.55 + pulse * 0.25))
	var frame := Color("ffd84a") if r.has("item") else (Color("e7c6ff") if row == "b" else Art.WHITE)
	Art.t_rect(ci, rect, 18.0, frame, 3.5, 0.0)
	var inner := rect.grow(-5.0)
	Art.flat(ci, Art.rrect_pts(inner, 14.0), fill)
	# Light from the top, rays on items.
	if r.has("item"):
		var c := inner.get_center() + Vector2(0, -18)
		for i in 8:
			var a := TAU * i / 8.0 + 0.2
			Art.flat(ci, Art.clipped(PackedVector2Array([c, c + Vector2(cos(a - 0.18), sin(a - 0.18)) * 120.0,
				c + Vector2(cos(a + 0.18), sin(a + 0.18)) * 120.0]), Art.rrect_pts(inner, 14.0)), Color(1, 1, 1, 0.22))
	var top := Rect2(inner.position + Vector2(6, 4), Vector2(inner.size.x - 12, inner.size.y * 0.3))
	Art.flat(ci, Art.rrect_pts(top, minf(12.0, top.size.y / 2.0)), Color(1, 1, 1, 0.18))
	# The bottom band under the amount.
	var band := Rect2(inner.position.x, inner.end.y - s.y * 0.25, inner.size.x, s.y * 0.25)
	Art.flat(ci, Art.clipped(Art.rrect_pts(band, 0.0), Art.rrect_pts(inner, 14.0)), Color(0, 0, 0, 0.22))
	var locked := (lv > BattlePass.level()) or (row == "b" and not BattlePass.bonus_open())
	if taken:
		Art.flat(ci, Art.rrect_pts(inner, 14.0), Color(0.05, 0.05, 0.15, 0.55))
		var c := inner.get_center() + Vector2(0, -10)
		Art.t_circle(ci, c, 22.0, Art.GREEN, 3.0, 0.4)
		Art.polyline(ci, PackedVector2Array([c + Vector2(-10, 0), c + Vector2(-3, 8), c + Vector2(11, -8)]), Art.WHITE, 5.0)
	elif locked:
		Art.flat(ci, Art.rrect_pts(inner, 14.0), Color(0.05, 0.05, 0.2, 0.32))
		var p := Vector2(inner.end.x - 16, inner.position.y + 16)
		Art.t_rect(ci, Rect2(p + Vector2(-10, -4), Vector2(20, 16)), 4.0, Color("c9cfdb"), 2.5, 0.0)
		Art.arc(ci, p + Vector2(0, -4), 6.0, PI, TAU, 8, Art.INK, 3.0)
	elif ready:
		var tag := Rect2(Vector2(inner.get_center().x - 46, inner.position.y - 12), Vector2(92, 26))
		Art.t_rect(ci, tag, 12.0, Art.RED, 3.0, 0.3)
		Art.text(ci, tag.get_center() + Vector2(0, 7), t("BP_READY"), 17, Art.WHITE, 5)


## The level badge: a rounded shield with the number (gold when reached).
static func draw_shield(ci: CanvasItem, c: Vector2, r: float, n: int, reached: bool) -> void:
	var pts := Art.smooth_pts(PackedVector2Array([c + Vector2(-r * 0.86, -r * 0.8), c + Vector2(0, -r * 1.02), c + Vector2(r * 0.86, -r * 0.8),
		c + Vector2(r * 0.86, r * 0.1), c + Vector2(0, r * 1.0), c + Vector2(-r * 0.86, r * 0.1)]), 3)
	Art.toon(ci, pts, Color("ffcf33") if reached else Color("7c86a8"), maxf(2.5, r * 0.09), 0.6)
	var inner := Art.smooth_pts(PackedVector2Array([c + Vector2(-r * 0.62, -r * 0.6), c + Vector2(0, -r * 0.76), c + Vector2(r * 0.62, -r * 0.6),
		c + Vector2(r * 0.62, r * 0.05), c + Vector2(0, r * 0.72), c + Vector2(-r * 0.62, r * 0.05)]), 3)
	Art.flat(ci, inner, Color("f59e0b") if reached else Color("5a6488"))
	Art.text(ci, c + Vector2(0, r * 0.3), str(n), int(r * 0.92), Art.WHITE, maxi(3, int(r * 0.22)))


# --- Background -------------------------------------------------------------------------------

func _draw_bg(ci: CanvasItem, s: Vector2, tt: float) -> void:
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("3a1f8f"), Color("3a1f8f"), Color("0b1f5c"), Color("0b1f5c")]))
	# Light rays from the top.
	for i in 5:
		var x := s.x * (0.1 + i * 0.22)
		var sway := snappedf(sin(tt * 0.4 + i) * 20.0, 4.0)
		Art.grad(ci, PackedVector2Array([Vector2(x - 30 + sway, 0), Vector2(x + 30 + sway, 0), Vector2(x + 140, s.y * 0.8), Vector2(x - 40, s.y * 0.8)]),
			PackedColorArray([Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	# Bubbles rising.
	for i in 14:
		var bx := fposmod(i * 97.0, s.x)
		var by := s.y - fposmod(snappedf(tt * (24.0 + i * 3.0), 2.0) + i * 131.0, s.y + 40.0)
		Art.ring(ci, Art.circle_pts(Vector2(bx, by), 4.0 + i % 4 * 2.0, 12), Color(1, 1, 1, 0.25), 2.0)


# --- Taking rewards ------------------------------------------------------------------------

func _tap(row: String, lv: int, box: Control) -> void:
	if BattlePass.ready(row, lv):
		var got := BattlePass.claim(row, lv)
		_celebrate(got, box.get_global_rect().get_center())
		_rebuild()
	elif row == "b" and not BattlePass.bonus_open():
		Sfx.play("deny")
		main._show_toast(t("BP_BONUS_LOCKED") % [mini(BattlePass.challenges_done(), BattlePass.BONUS_NEED), BattlePass.BONUS_NEED])
	elif lv > BattlePass.level():
		Sfx.play("deny")
		main._show_toast(t("BP_NEED_LEVEL") % lv)


func _take_everything() -> void:
	var got := BattlePass.claim_all()
	if got.is_empty():
		Sfx.play("deny")
		return
	_celebrate(got, _take_all.get_global_rect().get_center())
	_rebuild()


func _celebrate(got: Dictionary, from: Vector2) -> void:
	if got.is_empty():
		return
	Sfx.play("unlock")
	main.celebrate({"coins": float(got["coins"]), "pearls": int(got["pearls"]), "boost": int(got["boost"]) / 60}, from)
	for id in got["items"]:
		main._show_toast(t("BP_GOT_ITEM") % t("ITEM_" + str(id).to_upper()))
	if got.has("chapter"):
		main._show_toast(t("BP_NEW_CHAPTER") % int(got["chapter"]))


func _rebuild() -> void:
	var keep := _track.scroll_horizontal
	_fill_track()
	_refresh_take()
	_level_view.queue_redraw()
	(func(): _track.scroll_horizontal = keep).call_deferred()


func _fit_cards() -> void:
	var h := clampf((_track.size.y - NODE_H - 24.0) / 2.0, 150.0, 270.0)
	if absf(h - CARD_H) < 6.0:
		return
	CARD_H = h
	COL_W = roundf(h * 0.8)
	_rebuild()
	(func(): _scroll_to_level()).call_deferred()


func _refresh_take() -> void:
	var n := BattlePass.waiting()
	_take_all.text = t("BP_TAKE") % n if n > 0 else t("BP_NOTHING")
	_take_all.theme_type_variation = &"GoldButton" if n > 0 else &"DarkButton"


func _scroll_to_level() -> void:
	if not is_inside_tree():
		return
	var target := 92.0 + (maxi(1, BattlePass.level()) - 1) * COL_W - _track.size.x * 0.35
	_track.scroll_horizontal = int(maxf(0.0, target))


## Mouse drag and the wheel move the track sideways (touch drags work on
## their own).
func _on_track_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] and e.pressed:
			_track.scroll_horizontal += 90
		elif e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] and e.pressed:
			_track.scroll_horizontal -= 90
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = e.position.x if e.pressed else -1.0
			_drag_scroll = _track.scroll_horizontal
	elif e is InputEventMouseMotion and _drag_from >= 0.0 and e.button_mask & MOUSE_BUTTON_MASK_LEFT \
			and not DisplayServer.is_touchscreen_available():
		_track.scroll_horizontal = int(_drag_scroll - (e.position.x - _drag_from))
