#!/bin/bash
# Web export with the lazily loaded files next to the page (see
# game/scripts/util/lazy_assets.gd):
#   tools/export_web.sh [out dir, default game/build/web] [beta]
# "beta" builds with its own save folder (coralight-beta) without touching
# the project file in git.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$ROOT/game/build/web}
SRC=$ROOT/game
if [ "$2" = "beta" ]; then
	TMP=$(mktemp -d)
	cp -r "$ROOT/game/." "$TMP/"
	rm -rf "$TMP/build"
	python3 - "$TMP/project.godot" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'use_custom_user_dir' not in s:
    s = s.replace('config/icon="res://icon.svg"\n', 'config/icon="res://icon.svg"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="coralight-beta"\n', 1)
open(p, 'w').write(s)
PY
	SRC=$TMP
	godot --headless --path "$SRC" --import >/dev/null 2>&1 || true
fi
mkdir -p "$OUT"
rm -f "$OUT"/index.* "$OUT"/music.ogg "$OUT"/icudt_godot.dat
godot --headless --path "$SRC" --export-release Web "$OUT/index.html" 2>&1 | grep -E "^ERROR" || true
# Chinese line breaking data: fetched only when Chinese is chosen.
python3 "$ROOT/tools/pck_strip.py" "$OUT/index.pck" icudt_godot.dat
# The page's loading bar knows the file sizes: give it the new one.
python3 - "$OUT" <<'PY'
import os, re, sys
out = sys.argv[1]
p = os.path.join(out, "index.html")
s = open(p).read()
size = os.path.getsize(os.path.join(out, "index.pck"))
s, n = re.subn(r'"index\.pck":\d+', '"index.pck":%d' % size, s)
assert n == 1, "fileSizes not found in index.html"
open(p, "w").write(s)
PY
# The music loop: fetched after the start.
cp "$ROOT/game/assets/audio/music.ogg" "$OUT/music.ogg"
ls -la "$OUT"
