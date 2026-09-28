class_name StatsPanel
extends PanelContainer
## World statistics as line charts (monthly samples from Simulation.stats).

var game: Game
var _charts: Array[StatChart] = []
var _timer := 0.0

const CHARTS := [
	{"title": "Population", "series": [["humans", "People", "#e8c070"], ["sheep", "Woolbacks", "#e8e4d8"], ["wolves", "Wolves", "#9aa0a8"]]},
	{"title": "Realms", "series": [["cities", "Towns", "#d87a4a"], ["kingdoms", "Kingdoms", "#b08ae0"]]},
	{"title": "Food in store", "series": [["food", "Food", "#8ad04a"]]},
	{"title": "Births and deaths per month", "series": [["births", "Births", "#6ab0f0"], ["deaths", "Deaths", "#e05a4a"], ["sick", "Sick", "#9ad05a"]]},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 8
	offset_right = 468
	offset_top = 60
	offset_bottom = -130
	var col := VBoxContainer.new()
	add_child(col)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.icon_rect("perf", 32))
	var t := UiTheme.label("World Stats", "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.theme_type_variation = "ToolButton"
	close.icon = UiTheme.icon("close")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(40, 36)
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for spec: Dictionary in CHARTS:
		list.add_child(UiTheme.label(spec["title"], "MutedLabel"))
		var ch := StatChart.new()
		ch.series_spec = spec["series"]
		ch.custom_minimum_size = Vector2(420, 120)
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(ch)
		_charts.append(ch)
	col.add_child(UiTheme.label("One sample per month; older history is averaged.", "MutedLabel"))


func _process(delta: float) -> void:
	if not visible or game.sim == null:
		return
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	for ch in _charts:
		ch.sim = game.sim
		ch.queue_redraw()


class StatChart:
	extends Control
	var sim: Simulation
	var series_spec: Array = []

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#1c1512", 0.85))
		if sim == null:
			return
		var font := get_theme_default_font()
		var fsize := 14
		var hi := 1.0
		var n := 0
		for spec: Array in series_spec:
			var ss: StatSeries = sim.stats.get(spec[0], null)
			if ss == null:
				continue
			n = maxi(n, ss.values.size())
			for v in ss.values:
				hi = maxf(hi, v)
		var plot := Rect2(Vector2(4, 18), size - Vector2(8, 22))
		for g in 4:
			var y := plot.position.y + plot.size.y * g / 3.0
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.07), 1.0)
		draw_string(font, Vector2(plot.end.x - 90, 14), "max %s" % _fmt(hi), HORIZONTAL_ALIGNMENT_RIGHT, 86, fsize, Color("#a89a88"))
		var lx := 6.0
		for spec: Array in series_spec:
			var col := Color(spec[2])
			var ss: StatSeries = sim.stats.get(spec[0], null)
			var label := "%s %s" % [spec[1], _fmt(ss.last()) if ss != null else "-"]
			draw_rect(Rect2(Vector2(lx, 6), Vector2(8, 8)), col)
			draw_string(font, Vector2(lx + 11, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
			lx += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 24
			if ss == null or ss.values.size() < 2:
				continue
			var pts := PackedVector2Array()
			var m := ss.values.size()
			for k in m:
				var x := plot.position.x + plot.size.x * float(k) / float(maxi(1, n - 1))
				var y := plot.end.y - plot.size.y * ss.values[k] / hi
				pts.append(Vector2(x, y))
			draw_polyline(pts, col, 2.0)

	static func _fmt(v: float) -> String:
		if v >= 10000.0:
			return "%.1fk" % (v / 1000.0)
		return str(roundi(v))
