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
	pf.leave_league()
	_check(pf.current_id == home and not Balance.saga and gs.world_id() == "ocean", "back home: the usual worlds")
	WorldLook.apply(0)
	_check(WorldLook.world == "ocean", "the look follows back (same location number, other world)")
	pf.remove(pf.league_profile(lg).get("id", ""))

	print("test_saga: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
