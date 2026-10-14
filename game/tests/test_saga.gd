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
	_check(Balance.last_location() == Balance.SAGA_LAST and gs.is_last_location(), "act I is the last part for now")
	_check(WorldLook.world_of(0) == "twilight" and MapArt.world_of(0) == "twilight" and MapArt.soon_worlds() == MapArt.SAGA_SOON, "looks and map follow the saga")
	WorldLook.apply(0)
	_check(WorldLook.world == "twilight" and WorldLook.is_water(), "the Twilight Zone is under water (divers swim)")
	_check(WorkerLooks.world_index("twilight") == 5 and 5 in WorkerLooks.WATER_WORLDS, "abyss divers swim")
	for i in 15:
		_check(TranslationServer.translate("SITE_" + gs.site_id(i).to_upper()) != "SITE_" + gs.site_id(i).to_upper(), "name of site %d" % i)
	for k in ["WORLD_TWILIGHT", "MAP_W_TWILIGHT", "GEAR_TWILIGHT_1", "GEAR_TWILIGHT_4", "MAP_W_SUNKEN", "MAP_W_ABYSS"]:
		_check(TranslationServer.translate(k) != k, "words for %s" % k)
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
	_check(MineBoss.judge("crabblack", MineBoss.SPOT_AT) == 2 and MineBoss.judge("crabblack", MineBoss.SPOT_AT + 0.1) == 1 and MineBoss.judge("crabblack", 0.1) == 0, "miss, hit and perfect taps")
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
	var ids := ["intro"]
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
	gs.save_path = "user://saga_test_save.json"
	gs.save_game()
	gs.murk = 0.0
	gs.story = {}
	gs.load_game()
	_check(is_equal_approx(gs.murk, 0.4) and gs.story.get("intro", false), "Murk and seen story scenes are saved")
	DirAccess.remove_absolute("user://saga_test_save.json")

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
