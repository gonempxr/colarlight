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
IDS = ["shells", "coral", "pearl", "copper", "emerald", "crystal", "amber", "sapphire", "gold", "ruby", "ice",
       "lava", "jade", "moon", "fossil", "obsidian", "glow", "atlantis", "meteor", "kraken", "star"]
# value: coins/s per level at depth; cost0: level 1->2 upgrade cost; unlock: cost to open.
# Depths after the sixth follow a fixed pattern (value x7, cost0 x10, unlock x UNLOCK_STEP).
FIRST = [
    {"value": 0.8,    "cost0": 6,       "unlock": 0},
    {"value": 6,      "cost0": 60,      "unlock": 120},
    {"value": 45,     "cost0": 600,     "unlock": 2.2e4},
    {"value": 320,    "cost0": 6e3,     "unlock": 4.5e5},
    {"value": 2.3e3,  "cost0": 6e4,     "unlock": 6e6},
    {"value": 1.6e4,  "cost0": 6e5,     "unlock": 6e7},
]
# Unlock prices: the first six from calibrate2.py (run 1), the rest follow the
# run pattern (depth before the gate ~ P/40, the gate depth ~ P/9 of that run's
# Dive Deeper price), so every run opens about two new depths.
UNLOCKS = [0, 90, 1300, 1.2e5, 1.0e6, 2.3e6,
           6.8e6, 3.0e7, 4.5e7, 2.0e8, 3.0e8, 1.3e9, 1.9e9, 8.4e9,
           1.2e10, 5.3e10, 7.8e10, 3.4e11, 5.0e11, 2.2e12, 1.4e13]
DEPTHS = [dict(d) for d in FIRST]
while len(DEPTHS) < len(IDS):
    prev = DEPTHS[-1]
    DEPTHS.append({"value": prev["value"] * 7, "cost0": prev["cost0"] * 10, "unlock": 0})
for k, u in enumerate(UNLOCKS):
    DEPTHS[k]["unlock"] = u
    # Deep sites: first level-up costs about the opening price, so their
    # upgrade buttons stay within reach (x10 per depth outran income).
    if k >= 7:
        DEPTHS[k]["cost0"] = u
BOAT = {"value": 1.5, "cost0": 8}
PLANT = {"value": 1.7, "cost0": 10}
# Dive sites work on their own from the start. The boat and the plant run
# only on taps (at this efficiency) until their manager is hired.
TAP_EFFICIENCY = 0.35
# A dive site's foreman doubles its output.
FOREMAN_MULT = 2.0
MANAGER_COST = {"boat": 25, "plant": 45, "d0": 400, "d1": 2.5e3}
for k in range(2, len(DEPTHS)):
    MANAGER_COST[f"d{k}"] = float(f"{DEPTHS[k]['unlock'] * 2.0:.2g}")
# Diving Deeper needs this depth open (deeper every time) and the coins.
PRESTIGE_GATE_FIRST = 5
PRESTIGE_GATE_STEP = 2
PRESTIGE_COST0 = 1.0e7
PRESTIGE_COST_GROWTH = 6.4
RUNS = 9


def prestige_gate(times: int) -> int:
    return min(PRESTIGE_GATE_FIRST + PRESTIGE_GATE_STEP * times, len(DEPTHS) - 1)


def prestige_cost(times: int) -> float:
    return PRESTIGE_COST0 * PRESTIGE_COST_GROWTH ** times


def prestige_mult(times: int) -> float:
    return 3.0 ** times

DT = 1.0


def milestone_mult(level: int) -> float:
    m = (1 if level >= MILESTONE_FIRST else 0) + level // 25
    return 2.0 ** m


def output(value: float, level: int) -> float:
    return 0.0 if level <= 0 else value * level * milestone_mult(level)


def up_cost(cost0: float, level: int) -> float:
    return cost0 * GROWTH ** (level - 1)


class Game:
    def __init__(self, mult: float = 1.0, keep=()):
        self.coins = 0.0
        self.depth_lv = [1] + [0] * (len(DEPTHS) - 1)
        self.boat_lv = 1
        self.plant_lv = 1
        self.managers = set(keep)
        self.mult = mult

    def stage_rates(self):
        dives = 0.0
        for k, d in enumerate(DEPTHS):
            eff = FOREMAN_MULT if f"d{k}" in self.managers else 1.0
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


def run(mult: float, prestige_cost: float, trace: bool, max_t: float = 12 * 3600, keep=(), gate: int = 5):
    g = Game(mult, keep)
    t = 0.0
    events = []
    target = best_option(g)
    while t < max_t:
        if g.depth_lv[gate] > 0 and g.coins >= prestige_cost:
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
            if g.depth_lv[gate] > 0 and g.depth_lv[min(gate + 1, len(DEPTHS) - 1)] == 0 and False:
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
    keep = ()
    total = 0.0
    for i in range(RUNS):
        mult = prestige_mult(i)
        gate = prestige_gate(i)
        t, events, g = run(mult, prestige_cost(i), trace, keep=keep, gate=gate)
        keep = tuple(m for m in g.managers if m in ("boat", "plant"))
        print(f"=== Run {i + 1} (income x{mult:g}, needs {IDS[gate]} + {prestige_cost(i):.2g}) ===")
        for et, label in events:
            if label.startswith("open") or label.startswith("PRESTIGE"):
                print(f"  {fmt(et)}  {label}")
        if t is None:
            print("  prestige NOT reached in 12h")
            break
        total += t
        deepest = max(k for k, lv in enumerate(g.depth_lv) if lv > 0)
        print(f"  end {fmt(t)} (total {fmt(total)}): deepest {IDS[deepest]}, boat {g.boat_lv}, plant {g.plant_lv}, income {g.income():.3g}/s")


if __name__ == "__main__":
    main()
