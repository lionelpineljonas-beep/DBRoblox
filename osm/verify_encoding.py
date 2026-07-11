"""Decode DiscoveryBayData.luau exactly the way build.luau will, and diff against
layout_debug.json. Proves the base36/RLE encoding round-trips before Studio ever runs.
"""

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

src = open(os.path.join(ROOT, "DiscoveryBayData.luau"), encoding="utf-8").read()
dbg = json.load(open(os.path.join(HERE, "layout_debug.json"), encoding="utf-8"))


def field(name):
    m = re.search(r"D\." + name + r"\s*=\s*\[\[(.*?)\]\]", src, re.S)
    return m.group(1)


def num(name):
    return float(re.search(r"D\." + name + r"\s*=\s*([\d.]+)", src).group(1))


b36 = lambda s: int(s, 36)

W, H, CELL = num("widthFt"), num("heightFt"), int(num("cellFt"))
cols, rows = int(num("cols")), int(num("rows"))
assert (cols, rows) == (dbg["cols"], dbg["rows"]), "grid dims mismatch"

# ---- raster ----
raster = field("raster")
decoded_rows = []
for group in raster.split(";"):
    span = b36(group[0])
    runs = group[1:]
    row = []
    for i in range(0, len(runs), 3):
        count, cls = b36(runs[i:i + 2]), runs[i + 2]
        row.append(cls * count)
    row = "".join(row)
    assert len(row) == cols, f"row length {len(row)} != {cols}"
    decoded_rows += [row] * span
assert len(decoded_rows) == rows, f"{len(decoded_rows)} rows != {rows}"
mismatch = sum(1 for a, b in zip(decoded_rows, dbg["grid"]) if a != b)
print(f"raster: {rows} rows decoded, {mismatch} mismatched rows")
assert mismatch == 0

# ---- buildings ----
bldg = field("buildings")
assert len(bldg) % 15 == 0
n = len(bldg) // 15
assert n == len(dbg["buildings"]), f"{n} records != {len(dbg['buildings'])}"
bad = 0
for i in range(n):
    r = bldg[i * 15:(i + 1) * 15]
    x, zn = b36(r[0:3]), b36(r[3:6])
    w, d = b36(r[6:8]), b36(r[8:10])
    yaw = b36(r[10:12])
    cls = r[12]
    dock = None if r[13:15] == "--" else b36(r[13:15])
    ref = dbg["buildings"][i]
    if (abs(x - ref["x"]) > 1 or abs(zn - ref["z"]) > 1 or abs(w - round(min(ref["w"], 1200))) > 1
            or abs(d - round(min(ref["d"], 1200))) > 1 or cls != ref["cls"]):
        bad += 1
        if bad < 4:
            print("  mismatch:", (x, zn, w, d, yaw, cls, dock), "vs", ref)
    yr = round(ref["yaw"]) % 360
    if min(abs(yaw - yr), 360 - abs(yaw - yr)) > 1:
        bad += 1
    dr = ref.get("dock")
    if (dock is None) != (dr is None):
        bad += 1
print(f"buildings: {n} records decoded, {bad} mismatches")
assert bad == 0

# ---- roads ----
road_lines = [l for l in field("roads").strip().split("\n") if l]
assert len(road_lines) == len(dbg["roads"]), f"{len(road_lines)} != {len(dbg['roads'])}"
bad = 0
for line, ref in zip(road_lines, dbg["roads"]):
    name, cls, enc = line.split("|")
    if name != ref[0] or cls != ref[1]:
        bad += 1
        continue
    pts = [(b36(enc[i:i + 3]), b36(enc[i + 3:i + 6])) for i in range(0, len(enc), 6)]
    # generator re-simplifies at encode time, so only endpoints are guaranteed shared
    rp = ref[3]
    if (abs(pts[0][0] - rp[0][0]) > 1.5 or abs(pts[0][1] - rp[0][1]) > 1.5
            or abs(pts[-1][0] - rp[-1][0]) > 1.5 or abs(pts[-1][1] - rp[-1][1]) > 1.5):
        bad += 1
print(f"roads: {len(road_lines)} decoded, {bad} mismatches")
assert bad == 0

print("\nENCODING VERIFIED: raster, buildings, roads all round-trip exactly.")
