class_name NameGen
extends RefCounted
## Syllable-based name generation driven by species data.


static func person_name(def: Defs.SpeciesDef, rng: SimRng) -> String:
	var syl: Dictionary = def.raw.get("name_syllables", {})
	if syl.is_empty():
		return def.name
	var n: String = rng.pick(syl["first"])
	if rng.chance(0.45):
		n += rng.pick(syl["mid"])
	n += rng.pick(syl["last"])
	return n.capitalize()


## Town names draw on the land around the site: coasts, forests, hills, lakes,
## snow, deserts and marshes each have their own word pools, mixed with a
## general pool; prefixes already used by other towns are avoided.
static func city_name(def: Defs.SpeciesDef, rng: SimRng, taken: Dictionary, features: PackedStringArray = PackedStringArray()) -> String:
	var cn: Dictionary = def.raw.get("city_names", {})
	var prefixes: Array = (cn["prefix"] as Array).duplicate()
	var suffixes: Array = (cn["suffix"] as Array).duplicate()
	for f in features:
		if cn.has(f + "_prefix"):
			for k in 3:
				prefixes.append_array(cn[f + "_prefix"])
		if cn.has(f + "_suffix"):
			for k in 3:
				suffixes.append_array(cn[f + "_suffix"])
	var used := {}
	for n: String in taken:
		for p: String in prefixes:
			if n.begins_with(p):
				used[p] = true
	for attempt in 30:
		var pre: String = rng.pick(prefixes)
		if used.has(pre) and attempt < 20:
			continue
		var suf: String = rng.pick(suffixes)
		if pre.to_lower().ends_with(suf.substr(0, 1)) and attempt < 25:
			continue
		var n := pre + suf
		if not taken.has(n):
			return n
	return "%s %d" % [rng.pick(prefixes), taken.size() + 1]


static func realm_name(def: Defs.SpeciesDef, rng: SimRng, capital: String, ruler: String) -> String:
	var cn: Dictionary = def.raw.get("city_names", {})
	if ruler != "" and rng.chance(0.3):
		return str(rng.pick(cn.get("dynasty_forms", ["House of %s"]))) % ruler
	return str(rng.pick(cn.get("realm_forms", ["Kingdom of %s"]))) % capital
