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
	{"a": Color("d9d2c6"), "b": Color("cfc7ba")},
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


const FLOORS := [Color("aeb1b8"), Color("d39a62"), Color("c9874b"), Color("f3ead6"), Color("b9773f"), Color("f4f1f8")]


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
