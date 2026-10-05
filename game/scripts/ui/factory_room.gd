class_name FactoryRoom
extends Control
## Room 2: the factory hall. Crates come in through the dock door when a
## boat trip ends (GameState.cycle_finished "boat"/"boat2"), the workers run
## them through the machine line of the plant (and of the second plant on
## the balcony once it is open), and the coins go up glass tubes in the
## ceiling to the office (room 3). Each line looks like the plant's
## building stage (FactoryArt.line).
##
## Public API (W-UI mounts this in main.gd):
##   signal stage_selected(key)   a line was tapped ("plant" / "plant2"): show it in the upgrade panel
##   func card_anchor(key) -> Rect2   where the StageCard for "plant"/"plant2" should sit (local)
##   func set_insets(top, bottom)     parts of the rect covered by the top bar / dock
##   func line_rect(key) -> Rect2     the tap area of a line (local), for hints and tutorials
##   var preview: Dictionary          screenshot/test overrides: world, stage, stage2,
##                                    plant2 (bool), working (bool), mgr (bool)
##
## Layout: "tall" (phone portrait, PC) stacks the second line on a balcony
## over the first one; "wide" (phone landscape) puts both lines side by
## side. The scene is drawn in logical units and scaled to fit (_k).

signal stage_selected(key: String)

const CARD_SIZE := Vector2(206, 150)
const TALL_H := 660.0
const TALL_FLOOR := 600.0
const TALL_MEZZ := 330.0
const TALL_MIN_W := 400.0
const TALL_MAX_W := 760.0
## Narrower than this (logical) and the hatches replace the floor door.
const NARROW_W := 560.0
const HATCH_S := 0.6
const WIDE_H := 300.0
const WIDE_FLOOR := 275.0
const WIDE_MIN_W := 960.0
const WIDE_MAX_W := 1180.0
## Line length in its own units including the tube at its right end.
const LINE_SPAN := 480.0
const TUBE_X := 446.0
const CRATE_SEC := 2.2
const CAP_SEC := 1.6

var preview: Dictionary = {}

var _t := 0.0
var _wide := false
var _k := 1.0
## Content origin (screen px) and logical size of the whole hall.
var _o := Vector2.ZERO
var _hall := Vector2(400, 660)
## Logical content width (the part with the machines), its x in the hall.
var _cw := 400.0
var _cx := 0.0
var _floor := TALL_FLOOR
var _inset_top := 0.0
var _inset_bottom := 0.0
## Per line: origin (logical, hall space), scale, floor y.
var _line := {"plant": [Vector2.ZERO, 1.0], "plant2": [Vector2.ZERO, 1.0]}
var _door := Vector2.ZERO
var _narrow := false
var _rail_y := 120.0
var _gear := {"plant": 0.0, "plant2": 0.0}
var _flash := {"plant": 0.0, "plant2": 0.0}
var _shake := {"plant": -9.0, "plant2": -9.0}
var _door_open := {"plant": 0.0, "plant2": 0.0}
var _door_until := {"plant": -9.0, "plant2": -9.0}
var _crates: Array[Dictionary] = []
var _caps := {"plant": [], "plant2": []}
var _fx: Array[Dictionary] = []
var _mood := {}
var _bg: PaintLayer
var _bg_sig := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_bg = PaintLayer.new(_paint_bg)
	add_child(_bg)
	var gs := _gs()
	if gs:
		gs.cycle_finished.connect(_on_cycle_finished)
		gs.cycle_started.connect(_on_cycle_started)
	_layout()
	if not preview.is_empty():
		demo()


## Shows a little of everything at once (screenshots): crates on their way,
## coins in the tubes, the door open.
func demo() -> void:
	_add_crate("plant")
	_crates[-1]["t0"] = _t - 1.1
	if _open2():
		_add_crate("plant2")
		_crates[-1]["t0"] = _t - 1.4
		(_caps["plant2"] as Array).append(_t - 0.9)
	(_caps["plant"] as Array).append(_t - 0.5)
	_door_open = {"plant": 1.0, "plant2": 1.0}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func set_insets(top: float, bottom: float) -> void:
	_inset_top = top
	_inset_bottom = bottom
	_layout()


# --- State (guarded so the room runs before the other branches merge) --------------

func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func world_id() -> String:
	if preview.has("world"):
		return str(preview["world"])
	var gs := _gs()
	if gs and gs.has_method("world_id"):
		return str(gs.call("world_id"))
	return "ocean"


func _stage(key: String) -> int:
	var pk := "stage" if key == "plant" else "stage2"
	if preview.has(pk):
		return int(preview[pk])
	var gs := _gs()
	return Balance.building_stage(gs.get_level(key)) if gs else 1


func _open2() -> bool:
	if preview.has("plant2"):
		return bool(preview["plant2"])
	var gs := _gs()
	return gs != null and gs.is_open("plant2")


func _working(key: String) -> bool:
	if preview.has("working"):
		return bool(preview["working"])
	var gs := _gs()
	return gs != null and gs.cycle_progress(key) >= 0.0


func _has_mgr(key: String) -> bool:
	if preview.has("mgr"):
		return bool(preview["mgr"])
	var gs := _gs()
	return gs != null and gs.has_manager(key)


# --- Layout ----------------------------------------------------------------------------

func _layout() -> void:
	var avail := Vector2(size.x, maxf(1.0, size.y - _inset_top - _inset_bottom))
	if avail.x < 2.0:
		return
	_wide = avail.x / avail.y >= 1.6
	var h := WIDE_H if _wide else TALL_H
	var min_w := WIDE_MIN_W if _wide else TALL_MIN_W
	var max_w := WIDE_MAX_W if _wide else TALL_MAX_W
	_k = minf(avail.y / h, avail.x / min_w)
	_hall = Vector2(avail.x / _k, avail.y / _k)
	_cw = minf(_hall.x, max_w)
	_cx = (_hall.x - _cw) / 2.0
	# Extra height (narrow screens) goes to the wall above.
	var dy := _hall.y - h
	_o = Vector2(0, _inset_top)
	_floor = (WIDE_FLOOR if _wide else TALL_FLOOR) + dy
	_door = Vector2(_cx + 2, _floor)
	if _wide:
		_narrow = false
		var ls := minf(1.0, (_cw - 100.0) / (LINE_SPAN * 2.0 + 10.0))
		_line["plant"] = [Vector2(_cx + 100, _floor), ls]
		_line["plant2"] = [Vector2(_cx + 100 + LINE_SPAN * ls + 10, _floor), ls]
		_rail_y = _floor - 250.0
	else:
		# Narrow phones: no room for the floor door left of the line, so the
		# crates come in through loading hatches over the crushers.
		_narrow = _cw < NARROW_W
		var x1 := _cx + (6.0 if _narrow else 88.0)
		var ls := minf(1.2, (_cx + _cw - x1 - 4.0) / LINE_SPAN)
		_line["plant"] = [Vector2(x1, _floor), ls]
		_line["plant2"] = [Vector2(x1, TALL_MEZZ + dy), ls]
		_rail_y = TALL_MEZZ + dy - 210.0 * ls
	_bg_sig = ""
	queue_redraw()


func _to_screen(p: Vector2) -> Vector2:
	return _o + p * _k


func _line_pt(key: String, local: Vector2) -> Vector2:
	var l: Array = _line[key]
	return Vector2(l[0]) + local * float(l[1])


## Tap area of a line (local px).
func line_rect(key: String) -> Rect2:
	var l: Array = _line[key]
	var ls: float = l[1]
	var top := FactoryArt.line_height(_stage(key)) + 10.0
	var a := _to_screen(Vector2(l[0]) + Vector2(-4, -top) * ls)
	var b := _to_screen(Vector2(l[0]) + Vector2(LINE_SPAN, 24) * ls)
	return Rect2(a, b - a)


## Where the StageCard of "plant"/"plant2" should sit (local px). Both
## share one card (with its "2" tab), so both return the same rect: the
## upper wall at the right, clear of the machines.
func card_anchor(_key: String) -> Rect2:
	var w := minf(CARD_SIZE.x, size.x - 16.0)
	return Rect2(size.x - w - 8.0, _inset_top + 8.0, w, CARD_SIZE.y)


# --- Events ------------------------------------------------------------------------------

func _on_cycle_finished(key: String, amount: float) -> void:
	match key:
		"boat", "boat2":
			_add_crate("plant2" if key == "boat2" and _open2() else "plant")
		"plant", "plant2":
			_flash[key] = 1.0
			(_caps[key] as Array).append(_t)
			var top := _tube_top(key)
			_float(top + Vector2(-60, 40), "+" + NumFormat.short(amount), Art.GOLD)


func _on_cycle_started(key: String, _amount: float) -> void:
	if key == "plant" or key == "plant2":
		_mood[key] = ["focus", _t + 1.0]


## A crate arrives through the dock door and goes to `key`'s hopper.
func _add_crate(key: String) -> void:
	if _crates.size() > 6:
		return
	_door_until[key] = _t + 2.4
	var gem: Color = Art.DEPTH_STYLE[randi() % Art.DEPTH_STYLE.size()].get("ore", Art.CORAL)
	var hop := _line_pt(key, FactoryArt.HOPPER)
	var hoist := false
	var path := PackedVector2Array()
	if _narrow:
		var h := _hatch(key)
		path.append(h + Vector2(FactoryArt.DOOR_W * HATCH_S / 2.0, -10))
		path.append(Vector2(hop.x, path[0].y + 6))
		path.append(hop + Vector2(0, -6))
	else:
		var start := _door + Vector2(48, 0)
		path.append(start)
		path.append(start + Vector2(30, 0))
		hoist = key == "plant2"
		if hoist:
			path.append(Vector2(start.x + 30, _rail_y + 40))
			path.append(Vector2(hop.x, _rail_y + 40))
			path.append(hop + Vector2(0, -6))
		else:
			path.append(hop + Vector2(-40, -30))
			path.append(hop + Vector2(0, -6))
	_crates.append({"t0": _t + 0.5, "path": path, "gem": gem, "hoist": hoist, "key": key})


## Bottom-left of the loading hatch over a line's crusher (narrow layout).
func _hatch(key: String) -> Vector2:
	var hop := _line_pt(key, FactoryArt.HOPPER)
	return hop + Vector2(-FactoryArt.DOOR_W * HATCH_S / 2.0, -12)


func _float(at: Vector2, s: String, c: Color) -> void:
	_fx.append({"kind": "text", "p": at, "t0": _t, "s": s, "c": c})


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var p := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		p = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		p = event.position
	if not pressed:
		return
	var key := key_at(p)
	if key == "":
		return
	accept_event()
	_fx.append({"kind": "ripple", "p": (p - _o) / _k, "t0": _t})
	if key == "plant2" and not _open2():
		_play("click")
		stage_selected.emit(key)
		return
	_shake[key] = _t
	_mood[key] = ["joy", _t + 0.8]
	var gs := _gs()
	if gs and gs.tap(key):
		_play("machine")
	else:
		_play("tap")
	stage_selected.emit(key)


## Line under a local point ("" for none). The second line takes taps
## even while closed (W-UI shows it for sale).
func key_at(p: Vector2) -> String:
	for key: String in ["plant", "plant2"]:
		if line_rect(key).grow(6.0).has_point(p):
			return key
	return ""


func _play(s: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(s)


# --- Animation ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for key: String in ["plant", "plant2"]:
		if _working(key):
			_gear[key] = float(_gear[key]) + delta * 3.0
		_flash[key] = maxf(0.0, float(_flash[key]) - delta * 2.0)
		var caps: Array = _caps[key]
		while not caps.is_empty() and _t - float(caps[0]) > CAP_SEC:
			caps.pop_front()
	for key: String in ["plant", "plant2"]:
		var want := 1.0 if _t < float(_door_until[key]) else 0.0
		_door_open[key] = move_toward(float(_door_open[key]), want, delta * 2.2)
	var i := 0
	while i < _crates.size():
		if _t - float(_crates[i]["t0"]) > CRATE_SEC:
			_crates.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _fx.size():
		if _t - float(_fx[i]["t0"]) > 1.2:
			_fx.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _tube_top(key: String) -> Vector2:
	return Vector2(_line_pt(key, Vector2(TUBE_X, 0)).x, 22.0)


# --- Drawing ----------------------------------------------------------------------------------

func _paint_bg(ci: CanvasItem) -> void:
	var lk := FactoryArt.look(world_id())
	Art.push(ci, _o, 0.0, Vector2(_k, _k))
	Art.push(ci, Vector2(0, -_inset_top / _k))
	FactoryArt.hall(ci, _hall.x, _hall.y + (_inset_top + _inset_bottom) / _k, _floor + _inset_top / _k, lk, _t, [])
	Art.pop(ci)
	var wins := []
	var step := 150.0
	var x := _cx + _cw * 0.5 - step * floorf((_cw * 0.5 - 70.0) / step)
	while x < _cx + _cw - 60.0:
		wins.append(x)
		x += step
	var top := _floor - (TALL_FLOOR - 60.0 if not _wide else WIDE_FLOOR - 44.0)
	for wx in wins:
		FactoryArt.window(ci, Rect2(float(wx) - 42, top, 84, 64), lk, 0.0)
	# Lamps between the windows, the world's sign and a clock on the wall.
	for i in wins.size() - 1:
		Art.push(ci, Vector2((float(wins[i]) + float(wins[i + 1])) / 2.0, 18))
		FactoryArt.hanging_lamp(ci, 40.0, lk)
		Art.pop(ci)
	if not _wide:
		var y2: float = Vector2(_line["plant2"][0]).y
		var mid := (y2 + _floor) / 2.0 - 30.0
		# The line's sign hangs there from the last stage of a tier.
		if FactoryArt.extras_of(_stage("plant")) < 3:
			Art.push(ci, Vector2(_line_pt("plant", Vector2(248, 0)).x, mid), 0.0, Vector2(0.8, 0.8))
			FactoryArt.emblem(ci, lk)
			Art.pop(ci)
		if not _narrow:
			Art.push(ci, Vector2(_cx + 46, mid - 40))
			FactoryArt.clock(ci, lk)
			Art.pop(ci)
	else:
		Art.push(ci, Vector2(_cx + 46, top + 40))
		FactoryArt.clock(ci, lk)
		Art.pop(ci)
	Art.pop(ci)


func _draw() -> void:
	var sig := "%s|%s|%s|%d" % [world_id(), size, _k, FactoryArt.extras_of(_stage("plant"))]
	if sig != _bg_sig:
		_bg_sig = sig
		_bg.queue_redraw()
	var lk := FactoryArt.look(world_id())
	var open2 := _open2()
	Art.push(self, _o, 0.0, Vector2(_k, _k))
	_draw_tubes(lk, open2)
	# The balcony with the second line (tall), or the second line on the floor (wide).
	var mx1 := _line_pt("plant", Vector2(TUBE_X - 18, 0)).x
	if not _wide:
		FactoryArt.mezzanine(self, _cx - 10.0, mx1, Vector2(_line["plant2"][0]).y, _floor, lk)
	if _narrow and open2:
		_draw_hatch("plant2", lk)
	_draw_line("plant2", lk)
	if open2 and not _wide:
		_draw_people("plant2")
	if not _wide:
		FactoryArt.railing(self, _cx - 10.0, mx1, Vector2(_line["plant2"][0]).y, lk)
	# The hoist rail for crates going to the second line.
	if open2 and not _narrow:
		var hx0 := _door.x + 60.0
		var hx1 := _line_pt("plant2", FactoryArt.HOPPER).x + 30.0
		Art.stroke(self, PackedVector2Array([Vector2(hx0, _rail_y), Vector2(hx1, _rail_y)]), Color("8d94a6"), 6.0, 2.0)
	# Dock door (or the first line's hatch) and the first line.
	if _narrow:
		_draw_hatch("plant", lk)
	else:
		var op := maxf(float(_door_open["plant"]), float(_door_open["plant2"]))
		Art.push(self, _door, 0.0, Vector2(0.86, 0.86))
		FactoryArt.dock_door(self, op, op * (0.5 + 0.5 * sin(_t * 10.0)), lk)
		Art.pop(self)
	_draw_line("plant", lk)
	_draw_crates()
	_draw_people("plant")
	if open2 and _wide:
		_draw_people("plant2")
	_draw_fx()
	Art.pop(self)


func _draw_hatch(key: String, lk: Dictionary) -> void:
	var op: float = _door_open[key]
	Art.push(self, _hatch(key), 0.0, Vector2(HATCH_S, HATCH_S))
	FactoryArt.dock_door(self, op, op * (0.5 + 0.5 * sin(_t * 10.0)), lk)
	Art.pop(self)


## Glass tubes taking the coins up into the ceiling. Tall layouts share one
## tube (the balcony line feeds it halfway up); wide ones have one per line.
func _draw_tubes(lk: Dictionary, open2: bool) -> void:
	var top := 10.0
	var foot := _line_pt("plant", Vector2(TUBE_X, -12))
	var caps := []
	for c in _caps["plant"]:
		caps.append((_t - float(c)) / CAP_SEC)
	if _wide:
		FactoryArt.pipe(self, foot, top, lk, caps)
		if open2:
			var caps2 := []
			for c in _caps["plant2"]:
				caps2.append((_t - float(c)) / CAP_SEC)
			FactoryArt.pipe(self, _line_pt("plant2", Vector2(TUBE_X, -12)), top, lk, caps2)
		return
	var f0 := (foot.y - Vector2(_line["plant2"][0]).y) / maxf(1.0, foot.y - top)
	for c in _caps["plant2"]:
		caps.append(lerpf(f0, 1.0, (_t - float(c)) / CAP_SEC))
	FactoryArt.pipe(self, foot, top, lk, caps)


func _draw_line(key: String, lk: Dictionary) -> void:
	var l: Array = _line[key]
	var ls: float = l[1]
	var shake := 0.0
	var since: float = _t - float(_shake[key])
	if since < 0.3:
		shake = sin(since * 60.0) * (1.0 - since / 0.3) * 2.0
	Art.push(self, Vector2(l[0]) + Vector2(shake, 0), 0.0, Vector2(ls, ls))
	if key == "plant2" and not _open2():
		FactoryArt.closed_line(self, lk)
	else:
		var working := _working(key)
		var press := absf(sin(_t * 4.0)) if working else 0.0
		FactoryArt.line(self, _stage(key), {"t": _t, "working": working, "gear": _gear[key], "press": press,
				"flash": _flash[key], "variant": 1 if key == "plant2" else 0, "flame": lk["flame"]})
	Art.pop(self)


func _crate_pos(c: Dictionary) -> Array:
	var f := clampf((_t - float(c["t0"])) / CRATE_SEC, 0.0, 1.0)
	var path: PackedVector2Array = c["path"]
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var d := f * total
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if d <= seg or i == path.size() - 2:
			return [path[i].lerp(path[i + 1], clampf(d / maxf(seg, 0.001), 0.0, 1.0)), f]
		d -= seg
	return [path[path.size() - 1], f]


func _draw_crates() -> void:
	for c: Dictionary in _crates:
		if _t < float(c["t0"]):
			continue
		var r := _crate_pos(c)
		var p: Vector2 = r[0]
		var f: float = r[1]
		var ls: float = _line[c["key"]][1]
		var s := ls * (1.0 if f < 0.85 else lerpf(1.0, 0.3, (f - 0.85) / 0.15))
		if bool(c["hoist"]) and f > 0.12:
			Art.line(self, Vector2(p.x, _rail_y), p + Vector2(0, -28 * s), Art.INK, 2.5)
			Art.t_rect(self, Rect2(p.x - 8, _rail_y - 6, 16, 12), 3, Color("5a5f7a"), 2.0, 0.0)
		Art.push(self, p)
		FactoryArt.crate(self, s, c["gem"])
		Art.pop(self)


func _mood_of(key: String, fallback: String) -> String:
	var m = _mood.get(key)
	if m is Array and _t < float(m[1]):
		return str(m[0])
	return fallback


func _draw_people(key: String) -> void:
	var ls: float = _line[key][1]
	var working := _working(key)
	var tapped := _t - float(_shake[key]) < 0.5
	var hop := 6.0 * sin((_t - float(_shake[key])) / 0.5 * PI) if tapped else 0.0
	var gs := _gs()
	var idle := "bored"
	if gs and float(gs.get("dock")) <= 0.0:
		idle = "sleepy"
	var emo := _mood_of(key, "focus" if working else idle)
	var swing := absf(sin(_t * 7.0)) if working else 0.0
	var stage := _stage(key)
	# The hammer worker between the furnace and the polisher.
	var wl := Chars.look(3, "short", 1, "hardhat", "none", 2, "overalls") if key == "plant" else Chars.look(2, "bun", 3, "hardhat", "none", 7, "overalls")
	var wp := _line_pt(key, Vector2(200, 8)) - Vector2(0, hop)
	Chars.person(self, wp, 0.82 * ls, 1.0, wl, {"emotion": emo, "blink": Chars.blinking(_t, 4.0 if key == "plant" else 6.0),
			"arm_r": 2.2 - swing * 1.6, "arm_l": 0.3, "hold": "hammer", "bob": swing})
	if emo == "sleepy":
		_mark("zzz", wp + Vector2(10, -84) * ls, ls)
	# The dock hand waves the crates in (first line only), from stage 2 on
	# a second helper with a wrench at the press.
	if key == "plant" and not _narrow:
		var dp := Vector2(_door.x + 40, _floor + 8) if not _narrow else _line_pt(key, Vector2(-2, 10))
		var busy := float(_door_open[key]) > 0.1
		var wave := sin(_t * 9.0) * 0.5 if busy else 0.0
		Chars.person(self, dp, 0.8 * ls, 1.0, Chars.look(4, "curly", 0, "cap", "none", 1, "overalls"),
				{"emotion": "joy" if busy else _mood_of(key, "happy"), "blink": Chars.blinking(_t, 2.0),
				"arm_r": 2.6 + wave if busy else 0.2, "arm_l": -0.3, "bob": 0.0})
	if stage >= 4:
		var hp := _line_pt(key, Vector2(306, 10)) - Vector2(0, hop * 0.6)
		var turn := sin(_t * 3.0) * 0.5 if working else 0.0
		Chars.person(self, hp, 0.76 * ls, -1.0, Chars.look(1, "spiky", 2, "hardhat", "freckles", 5 if key == "plant" else 3, "overalls"),
				{"emotion": _mood_of(key, "happy" if working else idle), "blink": Chars.blinking(_t, 7.0),
				"arm_r": 1.4 + turn, "arm_l": 0.2, "hold": "wrench", "bob": 0.0})
	# The plant's manager with a clipboard once hired.
	if _has_mgr(key):
		var mp := _line_pt(key, Vector2(110, 12))
		var look := Chars.manager_look(key)
		var check := fposmod(_t, 6.0) < 3.0
		Chars.person(self, mp, 0.8 * ls, -1.0, look, {"emotion": "happy" if working else "bored",
				"blink": Chars.blinking(_t, 11.0), "arm_r": 1.2 if check else 0.2, "arm_l": -0.2, "hold": "clipboard", "bob": 0.0})


func _mark(kind: String, at: Vector2, s: float) -> void:
	Art.push(self, at, 0.0, Vector2(s, s))
	Chars.mark(self, kind, Vector2.ZERO, _t)
	Art.pop(self)


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
				Art.text(self, Vector2.ZERO, str(f["s"]), 26, f["c"], 6)
				Art.pop(self)
