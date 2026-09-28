extends TestCase
## Traits, heredity and predators (Feature T).


func test_traits_are_inherited() -> void:
	var sim := TestWorlds.flat(64)
	var parents := TestWorlds.add_band(sim, 20.5, 20.5, 2)
	var strong := 1 << Traits.STRONG
	sim.units.traits[parents[0]] = strong
	sim.units.traits[parents[1]] = strong
	var n := 0
	var with := 0
	for k in 200:
		var c := sim.spawn_unit(sim.human_species, 20.5, 20.5, 0.0, sim.units.id[parents[0]], sim.units.id[parents[1]])
		n += 1
		if Traits.has(sim.units.traits[c], Traits.STRONG):
			with += 1
		sim.kill_unit(c, "test")
	note("strong children %d / %d" % [with, n])
	assert_between(float(with) / n, 0.6, 0.9, "both-parent traits pass on about 3 times in 4")


func test_trait_effects() -> void:
	var sim := TestWorlds.flat(64)
	var a := TestWorlds.add_band(sim, 10.5, 20.5, 1)[0]
	var b := TestWorlds.add_band(sim, 10.5, 30.5, 1)[0]
	sim.units.traits[a] = 1 << Traits.SWIFT
	sim.units.traits[b] = 0
	for s in [a, b]:
		sim.units.set_flag(s, UnitStore.Flag.INVULNERABLE, true)
		sim.movement.go_to(s, sim.world.idx(50, int(sim.units.y[s])), false)
		sim.units.task[s] = UnitStore.Task.WANDER
	for k in 60:
		sim.movement.advance_all()
	assert_true(sim.units.x[a] > sim.units.x[b] + 1.5, "swift walkers outpace others (%.1f vs %.1f)" % [sim.units.x[a], sim.units.x[b]])
	# Strong creatures are born tougher.
	var tough := 0
	for k in 300:
		var s := sim.spawn_unit(sim.human_species, 30.5, 30.5, 20.0)
		if Traits.has(sim.units.traits[s], Traits.STRONG):
			assert_between(sim.units.max_health[s], 129.0, 131.0)
			tough += 1
		sim.kill_unit(s, "test")
	assert_true(tough > 5, "some people are born strong")


func test_just_and_greedy_are_exclusive() -> void:
	var rng := SimRng.new(3)
	for k in 2000:
		var m := Traits.roll(rng, true)
		assert_false(Traits.has(m, Traits.JUST) and Traits.has(m, Traits.GREEDY))
		assert_true(Traits.count(m) <= Traits.MAX_TRAITS)
	var animal := Traits.roll(rng, false)
	for k in 500:
		animal |= Traits.roll(rng, false)
	assert_false(Traits.has(animal, Traits.WISE) or Traits.has(animal, Traits.WARLIKE), "animals only get physical traits")


func test_wolves_hunt_sheep() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	for k in 12:
		sim.spawn_unit(sim.sheep_species, 30.5 + (k % 4), 30.5 + (k / 4), 2.0)
	var wolves := PackedInt32Array()
	for k in 3:
		var w := sim.spawn_unit(sim.wolf_species, 22.5 + k, 22.5, 3.0)
		sim.units.hunger[w] = 60.0
		wolves.append(w)
	sim.spatial.rebuild(sim.units)
	run_ticks(sim, 300)
	var eaten := sim.count_deaths("eaten by wolves", "sheep")
	note("sheep eaten %d" % eaten)
	assert_true(eaten >= 2, "wolves caught sheep")
	assert_no_violations(sim, "after the hunt")


func test_starving_wolf_attacks_a_lone_person_not_a_crowd() -> void:
	var sim := TestWorlds.flat(64)
	sim.laws.set_law("natural_disasters", false)
	var lone := TestWorlds.add_band(sim, 40.5, 40.5, 1)[0]
	sim.units.set_flag(lone, UnitStore.Flag.FROZEN, true)
	var w := sim.spawn_unit(sim.wolf_species, 36.5, 40.5, 3.0)
	sim.units.hunger[w] = 95.0
	sim.spatial.rebuild(sim.units)
	var hp0 := sim.units.health[lone]
	run_ticks(sim, 120)
	var hurt := sim.units.alive[lone] == 0 or sim.units.health[lone] < hp0
	assert_true(hurt, "a starving wolf attacked the lone traveller")
	# A crowd is left alone.
	var sim2 := TestWorlds.flat(64)
	sim2.laws.set_law("natural_disasters", false)
	var crowd := TestWorlds.add_band(sim2, 40.5, 40.5, 6)
	for s in crowd:
		sim2.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	var w2 := sim2.spawn_unit(sim2.wolf_species, 36.5, 40.5, 3.0)
	sim2.units.hunger[w2] = 95.0
	sim2.spatial.rebuild(sim2.units)
	run_ticks(sim2, 120)
	var dmg := 0.0
	for s in crowd:
		dmg += sim2.units.max_health[s] - sim2.units.health[s]
	assert_true(dmg < 1.0, "wolves avoid groups of people (damage %.1f)" % dmg)
