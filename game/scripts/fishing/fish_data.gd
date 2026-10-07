class_name FishData
extends RefCounted
## Fishing numbers in one place: species, rarities, odds, prices, sizes,
## reel difficulty and the upgrade tables. Pure data and math (no nodes),
## so the Fishing autoload, the screen and the tests all share it.
##
## Prices are "seconds of the player's income": a fish stays worth the same
## share of income at every stage of the game (see price()).

const COMMON := 0
const UNCOMMON := 1
const RARE := 2
const EPIC := 3
const LEGENDARY := 4
const RARITY_KEYS: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
## Grey-blue, green, blue, purple, gold.
const RARITY_COLORS: Array[Color] = [Color("9db4cc"), Color("5cd05f"), Color("3aa6f0"), Color("b07cff"), Color("ffbf2e")]
## Base chances in percent (a new rod).
const ODDS: Array[float] = [60.0, 25.0, 10.0, 4.0, 1.0]
## Each rod level multiplies a rarity's weight by (1 + ROD_ODDS[r] * level).
const ROD_ODDS: Array[float] = [0.0, 0.02, 0.08, 0.12, 0.16]
## Worth of a fish of normal size, in seconds of income.
const PRICE_SEC: Array[float] = [10.0, 30.0, 120.0, 480.0, 1800.0]
## Smallest and biggest fish of a species are worth this much times the base.
const SIZE_MULT := Vector2(0.8, 1.5)
## Income never counts as less than this (coins/s), so a brand-new player
## still gets a fair price.
const MIN_RATE := 1.5

## Reel mini-game: a little fish (the marker) swims back and forth along a
## bar; tap while it is inside the green zone. Zone width (share of the
## bar) and marker speed (bar widths per second) per rarity. Rare fish also
## dart (turn around by surprise). Every rod level widens the zone, slows
## the fish, calms the darting and adds hearts, so a better rod is felt on
## every rare fish (see reel_zone(), reel_speed(), reel_dart(), reel_tries()).
const REEL_ZONE: Array[float] = [0.22, 0.17, 0.13, 0.10, 0.08]
const REEL_SPEED: Array[float] = [0.75, 0.95, 1.15, 1.35, 1.55]
## Surprise turns per second while reeling.
const REEL_DART: Array[float] = [0.0, 0.15, 0.45, 0.75, 1.0]
## Hits needed to land a fish of each rarity.
const REEL_HITS_BY: Array[int] = [3, 3, 4, 4, 5]
## Extra forgiveness on each side of the zone (kids tap a little late).
const REEL_MARGIN := 0.02
## Every miss makes the zone this much wider for the same fish.
const REEL_MERCY := 0.035
## A tap this close to the zone's middle (share of its half width) is a
## "Perfect!" pull: the fish gets PERFECT_BONUS more valuable.
const PERFECT_SHARE := 0.4
const PERFECT_BONUS := 0.1
## Hearts (misses allowed) with a level 1 rod; a stronger line adds one every
## ROD_TRY_EVERY rod levels.
const REEL_MISSES := 3
const ROD_TRY_EVERY := 5
## What each rod level does: a wider green zone (share of the bar), a slower
## fish (share of its speed, down to ROD_SLOW_MIN), calmer darting.
const ROD_ZONE := 0.008
const ROD_SLOW := 0.022
const ROD_SLOW_MIN := 0.55
const ROD_CALM := 0.03
## One more bucket slot for every ROD_BUCKET_EVERY rod levels (all worlds).
const ROD_BUCKET_EVERY := 2
## Seconds to tap after the float dips.
const BITE_WINDOW := 1.8
## Seconds the float waits before a bite.
const WAIT_SEC := Vector2(1.6, 4.2)

## Rods: 20 levels in every world (level index 0..19, shown as 1..20).
const ROD_LEVELS := 20
## Upgrades: price of each next level in minutes of income.
const ROD_MIN: Array[float] = [1.5, 3.0, 5.0, 7.0, 9.5, 12.0, 15.0, 18.0, 22.0, 26.0,
		31.0, 36.0, 42.0, 49.0, 57.0, 66.0, 76.0, 88.0, 100.0]
const BUCKET_MIN: Array[float] = [3.0, 8.0, 15.0, 25.0, 40.0, 60.0]
## Level 1 hires the fisherman, the rest make him faster.
const HELPER_MIN: Array[float] = [8.0, 6.0, 12.0, 20.0, 32.0, 48.0, 70.0, 95.0]
const BUCKET_BASE := 10
const BUCKET_STEP := 5
const HELPER_SEC := 90.0
const HELPER_SPEEDUP := 0.86
## The fisherman keeps fishing while you're away, up to this long.
const OFFLINE_CAP_SEC := 8.0 * 3600.0

## id, rarity, size range in cm.
const SPECIES: Array[Dictionary] = [
	{"id": "sardine", "rarity": COMMON, "size": Vector2(10, 22)},
	{"id": "perch", "rarity": COMMON, "size": Vector2(15, 35)},
	{"id": "goby", "rarity": COMMON, "size": Vector2(6, 16)},
	{"id": "flounder", "rarity": COMMON, "size": Vector2(20, 45)},
	{"id": "mackerel", "rarity": COMMON, "size": Vector2(25, 45)},
	{"id": "clownfish", "rarity": UNCOMMON, "size": Vector2(7, 13)},
	{"id": "tang", "rarity": UNCOMMON, "size": Vector2(12, 30)},
	{"id": "puffer", "rarity": UNCOMMON, "size": Vector2(10, 30)},
	{"id": "butterfly", "rarity": UNCOMMON, "size": Vector2(10, 22)},
	{"id": "catfish", "rarity": UNCOMMON, "size": Vector2(30, 90)},
	{"id": "angelfish", "rarity": RARE, "size": Vector2(15, 40)},
	{"id": "lionfish", "rarity": RARE, "size": Vector2(15, 38)},
	{"id": "swordfish", "rarity": RARE, "size": Vector2(120, 300)},
	{"id": "angler", "rarity": RARE, "size": Vector2(20, 60)},
	{"id": "koi", "rarity": EPIC, "size": Vector2(30, 90)},
	{"id": "rainbow", "rarity": EPIC, "size": Vector2(10, 25)},
	{"id": "golden", "rarity": LEGENDARY, "size": Vector2(15, 30)},
	{"id": "star_whale", "rarity": LEGENDARY, "size": Vector2(200, 500)},
]


static func species(id: String) -> Dictionary:
	for s in SPECIES:
		if s["id"] == id:
			return s
	return {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for s in SPECIES:
		out.append(s["id"])
	return out


static func of_rarity(r: int) -> Array[String]:
	var out: Array[String] = []
	for s in SPECIES:
		if s["rarity"] == r:
			out.append(s["id"])
	return out


static func rarity_of(id: String) -> int:
	return int(species(id).get("rarity", COMMON))


static func name_key(id: String) -> String:
	return "FISH_" + id.to_upper()


static func rarity_key(r: int) -> String:
	return "FISH_R_" + RARITY_KEYS[clampi(r, 0, 4)].to_upper()


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 4)]


## Chance weights of the five rarities for a rod level (sum = 1).
static func odds(rod_level: int) -> Array[float]:
	var w: Array[float] = []
	var total := 0.0
	for r in 5:
		var v := ODDS[r] * (1.0 + ROD_ODDS[r] * rod_level)
		w.append(v)
		total += v
	for r in 5:
		w[r] /= total
	return w


## The fisherman only lands common and uncommon fish.
static func helper_odds(rod_level: int) -> Array[float]:
	var all := odds(rod_level)
	var s := all[0] + all[1]
	return [all[0] / s, all[1] / s, 0.0, 0.0, 0.0]


static func pick_rarity(weights: Array[float], roll: float) -> int:
	var acc := 0.0
	for r in weights.size():
		acc += weights[r]
		if roll < acc:
			return r
	return COMMON


## 0..1 where the size sits in the species' range.
static func size_share(id: String, size_cm: float) -> float:
	var range_cm: Vector2 = species(id).get("size", Vector2(10, 20))
	return clampf((size_cm - range_cm.x) / maxf(0.01, range_cm.y - range_cm.x), 0.0, 1.0)


## Coins a fish is worth at an income of `rate` coins per second.
static func price(id: String, size_cm: float, rate: float) -> float:
	var r := rarity_of(id)
	var mult := lerpf(SIZE_MULT.x, SIZE_MULT.y, size_share(id, size_cm))
	return ceilf(maxf(rate, MIN_RATE) * PRICE_SEC[r] * mult)


## Random size: big ones are rarer. `roll` in 0..1.
static func size_from_roll(id: String, roll: float) -> float:
	var range_cm: Vector2 = species(id).get("size", Vector2(10, 20))
	var f := pow(clampf(roll, 0.0, 1.0), 1.6)
	return snappedf(lerpf(range_cm.x, range_cm.y, f), 0.1)


static func reel_zone(rarity: int, rod_level: int, misses: int = 0) -> float:
	return clampf(REEL_ZONE[clampi(rarity, 0, 4)] + ROD_ZONE * rod_level + REEL_MERCY * misses, 0.06, 0.6)


static func reel_speed(rarity: int, rod_level: int) -> float:
	return REEL_SPEED[clampi(rarity, 0, 4)] * rod_slow(rod_level)


## The rod's slow-down factor for the fish (1 = none).
static func rod_slow(rod_level: int) -> float:
	return maxf(ROD_SLOW_MIN, 1.0 - ROD_SLOW * rod_level)


## Surprise turns per second for this fish on this rod.
static func reel_dart(rarity: int, rod_level: int) -> float:
	return REEL_DART[clampi(rarity, 0, 4)] * maxf(0.3, 1.0 - ROD_CALM * rod_level)


static func reel_hits(rarity: int) -> int:
	return REEL_HITS_BY[clampi(rarity, 0, 4)]


## Misses allowed before the fish gets away (the hearts).
static func reel_tries(rod_level: int) -> int:
	return REEL_MISSES + int(maxi(0, rod_level) / float(ROD_TRY_EVERY))


## Seconds the marker spends inside the zone (with margins) on one pass:
## the main measure of how hard a fish is to reel.
static func reel_window(rarity: int, rod_level: int, misses: int = 0) -> float:
	return (reel_zone(rarity, rod_level, misses) + 2.0 * REEL_MARGIN) / reel_speed(rarity, rod_level)


## Where a tap at `marker` lands for a zone centered at `zone` of width `w`:
## 0 = miss, 1 = hit, 2 = perfect.
static func reel_grade(marker: float, zone: float, w: float) -> int:
	var d := absf(marker - zone)
	if d <= w / 2.0 * PERFECT_SHARE:
		return 2
	if d <= w / 2.0 + REEL_MARGIN:
		return 1
	return 0


## Extra bucket slots from rod levels (sum of the levels over all worlds).
static func rod_slots(total_rod_levels: int) -> int:
	return maxi(0, total_rod_levels) / ROD_BUCKET_EVERY


static func capacity(bucket_level: int, total_rod_levels: int = 0) -> int:
	return BUCKET_BASE + BUCKET_STEP * bucket_level + rod_slots(total_rod_levels)


## Seconds per fish for the fisherman (0 = not hired).
static func helper_interval(helper_level: int) -> float:
	if helper_level <= 0:
		return 0.0
	return HELPER_SEC * pow(HELPER_SPEEDUP, helper_level - 1)


static func table(kind: String) -> Array[float]:
	match kind:
		"rod":
			return ROD_MIN
		"bucket":
			return BUCKET_MIN
		"helper":
			return HELPER_MIN
	return []


static func max_level(kind: String) -> int:
	return table(kind).size()


## Minutes of income the next level costs (-1 when maxed).
static func upgrade_minutes(kind: String, level: int) -> float:
	var t := table(kind)
	return t[level] if level >= 0 and level < t.size() else -1.0
