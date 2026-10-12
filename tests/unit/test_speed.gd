extends TestCase
## Custom time speed (pure controller logic; no scene needed).


func test_custom_speed_clamps_pauses_and_resumes() -> void:
	var g := Game.new()
	g.set_custom_speed(30.0)
	assert_eq(g.requested_speed(), 30.0)
	assert_eq(g.ticks_per_second(), 30.0 * SimConst.TICKS_PER_SECOND)
	g.set_custom_speed(500.0)
	assert_eq(g.requested_speed(), 100.0, "custom speed is capped at x100")
	g.set_custom_speed(0.01)
	assert_eq(g.requested_speed(), 0.25, "and floored at x0.25 (slow motion)")
	g.set_custom_speed(50.0)
	g.toggle_pause()
	assert_true(g.is_paused())
	assert_eq(g.ticks_per_second(), 0.0)
	g.toggle_pause()
	assert_eq(g.requested_speed(), 50.0, "unpausing returns to the custom speed")
	g.set_speed(3)
	assert_false(g.using_custom)
	assert_eq(g.requested_speed(), 5.0, "preset buttons still work")
	g.free()


func test_speed_labels() -> void:
	assert_eq(SpeedPanel.label_for(30.0), "x30")
	assert_eq(SpeedPanel.label_for(0.5), "x0.5")
	assert_eq(SpeedPanel.label_for(0.25), "x0.25")
	assert_eq(SpeedPanel._stop_index(26.0), Game.CUSTOM_STOPS.find(25))
