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

## The story
The Coral Light that feeds all five worlds is going out. The Murk (Мгла)
rises from below the deepest trench. The player's expedition goes where
nobody has dived before, to save the Light.

- **Act I: The Twilight Zone.** Shipwrecks, glowing jellyfish, the first
  pockets of Murk.
- **Act II: The Sunken City.** Ruins of the ancients who lit the Coral
  Light. Their machines still work.
- **Act III: The Heart of the Abyss.** The Leviathan sleeps on the Light.
  The finale of the league.

## Endgame: the Atlas of the Deep (PoE2 maps, idle-sized)
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

## Open questions for Mark
- The rewarded x2 ad in the league: switch it off there, or keep it
  without effect on the board? (recommended: off in the league)
- Who may join: everyone (now) or only players who opened the Jungle?
- What carries over to the usual game when a league ends (cosmetics,
  titles, trophies; never coins)?
- Act dates (proposal: Act I + Atlas 1-2 weeks after the start, then one
  act every ~2 weeks).
