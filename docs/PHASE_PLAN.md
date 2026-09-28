# Phase Plan, Dependency Graph and Risks

## Phases (from the brief, adjusted for dependencies)

| Phase | Content | Entry criteria | Exit criteria (Gauntlet) |
|---|---|---|---|
| **0** Research, matrix, architecture, prototype | FEATURE_MATRIX, docs, vertical slice | — | Slice gauntlet PASS (see GAUNTLET_LEDGER) |
| **1** World | Rivers, more generators (continents with shelves, lakes), world-size custom UI, minimap, camera polish (edge scroll, selection history) | Phase 0 PASS | Gen tests per shape; visual review of 5 seeds × 3 shapes |
| **2** Entities & ecology | Generic creature components, predators (wolves), fish/boats-later, flee/hunt, migration, plant spread/burn/recover | 1 | Lotka–Volterra-like oscillation observed & graphed in a 200-year run |
| **3** Sapient civ depth | Second sapient species, more buildings (storage, workshops, mines, docks), roads, ore→metal→tools chain, professions | 2 | Production chain test (ore→weapon→soldier), 100-city bench |
| **4** Kingdoms | Kingdom meta-entity, capitals, multi-city territory, rulers, succession laws, colonization | 3 | Succession & fragmentation tests; kingdom inspector |
| **5** Diplomacy & war | Relations with itemized reasons, alliances, armies, marching, battles, sieges, city capture, peace, rebellions | 4 | "Why do they hate each other" inspectable; 2 000-unit battle bench |
| **6** Traits, families, genetics | Trait framework, genome with inheritance/mutation, subspecies emergence, genealogy browser | 3 (can run parallel to 4–5) | Heredity statistics tests; subspecies divergence scenario |
| **7** Culture, language, religion, clans | Meta-entities with spread/split/decline, contact-driven diffusion | 4, 6 | Long-run split events observed; overlays |
| **8** Ages, disease, disasters, environment | World ages, epidemiology, fire cellular automaton, weather, tornado/quake/meteor/volcano | 2, 3 | Outbreak curves; fire spread/extinguish tests; disasters hit real systems |
| **9** History, stats, graphs, laws | Timeline browser, graphs UI on StatSeries, full law set | 5, 7, 8 | Graph screenshots; law toggle tests |
| **10** Possession, admin, overlays | Direct control of a unit (isolated from AI), advanced overlays for every meta-entity | 5, 7 | Possession release returns to AI cleanly (test) |
| **11** Hardening | Save migrations, performance (GDExtension if gate fails), 1M-tick soak | all sim phases | Budgets in PERFORMANCE_BUDGET met |
| **12** Art/UI/Audio gauntlets | Replace placeholders, animation, particles, original/licensed audio | 11 | Art consistency review; audio reactive to zoom |
| **13** Integration & release | Full gauntlet, regression, export presets Win/macOS/Linux | 12 | Release candidate |

## Dependency graph

```
                         ┌──────────── P0 slice ────────────┐
                         ▼                                   │
                   P1 World ──► P2 Ecology ──► P3 Civ depth ─┼──► P4 Kingdoms ──► P5 Diplomacy/War ──┐
                                   │              │           │         │                 │          │
                                   │              └──► P6 Traits/Genetics ──► P7 Culture/Lang/Religion│
                                   │                                  │                 │           │
                                   └──────────► P8 Ages/Disease/Disasters/Environment ◄─┘           │
                                                                      │                             │
                                             P9 History/Stats/Laws ◄──┴──────────────◄──────────────┘
                                                      │
                                             P10 Possession/Admin/Overlays
                                                      │
                                             P11 Hardening/Performance
                                                      │
                                             P12 Art/UI/Audio ──► P13 Integration/Release
```

Cross-cutting from day one: determinism, invariants, save schema discipline, DecisionLog for every new decision type, admin commands for every new system (testability).

## Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | GDScript throughput limits population scale (~7 µs/creature/tick today) | High | High | Profile-driven batching first; GDExtension for movement/life/AI hot loops behind the same SoA arrays (decision gate in PERFORMANCE_BUDGET) |
| R2 | Floating-point determinism differs across platforms/builds | Medium | Medium (replays/multiplayer out of scope) | Determinism guaranteed per build; saves store full state rather than relying on replay |
| R3 | Emergent balance collapses (famine spirals, runaway growth) in long runs | High | High | Long-run tests with population bands, decision logs, admin laws; per-system tuning notes in SIMULATION_RULES |
| R4 | Save format churn as systems land | High | Medium | Schema version + migration steps + fixture tests per bump |
| R5 | Art/UI drifting into generic look | Medium | High | Dedicated art & UI gauntlets with screenshot evidence; theme centralised in UiTheme/AssetForge |
| R6 | Rendering cost on low-end GPUs (full-screen terrain shader with neighbor fetches) | Medium | Medium | Measure on real GPUs; fall back to pre-baked chunk textures if needed |
| R7 | Scope explosion (215 matrix rows) | High | High | Priorities in FEATURE_MATRIX; phase exit gauntlets; KNOWN_GAPS instead of half-features |
| R8 | IP proximity to the reference game | Low | Critical | Originality rules in GAME_SPEC; no reference assets on disk; generic naming |
| R9 | Research limited by network policy (wiki pages blocked) | Realized | Low | Feature matrix built from search excerpts, rows marked [U]; revisit with full access |
