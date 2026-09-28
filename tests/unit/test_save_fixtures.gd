extends TestCase
## Persistence hardening (Gauntlet round 1, persistence critic D1–D5, D8–D9).

const ROOT := "user://test_fixture_saves"


func _mgr() -> SaveManager:
	return SaveManager.new(ROOT)


func _install_fixture(m: SaveManager, fixture: String, slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(m.slot_dir(slot))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/" + fixture), ProjectSettings.globalize_path(m.slot_dir(slot).path_join("world.sav")))


func _cleanup(m: SaveManager) -> void:
	var d := DirAccess.open(m.root)
	if d == null:
		return
	for name in d.get_directories():
		m.delete_slot(name)


## Wraps arbitrary payload bytes in a container with a VALID checksum, so tests
## exercise the payload validator rather than the checksum.
func _write_container(path: String, raw: PackedByteArray, claimed_raw_len: int = -1) -> void:
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(packed)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(SaveManager.MAGIC.to_ascii_buffer())
	f.store_32(SaveManager.CONTAINER_VERSION)
	f.store_32(Simulation.SAVE_SCHEMA)
	f.store_32(raw.size() if claimed_raw_len < 0 else claimed_raw_len)
	f.store_32(packed.size())
	f.store_buffer(ctx.finish())
	f.store_buffer(packed)
	f.close()


func test_schema1_golden_save_migrates_and_runs() -> void:
	var m := _mgr()
	_cleanup(m)
	_install_fixture(m, "schema1_seed5_96.sav", "old")
	var r := m.load_slot("old")
	assert_true(r["ok"], "schema-1 save loads: %s" % r.get("msg", ""))
	if not r["ok"]:
		return
	var sim: Simulation = r["sim"]
	assert_eq(sim.tick, 1500)
	assert_eq(sim.units.count, 71)
	assert_no_violations(sim, "migrated world")
	run_ticks(sim, 300)
	assert_no_violations(sim, "migrated world after 300 ticks")
	_cleanup(m)


func test_current_schema_golden_hash_is_stable() -> void:
	# Fails if to_dict()/from_dict() change without a SAVE_SCHEMA bump + new fixture.
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema%d_seed5_96.json" % Simulation.SAVE_SCHEMA))
	var m := _mgr()
	_cleanup(m)
	_install_fixture(m, "schema%d_seed5_96.sav" % Simulation.SAVE_SCHEMA, "cur")
	var r := m.load_slot("cur")
	assert_true(r["ok"], "current fixture loads")
	if r["ok"]:
		assert_eq((r["sim"] as Simulation).state_hash(), str(info["hash"]), "loaded state re-serializes identically")
		assert_true((r["sim"] as Simulation).editor.can_undo(), "undo history persisted")
	_cleanup(m)


func test_hostile_payloads_are_rejected_not_half_loaded() -> void:
	var m := _mgr()
	_cleanup(m)
	var base := Simulation.create_new(9, 64, 64, "island").to_dict()
	var cases := {}
	var d1 := base.duplicate(true)
	d1.erase("units")
	cases["missing_keys"] = d1
	var d2 := base.duplicate(true)
	d2["cities"] = "nope"
	cases["wrong_type"] = d2
	var d3 := base.duplicate(true)
	(d3["world"] as Dictionary)["w"] = 60000
	(d3["world"] as Dictionary)["h"] = 60000
	cases["huge_world"] = d3
	var d4 := base.duplicate(true)
	var b: PackedByteArray = (d4["world"] as Dictionary)["biome"]
	b[100] = 200
	(d4["world"] as Dictionary)["biome"] = b
	cases["bad_biome"] = d4
	var d5 := base.duplicate(true)
	(d5["world"] as Dictionary)["elevation"] = PackedFloat32Array([0.5])
	cases["short_arrays"] = d5
	var d6 := base.duplicate(true)
	var ux: PackedFloat32Array = (d6["units"] as Dictionary)["x"]
	for s in ux.size():
		ux[s] = 9999.0
	(d6["units"] as Dictionary)["x"] = ux
	cases["unit_out_of_world"] = d6
	for name: String in cases:
		DirAccess.make_dir_recursive_absolute(m.slot_dir(name))
		_write_container(m.slot_dir(name).path_join("world.sav"), var_to_bytes(cases[name]))
		var r := m.load_slot(name)
		assert_false(r["ok"], "%s rejected" % name)
		assert_false(r.has("sim"), "%s yields no simulation" % name)
	# Header lies about its size / decompression bomb.
	DirAccess.make_dir_recursive_absolute(m.slot_dir("liar"))
	_write_container(m.slot_dir("liar").path_join("world.sav"), var_to_bytes(base), SaveManager.MAX_RAW_BYTES + 1)
	assert_false(m.load_slot("liar")["ok"], "oversized raw length rejected before allocation")
	_cleanup(m)


func test_crash_during_save_is_recoverable() -> void:
	var m := _mgr()
	_cleanup(m)
	var sim := Simulation.create_new(10, 64, 64, "island")
	run_ticks(sim, 100)
	m.save_slot(sim, "crash")
	var dir := m.slot_dir("crash")
	# Crash between "old -> .bak" and "tmp -> final": only .bak remains.
	DirAccess.rename_absolute(dir.path_join("world.sav"), dir.path_join("world.sav.bak"))
	var r := m.load_slot("crash")
	assert_true(r["ok"] and bool(r.get("recovered", false)), "recovered from .bak")
	assert_eq(m.list_slots().size(), 1, "slot still listed")
	# Crash after the temp file was fully written but before rename.
	DirAccess.rename_absolute(dir.path_join("world.sav.bak"), dir.path_join("world.sav.tmp"))
	var r2 := m.load_slot("crash")
	assert_true(r2["ok"], "recovered from a complete .tmp")
	# A truncated temp file is not trusted.
	var bytes := FileAccess.get_file_as_bytes(dir.path_join("world.sav.tmp"))
	var f := FileAccess.open(dir.path_join("world.sav.tmp"), FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, bytes.size() / 2))
	f.close()
	assert_false(m.load_slot("crash")["ok"], "truncated temp rejected")
	_cleanup(m)


func test_slot_names_are_safe() -> void:
	for bad in ["../x", "a/b", "", "CON", "aux", "lpt1", "my save", "x".repeat(41)]:
		assert_false(SaveManager.valid_slot_name(bad), "rejects '%s'" % bad)
	var m := _mgr()
	assert_false(m.load_slot("../elsewhere/victim")["ok"], "load refuses traversal")
	assert_true(m.read_meta("../elsewhere/victim").is_empty(), "meta refuses traversal")


func test_commands_at_the_save_boundary_match_after_reload() -> void:
	for cmd: Dictionary in [{"op": "brush", "power": "smite", "x": 48, "y": 48, "radius": 10},
			{"op": "undo"}]:
		var sim := Simulation.create_new(12, 96, 96, "island")
		run_ticks(sim, 700)
		sim.apply_command({"op": "brush", "power": "raise", "x": 40, "y": 40, "radius": 4})
		var copy := sim.clone()
		assert_eq(copy.state_hash(), sim.state_hash())
		var ra := sim.apply_command(cmd)
		var rb := copy.apply_command(cmd)
		assert_eq(str(rb), str(ra), "same command result for %s" % cmd["op"])
		run_ticks(sim, 400)
		run_ticks(copy, 400)
		assert_eq(copy.state_hash(), sim.state_hash(), "same evolution after %s at the boundary" % cmd["op"])


func test_cross_process_save_load_continue() -> void:
	var m := _mgr()
	_cleanup(m)
	var sim := Simulation.create_new(13, 96, 96, "island")
	run_ticks(sim, 1200)
	assert_true(m.save_slot(sim, "xproc")["ok"])
	var cmd := {"op": "brush", "power": "smite", "x": 50, "y": 50, "radius": 8}
	sim.apply_command(cmd)
	run_ticks(sim, 600)
	var expected := sim.state_hash()
	# Non-blocking child with a result file: blocking capture of a Godot child's
	# stdout can deadlock on the pipe.
	var result := ProjectSettings.globalize_path("user://xproc_result.txt")
	if FileAccess.file_exists(result):
		DirAccess.remove_absolute(result)
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/xproc_continue.gd", "--", ROOT, "xproc", "600", JSON.stringify(cmd), result])
	assert_true(pid > 0, "child process started")
	var waited := 0
	while pid > 0 and OS.is_process_running(pid) and waited < 120000:
		OS.delay_msec(100)
		waited += 100
	if OS.is_process_running(pid):
		OS.kill(pid)
		fail("child process timed out")
	var got := FileAccess.get_file_as_string(result).strip_edges() if FileAccess.file_exists(result) else ""
	assert_eq(got, expected, "fresh process reproduces the uninterrupted world")
	_cleanup(m)
