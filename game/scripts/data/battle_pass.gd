class_name BattlePass
extends RefCounted
## The Sea Pass: free for everyone, earned only by playing. 30 levels of
## 100 XP and two tracks of rewards, like the passes of other games but
## with nothing to pay:
## - the main track ("f"): pearls, coins, x2, and three items no one can buy;
## - the bonus track ("b"): opened by doing BONUS_NEED challenges of the
##   day in this chapter (playing, not paying).
## No timer: when the whole main track is taken the next chapter starts
## (bonus rewards reached by then are given too; owned items become pearls).
##
## XP comes from things done, counted from the profile's counters (no hooks
## all over the game): tick() compares them with the last look.
## Kept in Progress.stats: bp_ch (chapter), bp_xp, bp_f<lv> / bp_b<lv>
## (taken), bp_dc0 (challenges done when the chapter began), bp_s_<source>
## (counters at the last look).

const LEVELS := 30
const XP_LEVEL := 100
const BONUS_NEED := 5
## Or the bonus track is opened at once for pearls (earned in the game,
## never bought: there is nothing to buy), once per chapter.
const BONUS_PEARLS := 1500
## XP for each one done.
const XP := {"challenge": 100, "quest": 40, "star": 10, "chest": 15, "daily": 30, "fish": 2, "badge": 40, "minute": 1}
## Items on the main track: level -> id (later chapters pay ITEM_PEARLS
## instead when the item is owned).
const ITEMS := {10: "boat_reef", 20: "hat_coral_crown", 30: "hat_trident"}
const ITEM_PEARLS := 80
const ROWS: Array[String] = ["f", "b"]


static func counters() -> Dictionary:
	return {
		"challenge": int(Progress.stats.get("dc_claims", 0)),
		"quest": int(Progress.stats.get("quests_done", 0)),
		"star": int(Progress.stats.get("puzzle_stars", 0)),
		"chest": int(Progress.stats.get("chests", 0)),
		"daily": int(Progress.stats.get("daily_claimed", 0)),
		"fish": int(Fishing.stats.get("caught", 0)),
		"badge": Achievements.count(),
		"minute": int(float(Progress.stats.get("play_time", 0.0)) / 60.0),
	}


static func chapter() -> int:
	return maxi(1, int(Progress.stats.get("bp_ch", 1)))


static func xp() -> int:
	return int(Progress.stats.get("bp_xp", 0))


static func level() -> int:
	return mini(LEVELS, xp() / XP_LEVEL)


## XP inside the current level (0..XP_LEVEL).
static func xp_in_level() -> int:
	return XP_LEVEL if level() >= LEVELS else xp() - level() * XP_LEVEL


static func challenges_done() -> int:
	return maxi(0, int(Progress.stats.get("dc_claims", 0)) - int(Progress.stats.get("bp_dc0", 0)))


static func bonus_open() -> bool:
	return challenges_done() >= BONUS_NEED or int(Progress.stats.get("bp_paid", 0)) == chapter()


## Opens the bonus track for BONUS_PEARLS. False when open or too few pearls.
static func buy_bonus() -> bool:
	if bonus_open() or not Progress.spend_pearls(BONUS_PEARLS):
		return false
	Progress.stats["bp_paid"] = chapter()
	Progress.save_game()
	return true


static func taken(row: String, lv: int) -> bool:
	_migrate()
	return int(Progress.stats.get("bp_%s%d" % [row, lv], 0)) > 0


static func ready(row: String, lv: int) -> bool:
	return lv <= level() and not taken(row, lv) and (row == "f" or bonus_open())


static func waiting() -> int:
	var n := 0
	for row in ROWS:
		for lv in range(1, level() + 1):
			if ready(row, lv):
				n += 1
	return n


## The first version kept "levels taken" as one number (bp_got).
static func _migrate() -> void:
	if not Progress.stats.has("bp_got"):
		return
	for lv in range(1, mini(LEVELS, int(Progress.stats["bp_got"])) + 1):
		Progress.stats["bp_f%d" % lv] = 1
	Progress.stats.erase("bp_got")
	if not Progress.stats.has("bp_dc0"):
		Progress.stats["bp_dc0"] = int(Progress.stats.get("dc_claims", 0))


## Adds XP for what was done since the last look. Returns levels gained.
## The first look only remembers the counters (old saves start at zero).
static func tick() -> int:
	_migrate()
	var now := counters()
	if not Progress.stats.has("bp_s_minute"):
		for k in now:
			Progress.stats["bp_s_" + k] = now[k]
		Progress.stats["bp_ch"] = 1
		Progress.stats["bp_xp"] = 0
		Progress.stats["bp_dc0"] = int(now["challenge"])
		return 0
	var gain := 0
	for k in now:
		var before := int(Progress.stats.get("bp_s_" + k, now[k]))
		if now[k] > before:
			gain += (now[k] - before) * int(XP[k])
		# A counter going down (profile reset) just moves the mark.
		Progress.stats["bp_s_" + k] = now[k]
	if gain <= 0:
		return 0
	return add_xp(gain)


static func add_xp(n: int) -> int:
	var old := level()
	# XP past the last level waits for the next chapter (capped at one).
	Progress.stats["bp_xp"] = mini(xp() + n, LEVELS * XP_LEVEL * 2)
	return level() - old


## The reward of a level on a track: {"pearls"}, {"coins_min"}, {"boost"}
## (s) or {"item"} (with "pearls" on the last level).
static func reward(row: String, lv: int, ch: int = -1) -> Dictionary:
	var c := ch if ch > 0 else chapter()
	if row == "b":
		# Worth more than its BONUS_PEARLS price over a chapter.
		if lv % 10 == 0:
			return {"pearls": 200 + lv * 5}
		if lv % 5 == 0:
			return {"boost": 7200}
		if lv % 2 == 0:
			return {"coins_min": 30 + lv}
		return {"pearls": 30 + lv * 2}
	if ITEMS.has(lv):
		var id: String = ITEMS[lv]
		if c == 1 or not Progress.is_owned(id):
			return {"item": id, "pearls": 50 if lv == LEVELS else 0}
		return {"pearls": ITEM_PEARLS}
	if lv % 5 == 0:
		return {"boost": 1800}
	if lv % 3 == 0:
		return {"coins_min": 10 + lv}
	return {"pearls": 5 + lv / 3}


static func level_of_item(id: String) -> int:
	for lv in ITEMS:
		if ITEMS[lv] == id:
			return lv
	return LEVELS


## Takes one reward. Returns what was given {"pearls", "coins", "boost",
## "items"} (empty when it was not ready).
static func claim(row: String, lv: int) -> Dictionary:
	if not ready(row, lv):
		return {}
	var out := _empty()
	_give(row, lv, out)
	_pay(out)
	_maybe_next_chapter(out)
	Progress.save_game()
	return out


## Takes every ready reward on both tracks.
static func claim_all() -> Dictionary:
	if waiting() <= 0:
		return {}
	var out := _empty()
	for row in ROWS:
		for lv in range(1, level() + 1):
			if ready(row, lv):
				_give(row, lv, out)
	_pay(out)
	_maybe_next_chapter(out)
	Progress.save_game()
	return out


static func _empty() -> Dictionary:
	return {"pearls": 0, "coins": 0.0, "boost": 0, "items": []}


static func _give(row: String, lv: int, out: Dictionary) -> void:
	var r := reward(row, lv)
	Progress.stats["bp_%s%d" % [row, lv]] = 1
	out["pearls"] += int(r.get("pearls", 0))
	out["boost"] += int(r.get("boost", 0))
	if r.has("coins_min"):
		out["coins"] += Progress.coins_for_minutes(float(r["coins_min"]))
	if r.has("item") and not Progress.is_owned(str(r["item"])):
		out["items"].append(str(r["item"]))


static func _pay(out: Dictionary) -> void:
	if int(out["pearls"]) > 0:
		Progress.add_pearls(int(out["pearls"]))
	if float(out["coins"]) > 0.0:
		GameState.add_coins(float(out["coins"]))
	if int(out["boost"]) > 0:
		GameState.add_boost(float(out["boost"]))
	for id in out["items"]:
		Progress.grant_item(id)


## The whole main track taken: the bonus rewards reached are given too
## (nothing is lost), then the next chapter starts with the XP left over.
static func _maybe_next_chapter(out: Dictionary) -> void:
	for lv in range(1, LEVELS + 1):
		if not taken("f", lv):
			return
	var extra := _empty()
	if bonus_open():
		for lv in range(1, level() + 1):
			if not taken("b", lv):
				_give("b", lv, extra)
		_pay(extra)
		for k in ["pearls", "boost"]:
			out[k] += extra[k]
		out["coins"] += extra["coins"]
	for row in ROWS:
		for lv in range(1, LEVELS + 1):
			Progress.stats.erase("bp_%s%d" % [row, lv])
	Progress.stats["bp_ch"] = chapter() + 1
	Progress.stats["bp_xp"] = maxi(0, xp() - LEVELS * XP_LEVEL)
	Progress.stats["bp_dc0"] = int(Progress.stats.get("dc_claims", 0))
	out["chapter"] = chapter()
