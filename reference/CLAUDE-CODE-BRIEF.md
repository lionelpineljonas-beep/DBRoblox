# Build Brief for Claude Code — Discovery Bay in Roblox

**You (Claude Code) are being asked to generate the code that builds a stylized
recreation of the Discovery Bay Golf & Country Club neighborhood (Discovery Bay,
California) inside Roblox Studio.**

This folder contains everything you need. Read `discovery-bay-layout.json` first — it's
the machine-readable source of truth for geometry. The `.svg` files are visual traces of
the real satellite layout. The `.md` files explain the design intent.

---

## The core constraint (read this first)

You cannot drive Roblox Studio directly. Studio doesn't expose a scripting API to
external tools, and a Gaussian splat / photoscan of the town **cannot render natively in
Roblox** anyway. So the deliverable is **Luau code that the user runs inside Studio** to
generate the world procedurally.

Two supported workflows — pick one and set it up:

1. **Command-bar / Script build (simplest).** Produce a single Luau build script the
   user pastes into Studio's **Command Bar** (or drops in as a `Script` and runs once).
   It reads an embedded layout table and instantiates Parts/Models. Best for quick
   iteration.
2. **Rojo project (recommended for a real project).** Scaffold a Rojo project
   (`default.project.json`, `src/`) so the build lives in version control and syncs into
   Studio. Put the generator in a `ServerScriptService` build script + `ReplicatedStorage`
   modules.

Deliver #1 at minimum; offer #2 if the user wants a maintainable project.

---

## What to build (functional goal)

A performant, stylized, **hand-built-looking** neighborhood — NOT a photoscan. From the
layout spec, procedurally generate:

- **Water**: Delta borders (Indian Slough N, Old River E), Willow Lake, golf ponds, and
  the interior lagoon channels between land peninsulas.
- **Roads**: the four spines (Discovery Bay Blvd, Willow Lake Rd, Clubhouse Dr loop,
  Cherry Hills Dr) as flat parts following the waypoint polylines, plus cul-de-sac courts.
- **Lots**: pads along each road, pattern = `road → house row → fairway/lagoon → next row`.
- **Houses**: 3–5 reusable models, placed as duplicated instances with varied
  color/rotation.
- **Golf course**: fairway ribbons, ponds, bunkers, greens in the SE core.
- **Docks + boats**: on every waterfront lot (the signature Discovery Bay detail).
- **Landmarks**: clubhouse + parking (hero), community center, marina slips, boat launch,
  lighthouse.
- **Required businesses (must be present — user requirement)**: **Callahan's Coffee and
  Cones**, **Discovery Bay Jiu Jitsu**, **Shell Gas Station** (canopy + pumps + kiosk),
  and **Convenience Mart**. See `requiredBusinesses` in the layout JSON. Build each as a
  small named model with a `SurfaceGui`/sign label so it's identifiable in-world. Do not
  omit any of them.

---

## Technical approach & requirements

- **Coordinate system**: use the grid + `worldScale` defined in `discovery-bay-layout.json`.
  Convert grid `[x,z]` → `Vector3` consistently. Elevations are in the spec.
- **Roads from polylines**: interpolate along each road's `waypoints`, placing/stretching
  thin Parts (or one CFrame-stretched Part per segment) at `widthStuds`. Round the joints.
- **Reuse, don't duplicate geometry**: build each house/dock once as a `Model` in
  `ReplicatedStorage`, then `:Clone()` for every placement so Roblox can instance them.
- **Organize** everything into Folders: `Water, Roads, Lots, Houses, Golf, Docks,
  Landmarks, Props`.
- **Anchor every part.** Non-negotiable.
- **Set `Workspace.StreamingEnabled = true`** in the build (or instruct the user to).
- **Meshes**: prefer Parts. If any imported mesh is used (e.g. one hero clubhouse),
  keep it **under 10,000 triangles per MeshPart**.
- **Determinism**: seed any randomization so re-runs are reproducible; make the script
  **idempotent** (clear its previous output folder before rebuilding).
- **Parameterize** `worldScale` and a `zonesToBuild` list so the user can build one zone
  at a time.

---

## Suggested milestones (ship each, let the user verify in Studio)

1. **M1 — Scaffold + coordinate helpers.** Grid→Vector3 conversion, folder setup,
   idempotent clear/rebuild, a flat ground plane sized to the world. Verify: runs clean.
2. **M2 — Water + roads.** Delta, Willow Lake, lagoon channels, four spines + courts.
   Verify: recognizable road skeleton over water.
3. **M3 — Lots + house kit.** 3–5 house models, lot pads, placement along one zone
   (start with Zone 1, the clubhouse/golf core).
4. **M4 — Golf course + landmarks.** Fairways, ponds, bunkers, clubhouse + parking,
   marina, lighthouse.
5. **M5 — Docks/boats + set dressing + perf pass.** Docks on waterfront lots, trees,
   streetlights; confirm anchoring, StreamingEnabled, and framerate on a mid-range device.

---

## Deliverables

- `src/` (or a single `build.luau`) containing the generator.
- The layout data as a Luau module (`Layout.luau`) — you may transpile
  `discovery-bay-layout.json` into a Luau table, or load/paste it.
- A `README.md` with **exact run instructions** (how to paste into the Command Bar, or
  how to install Rojo and sync), plus how to rebuild a single zone.
- Keep functions small and commented so the user can tweak road paths and house styles.

---

## Honest limitations to preserve (don't over-promise)

- The layout is a **schematic skeleton**. Exact canal edges, lot counts, and course hole
  shapes should be refined against the live satellite — build the framework, make it easy
  to adjust, and note where the user should eyeball the map.
- This is a **stylized** build, not a survey-accurate GIS import. That's intentional: it
  performs well and fits Roblox's art style.
- Don't attempt to import a Gaussian splat of the town. At most, one hero landmark could
  be a decimated mesh; everything else stays procedural Parts.

---

## Files in this handoff

| File | What it is |
|------|-----------|
| `discovery-bay-layout.json` | **Source of truth** — coordinate system, roads, water, zones, landmarks, house kit, constraints |
| `discovery-bay-layout-sketch.svg` | Whole-neighborhood zone map + build order |
| `discovery-bay-clubhouse-core-trace.svg` | Zone 1 street-level trace |
| `discovery-bay-lagoon-marina-trace.svg` | Lagoon + marina street-level trace |
| `discovery-bay-roblox-build-plan.md` | Strategy / reasoning |
| `discovery-bay-roblox-studio-checklist.md` | Human build checklist (mirrors the milestones) |

Start with M1. Ask the user only if something in the spec is ambiguous for code
generation; otherwise proceed milestone by milestone.
