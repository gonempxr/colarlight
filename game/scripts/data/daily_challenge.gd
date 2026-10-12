class_name DailyChallenge
extends RefCounted
## The challenge of the day: the same task for everyone on a UTC day
## (picked from the day number), counted from what the player has done
## since the day started for them. Pays CHALLENGE_PEARLS once.
## Kept in the profile's Progress.stats: dc_day (day number), dc_base (the
## counter at the start), dc_goal, dc_done.

const PEARLS := 15
## [kind, needs feature ("" = none)]
const KINDS := [["earn", ""], ["taps", ""], ["puzzle", "puzzle"], ["fish", "fishing"], ["chest", "chests"], ["quests", "quests"]]


static func day_of(unix: float) -> int:
	return floori(unix / 86400.0)


## Today's kind: one of the kinds whose feature the player has.
static func kind_for(day: int) -> String:
	var open: Array[String] = []
	for k in KINDS:
		if k[1] == "" or Progress.has_feature(str(k[1])):
			open.append(str(k[0]))
	# Same order for everyone: the day picks from the full list, falling
	# back to the first open kind after it.
	var start := posmod(day * 7 + 3, KINDS.size())
	for i in KINDS.size():
		var k := str(KINDS[(start + i) % KINDS.size()][0])
		if k in open:
			return k
	return "taps"


static func _counter(kind: String) -> float:
	match kind:
		"earn":
			return float(GameState.total_earned)
		"taps":
			return float(Progress.stats.get("taps", 0))
		"puzzle":
			return float(Progress.stats.get("puzzles_won", 0))
		"fish":
			return float(Fishing.stats.get("caught", 0))
		"chest":
			return float(Progress.stats.get("chests", 0))
		"quests":
			return float(Progress.stats.get("quests_done", 0))
	return 0.0


static func _goal(kind: String) -> float:
	match kind:
		"earn":
			# 15 minutes of today's income (never tiny).
			return maxf(500.0, ceilf(GameState.income_rate() * 900.0))
		"taps":
			return 150.0
		"puzzle":
			return 1.0
		"fish":
			return 3.0
		"chest":
			return 1.0
		"quests":
			return 3.0
	return 1.0


## Starts a new day's challenge when the day changed. Call before reading.
static func refresh(now: float = -1.0) -> void:
	var t := now if now >= 0.0 else Time.get_unix_time_from_system()
	var day := day_of(t)
	if int(Progress.stats.get("dc_day", -1)) == day:
		return
	var kind := kind_for(day)
	Progress.stats["dc_day"] = day
	Progress.stats["dc_base"] = _counter(kind)
	Progress.stats["dc_goal"] = _goal(kind)
	Progress.stats["dc_done"] = 0


static func kind() -> String:
	return kind_for(int(Progress.stats.get("dc_day", day_of(Time.get_unix_time_from_system()))))


## [done so far, goal]
static func progress() -> Array:
	var k := kind()
	var goal := float(Progress.stats.get("dc_goal", 1.0))
	var now := maxf(0.0, _counter(k) - float(Progress.stats.get("dc_base", 0.0)))
	return [minf(now, goal), goal]


static func complete() -> bool:
	var p := progress()
	return float(p[0]) >= float(p[1])


static func claimed() -> bool:
	return int(Progress.stats.get("dc_done", 0)) > 0


## Pays the pearls once when complete. True when paid now.
static func claim() -> bool:
	if claimed() or not complete():
		return false
	Progress.stats["dc_done"] = 1
	Progress.add_pearls(PEARLS)
	Progress.save_game()
	return true
