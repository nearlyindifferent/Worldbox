class_name MovementSystem
extends RefCounted
## Moves units along cached tile paths. Sapients use A* (Pathfinder); animals use
## cheap direct steering that aborts when the next tile is not walkable.

enum Plan { OK, PENDING, UNREACHABLE }

const DIRECT_RANGE := 3.0  ## straight-line moves shorter than this skip A*

var sim: Simulation
var _speed := PackedFloat32Array()
## Per-slot result of this tick's movement pass: 0 none, ARRIVED+1, BLOCKED+1.
var events := PackedByteArray()
## Derived cache of each mover's current waypoint tile (-1 = fetch from the path
## dictionary). Avoids a dictionary lookup per unit per tick. Not saved.
var _wp := PackedInt32Array()
const EV_NONE := 0
const EV_ARRIVED := 1
const EV_BLOCKED := 2


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_speed.resize(Defs.species.size())
	for sp: Defs.SpeciesDef in Defs.species:
		_speed[sp.index] = sp.speed


## Plans a route to tile `to_i`. `use_astar` false = direct steering.
func go_to(s: int, to_i: int, use_astar: bool) -> int:
	var u := sim.units
	var w := sim.world.width
	if to_i < 0 or to_i >= sim.world.size:
		return Plan.UNREACHABLE
	var from_i := int(u.y[s]) * w + int(u.x[s])
	if from_i == to_i:
		u.path[s] = PackedInt32Array([to_i])
		u.path_pos[s] = 0
		u.state[s] = UnitStore.State.MOVING
		_set_wp(s, to_i)
		return Plan.OK
	var dx := float(to_i % w) - float(from_i % w)
	var dy := float(to_i / w) - float(from_i / w)
	if not use_astar or (dx * dx + dy * dy) <= DIRECT_RANGE * DIRECT_RANGE:
		if not sim.world.is_walkable(to_i):
			return Plan.UNREACHABLE
		u.path[s] = PackedInt32Array([to_i])
	else:
		var p: Variant = sim.pathfinder.find_path(from_i, to_i)
		if p == null:
			return Plan.PENDING
		if (p as PackedInt32Array).is_empty():
			return Plan.UNREACHABLE
		u.path[s] = p
	u.path_pos[s] = 0
	u.state[s] = UnitStore.State.MOVING
	_set_wp(s, (u.path[s] as PackedInt32Array)[0])
	return Plan.OK


## Drops the derived waypoint cache (slots were renumbered); it is re-derived from paths.
func reset_waypoints() -> void:
	_wp.resize(sim.units.capacity)
	_wp.fill(-1)


func _set_wp(s: int, v: int) -> void:
	if _wp.size() != sim.units.capacity:
		_wp.resize(sim.units.capacity)
		_wp.fill(-1)
	_wp[s] = v


## Moves every non-frozen MOVING unit one tick in a single tight loop and records
## arrivals/blocks in `events` for the AI dispatch pass.
func advance_all() -> void:
	var u := sim.units
	var cap := u.capacity
	if events.size() != cap:
		events.resize(cap)
	events.fill(EV_NONE)
	if _wp.size() != cap:
		_wp.resize(cap)
		_wp.fill(-1)
	var alive := u.alive
	var state := u.state
	var flags := u.flags
	var species := u.species
	var xs := u.x
	var ys := u.y
	var path_pos := u.path_pos
	var paths := u.path
	var wp := _wp
	var ev := events
	var biome := sim.world.biome
	var walk := Defs.biome_walkable
	var cost_tab := Defs.biome_move_cost
	var speed := _speed
	var w := sim.world.width
	var moving: int = UnitStore.State.MOVING
	var idle: int = UnitStore.State.IDLE
	var frozen_bit: int = UnitStore.Flag.FROZEN
	var traits := u.traits
	var swift_bit := 1 << Traits.SWIFT
	for s in cap:
		if alive[s] == 0 or state[s] != moving or (flags[s] & frozen_bit) != 0:
			continue
		var target := wp[s]
		if target < 0:
			var p0: PackedInt32Array = paths.get(s, PackedInt32Array())
			var k0 := path_pos[s]
			if k0 >= p0.size():
				paths.erase(s)
				state[s] = idle
				ev[s] = EV_ARRIVED
				continue
			target = p0[k0]
			wp[s] = target
		var tx := float(target % w) + 0.5
		var ty := float(target / w) + 0.5
		var x := xs[s]
		var y := ys[s]
		var cur_i := int(y) * w + int(x)
		var cost := cost_tab[biome[cur_i]]
		var spd := speed[species[s]] / (cost if cost > 0.0 else 1.0)
		if (traits[s] & swift_bit) != 0:
			spd *= 1.2
		var dx := tx - x
		var dy := ty - y
		var d := sqrt(dx * dx + dy * dy)
		if d <= spd:
			xs[s] = tx
			ys[s] = ty
			var k := path_pos[s] + 1
			path_pos[s] = k
			var p: PackedInt32Array = paths.get(s, PackedInt32Array())
			if k >= p.size():
				paths.erase(s)
				wp[s] = -1
				state[s] = idle
				ev[s] = EV_ARRIVED
			else:
				wp[s] = p[k]
			continue
		var nx := x + dx / d * spd
		var ny := y + dy / d * spd
		var ni := int(ny) * w + int(nx)
		if ni != cur_i and walk[biome[ni]] == 0 and walk[biome[cur_i]] == 1:
			paths.erase(s)
			wp[s] = -1
			state[s] = idle
			ev[s] = EV_BLOCKED
			continue
		xs[s] = nx
		ys[s] = ny


func stop(s: int) -> void:
	sim.units.path.erase(s)
	_set_wp(s, -1)
	sim.units.state[s] = UnitStore.State.IDLE
