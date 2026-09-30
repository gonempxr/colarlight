class_name Dock
extends PanelContainer
## Row of big round feature buttons (gift, quests, puzzle, museum, wardrobe).
## A button shows up when Progress opens its feature, wiggles with a NEW
## badge until first pressed, and carries a counter when something waits.

signal pressed(id: String)

const ITEMS := [
	["daily", "gift", "DOCK_DAILY", "RedButton"],
	["quests", "quests", "DOCK_QUESTS", "BlueButton"],
	["puzzle", "puzzle", "DOCK_PUZZLE", "PurpleButton"],
	["museum", "museum", "DOCK_MUSEUM", "GoldButton"],
	["shop", "wardrobe", "DOCK_SHOP", "Button"],
	["fishing", "fishing", "DOCK_FISHING", "BlueButton"],
]
const BUTTON_H := 104.0

var _row: HBoxContainer
var _buttons := {}
var _badges := {}
var _t := 0.0
var _fit_w := 0.0


func _ready() -> void:
	var sb := ToonBox.make(Color("1f3f73"), 28, 0)
	sb.open_bottom = true
	sb.gloss = 0.0
	sb.shadow = 0.0
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	for it in ITEMS:
		var b := Button.new()
		b.theme_type_variation = StringName(it[3])
		b.icon = Icons.get_icon(it[1], 54)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("outline_size", 6)
		b.custom_minimum_size = Vector2(118, BUTTON_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var id: String = it[0]
		b.pressed.connect(func():
			Sfx.play("click")
			Progress.seen(id)
			pressed.emit(id))
		_row.add_child(b)
		# Slimmer side padding than normal buttons so labels fit narrow docks.
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box := b.get_theme_stylebox(st, StringName(it[3]))
			if box:
				box = _copy_box(box)
				box.content_margin_left = 6
				box.content_margin_right = 6
				b.add_theme_stylebox_override(st, box)
		_buttons[id] = b
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_override("font", UiTheme.heavy_font())
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_constant_override("outline_size", 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bsb := ToonBox.make(Art.RED, 16, 0)
		bsb.line_w = 3.0
		bsb.gloss = 0.2
		bsb.content_margin_left = 8
		bsb.content_margin_right = 8
		badge.add_theme_stylebox_override("normal", bsb)
		b.add_child(badge)
		_badges[id] = badge
	Progress.changed.connect(refresh)
	refresh()


## duplicate() drops a script's plain vars (ToonBox colours), so copy them.
static func _copy_box(src: StyleBox) -> StyleBox:
	var dst: StyleBox = src.duplicate()
	for p in src.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			dst.set(p["name"], src.get(p["name"]))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		dst.set_content_margin(side, src.get_content_margin(side))
	return dst


## Number of buttons showing (the dock hides itself when there are none).
func count() -> int:
	var n := 0
	for id in _buttons:
		if _buttons[id].visible:
			n += 1
	return n


## Shrinks the buttons so every one fits in the given width (the PC side
## column is narrower than a phone screen).
func fit(width: float) -> void:
	_fit_w = width
	var n := maxi(1, count())
	var w := floorf(minf(118.0, (width - 20.0 - 8.0 * (n - 1)) / n))
	for id in _buttons:
		var b: Button = _buttons[id]
		b.custom_minimum_size.x = w
		b.add_theme_font_size_override("font_size", 19 if w >= 110.0 else (15 if w >= 84.0 else 13))


func button(id: String) -> Button:
	return _buttons.get(id)


func refresh() -> void:
	for it in ITEMS:
		var id: String = it[0]
		var b: Button = _buttons[id]
		b.visible = Progress.has_feature(id)
		b.text = tr(it[2])
		var badge: Label = _badges[id]
		var n := 0
		match id:
			"daily":
				n = 1 if Progress.daily_ready() else 0
			"quests":
				n = Progress.quests_ready()
		if Progress.fresh.has(id):
			badge.text = tr("NEW")
			(badge.get_theme_stylebox("normal") as ToonBox).fill = Art.GOLD
			badge.add_theme_color_override("font_color", Art.INK)
		elif n > 0:
			badge.text = "!" if id == "daily" else str(n)
			(badge.get_theme_stylebox("normal") as ToonBox).fill = Art.RED
			badge.add_theme_color_override("font_color", Art.WHITE)
		badge.visible = Progress.fresh.has(id) or n > 0
		badge.reset_size()
	visible = count() > 0
	if _fit_w > 0.0:
		fit(_fit_w)


func _process(delta: float) -> void:
	_t += delta
	for id in _buttons:
		var b: Button = _buttons[id]
		if not b.visible:
			continue
		var badge: Label = _badges[id]
		badge.position = Vector2(b.size.x - badge.size.x + 6, -10)
		b.pivot_offset = b.size / 2.0
		var wiggle: bool = Progress.fresh.has(id) or (id == "daily" and Progress.daily_ready())
		if wiggle and not Settings.reduce_motion:
			b.rotation = sin(_t * 9.0) * 0.06 * maxf(0.0, sin(_t * 1.6))
			b.scale = Vector2.ONE * (1.0 + 0.04 * maxf(0.0, sin(_t * 3.2)))
		else:
			b.rotation = 0.0
			b.scale = Vector2.ONE
