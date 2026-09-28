extends SceneTree
## Cross-process persistence check: loads <slot> from <root> in a fresh process,
## advances <ticks>, prints "HASH <hash>" and, if <out_file> is given, writes the hash
## there. Used by tests/unit/test_save_fixtures.gd.
## Args: <root> <slot> <ticks> [command_json|-] [out_file]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var m := SaveManager.new(a[0])
	var r := m.load_slot(a[1])
	if not r["ok"]:
		print("LOADFAIL ", r["msg"])
		quit(2)
		return
	var sim: Simulation = r["sim"]
	if a.size() > 3 and a[3] != "-":
		sim.apply_command(JSON.parse_string(a[3]))
	for k in int(a[2]):
		sim.step()
	var h := sim.state_hash()
	print("HASH ", h)
	if a.size() > 4:
		var f := FileAccess.open(a[4], FileAccess.WRITE)
		f.store_string(h)
		f.close()
	quit()
