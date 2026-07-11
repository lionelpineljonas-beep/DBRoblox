"""Convert raw OSM data for Discovery Bay, CA into compact layout data for the Roblox build.

Outputs:
  ../DiscoveryBayData.luau  - ModuleScript with encoded terrain raster, roads, buildings, landmarks
  layout_debug.json         - full-fidelity sidecar used by preview_v2.py
  (run fetch_osm.py first; raw JSON is cached in this folder)

Coordinate frame: local feet. x = feet east of west edge, zn = feet north of south edge.
Roblox mapping (in build.luau): world X = x * scale, world Z = (H - zn) * scale  (north = -Z).
"""

import json
import math
import os
from collections import defaultdict

import numpy as np
import shapely
from shapely.geometry import (LineString, MultiPolygon, Point, Polygon, box)
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

CELL_FT = 25          # terrain raster cell size
SIMPLIFY_ROAD = 4.0   # ft tolerance
MARGIN = 350          # ft of margin around content bounds

B36 = "0123456789abcdefghijklmnopqrstuvwxyz"


def b36(n, width):
    n = max(0, int(round(n)))
    s = ""
    while n > 0:
        s = B36[n % 36] + s
        n //= 36
    s = s or "0"
    assert len(s) <= width, f"{n} does not fit in {width} base36 chars"
    return s.rjust(width, "0")


# ---------------------------------------------------------------- load + project
def load(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return json.load(f)["elements"]


infra = load("raw_infra.json")
bldg_raw = load("raw_buildings.json")

nodes = {}
for e in infra + bldg_raw:
    if e["type"] == "node":
        nodes[e["id"]] = (e["lon"], e["lat"])

LAT0 = 37.905
LON0 = -121.605
FT_PER_DEG_LAT = 364000.0
FT_PER_DEG_LON = FT_PER_DEG_LAT * math.cos(math.radians(LAT0))


def proj(lon, lat):
    return ((lon - LON0) * FT_PER_DEG_LON, (lat - LAT0) * FT_PER_DEG_LAT)


def way_coords(way):
    pts = []
    for nid in way["nodes"]:
        if nid in nodes:
            pts.append(proj(*nodes[nid]))
    return pts


ways_infra = {e["id"]: e for e in infra if e["type"] == "way"}
rels_infra = [e for e in infra if e["type"] == "relation"]
ways_bldg = [e for e in bldg_raw if e["type"] == "way"]

# ---------------------------------------------------------------- water polygons
def stitch_rings(member_ways):
    """Join open member ways of a multipolygon into closed rings."""
    segs = [list(w) for w in member_ways if len(w) >= 2]
    rings = []
    while segs:
        ring = segs.pop()
        changed = True
        while changed and ring[0] != ring[-1]:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == ring[-1]:
                    ring += s[1:]; segs.pop(i); changed = True; break
                if s[-1] == ring[-1]:
                    ring += list(reversed(s[:-1])); segs.pop(i); changed = True; break
                if s[-1] == ring[0]:
                    ring = s + ring[1:]; segs.pop(i); changed = True; break
                if s[0] == ring[0]:
                    ring = list(reversed(s)) + ring[1:]; segs.pop(i); changed = True; break
        if len(ring) >= 4 and ring[0] == ring[-1]:
            rings.append(ring)
    return rings


water_polys = []
for w in ways_infra.values():
    t = w.get("tags", {})
    if t.get("natural") == "water" or t.get("golf") == "lateral_water_hazard":
        pts = way_coords(w)
        if len(pts) >= 4 and pts[0] == pts[-1]:
            p = Polygon(pts)
            if p.is_valid and p.area > 100:
                water_polys.append(p)

for r in rels_infra:
    if r.get("tags", {}).get("natural") != "water":
        continue
    outers, inners = [], []
    for m in r.get("members", []):
        if m["type"] != "way" or m["ref"] not in ways_infra:
            continue
        pts = way_coords(ways_infra[m["ref"]])
        (outers if m.get("role") != "inner" else inners).append(pts)
    outer_rings = stitch_rings(outers)
    inner_rings = stitch_rings(inners)
    for ring in outer_rings:
        holes = [h for h in inner_rings if Polygon(ring).contains(Point(h[0]))]
        p = Polygon(ring, holes)
        if not p.is_valid:
            p = p.buffer(0)
        if p.area > 100:
            water_polys.append(p)

WATER = unary_union(water_polys)
print(f"water: {len(water_polys)} polys, union area {WATER.area/43560:.0f} acres")

# ---------------------------------------------------------------- golf + parks + commercial
def polys_where(pred):
    out = []
    for w in ways_infra.values():
        t = w.get("tags", {})
        if pred(t):
            pts = way_coords(w)
            if len(pts) >= 4 and pts[0] == pts[-1]:
                p = Polygon(pts)
                if p.is_valid and p.area > 50:
                    out.append(p)
    return out


GOLF_FAIRWAY = unary_union(polys_where(lambda t: t.get("golf") in ("fairway", "driving_range")))
GOLF_GREEN = unary_union(polys_where(lambda t: t.get("golf") == "green"))
GOLF_TEE = unary_union(polys_where(lambda t: t.get("golf") == "tee"))
GOLF_BUNKER = unary_union(polys_where(lambda t: t.get("golf") == "bunker"))
PARKS = unary_union(polys_where(lambda t: t.get("leisure") in ("park", "pitch")))
COMMERCIAL_LAND = unary_union(polys_where(lambda t: t.get("landuse") in ("retail", "commercial")))
MARINA_POLYS = polys_where(lambda t: t.get("leisure") == "marina")
SCHOOL_POLYS = polys_where(lambda t: t.get("amenity") == "school")

# the marina basin is wet slips — include it as water so slips and boats float
if MARINA_POLYS:
    WATER = unary_union([WATER] + MARINA_POLYS)
    print(f"water + marina basin: {WATER.area/43560:.0f} acres")

golf_all = unary_union([g for g in [GOLF_FAIRWAY, GOLF_GREEN, GOLF_TEE, GOLF_BUNKER] if not g.is_empty])

greens = [] if GOLF_GREEN.is_empty else (
    list(GOLF_GREEN.geoms) if GOLF_GREEN.geom_type == "MultiPolygon" else [GOLF_GREEN])
holes_lines = []
for w in ways_infra.values():
    t = w.get("tags", {})
    if t.get("golf") == "hole":
        pts = way_coords(w)
        if len(pts) >= 2:
            holes_lines.append((t.get("ref", "?"), pts))
cartpaths = []
for w in ways_infra.values():
    if w.get("tags", {}).get("golf") == "cartpath":
        pts = way_coords(w)
        if len(pts) >= 2:
            cartpaths.append(LineString(pts).simplify(SIMPLIFY_ROAD).coords[:])
print(f"golf: fairway {GOLF_FAIRWAY.area/43560:.0f}ac, {len(greens)} greens, "
      f"{len(holes_lines)} holes, {len(cartpaths)} cartpaths")

# ---------------------------------------------------------------- roads
ROAD_CLASSES = {
    "trunk": ("T", 44), "trunk_link": ("T", 36), "primary": ("P", 40),
    "tertiary": ("t", 34), "tertiary_link": ("t", 28),
    "unclassified": ("u", 26), "residential": ("r", 26),
    "track": ("k", 12),  # farm tracks: fill the rural gaps between subdivisions
}
roads = []  # (name, classChar, width, pts)
for w in ways_infra.values():
    t = w.get("tags", {})
    hw = t.get("highway")
    if hw in ROAD_CLASSES:
        cls, width = ROAD_CLASSES[hw]
    elif hw == "service":
        # ALL service ways (parking aisles, alleys, marina lanes) — they fill the gaps
        cls, width = ("s", 18 if t.get("name") else 14)
    else:
        continue
    pts = way_coords(w)
    if len(pts) >= 2:
        line = LineString(pts).simplify(SIMPLIFY_ROAD)
        roads.append([t.get("name", ""), cls, width, list(line.coords)])

# ---------------------------------------------------------------- content bounds
# Bounds come from the built community itself (buildings + golf + marina), NOT from
# roads — tertiary roads run miles into Delta farmland and would balloon the world.
content = []
for b in ways_bldg:
    if b.get("nodes"):
        nid = b["nodes"][0]
        if nid in nodes:
            content.append(proj(*nodes[nid]))
if not golf_all.is_empty:
    content += list(golf_all.envelope.exterior.coords)
for mp in MARINA_POLYS:
    content += list(mp.envelope.exterior.coords)

xs = [p[0] for p in content]
zs = [p[1] for p in content]
X0, X1 = min(xs) - MARGIN, max(xs) + MARGIN + 900  # extra east so Old River shows
Z0, Z1 = min(zs) - MARGIN, max(zs) + MARGIN + 500  # extra north for Indian Slough
W_FT = X1 - X0
H_FT = Z1 - Z0
BOUNDS = box(X0, Z0, X1, Z1)
print(f"bounds: {W_FT:.0f} x {H_FT:.0f} ft ({W_FT/5280:.2f} x {H_FT/5280:.2f} mi)")


def loc(p):  # project point into local frame (x east from west edge, zn north from south edge)
    return (p[0] - X0, p[1] - Z0)


# clip + localize everything
def clip_poly(g):
    c = g.intersection(BOUNDS)
    return c if not c.is_empty else None


WATER = clip_poly(WATER)
roads2 = []
for name, cls, width, pts in roads:
    line = LineString(pts).intersection(BOUNDS)
    geoms = list(line.geoms) if line.geom_type == "MultiLineString" else (
        [line] if line.geom_type == "LineString" and len(line.coords) >= 2 else [])
    for g in geoms:
        roads2.append([name, cls, width, [loc(p) for p in g.coords]])
roads = roads2
print(f"roads kept: {len(roads)} ways")

# ---------------------------------------------------------------- buildings
POIS = []
for e in infra:
    if e["type"] == "node" and e.get("tags", {}).get("name"):
        t = e["tags"]
        kind = t.get("amenity") or t.get("shop") or t.get("leisure") or ""
        POIS.append({"name": t["name"], "kind": kind, "pt": loc(proj(e["lon"], e["lat"]))})

valero = next((p for p in POIS if p["name"] == "Valero"), None)
school_node = next((p for p in POIS if "Elementary" in p["name"]), None)

water_prep = shapely.prepared.prep(WATER) if WATER else None
WATER_BOUNDARY = WATER.boundary if WATER else None

SKIP_BUILDING = {"garage", "garages", "shed", "carport", "roof"}
buildings = []
clubhouse_cand = None
for wy in ways_bldg:
    t = wy.get("tags", {})
    btype = t.get("building", "yes")
    if btype in SKIP_BUILDING:
        continue
    pts = [proj(*nodes[n]) for n in wy["nodes"] if n in nodes]
    if len(pts) < 4:
        continue
    poly = Polygon(pts)
    if not poly.is_valid:
        poly = poly.buffer(0)
    if poly.is_empty or poly.area < 250:  # skip tiny sheds
        continue
    if not BOUNDS.contains(poly.centroid):
        continue
    # oriented rectangle
    mrr = poly.minimum_rotated_rectangle
    rc = list(mrr.exterior.coords)
    e1 = math.dist(rc[0], rc[1])
    e2 = math.dist(rc[1], rc[2])
    if e1 >= e2:
        w_ft, d_ft = e1, e2
        ax = (rc[1][0] - rc[0][0], rc[1][1] - rc[0][1])
    else:
        w_ft, d_ft = e2, e1
        ax = (rc[2][0] - rc[1][0], rc[2][1] - rc[1][1])
    axlen = math.hypot(*ax) or 1
    ax = (ax[0] / axlen, ax[1] / axlen)  # long-axis unit vector (east, north)
    cx, cn = poly.centroid.x, poly.centroid.y
    area = poly.area

    cls = "r"
    if t.get("building") in ("school",) or any(sp.contains(poly.centroid) for sp in SCHOOL_POLYS):
        cls = "s"
    elif t.get("building") in ("retail", "commercial", "supermarket") or (
            not COMMERCIAL_LAND.is_empty and COMMERCIAL_LAND.contains(poly.centroid)):
        cls = "c"
    if not golf_all.is_empty and golf_all.distance(poly.centroid) < 250 and area > 4000:
        if clubhouse_cand is None or area > clubhouse_cand[0]:
            clubhouse_cand = (area, poly, ax, w_ft, d_ft)
        continue  # hero clubhouse built separately

    buildings.append({
        "poly": poly, "c": (cx, cn), "w": w_ft, "d": d_ft, "ax": ax,
        "cls": cls, "area": area,
    })
print(f"buildings kept: {len(buildings)}  (clubhouse candidate: "
      f"{clubhouse_cand[0]:.0f} sqft)" if clubhouse_cand else "NO CLUBHOUSE FOUND")

# nearest-road front direction + dock detection
# NOTE: `roads` pts are in the LOCAL frame; WATER is in the GLOBAL frame. Translation
# only, so directions are identical — just query each with the matching point.
road_lines = [(LineString(pts), name, cls) for name, cls, width, pts in roads if len(pts) >= 2]
road_tree = shapely.STRtree([rl[0] for rl in road_lines])

DOCK_RANGE = 140
for b in buildings:
    b["c"] = loc(b["c"])

for b in buildings:
    cx, cn = b["c"]
    ptL = Point(cx, cn)             # local frame (roads)
    pt = Point(cx + X0, cn + Z0)    # global frame (water)
    # front = rectangle normal (short-axis direction) pointing toward nearest road
    nearest_idx = road_tree.nearest(ptL)
    nline = road_lines[nearest_idx][0]
    np_pt = nline.interpolate(nline.project(ptL))
    to_road = (np_pt.x - ptL.x, np_pt.y - ptL.y)
    nx, nn = -b["ax"][1], b["ax"][0]  # short-axis normal candidates: ±(nx,nn)
    if to_road[0] * nx + to_road[1] * nn < 0:
        nx, nn = -nx, -nn
    front = (nx, nn)
    yaw = math.degrees(math.atan2(-front[0], front[1])) % 360  # for CFrame.Angles(0,yaw,0)

    dock_yaw = None
    if b["cls"] == "r" and WATER is not None:
        dwater = WATER.distance(pt)
        if dwater < DOCK_RANGE:
            wp = shapely.ops.nearest_points(pt, WATER_BOUNDARY)[1]
            dvec = (wp.x - pt.x, wp.y - pt.y)
            dl = math.hypot(*dvec)
            if dl > 1:
                dv = (dvec[0] / dl, dvec[1] / dl)
                dock_yaw = math.degrees(math.atan2(-dv[0], dv[1])) % 360
    b["yaw"] = yaw
    b["dock_yaw"] = dock_yaw

res_count = sum(1 for b in buildings if b["cls"] == "r")
dock_count = sum(1 for b in buildings if b["dock_yaw"] is not None)
print(f"residential {res_count}, waterfront (dock) {dock_count}, "
      f"commercial {sum(1 for b in buildings if b['cls']=='c')}, school {sum(1 for b in buildings if b['cls']=='s')}")

# ---------------------------------------------------------------- terrain raster
cols = int(math.ceil(W_FT / CELL_FT))
rows = int(math.ceil(H_FT / CELL_FT))
print(f"raster: {cols} x {rows} cells @ {CELL_FT} ft")

xs = (np.arange(cols) + 0.5) * CELL_FT + X0
zs = (np.arange(rows) + 0.5) * CELL_FT + Z0
XX, ZZ = np.meshgrid(xs, zs)  # [row, col]; row 0 = SOUTH edge
flatx, flatz = XX.ravel(), ZZ.ravel()

grid = np.full((rows, cols), "l", dtype="U1")


def paint(geom, ch):
    if geom is None or geom.is_empty:
        return
    mask = shapely.contains_xy(geom, flatx, flatz).reshape(rows, cols)
    grid[mask] = ch


paint(PARKS, "p")
paint(COMMERCIAL_LAND, "c")
paint(GOLF_FAIRWAY, "f")
paint(GOLF_TEE, "t")
paint(GOLF_GREEN, "g")
paint(GOLF_BUNKER, "b")
paint(WATER, "w")

unique, counts = np.unique(grid, return_counts=True)
print("raster classes:", dict(zip(unique.tolist(), counts.tolist())))

# encode: row groups (identical consecutive rows merged), rows from NORTH (row index reversed)
# group: "<span b36 1ch><runs>" runs = "<count b36 2ch><class 1ch>"*, groups joined by ';'
grid_n = grid[::-1]  # row 0 = north
groups = []
r = 0
while r < rows:
    r2 = r
    while r2 + 1 < rows and np.array_equal(grid_n[r2 + 1], grid_n[r]):
        r2 += 1
    span = r2 - r + 1
    row = grid_n[r]
    runs = []
    i = 0
    while i < cols:
        j = i
        while j + 1 < cols and row[j + 1] == row[i]:
            j += 1
        runs.append(b36(j - i + 1, 2) + row[i])
        i = j + 1
    while span > 0:
        s = min(span, 35)
        groups.append(b36(s, 1) + "".join(runs))
        span -= s
    r = r2 + 1
raster_str = ";".join(groups)
print(f"raster encoded: {len(raster_str)} chars, {len(groups)} row-groups")

# ---------------------------------------------------------------- encode roads
def enc_pt(x, zn):
    return b36(min(max(x, 0), W_FT), 3) + b36(min(max(zn, 0), H_FT), 3)


road_chunks = []
for name, cls, width, pts in roads:
    line = LineString(pts).simplify(SIMPLIFY_ROAD)
    enc = "".join(enc_pt(x, zn) for x, zn in line.coords)
    road_chunks.append(f"{name}|{cls}|{enc}")
roads_str = "\n".join(road_chunks)

cart_chunks = []
for pts in cartpaths:
    lpts = [loc(p) for p in pts]
    lpts = [p for p in lpts if 0 <= p[0] <= W_FT and 0 <= p[1] <= H_FT]
    if len(lpts) >= 2:
        cart_chunks.append("".join(enc_pt(x, zn) for x, zn in lpts))
cart_str = "\n".join(cart_chunks)

# ---------------------------------------------------------------- encode buildings
# record: x(3) zn(3) w(2) d(2) yaw(2, whole degrees base36) cls(1) dock(2: yaw or '--')
def enc_yaw(deg):
    return b36(int(round(deg)) % 360, 2)


recs = []
for b in buildings:
    x, zn = b["c"]
    if not (0 <= x <= W_FT and 0 <= zn <= H_FT):
        continue
    rec = (b36(x, 3) + b36(zn, 3) + b36(min(b["w"], 1200), 2) + b36(min(b["d"], 1200), 2)
           + enc_yaw(b["yaw"]) + b["cls"]
           + (enc_yaw(b["dock_yaw"]) if b["dock_yaw"] is not None else "--"))
    assert len(rec) == 15
    recs.append(rec)
bldg_str = "".join(recs)
print(f"buildings encoded: {len(recs)} records, {len(bldg_str)} chars")

# ---------------------------------------------------------------- landmarks
def lm_rect(poly, ax, w, d):
    c = loc((poly.centroid.x, poly.centroid.y))
    yaw = math.degrees(math.atan2(-(-ax[1]), ax[0])) % 360  # front along short axis — refined in Luau
    return {"x": round(c[0]), "z": round(c[1]), "w": round(w), "d": round(d), "yaw": round(yaw)}


landmarks = {}
if clubhouse_cand:
    _, ch_poly, ch_ax, ch_w, ch_d = clubhouse_cand
    c = loc((ch_poly.centroid.x, ch_poly.centroid.y))
    front = (-ch_ax[1], ch_ax[0])
    yaw = math.degrees(math.atan2(-front[0], front[1])) % 360
    landmarks["clubhouse"] = {"x": round(c[0]), "z": round(c[1]), "w": round(ch_w),
                              "d": round(ch_d), "yaw": round(yaw)}
if valero:
    landmarks["plaza"] = {"x": round(valero["pt"][0]), "z": round(valero["pt"][1])}
if school_node:
    landmarks["dbElementary"] = {"x": round(school_node["pt"][0]), "z": round(school_node["pt"][1])}
for sp in SCHOOL_POLYS:
    c = loc((sp.centroid.x, sp.centroid.y))
    landmarks.setdefault("timberPoint", {"x": round(c[0]), "z": round(c[1])})
if MARINA_POLYS:
    mp = max(MARINA_POLYS, key=lambda p: p.area)
    c = loc((mp.centroid.x, mp.centroid.y))
    mb = mp.bounds
    landmarks["marina"] = {"x": round(c[0]), "z": round(c[1]),
                           "w": round(mb[2] - mb[0]), "d": round(mb[3] - mb[1])}

green_pts = [loc((g.centroid.x, g.centroid.y)) for g in greens]
park_list = []
for w in ways_infra.values():
    t = w.get("tags", {})
    if t.get("leisure") == "park" and t.get("name"):
        pts = way_coords(w)
        if len(pts) >= 4:
            p = Polygon(pts)
            c = loc((p.centroid.x, p.centroid.y))
            park_list.append({"name": t["name"], "x": round(c[0]), "z": round(c[1]),
                              "r": round(math.sqrt(p.area / math.pi))})

poi_list = []
for p in POIS:
    x, zn = p["pt"]
    if 0 <= x <= W_FT and 0 <= zn <= H_FT:
        poi_list.append({"name": p["name"], "kind": p["kind"], "x": round(x), "z": round(zn)})

# ---------------------------------------------------------------- emit Luau module
def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


lines = []
lines.append("-- AUTO-GENERATED by osm/generate.py from OpenStreetMap data (Discovery Bay, CA).")
lines.append("-- (c) OpenStreetMap contributors, ODbL. Do not hand-edit; re-run the generator.")
lines.append("local D = {}")
lines.append(f"D.widthFt = {W_FT:.0f}")
lines.append(f"D.heightFt = {H_FT:.0f}")
lines.append(f"D.cellFt = {CELL_FT}")
lines.append(f"D.cols = {cols}")
lines.append(f"D.rows = {rows}")
lines.append("D.raster = [[" + raster_str + "]]")
lines.append("D.roads = [[\n" + roads_str + "\n]]")
lines.append("D.cartpaths = [[\n" + cart_str + "\n]]")
lines.append("D.buildings = [[" + bldg_str + "]]")
# small tables as literal Lua
def to_lua(v, indent=0):
    pad = "  " * indent
    if isinstance(v, dict):
        inner = ", ".join(f"{k} = {to_lua(x)}" if k.isidentifier() else f"[{lua_str(k)}] = {to_lua(x)}"
                          for k, x in v.items())
        return "{ " + inner + " }"
    if isinstance(v, list):
        return "{ " + ", ".join(to_lua(x) for x in v) + " }"
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, float):
        return f"{v:.1f}"
    return str(v)


lines = [l for l in lines if l != ""]
lines.append("D.landmarks = " + to_lua(landmarks))
lines.append("D.greens = " + to_lua([{"x": round(x), "z": round(z)} for x, z in green_pts]))
lines.append("D.parks = " + to_lua(park_list))
lines.append("D.pois = " + to_lua(poi_list))
lines.append("return D")

out = "\n".join(lines)
out_path = os.path.join(ROOT, "DiscoveryBayData.luau")
with open(out_path, "w", encoding="utf-8") as f:
    f.write(out)
print(f"\nwrote {out_path}: {len(out)} chars ({len(out)/1024:.0f} KB)"
      + ("  ⚠ OVER 195K SCRIPT LIMIT" if len(out) > 195000 else "  (fits in one ModuleScript)"))

# ---------------------------------------------------------------- debug sidecar for preview
debug = {
    "W": W_FT, "H": H_FT, "cell": CELL_FT, "cols": cols, "rows": rows,
    "roads": [[name, cls, width, pts] for name, cls, width, pts in roads],
    "buildings": [{"x": b["c"][0], "z": b["c"][1], "w": b["w"], "d": b["d"],
                   "yaw": b["yaw"], "cls": b["cls"],
                   "dock": b["dock_yaw"]} for b in buildings],
    "landmarks": landmarks, "greens": [{"x": x, "z": z} for x, z in green_pts],
    "parks": park_list, "pois": poi_list,
    "grid": ["".join(row) for row in grid_n.tolist()],  # row 0 = north
}
with open(os.path.join(HERE, "layout_debug.json"), "w", encoding="utf-8") as f:
    json.dump(debug, f)
print("wrote layout_debug.json")
