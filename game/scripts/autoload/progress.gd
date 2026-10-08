extends Node
## Everything around the economy: pearls, artifacts (from puzzles), quests,
## floating chests, the daily gift, cosmetics, which features are open, the
## tutorial and stats. Saved per profile next to GameState's save.
## Registered as the Progress autoload (after GameState).
##
## Artifact levels become multipliers in GameState.bonus.

signal changed
signal feature_unlocked(id: String)
signal quest_done(index: int)
signal pearls_earned(amount: int)
signal item_unlocked(id: String)
signal artifact_leveled(id: String, level: int)
signal chest_spawned
signal decor_changed
signal skins_changed
## The first small action of a new day lit the streak flame (see streak_action).
signal streak_lit(result: Dictionary)

const SAVE_VERSION := 2
## Version 2 added the lift to the tutorial (Tutor.STEPS): old step -> new.
const TUTORIAL_V1_TO_V2: Array[int] = [0, 1, 1, 1, 5, 7, 8, 9]
## Old evolution forms seen (0..12) -> gear levels bought (0..3).
const OLD_FORMS_TO_GEAR: Array[int] = [0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
const CHEST_FIRST_SEC := 120.0
const CHEST_GAP_SEC := Vector2(150.0, 240.0)
const TICK_SEC := 1.0

var save_path := "user://progress.json"
var autosave_enabled := true

var pearls := 0
var pearls_total := 0
## artifact id -> {"level": int, "pieces": int}
var artifacts: Dictionary = {}
## Quests of the active world: [{"kind", "key", "goal", "count", "pearls"}].
## Quests belong to the world they were made in: the other worlds' lists
## wait in world_quests (str(L) -> Array) and come back on a switch.
var quests: Array = []
## Location the `quests` list belongs to.
var quest_loc := 0
var world_quests: Dictionary = {}
var owned: Dictionary = {}
## slot -> cosmetic id ("" = none)
var equipped: Dictionary = {}
## Room 3 decor: slot (Content.DECOR_SLOTS) -> level 0..Content.DECOR_MAX.
var decor: Dictionary = {}
## World id -> highest gear level bought there so far (0..3, for the codex).
var looks_seen: Dictionary = {}
## Worker skins owned (Content.SKINS id -> true) and the one each world's
## workers wear (world id -> skin id, "" = none).
var skins: Dictionary = {}
var skin_on: Dictionary = {}
var features: Dictionary = {}
## Features whose button still shows "NEW".
var fresh: Dictionary = {}
var tutorial_step := 0
var daily_day := 0
var daily_last := ""
var puzzle_level := 1
var stats: Dictionary = {}
## A chest is floating when > 0 (its reward seed).
var chest_ready := false
var chest_timer := CHEST_FIRST_SEC
## Streak (days in a row with one small action; kids-safe, see streak_action).
var streak_count := 0
var streak_best := 0
## Local date ("YYYY-MM-DD") of the last day that counted.
var streak_last := ""
## Ice cubes: each covers one missed day (Content.STREAK_FREEZE_*).
var streak_freezes := Content.STREAK_FREEZE_START
## Milestone days already rewarded (once ever): "3" -> true.
var streak_claimed: Dictionary = {}
## Recent days: date -> "play" or "ice" (for the week strip).
var streak_log: Dictionary = {}
## Rewards waiting for the celebration to hand them out: {"pearls", "coins_min"}.
var streak_reward: Dictionary = {}

var _tick := TICK_SEC
var _save_left := 10.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("progress.json")
	reset()
	load_game()
	GameState.upgraded.connect(func(key, count):
		_count("upgrade", count)
		_count("upgrade_stage", count, key))
	GameState.tapped.connect(func(_k):
		stats["taps"] = int(stats.get("taps", 0)) + 1
		_count("tap", 1))
	GameState.coins_earned.connect(func(a): _count("earn", a))
	GameState.cycle_finished.connect(func(k, _a):
		if k.begins_with("d"):
			_count("mine", 1, k))
	GameState.manager_hired.connect(func(_k): _count("hire", 1))
	GameState.evo_bought.connect(func(_f): _see_looks())
	GameState.location_changed.connect(func(l):
		_swap_quests(l)
		_see_looks()
		apply_bonus()
		_check_goals())
	_streak_connect()
	GameState.depth_opened.connect(func(k):
		_count("open", 1)
		stats["deepest"] = maxi(int(stats.get("deepest", 0)), GameState.depth_index(k))
		add_pearls(3)
		_check_goals())


func reset() -> void:
	pearls = 0
	pearls_total = 0
	artifacts = {}
	for a in Content.ARTIFACTS:
		artifacts[a["id"]] = {"level": 0, "pieces": 0}
	quests = []
	quest_loc = 0
	world_quests = {}
	owned = {}
	for c in Content.COSMETICS:
		if c["unlock"] == "free":
			owned[c["id"]] = true
	equipped = {"pet": "", "hat": "", "boat": "boat_classic", "outfit": "outfit_casual"}
	decor = {}
	for slot in Content.DECOR_SLOTS:
		decor[slot] = 0
	looks_seen = {}
	skins = {}
	skin_on = {}
	features = {}
	fresh = {}
	tutorial_step = 0
	daily_day = 0
	daily_last = ""
	puzzle_level = 1
	stats = {}
	chest_ready = false
	chest_timer = CHEST_FIRST_SEC
	_streak_reset()
	apply_bonus()


func switch_profile() -> void:
	save_path = Profiles.file("progress.json")
	reset()
	load_game()
	changed.emit()


func _process(delta: float) -> void:
	stats["play_time"] = float(stats.get("play_time", 0.0)) + delta
	if has_feature("chests") and not chest_ready:
		chest_timer -= delta
		if chest_timer <= 0.0:
			chest_ready = true
			chest_spawned.emit()
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK_SEC
		_check_features()
		if has_feature("quests"):
			_fill_quests()
	if autosave_enabled:
		_save_left -= delta
		if _save_left <= 0.0:
			_save_left = 10.0
			save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled and is_inside_tree():
				save_game()


# --- Pearls ----------------------------------------------------------------------

func add_pearls(n: int) -> void:
	if n <= 0:
		return
	pearls += n
	pearls_total += n
	pearls_earned.emit(n)
	changed.emit()


func spend_pearls(n: int) -> bool:
	if n < 0 or pearls < n:
		return false
	pearls -= n
	changed.emit()
	return true


## Coins worth `minutes` of the current income (never less than a starter amount).
static func coins_for_minutes(minutes: float) -> float:
	return maxf(20.0 + minutes * 4.0, GameState.income_rate() * 60.0 * minutes)


func buy_boost() -> bool:
	if not spend_pearls(Content.BOOST_PRICE):
		return false
	GameState.add_boost(Content.BOOST_MIN * 60.0)
	return true


func buy_coins() -> bool:
	if not spend_pearls(Content.COINS_PRICE):
		return false
	GameState.add_coins(coins_for_minutes(Content.COINS_MIN))
	return true


# --- Features & tutorial --------------------------------------------------------

func has_feature(id: String) -> bool:
	return features.get(id, false)


func _check_features() -> void:
	var t := float(stats.get("play_time", 0.0))
	var want := {
		"daily": t >= 45.0,
		"chests": t >= 90.0,
		"quests": GameState.has_manager("boat") or t >= 150.0,
		"shop": pearls_total >= 8 or t >= 420.0,
		"puzzle": GameState.is_open("d1") and t >= 240.0,
		"museum": _any_piece(),
		"fishing": GameState.is_open("d2"),
	}
	for id in Content.FEATURES:
		if want.get(id, false) and not has_feature(id):
			unlock_feature(id)


func unlock_feature(id: String) -> void:
	features[id] = true
	fresh[id] = true
	feature_unlocked.emit(id)
	changed.emit()


func seen(id: String) -> void:
	if fresh.erase(id):
		changed.emit()


func _any_piece() -> bool:
	for id in artifacts:
		if artifacts[id]["pieces"] > 0 or artifacts[id]["level"] > 0:
			return true
	return false


func advance_tutorial(to_step: int) -> void:
	if to_step > tutorial_step:
		tutorial_step = to_step
		changed.emit()


# --- Artifacts & puzzle -----------------------------------------------------------

## The artifact the next won puzzle builds: the lowest level one, in order.
func target_artifact() -> String:
	var best := ""
	var best_level := Content.ARTIFACT_MAX
	for a in Content.ARTIFACTS:
		var lv: int = artifacts[a["id"]]["level"]
		if lv < best_level:
			best = a["id"]
			best_level = lv
	return best


func pieces_needed(id: String) -> int:
	var lv: int = artifacts[id]["level"]
	return Content.PIECES[mini(lv, Content.PIECES.size() - 1)]


func owned_artifacts() -> int:
	var n := 0
	for id in artifacts:
		if artifacts[id]["level"] > 0:
			n += 1
	return n


## Adds one piece; returns the new level when it completes one, else 0.
func add_piece(id: String) -> int:
	if not artifacts.has(id) or artifacts[id]["level"] >= Content.ARTIFACT_MAX:
		return 0
	var a: Dictionary = artifacts[id]
	a["pieces"] += 1
	var leveled := 0
	if a["pieces"] >= pieces_needed(id):
		a["pieces"] = 0
		a["level"] += 1
		leveled = a["level"]
		stats["artifacts_owned"] = owned_artifacts()
		apply_bonus()
		artifact_leveled.emit(id, leveled)
		_check_goals()
	changed.emit()
	return leveled


## Multiplier from artifacts for a bonus key.
func bonus(key: String) -> float:
	var m := 1.0
	for a in Content.ARTIFACTS:
		if a["bonus"] == key:
			m += a["per_level"] * artifacts.get(a["id"], {}).get("level", 0)
	return m


func apply_bonus() -> void:
	var b := {}
	for a in Content.ARTIFACTS:
		b[a["bonus"]] = bonus(a["bonus"])
	b["decor"] = decor_bonus()
	b["skin"] = skin_bonus()
	GameState.bonus = b
	GameState.changed.emit()


# --- Room 3 decor ------------------------------------------------------------------

func decor_level(slot: String) -> int:
	return int(decor.get(slot, 0))


## Pearl price of the slot's next level (0 when it is at the top level).
func decor_cost(slot: String) -> int:
	var lv := decor_level(slot)
	if not slot in Content.DECOR_SLOTS or lv >= Content.DECOR_MAX:
		return 0
	return Content.DECOR_PRICES[lv]


func buy_decor(slot: String) -> bool:
	var price := decor_cost(slot)
	if price <= 0 or not spend_pearls(price):
		return false
	decor[slot] = decor_level(slot) + 1
	apply_bonus()
	decor_changed.emit()
	changed.emit()
	save_game()
	return true


## Income multiplier from decor: +Balance.DECOR_BONUS per level of every slot.
func decor_bonus() -> float:
	var levels := 0
	for slot in Content.DECOR_SLOTS:
		levels += decor_level(slot)
	return 1.0 + Balance.DECOR_BONUS * levels


# --- Worker skins -------------------------------------------------------------------

func has_skin(id: String) -> bool:
	return skins.get(id, false) == true


## The skin the workers of `world` wear ("" = none).
func skin_of(world: String) -> String:
	var id := str(skin_on.get(world, ""))
	return id if has_skin(id) else ""


## Income multiplier from the skin worn in the current world.
func skin_bonus() -> float:
	var id := skin_of(GameState.world_id())
	if id == "":
		return 1.0
	return 1.0 + Balance.SKIN_BONUS[clampi(int(Content.skin(id).get("rarity", 0)), 0, 3)]


## Buys a skin with pearls and puts it on. False when owned or too dear.
func buy_skin(id: String) -> bool:
	var c := Content.skin(id)
	if c.is_empty() or has_skin(id):
		return false
	if not spend_pearls(Content.skin_price(id)):
		return false
	skins[id] = true
	wear_skin(id)
	save_game()
	return true


## Puts an owned skin on its world's workers; wearing it again takes it off.
func wear_skin(id: String) -> void:
	var c := Content.skin(id)
	if c.is_empty() or not has_skin(id):
		return
	var w: String = c["world"]
	skin_on[w] = "" if skin_of(w) == id else id
	apply_bonus()
	skins_changed.emit()
	changed.emit()


## Remembers the gear bought in the current world (the codex shows it).
func _see_looks() -> void:
	var w: String = GameState.world_id()
	if GameState.evo > int(looks_seen.get(w, 0)):
		looks_seen[w] = GameState.evo
		changed.emit()


## Rewards for a finished puzzle. Returns what was given, for the win panel:
## {"coins", "pearls", "piece": artifact id or "", "level": new level or 0}.
func puzzle_reward(result: Dictionary) -> Dictionary:
	var won: bool = result.get("won", false)
	var stars := clampi(int(result.get("stars", 0)), 0, 3)
	var mult := bonus("puzzle")
	var out := {"coins": 0.0, "pearls": 0, "piece": "", "level": 0}
	# Coins follow the puzzle progress: minutes of income, each minute
	# capped by the puzzle level (Content.puzzle_minute_cap), times the level
	# factor. Grinding the main game does not make puzzle level 1 pay millions.
	var got := int(result.get("fragments", 0))
	var lv := puzzle_level
	var minutes := Content.puzzle_minutes(lv, won, stars, got)
	var per_min := minf(GameState.income_rate() * 60.0, Content.puzzle_minute_cap(lv))
	out["coins"] = maxf(20.0 + minutes * 4.0, per_min * minutes) * mult
	out["pearls"] = Content.puzzle_pearls(lv, won, stars, got)
	if won:
		var id := str(result.get("artifact", ""))
		if not artifacts.has(id):
			id = target_artifact()
		if id != "":
			out["piece"] = id
			out["level"] = add_piece(id)
		stats["puzzles_won"] = int(stats.get("puzzles_won", 0)) + 1
		puzzle_level += 1
		_count("puzzle", 1)
	GameState.add_coins(out["coins"])
	add_pearls(out["pearls"])
	streak_action()
	_check_goals()
	save_game()
	return out


# --- Chests ----------------------------------------------------------------------

## Opens the floating chest: {"coins", "pearls"}.
func open_chest() -> Dictionary:
	if not chest_ready:
		return {}
	chest_ready = false
	chest_timer = _rng.randf_range(CHEST_GAP_SEC.x, CHEST_GAP_SEC.y)
	var mult := bonus("chest")
	var out := {"coins": coins_for_minutes(1.5) * mult, "pearls": 0}
	if _rng.randf() < 0.3:
		out["pearls"] = _rng.randi_range(1, 3)
	GameState.add_coins(out["coins"])
	add_pearls(out["pearls"])
	stats["chests"] = int(stats.get("chests", 0)) + 1
	streak_action()
	_count("chest", 1)
	changed.emit()
	return out


# --- Daily gift --------------------------------------------------------------------

static func today() -> String:
	return Time.get_date_string_from_system()


func daily_ready() -> bool:
	return has_feature("daily") and daily_last != today()


## Claims today's gift: {"kind", "amount", "value"}.
func claim_daily() -> Dictionary:
	if not daily_ready():
		return {}
	var gift: Dictionary = Content.DAILY[daily_day % Content.DAILY.size()].duplicate()
	var week := daily_day / Content.DAILY.size()
	match gift["kind"]:
		"coins":
			gift["value"] = coins_for_minutes(gift["amount"])
			GameState.add_coins(gift["value"])
		"pearls":
			gift["value"] = int(gift["amount"]) + week * 5
			add_pearls(gift["value"])
		"boost":
			gift["value"] = gift["amount"]
			GameState.add_boost(float(gift["amount"]) * 60.0)
	daily_day += 1
	daily_last = today()
	stats["daily_claimed"] = int(stats.get("daily_claimed", 0)) + 1
	streak_action()
	_check_goals()
	changed.emit()
	save_game()
	return gift


# --- Streak --------------------------------------------------------------------------
## Days in a row with one small action (an upgrade, a tap, a claim...), not
## just opening the game. Kind rules for kids: no timers or warnings; a
## missed day eats an ice cube (start with one, one more every
## STREAK_FREEZE_EVERY days, at most STREAK_FREEZE_MAX); without enough ice
## the flame starts again at 1, the best record stays and nothing owned is
## lost. A local date earlier than the last counted one (a clock moved back)
## never breaks or extends the streak.

const STREAK_LOG_DAYS := 21


func _streak_reset() -> void:
	streak_count = 0
	streak_best = 0
	streak_last = ""
	streak_freezes = Content.STREAK_FREEZE_START
	streak_claimed = {}
	streak_log = {}
	streak_reward = {}


func _streak_connect() -> void:
	GameState.upgraded.connect(func(_k, _c): streak_action())
	GameState.manager_hired.connect(func(_k): streak_action())
	GameState.tapped.connect(func(_k): streak_action())
	# Fishing is loaded after Progress.
	(func():
		var f := get_node_or_null("/root/Fishing")
		if f and f.has_signal("caught"):
			f.caught.connect(func(_fish): streak_action())).call_deferred()


## Day number of a "YYYY-MM-DD" date (-1 when it is not a date).
static func day_number(date: String) -> int:
	if date.length() < 10:
		return -1
	var u := Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00")
	if u == 0 and not date.begins_with("1970-01-01"):
		return -1
	return int(floor(float(u) / 86400.0))


static func date_of(day: int) -> String:
	return Time.get_date_string_from_unix_time(day * 86400 + 43200)


## Counts the day of a small action. Returns {} when nothing changed (the
## day already counted, the feature is not open yet, or the clock went back),
## else {"count", "old", "best", "ice_used", "ice_earned", "broken",
## "milestone" (days or 0), "reward": {"pearls", "coins_min"}} and emits
## streak_lit. The reward waits in streak_reward until take_streak_reward.
func streak_action(date: String = "") -> Dictionary:
	if not has_feature("daily"):
		return {}
	if date == "":
		date = today()
	if date == streak_last:
		return {}
	var t := day_number(date)
	if t < 0:
		return {}
	var l := day_number(streak_last)
	if l >= 0 and t <= l:
		return {}
	var old := streak_count
	var out := {"old": old, "ice_used": 0, "ice_earned": false, "broken": false, "milestone": 0}
	if l < 0 or old <= 0:
		streak_count = 1
	elif t == l + 1:
		streak_count += 1
	else:
		var missed := t - l - 1
		if missed <= streak_freezes:
			streak_freezes -= missed
			out["ice_used"] = missed
			for i in missed:
				streak_log[date_of(l + 1 + i)] = "ice"
			streak_count += 1
		else:
			# Too long away: a new flame. The best record and the ice stay.
			out["broken"] = true
			streak_count = 1
	streak_last = date
	streak_log[date] = "play"
	_streak_trim_log(t)
	streak_best = maxi(streak_best, streak_count)
	stats["streak_best"] = streak_best
	if streak_count % Content.STREAK_FREEZE_EVERY == 0 and streak_freezes < Content.STREAK_FREEZE_MAX:
		streak_freezes += 1
		out["ice_earned"] = true
	var reward := {"pearls": Content.STREAK_DAY_PEARLS, "coins_min": 0.0}
	for m in Content.STREAK_MILESTONES:
		var days := int(m["days"])
		if streak_count >= days and not streak_claimed.has(str(days)):
			streak_claimed[str(days)] = true
			out["milestone"] = days
			reward["pearls"] += int(m.get("pearls", 0))
			reward["coins_min"] += float(m.get("coins_min", 0.0))
	streak_reward = {"pearls": int(streak_reward.get("pearls", 0)) + reward["pearls"],
			"coins_min": float(streak_reward.get("coins_min", 0.0)) + reward["coins_min"]}
	out["count"] = streak_count
	out["best"] = streak_best
	out["reward"] = reward
	_check_goals()
	streak_lit.emit(out)
	changed.emit()
	return out


## Hands out the rewards the celebration shows: {"pearls", "coins"}.
func take_streak_reward() -> Dictionary:
	if streak_reward.is_empty():
		return {}
	var out := {"pearls": int(streak_reward.get("pearls", 0)), "coins": 0.0}
	var minutes := float(streak_reward.get("coins_min", 0.0))
	if minutes > 0.0:
		out["coins"] = coins_for_minutes(minutes)
		GameState.add_coins(out["coins"])
	streak_reward = {}
	add_pearls(out["pearls"])
	changed.emit()
	return out


## The flame as it stands today: the count while it can still go on (today
## or yesterday counted, or the ice covers the gap), else 0.
func streak_shown(date: String = "") -> int:
	if streak_count <= 0:
		return 0
	var t := day_number(today() if date == "" else date)
	var l := day_number(streak_last)
	if t < 0 or l < 0 or t <= l + 1:
		return streak_count
	return streak_count if t - l - 1 <= streak_freezes else 0


## Today already counted (the flame burns bright).
func streak_today(date: String = "") -> bool:
	var t := day_number(today() if date == "" else date)
	var l := day_number(streak_last)
	return l >= 0 and t <= l


## The streak would start again at the next action (shown as a warm welcome).
func streak_will_restart(date: String = "") -> bool:
	return streak_count > 0 and streak_shown(date) == 0


## The last `n` days up to `date`: [{"date", "state": "play" | "ice" | "today" | ""}].
func streak_week(date: String = "", n: int = 7) -> Array:
	var t := day_number(today() if date == "" else date)
	var out := []
	for i in n:
		var d := date_of(t - n + 1 + i)
		var st := str(streak_log.get(d, ""))
		if st == "" and i == n - 1:
			st = "today"
		out.append({"date": d, "state": st})
	return out


## The next milestone not reached yet (Content.STREAK_MILESTONES entry), or {}.
func streak_next_milestone() -> Dictionary:
	for m in Content.STREAK_MILESTONES:
		if not streak_claimed.has(str(int(m["days"]))):
			return m
	return {}


func _streak_trim_log(t: int) -> void:
	for d in streak_log.keys():
		var n := day_number(str(d))
		if n < 0 or n <= t - STREAK_LOG_DAYS or n > t + 1:
			streak_log.erase(d)


func _streak_save() -> Dictionary:
	return {"version": 1, "count": streak_count, "best": streak_best, "last": streak_last,
			"freezes": streak_freezes, "claimed": streak_claimed, "log": streak_log, "reward": streak_reward}


func _streak_load(s) -> void:
	_streak_reset()
	if not s is Dictionary:
		return
	streak_count = maxi(0, _int(s.get("count")))
	streak_best = maxi(streak_count, _int(s.get("best")))
	streak_last = str(s.get("last", ""))
	if day_number(streak_last) < 0:
		streak_last = ""
		streak_count = 0
	streak_freezes = clampi(_int(s.get("freezes")), 0, Content.STREAK_FREEZE_MAX) if s.has("freezes") else Content.STREAK_FREEZE_START
	if s.get("claimed") is Dictionary:
		for k in s["claimed"]:
			if s["claimed"][k] == true:
				streak_claimed[str(k)] = true
	if s.get("log") is Dictionary:
		for k in s["log"]:
			var v := str(s["log"][k])
			if day_number(str(k)) >= 0 and v in ["play", "ice"]:
				streak_log[str(k)] = v
	if s.get("reward") is Dictionary:
		var p := clampi(_int(s["reward"].get("pearls")), 0, 1000)
		var c := clampf(_f(s["reward"].get("coins_min")), 0.0, 600.0)
		if p > 0 or c > 0.0:
			streak_reward = {"pearls": p, "coins_min": c}
	stats["streak_best"] = maxi(int(stats.get("streak_best", 0)), streak_best)


# --- Quests ---------------------------------------------------------------------

func _fill_quests() -> void:
	var added := false
	while quests.size() < Content.QUEST_SLOTS:
		quests.append(_new_quest())
		added = true
	if added:
		changed.emit()


## The active world changed: its own quests come back, the old ones wait.
func _swap_quests(l: int) -> void:
	if l == quest_loc:
		return
	world_quests[str(quest_loc)] = quests
	var back = world_quests.get(str(l), [])
	world_quests.erase(str(l))
	quests = back if back is Array else []
	quest_loc = l
	if has_feature("quests"):
		_fill_quests()
	changed.emit()


## Open dive sites of the active world ("d0".."d9").
static func _open_sites() -> Array:
	return GameState.stage_keys().filter(func(k): return GameState.depth_index(k) >= 0 and GameState.is_open(k))


func _new_quest() -> Dictionary:
	var kinds: Array[String] = ["upgrade", "tap", "earn", "upgrade_stage"]
	if has_feature("chests"):
		kinds.append("chest")
	if has_feature("puzzle"):
		kinds.append("puzzle")
	var hire_left := false
	for key in GameState.stage_keys():
		if GameState.is_open(key) and not GameState.has_manager(key):
			hire_left = true
	if hire_left:
		kinds.append("hire")
	if GameState.next_depth() != "":
		kinds.append("open")
	# World flavour: bring up the ore of one of this world's sites.
	kinds.append("mine")
	var taken := quests.map(func(q): return q["kind"])
	var options := kinds.filter(func(k): return k not in taken)
	if options.is_empty():
		options = kinds
	var kind: String = options[_rng.randi() % options.size()]
	var done := int(stats.get("quests_done", 0))
	var step := 1.0 + minf(done, 40.0) * 0.1
	var q := {"kind": kind, "key": "", "goal": 1.0, "count": 0.0, "pearls": 2}
	match kind:
		"upgrade":
			q["goal"] = roundf(5.0 * step)
		"upgrade_stage":
			var open := GameState.stage_keys().filter(func(k): return GameState.is_open(k))
			q["key"] = open[_rng.randi() % open.size()]
			q["goal"] = roundf(3.0 * step)
		"tap":
			q["goal"] = roundf(20.0 * step / 5.0) * 5.0
		"mine":
			# One of the deeper open sites (this world's best ores), about
			# a minute or two of its trips.
			var sites := _open_sites()
			var pick: int = maxi(0, sites.size() - 1 - _rng.randi() % mini(3, sites.size()))
			q["key"] = sites[pick]
			var cycle := float(GameState.stage_data(q["key"])["cycle"])
			q["goal"] = maxf(5.0, roundf(75.0 / cycle * step / 5.0) * 5.0)
		"earn":
			q["goal"] = _nice(coins_for_minutes(2.0 + minf(done, 20.0) * 0.1))
		"hire", "open":
			q["goal"] = 1.0
			q["pearls"] = 3
		"puzzle":
			q["goal"] = 1.0
			q["pearls"] = 3
		"chest":
			q["goal"] = 1.0 if done < 10 else 2.0
	return q


## Rounds to 2 significant digits so goals read nicely.
static func _nice(v: float) -> float:
	if v < 10.0:
		return ceilf(v)
	var p := pow(10.0, floor(log(v) / log(10.0)) - 1.0)
	return ceilf(v / p) * p


func _count(kind: String, amount: float, key: String = "") -> void:
	for i in quests.size():
		var q: Dictionary = quests[i]
		if q["kind"] != kind or q["count"] >= q["goal"]:
			continue
		if q["key"] != "" and q["key"] != key:
			continue
		q["count"] = minf(q["goal"], q["count"] + amount)
		if q["count"] >= q["goal"]:
			quest_done.emit(i)
		changed.emit()


func quest_complete(i: int) -> bool:
	return i >= 0 and i < quests.size() and quests[i]["count"] >= quests[i]["goal"]


func quests_ready() -> int:
	var n := 0
	for i in quests.size():
		if quest_complete(i):
			n += 1
	return n


## Claims a finished quest: {"coins", "pearls"}.
func claim_quest(i: int) -> Dictionary:
	if not quest_complete(i):
		return {}
	var q: Dictionary = quests[i]
	var out := {"coins": coins_for_minutes(1.0), "pearls": int(q["pearls"])}
	quests.remove_at(i)
	streak_action()
	stats["quests_done"] = int(stats.get("quests_done", 0)) + 1
	GameState.add_coins(out["coins"])
	add_pearls(out["pearls"])
	_fill_quests()
	save_game()
	return out


# --- Cosmetics -------------------------------------------------------------------

func is_owned(id: String) -> bool:
	return owned.get(id, false)


## Goal progress 0..1 for goal-unlocked items.
func goal_progress(goal: String) -> float:
	var g: Array = Content.GOALS.get(goal, ["", 1])
	return clampf(float(stats.get(g[0], 0)) / float(g[1]), 0.0, 1.0)


func _check_goals() -> void:
	_sync_location_stats()
	for c in Content.COSMETICS:
		if c["unlock"] == "goal" and not is_owned(c["id"]) and goal_progress(c["goal"]) >= 1.0:
			owned[c["id"]] = true
			item_unlocked.emit(c["id"])
	changed.emit()


func buy_item(id: String) -> bool:
	var c := Content.cosmetic(id)
	if c.is_empty() or is_owned(id) or c["unlock"] != "pearls":
		return false
	if not spend_pearls(int(c["price"])):
		return false
	owned[id] = true
	equip(id)
	save_game()
	return true


## Gives an item bought with real money (called by Platform after payment).
func grant_item(id: String) -> void:
	if Content.cosmetic(id).is_empty():
		return
	owned[id] = true
	item_unlocked.emit(id)
	save_game()
	changed.emit()


## Suits are gone; kept for older UI code.
func suit_bonus() -> float:
	return 0.0


## "prestiges" (old Dives, now locations left) and "location" (the highest
## reached) never go down: a migrated save starts at location 0.
func _sync_location_stats() -> void:
	stats["prestiges"] = maxi(int(stats.get("prestiges", 0)), GameState.max_location)
	stats["location"] = maxi(int(stats.get("location", 0)), GameState.max_location)


func equip(id: String) -> void:
	var c := Content.cosmetic(id)
	if c.is_empty() or not is_owned(id):
		return
	var slot: String = c["slot"]
	# Tapping the equipped pet or hat again takes it off.
	if equipped.get(slot, "") == id and slot in ["pet", "hat"]:
		equipped[slot] = ""
	else:
		equipped[slot] = id
	changed.emit()


func equipped_art(slot: String) -> String:
	var id: String = equipped.get(slot, "")
	return str(Content.cosmetic(id).get("art", "")) if id != "" else ""


# --- Save --------------------------------------------------------------------------

func save_game() -> bool:
	_sync_location_stats()
	var data := {
		"version": SAVE_VERSION,
		"pearls": pearls, "pearls_total": pearls_total,
		"artifacts": artifacts, "quests": quests, "quest_loc": quest_loc, "world_quests": world_quests,
		"owned": owned, "equipped": equipped,
		"features": features, "fresh": fresh, "tutorial_step": tutorial_step,
		"daily_day": daily_day, "daily_last": daily_last, "puzzle_level": puzzle_level,
		"stats": stats, "chest_ready": chest_ready, "chest_timer": chest_timer,
		"decor": decor, "looks_seen": looks_seen, "skins": skins, "skin_on": skin_on,
		"streak": _streak_save(),
	}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(tmp, save_path) == OK


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var json := JSON.new()
	var d = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not d is Dictionary:
		push_warning("Progress save is corrupted, starting fresh")
		return false
	pearls = maxi(0, _int(d.get("pearls")))
	pearls_total = maxi(pearls, _int(d.get("pearls_total")))
	if d.get("artifacts") is Dictionary:
		for id in artifacts:
			var a = d["artifacts"].get(id)
			if a is Dictionary:
				artifacts[id] = {"level": clampi(_int(a.get("level")), 0, Content.ARTIFACT_MAX), "pieces": maxi(0, _int(a.get("pieces")))}
	quests = _parse_quests(d.get("quests"))
	# Saves from before per-world quests: the list belongs to the world
	# being played.
	quest_loc = clampi(_int(d.get("quest_loc")), 0, Balance.LAST_LOCATION) if d.has("quest_loc") else int(GameState.location)
	if d.get("world_quests") is Dictionary:
		for k in d["world_quests"]:
			var l: int = str(k).to_int() if str(k).is_valid_int() else -1
			if l >= 0 and l <= Balance.LAST_LOCATION and l != quest_loc:
				world_quests[str(l)] = _parse_quests(d["world_quests"][k])
	if quest_loc != int(GameState.location):
		_swap_quests(int(GameState.location))
	# The diver suits are gone: pearls spent on them come back (once: the
	# suits are not kept in `owned`, so the next save has none).
	var refund := 0
	if d.get("owned") is Dictionary:
		for id in Content.OLD_SUIT_PRICES:
			if d["owned"].get(id) == true:
				refund += int(Content.OLD_SUIT_PRICES[id])
	for dict_key in ["owned", "features", "fresh"]:
		if d.get(dict_key) is Dictionary:
			var target: Dictionary = get(dict_key)
			for k in d[dict_key]:
				if d[dict_key][k] == true:
					target[str(k)] = true
	for id in owned.keys():
		if str(id).begins_with("suit_"):
			owned.erase(id)
	if refund > 0:
		pearls += refund
		pearls_total += refund
		stats["suit_refund"] = int(stats.get("suit_refund", 0)) + refund
	if d.get("equipped") is Dictionary:
		for slot in Content.SLOTS:
			var id := str(d["equipped"].get(slot, equipped.get(slot, "")))
			if id == "" or (is_owned(id) and Content.cosmetic(id).get("slot") == slot):
				equipped[slot] = id
	tutorial_step = maxi(0, _int(d.get("tutorial_step")))
	if _int(d.get("version")) < 2:
		tutorial_step = TUTORIAL_V1_TO_V2[mini(tutorial_step, TUTORIAL_V1_TO_V2.size() - 1)]
	daily_day = maxi(0, _int(d.get("daily_day")))
	daily_last = str(d.get("daily_last", ""))
	puzzle_level = maxi(1, _int(d.get("puzzle_level")))
	if d.get("stats") is Dictionary:
		for k in d["stats"]:
			if d["stats"][k] is float or d["stats"][k] is int:
				stats[str(k)] = d["stats"][k]
	chest_ready = d.get("chest_ready") == true
	chest_timer = clampf(_f(d.get("chest_timer")), 1.0, CHEST_GAP_SEC.y)
	if d.get("decor") is Dictionary:
		for slot in Content.DECOR_SLOTS:
			decor[slot] = clampi(_int(d["decor"].get(slot)), 0, Content.DECOR_MAX)
	if d.get("looks_seen") is Dictionary:
		var gear_save := d.get("skins") is Dictionary
		for w in d["looks_seen"]:
			var n := _int(d["looks_seen"][w])
			if not gear_save:
				# 3.0 counted 12 forms: about every fourth one is a gear level.
				n = OLD_FORMS_TO_GEAR[clampi(n, 0, OLD_FORMS_TO_GEAR.size() - 1)]
			looks_seen[str(w)] = clampi(n, 0, Balance.EVO_FORMS)
	if d.get("skins") is Dictionary:
		for id in d["skins"]:
			if d["skins"][id] == true and not Content.skin(str(id)).is_empty():
				skins[str(id)] = true
	if d.get("skin_on") is Dictionary:
		for w in d["skin_on"]:
			var id := str(d["skin_on"][w])
			if has_skin(id) and Content.skin(id).get("world") == str(w):
				skin_on[str(w)] = id
	_streak_load(d.get("streak"))
	_see_looks()
	apply_bonus()
	_check_goals()
	return true


static func _parse_quests(list) -> Array:
	var out := []
	if not list is Array:
		return out
	for q in list:
		# A quest for a dive site that no longer exists (saves from the
		# 30-site version) is dropped; a new one fills its slot.
		var qkey := str(q.get("key", "")) if q is Dictionary else ""
		if qkey != "" and not qkey in GameState.stage_keys():
			continue
		if q is Dictionary and str(q.get("kind", "")) in Content.QUEST_KINDS and out.size() < Content.QUEST_SLOTS:
			out.append({"kind": str(q["kind"]), "key": qkey, "goal": maxf(1.0, _f(q.get("goal"))),
					"count": maxf(0.0, _f(q.get("count"))), "pearls": clampi(_int(q.get("pearls")), 1, 10)})
	return out


func reset_progress() -> void:
	reset()
	save_game()
	changed.emit()


static func _int(v) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0


static func _f(v) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else 0.0
