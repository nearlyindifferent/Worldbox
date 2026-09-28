class_name WorldGrid
extends RefCounted
## Authoritative tile state stored as structure-of-arrays (one packed array per
## field) for cache-friendly iteration and cheap serialization.

var width: int
var height: int
var size: int
var chunks_x: int
var chunks_y: int

var elevation := PackedFloat32Array()   ## 0..1, sea level ≈ 0.40
var biome := PackedByteArray()          ## Defs biome index
var moisture := PackedFloat32Array()    ## 0..1
var temperature := PackedFloat32Array() ## degrees C (approximate)
var vegetation := PackedByteArray()     ## grazing biomass, or crop maturity on farmland
var wood := PackedByteArray()           ## remaining timber on wooded tiles
var owner := PackedInt32Array()         ## owning city id or CITY_NONE
var building := PackedInt32Array()      ## building id occupying tile or BUILDING_ID_NONE
var variant := PackedByteArray()        ## cosmetic random variant, fixed at generation

## Render/derived-state dirtiness. Bumped whenever any tile in a chunk changes.
var chunk_rev := PackedInt32Array()
var owner_rev: int = 0
## Tiles whose walkability changed since last drain (consumed by the pathfinder).
var walk_changed := PackedInt32Array()
## Tiles whose walking cost changed (pathfinder weights only; not saved, drained each tick).
var cost_changed := PackedInt32Array()


func _init(w: int = 0, h: int = 0) -> void:
	if w > 0 and h > 0:
		allocate(w, h)


func allocate(w: int, h: int) -> void:
	width = w
	height = h
	size = w * h
	chunks_x = ceili(float(w) / SimConst.CHUNK)
	chunks_y = ceili(float(h) / SimConst.CHUNK)
	elevation.resize(size)
	biome.resize(size)
	moisture.resize(size)
	temperature.resize(size)
	vegetation.resize(size)
	wood.resize(size)
	owner.resize(size)
	owner.fill(SimConst.CITY_NONE)
	building.resize(size)
	building.fill(SimConst.BUILDING_ID_NONE)
	variant.resize(size)
	chunk_rev.resize(chunks_x * chunks_y)


func idx(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func chunk_of(i: int) -> int:
	@warning_ignore("integer_division")
	return ((i / width) / SimConst.CHUNK) * chunks_x + (i % width) / SimConst.CHUNK


func mark_dirty(i: int) -> void:
	chunk_rev[chunk_of(i)] += 1


func is_walkable(i: int) -> bool:
	return Defs.biome_walkable[biome[i]] == 1


func is_walkable_xy(x: int, y: int) -> bool:
	return in_bounds(x, y) and Defs.biome_walkable[biome[y * width + x]] == 1


func is_water(i: int) -> bool:
	return Defs.biome_water[biome[i]] == 1


func fertility(i: int) -> float:
	return Defs.biome_fertility[biome[i]] * (0.55 + 0.45 * moisture[i])


## Changes a tile's biome while keeping dependent fields consistent.
func set_biome(i: int, b: int) -> void:
	var old := biome[i]
	if old == b:
		return
	biome[i] = b
	var def: Defs.BiomeDef = Defs.biomes[b]
	wood[i] = def.wood
	var vmax := def.veg_max
	if b == Defs.farmland_index:
		vegetation[i] = 0
	elif vegetation[i] > vmax:
		vegetation[i] = vmax
	if Defs.biome_walkable[old] != Defs.biome_walkable[b]:
		walk_changed.append(i)
	elif Defs.biome_move_cost[old] != Defs.biome_move_cost[b]:
		cost_changed.append(i)
	mark_dirty(i)


func set_owner(i: int, city_id: int) -> void:
	if owner[i] != city_id:
		owner[i] = city_id
		owner_rev += 1
		mark_dirty(i)


func drain_walk_changes() -> PackedInt32Array:
	var out := walk_changed
	walk_changed = PackedInt32Array()
	return out


## Nearest walkable tile to (x, y) within radius, or -1.
func nearest_walkable(x: int, y: int, radius: int) -> int:
	if is_walkable_xy(x, y):
		return idx(x, y)
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				if is_walkable_xy(x + dx, y + dy):
					return idx(x + dx, y + dy)
	return -1
