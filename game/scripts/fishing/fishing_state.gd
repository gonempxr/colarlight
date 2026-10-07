extends Node
## Fishing: the bucket, the fish book (collection), the upgrades (rod,
## bucket, the hired fisherman) and stats. Saved per profile in
## Profiles.file("fishing.json"). Registered as the Fishing autoload
## (after GameState and Progress). Never touches UI classes.
##
## A fish is {"id": String, "size": float (cm), "value": float (coins)}.
## Its value is fixed when it is caught (seconds of the income at that
## moment, see FishData.price), so the bucket never changes price.
##
## The screen drives the player's fishing: roll_fish() -> record() ->
## keep() or sell_fish(). The fisherman works by himself in _process
## (advance()), also while the fishing screen is closed, and catches up
## for time away (up to FishData.OFFLINE_CAP_SEC, only while the bucket
## has room).

signal changed
## Any fish that reached the bucket or was sold from the catch card.
signal caught(fish: Dictionary)
signal helper_caught(fish: Dictionary)
signal sold(coins: float)
signal upgraded(kind: String, level: int)

## 2: one rod per world ("rods"); version 1 had a single "rod" (now the ocean rod).
const SAVE_VERSION := 2
const UPGRADES: Array[String] = ["rod", "bucket", "helper"]

var save_path := "user://fishing.json"
var autosave_enabled := true

var bucket: Array = []
## species id -> {"count": int, "best": float (cm)}
var book: Dictionary = {}
## Rod level index (0..19) in each world: ocean, volcano, acid, moon.
var rods: Array[int] = [0, 0, 0, 0]
## The rod of the world the player is in now.
var rod: int:
	get:
		return rods[world()]
	set(value):
		rods[world()] = clampi(value, 0, FishData.max_level("rod"))
## Tests and screenshots: fish in this world (-1 = the player's world).
var world_override := -1
var bucket_level := 0
## 0 = no fisherman yet.
var helper := 0
var helper_timer := 0.0
## caught, sold, coins, escaped, helper, legendary
var stats: Dictionary = {}

var _offline_catch := 0
var _save_left := 10.0
var _dirty := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("fishing.json")
	reset()
	load_game()


func reset() -> void:
	bucket = []
	book = {}
	rods = [0, 0, 0, 0]
	bucket_level = 0
	helper = 0
	helper_timer = 0.0
	stats = {}
	_offline_catch = 0


## Profiles switched: save the old player's fishing (save_path still points
## at their folder), then load the new player's.
func switch_profile() -> void:
	if autosave_enabled and DirAccess.dir_exists_absolute(save_path.get_base_dir()):
		save_game()
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("fishing.json")
	reset()
	load_game()
	changed.emit()


func _process(delta: float) -> void:
	advance(delta)
	if autosave_enabled:
		_save_left -= delta
		if _save_left <= 0.0:
			_save_left = 10.0
			if _dirty:
				save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled and is_inside_tree():
				save_game()


# --- Queries -------------------------------------------------------------------------

## Income in coins per second that prices follow (without the x2 boost, so
## prices don't jump while it runs).
func base_rate() -> float:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return FishData.MIN_RATE
	var r: float = gs.income_rate()
	if float(gs.get("boost_left")) > 0.0:
		r /= 2.0
	return maxf(r, FishData.MIN_RATE)


## World index 0..3 the fishing happens in (GameState's world).
func world() -> int:
	if world_override >= 0:
		return world_override % 4
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("world_index"):
		return 0
	return posmod(int(gs.world_index()), 4)


## Rod levels of every world added up (they all grow the bucket a little).
func rod_total() -> int:
	var n := 0
	for r in rods:
		n += r
	return n


func capacity() -> int:
	return FishData.capacity(bucket_level, rod_total())


func space() -> int:
	return maxi(0, capacity() - bucket.size())


func is_full() -> bool:
	return bucket.size() >= capacity()


func bucket_value() -> float:
	var total := 0.0
	for f in bucket:
		total += float(f["value"])
	return total


func found() -> int:
	return book.size()


func has_found(id: String) -> bool:
	return book.has(id)


func count_of(id: String) -> int:
	return int(book.get(id, {}).get("count", 0))


func best_of(id: String) -> float:
	return float(book.get(id, {}).get("best", 0.0))


func helper_interval() -> float:
	return FishData.helper_interval(helper)


## 0..1 until the fisherman's next fish.
func helper_progress() -> float:
	var iv := helper_interval()
	return clampf(helper_timer / iv, 0.0, 1.0) if iv > 0.0 else 0.0


func level(kind: String) -> int:
	match kind:
		"rod":
			return rod
		"bucket":
			return bucket_level
		"helper":
			return helper
	return 0


func is_maxed(kind: String) -> bool:
	return level(kind) >= FishData.max_level(kind)


## Coins for the next level (-1 when maxed). Scales with income.
func upgrade_cost(kind: String) -> float:
	var m := FishData.upgrade_minutes(kind, level(kind))
	if m < 0.0:
		return -1.0
	return ceilf(maxf(20.0 + m * 4.0, base_rate() * 60.0 * m))


func can_buy(kind: String) -> bool:
	var cost := upgrade_cost(kind)
	var gs := get_node_or_null("/root/GameState")
	return cost >= 0.0 and gs != null and float(gs.coins) >= cost


func buy(kind: String) -> bool:
	if not can_buy(kind):
		return false
	var gs := get_node("/root/GameState")
	gs.coins -= upgrade_cost(kind)
	match kind:
		"rod":
			rod += 1
		"bucket":
			bucket_level += 1
		"helper":
			helper += 1
			if helper == 1:
				helper_timer = 0.0
	gs.changed.emit()
	upgraded.emit(kind, level(kind))
	changed.emit()
	save_game()
	return true


# --- Catching ------------------------------------------------------------------------

## A new random fish for the player (or the fisherman: common/uncommon only).
func roll_fish(for_helper: bool = false) -> Dictionary:
	var w := FishData.helper_odds(rod) if for_helper else FishData.odds(rod)
	return make_fish(FishData.pick_rarity(w, rng.randf()))


## A random fish of the given rarity.
func make_fish(rarity: int) -> Dictionary:
	var list := FishData.of_rarity(rarity)
	var id: String = list[rng.randi() % list.size()]
	var size := FishData.size_from_roll(id, rng.randf())
	return {"id": id, "size": size, "value": FishData.price(id, size, base_rate())}


## Writes a catch into the fish book: {"new": bool, "record": bool}.
func record(fish: Dictionary) -> Dictionary:
	var id := str(fish.get("id", ""))
	if FishData.species(id).is_empty():
		return {"new": false, "record": false}
	var size := float(fish.get("size", 0.0))
	var is_new := not book.has(id)
	var entry: Dictionary = book.get(id, {"count": 0, "best": 0.0})
	var is_record := not is_new and size > float(entry["best"])
	entry["count"] = int(entry["count"]) + 1
	entry["best"] = maxf(float(entry["best"]), size)
	book[id] = entry
	stats["caught"] = int(stats.get("caught", 0)) + 1
	if FishData.rarity_of(id) == FishData.LEGENDARY:
		stats["legendary"] = int(stats.get("legendary", 0)) + 1
	_dirty = true
	changed.emit()
	return {"new": is_new, "record": is_record}


## Puts a fish in the bucket. False when it's full.
func keep(fish: Dictionary) -> bool:
	if is_full() or FishData.species(str(fish.get("id", ""))).is_empty():
		return false
	bucket.append({"id": str(fish["id"]), "size": float(fish.get("size", 0.0)), "value": maxf(0.0, float(fish.get("value", 0.0)))})
	_dirty = true
	caught.emit(fish)
	changed.emit()
	return true


## Sells a fish straight from the catch card.
func sell_fish(fish: Dictionary) -> float:
	var v := maxf(0.0, float(fish.get("value", 0.0)))
	caught.emit(fish)
	_pay(v, 1)
	return v


func sell_at(i: int) -> float:
	if i < 0 or i >= bucket.size():
		return 0.0
	var f: Dictionary = bucket[i]
	bucket.remove_at(i)
	var v := float(f["value"])
	_pay(v, 1)
	return v


func sell_all() -> float:
	if bucket.is_empty():
		return 0.0
	var v := bucket_value()
	var n := bucket.size()
	bucket = []
	_pay(v, n)
	return v


func note_escaped() -> void:
	stats["escaped"] = int(stats.get("escaped", 0)) + 1
	_dirty = true


func _pay(v: float, n: int) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and v > 0.0:
		gs.add_coins(v)
	stats["sold"] = int(stats.get("sold", 0)) + n
	stats["coins"] = float(stats.get("coins", 0.0)) + v
	sold.emit(v)
	changed.emit()
	save_game()


# --- The fisherman ---------------------------------------------------------------------

## Runs the fisherman for `seconds`. Returns how many fish he caught.
## He waits (timer stops) while the bucket is full.
func advance(seconds: float) -> int:
	var iv := helper_interval()
	if iv <= 0.0 or seconds <= 0.0:
		return 0
	var n := 0
	var left := seconds
	while left > 0.0:
		if is_full():
			# He waits with his next fish ready.
			helper_timer = minf(helper_timer + left, iv)
			break
		var need := iv - helper_timer
		if left < need:
			helper_timer += left
			break
		left -= need
		helper_timer = 0.0
		var fish := roll_fish(true)
		record(fish)
		keep(fish)
		stats["helper"] = int(stats.get("helper", 0)) + 1
		helper_caught.emit(fish)
		n += 1
	return n


## Fish the fisherman caught while the game was closed (read once).
func take_offline_catch() -> int:
	var n := _offline_catch
	_offline_catch = 0
	return n


# --- Save ------------------------------------------------------------------------------

func save_game() -> bool:
	_dirty = false
	var data := {
		"version": SAVE_VERSION, "bucket": bucket, "book": book, "rods": rods, "rod": rods[0],
		"bucket_level": bucket_level, "helper": helper, "helper_timer": helper_timer,
		"stats": stats, "saved_at": Time.get_unix_time_from_system(),
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
		push_warning("Fishing save is corrupted, starting fresh")
		return false
	var top := FishData.max_level("rod")
	if d.get("rods") is Array:
		var arr: Array = d["rods"]
		for i in mini(arr.size(), 4):
			rods[i] = clampi(_int(arr[i]), 0, top)
	else:
		# Version 1: one rod for all, it becomes the ocean rod.
		rods[0] = clampi(_int(d.get("rod")), 0, top)
	bucket_level = clampi(_int(d.get("bucket_level")), 0, FishData.max_level("bucket"))
	helper = clampi(_int(d.get("helper")), 0, FishData.max_level("helper"))
	if d.get("book") is Dictionary:
		for id in d["book"]:
			var e = d["book"][id]
			if e is Dictionary and not FishData.species(str(id)).is_empty():
				var c := maxi(0, _int(e.get("count")))
				if c > 0:
					book[str(id)] = {"count": c, "best": maxf(0.0, _f(e.get("best")))}
	if d.get("bucket") is Array:
		for f in d["bucket"]:
			if f is Dictionary and not FishData.species(str(f.get("id", ""))).is_empty() and bucket.size() < capacity():
				bucket.append({"id": str(f["id"]), "size": maxf(0.0, _f(f.get("size"))), "value": maxf(0.0, _f(f.get("value")))})
	if d.get("stats") is Dictionary:
		for k in d["stats"]:
			if d["stats"][k] is float or d["stats"][k] is int:
				stats[str(k)] = d["stats"][k]
	helper_timer = clampf(_f(d.get("helper_timer")), 0.0, maxf(0.0, helper_interval()))
	var saved_at := _f(d.get("saved_at"))
	if helper > 0 and saved_at > 0.0:
		var away := clampf(Time.get_unix_time_from_system() - saved_at, 0.0, FishData.OFFLINE_CAP_SEC)
		_offline_catch = advance(away)
	return true


func reset_progress() -> void:
	reset()
	save_game()
	changed.emit()


static func _int(v) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0


static func _f(v) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else 0.0
