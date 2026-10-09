#!/usr/bin/env python3
"""Store covers for Coralight as clean vector art (smooth curves, even
outlines), rendered by Chromium at 2x and scaled down for soft edges.

    python3 tools/store_art/covers.py [out_dir]     # default docs/store

Writes cover-landscape-1920x1080.png, cover-portrait-800x1200.png and
cover-square-800x800.png (CrazyGames sizes; only the title as text).
The scene: a star-eyed diver cheering next to a chest that bursts with
coins and gems, a warm burst of light, the logo.
"""
import base64
import io
import math
import os
import random
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOGO = os.path.join(ROOT, "game", "assets", "logo.svg")

INK = "#241a3a"
W = 7  # outline width at banner scale


def f(x):
    return ("%.1f" % x).rstrip("0").rstrip(".")


# --- the diver (feet at 0,0; about 750 tall) ----------------------------

def diver():
    s = []
    # Air tank behind the back.
    s.append(f'<rect x="-170" y="-470" width="90" height="250" rx="40" fill="url(#tank)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<rect x="-170" y="-395" width="90" height="26" fill="#ef5a5a" stroke="{INK}" stroke-width="5"/>')
    # Arms up (ink tube, then the suit tube).
    arms = ["M -100 -390 C -170 -420, -230 -470, -262 -540", "M 100 -390 C 170 -460, 220 -620, 236 -790"]
    for a in arms:
        s.append(f'<path d="{a}" fill="none" stroke="{INK}" stroke-width="80" stroke-linecap="round"/>')
    for a in arms:
        s.append(f'<path d="{a}" fill="none" stroke="url(#suitArm)" stroke-width="64" stroke-linecap="round"/>')
    # Legs and boots.
    for x in (-92, 14):
        s.append(f'<rect x="{x}" y="-215" width="78" height="170" rx="30" fill="#f07a2a" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<path d="M -118 -70 h 102 a 14 14 0 0 1 14 14 v 42 a 14 14 0 0 1 -14 14 h -96 a 26 26 0 0 1 -26 -26 v -18 a 26 26 0 0 1 26 -26 z" fill="#323a5c" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<path d="M 4 -70 h 96 a 40 40 0 0 1 40 40 v 16 a 14 14 0 0 1 -14 14 h -122 a 14 14 0 0 1 -14 -14 v -42 a 14 14 0 0 1 14 -14 z" fill="#323a5c" stroke="{INK}" stroke-width="{W}"/>')
    # Torso.
    s.append(f'<rect x="-128" y="-440" width="256" height="270" rx="78" fill="url(#suit)" stroke="{INK}" stroke-width="{W}"/>')
    s.append('<path d="M -96 -400 C -110 -330, -100 -260, -70 -215" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="14" stroke-linecap="round"/>')
    # Belt and buckle.
    s.append(f'<rect x="-131" y="-258" width="262" height="42" rx="12" fill="#6b3f22" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<rect x="-28" y="-266" width="56" height="58" rx="12" fill="url(#gold)" stroke="{INK}" stroke-width="6"/>')
    s.append('<rect x="-12" y="-250" width="24" height="26" rx="5" fill="#b9741c"/>')
    # Gloves.
    for x, y in ((-262, -548), (238, -800)):
        s.append(f'<circle cx="{x}" cy="{y}" r="50" fill="url(#glove)" stroke="{INK}" stroke-width="{W}"/>')
        s.append(f'<path d="M {x - 26} {y - 20} a 30 30 0 0 1 22 -20" fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="9" stroke-linecap="round"/>')
    # Brass collar.
    s.append(f'<ellipse cx="0" cy="-430" rx="148" ry="50" fill="url(#brass)" stroke="{INK}" stroke-width="{W}"/>')
    for i in range(6):
        a = math.pi * (0.12 + 0.76 * i / 5)
        s.append(f'<circle cx="{f(-math.cos(a) * 118)}" cy="{f(-430 + math.sin(a) * 30)}" r="7" fill="#8a5414"/>')
    # Helmet: dome, top valve, side ports, rivets.
    hy = -590
    s.append(f'<rect x="-42" y="{hy - 212}" width="84" height="56" rx="16" fill="url(#brass)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<circle cx="-172" cy="{hy + 6}" r="42" fill="url(#brass)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<circle cx="172" cy="{hy + 6}" r="42" fill="url(#brass)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<circle cx="-172" cy="{hy + 6}" r="20" fill="#a8d8ea" stroke="{INK}" stroke-width="5"/>')
    s.append(f'<circle cx="172" cy="{hy + 6}" r="20" fill="#a8d8ea" stroke="{INK}" stroke-width="5"/>')
    s.append(f'<circle cx="0" cy="{hy}" r="172" fill="url(#brassDome)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<path d="M -120 {hy - 95} A 150 150 0 0 1 40 {hy - 160}" fill="none" stroke="#fff6d0" stroke-opacity="0.7" stroke-width="16" stroke-linecap="round"/>')
    s.append(f'<circle cx="0" cy="{hy + 8}" r="124" fill="url(#brassDark)" stroke="{INK}" stroke-width="{W}"/>')
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        s.append(f'<circle cx="{f(math.cos(a) * 109)}" cy="{f(hy + 8 + math.sin(a) * 109)}" r="8" fill="#7a4710"/>')
    # Glass and face.
    gy = hy + 10
    s.append(f'<circle cx="0" cy="{gy}" r="96" fill="url(#glass)" stroke="{INK}" stroke-width="6"/>')
    s.append(f'<clipPath id="glassClip"><circle cx="0" cy="{gy}" r="93"/></clipPath>')
    s.append('<g clip-path="url(#glassClip)">')
    s.append(f'<ellipse cx="0" cy="{gy + 12}" rx="84" ry="86" fill="url(#skin)"/>')
    s.append(f'<path d="M -84 {gy - 30} C -60 {gy - 92}, 60 {gy - 92}, 84 {gy - 30} C 50 {gy - 58}, -50 {gy - 58}, -84 {gy - 30} Z" fill="#6b3f22"/>')
    # Star eyes.
    for ex in (-34, 34):
        s.append(f'<path d="{star_path(ex, gy - 4, 27, 12)}" fill="url(#starEye)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        s.append(f'<circle cx="{ex - 7}" cy="{gy - 11}" r="4.5" fill="#ffffff"/>')
    # Blush.
    for bx in (-58, 58):
        s.append(f'<ellipse cx="{bx}" cy="{gy + 28}" rx="15" ry="9" fill="#ff7f96" fill-opacity="0.55"/>')
    # Big open smile with a tongue.
    my = gy + 26
    s.append(f'<path d="M -32 {my} Q 0 {my + 6} 32 {my} Q 28 {my + 44} 0 {my + 46} Q -28 {my + 44} -32 {my} Z" fill="#7a2335" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<path d="M -16 {my + 36} Q 0 {my + 22} 16 {my + 36} Q 10 {my + 44} 0 {my + 44} Q -10 {my + 44} -16 {my + 36} Z" fill="#ff8a8a"/>')
    s.append(f'<path d="M -24 {my + 4} Q 0 {my + 9} 24 {my + 4} L 22 {my + 11} Q 0 {my + 15} -22 {my + 11} Z" fill="#ffffff"/>')
    s.append('</g>')
    # Glass shine.
    s.append(f'<path d="M -70 {gy - 30} A 80 80 0 0 1 -20 {gy - 80}" fill="none" stroke="#ffffff" stroke-opacity="0.75" stroke-width="12" stroke-linecap="round"/>')
    s.append(f'<circle cx="-62" cy="{gy - 2}" r="6" fill="#ffffff" fill-opacity="0.75"/>')
    return "".join(s)


def star_path(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = rot + math.pi * i / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    # Rounded star: quadratic corners through each point.
    d = []
    m = len(pts)
    for i in range(m):
        p0 = pts[i - 1]
        p1 = pts[i]
        p2 = pts[(i + 1) % m]
        a = (p1[0] + (p0[0] - p1[0]) * 0.18, p1[1] + (p0[1] - p1[1]) * 0.18)
        b = (p1[0] + (p2[0] - p1[0]) * 0.18, p1[1] + (p2[1] - p1[1]) * 0.18)
        d.append(("M" if i == 0 else "L") + f" {f(a[0])} {f(a[1])} Q {f(p1[0])} {f(p1[1])} {f(b[0])} {f(b[1])}")
    return " ".join(d) + " Z"


# --- the chest (bottom center at 0,0; 600 wide) --------------------------

def chest():
    s = []
    # Open lid, tipped back.
    s.append(f'<path d="M -262 -330 L -236 -500 Q -232 -520 -212 -522 L 212 -522 Q 232 -520 236 -500 L 262 -330 Z" fill="url(#woodDark)" stroke="{INK}" stroke-width="{W}" stroke-linejoin="round"/>')
    for x in (-175, 125):
        s.append(f'<path d="M {x} -330 L {x + 6} -522 L {x + 50} -522 L {x + 50} -330 Z" fill="url(#gold)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')
    s.append('<path d="M -220 -500 L 220 -500" stroke="#ffffff" stroke-opacity="0.18" stroke-width="10" stroke-linecap="round"/>')
    # Gold heap with coins on it.
    s.append(f'<path d="M -300 -300 C -282 -420, -150 -478, 0 -478 C 150 -478, 282 -420, 300 -300 Z" fill="url(#heap)" stroke="{INK}" stroke-width="{W}" stroke-linejoin="round"/>')
    rnd = random.Random(3)
    tops = []
    for i in range(13):
        x = -250 + i * 41.5 + rnd.uniform(-8, 8)
        y = -478 + (x / 300) ** 2 * 175 + rnd.uniform(-6, 10)
        tops.append((x, y))
    for x, y in sorted(tops, key=lambda t: t[1]):
        s.append(heap_coin(x, y, rnd.uniform(28, 36), rnd.uniform(-0.25, 0.25)))
    for i in range(9):
        x = rnd.uniform(-220, 220)
        y = rnd.uniform(-430 + (x / 300) ** 2 * 120, -335)
        s.append(heap_coin(x, y, rnd.uniform(24, 30), rnd.uniform(-0.3, 0.3)))
    s.append('<ellipse cx="-70" cy="-430" rx="60" ry="16" fill="#ffffff" fill-opacity="0.45" transform="rotate(-8 -70 -430)"/>')
    # Box.
    s.append(f'<rect x="-290" y="-330" width="580" height="330" rx="30" fill="url(#wood)" stroke="{INK}" stroke-width="{W}"/>')
    for y in (-245, -160, -80):
        s.append(f'<path d="M -270 {y} L 270 {y}" stroke="#8a4f24" stroke-opacity="0.55" stroke-width="6" stroke-linecap="round"/>')
    s.append(f'<rect x="-305" y="-345" width="610" height="52" rx="18" fill="url(#gold)" stroke="{INK}" stroke-width="{W}"/>')
    for x in (-215, 155):
        s.append(f'<rect x="{x}" y="-300" width="60" height="300" rx="10" fill="url(#gold)" stroke="{INK}" stroke-width="6"/>')
        s.append(f'<rect x="{x + 10}" y="-290" width="12" height="270" rx="6" fill="#ffffff" fill-opacity="0.4"/>')
    # Lock plate.
    s.append(f'<rect x="-62" y="-280" width="124" height="128" rx="24" fill="url(#gold)" stroke="{INK}" stroke-width="{W}"/>')
    s.append(f'<circle cx="0" cy="-226" r="15" fill="{INK}"/>')
    s.append(f'<path d="M -8 -220 L 8 -220 L 12 -184 L -12 -184 Z" fill="{INK}"/>')
    s.append('<rect x="-48" y="-270" width="34" height="10" rx="5" fill="#ffffff" fill-opacity="0.55"/>')
    return "".join(s)


def coin(x, y, r, turn, rot, flat=False):
    """A gold coin seen at an angle (turn 0..1 squashes it)."""
    rx = r if flat else r * max(0.22, turn)
    ry = r * 0.42 if flat else r
    rimw = max(3.0, r * 0.12)
    deg = math.degrees(rot)
    edge = ""
    if not flat and turn < 0.85:
        edge = f'<ellipse cx="{f(r * 0.10)}" cy="0" rx="{f(rx)}" ry="{f(ry)}" fill="#c27a12" stroke="{INK}" stroke-width="5"/>'
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(deg)})">{edge}'
            f'<ellipse cx="0" cy="0" rx="{f(rx)}" ry="{f(ry)}" fill="url(#coin)" stroke="{INK}" stroke-width="5"/>'
            f'<ellipse cx="0" cy="0" rx="{f(rx * 0.68)}" ry="{f(ry * 0.68)}" fill="none" stroke="#d98e12" stroke-width="{f(rimw)}"/>'
            f'<ellipse cx="{f(-rx * 0.35)}" cy="{f(-ry * 0.38)}" rx="{f(max(2.5, rx * 0.18))}" ry="{f(ry * 0.16)}" fill="#ffffff" fill-opacity="0.9"/></g>')


def heap_coin(x, y, r, rot):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(math.degrees(rot))})">'
            f'<ellipse cx="0" cy="5" rx="{f(r)}" ry="{f(r * 0.42)}" fill="#d48a12" stroke="{INK}" stroke-width="5"/>'
            f'<ellipse cx="0" cy="0" rx="{f(r)}" ry="{f(r * 0.42)}" fill="url(#coin)" stroke="{INK}" stroke-width="5"/>'
            f'<ellipse cx="0" cy="0" rx="{f(r * 0.66)}" ry="{f(r * 0.26)}" fill="none" stroke="#e09a18" stroke-width="4"/>'
            f'<ellipse cx="{f(-r * 0.4)}" cy="{f(-r * 0.12)}" rx="{f(r * 0.18)}" ry="{f(r * 0.07)}" fill="#ffffff" fill-opacity="0.9"/></g>')


def coin_stack(x, y, n, r):
    s = []
    for i in range(n):
        cy = y - i * r * 0.32
        s.append(f'<ellipse cx="{f(x)}" cy="{f(cy + r * 0.1)}" rx="{f(r)}" ry="{f(r * 0.36)}" fill="#d98e12" stroke="{INK}" stroke-width="5"/>')
        s.append(f'<ellipse cx="{f(x)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.36)}" fill="url(#coin)" stroke="{INK}" stroke-width="5"/>')
    top = y - (n - 1) * r * 0.32
    s.append(f'<ellipse cx="{f(x)}" cy="{f(top)}" rx="{f(r * 0.62)}" ry="{f(r * 0.2)}" fill="none" stroke="#d98e12" stroke-width="4"/>')
    return "".join(s)


def gold_bar(x, y, sc, rot):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({rot}) scale({sc})">'
            f'<path d="M -60 0 L -42 -38 L 42 -38 L 60 0 Z" fill="url(#gold)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
            f'<path d="M -42 -38 L 42 -38 L 34 -48 L -34 -48 Z" fill="#ffe28a" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
            f'<path d="M -30 -12 L 30 -12" stroke="#c27a12" stroke-width="6" stroke-linecap="round"/></g>')


def gem(x, y, size, kind, rot):
    deg = math.degrees(rot)
    g = f'<g transform="translate({f(x)} {f(y)}) rotate({f(deg)}) scale({f(size / 40)})">'
    if kind == "emerald":
        g += (f'<path d="M -22 -30 L 22 -30 L 34 -10 L 0 34 L -34 -10 Z" fill="url(#emerald)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
              f'<path d="M -34 -10 L 34 -10 M -12 -30 L -16 -10 L 0 34 L 16 -10 L 12 -30" fill="none" stroke="#0e7a4f" stroke-width="3.5" stroke-linejoin="round"/>'
              '<path d="M -18 -24 L -6 -24 L -10 -14 Z" fill="#ffffff" fill-opacity="0.8"/>')
    elif kind == "crystal":
        g += (f'<path d="M 0 -44 L 18 -22 L 14 36 L -14 36 L -18 -22 Z" fill="url(#crystal)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
              '<path d="M 0 -44 L 0 36" stroke="#5b3fc4" stroke-width="3.5"/>'
              '<path d="M -10 -20 L -8 22" stroke="#ffffff" stroke-opacity="0.7" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "ruby":
        g += (f'<path d="M -30 -14 L -16 -32 L 16 -32 L 30 -14 L 0 30 Z" fill="url(#ruby)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
              f'<path d="M -30 -14 L 30 -14 M -8 -32 L -12 -14 L 0 30 L 12 -14 L 8 -32" fill="none" stroke="#a3122f" stroke-width="3.5" stroke-linejoin="round"/>'
              '<path d="M -14 -26 L -4 -26 L -8 -18 Z" fill="#ffffff" fill-opacity="0.8"/>')
    else:  # pearl
        g += (f'<circle cx="0" cy="0" r="26" fill="url(#pearl)" stroke="{INK}" stroke-width="6"/>'
              '<circle cx="-9" cy="-9" r="7" fill="#ffffff"/>')
    return g + "</g>"


def sparkle(x, y, r, op=1.0):
    d = (f"M {f(x)} {f(y - r)} Q {f(x + r * 0.12)} {f(y - r * 0.12)} {f(x + r)} {f(y)} "
         f"Q {f(x + r * 0.12)} {f(y + r * 0.12)} {f(x)} {f(y + r)} Q {f(x - r * 0.12)} {f(y + r * 0.12)} {f(x - r)} {f(y)} "
         f"Q {f(x - r * 0.12)} {f(y - r * 0.12)} {f(x)} {f(y - r)} Z")
    return f'<path d="{d}" fill="#fffbe6" fill-opacity="{op}"/>'


def bubble(x, y, r):
    return (f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#e6fbff" fill-opacity="0.14" stroke="#ffffff" stroke-opacity="0.8" stroke-width="{f(max(2.5, r * 0.12))}"/>'
            f'<circle cx="{f(x - r * 0.38)}" cy="{f(y - r * 0.38)}" r="{f(r * 0.22)}" fill="#ffffff" fill-opacity="0.9"/>')


def coral(x, y, sc, flip=False):
    branches = ["M 0 0 C -5 -60, -10 -110, -40 -170", "M -14 -80 C -50 -100, -80 -120, -96 -160",
                "M -4 -40 C 30 -70, 52 -110, 58 -160", "M 40 -110 C 70 -120, 90 -140, 100 -170",
                "M -40 -170 C -44 -190, -40 -205, -30 -215"]
    tips = [(-30, -215), (-96, -160), (58, -160), (100, -170), (-40, -170)]
    t = f'translate({f(x)} {f(y)}) scale({f(-sc if flip else sc)} {f(sc)})'
    g = [f'<g transform="{t}">']
    for b in branches:
        g.append(f'<path d="{b}" fill="none" stroke="{INK}" stroke-width="34" stroke-linecap="round"/>')
    for b in branches:
        g.append(f'<path d="{b}" fill="none" stroke="#ff5f7e" stroke-width="22" stroke-linecap="round"/>')
    for tx, ty in tips:
        g.append(f'<circle cx="{tx}" cy="{ty}" r="17" fill="#ffb15e" stroke="{INK}" stroke-width="6"/>')
    g.append("</g>")
    return "".join(g)


def crystals(x, y, sc):
    g = [f'<g transform="translate({f(x)} {f(y)}) scale({f(sc)})">']
    for cx, h, w, rot, fill in ((-60, 150, 46, -14, "#b9a6ff"), (40, 120, 42, 16, "#d8ccff"), (-8, 220, 58, 2, "#9b7cff")):
        g.append(f'<g transform="translate({cx} 0) rotate({rot})">'
                 f'<path d="M {-w / 2} 0 L {-w / 2} {-h + w * 0.6} L 0 {-h} L {w / 2} {-h + w * 0.6} L {w / 2} 0 Z" fill="{fill}" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
                 f'<path d="M 0 {-h} L 0 0" stroke="#6a4fd6" stroke-width="4"/>'
                 f'<path d="M {-w / 4} {-h + w * 0.8} L {-w / 4} -14" stroke="#ffffff" stroke-opacity="0.65" stroke-width="7" stroke-linecap="round"/></g>')
    g.append("</g>")
    return "".join(g)


def defs(burst, ray_r):
    bx, by = burst
    return f'''<defs>
<radialGradient id="sea" cx="{f(bx)}" cy="{f(by)}" r="{f(ray_r)}" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#5fe3ef"/><stop offset="0.35" stop-color="#20a3d6"/><stop offset="0.75" stop-color="#1066ad"/><stop offset="1" stop-color="#0b3a78"/></radialGradient>
<radialGradient id="ray" cx="{f(bx)}" cy="{f(by)}" r="{f(ray_r)}" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#fff6c8" stop-opacity="0.55"/><stop offset="0.6" stop-color="#ffffff" stop-opacity="0.10"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>
<radialGradient id="glowGold" cx="0.5" cy="0.5" r="0.5">
  <stop offset="0" stop-color="#fff3b0" stop-opacity="0.95"/><stop offset="0.35" stop-color="#ffd25a" stop-opacity="0.55"/><stop offset="1" stop-color="#ffb02e" stop-opacity="0"/></radialGradient>
<radialGradient id="vignette" cx="0.5" cy="0.45" r="0.75">
  <stop offset="0.55" stop-color="#06204a" stop-opacity="0"/><stop offset="1" stop-color="#06204a" stop-opacity="0.55"/></radialGradient>
<linearGradient id="shaft" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.32"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>
<linearGradient id="sand" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe2a6"/><stop offset="1" stop-color="#eab36a"/></linearGradient>
<linearGradient id="suit" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffa04a"/><stop offset="0.6" stop-color="#f6812c"/><stop offset="1" stop-color="#d9601c"/></linearGradient>
<linearGradient id="suitArm" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff9a44"/><stop offset="1" stop-color="#ea6f22"/></linearGradient>
<linearGradient id="tank" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#f4f6fb"/><stop offset="1" stop-color="#aeb6c8"/></linearGradient>
<radialGradient id="glove" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#5d6488"/><stop offset="1" stop-color="#2e3352"/></radialGradient>
<linearGradient id="brass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd677"/><stop offset="1" stop-color="#d48f25"/></linearGradient>
<radialGradient id="brassDome" cx="0.35" cy="0.28" r="0.8"><stop offset="0" stop-color="#ffe7a0"/><stop offset="0.45" stop-color="#f6b543"/><stop offset="1" stop-color="#c47a1a"/></radialGradient>
<radialGradient id="brassDark" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="#e8a23a"/><stop offset="1" stop-color="#b06a14"/></radialGradient>
<radialGradient id="glass" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#e8fbff"/><stop offset="1" stop-color="#8fd3ea"/></radialGradient>
<radialGradient id="skin" cx="0.45" cy="0.4" r="0.7"><stop offset="0" stop-color="#ffe6cf"/><stop offset="1" stop-color="#ffc9a3"/></radialGradient>
<radialGradient id="starEye" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#fff3a0"/><stop offset="1" stop-color="#ffb81c"/></radialGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe680"/><stop offset="1" stop-color="#f2a91c"/></linearGradient>
<radialGradient id="coin" cx="0.38" cy="0.32" r="0.75"><stop offset="0" stop-color="#fff2a8"/><stop offset="0.55" stop-color="#ffcc33"/><stop offset="1" stop-color="#eda114"/></radialGradient>
<radialGradient id="heap" cx="0.4" cy="0.2" r="0.9"><stop offset="0" stop-color="#fff0a0"/><stop offset="0.5" stop-color="#ffcf3a"/><stop offset="1" stop-color="#e9a015"/></radialGradient>
<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d98e4a"/><stop offset="1" stop-color="#a8622c"/></linearGradient>
<linearGradient id="woodDark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a4f24"/><stop offset="1" stop-color="#b06a32"/></linearGradient>
<linearGradient id="emerald" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8affc8"/><stop offset="1" stop-color="#16b06e"/></linearGradient>
<linearGradient id="crystal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e2d6ff"/><stop offset="1" stop-color="#8a63ff"/></linearGradient>
<linearGradient id="ruby" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff9fb2"/><stop offset="1" stop-color="#e0244d"/></linearGradient>
<radialGradient id="pearl" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d6dcf5"/></radialGradient>
</defs>'''


def scene(w, h, lay):
    burst = lay["burst"]
    ray_r = math.hypot(w, h) * 1.1
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">', defs(burst, ray_r)]
    out.append(f'<rect width="{w}" height="{h}" fill="url(#sea)"/>')
    # Sunburst.
    n = 24
    bx, by = burst
    rays = []
    for i in range(n):
        a = math.tau * i / n + 0.06
        da = math.pi / n * 0.52
        p1 = (bx + math.cos(a - da) * ray_r, by + math.sin(a - da) * ray_r)
        p2 = (bx + math.cos(a + da) * ray_r, by + math.sin(a + da) * ray_r)
        rays.append(f"M {f(bx)} {f(by)} L {f(p1[0])} {f(p1[1])} L {f(p2[0])} {f(p2[1])} Z")
    out.append(f'<path d="{" ".join(rays)}" fill="url(#ray)"/>')
    # Light shafts from the surface.
    for i, (x0, wd) in enumerate(lay.get("shafts", [])):
        out.append(f'<path d="M {f(x0)} -10 L {f(x0 + wd)} -10 L {f(x0 + wd * 3.2 + h * 0.25)} {f(h * 0.85)} L {f(x0 + wd * 1.4 + h * 0.25)} {f(h * 0.85)} Z" fill="url(#shaft)"/>')
    # Distant bubbles.
    rnd = random.Random(9)
    for i in range(lay.get("bubbles", 10)):
        x = rnd.uniform(0.05, 0.95) * w
        y = rnd.uniform(0.05, 0.75) * h
        if math.hypot(x - lay["logo"][0] - lay["logo"][2] / 2, y - lay["logo"][1] - lay["logo"][2] * 0.16) < lay["logo"][2] * 0.45:
            continue
        out.append(bubble(x, y, rnd.uniform(6, 16) * lay["s"]))
    # Warm glow behind the treasure.
    gr = lay["glow"]
    out.append(f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(gr)}" fill="url(#glowGold)"/>')
    # Seabed.
    fy = lay["floor"]
    sand = f"M -20 {f(fy + 30 * lay['s'])} C {f(w * 0.2)} {f(fy - 20 * lay['s'])}, {f(w * 0.45)} {f(fy + 25 * lay['s'])}, {f(w * 0.62)} {f(fy)} S {f(w * 0.9)} {f(fy - 25 * lay['s'])}, {f(w + 20)} {f(fy + 5 * lay['s'])} L {w + 20} {h + 20} L -20 {h + 20} Z"
    out.append(f'<path d="{sand}" fill="url(#sand)" stroke="{INK}" stroke-width="{f(W * lay["s"])}"/>')
    for i in range(14):
        x = rnd.uniform(0, w)
        y = rnd.uniform(fy + 50 * lay["s"], h - 10)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rnd.uniform(6, 14) * lay["s"])}" ry="{f(rnd.uniform(3, 6) * lay["s"])}" fill="#d9a05a" fill-opacity="0.6"/>')
    # Corner props.
    cx, cy, cs = lay["coral"]
    out.append(coral(cx, cy, cs))
    if "coral2" in lay:
        out.append(coral(*lay["coral2"], flip=True))
    kx, ky, ks = lay["crystals"]
    out.append(crystals(kx, ky, ks))
    # Chest and its spill.
    chx, chy, chs = lay["chest"]
    out.append(f'<g transform="translate({f(chx)} {f(chy)}) scale({f(chs)})">{chest()}</g>')
    for (x, y, n, r) in lay["stacks"]:
        out.append(coin_stack(x, y, n, r))
    for (x, y, sc, rot) in lay["bars"]:
        out.append(gold_bar(x, y, sc, rot))
    # Hero.
    hx, hy, hs = lay["hero"]
    out.append(f'<ellipse cx="{f(hx)}" cy="{f(hy + 4 * hs)}" rx="{f(170 * hs)}" ry="{f(24 * hs)}" fill="#7a4a1c" fill-opacity="0.25"/>')
    out.append(f'<g transform="translate({f(hx)} {f(hy)}) scale({f(hs)})">{diver()}</g>')
    # Fountain of coins and gems from the chest.
    face = (hx, hy - 580 * hs, 210 * hs)
    rnd = random.Random(lay.get("seed", 21))
    kinds = ["emerald", "crystal", "ruby", "pearl"]
    fountain = []
    placed = 0
    tries = 0
    while placed < lay["coins"] and tries < 400:
        tries += 1
        a = -math.pi / 2 + rnd.uniform(-1.2, 1.2)
        d = lay["spread"] * rnd.uniform(0.2, 1.0) ** 0.8
        x = bx + math.cos(a) * d * 1.3
        y = by - 30 * lay["s"] + math.sin(a) * d
        if math.hypot(x - face[0], y - face[1]) < face[2]:
            continue
        lx, ly, lw = lay["logo"]
        if lx - 10 < x < lx + lw + 10 and ly - 10 < y < ly + lw * 0.34 + 10:
            continue
        if x < 20 or x > w - 20 or y < 20:
            continue
        r = rnd.uniform(22, 34) * lay["s"]
        if placed % 6 == 5:
            fountain.append(gem(x, y, r * 1.5, kinds[(placed // 6) % 4], rnd.uniform(-0.5, 0.5)))
        else:
            fountain.append(coin(x, y, r, rnd.uniform(0.2, 1.0), rnd.uniform(-0.6, 0.6)))
        placed += 1
    out.append('<g id="fountain">' + "".join(fountain) + '</g>')
    out.insert(len(out) - 1, '<use href="#fountain" filter="url(#glowF)" opacity="0.85"/>')
    # Sparkles around the treasure.
    for i in range(lay.get("sparkles", 12)):
        a = rnd.uniform(0, math.tau)
        d = lay["spread"] * rnd.uniform(0.3, 1.1)
        x = bx + math.cos(a) * d * 1.3
        y = by + math.sin(a) * d * 0.8
        if math.hypot(x - face[0], y - face[1]) < face[2] or y > fy:
            continue
        out.append(sparkle(x, y, rnd.uniform(14, 30) * lay["s"], 0.95))
    # Bokeh lights.
    for i in range(lay.get("bokeh", 14)):
        x = rnd.uniform(0, w)
        y = rnd.uniform(0, fy)
        r = rnd.uniform(8, 26) * lay["s"]
        col = rnd.choice(["#fff3b0", "#ffffff", "#9ff3ff"])
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{col}" fill-opacity="{f(rnd.uniform(0.15, 0.35))}" filter="url(#dof)"/>')
    # Out-of-focus coins close to the camera.
    for (x, y, r, turn, rot) in lay.get("near", []):
        out.append(f'<g filter="url(#dof)" opacity="0.95">{coin(x, y, r, turn, rot)}</g>')
    out.append(f'<rect width="{w}" height="{h}" fill="url(#vignette)"/>')
    # Logo on top.
    lx, ly, lw = lay["logo"]
    logo = base64.b64encode(open(LOGO, "rb").read()).decode()
    out.append(f'<ellipse cx="{f(lx + lw / 2)}" cy="{f(ly + lw * 0.17)}" rx="{f(lw * 0.55)}" ry="{f(lw * 0.22)}" fill="#06204a" fill-opacity="0.22" filter="url(#soft)"/>')
    blur1 = f(14 * lay['s'])
    blur2 = f(7 * lay['s'])
    out.insert(1, '<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="30"/></filter>'
               f'<filter id="glowF" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{blur1}"/></filter>'
               f'<filter id="dof" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{blur2}"/></filter>')
    out.append(f'<image href="data:image/svg+xml;base64,{logo}" x="{f(lx)}" y="{f(ly)}" width="{f(lw)}" height="{f(lw * 500 / 1514)}"/>')
    out.append("</svg>")
    return "".join(out)


LAYOUTS = {
    "cover-landscape-1920x1080.png": (1920, 1080, {
        "s": 1.0, "floor": 905, "burst": (1400, 470), "glow": 520,
        "hero": (800, 1000, 0.86), "chest": (1400, 985, 1.0),
        "logo": (50, 34, 780), "coral": (110, 975, 1.25), "coral2": (330, 1000, 0.8), "crystals": (1830, 975, 1.0),
        "shafts": [(150, 70), (520, 110), (900, 60)],
        "near": [(70, 520, 70, 0.8, 0.4), (1870, 330, 58, 0.55, -0.5), (1000, 1050, 64, 0.9, 0.2)],
        "stacks": [(1050, 1000, 4, 40), (1745, 1010, 5, 42)],
        "bars": [(1150, 1010, 1.1, -6), (1650, 1012, 1.0, 8)],
        "coins": 34, "spread": 430, "sparkles": 16, "bubbles": 12}),
    "cover-portrait-800x1200.png": (800, 1200, {
        "s": 0.62, "floor": 1060, "burst": (560, 760), "glow": 360,
        "hero": (250, 1150, 0.62), "chest": (575, 1130, 0.6),
        "logo": (40, 50, 720), "coral": (30, 1120, 0.75), "crystals": (770, 1120, 0.6),
        "shafts": [(40, 50), (330, 70)],
        "near": [(40, 640, 50, 0.7, 0.4), (770, 420, 40, 0.5, -0.5)],
        "stacks": [(400, 1150, 3, 26), (735, 1160, 4, 26)],
        "bars": [(455, 1160, 0.7, -6)],
        "coins": 30, "spread": 330, "sparkles": 12, "bubbles": 9, "seed": 4}),
    "cover-square-800x800.png": (800, 800, {
        "s": 0.55, "floor": 680, "burst": (575, 450), "glow": 300,
        "hero": (245, 760, 0.55), "chest": (580, 745, 0.52),
        "logo": (55, 28, 690), "coral": (25, 735, 0.65), "crystals": (775, 735, 0.52),
        "shafts": [(60, 40), (300, 60)],
        "near": [(30, 400, 42, 0.7, 0.4)],
        "stacks": [(405, 765, 3, 22), (745, 770, 3, 22)],
        "bars": [],
        "coins": 24, "spread": 250, "sparkles": 10, "bubbles": 6, "seed": 7}),
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "store")
    os.makedirs(out_dir, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, (w, h, lay) in LAYOUTS.items():
            svg = scene(w, h, lay)
            with open(os.path.join(out_dir, name.replace(".png", ".svg")), "w") as fh:
                fh.write(svg)
            pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
            pg.set_content(f'<html><body style="margin:0;background:#000">{svg}</body></html>')
            pg.wait_for_timeout(300)
            png = pg.screenshot(clip={"x": 0, "y": 0, "width": w, "height": h})
            img = Image.open(io.BytesIO(png)).convert("RGB").resize((w, h), Image.LANCZOS)
            img.save(os.path.join(out_dir, name), optimize=True)
            print("wrote", name, img.size)
            pg.close()
        b.close()


if __name__ == "__main__":
    main()
