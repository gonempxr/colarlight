extends Node
## Online features (Online autoload): the players' leaderboard, promo codes,
## the "first 100 players" founder gift and invites.
##
## The web shell keeps the network side in window.coralightOnline (Firebase
## anonymous sign-in + Firestore on our site and on CrazyGames; a fake
## backend in localStorage with ?online=test). This node wraps it: every
## request has a timeout, and when anything is missing (no network, an ad
## blocker, Firebase blocked, not a web build) the features say "Online is
## not available right now" and the game simply carries on.
##
## What the player got is kept in user://online.json (shared by the local
## profiles, mirrored to the cloud like the other saves): codes used, the
## founder number, who invited them, friends already paid for, this week's
## coins. Rewards go into the current profile (pearls, the exclusive item).
## Rules (codes, names, weeks, invites) live in OnlineRules.

## The connection changed (UI shows or greys online buttons).
signal state_changed
## Something was given (founder, promo, joined from an invite, friends
## joined): the UI shows the thank-you dialog. info: {"kind", "pearls",
## "item" (bool), "boost" (seconds), "n" (founder number / friends)}.
signal thanks(info: Dictionary)
## The player's name turned out to be someone else's (found while sending
## scores): the game asks for another one. Once per name.
signal name_taken(name: String)
## The race board's no. 1 changed (crown = {uid, name, k, id, score}; prev = the
## old holder's uid, "" when unknown).
signal crown_changed(crown: Dictionary, prev: String)

## Rows asked for (a few more than shown: one player's rows from several
## devices are joined into one) and rows shown on a board.
const BOARD_FETCH := 120
const BOARD_ROWS := 100
const SAVE_PATH := "user://online.json"
## Scores go out every few minutes and at important moments (a new world,
## the page hidden, the board opened), never twice within a minute: the
## free Firebase plan allows 20 000 writes a day for all players together.
## (The rules refuse a second write within 30 s.)
const SUBMIT_SEC := 300.0
const SUBMIT_GAP_SEC := 60.0
## The Firestore rules (v8, docs/online.md) accept scores up to 1e300. World
## stars push totals far past the old 1e60 (15 Jungle stars ~1e75), and with
## that cap every star player showed the same "990ao". Under older rules the
## web shell sends min(score, 9.9e59) when the full number is refused.
const SCORE_CAP := 9.9e299
## A board read is kept this long (50 reads each; 50 000 a day are free).
const BOARD_CACHE_SEC := 60.0
const TIMEOUT_SEC := 12.0
const POLL_SEC := 0.5
const TRACK_SEC := 5.0
const SAVE_SEC := 30.0
## The network side starts this long after the game (never during loading).
const BEGIN_SEC := 4.0
## How often the crown (crown/now, 2 reads) is checked, and how often its
## holder adds a minute at no. 1 (1 write).
const CROWN_SEC := 90.0
## How often a gift from the leader is looked for (one read).
const GIFT_SEC := 300.0
## Levels of each site in a world the leader's gift builds.
const GIFT_LEVEL := 150
const CROWN_TICK_SEC := 60.0

## "off" (no online here), "idle" (waiting to begin), "loading", "ready", "failed".
var state := "off"
var uid := ""
## Tests and screenshots: an object with `uid` and request(method, arg) -> String
## standing in for the browser bridge.
var backend: Object = null
## Thank-you dialogs waiting for a quiet moment (the UI takes them).
var pending_thanks: Array[Dictionary] = []

var data := {}
var _pending := {}
var _next_id := 1
var _js_cb: JavaScriptObject
var _poll_left := 0.0
var _track_left := TRACK_SEC
var _save_left := SAVE_SEC
var _dirty := false
var _submit_left := 10.0
var _since_submit := 9999.0
var _sent := {"all": -1.0, "week": -1.0, "month": -1.0, "puzzle": -1.0, "league": -1.0, "name": "", "p": ""}
var _ref_looks := 40
var _boards := {}
var _after_ready_done := false
var _begin_left := BEGIN_SEC
## The leader (only ids added by hand to admins/ in the Firebase console):
## can kick and ban players from the boards.
var admin := false
## Banned players: {uid: name} and {"o:<owner>": name}.
var bans := {}
## The crown as last read ({} = nobody yet / unknown).
var crown := {}
var _crown_left := 20.0
var _gift_left := GIFT_SEC
var _tick_left := CROWN_TICK_SEC
## The holder's minutes at no. 1 today (from the last tick).
var crown_minutes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	if OS.has_feature("web"):
		var s := _js_str("(window.coralightOnline && window.coralightOnline.state) || ''")
		if s != "":
			state = s
			_js_cb = JavaScriptBridge.create_callback(_on_js)
	GameState.location_changed.connect(func(_l): submit_soon())


func _process(delta: float) -> void:
	_since_submit += delta
	if _begin_left > 0.0:
		_begin_left -= delta
		if _begin_left <= 0.0 and _js_cb != null:
			# Firebase loads only now: the game is already running.
			JavaScriptBridge.eval("(function(){try{window.coralightOnline.begin()}catch(e){}})()", true)
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL_SEC
		_poll()
	_track_left -= delta
	if _track_left <= 0.0:
		_track_left = TRACK_SEC
		track()
		_keep_exclusive()
	if state == "ready":
		_gift_left -= delta
		if _gift_left <= 0.0:
			_gift_left = GIFT_SEC
			check_gift()
		_crown_left -= delta
		if _crown_left <= 0.0:
			_crown_left = CROWN_SEC
			check_crown()
		if is_king():
			_tick_left -= delta
			if _tick_left <= 0.0:
				_tick_left = CROWN_TICK_SEC
				_crown_tick()
		_submit_left -= delta
		if _submit_left <= 0.0:
			_submit_left = SUBMIT_SEC
			submit()
	for id in _pending.keys():
		_pending[id]["left"] -= delta
		if _pending[id]["left"] <= 0.0:
			_answer(id, "error:timeout")
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = SAVE_SEC
		if _dirty:
			save_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		track()
		save_data()
		submit()


func available() -> bool:
	return state == "ready"


## Online exists on this page (our site, CrazyGames, ?online=test), even if
## it is still loading or failed: the online buttons show.
func present() -> bool:
	return state != "off" or backend != null


# --- Connection ---------------------------------------------------------------------

func _poll() -> void:
	if backend != null or not OS.has_feature("web") or _js_cb == null:
		return
	# The invite parameter (CrazyGames gives it once its SDK is up).
	if _ref_looks > 0 and str(data.get("ref_pending", "")) == "" and not bool(data.get("ref_done", false)):
		_ref_looks -= 1
		var ref := _js_str("(window.coralightOnline && window.coralightOnline.inviteRef) ? String(window.coralightOnline.inviteRef() || '') : ''")
		if ref != "":
			_ref_looks = 0
			take_ref(ref)
	var s := _js_str("(window.coralightOnline && window.coralightOnline.state) || 'off'")
	if s == "ready":
		var u := _js_str("String(window.coralightOnline.uid || '')")
		if u != "" and (s != state or u != uid):
			_became_ready(u)
	elif s != state:
		state = s
		state_changed.emit()


## Tests and screenshots: use `fake` instead of the browser.
func use_backend(fake: Object) -> void:
	backend = fake
	_after_ready_done = false
	_became_ready(str(fake.get("uid")))


func _became_ready(new_uid: String) -> void:
	uid = new_uid
	state = "ready"
	# The save's own online id: the first one it was played with. It goes
	# with the save to other devices (CrazyGames, Google), so the rows one
	# player leaves from several devices are shown as one on the boards.
	if str(data.get("owner", "")) == "":
		var first := OnlineRules.code_of(str(data.get("claimed_by", "")))
		if first == "":
			first = str(data.get("code", ""))
		data["owner"] = first if OnlineRules.valid_code(first) else OnlineRules.code_of(uid)
		_dirty = true
	# The invite code follows the online id (signing in with Google can
	# change it); friends already paid are counted per code.
	var code := OnlineRules.code_of(uid)
	if code != "" and str(data.get("code", "")) != code:
		data["code"] = code
		_dirty = true
	state_changed.emit()
	if not _after_ready_done:
		_after_ready_done = true
		after_ready()


## Once per session when online: founder, invites, scores.
func after_ready() -> void:
	track()
	if not bool(data.get("founder_done", false)):
		claim_founder()
	if str(data.get("ref_pending", "")) != "":
		_join(str(data["ref_pending"]))
	check_invites()
	check_week_prize()
	check_season_prize()
	check_puzzle_prize()
	check_crown_prize()
	check_gift()
	check_admin()
	load_bans()
	submit()
	if in_club():
		# Keeps the club's weekly total fresh on the club board.
		club_info(str(data["club"]), func(_i: Dictionary): pass)


func _request(method: String, arg: String, cb: Callable) -> void:
	if backend != null:
		cb.call(str(backend.request(method, arg)))
		return
	if state != "ready" or _js_cb == null:
		cb.call("error:offline")
		return
	var id := _next_id
	_next_id += 1
	_pending[id] = {"cb": cb, "left": TIMEOUT_SEC}
	var bridge = JavaScriptBridge.get_interface("coralightOnline")
	if bridge == null:
		_answer(id, "error:offline")
		return
	bridge.request(id, method, arg, _js_cb)


func _on_js(args: Array) -> void:
	if args.size() >= 2:
		_answer(int(args[0]), str(args[1]))


func _answer(id: int, result: String) -> void:
	if not _pending.has(id):
		return
	var cb: Callable = _pending[id]["cb"]
	_pending.erase(id)
	if cb.is_valid():
		cb.call(result)


func _js_str(code: String) -> String:
	return str(JavaScriptBridge.eval("(function(){try{return %s}catch(e){return ''}})()" % code, true))


# --- Save ------------------------------------------------------------------------------

func defaults() -> Dictionary:
	return {"v": 1, "redeemed": {}, "founder": 0, "founder_done": false, "code": "", "referred_by": "", "ref_pending": "",
		"ref_done": false, "paid": {}, "exclusive": false, "week": -1, "week_score": 0.0, "all_best": 0.0,
		"seen_total": -1.0, "seen_profile": "", "claimed": "", "claimed_by": "", "taken": "", "prize_week": -1,
		"best_rank": 0, "title": 0, "title_week": -1, "month": -1, "month_score": 0.0, "season_prize": -1,
		"club": "", "club_name": "", "pz_score": 0.0, "seen_pz": -1.0, "pz_prize": -1, "owner": "",
		"league": 0, "league_score": 0.0, "crown_prize": -1, "crown_wins": 0, "sleeper": 0, "fri": "", "fri_name": "", "gifts": {}, "tester": false, "cheated": false}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		return
	var d = json.data
	if not d is Dictionary:
		return
	for k in data:
		if not d.has(k):
			continue
		var v = d[k]
		match typeof(data[k]):
			TYPE_BOOL:
				data[k] = v == true
			TYPE_INT:
				data[k] = int(v) if (v is float or v is int) else data[k]
			TYPE_FLOAT:
				data[k] = maxf(-1.0, float(v)) if (v is float or v is int) and is_finite(float(v)) else data[k]
			TYPE_STRING:
				data[k] = str(v).left(64)
			TYPE_DICTIONARY:
				if v is Dictionary:
					for id in v:
						if v[id] is bool and v[id]:
							data[k][str(id)] = true
						elif (v[id] is float or v[id] is int) and k == "paid":
							data[k][str(id).left(16)] = clampi(int(v[id]), 0, OnlineRules.INVITE_CAP)


func save_data() -> void:
	_dirty = false
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)


# --- Scores -------------------------------------------------------------------------------

## Adds the coins earned since the last look to this week's total (a new
## week starts from zero; switching profiles adds nothing).
func track(now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Clock.now()
	var w := OnlineRules.week_id(t)
	if w != int(data["week"]):
		data["week"] = w
		data["week_score"] = 0.0
		data["pz_score"] = 0.0
		_dirty = true
	var m := OnlineRules.month_id(t)
	if m != int(data["month"]):
		data["month"] = m
		data["month_score"] = 0.0
		_dirty = true
	# The Top League: a new start wipes its score (only the board's).
	var lg := OnlineRules.league_id(t)
	if lg != int(data["league"]):
		data["league"] = lg
		data["league_score"] = 0.0
		_dirty = true
	var prof := str(Profiles.current_id)
	# Coins from promo codes are a gift, not play: never on the boards.
	var total := maxf(0.0, float(GameState.total_earned) - float(Progress.stats.get("promo_coins", 0.0)))
	if str(data["seen_profile"]) == prof and float(data["seen_total"]) >= 0.0 and total > float(data["seen_total"]):
		data["week_score"] = float(data["week_score"]) + (total - float(data["seen_total"]))
		data["month_score"] = float(data["month_score"]) + (total - float(data["seen_total"]))
		# Only the league's own fresh game counts there (Profiles.enter_league).
		if Profiles.in_league(lg):
			data["league_score"] = float(data["league_score"]) + (total - float(data["seen_total"]))
		_dirty = true
	if str(data["seen_profile"]) != prof or float(data["seen_total"]) != total:
		_dirty = true
	# Puzzle points (stars won) this week, the same way.
	var pz := float(Progress.stats.get("puzzle_stars", 0))
	if str(data["seen_profile"]) == prof and float(data["seen_pz"]) >= 0.0 and pz > float(data["seen_pz"]):
		data["pz_score"] = float(data["pz_score"]) + (pz - float(data["seen_pz"]))
	if float(data["seen_pz"]) != pz:
		data["seen_pz"] = pz
		_dirty = true
	data["seen_profile"] = prof
	data["seen_total"] = total
	if total > float(data["all_best"]):
		data["all_best"] = total
		_dirty = true


func score(kind: String) -> float:
	match kind:
		"week", "clubs":
			return minf(float(data["week_score"]), SCORE_CAP)
		"month":
			return minf(float(data["month_score"]), SCORE_CAP)
		"league":
			return minf(float(data["league_score"]), SCORE_CAP) if int(data["league"]) > 0 else 0.0
		"puzzle":
			return float(data["pz_score"])
	return minf(float(data["all_best"]), SCORE_CAP)


## The title won last week (OnlineRules.title_for), worn this week only.
func title(now: float = -1.0) -> int:
	var t := now if now >= 0.0 else Clock.now()
	if int(data["title_week"]) != OnlineRules.week_id(t):
		return 0
	return clampi(int(data["title"]), 0, 3)


## What the profile card shows to others (the "p" field of a score row).
func profile_info() -> String:
	var p := {"t": title(), "b": Achievements.count(), "wo": int(GameState.max_location) + 1}
	if OnlineRules.valid_code(str(data.get("owner", ""))):
		p["o"] = str(data["owner"])
	if str(data["club_name"]) != "":
		p["c"] = str(data["club_name"])
	if int(data["founder"]) > 0:
		p["f"] = int(data["founder"])
	if int(data["best_rank"]) > 0:
		p["r"] = int(data["best_rank"])
	if int(data["crown_wins"]) > 0:
		p["k"] = int(data["crown_wins"])
	if int(data.get("sleeper", 0)) > 0:
		p["s"] = int(data["sleeper"])
	return JSON.stringify(p)


## A profile card's fields from a row's "p" (anything odd is dropped).
static func parse_profile(p: String) -> Dictionary:
	var d = JSON.parse_string(p) if p.begins_with("{") and p.length() <= 300 else null
	var out := {"t": 0, "b": 0, "wo": 1, "c": "", "f": 0, "r": 0, "k": 0, "s": 0}
	if not d is Dictionary:
		return out
	for k in ["t", "b", "wo", "f", "r", "k", "s"]:
		if d.get(k) is float or d.get(k) is int:
			out[k] = maxi(0, int(d[k]))
	out["t"] = mini(int(out["t"]), 3)
	out["wo"] = clampi(int(out["wo"]), 1, Balance.LAST_LOCATION + 1)
	out["k"] = mini(int(out["k"]), 999)
	out["s"] = mini(int(out["s"]), 999)
	out["b"] = mini(int(out["b"]), 99)
	if d.get("c") is String:
		out["c"] = OnlineRules.strip_name(str(d["c"]))
	return out


## The name on the board: the player's own name once it is theirs online
## (names are unique), otherwise "Diver####".
func board_name() -> String:
	var want := wanted_name()
	if OnlineRules.is_fallback(want) or name_ok(want):
		return want
	return OnlineRules.fallback_name(uid)


## The typed name after the filter (what the player wants to be called).
func wanted_name() -> String:
	return OnlineRules.board_name(Profiles.player_name(), uid)


func name_ok(name: String) -> bool:
	return uid != "" and str(data["claimed"]) == OnlineRules.name_key(name) and str(data["claimed_by"]) == uid


## "ok", "taken" (someone else has it), "rude" (the filter changed it),
## "wait" (not claimed yet).
func name_state() -> String:
	var typed := OnlineRules.strip_name(Profiles.player_name())
	if typed != "" and OnlineRules.is_rude(typed):
		return "rude"
	var want := wanted_name()
	if OnlineRules.is_fallback(want) or name_ok(want):
		return "ok"
	if str(data["taken"]) == OnlineRules.name_key(want):
		return "taken"
	return "wait"


## Makes the wanted name this player's own (one owner per name):
## done.call("ok" | "taken" | "error").
func claim_name(done: Callable = Callable()) -> void:
	var want := wanted_name()
	if OnlineRules.is_fallback(want) or name_ok(want):
		if done.is_valid():
			done.call("ok")
		return
	var key := OnlineRules.name_key(want)
	var old := str(data["claimed"]) if str(data["claimed_by"]) == uid else ""
	_request("claim", JSON.stringify({"name": want, "key": key, "old": old}), func(res: String):
		if res == "ok":
			data["claimed"] = key
			data["claimed_by"] = uid
			data["taken"] = ""
			save_data()
		elif res == "taken":
			data["taken"] = key
			_dirty = true
		if done.is_valid():
			done.call(res if res in ["ok", "taken"] else "error"))


## A score worth sending soon (a new world, ...): within the rate limit.
func submit_soon() -> void:
	_submit_left = minf(_submit_left, maxf(1.0, SUBMIT_GAP_SEC - _since_submit))


## Sends both scores when they changed (at most every SUBMIT_GAP_SEC).
func submit(done: Callable = Callable()) -> void:
	track()
	# A new name is made the player's own first (one owner per name).
	if state == "ready" and name_state() == "wait" and score("all") > 0.0 and _since_submit >= SUBMIT_GAP_SEC:
		var want := wanted_name()
		claim_name(func(r: String):
			if r == "taken":
				name_taken.emit(want)
			_submit_now(done))
		return
	_submit_now(done)


func _submit_now(done: Callable) -> void:
	# The leader's test mode: never on any board.
	if tester():
		if done.is_valid():
			done.call(false)
		return
	var name := board_name()
	var p := profile_info()
	var changed := score("all") != float(_sent["all"]) or score("week") != float(_sent["week"]) or name != str(_sent["name"]) \
		or score("month") != float(_sent["month"]) or p != str(_sent["p"]) or score("puzzle") != float(_sent["puzzle"]) \
		or score("league") != float(_sent["league"])
	if state != "ready" or not changed or _since_submit < SUBMIT_GAP_SEC or score("all") <= 0.0:
		if done.is_valid():
			done.call(false)
		return
	_since_submit = 0.0
	var sent := {"all": score("all"), "week": score("week"), "month": score("month"), "puzzle": score("puzzle"),
		"league": score("league"), "name": name, "p": p}
	var arg := JSON.stringify({"name": name, "a": JSON.stringify(Settings.avatar), "all": sent["all"], "week": sent["week"],
		"w": int(data["week"]), "month": sent["month"], "m": int(data["month"]), "p": p, "club": str(data["club"]), "pz": sent["puzzle"],
		"l": int(data["league"]), "league": sent["league"]})
	_request("submit", arg, func(res: String):
		if res == "ok":
			_sent = sent
			# Maybe past the crown's holder now: look at once.
			if not is_king() and not crown.is_empty() and float(sent.get(race_kind(), 0.0)) > float(crown.get("score", 0.0)):
				_crown_left = minf(_crown_left, 1.0)
		if done.is_valid():
			done.call(res == "ok"))


## The board: done.call({"ok", "rows": [{uid, name, score, a, p, n, you}], "rank"}).
## kind: "week", "month", "all", "puzzle" (stars won in the puzzle this week), "friends" (my inviter and who joined with
## my link) or "clubs" (this week's clubs: uid = club id, n = members).
func fetch_board(kind: String, done: Callable) -> void:
	if state != "ready":
		done.call({"ok": false, "rows": [], "rank": 0})
		return
	var now := Time.get_ticks_msec() / 1000.0
	var cached: Dictionary = _boards.get(kind, {})
	if not cached.is_empty() and now - float(cached["at"]) < BOARD_CACHE_SEC and int(cached["w"]) == int(data["week"]):
		done.call(cached["board"])
		return
	var ask := func(_sent_ok: bool = false) -> void:
		var arg := JSON.stringify({"kind": kind, "w": int(data["week"]), "m": int(data["month"]), "l": int(data["league"]), "score": score(kind),
			"code": invite_code(), "ref": str(data["referred_by"]), "club": str(data["club"])})
		_request("board", arg, func(res: String):
			var board := parse_board(res, uid, kind != "clubs")
			if board["ok"] and kind != "clubs":
				board["rows"] = board["rows"].filter(func(r): return bool(r["you"]) or not is_banned(r))
			if board["ok"]:
				_boards[kind] = {"at": Time.get_ticks_msec() / 1000.0, "w": int(data["week"]), "board": board}
			done.call(board))
	submit(ask)


static func parse_board(res: String, me: String, merge := true) -> Dictionary:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not d is Dictionary or not d.get("rows") is Array:
		return {"ok": false, "rows": [], "rank": 0}
	var rows: Array = []
	for r in d["rows"]:
		if not r is Dictionary or rows.size() >= BOARD_FETCH:
			continue
		var id := str(r.get("uid", ""))
		var s := float(r.get("score", 0)) if (r.get("score") is float or r.get("score") is int) else 0.0
		var n = r.get("n", 0)
		rows.append({"uid": id, "name": OnlineRules.board_name(str(r.get("name", "")), id), "score": maxf(0.0, s),
			"a": str(r.get("a", "")), "p": str(r.get("p", "")), "n": int(n) if (n is float or n is int) else 0,
			"you": id == me and me != ""})
	rows.sort_custom(func(x, y): return float(x["score"]) > float(y["score"]))
	if merge:
		rows = merge_rows(rows)
	if rows.size() > BOARD_ROWS:
		rows.resize(BOARD_ROWS)
	return {"ok": true, "rows": rows, "rank": maxi(0, int(d.get("rank", 0)))}


## Which player a row belongs to: the save's own id ("o" in the profile
## card) or, for rows from older versions, the start of the row's id.
static func row_owner(row: Dictionary) -> String:
	var p := str(row.get("p", ""))
	if p.begins_with("{") and p.length() <= 300:
		var d = JSON.parse_string(p)
		if d is Dictionary and d.get("o") is String and OnlineRules.valid_code(str(d["o"])):
			return str(d["o"])
	return OnlineRules.code_of(str(row.get("uid", "")))


## One row per player: a save played on two devices (or after a Google
## sign-in) leaves two rows, one with the name and one "Diver1234". They
## become one row with the best score and the real name. Rows with two
## different real names are never joined (an "o" copied from someone else
## can't hide them). Rows must be sorted by score, best first.
static func merge_rows(rows: Array) -> Array:
	var out: Array = []
	var by_owner := {}
	for r in rows:
		var k := row_owner(r)
		if k != "" and by_owner.has(k):
			var g: Dictionary = by_owner[k]
			var gn := str(g["name"])
			var rn := str(r["name"])
			if gn == rn or OnlineRules.is_fallback(gn) or OnlineRules.is_fallback(rn):
				if OnlineRules.is_fallback(gn) and not OnlineRules.is_fallback(rn):
					g["name"] = rn
					if str(r.get("a", "")) != "":
						g["a"] = r["a"]
				g["you"] = bool(g["you"]) or bool(r["you"])
				g["also"] = g.get("also", []) + [str(r["uid"])]
				continue
		out.append(r)
		if k != "" and not by_owner.has(k):
			by_owner[k] = r
	return out


# --- The leader: kick and ban ------------------------------------------------------------

func check_admin() -> void:
	_request("admin", "", func(res: String):
		var was := admin
		admin = res == "yes"
		if admin != was:
			state_changed.emit())


## The donation board: done.call({"ok": bool, "rows": [...]}) (OnlineRules.parse_donors).
## The saga's Ancient One beaten once more: the "Heart of the Sleeper"
## trophy on my card (kept for every profile on this device).
func add_sleeper() -> void:
	data["sleeper"] = int(data.get("sleeper", 0)) + 1
	save_data()
	submit_soon()


## The world boss (WorldBoss): sends my total damage for league `league`.
func wb_hit(league: int, dmg: float, done: Callable = Callable()) -> void:
	var arg := JSON.stringify({"l": league, "name": board_name(), "dmg": snappedf(clampf(dmg, 0.0, 1e7), 0.1)})
	_request("wb_hit", arg, func(res: String):
		if done.is_valid():
			done.call(res))


## The world boss board of league `league` -> WorldBoss.parse_board.
func wb_board(league: int, done: Callable) -> void:
	_request("wb_board", JSON.stringify({"l": league}), func(res: String): done.call(WorldBoss.parse_board(res)))


func fetch_donors(done: Callable) -> void:
	_request("donors", "", func(res: String): done.call(OnlineRules.parse_donors(res)))


## Donations show only on our own site (never on a portal) once a link is set.
func donations_shown() -> bool:
	return not Platform.on_portal() and not OnlineRules.donate_links().is_empty()


func load_bans(done: Callable = Callable()) -> void:
	_request("bans", "", func(res: String):
		var d = JSON.parse_string(res) if res.begins_with("{") else null
		if d is Dictionary and d.get("list") is Array:
			bans = {}
			for b in d["list"]:
				if b is Dictionary and str(b.get("uid", "")) != "":
					var name := OnlineRules.strip_name(str(b.get("name", "")))
					bans[str(b["uid"])] = name
					if OnlineRules.valid_code(str(b.get("o", ""))):
						bans["o:" + str(b["o"])] = name
		if done.is_valid():
			done.call())


## A row of a banned player: their id, or another device of the same save
## (same owner) with the banned name or a "Diver1234" one.
func is_banned(row: Dictionary) -> bool:
	if bans.has(str(row.get("uid", ""))):
		return true
	var k := "o:" + row_owner(row)
	if not bans.has(k):
		return false
	var n := str(row.get("name", ""))
	return OnlineRules.is_fallback(n) or n == str(bans[k])


## Takes a player's rows off every board (they come back when the player
## plays again); with `ban` their scores are refused from then on.
## done.call("ok" | "error").
func kick(row: Dictionary, ban: bool, done: Callable) -> void:
	var id := str(row.get("uid", ""))
	if not admin or id == "" or id == uid:
		done.call("error")
		return
	# A row joined from several devices: all of them go.
	var ids: Array = [id]
	for other in row.get("also", []):
		if str(other) != uid and not ids.has(str(other)):
			ids.append(str(other))
	var arg := JSON.stringify({"uids": ids, "w": int(data["week"]), "m": int(data["month"]), "l": int(data["league"]),
		"name": str(row.get("name", "")), "o": row_owner(row), "ban": ban})
	_request("kick", arg, func(res: String):
		if res == "ok":
			_boards = {}
			if ban:
				for b in ids:
					bans[b] = str(row.get("name", ""))
				var o := row_owner(row)
				if OnlineRules.valid_code(o):
					bans["o:" + o] = str(row.get("name", ""))
		done.call("ok" if res == "ok" else "error"))


func unban(id: String, done: Callable) -> void:
	_request("unban", JSON.stringify({"uid": id}), func(res: String):
		if res != "ok":
			done.call("error")
			return
		_boards = {}
		bans.erase(id)
		load_bans(func(): done.call("ok")))


## The banned players for the leader's list: [{uid, name}].
func ban_list() -> Array:
	var out := []
	for k in bans:
		if not str(k).begins_with("o:"):
			out.append({"uid": str(k), "name": str(bans[k])})
	return out


# --- The leader's test mode ------------------------------------------------------------
# Lets the leader check everything without playing for it: free coins,
# pearls, items and worlds. While it is on (and once a cheat was used, for
# good on this device) nothing is sent to the boards, the crown is never
# taken and no board prizes are paid.

func tester() -> bool:
	return bool(data["tester"])


## Turns test mode on (the leader only; their rows leave the boards) or
## off (refused once a cheat was used): done.call("ok" | "admin" | "cheated").
func set_tester(on: bool, done: Callable = Callable()) -> void:
	if on and not admin:
		if done.is_valid():
			done.call("admin")
		return
	if not on and bool(data["cheated"]):
		if done.is_valid():
			done.call("cheated")
		return
	data["tester"] = on
	save_data()
	if on:
		hide_self()
	state_changed.emit()
	if done.is_valid():
		done.call("ok")


## Takes this player's own rows off every board (and the crown).
func hide_self() -> void:
	if uid == "" or not admin:
		return
	var arg := JSON.stringify({"uids": [uid], "w": int(data["week"]), "m": int(data["month"]), "l": int(data["league"]),
		"name": board_name(), "o": str(data.get("owner", "")), "ban": false})
	_request("kick", arg, func(res: String):
		if res == "ok":
			_boards = {}
			if is_king():
				_set_crown({}))


## A cheat of test mode: "coins", "pearls", "items" or "world" (finish
## this world and go to the next). False when test mode is off.
func cheat(kind: String) -> bool:
	if not tester():
		return false
	data["cheated"] = true
	save_data()
	match kind:
		"coins":
			GameState.coins += maxf(1.0e9, GameState.coins * 1000.0)
			GameState.changed.emit()
		"pearls":
			Progress.add_pearls(5000)
		"items":
			# All at once, without a toast for each.
			for c in Content.COSMETICS:
				Progress.owned[str(c["id"])] = true
			for f in Content.FEATURES:
				Progress.features[f] = true
			Progress.changed.emit()
		"world":
			if GameState.is_last_location():
				return false
			for k in GameState.stage_keys():
				GameState.levels[k] = maxi(int(GameState.levels.get(k, 0)), 1)
				GameState.managers[k] = true
			for k in GameState.AUTOMATED:
				GameState.managers[k] = true
			GameState.coins += GameState.next_location_cost()
			return GameState.advance_location()
	Progress.save_game()
	GameState.save_game()
	return true


# --- The leader's gifts -------------------------------------------------------------------

## The leader gives one player coins and/or opened worlds (gifts/{uid}):
## `upto` = the world to open and play (every world before it fully built),
## -1 = worlds untouched.
func send_gift(row: Dictionary, coins: float, upto: int, done: Callable) -> void:
	var id := str(row.get("uid", ""))
	if not admin or id == "" or id == uid or not is_finite(coins) or coins < 0.0:
		done.call("error")
		return
	var arg := JSON.stringify({"to": id, "id": "g%d" % int(Time.get_unix_time_from_system()), "coins": coins,
		"upto": clampi(upto, -1, Balance.LAST_LOCATION)})
	_request("gift_send", arg, func(res: String): done.call("ok" if res == "ok" else "error"))


func check_gift() -> void:
	if tester() or Profiles.league_game():
		return
	_request("gift_get", "", func(res: String): on_gift(res))


## Applies a gift once (its id is remembered), then deletes it on the server.
## Never in a league game (it waits for the ordinary one).
func on_gift(res: String) -> void:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not d is Dictionary or Profiles.league_game():
		return
	var id := str(d.get("id", ""))
	if id == "":
		return
	if not data["gifts"].get(id, false):
		data["gifts"][id] = true
		var upto := int(d.get("upto", -1)) if (d.get("upto") is float or d.get("upto") is int) else -1
		if upto >= 0:
			GameState.gift_worlds(upto, GIFT_LEVEL)
		var coins := float(d.get("coins", 0.0)) if (d.get("coins") is float or d.get("coins") is int) else 0.0
		_grant({"kind": "gift", "coins": coins if is_finite(coins) else 0.0, "n": upto + 1})
		save_data()
	_request("gift_done", "", func(_r: String): pass)


# --- Promo codes ------------------------------------------------------------------------

## {"result": "ok" | "used" | "bad", "reward": {...}}. Works offline too.
func redeem(text: String) -> Dictionary:
	var p := OnlineRules.promo(text)
	if p.is_empty():
		return {"result": "bad"}
	var id := str(p["id"])
	if data["redeemed"].get(id, false):
		return {"result": "used"}
	data["redeemed"][id] = true
	var info := {"kind": "promo", "pearls": int(p.get("pearls", 0)), "boost": float(p.get("boost", 0.0)), "item": p.has("item"),
		"coins": float(p.get("coins", 0.0))}
	_grant(info)
	save_data()
	return {"result": "ok", "reward": info}


# --- Founders -------------------------------------------------------------------------------

func claim_founder() -> void:
	_request("founder", "", func(res: String): on_founder(res))


func on_founder(res: String) -> void:
	if res.begins_with("n:"):
		var n := res.trim_prefix("n:").to_int()
		if n < 1 or n > OnlineRules.FOUNDER_MAX:
			return
		data["founder"] = n
		data["founder_done"] = true
		_grant({"kind": "founder", "pearls": OnlineRules.FOUNDER_PEARLS, "item": true, "n": n})
		save_data()
	elif res.begins_with("already:"):
		# This player's founder place was given before (this device lost
		# its save): the item comes back, the pearls were paid then.
		data["founder"] = maxi(1, res.trim_prefix("already:").to_int())
		data["founder_done"] = true
		give_exclusive()
		save_data()
	elif res == "full":
		data["founder_done"] = true
		save_data()


# --- Invites -----------------------------------------------------------------------------------

func invite_code() -> String:
	var c := str(data.get("code", ""))
	return c if c != "" else OnlineRules.code_of(uid)


## The game was opened from an invite: remember it when this save may use
## it (new, never invited, not their own link) and join when online.
func take_ref(ref: String) -> void:
	if bool(data.get("ref_done", false)) or str(data.get("ref_pending", "")) != "":
		return
	if not OnlineRules.invite_ok(ref, invite_code(), str(data["referred_by"]), GameState.total_earned):
		data["ref_done"] = true
		_dirty = true
		return
	data["ref_pending"] = ref
	save_data()
	if state == "ready":
		_join(ref)


func _join(ref: String) -> void:
	_request("join", ref, func(res: String): on_joined(ref, res))


func on_joined(ref: String, res: String) -> void:
	if res == "ok":
		data["referred_by"] = ref
		data["ref_pending"] = ""
		data["ref_done"] = true
		_grant({"kind": "join", "pearls": OnlineRules.JOIN_PEARLS})
		save_data()
	elif res == "denied":
		# Already used, or the player's own link: nothing to give.
		data["ref_pending"] = ""
		data["ref_done"] = true
		save_data()


## How many friends joined with this player's link; new ones are paid now.
func check_invites(done: Callable = Callable()) -> void:
	var code := invite_code()
	if code == "":
		if done.is_valid():
			done.call(-1)
		return
	_request("joins", code, func(res: String):
		var n := res.trim_prefix("n:").to_int() if res.begins_with("n:") else -1
		if n >= 0:
			on_invite_count(n)
		if done.is_valid():
			done.call(n))


func on_invite_count(joined: int) -> void:
	var due := OnlineRules.invite_due(joined, friends_paid())
	if joined >= 1 and not bool(data["exclusive"]):
		give_exclusive()
	if due <= 0:
		return
	data["paid"][invite_code()] = friends_paid() + due
	_grant({"kind": "inviter", "pearls": due * OnlineRules.INVITE_PEARLS, "n": due, "item": false})
	save_data()


## Friends already paid for with the current invite code.
func friends_paid() -> int:
	return int(data["paid"].get(invite_code(), 0))


## done.call(link) ("" when online is not available).
func invite_link(done: Callable) -> void:
	var code := invite_code()
	if code == "" or state != "ready":
		done.call("")
		return
	_request("link", code, func(res: String): done.call(res if res.begins_with("http") else ""))


## Shares (or copies) the link: done.call("shared" | "copied" | "cancel" | "error").
func share(text: String, link: String, done: Callable) -> void:
	_request("share", JSON.stringify({"text": text, "url": link}), func(res: String): done.call(res))


# --- Weekly race ---------------------------------------------------------------------------------

## Once a new week starts: the place on last week's board pays a prize
## (OnlineRules.WEEK_PRIZES), once per week.
func check_week_prize(now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Clock.now()
	var last := OnlineRules.week_id(t) - 1
	if int(data["prize_week"]) >= last:
		return
	_request("rank", JSON.stringify({"w": last}), func(res: String): on_week_rank(last, res))


## res: "r:<rank>:<score>" or "none" (did not play that week).
func on_week_rank(week: int, res: String) -> void:
	if res == "none":
		data["prize_week"] = week
		_dirty = true
		return
	if not res.begins_with("r:"):
		return
	var parts := res.split(":")
	if parts.size() < 3:
		return
	var rank := parts[1].to_int()
	var score := parts[2].to_float()
	data["prize_week"] = week
	if rank > 0 and (int(data["best_rank"]) <= 0 or rank < int(data["best_rank"])):
		data["best_rank"] = rank
	if OnlineRules.title_for(rank) > 0:
		data["title"] = OnlineRules.title_for(rank)
		data["title_week"] = week + 1
	var prize := OnlineRules.week_prize(rank, score)
	if not prize.is_empty():
		_grant({"kind": "week", "pearls": int(prize["pearls"]), "boost": float(prize["boost"]), "n": rank})
	save_data()


# --- Puzzle race ----------------------------------------------------------------------------------

## Last week's place on the puzzle board pays a small prize, once.
func check_puzzle_prize(now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Clock.now()
	var last := OnlineRules.week_id(t) - 1
	if int(data["pz_prize"]) >= last:
		return
	_request("rank", JSON.stringify({"kind": "puzzle", "w": last}), func(res: String): on_puzzle_rank(last, res))


func on_puzzle_rank(week: int, res: String) -> void:
	if res == "none":
		data["pz_prize"] = week
		_dirty = true
		return
	if not res.begins_with("r:"):
		return
	var parts := res.split(":")
	if parts.size() < 3:
		return
	data["pz_prize"] = week
	var pearls := OnlineRules.puzzle_prize(parts[1].to_int(), parts[2].to_float())
	if pearls > 0:
		_grant({"kind": "puzzle", "pearls": pearls, "n": parts[1].to_int()})
	save_data()


# --- Seasons --------------------------------------------------------------------------------------

## Once a new month starts: last month's place pays the season prize.
func check_season_prize(now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Clock.now()
	var last := OnlineRules.prev_month(OnlineRules.month_id(t))
	if int(data["season_prize"]) >= last:
		return
	_request("rank", JSON.stringify({"kind": "month", "id": last}), func(res: String): on_season_rank(last, res))


func on_season_rank(month: int, res: String) -> void:
	if res == "none":
		data["season_prize"] = month
		_dirty = true
		return
	if not res.begins_with("r:"):
		return
	var parts := res.split(":")
	if parts.size() < 3:
		return
	data["season_prize"] = month
	var pearls := OnlineRules.season_prize(parts[1].to_int(), parts[2].to_float())
	if pearls > 0:
		_grant({"kind": "season", "pearls": pearls, "n": parts[1].to_int(), "m": month})
	save_data()


# --- The crown: no. 1 of the race -----------------------------------------------------------------

## The race the crown belongs to: the Top League once it runs, the week before.
func race_kind() -> String:
	return "league" if int(data["league"]) > 0 else "week"


## The crown's board for the server: {k: "league"|"weeks", id}.
func race_board() -> Dictionary:
	if int(data["league"]) > 0:
		return {"k": "league", "id": str(data["league"])}
	return {"k": "weeks", "id": str(data["week"])}


func is_king() -> bool:
	return not crown.is_empty() and str(crown.get("uid", "")) == uid and uid != ""


## True when a board row belongs to the crown's holder (also a joined row).
func row_is_king(row: Dictionary) -> bool:
	var k := str(crown.get("uid", ""))
	if k == "":
		return false
	if bool(row.get("you", false)) and is_king():
		return true
	return str(row.get("uid", "")) == k or k in row.get("also", [])


## Reads the crown; takes it when this player's sent score is higher than
## the holder's (the rules check the same on the server).
func check_crown() -> void:
	if str(data["fri"]) == "" and Clock.now() >= OnlineRules.FRI_CUTOFF:
		check_fri()
	elif str(data["fri"]) == "owed":
		pay_fri()
	_request("crown", "", func(res: String): on_crown(res))


## The race to Friday: reads (or, first after the cutoff, writes) who held
## the crown at the cutoff; the winner gets the prize once, in a normal
## game (not a league save, where it would spoil the race).
func check_fri() -> void:
	_request("crown_fri", JSON.stringify({"cut": OnlineRules.FRI_CUTOFF}), func(res: String): on_fri(res))


func on_fri(res: String) -> void:
	var info := parse_crown(res)
	if info.is_empty():
		if res == "none" and Clock.now() >= OnlineRules.FRI_CUTOFF + 86400:
			data["fri"] = "none"
			_dirty = true
		return
	data["fri_name"] = str(info["name"])
	if str(info["uid"]) != uid or uid == "":
		data["fri"] = "lost"
	else:
		data["fri"] = "owed"
		pay_fri()
	_dirty = true


func pay_fri() -> void:
	if str(data["fri"]) != "owed" or Profiles.league_game():
		return
	data["fri"] = "won"
	_grant({"kind": "fri", "pearls": OnlineRules.FRI_PEARLS, "coins": OnlineRules.FRI_COINS})
	save_data()


func on_crown(res: String) -> void:
	if res.begins_with("error"):
		return
	var info := parse_crown(res)
	var b := race_board()
	var mine := float(_sent.get(race_kind(), -1.0))
	var stale := info.is_empty() or str(info["k"]) != str(b["k"]) or str(info["id"]) != str(b["id"])
	_set_crown({} if stale else info)
	if mine > 0.0 and not tester() and str(info.get("uid", "")) != uid and (stale or mine > float(info.get("score", 0.0))):
		_take_crown(mine)


static func parse_crown(res: String) -> Dictionary:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not d is Dictionary or str(d.get("uid", "")) == "":
		return {}
	var id := str(d["uid"])
	var sc = d.get("score", 0)
	return {"uid": id, "name": OnlineRules.board_name(str(d.get("name", "")), id), "k": str(d.get("k", "")),
		"id": str(d.get("id", "")), "score": maxf(0.0, float(sc)) if (sc is float or sc is int) else 0.0}


func _set_crown(info: Dictionary) -> void:
	var prev := str(crown.get("uid", ""))
	crown = info
	if str(info.get("uid", "")) != prev and not info.is_empty():
		if is_king():
			_tick_left = minf(_tick_left, 5.0)
		crown_changed.emit(info, prev)


func _take_crown(mine: float) -> void:
	var b := race_board()
	var arg := JSON.stringify({"name": board_name(), "k": b["k"], "id": b["id"]})
	_request("crown_take", arg, func(res: String):
		if res == "ok":
			_set_crown({"uid": uid, "name": board_name(), "k": b["k"], "id": b["id"], "score": mine}))


## The holder adds a minute at no. 1 to today's count (refused once the
## crown went to someone else: then it is read again).
func _crown_tick(now: float = -1.0) -> void:
	if tester():
		return
	var t := now if now >= 0.0 else Clock.now()
	var arg := JSON.stringify({"day": OnlineRules.day_id(t), "name": board_name()})
	_request("crown_tick", arg, func(res: String):
		if res.begins_with("ok:"):
			crown_minutes = res.substr(3).to_int()
		elif res.contains("permission"):
			_crown_left = minf(_crown_left, 1.0))


## Today's and yesterday's longest at no. 1: done.call({"ok", "today": [rows],
## "yesterday": [rows]}), rows {uid, name, score (minutes), you}.
func fetch_kings(done: Callable, now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Clock.now()
	_request("kings", JSON.stringify({"day": OnlineRules.day_id(t)}), func(res: String):
		var d = JSON.parse_string(res) if res.begins_with("{") else null
		if not d is Dictionary:
			done.call({"ok": false, "today": [], "yesterday": []})
			return
		var out := {"ok": true}
		for k in ["today", "yesterday"]:
			var rows: Array = []
			if d.get(k) is Array:
				for r in d[k]:
					if r is Dictionary and rows.size() < 5:
						var id := str(r.get("uid", ""))
						var row := {"uid": id, "name": OnlineRules.board_name(str(r.get("name", "")), id),
							"score": int(r.get("score", 0)) if (r.get("score") is float or r.get("score") is int) else 0, "you": id == uid and uid != ""}
						if not is_banned(row):
							rows.append(row)
			out[k] = rows
		done.call(out))


## Yesterday's place by minutes at no. 1 pays once (the day's king also
## gets the crown hat the first time).
func check_crown_prize(now: float = -1.0) -> void:
	if tester():
		return
	var t := now if now >= 0.0 else Clock.now()
	var last := OnlineRules.day_id(t) - 1
	if int(data["crown_prize"]) >= last:
		return
	_request("rank", JSON.stringify({"kind": "crown", "id": last}), func(res: String): on_crown_rank(last, res))


func on_crown_rank(day: int, res: String) -> void:
	if res == "none":
		data["crown_prize"] = day
		_dirty = true
		return
	if not res.begins_with("r:"):
		return
	var parts := res.split(":")
	if parts.size() < 3:
		return
	data["crown_prize"] = day
	var rank := parts[1].to_int()
	var minutes := parts[2].to_float()
	var prize := OnlineRules.crown_prize(rank, minutes)
	if not prize.is_empty():
		if rank == 1:
			data["crown_wins"] = int(data["crown_wins"]) + 1
		if bool(prize["item"]) and not Progress.is_owned(OnlineRules.CROWN_ITEM):
			Progress.grant_item(OnlineRules.CROWN_ITEM)
		_grant({"kind": "crown", "pearls": int(prize["pearls"]), "boost": float(prize["boost"]), "n": rank, "min": int(minutes)})
	save_data()


# --- Clubs ------------------------------------------------------------------------------------------

func in_club() -> bool:
	return str(data["club"]) != ""


func _club_arg(extra: Dictionary = {}) -> Dictionary:
	var a := {"name": board_name(), "s": score("week"), "w": int(data["week"])}
	a.merge(extra, true)
	return a


## Makes a new club with this player in it: done.call("ok" | "rude" | "error").
func club_create(text: String, done: Callable) -> void:
	var name := OnlineRules.club_name(text)
	if name == "":
		done.call("rude")
		return
	var id := ""
	var abc := "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
	for i in 8:
		id += abc[randi() % abc.length()]
	var old := str(data["club"])
	_request("club_create", JSON.stringify(_club_arg({"id": id, "club": name})), func(res: String):
		if res == "ok":
			_leave_old(old)
			_set_club(id, name)
		done.call("ok" if res == "ok" else "error"))


## Joins a club: done.call("ok" | "full" | "gone" | "error").
func club_join(id: String, done: Callable) -> void:
	if not OnlineRules.club_id_ok(id):
		done.call("gone")
		return
	if id == str(data["club"]):
		done.call("ok")
		return
	# The old club is left only once the new one took the player (a full
	# club must not leave them with none).
	var old := str(data["club"])
	_request("club_join", JSON.stringify(_club_arg({"id": id})), func(res: String):
		if res.begins_with("ok"):
			_leave_old(old)
			_set_club(id, res.trim_prefix("ok:"))
			done.call("ok")
		else:
			done.call(res if res in ["full", "gone"] else "error"))


## done.call("ok" | "error").
func club_leave(done: Callable) -> void:
	if not in_club():
		done.call("ok")
		return
	_request("club_leave", JSON.stringify({"id": str(data["club"]), "w": int(data["week"])}), func(res: String):
		if res == "ok" or res == "gone":
			_set_club("", "")
		done.call("ok" if res == "ok" or res == "gone" else "error"))


func _leave_old(old: String) -> void:
	if old != "":
		_request("club_leave", JSON.stringify({"id": old, "w": int(data["week"])}), func(_r: String): pass)


func _set_club(id: String, name: String) -> void:
	data["club"] = id
	data["club_name"] = OnlineRules.strip_name(name)
	_sent["p"] = ""
	_boards.erase("clubs")
	save_data()
	Achievements.check()
	state_changed.emit()


## A club and its members: done.call({"ok", "id", "name", "n", "owner",
## "members": [{uid, name, score, you}], "sum"}). A member's look also
## refreshes the club's weekly total on the club board.
func club_info(id: String, done: Callable) -> void:
	if not OnlineRules.club_id_ok(id):
		done.call({"ok": false})
		return
	_request("club", JSON.stringify(_club_arg({"id": id, "mine": id == str(data["club"])})), func(res: String):
		var info := parse_club(res, uid)
		if info["ok"] and id == str(data["club"]) and str(info["name"]) != str(data["club_name"]):
			data["club_name"] = str(info["name"])
			_dirty = true
		if res == "gone" and id == str(data["club"]):
			_set_club("", "")
		done.call(info))


## Members count this week's coins only (an old week counts 0).
static func parse_club(res: String, me: String) -> Dictionary:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not d is Dictionary or not d.get("members") is Array:
		return {"ok": false}
	var members: Array = []
	var sum := 0.0
	for r in d["members"]:
		if not r is Dictionary or members.size() >= OnlineRules.CLUB_MAX:
			continue
		var id := str(r.get("uid", ""))
		var s := float(r.get("score", 0)) if (r.get("score") is float or r.get("score") is int) else 0.0
		s = maxf(0.0, s) if is_finite(s) else 0.0
		sum += s
		members.append({"uid": id, "name": OnlineRules.board_name(str(r.get("name", "")), id), "score": s, "you": id == me and me != ""})
	members.sort_custom(func(x, y): return x["score"] > y["score"])
	return {"ok": true, "id": str(d.get("id", "")), "name": OnlineRules.strip_name(str(d.get("name", ""))),
		"n": members.size(), "owner": str(d.get("owner", "")), "members": members, "sum": sum}


# --- Rewards ------------------------------------------------------------------------------------

func _grant(info: Dictionary) -> void:
	var pearls := int(info.get("pearls", 0))
	if pearls > 0:
		Progress.add_pearls(pearls)
	if float(info.get("boost", 0.0)) > 0.0:
		GameState.add_boost(float(info["boost"]))
	if bool(info.get("item", false)):
		give_exclusive()
	var coins := float(info.get("coins", 0.0))
	if coins > 0.0 and is_finite(coins):
		# Gifted coins are left out of the scores (see track()).
		Progress.stats["promo_coins"] = float(Progress.stats.get("promo_coins", 0.0)) + coins
		GameState.add_coins(coins)
		track()
	Progress.save_game()
	pending_thanks.append(info)
	thanks.emit(info)


func give_exclusive() -> void:
	data["exclusive"] = true
	_dirty = true
	if not Progress.is_owned(OnlineRules.EXCLUSIVE_ITEM):
		Progress.grant_item(OnlineRules.EXCLUSIVE_ITEM)


func has_exclusive() -> bool:
	return bool(data.get("exclusive", false))


## The exclusive item belongs to the person: every local profile has it.
func _keep_exclusive() -> void:
	if has_exclusive() and not Progress.is_owned(OnlineRules.EXCLUSIVE_ITEM):
		Progress.owned[OnlineRules.EXCLUSIVE_ITEM] = true
		Progress.changed.emit()


func take_thanks() -> Dictionary:
	return pending_thanks.pop_front() if not pending_thanks.is_empty() else {}
