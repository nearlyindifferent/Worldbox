class_name GameUi
extends Control
## Root of the interface layer. Builds and lays out every panel; panels talk to
## the Game controller only through its public API and signals.

var game: Game
var top_bar: TopBar
var power_bar: PowerBar
var inspector: InspectorPanel
var history: HistoryPanel
var admin: AdminPanel
var perf: PerfOverlay
var menu: MenuPanel
var labels: CityLabels
var toasts: VBoxContainer
var hover_label: Label
var hover_panel: PanelContainer


func _ready() -> void:
	theme = UiTheme.game()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	labels = CityLabels.new()
	labels.game = game
	add_child(labels)

	top_bar = TopBar.new()
	top_bar.game = game
	add_child(top_bar)

	power_bar = PowerBar.new()
	power_bar.game = game
	add_child(power_bar)

	inspector = InspectorPanel.new()
	inspector.game = game
	add_child(inspector)

	history = HistoryPanel.new()
	history.game = game
	history.visible = false
	add_child(history)

	hover_panel = PanelContainer.new()
	hover_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("#1c1512", 0.8), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0))
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.add_child(hover_label)
	add_child(hover_panel)

	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-300, 70)
	toasts.custom_minimum_size = Vector2(600, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)

	perf = PerfOverlay.new()
	perf.game = game
	perf.visible = false
	add_child(perf)

	admin = AdminPanel.new()
	admin.game = game
	admin.visible = false
	add_child(admin)

	menu = MenuPanel.new()
	menu.game = game
	menu.visible = false
	add_child(menu)

	game.toast.connect(show_toast)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size

	hover_panel.position = Vector2(8, vp.y - power_bar.get_combined_minimum_size().y - 34)


func on_hover_tile(t: Vector2i) -> void:
	var sim := game.sim
	hover_panel.visible = sim.world.in_bounds(t.x, t.y)
	if not hover_panel.visible:
		return
	_layout()
	var i := sim.world.idx(t.x, t.y)
	var b: Defs.BiomeDef = Defs.biomes[sim.world.biome[i]]
	var owner := ""
	var c: City = sim.cities.get(sim.world.owner[i], null)
	if c != null:
		owner = "  -  %s" % c.name
	hover_label.text = "%s  (%d, %d)  fertility %d%%%s" % [b.name, t.x, t.y, int(sim.world.fertility(i) * 100), owner]


func on_key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_F1, KEY_QUOTELEFT:
			toggle_admin()
		KEY_F3:
			perf.visible = not perf.visible
		KEY_T:
			history.visible = not history.visible


func toggle_admin() -> void:
	admin.visible = not admin.visible
	if admin.visible:
		admin.refresh_all()


func toggle_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		menu.refresh()


func show_toast(msg: String, good: bool = true) -> void:
	if msg.is_empty():
		return
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color("#1c1512", 0.92), UiTheme.GOLD.darkened(0.2) if good else UiTheme.BAD, Color(0, 0, 0, 0), 8)
	p.add_theme_stylebox_override("panel", sb)
	var l := UiTheme.label(msg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toasts.add_child(p)
	if toasts.get_child_count() > 4:
		toasts.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
