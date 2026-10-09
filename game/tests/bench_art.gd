extends SceneTree
## Microbenchmark of the Art primitives (per call, microseconds):
##   godot --headless --path . -s res://tests/bench_art.gd

var _ci: Control


func _initialize() -> void:
	_ci = Control.new()
	root.add_child(_ci)
	await process_frame
	var pts := Art.ellipse_pts(Vector2.ZERO, Vector2(20, 14))
	var line_pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 5), Vector2(20, 3), Vector2(30, 9), Vector2(40, 2), Vector2(50, 6)])
	var n := 20000
	_bench("toon (cached geo)", n, func(): Art.toon(_ci, pts, Art.CORAL, 3.0, 1.0))
	_bench("toon under push", n, func():
		Art.push(_ci, Vector2(10, 20), 0.3)
		Art.toon(_ci, pts, Art.CORAL, 3.0, 1.0)
		Art.pop(_ci))
	_bench("flat (cached)", n, func(): Art.flat(_ci, pts, Art.CORAL))
	_bench("t_circle", n, func(): Art.t_circle(_ci, Vector2(3, 4), 10.0, Art.GOLD))
	_bench("disc r=4", n, func(): Art.disc(_ci, Vector2(3, 4), 4.0, Art.GOLD))
	_bench("polyline 6 pts", n, func(): Art.polyline(_ci, line_pts, Art.INK, 3.0))
	_bench("line", n, func(): Art.line(_ci, Vector2.ZERO, Vector2(30, 10), Art.INK, 3.0))
	_bench("stroke 6 pts", n / 4, func(): Art.stroke(_ci, line_pts, Art.WOOD, 4.0))
	_bench("push+pop", n, func():
		Art.push(_ci, Vector2(10, 20), 0.3)
		Art.pop(_ci))
	var k := hash([1, 2, 3])
	Art.cache_begin(_ci, k)
	Art.toon(_ci, pts, Art.CORAL)
	Art.toon(_ci, pts, Art.BLUE)
	Art.cache_end(_ci, k)
	_bench("cache_begin hit", n, func(): Art.cache_begin(_ci, k))
	_bench("ellipse_pts", n, func(): Art.ellipse_pts(Vector2.ZERO, Vector2(20, 14)))
	_bench("rrect_pts", n, func(): Art.rrect_pts(Rect2(0, 0, 40, 20), 6))
	_bench("empty lambda", n, func(): pass)
	quit()


func _bench(name: String, n: int, f: Callable) -> void:
	Art.flush()
	var t0 := Time.get_ticks_usec()
	for i in n:
		f.call()
		if i % 200 == 199:
			Art.flush()
	Art.flush()
	var us := float(Time.get_ticks_usec() - t0) / n
	print("%-22s %6.2f us" % [name, us])
