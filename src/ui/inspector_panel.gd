class_name InspectorPanel
extends PanelContainer
## Rich inspection of the selected creature or city. Rebuilt on selection change
## and refreshed a few times per second. Names of related entities are clickable.

const WIDTH := 380
const REFRESH := 0.25

var game: Game
var _body := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _timer := 0.0
var _live: Dictionary = {}  ## key -> Control refreshed in place
var _show_all_children := false
var _last_selected := -2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 8
	offset_right = -8
	offset_top = 60
	offset_bottom = -130
	custom_minimum_size = Vector2(WIDTH, 0)
	var outer := VBoxContainer.new()
	add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.theme_type_variation = "ToolButton"
	close.icon = UiTheme.icon("close")
	close.tooltip_text = "Close  [Esc]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: game.select_unit(-1))
	head.add_child(close)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	game.selection_changed.connect(_rebuild)
	game.world_changed.connect(_rebuild)
	_rebuild()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= REFRESH:
		_timer = 0.0
		_refresh()


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_live.clear()


func _rebuild() -> void:
	if game.selected_unit != _last_selected:
		_show_all_children = false
		_last_selected = game.selected_unit
	_clear()
	if game.sim == null:
		visible = false
		return
	if game.selected_unit >= 0 and game.sim.units.is_alive_id(game.selected_unit):
		visible = true
		_build_unit()
	elif game.selected_unit >= 0 and game.sim.deceased.has(game.selected_unit):
		visible = true
		_show_deceased(game.selected_unit)
	elif game.selected_city >= 0 and game.sim.cities.has(game.selected_city):
		visible = true
		_build_city()
	elif game.selected_kingdom >= 0 and game.sim.kingdoms.has(game.selected_kingdom):
		visible = true
		_build_kingdom()
	else:
		visible = false


func _refresh() -> void:
	if game.selected_unit >= 0:
		if not game.sim.units.is_alive_id(game.selected_unit):
			_show_deceased(game.selected_unit)
			return
		_refresh_unit()
	elif game.selected_city >= 0:
		if not game.sim.cities.has(game.selected_city):
			game.select_city(-1)
			return
		_refresh_city()
	elif game.selected_kingdom >= 0:
		if not game.sim.kingdoms.has(game.selected_kingdom):
			game.select_kingdom(-1)
			return
		_refresh_kingdom()


# ---------------------------------------------------------------- helpers

func _row(label_text: String, key: String, value: String = "") -> Label:
	var h := HBoxContainer.new()
	var l := UiTheme.label(label_text, "MutedLabel")
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var v := UiTheme.label(value)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(v)
	_body.add_child(h)
	if key != "":
		_live[key] = v
	return v


func _link_row(label_text: String, text: String, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(label_text, "MutedLabel")
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	h.add_child(_link(text, cb))
	_body.add_child(h)


func _link(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", UiTheme.GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b


func _bar(label_text: String, key: String, color: Color) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(label_text, "MutedLabel")
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(200, 20)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.show_percentage = false
	var fill := UiTheme.box(color, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	pb.add_theme_stylebox_override("fill", fill)
	var val := Label.new()
	val.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_constant_override("outline_size", 4)
	val.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	pb.add_child(val)
	h.add_child(pb)
	_body.add_child(h)
	_live[key] = pb
	_live[key + "_val"] = val


func _section(title: String) -> void:
	_body.add_child(HSeparator.new())
	_body.add_child(UiTheme.label(title, "GoldLabel"))


func _set_text(key: String, text: String) -> void:
	if _live.has(key):
		(_live[key] as Label).text = text


# ---------------------------------------------------------------- unit

func _unit_name(uid: int) -> String:
	var u := game.sim.units
	var s := u.slot_for(uid)
	if s >= 0:
		return u.name[s]
	var d: Dictionary = game.sim.deceased.get(uid, {})
	return ("%s (deceased)" % d["name"]) if not d.is_empty() else "unknown"


func _build_unit() -> void:
	var sim := game.sim
	var u := sim.units
	var s := u.slot_for(game.selected_unit)
	var def: Defs.SpeciesDef = Defs.species[u.species[s]]
	var head := HBoxContainer.new()
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint := Color(AssetForge.NOMAD_CLOTHES)
	if u.city[s] != SimConst.CITY_NONE and sim.cities.has(u.city[s]):
		tint = Color(AssetForge.CITY_COLORS[(sim.cities[u.city[s]] as City).color_index])
	var frame := AssetForge.UF.SHEEP_A if not def.sapient else (AssetForge.UF.WOMAN_IDLE if u.sex[s] == 1 else AssetForge.UF.MAN_IDLE)
	var look := u.look[s]
	portrait.texture = ImageTexture.create_from_image(AssetForge.unit_portrait(frame, tint, Color(AssetForge.SKINS[look & 3]), Color(AssetForge.HAIRS[(look >> 4) % 5]), Color(AssetForge.WOOLS[(look >> 8) % 3])))
	var frame_bg := PanelContainer.new()
	frame_bg.theme_type_variation = "Inset"
	frame_bg.add_child(portrait)
	head.add_child(frame_bg)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiTheme.label(u.name[s], "TitleLabel"))
	names.add_child(UiTheme.label("%s, %s" % [def.name.trim_suffix("s"), "female" if u.sex[s] == 1 else "male"], "MutedLabel"))
	var age_l := UiTheme.label("")
	names.add_child(age_l)
	_live["age"] = age_l
	head.add_child(names)
	_body.add_child(head)

	var btns := HBoxContainer.new()
	var follow := Button.new()
	follow.text = "Follow"
	follow.icon = UiTheme.icon("follow")
	follow.focus_mode = Control.FOCUS_NONE
	follow.toggle_mode = true
	follow.tooltip_text = "Keep the camera on this creature  [Shift+F]"
	follow.toggled.connect(func(on: bool) -> void:
		if on:
			game.follow_selected()
		else:
			game.camera.follow(Callable()))
	btns.add_child(follow)
	_live["follow"] = follow
	var fav := Button.new()
	fav.text = "Favorite"
	fav.icon = UiTheme.icon("star")
	fav.toggle_mode = true
	fav.focus_mode = Control.FOCUS_NONE
	fav.button_pressed = u.has_flag(s, UnitStore.Flag.FAVORITE)
	var uid := game.selected_unit
	fav.toggled.connect(func(on: bool) -> void: game.command({"op": "set_flag", "id": uid, "flag": UnitStore.Flag.FAVORITE, "on": on}))
	btns.add_child(fav)
	_body.add_child(btns)

	_section("Condition")
	_bar("Health", "health", Color("#6ac86a"))
	_bar("Hunger", "hunger", Color("#e0a040"))
	_row("Doing", "task")
	_row("Carrying", "carry")
	if def.sapient:
		_section("Society")
		_row("Job", "job")
		var c: City = sim.cities.get(u.city[s], null)
		if c != null:
			var cid := c.id
			_link_row("Home", c.name, func() -> void: game.focus_city(cid))
			if c.leader_id == u.id[s]:
				_row("Title", "", "Leader of %s" % c.name)
		else:
			_row("Home", "", "Wandering, no settlement")
		_row("Kills", "kills")
	_section("Family")
	_parent_row("Mother", u.mother[s])
	_parent_row("Father", u.father[s])
	var kids: PackedInt64Array = u.children.get(u.id[s], PackedInt64Array())
	if kids.is_empty():
		_row("Children", "", "none")
	else:
		_row("Children", "", "%d" % kids.size())
		var shown := 0
		for kid in kids:
			if shown >= 8 and not _show_all_children:
				_link_row("", "... show all %d" % kids.size(), func() -> void:
					_show_all_children = true
					_rebuild())
				break
			var kid_id := kid
			_link_row("", _unit_name(kid), func() -> void: _select_any(kid_id))
			shown += 1
	_refresh_unit()


func _parent_row(label_text: String, pid: int) -> void:
	if pid == SimConst.UNIT_NONE:
		_row(label_text, "", "unknown (first generation)")
		return
	_link_row(label_text, _unit_name(pid), func() -> void: _select_any(pid))


func _select_any(uid: int) -> void:
	if game.sim.units.is_alive_id(uid):
		game.focus_unit(uid)
	else:
		game.select_unit(uid)


func _refresh_unit() -> void:
	var sim := game.sim
	var u := sim.units
	var s := u.slot_for(game.selected_unit)
	if s < 0 or not _live.has("health"):
		return
	var def: Defs.SpeciesDef = Defs.species[u.species[s]]
	var age := u.age_years(s, sim.tick)
	_set_text("age", "Age %d%s" % [int(age), "" if age >= def.adult_age else " (young)"])
	if _live.has("follow"):
		(_live["follow"] as Button).set_pressed_no_signal(game.is_following())
	var hp := _live["health"] as ProgressBar
	hp.max_value = u.max_health[s]
	hp.value = u.health[s]
	hp.tooltip_text = "%d / %d" % [roundi(u.health[s]), roundi(u.max_health[s])]
	_set_text("health_val", hp.tooltip_text)
	var hu := _live["hunger"] as ProgressBar
	hu.max_value = SimConst.HUNGER_MAX
	hu.value = u.hunger[s]
	hu.tooltip_text = "Hunger %d / 100. Eats at %d, starves at 100." % [roundi(u.hunger[s]), int(SimConst.HUNGER_EAT_THRESHOLD)]
	var mood := "fed" if u.hunger[s] < SimConst.HUNGER_EAT_THRESHOLD else ("STARVING" if u.hunger[s] >= SimConst.HUNGER_MAX else "hungry")
	_set_text("hunger_val", "%d  %s" % [roundi(u.hunger[s]), mood])
	var st := "moving" if u.state[s] == UnitStore.State.MOVING else ("working" if u.state[s] == UnitStore.State.WORKING else "idle")
	_set_text("task", "%s (%s)" % [UnitStore.TASK_NAMES[u.task[s]], st])
	_set_text("carry", "nothing" if u.carry_amount[s] <= 0.0 else "%.1f %s" % [u.carry_amount[s], UnitStore.RESOURCE_NAMES[u.carry_type[s]]])
	_set_text("job", Defs.jobs[u.job[s]].name if age >= def.adult_age else "child")
	_set_text("kills", str(u.kills[s]))


func _show_deceased(uid: int) -> void:
	if _live.has("dead"):
		return
	_clear()
	var d: Dictionary = game.sim.deceased.get(uid, {})
	_body.add_child(UiTheme.label(str(d.get("name", "Lost to time")), "TitleLabel"))
	var l := UiTheme.label("", "MutedLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if d.is_empty():
		l.text = "This creature has died and left no record."
	else:
		l.text = "Born %s\nDied %s (%s)" % [game.sim.date_string(int(d["born"])), game.sim.date_string(int(d["died"])), d["cause"]]
	_body.add_child(l)
	_live["dead"] = l
	if not d.is_empty():
		_section("Family")
		_parent_row("Mother", int(d["mother"]))
		_parent_row("Father", int(d["father"]))
		var kids: PackedInt64Array = game.sim.units.children.get(uid, PackedInt64Array())
		for kid in kids.slice(0, 8):
			var kid_id := kid
			_link_row("Child", _unit_name(kid), func() -> void: _select_any(kid_id))


# ---------------------------------------------------------------- city

func _build_city() -> void:
	var sim := game.sim
	var c: City = sim.cities[game.selected_city]
	var head := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = Color(AssetForge.CITY_COLORS[c.color_index])
	swatch.custom_minimum_size = Vector2(12, 40)
	head.add_child(swatch)
	var names := VBoxContainer.new()
	names.add_child(UiTheme.label(c.name, "TitleLabel"))
	var sub := UiTheme.label("%s settlement\nfounded %s" % [(Defs.species[c.species] as Defs.SpeciesDef).name.trim_suffix("s"), sim.date_string(c.founded_tick)], "MutedLabel")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(sub)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_body.add_child(head)
	var leader_id := c.leader_id
	if sim.units.is_alive_id(leader_id):
		_link_row("Leader", _unit_name(leader_id), func() -> void: game.focus_unit(leader_id))
	else:
		_row("Leader", "", "none")
	var kg: Kingdom = sim.kingdoms.get(c.kingdom, null)
	if kg != null:
		var kid := kg.id
		_link_row("Kingdom", kg.name + ("  (capital)" if kg.capital == c.id else ""), func() -> void: game.select_kingdom(kid))
		_row("Loyalty", "loyalty")
	_row("Population", "pop")
	_row("Territory", "terr")
	_section("Stores  (hover for last month)")
	for res in City.RESOURCES:
		var h := HBoxContainer.new()
		h.add_child(UiTheme.icon_rect(res, 24))
		var name_l := UiTheme.label(res.capitalize(), "MutedLabel")
		name_l.custom_minimum_size = Vector2(92, 0)
		h.add_child(name_l)
		var v := UiTheme.label("")
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_live["res_" + res] = v
		_body.add_child(h)
	_section("Buildings")
	_row("Built", "bld")
	_row("Under way", "site")
	_row("Fields", "fields")
	_section("Workers (have / want)")
	_row("", "jobs")
	_section("Why here?")
	var why := PackedStringArray()
	for r: Array in c.founding_reasons:
		var v: Variant = r[1]
		why.append("%s: %s" % [r[0], ("%+.1f" % v) if typeof(v) == TYPE_FLOAT else str(v)])
	var wl := UiTheme.label("\n".join(why), "MutedLabel")
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(wl)
	_section("Recent events")
	var ev := UiTheme.label("", "MutedLabel")
	ev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(ev)
	_live["events"] = ev
	_refresh_city()


func _refresh_city() -> void:
	var sim := game.sim
	var c: City = sim.cities.get(game.selected_city, null)
	if c == null or not _live.has("pop"):
		return
	_set_text("pop", "%d people, housing for %d\n%d born, %d died" % [c.population(), c.housing, c.births, c.deaths])
	_set_text("terr", "%d tiles" % c.territory.size())
	var mood := "devoted" if c.loyalty >= 75 else ("content" if c.loyalty >= 45 else ("restless" if c.loyalty >= 25 else "rebellious"))
	_set_text("loyalty", "%d  %s" % [roundi(c.loyalty), mood])
	for res in City.RESOURCES:
		var cap := c.food_capacity if res == "food" else float(Defs.building_globals.get("base_%s_capacity" % res, 200))
		var made := roundi(float(c.last_produced[res]))
		var used := roundi(float(c.last_consumed[res]))
		var net := made - used
		var trend := "steady" if net == 0 else ("%+d/mo" % net)
		_set_text("res_" + res, "%d / %d   %s" % [roundi(float(c.storage[res])), int(cap), trend])
		(_live["res_" + res] as Label).tooltip_text = "Last month: +%d made, -%d used" % [made, used]
		(_live["res_" + res] as Label).mouse_filter = Control.MOUSE_FILTER_PASS
	var counts := {}
	var sites := PackedStringArray()
	for bid in c.buildings:
		var b: Building = sim.buildings[bid]
		if b.complete:
			counts[b.def().name] = int(counts.get(b.def().name, 0)) + 1
		else:
			var need := PackedStringArray()
			if not b.paid:
				for r: String in b.def().cost:
					need.append("%d %s" % [int(b.def().cost[r]), r])
			sites.append("%s %d%%%s" % [b.def().name, int(100.0 * b.progress / maxf(1.0, b.def().work)), (" (needs " + ", ".join(need) + ")") if need.size() > 0 else ""])
	var parts := PackedStringArray()
	for k: String in counts:
		parts.append("%d %s" % [counts[k], k.to_lower() + ("s" if int(counts[k]) > 1 else "")])
	_set_text("bld", ", ".join(parts))
	_set_text("site", "none" if sites.is_empty() else "\n".join(sites))
	_set_text("fields", "%d farmland tiles" % c.fields.size())
	var jobs := PackedStringArray()
	for k in range(1, Defs.jobs.size()):
		if k < c.job_counts.size() and (c.job_counts[k] > 0 or c.job_targets[k] > 0):
			jobs.append("%s %d/%d" % [Defs.jobs[k].name, c.job_counts[k], c.job_targets[k]])
	_set_text("jobs", ", ".join(jobs))
	var evs := PackedStringArray()
	for e: Dictionary in sim.history.recent(300):
		if int((e["refs"] as Dictionary).get("city", -1)) == c.id:
			evs.append("%s: %s" % [sim.date_string(int(e["tick"])), e["text"]])
			if evs.size() >= 6:
				break
	_set_text("events", "\n".join(evs))


# ---------------------------------------------------------------- kingdom

func _build_kingdom() -> void:
	var sim := game.sim
	var k: Kingdom = sim.kingdoms[game.selected_kingdom]
	var head := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = Color(AssetForge.CITY_COLORS[k.color_index])
	swatch.custom_minimum_size = Vector2(12, 40)
	head.add_child(swatch)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiTheme.label(k.name, "TitleLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	var origin := "founded %s" % sim.date_string(k.founded_tick)
	if sim.kingdoms.has(k.parent):
		origin += ", broke from the %s" % (sim.kingdoms[k.parent] as Kingdom).name
	var sub := UiTheme.label(origin, "MutedLabel")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(sub)
	head.add_child(names)
	_body.add_child(head)
	var ruler := k.ruler_id
	if sim.units.is_alive_id(ruler):
		_link_row("Ruler", _unit_name(ruler), func() -> void: game.focus_unit(ruler))
	var cap: City = sim.cities.get(k.capital, null)
	if cap != null:
		var cid := cap.id
		_link_row("Capital", cap.name, func() -> void: game.focus_city(cid))
	_row("People", "kpop")
	_row("War weariness", "kexh")
	_section("Cities")
	for cid2 in k.cities:
		var c: City = sim.cities[cid2]
		var id2 := c.id
		_link_row("", "%s  (%d)" % [c.name, c.population()], func() -> void: game.focus_city(id2))
	_section("Relations")
	var rel := UiTheme.label("", "MutedLabel")
	rel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(rel)
	_live["krel"] = rel
	_section("Recent events")
	var ev := UiTheme.label("", "MutedLabel")
	ev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(ev)
	_live["kevents"] = ev
	_refresh_kingdom()


func _refresh_kingdom() -> void:
	var sim := game.sim
	var k: Kingdom = sim.kingdoms.get(game.selected_kingdom, null)
	if k == null or not _live.has("kpop"):
		return
	_set_text("kpop", "%d in %d cities, %d can fight" % [sim.realm.population(k), k.cities.size(), sim.realm.strength(k)])
	_set_text("kexh", "%d / 100" % roundi(k.exhaustion))
	var lines := PackedStringArray()
	for p: Dictionary in sim.realm.pairs.values():
		var other := -1
		if int(p["a"]) == k.id:
			other = int(p["b"])
		elif int(p["b"]) == k.id:
			other = int(p["a"])
		if other < 0 or not sim.kingdoms.has(other):
			continue
		var ok: Kingdom = sim.kingdoms[other]
		var stance := "AT WAR" if p["war"] else ("hostile" if float(p["opinion"]) < -20 else ("friendly" if float(p["opinion"]) > 10 else "wary"))
		lines.append("%s: %s (%+d)" % [ok.name, stance, roundi(float(p["opinion"]))])
		var why := PackedStringArray()
		for r: Array in p["reasons"]:
			if absf(float(r[1])) >= 1.0:
				why.append("%s %+d" % [r[0], roundi(float(r[1]))])
		if why.size() > 0:
			lines.append("   " + ", ".join(why))
		if p["war"]:
			var side := 0 if int(p["a"]) == k.id else 1
			lines.append("   dead: %d ours / %d theirs" % [int((p["casualties"] as Array)[side]), int((p["casualties"] as Array)[1 - side])])
	_set_text("krel", "\n".join(lines) if lines.size() > 0 else "No other kingdoms known.")
	var evs := PackedStringArray()
	for e: Dictionary in sim.history.recent(400):
		var refs: Dictionary = e["refs"]
		if int(refs.get("kingdom", -1)) == k.id or int(refs.get("enemy", -1)) == k.id or int(refs.get("from", -1)) == k.id:
			evs.append("%s: %s" % [sim.date_string(int(e["tick"])), e["text"]])
			if evs.size() >= 8:
				break
	_set_text("kevents", "\n".join(evs))
