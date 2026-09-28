class_name CivSystem
extends RefCounted
## Settlement lifecycle: founding, territory, job allocation, farmland, construction,
## births, succession and abandonment. Every city re-plans on a staggered cadence.
## Growth is constrained by real conditions (housing, food stock, materials, land),
## never by timers alone.

const PALETTE_SIZE := 16
const FIELDS_PER_FARMER := 4
const MAX_NEW_FIELDS_PER_PLAN := 2
const TERRITORY_BASE := 80
const TERRITORY_PER_PERSON := 8
const MAX_CLAIMS_PER_PLAN := 4
## A city only claims land within this many tiles of its town hall. Land is the
## ultimate carrying capacity: growth beyond it must come from new settlements.
const MAX_TERRITORY_RADIUS := 14.0
const BIRTH_CHANCE := 0.18
## Births need stores covering this many months of the city's food need, so growth
## tracks food *production* rather than a fixed storage constant.
const BIRTH_FOOD_MONTHS := 2.0
const START_FOOD := 10.0
## One granary per this many residents may be built (storage scales with the city).
const PEOPLE_PER_GRANARY := 25
## Colonisation: crowded cities send settler bands to found new towns.
const SETTLER_MIN_POP := 28
const SETTLER_BAND := 6
const SETTLER_COOLDOWN_YEARS := 4.0
const SETTLER_MIN_DISTANCE := 26
const SETTLER_MAX_DISTANCE := 60
## Most founders a new city accepts at once; the rest stay nomads and settle elsewhere.
const MAX_FOUNDERS := 12
## Monthly decay of goods stored above capacity (spoilage / overflow).
const OVERFLOW_DECAY := 0.3
## Share of adults drafted as soldiers while their kingdom is at war.
const SOLDIER_SHARE := 0.3
## Famine: share of a town that must be urgently hungry, and years between chronicle entries.
const FAMINE_HUNGRY_SHARE := 0.25
const FAMINE_RECORD_GAP_YEARS := 5

var sim: Simulation
var _blocked_logged: Dictionary = {}  ## building id -> true (log de-duplication only)
var _last_settlers: Dictionary = {}   ## city id -> tick settlers last left (saved)
var settler_attempts: Dictionary = {}  ## settler unit id -> founding attempts at the destination (saved)
var settler_origin: Dictionary = {}    ## settler unit id -> kingdom id they set out from (saved)
var _human: Defs.SpeciesDef
var _meal_food: float


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_human = Defs.species[sim.human_species]
	_meal_food = float(_human.raw["meal_food"])


func update() -> void:
	var monthly := sim.tick % SimConst.TICKS_PER_MONTH == 0
	for c: City in sim.cities.values():
		if (sim.tick + c.id * 7) % SimConst.CITY_PLAN_INTERVAL == 0:
			_plan(c)
		if monthly and c.alive:
			_monthly(c)


# ------------------------------------------------------------------ founding

## Scores a potential settlement site. Returns {ok, score, reasons}.
func evaluate_site(ti: int, check_companions_for: int = -1) -> Dictionary:
	var w := sim.world
	var reasons: Array = []
	var x := ti % w.width
	var y := ti / w.width
	if not _can_place_footprint(-1, x, y, 2):
		return {"ok": false, "score": 0.0, "reasons": [["site blocked", "no room for a town hall"]]}
	var nearest := INF
	for c: City in sim.cities.values():
		var cx := c.center % w.width
		var cy := c.center / w.width
		nearest = minf(nearest, Vector2(cx - x, cy - y).length())
	if nearest < SimConst.FOUND_MIN_CITY_DISTANCE:
		return {"ok": false, "score": 0.0, "reasons": [["too close to another city", nearest]]}
	var fert := 0.0
	var owned := 0
	var r := SimConst.FOUND_SITE_RADIUS
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r or not w.in_bounds(x + dx, y + dy):
				continue
			var i := w.idx(x + dx, y + dy)
			if w.owner[i] != SimConst.CITY_NONE:
				owned += 1
			elif w.is_walkable(i):
				fert += w.fertility(i)
	reasons.append(["fertile land", fert])
	var score := fert
	var water := _has_biome_near(x, y, 7, [Defs.biome_index("shallow"), Defs.biome_index("ocean")])
	if water:
		score += 8.0
		reasons.append(["water access", 8.0])
	if _has_biome_near(x, y, 9, [Defs.forest_index]):
		score += 6.0
		reasons.append(["timber nearby", 6.0])
	if _has_biome_near(x, y, 12, [Defs.hills_index, Defs.mountain_index]):
		score += 3.0
		reasons.append(["stone nearby", 3.0])
	if owned > 0:
		score -= owned
		reasons.append(["contested land", -float(owned)])
	if nearest != INF:
		reasons.append(["distance to nearest city", nearest])
	var ok := score >= SimConst.FOUND_MIN_SITE_SCORE
	if check_companions_for >= 0:
		var band := _band_of(check_companions_for)
		reasons.append(["band size", band.size()])
		if band.size() < 2:
			ok = false
	reasons.append(["threshold", SimConst.FOUND_MIN_SITE_SCORE])
	return {"ok": ok, "score": score, "reasons": reasons}


func _has_biome_near(x: int, y: int, r: int, biomes: Array) -> bool:
	var w := sim.world
	# Coarse ring sampling (step 2) is enough to answer "is there any nearby?".
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if w.in_bounds(x + dx, y + dy) and w.biome[w.idx(x + dx, y + dy)] in biomes:
				return true
	return false


## Cityless ADULTS of the same species near unit s (including s), nearest first.
func _band_of(s: int) -> PackedInt32Array:
	var u := sim.units
	var out := PackedInt32Array()
	for o in sim.spatial.query_radius(u, u.x[s], u.y[s], SimConst.CITY_JOIN_RADIUS, u.species[s]):
		if u.city[o] == SimConst.CITY_NONE and u.age_years(o, sim.tick) >= _human.adult_age:
			out.append(o)
	return out


func try_found_here(s: int, ti: int) -> bool:
	if not sim.laws.is_on("settlement_founding"):
		return false
	var ev := evaluate_site(ti, s)
	if not ev["ok"]:
		return false
	found_city(s, ti, ev["reasons"])
	return true


## Picks the best of a few random nearby candidate sites (by score), or -1.
func scout_site(ti: int) -> int:
	var w := sim.world
	var best := -1
	var best_score := -INF
	var cx := ti % w.width
	var cy := ti / w.width
	for k in 6:
		var x := clampi(cx + sim.rng.randi_range(-24, 24), 0, w.width - 1)
		var y := clampi(cy + sim.rng.randi_range(-24, 24), 0, w.height - 1)
		var i := w.idx(x, y)
		if not w.is_walkable(i):
			continue
		var ev := evaluate_site(i)
		if float(ev["score"]) > best_score:
			best_score = ev["score"]
			best = i
	return best


## Landscape words for naming a town founded at tile `ti`.
func _site_features(ti: int) -> PackedStringArray:
	var w := sim.world
	var counts := {}
	var cx := ti % w.width
	var cy := ti / w.width
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			if not w.in_bounds(cx + dx, cy + dy):
				continue
			var i := w.idx(cx + dx, cy + dy)
			var b: Defs.BiomeDef = Defs.biomes[w.biome[i]]
			var key := ""
			match b.id:
				"ocean", "deep_ocean":
					key = "coast"
				"shallow":
					key = "water"
				"forest", "mystic":
					key = "forest"
				"hills", "mountain":
					key = "hill"
				"snow":
					key = "cold"
				"desert":
					key = "dry"
				"swamp":
					key = "marsh"
			if key != "":
				counts[key] = int(counts.get(key, 0)) + 1
	var out := PackedStringArray()
	for k: String in counts:
		if int(counts[k]) >= 4:
			out.append(k)
	out.sort()
	return out


func found_city(s: int, ti: int, reasons: Array) -> City:
	var u := sim.units
	var w := sim.world
	# Read before join_city() clears the settler bookkeeping.
	var origin: Kingdom = sim.kingdoms.get(int(settler_origin.get(u.id[s], -1)), null)
	var c := City.new()
	c.id = sim.next_city_id
	sim.next_city_id += 1
	var taken := {}
	for other: City in sim.cities.values():
		taken[other.name] = true
	c.name = NameGen.city_name(Defs.species[u.species[s]], sim.rng, taken, _site_features(ti))
	c.species = u.species[s]
	c.founded_tick = sim.tick
	c.founder_id = u.id[s]
	c.leader_id = u.id[s]
	c.color_index = (c.id * 5) % PALETTE_SIZE
	c.founding_reasons = reasons
	c.storage["food"] = START_FOOD
	c.job_counts.resize(Defs.jobs.size())
	c.job_targets.resize(Defs.jobs.size())
	sim.cities[c.id] = c
	var x := ti % w.width
	var y := ti / w.width
	var hall := _place_building(c, Defs.building_by_id("town_hall").index, x, y, true)
	c.center = hall.center_tile(w.width)
	_claim_disk(c, c.center % w.width, c.center / w.width, SimConst.CITY_START_RADIUS)
	join_city(s, c)
	var joined := 1
	for o in _band_of(s):
		if joined >= MAX_FOUNDERS:
			break
		if u.city[o] == SimConst.CITY_NONE:
			join_city(o, c)
			joined += 1
	_recompute_capacity(c)
	# Colonies stay loyal to the kingdom their settlers came from.
	if origin != null:
		sim.realm.add_city(origin, c)
	else:
		sim.realm.create_for_city(c, -1, "founded by %s's band" % u.name[s])
	sim.history.record(sim.tick, HistoryLog.Kind.CITY_FOUNDED, "%s was founded by %s%s." % [c.name, u.name[s], (" for the " + origin.name) if origin != null else ""], {"city": c.id, "unit": u.id[s], "kingdom": c.kingdom}, c.center)
	sim.decisions.record(sim.tick, "settlement", u.name[s], "founded %s" % c.name, reasons, {"city": c.id})
	return c


func find_joinable_city(s: int, radius: float) -> City:
	var u := sim.units
	var w := sim.world
	var best: City = null
	var best_d := radius
	for c: City in sim.cities.values():
		if c.species != u.species[s] or c.population() >= c.housing + 2:
			continue
		var d := Vector2(float(c.center % w.width) - u.x[s], float(c.center / w.width) - u.y[s]).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func join_city(s: int, c: City) -> void:
	var u := sim.units
	if u.city[s] == c.id:
		return
	if u.city[s] != SimConst.CITY_NONE and sim.cities.has(u.city[s]):
		(sim.cities[u.city[s]] as City).remove_member(u.id[s])
	u.city[s] = c.id
	c.members.append(u.id[s])
	u.set_flag(s, UnitStore.Flag.SETTLER, false)
	settler_attempts.erase(u.id[s])
	settler_origin.erase(u.id[s])
	# Dependent cityless children follow their parent into the city.
	for cid in u.children.get(u.id[s], PackedInt64Array()):
		var cs := u.slot_for(cid)
		if cs >= 0 and u.city[cs] == SimConst.CITY_NONE and u.age_years(cs, sim.tick) < _human.adult_age:
			u.city[cs] = c.id
			c.members.append(cid)


# ------------------------------------------------------------------ planning

func _plan(c: City) -> void:
	if c.population() == 0:
		abandon_city(c, "its last inhabitant is gone")
		return
	_recompute_capacity(c)
	_ensure_leader(c)
	_validate_fields(c)
	_assign_jobs(c)
	_manage_fields(c)
	if sim.laws.is_on("construction"):
		_plan_construction(c)
	_expand_territory(c)


func _recompute_capacity(c: City) -> void:
	var housing := 0
	var food_cap := float(Defs.building_globals.get("base_food_capacity", 100))
	var valid := PackedInt32Array()
	for bid in c.buildings:
		var b: Building = sim.buildings.get(bid, null)
		if b == null:
			continue
		valid.append(bid)
		if b.complete:
			housing += b.def().housing
			food_cap += float(b.def().raw.get("food_capacity", 0))
	c.buildings = valid
	c.housing = housing
	c.food_capacity = food_cap


func _ensure_leader(c: City) -> void:
	var u := sim.units
	if u.is_alive_id(c.leader_id):
		return
	# The town chooses its most respected adult: age brings standing, and wise or
	# just people are preferred. If only children remain, the eldest child rules.
	var best := -1
	var best_score := -INF
	for mid in c.members:
		var s := u.slot_for(mid)
		if s < 0:
			continue
		var age := u.age_years(s, sim.tick)
		var score := age if age < _human.adult_age else 100.0 + minf(age, 60.0) * 0.5 + _leader_merit(u.traits[s])
		if score > best_score:
			best_score = score
			best = s
	if best >= 0:
		c.leader_id = u.id[best]
		var adult := u.age_years(best, sim.tick) >= _human.adult_age
		var ep := Traits.epithet(u.traits[best])
		var who := u.name[best] + ((" " + ep) if ep != "" else "")
		var realm: Kingdom = sim.kingdoms.get(c.kingdom, null)
		var title := "leader" if adult else "child ruler"
		if realm != null and realm.capital == c.id:
			sim.history.record(sim.tick, HistoryLog.Kind.LEADER_CHANGED, "%s became %s of %s and ruler of the %s." % [who, title, c.name, realm.name], {"city": c.id, "unit": u.id[best], "kingdom": realm.id}, c.center)
		else:
			sim.history.record(sim.tick, HistoryLog.Kind.LEADER_CHANGED, "%s became %s of %s." % [who, title, c.name], {"city": c.id, "unit": u.id[best]}, c.center)
		sim.decisions.record(sim.tick, "succession", c.name, "chose %s as leader" % u.name[best],
			[["rule", "most respected adult" if adult else "no adults left: eldest child"], ["age", u.age_years(best, sim.tick)], ["traits", ", ".join(Traits.names(u.traits[best]))]], {"city": c.id})


static func _leader_merit(mask: int) -> float:
	var m := 0.0
	if Traits.has(mask, Traits.WISE):
		m += 12.0
	if Traits.has(mask, Traits.JUST):
		m += 8.0
	if Traits.has(mask, Traits.BRAVE) or Traits.has(mask, Traits.STRONG):
		m += 4.0
	return m


## Target worker counts in priority order. Pure function of city state.
func compute_job_targets(c: City, adults: int) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(Defs.jobs.size())
	if adults <= 0:
		return t
	var pop := c.population()
	var food: float = c.storage["food"]
	var monthly_need := pop * _human.hunger_rate * SimConst.TICKS_PER_MONTH / float(_human.raw["meal_hunger"]) * _meal_food
	var months_of_food := food / maxf(1.0, monthly_need)
	var sites_ready := 0
	var wood_need := 0.0
	var stone_need := 0.0
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete:
			continue
		if b.paid or _affordable(c, b):
			sites_ready += 1
		else:
			wood_need += float(b.def().cost.get("wood", 0))
			stone_need += float(b.def().cost.get("stone", 0))
	var wood: float = c.storage["wood"]
	var stone: float = c.storage["stone"]
	var want := {}
	# Food first, scaled by how many months the stores would last.
	var food_share := 0.45 if months_of_food < 1.0 else (0.3 if months_of_food < 4.0 else 0.15)
	var food_workers := maxi(1, ceili(adults * food_share))
	want["farmer"] = ceili(food_workers * 0.6) if pop >= 3 else 0
	want["gatherer"] = food_workers - int(want["farmer"])
	# At war, a share of adults takes up arms (after the minimum food workforce).
	want["soldier"] = ceili(adults * SOLDIER_SHARE) if c.kingdom >= 0 and sim.realm.is_at_war(c.kingdom) and adults >= 3 else 0
	want["woodcutter"] = maxi(1, ceili(adults * 0.25)) if wood < wood_need + 12.0 else (1 if adults >= 4 else 0)
	want["builder"] = mini(sites_ready * 2, maxi(1, ceili(adults * 0.25)))
	want["miner"] = maxi(1, ceili(adults * 0.1)) if stone < stone_need else (1 if adults >= 8 and stone < 40.0 else 0)
	# Hunting is a hardship measure: only when stores cover < 3 months of need.
	want["hunter"] = 1 if adults >= 6 and months_of_food < 3.0 else 0
	var left := adults
	for jid in ["farmer", "gatherer", "soldier", "woodcutter", "builder", "miner", "hunter"]:
		var n := mini(int(want[jid]), left)
		t[Defs.job_by_id(jid).index] = n
		left -= n
	# Spare hands stockpile timber while it is scarce, otherwise gather food.
	var spare := "woodcutter" if wood < 60.0 else "gatherer"
	t[Defs.job_by_id(spare).index] += left
	return t


func _assign_jobs(c: City) -> void:
	var u := sim.units
	var adults: Array[int] = []
	for mid in c.members:
		var s := u.slot_for(mid)
		if s >= 0 and u.age_years(s, sim.tick) >= _human.adult_age:
			adults.append(s)
		elif s >= 0:
			u.job[s] = 0
	var targets := compute_job_targets(c, adults.size())
	var counts := PackedInt32Array()
	counts.resize(targets.size())
	var unassigned: Array[int] = []
	for s in adults:
		var j := u.job[s]
		if j != 0 and counts[j] < targets[j]:
			counts[j] += 1
		else:
			unassigned.append(s)
	for s in unassigned:
		for j in targets.size():
			if j != 0 and counts[j] < targets[j]:
				if u.job[s] != j:
					u.job[s] = j
					if u.state[s] != UnitStore.State.WORKING:
						u.task[s] = UnitStore.Task.NONE
				counts[j] += 1
				break
	c.job_targets = targets
	c.job_counts = counts


func _validate_fields(c: City) -> void:
	var w := sim.world
	var valid := PackedInt32Array()
	for f in c.fields:
		if w.biome[f] == Defs.farmland_index and w.owner[f] == c.id:
			valid.append(f)
	c.fields = valid


func _manage_fields(c: City) -> void:
	var w := sim.world
	var farmers := c.job_targets[Defs.job_by_id("farmer").index] if c.job_targets.size() > 0 else 0
	var desired := farmers * FIELDS_PER_FARMER
	var added := 0
	while c.fields.size() < desired and added < MAX_NEW_FIELDS_PER_PLAN:
		var best := -1
		var best_score := -INF
		var ccx := c.center % w.width
		var ccy := c.center / w.width
		for k in 40:
			var i: int = c.territory[sim.rng.randi_range(0, c.territory.size() - 1)]
			var b := w.biome[i]
			if not (b == Defs.grassland_index or b == Defs.biome_index("soil")):
				continue
			if w.building[i] != SimConst.BUILDING_ID_NONE or _near_building(i, 1):
				continue
			var fert := w.fertility(i)
			if fert < 0.35:
				continue
			var d := Vector2(i % w.width - ccx, i / w.width - ccy).length()
			var score := fert * 10.0 - d * 0.4 + (3.0 if _adjacent_to_field(i) else 0.0)
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			break
		w.set_biome(best, Defs.farmland_index)
		w.wood[best] = SimConst.SOIL_MAX
		sim.pathfinder.refresh_tile_cost(best)
		c.fields.append(best)
		added += 1


func _adjacent_to_field(i: int) -> bool:
	var w := sim.world
	var x := i % w.width
	var y := i / w.width
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if w.in_bounds(x + d.x, y + d.y) and w.biome[w.idx(x + d.x, y + d.y)] == Defs.farmland_index:
			return true
	return false


func _near_building(i: int, r: int) -> bool:
	var w := sim.world
	var x := i % w.width
	var y := i / w.width
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if w.in_bounds(x + dx, y + dy) and w.building[w.idx(x + dx, y + dy)] != SimConst.BUILDING_ID_NONE:
				return true
	return false


func pick_field(c: City, ux: float, uy: float) -> int:
	var w := sim.world
	var best := -1
	var best_score := INF
	for f in c.fields:
		var d := Vector2(float(f % w.width) + 0.5 - ux, float(f / w.width) + 0.5 - uy).length()
		var score := d if w.vegetation[f] >= SimConst.CROP_MATURE else d + 25.0 + float(w.vegetation[f]) * 0.1
		if score < best_score:
			best_score = score
			best = f
	return best


# ------------------------------------------------------------------ construction

func _plan_construction(c: City) -> void:
	# One housing project and one civic project may run in parallel so a stalled
	# civic build (e.g. waiting on stone) never blocks population growth.
	var house_pending := false
	var civic_pending := false
	for bid in c.buildings:
		var pb: Building = sim.buildings[bid]
		if not pb.complete:
			if pb.def().housing > 0:
				house_pending = true
			else:
				civic_pending = true
	var granary := Defs.building_by_id("granary")
	if not house_pending and c.housing - c.population() < 3:
		_start_project(c, Defs.building_by_id("house").index)
	_log_blocked_sites(c)
	var granaries := _count_buildings(c, granary.index)
	@warning_ignore("integer_division")
	var granaries_allowed := c.population() / PEOPLE_PER_GRANARY + (1 if c.population() >= int(granary.raw.get("min_population", 14)) else 0)
	if not civic_pending and granaries < granaries_allowed:
		_start_project(c, granary.index)
	elif not civic_pending:
		_plan_stone_buildings(c)


## Towns that have their granaries turn stone into civic buildings: a forge and a
## temple once they are large enough, and watchtowers (first, when at war).
func _plan_stone_buildings(c: City) -> void:
	var at_war := c.kingdom >= 0 and sim.realm.is_at_war(c.kingdom)
	var order := ["watchtower", "forge", "temple"] if at_war else ["forge", "temple", "watchtower"]
	var pop := c.population()
	for id: String in order:
		var d := Defs.building_by_id(id)
		if pop < int(d.raw.get("min_population", 999)):
			continue
		var per := int(d.raw.get("per_people", 0))
		@warning_ignore("integer_division")
		var allowed := maxi(1, pop / per) if per > 0 else 1
		if _count_buildings(c, d.index) < allowed:
			_start_project(c, d.index)
			return


## Completed buildings of type `id` in the city.
func count_complete(c: City, id: String) -> int:
	var n := 0
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete and b.def().id == id:
			n += 1
	return n


func has_building(c: City, id: String) -> bool:
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete and b.def().id == id:
			return true
	return false


## Records (once per site) that construction is waiting on missing materials.
func _log_blocked_sites(c: City) -> void:
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete or b.paid or _affordable(c, b) or _blocked_logged.has(bid):
			continue
		_blocked_logged[bid] = true
		var missing: Array = []
		for res: String in b.def().cost:
			var short := float(b.def().cost[res]) - float(c.storage.get(res, 0.0))
			if short > 0.0:
				missing.append(["missing " + res, short])
		sim.decisions.record(sim.tick, "construction", c.name, "cannot start %s yet" % b.def().name, missing, {"city": c.id, "building": bid})


func _start_project(c: City, type: int) -> void:
	var site := _find_site(c, Defs.buildings[type].size)
	if site < 0:
		sim.decisions.record(sim.tick, "construction", c.name, "could not place %s" % Defs.buildings[type].name, [["reason", "no free land in territory"]], {"city": c.id})
		return
	var b := _place_building(c, type, site % sim.world.width, site / sim.world.width, false)
	sim.decisions.record(sim.tick, "construction", c.name, "planned %s" % b.def().name,
		[["population", c.population()], ["housing", c.housing], ["wood in store", float(c.storage["wood"])]], {"city": c.id, "building": b.id})


func _count_buildings(c: City, type: int) -> int:
	var n := 0
	for bid in c.buildings:
		if (sim.buildings[bid] as Building).type == type:
			n += 1
	return n


func _find_site(c: City, size: int) -> int:
	var w := sim.world
	var best := -1
	var best_score := -INF
	var ccx := c.center % w.width
	var ccy := c.center / w.width
	for k in 48:
		var i: int = c.territory[sim.rng.randi_range(0, c.territory.size() - 1)]
		var x := i % w.width
		var y := i / w.width
		if not _can_place_footprint(c.id, x, y, size):
			continue
		var d := Vector2(x - ccx, y - ccy).length()
		var score := -d + sim.rng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = i
	return best


## Footprint must be buildable land owned by `city_id` (or unowned when city_id < 0),
## with a one-tile gap to other buildings so streets remain walkable.
func _can_place_footprint(city_id: int, x: int, y: int, size: int) -> bool:
	var w := sim.world
	for dy in range(-1, size + 1):
		for dx in range(-1, size + 1):
			var tx := x + dx
			var ty := y + dy
			var inside := dx >= 0 and dy >= 0 and dx < size and dy < size
			if not w.in_bounds(tx, ty):
				if inside:
					return false
				continue
			var i := w.idx(tx, ty)
			if w.building[i] != SimConst.BUILDING_ID_NONE:
				return false
			if inside:
				if not w.is_walkable(i) or w.biome[i] == Defs.farmland_index:
					return false
				if city_id >= 0 and w.owner[i] != city_id:
					return false
				if city_id < 0 and w.owner[i] != SimConst.CITY_NONE:
					return false
	return true


func _place_building(c: City, type: int, x: int, y: int, complete: bool) -> Building:
	var w := sim.world
	var b := Building.new()
	b.id = sim.next_building_id
	sim.next_building_id += 1
	b.type = type
	b.city = c.id
	b.x = x
	b.y = y
	b.complete = complete
	b.paid = complete
	b.progress = float(b.def().work) if complete else 0.0
	b.health = b.def().max_health
	var s := b.def().size
	for dy in s:
		for dx in s:
			var i := w.idx(x + dx, y + dy)
			w.building[i] = b.id
			w.mark_dirty(i)
	sim.buildings[b.id] = b
	c.buildings.append(b.id)
	return b


## Site a builder should work on: paid sites first, then affordable ones, housing
## before civic. Unaffordable sites are skipped so they cannot block the others.
func pick_construction(c: City) -> Building:
	var best: Building = null
	var best_rank := 99
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete:
			continue
		var rank := 0 if b.paid else (2 if _affordable(c, b) else 99)
		if b.def().housing > 0:
			rank -= 1
		if rank < best_rank:
			best_rank = rank
			best = b
	return best if best_rank < 90 else null


func _affordable(c: City, b: Building) -> bool:
	for res: String in b.def().cost:
		if float(c.storage.get(res, 0.0)) < float(b.def().cost[res]):
			return false
	return true


func try_pay(b: Building) -> bool:
	if b.paid:
		return true
	var c: City = sim.cities.get(b.city, null)
	if c == null:
		return false
	for res: String in b.def().cost:
		if float(c.storage.get(res, 0.0)) < float(b.def().cost[res]):
			return false
	for res: String in b.def().cost:
		c.take_resource(res, float(b.def().cost[res]))
	b.paid = true
	return true


func add_build_progress(b: Building, amount: float) -> void:
	b.progress += amount
	if b.progress >= b.def().work:
		b.complete = true
		b.health = b.def().max_health
		var c: City = sim.cities.get(b.city, null)
		if c != null:
			_recompute_capacity(c)
			sim.history.record(sim.tick, HistoryLog.Kind.BUILDING, "%s completed a %s." % [c.name, b.def().name.to_lower()], {"city": c.id, "building": b.id}, b.center_tile(sim.world.width))
		var s := b.def().size
		for dy in s:
			for dx in s:
				sim.world.mark_dirty(sim.world.idx(b.x + dx, b.y + dy))


func destroy_building(bid: int, reason: String) -> void:
	var b: Building = sim.buildings.get(bid, null)
	if b == null:
		return
	var w := sim.world
	var s := b.def().size
	for dy in s:
		for dx in s:
			var i := w.idx(b.x + dx, b.y + dy)
			if w.building[i] == bid:
				w.building[i] = SimConst.BUILDING_ID_NONE
				w.mark_dirty(i)
	sim.buildings.erase(bid)
	var c: City = sim.cities.get(b.city, null)
	if c == null:
		return
	var k := c.buildings.find(bid)
	if k >= 0:
		c.buildings.remove_at(k)
	_recompute_capacity(c)
	sim.history.record(sim.tick, HistoryLog.Kind.BUILDING, "A %s of %s was destroyed (%s)." % [b.def().name.to_lower(), c.name, reason], {"city": c.id}, b.center_tile(w.width))
	if b.def().storage and not _has_storage(c):
		abandon_city(c, "its town hall was destroyed")


func _has_storage(c: City) -> bool:
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete and b.def().storage:
			return true
	return false


func nearest_storage_tile(c: City, from_tile: int) -> int:
	var w := sim.world
	var fx := from_tile % w.width
	var fy := from_tile / w.width
	var best := c.center
	var best_d := INF
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if not b.complete or not b.def().storage:
			continue
		var t := b.center_tile(w.width)
		var d := Vector2(t % w.width - fx, t / w.width - fy).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## Adds goods to storage, discarding food beyond capacity (spoilage).
func deposit(c: City, res: String, amount: float) -> void:
	if res == "":
		return
	var room := maxf(0.0, capacity_of(c, res) - float(c.storage.get(res, 0.0)))
	c.add_resource(res, minf(room, amount))


# ------------------------------------------------------------------ territory

func _claim_disk(c: City, cx: int, cy: int, r: int) -> void:
	var w := sim.world
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r or not w.in_bounds(cx + dx, cy + dy):
				continue
			var i := w.idx(cx + dx, cy + dy)
			if w.owner[i] == SimConst.CITY_NONE:
				w.set_owner(i, c.id)
				c.territory.append(i)


func _expand_territory(c: City) -> void:
	var w := sim.world
	var target := TERRITORY_BASE + c.population() * TERRITORY_PER_PERSON
	if c.territory.size() >= target:
		return
	var ccx := c.center % w.width
	var ccy := c.center / w.width
	var cand := {}
	for i in c.territory:
		var x := i % w.width
		var y := i / w.width
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not w.in_bounds(x + d.x, y + d.y):
				continue
			var n := w.idx(x + d.x, y + d.y)
			if w.owner[n] != SimConst.CITY_NONE or cand.has(n):
				continue
			var dist := Vector2(x + d.x - ccx, y + d.y - ccy).length()
			if dist > MAX_TERRITORY_RADIUS:
				continue
			cand[n] = (w.fertility(n) * 2.0 if w.is_walkable(n) else -1.0) - dist * 0.15
	var picked := 0
	while picked < MAX_CLAIMS_PER_PLAN and not cand.is_empty():
		var best := -1
		var best_score := -INF
		for n: int in cand:
			if float(cand[n]) > best_score:
				best_score = cand[n]
				best = n
		cand.erase(best)
		w.set_owner(best, c.id)
		c.territory.append(best)
		picked += 1


# ------------------------------------------------------------------ monthly

func _monthly(c: City) -> void:
	var u := sim.units
	var pop := c.population()
	# A famine is people going hungry, not merely an empty granary: at least
	# FAMINE_HUNGRY_SHARE of the town must be urgently hungry with nothing in store.
	var hungry := 0
	for mid in c.members:
		var hs := u.slot_for(mid)
		if hs >= 0 and u.hunger[hs] >= SimConst.HUNGER_URGENT:
			hungry += 1
	if float(c.storage["food"]) < 1.0 and pop > 0 and hungry >= maxi(2, int(ceil(pop * FAMINE_HUNGRY_SHARE))):
		c.starving_months += 1
		if c.starving_months == 2 and sim.tick - c.last_famine_tick >= FAMINE_RECORD_GAP_YEARS * SimConst.TICKS_PER_YEAR:
			c.last_famine_tick = sim.tick
			sim.history.record(sim.tick, HistoryLog.Kind.FAMINE, "Famine struck %s: %d of %d townsfolk are going hungry." % [c.name, hungry, pop], {"city": c.id}, c.center)
			sim.decisions.record(sim.tick, "shortage", c.name, "is starving",
				[["food in store", float(c.storage["food"])], ["population", pop], ["urgently hungry", hungry], ["food produced last month", float(c.produced["food"])]], {"city": c.id})
	else:
		c.starving_months = 0
	_spoil_overflow(c)
	c.roll_month()
	_maybe_send_settlers(c)
	if not sim.laws.is_on("reproduction"):
		return
	var room := c.housing - pop
	if room <= 0 or not births_food_ok(c):
		return
	var fathers: Array[int] = []
	var mothers: Array[int] = []
	var cooldown := int(_human.birth_cooldown_years * SimConst.TICKS_PER_YEAR)
	for mid in c.members:
		var s := u.slot_for(mid)
		if s < 0:
			continue
		var age := u.age_years(s, sim.tick)
		if age < _human.fertile_min or age > _human.fertile_max:
			continue
		if u.sex[s] == UnitStore.SEX_MALE:
			fathers.append(s)
		elif sim.tick - u.last_birth_tick[s] >= cooldown and u.hunger[s] < SimConst.HUNGER_URGENT:
			mothers.append(s)
	if fathers.is_empty():
		return
	for m in mothers:
		if room <= 0:
			break
		if not sim.rng.chance(BIRTH_CHANCE * (1.5 if Traits.has(u.traits[m], Traits.FERTILE) else 1.0)):
			continue
		var f: int = fathers[sim.rng.randi_range(0, fathers.size() - 1)]
		var child := sim.spawn_unit(sim.human_species, u.x[m], u.y[m], 0.0, u.id[m], u.id[f])
		if child < 0:
			continue
		u.last_birth_tick[m] = sim.tick
		u.city[child] = c.id
		u.hunger[child] = 0.0
		c.members.append(u.id[child])
		c.births += 1
		sim.month_births += 1
		sim.total_births += 1
		room -= 1


func monthly_food_need(c: City) -> float:
	return c.population() * _human.hunger_rate * SimConst.TICKS_PER_MONTH / float(_human.raw["meal_hunger"]) * _meal_food


## Births require a food stock covering BIRTH_FOOD_MONTHS of need.
func births_food_ok(c: City) -> bool:
	return float(c.storage["food"]) >= monthly_food_need(c) * BIRTH_FOOD_MONTHS


func capacity_of(c: City, res: String) -> float:
	return c.food_capacity if res == "food" else float(Defs.building_globals.get("base_%s_capacity" % res, 200))


## Goods above capacity (god gifts, a lost granary) decay each month.
func _spoil_overflow(c: City) -> void:
	for res in City.RESOURCES:
		var cap := capacity_of(c, res)
		var have: float = c.storage[res]
		if have > cap:
			c.storage[res] = cap + (have - cap) * (1.0 - OVERFLOW_DECAY)


## Crowded cities send a band of adults (with their young children) to found a new
## town elsewhere. This is the engine of expansion after the first generation.
func _maybe_send_settlers(c: City) -> void:
	if not sim.laws.is_on("settlement_founding") or c.population() < SETTLER_MIN_POP:
		return
	if sim.tick - int(_last_settlers.get(c.id, -1000000)) < int(SETTLER_COOLDOWN_YEARS * SimConst.TICKS_PER_YEAR):
		return
	var crowding := float(c.population()) / maxf(1.0, c.housing)
	var pressure := crowding + (0.3 if not births_food_ok(c) else 0.0)
	if pressure < 0.9 or not sim.rng.chance(0.25):
		return
	var w := sim.world
	var target := -1
	var best := -INF
	var cx := c.center % w.width
	var cy := c.center / w.width
	for k in 10:
		var ang := sim.rng.randf() * TAU
		var dist := sim.rng.randf_range(SETTLER_MIN_DISTANCE, SETTLER_MAX_DISTANCE)
		var tx := clampi(cx + int(cos(ang) * dist), 0, w.width - 1)
		var ty := clampi(cy + int(sin(ang) * dist), 0, w.height - 1)
		var i := w.idx(tx, ty)
		if not w.is_walkable(i) or sim.pathfinder.component_of(i) != sim.pathfinder.component_of(c.center):
			continue
		var score := float(evaluate_site(i)["score"])
		if score > best:
			best = score
			target = i
	if target < 0 or best < SimConst.FOUND_MIN_SITE_SCORE * 0.8:
		return
	var u := sim.units
	var leaving := PackedInt32Array()
	for mid in c.members:
		var s := u.slot_for(mid)
		if s < 0 or mid == c.leader_id:
			continue
		var age := u.age_years(s, sim.tick)
		if age >= _human.adult_age and age < 40.0:
			leaving.append(s)
			if leaving.size() >= SETTLER_BAND:
				break
	if leaving.size() < 2:
		return
	_last_settlers[c.id] = sim.tick
	var names := PackedStringArray()
	for s in leaving:
		c.remove_member(u.id[s])
		u.city[s] = SimConst.CITY_NONE
		u.job[s] = 0
		u.carry_amount[s] = 0.0
		u.carry_type[s] = 0
		u.task[s] = UnitStore.Task.FOUND_CITY
		u.task_target[s] = target
		u.set_flag(s, UnitStore.Flag.SETTLER, true)
		settler_attempts[u.id[s]] = 0
		settler_origin[u.id[s]] = c.kingdom
		u.next_think[s] = sim.tick
		sim.movement.stop(s)
		names.append(u.name[s])
		for cid in u.children.get(u.id[s], PackedInt64Array()):
			var cs := u.slot_for(cid)
			if cs >= 0 and u.city[cs] == c.id and u.age_years(cs, sim.tick) < _human.adult_age:
				c.remove_member(cid)
				u.city[cs] = SimConst.CITY_NONE
				u.job[cs] = 0
	sim.history.record(sim.tick, HistoryLog.Kind.MIGRATION, "Settlers led by %s left %s to seek new land." % [names[0], c.name], {"city": c.id, "unit": u.id[leaving[0]]}, target)
	sim.decisions.record(sim.tick, "settlement", c.name, "sent %d settlers" % leaving.size(),
		[["crowding (people / housing)", crowding], ["food for births", "short" if not births_food_ok(c) else "ok"], ["target site score", best]], {"city": c.id})


func abandon_city(c: City, reason: String) -> void:
	if not c.alive:
		return
	var u := sim.units
	var w := sim.world
	for mid in c.members:
		var s := u.slot_for(mid)
		if s >= 0:
			u.city[s] = SimConst.CITY_NONE
			u.job[s] = 0
			u.carry_amount[s] = 0.0
			u.carry_type[s] = 0
	c.members = PackedInt64Array()
	for i in c.territory:
		if w.owner[i] == c.id:
			w.set_owner(i, SimConst.CITY_NONE)
		if w.biome[i] == Defs.farmland_index:
			w.set_biome(i, Defs.biome_index("soil"))
			sim.pathfinder.refresh_tile_cost(i)
	for bid in c.buildings.duplicate():
		var b: Building = sim.buildings.get(bid, null)
		if b == null:
			continue
		var s := b.def().size
		for dy in s:
			for dx in s:
				var i := w.idx(b.x + dx, b.y + dy)
				w.building[i] = SimConst.BUILDING_ID_NONE
				w.mark_dirty(i)
		sim.buildings.erase(bid)
	c.buildings = PackedInt32Array()
	c.territory = PackedInt32Array()
	c.fields = PackedInt32Array()
	c.alive = false
	sim.realm.detach_city(c)
	# Remove immediately so nothing can join or reference the dead city later this tick.
	sim.cities.erase(c.id)
	sim.history.record(sim.tick, HistoryLog.Kind.CITY_ABANDONED, "%s was abandoned: %s." % [c.name, reason], {"city": c.id}, c.center)
	sim.decisions.record(sim.tick, "settlement", c.name, "was abandoned", [["reason", reason]], {"city": c.id})


## Called by world-editing code after a tile's biome changed.
func on_tile_changed(i: int) -> void:
	var w := sim.world
	var bid := w.building[i]
	if bid != SimConst.BUILDING_ID_NONE and not w.is_walkable(i):
		destroy_building(bid, "the ground beneath it changed")


func to_dict() -> Dictionary:
	return {"last_settlers": _last_settlers.duplicate(), "settler_attempts": settler_attempts.duplicate(), "settler_origin": settler_origin.duplicate(), "blocked_logged": _blocked_logged.duplicate()}


func from_dict(d: Dictionary) -> void:
	_last_settlers = d.get("last_settlers", {})
	settler_attempts = d.get("settler_attempts", {})
	settler_origin = d.get("settler_origin", {})
	_blocked_logged = d.get("blocked_logged", {})
