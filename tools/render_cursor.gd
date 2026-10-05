extends SceneTree
## Bakes the PC mouse cursor from the tutorial glove (PointerArt.hand) into
## game/assets/cursor: hand.png / hand_press.png (32 px) and @2x (64 px) for
## HiDPI screens. Drawn 8x larger, then scaled down for clean edges.
##   xvfb-run -a godot --rendering-driver opengl3 --path game -s res://../tools/render_cursor.gd

const SIZE := 32
const SS := 8
const ANGLE := -0.12
const UNITS := 0.33           # glove units -> cursor px at 1x
const TIP := Vector2(10, 2.0) # fingertip in 1x cursor px (the hotspot)

class Glove extends Node2D:
	var press := false
	var k := 1.0
	func _draw() -> void:
		var sc := Vector2(1.0, 0.9) if press else Vector2.ONE
		var tip := TIP * k + (Vector2(0, 2.0) * k if press else Vector2.ZERO)
		PointerArt.hand(self, tip, ANGLE, sc * UNITS * k)


func _bake(press: bool, mult: int, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE * mult * SS, SIZE * mult * SS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var g := Glove.new()
	g.press = press
	g.k = mult * SS
	vp.add_child(g)
	root.add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(SIZE * mult, SIZE * mult, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(path))
	print("wrote ", path)
	vp.queue_free()


func _initialize() -> void:
	await process_frame
	await _bake(false, 1, "res://assets/cursor/hand.png")
	await _bake(true, 1, "res://assets/cursor/hand_press.png")
	await _bake(false, 2, "res://assets/cursor/hand@2x.png")
	await _bake(true, 2, "res://assets/cursor/hand_press@2x.png")
	print("hotspot ", TIP)
	quit()
