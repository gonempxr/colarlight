extends SceneTree
## The saga "The Leviathan's Abyss" (Top League games): a league game plays
## the saga's worlds from a fresh start; the usual game keeps its five.
## Also the mine bosses (MineBoss) once they exist.

var fails := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var pr: Node = root.get_node("Progress")
	var pf: Node = root.get_node("Profiles")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	if pf.league_game():
		pf.leave_league()

	# --- Worlds by mode ---------------------------------------------------------------------
	_check(not Balance.saga and Balance.world_of(0)["id"] == "ocean" and Balance.world_of(4)["id"] == "jungle", "the usual game: ocean .. jungle")
	_check(Balance.last_location() == Balance.LAST_LOCATION and Balance.site_count(0) == 10 and Balance.site_count(4) == 15, "usual last world and site counts")
	_check(Balance.world_of(5)["id"] == "ocean" and Balance.tier_of(5) == 1, "the usual game never reaches the saga by itself")
	var lg := OnlineRules.LEAGUE_STARTS[0]
	var home: String = pf.current_id
	pf.enter_league(lg)
	_check(Balance.saga and gs.world_id() == "twilight" and int(gs.location) == 0, "a league game starts in the Twilight Zone")
	_check(Balance.site_count(0) == 15 and gs.site_count() == 15 and gs.site_id(14) == "coral_light", "fifteen saga sites")
	_check(Balance.tier_of(0) == 0 and Balance.loc_scale(0) == 1.0, "from the first numbers (a fresh start)")
	_check(Balance.last_location() == Balance.SAGA_LAST and Balance.SAGA_LAST == 2 and not gs.is_last_location(), "acts II and III follow act I")
	_check(WorldLook.world_of(0) == "twilight" and MapArt.world_of(0) == "twilight" and MapArt.soon_worlds() == MapArt.SAGA_SOON, "looks and map follow the saga")
	WorldLook.apply(0)
	_check(WorldLook.world == "twilight" and WorldLook.is_water(), "the Twilight Zone is under water (divers swim)")
	_check(WorkerLooks.world_index("twilight") == 5 and 5 in WorkerLooks.WATER_WORLDS, "abyss divers swim")
	for i in 15:
		_check(TranslationServer.translate("SITE_" + gs.site_id(i).to_upper()) != "SITE_" + gs.site_id(i).to_upper(), "name of site %d" % i)
	for k in ["WORLD_TWILIGHT", "MAP_W_TWILIGHT", "GEAR_TWILIGHT_1", "GEAR_TWILIGHT_4", "MAP_W_SUNKEN", "MAP_W_ABYSS"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)
	# --- Fishing in the saga (world 5: arrays used to stop at 5 worlds) ---------------------
	var fs: Node = root.get_node("Fishing")
	_check(fs.rods.size() == Balance.WORLDS.size() and fs.world() == 5, "a rod slot for the saga's world")
	var rod0: int = fs.rod
	fs.rod = 3
	_check(fs.rod == 3 and fs.rods[5] == 3, "the saga's rod levels up on its own")
	fs.rod = rod0
	var scene = load("res://scripts/fishing/fishing_scene.gd").new(5, WorldLook.look_of(0))
	_check(scene.world == 0 and scene.look == WorldLook.look_of(0), "the saga fishes from the ocean's pier in its own colors")
	_check(FishArt.WORLD_HUES.size() == Balance.WORLDS.size(), "fish colors for every world")
	# --- Mine bosses ------------------------------------------------------------------------
	_check(MineBoss.guard("twilight", 3) == "crabblack" and MineBoss.guard("twilight", 14) == "warden" and MineBoss.guard("ocean", 3) == "", "guards of the saga only")
	for k in MineBoss.BOSSES:
		_check(TranslationServer.translate(MineBoss.name_key(k)) != MineBoss.name_key(k), "name of boss %s" % k)
	gs.reset()
	for i in 3:
		gs.levels["d%d" % i] = 10
	_check(gs.next_depth() == "d3" and gs.boss_at("d3") == "crabblack", "Captain Crabblack guards the fourth site")
	gs.coins = gs.unlock_cost("d3") * 10.0
	_check(not gs.open_depth("d3") and not gs.is_open("d3"), "the site can't be opened past its guard")
	var hp: float = gs.boss_hp("d3")
	_check(hp > 0.0 and is_equal_approx(hp, gs.unlock_cost("d3") * float(MineBoss.data("crabblack")["hp"])), "the guard's health follows the gate price")
	var h1: float = gs.boss_hit("d3")
	for k in ["d0", "d1", "d2", "lift", "boat", "plant"]:
		gs.levels[k] = 150
		gs.managers[k] = true
	var h2: float = gs.boss_hit("d3")
	_check(h2 > h1 and is_equal_approx(gs.boss_hit("d3", true), h2 * MineBoss.PERFECT_MULT), "a stronger mine hits harder; a perfect tap twice")
	_check(gs.boss_hit("d3") >= hp * MineBoss.MIN_HIT, "even a weak mine moves the bar")
	_check(MineBoss.combo_mult(1) == 1.0 and MineBoss.combo_mult(10) > 1.0 and MineBoss.combo_mult(1000) == MineBoss.COMBO_MAX, "combos grow, up to a cap")
	# --- The party (RPG classes) ---
	_check(Party.members([]) == ["guardian", "harpooner"] and Party.members(["crabblack", "mother_jelly"]).size() == 4, "heroes join as guards fall")
	_check(Party.level_of(0) == 1 and Party.level_of(Party.XP_STEP) == 2 and Party.level_of(Party.XP_STEP * 3) == 3 and Party.power(3) > Party.power(1), "experience makes levels, levels make power")
	gs.party_xp = {}
	var ups: Array = gs.add_party_xp(true)
	_check(int(gs.party_xp.get("guardian", 0)) == Party.XP_WIN and ups.size() == 2, "a won fight levels the party up")
	for k in Party.CLASSES:
		_check(TranslationServer.translate(Party.name_key(k)) != Party.name_key(k) and TranslationServer.translate(Party.skill_key(k)) != Party.skill_key(k), "words for class %s" % k)
	var p0: int = pr.pearls
	var c0: float = gs.total_earned
	var got: Dictionary = gs.defeat_boss("d3")
	_check(got.get("boss", "") == "crabblack" and pr.pearls == p0 + 20 and gs.total_earned > c0, "a beaten guard pays pearls and coins")
	_check(gs.boss_at("d3") == "" and gs.defeat_boss("d3").is_empty(), "and stays beaten")
	_check(gs.open_depth("d3") and gs.is_open("d3"), "now the site opens")
	gs.save_path = "user://saga_test_save.json"
	gs.save_game()
	gs.bosses = {}
	gs.load_game()
	_check(gs.bosses.has("d3"), "beaten guards are saved")
	var snap: Dictionary = gs._run_snapshot()
	gs._apply_run(snap)
	_check(gs.bosses.has("d3"), "and kept with the world's run")
	gs._reset_run(true)
	_check(gs.bosses.is_empty() and gs.boss_at("d3") == "crabblack", "a new run (a star) brings the guards back")
	DirAccess.remove_absolute("user://saga_test_save.json")
	# --- Story scenes ---------------------------------------------------------------------
	var story = load("res://scripts/ui/saga_story.gd")
	var ids := ["intro", "act2"]
	for b in MineBoss.BOSSES:
		ids.append("pre_" + b)
		ids.append("post_" + b)
	for sid in ids:
		var pages: Array = story.pages_of(sid)
		_check(not pages.is_empty(), "story %s has pages" % sid)
		for pg in pages:
			_check(TranslationServer.translate(pg[1]) != pg[1], "words for %s" % pg[1])
	_check(story.pages_of("pre_nobody").is_empty() and story.pages_of("x").is_empty(), "no story for unknown ids")
	for k in ["SAGA_TITLE", "SAGA_ACT", "SAGA_ACT2", "SAGA_ACT3", "MURK_TITLE", "MURK_TEXT", "STORY_KEEPER", "STORY_SKIP"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)
	# --- A whole boss fight, played by the test ---------------------------------------------
	gs.reset()
	gs.story["pre_crabblack"] = true
	for i in 3:
		gs.levels["d%d" % i] = 70
	for k in ["lift", "boat", "plant"]:
		gs.levels[k] = 140
	var played: Dictionary = await _fight(true)
	_check(played["state"] == "won", "an active player beats Crabblack with a grown mine (%s, %.0f s left)" % [played["state"], played["left"]])
	gs.bosses.erase("d3")
	for i in 3:
		gs.levels["d%d" % i] = 1
	for k in ["lift", "boat", "plant"]:
		gs.levels[k] = 1
	played = await _fight(true)
	_check(played["state"] == "lost", "even perfect play can't beat a guard with a fresh mine: upgrade first (%s)" % played["state"])
	# --- The Murk ---------------------------------------------------------------------------
	gs.reset()
	_check(gs.murk == 0.0 and gs.murk_mult() == 1.0, "a fresh saga starts clear")
	var base: float = gs.income_mult()
	gs.advance(600.0)
	_check(is_equal_approx(gs.murk, 600.0 / Murk.FULL_SEC), "the Murk rises while the mine works")
	_check(gs.income_mult() < base and is_equal_approx(gs.murk_mult(), Murk.factor(gs.murk)), "and slows everything down")
	gs.murk = 1.0
	_check(is_equal_approx(gs.murk_mult(), 1.0 - Murk.LOSS), "full Murk: half the income")
	gs.tap_clock += 5.0
	gs.tap("d0")
	_check(is_equal_approx(gs.murk, 1.0 - Murk.TAP_CLEAR), "a tap pushes it back")
	gs.simulate_offline(3600.0)
	_check(gs.murk == 1.0, "never above full")
	for i in 3:
		gs.levels["d%d" % i] = 10
	var cleansed := [false]
	gs.murk_cleansed.connect(func(): cleansed[0] = true, CONNECT_ONE_SHOT)
	gs.defeat_boss("d3")
	_check(gs.murk == 0.0 and cleansed[0], "a beaten guard cleanses the world")
	_check(Murk.rise(100.0, 1) < Murk.rise(100.0, 0), "every beaten guard slows the Murk")
	gs.murk = 0.4
	gs.story = {"intro": true}
	gs.party_xp = {"medic": 250}
	gs.save_path = "user://saga_test_save.json"
	gs.save_game()
	gs.murk = 0.0
	gs.story = {}
	gs.party_xp = {}
	gs.load_game()
	_check(is_equal_approx(gs.murk, 0.4) and gs.story.get("intro", false) and int(gs.party_xp.get("medic", 0)) == 250, "Murk, seen story scenes and the party are saved")
	DirAccess.remove_absolute("user://saga_test_save.json")

	# --- Act II: Atlantis ---------------------------------------------------------------------
	_act2(gs)
	_act3(gs)

	pf.leave_league()
	_check(pf.current_id == home and not Balance.saga and gs.world_id() == "ocean", "back home: the usual worlds")
	gs.reset()
	for i in 3:
		gs.levels["d%d" % i] = 10
	_check(gs.boss_at("d3") == "", "no guards in the usual worlds")
	gs.advance(600.0)
	_check(gs.murk == 0.0 and gs.murk_mult() == 1.0, "no Murk in the usual worlds")
	WorldLook.apply(0)
	_check(WorldLook.world == "ocean", "the look follows back (same location number, other world)")
	pf.remove(pf.league_profile(lg).get("id", ""))

	print("test_saga: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _act2(gs: Node) -> void:
	var n := Balance.WORLDS.size()
	_check(n == 8 and Balance.world_of(1)["id"] == "atlantis", "eight worlds; the saga's location 1 is Atlantis")
	# Every per-world table covers all worlds (the league's fishing bug came from 5-world arrays).
	_check(WorldLook.WORLDS.size() == n and MapArt.WORLDS.size() == n and WorkerLooks.WORLDS.size() == n, "looks, map and workers for every world")
	_check(FishArt.WORLD_HUES.size() == n and RodArt.KEYS.size() == n and TileWorlds.COLORS.has(n - 1), "fish, rods and tiles for every world")
	for w in Balance.WORLDS:
		var id := str(w["id"])
		_check(WorldLook.LOOKS.has(id) and FactoryArt.LOOKS.has(id) and MapArt.LOOK.has(id), "looks of %s" % id)
	gs.reset()
	gs.location = 1
	gs.max_location = 1
	WorldLook.apply(1)
	_check(gs.world_id() == "atlantis" and gs.site_count() == 15 and WorldLook.world == "atlantis" and WorldLook.is_water(), "Atlantis: 15 sites under water")
	for i in 15:
		var k: String = "SITE_" + gs.site_id(i).to_upper()
		_check(TranslationServer.translate(k) != k and Art.SITE_STYLE.has(gs.site_id(i)), "name and look of site %s" % gs.site_id(i))
	for k in ["WORLD_ATLANTIS", "MAP_W_ATLANTIS", "MAP_HINT_ATLANTIS", "FISHING_ROD_ATLANTIS", "ROD_ATLANTIS_20", "GEAR_ATLANTIS_4", "TIDE_TEXT", "TIDE_HIGH_BAR", "RELIC_TITLE", "RELIC_S_XP", "BOSS_SHIELD", "BOSS_PROPHECY"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)
	_check(MineBoss.guard("atlantis", 3) == "automaton" and MineBoss.guard("atlantis", 14) == "colossus", "Atlantis' five guards")
	for b in ["automaton", "siren_queen", "drowned_king", "hydra", "colossus"]:
		_check(Relics.BOSS_RARITY.has(b) and MineBoss.BOSSES[b].has("rule") or b == "colossus", "relic and rule for %s" % b)
	# The party keeps act I's heroes; the Oracle joins after the Drowned King.
	var beaten: Array = gs.saga_beaten()
	_check(beaten.has("warden") and Party.members(beaten).size() == 4 and not Party.members(beaten).has("oracle"), "act I's heroes come along")
	beaten.append("drowned_king")
	_check(Party.members(beaten).has("oracle") and Party.members(beaten).size() == 5, "the Oracle joins")
	# Tides.
	_check(Tides.high(10.0) and not Tides.high(100.0) and Tides.left(10.0) == 80.0, "a 3-minute tide cycle")
	_check(Tides.mult(10.0, "lift") == 2.0 and Tides.mult(10.0, "dives") == 1.0 and Tides.mult(100.0, "dives") == 2.0 and Tides.mult(100.0, "boat") == 1.0, "high tide: lift and boats; low tide: mines")
	_check(gs.has_tides(), "Atlantis has tides")
	# Relics: a drop, wearing, totals, saving.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rel := Relics.drop(rng, "hydra", 15)
	_check(int(rel["rarity"]) >= 2 and rel["affixes"].size() == int(rel["rarity"]) + 1 and Relics.KINDS.find(rel["kind"]) >= 5, "the Hydra drops a rare city relic")
	_check(gs.add_relic({"kind": "siren_comb", "rarity": 0, "affixes": [{"stat": "all", "v": 0.1}]}), "a relic goes to the bag")
	_check(gs.relic("all") == 0.0 and gs.wear_relic(0, "guardian") and is_equal_approx(gs.relic("all"), 0.1), "worn relics count")
	_check(not gs.wear_relic(0, "oracle"), "only party members wear relics")
	var m0: float = gs.income_mult()
	gs.salvage_relic(0)
	_check(gs.relics.is_empty() and gs.relic_shards == Relics.SALVAGE[0] and gs.income_mult() < m0, "melting gives shards and drops the bonus")
	gs.add_relic(rel)
	gs.wear_relic(0, "harpooner")
	gs.save_path = "user://saga_test_save.json"
	gs.save_game()
	gs.relics = []
	gs.relic_shards = 0
	gs.load_game()
	_check(gs.relics.size() == 1 and str(gs.relics[0]["hero"]) == "harpooner" and gs.relic_shards == Relics.SALVAGE[0] and gs.world_id() == "atlantis", "relics, shards and the act are saved")
	DirAccess.remove_absolute("user://saga_test_save.json")
	gs.reset()
	WorldLook.apply(0)


func _act3(gs: Node) -> void:
	gs.reset()
	gs.location = 2
	gs.max_location = 2
	WorldLook.apply(2)
	_check(gs.world_id() == "rlyeh" and gs.site_count() == 15 and WorldLook.world == "rlyeh" and gs.is_last_location(), "R'lyeh: 15 sites, the saga's last act")
	for i in 15:
		var k: String = "SITE_" + gs.site_id(i).to_upper()
		_check(TranslationServer.translate(k) != k and Art.SITE_STYLE.has(gs.site_id(i)), "name and look of site %s" % gs.site_id(i))
	for k in ["WORLD_RLYEH", "MAP_W_RLYEH", "FISHING_ROD_RLYEH", "GEAR_RLYEH_4", "WB_TITLE", "CARD_SLEEPER", "NIGHTMARE_TITLE", "STORY_ACT3_1"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)
	_check(MineBoss.guard("rlyeh", 3) == "deep_one_priest" and MineBoss.guard("rlyeh", 14) == "ancient_one", "R'lyeh's five guards")
	for b in ["deep_one_priest", "shoggoth", "dagon_priest", "star_spawn", "ancient_one"]:
		_check(Relics.BOSS_RARITY.has(b) and MineBoss.BOSSES[b].has("rule"), "relic and rule for %s" % b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_check(Relics.KINDS.find(Relics.drop(rng, "star_spawn", 15)["kind"]) >= 10, "act III bosses drop act III relics")
	var beaten: Array = ["crabblack", "mother_jelly", "drowned_king"]
	_check(not Party.members(beaten).has("astronomer"), "no Astronomer before the Shoggoth")
	beaten.append("shoggoth")
	_check(Party.members(beaten).has("astronomer") and Party.members(beaten).size() == 6, "the Astronomer joins: six heroes")
	# Rifts: open in a working mine, steal income, close after taps.
	gs.levels["d0"] = 10
	_check(gs.has_rifts(), "R'lyeh has rifts")
	var r0: float = gs.rate("d0")
	gs._tick_rifts(Rifts.EVERY + 1.0)
	_check(gs.rifts.has("d0") and is_equal_approx(gs.rate("d0"), r0 * Rifts.STEAL), "a rift opens and steals income")
	for i in Rifts.TAPS:
		gs.tap_clock += 1.0
		gs.tap("d0")
	_check(not gs.rifts.has("d0"), "taps close the rift")
	# World boss: my damage is capped per fight, the reward is given once.
	_check(is_equal_approx(gs.wb_add(1e9, 42), WorldBoss.CAP) and is_equal_approx(gs.wb_add(10.0, 42), WorldBoss.CAP + 10.0), "a fight adds at most CAP")
	_check(gs.wb_claim(WorldBoss.HP - 1.0, 42).is_empty(), "no reward before the boss falls")
	var got: Dictionary = gs.wb_claim(WorldBoss.HP, 42)
	_check(int(got.get("pearls", 0)) == WorldBoss.PEARLS and gs.wb_claim(WorldBoss.HP, 42).is_empty(), "the reward is given once")
	gs.wb_add(5.0, 43)
	_check(is_equal_approx(float(gs.wb["dmg"]), 5.0) and not gs.wb["claimed"], "a new league starts from zero")
	var board := WorldBoss.parse_board('{"rows":[{"name":"A","dmg":2e8},{"name":"B","dmg":100}]}')
	_check(is_equal_approx(float(board.get("total", 0.0)), 1e7 + 100.0), "the board caps one player's damage")
	# Nightmare: stars open only after the Ancient One.
	_check(not gs.stars_unlocked(), "no Nightmare before the finale")
	gs.saga_done = true
	_check(gs.stars_unlocked(), "Nightmare opens after the Ancient One")
	gs.save_path = "user://saga_test_save.json"
	gs.save_game()
	gs.saga_done = false
	gs.wb = {"l": 0, "dmg": 0.0, "claimed": false}
	gs.load_game()
	_check(gs.saga_done and int(gs.wb["l"]) == 43, "the finale and the world boss are saved")
	DirAccess.remove_absolute("user://saga_test_save.json")
	gs.reset()
	WorldLook.apply(0)


## Plays a fight on BossScreen for up to its full time: `active` taps the
## boss 6 times a second, hits weak spots, parries and fires skills.
func _fight(active: bool) -> Dictionary:
	var gs: Node = root.get_node("GameState")
	var bs = load("res://scripts/ui/boss_screen.gd").new()
	bs.key = "d3"
	bs.size = Vector2(720, 1280)
	root.add_child(bs)
	await process_frame
	bs.size = Vector2(720, 1280)
	bs.set_process(false)
	bs._start()
	var dt := 1.0 / 30.0
	var n := 0
	while bs._state == "fight" and n < int(MineBoss.FIGHT_SEC / dt) + 10:
		bs._process(dt)
		n += 1
		if active and n % 5 == 0:
			if bs._wind > 0.0:
				bs.tap_at(bs._attack_target())
			elif bs._spot_left > 0.0:
				bs.tap_at(bs._center() + bs._spot * bs._scale())
			else:
				bs.tap_at(bs._center())
			for i in bs._heroes.size():
				bs.use_skill(i)
	var out := {"state": bs._state, "left": bs._left}
	bs.queue_free()
	await process_frame
	return out
