class_name PerfOverlay
extends PanelContainer
## Live performance readout: frame/sim timings, subsystem costs, entity counts, memory.

var game: Game
var _text := Label.new()
var _timer := 0.0


func _ready() -> void:
	theme = UiTheme.admin()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(8, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)


func _process(delta: float) -> void:
	if not visible or game.sim == null:
		return
	_timer += delta
	if _timer < 0.25:
		return
	_timer = 0.0
	_text.text = report(game)


static func report(g: Game) -> String:
	var sim := g.sim
	var lines := PackedStringArray()
	lines.append("FPS %d   frame %.1f ms   draw calls %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	lines.append("sim %.2f ms/tick   %d ticks this frame (%.1f ms)   target %d t/s%s" % [float(sim.timings.get("tick_total", 0.0)) / 1000.0, g.ticks_last_frame, g.sim_ms_last_frame, int(g.ticks_per_second()), "  LAGGING" if g.sim_lagging else ""])
	var parts := PackedStringArray()
	for k in ["spatial", "vegetation", "units", "civ", "monthly"]:
		parts.append("%s %.2f" % [k, float(sim.timings.get(k, 0.0)) / 1000.0])
	lines.append("  " + "  ".join(parts) + "  (ms)")
	lines.append("units %d (visible %d)   cities %d   buildings %d (visible %d)" % [sim.units.count, g.units_view.visible_count, sim.cities.size(), sim.buildings.size(), g.buildings_view.visible_count])
	lines.append("tiles %d (%dx%d)   chunks re-encoded %d   paths %d (refused %d)" % [sim.world.size, sim.world.width, sim.world.height, g.terrain.chunks_updated_total, sim.pathfinder.requests_total, sim.pathfinder.refused_total])
	lines.append("memory %.1f MB static   objects %d   tick %d" % [OS.get_static_memory_usage() / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT)), sim.tick])
	return "\n".join(lines)
