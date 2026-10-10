extends SceneTree
## Promo video frames (CrazyGames preview: 15-20 s, no sound, starts on the
## static cover, no "play now" text). Mobile-ad style: a fresh mine at zero,
## taps and upgrades, a cut to a busy base, a pan down the deep mine, the
## clouds carry us to the volcano, then the logo.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1920x1080 \
##     --fixed-fps 30 -s res://tests/promo_rec.gd -- <out_dir> <cg|promo> <cover.png>
## "promo" also ends on a "Try now" button with the hand and where to play.
## Frames are written as <out_dir>/f00000.jpg ... at 30 fps; join with ffmpeg.

const FPS := 30.0

var out_dir := ""
var mode := "cg"
var cover: Texture2D
var frame := 0
var fx: PromoFx
var gs: Node
var pr: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://promo"
	mode = args[1] if args.size() > 1 else "cg"
	if args.size() > 2:
		cover = ImageTexture.create_from_image(Image.load_from_file(args[2]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	root.get_node("Settings").language = "en"
	root.get_node("Settings").hand_cursor = false
	root.get_node("Settings").ui_scale = 1.12
	TranslationServer.set_locale("en")
	gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://promo_save.json"
	pr = root.get_node("Progress")
	pr.autosave_enabled = false
	pr.save_path = "user://promo_progress.json"
	root.get_node("Profiles").set_name_of(root.get_node("Profiles").current_id, "Alex")
	load("res://scripts/ui/main.gd").show_title = false
	load("res://scripts/ui/day_night.gd").fixed_phase = 0.2

	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	fx = PromoFx.new()
	fx.cover = cover
	fx.mode = mode
	layer.add_child(fx)

	# 1. The cover, then the game fades in under it.
	await _scene("start")
	fx.cover_alpha = 1.0
	await _run(0.7)
	await _run(0.35, func(k: float): fx.cover_alpha = 1.0 - k)
	fx.cover_alpha = 0.0
	# 2. From zero: tap the divers, coins come, upgrade the first site.
	await _tap_world("d0", 4)
	gs.coins += 60.0
	await _tap_card("d0", 4)
	# 3. Cut: a busy base. Upgrades pop one after another.
	await _scene("mid")
	await _run(0.2)
	await _tap_card("d0", 5)
	await _tap_card("lift", 3)
	# 4. Cut: the big base, the camera dives down the mine.
	await _scene("late")
	var main := current_scene
	var bottom: float = main._scroller.max_scroll()
	await _run(2.6, func(k: float): main._scroller.scroll_to(bottom * _ease(k) * 0.85))
	# 5. The clouds roll in over the deep mine and part over the volcano.
	gs.max_location = maxi(gs.max_location, 1)
	load("res://scripts/ui/world_travel.gd").start(main, "ocean", "volcano", func():
		gs.switch_location(1)
		gs.coins = 1.2e4
		main._settle_switch(1))
	await _run(2.9)
	# 6. The logo.
	fx.pointer_on = false
	await _run(3.0, func(k: float): fx.end = k * 3.0)
	print("frames: ", frame)
	quit()


## Loads the main screen with a prepared state; frames before it settles
## are not written.
func _scene(kind: String) -> void:
	fx.pointer_on = false
	gs.reset()
	pr.reset()
	for f in Content.FEATURES:
		pr.features[f] = true
	pr.tutorial_step = 12
	pr.daily_last = pr.today()
	# No "first flame" or other news popping up over the shots.
	pr.streak_count = 6
	pr.streak_best = 6
	pr.streak_last = pr.today()
	pr.owned["pet_octopus"] = true
	pr.equipped["pet"] = "pet_octopus"
	pr.apply_bonus()
	match kind:
		"start":
			gs.coins = 0.0
		"mid":
			gs.levels.merge({"d0": 24, "d1": 9, "d2": 3, "lift": 30, "boat": 28, "plant": 26}, true)
			for k in ["d0", "lift", "boat", "plant"]:
				gs.managers[k] = true
			gs.coins = 3.0e6
			gs.hold = 900.0
		"late":
			for k in gs.stage_keys():
				gs.levels[k] = 60
				gs.managers[k] = true
			gs.levels.merge({"lift": 300, "boat": 360, "plant": 360}, true)
			gs.coins = 4.2e12
			gs.evo = 2
	change_scene_to_file("res://scenes/main.tscn")
	for i in 8:
		await process_frame
	for i in 40:
		gs.advance(0.05)
		await process_frame
	var main := current_scene
	main._scroller.scroll_to(0.0)
	await process_frame


## Runs `seconds` of the game, writing every frame; `step` gets 0..1.
func _run(seconds: float, step: Callable = Callable()) -> void:
	var n := maxi(1, int(round(seconds * FPS)))
	for i in n:
		if step.is_valid():
			step.call(float(i + 1) / n)
		var main := current_scene
		if main != null and main.get("_toast") != null:
			main._toast.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_jpg("%s/f%05d.jpg" % [out_dir, frame], 0.93)
		frame += 1


## The hand glides to a point (canvas coordinates) and taps it `times` times.
func _tap_at(get_pos: Callable, times: int) -> void:
	var from := fx.pointer
	var to: Vector2 = get_pos.call()
	if not fx.pointer_on:
		from = to + Vector2(240, 320)
		fx.pointer_on = true
	await _run(0.3, func(k: float): fx.pointer = from.lerp(to, _ease(k)))
	for i in times:
		fx.press = 0.0
		await _run(0.12, func(k: float): fx.press = k)
		_click(get_pos.call())
		await _run(0.16, func(k: float): fx.press = 1.0 - k)


func _tap_world(key: String, times: int) -> void:
	await _tap_at(func() -> Vector2:
		var main := current_scene
		var world: Control = main._world
		return world.get_global_transform_with_canvas() * (world.stage_anchor(key) + Vector2(60, -40)), times)


## Taps the Upgrade button of a stage: the PC side panel for the mine
## sites, else the stage's own card.
func _tap_card(key: String, times: int) -> void:
	var main := current_scene
	var panel: bool = main._wide and key.begins_with("d")
	if panel:
		main._panel.show_stage(key)
	else:
		# On a phone the card can sit under the bottom bar: glide it into view.
		var u: Control = main.stage_card(key)._upgrade
		var vh: float = root.get_visible_rect().size.y
		var low: float = (u.get_global_transform_with_canvas() * u.size).y
		if low > vh * 0.62:
			var from: float = main._scroller.scroll
			var to: float = from + (low - vh * 0.5) / main._scroller.zoom
			await _run(0.4, func(k: float): main._scroller.scroll_to(lerpf(from, to, _ease(k))))
	var at_card := func() -> Vector2:
		var b: Control = main._panel._buy if panel else main.stage_card(key)._upgrade
		return b.get_global_transform_with_canvas() * (b.size * 0.5)
	var at_buy := func() -> Vector2:
		var b: Control = main._panel._buy
		return b.get_global_transform_with_canvas() * (b.size * 0.5)
	if panel:
		await _tap_at(at_card, times)
		return
	# A card opens the phone sheet (or upgrades right away): keep buying there.
	await _tap_at(at_card, 1)
	if main._sheet_open:
		await _run(0.25)
		await _tap_at(at_buy, times)
		await _run(0.2)
		main._close_sheet()
		await _run(0.25)
	elif times > 1:
		await _tap_at(at_card, times - 1)


func _click(canvas_pos: Vector2) -> void:
	var p: Vector2 = root.get_final_transform() * canvas_pos
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
	Input.flush_buffered_events()


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


class PromoFx extends Control:
	var cover: Texture2D
	var cover_alpha := 0.0
	var mode := "cg"
	var pointer := Vector2.ZERO
	var pointer_on := false
	var press := 0.0
	## Seconds into the end card (0 = not shown).
	var end := 0.0
	var _logo: Texture2D
	var _t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _logo_tex(w: float) -> Texture2D:
		if _logo == null:
			var svg := FileAccess.get_file_as_string("res://assets/logo.svg")
			var probe := Image.new()
			probe.load_svg_from_string(svg, 1.0)
			var img := Image.new()
			img.load_svg_from_string(svg, w * 1.4 / probe.get_width())
			_logo = ImageTexture.create_from_image(img)
		return _logo

	func _draw() -> void:
		var v := size
		if end > 0.0:
			_draw_end(v)
		if pointer_on:
			var dip := press
			PointerArt.hand(self, pointer + Vector2(10, 14) * (1.0 - dip), -0.5, Vector2.ONE * (minf(v.x, v.y) / 520.0) * (1.0 - 0.08 * dip))
		if cover != null and cover_alpha > 0.0:
			draw_texture_rect(cover, Rect2(Vector2.ZERO, v), false, Color(1, 1, 1, cover_alpha))

	func _draw_end(v: Vector2) -> void:
		var k := clampf(end / 0.45, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, v), Color(0.04, 0.09, 0.26, 0.72 * k))
		var lw := minf(v.x * 0.62, v.y * 0.95)
		var logo := _logo_tex(lw)
		var ls := Vector2(logo.get_size()) * (lw / logo.get_width())
		var promo := mode == "promo"
		var c := Vector2(v.x * 0.5, v.y * (0.36 if promo else 0.46))
		# Sunburst behind the logo.
		var r := maxf(v.x, v.y) * 1.2
		for i in 16:
			var a := _t * 0.25 + TAU * i / 16.0
			var ray := Color(1.0, 0.9, 0.5, 0.13 * k)
			draw_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * r, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * r]), PackedColorArray([ray, Color(ray, 0.0), Color(ray, 0.0)]))
		# The logo drops in with a bounce.
		var pop := clampf((end - 0.15) / 0.55, 0.0, 1.0)
		if pop > 0.0:
			var s := _back(pop)
			draw_set_transform(c, 0.0, Vector2.ONE * s)
			draw_texture_rect(logo, Rect2(-ls * 0.5, ls), false)
			draw_set_transform(Vector2.ZERO)
		if not promo:
			return
		var bp := clampf((end - 0.7) / 0.4, 0.0, 1.0)
		if bp <= 0.0:
			return
		var font := UiTheme.heavy_font()
		var bw := minf(v.x * 0.34, v.y * 0.62)
		var bh := bw * 0.27
		var bc := Vector2(v.x * 0.5, c.y + ls.y * 0.5 + bh * 1.0)
		var pulse := 1.0 + 0.04 * sin(_t * 7.0)
		draw_set_transform(bc, 0.0, Vector2.ONE * _back(bp) * pulse)
		var box := Rect2(Vector2(-bw, -bh) * 0.5, Vector2(bw, bh))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ffc531")
		sb.set_corner_radius_all(int(bh * 0.32))
		sb.set_border_width_all(int(maxf(4.0, bh * 0.07)))
		sb.border_color = Art.INK
		sb.shadow_color = Color(Art.INK, 0.6)
		sb.shadow_offset = Vector2(0, bh * 0.1)
		sb.shadow_size = 1
		draw_style_box(sb, box)
		var shine := StyleBoxFlat.new()
		shine.bg_color = Color(1, 1, 1, 0.35)
		shine.set_corner_radius_all(int(bh * 0.2))
		draw_style_box(shine, Rect2(box.position + Vector2(bh * 0.25, bh * 0.14), Vector2(bw - bh * 0.5, bh * 0.22)))
		var fs := int(bh * 0.5)
		var label := "TRY NOW"
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, Vector2(-tw * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(6, fs / 6), Art.INK)
		draw_string(font, Vector2(-tw * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		# Where to play.
		var lines := ["gonempxr.github.io/colarlight", "CrazyGames"]
		var small := int(bh * 0.3)
		for i in lines.size():
			var lp := clampf((end - 1.0 - 0.2 * i) / 0.4, 0.0, 1.0)
			if lp <= 0.0:
				continue
			var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			var at := Vector2(v.x * 0.5 - w * 0.5, bc.y + bh * 1.05 + small * 1.35 * i + small)
			draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, small, maxi(4, small / 5), Color(Art.INK, lp))
			draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, lp))
		# The hand taps the button.
		if end > 1.0:
			var tip := bc + Vector2(bw * 0.28, bh * 0.15)
			PointerArt.draw(self, tip, end, true, -0.5, minf(v.x, v.y) / 520.0)

	static func _back(x: float) -> float:
		var c1 := 1.70158
		var c3 := c1 + 1.0
		return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
