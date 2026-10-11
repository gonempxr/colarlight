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

const SAVE_PATH := "user://online.json"
## Scores go out every few minutes and at important moments (a new world,
## the page hidden, the board opened), never twice within a minute: the
## free Firebase plan allows 20 000 writes a day for all players together.
## (The rules refuse a second write within 30 s.)
const SUBMIT_SEC := 300.0
const SUBMIT_GAP_SEC := 60.0
## A board read is kept this long (50 reads each; 50 000 a day are free).
const BOARD_CACHE_SEC := 60.0
const TIMEOUT_SEC := 12.0
const POLL_SEC := 0.5
const TRACK_SEC := 5.0
const SAVE_SEC := 30.0
## The network side starts this long after the game (never during loading).
const BEGIN_SEC := 4.0

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
var _sent := {"all": -1.0, "week": -1.0, "name": ""}
var _ref_looks := 40
var _boards := {}
var _after_ready_done := false
var _begin_left := BEGIN_SEC


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
	submit()


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
		"seen_total": -1.0, "seen_profile": ""}


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
	var t := now if now >= 0.0 else Time.get_unix_time_from_system()
	var w := OnlineRules.week_id(t)
	if w != int(data["week"]):
		data["week"] = w
		data["week_score"] = 0.0
		_dirty = true
	var prof := str(Profiles.current_id)
	var total := float(GameState.total_earned)
	if str(data["seen_profile"]) == prof and float(data["seen_total"]) >= 0.0 and total > float(data["seen_total"]):
		data["week_score"] = float(data["week_score"]) + (total - float(data["seen_total"]))
		_dirty = true
	if str(data["seen_profile"]) != prof or float(data["seen_total"]) != total:
		_dirty = true
	data["seen_profile"] = prof
	data["seen_total"] = total
	if total > float(data["all_best"]):
		data["all_best"] = total
		_dirty = true


func score(kind: String) -> float:
	return float(data["week_score"]) if kind == "week" else float(data["all_best"])


func board_name() -> String:
	return OnlineRules.board_name(Profiles.player_name(), uid)


## A score worth sending soon (a new world, ...): within the rate limit.
func submit_soon() -> void:
	_submit_left = minf(_submit_left, maxf(1.0, SUBMIT_GAP_SEC - _since_submit))


## Sends both scores when they changed (at most every SUBMIT_GAP_SEC).
func submit(done: Callable = Callable()) -> void:
	track()
	var name := board_name()
	var changed := score("all") != float(_sent["all"]) or score("week") != float(_sent["week"]) or name != str(_sent["name"])
	if state != "ready" or not changed or _since_submit < SUBMIT_GAP_SEC or score("all") <= 0.0:
		if done.is_valid():
			done.call(false)
		return
	_since_submit = 0.0
	var sent := {"all": score("all"), "week": score("week"), "name": name}
	var arg := JSON.stringify({"name": name, "a": JSON.stringify(Settings.avatar), "all": sent["all"], "week": sent["week"],
		"w": int(data["week"])})
	_request("submit", arg, func(res: String):
		if res == "ok":
			_sent = sent
		if done.is_valid():
			done.call(res == "ok"))


## The board: done.call({"ok", "rows": [{uid, name, score, a, you}], "rank"}).
## kind: "week" or "all".
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
		var arg := JSON.stringify({"kind": kind, "w": int(data["week"]), "score": score(kind)})
		_request("board", arg, func(res: String):
			var board := parse_board(res, uid)
			if board["ok"]:
				_boards[kind] = {"at": Time.get_ticks_msec() / 1000.0, "w": int(data["week"]), "board": board}
			done.call(board))
	submit(ask)


static func parse_board(res: String, me: String) -> Dictionary:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not d is Dictionary or not d.get("rows") is Array:
		return {"ok": false, "rows": [], "rank": 0}
	var rows: Array = []
	for r in d["rows"]:
		if not r is Dictionary or rows.size() >= 50:
			continue
		var id := str(r.get("uid", ""))
		var s := float(r.get("score", 0)) if (r.get("score") is float or r.get("score") is int) else 0.0
		rows.append({"uid": id, "name": OnlineRules.board_name(str(r.get("name", "")), id), "score": maxf(0.0, s),
			"a": str(r.get("a", "")), "you": id == me and me != ""})
	return {"ok": true, "rows": rows, "rank": maxi(0, int(d.get("rank", 0)))}


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
	var info := {"kind": "promo", "pearls": int(p.get("pearls", 0)), "boost": float(p.get("boost", 0.0)), "item": p.has("item")}
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


# --- Rewards ------------------------------------------------------------------------------------

func _grant(info: Dictionary) -> void:
	var pearls := int(info.get("pearls", 0))
	if pearls > 0:
		Progress.add_pearls(pearls)
	if float(info.get("boost", 0.0)) > 0.0:
		GameState.add_boost(float(info["boost"]))
	if bool(info.get("item", false)):
		give_exclusive()
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
