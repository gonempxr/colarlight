class_name SurfaceView
extends Control
## Everything above water: the raft with its crane and ore chest, the boat
## with a sailor (and the captain once hired), the island with the plant,
## its worker and the businessman (the player's avatar) who collects the
## money. Cards for the boat and the plant sit in the sky.
##
## The second boat and plant ("boat2", "plant2") live in the back row: the
## second boat sails a lane a little farther away (smaller, its own paint)
## and waits at the shore instead of the raft, so the two boats pass each
## other; the second plant stands on a terrace behind the shore chest.
## While they are closed (from the third dive site on) a buoy and a fenced
## plot with price signs mark where they will be; a tap there selects them
## (World.select) so the upgrade panel can sell them.
##
## The sky itself (gradient, sun, moon, stars) is drawn by World under the
## water, so the sun really sinks into the sea. This view adds, in layers:
##   _sky_fx  (behind)  clouds, rain, birds, the lighthouse beam
##   _far     (behind)  far islands and the lighthouse (still, repainted
##                      when the light changes)
##   _ground  (behind)  the island (still, repainted on resize)
##   self               palm, plant, raft, boat, waves, smoke - tinted at night
##   _glow    (front)   night lights and the ore number tags (never tinted)
## Almost everything can be tapped for a little reaction (see _poke_ambient).

const BOAT_SCALE := 0.85
const BOAT_LOAD_END := 0.12
const BOAT_SAIL_END := 0.45
const BOAT_UNLOAD_END := 0.58
const PLANT_X := 100.0
## Smallest tap target for scenery, so small fingers hit it.
const TAP_R := 46.0
const RAFT_CHEST := Vector2(40, -15)
const RAFT_CHEST_SCALE := 0.8
const DOCK_CHEST_SCALE := 0.92
## Second boat: smaller, in a lane a little farther away. Its cycle: it
## waits at the shore, sails to the raft (until B2_ARRIVE), loads (until
## B2_LEAVE), sails back (until B2_BACK) and unloads.
const BOAT2_SCALE := 0.68
const BOAT2_LANE := -3.0
const B2_ARRIVE := 0.28
const B2_LEAVE := 0.4
const B2_BACK := 0.78
## Second plant: on a terrace behind the shore chest (x from island_x()).
const PLANT2_SCALE := 0.8
const PLANT2_X := -18.0
const PLANT2_LIFT := 26.0
const BUILDINGS: Array[String] = ["boat", "plant", "boat2", "plant2"]

var world: World
var boat_card: StageCard
var plant_card: StageCard

var _t := 0.0
var _smoke: Array[Vector3] = []   # x, y, age
var _gear_rot := 0.0
var _boat_p := -1.0
var _boat2_p := -1.0
var _plant_flash := 0.0
var _plant2_flash := 0.0
var _gear_rot2 := 0.0
var _pending_throws: Array[Array] = []   # [time, kind, a, b]

var _sky_fx: PaintLayer
var _far: PaintLayer
var _far_step := -1.0
var _glow_last := []
var _ground: PaintLayer
var _glow: PaintLayer
var _tint := Color.WHITE
var _calm := false

# Sky life.
var _clouds: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _rain: Array[Vector3] = []            # x, y, speed
var _feathers: Array[Dictionary] = []
var _gusts: Array[Vector3] = []           # x, y, age
var _lighthouse_poke := -99.0
var _rng := RandomNumberGenerator.new()

# Palm and its coconuts.
var _palm_poke := -99.0
var _coconuts := 2
var _coconut_back := 0.0
var _coconut := {}

# Ore chests: lid angle (a spring), lid speed, number tag pop.
var _chest := {
	"raft": {"lid": 0.0, "vel": 0.0, "tag": 0.0, "shown": 0.0},
	"dock": {"lid": 0.0, "vel": 0.0, "tag": 0.0, "shown": 0.0},
}
var _dock_pop_at := -1.0

# Building looks: the stage shown, the one before, and when it changed.
var _stage := {"boat": 0, "plant": 0, "boat2": 0, "plant2": 0}
var _stage_old := {"boat": 0, "plant": 0, "boat2": 0, "plant2": 0}
var _stage_fx := {"boat": -99.0, "plant": -99.0, "boat2": -99.0, "plant2": -99.0}
## Only a change right after an upgrade is celebrated (not loads or profile switches).
var _upgraded_at := {"boat": -99.0, "plant": -99.0, "boat2": -99.0, "plant2": -99.0}
## When the second boat/plant was bought (the for-sale sign poofs away).
var _opened_at := {"boat2": -99.0, "plant2": -99.0}
## Last tap on a for-sale sign (it wobbles).
var _sign_poke := {"boat2": -99.0, "plant2": -99.0}
## Whether the terrace for the second plant is painted on the ground layer.
var _terrace_shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rng.seed = 11
	_sky_fx = PaintLayer.new(_draw_sky_fx)
	add_child(_sky_fx)
	_far = PaintLayer.new(_paint_far)
	add_child(_far)
	_ground = PaintLayer.new(_paint_ground)
	add_child(_ground)
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
	_chest["dock"]["shown"] = GameState.dock


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and plant_card:
		plant_card.position = Vector2(world.card_x(), 14)
		boat_card.position = Vector2(world.card_x() - 12 - World.CARD_W, 14)


func refresh() -> void:
	boat_card.refresh()
	plant_card.refresh()


# --- Layout ------------------------------------------------------------------------------

func island_x() -> float:
	return size.x - 280.0


func raft_pos() -> Vector2:
	return Vector2(World.ROPE_X, World.SURFACE_Y)


func dock_pos() -> Vector2:
	return Vector2(island_x() + 30.0, World.SURFACE_Y - 30.0)


func plant_world_pos() -> Vector2:
	return Vector2(island_x() + PLANT_X, World.SURFACE_Y - 64.0)


func plant_rect() -> Rect2:
	var p := plant_world_pos()
	var h := Props.plant_height(_stage["plant"])
	return Rect2(p + Vector2(0, -h), Vector2(150, h))


func boat_x_range() -> Vector2:
	return Vector2(World.ROPE_X + 66.0 + 84.0 * BOAT_SCALE, island_x() - 62.0)


func boat_world_pos() -> Vector2:
	var r := boat_x_range()
	var p := GameState.cycle_progress("boat")
	var x := r.x
	if p >= BOAT_LOAD_END and p < BOAT_SAIL_END:
		x = lerpf(r.x, r.y, smoothstep(BOAT_LOAD_END, BOAT_SAIL_END, p))
	elif p >= BOAT_SAIL_END and p < BOAT_UNLOAD_END:
		x = r.y
	elif p >= BOAT_UNLOAD_END:
		x = lerpf(r.y, r.x, smoothstep(BOAT_UNLOAD_END, 1.0, p))
	return Vector2(x, World.SURFACE_Y + 4.0)


func _boat_facing() -> float:
	return -1.0 if GameState.cycle_progress("boat") >= BOAT_UNLOAD_END else 1.0


func _boat_deck(bp: Vector2) -> Vector2:
	return bp + Vector2(30.0 * _boat_facing(), -50.0) * BOAT_SCALE


## The second boat loads a little right of the first and moors a little
## closer to the shore, so the two rarely hide each other.
func boat2_x_range() -> Vector2:
	var r := boat_x_range()
	return Vector2(r.x + 30.0, r.y + 10.0)


func boat2_world_pos() -> Vector2:
	var r := boat2_x_range()
	var p := GameState.cycle_progress("boat2")
	var x := r.y
	if p >= 0.0 and p < B2_ARRIVE:
		x = lerpf(r.y, r.x, smoothstep(0.0, B2_ARRIVE, p))
	elif p >= B2_ARRIVE and p < B2_LEAVE:
		x = r.x
	elif p >= B2_LEAVE and p < B2_BACK:
		x = lerpf(r.x, r.y, smoothstep(B2_LEAVE, B2_BACK, p))
	return Vector2(x, World.SURFACE_Y + BOAT2_LANE)


func _boat2_facing() -> float:
	var p := GameState.cycle_progress("boat2")
	return -1.0 if p >= 0.0 and p < B2_LEAVE else 1.0


func _boat_pos(key: String) -> Vector2:
	return boat_world_pos() if key == "boat" else boat2_world_pos()


func _boat_scale(key: String) -> float:
	return BOAT_SCALE if key == "boat" else BOAT2_SCALE


func _facing(key: String) -> float:
	return _boat_facing() if key == "boat" else _boat2_facing()


func _deck_of(key: String) -> Vector2:
	return _boat_pos(key) + Vector2(30.0 * _facing(key), -50.0) * _boat_scale(key)


## Is the boat under way (for the foam and the sailor's wave)?
func _sailing(key: String) -> bool:
	var p := GameState.cycle_progress(key)
	if key == "boat":
		return p >= BOAT_LOAD_END and (p < BOAT_SAIL_END or p >= BOAT_UNLOAD_END)
	return p >= 0.0 and (p < B2_ARRIVE or (p >= B2_LEAVE and p < B2_BACK))


## Crates on deck (0..3) while the boat carries ore.
func _crates(key: String) -> int:
	var p := GameState.cycle_progress(key)
	var loaded := (p >= 0.04 and p < BOAT_SAIL_END + 0.02) if key == "boat" else (p >= B2_ARRIVE and p < B2_BACK + 0.02)
	if not loaded:
		return 0
	var cap := maxf(1.0, GameState.cycle_capacity(key))
	return clampi(ceili(GameState.cycle_load(key) / cap * 3.0), 1, 3)


func plant2_world_pos() -> Vector2:
	return Vector2(island_x() + PLANT2_X, World.SURFACE_Y - 64.0 - PLANT2_LIFT)


func _plant_pos(key: String) -> Vector2:
	return plant_world_pos() if key == "plant" else plant2_world_pos()


func _plant_scale(key: String) -> float:
	return 1.0 if key == "plant" else PLANT2_SCALE


## Where coins come out of a plant (its door).
func _plant_door(key: String) -> Vector2:
	return _plant_pos(key) + Vector2(121, -44) * _plant_scale(key)


## Where the second boat's buoy floats while it is for sale: at its
## mooring, or out on the route when a phone's sky cards would hide the sign
## there.
func buoy_pos() -> Vector2:
	var r := boat2_x_range()
	var x := r.y
	if _covered(x, World.SURFACE_Y - 14.0 - Props.SIGN_POST - 38.0) or (second_state("plant2") == "sale" and _plant_sign_low()):
		x = lerpf(boat_x_range().x, boat_x_range().y, 0.66)
	return Vector2(x, World.SURFACE_Y + sin(_t * 1.8) * 2.5)


## Would a sky card (phone) hide a sign whose board top is at `top` around x?
func _covered(x: float, top: float) -> bool:
	for c: Control in [boat_card, plant_card]:
		if is_instance_valid(c) and c.visible:
			var r := c.get_rect()
			if r.position.x < x + 60.0 and r.end.x > x - 60.0 and r.end.y > top:
				return true
	return false


## For-sale sign placement: [foot of the post, post length, scale]. Where a
## phone's sky card would hide it, it sits low (short post, a bit smaller).
func _sign_place(key: String) -> Array:
	if key == "boat2":
		var b := buoy_pos()
		if _covered(b.x, b.y - 14.0 - Props.SIGN_POST - 38.0):
			return [b + Vector2(0, -12), 6.0, 0.8]
		return [b + Vector2(0, -14), Props.SIGN_POST, 1.0]
	var foot := plant2_world_pos() + Vector2(58, -4)
	if _covered(foot.x, foot.y - Props.SIGN_POST - 38.0):
		return [Vector2(island_x() - 30.0, World.SURFACE_Y - 40.0), 8.0, 0.8]
	return [foot, Props.SIGN_POST, 1.0]


## Is the plant sign in its low spot on the shore (drawn over the second boat)?
func _plant_sign_low() -> bool:
	var place := _sign_place("plant2")
	return float(place[1]) < Props.SIGN_POST


func _sign_rect(key: String) -> Rect2:
	var place := _sign_place(key)
	var foot: Vector2 = place[0]
	var post: float = place[1]
	var sc: float = place[2]
	var w := maxf(TAP_R, Props.sale_sign_width(_price(key)) * sc)
	var h := maxf(TAP_R + 10.0, (post + 34.0) * sc + 16.0)
	return Rect2(foot.x - w / 2.0, foot.y - h + 8.0, w, h)


## "open", "sale" (closed, for sale once the third dive site is open) or ""
## (not shown yet) for "boat2" / "plant2". Right after buying, the sign
## stays a moment while the poof hides the swap.
func second_state(key: String) -> String:
	var open: bool = GameState.is_open(key)
	if open and _t - float(_opened_at.get(key, -99.0)) >= 0.22:
		return "open"
	var d2: bool = GameState.is_open("d2")
	return "sale" if open or d2 else ""


## The plot of the second plant (its sign has _sign_rect).
func _plot_rect() -> Rect2:
	var p := plant2_world_pos()
	return Rect2(p.x - 8.0, p.y - 60.0, 128.0, 70.0)


func _building_rect(key: String) -> Rect2:
	if GameState.is_boat(key):
		var bp := _boat_pos(key)
		var bs := _boat_scale(key)
		var bh := Props.boat_height(_stage[key]) * bs
		return Rect2(bp.x - 100.0 * bs, bp.y - bh - 8.0, 200.0 * bs, bh + 22.0)
	var pp := _plant_pos(key)
	var ps := _plant_scale(key)
	var ph := Props.plant_height(_stage[key]) * ps
	return Rect2(pp.x - 8.0, pp.y - ph - 6.0, 150.0 * ps + 16.0, ph + 16.0)


func _biz_pos() -> Vector2:
	return plant_world_pos() + Vector2(122, 0)


func _ore() -> Color:
	return Art.DEPTH_STYLE[0]["ore2"]


func _raft_bob() -> float:
	return sin(_t * 1.6) * 3.0


func _raft_chest_pos() -> Vector2:
	return raft_pos() + RAFT_CHEST + Vector2(0, _raft_bob())


func _dock_chest_pos() -> Vector2:
	return dock_pos() + Vector2(-8, 8)


func _palm_pos() -> Vector2:
	return Vector2(island_x() + 268.0, World.SURFACE_Y - 64.0)


func _lighthouse_pos() -> Vector2:
	var r := boat_x_range()
	return Vector2(lerpf(r.x, r.y, 0.55), World.SURFACE_Y)


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
		Sfx.play("horn")
	elif key == "boat2":
		# It sails off from the shore; the loading happens at the raft (see _process).
		Sfx.play("horn", 0.8)
	elif key == "plant":
		_pop_chest("dock", 0.5)
		world.react("worker", "focus", 1.0)
	elif key == "plant2":
		_pop_chest("dock", 0.5)
		world.react("worker2", "focus", 1.0)
		var hopper := plant2_world_pos() + Vector2(-15, -66) * PLANT2_SCALE
		world.divers.throw_item("sack", _dock_chest_pos() + Vector2(0, -34), hopper, _ore(), 0.45)


## The second boat or plant was bought: poof the sign away.
func _on_opened(key: String) -> void:
	if not _opened_at.has(key):
		return
	_opened_at[key] = _t
	_stage[key] = Props.current_stage(key)
	_stage_old[key] = _stage[key]
	_stage_fx[key] = _t
	Sfx.play("unlock")


func _on_cycle_finished(key: String, amount: float) -> void:
	match key:
		"plant", "plant2":
			if key == "plant":
				_plant_flash = 1.0
			else:
				_plant2_flash = 1.0
			var door := _plant_door(key)
			world.divers.throw_item("coinbag", door, _biz_pos() + Vector2(14, -60), Art.GOLD, 0.45)
			var text_at := _biz_pos() + Vector2(0, -130)
			get_tree().create_timer(0.45).timeout.connect(func():
				world.react("biz", "rich", 1.4, true)
				if randf() < 0.25:
					Sfx.voice("ooh", 0.85)
				world.divers.float_text(text_at, "+" + NumFormat.short(amount), Art.GOLD, true)
				Sfx.play("coins"))
		"boat", "boat2":
			world.divers.float_text(dock_pos() + Vector2(0, -90), "+" + NumFormat.short(amount), Color("bff6ff"))
		_:
			if key.begins_with("d"):
				world.react("raft", "joy", 0.5, true)
				_pop_chest("raft", 1.0)


## Kicks a chest lid open (it springs back by itself).
func _pop_chest(which: String, strength: float) -> void:
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
			# A for-sale sign: show the second boat/plant in the upgrade panel.
			key = key.substr(5)
			_sign_poke[key] = _t
			Sfx.play("click")
			Settings.buzz(12)
			world.divers.tap_ripple(p)
			world.select(key)
			return
		if key == "" and _poke_ambient(p):
			return
		if key == "":
			if p.y < 250.0:
				return
			key = "plant" if p.x > island_x() else "boat"
		if GameState.tap(key):
			Sfx.play("horn" if GameState.is_boat(key) else "machine")
		else:
			Sfx.play("tap")
		world.divers.tap_ripple(p)


func _on_card(p: Vector2) -> bool:
	var g := get_global_transform() * p
	for c: Control in [boat_card, plant_card]:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(g):
			return true
	return false


## The boat, the raft, the plant and its people take taps first (things in
## front before things behind). Returns the key, "sale:boat2" /
## "sale:plant2" for a for-sale sign, or "".
func _building_at(p: Vector2) -> String:
	if _building_rect("boat").has_point(p):
		return "boat"
	var r := raft_pos()
	if Rect2(r.x - 70.0, r.y - 160.0, 140.0, 176.0).has_point(p):
		return "boat"
	var plant2 := second_state("plant2")
	var boat2 := second_state("boat2")
	# The signs stand in front of what is around them.
	if plant2 == "sale" and _sign_rect("plant2").has_point(p):
		return "sale:plant2"
	if boat2 == "sale" and _sign_rect("boat2").has_point(p):
		return "sale:boat2"
	var pp := plant_world_pos()
	var ph := Props.plant_height(_stage["plant"])
	# With the second plant (or its plot) behind, the first one's tap area
	# stops at its hopper; below the terrace the belt still counts.
	if plant2 == "" and Rect2(pp.x - 64.0, pp.y - ph - 6.0, 210.0, ph + 16.0).has_point(p):
		return "plant"
	if plant2 != "" and Rect2(pp.x - 8.0, pp.y - ph - 6.0, 154.0, ph + 16.0).has_point(p):
		return "plant"
	var d := _dock_chest_pos()
	if Rect2(d.x - 40.0, d.y - 70.0, 90.0, 80.0).has_point(p):
		return "plant"
	# The worker and the belt in front of the terrace.
	if plant2 != "" and Rect2(pp.x - 64.0, pp.y - 70.0, 60.0, 86.0).has_point(p):
		return "plant"
	if plant2 == "open" and _building_rect("plant2").has_point(p):
		return "plant2"
	if plant2 == "sale" and _plot_rect().has_point(p):
		return "sale:plant2"
	if boat2 == "open" and _building_rect("boat2").has_point(p):
		return "boat2"
	if boat2 == "sale" and Rect2(buoy_pos() + Vector2(-TAP_R / 2.0, -40.0), Vector2(TAP_R, 52.0)).has_point(p):
		return "sale:boat2"
	return ""


## Sun, moon, clouds, birds, fish, the palm and the lighthouse react to a
## tap. Returns false when nothing was hit.
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
	consider.call("palm", _palm_pos() + Props.PALM_TOP, 56.0)
	consider.call("palm", _palm_pos() + Vector2(-6, -40), TAP_R)
	consider.call("lighthouse", _lighthouse_pos() + Props.LIGHTHOUSE_LAMP + Vector2(0, 30), 48.0)
	var best: String = hit["name"]
	var bi: int = hit["i"]
	if best == "" and p.y > World.SURFACE_Y and world.poke_fish(p):
		return true
	match best:
		"sun":
			world.pokes["sun"] = world.t
			world.divers.sparkle(DayNight.sun_pos(w), 8)
			Sfx.play("upgrade", 1.3)
			Sfx.voice("yay", 1.6)
		"moon":
			world.pokes["moon"] = world.t
			world.shooting_star(DayNight.moon_pos(w) + Vector2(-40, -30))
			Sfx.play("upgrade", 0.8)
			Sfx.voice("ooh", 1.5)
		"cloud":
			var c: Dictionary = _clouds[bi]
			c["poke"] = _t
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
			Sfx.play("dig", 0.8)
			if _coconuts > 0 and _coconut.is_empty():
				_coconuts -= 1
				_coconut_back = _t + 25.0
				var top := _palm_pos() + Props.PALM_TOP + Vector2(4.0 if _coconuts == 1 else -4.0, 6.0)
				_coconut = {"pos": top, "vel": Vector2(_rng.randf_range(-40, -10), -60), "age": 0.0, "rot": 0.0, "bounces": 0}
		"lighthouse":
			_lighthouse_poke = _t
			Sfx.play("horn", 0.62)
		_:
			# A tap on the empty night sky sends a shooting star.
			if p.y < World.SURFACE_Y - 60.0 and DayNight.night() > 0.5:
				world.shooting_star(p)
				Sfx.play("upgrade", 1.7)
				return true
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
	_plant_flash = maxf(0.0, _plant_flash - delta * 2.0)
	_plant2_flash = maxf(0.0, _plant2_flash - delta * 2.0)
	_update_stages()
	var terrace := second_state("plant2") != ""
	if terrace != _terrace_shown:
		_terrace_shown = terrace
		_ground.queue_redraw()
	for key in ["plant", "plant2"]:
		if GameState.cycle_progress(key) < 0.0 or (key == "plant2" and second_state(key) != "open"):
			continue
		if key == "plant":
			_gear_rot += delta * 3.0
		else:
			_gear_rot2 += delta * 3.0
		if randf() < delta * 5.0:
			var pp := _plant_pos(key)
			var ps := _plant_scale(key)
			for s in Props.plant_smoke_points(_stage[key]):
				_smoke.append(Vector3(pp.x + s.x * ps, pp.y + s.y * ps, 0.0))
	for key in ["boat", "boat2"]:
		if GameState.cycle_progress(key) >= 0.0 and randf() < delta * 3.0 and (key == "boat" or second_state(key) == "open"):
			var bp := _boat_pos(key)
			var bs := _boat_scale(key)
			for s in Props.boat_smoke_points(_stage[key]):
				_smoke.append(Vector3(bp.x + s.x * bs * _facing(key), bp.y + s.y * bs, 0.0))
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
	# Sacks thrown with a small delay, and the unloading moment.
	for i in range(_pending_throws.size() - 1, -1, -1):
		var th: Array = _pending_throws[i]
		if _t >= th[0]:
			world.divers.throw_item(th[1], th[2], th[3], _ore(), 0.5)
			_pending_throws.remove_at(i)
	var bprog := GameState.cycle_progress("boat")
	if _boat_p < BOAT_SAIL_END + 0.02 and bprog >= BOAT_SAIL_END + 0.02:
		world.divers.throw_item("sack", _boat_deck(boat_world_pos()), _dock_chest_pos() + Vector2(0, -34), _ore(), 0.5)
		world.react("sailor", "joy", 0.8, true)
		_dock_pop_at = _t + 0.45
	_boat_p = bprog
	# The second boat loads when it reaches the raft and unloads back at the shore.
	var b2 := GameState.cycle_progress("boat2")
	if _boat2_p < B2_ARRIVE and b2 >= B2_ARRIVE:
		var from := _raft_chest_pos() + Vector2(0, -34)
		_pending_throws.append([_t, "sack", from, _deck_of("boat2")])
		_pending_throws.append([_t + 0.25, "sack", from, _deck_of("boat2")])
		_pop_chest("raft", 0.7)
		world.react("raft", "joy", 0.8, true)
	if _boat2_p < B2_BACK + 0.02 and b2 >= B2_BACK + 0.02:
		world.divers.throw_item("sack", _deck_of("boat2"), _dock_chest_pos() + Vector2(0, -34), _ore(), 0.5)
		world.react("sailor2", "joy", 0.8, true)
		_dock_pop_at = _t + 0.45
	_boat2_p = b2
	if _dock_pop_at > 0.0 and _t >= _dock_pop_at:
		_dock_pop_at = -1.0
		_pop_chest("dock", 1.0)
	var tint := DayNight.scene_tint()
	if not tint.is_equal_approx(_tint):
		_tint = tint
		self_modulate = tint
		_ground.self_modulate = tint
	# The crew, boats and plant redraw on the scene's SCENERY frames, the
	# sky life on the others (see World's frame schedule).
	if world.is_visible_band(0.0, size.y):
		if World.tick(World.SCENERY):
			queue_redraw()
			# Night lights flicker; by day only the number tags move.
			var sig := _glow_sig()
			if smoothstep(0.3, 0.8, DayNight.night()) > 0.01 or sig != _glow_last:
				_glow_last = sig
				_glow.queue_redraw()
		if World.tick(World.PEOPLE) and world.is_visible_band(0.0, World.SURFACE_Y):
			_sky_fx.queue_redraw()
			if _t - _lighthouse_poke < 2.4:
				_far.queue_redraw()
	var step := DayNight.stepped_phase()
	if step != _far_step:
		_far_step = step
		_far.queue_redraw()


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
			_rain.append(Vector3(cp.x + _rng.randf_range(-38, 38) * float(c["s"]), cp.y + 8.0, _rng.randf_range(260, 340)))
	for i in range(_rain.size() - 1, -1, -1):
		var r := _rain[i]
		r.y += r.z * dt
		r.x += wind * 40.0 * dt
		_rain[i] = r
		if r.y > World.SURFACE_Y:
			_rain.remove_at(i)
	var day := DayNight.daylight()
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
		# Off screen: come back from the left after a little while
		# (birds sleep at night and return in the morning).
		if float(b["x"]) > w + 50.0 or float(b["y"]) < -60.0:
			b["wait"] = _rng.randf_range(2.0, 7.0)
			b["x"] = -9999.0
	for i in range(_feathers.size() - 1, -1, -1):
		var f: Dictionary = _feathers[i]
		f["age"] = float(f["age"]) + dt
		if float(f["age"]) > 3.0:
			_feathers.remove_at(i)
	if wind > 0.6 and _gusts.size() < 2 and _rng.randf() < dt * 0.25:
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
				v.x *= 0.96
		c["rot"] = float(c["rot"]) + v.x * dt / 5.0
		c["vel"] = v
		c["pos"] = pos
		if float(c["age"]) > 4.0:
			_coconut = {}
	if _coconuts < 2 and _t > _coconut_back:
		_coconuts += 1
		_coconut_back = _t + 25.0


func _update_chests(dt: float) -> void:
	var gs := GameState
	var amounts := {"raft": gs.hold, "dock": gs.dock}
	var caps := {"raft": maxf(1.0, gs.cycle_capacity("boat") * 2.0), "dock": maxf(1.0, gs.cycle_capacity("plant") * 2.0)}
	for which in ["raft", "dock"]:
		var c: Dictionary = _chest[which]
		var amount: float = amounts[which]
		var fill := _fill(amount, caps[which])
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

func _paint_ground(ci: CanvasItem) -> void:
	if _terrace_shown:
		# The terrace for the second plant, behind the island's shore.
		Art.push(ci, Vector2(island_x() + PLANT2_X - 16.0, World.SURFACE_Y))
		Props.terrace(ci, 150.0 * PLANT2_SCALE + 16.0, 64.0 + PLANT2_LIFT)
		Art.pop(ci)
	Art.push(ci, Vector2(island_x(), World.SURFACE_Y))
	Props.island(ci, 280.0)
	Art.pop(ci)


## Far islands and the lighthouse on its rock (a still layer).
func _paint_far(ci: CanvasItem) -> void:
	var w := size.x
	var sy := World.SURFACE_Y
	var sp := DayNight.stepped_phase()
	var lights := smoothstep(0.3, 0.8, DayNight.night(sp))
	Art.push(ci, Vector2(w * 0.2, sy))
	Props.far_island(ci, 170, DayNight.far_color(0.0, sp))
	Art.pop(ci)
	Art.push(ci, Vector2(w * 0.72, sy))
	Props.far_island(ci, 180, DayNight.far_color(0.4, sp))
	Art.pop(ci)
	var flash := clampf(1.0 - (_t - _lighthouse_poke) / 2.2, 0.0, 1.0)
	Art.push(ci, _lighthouse_pos())
	Props.lighthouse(ci, DayNight.far_color(0.2, sp), DayNight.far_color(0.0, sp), maxf(lights, flash))
	Art.pop(ci)


## Clouds, rain, birds and the lighthouse beam (behind the scene).
func _draw_sky_fx(ci: CanvasItem) -> void:
	if not world.is_visible_band(0.0, World.SURFACE_Y):
		return
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
	var cf := DayNight.cloud_fill(sp)
	var cl := DayNight.cloud_line(sp)
	for c in _clouds:
		var poke := _t - float(c["poke"])
		var puff := 0.0
		if poke < 0.7:
			puff = sin(poke / 0.7 * PI * 2.0) * (1.0 - poke / 0.7) * 0.22
		var s: float = c["s"]
		Art.push(ci, _cloud_pos(c), 0.0, Vector2(s * (1.0 + puff), s * (1.0 - puff * 0.7)))
		Props.cloud(ci, int(c["seed"]), cf, cl)
		Art.pop(ci)
	for r in _rain:
		Art.line(ci, Vector2(r.x, r.y), Vector2(r.x - 2.0, r.y + 10.0), Color(0.75, 0.9, 1.0, 0.85), 2.2)
	# The lighthouse beam sweeping over the sea (the tower is on _far).
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
	# Birds (they rest at night).
	var bird_c := Color.WHITE * DayNight.scene_tint(sp)
	for b in _birds:
		if float(b["wait"]) > 0.0:
			continue
		var fleeing := float(b["flee"]) >= 0.0
		var flap := sin(_t * (18.0 if fleeing else 7.0) + float(b["phase"]))
		Art.push(ci, Vector2(b["x"], b["y"]), -0.35 if fleeing else sin(_t * 0.7 + float(b["phase"])) * 0.06)
		Props.gull(ci, flap, Color(bird_c, 1.0))
		Art.pop(ci)
	for f in _feathers:
		var age: float = f["age"]
		var at: Vector2 = f["pos"] + Vector2(sin(age * 3.0 + float(f["seed"])) * 14.0, age * 40.0)
		Art.push(ci, at, sin(age * 3.0 + float(f["seed"])) * 0.6)
		Art.flat_now(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(7, 2.5), 10), Color(1, 1, 1, clampf(3.0 - age, 0.0, 1.0)))
		Art.pop(ci)


func _draw() -> void:
	var w := size.x
	var sy := World.SURFACE_Y
	var lights := smoothstep(0.3, 0.8, DayNight.night())
	_draw_island(lights)
	match second_state("boat2"):
		"open":
			_draw_boat("boat2", lights)
		"sale":
			_draw_buoy(lights)
	if second_state("plant2") == "sale" and _plant_sign_low():
		_draw_sign("plant2")
	_draw_raft(lights)
	_draw_boat("boat", lights)
	# Water surface over the hulls and floats: two waves on top of each other.
	var amp := (1.8 + DayNight.wind * 2.0) * (0.5 if _calm else 1.0)
	var wave := PackedVector2Array()
	for i in 49:
		var x := w * i / 48.0
		wave.append(Vector2(x, sy + sin(_t * 1.6 + i * 0.62) * amp + sin(_t * 2.3 - i * 1.1) * amp * 0.45))
	var front := wave.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	Art.flat_now(self, front, Color(Art.SEA_TOP, 0.6))
	Art.polyline(self, wave, Art.WHITE, 4.0)
	# Little glints riding the crests.
	var glint := DayNight.glint()
	for i in 6:
		var f := fposmod(_t * 0.05 + i / 6.0, 1.0)
		var x := f * w
		var a := sin(f * PI) * (0.5 + 0.5 * sin(_t * 3.0 + i * 2.0))
		Art.line(self, Vector2(x - 7, sy + 7 + (i % 3) * 3), Vector2(x + 7, sy + 7 + (i % 3) * 3), Color(glint, a * 0.8), 2.5)
	for s in _smoke:
		var a := 0.55 * minf(1.0, s.z * 4.0) * (1.0 - s.z / 2.4)
		Art.push(self, Vector2(s.x, s.y), 0.0, Vector2.ONE * (0.55 + ease(minf(1.0, s.z / 2.4), 0.6) * 1.1))
		Art.disc(self, Vector2.ZERO, 10.0, Color(0.96, 0.96, 1.0, a))
		Art.pop(self)
	if not _coconut.is_empty():
		Art.push(self, _coconut["pos"], _coconut["rot"])
		Art.t_circle(self, Vector2(0, -5), 5, Color("8a5a2c"), 2.0, 0.0)
		Art.disc(self, Vector2(-1.5, -7), 1.2, Color("5a3a1c"))
		Art.pop(self)
	for key in BUILDINGS:
		_draw_poof(key)


## White puffs around a building the moment its look changes.
func _draw_poof(key: String) -> void:
	var age := _t - float(_stage_fx[key])
	if age < 0.0 or age > 0.8:
		return
	var f := age / 0.8
	var c: Vector2
	var r: float
	if GameState.is_boat(key):
		c = _boat_pos(key) + Vector2(0, -52) * _boat_scale(key)
		r = 82.0 * _boat_scale(key)
	else:
		c = _plant_pos(key) + Vector2(75, -70) * _plant_scale(key)
		r = 90.0 * _plant_scale(key)
	for i in 12:
		var a := TAU * i / 12.0 + i * 0.3
		var d := r * (0.35 + ease(f, 0.4) * 0.75)
		var p := c + Vector2(cos(a) * d * 1.2, sin(a) * d * 0.8)
		Art.disc(self, p, (18.0 + (i % 3) * 5.0) * (1.0 - f * 0.5), Color(1, 1, 1, 0.9 * (1.0 - f)))


## Squash-and-stretch after a new stage: x = vertical scale, y = hop height.
func _bounce(key: String) -> Vector2:
	var age := _t - float(_stage_fx[key]) - 0.15
	if age < 0.0 or age > 1.1:
		return Vector2(1.0, 0.0)
	var k := age / 1.1
	var sq := sin(k * PI * 3.0) * pow(1.0 - k, 2.0) * 0.2
	return Vector2(1.0 + sq, sin(minf(k * 2.5, 1.0) * PI) * 14.0 * (1.0 - k))


func _push_plant(ci: CanvasItem, key: String = "plant") -> void:
	var b := _bounce(key)
	var s := _plant_scale(key)
	Art.push(ci, _plant_pos(key) + Vector2(75 * s, -b.y), 0.0, Vector2(2.0 - b.x, b.x) * s)
	Art.push(ci, Vector2(-75, 0))


func _push_boat(ci: CanvasItem, key: String = "boat") -> void:
	var b := _bounce(key)
	var s := _boat_scale(key)
	var ph := 0.0 if key == "boat" else 1.9
	Art.push(ci, _boat_pos(key) + Vector2(0, -b.y), sin(_t * 1.4 + ph) * 0.03 * (0.5 if _calm else 1.0),
			Vector2(s * _facing(key) * (2.0 - b.x), s * b.x))
	Art.push(ci, Vector2(0, sin(_t * 1.6 + ph) * 3.0))


func _draw_island(lights: float) -> void:
	var palm_age := _t - _palm_poke
	Art.push(self, _palm_pos())
	Props.palm(self, _t, Props.wind, clampf(1.0 - palm_age / 1.4, 0.0, 1.0), _coconuts)
	Art.pop(self)
	match second_state("plant2"):
		"open":
			_draw_plant2(lights)
		"sale":
			_draw_plot()
	var pp := plant_world_pos()
	var working := GameState.cycle_progress("plant") >= 0.0
	_push_plant(self)
	Props.plant_at_stage(self, _shown_stage("plant"), _t, working, _gear_rot, _plant_flash, lights)
	Art.pop(self)
	Art.pop(self)
	# Conveyor from the shore chest up into the hopper.
	var belt_a := dock_pos() + Vector2(16, -30)
	var belt_b := pp + Vector2(-15, -58)
	Props.conveyor(self, belt_a, belt_b, _t, working, _ore())
	var dc: Dictionary = _chest["dock"]
	Art.push(self, _dock_chest_pos(), 0.0, Vector2.ONE * DOCK_CHEST_SCALE)
	Props.ore_chest(self, _t, _fill(GameState.dock, maxf(1.0, GameState.cycle_capacity("plant") * 2.0)), dc["lid"], _ore(), 5)
	Art.pop(self)
	# Plant worker next to the belt.
	var wmood := world.mood("worker")
	var wemo := "focus" if working else ("sleepy" if GameState.dock <= 0.0 else "bored")
	if GameState.is_rushing() and working:
		wemo = "strain"
	if wmood != "" and wmood != "focus":
		wemo = wmood
	var wpos := pp + Vector2(-44, 0 - world.hop("plant"))
	var swing := absf(sin(_t * 7.0)) if working else 0.0
	Chars.person(self, wpos, 0.8, 1.0, Chars.look(3, "short", 1, "hardhat", "none", 2, "overalls"),
			{"emotion": wemo, "blink": Chars.blinking(_t, 4.0), "arm_r": 2.2 - swing * 1.6, "arm_l": 0.3, "hold": "hammer", "bob": swing})
	if wemo == "sleepy":
		Chars.mark(self, "zzz", wpos + Vector2(14, -84), _t)
	elif wemo == "strain":
		Chars.mark(self, "sweat", wpos + Vector2(-14, -74), _t)
	# The businessman: the player's avatar collects the money.
	var bmood := world.mood("biz")
	var bplant := world.mood("plant")
	var bemo := bmood if bmood != "" else (bplant if bplant != "" else "happy")
	var bpos := _biz_pos() - Vector2(0, maxf(world.hop("biz"), world.hop("plant")))
	var holding := "coinbag" if bmood == "rich" else ("clipboard" if fposmod(_t, 9.0) < 3.0 else "briefcase")
	var arm := 1.9 if bmood == "rich" else (1.2 if holding == "clipboard" else 0.15)
	Chars.person(self, bpos, 0.86, -1.0, Settings.avatar,
			{"emotion": bemo, "blink": Chars.blinking(_t, 9.0), "arm_r": arm, "arm_l": -0.25 if bmood == "" else -2.4, "hold": holding, "bob": 0.0})
	if bmood == "rich":
		Chars.mark(self, "heart", bpos + Vector2(24, -98), _t)
	# The player's pet floats next to them in a little bubble of sea water.
	var pet: String = Progress.equipped_art("pet")
	if pet != "":
		var pet_at := bpos + Vector2(-50, -34 + sin(_t * 2.4) * 5.0 - (8.0 if bmood == "rich" else 0.0))
		Art.disc(self, pet_at, 30.0, Color(0.7, 0.93, 1.0, 0.35))
		Art.arc(self, pet_at, 30.0, 0, TAU, 28, Color(1, 1, 1, 0.8), 2.5)
		Art.push(self, pet_at, 0.0, Vector2(0.95, 0.95))
		PetArt.draw(self, pet, _t, -1.0, bmood == "rich")
		Art.pop(self)
		Art.arc(self, pet_at, 23.0, PI * 1.1, PI * 1.4, 6, Color(1, 1, 1, 0.8), 3.0)


func _draw_raft(lights: float) -> void:
	var p := raft_pos()
	var bob := _raft_bob()
	Art.push(self, p + Vector2(0, bob))
	Props.raft(self, _t, 0, _ore(), lights)
	Art.pop(self)
	var rc: Dictionary = _chest["raft"]
	Art.push(self, _raft_chest_pos(), 0.0, Vector2.ONE * RAFT_CHEST_SCALE)
	Props.ore_chest(self, _t, _fill(GameState.hold, maxf(1.0, GameState.cycle_capacity("boat") * 2.0)), rc["lid"], _ore(), 11)
	Art.pop(self)
	# Loader on the raft.
	var mood := world.mood("raft")
	var emo := mood if mood != "" else ("happy" if GameState.hold > 0.0 else "bored")
	var catching := mood == "joy"
	Chars.person(self, p + Vector2(-22, -15 + bob - world.hop("raft")), 0.8, 1.0, Chars.look(4, "curly", 0, "beanie", "none", 1, "sailor"),
			{"emotion": emo, "blink": Chars.blinking(_t, 2.0), "arm_r": 2.5 if catching else 0.4, "arm_l": -2.5 if catching else -0.2,
			"hold": "sack" if catching else "", "hold_color": _ore()})


## Sailors: the first boat's and the second one's.
const _SAILOR_LOOKS := {"boat": ["sailor", 1], "boat2": ["sailor2", 2]}


func _draw_boat(key: String, lights: float) -> void:
	var bp := _boat_pos(key)
	var bs := _boat_scale(key)
	var p := GameState.cycle_progress(key)
	var facing := _facing(key)
	var mood := world.mood(key)
	var sailor: String = _SAILOR_LOOKS[key][0]
	var smood := world.mood(sailor)
	var semo := smood if smood != "" else (mood if mood != "" else ("happy" if p >= 0.0 else "bored"))
	var sailing := _sailing(key)
	var hop := maxf(world.hop(key), world.hop(sailor))
	var look := Chars.look(1, "short", 3, "sailor", "freckles", 1, "sailor") if key == "boat" else Chars.look(4, "spiky", 2, "sailor", "none", 7, "sailor")
	var crew := func():
		Chars.person(self, Vector2(52, -40 - hop), 0.9, 1.0, look,
				{"emotion": semo, "blink": Chars.blinking(_t + (0.0 if key == "boat" else 1.7), 5.0),
				"arm_r": 2.6 if smood == "joy" else (0.9 + sin(_t * 6.0) * 0.5 if sailing else 0.3), "arm_l": -0.3})
	_push_boat(self, key)
	var cap_emo := mood if mood != "" else "happy"
	Props.downwind = facing
	Props.boat_at_stage(self, _shown_stage(key), _t, _crates(key), _ore(), GameState.has_manager(key), cap_emo, Chars.blinking(_t, 7.0), crew, lights,
			Props.variant_of(key))
	Props.downwind = 1.0
	Art.pop(self)
	Art.pop(self)
	if sailing:
		# Foam behind the boat.
		for i in 3:
			var f := fposmod(_t * 1.5 + i / 3.0, 1.0)
			var at := bp + Vector2(-facing * (82.0 + f * 47.0) * bs, 2)
			Art.arc(self, at, (6.0 + f * 8.0) * bs / BOAT_SCALE, PI, TAU, 10, Color(1, 1, 1, 0.8 * (1.0 - f)), 3.0)


## The second plant on its terrace, with its own worker.
func _draw_plant2(lights: float) -> void:
	var working := GameState.cycle_progress("plant2") >= 0.0
	_push_plant(self, "plant2")
	Props.plant_at_stage(self, _shown_stage("plant2"), _t + 3.1, working, _gear_rot2, _plant2_flash, lights, 1)
	Art.pop(self)
	Art.pop(self)
	var dock_empty: bool = GameState.dock <= 0.0
	var mood := world.mood("worker2")
	var emo := "focus" if working else ("sleepy" if dock_empty else "bored")
	if mood != "" and mood != "focus":
		emo = mood
	var pmood := world.mood("plant2")
	if pmood != "" and emo != "sleepy":
		emo = pmood
	var wpos := plant2_world_pos() + Vector2(14, -maxf(world.hop("plant2"), world.hop("worker2")))
	var swing := absf(sin(_t * 7.0 + 1.3)) if working else 0.0
	Chars.person(self, wpos, 0.66, 1.0, Chars.look(2, "bun", 3, "hardhat", "none", 7, "overalls"),
			{"emotion": emo, "blink": Chars.blinking(_t + 2.3, 4.0), "arm_r": 2.2 - swing * 1.6, "arm_l": 0.3, "hold": "hammer", "bob": swing})
	if emo == "sleepy":
		Chars.mark(self, "zzz", wpos + Vector2(12, -70), _t)


## The plot where the second plant will stand, with its price sign.
func _draw_plot() -> void:
	var p := plant2_world_pos()
	Art.push(self, p + Vector2(4, 0))
	Props.plot(self, 104.0)
	Art.pop(self)
	if not _plant_sign_low():
		_draw_sign("plant2")


## Mooring buoy with the second boat's price sign, bobbing where it will wait.
func _draw_buoy(lights: float) -> void:
	var b := buoy_pos()
	Art.push(self, b, sin(_t * 1.3) * 0.06)
	Props.buoy(self, lights)
	Art.pop(self)
	_draw_sign("boat2")


func _draw_sign(key: String) -> void:
	var place := _sign_place(key)
	var sc: float = place[2]
	var poke := clampf(1.0 - (_t - float(_sign_poke[key])) / 0.6, 0.0, 1.0)
	var ready := 1.0 if _can_buy(key) else 0.0
	var wob := sin(_t * 18.0) * 0.12 * poke + (sin(_t * 3.0) * 0.03 * ready if not _calm else 0.0)
	var sq := 1.0 + sin(_t * 20.0) * 0.06 * poke
	Art.push(self, place[0], wob, Vector2(2.0 - sq, sq) * sc)
	Props.sale_sign(self, _price(key), ready, place[1])
	Art.pop(self)


## What the number tags show and where (the glow layer redraws when it changes).
func _glow_sig() -> Array:
	var r: Dictionary = _chest["raft"]
	var d: Dictionary = _chest["dock"]
	return [NumFormat.short(GameState.hold) if GameState.hold > 0.0 else "", NumFormat.short(GameState.dock) if GameState.dock > 0.0 else "",
			roundf(_raft_bob()), snappedf(float(r["lid"]), 0.05), snappedf(float(d["lid"]), 0.05),
			snappedf(float(r["tag"]), 0.05), snappedf(float(d["tag"]), 0.05), size]


## Night lights and number tags, on top and never darkened.
func _draw_glow(ci: CanvasItem) -> void:
	if not world.is_visible_band(0.0, size.y):
		return
	var lights := smoothstep(0.3, 0.8, DayNight.night())
	if lights > 0.01:
		var plant2 := second_state("plant2")
		if plant2 == "open":
			_push_plant(ci, "plant2")
			Props.plant_lights(ci, _shown_stage("plant2"), _t, lights)
			Art.pop(ci)
			Art.pop(ci)
		_push_plant(ci)
		Props.plant_lights(ci, _shown_stage("plant"), _t, lights)
		Art.pop(ci)
		Art.pop(ci)
		match second_state("boat2"):
			"open":
				_push_boat(ci, "boat2")
				Props.boat_lights(ci, _shown_stage("boat2"), _t, lights)
				Art.pop(ci)
				Art.pop(ci)
			"sale":
				var b := buoy_pos()
				var lamp := b + Props.BUOY_LAMP.rotated(sin(_t * 1.3) * 0.06)
				var blink := 0.55 + 0.45 * sin(_t * 2.6)
				Props.halo(ci, lamp, 26.0, Color(1.0, 0.45, 0.35, 0.5 * lights * blink))
				Art.disc(ci, lamp, 3.5, Color(1.0, 0.9, 0.8, 0.9 * lights))
		_push_boat(ci)
		Props.boat_lights(ci, _shown_stage("boat"), _t, lights)
		Art.pop(ci)
		Art.pop(ci)
		var lamp := raft_pos() + Vector2(0, _raft_bob()) + Props.RAFT_LAMP + Vector2(sin(_t * 1.7) * 1.5, 0)
		Props.halo(ci, lamp, 34.0, Color(1.0, 0.85, 0.45, 0.45 * lights))
		Art.disc(ci, lamp, 4.0, Color(1.0, 0.95, 0.7, 0.9 * lights))
	if GameState.hold > 0.0:
		Props.number_tag(ci, _raft_chest_pos() + Vector2(0, -50 - float(_chest["raft"]["lid"]) * 8.0), NumFormat.short(GameState.hold), _ore(), _chest["raft"]["tag"])
	if GameState.dock > 0.0:
		Props.number_tag(ci, _dock_chest_pos() + Vector2(-8, -54 - float(_chest["dock"]["lid"]) * 8.0), NumFormat.short(GameState.dock), _ore(), _chest["dock"]["tag"])
