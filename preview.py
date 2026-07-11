"""Top-down preview of the OSM-based Discovery Bay build.

Renders osm/layout_debug.json (the exact data behind DiscoveryBayData.luau)
to preview.png. North = up. Run osm/generate.py first.
"""

import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
dbg = json.load(open(os.path.join(HERE, "osm", "layout_debug.json"), encoding="utf-8"))

W, H = dbg["W"], dbg["H"]
CELL = dbg["cell"]
cols, rows = dbg["cols"], dbg["rows"]
grid = dbg["grid"]  # row 0 = north

PX = 0.14  # image pixels per foot
IW, IH = int(W * PX) + 1, int(H * PX) + 1

CLASS_COLORS = {
    "w": (74, 143, 179), "l": (124, 158, 90), "f": (139, 195, 74),
    "g": (104, 190, 88), "t": (154, 205, 100), "b": (232, 220, 170),
    "p": (110, 170, 95), "c": (168, 162, 152),
}
ROAD_W = {"T": 44, "P": 40, "t": 34, "u": 26, "r": 26, "s": 18}


def XY(x, zn):
    return (x * PX, (H - zn) * PX)


img = Image.new("RGB", (IW, IH), CLASS_COLORS["l"])
dr = ImageDraw.Draw(img)

# terrain raster
cellpx = CELL * PX
for r in range(rows):
    row = grid[r]
    y0 = r * cellpx
    i = 0
    while i < cols:
        j = i
        while j + 1 < cols and row[j + 1] == row[i]:
            j += 1
        ch = row[i]
        if ch != "l":
            dr.rectangle([i * cellpx, y0, (j + 1) * cellpx, y0 + cellpx],
                         fill=CLASS_COLORS.get(ch, (255, 0, 255)))
        i = j + 1

# roads
for name, cls, width, pts in dbg["roads"]:
    w = max(1, int(ROAD_W.get(cls, 24) * PX))
    dr.line([XY(x, zn) for x, zn in pts], fill=(58, 58, 58), width=w, joint="curve")

# buildings
for b in dbg["buildings"]:
    x, zn, bw, bd, yaw = b["x"], b["z"], b["w"], b["d"], b["yaw"]
    # rectangle corners; long axis is perpendicular to front (front = short-axis normal)
    a = math.radians(yaw)
    # front dir (east, north) from yaw: yaw = atan2(-ex, en) => ex = -sin(a), en = cos(a)
    fx, fn = -math.sin(a), math.cos(a)
    lx, ln = -fn, fx  # long axis
    hw, hd = bw / 2, bd / 2
    corners = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        cxp = x + lx * hw * sx + fx * hd * sz
        czp = zn + ln * hw * sx + fn * hd * sz
        corners.append(XY(cxp, czp))
    col = {"r": (146, 104, 74), "c": (120, 110, 130), "s": (70, 110, 160)}.get(b["cls"], (150, 150, 150))
    if b["cls"] == "r" and b.get("dock") is not None:
        col = (192, 90, 58)
    dr.polygon(corners, fill=col)
    if b.get("dock") is not None:
        da = math.radians(b["dock"])
        dx, dn = -math.sin(da), math.cos(da)
        p0 = XY(x + dx * 20, zn + dn * 20)
        p1 = XY(x + dx * 55, zn + dn * 55)
        dr.line([p0, p1], fill=(122, 82, 48), width=2)

# landmarks + labels
try:
    font = ImageFont.truetype("arial.ttf", 26)
    font_sm = ImageFont.truetype("arial.ttf", 18)
except OSError:
    font = font_sm = ImageFont.load_default()

lm = dbg["landmarks"]
marks = []
if "clubhouse" in lm:
    marks.append(("CLUBHOUSE", lm["clubhouse"]["x"], lm["clubhouse"]["z"]))
if "plaza" in lm:
    marks.append(("Shell/Callahan's/JiuJitsu/Mart plaza", lm["plaza"]["x"], lm["plaza"]["z"]))
if "dbElementary" in lm:
    marks.append(("DB Elementary", lm["dbElementary"]["x"], lm["dbElementary"]["z"]))
if "timberPoint" in lm:
    marks.append(("Timber Point School", lm["timberPoint"]["x"], lm["timberPoint"]["z"]))
if "marina" in lm:
    marks.append(("Marina", lm["marina"]["x"], lm["marina"]["z"]))
for p in dbg["parks"]:
    marks.append((p["name"], p["x"], p["z"]))
for name, x, zn in marks:
    px, py = XY(x, zn)
    dr.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(200, 40, 40), outline="white")
    dr.text((px + 9, py - 11), name, fill=(20, 25, 30), font=font_sm)

# major road labels
for name, cls, width, pts in dbg["roads"]:
    if cls in ("t", "P", "T") and name and len(pts) > 2:
        mx, mz = pts[len(pts) // 2]
        dr.text(XY(mx, mz), name, fill=(30, 30, 30), font=font_sm)

# green flags
for g in dbg["greens"]:
    px, py = XY(g["x"], g["z"])
    dr.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(255, 235, 59))

dr.text((16, 12), "Discovery Bay, CA - OSM-accurate build preview (north = up). "
        "Red buildings = waterfront (dock+boat). Yellow dots = greens.",
        fill=(15, 20, 25), font=font)

img.save(os.path.join(HERE, "preview.png"))
res = len([b for b in dbg['buildings'] if b['cls'] == 'r'])
docks = len([b for b in dbg['buildings'] if b.get('dock') is not None])
print(f"image {IW}x{IH}; buildings {len(dbg['buildings'])} (res {res}, docks {docks}); "
      f"roads {len(dbg['roads'])}")
print("wrote preview.png")
