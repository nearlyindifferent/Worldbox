class_name SpatialIndex
extends RefCounted
## Chunk-bucketed unit index rebuilt once per tick with a counting sort
## (compressed sparse rows). O(units + chunks) per rebuild, no per-unit allocation.

var chunks_x: int
var chunks_y: int
var cell_start := PackedInt32Array() ## size chunks+1
var items := PackedInt32Array()       ## unit slots grouped by chunk
var _cell_of := PackedInt32Array()     ## scratch: chunk per slot


func setup(world_w: int, world_h: int) -> void:
	chunks_x = ceili(float(world_w) / SimConst.CHUNK)
	chunks_y = ceili(float(world_h) / SimConst.CHUNK)
	cell_start.resize(chunks_x * chunks_y + 1)
	cell_start.fill(0)


func rebuild(units: UnitStore) -> void:
	var n_cells := chunks_x * chunks_y
	var counts := PackedInt32Array()
	counts.resize(n_cells + 1)
	_cell_of.resize(units.capacity)
	for s in units.capacity:
		if units.alive[s] == 0:
			_cell_of[s] = -1
			continue
		var cx := clampi(int(units.x[s]) / SimConst.CHUNK, 0, chunks_x - 1)
		var cy := clampi(int(units.y[s]) / SimConst.CHUNK, 0, chunks_y - 1)
		var c := cy * chunks_x + cx
		_cell_of[s] = c
		counts[c + 1] += 1
	for c in n_cells:
		counts[c + 1] += counts[c]
	cell_start = counts.duplicate()
	items.resize(counts[n_cells])
	for s in units.capacity:
		var c := _cell_of[s]
		if c < 0:
			continue
		items[counts[c]] = s
		counts[c] += 1


## Slots of living units within radius r (tiles) of (px, py), optionally filtered by species.
func query_radius(units: UnitStore, px: float, py: float, r: float, species_filter: int = -1, limit: int = 1 << 30) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := r * r
	var cx0 := clampi(int(px - r) / SimConst.CHUNK, 0, chunks_x - 1)
	var cx1 := clampi(int(px + r) / SimConst.CHUNK, 0, chunks_x - 1)
	var cy0 := clampi(int(py - r) / SimConst.CHUNK, 0, chunks_y - 1)
	var cy1 := clampi(int(py + r) / SimConst.CHUNK, 0, chunks_y - 1)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var c := cy * chunks_x + cx
			for k in range(cell_start[c], cell_start[c + 1]):
				var s := items[k]
				if units.alive[s] == 0:
					continue
				if species_filter >= 0 and units.species[s] != species_filter:
					continue
				var dx := units.x[s] - px
				var dy := units.y[s] - py
				if dx * dx + dy * dy <= r2:
					out.append(s)
					if out.size() >= limit:
						return out
	return out


func count_in_chunk_of(px: float, py: float, units: UnitStore, species_filter: int) -> int:
	var cx := clampi(int(px) / SimConst.CHUNK, 0, chunks_x - 1)
	var cy := clampi(int(py) / SimConst.CHUNK, 0, chunks_y - 1)
	var c := cy * chunks_x + cx
	var n := 0
	for k in range(cell_start[c], cell_start[c + 1]):
		var s := items[k]
		if units.alive[s] == 1 and units.species[s] == species_filter:
			n += 1
	return n


## Visible-rectangle query used by presentation; returns slots in chunk rows overlapping rect.
func slots_in_rect(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cx0 := clampi(int(rect.position.x) / SimConst.CHUNK - 1, 0, chunks_x - 1)
	var cx1 := clampi(int(rect.end.x) / SimConst.CHUNK + 1, 0, chunks_x - 1)
	var cy0 := clampi(int(rect.position.y) / SimConst.CHUNK - 1, 0, chunks_y - 1)
	var cy1 := clampi(int(rect.end.y) / SimConst.CHUNK + 1, 0, chunks_y - 1)
	for cy in range(cy0, cy1 + 1):
		var a := cell_start[cy * chunks_x + cx0]
		var b := cell_start[cy * chunks_x + cx1 + 1]
		out.append_array(items.slice(a, b))
	return out
