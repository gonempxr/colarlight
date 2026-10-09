#!/bin/bash
# Runs every test of the game and prints one line per test, then a summary:
#   tools/run_tests.sh            all tests
#   tools/run_tests.sh fast       only the quick headless ones (no renderer)
# Exit code 0 when everything passed. Each test starts from a clean user://
# folder (left-over saves made some tests flaky).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT/game" || exit 1
USERDIR="$HOME/.local/share/godot/app_userdata/Coralight"
godot --headless --path . --import >/dev/null 2>&1

# name : how it runs (h = headless, p = headless phone window, m = phone at
# fixed 60 fps, r = needs a renderer via xvfb)
TESTS="check_scripts:h test_economy:h test_progress:h test_match3:h test_puzzle_ui:h
test_fishing:h test_world_taps:h test_diver_trip:h test_ads:h test_cloud:h test_map:h
test_worlds:h test_rooms:h test_streak:h test_switch:h
test_ui:p test_second:p test_lift:p test_rooms_ui:p test_motion:m test_governor:r"

fails=0
for item in $TESTS; do
	name=${item%%:*}
	mode=${item##*:}
	[ -f "tests/$name.gd" ] || continue
	if [ "$1" = "fast" ] && [ "$mode" != "h" ]; then
		continue
	fi
	rm -rf "$USERDIR"
	case $mode in
		h) out=$(timeout 600 godot --headless --path . -s "res://tests/$name.gd" 2>&1) ;;
		p) out=$(timeout 600 godot --headless --path . --resolution 390x844 -s "res://tests/$name.gd" 2>&1) ;;
		m) out=$(timeout 600 godot --headless --path . --resolution 390x844 --fixed-fps 60 -s "res://tests/$name.gd" 2>&1) ;;
		r) out=$(timeout 600 xvfb-run -a godot --rendering-driver opengl3 --path . -s "res://tests/$name.gd" 2>&1) ;;
	esac
	line=$(echo "$out" | grep -iE "checks,|passed,|jumps|broken|tests: |FAILED" | tail -1)
	bad=0
	echo "$line" | grep -qE "(^|[^0-9])[1-9][0-9]* (failed|broken|jumps)|FAILED" && bad=1
	[ -z "$line" ] && bad=1 && line="(no result line: crashed or timed out)"
	if [ $bad = 1 ]; then
		fails=$((fails + 1))
		printf "FAIL  %-18s %s\n" "$name" "$line"
		echo "$out" | grep -E "FAIL|SCRIPT ERROR" | head -5 | sed 's/^/        /'
	else
		printf "ok    %-18s %s\n" "$name" "$line"
	fi
done
rm -rf "$USERDIR"
echo "---"
if [ $fails = 0 ]; then
	echo "all tests passed"
else
	echo "$fails test(s) failed"
fi
exit $fails
