# UI System

## Principles
- The player UI must feel like a game: square pixel bevels, warm wood/parchment palette, original 5×7 bitmap font at integer scales (18 px / 27 px), procedural 16×16 icons. No rounded SaaS cards, gradients or glassmorphism.
- The admin console uses a separate cool, dense "technical" theme (`UiTheme.admin()`), so it is visually obviously a tool.
- Every player action is reachable by pointer (mobile-ready); keyboard shortcuts are accelerators only. Tooltips carry names, hotkeys and explanations.
- UI never mutates the simulation directly; it calls `Game` which issues logged commands.

## Components (`src/ui`)
| Component | Role |
|---|---|
| `UiTheme` | Builds both themes, icon AtlasTextures, label helpers |
| `GameUi` | Root Control: builds, lays out and toggles panels; tile hover readout; toasts |
| `TopBar` | Title, date, speed buttons (toggle group), population/cities/animals, buttons for Chronicle, World Ledger, Perf, Admin |
| `PowerBar` | Category tabs → power buttons (icon + tooltip + hotkey); current power name; brush −/+; undo |
| `InspectorPanel` | Unit (portrait, condition bars, task, carry, job, home link, leader title, kills, parents/children links, follow/favorite) or city (leader link, population/housing, stores with last-month +/−, buildings, construction needs, workers have/want, "Why here?" reasons, recent events). Deceased units show birth/death/cause and family |
| `HistoryPanel` | Chronicle list with filters; click jumps camera and selects |
| `CityLabels` | Screen-space banners (city color border, name, population); click to inspect |
| `MenuPanel` | "World Ledger": save-as, slot list with thumbnails/metadata, load/delete, new world (seed/size/shape) |
| `AdminPanel` | Entities (search + filters: All/Humans/Animals/Cities/Favorites/Leaders/Starving), Selected (health/hunger/age, flags, job, kill/delete/duplicate/teleport, force-found city; city resources add/remove, abandon), World (stats, admin speeds, step/+1 year, laws, set leader), Debug (map overlays, chunk grid, territory, paths, AI targets, perf, decision recording, invariants, state hash, decision log viewer) |
| `PerfOverlay` | Live frame/sim timings, subsystem costs, counts, memory, chunk uploads, path budget |

## Layout
Top bar (full width) · power bar (bottom, full width) · inspector (right) · chronicle/admin (left) · menu (center) · toasts (top center) · hover readout (bottom left above power bar).

## Interaction evidence
`tools/capture.gd` drives the real game with synthetic mouse/keyboard events (`tools/scenarios/*.json`) and records screenshots + assertions. Required for UI gauntlet reviews.
