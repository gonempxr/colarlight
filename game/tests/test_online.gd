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

	# --- Names: stronger filter, one owner per name ----------------------------------------
	for bad in ["nigger", "N1gg3r", "gay", "Gay Boy", "epstein", "Epst3in", "BigAssDiver", "гей", "пидр", "Hitler88", "sexy", "кончай секс"]:
		_check(OnlineRules.is_rude(bad), "blocked name: %s" % bad)
	for good in ["Lev", "геймер", "Gamer", "Spicy", "Assistant", "Classic", "Cucumber", "Canal", "Хачапури", "Peacock", "Dickens"]:
		_check(not OnlineRules.is_rude(good), "allowed name: %s" % good)
	_check(OnlineRules.name_key("Big Lev") == "biglev" and OnlineRules.name_key("LEV") == OnlineRules.name_key("lev"), "name keys ignore case and spaces")
	_check(OnlineRules.strip_name("a/b") == "ab", "slashes are taken out of names")
	_check(OnlineRules.is_fallback("Diver0042") and not OnlineRules.is_fallback("Diver42") and not OnlineRules.is_fallback("Lev"), "Diver#### is the fallback name")
	var nf = load("res://tests/online_fake.gd").new()
	nf.names["lev"] = "Someone0xxxxxxxxxxxxxxxxxxxx"
	online.data["claimed"] = ""
	online.data["claimed_by"] = ""
	online.data["taken"] = ""
	online.use_backend(nf)
	var keep_name: String = root.get_node("Profiles").player_name()
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "Lev")
	_check(online.name_state() == "wait" and OnlineRules.is_fallback(online.board_name()), "a new name shows Diver#### until it is claimed")
	var claim_res := [""]
	online.claim_name(func(rr: String): claim_res[0] = rr)
	_check(claim_res[0] == "taken" and online.name_state() == "taken" and OnlineRules.is_fallback(online.board_name()), "a taken name stays Diver####")
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "Lev Two")
	online.claim_name(func(rr: String): claim_res[0] = rr)
	_check(claim_res[0] == "ok" and online.board_name() == "Lev Two" and nf.names.get("levtwo", "") == nf.uid, "a free name becomes the player's")
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "Lev Three")
	online.claim_name(func(rr: String): claim_res[0] = rr)
	_check(claim_res[0] == "ok" and not nf.names.has("levtwo") and nf.names.get("levthree", "") == nf.uid, "renaming lets the old name go")
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "fuck")
	_check(online.name_state() == "rude" and OnlineRules.is_fallback(online.board_name()), "a rude name is never shown")
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, keep_name)

	# --- Saturday x2 and the weekly race ------------------------------------------------------
	_check(OnlineRules.weekday(_unix(2026, 10, 12, 12)) == 0, "2026-10-12 is a Monday")
	_check(OnlineRules.is_x2_day(_unix(2026, 10, 17, 0, 0, 1)) and OnlineRules.is_x2_day(_unix(2026, 10, 17, 23, 59)), "Saturday is the x2 day (UTC)")
	_check(not OnlineRules.is_x2_day(_unix(2026, 10, 16, 23, 59)) and not OnlineRules.is_x2_day(_unix(2026, 10, 18, 0, 1)), "only Saturday")
	gs.x2_days_on = false
	var base_mult: float = gs.income_mult()
	gs.x2_day = true
	_check(is_equal_approx(gs.income_mult(), base_mult * 2.0), "the x2 day doubles income")
	gs.x2_day = false
	_check(OnlineRules.week_prize(1, 10.0)["pearls"] == 500 and OnlineRules.week_prize(1, 10.0)["boost"] == 4 * 3600, "1st place: 500 pearls and 4 h of x2")
	_check(OnlineRules.week_prize(3, 10.0)["pearls"] == 300 and OnlineRules.week_prize(10, 10.0)["pearls"] == 150, "top 3 and top 10")
	_check(OnlineRules.week_prize(50, 1.0)["pearls"] == 75 and OnlineRules.week_prize(100, 1.0)["pearls"] == 40, "top 50 and top 100")
	_check(OnlineRules.week_prize(5000, 1.0)["pearls"] == 20 and OnlineRules.week_prize(0, 1.0)["pearls"] == 20, "everyone who raced gets a little")
	_check(OnlineRules.week_prize(1, 0.0).is_empty(), "no score, no prize")
	var now_w := OnlineRules.week_id(Time.get_unix_time_from_system())
	nf.weeks[now_w - 1] = {"A": {"name": "a", "score": 900.0, "a": ""}, "B": {"name": "b", "score": 500.0, "a": ""}, nf.uid: {"name": "me", "score": 700.0, "a": ""}}
	online.data["prize_week"] = -1
	online.pending_thanks.clear()
	var pw0: int = pr.pearls
	online.check_week_prize()
	_check(pr.pearls == pw0 + 300 and int(online.data["prize_week"]) == now_w - 1, "2nd place last week: 300 pearls")
	_check(online.pending_thanks.size() == 1 and online.pending_thanks[0]["kind"] == "week" and int(online.pending_thanks[0]["n"]) == 2, "a week results dialog")
	online.check_week_prize()
	_check(pr.pearls == pw0 + 300, "the week prize is paid once")
	online.pending_thanks.clear()

	var ach: GDScript = load("res://scripts/data/achievements.gd")
	var dc: GDScript = load("res://scripts/data/daily_challenge.gd")
	# --- Titles, seasons, profile card -------------------------------------------------------
	_check(int(online.data["best_rank"]) == 2, "the best weekly place is kept")
	_check(online.title() == 2 and int(online.data["title_week"]) == now_w, "2nd place: Master title this week")
	_check(online.title(OnlineRules.week_start(now_w + 1) + 10.0) == 0, "the title is worn one week only")
	_check(OnlineRules.title_for(1) == 3 and OnlineRules.title_for(3) == 2 and OnlineRules.title_for(10) == 1 and OnlineRules.title_for(11) == 0 and OnlineRules.title_for(0) == 0, "title tiers")
	_check(OnlineRules.month_id(_unix(2026, 10, 12)) == 202610 and OnlineRules.prev_month(202601) == 202512 and OnlineRules.prev_month(202610) == 202609, "season ids")
	_check(OnlineRules.season_prize(1, 5.0) == 1000 and OnlineRules.season_prize(2, 5.0) == 600 and OnlineRules.season_prize(10, 5.0) == 300, "season prizes")
	_check(OnlineRules.season_prize(100, 5.0) == 80 and OnlineRules.season_prize(0, 5.0) == 30 and OnlineRules.season_prize(1, 0.0) == 0, "season prizes (low places, none)")
	var now_m := OnlineRules.month_id(Time.get_unix_time_from_system())
	nf.months[OnlineRules.prev_month(now_m)] = {"A": {"name": "a", "score": 900.0, "a": ""}, nf.uid: {"name": "me", "score": 999.0, "a": ""}}
	online.data["season_prize"] = -1
	var ps0: int = pr.pearls
	online.check_season_prize()
	_check(pr.pearls == ps0 + 1000 and online.pending_thanks.size() == 1 and online.pending_thanks[0]["kind"] == "season", "1st in last season: 1000 pearls and a dialog")
	online.check_season_prize()
	_check(pr.pearls == ps0 + 1000, "the season prize is paid once")
	online.pending_thanks.clear()
	online.data["month"] = now_m - 1
	online.track()
	_check(int(online.data["month"]) == now_m and float(online.data["month_score"]) == 0.0, "a new season starts from zero")
	var seen: float = online.data["seen_total"]
	gs.total_earned = seen + 1234.0
	online.track()
	_check(is_equal_approx(float(online.data["month_score"]), 1234.0), "season coins are counted")
	var prof: Dictionary = online.parse_profile(online.profile_info())
	_check(int(prof["t"]) == 2 and int(prof["r"]) == 2 and int(prof["wo"]) >= 1, "own profile card: title, best place, worlds")
	_check(online.profile_info().length() <= 200, "the profile field stays small")
	var odd: Dictionary = online.parse_profile('{"t": 99, "wo": 50, "b": -3, "c": "x[b]y"}')
	_check(int(odd["t"]) == 3 and int(odd["wo"]) == 4 and int(odd["b"]) == 0 and str(odd["c"]) == "xby", "odd profile values are clamped")
	_check(int(online.parse_profile("nonsense")["t"]) == 0, "a broken profile is empty")
	online._since_submit = 9999.0
	online.submit()
	_check(nf.months.get(now_m, {}).has(nf.uid) and str(nf.all[nf.uid].get("p", "")).begins_with("{"), "scores carry the season and the profile")

	# --- Friends board ----------------------------------------------------------------------
	nf.all["Friend01xxxxxxxxxxxxxxxxxxxx"] = {"name": "Friend", "score": 50.0, "a": ""}
	nf.invites[online.invite_code()] = {"Friend01xxxxxxxxxxxxxxxxxxxx": true}
	var fbx := [{}]
	online._boards.clear()
	online.fetch_board("friends", func(b): fbx[0] = b)
	var fuids: Array = fbx[0]["rows"].map(func(x): return x["uid"])
	_check(fbx[0]["ok"] and "Friend01xxxxxxxxxxxxxxxxxxxx" in fuids and nf.uid in fuids and fuids.size() == 2, "friends board: me and my friend only")

	# --- Clubs -------------------------------------------------------------------------------
	_check(OnlineRules.club_name("  Deep  Divers ") == "Deep Divers" and OnlineRules.club_name("ab") == "" and OnlineRules.club_name("gay club") == "", "club names are filtered")
	_check(OnlineRules.club_id_ok("Ab3dEf7h") and not OnlineRules.club_id_ok("short") and not OnlineRules.club_id_ok("bad/id!!"), "club codes")
	var cres := [""]
	online.club_create("ab", func(r): cres[0] = r)
	_check(cres[0] == "rude" and not online.in_club(), "a bad club name is refused")
	online.club_create("Coral Crew", func(r): cres[0] = r)
	var my_club: String = online.data["club"]
	_check(cres[0] == "ok" and online.in_club() and str(online.data["club_name"]) == "Coral Crew" and nf.clubs.has(my_club), "a club is made with me in it")
	_check(ach.has("club"), "joining a club unlocks its badge")
	var info := [{}]
	online.club_info(my_club, func(i): info[0] = i)
	_check(info[0]["ok"] and int(info[0]["n"]) == 1 and info[0]["members"][0]["you"], "my club shows me")
	nf.seed_clubs(int(online.data["week"]))
	online.club_join("Club0002", func(r): cres[0] = r)
	_check(cres[0] == "ok" and str(online.data["club"]) == "Club0002" and not nf.clubs[my_club]["m"].has(nf.uid), "joining another club leaves the old one")
	online.club_join("Club0005", func(r): cres[0] = r)
	_check(cres[0] == "ok", "join a big club")
	for i in 40:
		nf.clubs["Club0004"]["m"]["Fill%d" % i] = {"name": "f", "score": 1.0, "w": 0}
	online.club_join("Club0004", func(r): cres[0] = r)
	_check(cres[0] == "full" and str(online.data["club"]) == "Club0005", "a full club says so")
	online.club_join("Nope0000", func(r): cres[0] = r)
	_check(cres[0] == "gone", "an unknown code says so")
	online._boards.clear()
	online.fetch_board("clubs", func(b): fbx[0] = b)
	_check(fbx[0]["ok"] and fbx[0]["rows"].size() >= 5 and int(fbx[0]["rows"][0]["n"]) > 0, "the club board lists clubs with members")
	online.club_leave(func(r): cres[0] = r)
	_check(cres[0] == "ok" and not online.in_club() and str(online.data["club_name"]) == "", "leave the club")
	online.save_data()
	online.load_data()
	_check(int(online.data["best_rank"]) == 2 and int(online.data["season_prize"]) == OnlineRules.prev_month(now_m), "new fields survive a save")

	# --- Achievements and the challenge of the day ----------------------------------------------
	var a0: int = pr.pearls
	pr.stats["taps"] = 1000
	var got_b: Array = ach.check()
	_check("taps_1000" in got_b and ach.has("taps_1000") and pr.pearls >= a0 + 5, "a badge unlocks once, with pearls")
	_check(not "taps_1000" in ach.check(), "badges unlock once")
	for a in ach.LIST:
		_check(TranslationServer.translate("ACH_" + str(a[0]).to_upper()) != "ACH_" + str(a[0]).to_upper(), "badge %s has a name" % a[0])
	var day: int = dc.day_of(_unix(2026, 10, 12, 10))
	_check(dc.kind_for(day) == dc.kind_for(day), "the same challenge all day")
	pr.stats.erase("dc_day")
	dc.refresh(_unix(2026, 10, 12, 10))
	_check(not dc.complete() and not dc.claim(), "a fresh challenge is not done")
	var k: String = dc.kind()
	match k:
		"earn":
			gs.total_earned += float(pr.stats["dc_goal"])
		"taps":
			pr.stats["taps"] = int(pr.stats["taps"]) + 200
		"puzzle":
			pr.stats["puzzles_won"] = int(pr.stats.get("puzzles_won", 0)) + 1
		"fish":
			root.get_node("Fishing").stats["caught"] = int(root.get_node("Fishing").stats.get("caught", 0)) + 3
		"chest":
			pr.stats["chests"] = int(pr.stats.get("chests", 0)) + 1
		"quests":
			pr.stats["quests_done"] = int(pr.stats.get("quests_done", 0)) + 3
	var d0: int = pr.pearls
	_check(dc.complete() and dc.claim() and pr.pearls == d0 + dc.PEARLS, "the challenge pays once done (%s)" % k)
	_check(not dc.claim(), "and only once")
	dc.refresh(_unix(2026, 10, 13, 10))
	_check(not dc.claimed(), "a new day, a new challenge")
	for kk in dc.KINDS:
		_check(TranslationServer.translate("DC_" + str(kk[0]).to_upper()) != "DC_" + str(kk[0]).to_upper(), "challenge text %s" % kk[0])

	# --- Puzzle board --------------------------------------------------------------------------
	online.track()
	var pz0: float = online.score("puzzle")
	pr.stats["puzzle_stars"] = int(pr.stats.get("puzzle_stars", 0)) + 3
	online.track()
	_check(is_equal_approx(online.score("puzzle"), pz0 + 3.0), "puzzle stars count for the week")
	online._since_submit = 9999.0
	online.submit()
	_check(nf.puzzle_weeks.get(int(online.data["week"]), {}).has(nf.uid), "puzzle points reach the puzzle board")
	var pzb := [{}]
	online._boards.clear()
	online.fetch_board("puzzle", func(b): pzb[0] = b)
	_check(pzb[0]["ok"] and pzb[0]["rows"].size() == 1 and pzb[0]["rows"][0]["you"], "the puzzle board shows me")
	_check(OnlineRules.puzzle_prize(1, 3.0) == 150 and OnlineRules.puzzle_prize(3, 3.0) == 100 and OnlineRules.puzzle_prize(10, 1.0) == 50
		and OnlineRules.puzzle_prize(0, 1.0) == 10 and OnlineRules.puzzle_prize(1, 0.0) == 0, "puzzle prizes")
	nf.puzzle_weeks[now_w - 1] = {"A": {"name": "a", "score": 30.0, "a": ""}, nf.uid: {"name": "me", "score": 12.0, "a": ""}}
	online.data["pz_prize"] = -1
	online.pending_thanks.clear()
	var pp0: int = pr.pearls
	online.check_puzzle_prize()
	_check(pr.pearls == pp0 + 100 and online.pending_thanks.size() == 1 and online.pending_thanks[0]["kind"] == "puzzle", "2nd on last week's puzzle board: 100 pearls")
	online.check_puzzle_prize()
	_check(pr.pearls == pp0 + 100, "the puzzle prize is paid once")
	online.pending_thanks.clear()
	online.data["week"] = int(online.data["week"]) - 1
	online.track()
	_check(online.score("puzzle") == 0.0, "a new week starts the puzzle board from zero")

	# --- Sea pass ---------------------------------------------------------------------------------
	var bp: GDScript = load("res://scripts/data/battle_pass.gd")
	for bk in ["bp_s_minute", "bp_xp", "bp_got", "bp_ch"]:
		pr.stats.erase(bk)
	_check(bp.tick() == 0 and bp.xp() == 0 and bp.level() == 0, "the pass starts at zero (old progress gives no XP)")
	pr.stats["quests_done"] = int(pr.stats.get("quests_done", 0)) + 3
	pr.stats["puzzle_stars"] = int(pr.stats.get("puzzle_stars", 0)) + 4
	_check(bp.tick() == 1 and bp.xp() == 100, "3 quests + 4 stars = 100 XP = level 1")
	_check(bp.tick() == 0, "nothing new, no XP")
	_check(bp.waiting() == 1, "one reward waits")
	var bpp: int = pr.pearls
	var got_bp: Dictionary = bp.claim_all()
	_check(int(got_bp["pearls"]) == 5 and pr.pearls == bpp + 5 and bp.waiting() == 0, "level 1 pays 5 pearls")
	_check(bp.claim_all().is_empty(), "nothing twice")
	_check(bp.reward(10, 1).get("item") == "boat_reef" and bp.reward(20, 1).get("item") == "hat_coral_crown" and bp.reward(30, 1).get("item") == "hat_trident", "items at 10, 20, 30")
	_check(bp.reward(5).has("boost") and bp.reward(3).has("coins_min") and bp.reward(4).has("pearls"), "boosts, coins, pearls")
	for id in ["boat_reef", "hat_coral_crown", "hat_trident"]:
		_check(Content.cosmetic(id).get("unlock") == "pass" and not pr.buy_item(id), "%s is never sold" % id)
		_check(TranslationServer.translate("ITEM_" + id.to_upper()) != "ITEM_" + id.to_upper(), "%s has a name" % id)
	_check("coral_crown" in HatsArt.IDS and "trident" in HatsArt.IDS and Content.BOAT_PAINTS.has("reef"), "pass items are drawn")
	bp.add_xp(5000)
	_check(bp.level() == 30, "level 30 at most")
	var all_bp: Dictionary = bp.claim_all()
	_check(pr.is_owned("boat_reef") and pr.is_owned("hat_coral_crown") and pr.is_owned("hat_trident") and all_bp["items"].size() == 3, "all three items given")
	_check(bp.chapter() == 2 and bp.taken() == 0 and bp.xp() == 5100 - 3000, "the next chapter starts with the XP left over")
	_check(not bp.reward(10).has("item") and int(bp.reward(10)["pearls"]) == 80, "owned items become pearls in later chapters")
	var dcc := int(pr.stats.get("dc_claims", 0))
	pr.stats["dc_claims"] = dcc + 1
	var x0: int = bp.xp()
	bp.tick()
	_check(bp.xp() == x0 + 100, "the challenge of the day: 100 XP")

	# --- The guide: every entry has words ------------------------------------------------------
	var guide_src := FileAccess.get_file_as_string("res://scripts/ui/guide_view.gd")
	var rx := RegEx.create_from_string('\\["([a-z0-9_]+)", "[a-z]+", "(base|fun|online)"')
	var gids := rx.search_all(guide_src).map(func(r): return r.get_string(1)).filter(func(g): return g != "base")
	_check(gids.size() >= 25, "the guide lists every feature (%d)" % gids.size())
	for gid in gids:
		var key: String = "GUIDE_" + str(gid).to_upper()
		_check(TranslationServer.translate(key) != key and TranslationServer.translate(key + "_D") != key + "_D", "guide words for %s" % gid)
	for lid in ["evo", "daily", "streak", "chests", "quests", "challenge", "puzzle", "museum", "fishing", "shop", "rivals"]:
		var lk: String = "GUIDE_" + str(lid).to_upper() + "_LOCK"
		_check(TranslationServer.translate(lk) != lk, "guide lock words for %s" % lid)
	for hk in ["HINT_CHALLENGE", "HINT_SEE_ACH", "HINT_SEE_CHALLENGE", "HINT_SEE_BOARD", "HINT_SEE_PUZZLE_BOARD", "HINT_SEE_CLUBS", "PZ_BOARD", "ONLINE_PUZZLE"]:
		_check(TranslationServer.translate(hk) != hk, "words for %s" % hk)

	DirAccess.remove_absolute(online.SAVE_PATH)
	print("test_online: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
