extends RefCounted
## A pretend online backend for tests and screenshots (Online.use_backend):
## the same answers and checks as the Firestore rules / the shell's
## ?online=test backend, kept in memory.

var uid := "Me000001abcdefghijklmnopqrst"
var all := {}
var weeks := {}
var months := {}
## Week -> the puzzle board (stars won that week).
var puzzle_weeks := {}
## League id -> board; the crown {uid, name, k, id}; day -> {uid: {name, score (minutes)}}.
var leagues := {}
var crown := {}
var crown_days := {}
## Club id -> {name, owner, m: {uid: {name, score, w}}}; week -> {club id: {name, s, n}}.
var clubs := {}
var club_weeks := {}
var founders := 0
var founder_of := {}
var invites := {}
var joins := {}
## Name key -> owner uid.
var names := {}
## Answer every request with this instead ("" = work normally).
var fail := ""
var calls: Array[String] = []
## The leader's tools: is this player the leader, and the banned ids.
var is_admin := false
var banned := {}
## donors/{id} {name, total}: [{name, total}, ...]
var donors: Array = []


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
		"admin":
			return "yes" if is_admin else "no"
		"donors":
			return JSON.stringify({"list": donors})
		"bans":
			var list := []
			for k in banned:
				list.append({"uid": k, "name": banned[k]["name"], "o": banned[k]["o"]})
			return JSON.stringify({"list": list})
		"kick":
			if not is_admin:
				return "error:permission-denied"
			var a: Dictionary = JSON.parse_string(arg)
			for id in a["uids"]:
				for t in [all, weeks.get(int(a["w"]), {}), months.get(int(a["m"]), {}), puzzle_weeks.get(int(a["w"]), {}), leagues.get(int(a.get("l", 0)), {})]:
					t.erase(str(id))
				if str(crown.get("uid", "")) == str(id):
					crown = {}
				if a.get("ban", false):
					banned[str(id)] = {"name": str(a["name"]), "o": str(a.get("o", ""))}
			return "ok"
		"unban":
			if not is_admin:
				return "error:permission-denied"
			banned.erase(str(JSON.parse_string(arg)["uid"]))
			return "ok"
		"submit" when banned.has(uid):
			return "error:permission-denied"
		"submit":
			var a: Dictionary = JSON.parse_string(arg)
			var wk: Dictionary = weeks.get(int(a["w"]), {})
			weeks[int(a["w"])] = wk
			var p := str(a.get("p", ""))
			var ok := _put(all, a["name"], float(a["all"]), str(a.get("a", "")), p)
			ok = _put(wk, a["name"], float(a["week"]), str(a.get("a", "")), p) or ok
			if a.has("m"):
				var mo: Dictionary = months.get(int(a["m"]), {})
				months[int(a["m"])] = mo
				ok = _put(mo, a["name"], float(a.get("month", 0.0)), str(a.get("a", "")), p) or ok
			if float(a.get("pz", 0.0)) > 0.0:
				var pzw: Dictionary = puzzle_weeks.get(int(a["w"]), {})
				puzzle_weeks[int(a["w"])] = pzw
				ok = _put(pzw, a["name"], float(a["pz"]), str(a.get("a", "")), p) or ok
			if int(a.get("l", 0)) > 0 and float(a.get("league", 0.0)) > 0.0:
				var lg: Dictionary = leagues.get(int(a["l"]), {})
				leagues[int(a["l"])] = lg
				ok = _put(lg, a["name"], float(a["league"]), str(a.get("a", "")), p) or ok
			var club := str(a.get("club", ""))
			if club != "" and clubs.has(club) and clubs[club]["m"].has(uid):
				clubs[club]["m"][uid] = {"name": a["name"], "score": float(a["week"]), "w": int(a["w"])}
			return "ok" if ok else "error:permission-denied"
		"board":
			var a: Dictionary = JSON.parse_string(arg)
			var table: Dictionary = all
			match str(a["kind"]):
				"week":
					table = weeks.get(int(a["w"]), {})
				"month":
					table = months.get(int(a.get("m", 0)), {})
				"puzzle":
					table = puzzle_weeks.get(int(a["w"]), {})
				"league":
					table = leagues.get(int(a.get("l", 0)), {})
				"friends":
					table = {}
					for id in all:
						var code := str(a.get("code", ""))
						if id == uid or (str(a.get("ref", "")) != "" and id.begins_with(str(a["ref"]))) \
								or (code != "" and invites.get(code, {}).has(id)):
							table[id] = all[id]
				"clubs":
					table = {}
					var cw: Dictionary = club_weeks.get(int(a["w"]), {})
					for id in cw:
						table[id] = {"name": cw[id]["name"], "score": cw[id]["s"], "a": "", "n": cw[id]["n"]}
			var rows := []
			for id in table:
				rows.append({"uid": id, "name": table[id]["name"], "score": table[id]["score"], "a": table[id]["a"],
					"p": table[id].get("p", ""), "n": table[id].get("n", 0)})
			rows.sort_custom(func(x, y): return x["score"] > y["score"])
			var at := -1
			var above := 0
			for i in rows.size():
				if rows[i]["uid"] == uid:
					at = i
				if float(rows[i]["score"]) > float(a["score"]):
					above += 1
			var rank := at + 1 if at >= 0 else (above + 1 if float(a["score"]) > 0.0 else 0)
			return JSON.stringify({"rows": rows.slice(0, 120), "rank": rank})
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
		"claim":
			var a: Dictionary = JSON.parse_string(arg)
			var key := str(a["key"])
			if names.has(key) and names[key] != uid:
				return "taken"
			names[key] = uid
			var old := str(a.get("old", ""))
			if old != "" and old != key and names.get(old, "") == uid:
				names.erase(old)
			return "ok"
		"crown":
			if crown.is_empty():
				return "none"
			var t: Dictionary = _crown_board(str(crown["k"]), str(crown["id"]))
			return JSON.stringify({"uid": crown["uid"], "name": crown["name"], "k": crown["k"], "id": crown["id"],
				"score": float(t.get(crown["uid"], {}).get("score", 0.0))})
		"crown_take":
			var a: Dictionary = JSON.parse_string(arg)
			var t: Dictionary = _crown_board(str(a["k"]), str(a["id"]))
			var mine := float(t.get(uid, {}).get("score", 0.0))
			if banned.has(uid) or mine <= 0.0:
				return "lower"
			if not crown.is_empty() and crown["k"] == a["k"] and crown["id"] == str(a["id"]) and crown["uid"] != uid \
					and t.has(crown["uid"]) and mine <= float(t[crown["uid"]]["score"]):
				return "lower"
			crown = {"uid": uid, "name": str(a["name"]), "k": str(a["k"]), "id": str(a["id"])}
			return "ok"
		"crown_tick":
			var a: Dictionary = JSON.parse_string(arg)
			if crown.get("uid", "") != uid:
				return "error:permission-denied"
			var day: Dictionary = crown_days.get(int(a["day"]), {})
			crown_days[int(a["day"])] = day
			var n := int(day.get(uid, {}).get("score", 0)) + 1
			day[uid] = {"name": str(a["name"]), "score": n}
			return "ok:%d" % n
		"kings":
			var a: Dictionary = JSON.parse_string(arg)
			return JSON.stringify({"today": _kings(int(a["day"])), "yesterday": _kings(int(a["day"]) - 1)})
		"rank" when str(JSON.parse_string(arg).get("kind", "")) == "crown":
			var day: Dictionary = crown_days.get(int(JSON.parse_string(arg)["id"]), {})
			if not day.has(uid):
				return "none"
			var mine := int(day[uid]["score"])
			var above := 0
			for id in day:
				if int(day[id]["score"]) > mine:
					above += 1
			return "r:%d:%d" % [above + 1, mine]
		"rank":
			var a: Dictionary = JSON.parse_string(arg)
			var wk: Dictionary = weeks.get(int(a.get("w", a.get("id", 0))), {})
			if str(a.get("kind", "week")) == "month":
				wk = months.get(int(a["id"]), {})
			elif str(a.get("kind", "week")) == "puzzle":
				wk = puzzle_weeks.get(int(a["w"]), {})
			if not wk.has(uid) or float(wk[uid]["score"]) <= 0.0:
				return "none"
			var mine := float(wk[uid]["score"])
			var above := 0
			for id in wk:
				if float(wk[id]["score"]) > mine:
					above += 1
			return "r:%d:%s" % [above + 1, str(mine)]
		"club_create":
			var a: Dictionary = JSON.parse_string(arg)
			clubs[str(a["id"])] = {"name": str(a["club"]), "owner": uid, "m": {uid: {"name": a["name"], "score": float(a["s"]), "w": int(a["w"])}}}
			_club_total(str(a["id"]), int(a["w"]))
			return "ok"
		"club_join":
			var a: Dictionary = JSON.parse_string(arg)
			var id := str(a["id"])
			if not clubs.has(id) or clubs[id]["m"].is_empty():
				return "gone"
			if not clubs[id]["m"].has(uid):
				if clubs[id]["m"].size() >= OnlineRules.CLUB_MAX:
					return "full"
				clubs[id]["m"][uid] = {"name": a["name"], "score": float(a["s"]), "w": int(a["w"])}
			_club_total(id, int(a["w"]))
			return "ok:" + str(clubs[id]["name"])
		"club_leave":
			var a: Dictionary = JSON.parse_string(arg)
			var id := str(a["id"])
			if not clubs.has(id) or not clubs[id]["m"].has(uid):
				return "gone"
			clubs[id]["m"].erase(uid)
			return "ok"
		"club":
			var a: Dictionary = JSON.parse_string(arg)
			var id := str(a["id"])
			if not clubs.has(id) or clubs[id]["m"].is_empty():
				return "gone"
			var c: Dictionary = clubs[id]
			if c["m"].has(uid):
				c["m"][uid] = {"name": a["name"], "score": float(a["s"]), "w": int(a["w"])}
				_club_total(id, int(a["w"]))
			var members := []
			for m in c["m"]:
				var r: Dictionary = c["m"][m]
				members.append({"uid": m, "name": r["name"], "score": float(r["score"]) if int(r["w"]) == int(a["w"]) else 0.0})
			return JSON.stringify({"id": id, "name": c["name"], "owner": c["owner"], "members": members})
		"link":
			return "https://gonempxr.github.io/colarlight/?ref=" + arg
		"share":
			return "copied"
	return "error:unknown"


func _put(table: Dictionary, name: String, score: float, a: String, p := "") -> bool:
	var old: Dictionary = table.get(uid, {})
	if not old.is_empty() and score < float(old["score"]):
		return false
	table[uid] = {"name": name, "score": score, "a": a, "p": p}
	return true


func _crown_board(k: String, id: String) -> Dictionary:
	return leagues.get(int(id), {}) if k == "league" else weeks.get(int(id), {})


func _kings(day: int) -> Array:
	var rows := []
	var t: Dictionary = crown_days.get(day, {})
	for id in t:
		rows.append({"uid": id, "name": t[id]["name"], "score": t[id]["score"]})
	rows.sort_custom(func(x, y): return int(x["score"]) > int(y["score"]))
	return rows.slice(0, 5)


func _club_total(id: String, w: int) -> void:
	var sum := 0.0
	for m in clubs[id]["m"]:
		var r: Dictionary = clubs[id]["m"][m]
		if int(r["w"]) == w:
			sum += float(r["score"])
	var cw: Dictionary = club_weeks.get(w, {})
	club_weeks[w] = cw
	cw[id] = {"name": clubs[id]["name"], "s": sum, "n": clubs[id]["m"].size()}


## A few made-up clubs for screenshots.
func seed_clubs(w: int) -> void:
	var names := ["Deep Divers", "Coral Crew", "Lava Lords", "Moon Miners", "Acid Ducks"]
	for i in names.size():
		var id := "Club%04d" % (i + 1)
		var m := {}
		for j in 3 + i * 4:
			m["Mem%d_%d" % [i, j]] = {"name": "Diver %d" % (i * 10 + j), "score": pow(10.0, 4.0 + i * 0.7) * (1.0 + j * 0.2), "w": w}
		clubs[id] = {"name": names[i], "owner": "Mem%d_0" % i, "m": m}
		_club_total(id, w)
