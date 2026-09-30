"""Calibrates the 21 depths so each Dive Deeper run takes about two hours.

Run 1 opens depths 2..6 at RUN1_MIN minutes. Every later run (income x3 per
dive) opens two new depths at NEW_MIN minutes and can dive again at
PRESTIGE_MIN. Unlock cost = SAVE_SEC of income at the target moment.
Prints constants for balance.gd.
"""
import sim

RUN1_MIN = [4, 12, 26, 45, 70]
NEW_MIN = [50, 85]
PRESTIGE_MIN = 125
SAVE_SEC = 150


def play(mult, keep, seconds):
    g = sim.Game(mult, keep)
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


def set_unlock(k, cost):
    sim.DEPTHS[k]["unlock"] = cost
    # Foremen are a mid-term goal: never cheaper than a few minutes of saving.
    sim.MANAGER_COST[f"d{k}"] = 2.5e3 if k == 1 else float(f"{cost * 2.0:.2g}")


def calibrate():
    sim.OPEN_WITHIN_SEC = SAVE_SEC * 1.05
    for k in range(1, len(sim.DEPTHS)):
        set_unlock(k, 1e300)
    costs = []
    keep = ()
    for r in range(sim.RUNS):
        mult = sim.prestige_mult(r)
        gate = sim.prestige_gate(r)
        if r == 0:
            plan = list(zip(range(1, 6), RUN1_MIN))
        else:
            plan = [(k, m) for k, m in zip(range(gate - 1, gate + 1), NEW_MIN) if k < len(sim.DEPTHS)]
        for k, minute in plan:
            g = play(mult, keep, minute * 60 - SAVE_SEC)
            set_unlock(k, float(f"{g.income() * SAVE_SEC:.2g}"))
        g = play(mult, keep, (PRESTIGE_MIN - 20) * 60)
        costs.append(float(f"{g.income() * 20 * 60:.2g}"))
        keep = ("boat", "plant")
    return costs


if __name__ == "__main__":
    costs = calibrate()
    for k, d in enumerate(sim.DEPTHS):
        print(sim.IDS[k], d["unlock"], sim.MANAGER_COST.get(f"d{k}"))
    print("prestige costs:", costs)
