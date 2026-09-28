class_name SimRng
extends RefCounted
## Deterministic RNG wrapper (PCG32 via RandomNumberGenerator). All simulation
## randomness must go through a SimRng owned by the simulation so that seeds
## and saved states reproduce identical outcomes.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func get_state() -> int:
	return _rng.state


func set_state(s: int) -> void:
	_rng.state = s


func randf() -> float:
	return _rng.randf()


func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func chance(p: float) -> bool:
	return _rng.randf() < p


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]
