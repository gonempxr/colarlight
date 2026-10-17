class_name Party
extends RefCounted
## The boss fight party (the saga, Top League games), RPG style: divers of
## four classes fight beside the player. Each hero auto-attacks, has health
## (the boss hits back) and a skill that charges up during the fight. Heroes
## join as guards are beaten and gain experience from every fight (levels:
## more damage and health). Everything is earned in play, nothing is sold.
##
## GameState.party_xp: class id -> experience (saved with the league game).

## Per class: damage per attack (share of a "hit", GameState.boss_hit),
## seconds between attacks, health (share of the party's base), the skill,
## its charge time (s), the suit color and the guard whose defeat brings the
## hero ("" = from the start).
const CLASSES := {
	"harpooner": {"atk": 0.16, "every": 1.1, "hp": 1.0, "skill": "volley", "charge": 9.0, "suit": Color("ff8a3a"), "joins": ""},
	"guardian": {"atk": 0.08, "every": 1.5, "hp": 1.8, "skill": "shield", "charge": 11.0, "suit": Color("4a8af0"), "joins": ""},
	"medic": {"atk": 0.06, "every": 1.6, "hp": 0.9, "skill": "heal", "charge": 12.0, "suit": Color("4ae08a"), "joins": "crabblack"},
	"alchemist": {"atk": 0.12, "every": 1.4, "hp": 0.8, "skill": "bomb", "charge": 13.0, "suit": Color("c25aff"), "joins": "mother_jelly"},
	# Act II: the Oracle of Atlantis joins once the Drowned King is beaten.
	"oracle": {"atk": 0.1, "every": 1.3, "hp": 0.9, "skill": "prophecy", "charge": 14.0, "suit": Color("ffd84a"), "joins": "drowned_king"},
}
const ORDER: Array[String] = ["guardian", "harpooner", "oracle", "alchemist", "medic"]

## Skills: volley = VOLLEY_SHOTS harpoons of VOLLEY_SHARE each; shield =
## the next boss attack does nothing; heal = HEAL_SHARE of everyone's
## health back (and the fallen stand up); bomb = BOMB_SHARE at once and the
## boss takes BREAK_MULT damage for BREAK_SEC; prophecy (the Oracle) = see
## PROPHECY_SEC.
const VOLLEY_SHOTS := 8
const VOLLEY_SHARE := 0.45
const HEAL_SHARE := 0.45
const BOMB_SHARE := 3.0
const BREAK_MULT := 1.5
const BREAK_SEC := 5.0
## prophecy = every tap is a critical hit for PROPHECY_SEC.
const PROPHECY_SEC := 5.0
## A boss attack takes this share of the hit hero's full health
## (ANGRY_HIT once the boss is under half health).
const BOSS_HIT := 0.3
const ANGRY_HIT := 0.45
## Experience: a won fight, a lost one; level n -> n + 1 costs XP_STEP * n.
const XP_WIN := 120
const XP_LOSS := 45
const XP_STEP := 100
const MAX_LEVEL := 50
## Each level above 1: +LEVEL_GAIN damage and health.
const LEVEL_GAIN := 0.12


## The heroes in the party now (in ORDER), given the beaten guards' ids.
static func members(beaten: Array) -> Array[String]:
	var out: Array[String] = []
	for c in ORDER:
		var j := str(CLASSES[c]["joins"])
		if j == "" or j in beaten:
			out.append(c)
	return out


static func level_of(xp: int) -> int:
	var lv := 1
	var need := XP_STEP
	while xp >= need and lv < MAX_LEVEL:
		xp -= need
		lv += 1
		need = XP_STEP * lv
	return lv


## Experience into the current level and needed for the next: [into, need].
static func progress_of(xp: int) -> Array[int]:
	var lv := 1
	var need := XP_STEP
	while xp >= need and lv < MAX_LEVEL:
		xp -= need
		lv += 1
		need = XP_STEP * lv
	return [xp, need]


static func power(level: int) -> float:
	return 1.0 + LEVEL_GAIN * maxi(0, level - 1)


static func name_key(c: String) -> String:
	return "CLASS_" + c.to_upper()


static func skill_key(c: String) -> String:
	return "SKILL_" + str(CLASSES[c]["skill"]).to_upper()
