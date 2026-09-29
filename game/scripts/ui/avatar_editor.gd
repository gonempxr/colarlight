class_name AvatarEditor
extends RefCounted
## Look editor for the player's avatar (the businessman on the island):
## a live preview and a row of arrows per part. Saved in the player's profile.

const PARTS := [
	["AV_SKIN", "skin"], ["AV_HAIR", "hair"], ["AV_HAIR_COLOR", "hair_color"], ["AV_HAT", "hat"],
	["AV_FACE", "extra"], ["AV_CLOTHES", "clothes"], ["AV_COLOR", "outfit"],
]


static func _options(part: String) -> Array:
	match part:
		"skin": return range(Chars.SKINS.size())
		"hair_color": return range(Chars.HAIR_COLORS.size())
		"outfit": return range(Chars.OUTFITS.size())
		"hair": return Chars.HAIR_STYLES
		"hat":
			# Free hats plus the ones won or bought in the wardrobe.
			var hats: Array = Chars.HATS.duplicate()
			for c in Content.COSMETICS:
				if c["slot"] == "hat" and Progress.is_owned(c["id"]):
					hats.append(c["art"])
			return hats
		"extra": return Chars.EXTRAS
		"clothes": return Chars.CLOTHES
	return []


static func build(m: Modal, on_done: Callable) -> void:
	m.title(tr_("AVATAR"))
	var preview := AvatarPreview.new()
	preview.custom_minimum_size = Vector2(0, 230)
	m.add(preview)
	for p in PARTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var left := Button.new()
		left.theme_type_variation = &"BlueButton"
		left.icon = Icons.get_icon("left", 30)
		left.custom_minimum_size = Vector2(64, 60)
		var label := Label.new()
		label.theme_type_variation = &"InkLabel"
		label.add_theme_font_override("font", UiTheme.heavy_font())
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = tr_(p[0])
		var right := Button.new()
		right.theme_type_variation = &"BlueButton"
		right.icon = Icons.get_icon("right", 30)
		right.custom_minimum_size = Vector2(64, 60)
		left.pressed.connect(_step.bind(p[1], -1, preview))
		right.pressed.connect(_step.bind(p[1], 1, preview))
		row.add_child(left)
		row.add_child(label)
		row.add_child(right)
		m.add(row)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	var dice := Button.new()
	dice.theme_type_variation = &"PurpleButton"
	dice.icon = Icons.get_icon("dice", 36)
	dice.custom_minimum_size = Vector2(90, 76)
	dice.pressed.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		Settings.set_avatar(Chars.random_look(rng))
		preview.cheer()
		Sfx.play("pop"))
	var done := Button.new()
	done.text = tr_("DONE")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size.y = 76
	done.pressed.connect(func(): Sfx.play("click"); on_done.call())
	bottom.add_child(dice)
	bottom.add_child(done)
	m.add(bottom)


static func _step(part: String, dir: int, preview: AvatarPreview) -> void:
	var look := Settings.avatar.duplicate()
	var opts := _options(part)
	var i := opts.find(look.get(part))
	look[part] = opts[posmod(i + dir, opts.size())]
	Settings.set_avatar(look)
	if part == "hat":
		# Keep the wardrobe's "wearing" mark in step.
		Progress.equipped["hat"] = ""
		for c in Content.COSMETICS:
			if c["slot"] == "hat" and c["art"] == look["hat"]:
				Progress.equipped["hat"] = c["id"]
	preview.cheer()
	Sfx.play("pop")


static func tr_(key: String) -> String:
	return TranslationServer.translate(key)
