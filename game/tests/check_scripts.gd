extends SceneTree
## Compiles every script and prints the ones that fail:
##   godot --headless --path . -s res://tests/check_scripts.gd

func _initialize() -> void:
	await process_frame
	var bad := 0
	for dir in ["res://scripts/ui", "res://scripts/puzzle", "res://scripts/data", "res://scripts/util", "res://scripts/autoload"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: GDScript = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					print("BROKEN: ", dir + "/" + f)
					bad += 1
	print("%d broken" % bad)
	quit(1 if bad > 0 else 0)
