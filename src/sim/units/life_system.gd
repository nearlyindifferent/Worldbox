class_name LifeSystem
extends RefCounted
## Per-tick biological upkeep: hunger, starvation, hazards, regeneration, old age.

var sim: Simulation
var _hunger_rate := PackedFloat32Array()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_hunger_rate.resize(Defs.species.size())
	for sp: Defs.SpeciesDef in Defs.species:
		_hunger_rate[sp.index] = sp.hunger_rate


## Returns false if the unit died this tick.
func update(s: int) -> bool:
	var u := sim.units
	var laws := sim.laws
	var invulnerable := u.has_flag(s, UnitStore.Flag.INVULNERABLE)
	if laws.is_on("hunger"):
		var h := u.hunger[s] + _hunger_rate[u.species[s]]
		if h >= SimConst.HUNGER_MAX:
			h = SimConst.HUNGER_MAX
			if not invulnerable:
				u.health[s] -= SimConst.STARVE_DAMAGE
		u.hunger[s] = h
	if u.hunger[s] < SimConst.HUNGER_EAT_THRESHOLD and u.health[s] < u.max_health[s]:
		u.health[s] = minf(u.max_health[s], u.health[s] + SimConst.REGEN_PER_TICK)
	var ti := int(u.y[s]) * sim.world.width + int(u.x[s])
	if not sim.world.is_walkable(ti) and not invulnerable:
		u.health[s] -= SimConst.HAZARD_DAMAGE
		if u.task[s] != UnitStore.Task.SEEK_LAND:
			u.next_think[s] = sim.tick
			u.state[s] = UnitStore.State.IDLE
	if u.health[s] <= 0.0:
		var cause := "starvation" if u.hunger[s] >= SimConst.HUNGER_MAX else ("drowning" if sim.world.is_water(ti) else "injury")
		sim.kill_unit(s, cause)
		return false
	if laws.is_on("natural_death") and not invulnerable and sim.tick - u.birth_tick[s] >= u.death_age[s]:
		sim.kill_unit(s, "old age")
		return false
	return true
