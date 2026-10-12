class_name Achievements
extends RefCounted
## Achievements: badges for things the player has done, each paying a few
## pearls once. Unlocked ones live in the profile's Progress.stats as
## "ach_<id>" = 1 (so every local player has their own). main.gd calls
## check() now and then and shows a toast for each new badge.
##
## [id, icon, tier (0 bronze, 1 silver, 2 gold), target, pearls]

const LIST := [
	["coins_1m", "coin", 0, 1e6, 5],
	["coins_1b", "coin", 1, 1e9, 10],
	["coins_1t", "coin", 2, 1e12, 20],
	["coins_1aa", "coin", 2, 1e15, 30],
	["world_2", "play", 0, 2, 10],
	["world_4", "play", 2, 4, 25],
	["puzzle_10", "puzzle", 0, 10, 10],
	["puzzle_50", "puzzle", 1, 50, 20],
	["fish_10", "fishing", 0, 10, 5],
	["fish_100", "fishing", 1, 100, 15],
	["fish_legend", "fishing", 2, 1, 15],
	["streak_7", "bolt", 1, 7, 15],
	["daily_30", "gift", 1, 30, 20],
	["chests_25", "chest", 0, 25, 10],
	["quests_50", "quests", 1, 50, 15],
	["taps_1000", "helmet", 0, 1000, 5],
	["week_top10", "star", 1, 10, 20],
	["week_win", "star", 2, 1, 50],
	["founder", "star", 2, 1, 10],
	["friend", "people", 0, 1, 10],
	["club", "people", 0, 1, 5],
]

const TIER_COLORS: Array[Color] = [Color("d9905a"), Color("c9d3e0"), Color("ffcc33")]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for a in LIST:
		out.append(str(a[0]))
	return out


static func info(id: String) -> Array:
	for a in LIST:
		if a[0] == id:
			return a
	return []


static func has(id: String) -> bool:
	return int(Progress.stats.get("ach_" + id, 0)) > 0


static func count() -> int:
	var n := 0
	for a in LIST:
		if has(str(a[0])):
			n += 1
	return n


## How far the player is: [now, target] (for the progress line).
static func progress(id: String) -> Array:
	var a := info(id)
	if a.is_empty():
		return [0.0, 1.0]
	var target := float(a[3])
	return [minf(_value(id), target), target]


static func _value(id: String) -> float:
	var fs: Dictionary = Fishing.stats
	match id:
		"coins_1m", "coins_1b", "coins_1t", "coins_1aa":
			return maxf(float(GameState.total_earned), float(Online.data.get("all_best", 0.0)))
		"world_2", "world_4":
			return float(maxi(int(GameState.max_location), int(Progress.stats.get("location", 0))) + 1)
		"puzzle_10", "puzzle_50":
			return float(Progress.stats.get("puzzles_won", 0))
		"fish_10", "fish_100":
			return float(fs.get("caught", 0))
		"fish_legend":
			return float(fs.get("legendary", 0))
		"streak_7":
			return float(maxi(int(Progress.streak_best), int(Progress.stats.get("streak_best", 0))))
		"daily_30":
			return float(Progress.stats.get("daily_claimed", 0))
		"chests_25":
			return float(Progress.stats.get("chests", 0))
		"quests_50":
			return float(Progress.stats.get("quests_done", 0))
		"taps_1000":
			return float(Progress.stats.get("taps", 0))
		"week_top10":
			var r := int(Online.data.get("best_rank", 0))
			return 10.0 if r > 0 and r <= 10 else 0.0
		"week_win":
			return 1.0 if int(Online.data.get("best_rank", 0)) == 1 else 0.0
		"founder":
			return 1.0 if int(Online.data.get("founder", 0)) > 0 else 0.0
		"friend":
			return 1.0 if Online.friends_paid() > 0 or str(Online.data.get("referred_by", "")) != "" else 0.0
		"club":
			return 1.0 if str(Online.data.get("club", "")) != "" else 0.0
	return 0.0


## Unlocks what is reached; pays the pearls. Returns the new ids.
static func check() -> Array[String]:
	var got: Array[String] = []
	for a in LIST:
		var id := str(a[0])
		if has(id):
			continue
		if _value(id) >= float(a[3]):
			Progress.stats["ach_" + id] = 1
			Progress.add_pearls(int(a[4]))
			got.append(id)
	if not got.is_empty():
		Progress.save_game()
	return got
