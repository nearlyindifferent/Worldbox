class_name SaveMigrations
extends RefCounted
## Forward-only schema migrations for world saves. To change the save format:
##   1. bump Simulation.SAVE_SCHEMA,
##   2. add a function here converting schema N-1 dictionaries to schema N,
##   3. register it in STEPS and add a fixture test in tests/unit/test_persistence.gd.

## from_schema -> method name that upgrades a dict from that schema to from_schema+1
const STEPS := {}


static func migrate(d: Dictionary) -> Dictionary:
	var schema := int(d.get("schema", -1))
	if schema < 1:
		return {"ok": false, "msg": "Unknown save schema %d" % schema}
	if schema > Simulation.SAVE_SCHEMA:
		return {"ok": false, "msg": "Save schema %d is newer than this build (%d)" % [schema, Simulation.SAVE_SCHEMA]}
	while schema < Simulation.SAVE_SCHEMA:
		if not STEPS.has(schema):
			return {"ok": false, "msg": "No migration from schema %d" % schema}
		d = Callable(SaveMigrations, STEPS[schema]).call(d)
		schema += 1
		d["schema"] = schema
	return {"ok": true, "data": d}
