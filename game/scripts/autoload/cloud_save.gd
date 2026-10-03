extends Node
## Mirrors the save files into the CrazyGames Data Module, so progress follows
## the player across devices. Registered as the first autoload, before
## Profiles reads anything. Only active on CrazyGames; elsewhere the saves
## stay in the browser as before.
##
## The shell (window.coralightAds) reads the SDK data before the engine
## starts and leaves it in `cloudBlob`; `cloudSave(text)` writes it back.
## One JSON blob {"t": newest file time, "files": {path: text}} holds every
## save file (a few KB, the SDK allows 1 MB).

const PUSH_SEC := 15.0
const MAX_BYTES := 900000
const ROOT_FILES := ["profiles.cfg", "settings.cfg", "rivals.json", "fishing.json", "imported.txt"]

var _left := PUSH_SEC
var _last_pushed := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _active():
		set_process(false)
		return
	var blob := str(JavaScriptBridge.eval("String((window.coralightAds && window.coralightAds.cloudBlob) || '')", true))
	if blob != "":
		restore(blob)
	_last_pushed = _pack(collect())


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = PUSH_SEC
		push()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _active():
			push()


## Writes the saves to the SDK when they changed since the last write.
func push() -> void:
	var data := collect()
	var key := _pack(data)
	var text := JSON.stringify(data)
	if key == _last_pushed or text.length() > MAX_BYTES:
		return
	_last_pushed = key
	var bridge = JavaScriptBridge.get_interface("coralightAds")
	if bridge != null:
		bridge.cloudSave(text)


## {"t": newest modified time, "files": {"p/ab/game.json": text}} of everything
## under user:// that the game saves.
func collect() -> Dictionary:
	var files := {}
	var newest := 0
	for name in ROOT_FILES:
		newest = maxi(newest, _read_into(files, name))
	var dirs := DirAccess.open("user://p")
	if dirs != null:
		for id in dirs.get_directories():
			var inner := DirAccess.open("user://p/%s" % id)
			if inner == null:
				continue
			for f in inner.get_files():
				newest = maxi(newest, _read_into(files, "p/%s/%s" % [id, f]))
	return {"t": newest, "files": files}


## Copies the files from the blob into user:// when it is newer than what is
## on this device (or nothing is here yet). Returns true when it did.
func restore(blob: String) -> bool:
	var data = JSON.parse_string(blob)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("files")) != TYPE_DICTIONARY:
		return false
	var local := collect()
	var files: Dictionary = data["files"]
	if files.is_empty() or (not local["files"].is_empty() and int(data.get("t", 0)) <= int(local["t"])):
		return false
	for path in files:
		var rel := str(path)
		if rel.contains("..") or rel.begins_with("/"):
			continue
		var full := "user://" + rel
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		var f := FileAccess.open(full, FileAccess.WRITE)
		if f != null:
			f.store_string(str(files[path]))
	return true


func _read_into(files: Dictionary, rel: String) -> int:
	var full := "user://" + rel
	if not FileAccess.file_exists(full):
		return 0
	files[rel] = FileAccess.get_file_as_string(full)
	return int(FileAccess.get_modified_time(full))


func _pack(data: Dictionary) -> String:
	# The time is left out so only real changes cause a write.
	return JSON.stringify(data["files"], "", true)


func _active() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("(window.coralightAds && window.coralightAds.state === 'ready') ? 'y' : ''", true)) == "y"
