class_name LiftView
extends Control
## The lift (Idle Miner's elevator) in the dive shaft: a winch on a small
## pontoon at the raft with its operator, a cable over the crane's pulley,
## and a cabin riding the cable. Divers leave their ore in a crate at their
## depth (GameState.pit); a trip goes down, stops at every open depth to
## empty its crate, comes back up and tosses the sacks into the raft chest.
## The cabin, the winch and the cable get a new look at the level
## milestones in Balance.LIFT_LOOKS (rope and bucket ... golden bathyscaphe).
## Also holds the lift's card (LiftCard) at the top of the shaft and the
## tap areas: a tap on the winch or the cabin taps the lift (one trip while
## it has no operator) and shows it in the upgrade panel.

const CAB_X := World.ROPE_X
## Bottom of the cabin when it waits under the raft.
const TOP_Y := World.SURFACE_Y + 92.0
const PULLEY := Vector2(World.ROPE_X, World.SURFACE_Y - 112.0)
## Guide wheel on top of the raft's crane post.
const GUIDE := Vector2(49.0, World.SURFACE_Y - 126.0)
## The winch's drum, up on the crane post under its arm, and its operator
## with a lever on the deck left of the post (the raft's loader stands
## right of it).
const WINCH := Vector2(33.0, World.SURFACE_Y - 98.0)
const OPERATOR := Vector2(17.0, World.SURFACE_Y - 15.0)
const LEVER := Vector2(35.0, World.SURFACE_Y - 16.0)
## Shares of a trip: down with the stops, back up, unloading at the top.
const DOWN_END := 0.55
const UP_END := 0.88
const CABIN_H := 62.0
const LOOKS := 6
## Card spot: right of the shaft, just under the water line.
const CARD_POS := Vector2(World.SHAFT_R + 14.0, World.SURFACE_Y + 26.0)

var world: World
var card: LiftCard

var _t := 0.0
var _top: PaintLayer
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
var _sync_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Balance.DEPTHS.size():
		_crates.append(0.0)
		_takes.append(0.0)
		_taken.append(true)
	_top = PaintLayer.new(_draw_top, false)
	add_child(_top)
	_hit_top = _hit_area()
	_hit_top.position = Vector2(0.0, World.SURFACE_Y - 120.0)
	_hit_top.size = Vector2(56.0, 124.0)
	_hit_cab = _hit_area()
	card = LiftCard.new("lift")
	card.world = world
	card.lift = self
	add_child(card)
	card.position = CARD_POS
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
	# The world is zoomed on wide screens; keep the card phone-sized there.
	var inv := 1.0 / maxf(0.5, world.scale.x)
	if not is_equal_approx(card.scale.x, inv):
		card.scale = Vector2(inv, inv)
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
	_hit_cab.position = cab + Vector2(-42.0, -CABIN_H - 26.0)
	_hit_cab.size = Vector2(84.0, CABIN_H + 40.0)
	self_modulate = Color.WHITE.lerp(DayNight.deep_tint(), 0.5)
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


## Syncs the look after a load, a Dive or a player switch.
func refresh() -> void:
	var now := Balance.lift_look(GameState.get_level("lift"))
	if now != _look and _t - _look_fx > 1.0:
		_look = now
		_look_old = now
	card.refresh()


# --- Drawing: shaft ---------------------------------------------------------------------

func _draw() -> void:
	var view := world.visible_rect().grow(60.0)
	var gs := GameState
	var p: float = gs.cycle_progress("lift")
	var tp := trip_at(p, _trip_deep)
	var cab := Vector2(CAB_X, float(tp[0]))
	var look := _shown_look()
	# Cable from the pulley down to the cabin's hook.
	var top := maxf(PULLEY.y, view.position.y)
	var bottom := minf(cab.y - CABIN_H - 4.0, view.end.y)
	if bottom > top:
		_cable(self, Vector2(CAB_X, top), Vector2(CAB_X, bottom), look)
	# Crates at every open depth.
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
	if view.grow(40.0).has_point(cab + Vector2(0, -CABIN_H * 0.5)):
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
		Art.push(self, cab, sway, Vector2(s, s))
		draw_cabin(self, look, _t, fill, p >= 0.0)
		Art.pop(self)


## Visual scale of each crate: 1 = one lift trip's share (full crate).
func _crate_scale() -> Array[float]:
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
	var c := Color("e8c48a") if look <= 2 else (Color("b9c3d6") if look <= 4 else Color("ffd86b"))
	Art.line(ci, a, b, c, 3.5)


## A wooden crate with the waiting ore; `fill` 1 = a lift trip's worth,
## more spills over.
func _draw_crate(i: int, at: Vector2, fill: float) -> void:
	var st: Dictionary = Art.DEPTH_STYLE[i]
	var f := snappedf(clampf(fill, 0.0, 1.5), 0.25)
	Art.push(self, at)
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
	var ore := {"ore": Art.DEPTH_STYLE[0]["ore"], "ore2": Art.DEPTH_STYLE[0]["ore2"]}
	var f := snappedf(clampf(fill, 0.0, 1.0), 0.25)
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
				var tw := 0.5 + 0.5 * sin(t * 4.0)
				Art.toon(ci, Art.star_pts(Vector2(-14, -50), 6.0, 2.5, 4), Color(1, 1, 1, snappedf(tw, 0.25)), 1.2, 0.0)
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
	# Cable: drum -> up the crane post -> along the arm -> over the pulley.
	var c := Color("e8c48a") if look <= 2 else (Color("b9c3d6") if look <= 4 else Color("ffd86b"))
	var pts := PackedVector2Array([WINCH + Vector2(0, -11), GUIDE + Vector2(-6, -4), GUIDE + Vector2(0, -7), PULLEY + Vector2(0, -9)])
	Art.push(ci, off)
	Art.polyline(ci, pts, Art.INK, 6.0)
	Art.polyline(ci, pts, c, 3.0)
	Art.pop(ci)
	Art.push(ci, GUIDE + off, _crank * 0.6)
	Art.t_circle(ci, Vector2.ZERO, 6.5, Art.METAL, 2.2, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-5, -1.2, 10, 2.4), 1), Art.INK_SOFT)
	Art.pop(ci)
	Art.push(ci, PULLEY + off, _crank * 0.4)
	Art.t_circle(ci, Vector2.ZERO, 9.0, Art.METAL if look <= 4 else Art.GOLD, 2.4, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-7, -1.5, 14, 3), 1), Art.INK_SOFT)
	Art.flat(ci, Art.rrect_pts(Rect2(-1.5, -7, 3, 14), 1), Art.INK_SOFT)
	Art.pop(ci)
	Art.push(ci, WINCH + off)
	_draw_winch(ci, look)
	Art.pop(ci)
	# The lever the operator works (tilts while the lift runs).
	var busy: bool = GameState.cycle_progress("lift") >= 0.0
	var tilt := (-0.35 if GameState.cycle_progress("lift") < DOWN_END else 0.35) if busy else 0.0
	Art.push(ci, LEVER + off)
	Art.t_rect(ci, Rect2(-7, -5, 14, 6), 2, Color("4a5270"), 2.0, 0.0)
	Art.push(ci, Vector2(0, -3), tilt)
	Art.t_rect(ci, Rect2(-2, -26, 4, 25), 2, Art.METAL, 2.0, 0.0)
	Art.t_circle(ci, Vector2(0, -28), 4.5, Art.RED, 2.0, 0.0)
	Art.pop(ci)
	Art.pop(ci)
	_draw_operator(ci, OPERATOR + off)
	# A new look pops in with a flash.
	var fx := _t - _look_fx
	if fx >= 0.0 and fx < 0.8:
		Art.glow(ci, WINCH + off, 40.0 * (1.0 + fx), Color(1, 1, 0.8, 0.6 * (1.0 - fx / 0.8)), 16)


## The winch on the raft's crane post (origin at the drum's axle): the drum
## with a crank, and below it the machine that turns it, fancier per look.
func _draw_winch(ci: CanvasItem, look: int) -> void:
	var busy: bool = GameState.cycle_progress("lift") >= 0.0
	# Bracket to the crane post.
	Art.t_rect(ci, Rect2(0, -4, 14, 8), 2, Art.WOOD_DARK if look <= 2 else Color("4a5270"), 2.2, 0.0)
	match look:
		2:
			Art.gear(ci, Vector2(-10, 12), 7.5, Art.METAL, -_crank * 1.6)
		3, 4:
			# A little steam engine that puffs while it winds.
			var metal := Color("8a94b8") if look == 3 else Art.BRASS
			Art.t_rect(ci, Rect2(-24, -2, 18, 22), 6, metal, 2.5, 0.6)
			Art.t_circle(ci, Vector2(-15, 9), 4.5, Art.WHITE, 1.8, 0.0)
			Art.push(ci, Vector2(-15, 9), sin(_t * 3.0) * 0.8 if busy else -0.6)
			Art.line(ci, Vector2.ZERO, Vector2(0, -3.2), Art.RED, 1.5)
			Art.pop(ci)
			Art.t_rect(ci, Rect2(-23, -14, 6, 13), 2, Color("4a5270"), 2.0, 0.0)
			if busy:
				for k in 2:
					var g := fposmod(_t * 0.9 + k * 0.5, 1.0)
					Art.disc(ci, Vector2(-20 - g * 8.0, -16 - g * 22.0), snappedf(3.0 + g * 5.0, 1.0), Color(1, 1, 1, snappedf(0.7 * (1.0 - g), 0.1)))
		5, 6:
			# Electric motor: a striped box with a lamp.
			var box := Color("ffc93c") if look == 5 else Color("ffe38a")
			Art.t_rect(ci, Rect2(-26, -8, 20, 24), 5, box, 2.5, 0.6)
			for k in 2:
				Art.flat(ci, PackedVector2Array([Vector2(-24 + k * 9, 10), Vector2(-20 + k * 9, 10), Vector2(-23 + k * 9, 15), Vector2(-26 + k * 9, 15)]), Art.INK)
			var lit := 1.0 if busy else 0.3
			Art.t_circle(ci, Vector2(-16, -1), 4.0, Color(1.0, 0.35 + 0.5 * lit, 0.3, 1.0), 1.8, 0.0)
			if busy:
				Art.glow(ci, Vector2(-16, -1), 11.0, Color(1, 0.8, 0.4, 0.4), 12)
			if look >= 6:
				Art.toon(ci, Art.star_pts(Vector2(-16, -14), 4.5, 2.0, 5), Art.WHITE, 1.2, 0.0)
	# The drum, its rope and the crank handle (turning).
	var drum := Art.WOOD if look <= 2 else (Color("4a5270") if look <= 4 else (Color("3a3f5c") if look == 5 else Art.GOLD_DARK))
	Art.push(ci, Vector2.ZERO, _crank)
	Art.t_circle(ci, Vector2.ZERO, 11.0, drum, 2.5, 0.4)
	Art.arc(ci, Vector2.ZERO, 7.0, 0, TAU, 16, Color("e8c48a") if look <= 2 else Color("b9c3d6"), 4.0)
	Art.line(ci, Vector2.ZERO, Vector2(0, -13), Art.INK, 3.0)
	Art.t_circle(ci, Vector2(0, -14), 3.5, Art.CORAL if look < 6 else Art.WHITE, 1.8, 0.0)
	Art.pop(ci)


## The operator: a worker who dozes by the winch while nobody sends the
## lift and cranks while it runs; once hired as the manager, the lift's own
## operator (the manager's look) who never sleeps.
func _draw_operator(ci: CanvasItem, at: Vector2) -> void:
	var gs := GameState
	var hired: bool = gs.has_manager("lift")
	var l: Dictionary = Chars.manager_look("lift") if hired else Chars.look(2, "short", 1, "beanie", "none", 2, "overalls")
	var p: float = gs.cycle_progress("lift")
	var mood := world.mood("lift")
	var emo := "happy"
	var arm_r := 0.5
	var arm_l := -0.2
	if p >= 0.0:
		emo = "focus" if not gs.is_rushing() else "joy"
		arm_r = -1.3 + snappedf(sin(_crank * 2.0), 0.25) * 0.5
	elif not hired and gs.pit > 0.0:
		emo = "sleepy" if _t - _idle_since > 5.0 else "bored"
	if mood != "":
		emo = mood
		if mood == "joy" or mood == "wow":
			arm_r = 2.4
			arm_l = -2.4
	var hop := world.hop("lift")
	Chars.person(ci, at - Vector2(0, hop), 0.7, 1.0, l, {"emotion": emo, "blink": Chars.blinking(_t, 3.3), "arm_r": arm_r, "arm_l": arm_l})
	if emo == "sleepy":
		Chars.mark(ci, "zzz", at + Vector2(6, -60), _t)


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
