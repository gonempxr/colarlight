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

## Built: the Atlas of the Deep, act I (2026-10-14, branch `atlas`)
Mark's choices: the Atlas opens from the league's first day; the sonar look;
a dive must be "interesting and hard" (not a timer).
- `Atlas` autoload (scripts/autoload/atlas.gd), saved per profile as
  `atlas.json` (synced by CloudSave with the other profile files). Shown
  only in league games (`Atlas.available()` = `Profiles.league_game()`).
- Act I map: 12 nodes + the Warden's citadel (`Atlas.NODES`, tiers 1..6).
  A node opens when a neighbour is cleared; T1 charts are free, the others
  drop from won dives (same tier, or +1 at 40%; Sharks rune +25%).
- A dive = a roguelike descent: 4 layers (citadel 5) of 2-3 chambers
  (treasure, monster, current, air pocket, mystery, wanted monster) then the
  guardian. Oxygen: every chamber costs some, currents more; out of air =
  half the loot, the chart is lost. Fights: a ring shrinks onto a glowing
  weak spot, tap in the window (`Atlas.tap_window`, smaller on deeper
  charts) to hit; a miss or a ring run out costs air. A page closed in a
  fight loses that fight (no free retries).
- Runes (dark, current, sharks, greed): risk for more loot; 1 slot up to T3,
  2 after. Crew gear for shards: tank (air), harpoon (fewer taps), lamp
  (cheaper chambers).
- Wanted: 3 named monsters a week on the same nodes for everyone (seeded by
  the week), met in the last chamber before the guardian; big pearls/shards.
- Loot: coins = minutes of the game's income (so the Atlas moves the league
  board), pearls, shards. Nothing is sold.
- Balance (tests/test_atlas.gd simulation, crew level = tier - 1): a player
  with 90% good taps wins 79-94% of dives, with 70% only 13-33%.
- UI: `AtlasScreen` (sonar map, node card, runes, Dive; crew in the gear
  dialog), `DiveScreen` (air bar, cave with the crew and the depth track,
  chamber cards, fight, result), art in `AtlasArt`; side button "atlas" in
  league games. Screenshots: overlay `atlas[:dive|:fight|:boss|:result]`;
  perf: `tests/perf_attr.gd open=atlas|fight`. The rooms under it are hidden
  (`main._covering`), so the Atlas costs less than the mine view.
- Chinese font: rebuilt from the Debian fonts-noto-cjk SC face (see
  tools/subset_fonts.py); kerning only, 214 KB (was 292 KB).

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
