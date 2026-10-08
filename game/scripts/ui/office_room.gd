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
## The window onto the world (logical).
var _window := Rect2()
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
			"wardrobe": [Vector2(X + W * 0.05, wb + 12), s],
			"sofa": [Vector2(X + W * 0.2, wb + 16), s],
			"board": [Vector2(X + W * 0.2, wb - 98), 0.7],
			"pile": [Vector2(X + W * 0.47, wb + 8), 0.64],
			"aquarium": [Vector2(X + W * 0.77, wb + 14), s],
			"trophy": [Vector2(X + W * 0.885, wb - 116), 0.72],
			"plant": [Vector2(X + W * 0.965, wb + 104), s],
			"lamp": [Vector2(X + W * 0.335, 0), 0.8],
			"clock": [Vector2(X + W * 0.118, 64), 0.7],
			"chute": [Vector2(X + W * 0.47, 0), 1.0],
			"desk": [Vector2(X + W * 0.3, wb + 108), s],
			"player": [Vector2(X + W * 0.63, wb + 112), 0.8],
			"collect": [Vector2(X + W * 0.47, wb + 66), 0.9],
		}
		var wtop := 40.0
		_window = Rect2(X + W * 0.575, wtop, W * 0.085, clampf(wb - 64.0 - wtop, 60.0, 170.0))
	else:
		var big := clampf(minf(W / 520.0, _hall.y / 760.0), 0.86, 1.3)
		var front := minf(196.0 * big, _hall.y - wb - 44.0)
		_at = {
			"wardrobe": [Vector2(X + W * 0.1 + 6.0, wb + 12), big * 0.95],
			"trophy": [Vector2(X + W * 0.11 + 4.0, wb - 262 * big), big * 0.72],
			"sofa": [Vector2(X + W * 0.37, wb + 16), big * 0.92],
			"board": [Vector2(X + W * 0.37, wb - 196 * big), big * 0.95],
			"pile": [Vector2(X + W * 0.63, wb + 8), big * 0.88],
			"aquarium": [Vector2(X + W * 0.915, wb + 14), big * 0.82],
			"lamp": [Vector2(X + W * 0.2, 0), big * 0.9],
			"clock": [Vector2(X + W * 0.53, 104), big],
			"chute": [Vector2(X + W * 0.63, 0), 1.0],
			"desk": [Vector2(X + W * 0.3, wb + front), big * 0.95],
			"player": [Vector2(X + W * 0.87, wb + front), big],
			"plant": [Vector2(X + maxf(W * 0.06, 36.0 * big), wb + front + 18.0 * big), big * 0.85],
			"collect": [Vector2(X + W * 0.63, wb + 74 * big), big],
		}
		_unclutter_tall(X, W)
		var wtop := 74.0
		var ww := minf(W * 0.16, 150.0)
		var wx := X + W - ww - 42.0
		_window = Rect2(wx, wtop, ww, clampf(wb - 175.0 * big - wtop, 70.0, 190.0))
	_bg_sig = ""
	queue_redraw()


## Widest drawing of each back-row piece (at its biggest level), in its own
## units: [left, right] of its origin. Measured once.
static var _extent := {}


static func _piece_extent(name: String) -> Vector2:
	if _extent.has(name):
		return _extent[name]
	Art.measure_begin()
	match name:
		"sofa":
			OfficeArt.sofa(null, 5)
		"aquarium":
			OfficeArt.aquarium(null, 5, 0.0)
		"wardrobe":
			OfficeArt.wardrobe(null, 0.0, Chars.OUTFITS[0])
	var r := Art.measure_end()
	_extent[name] = Vector2(-r.position.x, r.end.x)
	return _extent[name]


## Narrow phones: the sofa and the aquarium stand clear of the vault (its
## open door on the left, the full vault's coin stacks on both sides),
## moving aside and, if the wall is too short, getting a bit smaller.
func _unclutter_tall(X: float, W: float) -> void:
	const GAP := 8.0
	var vs := _s("pile")
	var vx := _p("pile").x
	# The door reaches ~124 left of the vault's middle, the coin stacks ~122
	# right of it (OfficeArt.vault, vault_coins).
	var vault_l := vx - 126.0 * vs - GAP
	var vault_r := vx + 124.0 * vs + GAP
	var wr := _p("wardrobe").x + _piece_extent("wardrobe").y * _s("wardrobe") + GAP
	_fit_between("sofa", wr, vault_l, true)
	_fit_between("aquarium", vault_r, X + W - 6.0, false)


## Keeps a back-row piece between two x limits: slides it in, and shrinks
## it (to 70% at most) when the gap is narrower than the piece. The vault's
## side (`hi` for the sofa, `lo` for the aquarium) always stays clear.
func _fit_between(name: String, lo: float, hi: float, clear_hi: bool) -> void:
	var e := _piece_extent(name)
	var sc := _s(name)
	var room := hi - lo
	if room <= 1.0:
		return
	var w := (e.x + e.y) * sc
	if w > room:
		sc = maxf(sc * 0.7, room / (e.x + e.y))
	var x: float = _p(name).x
	if clear_hi:
		x = maxf(minf(x, hi - e.y * sc), lo + e.x * sc)
		x = minf(x, hi - e.y * sc)
	else:
		x = minf(maxf(x, lo + e.x * sc), hi - e.y * sc)
		x = maxf(x, lo + e.x * sc)
	_at[name] = [Vector2(x, _p(name).y), sc]


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
		_fx.append({"kind": "text", "p": _vault_top(), "t0": _t, "s": tr("VAULT_EMPTY"), "c": Art.WHITE})
		return 0.0
	_rich_until = _t + 1.6
	_play("coins")
	var top := _vault_top()
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
		var c := Vector2(_p("desk").x + (_p("player").x - _p("desk").x) * 0.5, _wall + (_hall.y - _wall) * 0.6)
		OfficeArt.rug(ci, c, Vector2(minf(_cw * 0.32, 220.0), (_hall.y - _wall) * 0.24), fl)
	OfficeArt.window_view(ci, _window, world_id(), decor("wallpaper"))
	OfficeArt.window_light(ci, _window, _wall)
	Art.push(ci, _p("clock"), 0.0, Vector2.ONE * _s("clock"))
	OfficeArt.clock(ci)
	Art.pop(ci)
	# The pipe from the factory down into the vault, and the vault.
	var vs := _s("pile")
	var vtop := _p("pile") + Vector2(0, OfficeArt.VAULT_C.y - OfficeArt.VAULT_R - 46.0) * vs
	OfficeArt.chute(ci, 10.0, Vector2(_p("chute").x, vtop.y + 4.0), 0.0)
	Art.push(ci, _p("pile"), 0.0, Vector2.ONE * vs)
	OfficeArt.vault(ci, tr("VAULT"))
	Art.pop(ci)
	Art.push(ci, Vector2(0, -_inset_top / _k))
	OfficeArt.vignette(ci, _hall.x, full_h)
	Art.pop(ci)
	Art.pop(ci)


func _sig() -> String:
	return "%s|%s|%s|%d|%d|%s" % [world_id(), size, _k, decor("wallpaper"), decor("floor"), TranslationServer.get_locale()]


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
	# Coins falling from the pipe into the vault, and the vault's heap.
	var vs := _s("pile")
	var mouth := _vault_mouth()
	var hole := _p("pile") + (OfficeArt.VAULT_C + Vector2(0, OfficeArt.VAULT_R * 0.35)) * vs
	if _flap > 0.0:
		Props.halo(self, mouth, 22.0 * vs * _flap, Color(1.0, 0.85, 0.3, 0.5 * _flap))
	for d: Dictionary in _drops:
		var a := (_t - float(d["t0"])) / DROP_SEC
		if a < 0.0:
			continue
		var p := mouth.lerp(hole + Vector2(float(d["x"]), 0) * vs, a * a)
		Art.push(self, p, 0.0, Vector2(absf(cos(a * 9.0)) * 0.7 + 0.3, 1.0) * vs)
		Art.coin(self, Vector2.ZERO, 9.0)
		Art.pop(self)
	var squash := 0.0
	if _t - _press < 0.3:
		squash = sin((_t - _press) / 0.3 * PI) * 0.06
	_push("pile", Vector2(1.0 + squash, 1.0 - squash))
	OfficeArt.vault_coins(self, _fill, _t)
	Art.pop(self)
	# Clock hands.
	Art.push(self, _p("clock"), 0.0, Vector2.ONE * _s("clock"))
	OfficeArt.clock_hands(self, _t)
	Art.pop(self)
	# Empty decor slots breathe so they read as "build here".
	_draw_spots()
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


## Where the pipe from the factory ends, over the vault.
func _vault_mouth() -> Vector2:
	return Vector2(_p("chute").x, _p("pile").y + (OfficeArt.VAULT_C.y - OfficeArt.VAULT_R - 46.0) * _s("pile") + 4.0)


## The top of the vault's opening, where collected coins fly from.
func _vault_top() -> Vector2:
	return _p("pile") + (OfficeArt.VAULT_C + Vector2(0, -OfficeArt.VAULT_R * 0.4)) * _s("pile")


## A soft pulsing ring over the empty (level 0) decor slots.
func _draw_spots() -> void:
	var ph := Props._q(0.5 + 0.5 * sin(_t * 3.0), 8)
	for slot: String in ["sofa", "aquarium", "lamp", "trophy", "plant"]:
		if decor(slot) != 0 or not _at.has(slot):
			continue
		var b: Rect2 = OfficeArt.BOX[slot]
		var c := b.get_center()
		if slot == "lamp":
			c = Vector2(0, 66)
		var sc := _s(slot)
		var at := _p(slot) + c * sc
		Art.ring(self, Art.circle_pts(at, (17.0 + ph * 9.0) * sc, 24), Color(0.55, 1.0, 0.6, 0.7 * (1.0 - ph)), 3.0)


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
		var look := Chars.look(0, "short", 4, "none", "glasses", 0, "vest")
		var pose := {"blink": Chars.blinking(_t, 3.0), "bob": 0.0}
		if busy:
			# Stamping the books.
			var stamp := absf(sin(snappedf(since, 1.0 / 30.0) * 8.0))
			pose.merge({"emotion": "rich", "arm_r": 1.8 - stamp * 0.9, "arm_l": 0.9, "hold": "coinbag"})
		else:
			# Typing on the calculator, a glance up now and then.
			var k := snappedf(_t, 1.0 / 16.0)
			pose.merge({"emotion": "focus", "arm_r": 1.25 + absf(sin(k * 11.0)) * 0.25, "arm_l": 1.15 + absf(cos(k * 9.0)) * 0.25})
		Chars.person(self, Vector2(-30, -40), 0.86, 1.0, look, pose)
	else:
		Art.push(self, Vector2(-30, -6))
		OfficeArt.ghost(self)
		Art.pop(self)
	OfficeArt.desk(self, lv, _t)
	Art.pop(self)
	# The bag of coins hops from the vault to the desk.
	if has_accountant():
		var a := (_t - _acct_at) / 0.6
		if a >= 0.0 and a <= 1.0:
			var from := _vault_top()
			var to := dp + Vector2(10, -90) * ds
			var p := from.lerp(to, a) + Vector2(0, -sin(a * PI) * 60.0)
			Chars.item(self, "coinbag", p, Art.GOLD)


func _pet() -> String:
	if preview.has("pet"):
		return str(preview["pet"])
	var pr := _pr()
	if pr and pr.has_method("equipped_art"):
		return str(pr.call("equipped_art", "pet"))
	return ""


func _draw_player() -> void:
	var pp := _p("player")
	var ps := _s("player")
	var since := _t - _player_at
	var hop := 10.0 * sin(since / 0.5 * PI) if since < 0.5 else 0.0
	var rich := _t < _rich_until
	var wave := since < 1.2
	# Idle life: a cycle of standing, a wave, and a cheer when the vault is full.
	var cyc := fmod(_t, 11.0)
	var mode := "idle"
	if rich:
		mode = "collect"
	elif wave or (cyc > 8.0 and cyc < 9.4):
		mode = "wave"
	elif _fill >= 0.85 and cyc > 4.0 and cyc < 5.6:
		mode = "cheer"
	var emo := "rich" if rich else ("joy" if mode != "idle" else ("happy" if _fill < 0.6 else "wow"))
	var facing := -1.0 if _p("pile").x < pp.x else 1.0
	var at := pp - Vector2(0, hop * ps)
	Art.flat(self, Art.ellipse_pts(pp + Vector2(0, 2) * ps, Vector2(30, 7) * ps, 16), Color(0, 0, 0, 0.14))
	if _chars.has_method("player"):
		var pp2 := {"pose": mode, "t": _t, "emotion": emo, "facing": facing, "blink": Chars.blinking(_t, 9.0)}
		_chars.call("player", self, at, 0.95 * ps, _avatar(), _outfit(), pp2)
	else:
		var arm_r := 2.7 + sin(_t * 10.0) * 0.4 if mode == "wave" else (2.4 if rich else 0.3)
		Chars.person(self, at, 0.95 * ps, facing, _avatar(), {"emotion": emo, "blink": Chars.blinking(_t, 9.0), "arm_r": arm_r, "arm_l": -0.2, "bob": 0.0})
	# The pet floats beside the player.
	var pet := _pet()
	if pet != "":
		var side := -facing
		var pa := pp + Vector2(side * 48.0, -62.0 + sin(_t * 2.6) * 5.0) * ps
		if pa.x > _cx + _cw - 24.0 or pa.x < _cx + 24.0:
			pa.x = pp.x - side * 48.0 * ps
		Art.push(self, pa, 0.0, Vector2.ONE * 1.15 * ps)
		PetArt.draw(self, pet, _t, facing, rich)
		Art.pop(self)


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
