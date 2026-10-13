#!/usr/bin/env python3
"""Cover set v3 (2026-10-13), after the first CrazyGames day: CTR 0.8%.
The v2 cover (orange diver on orange) melted into one blob at thumbnail size
and didn't say "underwater mining tycoon". These use blue water behind the
orange hero (complementary colours) and show what the game is.

    python3 tools/store_art/covers_v3.py out_dir [D|E|F ...]
    ALL_SIZES=1 ... also portrait 800x1200 and square 800x800
    SHOT=path  the game screenshot for E (2560x1440 PC, late save, scroll 500)

D "Treasure"  blue sea, orange diver cheering at an open chest of gold
E "Real mine" the real game (a busy dive site) with the hero in front
F "Crew"      a crew of divers mining a giant gold vein under the sea
"""
import base64
import math
import os
import random
import sys

from PIL import Image, ImageEnhance
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import covers_v2 as v2  # noqa: E402
from covers_v2 import vcore, sprites, place, logo, rays, coins_burst, sparkles, wrap, render  # noqa: E402

INK = vcore.INK


def sea_bg(w, h, top="#46c3f5", mid="#1479c9", bot="#07306b"):
    return (f'<linearGradient id="seaV" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="0.45" stop-color="{mid}"/><stop offset="1" stop-color="{bot}"/></linearGradient>'
            '<linearGradient id="sand" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd98a"/><stop offset="1" stop-color="#e0a24e"/></linearGradient>'
            '<radialGradient id="goldGlow"><stop offset="0" stop-color="#fff3a8" stop-opacity="0.95"/><stop offset="0.45" stop-color="#ffcf33" stop-opacity="0.55"/>'
            '<stop offset="1" stop-color="#ffcf33" stop-opacity="0"/></radialGradient>')


def light_rays(w, h, k):
    out = []
    for i in range(6):
        x = w * (0.08 + i * 0.18)
        out.append(f'<path d="M {x - 40 * k} 0 L {x + 50 * k} 0 L {x + 260 * k} {h} L {x + 40 * k} {h} Z" fill="#ffffff" fill-opacity="0.07"/>')
    return "".join(out)


def bubbles(n, seed, area, k):
    rnd = random.Random(seed)
    x0, y0, w, h = area
    return "".join(vcore.bubble(x0 + rnd.random() * w, y0 + rnd.random() * h, rnd.uniform(8, 26) * k) for _ in range(n))


def seaweed(x, y, hgt, k, flip=1):
    d = f"M {x} {y} C {x + 30 * k * flip} {y - hgt * 0.3}, {x - 30 * k * flip} {y - hgt * 0.6}, {x + 10 * k * flip} {y - hgt}"
    return (f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{30 * k}" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="#2fbf71" stroke-width="{18 * k}" stroke-linecap="round"/>')


def seabed(w, h, k, y):
    return (f'<path d="M 0 {y} Q {w * 0.25} {y - 50 * k} {w * 0.5} {y - 10 * k} T {w} {y - 30 * k} L {w} {h} L 0 {h} Z" '
            f'fill="url(#sand)" stroke="{INK}" stroke-width="{9 * k}"/>')


# ------------------------------------------------------------------ D: treasure
def cover_d(w, h):
    land = w > h
    k = h / 1080 if land else w / 800 * 0.8
    body = [f'<rect width="{w}" height="{h}" fill="url(#seaV)"/>', light_rays(w, h, k), bubbles(22, 4, (0, 0, w, h * 0.8), k)]
    bed = h * (0.86 if land else 0.88)
    if land:
        cx, cy, cs = w * 0.66, bed + 20 * k, 1.0 * k
        hx, hs = w * 0.27, 1.02 * k
        lg = (w - min(w * 0.44, 840 * k) - 34 * k, 26 * k, min(w * 0.44, 840 * k))
    else:
        cx, cy, cs = w * 0.62, bed + 10 * k, 0.72 * k
        hx, hs = w * 0.34, 0.86 * k
        lg = (w * 0.08, 40 * k, w * 0.84)
    body.append(f'<circle cx="{cx}" cy="{cy - 330 * cs}" r="{520 * cs}" fill="url(#goldGlow)"/>')
    body.append(rays(cx, cy - 330 * cs, 18, 900 * cs, "#fff3a8", 0.16, 0.09))
    body.append(seabed(w, h, k, bed))
    body.append(vcore.coral(w * 0.04, bed + 30 * k, 1.4 * k))
    body.append(vcore.coral(w * 0.97, bed + 20 * k, 1.2 * k, flip=True))
    body.append(seaweed(w * 0.12, bed + 10 * k, 300 * k, k))
    body.append(seaweed(w * 0.88, bed, 260 * k, k, -1))
    body.append(place(vcore.chest(), cx, cy, cs))
    body.append(coins_burst(cx, cy - 560 * cs, 24, 330 * cs, 11, 26 * k, 62 * k))
    body.append(vcore.coin_stack(cx + 360 * cs, cy - 10 * k, 5, 46 * cs))
    hero = sprites.diver("wow", "up", "orange")
    body.append(f'<ellipse cx="{hx}" cy="{bed + 40 * k}" rx="{230 * hs}" ry="{36 * hs}" fill="#7a5a2a" fill-opacity="0.35"/>')
    body.append(place(hero, hx, bed + 44 * k, hs))
    body.append(sparkles(14, 3, (w * 0.45, 0, w * 0.55, h * 0.8)))
    body.append(logo(*lg))
    return wrap(w, h, "".join(body), sea_bg(w, h))


# ------------------------------------------------------------------ E: the real game
def shot_data(path, w, h):
    """The game screenshot cropped to the cover's shape, as a data URL."""
    im = Image.open(path).convert("RGB")
    W, H = im.size
    # The busy dive site under the sea (skip the left lift and the right panel).
    box = (int(W * 0.10), int(H * 0.16), int(W * 0.62), int(H * 0.82))
    im = im.crop(box)
    tw, th = im.size
    want = w / h
    if tw / th > want:
        nw = int(th * want)
        im = im.crop(((tw - nw) // 2, 0, (tw - nw) // 2 + nw, th))
    else:
        nh = int(tw / want)
        im = im.crop((0, (th - nh) // 2, tw, (th - nh) // 2 + nh))
    im = im.resize((w, h), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.2)
    im = ImageEnhance.Brightness(im).enhance(1.05)
    import io
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def cover_e(w, h):
    land = w > h
    k = h / 1080 if land else w / 800 * 0.8
    shot = shot_data(os.environ.get("SHOT", os.path.join(HERE, "shot_late.png")), w, h)
    extra = ('<linearGradient id="fadeL" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#062a63" stop-opacity="0.85"/>'
             '<stop offset="0.45" stop-color="#062a63" stop-opacity="0.15"/><stop offset="1" stop-color="#062a63" stop-opacity="0"/></linearGradient>'
             '<linearGradient id="fadeT" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#062a63" stop-opacity="0.8"/>'
             '<stop offset="0.3" stop-color="#062a63" stop-opacity="0"/></linearGradient>')
    body = [f'<image href="{shot}" x="0" y="0" width="{w}" height="{h}" preserveAspectRatio="none"/>',
            f'<rect width="{w}" height="{h}" fill="url(#fadeL)"/>', f'<rect width="{w}" height="{h}" fill="url(#fadeT)"/>']
    hero = sprites.diver("wow", "pick", "orange", "pick")
    if land:
        hx, hy, hs = w * 0.2, h + 30 * k, 1.0 * k
        lg = (w - min(w * 0.46, 880 * k) - 30 * k, 22 * k, min(w * 0.46, 880 * k))
        burst = (w * 0.36, h * 0.36)
    else:
        hx, hy, hs = w * 0.32, h + 20 * k, 0.8 * k
        lg = (w * 0.08, 34 * k, w * 0.84)
        burst = (w * 0.6, h * 0.42)
    body.append(f'<circle cx="{burst[0]}" cy="{burst[1]}" r="{300 * k}" fill="url(#goldGlow)"/>')
    body.append(coins_burst(burst[0], burst[1], 16, 210 * k, 21, 24 * k, 56 * k))
    body.append(place(hero, hx, hy, hs))
    body.append(logo(*lg))
    return wrap(w, h, "".join(body), sea_bg(w, h) + extra)


# ------------------------------------------------------------------ F: the crew
def gold_vein(cx, cy, s):
    """A big rock with a glowing gold vein and nuggets."""
    rock = (f'<path d="M {cx - 360 * s} {cy} C {cx - 380 * s} {cy - 260 * s}, {cx - 160 * s} {cy - 470 * s}, {cx + 40 * s} {cy - 450 * s} '
            f'C {cx + 260 * s} {cy - 430 * s}, {cx + 400 * s} {cy - 250 * s}, {cx + 370 * s} {cy} Z" fill="#4f6a8f" stroke="{INK}" stroke-width="{10 * s}"/>')
    vein = (f'<path d="M {cx - 250 * s} {cy - 40 * s} L {cx - 120 * s} {cy - 230 * s} L {cx - 40 * s} {cy - 170 * s} L {cx + 80 * s} {cy - 360 * s} '
            f'L {cx + 150 * s} {cy - 250 * s} L {cx + 260 * s} {cy - 300 * s}" fill="none" stroke="{INK}" stroke-width="{70 * s}" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="M {cx - 250 * s} {cy - 40 * s} L {cx - 120 * s} {cy - 230 * s} L {cx - 40 * s} {cy - 170 * s} L {cx + 80 * s} {cy - 360 * s} '
            f'L {cx + 150 * s} {cy - 250 * s} L {cx + 260 * s} {cy - 300 * s}" fill="none" stroke="#ffcf33" stroke-width="{50 * s}" stroke-linejoin="round" stroke-linecap="round" filter="url(#glow)"/>')
    nug = []
    rnd = random.Random(8)
    for i in range(10):
        x = cx + rnd.uniform(-280, 280) * s
        y = cy - rnd.uniform(40, 380) * s
        r = rnd.uniform(16, 30) * s
        nug.append(f'<path d="M {x - r} {y} L {x - r * 0.4} {y - r} L {x + r * 0.6} {y - r * 0.8} L {x + r} {y + r * 0.2} L {x + r * 0.2} {y + r} L {x - r * 0.8} {y + r * 0.6} Z" '
                   f'fill="#ffd84a" stroke="{INK}" stroke-width="{6 * s}" stroke-linejoin="round"/>')
    return rock + vein + "".join(nug)


def cover_f(w, h):
    land = w > h
    k = h / 1080 if land else w / 800 * 0.8
    body = [f'<rect width="{w}" height="{h}" fill="url(#seaV)"/>', light_rays(w, h, k), bubbles(18, 6, (0, 0, w, h * 0.7), k)]
    bed = h * 0.88
    vx = w * (0.62 if land else 0.55)
    vs = 1.25 * k if land else 1.0 * k
    body.append(f'<circle cx="{vx}" cy="{bed - 260 * vs}" r="{560 * vs}" fill="url(#goldGlow)"/>')
    body.append(seabed(w, h, k, bed))
    body.append(gold_vein(vx, bed + 10 * k, vs))
    # The crew around the vein, smaller further back.
    crew = [(vx - 420 * vs, bed + 20 * k, 0.5 * k, False), (vx + 430 * vs, bed + 20 * k, 0.5 * k, True)]
    for x, y, s, flip in crew:
        body.append(place(sprites.diver("happy", "pick", "orange", "pick"), x, y, s, flip=flip))
    body.append(coins_burst(vx, bed - 520 * vs, 18, 260 * vs, 31, 22 * k, 54 * k))
    hx = w * (0.2 if land else 0.24)
    hero = sprites.diver("wow", "up", "orange")
    body.append(place(hero, hx, bed + 60 * k, (0.95 if land else 0.78) * k))
    body.append(vcore.coral(w * 0.98, bed + 30 * k, 1.1 * k, flip=True))
    body.append(sparkles(12, 5, (w * 0.4, 0, w * 0.6, h * 0.7)))
    lg = (w - min(w * 0.44, 840 * k) - 34 * k, 26 * k, min(w * 0.44, 840 * k)) if land else (w * 0.08, 40 * k, w * 0.84)
    body.append(logo(*lg))
    return wrap(w, h, "".join(body), sea_bg(w, h))


MAKERS = {"D": cover_d, "E": cover_e, "F": cover_f}


def main():
    out = sys.argv[1]
    which = sys.argv[2:] or list(MAKERS)
    sizes = v2.SIZES if os.environ.get("ALL_SIZES") else {"landscape-1920x1080": v2.SIZES["landscape-1920x1080"]}
    os.makedirs(out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=2)
        for v in which:
            for name, (w, h) in sizes.items():
                path = os.path.join(out, f"cover-{v}-{name}.png")
                render(pg, MAKERS[v](w, h), w, h, path)
                print("wrote", path)
        b.close()


if __name__ == "__main__":
    main()
