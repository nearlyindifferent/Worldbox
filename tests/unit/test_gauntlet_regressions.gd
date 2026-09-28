extends TestCase
## Regression tests for defects proven by Gauntlet critics (see docs/GAUNTLET_LEDGER.md).


func _city_with(sim: Simulation, adults: int, children: int = 0) -> City:
	var band := TestWorlds.add_band(sim, 40.5, 40.5, adults)
	var c := sim.civ.found_city(band[0], sim.world.idx(40, 40), [["test", 0.0]])
	for k in children:
		var s := sim.spawn_unit(sim.human_species, 41.5, 41.5, 3.0)
		sim.civ.join_city(s, c)
	sim.spatial.rebuild(sim.units)
	return c


func test_d5_band_of_one_adult_and_child_cannot_found() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 1)
	sim.spawn_unit(sim.human_species, 41.5, 40.5, 3.0)
	run_ticks(sim, SimConst.TICKS_PER_YEAR)
	assert_eq(sim.cities.size(), 0, "one adult + one child is not a founding band")


func test_d5_founders_are_capped() -> void:
	var sim := TestWorlds.flat(96)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 30)
	var c := sim.civ.found_city(band[0], sim.world.idx(40, 40), [])
	assert_eq(c.population(), CivSystem.MAX_FOUNDERS, "only MAX_FOUNDERS join a new city")
	assert_no_violations(sim, "after capped founding")


func test_d1_birth_rule_scales_with_food_need_not_storage_constant() -> void:
	var sim := TestWorlds.flat(96)
	var c := _city_with(sim, 10)
	# 200 people would have needed 300 food under the old 1.5 x pop rule (capacity 140).
	for k in 190:
		var s := sim.spawn_unit(sim.human_species, 45.5, 45.5, 20.0)
		sim.civ.join_city(s, c)
	var need := sim.civ.monthly_food_need(c)
	c.storage["food"] = need * CivSystem.BIRTH_FOOD_MONTHS + 1.0
	assert_true(c.storage["food"] < 140.0, "a city of 200 can grow with a normal granary stock (need %.1f/month)" % need)
	assert_true(sim.civ.births_food_ok(c), "births allowed with two months of stock")
	c.storage["food"] = need * 0.5
	assert_false(sim.civ.births_food_ok(c), "births blocked below the stock requirement")


func test_d2_unaffordable_civic_site_does_not_block_house() -> void:
	var sim := TestWorlds.flat(96)
	var c := _city_with(sim, 16)
	sim.civ._recompute_capacity(c)
	c.storage["stone"] = 0.0
	c.storage["wood"] = 100.0
	var granary := sim.civ._place_building(c, Defs.building_by_id("granary").index, 50, 34, false)
	var house := sim.civ._place_building(c, Defs.building_by_id("house").index, 34, 46, false)
	var picked := sim.civ.pick_construction(c)
	assert_true(picked != null and picked.id == house.id, "builders go to the affordable house, not the stalled granary")
	c.storage["wood"] = 0.0
	assert_true(sim.civ.pick_construction(c) == null, "nothing workable when nothing is affordable")
	sim.civ._log_blocked_sites(c)
	var logged := false
	for e: Dictionary in sim.decisions.entries:
		if str(e["decision"]).begins_with("cannot start") and int((e["refs"] as Dictionary).get("building", -1)) == granary.id:
			logged = true
	assert_true(logged, "stalled construction is explained in the decision log")


func test_d2_granaries_scale_with_population() -> void:
	var sim := TestWorlds.flat(128)
	var c := _city_with(sim, 12)
	for k in 48:
		var s := sim.spawn_unit(sim.human_species, 45.5, 45.5, 20.0)
		sim.civ.join_city(s, c)
	c.storage["wood"] = 200.0
	c.storage["stone"] = 200.0
	for k in 12:
		sim.civ._plan_construction(c)
		for bid in c.buildings.duplicate():
			var b: Building = sim.buildings[bid]
			if not b.complete:
				sim.civ.try_pay(b)
				sim.civ.add_build_progress(b, 10000)
	var n := sim.civ._count_buildings(c, Defs.building_by_id("granary").index)
	assert_true(n >= 2, "a city of 60 builds more than one granary (%d)" % n)


func test_d6_overflow_spoils_monthly() -> void:
	var sim := TestWorlds.flat(96)
	var c := _city_with(sim, 6)
	sim.civ._recompute_capacity(c)
	c.storage["food"] = c.food_capacity + 300.0
	for k in 12:
		sim.civ._spoil_overflow(c)
	assert_true(float(c.storage["food"]) < c.food_capacity + 10.0, "excess decays toward capacity (%.1f)" % c.storage["food"])
	assert_true(float(c.storage["food"]) >= c.food_capacity, "never decays below capacity")


func test_d7_children_only_city_gets_a_child_ruler() -> void:
	var sim := TestWorlds.flat(96)
	var c := _city_with(sim, 2, 3)
	for mid in c.members.duplicate():
		var s := sim.units.slot_for(mid)
		if sim.units.age_years(s, sim.tick) >= 14.0:
			sim.kill_unit(s, "test")
	sim.civ._ensure_leader(c)
	assert_true(sim.units.is_alive_id(c.leader_id), "a living child leads")
	assert_true(c.members.has(c.leader_id), "leader is a member")


func test_d4_crowded_city_sends_settlers_who_found_a_new_town() -> void:
	var sim := TestWorlds.flat(160)
	var c := _city_with(sim, 12)
	for k in 30:
		var s := sim.spawn_unit(sim.human_species, 44.5, 44.5, 20.0)
		sim.civ.join_city(s, c)
	sim.civ._recompute_capacity(c)
	c.storage["food"] = c.food_capacity
	var sent := false
	for k in 200:
		sim.civ._maybe_send_settlers(c)
		if sim.civ._last_settlers.has(c.id):
			sent = true
			break
	assert_true(sent, "a crowded city sends settlers")
	var settlers := 0
	for s in sim.units.capacity:
		if sim.units.alive[s] == 1 and sim.units.has_flag(s, UnitStore.Flag.SETTLER):
			settlers += 1
	assert_true(settlers >= 2, "settlers are flagged (%d)" % settlers)
	var before := sim.cities.size()
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 3)
	note("cities before %d after %d" % [before, sim.cities.size()])
	assert_true(sim.cities.size() > before, "settlers founded a new city")
	assert_no_violations(sim, "after colonisation")


func test_d9_unreachable_paths_are_rejected_cheaply() -> void:
	var sim := TestWorlds.flat(64)
	var w := sim.world
	for y in 64:
		w.set_biome(w.idx(32, y), Defs.biome_index("ocean"))
	sim.pathfinder.sync_changes()
	sim.pathfinder.rebuild_components()
	sim.pathfinder.begin_tick(sim.tick)
	var before := sim.pathfinder.budget_left
	var p: Variant = sim.pathfinder.find_path(w.idx(10, 10), w.idx(50, 10))
	assert_eq((p as PackedInt32Array).size(), 0, "other landmass unreachable")
	assert_eq(sim.pathfinder.budget_left, before, "no A* budget spent on a known-unreachable target")
	assert_eq(sim.pathfinder.unreachable_skipped, 1)


func test_d9_component_labels_survive_save_load() -> void:
	var sim := Simulation.create_new(31, 96, 96, "archipelago")
	run_ticks(sim, 200)
	var copy := sim.clone()
	assert_eq(copy.pathfinder.components, sim.pathfinder.components)
	run_ticks(sim, 600)
	run_ticks(copy, 600)
	assert_eq(copy.state_hash(), sim.state_hash(), "identical evolution after reload")


func test_d8_brush_radius_is_clamped_and_animals_have_no_genealogy() -> void:
	var sim := TestWorlds.flat(96)
	var r: Dictionary = sim.apply_command({"op": "brush", "power": "paint_desert", "x": 48, "y": 48, "radius": 400})
	assert_true(int(r["changed"]) < 1200, "huge radius clamped (%d tiles)" % int(r["changed"]))
	var m := sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 3.0)
	sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 0.0, sim.units.id[m])
	assert_false(sim.units.children.has(sim.units.id[m]), "no genealogy links for animals")


func test_d10_deaths_are_attributed_per_species() -> void:
	var sim := TestWorlds.flat(64)
	var s := sim.spawn_unit(sim.sheep_species, 20.5, 20.5, 2.0)
	sim.kill_unit(s, "starvation")
	assert_eq(sim.count_deaths("starvation", "sheep"), 1)
	assert_eq(sim.count_deaths("starvation", "human"), 0)


func test_worldgen_places_rare_biomes_somewhere() -> void:
	var found := {}
	for seed_value in range(1, 9):
		var g := WorldGen.generate(seed_value, 192, 192, "island")
		for i in g.size:
			found[g.biome[i]] = true
	for id in ["volcanic", "mystic", "soil"]:
		assert_true(found.has(Defs.biome_index(id)), "%s appears in at least one of 8 maps" % id)
