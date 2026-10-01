class_name Content
extends RefCounted
## Catalogs for the meta game: artifacts, cosmetics, quests, daily gifts and
## when each feature opens. Numbers live here so Progress stays logic only.

# --- Artifacts ------------------------------------------------------------------
## Won puzzles give pieces; enough pieces raise an artifact's level (max 5).
## Each level adds `per_level` to the multiplier on `bonus` (a GameState.bonus
## key: a stage key, "all", "dives", "tap", "offline", or Progress's own
## "chest" and "puzzle").
const ARTIFACTS: Array[Dictionary] = [
	{"id": "compass", "bonus": "boat", "per_level": 0.15},
	{"id": "bell_shell", "bonus": "d0", "per_level": 0.3},
	{"id": "fish_idol", "bonus": "tap", "per_level": 0.25},
	{"id": "amphora", "bonus": "plant", "per_level": 0.15},
	{"id": "trident", "bonus": "dives", "per_level": 0.1},
	{"id": "treasure_key", "bonus": "chest", "per_level": 0.3},
	{"id": "ship_wheel", "bonus": "boat", "per_level": 0.15},
	{"id": "diving_watch", "bonus": "offline", "per_level": 0.15},
	{"id": "pearl_crown", "bonus": "all", "per_level": 0.06},
	{"id": "star_map", "bonus": "puzzle", "per_level": 0.2},
	{"id": "crystal_lantern", "bonus": "dives", "per_level": 0.1},
	{"id": "sun_medallion", "bonus": "all", "per_level": 0.06},
]
const ARTIFACT_MAX := 5

# --- Puzzle rewards -------------------------------------------------------------
## Puzzle coins are minutes of the player's income (so a win is worth the
## same at any stage of the economy) times a factor that grows with the
## puzzle level being played: the first puzzle levels pay a little (even late
## in the game), new deeper levels pay more. Factor: PUZZLE_FACTOR_FIRST at
## level 1, +PUZZLE_FACTOR_STEP per level, at most PUZZLE_FACTOR_MAX.
const PUZZLE_FACTOR_FIRST := 0.4
const PUZZLE_FACTOR_STEP := 0.06
const PUZZLE_FACTOR_MAX := 2.0
## A win: (PUZZLE_WIN_MIN + PUZZLE_STAR_MIN x stars) minutes x factor.
const PUZZLE_WIN_MIN := 1.5
const PUZZLE_STAR_MIN := 0.5
## "Collect what you got": (PUZZLE_LOSS_MIN + PUZZLE_PIECE_MIN x pieces) x factor.
const PUZZLE_LOSS_MIN := 0.5
const PUZZLE_PIECE_MIN := 0.25
## A win gives 2 + stars pearls, plus one more every PUZZLE_PEARL_EVERY
## puzzle levels (at most PUZZLE_PEARL_MAX_EXTRA more).
const PUZZLE_PEARL_EVERY := 10
const PUZZLE_PEARL_MAX_EXTRA := 3


static func puzzle_factor(level: int) -> float:
	return minf(PUZZLE_FACTOR_MAX, PUZZLE_FACTOR_FIRST + PUZZLE_FACTOR_STEP * maxi(0, level - 1))


## Minutes of income a finished puzzle level pays.
static func puzzle_minutes(level: int, won: bool, stars: int, pieces: int) -> float:
	var base := PUZZLE_WIN_MIN + PUZZLE_STAR_MIN * stars if won else PUZZLE_LOSS_MIN + PUZZLE_PIECE_MIN * pieces
	return base * puzzle_factor(level)


static func puzzle_pearls(level: int, won: bool, stars: int, pieces: int) -> int:
	if not won:
		return 1 if pieces > 0 else 0
	return 2 + stars + mini(PUZZLE_PEARL_MAX_EXTRA, maxi(0, level - 1) / PUZZLE_PEARL_EVERY)
## Pieces needed to reach level 1, 2, ... 5.
const PIECES := [3, 4, 5, 6, 8]


static func artifact(id: String) -> Dictionary:
	for a in ARTIFACTS:
		if a["id"] == id:
			return a
	return {}


# --- Cosmetics ------------------------------------------------------------------
## slot: hat (the player's hat), pet (swims next to the player), boat (boat
## paint), suit (every diver's suit). Unlock: "free", "pearls" (price),
## "goal" (an achievement, see GOALS) or "shop" (real money, only when the
## platform sells things). rarity: 0 common, 1 rare, 2 epic, 3 legendary.
const COSMETICS: Array[Dictionary] = [
	# Pets
	{"id": "pet_turtle", "slot": "pet", "art": "turtle", "unlock": "goal", "goal": "puzzle_1", "rarity": 0},
	{"id": "pet_crab", "slot": "pet", "art": "crab", "unlock": "pearls", "price": 40, "rarity": 0},
	{"id": "pet_clownfish", "slot": "pet", "art": "clownfish", "unlock": "pearls", "price": 50, "rarity": 0},
	{"id": "pet_seahorse", "slot": "pet", "art": "seahorse", "unlock": "pearls", "price": 60, "rarity": 0},
	{"id": "pet_jellyfish", "slot": "pet", "art": "jellyfish", "unlock": "pearls", "price": 90, "rarity": 1},
	{"id": "pet_puffer", "slot": "pet", "art": "puffer", "unlock": "pearls", "price": 110, "rarity": 1},
	{"id": "pet_octopus", "slot": "pet", "art": "octopus", "unlock": "pearls", "price": 140, "rarity": 1},
	{"id": "pet_seal", "slot": "pet", "art": "seal", "unlock": "pearls", "price": 180, "rarity": 1},
	{"id": "pet_axolotl", "slot": "pet", "art": "axolotl", "unlock": "pearls", "price": 280, "rarity": 2},
	{"id": "pet_dolphin", "slot": "pet", "art": "dolphin", "unlock": "pearls", "price": 320, "rarity": 2},
	{"id": "pet_shark_pup", "slot": "pet", "art": "shark_pup", "unlock": "goal", "goal": "daily_7", "rarity": 2},
	{"id": "pet_narwhal", "slot": "pet", "art": "narwhal", "unlock": "goal", "goal": "museum_6", "rarity": 3},
	# Hats
	{"id": "hat_party", "slot": "hat", "art": "party", "unlock": "goal", "goal": "daily_3", "rarity": 0},
	{"id": "hat_cat_ears", "slot": "hat", "art": "cat_ears", "unlock": "pearls", "price": 30, "rarity": 0},
	{"id": "hat_bunny_ears", "slot": "hat", "art": "bunny_ears", "unlock": "pearls", "price": 30, "rarity": 0},
	{"id": "hat_frog", "slot": "hat", "art": "frog", "unlock": "pearls", "price": 45, "rarity": 0},
	{"id": "hat_chef", "slot": "hat", "art": "chef", "unlock": "pearls", "price": 50, "rarity": 0},
	{"id": "hat_headphones", "slot": "hat", "art": "headphones", "unlock": "pearls", "price": 70, "rarity": 1},
	{"id": "hat_flower_crown", "slot": "hat", "art": "flower_crown", "unlock": "pearls", "price": 70, "rarity": 1},
	{"id": "hat_viking", "slot": "hat", "art": "viking", "unlock": "pearls", "price": 130, "rarity": 1},
	{"id": "hat_wizard", "slot": "hat", "art": "wizard", "unlock": "pearls", "price": 160, "rarity": 1},
	{"id": "hat_shark_hood", "slot": "hat", "art": "shark_hood", "unlock": "pearls", "price": 170, "rarity": 1},
	{"id": "hat_dino_hood", "slot": "hat", "art": "dino_hood", "unlock": "pearls", "price": 260, "rarity": 2},
	{"id": "hat_unicorn", "slot": "hat", "art": "unicorn", "unlock": "pearls", "price": 300, "rarity": 2},
	{"id": "hat_pumpkin", "slot": "hat", "art": "pumpkin", "unlock": "goal", "goal": "puzzle_20", "rarity": 2},
	{"id": "hat_astronaut", "slot": "hat", "art": "astronaut", "unlock": "goal", "goal": "depth_5", "rarity": 3},
	# Boat paint
	{"id": "boat_classic", "slot": "boat", "art": "classic", "unlock": "free", "rarity": 0},
	{"id": "boat_sunny", "slot": "boat", "art": "sunny", "unlock": "pearls", "price": 60, "rarity": 0},
	{"id": "boat_candy", "slot": "boat", "art": "candy", "unlock": "pearls", "price": 120, "rarity": 1},
	{"id": "boat_pirate", "slot": "boat", "art": "pirate", "unlock": "pearls", "price": 200, "rarity": 2},
	{"id": "boat_royal", "slot": "boat", "art": "royal", "unlock": "goal", "goal": "prestige_1", "rarity": 3},
	# Diver suits
	# dives: the worn suit makes every diver bring up this much more ore
	# (a share, on top of artifacts). Pearls or goals only, never real money.
	{"id": "suit_classic", "slot": "suit", "art": "classic", "unlock": "free", "rarity": 0, "dives": 0.0},
	{"id": "suit_mint", "slot": "suit", "art": "mint", "unlock": "pearls", "price": 50, "rarity": 0, "dives": 0.03},
	{"id": "suit_bubblegum", "slot": "suit", "art": "bubblegum", "unlock": "pearls", "price": 80, "rarity": 1, "dives": 0.05},
	{"id": "suit_sunset", "slot": "suit", "art": "sunset", "unlock": "pearls", "price": 120, "rarity": 1, "dives": 0.08},
	{"id": "suit_galaxy", "slot": "suit", "art": "galaxy", "unlock": "goal", "goal": "puzzle_10", "rarity": 2, "dives": 0.12},
]
const SLOTS: Array[String] = ["pet", "hat", "boat", "suit"]
const RARITY_COLORS: Array[Color] = [Color("7fc8f8"), Color("5cd05f"), Color("b07cff"), Color("ffbf2e")]

## Boat paint: hull, stripe, cabin roof, chimney, flag.
const BOAT_PAINTS := {
	"classic": [],
	"sunny": [Color("ffc93c"), Color("ffffff"), Color("3aa6f0"), Color("ff7b54"), Color("3aa6f0")],
	"candy": [Color("ff8fc7"), Color("fff0f7"), Color("b07cff"), Color("7be0ff"), Color("b6f36a")],
	"pirate": [Color("3a3350"), Color("e8c48a"), Color("7a2e3a"), Color("5c5470"), Color("1a1a24")],
	"royal": [Color("2a4fb8"), Color("ffd84a"), Color("ffd84a"), Color("ffd84a"), Color("d8363c")],
}
## Diver suits: null = each depth's own color.
const SUIT_PAINTS := {
	"classic": null,
	"mint": [Color("3fd6a4"), Color("2bb58a")],
	"bubblegum": [Color("ff7bc0"), Color("ff9fd0")],
	"sunset": [Color("ff9a3c"), Color("ff6f61")],
	"galaxy": [Color("5a3fd6"), Color("8f6cff")],
}


## Extra ore share a suit gives every diver (0 for none).
static func suit_bonus(id: String) -> float:
	return float(cosmetic(id).get("dives", 0.0))


static func cosmetic(id: String) -> Dictionary:
	for c in COSMETICS:
		if c["id"] == id:
			return c
	return {}


## Achievements that unlock items: goal id -> [stat, amount].
const GOALS := {
	"puzzle_1": ["puzzles_won", 1],
	"puzzle_10": ["puzzles_won", 10],
	"puzzle_20": ["puzzles_won", 20],
	"daily_3": ["daily_claimed", 3],
	"daily_7": ["daily_claimed", 7],
	"museum_6": ["artifacts_owned", 6],
	"depth_5": ["deepest", 5],
	"prestige_1": ["prestiges", 1],
}

# --- Quests ---------------------------------------------------------------------
## kind -> which event counts. Amounts scale with how far the player is.
const QUEST_KINDS: Array[String] = ["upgrade", "tap", "earn", "hire", "open", "puzzle", "chest", "upgrade_stage"]
const QUEST_SLOTS := 3

# --- Daily gifts ----------------------------------------------------------------
## One gift per calendar day. Missing a day never resets the week, it just waits.
## kind: coins (minutes of income), pearls, boost (minutes of x2).
const DAILY: Array[Dictionary] = [
	{"kind": "coins", "amount": 5},
	{"kind": "pearls", "amount": 5},
	{"kind": "boost", "amount": 15},
	{"kind": "pearls", "amount": 10},
	{"kind": "coins", "amount": 20},
	{"kind": "boost", "amount": 30},
	{"kind": "pearls", "amount": 25},
]

# --- Pearl shop ------------------------------------------------------------------
const BOOST_PRICE := 20       # pearls for 30 minutes of x2
const BOOST_MIN := 30
const COINS_PRICE := 15       # pearls for 30 minutes of income
const COINS_MIN := 30

# --- Features ---------------------------------------------------------------------
## Order in which features open, so something new keeps arriving.
const FEATURES: Array[String] = ["daily", "chests", "quests", "shop", "puzzle", "museum", "fishing"]
