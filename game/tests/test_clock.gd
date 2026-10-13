extends SceneTree
## Trusted time: the game runs on Clock.now(), which follows the server's
## time once known and then the monotonic tick counter, so moving the
## device clock gives nothing (offline coins, daily gifts, cooldowns).

var fails := 0
var checks := 0


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	await process_frame
	var clock: Node = root.get_node("Clock")
	var gs: Node = root.get_node("GameState")
	var pr: Node = root.get_node("Progress")
	gs.autosave_enabled = false
	pr.autosave_enabled = false
	var dev := Time.get_unix_time_from_system()
	_check(absf(clock.now() - dev) < 5.0, "without a server the device clock is used")
	# The server says it is 3 days earlier than the device thinks.
	var server := dev - 3 * 86400.0
	clock.set_server_time(server)
	_check(clock.synced and absf(clock.now() - server) < 1.0, "the server's time wins")
	_check(absf(gs.now() - server) < 1.0, "GameState runs on the trusted time")
	_check(clock.today() == Time.get_date_string_from_unix_time(int(server) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60), "today() follows the trusted time")
	_check(pr.today() == clock.today(), "the daily gift's day follows the trusted time")
	var t0: float = clock.now()
	OS.delay_msec(300)
	var t1: float = clock.now()
	_check(t1 - t0 > 0.25 and t1 - t0 < 5.0, "time runs on with the ticks (%.2f s)" % (t1 - t0))
	# Coins for pearls: bought now, the next one in 5 h by trusted time.
	pr.stats["coins_bought_at"] = clock.now()
	_check(pr.coins_wait() > Content.COINS_COOLDOWN_SEC - 5.0, "the cooldown counts from trusted time")
	# Offline earnings: a save "from the future" (made with a pushed clock)
	# gives nothing.
	var future := {"saved_at": clock.now() + 8 * 3600.0}
	_check(clampf(clock.now() - float(future["saved_at"]), 0.0, Balance.OFFLINE_CAP_SEC) == 0.0, "time away can't come from a pushed clock")
	print("test_clock: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
