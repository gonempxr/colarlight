class_name SettingsView
extends RefCounted
## Settings dialog (sound, game, graphics, help) and the players dialog
## (switch, add, rename, remove local profiles).

static func t(key: String) -> String:
	return TranslationServer.translate(key)


## A section: a tinted card with a colored title pill; rows go inside it.
static func _section(m: Modal, key: String, color: Color) -> VBoxContainer:
	var c := Views.card(color.lerp(Color.WHITE, 0.86))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	c.add_child(v)
	var pill := Label.new()
	pill.text = t(key)
	pill.add_theme_font_override("font", UiTheme.heavy_font())
	pill.add_theme_font_size_override("font_size", 22)
	pill.add_theme_color_override("font_color", Art.WHITE)
	pill.add_theme_color_override("font_outline_color", Art.INK)
	pill.add_theme_constant_override("outline_size", 6)
	var sb := ToonBox.make(color, 14, 0)
	sb.line_w = 3.0
	sb.gloss = 0.25
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("normal", sb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(pill)
	m.add(c)
	return v


## "Name ........ [control]" row.
static func _row(box: VBoxContainer, key: String, control: Control) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	box.add_child(r)
	var l := Views.label(t(key), 23, Art.INK, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	var sound := _section(m, "SET_SOUND", Art.TEAL)
	_row(sound, "MUSIC", _slider(Settings.music_volume, func(v): Settings.set_value("music_volume", v)))
	_row(sound, "SOUND", _slider(Settings.sfx_volume, func(v): Settings.set_value("sfx_volume", v)))
	_row(sound, "VOICES", _toggle(Settings.voices, func(v): Settings.set_value("voices", v)))

	var game := _section(m, "SET_GAME", Art.BLUE)
	_row(game, "LANGUAGE", _cycle(Settings.LANGUAGE_NAMES[Settings.language], func(): Settings.next_language()))
	_row(game, "VIBRATION", _toggle(Settings.vibration, func(v):
		Settings.set_value("vibration", v)
		Settings.buzz(40)))
	_row(game, "NUMBERS", _cycle("1.5K" if Settings.number_style == "short" else "1.5e3",
			func(): Settings.set_value("number_style", "sci" if Settings.number_style == "short" else "short")))

	var screen := _section(m, "SET_SCREEN", Art.PURPLE)
	var q := Settings.QUALITIES
	_row(screen, "QUALITY", _cycle(t("QUALITY_" + Settings.quality.to_upper()),
			func(): Settings.set_value("quality", q[(q.find(Settings.quality) + 1) % q.size()])))
	var scales := Settings.UI_SCALES
	_row(screen, "UI_SIZE", _cycle(t(["SIZE_NORMAL", "SIZE_BIG", "SIZE_HUGE"][scales.find(Settings.ui_scale)]),
			func(): Settings.set_value("ui_scale", scales[(scales.find(Settings.ui_scale) + 1) % scales.size()])))
	_row(screen, "REDUCE_MOTION", _toggle(Settings.reduce_motion, func(v): Settings.set_value("reduce_motion", v)))
	if not HandCursor.touch_device():
		_row(screen, "HAND_CURSOR", _toggle(Settings.hand_cursor, func(v): Settings.set_value("hand_cursor", v)))

	var who := _section(m, "SET_PLAYER", Art.CORAL)
	var players := m.button("%s: %s" % [t("PLAYERS"), Profiles.player_name() if Profiles.player_name() != "" else "?"],
			func(): Sfx.play("click"); main.open_players(), &"PurpleButton")
	var replay := m.button(t("REPLAY_TUTORIAL"), func():
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
	for b: Button in [players, replay, reset]:
		b.reparent(who, false)
	m.text(t("CREDITS"), 16, Art.INK_SOFT)
	m.text("Coralight %s" % ProjectSettings.get_setting("application/config/version", ""), 15, Art.INK_SOFT)


# --- Profile -----------------------------------------------------------------------------

## What the portrait in the top bar opens: the player (name, look) and who
## is playing. The wardrobe (clothes, pets, paint) is its own dock button.
static func profile(m: Modal, main: Node) -> void:
	m.title(t("PROFILE"))
	var c := Views.card(Color("fff1c2"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	c.add_child(v)
	v.add_child(ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float):
		var at := Vector2(s.x / 2.0, s.y - 10.0)
		Art.t_ellipse(ci, at, Vector2(110, 16), Art.CREAM_DARK, 3.0, 0.0)
		Chars.person(ci, at + Vector2(0, -4 - absf(sin(tt * 2.2)) * 3.0), 1.7, 1.0, Settings.avatar,
				{"emotion": "happy", "blink": Chars.blinking(tt, 2.0), "arm_r": 0.3 + sin(tt * 2.0) * 0.1, "arm_l": -0.2, "hold": ""}),
			Vector2(0, 236), true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	# A spacer as wide as the pencil keeps the name centred under the player.
	var pad := Control.new()
	pad.custom_minimum_size.x = 64
	h.add_child(pad)
	var name_text := Profiles.player_name() if Profiles.player_name() != "" else "?"
	var l := Views.label(name_text, 34, Art.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var rename := Button.new()
	rename.theme_type_variation = &"CreamButton"
	rename.icon = Icons.get_icon("pencil", 34)
	rename.custom_minimum_size = Vector2(64, 64)
	rename.tooltip_text = t("WHATS_YOUR_NAME")
	rename.pressed.connect(func(): Sfx.play("click"); main.ask_name(Profiles.current_id, func(): m.rebuild()))
	h.add_child(rename)
	m.add(c)
	m.text(t("PROFILE_HINT"), 20, Art.INK_SOFT)
	var look := m.button(t("EDIT_LOOK"), func(): Sfx.play("click"); main.open_avatar_editor(main.open_profile), &"BlueButton")
	look.icon = Icons.get_icon("pencil", 34)
	if Progress.has_feature("quests"):
		# The Rivals League (made-up sea characters), with this week's place.
		var league := m.button("%s  ·  #%d" % [t("RIVALS"), Rivals.place()], func(): Sfx.play("click"); main.open_rivals(), &"GoldButton")
		league.icon = Icons.get_icon("star", 36)
	if Progress.has_feature("shop"):
		var ward := m.button(t("WARDROBE"), func(): Sfx.play("click"); main.open_feature("shop"))
		ward.icon = Icons.get_icon("wardrobe", 38)
	var who := m.button(t("SWITCH_PLAYER"), func(): Sfx.play("click"); main.open_players(), &"PurpleButton")
	who.icon = Icons.get_icon("people", 36)


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
			h.add_child(Views.pill(t("PLAYING_NOW"), Art.GREEN_DARK, Art.WHITE, 19))
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
