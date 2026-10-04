# Coralight 3.0 "Worlds": design and work split

Mark's request (2026-10-04), with the concept PDF (docs/concept/): three
rooms, diver evolution with hidden silhouettes, a mini-map with the boat and
locked worlds, player outfits and room decor, and a chain of unusual worlds
(ocean -> volcano -> acid swamp -> moon) unlocked one after another. The
boat horn sound is gone (done, commit 888fca1). Everything must work great on
phone (portrait) and PC (landscape) in RU/EN/ES/ZH.

Rollback: branches `save/v3.1` (source) and `save/site-v3.1` (site).
Work branch: `worlds`. It ships to /colarlight/beta/ first; the main site
stays as it is until Mark approves.

Kids rules stay: rewarded ads optional only, no paid randomness, no FOMO
timers, nothing presented as real players.

## 1. Worlds and locations

Location index `L` = 0, 1, 2, ... (replaces the old Dive Deeper count).
World = `Balance.WORLDS[L % 4]`, tier (stars) = `L / 4` (0 for the first
pass; later passes show "★2", "★3" and use a hue-shifted palette).

| i | id      | name key (i18n)      | worker character | medium in room 1           |
|---|---------|----------------------|------------------|----------------------------|
| 0 | ocean   | WORLD_OCEAN          | diver            | sea water, sandy beach     |
| 1 | volcano | WORLD_VOLCANO        | lava miner       | lava river, basalt shore   |
| 2 | acid    | WORLD_ACID           | chemist (hazmat) | green acid swamp, mushrooms|
| 3 | moon    | WORLD_MOON           | astronaut        | dust "sea" (mare), craters |

Each world has 10 work sites (keys `d0`..`d9` as now, ids per world):

- ocean: shells, coral, pearl, copper, emerald, crystal, gold, glow, atlantis, heart
- volcano: ash, obsidian, sulfur, ruby, magma, fire_opal, garnet, ember, phoenix, dragon
- acid: slime, moss, shroom, bubble, venom, amber, radiant, jade, orchid, goo_king
- moon: dust, meteor, crater_ice, moonstone, star, comet, nebula, alien_egg, ufo, cosmic_heart

Site name keys: `SITE_<ID>` (uppercase id). Ore art kind = the id (reuse the
existing OreArt kinds where they fit: lava->magma, obsidian, meteor, star,
moon->moonstone, amber, ice->crater_ice, etc.).

In non-water worlds the cave rooms hold air, not water: workers walk and
climb instead of swimming.

## 2. Economy (W-Econ owns this)

- One shared 10-step site ladder (value, cost0, unlock, manager, cycle) in
  Balance; every location scales values and prices by `Balance.loc_scale(L)`
  so numbers keep growing forever. Each location should take a little longer
  than the previous one. Targets (balance/sim.py, greedy player): location 0
  complete in about 70-100 min of play, then each next one +10-20%.
- Location gate (Mark: "complete the location, buy everything, then pay a big
  sum"): all 10 sites open, all 10 foremen hired, managers of lift, both
  boats and both plants hired (boat2/plant2 open), then a big coin price
  opens the next location. Diver forms are NOT required (Mark, 2026-10-04):
  they are an optional income booster.
- Diver evolution: 12 forms per location (form 0 = the base look, forms
  1..12 bought with coins, in order). Each bought form multiplies all income
  of this location by 1.10 (so the whole chain speeds up, not only the dives).
  Prices spread over the whole location (first one affordable within the
  first few minutes, the last ones near the end). The UI shows the next 3
  unbought forms in full with their price; the others are silhouettes with
  "?" (owned forms are shown in color).
- Vault (room 3): finished coins land in the vault instead of the wallet
  while the vault has no manager. The player collects them in room 3 (tap
  the pile or "Collect"). The accountant (vault manager, costs coins, hired
  around 10 min into location 0) collects automatically and survives
  location changes, like the other automation. Offline earnings still go
  straight to the wallet (with the usual report).
- Room 3 decor (persistent, pearls): 8 slots x 5 levels (wallpaper, floor,
  desk, sofa, aquarium, lamp, trophy shelf, plant). Each level +1% income.
- Player outfits (persistent, pearls or goals): new wardrobe slot "outfit"
  for the player's own character in room 3 (casual free; captain, pirate,
  chef, scientist, astronaut, knight, wizard, king, superhero...).
- The old diver "suit" slot is removed (evolution replaces it): pearls spent
  on suits are refunded once on load; their ore bonuses go away.
- Save version 4: v3 saves move into location 0 (ocean). Old 15 sites fold
  into the 10 ocean sites (shells..gold 1:1; ice, lava, glow -> glow;
  atlantis, kraken -> atlantis; whale, dragon, heart -> heart; keep the
  highest level, any open -> open, any foreman -> foreman). The old Dive
  Deeper count becomes a permanent `legacy_mult` = old prestige_mult(n).

### GameState API (exact names; other workers code against these)

```
var location: int                      # L
var evo: int                           # forms bought in this location, 0..12
var vault: float                       # coins waiting in room 3
signal location_changed(L: int)
signal evo_bought(form: int)
signal vault_changed
func world_id() -> String              # "ocean" | "volcano" | "acid" | "moon"
func world_index() -> int              # 0..3
func tier() -> int                     # L / 4
func site_id(i: int) -> String         # id of site i in the current world
func evo_cost(form: int) -> float      # price of form 1..12 in this location
func can_buy_evo() -> bool
func buy_evo() -> bool                 # buys form evo + 1
func collect_vault() -> float          # moves vault -> coins, returns amount
func location_goals() -> Array         # [{"id": "sites"|"foremen"|"managers", "have": int, "need": int}]
func location_ready() -> bool          # every goal met
func next_location_cost() -> float
func can_advance_location() -> bool    # ready and coins >= cost
func advance_location() -> bool        # L += 1, run resets (automation kept)
```
Manager key of the vault: "vault" (`has_manager("vault")`, `hire_manager("vault")`, `manager_cost("vault")`).
Progress: `decor: Dictionary` (slot -> level 0..5), `decor_cost(slot) -> int`,
`buy_decor(slot) -> bool`, `Content.DECOR_SLOTS`, signal `decor_changed`;
`looks_seen: Dictionary` (world id -> highest form ever owned, for the codex).

## 3. Characters (W-Chars owns this)

`Chars.diver(...)` keeps its signature; new `pose` keys: `"world"` (world
id, default "ocean") and `"form"` (0..12; -1 = old depth-based gear, default
-1 so nothing breaks before integration). New file `scripts/ui/worker_looks.gd`
(`class_name WorkerLooks`): per world 13 forms with name keys
`FORM_<WORLD>_<N>` and `static func draw_card(ci, center, size, world, form, owned_or_revealed: bool, t)`
for the evolution UI: in full color when revealed, otherwise a dark
silhouette (INK-colored shape with a soft rim light) whose outline still
shows the interesting parts (tentacles, wings, crowns...).

Forms (Mark: "base = mask with snorkel, no gear; 1 = oxygen tank with a
hose; 2 = a bright unusual suit; 3 = robot-like; then ever more magical"):

- ocean diver: 0 snorkel kid, 1 tank + hose, 2 neon suit, 3 robo-diver,
  4 shark suit, 5 octopus (tentacles), 6 coral knight, 7 glowing jellyfish,
  8 pirate diver, 9 mermaid tail, 10 sea dragon, 11 kraken king, 12 Poseidon.
- volcano lava miner: 0 helmet with a lamp, 1 heat suit + tank, 2 bright
  lava-crack suit, 3 robot driller, 4 salamander, 5 obsidian knight,
  6 magma golem, 7 fire fox, 8 dwarf king, 9 phoenix wings, 10 lava dragon,
  11 volcano titan, 12 fire lord.
- acid chemist: 0 hazmat + goggles, 1 gas mask + tanks, 2 neon slime suit,
  3 robot cleaner, 4 frog, 5 mushroom, 6 slime blob, 7 beetle, 8 plant
  monster, 9 alchemist, 10 swamp spirit, 11 hydra, 12 toxic wizard king.
- moon astronaut: 0 white suit, 1 jetpack, 2 neon galaxy suit, 3 robot,
  4 alien antennae, 5 octo-alien, 6 star knight, 7 comet rider,
  8 nebula cape, 9 moon cat, 10 meteor golem, 11 cosmic dragon, 12 star king.

Non-ocean workers need an arm/leg pose that walks (no swimming) and the
same dig/pick/carry/rope/idle/cheer poses. Also: `Chars.player(ci, pos,
scale, look: Dictionary, outfit: String, pose: Dictionary)` full-body player
character for room 3 (look = the avatar from the avatar editor). Sheets:
`tests/evo_sheet.gd`.

## 4. Rooms

The main screen gets three rooms, switched by a tab bar under the top bar
(and by swiping on phones):

1. **Mine** (`room 1`): the current world view (surface + lift + work sites)
   without the plants and the businessman. The shore keeps the workers'
   house, the raft with the lift and the boat dock; boats load at the raft
   and sail out to the factory (they leave the screen; the mini-map shows
   where they go). Cards: lift, boats, sites.
2. **Factory** (`room 2`): an indoor hall. Crates come in through the dock
   door when a boat trip ends, workers run them through the machine line
   (plant 1, and plant 2 when opened, each line's look grows with the
   building stage), products go up a pipe to room 3. Cards: plant, plant2.
3. **Office** (`room 3`): the player's character, the vault pile with a
   Collect button, the diver evolution board (poster), the wardrobe closet
   (outfits) and 8 decor slots that change look with their level.

## 5. Map

A mini-map widget (top left on room 1, under the lightbulb) shows the
current island and the boat moving between the mine and the factory. Tap it
-> the world map: islands for every world joined by one route (like the
concept), the current location lit with mine, factory, office and the boat
moving along its route in sync with the boat trip; locked worlds are dark
silhouettes with "?" and a lock (the outline hints at the volcano, the
mushrooms, the moon dome); the gate checklist and the "Open for X" button.

## 6. Cursor

On PC the mouse cursor becomes a cartoon hand (white glove, thick INK
outline, game style, like Mark's reference), with a hover/pressed variant,
sized for HiDPI. Settings get a toggle (on by default).

## Work split and file ownership

| worker  | owns                                                                 |
|---------|----------------------------------------------------------------------|
| W-Econ  | autoloads (game_state, progress), data/balance.gd, data/content.gd, balance/sim.py, i18n/econ.csv, tests for the economy and saves |
| W-Chars | ui/chars.gd, ui/worker_looks.gd (new), i18n/evo.csv, tests/evo_sheet.gd |
| W-Env   | ui/ocean_look.gd -> world looks, ui/world.gd, ui/surface_view.gd, ui/depth_row.gd, ui/diver_layer.gd, ui/ore_art.gd, ui/art.gd (DEPTH_STYLE), ui/day_night.gd, ui/props.gd, i18n/worlds.csv |
| W-Rooms | new ui/factory_art.gd, ui/office_art.gd, ui/factory_room.gd, ui/office_room.gd, i18n/rooms.csv |
| W-Map   | new ui/map_art.gd, ui/map_view.gd, ui/mini_map.gd, i18n/map.csv       |
| W-UI    | ui/main.gd, hud.gd, dock.gd, upgrade_panel.gd, stage_card.gd, settings_view.gd, wardrobe.gd, new evolution / decor panels, cursor, tutorial and hints (phase 2, after the others merge) |

New i18n CSVs must be added to `locale/translations` in project.godot
(conflicts there are merged by hand). After adding strings run
`python3 tools/subset_fonts.py` then `godot --headless --path . --import`.
