class_name CameraRig
extends Camera2D
## Smooth god camera: right/middle drag, wheel zoom toward cursor, WASD/arrows,
## trackpad pan/pinch gestures, follow target, jump-to, bounded to the world.

signal moved

const MIN_ZOOM := 0.3
const MAX_ZOOM := 8.0
const KEY_PAN_SPEED := 900.0
const ZOOM_STEP := 1.15
const SMOOTH := 14.0

var world_px := Vector2(2048, 2048)
var target_zoom: float = 1.5
var target_pos := Vector2.ZERO
var follow_callable: Callable
var _dragging := false
var _drag_last := Vector2.ZERO
var input_enabled := true
## Active touch points (index -> screen position) for two-finger pan / pinch.
var _touches := {}
var _shake_amp := 0.0
var _shake_left := 0.0


func multi_touch_active() -> bool:
	return _touches.size() >= 2


func _ready() -> void:
	zoom = Vector2(target_zoom, target_zoom)
	target_pos = position


func setup_world(px_size: Vector2) -> void:
	world_px = px_size
	target_pos = px_size * 0.5
	position = target_pos
	target_zoom = clampf(minf(get_viewport_rect().size.x / px_size.x, get_viewport_rect().size.y / px_size.y) * 1.6, MIN_ZOOM, 3.0)
	zoom = Vector2(target_zoom, target_zoom)


func jump_to(world_pos: Vector2, new_zoom: float = -1.0) -> void:
	target_pos = world_pos
	if new_zoom > 0.0:
		target_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	follow_callable = Callable()


func follow(c: Callable) -> void:
	follow_callable = c


func current_zoom() -> float:
	return zoom.x


func handle_input(event: InputEvent) -> bool:
	if not input_enabled:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(ZOOM_STEP, mb.position)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / ZOOM_STEP, mb.position)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_drag_last = mb.position
			return true
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		target_pos -= (mm.position - _drag_last) / zoom.x
		_drag_last = mm.position
		follow_callable = Callable()
		return true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		return _touches.size() >= 2
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return false
		var before: Vector2 = _touches[sd.index]
		if _touches.size() >= 2:
			# Pinch: scale by the change in finger spread around the midpoint; pan by half the drag.
			var other := Vector2.ZERO
			for k: int in _touches:
				if k != sd.index:
					other = _touches[k]
					break
			var d0 := before.distance_to(other)
			var d1 := sd.position.distance_to(other)
			if d0 > 8.0 and d1 > 8.0:
				_zoom_at(d1 / d0, (sd.position + other) * 0.5)
			target_pos -= (sd.position - before) * 0.5 / zoom.x
			follow_callable = Callable()
		_touches[sd.index] = sd.position
		return _touches.size() >= 2
	elif event is InputEventMagnifyGesture:
		var g := event as InputEventMagnifyGesture
		_zoom_at(g.factor, g.position)
		return true
	elif event is InputEventPanGesture:
		var p := event as InputEventPanGesture
		target_pos += p.delta * 12.0 / zoom.x
		follow_callable = Callable()
		return true
	return false


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := _screen_to_world_target(screen_pos)
	target_zoom = clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var after := _screen_to_world_target(screen_pos)
	target_pos += before - after


func _screen_to_world_target(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return target_pos + (screen_pos - vp * 0.5) / target_zoom


## Screen shake for quakes and impacts (presentation only; amplitude in screen pixels).
func shake(amplitude: float, duration: float) -> void:
	_shake_amp = maxf(_shake_amp, amplitude)
	_shake_left = maxf(_shake_left, duration)


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		var a := _shake_amp * clampf(_shake_left * 2.0, 0.0, 1.0) / maxf(zoom.x, 0.01)
		offset = Vector2(randf_range(-a, a), randf_range(-a, a))
		if _shake_left <= 0.0:
			_shake_amp = 0.0
			offset = Vector2.ZERO
	var move := Vector2.ZERO
	if input_enabled and not _text_focused():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1
	if move != Vector2.ZERO:
		target_pos += move.normalized() * KEY_PAN_SPEED * delta / zoom.x
		follow_callable = Callable()
	if follow_callable.is_valid():
		var p: Variant = follow_callable.call()
		if p == null:
			follow_callable = Callable()
		else:
			target_pos = p
	target_pos = _clamp_to_world(target_pos, target_zoom)
	var k := 1.0 - exp(-SMOOTH * delta)
	var old := position
	position = position.lerp(target_pos, k)
	var z := lerpf(zoom.x, target_zoom, k)
	zoom = Vector2(z, z)
	if old.distance_squared_to(position) > 0.01 or absf(z - target_zoom) > 0.0001:
		moved.emit()


## Keeps the view inside the world (plus a small shore margin); centers the axis
## when the world is smaller than the view at the current zoom.
func _clamp_to_world(p: Vector2, z: float) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / maxf(z, 0.01)
	var margin := Vector2(48, 48)
	var out := p
	for axis in 2:
		var lo := half[axis] - margin[axis]
		var hi := world_px[axis] - half[axis] + margin[axis]
		out[axis] = world_px[axis] * 0.5 if lo > hi else clampf(p[axis], lo, hi)
	return out


func _text_focused() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox


## Visible world rectangle in tile units.
func visible_tiles_rect() -> Rect2:
	var vp := get_viewport_rect().size / zoom.x
	var r := Rect2(position - vp * 0.5, vp)
	return Rect2(r.position / AssetForge.TILE, r.size / AssetForge.TILE)


## Pans by a screen-space delta (used for one-finger / left-drag panning).
func pan_screen(delta_px: Vector2) -> void:
	target_pos -= delta_px / zoom.x
	follow_callable = Callable()
