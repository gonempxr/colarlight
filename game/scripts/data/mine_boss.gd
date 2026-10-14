class_name MineBoss
extends RefCounted
## Bosses in the mine (the saga's worlds, Top League games): a guardian
## sits in front of some sites; the site can't be opened until it is beaten.
## A fight (BossScreen) lasts FIGHT_SEC: a ring shrinks onto a glowing weak
## spot, a tap in the window hits for HIT_SEC seconds of the game's income
## (a perfect tap, in the middle of the window, twice that). So a stronger
## mine hits harder: the bosses live inside the usual loop (upgrade, then
## win). Out of time: the boss heals, try again (no wait).
##
## HP is a share of the guarded site's unlock price (gate prices grow with
## stars too, so starred runs meet stronger guardians).

const FIGHT_SEC := 45.0
const HIT_SEC := 8.0
const PERFECT_MULT := 2.0
## The smallest hit, as a share of the boss's HP (a weak mine still moves the bar).
const MIN_HIT := 0.012

## world id -> {site index: boss id}.
const GUARDS := {
	"twilight": {3: "crabblack", 6: "mother_jelly", 9: "shadow_eel", 12: "kraken", 14: "warden"},
}

## Per boss: HP as a share of the site's unlock price, the pearls it pays,
## seconds of income paid on top, how fast its ring runs (seconds) and the
## tap window (share of the ring's run).
const BOSSES := {
	"crabblack": {"hp": 1.0, "pearls": 20, "coins_sec": 60.0, "cycle": 1.15, "window": 0.26},
	"mother_jelly": {"hp": 1.0, "pearls": 30, "coins_sec": 60.0, "cycle": 1.05, "window": 0.24},
	"shadow_eel": {"hp": 1.1, "pearls": 40, "coins_sec": 90.0, "cycle": 0.95, "window": 0.22},
	"kraken": {"hp": 1.2, "pearls": 55, "coins_sec": 90.0, "cycle": 0.9, "window": 0.2},
	"warden": {"hp": 1.5, "pearls": 100, "coins_sec": 120.0, "cycle": 0.85, "window": 0.18},
}

## Where on its run (0..1) the ring sits on the weak spot.
const SPOT_AT := 0.7


## The boss guarding site `index` of `world` ("" = none).
static func guard(world: String, index: int) -> String:
	return str(GUARDS.get(world, {}).get(index, ""))


static func data(id: String) -> Dictionary:
	return BOSSES.get(id, BOSSES["crabblack"])


static func name_key(id: String) -> String:
	return "BOSS_" + id.to_upper()


## Was a tap at `u` (0..1 along the ring's run) a hit, and a perfect one?
## Returns 0 (miss), 1 (hit) or 2 (perfect).
static func judge(id: String, u: float) -> int:
	var w := float(data(id)["window"])
	var d := absf(u - SPOT_AT)
	if d > w / 2.0:
		return 0
	return 2 if d <= w / 6.0 else 1
