# Social pack ("все добавляем") — plan and status

Branch: `p-social` (merge into `worlds` when all tests pass). Saves must stay
compatible: everything is additive (new keys with defaults).

Already done on p-social: coins-for-pearls once per 5 h
(`Content.COINS_COOLDOWN_SEC`, `Progress.coins_wait/buy_coins`), fishing price
fix (`FishData.PRICE_SEC`, `Fishing.value_of`: a fish never sells for more in
a poorer world), themed puzzle per world, nickname at start, unique names,
weekly race + prizes, Saturday x2.

## Pieces (tick when done)
- [x] `scripts/data/achievements.gd` (21 badges, pearls once, stats `ach_<id>`)
- [x] `scripts/data/daily_challenge.gd` (same task for everyone per UTC day, 15 pearls)
- [x] `i18n/social.csv` (achievement strings; registered in project.godot)
- [x] Online data: `best_rank`, `title`, `title_week`, `club`, `club_name`,
      `month`, `month_score`, `season_prize` (defaults() in online.gd)
- [x] Titles: weekly place → tier 3 (1st, King), 2 (2–3, Master), 1 (4–10,
      Star), valid the week after (`title_week == current week`)
- [x] Seasons: month id = YYYY*100+MM (UTC); month score tracked like the week;
      submit writes `months/{m}/scores/{uid}`; board tab "Season"; prize on a
      new month via `rank {kind:"month", id}`: 1st 1000, 2–3 600, top10 300,
      top50 150, top100 80, played 30 pearls
- [x] Profile card: score rows get optional `p` (JSON ≤200: t title, b badges,
      wo worlds, c club, f founder); tap a board row → card
- [x] Friends tab: my inviter (lb_all docId prefix = joins/{me}.code) + who
      joined with my code (invites/{code}/joined), their lb_all rows
- [x] Clubs: `clubs/{id}` {name, owner, n, t} (n ≤ 30), members
      `clubs/{id}/m/{uid}` {name, s (week score), w, t}, weekly club board
      `clubweeks/{w}/clubs/{id}` {name, s, n, t} written by a member after
      summing members. Create / join (list or code) / leave. No prizes.
- [x] JS real + fake (shell.src.html → `python3 tools/make_web_shell.py`),
      GD fake (tests/online_fake.gd), tests
- [x] Rules in docs/online.md: goodScore allows optional `p`; months rule
      (`int(m) == request.time.year()*100 + request.time.month()`); clubs rules
- [x] UI: achievements dialog (profile), daily challenge card on top of
      quests, board tabs (Week/Season/All, Friends/Clubs), club dialog, toast
      for new badges (main.gd calls `Achievements.check()` every ~5 s)
- [x] Translations (RU/EN/ES/ZH), `godot --headless --path . --import`,
      `python3 tools/subset_fonts.py`, all tests, screenshots
- [x] Beta → main site + `main` branch (Mark said "потом все в игру
      переносим"), CrazyGames zip, rules file for Mark (publish together)
- [x] CLAUDE.md update, Russian report to Mark
