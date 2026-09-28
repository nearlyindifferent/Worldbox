class_name WorldLaws
extends RefCounted
## Global rule toggles. Systems read these every tick, so changes take effect immediately.

const DEFAULTS := {
	"hunger": true,
	"natural_death": true,
	"reproduction": true,
	"animal_reproduction": true,
	"vegetation_growth": true,
	"forest_spread": true,
	"settlement_founding": true,
	"construction": true,
}
const DESCRIPTIONS := {
	"hunger": "Creatures grow hungry and starve without food.",
	"natural_death": "Creatures die of old age.",
	"reproduction": "Sapient families have children.",
	"animal_reproduction": "Animals breed.",
	"vegetation_growth": "Grass and crops regrow over time.",
	"forest_spread": "Forests slowly reclaim nearby open land.",
	"settlement_founding": "Wanderers may found new settlements.",
	"construction": "Cities plan and build new structures.",
}

var values: Dictionary = DEFAULTS.duplicate()


func is_on(law: String) -> bool:
	return values.get(law, false)


func set_law(law: String, on: bool) -> void:
	if DEFAULTS.has(law):
		values[law] = on


func to_dict() -> Dictionary:
	return values.duplicate()


func from_dict(d: Dictionary) -> void:
	values = DEFAULTS.duplicate()
	for k: String in d:
		if values.has(k):
			values[k] = bool(d[k])
