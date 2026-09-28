class_name CityLabels
extends Control
## Screen-space name banners that track each city's town hall. Clicking a banner
## selects the city. Banners fade when zoomed in close so they do not hide the town.

var game: Game
var _pool := {}  ## city id -> Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if game.sim == null:
		return
	var sim := game.sim
	var xf := get_viewport().get_canvas_transform()
	var zoom := game.camera.current_zoom()
	var seen := {}
	for c: City in sim.cities.values():
		if not c.alive:
			continue
		seen[c.id] = true
		var b: Button = _pool.get(c.id, null)
		if b == null:
			b = _make(c)
			_pool[c.id] = b
		b.text = "%s  %d" % [c.name, c.population()]
		var world_pos := (Vector2(c.center % sim.world.width, c.center / sim.world.width) + Vector2(0.5, -1.2)) * AssetForge.TILE
		var sp := xf * world_pos
		b.reset_size()
		b.position = (sp - Vector2(b.size.x * 0.5, b.size.y)).round()
		b.modulate.a = clampf(1.6 - zoom * 0.25, 0.35, 1.0)
		b.visible = get_viewport_rect().grow(100).has_point(sp)
	for id: int in _pool.keys():
		if not seen.has(id):
			(_pool[id] as Button).queue_free()
			_pool.erase(id)


func _make(c: City) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.icon = UiTheme.icon("city")
	var col := Color(AssetForge.CITY_COLORS[c.color_index])
	var sb := UiTheme.box(Color("#1c1512", 0.85), col, Color(0, 0, 0, 0), 3)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := UiTheme.box(Color("#2c221d", 0.95), col.lightened(0.3), Color(0, 0, 0, 0), 3)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var cid := c.id
	b.pressed.connect(func() -> void: game.focus_city(cid))
	b.tooltip_text = "Click to inspect %s" % c.name
	add_child(b)
	return b
