# Game Specification — Hearthmere (working title)

> Canonical product definition. If code and this document disagree, one of them is a bug: fix it or update this file.

## 1. Product

An original 2D pixel-art **god-sandbox civilization simulator** in the same product category as WorldBox. The player shapes a living world with god powers and watches autonomous creatures and civilizations emerge, flourish, fight and collapse — without scripting.

**North-star experience:** *"I created a world, touched almost nothing, watched it for an hour, and an entire history emerged that I did not script."*

### Originality rules (non-negotiable)
- No proprietary WorldBox code, sprites, textures, sounds, text, logos, icons, names of proprietary content, or UI layouts copied.
- All art is procedurally generated (`src/render/asset_forge.gd`) or later hand-made/legitimately licensed. The font is original (`src/render/pixel_font.gd`).
- Species/biome/building names are generic or original ("Woolbacks", "Ashlands", "Glimmerwood").
- The working title "Hearthmere" is a placeholder pending a trademark search (see DECISIONS D-011).

## 2. Platforms & engine
- Godot **4.7.x stable**, GL Compatibility renderer, statically typed GDScript.
- Targets: Windows, macOS, Linux. Input architecture keeps Android/iOS practical: every action is reachable by pointer; camera handles trackpad pan/pinch gestures; no hover-only functionality in the player UI.

## 3. Core pillars
1. **Systemic simulation first.** Every visible thing is the result of simulated state (tiles, creatures, cities). Rendering only observes.
2. **Explainability.** The player can always ask *why*: founding reasons, construction decisions, succession rules, shortages — all recorded with numeric factors (DecisionLog).
3. **Emergence over scripting.** No timers that spawn cities or wars. Growth is constrained by food, housing, materials, land.
4. **Scale.** Data-oriented storage (structure-of-arrays), staggered updates, budgets — designed for thousands of creatures.
5. **Robustness.** Deterministic ticks, invariant checks, versioned checksummed saves, long-run fuzzing.

## 4. Scope of the current vertical slice (Phase 0 deliverable)

| Area | Delivered |
|---|---|
| World | Seeded generation (island / archipelago / continents), 15 biomes incl. volcanic "Ashlands" and magical "Glimmerwood", 5 size presets (128²–512²), chunked 16×16 |
| Camera | Smooth pan (right/middle drag, WASD/arrows, trackpad), zoom-to-cursor, follow unit, jump-to city/unit/event, world bounds |
| Time | Pause, 1×, 2×, 5×, 10× (+ admin 20×/50×/100×), fixed 10 ticks/s at 1×, frame-rate independent |
| Terrain editing | Raise/lower + 14 biome brushes, brush radius 0–12, tile-accurate preview, stroke undo (50 strokes) |
| Life | One animal species (Woolbacks: graze, herd, breed with density caps, flee hunters) and one sapient species (Humans) |
| Needs | Hunger → eating → starvation; old age; drowning/hazards; regeneration |
| Economy | Foraging, farming (farmland → crops grow → harvest → storage), woodcutting (deforestation), quarrying, hunting; city storage with capacity & spoilage |
| Settlements | Nomad bands evaluate sites (fertility, water, timber, stone, crowding) and found cities; territory growth; job allocation; construction (houses, granary) paid from storage; births constrained by housing and food; succession; famine; abandonment |
| Inspection | Unit panel (portrait, stats, job, task, carry, family links incl. deceased), city panel (stores with monthly production/consumption, buildings, construction needs, workers vs targets, "why here?", recent events) |
| History | Chronicle with filters and jump-to; bounded minor event log |
| Save/load | Manual slots, quicksave/quickload, rotating autosaves, thumbnails, metadata, schema versioning + migration gate, SHA-256 corruption detection, atomic writes |
| Admin | Entity search/filter, per-unit/city editing, laws, speed overrides, overlays (fertility/temperature/moisture/elevation/vegetation/biome id/ownership), chunk grid, paths, AI targets, invariant checker, state hash, decision log viewer |
| Performance overlay | FPS, frame ms, draw calls, sim ms/tick, per-subsystem ms, entity counts, memory, chunk uploads, path budget |

Everything outside this table is **not implemented yet** — see `FEATURE_MATRIX.md` and `KNOWN_GAPS.md`.

## 5. Time model
- 1 tick = 1/10 s at 1×. 30 ticks = 1 month, 12 months = 1 year (36 s at 1×, 3.6 s at 10×).
- Humans live 55–80 years, become adults at 14. Woolbacks live 6–10 years.

## 6. Controls (player)
| Input | Action |
|---|---|
| Left click / drag | Use selected power (Inspect selects) |
| Right or middle drag, WASD/arrows, trackpad | Pan |
| Wheel / pinch | Zoom toward cursor |
| Space, 1–4 | Pause / resume, speeds 1×, 2×, 5×, 10× |
| [ ] or - = | Brush size |
| Ctrl+Z | Undo terrain stroke |
| Q R F H J X | Inspect, Raise, Lower, Humans, Woolbacks, Smite |
| Shift+F | Follow selected unit |
| T | Chronicle |
| Esc | Deselect / open World Ledger (save, load, new world) |
| F5 / F9 | Quicksave / quickload |
| F1 or ` | Admin console |
| F3 | Performance overlay |

## 7. Definition of done (whole product)
See the master brief; restated: systems interact coherently; civilizations emerge, flourish and collapse unscripted; wars arise from simulation; families persist; cultures/languages/religions change; ecosystems react; resources constrain; disasters affect real systems; history is accurate and explainable; large worlds stay performant; save/load is reliable; UI and art feel intentional; extremely long runs do not corrupt state.
