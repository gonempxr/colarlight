extends SceneTree
## Worlds economy: location gate, evolution forms, vault and accountant,
## advance_location, world/tier cycling, save v3 -> v4, decor, suit refund.
##   godot --headless --path . -s res://tests/test_worlds.gd
## Uses its own save files, never the player's.

const GAME_SAVE := "user://test_worlds_game.json"
const PROGRESS_SAVE := "user://test_worlds_progress.json"

var _failures := 0
var _checks := 0
var gs: Node
var pr: Node


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	pr = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	gs.save_path = GAME_SAVE
	pr.save_path = PROGRESS_SAVE
	test_balance_tables()
	test_location_gate()
	test_evolution()
	test_income_mult()
	test_vault()
	test_advance_location()
	test_world_cycling()
	test_v3_migration()
	test_decor()
	test_suit_refund()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute(GAME_SAVE)
	DirAccess.remove_absolute(PROGRESS_SAVE)
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	gs.reset()
	pr.reset()


## Everything of the gate except the coins: all sites open with foremen, the
## lift, both boats and both plants with managers.
func _complete_location() -> void:
	for key in gs.stage_keys():
		gs.levels[key] = maxi(1, gs.levels[key])
		gs.managers[key] = true


func test_balance_tables() -> void:
	check(Balance.WORLDS.size() == 4, "four worlds")
	var ids := []
	for w in Balance.WORLDS:
		ids.append(w["id"])
		check(w["sites"].size() == 10, "%s has 10 sites" % w["id"])
		check(str(w["name"]) == "WORLD_" + str(w["id"]).to_upper(), "%s name key" % w["id"])
	check(ids == ["ocean", "volcano", "acid", "moon"], "worlds in order")
	check(Balance.DEPTHS.size() == 10, "one 10-step ladder")
	var rising := true
	for i in range(1, 10):
		var a: Dictionary = Balance.DEPTHS[i - 1]
		var b: Dictionary = Balance.DEPTHS[i]
		rising = rising and b["value"] > a["value"] and b["cost0"] > a["cost0"] and b["unlock"] > a["unlock"] and b["manager"] >= a["manager"]
	check(rising, "deeper sites are worth more and cost more")
	check(Balance.EVO_PRICES.size() == Balance.EVO_FORMS and Balance.EVO_FORMS == 12, "12 forms")
	var up := true
	for i in range(1, 12):
		up = up and Balance.EVO_PRICES[i] > Balance.EVO_PRICES[i - 1]
	check(up, "each form costs more than the one before")
	check(Balance.EVO_PRICES[0] <= 100.0, "the first form is cheap (a few minutes in)")
	check(Balance.LOCATION_PRICE > Balance.EVO_PRICES[11] and Balance.LOCATION_PRICE > Balance.DEPTHS[9]["manager"], "the location price is the biggest one")
	check(near(Balance.loc_scale(0), 1.0) and near(Balance.loc_gate_scale(0), 1.0), "location 0 is the base")
	var longer := true
	for l in range(1, 12):
		longer = longer and Balance.loc_gate_scale(l) / Balance.loc_scale(l) > Balance.loc_gate_scale(l - 1) / Balance.loc_scale(l - 1)
	check(longer, "gate prices grow faster than income, so locations get longer")


func test_location_gate() -> void:
	_fresh()
	var goals: Array = gs.location_goals()
	var ids := goals.map(func(g): return g["id"])
	check(ids == ["sites", "foremen", "managers"], "goals: sites, foremen, managers (forms are optional) %s" % str(ids))
	check(goals[0]["have"] == 1 and goals[0]["need"] == 10, "one of ten sites open at the start")
	check(goals[1]["need"] == 10 and goals[2]["need"] == 5, "ten foremen and five managers needed")
	check(not gs.location_ready(), "a new location is not ready")
	_complete_location()
	gs.managers["boat2"] = false
	check(not gs.location_ready(), "the second boat needs its manager too")
	gs.managers["boat2"] = true
	gs.levels["plant2"] = 0
	check(not gs.location_ready(), "the second plant must be open")
	gs.levels["plant2"] = 1
	gs.managers["d9"] = false
	check(not gs.location_ready(), "every foreman is needed")
	gs.managers["d9"] = true
	check(gs.location_ready(), "all goals met")
	check(gs.evo == 0, "no forms needed for the gate")
	var cost: float = gs.next_location_cost()
	check(near(cost, Balance.LOCATION_PRICE), "location 0 price")
	gs.coins = cost * 0.5
	check(not gs.can_advance_location() and not gs.advance_location(), "the price must be paid")
	gs.vault = cost * 0.5
	check(gs.can_advance_location(), "coins waiting in the vault count")
	check(gs.advance_location() and gs.location == 1, "the next location opens")
	gs.location = 1
	check(near(gs.next_location_cost(), Balance.LOCATION_PRICE * Balance.loc_gate_scale(1)), "later locations cost more")


func test_evolution() -> void:
	_fresh()
	check(not gs.can_buy_evo() and not gs.buy_evo(), "forms cost coins")
	var bought := []
	gs.evo_bought.connect(func(f): bought.append(f))
	var mult0: float = gs.income_mult()
	gs.coins = 1e12
	var spent := 0.0
	for form in range(1, 13):
		var price: float = gs.evo_cost(form)
		check(near(price, Balance.EVO_PRICES[form - 1]), "form %d price" % form)
		var before: float = gs.coins
		check(gs.buy_evo(), "buy form %d" % form)
		spent += before - gs.coins
		check(gs.evo == form and near(before - gs.coins, price), "form %d bought in order at its price" % form)
	check(bought == range(1, 13), "evo_bought(form) for every form %s" % str(bought))
	check(not gs.can_buy_evo() and not gs.buy_evo() and gs.evo == 12, "no 13th form")
	check(near(gs.income_mult(), mult0 * pow(1.1, 12)), "each form x1.10 income (%.3f)" % (gs.income_mult() / mult0))
	check(int(pr.looks_seen.get("ocean", 0)) == 12, "the codex remembers the forms seen")
	gs.location = 2
	gs.evo = 0
	check(near(gs.evo_cost(1), Balance.EVO_PRICES[0] * Balance.loc_gate_scale(2)), "forms cost more in later locations")


func test_income_mult() -> void:
	_fresh()
	var base: float = gs.rate("d0")
	check(near(gs.income_mult(), 1.0), "x1 at the start")
	gs.legacy_mult = 27.0
	check(near(gs.rate("d0"), base * 27.0), "the legacy of old Dives multiplies income")
	gs.legacy_mult = 1.0
	pr.decor["sofa"] = 3
	pr.decor["lamp"] = 2
	pr.apply_bonus()
	check(near(gs.income_mult(), 1.05), "decor: +1%% per level (%.3f)" % gs.income_mult())
	pr.decor["sofa"] = 0
	pr.decor["lamp"] = 0
	pr.apply_bonus()
	gs.location = 3
	check(near(gs.rate("d0"), base * Balance.loc_scale(3)), "values scale with the location")
	check(near(gs.upgrade_cost("d0"), Balance.upgrade_cost(Balance.DEPTHS[0]["cost0"], 1) * Balance.loc_scale(3)), "level prices scale with the location")
	check(near(gs.unlock_cost("d1"), Balance.DEPTHS[1]["unlock"] * Balance.loc_gate_scale(3)), "site unlocks use the gate scale")
	check(near(gs.manager_cost("d0"), Balance.DEPTHS[0]["manager"] * Balance.loc_gate_scale(3)), "foremen use the gate scale")
	check(near(gs.manager_cost("boat"), Balance.BOAT["manager"] * Balance.loc_scale(3)), "chain managers use the plain scale")
	check(near(gs.unlock_cost("boat2"), Balance.BOAT2["unlock"] * Balance.loc_scale(3)), "the second boat uses the plain scale")
	gs.coins = gs.upgrade_cost("d0", 5)
	check(gs.max_affordable("d0") == 5, "max affordable follows the scale")
	check(near(gs.upgrade_cost("lift", 3), Balance.bulk_cost(Balance.LIFT["cost0"], 1, 3, Balance.CHAIN_GROWTH) * Balance.loc_scale(3)), "the chain levels with its own growth")


func _run_plant_once() -> void:
	gs.dock = 1.0e6
	gs.tap("plant")
	gs.advance(gs.cycle_time("plant") + 0.01)


func test_vault() -> void:
	_fresh()
	pr.quests = [{"kind": "earn", "key": "", "goal": 1.0e12, "count": 0.0, "pearls": 2}]
	_run_plant_once()
	var made: float = gs.vault
	check(made > 0.0 and gs.coins == 0.0, "the plant fills the vault, not the wallet")
	check(near(gs.total_earned, made), "earnings count when made")
	check(near(pr.quests[0]["count"], made), "earn quests count vault coins when made")
	var signals := [0]
	gs.vault_changed.connect(func(): signals[0] += 1)
	check(near(gs.collect_vault(), made) and near(gs.coins, made) and gs.vault == 0.0, "collect moves the vault to the wallet")
	check(signals[0] == 1 and gs.collect_vault() == 0.0, "vault_changed on collect; empty vault gives 0")
	check(near(pr.quests[0]["count"], made), "collecting does not count twice")
	# Rewards go to the wallet.
	gs.add_coins(10.0)
	check(near(gs.coins, made + 10.0) and gs.vault == 0.0, "rewards skip the vault")
	# The accountant.
	_run_plant_once()
	var waiting: float = gs.vault
	check(near(gs.manager_cost("vault"), Balance.VAULT["manager"]), "the accountant's price")
	check(not gs.has_manager("vault") and gs.is_open("vault"), "the vault is there, without an accountant")
	gs.coins = gs.manager_cost("vault") + 5.0
	check(gs.hire_manager("vault") and gs.has_manager("vault"), "hire the accountant")
	check(gs.vault == 0.0 and near(gs.coins, 5.0 + waiting), "the accountant collects what waits")
	check(not gs.hire_manager("vault"), "only one accountant")
	_run_plant_once()
	check(gs.vault == 0.0 and gs.coins > 5.0 + waiting, "with the accountant coins go straight to the wallet")
	# Offline earnings always go to the wallet.
	_fresh()
	for key in ["d0", "lift", "boat", "plant"]:
		gs.managers[key] = true
		gs.levels[key] = 20
	var earned: float = gs.simulate_offline(600.0)
	check(earned > 0.0 and near(gs.coins, earned) and gs.vault == 0.0, "offline earnings land in the wallet")
	# The vault and the accountant are saved.
	gs.vault = 77.0
	gs.save_game()
	gs.reset()
	gs.load_game()
	check(gs.vault >= 77.0 and not gs.has_manager("vault"), "the vault is saved")
	gs.managers["vault"] = true
	gs.save_game()
	gs.reset()
	gs.load_game()
	check(gs.has_manager("vault") and gs.vault == 0.0, "the accountant is saved and collects on load")


func test_advance_location() -> void:
	_fresh()
	pr.decor["desk"] = 2
	pr.apply_bonus()
	gs.legacy_mult = 3.0
	gs.coins = 1e30
	gs.managers["vault"] = true
	for i in 4:
		gs.buy_evo()
	_complete_location()
	for key in gs.stage_keys():
		gs.levels[key] = 40
	var total: float = gs.total_earned
	var changed := []
	gs.location_changed.connect(func(l): changed.append(l))
	check(gs.advance_location(), "advance")
	check(changed == [1] and gs.location == 1, "location_changed(1)")
	check(gs.coins == 0.0 and gs.vault == 0.0 and gs.evo == 0, "coins, vault and forms reset")
	check(gs.get_level("d0") == 1 and gs.get_level("d1") == 0 and gs.get_level("lift") == 1 and gs.get_level("boat2") == 0, "levels reset (second boat closed again)")
	check(not gs.has_manager("d0") and not gs.has_manager("d9"), "foremen are hired again")
	var kept := true
	for k in ["lift", "boat", "plant", "boat2", "plant2", "vault"]:
		kept = kept and gs.has_manager(k)
	check(kept, "lift, boat, plant, second boat/plant and the accountant stay")
	check(near(gs.legacy_mult, 3.0) and gs.total_earned >= total, "legacy and lifetime earnings stay")
	check(pr.decor["desk"] == 2 and near(float(gs.bonus.get("decor", 1.0)), 1.02), "decor stays")
	check(int(pr.looks_seen.get("ocean", 0)) == 4, "seen forms stay in the codex")
	check(int(pr.stats.get("location", 0)) == 1, "the highest location reached is a stat")
	var goals: Array = gs.location_goals()
	check(goals[2]["have"] == 3, "kept managers count once the second boat/plant reopen (%d)" % goals[2]["have"])
	# Saved and loaded.
	gs.save_game()
	gs.reset()
	gs.load_game()
	check(gs.location == 1 and gs.has_manager("boat2") and gs.has_manager("vault"), "the new location is saved")


func test_world_cycling() -> void:
	_fresh()
	var want := ["ocean", "volcano", "acid", "moon", "ocean", "volcano", "acid", "moon", "ocean"]
	var ok := true
	for l in want.size():
		gs.location = l
		ok = ok and gs.world_id() == want[l] and gs.world_index() == l % 4 and gs.tier() == l / 4
	check(ok, "worlds cycle ocean -> volcano -> acid -> moon, tier = L / 4")
	gs.location = 4
	check(gs.world_id() == "ocean" and gs.tier() == 1, "L=4 is the ocean, tier 1")
	check(gs.site_id(0) == "shells" and gs.site_id(9) == "heart", "ocean sites")
	gs.location = 1
	check(gs.site_id(0) == "ash" and gs.site_id(9) == "dragon", "volcano sites")
	gs.location = 2
	check(gs.site_id(2) == "shroom", "acid sites")
	gs.location = 3
	check(gs.site_id(9) == "cosmic_heart" and gs.site_id(1) == "meteor", "moon sites")
	gs.location = 0


func test_v3_migration() -> void:
	_fresh()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v3_save.json"))
	data["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(GAME_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	check(gs.load_game(), "a v3 save loads")
	check(gs.location == 0 and gs.world_id() == "ocean", "it moves into location 0, the ocean")
	check(near(gs.legacy_mult, Balance.prestige_mult(3)) and near(gs.legacy_mult, 27.0), "3 Dives become a permanent x27")
	var same := true
	for i in 7:
		same = same and gs.get_level("d%d" % i) == int(data["levels"]["d%d" % i])
	check(same, "shells..gold keep their levels")
	check(gs.get_level("d7") == 47 and gs.has_manager("d7"), "ice, lava, glow -> glow: best level, any foreman (%d)" % gs.get_level("d7"))
	check(gs.get_level("d8") == 21 and gs.has_manager("d8"), "atlantis, kraken -> atlantis (%d)" % gs.get_level("d8"))
	check(gs.get_level("d9") == 0 and not gs.has_manager("d9"), "whale, dragon, heart -> heart (closed)")
	check(gs.has_manager("d6") and gs.has_manager("d0"), "foremen kept")
	check(gs.get_level("lift") == 310 and gs.get_level("boat2") == 120 and gs.get_level("plant2") == 113, "lift and buildings keep their levels")
	check(gs.has_manager("boat2") and not gs.has_manager("plant2") and not gs.has_manager("vault"), "managers kept, no accountant yet")
	check(gs.coins >= 3.4e9 and gs.evo == 0 and gs.vault == 0.0, "coins kept, no forms, empty vault")
	check(not gs.levels.has("d10") and gs.stage_keys().size() == 15, "no sites past the 10th")
	check(gs.income_rate() > 0.0 and gs.next_depth() == "d9", "the economy runs; heart is the next site")
	gs.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GAME_SAVE))
	check(int(saved["version"]) == 4 and int(saved["location"]) == 0, "saved as version 4")
	gs.reset()
	gs.load_game()
	check(gs.get_level("d7") == 47 and gs.get_level("d8") == 21 and near(gs.legacy_mult, 27.0), "a v4 save does not fold twice")
	# Progress of the same player: its quest for an old deep site is dropped,
	# the Dive stat never goes down.
	f = FileAccess.open(PROGRESS_SAVE, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/v3_progress.json"))
	f.close()
	pr.reset()
	check(pr.load_game(), "a v3 progress save loads")
	check(pr.quests.size() == 1 and pr.quests[0]["kind"] == "tap", "a quest for an old deep site is dropped")
	check(int(pr.stats["prestiges"]) == 3, "the Dive stat is kept")


func test_decor() -> void:
	_fresh()
	check(Content.DECOR_SLOTS == ["wallpaper", "floor", "desk", "sofa", "aquarium", "lamp", "trophy", "plant"], "eight decor slots")
	check(pr.decor_level("sofa") == 0 and pr.decor_cost("sofa") == Content.DECOR_PRICES[0], "level 0, first price")
	check(not pr.buy_decor("sofa"), "decor costs pearls")
	pr.pearls = 10000
	var seen := [0]
	pr.decor_changed.connect(func(): seen[0] += 1)
	var prev := 0
	var rising := true
	for lv in Content.DECOR_MAX:
		var price: int = pr.decor_cost("sofa")
		rising = rising and price > prev
		prev = price
		var before: int = pr.pearls
		check(pr.buy_decor("sofa") and pr.pearls == before - price, "sofa level %d" % (lv + 1))
	check(rising, "decor prices rise with the level")
	check(pr.decor_level("sofa") == 5 and pr.decor_cost("sofa") == 0 and not pr.buy_decor("sofa"), "5 levels at most")
	check(seen[0] == 5, "decor_changed on every purchase")
	check(not pr.buy_decor("rocket"), "unknown slots are refused")
	check(near(gs.income_mult(), 1.05), "+1%% income per level (%.3f)" % gs.income_mult())
	pr.buy_decor("lamp")
	check(near(gs.income_mult(), 1.06), "levels of all slots add up")
	pr.save_game()
	pr.reset()
	check(pr.decor_level("sofa") == 0 and near(gs.income_mult(), 1.0), "reset clears decor")
	pr.load_game()
	check(pr.decor_level("sofa") == 5 and pr.decor_level("lamp") == 1 and near(gs.income_mult(), 1.06), "decor is saved")


func test_suit_refund() -> void:
	_fresh()
	var f := FileAccess.open(PROGRESS_SAVE, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/v3_progress.json"))
	f.close()
	pr.reset()
	pr.load_game()
	# Mint 50 + sunset 120 bought with pearls; galaxy came from a goal.
	check(pr.pearls == 37 + 170, "pearls spent on suits come back (%d)" % pr.pearls)
	check(not pr.is_owned("suit_mint") and not pr.is_owned("suit_sunset") and not pr.is_owned("suit_galaxy") and not pr.is_owned("suit_classic"), "suits are gone")
	check(not pr.equipped.has("suit") and pr.equipped["outfit"] == "outfit_casual", "the worn suit is taken off")
	check(pr.equipped["pet"] == "pet_crab" and pr.is_owned("pet_crab"), "other items stay")
	check(near(float(gs.bonus.get("dives", 1.0)), 1.0), "no suit bonus on the divers")
	pr.save_game()
	pr.reset()
	pr.load_game()
	check(pr.pearls == 37 + 170, "the refund is given only once")
