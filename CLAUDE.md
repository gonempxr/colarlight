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
- Loop: divers mine ore at 10 sites per world → lift → boat → factory →
  coins. Managers automate. Three rooms: Mine, Factory, Office (vault,
  decor). Income = min of the chain.
- Worlds: Ocean → Volcano → Acid swamp → Moon (exactly 4), then 2 locked
  "?" islands ("Soon!"). Opened worlds can be switched between (p-switch).
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
