class_name City
extends RefCounted
## A settlement. Cities are few (tens to hundreds), so they are plain objects;
## all fields are explicit and serialized through to_dict/from_dict.

const RESOURCES := ["food", "wood", "stone"]

var id: int
var name: String
var species: int
var center: int                 ## tile index of the town hall anchor
var founded_tick: int
var founder_id: int = SimConst.UNIT_NONE
var leader_id: int = SimConst.UNIT_NONE
var color_index: int = 0
var members := PackedInt64Array()
var territory := PackedInt32Array()
var fields := PackedInt32Array()     ## farmland tiles owned by this city
var buildings := PackedInt32Array()  ## building ids
var storage: Dictionary = {"food": 0.0, "wood": 0.0, "stone": 0.0}
var housing: int = 0
var food_capacity: float = 0.0
var produced: Dictionary = {}        ## current month production per resource
var consumed: Dictionary = {}
var last_produced: Dictionary = {}   ## completed month
var last_consumed: Dictionary = {}
var job_counts := PackedInt32Array()
var job_targets := PackedInt32Array()
var births: int = 0
var deaths: int = 0
var starving_months: int = 0
var founding_reasons: Array = []     ## [[label, value], ...] explaining why it was founded
var alive: bool = true


func _init() -> void:
	for r in RESOURCES:
		produced[r] = 0.0
		consumed[r] = 0.0
		last_produced[r] = 0.0
		last_consumed[r] = 0.0


func population() -> int:
	return members.size()


func add_resource(res: String, amount: float) -> void:
	storage[res] = float(storage.get(res, 0.0)) + amount
	if amount > 0.0:
		produced[res] = float(produced.get(res, 0.0)) + amount


## Removes up to `amount`, returns the amount actually taken. Never goes negative.
func take_resource(res: String, amount: float) -> float:
	var have: float = storage.get(res, 0.0)
	var took := minf(have, amount)
	storage[res] = have - took
	consumed[res] = float(consumed.get(res, 0.0)) + took
	return took


func roll_month() -> void:
	for r in RESOURCES:
		last_produced[r] = produced[r]
		last_consumed[r] = consumed[r]
		produced[r] = 0.0
		consumed[r] = 0.0


func remove_member(uid: int) -> void:
	var k := members.find(uid)
	if k >= 0:
		members.remove_at(k)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "species": species, "center": center, "founded_tick": founded_tick,
		"founder_id": founder_id, "leader_id": leader_id, "color_index": color_index, "members": members,
		"territory": territory, "fields": fields, "buildings": buildings, "storage": storage.duplicate(),
		"housing": housing, "food_capacity": food_capacity, "produced": produced.duplicate(),
		"consumed": consumed.duplicate(), "last_produced": last_produced.duplicate(),
		"last_consumed": last_consumed.duplicate(), "job_counts": job_counts, "job_targets": job_targets,
		"births": births, "deaths": deaths, "starving_months": starving_months,
		"founding_reasons": founding_reasons.duplicate(true), "alive": alive,
	}


static func from_dict(d: Dictionary) -> City:
	var c := City.new()
	for k: String in d:
		c.set(k, d[k])
	return c
