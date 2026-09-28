extends TestCase

const ROOT := "user://test_saves"


func _mgr() -> SaveManager:
	return SaveManager.new(ROOT)


func _cleanup(m: SaveManager) -> void:
	for meta in m.list_slots():
		m.delete_slot(meta["slot"])


func test_roundtrip_preserves_state_exactly() -> void:
	var m := _mgr()
	var sim := Simulation.create_new(11, 128, 128, "island")
	run_ticks(sim, 2500)
	var before := sim.state_hash()
	var r := m.save_slot(sim, "rt_test")
	assert_true(r["ok"], "save ok: %s" % r["msg"])
	var l := m.load_slot("rt_test")
	assert_true(l["ok"], "load ok: %s" % l.get("msg", ""))
	if not l["ok"]:
		return
	var sim2: Simulation = l["sim"]
	assert_eq(sim2.state_hash(), before, "state hash identical after reload")
	assert_eq(sim2.units.count, sim.units.count)
	assert_eq(sim2.cities.size(), sim.cities.size())
	assert_no_violations(sim2, "loaded world")
	_cleanup(m)


func test_loaded_world_continues_identically() -> void:
	var m := _mgr()
	var sim := Simulation.create_new(12, 128, 128, "island")
	run_ticks(sim, 1500)
	m.save_slot(sim, "cont_test")
	var l := m.load_slot("cont_test")
	var sim2: Simulation = l["sim"]
	run_ticks(sim, 1500)
	run_ticks(sim2, 1500)
	assert_eq(sim2.state_hash(), sim.state_hash(), "original and reloaded worlds evolve identically")
	_cleanup(m)


func test_corruption_is_detected() -> void:
	var m := _mgr()
	var sim := Simulation.create_new(13, 64, 64, "island")
	run_ticks(sim, 100)
	m.save_slot(sim, "corrupt_test")
	var path := m.slot_dir("corrupt_test").path_join("world.sav")
	var bytes := FileAccess.get_file_as_bytes(path)
	# Flip one payload byte.
	var bad := bytes.duplicate()
	bad[bad.size() - 10] = bad[bad.size() - 10] ^ 0xFF
	_write(path, bad)
	var l := m.load_slot("corrupt_test")
	assert_false(l["ok"], "flipped byte rejected")
	assert_true(str(l["msg"]).contains("checksum"), "reports checksum: " + str(l["msg"]))
	# Truncation.
	_write(path, bytes.slice(0, bytes.size() / 2))
	assert_false(m.load_slot("corrupt_test")["ok"], "truncated rejected")
	# Bad magic.
	var magic := bytes.duplicate()
	magic[0] = 0x58
	_write(path, magic)
	assert_true(str(m.load_slot("corrupt_test")["msg"]).contains("magic"), "bad magic rejected")
	# Garbage.
	_write(path, PackedByteArray([1, 2, 3]))
	assert_false(m.load_slot("corrupt_test")["ok"], "garbage rejected")
	_cleanup(m)


func test_newer_schema_is_rejected_and_migration_gate() -> void:
	var r := SaveMigrations.migrate({"schema": Simulation.SAVE_SCHEMA + 1})
	assert_false(r["ok"], "future schema rejected")
	var r0 := SaveMigrations.migrate({"schema": 0})
	assert_false(r0["ok"], "unknown old schema rejected")
	var ok := SaveMigrations.migrate({"schema": Simulation.SAVE_SCHEMA})
	assert_true(ok["ok"], "current schema passes")


func test_slots_metadata_thumbnails_and_autosave_rotation() -> void:
	var m := _mgr()
	_cleanup(m)
	var sim := Simulation.create_new(14, 64, 64, "island")
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color.DARK_GREEN)
	assert_true(m.save_slot(sim, "slot_a", img)["ok"])
	run_ticks(sim, 50)
	assert_true(m.save_slot(sim, "slot_b")["ok"])
	var slots := m.list_slots()
	assert_eq(slots.size(), 2, "two slots listed")
	var meta := m.read_meta("slot_a")
	assert_eq(int(meta.get("seed", -1)), 14, "meta seed")
	assert_eq(int(meta.get("schema", -1)), Simulation.SAVE_SCHEMA, "meta schema")
	assert_true(FileAccess.file_exists(m.thumbnail_path("slot_a")), "thumbnail written")
	assert_false(SaveManager.valid_slot_name("../evil"), "path traversal rejected")
	assert_false(m.save_slot(sim, "../evil")["ok"], "invalid slot refused")
	var used := {}
	for k in 3:
		var s := m.next_autosave_slot()
		assert_false(used.has(s), "autosave rotates to a fresh slot")
		used[s] = true
		m.save_slot(sim, s)
		OS.delay_msec(1100)
	_cleanup(m)


func _write(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()
