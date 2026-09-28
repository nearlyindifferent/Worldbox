class_name Pathfinder
extends RefCounted
## Land pathfinding on the engine-native AStarGrid2D (C++), which keeps GDScript
## out of the inner search loop. Grid solidity mirrors tile walkability and is
## updated incrementally from WorldGrid.walk_changed. A per-tick request budget
## bounds worst-case tick time; callers retry next tick when refused.

var _astar := AStarGrid2D.new()
var _world: WorldGrid
var budget_left: int = 0
var requests_total: int = 0
var refused_total: int = 0


func setup(world: WorldGrid) -> void:
	_world = world
	_astar.region = Rect2i(0, 0, world.width, world.height)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.jumping_enabled = false
	_astar.update()
	for i in world.size:
		_apply_tile(i)
	begin_tick()


func _apply_tile(i: int) -> void:
	var p := Vector2i(i % _world.width, i / _world.width)
	var walk := _world.is_walkable(i)
	_astar.set_point_solid(p, not walk)
	if walk:
		_astar.set_point_weight_scale(p, Defs.biome_move_cost[_world.biome[i]])


func sync_changes() -> void:
	for i in _world.drain_walk_changes():
		_apply_tile(i)


func refresh_tile_cost(i: int) -> void:
	_apply_tile(i)


func begin_tick() -> void:
	budget_left = SimConst.PATH_BUDGET_PER_TICK


## Returns a tile-index path (excluding start) or an empty array when unreachable.
## Returns null when this tick's budget is exhausted.
func find_path(from_i: int, to_i: int) -> Variant:
	if budget_left <= 0:
		refused_total += 1
		return null
	budget_left -= 1
	requests_total += 1
	var w := _world.width
	var a := Vector2i(from_i % w, from_i / w)
	var b := Vector2i(to_i % w, to_i / w)
	if _astar.is_point_solid(b):
		return PackedInt32Array()
	# Starting on a solid tile (e.g. just flooded) is allowed; A* treats start specially.
	var pts: Array[Vector2i] = _astar.get_id_path(a, b, false)
	var out := PackedInt32Array()
	if pts.size() <= 1:
		return out
	out.resize(pts.size() - 1)
	for k in range(1, pts.size()):
		out[k - 1] = pts[k].y * w + pts[k].x
	return out
