class_name SpeedPanel
extends PanelContainer
## Custom time speed: a slider over Game.CUSTOM_STOPS (0.25x to 100x) plus quick
## picks. Opened from the top bar's custom speed button.

var game: Game
var _slider := HSlider.new()
var _value := Label.new()
var _real := Label.new()


static func label_for(mult: float) -> String:
	if mult < 1.0:
		return "x%s" % str(snappedf(mult, 0.01)).trim_suffix("0")
	return "x%d" % roundi(mult)


func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var head := HBoxContainer.new()
	var t := UiTheme.label("Custom speed", "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_value.theme_type_variation = "GoldLabel"
	_value.add_theme_font_size_override("font_size", 28)
	head.add_child(_value)
	col.add_child(head)
	_slider.min_value = 0
	_slider.max_value = Game.CUSTOM_STOPS.size() - 1
	_slider.step = 1
	_slider.custom_minimum_size = Vector2(340, 40)
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value = _stop_index(game.custom_speed)
	_slider.value_changed.connect(func(v: float) -> void:
		game.set_custom_speed(Game.CUSTOM_STOPS[int(v)])
		_refresh())
	col.add_child(_slider)
	var ends := HBoxContainer.new()
	var lo := UiTheme.label("slow motion", "MutedLabel")
	lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(lo)
	ends.add_child(UiTheme.label("very fast", "MutedLabel"))
	col.add_child(ends)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for m: float in [0.5, 20.0, 30.0, 50.0, 100.0]:
		var b := Button.new()
		b.text = label_for(m)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 40)
		b.pressed.connect(func() -> void:
			game.set_custom_speed(m)
			_slider.set_value_no_signal(_stop_index(m))
			_refresh())
		chips.add_child(b)
	col.add_child(chips)
	_real.theme_type_variation = "MutedLabel"
	_real.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_real.custom_minimum_size = Vector2(340, 0)
	col.add_child(_real)
	var done := Button.new()
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(0, 40)
	done.pressed.connect(func() -> void: visible = false)
	col.add_child(done)
	_refresh()


static func _stop_index(mult: float) -> int:
	var best := 0
	for k in Game.CUSTOM_STOPS.size():
		if absf(float(Game.CUSTOM_STOPS[k]) - mult) < absf(float(Game.CUSTOM_STOPS[best]) - mult):
			best = k
	return best


func open() -> void:
	_slider.set_value_no_signal(_stop_index(game.custom_speed))
	if not game.using_custom:
		game.set_custom_speed(game.custom_speed)
	visible = true
	_refresh()


func _refresh() -> void:
	_value.text = label_for(game.custom_speed)


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	size = get_combined_minimum_size()
	position = Vector2(clampf((vp.x - size.x) * 0.5, 8.0, vp.x - size.x - 8.0), 60.0)
	if game.using_custom and game.sim_lagging:
		_real.text = "Your device is running the world at about %s, the most it can manage. Smaller worlds run faster." % label_for(maxf(game.effective_speed, 0.25))
	else:
		_real.text = "Time runs %s times as fast as normal." % label_for(game.custom_speed).trim_prefix("x") if game.custom_speed >= 1.0 else "Slow motion: time runs at %s of normal speed." % label_for(game.custom_speed).trim_prefix("x")
