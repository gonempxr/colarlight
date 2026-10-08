class_name SurfaceView
extends Control
## Everything above the "sea" of room 1 (the mine): the raft with the lift's
## crane and ore chest, the boats with their sailors, and the shore with the
## workers' house and the dock. The boats load at the raft and sail off the
## right edge of the screen to the factory (room 2), then come back.
##
## Each world has its own shore (WorldLook.world): the ocean's sandy beach
## with a palm and a lighthouse, the volcano's basalt shore with a smoking
## volcano behind and a lava river, the acid swamp's mossy mud with giant
## mushrooms and fireflies, the moon's grey regolith under a black sky with
## the Earth hanging in it (the boats hover over its dust "sea").
##
## The shore is laid out left to right: the raft (the lift's winch and
## operator left of its crane post, the loader and the ore chest right of
## it), the boat lane, the dock (the second boat moors at it), the house,
## the signpost to the factory and the world's edge prop (the palm) half
## off the screen. On narrow screens the shore shrinks (see _layout).
##
## While the second boat is for sale (from the third site on) a buoy with a
## price board under the dock marks it; a tap there selects it.
##
## The sky itself (gradient, sun, moon, stars) is drawn by World under the
## water, so the sun really sinks into the sea. This view adds, in layers:
##   _sky_fx  (behind)  clouds (ash, mist, asteroids), rain, birds (fire
##                      birds, dragonflies, satellites), volcano smoke,
##                      fireflies, the lighthouse beam
##   _far     (behind)  far islands, the volcano, ridges and the landmark
##                      (still, repainted when the light changes)
##   _ground  (behind)  the shore and the house (still)
##   self               edge prop, dock, raft, boats, waves, smoke
##   _glow    (front)   night lights and the ore number tag (never tinted)
## Almost everything can be tapped for a little reaction (see _poke_ambient).

const BOAT_SCALE := 0.85
## Boat trip: load at the raft, sail out to the right, (at the factory),
## sail back.
const BOAT_LOAD_END := 0.12
const BOAT_OUT_END := 0.42
const BOAT_BACK_START := 0.6
## Smallest tap target for scenery, so small fingers hit it.
const TAP_R := 46.0
## The raft's chest (raft-local) stands right of the lift cable, and the
## deck reaches RAFT_DECK: the winch and its operator keep the left end.
const RAFT_CHEST := Vector2(50, -15)
const RAFT_DECK := 90.0
const RAFT_CHEST_SCALE := 0.8
const TAG_SCALE := 0.84

# --- Shore layout ---
## A boat loads with its stern at RAFT_RIGHT (clear of the raft's chest and
## its tag). The shore is laid out from the dock's tip in shore units,
## scaled by _k:
##   0 .. PIER_W   the dock (the second boat moors under its tip)
##   HOUSE_AT      the workers' house
##   SIGN_AT       the signpost to the factory
##   SHORE_W       the screen edge (the edge prop stands half off it)
const RAFT_RIGHT := 192.0
const BERTH_GAP := 5.0
## Least room the boat sails between the raft and the dock.
const TRAVEL_MIN := 36.0
## Stern and bow of each boat stage (scale 1, facing +x): where it moors.
const BOAT_EXT: Array[Vector2] = [Vector2(80, 82), Vector2(90, 92), Vector2(107, 97), Vector2(111, 109), Vector2(94, 102),
		Vector2(114, 105), Vector2(116, 105), Vector2(125, 111), Vector2(118, 107), Vector2(103, 118), Vector2(108, 116),
		Vector2(134, 116), Vector2(127, 110), Vector2(117, 117), Vector2(125, 116), Vector2(132, 126), Vector2(132, 137),
		Vector2(137, 122), Vector2(134, 127), Vector2(137, 148)]
## The longest hull (stern + bow) the fit makes room for.
const BOAT_LONGEST := 285.0
const PIER_W := 128.0
const PIER_H := 54.0
## Where the ground meets the water (the dock's end rests on the slope).
const SHORE_AT := 96.0
const GROUND := 64.0
const HOUSE_AT := 150.0
const SIGN_AT := 340.0
const SHORE_W := 400.0
## The edge prop's foot stands this far past the screen edge.
const PALM_OUT := 6.0
## Second boat: smaller, in a lane a little farther away. It waits at the
## dock (stern under its tip, bow to the raft), sails to the raft (until
## B2_ARRIVE), loads (until B2_LEAVE), sails off to the factory (until
## B2_OUT), comes back from the right (from B2_BACK) to the dock.
const BOAT2_SCALE := 0.68
const BOAT2_LANE := -5.0
const BOAT2_TUCK := 10.0
const B2_ARRIVE := 0.25
const B2_LEAVE := 0.36
const B2_OUT := 0.6
const B2_BACK := 0.74
## While it is for sale its buoy floats under the dock's tip and its price
## board hangs from the dock's beam.
const BUOY_AT := 14.0
const BOARD_AT := 76.0
const BOARD_SCALE := 0.8
const PIER_LOW := 46.0
## Moon boats hover this high over the dust.
const HOVER := 10.0
const BUILDINGS: Array[String] = ["boat", "boat2"]

var world: World
var boat_card: StageCard
## Kept for the phone layout until the factory room takes the plant's card.
var plant_card: StageCard

## Shore scale (1 = full size) and the dock's tip, from _layout.
var _k := 1.0
var _tip := 440.0

var _t := 0.0
## Shown facing of each boat while it turns round (see _turned).
var _turn := {}
const TURN_SEC := 0.7
var _smoke: Array[Vector3] = []   # x, y, age
var _boat_p := -1.0
var _boat2_p := -1.0
var _pending_throws: Array[Array] = []   # [time, kind, a, b]

var _sky_fx: PaintLayer
var _far: PaintLayer
var _far_step := -1.0
var _glow_last := []
var _ground: PaintLayer
var _ground_sig := []
var _glow: PaintLayer
var _l_back: PaintLayer
var _l_mid: PaintLayer
var _l_front: PaintLayer
var _boat_spr := {}
var _wake_spr := {}
## Canvas item the scene's drawing helpers draw on right now.
var _ci: CanvasItem


## A moving piece of the scene (a boat, its wake): drawn where it was at
## `rec` and moved by its transform to where it is now, so it moves on
## every frame while its picture changes only when `stamp` does.
class SceneSprite extends Node2D:
	var painter: Callable
	var rec := Transform2D.IDENTITY
	var stamp := -1

	func _draw() -> void:
		painter.call(self)

	func place(now: Transform2D, new_stamp: int) -> void:
		if new_stamp != stamp:
			stamp = new_stamp
			rec = now
			queue_redraw()
		transform = now * rec.affine_inverse()
var _tint := Color.WHITE
var _calm := false

# Sky life.
var _clouds: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _rain: Array[Vector3] = []            # x, y, speed
var _feathers: Array[Dictionary] = []
var _gusts: Array[Vector3] = []           # x, y, age
var _lighthouse_poke := -99.0
var _house_poke := -99.0
var _sign_poke_at := -99.0
## Sky and shore pokes are only for fun: past Balance.TAP_CAP a second per
## thing (an autoclicker) they stop sparkling and making sounds.
var _poke_cap := TapLimiter.new(Balance.TAP_CAP, Balance.TAP_WINDOW)
var _rng := RandomNumberGenerator.new()

# The edge prop (palm) and its coconuts.
var _palm_poke := -99.0
## The palm's wobble after taps: rises quickly and dies away smoothly, and
## more taps only keep it up (restarting it made the palm jerk).
var _palm_amp := 0.0
var _palm_want := 0.0
var _coconuts := 2
var _coconut_back := 0.0
var _coconut := {}

# The raft's ore chest: lid angle (a spring), lid speed, number tag pop.
var _chest := {
	"raft": {"lid": 0.0, "vel": 0.0, "tag": 0.0, "shown": 0.0},
}

# Building looks: the stage shown, the one before, and when it changed.
var _stage := {"boat": 0, "boat2": 0}
var _stage_old := {"boat": 0, "boat2": 0}
var _stage_fx := {"boat": -99.0, "boat2": -99.0}
## Only a change right after an upgrade is celebrated (not loads or profile switches).
var _upgraded_at := {"boat": -99.0, "boat2": -99.0}
## When the second boat was bought (the for-sale sign poofs away).
var _opened_at := {"boat2": -99.0}
## Last tap on a for-sale sign (it wobbles).
var _sign_poke := {"boat2": -99.0}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_layout()
	_rng.seed = 11
	_sky_fx = PaintLayer.new(_draw_sky_fx)
	add_child(_sky_fx)
	_far = PaintLayer.new(_paint_far)
	add_child(_far)
	_ground = PaintLayer.new(_paint_ground)
	add_child(_ground)
	# The shore scene in front of those, back to front (each layer redraws
	# with the scenery; the boats and their wakes are sprites that move on
	# every frame, see _place_boats).
	_l_back = PaintLayer.new(_paint_back, false)
	add_child(_l_back)
	for key in ["boat2", "boat"]:
		var spr := SceneSprite.new()
		spr.painter = _paint_boat.bind(key)
		add_child(spr)
		_boat_spr[key] = spr
		var wake := SceneSprite.new()
		wake.painter = _paint_wake.bind(key)
		add_child(wake)
		_wake_spr[key] = wake
		if key == "boat2":
			_l_mid = PaintLayer.new(_paint_mid, false)
			add_child(_l_mid)
	_l_front = PaintLayer.new(_paint_front, false)
	add_child(_l_front)
	_glow = PaintLayer.new(_draw_glow, false)
	add_child(_glow)
	boat_card = StageCard.new("boat")
	boat_card.world = world
	boat_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(boat_card)
	plant_card = StageCard.new("plant")
	plant_card.world = world
	plant_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	add_child(plant_card)
	GameState.cycle_started.connect(_on_cycle_started)
	GameState.cycle_finished.connect(_on_cycle_finished)
	GameState.upgraded.connect(func(k: String, _n: int) -> void:
		if _upgraded_at.has(k):
			_upgraded_at[k] = _t)
	GameState.depth_opened.connect(_on_opened)
	for c in [[0.12, 262.0, 0.8, 1], [0.52, 310.0, 0.95, 2], [0.86, 244.0, 0.72, 3], [0.36, 128.0, 0.62, 4]]:
		_clouds.append({"x": c[0], "y": c[1], "s": c[2], "seed": c[3], "poke": -99.0, "rain": -99.0})
	for i in 2:
		_birds.append(_new_bird(_rng.randf(), i))
	for key in BUILDINGS:
		_stage[key] = Props.current_stage(key)
		_stage_old[key] = _stage[key]
	_chest["raft"]["shown"] = GameState.hold


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and plant_card:
		_layout()
		plant_card.position = Vector2(world.card_x(), 14)
		boat_card.position = Vector2(world.card_x() - 12 - World.CARD_W, 14)


func repaint_still() -> void:
	_far.queue_redraw()
	_ground.queue_redraw()


func refresh() -> void:
	boat_card.refresh()
	plant_card.refresh()


# --- Layout ------------------------------------------------------------------------------

## Fits the shore to the width: full size when the raft, the longest boat
## and the shore fit side by side, smaller otherwise (phones).
func _layout() -> void:
	var w := maxf(size.x, 360.0)
	var need := BOAT_LONGEST * BOAT_SCALE + BERTH_GAP + SHORE_W
	_k = clampf((w - RAFT_RIGHT - TRAVEL_MIN) / need, 0.5, 1.0)
	_tip = w - SHORE_W * _k
	if _far:
		repaint_still()


## A point on the shore: `u` shore units right of the dock's tip.
func _at(u: float) -> float:
	return _tip + u * _k


## Where the ground meets the water.
func island_x() -> float:
	return _at(SHORE_AT)


func raft_pos() -> Vector2:
	return Vector2(World.ROPE_X, World.SURFACE_Y)


func _ground_y() -> float:
	return World.SURFACE_Y - GROUND * _k


## The dock's deck; never lower than PIER_LOW, so the price board of the
## second boat can hang under it.
func _pier_y() -> float:
	return World.SURFACE_Y - maxf(PIER_H * _k, PIER_LOW)


func _beam_bottom() -> float:
	return _pier_y() + 13.0 * _k


func house_pos() -> Vector2:
	return Vector2(_at(HOUSE_AT), _ground_y())


func house_rect() -> Rect2:
	var p := house_pos()
	return Rect2(p.x, p.y - 140.0 * _k, WorldArt.HOUSE_W * _k, 140.0 * _k)


## The signpost to the factory at the shore's right end.
func sign_pos() -> Vector2:
	return Vector2(_at(SIGN_AT), _ground_y())


## Where the boats' cargo goes: the signpost to the factory (the plant
## itself works in the factory room). Hints and the tutorial point here.
func plant_world_pos() -> Vector2:
	return sign_pos() + Vector2(-40, 0) * _k


func plant2_world_pos() -> Vector2:
	return plant_world_pos()


## Stern and bow of a boat at its current look, at its scale.
func _hull(key: String) -> Vector2:
	return BOAT_EXT[clampi(_stage[key], 1, BOAT_EXT.size()) - 1] * _boat_scale(key)


## x of the boat at the raft (stern to the raft) and off the screen's right edge.
func boat_x_range() -> Vector2:
	var ex := _hull("boat").x if is_nan(_boat_ex) else _boat_ex
	var r := RAFT_RIGHT + BERTH_GAP + ex
	return Vector2(r, size.x + ex + 30.0)


## The boat's half length as shown: eases to a bigger hull after an upgrade
## instead of moving the boat at once.
var _boat_ex := NAN


func _water_y() -> float:
	return World.SURFACE_Y + (-HOVER if WorldLook.world == "moon" else 4.0)


func boat_world_pos() -> Vector2:
	var r := boat_x_range()
	var p := Motion.progress("boat")
	var x := r.x
	if p >= BOAT_LOAD_END and p < BOAT_OUT_END:
		x = lerpf(r.x, r.y, smoothstep(BOAT_LOAD_END, BOAT_OUT_END, p))
	elif p >= BOAT_OUT_END and p < BOAT_BACK_START:
		x = r.y
	elif p >= BOAT_BACK_START:
		x = lerpf(r.y, r.x, smoothstep(BOAT_BACK_START, 1.0, p))
	return Vector2(x, _water_y())


func _boat_facing() -> float:
	return _turned("boat")


## Where a boat heads now (+1 right, -1 left), before the turn is shown.
func _heading(key: String) -> float:
	var p := Motion.progress(key)
	if key == "boat":
		return -1.0 if p >= BOAT_BACK_START else 1.0
	# It starts turning round a moment before it pulls away from the raft.
	return 1.0 if p >= B2_LEAVE - 0.04 and p < B2_OUT + 0.01 else -1.0


## Shown facing: a boat turns round over TURN_SEC (its width goes through
## a thin sliver) instead of flipping in one frame.
func _turned(key: String) -> float:
	var f: float = _turn.get(key, _heading(key))
	var e := Motion.ease_in_out(f * 0.5 + 0.5) * 2.0 - 1.0
	return signf(e) * maxf(0.08, absf(e)) if e != 0.0 else 0.08


func _update_turns(delta: float) -> void:
	for key in BUILDINGS:
		var want := _heading(key)
		var f: float = _turn.get(key, want)
		# Off screen (at the factory) it simply faces the new way.
		if _boat_pos(key).x - maxf(_hull(key).x, _hull(key).y) > size.x + 10.0:
			f = want
		_turn[key] = move_toward(f, want, delta * 2.0 / TURN_SEC)


func _boat_deck(bp: Vector2) -> Vector2:
	return bp + Vector2(30.0 * _boat_facing(), -50.0) * _boat_scale("boat")


## The second boat: x at the raft (bow to it), at the dock (stern tucked
## under the dock's tip) and off the right edge.
func boat2_x_range() -> Vector2:
	var e := _hull("boat2")
	var r := RAFT_RIGHT + BERTH_GAP + e.y
	return Vector2(r, maxf(r, _at(BOAT2_TUCK) + e.x * 0.35))


func boat2_world_pos() -> Vector2:
	var r := boat2_x_range()
	var off := size.x + _hull("boat2").y + 30.0
	var p := Motion.progress("boat2")
	var x := r.y
	if p >= 0.0 and p < B2_ARRIVE:
		x = lerpf(r.y, r.x, smoothstep(0.0, B2_ARRIVE, p))
	elif p >= B2_ARRIVE and p < B2_LEAVE:
		x = r.x
	elif p >= B2_LEAVE and p < B2_OUT:
		x = lerpf(r.x, off, smoothstep(B2_LEAVE, B2_OUT, p))
	elif p >= B2_OUT and p < B2_BACK:
		x = off
	elif p >= B2_BACK:
		x = lerpf(off, r.y, smoothstep(B2_BACK, 1.0, p))
	return Vector2(x, _water_y() - 4.0 + BOAT2_LANE)


func _boat2_facing() -> float:
	return _turned("boat2")


func _boat_pos(key: String) -> Vector2:
	return boat_world_pos() if key == "boat" else boat2_world_pos()


func _boat_scale(key: String) -> float:
	return (BOAT_SCALE if key == "boat" else BOAT2_SCALE) * _k


func _facing(key: String) -> float:
	return _boat_facing() if key == "boat" else _boat2_facing()


func _deck_of(key: String) -> Vector2:
	return _boat_pos(key) + Vector2(30.0 * _facing(key), -50.0) * _boat_scale(key)


## Is the boat under way (for the foam and the sailor's wave)?
func _sailing(key: String) -> bool:
	var p := Motion.progress(key)
	if key == "boat":
		return p >= BOAT_LOAD_END
	return p >= 0.0 and not (p >= B2_ARRIVE and p < B2_LEAVE)


## Crates on deck (0..3) while the boat carries ore.
func _crates(key: String) -> int:
	var p := Motion.progress(key)
	var loaded := (p >= 0.04 and p < BOAT_BACK_START) if key == "boat" else (p >= B2_ARRIVE and p < B2_BACK)
	if not loaded:
		return 0
	var cap := maxf(1.0, GameState.cycle_capacity(key))
	return clampi(ceili(GameState.cycle_load(key) / cap * 3.0), 1, 3)


## Where the second boat's buoy floats while it is for sale: under the
## dock, at its future berth.
func buoy_pos() -> Vector2:
	return Vector2(_at(BUOY_AT), World.SURFACE_Y + sin(_t * 1.8) * 2.0)


## For-sale sign placement: [foot of the board, post length, scale]: the
## second boat's price board hangs from the dock's beam.
func _sign_place(_key: String) -> Array:
	return [Vector2(_at(BOARD_AT), _beam_bottom() + 4.0 + 34.0 * BOARD_SCALE), 0.0, BOARD_SCALE]


func _sign_rect(key: String) -> Rect2:
	var place := _sign_place(key)
	var foot: Vector2 = place[0]
	var post: float = place[1]
	var sc: float = place[2]
	var w := maxf(TAP_R, Props.sale_sign_width(_price(key)) * sc)
	var h := maxf(TAP_R, (post + 34.0) * sc + 12.0)
	return Rect2(foot.x - w / 2.0, foot.y - h + 6.0, w, h)


## "open", "sale" (closed, for sale once the third site is open) or "" (not
## shown yet) for "boat2". Right after buying, the sign stays a moment
## while the poof hides the swap.
func second_state(key: String) -> String:
	var open: bool = GameState.is_open(key)
	if open and _t - float(_opened_at.get(key, -99.0)) >= 0.22:
		return "open"
	var d2: bool = GameState.is_open("d2")
	return "sale" if open or d2 else ""


func _building_rect(key: String) -> Rect2:
	var bp := _boat_pos(key)
	var bs := _boat_scale(key)
	var e := _hull(key)
	var bh := Props.boat_height(_stage[key]) * bs
	var back := e.x if _facing(key) > 0.0 else e.y
	var front := e.y if _facing(key) > 0.0 else e.x
	return Rect2(bp.x - back, bp.y - bh - 8.0, back + front, bh + 22.0)


func _ore() -> Color:
	return Art.DEPTH_STYLE[0]["ore2"]


func _raft_bob() -> float:
	match WorldLook.world:
		"moon":
			return sin(_t * 1.1) * 1.0
		"volcano":
			return sin(_t * 1.0) * 1.5
	return sin(_t * 1.6) * 3.0


func _raft_chest_pos() -> Vector2:
	return raft_pos() + RAFT_CHEST + Vector2(0, _raft_bob())


func _palm_pos() -> Vector2:
	return Vector2(size.x + PALM_OUT * _k, _ground_y())


## The ocean's lighthouse (and the acid tree, the moon's radar tower)
## stands far out between the raft and the dock; the volcano's landmark is
## the volcano itself, behind the scene.
func _lighthouse_pos() -> Vector2:
	if WorldLook.world == "volcano":
		return _volcano_pos()
	return Vector2(lerpf(RAFT_RIGHT, _tip, 0.55), World.SURFACE_Y)


func _volcano_pos() -> Vector2:
	return Vector2(lerpf(RAFT_RIGHT, size.x, 0.42), World.SURFACE_Y - 4.0)


func _volcano_h() -> float:
	return clampf(size.x * 0.24, 150.0, 240.0)


## Point where the landmark reacts to a tap (its lamp, the volcano's crater).
func _landmark_top() -> Vector2:
	if WorldLook.world == "volcano":
		return _volcano_pos() + WorldArt.VOLCANO_TOP * (_volcano_h() / 220.0)
	return _lighthouse_pos() + Props.LIGHTHOUSE_LAMP


## Stage drawn right now: the old look stays a moment while the poof hides the swap.
func _shown_stage(key: String) -> int:
	return _stage_old[key] if _t - float(_stage_fx[key]) < 0.22 else _stage[key]


func _price(key: String) -> String:
	var cost: float = GameState.unlock_cost(key)
	return NumFormat.short(cost)


func _can_buy(key: String) -> bool:
	var cost: float = GameState.unlock_cost(key)
	var coins: float = GameState.coins
	return coins >= cost


# --- Events -----------------------------------------------------------------------------

func _on_cycle_started(key: String, _amount: float) -> void:
	if key == "boat":
		var from := _raft_chest_pos() + Vector2(0, -34)
		var to := _boat_deck(boat_world_pos())
		_pending_throws.append([_t, "sack", from, to])
		_pending_throws.append([_t + 0.25, "sack", from, to])
		_pop_chest("raft", 0.7)
		world.react("raft", "joy", 0.8, true)


## The second boat was bought: poof the sign away.
func _on_opened(key: String) -> void:
	if not _opened_at.has(key):
		return
	_opened_at[key] = _t
	_stage[key] = Props.current_stage(key)
	_stage_old[key] = _stage[key]
	_stage_fx[key] = _t
	Sfx.play("unlock")


func _on_cycle_finished(key: String, _amount: float) -> void:
	if key.begins_with("d"):
		world.react("raft", "joy", 0.5, true)
		_pop_chest("raft", 1.0)


## Kicks a chest lid open (it springs back by itself).
func _pop_chest(which: String, strength: float) -> void:
	if not _chest.has(which):
		return
	var c: Dictionary = _chest[which]
	c["vel"] = maxf(float(c["vel"]), 0.0) + 7.5 * strength


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag():
			return
		World.hurry()
		var p: Vector2 = event.position
		if _on_card(p):
			return
		var key := _building_at(p)
		if key.begins_with("sale:"):
			# A for-sale sign: show the second boat in the upgrade panel.
			key = key.substr(5)
			_sign_poke[key] = Motion.repoke(float(_sign_poke.get(key, -99.0)), _t, 0.6)
			Sfx.play("click")
			Settings.buzz(12)
			world.divers.tap_ripple(p)
			world.select(key)
			return
		if key == "" and _poke_ambient(p):
			return
		if key == "":
			# The open "sea" between the raft and the dock belongs to the boat.
			if p.y < 250.0 or p.x > _tip:
				return
			key = "boat"
		if key == "plant":
			# The signpost leads to the factory room (main.gd switches rooms).
			_sign_poke_at = _t
			Sfx.play("click")
			world.divers.tap_ripple(p)
			world.select("room:factory")
			return
		if GameState.tap(key):
			Sfx.play("tap" if GameState.is_boat(key) else "machine")
		else:
			Sfx.play("tap")
		world.divers.tap_ripple(p)


func _on_card(p: Vector2) -> bool:
	var g := get_global_transform() * p
	for c: Control in [boat_card, plant_card]:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(g):
			return true
	return false


## The boats, the raft and the signpost take taps first (things in front
## before things behind). Returns the key, "sale:boat2" for the for-sale
## sign, or "".
func _building_at(p: Vector2) -> String:
	if _building_rect("boat").has_point(p):
		return "boat"
	var r := raft_pos()
	if Rect2(r.x - 70.0, r.y - 160.0, 70.0 + RAFT_DECK + 6.0, 176.0).has_point(p):
		return "boat"
	var boat2 := second_state("boat2")
	if boat2 == "sale" and _sign_rect("boat2").has_point(p):
		return "sale:boat2"
	if boat2 == "open" and _building_rect("boat2").has_point(p):
		return "boat2"
	if boat2 == "sale" and Rect2(buoy_pos() + Vector2(-TAP_R / 2.0, -40.0), Vector2(TAP_R, 52.0)).has_point(p):
		return "sale:boat2"
	# Until the factory room runs the plant, its signpost on the shore does.
	var sp := sign_pos()
	if Rect2(sp.x - maxf(TAP_R, 44.0 * _k), sp.y - 110.0 * _k, maxf(TAP_R * 2.0, 88.0 * _k), 116.0 * _k).has_point(p):
		return "plant"
	return ""


## Sun, moon, clouds, birds, fish, the edge prop, the house and the
## landmark react to a tap. Returns false when nothing was hit.
func _poke_ambient(p: Vector2) -> bool:
	var w := size.x
	var hit := {"name": "", "d": 1.0, "i": -1}
	var consider := func(name: String, at: Vector2, r: float, i: int = -1) -> void:
		var d := p.distance_to(at) / maxf(r, TAP_R)
		if d < float(hit["d"]):
			hit["d"] = d
			hit["name"] = name
			hit["i"] = i
	if DayNight.sun_up():
		var sp := DayNight.sun_pos(w)
		if sp.y < World.SURFACE_Y - 10.0:
			consider.call("sun", sp, 60.0)
	else:
		var mp := DayNight.moon_pos(w)
		if mp.y < World.SURFACE_Y - 10.0:
			consider.call("moon", mp, 52.0)
	for i in _clouds.size():
		var c: Dictionary = _clouds[i]
		consider.call("cloud", _cloud_pos(c) + Vector2(0, -8), 58.0 * float(c["s"]) + 6.0, i)
	for i in _birds.size():
		var b: Dictionary = _birds[i]
		if float(b["flee"]) < 0.0 and float(b["wait"]) <= 0.0:
			consider.call("bird", Vector2(b["x"], b["y"]), TAP_R, i)
	consider.call("palm", _palm_pos() + Props.PALM_TOP * _k, 56.0)
	consider.call("palm", _palm_pos() + Vector2(-6, -40) * _k, TAP_R)
	consider.call("lighthouse", _landmark_top() + Vector2(0, 30), 48.0)
	if house_rect().has_point(p):
		consider.call("house", p, TAP_R)
	var best: String = hit["name"]
	var bi: int = hit["i"]
	if best == "" and p.y > World.SURFACE_Y and world.is_fish_at(p):
		if _poke_cap.allow("fish", _t):
			world.poke_fish(p)
		return true
	if best == "" and p.y < World.SURFACE_Y - 60.0 and DayNight.starlight() > 0.5:
		best = "sky"
	if best != "" and not _poke_cap.allow(best, _t):
		return true
	match best:
		"sun":
			world.pokes["sun"] = Motion.repoke(float(world.pokes.get("sun", -99.0)), world.t, 1.2)
			world.divers.sparkle(DayNight.sun_pos(w), 8)
			Sfx.play("upgrade", 1.3)
			Sfx.voice("yay", 1.6)
		"moon":
			world.pokes["moon"] = Motion.repoke(float(world.pokes.get("moon", -99.0)), world.t, 1.4)
			world.shooting_star(DayNight.moon_pos(w) + Vector2(-40, -30))
			Sfx.play("upgrade", 0.8)
			Sfx.voice("ooh", 1.5)
		"cloud":
			var c: Dictionary = _clouds[bi]
			c["poke"] = Motion.repoke(float(c["poke"]), _t, 1.0)
			c["rain"] = _t + 2.4
			Sfx.play("pop", 0.6)
			Sfx.play("dive", 1.35)
		"bird":
			var b: Dictionary = _birds[bi]
			b["flee"] = _t
			_feathers.append({"pos": Vector2(b["x"], b["y"]), "age": 0.0, "seed": _rng.randf() * 10.0})
			Sfx.voice("hup", 1.9)
			Sfx.play("pop", 1.7)
		"palm":
			_palm_poke = _t
			_palm_want = 1.0
			Sfx.play("dig", 0.8)
			if WorldLook.world == "ocean":
				if _coconuts > 0 and _coconut.is_empty():
					_coconuts -= 1
					_coconut_back = _t + 25.0
					var top := _palm_pos() + Props.PALM_TOP + Vector2(4.0 if _coconuts == 1 else -4.0, 6.0)
					_coconut = {"pos": top, "vel": Vector2(_rng.randf_range(-40, -10), -60), "age": 0.0, "rot": 0.0, "bounces": 0}
			else:
				world.divers.sparkle(_palm_pos() + Vector2(-30, -90) * _k, 8)
		"lighthouse":
			_lighthouse_poke = Motion.repoke(_lighthouse_poke, _t, 2.2)
			Sfx.play("pop", 0.8)
			if WorldLook.world == "volcano":
				Sfx.play("dig", 0.6)
		"house":
			_house_poke = Motion.repoke(_house_poke, _t, 1.6)
			_ground.queue_redraw()
			Sfx.play("click", 0.9)
			Sfx.voice("hup", 1.5)
			world.divers.sparkle(house_pos() + Vector2(50, -60) * _k, 6)
		"sky":
			# A tap on the empty night sky sends a shooting star.
			world.shooting_star(p)
			Sfx.play("upgrade", 1.7)
			return true
		_:
			return false
	Settings.buzz(12)
	return true


# --- Sky life -------------------------------------------------------------------------

func _new_bird(x: float, i: int) -> Dictionary:
	return {"x": x * (size.x + 80.0) - 40.0, "y": 150.0 + i * 64.0 + _rng.randf_range(-16, 16), "speed": _rng.randf_range(34, 52),
			"phase": _rng.randf() * TAU, "flee": -1.0, "vy": 0.0, "wait": 0.0}


func _cloud_pos(c: Dictionary) -> Vector2:
	var span := size.x + 260.0
	return Vector2(fposmod(float(c["x"]) * span, span) - 130.0, c["y"])


func _process(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 20.0)
	_calm = Settings.reduce_motion
	var wind := DayNight.wind * (0.5 if _calm else 1.0)
	Props.wind = wind
	_update_stages()
	var ex := _hull("boat").x
	_boat_ex = ex if is_nan(_boat_ex) else Motion.damp(_boat_ex, ex, 6.0, delta)
	for key in ["boat", "boat2"]:
		if GameState.cycle_progress(key) >= 0.0 and randf() < delta * 3.0 and (key == "boat" or second_state(key) == "open"):
			var bp := _boat_pos(key)
			var bs := _boat_scale(key)
			if bp.x < size.x + 40.0:
				for s in Props.boat_smoke_points(_stage[key]):
					_smoke.append(Vector3(bp.x + s.x * bs * _facing(key), bp.y + s.y * bs, 0.0))
	# The edge prop of the volcano (a charred tree) smoulders.
	if WorldLook.world == "volcano" and randf() < delta * 1.2:
		_smoke.append(Vector3(_palm_pos().x - 20.0 * _k, _palm_pos().y - 100.0 * _k, 0.0))
	for i in range(_smoke.size() - 1, -1, -1):
		var s := _smoke[i]
		s.z += delta
		s.y -= delta * (30.0 - wind * 8.0)
		s.x += delta * (6.0 + wind * 34.0) * minf(1.0, s.z * 1.5)
		_smoke[i] = s
		if s.z > 2.4:
			_smoke.remove_at(i)
	_update_sky(dt, wind)
	_update_chests(dt)
	# Sacks thrown with a small delay.
	for i in range(_pending_throws.size() - 1, -1, -1):
		var th: Array = _pending_throws[i]
		if _t >= th[0]:
			world.divers.throw_item(th[1], th[2], th[3], _ore(), 0.5)
			_pending_throws.remove_at(i)
	_update_turns(delta)
	_palm_amp = Motion.damp(_palm_amp, _palm_want, 14.0, dt)
	_palm_want *= exp(-2.4 * dt)
	var bprog := Motion.progress("boat")
	if _boat_p < BOAT_BACK_START and bprog >= BOAT_BACK_START:
		world.react("sailor", "joy", 0.8, true)
	_boat_p = bprog
	# The second boat loads when it reaches the raft.
	var b2 := Motion.progress("boat2")
	if _boat2_p < B2_ARRIVE and b2 >= B2_ARRIVE:
		var from := _raft_chest_pos() + Vector2(0, -34)
		_pending_throws.append([_t, "sack", from, _deck_of("boat2")])
		_pending_throws.append([_t + 0.25, "sack", from, _deck_of("boat2")])
		_pop_chest("raft", 0.7)
		world.react("raft", "joy", 0.8, true)
	if _boat2_p < B2_BACK and b2 >= B2_BACK:
		world.react("sailor2", "joy", 0.8, true)
	_boat2_p = b2
	var tint := DayNight.scene_tint()
	if not tint.is_equal_approx(_tint):
		_tint = tint
		self_modulate = tint
		_ground.self_modulate = tint
	# The house's windows light up at night, its door opens on a tap.
	var gsig := [WorldLook.location, snappedf(smoothstep(0.3, 0.8, DayNight.night()), 0.25), _house_door() > 0.0, snappedf(_house_door(), 0.1)]
	if gsig != _ground_sig:
		_ground_sig = gsig
		_ground.queue_redraw()
	# The crew, boats and shore redraw on the scene's SCENERY frames, the
	# sky life on the others (see World's frame schedule).
	if world.is_visible_band(0.0, size.y):
		if World.tick(World.SCENERY):
			_redraw_scene()
			# Night lights flicker; by day only the number tag moves.
			var sig := _glow_sig()
			if smoothstep(0.3, 0.8, DayNight.night()) > 0.01 or sig != _glow_last:
				_glow_last = sig
				_glow.queue_redraw()
		if World.tick(World.PEOPLE) and world.is_visible_band(0.0, World.SURFACE_Y):
			_sky_fx.queue_redraw()
			if _t - _lighthouse_poke < 2.4:
				_far.queue_redraw()
	_place_boats()
	var step := DayNight.stepped_phase()
	if step != _far_step:
		_far_step = step
		_far.queue_redraw()


## How far the house door is open (0..1) after a tap.
func _house_door() -> float:
	var age := _t - _house_poke
	if age < 0.0 or age > 1.6:
		return 0.0
	return clampf(minf(age / 0.2, (1.6 - age) / 0.4), 0.0, 1.0)


func _update_stages() -> void:
	for key in BUILDINGS:
		var st := Props.current_stage(key)
		if st == int(_stage[key]):
			continue
		var grew: bool = st > int(_stage[key]) and _t - float(_upgraded_at[key]) < 1.0
		_stage_old[key] = _stage[key] if grew else st
		_stage[key] = st
		if grew:
			_stage_fx[key] = _t
			var at := world.stage_anchor(key)
			world.divers.confetti(at, 44)
			world.divers.sparkle(at, 14)
			world.react(key, "wow", 1.6, true)
			Sfx.play("unlock")


func _update_sky(dt: float, wind: float) -> void:
	var w := size.x
	var span := w + 260.0
	for c in _clouds:
		c["x"] = float(c["x"]) + dt * (4.0 + wind * 12.0) * (0.6 + float(c["s"]) * 0.5) / span
		if _t < float(c["rain"]) and _rng.randf() < dt * 24.0:
			var cp := _cloud_pos(c)
			var fall := _rng.randf_range(260, 340) * (0.35 if WorldLook.world in ["moon", "volcano"] else 1.0)
			_rain.append(Vector3(cp.x + _rng.randf_range(-38, 38) * float(c["s"]), cp.y + 8.0, fall))
	for i in range(_rain.size() - 1, -1, -1):
		var r := _rain[i]
		r.y += r.z * dt
		r.x += wind * 40.0 * dt
		_rain[i] = r
		if r.y > World.SURFACE_Y:
			_rain.remove_at(i)
	# Birds rest at night (the moon's satellites never do).
	var day := 1.0 if WorldLook.world == "moon" else DayNight.daylight()
	for i in _birds.size():
		var b: Dictionary = _birds[i]
		if float(b["wait"]) > 0.0:
			b["wait"] = float(b["wait"]) - dt
			if float(b["wait"]) <= 0.0:
				if day > 0.25:
					_birds[i] = _new_bird(0.0, i)
				else:
					b["wait"] = 5.0
			continue
		var fleeing := float(b["flee"]) >= 0.0
		var sp: float = float(b["speed"]) * (2.6 if fleeing else 1.0) * (0.7 if _calm else 1.0)
		b["x"] = float(b["x"]) + sp * dt
		if fleeing:
			b["vy"] = maxf(float(b["vy"]) - 260.0 * dt, -190.0)
			b["y"] = float(b["y"]) + float(b["vy"]) * dt
		else:
			b["y"] = float(b["y"]) + sin(_t * 0.7 + float(b["phase"])) * 6.0 * dt
		# Off screen: come back from the left after a little while.
		if float(b["x"]) > w + 50.0 or float(b["y"]) < -60.0:
			b["wait"] = _rng.randf_range(2.0, 7.0)
			b["x"] = -9999.0
	for i in range(_feathers.size() - 1, -1, -1):
		var f: Dictionary = _feathers[i]
		f["age"] = float(f["age"]) + dt
		if float(f["age"]) > 3.0:
			_feathers.remove_at(i)
	if wind > 0.6 and _gusts.size() < 2 and _rng.randf() < dt * 0.25 and WorldLook.world != "moon":
		_gusts.append(Vector3(-80.0, _rng.randf_range(160, 400), 0.0))
	for i in range(_gusts.size() - 1, -1, -1):
		var g := _gusts[i]
		g.z += dt
		g.x += dt * (120.0 + wind * 80.0)
		_gusts[i] = g
		if g.x > w + 120.0:
			_gusts.remove_at(i)
	# Coconut falls, bounces on the sand and rolls away.
	if not _coconut.is_empty():
		var c := _coconut
		c["age"] = float(c["age"]) + dt
		var v: Vector2 = c["vel"]
		var pos: Vector2 = c["pos"]
		v.y += 700.0 * dt
		pos += v * dt
		var ground := World.SURFACE_Y - 66.0
		if pos.y > ground:
			pos.y = ground
			if absf(v.y) > 60.0:
				v.y = -absf(v.y) * 0.42
				v.x *= 0.8
				c["bounces"] = int(c["bounces"]) + 1
				if int(c["bounces"]) == 1:
					Sfx.play("tap", 0.55)
					Sfx.voice("hup", 1.3)
			else:
				v.y = 0.0
				v.x *= Motion.drag(0.96, dt)
		c["rot"] = float(c["rot"]) + v.x * dt / 5.0
		c["vel"] = v
		c["pos"] = pos
		if float(c["age"]) > 4.0:
			_coconut = {}
	if _coconuts < 2 and _t > _coconut_back:
		_coconuts += 1
		_coconut_back = _t + 25.0


func _update_chests(dt: float) -> void:
	var c: Dictionary = _chest["raft"]
	var amount: float = GameState.hold
	var fill := _fill(amount, maxf(1.0, GameState.cycle_capacity("boat") * 2.0))
	var rest := 0.0 if amount <= 0.0 else 0.12 + fill * 0.22
	# Damped spring towards the resting angle: the lid pops and settles.
	var lid: float = c["lid"]
	var vel: float = c["vel"]
	vel += ((rest - lid) * 70.0 - vel * 8.5) * dt
	lid += vel * dt
	if lid < 0.0:
		lid = 0.0
		vel = absf(vel) * 0.25
	if lid > 1.05:
		lid = 1.05
		vel = minf(vel, 0.0)
	c["lid"] = lid
	c["vel"] = vel
	if amount > float(c["shown"]) + 0.001:
		c["tag"] = 1.0
	c["shown"] = amount
	c["tag"] = maxf(0.0, float(c["tag"]) - dt * 2.8)


static func _fill(amount: float, cap: float) -> float:
	if amount <= 0.0:
		return 0.0
	return clampf(0.12 + amount / cap, 0.12, 1.0)


# --- Drawing ----------------------------------------------------------------------------

## The shore and the house (a still layer: repainted on resize, when the
## windows light up and while the door opens).
func _paint_ground(ci: CanvasItem) -> void:
	var ix := island_x()
	var wl := WorldLook.world
	Art.push(ci, Vector2(ix, World.SURFACE_Y), 0.0, Vector2(_k, _k))
	WorldArt.island(ci, wl, (size.x - ix) / _k)
	Art.pop(ci)
	var lit := snappedf(smoothstep(0.3, 0.8, DayNight.night()), 0.25)
	Art.push(ci, house_pos(), 0.0, Vector2(_k, _k))
	WorldArt.house(ci, wl, 0.0, lit, _house_door())
	Art.pop(ci)
	Art.push(ci, sign_pos(), 0.0, Vector2(_k, _k))
	_signpost(ci)
	Art.pop(ci)


## A wooden signpost with an arrow and a gear: the way to the factory.
func _signpost(ci: CanvasItem) -> void:
	Art.t_rect(ci, Rect2(-5, -86, 10, 88), 3, Art.WOOD_DARK, 2.4, 0.0)
	Art.toon(ci, _ARROW, Art.CREAM, 3.0, 0.4)
	Art.gear(ci, Vector2(-8, -68), 10.0, Color("8a94b0"), 0.0, 8)
	Art.t_circle(ci, Vector2(-8, -68), 3.5, Art.CREAM, 1.6, 0.0)
	Art.toon(ci, _ARROW_TIP, Art.CORAL, 2.0, 0.0)


static var _ARROW := PackedVector2Array([Vector2(-28, -82), Vector2(20, -82), Vector2(34, -68), Vector2(20, -54), Vector2(-28, -54)])
static var _ARROW_TIP := PackedVector2Array([Vector2(6, -74), Vector2(20, -74), Vector2(20, -79), Vector2(29, -68), Vector2(20, -57), Vector2(20, -62), Vector2(6, -62)])


## Far islands and the landmark (a still layer): the ocean's lighthouse,
## the volcano, the swamp's lantern tree, the moon's ridges and radar.
func _paint_far(ci: CanvasItem) -> void:
	var w := size.x
	var sy := World.SURFACE_Y
	var sp := DayNight.stepped_phase()
	var lights := smoothstep(0.3, 0.8, DayNight.night(sp))
	var flash := clampf(1.0 - (_t - _lighthouse_poke) / 2.2, 0.0, 1.0)
	match WorldLook.world:
		"volcano":
			for f: Vector3 in [Vector3(0.12, 150, 0.0), Vector3(0.85, 200, 0.4)]:
				Art.push(ci, Vector2(w * f.x, sy))
				Props.far_island(ci, f.y, DayNight.far_color(f.z, sp))
				Art.pop(ci)
			Art.push(ci, _volcano_pos())
			WorldArt.volcano(ci, _volcano_h(), DayNight.far_color(0.6, sp).darkened(0.25), lights, flash)
			Art.pop(ci)
			return
		"acid":
			for f: Vector3 in [Vector3(0.08, 0.9, 0.0), Vector3(0.3, 0.7, 0.3), Vector3(0.66, 1.0, 0.1), Vector3(0.9, 0.8, 0.4)]:
				Art.push(ci, Vector2(w * f.x, sy + 2), 0.0, Vector2(f.y, f.y))
				WorldArt.swamp_tree(ci, DayNight.far_color(f.z, sp), int(f.x * 10.0))
				Art.pop(ci)
		"moon":
			for f: Vector3 in [Vector3(0.18, 220, 0.0), Vector3(0.7, 260, 0.4)]:
				Art.push(ci, Vector2(w * f.x, sy))
				WorldArt.ridge(ci, f.y, DayNight.far_color(f.z, sp))
				Art.pop(ci)
		_:
			Art.push(ci, Vector2(w * 0.2, sy))
			Props.far_island(ci, 170, DayNight.far_color(0.0, sp))
			Art.pop(ci)
			Art.push(ci, Vector2(w * 0.72, sy))
			Props.far_island(ci, 180, DayNight.far_color(0.4, sp))
			Art.pop(ci)
	Art.push(ci, _lighthouse_pos())
	if WorldLook.world == "ocean":
		Props.lighthouse(ci, DayNight.far_color(0.2, sp), DayNight.far_color(0.0, sp), maxf(lights, flash))
	else:
		WorldArt.landmark(ci, WorldLook.world, DayNight.far_color(0.2, sp), DayNight.far_color(0.0, sp), maxf(lights, flash))
	Art.pop(ci)


## Clouds, rain, birds, smoke, fireflies and the lighthouse beam (behind
## the scene).
func _draw_sky_fx(ci: CanvasItem) -> void:
	if not world.is_visible_band(0.0, World.SURFACE_Y):
		return
	var wl := WorldLook.world
	var night := DayNight.night()
	var lights := smoothstep(0.3, 0.8, night)
	var sp := DayNight.stepped_phase()
	# Wind gusts: soft curls drifting across.
	for g in _gusts:
		var a := minf(1.0, g.z * 2.0) * 0.4 * (1.0 - night * 0.6)
		var pts := PackedVector2Array()
		for i in 12:
			var f := i / 11.0
			pts.append(Vector2(g.x - 110.0 + f * 110.0, g.y + sin(f * 5.0 + g.z * 3.0) * 5.0))
		Art.polyline(ci, pts, Color(1, 1, 1, a), 2.5)
	if wl == "volcano":
		_draw_volcano_smoke(ci)
	var cf := DayNight.cloud_fill(sp)
	var cl := DayNight.cloud_line(sp)
	var wc := WorldArt.cloud_colors(wl, DayNight.daylight(sp))
	if not wc.is_empty():
		cf = Color(Props._q(wc[0].r, 32), Props._q(wc[0].g, 32), Props._q(wc[0].b, 32))
		cl = Color(Props._q(wc[1].r, 32), Props._q(wc[1].g, 32), Props._q(wc[1].b, 32))
	for c in _clouds:
		var poke := _t - float(c["poke"])
		var puff := 0.0
		if poke < 0.7:
			puff = sin(poke / 0.7 * PI * 2.0) * (1.0 - poke / 0.7) * 0.22
		var s: float = c["s"]
		if wl == "moon":
			# Asteroids drift and tumble instead of clouds.
			# A tap spins it once round (ending where it started: no snap back).
			var spin := float(c["seed"]) * 1.3 + _t * 0.05 + Motion.ease_out_cubic(poke) * TAU
			Art.push(ci, _cloud_pos(c), spin, Vector2(s * (1.0 + puff), s * (1.0 + puff)))
			WorldArt.asteroid(ci, int(c["seed"]), cf, cl)
		else:
			Art.push(ci, _cloud_pos(c), 0.0, Vector2(s * (1.0 + puff), s * (1.0 - puff * 0.7)))
			Props.cloud(ci, int(c["seed"]), cf, cl)
		Art.pop(ci)
	for r in _rain:
		match wl:
			"volcano":
				Art.dot(ci, Vector2(r.x, r.y), 2.0, Color(1.0, 0.6, 0.25, 0.9))
			"acid":
				Art.line(ci, Vector2(r.x, r.y), Vector2(r.x - 2.0, r.y + 8.0), Color(0.75, 1.0, 0.45, 0.9), 2.4)
			"moon":
				Art.dot(ci, Vector2(r.x, r.y), 1.6, Color(1, 1, 1, 0.9))
			_:
				Art.line(ci, Vector2(r.x, r.y), Vector2(r.x - 2.0, r.y + 10.0), Color(0.75, 0.9, 1.0, 0.85), 2.2)
	# The lighthouse beam sweeping over the sea (the tower is on _far).
	if wl == "ocean":
		var lh := _lighthouse_pos()
		var poke := _t - _lighthouse_poke
		var flash := clampf(1.0 - poke / 2.2, 0.0, 1.0)
		var beam := maxf(lights, flash)
		if beam > 0.01:
			var lamp := lh + Props.LIGHTHOUSE_LAMP
			var ang := _t * 1.1 + (poke * 5.0 if flash > 0.0 else 0.0)
			var dir := Vector2(cos(ang), 0.0)
			var c1 := Color(1.0, 0.95, 0.7, 0.42 * beam * absf(dir.x))
			var tip := lamp + dir * 300.0
			Art.grad(ci, PackedVector2Array([lamp, tip + Vector2(0, -44), tip + Vector2(0, 44)]), PackedColorArray([c1, Color(c1, 0.0), Color(c1, 0.0)]))
			Props.halo(ci, lamp, 36.0, Color(1.0, 0.9, 0.6, 0.6 * beam))
	elif wl != "volcano":
		var poke := _t - _lighthouse_poke
		var glow := maxf(lights, clampf(1.0 - poke / 2.2, 0.0, 1.0))
		if glow > 0.01:
			var lamp := _lighthouse_pos() + (WorldArt.LANDMARK_LAMP if wl == "moon" else Vector2(24, -79))
			var col := Color(1.0, 0.45, 0.45) if wl == "moon" else Color(0.8, 1.0, 0.45)
			var blink := 1.0 if wl != "moon" else (0.5 + 0.5 * sin(_t * 4.0))
			Props.halo(ci, lamp, 30.0, Color(col, 0.6 * glow * blink))
			if wl == "moon" and poke < 2.2:
				# A ping ring from the radar.
				var f := fposmod(poke, 0.7) / 0.7
				Art.arc(ci, lamp, 10.0 + f * 60.0, 0, TAU, 28, Color(col, 0.7 * (1.0 - f)), 2.5)
	# Birds (they rest at night): gulls, fire birds, dragonflies, satellites.
	var bird_c := Color.WHITE * DayNight.scene_tint(sp)
	for b in _birds:
		if float(b["wait"]) > 0.0:
			continue
		var fleeing := float(b["flee"]) >= 0.0
		var flap := sin(_t * (18.0 if fleeing else 7.0) + float(b["phase"]))
		Art.push(ci, Vector2(b["x"], b["y"]), -0.35 if fleeing else sin(_t * 0.7 + float(b["phase"])) * 0.06)
		match wl:
			"volcano":
				WorldArt.ember_bird(ci, flap, _t)
			"acid":
				WorldArt.dragonfly(ci, sin(_t * 30.0 + float(b["phase"])), Color("5ad8c8") if int(b["phase"] * 10.0) % 2 == 0 else Color("c86bff"))
			"moon":
				WorldArt.satellite(ci, _t, fposmod(_t + float(b["phase"]), 1.4) < 0.5)
			_:
				Props.gull(ci, flap, Color(bird_c, 1.0))
		Art.pop(ci)
	for f in _feathers:
		var age: float = f["age"]
		var at: Vector2 = f["pos"] + Vector2(sin(age * 3.0 + float(f["seed"])) * 14.0, age * 40.0)
		var a := clampf(3.0 - age, 0.0, 1.0)
		match wl:
			"ocean":
				Art.push(ci, at, sin(age * 3.0 + float(f["seed"])) * 0.6)
				Art.flat_now(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(7, 2.5), 10), Color(1, 1, 1, a))
				Art.pop(ci)
			"volcano":
				Art.dot(ci, at, 3.0, Color(1.0, 0.7, 0.3, a))
			_:
				Art.dot(ci, at, 2.2, Color(1, 1, 1, a))
	if wl == "acid":
		_draw_fireflies(ci, night)
	elif wl == "volcano":
		# Embers drifting up from the lava river.
		for k in 8:
			var f := fposmod(_t * 0.07 + k * 0.125, 1.0)
			var p := Vector2(fposmod(k * 0.37 + 0.05, 1.0) * size.x + sin(_t * 0.9 + k) * 18.0, World.SURFACE_Y - f * 300.0)
			Art.dot(ci, p, 2.2 * (1.0 - f) + 0.8, Color(1.0, 0.7, 0.3, 0.9 * sin(f * PI)))


## Smoke rising from the volcano's crater, bending downwind.
func _draw_volcano_smoke(ci: CanvasItem) -> void:
	var top := _landmark_top()
	var poke := clampf(1.0 - (_t - _lighthouse_poke) / 2.2, 0.0, 1.0)
	var s := _volcano_h() / 220.0
	for k in 7:
		var f := fposmod(_t * 0.07 + k / 7.0, 1.0)
		var p := top + Vector2(f * f * 90.0 * (0.4 + DayNight.wind), -f * 190.0 * s)
		var r := (14.0 + f * 34.0) * s * (1.0 + poke * 0.4)
		var a := snappedf(0.75 * sin(f * PI) * (0.6 + 0.4 * DayNight.daylight()), 0.05)
		Art.push(ci, p, 0.0, Vector2.ONE * snappedf(r / 20.0, 0.05))
		Art.toon(ci, _PUFF, Color(0.42, 0.36, 0.42, a), 0.0, 0.0)
		Art.pop(ci)
	# Lava spurts after a tap.
	if poke > 0.0:
		for k in 6:
			var age := (_t - _lighthouse_poke) * 1.4 - k * 0.08
			if age < 0.0 or age > 1.0:
				continue
			var dir := Vector2(-0.8 + k * 0.32, -1.0)
			var p := top + dir * 120.0 * s * age + Vector2(0, 160.0 * s * age * age)
			Art.dot(ci, p, 5.0 * s * (1.0 - age * 0.5), Color(1.0, 0.75, 0.25, 1.0 - age))


static var _PUFF := Art.circle_pts(Vector2.ZERO, 20.0, 18)


## Fireflies wandering over the swamp (brighter at night).
func _draw_fireflies(ci: CanvasItem, night: float) -> void:
	var a := 0.35 + 0.65 * night
	for k in 9:
		var base := Vector2(fposmod(k * 0.41 + 0.07, 1.0) * size.x, World.SURFACE_Y - 40.0 - (k * 53 % 220))
		var p := base + Vector2(sin(_t * 0.6 + k * 2.1) * 30.0, sin(_t * 0.9 + k) * 16.0)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + k * 1.7)
		Props.halo(ci, p, 14.0, Color(0.85, 1.0, 0.4, 0.4 * a * tw), 12)
		Art.dot(ci, p, 2.4, Color(1.0, 1.0, 0.7, a * (0.5 + 0.5 * tw)))


func _redraw_scene() -> void:
	_l_back.queue_redraw()
	_l_mid.queue_redraw()
	_l_front.queue_redraw()


## The palm (or the world's edge prop) at the end of the shore.
func _paint_back(ci: CanvasItem) -> void:
	_ci = ci
	var wl := WorldLook.world
	if wl == "volcano":
		WorldArt.volcano_flow(_ci, _volcano_pos(), _volcano_h(), _t, _tint)
	Art.push(_ci, _palm_pos(), 0.0, Vector2(_k, _k))
	if wl == "ocean":
		Props.palm(_ci, _t, Props.wind, _palm_amp, _coconuts)
	else:
		WorldArt.edge_prop(_ci, wl, _t, Props.wind, _palm_amp)
	Art.pop(self)


## Between the two boats: the dock and the raft with its loader.
func _paint_mid(ci: CanvasItem) -> void:
	_ci = ci
	var lights := smoothstep(0.3, 0.8, DayNight.night())
	_draw_pier(lights)
	_draw_raft(lights)


## In front of the boats: the sea's surface, glints, smoke and puffs.
func _paint_front(ci: CanvasItem) -> void:
	_ci = ci
	var w := size.x
	var sy := World.SURFACE_Y
	var wl := WorldLook.world
	# The sea's surface over the hulls and floats: two waves on top of each
	# other (lava rolls slowly, moon dust lies still).
	var calm := 0.5 if _calm else 1.0
	var amp := (1.8 + DayNight.wind * 2.0) * calm
	var speed := 1.0
	match wl:
		"volcano":
			amp *= 0.6
			speed = 0.5
		"acid":
			amp *= 0.5
			speed = 0.6
		"moon":
			amp = 0.6
			speed = 0.3
	var wave := PackedVector2Array()
	for i in 41:
		var x := w * i / 40.0
		var u := i * 1.2
		wave.append(Vector2(x, sy + sin(_t * 1.6 * speed + u * 0.62) * amp + sin(_t * 2.3 * speed - u * 1.1) * amp * 0.45))
	WorldArt.surface_front(_ci, wl, wave, w, sy, _t)
	# Little glints riding the crests.
	if wl == "ocean":
		var glint := DayNight.glint()
		for i in 6:
			var f := fposmod(_t * 0.05 + i / 6.0, 1.0)
			var x := f * w
			var a := sin(f * PI) * (0.5 + 0.5 * sin(_t * 3.0 + i * 2.0))
			Art.line(_ci, Vector2(x - 7, sy + 7 + (i % 3) * 3), Vector2(x + 7, sy + 7 + (i % 3) * 3), Color(glint, a * 0.8), 2.5)
	for s in _smoke:
		var a := 0.55 * minf(1.0, s.z * 4.0) * (1.0 - s.z / 2.4)
		var smoke_c := Color(0.96, 0.96, 1.0, a) if wl != "volcano" else Color(0.55, 0.5, 0.55, a)
		Art.push(_ci, Vector2(s.x, s.y), 0.0, Vector2.ONE * (0.55 + ease(minf(1.0, s.z / 2.4), 0.6) * 1.1))
		Art.disc(_ci, Vector2.ZERO, 10.0, smoke_c)
		Art.pop(self)
	if not _coconut.is_empty():
		Art.push(_ci, _coconut["pos"], _coconut["rot"], Vector2(_k, _k))
		Art.t_circle(_ci, Vector2(0, -5), 5, Color("8a5a2c"), 2.0, 0.0)
		Art.disc(_ci, Vector2(-1.5, -7), 1.2, Color("5a3a1c"))
		Art.pop(self)
	for key in BUILDINGS:
		_draw_poof(key)




## Moves the boats and their wakes to where they are now (every frame).
func _place_boats() -> void:
	var band: bool = world.is_visible_band(0.0, size.y) and is_visible_in_tree()
	for key in ["boat2", "boat"]:
		var spr: SceneSprite = _boat_spr[key]
		var wake: SceneSprite = _wake_spr[key]
		var bp := _boat_pos(key)
		var e := _hull(key)
		var show: bool = band and (key == "boat" or second_state("boat2") == "open") and bp.x - maxf(e.x, e.y) <= size.x + 10.0
		spr.visible = show
		wake.visible = show
		if not show:
			spr.stamp = -1
			wake.stamp = -1
			continue
		var st := Art.shape_stamp(_t, 0.0 if key == "boat" else 0.5)
		spr.place(_boat_xf(key), st)
		wake.place(Transform2D(0.0, bp), st)


## The boat's transform as _push_boat sets it (rocking, bobbing, squash).
func _boat_xf(key: String) -> Transform2D:
	var b := _bounce(key)
	var s := _boat_scale(key)
	var ph := 0.0 if key == "boat" else 1.9
	var rock := 0.03 if WorldLook.world != "moon" else 0.012
	return Transform2D(sin(_t * 1.4 + ph) * rock * (0.5 if _calm else 1.0), Vector2(s * _facing(key) * (2.0 - b.x), s * b.x), 0.0, _boat_pos(key) + Vector2(0, -b.y)) \
			* Transform2D(0.0, Vector2(0, sin(_t * 1.6 + ph) * 3.0))


func _paint_boat(ci: CanvasItem, key: String) -> void:
	_ci = ci
	_draw_boat(key, smoothstep(0.3, 0.8, DayNight.night()))


## Behind a sailing boat: foam (sparks on lava, dust on the moon); the
## second boat also gets its lane's strip of sea over its waterline.
func _paint_wake(ci: CanvasItem, key: String) -> void:
	_ci = ci
	var bp := _boat_pos(key)
	var bs := _boat_scale(key)
	var wl := WorldLook.world
	if key == "boat2" and wl != "moon":
		_draw_back_water(bp, bs)
	if _sailing(key):
		var facing := _facing(key)
		var foam := Color(1, 1, 1) if wl in ["ocean", "acid"] else (Color(1.0, 0.8, 0.4) if wl == "volcano" else Color(0.85, 0.87, 0.95))
		for i in 3:
			var f := fposmod(_t * 1.5 + i / 3.0, 1.0)
			var at := bp + Vector2(-facing * (82.0 + f * 47.0) * bs, 2 + (HOVER + 6.0 if wl == "moon" else 0.0))
			Art.arc(_ci, at, (6.0 + f * 8.0) * bs / BOAT_SCALE, PI, TAU, 10, Color(foam, 0.8 * (1.0 - f)), 3.0)


## White puffs around a boat the moment its look changes.
func _draw_poof(key: String) -> void:
	var age := _t - float(_stage_fx[key])
	if age < 0.0 or age > 0.8:
		return
	var f := age / 0.8
	var c := _boat_pos(key) + Vector2(0, -52) * _boat_scale(key)
	var r := 82.0 * _boat_scale(key)
	for i in 12:
		var a := TAU * i / 12.0 + i * 0.3
		var d := r * (0.35 + ease(f, 0.4) * 0.75)
		var p := c + Vector2(cos(a) * d * 1.2, sin(a) * d * 0.8)
		Art.disc(_ci, p, (18.0 + (i % 3) * 5.0) * (1.0 - f * 0.5), Color(1, 1, 1, 0.9 * (1.0 - f)))


## Squash-and-stretch after a new stage: x = vertical scale, y = hop height.
func _bounce(key: String) -> Vector2:
	var age := _t - float(_stage_fx[key]) - 0.15
	if age < 0.0 or age > 1.1:
		return Vector2(1.0, 0.0)
	var k := age / 1.1
	var sq := sin(k * PI * 3.0) * pow(1.0 - k, 2.0) * 0.2
	return Vector2(1.0 + sq, sin(minf(k * 2.5, 1.0) * PI) * 14.0 * (1.0 - k))


func _push_boat(ci: CanvasItem, key: String = "boat") -> void:
	var b := _bounce(key)
	var s := _boat_scale(key)
	var ph := 0.0 if key == "boat" else 1.9
	var rock := 0.03 if WorldLook.world != "moon" else 0.012
	Art.push(ci, _boat_pos(key) + Vector2(0, -b.y), sin(_t * 1.4 + ph) * rock * (0.5 if _calm else 1.0),
			Vector2(s * _facing(key) * (2.0 - b.x), s * b.x))
	Art.push(ci, Vector2(0, sin(_t * 1.6 + ph) * 3.0))


## A character mark (zzz, sweat, heart) at the shore's scale.
func _mark(kind: String, at: Vector2) -> void:
	Art.push(_ci, at, 0.0, Vector2(_k, _k))
	Chars.mark(_ci, kind, Vector2.ZERO, _t)
	Art.pop(_ci)


## The dock: the second boat's berth at it (its buoy and price board while
## it is for sale). A metal landing pier on the moon, stone by the volcano.
func _draw_pier(lights: float) -> void:
	var boat2 := second_state("boat2")
	var tip := Vector2(_tip, World.SURFACE_Y)
	var h := (World.SURFACE_Y - _pier_y()) / _k
	if boat2 == "sale":
		var b := buoy_pos()
		Art.push(_ci, b, sin(_t * 1.3) * 0.06, Vector2(_k, _k))
		Props.buoy(_ci, lights)
		Art.pop(_ci)
	Art.push(_ci, tip, 0.0, Vector2(_k, _k))
	Props.pier(_ci, PIER_W, h, true)
	Art.pop(_ci)
	if boat2 == "sale":
		_draw_sign("boat2")


func _draw_raft(lights: float) -> void:
	var p := raft_pos()
	var bob := _raft_bob()
	Art.push(_ci, p + Vector2(0, bob))
	Props.raft(_ci, _t, 0, _ore(), lights, RAFT_DECK)
	Art.pop(_ci)
	var rc: Dictionary = _chest["raft"]
	Art.push(_ci, _raft_chest_pos(), 0.0, Vector2.ONE * RAFT_CHEST_SCALE)
	Props.ore_chest(_ci, _t, _fill(GameState.hold, maxf(1.0, GameState.cycle_capacity("boat") * 2.0)), rc["lid"], _ore(), 11)
	Art.pop(_ci)
	# Loader on the raft, between the crane post and the lift cable.
	var mood := world.mood("raft")
	var emo := mood if mood != "" else ("happy" if GameState.hold > 0.0 else "bored")
	var catching := mood == "joy"
	Chars.person(_ci, p + Vector2(-22, -15 + bob - world.hop("raft")), 0.8, 1.0, Chars.look(4, "curly", 0, "beanie", "none", 1, "sailor"),
			{"emotion": emo, "blink": Chars.blinking(_t, 2.0), "arm_r": 2.5 if catching else 0.4, "arm_l": -2.5 if catching else -0.2,
			"hold": "sack" if catching else "", "hold_color": _ore()})


## Sailors: the first boat's and the second one's.
const _SAILOR_LOOKS := {"boat": ["sailor", 1], "boat2": ["sailor2", 2]}


func _draw_boat(key: String, lights: float) -> void:
	var bp := _boat_pos(key)
	var bs := _boat_scale(key)
	var e := _hull(key)
	if bp.x - maxf(e.x, e.y) > size.x + 10.0:
		return   # at the factory
	var p := Motion.progress(key)
	var facing := _facing(key)
	var mood := world.mood(key)
	var sailor: String = _SAILOR_LOOKS[key][0]
	var smood := world.mood(sailor)
	var semo := smood if smood != "" else (mood if mood != "" else ("happy" if p >= 0.0 else "bored"))
	var sailing := _sailing(key)
	var hop := maxf(world.hop(key), world.hop(sailor))
	var look := Chars.look(1, "short", 3, "sailor", "freckles", 1, "sailor") if key == "boat" else Chars.look(4, "spiky", 2, "sailor", "none", 7, "sailor")
	var crew := func():
		Chars.person(_ci, Vector2(52, -40 - hop), 0.9, 1.0, look,
				{"emotion": semo, "blink": Chars.blinking(_t + (0.0 if key == "boat" else 1.7), 5.0),
				"arm_r": 2.6 if smood == "joy" else (0.9 + sin(_t * 6.0) * 0.5 if sailing else 0.3), "arm_l": -0.3})
	var wl := WorldLook.world
	if wl == "moon":
		# The dust under a hovering boat.
		Art.flat_now(_ci, Art.ellipse_pts(Vector2(bp.x, World.SURFACE_Y + 4.0), Vector2((e.x + e.y) * 0.4, 4.0), 16), Color(0.15, 0.17, 0.3, 0.3))
	_push_boat(_ci, key)
	var cap_emo := mood if mood != "" else "happy"
	Props.downwind = facing
	Props.boat_at_stage(_ci, _shown_stage(key), _t, _crates(key), _ore(), GameState.has_manager(key), cap_emo, Chars.blinking(_t, 7.0), crew, lights,
			Props.variant_of(key))
	Props.downwind = 1.0
	if wl != "ocean":
		WorldArt.hull_trim(_ci, wl, BOAT_EXT[clampi(_shown_stage(key), 1, BOAT_EXT.size()) - 1], _t)
	Art.pop(_ci)
	Art.pop(_ci)


## The farther lane's own strip of sea over the second boat's waterline, so
## it floats a little behind the first boat instead of beside it.
func _draw_back_water(bp: Vector2, _bs: float) -> void:
	var e := _hull("boat2")
	var x0 := bp.x - maxf(e.x, e.y) - 10.0 * _k
	var x1 := bp.x + maxf(e.x, e.y) + 10.0 * _k
	var y := bp.y + 1.0
	var sea := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		sea.append(Vector2(x, y + sin(_t * 1.9 + x * 0.05) * 1.4))
	var line := sea.duplicate()
	sea.append(Vector2(x1, World.SURFACE_Y + 2.0))
	sea.append(Vector2(x0, World.SURFACE_Y + 2.0))
	var wl := WorldLook.world
	if wl == "volcano":
		Art.flat_now(_ci, sea, WorldArt.unlit(WorldArt.MAGMA_SKIN, _tint))
		Art.polyline(_ci, line, WorldArt.unlit(WorldArt.MAGMA_HOT, _tint), 3.0)
		return
	Art.flat_now(_ci, sea, Color(Art.calm(Art.sea_cols[0]), 0.85 if wl == "ocean" else 0.95))
	Art.polyline(_ci, line, Color(1, 1, 1, 0.75) if wl == "ocean" else Color(Art.sea_cols[0].lightened(0.4), 0.9), 2.5)


func _draw_sign(key: String) -> void:
	var place := _sign_place(key)
	var sc: float = place[2]
	var poke := clampf(1.0 - (_t - float(_sign_poke[key])) / 0.6, 0.0, 1.0)
	var ready := 1.0 if _can_buy(key) else 0.0
	var foot: Vector2 = place[0]
	var hanging: bool = float(place[1]) <= 0.0
	var wob := sin(_t * 18.0) * 0.12 * poke + (sin(_t * 3.0) * 0.03 * ready if not _calm else 0.0)
	var sq := 1.0 + sin(_t * 20.0) * 0.06 * poke
	if hanging:
		# Two ropes from the dock's beam.
		var w := Props.sale_sign_width(_price(key)) * sc
		var top := foot.y - 34.0 * sc
		for sx: float in [-0.32, 0.32]:
			Art.line(_ci, Vector2(foot.x + w * sx, _beam_bottom() - 2.0), Vector2(foot.x + w * sx, top + 3.0), Art.INK, 2.0)
		wob *= 0.4
	Art.push(_ci, foot, wob, Vector2(2.0 - sq, sq) * sc)
	Props.sale_sign(_ci, _price(key), ready, place[1])
	Art.pop(_ci)


## What the number tag shows and where (the glow layer redraws when it changes).
func _glow_sig() -> Array:
	var r: Dictionary = _chest["raft"]
	return [NumFormat.short(GameState.hold) if GameState.hold > 0.0 else "", roundf(_raft_bob()), snappedf(float(r["lid"]), 0.05),
			snappedf(float(r["tag"]), 0.05), size]


## Night lights and the number tag, on top and never darkened.
func _draw_glow(ci: CanvasItem) -> void:
	if not world.is_visible_band(0.0, size.y):
		return
	var lights := smoothstep(0.3, 0.8, DayNight.night())
	if lights > 0.01:
		var hp := house_pos()
		for l: Vector3 in WorldArt.house_lights(WorldLook.world):
			var flick := 0.85 + 0.15 * sin(_t * 5.0 + l.x)
			Props.halo(ci, hp + Vector2(l.x, l.y) * _k, l.z * _k * 1.6, Color(1.0, 0.85, 0.45, 0.4 * lights * flick))
		match second_state("boat2"):
			"open":
				_push_boat(ci, "boat2")
				Props.boat_lights(ci, _shown_stage("boat2"), _t, lights)
				Art.pop(ci)
				Art.pop(ci)
			"sale":
				var b := buoy_pos()
				var lamp := b + Props.BUOY_LAMP.rotated(sin(_t * 1.3) * 0.06) * _k
				var blink := 0.55 + 0.45 * sin(_t * 2.6)
				Props.halo(ci, lamp, 26.0 * _k, Color(1.0, 0.45, 0.35, 0.5 * lights * blink))
				Art.disc(ci, lamp, 3.5 * _k, Color(1.0, 0.9, 0.8, 0.9 * lights))
		_push_boat(ci)
		Props.boat_lights(ci, _shown_stage("boat"), _t, lights)
		Art.pop(ci)
		Art.pop(ci)
		var lamp := raft_pos() + Vector2(0, _raft_bob()) + Props.RAFT_LAMP + Vector2(sin(_t * 1.7) * 1.5, 0)
		Props.halo(ci, lamp, 34.0, Color(1.0, 0.85, 0.45, 0.45 * lights))
		Art.disc(ci, lamp, 4.0, Color(1.0, 0.95, 0.7, 0.9 * lights))
	# The lava river glows a little on the scene above it.
	if WorldLook.world == "volcano":
		Props.halo(ci, Vector2(size.x * 0.3, World.SURFACE_Y + 6.0), 160.0, Color(1.0, 0.55, 0.2, 0.12 + 0.12 * lights), 16)
		Props.halo(ci, Vector2(size.x * 0.75, World.SURFACE_Y + 6.0), 160.0, Color(1.0, 0.55, 0.2, 0.12 + 0.12 * lights), 16)
	# The chest tag a little smaller than the cards' numbers, so it informs
	# without shouting.
	if GameState.hold > 0.0:
		Art.push(ci, _raft_chest_pos() + Vector2(0, -44 - float(_chest["raft"]["lid"]) * 8.0), 0.0, Vector2.ONE * TAG_SCALE)
		Props.number_tag(ci, Vector2.ZERO, NumFormat.short(GameState.hold), _ore(), _chest["raft"]["tag"])
		Art.pop(ci)
