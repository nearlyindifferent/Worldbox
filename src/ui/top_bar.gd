class_name TopBar
extends PanelContainer
## Date, time controls and world summary.

var game: Game
var _date := Label.new()
var _speed_buttons: Array[Button] = []
var _pop := Label.new()
var _cities := Label.new()
var _animals := Label.new()
var _lag := Label.new()
var _timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var title := UiTheme.label("HEARTHMERE", "GoldLabel")
	row.add_child(title)
	row.add_child(_vsep())
	_date.custom_minimum_size = Vector2(230, 0)
	row.add_child(UiTheme.icon_rect("world", 24))
	row.add_child(_date)

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 2)
	for k in Game.SPEEDS.size():
		var b := Button.new()
		b.theme_type_variation = "ToolButton"
		b.icon = UiTheme.icon(Game.SPEED_ICONS[k])
		b.expand_icon = false
		b.custom_minimum_size = Vector2(40, 36)
		b.toggle_mode = true
		b.tooltip_text = ("Pause  [Space]" if k == 0 else "Speed %dx  [%d]" % [Game.SPEEDS[k], k])
		b.pressed.connect(game.set_speed.bind(k))
		b.focus_mode = Control.FOCUS_NONE
		speeds.add_child(b)
		_speed_buttons.append(b)
	row.add_child(speeds)
	_lag.text = ""
	_lag.theme_type_variation = "MutedLabel"
	row.add_child(_lag)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UiTheme.icon_rect("people", 24))
	row.add_child(_pop)
	row.add_child(UiTheme.icon_rect("city", 24))
	row.add_child(_cities)
	row.add_child(UiTheme.icon_rect("spawn_sheep", 24))
	row.add_child(_animals)
	row.add_child(_vsep())
	for spec: Array in [["history", "Chronicle  [T]", func() -> void: game.ui.toggle_history()],
			["save", "Save / Load / New world  [Esc]", func() -> void: game.ui.toggle_menu()],
			["perf", "Performance overlay  [F3]", func() -> void: game.ui.perf.visible = not game.ui.perf.visible],
			["admin", "Admin panel  [F1]", func() -> void: game.ui.toggle_admin()]]:
		var b := Button.new()
		b.theme_type_variation = "ToolButton"
		b.icon = UiTheme.icon(spec[0])
		b.tooltip_text = spec[1]
		b.custom_minimum_size = Vector2(40, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[2])
		row.add_child(b)
	game.speed_changed.connect(_sync_speed)
	_sync_speed()


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	return s


func _sync_speed() -> void:
	for k in _speed_buttons.size():
		_speed_buttons[k].set_pressed_no_signal(k == game.speed_index and game.admin_speed == 0)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.2 or game.sim == null:
		return
	_timer = 0.0
	var sim := game.sim
	_date.text = sim.date_string()
	var humans := sim.count_species(sim.human_species)
	_pop.text = str(humans)
	_cities.text = str(sim.cities.size())
	_animals.text = str(sim.units.count - humans)
	_lag.text = "sim slowed" if game.sim_lagging else ("x%d admin" % game.admin_speed if game.admin_speed > 0 else "")
