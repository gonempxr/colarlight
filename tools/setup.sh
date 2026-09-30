#!/usr/bin/env bash
# One-time setup for a fresh machine or cloud session (Linux x86_64).
# Installs Godot 4.7.2 if missing, points the web export at this checkout's
# slim template, and imports the project. Safe to run again.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$(command -v godot || true)"
if [ -z "$GODOT" ]; then
	mkdir -p "$HOME/tools"
	curl -fsSL -o /tmp/godot.zip \
		https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
	unzip -o -q /tmp/godot.zip -d "$HOME/tools"
	chmod +x "$HOME/tools/Godot_v4.7.2-stable_linux.x86_64"
	GODOT="$HOME/tools/Godot_v4.7.2-stable_linux.x86_64"
	ln -sf "$GODOT" /usr/local/bin/godot 2>/dev/null || echo "Add $GODOT to PATH as godot"
fi
# The export preset needs an absolute template path; make it this checkout's.
sed -i "s|^custom_template/release=.*|custom_template/release=\"$ROOT/tools/web_template/godot-4.7.2-slim-web-nothreads.zip\"|" \
	"$ROOT/game/export_presets.cfg"
mkdir -p "$ROOT/game/build/web" && touch "$ROOT/game/build/.gdignore"
cd "$ROOT/game" && "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --version
