class_name OnlineRules
extends RefCounted
## The rules of the online features, kept apart from the network code so
## tests can check them: promo codes, leaderboard names, week numbers and who
## may use an invite. The Online autoload applies them.

## Promo codes: SHA-256 of the normalised code (trimmed, upper case) -> what
## it gives. The plain codes are only in docs/online.md (how to add one is
## there too). "boost" is seconds of x2 coins, "item" a wardrobe item.
const PROMOS := {
	"93b4090a74ac713f7867338ec6fa135499d4053cfdb81dc592c4c5c9ea892856": {"id": "p1", "pearls": 50},
	"ec9ee22a6733eed7d86e663d3ed14853f2725f4abac515d9cb9d189cbbb100c9": {"id": "p2", "pearls": 30, "boost": 3600},
	"bed9b2c24e8646faf3e9e3a63013e84c2fad11b0df049d7dd4c861be0140c1d2": {"id": "p3", "pearls": 25, "item": "hat_founder"},
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

## Small block list (EN / RU / ES): a name containing one becomes "Diver####".
## Checked on the name in lower case with look-alike letters and digits
## mapped back (0 -> o, 1 -> i, 3 -> e, ...) and spaces/dots removed.
const BLOCKED: Array[String] = [
	"fuck", "fuk", "shit", "bitch", "cunt", "pussy", "nigg", "fagg", "whore", "slut", "nazi", "hitler",
	"porn", "asshole", "bastard", "penis", "vagina", "dildo", "wank", "retard",
	"хуй", "хуе", "хуё", "пизд", "бляд", "блят", "ебат", "ебан", "ебал", "ёба", "сука", "суки", "мудак", "мудил",
	"пидор", "пидар", "педик", "гандон", "шлюх", "залуп", "долбо", "дроч", "жопа", "говн",
	"puta", "puto", "mierda", "coño", "cabron", "cabrón", "pendej", "joder", "polla", "verga", "chinga",
	"culero", "maricon", "maricón", "gilipoll", "follar", "zorra", "mamon", "pinche",
]
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
	return false


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


# --- Invites ---------------------------------------------------------------------------

## The player's invite code: the first letters of their online id.
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
