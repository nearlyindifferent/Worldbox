class_name CityLabels
extends Control
## Screen-space name banners that track each city's town hall. Clicking a banner
## selects the city. Larger cities win when banners would overlap.

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
	var vp := get_viewport_rect()
	# Biggest cities claim screen space first; overlapping smaller banners are hidden.
	var order: Array = sim.cities.values()
	order.sort_custom(func(a: City, b: City) -> bool: return a.population() > b.population() or (a.population() == b.population() and a.id < b.id))
	var placed: Array[Rect2] = []
	var seen := {}
	for c: City in order:
		seen[c.id] = true
		var b: Button = _pool.get(c.id, null)
		if b == null:
			b = _make(c)
			_pool[c.id] = b
		var k: Kingdom = sim.kingdoms.get(c.kingdom, null)
		var capital := k != null and k.capital == c.id
		var war := k != null and sim.realm.is_at_war(k.id)
		b.text = "%s  %d" % [c.name, c.population()]
		b.icon = UiTheme.icon("incite_war" if war else ("crown" if capital else "city"))
		if b.get_meta("style", -1) != int(war) * 2 + int(capital) or b.get_meta("color", -1) != c.color_index:
			b.set_meta("style", int(war) * 2 + int(capital))
			b.set_meta("color", c.color_index)
			var col := Color(AssetForge.CITY_COLORS[c.color_index])
			var border := Color("#e0503c") if war else col
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("#1c1512", 0.88), border, Color(0, 0, 0, 0), 3, 3 if war else 2))
			b.add_theme_stylebox_override("hover", UiTheme.box(Color("#2c221d", 0.95), border.lightened(0.3), Color(0, 0, 0, 0), 3, 3 if war else 2))
		# Anchor above the town hall roof (hall top-left is center - (1,1)).
		var world_pos := (Vector2(c.center % sim.world.width, c.center / sim.world.width) + Vector2(0.0, -2.2)) * AssetForge.TILE
		var sp := xf * world_pos
		b.reset_size()
		var r := Rect2((sp - Vector2(b.size.x * 0.5, b.size.y)).round(), b.size)
		var show := vp.grow(-4).intersects(r)
		if show and zoom < 0.55 and c.population() < 6 and placed.size() > 0:
			show = false
		if show:
			for other in placed:
				if other.grow(2).intersects(r):
					show = false
					break
		b.visible = show
		if show:
			placed.append(r)
			b.position = r.position
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
