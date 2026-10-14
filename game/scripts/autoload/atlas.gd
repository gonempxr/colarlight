extends Node
## The Atlas of the Deep (Top League endgame, docs/league-saga.md): a map
## of nodes under the Murk. A node is run with a sea chart of its tier as a
## "dive": a short roguelike descent through chambers. The crew carries
## oxygen; every chamber costs some, monsters and currents cost more. Fights
## are timing taps (the UI decides hit or miss, this keeps the score).
## Out of oxygen = the crew surfaces with half the loot and the chart is
## lost. A finished dive pays coins (minutes of income, so it moves the
## league board), pearls, shards, runes and a new chart, and clears the
## node: the Murk lifts from its neighbours.
##
## Saved per profile (Profiles.file("atlas.json")); only shown in a league
## game (`available()`). Everything is earned, nothing is sold. Dives are
## seeded, so tests and the same chart give the same chambers.

signal changed
## A dive started / moved on / ended (the dive screen listens).
signal dive_changed

const SAVE_VERSION := 1

## Act I "The Twilight Zone": pos in 0..1 of the map, tier = chart needed,
## links = neighbours (both ways). The citadel ends the act.
const NODES := {
	"a1": {"pos": Vector2(0.50, 0.92), "tier": 1, "links": ["a2", "a3"]},
	"a2": {"pos": Vector2(0.27, 0.80), "tier": 1, "links": ["a1", "a4"]},
	"a3": {"pos": Vector2(0.74, 0.79), "tier": 1, "links": ["a1", "a5"]},
	"a4": {"pos": Vector2(0.16, 0.64), "tier": 2, "links": ["a2", "a6", "a7"]},
	"a5": {"pos": Vector2(0.84, 0.63), "tier": 2, "links": ["a3", "a7", "a8"]},
	"a6": {"pos": Vector2(0.24, 0.47), "tier": 3, "links": ["a4", "a9"]},
	"a7": {"pos": Vector2(0.52, 0.58), "tier": 3, "links": ["a4", "a5", "a9", "a10"]},
	"a8": {"pos": Vector2(0.80, 0.45), "tier": 3, "links": ["a5", "a10"]},
	"a9": {"pos": Vector2(0.36, 0.32), "tier": 4, "links": ["a6", "a7", "a11"]},
	"a10": {"pos": Vector2(0.68, 0.31), "tier": 4, "links": ["a7", "a8", "a12"]},
	"a11": {"pos": Vector2(0.26, 0.17), "tier": 5, "links": ["a9", "boss1"]},
	"a12": {"pos": Vector2(0.76, 0.16), "tier": 5, "links": ["a10", "boss1"]},
	"boss1": {"pos": Vector2(0.51, 0.07), "tier": 6, "links": ["a11", "a12"], "citadel": true},
}
const START_NODE := "a1"
const MAX_TIER := 6

## Chamber kinds a layer offers (the citadel and the last layer: the boss).
const KINDS := ["treasure", "monster", "current", "air", "mystery"]
const KIND_WEIGHT := {"treasure": 3, "monster": 4, "current": 2, "air": 2, "mystery": 2}
const LAYERS := 4
const CITADEL_LAYERS := 5

## Risk for reward, set before a dive (at most `rune_slots(tier)`).
const RUNES := {
	"dark": {"hp": 1.3, "loot": 1.4},
	"current": {"o2": 1.25, "loot": 1.3},
	"sharks": {"monsters": 2, "chart_up": 0.25},
	"greed": {"no_air": true, "shards": 1.6},
}

## Wanted monsters: each week every player has the same ones on the same
## nodes (seeded by the week); beating one in its dive pays extra.
const BOUNTIES := ["crabblack", "mother_jelly", "shadow_eel"]

## Crew gear bought with shards: tank = more oxygen, harpoon = stronger
## hits, lamp = cheaper chambers.
const CREW := ["tank", "harpoon", "lamp"]
const CREW_MAX := 10

var save_path := "user://atlas.json"
var autosave_enabled := true

var cleared := {}
## tier (String) -> count. Tier 1 charts are free and endless.
var charts := {}
var runes := {}
var shards := 0
var crew := {"tank": 0, "harpoon": 0, "lamp": 0}
## week id -> [bounty ids beaten]
var bounties_done := {}
var stats := {}
## The running dive ({} when none).
var dive := {}


func _ready() -> void:
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("atlas.json")
	load_game()


func switch_profile() -> void:
	save_path = Profiles.file("atlas.json")
	load_game()
	changed.emit()


## The Atlas is the Top League's: shown in league games only.
func available() -> bool:
	return Profiles.league_game()


func reset() -> void:
	cleared = {}
	charts = {}
	runes = {}
	shards = 0
	crew = {"tank": 0, "harpoon": 0, "lamp": 0}
	bounties_done = {}
	stats = {}
	dive = {}


# --- Map ------------------------------------------------------------------------------

## "cleared", "open" (a neighbour is cleared, or the start) or "fog".
func node_state(id: String) -> String:
	if cleared.has(id):
		return "cleared"
	if id == START_NODE:
		return "open"
	for n in NODES[id]["links"]:
		if cleared.has(n):
			return "open"
	return "fog"


func chart_count(tier: int) -> int:
	if tier <= 1:
		return 999
	return int(charts.get(str(tier), 0))


func can_start(id: String) -> bool:
	return dive.is_empty() and NODES.has(id) and node_state(id) != "fog" and chart_count(int(NODES[id]["tier"])) > 0


static func rune_slots(tier: int) -> int:
	return 1 if tier <= 3 else 2


func act_done() -> bool:
	return cleared.has("boss1")


# --- Crew -----------------------------------------------------------------------------

func crew_cost(kind: String) -> int:
	var lv := int(crew.get(kind, 0))
	return 0 if lv >= CREW_MAX else 20 + lv * lv * 15


func upgrade_crew(kind: String) -> bool:
	var cost := crew_cost(kind)
	if not kind in CREW or cost <= 0 or shards < cost:
		return false
	shards -= cost
	crew[kind] = int(crew.get(kind, 0)) + 1
	_changed()
	return true


func max_oxygen() -> float:
	return 100.0 + 12.0 * int(crew["tank"])


## Damage of one good hit (monster hp counts hits of 1).
func hit_power() -> float:
	return 1.0 + 0.2 * int(crew["harpoon"])


# --- Bounties -------------------------------------------------------------------------

## This week's wanted monsters: {bounty id: node id}, the same for everyone.
func week_bounties(week: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bounty%d" % week)
	var ids := NODES.keys().filter(func(n): return n != START_NODE and not NODES[n].get("citadel", false))
	var out := {}
	for b in BOUNTIES:
		var at: String = ids[rng.randi() % ids.size()]
		ids.erase(at)
		out[b] = at
	return out


func bounty_at(id: String, week: int) -> String:
	var wb := week_bounties(week)
	for b in wb:
		if wb[b] == id and not b in bounties_done.get(str(week), []):
			return b
	return ""


# --- Dive -----------------------------------------------------------------------------

## Starts a dive on node `id` with `chosen` runes (a chart is used up).
## `seed` makes it repeatable (tests); `week` places the bounties.
func start_dive(id: String, chosen: Array = [], seed: int = -1, week: int = -1) -> bool:
	if not can_start(id):
		return false
	var tier := int(NODES[id]["tier"])
	var rs: Array = []
	for r in chosen:
		if RUNES.has(r) and int(runes.get(r, 0)) > 0 and not r in rs and rs.size() < rune_slots(tier):
			rs.append(r)
	for r in rs:
		runes[r] = int(runes[r]) - 1
	if tier > 1:
		charts[str(tier)] = chart_count(tier) - 1
	var wk := week if week >= 0 else OnlineRules.week_id(Clock.now())
	var sd := seed if seed >= 0 else randi()
	var citadel: bool = NODES[id].get("citadel", false)
	dive = {"node": id, "tier": tier, "runes": rs, "seed": sd, "layer": 0,
		"layers": CITADEL_LAYERS if citadel else LAYERS, "o2": max_oxygen(),
		"loot": {"minutes": 0.0, "pearls": 0, "shards": 0}, "bounty": bounty_at(id, wk),
		"week": wk, "fight": {}, "log": [], "done": ""}
	dive["options"] = _roll_options()
	stats["dives"] = int(stats.get("dives", 0)) + 1
	_changed()
	dive_changed.emit()
	return true


func _mod(key: String, base: float = 1.0) -> float:
	var v := base
	for r in dive.get("runes", []):
		v *= float(RUNES[r].get(key, 1.0))
	return v


func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [int(dive["seed"]), int(dive["layer"]), salt])
	return rng


func is_boss_layer() -> bool:
	return int(dive.get("layer", 0)) >= int(dive.get("layers", LAYERS))


## The chamber kinds offered on the current layer.
func _roll_options() -> Array:
	if is_boss_layer():
		return ["boss"]
	var rng := _rng(1)
	var weights := KIND_WEIGHT.duplicate()
	for r in dive["runes"]:
		if RUNES[r].get("no_air", false):
			weights.erase("air")
		weights["monster"] = int(weights["monster"]) + int(RUNES[r].get("monsters", 0))
	var total := 0
	for k in weights:
		total += int(weights[k])
	var n := 3 if int(dive["layer"]) % 2 == 0 else 2
	var out := []
	var tries := 0
	while out.size() < n and tries < 40:
		tries += 1
		var roll := rng.randi() % total
		for k in weights:
			roll -= int(weights[k])
			if roll < 0:
				if not k in out:
					out.append(k)
				break
	# The bounty waits in the last chamber before the boss.
	if dive["bounty"] != "" and int(dive["layer"]) == int(dive["layers"]) - 1:
		out[0] = "bounty"
	return out


## Oxygen a chamber costs on entry.
func chamber_cost() -> float:
	var tier := int(dive["tier"])
	var lamp := maxf(0.6, 1.0 - 0.04 * int(crew["lamp"]))
	return (9.0 + 2.0 * tier) * lamp * _mod("o2")


## How many good hits a foe takes.
func foe_hits(kind: String) -> int:
	var tier := int(dive["tier"])
	var hp := 4.0 + 1.5 * tier
	match kind:
		"bounty":
			hp = 8.0 + tier * 2.5
		"boss":
			hp = (14.0 if dive.get("layers") == CITADEL_LAYERS else 10.0) + tier * 3.0
	return maxi(2, ceili(hp * _mod("hp") / hit_power()))


## Oxygen lost for a missed tap.
func miss_cost() -> float:
	return (8.0 + 1.5 * int(dive["tier"])) * _mod("o2")


## The window of a good tap in the fight, 0..1 of the ring's run (smaller
## for higher tiers and the boss; the UI turns it into time).
func tap_window() -> float:
	var w := 0.30 - 0.02 * int(dive["tier"])
	if dive.get("fight", {}).get("kind", "") in ["boss", "bounty"]:
		w -= 0.04
	return clampf(w, 0.12, 0.3)


## Enters chamber `i` of the offer. Returns what happened:
## {"kind", "o2": change, "fight": bool, "loot": {...}}.
func choose(i: int) -> Dictionary:
	if dive.is_empty() or dive["done"] != "" or not dive["fight"].is_empty():
		return {}
	var opts: Array = dive["options"]
	if i < 0 or i >= opts.size():
		return {}
	var kind: String = opts[i]
	var rng := _rng(10 + i)
	var tier := int(dive["tier"])
	var out := {"kind": kind, "o2": -chamber_cost(), "fight": false, "loot": {}}
	if kind == "mystery":
		kind = ["treasure", "air", "current", "monster"][rng.randi() % 4]
		out["became"] = kind
	match kind:
		"treasure":
			out["loot"] = {"minutes": (1.5 + 0.5 * tier) * _mod("loot"), "pearls": 2 + tier, "shards": roundi((4 + tier) * _mod("shards"))}
		"air":
			out["o2"] = 20.0
		"current":
			out["o2"] -= (12.0 + 2.5 * tier) * _mod("o2")
		"monster", "bounty", "boss":
			out["fight"] = true
	_add_o2(float(out["o2"]))
	_add_loot(out["loot"])
	dive["log"].append(kind)
	if float(dive["o2"]) <= 0.0:
		_end("fail")
	elif out["fight"]:
		dive["fight"] = {"kind": kind, "left": foe_hits(kind), "hits": foe_hits(kind), "misses": 0}
	else:
		_next_layer()
	_changed()
	dive_changed.emit()
	return out


## A good tap in the fight. True when the foe is beaten.
func fight_hit() -> bool:
	var f: Dictionary = dive.get("fight", {})
	if f.is_empty() or dive["done"] != "":
		return false
	f["left"] = int(f["left"]) - 1
	if int(f["left"]) > 0:
		dive_changed.emit()
		return false
	_win_fight(f)
	return true


## A missed tap: oxygen goes. True when the crew is out of air.
func fight_miss() -> bool:
	var f: Dictionary = dive.get("fight", {})
	if f.is_empty() or dive["done"] != "":
		return false
	f["misses"] = int(f["misses"]) + 1
	_add_o2(-miss_cost())
	if float(dive["o2"]) <= 0.0:
		_end("fail")
		_changed()
		dive_changed.emit()
		return true
	dive_changed.emit()
	return false


func _win_fight(f: Dictionary) -> void:
	var tier := int(dive["tier"])
	var kind: String = f["kind"]
	var loot := {"minutes": (1.0 + 0.4 * tier) * _mod("loot"), "pearls": 1 + tier / 2, "shards": roundi((3 + tier) * _mod("shards"))}
	if kind == "bounty":
		loot = {"minutes": (4.0 + tier) * _mod("loot"), "pearls": 25 + 5 * tier, "shards": roundi((20 + 4 * tier) * _mod("shards"))}
		var wk := str(dive["week"])
		var done: Array = bounties_done.get(wk, [])
		if not dive["bounty"] in done:
			done.append(dive["bounty"])
		bounties_done[wk] = done
		stats["bounties"] = int(stats.get("bounties", 0)) + 1
	elif kind == "boss":
		loot = {"minutes": (6.0 + 2.0 * tier) * _mod("loot"), "pearls": 8 + 3 * tier, "shards": roundi((12 + 3 * tier) * _mod("shards"))}
	_add_loot(loot)
	dive["fight"] = {}
	if kind == "boss":
		_end("win")
	else:
		_next_layer()
	_changed()
	dive_changed.emit()


func _next_layer() -> void:
	dive["layer"] = int(dive["layer"]) + 1
	dive["options"] = _roll_options()


func _add_o2(d: float) -> void:
	dive["o2"] = clampf(float(dive["o2"]) + d, 0.0, max_oxygen())


func _add_loot(l: Dictionary) -> void:
	for k in l:
		dive["loot"][k] = dive["loot"][k] + l[k]


func _end(how: String) -> void:
	dive["done"] = how
	dive["fight"] = {}


## Closes a finished (or given up) dive and pays it: everything on a win,
## half on a fail. Returns {"result", "coins", "pearls", "shards", "chart", "rune"}.
func collect(income_per_sec: float = -1.0) -> Dictionary:
	if dive.is_empty():
		return {}
	if dive["done"] == "":
		_end("fail")
	var win: bool = dive["done"] == "win"
	var k := 1.0 if win else 0.5
	var rate := income_per_sec if income_per_sec >= 0.0 else GameState.income_rate()
	var l: Dictionary = dive["loot"]
	var out := {"result": dive["done"], "coins": maxf(0.0, rate) * 60.0 * float(l["minutes"]) * k,
		"pearls": floori(int(l["pearls"]) * k), "shards": floori(int(l["shards"]) * k), "chart": 0, "rune": ""}
	if win:
		var tier := int(dive["tier"])
		var rng := _rng(99)
		var up := 0.4
		for r in dive["runes"]:
			up += float(RUNES[r].get("chart_up", 0.0))
		var got := mini(MAX_TIER, tier + (1 if rng.randf() < up else 0))
		if got > 1:
			charts[str(got)] = chart_count(got) + 1
		out["chart"] = got
		if rng.randf() < 0.35 + 0.05 * tier:
			var r: String = RUNES.keys()[rng.randi() % RUNES.size()]
			runes[r] = int(runes.get(r, 0)) + 1
			out["rune"] = r
		cleared[dive["node"]] = true
		stats["wins"] = int(stats.get("wins", 0)) + 1
		stats["best_tier"] = maxi(int(stats.get("best_tier", 0)), tier)
	shards += int(out["shards"])
	if int(out["pearls"]) > 0 and has_node("/root/Progress"):
		Progress.add_pearls(int(out["pearls"]))
	if float(out["coins"]) > 0.0 and has_node("/root/GameState"):
		GameState.add_coins(float(out["coins"]))
	dive = {}
	_changed()
	dive_changed.emit()
	return out


# --- Save -----------------------------------------------------------------------------

func _changed() -> void:
	changed.emit()
	if autosave_enabled:
		save_game()


func save_game() -> void:
	var d := {"version": SAVE_VERSION, "cleared": cleared, "charts": charts, "runes": runes, "shards": shards,
		"crew": crew, "bounties_done": bounties_done, "stats": stats, "dive": dive}
	var f := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
	DirAccess.rename_absolute(save_path + ".tmp", save_path)


func load_game() -> void:
	reset()
	if not FileAccess.file_exists(save_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary:
		return
	if d.get("cleared") is Dictionary:
		for k in d["cleared"]:
			if NODES.has(str(k)):
				cleared[str(k)] = true
	for pair in [["charts", charts], ["runes", runes]]:
		if d.get(pair[0]) is Dictionary:
			for k in d[pair[0]]:
				var v = d[pair[0]][k]
				var ok: bool = (pair[0] == "runes" and RUNES.has(str(k))) or (pair[0] == "charts" and str(k).is_valid_int() and int(str(k)) in range(2, MAX_TIER + 1))
				if ok and (v is float or v is int):
					pair[1][str(k)] = clampi(int(v), 0, 9999)
	shards = clampi(int(d.get("shards", 0)) if (d.get("shards") is float or d.get("shards") is int) else 0, 0, 99999999)
	if d.get("crew") is Dictionary:
		for k in CREW:
			var v = d["crew"].get(k, 0)
			crew[k] = clampi(int(v), 0, CREW_MAX) if (v is float or v is int) else 0
	if d.get("bounties_done") is Dictionary:
		for wk in d["bounties_done"]:
			if d["bounties_done"][wk] is Array:
				bounties_done[str(wk)] = d["bounties_done"][wk].filter(func(b): return b in BOUNTIES)
	if d.get("stats") is Dictionary:
		stats = d["stats"]
	# A dive left in the middle of a fight (page closed) counts the fight
	# as lost: no free retries by reloading.
	if d.get("dive") is Dictionary and not d["dive"].is_empty() and NODES.has(str(d["dive"].get("node", ""))):
		dive = d["dive"]
		for key in ["layer", "layers", "tier", "seed", "week"]:
			dive[key] = int(dive.get(key, 0))
		if dive.get("fight") is Dictionary and not dive["fight"].is_empty():
			dive["fight"] = {}
			_end("fail")
