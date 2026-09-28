class_name AgeSystem
extends RefCounted
## World ages: long eras (20-40 years) that shift the world's rules while they
## last. Each age scales crop and grass growth, wildfire and plague odds, sours
## or calms relations between realms, and may shake the earth. The next age is
## drawn at random (never the same one twice in a row).

const AGES := [
	{"id": "quiet", "name": "The Quiet Years", "desc": "An ordinary time: the world runs by its usual rules.",
		"crop": 1.0, "veg": 1.0, "fire": 1.0, "plague": 1.0, "strife": 0.0, "quake": 0.0, "tint": Color(1, 1, 1)},
	{"id": "green", "name": "The Green Years", "desc": "Gentle rains: crops and grass grow a third faster and fires are rare.",
		"crop": 1.3, "veg": 1.3, "fire": 0.4, "plague": 1.0, "strife": 0.0, "quake": 0.0, "tint": Color(0.96, 1.04, 0.94)},
	{"id": "winter", "name": "The Long Winter", "desc": "Cold years: harvests shrink to 60% and grass grows slowly.",
		"crop": 0.6, "veg": 0.6, "fire": 0.3, "plague": 1.2, "strife": 0.0, "quake": 0.0, "tint": Color(0.86, 0.93, 1.08)},
	{"id": "ember", "name": "The Ember Years", "desc": "Heat and drought: wildfires are three times as likely and crops wilt.",
		"crop": 0.85, "veg": 0.8, "fire": 3.0, "plague": 1.0, "strife": 0.0, "quake": 0.0, "tint": Color(1.08, 0.97, 0.86)},
	{"id": "restless", "name": "The Restless Years", "desc": "Old grudges stir: realms think worse of each other and the ground shakes.",
		"crop": 1.0, "veg": 1.0, "fire": 1.0, "plague": 1.0, "strife": -10.0, "quake": 0.03, "tint": Color(1.04, 0.95, 0.95)},
	{"id": "pale", "name": "The Pale Years", "desc": "A sickly time: plague breaks out four times as often.",
		"crop": 0.95, "veg": 1.0, "fire": 1.0, "plague": 4.0, "strife": 0.0, "quake": 0.0, "tint": Color(0.97, 1.0, 0.95)},
]
const MIN_YEARS := 20
const MAX_YEARS := 40

var sim: Simulation
var current: int = 0
var since: int = 0
var until: int = MIN_YEARS * SimConst.TICKS_PER_YEAR


func _init(p_sim: Simulation) -> void:
	sim = p_sim


func age() -> Dictionary:
	return AGES[current]


func factor(key: String) -> float:
	return float(AGES[current][key]) if sim.laws.is_on("world_ages") else (0.0 if key in ["strife", "quake"] else 1.0)


static func index_of(id: String) -> int:
	for k in AGES.size():
		if AGES[k]["id"] == id:
			return k
	return -1


func monthly() -> void:
	if not sim.laws.is_on("world_ages"):
		# Time stands still for the age while ages are switched off.
		until += SimConst.TICKS_PER_MONTH
		return
	if sim.tick >= until:
		var next := sim.rng.randi_range(0, AGES.size() - 2)
		if next >= current:
			next += 1
		begin(next, "the wheel of ages turned")
	var q := factor("quake")
	if q > 0.0 and sim.laws.is_on("natural_disasters") and sim.rng.chance(q):
		for attempt in 30:
			var i := sim.rng.randi_range(0, sim.world.size - 1)
			if sim.world.is_walkable(i):
				sim.disasters.earthquake(i % sim.world.width, i / sim.world.width, 2)
				break


## Starts age `idx` now, lasting a random 20-40 years.
func begin(idx: int, cause: String) -> void:
	current = clampi(idx, 0, AGES.size() - 1)
	since = sim.tick
	until = sim.tick + sim.rng.randi_range(MIN_YEARS, MAX_YEARS) * SimConst.TICKS_PER_YEAR
	sim.history.record(sim.tick, HistoryLog.Kind.WORLD, "%s began (%s). %s" % [AGES[current]["name"], cause, AGES[current]["desc"]])
	sim.push_fx("age", -1, {"age": current})


func to_dict() -> Dictionary:
	return {"current": current, "since": since, "until": until}


func from_dict(d: Dictionary) -> void:
	current = clampi(int(d.get("current", 0)), 0, AGES.size() - 1)
	since = int(d.get("since", 0))
	until = int(d.get("until", MIN_YEARS * SimConst.TICKS_PER_YEAR))
