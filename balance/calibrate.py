"""Calibrates location 0 so things happen at the target minutes.

Each site's unlock price is SAVE_SEC of the income the greedy player
(sim.py) has at the target minute, its foreman FOREMAN_X times that; each
gear level is EVO_SEC of income at its minute; the accountant and the
location price likewise. Items are calibrated in time order (later ones are
blocked meanwhile). Prints constants to paste into sim.py and balance.gd.

Run:  python3 calibrate.py
"""
import sim

SITE_MIN = [None, 2.5, 6, 11, 17, 24, 31, 39, 48, 57]   # site k may open at this minute
EVO_MIN = [9, 25, 53]      # gear levels 2, 3, 4
VAULT_MIN = 9
GATE_MIN = 66            # location price is LOC_SEC of income here
SAVE_SEC = 120
FOREMAN_X = 2.0
EVO_SEC = 240
VAULT_SEC = 240
LOC_SEC = 900
BLOCK = 1e300


def nice(v: float) -> float:
    return float(f"{v:.2g}")


def income_at(minute: float) -> float:
    _, _, g = sim.run(0, (), max_t=minute * 60)
    return g.income()


def calibrate():
    for k in range(1, 10):
        sim.DEPTHS[k]["unlock"] = BLOCK
        sim.DEPTHS[k]["manager"] = BLOCK
    sim.EVO_PRICES = [BLOCK] * sim.EVO_FORMS
    sim.VAULT_MANAGER = BLOCK
    sim.LOCATION_PRICE = BLOCK
    plan = [(m, "site", k) for k, m in enumerate(SITE_MIN) if m is not None]
    plan += [(m, "evo", i) for i, m in enumerate(EVO_MIN)]
    plan += [(VAULT_MIN, "vault", 0), (GATE_MIN, "loc", 0)]
    plan.sort()
    for minute, kind, k in plan:
        inc = income_at(minute)
        if kind == "site":
            sim.DEPTHS[k]["unlock"] = nice(inc * SAVE_SEC)
            sim.DEPTHS[k]["manager"] = nice(inc * SAVE_SEC * FOREMAN_X)
        elif kind == "evo":
            sim.EVO_PRICES[k] = nice(inc * EVO_SEC)
        elif kind == "vault":
            sim.VAULT_MANAGER = nice(inc * VAULT_SEC)
        else:
            sim.LOCATION_PRICE = nice(inc * LOC_SEC)
        print(f"  {minute:5.1f} min  {kind} {k}: income {inc:.3g}/s")
    print("unlock  =", [d["unlock"] for d in sim.DEPTHS])
    print("manager =", [d["manager"] for d in sim.DEPTHS])
    print("EVO_PRICES =", sim.EVO_PRICES)
    print("VAULT_MANAGER =", sim.VAULT_MANAGER)
    print("LOCATION_PRICE =", sim.LOCATION_PRICE)


if __name__ == "__main__":
    calibrate()
