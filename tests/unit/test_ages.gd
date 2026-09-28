extends TestCase
## World ages (Feature A).


func test_ages_turn_and_are_chronicled() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	var first := sim.ages.current
	sim.ages.until = sim.tick + SimConst.TICKS_PER_MONTH
	run_ticks(sim, SimConst.TICKS_PER_MONTH * 2)
	assert_ne(sim.ages.current, first, "a new age began")
	var years := float(sim.ages.until - sim.ages.since) / SimConst.TICKS_PER_YEAR
	assert_between(years, AgeSystem.MIN_YEARS, AgeSystem.MAX_YEARS, "ages last 20-40 years")
	var logged := false
	for e: Dictionary in sim.history.major:
		if str(e["text"]).contains(str(sim.ages.age()["name"])):
			logged = true
	assert_true(logged, "the new age is in the chronicle")


func test_green_years_grow_crops_faster_than_the_long_winter() -> void:
	var grown := {}
	for id: String in ["green", "winter"]:
		var sim := TestWorlds.flat(64)
		sim.laws.set_law("natural_disasters", false)
		sim.apply_command({"op": "set_world_age", "age": id})
		var w := sim.world
		var tiles := PackedInt32Array()
		for x in range(20, 30):
			var i := w.idx(x, 20)
			w.set_biome(i, Defs.farmland_index)
			w.vegetation[i] = 0
			w.wood[i] = SimConst.SOIL_MAX
			tiles.append(i)
		run_ticks(sim, SimConst.VEG_CYCLE_TICKS * 2)
		var total := 0
		for i in tiles:
			total += w.vegetation[i]
		grown[id] = total
	note("crop growth green %d vs winter %d" % [grown["green"], grown["winter"]])
	assert_true(int(grown["green"]) > int(grown["winter"]) * 1.5, "green years outgrow the long winter")


func test_restless_years_sour_relations() -> void:
	var sim := TestWorlds.flat(128)
	var a := TestWorlds.add_band(sim, 30.5, 60.5, 10)
	var b := TestWorlds.add_band(sim, 70.5, 60.5, 10)
	sim.civ.found_city(a[0], sim.world.idx(30, 60), [])
	sim.civ.found_city(b[0], sim.world.idx(70, 60), [])
	sim.apply_command({"op": "set_world_age", "age": "restless"})
	run_ticks(sim, SimConst.TICKS_PER_MONTH + 1)
	var labels := []
	for p: Dictionary in sim.realm.pairs.values():
		for r: Array in p["reasons"]:
			labels.append(r[0])
	assert_true("restless times" in labels, "restless times appear among the reasons: %s" % str(labels))


func test_law_off_freezes_the_age_and_its_effects() -> void:
	var sim := TestWorlds.flat(64)
	sim.apply_command({"op": "set_world_age", "age": "ember"})
	sim.laws.set_law("world_ages", false)
	assert_eq(sim.ages.factor("fire"), 1.0, "no age effects while the law is off")
	sim.ages.until = sim.tick
	var cur := sim.ages.current
	run_ticks(sim, SimConst.TICKS_PER_MONTH * 2)
	assert_eq(sim.ages.current, cur, "ages do not turn while the law is off")


func test_age_state_survives_clone() -> void:
	var sim := TestWorlds.flat(64)
	sim.apply_command({"op": "set_world_age", "age": "pale"})
	run_ticks(sim, 50)
	var copy := sim.clone()
	assert_eq(copy.ages.current, sim.ages.current)
	run_ticks(sim, 400)
	run_ticks(copy, 400)
	assert_eq(copy.state_hash(), sim.state_hash())
