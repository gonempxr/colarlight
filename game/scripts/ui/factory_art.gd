class_name FactoryArt
extends RefCounted
## The factory hall (room 2), drawn in local space with Art's toon kit.
## Callers place the parts with Art.push/pop (see FactoryRoom).
##
## Most pieces come in two halves so the room can cache what stands still:
##   static pieces       drawn once into a PaintLayer (hall, windows, machine
##                       bodies, shelves, signs...)
##   *_live pieces       drawn every frame, small (gears, flames, the piston,
##                       belt slats, needles, smoke, sparks)
##
##   hall(...)          back wall, steel columns, ceiling truss and floor,
##                      tinted per world (look(world_id))
##   window(...)        an industrial window onto the world outside
##   line_back/live     a machine line at a building stage 1..20: crusher,
##                      furnace, polisher and coin press. Stages 1-4 add the
##                      machines one by one; every 4 stages after that the
##                      line gets a new material tier (wood -> painted steel ->
##                      teal and brass -> white hi-tech -> gold and crystal),
##                      and inside a tier beacons, overhead pipes and a sign.
##   pipe(...)          the glass product tube up into the ceiling (to room 3)
##   dock_door(...)     the rolling dock door where boat crates come in
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

## Per world: hall colors, the furnace flame and the wall dressing.
##   wall/wall2/low  back wall, its pattern and the low band
##   style           planks, plates, tiles, panels or temple (the jungle:
##                   see "Jungle: the temple workshop" at the end)
##   beam/col/pipe   ceiling beams, steel columns, wall pipes
##   haz             safety paint (stripes, walkway, railings)
##   sky/sky2        outside, seen through windows and the dock door
const LOOKS := {
	"ocean": {"wall": Color("e3ad72"), "wall2": Color("d29a5e"), "low": Color("4f97c8"), "beam": Color("8e552c"),
		"col": Color("6f7f9c"), "pipe": Color("3aa6f0"), "haz": Color("ffc93c"),
		"floor": Color("9a7552"), "floor2": Color("876343"), "sky": Color("8fe0ff"), "sky2": Color("35c9d2"),
		"accent": Color("3aa6f0"), "flame": Color("ff9a3c"), "glow": Color("ffd27a"), "style": "planks"},
	"volcano": {"wall": Color("6a6d82"), "wall2": Color("5a5c70"), "low": Color("43445a"), "beam": Color("33344a"),
		"col": Color("3a3c50"), "pipe": Color("d0603a"), "haz": Color("ffc93c"),
		"floor": Color("4c4757"), "floor2": Color("3d3948"), "sky": Color("ffb35c"), "sky2": Color("e0482c"),
		"accent": Color("ff7a2e"), "flame": Color("ff6a1f"), "glow": Color("ff9a3c"), "style": "plates"},
	"acid": {"wall": Color("dff3d6"), "wall2": Color("c9e8bd"), "low": Color("62c873"), "beam": Color("3f7a5a"),
		"col": Color("3f7a5a"), "pipe": Color("8a6cf0"), "haz": Color("c8ff5a"),
		"floor": Color("9fc9a8"), "floor2": Color("88b591"), "sky": Color("c6ff8a"), "sky2": Color("5fbf4a"),
		"accent": Color("7dff5a"), "flame": Color("8cff3c"), "glow": Color("c8ff7a"), "style": "tiles"},
	"moon": {"wall": Color("eef3fb"), "wall2": Color("dde6f4"), "low": Color("8fb4e8"), "beam": Color("9aa9c4"),
		"col": Color("aab8d0"), "pipe": Color("5ad2ff"), "haz": Color("5ad2ff"),
		"floor": Color("c4cfe2"), "floor2": Color("b0bdd4"), "sky": Color("2a2f6a"), "sky2": Color("12163a"),
		"accent": Color("5ad2ff"), "flame": Color("6ad8ff"), "glow": Color("a8ecff"), "style": "panels"},
	"jungle": {"wall": Color("e8cd94"), "wall2": Color("dcbc80"), "low": Color("b98f58"), "beam": Color("7a4a26"),
		"col": Color("dcc28a"), "pipe": Color("d6c25e"), "haz": Color("d6c25e"),
		"floor": Color("c4a676"), "floor2": Color("8a7048"), "sky": Color("7fd0f2"), "sky2": Color("d4f2dc"),
		"accent": Color("3fd6c0"), "flame": Color("ff8a2a"), "glow": Color("ffd98a"), "style": "temple"},	# The Twilight Zone (saga act I): a coral workshop at dusk, lilac tiles,
	# violet beams, pink pipes, cyan glow; the window shows the dusk sea.
	"twilight": {"wall": Color("eed6f4"), "wall2": Color("e0c2ec"), "low": Color("8a5ad8"), "beam": Color("4a2e9a"),
		"col": Color("6a4ab8"), "pipe": Color("ff6ad8"), "haz": Color("6af8ff"),
		"floor": Color("a088cc"), "floor2": Color("8a70b8"), "sky": Color("c75ad6"), "sky2": Color("3ee8e0"),
		"accent": Color("6af8ff"), "flame": Color("ff6ad8"), "glow": Color("9afcff"), "style": "tiles"},
	# Atlantis (saga act II): a marble hall with gold beams, bronze pipes,
	# orichalcum glow; the window shows the clear blue sea.
	"atlantis": {"wall": Color("f4eee0"), "wall2": Color("e8dcc4"), "low": Color("2a8ed8"), "beam": Color("c7843a"),
		"col": Color("e0d4b8"), "pipe": Color("c7843a"), "haz": Color("ffc93c"),
		"floor": Color("d8c8a0"), "floor2": Color("2a6ec8"), "sky": Color("6ab8f0"), "sky2": Color("4ad8f0"),
		"accent": Color("4af0e0"), "flame": Color("ffc93c"), "glow": Color("ffe07a"), "style": "temple"},
}

## Machine materials per tier: body, trim, dark parts, light/glow.
const TIERS := [
	{"body": Color("c98249"), "trim": Color("8d94a6"), "dark": Color("6e4426"), "light": Color("ffd27a")},
	{"body": Color("ef6a4f"), "trim": Color("cbd5e1"), "dark": Color("5a5f7a"), "light": Color("ffe38a")},
	{"body": Color("2bb8b4"), "trim": Color("f5b843"), "dark": Color("2f5a6e"), "light": Color("bff3ff")},
	{"body": Color("f4f7ff"), "trim": Color("5ad2ff"), "dark": Color("5a6a8a"), "light": Color("7be8ff")},
	{"body": Color("ffc93c"), "trim": Color("a77cff"), "dark": Color("7a4ad0"), "light": Color("fff1a8")},
]

const PENNANTS := [Color("ef5350"), Color("ffc93c"), Color("3aa6f0"), Color("5cd05f"), Color("8a6cf0"), Color("ff7ab8")]


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


static func _mat(stage: int, variant: int, temple: bool = false) -> Dictionary:
	var m: Dictionary = (TEMPLE_TIERS if temple else TIERS)[tier_of(stage)]
	if variant == 0:
		return m
	return {"body": _alt(m["body"]), "trim": _alt(m["trim"]), "dark": m["dark"], "light": m["light"]}


static func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Vertical gradient over a rect.
static func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	Art.grad(ci, _quad(r), PackedColorArray([top, top, bottom, bottom]))


# --- The hall ------------------------------------------------------------------------

## Back wall, steel columns (x centers in `cols`), ceiling truss and floor of
## a hall `w` x `h` (local, origin top-left) whose floor line is at `floor_y`.
static func hall(ci: CanvasItem, w: float, h: float, floor_y: float, lk: Dictionary, cols: Array = []) -> void:
	var wall: Color = lk["wall"]
	var wall2: Color = lk["wall2"]
	Art.flat(ci, _quad(Rect2(0, 0, w, floor_y)), wall)
	match str(lk["style"]):
		"planks":
			var x := 0.0
			var i := 0
			while x < w:
				if i % 2 == 1:
					Art.flat(ci, _quad(Rect2(x, 0, 34, floor_y)), wall2)
				Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x, floor_y)]), Art.shade_of(wall, 0.35), 2.0)
				# Knots and nails.
				if i % 3 == 0:
					Art.flat(ci, Art.ellipse_pts(Vector2(x + 17, fmod(i * 97.0, floor_y * 0.7) + 60), Vector2(4, 2.5), 10), Art.shade_of(wall, 0.3))
				Art.disc(ci, Vector2(x + 6, 64), 1.8, Art.shade_of(wall, 0.45))
				Art.disc(ci, Vector2(x + 6, floor_y - 80), 1.8, Art.shade_of(wall, 0.45))
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
			# A warm glow from below (the heat of the hall).
			_vgrad(ci, Rect2(0, floor_y * 0.5, w, floor_y * 0.5), Color(1.0, 0.45, 0.15, 0.0), Color(1.0, 0.45, 0.15, 0.2))
		"tiles":
			var y := 0.0
			while y < floor_y:
				Art.line_c(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y)]), wall2, 2.0)
				y += 30.0
			var x := 0.0
			while x < w:
				Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x, floor_y)]), wall2, 2.0)
				x += 30.0
			# A few green-tinted tiles.
			for k in int(w / 50.0):
				var tx := floorf(fmod(k * 157.0, w) / 30.0) * 30.0
				var ty := floorf(fmod(k * 91.0 + 40.0, floor_y * 0.8) / 30.0) * 30.0
				Art.flat(ci, _quad(Rect2(tx + 1, ty + 1, 28, 28)), Color(lk["accent"], 0.2))
		"panels":
			var x := 0.0
			while x < w:
				var r := Rect2(x + 4, 6, 72, floor_y - 12)
				Art.flat(ci, Art.rrect_pts(r, 12.0), wall2)
				Art.flat(ci, Art.rrect_pts(Rect2(x + 36, 18, 4, floor_y * 0.5), 2.0), Color(lk["accent"], 0.35))
				Art.disc(ci, Vector2(x + 38, floor_y * 0.5 + 26), 3.0, Color(lk["accent"], 0.6))
				x += 80.0
		"temple":
			_temple_wall(ci, w, floor_y, lk)
	# The top of the wall is in the ceiling's shadow.
	_vgrad(ci, Rect2(0, 0, w, 150), Color(Art.SHADE, 0.24), Color(Art.SHADE, 0.0))
	if is_temple(lk):
		_temple_band(ci, w, floor_y, lk)
		for cx in cols:
			column(ci, float(cx), 20.0, floor_y, lk)
		ceiling(ci, w, lk)
		floor_band(ci, w, floor_y, h, lk)
		return
	# Lower wall band (wainscot) along the floor, with a safety stripe.
	var band := Rect2(0, floor_y - 58, w, 58)
	Art.flat(ci, _quad(band), lk["low"])
	_vgrad(ci, band, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.16))
	Art.flat(ci, _quad(Rect2(0, floor_y - 62, w, 8)), Art.shade_of(lk["low"], 0.3))
	var x2 := 0.0
	while x2 < w:
		Art.flat(ci, PackedVector2Array([Vector2(x2, floor_y - 54), Vector2(x2 + 12, floor_y - 54), Vector2(x2 + 4, floor_y - 46), Vector2(x2 - 8, floor_y - 46)]), Color(lk["haz"], 0.85))
		x2 += 24.0
	Art.line_c(ci, PackedVector2Array([Vector2(0, floor_y - 46), Vector2(w, floor_y - 46)]), Art.shade_of(lk["low"], 0.3), 2.0)
	# Steel columns.
	for cx in cols:
		column(ci, float(cx), 20.0, floor_y, lk)
	# Ceiling: a beam and a truss under it.
	ceiling(ci, w, lk)
	# Floor.
	floor_band(ci, w, floor_y, h, lk)


## The ceiling beam with a truss under it (0..56).
static func ceiling(ci: CanvasItem, w: float, lk: Dictionary) -> void:
	if is_temple(lk):
		_temple_ceiling(ci, w, lk)
		return
	var c: Color = Art.shade_of(lk["col"], 0.1)
	var x := -20.0
	var up := true
	while x < w + 40.0:
		var seg := PackedVector2Array([Vector2(x, 24 if up else 50), Vector2(x + 34, 50 if up else 24)])
		Art.line_c(ci, seg, Art.INK, 7.0)
		Art.line_c(ci, seg, c, 3.0)
		x += 34.0
		up = not up
	Art.stroke(ci, PackedVector2Array([Vector2(-10, 50), Vector2(w + 10, 50)]), c, 5.0, 2.0)
	Art.t_rect(ci, Rect2(-10, -6, w + 20, 30), 0.0, lk["beam"], 3.0, 0.5)
	var bx := 20.0
	while bx < w:
		Art.disc(ci, Vector2(bx, 12), 2.6, Art.shade_of(lk["beam"], 0.4))
		bx += 46.0


## A steel I-beam column from y0 down to the floor at y1.
static func column(ci: CanvasItem, x: float, y0: float, y1: float, lk: Dictionary) -> void:
	if is_temple(lk):
		_temple_pillar(ci, x, y0, y1, lk)
		return
	var c: Color = lk["col"]
	Art.flat(ci, _quad(Rect2(x - 15, y0, 30, y1 - y0)), Color(0, 0, 0, 0.08))
	Art.t_rect(ci, Rect2(x - 11, y0, 22, y1 - y0), 2, c, 2.6, 0.5)
	Art.flat(ci, _quad(Rect2(x - 4, y0 + 4, 8, y1 - y0 - 8)), Art.shade_of(c, 0.18))
	Art.flat(ci, _quad(Rect2(x - 9, y0 + 4, 2, y1 - y0 - 8)), Color(1, 1, 1, 0.22))
	var y := y0 + 40.0
	while y < y1 - 30.0:
		for sx: float in [-7.0, 7.0]:
			Art.disc(ci, Vector2(x + sx, y), 1.8, Art.shade_of(c, 0.45))
		y += 70.0
	Art.t_rect(ci, Rect2(x - 16, y1 - 10, 32, 10), 2, Art.shade_of(c, 0.15), 2.4, 0.3)


## Floor from `y0` (the wall's foot) down to `y1`.
static func floor_band(ci: CanvasItem, w: float, y0: float, y1: float, lk: Dictionary) -> void:
	if is_temple(lk):
		_temple_floor(ci, w, y0, y1, lk)
		return
	Art.flat(ci, _quad(Rect2(0, y0, w, y1 - y0)), lk["floor"])
	var fy := y0 + 10.0
	var k := 0
	while fy < y1:
		Art.line_c(ci, PackedVector2Array([Vector2(0, fy), Vector2(w, fy)]), lk["floor2"], 2.0)
		var step := 10.0 + k * 5.0
		var fx := fmod(k * 37.0, 90.0)
		while fx < w:
			Art.line_c(ci, PackedVector2Array([Vector2(fx, fy), Vector2(fx, minf(fy + step, y1))]), lk["floor2"], 2.0)
			fx += 90.0
		fy += step
		k += 1
	# Walkway paint and the shadow at the wall's foot.
	var wy := y0 + 34.0
	if wy < y1 - 8.0:
		var x := 6.0
		while x < w:
			Art.flat(ci, Art.rrect_pts(Rect2(x, wy, 26, 5), 2), Color(lk["haz"], 0.75))
			x += 40.0
	_vgrad(ci, Rect2(0, y0, w, 18), Color(Art.SHADE, 0.3), Color(Art.SHADE, 0.0))
	_vgrad(ci, Rect2(0, y0 - 24, w, 24), Color(Art.SHADE, 0.0), Color(Art.SHADE, 0.12))
	Art.line_c(ci, PackedVector2Array([Vector2(0, y0), Vector2(w, y0)]), Art.INK, 3.0)


## Horizontal wall pipes from x0 to x1 at y, with brackets and a valve
## wheel at each x in `valves`.
static func wall_pipes(ci: CanvasItem, x0: float, x1: float, y: float, lk: Dictionary, valves: Array = []) -> void:
	if is_temple(lk):
		# A bamboo aqueduct: an open half pipe of running water on brackets.
		var x := x0 + 30.0
		while x < x1 - 10.0:
			Art.t_rect(ci, Rect2(x - 4, y - 2, 8, 26), 2, Color("8a6a3a"), 2.0, 0.2)
			x += 120.0
		_bamboo(ci, Vector2(x0, y + 4), Vector2(x1, y + 4), 14.0)
		Art.flat(ci, _quad(Rect2(x0, y - 4, x1 - x0, 5)), JADE)
		Art.line_c(ci, PackedVector2Array([Vector2(x0, y - 4), Vector2(x1, y - 4)]), Color(1, 1, 1, 0.5), 1.6)
		return
	var p: Color = lk["pipe"]
	var p2: Color = Art.shade_of(lk["col"], -0.1)
	Art.stroke(ci, PackedVector2Array([Vector2(x0, y + 20), Vector2(x1, y + 20)]), p2, 7.0, 2.2)
	Art.stroke(ci, PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]), p, 11.0, 2.4)
	Art.line_c(ci, PackedVector2Array([Vector2(x0 + 4, y - 3), Vector2(x1 - 4, y - 3)]), Color(1, 1, 1, 0.35), 2.5)
	var x := x0 + 30.0
	while x < x1 - 10.0:
		Art.t_rect(ci, Rect2(x - 4, y - 8, 8, 36), 2, Art.shade_of(lk["col"], 0.2), 2.0, 0.2)
		if x + 60.0 < x1:
			Art.t_rect(ci, Rect2(x + 56, y - 8, 8, 16), 2, Art.shade_of(p, 0.2), 2.0, 0.2)
		x += 120.0
	for vx in valves:
		valve(ci, Vector2(float(vx), y - 18))


## A red valve wheel on a short stem.
static func valve(ci: CanvasItem, at: Vector2) -> void:
	Art.t_rect(ci, Rect2(at.x - 3, at.y, 6, 14), 1, Art.METAL, 1.8, 0.0)
	Art.t_circle(ci, at, 10, Art.RED, 2.4, 0.4)
	Art.t_circle(ci, at, 5, Art.shade_of(Art.RED, 0.3), 0.0, 0.0)
	for k in 4:
		Art.line_c(ci, PackedVector2Array([at, at + Vector2(9, 0).rotated(k * PI / 2.0 + PI / 4.0)]), Art.INK, 2.0)
	Art.disc(ci, at, 2.5, Art.GOLD)


## An industrial window onto the world outside (sea, volcano, swamp, space).
static func window(ci: CanvasItem, r: Rect2, lk: Dictionary) -> void:
	if is_temple(lk):
		_temple_window(ci, r, lk)
		return
	Art.t_rect(ci, r.grow(7), 6, lk["beam"], 3.0, 0.4)
	scene(ci, r, lk)
	# Glass glints, the panes and the sill.
	Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.12, 0), r.position + Vector2(r.size.x * 0.3, 0),
			r.position + Vector2(r.size.x * 0.08, r.size.y), r.position + Vector2(-0.0, r.size.y)]), Color(1, 1, 1, 0.18))
	Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.36, 0), r.position + Vector2(r.size.x * 0.42, 0),
			r.position + Vector2(r.size.x * 0.3, r.size.y), r.position + Vector2(r.size.x * 0.24, r.size.y)]), Color(1, 1, 1, 0.12))
	var cols := 3 if r.size.x > 110.0 else 2
	for i in range(1, cols):
		var x := r.position.x + r.size.x * i / float(cols)
		Art.line_c(ci, PackedVector2Array([Vector2(x, r.position.y), Vector2(x, r.end.y)]), lk["beam"], 5.0)
	Art.line_c(ci, PackedVector2Array([Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y)]), lk["beam"], 5.0)
	Art.ring(ci, Art.rrect_pts(r, 3), Art.INK, 3.0)
	Art.t_rect(ci, Rect2(r.position.x - 12, r.end.y + 4, r.size.x + 24, 9), 3, Art.shade_of(lk["beam"], -0.1), 2.6, 0.3)


## What is outside, drawn inside `r` (also used by the dock door).
static func scene(ci: CanvasItem, r: Rect2, lk: Dictionary) -> void:
	_vgrad(ci, r, lk["sky"], lk["sky2"])
	var p := r.position
	var s := r.size
	match str(lk["style"]):
		"planks":
			Art.t_circle(ci, p + Vector2(s.x * 0.78, s.y * 0.26), minf(11.0, s.y * 0.14), Art.GOLD, 0.0, 0.0)
			Art.flat(ci, Art.ellipse_pts(p + Vector2(s.x * 0.3, s.y * 0.24), Vector2(s.x * 0.16, s.y * 0.07), 14), Color(1, 1, 1, 0.85))
			Art.flat(ci, Art.ellipse_pts(p + Vector2(s.x * 0.4, s.y * 0.2), Vector2(s.x * 0.1, s.y * 0.08), 14), Color(1, 1, 1, 0.85))
			Art.flat(ci, Art.ellipse_pts(p + Vector2(s.x * 0.2, s.y * 0.62), Vector2(s.x * 0.2, s.y * 0.08), 16), Color("4aa86a"))
			_vgrad(ci, Rect2(p.x, p.y + s.y * 0.62, s.x, s.y * 0.38), Color("2a9ad0"), Color("1c6fa8"))
			for i in 3:
				var y := p.y + s.y * (0.72 + i * 0.09)
				var x0 := p.x + fmod(i * 23.0, s.x * 0.4) + 4.0
				Art.line_c(ci, PackedVector2Array([Vector2(x0, y), Vector2(x0 + s.x * 0.22, y)]), Color(1, 1, 1, 0.45), 2.0)
			# A little sail on the horizon.
			var b := p + Vector2(s.x * 0.62, s.y * 0.64)
			Art.flat(ci, PackedVector2Array([b + Vector2(-8, 0), b + Vector2(8, 0), b + Vector2(5, 4), b + Vector2(-5, 4)]), Color("8e552c"))
			Art.flat(ci, PackedVector2Array([b + Vector2(0, -14), b + Vector2(7, -1), b + Vector2(0, -1)]), Art.WHITE)
		"plates":
			Art.flat(ci, Art.ellipse_pts(p + Vector2(s.x * 0.3, s.y * 0.2), Vector2(s.x * 0.22, s.y * 0.08), 14), Color(0.25, 0.15, 0.2, 0.45))
			Art.flat(ci, PackedVector2Array([p + Vector2(s.x * 0.05, s.y), p + Vector2(s.x * 0.42, s.y * 0.3), p + Vector2(s.x * 0.58, s.y * 0.3), p + Vector2(s.x * 0.95, s.y)]), Color("4a3a48"))
			Props.halo(ci, p + Vector2(s.x * 0.5, s.y * 0.3), s.x * 0.3, Color(1.0, 0.6, 0.2, 0.6))
			Art.flat(ci, PackedVector2Array([p + Vector2(s.x * 0.45, s.y * 0.3), p + Vector2(s.x * 0.55, s.y * 0.3),
					p + Vector2(s.x * 0.6, s.y), p + Vector2(s.x * 0.47, s.y)]), Color("ff7a2e"))
			Art.flat(ci, PackedVector2Array([p + Vector2(s.x * 0.49, s.y * 0.32), p + Vector2(s.x * 0.52, s.y * 0.32),
					p + Vector2(s.x * 0.55, s.y), p + Vector2(s.x * 0.51, s.y)]), Color("ffd23f"))
			_vgrad(ci, Rect2(p.x, p.y + s.y * 0.84, s.x, s.y * 0.16), Color("ff7a2e"), Color("ffb13b"))
		"tiles":
			_vgrad(ci, Rect2(p.x, p.y + s.y * 0.7, s.x, s.y * 0.3), Color("3f7a3a"), Color("2a5a2a"))
			for i in 3:
				var c := p + Vector2(s.x * (0.18 + i * 0.3), s.y * 0.74)
				Art.flat(ci, _quad(Rect2(c.x - 2, c.y, 4, s.y * 0.2)), Color("f4ead6"))
				Art.flat(ci, Art.ellipse_pts(c, Vector2(s.x * 0.09, s.y * 0.08), 12), Color("ff6fa8") if i == 1 else Color("b06ae0"))
				Art.disc(ci, c + Vector2(-3, -2), 2.0, Color(1, 1, 1, 0.8))
			for i in 4:
				Art.disc(ci, p + Vector2(fmod(i * 41.0, s.x - 10) + 5, s.y * (0.2 + 0.12 * i)), 2.5 + i % 2, Color(1, 1, 1, 0.55))
		"panels":
			for i in 9:
				Art.disc(ci, p + Vector2(fmod(i * 37.0, s.x - 10) + 5, 5 + fmod(i * 23.0, s.y * 0.6)), 1.6, Art.WHITE)
			var e := p + Vector2(s.x * 0.7, s.y * 0.34)
			var er := minf(s.x, s.y) * 0.17
			Props.halo(ci, e, er * 1.8, Color(0.4, 0.7, 1.0, 0.3))
			Art.t_circle(ci, e, er, Color("3a8ae0"), 0.0, 0.0)
			Art.flat(ci, Art.ellipse_pts(e + Vector2(-er * 0.3, -er * 0.1), Vector2(er * 0.4, er * 0.3), 10, 0.4), Color("5cd05f"))
			Art.flat(ci, Art.ellipse_pts(e + Vector2(er * 0.4, er * 0.4), Vector2(er * 0.3, er * 0.2), 10), Color("5cd05f"))
			var g := PackedVector2Array([p + Vector2(0, s.y * 0.8), p + Vector2(s.x * 0.3, s.y * 0.72), p + Vector2(s.x * 0.65, s.y * 0.8),
					p + Vector2(s.x, s.y * 0.74), p + Vector2(s.x, s.y), p + Vector2(0, s.y)])
			Art.flat(ci, g, Color("9aa3b8"))
			Art.flat(ci, Art.ellipse_pts(p + Vector2(s.x * 0.3, s.y * 0.88), Vector2(s.x * 0.08, s.y * 0.03), 12), Color("7a8398"))
		"temple":
			_jungle_scene(ci, r, lk)


## Soft light falling from a window rect `r` to the floor.
static func shaft(ci: CanvasItem, r: Rect2, floor_y: float, lk: Dictionary) -> void:
	var dx := (floor_y - r.end.y) * 0.35
	var c := Color(lk["glow"], 0.13)
	var clear := Color(lk["glow"], 0.0)
	Art.grad(ci, PackedVector2Array([Vector2(r.position.x + 6, r.end.y), Vector2(r.end.x - 6, r.end.y),
			Vector2(r.end.x + dx + 20, floor_y + 20), Vector2(r.position.x + dx - 10, floor_y + 20)]), PackedColorArray([c, c, clear, clear]))


## A lamp hanging from the ceiling on a cord `cord` long; origin at the
## ceiling. Its warm light cone is drawn under it.
static func hanging_lamp(ci: CanvasItem, cord: float, lk: Dictionary, cone: float = 190.0) -> void:
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, cord)]), Art.INK, 2.5)
	var c := Color(lk["glow"], 0.16)
	var clear := Color(lk["glow"], 0.0)
	Art.grad(ci, PackedVector2Array([Vector2(-16, cord + 14), Vector2(16, cord + 14), Vector2(cone * 0.4, cord + cone), Vector2(-cone * 0.4, cord + cone)]),
			PackedColorArray([c, c, clear, clear]))
	Props.halo(ci, Vector2(0, cord + 18), 34, Color(lk["glow"], 0.35))
	if is_temple(lk):
		# A woven rattan lantern.
		Art.t_rect(ci, Rect2(-5, cord - 2, 10, 6), 2, Art.WOOD_DARK, 1.8, 0.0)
		Art.t_circle(ci, Vector2(0, cord + 16), 14, Color("c98a4a"), 2.6, 0.5)
		Art.t_circle(ci, Vector2(0, cord + 16), 8, Color("fff3c4"), 0.0, 0.0)
		for k in 3:
			Art.arc_c(ci, Vector2(0, cord + 16), 12.0 - k * 4.0, PI * 0.15, PI * 0.85, 8, Color("8e552c"), 1.6)
			Art.arc_c(ci, Vector2(0, cord + 16), 12.0 - k * 4.0, PI * 1.15, PI * 1.85, 8, Color("8e552c"), 1.6)
		Art.line_c(ci, PackedVector2Array([Vector2(-13, cord + 16), Vector2(13, cord + 16)]), Color("8e552c"), 1.6)
		Art.toon(ci, PackedVector2Array([Vector2(-4, cord + 29), Vector2(4, cord + 29), Vector2(0, cord + 38)]), Color("ff8a2a"), 1.6, 0.0)
		return
	Art.toon(ci, PackedVector2Array([Vector2(-7, cord), Vector2(7, cord), Vector2(22, cord + 17), Vector2(-22, cord + 17)]), lk["beam"], 2.5, 0.4)
	Art.t_circle(ci, Vector2(0, cord + 18), 7, Color("fff3c4"), 2.0, 0.0)


# --- Wall and floor dressing ------------------------------------------------------------

## A storage rack standing on the floor (origin bottom-left), `w` x `h`,
## with crates, barrels and the world's own things on its shelves.
static func rack(ci: CanvasItem, w: float, h: float, lk: Dictionary, seed: int) -> void:
	var post := Art.shade_of(lk["col"], -0.05)
	var levels := 3 if h > 110.0 else 2
	var lh := (h - 8.0) / levels
	Art.flat(ci, _quad(Rect2(4, -h, w - 8, h)), Color(0, 0, 0, 0.12))
	for i in levels:
		_rack_items(ci, Vector2(8, -8.0 - i * lh - 6.0), w - 16.0, lh - 14.0, lk, seed + i * 7)
	var shelf := Color("b07a3e") if is_temple(lk) else Color("ff8a3c")
	if is_temple(lk):
		post = BAMBOO
	for i in levels + 1:
		Art.t_rect(ci, Rect2(0, -8.0 - i * lh - 6.0, w, 7), 2, shelf if i > 0 else post, 2.2, 0.3)
	for x: float in [0.0, w - 7.0]:
		Art.t_rect(ci, Rect2(x, -h - 8, 7, h + 8), 2, post, 2.2, 0.3)
		var y := -h + 4.0
		while y < -10.0:
			Art.disc(ci, Vector2(x + 3.5, y), 1.4, Art.shade_of(post, 0.45))
			y += 12.0


static func _rack_items(ci: CanvasItem, at: Vector2, w: float, h: float, lk: Dictionary, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x := at.x
	while x < at.x + w - 18.0:
		var kind := rng.randi() % 5
		var room := at.x + w - x
		match kind:
			0, 1:
				var bw := minf(rng.randf_range(24, 34), room)
				var bh := minf(rng.randf_range(18, 26), h)
				box(ci, Rect2(x, at.y - bh, bw, bh), Art.WOOD if kind == 0 else Color("d9b27a"))
				if kind == 0 and bh > 20 and bw > 26 and h > bh + 14.0 and rng.randf() < 0.5:
					box(ci, Rect2(x + 4, at.y - bh - 14, bw - 8, 14), Color("d9b27a"))
				x += bw + 4.0
			2:
				var r := minf(10.0, h * 0.4)
				if room < r * 2.0 + 4.0:
					break
				if is_temple(lk):
					_pot(ci, Vector2(x + r + 2, at.y), r)
				else:
					barrel(ci, Vector2(x + r + 2, at.y), r, lk["pipe"] if rng.randf() < 0.5 else Color("8e94a6"))
				x += r * 2.0 + 8.0
			3:
				if room < 26.0:
					break
				_world_thing(ci, Vector2(x + 12, at.y), lk, rng.randi() % 3)
				x += 30.0
			_:
				if room < 28.0:
					break
				if is_temple(lk):
					# A stack of chocolate bars.
					for k in 3:
						Art.t_rect(ci, Rect2(x + (k % 2) * 3, at.y - 7 - k * 6, 24, 6), 1.5, CHOC.lightened(k * 0.06), 1.6, 0.3)
					x += 32.0
					continue
				# Jars / cans in a row.
				for k in 3:
					Art.t_rect(ci, Rect2(x + k * 9, at.y - 14, 8, 14), 2, [Art.CORAL, Art.TEAL, Art.GOLD][(seed + k) % 3], 1.8, 0.3)
				x += 32.0


## A wooden or cardboard box.
static func box(ci: CanvasItem, r: Rect2, c: Color) -> void:
	Art.t_rect(ci, r, 2, c, 2.2, 0.4)
	if r.size.x > 16.0 and r.size.y > 12.0:
		Art.line_c(ci, PackedVector2Array([Vector2(r.position.x + 2, r.position.y + r.size.y * 0.5), Vector2(r.end.x - 2, r.position.y + r.size.y * 0.5)]), Art.shade_of(c, 0.3), 1.6)
		Art.flat(ci, _quad(Rect2(r.position.x + r.size.x * 0.4, r.position.y + 1, r.size.x * 0.2, r.size.y - 2)), Color(1, 1, 1, 0.18))


## A barrel standing on `base` (bottom center).
static func barrel(ci: CanvasItem, base: Vector2, r: float, c: Color) -> void:
	var body := Art.smooth_pts(PackedVector2Array([base + Vector2(-r, 0), base + Vector2(-r * 1.12, -r * 1.2), base + Vector2(-r, -r * 2.4),
			base + Vector2(r, -r * 2.4), base + Vector2(r * 1.12, -r * 1.2), base + Vector2(r, 0)]), 2)
	Art.toon(ci, body, c, 2.2, 0.6)
	for y: float in [0.45, 1.9]:
		Art.line_c(ci, PackedVector2Array([base + Vector2(-r * 1.05, -r * y), base + Vector2(r * 1.05, -r * y)]), Art.shade_of(c, 0.35), 2.0)
	Art.flat(ci, Art.ellipse_pts(base + Vector2(-r * 0.45, -r * 1.3), Vector2(r * 0.18, r * 0.6), 8), Color(1, 1, 1, 0.3))


## A clay pot with a turquoise band (the temple's barrel), base bottom center.
static func _pot(ci: CanvasItem, base: Vector2, r: float) -> void:
	var body := Art.smooth_pts(PackedVector2Array([base + Vector2(-r * 0.7, 0), base + Vector2(-r * 1.1, -r * 1.1), base + Vector2(-r * 0.6, -r * 2.0),
			base + Vector2(r * 0.6, -r * 2.0), base + Vector2(r * 1.1, -r * 1.1), base + Vector2(r * 0.7, 0)]), 2)
	Art.toon(ci, body, TERRACOTTA, 2.2, 0.6)
	Art.flat(ci, _quad(Rect2(base.x - r * 0.95, base.y - r * 1.35, r * 1.9, r * 0.3)), JADE)
	Art.t_rect(ci, Rect2(base.x - r * 0.55, base.y - r * 2.3, r * 1.1, r * 0.4), 1.5, Art.shade_of(TERRACOTTA, 0.1), 1.8, 0.0)


## Small world-themed shelf items: rope / fish box (ocean), hot rocks
## (volcano), flasks (acid), oxygen cans (moon).
static func _world_thing(ci: CanvasItem, base: Vector2, lk: Dictionary, k: int) -> void:
	match str(lk["style"]):
		"planks":
			if k == 0:
				Art.t_ellipse(ci, base + Vector2(0, -8), Vector2(12, 7), Color("d9b27a"), 2.2, 0.4)
				Art.ring(ci, Art.ellipse_pts(base + Vector2(0, -9), Vector2(7, 3.5), 12), Art.shade_of(Color("d9b27a"), 0.35), 1.6)
			else:
				Art.t_rect(ci, Rect2(base.x - 12, base.y - 14, 24, 14), 2, Color("3aa6f0"), 2.0, 0.3)
				Art.fish(ci, base + Vector2(0, -16), 8, Color("ff9a3c"), 1.0, 0.0)
		"plates":
			Art.t_rect(ci, Rect2(base.x - 11, base.y - 14, 22, 14), 3, Color("5a5f7a"), 2.0, 0.3)
			for j in 3:
				Art.t_circle(ci, base + Vector2(-6 + j * 6, -16 - (j % 2) * 3), 4, Color("ff7a2e"), 1.6, 0.3)
		"tiles":
			Art.t_rect(ci, Rect2(base.x - 3, base.y - 22, 6, 8), 1, Color("dff8ff"), 1.6, 0.0)
			Art.t_circle(ci, base + Vector2(0, -8), 8, Color("dff8ff"), 2.0, 0.0)
			Art.flat(ci, Art.clipped(_quad(Rect2(base.x - 9, base.y - 9, 18, 10)), Art.circle_pts(base + Vector2(0, -8), 7, 16)), [Color("7dff5a"), Color("ff6fa8"), Color("b06ae0")][k])
		"panels":
			for j in 2:
				Art.t_rect(ci, Rect2(base.x - 10 + j * 11, base.y - 22, 9, 22), 4, Art.WHITE if j == 0 else Color("5ad2ff"), 2.0, 0.4)
				Art.t_rect(ci, Rect2(base.x - 8 + j * 11, base.y - 25, 5, 4), 1, Art.METAL, 1.4, 0.0)
		"temple":
			match k:
				0:
					# A woven basket of cocoa pods.
					for j in 3:
						Art.t_ellipse(ci, base + Vector2(-6 + j * 6, -14 - (j % 2) * 3), Vector2(4.5, 6.5), Color("e0802e") if j != 1 else Color("c9602a"), 1.6, 0.3)
					Art.toon(ci, PackedVector2Array([base + Vector2(-12, -12), base + Vector2(12, -12), base + Vector2(9, 0), base + Vector2(-9, 0)]), Color("c9a050"), 2.0, 0.3)
					Art.line_c(ci, PackedVector2Array([base + Vector2(-10, -6), base + Vector2(10, -6)]), Color("8a6a2a"), 1.4)
				1:
					Art.push(ci, base)
					idol(ci, 1.3)
					Art.pop(ci)
				_:
					_pot(ci, base, 9.0)


## A control desk (origin bottom center, ~84 x 92): buttons, a screen and a
## lever; panel_live lights it up.
static func control_panel(ci: CanvasItem, lk: Dictionary) -> void:
	var c: Color = Art.shade_of(lk["col"], -0.1)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, 1), Vector2(40, 5), 16), Color(Art.SHADE, 0.2))
	Art.t_rect(ci, Rect2(-30, -46, 60, 46), 4, Art.shade_of(c, 0.1), 2.6, 0.4)
	Art.toon(ci, PackedVector2Array([Vector2(-38, -92), Vector2(38, -92), Vector2(42, -46), Vector2(-42, -46)]), c, 2.8, 0.5)
	Art.t_rect(ci, Rect2(-30, -86, 34, 24), 3, Color("1d2b3a"), 2.2, 0.0)
	Art.t_rect(ci, Rect2(10, -86, 22, 34), 3, Art.shade_of(c, 0.2), 2.0, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-20, -24), Vector2(20, -24)]), Art.shade_of(c, 0.35), 2.0)
	Art.t_rect(ci, Rect2(-10, -16, 20, 4), 1, Art.shade_of(c, 0.35), 0.0, 0.0)


## The panel's blinking buttons, screen wave and lever (`on` = the line runs).
static func panel_live(ci: CanvasItem, t: float, on: bool, lk: Dictionary) -> void:
	var cols := [Art.RED, Art.GREEN, Art.GOLD, Color("5ad2ff")]
	for i in 4:
		var lit := on and fposmod(t * 1.7 + i * 0.37, 1.0) < 0.55
		var c: Color = cols[i]
		Art.push(ci, Vector2(-30 + i * 10, -54))
		Art.t_circle(ci, Vector2.ZERO, 3.6, c if lit else Art.shade_of(c, 0.45), 1.6, 0.0)
		Art.pop(ci)
	# The screen: a running wave while on.
	var sc := Color(lk["accent"]).lerp(Art.GREEN, 0.5)
	if on:
		var ph := int(t * 8.0) % 8
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(Vector2(-27 + k * 3.5, -74 + sin((k + ph) * 0.9) * 5.0))
		Art.polyline(ci, pts, sc, 2.0)
	else:
		Art.line_c(ci, PackedVector2Array([Vector2(-27, -74), Vector2(1, -74)]), Art.shade_of(sc, 0.5), 2.0)
	# Lever.
	Art.push(ci, Vector2(21, -58), -0.5 if on else 0.4)
	Art.t_rect(ci, Rect2(-2, -22, 4, 22), 1, Art.METAL, 1.6, 0.0)
	Art.t_circle(ci, Vector2(0, -22), 5, Art.RED, 1.8, 0.4)
	Art.pop(ci)


## Round gauge (origin center, radius r): face only; gauge_needle on top.
static func gauge(ci: CanvasItem, r: float, lk: Dictionary) -> void:
	Art.t_circle(ci, Vector2.ZERO, r, Art.shade_of(lk["col"], -0.2), 2.6, 0.3)
	Art.t_circle(ci, Vector2.ZERO, r * 0.78, Art.CREAM, 1.8, 0.0)
	Art.arc_c(ci, Vector2.ZERO, r * 0.6, PI * 0.75, PI * 1.6, 10, Art.GREEN, r * 0.16)
	Art.arc_c(ci, Vector2.ZERO, r * 0.6, PI * 1.6, PI * 2.0, 6, Art.GOLD, r * 0.16)
	Art.arc_c(ci, Vector2.ZERO, r * 0.6, PI * 2.0, PI * 2.25, 4, Art.RED, r * 0.16)


## The needle at `v` 0..1 (left to right).
static func gauge_needle(ci: CanvasItem, r: float, v: float) -> void:
	var a := lerpf(PI * 0.75, PI * 2.25, clampf(v, 0.0, 1.0))
	Art.push(ci, Vector2.ZERO, snappedf(a, 0.05), Vector2.ONE * (r / 12.0))
	Art.toon(ci, PackedVector2Array([Vector2(0, -1.6), Vector2(8.5, 0), Vector2(0, 1.6)]), Art.RED, 0.0, 0.0)
	Art.pop(ci)
	Art.disc(ci, Vector2.ZERO, maxf(1.5, r * 0.14), Art.INK)


## A wall fan (origin center, radius r): the frame; fan_blades spin in it.
static func fan(ci: CanvasItem, r: float, lk: Dictionary) -> void:
	Art.t_rect(ci, Rect2(-r - 6, -r - 6, r * 2.0 + 12, r * 2.0 + 12), 6, Art.shade_of(lk["col"], -0.1), 2.6, 0.4)
	Art.t_circle(ci, Vector2.ZERO, r, Color("2a2440"), 2.2, 0.0)


static func fan_blades(ci: CanvasItem, r: float, rot: float, lk: Dictionary) -> void:
	Art.push(ci, Vector2.ZERO, snappedf(rot, 0.05), Vector2.ONE * (r / 20.0))
	for k in 3:
		Art.push(ci, Vector2.ZERO, k * TAU / 3.0)
		Art.toon(ci, PackedVector2Array([Vector2(0, -2), Vector2(17, -6.5), Vector2(17, 3.5), Vector2(0, 3)]), Art.shade_of(lk["col"], -0.35), 1.6, 0.3)
		Art.pop(ci)
	Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, r * 0.2, Art.METAL, 1.8, 0.0)


static func fan_grill(ci: CanvasItem, r: float) -> void:
	for k in 4:
		var y := -r * 0.6 + k * r * 0.4
		var hw := sqrt(maxf(0.0, r * r - y * y))
		Art.line_c(ci, PackedVector2Array([Vector2(-hw, y), Vector2(hw, y)]), Color(1, 1, 1, 0.3), 1.5)


## A red fire extinguisher on its wall bracket (origin bottom center).
static func extinguisher(ci: CanvasItem) -> void:
	Art.t_rect(ci, Rect2(-12, -46, 24, 6), 2, Art.METAL, 1.8, 0.0)
	Art.t_rect(ci, Rect2(-8, -44, 16, 44), 7, Art.RED, 2.4, 0.5)
	Art.t_rect(ci, Rect2(-5, -52, 10, 8), 2, Art.INK_SOFT, 1.8, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(4, -50), Vector2(12, -46), Vector2(12, -30)]), Art.INK_SOFT, 2.5, 1.2)
	Art.t_rect(ci, Rect2(-6, -30, 12, 10), 2, Art.WHITE, 1.4, 0.0)


## A wall sign with a pictogram (no words): "helmet" (wear a hard hat),
## "coins" (production up), "up" (an arrow to the office), "hot".
static func sign_board(ci: CanvasItem, kind: String, lk: Dictionary) -> void:
	match kind:
		"helmet":
			if is_temple(lk):
				# An explorer's pith helmet on a wooden board.
				Art.t_rect(ci, Rect2(-26, -26, 52, 52), 8, Color("3f9a5a"), 2.6, 0.3)
				Art.ring(ci, Art.rrect_pts(Rect2(-21, -21, 42, 42), 6), Color("ffe9b0"), 2.0)
				Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, 4), Vector2(-12, -10), Vector2(0, -16), Vector2(12, -10), Vector2(14, 4)]), 3), Color("ead7a2"), 2.2, 0.4)
				Art.t_ellipse(ci, Vector2(0, 6), Vector2(20, 5), Color("d9c48a"), 2.0, 0.2)
				Art.flat(ci, _quad(Rect2(-13, -2, 26, 4)), Color("8a6a3a"))
				return
			Art.t_rect(ci, Rect2(-26, -26, 52, 52), 8, Color("3aa6f0"), 2.6, 0.3)
			Art.ring(ci, Art.rrect_pts(Rect2(-21, -21, 42, 42), 6), Art.WHITE, 2.0)
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-16, 6), Vector2(-14, -8), Vector2(0, -14), Vector2(14, -8), Vector2(16, 6)]), 3), Art.GOLD, 2.2, 0.4)
			Art.t_rect(ci, Rect2(-19, 4, 38, 6), 2, Art.GOLD, 2.0, 0.2)
		"coins":
			Art.t_rect(ci, Rect2(-26, -26, 52, 52), 8, Art.GREEN, 2.6, 0.3)
			Art.coin(ci, Vector2(-6, 6), 11)
			Art.push(ci, Vector2(11, -6))
			Art.toon(ci, Art.arrow_pts(9), Art.WHITE, 2.0, 0.0)
			Art.pop(ci)
		"up":
			Art.t_rect(ci, Rect2(-22, -22, 44, 44), 8, lk["haz"], 2.6, 0.3)
			Art.push(ci, Vector2(0, 2))
			Art.toon(ci, Art.arrow_pts(14), Art.INK, 0.0, 0.0)
			Art.pop(ci)
		"hot":
			Art.toon(ci, PackedVector2Array([Vector2(0, -30), Vector2(30, 24), Vector2(-30, 24)]), Art.GOLD, 3.0, 0.3)
			Art.toon(ci, PackedVector2Array([Vector2(-8, 16), Vector2(-4, 2), Vector2(0, 8), Vector2(3, -8), Vector2(8, 16)]), Color("ff6a1f"), 2.0, 0.0)


## A string of little flags from x0 to x1 hanging from y (sagging `sag`).
static func pennants(ci: CanvasItem, x0: float, x1: float, y: float, sag: float, lk: Dictionary = {}) -> void:
	if is_temple(lk):
		garland(ci, x0, x1, y, sag)
		return
	var n := maxi(3, int((x1 - x0) / 26.0))
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, u), y + sin(u * PI) * sag))
	Art.polyline(ci, pts, Art.INK, 2.0)
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var m := (a + b) / 2.0
		Art.toon(ci, PackedVector2Array([a + (b - a) * 0.12, b - (b - a) * 0.12, m + Vector2(0, 16)]), PENNANTS[i % PENNANTS.size()], 1.8, 0.3)


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
			sign_board(ci, "hot", lk)
		"tiles":
			Art.t_rect(ci, Rect2(-34, -34, 68, 68), 10, Art.WHITE, 3.0, 0.3)
			var fl := PackedVector2Array([Vector2(-6, -24), Vector2(6, -24), Vector2(6, -8), Vector2(20, 18), Vector2(-20, 18), Vector2(-6, -8)])
			Art.toon(ci, fl, Color("e8fff0"), 2.6, 0.0)
			Art.flat(ci, Art.clipped(_quad(Rect2(-22, 4, 44, 16)), fl), Color("7dff5a"))
			Art.ring(ci, fl, Art.INK, 2.6)
			Art.disc(ci, Vector2(-4, 10), 3, Art.WHITE)
		"temple":
			# A golden sun mask on a carved stone plaque.
			Art.t_rect(ci, Rect2(-38, -38, 76, 76), 6, Color("c9a668"), 3.0, 0.4)
			Art.ring(ci, Art.rrect_pts(Rect2(-31, -31, 62, 62), 4), Art.shade_of(Color("c9a668"), 0.3), 2.4)
			for k in 12:
				var a := k * TAU / 12.0
				Art.toon(ci, PackedVector2Array([Vector2.from_angle(a - 0.16) * 18, Vector2.from_angle(a) * 29, Vector2.from_angle(a + 0.16) * 18]),
						Art.GOLD if k % 2 == 0 else Color("ffe38a"), 2.0, 0.0)
			Art.t_circle(ci, Vector2.ZERO, 19, Art.GOLD, 2.6, 0.5)
			for sx: float in [-7.0, 7.0]:
				Art.t_ellipse(ci, Vector2(sx, -4), Vector2(4, 3), Art.WHITE, 1.6, 0.0)
				Art.disc(ci, Vector2(sx, -3.5), 1.8, Art.INK)
			Art.arc_c(ci, Vector2(0, 3), 7, 0.3, PI - 0.3, 8, Art.INK, 2.2)
			for sx: float in [-13.0, 13.0]:
				Art.disc(ci, Vector2(sx, 4), 2.6, JADE)
		"panels":
			Art.t_rect(ci, Rect2(-30, -40, 60, 80), 8, Color("1d2350"), 3.0, 0.2)
			Art.toon(ci, PackedVector2Array([Vector2(0, -30), Vector2(10, -12), Vector2(10, 14), Vector2(-10, 14), Vector2(-10, -12)]), Art.WHITE, 2.4, 0.4)
			Art.toon(ci, PackedVector2Array([Vector2(-10, 4), Vector2(-18, 18), Vector2(-10, 14)]), Art.RED, 2.0, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(10, 4), Vector2(18, 18), Vector2(10, 14)]), Art.RED, 2.0, 0.0)
			Art.t_circle(ci, Vector2(0, -6), 4, Color("5ad2ff"), 1.8, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-6, 16), Vector2(6, 16), Vector2(0, 30)]), Color("ffb13b"), 1.8, 0.0)
			for p: Vector2 in [Vector2(-20, -30), Vector2(20, -20), Vector2(-18, 28), Vector2(21, 30)]:
				Art.disc(ci, p, 1.8, Art.WHITE)


## A round wall clock face; clock_hands tick on it.
static func clock(ci: CanvasItem, lk: Dictionary) -> void:
	if is_temple(lk):
		# A carved stone calendar with a turquoise ring.
		Art.t_circle(ci, Vector2.ZERO, 25, Color("d8bc80"), 3.0, 0.4)
		Art.ring(ci, Art.circle_pts(Vector2.ZERO, 20, 24), Art.shade_of(Color("d8bc80"), 0.35), 2.0)
		Art.t_circle(ci, Vector2.ZERO, 16, Art.CREAM, 2.0, 0.0)
		Art.ring(ci, Art.circle_pts(Vector2.ZERO, 16, 24), JADE, 2.4)
		for k in 12:
			var d := Vector2(0, -22.5).rotated(k * TAU / 12.0)
			Art.disc(ci, d, 1.6, Art.shade_of(Color("d8bc80"), 0.45))
			if k % 3 == 0:
				Art.disc(ci, d * 0.58, 1.8, Art.INK_SOFT)
		return
	Art.t_circle(ci, Vector2.ZERO, 22, lk["beam"], 3.0, 0.3)
	Art.t_circle(ci, Vector2.ZERO, 17, Art.CREAM, 2.0, 0.0)
	for k in 12:
		Art.disc(ci, Vector2(0, -14).rotated(k * TAU / 12.0), 1.4 if k % 3 else 2.0, Art.INK_SOFT)


static func clock_hands(ci: CanvasItem, t: float) -> void:
	Art.push(ci, Vector2.ZERO, snappedf(1.3 + t * 0.02, TAU / 60.0))
	Art.t_rect(ci, Rect2(-1.5, -10, 3, 11), 1.5, Art.INK, 0.0, 0.0)
	Art.pop(ci)
	Art.push(ci, Vector2.ZERO, snappedf(t * TAU / 60.0, TAU / 60.0))
	Art.t_rect(ci, Rect2(-1, -14, 2, 16), 1, Art.RED, 0.0, 0.0)
	Art.pop(ci)
	Art.disc(ci, Vector2.ZERO, 2.5, Art.RED)


## A neon sign (stage 13+): a big coin and a star in glowing tubes.
static func neon(ci: CanvasItem, lk: Dictionary) -> void:
	var c: Color = lk["accent"]
	if is_temple(lk):
		# A glowing sun stone: a dark slab with jade and gold rings that shine.
		Art.t_rect(ci, Rect2(-56, -32, 112, 64), 8, Color("3a3a2a"), 3.0, 0.2)
		Props.halo(ci, Vector2(-20, 0), 42, Color(Art.GOLD, 0.35))
		Props.halo(ci, Vector2(28, 0), 32, Color(c, 0.35))
		Art.arc_c(ci, Vector2(-20, 0), 17, 0, TAU, 24, Color(Art.GOLD, 0.45), 8.0)
		Art.arc_c(ci, Vector2(-20, 0), 17, 0, TAU, 24, Color("fff1a8"), 3.0)
		for k in 8:
			var d := Vector2.from_angle(k * TAU / 8.0)
			Art.line_c(ci, PackedVector2Array([Vector2(-20, 0) + d * 20, Vector2(-20, 0) + d * 26]), Color("fff1a8"), 2.5)
		Art.disc(ci, Vector2(-20, 0), 5, Color("fff1a8"))
		var st := PackedVector2Array([Vector2(28, -16), Vector2(42, 0), Vector2(28, 16), Vector2(14, 0)])
		Art.polyline(ci, st, Color(c, 0.45), 8.0, true)
		Art.polyline(ci, st, c.lightened(0.6), 3.0, true)
		Art.disc(ci, Vector2(28, 0), 3.5, c.lightened(0.6))
		return
	Art.t_rect(ci, Rect2(-56, -30, 112, 60), 10, Color("231a3d"), 3.0, 0.2)
	Props.halo(ci, Vector2(-18, 0), 40, Color(Art.GOLD, 0.3))
	Props.halo(ci, Vector2(26, 0), 34, Color(c, 0.3))
	Art.arc_c(ci, Vector2(-18, 0), 15, 0, TAU, 24, Color(Art.GOLD, 0.45), 8.0)
	Art.arc_c(ci, Vector2(-18, 0), 15, 0, TAU, 24, Color("fff1a8"), 3.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-18, -8), Vector2(-18, 8)]), Color("fff1a8"), 3.0)
	var st := Art.star_pts(Vector2(26, 0), 17, 7.5, 5)
	Art.polyline(ci, st, Color(c, 0.45), 8.0, true)
	Art.polyline(ci, st, c.lightened(0.6), 3.0, true)


## A wooden crate with ore peeking out; origin at its bottom center.
static func crate(ci: CanvasItem, s: float, gem: Color) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(s, s))
	Art.crystal(ci, Vector2(-6, -26), 12, 5, -0.3, gem, 1.8)
	Art.crystal(ci, Vector2(5, -26), 14, 5, 0.25, gem.lightened(0.25), 1.8)
	Art.t_rect(ci, Rect2(-17, -28, 34, 28), 3, Art.WOOD, 2.4, 0.5)
	Art.line_c(ci, PackedVector2Array([Vector2(-15, -14), Vector2(15, -14)]), Art.WOOD_DARK, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-13, -26), Vector2(13, -2)]), Art.WOOD_DARK, 2.0)
	Art.pop(ci)


## A pile of `n` (0..8) crates waiting by the door (origin bottom-left).
static func crate_stack(ci: CanvasItem, n: int, gems: Array) -> void:
	var spots := [Vector2(18, 0), Vector2(54, 0), Vector2(36, -28), Vector2(90, 0), Vector2(72, -28), Vector2(54, -56), Vector2(126, 0), Vector2(108, -28)]
	for i in mini(n, spots.size()):
		Art.push(ci, spots[i])
		crate(ci, 1.0, gems[i % gems.size()])
		Art.pop(ci)


## A pallet jack parked on the floor (origin bottom-left).
static func pallet_jack(ci: CanvasItem, lk: Dictionary) -> void:
	Art.t_rect(ci, Rect2(0, -10, 60, 7), 2, lk["haz"], 2.2, 0.3)
	Art.t_circle(ci, Vector2(8, -3), 4, Art.INK_SOFT, 1.6, 0.0)
	Art.t_circle(ci, Vector2(52, -3), 4, Art.INK_SOFT, 1.6, 0.0)
	Art.stroke(ci, PackedVector2Array([Vector2(58, -10), Vector2(66, -44)]), Art.shade_of(lk["col"], 0.1), 4.0, 2.0)
	Art.stroke(ci, PackedVector2Array([Vector2(60, -46), Vector2(72, -42)]), Art.INK_SOFT, 5.0, 1.8)


# --- Dock door -------------------------------------------------------------------------

## The dock door: origin on the floor at its left post, DOOR_W wide.
const DOOR_W := 96.0
const DOOR_H := 150.0


## The frame and the quay outside (static).
static func dock_door_back(ci: CanvasItem, lk: Dictionary) -> void:
	var r := Rect2(8, -DOOR_H, DOOR_W - 16, DOOR_H)
	Art.t_rect(ci, Rect2(-6, -DOOR_H - 26, DOOR_W + 12, DOOR_H + 26), 6, Art.shade_of(lk["beam"], 0.1), 3.0, 0.4)
	scene(ci, Rect2(r.position, Vector2(r.size.x, r.size.y - 26)), lk)
	Art.flat(ci, _quad(Rect2(r.position.x, -28, r.size.x, 28)), Art.shade_of(lk["floor"], 0.2))
	Art.flat(ci, _quad(Rect2(r.position.x, -28, r.size.x, 4)), Art.shade_of(lk["floor"], 0.4))
	# Bollard on the quay.
	Art.t_rect(ci, Rect2(r.position.x + 10, -40, 10, 14), 4, Art.INK_SOFT, 1.8, 0.2)


## The shutter, posts and beacon. `open` 0..1 rolls the shutter up; `lamp`
## 0..1 lights the beacon; `boat` 0..1 brings a boat to the quay outside.
static func dock_door(ci: CanvasItem, open: float, lamp: float, lk: Dictionary, boat: float = 0.0) -> void:
	var r := Rect2(8, -DOOR_H, DOOR_W - 16, DOOR_H)
	var temple := is_temple(lk)
	if boat > 0.01:
		# The boat slides in to the quay (only its part inside the opening).
		var bx := lerpf(r.end.x + 30.0, r.get_center().x + 6.0, Props._q(boat, 24))
		var hull := Art.clipped(Art.moved(PackedVector2Array([Vector2(-34, -16), Vector2(-20, -12), Vector2(20, -12), Vector2(34, -16), Vector2(26, 2), Vector2(-26, 2)]
				if temple else [Vector2(-30, -12), Vector2(30, -12), Vector2(24, 2), Vector2(-24, 2)]), Vector2(bx, -30)), _quad(r))
		var cab := Art.clipped(_quad(Rect2(bx - 14, -56, 22, 14)), _quad(r))
		if temple:
			cab = Art.clipped(PackedVector2Array([Vector2(bx - 18, -56), Vector2(bx + 10, -56), Vector2(bx + 14, -48), Vector2(bx - 22, -48)]), _quad(r))
		if not cab.is_empty():
			Art.toon(ci, cab, Color("e9b95a") if temple else Art.WHITE, 2.0, 0.3)
		if not hull.is_empty():
			Art.toon(ci, hull, Color("b8743a") if temple else Art.CORAL, 2.2, 0.4)
	# The shutter, in slats, rolled up by `open`.
	var sh := DOOR_H * (1.0 - clampf(open, 0.0, 0.82))
	var n := int(ceil(sh / 14.0))
	for i in n:
		var y := -DOOR_H + sh - (i + 1) * 14.0
		if y < -DOOR_H:
			break
		Art.push(ci, Vector2(8, snappedf(y, 0.5)))
		if temple:
			Art.t_rect(ci, Rect2(0, 0, DOOR_W - 16, 14), 6, BAMBOO if i % 2 == 0 else Color("c8b456"), 2.0, 0.3)
			Art.line_c(ci, PackedVector2Array([Vector2(26 + (i % 2) * 14, 2), Vector2(26 + (i % 2) * 14, 12)]), BAMBOO_DARK, 1.6)
		else:
			Art.t_rect(ci, Rect2(0, 0, DOOR_W - 16, 14), 2, Color("c9d2e2") if i % 2 == 0 else Color("b7c1d4"), 2.0, 0.2)
		Art.pop(ci)
	if temple:
		# A carved stone lintel and posts with gold bands, a lantern over it.
		Art.t_rect(ci, Rect2(-2, -DOOR_H - 20, DOOR_W + 4, 18), 3, Color("d8bc80"), 2.6, 0.4)
		for gx in 4:
			Art.disc(ci, Vector2(15 + gx * 22, -DOOR_H - 11), 3.0, JADE if gx % 2 == 0 else Art.GOLD)
		for x: float in [0.0, DOOR_W - 8.0]:
			Art.t_rect(ci, Rect2(x - 2, -DOOR_H, 12, DOOR_H), 2, Color("d8bc80"), 2.2, 0.3)
			for j in 3:
				Art.flat(ci, _quad(Rect2(x - 1, -DOOR_H + 20 + j * 48, 10, 6)), Art.GOLD)
		var lc := Vector2(DOOR_W / 2.0, -DOOR_H - 34)
		var lq2 := Props._q(lamp, 8)
		Art.line_c(ci, PackedVector2Array([lc + Vector2(0, -14), lc + Vector2(0, -6)]), Art.INK, 2.0)
		Props.halo(ci, lc, 22 + 14 * lq2, Color(1.0, 0.75, 0.3, 0.35 + 0.3 * lq2))
		Art.t_circle(ci, lc, 8, Color("c98a4a"), 2.2, 0.4)
		Art.t_circle(ci, lc, 4, Color("fff3c4").lerp(Color("ffe38a"), lq2), 0.0, 0.0)
		return
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
	var lq := Props._q(lamp, 8)
	Art.t_circle(ci, bc, 9, Art.GOLD.lerp(Color("ffef9a"), lq), 2.4, 0.5)
	if lq > 0.02:
		Props.halo(ci, bc, 34, Color(1.0, 0.8, 0.3, 0.55 * lq))


## A conveyor belt from `a` (left end, on the floor) `len` long whose top is
## at `h` above the floor: the frame. belt_live moves its slats.
static func belt_frame(ci: CanvasItem, a: Vector2, len: float, h: float, lk: Dictionary) -> void:
	var legs := maxi(2, int(len / 60.0) + 1)
	for i in legs:
		var x := a.x + 10.0 + (len - 20.0) * i / float(legs - 1)
		Art.t_rect(ci, Rect2(x - 3, a.y - h + 8, 6, h - 8), 1, Art.shade_of(lk["col"], 0.1), 1.8, 0.0)
	Art.t_rect(ci, Rect2(a.x, a.y - h - 2, len, 12), 6, Color("6a4a2a") if is_temple(lk) else Color("3a3f5c"), 2.6, 0.2)
	Art.t_circle(ci, Vector2(a.x + 6, a.y - h + 4), 4, Art.METAL, 1.6, 0.0)
	Art.t_circle(ci, Vector2(a.x + len - 6, a.y - h + 4), 4, Art.METAL, 1.6, 0.0)


static func belt_live(ci: CanvasItem, a: Vector2, len: float, h: float, t: float, running: bool) -> void:
	var step := 12.0
	var off := snappedf(fposmod(t * 30.0, step), 0.5) if running else 0.0
	var x0 := a.x + 12.0 + off
	while x0 < a.x + len - 10.0:
		Art.push(ci, Vector2(x0, a.y - h + 1))
		Art.flat(ci, Art.rrect_pts(Rect2(-1.5, -2.5, 3, 5), 1), Color("8d94a6"))
		Art.pop(ci)
		x0 += step


# --- The machine line ------------------------------------------------------------------

## The parts of a line that stand still (drawn once). `variant` 1 = the
## second line (other paint).
static func line_back(ci: CanvasItem, stage: int, variant: int, lk: Dictionary) -> void:
	var s := clampi(stage, 1, STAGES)
	var temple := is_temple(lk)
	var m := _mat(s, variant, temple)
	var tier := tier_of(s)
	var ex := extras_of(s)
	var n := machines_at(s)
	# Overhead pipes behind the machines, with a gauge (needle in line_live).
	if ex >= 2:
		Art.stroke(ci, PackedVector2Array([Vector2(10, -150), Vector2(LINE_W - 10, -150)]), m["trim"], 9.0, 2.4)
		for x: float in SLOTS:
			Art.stroke(ci, PackedVector2Array([Vector2(x + 22, -150), Vector2(x + 22, -112)]), m["trim"], 6.0, 2.0)
		Art.push(ci, Vector2(200, -150))
		gauge(ci, 12, lk)
		Art.pop(ci)
	# A sign over the line, with a star per tier.
	if ex >= 3:
		var sc := Vector2(LINE_W / 2.0, -172)
		for x: float in [-60.0, 60.0]:
			Art.line_c(ci, PackedVector2Array([sc + Vector2(x, -18), sc + Vector2(x, -36)]), Art.INK, 2.0)
		Art.t_rect(ci, Rect2(sc.x - 74, sc.y - 18, 148, 30), 10, m["dark"], 3.0, 0.4)
		for i in tier:
			var c := sc + Vector2((i - (tier - 1) / 2.0) * 26.0, -3)
			Art.toon(ci, Art.star_pts(c, 10, 4.5, 5), Art.GOLD, 2.0, 0.3)
	# Shadows under the machines, and from tier 2 a raised steel platform.
	for i in n:
		Art.flat(ci, Art.ellipse_pts(Vector2(SLOTS[i], 2), Vector2(44, 6), 18), Color(Art.SHADE, 0.22))
	if tier >= 2:
		Art.t_rect(ci, Rect2(-6, -6, SLOTS[n - 1] + 52, 10), 3, m["dark"], 2.4, 0.3)
		var x := 4.0
		while x < SLOTS[n - 1] + 40.0:
			Art.flat(ci, PackedVector2Array([Vector2(x, -4), Vector2(x + 8, -4), Vector2(x + 4, 2), Vector2(x - 4, 2)]), Color(Art.GOLD, 0.8))
			x += 18.0
	# Belts between the machines.
	for i in n - 1:
		belt_frame(ci, Vector2(SLOTS[i] + 30, 0), SLOTS[i + 1] - SLOTS[i] - 60, 22, lk)
	for i in 4:
		var x: float = SLOTS[i]
		Art.push(ci, Vector2(x, 0))
		if i < n:
			match i:
				0: _crusher_back(ci, tier, m)
				1: _furnace_back(ci, tier, m, temple)
				2: _polisher_back(ci, tier, m)
				3: _press_back(ci, tier, m)
			if temple:
				_temple_carve(ci, i, tier, m)
			if ex >= 1:
				Art.t_rect(ci, Rect2(-7, _top(i) - 8, 14, 6), 2, m["dark"], 2.0, 0.0)
		else:
			_spot(ci)
		Art.pop(ci)
	if n < 4:
		# Until the press stands the last machine's output goes in a cart.
		Art.push(ci, Vector2(SLOTS[n - 1] + 44, 0))
		Art.t_rect(ci, Rect2(-10, -26, 30, 18), 3, m["dark"], 2.4, 0.3)
		Art.t_circle(ci, Vector2(-4, -6), 5, Art.INK_SOFT, 2.0, 0.0)
		Art.t_circle(ci, Vector2(14, -6), 5, Art.INK_SOFT, 2.0, 0.0)
		Art.coin(ci, Vector2(5, -28), 6)
		Art.pop(ci)
	if variant > 0:
		Props.second_badge(ci, Vector2(SLOTS[0] - 30, -96), 11.0)


## The moving parts. o: "t", "working" (bool), "gear" (rotation), "press"
## (0..1 piston down), "flash" (0..1 after a payout), "flame", "variant".
static func line_live(ci: CanvasItem, stage: int, o: Dictionary) -> void:
	var s := clampi(stage, 1, STAGES)
	var temple := str(o.get("style", "")) == "temple"
	var m := _mat(s, int(o.get("variant", 0)), temple)
	var tier := tier_of(s)
	var ex := extras_of(s)
	var n := machines_at(s)
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	if ex >= 2:
		Art.push(ci, Vector2(200, -150))
		gauge_needle(ci, 12, (0.62 + 0.12 * sin(t * 2.3)) if working else 0.08)
		Art.pop(ci)
	for i in n - 1:
		belt_live(ci, Vector2(SLOTS[i] + 30, 0), SLOTS[i + 1] - SLOTS[i] - 60, 22, t + i * 0.2, working)
	for i in n:
		Art.push(ci, Vector2(SLOTS[i], 0))
		match i:
			0: _crusher_live(ci, tier, m, o)
			1: _furnace_live(ci, tier, m, o)
			2: _polisher_live(ci, tier, m, o)
			3: _press_live(ci, tier, m, o)
		if ex >= 1:
			_beacon(ci, Vector2(0, _top(i) - 6), working, t + i, m)
		Art.pop(ci)
	# Goods riding the belts.
	if working:
		for i in n - 1:
			var a := SLOTS[i] + 30.0
			var len := SLOTS[i + 1] - SLOTS[i] - 60.0
			for k in 2:
				var f := fposmod(t * 0.9 + i * 0.37 + k * 0.5, 1.0)
				Art.push(ci, Vector2(snappedf(a + 8.0 + (len - 16.0) * f, 0.5), -24))
				if temple:
					_temple_good(ci, i)
				else:
					_good(ci, i)
				Art.pop(ci)


## Tops of the machines (local y), for beacons.
static func _top(i: int) -> float:
	return [-112.0, -138.0, -98.0, -134.0][i]


## The thing a belt carries after machine i: chunks, glowing ingots, shiny bars.
static func _good(ci: CanvasItem, i: int) -> void:
	match i:
		0:
			Art.toon(ci, PackedVector2Array([Vector2(-6, 0), Vector2(-4, -8), Vector2(3, -10), Vector2(7, -3), Vector2(5, 0)]), Color("b08a6a"), 1.8, 0.4)
		1:
			Art.t_rect(ci, Rect2(-8, -8, 16, 8), 2, Color("ff8a3c"), 1.8, 0.4)
			Art.flat(ci, Art.rrect_pts(Rect2(-6, -7, 12, 3), 1), Color("ffd23f"))
		_:
			Art.t_rect(ci, Rect2(-8, -8, 16, 8), 2, Art.GOLD, 1.8, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(-5, -7, 4, 2), 1), Color(1, 1, 1, 0.8))


## Empty spot for a machine still to come: taped square, a dashed outline
## and a "+".
static func _spot(ci: CanvasItem) -> void:
	Art.flat(ci, Art.rrect_pts(Rect2(-34, -10, 68, 10), 3), Color(0, 0, 0, 0.12))
	for j in 5:
		Art.flat(ci, Art.rrect_pts(Rect2(-34 + j * 14, -3, 8, 3), 1), Art.GOLD)
	var y := -90.0
	while y < -14.0:
		Art.flat(ci, Art.rrect_pts(Rect2(-32, y, 3, 8), 1), Color(1, 1, 1, 0.5))
		Art.flat(ci, Art.rrect_pts(Rect2(29, y, 3, 8), 1), Color(1, 1, 1, 0.5))
		y += 14.0
	var x := -30.0
	while x < 30.0:
		Art.flat(ci, Art.rrect_pts(Rect2(x, -92, 8, 3), 1), Color(1, 1, 1, 0.5))
		x += 14.0
	Art.t_circle(ci, Vector2(0, -50), 15, Color(1, 1, 1, 0.75), 2.4, 0.0)
	Art.flat(ci, Art.rrect_pts(Rect2(-8, -52, 16, 4), 1.5), Art.INK_SOFT)
	Art.flat(ci, Art.rrect_pts(Rect2(-2, -58, 4, 16), 1.5), Art.INK_SOFT)


static func _beacon(ci: CanvasItem, at: Vector2, on: bool, t: float, m: Dictionary) -> void:
	var lit := Props._q((0.5 + 0.5 * sin(t * 6.0)) if on else 0.0, 4)
	Art.push(ci, at + Vector2(0, -7))
	Art.t_circle(ci, Vector2.ZERO, 6, Art.CORAL.lerp(Color("ffe38a"), lit), 2.0, 0.3)
	Art.pop(ci)
	if lit > 0.1:
		Props.halo(ci, at + Vector2(0, -7), 20, Color(Color(m["light"]), 0.45 * lit))


static func _legs(ci: CanvasItem, hw: float, h: float, m: Dictionary) -> void:
	for x: float in [-hw, hw]:
		Art.t_rect(ci, Rect2(x - 4, -h, 8, h), 2, m["dark"], 2.2, 0.0)
	Art.t_rect(ci, Rect2(-hw - 8, -4, hw * 2.0 + 16, 4), 1, m["dark"], 1.8, 0.0)


static func _rivets(ci: CanvasItem, r: Rect2) -> void:
	for c: Vector2 in [r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6), r.end - Vector2(6, 6), Vector2(r.position.x + 6, r.end.y - 6)]:
		Art.disc(ci, c, 2.2, Color(0, 0, 0, 0.3))


## 1. Crusher: hopper on top with chomping jaws, two gear rollers behind a
## round window.
static func _crusher_back(ci: CanvasItem, tier: int, m: Dictionary) -> void:
	_legs(ci, 22, 22, m)
	var body := Rect2(-34, -76, 68, 56)
	Art.t_rect(ci, body, 8, m["body"], 3.0, 0.6)
	if tier == 0:
		for y: float in [-62.0, -46.0, -32.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(-32, y), Vector2(32, y)]), Art.WOOD_DARK, 2.0)
	else:
		_rivets(ci, body)
	Art.toon(ci, PackedVector2Array([Vector2(-40, -110), Vector2(40, -110), Vector2(22, -76), Vector2(-22, -76)]), m["trim"], 3.0, 0.5)
	Art.flat(ci, PackedVector2Array([Vector2(-32, -106), Vector2(32, -106), Vector2(26, -97), Vector2(-26, -97)]), Color(0, 0, 0, 0.45))
	# Hazard band on the hopper.
	for k in 4:
		Art.flat(ci, PackedVector2Array([Vector2(-26 + k * 14, -90), Vector2(-20 + k * 14, -90), Vector2(-24 + k * 14, -82), Vector2(-30 + k * 14, -82)]), Color(Art.INK, 0.4))
	Art.t_circle(ci, Vector2(0, -48), 20, Color("2a2440"), 2.6, 0.0)
	if tier >= 4:
		Art.crystal(ci, Vector2(28, -110), 18, 6, 0.3, Color("b78cff"), 2.0)
	elif tier >= 3:
		Art.flat(ci, Art.rrect_pts(Rect2(-30, -26, 60, 4), 2), m["trim"])


static func _crusher_live(ci: CanvasItem, _tier: int, m: Dictionary, o: Dictionary) -> void:
	var gr: float = snappedf(o.get("gear", 0.0), 0.05)
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	Art.gear(ci, Vector2(-8, -48), 10, m["trim"], gr, 7)
	Art.gear(ci, Vector2(9, -48), 10, m["trim"], -gr + 0.3, 7)
	# Rock bits tumbling between the rollers.
	if working:
		for k in 3:
			var f := Props._q(fposmod(t * 1.6 + k * 0.33, 1.0), 20)
			Art.push(ci, Vector2(-6 + k * 6, -64 + f * 30), f * 6.0)
			Art.toon(ci, PackedVector2Array([Vector2(-3, 0), Vector2(-1, -4), Vector2(3, -3), Vector2(3, 1)]), Color("b08a6a"), 1.4, 0.0)
			Art.pop(ci)
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -58), Vector2(6, 3), 10, -0.5), Color(1, 1, 1, 0.3))
	# The toothed jaws in the hopper's mouth chomp.
	var bite := Props._q(absf(sin(t * 5.0)), 6) * 8.0 if working else 3.0
	for side: float in [-1.0, 1.0]:
		Art.push(ci, Vector2(side * (22.0 - bite), -101), 0.0, Vector2(side, 1.0))
		Art.toon(ci, PackedVector2Array([Vector2(-10, -5), Vector2(4, -5), Vector2(10, -2), Vector2(4, 0), Vector2(10, 3), Vector2(4, 5), Vector2(-10, 5)]), Art.METAL, 2.0, 0.3)
		Art.pop(ci)
	if working:
		# Dust puffs over the hopper.
		for k in 2:
			var f := fposmod(t * 0.8 + k * 0.5, 1.0)
			Art.dot(ci, Vector2(-14 + k * 26 + f * 6.0, -112 - f * 22.0), 4.0 + f * 6.0, Color(0.85, 0.78, 0.7, 0.5 * (1.0 - f)))


## 2. Furnace: a rounded oven with a fire mouth and a chimney.
static func _furnace_back(ci: CanvasItem, tier: int, m: Dictionary, temple: bool = false) -> void:
	Art.t_rect(ci, Rect2(-10, -132, 20, 40), 3, m["dark"], 2.6, 0.3)
	Art.t_rect(ci, Rect2(-13, -138, 26, 8), 3, m["trim"], 2.4, 0.2)
	var body := Rect2(-38, -100, 76, 100)
	Art.t_rect(ci, body, 20 if tier >= 2 else 10, Color("c8604a") if tier == 0 and not temple else m["body"], 3.0, 0.6)
	if temple:
		# Stone blocks of the idol head.
		for y: float in [-56.0, -20.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(-36, y), Vector2(-26, y)]), Art.shade_of(m["body"], 0.3), 2.0)
			Art.line_c(ci, PackedVector2Array([Vector2(26, y), Vector2(36, y)]), Art.shade_of(m["body"], 0.3), 2.0)
	elif tier == 0:
		for j in 6:
			var y := -88.0 + j * 14.0
			Art.line_c(ci, PackedVector2Array([Vector2(-36, y), Vector2(36, y)]), Color("8e3a2c"), 2.0)
			var x := -24.0 if j % 2 == 0 else -10.0
			while x < 36.0:
				Art.line_c(ci, PackedVector2Array([Vector2(x, y), Vector2(x, y + 14)]), Color("8e3a2c"), 2.0)
				x += 28.0
	else:
		Art.t_rect(ci, Rect2(-38, -80, 76, 10), 3, m["trim"], 2.2, 0.2)
	Art.t_rect(ci, Rect2(-25, -59, 50, 42), 16, Art.shade_of(m["trim"], 0.15), 2.6, 0.2)
	Art.t_rect(ci, Rect2(-20, -54, 40, 34), 14, Color("2a1830"), 2.4, 0.0)
	# The dial (needle in the live part).
	if not temple:
		Art.t_circle(ci, Vector2(26, -88), 7, Art.WHITE, 2.0, 0.0)


static func _furnace_live(ci: CanvasItem, _tier: int, _m: Dictionary, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	var flame: Color = o.get("flame", Color("ff9a3c"))
	var lit := 1.0 if working else 0.35
	var fl := Props._q(0.85 + 0.15 * sin(t * 13.0), 8) if working else 0.6
	Props.halo(ci, Vector2(0, -36), 60 * lit, Color(flame, 0.5 * lit))
	Art.push(ci, Vector2(0, -21), 0.0, Vector2(1.0, fl * lit + 0.2))
	Art.toon(ci, PackedVector2Array([Vector2(-16, 0), Vector2(-12, -18), Vector2(-5, -10), Vector2(0, -28), Vector2(5, -12), Vector2(12, -20), Vector2(16, 0)]), flame, 2.0, 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(-8, 0), Vector2(-3, -12), Vector2(0, -6), Vector2(4, -14), Vector2(8, 0)]), Color("fff1a8"), 0.0, 0.0)
	Art.pop(ci)
	# Glowing coals at the mouth's foot.
	for k in 3:
		var hot := working and (int(t * 3.0) + k) % 2 == 0
		Art.push(ci, Vector2(-10 + k * 10, -22))
		Art.t_circle(ci, Vector2.ZERO, 4.5, flame.lerp(Color("fff1a8"), 0.4) if hot else Art.shade_of(flame, 0.35 if working else 0.55), 1.6, 0.0)
		Art.pop(ci)
	if str(o.get("style", "")) == "temple":
		# The idol's eyes glow while the fire burns.
		for sx: float in [-16.0, 16.0]:
			Art.t_ellipse(ci, Vector2(sx, -69), Vector2(6, 4), Color("fff1a8") if working else Art.WHITE, 0.0, 0.0)
			Art.disc(ci, Vector2(sx + 1, -69), 2.2, Color("ff8a2a") if working else Art.INK)
		if working:
			Props.halo(ci, Vector2(0, -69), 30, Color(1.0, 0.8, 0.3, 0.25 * fl))
	else:
		# The dial.
		Art.push(ci, Vector2(26, -88), snappedf(0.9 + sin(t * 3.0) * 0.15, 0.05) if working else -0.9)
		Art.flat(ci, Art.rrect_pts(Rect2(-1, -6, 2, 6), 1), Art.RED)
		Art.pop(ci)
	# Smoke from the chimney and embers.
	var puffs := 3 if working else 1
	for k in puffs:
		var f := fposmod(t * (0.45 if working else 0.2) + k / float(puffs), 1.0)
		var c := Vector2(sin(f * 4.0 + k) * 6.0 + f * 10.0, -144.0 - f * 60.0)
		Art.dot(ci, c, 6.0 + f * 10.0, Color(0.78, 0.75, 0.84, 0.55 * (1.0 - f)))
	if working:
		for k in 3:
			var f := fposmod(t * 0.9 + k * 0.33, 1.0)
			Art.dot(ci, Vector2(-14 + k * 14 + sin(f * 9.0 + k) * 4.0, -60 - f * 40.0), 2.2 * (1.0 - f) + 0.6, Color(1.0, 0.8, 0.3, 1.0 - f))


## 3. Polisher: a spinning drum on a base, sparks fly while it runs.
static func _polisher_back(ci: CanvasItem, _tier: int, m: Dictionary) -> void:
	Art.t_rect(ci, Rect2(-34, -36, 68, 36), 6, m["dark"], 3.0, 0.5)
	Art.t_rect(ci, Rect2(-30, -32, 60, 8), 3, m["trim"], 2.0, 0.2)
	for x: float in [-22.0, 22.0]:
		Art.t_rect(ci, Rect2(x - 4, -70, 8, 36), 2, m["trim"], 2.2, 0.2)


static func _polisher_live(ci: CanvasItem, tier: int, m: Dictionary, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var gr: float = snappedf(o.get("gear", 0.0) * 1.6, 0.05)
	var working: bool = o.get("working", false)
	Art.push(ci, Vector2(0, -64), gr)
	Art.t_circle(ci, Vector2.ZERO, 24, m["body"], 3.0, 0.0)
	if str(o.get("style", "")) == "temple":
		# A carved sun disc.
		for k in 8:
			var a := k * TAU / 8.0
			Art.toon(ci, PackedVector2Array([Vector2.from_angle(a - 0.2) * 10, Vector2.from_angle(a) * 21, Vector2.from_angle(a + 0.2) * 10]), m["trim"], 1.6, 0.0)
		Art.t_circle(ci, Vector2.ZERO, 9, m["trim"], 2.0, 0.0)
		Art.disc(ci, Vector2.ZERO, 3.5, JADE)
	else:
		for k in 4:
			Art.line_c(ci, PackedVector2Array([Vector2(7, 0).rotated(k * PI / 2.0), Vector2(21, 0).rotated(k * PI / 2.0)]), Art.shade_of(m["body"], 0.3), 3.0)
		Art.t_circle(ci, Vector2.ZERO, 7, m["trim"], 2.0, 0.0)
	Art.pop(ci)
	Art.arc_c(ci, Vector2(0, -64), 19, PI * 1.1, PI * 1.45, 6, Color(1, 1, 1, 0.55), 3.0)
	if tier >= 2:
		Art.flat(ci, Art.ellipse_pts(Vector2(0, -66), Vector2(32, 30), 24), Color(0.75, 0.95, 1.0, 0.25))
		Art.arc_c(ci, Vector2(0, -66), 31, PI, TAU, 16, Art.INK, 2.5)
		Art.arc_c(ci, Vector2(0, -66), 25, PI * 1.15, PI * 1.45, 6, Color(1, 1, 1, 0.8), 3.0)
	if working:
		# Sparks fly off the drum's edge.
		for k in 5:
			var f := fposmod(t * 2.2 + k * 0.2, 1.0)
			var a := -0.4 + k * 0.08
			var p := Vector2(24, -64) + Vector2(cos(a), sin(a)) * f * 26.0 + Vector2(0, f * f * 14.0)
			Art.dot(ci, p, 2.4 * (1.0 - f) + 0.5, Color(1.0, 0.9, 0.4, 1.0 - f))
		for k in 2:
			var ph := fposmod(t * 1.7 + k * 0.5, 1.0)
			Art.dot(ci, Vector2(-26 + k * 52, -96 - ph * 16), 3.0 * (1.0 - ph) + 1.0, Color(1, 1, 0.8, 1.0 - ph))


## 4. Coin press: a frame with a piston that stamps coins.
static func _press_back(ci: CanvasItem, tier: int, m: Dictionary) -> void:
	for x: float in [-32.0, 24.0]:
		Art.t_rect(ci, Rect2(x, -124, 8, 118), 2, m["trim"], 2.6, 0.3)
	Art.t_rect(ci, Rect2(-40, -134, 80, 20), 6, m["body"], 3.0, 0.5)
	if tier >= 1:
		_rivets(ci, Rect2(-40, -134, 80, 20))
	Art.t_rect(ci, Rect2(-34, -32, 68, 28), 6, m["body"], 3.0, 0.5)
	for k in 4:
		Art.flat(ci, PackedVector2Array([Vector2(-28 + k * 14, -12), Vector2(-22 + k * 14, -12), Vector2(-26 + k * 14, -6), Vector2(-32 + k * 14, -6)]), Color(Art.INK, 0.4))
	Art.t_rect(ci, Rect2(-20, -40, 40, 10), 3, Art.METAL, 2.4, 0.3)
	# Output chute to the right and its tray.
	Art.toon(ci, PackedVector2Array([Vector2(30, -30), Vector2(50, -40), Vector2(54, -32), Vector2(34, -20)]), m["trim"], 2.4, 0.3)
	Art.t_rect(ci, Rect2(30, -10, 22, 10), 3, m["dark"], 2.2, 0.2)


static func _press_live(ci: CanvasItem, _tier: int, m: Dictionary, o: Dictionary) -> void:
	var p: float = Props._q(o.get("press", 0.0), 10)
	var flash: float = o.get("flash", 0.0)
	var t: float = o.get("t", 0.0)
	var working: bool = o.get("working", false)
	Art.push(ci, Vector2(0, p * 34.0))
	Art.t_rect(ci, Rect2(-6, -116, 12, 40), 2, Art.METAL, 2.4, 0.3)
	Art.t_rect(ci, Rect2(-18, -80, 36, 14), 4, m["dark"], 2.6, 0.3)
	Art.pop(ci)
	Art.push(ci, Vector2(0, -44), 0.0, Vector2.ONE * (1.0 + Props._q(flash, 6) * 0.4))
	Art.coin(ci, Vector2.ZERO, 8.0)
	Art.pop(ci)
	if working and p > 0.85:
		# Impact: a flash of sparks under the ram.
		Art.push(ci, Vector2(0, -44))
		Art.toon(ci, Art.star_pts(Vector2.ZERO, 18, 7, 8), Color(1.0, 0.95, 0.6, 0.85), 0.0, 0.0)
		Art.pop(ci)
	# Coins sliding down the chute into the tray.
	if working:
		var f := Props._q(fposmod(t * 1.3, 1.0), 20)
		Art.coin(ci, Vector2(34, -28).lerp(Vector2(46, -14), f), 5)
	Art.coin(ci, Vector2(41, -14), 6)


# --- Products tube --------------------------------------------------------------------

## The glass tube from `a` (bottom) straight up to `top_y`, with a funnel at
## its foot. `caps` are 0..1 positions of capsules going up; while
## `stream` the coins rise in a steady line.
static func pipe(ci: CanvasItem, a: Vector2, top_y: float, lk: Dictionary, caps: Array, t: float = 0.0, stream: bool = false) -> void:
	var r := Rect2(a.x - 12, top_y, 24, a.y - top_y)
	Art.flat(ci, _quad(r), Color(0.8, 0.96, 1.0, 0.4))
	if stream:
		var gap := 46.0
		var off := fposmod(t * 110.0, gap)
		var y := a.y - 22.0 - off
		while y > top_y + 8.0:
			Art.push(ci, Vector2(a.x, snappedf(y, 0.5)), 0.0, Vector2(1.0, 0.7))
			Art.coin(ci, Vector2.ZERO, 8)
			Art.pop(ci)
			y -= gap
	for c in caps:
		var y := lerpf(a.y - 10.0, top_y + 6.0, float(c))
		Art.push(ci, Vector2(a.x, snappedf(y, 0.5)))
		Art.t_rect(ci, Rect2(-8, -11, 16, 22), 7, Art.GOLD, 2.2, 0.4)
		Art.flat(ci, Art.rrect_pts(Rect2(-8, -2, 16, 4), 1), Art.GOLD_DARK)
		Art.pop(ci)
	Art.line_c(ci, PackedVector2Array([r.position, Vector2(r.position.x, r.end.y)]), Art.INK, 3.0)
	Art.line_c(ci, PackedVector2Array([Vector2(r.end.x, r.position.y), r.end]), Art.INK, 3.0)
	Art.line_c(ci, PackedVector2Array([r.position + Vector2(5, 0), Vector2(r.position.x + 5, r.end.y)]), Color(1, 1, 1, 0.6), 2.5)
	var y2 := top_y + 30.0
	while y2 < a.y - 10.0:
		Art.t_rect(ci, Rect2(a.x - 15, y2, 30, 7), 2, Art.BRASS, 2.2, 0.2)
		y2 += 70.0
	# Funnel at the foot and the ceiling collar.
	Art.toon(ci, PackedVector2Array([a + Vector2(-26, 0), a + Vector2(26, 0), a + Vector2(14, -18), a + Vector2(-14, -18)]), Art.BRASS, 2.8, 0.4)
	Art.t_rect(ci, Rect2(a.x - 20, top_y - 4, 40, 14), 4, Art.BRASS, 2.6, 0.3)


# --- Mezzanine --------------------------------------------------------------------------

## A balcony deck from x0 to x1 whose walking surface is at y (local),
## with posts down to `floor_y` and a ladder at `ladder_x` (< 0: none).
static func mezzanine(ci: CanvasItem, x0: float, x1: float, y: float, floor_y: float, lk: Dictionary, ladder_x: float = -1.0) -> void:
	var c: Color = lk["col"]
	if is_temple(lk):
		# A wooden deck on stone posts, with a carved edge.
		_vgrad(ci, Rect2(x0, y + 16, x1 - x0, 34), Color(Art.SHADE, 0.28), Color(Art.SHADE, 0.0))
		var px := x0 + 20.0
		while px < x1:
			Art.t_rect(ci, Rect2(px - 7, y, 14, floor_y - y), 2, Art.shade_of(c, 0.05), 2.4, 0.4)
			Art.flat(ci, _quad(Rect2(px - 7, y + 24, 14, 5)), Art.GOLD)
			px += 140.0
		Art.t_rect(ci, Rect2(x0, y, x1 - x0, 16), 2, Color("a8743e"), 3.0, 0.4)
		var sx := x0 + 30.0
		while sx < x1 - 10.0:
			Art.line_c(ci, PackedVector2Array([Vector2(sx, y + 2), Vector2(sx, y + 14)]), Color("7a4a26"), 1.6)
			sx += 46.0
		Art.flat(ci, _quad(Rect2(x0 + 4, y + 11, x1 - x0 - 8, 3)), Color(0, 0, 0, 0.2))
		return
	# The shadow the deck throws on the wall under it.
	_vgrad(ci, Rect2(x0, y + 16, x1 - x0, 34), Color(Art.SHADE, 0.28), Color(Art.SHADE, 0.0))
	var x := x0 + 20.0
	while x < x1:
		Art.t_rect(ci, Rect2(x - 6, y, 12, floor_y - y), 2, Art.shade_of(c, 0.05), 2.4, 0.4)
		x += 140.0
	if ladder_x >= 0.0:
		for sx: float in [0.0, 30.0]:
			Art.t_rect(ci, Rect2(ladder_x + sx - 3, y - 6, 6, floor_y - y + 6), 2, lk["haz"], 2.0, 0.2)
		var ry := y + 14.0
		while ry < floor_y - 6.0:
			Art.t_rect(ci, Rect2(ladder_x, ry, 30, 4), 1, lk["haz"], 1.6, 0.0)
			ry += 22.0
	Art.t_rect(ci, Rect2(x0, y, x1 - x0, 16), 3, c, 3.0, 0.4)
	Art.flat(ci, _quad(Rect2(x0 + 4, y + 11, x1 - x0 - 8, 3)), Color(0, 0, 0, 0.2))
	var hx := x0 + 8.0
	while hx < x1 - 10.0:
		Art.flat(ci, PackedVector2Array([Vector2(hx, y + 3), Vector2(hx + 8, y + 3), Vector2(hx + 4, y + 9), Vector2(hx - 4, y + 9)]), Color(lk["haz"], 0.9))
		hx += 16.0


## The railing in front of what stands on the mezzanine.
static func railing(ci: CanvasItem, x0: float, x1: float, y: float, lk: Dictionary) -> void:
	var c: Color = lk["haz"]
	if is_temple(lk):
		var bx := x0 + 8.0
		while bx <= x1 - 4.0:
			_bamboo(ci, Vector2(bx, y - 34), Vector2(bx, y), 6.0)
			bx += 44.0
		_bamboo(ci, Vector2(x0 + 4, y - 30), Vector2(x1 - 4, y - 30), 7.0)
		_bamboo(ci, Vector2(x0 + 4, y - 14), Vector2(x1 - 4, y - 14), 5.0)
		bx = x0 + 8.0
		while bx <= x1 - 4.0:
			Art.t_circle(ci, Vector2(bx, y - 30), 3.5, Color("c9a26a"), 1.4, 0.0)
			bx += 44.0
		return
	Art.stroke(ci, PackedVector2Array([Vector2(x0 + 4, y - 30), Vector2(x1 - 4, y - 30)]), c, 5.0, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(x0 + 4, y - 15), Vector2(x1 - 4, y - 15)]), Art.shade_of(c, 0.25), 2.5)
	var x := x0 + 8.0
	while x <= x1 - 4.0:
		Art.line_c(ci, PackedVector2Array([Vector2(x, y - 30), Vector2(x, y)]), Art.shade_of(c, 0.25), 3.0)
		x += 44.0


## The second line's spot while it is not bought: covered machines behind
## a hazard-tape barrier, and a sign with a padlock, the name and the price.
static func closed_line(ci: CanvasItem, lk: Dictionary, label: String = "", price: String = "") -> void:
	for x: float in [70.0, 170.0, 280.0]:
		Art.push(ci, Vector2(x, 0))
		var tarp := Art.smooth_pts(PackedVector2Array([Vector2(-42, 0), Vector2(-38, -50), Vector2(-14, -76), Vector2(16, -72), Vector2(38, -48), Vector2(42, 0)]), 3)
		Art.toon(ci, tarp, Color("8ba0b8") if str(lk["style"]) != "plates" else Color("6f6a7c"), 3.0, 0.6)
		Art.line_c(ci, PackedVector2Array([Vector2(-30, -30), Vector2(30, -36)]), Color(0, 0, 0, 0.2), 3.0)
		Art.line_c(ci, PackedVector2Array([Vector2(-20, -60), Vector2(-2, -4)]), Color(0, 0, 0, 0.15), 3.0)
		Art.pop(ci)
	# Crates of parts waiting to be built in.
	box(ci, Rect2(336, -30, 34, 30), Art.WOOD)
	box(ci, Rect2(344, -52, 24, 22), Color("d9b27a"))
	# The barrier: posts and striped tape.
	for x: float in [10.0, 200.0, 390.0]:
		Art.t_rect(ci, Rect2(x - 4, -46, 8, 46), 3, Art.CORAL, 2.2, 0.3)
		Art.t_rect(ci, Rect2(x - 9, -6, 18, 6), 2, Art.INK_SOFT, 1.8, 0.0)
	var x := 14.0
	var i := 0
	while x < 386.0:
		Art.flat(ci, _quad(Rect2(x, -40, minf(16.0, 386.0 - x), 8)), Art.GOLD if i % 2 == 0 else Art.INK)
		x += 16.0
		i += 1
	# The sign board.
	var sc := Vector2(200, -124)
	for sx: float in [-44.0, 44.0]:
		Art.t_rect(ci, Rect2(sc.x + sx - 3, sc.y, 6, 80), 2, Art.WOOD_DARK, 2.0, 0.0)
	Art.t_rect(ci, Rect2(sc.x - 96, sc.y - 36, 192, 68), 14, Art.CREAM, 3.0, 0.4)
	Art.ring(ci, Art.rrect_pts(Rect2(sc.x - 89, sc.y - 29, 178, 54), 10), Art.GOLD, 2.4)
	Art.lock(ci, sc + Vector2(-64, -2), 24)
	if label != "":
		Art.text(ci, sc + Vector2(14, -6), label, 19, Art.INK, 0, true)
	if price != "":
		Art.coin(ci, sc + Vector2(-26, 11), 9)
		Art.text(ci, sc + Vector2(14, 18), price, 19, Art.GOLD_DARK, 0, true)


## The pulsing "build here" badge over the closed line (origin at its center).
static func build_badge(ci: CanvasItem, t: float) -> void:
	var p := Props._q(0.5 + 0.5 * sin(t * 4.0), 8)
	Props.halo(ci, Vector2.ZERO, 30, Color(1.0, 0.85, 0.3, 0.3 + 0.3 * p))
	Art.push(ci, Vector2.ZERO, 0.0, Vector2.ONE * (1.0 + p * 0.12))
	Art.t_circle(ci, Vector2.ZERO, 17, Art.GREEN, 3.0, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-9, -2.5, 18, 5), 2), Art.WHITE)
	Art.flat(ci, Art.rrect_pts(Rect2(-2.5, -9, 5, 18), 2), Art.WHITE)
	Art.pop(ci)


# --- Jungle: the temple workshop -----------------------------------------------------------
## The jungle hall ("temple" style) is a stone and bamboo temple: carved
## sandstone blocks with glyphs and moss, stone pillars with gold bands,
## bamboo beams under a leaf thatch, stone slab floors, arched windows on
## the rainforest with big leaves, a bamboo aqueduct and a water wheel
## that drives the line. Its machines are carved stone and jade with gold
## trims (the furnace is an idol head breathing fire), and the goods are
## cocoa pods, chocolate bars and little golden idols.

const BAMBOO := Color("d6c25e")
const BAMBOO_DARK := Color("9a8a34")
const LEAF := Color("3fae4e")
const LEAF_LIGHT := Color("6fd45c")
const LEAF_DARK := Color("23804a")
const JADE := Color("3fd6c0")
const TERRACOTTA := Color("d0763e")
const COCOA := Color("8a4a26")
const CHOC := Color("6a3a22")

## Machine materials of the temple line per tier: bamboo and wood,
## sandstone with turquoise, jade with gold, white limestone with gold,
## and solid gold with jade.
const TEMPLE_TIERS := [
	{"body": Color("c98a50"), "trim": Color("e2c47e"), "dark": Color("6e4426"), "light": Color("ffd27a")},
	{"body": Color("e2c47e"), "trim": Color("3fc9b4"), "dark": Color("8a6a3a"), "light": Color("bff8ee")},
	{"body": Color("46b884"), "trim": Color("ffc93c"), "dark": Color("2a6a50"), "light": Color("fff1a8")},
	{"body": Color("f3ead2"), "trim": Color("ffc93c"), "dark": Color("8a6a3a"), "light": Color("bff3ff")},
	{"body": Color("ffc93c"), "trim": Color("3fd6c0"), "dark": Color("a0641c"), "light": Color("fff1a8")},
]


static func is_temple(lk: Dictionary) -> bool:
	return str(lk.get("style", "")) == "temple"


## Carved sandstone blocks in staggered rows, some with glyphs, moss on top.
static func _temple_wall(ci: CanvasItem, w: float, floor_y: float, lk: Dictionary) -> void:
	var wall: Color = lk["wall"]
	var wall2: Color = lk["wall2"]
	Art.flat(ci, _quad(Rect2(0, 0, w, floor_y)), Art.shade_of(wall, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var bh := 46.0
	var y := 0.0
	var row := 0
	while y < floor_y:
		var x := -fmod(row * 41.0, 88.0)
		while x < w:
			var bw := 88.0 if rng.randf() < 0.7 else 64.0
			var r := Rect2(x + 2, y + 2, bw - 4, bh - 4)
			var c := wall if rng.randf() < 0.55 else wall2
			if rng.randf() < 0.12:
				c = c.lerp(Color("c8b07a"), 0.5)
			Art.flat(ci, Art.rrect_pts(r, 5), c)
			Art.line_c(ci, PackedVector2Array([r.position + Vector2(5, 2), Vector2(r.end.x - 5, r.position.y + 2)]), Color(1, 1, 1, 0.28), 2.0)
			Art.line_c(ci, PackedVector2Array([Vector2(r.position.x + 5, r.end.y - 2), r.end - Vector2(5, 2)]), Art.shade_of(c, 0.18), 2.5)
			var roll := rng.randf()
			if roll < 0.13 and y > 70.0 and y < floor_y - 110.0 and bw > 70.0:
				glyph(ci, r.get_center(), rng.randi() % 4, c)
			elif roll < 0.3:
				# Moss creeping over the top edge.
				var mx := r.position.x + rng.randf_range(10, bw - 30)
				Art.flat(ci, Art.ellipse_pts(Vector2(mx, r.position.y + 3), Vector2(rng.randf_range(10, 20), 4.5), 12), Color(LEAF, 0.75))
				Art.flat(ci, Art.ellipse_pts(Vector2(mx + 6, r.position.y + 5), Vector2(6, 3), 8), Color(LEAF_LIGHT, 0.8))
			elif roll < 0.36:
				var cx := r.position.x + rng.randf_range(14, bw - 20)
				Art.line_c(ci, PackedVector2Array([Vector2(cx, r.position.y + 4), Vector2(cx + 5, r.position.y + 14), Vector2(cx + 2, r.position.y + 24)]), Art.shade_of(c, 0.3), 1.6)
			x += bw
		y += bh
		row += 1
	# Warm light from the windows, cool shade low on the wall.
	_vgrad(ci, Rect2(0, floor_y * 0.45, w, floor_y * 0.55), Color(0.2, 0.5, 0.3, 0.0), Color(0.15, 0.4, 0.25, 0.12))


## A glyph carved into a stone block (k: 0 spiral, 1 step fret, 2 sun, 3 face).
static func glyph(ci: CanvasItem, c: Vector2, k: int, stone: Color) -> void:
	var deep := Art.shade_of(stone, 0.34)
	var lit := Color(1, 1, 1, 0.3)
	match k:
		0:
			for p: Array in [[deep, Vector2.ZERO], [lit, Vector2(1, 1.5)]]:
				var pts := PackedVector2Array()
				for i in 14:
					var a := i * 0.62
					pts.append(c + Vector2(p[1]) + Vector2(cos(a), sin(a)) * (2.0 + i * 0.9))
				Art.line_c(ci, pts, p[0], 2.4)
		1:
			for p: Array in [[deep, Vector2.ZERO], [lit, Vector2(1, 1.5)]]:
				var o: Vector2 = c + Vector2(p[1])
				Art.line_c(ci, PackedVector2Array([o + Vector2(-14, 8), o + Vector2(-14, -8), o + Vector2(6, -8), o + Vector2(6, 4),
						o + Vector2(-4, 4), o + Vector2(-4, -2)]), p[0], 2.4)
		2:
			Art.ring(ci, Art.circle_pts(c, 8, 16), deep, 2.4)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				Art.line_c(ci, PackedVector2Array([c + d * 11, c + d * 15]), deep, 2.2)
			Art.disc(ci, c, 2.5, Color(JADE, 0.8))
		3:
			Art.ring(ci, Art.rrect_pts(Rect2(c - Vector2(13, 11), Vector2(26, 22)), 4), deep, 2.2)
			Art.flat(ci, Art.rrect_pts(Rect2(c + Vector2(-9, -6), Vector2(6, 5)), 1), deep)
			Art.flat(ci, Art.rrect_pts(Rect2(c + Vector2(3, -6), Vector2(6, 5)), 1), deep)
			Art.line_c(ci, PackedVector2Array([c + Vector2(-7, 5), c + Vector2(-3, 3), c + Vector2(3, 3), c + Vector2(7, 5)]), deep, 2.2)


## The carved frieze along the foot of the wall: a step-fret band with
## turquoise and gold inlays.
static func _temple_band(ci: CanvasItem, w: float, floor_y: float, lk: Dictionary) -> void:
	var band := Rect2(0, floor_y - 58, w, 58)
	var low: Color = lk["low"]
	Art.flat(ci, _quad(band), low)
	_vgrad(ci, band, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.18))
	Art.flat(ci, _quad(Rect2(0, floor_y - 64, w, 9)), Art.shade_of(low, -0.15))
	Art.line_c(ci, PackedVector2Array([Vector2(0, floor_y - 64), Vector2(w, floor_y - 64)]), Art.shade_of(low, 0.35), 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(0, floor_y - 55), Vector2(w, floor_y - 55)]), Art.shade_of(low, 0.35), 2.0)
	var deep := Art.shade_of(low, 0.32)
	var x := 6.0
	var i := 0
	while x < w:
		var y0 := floor_y - 46.0
		Art.line_c(ci, PackedVector2Array([Vector2(x, y0 + 26), Vector2(x, y0 + 4), Vector2(x + 22, y0 + 4), Vector2(x + 22, y0 + 18),
				Vector2(x + 10, y0 + 18), Vector2(x + 10, y0 + 12)]), deep, 3.0)
		var gem := JADE if i % 2 == 0 else Art.GOLD
		Art.flat(ci, Art.rrect_pts(Rect2(x + 28, y0 + 8, 8, 8), 2), gem)
		Art.ring(ci, Art.rrect_pts(Rect2(x + 28, y0 + 8, 8, 8), 2), deep, 1.6)
		x += 42.0
		i += 1


## A carved stone pillar from y0 to the floor y1, gold bands and a vine.
static func _temple_pillar(ci: CanvasItem, x: float, y0: float, y1: float, lk: Dictionary) -> void:
	var c: Color = lk["col"]
	Art.flat(ci, _quad(Rect2(x - 18, y0, 36, y1 - y0)), Color(0, 0, 0, 0.1))
	Art.t_rect(ci, Rect2(x - 13, y0, 26, y1 - y0), 3, c, 2.6, 0.6)
	for fx: float in [-5.0, 0.0, 5.0]:
		Art.line_c(ci, PackedVector2Array([Vector2(x + fx, y0 + 26), Vector2(x + fx, y1 - 30)]), Art.shade_of(c, 0.18), 1.6)
	Art.flat(ci, _quad(Rect2(x - 10, y0 + 4, 3, y1 - y0 - 8)), Color(1, 1, 1, 0.22))
	for by: float in [y0 + 22.0, y1 - 34.0]:
		Art.t_rect(ci, Rect2(x - 15, by, 30, 8), 2, Art.GOLD, 2.0, 0.3)
		Art.disc(ci, Vector2(x, by + 4), 2.2, JADE)
	Art.t_rect(ci, Rect2(x - 19, y0, 38, 16), 3, Art.shade_of(c, 0.08), 2.6, 0.4)
	Art.t_rect(ci, Rect2(x - 19, y1 - 14, 38, 14), 3, Art.shade_of(c, 0.08), 2.4, 0.4)
	# A diamond glyph in the middle and a vine winding down.
	var mid := (y0 + y1) * 0.5
	Art.toon(ci, PackedVector2Array([Vector2(x, mid - 10), Vector2(x + 7, mid), Vector2(x, mid + 10), Vector2(x - 7, mid)]), JADE, 2.0, 0.3)
	var vine := PackedVector2Array()
	var vy := y0 + 16.0
	var k := 0
	while vy < mid - 20.0:
		vine.append(Vector2(x + (12.0 if k % 2 == 0 else -12.0), vy))
		vy += 22.0
		k += 1
	if vine.size() >= 2:
		Art.stroke(ci, Art.smooth_pts(vine, 3), Color("3a9a48"), 3.0, 1.5)
		for j in vine.size():
			Art.toon(ci, Art.ellipse_pts(vine[j] + Vector2(5 if j % 2 == 0 else -5, 2), Vector2(7, 3.5), 10, 0.5 if j % 2 == 0 else -0.5),
					LEAF_LIGHT if j % 2 == 0 else LEAF, 1.8, 0.3)


## Bamboo poles under a leaf thatch, lashed with rope.
static func _temple_ceiling(ci: CanvasItem, w: float, lk: Dictionary) -> void:
	# Thatch: rows of hanging palm leaves.
	Art.flat(ci, _quad(Rect2(-10, -6, w + 20, 34)), Color("7a5a2a"))
	var x := -14.0
	var k := 0
	while x < w + 20.0:
		var c := LEAF if k % 3 == 0 else (LEAF_DARK if k % 3 == 1 else Color("4fbf56"))
		Art.toon(ci, PackedVector2Array([Vector2(x, 16), Vector2(x + 22, 16), Vector2(x + 13, 40 + (k % 2) * 6)]), c, 2.0, 0.3)
		x += 16.0
		k += 1
	# The big beam and the bamboo pole under it.
	Art.t_rect(ci, Rect2(-10, -6, w + 20, 24), 0.0, lk["beam"], 3.0, 0.5)
	_bamboo(ci, Vector2(-10, 50), Vector2(w + 10, 50), 9.0)
	# Diagonal braces with rope lashings.
	var bx := 30.0
	var up := true
	while bx < w:
		_bamboo(ci, Vector2(bx, 18), Vector2(bx + (22.0 if up else -22.0), 48), 6.0)
		Art.t_circle(ci, Vector2(bx + (22.0 if up else -22.0), 50), 4, Color("c9a26a"), 1.6, 0.0)
		bx += 92.0
		up = not up


## A bamboo pole from a to b, `thick` wide, with nodes.
static func _bamboo(ci: CanvasItem, a: Vector2, b: Vector2, thick: float) -> void:
	Art.stroke(ci, PackedVector2Array([a, b]), BAMBOO, thick, 2.2)
	var d := b - a
	var len := d.length()
	var n := d / maxf(len, 0.001)
	var o := n.orthogonal() * (thick * 0.5)
	Art.line_c(ci, PackedVector2Array([a - o * 0.3, b - o * 0.3]), Color(1, 1, 1, 0.35), maxf(1.5, thick * 0.22))
	var s := 38.0
	while s < len - 6.0:
		var p := a + n * s
		Art.line_c(ci, PackedVector2Array([p + o, p - o]), BAMBOO_DARK, 2.0)
		s += 44.0


## Stone slab floor with grass in the cracks and a turquoise inlay path.
static func _temple_floor(ci: CanvasItem, w: float, y0: float, y1: float, lk: Dictionary) -> void:
	var f: Color = lk["floor"]
	var f2: Color = lk["floor2"]
	Art.flat(ci, _quad(Rect2(0, y0, w, y1 - y0)), f2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var fy := y0 + 2.0
	var k := 0
	while fy < y1:
		var h := 14.0 + k * 6.0
		var fx := -fmod(k * 47.0, 110.0)
		while fx < w:
			var sw := rng.randf_range(80, 120)
			var r := Rect2(fx + 2, fy + 1, sw - 4, h - 3)
			Art.flat(ci, Art.rrect_pts(r, 3), f.lerp(Color("d8c08a"), rng.randf() * 0.25))
			Art.line_c(ci, PackedVector2Array([r.position + Vector2(4, 1.5), Vector2(r.end.x - 4, r.position.y + 1.5)]), Color(1, 1, 1, 0.2), 1.6)
			if rng.randf() < 0.3:
				var gx := fx + rng.randf_range(6, sw - 6)
				for g in 3:
					Art.line_c(ci, PackedVector2Array([Vector2(gx + g * 3, fy + 1), Vector2(gx + g * 3 + (g - 1) * 2, fy - 5 - (g % 2) * 3)]), LEAF, 2.0)
			fx += sw
		fy += h
		k += 1
	# A turquoise inlay path along the hall.
	var wy := y0 + 34.0
	if wy < y1 - 8.0:
		var x := 10.0
		while x < w:
			Art.flat(ci, PackedVector2Array([Vector2(x, wy + 3), Vector2(x + 5, wy), Vector2(x + 10, wy + 3), Vector2(x + 5, wy + 6)]), Color(JADE, 0.8))
			x += 34.0
	_vgrad(ci, Rect2(0, y0, w, 18), Color(Art.SHADE, 0.3), Color(Art.SHADE, 0.0))
	_vgrad(ci, Rect2(0, y0 - 24, w, 24), Color(Art.SHADE, 0.0), Color(Art.SHADE, 0.12))
	Art.line_c(ci, PackedVector2Array([Vector2(0, y0), Vector2(w, y0)]), Art.INK, 3.0)


## A stone window with a stepped (corbel) arch onto the rainforest, big
## leaves growing in from outside.
static func _temple_window(ci: CanvasItem, r: Rect2, lk: Dictionary) -> void:
	var stone: Color = lk["col"]
	# A thick stone frame, a carved lintel with a golden sun, the sill.
	Art.t_rect(ci, r.grow(10), 4, stone, 3.0, 0.5)
	Art.ring(ci, Art.rrect_pts(r.grow(5), 3), Art.shade_of(stone, 0.22), 2.0)
	scene(ci, r, lk)
	Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.12, 0), r.position + Vector2(r.size.x * 0.3, 0),
			r.position + Vector2(r.size.x * 0.08, r.size.y), r.position + Vector2(0, r.size.y)]), Color(1, 1, 0.9, 0.12))
	Art.t_rect(ci, Rect2(r.get_center().x - 4, r.position.y, 8, r.size.y), 1, stone, 2.4, 0.4)
	Art.ring(ci, Art.rrect_pts(r, 2), Art.INK, 3.0)
	var lin := Rect2(r.position.x - 20, r.position.y - 26, r.size.x + 40, 20)
	Art.t_rect(ci, lin, 3, Art.shade_of(stone, 0.06), 3.0, 0.5)
	var deep := Art.shade_of(stone, 0.32)
	var x := lin.position.x + 10.0
	while x < lin.end.x - 24.0:
		if absf(x + 7.0 - r.get_center().x) > 20.0:
			Art.line_c(ci, PackedVector2Array([Vector2(x, lin.end.y - 5), Vector2(x, lin.position.y + 5), Vector2(x + 12, lin.position.y + 5),
					Vector2(x + 12, lin.end.y - 9), Vector2(x + 6, lin.end.y - 9)]), deep, 2.0)
		x += 20.0
	var sun := Vector2(r.get_center().x, lin.get_center().y)
	for k in 8:
		var a := k * TAU / 8.0
		Art.toon(ci, PackedVector2Array([sun + Vector2.from_angle(a - 0.25) * 7, sun + Vector2.from_angle(a) * 13, sun + Vector2.from_angle(a + 0.25) * 7]), Art.GOLD, 1.6, 0.0)
	Art.t_circle(ci, sun, 7.5, Art.GOLD, 2.0, 0.4)
	Art.disc(ci, sun, 2.5, JADE)
	Art.t_rect(ci, Rect2(r.position.x - 18, r.end.y + 6, r.size.x + 36, 10), 3, Art.shade_of(stone, 0.06), 2.6, 0.4)
	# Leaves growing in at the corners and a flowering vine along the sill.
	_leaf(ci, Vector2(r.position.x - 6, r.position.y + 6), minf(34.0, r.size.y * 0.42), 0.55, LEAF)
	_leaf(ci, Vector2(r.end.x + 4, r.end.y - 4), minf(32.0, r.size.y * 0.4), -2.6, LEAF_DARK)
	for i in 3:
		_flower(ci, Vector2(r.position.x + r.size.x * (0.22 + i * 0.28), r.end.y + 6), 4.0, [Color("ff8a2a"), Color("ff4fa8"), Color("ffd23f")][i])


## A big jungle leaf from `base` at angle `a` (radians), `len` long.
static func _leaf(ci: CanvasItem, base: Vector2, len: float, a: float, col: Color) -> void:
	Art.push(ci, base, a)
	var key := hash(["jleaf", len, col])
	if not Art.cache_begin(ci, key):
		# A pointed leaf: wide in the middle, a tip, a midrib and side veins.
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			var wd := len * 0.26 * pow(sin(PI * minf(1.0, u * 1.08)), 0.75)
			top.append(Vector2(u * len, -wd))
			bot.append(Vector2(u * len, wd * 0.9))
		bot.reverse()
		top.append_array(bot)
		Art.toon(ci, top, col, 2.4, 0.5)
		Art.line_c(ci, PackedVector2Array([Vector2(2, 0), Vector2(len * 0.9, 0)]), Art.shade_of(col, 0.3), 1.8)
		for i in 3:
			var x := len * (0.22 + i * 0.2)
			Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x + len * 0.12, -len * 0.15)]), Art.shade_of(col, 0.25), 1.4)
			Art.line_c(ci, PackedVector2Array([Vector2(x, 0), Vector2(x + len * 0.12, len * 0.13)]), Art.shade_of(col, 0.25), 1.4)
		Art.flat(ci, Art.ellipse_pts(Vector2(len * 0.4, -len * 0.1), Vector2(len * 0.18, len * 0.05), 8), Color(1, 1, 1, 0.22))
		Art.cache_end(ci, key)
	Art.pop(ci)


static func _flower(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	for k in 5:
		Art.toon(ci, Art.circle_pts(at + Vector2(0, -r).rotated(k * TAU / 5.0), r * 0.72, 8), col, 1.4, 0.0)
	Art.disc(ci, at, r * 0.5, Color("fff1a8"))


## The rainforest outside: sky and sun, a far pyramid in the haze, a
## waterfall off a green cliff, the canopy and the turquoise river.
static func _jungle_scene(ci: CanvasItem, r: Rect2, lk: Dictionary) -> void:
	var p := r.position
	var s := r.size
	Props.halo(ci, p + Vector2(s.x * 0.8, s.y * 0.2), minf(s.x, s.y) * 0.45, Color(1.0, 0.95, 0.6, 0.6))
	Art.t_circle(ci, p + Vector2(s.x * 0.8, s.y * 0.2), minf(10.0, s.y * 0.12), Color("fff3b0"), 0.0, 0.0)
	# Far hills in the haze, with the pyramid.
	var far := PackedVector2Array([p + Vector2(0, s.y * 0.6), p + Vector2(s.x * 0.2, s.y * 0.48), p + Vector2(s.x * 0.45, s.y * 0.56),
			p + Vector2(s.x * 0.75, s.y * 0.44), p + Vector2(s.x, s.y * 0.52), p + Vector2(s.x, s.y), p + Vector2(0, s.y)])
	Art.flat(ci, Art.smooth_pts(far, 3), Color("8fcfb4"))
	var py := p + Vector2(s.x * 0.6, s.y * 0.5)
	var pw := s.x * 0.2
	for i in 4:
		var w := pw * (1.0 - i * 0.22)
		var h := s.y * 0.06
		Art.flat(ci, _quad(Rect2(py.x - w / 2.0, py.y - (i + 1) * h, w, h + 0.5)), Color("b8c89a") if i % 2 == 0 else Color("a8bc8c"))
	Art.flat(ci, _quad(Rect2(py.x - pw * 0.08, py.y - s.y * 0.3, pw * 0.16, s.y * 0.06)), Color("a8bc8c"))
	# A green cliff with a waterfall on the left.
	var cliff := PackedVector2Array([p + Vector2(0, s.y * 0.3), p + Vector2(s.x * 0.22, s.y * 0.34), p + Vector2(s.x * 0.3, s.y * 0.7), p + Vector2(0, s.y * 0.75)])
	Art.flat(ci, cliff, Color("3f9a5a"))
	Art.flat(ci, _quad(Rect2(p.x + s.x * 0.17, p.y + s.y * 0.34, s.x * 0.06, s.y * 0.5)), Color("dffcff"))
	Art.flat(ci, _quad(Rect2(p.x + s.x * 0.19, p.y + s.y * 0.34, s.x * 0.015, s.y * 0.5)), Color(JADE, 0.6))
	# The canopy: rows of round crowns.
	for row in 2:
		var cy := p.y + s.y * (0.7 + row * 0.1)
		var x := p.x - 6.0 + row * 10.0
		var k := 0
		while x < r.end.x + 10.0:
			var rad := s.x * (0.07 + 0.02 * float((k + row) % 3))
			Art.flat(ci, Art.circle_pts(Vector2(x, cy), rad, 12), Color("2f8a4a") if row == 0 else Color("3faa52"))
			Art.flat(ci, Art.ellipse_pts(Vector2(x - rad * 0.2, cy - rad * 0.55), Vector2(rad * 0.5, rad * 0.22), 10), Color("6fd45c") if row == 1 else Color("4fbf56"))
			x += rad * 1.5
			k += 1
	_vgrad(ci, Rect2(p.x, p.y + s.y * 0.9, s.x, s.y * 0.1), Color("3fd6c0"), Color("1fa8a0"))
	# Two birds.
	for b: Vector2 in [Vector2(0.35, 0.22), Vector2(0.45, 0.17)]:
		var c := p + Vector2(s.x * b.x, s.y * b.y)
		Art.line_c(ci, PackedVector2Array([c + Vector2(-4, -2), c, c + Vector2(4, -2)]), Color("2a4a3a"), 1.5)


## The water wheel turned by the aqueduct (origin at its hub, radius r):
## rim, paddles and spokes at `rot`.
static func wheel(ci: CanvasItem, r: float, rot: float) -> void:
	Art.push(ci, Vector2.ZERO, snappedf(rot, 0.05))
	for k in 10:
		Art.push(ci, Vector2.ZERO, k * TAU / 10.0)
		Art.line_c(ci, PackedVector2Array([Vector2(5, 0), Vector2(r - 2, 0)]), Art.WOOD_DARK, 3.0)
		Art.t_rect(ci, Rect2(r - 6, -6, 13, 12), 2, Art.WOOD, 2.0, 0.3)
		Art.pop(ci)
	Art.pop(ci)
	Art.arc_c(ci, Vector2.ZERO, r - 4, 0.0, TAU, 28, Art.INK, 6.0)
	Art.arc_c(ci, Vector2.ZERO, r - 4, 0.0, TAU, 28, Art.WOOD, 3.0)
	Art.t_circle(ci, Vector2.ZERO, 7, Art.GOLD, 2.2, 0.4)
	Art.disc(ci, Vector2.ZERO, 2.5, Art.GOLD_DARK)


## The still part of the wheel: the bamboo spout from the aqueduct above
## (at `spout_y`, local, < 0) and the stone basin below it.
static func wheel_back(ci: CanvasItem, r: float, spout_y: float) -> void:
	_bamboo(ci, Vector2(-r * 0.2, spout_y), Vector2(-r * 0.2, spout_y + 16), 10.0)
	_bamboo(ci, Vector2(-r * 0.2, spout_y + 12), Vector2(r * 0.45, -r - 10), 8.0)
	Art.flat(ci, Art.circle_pts(Vector2.ZERO, r + 6, 28), Color(0, 0, 0, 0.12))
	Art.t_rect(ci, Rect2(-6, -4, 12, r + 14), 2, Art.WOOD_DARK, 2.0, 0.2)
	Art.toon(ci, PackedVector2Array([Vector2(-r - 6, r - 2), Vector2(r + 6, r - 2), Vector2(r, r + 14), Vector2(-r, r + 14)]), Color("c9aa6e"), 2.6, 0.5)
	Art.flat(ci, PackedVector2Array([Vector2(-r - 1, r + 1), Vector2(r + 1, r + 1), Vector2(r - 2, r + 6), Vector2(-r + 2, r + 6)]), JADE)


## Water pouring onto the wheel and splashing in the basin (t = time).
static func wheel_water(ci: CanvasItem, r: float, t: float, on: bool) -> void:
	var top := Vector2(r * 0.45, -r - 8)
	var flow := 1.0 if on else 0.4
	Art.flat(ci, _quad(Rect2(top.x - 3.5 * flow, top.y, 7 * flow, r * 0.6)), Color(0.75, 0.97, 1.0, 0.85))
	for i in 3:
		var f := fposmod(t * 1.8 + i / 3.0, 1.0)
		Art.push(ci, Vector2(top.x, snappedf(top.y + f * r * 0.6, 1.0)))
		Art.flat(ci, Art.rrect_pts(Rect2(-1, 0, 2, 7), 1), Color(1, 1, 1, 0.8))
		Art.pop(ci)
	# Drops thrown off the paddles and the splash in the basin.
	for i in 4:
		var f := fposmod(t * 1.3 + i / 4.0, 1.0)
		var a := 0.2 + i * 0.35
		var d := Vector2(cos(a), sin(a)) * r
		Art.dot(ci, d + Vector2(f * 8.0, f * f * 26.0), 2.4 * (1.0 - f) + 0.5, Color(0.8, 0.98, 1.0, 1.0 - f))
	for i in 2:
		var f := fposmod(t * 1.1 + i * 0.5, 1.0)
		Art.dot(ci, Vector2(-r * 0.5 + i * r, r - 2 - f * 8.0), 3.0 + f * 4.0, Color(1, 1, 1, 0.6 * (1.0 - f)))


## A torch in a stone bracket on a pillar (origin at the bracket).
static func torch(ci: CanvasItem) -> void:
	Art.t_rect(ci, Rect2(-7, 0, 14, 8), 2, Color("8a6a3a"), 2.0, 0.3)
	Art.toon(ci, PackedVector2Array([Vector2(-5, -14), Vector2(5, -14), Vector2(3, 2), Vector2(-3, 2)]), Art.WOOD_DARK, 2.0, 0.3)
	Art.t_rect(ci, Rect2(-6, -17, 12, 5), 2, Color("c9a26a"), 1.8, 0.0)


static func torch_flame(ci: CanvasItem, t: float, lk: Dictionary) -> void:
	var fl := Props._q(0.82 + 0.18 * sin(t * 13.0) * sin(t * 7.3 + 1.0), 6)
	Props.halo(ci, Vector2(0, -26), 42, Color(Color(lk["glow"]), 0.36 + 0.1 * fl))
	Art.push(ci, Vector2(0, -16), 0.0, Vector2(1.0 - (1.0 - fl) * 0.4, fl))
	Art.toon(ci, PackedVector2Array([Vector2(-7, 0), Vector2(-6, -10), Vector2(-2, -8), Vector2(0, -22), Vector2(3, -9), Vector2(6, -12), Vector2(7, 0)]), Color("ff8a2a"), 2.0, 0.0)
	Art.flat(ci, PackedVector2Array([Vector2(-3, 0), Vector2(0, -12), Vector2(3, 0)]), Color("fff1a8"))
	Art.pop(ci)


## A monkey hanging by its tail from a beam (origin at the beam), swinging by `swing` radians.
static func monkey(ci: CanvasItem, swing: float, t: float, blink: bool) -> void:
	Art.push(ci, Vector2.ZERO, snappedf(swing, 0.04))
	Art.stroke(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(6, 8), Vector2(0, 16), Vector2(-2, 26)]), 3), Color("8a5a2c"), 3.0, 1.5)
	var b := Vector2(-2, 40)
	# Arms reaching down, legs up, body upside down.
	Art.stroke(ci, PackedVector2Array([b + Vector2(-6, 6), b + Vector2(-12, 22)]), Color("8a5a2c"), 4.0, 1.5)
	Art.stroke(ci, PackedVector2Array([b + Vector2(6, 6), b + Vector2(10, 21 + sin(t * 3.0) * 2.0)]), Color("8a5a2c"), 4.0, 1.5)
	Art.t_ellipse(ci, b, Vector2(10, 13), Color("9a6234"), 2.4, 0.5)
	Art.flat(ci, Art.ellipse_pts(b + Vector2(0, 2), Vector2(5.5, 8), 10), Color("e8c08a"))
	var h := b + Vector2(0, 20)
	for sx: float in [-10.0, 10.0]:
		Art.t_circle(ci, h + Vector2(sx, -2), 5, Color("9a6234"), 2.0, 0.0)
		Art.disc(ci, h + Vector2(sx, -2), 2.4, Color("e8b07a"))
	Art.t_circle(ci, h, 10, Color("9a6234"), 2.4, 0.4)
	Art.t_ellipse(ci, h + Vector2(0, 2), Vector2(7.5, 6.5), Color("f0cf9a"), 0.0, 0.0)
	if blink:
		Art.line_c(ci, PackedVector2Array([h + Vector2(-5, 0), h + Vector2(-2, 0)]), Art.INK, 1.6)
		Art.line_c(ci, PackedVector2Array([h + Vector2(2, 0), h + Vector2(5, 0)]), Art.INK, 1.6)
	else:
		Art.disc(ci, h + Vector2(-3.5, 0), 1.8, Art.INK)
		Art.disc(ci, h + Vector2(3.5, 0), 1.8, Art.INK)
	Art.arc_c(ci, h + Vector2(0, 2.5), 3.0, 0.3, PI - 0.3, 6, Art.INK, 1.5)
	Art.pop(ci)


## A parrot perched on a beam (origin at its feet); `bob` 0..1 dips the head.
static func parrot(ci: CanvasItem, bob: float, blink: bool, facing: float) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	Art.toon(ci, PackedVector2Array([Vector2(-3, -6), Vector2(-14, 22), Vector2(-7, 24), Vector2(3, -4)]), Color("3a7ae0"), 2.0, 0.2)
	Art.t_ellipse(ci, Vector2(0, -12), Vector2(8, 12), Color("ef3e3e"), 2.4, 0.5)
	Art.flat(ci, Art.ellipse_pts(Vector2(3, -9), Vector2(4, 7), 10), Color("ff7a3c"))
	Art.toon(ci, PackedVector2Array([Vector2(-7, -14), Vector2(2, -12), Vector2(-3, 2), Vector2(-9, -1)]), Color("ffd23f"), 2.0, 0.3)
	Art.toon(ci, PackedVector2Array([Vector2(-4, -6), Vector2(1, -6), Vector2(-1, 0), Vector2(-5, 0)]), Color("3a7ae0"), 1.4, 0.0)
	var h := Vector2(3, -25 + Props._q(bob, 4) * 3.0)
	Art.t_circle(ci, h, 7, Color("ef3e3e"), 2.4, 0.4)
	Art.flat(ci, Art.ellipse_pts(h + Vector2(2.5, 0), Vector2(3.4, 2.8), 8), Art.WHITE)
	if blink:
		Art.line_c(ci, PackedVector2Array([h + Vector2(1.5, -0.5), h + Vector2(5, -0.5)]), Art.INK, 1.4)
	else:
		Art.disc(ci, h + Vector2(3.2, -0.6), 1.4, Art.INK)
	Art.toon(ci, PackedVector2Array([h + Vector2(5, -3), h + Vector2(11, 1), h + Vector2(6, 4)]), Color("3a3040"), 1.6, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-2, 0), Vector2(-2, -3)]), Color("5a4a3a"), 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(2, 0), Vector2(2, -3)]), Color("5a4a3a"), 2.0)
	Art.pop(ci)


## A butterfly (origin at its body); `flap` 0..1 closes the wings.
static func butterfly(ci: CanvasItem, flap: float, col: Color) -> void:
	var k := 0.25 + 0.75 * (1.0 - Props._q(flap, 4))
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(k, 1.0))
	Art.toon(ci, PackedVector2Array([Vector2(0, -1), Vector2(-9, -9), Vector2(-11, -2), Vector2(-3, 1)]), col, 1.6, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(0, -1), Vector2(9, -9), Vector2(11, -2), Vector2(3, 1)]), col, 1.6, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-1, 0), Vector2(-7, 6), Vector2(-3, 7)]), col.lightened(0.3), 1.4, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(1, 0), Vector2(7, 6), Vector2(3, 7)]), col.lightened(0.3), 1.4, 0.0)
	Art.pop(ci)
	Art.flat(ci, Art.rrect_pts(Rect2(-1, -5, 2, 10), 1), Art.INK)


## A garland of leaves and flowers (the jungle's pennants).
static func garland(ci: CanvasItem, x0: float, x1: float, y: float, sag: float) -> void:
	var n := maxi(4, int((x1 - x0) / 22.0))
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, u), y + sin(u * PI) * sag))
	Art.polyline(ci, pts, Color("3a7a3a"), 2.5)
	for i in n:
		var m := (pts[i] + pts[i + 1]) / 2.0
		if i % 3 == 1:
			_flower(ci, m + Vector2(0, 3), 5.0, [Color("ff8a2a"), Color("ff4fa8"), Color("ffd23f")][(i / 3) % 3])
		else:
			Art.push(ci, m, 1.57 + (0.25 if i % 2 == 0 else -0.25))
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(8, -5), Vector2(17, 0), Vector2(8, 5)]), 2), LEAF if i % 2 == 0 else LEAF_LIGHT, 1.8, 0.3)
			Art.pop(ci)


## Hanging vines from the ceiling (static), `len` long with leaves and a flower.
static func vine(ci: CanvasItem, top: Vector2, len: float, seed: int) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		pts.append(top + Vector2(sin(f * 2.6 + seed) * 6.0, f * len))
	Art.stroke(ci, pts, Color("3a9a48"), 3.0, 1.5)
	for i in range(1, 7):
		var side := 1.0 if (i + seed) % 2 == 0 else -1.0
		Art.toon(ci, Art.ellipse_pts(pts[i] + Vector2(side * 6.0, -1), Vector2(7, 3.5), 10, side * 0.6), LEAF_LIGHT if i % 2 == 0 else LEAF, 1.8, 0.3)
	_flower(ci, pts[6] + Vector2(0, 4), 4.5, [Color("ff8a2a"), Color("ff4fa8"), Color("ffd23f")][seed % 3])


## A clay water jar (the temple's fire bucket), origin bottom center.
static func water_jar(ci: CanvasItem) -> void:
	var body := Art.smooth_pts(PackedVector2Array([Vector2(-10, 0), Vector2(-16, -16), Vector2(-12, -32), Vector2(-7, -36),
			Vector2(7, -36), Vector2(12, -32), Vector2(16, -16), Vector2(10, 0)]), 3)
	Art.toon(ci, body, TERRACOTTA, 2.6, 0.6)
	Art.flat(ci, _quad(Rect2(-14, -22, 28, 5)), JADE)
	Art.t_rect(ci, Rect2(-9, -42, 18, 7), 3, Art.shade_of(TERRACOTTA, 0.1), 2.2, 0.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -41), Vector2(6, 2), 10), Color("1fa8a0"))
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -20), Vector2(2.5, 7), 8), Color(1, 1, 1, 0.3))


## Carvings and trims over a machine of the temple line (drawn after its body).
static func _temple_carve(ci: CanvasItem, i: int, tier: int, m: Dictionary) -> void:
	var deep := Art.shade_of(m["body"], 0.35)
	match i:
		0:
			# A jaguar's face on the crusher: brow, eyes and a row of teeth.
			Art.flat(ci, Art.rrect_pts(Rect2(-30, -74, 60, 7), 2), m["trim"])
			for sx: float in [-22.0, 22.0]:
				Art.t_circle(ci, Vector2(sx, -60), 5, m["trim"], 2.0, 0.2)
				Art.disc(ci, Vector2(sx, -60), 2.2, Art.INK)
			for k in 5:
				Art.toon(ci, PackedVector2Array([Vector2(-15 + k * 7, -26), Vector2(-9 + k * 7, -26), Vector2(-12 + k * 7, -20)]), Art.WHITE, 1.4, 0.0)
		1:
			# The furnace is an idol head: brow ridge, ear spools, a feather crown.
			Art.t_rect(ci, Rect2(-36, -84, 72, 9), 3, m["trim"], 2.2, 0.3)
			for sx: float in [-1.0, 1.0]:
				Art.t_circle(ci, Vector2(sx * 40, -50), 8, m["trim"], 2.4, 0.3)
				Art.t_circle(ci, Vector2(sx * 40, -50), 3.5, JADE if tier != 4 else Art.WHITE, 1.6, 0.0)
				Art.t_rect(ci, Rect2(sx * 16 - 9, -74, 18, 10), 4, Color("2a1830"), 2.0, 0.0)
			Art.toon(ci, PackedVector2Array([Vector2(-5, -72), Vector2(5, -72), Vector2(7, -61), Vector2(-7, -61)]), Art.shade_of(m["body"], 0.12), 2.0, 0.3)
			var cols := [Color("ef3e3e"), Color("3fd6c0"), Art.GOLD, Color("3fd6c0"), Color("ef3e3e")]
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.32
				var base := Vector2(cos(a) * 22.0, -98 + sin(a) * 8.0 + 8.0)
				Art.push(ci, base, a + PI / 2.0)
				Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(-6, -14), Vector2(0, -26), Vector2(6, -14)]), 2), cols[k], 2.0, 0.3)
				Art.pop(ci)
		2:
			# A step-fret base and gold studs on the polisher.
			for k in 4:
				Art.disc(ci, Vector2(-24 + k * 16, -14), 2.6, m["trim"])
			Art.line_c(ci, PackedVector2Array([Vector2(-28, -6), Vector2(-28, -12), Vector2(-20, -12), Vector2(-20, -8)]), deep, 2.0)
			Art.line_c(ci, PackedVector2Array([Vector2(28, -6), Vector2(28, -12), Vector2(20, -12), Vector2(20, -8)]), deep, 2.0)
		3:
			# Serpent heads on the press's top beam and a sun on its base.
			for sx: float in [-1.0, 1.0]:
				Art.push(ci, Vector2(sx * 44, -124), 0.0, Vector2(sx, 1))
				Art.toon(ci, PackedVector2Array([Vector2(-4, -8), Vector2(10, -6), Vector2(14, 0), Vector2(10, 5), Vector2(-4, 8)]), m["trim"], 2.2, 0.3)
				Art.disc(ci, Vector2(6, -2), 1.8, Art.INK)
				Art.pop(ci)
			Art.t_circle(ci, Vector2(0, -18), 7, Art.GOLD, 2.0, 0.3)
			Art.disc(ci, Vector2(0, -18), 2.5, Art.GOLD_DARK)


## What the temple line makes: cocoa pods, chocolate bars, golden idols.
static func _temple_good(ci: CanvasItem, i: int) -> void:
	match i:
		0:
			Art.t_ellipse(ci, Vector2(0, -6), Vector2(8, 5), Color("e0802e"), 1.8, 0.4)
			Art.line_c(ci, PackedVector2Array([Vector2(-5, -7), Vector2(5, -7)]), Art.shade_of(Color("e0802e"), 0.3), 1.4)
			Art.line_c(ci, PackedVector2Array([Vector2(-5, -4), Vector2(5, -4)]), Art.shade_of(Color("e0802e"), 0.3), 1.4)
		1:
			Art.t_rect(ci, Rect2(-9, -8, 18, 8), 2, CHOC, 1.8, 0.4)
			Art.line_c(ci, PackedVector2Array([Vector2(-3, -7), Vector2(-3, -1)]), Art.shade_of(CHOC, 0.3), 1.2)
			Art.line_c(ci, PackedVector2Array([Vector2(3, -7), Vector2(3, -1)]), Art.shade_of(CHOC, 0.3), 1.2)
			Art.flat(ci, Art.rrect_pts(Rect2(-7, -7, 4, 2), 1), Color(1, 1, 1, 0.35))
		_:
			idol(ci, 1.0)


## A little golden idol (origin bottom center, ~14 tall at s 1).
static func idol(ci: CanvasItem, s: float) -> void:
	Art.push(ci, Vector2.ZERO, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(-6, -6, 12, 6), 2, Art.GOLD_DARK, 1.6, 0.2)
	Art.t_rect(ci, Rect2(-5, -16, 10, 11), 3, Art.GOLD, 1.8, 0.4)
	Art.t_rect(ci, Rect2(-7, -18, 14, 4), 1.5, Art.GOLD, 1.6, 0.2)
	Art.disc(ci, Vector2(-2, -12), 1.1, Art.INK)
	Art.disc(ci, Vector2(2, -12), 1.1, Art.INK)
	Art.disc(ci, Vector2(0, -21), 2.2, JADE)
	Art.pop(ci)
