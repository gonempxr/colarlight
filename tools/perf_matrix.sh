#!/bin/bash
# Frame cost (headless, native CPU, ms at a simulated 60 fps) of the busy
# late-game save across worlds, rooms and scroll positions, phone and PC:
#   tools/perf_matrix.sh [game dir] [frames]
# Columns: median frame ms, worst frame ms.
GAME=${1:-$(dirname "$0")/../game}
FRAMES=${2:-240}
cd "$GAME" || exit 1
for dev in phone pc; do
	if [ $dev = phone ]; then res=390x844; flag=phone; else res=1920x1080; flag=; fi
	for cfg in "world=0" "world=0 scroll=1400" "world=1 scroll=700" "world=2 scroll=1400" "world=3 scroll=700" "room=1" "room=2"; do
		out=$(timeout 600 godot --headless --fixed-fps 60 --path . --resolution $res -s res://tests/perf_attr.gd -- $flag frames=$FRAMES $cfg 2>&1 | grep BASE)
		med=$(echo "$out" | sed -E 's/.*frame ([0-9.]+) ms.*/\1/')
		worst=$(echo "$out" | sed -E 's/.*worst ([0-9.]+)\).*/\1/')
		printf "%-6s %-22s %7s %7s\n" $dev "$cfg" "$med" "$worst"
	done
done
