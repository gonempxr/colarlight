class_name MapView
extends Control
## Full-screen world map: the floating islands of every location joined by
## one route. Past islands carry a flag, the current one is lit with its
## mine, factory and office and the boats sailing in step with the real
## boat trip, the next one is a dark silhouette with a "?" and the gate
## panel beside it: the goals as a checklist, the price and the big
## "Open <world>" button (with a confirm step inside the view).
##
## Phone portrait: islands zigzag down, the panel sits at the bottom.
## Landscape and PC: islands in a row, the panel on the right. The map pans
## by dragging (and the mouse wheel) when it does not fit.
##
## Reads GameState through has_method/get so it also runs before the
## location API exists; MapView.demo (a Dictionary) overrides every value
## for preview sheets.

signal closed
signal location_opened(location: int)

const TITLE_H := 110.0
const PANEL_W := 600.0
const GAP_X := 470.0
const ZIG_Y := 60.0
const GAP_Y := 470.0
const ZIG_X := 55.0
const DRAG_MIN := 14.0
const HINT_SEC := 3.2

## Test override: "location", "goals", "cost", "coins", "can", "boat",
## "boat2" (cycle progress, -2 = no second boat). Empty = live GameState.
static var demo: Dictionary = {}

var _canvas: Canvas
var _title: Label
var _x: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _wide := false
var _area := Rect2()
var _zoom := 1.0
var _pan := Vector2.ZERO
var _first := 0
var _last := 3
var _pos := {}
var _bounds := Rect2()
var _t := 0.0
var _redraw_left := 0.0
var _confirm := false
var _panel_sig := -1
var _check_left := 0.0
var _drag_from := Vector2.ZERO
var _drag_pan := Vector2.ZERO
var _dragging := false
var _pressed := false
var _hint_loc := -1
var _hint_left := 0.0
var _pan_tween: Tween
## Frames left to fit the panel again (wrapped labels know their height
## only after a layout pass).
var _refit := 0


class Canvas extends Control:
	var view: MapView

	func _draw() -> void:
		view._paint(self)

	func _gui_input(event: InputEvent) -> void:
		view._canvas_input(event)


# --- Game data (guarded) -----------------------------------------------------------------

static func _gs() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") if tree else null


static func cur_location() -> int:
	if demo.has("location"):
		return int(demo["location"])
	var gs := _gs()
	if gs:
		var l = gs.get("location")
		if l != null:
			return int(l)
	return 0


static func world_of(location: int) -> String:
	return MapArt.world_of(location)


static func tier_of(location: int) -> int:
	return maxi(0, location) / MapArt.WORLDS.size()


static func world_name(location: int, with_star: bool = true) -> String:
	var w := world_of(location).to_upper()
	var key := "WORLD_" + w
	var s := TranslationServer.translate(key)
	if s == key or s == "":
		s = TranslationServer.translate("MAP_W_" + w)
	var tier := tier_of(location)
	if with_star and tier > 0:
		s += " ★%d" % (tier + 1)
	return s


static func goals() -> Array:
	if demo.has("goals"):
		return demo["goals"]
	var gs := _gs()
	if gs and gs.has_method("location_goals"):
		return gs.location_goals()
	# Before the location API: count what the current run has.
	var sites := 0
	var foremen := 0
	var mgr := 0
	if gs:
		for i in 10:
			if gs.has_method("is_open") and gs.is_open("d%d" % i):
				sites += 1
			if gs.has_method("has_manager") and gs.has_manager("d%d" % i):
				foremen += 1
		for k in ["lift", "boat", "plant", "boat2", "plant2"]:
			if gs.has_method("has_manager") and gs.has_manager(k):
				mgr += 1
	return [{"id": "sites", "have": sites, "need": 10}, {"id": "foremen", "have": foremen, "need": 10},
			{"id": "managers", "have": mgr, "need": 5}, {"id": "evo", "have": 0, "need": 12}]


static func location_ready() -> bool:
	if demo.has("goals"):
		for g in goals():
			if int(g["have"]) < int(g["need"]):
				return false
		return true
	var gs := _gs()
	if gs and gs.has_method("location_ready"):
		return gs.location_ready()
	for g in goals():
		if int(g["have"]) < int(g["need"]):
			return false
	return true


static func next_cost() -> float:
	if demo.has("cost"):
		return float(demo["cost"])
	var gs := _gs()
	if gs and gs.has_method("next_location_cost"):
		return float(gs.next_location_cost())
	if gs and gs.has_method("prestige_cost"):
		return float(gs.prestige_cost())
	return 1e7


static func coins() -> float:
	if demo.has("coins"):
		return float(demo["coins"])
	var gs := _gs()
	if gs:
		var c = gs.get("coins")
		if c != null:
			return float(c)
	return 0.0


static func can_advance() -> bool:
	if demo.has("can"):
		return bool(demo["can"])
	var gs := _gs()
	if gs and gs.has_method("can_advance_location"):
		return gs.can_advance_location()
	return location_ready() and coins() >= next_cost()


## Cycle progress of a boat (-1 idle, -2 not bought).
static func boat_progress(key: String) -> float:
	if demo.has(key):
		return float(demo[key])
	var gs := _gs()
	if gs == null or not gs.has_method("cycle_progress"):
		return -1.0
	if key == "boat2" and gs.has_method("is_open") and not gs.is_open("boat2"):
		return -2.0
	return float(gs.cycle_progress(key))


## Lit level nodes on the current island (4 nodes for the 10 sites).
static func lit_nodes() -> int:
	for g in goals():
		if g["id"] == "sites":
			return clampi(int(floor(float(g["have"]) / maxf(1.0, float(g["need"])) * 4.0 + 0.001)), 0, 4)
	return 0


static func _advance() -> bool:
	if demo.has("location"):
		demo["location"] = int(demo["location"]) + 1
		demo["can"] = false
		return true
	var gs := _gs()
	if gs and gs.has_method("advance_location"):
		return bool(gs.advance_location())
	push_warning("MapView: GameState.advance_location() is missing")
	return false


static func _sfx(name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := tree.root.get_node_or_null("Sfx") if tree else null
	if s and s.has_method("play"):
		s.play(name)


static func _reduce_motion() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var s := tree.root.get_node_or_null("Settings") if tree else null
	if s:
		var r = s.get("reduce_motion")
		return bool(r) if r != null else false
	return false


# --- Setup ------------------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas = Canvas.new()
	_canvas.view = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.heavy_font())
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_constant_override("outline_size", 12)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_x = Button.new()
	_x.theme_type_variation = &"RedButton"
	_x.icon = Icons.get_icon("close", 30)
	_x.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_x.custom_minimum_size = Vector2(72, 72)
	_x.pressed.connect(func(): _sfx("click"); close())
	add_child(_x)
	_panel = PanelContainer.new()
	var sb := UiTheme.panel_box(Art.CREAM, 26, 6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	get_viewport().size_changed.connect(_layout)
	var gs := _gs()
	if gs and gs.has_signal("location_changed"):
		gs.connect("location_changed", func(_l): if visible: refresh())
	refresh()


## Shows the map centred on the current location.
func open() -> void:
	visible = true
	_confirm = false
	refresh()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh() -> void:
	_title.text = TranslationServer.translate("MAP_TITLE")
	_place()
	_build_panel()
	_layout()
	_center_on(cur_location(), false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _confirm:
			_confirm = false
			_build_panel()
		else:
			close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_hint_left -= delta
	if _refit > 0:
		_refit -= 1
		_layout()
	else:
		_fit_panel()
	MapArt.still = _reduce_motion()
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 1.0 / 30.0
		_canvas.queue_redraw()
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.5
		if _sig() != _panel_sig:
			_build_panel()
			_layout()


# --- Layout -------------------------------------------------------------------------------------

## Which locations are shown and where (map units).
func _place() -> void:
	var cur := cur_location()
	_first = maxi(0, cur - 3)
	_last = maxi(cur + 2, _first + 3)
	_pos.clear()
	var view := get_viewport_rect().size
	_wide = view.x > view.y * 1.05
	_bounds = Rect2()
	for l in range(_first, _last + 1):
		var i := l - _first
		var p := Vector2(i * GAP_X, ZIG_Y * (0.5 if i % 2 == 1 else -0.5)) if _wide else Vector2(ZIG_X * (1.0 if i % 2 == 1 else -1.0), i * GAP_Y)
		_pos[l] = p
		var r := Rect2(MapArt.BOUNDS.position + p, MapArt.BOUNDS.size)
		_bounds = r if l == _first else _bounds.merge(r)
	_bounds = _bounds.grow(24.0)


func _layout() -> void:
	if not is_node_ready():
		return
	var view := get_viewport_rect().size
	var was_wide := _wide
	_wide = view.x > view.y * 1.05
	if was_wide != _wide:
		_place()
	_x.position = Vector2(view.x - 72 - 18, 18)
	_x.size = Vector2(72, 72)
	_title.position = Vector2(28, 22)
	if _wide:
		var pw := minf(PANEL_W, view.x * 0.42)
		_panel.position = Vector2(view.x - pw - 20, TITLE_H)
		_panel.custom_minimum_size = Vector2(pw, 0)
		var want := _box.get_combined_minimum_size().y + 44.0
		_panel.size = Vector2(pw, minf(want, view.y - TITLE_H - 20))
		_panel.size.x = pw
		_area = Rect2(0, TITLE_H * 0.6, view.x - pw - 30, view.y - TITLE_H * 0.6)
		_zoom = clampf(minf(_area.size.y / 640.0, _area.size.x / (GAP_X * 2.6)), 0.6, 1.3)
	else:
		var pw := view.x - 24.0
		_panel.custom_minimum_size = Vector2(pw, 0)
		var want := _box.get_combined_minimum_size().y + 44.0
		var ph := minf(want, view.y * 0.48)
		_panel.position = Vector2(12, view.y - ph - 12)
		_panel.size = Vector2(pw, ph)
		_area = Rect2(0, TITLE_H, view.x, view.y - ph - 12 - TITLE_H)
		_zoom = clampf(view.x / 640.0, 0.6, 1.4)
	_scroll.custom_minimum_size = Vector2(0, 0)
	_clamp_pan()


## Keeps the panel as tall as its content (wrapped labels settle late).
func _fit_panel() -> void:
	var view := get_viewport_rect().size
	var want := _box.get_combined_minimum_size().y + 44.0
	if _wide:
		var h := minf(want, view.y - TITLE_H - 20)
		if absf(_panel.size.y - h) > 1.0:
			_panel.size.y = h
	else:
		var h := minf(want, view.y * 0.48)
		if absf(_panel.size.y - h) > 1.0:
			_layout()


func _center_on(location: int, animate: bool) -> void:
	if not _pos.has(location):
		return
	var want: Vector2 = _area.get_center() - (_pos[location] as Vector2) * _zoom
	if _wide and (location != cur_location() or _pos.has(location + 1)):
		# Leave room for the next island too.
		var nxt: Vector2 = _pos.get(location + 1, _pos[location])
		want = _area.get_center() - ((_pos[location] as Vector2).lerp(nxt, 0.3)) * _zoom
	if animate:
		if _pan_tween:
			_pan_tween.kill()
		var from := _pan
		_pan_tween = create_tween()
		_pan_tween.tween_method(func(f: float):
			_pan = from.lerp(want, f)
			_clamp_pan(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_pan = want
		_clamp_pan()


func _clamp_pan() -> void:
	var lo := _area.position - _bounds.position * _zoom
	var hi := _area.end - _bounds.end * _zoom
	for ax in 2:
		if hi[ax] >= lo[ax]:
			_pan[ax] = (lo[ax] + hi[ax]) / 2.0
		else:
			_pan[ax] = clampf(_pan[ax], hi[ax], lo[ax])


# --- Input --------------------------------------------------------------------------------------

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
				_dragging = false
				_drag_from = mb.position
				_drag_pan = _pan
				if _pan_tween:
					_pan_tween.kill()
			else:
				if _pressed and not _dragging:
					_tap(mb.position)
				_pressed = false
				_dragging = false
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var d := 60.0 * (1.0 if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else -1.0)
			if _wide:
				_pan.x += d
			else:
				_pan.y += d
			_clamp_pan()
	elif event is InputEventMouseMotion and _pressed:
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_drag_from) > DRAG_MIN:
			_dragging = true
		if _dragging:
			_pan = _drag_pan + (mm.position - _drag_from)
			_clamp_pan()


func _tap(at: Vector2) -> void:
	var m := (at - _pan) / _zoom
	var cur := cur_location()
	for l in _pos:
		var d: Vector2 = (m - (_pos[l] as Vector2))
		if absf(d.x) < MapArt.RX and d.y > -MapArt.RY - 90.0 and d.y < 220.0:
			if l > cur:
				_hint_loc = l
				_hint_left = HINT_SEC
				_sfx("pop")
			return


# --- Panel ---------------------------------------------------------------------------------------

func _sig() -> int:
	return hash([cur_location(), goals(), can_advance(), int(next_cost()), _confirm, coins() >= next_cost(), TranslationServer.get_locale()])


static func t(key: String) -> String:
	return TranslationServer.translate(key)


func _label(text: String, px: int, color: Color = Art.INK, heavy: bool = false) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"InkLabel"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size.x = 80
	if heavy:
		l.add_theme_font_override("font", UiTheme.heavy_font())
	return l


func _icon(name: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Icons.get_icon(name, px)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_panel() -> void:
	_panel_sig = _sig()
	_refit = 3
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var cur := cur_location()
	var nxt := cur + 1
	var name := world_name(nxt)
	if _confirm:
		_box.add_child(_label(t("MAP_CONFIRM") % name, 32, Art.INK, true))
		_box.add_child(_carry())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var no := Button.new()
		no.theme_type_variation = &"CreamButton"
		no.text = t("MAP_NO")
		no.custom_minimum_size = Vector2(0, 84)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		no.pressed.connect(func():
			_sfx("click")
			_confirm = false
			_build_panel()
			_layout())
		row.add_child(no)
		var yes := Button.new()
		yes.theme_type_variation = &"GoldButton"
		yes.text = t("MAP_YES")
		yes.custom_minimum_size = Vector2(0, 84)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.size_flags_stretch_ratio = 1.4
		yes.add_theme_font_size_override("font_size", 30)
		yes.pressed.connect(_do_open)
		row.add_child(yes)
		_box.add_child(row)
		return
	# Header: what comes next, with a teaser.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var k := minf(s.x, s.y) / 470.0
		Art.push(ci, s / 2.0 + Vector2(0, 6), 0.0, Vector2(k, k))
		MapArt.island(ci, world_of(nxt), MapArt.NEXT, tt, tier_of(nxt))
		Art.pop(ci)
		MapArt.mystery(ci, s / 2.0 + Vector2(-4, 2), tt, false, 0.4), Vector2(96, 96))
	pic.custom_minimum_size = Vector2(96, 96)
	head.add_child(pic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	hv.add_child(_label(t("MAP_NEXT") % name, 30, Art.INK, true))
	hv.add_child(_label(t("MAP_HINT_" + world_of(nxt).to_upper()), 21, Art.INK_SOFT))
	head.add_child(hv)
	_box.add_child(head)
	# Goals.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for g in goals():
		list.add_child(_goal_row(g))
	_box.add_child(list)
	# Price and the button (side by side on a phone).
	var cost := next_cost()
	var have_coins := coins() >= cost
	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 8)
	var pl := _label(t("MAP_PRICE"), 22 if not _wide else 24, Art.INK, true)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_child(pl)
	price.add_child(_icon("coin", 34))
	var pv := _label(NumFormat.short(cost), 30, Art.INK if have_coins else Color("c0392b"), true)
	pv.autowrap_mode = TextServer.AUTOWRAP_OFF
	pv.custom_minimum_size.x = 0
	pv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_child(pv)
	if not have_coins:
		var hc := _label("(" + t("MAP_YOU_HAVE") % NumFormat.short(coins()) + ")", 19, Art.INK_SOFT)
		hc.autowrap_mode = TextServer.AUTOWRAP_OFF
		hc.custom_minimum_size.x = 0
		hc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_child(hc)
	_box.add_child(price)
	var go := Button.new()
	go.theme_type_variation = &"GoldButton"
	go.text = t("OPEN_WORLD") % name
	go.custom_minimum_size = Vector2(0, 92 if _wide else 84)
	go.add_theme_font_size_override("font_size", 32 if _wide else 30)
	go.disabled = not can_advance()
	go.pressed.connect(func():
		_sfx("click")
		_confirm = true
		_build_panel()
		_layout())
	_box.add_child(go)
	if go.disabled:
		var why := _label(t("MAP_GOALS_FIRST") if not location_ready() else t("MAP_NEED_COINS"), 20, Art.INK_SOFT)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(why)
	_box.add_child(_carry())


func _goal_row(g: Dictionary) -> Control:
	var have := int(g["have"])
	var need := int(g["need"])
	var ok := have >= need
	var card := PanelContainer.new()
	var sb := UiTheme.panel_box(Color("dff7d2") if ok else Color("fffaf0"), 16, 3)
	sb.shadow = 0.0
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 6 if _wide else 3
	sb.content_margin_bottom = 9 if _wide else 6
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var box := ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float):
		var c := s / 2.0
		Art.t_circle(ci, c, 15, Art.GREEN if ok else Color("e9e2d2"), 3.0, 0.4)
		if ok:
			Art.polyline(ci, PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 6), c + Vector2(8, -6)]), Art.WHITE, 4.5), Vector2(38, 38))
	h.add_child(box)
	var l := _label(t("MAP_GOAL_" + String(g["id"]).to_upper()), 23 if _wide else 21, Art.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var n := _label("%d/%d" % [mini(have, need), need], 24, Art.GREEN_DARK if ok else Art.INK, true)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.custom_minimum_size.x = 0
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	return card


## What stays and what starts over, in kid words.
func _carry() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for row in [["check", "MAP_KEEP", Art.GREEN_DARK], ["arrow", "MAP_RESET", Color("c56a1c")]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := _icon(row[0], 28)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		var l := _label(t(row[1]), 20 if _wide else 18, row[2])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	return v


func _do_open() -> void:
	if not can_advance():
		_sfx("deny")
		_confirm = false
		_build_panel()
		return
	var before := cur_location()
	if _advance():
		_sfx("unlock")
		var now := cur_location()
		if now == before:
			now = before + 1
		_confirm = false
		_place()
		_build_panel()
		_layout()
		_center_on(now, true)
		location_opened.emit(now)
	else:
		_sfx("deny")


# --- Drawing ----------------------------------------------------------------------------------

func _state(l: int, cur: int) -> int:
	if l < cur:
		return MapArt.DONE
	if l == cur:
		return MapArt.CURRENT
	if l == cur + 1:
		return MapArt.NEXT
	return MapArt.LOCKED


## Where the route enters and leaves island `l` (local): the tips of its
## front edge. Phones snake down: every other island runs right to left.
func _ends(l: int) -> Array:
	var tip := Vector2(MapArt.RX * 0.93, 34)
	var flip := not _wide and (l - _first) % 2 == 1
	return [Vector2(tip.x, tip.y), Vector2(-tip.x, tip.y)] if flip else [Vector2(-tip.x, tip.y), tip]


func _paint(ci: CanvasItem) -> void:
	var s: Vector2 = (ci as Control).size
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([Color("3fa9ec"), Color("3fa9ec"), Color("bfe9ff"), Color("bfe9ff")]))
	var cur := cur_location()
	var tm := _t
	Art.push(ci, _pan, 0.0, Vector2(_zoom, _zoom))
	var i := 0
	for l in range(_first, _last + 1):
		var p: Vector2 = _pos[l]
		MapArt.cloud(ci, p + Vector2(-150, 300 if _wide else 230), 1.2, 3 + i)
		MapArt.cloud(ci, p + Vector2(160, -230 if _wide else 120), 0.9, 7 + i)
		if world_of(l) == "moon" and _state(l, cur) <= MapArt.CURRENT:
			MapArt.space(ci, p + Vector2(0, -10), 300.0, tm)
		i += 1
	# Bridges first: the island tops cover their ends.
	for l in range(_first, _last):
		var a: Vector2 = _pos[l]
		var b: Vector2 = _pos[l + 1]
		var lit := l + 1 <= cur
		var glowing := world_of(l) == "moon" or world_of(l + 1) == "moon"
		MapArt.bridge(ci, a + (_ends(l)[1] as Vector2), b + (_ends(l + 1)[0] as Vector2), lit, glowing, tm)
	for l in range(_first, _last + 1):
		var p: Vector2 = _pos[l]
		var st := _state(l, cur)
		var w := world_of(l)
		if st == MapArt.CURRENT:
			Art.glow(ci, p + Vector2(0, 20), 300, Color(1.0, 0.95, 0.6, 0.45))
		Art.push(ci, p)
		MapArt.island(ci, w, st, tm + l * 1.3, tier_of(l))
		if st == MapArt.DONE or st == MapArt.CURRENT:
			var ends := _ends(l)
			MapArt.path(ci, w, ends[0], ends[1], true)
			MapArt.nodes(ci, w, 4 if st == MapArt.DONE else lit_nodes())
		if st == MapArt.CURRENT:
			var p2 := boat_progress("boat2")
			if p2 > -1.5:
				var b2 := MapArt.boat_at(w, p2, 10.0)
				MapArt.boat(ci, Vector2(b2.x, b2.y), b2.z, w, p2 >= MapArt.LOAD_END and p2 < MapArt.UNLOAD_END, tm, true)
			var p1 := boat_progress("boat")
			var b1 := MapArt.boat_at(w, p1)
			MapArt.boat(ci, Vector2(b1.x, b1.y), b1.z, w, p1 >= MapArt.LOAD_END and p1 < MapArt.UNLOAD_END, tm)
			MapArt.markers(ci, w, tm)
		elif st == MapArt.DONE:
			MapArt.done_mark(ci, w, tm)
		else:
			MapArt.mystery(ci, Vector2(0, -10), tm, st == MapArt.NEXT)
		var label := world_name(l, false) if st != MapArt.LOCKED else "???"
		MapArt.plate(ci, Vector2(0, 150), label, st, tier_of(l), 28)
		Art.pop(ci)
	if _hint_left > 0.0 and _pos.has(_hint_loc):
		_hint_bubble(ci, (_pos[_hint_loc] as Vector2) + Vector2(0, -150), _hint_loc == cur + 1)
	Art.pop(ci)
	# Sky band behind the title, so the map scrolls away under it.
	var top := Color("3fa9ec")
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, TITLE_H * 0.7), Vector2(0, TITLE_H * 0.7)]),
			PackedColorArray([top, top, Color(top, 0.85), Color(top, 0.85)]))
	Art.grad(ci, PackedVector2Array([Vector2(0, TITLE_H * 0.7), Vector2(s.x, TITLE_H * 0.7), Vector2(s.x, TITLE_H * 1.1), Vector2(0, TITLE_H * 1.1)]),
			PackedColorArray([Color(top, 0.85), Color(top, 0.85), Color(top, 0.0), Color(top, 0.0)]))


func _hint_bubble(ci: CanvasItem, at: Vector2, is_next: bool) -> void:
	var s := t("MAP_HINT_" + world_of(_hint_loc).to_upper()) if is_next else t("MAP_LOCKED_FAR")
	var font := UiTheme.body_font()
	var size := 24
	while size > 15 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 480.0:
		size -= 1
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 40.0
	var r := Rect2(at.x - w / 2.0, at.y - 36, w, 52)
	Art.toon(ci, PackedVector2Array([at + Vector2(-12, 14), at + Vector2(12, 14), at + Vector2(0, 32)]), Art.WHITE, 3.0, 0.0)
	Art.t_rect(ci, r, 22, Art.WHITE, 3.0, 0.3)
	Art.text(ci, Vector2(at.x, at.y - 1), s, size, Art.INK, 0, true, font)
