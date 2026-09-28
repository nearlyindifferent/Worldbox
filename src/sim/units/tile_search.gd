class_name TileSearch
extends RefCounted
## Randomized local resource search. Sampling K tiles in a disk is O(K) instead of
## O(r²) for an exhaustive scan, and naturally spreads workers across sites.

enum Kind { GRAZE, FORAGE, FOREST, QUARRY, BUILD_LAND }


static func matches(sim: Simulation, i: int, kind: int, param: int) -> bool:
	var w := sim.world
	var b := w.biome[i]
	if Defs.biome_walkable[b] == 0:
		return false
	match kind:
		Kind.GRAZE, Kind.FORAGE:
			return b != Defs.farmland_index and w.vegetation[i] >= param
		Kind.FOREST:
			return w.wood[i] >= param
		Kind.QUARRY:
			if b == Defs.hills_index:
				return true
			var x := i % w.width
			var y := i / w.width
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.in_bounds(x + d.x, y + d.y) and w.biome[w.idx(x + d.x, y + d.y)] == Defs.mountain_index:
					return true
			return false
		Kind.BUILD_LAND:
			return w.building[i] == SimConst.BUILDING_ID_NONE and b != Defs.farmland_index
	return false


## Closest matching tile among `samples` random tiles within `radius` of `center`, or -1.
static func sample_best(sim: Simulation, center: int, radius: int, samples: int, kind: int, param: int) -> int:
	var w := sim.world
	var cx := center % w.width
	var cy := center / w.width
	if matches(sim, center, kind, param):
		return center
	var best := -1
	var best_d := 1 << 30
	for k in samples:
		var dx := sim.rng.randi_range(-radius, radius)
		var dy := sim.rng.randi_range(-radius, radius)
		var d2 := dx * dx + dy * dy
		if d2 > radius * radius or d2 >= best_d:
			continue
		var x := cx + dx
		var y := cy + dy
		if not w.in_bounds(x, y):
			continue
		var i := y * w.width + x
		if matches(sim, i, kind, param):
			best = i
			best_d = d2
	return best


## Tries radius, 2x and 3x radius with growing sample counts so scarce resources
## far away are still found without paying for large searches when they are near.
static func sample_expanding(sim: Simulation, center: int, radius: int, samples: int, kind: int, param: int) -> int:
	for mult in [1, 2, 3]:
		var t := sample_best(sim, center, radius * mult, samples * mult, kind, param)
		if t >= 0:
			return t
	return -1
