extends TestCase


func test_unit_store_allocation_and_reuse() -> void:
	var st := UnitStore.new()
	var a := st.allocate()
	var b := st.allocate()
	var ida := st.id[a]
	var idb := st.id[b]
	assert_ne(ida, idb)
	assert_eq(st.count, 2)
	st.free_slot(a)
	assert_eq(st.count, 1)
	assert_false(st.is_alive_id(ida))
	var c := st.allocate()
	assert_eq(c, a, "slot recycled")
	assert_true(st.id[c] > idb, "ids are never reused")
	for k in 500:
		st.allocate()
	assert_eq(st.count, 502)
	assert_eq(st.slot_of.size(), 502)


func test_hunger_starvation_and_law() -> void:
	var sim := TestWorlds.flat(48)
	var s := sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 2.0)
	var uid := sim.units.id[s]
	sim.laws.set_law("vegetation_growth", false)
	for i in sim.world.size:
		sim.world.vegetation[i] = 0
	sim.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	sim.units.hunger[s] = SimConst.HUNGER_MAX
	run_ticks(sim, 400)
	assert_false(sim.units.is_alive_id(uid), "starved without food")
	assert_true(int(sim.deaths_by_cause.get("starvation", 0)) >= 1, "starvation cause recorded")
	var s2 := sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 2.0)
	var uid2 := sim.units.id[s2]
	sim.units.set_flag(s2, UnitStore.Flag.FROZEN, true)
	sim.units.hunger[s2] = 0.0
	sim.laws.set_law("hunger", false)
	run_ticks(sim, 800)
	assert_true(sim.units.is_alive_id(uid2), "hunger law off keeps unit alive")
	assert_eq(sim.units.hunger[sim.units.slot_for(uid2)], 0.0, "no hunger accrues with law off")


func test_old_age_and_invulnerability() -> void:
	var sim := TestWorlds.flat(48)
	var s := sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 1.0)
	var uid := sim.units.id[s]
	sim.units.death_age[s] = sim.tick - sim.units.birth_tick[s] + 5
	var t := sim.spawn_unit(sim.sheep_species, 22.5, 20.5, 1.0)
	var tid := sim.units.id[t]
	sim.units.death_age[t] = sim.tick - sim.units.birth_tick[t] + 5
	sim.units.set_flag(t, UnitStore.Flag.INVULNERABLE, true)
	run_ticks(sim, 10)
	assert_false(sim.units.is_alive_id(uid), "died of old age")
	assert_true(sim.units.is_alive_id(tid), "invulnerable survives")


func test_drowning_units_seek_land() -> void:
	var sim := TestWorlds.flat(48)
	var s := sim.spawn_unit(sim.human_species, 20.5, 20.5)
	var uid := sim.units.id[s]
	sim.units.x[s] = 1.5
	sim.units.y[s] = 20.5
	run_ticks(sim, 60)
	var s2 := sim.units.slot_for(uid)
	assert_true(s2 >= 0, "unit escaped the water alive")
	if s2 >= 0:
		assert_true(sim.world.is_walkable(sim.units.tile_index(s2, sim.world.width)), "unit is on land")


func test_spatial_index_matches_bruteforce() -> void:
	var sim := TestWorlds.flat(96)
	for k in 300:
		sim.spawn_unit(sim.sheep_species, sim.rng.randf_range(4, 90), sim.rng.randf_range(4, 90), 2.0)
	sim.spatial.rebuild(sim.units)
	for q in 20:
		var px := sim.rng.randf_range(0, 96)
		var py := sim.rng.randf_range(0, 96)
		var r := sim.rng.randf_range(1, 20)
		var got := sim.spatial.query_radius(sim.units, px, py, r)
		var want := 0
		for s in sim.units.capacity:
			if sim.units.alive[s] == 1 and Vector2(sim.units.x[s] - px, sim.units.y[s] - py).length_squared() <= r * r:
				want += 1
		assert_eq(got.size(), want, "query %d" % q)


func test_pathfinding_avoids_water_and_follows_edits() -> void:
	var sim := TestWorlds.flat(48)
	var w := sim.world
	# Wall of water with one gap at y=40.
	for y in range(3, 45):
		if y != 40:
			w.set_biome(w.idx(24, y), Defs.biome_index("ocean"))
	sim.pathfinder.sync_changes()
	var p: PackedInt32Array = sim.pathfinder.find_path(w.idx(10, 10), w.idx(38, 10))
	assert_true(p.size() > 0, "path exists through gap")
	var through_gap := false
	for i in p:
		assert_true(w.is_walkable(i), "path tile walkable")
		if i == w.idx(24, 40):
			through_gap = true
	assert_true(through_gap, "path uses the gap")
	w.set_biome(w.idx(24, 40), Defs.biome_index("ocean"))
	sim.pathfinder.sync_changes()
	sim.pathfinder.begin_tick()
	var p2: PackedInt32Array = sim.pathfinder.find_path(w.idx(10, 10), w.idx(38, 10))
	assert_eq(p2.size(), 0, "no path once the gap is flooded")


func test_path_budget_is_enforced() -> void:
	var sim := TestWorlds.flat(48)
	sim.pathfinder.begin_tick()
	var served := 0
	for k in SimConst.PATH_BUDGET_PER_TICK + 10:
		if sim.pathfinder.find_path(sim.world.idx(10, 10), sim.world.idx(30, 30)) != null:
			served += 1
	assert_eq(served, SimConst.PATH_BUDGET_PER_TICK)


func test_ecosystem_herds_graze_breed_and_stay_bounded() -> void:
	var sim := TestWorlds.flat(96)
	for k in 12:
		var s := sim.spawn_unit(sim.sheep_species, 40.5 + (k % 4), 40.5 + k / 4, 2.0)
		sim.units.sex[s] = k % 2
	var veg_before := 0
	for i in sim.world.size:
		veg_before += sim.world.vegetation[i]
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 6)
	var sheep := sim.count_species(sim.sheep_species)
	note("sheep after 6 years: %d, births %d" % [sheep, sim.total_births])
	assert_true(sim.total_births > 5, "herd reproduced")
	assert_between(sheep, 8, 400, "herd population bounded")
	assert_no_violations(sim, "ecosystem")
