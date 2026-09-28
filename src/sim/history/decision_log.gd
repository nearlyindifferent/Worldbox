class_name DecisionLog
extends RefCounted
## Structured "why did this happen" log for major AI decisions. Each entry keeps
## the numeric factors that produced the decision so the player/admin can inspect it.

const CAP := 600

var entries: Array[Dictionary] = []
var enabled: bool = true


func record(tick: int, category: String, actor: String, decision: String, reasons: Array, refs: Dictionary = {}) -> void:
	if not enabled:
		return
	entries.append({"tick": tick, "category": category, "actor": actor, "decision": decision, "reasons": reasons, "refs": refs})
	if entries.size() > CAP:
		entries.remove_at(0)


static func format(e: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("[%s] %s %s" % [e["category"], e["actor"], e["decision"]])
	for r: Array in e["reasons"]:
		var v: Variant = r[1]
		if typeof(v) == TYPE_FLOAT:
			lines.append("   %s %s" % [r[0], ("%+.1f" % v)])
		else:
			lines.append("   %s %s" % [r[0], str(v)])
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	entries.assign(d["entries"])
