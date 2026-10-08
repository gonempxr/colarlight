"""Tiles a recorded frame sequence into one contact sheet image.

    python3 tools/contact_sheet.py <dir> <motion> <out.png> [cols] [scale] [crop x,y,w,h]

Takes <dir>/<motion>_NNN.png (from game/tests/motion_rec.gd), optionally
crops each frame, scales it and lays the frames out left to right, top to
bottom, numbered, so a motion can be checked frame by frame for jumps,
snaps and stutter.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw


def main():
    src, motion, out = sys.argv[1], sys.argv[2], sys.argv[3]
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
    scale = float(sys.argv[5]) if len(sys.argv) > 5 else 0.5
    crop = [int(v) for v in sys.argv[6].split(",")] if len(sys.argv) > 6 else None
    files = sorted(glob.glob(os.path.join(src, motion + "_*.png")))
    if not files:
        sys.exit("no frames")
    tiles = []
    for f in files:
        im = Image.open(f).convert("RGB")
        if crop:
            x, y, w, h = crop
            im = im.crop((x, y, x + w, y + h))
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
        tiles.append(im)
    tw, th = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 4) + 4, rows * (th + 4) + 4), (20, 16, 40))
    draw = ImageDraw.Draw(sheet)
    for i, im in enumerate(tiles):
        x = 4 + (i % cols) * (tw + 4)
        y = 4 + (i // cols) * (th + 4)
        sheet.paste(im, (x, y))
        draw.rectangle((x, y, x + 22, y + 12), fill=(0, 0, 0))
        draw.text((x + 2, y + 1), str(i), fill=(255, 255, 255))
    sheet.save(out)
    print("wrote", out, len(tiles), "frames")


if __name__ == "__main__":
    main()
