extends SceneTree
## Screenshot of the main screen (needs a real renderer, not --headless):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 390x844 \
##     -s res://tests/screenshot.gd -- out.png ru mid 0 [sheet]
## Args: output file, language, scenario (start|mid|late), scroll px,
## optional overlay ("-" for none), optional UI scale (1.0/1.12/1.25): sheet | title | avatar | settings | prestige | quests |
## daily | museum | wardrobe[:tab] | players | profile | feature:<id> | chest | tutorial | ocean:N[:night][:banner] | world:N[:night|:dusk][:banner] |
## sheet:<stage> (e.g. sheet:lift) | relang:<lang> (switch language live) | second (a new second boat and plant
## without managers: the red tab dots) | ads (test ad provider: the x2
## button) | boost (its offer) | adtest (the pretend ad) | boosted (x2 on,
## HUD badge) | rivals (the Rivals League board) | rivals_reward (with last
## week's pearls waiting) | room:<0|1|2> (mine, factory, office) | evo (the
## gear panel) | gear4 (it at the last level) | skins (its skins tab) | decor[:slot] | map (the world map) | tut:<step> (the
## tutorial at that step) | hint:<room> (the lightbulb's hint) | room:2:full (the office, vault overflowing) |
## board[:all][:off] (the players' leaderboard) | promo[:bad] (promo code) | invite[:off] (invite friends) |
## thanks:<founder|promo|join|inviter|week|season> (the online gifts' thank-you dialog) | onlinebtn (online on: its side button) |
## board:<month|friends|clubs> | ach (achievements) | card (a player's card) | club[:none] (clubs).
## Scenarios mid and late also open every meta feature and give pearls.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var lang := args[1] if args.size() > 1 else "ru"
	var scenario := args[2] if args.size() > 2 else "mid"
	var scroll := float(args[3]) if args.size() > 3 else 0.0
	var overlay: String = args[4] if args.size() > 4 else ""
	var ui_scale := float(args[5]) if args.size() > 5 else 1.0
	await process_frame
	root.get_node("Settings").language = lang
	root.get_node("Settings").ui_scale = ui_scale
	TranslationServer.set_locale(lang)
	var gs := root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://screenshot_save.json"
	gs.reset()
	var pr := root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://screenshot_progress.json"
	pr.reset()
	# Online gifts from an earlier shot don't carry over (exclusive item, ...).
	root.get_node("Online").data = root.get_node("Online").defaults()
	var profiles := root.get_node("Profiles")
	profiles.set_name_of(profiles.current_id, "Маша" if lang == "ru" else "Alex")
	if scenario != "start":
		for f in Content.FEATURES:
			pr.features[f] = true
		pr.fresh["puzzle"] = true
		pr.pearls = 135
		pr.pearls_total = 180
		pr.tutorial_step = 12
		pr.artifacts["compass"] = {"level": 2, "pieces": 1}
		pr.artifacts["bell_shell"] = {"level": 1, "pieces": 3}
		pr.artifacts["fish_idol"] = {"level": 0, "pieces": 2}
		pr.owned["pet_crab"] = true
		pr.owned["pet_octopus"] = true
		pr.owned["hat_cat_ears"] = true
		pr.equipped["pet"] = "pet_octopus"
		pr.stats["puzzles_won"] = 4
		pr.owned["outfit_pirate"] = true
		pr.equipped["outfit"] = "outfit_pirate"
		pr.decor["sofa"] = 2
		pr.decor["plant"] = 1
		pr.chest_ready = overlay == "chest"
		if overlay != "daily":
			pr.daily_last = pr.today()
		pr.apply_bonus()
		pr._fill_quests()
		pr.quests[0]["count"] = pr.quests[0]["goal"]
		_streak_setup(pr, overlay)
	match scenario:
		"mid", "rich":
			gs.levels.merge({"d0": 34, "d1": 27, "d2": 12, "lift": 40, "boat": 45, "plant": 41}, true)
			for k in ["d0", "d1", "lift", "boat", "plant"]:
				gs.managers[k] = true
			gs.coins = 48250.0
			gs.hold = 1840.0
			gs.dock = 620.0
			gs.evo = 1
			gs.vault = 8400.0
			if scenario == "rich":
				# Coins for the late tutorial steps (accountant, evolution).
				gs.coins = 2.5e6
				gs.evo = 0
		"late":
			gs.levels.merge({"d0": 62, "d1": 58, "d2": 42, "d3": 32, "d4": 11, "d5": 1, "lift": 160, "boat": 168, "plant": 152}, true)
			for k in gs.stage_keys():
				gs.managers[k] = true
			gs.coins = 6.3e7
		"deep":
			# Everything open, boat and plant at their last stage.
			for k in gs.stage_keys():
				gs.levels[k] = 60
				gs.managers[k] = true
			gs.levels.merge({"lift": 300, "boat": 360, "plant": 360}, true)
			gs.coins = 2.0e13
			gs.hold = 3.4e12
			gs.dock = 9.1e11
		_:
			gs.coins = 12.0
	# ocean:N[:night][:banner] - the world after N Dives (its own colors),
	# at night and/or with the arrival banner.
	if overlay.begins_with("ocean:"):
		var parts := overlay.split(":")
		gs.prestige_count = int(parts[1])
		if "night" in parts:
			load("res://scripts/ui/day_night.gd").fixed_phase = 0.75
	# world:N[:night][:banner] - location N (0 ocean, 1 volcano, 2 acid
	# swamp, 3 moon, 4 = ocean ★2 ...) by day (noon) or at night.
	if overlay.begins_with("world:"):
		var parts := overlay.split(":")
		if gs.get("location") != null:
			gs.set("location", int(parts[1]))
		else:
			gs.prestige_count = int(parts[1])
		load("res://scripts/ui/day_night.gd").fixed_phase = 0.75 if "night" in parts else (0.47 if "dusk" in parts else 0.2)
	if overlay == "second":
		gs.levels.merge({"boat2": 3, "plant2": 2}, true)
		gs.managers["boat2"] = false
		gs.managers["plant2"] = false
	if overlay in ["ads", "boost", "adtest", "boosted"]:
		root.get_node("Platform").set_provider("test")
	if overlay == "boosted":
		gs.add_ad_boost()
		gs.add_ad_boost()
	var rivals := root.get_node("Rivals")
	rivals.autosave_enabled = false
	rivals.reset()
	rivals.pace = 900.0
	# Thursday evening of a week, the player a bit above their usual pace.
	rivals.time_offset = (rivals.week * 7 + 3.8) * 86400.0 + rivals.MONDAY_OFFSET - rivals._local(Time.get_unix_time_from_system()) + 0.0
	rivals.week = rivals.current_week()
	rivals.points = 610
	if overlay == "rivals_reward":
		rivals.last = {"week": rivals.week - 1, "place": 2, "pearls": 15, "claimed": false}
	load("res://scripts/ui/main.gd").show_title = overlay == "title"
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	# Let the chain run a bit so divers and the boat are mid-cycle.
	for i in 90:
		gs.advance(0.05)
		await process_frame
	if scroll > 0.0:
		main._scroller.scroll_to(scroll)
	match overlay:
		"sheet":
			main._on_stage_selected("d1")
		"second":
			main.stage_card("boat").show_unit("boat")
			main.stage_card("plant").show_unit("plant")
		"avatar":
			main.open_avatar_editor()
		"quests", "daily", "museum":
			main.open_feature(overlay)
		"players":
			main.open_players()
		"profile":
			main.open_profile()
		"tutorial":
			pr.tutorial_step = 0
		"bar":
			main._hud._reveal_hold = 10.0
		"nobar":
			main._hud._intro_show = 0.0
			main._hud._reveal_hold = 0.0
		"hint":
			main.open_hint()
		"toast":
			main._show_toast(TranslationServer.translate("QUEST_DONE"))
		"settings":
			main._open_settings()
		"prestige":
			main._open_prestige()
		"boost":
			main.open_boost()
		"adtest":
			main._modal.close()
			root.get_node("Platform").show_rewarded(func(_ok): pass)
		"rivals", "rivals_reward":
			main.open_rivals()
		"evo", "gear4":
			load("res://scripts/ui/evo_panel.gd").tab = "gear"
			if overlay == "gear4":
				gs.evo = 3
			main.open_evolution()
		"skins":
			# A few skins owned, one worn, pearls for an epic one.
			pr.pearls = 200
			for id in ["ocean_shells", "ocean_storm", "ocean_robo"]:
				pr.skins[id] = true
			pr.skin_on["ocean"] = "ocean_storm"
			pr.apply_bonus()
			load("res://scripts/ui/evo_panel.gd").tab = "skins"
			main.open_evolution()
		"map":
			main.open_map()
		"streak", "streak_back":
			main.open_streak()
		"streakpop":
			pr.streak_action()
			await create_timer(0.9).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out)
			quit()
			return
		"streakwear":
			load("res://scripts/ui/wardrobe.gd").tab = "hat"
			main.open_feature("shop")
		_:
			if overlay.begins_with("room:"):
				if overlay.ends_with(":full"):
					# room:2:full - the office with an overflowing vault.
					gs.vault = gs.income_rate() * 400.0
				main.show_room(int(overlay.split(":")[1]), false)
			elif overlay.begins_with("decor"):
				main.open_decor(overlay.split(":")[1] if ":" in overlay else "sofa")
			elif overlay.begins_with("tut:"):
				pr.tutorial_step = int(overlay.split(":")[1])
				if overlay.split(":").size() > 2:
					main.show_room(int(overlay.split(":")[2]), false)
			elif overlay.begins_with("sheet:"):
				main._on_stage_selected(overlay.split(":")[1])
			elif overlay.begins_with("wardrobe"):
				if ":" in overlay:
					load("res://scripts/ui/wardrobe.gd").tab = overlay.split(":")[1]
				main.open_feature("shop")
				# wardrobe:<tab>:end - scrolled to the last items.
				if overlay.ends_with(":end"):
					for i in 20:
						await process_frame
					main._modal._scroll.scroll_vertical = 100000
			elif overlay.begins_with("world:") and overlay.ends_with(":sheet"):
				main._on_stage_selected("d0")
			elif (overlay.begins_with("ocean:") or overlay.begins_with("world:")) and overlay.ends_with(":banner"):
				main._world.show_ocean_name(gs.prestige_count)
			elif overlay.begins_with("relang:"):
				# Switch the language with the settings and the upgrade
				# sheet open, and shoot two frames later (nothing may lag).
				main._on_stage_selected("d0")
				for i in 20:
					await process_frame
				main._open_settings()
				await create_timer(0.5).timeout
				root.get_node("Settings").set_language(overlay.split(":")[1])
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out)
				quit()
				return
			elif overlay.begins_with("nick"):
				root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "")
				main.ask_nickname(tr("ONLINE_NAME_TAKEN") % "Lev" if overlay == "nick:taken" else "")
			elif overlay.begins_with("pass"):
				# The sea pass at level 7 with three rewards waiting.
				var bpass = load("res://scripts/data/battle_pass.gd")
				bpass.tick()
				bpass.add_xp(420)
				root.get_node("Progress").stats["bp_got"] = 4
				root.get_node("Progress").stats["dc_claims"] = int(root.get_node("Progress").stats.get("bp_dc0", 0)) + (6 if "bonus" in overlay else 2)
				if overlay != "pass:btn":
					load("res://scripts/ui/pass_view.gd").open(main)
			elif overlay == "x2":
				root.get_node("GameState").x2_force = true
			elif overlay.split(":")[0] in ["board", "promo", "invite", "thanks", "onlinebtn", "ach", "card", "club", "guide"]:
				await _online_overlay(main, overlay)
			elif overlay.begins_with("feature:"):
				main._news.append(overlay.split(":")[1])
				main._started = true
				main._show_next_news()
	for i in 30:
		await process_frame
	if overlay == "toast":
		await create_timer(0.6).timeout
		print("toast ", main._toast.visible, " ", main._toast.position, " ", main._toast.size, " a=", main._toast.modulate.a, " lbl=", main._toast_label.size, " min=", main._toast_label.get_minimum_size(), " txt=", main._toast_label.text)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()


## Online overlays with a pretend backend (tests/online_fake.gd):
## board[:all][:off] (the players' leaderboard), promo[:bad], invite[:off],
## thanks:<founder|promo|join|inviter|week|season> (the thank-you dialog); board:taken (the name is someone else's);
## pass (the sea pass) | pass:btn (its side button only) | guide[:new][:end] (everything in the game / what's new), board:<month|friends|clubs|puzzle>, ach (achievements), card (a player's card), club[:none] (my club / find one).
func _online_overlay(main: Node, overlay: String) -> void:
	var online := root.get_node("Online")
	var parts := overlay.split(":")
	var fake = load("res://tests/online_fake.gd").new()
	fake.uid = "Shot0001qqqqqqqqqqqqqqqqqqqq"
	fake.founders = 100
	fake.seed(24, ["SeaWolf", "Марина", "Lucía", "小海豚", "DeepDiver", "Капитан", "Pez Globo", "Nemo_77", "Аквамен",
		"CoralQueen", "Tiburón", "Жемчужина", "BubbleBob", "海星", "Kraken", "Медуза"])
	online.data["week"] = OnlineRules.week_id(Time.get_unix_time_from_system())
	var wk := {}
	for id in fake.all:
		wk[id] = {"name": fake.all[id]["name"], "score": float(fake.all[id]["score"]) * 0.08, "a": fake.all[id]["a"]}
	fake.weeks[int(online.data["week"])] = wk
	# Titles and profile cards on some rows, a season board, clubs, friends.
	var nr := 0
	for id in fake.all:
		var tier := 3 if nr == 23 else (2 if nr >= 21 else (1 if nr >= 15 else 0))
		var pj := JSON.stringify({"t": tier, "b": 3 + nr % 15, "wo": 1 + nr % 4, "c": ["Coral Crew", "", "Lava Lords"][nr % 3], "r": maxi(1, 24 - nr)})
		fake.all[id]["p"] = pj
		wk[id]["p"] = pj
		nr += 1
	online.data["month"] = OnlineRules.month_id(Time.get_unix_time_from_system())
	var mo := {}
	for id in fake.all:
		mo[id] = {"name": fake.all[id]["name"], "score": float(fake.all[id]["score"]) * 0.3, "a": fake.all[id]["a"], "p": fake.all[id]["p"]}
	fake.months[int(online.data["month"])] = mo
	var pzw := {}
	var np := 0
	for id in fake.all:
		pzw[id] = {"name": fake.all[id]["name"], "score": float(3 + (np * 7) % 40), "a": fake.all[id]["a"], "p": fake.all[id]["p"]}
		np += 1
	fake.puzzle_weeks[int(online.data["week"])] = pzw
	online.data["pz_score"] = 21.0
	online.data["month_score"] = 7.2e5
	fake.seed_clubs(int(online.data["week"]))
	online.data["title"] = 1
	online.data["title_week"] = int(online.data["week"])
	online.data["best_rank"] = 7
	fake.invites["Shot0001"] = {"a": true, "b": true}
	online.data["all_best"] = 2.4e6
	online.data["week_score"] = 1.9e5
	online.data["seen_profile"] = ""
	if "taken" in parts:
		fake.names[OnlineRules.name_key(OnlineRules.board_name(root.get_node("Profiles").player_name(), fake.uid))] = "Other001xxxxxxxxxxxxxxxxxxxx"
	if not "off" in parts:
		online.use_backend(fake)
		online.claim_name()
		online.data["paid"] = {"Shot0001": 2}
		var ids: Array = fake.all.keys()
		fake.invites[online.invite_code()] = {ids[20]: true, ids[11]: true}
		if parts[0] == "club" and not "none" in parts:
			online.club_join("Club0003", func(_r): pass)
	else:
		online.state = "failed"
	online.pending_thanks.clear()
	var ov = load("res://scripts/ui/online_view.gd")
	match parts[0]:
		"ach":
			var pr := root.get_node("Progress")
			pr.stats["taps"] = 640
			pr.stats["puzzles_won"] = 12
			pr.stats["chests"] = 9
			load("res://scripts/data/achievements.gd").check()
			load("res://scripts/ui/social_view.gd").open_achievements(main)
		"card":
			var rows := []
			for id in fake.all:
				rows.append({"uid": id, "name": fake.all[id]["name"], "score": fake.all[id]["score"], "a": fake.all[id]["a"], "p": fake.all[id]["p"], "you": false})
			rows.sort_custom(func(x, y): return x["score"] > y["score"])
			ov.tab = "week"
			ov.open_board(main)
			load("res://scripts/ui/social_view.gd").open_profile(main, rows[0])
		"club":
			load("res://scripts/ui/social_view.gd").open_clubs(main)
		"guide":
			if "new" in parts:
				main._news.append("whatsnew")
				main._show_next_news()
			else:
				load("res://scripts/ui/guide_view.gd").open(main)
			if "end" in parts:
				for i in 20:
					await process_frame
				main._modal._scroll.scroll_vertical = 100000
		"board":
			ov.tab = "week"
			for k in ["all", "month", "friends", "clubs", "puzzle"]:
				if k in parts:
					ov.tab = k
			ov.open_board(main)
			if "end" in parts:
				for i in 20:
					await process_frame
				main._modal._scroll.scroll_vertical = 100000
		"promo":
			ov.open_promo(main)
			if "bad" in parts:
				await process_frame
				await process_frame
				var edit: LineEdit = _find_edit(main._top)
				edit.text = "DIVE2025"
				edit.text_submitted.emit(edit.text)
		"invite":
			ov.open_invite(main)
		"thanks":
			var kind := parts[1] if parts.size() > 1 else "founder"
			var info: Dictionary = {"founder": {"kind": "founder", "pearls": 100, "item": true, "n": 7},
				"promo": {"kind": "promo", "pearls": 30, "boost": 3600.0, "item": false},
				"join": {"kind": "join", "pearls": 30},
				"inviter": {"kind": "inviter", "pearls": 60, "n": 2},
				"week": {"kind": "week", "pearls": 300, "boost": 10800.0, "n": 2},
				"season": {"kind": "season", "pearls": 600, "n": 3}}.get(kind, {})
			main._top.open(func(m): ov.thanks(m, main, info))


func _find_edit(node: Node) -> LineEdit:
	for c in node.get_children():
		if c is LineEdit:
			return c
		var f := _find_edit(c)
		if f != null:
			return f
	return null


## Streak overlays: streak (the screen), streakpop (the party of a new day),
## streak_back (a long break: the warm welcome), streakwear (flame items).
## Elsewhere a 5-day flame lit today (not yet today under "daily").
func _streak_setup(pr: Node, overlay: String) -> void:
	var t0: int = pr.day_number(pr.today())
	var lit := overlay not in ["daily", "streakpop"]
	var end := t0 if lit else t0 - 1
	pr.streak_log = {}
	var count := 0
	for i in range(end - 5, end + 1):
		if i == end - 3:
			pr.streak_log[pr.date_of(i)] = "ice"
		else:
			pr.streak_log[pr.date_of(i)] = "play"
			count += 1
	pr.streak_count = count
	pr.streak_best = 12
	pr.streak_last = pr.date_of(end)
	pr.streak_freezes = 1
	pr.streak_claimed = {"3": true}
	if overlay == "streakpop":
		pr.streak_count = 6
	if overlay == "streak_back":
		pr.streak_last = pr.date_of(t0 - 6)
		pr.streak_count = 9
		pr.streak_log = {}
		pr.streak_freezes = 0
	if overlay == "streakwear":
		pr.owned["hat_flame"] = true
		pr.owned["boat_flame"] = true
		pr.equipped["hat"] = "hat_flame"
