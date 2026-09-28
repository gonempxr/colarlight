extends Node
## Player settings: language, sound, music. Saved apart from game progress
## so resetting progress keeps them. Registered as the Settings autoload.

signal changed

const LANGUAGES: Array[String] = ["en", "ru", "es", "zh"]
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский", "es": "Español", "zh": "中文"}
const PATH := "user://settings.cfg"

var language := ""
var sound := true
var music := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		language = str(cfg.get_value("ui", "language", ""))
		sound = cfg.get_value("audio", "sound", true) == true
		music = cfg.get_value("audio", "music", true) == true
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


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "language", language)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "music", music)
	cfg.save(PATH)
	changed.emit()
