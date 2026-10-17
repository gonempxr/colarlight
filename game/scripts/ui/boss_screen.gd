class_name BossScreen
extends Control
## A mine boss fight (MineBoss, GameState.boss_*), RPG style on an arena:
## the party (Party: guardian, harpooner, alchemist, medic) fights beside
## the player. Heroes attack by themselves and charge their skills (tap a
## hero's card when it glows); the player taps the boss (combo), its
## glowing weak spots (critical hits) and the red target of its attacks
## (parry: the boss is stunned). Unparried attacks hurt a hero; the medic
## heals, the guardian's shield blocks. Health 0: won (GameState.defeat_boss
## pays). The whole party down or time up: lost, the boss heals; try
## again. Every fight gives the party experience (levels). Opened by
## main.open_boss(key).

const BOSS_Y := 0.36
const HIT_R := 165.0
const SPOT_R := 38.0
const SPOTS: Array[Vector2] = [Vector2(-60, -30), Vector2(40, -60), Vector2(0, 30), Vector2(70, 10), Vector2(-80, 40), Vector2(20, -90), Vector2(-30, -70)]
## Health of a level 1 hero with "hp" 1.0 (a number to show, the fight
## works in shares).
const HERO_HP := 1200.0
## Taps feed every hero's skill a little.
const TAP_CHARGE := 0.012
## The heroes' size on the arena.
const HERO_K := 1.35
## Act II rules (MineBoss "rule"): the Automaton's shield phase (only
## skills hurt), the Siren's charm, the Drowned King's sweep, the Hydra's
## heads, the Colossus' slow, heavy blows.
const SHIELD_EVERY := 9.0
const SHIELD_SEC := 4.0
const CHARM_EVERY := 8.0
const SWEEP_HIT := 0.2
const SWEEP_ANGRY := 0.3
const REGROW_SEC := 8.0
const REGROW_SHARE := 0.5
const COLOSSUS_SLOW := 1.4
const COLOSSUS_WIND := 2.0
const COLOSSUS_HIT := 0.55
const COLOSSUS_ANGRY := 0.75
const COLOSSUS_STUN := 1.6
## Act III's rules (MineBoss "rule"): adds every SUMMON_EVERY s (SUMMON_N,
## each ADD_HP of the boss's health); regen = REGEN_RATE of full health per
## second; a curse every CURSE_EVERY s drains CURSE_DRAIN of the hero's
## health per second; flight = up for FLY_SEC every FLY_EVERY s; the
## Ancient One's phase 3 attacks PHASE_FAST times as often.
const SUMMON_EVERY := 11.0
const SUMMON_N := 2
const ADD_HP := 0.05
const REGEN_RATE := 0.01
const CURSE_EVERY := 7.0
const CURSE_DRAIN := 0.035
const FLY_EVERY := 9.0
const FLY_SEC := 3.0
const PHASE_FAST := 0.65

var main: Node
## A world boss fight (WorldBoss): the league's Ancient One, timed, scored
## in taps instead of won.
var world := false
## World fight: my taps of damage this fight, the league id.
var _wb_units := 0.0
var _wb_league := 0
## The guarded site ("d3"...).
var key := ""
var _boss := ""
var _state := "ready"
var _hp := 1.0
var _hp_max := 1.0
var _hp_trail := 1.0
var _left := MineBoss.FIGHT_SEC
var _combo := 0
var _combo_left := 0.0
var _t := 0.0
var _hurt := 0.0
var _shake := 0.0
var _flash := 0.0
var _spot := Vector2.ZERO
var _spot_left := 0.0
var _spot_wait := 1.0
## The boss's attack: wind-up left (0 = none), next one in, its target hero.
var _wind := 0.0
var _attack_in := MineBoss.ATTACK_EVERY
var _target := 0
var _stun := 0.0
## The alchemist's bomb: the boss takes more damage while this runs.
var _break := 0.0
## The guardian's shield blocks the next attack.
var _shield := false
## The heroes: [{c, lv, hp, max, charge, wait, ko, hurt}].
var _heroes: Array = []
## The boss's rule ("" for act I's guards).
var _rule := ""
## Automaton: shield up for this long / next shield in.
var _bshield := 0.0
var _bshield_in := SHIELD_EVERY
## Siren Queen: next charm in.
var _charm_in := CHARM_EVERY
## Oracle's prophecy: every tap a critical hit for this long.
var _prophecy := 0.0
## Hydra: [{"hp", "max", "regrow"}] x 3.
var _heads: Array = []
## Deep One Priest: the adds' health; next summon in.
var _adds: Array = []
var _summon_in := SUMMON_EVERY
## Priest of Dagon: next curse in.
var _curse_in := CURSE_EVERY
## Star-Spawn: up in the water for this long / next flight in.
var _fly := 0.0
var _fly_in := FLY_EVERY
## The Ancient One's phase (1..3).
var _phase := 1
## The Astronomer's Elder Sign: the boss's attacks slowed for this long.
var _slow := 0.0
## Shots in flight: [from, to, age, damage, color, kind].
var _shots: Array = []
var _taps: Array[float] = []
var _rng := RandomNumberGenerator.new()
## Floating words and numbers: [pos, text, color, age, size].
var _pops: Array = []
## Sparks: [pos, vel, age, color].
var _sparks: Array = []
var _level_ups: Array = []
var _fight: Control
var _hud: Control
var _panel: VBoxContainer
var _cards: HBoxContainer


static func t(k: String) -> String:
	return TranslationServer.translate(k)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_boss = "ancient_one" if world else GameState.boss_at(key)
	_rule = str(MineBoss.data(_boss).get("rule", ""))
	_hp_max = maxf(1.0, _tap_unit() * WorldBoss.BAR_TAPS if world else GameState.boss_hp(key))
	_hp = _hp_max
	_hp_trail = _hp
	_reset_heads()
	_make_party()
	var bg := ArtView.make(func(ci: CanvasItem, s: Vector2, tt: float): draw_arena(ci, s, tt), Vector2.ZERO, true)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_fight = Control.new()
	_fight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fight.mouse_filter = Control.MOUSE_FILTER_STOP
	_fight.draw.connect(_draw_fight)
	_fight.gui_input.connect(_on_input)
	add_child(_fight)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(_top_bar())
	_hud = Control.new()
	_hud.custom_minimum_size = Vector2(0, 108)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	col.add_child(_hud)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	col.add_child(_panel)
	_show_panel()
	Sfx.play("start")


func _make_party() -> void:
	_heroes = []
	for m in GameState.party():
		var d: Dictionary = Party.CLASSES[m["c"]]
		var mx := HERO_HP * float(d["hp"]) * Party.power(int(m["lv"]))
		_heroes.append({"c": m["c"], "lv": int(m["lv"]), "hp": mx, "max": mx, "charge": 0.0,
			"wait": 0.3 + _heroes.size() * 0.25, "ko": false, "hurt": 0.0, "swing": 0.0, "charm": false, "curse": false})


func _reset_heads() -> void:
	_heads = []
	if _rule == "heads":
		for i in 3:
			_heads.append({"hp": _hp_max / 3.0, "max": _hp_max / 3.0, "regrow": 0.0})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _top_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.theme_type_variation = &"RedButton"
	back.icon = Icons.get_icon("close", 34)
	back.custom_minimum_size = Vector2(76, 76)
	back.pressed.connect(close)
	h.add_child(back)
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(0, 76)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.draw.connect(func(): UiTheme.draw_banner(banner, Rect2(Vector2.ZERO, banner.size), Color("b0306a")))
	banner.resized.connect(banner.queue_redraw)
	var l := Label.new()
	l.text = t(MineBoss.name_key(_boss))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_bottom = -6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.heavy_font())
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_constant_override("outline_size", 10)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	banner.add_child(l)
	h.add_child(banner)
	return h


# --- Geometry -------------------------------------------------------------------------

## One plain tap's damage (the world boss counts damage in these).
func _tap_unit() -> float:
	return maxf(1e-9, GameState.boss_hit(key) * MineBoss.TAP_SHARE)


func _fight_sec() -> float:
	return WorldBoss.FIGHT_SEC if world else MineBoss.FIGHT_SEC


func _center() -> Vector2:
	var bob := snappedf(sin(_t * 1.6) * 8.0, 1.0) if _state != "won" else 0.0
	return Vector2(size.x / 2.0, size.y * BOSS_Y + bob)


func _scale() -> float:
	return clampf(minf(size.x / 480.0, size.y / 900.0), 0.72, 1.4)


func _hero_pos(i: int) -> Vector2:
	var n := float(_heroes.size())
	var step := minf(size.x * (0.3 if n <= 2.0 else (0.235 if n <= 4.0 else (0.19 if n <= 5.0 else 0.158))), 240.0)
	return Vector2(size.x / 2.0 + (i - (n - 1.0) / 2.0) * step, size.y * 0.64 + (i % 2) * 18.0)


func _attack_target() -> Vector2:
	return _center() + Vector2(0, -150.0 * _scale())


func _alive() -> Array[int]:
	var out: Array[int] = []
	for i in _heroes.size():
		if not _heroes[i]["ko"]:
			out.append(i)
	return out


# --- The arena ------------------------------------------------------------------------

## The arena behind every fight: deep water lit from above, reef walls on
## both sides, glowing corals, a lit sand stage.
static func draw_arena(ci: CanvasItem, s: Vector2, tt: float) -> void:
	var top := Color("3a2290")
	var mid := Color("1a1460")
	var low := Color("080a26")
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.5), Vector2(0, s.y * 0.5)]), PackedColorArray([top, top, mid, mid]))
	Art.grad(ci, PackedVector2Array([Vector2(0, s.y * 0.5), Vector2(s.x, s.y * 0.5), s, Vector2(0, s.y)]), PackedColorArray([mid, mid, low, low]))
	for i in 4:
		var x := s.x * (0.12 + i * 0.25)
		var sway := snappedf(sin(tt * 0.35 + i) * 18.0, 3.0)
		Art.grad(ci, PackedVector2Array([Vector2(x - 26 + sway, 0), Vector2(x + 26 + sway, 0), Vector2(x + 130, s.y * 0.75), Vector2(x - 40, s.y * 0.75)]),
			PackedColorArray([Color(0.75, 0.9, 1.0, 0.16), Color(0.75, 0.9, 1.0, 0.16), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))
	var far := Color("140f48")
	for i in 6:
		var x := s.x * (i / 5.0)
		var h := s.y * (0.22 + 0.08 * ((i * 7) % 3))
		Art.flat(ci, Art.smooth_pts(PackedVector2Array([Vector2(x - 70, s.y * 0.7), Vector2(x - 30, s.y * 0.7 - h * 0.6), Vector2(x - 6, s.y * 0.7 - h),
			Vector2(x + 24, s.y * 0.7 - h * 0.7), Vector2(x + 70, s.y * 0.7)]), 3), far)
	var stage_y := s.y * 0.6
	Art.flat(ci, Art.ellipse_pts(Vector2(s.x / 2.0, stage_y + 50), Vector2(s.x * 0.75, 90), 40), Color("2a2468"))
	Art.flat(ci, Art.ellipse_pts(Vector2(s.x / 2.0, stage_y + 40), Vector2(s.x * 0.6, 64), 40), Color("3e3486"))
	Art.glow(ci, Vector2(s.x / 2.0, stage_y), s.x * 0.45, Color(0.6, 0.85, 1.0, 0.2), 28)
	Art.grad(ci, PackedVector2Array([Vector2(0, s.y * 0.72), Vector2(s.x, s.y * 0.72), s, Vector2(0, s.y)]),
		PackedColorArray([Color("1c1650"), Color("1c1650"), Color("0a0a26"), Color("0a0a26")]))
	for side in 2:
		var x0 := -10.0 if side == 0 else s.x + 10.0
		var dir := 1.0 if side == 0 else -1.0
		for k in 7:
			var c := Vector2(x0 + dir * (20.0 + (k % 2) * 34.0), s.y * (0.24 + k * 0.1))
			ReefArt.boulder(ci, c, Vector2(56.0 - (k % 3) * 8.0, 40.0), Color("2a2470").lerp(Color("15123e"), k / 7.0))
		for k in 3:
			var p := Vector2(x0 + dir * (40.0 + k * 22.0), s.y * (0.58 + k * 0.05))
			var sway := snappedf(sin(tt * 1.2 + k + side) * 0.08, 0.02)
			Art.push(ci, p, sway, Vector2(2.2, 2.2))
			ReefArt.coral_tuft(ci, Vector2.ZERO, ReefArt.CORAL[(k + side * 2) % ReefArt.CORAL.size()], 1.0, (k + side) % 3)
			Art.pop(ci)
			Art.glow(ci, p + Vector2(0, -24), 40.0, Color(ReefArt.CORAL[(k + side * 2) % ReefArt.CORAL.size()], 0.22), 14)
	for i in 16:
		var bx := fposmod(i * 97.0, s.x)
		var by := s.y - fposmod(snappedf(tt * (18.0 + i * 3.0), 2.0) + i * 131.0, s.y + 40.0)
		Art.dot(ci, Vector2(bx, by), 1.5 + i % 3, Color("bfe8ff", 0.35))
	var v := Color(0.02, 0.0, 0.08, 0.6)
	var n := Color(v, 0.0)
	Art.grad(ci, PackedVector2Array([Vector2.ZERO, Vector2(70, 0), Vector2(70, s.y), Vector2(0, s.y)]), PackedColorArray([v, n, n, v]))
	Art.grad(ci, PackedVector2Array([Vector2(s.x - 70, 0), Vector2(s.x, 0), s, Vector2(s.x - 70, s.y)]), PackedColorArray([n, v, v, n]))


# --- Drawing --------------------------------------------------------------------------

func _draw_fight() -> void:
	var ci := _fight
	var shake := Vector2(snappedf(sin(_t * 90.0) * 10.0 * _shake, 1.0), snappedf(cos(_t * 77.0) * 6.0 * _shake, 1.0))
	Art.push(ci, shake)
	var c := _center()
	var k := _scale()
	var anger := clampf(1.0 - _hp / _hp_max, 0.0, 1.0) if _state == "fight" else 0.0
	Art.flat(ci, Art.ellipse_pts(Vector2(c.x, c.y + 150.0 * k), Vector2(140.0 * k, 24.0 * k), 28), Color(0.02, 0.0, 0.1, 0.4))
	if _state == "won":
		Art.push(ci, c + Vector2(0, 80.0 * k), -0.3)
		BossArt.draw(ci, _boss, Vector2.ZERO, k * 0.9, 0.0, 1.0, 0.0)
		Art.pop(ci)
		for i in 5:
			var a := _t * 2.4 + i * TAU / 5.0
			var p := c + Vector2(cos(a) * 80.0, sin(a) * 18.0 - 50.0) * k
			Art.toon(ci, Art.star_pts(Vector2(snappedf(p.x, 1.0), snappedf(p.y, 1.0)), 14.0, 6.0, 5), Art.GOLD, 2.4, 0.0)
	else:
		if _break > 0.0:
			Art.glow(ci, c, 210.0 * k, Color(0.8, 0.3, 1.0, 0.3))
		if _stun > 0.0:
			Art.glow(ci, c, 200.0 * k, Color(0.5, 0.9, 1.0, 0.25))
		elif _wind > 0.0:
			Art.glow(ci, c, 230.0 * k, Color(1.0, 0.2, 0.3, snappedf(0.25 + 0.2 * sin(_t * 18.0), 0.05)))
		Art.push(ci, c, -0.12 if _wind > 0.0 else 0.0)
		BossArtAtlantis.shielded = _bshield > 0.0
		BossArtAtlantis.heads = _heads.map(func(h): return float(h["hp"]) > 0.0) if not _heads.is_empty() else [true, true, true]
		BossArtRlyeh.phase = _phase
		BossArtRlyeh.flying = _fly > 0.0
		BossArt.draw(ci, _boss, Vector2.ZERO, k, _t * (0.3 if _stun > 0.0 else 1.0), _hurt, maxf(anger, 1.0 if _wind > 0.0 else 0.0))
		BossArtAtlantis.shielded = false
		BossArtAtlantis.heads = [true, true, true]
		BossArtRlyeh.phase = 1
		BossArtRlyeh.flying = false
		Art.pop(ci)
		if _slow > 0.0:
			# The Elder Sign hanging over the boss.
			Art.glow(ci, c + Vector2(0, -190.0 * k), 50.0 * k, Color(0.5, 0.6, 1.0, 0.4))
			Art.toon(ci, Art.star_pts(c + Vector2(0, -190.0 * k), 26.0 * k, 11.0 * k, 5), Color("aab4ff"), 2.4, 0.3)
			Art.dot(ci, c + Vector2(0, -190.0 * k), 6.0 * k, Color("7dff6a"))
		for i in _adds.size():
			_draw_add(ci, c + Vector2(-170.0 + i * 340.0, 70.0) * k, k, float(_adds[i]))
		if _prophecy > 0.0:
			Art.glow(ci, c, 190.0 * k, Color(1.0, 0.85, 0.3, 0.22))
		if _stun > 0.0:
			for i in 3:
				var a := _t * 4.0 + i * TAU / 3.0
				Art.toon(ci, Art.star_pts(c + Vector2(cos(a) * 60.0, -120.0 + sin(a) * 12.0) * k, 12.0, 5.0, 5), Color("bff8ff"), 2.2, 0.0)
	_draw_heroes(ci, k)
	if _state == "fight":
		_draw_spot(ci, c, k)
		if _wind > 0.0:
			_draw_attack(ci, k)
	for h in _shots:
		var f: float = clampf(float(h[2]) / 0.3, 0.0, 1.0)
		var a: Vector2 = h[0]
		var b: Vector2 = h[1]
		var p := a.lerp(b, f)
		var d := (b - a).normalized()
		var col: Color = h[4]
		if h[5] == "harpoon" or h[5] == "volley":
			Art.line(ci, p - d * 28.0, p, Color("e8e2d0"), 3.5)
			Art.flat(ci, PackedVector2Array([p + d * 9.0, p + d.orthogonal() * 5.0, p - d.orthogonal() * 5.0]), Color("d9a441"))
		else:
			Art.glow(ci, p, 18.0, Color(col, 0.6), 10)
			Art.disc(ci, p, 6.0, col.lightened(0.4))
	for sp in _sparks:
		var a2: float = 1.0 - float(sp[2]) / 0.5
		Art.dot(ci, sp[0], 3.0 + 3.0 * a2, Color(sp[3], snappedf(a2, 0.05)))
	for p in _pops:
		var a3: float = clampf(1.3 - float(p[3]), 0.0, 1.0)
		var col2: Color = p[2]
		var grow := 1.0 + 0.45 * clampf(1.0 - float(p[3]) * 6.0, 0.0, 1.0)
		Art.text(ci, p[0] + Vector2(0, -float(p[3]) * 70.0), str(p[1]), int(int(p[4]) * grow), Color(col2, snappedf(a3, 0.05)), 8)
	if _flash > 0.0:
		Art.flat(ci, PackedVector2Array([Vector2(-20, -20), Vector2(size.x + 20, -20), size + Vector2(20, 20), Vector2(-20, size.y + 20)]), Color(1, 1, 1, snappedf(0.5 * _flash, 0.05)))
	Art.pop(ci)


func _draw_heroes(ci: CanvasItem, k: float) -> void:
	var form := int(GameState.evo)
	# Four heroes on a phone stand a little smaller.
	if _heroes.size() >= 4 and size.x < 800.0:
		k *= 0.85 if _heroes.size() == 4 else (0.74 if _heroes.size() == 5 else 0.64)
	for i in _heroes.size():
		var h: Dictionary = _heroes[i]
		var p := _hero_pos(i)
		var d: Dictionary = Party.CLASSES[h["c"]]
		var suit: Color = d["suit"]
		var facing := 1.0 if p.x <= size.x / 2.0 else -1.0
		if h["ko"]:
			Art.push(ci, p + Vector2(0, 20.0 * k), facing * 1.4)
			Chars.diver(ci, Vector2.ZERO, HERO_K * k, suit.darkened(0.4), facing, 0.0, 0.0, "swim", 0.0, false, suit, "sad", true, 0.0, 0,
				{"world": GameState.world_id(), "form": form})
			Art.pop(ci)
			continue
		var swing := float(h["swing"])
		var hurt := float(h["hurt"])
		var off := Vector2(snappedf(sin(_t * 60.0) * 6.0 * hurt, 1.0), snappedf(-10.0 * swing, 1.0))
		if _shield and h["c"] == "guardian":
			Art.glow(ci, p + Vector2(0, -20) * k, 70.0 * k, Color(0.4, 0.7, 1.0, 0.45))
		# A class-colored ring under each hero (tells the classes apart).
		Art.flat(ci, Art.ellipse_pts(p + Vector2(0, 40.0 * k), Vector2(50.0 * k, 12.0 * k), 18), Color(suit, 0.35))
		Art.ring(ci, Art.ellipse_pts(p + Vector2(0, 40.0 * k), Vector2(50.0 * k, 12.0 * k), 18), Color(suit.lightened(0.3), 0.8), 3.0)
		Chars.diver(ci, p + off, HERO_K * k, suit, facing, -0.2 * facing, snappedf(sin(_t * 4.0 + i), 0.1), "swim", swing, false, suit,
			"angry" if _state == "fight" else "happy", false, _t + i, 0, {"world": GameState.world_id(), "form": form})
		_hero_prop(ci, h["c"], p + off + Vector2(26.0 * facing, -20.0) * k, k * 1.4, facing)
		# Health over the head.
		var bw := 110.0 * k
		var bar := Rect2(p.x - bw / 2.0, p.y - 108.0 * k, bw, 16.0 * k)
		Art.t_rect(ci, bar, 5.0 * k, Color("2a1050"), 2.0, 0.0)
		# The class badge and level at the bar's left end.
		Art.t_circle(ci, bar.position + Vector2(-4.0, bar.size.y / 2.0), 15.0 * k, suit, 2.4, 0.3)
		Art.text(ci, bar.position + Vector2(-4.0, bar.size.y / 2.0 + 7.0 * k), str(int(h["lv"])), int(19 * k), Art.WHITE, 5)
		var f := clampf(float(h["hp"]) / float(h["max"]), 0.0, 1.0)
		if f > 0.02:
			Art.flat(ci, Art.rrect_pts(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4.0) * f, bar.size.y - 4.0)), 3.0 * k), Color("4ae08a") if f > 0.35 else Color("ff5a5a"))
		if _wind > 0.0 and (i == _target or _sweeps()):
			Art.text(ci, p + Vector2(0, -122.0 * k), "!", int(48 * k), Color("ff5a6a"), 8)
		if h["charm"]:
			# Charmed by the siren's song: hearts over the head, no attacks.
			for j in 3:
				var a := _t * 2.0 + j * TAU / 3.0
				var hp := p + Vector2(cos(a) * 30.0, -140.0 + sin(a) * 8.0) * k
				Art.toon(ci, _heart_pts(Vector2(snappedf(hp.x, 1.0), snappedf(hp.y, 1.0)), 9.0 * k), Color("ff7ad0"), 2.0, 0.0)
		if h["curse"]:
			# Dagon's curse: a violet eye over the head, green drips.
			var cp := p + Vector2(0, -140.0 * k)
			Art.glow(ci, cp, 30.0 * k, Color(0.55, 0.3, 0.95, 0.45))
			MurkVeil.eye(ci, cp, 11.0 * k, false, false)
			for j in 2:
				var fd := fposmod(_t * 1.5 + j * 0.5, 1.0)
				Art.dot(ci, cp + Vector2((-8.0 + j * 16.0) * k, snappedf(fd * 40.0, 2.0) * k), 3.0 * k, Color(0.5, 1.0, 0.4, 1.0 - fd))


## A Deep One add beside the Priest: a small fish-man with its health.
func _draw_add(ci: CanvasItem, at: Vector2, k: float, hp: float) -> void:
	var bob := snappedf(sin(_t * 3.0 + at.x) * 4.0, 1.0)
	Art.push(ci, at + Vector2(0, bob), 0.0, Vector2(k, k))
	Art.toon(ci, Art.ellipse_pts(Vector2(0, 10), Vector2(34, 40), 18), BossArtRlyeh.SKIN, 3.0, 0.6)
	for s: float in [-1.0, 1.0]:
		BossArt.eye(ci, Vector2(s * 12, -6), 9.0, Color("ffe066"), 0.0, 0.5, s)
	BossArt.mouth(ci, Vector2(0, 16), 14.0, 0.4, 3)
	var bar := Rect2(-34, -50, 68, 10)
	Art.t_rect(ci, bar, 4.0, Color("2a1050"), 1.6, 0.0)
	var f := clampf(hp / maxf(1.0, _hp_max * ADD_HP), 0.0, 1.0)
	if f > 0.02:
		Art.flat(ci, Art.rrect_pts(Rect2(bar.position + Vector2(1.5, 1.5), Vector2((bar.size.x - 3.0) * f, bar.size.y - 3.0)), 3.0), Color("6ae07a"))
	Art.pop(ci)


## This boss's blows hit the whole party (the Drowned King, the Ancient One from phase 2).
func _sweeps() -> bool:
	return _rule == "sweep" or (_rule == "phases" and _phase >= 2)


static func _heart_pts(c: Vector2, r: float) -> PackedVector2Array:
	return Art.smooth_pts(PackedVector2Array([c + Vector2(0, r), c + Vector2(-r, -r * 0.1), c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(0, -r * 0.4),
		c + Vector2(r * 0.6, -r * 0.8), c + Vector2(r, -r * 0.1)]), 3)


## What each class holds: a shield, a harpoon gun, a flask, a med kit, an orb.
func _hero_prop(ci: CanvasItem, c: String, at: Vector2, k: float, facing: float) -> void:
	Art.push(ci, at, 0.0, Vector2(k * facing, k))
	match c:
		"guardian":
			Art.toon(ci, Art.smooth_pts(PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(14, 4), Vector2(0, 20), Vector2(-14, 4)]), 2), Color("4a8af0"), 2.6, 0.5)
			Art.toon(ci, Art.star_pts(Vector2(0, -2), 8.0, 3.5, 5), Color("ffd23f"), 1.6, 0.0)
		"harpooner":
			Art.t_rect(ci, Rect2(-6, -6, 44, 12), 4.0, Color("5a6a8a"), 2.4, 0.4)
			Art.t_rect(ci, Rect2(34, -3, 16, 6), 2.0, Color("d9a441"), 2.0, 0.0)
		"alchemist":
			Art.glow(ci, Vector2(6, -6), 20.0, Color(0.8, 0.4, 1.0, 0.5), 10)
			Art.t_circle(ci, Vector2(6, -2), 11.0, Color("c25aff"), 2.4, 0.5)
			Art.t_rect(ci, Rect2(2, -20, 8, 10), 2.0, Color("e8e2d0"), 2.0, 0.0)
		"astronomer":
			# A brass telescope.
			Art.push(ci, Vector2(4, -6), -0.5)
			Art.t_rect(ci, Rect2(-6, -6, 40, 12), 4.0, Color("d9a441"), 2.4, 0.4)
			Art.t_rect(ci, Rect2(30, -9, 12, 18), 3.0, Color("7a8aff"), 2.2, 0.3)
			Art.pop(ci)
		"oracle":
			Art.line(ci, Vector2(0, 20), Vector2(14, -30), Color("8a5424"), 4.0)
			Art.glow(ci, Vector2(16, -34), 18.0, Color(1.0, 0.85, 0.3, 0.55), 10)
			Art.t_circle(ci, Vector2(16, -34), 9.0, Color("ffe07a"), 2.2, 0.4)
			Art.t_circle(ci, Vector2(16, -34), 3.5, Color("4af0e0"), 0.0, 0.0)
		"medic":
			Art.t_rect(ci, Rect2(-4, -14, 28, 22), 4.0, Art.WHITE, 2.4, 0.3)
			Art.t_rect(ci, Rect2(7, -11, 6, 16), 1.0, Color("ff4a5a"), 0.0, 0.0)
			Art.t_rect(ci, Rect2(2, -6, 16, 6), 1.0, Color("ff4a5a"), 0.0, 0.0)
	Art.pop(ci)


func _draw_spot(ci: CanvasItem, c: Vector2, k: float) -> void:
	if _spot_left <= 0.0:
		return
	var p := c + _spot * k
	var life := float(MineBoss.data(_boss)["spot_life"])
	var f := clampf(_spot_left / life, 0.0, 1.0)
	var pulse := snappedf(1.0 + 0.12 * sin(_t * 14.0), 0.02)
	Art.glow(ci, p, 60.0 * k * pulse, Color(1.0, 0.9, 0.3, 0.55))
	Art.toon(ci, Art.star_pts(p, 24.0 * k * pulse, 11.0 * k * pulse, 4, snappedf(_t * 1.5, 0.05)), Color("ffe066"), 3.0, 0.3)
	Art.t_circle(ci, p, 7.0 * k, Art.WHITE, 0.0, 0.0)
	Art.arc(ci, p, snappedf(SPOT_R * k, 0.5), -PI / 2.0, -PI / 2.0 + TAU * snappedf(f, 0.02), 32, Color(1, 1, 1, 0.85), 4.0)


func _draw_attack(ci: CanvasItem, k: float) -> void:
	var p := _attack_target()
	var f := clampf(_wind / MineBoss.ATTACK_WIND, 0.0, 1.0)
	Art.glow(ci, p, 70.0 * k, Color(1.0, 0.2, 0.25, 0.6))
	Art.t_circle(ci, p, 34.0 * k, Color("ff3a4a"), 3.5, 0.4)
	Art.t_circle(ci, p, 20.0 * k, Art.WHITE, 2.5, 0.0)
	Art.t_circle(ci, p, 9.0 * k, Color("ff3a4a"), 0.0, 0.0)
	Art.arc(ci, p, snappedf(46.0 * k, 0.5), -PI / 2.0, -PI / 2.0 + TAU * snappedf(f, 0.02), 32, Color("ffd0d4"), 5.0)
	Art.text(ci, p + Vector2(0, -56.0 * k), t("BOSS_PARRY_TAP"), int(26 * k), Color("ffd0d4"), 7)


func _draw_hud() -> void:
	var s := _hud.size
	var bar := Rect2(58, 8, s.x - 66, 48)
	Art.t_rect(_hud, bar, 24.0, Color("2a1050"), 4.0, 0.0)
	var inner := bar.grow(-5.0)
	var tf := clampf(_hp_trail / _hp_max, 0.0, 1.0)
	var f := clampf(_hp / _hp_max, 0.0, 1.0)
	if tf > 0.005:
		Art.flat(_hud, Art.rrect_pts(Rect2(inner.position, Vector2(maxf(36.0, inner.size.x * tf), inner.size.y)), 19.0), Color(1, 1, 1, 0.85))
	if f > 0.005:
		var fill := Rect2(inner.position, Vector2(maxf(36.0, inner.size.x * f), inner.size.y))
		Art.flat(_hud, Art.rrect_pts(fill, 19.0), Color("b04cff") if _break > 0.0 else Color("e8304f"))
		Art.flat(_hud, Art.rrect_pts(Rect2(fill.position + Vector2(8, 4), Vector2(maxf(10.0, fill.size.x - 16.0), fill.size.y * 0.36)), 7.0), Color(1, 1, 1, 0.3))
	for i in range(1, 10):
		var x := inner.position.x + inner.size.x * i / 10.0
		Art.line(_hud, Vector2(x, inner.position.y + 4), Vector2(x, inner.end.y - 4), Color(0.1, 0.0, 0.2, 0.35), 2.0)
	var bar_text := NumFormat.short(_hp) + " / " + NumFormat.short(_hp_max)
	if world:
		bar_text = t("WB_TAPS") % roundi((_hp_max - _hp) / _tap_unit())
	Art.text(_hud, bar.get_center() + Vector2(14, 10), bar_text, 26, Art.WHITE, 7)
	Art.t_circle(_hud, Vector2(42, 32), 36.0, Color("2a1050"), 4.0, 0.0)
	BossArt.portrait(_hud, _boss, Vector2(42, 32), 31.0, _t)
	# Status tags under the bar.
	var tx := 88.0
	if _break > 0.0:
		Art.text(_hud, Vector2(tx, 90), t("BOSS_BREAK"), 22, Color("e0a0ff"), 6, false)
		tx += 130.0
	if _stun > 0.0:
		Art.text(_hud, Vector2(tx, 90), t("BOSS_STUN"), 22, Color("bff8ff"), 6, false)
		tx += 130.0
	if _bshield > 0.0:
		Art.text(_hud, Vector2(tx, 90), t("BOSS_SHIELD"), 22, Color("ffe07a"), 6, false)
		tx += 150.0
	if _prophecy > 0.0:
		Art.text(_hud, Vector2(tx, 90), t("BOSS_PROPHECY"), 22, Color("ffe07a"), 6, false)
		tx += 150.0
	var tag := ""
	if _fly > 0.0:
		tag = t("BOSS_FLYING")
	elif _rule == "regen" and _break <= 0.0:
		tag = t("BOSS_REGEN")
	elif _rule == "phases":
		tag = t("BOSS_PHASE") % _phase
	elif not _adds.is_empty():
		tag = t("BOSS_ADDS") % _adds.size()
	elif _slow > 0.0:
		tag = t("BOSS_ELDER")
	if tag != "":
		Art.text(_hud, Vector2(tx, 90), tag, 22, Color("9aff8a"), 6, false)
	# The Hydra's heads: three small bars under the big one.
	if not _heads.is_empty():
		var hw := (inner.size.x - 20.0) / 3.0
		for i in 3:
			var hr := Rect2(inner.position.x + i * (hw + 10.0), bar.end.y + 2.0, hw, 10.0)
			var h: Dictionary = _heads[i]
			Art.t_rect(_hud, hr, 4.0, Color("2a1050"), 1.6, 0.0)
			var hf := clampf(float(h["hp"]) / float(h["max"]), 0.0, 1.0)
			if hf > 0.02:
				Art.flat(_hud, Art.rrect_pts(Rect2(hr.position + Vector2(1.5, 1.5), Vector2((hr.size.x - 3.0) * hf, hr.size.y - 3.0)), 3.0), Color("6ae07a"))
			elif float(h["regrow"]) > 0.0:
				Art.flat(_hud, Art.rrect_pts(Rect2(hr.position + Vector2(1.5, 1.5), Vector2((hr.size.x - 3.0) * (1.0 - float(h["regrow"]) / REGROW_SEC), hr.size.y - 3.0)), 3.0), Color(1.0, 0.4, 0.4, 0.6))
	var cc := Vector2(s.x - 40, 84)
	var cf := clampf(_left / _fight_sec(), 0.0, 1.0)
	Art.t_circle(_hud, cc, 24.0, Color("10204a"), 3.0, 0.0)
	Art.arc(_hud, cc, 19.0, -PI / 2.0, -PI / 2.0 + TAU * snappedf(cf, 0.01), 36, Color("6af8ff") if cf > 0.25 else Color("ffd23f"), 6.0)
	Art.text(_hud, cc + Vector2(0, 8), "%d" % ceili(_left), 22, Art.WHITE, 6)
	if _combo >= 3 and _state == "fight":
		Art.text(_hud, Vector2(s.x / 2.0 + 40, 92), t("BOSS_COMBO") % [_combo, MineBoss.combo_mult(_combo)], 26, Color("ffe066"), 7)


# --- Fight ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta * 4.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 3.0)
	_hp_trail = maxf(_hp, _hp_trail - _hp_max * delta * 0.6) if _hp_trail > _hp else _hp
	for h in _heroes:
		h["hurt"] = maxf(0.0, float(h["hurt"]) - delta * 3.0)
		h["swing"] = maxf(0.0, float(h["swing"]) - delta * 4.0)
	for p in _pops:
		p[3] = float(p[3]) + delta
	_pops = _pops.filter(func(p): return float(p[3]) < 1.3)
	if _pops.size() > 40:
		_pops = _pops.slice(_pops.size() - 40)
	for sp in _sparks:
		sp[0] = sp[0] + sp[1] * delta
		sp[2] = float(sp[2]) + delta
	_sparks = _sparks.filter(func(sp): return float(sp[2]) < 0.5)
	if _state == "fight":
		_tick(delta)
	_fight.queue_redraw()
	_hud.queue_redraw()
	if _cards:
		for c in _cards.get_children():
			c.queue_redraw()


func _tick(delta: float) -> void:
	_left -= delta
	_combo_left -= delta
	if _combo_left <= 0.0:
		_combo = 0
	_stun = maxf(0.0, _stun - delta)
	_break = maxf(0.0, _break - delta)
	_prophecy = maxf(0.0, _prophecy - delta)
	_slow = maxf(0.0, _slow - delta)
	_tick_rule(delta)
	if _spot_left > 0.0:
		_spot_left -= delta
	else:
		_spot_wait -= delta
		if _spot_wait <= 0.0 and _wind <= 0.0:
			_new_spot()
	if _wind > 0.0:
		_wind -= delta
		if _wind <= 0.0:
			_attack_lands()
	elif _stun <= 0.0 and _fly <= 0.0:
		_attack_in -= delta / (Party.ELDER_SLOW if _slow > 0.0 else 1.0)
		if _attack_in <= 0.0:
			var alive := _alive()
			if not alive.is_empty():
				_target = alive[_rng.randi() % alive.size()]
				_wind = COLOSSUS_WIND if _rule == "colossus" else MineBoss.ATTACK_WIND
				_spot_left = 0.0
	# The heroes attack and charge their skills.
	for i in _heroes.size():
		var h: Dictionary = _heroes[i]
		if h["ko"]:
			continue
		var d: Dictionary = Party.CLASSES[h["c"]]
		if h["charm"]:
			continue
		h["charge"] = minf(1.0, float(h["charge"]) + delta / float(d["charge"]))
		h["wait"] = float(h["wait"]) - delta
		if float(h["wait"]) <= 0.0:
			h["wait"] = float(d["every"]) * _rng.randf_range(0.85, 1.15)
			h["swing"] = 1.0
			var dmg := GameState.boss_hit(key) * float(d["atk"]) * Party.power(int(h["lv"]))
			_shoot(i, dmg, d["suit"], "harpoon" if h["c"] == "harpooner" else "orb")
	for s in _shots:
		s[2] = float(s[2]) + delta
		if float(s[2]) >= 0.3 and s.size() == 6:
			s.append(true)
			_damage(float(s[3]), s[1], Color(s[4]).lightened(0.5), 38, false, s[5] == "volley")
	_shots = _shots.filter(func(s): return float(s[2]) < 0.34)
	if _state == "fight" and _left <= 0.0:
		_end(false)


## Act II's rules over time: the shield phase, the charm, regrowing heads.
func _tick_rule(delta: float) -> void:
	match _rule:
		"shield":
			if _bshield > 0.0:
				_bshield -= delta
				if _bshield <= 0.0:
					_bshield_in = SHIELD_EVERY
			else:
				_bshield_in -= delta
				if _bshield_in <= 0.0:
					_bshield = SHIELD_SEC
					_pops.append([_center() + Vector2(0, -170.0 * _scale()), t("BOSS_SHIELD_UP"), Color("ffe07a"), 0.0, 40])
					Sfx.play("deny")
		"charm":
			_charm_in -= delta
			if _charm_in <= 0.0:
				_charm_in = CHARM_EVERY * (0.8 if _hp < _hp_max * 0.5 else 1.0)
				var free := _alive().filter(func(i): return not _heroes[i]["charm"])
				if not free.is_empty():
					var i: int = free[_rng.randi() % free.size()]
					_heroes[i]["charm"] = true
					_pops.append([_hero_pos(i) + Vector2(0, -150), t("BOSS_CHARMED"), Color("ff9ad8"), 0.0, 36])
					Sfx.play("deny")
		"heads":
			var living := _heads.filter(func(h): return float(h["hp"]) > 0.0).size()
			for i in _heads.size():
				var h: Dictionary = _heads[i]
				if float(h["regrow"]) > 0.0:
					h["regrow"] = float(h["regrow"]) - delta
					if float(h["regrow"]) <= 0.0 and living > 0:
						h["regrow"] = 0.0
						h["hp"] = float(h["max"]) * REGROW_SHARE
						_pops.append([_center() + Vector2(-120.0 + i * 120.0, -150.0) * _scale(), t("BOSS_REGROW"), Color("ff8a8a"), 0.0, 34])
						Sfx.play("deny")
			_hp = _heads_hp()
		"summon":
			if _adds.is_empty():
				_summon_in -= delta
				if _summon_in <= 0.0:
					_summon_in = SUMMON_EVERY
					for i in SUMMON_N:
						_adds.append(_hp_max * ADD_HP)
					_pops.append([_center() + Vector2(0, -170.0 * _scale()), t("BOSS_SUMMON"), Color("9aff8a"), 0.0, 40])
					Sfx.play("deny")
		"regen":
			if _break <= 0.0 and _hp > 0.0:
				_hp = minf(_hp_max, _hp + _hp_max * REGEN_RATE * delta)
				_hp_trail = maxf(_hp_trail, _hp)
		"curse":
			_curse_in -= delta
			if _curse_in <= 0.0:
				_curse_in = CURSE_EVERY * (0.8 if _hp < _hp_max * 0.5 else 1.0)
				var free := _alive().filter(func(i): return not _heroes[i]["curse"])
				if not free.is_empty():
					var i: int = free[_rng.randi() % free.size()]
					_heroes[i]["curse"] = true
					_pops.append([_hero_pos(i) + Vector2(0, -150), t("BOSS_CURSED"), Color("c8a0ff"), 0.0, 36])
					Sfx.play("deny")
			for i in _alive():
				var h: Dictionary = _heroes[i]
				if h["curse"]:
					h["hp"] = maxf(0.0, float(h["hp"]) - float(h["max"]) * CURSE_DRAIN * delta)
					if float(h["hp"]) <= 0.0:
						_knock_out(i)
		"flight":
			if _fly > 0.0:
				_fly -= delta
				if _fly <= 0.0:
					_fly_in = FLY_EVERY
					_pops.append([_center() + Vector2(0, -170.0 * _scale()), t("BOSS_LANDS"), Color("9aff8a"), 0.0, 40])
			else:
				_fly_in -= delta
				if _fly_in <= 0.0 and _wind <= 0.0:
					_fly = FLY_SEC
					_spot_left = 0.0
					_pops.append([_center() + Vector2(0, -170.0 * _scale()), t("BOSS_FLIES"), Color("c8a0ff"), 0.0, 40])
					Sfx.play("deny")
		"phases":
			var p := 1 + int(_hp < _hp_max * 2.0 / 3.0) + int(_hp < _hp_max / 3.0)
			if world:
				var gone := WorldBoss.FIGHT_SEC - _left
				p = 1 + int(gone >= WorldBoss.PHASE_SEC) + int(gone >= WorldBoss.PHASE_SEC * 2.0)
			if p > _phase:
				_phase = p
				_shake = 1.0
				_flash = 0.8
				_pops.append([_center() + Vector2(0, -190.0 * _scale()), t("BOSS_PHASE") % p, Color("ff5a7a"), 0.0, 52])
				Sfx.play("deny")


func _heads_hp() -> float:
	var sum := 0.0
	for h in _heads:
		sum += float(h["hp"])
	return sum


func _shoot(i: int, dmg: float, col: Color, kind: String) -> void:
	var to := _center() + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-70, 50)) * _scale()
	_shots.append([_hero_pos(i) + Vector2(0, -24), to, 0.0, dmg, col, kind])


func _new_spot() -> void:
	var d := MineBoss.data(_boss)
	var prev := _spot
	while _spot == prev:
		_spot = SPOTS[_rng.randi() % SPOTS.size()]
	_spot_left = float(d["spot_life"])
	_spot_wait = float(d["spot_every"]) * (0.75 if _hp < _hp_max * 0.5 else 1.0)


func _on_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap or _state != "fight":
		return
	_fight.accept_event()
	tap_at(event.position)


## A tap at `at` (screen space): parry, critical hit, hit or nothing.
func tap_at(at: Vector2) -> void:
	_taps = _taps.filter(func(x: float): return _t - x < 1.0)
	if _taps.size() >= int(MineBoss.TAP_CAP):
		return
	_taps.append(_t)
	var k := _scale()
	if _wind > 0.0 and at.distance_to(_attack_target()) <= 60.0 * k:
		_parry()
		return
	var c := _center()
	if _spot_left > 0.0 and at.distance_to(c + _spot * k) <= SPOT_R * k * 1.25:
		_spot_left = 0.0
		_hit(at, MineBoss.CRIT_MULT, true)
		return
	if at.distance_to(c) <= HIT_R * k:
		if _prophecy > 0.0:
			_hit(at, MineBoss.CRIT_MULT, true)
		else:
			_hit(at, 1.0, false)


func _hit(at: Vector2, mult: float, crit: bool) -> void:
	_combo += 1
	_combo_left = MineBoss.COMBO_GAP
	for h in _heroes:
		if not h["ko"]:
			h["charge"] = minf(1.0, float(h["charge"]) + TAP_CHARGE)
	var dmg := GameState.boss_hit(key) * MineBoss.TAP_SHARE * mult * MineBoss.combo_mult(_combo)
	_damage(dmg, at, Color("ffe066") if crit else Art.WHITE, 64 if crit else 44, crit)
	if crit:
		_pops.append([at + Vector2(0, -70), t("BOSS_CRIT"), Color("ffe066"), 0.0, 50])
		_shake = 1.0
		Sfx.play("coins")
	else:
		_shake = maxf(_shake, 0.3)
		Sfx.play("tap")


func _damage(dmg: float, at: Vector2, col: Color, px: int, big: bool, skill: bool = false) -> void:
	if _state != "fight":
		return
	if (_bshield > 0.0 or _fly > 0.0) and not skill:
		# The Automaton's shield (only skills get through), the Star-Spawn up high.
		if _rng.randf() < 0.35:
			_pops.append([at + Vector2(_rng.randf_range(-24, 24), -10), t("BOSS_IMMUNE" if _bshield > 0.0 else "BOSS_MISS"), Color("ffe07a"), 0.0, 30])
		return
	dmg *= (MineBoss.STUN_MULT if _stun > 0.0 else 1.0) * (Party.BREAK_MULT if _break > 0.0 else 1.0)
	if not _adds.is_empty() and not skill:
		# The Deep Ones shield their priest: plain hits go to them first.
		_adds[0] = float(_adds[0]) - dmg
		_pops.append([at + Vector2(_rng.randf_range(-24, 24), -10), NumFormat.short(dmg), Color("9aff8a"), 0.0, px])
		if float(_adds[0]) <= 0.0:
			_adds.remove_at(0)
			_shake = 0.8
			_pops.append([_center() + Vector2(0, -120.0 * _scale()), t("BOSS_ADD_DOWN"), Color("ffe066"), 0.0, 40])
		return
	if not _heads.is_empty():
		# The Hydra: hits go to the weakest head still up.
		var best := -1
		for i in _heads.size():
			if float(_heads[i]["hp"]) > 0.0 and (best < 0 or float(_heads[i]["hp"]) < float(_heads[best]["hp"])):
				best = i
		if best >= 0:
			var h: Dictionary = _heads[best]
			h["hp"] = maxf(0.0, float(h["hp"]) - dmg)
			if float(h["hp"]) <= 0.0:
				h["regrow"] = REGROW_SEC
				_pops.append([_center() + Vector2(-120.0 + best * 120.0, -120.0) * _scale(), t("BOSS_HEAD_CUT"), Color("ffe066"), 0.0, 44])
				_shake = 1.0
		_hp = _heads_hp()
	else:
		_hp = maxf(0.0, _hp - dmg)
	_hurt = 1.0 if big else maxf(_hurt, 0.5)
	_pops.append([at + Vector2(_rng.randf_range(-24, 24), -10), NumFormat.short(dmg), col, 0.0, px])
	for i in (10 if big else 4):
		var a := _rng.randf_range(0.0, TAU)
		_sparks.append([at, Vector2(cos(a), sin(a)) * _rng.randf_range(120.0, 260.0), 0.0, Color("ffe066") if big else Color("bff8ff")])
	if _hp <= 0.0:
		_end(true)


func _parry() -> void:
	_wind = 0.0
	_attack_in = MineBoss.ATTACK_EVERY * (COLOSSUS_SLOW if _rule == "colossus" else 1.0)
	_stun = MineBoss.STUN_SEC * (COLOSSUS_STUN if _rule == "colossus" else 1.0)
	# A parry breaks the siren's charm.
	for h in _heroes:
		if h["charm"]:
			h["charm"] = false
			_pops.append([_attack_target() + Vector2(0, 30), t("BOSS_FREED"), Color("7fffb0"), 0.0, 34])
	_shake = 1.0
	_pops.append([_attack_target() + Vector2(0, -30), t("BOSS_PARRY"), Color("7fffb0"), 0.0, 52])
	Sfx.play("milestone")


func _attack_lands() -> void:
	_attack_in = MineBoss.ATTACK_EVERY * (0.8 if _hp < _hp_max * 0.5 else 1.0) * (COLOSSUS_SLOW if _rule == "colossus" else 1.0) \
		* (PHASE_FAST if _rule == "phases" and _phase >= 3 else 1.0)
	_shake = 1.0
	_combo = 0
	if _shield:
		_shield = false
		var g := _class_index("guardian")
		_pops.append([_hero_pos(maxi(0, g)) + Vector2(0, -90), t("BOSS_BLOCK"), Color("9fd0ff"), 0.0, 34])
		Sfx.play("tap")
		return
	if _sweeps():
		# The Drowned King's wave (the Ancient One's tentacles) hits everyone standing.
		for i in _alive():
			_hurt_hero(i, SWEEP_ANGRY if _hp < _hp_max * 0.5 else SWEEP_HIT)
		return
	if _target >= _heroes.size() or _heroes[_target]["ko"]:
		return
	var share := Party.ANGRY_HIT if _hp < _hp_max * 0.5 else Party.BOSS_HIT
	if _rule == "colossus":
		share = COLOSSUS_ANGRY if _hp < _hp_max * 0.5 else COLOSSUS_HIT
	_hurt_hero(_target, share)


## The boss hits hero `i` for `share` of its full health.
func _hurt_hero(i: int, share: float) -> void:
	var h: Dictionary = _heroes[i]
	var dmg := float(h["max"]) * share
	h["hp"] = maxf(0.0, float(h["hp"]) - dmg)
	h["hurt"] = 1.0
	_pops.append([_hero_pos(i) + Vector2(0, -60), "-" + NumFormat.short(dmg), Color("ff6a7a"), 0.0, 44])
	Sfx.play("deny")
	if float(h["hp"]) <= 0.0:
		_knock_out(i)


func _knock_out(i: int) -> void:
	var h: Dictionary = _heroes[i]
	h["ko"] = true
	h["charge"] = 0.0
	h["curse"] = false
	_pops.append([_hero_pos(i) + Vector2(0, -100), t("BOSS_KO"), Color("ff6a7a"), 0.0, 30])
	if _alive().is_empty():
		_end(false)


func _class_index(c: String) -> int:
	for i in _heroes.size():
		if _heroes[i]["c"] == c:
			return i
	return -1


## A hero's card was tapped: its skill, when charged.
func use_skill(i: int) -> void:
	if _state != "fight" or i >= _heroes.size():
		return
	var h: Dictionary = _heroes[i]
	if h["ko"] or float(h["charge"]) < 1.0:
		return
	h["charge"] = 0.0
	h["swing"] = 1.0
	var power := Party.power(int(h["lv"]))
	var hit := GameState.boss_hit(key)
	_flash = 0.6
	_shake = 1.0
	_pops.append([_hero_pos(i) + Vector2(0, -150), t(Party.skill_key(h["c"])), Color("ffffff"), 0.0, 46])
	Sfx.play("milestone")
	match Party.CLASSES[h["c"]]["skill"]:
		"volley":
			for n in Party.VOLLEY_SHOTS:
				var to := _center() + Vector2(_rng.randf_range(-100, 100), _rng.randf_range(-90, 60)) * _scale()
				_shots.append([_hero_pos(i) + Vector2(_rng.randf_range(-30, 30), -24), to, -n * 0.07, hit * Party.VOLLEY_SHARE * power, Color("ffb46a"), "volley"])
		"shield":
			_shield = true
		"heal":
			for j in _heroes.size():
				var o: Dictionary = _heroes[j]
				var add := float(o["max"]) * Party.HEAL_SHARE * power
				o["ko"] = false
				o["curse"] = false
				o["hp"] = minf(float(o["max"]), float(o["hp"]) + add)
				_pops.append([_hero_pos(j) + Vector2(0, -90), "+" + NumFormat.short(add), Color("7fffb0"), 0.0, 40])
		"bomb":
			_break = Party.BREAK_SEC
			_damage(hit * Party.BOMB_SHARE * power, _center(), Color("e0a0ff"), 76, true, true)
		"prophecy":
			_prophecy = Party.PROPHECY_SEC
		"elder_sign":
			_slow = Party.ELDER_SEC


func _start() -> void:
	_state = "fight"
	_hp = _hp_max
	_hp_trail = _hp
	_left = _fight_sec()
	_combo = 0
	_stun = 0.0
	_break = 0.0
	_wind = 0.0
	_shield = false
	_bshield = 0.0
	_bshield_in = SHIELD_EVERY * 0.6
	_charm_in = CHARM_EVERY * 0.6
	_prophecy = 0.0
	_adds = []
	_summon_in = SUMMON_EVERY * 0.5
	_curse_in = CURSE_EVERY * 0.6
	_fly = 0.0
	_fly_in = FLY_EVERY * 0.6
	_phase = 1
	_slow = 0.0
	_reset_heads()
	_spot_left = 0.0
	_spot_wait = 0.8
	_attack_in = MineBoss.ATTACK_EVERY * 0.6
	_shots = []
	_level_ups = []
	_make_party()
	_show_panel()
	Sfx.play("dive")


func _end(won: bool) -> void:
	_state = "won" if won else "lost"
	_combo = 0
	_wind = 0.0
	_spot_left = 0.0
	_shots = []
	if world:
		# The league's boss can't be beaten alone: the damage is the score.
		_state = "wb"
		won = true
		_wb_units = minf(WorldBoss.CAP, (_hp_max - _hp) / _tap_unit())
		_wb_league = OnlineRules.league_id(GameState.now())
		var mine := GameState.wb_add(_wb_units, _wb_league)
		Online.wb_hit(_wb_league, mine)
	_level_ups = GameState.add_party_xp(won)
	Sfx.play("milestone" if won else "deny")
	_show_panel()


# --- Panels ---------------------------------------------------------------------------

func _show_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()
	_cards = null
	match _state:
		"fight":
			_cards = HBoxContainer.new()
			_cards.add_theme_constant_override("separation", 8)
			_cards.alignment = BoxContainer.ALIGNMENT_CENTER
			for i in _heroes.size():
				_cards.add_child(_hero_card(i))
			_panel.add_child(_cards)
			var hint := Views.label(t("BOSS_HINT"), 19, Color("dfe4ff"), true)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_panel.add_child(hint)
		"ready" when world:
			_card(t("WB_READY") % [int(WorldBoss.FIGHT_SEC), int(WorldBoss.CAP)], Color("dfe4ff"))
			_party_card()
			_button(t("BOSS_FIGHT"), &"GoldButton", _start)
		"wb":
			_card(t("WB_DONE") % [roundi(_wb_units), roundi(float(GameState.wb["dmg"]))], Color("7fffb0"))
			_xp_card(true)
			_button(t("BOSS_COLLECT"), &"GoldButton", close)
		"ready":
			_card(t("BOSS_READY") % [NumFormat.short(_hp_max), NumFormat.short(GameState.boss_hit(key) * MineBoss.TAP_SHARE), int(MineBoss.FIGHT_SEC)], Color("dfe4ff"))
			_party_card()
			_button(t("BOSS_FIGHT"), &"GoldButton", _start)
		"won":
			var got := GameState.defeat_boss(key)
			var text := t("BOSS_WON") % [int(got.get("pearls", 0)), NumFormat.short(float(got.get("coins", 0.0)))]
			_card(text, Color("7fffb0"))
			var rel: Dictionary = got.get("relic", {})
			if not rel.is_empty():
				_panel.add_child(RelicView.drop_card(rel))
			_xp_card(true)
			_button(t("BOSS_COLLECT"), &"GoldButton", close)
		"lost":
			_card(t("BOSS_LOST"), Color("ffb4a8"))
			_xp_card(false)
			_button(t("BOSS_AGAIN"), &"GoldButton", _start)


## A hero's skill card: portrait, class, level, health, the skill charging
## up from the bottom; glowing and tappable when full.
func _hero_card(i: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(minf(170.0, (get_viewport_rect().size.x - 30.0 - 8.0 * _heroes.size()) / maxf(4.0, _heroes.size())), 168)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			use_skill(i)
			c.accept_event())
	c.draw.connect(func(): _draw_card(c, i))
	return c


func _draw_card(ci: Control, i: int) -> void:
	if i >= _heroes.size():
		return
	var h: Dictionary = _heroes[i]
	var d: Dictionary = Party.CLASSES[h["c"]]
	var s := ci.size
	var r := Rect2(Vector2(2, 2), s - Vector2(4, 4))
	var ready: bool = float(h["charge"]) >= 1.0 and not h["ko"]
	if ready:
		Art.glow(ci, r.get_center(), r.size.x * 0.8, Color(1.0, 0.85, 0.3, snappedf(0.35 + 0.2 * sin(_t * 8.0), 0.05)), 16)
	Art.t_rect(ci, r, 16.0, Color("1c1450") if not h["ko"] else Color("2a2438"), 3.0, 0.0)
	# The skill filling up from the bottom.
	var ch := clampf(float(h["charge"]), 0.0, 1.0)
	if ch > 0.02:
		var fr := Rect2(r.position + Vector2(4, 4 + (r.size.y - 8) * (1.0 - ch)), Vector2(r.size.x - 8, (r.size.y - 8) * ch))
		Art.flat(ci, Art.rrect_pts(fr, 12.0), Color(d["suit"], 0.45 if not ready else 0.75))
	Art.ring(ci, Art.rrect_pts(r.grow(-1.0), 15.0), Color("ffd23f") if ready else Color(d["suit"], 0.9), 3.0)
	var form := int(GameState.evo)
	Chars.diver(ci, Vector2(s.x / 2.0, 92), 0.9, d["suit"], 1.0, 0.0, 0.0, "swim", 0.0, false, d["suit"], "sad" if h["ko"] else "happy", false, _t + i, 0,
		{"world": GameState.world_id(), "form": form})
	Art.t_rect(ci, Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 28)), 12.0, Color(d["suit"], 0.85), 0.0, 0.0)
	Art.text(ci, Vector2(s.x / 2.0, 26), t(Party.name_key(h["c"])), 20 if s.x >= 70.0 else 15, Art.WHITE, 6)
	Art.text(ci, Vector2(s.x / 2.0, s.y - 30), t("PARTY_LV") % int(h["lv"]), 19, Color("ffe066"), 5)
	var hb := Rect2(10, s.y - 22, s.x - 20, 9)
	Art.t_rect(ci, hb, 4.0, Color("2a1050"), 1.6, 0.0)
	var f := clampf(float(h["hp"]) / float(h["max"]), 0.0, 1.0)
	if f > 0.02:
		Art.flat(ci, Art.rrect_pts(Rect2(hb.position + Vector2(1.5, 1.5), Vector2((hb.size.x - 3.0) * f, hb.size.y - 3.0)), 3.0), Color("4ae08a") if f > 0.35 else Color("ff5a5a"))
	if ready:
		Art.text(ci, Vector2(s.x / 2.0, s.y * 0.62), t("SKILL_READY"), 20, Color("ffe066"), 6)


func _party_card() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in _heroes.size():
		row.add_child(_hero_card(i))
	_cards = row
	_panel.add_child(row)
	var missing := Party.ORDER.size() - _heroes.size()
	if missing > 0:
		var l := Views.label(t("PARTY_MORE") % missing, 19, Color("c9b8ff"), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(l)


func _xp_card(won: bool) -> void:
	var lines: Array[String] = [t("PARTY_XP") % (Party.XP_WIN if won else Party.XP_LOSS)]
	for u in _level_ups:
		lines.append(t("PARTY_LEVEL_UP") % [t(Party.name_key(u[0])), int(u[1]), int(u[2])])
	_card("\n".join(lines), Color("ffe066"))


func _card(text: String, color: Color) -> void:
	var card := PanelContainer.new()
	var sb := UiTheme.panel_box(Color(0.1, 0.06, 0.28, 0.92), 22, 0)
	sb.line = Color("9b6cff")
	sb.line_w = 3.0
	card.add_theme_stylebox_override("panel", sb)
	var l := Views.label(text, 21, color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)
	_panel.add_child(card)


func _button(text: String, variation: StringName, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(action)
	_panel.add_child(b)
