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
var unreachable_skipped: int = 0

## Connected land components ("landmasses"). Queries between different components are
## answered instantly instead of exhausting A* over a whole island. Labels are rebuilt
## at most every COMPONENT_REBUILD_TICKS while dirty; they are saved with the world so
## a reloaded simulation makes exactly the same decisions.
const COMPONENT_REBUILD_TICKS := 30
var components := PackedInt32Array()
var components_dirty := true
var components_built_tick: int = -1000000
var _now_tick: int = 0


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
	components_dirty = true


func _apply_tile(i: int) -> void:
	var p := Vector2i(i % _world.width, i / _world.width)
	var walk := _world.is_walkable(i)
	_astar.set_point_solid(p, not walk)
	if walk:
		_astar.set_point_weight_scale(p, Defs.biome_move_cost[_world.biome[i]])


func sync_changes() -> void:
	var changed := _world.drain_walk_changes()
	for i in changed:
		_apply_tile(i)
	if changed.size() > 0:
		components_dirty = true


func component_of(i: int) -> int:
	if components_dirty and _now_tick - components_built_tick >= COMPONENT_REBUILD_TICKS:
		rebuild_components()
	return components[i] if components.size() == _world.size else -1


## Flood-fills 4-connected walkable regions (diagonal moves require both orthogonal
## neighbours to be open, so 4-connectivity matches reachability). Water/mountain = -1.
func rebuild_components() -> void:
	var w := _world
	components.resize(w.size)
	components.fill(-1)
	var stack := PackedInt32Array()
	var label := 0
	var walk := Defs.biome_walkable
	var biome := w.biome
	var width := w.width
	for start in w.size:
		if components[start] != -1 or walk[biome[start]] == 0:
			continue
		components[start] = label
		stack.append(start)
		while stack.size() > 0:
			var i := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := i % width
			if x > 0 and components[i - 1] == -1 and walk[biome[i - 1]] == 1:
				components[i - 1] = label
				stack.append(i - 1)
			if x < width - 1 and components[i + 1] == -1 and walk[biome[i + 1]] == 1:
				components[i + 1] = label
				stack.append(i + 1)
			if i >= width and components[i - width] == -1 and walk[biome[i - width]] == 1:
				components[i - width] = label
				stack.append(i - width)
			if i + width < w.size and components[i + width] == -1 and walk[biome[i + width]] == 1:
				components[i + width] = label
				stack.append(i + width)
		label += 1
	components_dirty = false
	components_built_tick = _now_tick


func refresh_tile_cost(i: int) -> void:
	_apply_tile(i)


func begin_tick(tick: int = 0) -> void:
	budget_left = SimConst.PATH_BUDGET_PER_TICK
	_now_tick = tick


## Returns a tile-index path (excluding start) or an empty array when unreachable.
## Returns null when this tick's budget is exhausted.
func find_path(from_i: int, to_i: int) -> Variant:
	if budget_left <= 0:
		refused_total += 1
		return null
	var w := _world.width
	var a := Vector2i(from_i % w, from_i / w)
	var b := Vector2i(to_i % w, to_i / w)
	if _astar.is_point_solid(b):
		return PackedInt32Array()
	var ca := component_of(from_i)
	var cb := component_of(to_i)
	if ca >= 0 and cb >= 0 and ca != cb:
		unreachable_skipped += 1
		return PackedInt32Array()
	budget_left -= 1
	requests_total += 1
	# Starting on a solid tile (e.g. just flooded) is allowed; A* treats start specially.
	var pts: Array[Vector2i] = _astar.get_id_path(a, b, false)
	var out := PackedInt32Array()
	if pts.size() <= 1:
		return out
	out.resize(pts.size() - 1)
	for k in range(1, pts.size()):
		out[k - 1] = pts[k].y * w + pts[k].x
	return out


func components_to_dict() -> Dictionary:
	return {"labels": components, "dirty": components_dirty or _world.walk_changed.size() > 0, "built": components_built_tick}


func components_from_dict(d: Dictionary) -> void:
	components = d["labels"]
	components_dirty = bool(d["dirty"])
	components_built_tick = int(d["built"])
