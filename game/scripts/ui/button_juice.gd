class_name ButtonJuice
extends Node
## Squash and stretch for every button in the game: pressed, a button
## squashes a little (wider and lower); let go, it springs up taller and
## wobbles back to its shape. Works on top of whatever scale a button
## already has (the dock's wiggle, the title's Play pulse): it multiplies
## that scale and gives it back when the wobble ends. Runs after every
## other script each frame (process_priority), so it sees their scale.
## Buttons with the meta "no_juice" are left alone.

const PRESS := Vector2(1.06, 0.9)
const PRESS_SEC := 0.07
const RELEASE_SEC := 0.42

## button id -> {"b": button, "down": bool, "t": seconds since the change,
##              "from": squash when it changed, "applied": scale set last}
var _live := {}


func _ready() -> void:
	process_priority = 1000
	get_tree().node_added.connect(_on_node_added)
	_hook_all(get_tree().root)


func _hook_all(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_hook_all(c)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("juice_hooked"):
		n.set_meta("juice_hooked", true)
		var b := n as BaseButton
		b.button_down.connect(_on_down.bind(b))
		b.button_up.connect(_on_up.bind(b))


func _on_down(b: BaseButton) -> void:
	if Settings.reduce_motion or b.has_meta("no_juice"):
		return
	var e: Dictionary = _live.get(b.get_instance_id(), {})
	if e.is_empty():
		if b.pivot_offset == Vector2.ZERO:
			b.pivot_offset = b.size / 2.0
		e = {"b": b, "applied": Vector2.INF, "sq": Vector2.ONE}
		_live[b.get_instance_id()] = e
	e["down"] = true
	e["t"] = 0.0
	e["from"] = e["sq"]


func _on_up(b: BaseButton) -> void:
	var e: Dictionary = _live.get(b.get_instance_id(), {})
	if e.is_empty():
		return
	e["down"] = false
	e["t"] = 0.0
	e["from"] = e["sq"]


## Squash of a button `t` seconds after it was pressed or let go.
static func squash_at(down: bool, t: float, from: Vector2) -> Vector2:
	if down:
		return from.lerp(PRESS, Motion.ease_out_cubic(t / PRESS_SEC))
	# Let go: from the squash through a stretch back to 1 (a fading wobble).
	var k := clampf(t / RELEASE_SEC, 0.0, 1.0)
	var w := cos(k * PI * 2.6) * pow(1.0 - k, 2.0)
	var start := from - Vector2.ONE
	return Vector2.ONE + start * w


func _process(delta: float) -> void:
	if _live.is_empty():
		return
	for id in _live.keys():
		var e: Dictionary = _live[id]
		var b = e["b"]
		if not is_instance_valid(b):
			_live.erase(id)
			continue
		var btn := b as BaseButton
		# The button's own scale: what someone set this frame, or the one
		# under the squash we put on it last frame.
		var applied: Vector2 = e["applied"]
		var sq: Vector2 = e["sq"]
		var base := btn.scale
		if btn.scale.is_equal_approx(applied):
			base = btn.scale / sq
		e["t"] = float(e["t"]) + delta
		sq = squash_at(e["down"], e["t"], e["from"])
		e["sq"] = sq
		if not e["down"] and float(e["t"]) >= RELEASE_SEC:
			btn.scale = base
			_live.erase(id)
			continue
		btn.scale = base * sq
		e["applied"] = btn.scale
