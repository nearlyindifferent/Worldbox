class_name Game
extends Node
## Composition root and god layer controller. Owns the Simulation, drives the
## fixed-tick loop from frame time, routes input to powers/camera, and exposes a
## small API used by the UI and the automation harness.

signal world_changed
signal selection_changed
signal power_changed
signal speed_changed
signal toast(msg: String, good: bool)

const SPEEDS := [0, 1, 2, 5, 10]
const SPEED_ICONS := ["pause", "play", "fast", "faster", "fastest"]
const FRAME_SIM_BUDGET_MS := 14.0
const AUTOSAVE_YEARS := 10
const MAX_BRUSH := 12

## Set before adding the scene to the tree to control startup (used by tools/tests).
static var boot := {"seed": -1, "size": "medium", "shape": "island", "load": ""}

var sim: Simulation
var saves := SaveManager.new()
var speed_index: int = 1
var admin_speed: int = 0  ## admin override (ticks/sec multiplier), 0 = use SPEEDS
var power: String = "inspect"
var brush_radius: int = 3
var selected_unit: int = -1
var selected_city: int = -1
var sim_lagging := false
var ticks_last_frame: int = 0
var sim_ms_last_frame: float = 0.0

var world_root := Node2D.new()
var terrain := TerrainView.new()
var buildings_view := BuildingView.new()
var units_view := UnitView.new()
var fx := WorldFx.new()
var camera := CameraRig.new()
var ui_layer := CanvasLayer.new()
var ui: GameUi

var _acc := 0.0
var _stroke_active := false
var _stroke_timer := 0.0
var _last_brush_tile := Vector2i(-1, -1)
var _mouse_over_ui := false
var _last_autosave_year := 0
var pending_teleport_id: int = -1


func _ready() -> void:
	Defs.ensure_loaded()
	get_viewport().gui_embed_subwindows = true
	# Outside the world reads as open sea rather than an engine-grey void.
	RenderingServer.set_default_clear_color(Color("#0d1a3c"))
	add_child(world_root)
	world_root.add_child(terrain)
	world_root.add_child(buildings_view)
	world_root.add_child(units_view)
	world_root.add_child(fx)
	add_child(camera)
	camera.make_current()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui = GameUi.new()
	ui.game = self
	ui_layer.add_child(ui)
	if str(boot.get("load", "")) != "":
		if not load_world(boot["load"]):
			new_world(_boot_seed(), boot["size"], boot["shape"])
	else:
		new_world(_boot_seed(), boot["size"], boot["shape"])


func _boot_seed() -> int:
	var s := int(boot.get("seed", -1))
	return s if s >= 0 else int(Time.get_unix_time_from_system()) % 1000000


# ------------------------------------------------------------------ world lifecycle

func new_world(p_seed: int, size_name: String, shape: String) -> void:
	var sz: Vector2i = WorldGen.SIZE_PRESETS.get(size_name, WorldGen.SIZE_PRESETS["medium"])
	_install(Simulation.create_new(p_seed, sz.x, sz.y, shape))
	toast.emit("A new world rises (seed %d)" % p_seed, true)


func _install(new_sim: Simulation) -> void:
	sim = new_sim
	terrain.bind(sim)
	buildings_view.sim = sim
	units_view.sim = sim
	fx.sim = sim
	camera.setup_world(terrain.world_pixel_size())
	selected_unit = -1
	selected_city = -1
	_acc = 0.0
	_last_autosave_year = sim.year()
	world_changed.emit()
	selection_changed.emit()


func save_world(slot: String) -> bool:
	var meta := {"camera": [camera.position.x, camera.position.y, camera.zoom.x]}
	var r := saves.save_slot(sim, slot, MapImage.render(sim, 192), meta)
	toast.emit(("Saved \"%s\" (%d KB, %d ms)" % [slot, int(r.get("bytes", 0)) / 1024, int(r.get("ms", 0))]) if r["ok"] else str(r["msg"]), r["ok"])
	return r["ok"]


func load_world(slot: String) -> bool:
	var r := saves.load_slot(slot)
	if not r["ok"]:
		toast.emit("Load failed: %s" % r["msg"], false)
		return false
	_install(r["sim"])
	var meta := saves.read_meta(slot)
	var cam: Array = meta.get("camera", [])
	if cam.size() == 3:
		camera.jump_to(Vector2(cam[0], cam[1]), float(cam[2]))
		camera.position = camera.target_pos
	toast.emit("Loaded \"%s\" (%d ms)" % [slot, int(r["ms"])], true)
	return true


# ------------------------------------------------------------------ time

func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	admin_speed = 0
	speed_changed.emit()


func toggle_pause() -> void:
	if speed_index == 0:
		set_speed(_resume_speed)
	else:
		_resume_speed = speed_index
		set_speed(0)


var _resume_speed := 1


func ticks_per_second() -> float:
	if admin_speed > 0:
		return float(SimConst.TICKS_PER_SECOND * admin_speed)
	return float(SimConst.TICKS_PER_SECOND * SPEEDS[speed_index])


func _process(delta: float) -> void:
	if sim == null:
		return
	var tps := ticks_per_second()
	ticks_last_frame = 0
	var t0 := Time.get_ticks_usec()
	sim_lagging = false
	if tps > 0.0:
		_acc += delta * tps
		while _acc >= 1.0:
			sim.step()
			_acc -= 1.0
			ticks_last_frame += 1
			if (Time.get_ticks_usec() - t0) / 1000.0 > FRAME_SIM_BUDGET_MS:
				# Simulation cannot keep up: run slower instead of skipping logic.
				sim_lagging = _acc >= 1.0
				_acc = minf(_acc, 1.0)
				break
	sim_ms_last_frame = (Time.get_ticks_usec() - t0) / 1000.0
	if ticks_last_frame > 0 and sim.year() >= _last_autosave_year + AUTOSAVE_YEARS:
		_last_autosave_year = sim.year()
		saves.save_slot(sim, saves.next_autosave_slot(), MapImage.render(sim, 192), {"autosave": true})
	var alpha := clampf(_acc, 0.0, 1.0) if tps > 0.0 else 1.0
	units_view.alpha = alpha
	fx.unit_alpha = alpha
	_apply_held_brush(delta)
	var vr := camera.visible_tiles_rect()
	terrain.set_zoom_hint(camera.current_zoom())
	buildings_view.update_view(vr)
	units_view.selected_id = selected_unit
	units_view.update_view(vr, camera.current_zoom(), delta)


# ------------------------------------------------------------------ powers & selection

func set_power(id: String) -> void:
	power = id
	fx.brush_visible = Powers.DEFS[id]["brush"]
	fx.brush_color = Powers.brush_color(id)
	power_changed.emit()


func set_brush_radius(r: int) -> void:
	brush_radius = clampi(r, 0, MAX_BRUSH)
	fx.brush_radius = brush_radius
	power_changed.emit()


func select_unit(uid: int) -> void:
	selected_unit = uid
	selected_city = -1
	fx.selected_unit = uid
	fx.selected_city = -1
	selection_changed.emit()


func select_city(cid: int) -> void:
	selected_city = cid
	selected_unit = -1
	fx.selected_city = cid
	fx.selected_unit = -1
	selection_changed.emit()


func focus_unit(uid: int) -> void:
	var s := sim.units.slot_for(uid)
	if s >= 0:
		select_unit(uid)
		camera.jump_to(Vector2(sim.units.x[s], sim.units.y[s]) * AssetForge.TILE, maxf(camera.target_zoom, 3.0))


func focus_city(cid: int) -> void:
	var c: City = sim.cities.get(cid, null)
	if c != null:
		select_city(cid)
		camera.jump_to(tile_center_px(c.center), maxf(camera.target_zoom, 2.0))


func focus_tile(i: int) -> void:
	if i >= 0:
		camera.jump_to(tile_center_px(i), maxf(camera.target_zoom, 2.5))


func is_following() -> bool:
	return camera.follow_callable.is_valid()


func follow_selected() -> void:
	var uid := selected_unit
	camera.follow(func() -> Variant:
		var s := sim.units.slot_for(uid)
		return null if s < 0 else Vector2(sim.units.x[s], sim.units.y[s]) * AssetForge.TILE)


func tile_center_px(i: int) -> Vector2:
	return (Vector2(i % sim.world.width, i / sim.world.width) + Vector2(0.5, 0.5)) * AssetForge.TILE


func mouse_tile() -> Vector2i:
	var wp := world_root.get_global_mouse_position() / AssetForge.TILE
	return Vector2i(floori(wp.x), floori(wp.y))


func undo() -> void:
	var r := sim.apply_command({"op": "undo"})
	toast.emit(str(r["msg"]), r["ok"])


func command(cmd: Dictionary) -> Dictionary:
	var r := sim.apply_command(cmd)
	if not r["ok"]:
		toast.emit(str(r["msg"]), false)
	return r


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if camera.handle_input(event):
		return
	if event is InputEventMouseMotion:
		var t := mouse_tile()
		fx.brush_tile = t
		ui.on_hover_tile(t)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_press()
			else:
				_end_stroke()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)


func _on_left_press() -> void:
	var t := mouse_tile()
	if pending_teleport_id >= 0:
		command({"op": "teleport", "id": pending_teleport_id, "x": t.x, "y": t.y})
		pending_teleport_id = -1
		return
	if power == "inspect":
		_inspect_at(t)
		return
	sim.apply_command({"op": "stroke_begin"})
	_stroke_active = true
	_stroke_timer = 0.0
	_apply_brush_at(t)


func _end_stroke() -> void:
	if _stroke_active:
		sim.apply_command({"op": "stroke_end"})
		_stroke_active = false
		_last_brush_tile = Vector2i(-1, -1)


func _apply_held_brush(delta: float) -> void:
	if not _stroke_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_stroke()
		return
	var rep: float = Powers.DEFS[power]["repeat"]
	if rep <= 0.0:
		return
	_stroke_timer += delta
	var t := mouse_tile()
	# Painting responds instantly to movement; holding still repeats on the interval.
	if (t != _last_brush_tile and Powers.effect_kind(power) == "terrain" and power != "raise" and power != "lower") or _stroke_timer >= rep:
		_stroke_timer = 0.0
		_apply_brush_at(t)


func _apply_brush_at(t: Vector2i) -> void:
	if not sim.world.in_bounds(t.x, t.y):
		return
	_last_brush_tile = t
	var r := sim.apply_command({"op": "brush", "power": power, "x": t.x, "y": t.y, "radius": brush_radius})
	if r["ok"]:
		fx.add_effect(Powers.effect_kind(power), t, brush_radius)
	elif str(r["msg"]) != "":
		toast.emit(str(r["msg"]), false)


func _inspect_at(t: Vector2i) -> void:
	var wp := world_root.get_global_mouse_position() / AssetForge.TILE
	sim.spatial.rebuild(sim.units)
	var s := sim.unit_at(wp.x, wp.y, 1.0)
	if s >= 0:
		select_unit(sim.units.id[s])
		return
	if sim.world.in_bounds(t.x, t.y):
		var i := sim.world.idx(t.x, t.y)
		var bid := sim.world.building[i]
		if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid):
			select_city((sim.buildings[bid] as Building).city)
			return
		if sim.world.owner[i] != SimConst.CITY_NONE:
			select_city(sim.world.owner[i])
			return
	select_unit(-1)


func _on_key(k: InputEventKey) -> void:
	if k.ctrl_pressed and k.keycode == KEY_Z:
		undo()
		return
	match k.keycode:
		KEY_SPACE:
			toggle_pause()
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_speed(k.keycode - KEY_1 + 1)
		KEY_BRACKETLEFT, KEY_MINUS:
			set_brush_radius(brush_radius - 1)
		KEY_BRACKETRIGHT, KEY_EQUAL:
			set_brush_radius(brush_radius + 1)
		KEY_F5:
			save_world("quicksave")
		KEY_F9:
			load_world("quicksave")
		KEY_ESCAPE:
			if selected_unit >= 0 or selected_city >= 0:
				select_unit(-1)
			else:
				ui.toggle_menu()
		KEY_F:
			if k.shift_pressed:
				if selected_unit >= 0:
					follow_selected()
			elif Powers.HOTKEYS.values().has(k.keycode):
				set_power(Powers.HOTKEYS.find_key(k.keycode))
		_:
			if Powers.HOTKEYS.values().has(k.keycode):
				set_power(Powers.HOTKEYS.find_key(k.keycode))
			else:
				ui.on_key(k)
