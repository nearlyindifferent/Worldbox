extends TestCase


func test_band_founds_settlement_with_reasons() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, SimConst.TICKS_PER_YEAR)
	assert_eq(sim.cities.size(), 1, "one settlement founded")
	if sim.cities.size() == 1:
		var c: City = sim.cities.values()[0]
		assert_eq(c.population(), 6, "whole band joined")
		assert_true(c.founding_reasons.size() > 0, "founding reasons recorded")
		assert_true(c.territory.size() > 50, "territory claimed")
		var hall: Building = sim.buildings[c.buildings[0]]
		assert_eq(hall.def().id, "town_hall")
		var found := false
		for e: Dictionary in sim.decisions.entries:
			if e["category"] == "settlement":
				found = true
		assert_true(found, "decision log explains the founding")
	assert_no_violations(sim, "after founding")


func test_lone_wanderer_does_not_found() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 1)
	run_ticks(sim, SimConst.TICKS_PER_YEAR)
	assert_eq(sim.cities.size(), 0, "a band of one cannot found a city")


func test_founding_law_blocks_settlements() -> void:
	var sim := TestWorlds.flat(96)
	sim.laws.set_law("settlement_founding", false)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, SimConst.TICKS_PER_YEAR)
	assert_eq(sim.cities.size(), 0)


func test_city_grows_builds_houses_and_farms() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 8)
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 20)
	assert_eq(sim.cities.size(), 1)
	if sim.cities.size() != 1:
		return
	var c: City = sim.cities.values()[0]
	var houses := 0
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.def().id == "house" and b.complete:
			houses += 1
	note("pop %d housing %d houses %d fields %d food %.0f wood %.0f births %d" % [c.population(), c.housing, houses, c.fields.size(), c.storage["food"], c.storage["wood"], c.births])
	assert_true(houses >= 2, "built houses")
	assert_true(c.births >= 4, "children were born")
	assert_true(c.population() > 8, "population grew")
	assert_true(c.fields.size() >= 4, "farmland created")
	assert_true(c.population() <= c.housing + 2, "population respects housing (+2 joiner slack)")
	assert_no_violations(sim, "after 20 years")


func test_food_chain_farm_to_storage_to_consumption() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 8)
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 4)
	var c: City = sim.cities.values()[0]
	var produced := 0.0
	var consumed := 0.0
	var harvested_fields := 0
	for k in 24:
		run_ticks(sim, SimConst.TICKS_PER_MONTH)
		produced += float(c.last_produced["food"])
		consumed += float(c.last_consumed["food"])
	assert_true(produced > 0.0, "food entered storage (%.1f)" % produced)
	assert_true(consumed > 0.0, "citizens ate from storage (%.1f)" % consumed)
	assert_true(float(c.storage["food"]) <= c.food_capacity + 0.001, "storage respects capacity")


func test_starvation_after_sustained_shortage() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 8)
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 2)
	var c: City = sim.cities.values()[0]
	var pop0 := c.population()
	# Remove every food source: salt the earth and empty the stores.
	sim.laws.set_law("vegetation_growth", false)
	for i in sim.world.size:
		sim.world.vegetation[i] = 0
	for u in sim.units.capacity:
		if sim.units.alive[u] == 1 and sim.units.species[u] == sim.sheep_species:
			sim.kill_unit(u, "test")
	c.storage["food"] = 0.0
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 2)
	var starved := int(sim.deaths_by_cause.get("starvation", 0))
	note("pop before %d, starved %d" % [pop0, starved])
	assert_true(starved > 0, "people starve after sustained shortage")
	var famine := false
	for e: Dictionary in sim.history.major:
		if int(e["kind"]) == HistoryLog.Kind.FAMINE:
			famine = true
	assert_true(famine, "famine recorded in history")
	assert_no_violations(sim, "famine")


func test_construction_requires_materials() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, 200)
	var c: City = sim.cities.values()[0]
	var house := Defs.building_by_id("house")
	var b := Building.new()
	b.type = house.index
	b.city = c.id
	c.storage["wood"] = 0.0
	assert_false(sim.civ.try_pay(b), "cannot pay without wood")
	assert_false(b.paid)
	c.storage["wood"] = 100.0
	assert_true(sim.civ.try_pay(b), "pays with wood")
	assert_eq(float(c.storage["wood"]), 100.0 - float(house.cost["wood"]), "cost deducted exactly once")
	assert_true(sim.civ.try_pay(b), "second call is a no-op")
	assert_eq(float(c.storage["wood"]), 100.0 - float(house.cost["wood"]))


func test_deposit_respects_capacity_and_never_negative() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, 200)
	var c: City = sim.cities.values()[0]
	c.storage["food"] = 0.0
	sim.civ.deposit(c, "food", c.food_capacity * 3.0)
	assert_eq(float(c.storage["food"]), c.food_capacity, "capped at capacity")
	var took := c.take_resource("food", c.food_capacity * 5.0)
	assert_eq(took, c.food_capacity)
	assert_eq(float(c.storage["food"]), 0.0, "never negative")


func test_job_targets_prioritize_food_when_starving() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 10)
	run_ticks(sim, 200)
	var c: City = sim.cities.values()[0]
	c.storage["food"] = 0.0
	var starving := sim.civ.compute_job_targets(c, 10)
	c.storage["food"] = c.food_capacity
	var fed := sim.civ.compute_job_targets(c, 10)
	var food_jobs := func(t: PackedInt32Array) -> int: return t[Defs.job_by_id("farmer").index] + t[Defs.job_by_id("gatherer").index]
	assert_true(food_jobs.call(starving) > food_jobs.call(fed), "more food workers when starving")
	var total := 0
	for v in starving:
		total += v
	assert_eq(total, 10, "every adult gets a job")


func test_leader_succession() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, 200)
	var c: City = sim.cities.values()[0]
	var old_leader := c.leader_id
	sim.kill_unit(sim.units.slot_for(old_leader), "test")
	run_ticks(sim, SimConst.CITY_PLAN_INTERVAL + 1)
	assert_ne(c.leader_id, old_leader)
	assert_true(sim.units.is_alive_id(c.leader_id), "new leader alive")


func test_city_abandoned_when_town_hall_flooded() -> void:
	var sim := TestWorlds.flat(96)
	TestWorlds.add_band(sim, 40.5, 40.5, 6)
	run_ticks(sim, 200)
	var c: City = sim.cities.values()[0]
	var hall: Building = sim.buildings[c.buildings[0]]
	sim.apply_command({"op": "stroke_begin"})
	sim.apply_command({"op": "brush", "power": "paint_ocean", "x": hall.x, "y": hall.y, "radius": 3})
	sim.apply_command({"op": "stroke_end"})
	sim.step()
	assert_eq(sim.cities.size(), 0, "city abandoned")
	for s in sim.units.capacity:
		if sim.units.alive[s] == 1:
			assert_eq(sim.units.city[s], SimConst.CITY_NONE, "survivors are nomads again")
	assert_no_violations(sim, "after flood")
