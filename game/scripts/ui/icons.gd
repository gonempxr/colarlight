class_name Icons
extends RefCounted
## Small UI icons rendered once from inline SVG (crisp and anti-aliased
## at any size), cached by name and pixel size.

const INK := "#241a3a"

static var _cache := {}


static func get_icon(name: String, px: int = 32) -> Texture2D:
	var k := "%s@%d" % [name, px]
	if _cache.has(k):
		return _cache[k]
	var svg := _svg(name)
	var img := Image.new()
	if svg == "" or img.load_svg_from_string(svg, px / 64.0) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


static func _svg(name: String) -> String:
	var body := ""
	match name:
		"arrow":
			body = "<path d='M32 6 L58 32 L43 32 L43 58 L21 58 L21 32 L6 32 Z' fill='#ffffff' stroke='%s' stroke-width='7' stroke-linejoin='round'/>" % INK
		"gear":
			var pts := PackedStringArray()
			for i in 32:
				var a := TAU * (i + 0.5) / 32.0
				var r := 27.0 if (i % 4) < 2 else 20.0
				pts.append("%.1f,%.1f" % [32.0 + cos(a) * r, 32.0 + sin(a) * r])
			body = "<polygon points='%s' fill='#ffffff' stroke='%s' stroke-width='6' stroke-linejoin='round'/>" % [" ".join(pts), INK] \
					+ "<circle cx='32' cy='32' r='8' fill='%s'/>" % INK
		"coin":
			body = "<circle cx='32' cy='33' r='27' fill='#e0921c' stroke='%s' stroke-width='5'/>" % INK \
					+ "<circle cx='32' cy='30' r='21' fill='#ffc93c'/>" \
					+ "<path d='M32 17 L36 26 L46 27 L38.5 33.5 L41 43 L32 38 L23 43 L25.5 33.5 L18 27 L28 26 Z' fill='#ffe38a'/>" \
					+ "<ellipse cx='22' cy='19' rx='5' ry='3' fill='#ffffff' opacity='0.85' transform='rotate(-35 22 19)'/>"
		"close":
			body = "<path d='M16 16 L48 48 M48 16 L16 48' stroke='%s' stroke-width='16' stroke-linecap='round'/>" % INK \
					+ "<path d='M16 16 L48 48 M48 16 L16 48' stroke='#ffffff' stroke-width='7' stroke-linecap='round'/>"
		"helmet":
			body = "<rect x='14' y='44' width='36' height='12' rx='5' fill='#d19230' stroke='%s' stroke-width='5'/>" % INK \
					+ "<circle cx='32' cy='30' r='22' fill='#f5b843' stroke='%s' stroke-width='5'/>" % INK \
					+ "<circle cx='34' cy='30' r='13' fill='#dff8ff' stroke='#b8782a' stroke-width='4'/>" \
					+ "<rect x='28' y='3' width='10' height='7' rx='2' fill='#d19230' stroke='%s' stroke-width='4'/>" % INK \
					+ "<ellipse cx='29' cy='25' rx='4' ry='3' fill='#ffffff'/>"
		"plus":
			body = "<path d='M32 12 L32 52 M12 32 L52 32' stroke='%s' stroke-width='18' stroke-linecap='round'/>" % INK \
					+ "<path d='M32 12 L32 52 M12 32 L52 32' stroke='#ffffff' stroke-width='8' stroke-linecap='round'/>"
		"dice":
			body = "<rect x='8' y='8' width='48' height='48' rx='12' fill='#ffffff' stroke='%s' stroke-width='6'/>" % INK
			for p: Vector2 in [Vector2(22, 22), Vector2(42, 22), Vector2(32, 32), Vector2(22, 42), Vector2(42, 42)]:
				body += "<circle cx='%d' cy='%d' r='5' fill='%s'/>" % [p.x, p.y, INK]
		"left", "right":
			var d := "M40 12 L20 32 L40 52" if name == "left" else "M24 12 L44 32 L24 52"
			body = "<path d='%s' fill='none' stroke='%s' stroke-width='18' stroke-linecap='round' stroke-linejoin='round'/>" % [d, INK] \
					+ "<path d='%s' fill='none' stroke='#ffffff' stroke-width='8' stroke-linecap='round' stroke-linejoin='round'/>" % d
	if body == "":
		return ""
	return "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body
