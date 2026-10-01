class_name OceanLook
extends RefCounted
## Every Dive Deeper takes the player to a new ocean, and each ocean looks
## different: its own water, sky (day and night), sand, grass, seabed, sea
## weed and a tint for the dive sites, plus a few extras (ice floes, tall
## kelp). Ocean n is GameState.prestige_count (0 = the first ocean). After
## the hand-made looks run out they repeat with a small hue shift and a numeral
## ("Frost Sea II"). Everything here only changes colors: the scene keeps
## its layout, so readability stays the same.
##
## World calls apply() when the ocean changes; the drawing code reads the
## colors from here (and from Art.sea_cols / DayNight sky stops it sets).

const LOOKS: Array[Dictionary] = [
	{   # 1: the home lagoon (the original colors)
		"name": "OCEAN_NAME_LAGOON",
		"sea": [Color("35c9d2"), Color("1c88b6"), Color("165290"), Color("0e2654")],
		"day": [Color("4fb3ee"), Color("8fd2f7"), Color("c9eeff")],
		"night": [Color("0e1440"), Color("1b2862"), Color("33467f")],
		"sand": Color("f8d898"), "sand_dark": Color("e2aa62"), "grass": Color("72d25a"),
		"seabed": Color("2a2f5e"), "weed": Color("47c47a"), "room": Color.WHITE, "room_mix": 0.0,
	},
	{   # 2: cold arctic sea with ice floes and snowy shores
		"name": "OCEAN_NAME_FROST",
		"sea": [Color("93dcea"), Color("4a9fcf"), Color("2a5d9a"), Color("10264f")],
		"day": [Color("74ade0"), Color("b6d8f0"), Color("eef8ff")],
		"night": [Color("0a1634"), Color("163a5c"), Color("2f7a7c")],
		"sand": Color("e9f0f8"), "sand_dark": Color("aebfd6"), "grass": Color("f7fbff"),
		"seabed": Color("2c3d63"), "weed": Color("6fc3b8"), "room": Color("bfe6ff"), "room_mix": 0.28,
		"ice": true,
	},
	{   # 3: a warm coral sea under a sunset-colored sky
		"name": "OCEAN_NAME_SUNSET",
		"sea": [Color("58c9c2"), Color("2f8fb0"), Color("3f5296"), Color("2a1d58")],
		"day": [Color("e9877e"), Color("ffb48e"), Color("ffe2b4")],
		"night": [Color("26103c"), Color("47205c"), Color("7a3a6c")],
		"sand": Color("ffcf9c"), "sand_dark": Color("e8955a"), "grass": Color("a6d65a"),
		"seabed": Color("3a2450"), "weed": Color("ff7f6e"), "room": Color("ff9a7a"), "room_mix": 0.22,
	},
	{   # 4: violet deep sea
		"name": "OCEAN_NAME_VIOLET",
		"sea": [Color("86a2f2"), Color("5d64d2"), Color("3b3094"), Color("1b1250")],
		"day": [Color("8a7ae6"), Color("b9a8fb"), Color("ebe0ff")],
		"night": [Color("120a30"), Color("261a5a"), Color("4a3a8a")],
		"sand": Color("efd6f2"), "sand_dark": Color("c79ed2"), "grass": Color("8fe0b4"),
		"seabed": Color("2c1c5a"), "weed": Color("b48cff"), "room": Color("b48cff"), "room_mix": 0.26,
	},
	{   # 5: emerald kelp forest
		"name": "OCEAN_NAME_KELP",
		"sea": [Color("4fd6a8"), Color("1f9e88"), Color("136a6e"), Color("08343e")],
		"day": [Color("56bccb"), Color("9de0d6"), Color("e2fff4")],
		"night": [Color("071e28"), Color("0f3a42"), Color("1f5a5e")],
		"sand": Color("e8dc9c"), "sand_dark": Color("bfa45a"), "grass": Color("4fc070"),
		"seabed": Color("173a3a"), "weed": Color("2fae5a"), "room": Color("3ee08f"), "room_mix": 0.24,
		"kelp": true,
	},
	{   # 6: glowing midnight sea
		"name": "OCEAN_NAME_GLOW",
		"sea": [Color("3a9ed6"), Color("1c5aa0"), Color("172a72"), Color("080c30")],
		"day": [Color("5568c8"), Color("9a9ee6"), Color("f4d4ec")],
		"night": [Color("050820"), Color("0e1440"), Color("1e2a60")],
		"sand": Color("f2e4cc"), "sand_dark": Color("c9b08c"), "grass": Color("7ad0a4"),
		"seabed": Color("1a1a48"), "weed": Color("5affd8"), "room": Color("5affd8"), "room_mix": 0.16,
	},
]

const NUMERALS := ["", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X"]

## The ocean the colors were built for (-1 = none yet).
static var ocean := -1
static var look: Dictionary = LOOKS[0]


## Ocean n's look: the hand-made ones, then the later ones again (not the
## home lagoon) with their hues turned a little, a different way each round.
static func look_of(n: int) -> Dictionary:
	n = maxi(n, 0)
	if n < LOOKS.size():
		return LOOKS[n]
	var k := n - LOOKS.size()
	var base: Dictionary = LOOKS[1 + k % (LOOKS.size() - 1)]
	var round_n := floori(k / float(LOOKS.size() - 1)) + 1
	# Small hue turns either way, so a sea never drifts into odd colors.
	var shift: float = [0.05, -0.05, 0.09, -0.09][(round_n - 1) % 4]
	var out := {}
	for key in base:
		var v = base[key]
		if v is Color:
			out[key] = _hue(v, shift)
		elif v is Array:
			out[key] = v.map(func(c): return _hue(c, shift))
		else:
			out[key] = v
	return out


static func _hue(c: Color, shift: float) -> Color:
	return Color.from_hsv(fposmod(c.h + shift, 1.0), c.s, c.v, c.a)


## Name shown on arrival: "Frost Sea", "Frost Sea II", ...
static func name_of(n: int) -> String:
	var base := TranslationServer.translate(str(look_of(n)["name"]))
	if n < LOOKS.size():
		return base
	var round_n := floori((n - LOOKS.size()) / float(LOOKS.size() - 1)) + 1
	return base + NUMERALS[mini(round_n, NUMERALS.size() - 1)]


## Switches the drawing colors to ocean n. True when they changed.
static func apply(n: int) -> bool:
	if n == ocean:
		return false
	ocean = n
	look = look_of(n)
	var sea: Array = look["sea"]
	Art.sea_cols = PackedColorArray(sea)
	DayNight.day_cols = PackedColorArray(look["day"])
	DayNight.night_cols = PackedColorArray(look["night"])
	_rooms.clear()
	return true


static func color(key: String) -> Color:
	return look.get(key, LOOKS[0].get(key, Color.MAGENTA))


static func has(key: String) -> bool:
	return bool(look.get(key, false))


static var _rooms := {}


## A dive site's colors tinted toward this ocean's accent (water, rock and
## floor; ore and suits stay, they belong to the site).
static func room_style(i: int) -> Dictionary:
	var st: Dictionary = Art.DEPTH_STYLE[clampi(i, 0, Art.DEPTH_STYLE.size() - 1)]
	var mix: float = look.get("room_mix", 0.0)
	if mix <= 0.0:
		return st
	if not _rooms.has(i):
		var out := st.duplicate()
		var accent: Color = look["room"]
		for k in ["water", "rock", "floor"]:
			var c: Color = st[k]
			# Keep the brightness, take some of the accent's hue (the cave
			# water most: it is the biggest area of a site).
			var m := minf(mix * (1.8 if k == "water" else 1.0), 0.6)
			out[k] = c.lerp(Color.from_hsv(accent.h, maxf(c.s, accent.s * 0.6), c.v), m)
		_rooms[i] = out
	return _rooms[i]
