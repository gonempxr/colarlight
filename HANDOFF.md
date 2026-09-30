# Coralight: handoff for a new Claude session

Read this first, then continue the work. Everything below was true on 2026-09-30.

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
1. Divers mine ore at the depths.
2. The ore goes up to the raft.
3. The boat carries it to the shore.
4. The plant turns it into coins.

Income is min(dives, boat, plant). The boat and plant are manual until their manager is hired.

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
- Money: none. Mark chose **no ads and no IAP for now**. The Platform autoload hides every ad or purchase button. Background: portals such as Yandex Games were researched; Stripe and Paddle are unavailable for a RU developer.

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
- **Tests:** `godot --headless --path . -s res://tests/<name>.gd`
  - `check_scripts` (0 broken), `test_economy` (108), `test_progress` (73), `test_match3` (116), `test_puzzle_ui` (57), `test_fishing` (109), `test_world_taps` (15), `test_diver_trip` ("0 jumps").
  - `test_ui` (19) needs `--resolution 390x844`.
  - `test_second` checks the second boat and plant (branch `expansion` only).
  - The counts above are from v2.1. On `expansion` some tests changed, so run them and trust their own "N checks, 0 failed" line.
- **Screenshots:** `xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 -s res://tests/screenshot.gd -- out.png ru mid 0 - 1.0`
  - Arguments: out, lang, scenario (start / mid / late / deep), scroll, overlay (`-`, `toast`, `hint`, `daily`), ui_scale.
  - Use 1920x1080 or 1440x900 for PC.
- **Preview sheets:** `tests/stage_sheet.gd`, `daynight_shot.gd`, `diver_sheet.gd`, `fishing_shot.gd`, `depths_shot.gd`; on `expansion` also `world2_shot.gd` (second boat and plant). The arguments are described at the top of each file.
- **Frame cost:** `tests/perf.gd`, and `perf_world2.gd` with the second boat and plant. Compare before and after any drawing change.
- **Web export:** `godot --headless --path . --export-release Web build/web/index.html`
  - It uses the slim single-thread template in `tools/web_template/`.
  - The wasm is about 30 MB.
  - The page uses our own loading screen, `game/web/shell.html`. It is **generated**: edit `tools/web_shell/shell.src.html` (the tips in four languages live there too), then run `python3 tools/make_web_shell.py`. It inlines the logo and font subsets.
  - The loading screen waits for the line `CORALIGHT_READY`, which `main.gd` (`_announce_ready`) prints after the first frame. Removing that print leaves the loading screen up forever.
- **Publish:**
  1. Commit and push `main`.
  2. Check out `gh-pages` and copy the build files **by name**: index.html, .js, .wasm, .pck, .png, the two worklet .js files, apple-touch-icon and icon. Never copy `*.import`, and keep `.nojekyll`.
  3. Commit and push `gh-pages`.
  4. Rebuild the itch zip from the same files.
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
  - World drawing: `world.gd`, `surface_view.gd`, `props.gd` (the building stages), `day_night.gd`, `diver_layer.gd`, `depth_row.gd`, `chars.gd`, `ore_art.gd`, `pointer_art.gd`, `art.gd` (the toon kit).
  - `scripts/puzzle/` holds the match-3; `scripts/fishing/` holds fishing.
  - Strings live in `i18n/strings.csv`, `puzzle.csv` and `fishing.csv`.

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
- Branch `expansion` adds a second boat and plant (for sale once depth 3 opens), 30 depths, 20 building stages and prestige gate min(5 + 2n, 29), cost 1.2e7 × 6.6^n. The numbers above describe v2.1.
- v2.1 is saved as branches `save/v2.1` (source) and `save/site-v2.1` (site).
- The expansion is published only as a test page at /colarlight/beta/. Mark decides whether to keep it.
- **Beta saves:** every page on gonempxr.github.io shares one browser save. So the beta is exported with a temporary edit to project.godot:
  - `config/use_custom_user_dir=true`
  - `config/custom_user_dir_name="coralight-beta"`

  Do not commit this edit. On first start, `Profiles._import_main_saves()` copies the main save into the beta once, reading the main save without writing to it. Export the real release without these settings.

- **Loading screen** (commit 0014f19, after this handoff was first written): logo over a sunny sky, sea with bubbles and fish, a gold progress bar, rotating tips, and an error card with a reload button. It exists only on `expansion` and on the beta page. The main site and `main` still use the old Godot loading screen.

## Next steps
Do them in this order unless Mark asks for something else.
1. **Ask Mark about the beta:** keep the expansion, change it, or drop it? Without his answer do not merge `expansion` into `main` and do not publish it to the main site.
2. **If he keeps it:**
   1. Merge `expansion` into `main` (a normal merge, no force-push). `save/v2.1` and `save/site-v2.1` stay as the way back.
   2. Run all tests and take phone (390x844) and PC (1920x1080) screenshots of the start, mid, late and deep scenarios.
   3. Export **without** the beta save settings, publish to the site root and rebuild the itch zip.
   4. Decide with Mark whether to delete `/beta/` from gh-pages. That deletes a page, so ask first.
3. **If he only wants the loading screen:** move commit 0014f19 to `main` on its own (`git cherry-pick`), export and publish.
4. **After a release, ask Mark for feedback:** how long a run feels, where he got stuck, how the game runs on his phone, and whether the sound is fine. These are the open items below that only a real player can check.
5. **Keep this file true:** when something from this list or from the items below is done, update this file in the same commit.

## Open items and known risks
- **Balance** comes from the simulator (about 2–3.5 h per Dive run, about 24 h to the last depth). It is not tested with real players yet, so ask Mark for feedback.
- **Phone speed:** the phone build is about 6–12% heavier than before the day/night and art update (measured with software GL). It has not been measured on a real phone.
- **Narrow phones:**
  - the boat and plant cards cover the sky, so the late tall plant stages are partly hidden;
  - the sunset can happen behind the boat.
- **Sound** has never been checked by ear.
