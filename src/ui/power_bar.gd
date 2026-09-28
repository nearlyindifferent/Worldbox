class_name PowerBar
extends PanelContainer
## Bottom god-power toolbar. Wide screens use one row:
## [category tabs] | [powers of the browsed category] ... [current tool] [brush - n +] [undo]
## Narrow (portrait tablet) screens move the powers onto a second row. Powers are laid
## out in a grid of at most two rows so large categories never run off-screen.
## Browsing a category never changes the selected power; exactly one tab is active.

var game: Game
var _tabs := HBoxContainer.new()
var _powers := GridContainer.new()
var _stack := VBoxContainer.new()
var _row := HBoxContainer.new()
var _inset := PanelContainer.new()
var _right := VBoxContainer.new()
const NARROW := 1000.0
const POWER_BTN := 46.0
var _tab_buttons := {}
var _power_buttons := {}
var _category: String = "inspect"
var _brush_label := Label.new()
var _current := Label.new()
var _desc := Label.new()
var _brush_box := HBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := _row
	row.add_theme_constant_override("separation", 8)
	_stack.add_theme_constant_override("separation", 4)
	add_child(_stack)
	_stack.add_child(row)
	var tab_col := VBoxContainer.new()
	tab_col.add_theme_constant_override("separation", 2)
	row.add_child(tab_col)
	var tabs_a := HBoxContainer.new()
	var tabs_b := HBoxContainer.new()
	tabs_a.add_theme_constant_override("separation", 2)
	tabs_b.add_theme_constant_override("separation", 2)
	tab_col.add_child(tabs_a)
	tab_col.add_child(tabs_b)
	var k := 0
	for c: Dictionary in Powers.CATEGORIES:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.text = c["name"]
		b.icon = UiTheme.icon(c["icon"])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "Show %s powers" % str(c["name"]).to_lower()
		b.pressed.connect(_pick_category.bind(c["id"]))
		(tabs_a if k < 3 else tabs_b).add_child(b)
		_tab_buttons[c["id"]] = b
		k += 1
	row.add_child(VSeparator.new())
	var inset := _inset
	inset.theme_type_variation = "Inset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_powers.add_theme_constant_override("h_separation", 3)
	_powers.add_theme_constant_override("v_separation", 3)
	inset.add_child(_powers)
	row.add_child(inset)
	var right := _right
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	_current.theme_type_variation = "GoldLabel"
	_current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current.custom_minimum_size = Vector2(240, 0)
	right.add_child(_current)
	# The selected power's description, always visible (touch screens have no hover).
	_desc.theme_type_variation = "MutedLabel"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(240, 0)
	_desc.max_lines_visible = 2
	_desc.add_theme_font_size_override("font_size", 14)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_desc)
	_brush_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_brush_box.add_child(UiTheme.label("Brush", "MutedLabel"))
	_brush_box.add_child(_tool_button("minus", "Smaller brush  [ [ ]", func() -> void: game.set_brush_radius(game.brush_radius - 1)))
	_brush_label.custom_minimum_size = Vector2(28, 0)
	_brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brush_box.add_child(_brush_label)
	_brush_box.add_child(_tool_button("plus", "Larger brush  [ ] ]", func() -> void: game.set_brush_radius(game.brush_radius + 1)))
	_brush_box.add_child(_tool_button("undo", "Undo last terrain stroke  [Ctrl+Z]", func() -> void: game.undo()))
	right.add_child(_brush_box)
	game.power_changed.connect(_on_power_changed)
	show_category("inspect")
	get_viewport().size_changed.connect(_fit)
	_fit()


## Portrait / narrow screens: powers get their own row under the tabs.
func _fit() -> void:
	var narrow := get_viewport_rect().size.x < NARROW
	var parent := _inset.get_parent()
	if narrow and parent == _row:
		_row.remove_child(_inset)
		_stack.add_child(_inset)
	elif not narrow and parent == _stack:
		_stack.remove_child(_inset)
		_row.add_child(_inset)
		_row.move_child(_inset, _row.get_child_count() - 2)


func _tool_button(icon_id: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ToolButton"
	b.icon = UiTheme.icon(icon_id)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(32, 30)
	b.pressed.connect(cb)
	return b


## Tapping a tab also picks its first power, so the next tap on the map does something.
func _pick_category(cat: String) -> void:
	show_category(cat)
	for c: Dictionary in Powers.CATEGORIES:
		if c["id"] == cat and not (game.power in c["powers"]):
			game.set_power(c["powers"][0])


## Shows the powers of `cat` without changing the selected power.
func show_category(cat: String) -> void:
	_category = cat
	for id: String in _tab_buttons:
		(_tab_buttons[id] as Button).set_pressed_no_signal(id == cat)
	for ch in _powers.get_children():
		ch.queue_free()
	_power_buttons.clear()
	for c: Dictionary in Powers.CATEGORIES:
		if c["id"] != cat:
			continue
		var n: int = (c["powers"] as Array).size()
		_powers.columns = n if n <= 8 else ceili(n / 2.0)
		for pid: String in c["powers"]:
			var d: Dictionary = Powers.DEFS[pid]
			var b := Button.new()
			b.theme_type_variation = "ToolButton"
			b.icon = UiTheme.icon(pid)
			b.expand_icon = true
			b.custom_minimum_size = Vector2(POWER_BTN, POWER_BTN)
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			var hk := ""
			if Powers.HOTKEYS.has(pid):
				hk = "  [%s]" % OS.get_keycode_string(Powers.HOTKEYS[pid])
			b.tooltip_text = "%s%s\n%s" % [d["name"], hk, d["desc"]]
			b.pressed.connect(game.set_power.bind(pid))
			_powers.add_child(b)
			_power_buttons[pid] = b
	_sync_buttons()


func _on_power_changed() -> void:
	# A power picked by hotkey jumps the browser to its category.
	var cat := Powers.category_of(game.power)
	if cat != _category and not _power_buttons.has(game.power):
		show_category(cat)
	else:
		_sync_buttons()


func _sync_buttons() -> void:
	for pid: String in _power_buttons:
		(_power_buttons[pid] as Button).set_pressed_no_signal(pid == game.power)
	_brush_label.text = str(game.brush_radius)
	_current.text = Powers.DEFS[game.power]["name"]
	_desc.text = Powers.DEFS[game.power]["desc"]
	_brush_box.modulate.a = 1.0 if Powers.DEFS[game.power]["brush"] else 0.45
