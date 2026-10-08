class_name OfficeRoom
extends Control
## Room 3: the office with the vault. Finished coins drop from a ceiling
## chute onto the vault pile (GameState.vault); a tap on the pile or the
## big Collect button moves them to the wallet (GameState.collect_vault).
## The accountant (manager "vault") sits at the desk and collects by
## himself. On the walls: the worker evolution board and the trophy shelf;
## the wardrobe holds the player's outfits; 8 decor slots change look with
## their level (Progress.decor, 0..5).
##
## Public API (W-UI mounts this in main.gd):
##   signal collected(amount: float, from_pos: Vector2)  coins moved to the wallet; from_pos is a
##                                                       global position (for main.celebrate)
##   signal open_evolution()          the evolution board was tapped
##   signal open_outfits()            the wardrobe (or the player) was tapped
##   signal decor_selected(slot)      a decor piece (or the wall / floor) was tapped
##   func collect() -> float          what a tap on the pile does
##   func slot_rect(slot) -> Rect2    tap area of a decor slot, "pile", "collect", "board",
##                                    "wardrobe" or "player" (local px), for hints and tutorials
##   func set_insets(top, bottom)     parts of the rect covered by the top bar / dock
##   var preview: Dictionary          screenshot/test overrides: world, decor (int or
##                                    {slot: level}), vault (fill 0..1), vault_amount,
##                                    accountant (bool), evo (0..12), outfit
##
## Layout: "tall" (phone portrait, PC) with a back row against the wall
## and a front row (desk, pile, player); "wide" (phone landscape) in one
## long row. Drawn in logical units scaled to fit (_k).

signal collected(amount: float, from_pos: Vector2)
signal open_evolution
signal open_outfits
signal decor_selected(slot: String)

const SLOTS: Array[String] = ["wallpaper", "floor", "desk", "sofa", "aquarium", "lamp", "trophy", "plant"]
const TALL_H := 660.0
const TALL_WALL := 430.0
const TALL_MIN_W := 420.0
const TALL_MAX_W := 760.0
const WIDE_H := 300.0
const WIDE_WALL := 176.0
const WIDE_MIN_W := 960.0
const WIDE_MAX_W := 1200.0
const DROP_SEC := 0.7
const BUTTON := Vector2(168, 54)

var preview: Dictionary = {}

var _t := 0.0
var _wide := false
var _k := 1.0
var _o := Vector2.ZERO
var _hall := Vector2(420, 660)
var _cw := 420.0
var _cx := 0.0
var _wall := TALL_WALL
var _inset_top := 0.0
var _inset_bottom := 0.0
## name -> [position (logical), scale]
var _at: Dictionary = {}
var _fill := 0.0
var _drops: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _flap := 0.0
var _press := -9.0
var _wardrobe_at := -9.0
var _player_at := -9.0
var _board_at := -9.0
var _poke: Dictionary = {}
var _rich_until := -9.0
var _acct_next := 3.0
var _acct_at := -9.0
var _bg: PaintLayer
var _bg_sig := ""
static var _looks: GDScript = null
## Chars as a plain Script, to look for Chars.player (W-Chars) at run time.
static var _chars: Script = load("res://scripts/ui/chars.gd")
static var _looks_checked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_bg = PaintLayer.new(_paint_bg)
	add_child(_bg)
	var gs := _gs()
	if gs:
		gs.cycle_finished.connect(_on_cycle_finished)
	_fill = _target_fill()
	_layout()
	if not preview.is_empty():
		_drop(3)
		_drops[-1]["t0"] = _t - 0.35


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func set_insets(top: float, bottom: float) -> void:
	_inset_top = top
	_inset_bottom = bottom
	_layout()


# --- State (guarded so the room runs before the other branches merge) -------------------

func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _pr() -> Node:
	return get_node_or_null("/root/Progress")


func world_id() -> String:
	if preview.has("world"):
		return str(preview["world"])
	var gs := _gs()
	if gs and gs.has_method("world_id"):
		return str(gs.call("world_id"))
	return "ocean"


func decor(slot: String) -> int:
	if preview.has("decor"):
		var d = preview["decor"]
		return clampi(int(d.get(slot, 0)) if d is Dictionary else int(d), 0, 5)
	var pr := _pr()
	if pr:
		var dd = pr.get("decor")
		if dd is Dictionary:
			return clampi(int(dd.get(slot, 0)), 0, 5)
	return 0


func vault() -> float:
	if preview.has("vault_amount"):
		return float(preview["vault_amount"])
	if preview.has("vault"):
		return float(preview["vault"]) * 125000.0
	var gs := _gs()
	if gs:
		var v = gs.get("vault")
		if v != null:
			return float(v)
	return 0.0


func _target_fill() -> float:
	if preview.has("vault"):
		return clampf(float(preview["vault"]), 0.0, 1.0)
	var v := vault()
	if v <= 0.0:
		return 0.0
	var gs := _gs()
	var rate := 1.0
	if gs and gs.has_method("income_rate"):
		rate = maxf(1.0, float(gs.income_rate()))
	# About three minutes of income fills the pile.
	return clampf(0.08 + v / (rate * 180.0), 0.0, 1.0)


func has_accountant() -> bool:
	if preview.has("accountant"):
		return bool(preview["accountant"])
	var gs := _gs()
	return gs != null and gs.has_manager("vault")


func evo() -> int:
	if preview.has("evo"):
		return int(preview["evo"])
	var gs := _gs()
	if gs:
		var e = gs.get("evo")
		if e != null:
			return int(e)
	return 0


func _outfit() -> String:
	if preview.has("outfit"):
		return str(preview["outfit"])
	var pr := _pr()
	if pr:
		var eq = pr.get("equipped")
		if eq is Dictionary:
			return str(eq.get("outfit", "outfit_casual"))
	return "outfit_casual"


func _avatar() -> Dictionary:
	var st := get_node_or_null("/root/Settings")
	return st.avatar if st else Chars.default_avatar()


# --- Layout --------------------------------------------------------------------------------

func _layout() -> void:
	var avail := Vector2(size.x, maxf(1.0, size.y - _inset_top - _inset_bottom))
	if avail.x < 2.0:
		return
	_wide = avail.x / avail.y >= 1.6
	var h := WIDE_H if _wide else TALL_H
	_k = minf(avail.y / h, avail.x / (WIDE_MIN_W if _wide else TALL_MIN_W))
	_hall = Vector2(avail.x / _k, avail.y / _k)
	_cw = minf(_hall.x, WIDE_MAX_W if _wide else TALL_MAX_W)
	_cx = (_hall.x - _cw) / 2.0
	var dy := _hall.y - h
	_o = Vector2(0, _inset_top)
	_wall = (WIDE_WALL if _wide else TALL_WALL) + dy
	var W := _cw
	var X := _cx
	var wb := _wall
	if _wide:
		var s := 0.8
		_at = {
			"wardrobe": [Vector2(X + 52, wb + 14), s],
			"board": [Vector2(X + W * 0.17, wb - 96), 0.78],
			"sofa": [Vector2(X + W * 0.32, wb + 16), s],
			"porthole": [Vector2(X + W * 0.43, wb - 120), 0.8],
			"lamp": [Vector2(X + W * 0.32, 0), 0.8],
			"chute": [Vector2(X + W * 0.53, 0), 1.0],
			"pile": [Vector2(X + W * 0.53, wb + 88), s],
			"player": [Vector2(X + W * 0.645, wb + 104), 0.8],
			"trophy": [Vector2(X + W * 0.64, wb - 106), 0.75],
			"aquarium": [Vector2(X + W * 0.77, wb + 16), s],
			"desk": [Vector2(X + W * 0.865, wb + 90), s],
			"plant": [Vector2(X + W - 34, wb + 110), s],
			"collect": [Vector2(X + W * 0.53 - 150, wb + 96), 0.9],
		}
	else:
		var big := clampf(W / 520.0, 1.0, 1.3)
		_at = {
			"wardrobe": [Vector2(X + 56 * big, wb + 14), big],
			"board": [Vector2(X + W * 0.40, wb - 250), big],
			"sofa": [Vector2(X + W * 0.40, wb + 18), big],
			"porthole": [Vector2(X + W * 0.86, wb - 340), big],
			"lamp": [Vector2(X + W * 0.13, 0), big],
			"chute": [Vector2(X + W * 0.665, 0), 1.0],
			"pile": [Vector2(X + W * 0.665, wb + 150), big],
			"player": [Vector2(X + W * 0.9, wb + 176), big],
			"trophy": [Vector2(X + W * 0.86, wb - 196), big * 0.8],
			"aquarium": [Vector2(X + W * 0.86, wb + 18), big * 0.9],
			"desk": [Vector2(X + W * 0.27, wb + 122), big * 0.95],
			"plant": [Vector2(X + 38 * big, wb + 222), big * 0.9],
			"collect": [Vector2(X + W * 0.665, wb + 186), big],
		}
	_bg_sig = ""
	queue_redraw()


func _p(name: String) -> Vector2:
	return _at[name][0]


func _s(name: String) -> float:
	return _at[name][1]


func _to_screen(p: Vector2) -> Vector2:
	return _o + p * _k


## Tap area (local px) of a decor slot or "pile", "collect", "board",
## "wardrobe", "player".
func slot_rect(slot: String) -> Rect2:
	var r := Rect2()
	match slot:
		"wallpaper":
			return Rect2(_to_screen(Vector2(0, 0)), Vector2(size.x, _wall * _k))
		"floor":
			var a := _to_screen(Vector2(0, _wall))
			return Rect2(a, Vector2(size.x, size.y - _inset_bottom - a.y))
		"collect":
			var c := _p("collect")
			var bs := BUTTON * _s("collect")
			r = Rect2(c - bs / 2.0, bs).grow(4.0)
		"player":
			var pp := _p("player")
			var ps := _s("player")
			r = Rect2(pp + Vector2(-30, -104) * ps, Vector2(60, 108) * ps)
		_:
			if not OfficeArt.BOX.has(slot) or not _at.has(slot):
				return Rect2()
			var b: Rect2 = OfficeArt.BOX[slot]
			var sc := _s(slot)
			r = Rect2(_p(slot) + b.position * sc, b.size * sc)
			if slot == "lamp":
				r = Rect2(_p(slot) + Vector2(b.position.x, _lamp_cord()) * sc, Vector2(b.size.x, 70) * sc)
	var a2 := _to_screen(r.position)
	var sz := r.size * _k
	# Never smaller than a finger.
	var grow := Vector2(maxf(0.0, 44.0 - sz.x), maxf(0.0, 44.0 - sz.y)) / 2.0
	return Rect2(a2 - grow, sz + grow * 2.0)


func _lamp_cord() -> float:
	return [70.0, 62.0, 56.0, 50.0, 40.0, 36.0][decor("lamp")]


# --- Events ----------------------------------------------------------------------------------

func _on_cycle_finished(key: String, _amount: float) -> void:
	if key == "plant" or key == "plant2":
		_drop(2 if key == "plant" else 1)


## Coins drop from the chute onto the pile.
func _drop(n: int) -> void:
	_flap = 1.0
	for i in n:
		if _drops.size() > 10:
			break
		_drops.append({"t0": _t + i * 0.12, "x": randf_range(-14.0, 14.0)})


func _gui_input(event: InputEvent) -> void:
	var p := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		p = event.position
	elif event is InputEventScreenTouch and event.pressed:
		p = event.position
	else:
		return
	var what := thing_at(p)
	if what == "":
		return
	accept_event()
	_fx.append({"kind": "ripple", "p": (p - _o) / _k, "t0": _t})
	match what:
		"pile", "collect":
			_press = _t
			collect()
		"board":
			_board_at = _t
			_play("click")
			open_evolution.emit()
		"wardrobe":
			_wardrobe_at = _t
			_play("click")
			open_outfits.emit()
		"player":
			_player_at = _t
			_play("pop")
			open_outfits.emit()
		_:
			_poke[what] = _t
			_play("click")
			decor_selected.emit(what)


## What is under a local point: "collect", "pile", "player", "board",
## "wardrobe", a decor slot, or "".
func thing_at(p: Vector2) -> String:
	for name: String in ["collect", "pile", "player", "desk", "plant", "aquarium", "sofa", "wardrobe", "board", "trophy", "lamp", "floor", "wallpaper"]:
		if slot_rect(name).has_point(p):
			return name
	return ""


## Moves the vault into the wallet (GameState.collect_vault) and shows it.
func collect() -> float:
	var amount := 0.0
	var gs := _gs()
	if preview.has("vault"):
		amount = vault()
		preview["vault"] = 0.0
		preview.erase("vault_amount")
	elif gs and gs.has_method("collect_vault"):
		amount = float(gs.call("collect_vault"))
	if amount <= 0.0:
		_play("tap")
		_fx.append({"kind": "text", "p": _p("pile") + Vector2(0, -70) * _s("pile"), "t0": _t, "s": tr("VAULT_EMPTY"), "c": Art.WHITE})
		return 0.0
	_rich_until = _t + 1.6
	_play("coins")
	var top := _p("pile") + Vector2(0, -60) * _s("pile")
	_fx.append({"kind": "text", "p": top + Vector2(0, -30), "t0": _t, "s": "+" + NumFormat.short(amount), "c": Art.GOLD})
	for i in 10:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_fx.append({"kind": "coin", "p": top, "v": Vector2(cos(a), sin(a)) * randf_range(160, 320), "t0": _t})
	collected.emit(amount, get_global_transform() * _to_screen(top))
	return amount


func _play(s: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(s)


# --- Animation -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_fill = move_toward(_fill, _target_fill(), delta * 1.5)
	_flap = maxf(0.0, _flap - delta * 1.6)
	if has_accountant() and _t >= _acct_next:
		_acct_next = _t + 5.0
		_acct_at = _t
	var i := 0
	while i < _drops.size():
		if _t - float(_drops[i]["t0"]) > DROP_SEC:
			_drops.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _fx.size():
		if _t - float(_fx[i]["t0"]) > 1.2:
			_fx.remove_at(i)
		else:
			i += 1
	queue_redraw()


# --- Drawing ---------------------------------------------------------------------------------

func _paint_bg(ci: CanvasItem) -> void:
	var full_h := _hall.y + (_inset_top + _inset_bottom) / _k
	Art.push(ci, _o, 0.0, Vector2(_k, _k))
	Art.push(ci, Vector2(0, -_inset_top / _k))
	OfficeArt.wallpaper(ci, _hall.x, _wall + _inset_top / _k, decor("wallpaper"))
	OfficeArt.floor_band(ci, _hall.x, _wall + _inset_top / _k, full_h, decor("floor"))
	Art.pop(ci)
	var fl := decor("floor")
	if fl in [2, 4, 5]:
		var c := Vector2(_p("pile").x if not _wide else _cx + _cw * 0.45, _wall + (_hall.y - _wall) * 0.55)
		OfficeArt.rug(ci, c, Vector2(minf(_cw * 0.3, 190.0), (_hall.y - _wall) * 0.22), fl)
	Art.push(ci, _p("porthole"), 0.0, Vector2.ONE * _s("porthole"))
	OfficeArt.porthole(ci, world_id())
	Art.pop(ci)
	Art.pop(ci)


func _sig() -> String:
	return "%s|%s|%s|%d|%d" % [world_id(), size, _k, decor("wallpaper"), decor("floor")]


func _bounce(name: String) -> Vector2:
	var at = _poke.get(name)
	if at == null:
		return Vector2.ONE
	var a := _t - float(at)
	if a > 0.4:
		return Vector2.ONE
	var s := sin(a / 0.4 * PI) * 0.08
	return Vector2(1.0 + s, 1.0 - s)


func _push(name: String, extra: Vector2 = Vector2.ONE) -> void:
	Art.push(self, _p(name), 0.0, Vector2.ONE * _s(name) * extra * _bounce(name))


func _draw() -> void:
	var sig := _sig()
	if sig != _bg_sig:
		_bg_sig = sig
		_bg.queue_redraw()
	Art.push(self, _o, 0.0, Vector2(_k, _k))
	# Wall pieces.
	_push("board")
	OfficeArt.board(self, clampf(1.0 - (_t - _board_at) / 0.6, 0.0, 1.0))
	_draw_evo()
	Art.pop(self)
	_push("trophy")
	OfficeArt.trophy(self, decor("trophy"), _t)
	Art.pop(self)
	# Back row against the wall.
	var wopen := clampf(1.0 - absf(_t - _wardrobe_at - 0.6) / 0.6, 0.0, 1.0)
	_push("wardrobe")
	OfficeArt.wardrobe(self, wopen, Chars.OUTFITS[int(_avatar().get("outfit", 0)) % Chars.OUTFITS.size()])
	Art.pop(self)
	_push("sofa")
	OfficeArt.sofa(self, decor("sofa"))
	Art.pop(self)
	_push("aquarium")
	OfficeArt.aquarium(self, decor("aquarium"), _t)
	Art.pop(self)
	# Chute and pile.
	var pile_top := _p("pile") + Vector2(0, -lerpf(14.0, 92.0, Props._q(_fill, 12))) * _s("pile")
	var mouth := Vector2(_p("chute").x, pile_top.y - (60.0 if not _wide else 40.0))
	mouth.y = minf(mouth.y, _wall + 10.0)
	OfficeArt.chute(self, 10.0, mouth, _flap)
	for d: Dictionary in _drops:
		var a := (_t - float(d["t0"])) / DROP_SEC
		if a < 0.0:
			continue
		var p := mouth.lerp(pile_top + Vector2(float(d["x"]), 0), a * a)
		Art.push(self, p, 0.0, Vector2(1.0, 0.6 + 0.4 * absf(sin(a * 9.0))))
		Art.coin(self, Vector2.ZERO, 9.0 * _s("pile"))
		Art.pop(self)
	var squash := 0.0
	if _t - _press < 0.3:
		squash = sin((_t - _press) / 0.3 * PI) * 0.12
	_push("pile", Vector2(1.0 + squash, 1.0 - squash))
	OfficeArt.pile(self, _fill, _t)
	Art.pop(self)
	# Front row: desk with the accountant, the player, the plant.
	_draw_desk()
	_draw_player()
	_push("plant")
	OfficeArt.plant(self, decor("plant"), _t)
	Art.pop(self)
	# Collect button (only while there is something to collect).
	var amount := vault()
	_push("collect")
	var tr_label := tr("COLLECT")
	OfficeArt.collect_button(self, BUTTON, tr_label, NumFormat.short(amount) if amount > 0.0 else "", amount > 0.0,
			clampf(1.0 - (_t - _press) / 0.2, 0.0, 1.0))
	Art.pop(self)
	# The lamp in front of everything on the wall.
	_push("lamp")
	OfficeArt.lamp(self, decor("lamp"), _t)
	Art.pop(self)
	_draw_fx()
	Art.pop(self)


func _draw_desk() -> void:
	var lv := decor("desk")
	var dp := _p("desk")
	var ds := _s("desk")
	Art.push(self, dp, 0.0, Vector2.ONE * ds * _bounce("desk"))
	Art.push(self, Vector2(-30, -6))
	OfficeArt.chair(self, lv)
	Art.pop(self)
	if has_accountant():
		var since := _t - _acct_at
		var busy := since < 1.4
		var stamp := absf(sin(_t * 6.0)) if busy else 0.0
		var look := Chars.look(0, "short", 4, "none", "glasses", 0, "vest")
		Chars.person(self, Vector2(-30, -40), 0.86, 1.0, look, {"emotion": "rich" if busy else "focus",
				"blink": Chars.blinking(_t, 3.0), "arm_r": 1.6 - stamp * 0.8, "arm_l": 0.9, "hold": "clipboard" if not busy else "coinbag", "bob": 0.0})
	OfficeArt.desk(self, lv, _t)
	Art.pop(self)
	# The bag of coins hops from the pile to the desk.
	if has_accountant():
		var a := (_t - _acct_at) / 0.6
		if a >= 0.0 and a <= 1.0:
			var from := _p("pile") + Vector2(0, -40) * _s("pile")
			var to := dp + Vector2(10, -90) * ds
			var p := from.lerp(to, a) + Vector2(0, -sin(a * PI) * 60.0)
			Chars.item(self, "coinbag", p, Art.GOLD)


func _draw_player() -> void:
	var pp := _p("player")
	var ps := _s("player")
	var since := _t - _player_at
	var hop := 10.0 * sin(since / 0.5 * PI) if since < 0.5 else 0.0
	var rich := _t < _rich_until
	var wave := since < 1.2
	var emo := "rich" if rich else ("joy" if wave else ("happy" if _fill < 0.6 else "wow"))
	var arm_r := 2.7 + sin(_t * 10.0) * 0.4 if wave else (2.4 if rich else 0.3)
	var arm_l := -2.4 if rich else -0.2
	var pose := {"emotion": emo, "blink": Chars.blinking(_t, 9.0), "arm_r": arm_r, "arm_l": arm_l, "bob": 0.0}
	var at := pp - Vector2(0, hop * ps)
	if _chars.has_method("player"):
		var pp2 := {"pose": "collect" if rich else ("wave" if wave else "idle"), "t": _t, "emotion": emo, "facing": -1.0}
		_chars.call("player", self, at, 0.95 * ps, _avatar(), _outfit(), pp2)
	else:
		Chars.person(self, at, 0.95 * ps, -1.0, _avatar(), pose)


## The gear board: the workers' gear level now, the next one beside it,
## and four pips for the four levels.
func _draw_evo() -> void:
	var gears := 4
	var e := clampi(evo(), 0, gears - 1)
	Art.text(self, Vector2(0, -41), tr("EVO_BOARD"), 15, Art.WHITE, 4)
	var looks := _worker_looks()
	var w := world_id()
	if looks:
		looks.call("draw_card", self, Vector2(-36, 4), 76.0, w, e, true, _t)
		if e < gears - 1:
			looks.call("draw_card", self, Vector2(38, 8), 64.0, w, e + 1, true, _t)
	else:
		var depth := clampi(e, 0, Art.DEPTH_STYLE.size() - 1)
		var st: Dictionary = Art.DEPTH_STYLE[depth]
		Chars.diver(self, Vector2(-36, 40), 0.62, st.get("suit", Art.CORAL), 1.0, 0.0, 0.0, "idle", 0.0, false,
				st.get("ore", Art.GOLD), "happy", Chars.blinking(_t, 5.0), _t, depth, {"world": w, "form": e})
	if e < gears - 1:
		Art.toon(self, PackedVector2Array([Vector2(-4, 0), Vector2(6, 6), Vector2(-4, 12)]), Art.GOLD, 1.8, 0.0)
	else:
		Art.toon(self, Art.star_pts(Vector2(38, 10), 18, 8, 5), Art.GOLD, 2.4, 0.4)
	for i in gears:
		var c := Vector2(-24 + i * 16, 50)
		Art.disc(self, c, 4.6, Art.GOLD if i <= e else Color(1, 1, 1, 0.25))


static func _worker_looks() -> GDScript:
	if not _looks_checked:
		_looks_checked = true
		if ResourceLoader.exists("res://scripts/ui/worker_looks.gd"):
			_looks = load("res://scripts/ui/worker_looks.gd")
	return _looks


func _draw_fx() -> void:
	for f: Dictionary in _fx:
		var age := _t - float(f["t0"])
		match str(f["kind"]):
			"ripple":
				var a := 1.0 - age / 1.2
				Art.arc(self, f["p"], 14.0 + age * 60.0, 0, TAU, 24, Color(1, 1, 1, 0.8 * a), 3.0)
			"text":
				var p: Vector2 = f["p"] + Vector2(0, -age * 40.0)
				Art.push(self, p, 0.0, Vector2.ONE / maxf(_k, 0.01) * minf(1.0, _k * 1.2))
				Art.text(self, Vector2.ZERO, str(f["s"]), 30, f["c"], 6)
				Art.pop(self)
			"coin":
				if age > 0.8:
					continue
				var p: Vector2 = f["p"] + Vector2(f["v"]) * age + Vector2(0, 520.0 * age * age)
				Art.push(self, p, 0.0, Vector2(absf(cos(age * 12.0)) * 0.8 + 0.2, 1.0))
				Art.coin(self, Vector2.ZERO, 9.0)
				Art.pop(self)
