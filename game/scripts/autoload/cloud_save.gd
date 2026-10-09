extends Node
## Mirrors the save files into the cloud, so progress follows the player
## across devices. Registered as the first autoload, before Profiles reads
## anything. Two clouds, both kept by the web shell:
## - CrazyGames: its Data Module (window.coralightAds), always on there.
## - Our own site: the player's Google account (window.coralightCloud,
##   Firebase), once they sign in from the settings.
## Elsewhere the saves stay in the browser as before.
##
## The shell reads the cloud before the engine starts and leaves it in
## `cloudBlob`; `cloudSave(text)` writes it back. One JSON blob
## {"t": newest file time, "files": {path: text}} holds every save file
## (a few KB, both clouds allow about 1 MB).

## A sign-in from the settings finished: "ok", "ask" (both this device and
## the account have progress: see ask_info, use_cloud, keep_local) or
## "error:<code>".
signal sign_in_done(result: String)
## Signed in or out (the settings show the account).
signal account_changed

const PUSH_SEC := 15.0
## Google (Firestore) has a daily write budget on the free plan.
const GOOGLE_PUSH_SEC := 60.0
const MAX_BYTES := 900000
const ROOT_FILES := ["profiles.cfg", "settings.cfg", "rivals.json", "fishing.json", "imported.txt"]

var _left := PUSH_SEC
var _last_pushed := ""
var _sign_in_cb: JavaScriptObject
## The account's saves while the player picks which progress to keep.
var _asked := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	var bridge := _bridge()
	if bridge != "":
		var blob := str(JavaScriptBridge.eval("String(window.%s.cloudBlob || '')" % bridge, true))
		var force := str(JavaScriptBridge.eval("window.%s.force ? 'y' : ''" % bridge, true)) == "y"
		if blob != "":
			restore(blob, force)
	_last_pushed = _pack(collect())


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = GOOGLE_PUSH_SEC if _bridge() == "coralightCloud" else PUSH_SEC
		push()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		push()


## Writes the saves to the cloud when they changed since the last write.
func push(force: bool = false) -> void:
	var name := _bridge()
	if name == "":
		return
	var data := collect()
	var key := _pack(data)
	var text := JSON.stringify(data)
	if (key == _last_pushed and not force) or text.length() > MAX_BYTES:
		return
	# Never overwrite the account while the player is choosing.
	if _asked != "" and not force:
		return
	_last_pushed = key
	var bridge = JavaScriptBridge.get_interface(name)
	if bridge != null:
		bridge.cloudSave(text)


# --- Google account (our own site) ----------------------------------------------

## The site offers a Google sign-in (not on CrazyGames, not offline).
func google_available() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("(window.coralightCloud && window.coralightCloud.state !== 'failed') ? 'y' : ''", true)) == "y"


## The signed-in account's name ("" when signed out).
func google_user() -> String:
	if not google_available():
		return ""
	return str(JavaScriptBridge.eval("window.coralightCloud.state === 'in' ? String(window.coralightCloud.user || '?') : ''", true))


func google_sign_in() -> void:
	var bridge = JavaScriptBridge.get_interface("coralightCloud") if OS.has_feature("web") else null
	if bridge == null:
		sign_in_done.emit("error:unavailable")
		return
	_sign_in_cb = JavaScriptBridge.create_callback(_on_signed_in)
	bridge.signIn(_sign_in_cb)


func google_sign_out() -> void:
	var bridge = JavaScriptBridge.get_interface("coralightCloud") if OS.has_feature("web") else null
	if bridge != null:
		push()
		bridge.signOut()
	account_changed.emit()


func _on_signed_in(args: Array) -> void:
	var result := str(args[0]) if args.size() > 0 else "error:other"
	if not result.begins_with("blob:"):
		sign_in_done.emit(result)
		return
	account_changed.emit()
	sign_in_done.emit(after_sign_in(result.trim_prefix("blob:")))


## What to do with the account's saves right after signing in: none yet or
## the same as here - keep this device's ("ok"); this device has nothing -
## take the account's (the game restarts); both differ - ask the player.
func after_sign_in(blob: String) -> String:
	var cloud := _files_of(blob)
	var local := collect()
	if cloud.is_empty() or JSON.stringify(cloud, "", true) == _pack(local):
		push(true)
		return "ok"
	if local["files"].is_empty():
		use_cloud_blob(blob)
		return "ok"
	_asked = blob
	return "ask"


## {"cloud": unix time, "here": unix time} of the two saves being compared.
func ask_info() -> Dictionary:
	var data = JSON.parse_string(_asked) if _asked != "" else null
	var t := int(data.get("t", 0)) if typeof(data) == TYPE_DICTIONARY else 0
	return {"cloud": t, "here": int(collect()["t"])}


## Takes the account's progress: the page restarts with it.
func use_cloud() -> void:
	use_cloud_blob(_asked)


func use_cloud_blob(blob: String) -> void:
	var bridge = JavaScriptBridge.get_interface("coralightCloud") if OS.has_feature("web") else null
	if bridge != null:
		bridge.useCloud(blob)


## Keeps this device's progress: it replaces the account's.
func keep_local() -> void:
	_asked = ""
	push(true)


## The question was closed without an answer: sign out, both saves stay as they are.
func cancel_ask() -> void:
	if _asked == "":
		return
	_asked = ""
	var bridge = JavaScriptBridge.get_interface("coralightCloud") if OS.has_feature("web") else null
	if bridge != null:
		bridge.signOut()
	account_changed.emit()


func is_asking() -> bool:
	return _asked != ""


func _files_of(blob: String) -> Dictionary:
	if blob == "":
		return {}
	var data = JSON.parse_string(blob)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("files")) != TYPE_DICTIONARY:
		return {}
	return data["files"]


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
## on this device (or nothing is here yet, or `force`). Returns true when it did.
func restore(blob: String, force: bool = false) -> bool:
	var data = JSON.parse_string(blob)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("files")) != TYPE_DICTIONARY:
		return false
	var local := collect()
	var files: Dictionary = data["files"]
	if files.is_empty() or (not force and not local["files"].is_empty() and int(data.get("t", 0)) <= int(local["t"])):
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


## The cloud in use now: "coralightAds" (CrazyGames), "coralightCloud" (signed
## in with Google) or "".
func _bridge() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("(window.coralightAds && window.coralightAds.state === 'ready') ? 'coralightAds' : ((window.coralightCloud && window.coralightCloud.state === 'in') ? 'coralightCloud' : '')", true))
