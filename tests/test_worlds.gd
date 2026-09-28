class_name TestWorlds
extends RefCounted
## Reproducible scenario worlds for tests and benchmarks.


## Flat fertile grassland with a 3-tile ocean border, a forest strip and a hill ridge.
static func flat(size: int = 96, seed_value: int = 1) -> Simulation:
	var sim := Simulation.create_new(seed_value, size, size, "island", false)
	var w := sim.world
	for y in size:
		for x in size:
			var i := w.idx(x, y)
			var border := x < 3 or y < 3 or x >= size - 3 or y >= size - 3
			var b := Defs.biome_index("ocean") if border else Defs.grassland_index
			if not border and x >= size - 14 and x < size - 8:
				b = Defs.forest_index
			if not border and y >= size - 10 and y < size - 7 and x < 30:
				b = Defs.hills_index
			w.biome[i] = b
			w.elevation[i] = 0.3 if border else 0.5
			w.moisture[i] = 0.6
			w.temperature[i] = 16.0
			w.wood[i] = (Defs.biomes[b] as Defs.BiomeDef).wood
			w.vegetation[i] = Defs.biome_veg_max[b]
			w.owner[i] = SimConst.CITY_NONE
			w.building[i] = SimConst.BUILDING_ID_NONE
	sim._init_systems()
	return sim


static func add_band(sim: Simulation, cx: float, cy: float, n: int, age: float = 22.0) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in n:
		var s := sim.spawn_unit(sim.human_species, cx + (k % 3) * 0.8, cy + (k / 3) * 0.8, age)
		sim.units.sex[s] = k % 2
		out.append(s)
	sim.spatial.rebuild(sim.units)
	return out


static func world_hash(sim: Simulation) -> String:
	var w := sim.world
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for arr: Variant in [w.elevation, w.biome, w.moisture, w.temperature, w.vegetation, w.wood, w.owner, w.building]:
		ctx.update(var_to_bytes(arr))
	return ctx.finish().hex_encode()
