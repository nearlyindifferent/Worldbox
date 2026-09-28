extends SceneTree
## Headless smoke run: generate, simulate, print a population/economy summary per year.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ticks := int(args[0]) if args.size() > 0 else 3600
	var seed_v := int(args[1]) if args.size() > 1 else 7
	var size := int(args[2]) if args.size() > 2 else 192
	var t0 := Time.get_ticks_msec()
	var sim := Simulation.create_new(seed_v, size, size, "island")
	print("gen ms ", Time.get_ticks_msec() - t0, " units ", sim.units.count)
	t0 = Time.get_ticks_msec()
	for k in ticks:
		sim.step()
		if sim.tick % SimConst.TICKS_PER_YEAR == 0:
			var houses := 0
			for b: Building in sim.buildings.values(): if b.complete: houses += 1
			var cs := PackedStringArray()
			for c: City in sim.cities.values():
				cs.append("%s p%d h%d f%.0f w%.0f s%.0f fields%d terr%d" % [c.name, c.population(), c.housing, c.storage["food"], c.storage["wood"], c.storage["stone"], c.fields.size(), c.territory.size()])
			print("Y%d humans=%d sheep=%d cities=%d bld=%d tick_ms=%.2f | %s" % [sim.year(), sim.count_species(0), sim.count_species(1), sim.cities.size(), houses, sim.timings.get("tick_total", 0) / 1000.0, "; ".join(cs)])
	var ms := Time.get_ticks_msec() - t0
	print("ran ", ticks, " ticks in ", ms, " ms (", 1000.0 * ticks / maxf(1, ms), " ticks/s)")
	print("deaths ", sim.deaths_by_cause, " births ", sim.total_births)
	print("timings ", sim.timings)
	quit()
