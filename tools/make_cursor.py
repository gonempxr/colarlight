"""Bake the PC mouse cursor (cartoon pointing hand) into game/assets/cursor/.

Shape follows Mark's reference (docs/concept/cursor-ref.png), drawn in the
game's toon style: white glove, thick INK outline, soft shading, blue cuff.
Supersampled 8x, then downsampled. Hotspot is the index fingertip (see HOT).
Run: python3 tools/make_cursor.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SS = 8            # supersampling
SIZE = 32         # final cursor size (px)
INK = (36, 26, 58, 255)
WHITE = (251, 252, 255, 255)
SHADE = (207, 220, 240, 255)
CUFF = (143, 214, 255, 255)
CUFF_SHADE = (96, 176, 230, 255)
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "cursor"

# Reference-image coordinates -> canvas (SIZE*SS).
K = 0.255
def P(x, y):
    return ((x - 170) * K + 12, (y - 45) * K + 18)

def shape_mask(press):
    m = Image.new("L", (SIZE * SS,) * 2, 0)
    d = ImageDraw.Draw(m)
    top = 72 + (130 if press else 0)        # pressed: index finger bends down
    def rr(x0, y0, x1, y1, r):
        a, b = P(x0, y0), P(x1, y1)
        d.rounded_rectangle([a, b], radius=r * K, fill=255)
    rr(372, top, 502, 600, 64)             # index
    rr(502, 272, 635, 560, 55)             # middle
    rr(635, 325, 757, 560, 52)             # ring
    rr(757, 370, 875, 600, 50)             # pinky
    d.polygon([P(372, 430), P(875, 430), P(875, 675), P(790, 905),
               P(413, 905), P(413, 820), P(372, 760)], fill=255)   # palm
    d.polygon([P(372, 470), P(330, 425), P(275, 402), P(225, 410),
               P(200, 445), P(208, 490), P(413, 820), P(413, 700),
               P(372, 600)], fill=255)                               # thumb
    return m

def draw(press):
    W = SIZE * SS
    m = shape_mask(press)
    stroke = 2.5 * SS
    outer = m.filter(ImageFilter.MaxFilter(int(stroke * 2) | 1))
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    # soft drop shadow
    sh = outer.filter(ImageFilter.GaussianBlur(SS * 0.9)).point(lambda v: v * 0.35)
    img.paste((20, 14, 40, 255), (int(SS * 1.2), int(SS * 1.6)), sh)
    img.paste(INK, (0, 0), outer)
    img.paste(WHITE, (0, 0), m)
    d = ImageDraw.Draw(img)
    # shading band on the right side of the palm and fingers
    band = Image.new("L", (W, W), 0)
    ImageDraw.Draw(band).polygon([P(700, 520), P(875, 520), P(875, 675),
                                  P(790, 905), P(640, 905)], fill=255)
    band = Image.composite(band, Image.new("L", (W, W), 0), m)
    img.paste(SHADE, (0, 0), band)
    # cuff
    cuff = Image.new("L", (W, W), 0)
    ImageDraw.Draw(cuff).rectangle([P(380, 830), P(900, 910)], fill=255)
    cuff = Image.composite(cuff, Image.new("L", (W, W), 0), m)
    img.paste(CUFF, (0, 0), cuff)
    cs = Image.new("L", (W, W), 0)
    ImageDraw.Draw(cs).rectangle([P(700, 830), P(900, 910)], fill=255)
    img.paste(CUFF_SHADE, (0, 0), Image.composite(cs, Image.new("L", (W, W), 0), m))
    lw = int(1.9 * SS)
    d.line([P(380, 830), P(805, 830)], fill=INK, width=lw)
    # finger gaps (like the reference)
    d.line([P(502, 300), P(502, 430)], fill=INK, width=lw)
    d.line([P(635, 350), P(635, 430)], fill=INK, width=lw)
    d.line([P(757, 395), P(757, 470)], fill=INK, width=lw)
    d.line([P(372, 500), P(372, 610)], fill=INK, width=lw)
    # highlight on the index finger
    t = 72 + (130 if press else 0)
    d.line([P(405, t + 50), P(405, t + 140)], fill=(255, 255, 255, 255), width=int(1.6 * SS))
    return img.resize((SIZE, SIZE), Image.LANCZOS)

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    draw(False).save(OUT / "hand.png")
    draw(True).save(OUT / "hand_press.png")
    hx, hy = P(437, 72)
    stroke_top = 2.5 * SS
    print("hotspot", round(hx / SS, 1), round((hy - stroke_top) / SS, 1))
