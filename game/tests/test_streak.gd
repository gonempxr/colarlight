extends SceneTree
## Streak rules (days in a row, ice cubes, kind restarts, clock changes,
## milestone rewards once, save/load):
##   godot --headless --path . -s res://tests/test_streak.gd
## Uses its own save files, never the player's.

var _failures := 0
var _checks := 0
var gs: Node
var pr: Node
var _lit := 0


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
	gs.save_path = "user://test_streak_game.json"
	pr.save_path = "user://test_streak.json"
	pr.streak_lit.connect(func(_r): _lit += 1)
	test_dates()
	test_counting()
	test_actions_count()
	test_freezes()
	test_break_keeps_best()
	test_clock_backwards()
	test_milestones()
	test_items()
	test_week()
	test_save_load()
	test_corrupted()
	test_strings()
	print("%d checks, %d failed" % [_checks, _failures])
	DirAccess.remove_absolute("user://test_streak_game.json")
	DirAccess.remove_absolute("user://test_streak.json")
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	gs.reset()
	pr.reset()
	pr.features["daily"] = true
	_lit = 0


## Day `n` after 2026-03-01 as a date string.
func day(n: int) -> String:
	return pr.date_of(pr.day_number("2026-03-01") + n)


func test_dates() -> void:
	check(pr.day_number("2026-03-02") - pr.day_number("2026-03-01") == 1, "day numbers follow the calendar")
	check(pr.day_number("2024-03-01") - pr.day_number("2024-02-28") == 2, "leap day counted")
	check(pr.date_of(pr.day_number("2026-12-31")) == "2026-12-31", "date round trip")
	check(pr.day_number("") == -1 and pr.day_number("nonsense") == -1, "bad dates are refused")


func test_counting() -> void:
	_fresh()
	pr.features.erase("daily")
	check(pr.streak_action(day(0)).is_empty() and pr.streak_count == 0, "nothing counts before the daily gift opens")
	pr.features["daily"] = true
	check(pr.streak_shown(day(0)) == 0 and not pr.streak_today(day(0)), "no flame at the start")
	var r: Dictionary = pr.streak_action(day(0))
	check(r.get("count") == 1 and pr.streak_count == 1 and _lit == 1, "first action lights day 1")
	check(int(r.get("old", -1)) == 0 and not r.get("broken", true), "a first flame is not a restart")
	check(pr.streak_today(day(0)), "today counted")
	check(pr.streak_action(day(0)).is_empty() and pr.streak_count == 1 and _lit == 1, "a second action the same day adds nothing")
	r = pr.streak_action(day(1))
	check(r.get("count") == 2 and pr.streak_best == 2, "next day grows the flame")
	check(pr.streak_shown(day(2)) == 2 and not pr.streak_today(day(2)), "the next morning shows the flame waiting")
	for i in range(2, 6):
		pr.streak_action(day(i))
	check(pr.streak_count == 6 and pr.streak_best == 6, "six days in a row")
	check(pr.streak_freezes == Content.STREAK_FREEZE_START, "no extra ice before day 7")
	r = pr.streak_action(day(6))
	check(pr.streak_count == 7 and r.get("ice_earned") == true and pr.streak_freezes == Content.STREAK_FREEZE_START + 1, "day 7 earns an ice cube")
	for i in range(7, 14):
		pr.streak_action(day(i))
	check(pr.streak_count == 14 and pr.streak_freezes == Content.STREAK_FREEZE_MAX, "ice cubes stop at the most you can hold")
	check(pr.streak_reward.get("pearls", 0) > 0, "rewards wait for the celebration")
	var p0: int = pr.pearls
	var got: Dictionary = pr.take_streak_reward()
	check(pr.pearls == p0 + int(got["pearls"]) and got["pearls"] > 0 and pr.streak_reward.is_empty(), "the celebration hands out the pearls")
	check(pr.take_streak_reward().is_empty(), "rewards are handed out once")


func test_actions_count() -> void:
	_fresh()
	gs.tap("d0")
	check(pr.streak_today() and pr.streak_count == 1, "a tap counts as today's small action")
	_fresh()
	gs.coins = 1e6
	gs.upgrade("d0", 1)
	check(pr.streak_today(), "an upgrade counts")
	_fresh()
	pr.claim_daily()
	check(pr.streak_today(), "claiming the daily gift counts")
	var p0: int = pr.pearls
	_fresh()
	check(pr.pearls == 0, "fresh profile")
	pr.claim_daily()
	check(pr.pearls == p0 * 0, "the daily gift itself pays only its own gift (streak pearls wait)")


func test_freezes() -> void:
	_fresh()
	pr.streak_action(day(0))
	pr.streak_action(day(1))
	check(pr.streak_freezes == 1, "start with one ice cube")
	# Miss day 2, come back on day 3.
	check(pr.streak_shown(day(3)) == 2, "a missed day covered by ice still shows the flame")
	var r: Dictionary = pr.streak_action(day(3))
	check(r.get("ice_used") == 1 and pr.streak_count == 3 and pr.streak_freezes == 0, "one ice cube covers one missed day")
	check(pr.streak_log.get(day(2)) == "ice" and pr.streak_log.get(day(3)) == "play", "the week shows the ice day")
	# Two ice cubes cover two missed days.
	_fresh()
	pr.streak_freezes = 2
	pr.streak_action(day(0))
	r = pr.streak_action(day(3))
	check(r.get("ice_used") == 2 and pr.streak_count == 2 and pr.streak_freezes == 0, "two cubes cover two days")


func test_break_keeps_best() -> void:
	_fresh()
	for i in 5:
		pr.streak_action(day(i))
	pr.take_streak_reward()
	pr.owned["hat_cat_ears"] = true
	var pearls: int = pr.pearls
	var freezes: int = pr.streak_freezes
	# Gone for 3 days with one ice cube: too long.
	check(pr.streak_will_restart(day(9)) and pr.streak_shown(day(9)) == 0, "a long break shows a calm empty flame")
	var r: Dictionary = pr.streak_action(day(9))
	check(r.get("broken") == true and r.get("count") == 1, "the flame starts again at 1")
	check(pr.streak_best == 5 and r.get("best") == 5, "the best record is kept")
	check(pr.streak_freezes == freezes, "ice cubes are not taken away by a restart")
	check(pr.pearls == pearls and pr.is_owned("hat_cat_ears"), "nothing owned is lost")
	check(not pr.streak_will_restart(day(9)), "after the restart all is well")


func test_clock_backwards() -> void:
	_fresh()
	pr.streak_action(day(10))
	pr.streak_action(day(11))
	var before: int = pr.streak_count
	check(pr.streak_action(day(5)).is_empty(), "an earlier date changes nothing")
	check(pr.streak_count == before and pr.streak_last == day(11), "the clock going back neither breaks nor extends")
	check(pr.streak_shown(day(5)) == before, "the flame still shows with the clock back")
	check(pr.streak_action(day(12)).get("count") == before + 1, "back to normal the next day counts")
	check(pr.streak_action("garbage").is_empty(), "a broken date changes nothing")


func test_milestones() -> void:
	_fresh()
	var total_pearls := 0
	for i in 7:
		var r: Dictionary = pr.streak_action(day(i))
		total_pearls += int(r["reward"]["pearls"])
		if i == 2:
			check(r.get("milestone") == 3 and int(r["reward"]["pearls"]) == Content.STREAK_DAY_PEARLS + 10, "day 3 milestone gives its pearls")
		if i == 6:
			check(r.get("milestone") == 7 and float(r["reward"]["coins_min"]) > 0.0, "day 7 gives a chest of coins")
	check(pr.streak_claimed.has("3") and pr.streak_claimed.has("7"), "milestones are remembered")
	var coins0: float = gs.coins
	var got: Dictionary = pr.take_streak_reward()
	check(int(got["pearls"]) == total_pearls and gs.coins > coins0, "milestone pearls and coins are given")
	# Break and climb again: the same milestones give only the daily bit.
	pr.streak_action(day(20))
	for i in range(21, 27):
		var r: Dictionary = pr.streak_action(day(i))
		check(int(r.get("milestone", 0)) == 0 and int(r["reward"]["pearls"]) == Content.STREAK_DAY_PEARLS, "milestone %d not paid twice" % (i - 19))
	check(pr.streak_next_milestone().get("days") == 14, "next milestone is 14 days")


func test_items() -> void:
	_fresh()
	check(not pr.is_owned("boat_flame") and not pr.is_owned("hat_flame"), "flame items start locked")
	for i in 14:
		pr.streak_action(day(i))
	check(pr.is_owned("boat_flame"), "14 days unlock the flame boat paint")
	check(not pr.is_owned("hat_flame"), "the hat waits for 30 days")
	pr.streak_action(day(40))
	for i in range(41, 70):
		pr.streak_action(day(i))
	check(pr.streak_count == 30 and pr.is_owned("hat_flame"), "30 days unlock the flame hat")
	check(Content.cosmetic("hat_flame")["art"] in HatsArt.IDS, "the flame hat can be drawn")
	check(Content.BOAT_PAINTS.has("flame"), "the flame boat paint exists")
	for m in Content.STREAK_MILESTONES:
		var item := str(m.get("item", ""))
		check(item == "" or not Content.cosmetic(item).is_empty(), "milestone item %s exists" % item)
		check(item == "" or Content.cosmetic(item)["unlock"] == "goal", "milestone items are never sold")


func test_week() -> void:
	_fresh()
	pr.streak_action(day(0))
	pr.streak_action(day(2))
	var w: Array = pr.streak_week(day(3))
	check(w.size() == 7 and w[6]["date"] == day(3), "the week ends today")
	check(w[3]["state"] == "play" and w[4]["state"] == "ice" and w[5]["state"] == "play" and w[6]["state"] == "today", "played, ice and today are shown")
	check(w[0]["state"] == "", "days before the flame are empty")


func test_save_load() -> void:
	_fresh()
	for i in 4:
		pr.streak_action(day(i))
	pr.streak_action(day(5))
	var want := {"count": pr.streak_count, "best": pr.streak_best, "last": pr.streak_last, "ice": pr.streak_freezes,
			"claimed": pr.streak_claimed.duplicate(), "log": pr.streak_log.duplicate(), "reward": pr.streak_reward.duplicate()}
	check(pr.save_game(), "save works")
	pr.reset()
	check(pr.streak_count == 0 and pr.streak_freezes == Content.STREAK_FREEZE_START, "reset clears the streak")
	check(pr.load_game(), "load works")
	check(pr.streak_count == want["count"] and pr.streak_best == want["best"] and pr.streak_last == want["last"], "count, best and last day survive")
	check(pr.streak_freezes == want["ice"] and pr.streak_claimed == want["claimed"] and pr.streak_log == want["log"], "ice, milestones and the week survive")
	check(int(pr.streak_reward.get("pearls", 0)) == int(want["reward"]["pearls"]), "a reward not shown yet survives")
	check(int(pr.stats.get("streak_best", 0)) == pr.streak_best, "the best record is in the stats (for goals)")
	# A save from before the streak: defaults, one ice cube.
	var f := FileAccess.open(pr.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "pearls": 5}))
	f.close()
	pr.reset()
	check(pr.load_game() and pr.streak_count == 0 and pr.streak_freezes == Content.STREAK_FREEZE_START and pr.pearls == 5, "old saves start with a fresh flame and one ice cube")


func test_corrupted() -> void:
	_fresh()
	var f := FileAccess.open(pr.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "streak": {"count": -4, "best": "x", "last": "tomorrow", "freezes": 99,
			"claimed": [1], "log": {"bad": "play", day(1): "lava"}, "reward": {"pearls": 1e9}}}))
	f.close()
	pr.reset()
	check(pr.load_game(), "a strange streak still loads")
	check(pr.streak_count == 0 and pr.streak_last == "" and pr.streak_freezes == Content.STREAK_FREEZE_MAX, "bad values are cleaned")
	check(pr.streak_log.is_empty() and int(pr.streak_reward.get("pearls", 0)) <= 1000, "bad log and huge rewards are dropped")


func test_strings() -> void:
	var keys := ["STREAK", "STREAK_DAYS_ONE", "STREAK_DAYS_FEW", "STREAK_DAYS_MANY", "STREAK_WELCOME", "STREAK_ICE_HINT", "WEEKDAY_0", "WEEKDAY_6",
			"GOAL_STREAK_14", "GOAL_STREAK_30", "ITEM_HAT_FLAME", "ITEM_BOAT_FLAME"]
	for lang in ["en", "ru", "es", "zh"]:
		TranslationServer.set_locale(lang)
		for k in keys:
			check(TranslationServer.translate(k) != k, "%s has %s" % [lang, k])
		var hint := TranslationServer.translate("STREAK_ICE_HINT")
		check(hint.count("%d") == 2, "%s ice hint has two numbers" % lang)
	# Kids rules: no countdowns or threats in the streak texts.
	var f := FileAccess.open("res://i18n/streak.csv", FileAccess.READ)
	var text := f.get_as_text().to_lower()
	for bad in ["lose", "lost", "die", "hurry", "потеря", "сгор", "погас", "торопись", "perder", "失去"]:
		check(not bad in text, "no pressure words (%s)" % bad)
	TranslationServer.set_locale("ru")
	var sv = load("res://scripts/ui/streak_view.gd")
	check(sv.days_text(1) == "1 день подряд" and sv.days_text(3) == "3 дня подряд" and sv.days_text(5) == "5 дней подряд" and sv.days_text(21) == "21 день подряд" and sv.days_text(12) == "12 дней подряд", "Russian plurals")
	TranslationServer.set_locale("en")
	check(sv.days_text(1) == "1 day in a row" and sv.days_text(2) == "2 days in a row", "English plurals")
