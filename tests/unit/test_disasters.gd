extends TestCase
## Fire, lava, meteors, earthquakes, rain and plague (Feature D).


func _count_biome(sim: Simulation, id: String) -> int:
	var b := Defs.biome_index(id)
	var n := 0
	for i in sim.world.size:
		if sim.world.biome[i] == b:
			n += 1
	return n


func test_fire_spreads_through_forest_and_leaves_scorched_land() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("natural_disasters", false)
	var r := sim.apply_command({"op": "brush", "power": "fire", "x": 85, "y": 48, "radius": 1})
	assert_true(r["ok"], str(r["msg"]))
	var peak := 0
	for k in 600:
		sim.step()
		peak = maxi(peak, sim.disasters.burning.size())
		if k % 100 == 0:
			assert_no_violations(sim, "while burning (tick %d)" % sim.tick)
	note("peak burning tiles %d, scorched %d" % [peak, _count_biome(sim, "scorched")])
	assert_true(peak > 20, "the fire spread (%d tiles at peak)" % peak)
	assert_true(_count_biome(sim, "scorched") > 30, "burnt land is left scorched")
	assert_true(sim.history.major.any(func(e: Dictionary) -> bool: return int(e["kind"]) == HistoryLog.Kind.GOD_ACT), "the god act is chronicled")


func test_fire_burns_out_and_does_not_cross_water() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("natural_disasters", false)
	# A water moat around a patch of grass.
	var w := sim.world
	for y in range(30, 51):
		for x in range(30, 51):
			if x == 30 or y == 30 or x == 50 or y == 50:
				w.set_biome(w.idx(x, y), Defs.biome_index("shallow"))
	sim.disasters.ignite(w.idx(40, 40))
	run_ticks(sim, 900)
	assert_eq(sim.disasters.burning.size(), 0, "the fire burnt out")
	assert_eq(w.biome[w.idx(20, 20)], Defs.grassland_index, "land beyond the moat was untouched")
	assert_eq(w.biome[w.idx(40, 40)], Defs.biome_index("scorched"))


func test_creatures_flee_and_burn() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("natural_disasters", false)
	var band := TestWorlds.add_band(sim, 50.5, 50.5, 6)
	var w := sim.world
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			sim.disasters.ignite(w.idx(50 + dx, 50 + dy))
	run_ticks(sim, 60)
	var fled := 0
	for s in band:
		if sim.units.alive[s] == 1 and not sim.disasters.is_burning(sim.units.tile_index(s, w.width)):
			fled += 1
	var burned := sim.count_deaths("fire", "human")
	note("fled %d burned %d" % [fled, burned])
	assert_true(fled + burned == 6, "everyone either escaped the flames or died in them")
	assert_true(fled > 0, "people run from fire")


func test_rain_puts_out_fire() -> void:
	var sim := TestWorlds.flat(96)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			sim.disasters.ignite(sim.world.idx(40 + dx, 40 + dy))
	assert_true(sim.disasters.burning.size() >= 20)
	sim.apply_command({"op": "brush", "power": "rain", "x": 40, "y": 40, "radius": 4})
	assert_eq(sim.disasters.burning.size(), 0, "rain doused every flame under it")
	assert_no_violations(sim, "after rain")


func test_meteor_kills_craters_and_cools() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("natural_disasters", false)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 6)
	var r := sim.apply_command({"op": "brush", "power": "meteor", "x": 41, "y": 41, "radius": 3})
	assert_true(r["ok"])
	assert_true(int(r["killed"]) >= 5, "creatures at the impact die (%d)" % int(r["killed"]))
	assert_true(_count_biome(sim, "lava") > 0, "the crater holds lava")
	assert_true(sim.count_deaths("meteor") >= 5)
	run_ticks(sim, DisasterSystem.LAVA_COOL_STEPS * DisasterSystem.FIRE_STEP * 2 + 30)
	assert_eq(_count_biome(sim, "lava"), 0, "lava cools")
	assert_true(_count_biome(sim, "volcanic") > 0, "into ashlands")
	assert_no_violations(sim, "after meteor")


func test_earthquake_topples_a_town() -> void:
	var sim := TestWorlds.flat(128)
	sim.laws.set_law("natural_disasters", false)
	var band := TestWorlds.add_band(sim, 50.5, 50.5, 12)
	var c := sim.civ.found_city(band[0], sim.world.idx(50, 50), [])
	for k in 6:
		sim.civ._place_building(c, Defs.building_by_id("house").index, 44 + k * 3, 56, true)
	var before := sim.buildings.size()
	sim.apply_command({"op": "brush", "power": "earthquake", "x": 50, "y": 55, "radius": 4})
	run_ticks(sim, DisasterSystem.QUAKE_TICKS + 5)
	note("buildings %d -> %d" % [before, sim.buildings.size()])
	assert_true(sim.buildings.size() < before, "buildings collapsed")
	assert_true(sim.disasters.quakes.is_empty(), "the quake ended")
	assert_no_violations(sim, "after quake")


func test_plague_spreads_then_ends_in_death_or_immunity() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("natural_disasters", false)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 20)
	for s in band:
		sim.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	sim.disasters.infect(band[0])
	var peak := 0
	for k in 60:
		run_ticks(sim, 10)
		peak = maxi(peak, sim.disasters.sick_count())
	run_ticks(sim, DisasterSystem.PLAGUE_TICKS * 3)
	var dead := sim.count_deaths("plague", "human")
	var immune := 0
	for s in band:
		if sim.units.alive[s] == 1 and sim.units.has_flag(s, UnitStore.Flag.IMMUNE):
			immune += 1
	note("peak sick %d, dead %d, immune %d" % [peak, dead, immune])
	assert_true(peak >= 5, "the plague spread through the crowd")
	assert_eq(sim.disasters.sick_count(), 0, "the outbreak ended")
	assert_true(dead > 0 and immune > 0, "some died, some recovered")
	for s in band:
		if sim.units.alive[s] == 1 and sim.units.has_flag(s, UnitStore.Flag.IMMUNE):
			assert_false(sim.disasters.infect(s), "survivors are immune")
			break


func test_scorched_land_regrows_into_grass() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	var i := sim.world.idx(30, 30)
	sim.world.set_biome(i, Defs.biome_index("scorched"))
	sim.world.vegetation[i] = 0
	run_ticks(sim, SimConst.VEG_CYCLE_TICKS * 20)
	assert_eq(sim.world.biome[i], Defs.grassland_index, "grass returns to the burn scar")


func test_disasters_survive_save_and_clone_identically() -> void:
	var sim := TestWorlds.flat(96)
	var band := TestWorlds.add_band(sim, 30.5, 30.5, 10)
	sim.civ.found_city(band[0], sim.world.idx(30, 30), [])
	sim.apply_command({"op": "brush", "power": "fire", "x": 85, "y": 40, "radius": 2})
	sim.apply_command({"op": "brush", "power": "volcano", "x": 60, "y": 60, "radius": 2})
	sim.apply_command({"op": "brush", "power": "earthquake", "x": 30, "y": 36, "radius": 2})
	sim.apply_command({"op": "brush", "power": "plague", "x": 30, "y": 30, "radius": 3})
	run_ticks(sim, 25)
	var copy := sim.clone()
	var m := SaveManager.new("user://test_disaster_saves")
	assert_true(m.save_slot(sim, "d")["ok"])
	var r := m.load_slot("d")
	assert_true(r["ok"], str(r.get("msg", "")))
	var loaded: Simulation = r["sim"]
	run_ticks(sim, 200)
	run_ticks(copy, 200)
	run_ticks(loaded, 200)
	assert_eq(copy.state_hash(), sim.state_hash(), "clone mid-disaster evolves identically")
	assert_eq(loaded.state_hash(), sim.state_hash(), "save/load mid-disaster evolves identically")
	m.delete_slot("d")
