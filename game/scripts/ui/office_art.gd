class_name OfficeArt
extends RefCounted
## The office (room 3), drawn in local space with Art's toon kit. Every
## decor slot has 6 looks, level 0 (plain or empty) to 5 (grand):
##   wallpaper(ci, w, h, level)     floor_band(ci, w, y0, y1, level)
##   desk / sofa / aquarium / plant (origin on the floor, bottom center)
##   lamp (origin on the ceiling)   trophy (shelf center on the wall)
## Also the vault pile with its ceiling chute, the wardrobe closet, the
## evolution board and the porthole showing the world outside.
## BOX holds each piece's rough bounds (local, scale 1) for tap areas.

const BOX := {
	"desk": Rect2(-80, -130, 160, 132),
	"sofa": Rect2(-84, -96, 168, 98),
	"aquarium": Rect2(-62, -160, 124, 162),
	"plant": Rect2(-40, -150, 80, 152),
	"lamp": Rect2(-50, 0, 100, 130),
	"trophy": Rect2(-74, -70, 148, 100),
	"wardrobe": Rect2(-50, -200, 100, 202),
	"board": Rect2(-80, -66, 160, 132),
	"pile": Rect2(-96, -170, 192, 196),
}

const WALLS := [
	{"a": Color("eadfca"), "b": Color("dccfb6")},
	{"a": Color("f6d7a8"), "b": Color("eec894")},
	{"a": Color("c4ead9"), "b": Color("a9dcc6")},
	{"a": Color("bcd8f6"), "b": Color("9fc4ee")},
	{"a": Color("4fb8b0"), "b": Color("3fa29b")},
	{"a": Color("7a4fc4"), "b": Color("6a40b0")},
]


# --- Wall and floor ----------------------------------------------------------------------

## The back wall from y 0 to h, `w` wide.
static func wallpaper(ci: CanvasItem, w: float, h: float, level: int) -> void:
	var lv := clampi(level, 0, 5)
	var a: Color = WALLS[lv]["a"]
	var b: Color = WALLS[lv]["b"]
	Art.flat(ci, Art.rrect_pts(Rect2(0, 0, w, h), 0.0), a)
	match lv:
		0:
			# Bare plaster: a few cracks and a stain.
			for c: Vector2 in [Vector2(0.18, 0.3), Vector2(0.7, 0.2), Vector2(0.45, 0.62)]:
				var p := Vector2(c.x * w, c.y * h)
				Art.line_c(ci, PackedVector2Array([p, p + Vector2(10, 12), p + Vector2(6, 24), p + Vector2(14, 34)]), b.darkened(0.15), 2.0)
			Art.flat(ci, Art.ellipse_pts(Vector2(w * 0.85, h * 0.55), Vector2(26, 18), 14), Color(0.5, 0.45, 0.35, 0.12))
		1:
			pass
		2:
			var x := 0.0
			while x < w:
				Art.flat(ci, Art.rrect_pts(Rect2(x, 0, 18, h), 0.0), b)
				x += 36.0
		3:
			var y := 24.0
			var row := 0
			while y < h * 0.62:
				var x := 20.0 + (row % 2) * 30.0
				while x < w:
					Art.flat(ci, PackedVector2Array([Vector2(x, y - 7), Vector2(x + 7, y), Vector2(x, y + 7), Vector2(x - 7, y)]), b)
					x += 60.0
				y += 34.0
				row += 1
		4:
			var y := 28.0
			var row := 0
			while y < h * 0.62:
				var x := 24.0 + (row % 2) * 36.0
				while x < w:
					Art.flat(ci, Art.ellipse_pts(Vector2(x, y), Vector2(6, 9), 10), b)
					Art.flat(ci, Art.ellipse_pts(Vector2(x - 9, y + 6), Vector2(4, 3), 8, 0.6), b)
					Art.flat(ci, Art.ellipse_pts(Vector2(x + 9, y + 6), Vector2(4, 3), 8, -0.6), b)
					x += 72.0
				y += 44.0
				row += 1
		5:
			var y := 30.0
			var row := 0
			while y < h * 0.62:
				var x := 26.0 + (row % 2) * 40.0
				while x < w:
					Art.flat(ci, Art.star_pts(Vector2(x, y), 8, 3.5, 5), Color("ffd86a", 0.75))
					x += 80.0
				y += 46.0
				row += 1
	if lv >= 1:
		# Baseboard.
		Art.t_rect(ci, Rect2(-4, h - 14, w + 8, 14), 0.0, Art.WOOD if lv < 5 else Color("4a2a5a"), 2.4, 0.3)
	if lv >= 2:
		# Chair rail.
		Art.t_rect(ci, Rect2(-4, h * 0.62, w + 8, 8), 0.0, Art.CREAM if lv < 5 else Art.GOLD, 2.2, 0.2)
	if lv >= 3:
		# Wood wainscot below the rail.
		var wc := Art.WOOD if lv == 3 else (Color("8e552c") if lv == 4 else Color("5a2f6a"))
		Art.flat(ci, Art.rrect_pts(Rect2(0, h * 0.62 + 8, w, h * 0.38 - 22), 0.0), wc)
		var x := 14.0
		while x < w - 40.0:
			Art.ring(ci, Art.rrect_pts(Rect2(x, h * 0.62 + 18, 52, h * 0.38 - 44), 4), Art.shade_of(wc, 0.3) if lv < 5 else Art.GOLD, 2.0)
			x += 66.0
	if lv >= 4:
		# Crown molding.
		Art.t_rect(ci, Rect2(-4, 0, w + 8, 14), 0.0, Art.CREAM if lv == 4 else Art.GOLD, 2.4, 0.4)
	_room_light(ci, w, 0.0, h, 0.16)


## Room lighting over a wall or floor band: soft shade at the top (under
## the ceiling or against the wall), clearer towards the bottom, and darker
## corners at the sides.
static func _room_light(ci: CanvasItem, w: float, y0: float, y1: float, strength: float) -> void:
	var dark := Color(Art.SHADE, strength)
	var clear := Color(Art.SHADE, 0.0)
	var mid := y0 + (y1 - y0) * 0.45
	Art.grad(ci, PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, mid), Vector2(0, mid)]), PackedColorArray([dark, dark, clear, clear]))
	var side := minf(w * 0.14, 90.0)
	Art.grad(ci, PackedVector2Array([Vector2(0, y0), Vector2(side, y0), Vector2(side, y1), Vector2(0, y1)]), PackedColorArray([dark, clear, clear, dark]))
	Art.grad(ci, PackedVector2Array([Vector2(w - side, y0), Vector2(w, y0), Vector2(w, y1), Vector2(w - side, y1)]), PackedColorArray([clear, dark, dark, clear]))


const FLOORS := [Color("c2a98a"), Color("d39a62"), Color("c9874b"), Color("f3ead6"), Color("b9773f"), Color("f4f1f8")]


## The floor band from y0 (wall foot) to y1, `w` wide.
static func floor_band(ci: CanvasItem, w: float, y0: float, y1: float, level: int) -> void:
	var lv := clampi(level, 0, 5)
	var c: Color = FLOORS[lv]
	Art.flat(ci, Art.rrect_pts(Rect2(0, y0, w, y1 - y0), 0.0), c)
	var dk := Art.shade_of(c, 0.22)
	match lv:
		0:
			for p: Vector2 in [Vector2(0.2, 0.4), Vector2(0.65, 0.7), Vector2(0.85, 0.3)]:
				var a := Vector2(p.x * w, y0 + p.y * (y1 - y0))
				Art.line_c(ci, PackedVector2Array([a, a + Vector2(18, 4), a + Vector2(26, 14)]), dk, 2.0)
		1, 2:
			var y := y0 + 16.0
			var k := 0
			while y < y1:
				Art.line_c(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y)]), dk, 2.0)
				var x := fmod(k * 53.0, 120.0)
				while x < w:
					Art.line_c(ci, PackedVector2Array([Vector2(x, y - 16 - k * 1.5), Vector2(x, y)]), dk, 2.0)
					x += 120.0
				y += 18.0 + k * 3.0
				k += 1
			if lv == 2:
				# Varnish shine.
				Art.flat(ci, Art.ellipse_pts(Vector2(w * 0.5, y0 + (y1 - y0) * 0.45), Vector2(w * 0.3, 10), 20), Color(1, 1, 1, 0.18))
		3:
			var size := 34.0
			var y := y0
			var r := 0
			while y < y1:
				var x := -fmod(r * 17.0, size)
				var i := r
				while x < w:
					if i % 2 == 0:
						Art.flat(ci, Art.rrect_pts(Rect2(x, y, size, minf(size, y1 - y)), 0.0), Color("4fb0a8"))
					x += size
					i += 1
				y += size
				r += 1
		4:
			var y := y0
			var r := 0
			while y < y1:
				var x := -40.0 + (r % 2) * 20.0
				while x < w:
					Art.line_c(ci, PackedVector2Array([Vector2(x, y + 18), Vector2(x + 20, y)]), dk, 2.0)
					Art.line_c(ci, PackedVector2Array([Vector2(x + 20, y), Vector2(x + 40, y + 18)]), dk, 2.0)
					x += 40.0
				y += 18.0
				r += 1
		5:
			# Marble with soft veins and a gold border.
			for i in 7:
				var a := Vector2(fmod(i * 157.0, w), y0 + fmod(i * 41.0, y1 - y0))
				Art.line_c(ci, PackedVector2Array([a, a + Vector2(30, 10), a + Vector2(46, 4), a + Vector2(70, 16)]), Color("d8d0e8"), 2.0)
			Art.flat(ci, Art.rrect_pts(Rect2(0, y0 + 4, w, 4), 0.0), Art.GOLD)
	_room_light(ci, w, y0, y1, 0.2)
	Art.line_c(ci, PackedVector2Array([Vector2(0, y0), Vector2(w, y0)]), Art.INK, 3.0)


## A rug on the floor (floor levels 2, 4 and 5), centered at `c`.
static func rug(ci: CanvasItem, c: Vector2, half: Vector2, level: int) -> void:
	match level:
		2:
			Art.t_ellipse(ci, c, half * 0.7, Color("e86a6a"), 2.4, 0.2)
			Art.ring(ci, Art.ellipse_pts(c, half * 0.55, 24), Color("ffd0a0"), 2.0)
		4:
			Art.t_ellipse(ci, c, half, Color("3a6fd0"), 2.6, 0.2)
			Art.ring(ci, Art.ellipse_pts(c, half * 0.8, 28), Art.GOLD, 2.4)
			Art.ring(ci, Art.ellipse_pts(c, half * 0.45, 20), Color("8fd0ff"), 2.0)
		5:
			Art.t_rect(ci, Rect2(c - half, half * 2.0), 6, Color("c8243a"), 2.6, 0.2)
			Art.ring(ci, Art.rrect_pts(Rect2(c - half + Vector2(8, 5), half * 2.0 - Vector2(16, 10)), 4), Art.GOLD, 3.0)


# --- Furniture ----------------------------------------------------------------------------

static func _legs4(ci: CanvasItem, xs: Array, top: float, color: Color, w: float = 7.0) -> void:
	for x in xs:
		Art.t_rect(ci, Rect2(float(x) - w / 2.0, top, w, -top), 2, color, 2.0, 0.0)


## Chair behind the desk (drawn before the sitter).
static func chair(ci: CanvasItem, level: int) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		Art.t_rect(ci, Rect2(-16, -40, 32, 8), 3, Art.WOOD, 2.4, 0.3)
		_legs4(ci, [-12, 12], -32, Art.WOOD_DARK, 5)
		return
	var c := Art.WOOD if lv <= 2 else (Color("3a3f5c") if lv <= 4 else Color("b0243a"))
	var back_h := 70.0 if lv < 5 else 96.0
	Art.t_rect(ci, Rect2(-24, -40 - back_h, 48, back_h), 12 if lv >= 3 else 4, c, 2.8, 0.4)
	if lv == 5:
		Art.toon(ci, Art.star_pts(Vector2(0, -40 - back_h - 2), 10, 4, 5), Art.GOLD, 2.0, 0.3)


## Desk: 0 a crate, 1 a table, 2 drawers, 3 a computer, 4 executive, 5 gold.
static func desk(ci: CanvasItem, level: int, t: float) -> void:
	var lv := clampi(level, 0, 5)
	match lv:
		0:
			Art.t_rect(ci, Rect2(-52, -54, 104, 54), 3, Art.WOOD, 2.8, 0.5)
			Art.line_c(ci, PackedVector2Array([Vector2(-50, -27), Vector2(50, -27)]), Art.WOOD_DARK, 2.0)
			Art.line_c(ci, PackedVector2Array([Vector2(-48, -52), Vector2(48, -2)]), Art.WOOD_DARK, 2.0)
			Art.t_rect(ci, Rect2(-24, -70, 34, 16), 2, Color("c7a06a"), 2.2, 0.3)
		1:
			Art.t_rect(ci, Rect2(-66, -62, 132, 12), 3, Art.WOOD, 2.8, 0.4)
			_legs4(ci, [-58, 58], -50, Art.WOOD_DARK)
			_papers(ci, Vector2(-30, -62))
		2:
			Art.t_rect(ci, Rect2(-70, -64, 140, 12), 3, Color("b06a3a"), 2.8, 0.4)
			Art.t_rect(ci, Rect2(20, -52, 46, 52), 3, Color("9a5a2e"), 2.6, 0.4)
			for y: float in [-44.0, -26.0]:
				Art.t_rect(ci, Rect2(32, y, 22, 6), 2, Art.GOLD, 1.6, 0.0)
			_legs4(ci, [-62], -52, Color("7a4320"))
			_papers(ci, Vector2(-40, -64))
			Art.t_rect(ci, Rect2(-8, -78, 14, 14), 3, Art.CORAL, 2.0, 0.3)
		3, 4, 5:
			var top := Color("8a6a4a") if lv == 3 else (Color("5a3220") if lv == 4 else Color("fff3d8"))
			var front := Art.shade_of(top, 0.12)
			var trim := Art.GOLD if lv == 5 else Art.shade_of(top, 0.35)
			Art.t_rect(ci, Rect2(-76, -66, 152, 66), 5, front, 3.0, 0.5)
			Art.t_rect(ci, Rect2(-80, -72, 160, 12), 4, top, 2.8, 0.3)
			Art.ring(ci, Art.rrect_pts(Rect2(-64, -52, 128, 44), 4), trim, 2.4)
			# Monitor(s).
			var screens := 2 if lv == 5 else 1
			for i in screens:
				var x := (14.0 if screens == 1 else -2.0 + i * 50.0)
				Art.t_rect(ci, Rect2(x + 14, -82, 8, 12), 1, Color("5a5f7a"), 1.8, 0.0)
				Art.t_rect(ci, Rect2(x - 6, -116, 48, 36), 4, Color("2a2f4a"), 2.6, 0.0)
				Art.flat(ci, Art.rrect_pts(Rect2(x - 2, -112, 40, 28), 2), Color("5ad2ff"))
				# A little chart going up.
				Art.line_c(ci, PackedVector2Array([Vector2(x + 2, -90), Vector2(x + 14, -96), Vector2(x + 22, -93), Vector2(x + 34, -106)]), Art.WHITE, 2.4)
			if lv == 4:
				# Green banker's lamp.
				Art.t_rect(ci, Rect2(-62, -86, 4, 16), 1, Art.GOLD, 1.6, 0.0)
				Art.toon(ci, PackedVector2Array([Vector2(-76, -88), Vector2(-44, -88), Vector2(-48, -98), Vector2(-72, -98)]), Color("2f9a45"), 2.2, 0.4)
				Props.halo(ci, Vector2(-60, -80), 26, Color(1, 0.9, 0.5, 0.35))
			if lv == 5:
				# A globe.
				Art.t_rect(ci, Rect2(-64, -78, 4, 8), 1, Art.GOLD, 1.4, 0.0)
				Art.t_circle(ci, Vector2(-62, -92), 13, Color("3aa6f0"), 2.4, 0.4)
				Art.flat(ci, Art.ellipse_pts(Vector2(-66, -94), Vector2(6, 4), 10, 0.4), Art.GREEN)
				Art.arc_c(ci, Vector2(-62, -92), 17, PI * 0.7, PI * 2.3, 14, Art.GOLD, 2.4)
			else:
				# A mug.
				Art.t_rect(ci, Rect2(-66, -84, 14, 14), 3, Art.WHITE, 2.0, 0.2)
				Art.arc_c(ci, Vector2(-50, -77), 4, -PI / 2, PI / 2, 6, Art.INK, 2.0)


static func _papers(ci: CanvasItem, at: Vector2) -> void:
	Art.t_rect(ci, Rect2(at.x - 14, at.y - 6, 28, 6), 1, Art.WHITE, 1.8, 0.0)
	Art.t_rect(ci, Rect2(at.x - 12, at.y - 11, 26, 5), 1, Color("f4f0e6"), 1.8, 0.0)


## Sofa: 0 a bench, 1 a small couch, 2 cushions, 3 big, 4 chesterfield, 5 royal.
static func sofa(ci: CanvasItem, level: int) -> void:
	if clampi(level, 0, 5) == 0:
		spot(ci, "sofa")
		return
	var lv := clampi(level, 0, 5)
	if lv == 0:
		Art.t_rect(ci, Rect2(-64, -40, 128, 12), 3, Art.WOOD, 2.8, 0.4)
		_legs4(ci, [-54, 54], -28, Art.WOOD_DARK)
		return
	var c: Color = [Color(), Color("e8c89a"), Color("2bb8b4"), Color("ff8a5c"), Color("8e4a2a"), Color("8a3cc8")][lv]
	var half := 62.0 + lv * 4.0
	var back_h := 50.0 + lv * 4.0
	if lv >= 2:
		_legs4(ci, [-half + 8, half - 8], -12, Art.GOLD if lv == 5 else Art.WOOD_DARK, 6)
	Art.t_rect(ci, Rect2(-half + 6, -24 - back_h, half * 2.0 - 12, back_h), 16, c, 3.0, 0.5)
	if lv == 4:
		for i in 5:
			for j in 2:
				Art.disc(ci, Vector2(-half + 26 + i * (half * 2.0 - 52) / 4.0, -back_h - 4 + j * 18), 2.4, Art.shade_of(c, 0.35))
	if lv == 5:
		Art.toon(ci, PackedVector2Array([Vector2(-16, -24 - back_h), Vector2(-10, -38 - back_h), Vector2(0, -28 - back_h),
				Vector2(10, -38 - back_h), Vector2(16, -24 - back_h)]), Art.GOLD, 2.4, 0.3)
	Art.t_rect(ci, Rect2(-half + 14, -36, half * 2.0 - 28, 24), 8, c.lightened(0.12), 2.8, 0.4)
	for x: float in [-half, half - 22]:
		Art.t_rect(ci, Rect2(x, -52, 22, 42), 10, c, 2.8, 0.5)
	if lv >= 2:
		var pc: Color = [Art.GOLD, Art.CORAL, Color("ffe38a"), Color("ff6fa8"), Art.GOLD][lv - 1]
		Art.push(ci, Vector2(-half + 38, -48), -0.25)
		Art.t_rect(ci, Rect2(-14, -14, 28, 28), 8, pc, 2.4, 0.4)
		Art.pop(ci)
		if lv >= 3:
			Art.push(ci, Vector2(half - 40, -48), 0.25)
			Art.t_rect(ci, Rect2(-14, -14, 28, 28), 8, Color("8fd0ff") if lv < 5 else Art.GOLD, 2.4, 0.4)
			Art.pop(ci)


## Aquarium: 0 an empty bowl ... 5 a grand glowing tank. `t` swims the fish.
static func aquarium(ci: CanvasItem, level: int, t: float) -> void:
	if clampi(level, 0, 5) == 0:
		spot(ci, "aquarium")
		return
	var lv := clampi(level, 0, 5)
	if lv <= 1:
		# Stool and a round bowl.
		Art.t_rect(ci, Rect2(-24, -54, 48, 10), 3, Art.WOOD, 2.6, 0.3)
		_legs4(ci, [-18, 18], -44, Art.WOOD_DARK, 6)
		var c := Vector2(0, -88)
		Art.flat(ci, Art.circle_pts(c, 34, 28), Color(0.75, 0.93, 1.0, 0.45))
		Art.flat(ci, PackedVector2Array([c + Vector2(-31, -6), c + Vector2(31, -6), c + Vector2(24, 22), c + Vector2(-24, 22)]), Color(0.35, 0.75, 0.95, 0.55))
		if lv == 1:
			Art.fish(ci, c + Vector2(sin(t * 0.9) * 14.0, 6), 10, Color("ff9a3c"), clampf(cos(t * 0.9) * 3.0, -1.0, 1.0), t)
		Art.arc_c(ci, c, 34, -PI * 0.15, PI * 1.15, 24, Art.INK, 3.0)
		Art.arc_c(ci, c, 26, PI * 1.15, PI * 1.4, 6, Color(1, 1, 1, 0.8), 3.0)
		Art.line_c(ci, PackedVector2Array([c + Vector2(-18, -28), c + Vector2(18, -28)]), Art.INK, 3.0)
		return
	var hw := 40.0 + (lv - 2) * 10.0
	var th := 70.0 + (lv - 2) * 12.0
	var stand := 60.0
	var frame := Art.WOOD_DARK if lv < 5 else Art.GOLD
	# Cabinet.
	Art.t_rect(ci, Rect2(-hw - 4, -stand, hw * 2.0 + 8, stand), 4, Art.WOOD if lv < 5 else Color("4a2a5a"), 2.8, 0.4)
	Art.ring(ci, Art.rrect_pts(Rect2(-hw + 6, -stand + 10, hw * 2.0 - 12, stand - 20), 3), Art.shade_of(Art.WOOD, 0.3) if lv < 5 else Art.GOLD, 2.0)
	var r := Rect2(-hw, -stand - th, hw * 2.0, th)
	if lv >= 4:
		Props.halo(ci, r.get_center(), hw * 1.6, Color(0.4, 0.85, 1.0, 0.25))
	Art.grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color("7fe0ff"), Color("7fe0ff"), Color("1f8ac0"), Color("1f8ac0")]))
	# Sand, plants, decorations.
	Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, r.end.y - 12, r.size.x, 12), 0.0), Art.SAND)
	Art.seaweed(ci, Vector2(r.position.x + 12, r.end.y - 6), th * 0.6, Art.GREEN, t, 1.0, 6.0)
	if lv >= 3:
		Art.seaweed(ci, Vector2(r.end.x - 14, r.end.y - 6), th * 0.5, Color("3ee08f"), t, 2.0, 6.0)
		# Castle.
		var cx := r.position.x + r.size.x * 0.66
		Art.t_rect(ci, Rect2(cx - 12, r.end.y - 34, 24, 26), 2, Color("c9b8e8"), 2.0, 0.3)
		Art.t_rect(ci, Rect2(cx - 4, r.end.y - 22, 8, 14), 3, Color("3a3060"), 1.6, 0.0)
	if lv >= 4:
		for k in 3:
			Art.crystal(ci, Vector2(r.position.x + 30 + k * 10, r.end.y - 8), 14 + k * 4, 4, -0.3 + k * 0.3, Color("ff7ab8"), 1.8)
	if lv >= 5:
		Art.t_rect(ci, Rect2(r.position.x + 18, r.end.y - 26, 26, 18), 3, Art.WOOD, 2.0, 0.3)
		Art.t_rect(ci, Rect2(r.position.x + 16, r.end.y - 32, 30, 8), 3, Art.GOLD, 2.0, 0.3)
	# Fish.
	var n: int = [0, 0, 2, 3, 5, 6][lv]
	var cols := [Color("ff9a3c"), Color("ffd23f"), Color("ff6fa8"), Color("5ad2ff"), Color("8a6cf0"), Color("5cd05f")]
	for i in n:
		var sp := 0.5 + i * 0.13
		var ph := t * sp + i * 1.7
		var p := r.get_center() + Vector2(sin(ph) * (hw - 16), -th * 0.25 + fmod(i * 23.0, th * 0.55))
		Art.fish(ci, p, 9 + (i % 2) * 3, cols[i], clampf(cos(ph) * 3.0, -1.0, 1.0), t + i)
	if lv >= 5:
		# A jellyfish bobbing.
		var jp := r.position + Vector2(r.size.x * 0.3, th * 0.35 + sin(t * 1.3) * 6.0)
		Art.push(ci, jp)
		Art.toon(ci, PackedVector2Array([Vector2(-11, 4), Vector2(-10, -6), Vector2(0, -12), Vector2(10, -6), Vector2(11, 4)]), Color("ffb0e0"), 2.0, 0.3)
		for k in 3:
			Art.line_c(ci, PackedVector2Array([Vector2(-6 + k * 6, 4), Vector2(-8 + k * 6, 12), Vector2(-5 + k * 6, 18)]), Color("ffb0e0"), 2.0)
		Art.pop(ci)
	# Bubbles.
	for i in 3:
		var f := fposmod(t * 0.4 + i * 0.33, 1.0)
		Art.dot(ci, Vector2(r.position.x + 20 + i * 9, r.end.y - 14 - f * (th - 20)), 2.0 + i * 0.5, Color(1, 1, 1, 0.7 * (1.0 - f)))
	# Glass glint and frame.
	Art.flat(ci, PackedVector2Array([r.position + Vector2(8, 4), r.position + Vector2(18, 4), r.position + Vector2(8, th - 8), r.position + Vector2(-0.0, th - 8)]), Color(1, 1, 1, 0.25))
	Art.ring(ci, Art.rrect_pts(r, 4), Art.INK, 3.0)
	Art.t_rect(ci, Rect2(r.position.x - 4, r.position.y - 8, r.size.x + 8, 10), 3, frame, 2.6, 0.3)
	if lv >= 4:
		Art.t_rect(ci, Rect2(-14, r.position.y - 14, 28, 8), 2, Color("5a5f7a"), 2.0, 0.0)


## Lamp hanging from the ceiling (origin): 0 a bare bulb ... 5 a crystal chandelier.
static func lamp(ci: CanvasItem, level: int, t: float, light: bool = true) -> void:
	if clampi(level, 0, 5) == 0:
		spot(ci, "lamp")
		return
	var lv := clampi(level, 0, 5)
	var cord: float = [70.0, 62.0, 56.0, 50.0, 40.0, 36.0][lv]
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, cord)]), Art.INK, 2.5)
	var warm := Color(1.0, 0.85, 0.5, [0.18, 0.25, 0.3, 0.34, 0.4, 0.5][lv])
	if light:
		Props.halo(ci, Vector2(0, cord + 18), 50 + lv * 14.0, warm)
	match lv:
		0:
			Art.t_rect(ci, Rect2(-4, cord, 8, 6), 1, Color("5a5f7a"), 1.6, 0.0)
			Art.t_circle(ci, Vector2(0, cord + 13), 8, Color("fff3c4"), 2.2, 0.0)
		1:
			Art.toon(ci, PackedVector2Array([Vector2(-6, cord), Vector2(6, cord), Vector2(20, cord + 18), Vector2(-20, cord + 18)]), Color("e8e0d0"), 2.6, 0.4)
			Art.t_circle(ci, Vector2(0, cord + 19), 6, Color("fff3c4"), 2.0, 0.0)
		2:
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-26, cord + 20), Vector2(-18, cord + 4), Vector2(0, cord - 2), Vector2(18, cord + 4), Vector2(26, cord + 20)]), 3), Color("ffb13b"), 2.6, 0.5)
			Art.t_circle(ci, Vector2(0, cord + 21), 7, Color("fff3c4"), 2.0, 0.0)
		3:
			Art.t_rect(ci, Rect2(-30, cord, 60, 28), 8, Color("2bb8b4"), 2.8, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(-26, cord + 20, 52, 4), 2), Color("ffe38a"))
		4, 5:
			var c := Art.GOLD
			Art.t_circle(ci, Vector2(0, cord + 10), 8, c, 2.4, 0.4)
			var arms := 3 if lv == 4 else 5
			for i in arms:
				var x := (i - (arms - 1) / 2.0) * (26.0 if lv == 4 else 20.0)
				Art.stroke(ci, PackedVector2Array([Vector2(0, cord + 12), Vector2(x, cord + 24), Vector2(x, cord + 16)]), c, 3.5, 1.8)
				Art.t_rect(ci, Rect2(x - 4, cord + 4, 8, 12), 2, Art.CREAM, 1.8, 0.0)
				Art.dot(ci, Vector2(x, cord + 1), 3.5 + sin(t * 9.0 + i) * 0.4, Color("ffe38a"))
			if lv == 5:
				for i in 6:
					var x := -30.0 + i * 12.0
					Art.crystal(ci, Vector2(x, cord + 26), 12, 3.5, PI, Color("d8f4ff"), 1.6)
				for i in 3:
					var ph := fposmod(t * 0.7 + i * 0.33, 1.0)
					Art.dot(ci, Vector2(-36 + i * 36, cord + 30 + ph * 12), 2.5 * (1.0 - ph), Color(1, 1, 1, 1.0 - ph))


## Trophy shelf on the wall (origin at its middle): 0 an empty plank ... 5 a
## glass cabinet of gold.
static func trophy(ci: CanvasItem, level: int, t: float) -> void:
	if clampi(level, 0, 5) == 0:
		spot(ci, "trophy")
		return
	var lv := clampi(level, 0, 5)
	var wood := Art.WOOD if lv < 4 else Color("6a3a22")
	if lv == 5:
		Art.t_rect(ci, Rect2(-72, -68, 144, 96), 6, Color("4a2a5a"), 3.0, 0.3)
		Art.flat(ci, Art.rrect_pts(Rect2(-64, -60, 128, 80), 4), Color(0.8, 0.9, 1.0, 0.35))
	if lv == 4:
		Art.t_rect(ci, Rect2(-70, -60, 140, 82), 4, Color("8e552c"), 3.0, 0.2)
	# Planks.
	var planks := [18.0] if lv < 3 else [18.0, -24.0]
	for y in planks:
		Art.t_rect(ci, Rect2(-66, float(y), 132, 9), 2, wood if lv < 5 else Art.GOLD, 2.6, 0.3)
	if lv <= 2:
		for x: float in [-46.0, 46.0]:
			Art.toon(ci, PackedVector2Array([Vector2(x - 4, 27), Vector2(x + 4, 27), Vector2(x + 4, 38), Vector2(x - 4, 30)]), Art.WOOD_DARK, 1.8, 0.0)
	match lv:
		1:
			_cup(ci, Vector2(0, 18), 0.7, Color("d08a4a"))
		2:
			_cup(ci, Vector2(-28, 18), 0.8, Color("cfd8e6"))
			_cup(ci, Vector2(26, 18), 0.65, Color("d08a4a"))
		3:
			_cup(ci, Vector2(-34, 18), 0.95, Art.GOLD)
			_medal(ci, Vector2(20, 2))
			_books(ci, Vector2(30, -24))
			_cup(ci, Vector2(-30, -24), 0.6, Color("cfd8e6"))
		4:
			_cup(ci, Vector2(-38, 18), 0.9, Color("cfd8e6"))
			_cup(ci, Vector2(0, 18), 1.1, Art.GOLD)
			_cup(ci, Vector2(38, 18), 0.75, Color("d08a4a"))
			_books(ci, Vector2(-34, -24))
			Art.t_rect(ci, Rect2(12, -52, 36, 28), 3, Color("35507e"), 2.2, 0.2)
			Art.toon(ci, Art.star_pts(Vector2(30, -38), 10, 4.5, 5), Art.GOLD, 1.8, 0.3)
		5:
			_cup(ci, Vector2(0, 18), 1.4, Art.GOLD)
			_cup(ci, Vector2(-44, 18), 0.8, Art.GOLD)
			_cup(ci, Vector2(44, 18), 0.8, Art.GOLD)
			_medal(ci, Vector2(-36, -40))
			_medal(ci, Vector2(36, -40))
			Art.toon(ci, Art.star_pts(Vector2(0, -42), 12, 5, 5), Art.GOLD, 2.0, 0.3)
			var ph := fposmod(t * 0.8, 1.0)
			Art.dot(ci, Vector2(-20 + ph * 10, -10), 3.0 * (1.0 - ph), Color(1, 1, 0.8, 1.0 - ph))
			Art.dot(ci, Vector2(24, -20 - ph * 8), 2.6 * ph, Color(1, 1, 0.8, ph))


static func _cup(ci: CanvasItem, base: Vector2, s: float, c: Color) -> void:
	Art.push(ci, base, 0.0, Vector2(s, s))
	Art.t_rect(ci, Rect2(-12, -8, 24, 8), 2, Color("5a3a2a"), 2.0, 0.2)
	Art.t_rect(ci, Rect2(-3, -18, 6, 10), 1, c, 1.8, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-14, -40), Vector2(14, -40), Vector2(10, -24), Vector2(4, -18), Vector2(-4, -18), Vector2(-10, -24)]), c, 2.2, 0.5)
	Art.arc_c(ci, Vector2(-14, -32), 6, PI * 0.5, PI * 1.5, 6, Art.INK, 2.0)
	Art.arc_c(ci, Vector2(14, -32), 6, -PI * 0.5, PI * 0.5, 6, Art.INK, 2.0)
	Art.pop(ci)


static func _medal(ci: CanvasItem, at: Vector2) -> void:
	Art.toon(ci, PackedVector2Array([at + Vector2(-6, -16), at + Vector2(6, -16), at + Vector2(3, -2), at + Vector2(-3, -2)]), Art.RED, 1.6, 0.0)
	Art.t_circle(ci, at + Vector2(0, 4), 7, Art.GOLD, 2.0, 0.3)


static func _books(ci: CanvasItem, base: Vector2) -> void:
	var cols := [Art.RED, Color("3aa6f0"), Art.GREEN]
	for i in 3:
		Art.t_rect(ci, Rect2(base.x - 12 + i * 8, base.y - 22 + i * 2, 8, 22 - i * 2), 1, cols[i], 1.6, 0.2)


## Potted plant: 0 an empty pot ... 5 a flowering tree in a gold pot.
static func plant(ci: CanvasItem, level: int, t: float) -> void:
	if clampi(level, 0, 5) == 0:
		spot(ci, "plant")
		return
	var lv := clampi(level, 0, 5)
	var sway := sin(t * 1.3) * 0.04
	var pot: Color = [Color("c8704a"), Color("c8704a"), Color("e8e0d0"), Color("3aa6f0"), Color("2bb8b4"), Art.GOLD][lv]
	var pw := 22.0 + lv * 2.0
	Art.push(ci, Vector2(0, -34), sway)
	match lv:
		1:
			Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(0, -14)]), Art.GREEN_DARK, 3.0, 1.6)
			Art.t_ellipse(ci, Vector2(-7, -16), Vector2(8, 4), Art.GREEN, 2.0, 0.3, -0.4)
			Art.t_ellipse(ci, Vector2(7, -18), Vector2(8, 4), Art.GREEN, 2.0, 0.3, 0.4)
		2:
			for a: float in [-0.7, -0.25, 0.2, 0.65]:
				Art.push(ci, Vector2.ZERO, a)
				Art.t_ellipse(ci, Vector2(0, -24), Vector2(7, 20), Art.GREEN, 2.2, 0.4)
				Art.pop(ci)
		3:
			var blob := Art.union([Art.circle_pts(Vector2(-14, -30), 18, 16), Art.circle_pts(Vector2(12, -34), 19, 16), Art.circle_pts(Vector2(0, -52), 18, 16)])
			Art.toon(ci, blob, Art.GREEN, 2.8, 0.6)
			for p: Vector2 in [Vector2(-10, -36), Vector2(8, -50), Vector2(14, -30)]:
				Art.flat(ci, Art.ellipse_pts(p, Vector2(4, 2), 8, 0.5), Art.GREEN_DARK)
		4:
			Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(-2, -40), Vector2(2, -80)]), Art.WOOD, 7.0, 2.2)
			for a: float in [-2.6, -2.0, -1.2, -0.6, 0.0]:
				Art.push(ci, Vector2(2, -82), a + PI / 2.0)
				Art.t_ellipse(ci, Vector2(0, -26), Vector2(9, 28), Color("3cbf5a"), 2.4, 0.4)
				Art.pop(ci)
		5:
			Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(0, -60)]), Art.WOOD, 8.0, 2.2)
			var crown := Art.union([Art.circle_pts(Vector2(-22, -70), 22, 18), Art.circle_pts(Vector2(20, -72), 22, 18),
					Art.circle_pts(Vector2(0, -94), 24, 18), Art.circle_pts(Vector2(0, -64), 20, 16)])
			Art.toon(ci, crown, Art.GREEN, 3.0, 0.6)
			for p: Vector2 in [Vector2(-24, -76), Vector2(10, -96), Vector2(24, -66), Vector2(-6, -62), Vector2(-10, -100)]:
				Art.toon(ci, Art.star_pts(p, 6, 3, 5), Color("ff8fc0"), 1.6, 0.0)
				Art.disc(ci, p, 1.8, Art.GOLD)
	Art.pop(ci)
	# The pot.
	Art.toon(ci, PackedVector2Array([Vector2(-pw, -38), Vector2(pw, -38), Vector2(pw - 6, 0), Vector2(-pw + 6, 0)]), pot, 2.8, 0.5)
	Art.t_rect(ci, Rect2(-pw - 3, -42, pw * 2.0 + 6, 9), 3, Art.shade_of(pot, 0.1), 2.4, 0.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -38), Vector2(pw - 4, 3), 12), Color("5a3a2a"))
	if lv == 5:
		var ph := fposmod(t * 0.6, 1.0)
		Art.dot(ci, Vector2(-30, -120 + ph * 20), 3.0 * (1.0 - ph), Color(1, 1, 0.7, 1.0 - ph))


# --- Room pieces ----------------------------------------------------------------------------

## The wardrobe closet (origin bottom center); `open` 0..1 swings the doors.
static func wardrobe(ci: CanvasItem, open: float, outfit_color: Color) -> void:
	var body := Color("a8643a")
	Art.t_rect(ci, Rect2(-48, -196, 96, 192), 6, body, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-52, -204, 104, 14), 4, Art.shade_of(body, 0.15), 2.8, 0.3)
	_legs4(ci, [-40, 40], -6, Art.WOOD_DARK, 8)
	var inside := Rect2(-42, -186, 84, 170)
	Art.flat(ci, Art.rrect_pts(inside, 3), Color("4a2a20"))
	# Clothes on the rail inside.
	Art.line_c(ci, PackedVector2Array([Vector2(-40, -170), Vector2(40, -170)]), Art.METAL, 3.0)
	var cols := [outfit_color, Art.CORAL, Color("3aa6f0"), Art.GOLD]
	for i in 4:
		var x := -30.0 + i * 20.0
		Art.toon(ci, PackedVector2Array([Vector2(x - 8, -164), Vector2(x + 8, -164), Vector2(x + 10, -110), Vector2(x - 10, -110)]), cols[i], 2.2, 0.4)
	var o := clampf(open, 0.0, 1.0)
	var dw := 42.0 * (1.0 - o * 0.75)
	for side: float in [-1.0, 1.0]:
		var x0 := -42.0 if side < 0 else 42.0 - dw
		Art.t_rect(ci, Rect2(x0, -186, dw, 170), 4, body.lightened(0.08), 2.8, 0.4)
		if dw > 20.0:
			Art.ring(ci, Art.rrect_pts(Rect2(x0 + 6, -176, dw - 12, 70), 3), Art.shade_of(body, 0.3), 2.0)
			Art.ring(ci, Art.rrect_pts(Rect2(x0 + 6, -98, dw - 12, 72), 3), Art.shade_of(body, 0.3), 2.0)
			var kx := x0 + dw - 7.0 if side < 0 else x0 + 7.0
			Art.t_circle(ci, Vector2(kx, -104), 3.5, Art.GOLD, 1.6, 0.0)
	# A hanger sign on top.
	Art.t_circle(ci, Vector2(0, -220), 14, Art.WHITE, 2.4, 0.2)
	Art.line_c(ci, PackedVector2Array([Vector2(-9, -214), Vector2(0, -222), Vector2(9, -214), Vector2(-9, -214)]), Art.INK, 2.2)
	Art.arc_c(ci, Vector2(0, -225), 3, PI, TAU * 1.25, 6, Art.INK, 2.0)


## Frame of the evolution board (origin center, 160 x 132); the room
## draws the worker forms inside.
static func board(ci: CanvasItem, glow: float) -> void:
	if glow > 0.01:
		Props.halo(ci, Vector2.ZERO, 120, Color(1.0, 0.85, 0.4, 0.35 * glow))
	Art.t_rect(ci, Rect2(-80, -66, 160, 132), 10, Color("5a3a2a"), 3.0, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-72, -58, 144, 116), 6), Color("27305a"))
	Art.flat(ci, Art.rrect_pts(Rect2(-72, -58, 144, 22), 6), Color("35507e"))


## A round porthole showing the world outside (origin center).
static func porthole(ci: CanvasItem, world: String) -> void:
	var lk := FactoryArt.look(world)
	Art.t_circle(ci, Vector2.ZERO, 34, Art.BRASS, 3.0, 0.4)
	var disc := Art.circle_pts(Vector2.ZERO, 31, 32)
	Art.flat(ci, disc, lk["sky"])
	Art.flat(ci, Art.clipped(Art.rrect_pts(Rect2(-32, -4, 64, 40), 0.0), disc), Color(lk["sky2"]).lerp(lk["sky"], 0.35))
	match str(lk["style"]):
		"planks":
			Art.flat(ci, Art.rrect_pts(Rect2(-26, 6, 52, 18), 4), Color("1c88b6"))
			Art.t_circle(ci, Vector2(10, -10), 7, Art.GOLD, 0.0, 0.0)
		"plates":
			Art.toon(ci, PackedVector2Array([Vector2(-22, 20), Vector2(0, -10), Vector2(22, 20)]), Color("4a3a48"), 0.0, 0.0)
			Art.flat(ci, PackedVector2Array([Vector2(-3, -8), Vector2(3, -8), Vector2(6, 20), Vector2(-4, 20)]), Color("ff7a2e"))
		"tiles":
			Art.flat(ci, Art.ellipse_pts(Vector2(-8, 16), Vector2(12, 8), 12), Color("ff6fa8"))
			Art.flat(ci, Art.ellipse_pts(Vector2(12, 18), Vector2(10, 7), 12), Color("b06ae0"))
		"panels":
			Art.t_circle(ci, Vector2(8, 8), 12, Color("5ab8ff"), 0.0, 0.0)
			for p: Vector2 in [Vector2(-14, -12), Vector2(4, -18), Vector2(-18, 8)]:
				Art.disc(ci, p, 1.6, Art.WHITE)
	Art.arc_c(ci, Vector2.ZERO, 31, 0, TAU, 32, Art.BRASS, 6.0)
	Art.arc_c(ci, Vector2.ZERO, 34, 0, TAU, 32, Art.INK, 3.0)
	Art.arc_c(ci, Vector2.ZERO, 22, PI * 1.1, PI * 1.4, 6, Color(1, 1, 1, 0.7), 3.0)
	for k in 8:
		Art.disc(ci, Vector2(31, 0).rotated(k * TAU / 8.0), 2.0, Art.shade_of(Art.BRASS, 0.35))


# --- Vault ------------------------------------------------------------------------------------

## The chute from the ceiling (y = top) down to the mouth at `mouth`
## (local), a glass tube with a brass funnel; `flap` 0..1 opens its flap.
static func chute(ci: CanvasItem, top: float, mouth: Vector2, flap: float) -> void:
	var r := Rect2(mouth.x - 13, top, 26, mouth.y - top - 20)
	Art.flat(ci, Art.rrect_pts(r, 0.0), Color(0.8, 0.96, 1.0, 0.45))
	Art.line_c(ci, PackedVector2Array([r.position, Vector2(r.position.x, r.end.y)]), Art.INK, 3.0)
	Art.line_c(ci, PackedVector2Array([Vector2(r.end.x, r.position.y), r.end]), Art.INK, 3.0)
	Art.line_c(ci, PackedVector2Array([r.position + Vector2(5, 0), Vector2(r.position.x + 5, r.end.y)]), Color(1, 1, 1, 0.6), 2.5)
	var y := top + 26.0
	while y < mouth.y - 30.0:
		Art.t_rect(ci, Rect2(mouth.x - 16, y, 32, 7), 2, Art.BRASS, 2.2, 0.2)
		y += 64.0
	Art.t_rect(ci, Rect2(mouth.x - 20, top - 4, 40, 12), 4, Art.BRASS, 2.6, 0.3)
	Art.toon(ci, PackedVector2Array([mouth + Vector2(-16, -24), mouth + Vector2(16, -24), mouth + Vector2(26, 0), mouth + Vector2(-26, 0)]), Art.BRASS, 3.0, 0.5)
	Art.push(ci, mouth + Vector2(-24, 0), Props._q(flap, 6) * 0.9)
	Art.t_rect(ci, Rect2(0, -3, 48, 6), 2, Art.shade_of(Art.BRASS, 0.2), 2.2, 0.0)
	Art.pop(ci)


## Coin pile (origin bottom center) for fill 0..1 (0 = the empty tray).
## Gold bars from 0.35, gems and a crown near the top.
static func pile(ci: CanvasItem, fill: float, t: float) -> void:
	var f := Props._q(fill, 12)
	# The vault tray: a low round metal dish with a coin mark.
	Art.t_ellipse(ci, Vector2(0, -8), Vector2(70, 14), Color("8d94a6"), 3.0, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -10), Vector2(60, 9), 24), Color("5a5f7a"))
	if f <= 0.0:
		Art.t_circle(ci, Vector2(0, -10), 7, Color("c9d2e2"), 2.0, 0.0)
		return
	var w := lerpf(26.0, 64.0, minf(1.0, f * 1.6))
	var h := lerpf(12.0, 86.0, f)
	var heap := Art.smooth_pts(PackedVector2Array([Vector2(-w, -8), Vector2(-w * 0.7, -h * 0.45 - 8), Vector2(-w * 0.25, -h - 6),
			Vector2(w * 0.25, -h - 4), Vector2(w * 0.72, -h * 0.4 - 8), Vector2(w, -8)]), 4)
	Art.toon(ci, heap, Art.GOLD, 3.0, 0.7)
	# Coins on the heap's face.
	var n := 3 + int(f * 12.0)
	for i in n:
		var u := fmod(i * 0.618, 1.0)
		var v := fmod(i * 0.38 + 0.2, 1.0)
		var x := (u * 2.0 - 1.0) * w * 0.8 * (1.0 - v * 0.6)
		var y := -10.0 - v * h * 0.85
		Art.push(ci, Vector2(x, y), 0.0, Vector2(1.0, 0.55))
		Art.coin(ci, Vector2.ZERO, 7.0 + (i % 3))
		Art.pop(ci)
	if f >= 0.35:
		var bars := 1 + int((f - 0.35) * 8.0)
		for i in mini(bars, 5):
			var p := Vector2(-w * 0.55 + i * w * 0.27, -14.0 - (i % 2) * 8.0)
			Art.toon(ci, PackedVector2Array([p + Vector2(-14, 0), p + Vector2(14, 0), p + Vector2(10, -10), p + Vector2(-10, -10)]), Color("ffd86a"), 2.4, 0.5)
			Art.flat(ci, Art.rrect_pts(Rect2(p.x - 6, p.y - 8, 6, 2), 1), Color(1, 1, 1, 0.8))
	if f >= 0.6:
		Art.crystal(ci, Vector2(-w * 0.3, -h * 0.6), 18, 6, -0.4, Color("ff5d73"), 2.0)
		Art.crystal(ci, Vector2(w * 0.4, -h * 0.5), 16, 6, 0.4, Color("3ee08f"), 2.0)
	if f >= 0.85:
		var c := Vector2(0, -h - 8)
		Art.toon(ci, PackedVector2Array([c + Vector2(-16, 6), c + Vector2(-18, -12), c + Vector2(-8, -4), c + Vector2(0, -16),
				c + Vector2(8, -4), c + Vector2(18, -12), c + Vector2(16, 6)]), Art.GOLD, 2.4, 0.4)
		Art.disc(ci, c + Vector2(0, -2), 2.5, Art.RED)
	# Twinkles.
	var ph := fposmod(t * 0.9, 1.0)
	Art.dot(ci, Vector2(-w * 0.3, -h * 0.7), 3.5 * sin(ph * PI), Color(1, 1, 1, 0.9))
	Art.dot(ci, Vector2(w * 0.35, -h * 0.35), 3.0 * sin(fposmod(ph + 0.5, 1.0) * PI), Color(1, 1, 1, 0.9))


## The big Collect button (origin center, `size`); `glow` 0..1 pulses it.
static func collect_button(ci: CanvasItem, size: Vector2, label: String, amount: String, active: bool, press: float) -> void:
	var r := Rect2(-size / 2.0, size)
	var c := Art.GREEN if active else Color("a8b0c0")
	Art.push(ci, Vector2(0, press * 3.0))
	Art.t_rect(ci, Rect2(r.position + Vector2(0, 5), r.size), size.y / 2.0, Art.shade_of(c, 0.35), 3.0, 0.0)
	Art.t_rect(ci, r, size.y / 2.0, c, 3.0, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(r.position + Vector2(14, 5), Vector2(size.x - 28, 6)), 3), Color(1, 1, 1, 0.35))
	var fs := int(size.y * 0.42)
	if amount != "":
		Art.text(ci, Vector2(0, -2), label, int(fs * 0.85), Art.WHITE, 5)
		Art.text(ci, Vector2(0, fs * 0.95), amount, int(fs * 0.85), Color("fff3a8"), 5)
	else:
		Art.text(ci, Vector2(0, fs * 0.36), label, fs, Art.WHITE, 5)
	Art.pop(ci)


# --- Build spots ------------------------------------------------------------------------------

## An empty decor slot (level 0): a dashed outline of the piece to come
## and a green "+" badge, so it reads as "build something here".
static func spot(ci: CanvasItem, slot: String) -> void:
	var b: Rect2 = BOX.get(slot, Rect2(-40, -80, 80, 80))
	if slot == "lamp":
		# A hook on the ceiling and a dashed shade under it.
		Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, 40)]), Art.INK_SOFT, 2.5)
		b = Rect2(-34, 44, 68, 44)
	elif slot != "trophy":
		Art.flat(ci, Art.ellipse_pts(Vector2(0, 0), Vector2(b.size.x * 0.42, 7), 18), Color(0, 0, 0, 0.12))
	b = b.grow(-6.0)
	var dash := Color(1, 1, 1, 0.75)
	var x := b.position.x
	while x < b.end.x - 4.0:
		var w := minf(10.0, b.end.x - x)
		Art.flat(ci, Art.rrect_pts(Rect2(x, b.position.y - 1.5, w, 3), 1.5), dash)
		Art.flat(ci, Art.rrect_pts(Rect2(x, b.end.y - 1.5, w, 3), 1.5), dash)
		x += 18.0
	var y := b.position.y
	while y < b.end.y - 4.0:
		var h := minf(10.0, b.end.y - y)
		Art.flat(ci, Art.rrect_pts(Rect2(b.position.x - 1.5, y, 3, h), 1.5), dash)
		Art.flat(ci, Art.rrect_pts(Rect2(b.end.x - 1.5, y, 3, h), 1.5), dash)
		y += 18.0
	Art.flat(ci, Art.rrect_pts(b, 8), Color(1, 1, 1, 0.12))
	plus_badge(ci, b.get_center(), 15.0)


static func plus_badge(ci: CanvasItem, c: Vector2, r: float) -> void:
	Art.t_circle(ci, c, r, Art.GREEN, 2.6, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(c.x - r * 0.55, c.y - r * 0.15, r * 1.1, r * 0.3), r * 0.12), Art.WHITE)
	Art.flat(ci, Art.rrect_pts(Rect2(c.x - r * 0.15, c.y - r * 0.55, r * 0.3, r * 1.1), r * 0.12), Art.WHITE)


## The accountant's empty chair before he is hired: a ghost in the seat.
static func ghost(ci: CanvasItem) -> void:
	var sil := Art.union([Art.circle_pts(Vector2(0, -66), 15, 18), Art.rrect_pts(Rect2(-14, -50, 28, 34), 10)])
	Art.toon(ci, sil, Color(1, 1, 1, 0.35), 0.0, 0.0)
	Art.polyline(ci, sil, Color(1, 1, 1, 0.8), 2.0, true)
	Art.text(ci, Vector2(0, -58), "?", 18, Art.WHITE, 4)


# --- Vault ------------------------------------------------------------------------------------

const VAULT_R := 64.0
const VAULT_C := Vector2(0, -74)


## The round vault in the wall (origin on the floor under its middle): a
## steel frame with bolts, the dark inside with shelves, the heavy door
## swung open to the left and a brass name plate. The coins inside are
## vault_coins (they change).
static func vault(ci: CanvasItem, label: String) -> void:
	var c := VAULT_C
	Art.flat(ci, Art.circle_pts(c + Vector2(6, 8), VAULT_R + 20, 40), Color(Art.SHADE, 0.22))
	Art.t_circle(ci, c, VAULT_R + 16, Color("8d94a6"), 3.0, 0.6)
	Art.t_circle(ci, c, VAULT_R + 4, Color("5a5f7a"), 2.6, 0.0)
	for k in 12:
		Art.disc(ci, c + Vector2(VAULT_R + 10, 0).rotated(k * TAU / 12.0), 3.0, Color("cbd5e1"))
	var inside := Art.circle_pts(c, VAULT_R, 40)
	Art.flat(ci, inside, Color("2a2440"))
	for y: float in [-34.0, 8.0]:
		var sh := Art.clipped(Art.rrect_pts(Rect2(-VAULT_R, c.y + y, VAULT_R * 2.0, 6), 1), inside)
		if not sh.is_empty():
			Art.flat(ci, sh, Color("4a4560"))
	Art.ring(ci, inside, Art.INK, 3.0)
	# The open door, seen edge-on at the left.
	var d := c + Vector2(-VAULT_R - 34, 2)
	Art.t_rect(ci, Rect2(c.x - VAULT_R - 18, c.y - 30, 20, 12), 3, Color("5a5f7a"), 2.2, 0.2)
	Art.t_rect(ci, Rect2(c.x - VAULT_R - 18, c.y + 18, 20, 12), 3, Color("5a5f7a"), 2.2, 0.2)
	Art.t_ellipse(ci, d, Vector2(26, VAULT_R + 10), Color("aab4c6"), 3.0, 0.7)
	Art.t_ellipse(ci, d + Vector2(4, 0), Vector2(18, VAULT_R - 4), Color("cbd5e1"), 2.2, 0.3)
	Art.push(ci, d + Vector2(4, 0), 0.0, Vector2(0.4, 1.0))
	Art.t_circle(ci, Vector2.ZERO, 22, Art.BRASS, 2.6, 0.4)
	for k in 4:
		Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(28, 0).rotated(k * PI / 4.0)]), Art.INK, 3.0)
		Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(-28, 0).rotated(k * PI / 4.0)]), Art.INK, 3.0)
	Art.t_circle(ci, Vector2.ZERO, 7, Art.GOLD, 2.0, 0.3)
	Art.pop(ci)
	# Name plate.
	var pr := Rect2(c.x - 48, c.y - VAULT_R - 46, 96, 26)
	Art.t_rect(ci, pr, 8, Art.GOLD, 2.8, 0.5)
	Art.coin(ci, Vector2(pr.position.x + 14, pr.get_center().y), 8)
	if label != "":
		Art.text(ci, Vector2(pr.get_center().x + 8, pr.end.y - 7), label, 16, Art.INK, 0, true)


## Coins inside the vault for fill 0..1: a heap rising in the round
## opening; from 0.55 the coins spill out over the sill.
static func vault_coins(ci: CanvasItem, fill: float, t: float) -> void:
	var f := Props._q(fill, 12)
	var c := VAULT_C
	if f <= 0.0:
		return
	var key := hash(["vault_coins", f])
	if not Art.cache_begin(ci, key):
		var inside := Art.circle_pts(c, VAULT_R - 2, 40)
		var h := lerpf(10.0, VAULT_R * 1.85, minf(1.0, f * 1.25))
		var base := c.y + VAULT_R
		var heap := Art.smooth_pts(PackedVector2Array([Vector2(-VAULT_R - 10, base + 4), Vector2(-VAULT_R * 0.75, base - h * 0.55), Vector2(-VAULT_R * 0.3, base - h),
				Vector2(VAULT_R * 0.3, base - h + 4), Vector2(VAULT_R * 0.75, base - h * 0.5), Vector2(VAULT_R + 10, base + 4)]), 4)
		var inner := Art.clipped(heap, inside)
		if not inner.is_empty():
			Art.toon(ci, inner, Art.GOLD, 0.0, 0.8)
		var n := 4 + int(f * 16.0)
		for i in n:
			var u := fmod(i * 0.618, 1.0)
			var v := fmod(i * 0.38 + 0.2, 1.0)
			var p := Vector2((u * 2.0 - 1.0) * VAULT_R * 0.75 * (1.0 - v * 0.5), base - 6.0 - v * h * 0.85)
			if p.distance_to(c) < VAULT_R - 8.0:
				Art.push(ci, p, 0.0, Vector2(1.0, 0.55))
				Art.coin(ci, Vector2.ZERO, 7.0 + (i % 3))
				Art.pop(ci)
		if f >= 0.3:
			# Bags and bars on the shelves.
			Art.push(ci, c + Vector2(-34, -34))
			Chars.item(ci, "coinbag", Vector2(0, -28), Art.GOLD)
			Art.pop(ci)
			for k in mini(3, 1 + int((f - 0.3) * 6.0)):
				var bp := c + Vector2(14 + k * 16, -34)
				Art.toon(ci, PackedVector2Array([bp + Vector2(-8, 0), bp + Vector2(8, 0), bp + Vector2(6, -7), bp + Vector2(-6, -7)]), Color("ffd86a"), 2.0, 0.5)
		if f >= 0.55:
			# Spilling out over the sill onto the floor.
			var w := lerpf(40.0, 110.0, (f - 0.55) / 0.45)
			var sh := lerpf(14.0, 40.0, (f - 0.55) / 0.45)
			var spill := Art.smooth_pts(PackedVector2Array([Vector2(-w, 6), Vector2(-w * 0.6, -sh * 0.5), Vector2(-w * 0.2, -sh), Vector2(w * 0.25, -sh * 0.9),
					Vector2(w * 0.65, -sh * 0.4), Vector2(w, 6)]), 4)
			Art.toon(ci, spill, Art.GOLD, 3.0, 0.7)
			for i in 6 + int(f * 8.0):
				var u := fmod(i * 0.618 + 0.1, 1.0)
				Art.push(ci, Vector2((u * 2.0 - 1.0) * w * 0.75, -4.0 - fmod(i * 0.37, 1.0) * sh * 0.7), 0.0, Vector2(1.0, 0.55))
				Art.coin(ci, Vector2.ZERO, 7.0 + (i % 2))
				Art.pop(ci)
		if f >= 0.75:
			# Coin stacks beside the vault.
			for side: float in [-1.0, 1.0]:
				for j in 2:
					var sx := side * (VAULT_R + 30.0 + j * 18.0)
					var hgt := 3 + int((f - 0.75) * 24.0) - j * 2
					for k in maxi(1, hgt):
						Art.push(ci, Vector2(sx, -4.0 - k * 6.0), 0.0, Vector2(1.0, 0.45))
						Art.t_circle(ci, Vector2.ZERO, 11, Art.GOLD if k % 2 == 0 else Color("ffd86a"), 2.0, 0.0)
						Art.pop(ci)
		if f >= 0.9:
			var cr := Vector2(0, c.y + VAULT_R - lerpf(10.0, VAULT_R * 1.85, minf(1.0, f * 1.25)) - 4.0)
			Art.toon(ci, PackedVector2Array([cr + Vector2(-16, 6), cr + Vector2(-18, -12), cr + Vector2(-8, -4), cr + Vector2(0, -16),
					cr + Vector2(8, -4), cr + Vector2(18, -12), cr + Vector2(16, 6)]), Art.GOLD, 2.4, 0.4)
			Art.disc(ci, cr + Vector2(0, -2), 2.5, Art.RED)
		Art.cache_end(ci, key)
	# Twinkles.
	var ph := fposmod(t * 0.9, 1.0)
	Art.dot(ci, c + Vector2(-20, 30), 3.5 * sin(ph * PI), Color(1, 1, 1, 0.9))
	Art.dot(ci, c + Vector2(26, 44), 3.0 * sin(fposmod(ph + 0.5, 1.0) * PI), Color(1, 1, 1, 0.9))


# --- Wall pieces ------------------------------------------------------------------------------

## A window onto the current world (r = the glass), with curtains whose
## cloth follows the wallpaper level.
static func window_view(ci: CanvasItem, r: Rect2, world: String, level: int) -> void:
	var lk := FactoryArt.look(world)
	Art.t_rect(ci, r.grow(9), 8, Color("f4ead6") if level < 4 else Art.GOLD, 3.0, 0.4)
	FactoryArt.scene(ci, r, lk)
	Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.15, 0), r.position + Vector2(r.size.x * 0.32, 0),
			r.position + Vector2(r.size.x * 0.1, r.size.y), r.position + Vector2(0, r.size.y)]), Color(1, 1, 1, 0.16))
	Art.line_c(ci, PackedVector2Array([Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y)]), Color("f4ead6"), 5.0)
	Art.line_c(ci, PackedVector2Array([Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y)]), Color("f4ead6"), 5.0)
	Art.ring(ci, Art.rrect_pts(r, 3), Art.INK, 3.0)
	Art.t_rect(ci, Rect2(r.position.x - 16, r.end.y + 8, r.size.x + 32, 10), 4, Color("f4ead6"), 2.6, 0.3)
	# Curtains.
	var cloth: Color = [Color("c9b8a0"), Color("ff8a5c"), Color("5cc8a8"), Color("5a8ae0"), Color("2bb8b4"), Color("b0243a")][clampi(level, 0, 5)]
	Art.t_rect(ci, Rect2(r.position.x - 26, r.position.y - 22, r.size.x + 52, 8), 4, Art.WOOD_DARK if level < 5 else Art.GOLD, 2.4, 0.2)
	for side: float in [-1.0, 1.0]:
		var x0 := r.position.x - 22.0 if side < 0 else r.end.x + 22.0
		var x1 := x0 - side * r.size.x * 0.22
		var pts := Art.smooth_pts(PackedVector2Array([Vector2(x0, r.position.y - 18), Vector2(x1, r.position.y - 18), Vector2(lerpf(x0, x1, 0.5), r.get_center().y),
				Vector2(lerpf(x0, x1, 0.75), r.end.y + 20), Vector2(x0, r.end.y + 24)]), 3)
		Art.toon(ci, pts, cloth, 2.6, 0.6)
		Art.t_rect(ci, Rect2(lerpf(x0, x1, 0.4) - 8, r.get_center().y - 3, 16, 7), 3, Art.GOLD, 1.8, 0.0)


## Soft light from a window down onto the floor.
static func window_light(ci: CanvasItem, r: Rect2, floor_y: float) -> void:
	var c := Color(1.0, 0.95, 0.75, 0.16)
	var clear := Color(1.0, 0.95, 0.75, 0.0)
	var dx := (floor_y - r.end.y) * 0.3
	Art.grad(ci, PackedVector2Array([Vector2(r.position.x + 4, r.end.y), Vector2(r.end.x - 4, r.end.y),
			Vector2(r.end.x + dx + 30, floor_y + 70), Vector2(r.position.x + dx - 10, floor_y + 70)]), PackedColorArray([c, c, clear, clear]))


static func clock(ci: CanvasItem) -> void:
	Art.t_circle(ci, Vector2.ZERO, 24, Art.WOOD, 3.0, 0.4)
	Art.t_circle(ci, Vector2.ZERO, 19, Art.CREAM, 2.0, 0.0)
	for k in 12:
		Art.disc(ci, Vector2(0, -15).rotated(k * TAU / 12.0), 2.0 if k % 3 == 0 else 1.3, Art.INK_SOFT)


static func clock_hands(ci: CanvasItem, t: float) -> void:
	FactoryArt.clock_hands(ci, t)


## A soft dark edge around the room (cozy vignette), w x h.
static func vignette(ci: CanvasItem, w: float, h: float) -> void:
	var d := Color(Art.SHADE, 0.22)
	var c := Color(Art.SHADE, 0.0)
	var e := minf(w, h) * 0.12
	Art.grad(ci, PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, h), Vector2(0, h)]), PackedColorArray([d, c, c, d]))
	Art.grad(ci, PackedVector2Array([Vector2(w - e, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - e, h)]), PackedColorArray([c, d, d, c]))
	Art.grad(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, e), Vector2(0, e)]), PackedColorArray([d, d, c, c]))


# --- Jungle: the explorer's study ---------------------------------------------------------
# The jungle world dresses the office as an explorer's study: stone, bamboo
# and warm teak walls, a pinned treasure map, a brass compass instead of the
# clock, rattan furniture, a terrarium with a frog instead of the aquarium,
# a ceiling fan, relics on the trophy shelf and big jungle plants. Every
# decor slot keeps its 6 looks and stays inside the same bounds (BOX).

const TEAK := Color("a8643a")
const TEAK_DARK := Color("6a3a22")
const RATTAN := Color("e0b46a")
const RATTAN_DARK := Color("b0823e")
const PARCH := Color("f4e2b4")
const J_WALLS := [Color("d2bf94"), Color("e6cd92"), Color("dcc070"), Color("d4ebc0"), Color("2f9a7e"), Color("23705e")]
const J_FLOORS := [Color("b89a6a"), Color("dcc078"), Color("c08850"), Color("cdbb8e"), Color("a8683a"), Color("eadfc4")]
const J_BLOOMS := [Color("ff8a2a"), Color("ff4fa8"), Color("ffd23f")]


static func is_jungle(world: String) -> bool:
	return world == "jungle"


## The study's back wall from y 0 to h, `w` wide (level 0 a bare ruin ... 5 jade and gold).
static func j_wall(ci: CanvasItem, w: float, h: float, level: int) -> void:
	var lv := clampi(level, 0, 5)
	var a: Color = J_WALLS[lv]
	var rail := h * 0.62
	match lv:
		0:
			FactoryArt._temple_wall(ci, w, h, {"wall": Color("d8c49a"), "wall2": Color("c8b48a")})
		1:
			# A woven bamboo mat between bamboo posts.
			Art.flat(ci, Art.rrect_pts(Rect2(0, 0, w, h), 0.0), a)
			var dk := Art.shade_of(a, 0.12)
			var y := 0.0
			var row := 0
			while y < h:
				var x := -fmod(row * 13.0, 26.0)
				while x < w:
					if (int(x / 13.0) + row) % 2 == 0:
						Art.flat(ci, Art.rrect_pts(Rect2(x + 1, y + 1, 24, 11), 2), dk)
					x += 26.0
				y += 13.0
				row += 1
			var px := 60.0
			while px < w:
				FactoryArt._bamboo(ci, Vector2(px, 0), Vector2(px, h), 14.0)
				px += 170.0
		2:
			# A wall of bamboo canes with a lashed rail.
			Art.flat(ci, Art.rrect_pts(Rect2(0, 0, w, h), 0.0), Art.shade_of(a, 0.2))
			var x := 0.0
			var i := 0
			while x < w:
				var c := a if i % 3 != 1 else a.lerp(Color("c8b060"), 0.6)
				Art.flat(ci, Art.rrect_pts(Rect2(x + 1, 0, 20, h), 0.0), c)
				Art.flat(ci, Art.rrect_pts(Rect2(x + 4, 0, 4, h), 0.0), Color(1, 1, 1, 0.22))
				var ny := fmod(i * 37.0, 60.0) + 30.0
				while ny < h:
					Art.flat(ci, Art.rrect_pts(Rect2(x + 1, ny, 20, 3), 1), FactoryArt.BAMBOO_DARK)
					ny += 70.0
				x += 22.0
				i += 1
		3, 4, 5:
			Art.flat(ci, Art.rrect_pts(Rect2(0, 0, w, h), 0.0), a)
			_leaf_paper(ci, w, rail, lv)
	if lv >= 3:
		# Teak wainscot with carved panels below the rail.
		var wc := TEAK if lv == 3 else (TEAK_DARK if lv == 4 else Color("5a2f22"))
		var trim := Art.shade_of(wc, 0.3) if lv == 3 else (Color("e0a050") if lv == 4 else Art.GOLD)
		Art.flat(ci, Art.rrect_pts(Rect2(0, rail + 8, w, h - rail - 8), 0.0), wc)
		var x := 14.0
		var k := 0
		while x < w - 40.0:
			var pr := Rect2(x, rail + 18, 52, h - rail - 44)
			Art.flat(ci, Art.rrect_pts(pr, 4), Art.shade_of(wc, 0.12))
			Art.ring(ci, Art.rrect_pts(pr, 4), trim, 2.0)
			if pr.size.y > 34.0:
				FactoryArt.glyph(ci, pr.get_center(), k % 4 if lv == 5 else 1, Art.shade_of(wc, 0.12))
			x += 66.0
			k += 1
	if lv >= 2:
		# The rail: a bamboo pole (2) or carved teak (3+).
		if lv == 2:
			FactoryArt._bamboo(ci, Vector2(-4, rail + 4), Vector2(w + 4, rail + 4), 12.0)
			var tx := 40.0
			while tx < w:
				Art.line_c(ci, PackedVector2Array([Vector2(tx - 5, rail - 3), Vector2(tx + 5, rail + 11)]), Color("8a6a3a"), 2.4)
				Art.line_c(ci, PackedVector2Array([Vector2(tx + 5, rail - 3), Vector2(tx - 5, rail + 11)]), Color("8a6a3a"), 2.4)
				tx += 120.0
		else:
			Art.t_rect(ci, Rect2(-4, rail, w + 8, 10), 0.0, TEAK if lv < 5 else Art.GOLD, 2.2, 0.3)
	if lv >= 1:
		var bb := FactoryArt.BAMBOO if lv <= 2 else (TEAK_DARK if lv < 5 else Color("4a2a1a"))
		Art.t_rect(ci, Rect2(-4, h - 14, w + 8, 14), 0.0, bb, 2.4, 0.3)
	if lv >= 4:
		# Crown molding with a step-fret frieze.
		var cm := Color("e0a050") if lv == 4 else Art.GOLD
		Art.t_rect(ci, Rect2(-4, 0, w + 8, 22), 0.0, Art.shade_of(cm, 0.05), 2.4, 0.4)
		var fx := 6.0
		var deep := Art.shade_of(cm, 0.35)
		while fx < w:
			Art.line_c(ci, PackedVector2Array([Vector2(fx, 18), Vector2(fx, 6), Vector2(fx + 12, 6), Vector2(fx + 12, 14), Vector2(fx + 6, 14)]), deep, 2.0)
			fx += 20.0
	_room_light(ci, w, 0.0, h, 0.16)
	# Sunlight through leaves: soft dapples on the wall.
	for i in 6:
		var p := Vector2(fmod(i * 173.0 + 40.0, w), h * (0.2 + fmod(i * 0.37, 0.5)))
		Art.flat(ci, Art.ellipse_pts(p, Vector2(26, 12), 14, 0.3), Color(1.0, 0.97, 0.75, 0.10))
		Art.flat(ci, Art.ellipse_pts(p + Vector2(22, 10), Vector2(12, 7), 10), Color(1.0, 0.97, 0.75, 0.08))


## Leaf-pattern wallpaper above the rail (levels 3..5).
static func _leaf_paper(ci: CanvasItem, w: float, rail: float, lv: int) -> void:
	var leaf := Color("b4d89c") if lv == 3 else (Color("49b493") if lv == 4 else Color("2f8a72"))
	var y := 34.0 if lv >= 4 else 22.0
	var row := 0
	while y < rail - 10.0:
		var x := 26.0 + (row % 2) * 40.0
		while x < w:
			var a := -0.9 if (row + int(x / 80.0)) % 2 == 0 else -2.2
			Art.push(ci, Vector2(x, y), a)
			Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(0, 0), Vector2(9, -6), Vector2(22, 0), Vector2(9, 6)]), 2), leaf)
			Art.line_c(ci, PackedVector2Array([Vector2(1, 0), Vector2(20, 0)]), Art.shade_of(leaf, 0.18), 1.4)
			Art.pop(ci)
			if lv >= 4:
				Art.disc(ci, Vector2(x + 26, y + 14), 2.2, Color(Art.GOLD, 0.7 if lv == 5 else 0.45))
			x += 80.0
		y += 40.0
		row += 1
	if lv == 5:
		# Gold sun medallions along the wall.
		var mx := 90.0
		while mx < w - 40.0:
			var c := Vector2(mx, rail * 0.55)
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0)
				Art.line_c(ci, PackedVector2Array([c + d * 13, c + d * 19]), Color(Art.GOLD, 0.8), 2.4)
			Art.ring(ci, Art.circle_pts(c, 10, 16), Color(Art.GOLD, 0.8), 2.4)
			Art.disc(ci, c, 3.0, Color(FactoryArt.JADE, 0.9))
			mx += 240.0


## The floor band from y0 to y1 (0 packed earth ... 5 polished stone with a gold sun).
static func j_floor(ci: CanvasItem, w: float, y0: float, y1: float, level: int) -> void:
	var lv := clampi(level, 0, 5)
	var c: Color = J_FLOORS[lv]
	var dk := Art.shade_of(c, 0.2)
	Art.flat(ci, Art.rrect_pts(Rect2(0, y0, w, y1 - y0), 0.0), c)
	match lv:
		0:
			for i in 10:
				var p := Vector2(fmod(i * 97.0 + 20.0, w), y0 + 10.0 + fmod(i * 53.0, maxf(1.0, y1 - y0 - 20.0)))
				var rr := Vector2(8 + i % 3 * 4, 3.5 + i % 2 * 1.5)
				Art.flat(ci, Art.ellipse_pts(p + Vector2(0, 1.5), rr, 12), Art.shade_of(c, 0.18))
				Art.flat(ci, Art.ellipse_pts(p, rr, 12), Color("cdb088") if i % 2 == 0 else Color("c4a478"))
				Art.flat(ci, Art.ellipse_pts(p + Vector2(-rr.x * 0.3, -rr.y * 0.3), rr * 0.4, 8), Color(1, 1, 1, 0.25))
			for i in 7:
				var p := Vector2(fmod(i * 131.0 + 50.0, w), y0 + 14.0 + fmod(i * 67.0, maxf(1.0, y1 - y0 - 28.0)))
				Art.push(ci, p, i * 0.9)
				Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-7, 0), Vector2(0, -3), Vector2(7, 0), Vector2(0, 3)]), 2), Color("9aa84a") if i % 2 == 0 else Color("c88a3a"))
				Art.pop(ci)
			for i in 6:
				var p := Vector2(fmod(i * 151.0 + 70.0, w), y0 + 6.0 + fmod(i * 71.0, maxf(1.0, y1 - y0 - 12.0)))
				for k in 3:
					Art.line_c(ci, PackedVector2Array([p + Vector2(k * 4 - 4, 0), p + Vector2(k * 5 - 6, -8 - k % 2 * 3)]), FactoryArt.LEAF, 2.0)
		1:
			var y := y0 + 10.0
			var k := 0
			while y < y1:
				Art.line_c(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y)]), dk, 2.0)
				Art.line_c(ci, PackedVector2Array([Vector2(0, y - 4), Vector2(w, y - 4)]), Color(1, 1, 1, 0.18), 1.6)
				var x := fmod(k * 31.0, 70.0)
				while x < w:
					Art.line_c(ci, PackedVector2Array([Vector2(x, y - 9), Vector2(x, y)]), dk, 1.6)
					x += 70.0
				y += 11.0 + k * 1.2
				k += 1
		2:
			var y := y0 + 16.0
			var k := 0
			while y < y1:
				Art.line_c(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y)]), dk, 2.0)
				var x := fmod(k * 53.0, 120.0)
				while x < w:
					Art.line_c(ci, PackedVector2Array([Vector2(x, y - 16 - k * 1.5), Vector2(x, y)]), dk, 2.0)
					Art.disc(ci, Vector2(x + 6, y - 5), 1.4, dk)
					x += 120.0
				y += 18.0 + k * 3.0
				k += 1
			Art.flat(ci, Art.ellipse_pts(Vector2(w * 0.5, y0 + (y1 - y0) * 0.45), Vector2(w * 0.3, 10), 20), Color(1, 1, 1, 0.16))
		3:
			var size := 44.0
			var y := y0
			var r := 0
			while y < y1:
				var x := -fmod(r * 22.0, size)
				while x < w:
					var tr := Rect2(x + 2, y + 2, size - 4, minf(size, y1 - y) - 4)
					Art.flat(ci, Art.rrect_pts(tr, 4), c.lerp(Color("bca878"), 0.5 if int(x / size + r) % 3 == 0 else 0.0))
					if int(x * 7.0 + r * 13.0) % 5 == 0:
						Art.flat(ci, Art.ellipse_pts(Vector2(tr.position.x + 6, tr.end.y - 2), Vector2(9, 3.5), 10), Color(FactoryArt.LEAF, 0.7))
					x += size
				y += size
				r += 1
		4:
			var y := y0
			var r := 0
			while y < y1:
				var x := -40.0 + (r % 2) * 20.0
				while x < w:
					Art.line_c(ci, PackedVector2Array([Vector2(x, y + 18), Vector2(x + 20, y)]), dk, 2.0)
					Art.line_c(ci, PackedVector2Array([Vector2(x + 20, y), Vector2(x + 40, y + 18)]), dk, 2.0)
					x += 40.0
				y += 18.0
				r += 1
			Art.flat(ci, Art.ellipse_pts(Vector2(w * 0.5, y0 + (y1 - y0) * 0.4), Vector2(w * 0.32, 12), 20), Color(1, 1, 1, 0.14))
		5:
			# Polished stone with a jade border and a golden sun inlay.
			var size := 60.0
			var x := 0.0
			while x < w:
				Art.line_c(ci, PackedVector2Array([Vector2(x, y0), Vector2(x - 16, y1)]), Color("d8ccb0"), 1.8)
				x += size
			Art.flat(ci, Art.rrect_pts(Rect2(0, y0 + 6, w, 6), 0.0), FactoryArt.JADE)
			Art.flat(ci, Art.rrect_pts(Rect2(0, y0 + 14, w, 3), 0.0), Art.GOLD)
			var sc := Vector2(w * 0.5, y0 + (y1 - y0) * 0.55)
			var half := Vector2(minf(w * 0.18, 120.0), (y1 - y0) * 0.16)
			for k in 12:
				var d := Vector2.from_angle(k * TAU / 12.0)
				Art.line_c(ci, PackedVector2Array([sc + d * half * 1.1, sc + d * half * 1.45]), Color(Art.GOLD, 0.8), 3.0)
			Art.ring(ci, Art.ellipse_pts(sc, half, 28), Color(Art.GOLD, 0.85), 3.0)
			Art.flat(ci, Art.ellipse_pts(sc, half * 0.5, 20), Color(FactoryArt.JADE, 0.5))
	_room_light(ci, w, y0, y1, 0.2)
	Art.line_c(ci, PackedVector2Array([Vector2(0, y0), Vector2(w, y0)]), Art.INK, 3.0)


## A woven mat (floor levels 2, 4 and 5), centered at `c`.
static func j_rug(ci: CanvasItem, c: Vector2, half: Vector2, level: int) -> void:
	match level:
		2:
			Art.t_ellipse(ci, c, half * 0.72, RATTAN, 2.4, 0.2)
			for k in 3:
				Art.ring(ci, Art.ellipse_pts(c, half * (0.6 - k * 0.16), 24), RATTAN_DARK, 2.0)
		4, 5:
			var hh := half * (0.9 if level == 4 else 1.0)
			var base := Color("e8743a") if level == 4 else Color("1f8a72")
			Art.t_rect(ci, Rect2(c - hh, hh * 2.0), 5, base, 2.6, 0.2)
			var band := Art.GOLD if level == 5 else Color("ffd98a")
			Art.ring(ci, Art.rrect_pts(Rect2(c - hh + Vector2(7, 5), hh * 2.0 - Vector2(14, 10)), 3), band, 2.6)
			# Zigzag stripes.
			for row in 2:
				var y := c.y + (row - 0.5) * hh.y * 0.9
				var pts := PackedVector2Array()
				var x := c.x - hh.x + 16.0
				var up := true
				while x <= c.x + hh.x - 16.0:
					pts.append(Vector2(x, y + (-5.0 if up else 5.0)))
					up = not up
					x += 12.0
				Art.line_c(ci, pts, FactoryArt.JADE if level == 4 else Color("ffd98a"), 2.6)
			if level == 5:
				Art.toon(ci, Art.star_pts(c, 14, 7, 8), Art.GOLD, 2.0, 0.3)
			# Fringe at the ends.
			for side: float in [-1.0, 1.0]:
				var fx := c.x + side * hh.x
				var y := c.y - hh.y + 4.0
				while y < c.y + hh.y - 2.0:
					Art.line_c(ci, PackedVector2Array([Vector2(fx, y), Vector2(fx + side * 7.0, y)]), band, 1.6)
					y += 6.0


## Bamboo beam and a fringe of leaves under the ceiling (static).
static func j_canopy(ci: CanvasItem, w: float, top: float) -> void:
	var y := top + 6.0
	var x := -10.0
	var i := 0
	while x < w + 10.0:
		var col: Color = FactoryArt.LEAF if i % 3 != 1 else (FactoryArt.LEAF_DARK if i % 2 == 0 else FactoryArt.LEAF_LIGHT)
		var ln := 22.0 + float((i * 7) % 5) * 4.0
		FactoryArt._leaf(ci, Vector2(x, y + 4), ln, PI * 0.5 + (0.45 if i % 2 == 0 else -0.45), col)
		x += 17.0
		i += 1
	FactoryArt._bamboo(ci, Vector2(-6, y), Vector2(w + 6, y), 13.0)


## A treasure map pinned to the wall (r = the paper).
static func j_map(ci: CanvasItem, r: Rect2) -> void:
	var p := r.position
	var s := r.size
	var edge := PackedVector2Array()
	for k in 7:
		edge.append(p + Vector2(s.x * k / 6.0, (3.0 if k % 2 == 0 else -1.0)))
	for k in 5:
		edge.append(p + Vector2(s.x + (2.0 if k % 2 == 0 else -2.0), s.y * (k + 1) / 5.0))
	for k in 7:
		edge.append(p + Vector2(s.x * (6 - k) / 6.0, s.y + (-2.0 if k % 2 == 0 else 2.0)))
	for k in 4:
		edge.append(p + Vector2((-2.0 if k % 2 == 0 else 2.0), s.y * (4 - k) / 5.0))
	Art.flat(ci, Art.moved(edge, Vector2(4, 5)), Color(Art.SHADE, 0.22))
	Art.toon(ci, edge, PARCH, 2.4, 0.3)
	# Land, a river, the pyramid and the path to the X.
	var land := Art.union([Art.ellipse_pts(p + s * Vector2(0.32, 0.45), s * Vector2(0.24, 0.3), 14),
			Art.ellipse_pts(p + s * Vector2(0.62, 0.55), s * Vector2(0.28, 0.32), 14)])
	Art.flat(ci, land, Color("b8d890"))
	for q: Vector2 in [Vector2(0.22, 0.4), Vector2(0.38, 0.32), Vector2(0.7, 0.42), Vector2(0.58, 0.7)]:
		Art.flat(ci, Art.circle_pts(p + s * q, s.y * 0.07, 10), Color("6aaa5a"))
	Art.line_c(ci, PackedVector2Array([p + s * Vector2(0.08, 0.15), p + s * Vector2(0.3, 0.3), p + s * Vector2(0.46, 0.6),
			p + s * Vector2(0.52, 0.95)]), Color("4aa6d8"), 2.6)
	var py := p + s * Vector2(0.72, 0.36)
	Art.toon(ci, PackedVector2Array([py + Vector2(-9, 7), py + Vector2(0, -7), py + Vector2(9, 7)]), Color("e0c080"), 1.6, 0.0)
	var dash := [Vector2(0.16, 0.78), Vector2(0.28, 0.7), Vector2(0.4, 0.74), Vector2(0.54, 0.66), Vector2(0.66, 0.74), Vector2(0.78, 0.64)]
	for k in dash.size() - 1:
		if k % 2 == 0:
			Art.line_c(ci, PackedVector2Array([p + s * Vector2(dash[k]), p + s * Vector2(dash[k + 1])]), Color("d04040"), 2.2)
	var xm := p + s * Vector2(0.84, 0.62)
	Art.line_c(ci, PackedVector2Array([xm + Vector2(-5, -5), xm + Vector2(5, 5)]), Color("d04040"), 3.0)
	Art.line_c(ci, PackedVector2Array([xm + Vector2(5, -5), xm + Vector2(-5, 5)]), Color("d04040"), 3.0)
	# A little compass rose.
	var cr := p + s * Vector2(0.14, 0.2)
	Art.flat(ci, Art.star_pts(cr, s.y * 0.11, s.y * 0.035, 4), Color("8a6a4a"))
	# Pins.
	for q: Vector2 in [Vector2(0.06, 0.08), Vector2(0.94, 0.08), Vector2(0.06, 0.92), Vector2(0.94, 0.92)]:
		Art.t_circle(ci, p + s * q, 3.6, Art.RED, 1.6, 0.3)


## A brass compass on the wall (in place of the clock; origin center).
static func j_compass(ci: CanvasItem) -> void:
	Art.t_circle(ci, Vector2.ZERO, 26, Art.BRASS, 3.0, 0.5)
	Art.ring(ci, Art.circle_pts(Vector2.ZERO, 22, 24), Art.GOLD_DARK, 2.0)
	Art.t_circle(ci, Vector2.ZERO, 19, Art.CREAM, 2.0, 0.0)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 17, 4.5, 4, 0.0), Color("e8d8b0"))
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 11, 3.5, 4, PI / 4.0), Color("d8c49a"))
	for k in 16:
		var d := Vector2.from_angle(k * TAU / 16.0)
		Art.line_c(ci, PackedVector2Array([d * 15.5, d * (18.0 if k % 4 == 0 else 17.0)]), Art.INK_SOFT, 1.4)
	Art.toon(ci, PackedVector2Array([Vector2(-4, -27), Vector2(0, -33), Vector2(4, -27)]), Art.BRASS, 1.8, 0.0)
	Art.t_circle(ci, Vector2(0, -35), 3.5, Art.BRASS, 1.8, 0.0)


## The compass needle, swinging gently and settling north.
static func j_compass_needle(ci: CanvasItem, t: float) -> void:
	var a := snappedf(sin(t * 0.9) * 0.28 + sin(t * 2.3) * 0.07, 0.03)
	Art.push(ci, Vector2.ZERO, a)
	Art.toon(ci, PackedVector2Array([Vector2(-3.5, 0), Vector2(0, -16), Vector2(3.5, 0)]), Art.RED, 1.6, 0.0)
	Art.toon(ci, PackedVector2Array([Vector2(-3.5, 0), Vector2(0, 16), Vector2(3.5, 0)]), Art.WHITE, 1.6, 0.0)
	Art.pop(ci)
	Art.t_circle(ci, Vector2.ZERO, 3, Art.GOLD, 1.4, 0.0)
	Art.flat(ci, Art.ellipse_pts(Vector2(-7, -9), Vector2(6, 3), 8, -0.6), Color(1, 1, 1, 0.35))


## A window onto the jungle (r = the glass): bamboo frame (levels 0..2) or
## carved teak (3+, gold at 5), a rolled bamboo blind and leaves growing in.
static func j_window(ci: CanvasItem, r: Rect2, level: int) -> void:
	var lv := clampi(level, 0, 5)
	var lk := FactoryArt.look("jungle")
	var wood := TEAK if lv < 5 else Art.GOLD
	if lv < 3:
		Art.t_rect(ci, r.grow(8), 4, Color("8a6a3a"), 3.0, 0.3)
	else:
		Art.t_rect(ci, r.grow(10), 6, wood, 3.0, 0.4)
		Art.ring(ci, Art.rrect_pts(r.grow(5), 3), Art.shade_of(wood, 0.3), 2.0)
	FactoryArt.scene(ci, r, lk)
	Art.flat(ci, PackedVector2Array([r.position + Vector2(r.size.x * 0.15, 0), r.position + Vector2(r.size.x * 0.32, 0),
			r.position + Vector2(r.size.x * 0.1, r.size.y), r.position + Vector2(0, r.size.y)]), Color(1, 1, 0.9, 0.14))
	var c := r.get_center()
	if lv < 3:
		FactoryArt._bamboo(ci, Vector2(c.x, r.position.y - 2), Vector2(c.x, r.end.y + 2), 7.0)
		FactoryArt._bamboo(ci, Vector2(r.position.x - 2, c.y), Vector2(r.end.x + 2, c.y), 7.0)
	else:
		Art.line_c(ci, PackedVector2Array([Vector2(c.x, r.position.y), Vector2(c.x, r.end.y)]), wood, 5.0)
		Art.line_c(ci, PackedVector2Array([Vector2(r.position.x, c.y), Vector2(r.end.x, c.y)]), wood, 5.0)
	Art.ring(ci, Art.rrect_pts(r, 3), Art.INK, 3.0)
	if lv < 3:
		for q: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			FactoryArt._bamboo(ci, q + Vector2(-12, 0), q + Vector2(12, 0), 9.0)
	# The sill, with flowers in a trough at the higher levels.
	Art.t_rect(ci, Rect2(r.position.x - 16, r.end.y + 8, r.size.x + 32, 10), 4, FactoryArt.BAMBOO if lv < 3 else wood, 2.6, 0.3)
	if lv >= 2:
		Art.t_rect(ci, Rect2(r.position.x - 4, r.end.y - 2, r.size.x + 8, 11), 3, FactoryArt.TERRACOTTA, 2.2, 0.4)
		var n := int(r.size.x / 18.0)
		for i in n:
			var fx := r.position.x + 6.0 + i * (r.size.x - 12.0) / maxf(1.0, n - 1)
			Art.t_ellipse(ci, Vector2(fx, r.end.y - 4), Vector2(7, 4), FactoryArt.LEAF if i % 2 == 0 else FactoryArt.LEAF_LIGHT, 1.6, 0.2)
			if i % 2 == 1 or lv >= 4:
				FactoryArt._flower(ci, Vector2(fx, r.end.y - 9), 4.0, J_BLOOMS[i % 3])
	# A rolled-up bamboo blind with its cords.
	var bl := Rect2(r.position.x - 14, r.position.y - 26, r.size.x + 28, 14)
	Art.t_rect(ci, bl, 6, FactoryArt.BAMBOO, 2.6, 0.5)
	var lx := bl.position.x + 8.0
	while lx < bl.end.x - 6.0:
		Art.line_c(ci, PackedVector2Array([Vector2(lx, bl.position.y + 3), Vector2(lx, bl.end.y - 3)]), FactoryArt.BAMBOO_DARK, 1.4)
		lx += 7.0
	for side: float in [0.22, 0.78]:
		var cx := bl.position.x + bl.size.x * side
		Art.line_c(ci, PackedVector2Array([Vector2(cx, bl.position.y - 2), Vector2(cx, bl.end.y + 8)]), Color("8a5a2c"), 2.0)
		Art.t_circle(ci, Vector2(cx, bl.end.y + 10), 3, Color("c9a26a"), 1.4, 0.0)
	# Leaves growing in from the corners.
	var big := minf(40.0, r.size.y * 0.42)
	FactoryArt._leaf(ci, Vector2(r.position.x - 10, r.position.y - 12), big, 1.0, FactoryArt.LEAF)
	FactoryArt._leaf(ci, Vector2(r.position.x - 12, r.position.y - 8), big * 0.8, 1.7, FactoryArt.LEAF_DARK)
	FactoryArt._leaf(ci, Vector2(r.end.x + 12, r.end.y + 6), big * 0.9, -2.2, FactoryArt.LEAF_LIGHT)
	FactoryArt._leaf(ci, Vector2(r.end.x + 12, r.end.y + 10), big * 0.75, -1.5, FactoryArt.LEAF)


## Explorer's chair: 0 a stool, 1..2 bamboo, 3+ rattan with a tall back.
static func j_chair(ci: CanvasItem, level: int) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		Art.t_ellipse(ci, Vector2(0, -36), Vector2(17, 6), Color("a88a5a"), 2.4, 0.3)
		_legs4(ci, [-10, 10], -32, Color("8a6a3a"), 6)
		return
	var c := FactoryArt.BAMBOO if lv <= 2 else (RATTAN if lv < 5 else Art.GOLD)
	var back_h := 64.0 if lv < 5 else 92.0
	Art.t_rect(ci, Rect2(-24, -40 - back_h, 48, back_h), 14 if lv >= 3 else 4, c, 2.8, 0.4)
	if lv >= 3:
		var y := -32.0 - back_h
		while y < -48.0:
			Art.line_c(ci, PackedVector2Array([Vector2(-18, y), Vector2(18, y)]), Art.shade_of(c, 0.25), 1.6)
			y += 8.0
	else:
		for x: float in [-12.0, 0.0, 12.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(x, -36 - back_h), Vector2(x, -44)]), FactoryArt.BAMBOO_DARK, 2.0)
	if lv == 5:
		FactoryArt.idol(ci, 1.0)


## Explorer's desk: 0 a crate, 1 a camp table, 2 a teak desk, 3 carved,
## 4 dark teak with a telescope, 5 jade and gold with the golden idol.
static func j_desk(ci: CanvasItem, level: int, t: float) -> void:
	var lv := clampi(level, 0, 5)
	match lv:
		0:
			Art.t_rect(ci, Rect2(-52, -54, 104, 54), 3, Color("b88a50"), 2.8, 0.5)
			Art.line_c(ci, PackedVector2Array([Vector2(-50, -27), Vector2(50, -27)]), Color("8a6a3a"), 2.0)
			Art.line_c(ci, PackedVector2Array([Vector2(-48, -52), Vector2(48, -2)]), Color("8a6a3a"), 2.0)
			# A rolled-up map on the crate.
			Art.t_rect(ci, Rect2(-26, -66, 44, 12), 6, PARCH, 2.2, 0.3)
			Art.line_c(ci, PackedVector2Array([Vector2(-6, -66), Vector2(-6, -54)]), Art.RED, 2.0)
		1:
			# Camp table of bamboo with an open map.
			Art.t_rect(ci, Rect2(-66, -62, 132, 10), 3, FactoryArt.BAMBOO, 2.8, 0.4)
			for x: float in [-52.0, 52.0]:
				Art.line_c(ci, PackedVector2Array([Vector2(x - 8, 0), Vector2(x + 8, -52)]), FactoryArt.BAMBOO_DARK, 4.0)
				Art.line_c(ci, PackedVector2Array([Vector2(x + 8, 0), Vector2(x - 8, -52)]), FactoryArt.BAMBOO_DARK, 4.0)
			_desk_map(ci, Vector2(-14, -62), 1.0)
			_lantern_small(ci, Vector2(44, -62), t)
		2:
			Art.t_rect(ci, Rect2(-70, -64, 140, 12), 3, TEAK, 2.8, 0.4)
			Art.t_rect(ci, Rect2(20, -52, 46, 52), 3, Art.shade_of(TEAK, 0.1), 2.6, 0.4)
			for y: float in [-44.0, -26.0]:
				Art.t_rect(ci, Rect2(32, y, 22, 6), 2, Art.BRASS, 1.6, 0.0)
			_legs4(ci, [-62], -52, TEAK_DARK)
			_desk_map(ci, Vector2(-28, -64), 1.0)
			_lantern_small(ci, Vector2(50, -64), t)
		3, 4, 5:
			var top := TEAK if lv == 3 else (TEAK_DARK if lv == 4 else Color("1f8a72"))
			var front := Art.shade_of(top, 0.12)
			var trim := Art.GOLD if lv == 5 else Color("e0a050")
			Art.t_rect(ci, Rect2(-76, -66, 152, 66), 5, front, 3.0, 0.5)
			Art.t_rect(ci, Rect2(-80, -72, 160, 12), 4, top if lv < 5 else Art.GOLD, 2.8, 0.3)
			var panel := Rect2(-64, -52, 128, 44)
			Art.ring(ci, Art.rrect_pts(panel, 4), trim, 2.4)
			FactoryArt.glyph(ci, panel.get_center() + Vector2(-34, 0), 1, front)
			FactoryArt.glyph(ci, panel.get_center(), 2, front)
			FactoryArt.glyph(ci, panel.get_center() + Vector2(34, 0), 0, front)
			# A laptop with money going up, the map and the explorer's things.
			var lx := 6.0
			Art.toon(ci, PackedVector2Array([Vector2(lx - 26, -72), Vector2(lx + 26, -72), Vector2(lx + 22, -78), Vector2(lx - 22, -78)]), Color("5a5f7a"), 2.0, 0.0)
			Art.t_rect(ci, Rect2(lx - 22, -112, 44, 34), 4, Color("2a2f4a"), 2.4, 0.0)
			Art.flat(ci, Art.rrect_pts(Rect2(lx - 18, -108, 36, 26), 2), Color("5ad2a0"))
			Art.line_c(ci, PackedVector2Array([Vector2(lx - 14, -88), Vector2(lx - 4, -94), Vector2(lx + 4, -91), Vector2(lx + 14, -103)]), Art.WHITE, 2.4)
			_desk_map(ci, Vector2(-50, -72), 0.8)
			if lv == 3:
				_lantern_small(ci, Vector2(58, -72), t)
			elif lv == 4:
				# A brass telescope on a little tripod.
				Art.line_c(ci, PackedVector2Array([Vector2(52, -72), Vector2(58, -88), Vector2(64, -72)]), Art.WOOD_DARK, 2.4)
				Art.push(ci, Vector2(58, -92), -0.45)
				Art.t_rect(ci, Rect2(-18, -4, 36, 8), 3, Art.BRASS, 2.0, 0.4)
				Art.t_rect(ci, Rect2(14, -5.5, 8, 11), 2, Art.GOLD_DARK, 1.8, 0.2)
				Art.pop(ci)
			else:
				Art.push(ci, Vector2(60, -72))
				Props.halo(ci, Vector2(0, -14), 26, Color(1.0, 0.85, 0.3, 0.3))
				FactoryArt.idol(ci, 1.5)
				Art.pop(ci)


## A map spread on a desk (origin at its bottom middle on the desk top).
static func _desk_map(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.toon(ci, PackedVector2Array([Vector2(-24, 0), Vector2(-18, -8), Vector2(22, -8), Vector2(26, 0)]), PARCH, 1.8, 0.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-14, -2), Vector2(-4, -6), Vector2(8, -3)]), Color("d04040"), 1.6)
	Art.t_rect(ci, Rect2(-28, -5, 6, 6), 3, Color("d8c49a"), 1.4, 0.0)
	Art.t_rect(ci, Rect2(22, -5, 6, 6), 3, Color("d8c49a"), 1.4, 0.0)
	# A magnifying glass.
	Art.line_c(ci, PackedVector2Array([Vector2(6, -10), Vector2(14, -4)]), Art.WOOD_DARK, 3.0)
	Art.t_circle(ci, Vector2(2, -14), 6, Color(0.8, 0.95, 1.0, 0.6), 2.0, 0.0)
	Art.pop(ci)


## A small oil lantern standing on a desk (origin bottom center).
static func _lantern_small(ci: CanvasItem, at: Vector2, t: float) -> void:
	var fl := Props._q(0.85 + 0.15 * sin(t * 9.0) * sin(t * 5.3), 4)
	Props.halo(ci, at + Vector2(0, -14), 22, Color(1.0, 0.8, 0.4, 0.3 * fl))
	Art.t_rect(ci, Rect2(at.x - 8, at.y - 4, 16, 4), 1, Art.BRASS, 1.6, 0.0)
	Art.t_rect(ci, Rect2(at.x - 7, at.y - 22, 14, 18), 4, Color(1.0, 0.92, 0.6, 0.85), 1.8, 0.0)
	Art.disc(ci, at + Vector2(0, -12), 3.0 * fl, Color("ff9a3a"))
	Art.toon(ci, PackedVector2Array([at + Vector2(-8, -22), at + Vector2(0, -29), at + Vector2(8, -22)]), Art.BRASS, 1.6, 0.0)
	Art.arc_c(ci, at + Vector2(0, -31), 4, PI, TAU, 6, Art.INK, 1.6)


## Rattan sofa: 1 a bamboo bench ... 5 a carved teak and gold one with a sun crest.
static func j_sofa(ci: CanvasItem, level: int) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		spot(ci, "sofa")
		return
	if lv == 1:
		FactoryArt._bamboo(ci, Vector2(-62, -34), Vector2(62, -34), 12.0)
		FactoryArt._bamboo(ci, Vector2(-60, -24), Vector2(60, -24), 10.0)
		for x: float in [-52.0, 52.0]:
			FactoryArt._bamboo(ci, Vector2(x, -40), Vector2(x, 0), 8.0)
		Art.t_rect(ci, Rect2(-44, -46, 88, 10), 4, RATTAN, 2.2, 0.3)
		return
	var frame := RATTAN if lv <= 3 else (TEAK if lv == 4 else TEAK_DARK)
	var cush: Color = [Color(), Color(), Art.CREAM, Color("5cc06a"), FactoryArt.JADE, FactoryArt.JADE][lv]
	var half := 60.0 + lv * 4.0
	var back_h := 48.0 + lv * 4.0
	_legs4(ci, [-half + 10, half - 10], -12, Art.GOLD if lv == 5 else Art.shade_of(frame, 0.3), 6)
	# The woven back.
	var back := Rect2(-half + 6, -24 - back_h, half * 2.0 - 12, back_h)
	Art.t_rect(ci, back, 18, frame, 3.0, 0.5)
	if lv <= 3:
		var y := back.position.y + 10.0
		var row := 0
		while y < back.end.y - 6.0:
			var x := back.position.x + 14.0 + (row % 2) * 7.0
			while x < back.end.x - 14.0:
				Art.flat(ci, Art.ellipse_pts(Vector2(x, y), Vector2(4, 2.5), 8), Art.shade_of(frame, 0.2))
				x += 14.0
			y += 8.0
			row += 1
	else:
		Art.ring(ci, Art.rrect_pts(back.grow(-8), 12), Art.GOLD if lv == 5 else Color("e0a050"), 2.2)
	if lv == 5:
		var c := Vector2(0, -28 - back_h)
		for k in 7:
			var a := PI + (k + 0.5) * PI / 7.0
			Art.toon(ci, PackedVector2Array([c + Vector2.from_angle(a - 0.18) * 10, c + Vector2.from_angle(a) * 22, c + Vector2.from_angle(a + 0.18) * 10]), Art.GOLD, 1.8, 0.0)
		Art.t_circle(ci, c, 11, Art.GOLD, 2.2, 0.4)
		Art.disc(ci, c, 3.5, FactoryArt.JADE)
	# Seat cushion and arms.
	Art.t_rect(ci, Rect2(-half + 14, -36, half * 2.0 - 28, 24), 8, cush, 2.8, 0.4)
	if lv >= 3:
		for k in 3:
			var lx := -half + 34.0 + k * (half * 2.0 - 68.0) / 2.0
			Art.push(ci, Vector2(lx, -24), -0.3 + k * 0.3)
			Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-8, 0), Vector2(0, -4), Vector2(8, 0), Vector2(0, 4)]), 2), Art.shade_of(cush, 0.18))
			Art.pop(ci)
	for x: float in [-half, half - 22]:
		Art.t_rect(ci, Rect2(x, -52, 22, 42), 10, frame, 2.8, 0.5)
		Art.line_c(ci, PackedVector2Array([Vector2(x + 4, -44), Vector2(x + 18, -44)]), Art.shade_of(frame, 0.25), 1.6)
	# Pillows: an orange one and a leaf-print one.
	Art.push(ci, Vector2(-half + 38, -48), -0.25)
	Art.t_rect(ci, Rect2(-14, -14, 28, 28), 8, Color("ff8a3c"), 2.4, 0.4)
	Art.flat(ci, Art.star_pts(Vector2.ZERO, 7, 3, 6), Color("ffd98a"))
	Art.pop(ci)
	if lv >= 3:
		Art.push(ci, Vector2(half - 40, -48), 0.25)
		Art.t_rect(ci, Rect2(-14, -14, 28, 28), 8, Color("ffd23f") if lv < 5 else Art.GOLD, 2.4, 0.4)
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(-8, 4), Vector2(0, -6), Vector2(8, 4), Vector2(0, 8)]), 2), FactoryArt.LEAF)
		Art.pop(ci)


## A little frog (origin under its belly); `puff` swells its throat.
static func _frog(ci: CanvasItem, at: Vector2, s: float, blink: bool, puff: bool, col: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	Art.t_ellipse(ci, Vector2(-9, -3), Vector2(6, 4), Art.shade_of(col, 0.1), 1.8, 0.2)
	Art.t_ellipse(ci, Vector2(9, -3), Vector2(6, 4), Art.shade_of(col, 0.1), 1.8, 0.2)
	Art.t_ellipse(ci, Vector2(0, -8), Vector2(11, 8), col, 2.2, 0.5)
	if puff:
		Art.t_circle(ci, Vector2(0, -4), 5, Color("ffe8a0"), 1.6, 0.0)
	for sx: float in [-5.0, 5.0]:
		Art.t_circle(ci, Vector2(sx, -15), 4, col, 1.8, 0.0)
		if blink:
			Art.line_c(ci, PackedVector2Array([Vector2(sx - 2.5, -15), Vector2(sx + 2.5, -15)]), Art.INK, 1.4)
		else:
			Art.disc(ci, Vector2(sx, -15), 2.4, Art.WHITE)
			Art.disc(ci, Vector2(sx + 0.5, -15), 1.4, Art.INK)
	Art.arc_c(ci, Vector2(0, -9), 4, 0.3, PI - 0.3, 6, Art.INK, 1.4)
	Art.pop(ci)


## Terrarium (the jungle's aquarium): 1 a jar on a stump ... 5 a grand
## glass house with a waterfall, glowing mushrooms and fireflies. `t` lives it.
static func j_terrarium(ci: CanvasItem, level: int, t: float) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		spot(ci, "aquarium")
		return
	var blink := fposmod(t, 3.7) < 0.14
	var puff := fposmod(t * 0.8, 2.0) < 0.35
	if lv == 1:
		# A tree stump with a glass jar: a sprout and a ladybug.
		Art.t_rect(ci, Rect2(-24, -50, 48, 50), 6, Color("9a6a3a"), 2.6, 0.4)
		Art.t_ellipse(ci, Vector2(0, -50), Vector2(24, 6), Color("d8b07a"), 2.2, 0.0)
		Art.ring(ci, Art.ellipse_pts(Vector2(0, -50), Vector2(14, 3), 12), Color("a87a4a"), 1.6)
		var c := Vector2(0, -86)
		Art.flat(ci, Art.rrect_pts(Rect2(c.x - 26, c.y - 28, 52, 62), 12), Color(0.8, 0.95, 0.9, 0.45))
		Art.flat(ci, Art.rrect_pts(Rect2(c.x - 24, c.y + 18, 48, 14), 6), Color("7a5a3a"))
		Art.stroke(ci, PackedVector2Array([c + Vector2(0, 20), c + Vector2(0, 2)]), FactoryArt.LEAF_DARK, 3.0, 1.4)
		Art.t_ellipse(ci, c + Vector2(-7, 0), Vector2(8, 4), FactoryArt.LEAF, 1.8, 0.2, -0.4)
		Art.t_ellipse(ci, c + Vector2(7, -3), Vector2(8, 4), FactoryArt.LEAF_LIGHT, 1.8, 0.2, 0.4)
		var lb := c + Vector2(-12 + Props._q(fposmod(t * 0.15, 1.0), 12) * 24.0, 16)
		Art.t_circle(ci, lb, 3.5, Art.RED, 1.4, 0.0)
		Art.disc(ci, lb + Vector2(0, -0.5), 1.0, Art.INK)
		Art.ring(ci, Art.rrect_pts(Rect2(c.x - 26, c.y - 28, 52, 62), 12), Art.INK, 2.6)
		Art.t_rect(ci, Rect2(c.x - 18, c.y - 36, 36, 9), 3, Color("c9a26a"), 2.2, 0.3)
		return
	var hw := 40.0 + (lv - 2) * 10.0
	var th := 70.0 + (lv - 2) * 12.0
	var stand := 60.0
	var wood := FactoryArt.BAMBOO if lv == 2 else (TEAK if lv < 5 else TEAK_DARK)
	# Stand.
	if lv == 2:
		Art.t_rect(ci, Rect2(-hw - 4, -stand, hw * 2.0 + 8, 10), 3, wood, 2.6, 0.3)
		for x: float in [-hw + 4, hw - 4]:
			FactoryArt._bamboo(ci, Vector2(x, -stand + 6), Vector2(x, 0), 9.0)
		FactoryArt._bamboo(ci, Vector2(-hw + 2, -18), Vector2(hw - 2, -18), 7.0)
	else:
		Art.t_rect(ci, Rect2(-hw - 4, -stand, hw * 2.0 + 8, stand), 4, wood, 2.8, 0.4)
		var pr := Rect2(-hw + 6, -stand + 10, hw * 2.0 - 12, stand - 20)
		Art.ring(ci, Art.rrect_pts(pr, 3), Art.GOLD if lv == 5 else Art.shade_of(wood, 0.3), 2.0)
		FactoryArt.glyph(ci, pr.get_center(), 2 if lv == 5 else 1, wood)
	var r := Rect2(-hw, -stand - th, hw * 2.0, th)
	if lv >= 4:
		Props.halo(ci, r.get_center(), hw * 1.5, Color(0.5, 1.0, 0.6, 0.2))
	Art.grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color("c8f0d0"), Color("c8f0d0"), Color("6ac08a"), Color("6ac08a")]))
	# Soil, moss, a log and plants.
	Art.flat(ci, Art.rrect_pts(Rect2(r.position.x, r.end.y - 16, r.size.x, 16), 0.0), Color("6a4a2a"))
	Art.flat(ci, Art.ellipse_pts(Vector2(r.position.x + r.size.x * 0.3, r.end.y - 15), Vector2(r.size.x * 0.3, 5), 14), Color("4fae4e"))
	Art.flat(ci, Art.ellipse_pts(Vector2(r.end.x - r.size.x * 0.25, r.end.y - 15), Vector2(r.size.x * 0.22, 4), 12), Color("6fd45c"))
	var sway := Props._q(sin(t * 1.4), 6) * 0.06
	Art.push(ci, Vector2(r.position.x + 12, r.end.y - 12), sway)
	FactoryArt._leaf(ci, Vector2.ZERO, th * 0.5, -1.25, FactoryArt.LEAF)
	FactoryArt._leaf(ci, Vector2.ZERO, th * 0.38, -0.7, FactoryArt.LEAF_LIGHT)
	Art.pop(ci)
	Art.push(ci, Vector2(r.end.x - 10, r.end.y - 12), -sway)
	FactoryArt._leaf(ci, Vector2.ZERO, th * 0.44, -1.95, FactoryArt.LEAF_DARK)
	Art.pop(ci)
	if lv >= 3:
		# A mossy rock with a trickle of water and a little pool.
		var rx := r.position.x + r.size.x * 0.72
		Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(rx - 16, r.end.y - 14), Vector2(rx - 12, r.end.y - 40), Vector2(rx + 4, r.end.y - 46),
				Vector2(rx + 14, r.end.y - 30), Vector2(rx + 14, r.end.y - 14)]), 2), Color("a89a88"), 2.2, 0.5)
		Art.flat(ci, Art.ellipse_pts(Vector2(rx - 2, r.end.y - 42), Vector2(10, 4), 10), Color("5cc06a"))
		Art.flat(ci, Art.ellipse_pts(Vector2(rx - 22, r.end.y - 12), Vector2(14, 4), 12), Color("5ad2ff"))
		var f := Props._q(fposmod(t * 1.2, 1.0), 6)
		Art.line_c(ci, PackedVector2Array([Vector2(rx - 12, r.end.y - 38), Vector2(rx - 16, r.end.y - 14)]), Color(0.75, 0.95, 1.0, 0.9), 3.0)
		Art.dot(ci, Vector2(rx - 13 - f * 3.0, r.end.y - 36 + f * 22.0), 1.8, Art.WHITE)
	if lv >= 4:
		# Glowing mushrooms.
		for k in 3:
			var m := Vector2(r.position.x + 22 + k * 9, r.end.y - 14)
			Art.line_c(ci, PackedVector2Array([m, m + Vector2(0, -6 - k * 2)]), Art.CREAM, 2.4)
			Art.t_ellipse(ci, m + Vector2(0, -7 - k * 2), Vector2(5 + k, 3), Color("ff7ab8") if k != 1 else Color("8fe0ff"), 1.6, 0.0)
	# The frog(s) on the moss.
	var cols := [Color("5cd05f"), Color("ff8a3c"), Color("3aa6f0")]
	var nf := 1 if lv < 4 else 2
	for i in nf:
		var hop := fposmod(t * 0.23 + i * 0.5, 1.0)
		var hy := -sin(clampf((hop - 0.9) / 0.1, 0.0, 1.0) * PI) * 10.0
		var fp := Vector2(r.position.x + r.size.x * (0.36 + i * 0.28), r.end.y - 14 + hy)
		_frog(ci, fp, 0.9 + (lv - 2) * 0.08, blink if i == 0 else fposmod(t + 1.3, 4.1) < 0.14, puff and i == 0, cols[(i + lv) % 3])
	if lv >= 5:
		# Fireflies.
		for i in 4:
			var ph := t * (0.5 + i * 0.13) + i * 1.9
			var p := r.get_center() + Vector2(sin(ph) * (hw - 14), cos(ph * 1.3) * th * 0.28 - th * 0.1)
			var on := Props._q(0.5 + 0.5 * sin(t * 3.0 + i * 2.0), 4)
			Art.dot(ci, p, 2.4, Color(1.0, 1.0, 0.55, 0.4 + 0.6 * on))
	# A butterfly resting inside (levels 3+).
	if lv >= 3:
		Art.push(ci, r.position + Vector2(r.size.x * 0.25, th * 0.3))
		FactoryArt.butterfly(ci, fposmod(t * 0.6, 1.0) if fposmod(t * 0.6, 3.0) < 1.0 else 0.0, Color("ff8a2a"))
		Art.pop(ci)
	# Glass, frame and a carved roof.
	Art.flat(ci, PackedVector2Array([r.position + Vector2(8, 4), r.position + Vector2(18, 4), r.position + Vector2(8, th - 8), r.position + Vector2(-0.0, th - 8)]), Color(1, 1, 1, 0.3))
	Art.ring(ci, Art.rrect_pts(r, 4), Art.INK, 3.0)
	var roof := Art.GOLD if lv == 5 else wood
	Art.toon(ci, PackedVector2Array([Vector2(r.position.x - 6, r.position.y + 2), Vector2(r.position.x + 10, r.position.y - 14),
			Vector2(r.end.x - 10, r.position.y - 14), Vector2(r.end.x + 6, r.position.y + 2)]), roof, 2.6, 0.4)
	Art.disc(ci, Vector2(0, r.position.y - 6), 3.0, FactoryArt.JADE)


## A hanging lamp (origin on the ceiling): 1 an oil lantern, 2 a rattan
## pendant, 3..5 a ceiling fan with a lantern under it. `t` turns the fan.
static func j_lamp(ci: CanvasItem, level: int, t: float, light: bool = true) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		spot(ci, "lamp")
		return
	var cord: float = [70.0, 66.0, 56.0, 44.0, 40.0, 36.0][lv]
	Art.line_c(ci, PackedVector2Array([Vector2.ZERO, Vector2(0, cord)]), Color("6a4a2a"), 2.5)
	var warm := Color(1.0, 0.82, 0.45, [0.18, 0.28, 0.32, 0.34, 0.4, 0.5][lv])
	if light:
		Props.halo(ci, Vector2(0, cord + 24), 50 + lv * 14.0, warm)
	var fl := Props._q(0.88 + 0.12 * sin(t * 8.0) * sin(t * 4.7), 4)
	match lv:
		1:
			Art.toon(ci, PackedVector2Array([Vector2(-10, cord + 8), Vector2(0, cord), Vector2(10, cord + 8)]), Art.BRASS, 2.0, 0.2)
			Art.t_rect(ci, Rect2(-10, cord + 8, 20, 26), 4, Color(1.0, 0.9, 0.6, 0.85), 2.2, 0.0)
			Art.disc(ci, Vector2(0, cord + 22), 4.0 * fl, Color("ff9a3a"))
			for x: float in [-10.0, 10.0]:
				Art.line_c(ci, PackedVector2Array([Vector2(x, cord + 8), Vector2(x, cord + 34)]), Art.BRASS, 2.2)
			Art.t_rect(ci, Rect2(-12, cord + 33, 24, 5), 2, Art.BRASS, 1.8, 0.0)
		2:
			var dome := Art.smooth_pts(PackedVector2Array([Vector2(-28, cord + 26), Vector2(-22, cord + 6), Vector2(0, cord - 2), Vector2(22, cord + 6), Vector2(28, cord + 26)]), 3)
			Art.toon(ci, dome, RATTAN, 2.6, 0.5)
			for k in 4:
				var y := cord + 6.0 + k * 5.0
				var hw := 18.0 + k * 2.6
				Art.line_c(ci, PackedVector2Array([Vector2(-hw, y), Vector2(hw, y)]), RATTAN_DARK, 1.4)
			for x: float in [-14.0, 0.0, 14.0]:
				Art.line_c(ci, PackedVector2Array([Vector2(x * 0.6, cord + 2), Vector2(x * 1.6, cord + 25)]), RATTAN_DARK, 1.4)
			Art.t_circle(ci, Vector2(0, cord + 27), 6.5 * fl, Color("fff3c4"), 1.8, 0.0)
		3, 4, 5:
			var blade := RATTAN if lv == 3 else (TEAK if lv == 4 else Art.GOLD)
			var n := 4 if lv < 5 else 5
			var L := 46.0 + lv * 4.0
			var rot := snappedf(fposmod(t * 2.4, TAU), TAU / 48.0)
			var hub := Vector2(0, cord)
			# Leaf-shaped blades seen a little from below: the far ones first,
			# then the motor, then the near ones.
			var bp := Art.smooth_pts(PackedVector2Array([Vector2(8, -3), Vector2(L * 0.4, -11), Vector2(L * 0.85, -9), Vector2(L, 0),
					Vector2(L * 0.85, 9), Vector2(L * 0.4, 11), Vector2(8, 3)]), 2)
			for front in 2:
				for i in n:
					var a := rot + i * TAU / n
					if (sin(a) > 0.0) != (front == 1):
						continue
					Art.push(ci, hub + Vector2(0, 4), 0.0, Vector2(1.0, 0.34))
					Art.push(ci, Vector2.ZERO, a)
					Art.toon(ci, bp, blade if front == 1 else Art.shade_of(blade, 0.22), 2.4, 0.3)
					Art.line_c(ci, PackedVector2Array([Vector2(10, 0), Vector2(L - 6, 0)]), Art.shade_of(blade, 0.3) if lv < 5 else Art.GOLD_DARK, 2.0)
					Art.pop(ci)
					Art.pop(ci)
				if front == 0:
					Art.t_rect(ci, Rect2(-7, cord - 10, 14, 8), 2, Art.BRASS if lv < 5 else Art.GOLD, 2.0, 0.2)
					Art.t_ellipse(ci, Vector2(0, cord + 4), Vector2(13, 7), Art.BRASS if lv < 5 else Art.GOLD, 2.2, 0.5)
			# The lantern under the fan.
			var lc := Color(1.0, 0.92, 0.6, 0.9) if lv < 4 else Color(0.6, 1.0, 0.85, 0.9)
			Art.line_c(ci, PackedVector2Array([Vector2(0, cord + 4), Vector2(0, cord + 10)]), Art.INK, 2.0)
			Art.t_ellipse(ci, Vector2(0, cord + 20), Vector2(11, 11), lc, 2.2, 0.0)
			Art.disc(ci, Vector2(0, cord + 21), 4.2 * fl, Color("ffcf5a"))
			Art.t_rect(ci, Rect2(-7, cord + 8, 14, 4), 2, Art.BRASS, 1.6, 0.0)
			if lv == 5:
				for i in 3:
					var ph := fposmod(t * 0.7 + i * 0.33, 1.0)
					Art.dot(ci, Vector2(-30 + i * 30, cord + 30 + ph * 14), 2.5 * (1.0 - ph), Color(1, 1, 0.8, 1.0 - ph))


## A carved tribal mask (origin center), smiling.
static func _mask(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	Art.push(ci, at, 0.0, Vector2(s, s))
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.32
		Art.toon(ci, Art.ellipse_pts(Vector2.from_angle(a) * 16.0, Vector2(4, 9), 8, a + PI * 0.5), J_BLOOMS[k % 3], 1.4, 0.0)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-11, -12), Vector2(11, -12), Vector2(12, 4), Vector2(6, 15), Vector2(-6, 15), Vector2(-12, 4)]), 2), col, 2.2, 0.5)
	var deep := Art.shade_of(col, 0.4)
	Art.flat(ci, Art.ellipse_pts(Vector2(-5, -3), Vector2(3.5, 2.2), 8), deep)
	Art.flat(ci, Art.ellipse_pts(Vector2(5, -3), Vector2(3.5, 2.2), 8), deep)
	Art.flat(ci, Art.rrect_pts(Rect2(-1.5, -2, 3, 7), 1), deep)
	Art.arc_c(ci, Vector2(0, 5), 5, 0.3, PI - 0.3, 6, deep, 2.0)
	Art.line_c(ci, PackedVector2Array([Vector2(-9, 2), Vector2(-6, 5)]), Art.WHITE, 1.4)
	Art.line_c(ci, PackedVector2Array([Vector2(9, 2), Vector2(6, 5)]), Art.WHITE, 1.4)
	Art.pop(ci)


## A green jade gem (origin bottom).
static func _gem(ci: CanvasItem, at: Vector2, s: float) -> void:
	Art.toon(ci, PackedVector2Array([at + Vector2(-7, -8) * s, at + Vector2(-3, -13) * s, at + Vector2(3, -13) * s, at + Vector2(7, -8) * s, at]), FactoryArt.JADE, 1.8, 0.4)
	Art.line_c(ci, PackedVector2Array([at + Vector2(-7, -8) * s, at + Vector2(7, -8) * s]), Color(1, 1, 1, 0.5), 1.2)


## Trophy shelf of relics (origin at its middle): 1 a pot ... 5 a stone
## niche with a glowing golden idol.
static func j_trophy(ci: CanvasItem, level: int, t: float) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		spot(ci, "trophy")
		return
	if lv == 5:
		Art.t_rect(ci, Rect2(-72, -68, 144, 96), 6, Color("c8b07a"), 3.0, 0.3)
		Art.flat(ci, Art.rrect_pts(Rect2(-62, -58, 124, 78), 4), Color("6a4a3a"))
		Art.ring(ci, Art.rrect_pts(Rect2(-68, -64, 136, 88), 5), Art.GOLD, 2.4)
		var gx := -60.0
		while gx < 58.0:
			Art.line_c(ci, PackedVector2Array([Vector2(gx, -62), Vector2(gx, -66), Vector2(gx + 8, -66), Vector2(gx + 8, -63)]), Art.GOLD_DARK, 1.6)
			gx += 14.0
	elif lv == 4:
		Art.t_rect(ci, Rect2(-70, -60, 140, 82), 4, TEAK_DARK, 3.0, 0.2)
		Art.ring(ci, Art.rrect_pts(Rect2(-64, -54, 128, 70), 3), Color("e0a050"), 2.0)
	var planks := [18.0] if lv < 3 else [18.0, -24.0]
	for y in planks:
		if lv <= 2:
			FactoryArt._bamboo(ci, Vector2(-68, float(y) + 4.0), Vector2(68, float(y) + 4.0), 10.0)
		else:
			Art.t_rect(ci, Rect2(-66, float(y), 132, 9), 2, TEAK if lv < 5 else Art.GOLD, 2.6, 0.3)
	if lv <= 2:
		for x: float in [-46.0, 46.0]:
			Art.line_c(ci, PackedVector2Array([Vector2(x - 4, 18), Vector2(x + 4, 30)]), Color("8a6a3a"), 2.4)
			Art.line_c(ci, PackedVector2Array([Vector2(x + 4, 18), Vector2(x - 4, 30)]), Color("8a6a3a"), 2.4)
	match lv:
		1:
			FactoryArt._pot(ci, Vector2(0, 18), 10.0)
		2:
			FactoryArt._pot(ci, Vector2(-28, 18), 10.0)
			_frog(ci, Vector2(26, 18), 0.95, false, false, FactoryArt.JADE)
		3:
			Art.push(ci, Vector2(-34, 18))
			FactoryArt.idol(ci, 1.6)
			Art.pop(ci)
			_mask(ci, Vector2(18, -4), 0.85, Color("c98249"))
			_gem(ci, Vector2(-30, -24), 1.0)
			# A rolled scroll.
			Art.t_rect(ci, Rect2(14, -36, 34, 10), 5, PARCH, 2.0, 0.3)
			Art.line_c(ci, PackedVector2Array([Vector2(31, -36), Vector2(31, -26)]), Art.RED, 1.8)
		4:
			_mask(ci, Vector2(-38, -4), 0.8, Color("2bb8b4"))
			Art.push(ci, Vector2(0, 18))
			FactoryArt.idol(ci, 2.0)
			Art.pop(ci)
			_mask(ci, Vector2(38, -4), 0.8, Color("ff8a5c"))
			FactoryArt._pot(ci, Vector2(-34, -24), 8.0)
			_gem(ci, Vector2(0, -24), 1.2)
			Art.push(ci, Vector2(34, -24))
			FactoryArt.idol(ci, 1.1)
			Art.pop(ci)
		5:
			Props.halo(ci, Vector2(0, -10), 56, Color(1.0, 0.85, 0.3, 0.3 + 0.08 * Props._q(sin(t * 2.0), 4)))
			Art.push(ci, Vector2(0, 18))
			FactoryArt.idol(ci, 3.0)
			Art.pop(ci)
			_mask(ci, Vector2(-44, -30), 0.75, FactoryArt.JADE)
			_mask(ci, Vector2(44, -30), 0.75, FactoryArt.JADE)
			_gem(ci, Vector2(-44, 18), 1.2)
			_gem(ci, Vector2(44, 18), 1.2)
			var ph := fposmod(t * 0.8, 1.0)
			Art.dot(ci, Vector2(-16 + ph * 8, -40), 3.0 * (1.0 - ph), Color(1, 1, 0.8, 1.0 - ph))
			Art.dot(ci, Vector2(18, -28 - ph * 8), 2.6 * ph, Color(1, 1, 0.8, ph))


## Jungle plant: 1 a sprout ... 3 a monstera, 4 a bird of paradise, 5 a
## palm in a gold pot with flowers.
static func j_plant(ci: CanvasItem, level: int, t: float) -> void:
	var lv := clampi(level, 0, 5)
	if lv == 0:
		spot(ci, "plant")
		return
	var sway := Props._q(sin(t * 1.3), 8) * 0.04
	var pot: Color = [FactoryArt.TERRACOTTA, FactoryArt.TERRACOTTA, FactoryArt.TERRACOTTA, Color("c8b07a"), FactoryArt.JADE, Art.GOLD][lv]
	var pw := 22.0 + lv * 2.0
	Art.push(ci, Vector2(0, -34), sway)
	match lv:
		1:
			Art.stroke(ci, PackedVector2Array([Vector2(0, 0), Vector2(0, -16)]), FactoryArt.LEAF_DARK, 3.0, 1.6)
			FactoryArt._leaf(ci, Vector2(0, -14), 16, -2.6, FactoryArt.LEAF)
			FactoryArt._leaf(ci, Vector2(0, -16), 16, -0.5, FactoryArt.LEAF_LIGHT)
		2:
			# A fern: arched fronds with little leaflets.
			for a: float in [-1.05, -0.5, 0.0, 0.5, 1.05]:
				var pts := PackedVector2Array()
				for k in 6:
					var u := k / 5.0
					pts.append(Vector2(sin(a) * 60.0 * u + sin(a) * 20.0 * u * u, -cos(a) * 56.0 * u + 26.0 * u * u))
				Art.stroke(ci, pts, FactoryArt.LEAF_DARK, 2.4, 1.2)
				for k in range(1, 6):
					var d := (pts[k] - pts[k - 1]).normalized()
					var o := d.orthogonal() * (11.0 - k)
					Art.toon(ci, PackedVector2Array([pts[k] - d * 7, pts[k] + o - d * 2, pts[k] + d * 3]), FactoryArt.LEAF, 1.4, 0.0)
					Art.toon(ci, PackedVector2Array([pts[k] - d * 7, pts[k] - o - d * 2, pts[k] + d * 3]), FactoryArt.LEAF_LIGHT, 1.4, 0.0)
		3:
			# Monstera: big heart leaves with slits.
			for e: Array in [[Vector2(-18, -50), -0.5, 26.0], [Vector2(18, -60), 0.45, 28.0], [Vector2(-2, -86), 0.0, 24.0]]:
				var c: Vector2 = e[0]
				Art.stroke(ci, PackedVector2Array([Vector2.ZERO, c * 0.5 + Vector2(0, -8), c]), FactoryArt.LEAF_DARK, 3.0, 1.2)
				Art.push(ci, c, float(e[1]))
				var R: float = e[2]
				var shape := Art.smooth_pts(PackedVector2Array([Vector2(0, R * 0.7), Vector2(-R, R * 0.1), Vector2(-R * 0.8, -R * 0.7), Vector2(0, -R * 0.9),
						Vector2(R * 0.8, -R * 0.7), Vector2(R, R * 0.1)]), 3)
				Art.toon(ci, shape, Color("2f9a45"), 2.4, 0.5)
				Art.line_c(ci, PackedVector2Array([Vector2(0, R * 0.6), Vector2(0, -R * 0.8)]), Color("6fd45c"), 1.6)
				for sx: float in [-1.0, 1.0]:
					Art.flat(ci, Art.ellipse_pts(Vector2(sx * R * 0.5, -R * 0.1), Vector2(R * 0.22, 2.6), 8, sx * 0.4), Color("1f6a3a"))
					Art.flat(ci, Art.ellipse_pts(Vector2(sx * R * 0.45, R * 0.3), Vector2(R * 0.18, 2.2), 8, -sx * 0.3), Color("1f6a3a"))
				Art.pop(ci)
		4:
			# Bird of paradise: tall paddle leaves and an orange flower.
			for e: Array in [[-0.5, 70.0, FactoryArt.LEAF], [0.35, 78.0, FactoryArt.LEAF_DARK], [-0.05, 92.0, FactoryArt.LEAF_LIGHT]]:
				var a: float = e[0]
				var tip := Vector2(sin(a), -cos(a)) * float(e[1]) * 0.6
				Art.stroke(ci, PackedVector2Array([Vector2.ZERO, tip]), FactoryArt.LEAF_DARK, 3.0, 1.2)
				FactoryArt._leaf(ci, tip, float(e[1]) * 0.55, a - PI * 0.5, e[2])
			var fp := Vector2(16, -64)
			Art.stroke(ci, PackedVector2Array([Vector2(4, 0), Vector2(10, -40), fp]), FactoryArt.LEAF_DARK, 3.0, 1.2)
			Art.toon(ci, PackedVector2Array([fp + Vector2(-4, 2), fp + Vector2(22, -2), fp + Vector2(-2, -4)]), Color("3a7ae0"), 1.6, 0.0)
			for k in 3:
				Art.toon(ci, PackedVector2Array([fp + Vector2(0, -2), fp + Vector2(6 + k * 4, -22 + k * 3), fp + Vector2(10 + k * 4, -16 + k * 3)]), Color("ff8a2a") if k != 1 else Color("ffd23f"), 1.6, 0.0)
		5:
			# A little palm with coconuts and flowers at its foot.
			var trunk := PackedVector2Array([Vector2(0, 0), Vector2(-3, -30), Vector2(2, -62), Vector2(6, -88)])
			Art.stroke(ci, trunk, Color("a87a4a"), 9.0, 2.2)
			for k in range(1, 4):
				Art.line_c(ci, PackedVector2Array([trunk[k] + Vector2(-4, 0), trunk[k] + Vector2(4, 2)]), Color("7a5a3a"), 1.6)
			var top := Vector2(6, -90)
			for a: float in [-2.7, -2.1, -1.5, -0.9, -0.3, 0.3]:
				FactoryArt._leaf(ci, top, 44.0, a + (0.2 if a < -1.5 else -0.2), FactoryArt.LEAF if int(a * 10.0) % 2 == 0 else FactoryArt.LEAF_LIGHT)
			for d: Vector2 in [Vector2(-4, 4), Vector2(5, 5)]:
				Art.t_circle(ci, top + d, 4.5, Color("8a5a2c"), 1.6, 0.3)
			for k in 3:
				FactoryArt._flower(ci, Vector2(-16 + k * 16, -4 - (k % 2) * 6), 5.0, J_BLOOMS[k])
	Art.pop(ci)
	# The pot, with a carved band.
	var body := PackedVector2Array([Vector2(-pw, -38), Vector2(pw, -38), Vector2(pw - 6, 0), Vector2(-pw + 6, 0)])
	Art.toon(ci, body, pot, 2.8, 0.5)
	Art.flat(ci, Art.rrect_pts(Rect2(-pw + 4, -26, pw * 2.0 - 8, 6), 0.0), FactoryArt.JADE if lv != 4 else Art.GOLD)
	var zx := -pw + 8.0
	while zx < pw - 10.0:
		Art.line_c(ci, PackedVector2Array([Vector2(zx, -13), Vector2(zx + 4, -18), Vector2(zx + 8, -13)]), Art.shade_of(pot, 0.3), 1.6)
		zx += 9.0
	Art.t_rect(ci, Rect2(-pw - 3, -42, pw * 2.0 + 6, 9), 3, Art.shade_of(pot, 0.1), 2.4, 0.2)
	Art.flat(ci, Art.ellipse_pts(Vector2(0, -38), Vector2(pw - 4, 3), 12), Color("5a3a2a"))
	if lv == 5:
		var ph := fposmod(t * 0.6, 1.0)
		Art.dot(ci, Vector2(-30, -120 + ph * 20), 3.0 * (1.0 - ph), Color(1, 1, 0.7, 1.0 - ph))


## The explorer's wardrobe: carved teak with a smiling totem face on each
## door and a pith helmet on top (origin bottom center); `open` swings the doors.
static func j_wardrobe(ci: CanvasItem, open: float, outfit_color: Color) -> void:
	var body := TEAK
	Art.t_rect(ci, Rect2(-48, -196, 96, 192), 6, body, 3.0, 0.5)
	Art.t_rect(ci, Rect2(-52, -206, 104, 16), 4, TEAK_DARK, 2.8, 0.3)
	var gx := -48.0
	while gx < 44.0:
		Art.line_c(ci, PackedVector2Array([Vector2(gx, -194), Vector2(gx, -202), Vector2(gx + 8, -202), Vector2(gx + 8, -197)]), Color("e0a050"), 1.6)
		gx += 12.0
	_legs4(ci, [-40, 40], -6, TEAK_DARK, 8)
	var inside := Rect2(-42, -186, 84, 170)
	Art.flat(ci, Art.rrect_pts(inside, 3), Color("4a2a20"))
	Art.line_c(ci, PackedVector2Array([Vector2(-40, -170), Vector2(40, -170)]), FactoryArt.BAMBOO, 3.0)
	var cols := [outfit_color, Color("c9a26a"), Color("5cc06a"), Art.CORAL]
	for i in 4:
		var x := -30.0 + i * 20.0
		Art.toon(ci, PackedVector2Array([Vector2(x - 8, -164), Vector2(x + 8, -164), Vector2(x + 10, -110), Vector2(x - 10, -110)]), cols[i], 2.2, 0.4)
	var o := clampf(open, 0.0, 1.0)
	var dw := 42.0 * (1.0 - o * 0.75)
	for side: float in [-1.0, 1.0]:
		var x0 := -42.0 if side < 0 else 42.0 - dw
		Art.t_rect(ci, Rect2(x0, -186, dw, 170), 4, body.lightened(0.08), 2.8, 0.4)
		if dw > 20.0:
			var face := Rect2(x0 + 6, -176, dw - 12, 70)
			Art.ring(ci, Art.rrect_pts(face, 3), Art.shade_of(body, 0.3), 2.0)
			# A carved smiling face (the totem).
			var fc := face.get_center()
			var deep := Art.shade_of(body, 0.36)
			Art.flat(ci, Art.rrect_pts(Rect2(fc.x - 9, fc.y - 16, 7, 5), 2), deep)
			Art.flat(ci, Art.rrect_pts(Rect2(fc.x + 2, fc.y - 16, 7, 5), 2), deep)
			Art.disc(ci, Vector2(fc.x - 5.5, fc.y - 13.5), 1.4, FactoryArt.JADE)
			Art.disc(ci, Vector2(fc.x + 5.5, fc.y - 13.5), 1.4, FactoryArt.JADE)
			Art.flat(ci, Art.rrect_pts(Rect2(fc.x - 2, fc.y - 9, 4, 9), 1), deep)
			Art.arc_c(ci, Vector2(fc.x, fc.y + 6), 8, 0.2, PI - 0.2, 8, deep, 2.6)
			Art.line_c(ci, PackedVector2Array([Vector2(face.position.x + 3, face.position.y + 6), Vector2(face.end.x - 3, face.position.y + 6)]), Color("e0a050"), 2.0)
			Art.ring(ci, Art.rrect_pts(Rect2(x0 + 6, -98, dw - 12, 72), 3), Art.shade_of(body, 0.3), 2.0)
			FactoryArt.glyph(ci, Vector2(x0 + dw / 2.0, -62), 0, body.lightened(0.08))
			var kx := x0 + dw - 7.0 if side < 0 else x0 + 7.0
			Art.t_circle(ci, Vector2(kx, -104), 3.5, Art.GOLD, 1.6, 0.0)
	# The hanger sign on top, with a pith helmet resting beside it.
	Art.t_circle(ci, Vector2(0, -220), 14, Art.WHITE, 2.4, 0.2)
	Art.line_c(ci, PackedVector2Array([Vector2(-9, -214), Vector2(0, -222), Vector2(9, -214), Vector2(-9, -214)]), Art.INK, 2.2)
	Art.arc_c(ci, Vector2(0, -225), 3, PI, TAU * 1.25, 6, Art.INK, 2.0)
	Art.t_ellipse(ci, Vector2(-30, -208), Vector2(18, 4), Color("e8d8a8"), 2.0, 0.2)
	Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-42, -208), Vector2(-40, -220), Vector2(-30, -226), Vector2(-20, -220), Vector2(-18, -208)]), 2), Color("f0e2b8"), 2.2, 0.4)
	Art.flat(ci, Art.rrect_pts(Rect2(-41, -213, 22, 4), 1), Color("8a6a3a"))


## One decor piece in the look of `world` (the jungle has its own set):
## slot desk / sofa / aquarium / lamp / trophy / plant / chair.
static func piece(ci: CanvasItem, slot: String, level: int, t: float, world: String, light: bool = true) -> void:
	var jg := is_jungle(world)
	match slot:
		"desk":
			if jg:
				j_desk(ci, level, t)
			else:
				desk(ci, level, t)
		"chair":
			if jg:
				j_chair(ci, level)
			else:
				chair(ci, level)
		"sofa":
			if jg:
				j_sofa(ci, level)
			else:
				sofa(ci, level)
		"aquarium":
			if jg:
				j_terrarium(ci, level, t)
			else:
				aquarium(ci, level, t)
		"lamp":
			if jg:
				j_lamp(ci, level, t, light)
			else:
				lamp(ci, level, t, light)
		"trophy":
			if jg:
				j_trophy(ci, level, t)
			else:
				trophy(ci, level, t)
		"plant":
			if jg:
				j_plant(ci, level, t)
			else:
				plant(ci, level, t)


## The wall (or floor) swatch of `world` for the decor panel: w x h.
static func wall_in(ci: CanvasItem, w: float, h: float, level: int, world: String) -> void:
	if is_jungle(world):
		j_wall(ci, w, h, level)
	else:
		wallpaper(ci, w, h, level)


static func floor_in(ci: CanvasItem, w: float, y0: float, y1: float, level: int, world: String) -> void:
	if is_jungle(world):
		j_floor(ci, w, y0, y1, level)
	else:
		floor_band(ci, w, y0, y1, level)
