class_name SaveMigrations
extends RefCounted
## Forward-only schema migrations for world saves. To change the save format:
##   1. bump Simulation.SAVE_SCHEMA,
##   2. add a static function here converting schema N-1 dictionaries to schema N,
##   3. register it in STEPS,
##   4. keep the old golden fixture in tests/fixtures and add a new one
##      (tests/unit/test_save_fixtures.gd fails if to_dict changes without a bump).

## from_schema -> method name that upgrades a dict from that schema to from_schema+1
const STEPS := {1: "_v1_to_v2", 2: "_v2_to_v3", 3: "_v3_to_v4", 4: "_v4_to_v5", 5: "_v5_to_v6", 6: "_v6_to_v7"}


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


## Schema 3 added kingdoms and diplomacy: every existing city becomes the capital of
## its own kingdom (as if each had been founded by an independent band).
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	var kingdoms: Array = []
	var next_id := 1
	var forms := ["Kingdom of %s"]
	for c: Dictionary in d["cities"]:
		var kid := next_id
		next_id += 1
		c["kingdom"] = kid
		c["loyalty"] = 100.0
		kingdoms.append({"id": kid, "name": forms[0] % str(c.get("name", "?")), "species": int(c.get("species", 0)),
			"color_index": int(c.get("color_index", 0)), "capital": int(c["id"]), "ruler_id": int(c.get("leader_id", -1)),
			"parent": -1, "founded_tick": int(c.get("founded_tick", 0)), "cities": PackedInt32Array([int(c["id"])]),
			"exhaustion": 0.0, "alive": true})
	d["kingdoms"] = kingdoms
	d["next_kingdom_id"] = next_id
	d["realm"] = {"pairs": {}}
	var cs: Dictionary = d.get("civ_state", {})
	if not cs.has("settler_origin"):
		cs["settler_origin"] = {}
	d["civ_state"] = cs
	return d


## Schema 4 added per-city kingdom tenure (rebellion grace), famine rate limiting,
## the disaster system (fire, lava, quakes) and per-unit plague state.
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	var ud: Dictionary = d["units"]
	var dis := PackedInt32Array()
	dis.resize(int(ud.get("capacity", 0)))
	ud["disease"] = dis
	d["disasters"] = {"burning": PackedInt32Array(), "fuel": PackedInt32Array(), "lava": PackedInt32Array(),
		"lava_t": PackedInt32Array(), "lava_flow": PackedInt32Array(), "quakes": [], "last_record": {}}
	for c: Dictionary in d["cities"]:
		c["joined_tick"] = int(c.get("founded_tick", 0))
		c["last_famine_tick"] = -1000000
	return d


## Schema 5 added heritable traits per unit. It also repairs saves from an early
## schema-4 build (before disasters existed) that lack disaster and disease data.
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	var ud: Dictionary = d["units"]
	var cap := int(ud.get("capacity", 0))
	var zeros := PackedInt32Array()
	zeros.resize(cap)
	if not ud.has("disease"):
		ud["disease"] = zeros.duplicate()
	ud["traits"] = zeros.duplicate()
	if not d.has("disasters"):
		d["disasters"] = {"burning": PackedInt32Array(), "fuel": PackedInt32Array(), "lava": PackedInt32Array(),
			"lava_t": PackedInt32Array(), "lava_flow": PackedInt32Array(), "quakes": [], "last_record": {}}
	for c: Dictionary in d["cities"]:
		if not c.has("joined_tick"):
			c["joined_tick"] = int(c.get("founded_tick", 0))
		if not c.has("last_famine_tick"):
			c["last_famine_tick"] = -1000000
	return d


## Schema 6 added world ages; older worlds start in the Quiet Years.
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	var t := int(d.get("tick", 0))
	d["ages"] = {"current": 0, "since": t, "until": t + AgeSystem.MIN_YEARS * SimConst.TICKS_PER_YEAR}
	return d


## Schema 7 added settler sea voyages (civ_state.voyages).
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	(d["civ_state"] as Dictionary)["voyages"] = {}
	return d
