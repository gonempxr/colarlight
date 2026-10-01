extends SceneTree
## Meta game rules (pearls, quests, daily gift, artifacts, chests, wardrobe,
## saves, profiles):
##   godot --headless --path . -s res://tests/test_progress.gd
## Uses its own save files, never the player's.

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


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	pr = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	gs.save_path = "user://test_progress_game.json"
	pr.save_path = "user://test_progress.json"
	_fresh()
	test_pearls()
	test_quests()
	test_daily()
	test_artifacts_and_puzzle()
	test_chest()
	test_wardrobe()
	test_features()
	test_save_roundtrip()
	test_corrupted_save()
	test_names()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_progress_game.json")
	DirAccess.remove_absolute("user://test_progress.json")
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	gs.reset()
	pr.reset()


func test_pearls() -> void:
	_fresh()
	pr.add_pearls(10)
	check(pr.pearls == 10 and pr.pearls_total == 10, "pearls add up")
	check(not pr.spend_pearls(11), "can't spend more than you have")
	check(pr.spend_pearls(4) and pr.pearls == 6, "spending takes pearls")
	check(pr.pearls_total == 10, "spending keeps the lifetime total")
	check(not pr.spend_pearls(-3) and pr.pearls == 6, "negative spend is refused")
	pr.add_pearls(-5)
	check(pr.pearls == 6, "negative gifts are ignored")
	pr.pearls = 100
	var coins_before: float = gs.coins
	check(pr.buy_boost() and gs.boost_left >= Content.BOOST_MIN * 60.0 - 1.0, "boost costs pearls and gives x2 time")
	check(pr.buy_coins() and gs.coins > coins_before, "coin bag gives coins")


func test_quests() -> void:
	_fresh()
	pr.features["quests"] = true
	pr._fill_quests()
	check(pr.quests.size() == Content.QUEST_SLOTS, "quest slots fill up")
	var kinds := {}
	for q in pr.quests:
		kinds[q["kind"]] = true
	check(kinds.size() == pr.quests.size(), "no two quests of the same kind at once")
	# Force a known quest and finish it through the real game.
	pr.quests[0] = {"kind": "tap", "key": "", "goal": 3.0, "count": 0.0, "pearls": 2}
	for i in 3:
		gs.tap("d0")
	check(pr.quest_complete(0), "tapping completes a tap quest")
	check(pr.quests_ready() >= 1, "ready quests are counted")
	var pearls_before: int = pr.pearls
	var r: Dictionary = pr.claim_quest(0)
	check(r.get("pearls", 0) == 2 and pr.pearls == pearls_before + 2, "claiming gives the pearls")
	check(pr.quests.size() == Content.QUEST_SLOTS, "a new quest replaces the claimed one")
	check(pr.claim_quest(99).is_empty(), "claiming a missing quest does nothing")
	pr.quests[1] = {"kind": "upgrade_stage", "key": "boat", "goal": 2.0, "count": 0.0, "pearls": 2}
	gs.coins = 1e6
	gs.upgrade("d0", 3)
	check(pr.quests[1]["count"] == 0.0, "stage quests ignore other stages")
	gs.upgrade("boat", 5)
	check(pr.quests[1]["count"] == 2.0, "stage quest counts and stops at the goal")
	pr.quests[2] = {"kind": "earn", "key": "", "goal": 50.0, "count": 0.0, "pearls": 2}
	gs.add_coins(80.0)
	check(pr.quest_complete(2), "earning coins completes an earn quest")


func test_daily() -> void:
	_fresh()
	check(not pr.daily_ready(), "no gift before the feature opens")
	pr.features["daily"] = true
	check(pr.daily_ready(), "first gift is ready")
	var g: Dictionary = pr.claim_daily()
	check(g.get("kind") == Content.DAILY[0]["kind"] and gs.coins > 0.0, "day 1 gift is given")
	check(not pr.daily_ready() and pr.claim_daily().is_empty(), "only one gift per day")
	# Next day (whatever the gap): the week goes on, it never resets.
	pr.daily_last = "2000-01-01"
	g = pr.claim_daily()
	check(pr.daily_day == 2 and g.get("kind") == "pearls" and pr.pearls == Content.DAILY[1]["amount"], "day 2 gift after a long break")
	pr.daily_day = Content.DAILY.size() + 1
	pr.daily_last = "2000-01-02"
	var p0: int = pr.pearls
	g = pr.claim_daily()
	check(pr.pearls == p0 + Content.DAILY[1]["amount"] + 5, "second week pearls grow")


func test_artifacts_and_puzzle() -> void:
	_fresh()
	check(pr.target_artifact() == Content.ARTIFACTS[0]["id"], "first target is the first artifact")
	var first: String = Content.ARTIFACTS[0]["id"]
	var need: int = pr.pieces_needed(first)
	var lost: Dictionary = pr.puzzle_reward({"won": false, "fragments": 1})
	check(lost["piece"] == "" and lost["coins"] > 0.0 and lost["pearls"] == 1, "a lost puzzle still gives something")
	check(pr.puzzle_level == 1, "losing keeps the level")
	var boat_before: float = gs.rate("boat")
	for i in need:
		var r: Dictionary = pr.puzzle_reward({"won": true, "stars": 3, "artifact": first})
		check(r["piece"] == first, "win gives a piece of the level's artifact")
	check(pr.artifacts[first]["level"] == 1 and pr.artifacts[first]["pieces"] == 0, "enough pieces make level 1")
	check(pr.puzzle_level == need + 1, "winning moves to the next level")
	check(gs.rate("boat") > boat_before * 1.1, "the compass speeds up the boat")
	check(pr.target_artifact() == Content.ARTIFACTS[1]["id"], "next target is the next artifact")
	check(int(pr.stats.get("puzzles_won", 0)) == need, "wins are counted")
	var bad: Dictionary = pr.puzzle_reward({"won": true, "stars": 1, "artifact": "nonsense"})
	check(bad["piece"] == Content.ARTIFACTS[1]["id"], "unknown artifact falls back to the target")
	# Coins follow the puzzle level too: late in the game the first puzzle
	# level pays a little, new deeper levels pay more; every win still pays
	# at least half a minute of income, more stars pay more.
	_fresh()
	gs.levels.merge({"d0": 300, "d1": 300, "d2": 300, "lift": 400, "boat": 400, "plant": 400}, true)
	for k in ["d0", "d1", "d2", "lift", "boat", "plant"]:
		gs.managers[k] = true
	var inc: float = gs.income_rate() * 60.0
	pr.puzzle_level = 1
	var low: float = pr.puzzle_reward({"won": true, "stars": 3, "artifact": first})["coins"]
	pr.puzzle_level = 30
	var high: Dictionary = pr.puzzle_reward({"won": true, "stars": 3, "artifact": first})
	pr.puzzle_level = 30
	var high1: float = pr.puzzle_reward({"won": true, "stars": 1, "artifact": first})["coins"]
	check(low <= inc * 1.25 and low >= inc * 0.5, "late game, puzzle level 1 pays about a minute of income (%.2f min)" % (low / inc))
	check(float(high["coins"]) >= low * 4.0, "a deep puzzle level pays much more than level 1 (%.1fx)" % (float(high["coins"]) / low))
	check(float(high["coins"]) > high1, "more stars pay more")
	check(int(high["pearls"]) > 5, "deep puzzle levels give extra pearls (%d)" % int(high["pearls"]))
	check(Content.puzzle_factor(1000) <= Content.PUZZLE_FACTOR_MAX, "the level factor is capped")
	# Max level stops at 5.
	pr.artifacts[first]["level"] = Content.ARTIFACT_MAX
	check(pr.add_piece(first) == 0 and pr.artifacts[first]["level"] == Content.ARTIFACT_MAX, "artifacts stop at the max level")
	# Tap bonus pushes a dive further.
	_fresh()
	pr.artifacts["fish_idol"]["level"] = 2
	pr.apply_bonus()
	gs.advance(0.01)
	var p0: float = gs.cycle_progress("d0")
	gs.tap("d0")
	var gain: float = gs.cycle_progress("d0") - p0
	check(absf(gain - Balance.TAP_BOOST * 1.5) < 0.01, "fish idol makes taps stronger (%.3f)" % gain)


func test_chest() -> void:
	_fresh()
	check(pr.open_chest().is_empty(), "no chest, nothing to open")
	pr.features["chests"] = true
	pr.chest_timer = 0.01
	pr._process(0.02)
	check(pr.chest_ready, "a chest floats in after its timer")
	var r: Dictionary = pr.open_chest()
	check(r.get("coins", 0.0) > 0.0 and not pr.chest_ready, "opening gives coins and removes the chest")
	check(pr.chest_timer >= pr.CHEST_GAP_SEC.x, "next chest waits a while")


func test_wardrobe() -> void:
	_fresh()
	check(pr.is_owned("boat_classic") and pr.equipped["boat"] == "boat_classic", "classic boat is free and on")
	check(not pr.buy_item("pet_crab"), "can't buy without pearls")
	pr.pearls = 1000
	check(pr.buy_item("pet_crab") and pr.is_owned("pet_crab") and pr.equipped["pet"] == "pet_crab", "buying a pet puts it on")
	check(pr.pearls == 1000 - 40, "the pet cost its price")
	check(not pr.buy_item("pet_crab"), "can't buy twice")
	check(not pr.buy_item("pet_turtle"), "goal items can't be bought")
	pr.equip("pet_crab")
	check(pr.equipped["pet"] == "", "tapping the pet again takes it off")
	pr.equip("pet_turtle")
	check(pr.equipped["pet"] == "", "can't wear what you don't own")
	pr.stats["puzzles_won"] = 1
	pr._check_goals()
	check(pr.is_owned("pet_turtle"), "the first puzzle win unlocks the turtle")
	check(pr.equipped_art("boat") == "classic", "equipped art name")
	# Diver suits: a small real bonus for every diver while worn, bigger for
	# the pricier and rarer suits; the free one has none.
	var base: float = gs.rate("d0")
	check(pr.suit_bonus() == 0.0, "the classic suit gives no bonus")
	check(pr.buy_item("suit_sunset"), "a suit can be bought with pearls")
	check(is_equal_approx(gs.rate("d0"), base * 1.08), "the sunset suit brings +8%% ore (%.3f)" % (gs.rate("d0") / base))
	check(is_equal_approx(gs.rate("boat"), Balance.output(Balance.BOAT["value"], gs.get_level("boat")) * gs.income_mult()), "suits only help the divers")
	pr.equip("suit_classic")
	check(is_equal_approx(gs.rate("d0"), base), "taking it off removes the bonus")
	var prev := -1.0
	var grows := true
	for c in Content.COSMETICS:
		if c["slot"] == "suit":
			var sb := Content.suit_bonus(c["id"])
			grows = grows and sb >= prev and sb <= 0.15
			prev = sb
	check(grows, "suit bonuses grow with price and rarity and stay modest (<= 15%)")


func test_features() -> void:
	_fresh()
	pr.stats["play_time"] = 50.0
	pr._check_features()
	check(pr.has_feature("daily") and not pr.has_feature("puzzle"), "features open in order")
	check(pr.fresh.has("daily"), "a new feature is marked NEW")
	pr.seen("daily")
	check(not pr.fresh.has("daily"), "seeing it clears NEW")


func test_save_roundtrip() -> void:
	_fresh()
	pr.pearls = 42
	pr.pearls_total = 50
	pr.artifacts["amphora"] = {"level": 2, "pieces": 1}
	pr.owned["pet_seal"] = true
	pr.equipped["pet"] = "pet_seal"
	pr.features["quests"] = true
	pr.quests = [{"kind": "tap", "key": "", "goal": 10.0, "count": 4.0, "pearls": 2},
			{"kind": "upgrade_stage", "key": "d25", "goal": 3.0, "count": 1.0, "pearls": 2}]
	pr.daily_day = 3
	pr.daily_last = "2026-01-01"
	pr.puzzle_level = 7
	pr.stats["taps"] = 99
	check(pr.save_game(), "progress saves")
	pr.reset()
	check(pr.load_game(), "progress loads")
	check(pr.pearls == 42 and pr.pearls_total == 50, "pearls survive")
	check(pr.artifacts["amphora"]["level"] == 2 and pr.artifacts["amphora"]["pieces"] == 1, "artifacts survive")
	check(pr.equipped["pet"] == "pet_seal" and pr.is_owned("pet_seal"), "wardrobe survives")
	check(pr.quests.size() == 1 and pr.quests[0]["count"] == 4.0, "quests survive; one for a site of the 30-site version is dropped")
	check(pr.daily_day == 3 and pr.daily_last == "2026-01-01" and pr.puzzle_level == 7, "counters survive")
	check(float(gs.bonus.get("plant", 1.0)) > 1.0, "loaded artifacts apply their bonus")


func test_corrupted_save() -> void:
	var f := FileAccess.open(pr.save_path, FileAccess.WRITE)
	f.store_string("{\"pearls\": \"lots\", \"artifacts\": {\"compass\": {\"level\": 99}}, \"equipped\": {\"pet\": \"pet_unicorn\"}, \"quests\": [{\"kind\": \"hack\"}]}")
	f.close()
	pr.reset()
	check(pr.load_game(), "odd values load without crashing")
	check(pr.pearls == 0, "bad pearls become 0")
	check(pr.artifacts["compass"]["level"] == Content.ARTIFACT_MAX, "artifact level is clamped")
	check(pr.equipped["pet"] == "", "unknown items are not worn")
	check(pr.quests.is_empty(), "unknown quests are dropped")
	f = FileAccess.open(pr.save_path, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	pr.reset()
	check(not pr.load_game(), "broken file is refused")


func test_names() -> void:
	var Profiles: Node = root.get_node("Profiles")
	check(Profiles.clean_name("  Маша  ") == "Маша", "names are trimmed")
	check(Profiles.clean_name("a\nb\tc") == "abc", "control characters are dropped")
	check(Profiles.clean_name("x".repeat(40)).length() == Profiles.NAME_MAX, "names are capped")
	check(Profiles.clean_name("小明") == "小明", "Chinese names work")
