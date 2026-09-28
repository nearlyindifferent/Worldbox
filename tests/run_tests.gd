extends SceneTree
## Headless test runner.
##   godot --headless --path . -s res://tests/run_tests.gd [-- <name-filter> ...] [--skip-slow]
## Discovers res://tests/unit/test_*.gd, runs every method named test_*, prints a
## summary and exits with code 1 on any failure. Methods named test_slow_* are
## skipped with --skip-slow.


var _logger := ScriptErrorLogger.new()


func _init() -> void:
	OS.add_logger(_logger)
	var args := OS.get_cmdline_user_args()
	var skip_slow := args.has("--skip-slow")
	var filters := PackedStringArray()
	for a in args:
		if not a.begins_with("--"):
			filters.append(a)
	Defs.ensure_loaded()
	var files := DirAccess.get_files_at("res://tests/unit")
	files.sort()
	var total := 0
	var failed := 0
	var all_failures := PackedStringArray()
	var t_all := Time.get_ticks_msec()
	for f in files:
		if not f.begins_with("test_") or not f.ends_with(".gd"):
			continue
		var script: GDScript = load("res://tests/unit/" + f)
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			if skip_slow and mname.begins_with("test_slow_"):
				continue
			var full := f.get_basename() + "." + mname
			if filters.size() > 0:
				var hit := false
				for flt in filters:
					if full.contains(flt):
						hit = true
				if not hit:
					continue
			var inst: TestCase = script.new()
			inst.current_test = full
			var t0 := Time.get_ticks_msec()
			var errors_before := _logger.script_errors
			inst.call(mname)
			if _logger.script_errors > errors_before:
				inst.fail("script error aborted the test: %s" % _logger.last_message)
			var ms := Time.get_ticks_msec() - t0
			total += 1
			for n in inst.notes:
				print("    note ", n)
			if inst.failures.is_empty():
				print("  PASS %s (%d ms)" % [full, ms])
			else:
				failed += 1
				print("  FAIL %s (%d ms)" % [full, ms])
				for msg in inst.failures:
					print("       ", msg)
					all_failures.append(msg)
	print("\n%d tests, %d failed, %.1f s" % [total, failed, (Time.get_ticks_msec() - t_all) / 1000.0])
	if failed > 0:
		print("FAILURES:\n  " + "\n  ".join(all_failures))
	quit(1 if failed > 0 or total == 0 else 0)
