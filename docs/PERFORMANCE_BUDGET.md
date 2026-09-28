# Performance Budget

## Measurement tools
- `tools/bench.gd` — headless simulation benchmarks with fixed seeds (no rendering). Writes `tools/out/bench.json`.
- `tools/capture.gd` + `print: perf` — in-game perf report from the real renderer.
- In game: F3 overlay; Admin → Debug.

## Reference hardware for the numbers below
Cloud container: 4 vCPU (unknown x86-64), 15 GB RAM, **software rendering** (Mesa llvmpipe under Xvfb). Rendering numbers from this machine are pessimistic by an order of magnitude versus any real GPU; simulation numbers are representative of a mid-range CPU.

## Baseline (Phase 0 vertical slice, 2026-09-28)

### Simulation (headless, `tools/bench.gd`)
| Scenario | World | Units | Cities | Tick p50 | p95 | max | Ticks/s | Static mem | Save | Save ms | Load ms | Roundtrip |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| small | 192² | 151 | 5 | 1.06 ms | 1.37 | 3.22 | 930 | 39 MB | 442 KB | 6 | 23 | identical hash |
| medium | 256² | 262 | 9 | 1.89 ms | 2.81 | 7.68 | 500 | 54 MB | 766 KB | 11 | 47 | identical hash |
| large | 384² | 520 | 10 | 4.10 ms | 6.14 | 9.98 | 228 | 84 MB | 1689 KB | 22 | 113 | identical hash |
| dense | 256² +40 bands +600 sheep | 832 | 16 | 5.94 ms | 8.64 | 13.78 | 158 | 101 MB | 825 KB | 14 | 46 | identical hash |

Generation: 136 ms (192²), 213 ms (256²), 544 ms (384²).

Observed scaling: ≈ **7 µs per creature per tick** in GDScript (life + AI + movement) plus ≈ 0.27 ms/tick vegetation on 256².

### Rendering (software renderer, 1600×900, medium world, 20 years in)
FPS 17–24, draw calls ≈ 50–90, frame ≈ 55–75 ms (dominated by llvmpipe fragment shading of the terrain pass). Not representative; needs real-GPU measurement (KNOWN_GAPS G-003).

## Budgets (targets for release on a mid-range desktop: 4-core ~3 GHz, integrated GPU)
| Metric | Budget | Status |
|---|---|---|
| Frame time at 1× on medium world | ≤ 16.7 ms | unverified on real GPU |
| Simulation per frame | ≤ 14 ms (enforced cap; sim slows instead of skipping) | enforced |
| Tick cost, medium world, 300 creatures | ≤ 2 ms p95 | 2.81 ms p95 — **over** |
| Tick cost, 1 000 creatures | ≤ 5 ms p95 | ~8.6 ms p95 @ 832 — **over** |
| 10× speed sustainable (100 ticks/s) | medium world | 500 ticks/s headless → OK |
| 10× speed sustainable | 1 000 creatures | ~150 ticks/s headless → marginal with rendering |
| Save size, medium world | ≤ 2 MB | 766 KB OK |
| Save / load time, medium | ≤ 250 ms / ≤ 500 ms | 11 / 47 ms OK |
| Memory growth over 100k ticks | < 256 MB | verified by `test_slow_hundred_thousand_ticks_autonomous` |
| Terrain texture updates | changed chunks only, ≤ 96 per 0.12 s | enforced |

## Known hotspots & planned remedies (profile before optimizing)
1. Per-creature GDScript dispatch in `Simulation.step` → `LifeSystem.update` → `HumanAI.update` → `MovementSystem.advance`. Options in order: (a) batch life updates into a single loop over arrays, (b) move steady-state movement for all units into one tight loop, (c) GDExtension (C++) for movement + life if (a)/(b) are insufficient. Decision gate: tick p95 for 1 000 creatures must reach ≤ 5 ms.
2. `CivSystem._expand_territory` scans the whole territory each plan (O(territory)). Maintain a border set when cities exceed ~1 000 tiles.
3. `SimInvariants.check` is O(world) — test/admin only.

Accuracy is never reduced silently to meet budgets; any reduction must be recorded in `DECISIONS.md`.
