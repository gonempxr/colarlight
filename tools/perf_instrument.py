#!/usr/bin/env python3
"""Copies game/ to a scratch folder with every _draw and _process wrapped
in a timer, for finding what costs frame time:

    python3 tools/perf_instrument.py /tmp/prof_game
    cd /tmp/prof_game && godot --headless --path . --import
    godot --headless --fixed-fps 60 --path . --resolution 390x844 \
        -s res://tests/perf_attr.gd -- phone prof

perf_attr.gd prints the per-frame cost of each wrapped function when it is
given "prof" and the instrumented copy is the one running. The copy is
throwaway: never commit it.
"""
import os
import re
import shutil
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PROF = '''extends RefCounted
## Timers added by tools/perf_instrument.py (only in the instrumented copy).
static var total := {}
static var calls := {}


static func add(key: String, usec: int) -> void:
	total[key] = total.get(key, 0) + usec
	calls[key] = calls.get(key, 0) + 1


static func reset() -> void:
	total.clear()
	calls.clear()
'''

HOOK = re.compile(r'^(\t*)func (_draw|_process)\((\w*)\s*(:\s*\w+)?\)\s*(->\s*void)?\s*:\s*$')
PAINT = re.compile(r'^(\t*)func (_paint_\w+|_draw_\w+)\((\w+)(:\s*\w+)?\)\s*(->\s*void)?\s*:\s*$')


def instrument(path: str, rel: str) -> None:
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    out = []
    changed = False
    name = os.path.basename(rel)
    for line in lines:
        m = HOOK.match(line)
        if m:
            ind, fn, arg, typ, _ = m.groups()
            impl = "__" + fn.lstrip("_") + "_impl"
            key = "%s:%s" % (name, fn.lstrip("_"))
            if ind:
                key += "(inner)"
            sig_arg = arg + (typ or "") if arg else ""
            out.append("%sfunc %s(%s) -> void:" % (ind, fn, sig_arg))
            out.append("%s\tvar __t := Time.get_ticks_usec()" % ind)
            out.append("%s\t%s(%s)" % (ind, impl, arg or ""))
            out.append('%s\tpreload("res://scripts/util/prof.gd").add("%s", Time.get_ticks_usec() - __t)' % (ind, key))
            out.append("")
            out.append("%sfunc %s(%s):" % (ind, impl, sig_arg))
            changed = True
            continue
        out.append(line)
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(out))


def main() -> None:
    dst = sys.argv[1]
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(SRC, dst, ignore=shutil.ignore_patterns(".godot", "build"))
    with open(os.path.join(dst, "scripts", "util", "prof.gd"), "w") as f:
        f.write(PROF)
    for root, _, files in os.walk(os.path.join(dst, "scripts")):
        for fn in files:
            if fn.endswith(".gd") and fn != "prof.gd":
                p = os.path.join(root, fn)
                instrument(p, os.path.relpath(p, dst))
    # Paint layers: name the painter, not the layer.
    pl = os.path.join(dst, "scripts", "ui", "paint_layer.gd")
    s = open(pl).read()
    s = s.replace('preload("res://scripts/util/prof.gd").add("paint_layer.gd:draw"',
                  'preload("res://scripts/util/prof.gd").add("paint:" + str(painter.get_object().get_script().resource_path.get_file()) + "." + painter.get_method()')
    open(pl, "w").write(s)
    # Art.flush (sends the batched triangles).
    art = os.path.join(dst, "scripts", "ui", "art.gd")
    s = open(art).read()
    s = s.replace("static func flush() -> void:\n", "static func flush() -> void:\n\tpreload(\"res://scripts/util/prof.gd\").add(\"Art.flushed_verts (count, not ms)\", _bv.size() * 1000)\n\tvar __t := Time.get_ticks_usec()\n\t__flush_impl()\n\tpreload(\"res://scripts/util/prof.gd\").add(\"Art.flush\", Time.get_ticks_usec() - __t)\n\n\nstatic func __flush_impl() -> void:\n", 1)
    open(art, "w").write(s)
    wrap_static(art, ["circle_pts", "ellipse_pts", "rrect_pts", "smooth_pts", "_geo_for", "_colors_for", "_put", "cache_begin",
                      "toon", "flat", "grad", "disc", "polyline", "_poly_geo", "push", "pop"], "Art.")
    if os.environ.get("DEEP"):
        for fn in os.listdir(os.path.join(dst, "scripts", "ui")):
            if fn.endswith(".gd") and fn not in ("art.gd", "paint_layer.gd"):
                wrap_static(os.path.join(dst, "scripts", "ui", fn), None, fn[:-3] + ".")
    if os.environ.get("CHARS"):
        for fn in ["chars.gd", "worker_looks.gd", "ore_art.gd", "props.gd"]:
            wrap_static(os.path.join(dst, "scripts", "ui", fn), "ALL", fn[:-3] + ".")
    print("instrumented copy in", dst)


SFUNC = re.compile(r'^(static )?func (\w+)\((.*)\)\s*(->\s*([\w\[\]]+))?\s*:\s*$')


def wrap_static(path, names, prefix):
    """Times single-line static funcs (inclusive of what they call)."""
    lines = open(path).read().split("\n")
    out = []
    for line in lines:
        m = SFUNC.match(line)
        if m and (m.group(1) if names == "ALL" else True) and ((names == "ALL") or (m.group(2) in names if names else (re.match(r'^_?(draw|paint)', m.group(2)) and m.group(2) not in ("_draw",)))):
            fn, params, ret = m.group(2), m.group(3), m.group(5)
            parts, depth, cur = [], 0, ""
            for ch in params:
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                if ch == "," and depth == 0:
                    parts.append(cur)
                    cur = ""
                else:
                    cur += ch
            if cur.strip():
                parts.append(cur)
            args = [a.split(":")[0].split("=")[0].strip() for a in parts if a.strip()]
            impl = "__" + fn.lstrip("_") + "_timed"
            out.append(line)
            out.append("\tvar __t := Time.get_ticks_usec()")
            if ret and ret != "void":
                out.append("\tvar __r = %s(%s)" % (impl, ", ".join(args)))
                out.append('\tpreload("res://scripts/util/prof.gd").add("%s%s", Time.get_ticks_usec() - __t)' % (prefix, fn))
                out.append("\treturn __r")
            else:
                out.append("\t%s(%s)" % (impl, ", ".join(args)))
                out.append('\tpreload("res://scripts/util/prof.gd").add("%s%s", Time.get_ticks_usec() - __t)' % (prefix, fn))
            out.append("")
            out.append("")
            out.append(line.replace("func %s(" % fn, "func %s(" % impl, 1))
            continue
        out.append(line)
    open(path, "w").write("\n".join(out))


if __name__ == "__main__":
    main()
