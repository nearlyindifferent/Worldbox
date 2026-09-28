class_name VegetationSystem
extends RefCounted
## Staggered cellular update: each tick visits 1/VEG_CYCLE_TICKS of the chunks, so
## every tile regrows once per cycle at constant per-tick cost regardless of world size.

var sim: Simulation
## Per-chunk "contains any land" cache, refreshed when the chunk's revision changes.
var _has_land := PackedByteArray()
var _land_rev := PackedInt32Array()


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	var n := sim.world.chunks_x * sim.world.chunks_y
	_has_land.resize(n)
	_land_rev.resize(n)
	_land_rev.fill(-1)


func _chunk_has_land(c: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	var w := sim.world
	if _land_rev[c] != w.chunk_rev[c]:
		_land_rev[c] = w.chunk_rev[c]
		_has_land[c] = 0
		for y in range(y0, y1):
			for x in range(x0, x1):
				if Defs.biome_water[w.biome[y * w.width + x]] == 0:
					_has_land[c] = 1
					break
			if _has_land[c] == 1:
				break
	return _has_land[c] == 1


func update() -> void:
	var w := sim.world
	var grow := sim.laws.is_on("vegetation_growth")
	var spread := sim.laws.is_on("forest_spread")
	var phase := sim.tick % SimConst.VEG_CYCLE_TICKS
	var n_chunks := w.chunks_x * w.chunks_y
	var farmland := Defs.farmland_index
	var grass := Defs.grassland_index
	var forest := Defs.forest_index
	var forest_wood: int = (Defs.biomes[forest] as Defs.BiomeDef).wood
	for c in range(phase, n_chunks, SimConst.VEG_CYCLE_TICKS):
		var x0 := (c % w.chunks_x) * SimConst.CHUNK
		var y0 := (c / w.chunks_x) * SimConst.CHUNK
		var x1 := mini(x0 + SimConst.CHUNK, w.width)
		var y1 := mini(y0 + SimConst.CHUNK, w.height)
		if not _chunk_has_land(c, x0, y0, x1, y1):
			continue
		var changed := false
		for y in range(y0, y1):
			var row := y * w.width
			for x in range(x0, x1):
				var i := row + x
				var b := w.biome[i]
				if Defs.biome_water[b] == 1:
					continue
				var v := w.vegetation[i]
				if b == farmland:
					if grow and v < 255:
						var nv := mini(255, v + int(SimConst.CROP_GROWTH * (0.4 + 0.6 * w.moisture[i])))
						w.vegetation[i] = nv
						changed = changed or (nv >> 6) != (v >> 6)
					continue
				var vmax := Defs.biome_veg_max[b]
				if grow and v < vmax:
					var nv := mini(vmax, v + int(SimConst.VEG_GROWTH * w.fertility(i)) + 1)
					w.vegetation[i] = nv
					changed = changed or (nv >> 6) != (v >> 6)
				if b == forest and w.wood[i] < forest_wood:
					w.wood[i] = mini(forest_wood, w.wood[i] + 9)
				elif spread and b == forest and sim.rng.chance(SimConst.FOREST_DIEBACK_CHANCE):
					w.set_biome(i, grass)
					sim.pathfinder.refresh_tile_cost(i)
				elif spread and b == grass and w.owner[i] == SimConst.CITY_NONE and sim.rng.chance(SimConst.FOREST_SPREAD_CHANCE):
					if _neighbor_is(i, x, y, forest):
						w.set_biome(i, forest)
						w.wood[i] = forest_wood / 4
						sim.pathfinder.refresh_tile_cost(i)
		if changed:
			w.chunk_rev[c] += 1


func _neighbor_is(i: int, x: int, y: int, b: int) -> bool:
	var w := sim.world
	return (x > 0 and w.biome[i - 1] == b) or (x < w.width - 1 and w.biome[i + 1] == b) \
		or (y > 0 and w.biome[i - w.width] == b) or (y < w.height - 1 and w.biome[i + w.width] == b)
