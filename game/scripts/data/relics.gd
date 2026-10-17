class_name Relics
extends RefCounted
## Relics (the saga's loot, Path of Exile style): every beaten mine boss
## drops one. A relic has a kind (its look), a rarity (common .. legendary)
## and rarity + 1 random properties ("affixes"). Up to SLOTS are worn; the
## bag holds BAG. Properties can be rerolled for shards, a relic can be
## melted into shards. Everything is earned in play, nothing is sold.
##
## A relic: {"kind": String, "rarity": 0..3, "affixes": [{"stat", "v", "site"?}]}

const SLOTS := 3
const BAG := 12
const RARITY_KEYS := ["RELIC_R0", "RELIC_R1", "RELIC_R2", "RELIC_R3"]
const RARITY_COLORS: Array[Color] = [Color("b8c4d8"), Color("4fb3ee"), Color("b06cf0"), Color("ffc93c")]
const KINDS := ["shell_charm", "angler_lamp", "jelly_crown", "kraken_ring", "warden_eye",
	"trident_charm", "orichalcum_ring", "siren_comb", "kings_seal", "hydra_fang"]

## stat -> [low, high] at common; rarer relics roll higher (x (1 + rarity * 0.6)).
##   all     +% all income          site    +% one site's output
##   chain   +% lift, boats, plants  boss    +% damage to bosses
##   murk    the Murk grows slower   xp      more party experience
##   tap     taps push harder (and clear more Murk)
const STATS := {
	"all": [0.04, 0.08], "site": [0.25, 0.5], "chain": [0.08, 0.16], "boss": [0.15, 0.3],
	"murk": [0.1, 0.2], "xp": [0.15, 0.3], "tap": [0.2, 0.4],
}
## Caps of a worn total (up to 15 relics on 5 heroes).
const CAPS := {"murk": 0.8, "all": 1.5, "site": 3.0, "chain": 2.0, "boss": 3.0, "xp": 2.0, "tap": 2.0}
const SALVAGE: Array[int] = [5, 12, 25, 50]
const REROLL: Array[int] = [10, 20, 40, 80]
## Base rarity of each boss's drop (+1 at UPGRADE_CHANCE).
const BOSS_RARITY := {"crabblack": 0, "mother_jelly": 1, "shadow_eel": 1, "kraken": 2, "warden": 3,
	"automaton": 1, "siren_queen": 1, "drowned_king": 2, "hydra": 2, "colossus": 3}
const UPGRADE_CHANCE := 0.25


## A new relic of `rarity` (kind and properties rolled with `rng`).
static func roll(rng: RandomNumberGenerator, rarity: int, sites: int = 15, kinds: Array = KINDS) -> Dictionary:
	rarity = clampi(rarity, 0, 3)
	return {"kind": kinds[rng.randi() % kinds.size()], "rarity": rarity, "affixes": roll_affixes(rng, rarity, sites)}


static func roll_affixes(rng: RandomNumberGenerator, rarity: int, sites: int = 15) -> Array:
	var pool: Array = STATS.keys()
	var out := []
	for i in rarity + 1:
		var stat: String = pool[rng.randi() % pool.size()]
		pool.erase(stat)
		var r: Array = STATS[stat]
		var v := snappedf(rng.randf_range(r[0], r[1]) * (1.0 + rarity * 0.6), 0.01)
		var a := {"stat": stat, "v": v}
		if stat == "site":
			a["site"] = rng.randi() % maxi(1, sites)
		out.append(a)
	return out


## The relic a boss drops.
static func drop(rng: RandomNumberGenerator, boss: String, sites: int = 15) -> Dictionary:
	var r := int(BOSS_RARITY.get(boss, 0))
	if rng.randf() < UPGRADE_CHANCE:
		r += 1
	# Act I's guards drop act I's kinds, act II's the city's.
	var act2 := BOSS_RARITY.keys().find(boss) >= 5
	return roll(rng, r, sites, KINDS.slice(5) if act2 else KINDS.slice(0, 5))


## Sum of `stat` over the worn relics (site: only those for site `site`).
static func total(worn: Array, stat: String, site: int = -1) -> float:
	var sum := 0.0
	for rel in worn:
		for a in rel.get("affixes", []):
			if a.get("stat") == stat and (stat != "site" or int(a.get("site", -1)) == site):
				sum += float(a.get("v", 0.0))
	return minf(sum, float(CAPS.get(stat, 99.0)))


## A relic read from a save (bad entries dropped, values capped).
static func clean(v) -> Dictionary:
	if not v is Dictionary or not str(v.get("kind", "")) in KINDS:
		return {}
	var r := clampi(int(v.get("rarity", 0)) if (v.get("rarity") is float or v.get("rarity") is int) else 0, 0, 3)
	var aff := []
	for a in v.get("affixes", []) if v.get("affixes") is Array else []:
		if a is Dictionary and STATS.has(str(a.get("stat", ""))) and (a.get("v") is float or a.get("v") is int):
			var top: float = float(STATS[a["stat"]][1]) * (1.0 + r * 0.6) + 0.01
			var c := {"stat": str(a["stat"]), "v": clampf(float(a["v"]), 0.0, top)}
			if c["stat"] == "site":
				c["site"] = clampi(int(a.get("site", 0)) if (a.get("site") is float or a.get("site") is int) else 0, 0, 14)
			aff.append(c)
		if aff.size() > r + 1:
			break
	return {"kind": str(v["kind"]), "rarity": r, "affixes": aff}


## "+12% all income" etc. (site names come from `site_name`).
static func describe(a: Dictionary, site_name: Callable = Callable()) -> String:
	var pct := roundi(float(a.get("v", 0.0)) * 100.0)
	var key := "RELIC_S_" + str(a.get("stat", "")).to_upper()
	var text := TranslationServer.translate(key)
	if a.get("stat") == "site":
		var n := str(site_name.call(int(a.get("site", 0)))) if site_name.is_valid() else "#%d" % (int(a.get("site", 0)) + 1)
		return text % [pct, n]
	return text % pct
