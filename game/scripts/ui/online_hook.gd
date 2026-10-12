class_name OnlineHook
extends Node
## Shows the Online gifts' thank-you dialogs (founder, joined from an
## invite, friends joined) at a quiet moment: after the title screen, with
## no other dialog, puzzle or fishing open (the tutorial waits meanwhile).
## For a new player it is the welcome. main.gd adds one of these.

const LOOK_SEC := 0.5
## Achievements are checked this often; new badges show as a toast.
const ACH_SEC := 5.0

var main: Node
var _left := LOOK_SEC
var _ach_left := ACH_SEC
var _new_badges: Array[String] = []


static func make(m: Node) -> OnlineHook:
	var h := OnlineHook.new()
	h.main = m
	h.name = "OnlineHook"
	return h


func _process(delta: float) -> void:
	_ach_left -= delta
	if _ach_left <= 0.0:
		_ach_left = ACH_SEC
		_check_badges()
	_left -= delta
	if _left > 0.0:
		return
	_left = LOOK_SEC
	if Online.pending_thanks.is_empty() or not is_instance_valid(main):
		return
	if not main._started or main._blocked() or main.is_busy():
		return
	var info := Online.take_thanks()
	if info.is_empty():
		return
	Sfx.play("milestone")
	main._top.open(func(m): OnlineView.thanks(m, main, info))


func _check_badges() -> void:
	if not is_instance_valid(main) or not main._started:
		return
	_new_badges.append_array(Achievements.check())
	if _new_badges.is_empty() or main._blocked() or main.is_busy() or main._modal.visible or main._top.visible:
		return
	# One toast: the first new badge, "+N" more when several came at once
	# (an old save unlocks many on the first run).
	var first := _new_badges[0]
	var pearls := 0
	for id in _new_badges:
		pearls += int(Achievements.info(id)[4])
	var text := tr("ACH_NEW") % tr("ACH_" + first.to_upper())
	if _new_badges.size() > 1:
		text += "  +%d" % (_new_badges.size() - 1)
	_new_badges.clear()
	var view: Vector2 = main.get_viewport_rect().size
	var at := Vector2(view.x / 2.0, view.y * 0.3)
	Sfx.play("milestone")
	main._fx.burst(at, 30)
	main._fx.float_text(at, text, Art.GOLD, 34)
	if pearls > 0:
		main._fx.float_text(at + Vector2(0, 48), "+%d" % pearls, Color("f1e6ff"), 32)
		main._fx.fly("pearl", at, main._hud.pearl_target(), mini(pearls, 8))
