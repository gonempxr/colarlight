class_name OnlineRules
extends RefCounted
## The rules of the online features, kept apart from the network code so
## tests can check them: promo codes, leaderboard names, week numbers and who
## may use an invite. The Online autoload applies them.

## Promo codes: SHA-256 of the normalised code (trimmed, upper case) -> what
## it gives. The plain codes are only in docs/online.md (how to add one is
## there too). "boost" is seconds of x2 coins, "item" a wardrobe item,
## "coins" plain coins (not counted on the leaderboards).
const PROMOS := {
	"93b4090a74ac713f7867338ec6fa135499d4053cfdb81dc592c4c5c9ea892856": {"id": "p1", "pearls": 50},
	"ec9ee22a6733eed7d86e663d3ed14853f2725f4abac515d9cb9d189cbbb100c9": {"id": "p2", "pearls": 30, "boost": 3600},
	"bed9b2c24e8646faf3e9e3a63013e84c2fad11b0df049d7dd4c861be0140c1d2": {"id": "p3", "pearls": 25, "item": "hat_founder"},
	# Mark's coin codes (the plain codes are not kept in the repo). Gifted
	# coins never count on the leaderboards (Online.track).
	"edb19a27d5cd5bb89788e932dc220125015d8f1b3c6cea95bbb27883b5cbeabf": {"id": "p4", "coins": 2.0e23},
	"d61cba720e6f4d81fd201aa76ccc38a9325a2d9ddb0e342a34297a2803f55c42": {"id": "p5", "coins": 1.0e23},
}

## The exclusive item: never sold, only given (founders, a promo code,
## inviting a friend).
const EXCLUSIVE_ITEM := "hat_founder"
const FOUNDER_MAX := 100
const FOUNDER_PEARLS := 100
## A new player who came from an invite, and the inviter per friend.
const JOIN_PEARLS := 30
const INVITE_PEARLS := 30
const INVITE_CAP := 20
## A save that earned more than this is not "new" any more (no invite bonus).
const FRESH_COINS := 20000.0
const NAME_MIN := 2
const NAME_MAX := 16
const CODE_LEN := 8

## Block list (EN / RU / ES): a name containing one becomes "Diver####".
## Checked on the name in lower case with look-alike letters and digits
## mapped back (0 -> o, 1 -> i, 3 -> e, ...) and spaces/dots removed.
## Slurs, swearing, sex, hate and notorious criminals.
const BLOCKED: Array[String] = [
	"fuck", "fuk", "fck", "shit", "bitch", "cunt", "pussy", "nigg", "niga", "nigr", "negro", "fagg", "faggot", "whore", "slut",
	"nazi", "hitler", "heil", "fuhrer", "kkk", "isis", "jihad", "terroris", "epstein", "diddy", "pedo", "paedo",
	"molest", "rapist", "porn", "hentai", "onlyfans", "nude", "boob", "tits", "penis", "vagina", "dildo", "wank", "jerkoff",
	"blowjob", "handjob", "orgasm", "horny", "asshole", "bastard", "retard", "chink", "kike", "tranny", "dyke",
	"suicide", "killyourself", "kys", "gay", "lesbo",
	"хуй", "хуе", "хуё", "пизд", "бляд", "блят", "ебат", "ебан", "ебал", "ёба", "сука", "суки", "мудак", "мудил",
	"пидор", "пидар", "пидр", "педик", "педоф", "гандон", "шлюх", "залуп", "долбо", "дроч", "жопа", "говн",
	"нигер", "нигга", "негр", "гитлер", "нацист", "зиг хайл", "зига", "эпштейн", "чурк", "секс",
	"порно", "сиськ", "член", "трах", "насил", "суицид", "убейся", "гомик",
	"puta", "puto", "mierda", "coño", "cabron", "cabrón", "pendej", "joder", "polla", "verga", "chinga",
	"culero", "maricon", "maricón", "gilipoll", "follar", "zorra", "mamon", "pinche", "negrata", "violador",
]
## Short words blocked only as a whole word (or the start of one), so that
## "gamer" or "canal" stay fine: "ass", "cum", "sex", "гей" (not "геймер").
const BLOCKED_WORDS: Array[String] = ["ass", "cum", "sex", "anal", "dick", "cock", "fag", "rape", "hoe", "gey", "spic", "гей", "хер", "хач", "жид", "даун", "сосу", "соси", "puto"]
const WORD_OK: Array[String] = ["assist", "assassin", "assault", "asset", "cumulus", "cumbia", "analog", "analy", "dickens", "cockatoo", "cockpit",
	"hoek", "rapeseed", "spice", "spicy", "гейм", "херсон", "хачап", "жидк", "сосиск"]
const LOOKALIKE := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i"}
## Latin letters that look like Cyrillic ones, so "сyка" or "xуй" (mixed
## alphabets) are caught as well.
const LATIN_AS_CYR := {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х", "y": "у", "k": "к", "m": "м", "t": "т", "b": "в", "h": "н", "6": "б"}


# --- Promo codes -------------------------------------------------------------------

static func normalize_code(text: String) -> String:
	return text.strip_edges().to_upper()


static func hash_code(text: String) -> String:
	return normalize_code(text).sha256_text()


## What a typed code gives ({} = no such code).
static func promo(text: String) -> Dictionary:
	if normalize_code(text) == "":
		return {}
	return PROMOS.get(hash_code(text), {})


# --- Names -------------------------------------------------------------------------

## Control characters and odd spacing out; "" when too short.
static func strip_name(value: String) -> String:
	var out := ""
	for ch in value:
		var c := ch.unicode_at(0)
		# Control characters, zero-width and direction marks.
		if ch in ["/", "\\", "#", "[", "]", "*", "`", "~"]:
			continue
		if c < 32 or c == 127 or (c >= 0x80 and c < 0xA0) or (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E) \
				or (c >= 0x2060 and c <= 0x206F) or c == 0xFEFF:
			continue
		out += ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges().left(NAME_MAX).strip_edges()
	return out if out.length() >= NAME_MIN else ""


static func is_rude(name: String) -> bool:
	var low := name.to_lower()
	var flat := ""
	for ch in low:
		if ch in [" ", ".", "_", "-", "*", "'"]:
			continue
		flat += LOOKALIKE.get(ch, ch)
	var cyr := ""
	for ch in flat:
		cyr += LATIN_AS_CYR.get(ch, ch)
	for w in BLOCKED:
		if flat.contains(w) or cyr.contains(w) or low.contains(w):
			return true
	for word in _words(name):
		var wl := ""
		for ch in word.to_lower():
			wl += LOOKALIKE.get(ch, ch)
		var wc := ""
		for ch in wl:
			wc += LATIN_AS_CYR.get(ch, ch)
		for w in BLOCKED_WORDS:
			if (wl.begins_with(w) or wc.begins_with(w)) and not _word_ok(wl) and not _word_ok(wc):
				return true
	return false


static func _word_ok(word: String) -> bool:
	for ok in WORD_OK:
		if word.begins_with(ok):
			return true
	return false


## The words of a name: split at spaces, digits, signs and camelCase
## ("BigAssDiver" -> big, ass, diver).
static func _words(name: String) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	var prev_lower := false
	for ch in name:
		var letter := ch.to_lower() != ch.to_upper()
		if not letter:
			if cur != "":
				out.append(cur)
			cur = ""
			prev_lower = false
			continue
		var upper := ch == ch.to_upper()
		if upper and prev_lower and cur != "":
			out.append(cur)
			cur = ""
		cur += ch
		prev_lower = not upper
	if cur != "":
		out.append(cur)
	return out


## The unique key of a name: lower case without spaces ("Lev", "l e v" and
## "LEV" are the same name). The Firestore rules compute the same thing.
static func name_key(name: String) -> String:
	return name.to_lower().replace(" ", "")


static func is_fallback(name: String) -> bool:
	if name.length() != 9 or not name.begins_with("Diver"):
		return false
	return name.substr(5).is_valid_int()


## "Diver" and 4 digits made from the player's id (the same every time).
static func fallback_name(uid: String) -> String:
	return "Diver%04d" % (absi(uid.hash()) % 10000)


## The name shown on the leaderboard: the typed name when it is fine,
## otherwise "Diver####".
static func board_name(typed: String, uid: String) -> String:
	var n := strip_name(typed)
	if n == "" or is_rude(n):
		return fallback_name(uid)
	return n


# --- Weeks ---------------------------------------------------------------------------

## Weeks start on Monday 00:00 UTC. 1970-01-01 was a Thursday, so Monday
## 1970-01-05 (day 4) starts week 0.
static func week_id(unix: float) -> int:
	var day := floori(unix / 86400.0)
	return floori((day - 4) / 7.0)


static func week_start(id: int) -> float:
	return float(id * 7 + 4) * 86400.0


## Monday = 0 ... Sunday = 6 (UTC).
static func weekday(unix: float) -> int:
	return posmod(floori(unix / 86400.0) + 3, 7)


## Every Saturday (UTC) everyone earns x2 coins, for free.
const X2_WEEKDAY := 5


static func is_x2_day(unix: float) -> bool:
	return weekday(unix) == X2_WEEKDAY


# --- Weekly race -----------------------------------------------------------------------

## Prizes for last week's place on the players' board (coins earned that
## week): pearls and hours of x2 coins. Everyone who took part gets a little.
const WEEK_PRIZES := [
	[1, 500, 4], [3, 300, 3], [10, 150, 2], [50, 75, 1], [100, 40, 0],
]
const WEEK_PARTICIPATION := 20


static func week_prize(rank: int, score: float) -> Dictionary:
	if score <= 0.0:
		return {}
	if rank <= 0:
		return {"pearls": WEEK_PARTICIPATION, "boost": 0}
	for p in WEEK_PRIZES:
		if rank <= int(p[0]):
			return {"pearls": int(p[1]), "boost": int(p[2]) * 3600}
	return {"pearls": WEEK_PARTICIPATION, "boost": 0}


# --- Invites ---------------------------------------------------------------------------

## The player's invite code: the first letters of their online id.
# --- Seasons (one calendar month, UTC) ---------------------------------------------

## The season id: year * 100 + month (UTC), e.g. 202610.
static func month_id(unix: float) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(floor(unix)))
	return int(d["year"]) * 100 + int(d["month"])


## The season before `id` (202601 -> 202512).
static func prev_month(id: int) -> int:
	var y := id / 100
	var m := id % 100
	return (y - 1) * 100 + 12 if m <= 1 else y * 100 + m - 1


## [best place, pearls]; places beyond the last pay SEASON_PARTICIPATION.
const SEASON_PRIZES := [[1, 1000], [3, 600], [10, 300], [50, 150], [100, 80]]
const SEASON_PARTICIPATION := 30


static func season_prize(rank: int, score: float) -> int:
	if score <= 0.0:
		return 0
	if rank > 0:
		for p in SEASON_PRIZES:
			if rank <= int(p[0]):
				return int(p[1])
	return SEASON_PARTICIPATION


# --- Puzzle race (stars won in the puzzle in a week) ---------------------------------

## [best place, pearls]; everyone who won a puzzle that week gets the last.
const PUZZLE_PRIZES := [[1, 150], [3, 100], [10, 50]]
const PUZZLE_PARTICIPATION := 10


static func puzzle_prize(rank: int, score: float) -> int:
	if score <= 0.0:
		return 0
	if rank > 0:
		for p in PUZZLE_PRIZES:
			if rank <= int(p[0]):
				return int(p[1])
	return PUZZLE_PARTICIPATION


# --- Titles (the week after a good weekly place) ------------------------------------

## 3 = king (1st), 2 = master (2nd-3rd), 1 = star (4th-10th), 0 = none.
static func title_for(rank: int) -> int:
	if rank == 1:
		return 3
	if rank >= 2 and rank <= 3:
		return 2
	if rank >= 4 and rank <= 10:
		return 1
	return 0


const TITLE_KEYS := ["", "TITLE_STAR", "TITLE_MASTER", "TITLE_KING"]
const TITLE_COLORS: Array[Color] = [Color.WHITE, Color("8fd3ff"), Color("c9d3e0"), Color("ffcc33")]


# --- Clubs -----------------------------------------------------------------------------

const CLUB_MAX := 30


## A club name: 3-16 characters after the filter, not rude.
static func club_name(text: String) -> String:
	var n := strip_name(text).left(20).strip_edges()
	if n.length() < 3 or is_rude(n):
		return ""
	return n


static func club_id_ok(id: String) -> bool:
	return id.length() == 8 and RegEx.create_from_string("^[A-Za-z0-9]{8}$").search(id) != null


static func code_of(uid: String) -> String:
	return uid.left(CODE_LEN) if uid.length() >= CODE_LEN else ""


static func valid_code(code: String) -> bool:
	if code.length() < 6 or code.length() > 12:
		return false
	for ch in code:
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
			return false
	return true


## May this start from an invite give the joining bonus? Only a new save,
## never referred before, and not the player's own link.
static func invite_ok(ref: String, own_code: String, referred_by: String, total_earned: float) -> bool:
	if not valid_code(ref) or referred_by != "":
		return false
	if own_code != "" and ref == own_code:
		return false
	return total_earned < FRESH_COINS


## Pearls still due to an inviter: friends joined (capped) minus those already paid.
static func invite_due(joined: int, credited: int) -> int:
	return maxi(0, mini(joined, INVITE_CAP) - credited)
