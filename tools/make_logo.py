"""Builds the Coralight logo as SVG from the Seymour One glyph outlines.

    python3 tools/make_logo.py        # writes game/assets/logo.svg

Chunky white letters with a thick navy outline and a 3D extrusion, the
"O" replaced by a brass diving helmet, and "DIVE TYCOON" in gold below.
Rasterize with tools/render_svg.gd (Godot) for PNG versions.
"""
import math
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "tools", "fonts", "SeymourOne-Regular.ttf")
OUT = os.path.join(ROOT, "game", "assets", "logo.svg")

NAVY = "#1b2a66"
NAVY_DEEP = "#121c4a"

font = TTFont(FONT)
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
upm = font["head"].unitsPerEm
cap = font["OS/2"].sCapHeight or int(upm * 0.7)


def line(text, size, x0, y0, bounce, tilt, skip=()):
    """Returns ([(path_d, center)], width) for a line of text; letters bounce
    along an arc and wobble a little. Letters in `skip` leave a gap."""
    s = size / cap
    x = x0
    out = []
    holes = []
    n = len(text)
    for i, ch in enumerate(text):
        g = cmap.get(ord(ch))
        adv = font["hmtx"][g][0] * s
        if ch == " ":
            x += size * 0.45
            continue
        wob = (-1) ** i * 3.5 + tilt
        dy = -math.sin(i / max(1, n - 1) * math.pi) * bounce
        cx = x + adv / 2
        cy = y0 + dy - size / 2
        if i in skip:
            holes.append((cx, cy, adv))
            x += adv * 0.92
            continue
        pen = SVGPathPen(glyphs)
        ang = math.radians(wob)
        ca, sa = math.cos(ang), math.sin(ang)
        # font units -> px, flip y, rotate around the letter center
        def xf(px, py):
            X = x + px * s - cx
            Y = y0 + dy - py * s - cy
            return (cx + X * ca - Y * sa, cy + X * sa + Y * ca)
        tpen = _FuncPen(pen, xf)
        glyphs[g].draw(tpen)
        out.append(pen.getCommands())
        x += adv * 0.92
    return out, holes, x - x0


class _FuncPen:
    def __init__(self, pen, f):
        self.pen, self.f = pen, f

    def moveTo(self, p):
        self.pen.moveTo(self.f(*p))

    def lineTo(self, p):
        self.pen.lineTo(self.f(*p))

    def qCurveTo(self, *pts):
        self.pen.qCurveTo(*[self.f(*p) if p is not None else None for p in pts])

    def curveTo(self, *pts):
        self.pen.curveTo(*[self.f(*p) for p in pts])

    def closePath(self):
        self.pen.closePath()

    def endPath(self):
        self.pen.endPath()

    def addComponent(self, name, t):
        glyphs[name].draw(TransformPen(self, t))


def layered(paths, fill, outline_w, extrude, grad_id):
    d = " ".join(paths)
    parts = []
    for k in range(extrude, 0, -2):
        parts.append(f'<path d="{d}" transform="translate(0,{k})" fill="{NAVY_DEEP}" stroke="{NAVY_DEEP}" stroke-width="{outline_w}" stroke-linejoin="round"/>')
    parts.append(f'<path d="{d}" fill="{NAVY}" stroke="{NAVY}" stroke-width="{outline_w}" stroke-linejoin="round"/>')
    parts.append(f'<path d="{d}" fill="url(#{grad_id})"/>')
    # Gloss: a thin light line along the top edges.
    parts.append(f'<path d="{d}" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="3" transform="translate(0,-2)"/>')
    return "\n".join(parts)


def helmet(cx, cy, r, extrude):
    parts = []
    for k in range(extrude, 0, -2):
        parts.append(f'<circle cx="{cx}" cy="{cy + k}" r="{r + 11}" fill="{NAVY_DEEP}"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r + 11}" fill="{NAVY}"/>')
    # Valve on top and side vent.
    parts.append(f'<rect x="{cx - 12}" y="{cy - r - 22}" width="24" height="18" rx="5" fill="#d19230" stroke="{NAVY}" stroke-width="8"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#brass)"/>')
    parts.append(f'<circle cx="{cx + r * 0.08}" cy="{cy + r * 0.02}" r="{r * 0.62}" fill="#b8782a" stroke="{NAVY}" stroke-width="6"/>')
    parts.append(f'<circle cx="{cx + r * 0.08}" cy="{cy + r * 0.02}" r="{r * 0.5}" fill="url(#glass)"/>')
    # A happy face in the porthole.
    fx, fy = cx + r * 0.08, cy + r * 0.06
    e = r * 0.16
    parts.append(f'<ellipse cx="{fx - e}" cy="{fy - e * 0.3}" rx="{e * 0.32}" ry="{e * 0.42}" fill="{NAVY}"/>')
    parts.append(f'<ellipse cx="{fx + e}" cy="{fy - e * 0.3}" rx="{e * 0.32}" ry="{e * 0.42}" fill="{NAVY}"/>')
    parts.append(f'<path d="M{fx - e * 0.8} {fy + e * 0.5} Q{fx} {fy + e * 1.4} {fx + e * 0.8} {fy + e * 0.5}" fill="none" stroke="{NAVY}" stroke-width="{e * 0.3}" stroke-linecap="round"/>')
    parts.append(f'<ellipse cx="{fx - e * 1.7}" cy="{fy + e * 0.5}" rx="{e * 0.45}" ry="{e * 0.28}" fill="#ff8fab" opacity="0.7"/>')
    parts.append(f'<ellipse cx="{fx + e * 1.7}" cy="{fy + e * 0.5}" rx="{e * 0.45}" ry="{e * 0.28}" fill="#ff8fab" opacity="0.7"/>')
    parts.append(f'<ellipse cx="{fx - r * 0.2}" cy="{fy - r * 0.28}" rx="{r * 0.14}" ry="{r * 0.08}" fill="#ffffff" opacity="0.9" transform="rotate(-30 {fx - r * 0.2} {fy - r * 0.28})"/>')
    for a in (200, 250, 290, 340):
        bx = cx + math.cos(math.radians(a)) * r * 0.8
        by = cy + math.sin(math.radians(a)) * r * 0.8
        parts.append(f'<circle cx="{bx}" cy="{by}" r="{r * 0.07}" fill="#9a5f1a"/>')
    parts.append(f'<ellipse cx="{cx - r * 0.45}" cy="{cy - r * 0.55}" rx="{r * 0.22}" ry="{r * 0.1}" fill="#ffffff" opacity="0.55" transform="rotate(-40 {cx - r * 0.45} {cy - r * 0.55})"/>')
    return "\n".join(parts)


def main():
    big, holes, w1 = line("CORALIGHT", 112, 0, 0, 26, -2, skip=(1,))
    small, _, w2 = line("DIVE TYCOON", 58, 0, 0, 8, 0)
    W, H = int(w1 + 200), 500
    # Center both lines.
    ox1 = (W - w1) / 2
    ox2 = (W - w2) / 2 + 40
    big, holes, _ = line("CORALIGHT", 112, ox1, 250, 26, -2, skip=(1,))
    small, _, _ = line("DIVE TYCOON", 58, ox2, 360, 8, 0)
    hx, hy, hadv = holes[0]
    defs = f"""
<defs>
  <linearGradient id="white" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff"/><stop offset="0.55" stop-color="#ffffff"/><stop offset="1" stop-color="#bfe9ff"/>
  </linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff07a"/><stop offset="0.5" stop-color="#ffd23f"/><stop offset="1" stop-color="#ff9f1c"/>
  </linearGradient>
  <radialGradient id="brass" cx="0.35" cy="0.3" r="0.8">
    <stop offset="0" stop-color="#ffe08a"/><stop offset="0.6" stop-color="#f5b843"/><stop offset="1" stop-color="#c9861f"/>
  </radialGradient>
  <radialGradient id="glass" cx="0.4" cy="0.35" r="0.7">
    <stop offset="0" stop-color="#ffe6cf"/><stop offset="1" stop-color="#f6c9a0"/>
  </radialGradient>
  <linearGradient id="wave" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#4fd8e6"/><stop offset="1" stop-color="#1c88b6"/>
  </linearGradient>
</defs>"""
    body = []
    # Wave ribbon behind the subtitle.
    wave = f"M{ox2 - 60} 345 Q{W / 2} 300 {ox2 + w2 + 50} 335 L{ox2 + w2 + 75} 390 Q{W / 2} 362 {ox2 - 35} 405 Z"
    body.append(f'<path d="{wave}" transform="translate(0,10)" fill="{NAVY_DEEP}" stroke="{NAVY_DEEP}" stroke-width="16" stroke-linejoin="round"/>')
    body.append(f'<path d="{wave}" fill="url(#wave)" stroke="{NAVY}" stroke-width="16" stroke-linejoin="round"/>')
    # Bubbles.
    for bx, by, br in [(ox1 - 34, 150, 15), (ox1 - 58, 104, 9), (ox1 + w1 + 34, 120, 14), (ox1 + w1 + 58, 78, 9), (ox1 + w1 + 26, 44, 6)]:
        body.append(f'<circle cx="{bx}" cy="{by}" r="{br}" fill="#dff8ff" fill-opacity="0.9" stroke="{NAVY}" stroke-width="6"/>')
        body.append(f'<circle cx="{bx - br * 0.35}" cy="{by - br * 0.35}" r="{br * 0.28}" fill="#ffffff"/>')
    body.append(layered(big, "white", 30, 16, "white"))
    body.append(helmet(hx + 4, hy + 2, 60, 16))
    body.append(layered(small, "gold", 22, 10, "gold"))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{defs}\n<g transform="translate(0,30) rotate(-4 {W / 2} {H / 2})">\n' + "\n".join(body) + "\n</g></svg>\n"
    with open(OUT, "w") as f:
        f.write(svg)
    print("wrote", OUT, len(svg) // 1024, "KB")


if __name__ == "__main__":
    main()
