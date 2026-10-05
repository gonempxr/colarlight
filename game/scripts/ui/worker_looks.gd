class_name WorkerLooks
extends RefCounted
## The workers of the four worlds and their 13 evolution forms each
## (0 = the base look, 1..12 bought), drawn with the Art toon kit in the
## diver's space: feet at 0,0, facing +x, about 80 px tall at scale 1
## (crowns, wings and ears stick out above that).
##
## Chars.diver hands a worker over to `draw` when its pose has a "form"
## (or a "world" other than the ocean). Every form is a recipe (FORMS_*):
## a head, a torso, arms, legs, things on the back and on top of the head,
## a tool and effects, each picked from the part library below and colored
## by the recipe. Parts are drawn once into the part cache and pasted.
##
## Rarity (rarity()): 0 base (form 0), 1 rare (1-4), 2 epic (5-8),
## 3 legendary (9-11), 4 mythic (12).
##
## Non-ocean workers never swim: "swim" turns into "walk" (legs step, arms
## swing, upright). Workers whose legs are a tail, tentacles, a blob or a
## wisp glide instead of stepping.

const WORLDS := ["ocean", "volcano", "acid", "moon"]
const FORMS := 13
const RARITY_KEYS := ["RARITY_BASE", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY", "RARITY_MYTHIC"]
const RARITY_COLORS: Array[Color] = [Color("b8c4d8"), Color("4fb3ee"), Color("b06cf0"), Color("ffc93c"), Color("ff5ab4")]
## Soft rim light of each world's silhouettes.
const RIM: Array[Color] = [Color("5af0ff"), Color("ff8a2a"), Color("9cff3a"), Color("b8a8ff")]

const SHOULDER_F := Vector2(11, -39)
const SHOULDER_B := Vector2(-11, -39)
const ARM_LEN := 17.0
const SKIN := Color("ffd9b8")


static func world_index(world: String) -> int:
	return maxi(0, WORLDS.find(world))


## i18n key of a form's name: FORM_OCEAN_0 .. FORM_MOON_12.
static func name_key(world: String, form: int) -> String:
	return "FORM_%s_%d" % [world.to_upper(), clampi(form, 0, FORMS - 1)]


## 0 base, 1 rare (forms 1-4), 2 epic (5-8), 3 legendary (9-11), 4 mythic (12).
static func rarity(form: int) -> int:
	if form <= 0:
		return 0
	if form <= 4:
		return 1
	if form <= 8:
		return 2
	if form <= 11:
		return 3
	return 4


static func rarity_color(form: int) -> Color:
	return RARITY_COLORS[rarity(form)]


## The color a locked form's silhouette glows with (its world's rim light).
static func silhouette_color(world: String) -> Color:
	return RIM[world_index(world)]


## True when the form's tool is swung like a pick (false: pushed in like a drill).
static func swings(world: String, form: int) -> bool:
	return not (_spec(world_index(world), form).get("tool", "pick") in THRUST)


## Where the tool meets the deposit in the worker's own space (as Chars.dig_tip).
static func dig_tip(world: String, form: int) -> Vector2:
	match _spec(world_index(world), form).get("tool", "pick"):
		"drill":
			return Chars.dig_tip(3)
		"trident":
			return Chars.dig_tip(8)
		"sprayer", "laser":
			return Vector2(80, -44)
	return Chars.dig_tip(0)


# --- Recipes ---------------------------------------------------------------------
#
# Keys (all optional, see DEFAULT):
#   head: kid | hood | brass | lamp | heat | hazmat | gasmask | astro | robot
#         | knight | dome | creature;   cs: creature shape (rock, flame,
#         volcano, blob, ghost, alien);  hc / hc2: head colors
#   face: human | screen | glow;  eye: screen/glow eye color;  skin
#   hair, hair_c, beard, mask (swim mask rim), snorkel, reg (regulator hose),
#   goggles, eyepatch, cat (cat mouth on a screen face)
#   top: things on the head;  back: things on the back (bc / bc2 colors)
#   torso: suit | robot | armor | rock | robe | blob | ghost; suit, suit2,
#   belly, pattern + pc, emblem + ec, belt, plate
#   arms: sleeve | short | bare | robot | rock | blob | pauldron | spiky;
#   arm_c, glove
#   legs: boots | fins | bare_fins | robot | paws | frog | rock | roots | treads
#         | wheel | tentacles | mermaid | blob | wisp | robe;  leg_c, boot
#   tool: pick | hammer | anchor | sword | staff | drill | trident | sprayer |
#         laser;  tc (head), th (handle), orb, orb_shape
#   fx: bubbles | glow | embers | sparkles | bubbles_up | wisps | jets | orbit;  glow

const THRUST := ["drill", "trident", "sprayer", "laser"]

const DEFAULT := {
	"head": "hood", "cs": "rock", "hc": Color("3aa6f0"), "hc2": Color("ffc93c"), "face": "human", "eye": Color("5af0ff"),
	"skin": Color("ffd9b8"), "hair": "short", "hair_c": Color("7a4a2a"), "top": [], "back": [], "bc": Color("ffcf33"),
	"bc2": Color("ffffff"), "torso": "suit", "suit": Color("3aa6f0"), "suit2": Color("ffc93c"), "pattern": "",
	"pc": Color("ffffff"), "emblem": "", "ec": Color("ffc93c"), "arms": "sleeve", "legs": "boots", "tool": "pick",
	"tc": Color("a9b4c8"), "th": Color("c98249"), "orb": Color("ffd23f"), "orb_shape": "orb", "fx": [], "glow": Color("ffffff"),
}

const FORMS_OCEAN: Array[Dictionary] = [
	# 0 snorkel kid
	{"head": "kid", "hair": "short", "hair_c": Color("7a4a2a"), "mask": Color("ff6f61"), "snorkel": true, "suit": Color("ffb52e"),
	"emblem": "star", "ec": Color("fff6c2"), "arms": "short", "legs": "bare_fins", "leg_c": Color("3aa6f0"), "boot": Color("2bc8b4"),
	"tool": "pick", "th": Color("c98249"), "fx": ["bubbles"]},
	# 1 tank + hose
	{"head": "kid", "hair": "spiky", "hair_c": Color("3b2a20"), "mask": Color("ffcf33"), "reg": true, "suit": Color("3aa6f0"),
	"belt": Color("2f3a5c"), "pattern": "side", "pc": Color("1f6fb8"), "glove": Color("2f3a5c"), "legs": "fins", "leg_c": Color("3aa6f0"),
	"boot": Color("ffcf33"), "back": ["tank"], "bc": Color("ffcf33"), "tc": Color("d5e2f0"), "th": Color("8e552c"), "fx": ["bubbles"]},
	# 2 neon suit
	{"head": "hood", "hc": Color("ff4fd8"), "top": ["neon_crest"], "mask": Color("b6ff3c"), "reg": true, "suit": Color("ff4fd8"),
	"pattern": "zigzag", "pc": Color("b6ff3c"), "belt": Color("2a2f45"), "glove": Color("b6ff3c"), "legs": "fins", "leg_c": Color("ff4fd8"),
	"boot": Color("b6ff3c"), "back": ["twin_tanks"], "bc": Color("7df9ff"), "tc": Color("b6ff3c"), "th": Color("2a2f45"), "fx": ["bubbles"]},
	# 3 robo-diver
	{"head": "robot", "hc": Color("b8c4d8"), "hc2": Color("ffcf33"), "face": "screen", "eye": Color("7df9ff"), "top": ["antenna"],
	"torso": "robot", "suit": Color("b8c4d8"), "suit2": Color("ffcf33"), "arms": "robot", "arm_c": Color("b8c4d8"), "glove": Color("8a94a8"),
	"legs": "robot", "leg_c": Color("b8c4d8"), "boot": Color("6a7488"), "back": ["propeller"], "bc": Color("ffcf33"), "tool": "drill", "fx": ["bubbles"]},
	# 4 shark suit
	{"head": "hood", "hc": Color("6f8fc0"), "top": ["shark_fin", "teeth"], "suit": Color("6f8fc0"), "belly": Color("eef4ff"),
	"glove": Color("4a6a9a"), "legs": "fins", "leg_c": Color("6f8fc0"), "boot": Color("4a6a9a"), "back": ["shark_tail"], "bc": Color("6f8fc0"),
	"tc": Color("d5e2f0"), "fx": ["bubbles"]},
	# 5 octopus
	{"head": "hood", "hc": Color("a15cf0"), "hc2": Color("d6b0ff"), "top": ["octo_mantle"], "suit": Color("a15cf0"), "pattern": "spots",
	"pc": Color("d6b0ff"), "glove": Color("a15cf0"), "legs": "tentacles", "leg_c": Color("a15cf0"), "tc": Color("ffc93c"), "fx": ["bubbles"]},
	# 6 coral knight
	{"head": "knight", "hc": Color("ff7a8a"), "hc2": Color("ff5d73"), "top": ["coral_crest"], "torso": "armor", "suit": Color("ff9a8a"),
	"plate": Color("ffc0b8"), "emblem": "shell", "ec": Color("ff5d73"), "arms": "pauldron", "arm_c": Color("ff9a8a"), "glove": Color("ff5d73"),
	"legs": "boots", "leg_c": Color("ff9a8a"), "boot": Color("ff5d73"), "back": ["shield"], "bc": Color("ff7a8a"), "bc2": Color("ffd0d6"),
	"tool": "sword", "tc": Color("ff8fb0"), "fx": ["bubbles"]},
	# 7 glowing jellyfish
	{"head": "kid", "hair": "bald", "hair_c": Color("ff8fd8"), "top": ["jelly_bell"], "hc": Color("ff8fd8"), "suit": Color("8fe8ff"),
	"pattern": "dots_glow", "pc": Color("ff8fd8"), "glove": Color("ff8fd8"), "legs": "fins", "leg_c": Color("8fe8ff"), "boot": Color("ff8fd8"),
	"back": ["jelly_frills"], "bc": Color("ff8fd8"), "tc": Color("bff3ff"), "th": Color("8fe8ff"), "fx": ["glow", "bubbles"], "glow": Color("ff8fd8")},
	# 8 pirate diver
	{"head": "brass", "hc": Color("f5b843"), "top": ["tricorn"], "eyepatch": true, "suit": Color("f4f4f4"), "pattern": "stripes",
	"pc": Color("ef5350"), "belt": Color("6a3a20"), "glove": Color("3b2a2a"), "legs": "boots", "leg_c": Color("2e2a3d"), "boot": Color("3b2a2a"),
	"back": ["tank", "parrot"], "bc": Color("d19230"), "tool": "anchor", "tc": Color("8a94a8"), "fx": ["bubbles"]},
	# 9 mermaid
	{"head": "kid", "hair": "long", "hair_c": Color("2bc8b4"), "top": ["starfish"], "suit": Color("2bc8b4"), "pattern": "scales",
	"pc": Color("8ff0e0"), "emblem": "shell2", "ec": Color("ff8fb0"), "arms": "bare", "legs": "mermaid", "leg_c": Color("2bc8b4"),
	"boot": Color("ff8fd8"), "tool": "trident", "fx": ["bubbles", "sparkles"], "glow": Color("bff3ff")},
	# 10 sea dragon
	{"head": "hood", "hc": Color("3ad0a0"), "hc2": Color("ffd23f"), "top": ["horns", "side_fins"], "suit": Color("3ad0a0"),
	"belly": Color("ffe08a"), "pattern": "scales", "pc": Color("2aa080"), "glove": Color("2aa080"), "legs": "paws", "leg_c": Color("3ad0a0"),
	"boot": Color("2aa080"), "back": ["wings_fin", "dragon_tail"], "bc": Color("3ad0a0"), "bc2": Color("ffd23f"), "tc": Color("ffd23f"),
	"th": Color("2aa080"), "fx": ["bubbles"]},
	# 11 kraken king
	{"head": "hood", "hc": Color("6a3aa8"), "hc2": Color("ffc93c"), "top": ["crown"], "suit": Color("6a3aa8"), "pattern": "suckers",
	"pc": Color("c8a0ff"), "glove": Color("8a4ad0"), "legs": "boots", "leg_c": Color("6a3aa8"), "boot": Color("3a2060"),
	"back": ["tentacles_back"], "bc": Color("8a4ad0"), "bc2": Color("d6b0ff"), "tool": "hammer", "tc": Color("b58cff"), "th": Color("3a2060"),
	"fx": ["glow", "bubbles"], "glow": Color("b24aff")},
	# 12 Poseidon
	{"head": "kid", "hair": "long", "hair_c": Color("f4f7ff"), "beard": Color("f4f7ff"), "top": ["crown_spikes"], "torso": "armor",
	"suit": Color("4de8ff"), "plate": Color("f2b632"), "emblem": "gem", "ec": Color("4de8ff"), "arms": "pauldron", "arm_c": Color("f4f7ff"),
	"glove": Color("f2b632"), "legs": "boots", "leg_c": Color("4de8ff"), "boot": Color("f2b632"), "back": ["cape"], "bc": Color("2a6ad0"),
	"bc2": Color("f2b632"), "tool": "trident", "fx": ["sparkles", "bubbles"], "glow": Color("4de8ff")},
]

const FORMS_VOLCANO: Array[Dictionary] = [
	# 0 lava miner: hard hat with a lamp
	{"head": "lamp", "hc": Color("2f4a7a"), "hair": "short", "hair_c": Color("3b2a20"), "suit": Color("3a6ab0"), "pattern": "straps",
	"pc": Color("ff9a2e"), "belt": Color("2a2f45"), "glove": Color("ffcf33"), "legs": "boots", "leg_c": Color("2f4a7a"), "boot": Color("2a2230")},
	# 1 heat suit + tank
	{"head": "heat", "hc": Color("dfe4ec"), "hc2": Color("ff9a1f"), "suit": Color("dfe4ec"), "pattern": "band", "pc": Color("ff9a1f"),
	"belt": Color("9aa3b5"), "glove": Color("ff9a1f"), "legs": "boots", "leg_c": Color("dfe4ec"), "boot": Color("8a94a8"), "back": ["tank"],
	"bc": Color("ff7a3d"), "reg": true},
	# 2 lava-crack suit
	{"head": "lamp", "hc": Color("2a2230"), "hair": "spiky", "hair_c": Color("d8562e"), "suit": Color("3a2a34"), "pattern": "cracks",
	"pc": Color("ff8a1a"), "glove": Color("ff8a1a"), "legs": "boots", "leg_c": Color("3a2a34"), "boot": Color("ff5a1a"), "tc": Color("ff8a1a"),
	"th": Color("3a2a34"), "fx": ["embers"]},
	# 3 robot driller
	{"head": "robot", "hc": Color("ffb52e"), "hc2": Color("2a2230"), "face": "screen", "eye": Color("7df9ff"), "top": ["beacon"],
	"torso": "robot", "suit": Color("ffb52e"), "suit2": Color("3a2a34"), "arms": "robot", "arm_c": Color("ffb52e"), "glove": Color("6a7488"),
	"legs": "treads", "tool": "drill"},
	# 4 salamander
	{"head": "hood", "hc": Color("ff7a3d"), "hc2": Color("ff9ac0"), "top": ["frills", "head_spots"], "suit": Color("ff7a3d"),
	"belly": Color("ffd23f"), "pattern": "spots", "pc": Color("c0402a"), "glove": Color("ff7a3d"), "legs": "paws", "leg_c": Color("ff7a3d"),
	"boot": Color("e05a2a"), "back": ["lizard_tail"], "bc": Color("ff7a3d"), "bc2": Color("c0402a")},
	# 5 obsidian knight
	{"head": "knight", "hc": Color("3a3258"), "hc2": Color("b58cff"), "top": ["plume"], "torso": "armor", "suit": Color("2e2848"),
	"plate": Color("4a4070"), "emblem": "gem", "ec": Color("ff8a1a"), "arms": "spiky", "arm_c": Color("3a3258"), "glove": Color("2e2848"),
	"legs": "boots", "leg_c": Color("3a3258"), "boot": Color("2e2848"), "tc": Color("b58cff"), "th": Color("2e2848")},
	# 6 magma golem
	{"head": "creature", "cs": "rock", "hc": Color("6a4436"), "face": "glow", "eye": Color("ffd23f"), "torso": "rock", "suit": Color("6a4436"),
	"pc": Color("ff7a1a"), "arms": "rock", "arm_c": Color("6a4436"), "legs": "rock", "leg_c": Color("6a4436"), "tool": "hammer",
	"tc": Color("8a6a5a"), "th": Color("4a3028"), "fx": ["embers"]},
	# 7 fire fox
	{"head": "hood", "hc": Color("ff8a2a"), "hc2": Color("fff6e4"), "top": ["fox_ears"], "suit": Color("ff8a2a"), "belly": Color("fff6e4"),
	"glove": Color("3a2a34"), "legs": "paws", "leg_c": Color("ff8a2a"), "boot": Color("3a2a34"), "back": ["fox_tail"], "bc": Color("ff8a2a"),
	"bc2": Color("ffd23f"), "fx": ["embers"]},
	# 8 dwarf king
	{"head": "kid", "hair": "short", "hair_c": Color("d8562e"), "beard": Color("d8562e"), "top": ["dwarf_helm"], "torso": "armor",
	"suit": Color("c0304a"), "plate": Color("f2b632"), "emblem": "gem", "ec": Color("ef5350"), "arms": "pauldron", "arm_c": Color("c0304a"),
	"glove": Color("8e552c"), "legs": "boots", "leg_c": Color("6a3a20"), "boot": Color("3b2a2a"), "back": ["cape"], "bc": Color("c0304a"),
	"bc2": Color("f4f7ff"), "tool": "hammer", "tc": Color("f2b632"), "th": Color("8e552c")},
	# 9 phoenix wings
	{"head": "hood", "hc": Color("ff5a2a"), "hc2": Color("ffd23f"), "top": ["feather_crest"], "suit": Color("ff5a2a"), "pattern": "flames",
	"pc": Color("ffd23f"), "glove": Color("ffd23f"), "legs": "boots", "leg_c": Color("ff5a2a"), "boot": Color("ffd23f"), "back": ["wings_fire"],
	"bc": Color("ff7a2a"), "bc2": Color("ffd23f"), "tc": Color("ffd23f"), "fx": ["embers"]},
	# 10 lava dragon
	{"head": "hood", "hc": Color("c0302a"), "hc2": Color("2a2230"), "top": ["horns", "spikes"], "suit": Color("c0302a"),
	"belly": Color("ffb52e"), "pattern": "scales", "pc": Color("8a1a20"), "glove": Color("2a2230"), "legs": "paws", "leg_c": Color("c0302a"),
	"boot": Color("2a2230"), "back": ["wings_bat", "dragon_tail"], "bc": Color("c0302a"), "bc2": Color("ff8a1a"), "tc": Color("2a2230"),
	"fx": ["embers"]},
	# 11 volcano titan
	{"head": "creature", "cs": "volcano", "hc": Color("5a3a34"), "face": "glow", "eye": Color("ffd23f"), "torso": "rock",
	"suit": Color("5a3a34"), "pc": Color("ff5a1a"), "arms": "rock", "arm_c": Color("5a3a34"), "legs": "rock", "leg_c": Color("5a3a34"),
	"tool": "hammer", "tc": Color("2a2230"), "th": Color("4a3028"), "fx": ["embers", "glow"], "glow": Color("ff5a1a")},
	# 12 fire lord
	{"head": "creature", "cs": "flame", "hc": Color("ff8a1a"), "hc2": Color("ffd23f"), "face": "human", "skin": Color("ffb03a"),
	"top": ["crown"], "torso": "robe", "suit": Color("2a1a30"), "pattern": "flame_trim", "pc": Color("ff5a1a"), "emblem": "flame",
	"ec": Color("ffd23f"), "arm_c": Color("2a1a30"), "glove": Color("ff8a1a"), "legs": "robe", "back": ["cape"], "bc": Color("8a1a20"),
	"bc2": Color("ff8a1a"), "tool": "staff", "th": Color("2a1a30"), "orb": Color("ff8a1a"), "fx": ["embers", "glow"], "glow": Color("ff8a1a")},
]

const FORMS_ACID: Array[Dictionary] = [
	# 0 hazmat + goggles
	{"head": "hazmat", "hc": Color("ffd23f"), "hc2": Color("2a2f45"), "goggles": Color("5cd05f"), "suit": Color("ffd23f"),
	"pattern": "hazard", "pc": Color("2a2f45"), "emblem": "flask", "ec": Color("5cd05f"), "glove": Color("5cd05f"), "legs": "boots",
	"leg_c": Color("ffd23f"), "boot": Color("2a2f45"), "tc": Color("9cff3a"), "th": Color("2a2f45")},
	# 1 gas mask + tanks
	{"head": "gasmask", "hc": Color("8a9a5a"), "hc2": Color("4a4f3a"), "suit": Color("ff9a2e"), "belt": Color("4a4f3a"),
	"glove": Color("4a4f3a"), "legs": "boots", "leg_c": Color("ff9a2e"), "boot": Color("4a4f3a"), "back": ["twin_tanks"], "bc": Color("5cd05f")},
	# 2 neon slime suit
	{"head": "hazmat", "hc": Color("9cff3a"), "hc2": Color("c04ae0"), "suit": Color("9cff3a"), "pattern": "drips", "pc": Color("c04ae0"),
	"glove": Color("c04ae0"), "legs": "boots", "leg_c": Color("9cff3a"), "boot": Color("c04ae0"), "back": ["slime_tank"], "bc": Color("c04ae0"),
	"tc": Color("ff4fd8"), "th": Color("c04ae0"), "fx": ["bubbles_up"], "glow": Color("9cff3a")},
	# 3 robot cleaner
	{"head": "robot", "hc": Color("e8f4f0"), "hc2": Color("2bc8b4"), "face": "screen", "eye": Color("9cff3a"), "top": ["dome_light"],
	"torso": "robot", "suit": Color("e8f4f0"), "suit2": Color("2bc8b4"), "arms": "robot", "arm_c": Color("e8f4f0"), "glove": Color("2bc8b4"),
	"legs": "wheel", "back": ["tank"], "bc": Color("2bc8b4"), "tool": "sprayer", "tc": Color("9cff3a")},
	# 4 frog
	{"head": "hood", "hc": Color("5cd05f"), "hc2": Color("ff9ac0"), "top": ["frog_eyes"], "suit": Color("5cd05f"), "belly": Color("e8ffc0"),
	"pattern": "spots", "pc": Color("2f9a45"), "glove": Color("5cd05f"), "legs": "frog", "leg_c": Color("5cd05f"), "boot": Color("4ac04f")},
	# 5 mushroom
	{"head": "kid", "hair": "bald", "top": ["mushroom_cap"], "hc": Color("ef5350"), "suit": Color("f3e6cc"), "pattern": "gills",
	"pc": Color("e2c8a0"), "belt": Color("fff6e4"), "glove": Color("f3e6cc"), "legs": "boots", "leg_c": Color("e8d8b8"), "boot": Color("a07050"),
	"tc": Color("c98249"), "th": Color("8e552c")},
	# 6 slime blob
	{"head": "creature", "cs": "blob", "hc": Color("7cf06a"), "skin": Color("7cf06a"), "torso": "blob", "suit": Color("7cf06a"),
	"arms": "blob", "arm_c": Color("7cf06a"), "glove": Color("7cf06a"), "legs": "blob", "fx": ["bubbles_up"], "glow": Color("d0ffb0")},
	# 7 beetle
	{"head": "hood", "hc": Color("2a7a9a"), "hc2": Color("7df9c0"), "top": ["beetle_horn", "antennae"], "suit": Color("2a5a7a"),
	"pattern": "band", "pc": Color("2ad0a0"), "glove": Color("1a2a3a"), "legs": "boots", "leg_c": Color("2a5a7a"), "boot": Color("1a2a3a"),
	"back": ["beetle_shell"], "bc": Color("2ad0a0"), "bc2": Color("4a8aff")},
	# 8 plant monster
	{"head": "hood", "hc": Color("3fae4a"), "hc2": Color("ff5d73"), "top": ["flytrap"], "suit": Color("3fae4a"), "pattern": "leaves",
	"pc": Color("7ae070"), "glove": Color("2a8a3a"), "legs": "roots", "leg_c": Color("3fae4a"), "boot": Color("8e552c"), "back": ["leaves"],
	"bc": Color("5cd05f"), "bc2": Color("2a8a3a"), "tc": Color("ff5d73"), "th": Color("8e552c")},
	# 9 alchemist
	{"head": "kid", "hair": "curly", "hair_c": Color("eeeae2"), "top": ["alch_hat"], "hc": Color("6a3ab0"), "torso": "robe",
	"suit": Color("6a3ab0"), "pattern": "stars", "pc": Color("ffd23f"), "belt": Color("ffd23f"), "arm_c": Color("6a3ab0"),
	"glove": Color("8e552c"), "legs": "robe", "boot": Color("3b2a2a"), "tool": "staff", "th": Color("8e552c"), "orb": Color("5cff8a"),
	"orb_shape": "flask", "fx": ["bubbles_up"], "glow": Color("5cff8a")},
	# 10 swamp spirit
	{"head": "creature", "cs": "ghost", "hc": Color("8ff0d8"), "skin": Color("8ff0d8"), "top": ["lily"], "torso": "ghost",
	"suit": Color("8ff0d8"), "arms": "blob", "arm_c": Color("8ff0d8"), "glove": Color("8ff0d8"), "legs": "wisp", "tool": "staff",
	"th": Color("6a5a3a"), "orb": Color("d0ff6a"), "orb_shape": "lantern", "fx": ["wisps", "glow"], "glow": Color("9cff8a")},
	# 11 hydra
	{"head": "hood", "hc": Color("4aa060"), "hc2": Color("c04ae0"), "top": ["spikes"], "suit": Color("4aa060"), "belly": Color("d0f0a0"),
	"pattern": "scales", "pc": Color("2a7a40"), "glove": Color("2a7a40"), "legs": "paws", "leg_c": Color("4aa060"), "boot": Color("2a7a40"),
	"back": ["hydra_heads", "dragon_tail"], "bc": Color("4aa060"), "bc2": Color("c04ae0"), "tc": Color("c04ae0")},
	# 12 toxic wizard king
	{"head": "kid", "hair": "long", "hair_c": Color("eeeae2"), "beard": Color("eeeae2"), "top": ["wizard_crown"], "hc": Color("3a8a3a"),
	"torso": "robe", "suit": Color("3a2a5a"), "pattern": "drips", "pc": Color("9cff3a"), "emblem": "flask", "ec": Color("9cff3a"),
	"arm_c": Color("3a2a5a"), "glove": Color("9cff3a"), "legs": "robe", "boot": Color("2a1a3a"), "back": ["cape"], "bc": Color("2a6a2a"),
	"bc2": Color("9cff3a"), "tool": "staff", "th": Color("4a3a2a"), "orb": Color("9cff3a"), "fx": ["bubbles_up", "glow"], "glow": Color("9cff3a")},
]

const FORMS_MOON: Array[Dictionary] = [
	# 0 white suit
	{"head": "astro", "hc": Color("f4f7ff"), "hc2": Color("7ab0ff"), "face": "screen", "eye": Color("5af0ff"), "top": ["antenna"],
	"suit": Color("f4f7ff"), "emblem": "planet", "ec": Color("7ab0ff"), "belt": Color("b8c4d8"), "glove": Color("f4f7ff"), "legs": "boots",
	"leg_c": Color("f4f7ff"), "boot": Color("b8c4d8"), "back": ["astro_pack"], "bc": Color("dfe4ec"), "tc": Color("7df9ff"), "th": Color("8a94a8")},
	# 1 jetpack
	{"head": "astro", "hc": Color("f4f7ff"), "hc2": Color("ef5350"), "face": "screen", "eye": Color("5af0ff"), "top": ["antenna"],
	"suit": Color("f4f7ff"), "pattern": "side", "pc": Color("ef5350"), "belt": Color("b8c4d8"), "glove": Color("ef5350"), "legs": "boots",
	"leg_c": Color("f4f7ff"), "boot": Color("ef5350"), "back": ["jetpack"], "bc": Color("ef5350"), "tc": Color("7df9ff"), "th": Color("8a94a8"),
	"fx": ["jets"]},
	# 2 neon galaxy suit
	{"head": "astro", "hc": Color("6a4ae0"), "hc2": Color("ff8fd8"), "face": "screen", "eye": Color("ff8fd8"), "top": ["antenna"],
	"suit": Color("4a2ab0"), "pattern": "galaxy", "pc": Color("ff8fd8"), "belt": Color("2a1a6a"), "glove": Color("ff8fd8"), "legs": "boots",
	"leg_c": Color("4a2ab0"), "boot": Color("2a1a6a"), "back": ["astro_pack"], "bc": Color("6a4ae0"), "tc": Color("ff8fd8"), "th": Color("2a1a6a")},
	# 3 robot
	{"head": "robot", "hc": Color("9aa8c8"), "hc2": Color("ff5ab4"), "face": "screen", "eye": Color("ff8fd8"), "top": ["tv_antennae"],
	"torso": "robot", "suit": Color("9aa8c8"), "suit2": Color("ff5ab4"), "arms": "robot", "arm_c": Color("9aa8c8"), "glove": Color("6a7488"),
	"legs": "robot", "leg_c": Color("9aa8c8"), "boot": Color("6a7488"), "tool": "laser", "tc": Color("ff5ab4")},
	# 4 alien with antennae
	{"head": "creature", "cs": "alien", "hc": Color("8ef070"), "face": "alien", "top": ["alien_antennae"], "suit": Color("f4f7ff"),
	"pattern": "side", "pc": Color("8ef070"), "emblem": "planet", "ec": Color("8ef070"), "belt": Color("b8c4d8"), "glove": Color("8ef070"),
	"legs": "boots", "leg_c": Color("f4f7ff"), "boot": Color("8ef070"), "back": ["astro_pack"], "bc": Color("dfe4ec"), "tc": Color("8ef070"),
	"th": Color("8a94a8")},
	# 5 octo-alien
	{"head": "dome", "hc": Color("c070ff"), "face": "alien", "suit": Color("7a4ad0"), "pattern": "spots", "pc": Color("c070ff"),
	"glove": Color("c070ff"), "legs": "tentacles", "leg_c": Color("c070ff"), "tc": Color("7df9ff"), "th": Color("4a2a8a")},
	# 6 star knight
	{"head": "knight", "hc": Color("c8d4f0"), "hc2": Color("ffd23f"), "top": ["star_crest"], "torso": "armor", "suit": Color("4a5ad0"),
	"plate": Color("c8d4f0"), "emblem": "star", "ec": Color("ffd23f"), "arms": "pauldron", "arm_c": Color("c8d4f0"), "glove": Color("ffd23f"),
	"legs": "boots", "leg_c": Color("c8d4f0"), "boot": Color("4a5ad0"), "back": ["cape"], "bc": Color("2a3a9a"), "bc2": Color("ffd23f"),
	"tool": "sword", "tc": Color("bff3ff")},
	# 7 comet rider
	{"head": "astro", "hc": Color("bfefff"), "hc2": Color("ff9a2e"), "face": "screen", "eye": Color("ffd23f"), "top": ["helm_fin"],
	"suit": Color("6ad0ff"), "pattern": "stripes_diag", "pc": Color("f4f7ff"), "glove": Color("ff9a2e"), "legs": "boots", "leg_c": Color("6ad0ff"),
	"boot": Color("ff9a2e"), "back": ["comet"], "bc": Color("8ff0ff"), "tc": Color("ffd23f"), "th": Color("2a5a8a"), "fx": ["sparkles"],
	"glow": Color("bfefff")},
	# 8 nebula cape
	{"head": "astro", "hc": Color("3a2a6a"), "hc2": Color("ff8fd8"), "face": "screen", "eye": Color("ff8fd8"), "top": ["antenna"],
	"suit": Color("2a1a4a"), "pattern": "galaxy", "pc": Color("ff8fd8"), "glove": Color("ff8fd8"), "legs": "boots", "leg_c": Color("2a1a4a"),
	"boot": Color("ff8fd8"), "back": ["nebula_cape"], "bc": Color("8a3ad0"), "bc2": Color("ff8fd8"), "tool": "staff", "th": Color("2a1a4a"),
	"orb": Color("ff8fd8"), "fx": ["sparkles"], "glow": Color("ff8fd8")},
	# 9 moon cat
	{"head": "astro", "hc": Color("e0d8ff"), "hc2": Color("ff9ac0"), "face": "screen", "eye": Color("ffd23f"), "cat": true,
	"top": ["cat_ears"], "suit": Color("c8b8ff"), "emblem": "moon", "ec": Color("ffd23f"), "glove": Color("f4f7ff"), "legs": "paws",
	"leg_c": Color("c8b8ff"), "boot": Color("f4f7ff"), "back": ["cat_tail"], "bc": Color("c8b8ff"), "bc2": Color("f4f7ff"), "tc": Color("ffd23f"),
	"th": Color("8a7ab8")},
	# 10 meteor golem
	{"head": "creature", "cs": "moonrock", "hc": Color("6a7090"), "face": "glow", "eye": Color("5af0ff"), "torso": "rock",
	"suit": Color("6a7090"), "pc": Color("5af0ff"), "arms": "rock", "arm_c": Color("6a7090"), "legs": "rock", "leg_c": Color("6a7090"),
	"tool": "hammer", "tc": Color("8a90b0"), "th": Color("3a3a5a"), "fx": ["orbit"], "glow": Color("5af0ff")},
	# 11 cosmic dragon
	{"head": "hood", "hc": Color("2a3a9a"), "hc2": Color("ffd23f"), "top": ["horns", "spikes"], "suit": Color("2a3a9a"),
	"belly": Color("8ab0ff"), "pattern": "stars", "pc": Color("ffffff"), "glove": Color("1a2060"), "legs": "paws", "leg_c": Color("2a3a9a"),
	"boot": Color("1a2060"), "back": ["wings_star", "dragon_tail"], "bc": Color("3a2a8a"), "bc2": Color("ff8fd8"), "tc": Color("ffd23f"),
	"fx": ["sparkles"], "glow": Color("ffffff")},
	# 12 star king
	{"head": "astro", "hc": Color("ffd23f"), "hc2": Color("ff8fd8"), "face": "screen", "eye": Color("7df9ff"), "top": ["planet", "crown"],
	"torso": "armor", "suit": Color("2a2a6a"), "plate": Color("ffd23f"), "emblem": "star", "ec": Color("ff5ab4"), "arms": "pauldron",
	"arm_c": Color("2a2a6a"), "glove": Color("ffd23f"), "legs": "boots", "leg_c": Color("2a2a6a"), "boot": Color("ffd23f"),
	"back": ["star_cape"], "bc": Color("1a1a5a"), "bc2": Color("ffd23f"), "tool": "staff", "th": Color("ffd23f"), "orb": Color("ffd23f"),
	"orb_shape": "star", "fx": ["sparkles"], "glow": Color("ffd23f")},
]

static var _specs := {}


static func _spec(w: int, form: int) -> Dictionary:
	form = clampi(form, 0, FORMS - 1)
	var k := w * 16 + form
	var s = _specs.get(k)
	if s != null:
		return s
	var lists: Array = [FORMS_OCEAN, FORMS_VOLCANO, FORMS_ACID, FORMS_MOON]
	var d: Dictionary = DEFAULT.duplicate()
	d.merge(lists[clampi(w, 0, 3)][form], true)
	# Derived defaults.
	if not d.has("arm_c"):
		d["arm_c"] = d["suit"]
	if not d.has("leg_c"):
		d["leg_c"] = d["suit"]
	if not d.has("glove"):
		d["glove"] = Color("4a4f6a")
	if not d.has("boot"):
		d["boot"] = Color("3b2a2a")
	if not d.has("plate"):
		d["plate"] = d["suit2"]
	_specs[k] = d
	return d


# --- State while drawing one worker ---------------------------------------------------

static var _sp: Dictionary = {}
static var _w := 0
static var _form := 0
static var _wf := 0


static func _use(world: String, form: int) -> void:
	_w = world_index(world)
	_form = clampi(form, 0, FORMS - 1)
	_wf = _w * 16 + _form
	_sp = _spec(_w, _form)


## Part cache key: the part, the form, the drawing size and two small numbers.
static func _k(part: int, a: int = 0, b: int = 0) -> int:
	return (part << 56) | (_wf << 48) | (int(Chars._small) << 47) | (int(Art.fringe_min < 1.0) << 46) \
			| ((a & 0x3FFFFF) << 24) | (b & 0xFFFFFF)


static func _c(key: String) -> Color:
	return _sp.get(key, Color.WHITE)


static func _has(key: String, item: String) -> bool:
	return item in (_sp.get(key, []) as Array)


# --- The worker -------------------------------------------------------------------

## Same arguments as Chars.diver (which calls this when the pose has a form).
## Extra arm pose "walk" (air worlds; "swim" turns into it outside the ocean)
## and "show" (standing proud with the tool, for the evolution board).
static func draw(ci: CanvasItem, pos: Vector2, scale: float, world: String, form: int, facing: float, tilt: float,
		kick: float, arm: String, hit: float, carry: bool, ore: Color, emotion: String, blink: bool, t: float,
		depth: int, pose: Dictionary) -> void:
	_use(world, form)
	Chars._small = scale < 1.0
	var water := _w == 0
	if not water and arm == "swim":
		arm = "walk"
	if arm == "walk":
		tilt = 0.0
	var tool: String = _sp["tool"]
	var thrust := tool in THRUST
	var tier := 3 if thrust else 0
	var fr := _arm_pair(arm, hit, t, tier, carry, kick)
	var fa: float = fr[0]
	var ba: float = fr[1]
	var wrist: float = fr[2]
	var lean: float = fr[3]
	var lunge: float = fr[4]
	var blend: float = pose.get("blend", 1.0)
	if blend < 1.0 and pose.has("arm_from"):
		var af: String = pose["arm_from"]
		if not water and af == "swim":
			af = "walk"
		var from := _arm_pair(af, 0.0, t, tier, carry, kick)
		var e := Chars._ease_io(blend)
		fa = lerpf(from[0], fa, e)
		ba = lerpf(from[1], ba, e)
		wrist = lerpf(from[2], wrist, e)
		lean = lerpf(from[3], lean, e)
		lunge = lerpf(from[4], lunge, e)
	var turn: float = pose.get("turn", 1.0)
	var sx := facing * (1.0 if turn >= 0.0 else -1.0) * maxf(0.08, absf(turn))
	var kick_amp: float = pose.get("kick_amp", 0.0 if kick == 0.0 else 1.0)
	var legs: String = _sp["legs"]
	var glide := legs in ["mermaid", "tentacles", "blob", "wisp", "wheel", "treads"]
	var walking := arm == "walk"
	var breathe := sin(t * 2.2) * 0.012 if arm != "swim" else 0.0
	var bob := 0.0
	if walking and not glide:
		bob = -absf(sin(kick * TAU)) * 2.2 * kick_amp
	if legs == "wisp":
		bob = -4.0 + sin(t * 2.0) * 2.0
	Art.push(ci, pos, tilt * facing, Vector2(scale * sx, scale * (1.0 + breathe)))
	Art.push(ci, Vector2(lunge, bob), lean)
	var moving := (arm in ["swim", "rope", "walk"]) and kick_amp > 0.3
	_back(ci, t, moving, false)
	_legs(ci, kick, t, kick_amp, walking or arm == "rope" or not water)
	var sling: float = pose.get("sling", 1.0 if arm == "rope" else 0.0)
	var hand := _shoulder(true) + Vector2(sin(fa), cos(fa)) * ARM_LEN
	var back_at := Vector2(-18, -44)
	if carry and sling > 0.5:
		var e := Chars._ease_io((sling - 0.5) * 2.0)
		Art.push(ci, hand.lerp(back_at, e), lerpf(-(lean + tilt), 0.35 + sin(t * 6.0) * 0.08, e))
		Chars.item(ci, "sack", Vector2.ZERO, ore, depth)
		Art.pop(ci)
	_arm(ci, _shoulder(false), ba, false)
	_torso(ci, t)
	_back(ci, t, moving, true)
	if arm in ["dig", "pick", "show"] and tool != "none":
		_tool(ci, tool, fa, wrist, hit, t, arm)
	_head(ci, emotion, blink, t)
	_arm(ci, _shoulder(true), fa, true)
	if carry and sling <= 0.5:
		var e := Chars._ease_io(sling * 2.0)
		Chars.hang(ci, "sack", hand.lerp(back_at, e * 0.3), fa, ore, depth, -(lean + tilt) + sin(t * 3.0) * 0.12)
		Art.push(ci, hand)
		Art.t_circle(ci, Vector2.ZERO, 5.0, _c("glove"), 2.2, 0.0)
		Art.pop(ci)
	_fx(ci, t, arm, moving)
	Art.pop(ci)
	Art.pop(ci)


## Shoulders sit on the sides of the wide blob and ghost bodies.
static func _shoulder(front: bool) -> Vector2:
	match _sp["torso"]:
		"blob":
			return Vector2(22, -30) if front else Vector2(-20, -30)
		"ghost":
			return Vector2(19, -42) if front else Vector2(-18, -42)
	return SHOULDER_F if front else SHOULDER_B


## [front arm, back arm, wrist, lean, lunge] (see Chars._arm_pair).
static func _arm_pair(arm: String, hit: float, t: float, tier: int, carry: bool, kick: float) -> Array:
	match arm:
		"walk":
			var s := sin(kick * TAU)
			if carry:
				return [0.3 + s * 0.05, -s * 0.45, 0.0, 0.0, 0.0]
			return [s * 0.5, -s * 0.5, 0.0, 0.0, 0.0]
		"show":
			var b := sin(t * 2.2) * 0.04
			if tier == 3:
				return [1.45 + b, -0.35 - b, 0.0, 0.0, 0.0]
			return [0.95 + b, -0.35 - b, -2.2, 0.0, 0.0]
	return Chars._arm_pair(arm, hit, t, tier, carry)


# --- Shape helpers --------------------------------------------------------------------

## Outline of a stroke through `pts` that tapers from width w0 to w1.
static func _taper(pts: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var hw := lerpf(w0, w1, float(i) / (n - 1)) / 2.0
		l.append(pts[i] + d * hw)
		r.append(pts[i] - d * hw)
	r.reverse()
	l.append_array(r)
	return l


## Points of a curling curve: starts at `base` heading `a0` (radians, y down),
## turning by `curl` radians over its `length`.
static func _curl(base: Vector2, a0: float, length: float, curl: float, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array([base])
	var p := base
	var step := length / n
	for i in n:
		var f := (i + 0.5) / n
		var a := a0 + curl * f * f
		p += Vector2(cos(a), sin(a)) * step
		pts.append(p)
	return pts


static func _tentacle(ci: CanvasItem, base: Vector2, a0: float, length: float, curl: float, w0: float, col: Color, suckers: Color = Color(0, 0, 0, 0)) -> void:
	var pts := _curl(base, a0, length, curl, 8)
	Art.toon(ci, _taper(pts, w0, w0 * 0.25), col, 2.2, 0.0)
	if suckers.a > 0.0 and not Chars._small:
		for i in range(2, 7, 2):
			var d := (pts[i + 1] - pts[i - 1]).normalized().orthogonal()
			Art.disc(ci, pts[i] + d * w0 * 0.22 * (1.0 - i / 9.0), maxf(0.8, w0 * 0.16 * (1.0 - i / 10.0)), suckers)


static func _clip(pts: PackedVector2Array, shape: PackedVector2Array) -> PackedVector2Array:
	return Art.clipped(pts, shape)


# --- Back (behind and on top of the body) ---------------------------------------------

## Things on the back. `front` false: the parts behind the body (drawn
## first); true: the ones in front of the torso (straps, the parrot).
static func _back(ci: CanvasItem, t: float, moving: bool, front: bool) -> void:
	var parts: Array = _sp["back"]
	if parts.is_empty():
		return
	var dyn := 0
	for p: String in parts:
		match p:
			"propeller":
				dyn = int(fposmod(t * (5.0 if moving else 1.5), 1.0) * 6.0)
			"cape", "nebula_cape", "star_cape":
				dyn = roundi((sin(t * 2.0) * 0.04 + (0.2 if moving else 0.0)) / 0.04)
			"wings_fire", "wings_bat", "wings_fin", "wings_star":
				dyn = roundi((sin(t * (6.0 if moving else 2.0)) * 0.5 + 0.5) * 4.0)
			"jelly_frills", "tentacles_back", "hydra_heads", "fox_tail", "cat_tail", "comet", "leaves":
				dyn = int(fposmod(t * 0.8, 1.0) * 8.0)
	var key := _k(10 + int(front), dyn)
	if not Art.cache_begin(ci, key):
		for p: String in parts:
			if front:
				_back_front(ci, p)
			else:
				_back_part(ci, p, dyn)
		Art.cache_end(ci, key)
	if front:
		return
	for p: String in parts:
		match p:
			"jetpack":
				for x: float in [-27.0, -18.0]:
					var jl := (17.0 if moving else 8.0) * (0.75 + 0.25 * sin(t * 31.0 + x))
					Art.flat_now(ci, PackedVector2Array([Vector2(x - 1, -24), Vector2(x + 7, -24), Vector2(x + 3, -24 + jl)]), Color(1.0, 0.6, 0.15, 0.85))
					Art.flat_now(ci, PackedVector2Array([Vector2(x + 1, -24), Vector2(x + 5, -24), Vector2(x + 3, -24 + jl * 0.6)]), Color(1, 0.95, 0.6, 0.95))
			"comet":
				for k in 3:
					var f := fposmod(t * 0.9 + k / 3.0, 1.0)
					Art.dot(ci, Vector2(-30 - f * 40.0, -52 + sin(f * 7.0 + k) * 6.0 + f * 10.0), 2.2 * (1.0 - f) + 0.5, Color(1, 1, 1, 0.9 * (1.0 - f)))


static func _back_front(ci: CanvasItem, p: String) -> void:
	match p:
		"tank", "twin_tanks", "jetpack", "astro_pack", "slime_tank":
			# Straps over the shoulder.
			Art.t_rect(ci, Rect2(-13, -48, 5, 24), 2, Art.shade_of(_c("suit"), 0.45), 1.6, 0.0)
		"parrot":
			Art.push(ci, Vector2(-21, -46))
			Art.toon(ci, _PARROT_TAIL, Color("3aa6f0"), 1.8, 0.0)
			Art.t_ellipse(ci, Vector2(0, -6), Vector2(6.5, 8.5), Art.RED, 2.0, 0.5)
			Art.t_circle(ci, Vector2(1, -15), 5.5, Art.RED, 2.0, 0.3)
			Art.toon(ci, _PARROT_WING, Color("ffcf33"), 1.6, 0.0)
			Art.toon(ci, _PARROT_BEAK, Color("ffcf33"), 1.6, 0.0)
			Art.disc(ci, Vector2(3, -16), 1.6, Art.INK)
			Art.pop(ci)
		"hydra_heads":
			pass


static var _PARROT_TAIL := PackedVector2Array([Vector2(-3, -2), Vector2(2, -2), Vector2(-4, 14), Vector2(-9, 12)])
static var _PARROT_WING := Art.smooth_pts(PackedVector2Array([Vector2(-5, -9), Vector2(1, -7), Vector2(0, 2), Vector2(-5, 4)]), 2)
static var _PARROT_BEAK := PackedVector2Array([Vector2(5, -17), Vector2(10, -14), Vector2(5, -11)])


static func _back_part(ci: CanvasItem, p: String, dyn: int) -> void:
	var bc := _c("bc")
	var bc2 := _c("bc2")
	match p:
		"tank":
			Art.t_rect(ci, Rect2(-19, -57, 6, 6), 2, Color("5a5f7a"), 1.8, 0.0)
			Art.t_rect(ci, Rect2(-25, -53, 13, 34), 6.5, bc, 2.2, 0.6)
			Art.t_rect(ci, Rect2(-25, -44, 13, 3.5), 1, Art.shade_of(bc, 0.35), 0.0, 0.0)
		"twin_tanks":
			for k in 2:
				var x := -27.0 + k * 7.0
				Art.t_rect(ci, Rect2(x + 3, -57, 5, 5), 2, Color("5a5f7a"), 1.6, 0.0)
				Art.t_rect(ci, Rect2(x, -53, 11, 33), 5.5, Art.shade_of(bc, 0.25 - k * 0.25), 2.2, 0.5)
				Art.t_rect(ci, Rect2(x, -45, 11, 3), 1, Color("2a2f45"), 0.0, 0.0)
		"slime_tank":
			Art.t_rect(ci, Rect2(-28, -58, 16, 38), 6, Color("dff8ff"), 2.4, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(-26, -44, 12, 22), 4), Color("9cff3a"))
			for b: Vector2 in [Vector2(-22, -38), Vector2(-18, -31), Vector2(-23, -27)]:
				Art.disc(ci, b, 1.6, Color(1, 1, 1, 0.8))
			Art.flat(ci, Art.rrect_pts(Rect2(-26, -55, 3, 12), 1.5), Color(1, 1, 1, 0.7))
			Art.t_rect(ci, Rect2(-29, -61, 18, 6), 2.5, bc, 2.0, 0.0)
		"astro_pack":
			Art.t_rect(ci, Rect2(-28, -57, 16, 34), 5, bc, 2.4, 0.5)
			Art.t_rect(ci, Rect2(-25, -50, 9, 6), 2, _c("hc2"), 1.5, 0.0)
			Art.disc(ci, Vector2(-20.5, -33), 2.2, Color("5af0ff"))
		"jetpack":
			for k in 2:
				var x := -29.0 + k * 9.0
				Art.t_rect(ci, Rect2(x, -58, 10, 32), 5, Art.shade_of(bc, 0.2 - k * 0.2), 2.2, 0.5)
				Art.toon(ci, PackedVector2Array([Vector2(x + 1, -28), Vector2(x + 9, -28), Vector2(x + 10, -23), Vector2(x, -23)]), Color("4a5068"), 2.0, 0.0)
				Art.t_rect(ci, Rect2(x + 2, -54, 6, 3), 1, Color("ffd23f"), 0.0, 0.0)
		"propeller":
			Art.t_rect(ci, Rect2(-26, -50, 12, 22), 4, Color("8a94a8"), 2.2, 0.4)
			Art.push(ci, Vector2(-30, -39), dyn * TAU / 18.0)
			for k in 3:
				Art.push(ci, Vector2.ZERO, TAU * k / 3.0)
				Art.toon(ci, _BLADE, bc, 1.6, 0.0)
				Art.pop(ci)
			Art.t_circle(ci, Vector2.ZERO, 3.0, Color("6a7488"), 1.5, 0.0)
			Art.pop(ci)
		"shark_tail":
			Art.toon(ci, _SHARK_TAIL, bc, 2.4, 0.4)
		"shield":
			Art.t_circle(ci, Vector2(-20, -40), 14, Art.shade_of(bc, 0.2), 2.4, 0.4)
			Art.t_circle(ci, Vector2(-20, -40), 10, bc2, 0.0, 0.0)
			# A scallop shell on the shield.
			Art.toon(ci, _SHELL_MARK, bc, 1.6, 0.0)
		"parrot":
			pass
		"jelly_frills":
			for k in 6:
				var x: float = [-24.0, -18.0, -12.0, 14.0, 20.0, 26.0][k]
				var pts := PackedVector2Array()
				for i in 8:
					var f := i / 7.0
					pts.append(Vector2(x + sin(f * 6.0 + k + dyn * TAU / 8.0) * 3.0 - f * 4.0, -64 + f * (34.0 + (k % 3) * 8.0)))
				Art.toon(ci, _taper(pts, 5.0, 2.0), Color(bc, 0.9) if k % 2 == 0 else Color(bc.lightened(0.3), 0.9), 1.8, 0.0)
		"tentacles_back":
			var ph := dyn * TAU / 8.0
			_tentacle(ci, Vector2(4, -48), -PI * 0.42 + sin(ph) * 0.06, 52, 2.6, 12.0, Art.shade_of(bc, 0.3), bc2)
			_tentacle(ci, Vector2(-8, -48), -PI * 0.68 + sin(ph + 1.0) * 0.06, 54, -2.6, 13.0, Art.shade_of(bc, 0.15), bc2)
			_tentacle(ci, Vector2(-14, -40), -PI * 0.9 + sin(ph + 2.0) * 0.06, 46, -2.4, 12.0, bc, bc2)
			_tentacle(ci, Vector2(-14, -28), PI * 0.92 + sin(ph + 3.0) * 0.06, 40, 2.2, 11.0, bc, bc2)
		"cape":
			Art.push(ci, Vector2(-8, -53), dyn * 0.04)
			Art.toon(ci, Chars._CAPE, bc, 2.4, 0.0)
			Art.flat(ci, Chars._CAPE_LINING, Art.shade_of(bc, 0.4))
			Art.flat(ci, _clip(_CAPE_HEM, Chars._CAPE), bc2)
			Art.pop(ci)
		"nebula_cape", "star_cape":
			Art.push(ci, Vector2(-8, -53), dyn * 0.04, Vector2(1.25, 1.12))
			Art.toon(ci, Chars._CAPE, bc, 2.2, 0.0)
			Art.flat(ci, Chars._CAPE_LINING, bc2 if p == "nebula_cape" else Art.shade_of(bc, 0.3))
			for s: Vector2 in [Vector2(-10, 12), Vector2(-16, 30), Vector2(-6, 34), Vector2(-20, 41), Vector2(-2, 20)]:
				Art.toon(ci, Art.star_pts(s, 3.2, 1.3, 4), Color(1, 1, 1, 0.9) if p == "nebula_cape" else _c("bc2"), 0.0, 0.0)
			if p == "star_cape":
				Art.flat(ci, _clip(_CAPE_HEM, Chars._CAPE), bc2)
			Art.pop(ci)
		"wings_fin", "wings_bat", "wings_star", "wings_fire":
			_wings(ci, p, dyn, bc, bc2)
		"lizard_tail":
			var pts := _curl(Vector2(-9, -22), PI * 0.72, 34, 0.9, 8)
			Art.toon(ci, _taper(pts, 10, 2), bc, 2.2, 0.4)
			for i in [2, 4, 6]:
				Art.disc(ci, pts[i] + Vector2(0, -1), 1.8, bc2)
		"dragon_tail":
			var pts := _curl(Vector2(-9, -22), PI * 0.7, 36, 0.8, 8)
			Art.toon(ci, _taper(pts, 10, 3), bc, 2.2, 0.4)
			var tip := pts[8]
			var d := (pts[8] - pts[7]).normalized()
			Art.toon(ci, PackedVector2Array([tip + d.orthogonal() * 5.0, tip + d * 9.0, tip - d.orthogonal() * 5.0, tip - d * 2.0]), bc2, 2.0, 0.0)
		"fox_tail":
			Art.push(ci, Vector2(-11, -24), -0.15 + sin(dyn * TAU / 8.0) * 0.08)
			Art.toon(ci, _FOX_TAIL, bc, 2.4, 0.5)
			Art.toon(ci, _clip(_FOX_TIP, _FOX_TAIL), bc2, 0.0, 0.0)
			Art.toon(ci, _clip(_FOX_FLAME, _FOX_TAIL), Color("ffd23f"), 0.0, 0.0)
			Art.pop(ci)
		"cat_tail":
			var pts := _curl(Vector2(-10, -22), PI * 0.92, 32, 2.6 + sin(dyn * TAU / 8.0) * 0.3, 9)
			Art.toon(ci, _taper(pts, 6.5, 4.5), bc, 2.2, 0.0)
			Art.t_circle(ci, pts[9], 3.6, bc2, 2.0, 0.0)
		"beetle_shell":
			Art.toon(ci, _ELYTRA_FAR, Art.shade_of(bc, 0.3), 2.4, 0.0)
			Art.toon(ci, _ELYTRA, bc, 2.4, 0.5)
			Art.flat(ci, _clip(_ELYTRA_SHEEN, _ELYTRA), Color(bc2, 0.6))
			Art.line_c(ci, PackedVector2Array([Vector2(-8, -56), Vector2(-12, -18)]), Art.INK, 1.6)
		"leaves":
			var sw := sin(dyn * TAU / 8.0) * 0.06
			for k in 3:
				Art.push(ci, Vector2(-10, -38), -1.9 + k * 0.55 + sw)
				Art.toon(ci, _LEAF, bc if k != 1 else bc2, 2.2, 0.3)
				Art.line_c(ci, PackedVector2Array([Vector2(0, 0), Vector2(0, 30)]), Art.shade_of(bc, 0.4), 1.4)
				Art.pop(ci)
		"hydra_heads":
			var ph := dyn * TAU / 8.0
			_hydra_head(ci, _curl(Vector2(-6, -50), -PI * 0.62 + sin(ph) * 0.05, 34, -1.4, 7), bc, bc2)
			_hydra_head(ci, _curl(Vector2(-12, -42), -PI * 0.92 + sin(ph + 1.5) * 0.05, 30, 1.0, 7), Art.shade_of(bc, 0.15), bc2)
		"comet":
			Art.toon(ci, _COMET_OUT, Color(bc, 0.55), 0.0, 0.0)
			Art.toon(ci, _COMET_MID, Color(bc.lightened(0.4), 0.8), 0.0, 0.0)
			Art.toon(ci, _COMET_CORE, Color(1, 1, 1, 0.95), 0.0, 0.0)


static var _BLADE := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(3, -4), Vector2(4, -12), Vector2(0, -14), Vector2(-3, -8)]), 2)
static var _SHARK_TAIL := Art.smooth_pts(PackedVector2Array([Vector2(-10, -30), Vector2(-26, -28), Vector2(-36, -44), Vector2(-38, -40),
		Vector2(-32, -24), Vector2(-40, -10), Vector2(-36, -8), Vector2(-24, -18), Vector2(-10, -18)]), 2)
static var _SHELL_MARK := PackedVector2Array([Vector2(-20, -33), Vector2(-27, -42), Vector2(-25, -46), Vector2(-20, -48), Vector2(-15, -46), Vector2(-13, -42)])
static var _CAPE_HEM := Art.smooth_pts(PackedVector2Array([Vector2(-30, 36), Vector2(-14, 40), Vector2(-4, 36), Vector2(-4, 46), Vector2(-30, 52)]), 2)
static var _FOX_TAIL := Art.smooth_pts(PackedVector2Array([Vector2(2, 2), Vector2(-6, 4), Vector2(-20, -2), Vector2(-30, -16), Vector2(-30, -32),
		Vector2(-22, -42), Vector2(-16, -34), Vector2(-14, -20), Vector2(-6, -8)]), 3)
static var _FOX_TIP := Art.ellipse_pts(Vector2(-25, -36), Vector2(10, 10), 14)
static var _FOX_FLAME := Art.ellipse_pts(Vector2(-23, -42), Vector2(5, 6), 10)
static var _ELYTRA := Art.smooth_pts(PackedVector2Array([Vector2(-6, -58), Vector2(-20, -56), Vector2(-30, -44), Vector2(-30, -26), Vector2(-22, -14),
		Vector2(-12, -16), Vector2(-8, -30)]), 3)
static var _ELYTRA_FAR := Art.moved(_ELYTRA, Vector2(5, -3))
static var _ELYTRA_SHEEN := Art.ellipse_pts(Vector2(-22, -44), Vector2(4, 10), 10, 0.3)
static var _LEAF := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(8, 10), Vector2(9, 24), Vector2(0, 38), Vector2(-9, 24), Vector2(-8, 10)]), 2)
static var _COMET_OUT := Art.smooth_pts(PackedVector2Array([Vector2(-10, -60), Vector2(-40, -70), Vector2(-78, -62), Vector2(-46, -50), Vector2(-74, -36),
		Vector2(-38, -36), Vector2(-12, -32)]), 3)
static var _COMET_MID := Art.smooth_pts(PackedVector2Array([Vector2(-12, -56), Vector2(-40, -62), Vector2(-60, -54), Vector2(-38, -46),
		Vector2(-56, -40), Vector2(-14, -38)]), 3)
static var _COMET_CORE := Art.smooth_pts(PackedVector2Array([Vector2(-14, -52), Vector2(-34, -54), Vector2(-42, -48), Vector2(-30, -42), Vector2(-14, -42)]), 3)


static func _hydra_head(ci: CanvasItem, pts: PackedVector2Array, col: Color, eye: Color) -> void:
	Art.toon(ci, _taper(pts, 9, 7), col, 2.2, 0.0)
	var tip := pts[pts.size() - 1]
	var d := (tip - pts[pts.size() - 2]).normalized()
	var ang := d.angle()
	Art.push(ci, tip, ang)
	Art.toon(ci, _SNAKE_HEAD, col, 2.2, 0.4)
	Art.disc(ci, Vector2(3, -3.5), 2.4, Color("ffd23f"))
	Art.disc(ci, Vector2(3.6, -3.5), 1.1, Art.INK)
	Art.line_c(ci, PackedVector2Array([Vector2(11, 1), Vector2(15, 1), Vector2(17, -1)]), Color("ff5d73"), 1.4)
	Art.pop(ci)
	Art.disc(ci, pts[3], 1.6, eye)


static var _SNAKE_HEAD := Art.smooth_pts(PackedVector2Array([Vector2(-4, -6), Vector2(6, -7), Vector2(12, -2), Vector2(11, 3), Vector2(2, 5), Vector2(-4, 4)]), 2)


## Two wings: the far one peeking over the shoulder, the near one spread back.
static func _wings(ci: CanvasItem, kind: String, dyn: int, c1: Color, c2: Color) -> void:
	var flap := (dyn - 2) * 0.07
	var shape: PackedVector2Array
	match kind:
		"wings_fire":
			shape = _WING_FEATHER
		"wings_fin":
			shape = _WING_FIN
		_:
			shape = _WING_BAT
	for near in [false, true]:
		Art.push(ci, Vector2(-6, -48) if not near else Vector2(-11, -45), (0.85 - flap) if not near else (-0.2 + flap), Vector2(0.85, 0.9) if not near else Vector2.ONE)
		var col := Art.shade_of(c1, 0.3) if not near else c1
		Art.toon(ci, shape, col, 2.4, 0.0)
		match kind:
			"wings_fire":
				Art.flat(ci, _clip(_WING_FEATHER_IN, shape), c2)
				Art.flat(ci, _clip(_WING_FEATHER_CORE, shape), Color("fff6c2"))
			"wings_fin":
				for r in [0.3, 0.55, 0.8]:
					Art.line_c(ci, PackedVector2Array([Vector2(0, 0), _WING_FIN_TIP * r + Vector2(0, 0)]), Art.shade_of(col, 0.3), 1.6)
				Art.flat(ci, _clip(_WING_FIN_EDGE, shape), c2)
			"wings_bat", "wings_star":
				Art.flat(ci, _clip(_WING_BAT_IN, shape), c2 if kind == "wings_bat" else Color(c2, 0.55))
				for b in [Vector2(-30, -30), Vector2(-24, -14)]:
					Art.line_c(ci, PackedVector2Array([Vector2(-2, -4), b]), Art.shade_of(col, 0.4), 1.6)
				if kind == "wings_star":
					for s: Vector2 in [Vector2(-18, -22), Vector2(-30, -24), Vector2(-14, -10), Vector2(-24, -32)]:
						Art.toon(ci, Art.star_pts(s, 2.6, 1.0, 4), Color.WHITE, 0.0, 0.0)
		Art.pop(ci)


static var _WING_BAT := PackedVector2Array([Vector2(0, 2), Vector2(-4, -12), Vector2(-16, -30), Vector2(-40, -44), Vector2(-38, -30), Vector2(-44, -22),
		Vector2(-34, -18), Vector2(-36, -6), Vector2(-24, -8), Vector2(-20, 2), Vector2(-10, -2)])
static var _WING_BAT_IN := Art.smooth_pts(PackedVector2Array([Vector2(-10, -8), Vector2(-20, -24), Vector2(-34, -32), Vector2(-30, -16), Vector2(-18, -8)]), 2)
static var _WING_FEATHER := Art.smooth_pts(PackedVector2Array([Vector2(2, 2), Vector2(-6, -16), Vector2(-22, -36), Vector2(-44, -46), Vector2(-40, -36),
		Vector2(-50, -30), Vector2(-40, -22), Vector2(-48, -14), Vector2(-36, -10), Vector2(-40, -2), Vector2(-24, -2), Vector2(-12, 4)]), 2)
static var _WING_FEATHER_IN := Art.smooth_pts(PackedVector2Array([Vector2(-8, -6), Vector2(-20, -26), Vector2(-38, -38), Vector2(-40, -24), Vector2(-30, -10), Vector2(-14, -2)]), 2)
static var _WING_FEATHER_CORE := Art.ellipse_pts(Vector2(-12, -10), Vector2(7, 5), 10, -0.6)
static var _WING_FIN := Art.smooth_pts(PackedVector2Array([Vector2(0, 2), Vector2(-6, -16), Vector2(-20, -34), Vector2(-36, -40), Vector2(-34, -28),
		Vector2(-38, -16), Vector2(-28, -10), Vector2(-26, 0), Vector2(-12, 0)]), 2)
const _WING_FIN_TIP := Vector2(-36, -38)
static var _WING_FIN_EDGE := Art.smooth_pts(PackedVector2Array([Vector2(-34, -40), Vector2(-40, -26), Vector2(-38, -14), Vector2(-28, -6), Vector2(-24, 2),
		Vector2(-30, -12), Vector2(-34, -24)]), 2)


# --- Legs -----------------------------------------------------------------------------

static func _legs(ci: CanvasItem, kick: float, t: float, amp: float, walking: bool) -> void:
	var legs: String = _sp["legs"]
	match legs:
		"tentacles", "mermaid", "wisp", "treads", "wheel", "robe", "blob":
			var ph := int(fposmod(t * 0.9 + kick * 0.3, 1.0) * 8.0) if legs in ["tentacles", "mermaid", "wisp"] else 0
			if legs in ["treads", "wheel"]:
				ph = int(fposmod(kick * 2.0, 1.0) * 6.0)
			if legs == "robe" and walking and amp > 0.3:
				ph = 1 + int(fposmod(kick, 1.0) * 4.0)
			var key := _k(4, ph)
			if not Art.cache_begin(ci, key):
				_lower_body(ci, legs, ph)
				Art.cache_end(ci, key)
			return
	for sx: float in [-1.0, 1.0]:
		var ph := kick * TAU + (0.0 if sx < 0 else PI)
		var a := sin(ph) * (0.5 if walking else 0.45) * amp
		var fq := roundi(-a * 0.8 / 0.06) if walking else roundi(-cos(ph) * 0.3 * amp / 0.06)
		var near := sx > 0
		Art.push(ci, Vector2(5.0 * sx, -17), a)
		var key := _k(3, fq + 32, int(near))
		if not Art.cache_begin(ci, key):
			_leg(ci, legs, near)
			Art.push(ci, Vector2(0, 11), fq * 0.06)
			_foot(ci, legs, near)
			Art.pop(ci)
			Art.cache_end(ci, key)
		Art.pop(ci)


static func _leg(ci: CanvasItem, legs: String, near: bool) -> void:
	var k := 0.0 if near else 0.3
	var lc := Art.shade_of(_c("leg_c"), k)
	match legs:
		"robot":
			Art.t_rect(ci, Rect2(-3.5, -2, 7, 14), 3, Art.shade_of(Color("6a7488"), k), 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, 5), 4.2, lc, 2.0, 0.0)
		"rock":
			Art.t_rect(ci, Rect2(-6.5, -3, 13, 15), 4, lc, 2.4, 0.3)
			Art.line_c(ci, PackedVector2Array([Vector2(-4, 3), Vector2(0, 6), Vector2(4, 4)]), Color(_c("pc"), 0.9 - k), 1.6)
		"bare_fins":
			Art.t_rect(ci, Rect2(-4, -2, 8, 14), 4, Art.shade_of(SKIN, k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, -3, 10, 7), 3, lc, 2.2, 0.0)
		"roots":
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, lc, 2.2, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(-4.5, 4, 9, 3), 1), Art.shade_of(_c("leg_c"), k + 0.3))
		_:
			Art.t_rect(ci, Rect2(-4.5, -2, 9, 14), 4, lc, 2.2, 0.0)


static func _foot(ci: CanvasItem, legs: String, near: bool) -> void:
	var k := 0.0 if near else 0.3
	var b := Art.shade_of(_c("boot"), k)
	match legs:
		"fins", "bare_fins":
			Art.toon(ci, Chars._FIN1, b, 2.2, 0.0)
			Art.line_c(ci, PackedVector2Array([Vector2(4, 4), Vector2(19, 7)]), Art.shade_of(b, 0.25), 1.6)
		"robot":
			Art.toon(ci, Chars._MECH_BOOT, b, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 8, 21, 2.2), 1.0, Color(_c("suit2"), 0.9 - k), 0.0, 0.0)
		"paws":
			Art.toon(ci, _PAW, b, 2.2, 0.0)
			for x: float in [6.0, 10.5, 14.5]:
				Art.toon(ci, PackedVector2Array([Vector2(x, 6.5), Vector2(x + 3.5, 8.5), Vector2(x, 10)]), Art.shade_of(Color.WHITE, k), 1.2, 0.0)
		"frog":
			Art.toon(ci, _FROG_FOOT, b, 2.2, 0.0)
		"rock":
			Art.toon(ci, _ROCK_FOOT, Art.shade_of(_c("leg_c"), k + 0.1), 2.4, 0.0)
		"roots":
			for a: float in [0.2, -0.3, 0.7]:
				Art.push(ci, Vector2(1, 0), a)
				Art.toon(ci, _ROOT, b, 1.8, 0.0)
				Art.pop(ci)
		_:
			Art.toon(ci, Chars._BOOT, b, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-6, 7, 17, 3), 1.5, Art.shade_of(b, 0.35), 0.0, 0.0)


static var _PAW := Art.smooth_pts(PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(9, 2), Vector2(17, 4), Vector2(17, 10), Vector2(-6, 10)]), 2)
static var _FROG_FOOT := Art.smooth_pts(PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(10, 3), Vector2(22, 2), Vector2(18, 7),
		Vector2(24, 9), Vector2(16, 11), Vector2(-5, 10)]), 2)
static var _ROCK_FOOT := PackedVector2Array([Vector2(-8, -3), Vector2(8, -3), Vector2(13, 3), Vector2(13, 10), Vector2(-9, 10), Vector2(-10, 3)])
static var _ROOT := PackedVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(9, 8), Vector2(16, 11), Vector2(6, 11), Vector2(-4, 8)])


## Lower bodies that are not two legs. `ph` is the animation step.
static func _lower_body(ci: CanvasItem, legs: String, ph: int) -> void:
	var lc := _c("leg_c")
	var a := ph * TAU / 8.0
	match legs:
		"tentacles":
			var specs := [[-9.0, PI * 0.62, 1.6], [-3.0, PI * 0.55, 1.2], [3.0, PI * 0.45, -1.2], [9.0, PI * 0.38, -1.6], [0.0, PI * 0.5, 0.9]]
			for i in specs.size():
				var s: Array = specs[i]
				var col := lc if i % 2 == 0 else Art.shade_of(lc, 0.25)
				_tentacle(ci, Vector2(s[0], -20), s[1], 22, s[2] + sin(a + i * 1.3) * 0.35, 8.0, col, Color(1, 1, 1, 0.55))
		"mermaid":
			var sw := sin(a) * 0.25
			var pts := _curl(Vector2(0, -20), PI * 0.5, 30, 1.6 + sw, 8)
			Art.toon(ci, _taper(pts, 22, 6), lc, 2.4, 0.5)
			for i in [2, 4]:
				Art.arc_c(ci, pts[i], 4.0, 0.3, PI - 0.3, 6, Art.shade_of(lc, 0.3), 1.4)
			var tip := pts[8]
			var d := (pts[8] - pts[7]).normalized()
			Art.push(ci, tip, d.angle())
			Art.toon(ci, _TAIL_FIN, _c("boot"), 2.2, 0.3)
			Art.pop(ci)
		"wisp":
			var sw := sin(a) * 0.3
			var pts := _curl(Vector2(0, -26), PI * 0.55, 30, 1.4 + sw, 8)
			Art.toon(ci, _taper(pts, 26, 2), Color(_c("suit"), 0.9), 2.0, 0.0)
		"treads":
			Art.t_rect(ci, Rect2(-10, -24, 20, 10), 3, Color("4a5068"), 2.0, 0.0)
			Art.t_rect(ci, Rect2(-18, -15, 36, 15), 7.5, Color("2a2f45"), 2.4, 0.0)
			for k in 4:
				var x := -12.0 + k * 8.0
				Art.t_circle(ci, Vector2(x, -7.5), 4.2, Color("8a94a8"), 1.6, 0.0)
				Art.disc(ci, Vector2(x, -7.5) + Vector2(cos(ph + k), sin(ph + k)) * 2.0, 1.0, Color("4a5068"))
			for k in 6:
				var x := -15.0 + fposmod(k * 6.0 + ph, 32.0)
				Art.flat(ci, Art.rrect_pts(Rect2(x, -15.5, 2.5, 2.5), 0.8), Color("6a7488"))
		"wheel":
			Art.t_rect(ci, Rect2(-4, -22, 8, 12), 2, Color("6a7488"), 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, -9), 9.5, Color("2a2f45"), 2.4, 0.0)
			Art.t_circle(ci, Vector2(0, -9), 5.0, _c("suit2"), 1.6, 0.0)
			for k in 3:
				var ang := ph * TAU / 6.0 + TAU * k / 3.0
				Art.disc(ci, Vector2(0, -9) + Vector2(cos(ang), sin(ang)) * 7.2, 1.2, Color("8a94a8"))
		"robe":
			var step := 0.0 if ph == 0 else sin((ph - 1) * TAU / 4.0) * 3.0
			for sx: float in [-1.0, 1.0]:
				Art.t_ellipse(ci, Vector2(4.5 * sx + step * sx + 3, -3), Vector2(7, 4), Art.shade_of(_c("boot"), 0.0 if sx > 0 else 0.3), 2.2, 0.0)
		"blob":
			pass


static var _TAIL_FIN := Art.smooth_pts(PackedVector2Array([Vector2(-2, 0), Vector2(8, -12), Vector2(16, -14), Vector2(12, -2), Vector2(16, 12), Vector2(8, 10)]), 2)


# --- Torso ----------------------------------------------------------------------------

static func _torso(ci: CanvasItem, t: float) -> void:
	var dyn := 0
	if _sp["pattern"] in ["cracks", "dots_glow"] or _sp["torso"] in ["robot", "rock"]:
		dyn = roundi((0.6 + 0.4 * sin(t * 3.0)) * 5.0)
	var key := _k(2, dyn)
	if Art.cache_begin(ci, key):
		return
	_torso_draw(ci, dyn / 5.0)
	Art.cache_end(ci, key)


static var _TORSO := Art.rrect_pts(Rect2(-13, -47, 26, 33), 11)
static var _ROBOT_TORSO := Art.rrect_pts(Rect2(-15, -49, 30, 35), 8)
static var _ROBE := Art.smooth_pts(PackedVector2Array([Vector2(-11, -48), Vector2(11, -48), Vector2(14, -30), Vector2(18, -4), Vector2(0, -2), Vector2(-18, -4), Vector2(-14, -30)]), 3)
static var _ROCK := PackedVector2Array([Vector2(-14, -52), Vector2(-2, -55), Vector2(12, -53), Vector2(19, -42), Vector2(17, -26), Vector2(13, -14),
		Vector2(-1, -12), Vector2(-14, -15), Vector2(-19, -28), Vector2(-20, -42)])
static var _BLOB := Art.smooth_pts(PackedVector2Array([Vector2(-22, 0), Vector2(-24, -20), Vector2(-18, -50), Vector2(-4, -76), Vector2(10, -76), Vector2(22, -54),
		Vector2(26, -22), Vector2(25, 0)]), 4)
static var _GHOST := Art.smooth_pts(PackedVector2Array([Vector2(-18, -30), Vector2(-20, -54), Vector2(-8, -76), Vector2(10, -76), Vector2(22, -58),
		Vector2(20, -32), Vector2(12, -18), Vector2(-8, -18)]), 4)
static var _BOULDER := PackedVector2Array([Vector2(-10, 2), Vector2(-11, -6), Vector2(-5, -11), Vector2(4, -11), Vector2(10, -5), Vector2(9, 3)])
static var _BOULDER_LAVA := PackedVector2Array([Vector2(-6, -8), Vector2(4, -9), Vector2(7, -5), Vector2(2, -6), Vector2(0, -2), Vector2(-2, -6)])
static var _CUIRASS := Art.smooth_pts(PackedVector2Array([Vector2(-13, -47), Vector2(13, -47), Vector2(13, -34), Vector2(9, -26),
		Vector2(0, -23), Vector2(-9, -26), Vector2(-13, -34)]), 2)


static func _torso_draw(ci: CanvasItem, pulse: float) -> void:
	var suit := _c("suit")
	var kind: String = _sp["torso"]
	var shape := _TORSO
	match kind:
		"robot":
			shape = _ROBOT_TORSO
			Art.toon(ci, shape, suit, 2.6, 0.7)
			Art.t_rect(ci, Rect2(-10, -44, 20, 16), 4, _c("suit2"), 1.8, 0.3)
			for p: Vector2 in [Vector2(-12, -46), Vector2(12, -46), Vector2(-12, -18), Vector2(12, -18)]:
				Art.disc(ci, p, 1.3, Art.shade_of(suit, 0.4))
			Art.t_circle(ci, Vector2(0, -36), 4.0, Color("2a2f45"), 1.6, 0.0)
			Art.dot(ci, Vector2(0, -36), 2.6, Color(_c("eye"), 0.6 + 0.4 * pulse))
			Art.t_rect(ci, Rect2(-15, -24, 30, 6), 2, Art.shade_of(suit, 0.3), 1.8, 0.0)
			Art.t_rect(ci, Rect2(-17, -55, 36, 9), 4.5, Art.shade_of(suit, 0.2), 2.5, 0.3)
			return
		"rock":
			shape = _ROCK
			Art.toon(ci, shape, suit, 2.8, 0.8)
			var g := Color(_c("pc"), 0.7 + 0.3 * pulse)
			Art.polyline(ci, PackedVector2Array([Vector2(-8, -50), Vector2(-4, -40), Vector2(-9, -30), Vector2(-5, -18)]), g, 2.2)
			Art.polyline(ci, PackedVector2Array([Vector2(8, -48), Vector2(4, -38), Vector2(10, -28)]), g, 2.0)
			Art.polyline(ci, PackedVector2Array([Vector2(-4, -40), Vector2(4, -38)]), g, 1.8)
			if _sp["cs"] == "moonrock":
				for c: Vector2 in [Vector2(-10, -40), Vector2(10, -20), Vector2(2, -28)]:
					Art.t_circle(ci, c, 3.0, Art.shade_of(suit, 0.25), 1.2, 0.0)
			Art.dot(ci, Vector2(0, -36), 4.0 + pulse, Color(_c("pc"), 0.35))
			if _sp["cs"] == "volcano":
				for sx: float in [-1.0, 1.0]:
					var b := Vector2(sx * 16 - 1, -50)
					Art.toon(ci, Art.moved(_BOULDER, b), Art.shade_of(suit, 0.1 if sx > 0 else 0.3), 2.6, 0.6)
					Art.flat(ci, Art.moved(_BOULDER_LAVA, b), Color(_c("pc"), 0.8 + 0.2 * pulse))
			return
		"robe":
			shape = _ROBE
			Art.toon(ci, shape, suit, 2.6, 0.8)
		"blob":
			Art.toon(ci, _BLOB, Color(suit, 0.92), 2.6, 0.9)
			Art.flat(ci, Art.ellipse_pts(Vector2(-10, -56), Vector2(4, 9), 12, 0.5), Color(1, 1, 1, 0.45))
			for b: Vector2 in [Vector2(-8, -18), Vector2(12, -26), Vector2(4, -10), Vector2(-14, -34)]:
				Art.t_circle(ci, b, 2.4, Color(1, 1, 1, 0.35), 0.0, 0.0)
			Art.flat(ci, _clip(Art.rrect_pts(Rect2(-30, -6, 60, 8), 3), _BLOB), Art.shade_of(suit, 0.25))
			return
		"ghost":
			Art.toon(ci, _GHOST, Color(suit, 0.9), 2.4, 0.7)
			Art.flat(ci, Art.ellipse_pts(Vector2(-9, -60), Vector2(3.5, 7), 10, 0.5), Color(1, 1, 1, 0.5))
			return
		_:
			Art.toon(ci, shape, suit, 2.5, 0.8)
	if _sp.has("belly"):
		Art.flat(ci, _clip(Art.ellipse_pts(Vector2(2, -28), Vector2(9, 13), 16), shape), _c("belly"))
	_pattern(ci, shape, pulse)
	if kind == "armor":
		Art.toon(ci, _CUIRASS, _c("plate"), 2.2, 0.6)
		Art.flat(ci, _clip(Art.rrect_pts(Rect2(-14, -47, 28, 3), 1), _CUIRASS), Color(1, 1, 1, 0.35))
	if _sp.has("belt"):
		Art.flat(ci, _clip(Art.rrect_pts(Rect2(-20, -24, 40, 5), 1), shape), _c("belt"))
		Art.t_rect(ci, Rect2(-3, -25, 6, 7), 1.5, Art.GOLD, 1.2, 0.0)
	_emblem(ci, _sp["emblem"], _c("ec"))
	# Collar: a helmet ring, or a little neck band under a bare head.
	match _sp["head"]:
		"kid", "creature":
			if kind != "robe":
				Art.flat(ci, _clip(Art.ellipse_pts(Vector2(1, -47), Vector2(9, 4), 12), shape), Art.shade_of(suit, 0.3))
		"lamp":
			Art.flat(ci, _clip(Art.ellipse_pts(Vector2(1, -47), Vector2(9, 4), 12), shape), Art.shade_of(suit, 0.3))
		_:
			var cc := _c("hc") if _sp["head"] in ["astro", "hazmat", "heat"] else Art.shade_of(_c("hc"), 0.2)
			if kind == "armor":
				cc = _c("plate")
			Art.t_rect(ci, Rect2(-16, -53, 34, 9), 4, cc, 2.5, 0.3)


static func _pattern(ci: CanvasItem, shape: PackedVector2Array, pulse: float) -> void:
	var pc := _c("pc")
	match _sp["pattern"]:
		"zigzag":
			Art.polyline(ci, _clip_line(PackedVector2Array([Vector2(-14, -40), Vector2(-7, -33), Vector2(0, -40), Vector2(7, -33), Vector2(14, -40)])), pc, 3.2)
			Art.polyline(ci, PackedVector2Array([Vector2(-12, -30), Vector2(-6, -24), Vector2(0, -30), Vector2(6, -24), Vector2(12, -30)]), Art.shade_of(pc, 0.15), 2.4)
		"side":
			Art.flat(ci, _clip(Art.rrect_pts(Rect2(-14, -48, 7, 40), 2), shape), pc)
		"straps":
			for x: float in [-8.0, 5.0]:
				Art.flat(ci, _clip(Art.rrect_pts(Rect2(x, -50, 4.5, 30), 1), shape), pc)
			Art.flat(ci, _clip(Art.rrect_pts(Rect2(-10, -30, 20, 12), 3), shape), pc)
		"band":
			Art.flat(ci, _clip(Art.rrect_pts(Rect2(-20, -38, 40, 5), 1), shape), pc)
		"cracks":
			var g := Color(pc, 0.6 + 0.4 * pulse)
			Art.polyline(ci, PackedVector2Array([Vector2(-11, -44), Vector2(-6, -38), Vector2(-9, -31), Vector2(-3, -25), Vector2(-5, -18)]), g, 2.0)
			Art.polyline(ci, PackedVector2Array([Vector2(10, -42), Vector2(5, -36), Vector2(8, -28), Vector2(4, -20)]), g, 2.0)
			Art.polyline(ci, PackedVector2Array([Vector2(-6, -38), Vector2(0, -36), Vector2(5, -36)]), g, 1.6)
		"spots":
			for p: Vector2 in [Vector2(-8, -40), Vector2(6, -42), Vector2(9, -28), Vector2(-6, -24), Vector2(0, -33)]:
				Art.flat(ci, _clip(Art.circle_pts(p, 2.6, 10), shape), pc)
		"suckers":
			for p: Vector2 in [Vector2(-7, -40), Vector2(6, -40), Vector2(-7, -28), Vector2(6, -28)]:
				Art.toon(ci, Art.circle_pts(p, 2.4, 10), pc, 1.0, 0.0)
		"stars":
			for p: Vector2 in [Vector2(-8, -40), Vector2(6, -43), Vector2(9, -27), Vector2(-6, -24), Vector2(1, -33)]:
				Art.flat(ci, Art.star_pts(p, 2.8, 1.1, 5), pc)
		"stripes":
			for i in 4:
				Art.flat(ci, _clip(Art.rrect_pts(Rect2(-20, -45 + i * 7, 40, 3.5), 1), shape), pc)
		"stripes_diag":
			for i in 3:
				Art.flat(ci, _clip(PackedVector2Array([Vector2(-20, -30 + i * 10), Vector2(20, -50 + i * 10), Vector2(20, -46 + i * 10), Vector2(-20, -26 + i * 10)]), shape), pc)
		"scales":
			for row in 3:
				for col in 3:
					Art.arc_c(ci, Vector2(-8 + col * 8 + (row % 2) * 4, -42 + row * 7), 3.6, 0.2, PI - 0.2, 5, pc, 1.4)
		"galaxy":
			Art.flat(ci, _clip(Art.ellipse_pts(Vector2(-4, -36), Vector2(12, 6), 14, -0.5), shape), Color(pc, 0.55))
			Art.flat(ci, _clip(Art.ellipse_pts(Vector2(6, -24), Vector2(9, 4), 12, -0.4), shape), Color(Color("5af0ff"), 0.45))
			for p: Vector2 in [Vector2(-8, -42), Vector2(7, -38), Vector2(-3, -27), Vector2(9, -20), Vector2(-9, -20)]:
				Art.flat(ci, Art.star_pts(p, 2.2, 0.8, 4), Color.WHITE)
		"drips":
			for i in 5:
				var x := -11.0 + i * 5.5
				var l := 6.0 + (i * 7 % 5) * 2.5
				Art.flat(ci, _clip(Art.rrect_pts(Rect2(x - 2, -52, 4, l + 6), 2), shape), pc)
				Art.flat(ci, Art.circle_pts(Vector2(x, -46 + l), 2.6, 8), pc)
		"hazard":
			for i in 5:
				var x := -16.0 + i * 8.0
				Art.flat(ci, _clip(PackedVector2Array([Vector2(x, -18), Vector2(x + 4, -18), Vector2(x + 8, -26), Vector2(x + 4, -26)]), shape), pc)
		"dots_glow":
			for p: Vector2 in [Vector2(-7, -40), Vector2(6, -36), Vector2(-3, -26), Vector2(8, -24)]:
				Art.dot(ci, p, 3.0 + pulse, Color(pc, 0.4))
				Art.disc(ci, p, 1.8, pc)
		"flames":
			for i in 3:
				var x := -9.0 + i * 9.0
				Art.flat(ci, _clip(PackedVector2Array([Vector2(x - 5, -14), Vector2(x - 2, -26), Vector2(x, -22), Vector2(x + 2, -32), Vector2(x + 5, -14)]), shape), pc)
		"leaves":
			for p: Vector2 in [Vector2(-6, -38), Vector2(6, -28), Vector2(-4, -22)]:
				Art.flat(ci, _clip(Art.ellipse_pts(p, Vector2(5, 2.4), 10, -0.6), shape), pc)
		"gills":
			for i in 5:
				var x := -10.0 + i * 5.0
				Art.line_c(ci, PackedVector2Array([Vector2(x, -44), Vector2(x + 1, -28)]), pc, 1.4)
		"flame_trim":
			Art.flat(ci, _clip(Art.smooth_pts(PackedVector2Array([Vector2(-22, -2), Vector2(-14, -14), Vector2(-8, -8), Vector2(0, -18), Vector2(8, -8),
					Vector2(14, -14), Vector2(22, -2)]), 2), shape), pc)
			Art.flat(ci, _clip(Art.rrect_pts(Rect2(-3, -48, 6, 46), 2), shape), Color(pc, 0.8))


## A line kept inside the torso (only its own few points, not exact).
static func _clip_line(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(clampf(p.x, -11.5, 11.5), p.y))
	return out


static func _emblem(ci: CanvasItem, kind: String, col: Color) -> void:
	var c := Vector2(1, -36)
	match kind:
		"star":
			Art.toon(ci, Art.star_pts(c, 5.5, 2.4, 5), col, 1.6, 0.0)
		"shell", "shell2":
			Art.toon(ci, PackedVector2Array([c + Vector2(0, 5), c + Vector2(-6, -2), c + Vector2(-4, -5), c + Vector2(0, -6), c + Vector2(4, -5), c + Vector2(6, -2)]), col, 1.6, 0.0)
			Art.line_c(ci, PackedVector2Array([c + Vector2(0, 4), c + Vector2(0, -5)]), Art.shade_of(col, 0.3), 1.0)
		"gem":
			Art.toon(ci, PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), col, 1.6, 0.0)
			Art.flat(ci, PackedVector2Array([c + Vector2(-2, -1), c + Vector2(0, -3.5), c + Vector2(0, 0)]), Color(1, 1, 1, 0.6))
		"planet":
			Art.t_circle(ci, c, 4.0, col, 1.4, 0.0)
			Art.arc_c(ci, c, 6.5, -0.4, PI - 0.4, 8, Art.INK, 1.4)
		"moon":
			Art.toon(ci, _clip_moon(c, 5.5), col, 1.4, 0.0)
		"flask":
			Art.toon(ci, PackedVector2Array([c + Vector2(-1.5, -6), c + Vector2(1.5, -6), c + Vector2(1.5, -2), c + Vector2(5, 5), c + Vector2(-5, 5), c + Vector2(-1.5, -2)]), Color.WHITE, 1.4, 0.0)
			Art.flat(ci, PackedVector2Array([c + Vector2(-3.4, 2), c + Vector2(3.4, 2), c + Vector2(4.3, 4.3), c + Vector2(-4.3, 4.3)]), col)
		"flame":
			Art.toon(ci, PackedVector2Array([c + Vector2(0, -7), c + Vector2(4, -1), c + Vector2(4, 3), c + Vector2(0, 6), c + Vector2(-4, 3), c + Vector2(-3, -2), c + Vector2(-1, 0)]), col, 1.4, 0.0)


static func _clip_moon(c: Vector2, r: float) -> PackedVector2Array:
	var full := Art.circle_pts(c, r, 16)
	var cut := Art.circle_pts(c + Vector2(r * 0.55, -r * 0.3), r * 0.85, 16)
	var res := Geometry2D.clip_polygons(full, cut)
	return res[0] if res.size() > 0 else full


# --- Arms -----------------------------------------------------------------------------

static func _arm(ci: CanvasItem, shoulder: Vector2, angle: float, front: bool) -> void:
	Art.push(ci, shoulder, -angle)
	var key := _k(5, int(front))
	if not Art.cache_begin(ci, key):
		_arm_shape(ci, front)
		Art.cache_end(ci, key)
	Art.pop(ci)


static func _arm_shape(ci: CanvasItem, front: bool) -> void:
	var k := 0.0 if front else 0.35
	var c := Art.shade_of(_c("arm_c"), k)
	var g := Art.shade_of(_c("glove"), k * 0.8)
	match _sp["arms"]:
		"short":
			Art.t_rect(ci, Rect2(-4, -3, 8, 19), 4, Art.shade_of(SKIN, k), 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, -4, 10, 9), 4, c, 2.2, 0.0)
			g = Art.shade_of(SKIN, k)
		"bare":
			Art.t_rect(ci, Rect2(-4, -3, 8, 19), 4, Art.shade_of(SKIN, k), 2.2, 0.0)
			g = Art.shade_of(SKIN, k)
			Art.t_rect(ci, Rect2(-4.5, 9, 9, 3), 1.2, Art.shade_of(Color("ffd23f"), k), 0.0, 0.0)
		"robot":
			Art.t_rect(ci, Rect2(-3, -2, 6, 18), 2.5, Art.shade_of(Color("6a7488"), k), 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, 0), 5.5, c, 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, 9), 3.6, c, 1.8, 0.0)
			Art.push(ci, Vector2(0, ARM_LEN))
			Art.toon(ci, _CLAW, g, 1.8, 0.0)
			Art.pop(ci)
			return
		"rock":
			Art.toon(ci, _ROCK_ARM, c, 2.4, 0.3)
			Art.push(ci, Vector2(0, ARM_LEN + 1))
			Art.toon(ci, _ROCK_FIST, Art.shade_of(c, 0.1), 2.4, 0.3)
			Art.line_c(ci, PackedVector2Array([Vector2(-3, -2), Vector2(1, 2)]), Color(_c("pc"), 0.9 - k), 1.6)
			Art.pop(ci)
			return
		"blob":
			Art.toon(ci, Art.ellipse_pts(Vector2(0, 8), Vector2(5.5, 12), 14), Color(c, 0.92), 2.2, 0.0)
			return
		"pauldron":
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
			Art.t_rect(ci, Rect2(-5, 9, 10, 4), 1.5, Art.shade_of(_c("plate"), k), 0.0, 0.0)
			Art.toon(ci, Chars._PAULDRON, Art.shade_of(_c("plate"), k), 2.2, 0.4)
		"spiky":
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
			Art.toon(ci, Chars._PAULDRON, Art.shade_of(_c("plate"), k), 2.2, 0.4)
			Art.crystal(ci, Vector2(-3, -4), 11, 3, -0.5, Art.shade_of(_c("hc2"), k), 1.8)
			Art.crystal(ci, Vector2(3, -4), 8, 2.6, 0.3, Art.shade_of(_c("hc2"), k + 0.1), 1.8)
		_:
			Art.t_rect(ci, Rect2(-4.5, -3, 9, 19), 4.5, c, 2.2, 0.0)
	Art.push(ci, Vector2(0, ARM_LEN))
	Art.t_circle(ci, Vector2.ZERO, 5.0, g, 2.2, 0.0)
	Art.pop(ci)


static var _CLAW := PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(6, 5), Vector2(3, 3), Vector2(1, 6), Vector2(-1, 6), Vector2(-3, 3), Vector2(-6, 5)])
static var _ROCK_ARM := PackedVector2Array([Vector2(-6, -5), Vector2(6, -6), Vector2(7, 8), Vector2(5, 16), Vector2(-5, 16), Vector2(-7, 6)])
static var _ROCK_FIST := PackedVector2Array([Vector2(-7, -5), Vector2(6, -6), Vector2(9, 1), Vector2(6, 7), Vector2(-5, 7), Vector2(-8, 1)])


# --- Tools ----------------------------------------------------------------------------

static func _tool(ci: CanvasItem, tool: String, angle: float, wrist: float, hit: float, t: float, arm: String) -> void:
	var hand := _shoulder(true) + Vector2(sin(angle), cos(angle)) * ARM_LEN
	if tool in THRUST:
		var u := fposmod(hit, 1.0) if arm == "dig" else lerpf(0.5, Chars.DIG_IMPACT, clampf(hit, 0.0, 1.0))
		var on := arm != "show" and u >= Chars.DIG_IMPACT - 0.02 and u < 0.9
		Art.push(ci, hand, 0.0)
		match tool:
			"drill":
				Chars._drill(ci, 3, t, on)
			"trident":
				Chars._trident(ci, t, on)
			_:
				_gun(ci, tool, t, on)
		Art.pop(ci)
		return
	Art.push(ci, hand, -angle + wrist)
	var key := _k(6)
	if not Art.cache_begin(ci, key):
		_swing_tool(ci, tool)
		Art.cache_end(ci, key)
	Art.pop(ci)
	if tool == "staff" and not Chars._small:
		var tip := hand + Vector2(0, 34).rotated(-angle + wrist)
		Art.dot(ci, tip, 7.0 + sin(t * 4.0) * 1.5, Color(_c("orb"), 0.3))


## A swung tool in hand space: the fist at 0,0, the handle along +y, the
## striking end around y = 30 (as Chars._pick).
static func _swing_tool(ci: CanvasItem, tool: String) -> void:
	var tc := _c("tc")
	var th := _c("th")
	match tool:
		"hammer":
			Art.t_rect(ci, Rect2(-2.8, -7, 5.6, 36), 2.8, th, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-15, 23, 27, 14), 4, tc, 2.2, 0.4)
			Art.t_rect(ci, Rect2(-13, 24, 3.5, 12), 1, Art.shade_of(tc, 0.3), 0.0, 0.0)
			Art.t_rect(ci, Rect2(6.5, 24, 3.5, 12), 1, Art.shade_of(tc, 0.3), 0.0, 0.0)
		"anchor":
			Art.t_rect(ci, Rect2(-2.6, -8, 5.2, 40), 2.4, tc, 1.8, 0.0)
			Art.t_rect(ci, Rect2(-9, -2, 18, 4.5), 2, tc, 1.8, 0.0)
			Art.arc_c(ci, Vector2(0, -10), 4.0, 0, TAU, 12, Art.INK, 4.5)
			Art.arc_c(ci, Vector2(0, -10), 4.0, 0, TAU, 12, tc, 2.0)
			Art.toon(ci, _ANCHOR_HOOK, tc, 2.0, 0.3)
		"sword":
			Art.t_rect(ci, Rect2(-2.5, -6, 5, 10), 2, Color("6a3a20"), 1.6, 0.0)
			Art.t_rect(ci, Rect2(-9, 3, 18, 4.5), 2, Art.GOLD, 1.8, 0.0)
			Art.toon(ci, _BLADE_SWORD, tc, 2.0, 0.0)
			Art.line_c(ci, PackedVector2Array([Vector2(-0.8, 9), Vector2(-0.8, 34)]), Color(1, 1, 1, 0.6), 1.4)
		"staff":
			Art.t_rect(ci, Rect2(-2.4, -14, 4.8, 44), 2.4, th, 1.8, 0.0)
			_orb(ci, Vector2(0, 34))
		_:
			Art.t_rect(ci, Rect2(-2.6, -6, 5.2, 38), 2.6, th, 1.8, 0.0)
			Art.toon(ci, Chars._PICK_HEAD, tc, 2.0, 0.4)
			Art.line_c(ci, PackedVector2Array([Vector2(-14, 27.6), Vector2(-4, 27.8)]), Color(1, 1, 1, 0.65), 1.4)
			Art.t_rect(ci, Rect2(-4, 25.5, 8, 10), 2, Art.shade_of(tc, 0.25), 1.6, 0.0)


static var _ANCHOR_HOOK := Art.smooth_pts(PackedVector2Array([Vector2(-15, 22), Vector2(-11, 30), Vector2(0, 35), Vector2(11, 30), Vector2(15, 22),
		Vector2(17, 27), Vector2(10, 37), Vector2(0, 40), Vector2(-10, 37), Vector2(-17, 27)]), 2)
static var _BLADE_SWORD := PackedVector2Array([Vector2(-3.5, 7), Vector2(3.5, 7), Vector2(3.5, 34), Vector2(0, 40), Vector2(-3.5, 34)])


static func _orb(ci: CanvasItem, c: Vector2) -> void:
	var orb := _c("orb")
	match _sp["orb_shape"]:
		"flask":
			Art.toon(ci, Art.moved(_FLASK, c), Color("dff8ff"), 2.0, 0.0)
			Art.flat(ci, Art.moved(_FLASK_IN, c), orb)
			Art.disc(ci, c + Vector2(-2, 4), 1.4, Color(1, 1, 1, 0.8))
		"star":
			Art.toon(ci, Art.star_pts(c + Vector2(0, 3), 9.0, 4.0, 5, PI / 2.0), orb, 2.0, 0.4)
		"lantern":
			Art.t_rect(ci, Rect2(c.x - 6, c.y - 2, 12, 13), 3, Color(orb, 0.9), 2.0, 0.0)
			Art.t_rect(ci, Rect2(c.x - 7, c.y - 4, 14, 3), 1, Color("6a5a3a"), 1.6, 0.0)
			Art.t_rect(ci, Rect2(c.x - 7, c.y + 10, 14, 3), 1, Color("6a5a3a"), 1.6, 0.0)
			Art.disc(ci, c + Vector2(0, 5), 2.6, Color.WHITE)
		_:
			Art.t_circle(ci, c + Vector2(0, 2), 7.0, orb, 2.0, 0.5)
			Art.flat(ci, Art.ellipse_pts(c + Vector2(-2, -0.5), Vector2(2, 1.4), 8, -0.5), Color(1, 1, 1, 0.8))
			Art.t_rect(ci, Rect2(c.x - 4.5, c.y - 6, 9, 3), 1, Art.GOLD, 1.4, 0.0)


static var _FLASK := PackedVector2Array([Vector2(-2.5, -6), Vector2(2.5, -6), Vector2(2.5, -1), Vector2(8, 8), Vector2(5, 12), Vector2(-5, 12), Vector2(-8, 8), Vector2(-2.5, -1)])
static var _FLASK_IN := PackedVector2Array([Vector2(-5.5, 5), Vector2(5.5, 5), Vector2(7, 8), Vector2(4.5, 11), Vector2(-4.5, 11), Vector2(-7, 8)])


## Held level, pointing forward (like Chars._laser): the sprayer and the laser.
static func _gun(ci: CanvasItem, tool: String, t: float, on: bool) -> void:
	var glow := _c("tc")
	var key := _k(7, int(on))
	if not Art.cache_begin(ci, key):
		Art.t_rect(ci, Rect2(-3.5, -6, 7, 12), 3, Color("2a2f45"), 1.8, 0.0)
		if tool == "sprayer":
			Art.t_rect(ci, Rect2(-8, -16, 24, 12), 5, _c("suit2"), 2.2, 0.5)
			Art.t_rect(ci, Rect2(14, -13, 16, 5), 2, Color("8a94a8"), 1.8, 0.0)
			Art.t_circle(ci, Vector2(2, -19), 4.5, Color(glow, 0.9), 1.8, 0.0)
		else:
			Art.toon(ci, Chars._LASER_BODY, Color("e9eef6"), 2.2, 0.5)
			Art.t_rect(ci, Rect2(2, -12.5, 16, 2.6), 1, glow, 0.0, 0.0)
			Art.t_rect(ci, Rect2(26, -13.5, 5, 9), 2, Color("2a2f45"), 1.8, 0.0)
		Art.cache_end(ci, key)
	if on:
		var pulse := 0.5 + 0.5 * sin(t * 30.0)
		if tool == "sprayer":
			for k in 4:
				var f := fposmod(t * 3.0 + k * 0.25, 1.0)
				Art.dot(ci, Vector2(31 + f * 22.0, -10.5 + sin(k * 2.0) * f * 6.0), 2.0 + f * 3.0, Color(glow, 0.8 * (1.0 - f * 0.6)))
		else:
			Art.flat_now(ci, PackedVector2Array([Vector2(31, -11.5), Vector2(53, -10.5), Vector2(53, -7.5), Vector2(31, -6.5)]), Color(glow, 0.55 + 0.2 * pulse))
			Art.line(ci, Vector2(31, -9), Vector2(53, -9), Color(1, 1, 1, 0.95), 1.6)
			Art.dot(ci, Vector2(53, -9), 5.0 + pulse * 3.0, Color(glow, 0.45))


# --- Heads ----------------------------------------------------------------------------

## Head center and radius of each head kind (things on top use them).
static func _head_box() -> Array:
	match _sp["head"]:
		"kid", "lamp":
			return [Vector2(3, -68), 18.0]
		"astro", "brass", "heat", "hazmat":
			return [Vector2(2, -70), 21.0]
		"robot":
			return [Vector2(3, -71), 20.0]
		"knight":
			return [Vector2(2, -71), 21.0]
		"dome":
			return [Vector2(3, -70), 21.0]
		"creature":
			match _sp["cs"]:
				"blob", "ghost":
					return [Vector2(3, -58), 18.0]
				"volcano":
					return [Vector2(3, -66), 20.0]
				"alien":
					return [Vector2(3, -71), 20.0]
			return [Vector2(3, -67), 19.0]
	return [Vector2(2, -69), 20.0]


static func _head(ci: CanvasItem, emotion: String, blink: bool, t: float) -> void:
	var dyn := 0
	if _sp["head"] == "creature" and _sp["cs"] in ["flame", "volcano"]:
		dyn = int(fposmod(t * 2.0, 1.0) * 4.0)
	elif "planet" in (_sp["top"] as Array):
		dyn = roundi(sin(t * 2.0) * 2.0) + 2
	var key := hash([31, _wf, emotion, blink, Chars._small, dyn, Art.fringe_min])
	if Art.cache_begin(ci, key):
		return
	_head_draw(ci, emotion, blink, dyn)
	Art.cache_end(ci, key)


static func _head_draw(ci: CanvasItem, emotion: String, blink: bool, dyn: int) -> void:
	var box := _head_box()
	var c: Vector2 = box[0]
	var r: float = box[1]
	var hc := _c("hc")
	var skin := _c("skin")
	var tops: Array = _sp["top"]
	# Behind the head.
	if "octo_mantle" in tops:
		_top(ci, "octo_mantle", c, r, dyn)
	if "frog_eyes" in tops:
		pass
	match _sp["head"]:
		"kid", "lamp":
			_kid_head(ci, c, emotion, blink)
		"hood", "gasmask":
			Art.t_circle(ci, c, r, hc, 2.6, 0.5)
			var fo := c + Vector2(3, 3)
			Art.flat(ci, Art.ellipse_pts(fo, Vector2(15.2, 15.7), 20), Art.shade_of(hc, 0.25) if _sp.get("hc2", hc) == hc or not ("fox_ears" in tops) else _c("hc2"))
			Art.flat(ci, Art.ellipse_pts(fo, Vector2(13, 13.5), 20), skin)
			_face(ci, fo, 0.6, emotion, blink, skin)
			if _sp.has("mask"):
				_swim_mask(ci, fo, 0.6)
			if _sp["head"] == "gasmask":
				_gasmask(ci, fo)
		"brass":
			Art.t_circle(ci, c, 21, hc, 2.8, 0.7)
			Art.t_rect(ci, Rect2(c.x - 5, c.y - 25, 10, 6), 2, Art.shade_of(hc, 0.25), 2.2, 0.0)
			Art.t_circle(ci, c + Vector2(-17, -1), 5, Art.shade_of(hc, 0.25), 2.0, 0.0)
			var pc := c + Vector2(4, 0)
			Art.t_circle(ci, pc, 14.5, Art.shade_of(hc, 0.35), 2.2, 0.0)
			Art.t_circle(ci, pc, 12, Color("dff8ff"), 0.0, 0.0)
			Art.flat(ci, Art.circle_pts(pc + Vector2(0.5, 1.5), 11.0, 24), skin)
			_face(ci, pc, 0.58, emotion, blink, skin)
			Art.flat(ci, _clip(Art.circle_pts(pc + Vector2(-6, -6), 7, 14), Art.circle_pts(pc, 12, 24)), Color(1, 1, 1, 0.5))
			for b: Vector2 in [Vector2(-15, -6), Vector2(-15, 7), Vector2(19, -6), Vector2(19, 7)]:
				Art.disc(ci, c + b, 1.8, Art.shade_of(hc, 0.45))
		"heat":
			Art.toon(ci, Art.moved(Chars._HEAT_HOOD, c - Vector2(2, -70)), hc, 2.6, 0.6)
			var v := Art.moved(Chars._VISOR, c - Vector2(2, -70))
			Art.toon(ci, v, skin, 2.2, 0.0)
			_face(ci, c + Vector2(4, 2), 0.6, emotion, blink, skin)
			Art.flat(ci, v, Color(1.0, 0.7, 0.2, 0.16))
			Art.flat(ci, _clip(PackedVector2Array([c + Vector2(-10, -14), c + Vector2(-2, -14), c + Vector2(-10, 10), c + Vector2(-16, 10)]), v), Color(1, 0.95, 0.8, 0.5))
			Art.t_rect(ci, Rect2(c.x - 14, c.y - 22, 30, 5), 2, _c("hc2"), 1.6, 0.0)
		"hazmat":
			Art.t_circle(ci, c, 21, hc, 2.6, 0.6)
			var v := Art.rrect_pts(Rect2(c.x - 9, c.y - 12, 28, 25), 10)
			Art.toon(ci, v, skin, 2.4, 0.0)
			_face(ci, c + Vector2(5, 1), 0.6, emotion, blink, skin)
			if _sp.has("goggles"):
				_goggles(ci, c + Vector2(5, 1), 0.6)
			Art.flat(ci, v, Color(0.75, 1.0, 0.85, 0.22))
			Art.flat(ci, _clip(Art.ellipse_pts(c + Vector2(-3, -8), Vector2(4, 7), 10, 0.5), v), Color(1, 1, 1, 0.55))
			Art.ring(ci, v, _c("hc2"), 2.0)
			Art.t_circle(ci, c + Vector2(-17, 2), 4.5, _c("hc2"), 1.8, 0.0)
		"astro":
			Art.t_circle(ci, c, 22, hc, 2.8, 0.6)
			Art.t_circle(ci, c + Vector2(-18, 1), 5.5, _c("hc2"), 2.0, 0.0)
			var v := Art.ellipse_pts(c + Vector2(4, 1), Vector2(16, 13.5), 24)
			Art.toon(ci, v, Color("1a1f3a"), 2.4, 0.0)
			_screen_face(ci, c + Vector2(4, 1), 0.62, emotion, blink, _c("eye"))
			Art.flat(ci, _clip(Art.ellipse_pts(c + Vector2(-5, -7), Vector2(4, 6), 10, 0.6), v), Color(1, 1, 1, 0.35))
		"robot":
			var hr := Art.rrect_pts(Rect2(c.x - 18, c.y - 19, 40, 37), 9)
			Art.toon(ci, hr, hc, 2.8, 0.6)
			Art.t_circle(ci, c + Vector2(-19, 1), 5, _c("hc2"), 2.0, 0.0)
			var v := Art.rrect_pts(Rect2(c.x - 9, c.y - 13, 29, 24), 6)
			Art.toon(ci, v, Color("1a1f3a"), 2.2, 0.0)
			_screen_face(ci, c + Vector2(5.5, -1), 0.6, emotion, blink, _c("eye"))
			Art.flat(ci, _clip(PackedVector2Array([c + Vector2(-9, 4), c + Vector2(-9, -2), c + Vector2(2, -13), c + Vector2(8, -13)]), v), Color(1, 1, 1, 0.2))
		"knight":
			Art.t_circle(ci, c, 21, hc, 2.8, 0.6)
			var o := Art.ellipse_pts(c + Vector2(6, 4), Vector2(12.5, 13), 20)
			Art.toon(ci, o, skin, 2.0, 0.0)
			_face(ci, c + Vector2(6, 4), 0.6, emotion, blink, skin)
			Art.t_rect(ci, Rect2(c.x - 6, c.y - 15, 29, 5.5), 2.5, _c("hc2"), 1.6, 0.0)
			Art.toon(ci, PackedVector2Array([c + Vector2(-15, 2), c + Vector2(-8, 4), c + Vector2(-7, 17), c + Vector2(-14, 14)]), Art.shade_of(hc, 0.2), 1.6, 0.0)
			Art.arc_c(ci, c, 20.5, PI * 1.05, PI * 1.4, 5, Color(1, 1, 1, 0.55), 2.2)
		"dome":
			Art.t_circle(ci, c + Vector2(1, 2), 15, hc, 2.2, 0.4)
			_alien_face(ci, c + Vector2(4, 3), 0.62, emotion, blink)
			Art.flat(ci, Art.circle_pts(c, 21.5, 24), Color(0.8, 0.95, 1.0, 0.18))
			Art.arc_c(ci, c, 21.5, 0, TAU, 24, Art.INK, 2.6)
			Art.arc_c(ci, c, 18.5, PI * 1.05, PI * 1.45, 5, Color(1, 1, 1, 0.8), 2.6)
		"creature":
			_creature_head(ci, c, r, emotion, blink, dyn)
	for tp: String in tops:
		if tp != "octo_mantle":
			_top(ci, tp, c, r, dyn)


static func _kid_head(ci: CanvasItem, c: Vector2, emotion: String, blink: bool) -> void:
	var skin := SKIN
	var hc := _c("hair_c")
	var hair: String = _sp["hair"]
	Art.push(ci, c, 0.0, Vector2(0.9, 0.9))
	if hair == "long":
		Art.t_rect(ci, Rect2(-23, -16, 46, 44), 18, hc, 2.5, 0.6)
	for sx: float in [-1.0, 1.0]:
		Art.t_circle(ci, Vector2(19.5 * sx, 3), 5.0, skin, 2.2, 0.0)
	Art.toon(ci, Art.ellipse_pts(Vector2.ZERO, Vector2(20, 19.5), 32), skin, 2.5, 0.55)
	Art.pop(ci)
	_face(ci, c + Vector2(1, 1), 0.82, emotion, blink, skin)
	if _sp.has("beard"):
		Art.push(ci, c + Vector2(1, 1), 0.0, Vector2(0.82, 0.82))
		var beard := Art.smooth_pts(PackedVector2Array([Vector2(-19, 3), Vector2(-15, 17), Vector2(-7, 27), Vector2(0, 31),
				Vector2(7, 27), Vector2(15, 17), Vector2(19, 3), Vector2(13, 10), Vector2(6, 9.5), Vector2(0.5, 9), Vector2(-5, 9.5), Vector2(-13, 10)]), 3)
		Art.toon(ci, beard, _c("beard"), 2.2, 0.5)
		Art.toon(ci, PackedVector2Array([Vector2(-4, 11.5), Vector2(4.5, 11.5), Vector2(3, 14.5), Vector2(0.5, 15.5), Vector2(-2.5, 14.5)]), Color("7a1f33"), 1.2, 0.0)
		Art.pop(ci)
	var tops: Array = _sp["top"]
	var covered: bool = _sp["head"] == "lamp" or "mushroom_cap" in tops or "dwarf_helm" in tops or "wizard_crown" in tops or "alch_hat" in tops or "jelly_bell" in tops
	if hair != "bald" and not covered:
		Art.push(ci, c, 0.0, Vector2(0.9, 0.9))
		Chars._hair_front(ci, hair, hc)
		Art.pop(ci)
	elif covered and hair != "bald":
		Art.push(ci, c, 0.0, Vector2(0.9, 0.9))
		Art.toon(ci, PackedVector2Array([Vector2(-20, -4), Vector2(-17, -12), Vector2(-12, -8), Vector2(-14, 2)]), hc, 1.8, 0.0)
		Art.toon(ci, PackedVector2Array([Vector2(20, -4), Vector2(17, -12), Vector2(12, -8), Vector2(14, 2)]), hc, 1.8, 0.0)
		Art.pop(ci)
	if _sp.has("mask"):
		_swim_mask(ci, c + Vector2(1, 1), 0.82)
	if _sp["head"] == "lamp":
		_hard_hat(ci, c)


## Swim mask over the eyes (face space of `s`), with a snorkel or a regulator.
static func _swim_mask(ci: CanvasItem, fc: Vector2, s: float) -> void:
	var rim := _c("mask")
	Art.push(ci, fc, 0.0, Vector2(s, s))
	if _sp.get("snorkel", false):
		Art.stroke(ci, PackedVector2Array([Vector2(-2, 13), Vector2(-12, 14), Vector2(-21, 6), Vector2(-24, -10), Vector2(-24, -30)]), Color("3aa6f0"), 4.5, 2.2)
		Art.t_rect(ci, Rect2(-28, -38, 8, 9), 3, Color("ff6f61"), 2.0, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-22, 0), Vector2(-14, 1)]), Art.INK, 4.0)
	Art.line_c(ci, PackedVector2Array([Vector2(14, 1), Vector2(22, 0)]), Art.INK, 4.0)
	var m := Art.rrect_pts(Rect2(-15, -6.5, 30, 15), 6.5)
	Art.ring(ci, m, Art.INK, 6.0)
	Art.ring(ci, m, rim, 3.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-13, -4.5, 26, 11), 4.5), Color(0.75, 0.95, 1.0, 0.28))
	Art.flat(ci, Art.rrect_pts(Rect2(-11, -3.5, 5, 3), 1.5), Color(1, 1, 1, 0.7))
	if _sp.get("reg", false) or _sp.get("snorkel", false):
		Art.t_rect(ci, Rect2(-4, 10, 9, 6), 2.5, Color("3a3f5c"), 1.6, 0.0)
	Art.pop(ci)
	if _sp.get("reg", false):
		Art.line_c(ci, PackedVector2Array([fc + Vector2(-2, 12), fc + Vector2(-10, 15), fc + Vector2(-20, 14)]), Art.INK, 5.2)
		Art.line_c(ci, PackedVector2Array([fc + Vector2(-2, 12), fc + Vector2(-10, 15), fc + Vector2(-20, 14)]), Color("3a3f5c"), 2.4)


static func _hard_hat(ci: CanvasItem, c: Vector2) -> void:
	var hc := _c("hc")
	Art.push(ci, c, 0.0, Vector2(0.9, 0.9))
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(Vector2(cos(a) * 22.5, -8.0 + sin(a) * 19.0))
	Art.toon(ci, dome, hc, 2.5, 0.6)
	Art.t_rect(ci, Rect2(-27, -11, 54, 7), 3.5, Art.shade_of(hc, 0.25), 2.5, 0.0)
	Art.t_rect(ci, Rect2(-3, -27, 6, 18), 3, Art.shade_of(hc, 0.4), 0.0, 0.0)
	# The lamp: a brass ring and a bright glass.
	Art.t_circle(ci, Vector2(4, -20), 8.0, Color("d19230"), 2.2, 0.0)
	Art.t_circle(ci, Vector2(4, -20), 5.5, Color("fff6c2"), 1.4, 0.0)
	Art.flat(ci, Art.circle_pts(Vector2(2.5, -21.5), 2.0, 8), Color.WHITE)
	Art.pop(ci)


static func _face(ci: CanvasItem, at: Vector2, s: float, emotion: String, blink: bool, skin: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Chars._face_draw(ci, emotion, blink, skin)
	if _sp.get("eyepatch", false):
		Art.line_c(ci, PackedVector2Array([Vector2(-19, -9), Vector2(-3, 4)]), Art.INK, 1.8)
		Art.t_ellipse(ci, Vector2(-7, 1.5), Vector2(5.2, 5.6), Color("2a2240"), 1.2, 0.0)
	Art.pop(ci)


static func _goggles(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	for sx: float in [-1.0, 1.0]:
		Art.arc_c(ci, Vector2(7 * sx, 1.5), 6.6, 0, TAU, 16, Art.INK, 4.0)
		Art.arc_c(ci, Vector2(7 * sx, 1.5), 6.6, 0, TAU, 16, _c("goggles"), 2.2)
		Art.flat(ci, Art.circle_pts(Vector2(7 * sx, 1.5), 5.6, 14), Color(0.7, 1.0, 0.7, 0.2))
	Art.line_c(ci, PackedVector2Array([Vector2(-1, 0.5), Vector2(1, 0.5)]), Art.INK, 2.4)
	Art.pop(ci)


static func _gasmask(ci: CanvasItem, fo: Vector2) -> void:
	Art.push(ci, fo, 0.0, Vector2(0.6, 0.6))
	for sx: float in [-1.0, 1.0]:
		Art.arc_c(ci, Vector2(7 * sx, 1.5), 7.0, 0, TAU, 16, Art.INK, 4.5)
		Art.arc_c(ci, Vector2(7 * sx, 1.5), 7.0, 0, TAU, 16, Color("5a5f4a"), 2.5)
		Art.flat(ci, Art.circle_pts(Vector2(7 * sx, 1.5), 6.0, 14), Color(0.8, 1.0, 0.7, 0.25))
	Art.toon(ci, _GAS_SNOUT, Color("5a5f4a"), 2.4, 0.4)
	Art.t_circle(ci, Vector2(1, 20), 7.5, Color("8a9a5a"), 2.4, 0.3)
	for i in 3:
		Art.line_c(ci, PackedVector2Array([Vector2(-3 + i * 3, 16), Vector2(-3 + i * 3, 24)]), Color("4a4f3a"), 1.4)
	Art.pop(ci)


static var _GAS_SNOUT := Art.smooth_pts(PackedVector2Array([Vector2(-10, 7), Vector2(11, 7), Vector2(12, 15), Vector2(6, 22), Vector2(-4, 22), Vector2(-10, 15)]), 2)


## A face of light on a dark visor or screen (face space radius 20 at `s`).
static func _screen_face(ci: CanvasItem, at: Vector2, s: float, emotion: String, blink: bool, col: Color) -> void:
	var e: Array = Chars.EMOTIONS.get(emotion, Chars.EMOTIONS["happy"])
	var eyes: String = e[0]
	var mouth: String = e[1]
	var brows: String = e[2]
	if blink and eyes in ["open", "wide", "narrow", "star"]:
		eyes = "closed"
	Art.push(ci, at, 0.0, Vector2(s, s))
	if not Chars._small:
		Art.dot(ci, Vector2(-8, -1), 10.0, Color(col, 0.18))
		Art.dot(ci, Vector2(8, -1), 10.0, Color(col, 0.18))
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(8.0 * sx, -1.0)
		match eyes:
			"open":
				Art.flat(ci, Art.ellipse_pts(c, Vector2(3.6, 5.0), 12), col)
				Art.flat(ci, Art.circle_pts(c + Vector2(-1.2, -1.8), 1.3, 6), Color(1, 1, 1, 0.9))
			"wide":
				Art.flat(ci, Art.circle_pts(c, 5.6, 14), col)
				Art.flat(ci, Art.circle_pts(c + Vector2(-1.6, -2), 1.8, 8), Color(1, 1, 1, 0.9))
			"narrow":
				Art.flat(ci, Art.rrect_pts(Rect2(c.x - 4.5, c.y - 0.5, 9, 4), 2), col)
			"arc":
				Art.arc_c(ci, c + Vector2(0, 3.0), 4.5, PI + 0.3, TAU - 0.3, 8, col, 3.2)
			"closed":
				Art.arc_c(ci, c + Vector2(0, -1.5), 4.5, 0.3, PI - 0.3, 8, col, 3.0)
			"x":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-3.5 * sx, -3.5), c + Vector2(3.5 * sx, 0), c + Vector2(-3.5 * sx, 3.5)]), col, 2.6)
			"star":
				Art.flat(ci, Art.star_pts(c, 6.0, 2.6, 4), col)
		match brows:
			"angry":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-4 * sx, -9), c + Vector2(4 * sx, -6)]), col, 2.2)
			"worried":
				Art.line_c(ci, PackedVector2Array([c + Vector2(-4 * sx, -6), c + Vector2(4 * sx, -9)]), col, 2.2)
	var m := Vector2(0, 9)
	if _sp.get("cat", false):
		Art.arc_c(ci, m + Vector2(-2.5, -1), 2.6, 0.2, PI - 0.2, 6, col, 1.8)
		Art.arc_c(ci, m + Vector2(2.5, -1), 2.6, 0.2, PI - 0.2, 6, col, 1.8)
		for sy: float in [-1.0, 1.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(13, 5 + sy * 2), Vector2(19, 4 + sy * 4)]), Color(col, 0.7), 1.2)
			Art.line_c(ci, PackedVector2Array([Vector2(-13, 5 + sy * 2), Vector2(-19, 4 + sy * 4)]), Color(col, 0.7), 1.2)
	else:
		match mouth:
			"grin":
				Art.flat(ci, PackedVector2Array([m + Vector2(-5, -1.5), m + Vector2(5, -1.5), m + Vector2(3, 2.5), m + Vector2(-3, 2.5)]), col)
			"o":
				Art.arc_c(ci, m + Vector2(0, 0.5), 2.6, 0, TAU, 10, col, 1.8)
			"flat", "wavy", "tongue":
				Art.line_c(ci, PackedVector2Array([m + Vector2(-3, 0), m + Vector2(3, 0)]), col, 1.8)
			"frown":
				Art.arc_c(ci, m + Vector2(0, 3), 3.5, PI + 0.5, TAU - 0.5, 6, col, 1.8)
			_:
				Art.arc_c(ci, m + Vector2(0, -2.5), 4.0, 0.5, PI - 0.5, 6, col, 1.8)
	Art.pop(ci)


## Big glossy alien eyes (the antenna alien and the octo-alien in its dome).
static func _alien_face(ci: CanvasItem, at: Vector2, s: float, emotion: String, blink: bool) -> void:
	var e: Array = Chars.EMOTIONS.get(emotion, Chars.EMOTIONS["happy"])
	var eyes: String = e[0]
	var mouth: String = e[1]
	if blink and eyes in ["open", "wide", "narrow", "star"]:
		eyes = "closed"
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.flat(ci, Art.ellipse_pts(Vector2(-12, 9), Vector2(3.5, 2.2), 10), Color(1.0, 0.45, 0.6, 0.4))
	Art.flat(ci, Art.ellipse_pts(Vector2(12, 9), Vector2(3.5, 2.2), 10), Color(1.0, 0.45, 0.6, 0.4))
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(7.5 * sx, -1.0)
		match eyes:
			"open", "wide", "narrow", "x":
				var big := 1.12 if eyes == "wide" else 1.0
				Art.toon(ci, Art.ellipse_pts(c, Vector2(5.4, 7.0) * big, 14, 0.25 * sx), Color("1a1f3a"), 1.4, 0.0)
				Art.flat(ci, Art.circle_pts(c + Vector2(-1.8, -2.8), 1.9, 8), Color.WHITE)
				Art.flat(ci, Art.circle_pts(c + Vector2(1.6, 2.6), 0.9, 6), Color(1, 1, 1, 0.7))
				if eyes == "narrow":
					Art.line_c(ci, PackedVector2Array([c + Vector2(-5.5, -1.5), c + Vector2(5.5, -1.5)]), Art.INK, 2.0)
			"arc":
				Art.arc_c(ci, c + Vector2(0, 3), 4.5, PI + 0.3, TAU - 0.3, 8, Art.INK, 2.6)
			"closed":
				Art.arc_c(ci, c + Vector2(0, -1), 4.5, 0.3, PI - 0.3, 8, Art.INK, 2.4)
			"star":
				Art.toon(ci, Art.star_pts(c, 6.0, 2.6, 5), Art.GOLD, 1.0, 0.0)
	var m := Vector2(0, 11)
	match mouth:
		"grin", "o":
			Art.toon(ci, Art.ellipse_pts(m, Vector2(3.0, 2.4 if mouth == "grin" else 3.0), 10), Color("7a1f33"), 1.2, 0.0)
		"frown":
			Art.arc_c(ci, m + Vector2(0, 3), 3.0, PI + 0.5, TAU - 0.5, 6, Art.INK, 1.8)
		"flat", "wavy":
			Art.line_c(ci, PackedVector2Array([m + Vector2(-2.5, 0), m + Vector2(2.5, 0)]), Art.INK, 1.8)
		_:
			Art.arc_c(ci, m + Vector2(0, -2), 3.2, 0.5, PI - 0.5, 6, Art.INK, 1.8)
	Art.pop(ci)


## Glowing eyes and mouth on a rock or lava head.
static func _glow_face(ci: CanvasItem, at: Vector2, s: float, emotion: String, blink: bool, col: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.flat(ci, Art.ellipse_pts(Vector2(-8, -1), Vector2(6.5, 6), 12), Color(0, 0, 0, 0.45))
	Art.flat(ci, Art.ellipse_pts(Vector2(8, -1), Vector2(6.5, 6), 12), Color(0, 0, 0, 0.45))
	Art.flat(ci, Art.rrect_pts(Rect2(-7, 6, 14, 7), 3), Color(0, 0, 0, 0.45))
	Art.pop(ci)
	_screen_face(ci, at, s, emotion, blink, col)


static func _creature_head(ci: CanvasItem, c: Vector2, r: float, emotion: String, blink: bool, dyn: int) -> void:
	var hc := _c("hc")
	match _sp["cs"]:
		"rock", "moonrock":
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI / 2.0
				var rr := r * (1.0 if i % 2 == 0 else 0.9) * (1.08 if i == 3 else 1.0)
				pts.append(c + Vector2(cos(a) * rr * 1.08, sin(a) * rr))
			Art.toon(ci, pts, hc, 2.8, 0.7)
			if _sp["cs"] == "moonrock":
				for k: Vector2 in [Vector2(-10, -9), Vector2(10, -12), Vector2(-12, 8)]:
					Art.t_circle(ci, c + k, 3.0, Art.shade_of(hc, 0.25), 1.2, 0.0)
			else:
				Art.polyline(ci, PackedVector2Array([c + Vector2(-6, -r), c + Vector2(-3, -12), c + Vector2(-8, -6)]), _c("pc"), 2.0)
			_glow_face(ci, c + Vector2(4, 2), 0.85, emotion, blink, _c("eye"))
		"volcano":
			var cone := PackedVector2Array([c + Vector2(-22, 16), c + Vector2(-15, -14), c + Vector2(-8, -22), c + Vector2(10, -22), c + Vector2(16, -14), c + Vector2(24, 16)])
			Art.toon(ci, Art.smooth_pts(cone, 2), hc, 2.8, 0.7)
			Art.t_ellipse(ci, c + Vector2(1, -21), Vector2(10, 3.5), Color("ff5a1a"), 2.0, 0.0)
			var lava := PackedVector2Array([c + Vector2(-6, -21), c + Vector2(-3, -12 + dyn), c + Vector2(-1, -21), c + Vector2(5, -21), c + Vector2(7, -14), c + Vector2(9, -21)])
			Art.toon(ci, lava, Color("ff8a1a"), 1.6, 0.0)
			# Puffs of smoke and sparks over the crater.
			for k in 2:
				var f := fposmod(dyn / 4.0 + k / 2.0, 1.0)
				Art.dot(ci, c + Vector2(-4 + k * 6 - f * 10.0, -30 - f * 16.0), 4.0 + f * 4.0, Color(0.75, 0.7, 0.75, 0.75 - f * 0.55))
			Art.dot(ci, c + Vector2(1, -24), 9.0, Color(1.0, 0.5, 0.1, 0.35))
			_glow_face(ci, c + Vector2(4, 4), 0.85, emotion, blink, _c("eye"))
		"flame":
			var fl := (dyn % 2) * 2.0
			var flame := Art.smooth_pts(PackedVector2Array([c + Vector2(-17, 8), c + Vector2(-24, -6), c + Vector2(-30, -26 - fl), c + Vector2(-17, -16),
					c + Vector2(-18, -36 + fl), c + Vector2(-8, -22), c + Vector2(0, -44 - fl), c + Vector2(8, -22), c + Vector2(18, -38 + fl),
					c + Vector2(17, -14), c + Vector2(28, -22 - fl), c + Vector2(21, -2), c + Vector2(18, 8), c + Vector2(4, 18), c + Vector2(-10, 16)]), 2)
			Art.toon(ci, flame, hc, 2.6, 0.0)
			Art.flat(ci, _clip(Art.ellipse_pts(c + Vector2(1, 4), Vector2(15, 16), 18), flame), _c("hc2"))
			_face(ci, c + Vector2(3, 3), 0.7, emotion, blink, _c("hc2"))
		"alien":
			var hd := Art.smooth_pts(PackedVector2Array([c + Vector2(-18, -6), c + Vector2(-14, -20), c + Vector2(2, -26), c + Vector2(18, -20),
					c + Vector2(22, -4), c + Vector2(14, 12), c + Vector2(3, 18), c + Vector2(-10, 13)]), 3)
			Art.toon(ci, hd, hc, 2.6, 0.6)
			_alien_face(ci, c + Vector2(3, 0), 0.8, emotion, blink)
		"blob", "ghost":
			_face(ci, c + Vector2(4, 6), 0.9, emotion, blink, _c("skin"))


## Things on (or behind) the head, around its center `c` and radius `r`.
static func _top(ci: CanvasItem, kind: String, c: Vector2, r: float, dyn: int) -> void:
	var hc := _c("hc")
	var hc2 := _c("hc2")
	var top := c + Vector2(0, -r)
	match kind:
		"antenna":
			Art.line_c(ci, PackedVector2Array([c + Vector2(-9, -r + 3), c + Vector2(-13, -r - 10)]), Art.INK, 3.6)
			Art.line_c(ci, PackedVector2Array([c + Vector2(-9, -r + 3), c + Vector2(-13, -r - 10)]), Color("b8c4d8"), 1.6)
			Art.t_circle(ci, c + Vector2(-13, -r - 12), 3.5, _c("eye"), 1.8, 0.0)
		"tv_antennae":
			for sx: float in [-1.0, 1.0]:
				var tip := top + Vector2(-2 + sx * 12, -14)
				Art.line_c(ci, PackedVector2Array([top + Vector2(-2, 2), tip]), Art.INK, 3.4)
				Art.line_c(ci, PackedVector2Array([top + Vector2(-2, 2), tip]), Color("b8c4d8"), 1.4)
				Art.t_circle(ci, tip, 3.0, hc2, 1.6, 0.0)
			Art.t_rect(ci, Rect2(top.x - 7, top.y - 2, 10, 4), 2, Art.shade_of(hc, 0.3), 1.6, 0.0)
		"beacon":
			Art.t_rect(ci, Rect2(top.x - 6, top.y - 3, 12, 5), 2, Color("4a5068"), 1.8, 0.0)
			Art.toon(ci, Art.rrect_pts(Rect2(top.x - 4.5, top.y - 11, 9, 9), 4), Color("ff7a2a"), 1.8, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(top.x - 2.5, top.y - 9.5, 2.5, 5), 1), Color(1, 1, 1, 0.7))
		"dome_light":
			Art.t_rect(ci, Rect2(top.x - 6, top.y - 3, 12, 5), 2, Color("4a5068"), 1.8, 0.0)
			Art.t_circle(ci, top + Vector2(0, -5), 5.0, Color(_c("eye"), 0.9), 1.8, 0.0)
			Art.flat(ci, Art.circle_pts(top + Vector2(-1.5, -6.5), 1.5, 6), Color(1, 1, 1, 0.8))
		"neon_crest":
			var fin := Art.smooth_pts(PackedVector2Array([c + Vector2(-20, -4), c + Vector2(-26, -16), c + Vector2(-22, -30), c + Vector2(-8, -36),
					c + Vector2(6, -32), c + Vector2(12, -22), c + Vector2(2, -24), c + Vector2(-8, -18), c + Vector2(-14, -8)]), 2)
			Art.toon(ci, fin, _c("pc"), 2.2, 0.3)
			for k in 3:
				Art.line_c(ci, PackedVector2Array([c + Vector2(-16 + k * 7, -14 - k * 2), c + Vector2(-20 + k * 8, -28 - k)]), Art.shade_of(_c("pc"), 0.3), 1.4)
		"shark_fin":
			Art.toon(ci, PackedVector2Array([c + Vector2(-14, -12), c + Vector2(-16, -34), c + Vector2(-8, -30), c + Vector2(2, -18)]), hc, 2.4, 0.4)
			for k in 3:
				Art.line_c(ci, PackedVector2Array([c + Vector2(-17 + k * 2.5, -2), c + Vector2(-15 + k * 2.5, 8)]), Art.shade_of(hc, 0.4), 1.4)
		"teeth":
			for k in 5:
				var a := PI * 1.2 + k * PI * 0.15
				var p := c + Vector2(3, 3) + Vector2(cos(a), sin(a)) * 14.5
				var d := (c + Vector2(3, 3) - p).normalized()
				Art.toon(ci, PackedVector2Array([p + d.orthogonal() * 2.4, p - d.orthogonal() * 2.4, p + d * 4.5]), Color.WHITE, 1.2, 0.0)
		"octo_mantle":
			var m := Art.smooth_pts(PackedVector2Array([c + Vector2(-14, 8), c + Vector2(-30, -6), c + Vector2(-36, -26), c + Vector2(-26, -42),
					c + Vector2(-8, -44), c + Vector2(8, -32), c + Vector2(14, -14)]), 3)
			Art.toon(ci, m, hc, 2.6, 0.7)
			for k: Array in [[Vector2(-22, -30), 4.0], [Vector2(-10, -36), 3.0], [Vector2(-28, -14), 3.2], [Vector2(-16, -20), 2.4]]:
				Art.flat(ci, Art.circle_pts(c + (k[0] as Vector2), k[1], 10), hc2)
		"coral_crest":
			for b: Array in [[Vector2(-4, -18), Vector2(-8, -32), Vector2(-14, -36)], [Vector2(0, -19), Vector2(2, -34), Vector2(8, -40)], [Vector2(-8, -15), Vector2(-16, -24), Vector2(-22, -24)]]:
				var pts := PackedVector2Array()
				for v: Vector2 in b:
					pts.append(c + v)
				Art.stroke(ci, pts, Color("ff5d73"), 4.0, 2.0)
				Art.t_circle(ci, pts[2], 2.6, Color("ffa84a"), 1.4, 0.0)
			Art.stroke(ci, PackedVector2Array([c + Vector2(-8, -32), c + Vector2(-2, -38)]), Color("ff5d73"), 3.0, 2.0)
		"jelly_bell":
			var bell := Art.smooth_pts(PackedVector2Array([c + Vector2(-25, -2), c + Vector2(-23, -18), c + Vector2(-10, -30), c + Vector2(6, -31),
					c + Vector2(21, -21), c + Vector2(26, -4), c + Vector2(19, -6), c + Vector2(13, -2), c + Vector2(6, -6), c + Vector2(-2, -2),
					c + Vector2(-9, -6), c + Vector2(-17, -2)]), 3)
			Art.toon(ci, bell, Color(hc, 0.88), 2.4, 0.6)
			for k: Vector2 in [Vector2(-12, -18), Vector2(0, -24), Vector2(12, -18), Vector2(-4, -12)]:
				Art.disc(ci, c + k, 2.2, Color(1, 1, 1, 0.75))
		"tricorn":
			Art.push(ci, c + Vector2(0, -3), 0.0, Vector2(r / 20.0, r / 20.0))
			Chars._hat(ci, "pirate")
			Art.pop(ci)
		"starfish":
			Art.toon(ci, Art.star_pts(c + Vector2(-12, -14), 6.5, 3.0, 5, -1.2), Color("ff9a5a"), 1.8, 0.0)
		"horns":
			for sx: float in [-1.0, 1.0]:
				var base := c + Vector2(-2 + sx * 9, -r + 5)
				var pts := _curl(base, -PI / 2.0 - 0.3 + sx * 0.15, 15, -0.9, 5)
				Art.toon(ci, _taper(pts, 6.5, 1.0), hc2 if sx > 0 else Art.shade_of(hc2, 0.25), 2.0, 0.0)
		"side_fins":
			for sx: float in [-1.0, 1.0]:
				var b := c + Vector2(sx * (r - 1) + 1, -2)
				Art.toon(ci, PackedVector2Array([b + Vector2(0, -6), b + Vector2(sx * 10, -12), b + Vector2(sx * 8, -4), b + Vector2(sx * 12, 0), b + Vector2(0, 5)]), hc2, 1.8, 0.0)
		"spikes":
			for k in 4:
				var a := PI * 1.1 + k * 0.32
				var p := c + Vector2(cos(a), sin(a)) * (r - 1)
				var d := Vector2(cos(a), sin(a))
				Art.toon(ci, PackedVector2Array([p + d.orthogonal() * 3.5, p + d * 8.0, p - d.orthogonal() * 3.5]), hc2, 1.8, 0.0)
		"crown":
			if _sp["cs"] == "flame" and _sp["head"] == "creature":
				Art.push(ci, c + Vector2(0, -r + 14), 0.0, Vector2(0.72, 0.72))
			else:
				Art.push(ci, c + Vector2(-1, -r + 16), 0.0, Vector2(0.85, 0.85))
			Chars._hat(ci, "crown")
			Art.pop(ci)
		"crown_spikes":
			var pts := PackedVector2Array([top + Vector2(-15, 6), top + Vector2(-17, -10), top + Vector2(-10, -4), top + Vector2(-6, -18),
					top + Vector2(0, -6), top + Vector2(6, -22), top + Vector2(10, -6), top + Vector2(16, -18), top + Vector2(18, -4),
					top + Vector2(22, -10), top + Vector2(19, 6)])
			Art.toon(ci, pts, Color("f2b632"), 2.4, 0.6)
			Art.t_rect(ci, Rect2(top.x - 15, top.y + 1, 34, 5), 2, Color("c07a1c"), 0.0, 0.0)
			Art.t_circle(ci, top + Vector2(2, 0), 3.0, Color("4de8ff"), 1.4, 0.0)
		"frills":
			for sx: float in [-1.0, 1.0]:
				for k in 3:
					var b := c + Vector2(sx * (r - 2), -6 + k * 7)
					var pts := _curl(b, (0.0 if sx > 0 else PI) - sx * (0.6 - k * 0.5), 10, 0.0, 3)
					Art.toon(ci, _taper(pts, 5, 2.5), hc2, 1.8, 0.0)
		"head_spots":
			for k: Vector2 in [Vector2(-12, -10), Vector2(-4, -17), Vector2(-15, 2)]:
				Art.flat(ci, Art.circle_pts(c + k, 2.4, 10), _c("pc"))
		"plume":
			var pts := Art.smooth_pts(PackedVector2Array([top + Vector2(-2, 4), top + Vector2(-6, -10), top + Vector2(-18, -16), top + Vector2(-30, -6),
					top + Vector2(-26, 2), top + Vector2(-18, -6), top + Vector2(-10, 0)]), 2)
			Art.toon(ci, pts, Color("ff7a2a"), 2.2, 0.0)
			Art.flat(ci, _clip(Art.ellipse_pts(top + Vector2(-12, -6), Vector2(6, 3), 10, 0.3), pts), Color("ffd23f"))
			Art.t_rect(ci, Rect2(top.x - 4, top.y - 1, 8, 6), 2, hc2, 1.6, 0.0)
		"fox_ears":
			for sx: float in [-1.0, 1.0]:
				var b := c + Vector2(-1 + sx * 9, -r + 4)
				var tip := b + Vector2(sx * 6 - 2, -15)
				Art.toon(ci, PackedVector2Array([b + Vector2(-7, 2), tip, b + Vector2(7, 2)]), hc if sx > 0 else Art.shade_of(hc, 0.2), 2.2, 0.0)
				Art.flat(ci, PackedVector2Array([b + Vector2(-3.5, 0), tip + Vector2(0, 5), b + Vector2(3.5, 0)]), Color("3a2a34"))
		"feather_crest":
			for k in 3:
				Art.push(ci, top + Vector2(-2, 4), -0.7 - k * 0.35)
				Art.toon(ci, _FEATHER, hc2 if k != 1 else Color("ff8a2a"), 2.0, 0.0)
				Art.pop(ci)
		"dwarf_helm":
			Art.push(ci, c, 0.0, Vector2(0.9, 0.9))
			var dome := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				dome.append(Vector2(cos(a) * 22.0, -6.0 + sin(a) * 18.0))
			for sx: float in [-1.0, 1.0]:
				var pts := _curl(Vector2(sx * 18, -12), -PI / 2.0 + sx * 1.2, 16, -sx * 1.2, 5)
				Art.toon(ci, _taper(pts, 7, 1.5), Color("f4f0e0"), 2.0, 0.0)
			Art.toon(ci, dome, Color("a9b4c8"), 2.5, 0.6)
			Art.t_rect(ci, Rect2(-23, -12, 46, 7), 3, Color("f2b632"), 2.2, 0.0)
			var crown := PackedVector2Array([Vector2(-10, -22), Vector2(-12, -34), Vector2(-5, -28), Vector2(0, -38), Vector2(5, -28), Vector2(12, -34), Vector2(10, -22)])
			Art.toon(ci, crown, Color("f2b632"), 2.2, 0.4)
			Art.t_circle(ci, Vector2(0, -8.5), 2.6, Art.RED, 1.2, 0.0)
			Art.pop(ci)
		"frog_eyes":
			for sx: float in [-1.0, 1.0]:
				var e := c + Vector2(-1 + sx * 10, -r + 1)
				Art.t_circle(ci, e, 8.0, hc if sx > 0 else Art.shade_of(hc, 0.1), 2.4, 0.3)
				Art.t_circle(ci, e + Vector2(1, -1), 5.0, Color.WHITE, 1.4, 0.0)
				Art.flat(ci, Art.circle_pts(e + Vector2(2, -1), 2.6, 10), Art.INK)
				Art.flat(ci, Art.circle_pts(e + Vector2(1.2, -2), 1.0, 6), Color.WHITE)
			Art.flat(ci, Art.ellipse_pts(c + Vector2(-12, 10), Vector2(3.5, 2.2), 10), Color(hc2, 0.6))
		"mushroom_cap":
			var cap := Art.smooth_pts(PackedVector2Array([c + Vector2(-30, -2), c + Vector2(-26, -18), c + Vector2(-12, -30), c + Vector2(4, -32),
					c + Vector2(22, -24), c + Vector2(32, -8), c + Vector2(30, 0), c + Vector2(0, -6)]), 3)
			Art.toon(ci, cap, hc, 2.6, 0.6)
			for k: Array in [[Vector2(-16, -16), 4.0], [Vector2(2, -24), 5.0], [Vector2(18, -14), 4.0], [Vector2(-4, -12), 3.0], [Vector2(26, -6), 2.5]]:
				Art.flat(ci, _clip(Art.circle_pts(c + (k[0] as Vector2), k[1], 12), cap), Color("fff6e4"))
		"beetle_horn":
			var pts := _curl(c + Vector2(8, -r + 8), -PI / 2.0 + 0.45, 26, -1.5, 6)
			Art.toon(ci, _taper(pts, 11, 2.5), hc2, 2.4, 0.4)
			Art.flat(ci, Art.circle_pts(pts[3] + Vector2(-1, 0), 1.5, 6), Color(1, 1, 1, 0.5))
		"antennae":
			for sx: float in [-1.0, 1.0]:
				var pts := _curl(c + Vector2(-4 + sx * 6, -r + 3), -PI / 2.0 - 0.6 + sx * 0.3, 18, -0.8 + sx * 0.4, 5)
				Art.line_c(ci, pts, Art.INK, 3.2)
				Art.line_c(ci, pts, Art.shade_of(hc, 0.3), 1.4)
				Art.t_circle(ci, pts[5], 2.6, hc2, 1.4, 0.0)
		"flytrap":
			var jaw := Art.smooth_pts(PackedVector2Array([c + Vector2(-24, 4), c + Vector2(-24, -16), c + Vector2(-10, -30), c + Vector2(10, -30),
					c + Vector2(24, -16), c + Vector2(26, 0), c + Vector2(18, -14), c + Vector2(4, -20), c + Vector2(-10, -18), c + Vector2(-18, -8)]), 2)
			Art.toon(ci, jaw, Color("2a8a3a"), 2.4, 0.5)
			Art.flat(ci, _clip(Art.ellipse_pts(c + Vector2(0, -12), Vector2(20, 9), 18), jaw), hc2)
			for k in 6:
				var x := -16.0 + k * 7.0
				var y := -16.0 + absf(x) * 0.25
				Art.toon(ci, PackedVector2Array([c + Vector2(x - 2.5, y - 3), c + Vector2(x + 2.5, y - 3), c + Vector2(x, y + 3)]), Color.WHITE, 1.2, 0.0)
		"alch_hat":
			Art.push(ci, c + Vector2(0, 2), 0.0, Vector2(0.95, 0.95))
			Art.t_rect(ci, Rect2(-14, -46, 28, 32), 5, hc, 2.5, 0.5)
			Art.t_ellipse(ci, Vector2(0, -15), Vector2(24, 5.5), hc, 2.5, 0.3)
			Art.t_rect(ci, Rect2(-14, -24, 28, 6), 2, Color("ffd23f"), 0.0, 0.0)
			for sx: float in [-1.0, 1.0]:
				Art.t_circle(ci, Vector2(sx * 7, -26), 5.5, Color("8e552c"), 2.0, 0.0)
				Art.t_circle(ci, Vector2(sx * 7, -26), 3.6, Color("9cff8a"), 0.0, 0.0)
			Art.pop(ci)
		"lily":
			Art.t_ellipse(ci, top + Vector2(-2, 2), Vector2(19, 5), Color("4ab04a"), 2.2, 0.3)
			Art.flat(ci, PackedVector2Array([top + Vector2(-2, 2), top + Vector2(14, -1), top + Vector2(16, 3)]), Color("2a8a3a"))
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.55
				Art.toon(ci, Art.ellipse_pts(top + Vector2(-2, -4) + Vector2(cos(a), sin(a)) * 4.5, Vector2(2.8, 5.2), 10, a + PI / 2.0), Color("ff9ac0"), 1.4, 0.0)
			Art.t_circle(ci, top + Vector2(-2, -4), 2.4, Color("ffd23f"), 1.2, 0.0)
		"wizard_crown":
			var hat := PackedVector2Array([c + Vector2(-20, -10), c + Vector2(-6, -36), c + Vector2(-2, -52), c + Vector2(-16, -60),
					c + Vector2(4, -56), c + Vector2(10, -34), c + Vector2(22, -10)])
			Art.toon(ci, Art.smooth_pts(hat, 2), hc, 2.6, 0.5)
			Art.t_ellipse(ci, c + Vector2(1, -10), Vector2(27, 6), hc, 2.4, 0.3)
			var crown := PackedVector2Array([c + Vector2(-14, -12), c + Vector2(-16, -24), c + Vector2(-8, -19), c + Vector2(0, -28),
					c + Vector2(8, -19), c + Vector2(16, -24), c + Vector2(15, -12)])
			Art.toon(ci, crown, Color("f2b632"), 2.2, 0.4)
			Art.t_circle(ci, c + Vector2(0, -16), 2.8, Color("9cff3a"), 1.4, 0.0)
			Art.toon(ci, Art.star_pts(c + Vector2(-14, -58), 4.0, 1.8, 5), Color("9cff3a"), 1.4, 0.0)
		"star_crest":
			Art.toon(ci, Art.star_pts(top + Vector2(-2, -6), 10.0, 4.5, 5), hc2, 2.2, 0.5)
		"helm_fin":
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([c + Vector2(-8, -20), c + Vector2(-20, -24), c + Vector2(-34, -20), c + Vector2(-18, -14),
					c + Vector2(-10, -12)]), 2), hc2, 2.2, 0.0)
			Art.t_rect(ci, Rect2(c.x - 10, c.y - 23, 8, 12), 3, hc2, 2.0, 0.0)
		"cat_ears":
			for sx: float in [-1.0, 1.0]:
				var b := c + Vector2(-1 + sx * 11, -r + 5)
				var tip := b + Vector2(sx * 4, -14)
				Art.toon(ci, PackedVector2Array([b + Vector2(-7, 3), tip, b + Vector2(7, 3)]), hc if sx > 0 else Art.shade_of(hc, 0.2), 2.2, 0.0)
				Art.flat(ci, PackedVector2Array([b + Vector2(-3.5, 1), tip + Vector2(0, 5), b + Vector2(3.5, 1)]), hc2)
		"planet":
			var pc := top + Vector2(-22, -14 + (dyn - 2))
			Art.t_circle(ci, pc, 8.0, Color("ff8fd8"), 2.0, 0.5)
			Art.flat(ci, _clip(Art.ellipse_pts(pc + Vector2(0, 2), Vector2(9, 2), 12), Art.circle_pts(pc, 8.0, 16)), Color("c060c0"))
			Art.ring(ci, Art.ellipse_pts(pc, Vector2(14, 4), 20, -0.3), Art.INK, 3.6)
			Art.ring(ci, Art.ellipse_pts(pc, Vector2(14, 4), 20, -0.3), Color("ffd23f"), 1.8)
		"alien_antennae":
			for sx: float in [-1.0, 1.0]:
				var pts := _curl(c + Vector2(-2 + sx * 7, -r + 4), -PI / 2.0 + sx * 0.4, 18, sx * 0.9, 5)
				Art.line_c(ci, pts, Art.INK, 3.6)
				Art.line_c(ci, pts, hc, 1.8)
				Art.t_circle(ci, pts[5], 4.0, Color("ff8fd8"), 1.8, 0.3)


static var _FEATHER := Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(5, -8), Vector2(4, -20), Vector2(0, -28), Vector2(-4, -20), Vector2(-4, -8)]), 2)


# --- Effects ----------------------------------------------------------------------------

static func _fx(ci: CanvasItem, t: float, arm: String, moving: bool) -> void:
	var fx: Array = _sp["fx"]
	if fx.is_empty():
		return
	var g := _c("glow")
	for f: String in fx:
		match f:
			"bubbles":
				var src := Vector2(-2, -88)
				for k in 3:
					var u := fposmod(t * 0.45 + k * 0.33, 1.0)
					if u < 0.75:
						var p := src + Vector2(sin(u * 9.0 + k) * 3.0 - u * 6.0, -u * 34.0)
						Art.dot(ci, p, 2.2 + u * 2.2, Color(0.9, 0.98, 1.0, 0.5 * (1.0 - u / 0.75)))
			"glow":
				Art.dot(ci, Vector2(0, -50), 30.0 + sin(t * 2.5) * 3.0, Color(g, 0.14))
			"embers":
				for k in 3:
					var u := fposmod(t * 0.5 + k * 0.33, 1.0)
					var p := Vector2(-14 + k * 14 + sin(u * 8.0 + k) * 4.0, -20 - u * 70.0)
					Art.dot(ci, p, 1.8 * (1.0 - u) + 0.5, Color(1.0, 0.6 + 0.3 * (1.0 - u), 0.2, 0.9 * (1.0 - u)))
			"bubbles_up":
				for k in 3:
					var u := fposmod(t * 0.4 + k * 0.33, 1.0)
					var p := Vector2(-16 + k * 15 + sin(u * 7.0 + k) * 3.0, -30 - u * 60.0)
					Art.dot(ci, p, 2.4 + u * 1.5, Color(g, 0.6 * (1.0 - u)))
			"sparkles":
				for k in 3:
					var a := t * 1.1 + TAU * k / 3.0
					var p := Vector2(2, -52) + Vector2(cos(a) * 32.0, sin(a) * 14.0 - 16.0)
					Art.push(ci, p, t * 2.0 + k, Vector2.ONE * (0.6 + 0.4 * (sin(a) * 0.5 + 0.5)))
					Art.toon(ci, Chars._SPARK, Color(g.lightened(0.5), 0.95), 0.0, 0.0)
					Art.pop(ci)
			"wisps":
				for k in 3:
					var a := t * 0.8 + TAU * k / 3.0
					var p := Vector2(0, -50) + Vector2(cos(a) * 30.0, sin(a * 1.3) * 12.0 - 10.0)
					Art.dot(ci, p, 5.0, Color(g, 0.3))
					Art.dot(ci, p, 2.2, Color(1, 1, 0.85, 0.95))
			"orbit":
				for k in 3:
					var a := t * 1.2 + TAU * k / 3.0
					var p := Vector2(0, -56) + Vector2(cos(a) * 30.0, sin(a) * 10.0 - 10.0)
					Art.push(ci, p, a)
					Art.toon(ci, _PEBBLE, Art.shade_of(_c("suit"), 0.1 if sin(a) > 0 else 0.35), 1.8, 0.0)
					Art.pop(ci)
					Art.dot(ci, p, 1.2, Color(g, 0.9))


static var _PEBBLE := PackedVector2Array([Vector2(-4, -3), Vector2(2, -4), Vector2(5, 0), Vector2(2, 4), Vector2(-4, 3)])


# --- Evolution board card -----------------------------------------------------------------

static var _fit_cache := {}
static var _sil_cache := {}
const SIL_FILL := Color("2e2452")
const SIL_LINE := Color("1c1534")


## The form standing for the evolution board, centered in a `size` x `size`
## box at `center`. revealed = false: a dark silhouette with a soft colored
## rim light (its outline still shows the wings, crowns and tentacles).
static func draw_card(ci: CanvasItem, center: Vector2, size: float, world: String, form: int, revealed: bool, t: float) -> void:
	form = clampi(form, 0, FORMS - 1)
	var fit := _fit(world, form)
	var r: Rect2 = fit
	var s := minf(size * 0.9 / maxf(r.size.y, 1.0), size * 0.92 / maxf(r.size.x, 1.0))
	s = minf(s, size / 90.0)
	var feet := center + Vector2(-(r.position.x + r.size.x * 0.5) * s, size * 0.5 - (r.end.y) * s - size * 0.05)
	if revealed:
		draw(ci, feet, s, world, form, 1.0, 0.0, 0.0, "show", 0.0, false, Art.GOLD, "happy", Chars.blinking(t, form * 1.7), t, 0, {})
		return
	var k := world_index(world) * 16 + form
	var sil: Array = _sil_cache.get(k, [])
	if sil.is_empty():
		sil = _build_silhouette(world, form)
		_sil_cache[k] = sil
	var bob := sin(t * 1.6 + form) * size * 0.012
	var rim := silhouette_color(world)
	Art.glow(ci, center + Vector2(0, bob - size * 0.04), size * 0.46, Color(rim, 0.3 + 0.06 * sin(t * 2.0)))
	Art.push(ci, feet + Vector2(0, bob), 0.0, Vector2(s, s))
	var o := clampf(size * 0.022, 1.5, 4.0) / maxf(s, 0.2)
	Art.push(ci, Vector2(-o, -o))
	Art._put(ci, sil[0], sil[2])
	Art.pop(ci)
	Art.push(ci, Vector2(o * 0.6, -o * 0.4))
	Art._put(ci, sil[0], sil[3])
	Art.pop(ci)
	Art._put(ci, sil[0], sil[1])
	Art.pop(ci)


## Bounds of the form in its card pose (feet at 0,0, scale 1).
static func _fit(world: String, form: int) -> Rect2:
	var k := world_index(world) * 16 + form
	if _fit_cache.has(k):
		return _fit_cache[k]
	Art.measure_begin()
	draw(null, Vector2.ZERO, 1.0, world, form, 1.0, 0.0, 0.0, "show", 0.0, false, Art.GOLD, "happy", false, 0.0, 0, {})
	var r := Art.measure_end()
	_fit_cache[k] = r
	return r


## Triangles of the form (scale 1, card pose) with three color sets: the
## dark silhouette, and the rim light from the top left and the top right.
static func _build_silhouette(world: String, form: int) -> Array:
	var was := Chars._small
	Art.measure_begin()
	draw(null, Vector2.ZERO, 1.0, world, form, 1.0, 0.0, 0.0, "show", 0.0, false, Art.GOLD, "happy", false, 0.0, 0, {})
	var v: PackedVector2Array = Art._rv.duplicate()
	var c: PackedColorArray = Art._rc.duplicate()
	Art.measure_end()
	Chars._small = was
	var dark := PackedColorArray()
	var rim1 := PackedColorArray()
	var rim2 := PackedColorArray()
	dark.resize(c.size())
	rim1.resize(c.size())
	rim2.resize(c.size())
	var rc := silhouette_color(world)
	var clear := Color(0, 0, 0, 0)
	for i in c.size():
		var col := c[i]
		if col.a < 0.6:
			dark[i] = clear
			rim1[i] = clear
			rim2[i] = clear
			continue
		var line := col.is_equal_approx(Art.INK)
		dark[i] = SIL_LINE if line else SIL_FILL
		rim1[i] = Color(rc, 0.9)
		rim2[i] = Color(rc.lightened(0.3), 0.45)
	return [v, dark, rim1, rim2]
