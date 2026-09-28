# Known Gaps

Honest list of what is missing, partial, or unverified. Nothing here should be presented as working.

| ID | Area | Gap | Impact | Plan |
|---|---|---|---|---|
| G-001 | Scope | Everything beyond the Phase 0 slice (kingdoms, diplomacy, war, traits, genetics beyond cosmetic inheritance, culture, language, religion, clans, disease, fire, weather, disasters, ages, possession, graphs UI, audio) is **not implemented** | — | Phases 1–13 |
| G-002 | Performance | Tick cost ≈ 7 µs/creature; 1 000 creatures exceed the 5 ms p95 budget | 10× speed marginal on dense worlds | Phase 11 decision gate (batching → GDExtension) |
| G-003 | Performance | Rendering only measured on software GL (llvmpipe) | FPS numbers unrepresentative | Measure on real GPU hardware |
| G-004 | Audio | No audio at all | — | Phase 12 |
| G-005 | Terrain | No rivers; lakes only incidental from noise | Less interesting geography | Phase 1 |
| G-006 | Determinism | Guaranteed per engine build/platform only (floats, FastNoiseLite) | Cross-platform replays may diverge | Saves store full state, so loading is unaffected |
| G-007 | Undo | Undo covers terrain strokes only (not spawns/smites/admin ops); undo history is not saved | Expected for a god sim | Document in UI tooltip |
| G-008 | Undo | Undoing a stroke that erased farmland restores the farmland tile but not its membership in the city's field list (tile becomes unused farmland) | Minor | Re-adopt owned farmland tiles in `_manage_fields` |
| G-009 | AI | Humans flock/idle near home when jobless; no social needs, sleep, or leisure | Less lively | Phase 2/3 |
| G-010 | AI | Nomad children only follow mother; orphaned nomad children wander alone | Minor | Phase 6 family AI |
| G-011 | Genetics | Only cosmetic genes (skin/hair/wool) inherited; no stats/traits | — | Phase 6 |
| G-012 | Buildings | Units walk through buildings; no roads | Visual only | Phase 3 roads |
| G-013 | UI | No graphs panel yet (StatSeries recorded but not drawn); no minimap | — | Phase 9 |
| G-014 | UI | No settings menu (volume, edge scroll, UI scale) | — | Phase 12 |
| G-015 | Persistence | Player settings not persisted separately; camera stored in slot meta | Minor | Phase 11 |
| G-016 | Research | Feature matrix built from search excerpts only (wiki/Steam fetches blocked by network policy); rows marked [U] unverified | Some reference behaviors may be inaccurate | Re-verify with direct page access |
| G-017 | Admin | No "modify genes/change species/force marriage/inventory/equipment/treasury/war" commands yet — those systems do not exist | — | Added with their systems |
| G-018 | Platform | Export presets (Win/macOS/Linux) not yet configured; never run outside Linux | — | Phase 13 |
