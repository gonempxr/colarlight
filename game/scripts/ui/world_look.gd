class_name WorldLook
extends RefCounted
## The look of the current location: which world it is (ocean, volcano,
## acid swamp, moon), its colors (sky by day and night, the "sea" on the
## surface, the shaft, the ground) and its ten work sites.
##
## Location L (GameState.location) is world WORLDS[L % 4] at tier L / 4.
## Tier 0 is the hand-made look; later tiers turn the hues a little and add
## a star badge to the name ("Volcano ★2").
##
## World calls apply() when the location changes; the drawing code reads
## the colors from here (and from Art.sea_cols, Art.DEPTH_STYLE and the
## DayNight sky stops that apply() sets).

const WORLDS: Array[String] = ["ocean", "volcano", "acid", "moon"]

## Ten work sites per world (keys d0..d9), deepest last.
const SITES := {
	"ocean": ["shells", "coral", "pearl", "copper", "emerald", "crystal", "gold", "glow", "atlantis", "heart"],
	"volcano": ["ash", "obsidian", "sulfur", "ruby", "magma", "fire_opal", "garnet", "ember", "phoenix", "dragon"],
	"acid": ["slime", "moss", "shroom", "bubble", "venom", "amber", "radiant", "jade", "orchid", "goo_king"],
	"moon": ["dust", "meteor", "crater_ice", "moonstone", "star", "comet", "nebula", "alien_egg", "ufo", "cosmic_heart"],
}

## sea: the medium on the surface and above the first site, top to deep.
## shaft: the lift shaft and cave air (air worlds) from top to bottom.
## day / night: sky stops [top, middle, horizon]. dusk: how much sunrise
## and sunset color the sky gets. ground / ground_dark / top: the shore.
## seabed: the bottom under the last site. water: the rooms hold water.
const LOOKS := {
	"ocean": {
		"name": "WORLD_OCEAN",
		"sea": [Color("35c9d2"), Color("1c88b6"), Color("165290"), Color("0e2654")],
		"shaft": [Color("35c9d2"), Color("1c88b6"), Color("165290"), Color("0e2654")],
		"day": [Color("4fb3ee"), Color("8fd2f7"), Color("c9eeff")],
		"night": [Color("0e1440"), Color("1b2862"), Color("33467f")],
		"dusk": 1.0, "night_tint": Color(0.60, 0.66, 0.90),
		"sand": Color("f8d898"), "sand_dark": Color("e2aa62"), "grass": Color("72d25a"),
		"seabed": Color("2a2f5e"), "weed": Color("47c47a"), "water": true, "far": Color("9fd4ee"),
	},
	"volcano": {
		"name": "WORLD_VOLCANO",
		"sea": [Color("ffc43a"), Color("ff7a1e"), Color("c8361e"), Color("5a1418")],
		"shaft": [Color("6e4c4a"), Color("5a3c40"), Color("452c34"), Color("2e1c26")],
		"day": [Color("d86a5e"), Color("ffa070"), Color("ffd9a0")],
		"night": [Color("1c0a1e"), Color("3c1428"), Color("7a2a2c")],
		"dusk": 0.45, "night_tint": Color(0.72, 0.60, 0.70),
		"sand": Color("5c5262"), "sand_dark": Color("433a4c"), "grass": Color("8a7e8c"),
		"seabed": Color("2a1a22"), "weed": Color("ff7a2a"), "water": false, "far": Color("8a5a66"),
	},
	"acid": {
		"name": "WORLD_ACID",
		"sea": [Color("a6e04a"), Color("5aaa3a"), Color("2f6e3e"), Color("143a2c")],
		"shaft": [Color("4e6648"), Color("3e5640"), Color("2e4436"), Color("1c2e26")],
		"day": [Color("5eb8a0"), Color("a8e0a0"), Color("eef8c0")],
		"night": [Color("081a20"), Color("10302e"), Color("1e4a3a")],
		"dusk": 0.7, "night_tint": Color(0.58, 0.72, 0.78),
		"sand": Color("7a6244"), "sand_dark": Color("5c4830"), "grass": Color("6cc24a"),
		"seabed": Color("1a2a22"), "weed": Color("5ad84a"), "water": false, "far": Color("6a9a82"),
	},
	"moon": {
		"name": "WORLD_MOON",
		"sea": [Color("8f9cc4"), Color("7280ac"), Color("56618e"), Color("3a4268")],
		"shaft": [Color("4a5068"), Color("3c4158"), Color("2e3248"), Color("1e2134")],
		"day": [Color("0c1236"), Color("1e2862"), Color("3a4a8a")],
		"night": [Color("03040f"), Color("090c24"), Color("161c40")],
		"dusk": 0.0, "night_tint": Color(0.78, 0.80, 0.95), "stars_day": true,
		"sand": Color("c4c8d6"), "sand_dark": Color("989db2"), "grass": Color("e2e5ee"),
		"seabed": Color("23263a"), "weed": Color("9fe0ff"), "water": false, "far": Color("5a6288"),
	},
}

const TIER_SHIFT: Array[float] = [0.0, 0.045, -0.045, 0.08, -0.08, 0.11, -0.11]

## The location the colors were built for (-1 = none yet).
static var location := -1
static var world := "ocean"
static var tier := 0
static var look: Dictionary = LOOKS["ocean"]
static var _rooms := {}


## The player's location right now (GameState.location once it exists;
## until then the old Dive Deeper count).
static func location_now() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GameState") if tree else null
	if gs == null:
		return 0
	var l = gs.get("location")
	if l == null:
		l = gs.get("prestige_count")
	return maxi(0, int(l)) if l != null else 0


static func world_of(l: int) -> String:
	return WORLDS[posmod(l, WORLDS.size())]


static func world_index(l: int) -> int:
	return posmod(l, WORLDS.size())


static func tier_of(l: int) -> int:
	return maxi(l, 0) / WORLDS.size()


## Location l's look: its world's colors, turned a little for later tiers.
static func look_of(l: int) -> Dictionary:
	var base: Dictionary = LOOKS[world_of(l)]
	var t := tier_of(l)
	if t == 0:
		return base
	var shift: float = TIER_SHIFT[(t - 1) % (TIER_SHIFT.size() - 1) + 1]
	var out := {}
	for key in base:
		var v = base[key]
		if v is Color:
			out[key] = _hue(v, shift)
		elif v is Array:
			out[key] = v.map(func(c): return _hue(c, shift) if c is Color else c)
		else:
			out[key] = v
	return out


static func _hue(c: Color, shift: float) -> Color:
	if c.s < 0.08:
		return c
	return Color.from_hsv(fposmod(c.h + shift, 1.0), c.s, c.v, c.a)


## "Volcano", "Volcano ★2", ...
static func name_of(l: int) -> String:
	var base := TranslationServer.translate(str(LOOKS[world_of(l)]["name"]))
	var t := tier_of(l)
	return base if t == 0 else "%s ★%d" % [base, t + 1]


## Switches the drawing colors to location l. True when they changed.
static func apply(l: int) -> bool:
	if l == location:
		return false
	location = l
	world = world_of(l)
	tier = tier_of(l)
	look = look_of(l)
	Art.sea_cols = PackedColorArray(look["sea"])
	DayNight.day_cols = PackedColorArray(look["day"])
	DayNight.night_cols = PackedColorArray(look["night"])
	DayNight.dusk_amount = float(look.get("dusk", 1.0))
	DayNight.night_tint = look.get("night_tint", DayNight.NIGHT_TINT)
	DayNight.stars_by_day = bool(look.get("stars_day", false))
	DayNight.far_day = look.get("far", Color("9fd4ee"))
	Art.set_world_sites(site_ids(), tier)
	_rooms.clear()
	return true


static func color(key: String) -> Color:
	return look.get(key, LOOKS["ocean"].get(key, Color.MAGENTA))


static func has(key: String) -> bool:
	return bool(look.get(key, false))


## Do the work sites hold water (divers swim) or air (workers walk)?
static func is_water() -> bool:
	return bool(look.get("water", true))


## Color of the lift shaft / cave air at depth f (0 top .. 1 bottom).
static func shaft_color(f: float) -> Color:
	var cols: Array = look["shaft"]
	var x := clampf(f, 0.0, 1.0) * (cols.size() - 1)
	var i := mini(int(x), cols.size() - 2)
	return (cols[i] as Color).lerp(cols[i + 1], x - i)


## Site ids of a world, one per Balance.DEPTHS entry. The ocean keeps the
## old ids while the economy still has more than ten sites.
static func site_ids_of(w: String) -> Array[String]:
	var out: Array[String] = []
	var list: Array = SITES[w]
	var n := Balance.DEPTHS.size()
	for i in n:
		if w == "ocean" and n != list.size():
			out.append(String(Balance.DEPTHS[i]["id"]))
		else:
			out.append(String(list[mini(i, list.size() - 1)]))
	return out


## Site ids of the current world (GameState.site_id once it exists).
static func site_ids() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GameState") if tree else null
	if gs != null and gs.has_method("site_id") and gs.get("location") != null and int(gs.get("location")) == location:
		var out: Array[String] = []
		for i in Balance.DEPTHS.size():
			out.append(String(gs.call("site_id", i)))
		return out
	return site_ids_of(world)


static func site_id(i: int) -> String:
	var ids: Array[String] = Art.site_ids
	return ids[clampi(i, 0, ids.size() - 1)]


## The translated name of site i of the current world.
static func site_name(i: int) -> String:
	return TranslationServer.translate("SITE_" + site_id(i).to_upper())


## A site's colors (Art.DEPTH_STYLE holds the current world's sites).
static func room_style(i: int) -> Dictionary:
	return Art.DEPTH_STYLE[clampi(i, 0, Art.DEPTH_STYLE.size() - 1)]
