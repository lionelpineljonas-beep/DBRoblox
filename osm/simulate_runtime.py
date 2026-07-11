"""Offline simulation of build.luau's runtime logic against the encoded data:
- classAt() raster lookups (ported 1:1)
- dock marching (does every dock-flagged home actually reach rendered water?)
- marina anchor search from Marina Road
- part-count budget estimate
"""

import json
import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
src = open(os.path.join(ROOT, "DiscoveryBayData.luau"), encoding="utf-8").read()

b36 = lambda s: int(s, 36)
num = lambda n: float(re.search(r"D\." + n + r"\s*=\s*([\d.]+)", src).group(1))
field = lambda n: re.search(r"D\." + n + r"\s*=\s*\[\[(.*?)\]\]", src, re.S).group(1)

W, H, CELL = num("widthFt"), num("heightFt"), int(num("cellFt"))
COLS, ROWS = int(num("cols")), int(num("rows"))

# ---- decode raster exactly like build.luau ----
groups = []
row_to_group = [0] * ROWS
r = 0
for grp in field("raster").split(";"):
    span = b36(grp[0])
    runs = []
    col = 0
    for i in range(1, len(grp) - 2, 3):
        col += b36(grp[i:i + 2])
        runs.append((col, grp[i + 2]))
    groups.append((r, span, runs))
    for k in range(r, r + span):
        row_to_group[k] = len(groups) - 1
    r += span
assert r == ROWS

def class_at(x, zn):
    if x < 0 or x >= W or zn < 0 or zn >= H:
        return "l"
    col = min(max(int(x // CELL), 0), COLS - 1)
    row = min(max(int((H - zn) // CELL), 0), ROWS - 1)
    for end_col, cls in groups[row_to_group[row]][2]:
        if col < end_col:
            return cls
    return "l"

is_water = lambda x, zn: class_at(x, zn) == "w"

# ---- buildings + docks ----
blob = field("buildings")
buildings = []
for i in range(0, len(blob), 15):
    rec = blob[i:i + 15]
    buildings.append({
        "x": b36(rec[0:3]), "z": b36(rec[3:6]), "w": b36(rec[6:8]), "d": b36(rec[8:10]),
        "yaw": b36(rec[10:12]), "cls": rec[12],
        "dock": None if rec[13:15] == "--" else b36(rec[13:15]),
    })

dock_flagged = [b for b in buildings if b["dock"] is not None]
found, missed = 0, 0
for b in dock_flagged:
    a = math.radians(b["dock"])
    ex, en = -math.sin(a), math.cos(a)
    dd = b["d"] / 2 + 4
    hit = False
    while dd <= b["d"] / 2 + 4 + 160:
        if is_water(b["x"] + ex * dd, b["z"] + en * dd):
            hit = True
            break
        dd += 6
    if hit:
        found += 1
    else:
        missed += 1
print(f"docks: {len(dock_flagged)} flagged, {found} reach rendered water, {missed} miss")

# ---- marina anchor ----
road_lines = [l for l in field("roads").strip().split("\n") if l]
marina_pts = None
for line in road_lines:
    name, cls, enc = line.split("|")
    if name == "Marina Road":
        marina_pts = [(b36(enc[i:i + 3]), b36(enc[i + 3:i + 6])) for i in range(0, len(enc), 6)]
        break
if marina_pts:
    anchor = None
    for ep in (marina_pts[0], marina_pts[-1]):
        for ang in range(0, 360, 10):
            ex, en = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            for dist in range(20, 301, 20):
                if is_water(ep[0] + ex * dist, ep[1] + en * dist):
                    anchor = (ep, ang, dist)
                    break
            if anchor:
                break
        if anchor:
            break
    print(f"marina: Marina Road found, anchor={anchor}")
else:
    print("marina: MARINA ROAD NOT FOUND")

# ---- part budget ----
n_strips = sum(len(g[2]) for g in groups)
seg_pts = sum((len(l.split('|')[2]) // 6) for l in road_lines)
res = sum(1 for b in buildings if b["cls"] == "r")
com = sum(1 for b in buildings if b["cls"] == "c")
sch = sum(1 for b in buildings if b["cls"] == "s")
house_parts = res * 8.5
dock_parts = found * 5 + found * 6  # dock + boat clone
print(f"\npart budget: ground {n_strips}, road segs+joints ~{seg_pts * 2}, "
      f"houses ~{house_parts:.0f} ({res} res, {com} com, {sch} school), docks+boats ~{dock_parts}")
print(f"TOTAL ESTIMATE ~{n_strips + seg_pts * 2 + house_parts + com * 5 + sch * 3 + dock_parts + 6000:.0f} parts")
