"""Builds the Chinese fallback font in game/assets/fonts from ~/fontsrc.

Rubik (Latin + Cyrillic) is used whole and lives in game/assets/fonts
already. Noto Sans SC is cut down to
the Chinese characters the game actually uses, so rerun this after editing
any game/i18n/*.csv:
    python3 tools/subset_fonts.py
Sources (SIL Open Font License), fetched via fonts.googleapis.com css2:
    Rubik 600/800, Noto Sans SC 700.
"""
import csv
import os
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.expanduser("~/fontsrc")
OUT = os.path.join(ROOT, "game", "assets", "fonts")
EXTRA = "中文English Русский Español 0123456789%×∞→·★♪+-.,:;!?()（）：，。！？ "

os.makedirs(OUT, exist_ok=True)
text = EXTRA
I18N = os.path.join(ROOT, "game", "i18n")
for name in sorted(os.listdir(I18N)):
    if name.endswith(".csv"):
        with open(os.path.join(I18N, name), encoding="utf-8") as f:
            for row in csv.DictReader(f):
                text += row["zh"]
chars = sorted({c for c in text if ord(c) > 0x2000 or c in EXTRA})

opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
font = subset.load_font(os.path.join(SRC, "NotoSansSC-Bold.ttf"), opts)
sub = subset.Subsetter(opts)
sub.populate(text="".join(chars))
sub.subset(font)
out = os.path.join(OUT, "NotoSansSC-Bold-subset.ttf")
subset.save_font(font, out, opts)
print(f"{len(chars)} CJK/extra chars -> {os.path.getsize(out) // 1024} KB")
