# Decisions (ADR log)

| ID | Date | Decision | Why | Consequences |
|---|---|---|---|---|
| D-001 | 2026-09-28 | Godot 4.7 stable, GL Compatibility renderer, typed GDScript | Brief mandates Godot 4.7; Compatibility runs everywhere incl. software GL (CI screenshots) and mobile | No compute shaders; GPU work stays in canvas shaders |
| D-002 | 2026-09-28 | Simulation is pure `RefCounted` code with no Nodes; presentation observes | Headless testing, determinism, scale | Some duplication of queries on the view side |
| D-003 | 2026-09-28 | Structure-of-arrays for tiles and creatures | Avoid per-entity objects/`_process`; cache-friendly; trivial serialization | Adding a field means touching `UnitStore._array_fields` (+ schema bump) |
| D-004 | 2026-09-28 | Stable 64-bit creature ids + recycled slots | References survive deaths/reuse; genealogy of the dead | `slot_of` dictionary lookup on id resolution |
| D-005 | 2026-09-28 | Engine `AStarGrid2D` for sapient pathfinding with a per-tick budget; animals steer directly | Keeps GDScript out of search inner loops; bounded worst case | Budgeted units wait a tick; direct steering may bump into water then re-plan |
| D-006 | 2026-09-28 | Randomized sampling (`TileSearch`) instead of exhaustive scans for resource search, with ×1/×2/×3 radius expansion | O(K) instead of O(r²); naturally spreads workers | Occasional misses of the single nearest tile (acceptable) |
| D-007 | 2026-09-28 | Aggregated household eating: citizens inside their territory eat directly from city storage | Walking to the granary for every meal adds traffic without gameplay value (brief: "use aggregation intelligently") | Storage still constrains; delivery and harvest logistics are simulated |
| D-008 | 2026-09-28 | Commands as dictionaries through `GodCommands.execute`, logged with tick | Replayable, testable, one choke point for player/admin/test actions | Slight verbosity |
| D-009 | 2026-09-28 | Save container: magic + versions + SHA-256 + zstd(var_to_bytes(dict)), atomic rename, forward-only migrations | Corruption detection, no object deserialization, versioning | Hash computed over compressed bytes; schema bumps need migration functions |
| D-010 | 2026-09-28 | Procedural placeholder art via material-map atlases + palette shader; original bitmap font built at runtime | No copyrighted assets; per-instance colors free; crisp pixel UI | Art Gauntlet will replace/refine (Phase 12) |
| D-011 | 2026-09-28 | Working title "Hearthmere" | Needs a name that is not WorldBox | Trademark check required before release |
| D-012 | 2026-09-28 | Human hunger 0.08/tick (≈ 0.7 meals/year) | With 0.25/tick units starved on 45-tile wood trips (walk speed 1 tile/s at 1×). Time is compressed; economy ratios matter more than realism | Farmers feed ~7 people; documented in SIMULATION_RULES |
| D-013 | 2026-09-28 | Vegetation cycle 60 ticks (growth ×3 per visit), skip all-water chunks | 5× lower cost (1.3 → 0.27 ms/tick on 256²) with the same growth per year | Coarser temporal granularity of regrowth |
| D-014 | 2026-09-28 | Abandoned cities are removed from `sim.cities` immediately | A same-tick join into a dead city violated invariants (caught by tests) | Callers iterating cities must iterate a copy (`values()` already is) |
| D-015 | 2026-09-28 | One housing + one civic construction project in parallel | A granary waiting for stone blocked all housing growth | Slightly faster growth |
| D-016 | 2026-09-28 | Frame sim budget 14 ms: excess ticks are deferred, never skipped | Frame-rate independence of outcomes | At very high speed on slow machines the world runs slower than requested (indicator shown) |
| D-017 | 2026-09-28 | Custom headless test runner instead of a third-party framework | No network dependency, tiny, fits the Gauntlet evidence model | Fewer conveniences (no mocking) |

## Deviations from the brief's build order
- Phase 0 slice already includes pieces from later phases because they were cheap and required by the slice (world laws infra from Phase 9, admin panel from Phase 10, decision logs/observability, bounded stats). They are foundations, not complete features; see FEATURE_MATRIX statuses.
