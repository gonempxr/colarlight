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
		"pearl":
			body = "<circle cx='32' cy='34' r='24' fill='#e8dcf5' stroke='%s' stroke-width='5'/>" % INK \
					+ "<circle cx='36' cy='38' r='16' fill='#f7f0ff'/>" \
					+ "<ellipse cx='24' cy='24' rx='8' ry='5' fill='#ffffff' transform='rotate(-35 24 24)'/>" \
					+ "<circle cx='41' cy='44' r='4' fill='#d7c2f0'/>"
		"quests":
			body = "<rect x='12' y='10' width='40' height='48' rx='7' fill='#fff6e4' stroke='%s' stroke-width='5'/>" % INK \
					+ "<rect x='22' y='4' width='20' height='12' rx='4' fill='#3aa6f0' stroke='%s' stroke-width='4'/>" % INK \
					+ "<path d='M20 28 L25 33 L33 24' fill='none' stroke='#5cd05f' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>" \
					+ "<path d='M20 44 L25 49 L33 40' fill='none' stroke='#5cd05f' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>" \
					+ "<path d='M37 29 L45 29 M37 45 L45 45' stroke='%s' stroke-width='4' stroke-linecap='round'/>" % INK
		"puzzle":
			body = "<rect x='6' y='6' width='24' height='24' rx='7' fill='#ff7bc0' stroke='%s' stroke-width='4'/>" % INK \
					+ "<rect x='34' y='6' width='24' height='24' rx='12' fill='#ffd23f' stroke='%s' stroke-width='4'/>" % INK \
					+ "<rect x='6' y='34' width='24' height='24' rx='12' fill='#7be0ff' stroke='%s' stroke-width='4'/>" % INK \
					+ "<path d='M46 34 L57 46 L46 58 L35 46 Z' fill='#5cd05f' stroke='%s' stroke-width='4' stroke-linejoin='round'/>" % INK \
					+ "<circle cx='13' cy='13' r='3' fill='#ffffff'/><circle cx='41' cy='13' r='3' fill='#ffffff'/><circle cx='13' cy='41' r='3' fill='#ffffff'/>"
		"museum":
			body = "<path d='M22 8 L42 8 L40 16 C52 22 54 44 44 54 L20 54 C10 44 12 22 24 16 Z' fill='#e8964a' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK \
					+ "<path d='M16 32 L48 32' stroke='#ffd23f' stroke-width='6'/>" \
					+ "<path d='M22 40 L42 40' stroke='#b8622a' stroke-width='4'/>" \
					+ "<ellipse cx='24' cy='24' rx='3' ry='6' fill='#ffffff' opacity='0.7'/>"
		"wardrobe":
			body = "<path d='M22 8 L12 12 L4 26 L14 32 L16 28 L16 58 L48 58 L48 28 L50 32 L60 26 L52 12 L42 8 C40 14 24 14 22 8 Z' fill='#ff7b54' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK \
					+ "<circle cx='32' cy='38' r='8' fill='#e8dcf5' stroke='%s' stroke-width='4'/>" % INK \
					+ "<ellipse cx='29' cy='35' rx='3' ry='2' fill='#ffffff'/>"
		"gift":
			body = "<rect x='8' y='26' width='48' height='32' rx='5' fill='#ef5350' stroke='%s' stroke-width='5'/>" % INK \
					+ "<rect x='4' y='18' width='56' height='12' rx='4' fill='#ff7b7b' stroke='%s' stroke-width='5'/>" % INK \
					+ "<rect x='27' y='18' width='10' height='40' fill='#ffd23f' stroke='%s' stroke-width='4'/>" % INK \
					+ "<path d='M32 18 C24 4 12 8 18 16 C20 18 26 18 32 18 C38 18 44 18 46 16 C52 8 40 4 32 18 Z' fill='#ffd23f' stroke='%s' stroke-width='4' stroke-linejoin='round'/>" % INK
		"chest":
			body = "<rect x='6' y='28' width='52' height='28' rx='5' fill='#b8743a' stroke='%s' stroke-width='5'/>" % INK \
					+ "<path d='M6 30 C6 12 58 12 58 30 Z' fill='#d8924a' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK \
					+ "<rect x='26' y='24' width='12' height='16' rx='3' fill='#ffd23f' stroke='%s' stroke-width='4'/>" % INK \
					+ "<path d='M14 20 L14 56 M50 20 L50 56' stroke='#ffd23f' stroke-width='5'/>"
		"star", "star_off":
			var fill := "#ffd23f" if name == "star" else "#b9bfd1"
			body = "<path d='M32 5 L40 23 L59 25 L45 38 L49 57 L32 47 L15 57 L19 38 L5 25 L24 23 Z' fill='%s' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % [fill, INK]
		"lock":
			body = "<path d='M20 30 L20 20 C20 6 44 6 44 20 L44 30' fill='none' stroke='%s' stroke-width='9'/>" % INK \
					+ "<path d='M20 30 L20 20 C20 6 44 6 44 20 L44 30' fill='none' stroke='#b9bfd1' stroke-width='3'/>" \
					+ "<rect x='10' y='28' width='44' height='30' rx='7' fill='#ffc93c' stroke='%s' stroke-width='5'/>" % INK \
					+ "<circle cx='32' cy='41' r='5' fill='%s'/><rect x='30' y='42' width='4' height='9' fill='%s'/>" % [INK, INK]
		"bolt":
			body = "<path d='M36 4 L12 36 L30 36 L24 60 L52 24 L34 24 Z' fill='#ffd23f' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK
		"check":
			body = "<path d='M12 34 L26 48 L52 16' fill='none' stroke='%s' stroke-width='16' stroke-linecap='round' stroke-linejoin='round'/>" % INK \
					+ "<path d='M12 34 L26 48 L52 16' fill='none' stroke='#ffffff' stroke-width='7' stroke-linecap='round' stroke-linejoin='round'/>"
		"people":
			body = "<circle cx='22' cy='22' r='11' fill='#ffd0a8' stroke='%s' stroke-width='5'/>" % INK \
					+ "<path d='M4 56 C4 36 40 36 40 56 Z' fill='#3aa6f0' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK \
					+ "<circle cx='44' cy='24' r='9' fill='#c98d5e' stroke='%s' stroke-width='5'/>" % INK \
					+ "<path d='M30 56 C30 40 60 40 60 56 Z' fill='#ff7bc0' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK
		"pencil":
			body = "<path d='M12 44 L40 16 L50 26 L22 54 L10 56 Z' fill='#ffc93c' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK \
					+ "<path d='M40 16 L46 10 L56 20 L50 26 Z' fill='#ff7b7b' stroke='%s' stroke-width='5' stroke-linejoin='round'/>" % INK
		"knob":
			body = "<circle cx='32' cy='32' r='26' fill='#ffffff' stroke='%s' stroke-width='6'/>" % INK \
					+ "<circle cx='32' cy='32' r='12' fill='#ffc93c'/>"
		"play":
			body = "<path d='M18 8 L54 32 L18 56 Z' fill='#ffffff' stroke='%s' stroke-width='7' stroke-linejoin='round'/>" % INK
	if body == "":
		return ""
	return "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body
