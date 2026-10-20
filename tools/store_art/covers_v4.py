#!/usr/bin/env python3
"""Cover set v4 (2026-10-20), after Basic Launch ended with a 1.1% CTR
(bottom 20%). At CrazyGames thumbnail size (about 220 px wide) the v3 hero
and logo were small. G "Close-up": the hero fills half the cover, the gold
pile glows on a deeper sea, the logo is bigger and nothing else competes.

    python3 tools/store_art/covers_v4.py out_dir
    ALL_SIZES=1 ... also portrait 800x1200 and square 800x800
"""
import os
import sys

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import covers_v2 as v2  # noqa: E402
import covers_v3 as v3  # noqa: E402
from covers_v2 import vcore, sprites, place, logo, rays, coins_burst, sparkles, wrap, render  # noqa: E402


def cover_g(w, h):
    land = w > h
    k = h / 1080 if land else w / 800 * 0.8
    sea = v3.sea_bg(w, h, top="#2fb4ee", mid="#0d5fb0", bot="#041d4a")
    body = [f'<rect width="{w}" height="{h}" fill="url(#seaV)"/>', v3.light_rays(w, h, k), v3.bubbles(14, 9, (0, 0, w, h * 0.8), k)]
    bed = h * (0.9 if land else 0.93)
    if land:
        cx, cs = w * 0.74, 1.05 * k
        hx, hy, hs = w * 0.27, h * 1.12, 1.5 * k
        lw = w * 0.5
        lg = (w - lw - 30 * k, 22 * k, lw)
    elif w == h:
        cx, cs = w * 0.76, 0.62 * k
        hx, hy, hs = w * 0.34, h * 1.16, 1.2 * k
        lg = (w * 0.06, 24 * k, w * 0.88)
    else:
        cx, cs = w * 0.74, 0.62 * k
        hx, hy, hs = w * 0.4, h * 1.04, 1.65 * k
        lg = (w * 0.05, 36 * k, w * 0.9)
    body.append(f'<circle cx="{cx}" cy="{bed - 330 * cs}" r="{640 * cs}" fill="url(#goldGlow)"/>')
    body.append(rays(cx, bed - 330 * cs, 16, 1000 * cs, "#fff3a8", 0.2, 0.1))
    body.append(v3.seabed(w, h, k, bed))
    body.append(place(vcore.chest(), cx, bed + 10 * k, cs))
    body.append(coins_burst(cx, bed - 560 * cs, 16, 300 * cs, 12, 30 * k, 66 * k))
    body.append(vcore.coral(w * 0.99, bed + 30 * k, 1.2 * k, flip=True))
    # The hero, big and cropped at the waist: the face reads at any size.
    body.append(f'<circle cx="{hx}" cy="{hy - 700 * hs}" r="{420 * hs}" fill="#7fe3ff" fill-opacity="0.18"/>')
    body.append(place(sprites.diver("wow", "up", "orange"), hx, hy, hs))
    body.append(sparkles(10, 7, (w * 0.5, h * 0.2, w * 0.5, h * 0.6)))
    body.append(logo(*lg))
    return wrap(w, h, "".join(body), sea)


def main():
    out = sys.argv[1]
    sizes = v2.SIZES if os.environ.get("ALL_SIZES") else {"landscape-1920x1080": v2.SIZES["landscape-1920x1080"]}
    os.makedirs(out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path=os.environ.get("CHROME") or None)
        pg = b.new_page(device_scale_factor=2)
        for name, (w, h) in sizes.items():
            path = os.path.join(out, f"cover-G-{name}.png")
            render(pg, cover_g(w, h), w, h, path)
            print("wrote", path)
        b.close()


if __name__ == "__main__":
    main()
