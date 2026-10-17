class_name MineBoss
extends RefCounted
## Bosses in the mine (the saga's worlds, Top League games): a guardian
## sits in front of some sites; the site can't be opened until it is beaten.
## A fight (BossScreen) lasts FIGHT_SEC on an arena:
## - every tap on the boss hits for TAP_SHARE of a "hit" (HIT_SEC seconds
##   of the game's income, GameState.boss_hit), taps in a row build a combo
##   (+COMBO_STEP each, up to COMBO_MAX; it breaks after COMBO_GAP idle);
## - glowing weak spots open on the boss now and then (spot_every / spot_life
##   seconds): a tap there is a critical hit (CRIT_MULT taps);
## - every ATTACK_EVERY the boss winds up (ATTACK_WIND): tap the red target
##   to parry it (the boss is stunned STUN_SEC, taps hit STUN_MULT harder),
##   or the attack lands (ink on the screen, ATTACK_COST seconds lost);
## - the player's divers shoot harpoons by themselves (DIVER_SHARE every
##   DIVER_SEC each).
## So a stronger mine hits harder: the bosses live inside the usual loop
## (upgrade, then win). Out of time: the boss heals, try again (no wait).
##
## HP is a share of the guarded site's unlock price (gate prices grow with
## stars too, so starred runs meet stronger guardians).

const FIGHT_SEC := 60.0
const HIT_SEC := 8.0
const PERFECT_MULT := 2.0
## The smallest hit, as a share of the boss's HP (a weak mine still moves the bar).
const MIN_HIT := 0.003
const TAP_SHARE := 0.25
## Taps per second that count (more do nothing: no auto-clickers on the board).
const TAP_CAP := 8.0
const CRIT_MULT := 4.0
const COMBO_STEP := 0.04
const COMBO_MAX := 2.0
const COMBO_GAP := 0.9
const ATTACK_EVERY := 7.0
const ATTACK_WIND := 1.4
const ATTACK_COST := 3.0
const STUN_SEC := 2.5
const STUN_MULT := 2.0
const DIVER_SHARE := 0.15
const DIVER_SEC := 1.5
const DIVERS := 3

## world id -> {site index: boss id}.
const GUARDS := {
	"twilight": {3: "crabblack", 6: "mother_jelly", 9: "shadow_eel", 12: "kraken", 14: "warden"},
	"atlantis": {3: "automaton", 6: "siren_queen", 9: "drowned_king", 12: "hydra", 14: "colossus"},
	"rlyeh": {3: "deep_one_priest", 6: "shoggoth", 9: "dagon_priest", 12: "star_spawn", 14: "ancient_one"},
}

## Per boss: HP as a share of the site's unlock price, the pearls it pays,
## seconds of income paid on top, how often a weak spot opens and how long
## it stays (seconds).
const BOSSES := {
	"crabblack": {"hp": 2.0, "pearls": 20, "coins_sec": 60.0, "spot_every": 2.6, "spot_life": 1.4},
	"mother_jelly": {"hp": 2.0, "pearls": 30, "coins_sec": 60.0, "spot_every": 2.4, "spot_life": 1.3},
	"shadow_eel": {"hp": 2.2, "pearls": 40, "coins_sec": 90.0, "spot_every": 2.2, "spot_life": 1.15},
	"kraken": {"hp": 2.5, "pearls": 55, "coins_sec": 90.0, "spot_every": 2.0, "spot_life": 1.05},
	"warden": {"hp": 3.0, "pearls": 100, "coins_sec": 120.0, "spot_every": 1.8, "spot_life": 0.95},
	# Act II: Atlantis. Each guard has a rule (`rule`, BossScreen):
	#   shield  - a shield phase now and then: only hero skills hurt it;
	#   charm   - its song charms a hero (no attacks) until a parry breaks it;
	#   sweep   - its attacks hit the whole party (less each);
	#   heads   - three heads with their own health; a cut head regrows
	#             while another lives;
	#   colossus - slow, huge blows (a parry is worth more), the act's end.
	"automaton": {"hp": 2.6, "pearls": 60, "coins_sec": 90.0, "spot_every": 2.4, "spot_life": 1.2, "rule": "shield"},
	"siren_queen": {"hp": 2.8, "pearls": 70, "coins_sec": 90.0, "spot_every": 2.2, "spot_life": 1.1, "rule": "charm"},
	"drowned_king": {"hp": 3.0, "pearls": 80, "coins_sec": 100.0, "spot_every": 2.1, "spot_life": 1.05, "rule": "sweep"},
	"hydra": {"hp": 3.2, "pearls": 90, "coins_sec": 110.0, "spot_every": 2.0, "spot_life": 1.0, "rule": "heads"},
	"colossus": {"hp": 3.6, "pearls": 150, "coins_sec": 150.0, "spot_every": 1.8, "spot_life": 0.95, "rule": "colossus"},
	# Act III: R'lyeh.
	#   summon - calls Deep One adds now and then; taps and shots hit them
	#            first (skills go through to the boss);
	#   regen  - heals itself all the time, a bomb (the Alchemist) stops it;
	#   curse  - curses a hero (health drains) until the Medic heals;
	#   flight - flies up out of reach now and then (no hits, no attacks);
	#   phases - the Ancient One: eyes (1), tentacles hit everyone (2),
	#            awake: tentacles and faster blows (3).
	"deep_one_priest": {"hp": 3.4, "pearls": 90, "coins_sec": 110.0, "spot_every": 2.2, "spot_life": 1.1, "rule": "summon"},
	"shoggoth": {"hp": 3.6, "pearls": 100, "coins_sec": 120.0, "spot_every": 2.1, "spot_life": 1.05, "rule": "regen"},
	"dagon_priest": {"hp": 3.8, "pearls": 110, "coins_sec": 130.0, "spot_every": 2.0, "spot_life": 1.0, "rule": "curse"},
	"star_spawn": {"hp": 4.0, "pearls": 120, "coins_sec": 140.0, "spot_every": 1.9, "spot_life": 0.95, "rule": "flight"},
	"ancient_one": {"hp": 5.0, "pearls": 250, "coins_sec": 200.0, "spot_every": 1.7, "spot_life": 0.9, "rule": "phases"},
}


## Combo multiplier after `n` hits in a row.
static func combo_mult(n: int) -> float:
	return minf(COMBO_MAX, 1.0 + COMBO_STEP * maxi(0, n - 1))


## The boss guarding site `index` of `world` ("" = none).
static func guard(world: String, index: int) -> String:
	return str(GUARDS.get(world, {}).get(index, ""))


static func data(id: String) -> Dictionary:
	return BOSSES.get(id, BOSSES["crabblack"])


static func name_key(id: String) -> String:
	return "BOSS_" + id.to_upper()
