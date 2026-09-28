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

### Round 1 — Visual/UI critic (independent agent, fresh context) — 2026-09-28
Verdicts: S0.2 Camera **FAIL** (grey void past bounds) · S0.3 Time UI PASS (minor) · S0.4 Terrain UX **FAIL** (tabs unusable by mouse, multi-active tabs, placeholder swatches) · S0.13 Inspector PASS (minor) · S0.15 Admin PASS (weak: width jumps, empty decision log) · S0.16 Perf overlay PASS (hidden by admin) · Player UI bar **FAIL** · Art direction **FAIL** (buildings culled, one house sprite, unit/roof same hue, stair-step biome edges, banner pile-ups).

Critical defects and resolution (builder, verified by re-running the critic's own scenarios `tools/out/critic_ui/s2/s4/s8.json` + `tools/scenarios/toolbar_tabs.json`):
| Defect | Root cause | Fix | Evidence |
|---|---|---|---|
| Buildings vanish by camera position | MultiMesh auto-AABB stale after buffer upload → whole batch culled | `custom_aabb` world-sized in `SpriteBatch.setup` | Whitehaven z4 now shows all buildings (s8_03 re-run) |
| Category tabs snap back | `_show_category` → `_sync` forced category of current power | Browsing decoupled from selection; explicit exclusive pressed state | tabs_03: Divine shown while Raise selected; clicking Smite selects it |
| Several tabs lit | `set_pressed_no_signal` doesn't release group peers | Set every tab state explicitly | tabs_04 |
| Placeholder swatches | Icons sampled tile art | Framed swatch + pictogram per biome | `assets_icons.png` |
| Grey void | Clamp allowed 25% viewport overshoot; default clear grey | Clamp to world ± 48 px, center when smaller; sea-coloured clear | tabs_04 |
| Banner pile-ups/ghosts | No declutter; fade at zoom | Population-priority placement with overlap rejection; opaque | s4/tabs shots |
| Panel collisions | Independent absolute positions | Chronicle/admin share one left dock; perf docks beside it; toasts narrower | tabs_05/06 |
| Unit/roof same hue, weak shadows | Roofs tinted fully by city color | Roofs mixed 55% toward thatch; wider shadow | s8_03 re-run |
| Stair-step biome edges, stripy hills | Full-tile fills | Dithered 2-px transitions in shader; varied hill art | s8_03 re-run |
| One house sprite | Kit too small | +2 variants (stone cottage, timber longhouse) | `assets_buildings.png` |
| Minor: empty hover box, stale hover, toast dupes, number formatting, bars without values, children cap, follow state, Shift+F side effect, key 1 = pause, admin width/decision log, entity order, chronicle noise | — | All addressed (see commit 75f1bde) | tabs_07/08 |

Deferred with justification → KNOWN_GAPS: roads/props between buildings (G-012, Phase 3), full autotile edge sets (Art Gauntlet, Phase 12), per-power cursor sprites, more human templates (Phase 6 genetics).

Status: UI/art items re-verified by builder; **a fresh critic round is required** before marking PASS (the builder may not grade itself).

### Round 1 — Simulation critic (independent agent) — 2026-09-28
Verdicts: S0.1 PASS(minor) · S0.3 PASS · S0.4 PASS(minor) · **S0.5 FAIL** (herds collapse even without humans) · S0.6 PASS(weak) · S0.7 PASS · S0.8 PASS(minor) · **S0.9 FAIL** (adult + child founded a city) · **S0.10 FAIL** (hidden ≈93 cap) · **S0.11 FAIL** (construction deadlock) · S0.12 PASS · S0.17 PASS(minor) · **Observability FAIL** · **Emergent quality FAIL** (no founding after year 3).
Resolution (commits 8f362b7, 169b437, 95c8bc5; regression tests `tests/unit/test_gauntlet_regressions.gd`): months-of-need birth rule + scaling granaries (D-1); builders skip unaffordable sites, stalls logged (D-2); density pressure + looser herds, need-based hunting of herds ≥ 5 (D-3); settler colonisation (D-4); adult-only bands, founder cap (D-5); overflow spoilage (D-6); child regency (D-7); sapient-only genealogy + pruning, brush clamp (D-8); landmass components (D-9); per-species death causes, forest turnover, rare biomes, √size features (D-10).
Follow-up found by builder long runs: fixing D-1/D-4 let humans saturate islands (3–5k, herds extinct, 49 ms ticks). Added carrying capacity from land: 14-tile territory radius per city + farmland soil exhaustion; hunting only under food stress. Evidence (`tools/longrun.gd -- 150 1 192 island`): humans plateau ≈ 2 100 in 18 cities (max 175/city), woolbacks persist 72–300 for 150 years, 0 invariant violations.

### Round 1 — Persistence & performance critic (independent agent) — 2026-09-28
Verdicts: slots PASS(minor) · autosave rotation PASS · thumbnails PASS · metadata PASS(minor) · **versioning/migration FAIL** (schema change without bump; null sim reported ok) · corruption detection PARTIAL · in-process roundtrip PASS · **cross-process edge cases FAIL** (stale spatial index, unsaved undo) · **safety FAIL** (13 GB from a 56 KB file) · **atomic write FAIL** · **performance budgets FAIL** · **scalability FAIL** · bounded memory PASS(caveats).
Resolution (commits 81bbab3, 95c8bc5, 2dca618; tests `tests/unit/test_save_fixtures.gd`, `test_units.gd`): SAVE_SCHEMA 2 + migration verified against a golden schema-1 file; golden schema-2 hash fixture guards unversioned format changes; `SaveValidator` + invariant gate + size limits (hostile cases rejected); backup-rename writes with recovery from .bak/.tmp; spatial index rebuilt before every command, undo stack saved; real cross-process save→terminate→load→continue test; slot-name hardening; Game state reset on load; distance-weighted A* budget; O(1) deceased eviction; unit-store compaction; threaded autosave IO; batched life + movement and selective AI dispatch (dense 1 915 creatures: p95 13.9 → 7.7 ms, max 86 → 17 ms).
Remaining (→ KNOWN_GAPS): component relabel is a full flood fill (≈ 37 ms on 512² once per ≤ 30 ticks after walkability edits); monthly breeding pass ≈ 5.7 ms on dense worlds; one tick can still exceed the 14 ms frame budget at very large populations (frames bounded by a single tick's cost).

Status: fixes verified by builder with tests and long runs; **round 2 critics required** for verdicts. A deliberately hostile "hater" critic was added at the user's request (whole-product teardown).

---

## Features K (kingdoms, diplomacy, war), D (fire, disasters, plague), T (traits, wolves, stats), E (stone buildings)

Acceptance conditions (builder-specified, critic-verified):
- K: founding creates a realm; colonies stay loyal; opinions are sums of itemised reasons; wars draft soldiers, cause battle deaths and are explained in the decision log; undefended towns fall; exhaustion, stalemate and survival bring peace; distant disloyal provinces rebel after an occupation grace period; mid-war clones evolve identically. Tests: `test_kingdoms.*`.
- D: fire spreads by biome, vegetation and moisture, burns out into scorched land that regrows, does not cross water, creatures flee or burn, rain douses; meteors crater and kill, lava cools into ashlands; quakes topple buildings; plague spreads, kills some and immunises survivors; a wildfire cannot erase a town; disasters survive save/clone identically. Tests: `test_disasters.*`.
- T/E: traits pass on (both parents ~75 %), have their stated effects, exclusive pairs never co-occur; wolves hunt, attack only lone people when starving, and persist for decades. Tests: `test_life.*`; long-run evidence `tools/out/diag/wolves.gd`.

### Round 2 — "Hater" whole-product critic (independent agent) — 2026-09-28
Verdict: FAIL on iPad fit (toolbar and top bar off-screen at 1180×820, 1024×768, 820×1180), town-wiping disasters, early diplomacy dead ends, hover-only information, no onboarding, developer tools in the player bar, natural fire and plague over-tuned, chronicle naming the wrong place, noisy successions, bland names, clipped inspector. PASS on determinism, invariants, famine-spam fix, stale hover fix.
Resolution (commits 0615f67, 81d6815, 2527972): responsive power bar (2-row grid, portrait second row) and top bar, panels dock above the bar, inline power descriptions and store stats, welcome card with touch controls, World Stats replaces the performance button, fireproof halls, fire damping on settled land and large fires, dry-season lightning on unsettled land only, plague rate cut 4×, impacts chronicled before damage and rate-limited, merit-based leaders with epithets and one succession line, coups for one-town realms, landscape-aware town names and ten realm forms plus dynasties. Evidence: screenshots `tools/out/layout_{1180x820,1024x768,820x1180}/`, `tools/out/shots/{welcome,powerbar_desc,life_*,dis_*}.png`.
Open (→ KNOWN_GAPS): no audio, no settings/UI scale, depth still below the reference (G-001), late-game slowdown of history (G-019).

### Round 2 — Simulation/persistence critic (independent agent) — 2026-09-28
Verified PASS: clone and save/load mid-fire, mid-plague, mid-quake, mid-lava and mid-war stay hash-identical (300–720 ticks, two seeds); 150-year runs keep invariants.
Findings and resolution:
1. Schema 4 changed after being pushed → schema 5 for traits, shipped schema-4 fixtures restored as migration tests (D-024).
2. Unvalidated diplomacy records; an aborted invariant check accepted a bad save → full pair validation; `SimInvariants.completed` gate; tests for junk pairs and missing fields.
3. Wildfires abandoning towns → fireproof halls, hall rebuild (D-026), test `test_a_wildfire_does_not_wipe_out_a_town`.
4. `_fire_units` scanned all units → chunk-limited (34 ms → ~0 at 20k units).
5. Diplomacy cubic cost → cached enemies/strength, neighbour-only relations (1050 ms → 4.7 ms per month at 64 kingdoms).
6. Undo resurrected untracked lava; painted-over fires kept burning → `DisasterSystem.on_tile_changed`, lava-tracking invariant, test.
7. Every burned biome became grassland → only grass and forest scorch.
8. Unbounded disaster/plague/trait save data → bounds + hostile tests.
9. Loaders set arbitrary keys → whitelisted fields; NaN/duplicate checks.
10–13. Large-fire cost damped; plague scan skipped when nobody is sick; peace bonus capped; move-cost changes always reach the pathfinder.
Also found by the builder while fixing these: same-capacity unit compaction left a stale waypoint cache (reload divergence), regression test added; the test runner reported script-error-aborted tests as passing (D-031).

### Round 3 — Simulation critic (independent agent) — 2026-09-28
PASS: determinism (twin runs, clone/save-load at age boundaries and law toggles over 50 years), wolf target slot reuse harmless, kingdom monthly 0.4 ms.
Fixed (commit acffb04, tests `test_gauntlet_round3.gd`): watchtowers made towns uncapturable → towers raise the besieger count instead; hall not rebuilt when a granary survived; age quakes ignored the disaster law; age timer ran while ages were off; set_world_age accepted unknown ages; validator accepted stale id counters / living slots in the free list (+ building-footprint invariant); compaction left FIGHT targets stale; duplicate_unit re-rolled traits; invulnerable prey was eaten; monthly breeding spike (21 ms) → per-tick slice; wolf migration floor scales with map size.

### Round 3 — "Hater" player critic (independent agent) — 2026-09-28
PASS: tests (109), long runs with invariants OK, traits visibly drift, wars/conquests/rebellions now frequent (s42: 43 wars, 15 conquests, 6 rebellions in 100 y).
Fixed: earthquakes now topple buildings near the epicentre (12 → 3 on a test town); meteor kill zone widened; woolback breeding and density cap lowered (s42 year 41: 268 people, 182 woolbacks, previously 3.5:1 sheep); plague outbreaks can hit towns from 15 people; wildfires in the wilds are no longer chronicled (only near towns, once a year); chronicle rows wrap instead of truncating; tapping a category picks its first power; the welcome card pauses the world and closes with Esc; toasts wrap to the screen width; tap-to-inspect radius scales with zoom (~24 px); "granaries" plural.
Open (→ KNOWN_GAPS): portrait side panels still cover much of the map; late-game tick cost on 384²+ worlds exceeds the 10× budget (web single-threaded); only one sapient race, no alliances/religion/culture/items/monsters; voyages rare; empty granaries rarely starve anyone; stone supply can stall; no ambient audio.
