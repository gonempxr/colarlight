#!/usr/bin/env python3
"""Cover variants to choose from (landscape previews), built from the
pieces in covers.py:

    python3 tools/store_art/variants.py out_dir

A  "Jackpot"   bright day sea, diver cheering next to the bursting chest
B  "Deep glow" the same moment in the dark deep: neon gold on navy
C  "Close-up"  the diver huge in front, the treasure behind, logo right
D  "Sunset"    warm pink-violet water, gold pops even more
"""
import io
import os
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vcore as covers  # noqa: E402

BASE = dict(covers.LAYOUTS["cover-landscape-1920x1080.png"][2])


def night(svg):
    swaps = [
        ('<stop offset="0" stop-color="#5fe3ef"/><stop offset="0.35" stop-color="#20a3d6"/><stop offset="0.75" stop-color="#1066ad"/><stop offset="1" stop-color="#0b3a78"/>',
         '<stop offset="0" stop-color="#2a5fa8"/><stop offset="0.35" stop-color="#16306e"/><stop offset="0.75" stop-color="#0c1a45"/><stop offset="1" stop-color="#070d2a"/>'),
        ('<stop offset="0" stop-color="#ffe2a6"/><stop offset="1" stop-color="#eab36a"/>',
         '<stop offset="0" stop-color="#5a6aa8"/><stop offset="1" stop-color="#2c3466"/>'),
        ('fill="#d9a05a" fill-opacity="0.6"', 'fill="#1e2552" fill-opacity="0.6"'),
    ]
    for a, b in swaps:
        svg = svg.replace(a, b)
    return svg


def sunset(svg):
    swaps = [
        ('<stop offset="0" stop-color="#5fe3ef"/><stop offset="0.35" stop-color="#20a3d6"/><stop offset="0.75" stop-color="#1066ad"/><stop offset="1" stop-color="#0b3a78"/>',
         '<stop offset="0" stop-color="#ffb3c8"/><stop offset="0.35" stop-color="#d7609e"/><stop offset="0.75" stop-color="#6a3a9e"/><stop offset="1" stop-color="#2f1d66"/>'),
        ('<stop offset="0" stop-color="#ffe2a6"/><stop offset="1" stop-color="#eab36a"/>',
         '<stop offset="0" stop-color="#ffd0b0"/><stop offset="1" stop-color="#d98a7a"/>'),
    ]
    for a, b in swaps:
        svg = svg.replace(a, b)
    return svg


def closeup():
    lay = dict(BASE)
    lay.update({
        "hero": (560, 1560, 1.6), "chest": (1450, 1010, 0.9), "burst": (1450, 560), "glow": 480,
        "logo": (1010, 30, 860), "coral": (1880, 1010, 1.0), "crystals": (1110, 1000, 0.8),
        "stacks": [(1790, 1030, 4, 38)], "bars": [(1150, 1040, 1.0, -6)],
        "coins": 30, "spread": 380, "near": [(60, 330, 70, 0.8, 0.4), (1000, 1040, 60, 0.9, 0.2)],
        "shafts": [(250, 90), (700, 70)],
    })
    return covers.scene(1920, 1080, lay)


VARIANTS = {
    "A-jackpot.png": lambda: covers.scene(1920, 1080, dict(BASE)),
    "B-deep-glow.png": lambda: night(covers.scene(1920, 1080, dict(BASE))),
    "C-close-up.png": closeup,
    "D-sunset.png": lambda: sunset(covers.scene(1920, 1080, dict(BASE))),
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, make in VARIANTS.items():
            svg = make()
            pg = b.new_page(viewport={"width": 1920, "height": 1080}, device_scale_factor=2)
            pg.set_content(f'<html><body style="margin:0;background:#000">{svg}</body></html>')
            pg.wait_for_timeout(300)
            png = pg.screenshot(clip={"x": 0, "y": 0, "width": 1920, "height": 1080})
            Image.open(io.BytesIO(png)).convert("RGB").resize((1920, 1080), Image.LANCZOS).save(os.path.join(out, name))
            print("wrote", name)
            pg.close()
        b.close()


if __name__ == "__main__":
    main()
