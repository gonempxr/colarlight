class_name Tides
extends RefCounted
## Atlantis' tides (the saga, act II): a CYCLE-second cycle on the clock.
## High tide (the first half): the lift and the boats carry x MULT. Low
## tide (the second half): the mines dig x MULT. Offline and away time
## count without tides (GameState.simulate_offline), so leaving never
## beats playing.

const CYCLE := 180.0
const MULT := 2.0
## The world that has tides.
const WORLD := "atlantis"


## true at high tide (lift and boats), false at low tide (mines).
static func high(now: float) -> bool:
	return fposmod(now, CYCLE) < CYCLE / 2.0


## Seconds until the tide turns.
static func left(now: float) -> float:
	return CYCLE / 2.0 - fposmod(now, CYCLE / 2.0)


## The tide's factor for a stage group ("dives", "lift", "boat", "plant").
static func mult(now: float, group: String) -> float:
	if high(now):
		return MULT if group == "lift" or group == "boat" else 1.0
	return MULT if group == "dives" else 1.0
