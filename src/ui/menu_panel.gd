class_name MenuPanel
extends PanelContainer
## Save / load / new-world menu. Lists every slot with its map thumbnail and metadata.

var game: Game
var _slots := VBoxContainer.new()
var _name_edit := LineEdit.new()
var _seed_edit := LineEdit.new()
var _size := OptionButton.new()
var _shape := OptionButton.new()


func _ready() -> void:
	custom_minimum_size = Vector2(760, 620)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -380
	offset_right = 380
	offset_top = -310
	offset_bottom = 310
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var head := HBoxContainer.new()
	var title := UiTheme.label("World Ledger", "TitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var help := Button.new()
	help.text = "How to play"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(func() -> void:
		visible = false
		game.show_welcome())
	head.add_child(help)
	var close := Button.new()
	close.theme_type_variation = "ToolButton"
	close.icon = UiTheme.icon("close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)

	var save_row := HBoxContainer.new()
	save_row.add_child(UiTheme.label("Save as", "MutedLabel"))
	_name_edit.placeholder_text = "slot name (letters, digits, - _)"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text = "my_world"
	save_row.add_child(_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.icon = UiTheme.icon("save")
	save_btn.pressed.connect(func() -> void:
		if game.save_world(_name_edit.text.strip_edges()):
			refresh())
	save_row.add_child(save_btn)
	col.add_child(save_row)

	var inset := PanelContainer.new()
	inset.theme_type_variation = "Inset"
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(_slots)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(sc)
	col.add_child(inset)

	col.add_child(HSeparator.new())
	col.add_child(UiTheme.label("Shape a new world", "GoldLabel"))
	var gen := HBoxContainer.new()
	gen.add_child(UiTheme.label("Seed", "MutedLabel"))
	_seed_edit.text = str(randi() % 100000)
	_seed_edit.custom_minimum_size = Vector2(110, 0)
	gen.add_child(_seed_edit)
	for k: String in WorldGen.SIZE_PRESETS:
		var sz: Vector2i = WorldGen.SIZE_PRESETS[k]
		_size.add_item("%s %dx%d" % [k.capitalize(), sz.x, sz.y])
		_size.set_item_metadata(_size.item_count - 1, k)
	_size.select(2)
	gen.add_child(_size)
	for s: String in WorldGen.SHAPES:
		_shape.add_item(s.capitalize())
		_shape.set_item_metadata(_shape.item_count - 1, s)
	gen.add_child(_shape)
	var go := Button.new()
	go.text = "Generate"
	go.icon = UiTheme.icon("world")
	go.pressed.connect(func() -> void:
		game.new_world(int(_seed_edit.text) if _seed_edit.text.is_valid_int() else randi() % 100000, _size.get_selected_metadata(), _shape.get_selected_metadata())
		visible = false)
	gen.add_child(go)
	col.add_child(gen)
	col.add_child(HSeparator.new())
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	opts.add_child(UiTheme.label("Sound", "MutedLabel"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = game.sounds.volume if not game.sounds.muted else 0.0
	vol.custom_minimum_size = Vector2(160, 32)
	vol.focus_mode = Control.FOCUS_NONE
	vol.value_changed.connect(game.set_volume)
	opts.add_child(vol)
	opts.add_child(UiTheme.label("   Interface size", "MutedLabel"))
	for spec: Array in [["Small", 0.8], ["Normal", 1.0], ["Large", 1.25]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		var mult: float = spec[1]
		b.pressed.connect(func() -> void: game.set_ui_scale(mult))
		opts.add_child(b)
	col.add_child(opts)
	col.add_child(UiTheme.label("Autosave every %d years.  Keyboard: F5 quicksave, F9 quickload" % Game.AUTOSAVE_YEARS, "MutedLabel"))


func refresh() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var list := game.saves.list_slots()
	if list.is_empty():
		_slots.add_child(UiTheme.label("No saved worlds yet.", "MutedLabel"))
	for meta: Dictionary in list:
		_slots.add_child(_slot_row(meta))


func _slot_row(meta: Dictionary) -> Control:
	var slot: String = meta["slot"]
	var row := HBoxContainer.new()
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(96, 96)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tp := game.saves.thumbnail_path(slot)
	if FileAccess.file_exists(tp):
		var img := Image.load_from_file(tp)
		if img != null:
			thumb.texture = ImageTexture.create_from_image(img)
	row.add_child(thumb)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label(slot + ("  (autosave)" if meta.get("autosave", false) else ""), "GoldLabel"))
	info.add_child(UiTheme.label("%s   %d people, %d cities" % [meta.get("date", "?"), int(meta.get("population", 0)), int(meta.get("cities", 0))]))
	info.add_child(UiTheme.label("%s  seed %d  %dx%d  %d KB" % [str(meta.get("saved_at", "")).replace("T", " "), int(meta.get("seed", 0)), int(meta.get("width", 0)), int(meta.get("height", 0)), int(meta.get("bytes", 0)) / 1024], "MutedLabel"))
	row.add_child(info)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.icon = UiTheme.icon("load")
	load_btn.pressed.connect(func() -> void:
		if game.load_world(slot):
			visible = false)
	row.add_child(load_btn)
	var del := Button.new()
	del.text = "Delete"
	del.pressed.connect(func() -> void:
		game.saves.delete_slot(slot)
		refresh())
	row.add_child(del)
	return row
