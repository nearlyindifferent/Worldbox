# Architecture

## Layers

```
┌──────────────────────────── Layer C: Interface / God layer ─────────────────────────────┐
│ src/game/game.gd (composition root, time loop, input→commands)  src/game/powers.gd      │
│ src/ui/*  (GameUi, TopBar, PowerBar, InspectorPanel, HistoryPanel, AdminPanel,          │
│            PerfOverlay, MenuPanel, CityLabels, UiTheme)                                  │
└───────────────┬───────────────────────────────────────────────────────▲──────────────────┘
      commands  │ sim.apply_command(dict)                        reads    │ (never writes)
┌───────────────▼────────────── Layer A: Simulation (pure) ─────────────┴──────────────────┐
│ Simulation ── WorldGrid (SoA tiles) ── UnitStore (SoA creatures) ── cities{} buildings{} │
│ Systems: LifeSystem, MovementSystem, HumanAI, AnimalAI, CivSystem, VegetationSystem,    │
│          TerrainEditor, GodCommands, SpatialIndex, Pathfinder (AStarGrid2D)              │
│ Observability: HistoryLog, DecisionLog, StatSeries, SimInvariants                       │
│ Persistence: SaveManager (container), SaveMigrations                                    │
└───────────────▲──────────────────────────────────────────────────────────────────────────┘
      reads     │ (chunk revisions, unit arrays, prev/cur positions)
┌───────────────┴────────────── Layer B: Presentation ─────────────────────────────────────┐
│ TerrainView (data textures + terrain.gdshader), UnitView & BuildingView (SpriteBatch     │
│ MultiMesh + sprite.gdshader), WorldFx (brush, selection, debug, effects), CameraRig,    │
│ AssetForge (procedural art), PixelFont                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

### Rules
1. `src/sim/**` and `src/core/**` never reference Node, rendering, UI, `Input`, or frame delta. They are `RefCounted` and run headless (`tests/`, `tools/smoke.gd`, `tools/bench.gd`).
2. Presentation reads simulation state; it never mutates it. The only writes into the simulation are **commands** (`Simulation.apply_command`), which are logged (`command_log`) and replayable.
3. The UI calls the `Game` controller API; the controller issues commands.
4. `UnitStore.prev_x/prev_y` exist only for render interpolation; they are excluded from saves/hash.

## Directory map
| Path | Contents |
|---|---|
| `data/*.json` | Biomes, species, buildings, jobs. Stable integer `index` = on-disk id |
| `src/core` | `Defs` (typed registry + hot lookup tables), `SimConst` (tuning with rationale), `SimRng` |
| `src/sim/world` | `WorldGrid`, `WorldGen`, `VegetationSystem` |
| `src/sim/units` | `UnitStore`, `SpatialIndex`, `Pathfinder`, `MovementSystem`, `LifeSystem`, `AnimalAI`, `HumanAI`, `TileSearch` |
| `src/sim/civ` | `City`, `Building`, `CivSystem` |
| `src/sim/edit` | `TerrainEditor` (brushes + undo) |
| `src/sim/history` | `HistoryLog`, `DecisionLog`, `StatSeries` |
| `src/sim/persistence` | `SaveManager`, `SaveMigrations` |
| `src/render` | Views, shaders, camera, `AssetForge`, `PixelFont` |
| `src/ui` | Player UI + admin console |
| `src/game` | `Game` controller, `Powers`, `MapImage` |
| `tests/` | Runner, `TestCase`, `TestWorlds`, `unit/test_*.gd` |
| `tools/` | `smoke.gd`, `bench.gd`, `capture.gd` + `scenarios/*.json`, `export_assets.gd`, `dump_worldgen.gd` |

## Data-oriented design
- **Tiles**: one packed array per field (`elevation`, `biome`, `moisture`, `temperature`, `vegetation`, `wood`, `owner`, `building`, `variant`). Index `i = y*w + x`.
- **Creatures**: `UnitStore` structure-of-arrays with a free list. Stable 64-bit ids never reused; `slot_of` maps id→slot. Iteration is by slot index (deterministic).
- **Cities/Buildings**: few, so plain `RefCounted` objects in insertion-ordered dictionaries.
- **Spatial index**: chunk buckets (16×16 tiles) rebuilt every tick by counting sort (CSR). O(units + chunks), no allocations per unit.
- **Pathfinding**: engine-native `AStarGrid2D` (C++) with move-cost weights; solidity updated incrementally from `WorldGrid.walk_changed`; per-tick request budget (`PATH_BUDGET_PER_TICK`). Animals use direct steering.

## Tick pipeline (`Simulation.step`)
1. `tick += 1`; path budget reset; apply queued walkability changes to A*.
2. Spatial index rebuild.
3. Vegetation: 1/`VEG_CYCLE_TICKS` of chunks (skip all-water chunks via cached flag).
4. For each living slot: store prev position → `LifeSystem.update` (hunger, starvation, hazards, regen, old age) → if not frozen: `HumanAI.update` or `AnimalAI.update`.
5. `CivSystem.update`: each city plans on a staggered cadence (`CITY_PLAN_INTERVAL`); monthly accounting/births.
6. Monthly: animal breeding, stats sampling, population milestones.
7. Timing samples per subsystem (smoothed) → perf overlay.

## Update-frequency tiers
| Tier | What | Frequency |
|---|---|---|
| Every tick | Movement, timed work, hunger | 10 Hz @1× |
| Think | Decision making | ≤ every `THINK_INTERVAL` (8) ticks, staggered by slot; immediate re-think after task completion |
| Hunger interrupt | Abandon non-food task when starving | checked every 8 ticks while busy |
| City plan | Jobs, fields, construction, territory | every 30 ticks, staggered by city id |
| Monthly | Births, famine, breeding, stats | every 30 ticks |
| Vegetation | Regrowth, crops, forest spread | each tile every 60 ticks |
| Render | Terrain texture re-encode | changed chunks only, ≤ every 0.12 s, ≤ 96 chunks per refresh |

## Presentation
- **Terrain**: one `Sprite2D` scaled ×8 whose shader reads two data textures (tile data, ownership) and the procedural tile atlas. Hillshade, grazing dryness, water shimmer, shoreline foam/bank, territory fill + zoom-aware borders, heatmap overlay and chunk grid all happen in one pass. CPU cost is proportional to *changed chunks*.
- **Sprites**: `SpriteBatch` (MultiMeshInstance2D, 16 floats per instance). Atlases are *material maps* (R = material id, G = shade) resolved in `sprite.gdshader` so skin/hair/wool/city colors cost nothing extra. Units: shadow + body + carried item; interpolated between ticks; hidden below zoom 0.32 (the political map carries the view).
- **Labels**: city banners are screen-space `Button`s positioned from the canvas transform (constant size, clickable).

## Time loop (`Game._process`)
`acc += delta × ticks_per_second`; run whole ticks while `acc ≥ 1` within a 14 ms per-frame budget. If the budget is exceeded the simulation runs slower than requested ("sim slowed" indicator) — **logic is never skipped or scaled**. Interpolation alpha = fractional `acc`.

## Determinism contract
- All randomness in the simulation goes through `Simulation.rng` (PCG32 state saved).
- Iteration orders: slots ascending; dictionaries in insertion order.
- Commands are applied between ticks and logged with their tick.
- Verified by tests: same seed → same hash; same command script → same hash; batching ticks differently → same hash; save → load → continue → same hash as uninterrupted run.
- Worldgen uses `FastNoiseLite` (deterministic per seed on a given engine build). Cross-platform float determinism is **not** guaranteed (see KNOWN_GAPS G-006).

## Persistence
See `SaveManager` header comment. Container: magic, container version, schema, raw length, packed length, SHA-256, zstd payload of `var_to_bytes(Simulation.to_dict())` (no Objects). Slots: `user://saves/<slot>/{world.sav, meta.json, thumb.png}`. Atomic temp-file rename. `SaveMigrations.STEPS` upgrades old schemas forward; newer schemas are refused.

## Extension points
- New species/biomes/buildings/jobs: add JSON rows (new stable `index`), art pattern in `AssetForge` if needed.
- New god powers: `Powers.DEFS` + `GodCommands._brush` (or a new command op).
- New per-unit fields: add to `UnitStore._array_fields()` (automatically saved) and bump `SAVE_SCHEMA` with a migration.
- New overlays: `TerrainView.Overlay` + `_overlay_color`.
