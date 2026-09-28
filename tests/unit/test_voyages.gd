extends TestCase
## Settlers crossing the sea to another landmass.


## Two islands separated by a strait; a crowded town on the west island.
func _two_islands() -> Simulation:
	var sim := TestWorlds.flat(128)
	sim.laws.set_law("natural_disasters", false)
	var w := sim.world
	for y in range(3, 125):
		for x in range(3, 125):
			var west := x >= 8 and x < 24 and y >= 56 and y < 72
			var east := x >= 60 and x < 120 and y >= 10 and y < 118
			if not west and not east:
				w.set_biome(w.idx(x, y), Defs.biome_index("shallow"))
	sim._init_systems()
	sim.pathfinder.rebuild_components()
	return sim


func test_crowded_coastal_town_sends_settlers_overseas() -> void:
	var sim := _two_islands()
	var band := TestWorlds.add_band(sim, 15.5, 63.5, 12)
	var c := sim.civ.found_city(band[0], sim.world.idx(15, 63), [])
	for k in 20:
		var s := sim.spawn_unit(sim.human_species, 14.5 + (k % 5) * 0.5, 62.5 + (k / 5) * 0.5, 22.0)
		sim.units.sex[s] = k % 2
		sim.civ.join_city(s, c)
	for mid in c.members:
		sim.units.set_flag(sim.units.slot_for(mid), UnitStore.Flag.INVULNERABLE, true)
	sim.spatial.rebuild(sim.units)
	var voyage := sim.civ._plan_voyage(c)
	assert_false(voyage.is_empty(), "a crossing to the east island was found")
	if voyage.is_empty():
		return
	assert_ne(sim.pathfinder.component_of(voyage[1]), sim.pathfinder.component_of(c.center), "the landing is on another landmass")
	sim.civ._last_settlers.clear()
	var before := sim.cities.size()
	var sailed := false
	for m in 60:
		for k in SimConst.TICKS_PER_MONTH:
			sim.step()
			if not sailed:
				for s in sim.units.capacity:
					if sim.units.alive[s] == 1 and sim.units.has_flag(s, UnitStore.Flag.SAILING):
						sailed = true
						break
		if sim.cities.size() > before:
			break
	assert_true(sailed, "settlers took to the water")
	var east := false
	for other: City in sim.cities.values():
		note("town %s at (%d, %d)" % [other.name, other.center % sim.world.width, other.center / sim.world.width])
		if other.center % sim.world.width >= 58:
			east = true
	assert_true(east, "a town was founded on the east island")
	assert_no_violations(sim, "after the voyage")
