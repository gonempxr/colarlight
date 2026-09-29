extends Node
## All audio: sound effects from a small player pool, character voices,
## the underwater ambience and the music loop. Registered as the Sfx
## autoload. Sounds follow Settings.sfx_volume, music follows Settings.music_volume.
##
## Each sound has a volume, a pitch spread (so repeats don't sound
## robotic) and a minimum gap, so busy moments never turn into noise.

const DIR := "res://assets/audio/"
const POOL := 12
const MUSIC_DB := -9.0
const AMBIENCE_DB := -17.0

## name: [volume dB, pitch spread, minimum seconds between plays]
const SOUNDS := {
	"click": [-8.0, 0.05, 0.03],
	"pop": [-8.0, 0.12, 0.03],
	"tap": [-10.0, 0.15, 0.04],
	"deny": [-9.0, 0.0, 0.15],
	"upgrade": [-7.0, 0.03, 0.06],
	"hire": [-5.0, 0.0, 0.2],
	"unlock": [-4.0, 0.0, 0.3],
	"dive": [-9.0, 0.1, 0.12],
	"dig": [-17.0, 0.15, 0.09],
	"horn": [-11.0, 0.03, 0.8],
	"machine": [-15.0, 0.05, 0.6],
	"coins": [-11.0, 0.08, 0.35],
	"milestone": [-5.0, 0.0, 0.4],
	"rush": [-6.0, 0.0, 0.5],
	"prestige": [-3.0, 0.0, 1.0],
	"chest": [-6.0, 0.0, 0.3],
	"start": [-5.0, 0.0, 0.5],
	"voice_wow": [-12.0, 0.15, 0.5],
	"voice_yay": [-12.0, 0.15, 0.4],
	"voice_woohoo": [-11.0, 0.1, 0.8],
	"voice_hmm": [-14.0, 0.1, 1.0],
	"voice_ooh": [-13.0, 0.12, 1.2],
	"voice_hup": [-16.0, 0.2, 0.3],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_wanted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in SOUNDS:
		var path: String = DIR + name + ".ogg"
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = _loop_player("music", MUSIC_DB)
	_ambience = _loop_player("ambience", AMBIENCE_DB)
	Settings.changed.connect(_apply_settings)


func _loop_player(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path: String = DIR + name + ".ogg"
	if ResourceLoader.exists(path):
		var s: AudioStreamOggVorbis = load(path)
		s.loop = true
		p.stream = s
	p.volume_db = db
	add_child(p)
	return p


func play(name: String, pitch: float = 1.0) -> void:
	if not Settings.sound or not _streams.has(name):
		return
	if name.begins_with("voice_") and not Settings.voices:
		return
	var cfg: Array = SOUNDS[name]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -99.0)) < float(cfg[2]):
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = cfg[0] + linear_to_db(Settings.sfx_volume)
	p.pitch_scale = pitch * (1.0 + randf_range(-cfg[1], cfg[1]))
	p.play()


## A character voice line at a random, character-like pitch.
func voice(name: String, pitch: float = 1.0) -> void:
	play("voice_" + name, pitch)


## Called on the first user tap (browsers block audio before one).
func start_music() -> void:
	_music_wanted = true
	_apply_settings()


func _apply_settings() -> void:
	_music.volume_db = MUSIC_DB + linear_to_db(maxf(0.001, Settings.music_volume))
	_ambience.volume_db = AMBIENCE_DB + linear_to_db(maxf(0.001, Settings.sfx_volume))
	if _music.stream:
		var on := _music_wanted and Settings.music
		if on and not _music.playing:
			_music.play()
		elif not on and _music.playing:
			_music.stop()
	if _ambience.stream:
		var amb := _music_wanted and Settings.sound
		if amb and not _ambience.playing:
			_ambience.play()
		elif not amb and _ambience.playing:
			_ambience.stop()
