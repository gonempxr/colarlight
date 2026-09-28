"""Finds depth unlock / manager / prestige costs that hit the target pacing.

Target: a player opens depth 2..6 at the minutes in TARGET_MIN, and can afford
the first prestige at PRESTIGE_MIN. Prints constants to paste into balance.gd / sim.py.
"""
import sim

TARGET_MIN = [3, 9, 20, 40, 70]
PRESTIGE_MIN = 150
SAVE_SEC = 120          # unlock cost = ~2 minutes of income at the target moment
MANAGER_FRACTION = 0.3  # depth manager costs 30% of that depth's unlock


def play_until(seconds: float) -> sim.Game:
    g = sim.Game()
    t = 0
    target = sim.best_option(g)
    while t < seconds:
        g.coins += g.income() * sim.DT
        t += sim.DT
        while target and g.coins >= target[1]:
            g.coins -= target[1]
            g.apply(target[2])
            target = sim.best_option(g)
        if target is None:
            target = sim.best_option(g)
    return g


def calibrate():
    sim.OPEN_WITHIN_SEC = SAVE_SEC * 1.05
    for d in sim.DEPTHS[1:]:
        d["unlock"] = 1e30
    for k in range(1, len(sim.DEPTHS)):
        g = play_until(TARGET_MIN[k - 1] * 60 - SAVE_SEC)
        unlock = float(f"{g.income() * SAVE_SEC:.2g}")
        sim.DEPTHS[k]["unlock"] = unlock
        sim.MANAGER_COST[f"d{k}"] = float(f"{unlock * MANAGER_FRACTION:.2g}")
    g = play_until(PRESTIGE_MIN * 60 - 15 * 60)
    return float(f"{g.income() * 15 * 60:.2g}")


if __name__ == "__main__":
    p = calibrate()
    print("unlock:", [d["unlock"] for d in sim.DEPTHS])
    print("managers:", sim.MANAGER_COST)
    print("prestige 1 cost:", p)
