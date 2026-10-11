"""Vector sprites for the promo video (SVG strings), built on the cover art
pieces in tools/store_art/vcore.py so the ad matches the store covers."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "store_art"))
import vcore  # noqa: E402

INK = vcore.INK
W = vcore.W
f = vcore.f

EXTRA_DEFS = '''
<linearGradient id="suitP" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a99a86"/><stop offset="0.6" stop-color="#8d7e6a"/><stop offset="1" stop-color="#6e6050"/></linearGradient>
<linearGradient id="suitArmP" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a39480"/><stop offset="1" stop-color="#7d6f5c"/></linearGradient>
<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c9ced8"/><stop offset="1" stop-color="#7d8596"/></linearGradient>
<radialGradient id="steelDome" cx="0.35" cy="0.28" r="0.8"><stop offset="0" stop-color="#e3e7ee"/><stop offset="0.45" stop-color="#a8b0bf"/><stop offset="1" stop-color="#6f7787"/></radialGradient>
<radialGradient id="steelDark" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="#9aa2b2"/><stop offset="1" stop-color="#626a7a"/></radialGradient>
<linearGradient id="suitG" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff0a0"/><stop offset="0.55" stop-color="#ffcc33"/><stop offset="1" stop-color="#e09a12"/></linearGradient>
'''

ARMS_UP = ["M -100 -390 C -170 -420, -230 -470, -262 -540", "M 100 -390 C 170 -460, 220 -620, 236 -790"]
GLOVES_UP = [(-262, -548), (238, -800)]


def _face(kind, gy):
    s = [f'<ellipse cx="0" cy="{gy + 12}" rx="84" ry="86" fill="url(#skin)"/>',
         f'<path d="M -84 {gy - 30} C -60 {gy - 92}, 60 {gy - 92}, 84 {gy - 30} C 50 {gy - 58}, -50 {gy - 58}, -84 {gy - 30} Z" fill="#6b3f22"/>']
    if kind == "star":
        for ex in (-34, 34):
            s.append(f'<path d="{vcore.star_path(ex, gy - 4, 27, 12)}" fill="url(#starEye)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
            s.append(f'<circle cx="{ex - 7}" cy="{gy - 11}" r="4.5" fill="#ffffff"/>')
    elif kind == "sad":
        for ex in (-32, 32):
            s.append(f'<ellipse cx="{ex}" cy="{gy}" rx="11" ry="14" fill="{INK}"/>')
            s.append(f'<circle cx="{ex - 3}" cy="{gy - 5}" r="4" fill="#ffffff"/>')
            # worried brows
            d = -1 if ex < 0 else 1
            s.append(f'<path d="M {ex - 16 * d} {gy - 22} L {ex + 14 * d} {gy - 30}" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>')
        # a tear
        s.append(f'<path d="M 44 {gy + 10} q -8 14 0 20 q 8 -6 0 -20 z" fill="#7fd8ff" stroke="{INK}" stroke-width="3"/>')
        s.append(f'<path d="M -22 {gy + 50} Q 0 {gy + 34} 22 {gy + 50}" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>')
    else:  # happy / focus
        for ex in (-32, 32):
            s.append(f'<ellipse cx="{ex}" cy="{gy}" rx="11" ry="14" fill="{INK}"/>')
            s.append(f'<circle cx="{ex - 3}" cy="{gy - 5}" r="4.5" fill="#ffffff"/>')
        my = gy + 30
        s.append(f'<path d="M -28 {my} Q 0 {my + 4} 28 {my} Q 24 {my + 34} 0 {my + 36} Q -24 {my + 34} -28 {my} Z" fill="#7a2335" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        s.append(f'<path d="M -20 {my + 3} Q 0 {my + 7} 20 {my + 3} L 18 {my + 9} Q 0 {my + 12} -18 {my + 9} Z" fill="#ffffff"/>')
    for bx in (-58, 58):
        s.append(f'<ellipse cx="{bx}" cy="{gy + 28}" rx="15" ry="9" fill="#ff7f96" fill-opacity="{0.25 if kind == "sad" else 0.55}"/>')
    return "".join(s)


def pickaxe(x, y, rot):
    return (f'<g transform="translate({x} {y}) rotate({rot})">'
            f'<rect x="-11" y="-250" width="22" height="270" rx="10" fill="url(#wood)" stroke="{INK}" stroke-width="7"/>'
            f'<path d="M -160 -215 Q 0 -330 160 -215 Q 0 -262 -160 -215 Z" fill="url(#steel)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
            f'<path d="M -90 -262 Q 0 -300 90 -262" stroke="#ffffff" stroke-opacity="0.6" stroke-width="7" fill="none" stroke-linecap="round"/></g>')


def bucket(x, y):
    return (f'<g transform="translate({x} {y})">'
            f'<path d="M -50 -40 A 50 40 0 0 1 50 -40" fill="none" stroke="{INK}" stroke-width="8"/>'
            f'<path d="M -48 -40 L 48 -40 L 38 40 L -38 40 Z" fill="url(#woodDark)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
            f'<path d="M -44 -12 L 44 -12 M -41 16 L 41 16" stroke="#5a3418" stroke-width="5"/></g>')


def diver(face="happy", arms="up", palette="orange", tool=None):
    s = vcore.diver()
    # Face.
    a = s.index('<g clip-path="url(#glassClip)">') + len('<g clip-path="url(#glassClip)">')
    b = s.index('</g>', a)
    s = s[:a] + _face(face, -580) + s[b:]
    # Arms.
    if arms == "down":
        new = ["M -100 -390 C -150 -340, -170 -290, -175 -230", "M 100 -390 C 150 -340, 170 -290, 175 -230"]
        gloves = [(-176, -220), (176, -220)]
    elif arms == "pick":
        new = ["M -100 -390 C -150 -340, -170 -290, -175 -230", "M 100 -390 C 180 -430, 240 -520, 262 -600"]
        gloves = [(-176, -220), (264, -608)]
    else:
        new, gloves = ARMS_UP, GLOVES_UP
    for o, n in zip(ARMS_UP, new):
        s = s.replace(o, n)
    for (ox, oy), (nx, ny) in zip(GLOVES_UP, gloves):
        s = s.replace(f'cx="{ox}" cy="{oy}"', f'cx="{nx}" cy="{ny}"')
        s = s.replace(f'M {ox - 26} {oy - 20}', f'M {nx - 26} {ny - 20}')
    if palette == "poor":
        s = (s.replace("url(#suitArm)", "url(#suitArmP)").replace("url(#suit)", "url(#suitP)")
             .replace("url(#brassDome)", "url(#steelDome)").replace("url(#brassDark)", "url(#steelDark)")
             .replace("url(#brass)", "url(#steel)").replace("#f07a2a", "#7d6f5c"))
        # Patches on the suit.
        s += (f'<rect x="-80" y="-360" width="56" height="50" rx="6" fill="#b5a07a" stroke="{INK}" stroke-width="5" transform="rotate(-8 -52 -335)"/>'
              f'<path d="M -74 -350 l 10 6 M -60 -348 l 10 6 M -46 -346 l 10 6" stroke="{INK}" stroke-width="3"/>'
              f'<rect x="30" y="-180" width="46" height="40" rx="5" fill="#9c8a66" stroke="{INK}" stroke-width="5"/>'
              # dent on the helmet
              f'<path d="M 90 -720 q 20 10 30 34" stroke="{INK}" stroke-width="6" fill="none" stroke-linecap="round"/>')
    elif palette == "gold":
        s = s.replace("url(#suitArm)", "url(#suitG)").replace("url(#suit)", "url(#suitG)").replace("#f07a2a", "#e8a21a")
    pre = ""
    if tool == "pick":
        pre = ""
        s += pickaxe(264, -608, -18)
    elif tool == "bucket":
        s += bucket(-176, -150)
    return pre + s


def wrap(body, box, burst=(0, 0)):
    x, y, w, h = box
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{x} {y} {w} {h}">'
            + vcore.defs(burst, 100).replace("</defs>", EXTRA_DEFS + "</defs>") + body + "</svg>")


DIVER_BOX = (-360, -960, 720, 990)


def all_sprites():
    sp = {
        "diverSad": wrap(diver("sad", "down", "poor", "bucket"), DIVER_BOX),
        "diverHappy": wrap(diver("happy", "pick", "orange", "pick"), DIVER_BOX),
        "diverStar": wrap(diver("star", "up", "orange"), DIVER_BOX),
        "diverGold": wrap(diver("star", "up", "gold"), DIVER_BOX),
        "chest": wrap(vcore.chest(), (-330, -560, 660, 580)),
        "coin": wrap(vcore.coin(0, 0, 60, 1.0, 0), (-70, -70, 140, 140)),
        "bar": wrap(vcore.gold_bar(0, 0, 1.0, 0), (-70, -60, 140, 70)),
    }
    for k in ("emerald", "crystal", "ruby", "pearl"):
        sp[k] = wrap(vcore.gem(0, 0, 60, k, 0), (-70, -80, 140, 160))
    return sp
