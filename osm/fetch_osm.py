"""Fetch real Discovery Bay, CA geometry from OpenStreetMap (Overpass API).

Saves raw JSON to osm/raw_*.json. Run once (cached); the layout generator reads the cache.
"""

import json
import time
import urllib.request
import urllib.parse
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OVERPASS = "https://overpass-api.de/api/interpreter"

# Discovery Bay, CA community bounding box (south, west, north, east)
BBOX = "37.880,-121.645,37.928,-121.565"


def overpass(query, out_name):
    path = os.path.join(HERE, out_name)
    if os.path.exists(path) and os.path.getsize(path) > 100:
        print(f"cached: {out_name} ({os.path.getsize(path)} bytes)")
        return
    data = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(OVERPASS, data=data,
                                 headers={"User-Agent": "discovery-bay-roblox-build/1.0"})
    with urllib.request.urlopen(req, timeout=300) as r:
        raw = r.read()
    with open(path, "wb") as f:
        f.write(raw)
    print(f"fetched: {out_name} ({len(raw)} bytes)")
    time.sleep(2)


# 1) infrastructure: roads, water, golf, schools, leisure, POIs
overpass(f"""
[out:json][timeout:180];
(
  way["highway"]({BBOX});
  way["natural"="water"]({BBOX});
  relation["natural"="water"]({BBOX});
  way["waterway"]({BBOX});
  way["leisure"~"golf_course|park|pitch|marina|swimming_pool"]({BBOX});
  relation["leisure"~"golf_course|park"]({BBOX});
  way["golf"]({BBOX});
  way["amenity"~"school|fuel|marina"]({BBOX});
  node["amenity"]({BBOX});
  node["shop"]({BBOX});
  way["landuse"~"retail|commercial|grass|meadow"]({BBOX});
);
out body;
>;
out skel qt;
""", "raw_infra.json")

# 2) buildings (fetched separately; can be large)
overpass(f"""
[out:json][timeout:300];
(
  way["building"]({BBOX});
);
out body;
>;
out skel qt;
""", "raw_buildings.json")

# quick summary
for name in ("raw_infra.json", "raw_buildings.json"):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        data = json.load(f)
    els = data.get("elements", [])
    ways = [e for e in els if e["type"] == "way"]
    nodes = [e for e in els if e["type"] == "node"]
    rels = [e for e in els if e["type"] == "relation"]
    print(f"{name}: {len(ways)} ways, {len(nodes)} nodes, {len(rels)} relations")
    if name == "raw_infra.json":
        from collections import Counter
        hw = Counter(w["tags"].get("highway") for w in ways if "tags" in w and "highway" in w.get("tags", {}))
        print("  highway types:", dict(hw))
        water = [w for w in ways if w.get("tags", {}).get("natural") == "water"]
        print("  water ways:", len(water))
        golf = [w for w in ways if "golf_course" in str(w.get("tags", {}))]
        print("  golf ways:", len(golf))
        schools = [e for e in els if "school" in str(e.get("tags", {}).get("amenity", ""))]
        print("  schools:", [(e.get("tags", {}).get("name"), e["type"]) for e in schools])
        named_pois = [(e.get("tags", {}).get("name"), e.get("tags", {}).get("amenity") or e.get("tags", {}).get("shop"))
                      for e in nodes if e.get("tags", {}).get("name")]
        print("  named POIs:", named_pois[:40])
