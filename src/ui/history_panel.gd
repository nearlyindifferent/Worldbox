class_name HistoryPanel
extends PanelContainer
## Browsable chronicle of world events; click an entry to jump to where it happened.

var game: Game
var _list := ItemList.new()
var _filter := OptionButton.new()
var _timer := 0.0
var _last_total := -1
var _entries: Array[Dictionary] = []
const FILTERS := ["Notable events", "Everything", "Major only", "Settlements", "Leaders", "Hardship"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 8
	offset_right = 468
	offset_top = 60
	offset_bottom = -130
	var col := VBoxContainer.new()
	add_child(col)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.icon_rect("history", 32))
	var t := UiTheme.label("Chronicle", "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.theme_type_variation = "ToolButton"
	close.icon = UiTheme.icon("close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)
	for f in FILTERS:
		_filter.add_item(f)
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.item_selected.connect(func(_i: int) -> void: _last_total = -1)
	col.add_child(_filter)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.max_columns = 1
	_list.item_activated.connect(_jump)
	_list.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void: _jump(i))
	col.add_child(_list)
	col.add_child(UiTheme.label("Click an event to visit it.", "MutedLabel"))


func _process(delta: float) -> void:
	if not visible or game.sim == null:
		return
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	if game.sim.history.total_recorded == _last_total:
		return
	_last_total = game.sim.history.total_recorded
	_list.clear()
	_entries.clear()
	var mode := _filter.selected
	for e: Dictionary in game.sim.history.recent(400):
		var k := int(e["kind"])
		# "Notable" hides routine construction so important events stand out.
		if mode == 0 and k == HistoryLog.Kind.BUILDING and not str(e["text"]).contains("destroyed"):
			continue
		if mode == 2 and not (k in HistoryLog.MAJOR):
			continue
		if mode == 3 and not (k in [HistoryLog.Kind.CITY_FOUNDED, HistoryLog.Kind.CITY_ABANDONED, HistoryLog.Kind.BUILDING]):
			continue
		if mode == 4 and not (k in [HistoryLog.Kind.LEADER_CHANGED, HistoryLog.Kind.LEADER_DIED]):
			continue
		if mode == 5 and not (k in [HistoryLog.Kind.FAMINE, HistoryLog.Kind.DISASTER, HistoryLog.Kind.CITY_ABANDONED]):
			continue
		var idx := _list.add_item("%s  %s" % [_short_date(int(e["tick"])), e["text"]])
		if k in HistoryLog.MAJOR:
			_list.set_item_custom_fg_color(idx, UiTheme.GOLD)
		_entries.append(e)


func _short_date(tick: int) -> String:
	@warning_ignore("integer_division")
	return "Y%d M%d" % [tick / SimConst.TICKS_PER_YEAR + 1, (tick % SimConst.TICKS_PER_YEAR) / SimConst.TICKS_PER_MONTH + 1]


func _jump(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	var e := _entries[i]
	var refs: Dictionary = e["refs"]
	if refs.has("unit") and game.sim.units.is_alive_id(int(refs["unit"])):
		game.focus_unit(int(refs["unit"]))
	elif refs.has("city") and game.sim.cities.has(int(refs["city"])):
		game.focus_city(int(refs["city"]))
	elif int(e["tile"]) >= 0:
		game.focus_tile(int(e["tile"]))
