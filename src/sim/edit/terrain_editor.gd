class_name TerrainEditor
extends RefCounted
## God-power terrain brushes with stroke-grouped undo. Each stroke records the
## first-seen original values of every touched tile; undo restores them exactly.

const UNDO_LIMIT := 50
## Total tiles kept across all undo strokes (bounds memory and save size).
const UNDO_TILE_BUDGET := 200000
const RAISE_STEP := 0.035

## power id -> target biome id for paint brushes
const PAINT := {
	"paint_grass": "grassland", "paint_soil": "soil", "paint_sand": "beach", "paint_shallow": "shallow",
	"paint_ocean": "ocean", "paint_deep": "deep_ocean", "paint_mountain": "mountain", "paint_hills": "hills",
	"paint_forest": "forest", "paint_desert": "desert", "paint_snow": "snow", "paint_swamp": "swamp",
	"paint_ash": "volcanic", "paint_mystic": "mystic",
}
## Elevation assigned when painting a biome so later raise/lower stays coherent.
const PAINT_ELEVATION := {
	"deep_ocean": 0.15, "ocean": 0.30, "shallow": 0.37, "mountain": 0.80, "hills": 0.70, "snow": -1.0,
}

var sim: Simulation
var undo_stack: Array[Dictionary] = []
var _in_stroke := false
var _stroke_seen: Dictionary = {}
var _s_tiles := PackedInt32Array()
var _s_elev := PackedFloat32Array()
var _s_biome := PackedByteArray()
var _s_veg := PackedByteArray()
var _s_wood := PackedByteArray()
var _s_temp := PackedFloat32Array()


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func begin_stroke() -> void:
	if _in_stroke:
		end_stroke()
	_in_stroke = true
	_stroke_seen = {}
	_s_tiles = PackedInt32Array()
	_s_elev = PackedFloat32Array()
	_s_biome = PackedByteArray()
	_s_veg = PackedByteArray()
	_s_wood = PackedByteArray()
	_s_temp = PackedFloat32Array()


func end_stroke() -> void:
	if _in_stroke and _s_tiles.size() > 0:
		undo_stack.append({"tiles": _s_tiles, "elev": _s_elev, "biome": _s_biome, "veg": _s_veg, "wood": _s_wood, "temp": _s_temp})
		var total := 0
		for st in undo_stack:
			total += (st["tiles"] as PackedInt32Array).size()
		while undo_stack.size() > UNDO_LIMIT or (total > UNDO_TILE_BUDGET and undo_stack.size() > 1):
			total -= (undo_stack[0]["tiles"] as PackedInt32Array).size()
			undo_stack.remove_at(0)
	_in_stroke = false
	_stroke_seen = {}


## Brushes applied outside an explicit stroke form their own single-dab stroke.
func _remember(i: int) -> void:
	if not _in_stroke:
		begin_stroke()
	if _stroke_seen.has(i):
		return
	_stroke_seen[i] = true
	var w := sim.world
	_s_tiles.append(i)
	_s_elev.append(w.elevation[i])
	_s_biome.append(w.biome[i])
	_s_veg.append(w.vegetation[i])
	_s_wood.append(w.wood[i])
	_s_temp.append(w.temperature[i])


func is_terrain_power(power: String) -> bool:
	return power == "raise" or power == "lower" or PAINT.has(power)


## Applies a circular brush. Returns number of tiles changed. A brush applied outside
## an explicit stroke is its own complete stroke (so undo state is never left open).
func apply_brush(power: String, cx: int, cy: int, radius: int) -> int:
	var standalone := not _in_stroke
	if standalone:
		begin_stroke()
	var n := _apply_disk(power, cx, cy, radius)
	if standalone:
		end_stroke()
	return n


func _apply_disk(power: String, cx: int, cy: int, radius: int) -> int:
	var w := sim.world
	var changed := 0
	var r := maxi(0, radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r + r or not w.in_bounds(cx + dx, cy + dy):
				continue
			var i := w.idx(cx + dx, cy + dy)
			var falloff := 1.0 - (sqrt(float(dx * dx + dy * dy)) / float(r + 1)) * 0.6
			if _apply_tile(power, i, falloff):
				changed += 1
	return changed


func _apply_tile(power: String, i: int, falloff: float) -> bool:
	var w := sim.world
	var old_b := w.biome[i]
	var old_e := w.elevation[i]
	_remember(i)
	if power == "raise" or power == "lower":
		var delta := RAISE_STEP * falloff * (1.0 if power == "raise" else -1.0)
		var e := clampf(old_e + delta, 0.0, 1.0)
		w.elevation[i] = e
		w.temperature[i] -= (e - old_e) * 45.0
		var nb := WorldGen.classify(e, w.moisture[i], w.temperature[i])
		# Keep man-made and painted land types unless the tile crosses the shoreline or peaks.
		if old_b == Defs.farmland_index and nb != Defs.farmland_index and Defs.biome_walkable[nb] == 1 and Defs.biome_water[nb] == 0:
			nb = old_b
		w.set_biome(i, nb)
	else:
		var target: String = PAINT[power]
		var tb := Defs.biome_index(target)
		if tb == old_b:
			return false
		var pe: float = PAINT_ELEVATION.get(target, -1.0)
		if pe >= 0.0:
			w.elevation[i] = pe
		elif w.elevation[i] < WorldGen.SEA_LEVEL + 0.02:
			w.elevation[i] = WorldGen.SEA_LEVEL + 0.04
		w.set_biome(i, tb)
		if Defs.biome_veg_max[tb] > 0:
			w.vegetation[i] = int(Defs.biome_veg_max[tb] * 0.6)
	w.mark_dirty(i)
	_after_change(i, old_b)
	return w.biome[i] != old_b or w.elevation[i] != old_e


func _after_change(i: int, old_b: int) -> void:
	var w := sim.world
	if w.biome[i] != old_b:
		sim.pathfinder.refresh_tile_cost(i)
		sim.civ.on_tile_changed(i)


func can_undo() -> bool:
	return not undo_stack.is_empty()


func undo() -> int:
	if _in_stroke:
		end_stroke()
	if undo_stack.is_empty():
		return 0
	var st: Dictionary = undo_stack.pop_back()
	var w := sim.world
	var tiles: PackedInt32Array = st["tiles"]
	for k in range(tiles.size() - 1, -1, -1):
		var i := tiles[k]
		var old_b := w.biome[i]
		w.set_biome(i, (st["biome"] as PackedByteArray)[k])
		w.elevation[i] = (st["elev"] as PackedFloat32Array)[k]
		w.vegetation[i] = (st["veg"] as PackedByteArray)[k]
		w.wood[i] = (st["wood"] as PackedByteArray)[k]
		w.temperature[i] = (st["temp"] as PackedFloat32Array)[k]
		w.mark_dirty(i)
		_after_change(i, old_b)
	return tiles.size()
