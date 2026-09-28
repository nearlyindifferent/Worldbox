extends SceneTree
## Long autonomous run with decade reports for emergent-behaviour review.
##   godot --headless --path . -s res://tools/longrun.gd -- <years> <seed> <size> [shape] [humans=1]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var years := int(a[0]) if a.size() > 0 else 100
	var seed_v := int(a[1]) if a.size() > 1 else 1
	var size := int(a[2]) if a.size() > 2 else 192
	var shape: String = a[3] if a.size() > 3 else "island"
	var humans := (a[4] != "0") if a.size() > 4 else true
	var sim := Simulation.create_new(seed_v, size, size, shape)
	if not humans:
		for s in sim.units.capacity:
			if sim.units.alive[s] == 1 and sim.units.species[s] == sim.human_species:
				sim.kill_unit(s, "removed")
	var founded := sim.cities.size()
	var seen := {}
	for c: City in sim.cities.values(): seen[c.id] = true
	var t0 := Time.get_ticks_msec()
	for y in years:
		for k in SimConst.TICKS_PER_YEAR:
			sim.step()
		for c: City in sim.cities.values():
			if not seen.has(c.id):
				seen[c.id] = true
				founded += 1
		if (y + 1) % 10 == 0:
			var maxpop := 0
			for c: City in sim.cities.values(): maxpop = maxi(maxpop, c.population())
			var land := 0
			var forest := 0
			for i in sim.world.size:
				if sim.world.is_walkable(i):
					land += 1
					if sim.world.biome[i] == Defs.forest_index: forest += 1
			var nomads := 0
			for s in sim.units.capacity:
				if sim.units.alive[s] == 1 and sim.units.species[s] == sim.human_species and sim.units.city[s] == SimConst.CITY_NONE: nomads += 1
			var ev := {}
			for e: Dictionary in sim.history.major:
				ev[int(e["kind"])] = int(ev.get(int(e["kind"]), 0)) + 1
			var wars := 0
			for p: Dictionary in sim.realm.pairs.values():
				if p["war"]: wars += 1
			print("Y%3d humans %4d nomads %3d sheep %4d wolves %3d cities %2d kingdoms %2d wars %d | declared %d peace %d conquered %d rebellions %d fallen %d battle-dead %d | maxpop %3d starved %d tick %.2fms" % [sim.year(), sim.count_species(0), nomads, sim.count_species(1), sim.count_species(sim.wolf_species), sim.cities.size(), sim.kingdoms.size(), wars,
				int(ev.get(HistoryLog.Kind.WAR_DECLARED, 0)), int(ev.get(HistoryLog.Kind.PEACE, 0)), int(ev.get(HistoryLog.Kind.CITY_CONQUERED, 0)), int(ev.get(HistoryLog.Kind.REBELLION, 0)), int(ev.get(HistoryLog.Kind.KINGDOM_FALLEN, 0)),
				sim.count_deaths("battle", "human"), maxpop, sim.count_deaths("starvation", "human"), sim.timings.get("tick_total", 0) / 1000.0])
	var errs := SimInvariants.check(sim)
	print("invariants: ", "OK" if errs.is_empty() else str(errs.slice(0, 3)), "  wall ", (Time.get_ticks_msec() - t0) / 1000, "s")
	quit()
