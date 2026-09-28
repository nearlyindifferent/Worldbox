class_name AnimalAI
extends RefCounted
## Behaviour for non-sapient animals. Decisions are cheap and local: animals only
## sample a handful of nearby tiles and steer directly (no A*). Grazers eat
## vegetation and flee hunters and predators; predators (diet "carnivore") hunt
## their prey species, and when starving may attack a lone person.

const GRAZE_TICKS := 12
const GRAZE_SEARCH_RADIUS := 7
const GRAZE_SAMPLES := 10
const WANDER_RADIUS := 6
const FLEE_RADIUS := 4.0
const MATE_RADIUS := 6.0
const HERD_RADIUS := 10.0
const CROWD_RADIUS := 5.0
const HERD_COHESION := 0.4
const PACK_RADIUS := 30.0
const PACK_COHESION := 0.75
const ROAM_DISTANCE := 14.0
const CHASE_HOP := 2.5
const BITE_RANGE := 1.1
const PACK_SPLIT := 7
const MIGRATION_YEARS := 6

const HUMAN_DEFENSE_DAMAGE := 9.0
const LONE_RADIUS := 3.0

var sim: Simulation
var _carnivore := PackedByteArray()
var _prey: Array = []   ## species index -> PackedInt32Array of prey species


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_carnivore.resize(Defs.species.size())
	_prey.resize(Defs.species.size())
	for sp: Defs.SpeciesDef in Defs.species:
		_carnivore[sp.index] = 1 if sp.raw.get("diet", "") == "carnivore" else 0
		var p := PackedInt32Array()
		for id: String in sp.raw.get("prey", []):
			p.append(Defs.species_by_id(id).index)
		_prey[sp.index] = p


func is_predator(species_idx: int) -> bool:
	return _carnivore[species_idx] == 1


func dispatch(s: int, ev: int) -> void:
	var u := sim.units
	if ev == MovementSystem.EV_ARRIVED:
		if u.task[s] == UnitStore.Task.GRAZE:
			_start_graze(s)
		else:
			u.next_think[s] = sim.tick
		return
	if ev == MovementSystem.EV_BLOCKED:
		u.next_think[s] = sim.tick
		return
	update(s)


func update(s: int) -> void:
	var u := sim.units
	match u.state[s]:
		UnitStore.State.MOVING:
			pass  # movement is batched in MovementSystem.advance_all
		UnitStore.State.WORKING:
			u.task_timer[s] -= 1
			if u.task_timer[s] <= 0:
				_finish_graze(s)
		_:
			if sim.tick >= u.next_think[s]:
				_think(s)


func _think(s: int) -> void:
	var u := sim.units
	var w := sim.world
	u.next_think[s] = sim.tick + SimConst.THINK_INTERVAL
	var ti := int(u.y[s]) * w.width + int(u.x[s])
	if not w.is_walkable(ti):
		var land := w.nearest_walkable(int(u.x[s]), int(u.y[s]), 6)
		if land >= 0:
			u.task[s] = UnitStore.Task.SEEK_LAND
			sim.movement.go_to(s, land, false)
		return
	if _carnivore[u.species[s]] == 1:
		_predator_think(s)
		return
	# Flee from nearby hunters and prowling predators.
	for o in sim.spatial.query_radius(u, u.x[s], u.y[s], FLEE_RADIUS, -1, 8):
		if u.task[o] == UnitStore.Task.HUNT and (u.species[o] == sim.human_species or _carnivore[u.species[o]] == 1):
			var away := Vector2(u.x[s] - u.x[o], u.y[s] - u.y[o]).normalized() * 5.0
			var fx := clampi(int(u.x[s] + away.x), 0, w.width - 1)
			var fy := clampi(int(u.y[s] + away.y), 0, w.height - 1)
			if w.is_walkable_xy(fx, fy):
				u.task[s] = UnitStore.Task.WANDER
				sim.movement.go_to(s, w.idx(fx, fy), false)
				return
	if u.hunger[s] >= 35.0:
		var raw: Dictionary = (Defs.species[u.species[s]] as Defs.SpeciesDef).raw
		var need: int = int(raw.get("graze_amount", 20))
		if w.vegetation[ti] >= need and w.biome[ti] != Defs.farmland_index:
			_start_graze(s)
			return
		var best := TileSearch.sample_best(sim, ti, GRAZE_SEARCH_RADIUS, GRAZE_SAMPLES, TileSearch.Kind.GRAZE, need)
		if best >= 0:
			u.task[s] = UnitStore.Task.GRAZE
			sim.movement.go_to(s, best, false)
			return
		_wander(s, WANDER_RADIUS * 2)
		return
	_wander(s, WANDER_RADIUS)


## Wanders around the local herd centroid (herd cohesion keeps mates within reach).
func _wander(s: int, radius: int) -> void:
	var u := sim.units
	var w := sim.world
	var cx := u.x[s]
	var cy := u.y[s]
	# Predators keep to their pack over a much wider range than grazers keep to a herd.
	var pack := _carnivore[u.species[s]] == 1
	var herd := sim.spatial.query_radius(u, cx, cy, PACK_RADIUS if pack else HERD_RADIUS, u.species[s], 8)
	if herd.size() > 1:
		var sx := 0.0
		var sy := 0.0
		for o in herd:
			sx += u.x[o]
			sy += u.y[o]
		var k := PACK_COHESION if pack else HERD_COHESION
		cx = lerpf(cx, sx / herd.size(), k)
		cy = lerpf(cy, sy / herd.size(), k)
	var tx := clampi(int(cx) + sim.rng.randi_range(-radius, radius), 0, w.width - 1)
	var ty := clampi(int(cy) + sim.rng.randi_range(-radius, radius), 0, w.height - 1)
	var ti := w.idx(tx, ty)
	u.task[s] = UnitStore.Task.WANDER
	if w.is_walkable(ti):
		sim.movement.go_to(s, ti, false)
	u.next_think[s] = sim.tick + SimConst.THINK_INTERVAL + sim.rng.randi_range(0, 20)


func _start_graze(s: int) -> void:
	var u := sim.units
	u.state[s] = UnitStore.State.WORKING
	u.task[s] = UnitStore.Task.GRAZE
	u.task_timer[s] = GRAZE_TICKS


func _finish_graze(s: int) -> void:
	var u := sim.units
	var w := sim.world
	var raw: Dictionary = (Defs.species[u.species[s]] as Defs.SpeciesDef).raw
	var ti := int(u.y[s]) * w.width + int(u.x[s])
	var amount: int = int(raw.get("graze_amount", 20))
	var have := w.vegetation[ti]
	var eaten := mini(have, amount)
	if w.biome[ti] != Defs.farmland_index and eaten > 0:
		w.vegetation[ti] = have - eaten
		u.hunger[s] = maxf(0.0, u.hunger[s] - float(raw.get("graze_hunger", 30)) * float(eaten) / amount)
		if (have >> 6) != ((have - eaten) >> 6):
			w.mark_dirty(ti)
	u.state[s] = UnitStore.State.IDLE
	u.task[s] = UnitStore.Task.NONE
	u.next_think[s] = sim.tick + 2


## Monthly breeding pass. Density caps stop exponential blow-up; food limits do the rest.
## Breeding pass, run every tick over the 1/30 of animal slots whose turn it is,
## so each female is considered once a month without a monthly frame spike.
func reproduction_slice() -> void:
	if sim.tick % SimConst.TICKS_PER_MONTH == 0:
		_predator_migration()
	if not sim.laws.is_on("animal_reproduction"):
		return
	var u := sim.units
	var births: Array[Vector3i] = []  # (species, mother slot, count)
	var phase := sim.tick % SimConst.TICKS_PER_MONTH
	for s in range(phase, u.capacity, SimConst.TICKS_PER_MONTH):
		if u.alive[s] == 0 or u.species[s] == sim.human_species or u.sex[s] != UnitStore.SEX_FEMALE:
			continue
		var def: Defs.SpeciesDef = Defs.species[u.species[s]]
		var age := u.age_years(s, sim.tick)
		if age < def.fertile_min or age > def.fertile_max or u.hunger[s] > 60.0:
			continue
		if sim.tick - u.last_birth_tick[s] < int(def.birth_cooldown_years * SimConst.TICKS_PER_YEAR):
			continue
		if not sim.rng.chance(float(def.raw.get("birth_chance_per_month", 0.1)) * 2.0 * (1.5 if Traits.has(u.traits[s], Traits.FERTILE) else 1.0)):
			continue
		# Density pressure: crowding within CROWD_RADIUS and local grass both scale fertility,
		# so herds grow where forage is plentiful and level off where it is grazed down.
		var cap := float(def.raw.get("local_density_cap", 12))
		var near := sim.spatial.query_radius(u, u.x[s], u.y[s], maxf(CROWD_RADIUS, float(def.raw.get("mate_radius", 0))), u.species[s], int(cap) + 1)
		if near.size() >= cap:
			continue
		var has_mate := false
		for o in near:
			if u.sex[o] == UnitStore.SEX_MALE and u.age_years(o, sim.tick) >= def.adult_age and Vector2(u.x[o] - u.x[s], u.y[o] - u.y[s]).length() <= float(def.raw.get("mate_radius", MATE_RADIUS)):
				has_mate = true
				break
		var food := maxf(0.3, _prey_factor(s)) if _carnivore[u.species[s]] == 1 else _forage_factor(u.x[s], u.y[s])
		if has_mate and sim.rng.chance(food * (1.0 - near.size() / cap)):
			births.append(Vector3i(u.species[s], s, sim.rng.randi_range(def.litter_min, def.litter_max)))
	for b in births:
		var m := b.y
		if u.alive[m] == 0:
			continue
		u.last_birth_tick[m] = sim.tick
		for k in b.z:
			var c := sim.spawn_unit(b.x, u.x[m] + sim.rng.randf_range(-0.4, 0.4), u.y[m] + sim.rng.randf_range(-0.4, 0.4), 0.0, u.id[m])
			if c >= 0:
				sim.month_births += 1
				sim.total_births += 1


func _predator_think(s: int) -> void:
	var u := sim.units
	var raw: Dictionary = (Defs.species[u.species[s]] as Defs.SpeciesDef).raw
	var hunger := u.hunger[s]
	if hunger >= float(raw.get("hunt_hunger", 35)):
		var best := -1
		var best_d := INF
		for sp in _prey[u.species[s]]:
			# Starving predators range twice as far for food.
			var reach := float(raw.get("hunt_radius", 10)) * (2.0 if hunger >= 60.0 else 1.0)
			for o in sim.spatial.query_radius(u, u.x[s], u.y[s], reach, sp, 12):
				if u.has_flag(o, UnitStore.Flag.INVULNERABLE):
					continue
				var d := Vector2(u.x[o] - u.x[s], u.y[o] - u.y[s]).length_squared()
				if d < best_d:
					best_d = d
					best = o
		# A starving predator will go for a person standing alone.
		if best < 0 and hunger >= float(raw.get("desperate_hunger", 85)):
			for o in sim.spatial.query_radius(u, u.x[s], u.y[s], 6.0, sim.human_species, 6):
				if u.has_flag(o, UnitStore.Flag.INVULNERABLE):
					continue
				if sim.spatial.query_radius(u, u.x[o], u.y[o], LONE_RADIUS, sim.human_species, 3).size() <= 1:
					best = o
					best_d = Vector2(u.x[o] - u.x[s], u.y[o] - u.y[s]).length_squared()
					break
		if best >= 0:
			if best_d <= BITE_RANGE * BITE_RANGE:
				_bite(s, best, raw)
				return
			u.task[s] = UnitStore.Task.HUNT
			u.task_target[s] = best
			# Short hops toward the prey's current position, so the chase re-aims often.
			var dir := Vector2(u.x[best] - u.x[s], u.y[best] - u.y[s])
			var hop := Vector2(u.x[s], u.y[s]) + dir.limit_length(CHASE_HOP)
			var w := sim.world
			var ht := w.idx(clampi(int(hop.x), 0, w.width - 1), clampi(int(hop.y), 0, w.height - 1))
			if not w.is_walkable(ht):
				ht = u.tile_index(best, w.width)
			if sim.movement.go_to(s, ht, false) == MovementSystem.Plan.OK:
				u.next_think[s] = sim.tick + 4
				return
	if hunger >= float(raw.get("hunt_hunger", 35)):
		_roam(s)
	else:
		_wander(s, WANDER_RADIUS)


## A hungry predator with no prey in reach travels far, in a direction shared by its pack.
func _roam(s: int) -> void:
	var u := sim.units
	var w := sim.world
	var pack := sim.spatial.query_radius(u, u.x[s], u.y[s], PACK_RADIUS, u.species[s], 8)
	var anchor := pack[0] if pack.size() > 0 else s
	# The pack member with the lowest slot sets the heading, re-rolled every few months.
	for o in pack:
		anchor = mini(anchor, o)
	# Oversized packs split: every third wolf strikes out on its own heading.
	if pack.size() >= PACK_SPLIT and u.id[s] % 3 == 0:
		anchor = s
	var epoch := sim.tick / (SimConst.TICKS_PER_MONTH * 3)
	var h := (u.id[anchor] * 2654435761 + epoch * 40503) % 360
	var ang := deg_to_rad(float(h))
	for attempt in 4:
		var tx := clampi(int(u.x[s] + cos(ang) * ROAM_DISTANCE), 0, w.width - 1)
		var ty := clampi(int(u.y[s] + sin(ang) * ROAM_DISTANCE), 0, w.height - 1)
		var t := w.nearest_walkable(tx, ty, 3)
		if t >= 0 and sim.movement.go_to(s, t, false) == MovementSystem.Plan.OK:
			u.task[s] = UnitStore.Task.WANDER
			u.next_think[s] = sim.tick + SimConst.THINK_INTERVAL
			return
		ang += PI * 0.5
	_wander(s, WANDER_RADIUS * 2)


func _bite(s: int, prey: int, raw: Dictionary) -> void:
	var u := sim.units
	u.task[s] = UnitStore.Task.NONE
	u.state[s] = UnitStore.State.IDLE
	u.next_think[s] = sim.tick + 10
	if u.species[prey] == sim.human_species:
		u.health[prey] -= float((Defs.species[u.species[s]] as Defs.SpeciesDef).raw.get("damage", 7))
		sim.push_fx("hit", u.tile_index(prey, sim.world.width))
		# People fight back.
		u.health[s] -= HUMAN_DEFENSE_DAMAGE * (1.25 if Traits.has(u.traits[prey], Traits.STRONG) else 1.0)
		if u.health[prey] <= 0.0:
			sim.kill_unit(prey, "wolf attack")
			u.hunger[s] = maxf(0.0, u.hunger[s] - float(raw.get("meal_hunger", 70)))
		if u.health[s] <= 0.0:
			sim.kill_unit(s, "slain by people")
		return
	sim.kill_unit(prey, "eaten by wolves")
	u.hunger[s] = maxf(0.0, u.hunger[s] - float(raw.get("meal_hunger", 70)))


## 0..1 prey abundance near a predator: its litters depend on the hunting grounds.
func _prey_factor(s: int) -> float:
	var u := sim.units
	var raw: Dictionary = (Defs.species[u.species[s]] as Defs.SpeciesDef).raw
	var n := 0
	for sp in _prey[u.species[s]]:
		n += sim.spatial.query_radius(u, u.x[s], u.y[s], float(raw.get("hunt_radius", 10)) * 1.5, sp, 32).size()
	return clampf(float(n) / float(raw.get("prey_per_birth", 8)), 0.0, 1.0)


## 0..1 share of grazing biomass on a few tiles around (x, y).
func _forage_factor(x: float, y: float) -> float:
	var w := sim.world
	var total := 0.0
	var n := 0
	for d: Vector2i in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		var tx := int(x) + d.x
		var ty := int(y) + d.y
		if w.in_bounds(tx, ty):
			total += w.vegetation[w.idx(tx, ty)] / 255.0
			n += 1
	return total / maxf(1.0, n)


## If a predator species has (almost) vanished, a pair occasionally wanders in from
## beyond the map edge, so ecosystems recover from local extinction.
func _predator_migration() -> void:
	if sim.tick % (SimConst.TICKS_PER_YEAR * MIGRATION_YEARS) != 0:
		return
	# Large worlds need more than one surviving pair to count as "still present".
	var floor_count := maxi(2, sim.world.size / 20000 * 2)
	for sp: Defs.SpeciesDef in Defs.species:
		if _carnivore[sp.index] == 0 or sim.count_species(sp.index) >= floor_count:
			continue
		var prey := 0
		for p in _prey[sp.index]:
			prey += sim.count_species(p)
		if prey < 30 or not sim.rng.chance(0.6):
			continue
		var w := sim.world
		for attempt in 60:
			var i := sim.rng.randi_range(0, w.size - 1)
			if w.biome[i] != Defs.forest_index or w.owner[i] != SimConst.CITY_NONE:
				continue
			for k in 2:
				var ws := sim.spawn_unit(sp.index, float(i % w.width) + 0.5 + k * 0.5, float(i / w.width) + 0.5, 2.0)
				if ws >= 0:
					sim.units.sex[ws] = k
			sim.history.record(sim.tick, HistoryLog.Kind.MIGRATION, "A pair of %s wandered in from the wilds." % sp.name.to_lower(), {}, i)
			break
