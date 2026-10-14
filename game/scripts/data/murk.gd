class_name Murk
extends RefCounted
## The Murk (the saga's corruption, Top League games): it rises from the
## deep while the mine works, darkens the world (MurkVeil: a violet gloom,
## eyes, tentacles) and makes everything dig up to LOSS slower. Taps push
## it back a little; a beaten guard cleanses the world, and every beaten
## guard slows it down.

## Seconds from clear to full with no guard beaten.
const FULL_SEC := 2400.0
## Each beaten guard makes it rise this much slower (x (1 + n * SLOW)).
const SLOW := 0.5
## Income lost at full Murk.
const LOSS := 0.5
## A tap clears this much.
const TAP_CLEAR := 0.03
## The income factor uses steps of this size (rates don't creep every frame).
const STEP := 0.02


## How much the Murk rises in `seconds` with `beaten` guards down.
static func rise(seconds: float, beaten: int) -> float:
	return maxf(0.0, seconds) / (FULL_SEC * (1.0 + SLOW * maxf(0, beaten)))


## Income factor at Murk `m` (0..1).
static func factor(m: float) -> float:
	return 1.0 - LOSS * snappedf(clampf(m, 0.0, 1.0), STEP)
