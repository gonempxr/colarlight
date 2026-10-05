class_name OfficeBar
extends PanelContainer
## The office's buttons: the accountant (hire him: he collects the vault by
## himself), the workers' evolution, the player's outfits and the room's
## decor. Phone: one row of four picture buttons under the office room.
## PC (`full`): a cream side card with the vault (amount and Collect) on
## top and the four buttons in a 2 x 2 grid.

signal evolution_pressed
signal outfits_pressed
signal decor_pressed
## The Collect button (PC card): amount and the global point it flew from.
signal collect_pressed(from: Vector2)

var full := false
var _acct: ArtButton
var _evo: ArtButton
var _outfit: ArtButton
var _decor: ArtButton
var _vault_label: Label
var _collect: PriceButton
var _desc: Label
var _check_left := 0.0
var _sig := []
static var _sofa_box := Rect2()


func _ready() -> void:
	theme_type_variation = &"CardPanel" if full else &"PanelContainer"
	if not full:
		var sb := ToonBox.make(Color("1f3f73"), 26, 0)
		sb.gloss = 0.0
		sb.shadow = 0.0
		sb.line_w = 4.0
		sb.set_content_margin_all(10)
		add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var pic := 150.0 if full else 70.0
	_acct = ArtButton.make(tr("ACCOUNTANT"), &"CreamButton", _draw_acct, pic)
	_evo = ArtButton.make(tr("EVO_BOARD"), &"PurpleButton", _draw_evo, pic)
	_outfit = ArtButton.make(tr("TAB_OUTFITS"), &"BlueButton", _draw_outfit, pic)
	_decor = ArtButton.make(tr("DECOR"), &"GoldButton", _draw_decor, pic)
	_acct.pressed.connect(_on_acct)
	_evo.pressed.connect(func(): Sfx.play("click"); evolution_pressed.emit())
	_outfit.pressed.connect(func(): Sfx.play("click"); outfits_pressed.emit())
	_decor.pressed.connect(func(): Sfx.play("click"); decor_pressed.emit())
	if full:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		head.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, t: float):
			Art.push(ci, s / 2.0, 0.0, Vector2(1.6, 1.6))
			RoomTabs.draw_icon(ci, 2, t * 0.3)
			Art.pop(ci), Vector2(90, 90), true))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		head.add_child(v)
		var name := Views.label(tr("VAULT"), 26, Art.INK, true)
		v.add_child(name)
		_vault_label = Views.label("", 22, Art.GOLD_DARK, true)
		v.add_child(_vault_label)
		_collect = PriceButton.new()
		_collect.custom_minimum_size = Vector2(0, 72)
		_collect.add_theme_font_size_override("font_size", 26)
		_collect.pressed.connect(func(): collect_pressed.emit(_collect.get_global_rect().get_center()))
		box.add_child(_collect)
		_desc = Views.label("", 18, Art.INK_SOFT)
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc.custom_minimum_size.x = 200
		box.add_child(_desc)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		box.add_child(grid)
		for b: ArtButton in [_acct, _evo, _outfit, _decor]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = pic + 44.0
			grid.add_child(b)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		for b: ArtButton in [_acct, _evo, _outfit, _decor]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(60, pic + 40.0)
			row.add_child(b)
	refresh()


func button(id: String) -> Control:
	match id:
		"vault", "accountant":
			return _acct
		"evo":
			return _evo
		"outfit":
			return _outfit
		"decor":
			return _decor
		"collect":
			return _collect
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sig = []
		refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0 and is_visible_in_tree():
		_check_left = 0.2
		refresh()


func refresh() -> void:
	if _acct == null:
		return
	var gs := GameState
	var hired: bool = gs.has_manager("vault")
	var cost: float = gs.manager_cost("vault")
	var can_evo: bool = gs.can_buy_evo()
	var cheapest := 0
	for slot in Content.DECOR_SLOTS:
		var c := Progress.decor_cost(slot)
		if c > 0 and (cheapest == 0 or c < cheapest):
			cheapest = c
	var decor_ready := cheapest > 0 and Progress.pearls >= cheapest
	var sig := [hired, gs.coins >= cost, can_evo, decor_ready, gs.evo, Progress.equipped.get("outfit", ""),
			NumFormat.short(gs.vault), NumFormat.short(cost), TranslationServer.get_locale()]
	if sig == _sig:
		return
	_sig = sig
	_acct.text = tr("ACCOUNTANT")
	_evo.text = tr("EVO_BOARD")
	_outfit.text = tr("TAB_OUTFITS")
	_decor.text = tr("DECOR")
	_acct.set_variation(&"CreamButton" if hired else (&"GoldButton" if gs.coins >= cost else &"DarkButton"))
	_acct.tooltip_text = tr("ACCOUNTANT_DESC")
	_evo.set_badge("!" if can_evo else "")
	_decor.set_badge("!" if decor_ready and _no_decor_yet() else "")
	for b: ArtButton in [_acct, _evo, _outfit, _decor]:
		b.fit_text(19)
	if full:
		var v: float = gs.vault
		_vault_label.text = NumFormat.short(v) if v >= 1.0 else tr("VAULT_EMPTY")
		_collect.set_price(tr("VAULT_COLLECT"), NumFormat.short(v) if v >= 1.0 else "", "coin")
		_collect.theme_type_variation = &"GoldButton" if v >= 1.0 else &"DarkButton"
		_collect.visible = not hired or v >= 1.0
		_desc.text = tr("ACCOUNTANT_WORKS") if hired else tr("VAULT_HOW")


static func _no_decor_yet() -> bool:
	for slot in Content.DECOR_SLOTS:
		if Progress.decor_level(slot) > 0:
			return false
	return true


func _on_acct() -> void:
	var gs := GameState
	if gs.has_manager("vault"):
		Sfx.play("pop")
		_toast(tr("ACCOUNTANT_WORKS"))
		return
	if gs.hire_manager("vault"):
		Sfx.play("hire")
		Sfx.voice("yay", 1.1)
		_toast(tr("ACCOUNTANT_HIRED"))
	else:
		Sfx.play("deny")
		_toast(tr("ACCOUNTANT_SAVE") % NumFormat.short(gs.manager_cost("vault")))
	_sig = []
	refresh()


func _toast(s: String) -> void:
	var n := get_parent()
	while n and not n.has_method("_show_toast"):
		n = n.get_parent()
	if n:
		n._show_toast(s)


# --- Pictures ---------------------------------------------------------------------------

func _draw_acct(ci: CanvasItem, s: Vector2, t: float) -> void:
	var hired: bool = GameState.has_manager("vault")
	var r := minf(s.y * 0.5 - 4.0, s.x * 0.4)
	var c := Vector2(s.x / 2.0, s.y / 2.0 - (6.0 if not hired else 0.0))
	Chars.portrait(ci, c, r, Chars.manager_look("vault"), "happy" if hired else "focus", Chars.blinking(t, 3.0), Color("e6d2ff"))
	if hired:
		Art.t_circle(ci, c + Vector2(r * 0.75, r * 0.7), 11.0, Art.GREEN, 2.5, 0.0)
		Art.polyline(ci, PackedVector2Array([c + Vector2(r * 0.75 - 5, r * 0.7), c + Vector2(r * 0.75 - 1, r * 0.7 + 4), c + Vector2(r * 0.75 + 6, r * 0.7 - 4)]), Art.WHITE, 3.0)
	else:
		# The price on a tag under the face.
		var txt := NumFormat.short(GameState.manager_cost("vault"))
		var font := UiTheme.heavy_font()
		var fs := 17
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tag := Rect2(Vector2(s.x / 2.0 - (tw + 30.0) / 2.0, s.y - 22.0), Vector2(tw + 30.0, 22.0))
		Art.t_rect(ci, tag, 11.0, Art.INK, 0.0, 0.0)
		Art.coin(ci, tag.position + Vector2(11, 11), 8.0)
		Art.text(ci, tag.position + Vector2(22, 17), txt, fs, Art.GOLD if GameState.coins >= GameState.manager_cost("vault") else Art.WHITE, 0, false)


func _draw_evo(ci: CanvasItem, s: Vector2, t: float) -> void:
	var w: String = GameState.world_id()
	var e: int = GameState.evo
	Art.glow(ci, s / 2.0, s.y * 0.5, Color(WorkerLooks.rarity_color(e), 0.35))
	WorkerLooks.draw_card(ci, s / 2.0 + Vector2(0, 2), s.y, w, e, true, t)
	if e > 0:
		var tag := "+%d%%" % roundi((Balance.evo_mult(e) - 1.0) * 100.0)
		Art.text(ci, Vector2(s.x / 2.0 + s.y * 0.45, s.y - 6.0), tag, 18, Art.GOLD, 5)


func _draw_outfit(ci: CanvasItem, s: Vector2, _t: float) -> void:
	var o := str(Progress.equipped.get("outfit", ""))
	if o == "":
		o = "outfit_casual"
	Chars.outfit_icon(ci, s / 2.0, s.y, o)


func _draw_decor(ci: CanvasItem, s: Vector2, _t: float) -> void:
	if _sofa_box.size == Vector2.ZERO:
		Art.measure_begin()
		OfficeArt.sofa(null, 2)
		_sofa_box = Art.measure_end()
	var lv := Progress.decor_level("sofa")
	var sc := minf((s.x - 8.0) / _sofa_box.size.x, (s.y - 4.0) / _sofa_box.size.y)
	Art.push(ci, s / 2.0 - _sofa_box.get_center() * sc, 0.0, Vector2(sc, sc))
	OfficeArt.sofa(ci, maxi(lv, 2))
	Art.pop(ci)
