class_name OnlineHook
extends Node
## Shows the Online gifts' thank-you dialogs (founder, joined from an
## invite, friends joined) at a quiet moment: after the title screen, with
## no other dialog, puzzle or fishing open (the tutorial waits meanwhile).
## For a new player it is the welcome. main.gd adds one of these.

const LOOK_SEC := 0.5

var main: Node
var _left := LOOK_SEC


static func make(m: Node) -> OnlineHook:
	var h := OnlineHook.new()
	h.main = m
	h.name = "OnlineHook"
	return h


func _process(delta: float) -> void:
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
