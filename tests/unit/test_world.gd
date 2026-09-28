extends TestCase


func test_defs_indices_are_contiguous_and_unique() -> void:
	var seen := {}
	for k in Defs.biomes.size():
		var b: Defs.BiomeDef = Defs.biomes[k]
		assert_true(b != null, "biome index %d missing" % k)
		if b:
			assert_eq(b.index, k)
			assert_false(seen.has(b.id), "duplicate biome id " + b.id)
			seen[b.id] = true
			assert_eq(b.colors.size(), 4, "palette size for " + b.id)
	assert_true(Defs.species.size() >= 2)
	assert_true(Defs.species_by_id("human").sapient)
	assert_false(Defs.species_by_id("sheep").sapient)
	assert_true(Defs.building_by_id("house").housing > 0)
	assert_eq(Defs.jobs[0].id, "none", "job 0 must be idle")


func test_worldgen_is_deterministic() -> void:
	for shape in WorldGen.SHAPES:
		var a := WorldGen.generate(42, 96, 96, shape)
		var b := WorldGen.generate(42, 96, 96, shape)
		assert_eq(a.biome, b.biome, shape + " biome")
		assert_eq(a.elevation, b.elevation, shape + " elevation")
		var c := WorldGen.generate(43, 96, 96, shape)
		assert_ne(a.biome, c.biome, shape + " different seeds should differ")


func test_worldgen_land_fraction_and_sanity() -> void:
	for shape in WorldGen.SHAPES:
		for seed_value in [1, 2, 3, 4]:
			var g := WorldGen.generate(seed_value, 128, 128, shape)
			var land := 0
			var biomes := {}
			for i in g.size:
				assert_true(is_finite(g.elevation[i]) and is_finite(g.temperature[i]) and is_finite(g.moisture[i]), "finite climate")
				if g.is_walkable(i):
					land += 1
				biomes[g.biome[i]] = true
			var frac := float(land) / g.size
			assert_between(frac, 0.10, 0.60, "%s/%d walkable fraction" % [shape, seed_value])
			assert_true(biomes.size() >= 6, "%s/%d biome variety %d" % [shape, seed_value, biomes.size()])
			# Map edges are always sea so nothing can walk off the world.
			for x in g.width:
				assert_true(g.is_water(g.idx(x, 0)) and g.is_water(g.idx(x, g.height - 1)), "edge is water")


func test_classify_thresholds() -> void:
	assert_eq(WorldGen.classify(0.1, 0.5, 20.0), Defs.biome_index("deep_ocean"))
	assert_eq(WorldGen.classify(0.38, 0.5, 20.0), Defs.biome_index("shallow"))
	assert_eq(WorldGen.classify(0.8, 0.5, 5.0), Defs.biome_index("mountain"))
	assert_eq(WorldGen.classify(0.5, 0.2, 30.0), Defs.biome_index("desert"))
	assert_eq(WorldGen.classify(0.5, 0.45, 15.0), Defs.grassland_index)
	assert_eq(WorldGen.classify(0.5, 0.65, 15.0), Defs.forest_index)


func test_set_biome_keeps_fields_consistent() -> void:
	var g := WorldGen.generate(5, 64, 64, "island")
	var i := g.idx(32, 32)
	g.set_biome(i, Defs.forest_index)
	assert_eq(g.wood[i], (Defs.biomes[Defs.forest_index] as Defs.BiomeDef).wood)
	g.drain_walk_changes()
	g.set_biome(i, Defs.biome_index("ocean"))
	assert_eq(g.wood[i], 0)
	assert_true(g.drain_walk_changes().has(i), "walkability change queued for pathfinder")
	assert_eq(g.vegetation[i], 0, "water has no vegetation")


func test_vegetation_regrows_and_is_law_gated() -> void:
	var sim := TestWorlds.flat(64)
	var i := sim.world.idx(20, 20)
	sim.world.vegetation[i] = 0
	sim.laws.set_law("vegetation_growth", false)
	run_ticks(sim, SimConst.VEG_CYCLE_TICKS * 3)
	assert_eq(sim.world.vegetation[i], 0, "no growth with law off")
	sim.laws.set_law("vegetation_growth", true)
	run_ticks(sim, SimConst.VEG_CYCLE_TICKS * 3)
	assert_true(sim.world.vegetation[i] > 0, "regrows with law on")


func test_stat_series_is_bounded() -> void:
	var s := StatSeries.new()
	for k in 100000:
		s.push(float(k))
	assert_true(s.values.size() < StatSeries.CAPACITY, "bounded samples")
	assert_true(s.interval > 1, "interval grew")
	assert_between(s.last(), 90000.0, 100000.0, "recent sample stays recent")
