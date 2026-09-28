class_name HumanAI
extends RefCounted
## Hierarchical decision making for sapient units. A unit only re-plans ("thinks")
## when idle and its staggered think tick arrives, never every frame:
##   1. Survival  – escape hazards, eat (city stores > carried food > forage)
##   2. Logistics – deliver carried goods to the nearest storage
##   3. Society   – nomads join or found settlements; children stay near home
##   4. Work      – perform the job assigned by the city planner
## Movement and timed work run every tick; decisions run at most every THINK_INTERVAL.

const CARRY_FOOD := 1
const CARRY_WOOD := 2
const CARRY_STONE := 3
const TEND_BOOST := 40
const NOMAD_FLOCK_RADIUS := 14.0
const HUNT_KILL_RANGE := 1.5
const JOIN_SEARCH_RADIUS := 40.0
const TOP_UP_HUNGER := 25.0
const FARM_CARRY_LIMIT := 10.0
const FARM_HOP_RADIUS := 6.0
const MIN_HERD_TO_HUNT := 5
const ENGAGE_RADIUS := 9.0
const MELEE_RANGE := 1.4
const FLEE_RADIUS := 5.0
## Soldiers with id % GARRISON_EVERY == 0 defend their own town instead of marching.
const GARRISON_EVERY := 3

var sim: Simulation
var _def: Defs.SpeciesDef
var _meal_food: float
var _meal_hunger: float
var _jobs: Array[Defs.JobDef]


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_def = Defs.species[sim.human_species]
	_meal_food = float(_def.raw["meal_food"])
	_meal_hunger = float(_def.raw["meal_hunger"])
	_jobs = Defs.jobs


## Called by the simulation's dispatch pass only for units that need attention:
## a movement event (arrived/blocked), timed work, a due think, or a hunger check.
func dispatch(s: int, ev: int) -> void:
	var u := sim.units
	if ev == MovementSystem.EV_ARRIVED:
		_on_arrive(s)
		return
	if ev == MovementSystem.EV_BLOCKED:
		u.next_think[s] = sim.tick + 1
		return
	update(s)


func update(s: int) -> void:
	var u := sim.units
	# Hunger interrupt: long trips and jobs are abandoned when food becomes urgent.
	if u.state[s] != UnitStore.State.IDLE and u.hunger[s] >= SimConst.HUNGER_URGENT \
			and (sim.tick + s) % SimConst.THINK_INTERVAL == 0 and not _is_food_task(u.task[s]):
		sim.movement.stop(s)
		u.task[s] = UnitStore.Task.NONE
		_think(s)
		return
	match u.state[s]:
		UnitStore.State.MOVING:
			# Marching soldiers break off to engage enemies they come across.
			if u.task[s] == UnitStore.Task.MARCH:
				var c: City = sim.cities.get(u.city[s], null)
				if c != null and _nearest_enemy(s, c.kingdom, ENGAGE_RADIUS, false) >= 0:
					sim.movement.stop(s)
					_think(s)
		UnitStore.State.WORKING:
			u.task_timer[s] -= 1
			if u.task_timer[s] <= 0:
				u.state[s] = UnitStore.State.IDLE
				_on_work_done(s)
		_:
			if sim.tick >= u.next_think[s]:
				_think(s)


func _is_food_task(t: int) -> bool:
	return t == UnitStore.Task.GO_HOME or t == UnitStore.Task.FORAGE or t == UnitStore.Task.HUNT \
		or t == UnitStore.Task.FARM or t == UnitStore.Task.SEEK_LAND


# ------------------------------------------------------------------ decisions

func _think(s: int) -> void:
	var u := sim.units
	var w := sim.world
	u.next_think[s] = sim.tick + SimConst.THINK_INTERVAL
	var ti := int(u.y[s]) * w.width + int(u.x[s])
	if not w.is_walkable(ti):
		var land := w.nearest_walkable(int(u.x[s]), int(u.y[s]), 10)
		if land >= 0:
			u.task[s] = UnitStore.Task.SEEK_LAND
			sim.movement.go_to(s, land, false)
		return
	var city: City = sim.cities.get(u.city[s], null)
	var adult := u.age_years(s, sim.tick) >= _def.adult_age

	# 1. Survival. At home with food in store, top up before setting out so long
	# work trips do not end in a hunger retreat.
	if city != null and u.hunger[s] >= TOP_UP_HUNGER and u.hunger[s] < SimConst.HUNGER_EAT_THRESHOLD \
			and w.owner[ti] == city.id and float(city.storage["food"]) >= _meal_food:
		_eat_from_store(s, city)
	if u.hunger[s] >= SimConst.HUNGER_EAT_THRESHOLD:
		if u.carry_type[s] == CARRY_FOOD and u.carry_amount[s] > 0.0:
			var take := minf(u.carry_amount[s], _meal_food)
			u.carry_amount[s] -= take
			if u.carry_amount[s] <= 0.0:
				u.carry_type[s] = 0
			u.hunger[s] = maxf(0.0, u.hunger[s] - _meal_hunger * take / _meal_food)
			u.next_think[s] = sim.tick + 1
			return
		if city != null and float(city.storage["food"]) >= _meal_food * 0.5:
			if w.owner[ti] == city.id:
				_eat_from_store(s, city)
				u.next_think[s] = sim.tick + 1
				return
			if _go(s, city.center, UnitStore.Task.GO_HOME):
				return
		if _forage(s):
			return

	# 2. Logistics
	if u.carry_amount[s] > 0.0 and city != null:
		if _go(s, sim.civ.nearest_storage_tile(city, ti), UnitStore.Task.DELIVER):
			return

	# 3. Society
	if city == null:
		_nomad(s, ti, adult)
		return
	if not adult:
		_wander_near(s, city.center, 6)
		return

	# War: civilians run home from enemy soldiers.
	var soldier_job := _jobs[u.job[s]].id == "soldier"
	if not soldier_job and city.kingdom >= 0 and not Traits.has(u.traits[s], Traits.BRAVE) and sim.realm.is_at_war(city.kingdom):
		if _nearest_enemy(s, city.kingdom, FLEE_RADIUS, true) >= 0:
			var cx := city.center % w.width
			var cy := city.center / w.width
			if Vector2(cx - u.x[s], cy - u.y[s]).length() > 3.0 and _go(s, city.center, UnitStore.Task.FLEE):
				return

	# 4. Work
	var job_id: String = _jobs[u.job[s]].id
	match job_id:
		"gatherer":
			if _forage(s):
				return
		"farmer":
			if _farm(s, city):
				return
		"woodcutter":
			if _chop(s, ti):
				return
		"miner":
			if _quarry(s, ti):
				return
		"builder":
			if _build(s, city):
				return
		"hunter":
			if _hunt(s):
				return
		"soldier":
			if _soldier(s, city):
				return
	_wander_near(s, city.center, 7)


## Starts moving toward `tile` for `task`. Returns true if the unit is now committed
## (moving, or waiting on path budget). False means unreachable.
func _go(s: int, tile: int, task: int, use_astar: bool = true) -> bool:
	var u := sim.units
	if tile < 0:
		return false
	u.task[s] = task
	u.task_target[s] = tile
	var r := sim.movement.go_to(s, tile, use_astar)
	if r == MovementSystem.Plan.PENDING:
		u.next_think[s] = sim.tick + 1
		return true
	return r == MovementSystem.Plan.OK


func _eat_from_store(s: int, city: City) -> void:
	var u := sim.units
	var took := city.take_resource("food", _meal_food)
	u.hunger[s] = maxf(0.0, u.hunger[s] - _meal_hunger * took / _meal_food)


func _forage(s: int) -> bool:
	var u := sim.units
	var ti := int(u.y[s]) * sim.world.width + int(u.x[s])
	var jd: Defs.JobDef = Defs.job_by_id("gatherer")
	var cost := int(jd.raw["veg_cost"])
	var t := TileSearch.sample_expanding(sim, ti, jd.search_radius, 14, TileSearch.Kind.FORAGE, cost)
	if t < 0:
		return false
	return _go(s, t, UnitStore.Task.FORAGE)


func _farm(s: int, city: City) -> bool:
	var t := sim.civ.pick_field(city, sim.units.x[s], sim.units.y[s])
	if t < 0:
		return false
	return _go(s, t, UnitStore.Task.FARM)


func _chop(s: int, ti: int) -> bool:
	var jd: Defs.JobDef = Defs.job_by_id("woodcutter")
	var need := int(jd.raw["wood_cost"])
	var t := TileSearch.sample_expanding(sim, ti, jd.search_radius, 16, TileSearch.Kind.FOREST, need)
	if t < 0:
		return false
	return _go(s, t, UnitStore.Task.CHOP)


func _quarry(s: int, ti: int) -> bool:
	var jd: Defs.JobDef = Defs.job_by_id("miner")
	var t := TileSearch.sample_expanding(sim, ti, jd.search_radius, 16, TileSearch.Kind.QUARRY, 0)
	if t < 0:
		return false
	return _go(s, t, UnitStore.Task.QUARRY)


func _build(s: int, city: City) -> bool:
	var b := sim.civ.pick_construction(city)
	if b == null:
		return false
	var ok := _go(s, b.center_tile(sim.world.width), UnitStore.Task.BUILD)
	sim.units.task_target[s] = b.id
	return ok


func _hunt(s: int) -> bool:
	var u := sim.units
	var jd: Defs.JobDef = Defs.job_by_id("hunter")
	var prey := sim.spatial.query_radius(u, u.x[s], u.y[s], jd.search_radius, sim.sheep_species, 6)
	var best := -1
	var best_d := INF
	for p in prey:
		var d := Vector2(u.x[p] - u.x[s], u.y[p] - u.y[s]).length_squared()
		if d < best_d:
			best_d = d
			best = p
	# Only hunt herds of MIN_HERD_TO_HUNT+ so hunters cannot wipe out the last local breeders.
	if best < 0 or prey.size() < MIN_HERD_TO_HUNT:
		return false
	var ok := _go(s, int(u.y[best]) * sim.world.width + int(u.x[best]), UnitStore.Task.HUNT)
	u.task_target[s] = best
	return ok


## Nearest living human of a kingdom at war with `kid` within r (soldiers only if asked).
func _nearest_enemy(s: int, kid: int, r: float, soldiers_only: bool) -> int:
	if kid < 0:
		return -1
	var foes := sim.realm.enemies_of(kid)
	if foes.is_empty():
		return -1
	var u := sim.units
	var soldier := Defs.job_by_id("soldier").index
	var best := -1
	var best_d := INF
	for o in sim.spatial.query_radius(u, u.x[s], u.y[s], r, sim.human_species, 32):
		if o == s or (soldiers_only and u.job[o] != soldier):
			continue
		if not foes.has(sim.realm.kingdom_of_unit(o)):
			continue
		var d := Vector2(u.x[o] - u.x[s], u.y[o] - u.y[s]).length_squared()
		if d < best_d:
			best_d = d
			best = o
	return best


func _soldier(s: int, city: City) -> bool:
	var u := sim.units
	var kid := city.kingdom
	if not sim.realm.is_at_war(kid):
		return false
	var e := _nearest_enemy(s, kid, ENGAGE_RADIUS, false)
	if e >= 0:
		var d := Vector2(u.x[e] - u.x[s], u.y[e] - u.y[s]).length()
		if d <= MELEE_RANGE:
			u.task[s] = UnitStore.Task.FIGHT
			u.task_target[s] = e
			_start_work(s, Defs.job_by_id("soldier").work_ticks)
			return true
		var et := int(u.y[e]) * sim.world.width + int(u.x[e])
		return _go(s, et, UnitStore.Task.FIGHT, d > MovementSystem.DIRECT_RANGE)
	if u.id[s] % GARRISON_EVERY == 0:
		_wander_near(s, city.center, 5)
		return true
	for foe in sim.realm.enemies_of(kid):
		var target: City = sim.cities.get(sim.realm.war_target(kid, foe), null)
		if target != null:
			return _go(s, target.center, UnitStore.Task.MARCH)
	return false


## Food yield multiplier from a wise town leader.
func _leader_bonus(s: int) -> float:
	var c: City = sim.cities.get(sim.units.city[s], null)
	if c == null:
		return 1.0
	var ls := sim.units.slot_for(c.leader_id)
	return 1.15 if ls >= 0 and Traits.has(sim.units.traits[ls], Traits.WISE) else 1.0


func _resolve_attack(s: int) -> void:
	var u := sim.units
	var e := u.task_target[s]
	if e < 0 or e >= u.capacity or u.alive[e] == 0 or u.species[e] != sim.human_species:
		return
	var mine := sim.realm.kingdom_of_unit(s)
	var theirs := sim.realm.kingdom_of_unit(e)
	if not sim.realm.at_war(mine, theirs):
		return
	if Vector2(u.x[e] - u.x[s], u.y[e] - u.y[s]).length() > MELEE_RANGE + 0.3:
		return
	if u.has_flag(e, UnitStore.Flag.INVULNERABLE):
		return
	var dmg := float(Defs.job_by_id("soldier").raw.get("damage", 10.0)) * sim.rng.randf_range(0.7, 1.3)
	if Traits.has(u.traits[s], Traits.STRONG):
		dmg *= 1.25
	u.health[e] -= dmg
	var et := int(u.y[e]) * sim.world.width + int(u.x[e])
	sim.push_fx("hit", et)
	if u.health[e] <= 0.0:
		sim.realm.record_battle_death(theirs, mine)
		u.kills[s] += 1
		sim.kill_unit(e, "battle")


func _nomad(s: int, ti: int, adult: bool) -> void:
	var u := sim.units
	if not adult:
		var ms := u.slot_for(u.mother[s])
		if ms >= 0:
			var mt := int(u.y[ms]) * sim.world.width + int(u.x[ms])
			if Vector2(u.x[ms] - u.x[s], u.y[ms] - u.y[s]).length() > 3.0 and _go(s, mt, UnitStore.Task.FOLLOW):
				return
		_wander_near(s, ti, 4)
		return
	if u.has_flag(s, UnitStore.Flag.SETTLER):
		_settler(s, ti)
		return
	var join := sim.civ.find_joinable_city(s, JOIN_SEARCH_RADIUS)
	if join != null:
		sim.civ.join_city(s, join)
		_go(s, join.center, UnitStore.Task.GO_HOME)
		return
	if sim.laws.is_on("settlement_founding") and (sim.tick + s * 7) % SimConst.FOUND_EVAL_INTERVAL < SimConst.THINK_INTERVAL:
		if sim.civ.try_found_here(s, ti):
			return
		var better := sim.civ.scout_site(ti)
		if better >= 0 and better != ti and _go(s, better, UnitStore.Task.FOUND_CITY):
			return
	# Flock with the band: follow the lowest-id adult nomad nearby.
	var leader := -1
	for o in sim.spatial.query_radius(u, u.x[s], u.y[s], NOMAD_FLOCK_RADIUS, sim.human_species, 12):
		if o != s and u.city[o] == SimConst.CITY_NONE and (leader < 0 or u.id[o] < u.id[leader]):
			leader = o
	if leader >= 0 and u.id[leader] < u.id[s]:
		var lt := int(u.y[leader]) * sim.world.width + int(u.x[leader])
		if Vector2(u.x[leader] - u.x[s], u.y[leader] - u.y[s]).length() > 4.0:
			if _go(s, lt, UnitStore.Task.FOLLOW):
				return
		_wander_near(s, lt, 3)
		return
	_wander_near(s, ti, 8)


## Settlers travel to their chosen site, try to found there, scout nearby a few
## times, and otherwise give up and become ordinary nomads.
func _settler(s: int, ti: int) -> void:
	var u := sim.units
	var target := u.task_target[s]
	var w := sim.world
	if target >= 0 and Vector2(target % w.width - u.x[s], target / w.width - u.y[s]).length() > 3.0:
		if _go(s, target, UnitStore.Task.FOUND_CITY):
			return
	if sim.civ.try_found_here(s, ti):
		return
	var tries := int(sim.civ.settler_attempts.get(u.id[s], 0)) + 1
	sim.civ.settler_attempts[u.id[s]] = tries
	if tries > 4:
		u.set_flag(s, UnitStore.Flag.SETTLER, false)
		sim.civ.settler_attempts.erase(u.id[s])
		return
	var better := sim.civ.scout_site(ti)
	if better >= 0:
		u.task_target[s] = better
		_go(s, better, UnitStore.Task.FOUND_CITY)
		return
	_wander_near(s, ti, 6)


func _wander_near(s: int, center: int, radius: int) -> void:
	var u := sim.units
	var w := sim.world
	var cx := center % w.width
	var cy := center / w.width
	var tx := clampi(cx + sim.rng.randi_range(-radius, radius), 0, w.width - 1)
	var ty := clampi(cy + sim.rng.randi_range(-radius, radius), 0, w.height - 1)
	var t := w.idx(tx, ty)
	u.next_think[s] = sim.tick + SimConst.THINK_INTERVAL + sim.rng.randi_range(0, 16)
	if w.is_walkable(t):
		u.task[s] = UnitStore.Task.WANDER
		if sim.movement.go_to(s, t, true) == MovementSystem.Plan.PENDING:
			u.next_think[s] = sim.tick + 1


# ------------------------------------------------------------------ arrival & work

func _on_arrive(s: int) -> void:
	var u := sim.units
	var w := sim.world
	var ti := int(u.y[s]) * w.width + int(u.x[s])
	var job: Defs.JobDef = _jobs[u.job[s]]
	match u.task[s]:
		UnitStore.Task.FORAGE:
			var cost := int(Defs.job_by_id("gatherer").raw["veg_cost"])
			if TileSearch.matches(sim, ti, TileSearch.Kind.FORAGE, cost):
				_start_work(s, Defs.job_by_id("gatherer").work_ticks)
				return
		UnitStore.Task.FARM:
			if w.biome[ti] == Defs.farmland_index:
				_start_work(s, job.work_ticks if job.id == "farmer" else 30)
				return
		UnitStore.Task.CHOP:
			if w.wood[ti] > 0:
				_start_work(s, Defs.job_by_id("woodcutter").work_ticks)
				return
		UnitStore.Task.QUARRY:
			if TileSearch.matches(sim, ti, TileSearch.Kind.QUARRY, 0):
				_start_work(s, Defs.job_by_id("miner").work_ticks)
				return
		UnitStore.Task.BUILD:
			var b: Building = sim.buildings.get(u.task_target[s], null)
			if b != null and not b.complete and sim.civ.try_pay(b):
				_start_work(s, Defs.job_by_id("builder").work_ticks)
				return
		UnitStore.Task.DELIVER:
			var city: City = sim.cities.get(u.city[s], null)
			if city != null and u.carry_amount[s] > 0.0:
				sim.civ.deposit(city, UnitStore.RESOURCE_NAMES[u.carry_type[s]], u.carry_amount[s])
			u.carry_amount[s] = 0.0
			u.carry_type[s] = 0
		UnitStore.Task.HUNT:
			_resolve_hunt(s)
			return
		UnitStore.Task.FOUND_CITY:
			if not u.has_flag(s, UnitStore.Flag.SETTLER):
				sim.civ.try_found_here(s, ti)
	u.task[s] = UnitStore.Task.NONE
	u.next_think[s] = sim.tick + 1


func _start_work(s: int, ticks: int) -> void:
	sim.units.state[s] = UnitStore.State.WORKING
	sim.units.task_timer[s] = maxi(1, ticks)


func _on_work_done(s: int) -> void:
	var u := sim.units
	var w := sim.world
	var ti := int(u.y[s]) * w.width + int(u.x[s])
	match u.task[s]:
		UnitStore.Task.FORAGE:
			var jd := Defs.job_by_id("gatherer")
			var cost := int(jd.raw["veg_cost"])
			var have := w.vegetation[ti]
			if have >= cost:
				w.vegetation[ti] = have - cost
				w.mark_dirty(ti)
				var food := jd.yield_amount * (Defs.biomes[w.biome[ti]] as Defs.BiomeDef).veg_food * _leader_bonus(s)
				_receive(s, CARRY_FOOD, food)
		UnitStore.Task.FARM:
			if w.biome[ti] == Defs.farmland_index:
				if w.vegetation[ti] >= SimConst.CROP_MATURE:
					var jd := Defs.job_by_id("farmer")
					w.vegetation[ti] = 0
					w.mark_dirty(ti)
					var soil := float(w.wood[ti]) / SimConst.SOIL_MAX
					w.wood[ti] = maxi(0, w.wood[ti] - SimConst.SOIL_DRAIN)
					_receive(s, CARRY_FOOD, jd.yield_amount * (0.5 + 0.5 * w.fertility(ti)) * (0.35 + 0.65 * soil) * _leader_bonus(s))
					# Keep harvesting neighbouring ripe fields before the walk to storage.
					if u.carry_amount[s] < FARM_CARRY_LIMIT:
						var city: City = sim.cities.get(u.city[s], null)
						if city != null:
							var nxt := sim.civ.pick_field(city, u.x[s], u.y[s])
							if nxt >= 0 and w.vegetation[nxt] >= SimConst.CROP_MATURE and Vector2(nxt % w.width - u.x[s], nxt / w.width - u.y[s]).length() <= FARM_HOP_RADIUS:
								if _go(s, nxt, UnitStore.Task.FARM):
									return
				else:
					w.vegetation[ti] = mini(255, w.vegetation[ti] + TEND_BOOST)
					w.mark_dirty(ti)
		UnitStore.Task.CHOP:
			var jd := Defs.job_by_id("woodcutter")
			var cost := int(jd.raw["wood_cost"])
			var took := mini(cost, w.wood[ti])
			w.wood[ti] = w.wood[ti] - took
			if w.wood[ti] < cost and w.biome[ti] == Defs.forest_index:
				w.set_biome(ti, Defs.grassland_index)
				sim.pathfinder.refresh_tile_cost(ti)
			_receive(s, CARRY_WOOD, jd.yield_amount * float(took) / cost)
		UnitStore.Task.QUARRY:
			_receive(s, CARRY_STONE, Defs.job_by_id("miner").yield_amount)
		UnitStore.Task.BUILD:
			var b: Building = sim.buildings.get(u.task_target[s], null)
			if b != null and not b.complete:
				sim.civ.add_build_progress(b, Defs.job_by_id("builder").work_ticks)
		UnitStore.Task.FIGHT:
			_resolve_attack(s)
	u.task[s] = UnitStore.Task.NONE
	u.next_think[s] = sim.tick + 1


## Adds goods to the unit's hands; nomads without a city eat food on the spot.
func _receive(s: int, kind: int, amount: float) -> void:
	var u := sim.units
	if amount <= 0.0:
		return
	if kind == CARRY_FOOD and (u.city[s] == SimConst.CITY_NONE or u.hunger[s] >= SimConst.HUNGER_EAT_THRESHOLD):
		var eat := minf(amount, u.hunger[s] / _meal_hunger * _meal_food)
		u.hunger[s] = maxf(0.0, u.hunger[s] - _meal_hunger * eat / _meal_food)
		amount -= eat
	if u.city[s] == SimConst.CITY_NONE or amount <= 0.0:
		return
	if u.carry_type[s] != kind and u.carry_amount[s] > 0.0:
		var city: City = sim.cities.get(u.city[s], null)
		if city != null:
			sim.civ.deposit(city, UnitStore.RESOURCE_NAMES[u.carry_type[s]], u.carry_amount[s])
		u.carry_amount[s] = 0.0
	u.carry_type[s] = kind
	u.carry_amount[s] += amount


func _resolve_hunt(s: int) -> void:
	var u := sim.units
	var p := u.task_target[s]
	u.task[s] = UnitStore.Task.NONE
	u.next_think[s] = sim.tick + 1
	if p < 0 or p >= u.capacity or u.alive[p] == 0 or u.species[p] != sim.sheep_species:
		return
	var d := Vector2(u.x[p] - u.x[s], u.y[p] - u.y[s]).length()
	if d <= HUNT_KILL_RANGE:
		var meat := float((Defs.species[sim.sheep_species] as Defs.SpeciesDef).raw.get("meat_food", 10))
		sim.kill_unit(p, "hunted")
		u.kills[s] += 1
		_receive(s, CARRY_FOOD, meat)
	elif d < 10.0:
		if _go(s, int(u.y[p]) * sim.world.width + int(u.x[p]), UnitStore.Task.HUNT, d > MovementSystem.DIRECT_RANGE):
			u.task_target[s] = p
