class_name Building
extends RefCounted
## A placed structure. `x`,`y` are the top-left footprint tile.

var id: int
var type: int        ## Defs building index
var city: int
var x: int
var y: int
var progress: float  ## builder work accumulated
var complete: bool
var health: float
var paid: bool       ## construction cost already deducted


func def() -> Defs.BuildingDef:
	return Defs.buildings[type]


func center_tile(width: int) -> int:
	var s := def().size
	@warning_ignore("integer_division")
	return (y + s / 2) * width + (x + s / 2)


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "city": city, "x": x, "y": y, "progress": progress,
		"complete": complete, "health": health, "paid": paid}


static func from_dict(d: Dictionary) -> Building:
	var b := Building.new()
	var known := Building.new().to_dict()
	for k: String in d:
		if known.has(k):
			b.set(k, d[k])
	return b
