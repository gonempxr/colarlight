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

## Dive sites from shallow to deep. value = coins/s per level; cost0 = price
## of level 1 -> 2; unlock = price to open; manager = price of its foreman;
## cycle = seconds for one dive (down, 3 hits, up), longer when deeper.
## Divers work on their own; a site's manager (foreman) doubles its output.
const DEPTHS: Array[Dictionary] = [
	{"id": "shells", "value": 0.8, "cost0": 6.0, "unlock": 0.0, "manager": 400.0, "cycle": 4.0},
	{"id": "coral", "value": 6.0, "cost0": 60.0, "unlock": 90.0, "manager": 2500.0, "cycle": 4.8},
	{"id": "pearl", "value": 45.0, "cost0": 600.0, "unlock": 1300.0, "manager": 2600.0, "cycle": 5.6},
	{"id": "copper", "value": 320.0, "cost0": 6.0e3, "unlock": 1.2e5, "manager": 2.4e5, "cycle": 6.4},
	{"id": "emerald", "value": 2300.0, "cost0": 6.0e4, "unlock": 1.0e6, "manager": 2.0e6, "cycle": 7.2},
	{"id": "crystal", "value": 1.6e4, "cost0": 6.0e5, "unlock": 2.3e6, "manager": 4.6e6, "cycle": 8.0},
	{"id": "amber", "value": 1.12e05, "cost0": 6e06, "unlock": 6.8e6, "manager": 1.4e7, "cycle": 8.3},
	{"id": "sapphire", "value": 7.84e05, "cost0": 3.0e7, "unlock": 3.0e7, "manager": 6.0e7, "cycle": 8.6},
	{"id": "gold", "value": 5.49e06, "cost0": 4.5e7, "unlock": 4.5e7, "manager": 9.0e7, "cycle": 8.9},
	{"id": "ruby", "value": 3.84e07, "cost0": 2.0e8, "unlock": 2.0e8, "manager": 4.0e8, "cycle": 9.2},
	{"id": "ice", "value": 2.69e08, "cost0": 3.0e8, "unlock": 3.0e8, "manager": 6.0e8, "cycle": 9.5},
	{"id": "lava", "value": 1.88e09, "cost0": 1.3e9, "unlock": 1.3e9, "manager": 2.6e9, "cycle": 9.8},
	{"id": "jade", "value": 1.32e10, "cost0": 1.9e9, "unlock": 1.9e9, "manager": 3.8e9, "cycle": 10.1},
	{"id": "moon", "value": 9.22e10, "cost0": 8.4e9, "unlock": 8.4e9, "manager": 1.7e10, "cycle": 10.4},
	{"id": "fossil", "value": 6.46e11, "cost0": 1.2e10, "unlock": 1.2e10, "manager": 2.4e10, "cycle": 10.7},
	{"id": "obsidian", "value": 4.52e12, "cost0": 5.3e10, "unlock": 5.3e10, "manager": 1.1e11, "cycle": 11.0},
	{"id": "glow", "value": 3.16e13, "cost0": 7.8e10, "unlock": 7.8e10, "manager": 1.6e11, "cycle": 11.3},
	{"id": "atlantis", "value": 2.21e14, "cost0": 3.4e11, "unlock": 3.4e11, "manager": 6.8e11, "cycle": 11.6},
	{"id": "meteor", "value": 1.55e15, "cost0": 5.0e11, "unlock": 5.0e11, "manager": 1.0e12, "cycle": 11.9},
	{"id": "kraken", "value": 1.09e16, "cost0": 2.2e12, "unlock": 2.2e12, "manager": 4.4e12, "cycle": 12.0},
	{"id": "star", "value": 7.6e16, "cost0": 1.4e13, "unlock": 1.4e13, "manager": 2.8e13, "cycle": 12.0},
	{"id": "vent", "value": 5.32e17, "cost0": 2.1e13, "unlock": 2.1e13, "manager": 4.2e13, "cycle": 12.0},
	{"id": "whale", "value": 3.72e18, "cost0": 9e13, "unlock": 9e13, "manager": 1.8e14, "cycle": 12.0},
	{"id": "mirror", "value": 2.61e19, "cost0": 1.3e14, "unlock": 1.3e14, "manager": 2.6e14, "cycle": 12.0},
	{"id": "storm", "value": 1.82e20, "cost0": 5.8e14, "unlock": 5.8e14, "manager": 1.2e15, "cycle": 12.0},
	{"id": "dragon", "value": 1.28e21, "cost0": 8.6e14, "unlock": 8.6e14, "manager": 1.7e15, "cycle": 12.0},
	{"id": "crown", "value": 8.94e21, "cost0": 3.8e15, "unlock": 3.8e15, "manager": 7.6e15, "cycle": 12.0},
	{"id": "void", "value": 6.26e22, "cost0": 5.5e15, "unlock": 5.5e15, "manager": 1.1e16, "cycle": 12.0},
	{"id": "time", "value": 4.38e23, "cost0": 2.4e16, "unlock": 2.4e16, "manager": 4.8e16, "cycle": 12.0},
	{"id": "heart", "value": 3.07e24, "cost0": 3.5e16, "unlock": 3.5e16, "manager": 7e16, "cycle": 12.0},
]
const FOREMAN_MULT := 2.0

## The boat and the plant change their look (and name) as they grow, like
## buildings in Clash of Clans: a new stage at every output milestone
## (level 10, 25, 50, 75...), 20 stages in all.
const BUILDING_STAGES := 20

## Boat: carries ore from the dive sites to the shore. Plant: turns ore into
## coins. Both run on taps until their manager automates them for good
## (the automation survives a Dive).
const BOAT := {"value": 1.5, "cost0": 8.0, "manager": 25.0, "cycle": 5.0}
const PLANT := {"value": 1.7, "cost0": 10.0, "manager": 45.0, "cycle": 3.0}
## The second boat and plant: bought in each run once the ocean is busy,
## bigger per level than the first ones. Provisional numbers (see sim.py).
const BOAT2 := {"value": 60.0, "cost0": 2.0e4, "manager": 4.0e5, "cycle": 6.0, "unlock": 2.0e5}
const PLANT2 := {"value": 68.0, "cost0": 2.5e4, "manager": 5.0e5, "cycle": 3.6, "unlock": 2.5e5}

## A tap on a working stage pushes its cycle forward by this share.
const TAP_BOOST := 0.1

## Dive Deeper: needs the coins and a deeper depth open every time
## (PRESTIGE_GATE_FIRST, then PRESTIGE_GATE_STEP more per Dive).
const PRESTIGE_COST := 1.2e7
const PRESTIGE_COST_GROWTH := 6.6
const PRESTIGE_GATE_FIRST := 5
const PRESTIGE_GATE_STEP := 2
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
static func upgrade_cost(cost0: float, level: int) -> float:
	return cost0 * pow(COST_GROWTH, level - 1)


## Price of `count` levels in a row starting at `level`.
static func bulk_cost(cost0: float, level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	return upgrade_cost(cost0, level) * (pow(COST_GROWTH, count) - 1.0) / (COST_GROWTH - 1.0)


## How many levels `coins` can buy starting at `level` (at least 0).
static func affordable_levels(cost0: float, level: int, coins: float) -> int:
	var first := upgrade_cost(cost0, level)
	if coins < first:
		return 0
	var n := int(floor(log(coins * (COST_GROWTH - 1.0) / first + 1.0) / log(COST_GROWTH)))
	# Guard against float error at the boundary.
	while n > 0 and bulk_cost(cost0, level, n) > coins:
		n -= 1
	return n


## Look/stage of the boat or the plant at this level: 1..BUILDING_STAGES.
static func building_stage(level: int) -> int:
	return clampi(1 + milestones(level), 1, BUILDING_STAGES)


static func divers_at(level: int) -> int:
	return mini(1 + milestones(level), MAX_DIVERS)


static func prestige_cost(times: int) -> float:
	return PRESTIGE_COST * pow(PRESTIGE_COST_GROWTH, times)


## Index of the depth that must be open before the next Dive Deeper.
static func prestige_gate(times: int) -> int:
	return mini(PRESTIGE_GATE_FIRST + PRESTIGE_GATE_STEP * times, DEPTHS.size() - 1)


static func prestige_mult(times: int) -> float:
	return pow(PRESTIGE_MULT_STEP, times)
