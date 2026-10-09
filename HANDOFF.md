# Coralight: handoff for a new Claude session

Read CLAUDE.md first (the current picture), then this for commands and details. Parts below date from 2026-09-30.

## The owner
- Mark (GitHub `gonempxr`). Write to him **in Russian**. He is new to git, so explain git steps simply.
- He wants you to do the work yourself, test it, and report briefly:
  - what changed;
  - how you checked it;
  - the risks;
  - what you need from him.
- Ask him before anything irreversible, such as deleting data or changing accounts. Publishing the game to the gh-pages site is his standing request.
- He often misspells the name: repo `colarlight`, itch page `corelight`. The game is **Coralight**.

## The game
Coralight: Dive Tycoon is an idle tycoon/clicker in the style of Idle Miner Tycoon, built with **Godot 4.7.2** for the web. It must work well on both PC and phone.

**Core loop:**
1. Divers mine ore at the depths and drop it into the lift's crate at each depth (`GameState.pit`).
2. The lift (stage `"lift"`) takes it up to the raft (`hold`): each trip goes down to the deepest open depth.
3. The boat carries it to the shore.
4. The plant turns it into coins.

Income is min(dives, lift, boat, plant). The lift, boat and plant are manual until their manager is hired. Their managers survive Dive Deeper (`GameState.AUTOMATED`); the lift goes back to level 1.
Saves from before the lift (no `"lift"` level) get a lift strong enough for their chain, with an operator if the boat had a captain (`_migrate_lift`). Progress save version 2 remaps old tutorial steps.

**Content:**
- 21 depths.
- 15 visual stages each for the boat and the plant.
- Prestige ("Dive Deeper"):
  - needs coins, 1e7 × 6.4^n;
  - needs depth index min(5 + 2n, 20) open;
  - gives an income multiplier of 3^n.
- Meta game: pearls, quests, daily gift, chests, match-3 puzzle → artifact pieces → museum, wardrobe (cosmetics), local player profiles.
- Fishing: 18 fish in 5 rarities, a reel mini-game, a bucket, a fish book and a fisherman helper.
- World: a 10-minute day/night cycle, and everything in it reacts to taps.
- Hints: a lightbulb shows hints and an automation checklist.
- Languages: RU, EN, ES and ZH.
- Money (2026-10-01, branch expansion): optional rewarded ad "x2 coins for 30 min" (stacks to 4 h). Platform providers: `none` (GitHub Pages/itch, button hidden), `crazygames` (SDK v3 via the `window.coralightAds` bridge in the web shell; loads on `*.crazygames.*` or `?ads=crazygames`; real SDK not yet run), `test` (`?ads=test`, 3 s fake ad). No IAP. Rivals League (autoload Rivals): weekly board of clearly fictional sea characters, pearl rewards; Mark asked for bots shown as real players and that was declined.

**Art direction:**
- All art is drawn in code: a cartoon "toon" look with a thick INK outline (#241a3a), chibi characters with emotions and reactions.
- Fonts: Rubik and Nunito for the UI, Noto Sans SC subset for Chinese, Seymour One for the logo only.

**Where it lives:**
- Repo: github.com/gonempxr/colarlight.
  - `main` holds the source: game in `game/`, balance sim in `balance/`, tools in `tools/`.
  - `gh-pages` holds only the web build files plus `.nojekyll`.
- Site: https://gonempxr.github.io/colarlight/
- itch.io: gonempxr.itch.io/corelight. Mark uploads the zip himself. Kind of project: HTML, with "played in browser" checked.

## Setup (fresh cloud session)
```
bash tools/setup.sh   # installs Godot 4.7.2 if missing, fixes the export template path, imports
```
Chromium and Playwright are usually preinstalled in Claude Code on the web.

## Commands (run from game/)
- **Import after adding a class_name or assets:** `godot --headless --path . --import`
- **Tests:** `tools/run_tests.sh` from the repo root runs them all (or one: `godot --headless --path . -s res://tests/<name>.gd`)
  - `check_scripts` (0 broken), `test_economy` (115), `test_progress` (73), `test_match3` (116), `test_puzzle_ui` (57), `test_fishing` (109), `test_world_taps` (34), `test_diver_trip` ("0 jumps").
  - `test_ui` (19), `test_second` (38) and `test_lift` (98) need `--resolution 390x844`.
- **Screenshots:** `xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 -s res://tests/screenshot.gd -- out.png ru mid 0 - 1.0`
  - Arguments: out, lang, scenario (start / mid / late / deep), scroll, overlay (`-`, `toast`, `hint`, `daily`, `sheet:lift`, `second`), ui_scale.
  - Use 1920x1080 or 1440x900 for PC.
- **Preview sheets:** `tests/lift_sheet.gd` (the 6 lift cabins), `tests/stage_sheet.gd`, `daynight_shot.gd`, `diver_sheet.gd`, `fishing_shot.gd`, `depths_shot.gd`.
- **Web export:** `tools/export_web.sh [out] [beta]` (from the repo root).
  - It uses the slim single-thread template in `tools/web_template/` (custom_template path in export_presets.cfg is absolute; tools/setup.sh fixes it).
  - Lazy files (scripts/util/lazy_assets.gd): `music.ogg` (fetched after the start) and `icudt_godot.dat` (line breaking, fetched only for Chinese) sit next to index.html, not in index.pck. The script strips the pack (tools/pck_strip.py) and fixes the pck size in index.html.
  - `beta` builds with the coralight-beta save folder without editing project.godot in git.
  - The wasm is about 30 MB (about 7.7 MB gzipped), index.pck about 2.3 MB.
- **Publish:**
  1. Commit and push the source branch.
  2. Check out `gh-pages` and copy the build files **by name**: index.html, .js, .wasm, .pck, the two worklet .js files, **music.ogg and icudt_godot.dat**. Keep the site's own icons (index.png, index.icon.png, index.apple-touch-icon.png) unless they changed on purpose. Never copy `*.import`, and keep `.nojekyll`.
  3. Commit and push `gh-pages`.
  4. Rebuild the itch zip from the same files.
- **Speed checks:** `tools/perf_matrix.sh` (frame cost per world/room, phone and PC), `tests/perf_attr.gd` (`prof`, `spikes`, `attr`, `open=puzzle|map|...`), `tools/perf_instrument.py` (timed copy), `tools/bench_web.py` (the web build in Chromium). On any page `?fps=1` shows a counter; `?bench=late` a busy throwaway save.
- **Frame rate:** divers, boats and the lift cabin are their own canvas items that move every frame and change shape at Art.shape_hz; the rest animates in two alternating halves (World._schedule). FrameGovernor lowers rates/quality on slow devices (graphics "auto").
- **After adding strings:** run `python3 tools/subset_fonts.py` so Chinese and symbol glyphs (★ ♪ → ×) exist in the web build. On the web there are no system fallback fonts, and a missing glyph shows as a box.

## Code map
- **Autoloads, in order:** Profiles, Settings, Sfx, GameState, Progress, Platform, Fishing.
- `scripts/data/balance.gd` holds all economy numbers and mirrors `balance/sim.py`. Change them together, and rerun `python3 balance/sim.py`.
- `scripts/ui/main.gd` handles layout:
  - PC ("wide") has the notch HUD at the top centre, cards in the right column and the dock bottom-right.
  - Phone has the HUD on top and the dock at the bottom.
- Other files:
  - `hud.gd`: the PC notch, whose bar slides down when the mouse is at the top.
  - `stage_card.gd`, `upgrade_panel.gd`, `scroller.gd` (smooth wheel and fling), `dock.gd`, `hints.gd`, `hint_button.gd`, `tutor.gd`.
  - The lift: `lift_view.gd` (winch, operator, cable, cabin, the crates at each depth) and `lift_card.gd` (its compact card at the top of the shaft).
  - World drawing: `world.gd`, `surface_view.gd`, `props.gd` (the building stages), `day_night.gd`, `diver_layer.gd`, `depth_row.gd`, `chars.gd`, `ore_art.gd`, `pointer_art.gd`, `art.gd` (the toon kit).
  - `scripts/puzzle/` holds the match-3; `scripts/fishing/` holds fishing.
  - Strings live in `i18n/strings.csv`, `puzzle.csv`, `fishing.csv` and `lift.csv`.

## Gotchas
- Draw only through the `Art.*` helpers with push/pop, never `ci.draw_*` directly, because shapes are batched and cached. Cache animated values in steps, or the shape cache floods.
- Give values from autoload calls explicit types (`var x: bool = Progress...`).
- Autoloads must not reference UI classes.
- In `-s` test scripts, load classes that touch autoloads with `load(...).new()`.
- A class_name must not clash with a native class; `Sky` did, so it was renamed to DayNight.
- `Resource.duplicate()` drops a script's plain variables, such as ToonBox colours. Copy them yourself.
- Autowrapped labels:
  - give them a minimum width;
  - their cached minimum size is stale in the same frame, so set the width first or re-fit next frame.
- In tweens, `set_parallel(true)` makes later steps parallel too. Use `.parallel()` per tweener.
- Retina/HiDPI: the UI scale must account for pixel density, not just the viewport width.

## State on 2026-09-30 (expansion)
- Branch `expansion` adds a second boat and plant (for sale once depth 3 opens), 20 building stages, a lift, 15 dive sites (cut from 30 on 2026-10-01; save version 3 folds older saves via OLD_DEPTH_FOLD), prestige gate min(5 + n, 14), per-ocean looks (ocean_look.gd), tap caps (TapLimiter, 10/s per target), suit bonuses. balance/sim.py matches. The numbers above describe v2.1.
- v2.1 is saved as branches `save/v2.1` (source) and `save/site-v2.1` (site).
- The expansion is published only as a test page at /colarlight/beta/. Mark decides whether to keep it.
- **Beta saves:** every page on gonempxr.github.io shares one browser save. So the beta is exported with a temporary edit to project.godot:
  - `config/use_custom_user_dir=true`
  - `config/custom_user_dir_name="coralight-beta"`

  Do not commit this edit. On first start, `Profiles._import_main_saves()` copies the main save into the beta once, reading the main save without writing to it. Export the real release without these settings.

## Open items and known risks
- **Balance** comes from the simulator (about 2–3.5 h per Dive run, about 24 h to the last depth). It is not tested with real players yet, so ask Mark for feedback.
- **Phone speed:** the phone build is about 6–12% heavier than before the day/night and art update (measured with software GL). It has not been measured on a real phone.
- **Narrow phones:**
  - the boat and plant cards cover the sky, so the late tall plant stages are partly hidden;
  - the sunset can happen behind the boat.
- **Sound** has never been checked by ear.
