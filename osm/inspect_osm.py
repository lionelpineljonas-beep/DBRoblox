import json, os
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(HERE, "raw_infra.json"), encoding="utf-8"))
els = data["elements"]
ways = {e["id"]: e for e in els if e["type"] == "way"}
nodes = {e["id"]: e for e in els if e["type"] == "node"}
rels = [e for e in els if e["type"] == "relation"]

print("== RELATIONS ==")
for r in rels:
    t = r.get("tags", {})
    print(r["id"], t.get("type"), t.get("natural") or t.get("leisure") or t.get("landuse"),
          t.get("name"), "members:", len(r.get("members", [])))

print("\n== WATER ways (closed?) ==")
wtr = [w for w in ways.values() if w.get("tags", {}).get("natural") == "water"]
for w in wtr[:40]:
    nds = w["nodes"]
    print(w["id"], w.get("tags", {}).get("name"), "closed" if nds[0] == nds[-1] else "OPEN", len(nds), "pts")

print("\n== WATERWAY lines ==")
ww = [w for w in ways.values() if "waterway" in w.get("tags", {})]
print(Counter(w["tags"]["waterway"] for w in ww))
for w in ww[:10]:
    print(" ", w["tags"].get("waterway"), w["tags"].get("name"))

print("\n== GOLF / LEISURE / LANDUSE ==")
for w in ways.values():
    t = w.get("tags", {})
    if "golf" in t or t.get("leisure") in ("golf_course", "park", "marina") or t.get("landuse") in ("retail", "commercial"):
        print(w["id"], t.get("leisure") or t.get("landuse") or ("golf=" + t.get("golf", "")), t.get("name"))

print("\n== NAMED ROADS ==")
names = Counter()
for w in ways.values():
    t = w.get("tags", {})
    if "highway" in t and t.get("name"):
        names[(t["name"], t["highway"])] += 1
for (n, h), c in sorted(names.items()):
    print(f"  {n} [{h}] x{c}")

print("\n== SCHOOLS / notable ==")
for e in els:
    t = e.get("tags", {})
    if t.get("amenity") in ("school", "fuel", "marina") or t.get("leisure") == "marina":
        loc = f"({e.get('lat')},{e.get('lon')})" if e["type"] == "node" else "way"
        print(" ", e["type"], t.get("amenity") or t.get("leisure"), t.get("name"), loc)
