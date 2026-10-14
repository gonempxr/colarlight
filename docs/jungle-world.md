# World 5 "Jungle Ruins" and the endgame stars (2026-10-13)

Mark's request (thread 2026-10-13): a fifth world after the Moon, replacing
the first locked "?" island, with everything the other worlds have, very
high quality. He picked the theme "Jungle and ruins" on the decision card.
Plus (urgent): players who opened everything see no reason to keep
playing; add strong long-term goals and keep the balance right. Kids-safe
rules stay: no paid randomness, no pressure timers, nothing sold.

Work branch: `jungle` work merged into `worlds`, ships to
/colarlight/beta/ first; the main site only after Mark approves.

## 1. The world

- id `jungle`, location index 4 (`Balance.WORLDS[4]`, `WorldLook.WORLDS[4]`),
  name key `WORLD_JUNGLE` (Jungle Ruins / Джунгли / Ruinas de la Selva /
  丛林遗迹). `Balance.LAST_LOCATION` = 4. The map keeps one "Soon!" island
  (the ice castle) after it.
- Look: lush emerald rainforest (big leaves, palms, ferns, hanging vines,
  bright flowers: orange, magenta, yellow), a wide turquoise jungle river
  with lily pads, a waterfall, warm golden-sand temple stone, a stepped
  pyramid in the distance, parrots and butterflies by day, fireflies at
  night. It must not look like the Acid swamp (that one is acid green,
  murky and mushroomy): the jungle is clear turquoise water, deep emerald
  leaves, warm sunny gold and flowers.
- Rooms hold AIR (temple tunnels: carved stone blocks, vines, torches,
  glyphs): workers walk like on the volcano/acid/moon.
- Worker: `explorer` = a jungle explorer (pith/safari helmet, khaki vest,
  satchel). Gear 1..4: 1 safari helmet + vest; 2 climbing gear (rope,
  head lamp, gloves); 3 bright jungle suit (leaf pattern, glowing trim);
  4 golden temple armour (sun-disc chest plate).
- Fifteen sites since 2026-10-14 (keys d0..d14, name keys `SITE_<ID>`; see §4), ore art kind = id:
  `clay` Clay Shards, `cocoa` Cocoa Pods, `turquoise` Turquoise Vein,
  `old_coins` Ancient Coins, `mask` Stone Masks, `tiger_eye` Tiger's Eye,
  `idol` Golden Idols, `sun_disc` Sun Discs, `serpent` Feathered Serpent,
  `temple_heart` Heart of the Temple.
- Boats: river boats (a wooden dugout / paddle-wheel river boat feel).
- Factory: a temple workshop (stone and bamboo hall, waterfall wheel,
  carved machines, cocoa/gold products). Office: an explorer's study
  (maps, compass, trophies, totem, jungle plants, warm wood).
- Puzzle (TileWorlds, board index 4): banana, parrot, hibiscus flower,
  coconut, golden idol mask, tiger's-eye gem; background: temple ruins
  under a green canopy with sun rays.
- Fishing (world index 4): fishing from a temple pier on the jungle river,
  fish recoloured in tropical river palettes; 20 jungle rods (bamboo,
  vine-wrapped, carved wood, jade, gold, sun rod; bobbers: cork, coconut,
  leaf, golden scarab, glowing sun gem).
- Map island: jungle island with the stepped pyramid, palms, waterfall.

## 2. Endgame: world stars ★ (the long goal)

After the last world opens, every world can be "starred" again and again:

- A world whose gate checklist is done (all its sites and foremen: 10, the
  Jungle 15; the 5 managers) offers "Get a star" for a coin price. The player chooses
  which world, and when (no timer).
- Getting a star restarts that world's run (coins, levels, foremen, gear)
  like a new world; the lift, boat, plant and vault managers stay.
- Each star of a world makes that world's numbers bigger (like the next
  location) AND gives a permanent income bonus to every world, so later
  runs go faster and the totals (and the weekly race) keep climbing.
- Rewards: pearls per star; gifts at total-star milestones (cosmetics);
  achievements; stars shown on the map island and the world banner.
- Unlocks when the last world (Jungle) is opened.

## 3. File ownership (parallel work)

| part   | owns |
|--------|------|
| core (lead) | balance.gd, game_state.gd, progress.gd, content.gd (except jungle skins), achievements.gd, battle_pass.gd, sim.py, i18n worlds/econ/social/strings/switch, new stars strings, tests test_economy/test_worlds/test_switch/test_progress, endgame UI, CLAUDE.md |
| env-surface | world_look.gd (colours), world.gd, world_art.gd, surface_view.gd, day_night.gd, props.gd |
| env-mine | depth_row.gd, art.gd (DEPTH_STYLE), ore_art.gd, diver_layer.gd, lift_view.gd |
| chars  | worker_looks.gd, chars.gd, i18n/evo.csv, content.gd SKINS jungle entries, tests/evo_sheet.gd |
| rooms+map | factory_art.gd, office_art.gd, factory_room.gd, office_room.gd, map_art.gd, map_view.gd, mini_map.gd, i18n/rooms.csv, i18n/map.csv |
| fun    | tile_worlds.gd, tile_art.gd, puzzle_screen.gd, fishing_scene.gd, fishing_screen.gd, fish_art.gd, rod_art.gd, i18n/fishing.csv, i18n/puzzle.csv |

## 4. The longest world: 15 sites (2026-10-14, branch crown2)

Mark asked for "deeper upgrades, heavy progress" in the Jungle. Only the
Jungle grows; the other worlds keep 10 sites.

- `Balance.site_count(L)` (10, the Jungle `LONG_SITES` = 15) and
  `GameState.site_count()`; `stage_keys()` is per world now (not static).
  `Balance.DEPTHS` holds all 15 steps; a 10-site world uses the first 10.
- Sites 11..15 (d10..d14): `jade_jaguar` Jade Jaguars, `emerald_scarab`
  Emerald Scarabs, `sky_feather` Quetzal Feathers, `rain_crystal` Rain
  Crystals, `sun_crown` Crown of the Sun God (the finale). Ore art in
  `OreArt.jungle_deep_piece / jungle_deep_centerpiece`, hall decor in
  `DepthRow._draw_decor_jungle_deep` (decos `jg_jade`, `jg_scarab`,
  `jg_feather`, `jg_rain`, `jg_crown`), colors in `Art.SITE_STYLE`.
- Economy: values x7 and level prices x10 per site like before; the unlock
  and foreman prices of sites 11..15 grow gently (5e9 .. 2.5e10 unlock at
  location 0 scale, foreman x2): late in a run the lift/boat/plant chain
  limits income, so steep gates would be walls. The gate and the star need
  all 15 sites and foremen. sim.py minutes: Ocean 88, Volcano 103, Acid
  124, Moon 133 (unchanged), Jungle 149 -> 256; Jungle star runs ~67 ->
  ~99 min (first), ~51 -> ~80 (second).
- No extra level/gear tiers: site levels have no cap (x2 every 25 levels
  already) and gear has 4 drawn looks, so "deeper upgrades" = 5 more sites.
- Saves: no version bump. Levels are keyed by site; an old jungle save
  loads with d10..d14 closed and keeps everything. The `location` setter
  fills missing keys (`_ensure_keys`). The mine builds 15 rows and hides
  the ones a world doesn't have (`World.site_rows`, `_sync_rows`).
- Tests: `test_worlds.test_jungle_sites` (old save, closed new sites,
  ocean <-> jungle switching, the jungle's star with 15 sites).
- Perf: phone jungle mine ~11 ms median (was ~10 with 10 open sites),
  worst ~25-35 ms headless.
