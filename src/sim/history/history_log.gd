class_name HistoryLog
extends RefCounted
## Chronicle of world events. Major events are kept forever (they are rare by
## construction); minor events live in a bounded ring so memory stays flat.

const MINOR_CAP := 4000

## Append new kinds at the end: values are stored in saves.
enum Kind { WORLD, CITY_FOUNDED, CITY_ABANDONED, LEADER_CHANGED, LEADER_DIED, POP_MILESTONE, DISASTER, GOD_ACT, FAMINE, BUILDING, MIGRATION,
	KINGDOM_FOUNDED, WAR_DECLARED, PEACE, CITY_CONQUERED, REBELLION, KINGDOM_FALLEN, BATTLE }
const MAJOR := [Kind.WORLD, Kind.CITY_FOUNDED, Kind.CITY_ABANDONED, Kind.LEADER_CHANGED, Kind.LEADER_DIED, Kind.POP_MILESTONE, Kind.DISASTER, Kind.FAMINE, Kind.MIGRATION,
	Kind.KINGDOM_FOUNDED, Kind.WAR_DECLARED, Kind.PEACE, Kind.CITY_CONQUERED, Kind.REBELLION, Kind.KINGDOM_FALLEN]

var major: Array[Dictionary] = []
var minor: Array[Dictionary] = []
var total_recorded: int = 0


func record(tick: int, kind: int, text: String, refs: Dictionary = {}, tile: int = -1) -> void:
	var e := {"tick": tick, "kind": kind, "text": text, "refs": refs, "tile": tile}
	total_recorded += 1
	if kind in MAJOR:
		major.append(e)
	else:
		minor.append(e)
		if minor.size() > MINOR_CAP:
			minor.remove_at(0)


## Merged, newest-first list for UI.
func recent(limit: int = 200) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a := major.size() - 1
	var b := minor.size() - 1
	while out.size() < limit and (a >= 0 or b >= 0):
		if b < 0 or (a >= 0 and int(major[a]["tick"]) >= int(minor[b]["tick"])):
			out.append(major[a])
			a -= 1
		else:
			out.append(minor[b])
			b -= 1
	return out


func to_dict() -> Dictionary:
	return {"major": major.duplicate(true), "minor": minor.duplicate(true), "total": total_recorded}


func from_dict(d: Dictionary) -> void:
	major.assign(d["major"])
	minor.assign(d["minor"])
	total_recorded = int(d["total"])
