class_name GodCommands
extends RefCounted
## Single entry point for every player power and admin action. Commands are plain
## dictionaries so they can be logged, replayed and issued from tests/tools.
## Returns {"ok": bool, "msg": String, ...}.


## Upper bound for brush radius regardless of caller (keeps undo entries and tick cost bounded).
const MAX_BRUSH_RADIUS := 16


static func execute(sim: Simulation, cmd: Dictionary) -> Dictionary:
	var op: String = cmd.get("op", "")
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
		"spawn_human", "spawn_sheep":
			var sp := sim.human_species if power == "spawn_human" else sim.sheep_species
			var n := 1 + r / 2
			var made := 0
			for k in n:
				var s := sim.spawn_unit(sp, float(x) + 0.5 + sim.rng.randf_range(-r, r) * 0.5, float(y) + 0.5 + sim.rng.randf_range(-r, r) * 0.5, sim.rng.randf_range(16.0, 28.0) if sp == sim.human_species else sim.rng.randf_range(1.0, 4.0))
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
			return _ok("", {"killed": n})
		"bless":
			var n := 0
			for s in sim.spatial.query_radius(sim.units, x + 0.5, y + 0.5, maxf(0.8, r)):
				sim.units.health[s] = sim.units.max_health[s]
				sim.units.hunger[s] = 0.0
				n += 1
			return _ok("", {"blessed": n})
	return _fail("Unknown power '%s'" % power)


static func _slot(sim: Simulation, cmd: Dictionary) -> int:
	return sim.units.slot_for(int(cmd.get("id", -1)))


static func _ok(msg: String = "", extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "msg": msg}
	d.merge(extra)
	return d


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
