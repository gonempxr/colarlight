class_name DiveScreen
extends Control
## A dive of the Atlas (Atlas.dive): the air bar and depth on top, then
## either the chambers to pick from, a fight, or the result with the loot.
## Fight: a ring shrinks onto a glowing weak spot; tap while it is on the
## spot (Atlas.tap_window) for a hit, else lose air. A ring that runs out
## is a miss too. Opened over the AtlasScreen.

## Where on its run (0..1) the ring sits on the weak spot.
const SPOT_AT := 0.7
const RING_R := 120.0

var main: Node
var _body: VBoxContainer
var _air: Control
var _fight: Control
var _t := 0.0
## Fight timing: time on the current ring, a short pause after a tap.
var _ring_t := 0.0
var _pause := 0.0
var _spot := Vector2.ZERO
var _flash := 0.0
var _flash_hit := false
var _rng := RandomNumberGenerator.new()


static func t(key: String) -> String:
	return TranslationServer.translate(key)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	var bg := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): _draw_bg(ci, s, tt), Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)
	_air = ArtView.make(func(ci: CanvasItem, s: Vector2, _tt: float): _draw_air(ci, s), Vector2(0, 96))
	col.add_child(_air)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	Atlas.dive_changed.connect(_on_dive_changed)
	Sfx.play("dive")
	_build()


func _on_dive_changed() -> void:
	if not is_inside_tree():
		return
	_air.queue_redraw()
	# A fight keeps its view; anything else is rebuilt.
	if Atlas.dive.is_empty() or Atlas.dive["fight"].is_empty() or not is_instance_valid(_fight):
		_build.call_deferred()


func _draw_bg(ci: CanvasItem, s: Vector2, tt: float) -> void:
	AtlasArt.draw_bg(ci, s, tt)
	# Darker the deeper the crew goes.
	var layer := float(Atlas.dive.get("layer", 0)) / maxf(1.0, float(Atlas.dive.get("layers", 4)))
	Art.flat(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), Color(0, 0, 0.05, snappedf(0.3 * layer, 0.05)))


# --- Air and depth --------------------------------------------------------------------

func _draw_air(ci: CanvasItem, s: Vector2) -> void:
	if Atlas.dive.is_empty():
		return
	var r := Rect2(Vector2(0, 4), s - Vector2(0, 8))
	Art.t_rect(ci, r, 22.0, Color(0.04, 0.08, 0.25, 0.8), 3.0, 0.0)
	var o2 := float(Atlas.dive["o2"])
	var mx := Atlas.max_oxygen()
	Art.text(ci, Vector2(s.x / 2.0, 34), "%s  ·  %s" % [AtlasScreen.node_name(str(Atlas.dive["node"])),
		t("ATLAS_LAYER") % [mini(int(Atlas.dive["layer"]) + 1, int(Atlas.dive["layers"]) + 1), int(Atlas.dive["layers"]) + 1]], 20, Color("bff4ff"), 6)
	var bar := Rect2(18, 48, s.x - 36, 32)
	Art.t_rect(ci, bar, 16.0, Color("0d1840"), 3.0, 0.0)
	var f := clampf(o2 / mx, 0.0, 1.0)
	if f > 0.01:
		var col := Color("5ee0ff") if f > 0.5 else (Color("ffd23f") if f > 0.25 else Color("ff5a5a"))
		Art.t_rect(ci, Rect2(bar.position, Vector2(maxf(32.0, bar.size.x * f), bar.size.y)), 16.0, col, 3.0, 0.5)
	Art.text(ci, bar.get_center() + Vector2(0, 8), "%s %d / %d" % [t("ATLAS_O2"), roundi(o2), roundi(mx)], 19, Art.WHITE, 6)


# --- Body -----------------------------------------------------------------------------

func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	_fight = null
	if Atlas.dive.is_empty():
		queue_free()
		return
	if Atlas.dive["done"] != "":
		_result()
	elif not Atlas.dive["fight"].is_empty():
		_start_fight()
	else:
		_chambers()


func _chambers() -> void:
	var l := Views.label(t("ATLAS_PICK"), 26, Color("ffe08a"), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(l)
	var opts: Array = Atlas.dive["options"]
	# The crew in the cave, the depth track beside them.
	var scene := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		AtlasArt.draw_cave(ci, s, tt, int(Atlas.dive["layer"]), int(Atlas.dive["layers"]) + 1), Vector2(0, 120), true)
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scene)
	for i in opts.size():
		var kind: String = opts[i]
		var card := Button.new()
		card.theme_type_variation = &"CreamButton"
		card.custom_minimum_size = Vector2(0, 116)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -12
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(h)
		var icon := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			var rr := minf(s.x, s.y) / 2.0 - 4.0
			Art.glow(ci, s / 2.0, rr * 1.15, Color(AtlasArt.SONAR, 0.25))
			Art.t_circle(ci, s / 2.0, rr, Color("142a6b"), 3.0, 0.0)
			AtlasArt.draw_chamber(ci, s / 2.0, rr * 0.75, kind, tt), Vector2(96, 96), true)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.custom_minimum_size = Vector2(100, 100)
		h.add_child(icon)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := t("ATLAS_K_" + kind.to_upper())
		if kind == "bounty":
			name += " " + t("ATLAS_B_" + str(Atlas.dive["bounty"]).to_upper())
		var nl := Views.label(name, 24, Art.INK, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		var dl := Views.label(t("ATLAS_KD_" + kind.to_upper()), 18, Art.INK_SOFT)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dl.custom_minimum_size.x = 120
		v.add_child(dl)
		h.add_child(v)
		card.pressed.connect(func(): _enter(i))
		_body.add_child(card)
	var up := Button.new()
	up.text = t("ATLAS_GIVE_UP")
	up.theme_type_variation = &"RedButton"
	up.custom_minimum_size = Vector2(0, 64)
	up.tooltip_text = t("ATLAS_GIVE_UP_HINT")
	var armed := [false]
	up.pressed.connect(func():
		if armed[0]:
			Atlas.dive["done"] = "fail"
			_build()
		else:
			armed[0] = true
			Sfx.play("deny")
			up.text = t("ATLAS_GIVE_UP_HINT"))
	_body.add_child(up)


func _enter(i: int) -> void:
	var r := Atlas.choose(i)
	if r.is_empty():
		return
	var d := roundi(float(r["o2"]))
	var line := ""
	if r.has("became"):
		line = t("ATLAS_K_MYSTERY") + " → " + t("ATLAS_K_" + str(r["became"]).to_upper()) + "  "
	if d != 0:
		line += "%s %s%d" % [t("ATLAS_O2"), "+" if d > 0 else "−", absi(d)]
	Sfx.play("chest" if r.get("became", r["kind"]) == "treasure" else ("pop" if d >= 0 else "dive"))
	if line != "" and main:
		main._show_toast(line)


# --- Fight ----------------------------------------------------------------------------

func _start_fight() -> void:
	var f: Dictionary = Atlas.dive["fight"]
	var kind: String = f["kind"]
	var name := t("ATLAS_K_" + kind.to_upper())
	if kind == "bounty":
		name = t("ATLAS_B_" + str(Atlas.dive["bounty"]).to_upper())
	elif kind == "boss" and Atlas.NODES[str(Atlas.dive["node"])].get("citadel", false):
		name = t("ATLAS_CITADEL")
	var l := Views.label(name, 26, Color("ff9bb0") if kind != "monster" else Color("ffe08a"), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(l)
	_fight = Control.new()
	_fight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fight.mouse_filter = Control.MOUSE_FILTER_STOP
	_fight.draw.connect(_draw_fight)
	_fight.gui_input.connect(_on_fight_input)
	_body.add_child(_fight)
	var hint := Views.label(t("ATLAS_TAP_HINT"), 19, Color("dfe4ff"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(hint)
	_ring_t = 0.0
	_pause = 0.6
	_new_spot()


func _cycle() -> float:
	var tier := int(Atlas.dive.get("tier", 1))
	var d := maxf(0.75, 1.3 - 0.06 * tier)
	if str(Atlas.dive.get("fight", {}).get("kind", "")) in ["boss", "bounty"]:
		d *= 0.9
	return d


func _new_spot() -> void:
	var a := _rng.randf() * TAU
	_spot = Vector2(cos(a), sin(a)) * _rng.randf_range(10.0, 46.0)


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_fight):
		return
	_flash = maxf(0.0, _flash - delta)
	if _pause > 0.0:
		_pause -= delta
	else:
		_ring_t += delta
		# The ring ran past the spot and out: a miss.
		if _ring_t >= _cycle():
			_judge(false)
	_fight.queue_redraw()


func _on_fight_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap or _pause > 0.0:
		return
	_fight.accept_event()
	var u := _ring_t / _cycle()
	_judge(absf(u - SPOT_AT) <= Atlas.tap_window() / 2.0)


func _judge(hit: bool) -> void:
	_flash = 0.35
	_flash_hit = hit
	_ring_t = 0.0
	_pause = 0.25
	if hit:
		Sfx.play("tap")
		_new_spot()
		Atlas.fight_hit()
	else:
		Sfx.play("deny")
		Atlas.fight_miss()


func _draw_fight() -> void:
	if not is_instance_valid(_fight) or Atlas.dive.is_empty():
		return
	var ci := _fight
	var s := _fight.size
	var f: Dictionary = Atlas.dive.get("fight", {})
	var c := s / 2.0 + Vector2(0, -10)
	var k := clampf(minf(s.x, s.y) / 120.0, 1.6, 4.2)
	# A soft light behind the foe and a ring of seabed far below.
	Art.glow(ci, c, minf(s.x, s.y) * 0.55, Color(AtlasArt.SONAR, 0.10))
	var shake := Vector2.ZERO
	if _flash > 0.0 and _flash_hit:
		shake = Vector2(snappedf(sin(_t * 60.0) * 4.0, 1.0), 0)
	AtlasArt.draw_foe(ci, c + shake, k, str(f.get("kind", "monster")), str(Atlas.dive.get("bounty", "")), _t)
	var spot := c + _spot * k * 0.6
	Art.glow(ci, spot, 30.0, Color(AtlasArt.LURE, 0.55))
	Art.t_circle(ci, spot, RING_R * (1.0 - SPOT_AT) * 0.32, Color(AtlasArt.LURE, 0.9), 2.5, 0.0)
	if _pause <= 0.0:
		var u := _ring_t / _cycle()
		var rr := maxf(2.0, RING_R * (1.0 - u))
		var good := absf(u - SPOT_AT) <= Atlas.tap_window() / 2.0
		Art.arc(ci, spot, rr, 0.0, TAU, 40, Color("7fffb0") if good else Art.WHITE, 5.0 if good else 3.5)
	# Hits left as pips, the last tap's word.
	var left := int(f.get("left", 0))
	var total := maxi(1, int(f.get("hits", 1)))
	var pw := minf(22.0, (s.x - 40.0) / total)
	for i in total:
		var p := Vector2(s.x / 2.0 + (i - (total - 1) / 2.0) * pw, 18.0)
		Art.t_circle(ci, p, pw * 0.36, Color("ff5a7a") if i < left else Color("3a3f66"), 2.0, 0.0)
	if _flash > 0.0:
		var word := t("ATLAS_HIT") if _flash_hit else t("ATLAS_MISS") % roundi(Atlas.miss_cost())
		Art.text(ci, spot + Vector2(0, -RING_R * 0.5), word, 28, Color("7fffb0") if _flash_hit else Color("ff7f8f"), 7)


# --- Result ---------------------------------------------------------------------------

func _result() -> void:
	var win: bool = Atlas.dive["done"] == "win"
	var card := Views.card(Color("142a6b"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var title := Views.label(t("ATLAS_WIN") if win else t("ATLAS_FAIL"), 26 if win else 21, Color("7fffb0") if win else Color("ffb4a8"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var l: Dictionary = Atlas.dive["loot"]
	var k := 1.0 if win else 0.5
	var coins := GameState.income_rate() * 60.0 * float(l["minutes"]) * k
	var head := Views.label(t("ATLAS_LOOT"), 20, Color("bff4ff"), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for item in [["coin", NumFormat.short(coins)], ["pearl", "%d" % floori(int(l["pearls"]) * k)], ["shard", "%d %s" % [floori(int(l["shards"]) * k), t("ATLAS_SHARDS")]]]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		if item[0] == "shard":
			row.add_child(ArtView.make(func(ci: CanvasItem, sz: Vector2, _tt: float):
				Art.crystal(ci, Vector2(sz.x / 2.0, sz.y - 4.0), 24.0, 12.0, 0.15, Color("8fe8ff")), Vector2(32, 32)))
		else:
			row.add_child(Views.icon(item[0], 30))
		var lab := Views.label("+" + item[1], 24, Art.WHITE, true)
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(lab)
		v.add_child(row)
	_body.add_child(card)
	var icon := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		AtlasArt.draw_chamber(ci, s / 2.0, minf(s.x, s.y) * 0.3, "treasure" if win else "air", tt), Vector2(0, 150), true)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(icon)
	var b := Button.new()
	b.text = t("ATLAS_COLLECT")
	b.theme_type_variation = &"GoldButton"
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(_collect)
	_body.add_child(b)
	Sfx.play("milestone" if win else "deny")


func _collect() -> void:
	var got := Atlas.collect()
	Sfx.play("coins")
	if main and not got.is_empty():
		var bits := []
		if int(got.get("chart", 0)) > 1:
			bits.append(t("ATLAS_GOT_CHART") % int(got["chart"]))
		if str(got.get("rune", "")) != "":
			bits.append(t("ATLAS_GOT_RUNE") % t("ATLAS_RUNE_" + str(got["rune"]).to_upper()))
		if not bits.is_empty():
			main._show_toast(" · ".join(bits))
	queue_free()
