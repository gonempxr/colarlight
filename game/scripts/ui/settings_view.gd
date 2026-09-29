class_name SettingsView
extends RefCounted
## Settings dialog (sound, game, graphics, help) and the players dialog
## (switch, add, rename, remove local profiles).

static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func _section(m: Modal, key: String) -> void:
	var l := Views.label(t(key), 26, Color("1c7fb8"), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	m.add(l)


## "Name ........ [control]" row.
static func _row(m: Modal, key: String, control: Control) -> void:
	var r := m.row(12)
	var l := Views.label(t(key), 23, Art.INK, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	r.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(control)


static func _slider(value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 56)
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_c): Sfx.play("pop"))
	return s


static func _toggle(on: bool, on_change: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"Button" if on else &"DarkButton"
	b.text = t("ON") if on else t("OFF")
	b.custom_minimum_size = Vector2(160, 64)
	b.pressed.connect(func(): Sfx.play("click"); on_change.call(not on))
	return b


static func _cycle(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"BlueButton"
	b.text = text
	b.custom_minimum_size = Vector2(160, 64)
	b.clip_text = true
	b.pressed.connect(func(): Sfx.play("click"); on_press.call())
	return b


static func build(m: Modal, main: Node) -> void:
	m.title(t("SETTINGS"))
	_section(m, "SET_SOUND")
	_row(m, "MUSIC", _slider(Settings.music_volume, func(v): Settings.set_value("music_volume", v)))
	_row(m, "SOUND", _slider(Settings.sfx_volume, func(v): Settings.set_value("sfx_volume", v)))
	_row(m, "VOICES", _toggle(Settings.voices, func(v): Settings.set_value("voices", v)))

	_section(m, "SET_GAME")
	_row(m, "LANGUAGE", _cycle(Settings.LANGUAGE_NAMES[Settings.language], func(): Settings.next_language()))
	_row(m, "VIBRATION", _toggle(Settings.vibration, func(v):
		Settings.set_value("vibration", v)
		Settings.buzz(40)))
	_row(m, "NUMBERS", _cycle("1.5K" if Settings.number_style == "short" else "1.5e3",
			func(): Settings.set_value("number_style", "sci" if Settings.number_style == "short" else "short")))

	_section(m, "SET_SCREEN")
	var q := Settings.QUALITIES
	_row(m, "QUALITY", _cycle(t("QUALITY_" + Settings.quality.to_upper()),
			func(): Settings.set_value("quality", q[(q.find(Settings.quality) + 1) % q.size()])))
	var scales := Settings.UI_SCALES
	_row(m, "UI_SIZE", _cycle(t(["SIZE_NORMAL", "SIZE_BIG", "SIZE_HUGE"][scales.find(Settings.ui_scale)]),
			func(): Settings.set_value("ui_scale", scales[(scales.find(Settings.ui_scale) + 1) % scales.size()])))
	_row(m, "REDUCE_MOTION", _toggle(Settings.reduce_motion, func(v): Settings.set_value("reduce_motion", v)))

	_section(m, "SET_PLAYER")
	m.button("%s: %s" % [t("PLAYERS"), Profiles.player_name() if Profiles.player_name() != "" else "?"],
			func(): Sfx.play("click"); main.open_players(), &"PurpleButton")
	m.button(t("REPLAY_TUTORIAL"), func():
		Sfx.play("click")
		Progress.tutorial_step = 0
		Progress.changed.emit()
		m.close(), &"BlueButton")
	var confirm := [false]
	var reset: Button
	reset = m.button(t("RESET"), func():
		if confirm[0]:
			GameState.reset_progress()
			Progress.reset_progress()
			m.close()
		else:
			confirm[0] = true
			reset.text = t("RESET_CONFIRM"), &"RedButton")
	m.text(t("CREDITS"), 16, Art.INK_SOFT)
	m.text("Coralight %s" % ProjectSettings.get_setting("application/config/version", ""), 15, Art.INK_SOFT)


# --- Players ---------------------------------------------------------------------------

static func players(m: Modal, main: Node) -> void:
	m.title(t("PLAYERS"))
	m.text(t("PLAYERS_HINT"), 21, Art.INK_SOFT)
	for p in Profiles.list:
		var id: String = p["id"]
		var is_current := id == Profiles.current_id
		var c := Views.card(Color("fff1c2") if is_current else Color("fffaf0"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		c.add_child(h)
		var look := Settings.sanitize_look(p.get("avatar", {}))
		h.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
			Chars.portrait(ci, s / 2.0, minf(s.x, s.y) / 2.0 - 2.0, look, "happy", Chars.blinking(tt, 3.0), Color("ffd98a")),
			Vector2(76, 76), true))
		var name_text: String = p["name"] if p["name"] != "" else "?"
		var l := Views.label(name_text, 26, Art.INK, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		h.add_child(l)
		var rename := Button.new()
		rename.theme_type_variation = &"CreamButton"
		rename.icon = Icons.get_icon("pencil", 34)
		rename.custom_minimum_size = Vector2(64, 64)
		rename.pressed.connect(func(): main.ask_name(id, func(): m.rebuild()))
		h.add_child(rename)
		if is_current:
			var b := Views.label(t("PLAYING_NOW"), 20, Color("1f8a4c"), true)
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
			h.add_child(b)
		else:
			var play := Button.new()
			play.text = t("PLAY")
			play.custom_minimum_size = Vector2(120, 64)
			play.pressed.connect(func():
				Sfx.play("start")
				Profiles.select(id)
				main.after_profile_switch()
				m.rebuild())
			h.add_child(play)
			var del := Button.new()
			del.theme_type_variation = &"RedButton"
			del.icon = Icons.get_icon("close", 26)
			del.custom_minimum_size = Vector2(64, 64)
			var armed := [false]
			del.pressed.connect(func():
				if armed[0]:
					Profiles.remove(id)
					m.rebuild()
				else:
					armed[0] = true
					del.icon = null
					del.text = "?"
					Sfx.play("deny"))
			h.add_child(del)
		m.add(c)
	if Profiles.can_add():
		m.button(t("ADD_PLAYER"), func():
			main.ask_name("", func(): m.rebuild()), &"GoldButton")
