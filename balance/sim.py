"""Coralight 3.0 "Worlds" balance simulation.

Models one location of the tycoon chain: work sites -> lift -> boat -> plant
-> vault -> wallet. A greedy "reasonable player" buys whatever gives the best
income gain per coin, opens sites and hires managers when they are a few
minutes of income away, buys evolution forms (x1.10 income each) and, once
the location gate is met (all 10 sites open, 10 foremen, lift + boat + boat2
+ plant + plant2 managers), saves up for the location price. Forms are an
optional booster, not part of the gate.

Every location scales values and prices by loc_scale(L); the gate prices
(site unlocks, foremen, evolution forms and the location price) also grow by
GATE_GROWTH per location, so each location takes a little longer.

Run:  python3 sim.py            (timeline per location)
      python3 sim.py --trace    (every purchase)
      python3 sim.py --locs N   (simulate N locations, default 12)
"""
import sys

# --- Parameters: the game must use exactly these (balance.gd mirrors them) ---
GROWTH = 1.08                     # upgrade cost growth per level
MILESTONE_FIRST = 10              # x2 output at level 10, then every 25 levels (25, 50, 75...)
MILESTONE_STEP = 25
# The lift, boats and plants get cheaper levels than the sites, so the
# chain keeps up with ten sites within one location.
CHAIN_GROWTH = 1.05

# The one 10-step site ladder (ids are the ocean ones; other worlds rename them).
# value: coins/s per level; cost0: level 1->2; unlock: price to open;
# manager: price of the site's foreman.
DEPTHS = [
    {"id": "shells",   "value": 0.8,    "cost0": 6.0,   "unlock": 0.0,   "manager": 400.0},
    {"id": "coral",    "value": 6.0,    "cost0": 60.0,  "unlock": 60.0,  "manager": 400.0},
    {"id": "pearl",    "value": 45.0,   "cost0": 600.0, "unlock": 2.0e3, "manager": 4.0e3},
    {"id": "copper",   "value": 320.0,  "cost0": 6.0e3, "unlock": 5.2e6, "manager": 1.0e7},
    {"id": "emerald",  "value": 2.3e3,  "cost0": 6.0e4, "unlock": 3.6e7, "manager": 7.2e7},
    {"id": "crystal",  "value": 1.6e4,  "cost0": 6.0e5, "unlock": 1.7e8, "manager": 3.4e8},
    {"id": "gold",     "value": 1.12e5, "cost0": 6.0e6, "unlock": 3.0e8, "manager": 6.0e8},
    {"id": "glow",     "value": 7.8e5,  "cost0": 6.0e7, "unlock": 6.0e8, "manager": 1.2e9},
    {"id": "atlantis", "value": 5.5e6,  "cost0": 6.0e8, "unlock": 1.2e9, "manager": 2.4e9},
    {"id": "heart",    "value": 3.8e7,  "cost0": 6.0e9, "unlock": 3.0e9, "manager": 6.0e9},
]
LIFT = {"value": 3.0, "cost0": 4.0, "manager": 10.0, "growth": CHAIN_GROWTH}
BOAT = {"value": 1.5, "cost0": 8.0, "manager": 25.0, "growth": CHAIN_GROWTH}
PLANT = {"value": 1.7, "cost0": 10.0, "manager": 45.0, "growth": CHAIN_GROWTH}
BOAT2 = {"value": 60.0, "cost0": 2.0e4, "manager": 4.0e5, "unlock": 2.0e5, "growth": CHAIN_GROWTH}
PLANT2 = {"value": 68.0, "cost0": 2.5e4, "manager": 5.0e5, "unlock": 2.5e5, "growth": CHAIN_GROWTH}
FOREMAN_MULT = 2.0
# The accountant (vault manager): collects the vault by itself. Kept forever.
VAULT_MANAGER = 1.0e6
# Evolution forms 1..12 of location 0 (later locations: x loc_gate_scale(L)).
EVO_PRICES = [40.0, 200.0, 3.8e5, 1.2e7, 7.2e7, 1.9e8, 2.5e8, 4.0e8, 8.0e8, 1.6e9, 3.0e9, 4.0e9]
EVO_MULT = 1.10
EVO_FORMS = 12
# Price to open the next location (location 0; later: x loc_gate_scale(L)).
LOCATION_PRICE = 2.4e10
# Every location: values and prices x LOC_SCALE_STEP ...
LOC_SCALE_STEP = 1000.0
# ... and the gate prices (site unlocks, foremen, forms, location price)
# x GATE_GROWTH more, so each location takes a little longer.
GATE_GROWTH = 1.4
# Location 0 also pays for the automation that later locations keep, so
# every later location's gate costs this much more on top.
GATE_BUMP = 1.45


def loc_scale(L: int) -> float:
    return LOC_SCALE_STEP ** L


def loc_gate_scale(L: int) -> float:
    return loc_scale(L) * GATE_GROWTH ** L * (GATE_BUMP if L > 0 else 1.0)


def evo_cost(L: int, form: int) -> float:
    return EVO_PRICES[form - 1] * loc_gate_scale(L)


def location_cost(L: int) -> float:
    return LOCATION_PRICE * loc_gate_scale(L)


# --- Player model ---------------------------------------------------------------
# The lift, the boats and the plants run on taps (at this efficiency) until
# their manager is hired. Without the accountant the player walks to the
# vault and collects every COLLECT_SEC seconds.
TAP_EFFICIENCY = 0.35
COLLECT_SEC = 30
OPEN_WITHIN_SEC = 126      # a player saves for a new site if it is ~2 min of income away
MANAGER_WITHIN_SEC = 300
EVO_WITHIN_SEC = 90
CHEAP_FIRST = 0.1
GATE_WITHIN_SEC = 600      # once all sites are open, gate items get bought when 10 min away
DT = 1.0


def milestones(level: int) -> int:
    return 0 if level < MILESTONE_FIRST else 1 + level // MILESTONE_STEP


def output(value: float, level: int) -> float:
    return 0.0 if level <= 0 else value * level * 2.0 ** milestones(level)


def up_cost(cost0: float, level: int, growth: float = GROWTH) -> float:
    return cost0 * growth ** (level - 1)


class Game:
    def __init__(self, L: int = 0, keep=()):
        self.L = L
        self.s = loc_scale(L)
        self.coins = 0.0
        self.vault = 0.0
        self.depth_lv = [1] + [0] * (len(DEPTHS) - 1)
        self.lv = {"lift": 1, "boat": 1, "plant": 1, "boat2": 0, "plant2": 0}
        self.managers = set(keep)
        self.evo = 0

    @property
    def mult(self) -> float:
        return EVO_MULT ** self.evo

    def stage_rates(self):
        dives = 0.0
        for k, d in enumerate(DEPTHS):
            eff = FOREMAN_MULT if f"d{k}" in self.managers else 1.0
            dives += output(d["value"], self.depth_lv[k]) * eff
        r = {}
        for key, data in (("lift", LIFT), ("boat", BOAT), ("plant", PLANT), ("boat2", BOAT2), ("plant2", PLANT2)):
            r[key] = output(data["value"], self.lv[key]) * (1.0 if key in self.managers else TAP_EFFICIENCY)
        return dives, r["lift"], r["boat"] + r["boat2"], r["plant"] + r["plant2"]

    def income(self) -> float:
        return min(self.stage_rates()) * self.mult * self.s

    def gate(self):
        sites = sum(1 for lv in self.depth_lv if lv > 0)
        foremen = sum(1 for k in range(len(DEPTHS)) if f"d{k}" in self.managers)
        mgrs = sum(1 for k in ("lift", "boat", "plant", "boat2", "plant2") if k in self.managers and self.lv[k] > 0)
        return {"sites": (sites, 10), "foremen": (foremen, 10), "managers": (mgrs, 5)}

    def ready(self) -> bool:
        return all(h >= n for h, n in self.gate().values())

    def options(self):
        """(label, cost, action, is_gate_item) for every purchase available now."""
        s = self.s
        gs = loc_gate_scale(self.L)
        opts = []
        for k, d in enumerate(DEPTHS):
            lv = self.depth_lv[k]
            if lv == 0:
                if self.depth_lv[k - 1] > 0:
                    opts.append((f"open site {k + 1} ({d['id']})", d["unlock"] * gs, ("open", k), True))
            else:
                opts.append((f"site {k + 1} -> {lv + 1}", up_cost(d["cost0"], lv, d.get("growth", GROWTH)) * s, ("depth", k), False))
                if f"d{k}" not in self.managers:
                    opts.append((f"foreman site {k + 1}", d["manager"] * gs, ("mgr", f"d{k}"), True))
        for key, data in (("lift", LIFT), ("boat", BOAT), ("plant", PLANT), ("boat2", BOAT2), ("plant2", PLANT2)):
            lv = self.lv[key]
            if lv == 0:
                if self.depth_lv[2] > 0:
                    opts.append((f"open {key}", data["unlock"] * s, ("open2", key), True))
                continue
            opts.append((f"{key} -> {lv + 1}", up_cost(data["cost0"], lv, data.get("growth", GROWTH)) * s, ("lv", key), False))
            if key not in self.managers:
                opts.append((f"manager {key}", data["manager"] * s, ("mgr", key), True))
        if "vault" not in self.managers:
            opts.append(("accountant (vault manager)", VAULT_MANAGER * s, ("mgr", "vault"), False))
        if self.evo < EVO_FORMS:
            opts.append((f"evolution form {self.evo + 1}", evo_cost(self.L, self.evo + 1), ("evo",), False))
        return opts

    def apply(self, action):
        kind = action[0]
        if kind == "open":
            self.depth_lv[action[1]] = 1
        elif kind == "depth":
            self.depth_lv[action[1]] += 1
        elif kind == "open2":
            self.lv[action[1]] = 1
        elif kind == "lv":
            self.lv[action[1]] += 1
        elif kind == "mgr":
            self.managers.add(action[1])
        elif kind == "evo":
            self.evo += 1

    def potential(self) -> float:
        """Smooth stand-in for min(): rewards raising any stage, the weakest most.
        Players read the bottleneck; a strict min() makes ties look worthless."""
        rates = self.stage_rates()
        if min(rates) <= 0:
            return 0.0
        return self.mult * len(rates) / sum(1.0 / r ** 4 for r in rates) ** 0.25 / len(rates) ** 0.75

    def gain_of(self, action) -> float:
        before = self.potential()
        saved = (list(self.depth_lv), dict(self.lv), set(self.managers), self.evo)
        self.apply(action)
        after = self.potential()
        self.depth_lv, self.lv, self.managers, self.evo = saved
        return after - before


def best_upgrade(g: Game, opts, inc: float):
    """The purchase with the best income gain per second of income spent and waited."""
    best, best_score = None, 0.0
    for o in opts:
        if o[2][0] in ("open", "open2") or o[2] == ("mgr", "vault"):
            continue
        gain = g.gain_of(o[2])
        if gain <= 0:
            continue
        wait = max(0.0, o[1] - g.coins) / inc
        score = gain / (o[1] / inc + wait + 1e-9)
        if score > best_score:
            best, best_score = o, score
    return best


def best_option(g: Game):
    inc = max(g.income(), 1e-9)
    opts = g.options()
    best = best_upgrade(g, opts, inc)
    all_open = all(lv > 0 for lv in g.depth_lv)
    wanted = []
    for o in opts:
        kind = o[2][0]
        if kind in ("open", "open2") and o[1] <= inc * OPEN_WITHIN_SEC:
            wanted.append(o)
        elif kind == "mgr" and o[1] <= inc * MANAGER_WITHIN_SEC:
            wanted.append(o)
        elif kind == "evo" and o[1] <= inc * EVO_WITHIN_SEC:
            # A new look for the worker is exciting: bought once it is close.
            wanted.append(o)
        elif all_open and o[3] and o[1] <= inc * GATE_WITHIN_SEC:
            # Once every site is open the player works through the gate checklist.
            wanted.append(o)
    if wanted:
        pick = min(wanted, key=lambda o: o[1])
        # Small obvious upgrades (a tenth of the price or less) come first.
        if best and best[1] <= CHEAP_FIRST * pick[1]:
            return best
        return pick
    return best


def run(L: int, keep=(), trace: bool = False, max_t: float = 24 * 3600):
    g = Game(L, keep)
    t = 0.0
    events = []
    target = best_option(g)
    gate_t = None
    while t < max_t:
        if gate_t is None and g.ready():
            gate_t = t
            events.append((t, "GATE met (all sites, foremen, managers)"))
            target = None
        if gate_t is not None and g.coins >= location_cost(L):
            g.coins -= location_cost(L)
            events.append((t, f"LOCATION done (paid {location_cost(L):.3g})"))
            return t, events, g
        earned = g.income() * DT
        if "vault" in g.managers:
            g.coins += earned
        else:
            g.vault += earned
            if int(t) % COLLECT_SEC == 0:
                g.coins += g.vault
                g.vault = 0.0
        t += DT
        if target is None and gate_t is None:
            target = best_option(g)
        while target and g.coins >= target[1]:
            g.coins -= target[1]
            g.apply(target[2])
            label = target[0]
            if trace or label.split()[0] not in ("site", "lift", "boat", "plant", "boat2", "plant2"):
                events.append((t, label))
            target = best_option(g) if gate_t is None and not g.ready() else None
        if gate_t is not None and target is None and int(t) % 10 == 0:
            # Saving for the location: only buy what costs under 5% of what is still needed.
            cand = best_option(g)
            need = location_cost(L) - g.coins
            if cand and cand[1] <= 0.05 * max(need, 0):
                target = cand
    return None, events, g


def fmt(t: float) -> str:
    return f"{int(t // 3600)}:{int(t % 3600 // 60):02d}:{int(t % 60):02d}"


def main():
    trace = "--trace" in sys.argv
    locs = 12
    if "--locs" in sys.argv:
        locs = int(sys.argv[sys.argv.index("--locs") + 1])
    keep = ()
    total = 0.0
    summary = []
    for L in range(locs):
        t, events, g = run(L, keep, trace)
        keep = tuple(m for m in g.managers if m in ("lift", "boat", "plant", "boat2", "plant2", "vault"))
        print(f"=== Location {L} (x{loc_scale(L):.3g} values, gate x{loc_gate_scale(L):.3g}, price {location_cost(L):.3g}) ===")
        for et, label in events:
            print(f"  {fmt(et)}  {label}")
        if t is None:
            print("  location NOT done in 24h")
            break
        total += t
        prev = summary[-1][1] if summary else None
        summary.append((L, t))
        grow = f" (+{(t / prev - 1) * 100:.0f}%)" if prev else ""
        print(f"  end {fmt(t)}{grow} total {fmt(total)}; lift {g.lv['lift']}, boat {g.lv['boat']}+{g.lv['boat2']}, "
              f"plant {g.lv['plant']}+{g.lv['plant2']}, sites {g.depth_lv}, income {g.income():.3g}/s")
    print("=== Summary: minutes per location ===")
    prev = None
    for L, t in summary:
        grow = f"  +{(t / prev - 1) * 100:.0f}%" if prev else ""
        print(f"  L{L:2d}: {t / 60:6.1f} min{grow}")
        prev = t


if __name__ == "__main__":
    main()
