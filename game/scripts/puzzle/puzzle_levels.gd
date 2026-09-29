class_name PuzzleLevels
extends RefCounted
## Endless puzzle levels generated from the level number.
##
## The curve is gentle and saw-toothed: new things arrive slowly (sand from
## level 4, bubbles from level 8, a fifth tile kind from level 10, a sixth
## from 30) and every 5th level is a "breather" with extra moves. Early
## levels are nearly impossible to fail; later ones ask for a little thought.
## Moves are tuned with a simulated player (see tests/test_match3.gd, which
## also prints win rates for a greedy and a random player).

## Level n (1-based): {"level", "width", "height", "kinds", "fragments",
## "fragments_at_start", "moves", "sand", "sand2", "bubbles", "seed", "artifact"}.
## The caller may override any key (e.g. "artifact") before PuzzleScreen.setup.
static func level(n: int) -> Dictionary:
	n = maxi(1, n)
	var breather := n % 5 == 0 and n > 5
	var kinds := 4
	if n >= 30 and n % 3 == 0:
		kinds = 6
	elif n >= 10:
		kinds = 5
	var fragments := 1
	if n >= 25:
		fragments = 4
	elif n >= 12:
		fragments = 3
	elif n >= 4:
		fragments = 2
	# Invisible helper: new tiles sometimes copy the one below (more cascades).
	var assist := 0.25 if n <= 3 else 0.15
	if kinds == 5:
		assist = 0.37 - clampf((n - 10) * 0.002, 0.0, 0.04)
	elif kinds == 6:
		assist = 0.42
	var sand := 0
	var sand2 := 0
	if n >= 4:
		sand = mini(2 + (n - 4) / 3, 8)
	if n >= 16:
		sand2 = mini(1 + (n - 16) / 6, 4)
		sand = maxi(0, sand - sand2)
	var bubbles := 0
	if n >= 8:
		bubbles = mini(2 + (n - 8) / 3, 8)
	if breather:
		sand = sand / 2
		sand2 = 0
		bubbles = bubbles / 2
	var ids := ArtifactArt.IDS
	return {
		"level": n,
		"width": 7,
		"height": 8,
		"kinds": kinds,
		"fragments": fragments,
		"fragments_at_start": mini(fragments, 2),
		"assist": assist,
		"moves": moves_for(n, fragments, sand + sand2 * 2 + bubbles, breather),
		"sand": sand,
		"sand2": sand2,
		"bubbles": bubbles,
		"seed": n * 7919 + 13,
		"artifact": ids[(n - 1) % ids.size()],
	}


## About what a focused player needs, times a generous factor that shrinks
## from 2.5x on level 1 to 1.3x from level 30 on (breathers get more).
## `blockers` = sand layers + bubbles.
static func moves_for(n: int, fragments: int, blockers: int, breather: bool) -> int:
	var need := 3.5 + fragments * 3.2 + blockers * 0.3
	var slack := lerpf(2.5, 1.3, clampf((n - 1) / 29.0, 0.0, 1.0))
	if breather:
		slack += 0.4
	return int(ceil(need * slack))
