extends SceneTree
## Rewarded-ad x2 boost (Platform provider "test") and the Rivals League:
##   godot --headless --path . --resolution 390x844 -s res://tests/test_ads.gd
## Uses its own save files and never writes the player's league.

const SAVE := "user://test_ads_save.json"

var _failures := 0
var _checks := 0
var gs: Node
var pf: Node
var rv: Node
var pr: Node
var main: Node


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	pf = root.get_node("Platform")
	rv = root.get_node("Rivals")
	pr = root.get_node("Progress")
	gs.autosave_enabled = false
	gs.save_path = SAVE
	gs.reset()
	pr.autosave_enabled = false
	pr.save_path = "user://test_ads_progress.json"
	pr.reset()
	rv.autosave_enabled = false
	rv.save_path = "user://test_ads_rivals.json"
	rv.reset()
	TranslationServer.set_locale("en")
	test_provider_none()
	await test_test_provider_grants_boost()
	test_income_doubles()
	test_stacking_cap()
	test_save_load_keeps_boost()
	test_offline_counts_boost_only_while_on()
	test_old_save_boost()
	await test_failure_grants_nothing()
	await test_main_buttons()
	test_rivals_points()
	test_rivals_board()
	test_rivals_week_reward()
	test_strings()
	print("%d checks, %d failed" % [_checks, _failures])
	for f in [SAVE, "user://test_ads_progress.json", "user://test_ads_rivals.json"]:
		DirAccess.remove_absolute(f)
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


# --- Ads --------------------------------------------------------------------------

func test_provider_none() -> void:
	pf.set_provider("none")
	check(not pf.ads_available(), "no provider: no ads")
	var got := [null]
	pf.show_rewarded(func(ok): got[0] = ok)
	check(got[0] == false, "no provider: show_rewarded answers false at once")
	check(gs.boost_left == 0.0, "no provider: no boost")


func test_test_provider_grants_boost() -> void:
	gs.reset()
	pf.set_provider("test")
	check(pf.ads_available(), "test provider: ads available")
	var got := [null]
	pf.show_rewarded(func(ok):
		got[0] = ok
		if ok:
			gs.add_ad_boost())
	check(pf.ad_running and not pf.ads_available(), "one ad at a time")
	check(paused, "the game pauses during the ad")
	check(AudioServer.is_bus_mute(0), "the sound is muted during the ad")
	await create_timer(pf.TEST_AD_SEC + 0.5).timeout
	await _frames(2)
	check(got[0] == true, "the pretend ad ends as watched")
	check(not paused, "the game runs again after the ad")
	check(not AudioServer.is_bus_mute(0), "the sound is back after the ad")
	check(_approx(gs.boost_left, gs.AD_BOOST_SEC, 3.0), "watching gives 30 minutes of x2 (got %.0f s)" % gs.boost_left)


func test_income_doubles() -> void:
	gs.reset()
	gs.levels.merge({"d0": 20, "lift": 20, "boat": 20, "plant": 20}, true)
	var before: float = gs.income_rate()
	gs.add_ad_boost()
	var after: float = gs.income_rate()
	check(_approx(after, before * 2.0, before * 1e-6), "the boost doubles income (%.2f -> %.2f)" % [before, after])
	gs.boost_left = 0.0
	gs.advance(0.1)
	check(_approx(gs.income_rate(), before, before * 1e-6), "income is back to normal after the boost")


func test_stacking_cap() -> void:
	gs.reset()
	var n := 0
	while gs.add_ad_boost() and n < 50:
		n += 1
	var cap: float = gs.AD_BOOST_CAP_SEC
	check(n == int(cap / gs.AD_BOOST_SEC), "ads stack %d times up to the cap (got %d)" % [int(cap / gs.AD_BOOST_SEC), n])
	check(gs.boost_left <= cap + 1.0 and gs.boost_left >= cap - 5.0, "stacked boost stops at 4 h (%.0f s)" % gs.boost_left)
	check(not gs.can_ad_boost(), "the button dims at the cap")
	# Once some time passed, one more ad fits again.
	gs.boost_end -= gs.AD_BOOST_SEC
	check(gs.can_ad_boost(), "after 30 minutes one more ad fits")
	# Pearl boosts may go past the ad cap (up to 24 h), but ads never add on top.
	gs.add_boost(10.0 * 3600.0)
	check(not gs.add_ad_boost(), "no ad boost on top of a long pearl boost")


func test_save_load_keeps_boost() -> void:
	gs.reset()
	gs.add_ad_boost()
	gs.add_ad_boost()
	var end: float = gs.boost_end
	gs.save_game()
	gs.reset()
	check(gs.boost_left == 0.0, "reset clears the boost")
	gs.load_game()
	check(_approx(gs.boost_end, end, 0.01), "the boost end time is saved and loaded")
	check(gs.boost_left > 3500.0, "loaded boost still runs (%.0f s)" % gs.boost_left)


## Writes a save `away` seconds old whose boost ends `boost_after` seconds
## after it was saved; returns the offline coins.
func _offline(away: float, boost_after: float) -> float:
	gs.reset()
	gs.levels.merge({"d0": 30, "lift": 30, "boat": 30, "plant": 30}, true)
	for k in ["d0", "lift", "boat", "plant"]:
		gs.managers[k] = true
	gs.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var t: float = Time.get_unix_time_from_system()
	data["saved_at"] = t - away
	data["boost_end"] = t - away + boost_after if boost_after > 0.0 else 0.0
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	gs.reset()
	var before: float = gs.coins
	gs.load_game()
	gs.take_offline_report()
	return gs.coins - before


func test_offline_counts_boost_only_while_on() -> void:
	var none := _offline(3600.0, 0.0)
	var half := _offline(3600.0, 1800.0)
	var full := _offline(3600.0, 7200.0)
	check(none > 0.0, "offline earnings without boost")
	check(_approx(full, none * 2.0, none * 0.02), "a boost lasting the whole time away doubles offline coins (%.0f vs %.0f)" % [full, none])
	check(half > none * 1.3 and half < none * 1.7, "half the time boosted gives about x1.5 offline (%.2f)" % (half / none))
	check(gs._boosted and gs.boost_left > 3500.0, "a boost still running after the time away stays on")
	_offline(3600.0, 1800.0)
	check(gs.boost_left == 0.0 and not gs._boosted, "a boost that ran out while away is off after loading")


func test_old_save_boost() -> void:
	gs.reset()
	gs.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("boost_end")
	data["boost_left"] = 900.0
	data["saved_at"] = Time.get_unix_time_from_system() - 300.0
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	gs.load_game()
	check(_approx(gs.boost_left, 600.0, 3.0), "old saves: seconds left minus time away (%.0f)" % gs.boost_left)


func test_failure_grants_nothing() -> void:
	gs.reset()
	pf.set_provider("test")
	# Something shows the pretend ad (like the overlay) and the player skips.
	var skip := func(_s: float): (func(): pf.finish_test_ad(false)).call_deferred()
	pf.test_ad_requested.connect(skip)
	var got := [null]
	pf.show_rewarded(func(ok):
		got[0] = ok
		if ok:
			gs.add_ad_boost())
	await _frames(3)
	pf.test_ad_requested.disconnect(skip)
	check(got[0] == false, "a skipped ad reports false")
	check(pf.last_error == "skipped", "the reason is kept for the message")
	check(gs.boost_left == 0.0, "a skipped ad gives no boost")
	check(not paused, "the game runs again after a skipped ad")
	check(AdBoostScript().fail_text("skipped") == "AD_SKIPPED" and AdBoostScript().fail_text("unfilled") == "AD_FAIL" \
			and AdBoostScript().fail_text("adblock") == "AD_BLOCKED", "friendly message for each failure")


func AdBoostScript() -> GDScript:
	return load("res://scripts/ui/ad_boost.gd")


func test_main_buttons() -> void:
	gs.reset()
	pr.features["quests"] = true
	pf.set_provider("none")
	load("res://scripts/ui/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(6)
	main = current_scene
	await _frames(2)
	check(not main._boost_btn.visible, "provider none: the x2 button is hidden")
	check(not main._rivals_btn.visible, "no weekly reward: no trophy button")
	pf.set_provider("test")
	await _frames(2)
	check(main._boost_btn.visible, "provider test: the x2 button shows")
	rv.last = {"week": rv.week - 1, "place": 2, "pearls": 15, "claimed": false}
	await _frames(2)
	check(main._rivals_btn.visible, "a waiting weekly reward shows the trophy")
	check(main._rivals_btn.position.y > main._boost_btn.position.y, "the trophy sits under the x2 button")
	rv.last = {}
	# The Profile has the league button.
	main.open_profile()
	await _frames(3)
	var league: Button = null
	for b in main._modal.find_children("*", "Button", true, false):
		if b.text.begins_with(TranslationServer.translate("RIVALS")):
			league = b
	check(league != null, "the Profile has a Rivals League button")
	if league:
		league.pressed.emit()
		await _frames(3)
		check(main._modal.visible and main._modal.find_children("*", "ArtView", true, false).size() >= 16, "it opens the league board")
	main._modal.close()
	await _frames(12)
	# The whole flow through the real UI: button -> offer -> watch -> overlay.
	main._boost_btn.pressed.emit()
	await _frames(3)
	check(main._modal.visible, "the button opens the offer")
	var watch: Button = null
	var no_btn: Button = null
	for b in main._modal.find_children("*", "Button", true, false):
		if b.text == TranslationServer.translate("BOOST_WATCH"):
			watch = b
		elif b.text == TranslationServer.translate("BOOST_NO"):
			no_btn = b
	check(watch != null and no_btn != null, "offer has Watch and No thanks")
	if watch == null:
		return
	await _frames(2)
	check(no_btn.size.is_equal_approx(watch.size), "Watch and No thanks are the same size")
	watch.pressed.emit()
	await _frames(3)
	check(main._ad_overlay.visible, "the pretend ad overlay shows")
	check(paused, "the game is paused under the overlay")
	await create_timer(pf.TEST_AD_SEC + 0.6).timeout
	await _frames(3)
	check(not main._ad_overlay.visible, "the overlay closes after 3 s")
	check(_approx(gs.boost_left, gs.AD_BOOST_SEC, 5.0), "watching through the UI gives the boost")
	check(main._toast.visible, "a toast tells about the boost")
	# Skip through the overlay: no reward.
	gs.boost_left = 0.0
	AdBoostScript().watch_ad(main)
	await _frames(3)
	main._ad_overlay._skip.pressed.emit()
	await _frames(3)
	check(gs.boost_left == 0.0, "skipping the pretend ad gives nothing")
	check(main._toast_label.text == TranslationServer.translate("AD_SKIPPED"), "skipping shows a friendly line")
	# The league opens.
	main.open_rivals()
	await _frames(3)
	check(main._modal.visible, "the trophy opens the Rivals League")
	pf.set_provider("none")


# --- Rivals League -------------------------------------------------------------------

func test_rivals_points() -> void:
	# No quests this time: finishing one would add its own stars.
	pr.features["quests"] = false
	pr.quests = []
	rv.reset()
	gs.reset()
	gs.coins = 1e9
	gs.upgrade("d0", 10)
	check(rv.points == 10, "upgrade levels give stars (%d)" % rv.points)
	gs.hire_manager("d0")
	check(rv.points == 20, "a manager gives 10 stars (%d)" % rv.points)
	gs.open_depth("d1")
	check(rv.points == 45, "a new depth gives 25 stars (%d)" % rv.points)
	var before: int = rv.points
	for i in 20:
		gs.tap("d0")
	check(rv.points == before, "taps give no stars (autoclickers win nothing)")
	pr.stats["puzzles_won"] = int(pr.stats.get("puzzles_won", 0)) + 2
	rv.poll()
	check(rv.points == before + 40, "won puzzles count when polled")


func test_rivals_board() -> void:
	rv.reset()
	rv.pace = 900.0
	var w: int = rv.week
	var a: Array = []
	var b: Array = []
	for i in rv.RIVALS.size():
		a.append(rv.rival_score(i, w, 0.5, 300))
		b.append(rv.rival_score(i, w, 0.5, 300))
	check(a == b, "rival scores are the same every time (no randomness)")
	var grows := true
	var follows := true
	for i in rv.RIVALS.size():
		var prev := -1
		for k in 15:
			var s: int = rv.rival_score(i, w, k / 14.0, 300)
			if s < prev:
				grows = false
			prev = s
		if rv.rival_score(i, w, 0.5, 600) <= rv.rival_score(i, w, 0.5, 300):
			follows = false
	check(grows, "rival scores never go down during a week")
	check(follows, "rivals keep near the player")
	# A usual week lands mid-board; a great one climbs; the top needs a lot.
	var usual: int = rv.place_of(900, w, 1.0)
	var great: int = rv.place_of(2000, w, 1.0)
	var huge: int = rv.place_of(4000, w, 1.0)
	check(usual >= 3 and usual <= 6, "a usual week is mid-board (#%d)" % usual)
	check(great < usual, "a great week climbs (#%d)" % great)
	check(huge == 1, "a huge week takes first place")
	check(rv.place_of(0, w, 1.0) == rv.RIVALS.size() + 1, "no play: last place")
	rv.points = 500
	var rows: Array = rv.board()
	check(rows.size() == rv.RIVALS.size() + 1, "board: the player and every rival")
	var sorted := true
	var you := 0
	for i in rows.size():
		if i > 0 and rows[i]["score"] > rows[i - 1]["score"]:
			sorted = false
		if rows[i]["you"]:
			you += 1
	check(sorted and you == 1, "board is sorted, the player once")


func test_rivals_week_reward() -> void:
	rv.reset()
	rv.points = 5000
	var pearls: int = pr.pearls
	check(not rv.reward_pending(), "no reward during the week")
	rv.time_offset = 8 * 86400.0
	rv.poll()
	check(rv.points == 0, "a new week starts from zero")
	check(rv.reward_pending() and int(rv.last["place"]) == 1, "last week's first place waits (#%s)" % str(rv.last.get("place")))
	check(rv.pace > rv.START_PACE, "a strong week raises the rivals' pace")
	var n: int = rv.claim()
	check(n == rv.REWARDS[0] and pr.pearls == pearls + n, "collect gives the first place pearls")
	check(not rv.reward_pending() and rv.claim() == 0, "the reward is collected once")
	# A week with no play gives nothing.
	rv.time_offset = 16 * 86400.0
	rv.poll()
	check(not rv.reward_pending(), "no stars, no pearls")
	rv.time_offset = 0.0
	rv.reset()
	# Save and load keep stars and the waiting reward.
	rv.points = 77
	rv.last = {"week": rv.week - 1, "place": 3, "pearls": 10, "claimed": false}
	rv.save_game()
	rv.reset()
	rv.load_game()
	check(rv.points == 77 and rv.reward_pending(), "league saves and loads")


func test_strings() -> void:
	var keys := ["BOOST_BTN", "BOOST_TITLE", "BOOST_OFFER", "BOOST_LEFT", "BOOST_FULL", "BOOST_WATCH", "BOOST_NO", "BOOST_GOT",
		"AD_FAIL", "AD_BLOCKED", "AD_SKIPPED", "AD_TEST", "AD_TEST_NOTE", "AD_SKIP", "RIVALS", "RIVALS_SUB", "RIVALS_HOW",
		"RIVALS_YOU", "RIVALS_REWARDS", "RIVALS_LAST", "RIVALS_CLAIM", "RIVALS_SUB_CPU", "RIVALS_CPU", "RIVALS_GAP", "RIVALS_TOP"]
	for r in rv.RIVALS:
		keys.append("RIVAL_" + str(r["id"]).to_upper())
	var missing := []
	for lang in ["en", "ru", "es", "zh"]:
		TranslationServer.set_locale(lang)
		for k in keys:
			if TranslationServer.translate(k) == k:
				missing.append(lang + ":" + k)
	TranslationServer.set_locale("en")
	check(missing.is_empty(), "every new string in 4 languages %s" % str(missing))
	# Kids rule: the board says plainly that the rivals are the computer.
	check(TranslationServer.translate("RIVALS_SUB_CPU").to_lower().find("computer") >= 0 and TranslationServer.translate("RIVALS_CPU") == "Computer", "rivals are labelled as computer characters")
