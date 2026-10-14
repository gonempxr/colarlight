# Coralight — read this first

Coralight: Dive Tycoon is a web idle tycoon (Idle Miner Tycoon style) made in
**Godot 4.7.2** for phone and PC browsers. Owner: **Mark** (GitHub `gonempxr`).
Talk to him **in Russian**, simply (he is new to git). He wants the work done
and tested, then a short report: what changed, how it was checked, the risks,
what is needed from him.

More detail lives in `HANDOFF.md` (commands, code map, gotchas) and `docs/`.
This file is the quick picture; keep it up to date when something big changes.

## Where things are
- Repo `gonempxr/colarlight` (the name's typo is intended, never "fix" it; same
  for the itch page `gonempxr.itch.io/corelight`).
- `game/` the Godot project · `balance/sim.py` the economy simulator (mirrors
  `game/scripts/data/balance.gd`) · `tools/` scripts · `docs/` design notes,
  tester reports and reference art (`docs/concept/`).
- Branches:
  - `main` — source of the live site (version 2.x/expansion). Don't change
    it until Mark approves the beta.
  - `worlds` — the current work (3.x "Worlds" + 3.1 "Polish"). Work branches
    `p-*` / `w-*` are merged into it. Start new work from `worlds`.
  - `gh-pages` — built site only: root = live game
    (gonempxr.github.io/colarlight/), `beta/` = the beta, `crazygames/` = upload
    copy.
  - `save/v2.1`, `save/site-v2.1`, `save/v3.1`, `save/site-v3.1` — rollback
    points. Never delete or force-push them.
- Several Claude sessions work on this repo at once. Before pushing `worlds`
  or `gh-pages`, fetch and merge the latest first; never overwrite someone
  else's newer beta with an older build.

## The game now (worlds, 2026-10-09)
- Loop: divers mine ore at 10 sites per world (the Jungle 15) → lift → boat → factory →
  coins. Managers automate. Three rooms: Mine, Factory, Office (vault,
  decor). Income = min of the chain.
- Worlds: Ocean → Volcano → Acid swamp → Moon → Jungle Ruins (5 since
  2026-10-14, `Balance.LAST_LOCATION` = 4), then 1 locked "?" island (ice,
  "Soon!"). Opened worlds can be switched between (p-switch). Endgame:
  world stars ★ (docs/jungle-world.md §2, `StarView`, `GameState.get_star`):
  any finished world restarts with x1000 numbers, +25% income everywhere per
  star, max 50 per world; boards cap scores under 1e60 (`Online.SCORE_CAP`).
- Workers: gear levels + skins by rarity per world (Evolution/Gear card).
- Meta: pearls, quests (per world), daily gift, login streak, chests,
  match-3 puzzle → artifacts → museum, wardrobe (pets, hats, outfits,
  boat paint), fishing (rods), Rivals League (clearly marked computer
  rivals), hints bulb, tutorial.
- Online (branch p-online, docs/online.md): real players' leaderboard (week /
  all time), promo codes (SHA-256 hashes only), first-100 "Founder" gift,
  invites (?ref= / CrazyGames inviteLink), exclusive Founder Cap. Firebase
  anonymous auth + Firestore rules; `Online` autoload, `window.coralightOnline`
  bridge, loaded 4 s after start; `?online=test` fakes it.
  2026-10-12 (p-social, in worlds + beta): unique nicknames (Firestore
  `names/{key}`, asked at the start on web), bigger name filter, weekly race
  with prizes paid on Monday, x2 coins every Saturday (UTC), account card
  (CrazyGames log-in on CrazyGames, Google on our site). The rules in
  docs/online.md changed: Mark must publish them together with promoting the
  beta to main (old clients can't send scores under the new rules).
  Social pack (p-social, docs/social-plan.md): achievements (21 badges,
  `Achievements`, toast from OnlineHook), challenge of the day on top of the
  quests (`DailyChallenge`), titles for the weekly top 10 (worn next week),
  monthly seasons (`months/{YYYYMM}` + prize on the 1st), player card (tap a
  name; optional `p` field on score rows), friends tab, clubs (≤30,
  `clubs/`, `clubweeks/`). UI in `social_view.gd`, strings `i18n/social.csv`.
  Balance: coins for pearls once per 5 h; fish never sell for more in a
  poorer world (`Fishing.value_of`).
  Also: weekly puzzle board (stars won, `puzzleweeks/`, small Monday
  prizes); "Everything in the game" guide (`GuideView`, from the lightbulb,
  profile, settings; "What's new" once per `NEWS_VERSION`); the lightbulb
  points to never-opened features; free Sea Pass (`BattlePass`, 30 levels,
  XP from counters, no timer, chapters repeat; items `unlock: "pass"`),
  side button under the lightbulb.
- Puzzle: each world has its own board (TileWorlds: lava, swamp, space).
- Languages RU / EN / ES / ZH (Noto Sans SC subset — rerun
  `python3 tools/subset_fonts.py` after adding Chinese text; it needs the
  full font in `~/fontsrc`, otherwise merge glyphs carefully).
- Money (decided 2026-10-09): ads through the CrazyGames SDK only.
  - Rewarded, always optional and opt-in, same-size "no" button, reward only
    after the ad finished: x2 coins for 30 min, x2 offline earnings, a
    second "+5 moves" in the puzzle (the first one is free).
  - Midgame breaks only at natural pauses (puzzle end, fishing closed,
    travel to a world), never in the first 4 minutes of a session or during
    the tutorial, at most one per ~3 min (`Platform.request_midgame`).
  - **No IAP, no paid randomness, no FOMO timers, no bots shown as real
    players.** Fair-play rules stay even though the game is positioned for
    all ages (CrazyGames rejects games "targeted at kids": don't market it
    as a kids' game).
  - Plan and status: `docs/monetization-marketing.md`.

## Status 2026-10-13 (read this first in a new chat)
- Live (main site + `main`): social pack, Sea Pass v1 dialog, puzzle board,
  guide, trusted time (`Clock` autoload: server Date header via the web
  shell `coralightClock`, then monotonic ticks; moving the device clock
  gives nothing). CrazyGames: the version Active there has the social pack;
  `gh-pages:crazygames/coralight-crazygames.zip` = latest main build (Mark
  uploads it himself via "Submit new version", files unzipped, answer
  "Yes, using the Data Module" for saves). Firestore rules v4 are published.
- Leaderboard (2026-10-13, live on main + beta + CG zip): top 100 (asks 120
  rows); one row per player: the save keeps `owner` (its first online id,
  sent as `o` in the profile card) and `Online.merge_rows` joins a player's
  rows from several devices / Google sign-in (never two different real
  names). Beta also has the new board look (podium, `OnlineView._podium`).
- Leader tools (2026-10-13, worlds/beta + CG zip): Mark only. `admins/{uid}`
  docs are added by hand in the Firebase console; kick/ban on a player's card,
  ban list under the board, own ID + Copy under the board. Needs rules v5
  (docs/online.md) published. Since 2026-10-13 the CrazyGames upload is a
  normal (non-beta) export of `worlds`, not `main` (Mark wanted the beta look).
- Beta / `worlds` only (not yet approved for main): new dialog look (striped
  title banner, light-blue panels, `Modal.banner()`), profile as big tiles
  (`Views.tiles`), Sea Pass on its own screen (`PassScreen`, two tracks:
  bonus track opens after 5 challenges of the day, nothing sold), one font
  family (Nunito ExtraBold body + Black), min text 19 px, phone cards show
  only level + price, anti-aliasing on phones (`Art.smooth`; only governor
  level 3 drops it).
- Store covers: variant D of `tools/store_art/covers_v3.py` (in docs/store).
  CTR on launch day was 0.8% (bottom 20%); check again after the new cover.
- 2026-10-14 (worlds + beta only, not main / not the CG zip yet): world 5
  "Jungle Ruins" (docs/jungle-world.md) + world stars. Saves v5; older saves
  are clamped to the Moon on load. Since branch `crown2` the Jungle has 15
  sites (`Balance.site_count`, d10..d14, the longest run: sim 256 min vs
  Moon 133); the other worlds keep 10 (docs/jungle-world.md §4). Screenshots overlay `in:N:<overlay>`.
  Perf: jungle mine is the heaviest view (PC ~10-13 ms headless).
- 2026-10-14 (worlds + beta, branch `crown`): the crown and the Top League
  (docs/online.md rules v6, Mark must publish them). Crown = no. 1 of the race
  board (week, or the league once it runs); minutes at no. 1 per UTC day are
  counted while the holder plays; yesterday's top 3 by minutes get pearls +
  x2, the 1st also the "Корона короля" hat (`hat_day_king`). Toasts "X is
  No. 1 now" (`main._on_crown_changed`, max one per 3 min for others).
  Top League starts Fri 16.10.2026 05:15 UTC (`OnlineRules.LEAGUE_STARTS`,
  8:15 Tallinn): only the league board starts from zero, progress stays.
- 2026-10-14 coin exchange (worlds/beta/CG zip): on the map, an older world's
  panel sends its wallet to the current (bigger) world at the gate-price gap
  (Moon -> Jungle ~1400:1), up to `Balance.EXCHANGE_SHARE` (10%) of that
  world's gate price in all (`GameState.exchange_*`, saved as `exchanged`);
  not earnings, boards don't move. sim: Jungle 150 -> 95 min with a full purse.
- 2026-10-14 (branch `league`, docs/league-saga.md): the Top League is now
  its OWN fresh save (a league profile, `Profiles.enter_league`); only coins
  earned there count on the league board, the usual game stays untouched.
  League start moved to 05:15:01 UTC (board id ...701) so builds that
  counted all progress write elsewhere. Saga "The Leviathan's Abyss"
  (3 acts + PoE2-style Atlas of sea charts, bounties) is agreed but not built.
  CrazyGames: no nickname dialog at start, the CG account name is used.
  Mark's answers (2026-10-14): no x2-for-ads in league games
  (`Profiles.league_game`), the league opens after the Jungle
  (`Profiles.can_join_league`), at a league's end cosmetics/titles/trophies
  carry over (never coins; not built yet).
- 2026-10-14: Mark approved the beta: `main` = `worlds` 08f10fe and the main
  site = that build (rollback: `save/v3.2`, `save/site-v3.2`). Firestore
  rules v5 + v6 must be published for it (Mark).
- 2026-10-14 (branch `atlas`, docs/league-saga.md "Built"): the Atlas of the
  Deep act I for league games: `Atlas` autoload, `AtlasScreen`/`DiveScreen`/
  `AtlasArt`, side button "atlas". Dives are a hard roguelike with oxygen
  and timing-tap fights; loot = income minutes, pearls, shards, charts,
  runes; weekly wanted monsters. Acts II-III, league points and the end-of-
  league carry-over are not built yet.
- Donations (asked 2026-10-14): only on our own site, NEVER in the
  CrazyGames build (CG allows payments only via Xsolla). Built (worlds,
  2026-10-14): board tab "Donations" ranked by total (Mark chose ranking by
  sum), Ko-fi + DonationAlerts buttons (`OnlineRules.donate_urls`, empty =
  tab hidden), "under 18 only with parents" note, no in-game advantage.
  Donors = Firestore `donors/{id}` {name, total €} added by Mark by hand;
  rules v7 in docs/online.md. Waiting for Mark's two links.
- Open requests from Mark:
  1. New promo video for CrazyGames + TikTok + Instagram (vertical), same
     style as `tools/promo_video` (he loved it) but a new meme plot:
     "LVL 1" broke diver -> "LVL 67" rich empire (the 6-7 meme), level
     counter ticking up, ends with logo + TRY NOW. CrazyGames version: no
     captions/links/sound rules as in render.py "cg" mode. Higgsfield has
     only 10 free credits and uploads are blocked by the proxy.
  2. UI redesign phase 2 (research done: Idle Miner, Brawl Stars, Royal
     Match): separate coin/pearl pills in the top bar, fewer round buttons
     on the left, white outlined text on coloured panels, shorter texts,
     one colour system for buttons. Show Mark screenshots before going live.
  3. (done 2026-10-14, on beta) the 5th world: Jungle Ruins.

## Rules of the code
- All art is drawn in code through `Art.*` (art.gd) with push/pop — never
  `CanvasItem.draw_*` directly. Animated values go in steps or the shape
  caches flood. Outline ink is `Art.INK`.
- Speed: moving things (divers, boats, lift cabin) are their own canvas
  items moved every frame; the rest of the scene redraws in two alternating
  halves (`World._schedule`). `FrameGovernor` lowers quality on slow devices.
  Check with `tools/perf_matrix.sh` before/after heavy changes (target: well
  under 16 ms per frame on phone and PC, no spikes).
- Tests load classes that touch autoloads with `load(...).new()`.
  `Resource.duplicate()` loses script variables — copy them by hand.

## Commands (repo root unless said)
- Fresh container: `bash tools/setup.sh` (installs Godot, fixes the export
  template path, imports).
- All tests: `tools/run_tests.sh` (`fast` for the headless ones only). They
  must all pass before merging into `worlds`.
- Screenshots (from `game/`):
  `xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 -s res://tests/screenshot.gd -- out.png ru mid 0 -`
  (scenario start|mid|late|deep, overlays: title, settings, map, world:N,
  room:N, evo, wardrobe, daily, ... — see the header of tests/screenshot.gd;
  1440x900 for PC). Look at the pictures before saying a visual change works.
- Web build: `tools/export_web.sh <out dir> [beta]` (beta = its own save
  folder). Music and the Chinese ICU data are lazy files next to index.html.
- Check a build in a browser: `python3 tools/bench_web.py <dir> all 10 bench=late`.
  On the real site `?fps=1` shows a frame counter, `?bench=late` a throwaway
  busy save.
- Publish the beta: copy the build files by name into `gh-pages:beta/`
  (index.html/.js/.wasm/.pck, the two worklet .js, music.ogg,
  icudt_godot.dat; keep the existing icons and `.nojekyll`), commit, push.
  GitHub Pages can't be fetched from the container — verify with
  `git ls-remote`, test locally.
- Promoting the beta to the main site is Mark's decision: ask first.

## CrazyGames status (2026-10-10)
- First submission was rejected: "overall quality does not yet meet the
  expectations". Audit and plan: `docs/quality-audit.md`. Resubmitting is
  allowed after meaningful improvements (Mark decides when).
- Full build upload (not the loader). Covers: `tools/store_art/` (vector);
  since 2026-10-13 variant D of `covers_v3.py` (blue sea, orange diver, open
  chest) after a 0.8% CTR on launch day; files in `docs/store/`. Keep the logo out
  of the top-left label zone. Videos: `gh-pages:crazygames/video/`.
- 2026-10-11: the polished build is live on the main site, the beta and
  `main` (Mark approved). Phones start with the bigger UI size (1.12,
  `Settings.default_scale`) until the player picks one.
- On CrazyGames the title screen is skipped and gameplayStart is sent after
  loadingStop (`Platform.on_portal`). Google sign-in only runs on our site.
