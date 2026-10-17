class_name TileAtlantis
extends RefCounted
## Atlantis' puzzle pieces (TileWorlds world 6), drawn around (0, 0) in a
## ~44 px cell: amphora, sun coin, orichalcum gem, bronze cog, wave shell,
## laurel crown.

const _W := 3.0


static func piece(ci: CanvasItem, slot: int, t: float, col: Color) -> void:
	match slot:
		0:
			# Amphora.
			Art.push(ci, Vector2(0, 21), 0.0, Vector2(0.95, 0.95))
			AtlantisArt.amphora(ci, col, Color("2a2a3a"))
			Art.pop(ci)
		1:
			# A gold sun coin.
			Art.t_circle(ci, Vector2.ZERO, 19.0, col, _W, 0.6)
			Art.arc(ci, Vector2.ZERO, 13.0, 0.0, TAU, 20, col.darkened(0.25), 2.0)
			for k in 8:
				var a := k * TAU / 8.0
				Art.line(ci, Vector2(cos(a), sin(a)) * 5.0, Vector2(cos(a), sin(a)) * 10.0, col.darkened(0.3), 2.0)
			Art.t_circle(ci, Vector2.ZERO, 4.0, col.lightened(0.3), 1.6, 0.0)
		2:
			# Orichalcum gem.
			var pulse := snappedf(0.5 + 0.5 * sin(t * 2.4), 0.25)
			Art.glow(ci, Vector2.ZERO, 24.0, Color(col, 0.25 + 0.2 * pulse))
			Art.toon(ci, PackedVector2Array([Vector2(0, -20), Vector2(16, -6), Vector2(10, 18), Vector2(-10, 18), Vector2(-16, -6)]), col, _W, 0.6)
			Art.line(ci, Vector2(-16, -6), Vector2(16, -6), Color(Art.INK, 0.4), 1.6)
			Art.line(ci, Vector2(0, -20), Vector2(0, 18), Color(Art.INK, 0.25), 1.4)
			Art.flat(ci, Art.ellipse_pts(Vector2(-6, -8), Vector2(4, 2.5), 8, -0.5), Color(1, 1, 1, 0.8))
		3:
			# Bronze cog.
			AtlantisArt.cog(ci, Vector2.ZERO, 20.0, 10, col)
		4:
			# A blue wave shell.
			var body := Art.smooth_pts(PackedVector2Array([Vector2(-18, 10), Vector2(-20, -6), Vector2(-6, -20), Vector2(6, -20), Vector2(20, -6), Vector2(18, 10)]), 3)
			Art.toon(ci, body, col, _W, 0.6)
			for x in [-10.0, -3.0, 4.0, 11.0]:
				Art.line(ci, Vector2(x * 0.4, 10), Vector2(x, -15), col.lightened(0.35), 2.0)
			Art.t_rect(ci, Rect2(-8, 8, 16, 7), 2.0, col.darkened(0.15), 2.0, 0.0)
		_:
			# A laurel crown.
			Art.arc(ci, Vector2(0, 4), 16.0, PI * 0.95, PI * 2.05, 14, Color("6a9a3a"), 4.0)
			for k in 7:
				var a := PI + k * PI / 6.0
				Art.t_ellipse(ci, Vector2(0, 4) + Vector2(cos(a), sin(a)) * 16.0, Vector2(6, 3), Color("ffc93c") if k % 2 == 0 else col, 1.4, 0.0, a + PI / 2.0)
			Art.t_circle(ci, Vector2(0, -12), 4.0, Color("4af0e0"), 1.6, 0.0)
