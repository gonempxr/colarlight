#!/usr/bin/env python3
"""Moves files out of a Godot 4 .pck (pack format with a directory at the
end and offsets from the file base) so the page downloads them only when
needed:

    python3 tools/pck_strip.py build/web/index.pck icudt_godot.dat [...]

Each named file is written next to the .pck (same name) and dropped from
the pack. Used by tools/export_web.sh for the text server data (only
Chinese needs it, scripts/util/lazy_assets.gd loads it then).
"""
import os
import struct
import sys

ALIGN = 16


def read_dir(d):
    flags, fbase, dirofs = struct.unpack_from('<IQQ', d, 20)
    assert flags & 2, "expected offsets relative to the file base"
    off = dirofs
    n, = struct.unpack_from('<I', d, off)
    off += 4
    entries = []
    for _ in range(n):
        l, = struct.unpack_from('<I', d, off)
        off += 4
        raw = d[off:off + l]
        off += l
        o, s = struct.unpack_from('<QQ', d, off)
        md5 = d[off + 16:off + 32]
        off += 32
        fl, = struct.unpack_from('<I', d, off)
        off += 4
        entries.append({"raw": raw, "name": raw.rstrip(b"\0").decode(), "o": o, "s": s, "md5": md5, "fl": fl})
    return fbase, dirofs, entries


def main():
    path = sys.argv[1]
    names = set(sys.argv[2:])
    d = open(path, 'rb').read()
    magic, = struct.unpack_from('<I', d, 0)
    assert magic == 0x43504447, "not a pck"
    fbase, dirofs, entries = read_dir(d)
    out = bytearray(d[:fbase])
    kept = []
    for e in sorted(entries, key=lambda e: e["o"]):
        data = d[fbase + e["o"]:fbase + e["o"] + e["s"]]
        if e["name"] in names:
            with open(os.path.join(os.path.dirname(path) or ".", os.path.basename(e["name"])), 'wb') as f:
                f.write(data)
            print("moved out %s (%d bytes)" % (e["name"], e["s"]))
            continue
        while (len(out) - fbase) % ALIGN:
            out.append(0)
        e["o"] = len(out) - fbase
        out += data
        kept.append(e)
    while len(out) % ALIGN:
        out.append(0)
    new_dir = len(out)
    out += struct.pack('<I', len(kept))
    for e in sorted(kept, key=lambda e: [x["name"] for x in entries].index(e["name"])):
        out += struct.pack('<I', len(e["raw"])) + e["raw"]
        out += struct.pack('<QQ', e["o"], e["s"]) + e["md5"] + struct.pack('<I', e["fl"])
    struct.pack_into('<Q', out, 32, new_dir)
    with open(path, 'wb') as f:
        f.write(out)
    print("%s: %d -> %d bytes" % (path, len(d), len(out)))


if __name__ == "__main__":
    main()
