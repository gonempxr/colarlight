class_name WorldBoss
extends RefCounted
## The saga's world boss (act III): one Ancient One for the whole Top
## League. Every player who has reached R'lyeh fights it for FIGHT_SEC at a
## time; the damage counts in "taps" (damage / the player's own tap, so
## weak and strong players weigh the same), at most CAP a fight. Firestore
## worldboss/{league}/hits/{uid} {name, dmg} (rules v9). When the league's
## total reaches HP, everyone who took part claims PEARLS and a relic.

const FIGHT_SEC := 30.0
const CAP := 900.0
const HP := 250000.0
const PEARLS := 300
## The fight's health bar: this many of the player's taps (never emptied).
const BAR_TAPS := 4000.0
## Seconds per phase of the Ancient One in a world fight.
const PHASE_SEC := 10.0
## The site whose strength the fight uses (the Ancient One's own).
const KEY := "d14"


## A board answer ({"rows": [{uid, name, dmg}]}) -> {"ok", "rows", "total"}.
static func parse_board(res: String) -> Dictionary:
	var d = JSON.parse_string(res) if res.begins_with("{") else null
	if not (d is Dictionary and d.get("rows") is Array):
		return {"ok": false, "rows": [], "total": 0.0}
	var rows := []
	var total := 0.0
	for x in d["rows"]:
		if not x is Dictionary:
			continue
		var v = x.get("dmg", 0)
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) <= 0.0:
			continue
		var dmg := minf(float(v), 1e7)
		total += dmg
		rows.append({"uid": str(x.get("uid", "")), "name": OnlineRules.strip_name(str(x.get("name", ""))), "dmg": dmg})
	rows.sort_custom(func(a, b): return a["dmg"] > b["dmg"])
	return {"ok": true, "rows": rows, "total": total}


## The league's progress 0..1.
static func progress(total: float) -> float:
	return clampf(total / HP, 0.0, 1.0)
