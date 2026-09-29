class_name Match3
extends RefCounted
## Match-3 board logic for the puzzle mode (no nodes, no drawing).
##
## Goal of a level: bring artifact FRAGMENTS down to the bottom row. They
## fall with gravity when tiles under them clear, never match and are never
## destroyed by specials. A fragment in the bottom row is collected.
##
## Coordinates are Vector2i(x, y) with y = 0 at the top.
##
## Rules
## - A swap is valid when it makes a line of 3+, or when it moves a special
##   (rocket, bomb, rainbow) - specials fire on any swap or on activate()
##   (a second tap), like Gardenscapes power-ups. Specials are colorless and
##   never match. An invalid swap returns one "bad_swap" step and costs no move.
## - 4 in a line makes a rocket that fires along the same line
##   (a horizontal 4 makes "rocket_h", which clears its row).
##   L / T / + shapes make a bomb (3x3). 5+ in a line makes a rainbow.
## - Rainbow + tile clears every tile of that kind. Rainbow + rocket/bomb
##   turns every tile of the most common kind into that special and fires
##   them. A rainbow set off by a chain clears the most common kind.
##   Rainbow + rainbow clears the board. Rocket + rocket fires a cross,
##   bomb + bomb blasts 5x5, rocket + bomb fires a 3-wide cross.
##   Specials hit by other specials fire too (chains).
## - Sand is a block that fills its cell (no tile there). It falls like
##   everything else, can't be swapped or matched, and loses one layer when
##   a match happens next to it or a special hits it. At most one layer is
##   removed per blocker per clearing wave.
## - A bubble traps a tile: that tile can't be swapped but still falls and
##   still counts in lines. A match that includes it, a match next to it or a
##   special hit pops one bubble layer; the tile itself stays.
## - Everything falls straight down (tiles, fragments, sand); new tiles drop
##   in at the top, so a settled board never has holes.
## - After every move the board has a valid move; otherwise it reshuffles
##   (reported as a "shuffle" step).
##
## swap(a, b) and activate(p) return the whole cascade as a list of steps
## for the view to replay. Every step that changes the board carries "grid",
## a snapshot (see snapshot()) of the board right after that step:
##   {"type": "swap", "a", "b", "grid"}
##   {"type": "bad_swap", "a", "b"}
##   {"type": "clear", "cells": [Vector2i], "kinds": [int], "specials": [String], "combo": int, "grid"}
##   {"type": "blocker_hit", "hits": [{"cell", "blocker": "sand"|"bubble", "left": int}], "grid"}
##   {"type": "special_fire", "special": "rocket_h"|"rocket_v"|"bomb"|"rainbow"|"cross"|"cross3"|"bomb5"|"board",
##       "cell": Vector2i, "area": [Vector2i], "cleared": [{"cell", "kind", "special"}], "kind": int,
##       "targets": [Vector2i] (rainbow), "convert": String (rainbow + special), "combo": int, "grid"}
##   {"type": "special_made", "cell", "special": String, "kind": int, "grid"}
##   {"type": "fall", "moves": [{"from", "to"}], "spawns": [{"from", "to"}], "grid"}
##       (spawn "from" is a virtual cell above the board, y < 0)
##   {"type": "fragment_collected", "cell", "collected": int, "grid"}
##   {"type": "shuffle", "grid"}

const EMPTY := -1
const FRAGMENT := -2
const SAND := -3
## Every special (rocket, bomb, rainbow) is colorless: it never matches.
const SPECIAL_KIND := -4

const NONE := 0
const ROCKET_H := 1
const ROCKET_V := 2
const BOMB := 3
const RAINBOW := 4
const SPECIAL_NAMES: Array[String] = ["", "rocket_h", "rocket_v", "bomb", "rainbow"]

const PLAYING := "playing"
const WON := "won"
const LOST := "lost"

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width := 7
var height := 8
var kinds := 4
var moves := 20
var moves_used := 0
var fragments_needed := 1
var fragments_collected := 0
## Fragments dropped so far (the ones placed at start included).
var fragments_spawned := 0
## How many fragments may be on the board at once; the rest drop in later.
var fragments_max_on_board := 2
var state := PLAYING
var shuffles := 0
## 0..1: chance that a new tile copies the kind under it, so easy levels
## get more cascades (a gentle, invisible helper).
var assist := 0.0
var rng := RandomNumberGenerator.new()

## Per cell (index y * width + x): tile kind (0..kinds-1) or EMPTY/FRAGMENT/SAND/SPECIAL_KIND.
var kind := PackedInt32Array()
var special := PackedInt32Array()
var sand := PackedInt32Array()
var bubble := PackedInt32Array()


## level keys (all optional): width, height, kinds, moves, fragments,
## fragments_at_start, sand, sand2 (two-layer), bubbles, seed.
func _init(level: Dictionary = {}) -> void:
	width = int(level.get("width", 7))
	height = int(level.get("height", 8))
	kinds = clampi(int(level.get("kinds", 4)), 3, 6)
	moves = int(level.get("moves", 20))
	fragments_needed = maxi(1, int(level.get("fragments", 1)))
	fragments_max_on_board = clampi(int(level.get("fragments_at_start", mini(fragments_needed, 2))), 1, width)
	rng.seed = int(level.get("seed", 1))
	assist = clampf(float(level.get("assist", 0.0)), 0.0, 0.9)
	_alloc()
	_generate(int(level.get("sand", 0)), int(level.get("sand2", 0)), int(level.get("bubbles", 0)))


# --- Queries ---------------------------------------------------------------------------

func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func kind_at(p: Vector2i) -> int:
	return kind[idx(p)] if inside(p) else EMPTY


func special_at(p: Vector2i) -> String:
	return SPECIAL_NAMES[special[idx(p)]] if inside(p) else ""


func is_swappable(p: Vector2i) -> bool:
	if not inside(p):
		return false
	var i := idx(p)
	var k := kind[i]
	return k != EMPTY and k != SAND and bubble[i] == 0


func fragments_on_board() -> int:
	var n := 0
	for k in kind:
		if k == FRAGMENT:
			n += 1
	return n


## Copy of the board for the view: {"kind", "special", "sand", "bubble"}
## (PackedInt32Array each, index y * width + x).
func snapshot() -> Dictionary:
	return {"kind": kind.duplicate(), "special": special.duplicate(), "sand": sand.duplicate(), "bubble": bubble.duplicate()}


## A valid swap as [a, b] (the most useful one found), or [] if none.
func find_hint() -> Array:
	_scan_fragments()
	var best := []
	var best_score := 0
	for y in height:
		for x in width:
			var a := Vector2i(x, y)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b := a + d
				if not inside(b):
					continue
				var s := _move_score(a, b)
				if s > best_score:
					best_score = s
					best = [a, b]
	return best


func has_valid_move() -> bool:
	_frag_y.clear()
	for y in height:
		for x in width:
			var a := Vector2i(x, y)
			if _move_score(a, a + Vector2i(1, 0)) > 0 or _move_score(a, a + Vector2i(0, 1)) > 0:
				return true
	return false


## Lowest fragment row per column (-1 = none), for hint scoring.
var _frag_y := PackedInt32Array()


func _scan_fragments() -> void:
	_frag_y.resize(width)
	_frag_y.fill(-1)
	for y in height:
		for x in width:
			if kind[idx(Vector2i(x, y))] == FRAGMENT:
				_frag_y[x] = y


## Clearing p pulls a fragment down.
func _pulls(p: Vector2i) -> bool:
	return not _frag_y.is_empty() and _frag_y[p.x] >= 0 and p.y > _frag_y[p.x]


## 0 = invalid. Bigger is better: specials and combos, then lines that pull
## a fragment down, then long lines.
func _move_score(a: Vector2i, b: Vector2i) -> int:
	if not is_swappable(a) or not is_swappable(b):
		return 0
	var ia := idx(a)
	var ib := idx(b)
	var sa := special[ia]
	var sb := special[ib]
	if sa == RAINBOW or sb == RAINBOW:
		if sa == RAINBOW and sb == RAINBOW:
			return 100
		var other := ib if sa == RAINBOW else ia
		if kind[other] == FRAGMENT:
			return 0
		return 70 if special[other] != NONE else 45
	if sa != NONE and sb != NONE:
		return 80
	if sa != NONE or sb != NONE:
		var at := b if sa != NONE else a
		var sp := sa if sa != NONE else sb
		var s := 25
		for x in width:
			if sp == ROCKET_V and x != at.x:
				continue
			if (sp == ROCKET_H or sp == ROCKET_V) and _pulls(Vector2i(x, at.y if sp == ROCKET_H else height - 1)):
				s += 8
			elif sp == BOMB and absi(x - at.x) <= 1 and _pulls(Vector2i(x, mini(at.y + 1, height - 1))):
				s += 8
		return s
	if kind[ia] == kind[ib]:
		return 0
	_swap_cells(ia, ib)
	var s := _line_score(a) + _line_score(b)
	_swap_cells(ia, ib)
	return s


## Score of the lines of 3+ through p (0 when none): cells, +6 per cell
## under a fragment, and a bonus when the line makes a special.
func _line_score(p: Vector2i) -> int:
	var k := kind[idx(p)]
	if k < 0:
		return 0
	var l := _count(p, Vector2i(-1, 0), k)
	var r := _count(p, Vector2i(1, 0), k)
	var u := _count(p, Vector2i(0, -1), k)
	var d := _count(p, Vector2i(0, 1), k)
	var h := 1 + l + r
	var v := 1 + u + d
	if h < 3 and v < 3:
		return 0
	var s := 0
	if h >= 3:
		for x in range(p.x - l, p.x + r + 1):
			s += 7 if _pulls(Vector2i(x, p.y)) else 1
	if v >= 3:
		for y in range(p.y - u, p.y + d + 1):
			s += 7 if _pulls(Vector2i(p.x, y)) else 1
	if maxi(h, v) >= 5:
		s += 12
	elif h >= 3 and v >= 3:
		s += 8
	elif maxi(h, v) == 4:
		s += 5
	return s


func _count(p: Vector2i, d: Vector2i, k: int) -> int:
	var n := 0
	var q := p + d
	while inside(q) and kind[idx(q)] == k:
		n += 1
		q += d
	return n


# --- Moves -------------------------------------------------------------------------------

func swap(a: Vector2i, b: Vector2i) -> Array:
	var bad := [{"type": "bad_swap", "a": a, "b": b}]
	if state != PLAYING or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return bad
	if not is_swappable(a) or not is_swappable(b):
		return bad
	var ia := idx(a)
	var ib := idx(b)
	var sa := special[ia]
	var sb := special[ib]
	if (sa == RAINBOW and kind[ib] == FRAGMENT) or (sb == RAINBOW and kind[ia] == FRAGMENT):
		return bad
	if sa == NONE and sb == NONE:
		if kind[ia] == kind[ib]:
			return bad
		_swap_cells(ia, ib)
		if _line_score(a) == 0 and _line_score(b) == 0:
			_swap_cells(ia, ib)
			return bad
	else:
		_swap_cells(ia, ib)
	var steps := [{"type": "swap", "a": a, "b": b, "grid": snapshot()}]
	moves -= 1
	moves_used += 1
	# After the swap, a's special sits at b and b's at a.
	var fires := []
	if sa == RAINBOW and sb == RAINBOW:
		_take(ia)
		_take(ib)
		fires.append({"type": "board", "cell": b})
	elif sa == RAINBOW or sb == RAINBOW:
		var r := ib if sa == RAINBOW else ia
		var o := ia if sa == RAINBOW else ib
		var other_sp := special[o]
		_take(r)
		var rc := b if sa == RAINBOW else a
		if other_sp != NONE:
			fires.append({"type": "rainbow_convert", "cell": rc, "kind": _most_common_kind(), "to": other_sp})
		else:
			fires.append({"type": "rainbow", "cell": rc, "kind": kind[o]})
	elif sa != NONE and sb != NONE:
		var combo := "cross3"
		if sa == BOMB and sb == BOMB:
			combo = "bomb5"
		elif sa != BOMB and sb != BOMB:
			combo = "cross"
		_take(ia)
		_take(ib)
		fires.append({"type": combo, "cell": b})
	elif sa != NONE:
		fires.append({"cell": b})
	elif sb != NONE:
		fires.append({"cell": a})
	_resolve(steps, fires, [b, a])
	return steps


## Fires the special at p in place (the view uses it for a second tap on
## a selected special). Costs a move like a swap.
func activate(p: Vector2i) -> Array:
	if state != PLAYING or not is_swappable(p) or special[idx(p)] == NONE:
		return [{"type": "bad_swap", "a": p, "b": p}]
	moves -= 1
	moves_used += 1
	var steps := []
	var fires := []
	if special[idx(p)] == RAINBOW:
		_take(idx(p))
		fires.append({"type": "rainbow", "cell": p, "kind": _most_common_kind()})
	else:
		fires.append({"cell": p})
	_resolve(steps, fires, [])
	return steps


## "+5 moves" after running out: the level goes on.
func add_moves(n: int) -> void:
	moves += n
	if state == LOST and moves > 0:
		state = PLAYING


func _swap_cells(i: int, j: int) -> void:
	var t := kind[i]
	kind[i] = kind[j]
	kind[j] = t
	t = special[i]
	special[i] = special[j]
	special[j] = t


## Removes a special that is consumed by a combo (no chain fire of its own).
func _take(i: int) -> void:
	kind[i] = EMPTY
	special[i] = NONE


# --- Resolution ----------------------------------------------------------------------------

func _resolve(steps: Array, fires: Array, swapped: Array) -> void:
	var combo := 0
	while true:
		var groups := _find_groups()
		if groups.is_empty() and fires.is_empty():
			break
		combo += 1
		_wave(steps, groups, fires, swapped, combo)
		fires = []
		swapped = []
		_settle(steps)
	if fragments_collected >= fragments_needed:
		state = WON
	elif moves <= 0:
		state = LOST
	if state != WON and not has_valid_move():
		_shuffle(steps)


## Gravity, refill and fragment collection until nothing moves.
func _settle(steps: Array) -> void:
	_gravity(steps)
	while _collect_fragments(steps):
		_gravity(steps)


## Lines of 3+ merged into groups: [{"cells": [Vector2i], "kind", "runs": [[cells, horizontal]]}].
func _find_groups() -> Array:
	var runs := []
	for horizontal: bool in [true, false]:
		var outer := height if horizontal else width
		var inner := width if horizontal else height
		for o in outer:
			var s := 0
			while s < inner:
				var p := Vector2i(s, o) if horizontal else Vector2i(o, s)
				var k := kind[idx(p)]
				var e := s + 1
				if k >= 0:
					while e < inner and kind[idx(Vector2i(e, o) if horizontal else Vector2i(o, e))] == k:
						e += 1
					if e - s >= 3:
						var cells := []
						for j in range(s, e):
							cells.append(Vector2i(j, o) if horizontal else Vector2i(o, j))
						runs.append([cells, horizontal])
				s = e
	# Merge runs that share a cell.
	var owner := {}
	var groups := []
	for r in runs:
		var hit := -1
		for c in r[0]:
			if owner.has(c):
				hit = owner[c]
				break
		if hit == -1:
			hit = groups.size()
			groups.append({"cells": [], "runs": [], "kind": kind[idx(r[0][0])]})
		var g: Dictionary = groups[hit]
		g["runs"].append(r)
		for c in r[0]:
			if not owner.has(c):
				owner[c] = hit
				g["cells"].append(c)
	return groups


func _special_for(g: Dictionary) -> int:
	var longest := 0
	var has_h := false
	var has_v := false
	var dir_h := true
	for r in g["runs"]:
		var n: int = r[0].size()
		if r[1]:
			has_h = true
		else:
			has_v = true
		if n > longest:
			longest = n
			dir_h = r[1]
	if longest >= 5:
		return RAINBOW
	if has_h and has_v:
		return BOMB
	if longest == 4:
		return ROCKET_H if dir_h else ROCKET_V
	return NONE


## Where a group's special appears: the swapped cell if it is in the group,
## else the crossing of an L/T, else the middle of the longest line.
func _special_spots(g: Dictionary, swapped: Array) -> Array:
	var spots := []
	for s in swapped:
		if s in g["cells"]:
			spots.append(s)
	var seen := {}
	for r in g["runs"]:
		for c in r[0]:
			if seen.has(c):
				spots.append(c)
			seen[c] = true
	var longest: Array = g["runs"][0][0]
	for r in g["runs"]:
		if r[0].size() > longest.size():
			longest = r[0]
	spots.append(longest[longest.size() / 2])
	spots.append_array(g["cells"])
	return spots


func _wave(steps: Array, groups: Array, fires: Array, swapped: Array, combo: int) -> void:
	var ctx := {"hit": {}, "armed": {}, "hits": [], "queue": []}
	var cleared := []
	var makes := []
	for g in groups:
		for c in g["cells"]:
			_hit(c, ctx, cleared)
		for c in g["cells"]:
			for d in DIRS:
				_hit_blocker(c + d, ctx)
		var sp := _special_for(g)
		if sp != NONE:
			makes.append([_special_spots(g, swapped), sp, g["kind"]])
	if not cleared.is_empty():
		var cells := []
		var ks := []
		var sps := []
		for c in cleared:
			cells.append(c["cell"])
			ks.append(c["kind"])
			sps.append(c["special"])
		steps.append({"type": "clear", "cells": cells, "kinds": ks, "specials": sps, "combo": combo, "grid": snapshot()})
	_flush_hits(steps, ctx)
	for f in fires:
		if f.has("type"):
			ctx["queue"].append(f)
		else:
			_hit(f["cell"], ctx, cleared)
	while not ctx["queue"].is_empty():
		_fire(ctx["queue"].pop_front(), steps, ctx, combo)
	for m in makes:
		for spot: Vector2i in m[0]:
			var i := idx(spot)
			if kind[i] == EMPTY:
				special[i] = m[1]
				kind[i] = SPECIAL_KIND
				steps.append({"type": "special_made", "cell": spot, "special": SPECIAL_NAMES[m[1]], "kind": m[2], "grid": snapshot()})
				break


## One hit on a cell: sand and bubbles lose a layer, a plain tile clears,
## a special tile is armed (it fires from the queue). Fragments ignore it.
func _hit(c: Vector2i, ctx: Dictionary, cleared: Array) -> void:
	if not inside(c):
		return
	var i := idx(c)
	var k := kind[i]
	if k == SAND or bubble[i] > 0:
		_hit_blocker(c, ctx)
		return
	if k == EMPTY or k == FRAGMENT:
		return
	if special[i] != NONE:
		if not ctx["armed"].has(i):
			ctx["armed"][i] = true
			ctx["queue"].append({"cell": c})
		return
	cleared.append({"cell": c, "kind": k, "special": ""})
	kind[i] = EMPTY


## Sand and bubbles lose one layer (once per wave); anything else is untouched.
func _hit_blocker(c: Vector2i, ctx: Dictionary) -> void:
	if not inside(c):
		return
	var i := idx(c)
	if ctx["hit"].has(i):
		return
	if kind[i] == SAND:
		ctx["hit"][i] = true
		sand[i] -= 1
		if sand[i] <= 0:
			sand[i] = 0
			kind[i] = EMPTY
		ctx["hits"].append({"cell": c, "blocker": "sand", "left": sand[i]})
	elif bubble[i] > 0:
		ctx["hit"][i] = true
		bubble[i] -= 1
		ctx["hits"].append({"cell": c, "blocker": "bubble", "left": bubble[i]})


func _flush_hits(steps: Array, ctx: Dictionary) -> void:
	if ctx["hits"].is_empty():
		return
	steps.append({"type": "blocker_hit", "hits": ctx["hits"], "grid": snapshot()})
	ctx["hits"] = []


func _fire(f: Dictionary, steps: Array, ctx: Dictionary, combo: int) -> void:
	var c: Vector2i = f["cell"]
	var cleared := []
	var t: String = f.get("type", "")
	var k: int = f.get("kind", -1)
	if t == "":
		# An armed special tile still sitting at c.
		var i := idx(c)
		if special[i] == NONE:
			return
		t = SPECIAL_NAMES[special[i]]
		k = kind[i]
		cleared.append({"cell": c, "kind": k, "special": t})
		_take(i)
		if t == "rainbow":
			k = _most_common_kind()
	var step := {"type": "special_fire", "special": t, "cell": c, "kind": k, "combo": combo}
	var area := []
	match t:
		"rocket_h":
			for x in width:
				area.append(Vector2i(x, c.y))
		"rocket_v":
			for y in height:
				area.append(Vector2i(c.x, y))
		"bomb":
			area = _square(c, 1)
		"bomb5":
			area = _square(c, 2)
		"cross":
			for x in width:
				area.append(Vector2i(x, c.y))
			for y in height:
				if y != c.y:
					area.append(Vector2i(c.x, y))
		"cross3":
			var seen := {}
			for d in [-1, 0, 1]:
				for x in width:
					seen[Vector2i(x, c.y + d)] = true
				for y in height:
					seen[Vector2i(c.x + d, y)] = true
			for p in seen:
				if inside(p):
					area.append(p)
		"board":
			for y in height:
				for x in width:
					area.append(Vector2i(x, y))
		"rainbow", "rainbow_convert":
			for y in height:
				for x in width:
					if kind[idx(Vector2i(x, y))] == k and k >= 0:
						area.append(Vector2i(x, y))
			step["special"] = "rainbow"
			step["targets"] = area
	if t == "rainbow_convert":
		# Every plain tile of that kind becomes the special, then they all fire.
		var to: int = f["to"]
		step["convert"] = SPECIAL_NAMES[to]
		for p in area:
			var i := idx(p)
			if special[i] == NONE and bubble[i] == 0:
				special[i] = to if to == BOMB else (ROCKET_H if rng.randi() % 2 == 0 else ROCKET_V)
		step["area"] = area
		step["cleared"] = cleared
		step["grid"] = snapshot()
		steps.append(step)
		for p in area:
			_hit(p, ctx, cleared)
		_flush_hits(steps, ctx)
		return
	for p in area:
		_hit(p, ctx, cleared)
	step["area"] = area
	step["cleared"] = cleared
	step["grid"] = snapshot()
	steps.append(step)
	_flush_hits(steps, ctx)


func _square(c: Vector2i, r: int) -> Array:
	var out := []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if inside(p):
				out.append(p)
	return out


func _most_common_kind() -> int:
	var counts := []
	counts.resize(kinds)
	counts.fill(0)
	for k in kind:
		if k >= 0:
			counts[k] += 1
	var best := 0
	for i in kinds:
		if counts[i] > counts[best]:
			best = i
	return best


func _gravity(steps: Array) -> void:
	var moved := []
	var spawns := []
	for x in width:
		var write := height - 1
		for y in range(height - 1, -1, -1):
			var i := idx(Vector2i(x, y))
			if kind[i] == EMPTY:
				continue
			if y != write:
				var j := idx(Vector2i(x, write))
				kind[j] = kind[i]
				special[j] = special[i]
				sand[j] = sand[i]
				bubble[j] = bubble[i]
				kind[i] = EMPTY
				special[i] = NONE
				sand[i] = 0
				bubble[i] = 0
				moved.append({"from": Vector2i(x, y), "to": Vector2i(x, write)})
			write -= 1
		var n := write + 1
		for y in range(write, -1, -1):
			var i := idx(Vector2i(x, y))
			kind[i] = rng.randi_range(0, kinds - 1)
			if assist > 0.0 and y < height - 1 and rng.randf() < assist:
				var below := kind[idx(Vector2i(x, y + 1))]
				if below >= 0:
					kind[i] = below
			special[i] = NONE
			sand[i] = 0
			bubble[i] = 0
			spawns.append({"from": Vector2i(x, y - n), "to": Vector2i(x, y)})
	# Later fragments drop in with new tiles, one at a time.
	if not spawns.is_empty() and fragments_spawned < fragments_needed and fragments_on_board() < fragments_max_on_board:
		var top := []
		for s in spawns:
			if s["to"].y == 0:
				top.append(s)
		if not top.is_empty():
			var s: Dictionary = top[rng.randi_range(0, top.size() - 1)]
			kind[idx(s["to"])] = FRAGMENT
			fragments_spawned += 1
	if not moved.is_empty() or not spawns.is_empty():
		steps.append({"type": "fall", "moves": moved, "spawns": spawns, "grid": snapshot()})


func _collect_fragments(steps: Array) -> bool:
	var any := false
	for x in width:
		var p := Vector2i(x, height - 1)
		var i := idx(p)
		if kind[i] == FRAGMENT:
			kind[i] = EMPTY
			fragments_collected += 1
			any = true
			steps.append({"type": "fragment_collected", "cell": p, "collected": fragments_collected, "grid": snapshot()})
	return any


# --- Board setup and shuffle ------------------------------------------------------------------

func _generate(sand_count: int, sand2_count: int, bubble_count: int) -> void:
	for attempt in 40:
		_fill_plain()
		_place_blockers(sand_count, sand2_count, bubble_count)
		_place_fragments()
		if _find_groups().is_empty() and has_valid_move():
			return
	_shuffle([])


## Random kinds with no line of 3 anywhere.
func _fill_plain() -> void:
	for y in height:
		for x in width:
			var i := idx(Vector2i(x, y))
			special[i] = NONE
			sand[i] = 0
			bubble[i] = 0
			kind[i] = _safe_kind(Vector2i(x, y))


func _safe_kind(p: Vector2i) -> int:
	var banned := {}
	if p.x >= 2:
		var a := kind[idx(p - Vector2i(1, 0))]
		if a >= 0 and a == kind[idx(p - Vector2i(2, 0))]:
			banned[a] = true
	if p.y >= 2:
		var a := kind[idx(p - Vector2i(0, 1))]
		if a >= 0 and a == kind[idx(p - Vector2i(0, 2))]:
			banned[a] = true
	var k := rng.randi_range(0, kinds - 1)
	while banned.has(k):
		k = (k + 1) % kinds
	return k


func _place_blockers(sand_count: int, sand2_count: int, bubble_count: int) -> void:
	# Sand lies low: random cells in the bottom three rows.
	var sand_cells := []
	for y in range(maxi(1, height - 3), height):
		for x in width:
			sand_cells.append(Vector2i(x, y))
	_rng_shuffle(sand_cells)
	var total := mini(sand_count + sand2_count, sand_cells.size() / 2)
	for n in total:
		var i := idx(sand_cells[n])
		kind[i] = SAND
		sand[i] = 2 if n < sand2_count else 1
	# Bubbles trap tiles in the middle rows.
	var cells := []
	for y in range(2, height - 1):
		for x in width:
			if kind[idx(Vector2i(x, y))] >= 0:
				cells.append(Vector2i(x, y))
	_rng_shuffle(cells)
	for n in mini(bubble_count, cells.size() / 3):
		bubble[idx(cells[n])] = 1


func _place_fragments() -> void:
	var cols := []
	for x in width:
		cols.append(x)
	_rng_shuffle(cols)
	fragments_spawned = 0
	for n in mini(fragments_max_on_board, fragments_needed):
		var i := idx(Vector2i(cols[n], 0))
		kind[i] = FRAGMENT
		special[i] = NONE
		bubble[i] = 0
		fragments_spawned += 1


func _rng_shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Mixes the free plain tiles until there is no line and a valid move.
func _shuffle(steps: Array) -> void:
	shuffles += 1
	var cells := []
	var vals := []
	for i in kind.size():
		if kind[i] >= 0 and special[i] == NONE and bubble[i] == 0:
			cells.append(i)
			vals.append(kind[i])
	var ok := false
	for attempt in 60:
		_rng_shuffle(vals)
		for n in cells.size():
			kind[cells[n]] = vals[n]
		if _find_groups().is_empty() and has_valid_move():
			ok = true
			break
	if not ok:
		# Fresh random kinds for those cells.
		for attempt in 60:
			for i in cells:
				kind[i] = _safe_kind(Vector2i(i % width, i / width))
			if _find_groups().is_empty() and has_valid_move():
				ok = true
				break
	if not ok:
		# Last resort: free every bubble and make a bomb, which always has a move.
		for i in kind.size():
			bubble[i] = 0
		for i in cells:
			var p := Vector2i(i % width, i / width)
			for d in DIRS:
				if is_swappable(p + d):
					special[i] = BOMB
					ok = true
					break
			if ok:
				break
	steps.append({"type": "shuffle", "grid": snapshot()})


# --- Test helpers -------------------------------------------------------------------------------

## Loads a board from strings, one per row: 0-5 tile kinds, F fragment,
## S sand (1 layer), T sand (2 layers), a-f bubbled kinds 0-5, . empty.
## Specials: put(p, kind, "rocket_h") after loading.
func load_rows(rows: Array) -> void:
	height = rows.size()
	width = String(rows[0]).length()
	_alloc()
	fragments_spawned = 0
	for y in height:
		var row: String = rows[y]
		for x in width:
			var ch := row[x]
			var i := idx(Vector2i(x, y))
			if ch == "F":
				kind[i] = FRAGMENT
				fragments_spawned += 1
			elif ch == "S" or ch == "T":
				kind[i] = SAND
				sand[i] = 1 if ch == "S" else 2
			elif ch == ".":
				kind[i] = EMPTY
			elif ch >= "a" and ch <= "f":
				kind[i] = ch.unicode_at(0) - "a".unicode_at(0)
				bubble[i] = 1
			else:
				kind[i] = int(ch)


func _alloc() -> void:
	var n := width * height
	kind.resize(n)
	kind.fill(EMPTY)
	special.resize(n)
	special.fill(NONE)
	sand.resize(n)
	sand.fill(0)
	bubble.resize(n)
	bubble.fill(0)


func put(p: Vector2i, k: int, sp: String = "") -> void:
	var i := idx(p)
	var s := SPECIAL_NAMES.find(sp)
	special[i] = maxi(0, s)
	kind[i] = SPECIAL_KIND if s > NONE else k
