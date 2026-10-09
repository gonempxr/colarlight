#!/usr/bin/env python3
"""Variant C ("close-up") in the three CrazyGames sizes:
    python3 tools/store_art/final_c.py out_dir
"""
import io
import os
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vcore  # noqa: E402
import variants  # noqa: E402

BASE_P = dict(vcore.LAYOUTS["cover-portrait-800x1200.png"][2])
BASE_S = dict(vcore.LAYOUTS["cover-square-800x800.png"][2])


def portrait():
    lay = dict(BASE_P)
    lay.update({
        "s": 0.6, "floor": 720, "hero": (330, 1520, 0.98), "chest": (575, 735, 0.5), "burst": (575, 500), "glow": 330,
        "logo": (40, 40, 720), "coral": (770, 730, 0.55), "crystals": (395, 725, 0.45),
        "stacks": [(745, 745, 3, 22)], "bars": [], "coins": 24, "spread": 240,
        "near": [(40, 520, 44, 0.8, 0.4), (770, 1130, 50, 0.7, -0.3)], "shafts": [(60, 50), (300, 60)], "seed": 12,
    })
    return vcore.scene(800, 1200, lay)


def square():
    lay = dict(BASE_S)
    lay.update({
        "s": 0.5, "floor": 600, "hero": (245, 1060, 0.8), "chest": (600, 615, 0.42), "burst": (600, 420), "glow": 280,
        "logo": (40, 22, 600), "coral": (785, 610, 0.45), "crystals": (455, 605, 0.38),
        "stacks": [], "bars": [], "coins": 20, "spread": 190,
        "near": [(30, 380, 36, 0.8, 0.4)], "shafts": [(40, 40)], "seed": 15,
    })
    return vcore.scene(800, 800, lay)


JOBS = {
    "cover-landscape-1920x1080.png": (1920, 1080, variants.closeup),
    "cover-portrait-800x1200.png": (800, 1200, portrait),
    "cover-square-800x800.png": (800, 800, square),
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, (w, h, make) in JOBS.items():
            pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
            pg.set_content(f'<html><body style="margin:0;background:#000">{make()}</body></html>')
            pg.wait_for_timeout(300)
            png = pg.screenshot(clip={"x": 0, "y": 0, "width": w, "height": h})
            Image.open(io.BytesIO(png)).convert("RGB").resize((w, h), Image.LANCZOS).save(os.path.join(out, name))
            print("wrote", name)
            pg.close()
        b.close()


if __name__ == "__main__":
    main()
