extends TestCase
## Long-running and randomized ("fuzz") simulations. Slow; skipped with --skip-slow.

const POWERS := ["raise", "lower", "paint_ocean", "paint_grass", "paint_forest", "paint_mountain",
	"paint_sand", "spawn_human", "spawn_sheep", "smite", "bless"]


func test_slow_fuzz_with_random_god_actions() -> void:
	var sim := Simulation.create_new(777, 160, 160, "island")
	var fuzz := RandomNumberGenerator.new()
	fuzz.seed = 4242
	var checks := 0
	for t in 30000:
		if t % 150 == 0:
			var p: String = POWERS[fuzz.randi_range(0, POWERS.size() - 1)]
			sim.apply_command({"op": "stroke_begin"})
			sim.apply_command({"op": "brush", "power": p, "x": fuzz.randi_range(0, 159), "y": fuzz.randi_range(0, 159), "radius": fuzz.randi_range(0, 6)})
			sim.apply_command({"op": "stroke_end"})
			if fuzz.randf() < 0.1:
				sim.apply_command({"op": "undo"})
		sim.step()
		if t % 2000 == 0:
			checks += 1
			if not assert_no_violations(sim, "tick %d" % sim.tick):
				return
	assert_no_violations(sim, "final")
	note("after %d ticks: units %d cities %d history %d/%d decisions %d" % [sim.tick, sim.units.count, sim.cities.size(), sim.history.major.size(), sim.history.minor.size(), sim.decisions.entries.size()])
	assert_true(sim.history.minor.size() <= HistoryLog.MINOR_CAP)
	assert_true(sim.decisions.entries.size() <= DecisionLog.CAP)
	assert_true(sim.command_log.size() <= Simulation.COMMAND_LOG_CAP)


func test_slow_hundred_thousand_ticks_autonomous() -> void:
	var sim := Simulation.create_new(2024, 160, 160, "island")
	var mem0 := OS.get_static_memory_usage()
	var peak_humans := 0
	for t in 100000:
		sim.step()
		if t % 10000 == 0:
			if not assert_no_violations(sim, "tick %d" % sim.tick):
				return
			peak_humans = maxi(peak_humans, sim.count_species(sim.human_species))
	var mem1 := OS.get_static_memory_usage()
	note("100k ticks (%d years): humans %d (peak %d) sheep %d cities %d; history major %d; mem %.1f -> %.1f MB" % [
		sim.year(), sim.count_species(sim.human_species), peak_humans, sim.count_species(sim.sheep_species),
		sim.cities.size(), sim.history.major.size(), mem0 / 1048576.0, mem1 / 1048576.0])
	assert_no_violations(sim, "final")
	assert_true(peak_humans > 20, "civilization emerged")
	for k: String in sim.stats:
		assert_true((sim.stats[k] as StatSeries).values.size() < StatSeries.CAPACITY, "stat %s bounded" % k)
	assert_true(sim.deceased.size() <= Simulation.DECEASED_CAP)
	assert_true(mem1 - mem0 < 256 * 1048576, "no runaway memory growth")
