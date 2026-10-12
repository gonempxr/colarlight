class_name BattlePass
extends RefCounted
## The sea pass: free for everyone, earned only by playing. 30 levels of
## 100 XP; each level has a reward (pearls, coins, x2, and three items no
## one can buy). No timer and nothing to pay: when all 30 are taken the next
## chapter starts (items already owned become pearls).
##
## XP comes from things done, counted from the profile's counters (no hooks
## all over the game): tick() compares them with the last look.
## Kept in Progress.stats: bp_ch (chapter), bp_xp, bp_got (levels taken),
## bp_s_<source> (counters at the last look).

const LEVELS := 30
const XP_LEVEL := 100
## XP for each one done.
const XP := {"challenge": 100, "quest": 20, "star": 10, "chest": 15, "daily": 30, "fish": 2, "badge": 40, "minute": 1}
## Items: level -> id (chapter 1; later chapters pay ITEM_PEARLS instead
## when the item is owned).
const ITEMS := {10: "boat_reef", 20: "hat_coral_crown", 30: "hat_trident"}
const ITEM_PEARLS := 80


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


static func taken() -> int:
	return int(Progress.stats.get("bp_got", 0))


static func waiting() -> int:
	return maxi(0, level() - taken())


## Adds XP for what was done since the last look. Returns levels gained.
## The first look only remembers the counters (old saves start at zero).
static func tick() -> int:
	var now := counters()
	if not Progress.stats.has("bp_s_minute"):
		for k in now:
			Progress.stats["bp_s_" + k] = now[k]
		Progress.stats["bp_ch"] = 1
		Progress.stats["bp_xp"] = 0
		Progress.stats["bp_got"] = 0
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


## The reward of a level: {"pearls"}, {"coins_min"}, {"boost"} (s) or {"item"}.
static func reward(lv: int, ch: int = -1) -> Dictionary:
	var c := ch if ch > 0 else chapter()
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


## Takes every reached level's reward. Returns the total {"pearls",
## "coins", "boost", "items": []} (empty when nothing waited).
static func claim_all() -> Dictionary:
	var out := {"pearls": 0, "coins": 0.0, "boost": 0, "items": []}
	if waiting() <= 0:
		return {}
	for lv in range(taken() + 1, level() + 1):
		var r := reward(lv)
		out["pearls"] += int(r.get("pearls", 0))
		out["boost"] += int(r.get("boost", 0))
		if r.has("coins_min"):
			out["coins"] += Progress.coins_for_minutes(float(r["coins_min"]))
		if r.has("item") and not Progress.is_owned(str(r["item"])):
			out["items"].append(str(r["item"]))
	Progress.stats["bp_got"] = level()
	if out["pearls"] > 0:
		Progress.add_pearls(int(out["pearls"]))
	if out["coins"] > 0.0:
		GameState.add_coins(float(out["coins"]))
	if out["boost"] > 0:
		GameState.add_boost(float(out["boost"]))
	for id in out["items"]:
		Progress.grant_item(id)
	# All 30 taken: the next chapter starts with the XP left over.
	if taken() >= LEVELS:
		Progress.stats["bp_ch"] = chapter() + 1
		Progress.stats["bp_xp"] = maxi(0, xp() - LEVELS * XP_LEVEL)
		Progress.stats["bp_got"] = 0
	Progress.save_game()
	return out
