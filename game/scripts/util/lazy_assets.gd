class_name LazyAssets
extends RefCounted
## Files the web page fetches only when they are needed, after the game has
## started (tools/export_web.sh keeps them out of index.pck and puts them
## next to index.html):
##   music.ogg          the music loop, a few seconds after the start (Sfx)
##   icudt_godot.dat    line-breaking data of the text server; only Chinese
##                      needs it (words aren't split by spaces). It is kept
##                      in user:// after the first download.
## Everywhere else (the editor, tests, desktop builds) the files are in the
## pack as usual and nothing is fetched.

const TEXT_DATA := "icudt_godot.dat"

static var _text_state := ""   # "", "loading", "ready", "failed"


## Downloads `file` from next to the page and calls done(bytes) (empty on
## failure). `host` is any node in the tree (it holds the request).
static func fetch(host: Node, file: String, done: Callable) -> void:
	if not OS.has_feature("web"):
		done.call(PackedByteArray())
		return
	var url := str(JavaScriptBridge.eval("new URL('%s', document.baseURI).href" % file, true))
	var req := HTTPRequest.new()
	req.accept_gzip = true
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		done.call(body if result == HTTPRequest.RESULT_SUCCESS and code == 200 else PackedByteArray()))
	if req.request(url) != OK:
		req.queue_free()
		done.call(PackedByteArray())


## Makes sure the text server can break lines of `locale` (call at start
## and when the language changes). Text already on screen is laid out
## again once the data is in.
static func ensure_text_data(host: Node, locale: String) -> void:
	var ts := TextServerManager.get_primary_interface()
	if ts == null or not ts.has_feature(TextServer.FEATURE_USE_SUPPORT_DATA):
		return
	if _text_state in ["loading", "ready"] or not ts.is_locale_using_support_data(locale):
		return
	# In the pack (desktop, editor) the server has loaded it by itself.
	if ResourceLoader.exists("res://" + TEXT_DATA) or FileAccess.file_exists("res://" + TEXT_DATA):
		_text_state = "ready"
		return
	var cached := "user://" + TEXT_DATA
	if FileAccess.file_exists(cached) and ts.load_support_data(cached):
		_text_state = "ready"
		_relayout(host)
		return
	_text_state = "loading"
	fetch(host, TEXT_DATA, func(bytes: PackedByteArray) -> void:
		if bytes.size() < 1024:
			_text_state = "failed"
			return
		var f := FileAccess.open(cached, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
		_text_state = "ready" if ts.load_support_data(cached) else "failed"
		if _text_state == "ready":
			_relayout(host))


static func _relayout(host: Node) -> void:
	if host.is_inside_tree():
		host.get_tree().root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
