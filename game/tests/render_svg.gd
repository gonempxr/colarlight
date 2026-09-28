extends SceneTree
## Rasterizes an SVG to PNG with Godot's own SVG renderer:
##   godot --headless --path game -s res://../tools/render_svg.gd -- in.svg out.png [scale] [bg_hex]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var text := FileAccess.get_file_as_string(a[0])
	var img := Image.new()
	var err := img.load_svg_from_string(text, float(a[2]) if a.size() > 2 else 1.0)
	if err != OK:
		push_error("svg load failed %d" % err)
		quit(1)
		return
	if a.size() > 3:
		var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color(a[3]))
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		img = bg
	img.save_png(a[1])
	quit()
