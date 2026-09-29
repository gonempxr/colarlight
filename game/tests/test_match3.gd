extends SceneTree
## Match-3 model checks (no UI):
##   godot --headless --path . -s res://tests/test_match3.gd
## Exit code 0 means every check passed.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_start_board()
	test_determinism()
	test_three_match()
	test_invalid_swaps()
	test_rockets()
	test_bomb()
	test_rainbow()
	test_combos()
	test_specials_never_match()
	test_chain()
	test_sand()
	test_bubbles()
	test_fragments()
	test_win_lose()
	test_levels()
	test_fuzz()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


# --- Helpers ---------------------------------------------------------------------------

## 7x8 board of kinds 1-5 without any line; tests draw with kind 0.
func _rows(w: int = 7, h: int = 8) -> Array:
	var rows := []
	for y in h:
		var s := ""
		for x in w:
			s += str(1 + (x + 2 * y) % 5)
		rows.append(s)
	return rows


func _put_ch(rows: Array, x: int, y: int, ch: String) -> void:
	var s: String = rows[y]
	rows[y] = s.substr(0, x) + ch + s.substr(x + 1)


func _model(rows: Array, moves: int = 10, fragments: int = 1) -> Match3:
	var m := Match3.new({"kinds": 6, "seed": 5, "moves": moves, "fragments": fragments})
	m.load_rows(rows)
	check(m._find_groups().is_empty(), "test board starts without lines")
	return m


func _first(steps: Array, type: String) -> Dictionary:
	for s in steps:
		if s["type"] == type:
			return s
	return {}


func _all(steps: Array, type: String) -> Array:
	return steps.filter(func(s): return s["type"] == type)


func _fires(steps: Array, special: String) -> Array:
	return steps.filter(func(s): return s["type"] == "special_fire" and s["special"] == special)


func _no_holes(m: Match3) -> bool:
	for k in m.kind:
		if k == Match3.EMPTY:
			return false
	return true


func _count_kind(grid: Dictionary, k: int) -> int:
	var n := 0
	for v in grid["kind"]:
		if v == k:
			n += 1
	return n


# --- Tests ------------------------------------------------------------------------------

func test_start_board() -> void:
	var bad_lines := 0
	var no_move := 0
	var frag_ok := true
	for n in range(1, 61):
		for s in 4:
			var lv := PuzzleLevels.level(n)
			lv["seed"] = lv["seed"] + s * 977
			var m := Match3.new(lv)
			if not m._find_groups().is_empty():
				bad_lines += 1
			if not m.has_valid_move():
				no_move += 1
			if m.fragments_on_board() != lv["fragments_at_start"]:
				frag_ok = false
			for x in m.width:
				for y in range(1, m.height):
					if m.kind_at(Vector2i(x, y)) == Match3.FRAGMENT:
						frag_ok = false
	check(bad_lines == 0, "no level starts with a line (%d did)" % bad_lines)
	check(no_move == 0, "every level starts with a valid move (%d did not)" % no_move)
	check(frag_ok, "fragments start in the top row, as many as asked")


func test_determinism() -> void:
	var lv := PuzzleLevels.level(17)
	var a := Match3.new(lv)
	var b := Match3.new(lv)
	check(a.kind == b.kind and a.sand == b.sand and a.bubble == b.bubble, "same seed, same board")
	for i in 12:
		if a.state != Match3.PLAYING:
			break
		var h := a.find_hint()
		check(h == b.find_hint(), "same hint")
		a.swap(h[0], h[1])
		b.swap(h[0], h[1])
	check(a.kind == b.kind and a.moves == b.moves and a.fragments_collected == b.fragments_collected, "same moves, same result")
	var lv2 := lv.duplicate()
	lv2["seed"] = 99
	check(Match3.new(lv2).kind != a.kind, "another seed, another board")


func test_three_match() -> void:
	var rows := _rows()
	_put_ch(rows, 0, 5, "0")
	_put_ch(rows, 1, 5, "0")
	_put_ch(rows, 2, 4, "0")
	var m := _model(rows)
	var steps := m.swap(Vector2i(2, 4), Vector2i(2, 5))
	check(steps[0]["type"] == "swap", "a valid swap starts with a swap step")
	var clear := _first(steps, "clear")
	check(not clear.is_empty() and clear["cells"].size() == 3 and Vector2i(0, 5) in clear["cells"] and Vector2i(2, 5) in clear["cells"], "3 in a row clears those 3")
	check(clear.get("combo", 0) == 1, "first wave is combo 1")
	check(not _first(steps, "fall").is_empty(), "tiles fall after a clear")
	check(_no_holes(m), "the board refills with no holes")
	check(m.moves == 9, "a move costs one move")
	check(m._find_groups().is_empty(), "no lines left after the cascade")
	var last := {}
	for s in steps:
		if s.has("grid"):
			last = s["grid"]
	check(last == m.snapshot(), "last step grid matches the board")
	var fall := _first(steps, "fall")
	var ok := true
	for sp in fall["spawns"]:
		if sp["from"].y >= 0 or not m.inside(sp["to"]):
			ok = false
	check(ok, "spawns drop in from above the board")


func test_invalid_swaps() -> void:
	var m := _model(_rows())
	var before := m.kind.duplicate()
	var steps := m.swap(Vector2i(0, 0), Vector2i(1, 0))
	check(steps.size() == 1 and steps[0]["type"] == "bad_swap", "a swap without a line is a bad swap")
	check(m.moves == 10 and m.kind == before, "a bad swap costs nothing and changes nothing")
	steps = m.swap(Vector2i(0, 0), Vector2i(2, 0))
	check(steps[0]["type"] == "bad_swap", "far swaps are bad")
	steps = m.swap(Vector2i(0, 0), Vector2i(-1, 0))
	check(steps[0]["type"] == "bad_swap" and m.moves == 10, "swaps off the board are bad")


func test_rockets() -> void:
	var rows := _rows()
	for x in [0, 1, 3]:
		_put_ch(rows, x, 5, "0")
	_put_ch(rows, 2, 4, "0")
	var m := _model(rows)
	var steps := m.swap(Vector2i(2, 4), Vector2i(2, 5))
	var made := _first(steps, "special_made")
	check(made.get("special") == "rocket_h" and made.get("cell") == Vector2i(2, 5), "4 in a row makes a row rocket where the tile landed")
	check(_first(steps, "clear")["cells"].size() == 4, "the 4 tiles clear")

	rows = _rows()
	for y in [1, 2, 4]:
		_put_ch(rows, 3, y, "0")
	_put_ch(rows, 2, 3, "0")
	m = _model(rows)
	steps = m.swap(Vector2i(2, 3), Vector2i(3, 3))
	made = _first(steps, "special_made")
	check(made.get("special") == "rocket_v" and made.get("cell") == Vector2i(3, 3), "4 in a column makes a column rocket")

	# A rocket swapped with any tile fires along its line.
	rows = _rows()
	m = _model(rows)
	m.put(Vector2i(3, 2), 1, "rocket_h")
	steps = m.swap(Vector2i(3, 2), Vector2i(3, 3))
	var fire := _fires(steps, "rocket_h")
	check(fire.size() == 1 and fire[0]["cell"] == Vector2i(3, 3) and fire[0]["area"].size() == 7, "swapping a rocket fires it across its new row")
	check(m.moves == 9, "firing a rocket costs a move")
	m = _model(_rows())
	m.put(Vector2i(4, 4), 2, "rocket_v")
	steps = m.activate(Vector2i(4, 4))
	check(_fires(steps, "rocket_v").size() == 1 and _fires(steps, "rocket_v")[0]["area"].size() == 8, "tapping a rocket fires it down its column")
	check(m.moves == 9 and _no_holes(m), "activate costs a move and refills")


func test_bomb() -> void:
	var rows := _rows()
	_put_ch(rows, 0, 5, "0")
	_put_ch(rows, 1, 5, "0")
	_put_ch(rows, 2, 3, "0")
	_put_ch(rows, 2, 4, "0")
	_put_ch(rows, 3, 5, "0")
	var m := _model(rows)
	var steps := m.swap(Vector2i(3, 5), Vector2i(2, 5))
	var made := _first(steps, "special_made")
	check(made.get("special") == "bomb" and made.get("cell") == Vector2i(2, 5), "an L shape makes a bomb at the corner")
	check(_first(steps, "clear")["cells"].size() == 5, "the L's 5 tiles clear")
	m = _model(_rows())
	m.put(Vector2i(3, 3), 1, "bomb")
	steps = m.activate(Vector2i(3, 3))
	var fire := _fires(steps, "bomb")
	check(fire.size() == 1 and fire[0]["area"].size() == 9, "a bomb blasts 3x3")
	m = _model(_rows())
	m.put(Vector2i(0, 0), 1, "bomb")
	steps = m.activate(Vector2i(0, 0))
	check(_fires(steps, "bomb")[0]["area"].size() == 4, "a corner bomb stays on the board")


func test_rainbow() -> void:
	var rows := _rows()
	for x in [0, 1, 3, 4]:
		_put_ch(rows, x, 5, "0")
	_put_ch(rows, 2, 4, "0")
	var m := _model(rows)
	var steps := m.swap(Vector2i(2, 4), Vector2i(2, 5))
	var made := _first(steps, "special_made")
	check(made.get("special") == "rainbow" and made.get("cell") == Vector2i(2, 5), "5 in a row makes a rainbow")
	check(m.special_at(Vector2i(2, 5)) == "rainbow" and m.kind_at(Vector2i(2, 5)) == Match3.SPECIAL_KIND, "the rainbow sits on the board, colorless")

	m = _model(_rows())
	m.put(Vector2i(3, 3), 0, "rainbow")
	var target := m.kind_at(Vector2i(4, 3))
	var before := _count_kind(m.snapshot(), target)
	steps = m.swap(Vector2i(3, 3), Vector2i(4, 3))
	var fire := _fires(steps, "rainbow")
	check(fire.size() == 1 and fire[0]["targets"].size() == before, "rainbow + tile targets every tile of that kind (%d)" % before)
	check(fire.size() == 1 and _count_kind(fire[0]["grid"], target) == 0, "and clears them all")
	check(m.moves == 9, "a rainbow swap costs one move")


func test_combos() -> void:
	var m := _model(_rows())
	m.put(Vector2i(3, 2), 1, "rocket_h")
	m.put(Vector2i(4, 2), 2, "rocket_v")
	var steps := m.swap(Vector2i(3, 2), Vector2i(4, 2))
	var f := _fires(steps, "cross")
	check(f.size() == 1 and f[0]["cell"] == Vector2i(4, 2) and f[0]["area"].size() == 7 + 8 - 1, "rocket + rocket fires a cross")
	check(_fires(steps, "rocket_h").is_empty() and _fires(steps, "rocket_v").is_empty(), "the two rockets merge instead of firing alone")

	m = _model(_rows())
	m.put(Vector2i(3, 3), 1, "bomb")
	m.put(Vector2i(3, 4), 2, "bomb")
	steps = m.swap(Vector2i(3, 3), Vector2i(3, 4))
	f = _fires(steps, "bomb5")
	check(f.size() == 1 and f[0]["area"].size() == 25, "bomb + bomb blasts 5x5")

	m = _model(_rows())
	m.put(Vector2i(3, 3), 1, "rocket_v")
	m.put(Vector2i(4, 3), 2, "bomb")
	steps = m.swap(Vector2i(3, 3), Vector2i(4, 3))
	f = _fires(steps, "cross3")
	check(f.size() == 1 and f[0]["area"].size() == 3 * 7 + 3 * 8 - 9, "rocket + bomb fires a 3-wide cross")

	m = _model(_rows())
	m.put(Vector2i(3, 3), 0, "rainbow")
	m.put(Vector2i(3, 4), 0, "rainbow")
	steps = m.swap(Vector2i(3, 3), Vector2i(3, 4))
	f = _fires(steps, "board")
	var empty := f.size() == 1
	if empty:
		for k in f[0]["grid"]["kind"]:
			if k >= 0:
				empty = false
	check(empty, "rainbow + rainbow clears the whole board")

	m = _model(_rows())
	m.put(Vector2i(3, 3), 0, "rainbow")
	m.put(Vector2i(4, 3), 2, "rocket_h")
	var twos := _count_kind(m.snapshot(), m._most_common_kind())
	steps = m.swap(Vector2i(3, 3), Vector2i(4, 3))
	f = _fires(steps, "rainbow")
	check(f.size() == 1 and f[0].get("convert", "").begins_with("rocket"), "rainbow + rocket turns a kind into rockets")
	var rockets := _fires(steps, "rocket_h").size() + _fires(steps, "rocket_v").size()
	check(rockets >= twos - 2, "and they all fire (%d of %d)" % [rockets, twos])
	check(_no_holes(m), "board refills after a big combo")


func test_specials_never_match() -> void:
	var m := _model(_rows())
	m.put(Vector2i(1, 2), 0, "rocket_h")
	m.put(Vector2i(2, 2), 0, "bomb")
	m.put(Vector2i(3, 2), 0, "rocket_v")
	check(m._find_groups().is_empty(), "specials in a row never make a line")


func test_chain() -> void:
	var m := _model(_rows())
	m.put(Vector2i(0, 2), 1, "rocket_h")
	m.put(Vector2i(5, 3), 2, "bomb")
	m.put(Vector2i(4, 4), 3, "rocket_v")
	var steps := m.swap(Vector2i(0, 2), Vector2i(0, 3))
	var order := []
	for s in steps:
		if s["type"] == "special_fire":
			order.append(s["special"])
	check(order.size() >= 3 and order[0] == "rocket_h" and order[1] == "bomb" and order[2] == "rocket_v", "specials fire in a chain: %s" % [order])


func test_sand() -> void:
	var rows := _rows()
	_put_ch(rows, 3, 7, "S")
	_put_ch(rows, 2, 6, "0")
	_put_ch(rows, 4, 6, "0")
	_put_ch(rows, 3, 5, "0")
	var m := _model(rows)
	check(m.swap(Vector2i(3, 7), Vector2i(2, 7))[0]["type"] == "bad_swap", "sand can't be swapped")
	var steps := m.swap(Vector2i(3, 5), Vector2i(3, 6))
	var hit := _first(steps, "blocker_hit")
	check(not hit.is_empty() and hit["hits"][0]["blocker"] == "sand" and hit["hits"][0]["cell"] == Vector2i(3, 7) and hit["hits"][0]["left"] == 0, "a match next to sand clears it")
	check(m.kind_at(Vector2i(3, 7)) != Match3.SAND and _no_holes(m), "the sand cell refills")

	rows = _rows()
	_put_ch(rows, 3, 6, "T")
	_put_ch(rows, 1, 7, "0")
	_put_ch(rows, 2, 7, "0")
	_put_ch(rows, 4, 7, "0")
	m = _model(rows)
	steps = m.swap(Vector2i(4, 7), Vector2i(3, 7))
	hit = _first(steps, "blocker_hit")
	check(not hit.is_empty() and hit["hits"][0]["left"] == 1, "two-layer sand loses one layer per match")
	var fell := false
	for mv in _first(steps, "fall")["moves"]:
		if mv["from"] == Vector2i(3, 6) and mv["to"] == Vector2i(3, 7):
			fell = true
	check(fell, "sand falls into the cleared cell below")

	m = _model(_rows())
	m.kind[m.idx(Vector2i(3, 3))] = Match3.SAND
	m.sand[m.idx(Vector2i(3, 3))] = 2
	m.put(Vector2i(3, 5), 1, "rocket_v")
	steps = m.activate(Vector2i(3, 5))
	var fire := _fires(steps, "rocket_v")
	check(fire.size() == 1 and fire[0]["grid"]["sand"][m.idx(Vector2i(3, 3))] == 1, "a rocket takes one sand layer")


func test_bubbles() -> void:
	var rows := _rows()
	_put_ch(rows, 3, 3, "b")
	var m := _model(rows)
	check(m.swap(Vector2i(3, 3), Vector2i(3, 4))[0]["type"] == "bad_swap" and m.moves == 10, "a bubbled tile can't be swapped")

	rows = _rows()
	_put_ch(rows, 0, 5, "0")
	_put_ch(rows, 1, 5, "a")
	_put_ch(rows, 2, 4, "0")
	m = _model(rows)
	var steps := m.swap(Vector2i(2, 4), Vector2i(2, 5))
	var clear := _first(steps, "clear")
	check(clear["cells"].size() == 2 and not Vector2i(1, 5) in clear["cells"], "a bubbled tile in a line stays")
	var hit := _first(steps, "blocker_hit")
	check(not hit.is_empty() and hit["hits"][0]["blocker"] == "bubble" and hit["hits"][0]["cell"] == Vector2i(1, 5), "and its bubble pops")
	check(clear["grid"]["kind"][m.idx(Vector2i(1, 5))] == 0 and clear["grid"]["bubble"][m.idx(Vector2i(1, 5))] == 0, "leaving a free tile")

	rows = _rows()
	_put_ch(rows, 0, 5, "0")
	_put_ch(rows, 1, 5, "0")
	_put_ch(rows, 2, 4, "0")
	_put_ch(rows, 1, 4, "c")
	m = _model(rows)
	steps = m.swap(Vector2i(2, 4), Vector2i(2, 5))
	hit = _first(steps, "blocker_hit")
	check(not hit.is_empty() and hit["hits"][0]["cell"] == Vector2i(1, 4), "a match next to a bubble pops it")

	m = _model(_rows())
	m.bubble[m.idx(Vector2i(5, 2))] = 1
	var k := m.kind_at(Vector2i(5, 2))
	m.put(Vector2i(1, 2), 1, "rocket_h")
	steps = m.activate(Vector2i(1, 2))
	var f: Dictionary = _fires(steps, "rocket_h")[0]
	check(f["grid"]["bubble"][m.idx(Vector2i(5, 2))] == 0 and f["grid"]["kind"][m.idx(Vector2i(5, 2))] == k, "a rocket pops a bubble and spares its tile")


func test_fragments() -> void:
	var rows := _rows()
	_put_ch(rows, 3, 4, "F")
	_put_ch(rows, 3, 5, "0")
	_put_ch(rows, 3, 6, "0")
	_put_ch(rows, 2, 7, "0")
	var m := _model(rows)
	var steps := m.swap(Vector2i(2, 7), Vector2i(3, 7))
	var got := _first(steps, "fragment_collected")
	check(not got.is_empty() and got["cell"] == Vector2i(3, 7), "a fragment that falls to the bottom row is collected")
	check(m.fragments_collected == 1 and m.state == Match3.WON, "collecting the last fragment wins")
	check(_no_holes(m), "no hole where the fragment left")

	rows = _rows()
	_put_ch(rows, 1, 2, "F")
	_put_ch(rows, 2, 2, "F")
	_put_ch(rows, 3, 2, "F")
	m = _model(rows, 10, 3)
	check(m._find_groups().is_empty(), "fragments never make a line")
	check(m.swap(Vector2i(1, 2), Vector2i(2, 2))[0]["type"] == "bad_swap", "swapping two fragments does nothing")

	m = _model(_rows())
	m.kind[m.idx(Vector2i(5, 3))] = Match3.FRAGMENT
	m.kind[m.idx(Vector2i(2, 2))] = Match3.FRAGMENT
	m.put(Vector2i(1, 3), 1, "rocket_h")
	m.put(Vector2i(3, 3), 2, "bomb")
	steps = m.activate(Vector2i(1, 3))
	var survived := true
	for s in steps:
		if s["type"] == "special_fire" and _count_kind(s["grid"], Match3.FRAGMENT) + m.fragments_collected < 2:
			survived = false
	check(survived and _fires(steps, "bomb").size() == 1, "rockets and bombs never destroy fragments")

	m = _model(_rows())
	m.kind[m.idx(Vector2i(4, 3))] = Match3.FRAGMENT
	m.put(Vector2i(3, 3), 0, "rainbow")
	check(m.swap(Vector2i(3, 3), Vector2i(4, 3))[0]["type"] == "bad_swap", "a rainbow can't eat a fragment")

	# Later fragments drop in from the top.
	var lv := {"kinds": 4, "fragments": 3, "fragments_at_start": 1, "moves": 200, "seed": 3, "assist": 0.3}
	m = Match3.new(lv)
	var seen_drop := false
	for i in 200:
		if m.state != Match3.PLAYING:
			break
		var h := m.find_hint()
		m.swap(h[0], h[1])
		if m.fragments_spawned > 1:
			seen_drop = true
		if m.fragments_on_board() > 1:
			check(false, "no more fragments on the board than allowed")
	check(seen_drop and m.state == Match3.WON, "later fragments drop in and all get collected")


func test_win_lose() -> void:
	var rows := _rows()
	_put_ch(rows, 0, 0, "F")
	_put_ch(rows, 6, 5, "0")
	_put_ch(rows, 6, 6, "0")
	_put_ch(rows, 5, 7, "0")
	var m := _model(rows, 1)
	m.swap(Vector2i(5, 7), Vector2i(6, 7))
	check(m.moves == 0 and m.state == Match3.LOST, "out of moves without the fragment loses")
	check(m.swap(Vector2i(0, 1), Vector2i(1, 1))[0]["type"] == "bad_swap", "no swaps after losing")
	m.add_moves(5)
	check(m.state == Match3.PLAYING and m.moves == 5, "+5 moves continues the level")
	check(m.has_valid_move(), "and there is a move to make")


func test_levels() -> void:
	var prev := {}
	var ok := true
	for n in range(1, 200):
		var lv := PuzzleLevels.level(n)
		if lv["kinds"] < 4 or lv["kinds"] > 6 or lv["fragments"] < 1 or lv["fragments"] > 4 or lv["moves"] < 10:
			ok = false
		if n < 4 and (lv["sand"] > 0 or lv["bubbles"] > 0):
			ok = false
		if n < 8 and lv["bubbles"] > 0:
			ok = false
		if String(lv["artifact"]) == "":
			ok = false
	check(ok, "level params stay in range and blockers come in gradually")
	check(PuzzleLevels.level(1)["fragments"] == 1 and PuzzleLevels.level(1)["kinds"] == 4, "level 1 is the easiest")
	check(PuzzleLevels.level(4)["sand"] > 0 and PuzzleLevels.level(8)["bubbles"] > 0, "sand from 4, bubbles from 8")
	check(PuzzleLevels.level(3)["artifact"] != PuzzleLevels.level(4)["artifact"], "artifacts cycle")
	check(PuzzleLevels.level(12) == PuzzleLevels.level(12), "levels are reproducible")


## Plays ~200 levels with the hint (and some random and bad moves),
## checking the board after every move.
func test_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var games := 200
	var won := 0
	var problems := {}
	var total_moves := 0
	for g in games:
		var lv := PuzzleLevels.level(1 + g % 60)
		lv["seed"] = 1000 + g * 31
		var m := Match3.new(lv)
		var extra_used := false
		var guard := 0
		while guard < 400:
			guard += 1
			if m.state == Match3.LOST and not extra_used:
				extra_used = true
				m.add_moves(5)
			if m.state != Match3.PLAYING:
				break
			var mv := m.find_hint()
			if mv.is_empty():
				problems["no hint while playing"] = true
				break
			if rng.randf() < 0.15:
				# A random neighbour swap (often bad: must cost nothing).
				var a := Vector2i(rng.randi_range(0, m.width - 1), rng.randi_range(0, m.height - 1))
				mv = [a, a + [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][rng.randi_range(0, 2)]]
			var moves_before := m.moves
			var steps := m.swap(mv[0], mv[1])
			total_moves += 1
			if steps[0]["type"] == "bad_swap":
				if m.moves != moves_before:
					problems["bad swap cost a move"] = true
				continue
			_check_board(m, steps, problems)
		if m.state == Match3.PLAYING:
			problems["game did not end"] = true
		if m.state == Match3.WON:
			won += 1
	for p in problems:
		check(false, "fuzz: " + p)
	check(problems.is_empty(), "fuzz: %d games, %d swaps, invariants hold" % [games, total_moves])
	print("fuzz: won %d of %d games (hint bot, one +5)" % [won, games])
	check(won >= games * 0.8, "the hint bot wins most games (%d/%d)" % [won, games])


func _check_board(m: Match3, steps: Array, problems: Dictionary) -> void:
	var n := m.width * m.height
	if m.kind.size() != n or m.special.size() != n:
		problems["board size changed"] = true
	if m.moves < 0:
		problems["negative moves"] = true
	for i in n:
		var k := m.kind[i]
		if k == Match3.EMPTY:
			problems["hole after settle"] = true
		if k >= m.kinds or k < Match3.SPECIAL_KIND:
			problems["bad kind %d" % k] = true
		if (k == Match3.SAND) != (m.sand[i] > 0):
			problems["sand layers out of sync"] = true
		if m.bubble[i] > 0 and k < 0:
			problems["bubble without a tile"] = true
		if (k == Match3.SPECIAL_KIND) != (m.special[i] != Match3.NONE):
			problems["special kind out of sync"] = true
	for x in m.width:
		if m.kind_at(Vector2i(x, m.height - 1)) == Match3.FRAGMENT:
			problems["fragment left in the bottom row"] = true
	if not m._find_groups().is_empty():
		problems["lines left on a settled board"] = true
	if m.state == Match3.PLAYING and not m.has_valid_move():
		problems["no valid move while playing"] = true
	if m.fragments_collected > m.fragments_needed or m.fragments_spawned > m.fragments_needed:
		problems["too many fragments"] = true
	var last := {}
	for s in steps:
		if s.has("grid"):
			last = s["grid"]
		if s["type"] == "fall":
			for mv in s["moves"]:
				if not m.inside(mv["from"]) or not m.inside(mv["to"]) or mv["to"].y <= mv["from"].y:
					problems["bad fall move"] = true
		for key in ["cells", "area"]:
			for c in s.get(key, []):
				if not m.inside(c):
					problems["step cell outside the grid"] = true
	if last != m.snapshot():
		problems["last grid differs from the board"] = true
