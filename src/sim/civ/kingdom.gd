class_name Kingdom
extends RefCounted
## A realm of one or more cities under one ruler. Diplomatic state between two
## kingdoms lives in KingdomSystem.pairs (one record per unordered pair).

var id: int
var name: String
var species: int
var color_index: int
var capital: int = -1           ## city id
var ruler_id: int = SimConst.UNIT_NONE
var parent: int = -1            ## kingdom this one split from or was colonised from (-1 none)
var founded_tick: int
var cities := PackedInt32Array()
var exhaustion: float = 0.0     ## war weariness 0..100
var alive: bool = true


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "species": species, "color_index": color_index, "capital": capital,
		"ruler_id": ruler_id, "parent": parent, "founded_tick": founded_tick, "cities": cities,
		"exhaustion": exhaustion, "alive": alive}


static func from_dict(d: Dictionary) -> Kingdom:
	var k := Kingdom.new()
	for key: String in d:
		k.set(key, d[key])
	return k
