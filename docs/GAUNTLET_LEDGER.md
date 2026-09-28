# Gauntlet Ledger

Every major piece gets a spec with acceptance conditions, a builder, then an independent critic (fresh context, no builder justification) who tries to prove it incomplete. Verdicts are PASS or FAIL-with-evidence. Budget: 3 rounds (5 for difficult subsystems), then escalate to KNOWN_GAPS.

Evidence locations: `tools/out/` (screenshots, bench JSON — not committed; regenerate with the listed command), test output, this file.

---

## Slice S0 — Vertical slice acceptance specification

| # | Piece | Acceptance conditions | Evidence type |
|---|---|---|---|
| S0.1 | World generation | Seeded & deterministic; island/archipelago/continents; ≥ 6 biomes per map; edges are water; land 10–60 % | tests `test_world.*`, `tools/dump_worldgen.gd` images |
| S0.2 | Camera | Drag pan, wheel zoom to cursor, keys, bounds, follow, jump-to | UI scenario + manual review |
| S0.3 | Time controls | Pause/1/2/5/10; outcome independent of frame batching | `test_determinism.test_tick_rate_independent_of_frame_batching`, UI scenario |
| S0.4 | Terrain editing | Raise/lower/paint; brush radius; exact undo; walkability propagates to AI; buildings on flooded tiles destroyed | `test_editor.*`, `test_civ.test_city_abandoned_when_town_hall_flooded`, UI drag scenario hash check |
| S0.5 | Animal species | Grazes, breeds, dies; herd bounded; responds to hunters | `test_units.test_ecosystem_*`, long-run notes |
| S0.6 | Sapient species | Nomads, founding, jobs, children | `test_civ.*` |
| S0.7 | Hunger | Rises, eating reduces, starvation kills, law gate | `test_units.test_hunger_*`, `test_civ.test_starvation_*` |
| S0.8 | Food gathering | Forage/farm/hunt → storage → consumption; capacity | `test_civ.test_food_chain_*`, `test_deposit_*` |
| S0.9 | Settlement creation | Needs ≥ 2 band members + site score; reasons recorded | `test_civ.test_band_founds_*`, `test_lone_wanderer_*` |
| S0.10 | Population growth | Births limited by housing and food | `test_civ.test_city_grows_*` |
| S0.11 | Houses | Planned, paid from wood, built by builders, add housing | same + screenshots |
| S0.12 | City inventory | Food/wood/stone never negative; production/consumption tracked | invariants, inspector |
| S0.13 | Inspection panel | Unit + city + deceased, clickable relations | screenshots `03_city_close`, `04_unit_inspect` |
| S0.14 | Save/load | Slots, autosave, thumbnails, metadata, versioning, corruption detection, exact state roundtrip incl. continued evolution; cross-process | `test_persistence.*`, bench roundtrip |
| S0.15 | Admin panel | Search/filter; edit unit/city; laws; overlays; invariants; decision log | screenshot `05_admin`, scenario asserts |
| S0.16 | Performance overlay | Frame/sim/subsystem/entity/memory figures | screenshot `06_history_perf` |
| S0.17 | Robustness | 100k autonomous ticks & 30k fuzzed ticks with no invariant violations; bounded memory/logs | `test_long_run.*` |

## Builder self-check (not a verdict — the builder may not grade itself)
2026-09-28, commit after "Phase 0 vertical slice":
- Fast suite: 40/40 pass (≈19 s). Slow suite: 2/2 pass (fuzz 30k ticks: 409 units, 4 cities; autonomous 100k ticks = 278 years: 278 humans, 3 cities, **0 woolbacks — herd went extinct**, memory 39.2 → 41.8 MB).
- UI scenario: raise-drag changed world hash, Ctrl+Z restored the exact original hash; F1/T/Esc toggles assert OK.
- Known weak points handed to critics without spin: GDScript tick cost; woolback extinction in very long runs; rendering only measured on llvmpipe.

## Critic rounds
(appended below per round)
