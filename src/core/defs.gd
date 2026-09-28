class_name Defs
extends RefCounted
## Data-driven definition registry. Loads JSON under res://data once and exposes
## typed, index-addressable definitions. Indices are stable on-disk ids.

class BiomeDef:
	var id: String
	var index: int
	var name: String
	var water: bool
	var walkable: bool
	var move_cost: float
	var fertility: float
	var veg_max: int
	var veg_food: float
	var wood: int
	var pattern: String
	var colors: PackedColorArray

class SpeciesDef:
	var id: String
	var index: int
	var name: String
	var sapient: bool
	var speed: float
	var max_health: float
	var damage: float
	var lifespan_min: float
	var lifespan_max: float
	var adult_age: float
	var fertile_min: float
	var fertile_max: float
	var hunger_rate: float
	var birth_cooldown_years: float
	var litter_min: int
	var litter_max: int
	var sprite: String
	var raw: Dictionary

class BuildingDef:
	var id: String
	var index: int
	var name: String
	var size: int
	var housing: int
	var storage: bool
	var cost: Dictionary
	var work: int
	var max_health: float
	var sprite: String
	var desc: String
	var raw: Dictionary

class JobDef:
	var id: String
	var index: int
	var name: String
	var resource: String
	var work_ticks: int
	var yield_amount: float
	var search_radius: int
	var raw: Dictionary

static var _loaded: bool = false
static var biomes: Array[BiomeDef] = []
static var species: Array[SpeciesDef] = []
static var buildings: Array[BuildingDef] = []
static var jobs: Array[JobDef] = []
static var building_globals: Dictionary = {}
static var _biome_by_id: Dictionary = {}
static var _species_by_id: Dictionary = {}
static var _building_by_id: Dictionary = {}
static var _job_by_id: Dictionary = {}

## Per-biome lookup tables for hot loops (indexed by biome index).
static var biome_walkable: PackedByteArray = PackedByteArray()
static var biome_water: PackedByteArray = PackedByteArray()
static var biome_fertility: PackedFloat32Array = PackedFloat32Array()
static var biome_veg_max: PackedInt32Array = PackedInt32Array()
static var biome_move_cost: PackedFloat32Array = PackedFloat32Array()
## Frequently used biome indices, resolved once at load.
static var farmland_index: int = -1
static var grassland_index: int = -1
static var forest_index: int = -1
static var hills_index: int = -1
static var mountain_index: int = -1


static func ensure_loaded() -> void:
	if _loaded:
		return
	_load_biomes()
	_load_species()
	_load_buildings()
	_load_jobs()
	_loaded = true


static func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Defs: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Defs: invalid JSON in %s" % path)
		return {}
	return parsed


static func _load_biomes() -> void:
	var d := _read_json("res://data/biomes.json")
	var list: Array = d.get("biomes", [])
	var max_index := 0
	for e: Dictionary in list:
		max_index = maxi(max_index, int(e["index"]))
	biomes.resize(max_index + 1)
	biome_walkable.resize(max_index + 1)
	biome_water.resize(max_index + 1)
	biome_fertility.resize(max_index + 1)
	biome_veg_max.resize(max_index + 1)
	biome_move_cost.resize(max_index + 1)
	for e: Dictionary in list:
		var b := BiomeDef.new()
		b.id = e["id"]
		b.index = int(e["index"])
		b.name = e["name"]
		b.water = bool(e["water"])
		b.walkable = bool(e["walkable"])
		b.move_cost = float(e["move_cost"])
		b.fertility = float(e["fertility"])
		b.veg_max = int(e["veg_max"])
		b.veg_food = float(e["veg_food"])
		b.wood = int(e["wood"])
		b.pattern = e["pattern"]
		for c: String in e["colors"]:
			b.colors.append(Color.html(c))
		biomes[b.index] = b
		_biome_by_id[b.id] = b
		biome_walkable[b.index] = 1 if b.walkable else 0
		biome_water[b.index] = 1 if b.water else 0
		biome_fertility[b.index] = b.fertility
		biome_veg_max[b.index] = b.veg_max
		biome_move_cost[b.index] = b.move_cost
	farmland_index = (_biome_by_id["farmland"] as BiomeDef).index
	grassland_index = (_biome_by_id["grassland"] as BiomeDef).index
	forest_index = (_biome_by_id["forest"] as BiomeDef).index
	hills_index = (_biome_by_id["hills"] as BiomeDef).index
	mountain_index = (_biome_by_id["mountain"] as BiomeDef).index


static func _load_species() -> void:
	var d := _read_json("res://data/species.json")
	for e: Dictionary in d.get("species", []):
		var s := SpeciesDef.new()
		s.id = e["id"]
		s.index = int(e["index"])
		s.name = e["name"]
		s.sapient = bool(e["sapient"])
		s.speed = float(e["speed"])
		s.max_health = float(e["max_health"])
		s.damage = float(e["damage"])
		s.lifespan_min = float(e["lifespan"][0])
		s.lifespan_max = float(e["lifespan"][1])
		s.adult_age = float(e["adult_age"])
		s.fertile_min = float(e["fertile_age"][0])
		s.fertile_max = float(e["fertile_age"][1])
		s.hunger_rate = float(e["hunger_rate"])
		s.birth_cooldown_years = float(e["birth_cooldown_years"])
		s.litter_min = int(e["litter"][0])
		s.litter_max = int(e["litter"][1])
		s.sprite = e["sprite"]
		s.raw = e
		if species.size() <= s.index:
			species.resize(s.index + 1)
		species[s.index] = s
		_species_by_id[s.id] = s


static func _load_buildings() -> void:
	var d := _read_json("res://data/buildings.json")
	for e: Dictionary in d.get("buildings", []):
		var b := BuildingDef.new()
		b.id = e["id"]
		b.index = int(e["index"])
		b.name = e["name"]
		b.size = int(e["size"])
		b.housing = int(e["housing"])
		b.storage = bool(e["storage"])
		b.cost = e["cost"]
		b.work = int(e["work"])
		b.max_health = float(e["max_health"])
		b.sprite = e["sprite"]
		b.desc = e.get("desc", "")
		b.raw = e
		if buildings.size() <= b.index:
			buildings.resize(b.index + 1)
		buildings[b.index] = b
		_building_by_id[b.id] = b
	for k: String in d.keys():
		if k.begins_with("base_"):
			building_globals[k] = d[k]


static func _load_jobs() -> void:
	var d := _read_json("res://data/jobs.json")
	for e: Dictionary in d.get("jobs", []):
		var j := JobDef.new()
		j.id = e["id"]
		j.index = int(e["index"])
		j.name = e["name"]
		j.resource = e["resource"]
		j.work_ticks = int(e["work_ticks"])
		j.yield_amount = float(e["yield"])
		j.search_radius = int(e.get("search_radius", 0))
		j.raw = e
		if jobs.size() <= j.index:
			jobs.resize(j.index + 1)
		jobs[j.index] = j
		_job_by_id[j.id] = j


static func biome(id: String) -> BiomeDef:
	ensure_loaded()
	return _biome_by_id[id]


static func biome_index(id: String) -> int:
	ensure_loaded()
	return (_biome_by_id[id] as BiomeDef).index


static func species_by_id(id: String) -> SpeciesDef:
	ensure_loaded()
	return _species_by_id[id]


static func building_by_id(id: String) -> BuildingDef:
	ensure_loaded()
	return _building_by_id[id]


static func job_by_id(id: String) -> JobDef:
	ensure_loaded()
	return _job_by_id[id]
