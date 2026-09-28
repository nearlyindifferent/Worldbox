class_name PowerBar
extends PanelContainer
## Bottom god-power toolbar: category tabs, power buttons with tooltips, brush size, undo.

var game: Game
var _tabs := HBoxContainer.new()
var _powers := HBoxContainer.new()
var _tab_buttons := {}
var _power_buttons := {}
var _category: String = "inspect"
var _brush_label := Label.new()
var _current := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	top.add_child(_tabs)
	var group := ButtonGroup.new()
	for c: Dictionary in Powers.CATEGORIES:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.text = c["name"]
		b.icon = UiTheme.icon(c["icon"])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_category.bind(c["id"]))
		_tabs.add_child(b)
		_tab_buttons[c["id"]] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_current.theme_type_variation = "GoldLabel"
	top.add_child(_current)
	top.add_child(VSeparator.new())
	top.add_child(UiTheme.label("Brush", "MutedLabel"))
	top.add_child(_tool_button("minus", "Smaller brush  [ [ ]", func() -> void: game.set_brush_radius(game.brush_radius - 1)))
	_brush_label.custom_minimum_size = Vector2(36, 0)
	_brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_brush_label)
	top.add_child(_tool_button("plus", "Larger brush  [ ] ]", func() -> void: game.set_brush_radius(game.brush_radius + 1)))
	top.add_child(_tool_button("undo", "Undo last terrain stroke  [Ctrl+Z]", func() -> void: game.undo()))

	var inset := PanelContainer.new()
	inset.theme_type_variation = "Inset"
	inset.custom_minimum_size = Vector2(0, 60)
	col.add_child(inset)
	_powers.add_theme_constant_override("separation", 4)
	inset.add_child(_powers)
	game.power_changed.connect(_sync)
	_show_category("inspect")
	_sync()


func _tool_button(icon_id: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ToolButton"
	b.icon = UiTheme.icon(icon_id)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 32)
	b.pressed.connect(cb)
	return b


func _show_category(cat: String) -> void:
	_category = cat
	(_tab_buttons[cat] as Button).set_pressed_no_signal(true)
	for ch in _powers.get_children():
		ch.queue_free()
	_power_buttons.clear()
	for c: Dictionary in Powers.CATEGORIES:
		if c["id"] != cat:
			continue
		for pid: String in c["powers"]:
			var d: Dictionary = Powers.DEFS[pid]
			var b := Button.new()
			b.theme_type_variation = "ToolButton"
			b.icon = UiTheme.icon(pid)
			b.expand_icon = true
			b.custom_minimum_size = Vector2(52, 52)
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			var hk := ""
			if Powers.HOTKEYS.has(pid):
				hk = "  [%s]" % OS.get_keycode_string(Powers.HOTKEYS[pid])
			b.tooltip_text = "%s%s\n%s" % [d["name"], hk, d["desc"]]
			b.pressed.connect(game.set_power.bind(pid))
			_powers.add_child(b)
			_power_buttons[pid] = b
	_sync()


func _sync() -> void:
	var cat := Powers.category_of(game.power)
	if cat != _category and _tab_buttons.has(cat):
		_show_category(cat)
		return
	for pid: String in _power_buttons:
		(_power_buttons[pid] as Button).set_pressed_no_signal(pid == game.power)
	_brush_label.text = str(game.brush_radius)
	_current.text = Powers.DEFS[game.power]["name"]
