# Known Gaps

Honest list of what is missing, partial, or unverified. Nothing here should be presented as working.

| ID | Area | Gap | Impact | Plan |
|---|---|---|---|---|
| G-001 | Scope | Kingdoms/diplomacy/war, traits, fire, plague and disasters now exist (see FEATURE_MATRIX). Still **not implemented**: culture, language, religion, clans, weather beyond a dry season, world ages, possession, boats/naval, items/equipment, tech, multiple sapient species, subspecies | Depth gap vs the reference | Next phases |
| G-002 | Performance | Tick cost ≈ 7 µs/creature; 1 000 creatures exceed the 5 ms p95 budget | 10× speed marginal on dense worlds | Phase 11 decision gate (batching → GDExtension) |
| G-003 | Performance | Rendering only measured on software GL (llvmpipe) | FPS numbers unrepresentative | Measure on real GPU hardware |
| G-004 | Audio | No audio at all | — | Phase 12 |
| G-005 | Terrain | No rivers; lakes only incidental from noise | Less interesting geography | Phase 1 |
| G-006 | Determinism | Guaranteed per engine build/platform only (floats, FastNoiseLite) | Cross-platform replays may diverge | Saves store full state, so loading is unaffected |
| G-007 | Undo | Undo covers terrain strokes only (not spawns/smites/admin ops); undo history is not saved | Expected for a god sim | Document in UI tooltip |
| G-008 | Undo | Undoing a stroke that erased farmland restores the farmland tile but not its membership in the city's field list (tile becomes unused farmland) | Minor | Re-adopt owned farmland tiles in `_manage_fields` |
| G-009 | AI | Humans flock/idle near home when jobless; no social needs, sleep, or leisure | Less lively | Phase 2/3 |
| G-010 | AI | Nomad children only follow mother; orphaned nomad children wander alone | Minor | Phase 6 family AI |
| G-011 | Genetics | 11 heritable traits exist, but no genome grid, subspecies or trait editor | — | Later phase |
| G-012 | Buildings | Units walk through buildings; no roads | Visual only | Phase 3 roads |
| G-013 | UI | World Stats graphs exist; no minimap | — | Later |
| G-014 | UI | No settings menu (UI scale, volume); only a first-run welcome card and How to play | Touch players cannot rescale the UI | Next UI pass |
| G-015 | Persistence | Player settings not persisted separately; camera stored in slot meta | Minor | Phase 11 |
| G-016 | Research | Feature matrix built from search excerpts only (wiki/Steam fetches blocked by network policy); rows marked [U] unverified | Some reference behaviors may be inaccurate | Re-verify with direct page access |
| G-017 | Admin | No "modify genes/change species/force marriage/inventory/equipment/treasury/war" commands yet — those systems do not exist | — | Added with their systems |
| G-018 | Platform | Export presets (Win/macOS/Linux) not yet configured; never run outside Linux | — | Phase 13 |
| G-019 | Balance | Rebellions mostly fail and wars rarely change borders for long; late worlds (120+ years) settle into a stable set of 4–12 realms | History slows down late | Tune with longrun reports each round |
| G-020 | Ecology | Wolves survive but hover at 5–20 animals; woolbacks can reach 1 000 with humans as the main limiter | Predator pressure is light | More predator species, pack territories |
| G-021 | Web | The browser build is single-threaded; on an iPad late-game worlds may not hold 10× speed | Slower fast-forward | Measure on device; profile monthly spikes |
| G-022 | Tests | Crash-free code paths are covered by headless tests; UI flows are only checked by screenshots | UI regressions can slip | Scripted UI assertions in tools/capture.gd scenarios |
| G-023 | Hygiene | Headless runs end with "ObjectDB instances leaked" warnings (static caches, test worlds) | Noise only; Simulation.dispose() frees worlds in the game | Audit static caches |
