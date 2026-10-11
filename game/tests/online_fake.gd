extends RefCounted
## A pretend online backend for tests and screenshots (Online.use_backend):
## the same answers and checks as the Firestore rules / the shell's
## ?online=test backend, kept in memory.

var uid := "Me000001abcdefghijklmnopqrst"
var all := {}
var weeks := {}
var founders := 0
var founder_of := {}
var invites := {}
var joins := {}
## Answer every request with this instead ("" = work normally).
var fail := ""
var calls: Array[String] = []


## A board with `n` made-up test rows.
func seed(n: int, names: Array = []) -> void:
	for i in n:
		var id := "Test%04dxxxxxxxxxxxxxxxxxxxx" % (i + 1)
		var name: String = names[i % names.size()] if not names.is_empty() else "Test diver %d" % (i + 1)
		var look := Chars.default_avatar()
		look["skin"] = i % 4
		look["hair_color"] = (i * 3) % 6
		look["hat"] = ["none", "cap", "beanie", "captain", "sailor", "pirate", "founder"][i % 7]
		all[id] = {"name": name, "score": pow(10.0, 3.0 + i * 0.6) * (1.0 + (i % 3) * 0.3), "a": JSON.stringify(look)}


func request(method: String, arg: String) -> String:
	calls.append(method)
	if fail != "":
		return fail
	match method:
		"submit":
			var a: Dictionary = JSON.parse_string(arg)
			var wk: Dictionary = weeks.get(int(a["w"]), {})
			weeks[int(a["w"])] = wk
			var ok := _put(all, a["name"], float(a["all"]), str(a.get("a", "")))
			ok = _put(wk, a["name"], float(a["week"]), str(a.get("a", ""))) or ok
			return "ok" if ok else "error:permission-denied"
		"board":
			var a: Dictionary = JSON.parse_string(arg)
			var table: Dictionary = weeks.get(int(a["w"]), {}) if a["kind"] == "week" else all
			var rows := []
			for id in table:
				rows.append({"uid": id, "name": table[id]["name"], "score": table[id]["score"], "a": table[id]["a"]})
			rows.sort_custom(func(x, y): return x["score"] > y["score"])
			var at := -1
			var above := 0
			for i in rows.size():
				if rows[i]["uid"] == uid:
					at = i
				if float(rows[i]["score"]) > float(a["score"]):
					above += 1
			var rank := at + 1 if at >= 0 else (above + 1 if float(a["score"]) > 0.0 else 0)
			return JSON.stringify({"rows": rows.slice(0, 50), "rank": rank})
		"founder":
			if founder_of.has(uid):
				return "already:%d" % founder_of[uid]
			if founders >= 100:
				return "full"
			founders += 1
			founder_of[uid] = founders
			return "n:%d" % founders
		"join":
			if joins.has(uid) or uid.begins_with(arg):
				return "ok" if joins.get(uid, "") == arg else "denied"
			joins[uid] = arg
			if not invites.has(arg):
				invites[arg] = {}
			invites[arg][uid] = true
			return "ok"
		"joins":
			return "n:%d" % invites.get(arg, {}).size()
		"link":
			return "https://gonempxr.github.io/colarlight/?ref=" + arg
		"share":
			return "copied"
	return "error:unknown"


func _put(table: Dictionary, name: String, score: float, a: String) -> bool:
	var old: Dictionary = table.get(uid, {})
	if not old.is_empty() and score < float(old["score"]):
		return false
	table[uid] = {"name": name, "score": score, "a": a}
	return true
