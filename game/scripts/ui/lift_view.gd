class_name LiftView
extends Control
## The lift (Idle Miner's elevator) in the dive shaft: a winch on a small
## pontoon at the raft with its operator, a cable over the crane's pulley,
## and a cabin riding the cable. Divers leave their ore in a crate at their
## depth (GameState.pit); a trip goes down, stops at every open depth to
## empty its crate, comes back up and tosses the sacks into the raft chest.
## The cabin, the winch and the cable get a new look at the level
## milestones in Balance.LIFT_LOOKS (rope and bucket ... golden bathyscaphe).
## Also holds the tap areas: a tap on the winch or the cabin taps the lift (one trip while
## it has no operator) and shows it in the upgrade panel.

const CAB_X := World.ROPE_X
## Bottom of the cabin when it waits under the raft.
const TOP_Y := World.SURFACE_Y + 92.0
const PULLEY := Vector2(World.ROPE_X, World.SURFACE_Y - 112.0)
## Guide wheel on top of the raft's crane post.
const GUIDE := Vector2(49.0, World.SURFACE_Y - 126.0)
## The hand winch, seen from its end: an A-frame on the deck holding the
## drum (WINCH is its axle) with the crank in front of it. The operator
## stands right behind it facing us and turns the crank's handle with both
## hands, in a circle in front of his chest. From look 3 on an engine on
## the pontoon at the left helps it through a belt. A little pontoon lashed
## to the raft's left end carries them; they keep to x < 60 (the raft's
## loader stands right of them) and below SURFACE_Y - 100.
const WINCH := Vector2(27.0, World.SURFACE_Y - 38.0)
const DRUM_R := 12.0
const CRANK_R := 11.0
## Half the handle's grip bar (both fists hold it side by side).
const GRIP := 6.0
const OPERATOR := Vector2(27.0, World.SURFACE_Y - 16.0)
const OP_SCALE := 0.8
## The crank is drawn in this many angle steps (cached shapes).
const CRANK_STEPS := 24
## Shares of a trip: down with the stops, back up, unloading at the top.
const DOWN_END := 0.55
const UP_END := 0.88
const CABIN_H := 62.0
const LOOKS := 6
## Phone: the lift's card sits in the sky's card row, left of the boat and
## plant cards and right of the hint bulb (main.gd puts it at x 10); PC
## shows it in the side column instead (main.gd).
const CARD_LEFT := 10.0 + HintButton.SIZE + 10.0
const CARD_GAP := 12.0
## Narrower than this (a big UI size) and the compact card at the top of
## the shaft stands in for it: a second row in the sky would cover the raft.
const CARD_MIN_W := 160.0
const COMPACT_POS := Vector2(World.SHAFT_R + 14.0, World.SURFACE_Y + 26.0)

var world: World
var card: StageCard
var compact: LiftCard
## PC: the side column shows the lift's card, both of these hide.
var wide := false

var _t := 0.0
var _top: PaintLayer
## The cabin and its cable move on every frame as their own canvas items;
## the cabin's look is drawn again only when it changes (see _place_cabin).
var _cab_spr: Node2D
var _cable_spr: Node2D
var _cab_sig := 0
var _cable_look := -1
var _cab_args := []
var _hit_top: Control
var _hit_cab: Control
## Ore shown in each depth's crate (their sum follows GameState.pit), what
## the running trip takes from each and whether the cabin got it yet.
var _crates: Array[float] = []
var _takes: Array[float] = []
var _taken: Array[bool] = []
var _trip_amount := 0.0
var _trip_deep := 0
var _last_p := -1.0
var _thrown := 0
var _look := 1
var _look_old := 1
var _look_fx := -99.0
var _idle_since := 0.0
var _crank := 0.0
## Tests and preview sheets: keep the crank where they put it.
var freeze_crank := false
var _sync_left := 0.0
var _ratio: Array[float] = []
var _ratio_at := -99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Balance.DEPTHS.size():
		_crates.append(0.0)
		_takes.append(0.0)
		_taken.append(true)
	_cable_spr = Node2D.new()
	_cable_spr.show_behind_parent = true
	_cable_spr.draw.connect(_draw_cable_sprite)
	add_child(_cable_spr)
	_cab_spr = Node2D.new()
	_cab_spr.draw.connect(_draw_cab_sprite)
	add_child(_cab_spr)
	_top = PaintLayer.new(_draw_top, false)
	add_child(_top)
	_hit_top = _hit_area()
	_hit_top.position = Vector2(0.0, World.SURFACE_Y - 120.0)
	_hit_top.size = Vector2(56.0, 124.0)
	_hit_cab = _hit_area()
	card = StageCard.new("lift")
	card.world = world
	add_child(card)
	compact = LiftCard.new("lift")
	compact.world = world
	compact.lift = self
	compact.position = COMPACT_POS
	# Over the chest bubble that drifts in the same water.
	compact.z_index = 2
	compact.visible = false
	add_child(compact)
	_look = Balance.lift_look(GameState.get_level("lift"))
	_look_old = _look
	GameState.cycle_started.connect(_on_cycle_started)
	GameState.cycle_finished.connect(_on_cycle_finished)
	GameState.upgraded.connect(_on_upgraded)
	world.resized.connect(_fit)
	_fit()
	_sync_crates(true)


func _fit() -> void:
	position = Vector2.ZERO
	size = world.size


func _hit_area() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(_on_hit_input)
	add_child(c)
	return c


func _on_hit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag():
			return
		tap()
		get_viewport().set_input_as_handled()


## A tap on the lift: one trip (or a push to the running one), and the
## lift's details in the upgrade panel. On phones the panel is a sheet over
## the ocean, so while the player still sends every trip by hand (and the
## tutorial points at the boat next) only the card opens it.
func tap(from_card: bool = false) -> void:
	if GameState.tap("lift"):
		Sfx.play("machine", 1.3)
	else:
		Sfx.play("tap")
	Settings.buzz(12)
	world.divers.tap_ripple(cabin_pos() + Vector2(0, -CABIN_H * 0.5))
	var vp := get_viewport_rect().size
	if from_card or vp.x > vp.y * 1.05 or GameState.has_manager("lift"):
		world.select("lift")


# --- Where things are ------------------------------------------------------------------

## Cabin bottom when stopped at a depth: level with the cave floor.
static func stop_y(i: int) -> float:
	return World.row_y(i) + DepthRow.LEDGE_Y + 4.0


## The crate at a depth, where divers drop their sacks (bottom centre).
static func crate_pos(i: int) -> Vector2:
	return Vector2(World.SHAFT_R + 20.0, World.row_y(i) + DepthRow.LEDGE_Y + 4.0)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The cabin during a trip at progress p (0..1, <0 = waiting) down to the
## depth `deep`: [bottom y, depth it is stopped at (-1 moving, -2 unloading
## at the top), share of that stop done]. The cabin slows into every stop.
static func trip_at(p: float, deep: int) -> Array:
	if p < 0.0:
		return [TOP_Y, -1, 0.0]
	var n := deep + 1
	if p < DOWN_END:
		var stops := DOWN_END * minf(0.5, 0.2 * n)
		var stop := stops / n
		var travel := DOWN_END - stops
		var total := stop_y(deep) - TOP_Y
		var t := p
		var from := TOP_Y
		for i in n:
			var seg := travel * (stop_y(i) - from) / total
			if t < seg:
				return [lerpf(from, stop_y(i), _ease(t / seg)), -1, 0.0]
			t -= seg
			if t < stop:
				return [stop_y(i), i, t / stop]
			t -= stop
			from = stop_y(i)
		return [stop_y(deep), deep, 1.0]
	if p < UP_END:
		return [lerpf(stop_y(deep), TOP_Y, _ease((p - DOWN_END) / (UP_END - DOWN_END))), -1, 0.0]
	return [TOP_Y, -2, (p - UP_END) / (1.0 - UP_END)]


func _trip() -> Array:
	return trip_at(GameState.cycle_progress("lift"), _trip_deep)


## Bottom centre of the cabin now.
func cabin_pos() -> Vector2:
	return Vector2(CAB_X, float(_trip()[0]))


## Where the "Tap!" bubble for an idle manual lift goes.
func hint_pos() -> Vector2:
	return Vector2(CAB_X - 16.0, TOP_Y - CABIN_H - 22.0)


func look() -> int:
	return _look


# --- Crates -----------------------------------------------------------------------------

func _on_cycle_finished(key: String, amount: float) -> void:
	var i := GameState.depth_index(key)
	if i >= 0 and i < _crates.size():
		_crates[i] += amount


func _on_cycle_started(key: String, amount: float) -> void:
	if key != "lift":
		return
	# Shallow crates first, as far as the cabin's share of the pit goes.
	_trip_deep = GameState.lift_trip_depth if GameState.lift_trip_depth >= 0 else GameState.deepest_open()
	_trip_amount = amount
	_thrown = 0
	var rem := amount
	for i in _crates.size():
		var take := minf(_crates[i], rem) if i <= _trip_deep else 0.0
		_takes[i] = take
		_taken[i] = take <= 0.0
		rem -= take
	if rem > amount * 0.02:
		# The crates were behind the real pit: spread the rest by share.
		var shares := _shares()
		for i in _trip_deep + 1:
			var extra: float = rem * shares[i]
			_takes[i] += extra
			_crates[i] += extra
			_taken[i] = _takes[i] <= 0.0


## Each open site's share of the dives (who fills the crates).
func _shares() -> Array[float]:
	var out: Array[float] = []
	var total := GameState.dives_rate()
	for i in _crates.size():
		var r: float = GameState.rate("d%d" % i) if GameState.is_open("d%d" % i) else 0.0
		out.append(r / total if total > 0.0 else (1.0 if i == 0 else 0.0))
	return out


## Crates always add up to the real pit plus what the cabin has yet to pick
## up (loads, time away and Dives change the pit without cycles).
func _sync_crates(force: bool = false) -> void:
	var want: float = GameState.pit
	var have := 0.0
	for i in _crates.size():
		if not _taken[i]:
			want += _takes[i]
		have += _crates[i]
	if not force and absf(have - want) <= maxf(1e-6, want * 0.02):
		return
	if have > 0.0 and want > 0.0:
		var k := want / have
		for i in _crates.size():
			_crates[i] *= k
			_takes[i] *= k
	else:
		var shares := _shares()
		for i in _crates.size():
			_crates[i] = want * shares[i]
			_takes[i] = 0.0
			_taken[i] = true


# --- Frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_place_card()
	var gs := GameState
	var p: float = gs.cycle_progress("lift")
	if p < 0.0 and _last_p >= 0.0:
		_idle_since = _t
	var tp := trip_at(p, _trip_deep)
	var stop: int = tp[1]
	if p >= 0.0:
		# The cabin empties each crate it stops at (all of those passed).
		for i in _trip_deep + 1:
			if not _taken[i] and (p >= DOWN_END or (stop >= 0 and i < stop) or (stop == i and float(tp[2]) >= 1.0)):
				_crates[i] = maxf(0.0, _crates[i] - _takes[i])
				_taken[i] = true
		if stop == -2 and _thrown < 2 and float(tp[2]) >= _thrown * 0.35:
			_unload_sack()
		var moving := stop == -1 and p < UP_END
		if not freeze_crank:
			_crank += delta * (9.0 if moving else 1.5) * (-1.0 if p >= DOWN_END else 1.0)
	elif _last_p >= 0.0:
		for i in _crates.size():
			if not _taken[i]:
				_crates[i] = maxf(0.0, _crates[i] - _takes[i])
				_taken[i] = true
	_last_p = p
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = 0.5
		_sync_crates()
	var cab := Vector2(CAB_X, float(tp[0]))
	_place_cabin(p, tp, cab)
	_hit_cab.position = cab + Vector2(-42.0, -CABIN_H - 26.0)
	_hit_cab.size = Vector2(84.0, CABIN_H + 40.0)
	self_modulate = Color.WHITE.lerp(DayNight.deep_tint(), 0.5)
	_cab_spr.self_modulate = self_modulate
	_cable_spr.self_modulate = self_modulate
	_top.self_modulate = DayNight.scene_tint()
	if World.anim_tick():
		queue_redraw()
		if world.is_visible_band(World.SURFACE_Y - 200.0, TOP_Y + 20.0):
			_top.queue_redraw()


func _unload_sack() -> void:
	_thrown += 1
	var from := Vector2(CAB_X, TOP_Y - CABIN_H + 6.0)
	var to := world.surface._raft_chest_pos() + Vector2(0, -30) if world.surface.has_method("_raft_chest_pos") else PULLEY + Vector2(40, 90)
	world.divers.throw_item("sack", from, to, Art.DEPTH_STYLE[0]["ore2"], 0.45, 0)
	if _thrown == 1:
		world.react("raft", "joy", 0.8, true)
		if world.surface.has_method("_pop_chest"):
			world.surface._pop_chest("raft", 0.8)


func _on_upgraded(key: String, _n: int) -> void:
	if key != "lift":
		return
	var now := Balance.lift_look(GameState.get_level("lift"))
	if now > _look:
		_look_old = _look
		_look_fx = _t
		world.divers.confetti(cabin_pos() + Vector2(0, -CABIN_H * 0.5), 40)
		world.divers.sparkle(cabin_pos() + Vector2(0, -CABIN_H * 0.5), 12)
		world.react("lift", "wow", 1.6, true)
		Sfx.play("unlock")
	_look = now


## Phone: the card joins the boat and plant cards at the top of the sky,
## as wide as the room left of them allows (at most as wide as they are);
## with a big UI size the compact card at the top of the shaft instead.
func _place_card() -> void:
	var boat: Control = world.surface.boat_card
	var room := boat.position.x - CARD_GAP - CARD_LEFT
	var in_row := not wide and room >= CARD_MIN_W
	card.visible = in_row
	compact.visible = not wide and not in_row
	if not in_row:
		return
	var at := Vector2(CARD_LEFT, boat.position.y)
	var w := minf(World.CARD_W, room)
	# Its name may not hold the card wider than the room (no unit tabs here).
	card._name.custom_minimum_size.x = 40.0
	card._bar.custom_minimum_size.x = 40.0
	card._rate.add_theme_font_size_override("font_size", 16)
	if card.position != at:
		card.position = at
	if card.custom_minimum_size.x != w:
		card.custom_minimum_size.x = w
		card.size.x = w
	# Its name tab as tall as theirs (they grow "1 | 2" tabs).
	var head_h: float = boat._head.size.y
	if card._head.custom_minimum_size.y != head_h:
		card._head.custom_minimum_size.y = head_h


## The phone's card for the lift now (the row's or the compact one).
func phone_card() -> StageCard:
	return compact if compact.visible else card


## Syncs the look after a load, a Dive or a player switch.
func refresh() -> void:
	var now := Balance.lift_look(GameState.get_level("lift"))
	if now != _look and _t - _look_fx > 1.0:
		_look = now
		_look_old = now
	if card.visible:
		card.refresh()
	if compact.visible:
		compact.refresh()


# --- Drawing: shaft ---------------------------------------------------------------------

func _draw() -> void:
	var view := world.visible_rect().grow(60.0)
	var gs := GameState
	var p: float = gs.cycle_progress("lift")
	var tp := trip_at(p, _trip_deep)
	var cab := Vector2(CAB_X, float(tp[0]))
	# Crates at every open depth (the cable and the cabin are sprites).
	var ratio := _crate_scale()
	for i in Balance.DEPTHS.size():
		if not gs.is_open("d%d" % i):
			break
		var at := crate_pos(i)
		if not view.has_point(at):
			continue
		var shown := _crates[i]
		if not _taken[i] and int(tp[1]) == i:
			shown = maxf(0.0, shown - _takes[i] * float(tp[2]))
		_draw_crate(i, at, shown * ratio[i])
		if int(tp[1]) == i:
			_draw_chips(i, at, cab, float(tp[2]))


## Moves the cabin and the cable to where the trip is now (every frame);
## the cabin's picture changes only when its look, load or step does.
func _place_cabin(p: float, tp: Array, cab: Vector2) -> void:
	if not is_visible_in_tree():
		return
	var view := world.visible_rect().grow(60.0)
	var look := _shown_look()
	# Cable from the pulley down to the cabin's hook: a unit line stretched.
	var top := PULLEY.y
	var bottom := cab.y - CABIN_H - 4.0
	_cable_spr.visible = bottom > top and bottom > view.position.y and top < view.end.y
	if _cable_spr.visible:
		_cable_spr.position = Vector2(CAB_X, top)
		_cable_spr.scale = Vector2(1.0, bottom - top)
		if _cable_look != look:
			_cable_look = look
			_cable_spr.queue_redraw()
	_cab_spr.visible = view.grow(40.0).has_point(cab + Vector2(0, -CABIN_H * 0.5))
	if not _cab_spr.visible:
		_cab_sig = 0
		return
	var fill := 0.0
	if p >= 0.0 and p < UP_END + 0.05:
		var got := 0.0
		for i in _trip_deep + 1:
			if _taken[i]:
				got += _takes[i]
			elif int(tp[1]) == i:
				got += _takes[i] * float(tp[2])
		fill = got / maxf(_trip_amount, 1e-9) if p < DOWN_END else 1.0
	elif p >= 0.0:
		fill = 1.0 - float(tp[2]) * 1.4
	var sway := 0.0
	if p >= 0.0 and int(tp[1]) == -1 and not Settings.reduce_motion:
		sway = sin(_t * 5.0) * 0.025
	var pop := clampf((_t - _look_fx) / 0.6, 0.0, 1.0)
	var s := 1.0 + sin(pop * PI) * 0.18
	_cab_spr.position = cab
	_cab_spr.rotation = sway
	var busy := p >= 0.0
	var sig := hash([look, snappedf(clampf(fill, 0.0, 1.0), 0.25), busy, s, Art.shape_stamp(_t) if look >= 6 or pop < 1.0 else 0])
	if sig != _cab_sig:
		_cab_sig = sig
		_cab_args = [look, _t, fill, busy, s]
		_cab_spr.queue_redraw()


func _draw_cab_sprite() -> void:
	if _cab_args.is_empty():
		return
	var a := _cab_args
	Art.push(_cab_spr, Vector2.ZERO, 0.0, Vector2(a[4], a[4]))
	draw_cabin(_cab_spr, a[0], a[1], a[2], a[3])
	Art.pop(_cab_spr)


func _draw_cable_sprite() -> void:
	_cable(_cable_spr, Vector2.ZERO, Vector2(0, 1), _cable_look)


## Visual scale of each crate: 1 = one lift trip's share (full crate).
func _crate_scale() -> Array[float]:
	# Shares only change with upgrades and hires: worked out twice a second.
	if _ratio_at > _t or _t - _ratio_at > 0.5 or _ratio.size() != _crates.size():
		_ratio_at = _t
		_ratio = _work_out_scale()
	return _ratio


func _work_out_scale() -> Array[float]:
	var shares := _shares()
	var cap: float = maxf(GameState.cycle_capacity("lift"), 1e-9)
	var out: Array[float] = []
	for i in shares.size():
		out.append(1.0 / maxf(cap * shares[i], 1e-9))
	return out


func _shown_look() -> int:
	return _look_old if _t - _look_fx < 0.3 else _look


static func _cable(ci: CanvasItem, a: Vector2, b: Vector2, look: int) -> void:
	Art.line(ci, a, b, Art.INK, 7.0)
	Art.line(ci, a, b, cable_color(look), 3.5)


## A wooden crate with the waiting ore; `fill` 1 = a lift trip's worth,
## more spills over.
func _draw_crate(i: int, at: Vector2, fill: float) -> void:
	var st: Dictionary = Art.DEPTH_STYLE[i]
	var f := snappedf(clampf(fill, 0.0, 1.5), 0.25)
	Art.push(self, at)
	# A crate only changes when its ore pile steps up or down (quarters).
	var key := hash([50, i, f])
	if not Art.cache_begin(self, key):
		if f > 1.0:
			Art.crystals(self, Vector2(-24, 0), 12.0, st, 7, 2)
			Art.crystals(self, Vector2(23, 0), 10.0, st, 9, 2)
		if f > 0.0:
			Art.crystals(self, Vector2(0, -22), 10.0 + minf(f, 1.0) * 14.0, st, 3 + i, 3 if f < 0.75 else 4)
		Art.t_rect(self, Rect2(-19, -26, 38, 26), 3, Art.WOOD, 2.5, 0.5)
		Art.line(self, Vector2(-17, -13), Vector2(17, -13), Art.WOOD_DARK, 2.0)
		Art.line(self, Vector2(-8, -24), Vector2(-8, -2), Art.WOOD_DARK, 2.0)
		Art.line(self, Vector2(8, -24), Vector2(8, -2), Art.WOOD_DARK, 2.0)
		Art.t_rect(self, Rect2(-19, -26, 7, 7), 1.5, Art.BRASS, 1.5, 0.0)
		Art.t_rect(self, Rect2(12, -26, 7, 7), 1.5, Art.BRASS, 1.5, 0.0)
		Art.cache_end(self, key)
	Art.pop(self)


## Ore hopping from a crate into the stopped cabin.
func _draw_chips(i: int, from: Vector2, cab: Vector2, f: float) -> void:
	for k in 2:
		var g := fposmod(f * 2.0 + k * 0.5, 1.0)
		var a := from + Vector2(0, -26)
		var b := cab + Vector2(8, -22)
		var pos := a.lerp(b, g) + Vector2(0, -sin(g * PI) * 26.0)
		OreArt.chip(self, pos, 4.0, i, g * 6.0 + k)


# --- Cabin looks ----------------------------------------------------------------------------

## The cabin, bottom centre at the origin (about 56 wide and CABIN_H tall)
## with `fill` 0..1 of ore inside. Looks 1..6: rope bucket, wooden cage,
## iron cage, diving bell, bathyscaphe, golden bathyscaphe.
static func draw_cabin(ci: CanvasItem, look: int, t: float, fill: float, busy: bool) -> void:
	var f := snappedf(clampf(fill, 0.0, 1.0), 0.25)
	# Only the golden one twinkles (in quarter steps of alpha).
	var tw := snappedf(0.5 + 0.5 * sin(t * 4.0), 0.25)
	var key := hash([51, look, f, busy, tw if look >= 6 else 0.0])
	if Art.cache_begin(ci, key):
		return
	_cabin_shape(ci, look, f, busy, tw)
	Art.cache_end(ci, key)


static func _cabin_shape(ci: CanvasItem, look: int, f: float, busy: bool, tw: float) -> void:
	var ore := {"ore": Art.DEPTH_STYLE[0]["ore"], "ore2": Art.DEPTH_STYLE[0]["ore2"]}
	match look:
		1:
			# Rope bucket: a handle up to the hook, ore heaped on top.
			Art.arc(ci, Vector2(0, -34), 20.0, PI, TAU, 16, Art.INK, 5.0)
			Art.arc(ci, Vector2(0, -34), 20.0, PI, TAU, 16, Color("e8c48a"), 2.5)
			if f > 0.0:
				Art.crystals(ci, Vector2(0, -34), 10.0 + f * 10.0, ore, 5, 3)
			Art.toon(ci, PackedVector2Array([Vector2(-22, -38), Vector2(22, -38), Vector2(17, 0), Vector2(-17, 0)]), Art.WOOD, 3.0, 0.6)
			Art.t_rect(ci, Rect2(-23, -30, 46, 5), 2, Art.WOOD_DARK, 2.0, 0.0)
			Art.t_rect(ci, Rect2(-20, -12, 40, 5), 2, Art.WOOD_DARK, 2.0, 0.0)
			_hook(ci, Vector2(0, -56), Art.METAL)
		2, 3:
			# Cage: planks (wood) or riveted iron, bars in front of the ore.
			var frame := Art.WOOD if look == 2 else Color("8a94b8")
			var dark := Art.WOOD_DARK if look == 2 else Color("4a5270")
			Art.t_rect(ci, Rect2(-27, -CABIN_H + 6, 54, CABIN_H - 6), 4, Color(dark, 0.35), 0.0, 0.0)
			if f > 0.0:
				Art.crystals(ci, Vector2(0, -6), 12.0 + f * 16.0, ore, 11, 4)
			Art.t_rect(ci, Rect2(-29, -CABIN_H + 2, 58, 9), 3, frame, 2.5, 0.4)
			Art.t_rect(ci, Rect2(-29, -8, 58, 9), 3, frame, 2.5, 0.4)
			for x: float in [-26.0, 26.0]:
				Art.t_rect(ci, Rect2(x - 3, -CABIN_H + 6, 6, CABIN_H - 10), 2, frame, 2.2, 0.0)
			for x: float in [-13.0, 0.0, 13.0]:
				Art.line(ci, Vector2(x, -CABIN_H + 10), Vector2(x, -8), dark, 3.0)
			if look == 3:
				for x: float in [-24.0, 24.0]:
					Art.disc(ci, Vector2(x, -CABIN_H + 6), 1.8, Art.INK_SOFT)
					Art.disc(ci, Vector2(x, -4), 1.8, Art.INK_SOFT)
				Props.lamp(ci, Vector2(18, -CABIN_H - 4), 1.0 if busy else 0.4)
			_hook(ci, Vector2(0, -CABIN_H - 6), Art.METAL)
		4:
			# Diving bell: brass, two portholes, ore on the rim below.
			var bell := Art.smooth_pts(PackedVector2Array([Vector2(-30, -6), Vector2(-26, -34), Vector2(-16, -54), Vector2(0, -60),
					Vector2(16, -54), Vector2(26, -34), Vector2(30, -6)]), 3)
			if f > 0.0:
				Art.crystals(ci, Vector2(0, 2), 10.0 + f * 12.0, ore, 13, 4)
			Art.toon(ci, bell, Color("e08a4a"), 3.0, 0.8)
			Art.t_rect(ci, Rect2(-33, -10, 66, 9), 4, Color("b8652e"), 2.5, 0.0)
			for x: float in [-13.0, 13.0]:
				Art.t_circle(ci, Vector2(x, -32), 8.5, Art.BRASS, 2.5, 0.0)
				Art.t_circle(ci, Vector2(x, -32), 5.5, Art.GLASS, 1.5, 0.0)
				Art.disc(ci, Vector2(x - 2, -34), 1.6, Color(1, 1, 1, 0.9))
			_hook(ci, Vector2(0, -66), Art.BRASS)
		_:
			# Bathyscaphe: round cabin, big porthole, headlight, ore basket.
			var gold := look >= 6
			var body := Color("ffc93c") if not gold else Color("ffb300")
			var trim := Color("ef5350") if not gold else Color("e8eef8")
			if busy:
				Art.glow(ci, Vector2(30, -30), 26.0, Color(1, 0.95, 0.7, 0.35 if not gold else 0.5), 14)
			Art.t_rect(ci, Rect2(-24, -12, 48, 12), 3, Color("4a5270"), 2.5, 0.0)
			if f > 0.0:
				Art.crystals(ci, Vector2(0, -8), 8.0 + f * 10.0, ore, 17, 4)
			Art.line(ci, Vector2(-22, -6), Vector2(22, -6), Color("8a94b8"), 2.0)
			Art.t_ellipse(ci, Vector2(0, -38), Vector2(29, 25), body, 3.0, 0.8)
			Art.t_rect(ci, Rect2(-30, -42, 60, 7), 3, trim, 2.2, 0.0)
			Art.t_circle(ci, Vector2(4, -38), 12.0, Color("8a94b8") if not gold else Art.GOLD_DARK, 2.5, 0.0)
			Art.t_circle(ci, Vector2(4, -38), 8.5, Color("7fe3ff") if not gold else Color("9ff6ff"), 1.8, 0.0)
			Art.disc(ci, Vector2(1, -41), 2.2, Color(1, 1, 1, 0.9))
			Art.t_rect(ci, Rect2(24, -35, 9, 9), 3, Color("fff6c8"), 2.0, 0.0)
			Art.t_rect(ci, Rect2(-8, -66, 16, 8), 3, trim, 2.2, 0.0)
			if gold:
				# Fins, a second lamp and a twinkle.
				Art.toon(ci, PackedVector2Array([Vector2(-26, -30), Vector2(-40, -22), Vector2(-40, -10), Vector2(-24, -18)]), Color("2bc8b4"), 2.2, 0.0)
				Art.t_rect(ci, Rect2(24, -52, 8, 8), 3, Color("fff6c8"), 2.0, 0.0)
				Art.toon(ci, Art.star_pts(Vector2(-14, -50), 6.0, 2.5, 4), Color(1, 1, 1, tw), 1.2, 0.0)
				Art.toon(ci, Art.star_pts(Vector2(20, -64), 4.0, 1.8, 4), Color(1, 1, 1, snappedf(1.0 - tw, 0.25)), 1.0, 0.0)
			_hook(ci, Vector2(0, -70), Color("b9c3d6"))


static func _hook(ci: CanvasItem, at: Vector2, c: Color) -> void:
	Art.arc(ci, at, 6.0, 0, TAU, 14, Art.INK, 5.0)
	Art.arc(ci, at, 6.0, 0, TAU, 14, c, 2.2)


# --- Drawing: the winch on top ------------------------------------------------------------

func _draw_top(ci: CanvasItem) -> void:
	var look := _shown_look()
	var bob: float = world.surface._raft_bob() if world.surface.has_method("_raft_bob") else 0.0
	var off := Vector2(0, bob)
	var turn := crank_angle()
	var busy: bool = GameState.cycle_progress("lift") >= 0.0
	# Engine (from look 3) on the pontoon, belted to the drum.
	Art.push(ci, off)
	_draw_pontoon(ci)
	Art.pop(ci)
	if look >= 3:
		Art.push(ci, WINCH + off)
		draw_engine(ci, look, turn, busy, _t)
		Art.pop(ci)
	# Cable: off the drum -> up to the guide wheel on the post -> along the
	# arm -> over the pulley (behind the operator).
	var c := cable_color(look)
	var pts := PackedVector2Array([WINCH + Vector2(DRUM_R - 3.0, -DRUM_R + 3.0), GUIDE + Vector2(-6.5, 0), GUIDE + Vector2(0, -7), PULLEY + Vector2(0, -9)])
	Art.push(ci, off)
	Art.polyline(ci, pts, Art.INK, 6.0)
	Art.polyline(ci, pts, c, 3.0)
	Art.pop(ci)
	Art.push(ci, GUIDE + off, turn * 0.6)
	Art.t_circle(ci, Vector2.ZERO, 6.5, Art.METAL, 2.2, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-5, -1.2, 10, 2.4), 1), Art.INK_SOFT)
	Art.pop(ci)
	Art.push(ci, PULLEY + off, turn * 0.4)
	Art.t_circle(ci, Vector2.ZERO, 9.0, Art.METAL if look <= 4 else Art.GOLD, 2.4, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-7, -1.5, 14, 3), 1), Art.INK_SOFT)
	Art.flat(ci, Art.rrect_pts(Rect2(-1.5, -7, 3, 14), 1), Art.INK_SOFT)
	Art.pop(ci)
	# The operator, the winch in front of him, then his arms over it.
	var op := _draw_operator(ci, off, turn)
	Art.push(ci, WINCH + off)
	draw_winch(ci, look, turn, busy, _t)
	Art.pop(ci)
	Chars.reach_arms(ci, op["feet"], OP_SCALE, 1.0, _op_look, op["hand_l"], op["hand_r"], op["bob"])
	if _op_sleepy:
		Chars.mark(ci, "zzz", OPERATOR + off + Vector2(12, -80), _t)
	# A new look pops in with a flash.
	var fx := _t - _look_fx
	if fx >= 0.0 and fx < 0.8:
		Art.glow(ci, WINCH + off, 40.0 * (1.0 + fx), Color(1, 1, 0.8, 0.6 * (1.0 - fx / 0.8)), 16)


static func cable_color(look: int) -> Color:
	return Color("e8c48a") if look <= 2 else (Color("b9c3d6") if look <= 4 else Color("ffd86b"))


## The crank's angle now, snapped to CRANK_STEPS (0 = handle straight up,
## growing clockwise).
func crank_angle() -> float:
	var step := TAU / CRANK_STEPS
	return fposmod(roundf(_crank / step) * step, TAU)


## Where the crank's handle is, relative to the axle.
static func handle_at(turn: float) -> Vector2:
	return Vector2(sin(turn), -cos(turn)) * CRANK_R


static var _PONTOON_KEY := hash([54, "pontoon"])


## The winch's pontoon: a few planks on a float, lashed to the raft.
func _draw_pontoon(ci: CanvasItem) -> void:
	Art.push(ci, Vector2(0, World.SURFACE_Y))
	if not Art.cache_begin(ci, _PONTOON_KEY):
		Art.t_ellipse(ci, Vector2(12, 3), Vector2(17, 9), Art.CORAL, 2.5, 0.7)
		Art.t_rect(ci, Rect2(-8, -16, 44, 13), 4, Art.WOOD, 3.0, 0.6)
		for x: float in [5.0, 19.0]:
			Art.line(ci, Vector2(x, -14), Vector2(x, -5), Art.WOOD_DARK, 2.0)
		# Rope lashing to the raft's deck.
		Art.t_rect(ci, Rect2(29, -17, 6, 15), 2, Color("e8c48a"), 2.0, 0.0)
		Art.line(ci, Vector2(30, -12), Vector2(34, -9), Color("b88a4a"), 1.5)
		Art.line(ci, Vector2(30, -7), Vector2(34, -4), Color("b88a4a"), 1.5)
		Art.cache_end(ci, _PONTOON_KEY)
	Art.pop(ci)


## The engine that helps the winch from look 3 on (origin at the drum's
## axle; it stands on the pontoon at the left, the deck 22 below): a little
## steam boiler that puffs (looks 3, 4), then an electric motor (5, 6), with
## a belt running up to the drum.
static func draw_engine(ci: CanvasItem, look: int, turn: float, busy: bool, t: float) -> void:
	var x0 := -25.0
	var w := 12.0
	var top := -10.0
	Art.stroke(ci, PackedVector2Array([Vector2(x0 + w * 0.5, top + 8.0), Vector2(0, 0)]), Color("3a3f5c"), 3.0, 1.5)
	match look:
		3, 4:
			var metal := Color("8a94b8") if look == 3 else Color("e08a4a")
			Art.t_rect(ci, Rect2(x0 + 4, top - 12, 5, 13), 2, Color("4a5270"), 2.0, 0.0)
			Art.t_rect(ci, Rect2(x0, top, w, 32), 5, metal, 2.5, 0.6)
			Art.t_rect(ci, Rect2(x0 - 1, top + 9, w + 2, 3.5), 1.5, Art.shade_of(metal, 0.25), 1.8, 0.0)
			Art.t_circle(ci, Vector2(x0 + w * 0.5, top + 20), 4.2, Art.WHITE, 1.8, 0.0)
			Art.push(ci, Vector2(x0 + w * 0.5, top + 20), snappedf(sin(t * 3.0) * 0.8, 0.2) if busy else -0.6)
			Art.line(ci, Vector2.ZERO, Vector2(0, -3.0), Art.RED, 1.5)
			Art.pop(ci)
			if busy:
				for k in 2:
					var g := snappedf(fposmod(t * 0.9 + k * 0.5, 1.0), 0.05)
					Art.disc(ci, Vector2(x0 + 6.0 - g * 6.0, top - 14.0 - g * 20.0), snappedf(2.5 + g * 5.0, 1.0), Color(1, 1, 1, snappedf(0.75 * (1.0 - g), 0.1)))
		_:
			var box := Color("ffc93c") if look == 5 else Color("fff0b8")
			Art.t_rect(ci, Rect2(x0, top, w, 32), 4, box, 2.5, 0.6)
			for k in 3:
				var y := top + 3.0 + k * 6.0
				Art.flat(ci, PackedVector2Array([Vector2(x0 + 2, y + 3), Vector2(x0 + w - 2, y), Vector2(x0 + w - 2, y + 2.5), Vector2(x0 + 2, y + 5.5)]), Color(Art.INK, 0.85))
			var lit := 1.0 if busy else 0.3
			if busy:
				Art.glow(ci, Vector2(x0 + w * 0.5, top + 25), 9.0, Color(1, 0.8, 0.4, 0.4), 12)
			Art.t_circle(ci, Vector2(x0 + w * 0.5, top + 25), 3.2, Color(1.0, 0.35 + 0.5 * lit, 0.3, 1.0), 1.6, 0.0)
			if look >= 6:
				Art.toon(ci, Art.star_pts(Vector2(x0 + w * 0.5, top - 5), 4.5, 2.0, 5), Art.WHITE, 1.2, 0.0)
	# The engine's pulley turns with the winch.
	Art.push(ci, Vector2(x0 + w * 0.5, top + 8.0), turn * 2.0)
	Art.t_circle(ci, Vector2.ZERO, 3.5, Art.METAL, 1.6, 0.0)
	Art.line(ci, Vector2(-2.5, 0), Vector2(2.5, 0), Art.INK_SOFT, 1.2)
	Art.pop(ci)


## The winch, origin at the drum's axle (the deck is 22 below): an A-frame
## stand, the drum seen from its end with the cable wound on it, and the
## crank (arm, and a grip bar for both hands) at `turn`, fancier per look.
static func draw_winch(ci: CanvasItem, look: int, turn: float, busy: bool, _t: float) -> void:
	var deck := 22.0
	var wood := look <= 2
	var frame := Art.WOOD_DARK if wood else (Color("6a7394") if look == 3 else (Color("b8652e") if look == 4 else (Color("4a5270") if look == 5 else Art.GOLD_DARK)))
	# Stand: two legs from the axle to a skid on the deck.
	Art.stroke(ci, PackedVector2Array([Vector2(-3, 0), Vector2(-13, deck - 2)]), frame, 5.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(3, 0), Vector2(13, deck - 2)]), frame, 5.0, 2.0)
	Art.t_rect(ci, Rect2(-17, deck - 4, 34, 5), 2, Art.shade_of(frame, 0.2), 2.0, 0.0)
	# The drum's end plate with the cable wound round it; the spokes turn.
	var drum := Art.WOOD if wood else (Color("8a94b8") if look == 3 else (Art.BRASS if look == 4 else (Color("3a3f5c") if look == 5 else Art.GOLD)))
	Art.t_circle(ci, Vector2.ZERO, DRUM_R, drum, 2.5, 0.4)
	Art.arc(ci, Vector2.ZERO, DRUM_R - 3.5, 0, TAU, 20, cable_color(look), 3.0)
	if look == 2 or look == 3:
		# Iron teeth round the rim.
		for k in 8:
			var a := turn + k * TAU / 8.0
			Art.disc(ci, Vector2(cos(a), sin(a)) * (DRUM_R + 0.5), 1.8, Art.INK_SOFT)
	Art.push(ci, Vector2.ZERO, turn)
	for k in 3:
		Art.line(ci, Vector2.ZERO, Vector2(0, -DRUM_R + 5.0).rotated(k * TAU / 3.0), Art.shade_of(drum, 0.45), 2.0)
	Art.pop(ci)
	if look >= 6:
		Art.toon(ci, Art.star_pts(Vector2(0, DRUM_R - 3.0), 3.0, 1.4, 5), Art.WHITE, 1.0, 0.0)
	# Crank: the arm from the axle to the handle, and its grip bar.
	var h := handle_at(turn)
	var arm := Art.METAL if look < 6 else Art.GOLD
	Art.stroke(ci, PackedVector2Array([Vector2.ZERO, h]), arm, 4.0, 1.8)
	Art.t_circle(ci, Vector2.ZERO, 3.2, arm, 1.8, 0.0)
	Art.stroke(ci, PackedVector2Array([h - Vector2(GRIP, 0), h + Vector2(GRIP, 0)]), Art.CORAL if look < 6 else Art.WHITE, 4.5, 1.8)
	if busy:
		# Motion lines behind the handle: it sweeps round.
		var a1 := turn - PI * 0.5
		Art.arc(ci, Vector2.ZERO, CRANK_R + 5.0, a1 - 1.1, a1 - 0.2, 6, Color(1, 1, 1, 0.85), 1.8)


var _op_sleepy := false
var _op_look: Dictionary = {}


## The operator behind the winch: a worker (or, once hired, the lift's own
## operator) who turns the crank with both hands while the lift runs,
## bobbing with it, and leans on the drum while it waits (dozing when ore
## is waiting and nobody sends the lift). Draws him without his arms and
## returns where they go: {feet, hand_l, hand_r (his units), bob}.
func _draw_operator(ci: CanvasItem, off: Vector2, turn: float) -> Dictionary:
	var gs := GameState
	var hired: bool = gs.has_manager("lift")
	_op_look = Chars.manager_look("lift") if hired else Chars.look(2, "short", 1, "hardhat", "none", 0, "overalls")
	var p: float = gs.cycle_progress("lift")
	var mood := world.mood("lift")
	var pose := {"blink": Chars.blinking(_t, 3.3), "no_arms": true}
	var feet := OPERATOR + off + Vector2(0, -world.hop("lift"))
	var axle := WINCH + off
	var emo := "happy"
	var hl := Vector2.ZERO
	var hr := Vector2.ZERO
	_op_sleepy = false
	if mood == "joy" or mood == "wow":
		# Cheers with both arms up.
		hl = feet + Vector2(-19, -62) * OP_SCALE
		hr = feet + Vector2(19, -62) * OP_SCALE
	elif p >= 0.0:
		emo = "focus" if not gs.is_rushing() else "joy"
		var h := handle_at(turn)
		# Leans into the handle as it goes down and sways after it (his legs
		# are behind the winch).
		var dip := snappedf(0.5 - 0.5 * cos(turn), 0.125)
		feet += Vector2(snappedf(h.x * 0.25, 0.5), dip * 5.0)
		pose["bob"] = dip * 0.5
		pose["tilt"] = snappedf(sin(turn), 0.5) * 0.08
		hl = axle + h + Vector2(-GRIP * 0.55, 0)
		hr = axle + h + Vector2(GRIP * 0.55, 0)
	else:
		if not hired and gs.pit > 0.0:
			emo = "sleepy" if _t - _idle_since > 5.0 else "bored"
		_op_sleepy = emo == "sleepy"
		if _op_sleepy:
			# Dozes leaning on the drum, both hands on top of it.
			hl = axle + Vector2(-9, -DRUM_R + 2.0)
			hr = axle + Vector2(9, -DRUM_R + 2.0)
			feet.y += 3.0
			pose["tilt"] = 0.16
		else:
			# Waits at ease: a hand on the crank's grip, the other hanging.
			hr = axle + handle_at(turn) + Vector2(GRIP * 0.3, 0)
			hl = feet + Vector2(-16, -22) * OP_SCALE
	if mood != "":
		emo = mood
		_op_sleepy = false
	pose["emotion"] = emo
	Chars.person(ci, feet, OP_SCALE, 1.0, _op_look, pose)
	return {"feet": feet, "hand_l": (hl - feet) / OP_SCALE, "hand_r": (hr - feet) / OP_SCALE, "bob": float(pose.get("bob", 0.0))}


## Picture for the upgrade panel (PC): the shaft, the cabin and the crates.
static func draw_hero(ci: CanvasItem, s: Vector2, t: float, look: int) -> void:
	var bg := Color("2283b6")
	Art.t_rect(ci, Rect2(Vector2(2, 2), s - Vector2(4, 4)), 18, bg, 4.0, 0.0)
	var cx := s.x - 150.0
	Art.flat(ci, Art.rrect_pts(Rect2(cx - 44, 8, 88, s.y - 16), 8), Color("1a6aa0"))
	Art.line(ci, Vector2(cx, 8), Vector2(cx, s.y * 0.5 - 30.0), Art.INK, 7.0)
	Art.line(ci, Vector2(cx, 8), Vector2(cx, s.y * 0.5 - 30.0), Color("e8c48a") if look <= 2 else Color("b9c3d6"), 3.5)
	var k := minf(1.35, (s.y - 30.0) / 100.0)
	Art.push(ci, Vector2(cx, s.y * 0.5 + CABIN_H * k * 0.5 + sin(t * 1.4) * 4.0), 0.0, Vector2(k, k))
	draw_cabin(ci, look, t, 0.75, true)
	Art.pop(ci)


## Picture for the lift's card (the PC side column, like the boat and the
## plant): the raft's winch at the current look with its cable over the
## crane arm to the cabin hanging above the water. `p` is the trip's
## progress (< 0 = waiting): the crank turns and the cabin bobs while it runs.
static func draw_card_hero(ci: CanvasItem, s: Vector2, t: float, look: int, p: float) -> void:
	var sea_y := s.y * 0.66
	Art.flat(ci, Art.rrect_pts(Rect2(Vector2.ZERO, s), 14.0), Color("bfe8ff"))
	Art.flat(ci, Art.rrect_pts(Rect2(0, sea_y, s.x, s.y - sea_y), 14.0), Color("5ec4e6"))
	var busy := p >= 0.0
	var k := clampf(s.y / 150.0, 0.7, 1.2)
	var step := TAU / CRANK_STEPS
	var turn := fposmod(roundf(t * (6.0 if busy else 0.0) / step) * step, TAU)
	# Raft deck on the left with the post of the crane.
	var post_x := s.x * 0.2
	var deck := Vector2(post_x + 6.0 * k, sea_y + 2.0)
	var pulley := Vector2(s.x * 0.68, 20.0 * k)
	var arm := Art.WOOD if look <= 2 else (Color("8a94b8") if look <= 4 else Art.GOLD)
	Art.t_rect(ci, Rect2(-10, deck.y - 8.0 * k, post_x + 60.0 * k, 12.0 * k), 3, Art.WOOD, 2.5, 0.5)
	Art.t_rect(ci, Rect2(post_x - 5.0 * k, 12.0 * k, 10.0 * k, deck.y - 20.0 * k), 3, arm, 2.5, 0.4)
	Art.t_rect(ci, Rect2(post_x - 6.0 * k, pulley.y - 5.0 * k, pulley.x - post_x + 8.0 * k, 9.0 * k), 3, arm, 2.5, 0.4)
	# The cabin on its cable, bobbing a little while it runs.
	var cab := Vector2(pulley.x, sea_y + 8.0 * k + (snappedf(sin(t * 2.0), 0.25) * 3.0 if busy else 0.0))
	var ck := minf(k * 0.95, (cab.y - pulley.y - 18.0) / 76.0)
	var hook_y := cab.y - 70.0 * ck
	var c := cable_color(look)
	var wk := k * 0.85
	var drum := Vector2(post_x + 26.0 * k, deck.y - 8.0 * k - 22.0 * wk)
	var pts := PackedVector2Array([drum + Vector2(DRUM_R - 3.0, -DRUM_R + 3.0) * wk, Vector2(post_x + 2.0 * k, pulley.y + 2.0), pulley + Vector2(0, -7.0 * k)])
	Art.polyline(ci, pts, Art.INK, 6.0)
	Art.polyline(ci, pts, c, 3.0)
	Art.line(ci, pulley, Vector2(cab.x, hook_y), Art.INK, 6.0)
	Art.line(ci, pulley, Vector2(cab.x, hook_y), c, 3.0)
	Art.push(ci, pulley, snappedf(turn * 0.4, 0.2))
	Art.t_circle(ci, Vector2.ZERO, 8.0 * k, Art.METAL if look <= 4 else Art.GOLD, 2.4, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-6, -1.5, 12, 3), 1), Art.INK_SOFT)
	Art.pop(ci)
	Art.push(ci, cab, 0.0, Vector2(ck, ck))
	draw_cabin(ci, look, t, 1.0 if p >= DOWN_END else 0.25, busy)
	Art.pop(ci)
	Art.push(ci, drum, 0.0, Vector2(wk, wk))
	if look >= 3:
		draw_engine(ci, look, turn, busy, t)
	draw_winch(ci, look, turn, busy, t)
	Art.pop(ci)
	# Little waves over the water line.
	for x in range(8, int(s.x), 26):
		Art.arc(ci, Vector2(x, sea_y + 14.0), 5.0, PI * 1.1, PI * 1.9, 6, Color(1, 1, 1, 0.6), 2.0)
