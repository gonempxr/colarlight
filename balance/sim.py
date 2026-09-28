"""Coralight 2.0 balance simulation.

Models the tycoon chain: dive sites -> boat -> processing plant -> coins.
A greedy "reasonable player" buys whatever gives the best income gain per coin.
Prints when each depth opens, when managers are hired and when prestige is reached.

Run:  python3 sim.py            (summary)
      python3 sim.py --trace    (every purchase)
"""
import math
import sys

# --- Parameters: the game must use exactly these (balance.gd mirrors them) ---
GROWTH = 1.08                     # upgrade cost growth per level
MILESTONE_FIRST = 10              # x2 output at level 10, then every 25 levels (25, 50, 75...)
DEPTHS = [
    # value: coins/s per level at depth; cost0: level 1->2 upgrade cost; unlock: cost to open
    {"value": 0.8,    "cost0": 6,       "unlock": 0},
    {"value": 6,      "cost0": 60,      "unlock": 50},
    {"value": 45,     "cost0": 600,     "unlock": 9e4},
    {"value": 320,    "cost0": 6e3,     "unlock": 7e5},
    {"value": 2.3e3,  "cost0": 6e4,     "unlock": 1.7e6},
    {"value": 1.6e4,  "cost0": 6e5,     "unlock": 3.8e6},
]
BOAT = {"value": 1.5, "cost0": 8}
PLANT = {"value": 1.7, "cost0": 10}
# Stage runs only on taps until its manager is hired.
TAP_EFFICIENCY = 0.35
MANAGER_COST = {"plant": 15, "boat": 30, "d0": 20, "d1": 50, "d2": 2.7e4, "d3": 2.1e5, "d4": 5.1e5, "d5": 1.1e6}
PRESTIGE_COSTS = [6.3e7, 6.3e7 * 8, 6.3e7 * 64]   # need all depths open + this many coins
PRESTIGE_MULT = [3, 9, 27]                        # income multiplier after 1st, 2nd, 3rd prestige

DT = 1.0


def milestone_mult(level: int) -> float:
    m = (1 if level >= MILESTONE_FIRST else 0) + level // 25
    return 2.0 ** m


def output(value: float, level: int) -> float:
    return 0.0 if level <= 0 else value * level * milestone_mult(level)


def up_cost(cost0: float, level: int) -> float:
    return cost0 * GROWTH ** (level - 1)


class Game:
    def __init__(self, mult: float = 1.0):
        self.coins = 0.0
        self.depth_lv = [1] + [0] * (len(DEPTHS) - 1)
        self.boat_lv = 1
        self.plant_lv = 1
        self.managers = set()
        self.mult = mult

    def stage_rates(self):
        dives = 0.0
        for k, d in enumerate(DEPTHS):
            eff = 1.0 if f"d{k}" in self.managers else TAP_EFFICIENCY
            dives += output(d["value"], self.depth_lv[k]) * eff
        boat = output(BOAT["value"], self.boat_lv) * (1.0 if "boat" in self.managers else TAP_EFFICIENCY)
        plant = output(PLANT["value"], self.plant_lv) * (1.0 if "plant" in self.managers else TAP_EFFICIENCY)
        return dives, boat, plant

    def income(self) -> float:
        return min(self.stage_rates()) * self.mult

    def options(self):
        """(label, cost, apply) for every purchase available now."""
        opts = []
        for k, d in enumerate(DEPTHS):
            lv = self.depth_lv[k]
            if lv == 0:
                if self.depth_lv[k - 1] > 0:
                    opts.append((f"open depth {k + 1}", d["unlock"], ("open", k)))
            else:
                opts.append((f"depth {k + 1} -> {lv + 1}", up_cost(d["cost0"], lv), ("depth", k)))
                if f"d{k}" not in self.managers:
                    opts.append((f"manager depth {k + 1}", MANAGER_COST[f"d{k}"], ("mgr", f"d{k}")))
        opts.append((f"boat -> {self.boat_lv + 1}", up_cost(BOAT["cost0"], self.boat_lv), ("boat",)))
        opts.append((f"plant -> {self.plant_lv + 1}", up_cost(PLANT["cost0"], self.plant_lv), ("plant",)))
        for s in ("boat", "plant"):
            if s not in self.managers:
                opts.append((f"manager {s}", MANAGER_COST[s], ("mgr", s)))
        return opts

    def apply(self, action):
        kind = action[0]
        if kind == "open":
            self.depth_lv[action[1]] = 1
        elif kind == "depth":
            self.depth_lv[action[1]] += 1
        elif kind == "boat":
            self.boat_lv += 1
        elif kind == "plant":
            self.plant_lv += 1
        elif kind == "mgr":
            self.managers.add(action[1])

    def potential(self) -> float:
        """Smooth stand-in for min(): rewards raising any stage, the weakest most.
        Players read the bottleneck; a strict min() makes ties look worthless."""
        rates = self.stage_rates()
        if min(rates) <= 0:
            return 0.0
        return self.mult * len(rates) / sum(1.0 / r ** 4 for r in rates) ** 0.25 / len(rates) ** 0.75

    def gain_of(self, action) -> float:
        before = self.potential()
        saved = (list(self.depth_lv), self.boat_lv, self.plant_lv, set(self.managers))
        self.apply(action)
        after = self.potential()
        self.depth_lv, self.boat_lv, self.plant_lv, self.managers = saved
        return after - before


OPEN_WITHIN_SEC = 126      # a player saves for a new depth if it's <10 min of income away
MANAGER_WITHIN_SEC = 300


def best_option(g: Game):
    inc = max(g.income(), 1e-9)
    opts = g.options()
    for label, cost, action in opts:
        if action[0] == "open" and cost <= inc * OPEN_WITHIN_SEC:
            return (label, cost, action)
    for label, cost, action in opts:
        if action[0] == "mgr" and cost <= inc * MANAGER_WITHIN_SEC:
            return (label, cost, action)
    best, best_score = None, 0.0
    for label, cost, action in opts:
        if action[0] == "open":
            continue
        gain = g.gain_of(action)
        if gain <= 0:
            continue
        wait = max(0.0, cost - g.coins) / inc
        score = gain / (cost / inc + wait + 1e-9)
        if score > best_score:
            best, best_score = (label, cost, action), score
    return best


def run(mult: float, prestige_cost: float, trace: bool, max_t: float = 12 * 3600):
    g = Game(mult)
    t = 0.0
    events = []
    target = best_option(g)
    while t < max_t:
        if all(lv > 0 for lv in g.depth_lv) and g.coins >= prestige_cost:
            events.append((t, "PRESTIGE ready"))
            return t, events, g
        g.coins += g.income() * DT
        t += DT
        while target and g.coins >= target[1]:
            g.coins -= target[1]
            g.apply(target[2])
            label = target[0]
            if trace or label.startswith(("open", "manager")):
                events.append((t, label))
            target = best_option(g)
            if all(lv > 0 for lv in g.depth_lv):
                # Saving for prestige: only buy when it's under 5% of what we still need.
                need = prestige_cost - g.coins
                if target and target[1] > 0.05 * max(need, 0):
                    target = None
        if target is None and not all(lv > 0 for lv in g.depth_lv):
            target = best_option(g)
        if target is None and int(t) % 10 == 0:
            cand = best_option(g)
            need = prestige_cost - g.coins
            if cand and cand[1] <= 0.05 * max(need, 0):
                target = cand
    return None, events, g


def fmt(t: float) -> str:
    return f"{int(t // 3600)}:{int(t % 3600 // 60):02d}:{int(t % 60):02d}"


def main():
    trace = "--trace" in sys.argv
    mult = 1.0
    for i, cost in enumerate(PRESTIGE_COSTS):
        t, events, g = run(mult, cost, trace)
        print(f"=== Run {i + 1} (income x{mult:g}) ===")
        for et, label in events:
            print(f"  {fmt(et)}  {label}")
        if t is None:
            print("  prestige NOT reached in 12h")
            break
        d, b, p = g.stage_rates()
        print(f"  end: depths {g.depth_lv}, boat {g.boat_lv}, plant {g.plant_lv}, "
              f"income {g.income():.3g}/s (dives {d:.3g} boat {b:.3g} plant {p:.3g})")
        mult = PRESTIGE_MULT[i]


if __name__ == "__main__":
    main()
