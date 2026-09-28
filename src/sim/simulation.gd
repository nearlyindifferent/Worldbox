class_name Simulation
extends RefCounted
## Root of the simulation layer. Owns every piece of authoritative state and
## advances it in fixed ticks. Contains no rendering or UI code and never reads
## frame time, so the same seed + command stream reproduces the same world.

const SAVE_SCHEMA := 2

var seed_value: int = 0
var shape: String = "island"
var tick: int = 0

var world: WorldGrid
var units := UnitStore.new()
var cities: Dictionary = {}     ## id -> City (insertion order = founding order)
var buildings: Dictionary = {}  ## id -> Building
var next_city_id: int = 1
var next_building_id: int = 1
var rng: SimRng
var laws := WorldLaws.new()
var history := HistoryLog.new()
var decisions := DecisionLog.new()
var stats: Dictionary = {}      ## name -> StatSeries
var month_births: int = 0
var month_deaths: int = 0
var deaths_by_cause: Dictionary = {}
var total_births: int = 0
var total_deaths: int = 0
var deceased: Dictionary = {}   ## id -> summary, bounded (genealogy of the dead)
const DECEASED_CAP := 20000
var command_log: Array[Dictionary] = []
const COMMAND_LOG_CAP := 2000
var pop_milestone: int = 0

## Derived / transient (rebuilt, not saved)
var spatial := SpatialIndex.new()
var pathfinder := Pathfinder.new()
var life: LifeSystem
var movement: MovementSystem
var human_ai: HumanAI
var animal_ai: AnimalAI
var civ: CivSystem
var vegetation: VegetationSystem
var editor: TerrainEditor
var timings: Dictionary = {}    ## system -> smoothed microseconds per tick
var last_tick_usec: int = 0
var human_species: int = 0
var sheep_species: int = 1


static func create_new(p_seed: int, w: int, h: int, p_shape: String = "island", populate: bool = true) -> Simulation:
	Defs.ensure_loaded()
	var sim := Simulation.new()
	sim.seed_value = p_seed
	sim.shape = p_shape
	sim.rng = SimRng.new(p_seed)
	sim.world = WorldGen.generate(p_seed, w, h, p_shape)
	sim._init_systems()
	sim.pathfinder.rebuild_components()
	sim.history.record(0, HistoryLog.Kind.WORLD, "The world was shaped (seed %d, %dx%d %s)." % [p_seed, w, h, p_shape])
	if populate:
		sim.populate_default()
	return sim


func _init_systems() -> void:
	human_species = Defs.species_by_id("human").index
	sheep_species = Defs.species_by_id("sheep").index
	spatial.setup(world.width, world.height)
	world.drain_walk_changes()
	pathfinder.setup(world)
	life = LifeSystem.new(self)
	movement = MovementSystem.new(self)
	human_ai = HumanAI.new(self)
	animal_ai = AnimalAI.new(self)
	civ = CivSystem.new(self)
	vegetation = VegetationSystem.new(self)
	editor = TerrainEditor.new(self)
	for n in ["population", "humans", "animals", "cities", "food", "births", "deaths"]:
		if not stats.has(n):
			stats[n] = StatSeries.new()
	spatial.rebuild(units)


## Scatters nomadic human bands and animal herds on good land.
func populate_default() -> void:
	var bands := clampi(world.size / 6000, 3, 12)
	for b in bands:
		var t := _random_land_tile(0.6)
		if t < 0:
			break
		for k in 6:
			var s := spawn_unit(human_species, float(t % world.width) + rng.randf_range(-2, 2) + 0.5, float(t / world.width) + rng.randf_range(-2, 2) + 0.5, rng.randf_range(16, 30))
			if s >= 0:
				units.sex[s] = k % 2
	var herds := clampi(world.size / 2500, 6, 60)
	for hh in herds:
		var t := _random_land_tile(0.5)
		if t < 0:
			break
		for k in rng.randi_range(3, 6):
			spawn_unit(sheep_species, float(t % world.width) + rng.randf_range(-2, 2) + 0.5, float(t / world.width) + rng.randf_range(-2, 2) + 0.5, rng.randf_range(1, 5))
	spatial.rebuild(units)


func _random_land_tile(min_fertility: float) -> int:
	for attempt in 400:
		var i := rng.randi_range(0, world.size - 1)
		if world.is_walkable(i) and world.fertility(i) >= min_fertility:
			return i
	for attempt in 400:
		var i := rng.randi_range(0, world.size - 1)
		if world.is_walkable(i):
			return i
	return -1


# ---------------------------------------------------------------- tick

func step() -> void:
	var t0 := Time.get_ticks_usec()
	tick += 1
	pathfinder.begin_tick(tick)
	pathfinder.sync_changes()

	var t := Time.get_ticks_usec()
	spatial.rebuild(units)
	_time("spatial", t)

	t = Time.get_ticks_usec()
	vegetation.update()
	_time("vegetation", t)

	t = Time.get_ticks_usec()
	life.update_all()
	_time("life", t)

	t = Time.get_ticks_usec()
	var alive := units.alive
	var flags := units.flags
	var species := units.species
	var frozen_bit: int = UnitStore.Flag.FROZEN
	var hs := human_species
	for s in units.capacity:
		if alive[s] == 0 or (flags[s] & frozen_bit) != 0:
			continue
		if species[s] == hs:
			human_ai.update(s)
		else:
			animal_ai.update(s)
	_time("units", t)

	t = Time.get_ticks_usec()
	civ.update()
	_time("civ", t)

	if tick % SimConst.TICKS_PER_MONTH == 0:
		t = Time.get_ticks_usec()
		animal_ai.monthly_reproduction()
		_sample_stats()
		_time("monthly", t)
	last_tick_usec = Time.get_ticks_usec() - t0
	_smooth("tick_total", last_tick_usec)


func _time(key: String, since: int) -> void:
	_smooth(key, Time.get_ticks_usec() - since)


func _smooth(key: String, v: int) -> void:
	timings[key] = lerpf(float(timings.get(key, v)), float(v), 0.05)


func _sample_stats() -> void:
	var humans := 0
	var animals := 0
	for s in units.capacity:
		if units.alive[s] == 1:
			if units.species[s] == human_species:
				humans += 1
			else:
				animals += 1
	var food := 0.0
	for c: City in cities.values():
		food += float(c.storage["food"])
	(stats["population"] as StatSeries).push(humans + animals)
	(stats["humans"] as StatSeries).push(humans)
	(stats["animals"] as StatSeries).push(animals)
	(stats["cities"] as StatSeries).push(cities.size())
	(stats["food"] as StatSeries).push(food)
	(stats["births"] as StatSeries).push(month_births)
	(stats["deaths"] as StatSeries).push(month_deaths)
	month_births = 0
	month_deaths = 0
	var milestone := 50
	while milestone <= humans:
		milestone *= 2
	@warning_ignore("integer_division")
	milestone /= 2
	if milestone >= 50 and milestone > pop_milestone:
		pop_milestone = milestone
		history.record(tick, HistoryLog.Kind.POP_MILESTONE, "The world's people now number over %d." % milestone)


# ---------------------------------------------------------------- calendar

func year() -> int:
	@warning_ignore("integer_division")
	return tick / SimConst.TICKS_PER_YEAR + 1


func month() -> int:
	@warning_ignore("integer_division")
	return (tick % SimConst.TICKS_PER_YEAR) / SimConst.TICKS_PER_MONTH + 1


func date_string(at_tick: int = -1) -> String:
	var tk := tick if at_tick < 0 else at_tick
	@warning_ignore("integer_division")
	return "Year %d, Month %d" % [tk / SimConst.TICKS_PER_YEAR + 1, (tk % SimConst.TICKS_PER_YEAR) / SimConst.TICKS_PER_MONTH + 1]


# ---------------------------------------------------------------- units

func spawn_unit(species_idx: int, px: float, py: float, age_years: float = 20.0, mother_id: int = SimConst.UNIT_NONE, father_id: int = SimConst.UNIT_NONE) -> int:
	var tx := int(px)
	var ty := int(py)
	if not world.in_bounds(tx, ty):
		return -1
	if not world.is_walkable_xy(tx, ty):
		var near := world.nearest_walkable(tx, ty, 4)
		if near < 0:
			return -1
		px = float(near % world.width) + 0.5
		py = float(near / world.width) + 0.5
	var def: Defs.SpeciesDef = Defs.species[species_idx]
	var s := units.allocate()
	units.species[s] = species_idx
	units.sex[s] = rng.randi_range(0, 1)
	units.x[s] = px
	units.y[s] = py
	units.prev_x[s] = px
	units.prev_y[s] = py
	units.birth_tick[s] = tick - int(age_years * SimConst.TICKS_PER_YEAR)
	units.death_age[s] = int(rng.randf_range(def.lifespan_min, def.lifespan_max) * SimConst.TICKS_PER_YEAR)
	units.max_health[s] = def.max_health
	units.health[s] = def.max_health
	units.hunger[s] = rng.randf_range(0.0, 30.0)
	units.mother[s] = mother_id
	units.father[s] = father_id
	units.next_think[s] = tick + 1 + (s % SimConst.THINK_INTERVAL)
	units.look[s] = _inherit_look(species_idx, mother_id, father_id)
	units.name[s] = NameGen.person_name(def, rng) if def.sapient else def.name.trim_suffix("s")
	if def.sapient:
		units.add_child_link(mother_id, units.id[s])
		units.add_child_link(father_id, units.id[s])
	return s


## Cosmetic heredity: each gene slot (4 bits) comes from a random parent with a small mutation chance.
func _inherit_look(species_idx: int, mother_id: int, father_id: int) -> int:
	var ms := units.slot_for(mother_id)
	var fs := units.slot_for(father_id)
	var out := 0
	for g in 4:
		var v := rng.randi_range(0, 15)
		var src := -1
		if ms >= 0 and fs >= 0:
			src = ms if rng.chance(0.5) else fs
		elif ms >= 0:
			src = ms
		elif fs >= 0:
			src = fs
		if src >= 0 and not rng.chance(0.05):
			v = (units.look[src] >> (g * 4)) & 15
		out |= v << (g * 4)
	return out


func kill_unit(s: int, cause: String) -> void:
	if units.alive[s] == 0:
		return
	var uid := units.id[s]
	var c := units.city[s]
	if c != SimConst.CITY_NONE and cities.has(c):
		var city: City = cities[c]
		city.remove_member(uid)
		city.deaths += 1
		if city.leader_id == uid:
			history.record(tick, HistoryLog.Kind.LEADER_DIED, "%s, leader of %s, died (%s)." % [units.name[s], city.name, cause], {"city": c, "unit": uid}, units.tile_index(s, world.width))
			city.leader_id = SimConst.UNIT_NONE
	if units.species[s] == human_species:
		deceased[uid] = {"name": units.name[s], "species": units.species[s], "born": units.birth_tick[s], "died": tick,
			"cause": cause, "mother": units.mother[s], "father": units.father[s], "city": c, "sex": units.sex[s]}
		if deceased.size() > DECEASED_CAP:
			var evicted: int = deceased.keys()[0]
			deceased.erase(evicted)
			units.children.erase(evicted)
	month_deaths += 1
	total_deaths += 1
	var key := "%s: %s" % [(Defs.species[units.species[s]] as Defs.SpeciesDef).id, cause]
	deaths_by_cause[key] = int(deaths_by_cause.get(key, 0)) + 1
	units.free_slot(s)


# ---------------------------------------------------------------- god / admin commands

## Applies a player/admin command at the tick boundary and logs it for replay/debugging.
func apply_command(cmd: Dictionary) -> Dictionary:
	command_log.append({"tick": tick, "cmd": cmd.duplicate(true)})
	if command_log.size() > COMMAND_LOG_CAP:
		command_log.remove_at(0)
	return GodCommands.execute(self, cmd)


# ---------------------------------------------------------------- queries

func unit_at(px: float, py: float, radius: float = 1.2) -> int:
	var best := -1
	var best_d := radius * radius
	for s in spatial.query_radius(units, px, py, radius):
		var d := Vector2(units.x[s] - px, units.y[s] - py).length_squared()
		if d < best_d:
			best_d = d
			best = s
	return best


func city_at_tile(i: int) -> City:
	var c := world.owner[i]
	return cities.get(c, null)


## Total deaths whose cause matches `cause`, optionally for one species id ("human").
func count_deaths(cause: String, species_id: String = "") -> int:
	var n := 0
	for k: String in deaths_by_cause:
		if k.ends_with(": " + cause) and (species_id == "" or k.begins_with(species_id + ":")):
			n += int(deaths_by_cause[k])
	return n


func count_species(sp: int) -> int:
	var n := 0
	for s in units.capacity:
		if units.alive[s] == 1 and units.species[s] == sp:
			n += 1
	return n


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	var w := world
	var city_list: Array = []
	for c: City in cities.values():
		city_list.append(c.to_dict())
	var bld_list: Array = []
	for b: Building in buildings.values():
		bld_list.append(b.to_dict())
	var stat_d := {}
	for k: String in stats:
		stat_d[k] = (stats[k] as StatSeries).to_dict()
	return {
		"schema": SAVE_SCHEMA,
		"seed": seed_value, "shape": shape, "tick": tick, "rng_state": rng.get_state(),
		"world": {"w": w.width, "h": w.height, "elevation": w.elevation, "biome": w.biome, "moisture": w.moisture,
			"temperature": w.temperature, "vegetation": w.vegetation, "wood": w.wood, "owner": w.owner,
			"building": w.building, "variant": w.variant},
		"units": units.to_dict(),
		"cities": city_list, "buildings": bld_list,
		"next_city_id": next_city_id, "next_building_id": next_building_id,
		"laws": laws.to_dict(), "history": history.to_dict(), "decisions": decisions.to_dict(),
		"stats": stat_d, "month_births": month_births, "month_deaths": month_deaths,
		"deaths_by_cause": deaths_by_cause.duplicate(), "total_births": total_births, "total_deaths": total_deaths,
		"deceased": deceased.duplicate(true), "pop_milestone": pop_milestone,
		"civ_state": civ.to_dict(),
		"components": pathfinder.components_to_dict(),
		"undo": editor.undo_stack.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Simulation:
	Defs.ensure_loaded()
	var sim := Simulation.new()
	sim.seed_value = int(d["seed"])
	sim.shape = d["shape"]
	sim.tick = int(d["tick"])
	sim.rng = SimRng.new(sim.seed_value)
	sim.rng.set_state(int(d["rng_state"]))
	var wd: Dictionary = d["world"]
	var w := WorldGrid.new(int(wd["w"]), int(wd["h"]))
	for f in ["elevation", "biome", "moisture", "temperature", "vegetation", "wood", "owner", "building", "variant"]:
		w.set(f, wd[f])
	sim.world = w
	sim.units.from_dict(d["units"])
	for cd: Dictionary in d["cities"]:
		var c := City.from_dict(cd)
		sim.cities[c.id] = c
	for bd: Dictionary in d["buildings"]:
		var b := Building.from_dict(bd)
		sim.buildings[b.id] = b
	sim.next_city_id = int(d["next_city_id"])
	sim.next_building_id = int(d["next_building_id"])
	sim.laws.from_dict(d["laws"])
	sim.history.from_dict(d["history"])
	sim.decisions.from_dict(d["decisions"])
	for k: String in d["stats"]:
		var ss := StatSeries.new()
		ss.from_dict(d["stats"][k])
		sim.stats[k] = ss
	sim.month_births = int(d["month_births"])
	sim.month_deaths = int(d["month_deaths"])
	sim.deaths_by_cause = d["deaths_by_cause"]
	sim.total_births = int(d["total_births"])
	sim.total_deaths = int(d["total_deaths"])
	sim.deceased = d["deceased"]
	sim.pop_milestone = int(d["pop_milestone"])
	sim._init_systems()
	sim.civ.from_dict(d["civ_state"])
	sim.pathfinder.components_from_dict(d["components"])
	sim.editor.undo_stack.assign(d["undo"])
	return sim


## Builds a Simulation from an untrusted (already migrated) save dictionary.
## Returns {"ok", "sim"|"msg"}; the world must pass structural validation and all
## invariants, otherwise nothing is returned.
static func from_save(d: Dictionary) -> Dictionary:
	var err := SaveValidator.validate(d)
	if err != "":
		return {"ok": false, "msg": "Save rejected: %s" % err}
	var sim := Simulation.from_dict(d)
	if sim == null:
		return {"ok": false, "msg": "Save rejected: could not rebuild world"}
	var errs := SimInvariants.check(sim, 5)
	if errs.size() > 0:
		return {"ok": false, "msg": "Save rejected: inconsistent world (%s)" % errs[0]}
	return {"ok": true, "sim": sim}


## Independent deep copy. to_dict() shares packed arrays with this simulation, so
## an in-memory clone must go through serialization (exactly like a save file).
func clone() -> Simulation:
	return Simulation.from_dict(bytes_to_var(var_to_bytes(to_dict())))


## Content hash of all authoritative state. Equal hashes ⇒ equal worlds.
func state_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(to_dict()))
	return ctx.finish().hex_encode()
