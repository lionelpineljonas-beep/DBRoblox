# Discovery Bay in Roblox — Step-by-Step Studio Build Checklist

A hands-on companion to the build plan and the three trace sketches. Work top to
bottom; finish each phase before starting the next. Check the boxes as you go.

**Reference files that go with this:**
- `discovery-bay-roblox-build-plan.md` — the overall strategy and reasoning
- `discovery-bay-layout-sketch.svg` — whole-neighborhood zone map + build order
- `discovery-bay-clubhouse-core-trace.svg` — Zone 1 street trace (clubhouse + golf)
- `discovery-bay-lagoon-marina-trace.svg` — lagoon + marina street trace
- Live reference: Google Maps → search "Discovery Bay Golf & Country Club" → Satellite

---

## Phase 0 — Project setup (once)

- [ ] New Baseplate in Roblox Studio.
- [ ] Decide scale: **1 stud = 1 foot** (recommended). Half-scale (1 stud = 2 ft) if
      the full area feels too big to fill.
- [ ] In **Workspace → Properties**, set `StreamingEnabled = true` (big map = essential).
- [ ] Create these Folders in Explorer to stay organized: `Water`, `Roads`, `Lots`,
      `Houses`, `Golf`, `Docks`, `Landmarks`, `Props`.
- [ ] Turn on **grid snap** (Model tab → set Rotate 15°, Move 1 stud) for clean roads.

---

## Phase 1 — Terrain shell & water (do first, it shapes everything)

The whole town is water-defined, so carve water before roads.

- [ ] Enlarge the baseplate (or add a big flat Part) to your map footprint.
- [ ] Open the **Terrain Editor**. Use **Sea Level / Add → Water** to lay the two Delta
      borders: **Indian Slough** (north) and **Old River** (east).
- [ ] Carve the **interior lagoon maze** — winding channels, not straight lines. Trace
      the finger shapes from the satellite. Keep water a consistent depth.
- [ ] Add the big **open bodies**: Willow Lake (center) and the golf-course ponds.
- [ ] Leave tan/green **land fingers (peninsulas)** between channels — these become
      the housing lots.

> Tip: If Terrain water is fiddly, flat semi-transparent blue Parts also work and are
> lighter on performance.

---

## Phase 2 — Road skeleton

Lay roads as thin flat dark Parts (or SmoothTerrain paths). Match the traces.

- [ ] **Discovery Bay Blvd** — the main north–south spine. Place this first.
- [ ] **Willow Lake Rd** — east–west / curving spine serving the lagoon district.
- [ ] **Clubhouse Dr** — the loop through the golf core (west entry → past the holes →
      clubhouse → up the east side).
- [ ] **Cherry Hills Dr** — east spine along the golf course.
- [ ] Add the **cul-de-sac courts** branching off the spines. Name them as you place
      them so you don't lose track:
  - Golf core: Fairway Ct, Hampton Ct, Augusta Ct, Oakmont Ct, Gateway Ct,
    Greenfield Way, Pinehurst Ct, Prestwick Dr, Wayfarer Ct, Azure Ct, St Andrews Ct.
  - Lagoon: Starboard Dr, Starfish Ct, Drakes Dr, Drakes Ct, Marlin Dr, Marlin Pl.
- [ ] Add sidewalks as thin light Parts along the main roads (optional but sells it).

---

## Phase 3 — Lot pads

- [ ] Drop a simple rectangular pad (~60 × 40 studs) on each lot, between road and water.
- [ ] Waterfront pads face the **water**; street pads face the **road**.
- [ ] Even spacing beats realism — keep pads regular so houses line up.

---

## Phase 4 — House kit (build once, reuse everywhere)

- [ ] Build **3–5 base house models**: 1-story, 2-story, and a larger "estate."
      Each = boxes for walls + a wedge/roof. Keep part counts low.
- [ ] Group each into a **Model**, rename it, and (optional) turn it into a reusable
      asset via **right-click → Save to Roblox** or a local package.
- [ ] Place copies with `Ctrl+D`. On each copy vary: **wall color, roof color, rotation.**
- [ ] **Anchor every part** (select all → Anchored = true).

---

## Phase 5 — Zone builds (one zone fully, then the next)

Follow the badge order on `discovery-bay-layout-sketch.svg`.

**Zone 1 — Clubhouse & golf core** (use the core trace)
- [ ] Lay the Clubhouse Dr loop + Discovery Bay Blvd (already in Phase 2).
- [ ] Build the **clubhouse building + parking lot** (your hero piece).
- [ ] Add each court with its house row, one court at a time.
- [ ] Fill **fairways** (green Parts/terrain) and **ponds** between the courts.
- [ ] Add sand **bunkers** (tan) and a few flat **greens**; cart-path lines if you want.
- [ ] Your own house on **Cherry Hills Dr** goes here — worth extra detail.

**Zone 2 — Fairway housing rows** — repeat the house kit along the remaining holes.

**Zone 3 — Lagoon streets** (use the lagoon/marina trace)
- [ ] Place house rows along each peninsula.
- [ ] Add a **dock + small boat** on every waterfront lot. *This is the signature move.*

**Zone 4 — Marina** — covered slip structures, moored boats, boat launch ramp, parking.

**Zone 5 — Perimeter / entry** — main entry road, the Discovery Bay Lighthouse at the
north Delta entrance, boundary landscaping and signage.

---

## Phase 6 — Set dressing

- [ ] Trees (cluster near the golf course and along streets).
- [ ] Streetlights, mailboxes, fences, driveways, a few parked cars.
- [ ] Extra boats moored in the lagoons and Willow Lake.
- [ ] Optional: a simple clubhouse interior if players will go inside.

---

## Phase 7 — Performance & test pass

- [ ] Confirm **everything is anchored**.
- [ ] Confirm identical houses are true **copies** of the same model (helps Roblox optimize).
- [ ] Keep part counts sane — merge tiny decorative parts where possible.
- [ ] Verify `StreamingEnabled` is on.
- [ ] **Playtest on a mid-range device**, not just your PC — walk the whole map, watch
      the framerate, and check you can't fall through water/roads (add collision where needed).

---

## Optional — one photoreal landmark

If you want the actual clubhouse (or your own house) to look real rather than blocky:
generate a 3D model from a photo, **convert the splat to a mesh**, decimate it to well
under **10,000 triangles**, and import that single MeshPart. Keep everything else
hand-built — a whole neighborhood of scanned meshes will not perform.

---

### Quick daily loop
Pick one court → roads → lots → houses → water/dock detail → move on. Small, complete
chunks keep a big map from feeling overwhelming and always leave you with something that
looks finished.
