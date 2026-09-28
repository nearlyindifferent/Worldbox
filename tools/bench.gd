extends SceneTree
## Headless simulation benchmarks (no rendering). Reproducible: fixed seeds.
##   godot --headless --path . -s res://tools/bench.gd [-- <scenario> ...]
## Prints a table and writes tools/out/bench.json.

const SCENARIOS := {
	"small": {"size": 192, "seed": 11, "warm": 3600, "measure": 1800},
	"medium": {"size": 256, "seed": 12, "warm": 3600, "measure": 1800},
	"large": {"size": 384, "seed": 13, "warm": 3600, "measure": 1200},
	"huge": {"size": 512, "seed": 14, "warm": 1800, "measure": 900},
	"dense": {"size": 256, "seed": 15, "warm": 3600, "measure": 1200, "extra_bands": 40, "extra_sheep": 600},
	"long": {"size": 256, "seed": 16, "warm": 36000, "measure": 1800},
}


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	var results := {}
	for name: String in SCENARIOS:
		if wanted.size() > 0 and not wanted.has(name):
			continue
		results[name] = _run(name, SCENARIOS[name])
		var r: Dictionary = results[name]
		print("%-7s %4dx%-4d gen %5d ms | units %5d cities %3d | tick p50 %.2f p95 %.2f max %.2f ms | %6.0f ticks/s | mem %.0f MB | save %d KB %d ms, load %d ms, roundtrip %s" % [
			name, r["size"], r["size"], r["gen_ms"], r["units"], r["cities"], r["p50"], r["p95"], r["max"], r["tps"],
			r["mem_mb"], r["save_kb"], r["save_ms"], r["load_ms"], "OK" if r["roundtrip"] else "MISMATCH"])
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	var f := FileAccess.open("res://tools/out/bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	quit()


func _run(_name: String, cfg: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sim := Simulation.create_new(int(cfg["seed"]), int(cfg["size"]), int(cfg["size"]), "island")
	var gen_ms := Time.get_ticks_msec() - t0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in int(cfg.get("extra_bands", 0)):
		var i := sim.world.nearest_walkable(rng.randi_range(0, sim.world.width - 1), rng.randi_range(0, sim.world.height - 1), 40)
		if i >= 0:
			sim.apply_command({"op": "brush", "power": "spawn_human", "x": i % sim.world.width, "y": i / sim.world.width, "radius": 8})
	for k in int(cfg.get("extra_sheep", 0)) / 5:
		var i := sim.world.nearest_walkable(rng.randi_range(0, sim.world.width - 1), rng.randi_range(0, sim.world.height - 1), 40)
		if i >= 0:
			sim.apply_command({"op": "brush", "power": "spawn_sheep", "x": i % sim.world.width, "y": i / sim.world.width, "radius": 8})
	for k in int(cfg["warm"]):
		sim.step()
	var samples := PackedFloat32Array()
	var tm := Time.get_ticks_usec()
	for k in int(cfg["measure"]):
		var a := Time.get_ticks_usec()
		sim.step()
		samples.append((Time.get_ticks_usec() - a) / 1000.0)
	var total_s := (Time.get_ticks_usec() - tm) / 1000000.0
	samples.sort()
	var mgr := SaveManager.new("user://bench_saves")
	var hash_before := sim.state_hash()
	var sr := mgr.save_slot(sim, "bench")
	var lr := mgr.load_slot("bench")
	var ok: bool = lr["ok"] and (lr["sim"] as Simulation).state_hash() == hash_before
	mgr.delete_slot("bench")
	return {
		"size": int(cfg["size"]), "gen_ms": gen_ms, "units": sim.units.count, "humans": sim.count_species(sim.human_species),
		"cities": sim.cities.size(), "buildings": sim.buildings.size(), "year": sim.year(),
		"p50": samples[samples.size() / 2], "p95": samples[int(samples.size() * 0.95)], "max": samples[samples.size() - 1],
		"tps": cfg["measure"] / maxf(total_s, 0.0001), "mem_mb": OS.get_static_memory_usage() / 1048576.0,
		"save_kb": int(sr.get("bytes", 0)) / 1024, "save_ms": int(sr.get("ms", 0)), "load_ms": int(lr.get("ms", 0)), "roundtrip": ok,
		"timings_us": sim.timings,
	}
