class_name Balance
extends RefCounted
## All balance numbers in one place. balance/sim.py uses the same formulas;
## change both together.

const COST_GROWTH := 1.08
## Output doubles at level 10, then every 25 levels (25, 50, 75...).
const MILESTONE_FIRST := 10
const MILESTONE_STEP := 25
const MAX_DIVERS := 5

const OFFLINE_CAP_SEC := 8.0 * 3600.0
const OFFLINE_MIN_REPORT_SEC := 60.0
const AUTOSAVE_SEC := 10.0

## The worlds, in the order they open (location L is world L % 4, tier
## L / 4). name: i18n key; char: the worker character; sites: the ids of the
## world's 10 work sites (keys d0..d9, name keys SITE_<ID>).
const WORLDS: Array[Dictionary] = [
	{"id": "ocean", "name": "WORLD_OCEAN", "char": "diver",
		"sites": ["shells", "coral", "pearl", "copper", "emerald", "crystal", "gold", "glow", "atlantis", "heart"]},
	{"id": "volcano", "name": "WORLD_VOLCANO", "char": "lava_miner",
		"sites": ["ash", "obsidian", "sulfur", "ruby", "magma", "fire_opal", "garnet", "ember", "phoenix", "dragon"]},
	{"id": "acid", "name": "WORLD_ACID", "char": "chemist",
		"sites": ["slime", "moss", "shroom", "bubble", "venom", "amber", "radiant", "jade", "orchid", "goo_king"]},
	{"id": "moon", "name": "WORLD_MOON", "char": "astronaut",
		"sites": ["dust", "meteor", "crater_ice", "moonstone", "star", "comet", "nebula", "alien_egg", "ufo", "cosmic_heart"]},
]

## The one 10-step site ladder every location uses (ids are the ocean ones;
## GameState.site_id(i) gives the current world's). value = coins/s per
## level; cost0 = price of level 1 -> 2; unlock = price to open; manager =
## price of its foreman; cycle = seconds for one dive (down, 3 hits, up).
## Location L multiplies values and level prices by loc_scale(L), and the
## gate prices (unlock, foreman) by loc_gate_scale(L). Workers work on their
## own; a site's foreman doubles its output. sim.py: about 88 min for
## location 0 (calibrate.py), each later one 10-16% longer.
const DEPTHS: Array[Dictionary] = [
	{"id": "shells", "value": 0.8, "cost0": 6.0, "unlock": 0.0, "manager": 400.0, "cycle": 4.0},
	{"id": "coral", "value": 6.0, "cost0": 60.0, "unlock": 60.0, "manager": 400.0, "cycle": 4.8},
	{"id": "pearl", "value": 45.0, "cost0": 600.0, "unlock": 2.0e3, "manager": 4.0e3, "cycle": 5.6},
	{"id": "copper", "value": 320.0, "cost0": 6.0e3, "unlock": 5.2e6, "manager": 1.0e7, "cycle": 6.4},
	{"id": "emerald", "value": 2300.0, "cost0": 6.0e4, "unlock": 3.6e7, "manager": 7.2e7, "cycle": 7.2},
	{"id": "crystal", "value": 1.6e4, "cost0": 6.0e5, "unlock": 1.7e8, "manager": 3.4e8, "cycle": 8.0},
	{"id": "gold", "value": 1.12e5, "cost0": 6.0e6, "unlock": 3.0e8, "manager": 6.0e8, "cycle": 8.3},
	{"id": "glow", "value": 7.8e5, "cost0": 6.0e7, "unlock": 6.0e8, "manager": 1.2e9, "cycle": 8.9},
	{"id": "atlantis", "value": 5.5e6, "cost0": 6.0e8, "unlock": 1.2e9, "manager": 2.4e9, "cycle": 9.5},
	{"id": "heart", "value": 3.8e7, "cost0": 6.0e9, "unlock": 3.0e9, "manager": 6.0e9, "cycle": 10.1},
]
const FOREMAN_MULT := 2.0

## The boat and the plant change their look (and name) as they grow, like
## buildings in Clash of Clans: a new stage at every output milestone
## (level 10, 25, 50, 75...), 20 stages in all.
const BUILDING_STAGES := 20

## Boat: carries ore from the dive sites to the shore. Plant: turns ore into
## coins. Both run on taps until their manager automates them for good
## (the automation survives a Dive).
## The lift, boats and plants level up with CHAIN_GROWTH (cheaper than the
## sites), so the chain keeps up with ten sites within one location.
const CHAIN_GROWTH := 1.05
const BOAT := {"value": 1.5, "cost0": 8.0, "manager": 25.0, "cycle": 5.0, "growth": CHAIN_GROWTH}
const PLANT := {"value": 1.7, "cost0": 10.0, "manager": 45.0, "cycle": 3.0, "growth": CHAIN_GROWTH}
## Lift: carries the ore the divers leave in the crates at each depth up
## the shaft to the raft. One trip goes down to the deepest open depth and
## back, so a trip takes `cycle` + `cycle_step` per open depth below the
## first (the rate per second does not change with depth, a trip just
## carries more). Manual until its manager (the operator) is hired.
const LIFT := {"value": 3.0, "cost0": 4.0, "manager": 10.0, "cycle": 4.0, "cycle_step": 0.4, "unlock": 0.0, "growth": CHAIN_GROWTH}
## Levels where the lift gets a new look (rope and bucket ... bathyscaphe).
const LIFT_LOOKS: Array[int] = [1, 10, 25, 75, 150, 250]
## The lift gets faster with every look and a little with every level: the
## trip time is divided by lift_speed(). Its rate (coins/s) does not change,
## a faster trip just carries a smaller load, so the economy (and sim.py)
## stays the same; the lift only looks and feels quicker.
## Every level adds LIFT_SPEED_PER_LEVEL on top of the look's speed, so a
## level 100+ lift is clearly quicker (about 2.6x at 100, 4x at 150, the
## LIFT_SPEED_MAX at 250).
const LIFT_LOOK_SPEED: Array[float] = [1.0, 1.2, 1.45, 1.75, 2.1, 2.5]
const LIFT_SPEED_PER_LEVEL := 0.005
const LIFT_SPEED_MAX := 6.0
## Shortest trip: this many seconds plus this many per depth below the first
## (so the cabin can still be seen stopping at every crate).
const LIFT_MIN_TRIP := 1.2
const LIFT_MIN_TRIP_STEP := 0.1
## The second boat and plant: bought in each run once the ocean is busy,
## bigger per level than the first ones. Provisional numbers (see sim.py).
const BOAT2 := {"value": 60.0, "cost0": 2.0e4, "manager": 4.0e5, "cycle": 6.0, "unlock": 2.0e5, "growth": CHAIN_GROWTH}
const PLANT2 := {"value": 68.0, "cost0": 2.5e4, "manager": 5.0e5, "cycle": 3.6, "unlock": 2.5e5, "growth": CHAIN_GROWTH}
## The vault (room 3): coins wait there until collected, or until the
## accountant (its manager, kept forever like the other automation) is hired.
const VAULT := {"manager": 1.0e6}

## Locations. Every location multiplies values and prices by LOC_SCALE_STEP
## (so numbers keep growing); the gate prices (site unlocks, foremen,
## evolution forms, the location price) also by GATE_GROWTH per location and
## GATE_BUMP once from location 1 on (location 0 also pays for the managers
## that later ones keep).
const LOC_SCALE_STEP := 1000.0
const GATE_GROWTH := 1.4
const GATE_BUMP := 1.45
## Price to open the next location, at location 0.
const LOCATION_PRICE := 2.4e10
## The last location there is (the Moon): no repeats with stars after it,
## the map shows the next worlds as "coming soon". Older saves further on
## are moved back to it (GameState keeps their levels).
const LAST_LOCATION := 3
## Worker gear: 4 levels per location (level 1 is the base look, levels
## 2..4 are bought with coins, in order). GameState.evo counts the levels
## bought (0..EVO_FORMS). EVO_PRICES: price of levels 2..4 at location 0;
## GEAR_MULT: income multiplier with 0..3 levels bought (a big jump each).
const EVO_FORMS := 3
const EVO_PRICES: Array[float] = [3.0e5, 2.5e8, 3.5e9]
const GEAR_MULT: Array[float] = [1.0, 1.3, 1.7, 2.5]
## Old saves (12 forms of x1.10 each): the coins they paid for forms, at location 0.
const OLD_EVO_PRICES: Array[float] = [40.0, 200.0, 3.8e5, 1.2e7, 7.2e7, 1.9e8, 2.5e8, 4.0e8, 8.0e8, 1.6e9, 3.0e9, 4.0e9]
## Worker skins (pearls, persistent): the equipped skin of the current world
## adds this much income by rarity (0 base, 1 rare, 2 epic, 3 legendary).
const SKIN_BONUS: Array[float] = [0.0, 0.02, 0.04, 0.08]
## Room 3 decor: each level of each slot +DECOR_BONUS income.
const DECOR_BONUS := 0.01

## A tap on a working stage pushes its cycle forward by this share.
const TAP_BOOST := 0.1
## Taps that count per target (a dive site, the lift, a boat, a plant) in any
## TAP_WINDOW seconds; faster taps (an autoclicker) give nothing extra. A fast
## child taps about 6-8 times a second, so normal play never meets the cap.
## The rush meter has the same cap across all targets together.
const TAP_CAP := 10
const TAP_WINDOW := 1.0

## The old Dive Deeper (before the worlds; save version 3). Only
## prestige_mult is still used: a v3 save's Dive count becomes the
## permanent GameState.legacy_mult. The rest stays for older UI code.
const PRESTIGE_COST := 1.2e7
const PRESTIGE_COST_GROWTH := 6.5
const PRESTIGE_GATE_FIRST := 5
const PRESTIGE_GATE_STEP := 1
const PRESTIGE_MULT_STEP := 3.0


static func milestones(level: int) -> int:
	if level < MILESTONE_FIRST:
		return 0
	return 1 + level / MILESTONE_STEP


## Coins per second a stage can handle at this level.
static func output(value: float, level: int) -> float:
	if level <= 0:
		return 0.0
	return value * level * pow(2.0, milestones(level))


## Price of going from `level` to `level + 1`.
static func upgrade_cost(cost0: float, level: int, growth: float = COST_GROWTH) -> float:
	return cost0 * pow(growth, level - 1)


## Price of `count` levels in a row starting at `level`.
static func bulk_cost(cost0: float, level: int, count: int, growth: float = COST_GROWTH) -> float:
	if count <= 0:
		return 0.0
	return upgrade_cost(cost0, level, growth) * (pow(growth, count) - 1.0) / (growth - 1.0)


## How many levels `coins` can buy starting at `level` (at least 0).
static func affordable_levels(cost0: float, level: int, coins: float, growth: float = COST_GROWTH) -> int:
	var first := upgrade_cost(cost0, level, growth)
	if coins < first:
		return 0
	var n := int(floor(log(coins * (growth - 1.0) / first + 1.0) / log(growth)))
	# Guard against float error at the boundary.
	while n > 0 and bulk_cost(cost0, level, n, growth) > coins:
		n -= 1
	return n


## Cost growth per level of a stage's data (sites COST_GROWTH, chain CHAIN_GROWTH).
static func growth_of(data: Dictionary) -> float:
	return float(data.get("growth", COST_GROWTH))


# --- Worlds and locations ------------------------------------------------------

static func world_of(location: int) -> Dictionary:
	return WORLDS[posmod(location, WORLDS.size())]


static func tier_of(location: int) -> int:
	return maxi(0, location) / WORLDS.size()


## Values and level prices of location L.
static func loc_scale(location: int) -> float:
	return pow(LOC_SCALE_STEP, maxi(0, location))


## Gate prices (site unlocks, foremen, forms, the location price) of location L.
static func loc_gate_scale(location: int) -> float:
	var l := maxi(0, location)
	return loc_scale(l) * pow(GATE_GROWTH, l) * (GATE_BUMP if l > 0 else 1.0)


## Price of gear level `form` + 1 (form = 1..EVO_FORMS: the levels bought
## so far after this one) at location L.
static func evo_cost(location: int, form: int) -> float:
	return EVO_PRICES[clampi(form, 1, EVO_FORMS) - 1] * loc_gate_scale(location)


## Income multiplier with `forms` gear levels bought.
static func evo_mult(forms: int) -> float:
	return GEAR_MULT[clampi(forms, 0, EVO_FORMS)]


## Coins an old save paid for its first `forms` evolution forms at location L.
static func old_evo_spent(location: int, forms: int) -> float:
	var sum := 0.0
	for i in clampi(forms, 0, OLD_EVO_PRICES.size()):
		sum += OLD_EVO_PRICES[i]
	return sum * loc_gate_scale(location)


## Price to leave location L for L + 1.
static func location_cost(location: int) -> float:
	return LOCATION_PRICE * loc_gate_scale(location)


## Look/stage of the boat or the plant at this level: 1..BUILDING_STAGES.
static func building_stage(level: int) -> int:
	return clampi(1 + milestones(level), 1, BUILDING_STAGES)


## Look of the lift at this level: 1..LIFT_LOOKS.size().
static func lift_look(level: int) -> int:
	var look := 1
	for i in LIFT_LOOKS.size():
		if level >= LIFT_LOOKS[i]:
			look = i + 1
	return look


## How much faster than at level 1 the lift makes its trips.
static func lift_speed(level: int) -> float:
	var look_speed: float = LIFT_LOOK_SPEED[clampi(lift_look(level), 1, LIFT_LOOK_SPEED.size()) - 1]
	return minf(LIFT_SPEED_MAX, look_speed * (1.0 + LIFT_SPEED_PER_LEVEL * maxi(0, level - 1)))


## Seconds of one lift trip down to depth index `deep` and back.
static func lift_trip(level: int, deep: int) -> float:
	var base: float = LIFT["cycle"] + LIFT["cycle_step"] * deep
	return maxf(base / lift_speed(level), minf(base, LIFT_MIN_TRIP + LIFT_MIN_TRIP_STEP * deep))


static func divers_at(level: int) -> int:
	return mini(1 + milestones(level), MAX_DIVERS)


static func prestige_cost(times: int) -> float:
	return PRESTIGE_COST * pow(PRESTIGE_COST_GROWTH, times)


## Index of the depth that must be open before the next Dive Deeper.
static func prestige_gate(times: int) -> int:
	return mini(PRESTIGE_GATE_FIRST + PRESTIGE_GATE_STEP * times, DEPTHS.size() - 1)


static func prestige_mult(times: int) -> float:
	return pow(PRESTIGE_MULT_STEP, times)
