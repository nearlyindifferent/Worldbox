class_name MovementSystem
extends RefCounted
## Moves units along cached tile paths. Sapients use A* (Pathfinder); animals use
## cheap direct steering that aborts when the next tile is not walkable.

enum Result { MOVING, ARRIVED, BLOCKED }
enum Plan { OK, PENDING, UNREACHABLE }

const DIRECT_RANGE := 3.0  ## straight-line moves shorter than this skip A*

var sim: Simulation
var _speed := PackedFloat32Array()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	_speed.resize(Defs.species.size())
	for sp: Defs.SpeciesDef in Defs.species:
		_speed[sp.index] = sp.speed


## Plans a route to tile `to_i`. `use_astar` false = direct steering.
func go_to(s: int, to_i: int, use_astar: bool) -> int:
	var u := sim.units
	var w := sim.world.width
	var from_i := int(u.y[s]) * w + int(u.x[s])
	if from_i == to_i:
		u.path[s] = PackedInt32Array([to_i])
		u.path_pos[s] = 0
		u.state[s] = UnitStore.State.MOVING
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
	return Plan.OK


func advance(s: int) -> int:
	var u := sim.units
	var p: PackedInt32Array = u.path.get(s, PackedInt32Array())
	var k := u.path_pos[s]
	if k >= p.size():
		u.path.erase(s)
		return Result.ARRIVED
	var w := sim.world.width
	var target := p[k]
	var tx := float(target % w) + 0.5
	var ty := float(target / w) + 0.5
	var cur_i := int(u.y[s]) * w + int(u.x[s])
	var cost: float = Defs.biome_move_cost[sim.world.biome[cur_i]]
	var spd := _speed[u.species[s]] / (cost if cost > 0.0 else 1.0)
	var dx := tx - u.x[s]
	var dy := ty - u.y[s]
	var d := sqrt(dx * dx + dy * dy)
	if d <= spd:
		u.x[s] = tx
		u.y[s] = ty
		k += 1
		u.path_pos[s] = k
		if k >= p.size():
			u.path.erase(s)
			return Result.ARRIVED
		return Result.MOVING
	var nx := u.x[s] + dx / d * spd
	var ny := u.y[s] + dy / d * spd
	var ni := int(ny) * w + int(nx)
	if ni != cur_i and not sim.world.is_walkable(ni) and sim.world.is_walkable(cur_i):
		u.path.erase(s)
		return Result.BLOCKED
	u.x[s] = nx
	u.y[s] = ny
	return Result.MOVING


func stop(s: int) -> void:
	sim.units.path.erase(s)
	sim.units.state[s] = UnitStore.State.IDLE
