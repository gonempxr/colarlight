class_name OceanLook
extends RefCounted
## Old name of WorldLook (one look per ocean before the worlds update),
## kept as a thin alias for older callers. New code uses WorldLook.

## The location the colors were built for (WorldLook.location).
static var ocean: int:
	get:
		return WorldLook.location


static func apply(n: int) -> bool:
	return WorldLook.apply(n)


static func look_of(n: int) -> Dictionary:
	return WorldLook.look_of(n)


static func name_of(n: int) -> String:
	return WorldLook.name_of(n)


static func color(key: String) -> Color:
	return WorldLook.color(key)


static func has(key: String) -> bool:
	return WorldLook.has(key)


static func room_style(i: int) -> Dictionary:
	return WorldLook.room_style(i)
