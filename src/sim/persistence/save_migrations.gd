class_name SaveMigrations
extends RefCounted
## Forward-only schema migrations for world saves. To change the save format:
##   1. bump Simulation.SAVE_SCHEMA,
##   2. add a static function here converting schema N-1 dictionaries to schema N,
##   3. register it in STEPS,
##   4. keep the old golden fixture in tests/fixtures and add a new one
##      (tests/unit/test_save_fixtures.gd fails if to_dict changes without a bump).

## from_schema -> method name that upgrades a dict from that schema to from_schema+1
const STEPS := {1: "_v1_to_v2"}


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


## Schema 2 added: landmass component labels, persisted undo history, settler/
## construction bookkeeping in civ_state, and species-qualified death causes.
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	d["components"] = {"labels": PackedInt32Array(), "dirty": true, "built": -1000000}
	d["undo"] = []
	if not d.has("civ_state") or typeof(d["civ_state"]) != TYPE_DICTIONARY:
		d["civ_state"] = {}
	var causes := {}
	var old: Dictionary = d.get("deaths_by_cause", {})
	for k: String in old:
		causes[k if k.contains(": ") else "unknown: " + k] = old[k]
	d["deaths_by_cause"] = causes
	return d
