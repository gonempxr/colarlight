extends Node
## Device settings: language, volumes, vibration, graphics, motion, UI size,
## number style. Saved apart from game progress so resetting progress keeps
## them. The player's look belongs to their profile (see Profiles), but is
## mirrored here as `avatar` for drawing code. Registered as the Settings autoload.

signal changed

const LANGUAGES: Array[String] = ["en", "ru", "es", "zh"]
const LANGUAGE_NAMES := {"en": "English", "ru": "Русский", "es": "Español", "zh": "中文"}
const QUALITIES: Array[String] = ["auto", "high", "low"]
const UI_SCALES: Array[float] = [1.0, 1.12, 1.25]
const PATH := "user://settings.cfg"

var language := ""
var sfx_volume := 0.8
var music_volume := 0.6
var voices := true
var vibration := true
var quality := "auto"
## Set by FrameGovernor for this session when "auto" found the device slow:
## low quality as if chosen (not saved).
var auto_low := false:
	set(v):
		if v == auto_low:
			return
		auto_low = v
		if OS.has_feature("web") and quality == "auto":
			JavaScriptBridge.eval("window.coralightPixelCap = %s; window.dispatchEvent(new Event('resize'));" % ("1.5" if v else "2"), true)
var reduce_motion := false
var ui_scale := 1.0
## "short" = 1.2K, 3.4M; "sci" = 1.2e3.
var number_style := "short"
## PC: the cartoon glove cursor (hidden on touch screens).
var hand_cursor := true
var avatar: Dictionary = Chars.default_avatar()

var sound: bool:
	get:
		return sfx_volume > 0.01
var music: bool:
	get:
		return music_volume > 0.01


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		language = str(cfg.get_value("ui", "language", ""))
		# Old saves kept on/off switches.
		sfx_volume = _vol(cfg.get_value("audio", "sfx_volume", 0.8 if cfg.get_value("audio", "sound", true) == true else 0.0))
		music_volume = _vol(cfg.get_value("audio", "music_volume", 0.6 if cfg.get_value("audio", "music", true) == true else 0.0))
		voices = cfg.get_value("audio", "voices", true) == true
		vibration = cfg.get_value("ui", "vibration", true) == true
		quality = str(cfg.get_value("graphics", "quality", "auto"))
		reduce_motion = cfg.get_value("ui", "reduce_motion", false) == true
		var sc = cfg.get_value("ui", "scale", 1.0)
		ui_scale = float(sc) if (sc is float or sc is int) else 1.0
		number_style = str(cfg.get_value("ui", "numbers", "short"))
		hand_cursor = cfg.get_value("ui", "hand_cursor", true) == true
	if language not in LANGUAGES:
		language = detect_language()
	if quality not in QUALITIES:
		quality = "auto"
	if number_style not in ["short", "sci"]:
		number_style = "short"
	ui_scale = _closest_scale(ui_scale)
	_sync_web_quality()
	NumFormat.sci = number_style == "sci"
	TranslationServer.set_locale(language)
	reload_avatar()


static func _vol(v: Variant) -> float:
	return clampf(float(v), 0.0, 1.0) if (v is float or v is int) else 0.8


static func _closest_scale(v: float) -> float:
	var best := 1.0
	for s in UI_SCALES:
		if absf(s - v) < absf(best - v):
			best = s
	return best


static func detect_language() -> String:
	var lang := OS.get_locale_language()
	return lang if lang in LANGUAGES else "en"


func reload_avatar() -> void:
	var profiles := get_node_or_null("/root/Profiles")
	avatar = sanitize_look(profiles.avatar() if profiles else {})
	changed.emit()


func set_language(lang: String) -> void:
	if lang not in LANGUAGES:
		return
	language = lang
	TranslationServer.set_locale(lang)
	_save()


func next_language() -> void:
	set_language(LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()])


func set_sound(on: bool) -> void:
	sfx_volume = 0.8 if on else 0.0
	_save()


func set_music(on: bool) -> void:
	music_volume = 0.6 if on else 0.0
	_save()


func set_value(key: String, value: Variant) -> void:
	match key:
		"sfx_volume":
			sfx_volume = _vol(value)
		"music_volume":
			music_volume = _vol(value)
		"voices":
			voices = value == true
		"vibration":
			vibration = value == true
		"quality":
			if str(value) in QUALITIES:
				quality = str(value)
				_sync_web_quality()
		"reduce_motion":
			reduce_motion = value == true
		"hand_cursor":
			hand_cursor = value == true
		"ui_scale":
			ui_scale = _closest_scale(float(value))
		"number_style":
			if str(value) in ["short", "sci"]:
				number_style = str(value)
				NumFormat.sci = number_style == "sci"
		_:
			return
	_save()


## The web page draws the canvas at the screen's pixel ratio capped at 2,
## or at 1.5 when the player chose low quality (tools/web_shell): it reads
## the choice from localStorage at start, and a change applies at once.
func _sync_web_quality() -> void:
	if not OS.has_feature("web"):
		return
	var low := quality == "low"
	JavaScriptBridge.eval("try { localStorage.setItem('coralight_quality', '%s'); } catch (e) {} window.coralightPixelCap = %s;"
			% [quality, "1.5" if low else "2"], true)


## Low quality drops soft outline edges and animates the scene a little
## slower (the main screen applies it to Art and World).
func low_quality() -> bool:
	var phone := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	return (phone or auto_low) if quality == "auto" else quality == "low"


## A short buzz on phones that support it.
func buzz(ms: int = 25) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


func set_avatar(look: Dictionary) -> void:
	avatar = sanitize_look(look)
	var profiles := get_node_or_null("/root/Profiles")
	if profiles:
		profiles.set_avatar(avatar)
	changed.emit()


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
		var allowed: Array = {"hair": Chars.HAIR_STYLES, "hat": Chars.HATS + HatsArt.IDS, "extra": Chars.EXTRAS, "clothes": Chars.CLOTHES}[k]
		if str(d.get(k, "")) in allowed:
			out[k] = str(d[k])
	return out


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "language", language)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "voices", voices)
	cfg.set_value("ui", "vibration", vibration)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("ui", "reduce_motion", reduce_motion)
	cfg.set_value("ui", "scale", ui_scale)
	cfg.set_value("ui", "numbers", number_style)
	cfg.set_value("ui", "hand_cursor", hand_cursor)
	cfg.save(PATH)
	changed.emit()
