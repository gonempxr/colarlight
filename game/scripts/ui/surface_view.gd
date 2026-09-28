class_name SurfaceView
extends Control
## Everything above water: sky, the raft with its crane and loader, the
## tugboat with a sailor (and the captain once hired), the island with the
## processing plant, its worker and the businessman (the player's avatar)
## who collects the money. Cards for the boat and the plant sit in the sky.

const BOAT_SCALE := 0.85
const BOAT_LOAD_END := 0.12
const BOAT_SAIL_END := 0.45
const BOAT_UNLOAD_END := 0.58
const PLANT_X := 100.0

var world: World
var boat_card: StageCard
var plant_card: StageCard

var _t := 0.0
var _smoke: Array[Vector3] = []   # x, y, age
var _gear_rot := 0.0
var _boat_p := -1.0
var _plant_flash := 0.0
var _gulls: Array[Vector3] = []
var _pending_throws: Array[Array] = []   # [time, kind, a, b]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
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
	for i in 2:
		_gulls.append(Vector3(randf(), 120.0 + i * 70.0, 0.02 + i * 0.01))


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
	return Rect2(p + Vector2(0, -100), Vector2(150, 100))


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


func _biz_pos() -> Vector2:
	return plant_world_pos() + Vector2(122, 0)


func _ore() -> Color:
	return Art.DEPTH_STYLE[0]["ore2"]


# --- Events -----------------------------------------------------------------------------

func _on_cycle_started(key: String, _amount: float) -> void:
	if key == "boat":
		var from := raft_pos() + Vector2(40, -40)
		var to := _boat_deck(boat_world_pos())
		_pending_throws.append([_t, "sack", from, to])
		_pending_throws.append([_t + 0.25, "sack", from, to])
		world.react("raft", "joy", 0.8, true)
		Sfx.play("horn")
	elif key == "plant":
		world.react("worker", "focus", 1.0)


func _on_cycle_finished(key: String, amount: float) -> void:
	match key:
		"plant":
			_plant_flash = 1.0
			var door := plant_world_pos() + Vector2(121, -44)
			world.divers.throw_item("coinbag", door, _biz_pos() + Vector2(14, -60), Art.GOLD, 0.45)
			var text_at := _biz_pos() + Vector2(0, -130)
			get_tree().create_timer(0.45).timeout.connect(func():
				world.react("biz", "rich", 1.4, true)
				if randf() < 0.25:
					Sfx.voice("ooh", 0.85)
				world.divers.float_text(text_at, "+" + NumFormat.short(amount), Art.GOLD, true)
				Sfx.play("coins"))
		"boat":
			world.divers.float_text(dock_pos() + Vector2(0, -50), "+" + NumFormat.short(amount), Color("bff6ff"))
		_:
			if key.begins_with("d"):
				world.react("raft", "joy", 0.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Scroller.is_drag() or event.position.y < 250.0:
			return
		var key := "plant" if event.position.x > island_x() else "boat"
		if GameState.tap(key):
			Sfx.play("horn" if key == "boat" else "machine")
		else:
			Sfx.play("tap")
		world.divers.tap_ripple(event.position)


func _process(delta: float) -> void:
	_t += delta
	_plant_flash = maxf(0.0, _plant_flash - delta * 2.0)
	var working := GameState.cycle_progress("plant") >= 0.0
	if working:
		_gear_rot += delta * 3.0
		if randf() < delta * 5.0:
			var p := plant_world_pos()
			_smoke.append(Vector3(p.x + 31, p.y - 176, 0.0))
	if GameState.cycle_progress("boat") >= 0.0 and randf() < delta * 3.0:
		var bp := boat_world_pos()
		_smoke.append(Vector3(bp.x - 14 * BOAT_SCALE * _boat_facing(), bp.y - 130 * BOAT_SCALE, 0.0))
	for i in range(_smoke.size() - 1, -1, -1):
		var s := _smoke[i]
		s.z += delta
		s.y -= delta * 28.0
		s.x += delta * 14.0
		_smoke[i] = s
		if s.z > 2.4:
			_smoke.remove_at(i)
	for i in _gulls.size():
		var g := _gulls[i]
		g.x = fposmod(g.x + g.z * delta, 1.2)
		_gulls[i] = g
	# Sacks thrown with a small delay, and the unloading moment.
	for i in range(_pending_throws.size() - 1, -1, -1):
		var th: Array = _pending_throws[i]
		if _t >= th[0]:
			world.divers.throw_item(th[1], th[2], th[3], _ore(), 0.5)
			_pending_throws.remove_at(i)
	var bp := GameState.cycle_progress("boat")
	if _boat_p < BOAT_SAIL_END + 0.02 and bp >= BOAT_SAIL_END + 0.02:
		world.divers.throw_item("sack", _boat_deck(boat_world_pos()), dock_pos(), _ore(), 0.5)
		world.react("sailor", "joy", 0.8, true)
	_boat_p = bp
	if World.anim_tick() and world.is_visible_band(0.0, size.y):
		queue_redraw()


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	var sy := World.SURFACE_Y
	Art.grad(self, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, sy), Vector2(0, sy)]), PackedColorArray([Art.SKY_TOP, Art.SKY_TOP, Art.SKY_BOTTOM, Art.SKY_BOTTOM]))
	Art.push(self, Vector2(74, 96))
	Props.sun(self, _t)
	Art.pop(self)
	Art.push(self, Vector2(w * 0.3, sy))
	Props.far_island(self, 220, Color("9fd4ee"))
	Art.pop(self)
	Art.push(self, Vector2(w * 0.62, sy))
	Props.far_island(self, 160, Color("8ccbe8"))
	Art.pop(self)
	for i in 3:
		var cx := fposmod(i * 300.0 + _t * (7.0 + i * 3.0), w + 240.0) - 120.0
		Art.push(self, Vector2(cx, 250.0 + i * 46.0), 0.0, Vector2.ONE * (0.8 + i * 0.15))
		Props.cloud(self, i + 1)
		Art.pop(self)
	for g in _gulls:
		var gx := (g.x - 0.1) * w
		var flap := sin(_t * 8.0 + g.y) * 6.0
		Art.polyline(self, PackedVector2Array([Vector2(gx - 12, g.y + 50 - flap), Vector2(gx - 5, g.y + 50), Vector2(gx, g.y + 54), Vector2(gx + 5, g.y + 50), Vector2(gx + 12, g.y + 50 - flap)]), Art.INK, 3.0)
	_draw_island()
	_draw_raft()
	_draw_boat()
	# Water surface over the hulls and floats.
	var wave := PackedVector2Array()
	for i in 41:
		wave.append(Vector2(w * i / 40.0, sy + sin(_t * 1.6 + i * 0.7) * 3.0))
	var front := wave.duplicate()
	front.append(Vector2(w, sy + 16))
	front.append(Vector2(0, sy + 16))
	Art.flat_now(self, front, Color(Art.SEA_TOP, 0.6))
	Art.polyline(self, wave, Art.WHITE, 4.0)
	for s in _smoke:
		var a := 0.55 * (1.0 - s.z / 2.4)
		Art.push(self, Vector2(s.x, s.y), 0.0, Vector2.ONE * (0.6 + s.z * 0.5))
		Art.toon(self, Art.circle_pts(Vector2.ZERO, 10, 16), Color(1, 1, 1, a), 0.0, 0.0)
		Art.pop(self)


func _draw_island() -> void:
	var ix := island_x()
	var sy := World.SURFACE_Y
	Art.push(self, Vector2(ix, sy))
	Props.island(self, 280.0)
	Art.push(self, Vector2(268, -64))
	Props.palm(self, _t)
	Art.pop(self)
	Art.pop(self)
	var pp := plant_world_pos()
	var working := GameState.cycle_progress("plant") >= 0.0
	Art.push(self, pp)
	Props.plant(self, _t, working, _gear_rot, _plant_flash)
	Art.pop(self)
	# Conveyor from the shore pile up into the hopper.
	var belt_a := dock_pos() + Vector2(8, -6)
	var belt_b := pp + Vector2(-15, -58)
	Props.conveyor(self, belt_a, belt_b, _t, working, _ore())
	if GameState.dock > 0.0:
		var n := clampi(int(log(GameState.dock + 1.0) / log(10.0)) + 1, 1, 5)
		Props.ore_pile(self, dock_pos() + Vector2(-4, 2), n, _ore(), 5)
		Art.text(self, dock_pos() + Vector2(-2, -44), NumFormat.short(GameState.dock), 20, Color("dff8ff"), 5)
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


func _draw_raft() -> void:
	var p := raft_pos()
	var bob := sin(_t * 1.6) * 3.0
	var pile := 0
	if GameState.hold > 0.0:
		pile = clampi(int(log(GameState.hold + 1.0) / log(10.0)) + 1, 1, 5)
	Art.push(self, p + Vector2(0, bob))
	Props.raft(self, _t, pile, _ore())
	Art.pop(self)
	if GameState.hold > 0.0:
		Art.text(self, p + Vector2(40, -60 + bob), NumFormat.short(GameState.hold), 20, Color("dff8ff"), 5)
	# Loader on the raft.
	var mood := world.mood("raft")
	var emo := mood if mood != "" else ("happy" if GameState.hold > 0.0 else "bored")
	var catching := mood == "joy"
	Chars.person(self, p + Vector2(-22, -15 + bob - world.hop("raft")), 0.8, 1.0, Chars.look(4, "curly", 0, "beanie", "none", 1, "sailor"),
			{"emotion": emo, "blink": Chars.blinking(_t, 2.0), "arm_r": 2.5 if catching else 0.4, "arm_l": -2.5 if catching else -0.2,
			"hold": "sack" if catching else "", "hold_color": _ore()})


func _draw_boat() -> void:
	var bp := boat_world_pos()
	var p := GameState.cycle_progress("boat")
	var facing := _boat_facing()
	var crates := 0
	if p >= 0.04 and p < BOAT_SAIL_END + 0.02:
		var cap := maxf(1.0, GameState.cycle_capacity("boat"))
		crates = clampi(ceili(GameState.cycle_load("boat") / cap * 3.0), 1, 3)
	var mood := world.mood("boat")
	var smood := world.mood("sailor")
	var semo := smood if smood != "" else (mood if mood != "" else ("happy" if p >= 0.0 else "bored"))
	var sailing := p >= BOAT_LOAD_END and (p < BOAT_SAIL_END or p >= BOAT_UNLOAD_END)
	var hop := maxf(world.hop("boat"), world.hop("sailor"))
	var crew := func():
		Chars.person(self, Vector2(52, -40 - hop), 0.9, 1.0, Chars.look(1, "short", 3, "sailor", "freckles", 1, "sailor"),
				{"emotion": semo, "blink": Chars.blinking(_t, 5.0), "arm_r": 2.6 if smood == "joy" else (0.9 + sin(_t * 6.0) * 0.5 if sailing else 0.3),
				"arm_l": -0.3})
	Art.push(self, bp, sin(_t * 1.4) * 0.03, Vector2(BOAT_SCALE * facing, BOAT_SCALE))
	Art.push(self, Vector2(0, sin(_t * 1.6) * 3.0))
	var cap_emo := mood if mood != "" else "happy"
	Props.boat(self, _t, crates, _ore(), GameState.has_manager("boat"), cap_emo, Chars.blinking(_t, 7.0), crew)
	Art.pop(self)
	Art.pop(self)
	if sailing:
		# Foam behind the boat.
		for i in 3:
			var f := fposmod(_t * 1.5 + i / 3.0, 1.0)
			var at := bp + Vector2(-facing * (70.0 + f * 40.0), 2)
			Art.arc(self, at, 6.0 + f * 8.0, PI, TAU, 10, Color(1, 1, 1, 0.8 * (1.0 - f)), 3.0)
