class_name DayNight
extends RefCounted
## Time of day and wind for the surface world. One day lasts CYCLE seconds:
## about half of it is day and half is night, joined by a warm sunrise and
## sunset. World advances the clock; everything else only reads it.
##
## phase 0.0 = sunrise, 0.25 = noon, 0.5 = sunset, 0.75 = midnight.

const CYCLE := 600.0
## Every launch starts in a fresh morning.
const START_PHASE := 0.035
## Colors that feed toon shapes change in small steps (their geometry and
## colors are cached, so a new color every frame would flood the caches).
const STEP_SECONDS := 1.0

const DAY_TOP := Color("4fb3ee")
const DAY_MID := Color("8fd2f7")
const DAY_BOTTOM := Color("c9eeff")
const NIGHT_TOP := Color("0e1440")
const NIGHT_MID := Color("1b2862")
const NIGHT_BOTTOM := Color("33467f")
const DUSK_TOP := Color("4e4aa6")
const DUSK_MID := Color("e0679a")
const DUSK_BOTTOM := Color("ffab5c")
const DAWN_MID := Color("f48fb8")
const DAWN_BOTTOM := Color("ffd08a")

## Scene tint (modulate) at night and in the warm hours.
const NIGHT_TINT := Color(0.60, 0.66, 0.90)
const WARM_TINT := Color(1.0, 0.86, 0.80)
## Underwater modulate at night: gentle, the game must stay readable.
const DEEP_NIGHT_TINT := Color(0.76, 0.80, 0.94)

## Day and night sky stops [top, middle, horizon]; OceanLook sets them per ocean.
static var day_cols := PackedColorArray([DAY_TOP, DAY_MID, DAY_BOTTOM])
static var night_cols := PackedColorArray([NIGHT_TOP, NIGHT_MID, NIGHT_BOTTOM])
## How much sunrise/sunset color the sky takes (0 on the airless moon).
static var dusk_amount := 1.0
## Scene modulate at night (warmer by the volcano).
static var night_tint := NIGHT_TINT
## Stars stay out by day (the moon's black sky).
static var stars_by_day := false
## Faraway hills by day (WorldLook sets it per world).
static var far_day := Color("9fd4ee")
static var clock := START_PHASE * CYCLE
## Tests and preview sheets pin the time of day here (0..1, -1 = running).
static var fixed_phase := -1.0
## 0..1, drives clouds, palms, flags, smoke and waves.
static var wind := 0.5
static var time := 0.0


static func advance(delta: float) -> void:
	clock = fposmod(clock + delta, CYCLE)
	time += delta
	var t := time
	wind = clampf(0.5 + 0.22 * sin(t * 0.11) + 0.14 * sin(t * 0.31 + 1.3) + 0.06 * sin(t * 0.93 + 0.4), 0.08, 1.0)


static func phase() -> float:
	return fixed_phase if fixed_phase >= 0.0 else clock / CYCLE


## Phase rounded to STEP_SECONDS, for colors of cached shapes.
static func stepped_phase() -> float:
	var steps := CYCLE / STEP_SECONDS
	return floorf(phase() * steps) / steps


## Sun height: 1 at noon, 0 at sunrise/sunset, -1 at midnight.
static func elevation(p: float = -1.0) -> float:
	return sin(TAU * (phase() if p < 0.0 else p))


## 1 in full day, 0 in full night, smooth in between.
static func daylight(p: float = -1.0) -> float:
	return smoothstep(-0.22, 0.26, elevation(p))


static func night(p: float = -1.0) -> float:
	return 1.0 - daylight(p)


## How bright the stars are: at night, and always in an airless sky.
static func starlight(p: float = -1.0) -> float:
	return maxf(night(p), 0.75) if stars_by_day else night(p)


## Sunrise/sunset glow: 1 when the sun touches the horizon.
static func warmth(p: float = -1.0) -> float:
	var e := elevation(p) / 0.2
	return exp(-e * e)


## True in the morning half (the sun rises), for pinker dawns.
static func is_morning(p: float = -1.0) -> bool:
	return cos(TAU * (phase() if p < 0.0 else p)) > 0.0


## Sky gradient stops: [top, middle, horizon].
static func sky_colors(p: float = -1.0) -> PackedColorArray:
	var d := daylight(p)
	var w := warmth(p) * dusk_amount
	var morning := is_morning(p)
	var top := night_cols[0].lerp(day_cols[0], d).lerp(DUSK_TOP, w * 0.55)
	var mid := night_cols[1].lerp(day_cols[1], d).lerp(DAWN_MID if morning else DUSK_MID, w * 0.75)
	var bottom := night_cols[2].lerp(day_cols[2], d).lerp(DAWN_BOTTOM if morning else DUSK_BOTTOM, w * 0.92)
	return PackedColorArray([top, mid, bottom])


## Modulate for everything standing on the surface (boat, plant, people).
static func scene_tint(p: float = -1.0) -> Color:
	var base := night_tint.lerp(Color.WHITE, daylight(p))
	return base.lerp(base * WARM_TINT, warmth(p) * 0.7 * dusk_amount)


## Modulate for the underwater world.
static func deep_tint(p: float = -1.0) -> Color:
	return DEEP_NIGHT_TINT.lerp(Color.WHITE, daylight(p))


## Tint for the sea surface water (warm at sunset, deep blue at night).
static func sea_tint(p: float = -1.0) -> Color:
	var base := Color(0.55, 0.62, 0.86).lerp(Color.WHITE, daylight(p))
	return base.lerp(Color(1.0, 0.82, 0.78), warmth(p) * 0.45)


## Glint color for highlights on the water and cloud edges.
static func glint(p: float = -1.0) -> Color:
	var c := Color("dfe8ff").lerp(Color.WHITE, daylight(p))
	return c.lerp(Color("ffd9a0"), warmth(p) * 0.8)


static func cloud_fill(p: float = -1.0) -> Color:
	var pp := stepped_phase() if p < 0.0 else p
	var c := Color("5d6aa6").lerp(Color.WHITE, daylight(pp))
	return c.lerp(Color("ffc6b0") if not is_morning(pp) else Color("ffd6e0"), warmth(pp) * 0.75)


static func cloud_line(p: float = -1.0) -> Color:
	var pp := stepped_phase() if p < 0.0 else p
	var c := Color("2c3668").lerp(Color("7fb8e0"), daylight(pp))
	return c.lerp(Color("c46a8a"), warmth(pp) * 0.7)


## Faraway islands fade into the sky color.
static func far_color(depth: float, p: float = -1.0) -> Color:
	var pp := stepped_phase() if p < 0.0 else p
	var sky := sky_colors(pp)
	var day := far_day.lerp(far_day.darkened(0.15), depth)
	var c := night_cols[1].lerp(Color("26325f"), 0.5).lerp(day, daylight(pp))
	return c.lerp(sky[2].darkened(0.25), warmth(pp) * 0.55 * dusk_amount)


# --- Sun and moon path ----------------------------------------------------------------

const PEAK_Y := 112.0
## Same as World.SURFACE_Y (kept here so DayNight stays free of UI classes).
const HORIZON := 470.0
const PEAK_AT := 0.33


## Point on the sky arc; u 0 = rising on the left, 1 = setting into the open
## sea before the island. The arc stays over the open sky left of the cards.
static func arc_pos(u: float, w: float) -> Vector2:
	var warp := 0.5 * u / PEAK_AT if u < PEAK_AT else 0.5 + 0.5 * (u - PEAK_AT) / (1.0 - PEAK_AT)
	var horizon := HORIZON + 44.0
	var lift := sin(PI * clampf(warp, 0.0, 1.0))
	return Vector2(lerpf(w * 0.05, w * 0.56, u), horizon - (horizon - PEAK_Y) * pow(lift, 0.8))


static func sun_u() -> float:
	return phase() / 0.5


static func moon_u() -> float:
	return (phase() - 0.5) / 0.5


static func sun_up() -> bool:
	return phase() < 0.5


static func sun_pos(w: float) -> Vector2:
	return arc_pos(clampf(sun_u(), 0.0, 1.0), w)


static func moon_pos(w: float) -> Vector2:
	return arc_pos(clampf(moon_u(), 0.0, 1.0), w)


## Where the light on the water comes from (sun by day, moon by night).
static func light_pos(w: float) -> Vector2:
	return sun_pos(w) if sun_up() else moon_pos(w)
