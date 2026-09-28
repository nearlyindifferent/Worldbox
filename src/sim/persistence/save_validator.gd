class_name SaveValidator
extends RefCounted
## Structural validation of a (migrated) save dictionary BEFORE it is turned into a
## Simulation. Save files are untrusted input: every size, type and index that later
## code relies on is checked here, and world dimensions are bounded so a tiny file
## cannot request a huge allocation. Returns "" when valid, else a reason.

const MAX_WORLD_DIM := 2048
const MIN_WORLD_DIM := 16
const MAX_UNITS := 2000000
const MAX_CITIES := 100000
const MAX_BUILDINGS := 2000000

const WORLD_FIELDS := {
	"elevation": TYPE_PACKED_FLOAT32_ARRAY, "biome": TYPE_PACKED_BYTE_ARRAY, "moisture": TYPE_PACKED_FLOAT32_ARRAY,
	"temperature": TYPE_PACKED_FLOAT32_ARRAY, "vegetation": TYPE_PACKED_BYTE_ARRAY, "wood": TYPE_PACKED_BYTE_ARRAY,
	"owner": TYPE_PACKED_INT32_ARRAY, "building": TYPE_PACKED_INT32_ARRAY, "variant": TYPE_PACKED_BYTE_ARRAY,
}
const UNIT_TYPES := {
	"id": TYPE_PACKED_INT64_ARRAY, "alive": TYPE_PACKED_BYTE_ARRAY, "species": TYPE_PACKED_INT32_ARRAY,
	"sex": TYPE_PACKED_BYTE_ARRAY, "x": TYPE_PACKED_FLOAT32_ARRAY, "y": TYPE_PACKED_FLOAT32_ARRAY,
	"birth_tick": TYPE_PACKED_INT64_ARRAY, "death_age": TYPE_PACKED_INT64_ARRAY, "health": TYPE_PACKED_FLOAT32_ARRAY,
	"max_health": TYPE_PACKED_FLOAT32_ARRAY, "hunger": TYPE_PACKED_FLOAT32_ARRAY, "state": TYPE_PACKED_BYTE_ARRAY,
	"task": TYPE_PACKED_BYTE_ARRAY, "task_target": TYPE_PACKED_INT32_ARRAY, "task_timer": TYPE_PACKED_INT32_ARRAY,
	"job": TYPE_PACKED_BYTE_ARRAY, "city": TYPE_PACKED_INT32_ARRAY, "home": TYPE_PACKED_INT32_ARRAY,
	"mother": TYPE_PACKED_INT64_ARRAY, "father": TYPE_PACKED_INT64_ARRAY, "carry_type": TYPE_PACKED_BYTE_ARRAY,
	"carry_amount": TYPE_PACKED_FLOAT32_ARRAY, "next_think": TYPE_PACKED_INT64_ARRAY, "last_birth_tick": TYPE_PACKED_INT64_ARRAY,
	"flags": TYPE_PACKED_INT32_ARRAY, "kills": TYPE_PACKED_INT32_ARRAY, "look": TYPE_PACKED_INT32_ARRAY,
	"name": TYPE_PACKED_STRING_ARRAY, "path_pos": TYPE_PACKED_INT32_ARRAY,
}
const TOP_KEYS := {
	"schema": TYPE_INT, "seed": TYPE_INT, "shape": TYPE_STRING, "tick": TYPE_INT, "rng_state": TYPE_INT,
	"world": TYPE_DICTIONARY, "units": TYPE_DICTIONARY, "cities": TYPE_ARRAY, "buildings": TYPE_ARRAY,
	"next_city_id": TYPE_INT, "next_building_id": TYPE_INT, "laws": TYPE_DICTIONARY, "history": TYPE_DICTIONARY,
	"decisions": TYPE_DICTIONARY, "stats": TYPE_DICTIONARY, "month_births": TYPE_INT, "month_deaths": TYPE_INT,
	"deaths_by_cause": TYPE_DICTIONARY, "total_births": TYPE_INT, "total_deaths": TYPE_INT, "deceased": TYPE_DICTIONARY,
	"pop_milestone": TYPE_INT, "civ_state": TYPE_DICTIONARY, "components": TYPE_DICTIONARY, "undo": TYPE_ARRAY,
	"kingdoms": TYPE_ARRAY, "next_kingdom_id": TYPE_INT, "realm": TYPE_DICTIONARY,
}


static func validate(d: Dictionary) -> String:
	Defs.ensure_loaded()
	for k: String in TOP_KEYS:
		if not d.has(k):
			return "missing '%s'" % k
		if typeof(d[k]) != TOP_KEYS[k]:
			return "'%s' has the wrong type" % k
	if int(d["tick"]) < 0:
		return "negative tick"
	var err := _world(d["world"])
	if err != "":
		return err
	var wd: Dictionary = d["world"]
	var size := int(wd["w"]) * int(wd["h"])
	err = _units(d["units"], size, int(wd["w"]), int(wd["h"]))
	if err != "":
		return err
	if (d["cities"] as Array).size() > MAX_CITIES or (d["buildings"] as Array).size() > MAX_BUILDINGS:
		return "too many cities/buildings"
	for c: Variant in d["cities"]:
		err = _city(c, size)
		if err != "":
			return err
	for b: Variant in d["buildings"]:
		err = _building(b, int(wd["w"]), int(wd["h"]))
		if err != "":
			return err
	for kd: Variant in d["kingdoms"]:
		if typeof(kd) != TYPE_DICTIONARY:
			return "kingdom entry is not a dictionary"
		for k: String in ["id", "species", "color_index", "capital", "ruler_id", "parent", "founded_tick"]:
			if typeof(kd.get(k)) != TYPE_INT:
				return "kingdom.%s missing" % k
		if typeof(kd.get("cities")) != TYPE_PACKED_INT32_ARRAY or int(kd["color_index"]) < 0 or int(kd["color_index"]) >= AssetForge.CITY_COLORS.size():
			return "kingdom data invalid"
	if typeof((d["realm"] as Dictionary).get("pairs")) != TYPE_DICTIONARY:
		return "diplomacy data missing"
	var comp: Dictionary = d["components"]
	if typeof(comp.get("labels")) != TYPE_PACKED_INT32_ARRAY or not ((comp["labels"] as PackedInt32Array).size() in [0, size]):
		return "bad component labels"
	return ""


static func _world(wd: Dictionary) -> String:
	if typeof(wd.get("w")) != TYPE_INT or typeof(wd.get("h")) != TYPE_INT:
		return "world size missing"
	var w := int(wd["w"])
	var h := int(wd["h"])
	if w < MIN_WORLD_DIM or h < MIN_WORLD_DIM or w > MAX_WORLD_DIM or h > MAX_WORLD_DIM:
		return "world size %dx%d out of range" % [w, h]
	for f: String in WORLD_FIELDS:
		if typeof(wd.get(f)) != WORLD_FIELDS[f]:
			return "world.%s has the wrong type" % f
		if wd[f].size() != w * h:
			return "world.%s has %d cells, expected %d" % [f, wd[f].size(), w * h]
	var nb := Defs.biomes.size()
	var biome: PackedByteArray = wd["biome"]
	for i in biome.size():
		if biome[i] >= nb:
			return "invalid biome index %d at tile %d" % [biome[i], i]
	return ""


static func _units(ud: Dictionary, world_size: int, w: int, h: int) -> String:
	if typeof(ud.get("capacity")) != TYPE_INT:
		return "units.capacity missing"
	var cap := int(ud["capacity"])
	if cap < 0 or cap > MAX_UNITS:
		return "units.capacity out of range"
	for f: String in UNIT_TYPES:
		if typeof(ud.get(f)) != UNIT_TYPES[f]:
			return "units.%s has the wrong type" % f
		if ud[f].size() != cap:
			return "units.%s size mismatch" % f
	if typeof(ud.get("free")) != TYPE_PACKED_INT32_ARRAY or typeof(ud.get("children")) != TYPE_DICTIONARY or typeof(ud.get("path")) != TYPE_DICTIONARY:
		return "units bookkeeping missing"
	for s in ud["free"]:
		if s < 0 or s >= cap:
			return "free slot out of range"
	var alive: PackedByteArray = ud["alive"]
	var species: PackedInt32Array = ud["species"]
	var job: PackedByteArray = ud["job"]
	var state: PackedByteArray = ud["state"]
	var task: PackedByteArray = ud["task"]
	var carry: PackedByteArray = ud["carry_type"]
	var xs: PackedFloat32Array = ud["x"]
	var ys: PackedFloat32Array = ud["y"]
	for s in cap:
		if alive[s] == 0:
			continue
		if species[s] < 0 or species[s] >= Defs.species.size():
			return "unit slot %d has invalid species" % s
		if job[s] >= Defs.jobs.size() or state[s] >= UnitStore.State.size() or task[s] >= UnitStore.Task.size() or carry[s] >= UnitStore.RESOURCE_NAMES.size():
			return "unit slot %d has an invalid enum value" % s
		if not (xs[s] >= 0.0 and ys[s] >= 0.0 and xs[s] < w and ys[s] < h):
			return "unit slot %d is outside the world" % s
	var paths: Dictionary = ud["path"]
	for k: Variant in paths:
		if typeof(k) != TYPE_INT or int(k) < 0 or int(k) >= cap or typeof(paths[k]) != TYPE_PACKED_INT32_ARRAY:
			return "invalid path entry"
		for t in paths[k]:
			if t < 0 or t >= world_size:
				return "path tile out of range"
	return ""


static func _city(c: Variant, world_size: int) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return "city entry is not a dictionary"
	for k: String in ["id", "species", "center", "founded_tick", "color_index", "kingdom", "joined_tick", "last_famine_tick"]:
		if typeof(c.get(k)) != TYPE_INT:
			return "city.%s missing" % k
	for k: String in ["members", "territory", "fields", "buildings"]:
		if not (typeof(c.get(k)) in [TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_INT32_ARRAY]):
			return "city.%s missing" % k
	if typeof(c.get("storage")) != TYPE_DICTIONARY:
		return "city.storage missing"
	for res in City.RESOURCES:
		if not (typeof((c["storage"] as Dictionary).get(res)) in [TYPE_FLOAT, TYPE_INT]):
			return "city storage '%s' missing" % res
	if int(c["center"]) < 0 or int(c["center"]) >= world_size:
		return "city center out of range"
	if int(c["color_index"]) < 0 or int(c["color_index"]) >= AssetForge.CITY_COLORS.size():
		return "city color out of range"
	if int(c["species"]) < 0 or int(c["species"]) >= Defs.species.size():
		return "city species invalid"
	for k: String in ["territory", "fields"]:
		for t in c[k]:
			if t < 0 or t >= world_size:
				return "city %s tile out of range" % k
	return ""


static func _building(b: Variant, w: int, h: int) -> String:
	if typeof(b) != TYPE_DICTIONARY:
		return "building entry is not a dictionary"
	for k: String in ["id", "type", "city", "x", "y"]:
		if typeof(b.get(k)) != TYPE_INT:
			return "building.%s missing" % k
	var t := int(b["type"])
	if t < 0 or t >= Defs.buildings.size():
		return "building type invalid"
	var sz := (Defs.buildings[t] as Defs.BuildingDef).size
	if int(b["x"]) < 0 or int(b["y"]) < 0 or int(b["x"]) + sz > w or int(b["y"]) + sz > h:
		return "building footprint outside the world"
	return ""
