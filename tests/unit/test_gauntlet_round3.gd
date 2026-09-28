extends TestCase
## Regressions for findings of Gauntlet round 3 (simulation critic).


func test_a_watchtower_raises_the_bar_but_does_not_make_a_town_invulnerable() -> void:
	var sim := TestWorlds.flat(128)
	var a := TestWorlds.add_band(sim, 30.5, 60.5, 10)
	var b := TestWorlds.add_band(sim, 80.5, 60.5, 10)
	sim.civ.found_city(a[0], sim.world.idx(30, 60), [])
	var target := sim.civ.found_city(b[0], sim.world.idx(80, 60), [])
	sim.civ._place_building(target, Defs.building_by_id("watchtower").index, 86, 60, true)
	var ka: Kingdom = sim.kingdoms[(sim.cities.values()[0] as City).kingdom]
	var kb: Kingdom = sim.kingdoms[target.kingdom]
	sim.realm.declare_war(ka, kb, [])
	for mid in target.members.duplicate():
		sim.kill_unit(sim.units.slot_for(mid), "test")
	var soldier := Defs.job_by_id("soldier").index
	var home: City = sim.cities[ka.capital]
	var w := sim.world.width
	for k in 4:
		var s := sim.spawn_unit(sim.human_species, target.center % w + 0.5 + k * 0.3, target.center / w + 1.5, 20.0)
		sim.civ.join_city(s, home)
		sim.units.job[s] = soldier
		sim.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	sim.spatial.rebuild(sim.units)
	sim.realm._sieges()
	assert_eq(target.kingdom, kb.id, "four attackers are not enough against a tower")
	for k in 4:
		var s := sim.spawn_unit(sim.human_species, target.center % w + 1.5 + k * 0.3, target.center / w + 0.5, 20.0)
		sim.civ.join_city(s, home)
		sim.units.job[s] = soldier
		sim.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	sim.spatial.rebuild(sim.units)
	sim.realm._sieges()
	assert_eq(sim.cities[target.id].kingdom if sim.cities.has(target.id) else ka.id, ka.id, "a larger army takes the town")


func test_losing_the_hall_but_keeping_a_granary_still_rebuilds_the_hall() -> void:
	var sim := TestWorlds.flat(96)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 12)
	var c := sim.civ.found_city(band[0], sim.world.idx(40, 40), [])
	sim.civ._place_building(c, Defs.building_by_id("granary").index, 46, 40, true)
	var hall := -1
	for bid in c.buildings:
		if (sim.buildings[bid] as Building).def().id == "town_hall":
			hall = bid
	sim.civ.destroy_building(hall, "test")
	assert_eq(sim.civ.count_complete(c, "town_hall"), 1, "a new hall stands")
	assert_ne(sim.world.building[c.center], SimConst.BUILDING_ID_NONE, "the centre is on a building")
	assert_no_violations(sim, "after rebuild")


func test_validator_rejects_stale_id_counters_and_bad_free_lists() -> void:
	var sim := Simulation.create_new(3, 64, 64, "island")
	for k in 200:
		sim.step()
	var base := sim.to_dict()
	var cases := {}
	var d1 := base.duplicate(true)
	d1["next_building_id"] = 1
	cases["building ids"] = d1
	var d2 := base.duplicate(true)
	d2["next_city_id"] = 1
	cases["city ids"] = d2
	var d3 := base.duplicate(true)
	(d3["units"] as Dictionary)["next_id"] = 1
	cases["unit ids"] = d3
	var d4 := base.duplicate(true)
	var fr := PackedInt32Array([0])
	(d4["units"] as Dictionary)["free"] = fr
	cases["living slot in free list"] = d4
	for name: String in cases:
		if name == "city ids" and (base["cities"] as Array).is_empty():
			continue
		assert_ne(SaveValidator.validate(cases[name]), "", "%s rejected" % name)
	assert_eq(SaveValidator.validate(base), "", "the untouched save is valid")


func test_compaction_remaps_fight_targets() -> void:
	var sim := TestWorlds.flat(64)
	for law in ["hunger", "natural_death", "reproduction", "animal_reproduction"]:
		sim.laws.set_law(law, false)
	var slots := PackedInt32Array()
	for k in 400:
		slots.append(sim.spawn_unit(sim.human_species, 10.5 + (k % 40), 10.5 + (k / 40), 20.0))
	for k in 399:
		if k % 2 == 0:
			sim.kill_unit(slots[k], "test")
	var fighter := slots[1]
	var foe := slots[399]
	sim.units.task[fighter] = UnitStore.Task.FIGHT
	sim.units.task_target[fighter] = foe
	var foe_id := sim.units.id[foe]
	sim.units.compact()
	var fs := -1
	for s in sim.units.capacity:
		if sim.units.alive[s] == 1 and sim.units.task[s] == UnitStore.Task.FIGHT:
			fs = s
	assert_true(fs >= 0)
	assert_eq(sim.units.task_target[fs], sim.units.slot_for(foe_id), "the fight target follows its unit")


func test_duplicate_copies_traits_and_health() -> void:
	var sim := TestWorlds.flat(64)
	var s := TestWorlds.add_band(sim, 20.5, 20.5, 1)[0]
	sim.units.traits[s] = (1 << Traits.STRONG) | (1 << Traits.WISE)
	sim.units.max_health[s] = 130.0
	var r := sim.apply_command({"op": "duplicate_unit", "id": sim.units.id[s]})
	var c := sim.units.slot_for(int(r["id"]))
	assert_eq(sim.units.traits[c], sim.units.traits[s])
	assert_eq(sim.units.max_health[c], 130.0)


func test_predators_and_hunters_spare_invulnerable_prey() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	var sheep := sim.spawn_unit(sim.sheep_species, 30.5, 30.5, 2.0)
	sim.units.set_flag(sheep, UnitStore.Flag.INVULNERABLE, true)
	var wolf := sim.spawn_unit(sim.wolf_species, 29.5, 30.5, 3.0)
	sim.units.hunger[wolf] = 70.0
	sim.spatial.rebuild(sim.units)
	run_ticks(sim, 120)
	assert_eq(sim.units.alive[sheep], 1, "the protected woolback lives")


func test_age_quakes_respect_the_disaster_law_and_ages_pause_when_off() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	sim.apply_command({"op": "set_world_age", "age": "restless"})
	var quakes := 0
	for m in 240:
		run_ticks(sim, SimConst.TICKS_PER_MONTH)
		quakes += sim.disasters.quakes.size()
		sim.ages.until = sim.tick + SimConst.TICKS_PER_YEAR
	assert_eq(quakes, 0, "no natural quakes while disasters are off")
	sim.laws.set_law("world_ages", false)
	var left := sim.ages.until - sim.tick
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 2)
	assert_eq(sim.ages.until - sim.tick, left, "the age's remaining time is frozen while ages are off")
	assert_false(sim.apply_command({"op": "set_world_age", "age": "green"})["ok"], "cannot set an age while ages are off")
	sim.laws.set_law("world_ages", true)
	assert_false(sim.apply_command({"op": "set_world_age", "age": "nonsense"})["ok"], "unknown ages are refused")
