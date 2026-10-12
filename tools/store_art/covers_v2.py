#!/usr/bin/env python3
"""Cover set v2, built to win clicks at thumbnail size: one big readable
idea per cover, strong contrast, the logo kept out of the top-left label zone.

    python3 tools/store_art/covers_v2.py out_dir [A|B|C ...]

A "Jackpot"  huge amazed diver face, gold burst, coins flying at the camera
B "0 -> rich" split: grey broke diver | golden rich diver
C "Crystal"  diver swinging into a giant glowing crystal vein in a dark cave
"""
import base64
import io
import math
import os
import random
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools", "promo_video"))
import vcore  # noqa: E402
import sprites  # noqa: E402

INK = vcore.INK
LOGO = base64.b64encode(open(os.path.join(ROOT, "game/assets/logo.svg"), "rb").read()).decode()


def defs():
    return vcore.defs((0, 0), 100).replace("</defs>", sprites.EXTRA_DEFS + "</defs>")


def place(body, x, y, s, flip=False, rot=0):
    sx = -s if flip else s
    return f'<g transform="translate({x} {y}) rotate({rot}) scale({sx} {s})">{body}</g>'


def logo(x, y, w):
    h = w * 500 / 1514
    return (f'<g filter="url(#lshadow)"><image href="data:image/svg+xml;base64,{LOGO}" x="{x}" y="{y}" width="{w}" height="{h}"/></g>')


EXTRA = '''
<filter id="lshadow" x="-10%" y="-10%" width="120%" height="140%"><feDropShadow dx="0" dy="8" stdDeviation="6" flood-color="#1a0f33" flood-opacity="0.55"/></filter>
<filter id="blur6"><feGaussianBlur stdDeviation="6"/></filter>
<filter id="blur14"><feGaussianBlur stdDeviation="14"/></filter>
<filter id="glow"><feGaussianBlur stdDeviation="18" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
'''


def rays(cx, cy, n, r, col, op, width=0.11, rot=0.0):
    out = []
    for i in range(n):
        a = rot + i * 2 * math.pi / n
        out.append(f'<path d="M {cx} {cy} L {cx + math.cos(a - width) * r:.1f} {cy + math.sin(a - width) * r:.1f} '
                   f'L {cx + math.cos(a + width) * r:.1f} {cy + math.sin(a + width) * r:.1f} Z" fill="{col}" fill-opacity="{op}"/>')
    return "".join(out)


def coins_burst(cx, cy, n, spread, seed, rmin=26, rmax=70, near=0):
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        d = spread * (0.25 + rnd.random() ** 0.7)
        x, y = cx + math.cos(a) * d * 1.3, cy + math.sin(a) * d * 0.85
        r = rnd.uniform(rmin, rmax)
        out.append(vcore.coin(x, y, r, rnd.uniform(0.3, 1.0), rnd.uniform(-1, 1)))
        if i % 4 == 0:
            out.append(vcore.gem(x + 40, y - 30, rnd.uniform(30, 48), rnd.choice(["emerald", "ruby", "crystal", "pearl"]), rnd.uniform(-0.6, 0.6)))
    for i in range(near):
        a = rnd.uniform(0, 2 * math.pi)
        x, y = cx + math.cos(a) * spread * 1.9, cy + math.sin(a) * spread * 1.2
        out.append(f'<g filter="url(#blur6)">{vcore.coin(x, y, rnd.uniform(90, 130), rnd.uniform(0.4, 1), rnd.uniform(-1, 1))}</g>')
    return "".join(out)


def sparkles(xs, seed, area):
    rnd = random.Random(seed)
    x0, y0, w, h = area
    return "".join(vcore.sparkle(x0 + rnd.random() * w, y0 + rnd.random() * h, rnd.uniform(14, 40), rnd.uniform(0.6, 1)) for _ in range(xs))


def wrap(w, h, body, extra_defs=""):
    d = defs().replace("</defs>", EXTRA + extra_defs + "</defs>")
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{d}{body}</svg>'


# ------------------------------------------------------------------ A: jackpot face
def cover_a(w, h):
    if w > h:  # landscape
        k = h / 1080
        L = dict(cx=w * 0.64, cy=h * 0.52, glow=260 * k, chest=(w * 0.64 + 330 * k, h - 40 * k, 1.05 * k),
                 stack=(w * 0.64 + 650 * k, h - 50 * k, 6, 46 * k), burst=(w * 0.64 + 150 * k, h * 0.52 - 60 * k, 26, 380 * k, 24 * k, 64 * k, 3),
                 hero=(w * 0.30, h * 0.52, 1.18 * k), shadow=330 * k, logo=(w - min(w * 0.42, 820 * k) - 40 * k, 30 * k, min(w * 0.42, 820 * k)))
    elif h > w:  # portrait 800x1200
        u = w / 800
        L = dict(cx=430 * u, cy=640 * u, glow=220 * u, chest=(590 * u, 1190 * u, 0.62 * u), stack=(760 * u, 1185 * u, 5, 34 * u),
                 burst=(500 * u, 520 * u, 22, 250 * u, 20 * u, 50 * u, 0), hero=(340 * u, 640 * u, 1.18 * u), shadow=260 * u,
                 logo=(60 * u, 110 * u, 680 * u))
    else:  # square 800x800
        u = w / 800
        L = dict(cx=540 * u, cy=420 * u, glow=200 * u, chest=(650 * u, 795 * u, 0.55 * u), stack=(775 * u, 790 * u, 4, 30 * u),
                 burst=(560 * u, 380 * u, 20, 210 * u, 18 * u, 46 * u, 0), hero=(250 * u, 420 * u, 0.8 * u), shadow=220 * u,
                 logo=(318 * u, 24 * u, 462 * u))
    cx, cy = L["cx"], L["cy"]
    bg = (f'<radialGradient id="bgA" cx="{cx}" cy="{cy}" r="{max(w, h) * 0.8}" gradientUnits="userSpaceOnUse">'
          '<stop offset="0" stop-color="#fff6c4"/><stop offset="0.22" stop-color="#ffd23f"/><stop offset="0.55" stop-color="#ff8a1e"/><stop offset="1" stop-color="#b8320f"/></radialGradient>')
    body = [f'<rect width="{w}" height="{h}" fill="url(#bgA)"/>', rays(cx, cy, 22, max(w, h) * 1.2, "#ffffff", 0.18)]
    body.append(f'<circle cx="{cx}" cy="{cy}" r="{L["glow"]}" fill="#ffffff" fill-opacity="0.35" filter="url(#blur14)"/>')
    x, y, sc = L["chest"]
    body.append(place(vcore.chest(), x, y, sc))
    body.append(vcore.coin_stack(*L["stack"]))
    bx, by, n, sp, r0, r1, near = L["burst"]
    body.append(coins_burst(bx, by, n, sp, 3, r0, r1, near=near))
    hero = sprites.diver("wow", "up", "orange")
    hx, hy, s = L["hero"]
    body.append(f'<ellipse cx="{hx}" cy="{h - 10}" rx="{L["shadow"]}" ry="{L["shadow"] * 0.15}" fill="#7a2a0a" fill-opacity="0.35"/>')
    body.append(place(hero, hx, hy + 590 * s, s))
    body.append(sparkles(16, 9, (0, 0, w, h)))
    body.append(logo(*L["logo"]))
    return wrap(w, h, "".join(body), bg)


# ------------------------------------------------------------------ B: broke -> rich
def cover_b(w, h):
    k = h / 1080
    mid = w * 0.5
    bg = ('<linearGradient id="bgL" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5d6b7d"/><stop offset="1" stop-color="#263241"/></linearGradient>'
          f'<radialGradient id="bgR" cx="{w * 0.76}" cy="{h * 0.45}" r="{w * 0.55}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff6c4"/><stop offset="0.3" stop-color="#ffd23f"/><stop offset="0.75" stop-color="#ff9a1e"/><stop offset="1" stop-color="#c24a0f"/></radialGradient>'
          f'<clipPath id="cR"><path d="M {mid + 90 * k} 0 L {w} 0 L {w} {h} L {mid - 90 * k} {h} Z"/></clipPath>'
          f'<clipPath id="cL"><path d="M 0 0 L {mid + 90 * k} 0 L {mid - 90 * k} {h} L 0 {h} Z"/></clipPath>')
    body = []
    # left: grey, broke
    left = [f'<rect width="{w}" height="{h}" fill="url(#bgL)"/>']
    left.append(f'<path d="M 0 {h * 0.86} Q {w * 0.25} {h * 0.8} {mid} {h * 0.86} L {mid} {h} L 0 {h} Z" fill="#8a8378" stroke="{INK}" stroke-width="8"/>')
    for i in range(10):
        left.append(vcore.bubble(60 * k + i * 70 * k, h * 0.2 + (i * 97 % 400) * k, (10 + i % 4 * 6) * k))
    poor = sprites.diver("sad", "down", "poor", "bucket")
    sp = 0.78 * k
    left.append(place(poor, w * 0.24, h * 0.9, sp))
    body.append(f'<g clip-path="url(#cL)">{"".join(left)}</g>')
    # right: gold, rich
    right = [f'<rect width="{w}" height="{h}" fill="url(#bgR)"/>', rays(w * 0.76, h * 0.45, 20, w, "#ffffff", 0.2)]
    right.append(place(vcore.chest(), w * 0.88, h * 0.98, 0.78 * k))
    right.append(coins_burst(w * 0.8, h * 0.55, 20, 260 * k, 5, 22 * k, 58 * k))
    rich = sprites.diver("wow", "up", "gold")
    right.append(place(rich, w * 0.68, h * 0.97, 0.86 * k))
    right.append(sparkles(12, 4, (mid, 0, w - mid, h)))
    body.append(f'<g clip-path="url(#cR)">{"".join(right)}</g>')
    # the split: a bright zig-zag
    zz = f'M {mid + 90 * k} 0 L {mid + 20 * k} {h * 0.42} L {mid + 70 * k} {h * 0.5} L {mid - 90 * k} {h}'
    body.append(f'<path d="{zz}" fill="none" stroke="#ffffff" stroke-width="{30 * k}" stroke-linejoin="round" filter="url(#glow)"/>')
    body.append(f'<path d="{zz}" fill="none" stroke="{INK}" stroke-width="{10 * k}" stroke-linejoin="round"/>')
    # arrow badge in the middle
    ax, ay = mid + 45 * k, h * 0.46
    body.append(f'<circle cx="{ax}" cy="{ay}" r="{70 * k}" fill="#4cd964" stroke="{INK}" stroke-width="{9 * k}"/>')
    body.append(f'<path d="M {ax - 30 * k} {ay - 8 * k} L {ax + 6 * k} {ay - 8 * k} L {ax + 6 * k} {ay - 32 * k} L {ax + 40 * k} {ay} L {ax + 6 * k} {ay + 32 * k} L {ax + 6 * k} {ay + 8 * k} L {ax - 30 * k} {ay + 8 * k} Z" fill="#ffffff" stroke="{INK}" stroke-width="{6 * k}" stroke-linejoin="round"/>')
    lw = min(w * 0.4, 760 * k)
    body.append(logo(w - lw - 36 * k, 26 * k, lw))
    return wrap(w, h, "".join(body), bg)


# ------------------------------------------------------------------ C: crystal vein
def cover_c(w, h):
    k = h / 1080
    vx, vy = w * 0.68, h * 0.55
    bg = ('<linearGradient id="bgC" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b2a6b"/><stop offset="1" stop-color="#0a0f2e"/></linearGradient>'
          f'<radialGradient id="gC" cx="{vx}" cy="{vy}" r="{520 * k}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#9ff3ff" stop-opacity="0.9"/><stop offset="0.4" stop-color="#7a5cff" stop-opacity="0.45"/><stop offset="1" stop-color="#7a5cff" stop-opacity="0"/></radialGradient>'
          '<linearGradient id="cry1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#8ff0ff"/><stop offset="1" stop-color="#2a7be0"/></linearGradient>'
          '<linearGradient id="cry2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#ff9ad5"/><stop offset="1" stop-color="#c22a8a"/></linearGradient>'
          '<linearGradient id="cry3" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fffbe0"/><stop offset="0.35" stop-color="#ffd23f"/><stop offset="1" stop-color="#e0780f"/></linearGradient>')
    body = [f'<rect width="{w}" height="{h}" fill="url(#bgC)"/>']
    # cave walls
    body.append(f'<path d="M 0 0 L {w} 0 L {w} {h * 0.12} Q {w * 0.7} {h * 0.2} {w * 0.5} {h * 0.1} Q {w * 0.3} {h * 0.02} 0 {h * 0.16} Z" fill="#2c1f4a" stroke="{INK}" stroke-width="8"/>')
    body.append(f'<path d="M 0 {h * 0.84} Q {w * 0.3} {h * 0.78} {w * 0.55} {h * 0.84} T {w} {h * 0.8} L {w} {h} L 0 {h} Z" fill="#3a2a5e" stroke="{INK}" stroke-width="8"/>')
    body.append(f'<circle cx="{vx}" cy="{vy}" r="{520 * k}" fill="url(#gC)"/>')
    body.append(rays(vx, vy, 16, 900 * k, "#bff6ff", 0.12, 0.07))
    # giant crystals fanning out
    rnd = random.Random(2)
    cr = []
    for i, (a, L, wd, g) in enumerate([(-1.75, 520, 120, "cry1"), (-1.25, 430, 100, "cry2"), (-2.25, 400, 96, "cry3"),
                                        (-0.8, 330, 84, "cry1"), (-2.7, 300, 80, "cry2"), (-1.5, 250, 70, "cry3"), (-0.35, 250, 72, "cry2")]):
        L, wd = L * k, wd * k
        ca, sa = math.cos(a), math.sin(a)
        px, py = -sa, ca
        bx, by = vx + ca * 40 * k, vy + 160 * k + sa * 40 * k
        tip = (bx + ca * L, by + sa * L)
        p1 = (bx + px * wd / 2, by + py * wd / 2)
        p2 = (bx - px * wd / 2, by - py * wd / 2)
        q1 = (p1[0] + ca * L * 0.78, p1[1] + sa * L * 0.78)
        q2 = (p2[0] + ca * L * 0.78, p2[1] + sa * L * 0.78)
        pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in (p1, q1, tip, q2, p2))
        cr.append(f'<polygon points="{pts}" fill="url(#{g})" stroke="{INK}" stroke-width="{8 * k}" stroke-linejoin="round"/>')
        cr.append(f'<path d="M {(p1[0] + bx) / 2:.1f} {(p1[1] + by) / 2:.1f} L {(q1[0] + tip[0]) / 2:.1f} {(q1[1] + tip[1]) / 2:.1f}" stroke="#ffffff" stroke-opacity="0.7" stroke-width="{10 * k}" stroke-linecap="round"/>')
    body.append(f'<g filter="url(#glow)">{"".join(cr)}</g>')
    body.append(f'<ellipse cx="{vx}" cy="{vy + 190 * k}" rx="{260 * k}" ry="{70 * k}" fill="#4a3a6e" stroke="{INK}" stroke-width="8"/>')
    # gems spilling
    for i in range(9):
        body.append(vcore.gem(vx - 260 * k + i * 62 * k, vy + 190 * k - (i % 3) * 18 * k, (34 + (i * 7) % 18) * k, ["emerald", "ruby", "crystal", "pearl"][i % 4], (i - 4) * 0.2))
    # hero swinging into the vein
    hero = sprites.diver("wow", "pick", "orange", "pick")
    s = 0.92 * k
    hx, hy = w * 0.26 + 190 * k, h * 0.93
    body.append(place(hero, hx, hy, s))
    # impact burst at the pick head
    ix, iy = hx + 264 * s + 150 * s, hy - 608 * s - 160 * s
    body.append(f'<g filter="url(#glow)">{vcore.sparkle(ix, iy, 120 * k)}{vcore.sparkle(ix + 40 * k, iy + 30 * k, 60 * k)}</g>')
    for i in range(10):
        a = -0.9 + i * 0.2
        body.append(vcore.gem(ix + math.cos(a) * (120 + i * 18) * k, iy + math.sin(a) * (110 + i * 10) * k, (18 + i % 3 * 8) * k, ["crystal", "ruby", "emerald"][i % 3], a))
    body.append(sparkles(18, 7, (0, 0, w, h * 0.8)))
    lw = min(w * 0.42, 800 * k)
    body.append(logo(w - lw - 40 * k, 28 * k, lw))
    return wrap(w, h, "".join(body), bg)


MAKERS = {"A": cover_a, "B": cover_b, "C": cover_c}
SIZES = {"landscape-1920x1080": (1920, 1080), "portrait-800x1200": (800, 1200), "square-800x800": (800, 800)}


def render(pg, svg, w, h, path):
    pg.set_viewport_size({"width": w, "height": h})
    pg.set_content(f'<html><body style="margin:0;background:#000">{svg}</body></html>')
    pg.wait_for_timeout(400)
    png = pg.screenshot(clip={"x": 0, "y": 0, "width": w, "height": h})
    Image.open(io.BytesIO(png)).convert("RGB").resize((w, h), Image.LANCZOS).save(path)


def main():
    out = sys.argv[1]
    which = sys.argv[2:] or list(MAKERS)
    sizes = SIZES if os.environ.get("ALL_SIZES") else {"landscape-1920x1080": SIZES["landscape-1920x1080"]}
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
