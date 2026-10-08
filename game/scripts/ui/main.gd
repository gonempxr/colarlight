extends Control
## Main screen with three rooms: the Mine (room 1: the world with the lift,
## the boats and the work sites), the Factory (room 2) and the Office
## (room 3: the vault, the accountant, evolution, outfits and decor).
## Phone (portrait): top bar, the room tabs under it, the room, the feature
## dock at the bottom and the upgrade sheet sliding up over it; a swipe
## left or right changes the room. PC (landscape): the coin notch, the room
## on the left with the tabs floating under the notch, cards, the upgrade
## panel and the dock on the right.
## Also routes the meta game: dialogs, rewards, the map, the puzzle, players.

const WIDE_ASPECT := 1.05
const REFRESH_SEC := 0.1
const SIDE_W := 540.0
const TOAST_SEC := 3.0
const HUD_H := 112.0
const DOCK_H := 128.0
const PUZZLE_SCRIPT := "res://scripts/puzzle/puzzle_screen.gd"
const LEVELS_SCRIPT := "res://scripts/puzzle/puzzle_levels.gd"
const ROOMS := ["mine", "factory", "office"]
const MINE := 0
const FACTORY := 1
const OFFICE := 2
const SLIDE_SEC := 0.34
## A finger has to travel this far sideways (and mostly sideways) to swipe.
const SWIPE_MIN := 70.0

var _hud: Hud
var _tabs: RoomTabs
var _scroller: Scroller
var _world: World
var _factory: FactoryRoom
var _office: OfficeRoom
var _panel: UpgradePanel
var _dock: Dock
var _dock_laid_out := false
## Phone: the plant's card on the factory's wall, the office buttons under
## the office, the evolution card in room 1's card row.
var _factory_card: StageCard
var _office_bar: OfficeBar
var _evo_card: EvoCard
## PC only: the cards in a row in the side column (the in-room ones hide):
## lift, boat, evolution in the mine; the plant in the factory; the office
## card replaces cards and panel in the office.
var _side_cards: HBoxContainer
var _side_lift: StageCard
var _side_boat: StageCard
var _side_evo: EvoCard
var _side_plant: StageCard
var _side_office: OfficeBar
var _hint_btn: HintButton
## The mini-map under the lightbulb in room 1: big on PC; on phones a
## smaller one (in a scaled holder) that fades away while the mine scrolls
## down to the work sites.
var _mini: MiniMap
var _mini_world: MiniMap
var _mini_holder: Control
const PHONE_MINI := 0.68
var _map: MapView
## Under the lightbulb: x2 for an optional ad (only where ads exist) and
## the Rivals League trophy (only while a weekly reward waits).
var _boost_btn: SideButton
var _rivals_btn: SideButton
var _ad_overlay: AdOverlay
## Frames left to re-fit the PC side column (wrapped text settles a frame late).
var _side_fit_frames := 0
var _modal: Modal
## Second dialog layer above the first (names, feature news).
var _top: Modal
var _fx: FxLayer
var _tutor: Tutor
var _puzzle: Control
var _fishing: Control
var _title: TitleScreen
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _wide := false
var _sheet_open := false
var _refresh_left := 0.0
var _news: Array[String] = []
var _started := false
var _sheet_tween: Tween
## The room shown (0 mine, 1 factory, 2 office) and the slide between rooms
## (a float index: 0.5 is halfway from the mine to the factory).
var _room := MINE
var _slide := 0.0
var _slide_tween: Tween
## Rooms' area on screen.
var _area := Rect2()
## The stage each room last showed in the upgrade panel.
var _room_key: Array[String] = ["d0", "plant", ""]
## Swipe tracking.
var _swipe_from := Vector2.ZERO
var _swipe_on := false
var _swiped := false
## The finger is down (a room tap that opens a dialog waits for the release,
## so a swipe that starts on the sofa doesn't open the decor shop).
var _finger_down := false
var _on_release := Callable()
## Settings that change what dialogs show (not the volumes: rebuilding the
## settings dialog while a volume slider is dragged would drop the drag).
var _settings_sig := []
## Tests and screenshots skip the title screen.
static var show_title := true


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_ui_scale()
	var bg := ColorRect.new()
	bg.color = Art.SEA_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scroller = Scroller.new()
	add_child(_scroller)
	_world = World.new()
	_scroller.set_content(_world)
	_world.stage_selected.connect(_on_stage_selected)
	_world.chest.opened.connect(func(r, at): celebrate(r, at))

	_factory = FactoryRoom.new()
	_factory.visible = false
	add_child(_factory)
	_factory.stage_selected.connect(_on_stage_selected)
	_factory_card = StageCard.new("plant")
	_factory_card.world = _world
	_factory_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	_factory.add_child(_factory_card)

	_office = OfficeRoom.new()
	_office.visible = false
	add_child(_office)
	_office.collected.connect(func(amount: float, from: Vector2): celebrate({"coins": amount}, from, false))
	_office.open_evolution.connect(func(): _after_tap(open_evolution))
	_office.open_outfits.connect(func(): _after_tap(open_outfits))
	_office.decor_selected.connect(func(slot: String): _after_tap(open_decor.bind(slot)))
	_office_bar = OfficeBar.new()
	_connect_office_bar(_office_bar)
	_office.add_child(_office_bar)

	# Room 1: the evolution card takes the plant card's place in the row
	# (the plant works in the factory now), the mini-map hangs under it.
	_world.surface.plant_card.visible = false
	_evo_card = EvoCard.new()
	_evo_card.custom_minimum_size = Vector2(World.CARD_W, 0)
	_evo_card.open_panel.connect(open_evolution)
	_world.add_child(_evo_card)
	_mini_holder = Control.new()
	_mini_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_holder.scale = Vector2(PHONE_MINI, PHONE_MINI)
	add_child(_mini_holder)
	_mini_world = MiniMap.new()
	_mini_world.open_map.connect(open_map)
	_mini_holder.add_child(_mini_world)
	_mini = MiniMap.new()
	_mini.big = true
	_mini.open_map.connect(open_map)
	add_child(_mini)

	_dock = Dock.new()
	_dock.pressed.connect(open_feature)
	add_child(_dock)

	_panel = UpgradePanel.new()
	_panel.closed.connect(_close_sheet)
	add_child(_panel)

	_side_cards = HBoxContainer.new()
	_side_cards.add_theme_constant_override("separation", 8)
	_side_cards.visible = false
	add_child(_side_cards)
	for k in ["lift", "boat", "evo", "plant"]:
		var c: Control
		if k == "evo":
			_side_evo = EvoCard.new()
			_side_evo.hero = true
			_side_evo.narrow = true
			_side_evo.open_panel.connect(open_evolution)
			c = _side_evo
		else:
			var sc := StageCard.new(k)
			sc.world = _world
			sc.hero = true
			sc.narrow = true
			c = sc
			match k:
				"lift":
					_side_lift = sc
				"boat":
					_side_boat = sc
				_:
					_side_plant = sc
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_stretch_ratio = 1.0
		c.custom_minimum_size.x = 0
		_side_cards.add_child(c)
	_side_office = OfficeBar.new()
	_side_office.full = true
	_side_office.visible = false
	_connect_office_bar(_side_office)
	add_child(_side_office)

	_tabs = RoomTabs.new()
	_tabs.selected.connect(func(i): show_room(i))
	add_child(_tabs)
	_hud = Hud.new()
	_hud.settings_pressed.connect(_open_settings)
	_hud.avatar_pressed.connect(open_profile)
	add_child(_hud)

	_hint_btn = HintButton.new()
	_hint_btn.main = self
	_hint_btn.pressed.connect(open_hint)
	add_child(_hint_btn)
	_boost_btn = SideButton.make("boost")
	_boost_btn.pressed.connect(open_boost)
	add_child(_boost_btn)
	_rivals_btn = SideButton.make("rivals")
	_rivals_btn.pressed.connect(open_rivals)
	add_child(_rivals_btn)

	_tutor = Tutor.new()
	_tutor.main = self
	add_child(_tutor)

	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"ToastPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_override("font", UiTheme.heavy_font())
	_toast_label.add_theme_font_size_override("font_size", 25)
	_toast_label.add_theme_color_override("font_color", Color("fff6e4"))
	_toast_label.add_theme_constant_override("outline_size", 0)
	_toast.add_child(_toast_label)
	add_child(_toast)

	_map = MapView.new()
	_map.visible = false
	add_child(_map)
	_map.location_opened.connect(_on_location_opened)
	_map.closed.connect(_on_map_closed)

	_modal = Modal.new()
	add_child(_modal)
	_top = Modal.new()
	add_child(_top)
	_top.closed.connect(_show_next_news)
	_modal.closed.connect(_show_next_news)
	_fx = FxLayer.new()
	add_child(_fx)
	_fx.arrived.connect(func(kind): _hud.bump(kind))
	_ad_overlay = AdOverlay.new()
	add_child(_ad_overlay)
	_setup_streak()

	GameState.changed.connect(_refresh)
	GameState.milestone_reached.connect(_on_milestone)
	GameState.rush_started.connect(func(): _show_toast(tr("RUSH")); Sfx.play("rush"))
	Progress.feature_unlocked.connect(func(id):
		_news.append(id)
		_show_next_news())
	Progress.artifact_leveled.connect(func(id, lv):
		_show_toast(tr("ARTIFACT_UP") % [tr("ART_" + id.to_upper()), lv]))
	Progress.item_unlocked.connect(func(id):
		_show_toast(tr("ITEM_UNLOCKED"))
		Sfx.play("unlock"))
	Progress.quest_done.connect(func(_i):
		_show_toast(tr("QUEST_DONE"))
		Sfx.play("milestone"))
	_settings_sig = _settings_signature()
	Settings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_layout)
	Wardrobe.apply_looks()
	Progress.changed.connect(Wardrobe.apply_looks)
	HandCursor.apply(Settings.hand_cursor)
	_layout()
	_refresh()
	if show_title:
		_title = TitleScreen.new()
		_title.started.connect(_after_title)
		_title.players_pressed.connect(open_players)
		add_child(_title)
		move_child(_title, _modal.get_index())
	else:
		_after_title()
	_announce_ready()


func _connect_office_bar(b: OfficeBar) -> void:
	b.evolution_pressed.connect(open_evolution)
	b.outfits_pressed.connect(open_outfits)
	b.decor_pressed.connect(func(): open_decor(""))
	b.collect_pressed.connect(func(from: Vector2):
		var amount := GameState.collect_vault()
		if amount > 0.0:
			celebrate({"coins": amount}, from)
		else:
			Sfx.play("tap"))


## Tells the web loading screen (web/shell.html) that the first frame is
## drawn, so it can fade out without showing a blank canvas.
func _announce_ready() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	print("CORALIGHT_READY")


func _after_title() -> void:
	_title = null
	_started = true
	Platform.gameplay_start()
	var report := GameState.take_offline_report()
	if not report.is_empty():
		_open_offline(report)
	elif Progress.daily_ready():
		open_feature("daily")


func _process(delta: float) -> void:
	if _wide:
		# The lightbulb, the mini-map and the tabs ride below the top bar
		# while it slides down on PC.
		var drop := _hud.bar_bottom()
		_hint_btn.position.y = 24.0 + drop
		_tabs.position.y = maxf(_hud.used_height() + 10.0, drop + 10.0)
	_place_side_buttons()
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SEC
		_refresh()
	Scroller.locked = _modal.visible or _top.visible or _map.visible or is_instance_valid(_puzzle) or is_instance_valid(_fishing) or is_instance_valid(_title) or _room != MINE
	if _side_fit_frames > 0 and _wide:
		_side_fit_frames -= 1
		var view := get_viewport_rect().size
		_fit_side_column(view, minf(SIDE_W, view.x * 0.4), _dock_height())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		HandCursor.press(event.pressed)
	_track_swipe(event)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _modal.visible or _top.visible or _map.visible or is_busy():
		return
	# PC: 1 / 2 / 3 or the arrow keys change the room.
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			show_room(event.keycode - KEY_1)
		KEY_LEFT:
			show_room(maxi(0, _room - 1))
		KEY_RIGHT:
			show_room(mini(2, _room + 1))
	if not OS.is_debug_build():
		return
	match event.keycode:
		KEY_F8:
			GameState.debug_grant()
			Progress.add_pearls(50)
		KEY_F9:
			GameState.reset_progress()
			Progress.reset_progress()


# --- Rooms ------------------------------------------------------------------------------

## Which room a stage's card and machine live in.
static func room_of(key: String) -> int:
	if key == "plant" or key == "plant2":
		return FACTORY
	if key == "vault":
		return OFFICE
	return MINE


func current_room() -> int:
	return _room


## Shows room i (0 mine, 1 factory, 2 office), sliding over from the one
## shown now (left to right is the way the ore goes).
func show_room(i: int, animate: bool = true) -> void:
	i = clampi(i, 0, 2)
	if i == _room:
		return
	_room = i
	_tabs.set_current(i)
	Sfx.play("pop", 0.9 + i * 0.1)
	if _sheet_open and not _wide:
		_close_sheet()
	if _wide and i != OFFICE and _room_key[i] != "":
		_panel.show_stage(_room_key[i])
	if _slide_tween:
		_slide_tween.kill()
	if not animate or Settings.reduce_motion or not is_inside_tree():
		_slide = float(i)
		_place_rooms()
	else:
		_slide_tween = create_tween()
		_slide_tween.tween_method(func(v: float):
			_slide = v
			_place_rooms(), _slide, float(i), SLIDE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_layout_side()
	_refresh()


## Rooms side by side, moved by the slide; only the ones on screen show.
func _place_rooms() -> void:
	var rooms: Array[Control] = [_scroller, _factory, _office]
	for i in rooms.size():
		var r := rooms[i]
		var off := (float(i) - _slide) * (_area.size.x + 24.0)
		var on := absf(float(i) - _slide) < 0.999
		r.visible = on
		r.position = Vector2(_area.position.x + roundf(off), _area.position.y)
		if r.size != _area.size:
			r.size = _area.size
	# Room 1's overlays go with it.
	var m := 1.0 - clampf(absf(_slide), 0.0, 1.0)
	_mini.visible = _wide and m > 0.01
	_mini.modulate.a = m
	# Phone: it also fades while the mine scrolls down to the work sites.
	var f := m * clampf(1.0 - (_scroller.scroll - 60.0) / 160.0, 0.0, 1.0)
	_mini_holder.visible = not _wide and f > 0.01
	_mini_holder.modulate.a = f


## Swipe left/right over the room changes it (phones; works with a mouse
## drag too). A swipe never presses the button it started on.
func _track_swipe(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_finger_down = event.pressed
		if event.pressed:
			_swipe_on = _area.has_point(event.position) and not _blocked()
			_swipe_from = event.position
			_swiped = false
			_on_release = Callable()
		else:
			_swipe_on = false
			var f := _on_release
			_on_release = Callable()
			if f.is_valid() and not _swiped and not Scroller.is_drag():
				f.call_deferred()
	elif event is InputEventMouseMotion and _swipe_on and not _swiped:
		var d: Vector2 = event.position - _swipe_from
		if _scroller._dragging:
			_swipe_on = false
			return
		if absf(d.x) > SWIPE_MIN and absf(d.x) > absf(d.y) * 1.8:
			_swiped = true
			_swipe_on = false
			var to := _room + (1 if d.x < 0.0 else -1)
			if to >= 0 and to <= 2:
				show_room(to)
			# Buttons ask Scroller.is_drag() and ignore this release.
			Scroller._dragged_recently = true
			(func(): Scroller._dragged_recently = false).call_deferred()


## Runs `f` now, or on the release when the finger is still down (and not
## at all when that touch turns into a swipe).
func _after_tap(f: Callable) -> void:
	if _finger_down:
		_on_release = f
	else:
		f.call()


func _blocked() -> bool:
	return _modal.visible or _top.visible or _map.visible or is_instance_valid(_puzzle) or is_instance_valid(_fishing) or is_instance_valid(_title)


# --- Cards ------------------------------------------------------------------------------

## The card the player sees for a stage (PC: the side column).
func stage_card(key: String) -> StageCard:
	if key == "lift":
		return _side_lift if _wide else _world.lift.phone_card()
	# The second boat/plant share the first one's card (its "2" tab).
	if GameState.is_boat(key):
		return _side_boat if _wide else _world.surface.boat_card
	if GameState.is_plant(key):
		return _side_plant if _wide else _factory_card
	var i := GameState.depth_index(key)
	return _world.rows[i].card if i >= 0 else null


## The evolution card the player sees (room 1 or the PC column).
func evo_card() -> EvoCard:
	return _side_evo if _wide else _evo_card


## The office buttons the player sees (under the office or the PC column).
func office_bar() -> OfficeBar:
	return _side_office if _wide else _office_bar


func room_tabs() -> RoomTabs:
	return _tabs


## True while something covers the rooms (tutorial waits).
func is_busy() -> bool:
	return _top.visible or _map.visible or is_instance_valid(_puzzle) or is_instance_valid(_fishing) or is_instance_valid(_title) or (_sheet_open and not _wide)


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = Settings.ui_scale
	var low := Settings.low_quality()
	if low != Art.low_power:
		# Shapes are cached with or without soft edges: rebuild them.
		Art.low_power = low
		Art.clear_cache()
		if _world:
			_world.repaint_still()
	World.half_rate = Art.low_power


## Room the dock takes at the bottom: its real height (icon + label + margins
## can outgrow DOCK_H), or nothing while it has no buttons.
func _dock_height() -> float:
	if not _dock_laid_out:
		return 0.0
	return maxf(DOCK_H, _dock.get_combined_minimum_size().y)


func _layout() -> void:
	var view := get_viewport_rect().size
	_wide = view.x > view.y * WIDE_ASPECT
	var dock_h := _dock_height()
	_hud.position = Vector2.ZERO
	_hud.size = Vector2(view.x, HUD_H)
	_hud.area_w = view.x - minf(SIDE_W, view.x * 0.4) - 24.0 if _wide else 0.0
	_hud.set_notch(_wide)
	_tabs.floating = _wide
	if _wide:
		var side := minf(SIDE_W, view.x * 0.4)
		var world_w := view.x - side - 36.0
		# The notch floats over the sky, so the rooms fill the whole height.
		_area = Rect2(12, 0, world_w, view.y)
		var tw := minf(RoomTabs.PILL_W, world_w - 2.0 * (HintButton.SIZE + 40.0))
		_tabs.size = Vector2(tw, RoomTabs.PILL_H)
		_tabs.position = Vector2(roundf(12.0 + (world_w - tw) / 2.0), maxf(_hud.used_height() + 10.0, 0.0))
		var top := _hud.used_height() + 10.0 + RoomTabs.PILL_H + 8.0
		_scroller.zoom = clampf(world_w / 960.0, 1.0, 1.7)
		_factory.set_insets(top, 0.0)
		_office.set_insets(top, 0.0)
		_office_bar.visible = false
		_factory_card.visible = false
		_evo_card.visible = false
		_panel.set_docked(true)
		_panel.custom_minimum_size = Vector2(side, 0)
		_dock.fit(side)
		_dock.size = Vector2(side, dock_h)
		_dock.position = Vector2(view.x - side - 12.0, view.y - dock_h)
	else:
		_tabs.size = Vector2(view.x, RoomTabs.STRIP_H)
		# Right under the drawn bar (whole pills visible, nothing tucked under).
		_tabs.position = Vector2(0, _hud.phone_bottom() - 4.0)
		# (+4: the Office badge hangs under its tab; keep it off the room cards.)
		var top := _tabs.position.y + RoomTabs.STRIP_H + 4.0
		_area = Rect2(0, top, view.x, view.y - top - dock_h + 10.0)
		_scroller.zoom = 1.0
		_factory.set_insets(0.0, 10.0)
		_office_bar.visible = true
		_factory_card.visible = true
		_evo_card.visible = true
		_panel.set_docked(false)
		_panel.custom_minimum_size = Vector2(view.x, 0)
		_panel.size = Vector2(view.x, 0)
		_panel.visible = _sheet_open
		_place_sheet()
		_dock.fit(view.x)
		_dock.size = Vector2(view.x, dock_h)
		_dock.position = Vector2(0, view.y - dock_h)
	_place_rooms()
	_scroller.scroll_to(_scroller.scroll)
	_place_room_cards()
	# Lightbulb: top-left over the room, clear of the bar and the tabs.
	_hint_btn.position = Vector2(24, 24) if _wide else Vector2(10, _area.position.y + 18.0)
	_mini.position = Vector2(24.0 + (HintButton.SIZE - MiniMap.SIZE_BIG) / 2.0 + 6.0, 24.0 + HintButton.SIZE + 14.0)
	_layout_side()
	_place_side_buttons()
	_world.surface.boat_card.visible = not _wide
	_world.surface.plant_card.visible = false
	_world.lift.wide = _wide
	_world.lift._place_card()


## Phone: the plant card on the factory wall, the office buttons under the
## office, the evolution card in room 1's row (where the plant card was).
func _place_room_cards() -> void:
	if _wide:
		return
	var a := _factory.card_anchor("plant")
	_factory_card.custom_minimum_size.x = a.size.x
	_factory_card.position = a.position
	_factory_card.reset_size()
	var w := _area.size.x
	_office_bar.custom_minimum_size.x = w - 20.0
	_office_bar.reset_size()
	var bh := _office_bar.get_combined_minimum_size().y
	_office_bar.size = Vector2(w - 20.0, bh)
	_office_bar.position = Vector2(10, _area.size.y - 10.0 - bh - 8.0)
	_office.set_insets(0.0, bh + 26.0)
	_evo_card.position = Vector2(_world.card_x(), 14)
	var boat := _world.surface.boat_card
	if boat.size.y > 0.0:
		_evo_card.custom_minimum_size.y = boat.size.y
	_evo_card.reset_size()


## PC column per room: mine = lift, boat, evolution cards and the panel;
## factory = the plant card and the panel; office = the office card.
func _layout_side() -> void:
	if not _wide:
		_side_cards.visible = false
		_side_office.visible = false
		return
	var view := get_viewport_rect().size
	var side := minf(SIDE_W, view.x * 0.4)
	var office := _room == OFFICE
	_side_cards.visible = not office
	_panel.visible = not office
	_side_office.visible = office
	_side_lift.visible = _room == MINE
	_side_boat.visible = _room == MINE
	_side_evo.visible = _room == MINE
	_side_plant.visible = _room == FACTORY
	if office:
		_side_office.custom_minimum_size = Vector2(side, 0)
		_side_office.position = Vector2(view.x - side - 12.0, 12.0)
		_side_office.size = Vector2(side, 0)
		_side_office.reset_size()
	else:
		_fit_side_column(view, side, _dock_height())
		_side_fit_frames = 2


## Stacks the cards and the upgrade panel above the dock; on short screens
## (or big UI) the pictures shrink, then hide, so it all fits.
func _fit_side_column(view: Vector2, side: float, dock_h: float) -> void:
	if _room == OFFICE:
		return
	var x := view.x - side - 12.0
	var bottom := view.y - dock_h - 8.0
	var panel_hero := 190.0
	var card_pics := true
	for attempt in 3:
		for c in [_side_lift, _side_boat, _side_plant]:
			if c._pic:
				c._pic.visible = card_pics
		_side_evo._pic.visible = card_pics
		_side_cards.position = Vector2(x, 12.0)
		_side_cards.size = Vector2(side, 0)
		_side_cards.reset_size()
		_side_cards.size.x = side
		_panel.set_hero_height(panel_hero)
		_panel.position = Vector2(x, _side_cards.position.y + _side_cards.size.y + 12.0)
		_panel.reset_size()
		var over := _panel.position.y + _panel.size.y - bottom
		if over <= 0.0:
			return
		if panel_hero > 0.0:
			panel_hero = 0.0 if panel_hero - over < 70.0 else panel_hero - over
		else:
			card_pics = false


func _place_sheet() -> void:
	var view := get_viewport_rect().size
	_panel.reset_size()
	_panel.position = Vector2(0, view.y - _panel.size.y)


func _on_stage_selected(key: String) -> void:
	if key.begins_with("room:"):
		show_room(ROOMS.find(key.substr(5)))
		return
	var r := room_of(key)
	if r != _room:
		show_room(r)
	_room_key[r] = key
	_panel.show_stage(key)
	if GameState.is_boat(key) or GameState.is_plant(key):
		# Keep the card on the same unit as the panel.
		var card := stage_card(key)
		if card and card.key != key:
			card.show_unit(key)
	if not _wide:
		var was_open := _sheet_open
		_sheet_open = true
		_panel.visible = true
		_place_sheet.call_deferred()
		if not was_open and not Settings.reduce_motion:
			# Slide up from below the screen.
			(func():
				var y := _panel.position.y
				_panel.position.y = get_viewport_rect().size.y
				_sheet_tween = create_tween()
				_sheet_tween.tween_property(_panel, "position:y", y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)).call_deferred()


func _close_sheet() -> void:
	Sfx.play("click")
	_sheet_open = false
	if not _wide:
		if Settings.reduce_motion:
			_panel.visible = false
			return
		_sheet_tween = create_tween()
		_sheet_tween.tween_property(_panel, "position:y", get_viewport_rect().size.y, 0.16).set_ease(Tween.EASE_IN)
		_sheet_tween.tween_callback(func(): if not _sheet_open: _panel.visible = false)


func _refresh() -> void:
	_world.surface.refresh()
	if _side_cards.visible:
		_side_lift.refresh()
		_side_boat.refresh()
		_side_plant.refresh()
	if _factory_card.is_visible_in_tree():
		_factory_card.refresh()
	for row in _world.rows:
		row.refresh_if_shown()
	_world.lift.refresh()
	if _panel.visible:
		_panel.refresh()
		if not _wide:
			if _sheet_open and not (_sheet_tween and _sheet_tween.is_running()):
				_place_sheet()
		else:
			_panel.reset_size()
			_side_fit_frames = maxi(_side_fit_frames, 1)
	if not _wide and _evo_card.size.y != _world.surface.boat_card.size.y and _world.surface.boat_card.size.y > 0.0:
		_place_room_cards()
	# The dock shows itself when a feature opens (Dock.refresh), so compare
	# with what the layout last made room for, not with its visibility.
	var dock_shown := _dock.count() > 0
	if dock_shown != _dock_laid_out:
		_dock_laid_out = dock_shown
		_dock.visible = dock_shown
		_layout()
		if dock_shown and not Settings.reduce_motion:
			var y := _dock.position.y
			_dock.position.y += _dock.size.y
			create_tween().tween_property(_dock, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _settings_signature() -> Array:
	var s := Settings
	return [s.language, s.voices, s.vibration, s.quality, s.reduce_motion, s.ui_scale, s.number_style, s.avatar.hash(), s.hand_cursor]


func _on_settings_changed() -> void:
	if not is_equal_approx(get_tree().root.content_scale_factor, Settings.ui_scale) or Art.low_power != Settings.low_quality():
		_apply_ui_scale()
	HandCursor.apply(Settings.hand_cursor)
	var sig := _settings_signature()
	var shown_changed := sig != _settings_sig
	_settings_sig = sig
	if not shown_changed:
		# A volume: nothing on screen shows it but the slider being dragged.
		return
	_refresh()
	# The dock's labels only follow Progress otherwise (a new language
	# showed up there late).
	_dock.refresh()
	_hud.queue_redraw()
	_tabs.queue_redraw()
	if _modal.visible:
		_modal.rebuild()
	if _top.visible:
		_top.rebuild()


func _on_milestone(key: String, level: int) -> void:
	if key == "lift":
		# The lift gets a new look at some milestones (Balance.LIFT_LOOKS).
		var look := Balance.lift_look(level)
		if look > Balance.lift_look(int(GameState.upgraded_from.get("lift", level))):
			_show_toast(tr("STAGE_UP") % [Views.stage_name(key), tr("LIFT_STAGE_%d" % look)])
			Sfx.play("unlock")
			return
	var building := GameState.is_boat(key) or GameState.is_plant(key)
	if building and 1 + Balance.milestones(level) <= Balance.BUILDING_STAGES:
		# A milestone of a boat or a plant is a new building stage (up to 20).
		var stage := Balance.building_stage(level)
		var line := "BOAT" if GameState.is_boat(key) else "PLANT"
		_show_toast(tr("STAGE_UP") % [Views.stage_name(key), tr("%s_STAGE_%d" % [line, stage])])
		Sfx.play("unlock")
		return
	_show_toast(tr("MILESTONE_TOAST") % [Views.stage_name(key), level])
	Sfx.play("milestone")


func _show_toast(text: String) -> void:
	# A small calm card in the middle of the screen that fades up and away.
	_toast_label.text = text
	var view := get_viewport_rect().size
	var font := _toast_label.get_theme_font("font")
	var fs := _toast_label.get_theme_font_size("font_size")
	var need := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 72.0
	var w := minf(minf(560.0, view.x - 48.0), need)
	# The label needs its width up front, or wrapping measures it one
	# character per line.
	_toast_label.custom_minimum_size.x = w - 60.0
	_toast_label.size = Vector2(w - 60.0, 0.0)
	# The container's cached minimum size is still the old one this frame,
	# so size the card from the label directly.
	var sb := _toast.get_theme_stylebox("panel")
	_toast.size = Vector2(w, _toast_label.get_minimum_size().y + sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
	var y := roundf(view.y * 0.4 - _toast.size.y / 2.0)
	_toast.position = Vector2(roundf((view.x - _toast.size.x) / 2.0), y)
	_toast.pivot_offset = _toast.size / 2.0
	_toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	if Settings.reduce_motion:
		_toast.modulate.a = 1.0
		_toast.scale = Vector2.ONE
		_toast_tween.tween_interval(TOAST_SEC)
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	else:
		_toast.modulate.a = 0.0
		_toast.scale = Vector2(0.9, 0.9)
		_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.22)
		_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_toast_tween.tween_interval(TOAST_SEC)
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		_toast_tween.parallel().tween_property(_toast, "position:y", y - 26.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(_toast.hide)


## Screen-space point -> scroll the ocean so it sits in the middle.
func scroll_to_screen_point(p: Vector2) -> void:
	if _room != MINE:
		return
	var mid := _scroller.global_position.y + _scroller.size.y * 0.45
	var target := _scroller.scroll + (p.y - mid)
	var tw := create_tween()
	tw.tween_method(func(v: float): _scroller.scroll_to(v), _scroller.scroll, clampf(target, 0.0, _scroller.max_scroll()), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Map, evolution, office ---------------------------------------------------------------

func open_map() -> void:
	if _map.visible:
		return
	_modal.close()
	_map.open()
	_tutor.on_map_opened()


func _on_map_closed() -> void:
	_show_next_news()


## The gate in the map opened the next location: everything follows (the
## world's look, the rooms, the cards), and a little party.
func _on_location_opened(location: int) -> void:
	Sfx.play("prestige")
	Progress.add_pearls(25)
	Progress.save_game()
	_room_key = ["d0", "plant", ""]
	show_room(MINE, false)
	_scroller.scroll_to(0.0)
	if _sheet_open:
		_close_sheet()
	_panel.show_stage("d0")
	for c in [_side_lift, _side_boat, _side_plant, _factory_card, _world.surface.boat_card]:
		c.show_unit(c.base)
	_refresh()
	var v := get_viewport_rect().size
	_fx.burst(v / 2.0, 60)
	_fx.float_text(v / 2.0 + Vector2(0, -60), "+25", Color("f1e6ff"), 40)
	_show_toast(tr("WORLD_WELCOME") % WorldLook.name_of(location))
	if _world.has_method("show_ocean_name"):
		_world.show_ocean_name(location)


func open_evolution() -> void:
	if not _map.visible:
		_modal.open(func(m): EvoPanel.build(m, self), {"wide": true})


## A form was bought in the evolution panel: the party, and the workers in
## room 1 wear it at once (they read GameState.evo).
func on_evo_bought(from: Vector2) -> void:
	_fx.burst(from, 40)
	_fx.float_text(from + Vector2(0, -50), tr("GEAR_NEW"), Art.GOLD, 36)
	_show_toast(tr("GEAR_BOUGHT") % tr(WorkerLooks.gear_key(GameState.world_id(), GameState.evo)))
	for i in Balance.DEPTHS.size():
		if GameState.is_open("d%d" % i):
			_world.react("d%d" % i, "joy", 2.5, true)


func open_outfits() -> void:
	Wardrobe.tab = "outfit"
	_open_wardrobe()


## slot "" keeps the last chosen piece.
func open_decor(slot: String) -> void:
	if slot in Content.DECOR_SLOTS:
		DecorPanel.slot = slot
	_modal.open(func(m): DecorPanel.build(m, self))


func on_decor_bought(_slot: String, from: Vector2) -> void:
	_fx.burst(from, 30)
	_fx.float_text(from + Vector2(0, -50), "+1%", Art.GOLD, 34)


# --- Rewards -------------------------------------------------------------------------

## Shows a reward: coins and pearls fly from `from` into the top bar.
## r: {"coins", "pearls", "boost" (minutes)}.
func celebrate(r: Dictionary, from: Vector2, sound: bool = true) -> void:
	_fx.burst(from, 26)
	var coins := float(r.get("coins", 0.0))
	var pearls := int(r.get("pearls", 0))
	if coins > 0.0:
		_fx.fly("coin", from, _hud.coin_target(), 8)
		_fx.float_text(from + Vector2(0, -40), "+" + NumFormat.short(coins), Art.GOLD)
	if pearls > 0:
		_fx.fly("pearl", from + Vector2(20, 10), _hud.pearl_target(), mini(pearls, 8))
		_fx.float_text(from + Vector2(0, 10), "+%d" % pearls, Color("f1e6ff"), 34)
	if int(r.get("boost", 0)) > 0:
		_fx.float_text(from + Vector2(0, 50), "×2  " + tr("MINUTES") % int(r["boost"]), Art.GOLD, 34)
	if sound:
		Sfx.play("coins")
	Sfx.voice("yay", 1.1)
	Settings.buzz(30)


# --- Side buttons: x2 for an ad, Rivals League ---------------------------------------

## Stacks the shown side buttons under the lightbulb (and the PC mini-map).
func _place_side_buttons() -> void:
	var x := _hint_btn.position.x + (HintButton.SIZE - SideButton.SIZE) / 2.0
	var y := _hint_btn.position.y + HintButton.SIZE + 10.0
	if _wide:
		_mini.position = Vector2(maxf(14.0, _hint_btn.position.x + (HintButton.SIZE - _mini.size.x) / 2.0), y + 4.0)
		if _mini.visible:
			y += _mini.size.y + 14.0
	else:
		_place_rooms()
		var mw := MiniMap.SIZE * PHONE_MINI
		_mini_holder.position = Vector2(roundf(_hint_btn.position.x + (HintButton.SIZE - mw) / 2.0), y)
		if _mini_holder.visible and _mini_holder.modulate.a > 0.5:
			y += _mini_world.size.y * PHONE_MINI + 10.0
	# Not in the first minutes: the game comes first, then the extras.
	var settled := _started and Progress.has_feature("quests")
	_boost_btn.visible = settled and Platform.ads_available()
	# The league lives in the Profile; the trophy shows up only while last
	# week's pearls wait there.
	_rivals_btn.visible = settled and Rivals.reward_pending()
	for b in [_boost_btn, _rivals_btn]:
		if b.visible:
			b.position = Vector2(x, y)
			# The boost's time tag hangs below it.
			y += SideButton.SIZE + (22.0 if b == _boost_btn and GameState.boost_left > 0.0 else 10.0)


func open_boost() -> void:
	_modal.open(func(m): AdBoost.offer(m, self))


func open_rivals() -> void:
	_modal.open(func(m): RivalsView.build(m, self))


# --- Features ------------------------------------------------------------------------

func open_hint() -> void:
	var h := Hints.pick(self)
	_modal.open(func(m): Hints.build(m, self, h))


func open_feature(id: String) -> void:
	Progress.seen(id)
	match id:
		"daily":
			_modal.open(func(m): Views.daily(m, self))
		"quests":
			_modal.open(func(m): Views.quests(m, self))
		"museum":
			_modal.open(func(m): Views.museum(m, self), {"wide": true})
		"shop":
			_open_wardrobe()
		"puzzle":
			open_puzzle()
		"fishing":
			open_fishing()


func _show_next_news() -> void:
	if _news.is_empty() or _top.visible or _modal.visible or _map.visible or is_instance_valid(_puzzle) or is_instance_valid(_fishing) or not _started:
		return
	var id: String = _news.pop_front()
	Sfx.play("unlock")
	var opener := Callable()
	if id in ["daily", "quests", "puzzle", "museum", "shop", "fishing"]:
		opener = func(): open_feature(id)
	_top.open(func(m): Views.feature_intro(m, id, opener))


func _open_wardrobe() -> void:
	if Wardrobe.tab == "suit":
		Wardrobe.tab = "outfit"
	_modal.open(func(m): Wardrobe.build(m, self), {"wide": true})


## The portrait in the top bar: name, look and players (the wardrobe has
## its own dock button).
func open_profile() -> void:
	_modal.open(func(m): SettingsView.profile(m, self))


## back: where "Done" returns (the wardrobe unless given).
func open_avatar_editor(back: Callable = Callable()) -> void:
	var done := back if back.is_valid() else _open_wardrobe
	_modal.open(func(m: Modal):
		AvatarEditor.build(m, func(): done.call()))


# --- Fishing -----------------------------------------------------------------------------

func open_fishing(panel: String = "") -> void:
	if is_instance_valid(_fishing):
		return
	_modal.close()
	_fishing = load("res://scripts/fishing/fishing_screen.gd").new()
	add_child(_fishing)
	move_child(_fishing, _fx.get_index())
	_fishing.setup({"panel": panel} if panel != "" else {})
	_fishing.tree_exited.connect(func():
		_fishing = null
		_show_next_news())
	Sfx.play("start")


# --- Puzzle ------------------------------------------------------------------------------

func open_puzzle() -> void:
	if is_instance_valid(_puzzle) or not ResourceLoader.exists(PUZZLE_SCRIPT):
		return
	_modal.close()
	var level: Dictionary = load(LEVELS_SCRIPT).level(Progress.puzzle_level)
	var target := Progress.target_artifact()
	if target != "":
		level["artifact"] = target
	_puzzle = load(PUZZLE_SCRIPT).new()
	add_child(_puzzle)
	move_child(_puzzle, _fx.get_index())
	_puzzle.setup(level, _puzzle_rewards)
	_puzzle.finished.connect(_on_puzzle_finished)
	_puzzle.tree_exited.connect(func():
		_puzzle = null
		_show_next_news())
	Sfx.play("start")


## Called by the puzzle when a level ends (won, or "collect what you got"):
## grants the rewards and returns the lines its end panel shows.
var _last_puzzle_reward := {}


func _puzzle_rewards(result: Dictionary) -> Array:
	var r := Progress.puzzle_reward(result)
	_last_puzzle_reward = r
	var lines: Array = []
	if r["coins"] > 0.0:
		lines.append(["coin", "+" + NumFormat.short(r["coins"])])
	if r["pearls"] > 0:
		lines.append(["pearl", "+%d" % r["pearls"]])
	if r["piece"] != "":
		var id: String = r["piece"]
		if r["level"] > 0:
			lines.append(["museum", tr("ARTIFACT_UP") % [tr("ART_" + id.to_upper()), r["level"]]])
		else:
			var st: Dictionary = Progress.artifacts[id]
			lines.append(["museum", tr("PIECE_OF") % [tr("ART_" + id.to_upper()), st["pieces"], Progress.pieces_needed(id)]])
	return lines


func _on_puzzle_finished(_result: Dictionary) -> void:
	# The rewards were given when the level ended; now let them fly home.
	if not _last_puzzle_reward.is_empty():
		celebrate({"coins": _last_puzzle_reward["coins"], "pearls": _last_puzzle_reward["pearls"]}, get_viewport_rect().size / 2.0)
		_last_puzzle_reward = {}


# --- Players ------------------------------------------------------------------------------

func open_players() -> void:
	_modal.open(func(m): SettingsView.players(m, self))


## Asks for a name. id "" adds a new player.
func ask_name(id: String, done: Callable) -> void:
	_top.open(func(m: Modal):
		m.title(tr("WHATS_YOUR_NAME"))
		var edit := LineEdit.new()
		edit.max_length = Profiles.NAME_MAX
		edit.placeholder_text = tr("NAME_PLACEHOLDER")
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.custom_minimum_size.y = 84
		edit.text = str(Profiles.find(id).get("name", "")) if id != "" else ""
		m.add(edit)
		var r := m.row(10)
		var dice := Button.new()
		dice.theme_type_variation = &"PurpleButton"
		dice.icon = Icons.get_icon("dice", 36)
		dice.custom_minimum_size = Vector2(90, 76)
		dice.pressed.connect(func():
			Sfx.play("pop")
			edit.text = random_name())
		r.add_child(dice)
		var ok := Button.new()
		ok.text = tr("DONE")
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.custom_minimum_size.y = 76
		var submit := func(_t = ""):
			var name := Profiles.clean_name(edit.text)
			if name == "":
				Sfx.play("deny")
				return
			Sfx.play("click")
			if id == "":
				Profiles.add(name)
			else:
				Profiles.set_name_of(id, name)
			m.close()
			done.call()
		ok.pressed.connect(submit)
		edit.text_submitted.connect(submit)
		r.add_child(ok)
		edit.grab_focus.call_deferred())


static func random_name() -> String:
	var names := TranslationServer.translate("RANDOM_NAMES").split(",")
	return names[randi() % names.size()].strip_edges()


func after_profile_switch() -> void:
	_scroller.scroll_to(0.0)
	_refresh()
	_hud.queue_redraw()
	var report := GameState.take_offline_report()
	if not report.is_empty():
		_show_toast(tr("OFFLINE") % NumFormat.duration(report["seconds"]) + " +" + NumFormat.short(report["coins"]))


# --- Dialogs ------------------------------------------------------------------

func _open_settings() -> void:
	_modal.open(func(m): SettingsView.build(m, self))


func _open_offline(report: Dictionary) -> void:
	_modal.open(func(m: Modal):
		m.text(tr("OFFLINE") % NumFormat.duration(report["seconds"]), 24)
		m.title("+" + NumFormat.short(report["coins"]))
		var b := m.button(tr("COLLECT"), func(): pass, &"GoldButton")
		b.pressed.connect(func():
			celebrate({"coins": report["coins"]}, b.get_global_rect().get_center())
			_modal.close()
			if Progress.daily_ready():
				(func(): open_feature("daily")).call_deferred()))


# --- Streak (StreakView, StreakPop) ----------------------------------------------------

var _streak_pop: StreakPop


func _setup_streak() -> void:
	_streak_pop = StreakPop.new()
	_streak_pop.main = self
	_streak_pop.tapped.connect(open_streak)
	add_child(_streak_pop)
	_hud.streak_pressed.connect(open_streak)
	Progress.streak_lit.connect(_on_streak_lit)


func _on_streak_lit(res: Dictionary) -> void:
	_streak_pop.top_y = (_hud.used_height() if _wide else _hud.phone_bottom()) + 8.0
	_streak_pop.show_result(res)


func open_streak() -> void:
	if _streak_pop.is_showing():
		_streak_pop.hide_pop()
	_modal.open(func(m): StreakView.build(m, self))
