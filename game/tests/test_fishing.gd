extends SceneTree
## Fishing rules (odds, prices, bucket, selling, upgrades, the fisherman,
## saves) and a smoke test of the screen:
##   godot --headless --path . -s res://tests/test_fishing.gd
## Uses its own save files, never the player's.

var _failures := 0
var _checks := 0
var gs: Node
var fi: Node


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	fi = root.get_node("Fishing")
	var pr := root.get_node("Progress")
	for n: Node in [gs, fi, pr]:
		n.autosave_enabled = false
	gs.save_path = "user://test_fishing_game.json"
	pr.save_path = "user://test_fishing_progress.json"
	fi.save_path = "user://test_fishing.json"
	TranslationServer.set_locale("en")
	test_scripts_compile()
	test_data()
	test_odds()
	test_prices()
	test_bucket_and_selling()
	test_upgrades()
	test_helper()
	test_save_roundtrip()
	test_corrupted_save()
	test_translations()
	await test_screen()
	print("%d checks, %d failed" % [_checks, _failures])
	for f in ["user://test_fishing_game.json", "user://test_fishing_progress.json", "user://test_fishing.json"]:
		DirAccess.remove_absolute(f)
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	gs.reset()
	fi.reset()
	fi.rng.seed = 1234


func test_scripts_compile() -> void:
	for path in ["res://scripts/fishing/fish_data.gd", "res://scripts/fishing/fishing_state.gd", "res://scripts/fishing/fishing_screen.gd", "res://scripts/ui/fish_art.gd"]:
		var s: GDScript = load(path)
		check(s != null and s.can_instantiate(), "compiles: " + path)


func test_data() -> void:
	var ids := FishData.ids()
	check(ids.size() == 18, "18 species")
	var seen := {}
	for id in ids:
		seen[id] = true
	check(seen.size() == ids.size(), "species ids are unique")
	for r in 5:
		check(not FishData.of_rarity(r).is_empty(), "rarity %d has fish" % r)
	var total := 0.0
	for o in FishData.ODDS:
		total += o
	check(is_equal_approx(total, 100.0), "base odds add up to 100%")


func test_odds() -> void:
	_fresh()
	var n := 20000
	var counts := [0, 0, 0, 0, 0]
	for i in n:
		counts[FishData.rarity_of(str(fi.roll_fish()["id"]))] += 1
	var want := FishData.ODDS
	for r in 5:
		var got: float = counts[r] * 100.0 / n
		# Within 1.5 points (or a third for the rarest).
		check(absf(got - want[r]) < maxf(1.5, want[r] * 0.35), "rarity %d odds ~%.0f%% (got %.2f%%)" % [r, want[r], got])
	print("odds over %d rolls: %s" % [n, str(counts)])
	check(counts[4] > 0, "legendary fish do show up")
	# A better rod makes rare fish more likely.
	var base := FishData.odds(0)
	var best := FishData.odds(FishData.max_level("rod"))
	check(best[2] > base[2] and best[3] > base[3] and best[4] > base[4], "a better rod raises rare, epic and legendary odds")
	check(best[0] < base[0], "a better rod lowers common odds")
	# The fisherman only catches common and uncommon fish.
	var helper_ok := true
	for i in 2000:
		if FishData.rarity_of(str(fi.roll_fish(true)["id"])) > FishData.UNCOMMON:
			helper_ok = false
	check(helper_ok, "the fisherman only lands common/uncommon fish")


func test_prices() -> void:
	# Every size of a rarer fish is worth more than any size of a commoner one.
	for rate in [0.8, 10.0, 1.0e6, 1.0e15]:
		var ok := true
		for r in 4:
			var top := 0.0
			for id in FishData.of_rarity(r):
				top = maxf(top, FishData.price(id, FishData.species(id)["size"].y, rate))
			var low := INF
			for id in FishData.of_rarity(r + 1):
				low = minf(low, FishData.price(id, FishData.species(id)["size"].x, rate))
			ok = ok and low > top
		check(ok, "prices strictly ordered by rarity at %s coins/s" % NumFormat.short(rate))
	check(FishData.price("sardine", 16.0, 0.0) >= FishData.MIN_RATE * 10.0 * 0.8, "brand-new players get a price floor")
	var p1 := FishData.price("perch", 20.0, 100.0)
	var p2 := FishData.price("perch", 20.0, 1000.0)
	check(p2 > p1 * 9.0, "prices follow income")
	check(FishData.price("perch", 35.0, 100.0) > FishData.price("perch", 15.0, 100.0), "bigger fish are worth more")
	var koi := FishData.price("koi", 60.0, 50.0)
	check(absf(koi - 50.0 * 480.0 * 1.15) <= 2.0, "epic ~8 min of income at mid size (%s)" % koi)
	# Sizes stay in range.
	var in_range := true
	for id in FishData.ids():
		var r: Vector2 = FishData.species(id)["size"]
		for k in 11:
			var s := FishData.size_from_roll(id, k / 10.0)
			in_range = in_range and s >= r.x - 0.01 and s <= r.y + 0.01
	check(in_range, "rolled sizes stay in each species' range")


func test_bucket_and_selling() -> void:
	_fresh()
	check(fi.capacity() == FishData.BUCKET_BASE, "bucket starts at %d" % FishData.BUCKET_BASE)
	var all_fit := true
	for i in fi.capacity():
		all_fit = fi.keep(fi.make_fish(0)) and all_fit
	check(all_fit, "every fish fits until the bucket is full")
	check(fi.bucket.size() == fi.capacity() and fi.is_full(), "bucket fills up")
	check(not fi.keep(fi.make_fish(0)), "a full bucket takes no more")
	check(fi.bucket.size() == fi.capacity(), "still exactly full")
	var coins_before: float = gs.coins
	var one: float = fi.bucket[0]["value"]
	var got: float = fi.sell_at(0)
	check(is_equal_approx(got, one) and is_equal_approx(gs.coins, coins_before + one), "selling one fish pays its value")
	check(fi.bucket.size() == fi.capacity() - 1, "sold fish leaves the bucket")
	check(fi.sell_at(99) == 0.0, "selling a missing fish does nothing")
	var total: float = fi.bucket_value()
	coins_before = gs.coins
	var all: float = fi.sell_all()
	check(is_equal_approx(all, total) and is_equal_approx(gs.coins, coins_before + total), "sell all pays the bucket's value")
	check(fi.bucket.is_empty() and fi.sell_all() == 0.0, "bucket is empty after selling")
	var f: Dictionary = fi.make_fish(4)
	coins_before = gs.coins
	check(is_equal_approx(fi.sell_fish(f), f["value"]) and gs.coins > coins_before, "selling from the catch card pays")
	check(int(fi.stats.get("sold", 0)) == fi.capacity() + 1, "sold count adds up")
	# Fish book.
	var r1: Dictionary = fi.record({"id": "koi", "size": 40.0, "value": 1.0})
	check(r1["new"] and not r1["record"] and fi.has_found("koi"), "first koi is new")
	var r2: Dictionary = fi.record({"id": "koi", "size": 55.0, "value": 1.0})
	check(not r2["new"] and r2["record"], "a bigger koi is a record")
	var r3: Dictionary = fi.record({"id": "koi", "size": 30.0, "value": 1.0})
	check(not r3["record"] and fi.count_of("koi") == 3 and is_equal_approx(fi.best_of("koi"), 55.0), "book counts catches and keeps the best size")
	check(not fi.record({"id": "boot", "size": 1.0})["new"] and fi.found() == 1, "unknown ids are ignored")


func test_upgrades() -> void:
	_fresh()
	gs.coins = 0.0
	for kind in fi.UPGRADES:
		check(fi.upgrade_cost(kind) > 0.0 and not fi.can_buy(kind) and not fi.buy(kind), "%s needs coins" % kind)
	gs.coins = 1.0e12
	var cost: float = fi.upgrade_cost("bucket")
	check(fi.buy("bucket") and fi.capacity() == FishData.BUCKET_BASE + FishData.BUCKET_STEP, "bigger bucket holds more")
	check(is_equal_approx(gs.coins, 1.0e12 - cost), "buying takes the coins")
	check(fi.upgrade_cost("bucket") > cost, "next level costs more")
	check(fi.buy("rod") and fi.rod == 1, "rod upgrades")
	check(FishData.reel_zone(4, 1) > FishData.reel_zone(4, 0) and FishData.reel_speed(4, 1) < FishData.reel_speed(4, 0), "a better rod makes reeling easier")
	check(FishData.reel_zone(0, 0) > FishData.reel_zone(4, 0) and FishData.reel_speed(0, 0) < FishData.reel_speed(4, 0), "rarer fish are harder to reel")
	check(FishData.reel_zone(2, 0, 2) > FishData.reel_zone(2, 0, 0), "misses widen the zone")
	# Difficulty: a new rod is fine for common fish, rare ones want a better
	# rod, and every rod level shows (wider zone, slower fish, more tries).
	var top: int = FishData.max_level("rod")
	check(top + 1 == 20 and FishData.ROD_LEVELS == 20, "20 rod levels per world")
	check(FishData.reel_window(0, 0) >= 0.3, "a new rod reels common fish fine (%.2f s in the zone)" % FishData.reel_window(0, 0))
	check(FishData.reel_window(4, 0) <= 0.1 and FishData.reel_window(4, 0) >= 0.06, "a legendary on a new rod is really hard (%.2f s)" % FishData.reel_window(4, 0))
	check(FishData.reel_window(4, top) >= FishData.reel_window(4, 0) * 3.5, "the best rod makes a legendary about four times easier (%.2f s)" % FishData.reel_window(4, top))
	var easier := true
	for r in 5:
		for lv in top:
			easier = easier and FishData.reel_window(r, lv + 1) > FishData.reel_window(r, lv)
	check(easier, "every rod level helps with every fish")
	check(FishData.reel_window(4, 0, 2) >= 0.1, "misses make even a legendary catchable (%.2f s)" % FishData.reel_window(4, 0, 2))
	check(FishData.reel_dart(0, 0) == 0.0 and FishData.reel_dart(4, 0) > FishData.reel_dart(2, 0), "only rare fish dart, legendary ones most")
	check(FishData.reel_dart(4, top) < FishData.reel_dart(4, 0) * 0.6, "a better rod calms the darting")
	check(FishData.reel_grade(0.5, 0.5, 0.2) == 2 and FishData.reel_grade(0.57, 0.5, 0.2) == 1 and FishData.reel_grade(0.63, 0.5, 0.2) == 0, "the middle of the zone is Perfect, its edge a hit, outside a miss")
	check(FishData.reel_grade(0.5 + 0.1 + FishData.REEL_MARGIN * 0.9, 0.5, 0.2) == 1, "a tap a little late still counts")
	# A kid who taps within +-0.15 s of the right moment: what each rod lands.
	check(_catch_rate(0, 0, 0.15) >= 0.95, "rod 1 lands common fish (%.2f)" % _catch_rate(0, 0, 0.15))
	check(_catch_rate(4, 0, 0.15) <= 0.2, "rod 1 rarely lands a legendary (%.2f)" % _catch_rate(4, 0, 0.15))
	check(_catch_rate(4, 10, 0.15) >= 0.85 and _catch_rate(4, top, 0.15) >= 0.99, "rod 11 and up land legendaries (%.2f, %.2f)" % [_catch_rate(4, 10, 0.15), _catch_rate(4, top, 0.15)])
	var climbs := true
	for lv in range(0, 10, 2):
		climbs = climbs and _catch_rate(3, lv + 2, 0.2) > _catch_rate(3, lv, 0.2)
	check(climbs, "for a less exact kid every two rod levels land more epic fish")
	check(FishData.odds(top)[4] > FishData.odds(0)[4] * 2.5, "the best rod brings legendaries over 2.5x more often")
	check(FishData.reel_tries(top) > FishData.reel_tries(0) and FishData.reel_tries(0) >= 3, "a stronger line gives more tries")
	check(FishData.reel_hits(4) > FishData.reel_hits(0) and FishData.reel_hits(0) == 3, "big fish need more pulls")
	while fi.buy("rod"):
		pass
	check(fi.is_maxed("rod") and fi.upgrade_cost("rod") < 0.0 and not fi.buy("rod"), "rod stops at max")
	check(fi.rod == 19 and fi.capacity() == FishData.BUCKET_BASE + FishData.BUCKET_STEP + 9, "rod levels add bucket slots (+1 per 2)")
	# Every world has its own rod.
	fi.world_override = 2
	check(fi.rod == 0 and fi.upgrade_cost("rod") > 0.0, "the swamp rod starts at level 1")
	check(fi.buy("rod") and fi.rods[2] == 1 and fi.rods[0] == 19, "buying the swamp rod leaves the sea rod alone")
	gs.location = 1
	fi.world_override = -1
	check(fi.world() == 1 and fi.rod == 0, "the rod follows the player's world")
	gs.location = 0
	# Prices scale with income.
	gs.reset()
	var low: float = fi.upgrade_cost("helper")
	gs.levels["d0"] = 200
	gs.levels["lift"] = 200
	gs.levels["boat"] = 200
	gs.levels["plant"] = 200
	check(fi.upgrade_cost("helper") > low * 5.0, "upgrade prices follow income")


## Chance to land a fish of rarity r with rod level lv for a player whose
## taps are off by up to `err` seconds (evenly spread), with the mercy
## widening after each miss.
func _catch_rate(r: int, lv: int, err: float) -> float:
	var need := FishData.reel_hits(r)
	var tries := FishData.reel_tries(lv)
	var memo := {}
	return _catch_step(r, lv, err, 0, 0, need, tries, memo)


func _catch_step(r: int, lv: int, err: float, hits: int, misses: int, need: int, tries: int, memo: Dictionary) -> float:
	if hits >= need:
		return 1.0
	if misses >= tries:
		return 0.0
	var key := hits * 100 + misses
	if memo.has(key):
		return memo[key]
	var half := FishData.reel_zone(r, lv, misses) / 2.0 + FishData.REEL_MARGIN
	var p := minf(1.0, half / FishData.reel_speed(r, lv) / err)
	var v := p * _catch_step(r, lv, err, hits + 1, misses, need, tries, memo) + (1.0 - p) * _catch_step(r, lv, err, hits, misses + 1, need, tries, memo)
	memo[key] = v
	return v


func test_helper() -> void:
	_fresh()
	check(fi.advance(1000.0) == 0 and fi.bucket.is_empty(), "no fisherman, no fish")
	fi.helper = 1
	var iv: float = fi.helper_interval()
	check(is_equal_approx(iv, FishData.HELPER_SEC), "first fisherman: one fish every %d s" % int(FishData.HELPER_SEC))
	check(fi.advance(iv * 0.5) == 0, "no fish before the interval")
	check(fi.advance(iv * 0.5 + 0.01) == 1 and fi.bucket.size() == 1, "one fish after the interval")
	# Simulated time in small steps, like frames.
	var n := 0
	for i in int(iv * 3.0 / 0.25):
		n += fi.advance(0.25)
	check(n == 3 and fi.bucket.size() == 4, "3 more fish in 3 intervals (got %d)" % n)
	check(fi.found() >= 1 and int(fi.stats.get("helper", 0)) == 4, "his fish count in the book and stats")
	check(fi.advance(iv * 100.0) == fi.capacity() - 4 and fi.is_full(), "he stops when the bucket is full")
	check(fi.advance(iv * 10.0) == 0, "and waits while it stays full")
	fi.sell_at(0)
	check(fi.advance(0.1) == 1, "then goes on (his timer was ready)")
	fi.bucket = []
	fi.helper = FishData.max_level("helper")
	check(fi.helper_interval() < FishData.HELPER_SEC * 0.4, "upgrades make him much faster")


func test_save_roundtrip() -> void:
	_fresh()
	fi.rod = 3
	fi.rods[3] = 7
	fi.bucket_level = 2
	fi.helper = 2
	fi.keep({"id": "koi", "size": 44.5, "value": 1234.0})
	fi.keep({"id": "sardine", "size": 12.0, "value": 15.0})
	fi.record({"id": "koi", "size": 44.5})
	fi.record({"id": "golden", "size": 20.0})
	fi.helper_timer = 5.0
	fi.stats["sold"] = 7
	check(fi.save_game(), "save works")
	fi.reset()
	check(fi.bucket.is_empty() and fi.rod == 0, "reset clears")
	check(fi.load_game(), "load works")
	check(fi.rod == 3 and fi.rods[3] == 7 and fi.bucket_level == 2 and fi.helper == 2, "upgrades survive (a rod per world)")
	check(fi.bucket.size() >= 2 and fi.bucket[0]["id"] == "koi" and is_equal_approx(fi.bucket[0]["value"], 1234.0), "bucket survives")
	check(fi.has_found("golden") and fi.count_of("koi") == 1 and is_equal_approx(fi.best_of("koi"), 44.5), "book survives")
	check(int(fi.stats.get("sold", 0)) == 7, "stats survive")
	# Time away: the fisherman catches up (but only while there's room).
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fi.save_path))
	d["saved_at"] = Time.get_unix_time_from_system() - 3600.0
	var f := FileAccess.open(fi.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	fi.reset()
	fi.load_game()
	var away: int = fi.take_offline_catch()
	check(away > 0 and fi.is_full() and away == fi.capacity() - 2, "fisherman filled the bucket while away (%d fish)" % away)
	check(fi.take_offline_catch() == 0, "the away report is read once")


func test_corrupted_save() -> void:
	_fresh()
	var f := FileAccess.open(fi.save_path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(not fi.load_game() and fi.bucket.is_empty() and fi.rod == 0, "broken file starts fresh")
	f = FileAccess.open(fi.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rod": 999, "bucket_level": -4, "helper": "x", "helper_timer": 1.0e30,
			"bucket": [{"id": "boot", "size": 1, "value": 5}, {"id": "koi", "size": -3, "value": -9}, "junk"] + range(200).map(func(i): return {"id": "perch", "size": 20, "value": 1}),
			"book": {"koi": {"count": 2, "best": 50}, "boot": {"count": 1}, "perch": "x", "tang": {"count": -2}}, "stats": {"sold": 3, "bad": "x"}}))
	f.close()
	check(fi.load_game(), "odd values still load")
	check(fi.rod == FishData.max_level("rod") and fi.bucket_level == 0 and fi.helper == 0, "levels are clamped (an old single rod becomes the sea rod)")
	check(fi.bucket.size() == fi.capacity(), "bucket never loads over capacity")
	check(fi.bucket[0]["id"] == "koi" and fi.bucket[0]["size"] >= 0.0 and fi.bucket[0]["value"] >= 0.0, "unknown fish dropped, negatives fixed")
	check(fi.book.size() == 1 and fi.count_of("koi") == 2, "book keeps only good entries")
	check(fi.stats.get("sold") == 3 and not fi.stats.has("bad"), "stats keep only numbers")
	check(fi.helper_timer == 0.0, "timer clamped")


func test_translations() -> void:
	var keys := ["FISHING_CAST", "FISHING_PRESS_CAST", "FISHING_KEEP", "FISH_R_LEGENDARY", "DOCK_FISHING", "FEATURE_FISHING_DESC",
			"FISHING_PERFECT", "FISHING_ROD_NEXT", "FISHING_ROD_LADDER", "FISHING_STAT_RARE", "FISHING_PERFECT_BONUS"]
	for w in 4:
		keys.append(RodArt.name_key(w))
		for lv in 20:
			keys.append(RodArt.level_key(w, lv + 1))
	for id in FishData.ids():
		keys.append(FishData.name_key(id))
	for lang in ["en", "ru", "es", "zh"]:
		TranslationServer.set_locale(lang)
		var ok := true
		for k in keys:
			ok = ok and TranslationServer.translate(k) != k
		check(ok, "all fishing strings translated in " + lang)
	TranslationServer.set_locale("en")


## The real screen: cast, bite, reel (tapping in the zone), keep; sell all; close.
func test_screen() -> void:
	_fresh()
	var screen: Control = load("res://scripts/fishing/fishing_screen.gd").new()
	root.add_child(screen)
	screen.setup()
	var sold := [0.0]
	var done := [{}]
	screen.sold.connect(func(c, _from): sold[0] += c)
	screen.finished.connect(func(r): done[0] = r)
	await _frames(3)
	check(screen.state() == "idle", "starts ready to cast")
	screen._on_screen_tap()
	await _frames(30)
	check(screen.state() == "idle", "a tap on the water does not cast by itself")
	var act := _find(screen, "Action") as Button
	act.pressed.emit()
	await _frames(2)
	check(screen.state() == "cast", "the Cast button casts")
	screen._on_action()
	check(screen.state() == "cast", "early taps do nothing bad")
	await _wait_for(screen, "wait", 2.0)
	var wl: float = screen._wait_len
	screen._last_tap = -1.0
	screen._on_action()
	check(screen.state() == "wait" and screen._wait_len > wl, "a tap before the bite makes the fish wait a little")
	screen._wait_len = 0.0
	await _wait_for(screen, "bite", 3.0)
	check(screen.state() == "bite", "the float dips")
	screen._last_tap = -1.0
	screen._on_screen_tap()
	check(screen.state() == "reel", "a tap anywhere in time starts reeling")
	# A miss, then hits right in the zone.
	screen._marker = fposmod(screen._zone + 0.5, 1.0)
	screen._last_tap = -1.0
	screen._reel_tap()
	check(screen._misses == 1 and screen.state() == "reel", "a miss doesn't end it")
	check(screen._tries == FishData.reel_tries(fi.rod) and screen._need_hits == FishData.reel_hits(FishData.rarity_of(str(screen._fish["id"]))), "the reel uses the rod's tries and the fish's pulls")
	var v0: float = screen._fish["value"]
	for i in screen._need_hits:
		screen._marker = screen._zone
		screen._reel_tap()
	check(screen.state() == "land", "enough hits land the fish")
	check(screen._perfects == screen._need_hits and float(screen._fish["value"]) >= v0 * (1.0 + FishData.PERFECT_BONUS * screen._need_hits) - 1.0, "Perfect pulls make the fish worth more")
	await _wait_for(screen, "card", 3.0)
	check(screen.state() == "card" and fi.found() == 1, "catch card shows and the book has it")
	var card: Node = screen._card_layer.get_node_or_null("Card")
	check(card != null, "card is on screen")
	screen._card_choice("keep")
	check(fi.bucket.size() == 1 and screen.state() == "idle", "keep puts it in the bucket")
	# Letting the bite pass is friendly: back to idle.
	screen._on_action()
	screen._wait_len = 0.0
	await _wait_for(screen, "bite", 3.0)
	await _wait_for(screen, "away", FishData.BITE_WINDOW + 1.0)
	check(screen.state() == "away", "too slow: the fish swims away")
	await _wait_for(screen, "idle", 3.0)
	check(screen.state() == "idle", "and you can cast again")
	# Bucket panel: sell all.
	fi.keep(fi.make_fish(2))
	var coins_before: float = gs.coins
	var value: float = fi.bucket_value()
	screen.open_panel("bucket")
	await _frames(3)
	var btn := _find(screen._modal, "SellAll") as Button
	check(btn != null, "sell all button exists")
	if btn:
		btn.pressed.emit()
	await _frames(2)
	check(fi.bucket.is_empty() and is_equal_approx(gs.coins, coins_before + value), "sell all from the panel pays")
	check(is_equal_approx(sold[0], value), "sold signal carries the coins")
	for p in ["book", "shop"]:
		screen._modal.close()
		await _frames(12)
		screen.open_panel(p)
		await _frames(3)
		check(screen._modal.visible, p + " panel opens")
	var ladder := _find(screen._modal, "RodLadder")
	check(ladder != null and ladder.get_child_count() == 20, "the shop shows the ladder of 20 rods")
	gs.coins += 1.0e9
	screen._modal.rebuild()
	await _frames(2)
	var buy := _find(screen._modal, "BuyRod") as Button
	var rod_before: int = fi.rod
	check(buy != null, "the rod card has a buy button")
	if buy:
		buy.pressed.emit()
	await _frames(2)
	check(fi.rod == rod_before + 1, "the rod is bought from the ladder card")
	gs.coins -= 1.0e9
	screen._modal.close()
	await _frames(12)
	screen.close()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(screen) and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	check(not is_instance_valid(screen), "closing frees the screen")
	check(done[0].get("caught", 0) == 1 and is_equal_approx(float(done[0].get("coins", 0.0)), value), "finished reports the visit")


func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f:
			return f
	return null


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_for(screen: Control, state: String, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(screen) and screen.state() != state and Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame
