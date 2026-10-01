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

const SAVE_VERSION := 2
## Version 2 added the lift to the tutorial (Tutor.STEPS): old step -> new.
const TUTORIAL_V1_TO_V2: Array[int] = [0, 1, 1, 1, 5, 7, 8, 9]
const CHEST_FIRST_SEC := 120.0
const CHEST_GAP_SEC := Vector2(150.0, 240.0)
const TICK_SEC := 1.0

var save_path := "user://progress.json"
var autosave_enabled := true

var pearls := 0
var pearls_total := 0
## artifact id -> {"level": int, "pieces": int}
var artifacts: Dictionary = {}
## [{"kind", "key", "goal", "count", "pearls", "coins_min"}]
var quests: Array = []
var owned: Dictionary = {}
## slot -> cosmetic id ("" = none)
var equipped: Dictionary = {}
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
	GameState.manager_hired.connect(func(_k): _count("hire", 1))
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
	owned = {}
	for c in Content.COSMETICS:
		if c["unlock"] == "free":
			owned[c["id"]] = true
	equipped = {"pet": "", "hat": "", "boat": "boat_classic", "suit": "suit_classic"}
	features = {}
	fresh = {}
	tutorial_step = 0
	daily_day = 0
	daily_last = ""
	puzzle_level = 1
	stats = {}
	chest_ready = false
	chest_timer = CHEST_FIRST_SEC
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
	GameState.bonus = b
	GameState.changed.emit()


## Rewards for a finished puzzle. Returns what was given, for the win panel:
## {"coins", "pearls", "piece": artifact id or "", "level": new level or 0}.
func puzzle_reward(result: Dictionary) -> Dictionary:
	var won: bool = result.get("won", false)
	var stars := clampi(int(result.get("stars", 0)), 0, 3)
	var mult := bonus("puzzle")
	var out := {"coins": 0.0, "pearls": 0, "piece": "", "level": 0}
	# Coins follow both the economy (minutes of income) and the puzzle level
	# played (see Content.puzzle_factor): replaying the game's early puzzle
	# levels late in the game pays less than reaching new ones.
	var got := int(result.get("fragments", 0))
	var lv := puzzle_level
	out["coins"] = coins_for_minutes(Content.puzzle_minutes(lv, won, stars, got)) * mult
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
	_check_goals()
	changed.emit()
	save_game()
	return gift


# --- Quests ---------------------------------------------------------------------

func _fill_quests() -> void:
	var added := false
	while quests.size() < Content.QUEST_SLOTS:
		quests.append(_new_quest())
		added = true
	if added:
		changed.emit()


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
	stats["prestiges"] = GameState.prestige_count
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
	stats["prestiges"] = GameState.prestige_count
	var data := {
		"version": SAVE_VERSION,
		"pearls": pearls, "pearls_total": pearls_total,
		"artifacts": artifacts, "quests": quests, "owned": owned, "equipped": equipped,
		"features": features, "fresh": fresh, "tutorial_step": tutorial_step,
		"daily_day": daily_day, "daily_last": daily_last, "puzzle_level": puzzle_level,
		"stats": stats, "chest_ready": chest_ready, "chest_timer": chest_timer,
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
	if d.get("quests") is Array:
		for q in d["quests"]:
			# A quest for a dive site that no longer exists (saves from the
			# 30-site version) is dropped; a new one fills its slot.
			var qkey := str(q.get("key", "")) if q is Dictionary else ""
			if qkey != "" and not qkey in GameState.stage_keys():
				continue
			if q is Dictionary and str(q.get("kind", "")) in Content.QUEST_KINDS and quests.size() < Content.QUEST_SLOTS:
				quests.append({"kind": str(q["kind"]), "key": str(q.get("key", "")), "goal": maxf(1.0, _f(q.get("goal"))),
						"count": maxf(0.0, _f(q.get("count"))), "pearls": clampi(_int(q.get("pearls")), 1, 10)})
	for dict_key in ["owned", "features", "fresh"]:
		if d.get(dict_key) is Dictionary:
			var target: Dictionary = get(dict_key)
			for k in d[dict_key]:
				if d[dict_key][k] == true:
					target[str(k)] = true
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
	apply_bonus()
	_check_goals()
	return true


func reset_progress() -> void:
	reset()
	save_game()
	changed.emit()


static func _int(v) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0


static func _f(v) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else 0.0
