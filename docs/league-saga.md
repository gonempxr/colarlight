# Top League saga "The Leviathan's Abyss" (agreed 2026-10-14)

Mark's request: after the Jungle, the Top League (from Fri 16.10.2026) is
where players who want it compete on a board. Their balance starts from
zero, but only in the league. The endgame should feel like Path of Exile 2's
maps: new mechanics, new balance, activities, bounty hunting. The league
world is a saga in three parts.

Decisions on the decision card (2026-10-14):
- Saga: **The Leviathan's Abyss** (Бездна Левиафана).
- Reset: **a separate league save** (PoE-style). Whoever joins starts from
  zero in a league profile; their usual game is not touched.
- For Friday: the league starts on the existing worlds with its own fresh
  save, plus no nickname dialog at the start on CrazyGames. The acts come
  later.

## Done (branch `league`, 2026-10-14)
- League profile: `Profiles.enter_league(lg)` / `leave_league()` /
  `in_league(lg)` / `league_profile(lg)`. The profile keeps `league` (the
  league id) and `home` (where it came from). It doesn't count toward
  `MAX_PROFILES`, at most `MAX_LEAGUE_PROFILES` (3); the oldest league
  profiles go first. A new league game carries the tutorial step over.
- `Online.track`: only coins earned in the league profile count on the
  league board. The week, season and all-time boards still count every game.
- `OnlineRules.LEAGUE_STARTS` = 1792127701 (05:15:01 UTC). Beta and
  CrazyGames builds made before this change counted all progress on board
  ...700, so the fresh-save board is a different one. The Firestore rules
  (v6) don't change.
- League tab: "A new game from zero" card + "Join the league" / "Play in
  the league" / "Back to my game". A toast in the league game at start. The
  players list marks it "· League".
- CrazyGames: no nickname dialog at the start (`Platform.on_portal()`). The
  name comes from the CrazyGames account (`_take_portal_name`), or a guest
  stays "Diver####" until they change it.

## Built: the saga's act I as a real world + mine bosses (2026-10-14, branch `saga`)
Mark (2026-10-14) rejected the separate Atlas screen ("the design limps, it
should be different: mines and all the core gameplay as before, only now
with bosses and new content; and make the design better"). The Atlas code
was removed; its tap-ring fight lives on in the bosses.
- **Saga mode** (`Balance.saga`, set by `Profiles._apply_mode` for league
  profiles): a league game plays the saga's worlds instead of the usual
  five. Location L is world `SAGA_FIRST + L` from the first numbers (a
  fresh start), `Balance.last_location()` = `SAGA_LAST` (0: act I only),
  15 sites per saga world. Looks, map (`MapArt.soon_worlds`: "sunken",
  "abyss" teasers), mini map, stars and quests follow the mode.
- **World 6 "The Twilight Zone"** (`twilight`): violet-rose dusk sky over a
  glowing turquoise sea; underwater sites (abyss divers swim, 4 gear
  levels `GEAR_TWILIGHT`); 15 site styles + decor (`tw_*` in DepthRow:
  plankton, lantern fish, jellies, ghost ship, anglers, siren clams,
  falling stars, eyes in the dark); 5 new ores (`OreArt.twilight_piece`),
  the rest recolored kin; surface: far coral spires, the Coral Light
  beacon (`WorldArt.landmark`), pink clouds and sky jellies; map island
  (`MapArt._twilight`); puzzle pieces (TileWorlds world 5); rods (ocean
  rods in the twilight palette, `RodArt.TWILIGHT`); factory palette.
  Office, boats and fishing scene use the shared looks.
- **Mine bosses** (`MineBoss`, `GameState.boss_*`, `BossScreen`, `BossArt`):
  guards before sites 4, 7, 10, 13 and 15 (Captain Crabblack, Mother
  Jelly, Shadow Eel, Young Kraken, the Twilight Warden). The site can't be
  opened until its guard is beaten. Fight: 45 s, a ring shrinks onto a
  glowing weak spot; a hit = 8 s of the game's income (perfect x2), combo
  +10% per hit in a row up to x2; a miss costs 2 s. HP = the site's unlock
  price x 1.0..1.5, so a stronger mine wins: bosses sit inside the core
  loop. Lost: the boss heals, try again (no wait). Win: pearls (20..100) +
  60..120 s of income. Beaten guards are part of the world's run (a star
  brings them back, stronger). The lightbulb points to the boss.
- Perf (tools: `tests/perf_attr.gd saga [open=boss]`): the saga mine 6-10 ms
  median vs the Jungle 8-11 ms; the boss screen ~3 ms (rooms hidden under it).
- Tests: `tests/test_saga.gd` (mode, world, bosses, save); screenshots
  `saga[:overlay]`, `saga:boss[:row|:fight|:won|:lost]`; `tests/boss_sheet.gd`.
- Chinese font: rebuilt from the Debian fonts-noto-cjk SC face (see
  tools/subset_fonts.py); kerning only, ~219 KB (was 292 KB).

## Built: the saga feeling (2026-10-14, branch `mechanics`)
Mark: "players must feel they are in a saga and in the endgame: something
new, like Atlantis or a Lovecraft world". He chose the story "Atlantis ->
Lovecraft" and all four "saga feeling" parts:
- **The Murk changes the world** (`Murk`, `GameState.murk`, `MurkVeil`):
  in saga games the Murk rises while the mine works (and while away), to
  full in 40 min (each beaten guard: +50% slower). It cuts all income by
  up to 50% (`income_mult` x `murk_mult`, steps of 2%). A tap pushes it
  back 3%; a beaten guard cleanses it (a gold flash). On screen: a violet
  gloom and dark edges over the mine, eyes opening in the dark from 20%,
  tentacles creeping in from 40%. Saved (`murk`), reset with a run.
- **Saga strip** (`SagaBar`, under the room tabs in league games): "Act I",
  the five guards as dots (beaten gold, next glowing "!", star on the last),
  the Murk meter (eye + %). Tap: the saga page (acts I-III, guards with
  portraits and state, what the Murk does, "Watch the story").
- **Story scenes** (`SagaStory`, `main.open_story`): comic panel + the
  Keeper of the Deep (old brass-helmet diver with the Coral Light lantern)
  speaking, typewriter text, skip. "intro" (4 pages) the first time a
  league game opens; "pre_<boss>" before a guard's first fight;
  "post_<boss>" after it is beaten (the last one ends Act I and points to
  Atlantis). Seen scenes are saved (`GameState.story`).
- **Dark league dialogs**: in saga games every dialog has a lavender panel
  in a deep violet frame, violet banners with glowing runes, a violet dim
  (`UiTheme.dialog_box(true)`, `Modal`).
- Map teasers renamed: "Atlantis" (act II) and "R'lyeh" (act III).
- Relics (`scripts/data/relics.gd`): the data side is written (kinds,
  rarities, affixes, salvage/reroll); not used yet (needs the relic UI).

## Built: RPG boss fights, reef art, fishing fix (2026-10-15)
Mark: "design and textures are bad", "fishing bugs", "the boss fight is
crap; make it like Japanese autoclicker RPGs (FF mobile, Seven Deadly Sins):
lots of numbers, lots of HP, a party, classes, RPG moments". Players on
CrazyGames are already in the league (the CG zip had it), so this goes to
the CG zip too.
- **Fishing in league games was broken**: per-world arrays stopped at 5
  worlds (rods, fish colors, scene tints), world 6 read index 5: hundreds
  of errors, no pier, no water. Rods are sized by `Balance.WORLDS`, the
  saga fishes from the ocean's pier in its own colors (`FishingScene`).
- **Boss fight = RPG party battle** (`BossScreen`, `Party`, `MineBoss`):
  60 s on an arena (reef walls, god rays, lit stage). The party: Guardian
  + Harpooner from the start, Medic joins after Crabblack, Alchemist after
  Mother Jelly. Heroes attack by themselves (numbers fly), charge skills
  (Harpoon storm, Shield wall, Healing wave, Ink bomb = armor break x1.5);
  taps on the boss hit (combo up to x2), golden weak spots = crit x4, the
  red target during the boss's wind-up = parry (stun, x2 damage). Unparried
  attacks hurt a hero (KO possible); the whole party down = lost. XP after
  every fight (win 120, loss 45), levels +12% damage/health each, saved as
  `party_xp`. Boss HP x2 (more numbers), MIN_HIT 0.3% so a fresh mine can't
  win even with perfect play (test_saga plays whole fights).
- **Twilight mine art** (`ReefArt`): dark pillow basalt with lit caps and
  shaded feet, glowing veins, barnacles, coral crust; deep-water halls with
  god rays, caustics and far coral spires; dark sand with shells and glowing
  pebbles; whale-rib mine frames; brass shaft braces. Darker site palette.
  The guarded row: name + button over the cave, the boss fits the card column.

## The story (Atlantis -> Lovecraft)
The Coral Light, the heart of the ocean, is fading: the Murk rises from
below the deepest trench, where the Ancient One sleeps. The Keeper of the
Deep has guarded the Light for forty years and leads the player down.
- **Act I: The Twilight Zone** (built). Shipwrecks, glowing jellies, the
  first Murk. Guards: Crabblack, Mother Jelly, Shadow Eel (leaves a scale
  with the map of Atlantis), Young Kraken (its kin held Atlantis' gates),
  the Twilight Warden.
- **Act II: Atlantis** (next). The sunken city of the ancients who lit the
  Coral Light: white-gold columns, domes, working brass mechanisms, statues
  that turned to the Murk. New mechanic idea: ancient machines (sites that
  power each other, a "circuit" bonus). Guards: a bronze automaton, the
  drowned king, a siren choir, the Murk-touched oracle, the Gatekeeper.
- **Act III: R'lyeh** (finale). Lovecraft: green non-Euclidean stone,
  stairs that go nowhere, huge eyes in the walls, tentacles; the Murk is
  strongest here. Final boss: the Ancient One (a multi-phase fight). Ends
  the league's story; carry-over of cosmetics / titles / trophies.
- Each act = one saga world (15 sites, 5 guards), opened after the last
  guard of the previous act (`Balance.SAGA_LAST` grows).

## Acts II and III: the agreed design (Mark, 2026-10-17)
Answers: acts open **by progress** (beat the last guard -> the next act's
world opens at once); Act II gets relics, the Oracle, tides and bosses with
special rules; Act III gets the Ancient One in 3 phases, rifts in the
mines, a **world boss** (all league players hit one shared Ancient One) and
the Astronomer; after the Ancient One: **Nightmare**, the saga again with
stars, endless. The Murk stays in every act and grows harsher.

### Act II: Atlantis (world 7, `atlantis`)
Sunken city of the ancients: white marble, gold domes, mosaics, brass
machines, blue orichalcum glow. Surface: a temple island and a fallen
statue with a trident.
- Sites: marble_dust, mosaic_tile, bronze_gear, amphora, trident_shard,
  orichalcum, sun_lens, automaton_core, siren_harp, royal_seal,
  crystal_codex, tide_engine, poseidon_crown, star_chart, atlas_heart.
- Guards (sites 4, 7, 10, 13, 15), each with a rule:
  - Bronze Automaton: a shield phase, only hero skills hurt it.
  - Siren Queen: her song charms a hero (skips attacks); a parry breaks it.
  - Drowned King: his attacks hit the whole party.
  - Hydra: three heads with their own health; a cut head regrows while
    another lives.
  - Colossus Gatekeeper: the act's end; behind it the gate to R'lyeh.
- Oracle (5th hero, joins after the Drowned King): "Prophecy", 5 s of
  certain crits.
- Relics (`relics.gd`): guards drop them; 3 slots per hero; rarities;
  random properties; salvage into shards; reroll for shards. Earned only.
- Tides: a 3-minute cycle; high tide = lift and boats x2, low tide =
  mines x2.

### Act III: R'lyeh (world 8, `rlyeh`)
Green-black stone with wrong angles, eyes in the walls, tentacles, sick
green glow; black monoliths in a storm, strange stars, a sleeping giant.
- Sites: black_sand, eye_stone, elder_glyph, deep_spawn, madness_pearl,
  cyclopean_block, green_flame, dream_crystal, tentacle_ivory, void_coral,
  sleeper_idol, star_metal, whisper_shell, elder_sign, sleeper_heart.
- Guards: Deep One Priest (summons adds), Shoggoth (regenerates), Priest of
  Dagon (curse: health drain, the Medic clears it), Star-Spawn (flies off:
  windows to hit), the Ancient One (3 phases: eyes, tentacles, awakened).
- Astronomer (6th hero): "Elder Sign" slows the boss's attacks.
- Rifts: tentacles open in the mines and steal ore until tapped; the Murk
  rises twice as fast.
- World boss: one shared Ancient One for the whole league (Firestore,
  new rules), damage board, rewards for everyone who took part.

### After the Ancient One: Nightmare
The saga starts over with a star (like world stars): stronger guards,
bigger rewards, endless. Trophy "Heart of the Sleeper" + a title carry
over to the usual game (never coins).

Built 2026-10-17 (worlds): all of Act II above. Notes: a relic's "site"
property counts for that site index in whatever act you are in; relic
"luck" became "xp" (party experience); act I guards drop act I relic kinds,
act II guards the city's; a full bag melts the drop into shards.

Built 2026-10-17 (worlds, branch `rlyeh`): all of Act III. World 8
`rlyeh` (15 sites, `RlyehArt`, `BossArtRlyeh`); guards deep_one_priest /
shoggoth / dagon_priest / star_spawn / ancient_one with rules summon / regen /
curse / flight / phases (Ancient One 3 phases); Astronomer = 6th hero (Elder
Sign slows the boss, joins after the Shoggoth); rifts (`Rifts`, tap 6x);
league world boss (`WorldBoss`, Firestore `worldboss/{league}/hits`, rules
v9, card on the saga page); Nightmare: stars open only after the Ancient One
(`GameState.saga_done`); story "act3". Boss HUD status words are measured
and wrap to a second line (`BossScreen._tag_at`).

### Build order
Act II first (plumbing, art, bosses, story, Oracle, relics UI, tides), then
Act III (world, bosses, rifts, Astronomer, world boss, Nightmare).

## Earlier idea (replaced): the Atlas of the Deep
- **Sea charts** (waystones), tiers 1-16. A chart is a short expedition
  (10-20 min): a special mine with a goal. Finishing it drops charts, mostly
  of the same or next tier.
- **Modifiers**, risk for reward, e.g. "Strong current: lift -30%, ore
  +50%". The player sets them with pearl runes. Runes are only found or
  earned, never sold. No paid randomness.
- **The Atlas**: a node map under the Murk fog. Finished nodes clear the
  fog and give atlas points for a passive tree. One citadel with a boss per
  act.
- **Bounty hunting**: a "Wanted" board of named sea monsters (Captain
  Crabblack, Mother Jelly, ...). Idle fight: damage = income, taps help.
  Plus "the king's bounty": a bonus for whoever overtakes the crown holder
  (a real race, no fake players).
- **Activities**: digs (Expedition), tides (waves, Ritual-like), the
  endless mine (Delve-like).
- **Board score**: league points (atlas + bosses + bounties + best tier)
  instead of raw coins, so the board rewards variety, not only time online.

## Mark's answers (2026-10-14)
- No x2-for-ads in league games; the league opens after the Jungle; at a
  league's end cosmetics/titles/trophies carry over, never coins (not built).
- Open: act dates (proposal: Act II ~2 weeks after the start).
