class_name WelcomePanel
extends PanelContainer
## First-run welcome card: what the game is and how to control it on touch and
## mouse. Shown once (remembered in user://settings.cfg) and from the menu.

const SETTINGS := "user://settings.cfg"

var game: Game


static func seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return false
	return bool(cfg.get_value("ui", "welcome_seen", false))


static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("ui", "welcome_seen", true)
	cfg.save(SETTINGS)


func _ready() -> void:
	custom_minimum_size = Vector2(640, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.icon_rect("world", 40))
	var titles := VBoxContainer.new()
	titles.add_child(UiTheme.label("Hearthmere", "TitleLabel"))
	titles.add_child(UiTheme.label("A small world in your hands. Shape it, people it, and watch what they make of it.", "MutedLabel"))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(titles.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(titles.get_child(1) as Label).custom_minimum_size = Vector2(560, 0)
	head.add_child(titles)
	col.add_child(head)
	col.add_child(HSeparator.new())
	for line: Array in [
			["inspect", "Inspect: tap a person, town or crown to learn who they are and why things happen."],
			["raise", "Pick a power from the tabs at the bottom, then tap or drag on the land to use it."],
			["follow", "Move the map: drag with one finger in Inspect, or with two fingers anywhere. Pinch to zoom."],
			["fast", "Speed up time with the arrows at the top. Kingdoms, wars and famines take years to unfold."],
			["history", "The chronicle (book icon) records every founding, war, disaster and act of the gods."],
			["perf", "World stats (bar chart icon) graph people, animals, realms and food over time."]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiTheme.icon_rect(line[0], 32))
		var l := UiTheme.label(line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	col.add_child(HSeparator.new())
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 8)
	var new_w := Button.new()
	new_w.text = "New world..."
	new_w.focus_mode = Control.FOCUS_NONE
	new_w.custom_minimum_size = Vector2(150, 44)
	new_w.pressed.connect(func() -> void:
		_close()
		game.ui.toggle_menu())
	btns.add_child(new_w)
	var start := Button.new()
	start.text = "Start playing"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(180, 44)
	start.pressed.connect(_close)
	btns.add_child(start)
	col.add_child(btns)
	resized.connect(_center)
	get_viewport().size_changed.connect(_center)
	_center()


func _center() -> void:
	var vp := get_viewport_rect().size
	size = get_combined_minimum_size()
	position = ((vp - size) * 0.5).max(Vector2.ZERO)


func _close() -> void:
	mark_seen()
	queue_free()
