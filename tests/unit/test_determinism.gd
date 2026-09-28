extends TestCase


func test_same_seed_same_history() -> void:
	var a := Simulation.create_new(99, 128, 128, "island")
	var b := Simulation.create_new(99, 128, 128, "island")
	assert_eq(a.state_hash(), b.state_hash(), "identical at tick 0")
	run_ticks(a, 3000)
	run_ticks(b, 3000)
	assert_eq(a.state_hash(), b.state_hash(), "identical after 3000 ticks")


func test_same_commands_same_outcome() -> void:
	var a := Simulation.create_new(5, 96, 96, "island")
	var b := Simulation.create_new(5, 96, 96, "island")
	var script := [
		[100, {"op": "brush", "power": "raise", "x": 40, "y": 40, "radius": 4}],
		[300, {"op": "brush", "power": "spawn_human", "x": 48, "y": 48, "radius": 6}],
		[600, {"op": "brush", "power": "smite", "x": 50, "y": 50, "radius": 2}],
		[900, {"op": "brush", "power": "paint_forest", "x": 30, "y": 50, "radius": 3}],
	]
	for sim: Simulation in [a, b]:
		var k := 0
		for t in 1500:
			while k < script.size() and int(script[k][0]) == sim.tick:
				sim.apply_command(script[k][1])
				k += 1
			sim.step()
	assert_eq(a.state_hash(), b.state_hash(), "command replay deterministic")


func test_tick_rate_independent_of_frame_batching() -> void:
	# The presentation layer may run many ticks in one frame at high speed;
	# logic must not depend on how ticks are batched.
	var a := Simulation.create_new(21, 96, 96, "island")
	var b := Simulation.create_new(21, 96, 96, "island")
	run_ticks(a, 1000)
	for batch in 100:
		run_ticks(b, 10)
	assert_eq(a.state_hash(), b.state_hash())


func test_different_seeds_diverge() -> void:
	var a := Simulation.create_new(1, 96, 96, "island")
	var b := Simulation.create_new(2, 96, 96, "island")
	assert_ne(a.state_hash(), b.state_hash())
