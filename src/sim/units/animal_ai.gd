class_name AnimalAI
extends RefCounted
## Behaviour for non-sapient grazers. Decisions are cheap and local: animals only
## sample a handful of nearby tiles and steer directly (no A*).

const GRAZE_TICKS := 12
const GRAZE_SEARCH_RADIUS := 7
const GRAZE_SAMPLES := 10
const WANDER_RADIUS := 6
const FLEE_RADIUS := 4.0
const MATE_RADIUS := 6.0
const HERD_RADIUS := 10.0
const CROWD_RADIUS := 5.0
const HERD_COHESION := 0.4

var sim: Simulation


func _init(p_sim: Simulation) -> void:
	sim = p_sim


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
	# Flee from nearby hunters: a crude but observable prey response.
	for o in sim.spatial.query_radius(u, u.x[s], u.y[s], FLEE_RADIUS, sim.human_species, 4):
		if u.task[o] == UnitStore.Task.HUNT:
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
	var herd := sim.spatial.query_radius(u, cx, cy, HERD_RADIUS, u.species[s], 8)
	if herd.size() > 1:
		var sx := 0.0
		var sy := 0.0
		for o in herd:
			sx += u.x[o]
			sy += u.y[o]
		cx = lerpf(cx, sx / herd.size(), HERD_COHESION)
		cy = lerpf(cy, sy / herd.size(), HERD_COHESION)
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
func monthly_reproduction() -> void:
	if not sim.laws.is_on("animal_reproduction"):
		return
	var u := sim.units
	var births: Array[Vector3i] = []  # (species, mother slot, count)
	for s in u.capacity:
		if u.alive[s] == 0 or u.species[s] == sim.human_species or u.sex[s] != UnitStore.SEX_FEMALE:
			continue
		var def: Defs.SpeciesDef = Defs.species[u.species[s]]
		var age := u.age_years(s, sim.tick)
		if age < def.fertile_min or age > def.fertile_max or u.hunger[s] > 60.0:
			continue
		if sim.tick - u.last_birth_tick[s] < int(def.birth_cooldown_years * SimConst.TICKS_PER_YEAR):
			continue
		if not sim.rng.chance(float(def.raw.get("birth_chance_per_month", 0.1)) * 2.0):
			continue
		# Density pressure: crowding within CROWD_RADIUS and local grass both scale fertility,
		# so herds grow where forage is plentiful and level off where it is grazed down.
		var near := sim.spatial.query_radius(u, u.x[s], u.y[s], CROWD_RADIUS, u.species[s])
		var cap := float(def.raw.get("local_density_cap", 12))
		if near.size() >= cap:
			continue
		var has_mate := false
		for o in near:
			if u.sex[o] == UnitStore.SEX_MALE and u.age_years(o, sim.tick) >= def.adult_age and Vector2(u.x[o] - u.x[s], u.y[o] - u.y[s]).length() <= MATE_RADIUS:
				has_mate = true
				break
		if has_mate and sim.rng.chance(_forage_factor(u.x[s], u.y[s]) * (1.0 - near.size() / cap)):
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
