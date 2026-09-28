class_name StatSeries
extends RefCounted
## Bounded time series. When full, adjacent samples are averaged pairwise and the
## sampling interval doubles, so a series covers any world age in O(CAPACITY) memory
## with resolution degrading gracefully for older data.

const CAPACITY := 512

var interval: int = 1       ## samples (months) represented by each stored value
var values := PackedFloat32Array()
var _acc: float = 0.0
var _acc_n: int = 0


func push(v: float) -> void:
	_acc += v
	_acc_n += 1
	if _acc_n < interval:
		return
	values.append(_acc / _acc_n)
	_acc = 0.0
	_acc_n = 0
	if values.size() >= CAPACITY:
		_compact()


func _compact() -> void:
	var half := PackedFloat32Array()
	@warning_ignore("integer_division")
	half.resize(values.size() / 2)
	for k in half.size():
		half[k] = (values[2 * k] + values[2 * k + 1]) * 0.5
	values = half
	interval *= 2


func last() -> float:
	return values[values.size() - 1] if values.size() > 0 else 0.0


func to_dict() -> Dictionary:
	return {"interval": interval, "values": values, "acc": _acc, "acc_n": _acc_n}


func from_dict(d: Dictionary) -> void:
	interval = int(d["interval"])
	values = d["values"]
	_acc = float(d["acc"])
	_acc_n = int(d["acc_n"])
