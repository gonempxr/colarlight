#!/usr/bin/env python3
"""Renders the Coralight promo video (scene.js) frame by frame in Chromium
and encodes it with ffmpeg at 60 fps.

    python3 tools/promo_video/render.py frames out_dir W H t1 t2 ...   # stills
    python3 tools/promo_video/render.py video out.mp4 W H [ad|cg]

ad = 30.5 s with captions, music + sound effects, logo, TRY NOW and the link.
cg = 19.6 s gameplay part, no captions, links or sound (CrazyGames preview rules).
"""
import base64
import os
import subprocess
import sys

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import sprites  # noqa: E402
import audio  # noqa: E402

FPS = 60
LINK = "gonempxr.github.io/colarlight"


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode()


def page_html(cfg):
    font = b64(open(os.path.join(ROOT, "game/assets/fonts/Nunito-Black.ttf"), "rb").read())
    sp = {k: b64(v.encode()) for k, v in sprites.all_sprites().items()}
    sp["logo"] = b64(open(os.path.join(ROOT, "game/assets/logo.svg"), "rb").read())
    js = "\n".join(open(os.path.join(HERE, n)).read() for n in ("scene.js", "empire.js", "timeline.js"))
    import json
    return f"""<!doctype html><html><head><style>
@font-face {{ font-family: Nunito; src: url(data:font/ttf;base64,{font}); }}
body {{ margin: 0; background: #000; }}
</style></head><body><canvas id="c"></canvas>
<div style="font-family:Nunito;position:absolute;opacity:0">.</div>
<script>
window.CFG = {json.dumps(cfg)};
window.SPR = {{}};
const SRC = {json.dumps(sp)};
window.ready = (async () => {{
  await document.fonts.load('40px Nunito');
  for (const [k, v] of Object.entries(SRC)) {{
    const im = new Image();
    im.src = 'data:image/svg+xml;base64,' + v;
    await im.decode();
    const r = k === 'logo' ? 2 : 1.6;
    const c = document.createElement('canvas');
    c.width = Math.ceil(im.naturalWidth * r); c.height = Math.ceil(im.naturalHeight * r);
    c.getContext('2d').drawImage(im, 0, 0, c.width, c.height);
    c.ratio = r;
    window.SPR[k] = c;
  }}
  return true;
}})();
</script>
<script>{js}</script>
<script>setup(CFG.w, CFG.h);</script>
</body></html>"""


def open_page(p, cfg):
    b = p.chromium.launch(args=["--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = b.new_page(viewport={"width": cfg["w"], "height": cfg["h"]})
    pg.set_content(page_html(cfg))
    pg.evaluate("window.ready")
    return b, pg


def config(w, h, mode):
    if mode == "cg":
        return {"w": w, "h": h, "captions": False, "endcard": False, "t0": 6.0, "dur": 19.6}
    return {"w": w, "h": h, "captions": True, "endcard": True, "t0": 0.0, "dur": 30.5, "link": LINK}


def soundtrack(pg, cfg, path):
    ev = pg.evaluate("sfxEvents()")
    tl = pg.evaluate("VT()")
    audio.write_track(path, ev, cfg["t0"], cfg["dur"], tl)


def grab(pg, t):
    url = pg.evaluate(f"render({t}); document.getElementById('c').toDataURL('image/jpeg', 0.93)")
    return base64.b64decode(url.split(",", 1)[1])


def main():
    mode = sys.argv[1]
    if mode == "audio":
        out, w, h = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
        cfg = config(w, h, "ad")
        with sync_playwright() as p:
            b, pg = open_page(p, cfg)
            soundtrack(pg, cfg, out)
            b.close()
        return
    if mode == "frames":
        out, w, h = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
        os.makedirs(out, exist_ok=True)
        cfg = config(w, h, "ad")
        with sync_playwright() as p:
            b, pg = open_page(p, cfg)
            for ts in sys.argv[5:]:
                open(os.path.join(out, f"f_{float(ts):05.2f}.jpg"), "wb").write(grab(pg, float(ts)))
            b.close()
        return
    out, w, h = sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    kind = sys.argv[5] if len(sys.argv) > 5 else "ad"
    cfg = config(w, h, kind)
    n = int(cfg["dur"] * FPS)
    with sync_playwright() as p:
        b, pg = open_page(p, cfg)
        a_args = ["-an"]
        if kind == "ad":
            wav = out + ".wav"
            soundtrack(pg, cfg, wav)
            a_args = ["-i", wav, "-map", "0:v", "-map", "1:a", "-c:a", "aac", "-b:a", "192k", "-shortest"]
        enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(FPS), "-i", "-"]
                               + a_args[:2] + ["-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p",
                                               "-movflags", "+faststart"] + a_args[2:] + [out], stdin=subprocess.PIPE)
        for i in range(n):
            enc.stdin.write(grab(pg, i / FPS))
            if i % 120 == 0:
                print(f"{out}: frame {i}/{n}", flush=True)
        b.close()
    enc.stdin.close()
    enc.wait()
    print("wrote", out)


if __name__ == "__main__":
    main()
