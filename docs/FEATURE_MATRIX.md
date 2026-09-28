# Feature Matrix (Phase 0 research)

## Purpose

This matrix lists the publicly observable gameplay systems of WorldBox (the reference god-sandbox) and several comparable god/colony/world simulators. For each one it gives our own original design intent, a priority, and tracking columns. It is the checklist the master spec is measured against.

**Clean-room rule:** the "Reference behavior" column paraphrases *mechanics* only. No proprietary names of traits, powers, biomes, species, items, eras, text, icons, art or code are used or to be used. Every name, asset, number and string in our game must be original.

## Sources consulted

Research was done with web search on 2026-09-28. Direct page fetches (wiki, Steam, SteamDB, superworldbox.com) were **blocked by the sandbox egress proxy**, so the facts below come from search-engine excerpts of these pages rather than full reads. Rows that no excerpt confirmed are marked `[U]`.

- https://the-official-worldbox-wiki.fandom.com/wiki/Cultures
- https://the-official-worldbox-wiki.fandom.com/wiki/Languages
- https://the-official-worldbox-wiki.fandom.com/wiki/Religions and /wiki/Religion_Traits
- https://the-official-worldbox-wiki.fandom.com/wiki/Clans and /wiki/Clan_Traits
- https://the-official-worldbox-wiki.fandom.com/wiki/Plots
- https://the-official-worldbox-wiki.fandom.com/wiki/Books
- https://the-official-worldbox-wiki.fandom.com/wiki/Ages
- https://the-official-worldbox-wiki.fandom.com/wiki/World_Laws
- https://the-official-worldbox-wiki.fandom.com/wiki/Subspecies_Traits and /wiki/Gene_Editor
- https://the-official-worldbox-wiki.fandom.com/wiki/Reproduction
- https://the-official-worldbox-wiki.fandom.com/wiki/Happiness
- https://the-official-worldbox-wiki.fandom.com/wiki/Neurons
- https://the-official-worldbox-wiki.fandom.com/wiki/Unit_Stats and /wiki/Unit_Levels
- https://the-official-worldbox-wiki.fandom.com/wiki/Loyalty, /wiki/Rebellions, /wiki/Kingdom_Opinions, /wiki/War
- https://the-official-worldbox-wiki.fandom.com/wiki/Armies and /wiki/0.51.0_-_Armybox
- https://the-official-worldbox-wiki.fandom.com/wiki/0.50.0_%E2%80%94_Monolith_Awakens
- https://the-official-worldbox-wiki.fandom.com/wiki/Equipment and /wiki/Equipment_Crafting
- https://the-official-worldbox-wiki.fandom.com/wiki/Boats, /wiki/Docks, /wiki/Trading_Mechanics
- https://the-official-worldbox-wiki.fandom.com/wiki/Status_Effects
- https://the-official-worldbox-wiki.fandom.com/wiki/World_History and /wiki/World_and_Game_Statistics
- https://the-official-worldbox-wiki.fandom.com/wiki/Category:Biomes
- https://the-official-worldbox-wiki.fandom.com/wiki/Map_Creation
- https://the-official-worldbox-wiki.fandom.com/wiki/Achievements and /wiki/Modding
- https://shapes.inc/fandom/worldbox-god-simulator/powers-and-tools
- https://www.superworldbox.com/changelog
- https://steamdb.info/patchnotes/19939104/ (0.51.0 notes)
- https://store.steampowered.com/news/app/1206560/view/509574242369537672 (0.50 announcement)
- https://bugbox.featureupvote.com/suggestions/625784/save-clans-subspecies-cultures-religions
- https://dwarffortresswiki.org/index.php/DF2014:Legends
- https://en.wikipedia.org/wiki/SimEarth
- https://store.steampowered.com/app/2186320/Ages_of_Conflict_World_War_Simulator/
- https://rimworldwiki.com/wiki/AI_Storytellers
- https://store.steampowered.com/app/1162750/Songs_of_Syx/
- https://blackandwhite.fandom.com/wiki/Belief
- https://www.sega-16.com/2006/09/populous/

## Legend

- **Priority:** `CORE` = the product is not a god-sim civ sandbox without it (used sparingly). `IMPORTANT` = needed for comparable systemic depth. `POLISH` = improves feel/readability. `OPTIONAL` = nice to have, or experimental. `OUT OF SCOPE` = will not be built (see the last section).
- **Status columns:** `NOT STARTED` or `IN PROGRESS (slice)` for features the current vertical slice is building.
- **Notes tags:** `[V]` = a public source confirms it. `[U]` = unverified, either in the reference or in its details. `[NEW]` = a system not in the master spec's planned list. `From X` = seen in a comparable game, not in WorldBox.
- **Subsystem** uses short codes that match the section headings.

**Row count:** 215. **By priority:** CORE 33, IMPORTANT 134, POLISH 22, OPTIONAL 22, OUT OF SCOPE 4.

## Matrix

### World & Terrain

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Seeded world generation | Worlds are generated procedurally from noise; the same settings can be regenerated. | Fully deterministic generator: identical seed + settings yields an identical world. | World | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] Seed shown in UI and saved. |
| Island generation | Generator produces islands, archipelagos and landmasses. | Island-first generator for the slice; other shapes reuse the same pipeline. | World | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Continents / archipelago presets | Many world-shape types (roughly 16) with per-type options such as noise and ring shapes. | Preset library (single continent, archipelago, ring, lake world, fractured) with sliders. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] Map-type presets not in master spec. |
| Map size tiers | Several fixed map sizes; very large maps load slowly and strain performance. | Size tiers S-XL, each with a documented tick-time budget. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Elevation bands | Tiles form bands: deep water, shallows, sand, soil, hills, mountains, peaks. | Continuous heightfield quantized into terrain bands with passability rules. | World | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Lakes and rivers | Water bodies exist; rivers are mostly player-painted. | Generate downhill rivers to sea and basin lakes; paintable afterwards. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [U] Auto river generation in reference unconfirmed. |
| Biome classification | Each land tile carries a biome that determines grass colour, trees and plants. | Biome derived from temperature, moisture and height, stored per tile. | World | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Magical / fantasy biomes | A large set of special biomes (sweet, crystalline, blighted, hellish, enchanted, etc.). | Original set of 4-6 magical biomes with distinct gameplay effects and names. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] Must use our own names and palettes. |
| Volcanic terrain and lava | Lava flows, ignites things and cools into rock. | Lava tiles that flow downhill, burn, then cool into basalt. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Biome spread competition | Biomes expand onto neighbours using a random roll weighted by per-biome strength. | Per-biome spread strength with era and law modifiers; can be frozen by law. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Ore and mineral deposits | Ore and precious-metal deposits appear in hills/mountains and can be mined. | Deposits placed by geology/height; finite with slow regeneration option. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Vegetation layer | Trees, bushes and plants grow and spread per biome. | Plant growth sim with per-biome species and density caps. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Soil fertility | Different soil tiles determine how fertile land is. | Per-tile fertility value feeding plant growth and farm yields. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Temperature and frozen terrain | Cold biomes, freezing water and snow cover; heat melts it. | Per-tile temperature field driving ice, snow and melt. | World | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Roads | Paths/roads appear between buildings. | Roads emerge from traffic heatmap and give a movement bonus. | World | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [U][NEW] |
| Image-to-map import | Community tools convert images into playable maps. | Import PNG heightmap/biome palette as a world. | World | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] Reference feature is community-made. |

### God Powers

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Terrain brushes (raise/lower/biome paint) | Brushes paint ocean, shallows, sand, soil and mountains. | Raise, lower, flatten and biome-paint brushes. | Powers | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Brush sizes and shapes | Multiple brush sizes/shapes selectable. | Sizes 1-N, circle/square, hotkey cycling. | Powers | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Undo for edits | Not publicly documented for terrain edits. | Undo/redo stack for terrain and biome edits. | Powers | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [U] Differentiator if reference lacks it. |
| Categorized power toolbar | Powers grouped into tabs (world shaping, life, nature/disasters, destruction, misc). | Our 13 categories with search and tooltips. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Spawn creatures | Drop any species onto the map. | Spawn tool per species with count and subspecies selector. | Powers | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Status brushes (bless/curse/heal) | Powers that heal, bless or curse units in an area. | Area status brushes backed by the status-effect framework. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Frenzy power | A power that makes units attack anything nearby. | Frenzy status with duration and contagion option. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Force war / force peace | Powers that instantly trigger war or peace between nations. | Diplomacy brushes that shift opinion and log the divine cause. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Force independence | A power that makes a village break away as its own kingdom. | Independence brush creating a new polity with inherited metas. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Explosives tiers | Small bombs, mines and huge area weapons. | Explosive tiers producing craters, fire and debris. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Hand / grab tool | Units can be picked up, moved and thrown. | Grab, carry and throw units with fall damage. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [U][NEW] |
| Trait brush | Apply or remove traits with a brush. | Trait paint tool using the trait registry. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Eraser tools | Tools to remove units, buildings, water or life. | Per-layer eraser (units, buildings, plants, water). | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Uplift artifact | A placeable structure alters genes and can grant sapience to animals. | Placeable artifact that slowly uplifts nearby fauna into a new civ. | Powers | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Power unlock progression | Some powers/traits are unlocked via achievements or discovery. | Everything unlocked by default; optional discovery mode. | Powers | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Faith/mana budget mode | Comparable god games fuel powers with follower-generated mana/belief. | Optional mode where powers cost faith produced by worshippers. | Powers | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Populous / Black & White. |

### Creatures

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Data-driven species catalogue | Dozens of species: civilized races, animals, monsters. | Species defined in data files with stats, diet, habitat. | Creatures | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| One animal species (grazing, reproduction) | Herbivores graze plants and breed. | Grazer that eats vegetation, reproduces, and dies of hunger/age. | Creatures | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| One sapient species | Civilized races found villages and kingdoms. | First original sapient species with full civ loop. | Creatures | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Multiple sapient species | Several civ races, each with biome preferences and traits. | 4-6 original sapient species with distinct preferences. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Animal civilizations | Animals (and even spirits) can become civilizations after uplift. | Any species flagged sapient via genetics can civilize. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Hostile monsters | Monsters roam and attack settlements. | Hostile fauna with lairs and territory. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Undead / reanimation | Dead can rise as hostile undead under certain effects. | Reanimation status and cursed zones. | Creatures | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Hunger need | Units have a hunger bar and seek food. | Hunger drains per tick; eat from inventory, city or wild. | Creatures | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Rest and home need | Units sleep/rest at home, more so when unhappy. | Energy need satisfied by housing. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Core stat block | Health, damage, armor, speed, attack speed, crit, lifespan, mass. | Typed stat block with modifier stacking. | Creatures | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Stamina and mana pools | Units have stamina and mana resources. | Stamina for sprinting/combat, mana for spells. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Aging and life stages | Units are born, grow up, age and die of old age. | Life stages with stat curves and lifespan per species. | Creatures | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Levels and experience | Units gain XP (mostly from kills) and level up for stat boosts. | XP from combat and work; modest per-level bonuses. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Civic aptitudes | Four civic stats (diplomacy, warfare, stewardship, intelligence). | Four leadership aptitudes feeding ruler decisions. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Leader personalities | Kings and leaders have personalities affecting behaviour. | Personality archetypes weighting ruler AI. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Happiness | Happiness in a -100..100 range changed by events; low values alter behaviour. | Happiness with itemized event contributions. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Relationships | Units form lover pairs and best-friendships through conversation. | Relationship graph: partners, friends, rivals. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Conversations | Units talk; talking can spread culture, language and religion. | Social interaction tick that transfers memes and opinion. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Reproduction modes | Sexual pairing, egg laying, budding, fission, once-per-life late birth. | Per-subspecies reproduction mode with cooldowns. | Creatures | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |

### Genetics & Traits

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Subspecies | Populations diverge into subspecies with their own traits. | Subspecies split on isolation or mutation thresholds. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Genome of chromosomes/genes | Chromosomes hold genes that set base stats. | Genome = gene slots with alleles mapped to stats. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Gene synergy | Fully linked genes amplify their bonuses. | Adjacency linkage bonus in the genome grid. | Genetics | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Genome editor | Players can edit subspecies genes. | Genome editor in admin panel. | Genetics | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Mutation | Random mutations add traits or change looks. | Tunable mutation rate per world. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Visual phenotype | Mutations alter subspecies appearance (colours/patterns). | Palette/pattern genes rendered on sprites. | Genetics | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Subspecies trait pool | Around 200 subspecies traits (diet, body, reproduction, senses). | Original subspecies trait pool (~60 at launch). | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Genealogy | Parents and families tracked per unit. | Family tree viewer with descent queries. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Individual traits | Units have birth and acquired traits affecting stats and behaviour. | Trait registry with source tracking (birth/event/power). | Genetics | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Trait inheritance | Children may inherit parent traits. | Per-trait inheritance probability. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Event-acquired traits | Traits gained from experiences (battles, disasters). | Event hooks granting traits. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Trait editor | UI to add/remove traits on a unit. | Trait editor panel. | Genetics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Conditional evolution | Some animals transform into other species under conditions. | Rule-based evolution triggers (biome, era, artifact). | Genetics | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |

### AI

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Weighted-choice decision system | Each possible action has a weight; the chosen one is random in proportion. | Utility AI with weighted choice and recorded reasons. | AI | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Layered behaviour sources | Traits, culture, religion, clan and items add candidate actions. | Modifiers contribute actions/weights to the brain. | AI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Behaviour toggles | Players can disable specific actions for units. | Admin toggles per action type. | AI | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Jobs | Citizens become farmers, gatherers, woodcutters, miners, builders, warriors. | Job allocator by city demand and aptitude. | AI | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Pathfinding | Units path on land; boats cross water. | Hierarchical A* over tile regions plus water graph. | AI | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Combat AI | Units select targets, fight and flee. | Target scoring, flee thresholds, group cohesion. | AI | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Explain-why inspector | Current task visible when inspecting a unit. | Show current goal plus top alternatives and scores. | AI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Civilization/Cities

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Settlement founding | Sapients gather and found a village on suitable land. | Founding when a group finds fertile land away from others. | Civ | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Population growth | Villages grow by births and housing. | Births limited by food and housing. | Civ | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Houses / construction | Builders construct and upgrade houses. | Build queue with material cost and build time. | Civ | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| City inventory | Villages store resources centrally. | City stockpile with capacity per storage building. | Civ | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Food gathering / farming | Units harvest wild food and farm fields. | Gathering plus farm plots with growth stages. | Civ | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| City territory zones | Villages claim zones that grow over time. | Influence-based zone claiming. | Civ | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Building tiers | Buildings upgrade into better versions. | Tiered buildings unlocked by tech/pop. | Civ | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Unique civic buildings | Only one hall and library per village. | Unique-per-city building rules. | Civ | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Walls | Villages can build walls. | Auto-planned walls and gates when threatened. | Civ | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Settler expeditions | Settlers leave to found new villages, sometimes by boat. | Expedition planner using land or sea transport. | Civ | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| City leader | Each village has a leader, often from a clan. | Leader chosen by clan and aptitude. | Civ | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| City names | Villages have generated names. | Names generated from the city's language. | Civ | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Kingdoms & Politics

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Kingdom formation | Villages grow into or join kingdoms. | Kingdom forms when a city reaches a threshold. | Politics | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Banners and colours | Kingdoms and metas have banners, symbols and colours. | Procedural original heraldry. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Ruler and succession | Kings rule; successors chosen on death. | Succession rules from culture (eldest, elective, strongest). | Politics | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Capital | The capital is always fully loyal. | Capital has fixed loyalty and relocation rules. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| City loyalty | Villages have loyalty affected by king, distance, culture. | Loyalty with itemized factors. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Rebellion | Low loyalty villages revolt, split off and war with the parent. | Rebellion spawns new kingdom at war with parent. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Plots | Clan members plan wars, rebellions or new faiths over ~years; progress visible; can be cancelled. | Plot entities with progress bars, backers, and interruption rules. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Treasury and taxes | Kingdoms and units hold coins. | Tax flow from cities to crown. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Alliances | Kingdoms form alliances shown as a meta object. | Alliance entity with leader and shared war rules. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Kingdom collapse | Kingdoms are destroyed when they lose all cities. | Collapse with successor states and history entry. | Politics | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Vassals / tributaries | Subordinate states. | Tributary relation with tribute flow. | Politics | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [U] |

### Diplomacy & War

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Opinion with reasons | Relations depend on rulers, culture, borders and history. | Opinion matrix with inspectable reason list. | War | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| War declaration | Kingdoms declare war and send attacks. | War declaration from opinion, plots or ruler traits. | War | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Peace treaties | Wars end in peace. | Peace with terms and truce timer. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| War goals and outcome | Wars end with territorial change or destruction. | War score and explicit goals. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Armies as entities | Armies are selectable metas with captains who rally troops and army stats. | Army entity with commander, morale and roster. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Sieges and capture | Cities change hands when defenders fall. | Siege state and capture after hold time. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Naval troop transport | Transport boats answer ferry requests for soldiers/settlers. | Transport request queue served by boats. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Real-time combat | Individual units fight in real time. | Per-unit melee resolution with stats. | War | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Ranged combat | Units attack at range with projectiles. | Projectile system for bows and spells. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| War records | Wars and casualties are logged. | War ledger with casualties and battles. | War | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Religious war rites | Faiths cast powerful rites during war. | Rites triggered by plots with cooldowns. | War | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |

### Economy & Buildings

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Resource chain | Food, wood, stone, ore, metals and gold gathered and stored. | Chain food/wood/stone/ore/metal/gold/equipment. | Economy | CORE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Crop growth stages | Crops grow in stages and can die in harsh eras. | Staged crops affected by era and fertility. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Equipment crafting | Units craft weapons/armor using materials and coins. | Workshop crafting from stockpile. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Equipment slots | Weapon, head, body, feet and two accessory slots. | Slot model with stat modifiers. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Item quality tiers | Item rarity set by modifier level. | Quality tiers with original affix names. | Economy | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Personal wealth and loot | Units carry coins and loot from kills. | Personal purse and looting. | Economy | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Docks | Shore buildings that let villages build boats. | Dock building enabling boats. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Fishing boats | Boats that produce food. | Fishing boats harvesting fish stocks. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Trade boats | Boats sail to friendly docks and earn gold. | Trade routes between friendly ports. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Tech progression | Knowledge advances unlock better buildings/gear. | Tech tree per culture spread by contact and books. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Books as knowledge | Books written and stored in libraries; genres; lost when buildings burn. | Books carry knowledge and lore; libraries preserve them. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Market prices | Comparable colony sims use supply/demand prices. | Optional price model between cities. | Economy | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Songs of Syx. |
| Destructible buildings | Buildings take damage and burn. | Building HP, fire and collapse. | Economy | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Society

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Cultures | Cultures as metas with traits, spread and splits. | Culture entity with traits and member counts. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Culture traits | Traits change succession, building style and behaviour. | Original culture trait pool. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Languages | Created at founding, spread via talk, die with no speakers or books. | Language entity with spread and extinction. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Language traits | Language traits alter reading/book effects. | Language traits affecting knowledge transfer. | Society | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Procedural naming | Names generated for units, places and metas. | Phonology per language drives all names. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Religions | Religions arise via plots, spread via talk. | Religion entity created by prophets/plots. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Religion traits | Traits grant passive spells, rites and biome transformation. | Original faith trait pool with rites. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Clans | Royal bloodlines holding power, led by a chief. | Dynasty entity with chief and prestige. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Clan traits | Clans gain 1-3 random traits. | Dynasty traits inherited by members. | Society | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Families | Families are a meta object. | Household entity for kin groups. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Meta splits / schisms | Cultures, languages and religions divide over time. | Schism rules based on distance and drift. | Society | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Species-specific meta traits | Each sapient species has its own culture/faith/clan trait sets. | Trait sets filtered by species. | Society | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |

### Nature & Ecology

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Predator/prey | Carnivores hunt herbivores; civs hunt animals. | Diet-driven hunting with population feedback. | Ecology | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Grazing and regrowth | Herbivores consume plants, plants regrow. | Vegetation biomass consumed and regrown. | Ecology | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] Part of slice animal. |
| Diet types | Herbivore, carnivore, omnivore and exotic diets. | Diet tags on subspecies. | Ecology | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Population caps | Animal numbers limited by food. | Carrying capacity per region. | Ecology | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Sea life | Fish and sea creatures. | Fish stocks and marine fauna. | Ecology | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Extinction tracking | Species can die out. | Extinction events logged. | Ecology | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Planetary feedback | A classic planet sim links biomes to atmosphere/climate. | Optional global climate variable fed by vegetation. | Ecology | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From SimEarth. |

### Disease

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Disease framework | Plague-like statuses spread between units. | Data-driven diseases with incubation and mortality. | Disease | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Contagion | Infection spreads by proximity. | Proximity and contact transmission. | Disease | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Immunity | Traits grant resistance. | Immunity from traits and survival. | Disease | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Transformation infection | Some infections turn victims into hostile creatures. | Transforming disease variant. | Disease | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Environment/Fire/Weather

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Fire spread | Fire spreads across flammable tiles and buildings. | Cellular fire with fuel and moisture. | Environment | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Extinguishing | Rain and water put fires out. | Water/rain reduce fire intensity. | Environment | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Burnt ground | Burned tiles recover. | Scorched state with regrowth timer. | Environment | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Status effects framework | Roughly 57 statuses (burning, frozen, poisoned, drowning, etc.). | Data-driven status system with stacking rules. | Environment | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Clouds and rain | Clouds of several kinds (rain, snow, acid, fire) drift. | Cloud entities drifting with wind. | Environment | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Day/night | Long nights during a dark era. | Lighting cycle modulated by era. | Environment | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Seasons | Seasonal cycles. | Optional seasons. | Environment | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [U] |

### Ages & Disasters

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| World ages | About 10 eras lasting 30+ years each; alter crops, light, biomes. | Era system with modifiers and history entries. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Era clock control | Player controls how eras advance. | Era clock UI: lock, skip, schedule. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Harsh-era crop failure | Cold/dark eras cause crop losses. | Crop failure chance per era. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Earthquake | Earthquakes damage terrain and buildings. | Earthquake disaster. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Volcanic eruption | Volcanoes erupt lava. | Eruption event. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Tornado | Tornadoes throw units. | Tornado entity. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Meteor strike | Meteors cause impact craters. | Impact disaster. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Flood / tsunami | Large wave floods coasts. | Flood event. | Ages | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| Random disaster scheduler | Disasters occur automatically; toggled by laws. | Scheduler with frequency and law toggles. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Monster invasions | Monster spawns as disasters. | Invasion events. | Ages | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Storyteller pacing | Colony sims pace events with tension curves. | Optional director profiles (calm, rising, chaotic). | Ages | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From RimWorld. |

### History & Stats

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| World history log | Events auto-logged with filters for rulers, favourites, cities, kingdoms, wars, clans and disasters. | Structured event log with typed events, filters and jump-to-location. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| History timeline | Past events can be reviewed after the fact. | Scrollable timeline grouped by era and year. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| World statistics panel | World age, population, beasts, deaths, trees, houses, villages, islands. | Live world-stats panel fed by the stats service. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Graphs | Time-series graphs with delta tooltips, zero-series hiding, very long time scales. | Graph widget over sampled series with selectable ranges. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Per-meta history | Kingdoms/cultures etc. keep their own records. | Each meta stores founding, peak, key events, end. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Cross-world lifetime stats | Statistics accumulated across all worlds a player has run. | Profile-level stats file independent of saves. | History | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Achievements | Around 96 achievements, some requiring deliberate play. | Small original achievement set, offline only. | History | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Legends browser | A deep history sim lets players browse historical figures, sites and events after worldgen. | Browser for notable figures, sites and events with cross-links. | History | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Dwarf Fortress. |
| Historical border replay | Maps showing how territories changed over time. | Scrub a slider to replay border snapshots. | History | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Dwarf Fortress / Ages of Conflict. |
| Pre-simulated history | World generation can run centuries of history before play starts. | Optional headless warm-up of N years during worldgen. | History | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Dwarf Fortress. |

### Inspection & UI

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Unit inspection panel | Clicking a unit shows stats, traits, equipment, relations and current task. | Unit panel: stats, needs, traits, inventory, task, relations. | UI | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| City inspection panel | Village window shows population, resources, buildings, leader. | City panel: population, stockpile, buildings, jobs, leader. | UI | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Kingdom panel | Kingdom window with ruler, cities, wars, relations. | Kingdom panel with opinion reasons and war list. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Meta-object windows | Dedicated windows for cultures, languages, religions, clans, families, subspecies, armies, alliances. | One reusable meta-window template with tabs. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Meta selection from map | Clicking the map selects the meta object of the active layer. | Layer-aware picking on the map. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Favourites | Units and metas can be starred for tracking and dedicated logs. | Favourites list with event alerts and quick focus. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Follow camera | Camera can follow a selected unit. | Follow mode with smooth tracking. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Lists and search | Browsable lists of kingdoms, cities, units and metas. | Sortable, searchable list panels. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Event notifications | On-screen messages for notable events. | Notification feed with click-to-locate. | UI | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Tooltips | Hover tooltips explain stats and traits. | Consistent tooltip system incl. modifier breakdowns. | UI | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Localization | Many languages translated (several at 100%). | All strings via translation tables from day one. | UI | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Control/Possession

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Possession / direct control | Player takes direct control of a single unit to move and fight. | Possess any unit; keyboard movement and attack; AI resumes on exit. | Control | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Possessed-unit actions | Controlled units can perform context actions. | Context actions: talk, attack, pick up, cast. | Control | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| Army command | Direct orders to armies. | Rally-point and target orders for a possessed commander. | Control | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| Learning god avatar | A god game features a creature that learns from player feedback. | Optional avatar creature trained by reward/punish. | Control | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Black & White. |

### Admin & Laws

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| World laws | A menu toggles rules governing the world. | Law registry with per-world values saved in the file. | Admin | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Law categories | Laws covering civilization, diplomacy, rebellion, settlers, disasters, mutation. | Grouped laws with descriptions and defaults. | Admin | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Sandbox unlock law | A law unlocks everything for one world but blocks achievements. | Per-world sandbox flag that disables achievements. | Admin | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] |
| Admin panel | Not a reference feature; developer tooling. | Admin panel: spawn, set stats, force events, inspect state. | Admin | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [NEW] Internal tooling. |
| Simulation parameters | Planet sims expose rates like mutation and reproduction. | Sliders for mutation, birth, spread and disaster rates. | Admin | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] Also SimEarth. |
| Performance overlay | Not a documented reference feature. | Overlay: FPS, tick ms per system, entity counts. | Admin | IMPORTANT | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [NEW] Internal tooling. |
| Determinism checker | Not a reference feature. | State hash per tick to verify replays and saves. | Admin | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [NEW] Internal tooling. |

### Persistence

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Save/load slots | Multiple save slots with preview images. | Slots with thumbnails, metadata and format versioning. | Persistence | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Autosave | Periodic automatic saves. | Rotating autosave slots on a timer. | Persistence | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| Save migration | Older saves remain loadable after updates. | Versioned migration steps with tests. | Persistence | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| World file export/import | Worlds can be exported and shared as files. | Portable compressed world file. | Persistence | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Save meta objects | Players ask to save/load individual metas (clans, cultures). | Export a subspecies/culture template for reuse. | Persistence | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] Community request. |

### Presentation

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Camera pan/zoom | Drag to pan, scroll/pinch to zoom. | Smooth pan/zoom with bounds and zoom-dependent detail. | Presentation | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Time controls | Pause and several simulation speeds. | Pause, 1x, 2x, 5x, 10x with fixed-step sim. | Presentation | CORE | IN PROGRESS (slice) | IN PROGRESS (slice) | IN PROGRESS (slice) | [V] |
| Meta overlays | Toggleable overlays for kingdoms, villages, cultures, alliances, clans. | Overlay per meta type incl. religion and language. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Data heatmaps | Not a documented reference feature. | Heatmaps: population, fertility, temperature, happiness. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [NEW] |
| Original pixel art | Top-down pixel-art tiles and units. | Fully original pixel art and palette. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] No asset reuse. |
| Unit animations | Walking, working, attacking animations. | Small sprite animation set per body type. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Particles and effects | Explosions, fire, weather visuals. | Pooled particle effects. | Presentation | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Sound effects | Sounds for powers, combat, events. | Original SFX with distance attenuation. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Music | Background music. | Original music reacting to era and war. | Presentation | POLISH | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Accessibility | Not publicly documented. | Colour-blind palettes, UI scale, remappable keys. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [NEW] |
| Map name labels | Kingdom and city names shown on map. | Zoom-aware labels. | Presentation | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |

### Modding/Other

| Feature | Reference behavior | Our intended behavior | Subsystem | Priority | Implementation status | Test status | Visual validation status | Notes |
|---|---|---|---|---|---|---|---|---|
| Data-driven content | Game content is extended by community mods. | All species/traits/buildings/laws in data files. | Modding | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Mod API | Community-maintained mod loader on desktop. | Documented data-mod folder; scripting later. | Modding | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Scenario editor | Map sims offer scenario and map editors. | Scenario files with preset polities and laws. | Modding | OPTIONAL | NOT STARTED | NOT STARTED | NOT STARTED | [V][NEW] From Ages of Conflict. |
| Headless simulation | Not a reference feature. | Run sim without rendering for tests/benchmarks. | Modding | IMPORTANT | NOT STARTED | NOT STARTED | NOT STARTED | [NEW] Internal tooling. |
| Steam Workshop / map portal | Players upload and download worlds and mods online. | None; local file sharing only. | Modding | OUT OF SCOPE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Multiplayer | Not offered in reference. | None. | Modding | OUT OF SCOPE | NOT STARTED | NOT STARTED | NOT STARTED | [U] |
| Premium / monetized tier | Mobile version gates powers behind premium purchase. | None; single complete product. | Modding | OUT OF SCOPE | NOT STARTED | NOT STARTED | NOT STARTED | [V] |
| Meme / pop-culture content | Reference includes joke creatures and references. | None; original tone only. | Modding | OUT OF SCOPE | NOT STARTED | NOT STARTED | NOT STARTED | [V] IP risk. |

## Additional systems identified beyond the master spec

Rows tagged `[NEW]` (52 total), by subsystem:

- **World & Terrain:** Continents / archipelago presets; Map size tiers; Biome spread competition; Roads; Image-to-map import
- **God Powers:** Hand / grab tool; Uplift artifact; Power unlock progression; Faith/mana budget mode
- **Creatures:** Animal civilizations; Levels and experience; Civic aptitudes; Leader personalities; Happiness; Relationships; Conversations; Reproduction modes
- **Genetics & Traits:** Gene synergy; Visual phenotype; Conditional evolution
- **AI:** Weighted-choice decision system; Layered behaviour sources; Behaviour toggles
- **Kingdoms & Politics:** Plots
- **Diplomacy & War:** Naval troop transport; Religious war rites
- **Economy & Buildings:** Item quality tiers; Personal wealth and loot; Books as knowledge; Market prices
- **Society:** Procedural naming; Meta splits / schisms; Species-specific meta traits
- **Nature & Ecology:** Planetary feedback
- **Environment/Fire/Weather:** Status effects framework
- **Ages & Disasters:** Era clock control; Storyteller pacing
- **History & Stats:** Cross-world lifetime stats; Achievements; Legends browser; Historical border replay; Pre-simulated history
- **Control/Possession:** Learning god avatar
- **Admin & Laws:** Sandbox unlock law; Admin panel; Performance overlay; Determinism checker
- **Persistence:** Save meta objects
- **Presentation:** Data heatmaps; Accessibility
- **Modding/Other:** Scenario editor; Headless simulation

### Highest-value additions (recommended for the master spec)

1. **Weighted-choice AI with layered behaviour sources.** Traits, culture, faith, clan and items all add candidate actions to a unit's decisions. This is the backbone that makes every other system matter.
2. **Plots.** Planned political actions that are visible and interruptible (wars, rebellions, new faiths) and take years to complete. They give the player warning and a reason to intervene.
3. **Status-effect framework.** One data-driven system behind fire, cold, poison, disease, blessings and curses.
4. **Social conversations as the transmission channel.** When units talk, culture, language and faith spread between them and relationships form.
5. **Happiness with itemized causes, plus relationship graph.** Drives staying home, pairing and loyalty.
6. **Books and libraries as knowledge carriers.** Knowledge can be physically lost when libraries burn, and a language dies out when it has no speakers and no books left.
7. **Uplift/animal civilizations.** Any species can gain sapience (through genetics or an artifact) and found a civ.
8. **Armies as first-class entities with commanders**, plus naval transport requests for overseas wars and colonization.
9. **Era clock and biome-spread competition.** Eras change which biomes spread and how crops grow, and the player can steer the timing.
10. **Legends-style history browser** (from Dwarf Fortress), with optional pre-simulated history and border replay.

Also worth noting: reproduction modes per subspecies, leader aptitudes/personalities, XP/levels, item quality tiers, trade/fishing boats, meta schisms, lifetime stats, and a sandbox law that disables achievements.

## Explicitly OUT OF SCOPE

| Item | Reason |
|---|---|
| Multiplayer / shared worlds | Deterministic single-player sim first. Networking multiplies scope and QA cost with little benefit for an observation sandbox. |
| Steam Workshop / online map and mod portal | Needs hosting, moderation and legal work. Local file import/export covers sharing. |
| Monetized premium tier / gated powers / ads | We ship one complete product. Paywalling core god powers conflicts with sandbox design. |
| Mobile/touch-first UI | Desktop (mouse + keyboard) is the target. We keep UI scalable, but touch is not planned. |
| Proprietary names, art, icons, text, joke/meme creatures | Clean-room requirement. All content must be original, and pop-culture references carry IP risk. |
| Reference save-file compatibility (reading their map files) | That format is proprietary. Our own format and image-to-map import cover the need. |
| Running a third-party mod loader | We will not reimplement the community loader. A data-folder mod path is OPTIONAL instead. |
| Real-time 3D / planet-scale climate model | Out of genre scope. At most, a single global climate variable is OPTIONAL. |
