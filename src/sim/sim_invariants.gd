class_name SimInvariants
extends RefCounted
## Structural consistency checks over the whole simulation. Used by automated
## tests, long-run fuzzing and the admin panel. Returns a list of violations.


static func check(sim: Simulation, max_errors: int = 50) -> PackedStringArray:
	var errs := PackedStringArray()
	var u := sim.units
	var w := sim.world
	var alive_count := 0
	for s in u.capacity:
		if u.alive[s] == 0:
			continue
		alive_count += 1
		if not (is_finite(u.x[s]) and is_finite(u.y[s]) and is_finite(u.health[s]) and is_finite(u.hunger[s])):
			errs.append("unit %d has non-finite state" % u.id[s])
		if u.x[s] < 0.0 or u.y[s] < 0.0 or u.x[s] >= w.width or u.y[s] >= w.height:
			errs.append("unit %d out of bounds (%.2f, %.2f)" % [u.id[s], u.x[s], u.y[s]])
		if u.hunger[s] < 0.0 or u.hunger[s] > SimConst.HUNGER_MAX + 0.001:
			errs.append("unit %d hunger out of range %.3f" % [u.id[s], u.hunger[s]])
		if u.health[s] > u.max_health[s] + 0.001:
			errs.append("unit %d health above max" % u.id[s])
		if u.carry_amount[s] < 0.0:
			errs.append("unit %d negative carry" % u.id[s])
		if u.slot_for(u.id[s]) != s:
			errs.append("unit %d slot map mismatch" % u.id[s])
		var c := u.city[s]
		if c != SimConst.CITY_NONE:
			if not sim.cities.has(c):
				errs.append("unit %d references missing city %d" % [u.id[s], c])
			elif not (sim.cities[c] as City).members.has(u.id[s]):
				errs.append("unit %d not in its city's member list" % u.id[s])
		if errs.size() >= max_errors:
			return errs
	# Derived movement cache must agree with the authoritative path (else reloads diverge).
	var wp := sim.movement._wp
	if wp.size() == u.capacity:
		for s in u.capacity:
			if u.alive[s] == 1 and u.state[s] == UnitStore.State.MOVING and wp[s] >= 0:
				var p: PackedInt32Array = u.path.get(s, PackedInt32Array())
				if u.path_pos[s] >= p.size() or p[u.path_pos[s]] != wp[s]:
					errs.append("unit %d waypoint cache %d disagrees with path" % [u.id[s], wp[s]])
					break
	if alive_count != u.count:
		errs.append("unit count %d != alive slots %d" % [u.count, alive_count])
	if u.slot_of.size() != u.count:
		errs.append("slot map size %d != count %d" % [u.slot_of.size(), u.count])

	for c: City in sim.cities.values():
		if not c.alive:
			continue
		for res: String in c.storage:
			var v: float = c.storage[res]
			if v < -0.0001 or not is_finite(v):
				errs.append("city %s has invalid %s=%f" % [c.name, res, v])
		var seen := {}
		for mid in c.members:
			if seen.has(mid):
				errs.append("city %s lists member %d twice" % [c.name, mid])
			seen[mid] = true
			var s := u.slot_for(mid)
			if s < 0:
				errs.append("city %s has dead/orphan member %d" % [c.name, mid])
			elif u.city[s] != c.id:
				errs.append("city %s member %d points to city %d" % [c.name, mid, u.city[s]])
		for i in c.territory:
			if w.owner[i] != c.id:
				errs.append("city %s territory tile %d owned by %d" % [c.name, i, w.owner[i]])
				break
		for bid in c.buildings:
			if not sim.buildings.has(bid):
				errs.append("city %s references missing building %d" % [c.name, bid])
		if c.population() > 0 and c.housing <= 0 and c.buildings.size() == 0:
			errs.append("city %s has people but no buildings" % c.name)
		if errs.size() >= max_errors:
			return errs

	for b: Building in sim.buildings.values():
		var c: City = sim.cities.get(b.city, null)
		if c == null or not c.alive:
			errs.append("building %d belongs to missing city %d" % [b.id, b.city])
			continue
		var sz := b.def().size
		for dy in sz:
			for dx in sz:
				var i := w.idx(b.x + dx, b.y + dy)
				if w.building[i] != b.id:
					errs.append("building %d footprint tile %d holds %d" % [b.id, i, w.building[i]])
		if b.progress < 0.0:
			errs.append("building %d negative progress" % b.id)

	var owned_total := 0
	for c: City in sim.cities.values():
		if c.alive:
			owned_total += c.territory.size()
	var owned_tiles := 0
	for i in w.size:
		var o := w.owner[i]
		if o != SimConst.CITY_NONE:
			owned_tiles += 1
			if not sim.cities.has(o) or not (sim.cities[o] as City).alive:
				errs.append("tile %d owned by missing city %d" % [i, o])
				break
		var bid := w.building[i]
		if bid != SimConst.BUILDING_ID_NONE and not sim.buildings.has(bid):
			errs.append("tile %d references missing building %d" % [i, bid])
			break
		if not is_finite(w.elevation[i]) or not is_finite(w.temperature[i]):
			errs.append("tile %d non-finite climate" % i)
			break
	if owned_tiles != owned_total:
		errs.append("owned tiles %d != sum of territories %d" % [owned_tiles, owned_total])
	return errs
