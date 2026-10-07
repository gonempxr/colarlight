# Coralight 3.1 "Polish": plan and work split (2026-10-07)

Mark played the 3.0 "Worlds" beta and asked for:
1. Very smooth animations everywhere ("анимации плохие, надо сделать всё очень плавное").
2. Fix the bugs from the tester's report (docs/concept/testing-4.txt and the
   screenshots in docs/concept/testing-4-p*.png).
3. Exactly 4 worlds (ocean, volcano, acid, moon), then two more islands
   shown as locked "?" silhouettes ("coming soon"); no ★2 repeats on the map.
4. Lava and every non-water world look bad; lava must look like thick glowing
   magma, not blue-ish water with an orange tint.
5. References: character levels and skins (docs/concept/chars-*.png) and
   fishing-rod progression, 20 rod levels per world (docs/concept/rods.txt,
   docs/concept/rods-*.png).

Base branch: `worlds` (beta). Ships to /colarlight/beta/ first.
Kids rules stay: rewarded ads optional only, no paid randomness, no FOMO
timers, never present bots as real players (computer rivals must be clearly
labelled as such).

## Decisions taken (defaults; Mark may change them)
- After the Moon there is no next world yet: the map shows 2 extra locked "?"
  islands with "Soon!" and the Moon's gate panel says new worlds are coming.
  Play continues in the Moon world (levels keep growing). Old saves with
  location >= 4 are clamped to 3 (Moon) keeping their best progress.
- Characters: see the decision card in the thread; default "both":
  per world 4 gear levels (bought with coins, like the PDF levels 1-4, each a
  bigger income boost) plus skins by rarity per world (rare / epic /
  legendary, pearls, each with a small bonus: rare +2%, epic +4%,
  legendary +8% income in that world). The current 12 funny forms become
  the legendary/epic skins where they fit.
- Fishing gets a rod ladder of 20 levels per world following the rod PDF
  (ocean, lava, space; acid gets its own "swamp" rod set in the same spirit),
  the minigame gets a real skill element (cast only on button press, a
  timing bar whose sweet spot shrinks with harder fish and grows with rod
  level) so better rods matter.

## Work split and file ownership
| worker   | owns |
|----------|------|
| W-Anim   | motion and timing: diver_layer.gd movement, lift_view.gd, boat motion in surface_view.gd (movement code only), fx_layer.gd, modal.gd and panel open/close, room tab transitions in main.gd (transition code only), title_screen.gd, the web loading screen (tools/web_shell), frame-rate / draw-cost optimisation |
| W-Worlds | world looks: world_look.gd, world_art.gd, ocean_look.gd, depth_row.gd, art.gd (site styles), day_night.gd, props.gd, surface drawing of the medium in surface_view.gd (draw code only), ore_art.gd, map_art.gd / map_view.gd / mini_map.gd, the 4 + 2 worlds rule in balance.gd / game_state.gd (location cap only), i18n/worlds.csv, map.csv |
| W-Chars  | chars.gd, worker_looks.gd, evo_panel.gd, evo card, skins tab in wardrobe.gd, the evolution/skins economy in balance.gd / game_state.gd / progress.gd / content.gd (evo + skins only), i18n/evo.csv |
| W-Fish   | scripts/fishing/*, fish_art.gd, rods art (new rod_art.gd), fishing upgrades UI, i18n/fishing.csv |
| W-Fix    | everything else in the tester list: pet_art.gd, hats_art.gd, hud.gd avatar, avatar_preview.gd, wardrobe card clipping (except the skins tab), upgrade_panel.gd / stage_card.gd / price_button.gd clarity, dock.gd relabel on language change, settings_view.gd sliders, tap cooldown in game_state.gd (tap only), lift speed in balance.gd (lift only), puzzle (scripts/puzzle/*), rivals_view.gd |

When two workers must touch the same file, each keeps its edit small and in
its own functions; the lead merges.
