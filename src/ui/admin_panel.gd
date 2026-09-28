class_name AdminPanel
extends PanelContainer
## Developer/admin console. Deliberately technical-looking. Every action goes
## through GodCommands so it is logged and reproducible.

var game: Game
var _tabs := TabContainer.new()
# entities
var _search := LineEdit.new()
var _filter := OptionButton.new()
var _results := ItemList.new()
var _result_refs: Array = []
# selected
var _sel_box := VBoxContainer.new()
# world
var _laws_box := VBoxContainer.new()
var _world_info := Label.new()
# debug
var _overlay := OptionButton.new()
var _inv_label := Label.new()
var _decisions := RichTextLabel.new()
var _dec_filter := OptionButton.new()
var _timer := 0.0


func _ready() -> void:
	theme = UiTheme.admin()
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 8
	offset_right = 568
	offset_top = 60
	offset_bottom = -130
	var col := VBoxContainer.new()
	add_child(col)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.icon_rect("admin", 24))
	var t := UiTheme.label("ADMIN CONSOLE", "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.icon = UiTheme.icon("close")
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	col.add_child(head)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_build_entities()
	_build_selected()
	_build_world()
	_build_debug()
	game.selection_changed.connect(_rebuild_selected)
	game.world_changed.connect(refresh_all)


func refresh_all() -> void:
	_run_search()
	_rebuild_selected()
	_rebuild_laws()


func _process(delta: float) -> void:
	if not visible or game.sim == null:
		return
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	var sim := game.sim
	_world_info.text = "tick %d   %s\nunits %d   cities %d   buildings %d\ncommands logged %d   history %d major / %d minor\nbirths %d   deaths %s" % [
		sim.tick, sim.date_string(), sim.units.count, sim.cities.size(), sim.buildings.size(),
		sim.command_log.size(), sim.history.major.size(), sim.history.minor.size(), sim.total_births, str(sim.deaths_by_cause)]
	if _tabs.current_tab == 3:
		_refresh_decisions()


func _page(name_: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name_
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_tabs.add_child(sc)
	return v


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- entities

func _build_entities() -> void:
	var v := _page("Entities")
	var row := HBoxContainer.new()
	_search.placeholder_text = "search name / id / city"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _run_search())
	row.add_child(_search)
	for f in ["All", "Humans", "Animals", "Cities", "Favorites", "Leaders", "Starving"]:
		_filter.add_item(f)
	_filter.item_selected.connect(func(_i: int) -> void: _run_search())
	row.add_child(_filter)
	row.add_child(_btn("Refresh", _run_search))
	v.add_child(row)
	_results.custom_minimum_size = Vector2(0, 560)
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.item_selected.connect(_pick_result)
	v.add_child(_results)


func _run_search() -> void:
	if game.sim == null:
		return
	var sim := game.sim
	var q := _search.text.strip_edges().to_lower()
	var mode := _filter.get_item_text(_filter.selected)
	_results.clear()
	_result_refs.clear()
	var leaders := {}
	for c: City in sim.cities.values():
		leaders[c.leader_id] = true
		if mode in ["All", "Cities"] and (q == "" or c.name.to_lower().contains(q) or str(c.id) == q):
			_results.add_item("[city %d] %s  pop %d  food %d  wood %d" % [c.id, c.name, c.population(), int(c.storage["food"]), int(c.storage["wood"])])
			_result_refs.append(["city", c.id])
	if mode == "Cities":
		return
	var u := sim.units
	for s in u.capacity:
		if _results.item_count >= 300:
			_results.add_item("... refine the search to see more")
			_result_refs.append(["none", 0])
			break
		if u.alive[s] == 0:
			continue
		var human := u.species[s] == sim.human_species
		if mode == "Humans" and not human:
			continue
		if mode == "Animals" and human:
			continue
		if mode == "Favorites" and not u.has_flag(s, UnitStore.Flag.FAVORITE):
			continue
		if mode == "Leaders" and not leaders.has(u.id[s]):
			continue
		if mode == "Starving" and u.hunger[s] < SimConst.HUNGER_URGENT:
			continue
		var city_name := ""
		if sim.cities.has(u.city[s]):
			city_name = (sim.cities[u.city[s]] as City).name
		if q != "" and not (u.name[s].to_lower().contains(q) or str(u.id[s]) == q or city_name.to_lower().contains(q)):
			continue
		_results.add_item("#%d %s  %s age %d  hp %d  hunger %d  %s" % [u.id[s], u.name[s], (Defs.species[u.species[s]] as Defs.SpeciesDef).id, int(u.age_years(s, sim.tick)), int(u.health[s]), int(u.hunger[s]), city_name])
		_result_refs.append(["unit", u.id[s]])


func _pick_result(i: int) -> void:
	var r: Array = _result_refs[i]
	if r[0] == "city":
		game.focus_city(r[1])
	elif r[0] == "unit":
		game.focus_unit(r[1])


# ---------------------------------------------------------------- selected

func _build_selected() -> void:
	var v := _page("Selected")
	v.add_child(_sel_box)


func _rebuild_selected() -> void:
	for c in _sel_box.get_children():
		c.queue_free()
	if game.sim == null:
		return
	var sim := game.sim
	var s := sim.units.slot_for(game.selected_unit)
	if s >= 0:
		_unit_editor(s)
	elif sim.cities.has(game.selected_city):
		_city_editor(sim.cities[game.selected_city])
	else:
		_sel_box.add_child(UiTheme.label("Select a unit or city (Inspect tool or Entities tab).", "MutedLabel"))


func _num_row(label_text: String, value: float, lo: float, hi: float, op: String, uid: int) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(label_text, "MutedLabel")
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = 1
	sb.value = value
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sb)
	h.add_child(_btn("Set", func() -> void: game.command({"op": op, "id": uid, "value": sb.value})))
	_sel_box.add_child(h)


func _unit_editor(s: int) -> void:
	var sim := game.sim
	var u := sim.units
	var uid := u.id[s]
	_sel_box.add_child(UiTheme.label("#%d %s" % [uid, u.name[s]], "GoldLabel"))
	_num_row("Health", u.health[s], 1, u.max_health[s], "set_health", uid)
	_num_row("Hunger", u.hunger[s], 0, 100, "set_hunger", uid)
	_num_row("Age (years)", u.age_years(s, sim.tick), 0, 200, "set_age", uid)
	for spec: Array in [["Freeze AI", UnitStore.Flag.FROZEN], ["Invulnerable", UnitStore.Flag.INVULNERABLE], ["Favorite", UnitStore.Flag.FAVORITE]]:
		var cb := CheckBox.new()
		cb.text = spec[0]
		cb.button_pressed = u.has_flag(s, spec[1])
		var flag: int = spec[1]
		cb.toggled.connect(func(on: bool) -> void: game.command({"op": "set_flag", "id": uid, "flag": flag, "on": on}))
		_sel_box.add_child(cb)
	if u.species[s] == sim.human_species:
		var jr := HBoxContainer.new()
		jr.add_child(UiTheme.label("Job", "MutedLabel"))
		var jo := OptionButton.new()
		for j: Defs.JobDef in Defs.jobs:
			jo.add_item(j.name)
		jo.select(u.job[s])
		jo.item_selected.connect(func(i: int) -> void: game.command({"op": "set_job", "id": uid, "job": Defs.jobs[i].id}))
		jr.add_child(jo)
		_sel_box.add_child(jr)
		_sel_box.add_child(UiTheme.label("Note: the city planner may reassign jobs on its next plan.", "MutedLabel"))
	var row := HBoxContainer.new()
	row.add_child(_btn("Kill", func() -> void: game.command({"op": "kill_unit", "id": uid})))
	row.add_child(_btn("Delete", func() -> void:
		game.command({"op": "delete_unit", "id": uid})
		game.select_unit(-1)))
	row.add_child(_btn("Duplicate", func() -> void:
		var r := game.command({"op": "duplicate_unit", "id": uid})
		if r["ok"]:
			game.select_unit(int(r["id"]))))
	row.add_child(_btn("Teleport...", func() -> void:
		game.pending_teleport_id = uid
		game.toast.emit("Click a destination tile", true)))
	_sel_box.add_child(row)
	if u.species[s] == sim.human_species and u.city[s] == SimConst.CITY_NONE:
		_sel_box.add_child(_btn("Force-found a city here", func() -> void:
			var r := game.command({"op": "found_city", "id": uid})
			if r["ok"]:
				game.toast.emit(str(r["msg"]), true)))
	var s2 := sim.units.slot_for(uid)
	var p: PackedInt32Array = u.path.get(s2, PackedInt32Array())
	_sel_box.add_child(UiTheme.label("state %d task %s target %d timer %d path %d/%d next_think %d look %x" % [u.state[s], UnitStore.TASK_NAMES[u.task[s]], u.task_target[s], u.task_timer[s], u.path_pos[s], p.size(), u.next_think[s], u.look[s]], "MutedLabel"))


func _city_editor(c: City) -> void:
	var cid := c.id
	_sel_box.add_child(UiTheme.label("[city %d] %s" % [cid, c.name], "GoldLabel"))
	var ar := HBoxContainer.new()
	ar.add_child(UiTheme.label("Amount", "MutedLabel"))
	var amt := SpinBox.new()
	amt.min_value = -1000
	amt.max_value = 1000
	amt.value = 50
	ar.add_child(amt)
	_sel_box.add_child(ar)
	for res in City.RESOURCES:
		var h := HBoxContainer.new()
		h.add_child(UiTheme.icon_rect(res, 24))
		var l := UiTheme.label("%s: %d" % [res, int(c.storage[res])])
		l.custom_minimum_size = Vector2(140, 0)
		h.add_child(l)
		var r_id: String = res
		h.add_child(_btn("Add / remove", func() -> void:
			game.command({"op": "add_resource", "city": cid, "res": r_id, "amount": amt.value})
			_rebuild_selected()))
		_sel_box.add_child(h)
	_sel_box.add_child(_btn("Abandon city", func() -> void:
		game.command({"op": "abandon_city", "city": cid})
		game.select_city(-1)))
	_sel_box.add_child(UiTheme.label("To change leader: select a member, then World tab > 'Make selected unit leader'.", "MutedLabel"))


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var v := _page("World")
	v.add_child(_world_info)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.label("Simulation speed (admin override, ticks = 10 x value per second)", "MutedLabel"))
	var sp := HBoxContainer.new()
	for m in [20, 50, 100]:
		sp.add_child(_btn("x%d" % m, func() -> void:
			game.admin_speed = m
			game.speed_changed.emit()))
	sp.add_child(_btn("Normal", func() -> void: game.set_speed(1)))
	sp.add_child(_btn("Step 1 tick", func() -> void:
		game.set_speed(0)
		game.sim.step()))
	sp.add_child(_btn("+1 year", func() -> void:
		for k in SimConst.TICKS_PER_YEAR:
			game.sim.step()))
	v.add_child(sp)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.label("World laws (take effect immediately)", "GoldLabel"))
	v.add_child(_laws_box)
	v.add_child(HSeparator.new())
	v.add_child(_btn("Make selected unit leader of its city", func() -> void:
		var s := game.sim.units.slot_for(game.selected_unit)
		if s >= 0:
			var r := game.command({"op": "set_leader", "id": game.selected_unit, "city": game.sim.units.city[s]})
			if r["ok"]:
				game.toast.emit("Leader changed", true)))
	_rebuild_laws()


func _rebuild_laws() -> void:
	for c in _laws_box.get_children():
		c.queue_free()
	if game.sim == null:
		return
	for law: String in WorldLaws.DEFAULTS:
		var cb := CheckBox.new()
		cb.text = "%s - %s" % [law.replace("_", " "), WorldLaws.DESCRIPTIONS[law]]
		cb.button_pressed = game.sim.laws.is_on(law)
		var l := law
		cb.toggled.connect(func(on: bool) -> void: game.command({"op": "set_law", "law": l, "on": on}))
		_laws_box.add_child(cb)


# ---------------------------------------------------------------- debug

func _build_debug() -> void:
	var v := _page("Debug")
	var orow := HBoxContainer.new()
	orow.add_child(UiTheme.label("Map overlay", "MutedLabel"))
	for n in TerrainView.OVERLAY_NAMES:
		_overlay.add_item(n)
	_overlay.item_selected.connect(func(i: int) -> void: game.terrain.set_overlay(i))
	orow.add_child(_overlay)
	v.add_child(orow)
	for spec: Array in [["Chunk boundaries", func(on: bool) -> void: game.terrain.set_chunks_visible(on), false],
			["Territory colors", func(on: bool) -> void: game.terrain.set_territory_visible(on), true],
			["All unit paths (visible area)", func(on: bool) -> void: game.fx.show_paths = on, false],
			["AI navigation targets", func(on: bool) -> void: game.fx.show_targets = on, false],
			["Performance overlay", func(on: bool) -> void: game.ui.perf.visible = on, false],
			["Record AI decisions", func(on: bool) -> void: game.sim.decisions.enabled = on, true]]:
		var cb := CheckBox.new()
		cb.text = spec[0]
		cb.button_pressed = spec[2]
		cb.toggled.connect(spec[1])
		v.add_child(cb)
	v.add_child(HSeparator.new())
	var ir := HBoxContainer.new()
	ir.add_child(_btn("Check invariants", func() -> void:
		var t0 := Time.get_ticks_msec()
		var errs := SimInvariants.check(game.sim)
		_inv_label.text = ("OK - no violations (%d ms)" % (Time.get_ticks_msec() - t0)) if errs.is_empty() else "%d violations:\n%s" % [errs.size(), "\n".join(errs.slice(0, 10))]))
	ir.add_child(_btn("State hash", func() -> void: _inv_label.text = "state hash " + game.sim.state_hash().substr(0, 24)))
	v.add_child(ir)
	_inv_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_inv_label)
	v.add_child(HSeparator.new())
	var dr := HBoxContainer.new()
	dr.add_child(UiTheme.label("AI decisions", "GoldLabel"))
	for f in ["all", "settlement", "construction", "succession", "shortage"]:
		_dec_filter.add_item(f)
	dr.add_child(_dec_filter)
	v.add_child(dr)
	_decisions.custom_minimum_size = Vector2(0, 360)
	_decisions.fit_content = false
	_decisions.scroll_following = false
	v.add_child(_decisions)


func _refresh_decisions() -> void:
	var f := _dec_filter.get_item_text(_dec_filter.selected)
	var lines := PackedStringArray()
	var entries := game.sim.decisions.entries
	for k in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[k]
		if f != "all" and e["category"] != f:
			continue
		lines.append("%s  %s" % [game.sim.date_string(int(e["tick"])), DecisionLog.format(e)])
		if lines.size() >= 40:
			break
	_decisions.text = "\n".join(lines)
