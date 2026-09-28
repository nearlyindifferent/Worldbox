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
	"name": TYPE_PACKED_STRING_ARRAY, "path_pos": TYPE_PACKED_INT32_ARRAY, "disease": TYPE_PACKED_INT32_ARRAY, "traits": TYPE_PACKED_INT32_ARRAY,
}
const TOP_KEYS := {
	"schema": TYPE_INT, "seed": TYPE_INT, "shape": TYPE_STRING, "tick": TYPE_INT, "rng_state": TYPE_INT,
	"world": TYPE_DICTIONARY, "units": TYPE_DICTIONARY, "cities": TYPE_ARRAY, "buildings": TYPE_ARRAY,
	"next_city_id": TYPE_INT, "next_building_id": TYPE_INT, "laws": TYPE_DICTIONARY, "history": TYPE_DICTIONARY,
	"decisions": TYPE_DICTIONARY, "stats": TYPE_DICTIONARY, "month_births": TYPE_INT, "month_deaths": TYPE_INT,
	"deaths_by_cause": TYPE_DICTIONARY, "total_births": TYPE_INT, "total_deaths": TYPE_INT, "deceased": TYPE_DICTIONARY,
	"pop_milestone": TYPE_INT, "civ_state": TYPE_DICTIONARY, "components": TYPE_DICTIONARY, "undo": TYPE_ARRAY,
	"kingdoms": TYPE_ARRAY, "next_kingdom_id": TYPE_INT, "realm": TYPE_DICTIONARY, "disasters": TYPE_DICTIONARY, "ages": TYPE_DICTIONARY,
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
	err = _disasters(d["disasters"], size, int(wd["w"]), int(wd["h"]))
	if err != "":
		return err
	# Id counters must exceed every id in use, or new objects would overwrite old ones.
	for pair: Array in [["next_city_id", d["cities"]], ["next_building_id", d["buildings"]], ["next_kingdom_id", d["kingdoms"]]]:
		for e: Dictionary in pair[1]:
			if int(e["id"]) >= int(d[pair[0]]):
				return "%s does not exceed id %d" % [pair[0], int(e["id"])]
	var ud2: Dictionary = d["units"]
	if typeof(ud2.get("next_id")) != TYPE_INT:
		return "units.next_id missing"
	var alive2: PackedByteArray = ud2["alive"]
	var ids2: PackedInt64Array = ud2["id"]
	for s in alive2.size():
		if alive2[s] == 1 and ids2[s] >= int(ud2["next_id"]):
			return "units.next_id does not exceed id %d" % ids2[s]
	var free_seen := {}
	for s in ud2["free"]:
		if free_seen.has(s) or alive2[s] == 1:
			return "free list holds a living or repeated slot"
		free_seen[s] = true
	var voy: Variant = (d["civ_state"] as Dictionary).get("voyages")
	if typeof(voy) != TYPE_DICTIONARY:
		return "voyages missing"
	for k: Variant in voy:
		var route: Variant = voy[k]
		if typeof(k) != TYPE_INT or typeof(route) != TYPE_PACKED_INT32_ARRAY or (route as PackedInt32Array).size() != 3:
			return "voyage entry invalid"
		for t in route:
			if t < 0 or t >= size:
				return "voyage tile out of range"
	var ag: Dictionary = d["ages"]
	for k: String in ["current", "since", "until"]:
		if typeof(ag.get(k)) != TYPE_INT:
			return "ages.%s missing" % k
	if int(ag["current"]) < 0 or int(ag["current"]) >= AgeSystem.AGES.size() or int(ag["until"]) < int(ag["since"]):
		return "ages data invalid"
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
		if typeof(kd.get("name")) != TYPE_STRING or not (typeof(kd.get("exhaustion")) in [TYPE_FLOAT, TYPE_INT]) or not is_finite(float(kd["exhaustion"])):
			return "kingdom data invalid"
		var seen_c := {}
		for cid in kd["cities"]:
			if seen_c.has(cid):
				return "kingdom lists a city twice"
			seen_c[cid] = true
	if typeof((d["realm"] as Dictionary).get("pairs")) != TYPE_DICTIONARY:
		return "diplomacy data missing"
	err = _pairs((d["realm"] as Dictionary)["pairs"], d["kingdoms"])
	if err != "":
		return err
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


## Every diplomatic record must be well formed and refer to two living kingdoms.
static func _pairs(pairs: Dictionary, kingdoms: Array) -> String:
	var ids := {}
	for kd: Dictionary in kingdoms:
		ids[int(kd["id"])] = true
	for key: Variant in pairs:
		var p: Variant = pairs[key]
		if typeof(key) != TYPE_STRING or typeof(p) != TYPE_DICTIONARY:
			return "diplomacy record invalid"
		for k: String in ["a", "b", "war_start", "last_peace"]:
			if typeof((p as Dictionary).get(k)) != TYPE_INT:
				return "diplomacy record missing %s" % k
		for k: String in ["opinion", "grievance"]:
			if not (typeof((p as Dictionary).get(k)) in [TYPE_FLOAT, TYPE_INT]) or not is_finite(float(p[k])):
				return "diplomacy record missing %s" % k
		if typeof((p as Dictionary).get("war")) != TYPE_BOOL or typeof((p as Dictionary).get("reasons")) != TYPE_ARRAY:
			return "diplomacy record invalid"
		for k: String in ["casualties", "month_cas", "targets", "cities_lost"]:
			var arr: Variant = (p as Dictionary).get(k)
			if typeof(arr) != TYPE_ARRAY or (arr as Array).size() != 2:
				return "diplomacy record %s invalid" % k
			for v: Variant in arr:
				if typeof(v) != TYPE_INT:
					return "diplomacy record %s invalid" % k
		var a := int(p["a"])
		var b := int(p["b"])
		if a >= b or not ids.has(a) or not ids.has(b) or str(key) != "%d:%d" % [a, b]:
			return "diplomacy record refers to unknown kingdoms"
		if p.has("last_capture") and typeof(p["last_capture"]) != TYPE_INT:
			return "diplomacy record invalid"
	return ""


static func _disasters(dd: Dictionary, world_size: int, w: int, h: int) -> String:
	for k: String in ["burning", "fuel", "lava", "lava_t", "lava_flow"]:
		if typeof(dd.get(k)) != TYPE_PACKED_INT32_ARRAY:
			return "disasters.%s missing" % k
	if (dd["burning"] as PackedInt32Array).size() != (dd["fuel"] as PackedInt32Array).size():
		return "disasters fire lists mismatch"
	var nl := (dd["lava"] as PackedInt32Array).size()
	if (dd["lava_t"] as PackedInt32Array).size() != nl or (dd["lava_flow"] as PackedInt32Array).size() != nl:
		return "disasters lava lists mismatch"
	if (dd["burning"] as PackedInt32Array).size() > DisasterSystem.MAX_BURNING or nl > world_size:
		return "too many burning tiles"
	var seen := {}
	for i in dd["burning"]:
		if i < 0 or i >= world_size or seen.has(i):
			return "burning tile out of range or duplicated"
		seen[i] = true
	for f in dd["fuel"]:
		if f < 1 or f > DisasterSystem.MAX_FUEL:
			return "fire fuel out of range"
	var seen_l := {}
	for i in dd["lava"]:
		if i < 0 or i >= world_size or seen_l.has(i):
			return "lava tile out of range or duplicated"
		seen_l[i] = true
	for t in dd["lava_t"]:
		if t < 0 or t > DisasterSystem.LAVA_COOL_STEPS:
			return "lava timer out of range"
	for f in dd["lava_flow"]:
		if f < 0 or f > DisasterSystem.MAX_LAVA_FLOW:
			return "lava flow out of range"
	if typeof(dd.get("quakes")) != TYPE_ARRAY or typeof(dd.get("last_record")) != TYPE_DICTIONARY:
		return "disasters bookkeeping missing"
	if (dd["quakes"] as Array).size() > DisasterSystem.MAX_QUAKES:
		return "too many quakes"
	for q: Variant in dd["quakes"]:
		if typeof(q) != TYPE_DICTIONARY:
			return "quake entry invalid"
		for k: String in ["x", "y", "r", "left"]:
			if typeof((q as Dictionary).get(k)) != TYPE_INT:
				return "quake.%s missing" % k
		if int(q["r"]) < 0 or int(q["r"]) > 64 or int(q["left"]) < 0 or int(q["left"]) > DisasterSystem.QUAKE_TICKS:
			return "quake out of range"
		if int(q["x"]) < 0 or int(q["y"]) < 0 or int(q["x"]) >= w or int(q["y"]) >= h:
			return "quake out of the world"
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
	var disease: PackedInt32Array = ud["disease"]
	var traits: PackedInt32Array = ud["traits"]
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
		if disease[s] < 0 or disease[s] > DisasterSystem.PLAGUE_TICKS or traits[s] < 0 or traits[s] >= (1 << Traits.INFO.size()):
			return "unit slot %d has invalid plague or trait data" % s
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
	if not (typeof(c.get("loyalty")) in [TYPE_FLOAT, TYPE_INT]) or not is_finite(float(c["loyalty"])):
		return "city.loyalty invalid"
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
