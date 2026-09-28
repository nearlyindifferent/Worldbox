# Simulation Rules

All numbers live in `src/core/sim_const.gd` or `data/*.json`; this document explains *why* and how they interact. Update both together.

## Calendar
10 ticks/s at 1×. Month = 30 ticks, year = 360 ticks.

## World
- Elevation (0–1, sea ≈ 0.40), moisture (0–1), temperature (°C: latitude − altitude lapse + noise) → biome via `WorldGen.classify` thresholds.
- Fertility = biome fertility × (0.55 + 0.45 × moisture).
- Walkable: all land except Mountain. Water: Deep Ocean, Ocean, Shallows.
- Movement cost multiplies time to cross a tile (e.g. forest 1.5, swamp 2.2). A* uses the same weights.

## Vegetation (cellular, `VegetationSystem`)
- Each tile is visited every 60 ticks (staggered by chunk).
- Grass-like biomes regrow `24 × fertility + 1` per visit up to the biome's `veg_max`.
- Farmland: crop maturity grows `90 × (0.4 + 0.6 × moisture)` per visit (≈4–7 visits ≈ 0.7–1.2 years to mature). Mature ≥ 240.
- Forest timber regrows +9 per visit. Unowned grassland touching forest converts to young forest with 1.2 % chance per visit (law `forest_spread`).
- Visual grazing: grass with low vegetation renders drier.

## Creatures (`LifeSystem`)
- Hunger rises by species `hunger_rate` per tick (humans 0.08, woolbacks 0.30). At 100: −0.4 health/tick (starvation).
- Standing on an unwalkable tile: −2 health/tick (drowning/buried) and forced re-think to seek land.
- Regeneration +0.05/tick while hunger < 50.
- Natural death at an age drawn uniformly from the species lifespan.
- Flags: FROZEN (AI skipped; life still runs), INVULNERABLE (no damage, no old age), FAVORITE.

## Woolbacks (`AnimalAI`)
- Think every 8 ticks. Flee from hunting humans within 4 tiles.
- Hunger ≥ 35: graze current tile if vegetation ≥ 24, otherwise sample 10 tiles within radius 7 for grazing; else wander farther.
- Wander around the local herd centroid (10-tile radius) — herd cohesion.
- Monthly breeding: female, fertile age, hunger ≤ 60, cooldown 0.8 y, 12 % chance, adult male within 6 tiles, fewer than 7 of the species in her chunk. Litter 1–2.
- Result (measured): stable oscillating herds (≈50–150 on a medium island) under human hunting.

## Humans (`HumanAI`) — hierarchical decisions
Decisions happen only when idle and the unit's think tick arrives (every 8 ticks, staggered), or immediately after a task completes.
1. **Survival**: on water → seek nearest land. Hunger ≥ 50 → eat carried food; else if the city has food: eat instantly when inside own territory (aggregated household eating), otherwise walk home; else forage.
2. **Logistics**: carrying goods and belonging to a city → deliver to nearest storage building.
3. **Society**: cityless adults try to *join* a same-species city within 40 tiles that has housing room; otherwise every 90 ticks evaluate founding here (see below) or scout 6 random sites within 24 tiles and walk to the best; otherwise flock with the band (follow lowest-id nomad nearby). Children follow their mother (nomads) or stay near the town hall.
4. **Work**: perform the city-assigned job.
- **Hunger interrupt**: a busy unit with hunger ≥ 75 abandons any non-food task and re-plans.
- Hungry units eat foraged/hunted food on the spot; the remainder is carried.

### Jobs
| Job | Action | Yield |
|---|---|---|
| Gatherer | Forage a tile with vegetation ≥ 60 (sampled search, radius 14 ×1/×2/×3) | 1.2 × biome food value, tile −60 veg |
| Farmer | Harvest nearest mature field, else tend the least-grown (+40 maturity) | 2.5 × (0.5 + 0.5 fertility) food |
| Woodcutter | Chop tile with wood ≥ 40 (radius 16 ×1/×2/×3) | 4 wood; forest turns to grassland when depleted |
| Quarrier | Work a hills tile or tile next to mountain | 3 stone |
| Builder | Pay cost from storage on arrival (once), then add 20 work per trip | — |
| Hunter | Chase nearest woolback in a herd of ≥ 3 within 16 tiles | 4 food per kill |

## Settlements (`CivSystem`)
### Founding
Site score around the candidate (radius 5): Σ fertility of unowned walkable tiles + 8 water access + 6 timber within 9 + 3 stone within 12 − 1 per already-owned tile. Rejected if the town-hall footprint is blocked or another city is within 22 tiles. Requires score ≥ 48 **and** a band of ≥ 2 cityless adults within 12 tiles. All factors are stored as `founding_reasons` and in the DecisionLog.

On founding: 2×2 town hall (housing 4, storage), territory disk radius 5, band members (and their children) join, 10 starting food, founder is leader.

### Planning (every 30 ticks, staggered)
1. Abandon if population is 0.
2. Recompute housing and food capacity (60 + 80 per granary).
3. Succession: if the leader is dead, the eldest adult member leads (logged).
4. Job targets (pure function `compute_job_targets`): food workers = 45 %/30 %/15 % of adults when stores last < 1 / < 4 / ≥ 4 months (60 % farmers, rest gatherers); woodcutters 25 % when wood < unpaid needs + 12; builders 2 per affordable site (≤ 25 %); quarriers when stone is short; 1 hunter at ≥ 6 adults. Leftover adults cut wood while wood < 60, else gather. Existing jobs are kept when still needed (stability).
5. Fields: 4 per farmer target; ≤ 2 new per plan on fertile grass/soil, clustered, not next to buildings.
6. Construction: at most one housing project and one civic project concurrently. House when free housing < 3. Granary when population ≥ 14 and none exists. Site = nearest valid 2×2 footprint in territory with a one-tile gap from other buildings.
7. Territory: target 80 + 8 × population tiles; claim up to 4 best border tiles per plan (fertility-weighted, closer first).

### Monthly
- Famine: food < 1 for 3 consecutive months → FAMINE history + shortage decision.
- Births: needs free housing and food ≥ 1.5 × population; each fertile mother (16–45, cooldown 1.5 y, hunger < 75) has 35 % chance with a random fertile father from the city.
- Storage beyond capacity is discarded (spoilage).

### Abandonment
Town hall destroyed with no other storage, or population 0 → members become nomads, territory released, farmland reverts to soil, buildings removed, history + decision entries.

## God powers
Terrain brushes record undo per stroke. Changing a tile's walkability updates A*; making a building's tile unwalkable destroys it; destroying the last storage abandons the city. Spawn powers need land within 4 tiles. Smite kills non-invulnerable units in the brush; Blessing heals and feeds.

## Laws
`hunger`, `natural_death`, `reproduction`, `animal_reproduction`, `vegetation_growth`, `forest_spread`, `settlement_founding`, `construction` — read every tick; toggles take effect immediately.

## Observability
- `HistoryLog`: major events kept; minor events capped at 4000.
- `DecisionLog`: 600 most recent decisions with numeric reasons (settlement, construction, succession, shortage).
- `StatSeries`: bounded (≤ 512 samples) with pairwise downsampling.
- `Simulation.deceased`: genealogy records for dead humans, capped at 20 000 (oldest evicted).
