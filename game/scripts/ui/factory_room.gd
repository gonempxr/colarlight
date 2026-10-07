class_name FactoryRoom
extends Control
## Room 2: the factory hall. Crates come in through the dock door when a
## boat trip ends (GameState.cycle_finished "boat"/"boat2"; the boat itself
## moors at the quay outside the door), ride a feed belt into the crusher,
## the workers run them through the machine line of the plant (and of the
## second plant on the balcony once it is open), and the coins go up a
## glass pipe to the office (room 3). Each line looks like the plant's
## building stage (FactoryArt.line_*), and the hall fills up with racks, a
## control desk, flags and a neon sign as the first plant grows.
##
## Public API (W-UI mounts this in main.gd):
##   signal stage_selected(key)   a line was tapped ("plant" / "plant2"): show it in the upgrade panel
##   func card_anchor(key) -> Rect2   where the StageCard for "plant"/"plant2" should sit (local)
##   func set_insets(top, bottom)     parts of the rect covered by the top bar / dock
##   func line_rect(key) -> Rect2     the tap area of a line (local), for hints and tutorials
##   var preview: Dictionary          screenshot/test overrides: world, stage, stage2,
##                                    plant2 (bool), working (bool), mgr (bool), dock (crates 0..6)
##
## Layout: "tall" (phone portrait, PC) stacks the second line on a balcony
## over the first one; "wide" (phone landscape) puts both lines side by
## side. The scene is drawn in logical units and scaled to fit (_k).
##
## Drawing cost: what stands still (the hall, windows, machine bodies,
## racks, signs) is painted once into _bg (behind) and _front (the balcony
## railing, in front); _draw only paints the small moving parts.

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
const CRATE_SEC := 2.4
const CAP_SEC := 1.6
## How long a boat stays moored at the door after a trip.
const MOOR_SEC := 2.6
const DOOR_S := 0.86

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
## Per line: origin (logical, hall space), scale.
var _line := {"plant": [Vector2.ZERO, 1.0], "plant2": [Vector2.ZERO, 1.0]}
var _door := Vector2.ZERO
var _narrow := false
var _rail_y := 120.0
var _gear := {"plant": 0.0, "plant2": 0.0}
var _flash := {"plant": 0.0, "plant2": 0.0}
var _shake := {"plant": -9.0, "plant2": -9.0}
var _door_open := {"plant": 0.0, "plant2": 0.0}
var _door_until := {"plant": -9.0, "plant2": -9.0}
var _moor_until := {"plant": -9.0, "plant2": -9.0}
var _crates: Array[Dictionary] = []
var _caps := {"plant": [], "plant2": []}
var _fx: Array[Dictionary] = []
var _mood := {}
var _bg: PaintLayer
var _front: PaintLayer
var _bg_sig := ""
## Wall dressing placed by _plan_dressing (logical): windows (Rect2), lamps
## ([x, cord]), columns (x), wall pipe runs ([x0, x1, y]) and props
## ({"kind", "p", ..., "min": first plant stage}). The fan, clock and
## control desk also tick in _draw.
var _wins: Array = []
var _lamps: Array = []
var _cols: Array = []
var _pipes: Array = []
var _props: Array = []
var _steam_next := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_bg = PaintLayer.new(_paint_bg)
	add_child(_bg)
	_front = PaintLayer.new(_paint_front, false)
	add_child(_front)
	var gs := _gs()
	if gs:
		gs.cycle_finished.connect(_on_cycle_finished)
		gs.cycle_started.connect(_on_cycle_started)
	_layout()
	if not preview.is_empty():
		demo()


## Shows a little of everything at once (screenshots): crates on their way,
## coins in the tubes, the door open, a boat at the quay.
func demo() -> void:
	_add_crate("plant")
	_crates[-1]["t0"] = _t - 1.1
	if _open2():
		_add_crate("plant2")
		_crates[-1]["t0"] = _t - 1.4
		(_caps["plant2"] as Array).append(_t - 0.9)
	(_caps["plant"] as Array).append(_t - 0.5)
	_door_open = {"plant": 1.0, "plant2": 1.0}
	_door_until = {"plant": _t + 30.0, "plant2": _t + 30.0}
	_moor_until = {"plant": _t + 30.0, "plant2": _t + 30.0}


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


## Crates of ore waiting at the shore (0..6), from GameState.dock.
func _waiting() -> int:
	if preview.has("dock"):
		return int(preview["dock"])
	var gs := _gs()
	if gs == null:
		return 0
	var d := float(gs.get("dock"))
	if d <= 0.0:
		return 0
	var cap := maxf(1.0, float(gs.cycle_capacity("plant")))
	return clampi(ceili(d / cap), 1, 6)


## 0..1: a boat at the quay outside the door of `key`'s crates.
func _boat(key: String) -> float:
	var stay := clampf((float(_moor_until[key]) - _t) / 0.6, 0.0, 1.0)
	var gs := _gs()
	if gs == null or not preview.is_empty():
		return stay
	var p := float(gs.cycle_progress("boat2" if key == "plant2" else "boat"))
	return maxf(stay, smoothstep(0.8, 1.0, p) if p >= 0.0 else 0.0)


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
	_plan_dressing()
	_bg_sig = ""
	queue_redraw()


## Places the windows, lamps, columns, the wall pipes and the props in the
## free parts of the wall and floor for the current layout.
func _plan_dressing() -> void:
	_wins.clear()
	_lamps.clear()
	_cols.clear()
	_pipes.clear()
	_props.clear()
	var W := _hall.x
	var ls: float = _line["plant"][1]
	var tube := _line_pt("plant", Vector2(TUBE_X, 0)).x
	if _wide:
		var l2: Vector2 = _line["plant2"][0]
		var l1: Vector2 = _line["plant"][0]
		var top := 64.0
		var line_top := _floor - FactoryArt.line_height(maxi(_stage("plant"), _stage("plant2"))) * ls - 16.0
		var wh := clampf((line_top - top) * 0.5, 0.0, 110.0)
		var pipe_y := _floor - 84.0
		if wh >= 44.0:
			var ww := minf(170.0, wh * 1.6)
			var n := maxi(1, int((W - 40.0) / (ww + 90.0)))
			var gap := (W - n * ww) / float(n + 1)
			for i in n:
				var x := gap + i * (ww + gap)
				_wins.append(Rect2(x, top, ww, wh))
				if i < n - 1:
					_lamps.append([x + ww + gap / 2.0, 28.0])
			pipe_y = top + wh + 40.0
		_props.append({"kind": "pennants", "x0": 14.0, "x1": W - 14.0, "y": 58.0, "min": 9})
		_cols = [_cx + 94.0, l2.x - 6.0]
		_pipes.append([0.0, W, pipe_y])
		var band := line_top - pipe_y
		if band > 60.0:
			var wy := pipe_y + 20.0 + band * 0.5
			var span := TUBE_X * ls
			_props.append({"kind": "fan", "p": Vector2(l1.x + span * 0.2, wy), "r": 18.0})
			_props.append({"kind": "sign", "p": Vector2(l1.x + span * 0.62, wy), "sign": "helmet"})
			_props.append({"kind": "emblem", "p": Vector2(l2.x + span * 0.3, wy), "s": 0.62})
			_props.append({"kind": "neon", "p": Vector2(l2.x + span * 0.68, wy), "min": 13})
			_props.append({"kind": "sign", "p": Vector2(l2.x + span * 0.68, wy), "sign": "coins", "max": 12})
		_props.append({"kind": "clock", "p": Vector2(_cx + 42, _floor - _door_top() - 32.0)})
		var right := _line_pt("plant2", Vector2(TUBE_X + 30, 0)).x
		if W - right > 90.0:
			_props.append({"kind": "rack", "p": Vector2(right, _floor + 2.0), "w": minf(140.0, W - right - 16.0), "h": 120.0, "min": 3})
		return
	var my: float = Vector2(_line["plant2"][0]).y
	# Columns at the hall's edges (when there is wall beside the lines).
	if _cx > 40.0:
		_cols.append(_cx - 22.0)
	if W - tube > 70.0:
		_cols.append(tube + 46.0)
	# Windows in the top band, over the balcony line.
	var top := 66.0
	var wh := clampf(my - FactoryArt.line_height(_stage("plant2")) * ls - top - 26.0, 56.0, 96.0)
	var ww := clampf(wh * 1.5, 96.0, 150.0)
	var n := maxi(1, int((W - 20.0) / (ww + 60.0)))
	var gap := (W - n * ww) / float(n + 1)
	for i in n:
		var x := gap + i * (ww + gap)
		_wins.append(Rect2(x, top, ww, wh))
		if i < n - 1:
			_lamps.append([x + ww + gap / 2.0, 28.0])
	if n == 1:
		_lamps.append([gap * 0.5, 28.0])
	_props.append({"kind": "pennants", "x0": 14.0, "x1": W - 14.0, "y": 58.0, "min": 9})
	# Between the floors: the wall pipes, a fan, signs, the clock.
	var y_mid := my + 16.0
	var y_low := _floor - FactoryArt.line_height(_stage("plant")) * ls
	_pipes.append([0.0, W, y_mid + 26.0])
	var band := y_low - y_mid
	var wall_y := y_mid + 26.0 + clampf(band * 0.5, 40.0, 70.0)
	var l1x: float = Vector2(_line["plant"][0]).x
	var span := tube - l1x
	if band > 70.0:
		if _narrow:
			_props.append({"kind": "fan", "p": Vector2(l1x + 104.0, wall_y), "r": 18.0})
			_props.append({"kind": "sign", "p": Vector2(l1x + 168.0, wall_y), "sign": "helmet", "max": 12})
			_props.append({"kind": "neon", "p": Vector2(l1x + 166.0, wall_y), "min": 13})
			_props.append({"kind": "emblem", "p": Vector2(l1x + 236.0, wall_y + 2.0), "s": 0.62})
		else:
			_props.append({"kind": "fan", "p": Vector2(l1x + span * 0.06, wall_y), "r": 18.0})
			_props.append({"kind": "sign", "p": Vector2(l1x + span * 0.46, wall_y), "sign": "helmet"})
			_props.append({"kind": "emblem", "p": Vector2(l1x + span * 0.68, wall_y + 2.0), "s": 0.62})
			_props.append({"kind": "neon", "p": Vector2(l1x + span * 0.27, wall_y), "min": 13})
	if not _narrow:
		# Over the dock door: a clock; left of it, the extinguisher.
		_props.append({"kind": "clock", "p": Vector2(_cx + 44, _floor - _door_top() - 34.0)})
		if _cx > 50.0:
			_props.append({"kind": "extinguisher", "p": Vector2(_cx - 20.0 if _cx < 90.0 else _cx - 50.0, _floor - 64.0)})
	else:
		_props.append({"kind": "clock", "p": Vector2(l1x + 300.0, wall_y - 2.0)})
	# Beside the lines (PC): racks, the control desk, a window, a pallet jack.
	var free := W - (tube + 34.0)
	if free > 100.0:
		var x := tube + 34.0
		_props.append({"kind": "panel", "p": Vector2(x + 46.0, _floor + 6.0), "min": 5})
		if free > 200.0:
			_props.append({"kind": "rack", "p": Vector2(x + 100.0, _floor + 2.0), "w": minf(150.0, free - 112.0), "h": 150.0, "min": 3})
		_props.append({"kind": "rack", "p": Vector2(x + 12.0, my + 2.0), "w": minf(170.0, free - 28.0), "h": 110.0, "min": 3})
		_props.append({"kind": "window", "r": Rect2(x + 20.0, y_mid + 48.0, minf(150.0, free - 44.0), 86.0)})
	if not _narrow and _cx > 100.0:
		_props.append({"kind": "rack", "p": Vector2(14.0, my + 2.0), "w": minf(130.0, _cx - 26.0), "h": 110.0, "min": 3})


## Height of the dock door's frame top above the floor.
func _door_top() -> float:
	return (FactoryArt.DOOR_H + 30.0) * DOOR_S


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
			var line := "plant2" if key == "boat2" and _open2() else "plant"
			_moor_until[line] = _t + MOOR_SEC
			_add_crate(line)
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
	_door_until[key] = _t + 2.6
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
		path.append(_door + Vector2(40, 0))
		path.append(_door + Vector2(FactoryArt.DOOR_W * DOOR_S + 4.0, 0))
		hoist = key == "plant2" and not _wide
		if hoist:
			path.append(Vector2(path[1].x, _rail_y + 40))
			path.append(Vector2(hop.x, _rail_y + 40))
			path.append(hop + Vector2(0, -6))
		else:
			var feed := _feed(key)
			path.append(feed[0])
			path.append(feed[1])
			path.append(hop + Vector2(0, -6))
	_crates.append({"t0": _t + 0.5, "path": path, "gem": gem, "hoist": hoist, "key": key})


## The sloped feed belt from the door up to a floor line's hopper: [foot, top].
func _feed(key: String) -> Array:
	var hop := _line_pt(key, FactoryArt.HOPPER)
	var ls: float = _line[key][1]
	var foot := Vector2(_door.x + FactoryArt.DOOR_W * DOOR_S + 6.0, _floor - 10.0)
	if key == "plant2":
		foot = Vector2(hop.x - 80.0 * ls, _floor - 10.0)
	return [foot, hop + Vector2(-26.0, -22.0) * ls]


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
	var lp := (p - _o) / _k
	_fx.append({"kind": "ripple", "p": lp, "t0": _t})
	if key == "plant2" and not _open2():
		_play("click")
		stage_selected.emit(key)
		return
	_shake[key] = _t
	_mood[key] = ["joy", _t + 0.8]
	for i in 6:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		_fx.append({"kind": "spark", "p": lp, "v": Vector2(cos(a), sin(a)) * randf_range(90, 200), "t0": _t})
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
		var want := 1.0 if _t < float(_door_until[key]) else 0.0
		_door_open[key] = move_toward(float(_door_open[key]), want, delta * 2.2)
	if _t >= _steam_next and not _pipes.is_empty():
		# A valve on the wall pipes lets off a little steam now and then.
		_steam_next = _t + randf_range(3.0, 6.0)
		var run: Array = _pipes[0]
		_fx.append({"kind": "steam", "p": Vector2(lerpf(float(run[0]) + 40.0, float(run[1]) - 40.0, randf()), float(run[2]) - 8.0), "t0": _t})
	var i := 0
	while i < _crates.size():
		if _t - float(_crates[i]["t0"]) > CRATE_SEC:
			_crates.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _fx.size():
		if _t - float(_fx[i]["t0"]) > 1.4:
			_fx.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _tube_top(key: String) -> Vector2:
	return Vector2(_line_pt(key, Vector2(TUBE_X, 0)).x, 22.0)


# --- Drawing ----------------------------------------------------------------------------------

func _sig() -> String:
	return "%s|%s|%s|%s|%d|%d|%s|%d|%s|%s" % [world_id(), size, _k, _inset_top, _stage("plant"), _stage("plant2"), _open2(),
			_waiting(), "" if _open2() else _price2(), TranslationServer.get_locale()]


func _price2() -> String:
	var gs := _gs()
	if gs == null or not gs.has_method("unlock_cost"):
		return ""
	var c := float(gs.unlock_cost("plant2"))
	return NumFormat.short(c) if c > 0.0 else ""


func _show(p: Dictionary) -> bool:
	var s := _stage("plant")
	return s >= int(p.get("min", 0)) and s <= int(p.get("max", 99))


## The still parts behind everything: hall, dressing, door frame, belts and
## the machine bodies.
func _paint_bg(ci: CanvasItem) -> void:
	var lk := FactoryArt.look(world_id())
	var open2 := _open2()
	Art.push(ci, _o, 0.0, Vector2(_k, _k))
	Art.push(ci, Vector2(0, -_inset_top / _k))
	FactoryArt.hall(ci, _hall.x, _hall.y + (_inset_top + _inset_bottom) / _k, _floor + _inset_top / _k, lk, _cols)
	Art.pop(ci)
	# Windows and their light on the floor.
	for r: Rect2 in _wins:
		FactoryArt.window(ci, r, lk)
	for p: Dictionary in _props:
		if str(p["kind"]) == "window":
			FactoryArt.window(ci, p["r"], lk)
	for r: Rect2 in _wins:
		FactoryArt.shaft(ci, r, _floor, lk)
	for run: Array in _pipes:
		var valves := []
		var x := float(run[0]) + 150.0
		while x < float(run[1]) - 60.0:
			valves.append(x)
			x += 330.0
		FactoryArt.wall_pipes(ci, float(run[0]), float(run[1]), float(run[2]), lk, valves)
	for p: Dictionary in _props:
		if _show(p):
			_paint_prop(ci, p, lk)
	for l: Array in _lamps:
		Art.push(ci, Vector2(float(l[0]), 50))
		FactoryArt.hanging_lamp(ci, float(l[1]), lk, 170.0)
		Art.pop(ci)
	# The balcony (tall) and the second line.
	var mx1 := _line_pt("plant", Vector2(TUBE_X - 18, 0)).x
	if not _wide:
		FactoryArt.mezzanine(ci, _cx - 10.0, mx1, Vector2(_line["plant2"][0]).y, _floor, lk)
	if _narrow and open2:
		_paint_hatch(ci, "plant2", lk)
	_paint_line(ci, "plant2", lk)
	if open2 and not _narrow and not _wide:
		Art.stroke(ci, PackedVector2Array([Vector2(_door.x + 60.0, _rail_y), Vector2(_line_pt("plant2", FactoryArt.HOPPER).x + 30.0, _rail_y)]), Color("8d94a6"), 6.0, 2.0)
	# Dock door (or the first line's hatch), the feed belts and the first line.
	if _narrow:
		_paint_hatch(ci, "plant", lk)
	else:
		Art.push(ci, _door, 0.0, Vector2(DOOR_S, DOOR_S))
		FactoryArt.dock_door_back(ci, lk)
		Art.pop(ci)
		_paint_feed(ci, "plant", lk)
		if open2 and _wide:
			_paint_feed(ci, "plant2", lk)
	_paint_line(ci, "plant", lk)
	Art.pop(ci)


func _paint_prop(ci: CanvasItem, p: Dictionary, lk: Dictionary) -> void:
	match str(p["kind"]):
		"rack":
			Art.push(ci, p["p"])
			FactoryArt.rack(ci, float(p["w"]), float(p["h"]), lk, int(Vector2(p["p"]).x))
			Art.pop(ci)
		"panel":
			Art.push(ci, p["p"])
			FactoryArt.control_panel(ci, lk)
			Art.pop(ci)
		"clock":
			Art.push(ci, p["p"])
			FactoryArt.clock(ci, lk)
			Art.pop(ci)
		"fan":
			Art.push(ci, p["p"])
			FactoryArt.fan(ci, float(p["r"]), lk)
			Art.pop(ci)
		"sign":
			Art.push(ci, p["p"], 0.0, Vector2(0.8, 0.8))
			FactoryArt.sign_board(ci, str(p["sign"]), lk)
			Art.pop(ci)
		"emblem":
			Art.push(ci, p["p"], 0.0, Vector2.ONE * float(p.get("s", 0.8)))
			FactoryArt.emblem(ci, lk)
			Art.pop(ci)
		"neon":
			Art.push(ci, p["p"], 0.0, Vector2(0.7, 0.7))
			FactoryArt.neon(ci, lk)
			Art.pop(ci)
		"extinguisher":
			Art.push(ci, p["p"])
			FactoryArt.extinguisher(ci)
			Art.pop(ci)
		"pennants":
			FactoryArt.pennants(ci, float(p["x0"]), float(p["x1"]), float(p["y"]), 10.0)
		"jack":
			Art.push(ci, p["p"])
			FactoryArt.pallet_jack(ci, lk)
			Art.pop(ci)


## The sloped belt from the door to a floor line's hopper, and the crates
## waiting by the door for the next cycle.
func _paint_feed(ci: CanvasItem, key: String, lk: Dictionary) -> void:
	var f := _feed(key)
	var a: Vector2 = f[0]
	var b: Vector2 = f[1]
	var d := b - a
	var len := d.length()
	# Legs down to the floor.
	for u: float in [0.3, 0.75]:
		var p := a.lerp(b, u)
		Art.t_rect(ci, Rect2(p.x - 3, p.y, 6, _floor - p.y), 1, Art.shade_of(lk["col"], 0.1), 1.8, 0.0)
	Art.push(ci, a, d.angle())
	Art.t_rect(ci, Rect2(-6, -2, len + 12, 12), 6, Color("3a3f5c"), 2.6, 0.2)
	Art.t_circle(ci, Vector2(0, 4), 5, Art.METAL, 1.6, 0.0)
	Art.t_circle(ci, Vector2(len, 4), 5, Art.METAL, 1.6, 0.0)
	Art.pop(ci)
	if key == "plant":
		var n := _waiting()
		if n > 0 and _cx > 60.0:
			Art.push(ci, Vector2(maxf(4.0, _cx - 150.0), _floor + 8.0))
			FactoryArt.crate_stack(ci, n, [Art.CORAL, Color("5ad2ff"), Art.GOLD, Color("b78cff")])
			Art.pop(ci)


func _paint_hatch(ci: CanvasItem, key: String, lk: Dictionary) -> void:
	Art.push(ci, _hatch(key), 0.0, Vector2(HATCH_S, HATCH_S))
	FactoryArt.dock_door_back(ci, lk)
	Art.pop(ci)


func _paint_line(ci: CanvasItem, key: String, lk: Dictionary) -> void:
	var l: Array = _line[key]
	var ls: float = l[1]
	Art.push(ci, Vector2(l[0]), 0.0, Vector2(ls, ls))
	if key == "plant2" and not _open2():
		FactoryArt.closed_line(ci, lk, tr("FACTORY_LINE2"), _price2())
	else:
		FactoryArt.line_back(ci, _stage(key), 1 if key == "plant2" else 0, lk)
	Art.pop(ci)


## In front of everything: the balcony railing.
func _paint_front(ci: CanvasItem) -> void:
	if _wide:
		return
	var lk := FactoryArt.look(world_id())
	Art.push(ci, _o, 0.0, Vector2(_k, _k))
	var mx1 := _line_pt("plant", Vector2(TUBE_X - 18, 0)).x
	FactoryArt.railing(ci, _cx - 10.0, mx1, Vector2(_line["plant2"][0]).y, lk)
	Art.pop(ci)


func _draw() -> void:
	var sig := _sig()
	if sig != _bg_sig:
		_bg_sig = sig
		_bg.queue_redraw()
		_front.queue_redraw()
	var lk := FactoryArt.look(world_id())
	var open2 := _open2()
	var w1 := _working("plant")
	Art.push(self, _o, 0.0, Vector2(_k, _k))
	_draw_wall_live(lk, w1)
	# The balcony: the second line's moving parts and its crew.
	if _narrow and open2:
		_draw_hatch("plant2", lk)
	_draw_line("plant2", lk)
	if open2 and not _wide:
		_draw_people("plant2")
	_draw_tubes(lk, open2)
	# The door (or the first hatch), the belts, the crates, the first line.
	if _narrow:
		_draw_hatch("plant", lk)
	else:
		var op := maxf(float(_door_open["plant"]), float(_door_open["plant2"]))
		Art.push(self, _door, 0.0, Vector2(DOOR_S, DOOR_S))
		FactoryArt.dock_door(self, op, op * (0.5 + 0.5 * sin(_t * 10.0)), lk, maxf(_boat("plant"), _boat("plant2")))
		Art.pop(self)
		_draw_feed("plant", w1 or op > 0.1)
		if open2 and _wide:
			_draw_feed("plant2", _working("plant2") or op > 0.1)
	_draw_line("plant", lk)
	_draw_crates()
	_draw_people("plant")
	if open2 and _wide:
		_draw_people("plant2")
	_draw_fx()
	Art.pop(self)


## Fans, clock hands, the control desk's lights.
func _draw_wall_live(lk: Dictionary, on: bool) -> void:
	for p: Dictionary in _props:
		if not _show(p):
			continue
		match str(p["kind"]):
			"fan":
				Art.push(self, p["p"])
				FactoryArt.fan_blades(self, float(p["r"]), _t * (9.0 if on else 1.5), lk)
				FactoryArt.fan_grill(self, float(p["r"]))
				Art.pop(self)
			"clock":
				Art.push(self, p["p"])
				FactoryArt.clock_hands(self, _t + 600.0)
				Art.pop(self)
			"panel":
				Art.push(self, p["p"])
				FactoryArt.panel_live(self, _t, on, lk)
				Art.pop(self)


func _draw_feed(key: String, running: bool) -> void:
	var f := _feed(key)
	var a: Vector2 = f[0]
	var b: Vector2 = f[1]
	Art.push(self, a, (b - a).angle())
	FactoryArt.belt_live(self, Vector2(-6, 10), (b - a).length() + 12.0, 10.0, _t, running)
	Art.pop(self)


func _draw_hatch(key: String, lk: Dictionary) -> void:
	var op: float = _door_open[key]
	Art.push(self, _hatch(key), 0.0, Vector2(HATCH_S, HATCH_S))
	FactoryArt.dock_door(self, op, op * (0.5 + 0.5 * sin(_t * 10.0)), lk, _boat(key))
	Art.pop(self)


## Glass tubes taking the coins up into the ceiling. Tall layouts share one
## tube (the balcony line feeds it halfway up); wide ones have one per line.
func _draw_tubes(lk: Dictionary, open2: bool) -> void:
	var top := 10.0
	var foot := _line_pt("plant", Vector2(TUBE_X, -12))
	var caps := []
	for c in _caps["plant"]:
		caps.append((_t - float(c)) / CAP_SEC)
	var w1 := _working("plant")
	var w2 := open2 and _working("plant2")
	if _wide:
		FactoryArt.pipe(self, foot, top, lk, caps, _t, w1)
		_draw_pipe_gauge(foot, top, w1, lk)
		if open2:
			var caps2 := []
			for c in _caps["plant2"]:
				caps2.append((_t - float(c)) / CAP_SEC)
			FactoryArt.pipe(self, _line_pt("plant2", Vector2(TUBE_X, -12)), top, lk, caps2, _t + 0.3, w2)
		return
	var f0 := (foot.y - Vector2(_line["plant2"][0]).y) / maxf(1.0, foot.y - top)
	for c in _caps["plant2"]:
		caps.append(lerpf(f0, 1.0, (_t - float(c)) / CAP_SEC))
	FactoryArt.pipe(self, foot, top, lk, caps, _t, w1 or w2)
	_draw_pipe_gauge(foot, top, w1 or w2, lk)


## A pressure gauge clamped to the product pipe.
func _draw_pipe_gauge(foot: Vector2, top: float, on: bool, lk: Dictionary) -> void:
	var y := lerpf(foot.y, top, 0.3) if _wide else (Vector2(_line["plant2"][0]).y + _floor) / 2.0 + 10.0
	var side := -1.0 if foot.x + 44.0 > _hall.x else 1.0
	Art.push(self, Vector2(foot.x + 24.0 * side, y))
	Art.t_rect(self, Rect2(-14 if side > 0 else 4, -3, 10, 6), 1, Art.BRASS, 1.6, 0.0)
	FactoryArt.gauge(self, 13, lk)
	FactoryArt.gauge_needle(self, 13, (0.6 + 0.15 * sin(_t * 1.7)) if on else 0.1)
	Art.pop(self)


func _draw_line(key: String, lk: Dictionary) -> void:
	var l: Array = _line[key]
	var ls: float = l[1]
	Art.push(self, Vector2(l[0]), 0.0, Vector2(ls, ls))
	if key == "plant2" and not _open2():
		Art.push(self, Vector2(200, -194))
		FactoryArt.build_badge(self, _t)
		Art.pop(self)
	else:
		var working := _working(key)
		# The press: a slow lift, a quick stamp.
		var ph := fposmod(_t * 0.9, 1.0)
		var press := (1.0 - ph / 0.8 if ph < 0.8 else (ph - 0.8) / 0.2) if working else 0.0
		FactoryArt.line_live(self, _stage(key), {"t": _t, "working": working, "gear": _gear[key], "press": press,
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
			Art.push(self, Vector2(p.x, _rail_y))
			Art.t_rect(self, Rect2(-8, -6, 16, 12), 3, Color("5a5f7a"), 2.0, 0.0)
			Art.pop(self)
		Art.push(self, p)
		FactoryArt.crate(self, Props._q(s, 20), c["gem"])
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
	if gs and float(gs.get("dock")) <= 0.0 and preview.is_empty():
		idle = "sleepy"
	var emo := _mood_of(key, "focus" if working else idle)
	var stage := _stage(key)
	var n := FactoryArt.machines_at(stage)
	var seed := 0.0 if key == "plant" else 1.7
	# The smith hammers the hot ingots on the belt after the furnace.
	var ph := fposmod(_t * 1.6 + seed, 1.0)
	var swing := (ph / 0.75 if ph < 0.75 else 1.0 - (ph - 0.75) / 0.25) if working else 0.0
	var wl := Chars.look(3, "short", 1, "hardhat", "none", 2, "overalls") if key == "plant" else Chars.look(2, "bun", 3, "hardhat", "none", 7, "overalls")
	var sx := minf(200.0, FactoryArt.SLOTS[n - 1] + 52.0)
	var wp := _line_pt(key, Vector2(sx, 8)) - Vector2(0, hop)
	Chars.person(self, wp, 0.82 * ls, 1.0, wl, {"emotion": emo, "blink": Chars.blinking(_t, 4.0 if key == "plant" else 6.0),
			"arm_r": snappedf(0.5 + swing * 1.9, 0.05), "arm_l": 0.3, "hold": "hammer", "bob": (1.0 - swing) * 0.5})
	if working and swing < 0.08:
		var hit := wp + Vector2(20, -20) * ls
		for k in 3:
			Art.dot(self, hit + Vector2(-6 + k * 6, -4 - (k % 2) * 5) * ls, 2.5 * ls, Color("fff1a8"))
	if emo == "sleepy":
		_mark("zzz", wp + Vector2(10, -84) * ls, ls)
	# The dock hand waves the crates in (first line only, by the door).
	if key == "plant" and not _narrow:
		var dp := Vector2(_door.x + 38, _floor + 10)
		var busy := float(_door_open["plant"]) > 0.1 or float(_door_open["plant2"]) > 0.1
		var wave := sin(_t * 9.0) * 0.5 if busy else 0.0
		Chars.person(self, dp, 0.8 * ls, 1.0, Chars.look(4, "curly", 0, "cap", "none", 1, "overalls"),
				{"emotion": "joy" if busy else _mood_of(key, "happy"), "blink": Chars.blinking(_t, 2.0),
				"arm_r": snappedf(2.6 + wave, 0.05) if busy else 0.2, "arm_l": -0.3, "bob": 0.0})
	# From stage 4 a fitter turns a wrench at the press.
	if stage >= 4:
		var hp := _line_pt(key, Vector2(306, 10)) - Vector2(0, hop * 0.6)
		var turn := snappedf(sin(_t * 3.0 + seed) * 0.5, 0.05) if working else 0.0
		Chars.person(self, hp, 0.76 * ls, -1.0, Chars.look(1, "spiky", 2, "hardhat", "freckles", 5 if key == "plant" else 3, "overalls"),
				{"emotion": _mood_of(key, "happy" if working else idle), "blink": Chars.blinking(_t, 7.0),
				"arm_r": 1.4 + turn, "arm_l": 0.2, "hold": "wrench", "bob": 0.0})
	# From stage 9 a stoker feeds the furnace with a ladle.
	if stage >= 9:
		var sp := _line_pt(key, Vector2(98, 10)) - Vector2(0, hop * 0.8)
		var stoke := snappedf(0.5 + 0.5 * sin(_t * 2.2 + seed), 0.05) if working else 0.0
		Chars.person(self, sp, 0.76 * ls, 1.0, Chars.look(5, "mohawk", 6, "hardhat", "none", 4 if key == "plant" else 0, "overalls"),
				{"emotion": _mood_of(key, "happy" if working else idle), "blink": Chars.blinking(_t, 5.0),
				"arm_r": 1.0 + stoke * 0.9, "arm_l": 0.6, "hold": "ladle", "bob": 0.0})
	# The plant's manager walks the line with a clipboard once hired.
	if _has_mgr(key):
		var cyc := fposmod(_t * 0.07 + seed * 0.3, 1.0)
		var x1 := FactoryArt.SLOTS[n - 1] + 10.0
		var u := 0.0
		var dir := 1.0
		var walking := true
		# Walk right, stop and check, walk back, stop.
		if cyc < 0.35:
			u = cyc / 0.35
		elif cyc < 0.5:
			u = 1.0
			walking = false
		elif cyc < 0.85:
			u = 1.0 - (cyc - 0.5) / 0.35
			dir = -1.0
		else:
			walking = false
			dir = -1.0
		var mp := _line_pt(key, Vector2(lerpf(70.0, x1, smoothstep(0.0, 1.0, u)), 14))
		var pose := {"emotion": "happy" if working else "bored", "blink": Chars.blinking(_t, 11.0),
				"arm_r": 1.2 if not walking else 0.6, "arm_l": -0.2, "hold": "clipboard", "bob": 0.0}
		if walking:
			pose["walk"] = snappedf(_t * 1.6, 1.0 / 16.0)
		Chars.person(self, mp, 0.8 * ls, dir, Chars.manager_look(key), pose)


func _mark(kind: String, at: Vector2, s: float) -> void:
	Art.push(self, at, 0.0, Vector2(s, s))
	Chars.mark(self, kind, Vector2.ZERO, _t)
	Art.pop(self)


func _draw_fx() -> void:
	for f: Dictionary in _fx:
		var age := _t - float(f["t0"])
		match str(f["kind"]):
			"ripple":
				if age > 1.2:
					continue
				var a := 1.0 - age / 1.2
				Art.arc(self, f["p"], 14.0 + age * 60.0, 0, TAU, 24, Color(1, 1, 1, 0.8 * a), 3.0)
			"spark":
				if age > 0.6:
					continue
				var p: Vector2 = f["p"] + Vector2(f["v"]) * age + Vector2(0, 300.0 * age * age)
				Art.dot(self, p, 3.5 * (1.0 - age / 0.6) + 0.5, Color(1.0, 0.85, 0.3, 1.0 - age / 0.6))
			"steam":
				for k in 3:
					var u := clampf(age / 1.4 - k * 0.12, 0.0, 1.0)
					if u <= 0.0 or u >= 1.0:
						continue
					Art.dot(self, f["p"] + Vector2(k * 6.0 - 6.0 + u * 10.0, -u * 46.0), 5.0 + u * 10.0, Color(1, 1, 1, 0.55 * (1.0 - u)))
			"text":
				if age > 1.2:
					continue
				var p: Vector2 = f["p"] + Vector2(0, -age * 40.0)
				Art.push(self, p, 0.0, Vector2.ONE / maxf(_k, 0.01) * minf(1.0, _k * 1.2))
				Art.text(self, Vector2.ZERO, str(f["s"]), 26, f["c"], 6)
				Art.pop(self)
