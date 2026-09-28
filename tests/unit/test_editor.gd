extends TestCase


func test_brush_changes_and_undo_restores_exactly() -> void:
	var sim := Simulation.create_new(3, 96, 96, "island", false)
	var before := TestWorlds.world_hash(sim)
	for power in ["raise", "lower", "paint_ocean", "paint_forest", "paint_mountain", "paint_sand"]:
		sim.apply_command({"op": "stroke_begin"})
		for k in 5:
			sim.apply_command({"op": "brush", "power": power, "x": 40 + k, "y": 44, "radius": 4})
		sim.apply_command({"op": "stroke_end"})
	assert_ne(TestWorlds.world_hash(sim), before, "brushes changed the world")
	for k in 6:
		assert_true(sim.apply_command({"op": "undo"})["ok"], "undo %d" % k)
	assert_eq(TestWorlds.world_hash(sim), before, "undo restores the exact original world")
	assert_false(sim.apply_command({"op": "undo"})["ok"], "empty undo stack reports failure")


func test_brush_radius_scales_area() -> void:
	var sim := TestWorlds.flat(96)
	var small: int = sim.apply_command({"op": "brush", "power": "paint_desert", "x": 30, "y": 30, "radius": 1})["changed"]
	var big: int = sim.apply_command({"op": "brush", "power": "paint_desert", "x": 60, "y": 60, "radius": 6})["changed"]
	assert_true(big > small * 8, "radius 6 affects many more tiles (%d vs %d)" % [big, small])


func test_raising_sea_creates_land_and_pathfinder_updates() -> void:
	var sim := Simulation.create_new(3, 96, 96, "island", false)
	var w := sim.world
	var i := w.idx(5, 48)
	assert_true(w.is_water(i))
	for k in 30:
		sim.apply_command({"op": "brush", "power": "raise", "x": 5, "y": 48, "radius": 2})
	assert_false(w.is_water(i), "raised above sea level")
	sim.pathfinder.sync_changes()


func test_spawn_smite_bless_powers() -> void:
	var sea := Simulation.create_new(3, 96, 96, "island", false)
	assert_false(sea.apply_command({"op": "brush", "power": "spawn_sheep", "x": 0, "y": 0, "radius": 0})["ok"], "cannot spawn in open sea far from land")
	var sim := TestWorlds.flat(64)
	var r: Dictionary = sim.apply_command({"op": "brush", "power": "spawn_human", "x": 30, "y": 30, "radius": 4})
	assert_true(r["ok"] and int(r["spawned"]) >= 1, "spawned humans")
	sim.spatial.rebuild(sim.units)
	var n := sim.units.count
	var k: Dictionary = sim.apply_command({"op": "brush", "power": "smite", "x": 30, "y": 30, "radius": 8})
	assert_eq(sim.units.count, n - int(k["killed"]))
	assert_true(int(k["killed"]) >= 1)


func test_admin_commands() -> void:
	var sim := TestWorlds.flat(96)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 6)
	var uid := sim.units.id[band[0]]
	assert_true(sim.apply_command({"op": "set_health", "id": uid, "value": 5})["ok"])
	assert_eq(sim.units.health[sim.units.slot_for(uid)], 5.0)
	sim.apply_command({"op": "set_age", "id": uid, "value": 40})
	assert_between(sim.units.age_years(sim.units.slot_for(uid), sim.tick), 39.9, 40.1, "age set")
	var fc: Dictionary = sim.apply_command({"op": "found_city", "id": uid})
	assert_true(fc["ok"], "forced founding: " + str(fc["msg"]))
	var cid := int(fc.get("city", -1))
	assert_true(sim.apply_command({"op": "add_resource", "city": cid, "res": "wood", "amount": 50})["ok"])
	assert_eq(float((sim.cities[cid] as City).storage["wood"]), 50.0)
	sim.apply_command({"op": "add_resource", "city": cid, "res": "wood", "amount": -500})
	assert_eq(float((sim.cities[cid] as City).storage["wood"]), 0.0, "removal clamps at zero")
	var dup: Dictionary = sim.apply_command({"op": "duplicate_unit", "id": uid})
	assert_true(dup["ok"])
	assert_true((sim.cities[cid] as City).members.has(int(dup["id"])), "duplicate joins the same city")
	assert_true(sim.apply_command({"op": "teleport", "id": uid, "x": 20, "y": 20})["ok"])
	assert_between(sim.units.x[sim.units.slot_for(uid)], 19.0, 22.0, "teleported")
	sim.apply_command({"op": "set_flag", "id": uid, "flag": UnitStore.Flag.FROZEN, "on": true})
	var px := sim.units.x[sim.units.slot_for(uid)]
	run_ticks(sim, 50)
	assert_eq(sim.units.x[sim.units.slot_for(uid)], px, "frozen unit does not act")
	assert_false(sim.apply_command({"op": "nonsense"})["ok"], "unknown command rejected")
	assert_true(sim.apply_command({"op": "abandon_city", "city": cid})["ok"])
	sim.step()
	assert_no_violations(sim, "admin ops")
