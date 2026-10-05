class_name RoomTabs
extends Control
## The three rooms of the main screen as big tabs: Mine, Factory, Office.
## Phone: a strip under the top bar, as wide as the screen. PC: a floating
## pill under the coin notch. Each tab has a drawn icon and its name; the
## active one stands up in its room's color. Little things fly onto the
## tabs to show the chain: a crate onto the Factory when a boat trip ends,
## a coin onto the Office when coins land in the vault. A badge shows coins
## waiting in the vault and a red dot when a manager can be hired there.

signal selected(index: int)

const KEYS := ["ROOM_MINE", "ROOM_FACTORY", "ROOM_OFFICE"]
const COLORS: Array[Color] = [Color("3aa6f0"), Color("ff8a3d"), Color("a46cf0")]
const STRIP := Color("1f3f73")
const IDLE := Color("2c5592")
## Phone strip height and the PC pill's.
const STRIP_H := 80.0
const PILL_H := 76.0
const PILL_W := 560.0

var current := 0
## PC: a floating pill instead of a full-width strip.
var floating := false
var _t := 0.0
var _down := -1
var _press: Array[float] = [0.0, 0.0, 0.0]
var _bump: Array[float] = [0.0, 0.0, 0.0]
## Things flying onto a tab: {"tab", "kind", "t0"}.
var _flyers: Array[Dictionary] = []
var _badge: Array[String] = ["", "", ""]
var _dot: Array[bool] = [false, false, false]
var _check_left := 0.0
var _sig := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.cycle_finished.connect(_on_cycle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func height() -> float:
	return PILL_H if floating else STRIP_H


## Area of tab i (local).
func tab_rect(i: int) -> Rect2:
	var pad := Vector2(10, 8) if not floating else Vector2(8, 8)
	var top := 9.0 if not floating else pad.y
	var w := (size.x - pad.x * 2.0 - 8.0 * 2.0) / 3.0
	var h := size.y - top - pad.y - (6.0 if not floating else 0.0)
	return Rect2(pad.x + i * (w + 8.0), top, w, h)


func set_current(i: int) -> void:
	if i != current:
		current = i
		_bump[i] = 1.0
		queue_redraw()


## Something arrived in a room: a short bounce and a flying icon.
func ping(i: int, kind: String) -> void:
	if i == current or Settings.reduce_motion:
		return
	if _flyers.size() < 4:
		_flyers.append({"tab": i, "kind": kind, "t0": _t})


func _on_cycle(key: String, _amount: float) -> void:
	if not is_visible_in_tree():
		return
	if GameState.is_boat(key):
		ping(1, "crate")
	elif GameState.is_plant(key) and not GameState.has_manager("vault"):
		ping(2, "coin")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := -1
		for i in 3:
			if tab_rect(i).grow(4.0).has_point(event.position):
				hit = i
		if event.pressed:
			_down = hit
		elif _down >= 0:
			if hit == _down:
				Sfx.play("click")
				selected.emit(hit)
			_down = -1
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	var moving := false
	for i in 3:
		var want := 1.0 if _down == i else 0.0
		if _press[i] != want:
			_press[i] = move_toward(_press[i], want, delta * 12.0)
			moving = true
		if _bump[i] > 0.0:
			_bump[i] = maxf(0.0, _bump[i] - delta * 2.5)
			moving = true
	var i := 0
	while i < _flyers.size():
		var f: Dictionary = _flyers[i]
		var age := _t - float(f["t0"])
		if age > 0.9:
			_bump[int(f["tab"])] = maxf(_bump[int(f["tab"])], 0.6)
			_flyers.remove_at(i)
		else:
			i += 1
	if not _flyers.is_empty():
		moving = true
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.25
		_update_badges()
	if moving:
		queue_redraw()


## Coins in the vault (no accountant) on the Office tab; red dots where a
## manager can be hired right now.
func _update_badges() -> void:
	var gs := GameState
	var vault: float = gs.vault
	_badge[2] = NumFormat.short(vault) if vault >= 1.0 and not gs.has_manager("vault") else ""
	_dot[0] = false
	for k in ["lift", "boat", "boat2"]:
		if StageCard.unit_wants_manager(k):
			_dot[0] = true
	_dot[1] = StageCard.unit_wants_manager("plant") or StageCard.unit_wants_manager("plant2")
	_dot[2] = _badge[2] == "" and not gs.has_manager("vault") and gs.coins >= gs.manager_cost("vault")
	var sig := [_badge.duplicate(), _dot.duplicate(), current]
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _draw() -> void:
	if floating:
		var r := Rect2(Vector2.ZERO, size)
		Art.t_rect(self, Rect2(r.position + Vector2(0, 5), r.size), r.size.y / 2.0, Color(Art.SHADE, 0.45), 0.0, 0.0)
		Art.t_rect(self, r, r.size.y / 2.0, STRIP, 4.0, 0.0)
	else:
		# The strip hangs from the top bar: square top, round bottom.
		var pts := Art.rrect_pts(Rect2(0, -40, size.x, size.y + 40), 26.0)
		Art.toon(self, pts, STRIP, 4.0, 0.0)
	var font := UiTheme.heavy_font()
	for i in 3:
		var r := tab_rect(i)
		var on := i == current
		var sink := _press[i] * 3.0
		var pop := 1.0 + _bump[i] * 0.08 * sin(_bump[i] * PI)
		Art.push(self, r.get_center() + Vector2(0, sink), 0.0, Vector2(pop, pop))
		var rr := Rect2(-r.size / 2.0, r.size)
		var face := COLORS[i] if on else IDLE
		if on:
			Art.t_rect(self, Rect2(rr.position + Vector2(0, 5 - sink), rr.size), 18.0, Art.shade_of(face, 0.4), 3.0, 0.0)
		Art.t_rect(self, rr, 18.0, face, 3.0 if on else 0.0, 0.0)
		if on:
			Art.flat(self, Art.rrect_pts(Rect2(rr.position + Vector2(8, 5), Vector2(rr.size.x - 16, rr.size.y * 0.32)), 10.0), Color(1, 1, 1, 0.22))
		# Icon on the left, the name on the right (the name shrinks to fit).
		var ic := minf(rr.size.y * 0.42, 26.0)
		var label := tr(KEYS[i])
		var fs := 24
		var room := rr.size.x - ic * 2.0 - 26.0
		while fs > 13 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			fs -= 1
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := -(ic * 2.0 + 8.0 + tw) / 2.0
		var dim := 1.0 if on else 0.8
		Art.push(self, Vector2(x0 + ic, 0.0), 0.0, Vector2.ONE * (ic / 26.0))
		draw_icon(self, i, _t if on else 0.0, dim)
		Art.pop(self)
		Art.text(self, Vector2(x0 + ic * 2.0 + 8.0, fs * 0.36), label, fs, Art.WHITE if on else Color("cfe2ff"), 6 if on else 5, false)
		Art.pop(self)
		# Badge (vault coins) or a red dot, at the tab's top-right corner.
		var corner := r.position + Vector2(r.size.x - 6.0, 4.0)
		if _badge[i] != "":
			var bs := 17
			var bw := font.get_string_size(_badge[i], HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x + 34.0
			var br := Rect2(corner - Vector2(bw - 6.0, 12.0), Vector2(bw, 26.0))
			br.position.x = minf(br.position.x, size.x - bw - 2.0)
			Art.t_rect(self, br, 13.0, Art.GOLD, 2.5, 0.0)
			Art.coin(self, br.position + Vector2(13, 13), 8.0)
			Art.text(self, br.position + Vector2(24, 19), _badge[i], bs, Art.INK, 0, false)
		elif _dot[i]:
			var s := 1.0 + 0.12 * maxf(0.0, sin(_t * 4.0)) if not Settings.reduce_motion else 1.0
			Art.t_circle(self, corner, 9.0 * s, Art.RED, 2.5, 0.3)
	for f in _flyers:
		var age := (_t - float(f["t0"])) / 0.9
		var r2 := tab_rect(int(f["tab"]))
		var to := r2.get_center() + Vector2(-r2.size.x * 0.22, 0)
		var from := to + Vector2(30.0, size.y * 0.9)
		var p := from.lerp(to, ease(age, 0.6)) + Vector2(-sin(age * PI) * 26.0, 0)
		var a := clampf((1.0 - age) * 4.0, 0.0, 1.0)
		if f["kind"] == "crate":
			Art.push(self, p, sin(age * 6.0) * 0.2, Vector2.ONE * (0.8 + 0.2 * a))
			Art.t_rect(self, Rect2(-12, -10, 24, 20), 3.0, Color(Art.WOOD, a), 2.5, 0.0)
			Art.line(self, Vector2(-12, 0), Vector2(12, 0), Color(Art.WOOD_DARK, a), 2.5)
			Art.pop(self)
		else:
			Art.coin(self, p, 10.0 * (0.8 + 0.2 * a))


## The room's icon around the origin, about 52 px (scale it with push).
## 0 = a pickaxe over a rock, 1 = a factory with a gear, 2 = a vault.
static func draw_icon(ci: CanvasItem, i: int, t: float, dim: float = 1.0) -> void:
	var k := Color(dim, dim, dim)
	match i:
		0:
			Art.toon(ci, PackedVector2Array([Vector2(-24, 22), Vector2(-16, 4), Vector2(0, -2), Vector2(18, 6), Vector2(24, 22)]), Color("9aa3b5") * k, 3.0, 0.6)
			Art.toon(ci, Art.star_pts(Vector2(8, 10), 7.0, 3.5, 4, 0.3), Color("6ee0ff") * k, 2.0, 0.0)
			Art.push(ci, Vector2(-2, -4), -0.7)
			Art.t_rect(ci, Rect2(-3.5, -4, 7, 34), 3.0, Art.WOOD * k, 3.0, 0.0)
			Art.pop(ci)
			Art.push(ci, Vector2(-10, -14), -0.7)
			var head := PackedVector2Array([Vector2(-22, 6), Vector2(-10, -4), Vector2(0, -6), Vector2(10, -4), Vector2(22, 6), Vector2(8, 0), Vector2(0, 0), Vector2(-8, 0)])
			Art.toon(ci, head, Color("dfe6f0") * k, 3.0, 0.5)
			Art.pop(ci)
		1:
			var body := PackedVector2Array([Vector2(-24, 24), Vector2(-24, -4), Vector2(-12, -14), Vector2(-12, -4), Vector2(0, -14), Vector2(0, -4), Vector2(12, -14), Vector2(12, -24), Vector2(22, -24), Vector2(22, 24)])
			Art.toon(ci, body, Color("ffb04a") * k, 3.0, 0.6)
			Art.t_rect(ci, Rect2(-18, 6, 10, 10), 2.0, Color("bff3ff") * k, 2.5, 0.0)
			Art.gear(ci, Vector2(8, 10), 9.0, Art.GOLD * k, t * 2.0, 8)
			Art.t_circle(ci, Vector2(8, 10), 3.0, Art.INK, 0.0, 0.0)
		_:
			Art.t_rect(ci, Rect2(-24, -22, 48, 44), 8.0, Color("c0c8d8") * k, 3.0, 0.6)
			Art.t_rect(ci, Rect2(-17, -15, 34, 30), 5.0, Color("8f9ab0") * k, 2.5, 0.0)
			Art.t_circle(ci, Vector2(0, 0), 9.0, Art.GOLD * k, 2.5, 0.0)
			Art.push(ci, Vector2.ZERO, t * 1.5)
			Art.line(ci, Vector2(0, 0), Vector2(0, -7), Art.INK, 2.5)
			Art.pop(ci)
			Art.coin(ci, Vector2(20, 18), 9.0)
