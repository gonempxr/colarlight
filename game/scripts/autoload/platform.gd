extends Node
## Where the game runs and what that site offers: rewarded ads, purchases,
## a player account with cloud saves. Registered as the Platform autoload.
##
## Providers:
## - "none": itch.io, GitHub Pages, desktop. Nothing here is available and
##   the UI hides every ad and purchase button, so no button does nothing.
## - "crazygames": the CrazyGames HTML5 SDK v3 (window.CrazyGames.SDK). The
##   web shell (web/shell.html) loads and initialises it on CrazyGames and
##   puts a small bridge in window.coralightAds. Rewarded ads only, and only
##   when the player asks for one: the game is for kids.
## - "test": a pretend ad for trying the flow on a test page: open the game
##   with ?ads=test and an overlay (AdOverlay) stands in for a 3-second ad.
##
## While an ad plays the game is paused and muted; the SDK hears
## gameplayStop/gameplayStart around it (the shell does that).

signal purchase_done(product: String, ok: bool)
## An ad began / ended (ok = watched to the end, so the reward is due).
signal ad_started
signal ad_finished(ok: bool)
## Provider "test": the overlay should show the pretend ad now.
signal test_ad_requested(seconds: float)
## The provider changed (the SDK finished loading): show or hide ad buttons.
signal provider_changed

const TEST_AD_SEC := 3.0
## An ad that never answers must not freeze the game.
const AD_TIMEOUT_SEC := 150.0
## How often the SDK's mute setting is read (the shell keeps it current).
const POLL_SEC := 1.0
## How long to wait for the shell to finish starting the SDK.
const SDK_WAIT_SEC := 40.0

var provider := "none"
var ad_running := false
## The site asks the game to stay quiet (CrazyGames' settings.muteAudio).
var site_muted := false
## Why the last ad did not pay out ("" = it did): "adblock", "unfilled",
## "adCooldown", "skipped", "timeout", ...
var last_error := ""

var _done: Callable
var _ad_left := 0.0
## Provider "test" with no overlay listening (tests): the ad ends by itself.
var _auto_ok := false
var _poll_left := 0.0
var _sdk_wait := 0.0
var _paused_by_ad := false
var _was_paused := false
## JavaScript callbacks must stay referenced while the SDK may call them.
var _js_started: JavaScriptObject
var _js_done: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	var query := str(JavaScriptBridge.eval("(function(){try{return new URLSearchParams(window.location.search).get('ads')||''}catch(e){return ''}})()", true))
	if query == "test":
		provider = "test"
		return
	# The shell loads the SDK only on CrazyGames (or with ?ads=crazygames);
	# it may still be starting, so look again for a while.
	if _shell_state() != "":
		_sdk_wait = SDK_WAIT_SEC


func _process(delta: float) -> void:
	if _sdk_wait > 0.0:
		_sdk_wait -= delta
		var state := _shell_state()
		if state == "ready":
			_sdk_wait = 0.0
			set_provider("crazygames")
		elif state != "loading":
			_sdk_wait = 0.0
	if provider == "crazygames":
		_poll_left -= delta
		if _poll_left <= 0.0:
			_poll_left = POLL_SEC
			var muted := bool(JavaScriptBridge.eval("!!(window.coralightAds && window.coralightAds.muteAudio)", true))
			if muted != site_muted:
				site_muted = muted
				_apply_mute()
	if ad_running:
		_ad_left -= delta
		if _ad_left <= 0.0:
			if not _auto_ok:
				push_warning("Rewarded ad timed out")
				last_error = "timeout"
			_finish(_auto_ok)


## Picks the provider (tests; the shell's SDK start).
func set_provider(id: String) -> void:
	provider = id
	provider_changed.emit()


func ads_available() -> bool:
	return provider in ["test", "crazygames"] and not ad_running


## Shows a rewarded ad; `done(true)` runs only when it was watched to the
## end, `done(false)` when it failed, was skipped or none is available.
func show_rewarded(done: Callable) -> void:
	if not ads_available():
		done.call(false)
		return
	ad_running = true
	_done = done
	_ad_left = AD_TIMEOUT_SEC
	_auto_ok = false
	last_error = ""
	match provider:
		"test":
			_begin_ad()
			if test_ad_requested.get_connections().is_empty():
				_auto_ok = true
				_ad_left = TEST_AD_SEC
			test_ad_requested.emit(TEST_AD_SEC)
		"crazygames":
			var bridge = JavaScriptBridge.get_interface("coralightAds")
			if bridge == null:
				last_error = "unavailable"
				_finish(false)
				return
			_js_started = JavaScriptBridge.create_callback(_on_js_started)
			_js_done = JavaScriptBridge.create_callback(_on_js_done)
			bridge.rewarded(_js_started, _js_done)


## The test overlay reports: watched to the end (true) or skipped (false).
func finish_test_ad(ok: bool) -> void:
	if ad_running and provider == "test":
		if not ok:
			last_error = "skipped"
		_finish(ok)


## The player starts (or is back to) playing. Only the SDK cares.
func gameplay_start() -> void:
	if provider != "crazygames":
		return
	var bridge = JavaScriptBridge.get_interface("coralightAds")
	if bridge != null:
		bridge.gameplayStart()


func payments_available() -> bool:
	return false


## Local price text for a product ("" when unknown).
func price(_product: String) -> String:
	return ""


func purchase(product: String) -> void:
	purchase_done.emit(product, false)


# --- Inside ---------------------------------------------------------------------

func _shell_state() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("(window.coralightAds && window.coralightAds.state) || ''", true))


func _on_js_started(_args: Array) -> void:
	if ad_running:
		_begin_ad()


func _on_js_done(args: Array) -> void:
	var result := str(args[0]) if args.size() > 0 else "error"
	if result != "ok":
		push_warning("Rewarded ad not shown: " + result)
		last_error = result.trim_prefix("error:")
	_finish(result == "ok")


## Ad on screen: stop the game and its sound (the SDK asks for both).
func _begin_ad() -> void:
	if _paused_by_ad:
		return
	_paused_by_ad = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_apply_mute()
	ad_started.emit()


func _finish(ok: bool) -> void:
	if not ad_running:
		return
	ad_running = false
	_auto_ok = false
	if _paused_by_ad:
		_paused_by_ad = false
		get_tree().paused = _was_paused
	_apply_mute()
	var done := _done
	_done = Callable()
	ad_finished.emit(ok)
	if done.is_valid():
		done.call(ok)


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, site_muted or _paused_by_ad)
