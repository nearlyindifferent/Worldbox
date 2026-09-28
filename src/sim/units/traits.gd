class_name Traits
extends RefCounted
## Heritable traits stored as a bitmask per creature (UnitStore.traits). Physical
## traits apply to every species, so herds and packs evolve under selection;
## character traits only matter for people, mostly when they lead a town or rule
## a kingdom. Bit positions are stored in saves: append only.

enum { STRONG, SWIFT, HARDY, LONG_LIVED, SICKLY, WISE, WARLIKE, JUST, GREEDY, FERTILE, BRAVE }

const INFO := [
	{"name": "Strong", "desc": "30% more health and hits 25% harder in battle.", "physical": true},
	{"name": "Swift", "desc": "Moves 20% faster.", "physical": true},
	{"name": "Hardy", "desc": "Grows hungry 25% more slowly.", "physical": true},
	{"name": "Long-lived", "desc": "Lives about a fifth longer.", "physical": true},
	{"name": "Sickly", "desc": "Plague strikes 60% harder; shorter life.", "physical": true},
	{"name": "Wise", "desc": "As a town leader, farmers and gatherers bring in 15% more food.", "physical": false},
	{"name": "Warlike", "desc": "As a ruler, far quicker to declare war.", "physical": false},
	{"name": "Just", "desc": "As a ruler, provinces stay more loyal.", "physical": false},
	{"name": "Greedy", "desc": "As a ruler, provinces resent the crown.", "physical": false},
	{"name": "Fertile", "desc": "Half again as likely to have children.", "physical": true},
	{"name": "Brave", "desc": "Stands firm instead of fleeing enemy soldiers.", "physical": false},
]
const ROLL_CHANCE := 0.08
const INHERIT_ONE := 0.45     ## one parent carries the trait
const INHERIT_BOTH := 0.75    ## both parents carry it
const MUTATION := 0.04
const MAX_TRAITS := 3
## Mutually exclusive pairs.
const EXCLUSIVE := [[JUST, GREEDY], [LONG_LIVED, SICKLY]]


static func has(mask: int, t: int) -> bool:
	return (mask >> t) & 1 == 1


static func count(mask: int) -> int:
	var n := 0
	for t in INFO.size():
		n += (mask >> t) & 1
	return n


## Traits for a creature with no known parents.
static func roll(rng: SimRng, sapient: bool) -> int:
	var mask := 0
	for t in INFO.size():
		if (sapient or INFO[t]["physical"]) and rng.chance(ROLL_CHANCE):
			mask = _add(mask, t)
	return mask


## Offspring traits: each parental trait passes on with a chance, plus rare mutation.
static func inherit(rng: SimRng, a: int, b: int, sapient: bool) -> int:
	var mask := 0
	for t in INFO.size():
		if not sapient and not INFO[t]["physical"]:
			continue
		var n := (a >> t & 1) + (b >> t & 1)
		if n == 2 and rng.chance(INHERIT_BOTH):
			mask = _add(mask, t)
		elif n == 1 and rng.chance(INHERIT_ONE):
			mask = _add(mask, t)
	if rng.chance(MUTATION):
		var t2 := rng.randi_range(0, INFO.size() - 1)
		if sapient or INFO[t2]["physical"]:
			mask = _add(mask, t2)
	return mask


static func _add(mask: int, t: int) -> int:
	if count(mask) >= MAX_TRAITS:
		return mask
	for pair: Array in EXCLUSIVE:
		if t in pair:
			for o: int in pair:
				if o != t and has(mask, o):
					return mask
	return mask | (1 << t)


static func names(mask: int) -> PackedStringArray:
	var out := PackedStringArray()
	for t in INFO.size():
		if has(mask, t):
			out.append(INFO[t]["name"])
	return out
