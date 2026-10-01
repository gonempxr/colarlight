class_name AdBoost
extends RefCounted
## The optional "watch an ad: x2 coins for 30 minutes" offer. The player
## opens it from the round x2 button; both choices are the same size, the
## reward comes only when the ad played to the end, and a failed or skipped
## ad gives a friendly line and nothing else.


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func offer(m: Modal, main: Node) -> void:
	m.title(t("BOOST_TITLE"))
	var pic := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var c := s / 2.0
		for i in 3:
			var a := tt * 1.6 + i * TAU / 3.0
			Art.coin(ci, c + Vector2(cos(a) * 92.0, sin(a) * 26.0 + 6.0), 16.0)
		SideButton.draw_boost(ci, c + Vector2(0, -2 + sin(tt * 2.4) * 3.0), 44.0), Vector2(0, 130), true)
	m.add(pic)
	var minutes := int(GameState.AD_BOOST_SEC / 60.0)
	var hours := int(GameState.AD_BOOST_CAP_SEC / 3600.0)
	m.text(t("BOOST_OFFER") % minutes, 24)
	if GameState.boost_left > 0.0:
		m.text(t("BOOST_LEFT") % [NumFormat.duration(GameState.boost_left), hours], 21, Art.INK_SOFT)
	if not GameState.can_ad_boost():
		m.text(t("BOOST_FULL"), 22, Color("1c7fb8"))
		m.button(t("CLOSE"), func(): m.close(), &"CreamButton")
		return
	# Watch and No thanks: same size, same font (portal rules: no tricks).
	var r := m.row(12)
	var watch := Button.new()
	watch.text = t("BOOST_WATCH")
	watch.icon = Icons.get_icon("play", 30)
	watch.theme_type_variation = &"BlueButton"
	watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch.custom_minimum_size = Vector2(0, 76)
	watch.pressed.connect(func():
		m.close()
		watch_ad(main))
	r.add_child(watch)
	var no := Button.new()
	no.text = t("BOOST_NO")
	no.theme_type_variation = &"CreamButton"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(0, 76)
	no.pressed.connect(func(): Sfx.play("click"); m.close())
	r.add_child(no)


## Plays the ad and pays out x2 time only when it was watched to the end.
static func watch_ad(main: Node) -> void:
	Platform.show_rewarded(func(ok: bool):
		if ok and GameState.add_ad_boost():
			var minutes := int(GameState.AD_BOOST_SEC / 60.0)
			main._show_toast(t("BOOST_GOT") % minutes)
			main.celebrate({"boost": minutes}, main.get_viewport_rect().size / 2.0)
			return
		Sfx.play("deny")
		main._show_toast(t(fail_text(Platform.last_error))))


static func fail_text(reason: String) -> String:
	match reason:
		"adblock":
			return "AD_BLOCKED"
		"skipped":
			return "AD_SKIPPED"
	return "AD_FAIL"
