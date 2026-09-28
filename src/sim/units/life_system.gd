class_name LifeSystem
extends RefCounted
## Batched biological upkeep for every creature: hunger, starvation, hazards,
## regeneration and old age, in one tight pass over the unit arrays with law and
## table lookups hoisted out of the loop. Deaths are applied after the pass in
## slot order so the result is deterministic and independent of AI ordering.

var sim: Simulation
var _hunger_rate := PackedFloat32Array()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_hunger_rate.resize(Defs.species.size())
	for sp: Defs.SpeciesDef in Defs.species:
		_hunger_rate[sp.index] = sp.hunger_rate


func update_all() -> void:
	var u := sim.units
	var w := sim.world
	# Packed arrays are shared by reference, so these locals write through.
	var alive := u.alive
	var hunger := u.hunger
	var health := u.health
	var max_health := u.max_health
	var flags := u.flags
	var species := u.species
	var xs := u.x
	var ys := u.y
	var pxs := u.prev_x
	var pys := u.prev_y
	var birth := u.birth_tick
	var death_age := u.death_age
	var state := u.state
	var task := u.task
	var next_think := u.next_think
	var biome := w.biome
	var walk := Defs.biome_walkable
	var water := Defs.biome_water
	var rates := _hunger_rate
	var width := w.width
	var tick := sim.tick
	var hunger_on := sim.laws.is_on("hunger")
	var aging_on := sim.laws.is_on("natural_death")
	var invuln_bit: int = UnitStore.Flag.INVULNERABLE
	var seek: int = UnitStore.Task.SEEK_LAND
	var idle: int = UnitStore.State.IDLE
	var disease := u.disease
	var traits := u.traits
	var hardy_bit := 1 << Traits.HARDY
	var lava_b := Defs.biome_index("lava")
	var dead_slots := PackedInt32Array()
	var dead_causes := PackedStringArray()
	for s in u.capacity:
		if alive[s] == 0:
			continue
		pxs[s] = xs[s]
		pys[s] = ys[s]
		var invulnerable := (flags[s] & invuln_bit) != 0
		var h := hunger[s]
		if hunger_on:
			h += rates[species[s]] * (0.75 if (traits[s] & hardy_bit) != 0 else 1.0)
			if h >= SimConst.HUNGER_MAX:
				h = SimConst.HUNGER_MAX
				if not invulnerable:
					health[s] -= SimConst.STARVE_DAMAGE
			hunger[s] = h
		if h < SimConst.HUNGER_EAT_THRESHOLD and health[s] < max_health[s] and disease[s] == 0:
			health[s] = minf(max_health[s], health[s] + SimConst.REGEN_PER_TICK)
		var ti := int(ys[s]) * width + int(xs[s])
		var b := biome[ti]
		if walk[b] == 0 and not invulnerable:
			health[s] -= SimConst.HAZARD_DAMAGE if b != lava_b else DisasterSystem.LAVA_DAMAGE
			if task[s] != seek:
				next_think[s] = tick
				state[s] = idle
		if health[s] <= 0.0:
			dead_slots.append(s)
			dead_causes.append("starvation" if h >= SimConst.HUNGER_MAX else ("drowning" if water[b] == 1 else ("lava" if b == lava_b else "injury")))
		elif aging_on and not invulnerable and tick - birth[s] >= death_age[s]:
			dead_slots.append(s)
			dead_causes.append("old age")
	for k in dead_slots.size():
		sim.kill_unit(dead_slots[k], dead_causes[k])
