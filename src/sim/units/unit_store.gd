class_name UnitStore
extends RefCounted
## Structure-of-arrays storage for every living creature. Slots are recycled via
## a free list; stable 64-bit ids (never reused) map to slots through `slot_of`.
## Systems iterate slots 0..capacity-1 and skip dead ones, which keeps iteration
## order deterministic.

enum State { IDLE, MOVING, WORKING, EATING, FLEEING, DEAD }
## Append new values at the end: task ids are stored in saves.
enum Task { NONE, WANDER, FORAGE, GRAZE, FARM, CHOP, QUARRY, BUILD, DELIVER, EAT_STORE, HUNT, GO_HOME, FOUND_CITY, SEEK_LAND, FOLLOW, FIGHT, MARCH, FLEE }
enum Flag { FROZEN = 1, INVULNERABLE = 2, FAVORITE = 4, SETTLER = 8, IMMUNE = 16 }
const TASK_NAMES := ["None", "Wandering", "Foraging", "Grazing", "Farming", "Chopping wood", "Quarrying stone", "Building", "Delivering goods", "Eating from stores", "Hunting", "Going home", "Founding a settlement", "Seeking dry land", "Following", "Fighting", "Marching to war", "Fleeing"]
const SEX_MALE := 0
const SEX_FEMALE := 1

var capacity: int = 0
var count: int = 0
var next_id: int = 1

var id := PackedInt64Array()
var alive := PackedByteArray()
var species := PackedInt32Array()
var sex := PackedByteArray()
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var prev_x := PackedFloat32Array() ## presentation interpolation only; not part of logic
var prev_y := PackedFloat32Array()
var birth_tick := PackedInt64Array()
var death_age := PackedInt64Array() ## age in ticks at which natural death occurs
var health := PackedFloat32Array()
var max_health := PackedFloat32Array()
var hunger := PackedFloat32Array()
var state := PackedByteArray()
var task := PackedByteArray()
var task_target := PackedInt32Array() ## tile index, building id or unit slot depending on task
var task_timer := PackedInt32Array()
var job := PackedByteArray()
var city := PackedInt32Array()
var home := PackedInt32Array()
var mother := PackedInt64Array()
var father := PackedInt64Array()
var carry_type := PackedByteArray() ## 0 none, 1 food, 2 wood, 3 stone
var carry_amount := PackedFloat32Array()
var next_think := PackedInt64Array()
var last_birth_tick := PackedInt64Array()
var flags := PackedInt32Array()
var kills := PackedInt32Array()
var look := PackedInt32Array() ## packed cosmetic genes: skin/hair/wool indices
var disease := PackedInt32Array() ## plague ticks remaining (0 = healthy)
var traits := PackedInt32Array() ## Traits bitmask
var name := PackedStringArray()

var slot_of: Dictionary = {} ## id -> slot
var _free: PackedInt32Array = PackedInt32Array()
var children: Dictionary = {} ## id -> PackedInt64Array of child ids
## Per-unit cached path (tile indices) and cursor. Keyed by slot.
var path: Dictionary = {}
var path_pos := PackedInt32Array()

const RESOURCE_NAMES := ["", "food", "wood", "stone"]


func _grow(new_cap: int) -> void:
	for arr_name in _array_fields():
		var arr: Variant = get(arr_name)
		arr.resize(new_cap)
		set(arr_name, arr)
	for s in range(capacity, new_cap):
		_free.append(new_cap - 1 - (s - capacity))
	capacity = new_cap


static func _array_fields() -> PackedStringArray:
	return PackedStringArray(["id", "alive", "species", "sex", "x", "y", "prev_x", "prev_y", "birth_tick",
		"death_age", "health", "max_health", "hunger", "state", "task", "task_target", "task_timer", "job",
		"city", "home", "mother", "father", "carry_type", "carry_amount", "next_think", "last_birth_tick",
		"flags", "kills", "look", "name", "path_pos", "disease", "traits"])


## Fields that are logically authoritative (prev_x/prev_y excluded).
static func persistent_fields() -> PackedStringArray:
	var f := _array_fields()
	var out := PackedStringArray()
	for n in f:
		if n != "prev_x" and n != "prev_y":
			out.append(n)
	return out


func allocate() -> int:
	if _free.is_empty():
		_grow(maxi(64, capacity * 2))
	var s: int = _free[_free.size() - 1]
	_free.remove_at(_free.size() - 1)
	var uid := next_id
	next_id += 1
	id[s] = uid
	alive[s] = 1
	slot_of[uid] = s
	count += 1
	species[s] = 0
	sex[s] = 0
	x[s] = 0.0
	y[s] = 0.0
	prev_x[s] = 0.0
	prev_y[s] = 0.0
	birth_tick[s] = 0
	death_age[s] = 0
	health[s] = 1.0
	max_health[s] = 1.0
	hunger[s] = 0.0
	state[s] = State.IDLE
	task[s] = Task.NONE
	task_target[s] = -1
	task_timer[s] = 0
	job[s] = 0
	city[s] = SimConst.CITY_NONE
	home[s] = SimConst.BUILDING_ID_NONE
	mother[s] = SimConst.UNIT_NONE
	father[s] = SimConst.UNIT_NONE
	carry_type[s] = 0
	carry_amount[s] = 0.0
	next_think[s] = 0
	last_birth_tick[s] = -1000000
	flags[s] = 0
	kills[s] = 0
	look[s] = 0
	name[s] = ""
	path_pos[s] = 0
	disease[s] = 0
	traits[s] = 0
	return s


func free_slot(s: int) -> void:
	if alive[s] == 0:
		return
	alive[s] = 0
	state[s] = State.DEAD
	slot_of.erase(id[s])
	path.erase(s)
	_free.append(s)
	count -= 1


func is_alive_id(uid: int) -> bool:
	return slot_of.has(uid)


func slot_for(uid: int) -> int:
	return slot_of.get(uid, -1)


func add_child_link(parent_id: int, child_id: int) -> void:
	if parent_id == SimConst.UNIT_NONE:
		return
	var arr: PackedInt64Array = children.get(parent_id, PackedInt64Array())
	arr.append(child_id)
	children[parent_id] = arr


func age_years(s: int, tick: int) -> float:
	return float(tick - birth_tick[s]) / SimConst.TICKS_PER_YEAR


func has_flag(s: int, f: int) -> bool:
	return (flags[s] & f) != 0


func set_flag(s: int, f: int, on: bool) -> void:
	flags[s] = (flags[s] | f) if on else (flags[s] & ~f)


func tile_index(s: int, width: int) -> int:
	return int(y[s]) * width + int(x[s])


func to_dict() -> Dictionary:
	var d := {"capacity": capacity, "count": count, "next_id": next_id, "free": _free, "children": children}
	for f in persistent_fields():
		d[f] = get(f)
	var p := {}
	for s: int in path:
		p[s] = path[s]
	d["path"] = p
	return d


func from_dict(d: Dictionary) -> void:
	capacity = int(d["capacity"])
	count = int(d["count"])
	next_id = int(d["next_id"])
	_free = d["free"]
	children = d["children"]
	for f in persistent_fields():
		set(f, d[f])
	prev_x = x.duplicate()
	prev_y = y.duplicate()
	path = {}
	var p: Dictionary = d["path"]
	for s in p:
		path[int(s)] = p[s]
	slot_of.clear()
	for s in capacity:
		if alive[s] == 1:
			slot_of[id[s]] = s


## Compaction keeps per-tick loops proportional to the living population after a
## die-off (capacity otherwise never shrinks). Deterministic: runs at year ticks.
func should_compact() -> bool:
	return capacity > 256 and count < capacity / 2


func compact() -> void:
	var remap := PackedInt32Array()
	remap.resize(capacity)
	remap.fill(-1)
	var n := 0
	for s in capacity:
		if alive[s] == 1:
			remap[s] = n
			n += 1
	var new_cap := maxi(64, nearest_po2(n + n / 4 + 1))
	for f in _array_fields():
		var old: Variant = get(f)
		var arr: Variant = old.duplicate()
		arr.resize(new_cap)
		for s in capacity:
			var t := remap[s]
			if t >= 0:
				arr[t] = old[s]
		for t in range(n, new_cap):
			arr[t] = _blank(f)
		set(f, arr)
	# Slot-valued references: hunting targets (task_target holds a prey slot).
	for t in n:
		if task[t] == Task.HUNT:
			var tgt := task_target[t]
			task_target[t] = remap[tgt] if tgt >= 0 and tgt < capacity else -1
	var new_path := {}
	for s: int in path:
		if remap[s] >= 0:
			new_path[remap[s]] = path[s]
	path = new_path
	capacity = new_cap
	_free = PackedInt32Array()
	for s in range(new_cap - 1, n - 1, -1):
		_free.append(s)
	slot_of.clear()
	for s in n:
		slot_of[id[s]] = s


static func _blank(field: String) -> Variant:
	match field:
		"name":
			return ""
		"x", "y", "prev_x", "prev_y", "health", "max_health", "hunger", "carry_amount":
			return 0.0
	return 0
