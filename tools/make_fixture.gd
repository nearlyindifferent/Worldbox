extends SceneTree
## Regenerates the current-schema golden fixture (run after bumping SAVE_SCHEMA):
##   godot --headless --path . -s res://tools/make_fixture.gd
func _init() -> void:
	var sim := Simulation.create_new(5, 96, 96, "island")
	for k in 1500:
		sim.step()
	sim.apply_command({"op": "stroke_begin"})
	sim.apply_command({"op": "brush", "power": "raise", "x": 30, "y": 30, "radius": 3})
	sim.apply_command({"op": "stroke_end"})
	var m := SaveManager.new("user://fixture_gen")
	m.save_slot(sim, "fx")
	var name := "schema%d_seed5_96" % Simulation.SAVE_SCHEMA
	DirAccess.copy_absolute(ProjectSettings.globalize_path(m.slot_dir("fx").path_join("world.sav")), ProjectSettings.globalize_path("res://tests/fixtures/%s.sav" % name))
	var f := FileAccess.open("res://tests/fixtures/%s.json" % name, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": Simulation.SAVE_SCHEMA, "tick": sim.tick, "units": sim.units.count, "hash": sim.state_hash()}, "  "))
	print("fixture ", name, " hash ", sim.state_hash())
	m.delete_slot("fx")
	quit()
