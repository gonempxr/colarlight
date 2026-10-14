extends SceneTree
## The Atlas of the Deep (league endgame): map, charts, runes, dives,
## fights, loot, bounties, crew and the save. Also a small balance check:
## how often a careful and a sloppy player get through each tier.

var fails := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


## Plays a dive to the end: picks the chamber a sensible player would
## (air when low, else treasure, else the first), taps with `skill`
## (chance of a good tap). Returns the collected result.
func _play(at: Node, node: String, skill: float, seed: int, rs: Array = []) -> Dictionary:
	if not at.start_dive(node, rs, seed, 1000):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 1
	var guard := 0
	while at.dive["done"] == "" and guard < 500:
		guard += 1
		if not at.dive["fight"].is_empty():
			if rng.randf() < skill:
				at.fight_hit()
			else:
				at.fight_miss()
			continue
		var opts: Array = at.dive["options"]
		var pick := 0
		if float(at.dive["o2"]) < at.max_oxygen() * 0.45 and "air" in opts:
			pick = opts.find("air")
		elif "treasure" in opts:
			pick = opts.find("treasure")
		elif "current" in opts and opts.size() > 1:
			pick = 1 if opts[0] == "current" else 0
		at.choose(pick)
	return at.collect(10.0)


func _initialize() -> void:
	await process_frame
	var at: Node = root.get_node("Atlas")
	var gs: Node = root.get_node("GameState")
	var pr: Node = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	at.autosave_enabled = false
	at.reset()

	# --- The map ----------------------------------------------------------------------------
	_check(at.node_state("a1") == "open" and at.node_state("a2") == "fog" and at.node_state("boss1") == "fog", "only the start is open")
	for id in at.NODES:
		for n in at.NODES[id]["links"]:
			_check(at.NODES.has(n) and id in at.NODES[n]["links"], "link %s-%s goes both ways" % [id, n])
	_check(at.NODES["boss1"].get("citadel", false) and int(at.NODES["boss1"]["tier"]) == at.MAX_TIER, "the citadel ends act I")
	_check(at.chart_count(1) > 100 and at.chart_count(2) == 0, "tier 1 charts are free, others are found")
	_check(at.can_start("a1") and not at.can_start("a2") and not at.can_start("a4"), "start only where open and with a chart")

	# --- A dive -----------------------------------------------------------------------------
	_check(at.start_dive("a1", [], 42, 1000), "a dive starts")
	_check(not at.start_dive("a1", [], 43, 1000), "one dive at a time")
	_check(float(at.dive["o2"]) == at.max_oxygen() and at.dive["options"].size() == 3, "full air, three chambers to pick from")
	var opts1: Array = at.dive["options"].duplicate()
	var d2 = load("res://scripts/autoload/atlas.gd").new()
	d2.autosave_enabled = false
	d2.start_dive("a1", [], 42, 1000)
	_check(d2.dive["options"] == opts1, "the same seed gives the same chambers")
	d2.free()
	var o_before := float(at.dive["o2"])
	var r: Dictionary = at.choose(0)
	_check(not r.is_empty() and (float(at.dive["o2"]) != o_before or r["kind"] == "air"), "a chamber changes the air")
	if r["fight"]:
		var need := int(at.dive["fight"]["left"])
		_check(need >= 2, "a foe takes a few good taps")
		var o1 := float(at.dive["o2"])
		at.fight_miss()
		_check(float(at.dive["o2"]) < o1, "a miss costs air")
		for i in need - 1:
			at.fight_hit()
		_check(not at.fight_hit() or at.dive["fight"].is_empty(), "the last good tap wins")
	_check(at.dive["fight"].is_empty() and int(at.dive["layer"]) == 1, "on to the next layer")
	_check(at.choose(99).is_empty(), "no such chamber")
	at.collect(10.0)
	_check(at.dive.is_empty() and not at.cleared.has("a1"), "given up = not cleared")

	# A careful player clears the start; its neighbours lift from the Murk.
	var res := {}
	for s in range(1, 30):
		res = _play(at, "a1", 1.0, s)
		if res.get("result", "") == "win":
			break
	_check(res.get("result", "") == "win", "a perfect diver wins tier 1")
	_check(at.cleared.has("a1") and at.node_state("a2") == "open" and at.node_state("a3") == "open" and at.node_state("a4") == "fog", "the Murk lifts around a cleared node")
	_check(float(res["coins"]) > 0.0 and int(res["pearls"]) > 0 and int(res["shards"]) > 0 and int(res["chart"]) >= 1, "a win pays coins, pearls, shards and a chart")
	var coins0: float = gs.coins

	# A fail keeps half and loses the chart.
	at.charts["2"] = 1
	at.cleared["a2"] = true
	_check(at.start_dive("a4", [], 5, 1000), "a tier 2 dive with a found chart")
	_check(at.chart_count(2) == 0, "the chart is used up")
	at.dive["loot"] = {"minutes": 4.0, "pearls": 10, "shards": 20}
	at.dive["o2"] = 1.0
	var guard := 0
	while at.dive["done"] == "" and guard < 50:
		guard += 1
		if at.dive["fight"].is_empty():
			var o: Array = at.dive["options"]
			var p := o.find("current")
			at.choose(p if p >= 0 else (o.find("monster") if o.has("monster") else 0))
		else:
			at.fight_miss()
	var lost: Dictionary = at.collect(10.0)
	_check(lost["result"] == "fail" and int(lost["chart"]) == 0 and not at.cleared.has("a4"), "out of air: a fail, no chart, not cleared")
	_check(int(lost["shards"]) >= 10 and int(lost["shards"]) < 30, "a fail keeps half the loot (%d shards)" % int(lost["shards"]))
	_check(gs.coins >= coins0, "the coins go into the game")

	# --- Runes ------------------------------------------------------------------------------
	at.runes = {"dark": 1, "greed": 2}
	_check(at.start_dive("a1", ["dark", "greed", "nope"], 7, 1000), "runes in a dive")
	_check(at.dive["runes"] == ["dark"] and int(at.runes["dark"]) == 0 and int(at.runes["greed"]) == 2, "tier 1 has one rune slot; the rune is used")
	var hp_dark: int = at.foe_hits("monster")
	at.dive["runes"] = []
	_check(hp_dark > at.foe_hits("monster"), "darkness makes foes tougher")
	at.dive["runes"] = ["greed"]
	at.dive["layer"] = 0
	var air_seen := false
	for s in 60:
		at.dive["seed"] = s
		if "air" in at._roll_options():
			air_seen = true
	_check(not air_seen, "greed: no air pockets")
	at.collect(10.0)
	_check(at.rune_slots(3) == 1 and at.rune_slots(4) == 2, "more rune slots on deeper charts")

	# --- Bounties ---------------------------------------------------------------------------
	var wb: Dictionary = at.week_bounties(2000)
	_check(wb.size() == 3 and wb == at.week_bounties(2000), "three wanted monsters, the same for everyone in a week")
	_check(not wb.values().has("a1") and not wb.values().has("boss1"), "never on the start or the citadel")
	var bnode: String = wb["crabblack"]
	at.cleared[bnode] = true
	at.charts[str(at.NODES[bnode]["tier"])] = 5
	_check(at.bounty_at(bnode, 2000) == "crabblack", "the bounty sits on its node")
	at.start_dive(bnode, [], 3, 2000)
	var met := false
	guard = 0
	while at.dive["done"] == "" and guard < 400:
		guard += 1
		if at.dive["fight"].is_empty():
			var o: Array = at.dive["options"]
			if "bounty" in o:
				met = true
			at.choose(max(0, o.find("bounty")) if "bounty" in o else (o.find("air") if "air" in o else 0))
		else:
			at.fight_hit()
	_check(met, "the bounty waits before the boss")
	var bres: Dictionary = at.collect(10.0)
	if bres["result"] == "win":
		_check(at.bounty_at(bnode, 2000) == "" and "crabblack" in at.bounties_done["2000"], "a beaten bounty is gone for the week")
		_check(at.bounty_at(bnode, 2001) == "" or at.week_bounties(2001).values().has(bnode), "a new week brings new ones")

	# --- Crew -------------------------------------------------------------------------------
	at.shards = 0
	_check(not at.upgrade_crew("tank"), "gear costs shards")
	at.shards = 1000
	var o2a: float = at.max_oxygen()
	_check(at.upgrade_crew("tank") and at.max_oxygen() > o2a and at.shards == 1000 - 20, "a bigger tank: more air")
	_check(at.crew_cost("tank") > 20, "each level costs more")
	var hp0: int = 0
	at.start_dive("a1", [], 9, 1000)
	hp0 = at.foe_hits("boss")
	at.crew["harpoon"] = 6
	_check(at.foe_hits("boss") < hp0, "a better harpoon: fewer taps")
	at.collect(10.0)
	at.crew = {"tank": 0, "harpoon": 0, "lamp": 0}

	# --- Save and a closed page in a fight ---------------------------------------------------
	at.save_path = "user://atlas_test.json"
	at.cleared = {"a1": true}
	at.charts = {"3": 2, "99": 5}
	at.runes = {"dark": 1}
	at.shards = 77
	at.start_dive("a1", [], 11, 1000)
	var gd := 0
	while at.dive["fight"].is_empty() and at.dive["done"] == "" and gd < 20:
		gd += 1
		var o: Array = at.dive["options"]
		at.choose(o.find("monster") if "monster" in o else 0)
	var in_fight: bool = not at.dive["fight"].is_empty()
	at.save_game()
	at.load_game()
	_check(at.cleared.has("a1") and at.chart_count(3) == 2 and not at.charts.has("99") and at.shards == 77, "the atlas is saved (bad tiers dropped)")
	if in_fight:
		_check(at.dive["done"] == "fail", "a page closed in a fight: the fight is lost")
	at.collect(10.0)
	DirAccess.remove_absolute("user://atlas_test.json")

	# --- Words ------------------------------------------------------------------------------
	for k in ["ATLAS_TITLE", "ATLAS_DIVE", "ATLAS_O2", "ATLAS_K_TREASURE", "ATLAS_K_MONSTER", "ATLAS_K_CURRENT", "ATLAS_K_AIR", "ATLAS_K_MYSTERY", "ATLAS_K_BOUNTY", "ATLAS_K_BOSS",
			"ATLAS_RUNE_DARK", "ATLAS_RUNE_CURRENT", "ATLAS_RUNE_SHARKS", "ATLAS_RUNE_GREED", "ATLAS_B_CRABBLACK", "ATLAS_B_MOTHER_JELLY", "ATLAS_B_SHADOW_EEL",
			"ATLAS_CREW_TANK", "ATLAS_CREW_HARPOON", "ATLAS_CREW_LAMP", "ATLAS_WIN", "ATLAS_FAIL"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)

	# --- Balance: how often each tier is won (crew grows with the tier) ----------------------
	var lines := []
	for tier in range(1, at.MAX_TIER + 1):
		var node := ""
		for id in at.NODES:
			if int(at.NODES[id]["tier"]) == tier:
				node = id
				break
		var lv := tier - 1
		at.crew = {"tank": lv, "harpoon": lv, "lamp": lv}
		var rates := []
		for skill in [0.9, 0.7]:
			var wins := 0
			for s in 200:
				at.cleared = {}
				for n in at.NODES[node]["links"]:
					at.cleared[n] = true
				at.charts = {str(tier): 1}
				if _play(at, node, skill, 5000 + s).get("result", "") == "win":
					wins += 1
			rates.append(wins / 2.0)
		lines.append("T%d %d%%/%d%%" % [tier, rates[0], rates[1]])
		# Hard but fair: a good player mostly wins, a sloppy one often doesn't.
		_check(rates[0] >= 55.0, "tier %d: a good player (90%% taps) wins often (%d%%)" % [tier, rates[0]])
		_check(rates[1] <= rates[0] and rates[1] < 95.0, "tier %d: sloppy taps are punished (%d%%)" % [tier, rates[1]])
	print("balance (90% / 70% good taps): ", ", ".join(lines))
	at.reset()
	print("test_atlas: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
