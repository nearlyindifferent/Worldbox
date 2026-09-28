class_name GodCommands
extends RefCounted
## Single entry point for every player power and admin action. Commands are plain
## dictionaries so they can be logged, replayed and issued from tests/tools.
## Returns {"ok": bool, "msg": String, ...}.


## Upper bound for brush radius regardless of caller (keeps undo entries and tick cost bounded).
const MAX_BRUSH_RADIUS := 16


static func execute(sim: Simulation, cmd: Dictionary) -> Dictionary:
	var op: String = cmd.get("op", "")
	# Commands run between ticks; the spatial index must reflect current positions so a
	# command behaves the same in an uninterrupted run and in a freshly loaded one.
	sim.spatial.rebuild(sim.units)
	match op:
		"stroke_begin":
			sim.editor.begin_stroke()
			return _ok()
		"stroke_end":
			sim.editor.end_stroke()
			return _ok()
		"undo":
			var n := sim.editor.undo()
			return _ok("Undid %d tiles" % n) if n > 0 else _fail("Nothing to undo")
		"brush":
			return _brush(sim, cmd)
		"kill_unit", "delete_unit":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.kill_unit(s, "divine intervention" if op == "kill_unit" else "removed by admin")
			return _ok()
		"duplicate_unit":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			var u := sim.units
			var c := sim.spawn_unit(u.species[s], u.x[s] + 0.6, u.y[s], u.age_years(s, sim.tick), u.mother[s], u.father[s])
			if c < 0:
				return _fail("No room")
			u.sex[c] = u.sex[s]
			u.look[c] = u.look[s]
			u.flags[c] = u.flags[s]
			if u.city[s] != SimConst.CITY_NONE and sim.cities.has(u.city[s]):
				sim.civ.join_city(c, sim.cities[u.city[s]])
			return _ok("Duplicated", {"id": u.id[c]})
		"teleport":
			var s := _slot(sim, cmd)
			var t := sim.world.nearest_walkable(int(cmd["x"]), int(cmd["y"]), 3)
			if s < 0 or t < 0:
				return _fail("Invalid target")
			sim.units.x[s] = float(t % sim.world.width) + 0.5
			sim.units.y[s] = float(t / sim.world.width) + 0.5
			sim.units.prev_x[s] = sim.units.x[s]
			sim.units.prev_y[s] = sim.units.y[s]
			sim.movement.stop(s)
			sim.units.next_think[s] = sim.tick + 1
			return _ok()
		"set_health":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.units.health[s] = clampf(float(cmd["value"]), 0.1, sim.units.max_health[s])
			return _ok()
		"set_hunger":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.units.hunger[s] = clampf(float(cmd["value"]), 0.0, SimConst.HUNGER_MAX)
			return _ok()
		"set_age":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.units.birth_tick[s] = sim.tick - int(maxf(0.0, float(cmd["value"])) * SimConst.TICKS_PER_YEAR)
			return _ok()
		"set_flag":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.units.set_flag(s, int(cmd["flag"]), bool(cmd["on"]))
			return _ok()
		"set_job":
			var s := _slot(sim, cmd)
			if s < 0:
				return _fail("No such unit")
			sim.units.job[s] = Defs.job_by_id(cmd["job"]).index
			sim.units.task[s] = UnitStore.Task.NONE
			return _ok()
		"add_resource":
			var c: City = sim.cities.get(int(cmd["city"]), null)
			if c == null:
				return _fail("No such city")
			var res: String = cmd["res"]
			var amt := float(cmd["amount"])
			if amt >= 0.0:
				c.storage[res] = float(c.storage.get(res, 0.0)) + amt
			else:
				c.take_resource(res, -amt)
			return _ok()
		"set_law":
			sim.laws.set_law(cmd["law"], bool(cmd["on"]))
			return _ok()
		"found_city":
			var s := _slot(sim, cmd)
			if s < 0 or sim.units.species[s] != sim.human_species:
				return _fail("Needs a sapient unit")
			if sim.units.city[s] != SimConst.CITY_NONE:
				return _fail("Already belongs to a city")
			var ti := sim.units.tile_index(s, sim.world.width)
			var ev := sim.civ.evaluate_site(ti)
			if (ev["reasons"] as Array).size() > 0 and str((ev["reasons"] as Array)[0][0]) in ["site blocked", "too close to another city"]:
				return _fail(str((ev["reasons"] as Array)[0][0]))
			var reasons: Array = ev["reasons"]
			reasons.append(["forced by the gods", 0.0])
			var c := sim.civ.found_city(s, ti, reasons)
			return _ok("Founded %s" % c.name, {"city": c.id})
		"abandon_city":
			var c: City = sim.cities.get(int(cmd["city"]), null)
			if c == null:
				return _fail("No such city")
			sim.civ.abandon_city(c, "the gods willed it")
			return _ok()
		"declare_war":
			var ka: Kingdom = sim.kingdoms.get(int(cmd["a"]), null)
			var kb: Kingdom = sim.kingdoms.get(int(cmd["b"]), null)
			if ka == null or kb == null or ka == kb:
				return _fail("Two different kingdoms are needed")
			if sim.realm.at_war(ka.id, kb.id):
				return _fail("They are already at war")
			sim.realm.declare_war(ka, kb, [["cause", str(cmd.get("reason", "divine provocation"))]])
			return _ok("War between the %s and the %s" % [ka.name, kb.name])
		"make_peace":
			var ka2: Kingdom = sim.kingdoms.get(int(cmd["a"]), null)
			if ka2 == null:
				return _fail("No such kingdom")
			var n := 0
			for foe in sim.realm.enemies_of(ka2.id):
				if cmd.has("b") and int(cmd["b"]) != foe:
					continue
				sim.realm.make_peace(ka2, sim.kingdoms[foe], [["cause", "divine intervention"]])
				n += 1
			return _ok("Peace made (%d wars ended)" % n) if n > 0 else _fail("Not at war")
		"rebel":
			var rc: City = sim.cities.get(int(cmd["city"]), null)
			if rc == null:
				return _fail("No such city")
			var realm: Kingdom = sim.kingdoms.get(rc.kingdom, null)
			if realm != null and realm.cities.size() < 2:
				# A realm of one town cannot split: its people overthrow their ruler instead.
				return _coup(sim, rc)
			var nk := sim.realm.rebel(rc, [["cause", "stirred up by the gods"]])
			return _ok("%s rebelled" % rc.name, {"kingdom": nk.id}) if nk != null else _fail("This town cannot rebel")
		"set_world_age":
			var idx := AgeSystem.index_of(str(cmd.get("age", "")))
			if idx < 0:
				idx = (sim.ages.current + 1) % AgeSystem.AGES.size()
			sim.ages.begin(idx, "the gods turned the wheel")
			return _ok(str(AgeSystem.AGES[idx]["name"]) + " began")
		"set_leader":
			var c: City = sim.cities.get(int(cmd["city"]), null)
			var s := _slot(sim, cmd)
			if c == null or s < 0 or sim.units.city[s] != c.id:
				return _fail("Unit must be a member of the city")
			c.leader_id = sim.units.id[s]
			sim.history.record(sim.tick, HistoryLog.Kind.LEADER_CHANGED, "The gods made %s leader of %s." % [sim.units.name[s], c.name], {"city": c.id, "unit": c.leader_id}, c.center)
			return _ok()
	return _fail("Unknown command '%s'" % op)


static func _brush(sim: Simulation, cmd: Dictionary) -> Dictionary:
	var power: String = cmd["power"]
	var x := int(cmd["x"])
	var y := int(cmd["y"])
	var r := clampi(int(cmd.get("radius", 1)), 0, MAX_BRUSH_RADIUS)
	if sim.editor.is_terrain_power(power):
		return _ok("", {"changed": sim.editor.apply_brush(power, x, y, r)})
	match power:
		"spawn_human", "spawn_sheep", "spawn_wolf":
			var sp := sim.human_species if power == "spawn_human" else (sim.sheep_species if power == "spawn_sheep" else sim.wolf_species)
			var n := 1 + r / 2
			var made := 0
			for k in n:
				var s := sim.spawn_unit(sp, float(x) + 0.5 + sim.rng.randf_range(-r, r) * 0.5, float(y) + 0.5 + sim.rng.randf_range(-r, r) * 0.5, sim.rng.randf_range(16.0, 28.0) if sp == sim.human_species else sim.rng.randf_range(1.0, 4.0))
				if s >= 0 and sp == sim.wolf_species:
					sim.units.sex[s] = k % 2
				if s >= 0:
					made += 1
			return _ok("", {"spawned": made}) if made > 0 else _fail("Creatures need dry land")
		"smite":
			var n := 0
			for s in sim.spatial.query_radius(sim.units, x + 0.5, y + 0.5, maxf(0.8, r)):
				if not sim.units.has_flag(s, UnitStore.Flag.INVULNERABLE):
					sim.kill_unit(s, "smitten by the gods")
					n += 1
			sim.spatial.rebuild(sim.units)
			if n > 0:
				var at := sim.world.idx(clampi(x, 0, sim.world.width - 1), clampi(y, 0, sim.world.height - 1))
				sim.disasters.record("smite", HistoryLog.Kind.GOD_ACT, "The gods struck down %d near %s." % [n, sim.disasters.place_name(at)], at)
			return _ok("", {"killed": n})
		"fire":
			var lit := 0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= r * r + r and sim.world.in_bounds(x + dx, y + dy) and sim.disasters.ignite(sim.world.idx(x + dx, y + dy)):
						lit += 1
			if lit == 0:
				return _fail("Nothing here will burn")
			var ft := sim.world.idx(clampi(x, 0, sim.world.width - 1), clampi(y, 0, sim.world.height - 1))
			sim.disasters.record("fire_power", HistoryLog.Kind.GOD_ACT, "The gods set fire to the land near %s." % sim.disasters.place_name(ft), ft)
			return _ok("", {"lit": lit})
		"rain":
			return _ok("", {"doused": sim.disasters.rain(x, y, maxi(1, r))})
		"meteor":
			if not sim.world.in_bounds(x, y):
				return _fail("Out of the world")
			return _ok("", sim.disasters.meteor(x, y, r))
		"earthquake":
			if not sim.world.in_bounds(x, y):
				return _fail("Out of the world")
			sim.disasters.earthquake(x, y, r)
			return _ok()
		"volcano":
			if not sim.world.in_bounds(x, y):
				return _fail("Out of the world")
			sim.disasters.volcano(x, y, r)
			return _ok()
		"plague":
			var sick := sim.disasters.plague_power(x, y, r)
			return _ok("", {"infected": sick}) if sick > 0 else _fail("No one here can catch the plague")
		"turn_age":
			return execute(sim, {"op": "set_world_age"})
		"incite_war", "forge_peace", "spark_rebellion":
			var i := sim.world.idx(clampi(x, 0, sim.world.width - 1), clampi(y, 0, sim.world.height - 1))
			var c: City = sim.cities.get(sim.world.owner[i], null)
			if c == null:
				return _fail("Use this on a city's territory")
			if power == "spark_rebellion":
				return execute(sim, {"op": "rebel", "city": c.id})
			if power == "forge_peace":
				return execute(sim, {"op": "make_peace", "a": c.kingdom})
			# Incite: this kingdom attacks its nearest neighbouring kingdom.
			var w := sim.world.width
			var best := -1
			var best_d := INF
			for other: City in sim.cities.values():
				if other.kingdom == c.kingdom or sim.realm.at_war(c.kingdom, other.kingdom):
					continue
				var d := Vector2(other.center % w - c.center % w, other.center / w - c.center / w).length()
				if d < best_d:
					best_d = d
					best = other.kingdom
			if best < 0:
				return _fail("No neighbouring kingdom to fight")
			return execute(sim, {"op": "declare_war", "a": c.kingdom, "b": best, "reason": "incited by the gods"})
		"bless":
			var n := 0
			for s in sim.spatial.query_radius(sim.units, x + 0.5, y + 0.5, maxf(0.8, r)):
				sim.units.health[s] = sim.units.max_health[s]
				sim.units.hunger[s] = 0.0
				n += 1
			return _ok("", {"blessed": n})
	return _fail("Unknown power '%s'" % power)


## Replaces a town's leader with the most ambitious other adult.
static func _coup(sim: Simulation, c: City) -> Dictionary:
	var u := sim.units
	var best := -1
	var best_score := -1.0
	for mid in c.members:
		var s := u.slot_for(mid)
		if s < 0 or mid == c.leader_id or u.age_years(s, sim.tick) < 16.0:
			continue
		var score := 1.0 + (5.0 if Traits.has(u.traits[s], Traits.WARLIKE) else 0.0) + (3.0 if Traits.has(u.traits[s], Traits.BRAVE) else 0.0) + float(u.id[s] % 7) * 0.1
		if score > best_score:
			best_score = score
			best = s
	if best < 0:
		return _fail("No one in %s is ready to seize power" % c.name)
	var old := sim.units.slot_for(c.leader_id)
	var old_name := sim.units.name[old] if old >= 0 else "the old leader"
	c.leader_id = u.id[best]
	var realm: Kingdom = sim.kingdoms.get(c.kingdom, null)
	if realm != null and realm.capital == c.id:
		realm.ruler_id = c.leader_id
	c.loyalty = maxf(0.0, c.loyalty - 20.0)
	sim.history.record(sim.tick, HistoryLog.Kind.REBELLION, "%s overthrew %s and seized %s." % [u.name[best], old_name, c.name], {"city": c.id, "unit": c.leader_id}, c.center)
	return _ok("%s seized power in %s" % [u.name[best], c.name])


static func _slot(sim: Simulation, cmd: Dictionary) -> int:
	return sim.units.slot_for(int(cmd.get("id", -1)))


static func _ok(msg: String = "", extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "msg": msg}
	d.merge(extra)
	return d


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
