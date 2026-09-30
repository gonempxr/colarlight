extends Node
## Local player profiles: each child (or grown-up) on the same device gets a
## name, a look and their own saves. Registered as the Profiles autoload,
## before everything that saves.
##
## Files: user://profiles.cfg lists the profiles; each profile's saves live
## in user://p/<id>/ (game.json for GameState, progress.json for Progress).
## A save from before profiles (user://coralight2.json) moves into the first
## profile, so nobody loses progress.

signal switched

const LIST_PATH := "user://profiles.cfg"
const OLD_SAVE := "user://coralight2.json"
const MAX_PROFILES := 6
const NAME_MAX := 16

## [{"id": String, "name": String, "avatar": Dictionary, "created": float}]
var list: Array = []
var current_id := ""


func _ready() -> void:
	_import_main_saves()
	_load()
	if list.is_empty():
		var p := _make("")
		list.append(p)
		current_id = p["id"]
		_migrate_old_save(p["id"])
		_save()
	if find(current_id).is_empty():
		current_id = list[0]["id"]


func current() -> Dictionary:
	return find(current_id)


func find(id: String) -> Dictionary:
	for p in list:
		if p["id"] == id:
			return p
	return {}


func player_name() -> String:
	return str(current().get("name", ""))


## Path of a save file inside the current profile's folder.
func file(name: String) -> String:
	var dir := "user://p/%s" % current_id
	DirAccess.make_dir_recursive_absolute(dir)
	return dir + "/" + name


## Cleans a typed name: trims, drops control characters, caps the length.
static func clean_name(value: String) -> String:
	var out := ""
	for ch in value.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.strip_edges().left(NAME_MAX)


func set_name_of(id: String, value: String) -> void:
	var p := find(id)
	if p.is_empty():
		return
	p["name"] = clean_name(value)
	_save()


func avatar() -> Dictionary:
	return current().get("avatar", Chars.default_avatar())


func set_avatar(look: Dictionary) -> void:
	var p := current()
	if not p.is_empty():
		p["avatar"] = look
		_save()


func can_add() -> bool:
	return list.size() < MAX_PROFILES


## Adds a profile with a random look and returns its id ("" when full).
func add(name: String) -> String:
	if not can_add():
		return ""
	var p := _make(clean_name(name))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	p["avatar"] = Chars.random_look(rng)
	list.append(p)
	_save()
	return p["id"]


## Deletes a profile and its saves. The last profile can't be removed.
func remove(id: String) -> bool:
	if list.size() <= 1 or find(id).is_empty():
		return false
	var dir := "user://p/%s" % id
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)
	list = list.filter(func(p): return p["id"] != id)
	if current_id == id:
		select(list[0]["id"])
	_save()
	return true


## Saves the running game, then loads the chosen profile's game.
func select(id: String) -> void:
	if find(id).is_empty() or id == current_id:
		return
	_save_all()
	current_id = id
	_save()
	_load_all()
	if has_node("/root/Fishing"): get_node("/root/Fishing").switch_profile()
	switched.emit()


func _save_all() -> void:
	for n in ["GameState", "Progress"]:
		var node := get_node_or_null("/root/" + n)
		if node and node.autosave_enabled:
			node.save_game()


func _load_all() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings:
		settings.reload_avatar()
	for n in ["GameState", "Progress"]:
		var node := get_node_or_null("/root/" + n)
		if node:
			node.switch_profile()


func _make(name: String) -> Dictionary:
	var id := "%d%03d" % [int(Time.get_unix_time_from_system()) % 100000000, randi() % 1000]
	while not find(id).is_empty():
		id = str(randi() % 100000000)
	return {"id": id, "name": name, "avatar": Chars.default_avatar(), "created": Time.get_unix_time_from_system()}


## A test build exported with its own save folder (custom user dir) starts
## from a copy of the main build's saves, so a player can try it with their
## progress. The main build's files are only read, never written.
func _import_main_saves() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		return
	if FileAccess.file_exists(LIST_PATH) or FileAccess.file_exists("user://imported.txt"):
		return
	var base := OS.get_user_data_dir().get_base_dir()
	var app := str(ProjectSettings.get_setting("application/config/name", ""))
	for godot_dir in ["godot", "Godot"]:
		var main_dir: String = base.path_join(godot_dir).path_join("app_userdata").path_join(app)
		if FileAccess.file_exists(main_dir.path_join("profiles.cfg")):
			_copy_dir(main_dir, "user://")
			print("Imported saves from ", main_dir)
			break
	var mark := FileAccess.open("user://imported.txt", FileAccess.WRITE)
	if mark:
		mark.store_string("done")


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for f in DirAccess.get_files_at(from):
		if not f.ends_with(".tmp"):
			DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d in DirAccess.get_directories_at(from):
		_copy_dir(from.path_join(d), to.path_join(d))


func _migrate_old_save(id: String) -> void:
	# Before profiles the look lived in settings.cfg.
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("player", "avatar"):
		list[0]["avatar"] = cfg.get_value("player", "avatar")
	if FileAccess.file_exists(OLD_SAVE):
		var dir := "user://p/%s" % id
		DirAccess.make_dir_recursive_absolute(dir)
		DirAccess.copy_absolute(OLD_SAVE, dir + "/game.json")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LIST_PATH) != OK:
		return
	var saved = cfg.get_value("profiles", "list", [])
	if saved is Array:
		for p in saved:
			if p is Dictionary and p.get("id") is String and p["id"] != "":
				list.append({"id": p["id"], "name": clean_name(str(p.get("name", ""))),
						"avatar": p.get("avatar", {}) if p.get("avatar") is Dictionary else {},
						"created": float(p.get("created", 0.0)) if (p.get("created") is float or p.get("created") is int) else 0.0})
			if list.size() >= MAX_PROFILES:
				break
	current_id = str(cfg.get_value("profiles", "current", ""))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profiles", "list", list)
	cfg.set_value("profiles", "current", current_id)
	cfg.save(LIST_PATH)
