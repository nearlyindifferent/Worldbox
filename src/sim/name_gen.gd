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


static func city_name(def: Defs.SpeciesDef, rng: SimRng, taken: Dictionary) -> String:
	var cn: Dictionary = def.raw.get("city_names", {})
	for attempt in 20:
		var n: String = str(rng.pick(cn["prefix"])) + str(rng.pick(cn["suffix"]))
		if not taken.has(n):
			return n
	return "%s %d" % [rng.pick(cn["prefix"]), taken.size() + 1]
