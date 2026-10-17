class_name Rifts
extends RefCounted
## R'lyeh's rifts (the saga, act III): now and then a rift tears open in a
## working mine and tentacles steal its ore (the site gives STEAL of its
## output) until the player taps it TAPS times. While any rift is open the
## Murk rises MURK_MULT times as fast. Only in live play (away time has no
## rifts, GameState.simulate_offline); rifts are not saved.

const EVERY := 70.0
const TAPS := 6
const STEAL := 0.25
const MURK_MULT := 2.0
## The world that has rifts.
const WORLD := "rlyeh"
