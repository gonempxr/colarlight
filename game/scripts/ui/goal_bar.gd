class_name GoalBar
extends PanelContainer
## A new player's first-session goals, one at a time, in a strip under the
## room tabs (where the saga's strip sits in league games): what to do,
## how far along, and a Take button with pearls when it is done. Shown
## after the tutorial's first upgrade until the last goal is taken
## (Progress.first_goal counts the goals taken).

signal claimed(pearls: int, from: Vector2)

const H := 52.0
## [kind, target, pearls]
const GOALS := [
	["managers", 3, 5],
	["depths", 3, 10],
	["level", 10, 10],
	["depths", 5, 15],
	["earn", 10000, 20],
]
## The tutorial step after which the goals show (its first upgrade).
const AFTER_STEP := 5

var _text: Label
var _bar: ProgressBar
var _take: Button
var _count: Label
var _sig := []


static func t(k: String) -> String:
	return TranslationServer.translate(k)


## True while there is a goal to show.
static func wanted() -> bool:
	return not Balance.saga and Progress.first_goal < GOALS.size() and Progress.tutorial_step >= AFTER_STEP


## [done so far, target] of goal i.
static func progress_of(i: int) -> Array:
	var g: Array = GOALS[i]
	var have := 0.0
	match str(g[0]):
		"managers":
			for k in ["lift", "boat", "plant"]:
				if GameState.has_manager(k):
					have += 1.0
		"depths":
			for d in range(10):
				if GameState.is_open("d%d" % d):
					have += 1.0
		"level":
			have = float(GameState.get_level("d0"))
		"earn":
			have = GameState.total_earned
	return [minf(have, float(g[1])), float(g[1])]


static func text_of(i: int) -> String:
	var g: Array = GOALS[i]
	match str(g[0]):
		"managers":
			return t("GOAL_MANAGERS")
		"depths":
			return t("GOAL_DEPTHS") % int(g[1])
		"level":
			return t("GOAL_LEVEL") % int(g[1])
	return t("GOAL_EARN") % NumFormat.short(float(g[1]))


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	custom_minimum_size = Vector2(0, H)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_text = Label.new()
	_text.theme_type_variation = &"InkLabel"
	_text.add_theme_font_size_override("font_size", 22)
	_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text.clip_text = true
	col.add_child(_text)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	col.add_child(_bar)
	_count = Label.new()
	_count.theme_type_variation = &"InkLabel"
	_count.add_theme_font_size_override("font_size", 22)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	_take = Button.new()
	_take.theme_type_variation = &"GoldButton"
	_take.add_theme_font_size_override("font_size", 20)
	_take.custom_minimum_size = Vector2(120, 0)
	_take.pressed.connect(_on_take)
	row.add_child(_take)
	_refresh(true)


func _process(_delta: float) -> void:
	if visible:
		_refresh(false)


func _refresh(force: bool) -> void:
	var i: int = Progress.first_goal
	if i >= GOALS.size():
		return
	var p := progress_of(i)
	var done: bool = p[0] >= p[1]
	var sig := [i, int(p[0]), done, TranslationServer.get_locale()]
	if sig == _sig and not force:
		return
	_sig = sig
	_text.text = "%s: %s" % [t("GOAL_TITLE"), text_of(i)]
	_bar.max_value = p[1]
	_bar.value = p[0]
	_bar.visible = not done
	_take.visible = done
	_count.visible = not done
	_count.text = "%s/%s" % [NumFormat.short(p[0]), NumFormat.short(p[1])]
	_take.text = "%s +%d" % [t("GOAL_CLAIM"), int(GOALS[i][2])]


func _on_take() -> void:
	var i: int = Progress.first_goal
	if i >= GOALS.size():
		return
	var p := progress_of(i)
	if p[0] < p[1]:
		return
	var pearls := int(GOALS[i][2])
	Progress.add_pearls(pearls)
	Progress.first_goal = i + 1
	Progress.changed.emit()
	Sfx.play("chest")
	claimed.emit(pearls, _take.get_global_rect().get_center())
	_refresh(true)
