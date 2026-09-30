"""Builds the web loading screen (custom HTML shell) for the Godot export.

    python3 tools/make_web_shell.py      # writes game/web/shell.html

Takes tools/web_shell/shell.src.html and inlines the logo (logo.webp) and two
small font subsets (Nunito Black for Latin and Cyrillic, Noto Sans SC for
Chinese) holding only the characters the page uses, so the loading screen
shows at once without extra requests.

Rebuild logo.webp after changing the logo:
    godot --headless --path game -s res://../tools/render_svg.gd -- \
        $PWD/game/assets/logo.svg $PWD/tools/web_shell/logo.png 0.6
    then save it as WebP (quality 88).
"""
import base64
import io
import os

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "web_shell", "shell.src.html")
LOGO = os.path.join(ROOT, "tools", "web_shell", "logo.webp")
OUT = os.path.join(ROOT, "game", "web", "shell.html")
MAIN_FONT = os.path.join(ROOT, "game", "assets", "fonts", "Nunito-Black.ttf")
ZH_FONT = os.path.join(ROOT, "game", "assets", "fonts", "NotoSansSC-Bold-subset.ttf")


def is_cjk(ch):
    return ord(ch) >= 0x2E80


def woff_subset(path, chars):
    font = TTFont(path)
    options = subset.Options()
    options.flavor = "woff"
    options.layout_features = ["kern", "liga"]
    options.name_IDs = ["*"]
    sub = subset.Subsetter(options)
    sub.populate(text="".join(sorted(chars)))
    sub.subset(font)
    buf = io.BytesIO()
    font.flavor = "woff"
    font.save(buf)
    return base64.b64encode(buf.getvalue()).decode("ascii")


def main():
    with open(SRC, encoding="utf-8") as f:
        html = f.read()
    text = set(html) | set("0123456789%")
    main_chars = {c for c in text if c.isprintable() and not is_cjk(c)}
    zh_chars = {c for c in text if is_cjk(c)} | set("“”…")
    with open(LOGO, "rb") as f:
        logo = base64.b64encode(f.read()).decode("ascii")
    html = (html.replace("{{FONT_MAIN}}", woff_subset(MAIN_FONT, main_chars))
            .replace("{{FONT_ZH}}", woff_subset(ZH_FONT, zh_chars))
            .replace("{{LOGO}}", logo))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("wrote", OUT, len(html.encode("utf-8")) // 1024, "KB")


if __name__ == "__main__":
    main()
