class_name NumFormat
extends RefCounted
## Short numbers for the UI: 7, 950, 1.2K, 34.5M, 2.0B, 5.1T, then aa, ab, ... az, ba...
## like Idle Miner, so numbers never overflow the layout.

const NAMED: Array[String] = ["", "K", "M", "B", "T"]


static func suffix(tier: int) -> String:
	if tier < NAMED.size():
		return NAMED[tier]
	var n := tier - NAMED.size()
	var a := "abcdefghijklmnopqrstuvwxyz"
	return a[(n / 26) % 26] + a[n % 26]


static func short(value: float) -> String:
	if not is_finite(value):
		return "∞"
	var v := floorf(absf(value))
	var sign := "-" if value < 0.0 else ""
	if v < 1000.0:
		return sign + str(int(v))
	var tier := int(floor(log(v) / log(1000.0)))
	var shown := v / pow(1000.0, tier)
	# Float error can land at 999.99 or 1000.0 on the boundary.
	if shown >= 1000.0:
		shown /= 1000.0
		tier += 1
	# Truncate, never round up, so 999.99K doesn't turn into 1000K.
	shown = floorf(shown * 10.0) / 10.0
	if shown >= 100.0:
		return "%s%d%s" % [sign, int(shown), suffix(tier)]
	return "%s%.1f%s" % [sign, shown, suffix(tier)]


## Per-second rates keep one decimal while small: 0.6, 12.5, 1.2K.
static func rate(value: float) -> String:
	if value < 100.0:
		return "%.1f" % value
	return short(value)


## 1:05:09 / 4:07 / 0:12
static func duration(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, s % 3600 / 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
