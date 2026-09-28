class_name TestCase
extends RefCounted
## Minimal assertion base for headless tests. Failures are recorded, not thrown,
## so one run reports every failing assertion.

var failures: PackedStringArray = PackedStringArray()
var current_test: String = ""
var notes: PackedStringArray = PackedStringArray()


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func note(msg: String) -> void:
	notes.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "expected true") -> bool:
	if not cond:
		fail(msg)
	return cond


func assert_false(cond: bool, msg: String = "expected false") -> bool:
	return assert_true(not cond, msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> bool:
	if typeof(a) != typeof(b) or a != b:
		fail("%s expected %s == %s" % [msg, str(b), str(a)])
		return false
	return true


func assert_ne(a: Variant, b: Variant, msg: String = "") -> bool:
	if typeof(a) == typeof(b) and a == b:
		fail("%s expected values to differ (%s)" % [msg, str(a)])
		return false
	return true


func assert_between(v: float, lo: float, hi: float, msg: String = "") -> bool:
	if v < lo or v > hi:
		fail("%s %f not in [%f, %f]" % [msg, v, lo, hi])
		return false
	return true


func assert_no_violations(sim: Simulation, context: String = "") -> bool:
	var errs := SimInvariants.check(sim)
	if errs.size() > 0:
		fail("%s invariant violations: %s" % [context, "; ".join(errs.slice(0, 5))])
		return false
	return true


static func run_ticks(sim: Simulation, n: int) -> void:
	for k in n:
		sim.step()
