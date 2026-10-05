class_name FactoryArt
extends RefCounted
## The factory hall (room 2), drawn in local space with Art's toon kit.
## Callers place the parts with Art.push/pop (see FactoryRoom).
##
##   hall(...)       back wall with windows, ceiling beams and the floor,
##                   tinted per world (look(world_id))
##   dock_door(...)  the rolling dock door where boat crates come in
##   line(...)       a machine line at a building stage 1..20: crusher,
##                   furnace, polisher and coin press. Stages 1-4 add the
##                   machines one by one; every 4 stages after that the
##                   line gets a new material tier (wood -> painted steel ->
##                   teal and brass -> white hi-tech -> gold and crystal),
##                   and inside a tier beacons, overhead pipes and a sign.
##   pipe(...)       the glass product tube up into the ceiling (to room 3)
##
## A line's origin is on the floor at its left end; it is LINE_W long and
## the products leave at OUT (local).

const LINE_W := 400.0
## Centers of the four machines on a line.
const SLOTS: Array[float] = [48.0, 148.0, 250.0, 350.0]
const MACHINES := ["crusher", "furnace", "polisher", "press"]
## Where products leave a line (local): the press's chute.
const OUT := Vector2(400, -34)
## Where crates go in: the crusher's hopper top.
const HOPPER := Vector2(48, -112)
const STAGES := 20

## Per world: hall colors and the furnace flame.
const LOOKS := {
	"ocean": {"wall": Color("e3ad72"), "wall2": Color("d29a5e"), "low": Color("4f97c8"), "beam": Color("8e552c"),
		"floor": Color("9a7552"), "floor2": Color("876343"), "sky": Color("8fe0ff"), "sky2": Color("35c9d2"),
		"accent": Color("3aa6f0"), "flame": Color("ff9a3c"), "glow": Color("ffd27a"), "style": "planks"},
	"volcano": {"wall": Color("6a6d82"), "wall2": Color("5a5c70"), "low": Color("43445a"), "beam": Color("33344a"),
		"floor": Color("4c4757"), "floor2": Color("3d3948"), "sky": Color("ffb35c"), "sky2": Color("e0482c"),
		"accent": Color("ff7a2e"), "flame": Color("ff6a1f"), "glow": Color("ff9a3c"), "style": "plates"},
	"acid": {"wall": Color("dff3d6"), "wall2": Color("c9e8bd"), "low": Color("62c873"), "beam": Color("3f7a5a"),
		"floor": Color("9fc9a8"), "floor2": Color("88b591"), "sky": Color("c6ff8a"), "sky2": Color("5fbf4a"),
		"accent": Color("7dff5a"), "flame": Color("8cff3c"), "glow": Color("c8ff7a"), "style": "tiles"},
	"moon": {"wall": Color("eef3fb"), "wall2": Color("dde6f4"), "low": Color("8fb4e8"), "beam": Color("9aa9c4"),
		"floor": Color("c4cfe2"), "floor2": Color("b0bdd4"), "sky": Color("2a2f6a"), "sky2": Color("12163a"),
		"accent": Color("5ad2ff"), "flame": Color("6ad8ff"), "glow": Color("a8ecff"), "style": "panels"},
}

## Machine materials per tier: body, trim, dark parts, light/glow.
const TIERS := [
	{"body": Color("c98249"), "trim": Color("8d94a6"), "dark": Color("6e4426"), "light": Color("ffd27a")},
	{"body": Color("ef6a4f"), "trim": Color("cbd5e1"), "dark": Color("5a5f7a"), "light": Color("ffe38a")},
	{"body": Color("2bb8b4"), "trim": Color("f5b843"), "dark": Color("2f5a6e"), "light": Color("bff3ff")},
	{"body": Color("f4f7ff"), "trim": Color("5ad2ff"), "dark": Color("5a6a8a"), "light": Color("7be8ff")},
	{"body": Color("ffc93c"), "trim": Color("a77cff"), "dark": Color("7a4ad0"), "light": Color("fff1a8")},
]


static func look(world: String) -> Dictionary:
	return LOOKS.get(world, LOOKS["ocean"])


static func tier_of(stage: int) -> int:
	return (clampi(stage, 1, STAGES) - 1) / 4


## Machines standing at a stage (1..4).
static func machines_at(stage: int) -> int:
	return clampi(stage, 1, 4)


## Extras inside a tier (0..3) once all four machines stand (stage 5+).
static func extras_of(stage: int) -> int:
	return 0 if stage < 5 else (clampi(stage, 1, STAGES) - 1) % 4


## Top of a line above its floor (for cards and effects above it).
static func line_height(stage: int) -> float:
	return 150.0 + (34.0 if extras_of(stage) >= 3 else 0.0)


## The second line's paint: bright colors turn around the color wheel.
static func _alt(c: Color) -> Color:
	if c.s < 0.16:
		return c if c.v < 0.55 else c.lerp(Color("aef0d8"), 0.42)
	return Color.from_hsv(fposmod(c.h + 0.3, 1.0), c.s, c.v, c.a)


static func _mat(stage: int, variant: int) -> Dictionary:
	var m: Dictionary = TIERS[tier_of(stage)]
	if variant == 0:
		return m
	return {"body": _alt(m["body"]), "trim": _alt(m["trim"]), "dark": m["dark"], "light": m["light"]}


# --- The hall ------------------------------------------------------------------------

## Back wall, windows, ceiling and floor of a hall `w` x `h` (local, origin
## top-left) whose floor line is at `floor_y`. `windows` = x centers.
static func hall(ci: CanvasItem, w: float, h: float, floor_y: float, lk: Dictionary, t: float, windows: Array = []) -> void:
	var wall: Color = lk["wall"]
	var wall2: Color = lk["wall2"]
	Art.flat(ci, Art.rrect_pts(Rect2(0, 0, w, floor_y), 0.0), wall)
	match str(lk["style"]):
		"planks":
			var x := 0.0
			var i := 0
			while x < w:
				if i % 2 == 1:
					Art.flat(ci, PackedVector2Array([Vector2(x, 0), Vector2(x + 34, 0), Vector2(x + 34, floor_y), Vector2(x, floor_y)]), wall2)
				Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x, floor_y)]), Art.shade_of(wall, 0.35), 2.0)
				x += 34.0
				i += 1
		"plates":
			var ys := [0.0, floor_y * 0.33, floor_y * 0.66]
			for j in ys.size():
				var y0: float = ys[j]
				var off := 0.0 if j % 2 == 0 else 45.0
				var x := -off
				while x < w:
					var r := Rect2(x + 3, y0 + 3, 84, floor_y * 0.33 - 6)
					Art.flat(ci, Art.rrect_pts(r, 6.0), wall2 if (j + int(x / 90.0)) % 2 == 0 else wall)
					Art.ring(ci, Art.rrect_pts(r, 6.0), Art.shade_of(wall, 0.3), 2.0)
					for c: Vector2 in [r.position + Vector2(8, 8), r.position + Vector2(r.size.x - 8, 8),
							r.end - Vector2(8, 8), Vector2(r.position.x + 8, r.end.y - 8)]:
						Art.disc(ci, c, 2.6, Art.shade_of(wall, 0.4))
					x += 90.0
		"tiles":
			var y := 0.0
			while y < floor_y:
				Art.line_c(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y)]), wall2, 2.0)
				y += 30.0
			var x := 0.0
			while x < w:
				Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x, floor_y)]), wall2, 2.0)
				x += 30.0
		"panels":
			var x := 0.0
			while x < w:
				var r := Rect2(x + 4, 6, 72, floor_y - 12)
				Art.flat(ci, Art.rrect_pts(r, 12.0), wall2)
				Art.flat(ci, Art.rrect_pts(Rect2(x + 36, 18, 4, floor_y * 0.5), 2.0), Color(lk["accent"], 0.35))
				x += 80.0
	# Lower wall band (wainscot) along the floor.
	var band := Rect2(0, floor_y - 58, w, 58)
	Art.flat(ci, Art.rrect_pts(band, 0.0), lk["low"])
	Art.flat(ci, Art.rrect_pts(Rect2(0, floor_y - 62, w, 8), 0.0), Art.shade_of(lk["low"], 0.3))
	if str(lk["style"]) == "plates":
		# Hazard stripes along the band in the volcano.
		var x := 0.0
		while x < w:
			Art.flat(ci, PackedVector2Array([Vector2(x, floor_y - 54), Vector2(x + 14, floor_y - 54), Vector2(x + 4, floor_y - 40), Vector2(x - 10, floor_y - 40)]), Color("ffc93c"))
			x += 28.0
	for wx in windows:
		window(ci, Rect2(float(wx) - 46, 34, 92, 74), lk, t)
	# Ceiling beams.
	Art.t_rect(ci, Rect2(-10, -6, w + 20, 26), 0.0, lk["beam"], 3.0, 0.5)
	var bx := 40.0
	while bx < w:
		Art.toon(ci, PackedVector2Array([Vector2(bx - 26, 18), Vector2(bx + 26, 18), Vector2(bx, 44)]), lk["beam"], 2.5, 0.4)
		bx += 160.0
	# Floor.
	Art.flat(ci, Art.rrect_pts(Rect2(0, floor_y, w, h - floor_y), 0.0), lk["floor"])
	var fy := floor_y + 14.0
	var k := 0
	while fy < h:
		Art.line_c(ci, PackedVector2Array([Vector2(0, fy), Vector2(w, fy)]), lk["floor2"], 2.0)
		var fx := fmod(k * 37.0, 90.0)
		while fx < w:
			Art.line_c(ci, PackedVector2Array([Vector2(fx, fy - 14), Vector2(fx, fy)]), lk["floor2"], 2.0)
			fx += 90.0
		fy += 14.0 + k * 4.0
		k += 1
	Art.line_c(ci, PackedVector2Array([Vector2(0, floor_y), Vector2(w, floor_y)]), Art.INK, 3.0)


## A window showing the world outside (sea, lava, swamp, space).
static func window(ci: CanvasItem, r: Rect2, lk: Dictionary, t: float) -> void:
	Art.t_rect(ci, r.grow(6), 10, lk["beam"], 3.0, 0.4)
	Art.grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([lk["sky"], lk["sky"], lk["sky2"], lk["sky2"]]))
	match str(lk["style"]):
		"planks":
			Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, r.end.y - 24, r.size.x, 24), 0.0), Color("1c88b6"))
			Art.t_circle(ci, r.position + Vector2(r.size.x * 0.75, 20), 9, Art.GOLD, 0.0, 0.0)
		"plates":
			Art.toon(ci, PackedVector2Array([r.position + Vector2(10, r.size.y), r.position + Vector2(r.size.x * 0.45, 22),
					r.position + Vector2(r.size.x * 0.8, r.size.y)]), Color("4a3a48"), 0.0, 0.0)
			Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.4, 26), r.position + Vector2(r.size.x * 0.5, 26),
					r.position + Vector2(r.size.x * 0.56, r.size.y), r.position + Vector2(r.size.x * 0.46, r.size.y)]), Color("ff7a2e"))
		"tiles":
			for i in 3:
				var c := r.position + Vector2(18 + i * 28, r.size.y - 14)
				Art.flat(ci, Art.ellipse_pts(c, Vector2(12, 9), 12), Color("ff6fa8") if i == 1 else Color("b06ae0"))
		"panels":
			for i in 5:
				Art.disc(ci, r.position + Vector2(fposmod(i * 37.0, r.size.x - 10) + 5, 8 + fposmod(i * 23.0, r.size.y - 20)), 1.8, Art.WHITE)
			Art.t_circle(ci, r.position + Vector2(r.size.x * 0.7, r.size.y * 0.75), 16, Color("5ab8ff"), 0.0, 0.0)
	# Glass glint and the frame bars.
	Art.flat(ci, PackedVector2Array([r.position + Vector2(10, 0), r.position + Vector2(26, 0), r.position + Vector2(8, r.size.y), r.position + Vector2(-0.0, r.size.y)]), Color(1, 1, 1, 0.22))
	Art.line_c(ci, PackedVector2Array([Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y)]), lk["beam"], 5.0)
	Art.line_c(ci, PackedVector2Array([Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y)]), lk["beam"], 5.0)
	Art.ring(ci, Art.rrect_pts(r, 4), Art.INK, 3.0)


# --- Dock door -------------------------------------------------------------------------

## The dock door: origin on the floor at its left post, DOOR_W wide.
## `open` 0..1 rolls the shutter up; `lamp` 0..1 lights its beacon.
const DOOR_W := 96.0
const DOOR_H := 150.0


static func dock_door(ci: CanvasItem, open: float, lamp: float, lk: Dictionary) -> void:
	var r := Rect2(8, -DOOR_H, DOOR_W - 16, DOOR_H)
	Art.t_rect(ci, Rect2(0, -DOOR_H - 22, DOOR_W, DOOR_H + 22), 6, Art.shade_of(lk["beam"], 0.1), 3.0, 0.4)
	# The outside: the quay and the sea or the world's ground.
	Art.grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([lk["sky"], lk["sky"], lk["sky2"], lk["sky2"]]))
	Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, -30, r.size.x, 30), 0.0), Art.shade_of(lk["floor"], 0.15))
	# The shutter, in slats, rolled up by `open`.
	var sh := DOOR_H * (1.0 - clampf(open, 0.0, 0.82))
	var n := int(ceil(sh / 14.0))
	for i in n:
		var y := -DOOR_H + sh - (i + 1) * 14.0
		if y < -DOOR_H:
			break
		Art.t_rect(ci, Rect2(8, y, DOOR_W - 16, 14), 2, Color("c9d2e2") if i % 2 == 0 else Color("b7c1d4"), 2.0, 0.2)
	Art.t_rect(ci, Rect2(4, -DOOR_H - 18, DOOR_W - 8, 16), 6, Color("8d94a6"), 2.6, 0.3)
	# Yellow-black posts.
	for x: float in [0.0, DOOR_W - 8.0]:
		Art.t_rect(ci, Rect2(x, -DOOR_H, 8, DOOR_H), 2, Art.GOLD, 2.2, 0.2)
		for j in 6:
			Art.flat(ci, PackedVector2Array([Vector2(x, -DOOR_H + j * 25 + 4), Vector2(x + 8, -DOOR_H + j * 25 + 12),
					Vector2(x + 8, -DOOR_H + j * 25 + 20), Vector2(x, -DOOR_H + j * 25 + 12)]), Art.INK)
	# Beacon over the door.
	var bc := Vector2(DOOR_W / 2.0, -DOOR_H - 30)
	Art.t_rect(ci, Rect2(bc.x - 12, bc.y + 2, 24, 8), 2, Color("5a5f7a"), 2.0, 0.0)
	Art.t_circle(ci, bc, 9, Art.GOLD.lerp(Color("ffef9a"), lamp), 2.4, 0.5)
	if lamp > 0.02:
		Props.halo(ci, bc, 34, Color(1.0, 0.8, 0.3, 0.55 * lamp))


## A wooden crate with ore peeking out; origin at its bottom center.
static func crate(ci: CanvasItem, s: float, gem: Color) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(s, s))
	Art.crystal(ci, Vector2(-6, -26), 12, 5, -0.3, gem, 1.8)
	Art.crystal(ci, Vector2(5, -26), 14, 5, 0.25, gem.lightened(0.25), 1.8)
	Art.t_rect(ci, Rect2(-17, -28, 34, 28), 3, Art.WOOD, 2.4, 0.5)
	Art.line_c(ci, PackedVector2Array([Vector2(-15, -14), Vector2(15, -14)]), Art.WOOD_DARK, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-13, -26), Vector2(13, -2)]), Art.WOOD_DARK, 2.0)
	Art.pop(ci)


## A floor belt from `a` (left end, on the floor) `len` long; its top is 22
## above the floor. Rollers spin with t when running.
static func belt(ci: CanvasItem, a: Vector2, len: float, t: float, running: bool) -> void:
	var legs := maxi(2, int(len / 60.0) + 1)
	for i in legs:
		var x := a.x + 8.0 + (len - 16.0) * i / float(legs - 1)
		Art.stroke(ci, PackedVector2Array([Vector2(x, a.y - 16), Vector2(x, a.y)]), Color("5a5f7a"), 4.0, 1.8)
	Art.t_rect(ci, Rect2(a.x, a.y - 24, len, 10), 5, Color("3a3f5c"), 2.6, 0.2)
	var step := 16.0
	var off := fposmod(t * 30.0, step) if running else 0.0
	var x0 := a.x + 6.0 + off
	while x0 < a.x + len - 4.0:
		Art.disc(ci, Vector2(x0, a.y - 19), 1.8, Art.METAL)
		x0 += step


# --- The machine line ------------------------------------------------------------------

## o: "t", "working" (bool), "gear" (rotation), "press" (0..1 piston down),
## "flash" (0..1 after a payout), "variant" (1 = second line), "flame".
static func line(ci: CanvasItem, stage: int, o: Dictionary) -> void:
	var s := clampi(stage, 1, STAGES)
	var m := _mat(s, int(o.get("variant", 0)))
	var tier := tier_of(s)
	var ex := extras_of(s)
	var n := machines_at(s)
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	# Overhead pipes behind the machines.
	if ex >= 2:
		Art.stroke(ci, PackedVector2Array([Vector2(10, -150), Vector2(LINE_W - 10, -150)]), m["trim"], 9.0, 2.4)
		for x: float in SLOTS:
			Art.stroke(ci, PackedVector2Array([Vector2(x + 22, -150), Vector2(x + 22, -112)]), m["trim"], 6.0, 2.0)
		Art.t_circle(ci, Vector2(200, -150), 11, Art.WHITE, 2.4, 0.2)
		Art.line(ci, Vector2(200, -150), Vector2(200, -150) + Vector2(0, -8).rotated(sin(t * 2.0) * 0.8 if working else -0.6), Art.RED, 2.0)
	# A sign over the line, with a star per tier.
	if ex >= 3:
		var sc := Vector2(LINE_W / 2.0, -172)
		for x: float in [-60.0, 60.0]:
			Art.line_c(ci, PackedVector2Array([sc + Vector2(x, -18), sc + Vector2(x, -36)]), Art.INK, 2.0)
		Art.t_rect(ci, Rect2(sc.x - 74, sc.y - 18, 148, 30), 10, m["dark"], 3.0, 0.4)
		for i in tier:
			var c := sc + Vector2((i - (tier - 1) / 2.0) * 26.0, -3)
			Art.toon(ci, Art.star_pts(c, 10, 4.5, 5), Art.GOLD, 2.0, 0.3)
	# Small belts between the machines, with the goods moving along them.
	for i in n - 1:
		var a := Vector2(SLOTS[i] + 30, 0)
		var len := SLOTS[i + 1] - SLOTS[i] - 60
		belt(ci, a, len, t, working)
	for i in 4:
		var x: float = SLOTS[i]
		Art.push(ci, Vector2(x, 0))
		if i < n:
			match i:
				0: _crusher(ci, tier, m, o)
				1: _furnace(ci, tier, m, o)
				2: _polisher(ci, tier, m, o)
				3: _press(ci, tier, m, o)
			if ex >= 1:
				_beacon(ci, Vector2(0, _top(i) - 6), working, t + i, m)
		else:
			_spot(ci)
		Art.pop(ci)
	if n < 4:
		# Until the press stands the crusher's output goes in a cart.
		Art.push(ci, Vector2(SLOTS[n - 1] + 44, 0))
		Art.t_rect(ci, Rect2(-10, -26, 30, 18), 3, m["dark"], 2.4, 0.3)
		Art.t_circle(ci, Vector2(-4, -6), 5, Art.INK_SOFT, 2.0, 0.0)
		Art.t_circle(ci, Vector2(14, -6), 5, Art.INK_SOFT, 2.0, 0.0)
		Art.coin(ci, Vector2(5, -28), 6)
		Art.pop(ci)
	# Goods on the small belts.
	if working:
		for i in n - 1:
			var a := SLOTS[i] + 30.0
			var len := SLOTS[i + 1] - SLOTS[i] - 60.0
			var f := fposmod(t * 0.9 + i * 0.37, 1.0)
			Art.push(ci, Vector2(a + len * f, -24))
			_good(ci, i)
			Art.pop(ci)
	if int(o.get("variant", 0)) > 0:
		Props.second_badge(ci, Vector2(SLOTS[0] - 30, -96), 11.0)


## Tops of the machines (local y), for beacons.
static func _top(i: int) -> float:
	return [-112.0, -100.0, -94.0, -132.0][i]


## The thing a belt carries after machine i: chunks, glowing ingots, shiny bars.
static func _good(ci: CanvasItem, i: int) -> void:
	match i:
		0:
			Art.toon(ci, PackedVector2Array([Vector2(-6, 0), Vector2(-4, -8), Vector2(3, -10), Vector2(7, -3), Vector2(5, 0)]), Color("b08a6a"), 1.8, 0.4)
		1:
			Art.t_rect(ci, Rect2(-8, -8, 16, 8), 2, Color("ff8a3c"), 1.8, 0.4)
		_:
			Art.t_rect(ci, Rect2(-8, -8, 16, 8), 2, Art.GOLD, 1.8, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(-5, -7, 4, 2), 1), Color(1, 1, 1, 0.8))


## Empty spot for a machine still to come: taped square and a "+".
static func _spot(ci: CanvasItem) -> void:
	var r := Rect2(-34, -10, 68, 10)
	Art.flat(ci, Art.rrect_pts(r, 3), Color(0, 0, 0, 0.12))
	for j in 5:
		Art.flat(ci, Art.rrect_pts(Rect2(-34 + j * 14, -3, 8, 3), 1), Art.GOLD)
	Art.t_circle(ci, Vector2(0, -34), 13, Color(1, 1, 1, 0.55), 2.4, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-7, -36, 14, 4), 1.5), Art.INK_SOFT)
	Art.flat(ci, Art.rrect_pts(Rect2(-2, -41, 4, 14), 1.5), Art.INK_SOFT)


static func _beacon(ci: CanvasItem, at: Vector2, on: bool, t: float, m: Dictionary) -> void:
	Art.t_rect(ci, Rect2(at.x - 7, at.y - 2, 14, 6), 2, m["dark"], 2.0, 0.0)
	var lit := (0.5 + 0.5 * sin(t * 6.0)) if on else 0.0
	Art.t_circle(ci, at + Vector2(0, -7), 6, Art.CORAL.lerp(Color("ffe38a"), Props._q(lit, 4)), 2.0, 0.3)
	if lit > 0.1:
		Props.halo(ci, at + Vector2(0, -7), 20, Color(1.0, 0.7, 0.3, 0.4 * lit))


static func _legs(ci: CanvasItem, hw: float, h: float, m: Dictionary) -> void:
	for x: float in [-hw, hw]:
		Art.t_rect(ci, Rect2(x - 4, -h, 8, h), 2, m["dark"], 2.2, 0.0)
	Art.t_rect(ci, Rect2(-hw - 8, -4, hw * 2.0 + 16, 4), 1, m["dark"], 1.8, 0.0)


static func _rivets(ci: CanvasItem, r: Rect2) -> void:
	for c: Vector2 in [r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6), r.end - Vector2(6, 6), Vector2(r.position.x + 6, r.end.y - 6)]:
		Art.disc(ci, c, 2.2, Color(0, 0, 0, 0.3))


## 1. Crusher: hopper on top, two gear rollers behind a round window.
static func _crusher(ci: CanvasItem, tier: int, m: Dictionary, o: Dictionary) -> void:
	var gr: float = o.get("gear", 0.0)
	_legs(ci, 22, 22, m)
	var body := Rect2(-34, -76, 68, 56)
	Art.t_rect(ci, body, 8, m["body"], 3.0, 0.6)
	if tier == 0:
		for y: float in [-62.0, -46.0, -32.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(-32, y), Vector2(32, y)]), Art.WOOD_DARK, 2.0)
	else:
		_rivets(ci, body)
	Art.toon(ci, PackedVector2Array([Vector2(-40, -110), Vector2(40, -110), Vector2(22, -76), Vector2(-22, -76)]), m["trim"], 3.0, 0.5)
	Art.flat(ci, PackedVector2Array([Vector2(-32, -106), Vector2(32, -106), Vector2(28, -100), Vector2(-28, -100)]), Color(0, 0, 0, 0.35))
	Art.t_circle(ci, Vector2(0, -48), 20, Color("2a2440"), 2.6, 0.0)
	Art.gear(ci, Vector2(-8, -48), 10, m["trim"], gr, 7)
	Art.gear(ci, Vector2(9, -48), 10, m["trim"], -gr + 0.3, 7)
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -58), Vector2(6, 3), 10, -0.5), Color(1, 1, 1, 0.3))
	if tier >= 4:
		Art.crystal(ci, Vector2(28, -110), 18, 6, 0.3, Color("b78cff"), 2.0)
	elif tier >= 3:
		Art.flat(ci, Art.rrect_pts(Rect2(-30, -26, 60, 4), 2), m["trim"])


## 2. Furnace: a rounded oven with a fire mouth and a short chimney.
static func _furnace(ci: CanvasItem, tier: int, m: Dictionary, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	var flame: Color = o.get("flame", Color("ff9a3c"))
	Art.t_rect(ci, Rect2(-10, -132, 20, 40), 3, m["dark"], 2.6, 0.3)
	Art.t_rect(ci, Rect2(-13, -138, 26, 8), 3, m["trim"], 2.4, 0.2)
	var body := Rect2(-38, -100, 76, 100)
	Art.t_rect(ci, body, 20 if tier >= 2 else 10, Color("c8604a") if tier == 0 else m["body"], 3.0, 0.6)
	if tier == 0:
		for j in 6:
			var y := -88.0 + j * 14.0
			Art.line_c(ci, PackedVector2Array([Vector2(-36, y), Vector2(36, y)]), Color("8e3a2c"), 2.0)
			var x := -24.0 if j % 2 == 0 else -10.0
			while x < 36.0:
				Art.line_c(ci, PackedVector2Array([Vector2(x, y), Vector2(x, y + 14)]), Color("8e3a2c"), 2.0)
				x += 28.0
	else:
		Art.t_rect(ci, Rect2(-38, -80, 76, 10), 3, m["trim"], 2.2, 0.2)
	var mouth := Rect2(-22, -56, 44, 36)
	Art.t_rect(ci, mouth, 14, Color("2a1830"), 3.0, 0.0)
	var lit := 1.0 if working else 0.35
	var fl := 0.85 + 0.15 * sin(t * 13.0) if working else 0.6
	Props.halo(ci, Vector2(0, -36), 46 * lit, Color(flame, 0.55 * lit))
	Art.push(ci, Vector2(0, -20), 0.0, Vector2(1.0, Props._q(fl, 8) * lit + 0.2))
	Art.toon(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-12, -18), Vector2(-5, -10), Vector2(0, -28), Vector2(5, -12), Vector2(12, -20), Vector2(16, 0)]), flame, 2.0, 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(-8, 0), Vector2(-3, -12), Vector2(0, -6), Vector2(4, -14), Vector2(8, 0)]), Color("fff1a8"), 0.0, 0.0)
	Art.pop(ci)
	# The door handle and a temperature dial.
	Art.t_circle(ci, Vector2(26, -88), 7, Art.WHITE, 2.0, 0.0)
	Art.line(ci, Vector2(26, -88), Vector2(26, -88) + Vector2(0, -5).rotated(0.9 if working else -0.9), Art.RED, 1.8)


## 3. Polisher: a spinning drum on a base, sparkles while it runs.
static func _polisher(ci: CanvasItem, tier: int, m: Dictionary, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var gr: float = o.get("gear", 0.0)
	var working: bool = o.get("working", false)
	Art.t_rect(ci, Rect2(-34, -36, 68, 36), 6, m["dark"], 3.0, 0.5)
	Art.t_rect(ci, Rect2(-30, -32, 60, 8), 3, m["trim"], 2.0, 0.2)
	for x: float in [-22.0, 22.0]:
		Art.t_rect(ci, Rect2(x - 4, -70, 8, 36), 2, m["trim"], 2.2, 0.2)
	Art.push(ci, Vector2(0, -64), gr * 1.6)
	Art.t_circle(ci, Vector2.ZERO, 24, m["body"], 3.0, 0.5)
	for k in 4:
		Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(20, 0).rotated(k * PI / 2.0)]), Art.shade_of(m["body"], 0.3), 3.0)
	Art.t_circle(ci, Vector2.ZERO, 7, m["trim"], 2.0, 0.0)
	Art.pop(ci)
	if tier >= 2:
		Art.flat(ci, Art.ellipse_pts(Vector2(0, -66), Vector2(32, 30), 24), Color(0.75, 0.95, 1.0, 0.25))
		Art.arc_c(ci, Vector2(0, -66), 31, PI, TAU, 16, Art.INK, 2.5)
		Art.arc_c(ci, Vector2(0, -66), 25, PI * 1.15, PI * 1.45, 6, Color(1, 1, 1, 0.8), 3.0)
	if working:
		for k in 3:
			var ph := fposmod(t * 1.7 + k * 0.33, 1.0)
			var c := Vector2(-28 + k * 28, -92 - ph * 18)
			var a := 1.0 - ph
			Art.dot(ci, c, 3.0 * a + 1.0, Color(1, 1, 0.8, a))


## 4. Coin press: a frame with a piston that stamps coins.
static func _press(ci: CanvasItem, tier: int, m: Dictionary, o: Dictionary) -> void:
	var p: float = o.get("press", 0.0)
	var flash: float = o.get("flash", 0.0)
	for x: float in [-32.0, 24.0]:
		Art.t_rect(ci, Rect2(x, -124, 8, 118), 2, m["trim"], 2.6, 0.3)
	Art.t_rect(ci, Rect2(-40, -134, 80, 20), 6, m["body"], 3.0, 0.5)
	if tier >= 1:
		_rivets(ci, Rect2(-40, -134, 80, 20))
	Art.push(ci, Vector2(0, Props._q(p, 10) * 34.0))
	Art.t_rect(ci, Rect2(-6, -116, 12, 40), 2, Art.METAL, 2.4, 0.3)
	Art.t_rect(ci, Rect2(-18, -80, 36, 14), 4, m["dark"], 2.6, 0.3)
	Art.pop(ci)
	Art.t_rect(ci, Rect2(-34, -32, 68, 28), 6, m["body"], 3.0, 0.5)
	Art.t_rect(ci, Rect2(-20, -40, 40, 10), 3, Art.METAL, 2.4, 0.3)
	Art.coin(ci, Vector2(0, -44), 8.0 + flash * 3.0)
	# Output chute to the right.
	Art.toon(ci, PackedVector2Array([Vector2(30, -30), Vector2(50, -40), Vector2(54, -32), Vector2(34, -20)]), m["trim"], 2.4, 0.3)
	Art.t_rect(ci, Rect2(30, -10, 22, 10), 3, m["dark"], 2.2, 0.2)
	Art.coin(ci, Vector2(41, -14), 6)


# --- Products tube --------------------------------------------------------------------

## The glass tube from `a` (bottom) straight up to `top_y`, with a funnel at
## its foot. `caps` are 0..1 positions of capsules going up.
static func pipe(ci: CanvasItem, a: Vector2, top_y: float, lk: Dictionary, caps: Array) -> void:
	var r := Rect2(a.x - 12, top_y, 24, a.y - top_y)
	Art.flat(ci, Art.rrect_pts(r, 0.0), Color(0.8, 0.96, 1.0, 0.45))
	for c in caps:
		var y := lerpf(a.y - 10.0, top_y + 6.0, float(c))
		Art.push(ci, Vector2(a.x, y))
		Art.t_rect(ci, Rect2(-8, -11, 16, 22), 7, Art.GOLD, 2.2, 0.4)
		Art.flat(ci, Art.rrect_pts(Rect2(-8, -2, 16, 4), 1), Art.GOLD_DARK)
		Art.pop(ci)
	Art.line(ci, Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Art.INK, 3.0)
	Art.line(ci, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Art.INK, 3.0)
	Art.line(ci, Vector2(r.position.x + 5, r.position.y), Vector2(r.position.x + 5, r.end.y), Color(1, 1, 1, 0.6), 2.5)
	var y := top_y + 30.0
	while y < a.y - 10.0:
		Art.t_rect(ci, Rect2(a.x - 15, y, 30, 7), 2, lk["beam"], 2.2, 0.2)
		y += 70.0
	# Funnel at the foot and the ceiling collar.
	Art.toon(ci, PackedVector2Array([a + Vector2(-26, 0), a + Vector2(26, 0), a + Vector2(14, -18), a + Vector2(-14, -18)]), Art.METAL, 2.8, 0.4)
	Art.t_rect(ci, Rect2(a.x - 20, top_y - 4, 40, 14), 4, Art.METAL, 2.6, 0.3)


# --- Mezzanine --------------------------------------------------------------------------

## A balcony deck from x0 to x1 whose walking surface is at y (local),
## with a railing and posts down to `floor_y`.
static func mezzanine(ci: CanvasItem, x0: float, x1: float, y: float, floor_y: float, lk: Dictionary) -> void:
	var c: Color = lk["beam"]
	var x := x0 + 20.0
	while x < x1:
		Art.t_rect(ci, Rect2(x - 5, y, 10, floor_y - y), 2, Art.shade_of(c, 0.1), 2.4, 0.2)
		x += 140.0
	Art.t_rect(ci, Rect2(x0, y, x1 - x0, 16), 3, c, 3.0, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(x0 + 4, y + 10, x1 - x0 - 8, 3), 1), Color(0, 0, 0, 0.2))


## The railing in front of what stands on the mezzanine.
static func railing(ci: CanvasItem, x0: float, x1: float, y: float, lk: Dictionary) -> void:
	var c: Color = Art.GOLD if str(lk["style"]) != "panels" else lk["accent"]
	Art.stroke(ci, PackedVector2Array([Vector2(x0 + 4, y - 30), Vector2(x1 - 4, y - 30)]), c, 5.0, 2.0)
	var x := x0 + 8.0
	while x <= x1 - 4.0:
		Art.line_c(ci, PackedVector2Array([Vector2(x, y - 30), Vector2(x, y)]), Art.shade_of(c, 0.25), 3.0)
		x += 22.0


## Tarp-covered spot of the second line while it is not bought: a padlock
## and a "?" on a crate pile.
static func closed_line(ci: CanvasItem, lk: Dictionary) -> void:
	for x: float in [90.0, 210.0, 320.0]:
		Art.push(ci, Vector2(x, 0))
		var tarp := Art.smooth_pts(PackedVector2Array([Vector2(-42, 0), Vector2(-38, -50), Vector2(-14, -72), Vector2(16, -70), Vector2(38, -46), Vector2(42, 0)]), 3)
		Art.toon(ci, tarp, Color("8ba0b8") if str(lk["style"]) != "plates" else Color("6f6a7c"), 3.0, 0.6)
		Art.line_c(ci, PackedVector2Array([Vector2(-30, -30), Vector2(30, -36)]), Color(0, 0, 0, 0.2), 3.0)
		Art.pop(ci)
	Art.lock(ci, Vector2(210, -96), 30)


# --- Wall details -------------------------------------------------------------------------

## A lamp hanging from the ceiling on a cord `cord` long; origin at the
## ceiling. Its warm light cone is drawn under it.
static func hanging_lamp(ci: CanvasItem, cord: float, lk: Dictionary) -> void:
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, cord)]), Art.INK, 2.5)
	Art.flat(ci, PackedVector2Array([Vector2(-16, cord + 14), Vector2(16, cord + 14), Vector2(70, cord + 190), Vector2(-70, cord + 190)]), Color(lk["glow"], 0.13))
	Art.toon(ci, PackedVector2Array([Vector2(-6, cord), Vector2(6, cord), Vector2(18, cord + 16), Vector2(-18, cord + 16)]), lk["beam"], 2.5, 0.4)
	Art.t_circle(ci, Vector2(0, cord + 17), 6, Color("fff3c4"), 2.0, 0.0)


## The world's sign on the wall (~70 px): a life ring (ocean), a hot
## warning (volcano), a flask (acid lab), a rocket (moon).
static func emblem(ci: CanvasItem, lk: Dictionary) -> void:
	match str(lk["style"]):
		"planks":
			Art.t_circle(ci, Vector2.ZERO, 32, Art.WHITE, 3.0, 0.5)
			for k in 4:
				var a := k * PI / 2.0 + PI / 4.0
				Art.flat(ci, PackedVector2Array([Vector2(cos(a - 0.3), sin(a - 0.3)) * 31, Vector2(cos(a + 0.3), sin(a + 0.3)) * 31,
						Vector2(cos(a + 0.4), sin(a + 0.4)) * 17, Vector2(cos(a - 0.4), sin(a - 0.4)) * 17]), Art.RED)
			Art.t_circle(ci, Vector2.ZERO, 16, lk["wall"], 3.0, 0.0)
			Art.arc_c(ci, Vector2.ZERO, 24, -PI * 0.9, -PI * 0.6, 6, Color(1, 1, 1, 0.8), 3.0)
		"plates":
			Art.toon(ci, PackedVector2Array([Vector2(0, -34), Vector2(36, 28), Vector2(-36, 28)]), Art.GOLD, 3.5, 0.4)
			Art.toon(ci, PackedVector2Array([Vector2(-8, 18), Vector2(-4, 4), Vector2(0, 10), Vector2(3, -6), Vector2(8, 18)]), Color("ff6a1f"), 2.0, 0.0)
		"tiles":
			Art.t_rect(ci, Rect2(-34, -34, 68, 68), 10, Art.WHITE, 3.0, 0.3)
			Art.toon(ci, PackedVector2Array([Vector2(-6, -24), Vector2(6, -24), Vector2(6, -8), Vector2(20, 18), Vector2(-20, 18), Vector2(-6, -8)]), Color("e8fff0"), 2.6, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-14, 6), Vector2(14, 6), Vector2(20, 18), Vector2(-20, 18)]), Color("7dff5a"), 0.0, 0.0)
			Art.ring(ci, PackedVector2Array([Vector2(-6, -24), Vector2(6, -24), Vector2(6, -8), Vector2(20, 18), Vector2(-20, 18), Vector2(-6, -8)]), Art.INK, 2.6)
			Art.disc(ci, Vector2(-4, 10), 3, Art.WHITE)
		"panels":
			Art.t_rect(ci, Rect2(-30, -40, 60, 80), 8, Color("1d2350"), 3.0, 0.2)
			Art.toon(ci, PackedVector2Array([Vector2(0, -30), Vector2(10, -12), Vector2(10, 14), Vector2(-10, 14), Vector2(-10, -12)]), Art.WHITE, 2.4, 0.4)
			Art.toon(ci, PackedVector2Array([Vector2(-10, 4), Vector2(-18, 18), Vector2(-10, 14)]), Art.RED, 2.0, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(10, 4), Vector2(18, 18), Vector2(10, 14)]), Art.RED, 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, -6), 4, Color("5ad2ff"), 1.8, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-6, 16), Vector2(6, 16), Vector2(0, 30)]), Color("ffb13b"), 1.8, 0.0)
			for p: Vector2 in [Vector2(-20, -30), Vector2(20, -20), Vector2(-18, 28), Vector2(21, 30)]:
				Art.disc(ci, p, 1.8, Art.WHITE)


## A round wall clock (static hands).
static func clock(ci: CanvasItem, lk: Dictionary) -> void:
	Art.t_circle(ci, Vector2.ZERO, 22, lk["beam"], 3.0, 0.3)
	Art.t_circle(ci, Vector2.ZERO, 17, Art.CREAM, 2.0, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, -12)]), Art.INK, 2.5)
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(8, 3)]), Art.INK, 2.5)
	Art.disc(ci, Vector2.ZERO, 2.5, Art.RED)
