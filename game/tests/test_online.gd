extends SceneTree
## Online features without a network: promo codes, leaderboard names, week
## numbers, invites, the founder gift and the online save (OnlineRules and
## the Online autoload with a pretend backend, tests/online_fake.gd).

var fails := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _unix(y: int, mo: int, d: int, h: int = 0, mi: int = 0, s: int = 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": s}))


func _initialize() -> void:
	await process_frame
	var online: Node = root.get_node("Online")
	var gs: Node = root.get_node("GameState")
	var pr: Node = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	gs.reset()
	pr.reset()
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()

	# --- Promo codes: normalised, hashed, once each ---------------------------------
	_check(OnlineRules.normalize_code("  coraLight \n") == "CORALIGHT", "codes are trimmed and upper-cased")
	_check(OnlineRules.hash_code(" coralight ") == "93b4090a74ac713f7867338ec6fa135499d4053cfdb81dc592c4c5c9ea892856", "hash of CORALIGHT")
	_check(int(OnlineRules.promo("dive2026").get("pearls", 0)) == 30, "DIVE2026 gives 30 pearls")
	_check(int(OnlineRules.promo("DIVE2026").get("boost", 0)) == 3600, "DIVE2026 gives an hour of x2")
	_check(OnlineRules.promo("thankyou").get("item", "") == OnlineRules.EXCLUSIVE_ITEM, "THANKYOU gives the exclusive item")
	_check(OnlineRules.promo("CORALIGHT2").is_empty() and OnlineRules.promo("").is_empty() and OnlineRules.promo("   ").is_empty(), "unknown codes give nothing")
	for h in OnlineRules.PROMOS:
		_check(str(h).length() == 64, "promo keys are SHA-256 hex")
	var src := FileAccess.get_file_as_string("res://scripts/data/online_rules.gd") + FileAccess.get_file_as_string("res://scripts/autoload/online.gd")
	for plain in ["CORALIGHT\"", "DIVE2026", "THANKYOU"]:
		_check(not src.contains(plain), "no plain code %s in the code" % plain)
	var p0: int = pr.pearls
	var r: Dictionary = online.redeem(" Coralight ")
	_check(r["result"] == "ok" and pr.pearls == p0 + 50, "CORALIGHT: +50 pearls")
	_check(online.redeem("CORALIGHT")["result"] == "used", "a code works once")
	_check(online.redeem("NOPE123")["result"] == "bad", "a wrong code is refused")
	var b0: float = gs.boost_left
	_check(online.redeem("dive2026")["result"] == "ok" and gs.boost_left >= b0 + 3500.0 and pr.pearls == p0 + 80, "DIVE2026: pearls and an hour of x2")
	_check(not pr.is_owned(OnlineRules.EXCLUSIVE_ITEM), "no exclusive item before THANKYOU")
	_check(online.redeem("THANKYOU")["result"] == "ok" and pr.is_owned(OnlineRules.EXCLUSIVE_ITEM) and online.has_exclusive(), "THANKYOU: the exclusive item")
	_check(pr.pearls == p0 + 105, "THANKYOU: +25 pearls")
	_check(online.pending_thanks.size() == 3, "each code queues a thank-you dialog")
	online.pending_thanks.clear()
	var item := Content.cosmetic(OnlineRules.EXCLUSIVE_ITEM)
	_check(item.get("unlock") == "exclusive" and item.get("slot") == "hat", "the exclusive item is a hat that is never sold")
	_check(not pr.buy_item(OnlineRules.EXCLUSIVE_ITEM), "the exclusive item cannot be bought")
	_check("founder" in HatsArt.IDS, "the Founder Cap is drawn")

	# --- Names --------------------------------------------------------------------------
	_check(OnlineRules.strip_name("  Ma\u0007ry​  ") == "Mary", "control and zero-width characters go")
	_check(OnlineRules.strip_name("A") == "" and OnlineRules.strip_name("  ") == "", "names under 2 letters are empty")
	_check(OnlineRules.strip_name("Abcdefghijklmnopqrstuvwxyz").length() == 16, "names are cut to 16")
	_check(OnlineRules.strip_name("Big    Fish") == "Big Fish", "runs of spaces shrink")
	var uid := "Abc12345zzzzzzzzzzzzzzzzzzzz"
	var fb := OnlineRules.fallback_name(uid)
	_check(fb.begins_with("Diver") and fb.length() == 9 and fb == OnlineRules.fallback_name(uid), "fallback Diver#### is stable")
	for bad in ["Fuck you", "sh1t", "BITCH", "f.u.c.k", "сука", "Сyка", "хуй123", "пиздец", "puta madre", "Mierda", "cabrón", "Joder"]:
		_check(OnlineRules.board_name(bad, uid) == fb, "blocked: " + bad)
	for good in ["Marina", "Корабль", "Скорость", "Grape", "Dickens", "Команда", "Conor", "Хлебушек", "小海豚", "Pepe"]:
		_check(OnlineRules.board_name(good, uid) == good, "allowed: " + good)
	_check(OnlineRules.board_name("x", uid) == fb, "too short becomes Diver####")

	# --- Weeks (Monday 00:00 UTC) ----------------------------------------------------------
	_check(OnlineRules.week_id(_unix(1970, 1, 5)) == 0, "1970-01-05 (Monday) is week 0")
	_check(OnlineRules.week_id(_unix(1970, 1, 4, 23, 59, 59)) == -1, "the Sunday before is week -1")
	var mon := _unix(2026, 10, 5)
	var w := OnlineRules.week_id(mon)
	_check(OnlineRules.week_id(mon - 1.0) == w - 1, "Sunday 23:59:59 is the week before")
	_check(OnlineRules.week_id(mon + 7.0 * 86400.0 - 1.0) == w, "next Sunday 23:59:59 is the same week")
	_check(OnlineRules.week_id(mon + 7.0 * 86400.0) == w + 1, "next Monday 00:00 starts a new week")
	_check(OnlineRules.week_start(w) == mon, "week_start gives Monday 00:00")
	_check(OnlineRules.week_id(_unix(2026, 10, 11, 12)) == w, "Sunday noon belongs to the week from Monday")
	_check(int(Time.get_datetime_dict_from_unix_time(int(OnlineRules.week_start(w + 30)))["weekday"]) == Time.WEEKDAY_MONDAY, "weeks always start on a Monday")

	# --- Week tracking --------------------------------------------------------------------
	gs.total_earned = 1000.0
	online.data["week"] = -1
	online.data["seen_total"] = -1.0
	online.track(mon + 3600.0)
	_check(float(online.data["week_score"]) == 0.0, "the first look counts nothing yet")
	gs.total_earned = 1500.0
	online.track(mon + 7200.0)
	_check(float(online.data["week_score"]) == 500.0, "coins earned add to the week")
	_check(float(online.data["all_best"]) == 1500.0, "all-time follows total earned")
	gs.total_earned = 200.0
	online.track(mon + 7300.0)
	_check(float(online.data["week_score"]) == 500.0 and float(online.data["all_best"]) == 1500.0, "a reset save never lowers the scores")
	gs.total_earned = 900.0
	online.track(mon + 7.0 * 86400.0 + 10.0)
	_check(float(online.data["week_score"]) == 700.0 and int(online.data["week"]) == w + 1, "a new week starts from zero (plus coins since the last look)")
	gs.total_earned = 1200.0
	online.track(mon + 7.0 * 86400.0 + 20.0)
	_check(float(online.data["week_score"]) == 1000.0, "and counts on")

	# --- Invites: who may use one -------------------------------------------------------------
	_check(OnlineRules.code_of(uid) == "Abc12345", "invite code = first 8 letters of the id")
	_check(OnlineRules.invite_ok("Zzz98765", "Abc12345", "", 0.0), "a new save may use a friend's code")
	_check(not OnlineRules.invite_ok("Abc12345", "Abc12345", "", 0.0), "not the player's own code")
	_check(not OnlineRules.invite_ok("Zzz98765", "Abc12345", "Qqq11111", 0.0), "not when already referred")
	_check(not OnlineRules.invite_ok("Zzz98765", "Abc12345", "", 1.0e6), "not for a save that already played")
	_check(not OnlineRules.invite_ok("ab", "", "", 0.0) and not OnlineRules.invite_ok("bad code!", "", "", 0.0), "malformed codes are ignored")
	_check(OnlineRules.invite_due(3, 0) == 3 and OnlineRules.invite_due(3, 2) == 1 and OnlineRules.invite_due(2, 2) == 0, "friends are paid once")
	_check(OnlineRules.invite_due(40, 0) == OnlineRules.INVITE_CAP and OnlineRules.invite_due(40, 20) == 0, "at most 20 friends")

	# --- Online with a pretend backend: founder, joining, inviter ----------------------------
	pr.reset()
	pr.owned.erase(OnlineRules.EXCLUSIVE_ITEM)
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()
	online.pending_thanks.clear()
	gs.total_earned = 0.0
	var fake = load("res://tests/online_fake.gd").new()
	fake.uid = "Newb0001qqqqqqqqqqqqqqqqqqqq"
	fake.founders = 41
	fake.invites["Frnd0001"] = {"someone": true}
	online.take_ref("Frnd0001")
	_check(online.data["ref_pending"] == "Frnd0001", "an invite waits for the network")
	var before: int = pr.pearls
	online.use_backend(fake)
	_check(online.available() and online.uid == fake.uid, "online is ready with the backend")
	_check(online.invite_code() == "Newb0001", "the invite code comes from the id")
	_check(int(online.data["founder"]) == 42 and fake.founders == 42, "founder number = counter + 1")
	_check(online.data["referred_by"] == "Frnd0001" and online.data["ref_pending"] == "", "joined the friend's invite")
	_check(fake.invites["Frnd0001"].has(fake.uid), "the inviter can see the join")
	_check(pr.pearls == before + OnlineRules.FOUNDER_PEARLS + OnlineRules.JOIN_PEARLS, "founder +100 and invite +30 pearls")
	_check(pr.is_owned(OnlineRules.EXCLUSIVE_ITEM), "founders get the exclusive item")
	var kinds := []
	for t in online.pending_thanks:
		kinds.append(t["kind"])
	_check("founder" in kinds and "join" in kinds, "thank-you dialogs for founder and invite")
	online.pending_thanks.clear()
	var p1: int = pr.pearls
	online.claim_founder()
	_check(pr.pearls == p1 and int(online.data["founder"]) == 42, "the founder gift comes once")
	online.take_ref("Other001")
	_check(online.data["ref_pending"] == "" and online.data["referred_by"] == "Frnd0001", "a second invite does nothing")
	# Friends join with this player's link.
	fake.invites["Newb0001"] = {"a": true, "b": true, "c": true}
	online.check_invites()
	_check(pr.pearls == p1 + 3 * OnlineRules.INVITE_PEARLS and online.friends_paid() == 3, "3 friends: +90 pearls")
	online.check_invites()
	_check(pr.pearls == p1 + 90, "friends are not paid twice")
	for i in 30:
		fake.invites["Newb0001"]["x%d" % i] = true
	online.check_invites()
	_check(online.friends_paid() == OnlineRules.INVITE_CAP and pr.pearls == p1 + 20 * OnlineRules.INVITE_PEARLS, "capped at 20 friends")
	# Another online id (signed in with Google elsewhere): its own code and
	# friends; coming back to the first id pays nothing twice.
	var other = load("res://tests/online_fake.gd").new()
	other.uid = "Goog0001qqqqqqqqqqqqqqqqqqqq"
	other.founders = 100
	other.invites["Goog0001"] = {"f1": true, "f2": true}
	var p3: int = pr.pearls
	online.use_backend(other)
	_check(online.invite_code() == "Goog0001" and pr.pearls == p3 + 2 * OnlineRules.INVITE_PEARLS, "a new id has its own code and friends")
	fake.founders = 100
	online.use_backend(fake)
	_check(online.invite_code() == "Newb0001" and pr.pearls == p3 + 2 * OnlineRules.INVITE_PEARLS, "back on the first id: no friend paid twice")
	_check(online.present(), "online buttons show with a backend")
	online.pending_thanks.clear()

	# The 101st player gets nothing; their own link is refused.
	var late = load("res://tests/online_fake.gd").new()
	late.uid = "Late0001qqqqqqqqqqqqqqqqqqqq"
	late.founders = 100
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()
	var p2: int = pr.pearls
	online.use_backend(late)
	_check(online.data["founder_done"] and int(online.data["founder"]) == 0 and pr.pearls == p2, "after 100 founders: no gift")
	online.take_ref("Late0001")
	_check(online.data["ref_done"] and online.data["referred_by"] == "" and pr.pearls == p2, "own invite link gives nothing")
	# A save that already played is not "new".
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()
	gs.total_earned = 5.0e5
	online.take_ref("Frnd0001")
	_check(online.data["referred_by"] == "" and online.data["ref_pending"] == "", "old saves don't get the invite bonus")
	# The network fails: the invite stays for later, nothing breaks.
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()
	gs.total_earned = 0.0
	var down = load("res://tests/online_fake.gd").new()
	down.uid = "Down0001qqqqqqqqqqqqqqqqqqqq"
	down.fail = "error:timeout"
	online.use_backend(down)
	online.take_ref("Frnd0001")
	_check(online.data["ref_pending"] == "Frnd0001" and not online.data["founder_done"], "failed requests are retried later")
	var got := [null]
	online.fetch_board("all", func(res): got[0] = res)
	_check(got[0] is Dictionary and not got[0]["ok"], "a failed board says so")

	# --- Scores and the board --------------------------------------------------------------------
	var lb = load("res://tests/online_fake.gd").new()
	lb.uid = "Ldr00001qqqqqqqqqqqqqqqqqqqq"
	lb.seed(60)
	lb.founders = 100
	DirAccess.remove_absolute(online.SAVE_PATH)
	online.load_data()
	gs.total_earned = 0.0
	online.use_backend(lb)
	gs.total_earned = 5000.0
	online._since_submit = 9999.0
	online._boards = {}
	online.fetch_board("all", func(res): got[0] = res)
	var bd: Dictionary = got[0]
	_check(bd["ok"] and bd["rows"].size() == 50, "the board shows the top 50")
	_check(lb.all.has(lb.uid) and float(lb.all[lb.uid]["score"]) == 5000.0, "opening the board sends the score")
	_check(int(bd["rank"]) > 50, "own place below the top 50 is known (%d)" % int(bd["rank"]))
	var sorted := true
	for i in range(1, bd["rows"].size()):
		sorted = sorted and float(bd["rows"][i - 1]["score"]) >= float(bd["rows"][i]["score"])
	_check(sorted, "rows are sorted by score")
	var n_calls: int = lb.calls.size()
	online.fetch_board("all", func(res): got[0] = res)
	_check(lb.calls.size() == n_calls, "a board read is reused for a minute")
	online.submit()
	_check(lb.calls.size() == n_calls, "no second submit within a minute")
	var parsed: Dictionary = online.parse_board(JSON.stringify({"rows": [{"uid": "x1", "name": "сука", "score": 5}, {"uid": lb.uid, "name": "Me", "score": 3}], "rank": 2}), lb.uid)
	_check(parsed["rows"][0]["name"] == OnlineRules.fallback_name("x1"), "rude names from the server are hidden too")
	_check(parsed["rows"][1]["you"] and not parsed["rows"][0]["you"], "the player's own row is marked")
	_check(not online.parse_board("error:x", "")["ok"] and not online.parse_board("{\"rows\": 5}", "")["ok"], "bad answers are handled")

	# --- Save and load ---------------------------------------------------------------------------
	online.data["redeemed"] = {"p1": true, "p3": true}
	online.data["founder"] = 7
	online.data["founder_done"] = true
	online.data["referred_by"] = "Frnd0001"
	online.data["paid"] = {"Ldr00001": 4}
	online.data["exclusive"] = true
	online.data["week"] = w
	online.data["week_score"] = 1234.5
	online.data["all_best"] = 9.9e12
	online.data["code"] = "Ldr00001"
	online.save_data()
	var copy: Dictionary = online.data.duplicate(true)
	online.data = {}
	online.load_data()
	var same := true
	for k in copy:
		if str(copy[k]) != str(online.data[k]):
			same = false
			print("  differs: ", k, " ", copy[k], " / ", online.data[k])
	_check(same, "online.json keeps every field")
	var f := FileAccess.open(online.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	online.load_data()
	_check(online.data["founder"] == 0 and online.data["redeemed"].is_empty(), "a broken save starts fresh")
	_check("online.json" in load("res://scripts/autoload/cloud_save.gd").ROOT_FILES, "the cloud save carries online.json")
	# The exclusive item follows to every local profile.
	online.data["exclusive"] = true
	pr.owned.erase(OnlineRules.EXCLUSIVE_ITEM)
	online._keep_exclusive()
	_check(pr.is_owned(OnlineRules.EXCLUSIVE_ITEM), "exclusive item restored on another profile")

	DirAccess.remove_absolute(online.SAVE_PATH)
	print("test_online: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
