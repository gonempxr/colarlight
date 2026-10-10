extends SceneTree
## Cloud save mirror: collecting the files and restoring them on a fresh device.

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _write(rel: String, text: String) -> void:
	var full := "user://" + rel
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var f := FileAccess.open(full, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe() -> void:
	for rel in ["profiles.cfg", "settings.cfg", "rivals.json", "fishing.json", "p/a1/game.json", "p/a1/progress.json"]:
		DirAccess.remove_absolute("user://" + rel)


func _init() -> void:
	var cs = load("res://scripts/autoload/cloud_save.gd").new()
	_wipe()
	_write("profiles.cfg", "[x]\na=1\n")
	_write("p/a1/game.json", "{\"coins\": 5}")
	_write("p/a1/progress.json", "{\"pearls\": 2}")
	var data: Dictionary = cs.collect()
	_check(data["files"].size() == 3, "collects 3 files, got %d" % data["files"].size())
	_check(data["files"].has("p/a1/game.json"), "has profile save")
	var blob := JSON.stringify(data)

	# Same device: nothing newer, no restore.
	_check(not cs.restore(blob), "no restore on the same device")

	# Fresh device: files come back.
	_wipe()
	_check(cs.restore(blob), "restores on an empty device")
	_check(FileAccess.get_file_as_string("user://p/a1/game.json") == "{\"coins\": 5}", "game.json restored")
	_check(FileAccess.get_file_as_string("user://profiles.cfg") == "[x]\na=1\n", "profiles.cfg restored")

	# Older cloud copy does not overwrite newer local files.
	var old := JSON.stringify({"t": 1, "files": {"p/a1/game.json": "{\"coins\": 1}"}})
	_check(not cs.restore(old), "older cloud copy ignored")
	_check(FileAccess.get_file_as_string("user://p/a1/game.json") == "{\"coins\": 5}", "local kept")

	# Newer cloud copy wins.
	var newer := JSON.stringify({"t": int(Time.get_unix_time_from_system()) + 1000, "files": {"p/a1/game.json": "{\"coins\": 9}"}})
	_check(cs.restore(newer), "newer cloud copy restores")
	_check(FileAccess.get_file_as_string("user://p/a1/game.json") == "{\"coins\": 9}", "cloud value written")

	# A forced restore (the player chose the account's saves) beats newer local files.
	_check(cs.restore(old, true), "forced restore applies an older copy")
	_check(FileAccess.get_file_as_string("user://p/a1/game.json") == "{\"coins\": 1}", "forced value written")

	# Right after a Google sign-in.
	_write("p/a1/game.json", "{\"coins\": 5}")
	_check(cs.after_sign_in("") == "ok", "empty account: keep this device")
	_check(cs.after_sign_in(JSON.stringify(cs.collect())) == "ok", "same saves: nothing to ask")
	_check(not cs.is_asking(), "not asking after ok")
	var other := JSON.stringify({"t": 123, "files": {"p/a1/game.json": "{\"coins\": 77}"}})
	_check(cs.after_sign_in(other) == "ask", "different saves: ask")
	_check(cs.is_asking(), "asking")
	_check(int(cs.ask_info()["cloud"]) == 123, "ask_info has the account's time")
	cs.cancel_ask()
	_check(not cs.is_asking(), "cancel stops asking")
	_check(FileAccess.get_file_as_string("user://p/a1/game.json") == "{\"coins\": 5}", "cancel keeps local files")
	cs.after_sign_in(other)
	cs.keep_local()
	_check(not cs.is_asking(), "keep_local stops asking")

	# Bad input and path tricks.
	_check(not cs.restore("not json"), "garbage ignored")
	var evil := JSON.stringify({"t": 99999999999, "files": {"../evil.txt": "x"}})
	cs.restore(evil)
	_check(not FileAccess.file_exists("user://../evil.txt"), "path escape blocked")
	_wipe()
	print("cloud tests: ", "OK" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
