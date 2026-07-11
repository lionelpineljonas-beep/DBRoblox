"""Analyze road-endpoint gaps in the encoded data to tune the in-game gap filler.

A 'gap' = a road endpoint that doesn't touch any other road (> 4 ft away) but has one
within reach; the connector must roughly CONTINUE the road's direction (< 55 deg turn)
so cul-de-sacs never get bogus bridges to parallel back streets.
"""

import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "DiscoveryBayData.luau"), encoding="utf-8").read()
b36 = lambda s: int(s, 36)
m = re.search(r"D\.roads\s*=\s*\[\[(.*?)\]\]", src, re.S)

roads = []
for line in m.group(1).strip().split("\n"):
    name, cls, enc = line.split("|")
    pts = [(b36(enc[i:i + 3]), b36(enc[i + 3:i + 6])) for i in range(0, len(enc), 6)]
    if len(pts) >= 2:
        roads.append((name, cls, pts))

def dist_seg(px, pz, ax, az, bx, bz):
    abx, abz = bx - ax, bz - az
    l2 = abx * abx + abz * abz
    t = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((px - ax) * abx + (pz - az) * abz) / l2))
    cx, cz = ax + abx * t, az + abz * t
    return math.hypot(px - cx, pz - cz), cx, cz

MAXGAP = 45
connectors = []
for ri, (name, cls, pts) in enumerate(roads):
    for end in (0, len(pts) - 1):
        p = pts[end]
        nxt = pts[1] if end == 0 else pts[-2]
        # outgoing direction at this endpoint (pointing away from the road)
        dx, dz = p[0] - nxt[0], p[1] - nxt[1]
        dl = math.hypot(dx, dz) or 1
        dx, dz = dx / dl, dz / dl
        best = (1e9, None, None, None)
        for rj, (n2, c2, pts2) in enumerate(roads):
            if rj == ri:
                continue
            for i in range(len(pts2) - 1):
                a, b = pts2[i], pts2[i + 1]
                if min(abs(a[0] - p[0]), abs(b[0] - p[0])) > MAXGAP + 60:
                    continue
                if min(abs(a[1] - p[1]), abs(b[1] - p[1])) > MAXGAP + 60:
                    continue
                d, cx, cz = dist_seg(p[0], p[1], *a, *b)
                if d < best[0]:
                    best = (d, cx, cz, n2 or c2)
        d, cx, cz, target = best
        if 4 < d < MAXGAP:
            vx, vz = cx - p[0], cz - p[1]
            vl = math.hypot(vx, vz) or 1
            cosang = (vx * dx + vz * dz) / vl
            if cosang > 0.57:  # within ~55 degrees of "straight ahead"
                connectors.append((d, name or cls, target))

print(f"{len(connectors)} connectors would be built (gap 4..{MAXGAP} ft, forward-facing)")
buckets = {}
for d, *_ in connectors:
    k = int(d // 10) * 10
    buckets[k] = buckets.get(k, 0) + 1
print("gap sizes:", dict(sorted(buckets.items())))
for d, n, t in sorted(connectors, key=lambda x: -x[0])[:12]:
    print(f"  {d:5.1f} ft   {n!r:30} -> {t!r}")
