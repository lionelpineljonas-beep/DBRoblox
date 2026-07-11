# Discovery Bay Golf Course Neighborhood — Roblox Build Plan

A reference plan for recreating the **Discovery Bay Golf & Country Club** community
(Discovery Bay, California) as a stylized, performant build in Roblox Studio.

> **Approach:** Build it by hand from a real map, block-style. Don't try to import a
> Gaussian splat or a photoscanned mesh of the whole area — it won't render as a splat
> in Roblox and would blow past mesh/performance limits. Use the map as a tracing
> reference and lay down roads, water, and simple houses.

---

## 1. What you're recreating (the character of the place)

Discovery Bay is a **Delta waterfront community** — its defining feature is water
everywhere: lagoons and canals connected to the San Joaquin Delta, with homes that
have **private boat docks in their backyards**. The golf course community sits inside
this, so your build has three signature ingredients:

- **The golf course** — an 18-hole, par-71 course (Ted Robinson, 1986) on ~225 acres,
  with a chain of **lakes and ponds winding through the fairways**. Homes line both
  sides of most fairways, water down the middle or along the edges.
- **The water/lagoon network** — winding channels with houses backing onto them, each
  with a dock and often a boat.
- **The clubhouse** — the social hub (real address: 1475 Clubhouse Dr), with tennis
  courts, a pool, and a marina nearby.

Nail those three and it will read instantly as Discovery Bay.

---

## 2. Get your reference map

Before placing a single part, pull up the real layout to trace:

1. **Google Maps → Satellite view** of Discovery Bay, CA. Center on the golf course
   (search "Discovery Bay Golf & Country Club").
2. Screenshot the top-down satellite view at a consistent zoom.
3. Optional: grab **Street View** stills of your street, the clubhouse entrance, and a
   couple of recognizable corners for later detailing.

**Trace trick:** In Roblox Studio you can't import a map as a floor texture easily, but
you can eyeball it. Put your screenshot on a second monitor (or print it) and rough out
the road grid on a large baseplate first.

---

## 3. Scale & baseplate

Pick a scale and stick to it — this is the single most important decision.

- **Recommended scale:** ~**1 stud = 1 foot** (Roblox studs are 1 ft each by default,
  so this is natural).
- A typical house lot (~60 ft wide) ≈ **60 studs**. A street ≈ **24–30 studs** wide
  including sidewalks. A golf fairway ≈ **40–70 studs** wide.
- The full country-club area is ~225 acres ≈ roughly **3,100 × 3,100 studs** at 1:1.
  That's large but doable. If it feels too big to fill, build at **1 stud = 2 ft**
  (half scale) to halve the footprint while keeping proportions.

Lay down one **oversized baseplate** (Terrain or a big Part) sized to your traced map,
then work in sections.

---

## 4. Build order (do it in this sequence)

Working outside-in and infrastructure-first keeps everything aligned:

1. **Water first.** Use Roblox **Terrain → Water** (or flat blue parts) to carve the
   main lagoon channels and the golf-course lakes. Water shapes the whole layout, so
   place it before roads and lots.
2. **Road grid.** Lay the main road loop and cul-de-sacs as flat dark parts. Discovery
   Bay streets curve to follow the water — don't make it a rigid square grid.
3. **Lot pads.** Drop a simple rectangular pad on each lot between the road and the
   water. This defines where houses go and keeps spacing even.
4. **Golf course.** Fill fairways with green terrain/parts between the housing rows;
   snake the lakes through them; add sand bunkers (tan parts) and a few greens.
5. **Houses.** Build **3–5 reusable house models**, then place and rotate copies. Vary
   roof color and orientation so it doesn't look copy-pasted. (See §5.)
6. **Docks & boats.** Add a small dock + optional boat on each waterfront lot — this is
   the detail that makes it unmistakably Discovery Bay.
7. **Landmarks.** Build the **clubhouse**, pool, tennis courts, and the marina as
   hero pieces with a bit more detail.
8. **Dressing.** Trees, streetlights, mailboxes, cars in driveways, fences.

---

## 5. Houses — keep them modular and cheap

Don't hand-build every house. Make a small kit:

- **3–5 base models** (single-story, two-story, larger "estate"). Each = simple boxes
  + a roof wedge. Keep part counts low.
- Turn each into a **Model** and reuse it. Use `Ctrl+D` to duplicate, then vary:
  wall color, roof color, and rotation.
- Waterfront homes face the **water side**; street homes face the road. Backyards on
  the water get the dock.
- **Performance:** houses are the #1 lag source in big neighborhoods. Prefer plain
  Parts over lots of MeshParts, keep them unanchored-free (anchor everything), and if
  you convert any photoscanned/splat mesh, **decimate it well under 10k triangles per
  MeshPart** (Roblox's cap) before importing.

---

## 6. Section-by-section plan

Break the neighborhood into zones and build one at a time so it never feels
overwhelming:

| Zone | What's there | Priority |
|------|--------------|----------|
| **Clubhouse core** | Clubhouse, pool, tennis, main entrance road | Build first — it's the identity anchor |
| **Fairway rows** | Housing lined along each golf hole, lakes between | Bulk of the build; repeat the house kit |
| **Lagoon streets** | Waterfront homes + docks + boats on the canals | The "Discovery Bay look" |
| **Marina** | Docks, moored boats, parking | Hero landmark |
| **Perimeter/entry** | Main road in, signage, boundary landscaping | Do last |

Finish one zone fully (roads → lots → houses → detail) before starting the next.

---

## 7. Performance checklist (Roblox-specific)

A whole neighborhood can tank framerate. Keep it playable:

- **Anchor everything** that doesn't move.
- Reuse models so Roblox can optimize identical instances.
- Keep total part count in check — favor bigger single parts over many tiny ones.
- Use **StreamingEnabled** (in Workspace properties) so distant areas load on demand —
  essential for a large map.
- Keep MeshParts light; avoid dense imported scans.
- Test on a mid-range device, not just your PC.

---

## 8. Where a captured 3D model *can* help

You don't need splats for the layout, but a photoscan/splat-to-mesh can be worth it for
**one or two hero landmarks** — e.g. the actual clubhouse — where recognizability
matters. Generate it, **convert splat → mesh**, decimate heavily, and import that single
MeshPart. Everything else stays hand-built.

---

## 9. Quick-start checklist

- [ ] Screenshot satellite + Street View references
- [ ] Choose scale (1 stud = 1 ft, or half-scale)
- [ ] Big baseplate sized to the map
- [ ] Carve water (lagoons + golf lakes)
- [ ] Lay curved road loop + cul-de-sacs
- [ ] Place lot pads
- [ ] Fill fairways, bunkers, greens
- [ ] Build 3–5 house models, place copies
- [ ] Add docks + boats on waterfront lots
- [ ] Build clubhouse, pool, tennis, marina
- [ ] Dress with trees, lights, cars
- [ ] Turn on StreamingEnabled, test performance

---

### Sources
- [Discovery Bay Golf & Country Club — official site](https://dbgcc.com/)
- [Discovery Bay Country Club — course details (Hole19)](https://www.hole19golf.com/courses/discovery-bay-country-club)
- [Discovery Bay Country Club — San Francisco Golf](https://www.sanfranciscogolf.com/courses/discovery-bay-country-club)
- [Discovery Bay Country Club neighborhood guide (Flyhomes)](https://flyhomes.com/neighborhood-guide/discovery-bay-country-club--discovery-bay--ca)
- [Discovery Bay Country Club homes (Redfin)](https://www.redfin.com/neighborhood/547072/CA/Discovery-Bay/Discovery-Bay-Country-Club)
