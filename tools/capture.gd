extends SceneTree
## Drives the real game (rendering + UI) through a scripted sequence and saves
## screenshots. Used for visual review and UI interaction evidence.
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path . \
##       -s res://tools/capture.gd -- --steps=res://tools/scenarios/overview.json --out=tools/out/shots
##
## Step ops: ticks{n} | frames{n} | realtime{sec} | shot{name} | zoom{value} | focus{target: city|unit|center|tile, index, x, y}
##   select_city{index} | select_unit{index} | power{id} | brush{x,y} (tile coords) | radius{value}
##   key{key, ctrl?, shift?} | click{x,y,button?} (screen) | drag{x0,y0,x1,y1,button?} | hover{x,y}
##   panel{name: admin|history|perf|menu, on} | speed{i} | save{slot} | load{slot} | new_world{seed,size,shape}
##   admin_tab{index} | overlay{index} | print{what: perf|hash|stats|selection} | assert_panel{name, visible}
##   record_start{name} | record_stop  (saves every rendered frame; run godot with --fixed-fps 30)
##   brush may use {"city": index, "dx", "dy"} instead of x/y to target tiles near a city

var _out := "res://tools/out/shots"
var game: Game
var _log := PackedStringArray()
var _recording := ""
var _rec_frame := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out = args.get("out", _out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out)
	Game.boot = {"seed": int(args.get("seed", "7")), "size": args.get("size", "medium"), "shape": args.get("shape", "island"), "load": args.get("load", "")}
	var steps: Array = []
	if args.has("steps"):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(args["steps"]))
		if typeof(v) == TYPE_ARRAY:
			steps = v
		else:
			push_error("capture: cannot parse steps file %s" % args["steps"])
			quit(2)
			return
	else:
		steps = [{"do": "frames", "n": 5}, {"do": "shot", "name": "default"}]
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	game = main as Game
	_run(steps)


func _run(steps: Array) -> void:
	await process_frame
	await process_frame
	for st: Dictionary in steps:
		await _step(st)
	print("\n".join(_log))
	quit(0)


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _step(st: Dictionary) -> void:
	var op: String = st.get("do", "")
	match op:
		"ticks":
			var t0 := Time.get_ticks_msec()
			for k in int(st["n"]):
				game.sim.step()
			_log.append("ticks %d in %d ms (now %s)" % [int(st["n"]), Time.get_ticks_msec() - t0, game.sim.date_string()])
			game.terrain.refresh(true)
			await _frames(3)
		"frames":
			await _frames(int(st.get("n", 1)))
		"realtime":
			var end := Time.get_ticks_msec() + int(float(st["sec"]) * 1000.0)
			var frames := 0
			while Time.get_ticks_msec() < end:
				await process_frame
				frames += 1
			_log.append("realtime %.1fs: %d frames" % [float(st["sec"]), frames])
		"shot":
			game.camera.position = game.camera.target_pos
			game.camera.zoom = Vector2(game.camera.target_zoom, game.camera.target_zoom)
			await _frames(3)
			var img := root.get_texture().get_image()
			var path := _out.path_join(str(st["name"]) + ".png")
			img.save_png(path)
			_log.append("shot %s" % path)
		"zoom":
			game.camera.target_zoom = float(st["value"])
			await _frames(2)
		"focus":
			match str(st.get("target", "center")):
				"city":
					var cs := game.sim.cities.values()
					if cs.size() > int(st.get("index", 0)):
						var c: City = cs[int(st.get("index", 0))]
						game.camera.jump_to(game.tile_center_px(c.center), float(st.get("zoom", game.camera.target_zoom)))
				"unit":
					var s := _nth_unit(int(st.get("index", 0)), st.get("species", "human"))
					if s >= 0:
						game.camera.jump_to(Vector2(game.sim.units.x[s], game.sim.units.y[s]) * AssetForge.TILE, float(st.get("zoom", game.camera.target_zoom)))
				"tile":
					game.camera.jump_to(game.tile_center_px(game.sim.world.idx(int(st["x"]), int(st["y"]))), float(st.get("zoom", game.camera.target_zoom)))
				_:
					game.camera.jump_to(game.terrain.world_pixel_size() * 0.5, float(st.get("zoom", game.camera.target_zoom)))
			await _frames(2)
		"select_city":
			var cs2 := game.sim.cities.values()
			if cs2.size() > int(st.get("index", 0)):
				game.focus_city((cs2[int(st.get("index", 0))] as City).id)
			await _frames(3)
		"select_unit":
			var s2 := _nth_unit(int(st.get("index", 0)), st.get("species", "human"))
			if s2 >= 0:
				game.focus_unit(game.sim.units.id[s2])
			await _frames(3)
		"power":
			game.set_power(st["id"])
			await _frames(1)
		"radius":
			game.set_brush_radius(int(st["value"]))
		"record_start":
			_recording = str(st.get("name", "clip"))
			_rec_frame = 0
		"record_stop":
			_log.append("recorded %d frames of %s" % [_rec_frame, _recording])
			_recording = ""
		"brush":
			var bx := int(st.get("x", 0))
			var by := int(st.get("y", 0))
			if st.has("city"):
				var cl := game.sim.cities.values()
				if cl.size() > int(st["city"]):
					var cc: City = cl[int(st["city"])]
					bx = cc.center % game.sim.world.width + int(st.get("dx", 0))
					by = cc.center / game.sim.world.width + int(st.get("dy", 0))
			game.fx.brush_tile = Vector2i(bx, by)
			game.sim.apply_command({"op": "stroke_begin"})
			var r := game.sim.apply_command({"op": "brush", "power": game.power, "x": bx, "y": by, "radius": game.brush_radius})
			game.sim.apply_command({"op": "stroke_end"})
			game.fx.add_effect(Powers.effect_kind(game.power), Vector2i(bx, by), game.brush_radius)
			_log.append("brush %s -> %s" % [game.power, str(r)])
			await _frames(2)
		"key":
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(str(st["key"]))
			ev.physical_keycode = ev.keycode
			ev.ctrl_pressed = bool(st.get("ctrl", false))
			ev.shift_pressed = bool(st.get("shift", false))
			ev.pressed = true
			Input.parse_input_event(ev)
			await _frames(1)
			var up := ev.duplicate() as InputEventKey
			up.pressed = false
			Input.parse_input_event(up)
			await _frames(2)
		"hover":
			_mouse_move(Vector2(float(st["x"]), float(st["y"])))
			await _frames(2)
		"click":
			var p := Vector2(float(st["x"]), float(st["y"]))
			var btn := int(st.get("button", MOUSE_BUTTON_LEFT))
			_mouse_move(p)
			await _frames(1)
			_mouse_button(p, btn, true)
			await _frames(2)
			_mouse_button(p, btn, false)
			await _frames(3)
		"drag":
			var a := Vector2(float(st["x0"]), float(st["y0"]))
			var b := Vector2(float(st["x1"]), float(st["y1"]))
			var dbtn := int(st.get("button", MOUSE_BUTTON_LEFT))
			_mouse_move(a)
			await _frames(1)
			_mouse_button(a, dbtn, true)
			for k in 12:
				_mouse_move(a.lerp(b, (k + 1) / 12.0), dbtn)
				await _frames(1)
			_mouse_button(b, dbtn, false)
			await _frames(3)
		"panel":
			var on := bool(st.get("on", true))
			match str(st["name"]):
				"admin":
					if game.ui.admin.visible != on:
						game.ui.toggle_admin()
				"history":
					game.ui.history.visible = on
				"perf":
					game.ui.perf.visible = on
				"menu":
					if game.ui.menu.visible != on:
						game.ui.toggle_menu()
			await _frames(3)
		"admin_tab":
			game.ui.admin._tabs.current_tab = int(st["index"])
			await _frames(3)
		"overlay":
			game.terrain.set_overlay(int(st["index"]))
			await _frames(2)
		"speed":
			game.set_speed(int(st["i"]))
		"save":
			_log.append("save %s -> %s" % [st["slot"], str(game.save_world(st["slot"]))])
		"load":
			_log.append("load %s -> %s" % [st["slot"], str(game.load_world(st["slot"]))])
			await _frames(3)
		"new_world":
			game.new_world(int(st.get("seed", 1)), st.get("size", "medium"), st.get("shape", "island"))
			await _frames(3)
		"print":
			match str(st["what"]):
				"perf":
					_log.append(PerfOverlay.report(game))
				"hash":
					_log.append("hash %s tick %d" % [game.sim.state_hash(), game.sim.tick])
				"stats":
					_log.append("humans %d sheep %d cities %d buildings %d %s" % [game.sim.count_species(0), game.sim.count_species(1), game.sim.cities.size(), game.sim.buildings.size(), game.sim.date_string()])
				"selection":
					_log.append("selected unit %d city %d power %s radius %d speed %d" % [game.selected_unit, game.selected_city, game.power, game.brush_radius, game.speed_index])
		"assert_panel":
			var vis := false
			match str(st["name"]):
				"admin":
					vis = game.ui.admin.visible
				"history":
					vis = game.ui.history.visible
				"perf":
					vis = game.ui.perf.visible
				"menu":
					vis = game.ui.menu.visible
				"inspector":
					vis = game.ui.inspector.visible
			_log.append("assert_panel %s visible=%s expected=%s %s" % [st["name"], vis, st["visible"], "OK" if vis == bool(st["visible"]) else "MISMATCH"])
		_:
			_log.append("unknown step %s" % op)


func _on_frame_drawn() -> void:
	if _recording == "":
		return
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%05d.png" % [_recording, _rec_frame]))
	_rec_frame += 1


func _nth_unit(n: int, species: String) -> int:
	var sp := Defs.species_by_id(species).index
	var k := 0
	for s in game.sim.units.capacity:
		if game.sim.units.alive[s] == 1 and game.sim.units.species[s] == sp:
			if k == n:
				return s
			k += 1
	return -1


func _mouse_move(p: Vector2, held: int = 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	if held != 0:
		ev.button_mask = 1 << (held - 1)
	Input.warp_mouse(p)
	Input.parse_input_event(ev)


func _mouse_button(p: Vector2, btn: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = btn
	ev.pressed = pressed
	if pressed:
		ev.button_mask = 1 << (btn - 1)
	Input.parse_input_event(ev)
