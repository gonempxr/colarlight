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
	{"id": "coral", "value": 6.0, "cost0": 60.0, "unlock": 50.0, "manager": 2.5e3, "cycle": 4.8},
	{"id": "pearl", "value": 45.0, "cost0": 600.0, "unlock": 9.0e4, "manager": 1.5e5, "cycle": 5.6},
	{"id": "copper", "value": 320.0, "cost0": 6.0e3, "unlock": 7.0e5, "manager": 1.2e6, "cycle": 6.4},
	{"id": "emerald", "value": 2300.0, "cost0": 6.0e4, "unlock": 1.7e6, "manager": 3.4e6, "cycle": 7.2},
	{"id": "crystal", "value": 1.6e4, "cost0": 6.0e5, "unlock": 3.8e6, "manager": 7.6e6, "cycle": 8.0},
	{"id": "amber", "value": 1.12e05, "cost0": 6e06, "unlock": 3.42e07, "manager": 6.84e07, "cycle": 8.3},
	{"id": "sapphire", "value": 7.84e05, "cost0": 6e07, "unlock": 3.08e08, "manager": 6.16e08, "cycle": 8.6},
	{"id": "gold", "value": 5.49e06, "cost0": 6e08, "unlock": 2.77e09, "manager": 5.54e09, "cycle": 8.9},
	{"id": "ruby", "value": 3.84e07, "cost0": 6e09, "unlock": 2.49e10, "manager": 4.99e10, "cycle": 9.2},
	{"id": "ice", "value": 2.69e08, "cost0": 6e10, "unlock": 2.24e11, "manager": 4.49e11, "cycle": 9.5},
	{"id": "lava", "value": 1.88e09, "cost0": 6e11, "unlock": 2.02e12, "manager": 4.04e12, "cycle": 9.8},
	{"id": "jade", "value": 1.32e10, "cost0": 6e12, "unlock": 1.82e13, "manager": 3.64e13, "cycle": 10.1},
	{"id": "moon", "value": 9.22e10, "cost0": 6e13, "unlock": 1.64e14, "manager": 3.27e14, "cycle": 10.4},
	{"id": "fossil", "value": 6.46e11, "cost0": 6e14, "unlock": 1.47e15, "manager": 2.94e15, "cycle": 10.7},
	{"id": "obsidian", "value": 4.52e12, "cost0": 6e15, "unlock": 1.32e16, "manager": 2.65e16, "cycle": 11.0},
	{"id": "glow", "value": 3.16e13, "cost0": 6e16, "unlock": 1.19e17, "manager": 2.38e17, "cycle": 11.3},
	{"id": "atlantis", "value": 2.21e14, "cost0": 6e17, "unlock": 1.07e18, "manager": 2.15e18, "cycle": 11.6},
	{"id": "meteor", "value": 1.55e15, "cost0": 6e18, "unlock": 9.66e18, "manager": 1.93e19, "cycle": 11.9},
	{"id": "kraken", "value": 1.09e16, "cost0": 6e19, "unlock": 8.69e19, "manager": 1.74e20, "cycle": 12.0},
	{"id": "star", "value": 7.6e16, "cost0": 6e20, "unlock": 7.82e20, "manager": 1.56e21, "cycle": 12.0},
]
const FOREMAN_MULT := 2.0

## The boat and the plant change their look (and name) as they grow, like
## buildings in Clash of Clans: a new stage at every output milestone
## (level 10, 25, 50, 75...), 15 stages in all.
const BUILDING_STAGES := 15

## Boat: carries ore from the dive sites to the shore. Plant: turns ore into
## coins. Both run on taps until their manager automates them for good
## (the automation survives a Dive).
const BOAT := {"value": 1.5, "cost0": 8.0, "manager": 25.0, "cycle": 5.0}
const PLANT := {"value": 1.7, "cost0": 10.0, "manager": 45.0, "cycle": 3.0}

## A tap on a working stage pushes its cycle forward by this share.
const TAP_BOOST := 0.1

const PRESTIGE_COST := 5.0e7
const PRESTIGE_COST_GROWTH := 6.0
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


static func prestige_mult(times: int) -> float:
	return pow(PRESTIGE_MULT_STEP, times)
