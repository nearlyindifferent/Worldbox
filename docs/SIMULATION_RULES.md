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
- Forest timber regrows +9 per visit. Unowned grassland touching forest converts to young forest with 1.2 % chance per visit; mature forest thins back to grassland with 0.2 % chance per visit (turnover; both under law `forest_spread`).
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
- Wander around the local herd centroid with 40 % cohesion (loose herds spread over pasture).
- Monthly breeding: female, fertile age, hunger ≤ 60, cooldown 0.8 y, base 24 % chance, an adult male within 6 tiles, then **density pressure**: probability × (local grass share around her) × (1 − woolbacks within 5 tiles / 12); none if ≥ 12 nearby. Litter 1–2. (Replaced a per-chunk hard cap that blocked 81 % of breeding — Gauntlet D-3.)

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
Site score around the candidate (radius 5): Σ fertility of unowned walkable tiles + 8 water access + 6 timber within 9 + 3 stone within 12 − 1 per already-owned tile. Rejected if the town-hall footprint is blocked or another city is within 22 tiles. Requires score ≥ 48 **and** a band of ≥ 2 cityless **adults** within 12 tiles. All factors are stored as `founding_reasons` and in the DecisionLog.

On founding: 2×2 town hall (housing 4, storage), territory disk radius 5, founder + up to 11 nearest band adults (and their children) join (`MAX_FOUNDERS` 12; the rest stay nomads), 10 starting food, founder is leader.

### Colonisation (settlers)
Monthly, a city with ≥ 28 people whose crowding (people ÷ housing, +0.3 if food is too short for births) is ≥ 0.9 has a 25 % chance — at most once per 4 years — to send up to 6 adults aged 14–40 (not the leader) plus their young children. The destination is the best of 10 sites 26–60 tiles away on the same landmass (score ≥ 80 % of the founding threshold). Settlers carry the SETTLER flag: they never re-join cities, walk to the site, found there if the rules allow, otherwise scout up to 4 times, then become ordinary nomads. Recorded as a MIGRATION history event and a settlement decision with its reasons.

### Sea voyages
If no good site exists on the town's own landmass, the town tries 12 random headings from its centre: walking out over land to the last shore tile, then over at least 3 tiles of open water (at most 90 tiles in total) to the first land of a *different* landmass. The best such crossing whose inland site (up to 4 tiles past the landing) scores ≥ 80 % of the founding threshold is chosen. Settlers and their children get a route in `CivSystem.voyages`, walk to the shore, sail straight to the landing (the SAILING flag lets them cross water without drowning or being blocked), then continue as settlers to the site. A route whose shore becomes unreachable is abandoned.

### Planning (every 30 ticks, staggered)
1. Abandon if population is 0.
2. Recompute housing and food capacity (60 + 80 per granary).
3. Succession: if the leader is dead, the most respected adult leads (score 100 + half their age, capped at 60 years, +12 wise, +8 just, +4 brave or strong); with no adults the eldest child rules ("child ruler"). Announced with an epithet from their traits ("the Wise"); in a capital the same entry names the new ruler of the realm.
4. Job targets (pure function `compute_job_targets`): food workers = 45 %/30 %/15 % of adults when stores last < 1 / < 4 / ≥ 4 months (60 % farmers, rest gatherers); woodcutters 25 % when wood < unpaid needs + 12; builders 2 per affordable site (≤ 25 %); quarriers when stone is short; 1 hunter at ≥ 6 adults. Leftover adults cut wood while wood < 60, else gather. Existing jobs are kept when still needed (stability).
5. Fields: 4 per farmer target; ≤ 2 new per plan on fertile grass/soil, clustered, not next to buildings.
6. Construction: at most one housing project and one civic project concurrently. House when free housing < 3. Granaries allowed: 1 from population 14, +1 per 25 people. Once granaries are satisfied, stone buildings (order forge → temple → watchtower, or watchtower first in wartime): forge from population 25, temple from 35, watchtower from 20 (+1 per 45 people). Site = nearest valid 2×2 footprint in territory with a one-tile gap from other buildings. Builders pick paid sites first, then affordable ones, housing before civic; unaffordable sites are skipped (logged once as "cannot start … missing X").
7. Territory: target 80 + 8 × population tiles; claim up to 4 best border tiles per plan (fertility-weighted, closer first).

### Monthly
- Famine: food < 1 **and** at least 25 % of the town urgently hungry (hunger ≥ 75) for 2 consecutive months → FAMINE history (at most once per town per 5 years) + shortage decision.
- Births: need free housing and a food stock covering **2 months of the city's need** (need = population × hunger rate × 30 / meal hunger × meal food); each fertile mother (16–45, cooldown 1.5 y, hunger < 75) has 35 % chance with a random fertile father from the city. (Replaced "food ≥ 1.5 × population", which capped every city at ≈ 93 because storage is bounded — Gauntlet D-1.)
- Deliveries beyond capacity are discarded; stock already above capacity (god gifts, a destroyed granary) decays 30 % of the excess per month.

### Stone buildings
- Watchtower (12 wood, 16 stone): counts as 3 defenders when enemies besiege the town.
- Forge (15 wood, 20 stone): the town's soldiers hit 30 % harder; gathering, farming and woodcutting yield 10 % more.
- Temple (20 wood, 30 stone): +12 to the town's loyalty target; plague damage and spread among its people × 0.6.

### Abandonment
If the last storage building is destroyed and people remain, they raise a new town hall on free land in the territory (the town centre moves there; half the stores are lost). Population 0, or no room for a new hall → members become nomads, territory released, farmland reverts to soil, buildings removed, history + decision entries.

## Kingdoms (`KingdomSystem`, monthly)
- A band founding a town founds a kingdom; settlers' colonies join their mother kingdom. A kingdom falls with its last town.
- Loyalty of each non-capital town drifts 10 %/month toward 100 − 0.9 × distance to the capital − 3 × (towns beyond 3) − 0.4 × war weariness ± 10 (just / greedy ruler) + 12 (temple).
- Opinion between neighbouring realms (capitals within 90 tiles, or with shared history) is the sum of itemised reasons: border tension (up to −30 within 45 tiles), rulers' temperament (−12 × combined aggression; warlike rulers +0.35 aggression), grievances from bloodshed (decay 3 %/month), years of peace (+0.5/year, max +8), shared origin (+12), common enemy (+15), coveted land (−12 when one side is ≥ 1.4× stronger and ≥ 8 adults).
- War: opinion < −28, ≥ 5 years since the last peace, the more aggressive ruler declares if not already at war and at least 0.8× as strong; 25 %/month chance.
- Soldiers (30 % of adults in wartime) march on the enemy town nearest their capital. A town with ≥ 3 enemy soldiers within 7 tiles of its hall and no defenders (watchtowers count as 3) is captured; it starts at loyalty 40 with a 4-year occupation grace.
- Peace: war weariness (+1/month +1.5 per death) ≥ 45 on either side → 35 %/month; stalemates (≥ 3 years, no town taken for half of it) → 6 %/month truce; rebel realms that survive 5 years win recognition; wars end after 12 years.
- Rebellion: a province below loyalty 22 (outside its grace period, ≥ 10 people) rebels with chance 5 % × (22 − loyalty)/22 per month, founding a new kingdom that the crown immediately fights; up to 2 disloyal (< 30) towns within 20 tiles join it.

## Disasters (`DisasterSystem`)
- Fire is updated every 3 ticks. Each burning tile burns one fuel unit (grass 3, forest 12, hills 5, swamp 5, glimmerwood 9, farmland 3) and tries to ignite its 8 neighbours with chance = flammability (grass 0.05, forest 0.30, farmland 0.10 …) × vegetation (grass/farmland) × (1 − 0.8 × moisture) × 0.45 on settled land × damping for fires over 1 200 tiles; diagonals half. Burnt grass and forest become scorched land (regrows to grassland); other biomes keep their type and lose vegetation. Wooden buildings on a burning tile burn down with 12 % per step; town halls are fireproof. Creatures in flames lose 7 health per step; creatures next to flames flee 6 tiles.
- Lava is impassable (40 damage/tick), ignites flammable neighbours (30 %/step), flows downhill while it has flow, and cools into ashlands after 80 steps.
- Meteor: kills within 0.6 R, halves health within R, flattens buildings within 0.85 R, craters the ground (lava core, scorched ring, fire at the rim).
- Earthquake: a fissure through the epicentre (buildings on it collapse, some lava), then 60 ticks of shaking: 5 hits per tick concentrated near the centre (35 % collapse chance, halls ×0.2) and injuries.
- Volcano: raises a cone, lava core with long flows, ashlands around.
- Rain: puts out fires, cools lava, adds moisture and vegetation.
- Plague lasts 150 ticks: 0.7 health/tick × frailty (0.4–1.6 by person, ×1.6 sickly, ×0.6 with a temple); spreads every 6 ticks to same-species creatures within 1.6 tiles (12 %, ×0.6 with a temple); survivors become immune.
- Natural events (law `natural_disasters`): lightning fires in months 6–9 on dry unsettled grass/forest (6 %/month scaled by world area); plague outbreaks as a rare world event (0.6 %/month, weighted toward large towns).

## World ages (`AgeSystem`, monthly; law `world_ages`)
Each age lasts 20–40 years; the next is drawn at random (never the same twice) and chronicled. Multipliers: crop and grass growth, natural wildfire odds, natural plague odds, an opinion shift between all realms ("restless times"), and a monthly natural earthquake chance.
| Age | Crops | Grass | Fire | Plague | Relations | Quakes |
|---|---|---|---|---|---|---|
| The Quiet Years | 1.0 | 1.0 | 1.0 | 1.0 | 0 | 0 |
| The Green Years | 1.3 | 1.3 | 0.4 | 1.0 | 0 | 0 |
| The Long Winter | 0.6 | 0.6 | 0.3 | 1.2 | 0 | 0 |
| The Ember Years | 0.85 | 0.8 | 3.0 | 1.0 | 0 | 0 |
| The Restless Years | 1.0 | 1.0 | 1.0 | 1.0 | −10 | 3 %/month |
| The Pale Years | 0.95 | 1.0 | 1.0 | 4.0 | 0 | 0 |
The Turn of Ages power (and admin op `set_world_age`) starts the next age at once. Presentation tints the land per age and dusts it with snow in the Long Winter.

## Traits (`Traits`)
Up to 3 per creature from 11: strong (+30 % health, +25 % battle damage), swift (+20 % speed), hardy (−25 % hunger), long-lived (+20 % lifespan), sickly (plague ×1.6, −15 % lifespan), wise (as leader: +15 % food yields), warlike, just, greedy (as ruler), fertile (×1.5 births), brave (does not flee enemy soldiers). Animals only get physical traits. First generations roll each trait at 8 %; children inherit a trait carried by one parent at 45 %, by both at 75 %, with a 4 % mutation.

## Wolves (`AnimalAI`, diet carnivore)
Hunt woolbacks when hunger ≥ 30 within 16 tiles (32 when starving), chasing in 2.5-tile hops and biting within 1.1 tiles (hunger −75). With no prey in reach they roam 14 tiles on a heading shared by the pack; packs split at 7. When starving (≥ 85) they attack a person standing alone (people strike back for 9). Litters need mates within 20 tiles and prey nearby. If wolves drop below 2 and prey is plentiful, a pair may wander in from the wilds every 6 years.

## Pathfinding reachability
Walkable tiles are labelled into 4-connected landmass components (`Pathfinder.rebuild_components`). Requests between different components return "unreachable" immediately without spending A* budget. Labels rebuild at most every 30 ticks while dirty and are saved, so reloaded worlds decide identically.

## God powers
Brush radius is clamped to 16 by the simulation. Terrain brushes record undo per stroke. Changing a tile's walkability updates A*; making a building's tile unwalkable destroys it; destroying the last storage abandons the city. Spawn powers need land within 4 tiles. Smite kills non-invulnerable units in the brush; Blessing heals and feeds.

## Laws
`hunger`, `natural_death`, `reproduction`, `animal_reproduction`, `vegetation_growth`, `forest_spread`, `settlement_founding`, `construction`, `diplomacy`, `wars`, `rebellions`, `natural_disasters`, `world_ages` — read every tick; toggles take effect immediately.

## Observability
- `HistoryLog`: major events kept; minor events capped at 4000.
- `DecisionLog`: 600 most recent decisions with numeric reasons (settlement, construction, succession, shortage).
- `StatSeries`: bounded (≤ 512 samples) with pairwise downsampling.
- `Simulation.deceased`: genealogy records for dead humans, capped at 20 000 (oldest evicted; their child links are pruned too). Genealogy links are kept for sapient species only.
- `deaths_by_cause` keys are `"<species>: <cause>"`; use `Simulation.count_deaths(cause, species)`.
