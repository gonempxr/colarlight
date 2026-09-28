extends Node
## Player settings: language, sound, music and the player's avatar look. Saved apart from game progress
## so resetting progress keeps them. Registered as the Settings autoload.

signal changed

const LANGUAGES: Array[String] = ["en", "ru", "es", "zh"]
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский", "es": "Español", "zh": "中文"}
const PATH := "user://settings.cfg"

var language := ""
var sound := true
var music := true
var avatar: Dictionary = Chars.default_avatar()


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		language = str(cfg.get_value("ui", "language", ""))
		sound = cfg.get_value("audio", "sound", true) == true
		music = cfg.get_value("audio", "music", true) == true
		avatar = sanitize_look(cfg.get_value("player", "avatar", {}))
	if language not in LANGUAGES:
		language = detect_language()
	TranslationServer.set_locale(language)


static func detect_language() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LANGUAGES else "en"


func set_language(lang: String) -> void:
	if lang not in LANGUAGES:
		return
	language = lang
	TranslationServer.set_locale(lang)
	_save()


func next_language() -> void:
	set_language(LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()])


func set_sound(on: bool) -> void:
	sound = on
	_save()


func set_music(on: bool) -> void:
	music = on
	_save()


func set_avatar(look: Dictionary) -> void:
	avatar = sanitize_look(look)
	_save()


## Any stored look becomes a valid one: unknown parts fall back to defaults.
static func sanitize_look(value: Variant) -> Dictionary:
	var out := Chars.default_avatar()
	if not value is Dictionary:
		return out
	var d: Dictionary = value
	for k in ["skin", "hair_color", "outfit"]:
		if d.get(k) is int or d.get(k) is float:
			out[k] = clampi(int(d[k]), 0, {"skin": Chars.SKINS, "hair_color": Chars.HAIR_COLORS, "outfit": Chars.OUTFITS}[k].size() - 1)
	for k in ["hair", "hat", "extra", "clothes"]:
		var allowed: Array = {"hair": Chars.HAIR_STYLES, "hat": Chars.HATS, "extra": Chars.EXTRAS, "clothes": Chars.CLOTHES}[k]
		if str(d.get(k, "")) in allowed:
			out[k] = str(d[k])
	return out


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "language", language)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "music", music)
	cfg.set_value("player", "avatar", avatar)
	cfg.save(PATH)
	changed.emit()
