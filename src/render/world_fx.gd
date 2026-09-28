class_name WorldFx
extends Node2D
## World-space overlays drawn above sprites: brush preview, selection marker,
## debug paths/targets and short-lived pixel effects for god powers.

const T := AssetForge.TILE

var sim: Simulation
var brush_tile := Vector2i(-1, -1)
var brush_radius: int = 2
var brush_visible := false
var brush_color := Color(1.0, 0.95, 0.7, 0.9)
var selected_unit: int = -1
var selected_city: int = -1
var unit_alpha: float = 1.0
var show_paths := false
var show_targets := false
var _effects: Array[Dictionary] = []


func add_effect(kind: String, tile: Vector2i, radius: int = 1) -> void:
	_effects.append({"kind": kind, "tile": tile, "r": radius, "t": 0.0})


func _process(delta: float) -> void:
	for e in _effects:
		e["t"] = float(e["t"]) + delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return float(e["t"]) < (1.6 if e["kind"] == "conquest" else 0.7))
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var z := maxf(0.25, get_viewport().get_canvas_transform().get_scale().x)
	var line := 1.5 / z
	if selected_city >= 0 and sim.cities.has(selected_city):
		var c: City = sim.cities[selected_city]
		var p := Vector2(c.center % sim.world.width, c.center / sim.world.width) * T
		draw_arc(p + Vector2(T, T) * 0.5, T * 2.2, 0, TAU, 32, Color(1, 0.9, 0.5, 0.8), line * 1.5)
	var s := sim.units.slot_for(selected_unit)
	if s >= 0:
		var u := sim.units
		var pos := Vector2(lerpf(u.prev_x[s], u.x[s], unit_alpha), lerpf(u.prev_y[s], u.y[s], unit_alpha)) * T
		var r := T * 0.9
		var cc := Color(1.0, 0.92, 0.45)
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			var o := Vector2(cos(a), sin(a)) * r
			draw_line(pos + o, pos + o * 0.6, cc, line * 1.4)
		_draw_path(s, Color(1, 0.9, 0.4, 0.8), line)
	if show_paths or show_targets:
		var rect := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
		var vt := Rect2(rect.position / T, rect.size / T)
		for os in sim.spatial.slots_in_rect(vt):
			if sim.units.alive[os] == 0:
				continue
			if show_paths:
				_draw_path(os, Color(0.4, 0.9, 1.0, 0.45), line * 0.7)
			if show_targets and sim.units.task_target[os] >= 0 and sim.units.task[os] in [UnitStore.Task.FORAGE, UnitStore.Task.FARM, UnitStore.Task.CHOP, UnitStore.Task.QUARRY, UnitStore.Task.DELIVER, UnitStore.Task.GO_HOME]:
				var ti := sim.units.task_target[os]
				var tp := Vector2(ti % sim.world.width + 0.5, ti / sim.world.width + 0.5) * T
				draw_line(Vector2(sim.units.x[os], sim.units.y[os]) * T, tp, Color(1, 0.5, 0.2, 0.5), line * 0.7)
				draw_rect(Rect2(tp - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.5, 0.2, 0.8), false, line * 0.7)
	if brush_visible and brush_tile.x >= 0:
		_draw_brush(line)
	for e in _effects:
		_draw_effect(e, line)


func _draw_path(s: int, col: Color, width: float) -> void:
	var p: PackedInt32Array = sim.units.path.get(s, PackedInt32Array())
	if p.is_empty():
		return
	var w := sim.world.width
	var pts := PackedVector2Array([Vector2(sim.units.x[s], sim.units.y[s]) * T])
	for k in range(sim.units.path_pos[s], p.size()):
		pts.append(Vector2(p[k] % w + 0.5, p[k] / w + 0.5) * T)
	if pts.size() >= 2:
		draw_polyline(pts, col, width)


## Tile-aligned brush outline: only edges between inside/outside tiles are drawn.
func _draw_brush(line: float) -> void:
	var r := brush_radius
	var fill := Color(brush_color, 0.12)
	var inside := func(dx: int, dy: int) -> bool: return dx * dx + dy * dy <= r * r + r
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not inside.call(dx, dy):
				continue
			var p := Vector2(brush_tile.x + dx, brush_tile.y + dy) * T
			draw_rect(Rect2(p, Vector2(T, T)), fill)
			if not inside.call(dx - 1, dy):
				draw_line(p, p + Vector2(0, T), brush_color, line)
			if not inside.call(dx + 1, dy):
				draw_line(p + Vector2(T, 0), p + Vector2(T, T), brush_color, line)
			if not inside.call(dx, dy - 1):
				draw_line(p, p + Vector2(T, 0), brush_color, line)
			if not inside.call(dx, dy + 1):
				draw_line(p + Vector2(0, T), p + Vector2(T, T), brush_color, line)


func _draw_effect(e: Dictionary, line: float) -> void:
	var t: float = e["t"] / 0.7
	var tile: Vector2i = e["tile"]
	var c := (Vector2(tile) + Vector2(0.5, 0.5)) * T
	var r := float(e["r"]) * T
	match e["kind"]:
		"smite":
			var a := 1.0 - t
			var x := c.x
			var y := c.y - 400.0
			var pts := PackedVector2Array([Vector2(x, y)])
			var rng := RandomNumberGenerator.new()
			rng.seed = int(tile.x * 7919 + tile.y)
			while y < c.y:
				y += 24.0
				x += rng.randf_range(-10, 10)
				pts.append(Vector2(x, minf(y, c.y)))
			draw_polyline(pts, Color(1.0, 0.98, 0.7, a), 3.0 * line + 2.0)
			draw_polyline(pts, Color(1, 1, 1, a), line + 1.0)
			draw_circle(c, r * (0.5 + t), Color(1, 0.9, 0.5, 0.35 * a))
		"spawn", "bless":
			var col := Color(0.7, 1.0, 0.8) if e["kind"] == "spawn" else Color(1.0, 0.95, 0.6)
			for k in 10:
				var ang := k * TAU / 10.0 + t * 2.0
				var p := c + Vector2(cos(ang), sin(ang)) * (4.0 + r * t)
				draw_rect(Rect2(p - Vector2(1, 1) - Vector2(0, t * 10.0), Vector2(2, 2)), Color(col, 1.0 - t))
		"hit":
			var a2 := 1.0 - t
			for k in 5:
				var ang := k * TAU / 5.0 + float(tile.x * 3 + tile.y)
				var p := c + Vector2(cos(ang), sin(ang)) * (1.0 + t * 7.0) - Vector2(0, 4)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.35 + 0.5 * float(k % 2), 0.25, a2))
		"conquest":
			var tt: float = e["t"] / 1.6
			draw_arc(c, 6.0 + tt * 40.0, 0, TAU, 40, Color(1.0, 0.85, 0.3, 1.0 - tt), 3.0)
			draw_arc(c, 3.0 + tt * 26.0, 0, TAU, 40, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - tt)), 2.0)
		"terrain":
			for k in 8:
				var ang := k * TAU / 8.0
				var p := c + Vector2(cos(ang), sin(ang)) * (r + t * 6.0)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 0.75, 0.55, 0.8 * (1.0 - t)))
