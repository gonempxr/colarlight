extends Node
## The whole economy: dive sites -> lift -> boat -> plant -> coins.
## Registered as the GameState autoload. UI only reads from here and calls actions.
##
## Stage keys: "d0".."dN" (dive sites, shallow to deep), "lift", "boat", "plant",
## and the second boat and plant, "boat2" and "plant2", bought later in a run
## (closed at level 0). Both boats carry from the same raft to the same
## shore; both plants work the same shore pile.
## Divers always work on their own; a tap pushes their dive forward and a
## site's manager (foreman) doubles its output. The lift, the boat and the
## plant run one cycle per tap until their manager automates them; that
## automation is kept through a Dive (prestige).
## Divers put ore into the crates at their depth (`pit`, one pool), the
## lift brings it up to the raft (`hold`), the boat moves it to `dock`
## (on shore), the plant turns dock ore into coins. Finished coins land in
## the `vault` (room 3) until the player collects them, or by themselves
## once the accountant (manager "vault") is hired.
##
## Worlds: the player goes through locations L = 0, 1, 2... (world L % 5,
## tier L / 5). Every location scales values and prices (Balance.loc_scale).
## A location is done when all 10 sites are open with their foremen and the
## lift, boats and plants have managers; then a big price opens the next one
## (advance_location: the run resets, automation is kept). Worker evolution
## forms (12 per location) each give x1.10 income in this location.
##
## Every opened world keeps its own run (Idle Miner style): coins, vault,
## site and building levels, foremen and managers, gear and the ore piles.
## The active world lives in the plain variables; the others wait in
## `worlds_runs` (one snapshot each) and earn "while you were away" for the
## time they sat inactive when the player comes back (switch_location).
## `max_location` is the highest world opened; the gate to the next world
## is only there.
##
## Stars (the endgame): once the last world is open, a world whose gate
## checklist is done can take a star (get_star): its run restarts with its
## automation, its numbers grow (Balance.star_scale) and every star owned
## adds Balance.STAR_BONUS income to every world. `world_stars`.

signal changed
signal cycle_started(key: String, amount: float)
signal cycle_finished(key: String, amount: float)
signal milestone_reached(key: String, level: int)
signal rush_started
signal coins_earned(amount: float)
## Player actions, for character reactions and sounds.
signal upgraded(key: String, count: int)
signal manager_hired(key: String)
signal depth_opened(key: String)
signal tapped(key: String)
signal location_changed(L: int)
signal evo_bought(form: int)
signal vault_changed
## switch_location() moved to another opened world; `away` = coins its
## automation earned while it waited (0 if none).
signal location_switched(L: int, away: float)
## A world took a star: `stars` = how many it has now.
signal star_gained(L: int, stars: int)
## A mine boss was beaten (MineBoss): its site can be opened now.
signal boss_defeated(key: String, boss: String)
## The player wants to fight the guard of site `key` (main opens BossScreen).
signal boss_requested(key: String)
## The Murk was swept away (a beaten guard, Murk).
signal murk_cleansed

## 3: 15 dive sites instead of 30 (older saves are folded, see OLD_DEPTH_FOLD).
## 4: worlds and locations, 10 sites (v3 saves fold with V3_SITE_FOLD into
## location 0; their Dive count becomes legacy_mult).
## 5: the fifth world (Jungle) is location 4; older saves never go past the
## Moon (3) (location 4 there was the old "Ocean ★2" repeat).
const SAVE_VERSION := 5
## Save version 3 -> 4: which old sites (of 15) each of the 10 sites takes
## its level and foreman from (the best of them).
const V3_SITE_FOLD: Array = [[0], [1], [2], [3], [4], [5], [6], [7, 8, 9], [10, 11], [12, 13, 14]]
## Saves from the 30-site version (save version 2 or older): which old
## sites each site from d7 on takes its level and foreman from (the best of
## them). Sites d0..d6 keep their own. The old sites' prices and outputs
## follow the same curve, so a folded site works like the one it replaces.
const OLD_DEPTH_FOLD: Array = [[7, 8], [9, 10], [11, 12], [13, 14], [15, 16], [17, 18], [19, 20], [21, 22, 23, 24, 25, 26, 27, 28, 29]]
const RUSH_PER_TAP := 0.08
const RUSH_DECAY := 0.15
const RUSH_SEC := 5.0
const RUSH_SPEED := 2.0
## Offline progress is simulated in steps of this many seconds.
const OFFLINE_STEP := 1.0
## The x2 boost never runs longer than this (pearls and rewards).
const BOOST_CAP_SEC := 24.0 * 3600.0
## A watched rewarded ad: x2 for this long, stacking up to AD_BOOST_CAP_SEC.
const AD_BOOST_SEC := 30.0 * 60.0
const AD_BOOST_CAP_SEC := 4.0 * 3600.0

var save_path := "user://coralight2.json"
var autosave_enabled := true

var coins := 0.0
var total_earned := 0.0
## Location index L (world L % 5), 0..Balance.LAST_LOCATION.
var location := 0:
	set(value):
		location = clampi(value, 0, Balance.last_location())
		_rescale()
		_ensure_keys()
## Highest location opened so far (>= location). The gate lives there.
var max_location := 0:
	set(value):
		max_location = clampi(value, 0, Balance.last_location())
## Runs of the opened worlds that are not active: str(L) -> snapshot
## (_run_snapshot). A world opened before this existed (old saves) has none
## and starts a fresh run on its first visit (see _fresh_world_run).
var worlds_runs: Dictionary = {}
## Stars of each world: str(L) -> count (0 when missing). Kept forever.
var world_stars: Dictionary = {}
## Coins already sent into a world by the coin exchange: "<world>:<stars>" ->
## coins received there (capped, see exchange_cap()).
var exchanged: Dictionary = {}
## Mine bosses beaten in this run: site key -> true (MineBoss).
var bosses: Dictionary = {}
## The saga's Murk, 0..1 (Murk; only in the saga's worlds).
var murk := 0.0
## Saga story scenes already shown (SagaStory), id -> true.
var story: Dictionary = {}
## The boss fight party's experience (Party), class id -> XP.
var party_xp: Dictionary = {}
## Relics (Relics, the saga's loot) owned: relic dicts; "hero" = the class
## wearing it ("" in the bag). Kept for the whole league game.
var relics: Array = []
## Shards from melted relics (pay for rerolls).
var relic_shards := 0
## Worn relics' totals per stat (cached, see _relic_totals()).
var _relic_tot: Dictionary = {}
## True while offline time is paid: no tides or rifts then.
var _calm := false
## The saga's Ancient One was beaten (Nightmare open).
var saga_done := false
## The world boss (WorldBoss): this league's id, my damage in taps, the
## reward taken.
var wb := {"l": 0, "dmg": 0.0, "claimed": false}
## R'lyeh's open rifts: site key -> taps still needed (Rifts; not saved).
var rifts: Dictionary = {}
var _rift_in := Rifts.EVERY
## Worker gear levels bought in this location (0..Balance.EVO_FORMS): the
## workers wear gear level evo + 1 (1..4).
var evo := 0
## Coins given back when an old save's evolution forms became gear (0 if none).
var gear_refund := 0.0
## Finished coins waiting in room 3 to be collected.
var vault := 0.0
## False in a new player's first minutes: plant coins go straight to the
## wallet until the tutorial brings in the office (Tutor, step hire_vault).
var vault_on := true
## Permanent income multiplier from the old Dive Deeper count (v3 saves).
var legacy_mult := 1.0
## Old name of the location counter (the Dive count), kept for older code.
var prestige_count: int:
	get:
		return location
	set(value):
		location = value
## Cached Balance.star_scale / star_gate_scale of the location (with its stars).
var _scale := 1.0
var _gate_scale := 1.0
var levels: Dictionary = {}
var managers: Dictionary = {}
## Ore the divers left in the crates at the depths, waiting for the lift.
var pit := 0.0
var hold := 0.0
var dock := 0.0
var rush_meter := 0.0
var rush_left := 0.0
## Income x2 boost (from pearls, rewards, a watched ad) and its seconds left.
## It runs on real time: the end is kept as a Unix time (also in the save),
## so it ends on time while the game is closed or the tab sleeps.
var boost_left: float:
	get:
		return maxf(0.0, boost_end - now())
	set(value):
		boost_end = now() + clampf(value, 0.0, BOOST_CAP_SEC)
		_boosted = boost_end > now()
## Unix time when the x2 boost ends (0 = none).
var boost_end := 0.0
## Cached "boost is on" for the hot income math; refreshed every frame.
var _boosted := false
## The game turns the Saturday x2 on (main.gd); tests leave it off so their
## numbers do not depend on the day they run.
var x2_days_on := false
## Screenshots: pretend it is Saturday.
var x2_force := false
## Saturday (UTC): x2 coins for everyone (OnlineRules.is_x2_day), live
## play only; refreshed every frame like _boosted.
var x2_day := false
## Extra multipliers per stage key from artifacts and the like ("all" = every
## stage). Filled by Progress; not saved here.
var bonus: Dictionary = {}

## Per-stage cycle state: seconds elapsed in the current cycle (-1 = idle)
## and the amount the cycle carries.
var _timer: Dictionary = {}
var _load: Dictionary = {}
## Game seconds run so far (advance()), the clock for the tap cap.
var tap_clock := 0.0
var _taps := TapLimiter.new(Balance.TAP_CAP, Balance.TAP_WINDOW)
var _autosave_left := Balance.AUTOSAVE_SEC
var _offline_report: Dictionary = {}
## While true, _earn doesn't emit coins_earned (away pay-outs).
var _quiet_earn := false
## Last switch_location() pay-out: {"location", "seconds", "coins"}.
var _away_report: Dictionary = {}
## Deepest site the running lift trip goes to (-1 while the lift waits).
var lift_trip_depth := -1
## Level of a stage right before its last upgrade (for look changes).
var upgraded_from: Dictionary = {}


func _ready() -> void:
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		save_path = profiles.file("game.json")
	reset()
	load_game()


## Profiles switched: load the new player's game.
func switch_profile() -> void:
	save_path = Profiles.file("game.json")
	reset()
	load_game()
	changed.emit()


func _process(delta: float) -> void:
	advance(delta)
	if not autosave_enabled:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = Balance.AUTOSAVE_SEC
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if autosave_enabled and is_inside_tree():
				save_game()


func reset() -> void:
	rifts = {}
	_rift_in = Rifts.EVERY
	coins = 0.0
	total_earned = 0.0
	location = 0
	max_location = 0
	worlds_runs = {}
	world_stars = {}
	exchanged = {}
	story = {}
	party_xp = {}
	relics = []
	relic_shards = 0
	wb = {"l": 0, "dmg": 0.0, "claimed": false}
	saga_done = false
	_relic_tot = {}
	_away_report = {}
	legacy_mult = 1.0
	gear_refund = 0.0
	boost_end = 0.0
	_boosted = false
	managers = {}
	_reset_run()
	_rescale()


func _reset_run(keep_automation: bool = false) -> void:
	var kept := {}
	if keep_automation:
		for k in AUTOMATED:
			kept[k] = managers.get(k, false)
		kept[VAULT] = managers.get(VAULT, false)
	levels = {}
	managers = {}
	for key in stage_keys():
		levels[key] = 0
		managers[key] = kept.get(key, false)
		_timer[key] = -1.0
		_load[key] = 0.0
	managers[VAULT] = kept.get(VAULT, false)
	bosses = {}
	murk = 0.0
	evo = 0
	vault = 0.0
	levels["d0"] = 1
	levels["lift"] = 1
	levels["boat"] = 1
	levels["plant"] = 1
	pit = 0.0
	hold = 0.0
	dock = 0.0
	lift_trip_depth = -1
	rush_meter = 0.0
	rush_left = 0.0
	_offline_report = {}


# --- Queries ------------------------------------------------------------------

## Every stage of the current world has its level, manager and cycle
## entries (a world with more sites than the last one, e.g. a save loading
## into the Jungle after reset()).
func _ensure_keys() -> void:
	for key in stage_keys():
		if not levels.has(key):
			levels[key] = 0
		if not managers.has(key):
			managers[key] = false
		if not _timer.has(key):
			_timer[key] = -1.0
			_load[key] = 0.0


## The current world's stages: its sites (d0..d9, the Jungle d0..d14), the
## lift and the buildings.
func stage_keys() -> Array[String]:
	var keys: Array[String] = []
	for i in site_count():
		keys.append("d%d" % i)
	keys.append("lift")
	keys.append_array(BUILDINGS)
	return keys


const BUILDINGS: Array[String] = ["boat", "plant", "boat2", "plant2"]
## Stages that stand still until their manager is hired (kept through a Dive).
const AUTOMATED: Array[String] = ["lift", "boat", "plant", "boat2", "plant2"]
## Manager key of the vault (the accountant); not a stage. Kept like AUTOMATED.
const VAULT := "vault"


static func is_boat(key: String) -> bool:
	return key == "boat" or key == "boat2"


static func is_plant(key: String) -> bool:
	return key == "plant" or key == "plant2"


## The second boat or plant: bought with coins, not open from the start.
static func is_second(key: String) -> bool:
	return key == "boat2" or key == "plant2"


static func is_lift(key: String) -> bool:
	return key == "lift"


static func depth_index(key: String) -> int:
	return int(key.substr(1)) if key.begins_with("d") else -1


static func stage_data(key: String) -> Dictionary:
	match key:
		"lift":
			return Balance.LIFT
		"boat":
			return Balance.BOAT
		"plant":
			return Balance.PLANT
		"boat2":
			return Balance.BOAT2
		"plant2":
			return Balance.PLANT2
	return Balance.DEPTHS[depth_index(key)]


func get_level(key: String) -> int:
	return levels.get(key, 0)


func has_manager(key: String) -> bool:
	return managers.get(key, false)


## The vault is always there (it has no level).
func is_open(key: String) -> bool:
	return key == VAULT or get_level(key) > 0


## Everything that multiplies every stage: the location's scale, evolution
## forms, room decor, the legacy of old Dives, the x2 boost and artifacts.
func income_mult() -> float:
	return _scale * Balance.evo_mult(evo) * float(bonus.get("decor", 1.0)) * float(bonus.get("skin", 1.0)) * legacy_mult * star_mult() \
			* (2.0 if _boosted else 1.0) * (2.0 if x2_day else 1.0) * float(bonus.get("all", 1.0)) * murk_mult() * (1.0 + relic("all"))


# --- Worlds and locations --------------------------------------------------------

func world_index() -> int:
	return Balance.world_index_of(location)


func world_id() -> String:
	return Balance.WORLDS[world_index()]["id"]


func tier() -> int:
	return Balance.tier_of(location)


## Work sites of the current world (10, the Jungle 15).
func site_count() -> int:
	return Balance.site_count(location)


## Id of site i (0..site_count() - 1) in the current world ("shells", "ash", ...).
func site_id(i: int) -> String:
	var sites: Array = Balance.WORLDS[world_index()]["sites"]
	return sites[clampi(i, 0, sites.size() - 1)]


## Gear level the workers wear now (1..4).
func gear_level() -> int:
	return evo + 1


## Price of gear purchase `form` (1..3 = gear level 2..4) in this location.
func evo_cost(form: int) -> float:
	return Balance.evo_cost(location, form, stars_of(location))


func can_buy_evo() -> bool:
	return evo < Balance.EVO_FORMS and coins >= evo_cost(evo + 1)


## Buys the next gear level: a big income boost for the rest of the location.
func buy_evo() -> bool:
	if not can_buy_evo():
		return false
	coins -= evo_cost(evo + 1)
	evo += 1
	evo_bought.emit(evo)
	changed.emit()
	return true


## Gear levels for a save from before the gear (12 evolution forms): the
## coins it paid for forms buy gear levels in order, the rest comes back
## as coins. Returns [levels bought, coins refunded].
static func gear_from_old_forms(location: int, forms: int) -> Array:
	var spent := Balance.old_evo_spent(location, forms)
	var levels := 0
	while levels < Balance.EVO_FORMS and spent >= Balance.evo_cost(location, levels + 1) * 0.999:
		spent -= Balance.evo_cost(location, levels + 1)
		levels += 1
	return [levels, maxf(0.0, spent)]


## Moves the vault into the wallet; returns how much.
func collect_vault() -> float:
	var amount := vault
	if amount <= 0.0:
		return 0.0
	vault = 0.0
	coins += amount
	vault_changed.emit()
	changed.emit()
	return amount


## The checklist that opens the next location:
## [{"id": "sites"|"foremen"|"managers", "have": int, "need": int}].
func location_goals() -> Array:
	var sites := 0
	var foremen := 0
	for i in site_count():
		var key := "d%d" % i
		if is_open(key):
			sites += 1
			if has_manager(key):
				foremen += 1
	var mgrs := 0
	for k in AUTOMATED:
		if is_open(k) and has_manager(k):
			mgrs += 1
	return [
		{"id": "sites", "have": sites, "need": site_count()},
		{"id": "foremen", "have": foremen, "need": site_count()},
		{"id": "managers", "have": mgrs, "need": AUTOMATED.size()},
	]


func location_ready() -> bool:
	for g in location_goals():
		if g["have"] < g["need"]:
			return false
	return true


func next_location_cost() -> float:
	return Balance.location_cost(location)


## Ready, and the wallet (with the vault) holds the price. Never past the
## last world (the next ones are "coming soon").
func can_advance_location() -> bool:
	return is_max_location() and not is_last_location() and location_ready() and coins + vault >= next_location_cost()


## The last world (the Jungle): there is no next world yet.
func is_last_location() -> bool:
	return location >= Balance.last_location()


## Opens the next location: L + 1 with a fresh run (coins, levels, foremen,
## gear); the lift, boat, plant and vault managers come along. The world
## left behind keeps its run (minus the price) for switch_location().
func advance_location() -> bool:
	if not can_advance_location():
		return false
	collect_vault()
	coins = maxf(0.0, coins - next_location_cost())
	_flush_cycles()
	worlds_runs[str(location)] = _run_snapshot()
	location += 1
	max_location = maxi(max_location, location)
	worlds_runs.erase(str(location))
	_reset_run(true)
	coins = 0.0
	location_changed.emit(location)
	changed.emit()
	save_game()
	return true


# --- Stars (the endgame) ----------------------------------------------------------

func _rescale() -> void:
	var n := stars_of(location)
	_scale = Balance.star_scale(location, n)
	_gate_scale = Balance.star_gate_scale(location, n)


func stars_of(l: int) -> int:
	return maxi(0, int(_num(world_stars.get(str(l)), 0.0)))


func total_stars() -> int:
	var n := 0
	for k in world_stars:
		n += maxi(0, int(_num(world_stars[k], 0.0)))
	return n


## Income multiplier of every world from all the stars owned.
func star_mult() -> float:
	return Balance.star_mult(total_stars())


## Stars open up once the last world is open.
func stars_unlocked() -> bool:
	# In the saga stars are "Nightmare": open once the Ancient One is beaten.
	return max_location >= Balance.last_location() and (saga_done or not Balance.saga)


func star_cost() -> float:
	return Balance.star_cost(location, stars_of(location))


## This world's checklist is done (stars are open): saving up for a star.
func star_ready() -> bool:
	return stars_unlocked() and location_ready() and stars_of(location) < Balance.MAX_STARS


# --- Coin exchange (2026-10-14) -------------------------------------------------------
# An older (smaller) world's wallet can be sent to the world the player is
# in, at the gap between their prices (Moon -> Jungle about 1400 : 1), so a
# rich older world gives a good start in the new one. In all, a world takes
# at most Balance.EXCHANGE_SHARE of its own gate price (the new world still
# has to be played). Exchanged coins are not earnings: the boards don't move.

func _gate_of(l: int) -> float:
	return Balance.star_gate_scale(l, stars_of(l))


func _exchange_key() -> String:
	return "%d:%d" % [location, stars_of(location)]


## How many coins this world can still take from the exchange.
func exchange_room() -> float:
	var cap := Balance.LOCATION_PRICE * _gate_of(location) * Balance.EXCHANGE_SHARE
	return maxf(0.0, cap - _num(exchanged.get(_exchange_key()), 0.0))


## Coins of world `from` per coin arriving here (0 = no exchange that way).
func exchange_rate(from: int) -> float:
	if from == location or from < 0 or from > max_location:
		return 0.0
	var r := _gate_of(location) / _gate_of(from)
	return r if r >= 10.0 else 0.0


## {"give": coins taken from `from`, "get": coins arriving here}.
func exchange_preview(from: int) -> Dictionary:
	var rate := exchange_rate(from)
	if rate <= 0.0:
		return {"give": 0.0, "get": 0.0}
	var amount := minf(world_coins(from) / rate, exchange_room())
	if amount < 1.0:
		return {"give": 0.0, "get": 0.0}
	return {"give": amount * rate, "get": amount}


## Sends world `from`'s coins here. Returns the coins received.
func exchange_from(from: int) -> float:
	var p := exchange_preview(from)
	var amount := float(p["get"])
	if amount <= 0.0:
		return 0.0
	var snap = worlds_runs.get(str(from))
	if not snap is Dictionary:
		return 0.0
	snap["coins"] = maxf(0.0, _num(snap.get("coins"), 0.0) - float(p["give"]))
	worlds_runs[str(from)] = snap
	exchanged[_exchange_key()] = _num(exchanged.get(_exchange_key()), 0.0) + amount
	# Into the wallet directly: not earnings (total_earned and the boards stay).
	coins += amount
	changed.emit()
	save_game()
	return amount


func can_get_star() -> bool:
	return star_ready() and coins + vault >= star_cost()


## Takes a star for this world: pays the price, restarts its run (the lift,
## boats, plants and vault managers stay), bigger numbers from now on, and a
## bonus for every world. Gives pearls.
func get_star() -> bool:
	if not can_get_star():
		return false
	collect_vault()
	var price := star_cost()
	var n := stars_of(location) + 1
	_flush_cycles()
	world_stars[str(location)] = n
	_reset_run(true)
	coins = 0.0
	upgraded_from = {}
	_rescale()
	var progress := get_node_or_null("/root/Progress")
	if progress:
		progress.add_pearls(Balance.star_pearls(n - 1))
	star_gained.emit(location, n)
	location_changed.emit(location)
	changed.emit()
	save_game()
	return price > 0.0


# --- Switching between opened worlds -------------------------------------------------

## The active world is the highest one opened (only there the gate works).
## The leader's gift (Online.check_gift): every world before `upto` fully
## built (all sites, foremen, managers, gear, levels at least `lv`), and
## `upto` opened and played. Levels already higher stay; coins stay.
func gift_worlds(upto: int, lv: int) -> void:
	upto = clampi(upto, 0, Balance.LAST_LOCATION)
	var back := location
	_flush_cycles()
	worlds_runs[str(location)] = _run_snapshot()
	for l in range(0, upto + 1):
		var snap = worlds_runs.get(str(l))
		worlds_runs.erase(str(l))
		location = l
		if snap is Dictionary:
			_apply_run(snap)
		else:
			_fresh_world_run()
		if l < upto:
			for k in stage_keys():
				levels[k] = maxi(int(levels.get(k, 0)), lv)
				managers[k] = true
			managers[VAULT] = true
			evo = Balance.EVO_FORMS
			worlds_runs[str(l)] = _run_snapshot()
	if back > upto:
		worlds_runs[str(upto)] = _run_snapshot()
		var mine = worlds_runs.get(str(back))
		worlds_runs.erase(str(back))
		location = back
		if mine is Dictionary:
			_apply_run(mine)
	max_location = maxi(max_location, upto)
	upgraded_from = {}
	location_changed.emit(location)
	changed.emit()
	save_game()


func is_max_location() -> bool:
	return location >= max_location


func is_opened(l: int) -> bool:
	return l >= 0 and l <= max_location


func can_switch_location(l: int) -> bool:
	return is_opened(l) and l != location


## Goes to another opened world: this run is put aside (a snapshot), the
## target's run comes back and pays what its automation made while it
## waited, with the offline rules: only automated parts work, at most
## Balance.OFFLINE_CAP_SEC, no x2 boost (the boost ran for the world being
## played) and no rush. A switch back and forth pays at most the seconds
## that really passed, so it never beats staying.
func switch_location(l: int) -> bool:
	if not can_switch_location(l):
		return false
	_flush_cycles()
	worlds_runs[str(location)] = _run_snapshot()
	var snap = worlds_runs.get(str(l))
	worlds_runs.erase(str(l))
	location = l
	if snap is Dictionary:
		_apply_run(snap)
	else:
		_fresh_world_run()
	# Progress swaps the quests and the skin bonus on this signal, so the
	# pay-out below already counts for this world.
	location_changed.emit(location)
	var away := 0.0
	var secs := 0.0
	if snap is Dictionary:
		secs = clampf(now() - _num(snap.get("left_at"), now()), 0.0, Balance.OFFLINE_CAP_SEC)
		away = _pay_away(secs)
	_away_report = {"location": l, "seconds": secs, "coins": away}
	location_switched.emit(l, away)
	changed.emit()
	save_game()
	return true


## What the last switch paid ({"location", "seconds", "coins"}); given once.
func take_away_report() -> Dictionary:
	var r := _away_report
	_away_report = {}
	return r


## Seconds the world has been waiting (0 for the active one or none).
func away_seconds(l: int) -> float:
	var snap = worlds_runs.get(str(l))
	if l == location or not snap is Dictionary:
		return 0.0
	return clampf(now() - _num(snap.get("left_at"), now()), 0.0, Balance.OFFLINE_CAP_SEC)


## Coins waiting in an opened world (its wallet; the active one: coins).
func world_coins(l: int) -> float:
	if l == location:
		return coins
	var snap = worlds_runs.get(str(l))
	return maxf(0.0, _num(snap.get("coins"), 0.0)) if snap is Dictionary else 0.0


## Less than a second away pays nothing (a quick back-and-forth is free of
## any rounding gain).
const AWAY_MIN_SEC := 1.0


func _pay_away(seconds: float) -> float:
	if seconds < AWAY_MIN_SEC:
		return 0.0
	_boosted = false
	x2_day = false
	# Like the offline pay at start-up, it doesn't count for "earn" quests.
	_quiet_earn = true
	var earned := simulate_offline(seconds)
	_quiet_earn = false
	_boosted = boost_end > now()
	return earned


## Cycles in flight give their load back to where it came from (the
## crates, the raft, the shore), so nothing is lost or made twice.
func _flush_cycles() -> void:
	for key in stage_keys():
		var amount: float = _load.get(key, 0.0)
		if float(_timer.get(key, -1.0)) >= 0.0 and amount > 0.0:
			if key == "lift":
				pit += amount
			elif is_boat(key):
				hold += amount
			elif is_plant(key):
				dock += amount
		_timer[key] = -1.0
		_load[key] = 0.0
	lift_trip_depth = -1


## The run of the active world, for worlds_runs and the save.
func _run_snapshot() -> Dictionary:
	return {
		"coins": coins, "vault": vault, "gear": evo,
		"levels": levels.duplicate(), "managers": managers.duplicate(),
		"pit": pit, "hold": hold, "dock": dock, "left_at": now(), "bosses": bosses.duplicate(),
	}


## Puts a snapshot back as the active run (values checked like a save).
func _apply_run(d: Dictionary) -> void:
	_reset_run(false)
	coins = maxf(0.0, _num(d.get("coins"), 0.0))
	vault = maxf(0.0, _num(d.get("vault"), 0.0))
	evo = clampi(int(_num(d.get("gear"), 0.0)), 0, Balance.EVO_FORMS)
	var lv = d.get("levels", {})
	var mg = d.get("managers", {})
	_apply_levels(lv if lv is Dictionary else {}, mg if mg is Dictionary else {})
	pit = maxf(0.0, _num(d.get("pit"), 0.0))
	hold = maxf(0.0, _num(d.get("hold"), 0.0))
	dock = maxf(0.0, _num(d.get("dock"), 0.0))
	_read_bosses(d.get("bosses"))
	if has_manager(VAULT) and vault > 0.0:
		coins += vault
		vault = 0.0
	upgraded_from = {}


## A world opened before per-world runs existed (an old save): the player
## finished it once, so it starts like a newly opened world, from scratch
## but with the lift, boat, plant and vault managers already hired (they
## earned those there; the gate needed them). Its gate goals don't matter:
## the gate is only on the highest world.
func _fresh_world_run() -> void:
	_reset_run(false)
	coins = 0.0
	for k in AUTOMATED:
		managers[k] = true
	managers[VAULT] = true
	upgraded_from = {}


## Levels and managers from a save or a snapshot, cleaned up.
func _apply_levels(saved_levels: Dictionary, saved_managers: Dictionary) -> void:
	managers[VAULT] = saved_managers.get(VAULT) == true
	for key in stage_keys():
		var minimum := 0 if depth_index(key) > 0 or is_second(key) else 1
		levels[key] = maxi(minimum, int(_num(saved_levels.get(key), minimum)))
		# Automation stays hired while its building is closed (the second
		# boat and plant reopen in every location).
		managers[key] = saved_managers.get(key) == true and (is_open(key) or key in AUTOMATED)
	# A deeper site can't be open while a shallower one is closed.
	var closed := false
	for key in stage_keys():
		if depth_index(key) < 0:
			continue
		if closed:
			levels[key] = 0
			managers[key] = false
		elif levels[key] == 0:
			closed = true


## Real time (Unix seconds); the boost runs on it.
func now() -> float:
	return Clock.now()


## Can a watched ad add its full 30 minutes without passing the cap?
func can_ad_boost() -> bool:
	if Profiles.league_game():
		return false
	return boost_left <= AD_BOOST_CAP_SEC - AD_BOOST_SEC + 1.0


## Reward for a rewarded ad watched to the end: +30 min of x2, at most 4 h
## in total. False (nothing given) when the boost is already near the cap.
func add_ad_boost() -> bool:
	if not can_ad_boost():
		return false
	boost_end = maxf(now(), boost_end) + AD_BOOST_SEC
	boost_end = minf(boost_end, now() + AD_BOOST_CAP_SEC)
	_boosted = true
	changed.emit()
	return true


## Does this stage start its next cycle by itself?
func is_auto(key: String) -> bool:
	return depth_index(key) >= 0 or has_manager(key)


## Coins per second this stage can handle.
func rate(key: String) -> float:
	# Artifact bonuses for the boat or the plant count for both of them.
	var group := "boat" if is_boat(key) else ("plant" if is_plant(key) else key)
	var r := Balance.output(stage_data(key)["value"], get_level(key)) * income_mult() * float(bonus.get(group, 1.0))
	if depth_index(key) >= 0:
		r *= float(bonus.get("dives", 1.0))
		if has_manager(key):
			r *= Balance.FOREMAN_MULT
	if Balance.saga:
		var i := depth_index(key)
		if i >= 0:
			r *= 1.0 + relic("site", i)
		elif key != VAULT:
			r *= 1.0 + relic("chain")
		if has_tides():
			r *= Tides.mult(now(), "dives" if i >= 0 else group)
		if i >= 0 and not _calm and rifts.has(key):
			r *= Rifts.STEAL
	return r


## Atlantis' tides are on (the saga's act II world, not while away).
func has_tides() -> bool:
	return Balance.saga and not _calm and world_id() == Tides.WORLD


## R'lyeh's rifts can open (the saga's act III world, live play only).
func has_rifts() -> bool:
	return Balance.saga and not _calm and world_id() == Rifts.WORLD


## Live play in R'lyeh: counts down to the next rift and opens it in a
## random working mine without one.
func _tick_rifts(seconds: float) -> void:
	if not has_rifts():
		if not rifts.is_empty() and not _calm:
			rifts = {}
		return
	_rift_in -= seconds
	if _rift_in > 0.0:
		return
	_rift_in = Rifts.EVERY
	var free := []
	for i in site_count():
		var k := "d%d" % i
		if is_open(k) and not rifts.has(k):
			free.append(k)
	if not free.is_empty():
		rifts[free[randi() % free.size()]] = Rifts.TAPS
		changed.emit()


func dives_rate() -> float:
	var total := 0.0
	for i in site_count():
		total += rate("d%d" % i)
	return total


## Both boats together (a closed one adds nothing).
func boats_rate() -> float:
	return rate("boat") + rate("boat2")


func plants_rate() -> float:
	return rate("plant") + rate("plant2")


func lift_rate() -> float:
	return rate("lift")


## Coins per second with every stage automated: the weakest link.
func income_rate() -> float:
	return minf(minf(dives_rate(), lift_rate()), minf(boats_rate(), plants_rate()))


## Which group limits income: "dives", "lift", "boat" (both boats) or "plant".
func bottleneck() -> String:
	var d := dives_rate()
	var l := lift_rate()
	var b := boats_rate()
	var p := plants_rate()
	if d <= l and d <= b and d <= p:
		return "dives"
	if l <= b and l <= p:
		return "lift"
	return "boat" if b <= p else "plant"


## Index of the deepest open dive site.
func deepest_open() -> int:
	var deepest := 0
	for i in site_count():
		if levels.get("d%d" % i, 0) > 0:
			deepest = i
	return deepest


func cycle_time(key: String) -> float:
	if key == "lift":
		# Deeper shafts make longer trips (each trip carries more). A trip
		# keeps the depth it started with, so opening a depth never jumps it.
		var deep := lift_trip_depth if lift_trip_depth >= 0 else deepest_open()
		return Balance.lift_trip(get_level("lift"), deep)
	return stage_data(key)["cycle"]


## Amount one full cycle moves.
func cycle_capacity(key: String) -> float:
	return rate(key) * cycle_time(key)


## 0..1 progress of the running cycle, or -1 when idle.
func cycle_progress(key: String) -> float:
	var t: float = _timer.get(key, -1.0)
	return -1.0 if t < 0.0 else clampf(t / cycle_time(key), 0.0, 1.0)


func cycle_load(key: String) -> float:
	return _load.get(key, 0.0)


## Level prices follow the location's scale.
func upgrade_cost(key: String, count: int = 1) -> float:
	var data := stage_data(key)
	return Balance.bulk_cost(data["cost0"], get_level(key), count, Balance.growth_of(data)) * _scale


func max_affordable(key: String) -> int:
	var data := stage_data(key)
	var n := Balance.affordable_levels(data["cost0"], get_level(key), coins / _scale, Balance.growth_of(data))
	# The scale can round either way: settle on what upgrade() accepts.
	while upgrade_cost(key, n + 1) <= coins:
		n += 1
	while n > 0 and upgrade_cost(key, n) > coins:
		n -= 1
	return n


## Sites cost the gate scale to open (they are part of the location goal),
## the second boat and plant the plain scale.
func unlock_cost(key: String) -> float:
	if key == VAULT:
		return 0.0
	return float(stage_data(key).get("unlock", 0.0)) * (_gate_scale if depth_index(key) >= 0 else _scale)


func manager_cost(key: String) -> float:
	if key == VAULT:
		return float(Balance.VAULT["manager"]) * _scale
	return float(stage_data(key)["manager"]) * (_gate_scale if depth_index(key) >= 0 else _scale)


## The next closed dive site, or "" when all are open.
func next_depth() -> String:
	for key in stage_keys():
		if depth_index(key) >= 0 and not is_open(key):
			return key
	return ""


func divers(key: String) -> int:
	return Balance.divers_at(get_level(key))


# Old Dive Deeper names, mapped onto the location gate until the UI moves
# to the new API.

func prestige_cost() -> float:
	return next_location_cost()


## Ladder id of the first closed site (the last one when all are open).
func prestige_gate_depth() -> String:
	var next := next_depth()
	return Balance.DEPTHS[depth_index(next) if next != "" else site_count() - 1]["id"]


func prestige_gate_open() -> bool:
	return location_ready()


func can_prestige() -> bool:
	return can_advance_location()


func is_rushing() -> bool:
	return rush_left > 0.0


## Report of coins earned while away. Given out once.
func take_offline_report() -> Dictionary:
	var report := _offline_report
	_offline_report = {}
	return report


# --- Actions ------------------------------------------------------------------

func upgrade(key: String, count: int = 1) -> bool:
	if not is_open(key) or count <= 0:
		return false
	var cost := upgrade_cost(key, count)
	if coins < cost:
		return false
	coins -= cost
	upgraded_from[key] = get_level(key)
	var before := Balance.milestones(get_level(key))
	# A faster lift: the running trip keeps its progress (no jump).
	var progress := cycle_progress(key)
	levels[key] = get_level(key) + count
	if progress >= 0.0:
		_timer[key] = progress * cycle_time(key)
	if Balance.milestones(levels[key]) > before:
		milestone_reached.emit(key, levels[key])
	upgraded.emit(key, count)
	changed.emit()
	return true


## Buys the second boat or plant (level 1).
func open_building(key: String) -> bool:
	if not is_second(key) or is_open(key) or coins < unlock_cost(key):
		return false
	coins -= unlock_cost(key)
	levels[key] = 1
	depth_opened.emit(key)
	changed.emit()
	return true


func open_depth(key: String) -> bool:
	if key != next_depth() or coins < unlock_cost(key) or boss_at(key) != "":
		return false
	coins -= unlock_cost(key)
	levels[key] = 1
	depth_opened.emit(key)
	changed.emit()
	return true


# --- Mine bosses (MineBoss, the saga's worlds) ----------------------------------------

## The boss still guarding site `key` ("" = none, or beaten).
func boss_at(key: String) -> String:
	var i := depth_index(key)
	if i < 0 or bosses.has(key):
		return ""
	return MineBoss.guard(world_id(), i)


## The guard's health in coins: a share of the site's unlock price.
func boss_hp(key: String) -> float:
	var id := MineBoss.guard(world_id(), depth_index(key))
	return unlock_cost(key) * float(MineBoss.data(id)["hp"]) if id != "" else 0.0


## Damage of a hit (`perfect`: twice): seconds of the game's income, at
## least a small share of the boss's health.
func boss_hit(key: String, perfect: bool = false) -> float:
	var hit := maxf(income_rate() * MineBoss.HIT_SEC, boss_hp(key) * MineBoss.MIN_HIT)
	return hit * (MineBoss.PERFECT_MULT if perfect else 1.0) * (1.0 + relic("boss"))


## The guard of `key` is beaten: the site can be opened. Pays its pearls
## and some seconds of income. Returns {"boss", "pearls", "coins"} ({} when
## there was no guard).
func defeat_boss(key: String) -> Dictionary:
	var id := boss_at(key)
	if id == "":
		return {}
	bosses[key] = true
	murk = 0.0
	murk_cleansed.emit()
	var d := MineBoss.data(id)
	var c := income_rate() * float(d["coins_sec"])
	if c > 0.0:
		_earn(c)
	# Nightmare (saga stars): every star makes the guards pay half again.
	var pearls := int(d["pearls"])
	if Balance.saga:
		pearls = roundi(pearls * (1.0 + 0.5 * stars_of(location)))
	var pr := get_node_or_null("/root/Progress")
	if pr:
		pr.add_pearls(pearls)
	if id == "ancient_one":
		# The saga's finale: Nightmare opens, the trophy goes to the player's
		# online card (every profile, the usual game too).
		saga_done = true
		var on := get_node_or_null("/root/Online")
		if on:
			on.add_sleeper()
	# A relic drops (kept, or melted into shards when the bag is full).
	var rel := {}
	if Balance.saga:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rel = Relics.drop(rng, id, site_count())
		if stars_of(location) > 0 and int(rel["rarity"]) < 3:
			# Nightmare guards drop one rarity higher.
			rel["rarity"] = int(rel["rarity"]) + 1
			rel["affixes"] = Relics.roll_affixes(rng, int(rel["rarity"]), site_count())
		if not add_relic(rel):
			relic_shards += Relics.SALVAGE[int(rel["rarity"])]
			rel["melted"] = true
			rel["shards"] = Relics.SALVAGE[int(rel["rarity"])]
	boss_defeated.emit(key, id)
	changed.emit()
	return {"boss": id, "pearls": pearls, "coins": c, "relic": rel}


## Income factor of the Murk (1 outside the saga).
func murk_mult() -> float:
	return Murk.factor(murk) if Balance.saga else 1.0


func _grow_murk(seconds: float) -> void:
	if Balance.saga:
		var fast := Rifts.MURK_MULT if not rifts.is_empty() and has_rifts() else 1.0
		murk = minf(1.0, murk + Murk.rise(seconds, bosses.size()) * (1.0 - relic("murk")) * fast)


## Ids of the guards beaten in this world's run.
func beaten_bosses() -> Array:
	var out := []
	for k in bosses:
		var id := MineBoss.guard(world_id(), depth_index(str(k)))
		if id != "":
			out.append(id)
	return out


## Guards beaten so far in the saga: this run's, and every guard of the
## acts before (an act opens only after its last guard).
func saga_beaten() -> Array:
	var out := beaten_bosses()
	if Balance.saga:
		for l in range(0, location):
			for b in MineBoss.GUARDS.get(str(Balance.world_of(l)["id"]), {}).values():
				out.append(str(b))
	return out


## The party for a fight: [{"c", "lv", "xp"}] (Party.members, in order).
func party() -> Array:
	var out := []
	for c in Party.members(saga_beaten()):
		var xp := int(party_xp.get(c, 0))
		out.append({"c": c, "lv": Party.level_of(xp), "xp": xp})
	return out


## Experience after a fight for everyone in the party. Returns the level
## ups: [[class, old level, new level], ...].
func add_party_xp(won: bool) -> Array:
	var ups := []
	for m in party():
		var c: String = m["c"]
		var xp := int(m["xp"]) + roundi((Party.XP_WIN if won else Party.XP_LOSS) * (1.0 + relic("xp")))
		party_xp[c] = xp
		var lv := Party.level_of(xp)
		if lv > int(m["lv"]):
			ups.append([c, int(m["lv"]), lv])
	changed.emit()
	return ups


# --- Relics (the saga's loot) ------------------------------------------------------------

## The worn relics' total of `stat` (site: for site index `site`).
func relic(stat: String, site: int = -1) -> float:
	if relics.is_empty():
		return 0.0
	if _relic_tot.is_empty():
		_relic_tot = {"_": true}
		var worn := worn_relics()
		for st in Relics.STATS:
			if st != "site":
				_relic_tot[st] = Relics.total(worn, st)
		for i in Balance.DEPTHS.size():
			_relic_tot["site%d" % i] = Relics.total(worn, "site", i)
	return float(_relic_tot.get("site%d" % site if stat == "site" else stat, 0.0))


func worn_relics(hero: String = "") -> Array:
	return relics.filter(func(r): return str(r.get("hero", "")) != "" and (hero == "" or str(r["hero"]) == hero))


func bag_relics() -> Array:
	return relics.filter(func(r): return str(r.get("hero", "")) == "")


## Keeps a new relic in the bag (false: the bag is full).
func add_relic(rel: Dictionary) -> bool:
	if rel.is_empty() or bag_relics().size() >= Relics.BAG:
		return false
	rel["hero"] = ""
	relics.append(rel)
	_relics_changed()
	return true


## Puts relic `i` on `hero` (its first free slot; false when full or not in
## the party).
func wear_relic(i: int, hero: String) -> bool:
	if i < 0 or i >= relics.size() or not hero in Party.members(saga_beaten()):
		return false
	if str(relics[i].get("hero", "")) == hero:
		return true
	if worn_relics(hero).size() >= Relics.SLOTS:
		return false
	relics[i]["hero"] = hero
	_relics_changed()
	return true


func take_off_relic(i: int) -> bool:
	if i < 0 or i >= relics.size() or str(relics[i].get("hero", "")) == "":
		return false
	if bag_relics().size() >= Relics.BAG:
		return false
	relics[i]["hero"] = ""
	_relics_changed()
	return true


## Melts relic `i` into shards. Returns the shards (0: nothing done).
func salvage_relic(i: int) -> int:
	if i < 0 or i >= relics.size():
		return 0
	var n: int = Relics.SALVAGE[int(relics[i]["rarity"])]
	relics.remove_at(i)
	relic_shards += n
	_relics_changed()
	return n


## Rolls relic `i`'s properties again for shards.
func reroll_relic(i: int) -> bool:
	if i < 0 or i >= relics.size():
		return false
	var cost: int = Relics.REROLL[int(relics[i]["rarity"])]
	if relic_shards < cost:
		return false
	relic_shards -= cost
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	relics[i]["affixes"] = Relics.roll_affixes(rng, int(relics[i]["rarity"]), site_count())
	_relics_changed()
	return true


## A world boss fight gave `units` taps of damage in league `league`.
## Returns my total for that league.
func wb_add(units: float, league: int) -> float:
	if int(wb["l"]) != league:
		wb = {"l": league, "dmg": 0.0, "claimed": false}
	wb["dmg"] = float(wb["dmg"]) + clampf(units, 0.0, WorldBoss.CAP)
	changed.emit()
	save_game()
	return float(wb["dmg"])


## The league beat the world boss (`total` >= WorldBoss.HP) and I took part:
## pearls and a legendary relic, once. Returns {"pearls", "relic"} or {}.
func wb_claim(total: float, league: int) -> Dictionary:
	if int(wb["l"]) != league or float(wb["dmg"]) <= 0.0 or wb["claimed"] or total < WorldBoss.HP:
		return {}
	wb["claimed"] = true
	var pr := get_node_or_null("/root/Progress")
	if pr:
		pr.add_pearls(WorldBoss.PEARLS)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rel := Relics.roll(rng, 3, site_count(), Relics.KINDS.slice(10))
	if not add_relic(rel):
		relic_shards += Relics.SALVAGE[3]
		rel["melted"] = true
		rel["shards"] = Relics.SALVAGE[3]
	save_game()
	return {"pearls": WorldBoss.PEARLS, "relic": rel}


func _relics_changed() -> void:
	_relic_tot = {}
	changed.emit()
	save_game()


func _read_relics(v, shards) -> void:
	relics = []
	_relic_tot = {}
	relic_shards = clampi(int(_num(shards, 0.0)), 0, 1000000)
	if not v is Array:
		return
	var per := {}
	for x in v:
		var r := Relics.clean(x)
		if r.is_empty() or relics.size() >= Relics.BAG + Relics.SLOTS * Party.CLASSES.size():
			continue
		var h := str(x.get("hero", "")) if x is Dictionary else ""
		if not Party.CLASSES.has(h) or int(per.get(h, 0)) >= Relics.SLOTS:
			h = ""
		per[h] = int(per.get(h, 0)) + 1
		r["hero"] = h
		relics.append(r)


func _read_bosses(v) -> void:
	bosses = {}
	if v is Dictionary:
		for k in v:
			if depth_index(str(k)) >= 0 and v[k] == true:
				bosses[str(k)] = true


func hire_manager(key: String) -> bool:
	if not is_open(key) or has_manager(key) or coins < manager_cost(key):
		return false
	coins -= manager_cost(key)
	managers[key] = true
	manager_hired.emit(key)
	if key == VAULT:
		collect_vault()
	changed.emit()
	return true


## Rewards from quests, chests, puzzles and gifts.
func add_coins(amount: float) -> void:
	if amount > 0.0 and is_finite(amount):
		_earn(amount)
		changed.emit()


func add_boost(seconds: float) -> void:
	boost_left = minf(BOOST_CAP_SEC, boost_left + maxf(0.0, seconds))
	changed.emit()


## Player tapped a stage: starts the cycle if idle, otherwise pushes the
## running one forward a little. Also fills the rush meter.
## Returns true when something happened. Taps over Balance.TAP_CAP per
## second on one target do nothing (returns false).
func tap(key: String) -> bool:
	if not is_open(key):
		return false
	if not _taps.allow(key, tap_clock):
		return false
	if _taps.allow("rush", tap_clock):
		_add_rush()
	if Balance.saga:
		murk = maxf(0.0, murk - Murk.TAP_CLEAR * (1.0 + relic("tap")))
		if rifts.has(key):
			# Each tap pushes the tentacles back; the last one closes the rift.
			rifts[key] = int(rifts[key]) - 1
			if int(rifts[key]) <= 0:
				rifts.erase(key)
				changed.emit()
	tapped.emit(key)
	if _timer[key] >= 0.0:
		_timer[key] += Balance.TAP_BOOST * float(bonus.get("tap", 1.0)) * (1.0 + relic("tap")) * cycle_time(key)
		return true
	return _start_cycle(key)


## Old name of advance_location().
func prestige() -> bool:
	return advance_location()


## Runs the economy forward. Live play uses cycles; `seconds` may be large.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	tap_clock += seconds
	_grow_murk(seconds)
	if seconds < 5.0:
		_tick_rifts(seconds)
	rush_meter = maxf(0.0, rush_meter - RUSH_DECAY * seconds)
	var speed := RUSH_SPEED if rush_left > 0.0 else 1.0
	rush_left = maxf(0.0, rush_left - seconds)
	_boosted = boost_end > now()
	x2_day = x2_force or (x2_days_on and seconds < 2.0 and OnlineRules.is_x2_day(now()))
	for key in stage_keys():
		if not is_open(key):
			continue
		if _timer[key] < 0.0 and is_auto(key):
			_start_cycle(key)
		if _timer[key] < 0.0:
			continue
		_timer[key] += seconds * speed
		while _timer[key] >= cycle_time(key):
			var leftover: float = _timer[key] - cycle_time(key)
			_finish_cycle(key)
			if not is_auto(key) or not _start_cycle(key):
				break
			_timer[key] = leftover


func _start_cycle(key: String) -> bool:
	var amount := cycle_capacity(key)
	if key == "lift":
		amount = minf(pit, amount)
		if amount <= 0.0:
			return false
		pit -= amount
		lift_trip_depth = deepest_open()
	elif is_boat(key):
		amount = minf(hold, amount)
		if amount <= 0.0:
			return false
		hold -= amount
	elif is_plant(key):
		amount = minf(dock, amount)
		if amount <= 0.0:
			return false
		dock -= amount
	_timer[key] = 0.0
	_load[key] = amount
	cycle_started.emit(key, amount)
	return true


func _finish_cycle(key: String) -> void:
	var amount: float = _load[key]
	_timer[key] = -1.0
	_load[key] = 0.0
	if key == "lift":
		hold += amount
		lift_trip_depth = -1
	elif is_boat(key):
		dock += amount
	elif is_plant(key):
		_earn(amount, true)
	else:
		pit += amount
	cycle_finished.emit(key, amount)


## Counts earned coins (quests, stats). Plant output (`to_vault`) waits in
## the vault until collected unless the accountant is hired; rewards and
## offline earnings go straight to the wallet.
func _earn(amount: float, to_vault: bool = false) -> void:
	total_earned += amount
	if to_vault and vault_on and not has_manager(VAULT):
		vault += amount
		vault_changed.emit()
	else:
		coins += amount
	if not _quiet_earn:
		coins_earned.emit(amount)


func _add_rush() -> void:
	if rush_left > 0.0:
		return
	rush_meter += RUSH_PER_TAP
	if rush_meter >= 1.0:
		rush_meter = 0.0
		rush_left = RUSH_SEC
		rush_started.emit()


## Time away: divers and automated stages keep working. Uses smooth flows
## instead of cycles so 8 hours cost a few thousand cheap steps.
func simulate_offline(seconds: float) -> float:
	var earned := 0.0
	_calm = true
	var dives := dives_rate()
	var lift := lift_rate() if has_manager("lift") else 0.0
	var boat := 0.0
	var plant := 0.0
	for k in BUILDINGS:
		if has_manager(k):
			if is_boat(k):
				boat += rate(k)
			else:
				plant += rate(k)
	_calm = false
	var left := seconds
	while left > 0.0:
		var dt := minf(OFFLINE_STEP, left)
		left -= dt
		pit += dives * dt
		var lifted := minf(pit, lift * dt)
		pit -= lifted
		hold += lifted
		var moved := minf(hold, boat * dt)
		hold -= moved
		dock += moved
		var made := minf(dock, plant * dt)
		dock -= made
		earned += made
		# Once nothing flows the rest of the time adds nothing but ore piles.
		if dives == 0.0 and lifted == 0.0 and moved == 0.0 and made == 0.0:
			break
	if earned > 0.0:
		_earn(earned)
	_grow_murk(seconds)
	return earned


# --- Save ---------------------------------------------------------------------

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Clock.now(),
		"coins": coins,
		"total_earned": total_earned,
		"location": location,
		"max_location": max_location,
		"worlds_runs": worlds_runs,
		"stars": world_stars,
		"exchanged": exchanged,
		"bosses": bosses,
		"murk": murk,
		"story": story,
		"party_xp": party_xp,
		"relics": relics,
		"relic_shards": relic_shards,
		"wb": wb,
		"saga_done": saga_done,
		"gear": evo,
		"vault": vault,
		"vault_on": vault_on,
		"legacy_mult": legacy_mult,
		"levels": levels,
		"managers": managers,
		"pit": pit,
		"hold": hold,
		"dock": dock,
		"boost_end": boost_end,
		# Older builds read this one.
		"boost_left": boost_left,
	}
	# Write to a temp file and swap, so a crash mid-write can't corrupt the save.
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_warning("Save rename failed: %s" % error_string(err))
		return false
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var json := JSON.new()
	var data = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not data is Dictionary:
		push_warning("Save file is corrupted, starting fresh")
		return false
	_apply_save(data)
	var t_now := now()
	var saved_at := _num(data.get("saved_at"), t_now)
	var away := clampf(t_now - saved_at, 0.0, Balance.OFFLINE_CAP_SEC)
	# The x2 boost counts only for the part of the time away it lasted.
	var boosted := clampf(boost_end - (t_now - away), 0.0, away)
	_boosted = true
	var earned := simulate_offline(boosted)
	_boosted = false
	earned += simulate_offline(away - boosted)
	_boosted = boost_end > t_now
	if earned > 0.0 and float(bonus.get("offline", 1.0)) > 1.0:
		var extra := earned * (float(bonus["offline"]) - 1.0)
		_earn(extra)
		earned += extra
	if away >= Balance.OFFLINE_MIN_REPORT_SEC and earned >= 1.0:
		_offline_report = {"seconds": away, "coins": earned}
	changed.emit()
	return true


func reset_progress() -> void:
	reset()
	save_game()
	changed.emit()


## Debug: +coins equal to 10 minutes of current income (at least 1000).
func debug_grant() -> void:
	_earn(maxf(1000.0, income_rate() * 600.0))
	changed.emit()


func _apply_save(data: Dictionary) -> void:
	reset()
	coins = maxf(0.0, _num(data.get("coins"), 0.0))
	total_earned = maxf(coins, _num(data.get("total_earned"), 0.0))
	var version := int(_num(data.get("version"), 0.0))
	var saved_levels = data.get("levels", {})
	var saved_managers = data.get("managers", {})
	if not saved_managers is Dictionary:
		saved_managers = {}
	if version < 3 and saved_levels is Dictionary:
		var folded := _fold_old_depths(saved_levels, saved_managers)
		saved_levels = folded[0]
		saved_managers = folded[1]
	if version < 4:
		# Before the worlds: everything moves into location 0 (the ocean) and
		# the Dive count becomes a permanent income multiplier.
		var dives := clampi(int(_num(data.get("prestige_count"), 0.0)), 0, 200)
		legacy_mult = Balance.prestige_mult(dives)
		location = 0
		if saved_levels is Dictionary:
			var folded := _fold_v3_sites(saved_levels, saved_managers)
			saved_levels = folded[0]
			saved_managers = folded[1]
	else:
		# Saves from the old repeats (Ocean ★2 and on) stay on the Moon (the
		# last world before version 5), with their levels, coins and helpers.
		location = clampi(int(_num(data.get("location"), 0.0)), 0, Balance.LAST_LOCATION if version >= 5 else 3)
		legacy_mult = maxf(1.0, _num(data.get("legacy_mult"), 1.0))
		if data.has("gear"):
			evo = clampi(int(_num(data.get("gear"), 0.0)), 0, Balance.EVO_FORMS)
		else:
			# 3.0 saves had 12 evolution forms: their coins buy gear levels.
			var old_forms := clampi(int(_num(data.get("evo"), 0.0)), 0, Balance.OLD_EVO_PRICES.size())
			var g := gear_from_old_forms(location, old_forms)
			evo = g[0]
			coins += g[1]
			gear_refund = g[1]
		vault = maxf(0.0, _num(data.get("vault"), 0.0))
	vault_on = data.get("vault_on", true) != false
	# Saves from before the lift: it gets set up below, after the rest.
	var old_save: bool = saved_levels is Dictionary and not saved_levels.has("lift")
	if saved_levels is Dictionary:
		_apply_levels(saved_levels, saved_managers)
	else:
		managers[VAULT] = saved_managers.get(VAULT) == true
	pit = maxf(0.0, _num(data.get("pit"), 0.0))
	hold = maxf(0.0, _num(data.get("hold"), 0.0))
	dock = maxf(0.0, _num(data.get("dock"), 0.0))
	var saved_at := _num(data.get("saved_at"), now())
	if data.has("boost_end"):
		boost_end = _num(data.get("boost_end"), 0.0)
	else:
		# Saves from before the real-time boost kept the seconds left.
		boost_end = saved_at + clampf(_num(data.get("boost_left"), 0.0), 0.0, BOOST_CAP_SEC)
	# A clock moved back must not stretch the boost past its cap.
	boost_end = clampf(boost_end, 0.0, maxf(saved_at, now()) + BOOST_CAP_SEC)
	_boosted = boost_end > now()
	if old_save:
		_migrate_lift()
	if has_manager(VAULT) and vault > 0.0:
		coins += vault
		vault = 0.0
	_load_worlds(data, version)


## max_location and the other worlds' runs. Saves from before the switch
## have neither: the worlds below the current one count as opened (with no
## run yet, see _fresh_world_run).
func _load_worlds(data: Dictionary, version: int) -> void:
	max_location = location
	worlds_runs = {}
	if version < 4:
		return
	max_location = maxi(location, mini(int(_num(data.get("max_location"), float(location))), Balance.LAST_LOCATION if version >= 5 else 3))
	var st = data.get("stars")
	if st is Dictionary:
		for k in st:
			var sl: int = str(k).to_int() if str(k).is_valid_int() else -1
			var sn := int(_num(st[k], 0.0))
			if sl >= 0 and sl <= Balance.LAST_LOCATION and sn > 0:
				world_stars[str(sl)] = mini(sn, Balance.MAX_STARS)
	var ex = data.get("exchanged")
	if ex is Dictionary:
		for k in ex:
			var v := _num(ex[k], 0.0)
			if v > 0.0 and str(k).length() <= 12:
				exchanged[str(k)] = v
	_read_bosses(data.get("bosses"))
	murk = clampf(_num(data.get("murk"), 0.0), 0.0, 1.0)
	var sto = data.get("story")
	if sto is Dictionary:
		for k in sto:
			if str(k).length() <= 24 and sto[k] == true and story.size() < 64:
				story[str(k)] = true
	var px = data.get("party_xp")
	if px is Dictionary:
		for k in px:
			if Party.CLASSES.has(str(k)):
				party_xp[str(k)] = clampi(int(_num(px[k], 0.0)), 0, 10000000)
	_read_relics(data.get("relics"), data.get("relic_shards"))
	saga_done = data.get("saga_done") == true
	var w = data.get("wb")
	wb = {"l": 0, "dmg": 0.0, "claimed": false}
	if w is Dictionary:
		wb = {"l": int(_num(w.get("l"), 0.0)), "dmg": clampf(_num(w.get("dmg"), 0.0), 0.0, 1e7), "claimed": w.get("claimed") == true}
	_rescale()
	var runs = data.get("worlds_runs")
	if not runs is Dictionary:
		return
	for k in runs:
		var l: int = str(k).to_int() if str(k).is_valid_int() else -1
		if l >= 0 and l <= max_location and l != location and runs[k] is Dictionary:
			worlds_runs[str(l)] = runs[k]


## Levels and managers of a 30-site save mapped onto the 15 sites: d0..d6
## stay, the deeper ones take the best level of their OLD_DEPTH_FOLD group
## (a foreman if any had one). Never lowers what the player had reached.
static func _fold_old_depths(old_levels: Dictionary, old_managers: Dictionary) -> Array:
	var lv := old_levels.duplicate()
	var mg := old_managers.duplicate()
	for i in OLD_DEPTH_FOLD.size():
		var key := "d%d" % (7 + i)
		var best := 0
		var hired := false
		for k: int in OLD_DEPTH_FOLD[i]:
			var old_key := "d%d" % k
			best = maxi(best, int(_num(old_levels.get(old_key), 0.0)))
			hired = hired or old_managers.get(old_key) == true
		lv[key] = best
		mg[key] = hired
	for k in range(7 + OLD_DEPTH_FOLD.size(), 30):
		lv.erase("d%d" % k)
		mg.erase("d%d" % k)
	return [lv, mg]


## Levels and managers of a 15-site save (v3) mapped onto the 10 sites with
## V3_SITE_FOLD: the best level of each group (any open -> open), a foreman
## if any had one. The second boat/plant and the lift keep theirs.
static func _fold_v3_sites(old_levels: Dictionary, old_managers: Dictionary) -> Array:
	var lv := old_levels.duplicate()
	var mg := old_managers.duplicate()
	for k in 15:
		lv.erase("d%d" % k)
		mg.erase("d%d" % k)
	for i in V3_SITE_FOLD.size():
		var best := 0
		var hired := false
		for k: int in V3_SITE_FOLD[i]:
			var old_key := "d%d" % k
			best = maxi(best, int(_num(old_levels.get(old_key), 0.0)))
			hired = hired or old_managers.get(old_key) == true
		lv["d%d" % i] = best
		mg["d%d" % i] = hired
	return [lv, mg]


## A save from before the lift: open the lift at a level that keeps up with
## the rest of the chain (so nothing suddenly stalls), and let it run by
## itself if the boat already did. Artifact bonuses may be loaded later and
## the lift has none of its own, hence a little headroom.
const LIFT_MIGRATE_HEADROOM := 1.25


func _migrate_lift() -> void:
	var target := minf(dives_rate(), minf(boats_rate(), plants_rate())) * LIFT_MIGRATE_HEADROOM
	var level := 1
	levels["lift"] = level
	while rate("lift") < target and level < 5000:
		level += 1
		levels["lift"] = level
	managers["lift"] = has_manager("boat")


static func _num(value, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback
