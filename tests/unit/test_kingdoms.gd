extends TestCase
## Kingdoms, diplomacy and war (Feature K).


## Two independent towns on a flat world, `gap` tiles apart.
func _two_realms(gap: int = 50, size: int = 128) -> Simulation:
	var sim := TestWorlds.flat(size)
	var a := TestWorlds.add_band(sim, 30.5, 60.5, 10)
	var b := TestWorlds.add_band(sim, 30.5 + gap, 60.5, 10)
	sim.civ.found_city(a[0], sim.world.idx(30, 60), [["test", 0.0]])
	sim.civ.found_city(b[0], sim.world.idx(30 + gap, 60), [["test", 0.0]])
	sim.spatial.rebuild(sim.units)
	return sim


func _kingdoms(sim: Simulation) -> Array:
	return sim.kingdoms.values()


func test_founding_creates_kingdom_and_colonies_stay_loyal() -> void:
	var sim := TestWorlds.flat(160)
	var band := TestWorlds.add_band(sim, 40.5, 40.5, 12)
	var c := sim.civ.found_city(band[0], sim.world.idx(40, 40), [])
	assert_eq(sim.kingdoms.size(), 1, "a nomad band founds a kingdom")
	var k: Kingdom = sim.kingdoms[c.kingdom]
	assert_eq(k.capital, c.id)
	# Settlers from this city found a colony that joins the same kingdom.
	var settlers := TestWorlds.add_band(sim, 100.5, 100.5, 4)
	for s in settlers:
		sim.civ.settler_origin[sim.units.id[s]] = k.id
	var colony := sim.civ.found_city(settlers[0], sim.world.idx(100, 100), [])
	assert_eq(colony.kingdom, k.id, "colony joins the mother kingdom")
	assert_eq(sim.kingdoms.size(), 1)
	assert_eq(k.cities.size(), 2)
	assert_no_violations(sim, "after colonisation")


func test_relations_have_itemised_reasons() -> void:
	var sim := _two_realms(30)
	run_ticks(sim, SimConst.TICKS_PER_MONTH + 1)
	var ks := _kingdoms(sim)
	var p := sim.realm.pair((ks[0] as Kingdom).id, (ks[1] as Kingdom).id)
	var labels := []
	for r: Array in p["reasons"]:
		labels.append(r[0])
	assert_true("border tension" in labels, "close neighbours feel border tension: %s" % str(labels))
	assert_true("rulers' temperament" in labels)
	var total := 0.0
	for r: Array in p["reasons"]:
		total += float(r[1])
	assert_between(float(p["opinion"]), total - 0.01, total + 0.01, "opinion equals the sum of its reasons")


func test_war_drafts_soldiers_and_causes_battle_deaths() -> void:
	var sim := _two_realms(26)
	var ks := _kingdoms(sim)
	var r := sim.apply_command({"op": "declare_war", "a": (ks[0] as Kingdom).id, "b": (ks[1] as Kingdom).id})
	assert_true(r["ok"], str(r["msg"]))
	run_ticks(sim, SimConst.CITY_PLAN_INTERVAL + 2)
	var soldiers := 0
	for s in sim.units.capacity:
		if sim.units.alive[s] == 1 and Defs.jobs[sim.units.job[s]].id == "soldier":
			soldiers += 1
	assert_true(soldiers >= 4, "both sides drafted soldiers (%d)" % soldiers)
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 2)
	var battle := sim.count_deaths("battle", "human")
	note("battle deaths after 2 years: %d; kingdoms left %d; history %d" % [battle, sim.kingdoms.size(), sim.history.major.size()])
	assert_true(battle > 0 or sim.kingdoms.size() < 2, "fighting happened")
	var logged := false
	for e: Dictionary in sim.decisions.entries:
		if e["category"] == "war":
			logged = true
	assert_true(logged, "war decisions are explained")
	assert_no_violations(sim, "during war")


func test_undefended_city_is_captured_by_besiegers() -> void:
	var sim := _two_realms(40)
	var ks := _kingdoms(sim)
	var ka: Kingdom = ks[0]
	var kb: Kingdom = ks[1]
	sim.realm.declare_war(ka, kb, [])
	var target: City = sim.cities[kb.capital]
	# Remove every defender, then post attacking soldiers at the hall.
	for mid in target.members.duplicate():
		sim.kill_unit(sim.units.slot_for(mid), "test")
	var w := sim.world.width
	var soldier := Defs.job_by_id("soldier").index
	var home: City = sim.cities[ka.capital]
	for k in 4:
		var s := sim.spawn_unit(sim.human_species, target.center % w + 0.5 + k * 0.3, target.center / w + 1.5, 20.0)
		sim.civ.join_city(s, home)
		sim.units.job[s] = soldier
		sim.units.set_flag(s, UnitStore.Flag.FROZEN, true)
	sim.spatial.rebuild(sim.units)
	sim.realm._sieges()
	assert_false(sim.kingdoms.has(kb.id), "the defeated kingdom fell with its last city")
	assert_eq(sim.cities[target.id].kingdom if sim.cities.has(target.id) else ka.id, ka.id)
	var conquered := false
	for e: Dictionary in sim.history.major:
		if int(e["kind"]) == HistoryLog.Kind.CITY_CONQUERED:
			conquered = true
	assert_true(conquered, "conquest recorded")
	sim.step()
	assert_no_violations(sim, "after conquest")


func test_war_weariness_leads_to_peace() -> void:
	var sim := _two_realms(80)
	var ks := _kingdoms(sim)
	var ka: Kingdom = ks[0]
	var kb: Kingdom = ks[1]
	sim.realm.declare_war(ka, kb, [])
	ka.exhaustion = 90.0
	var peace := false
	for m in 40:
		run_ticks(sim, SimConst.TICKS_PER_MONTH)
		if not sim.realm.at_war(ka.id, kb.id):
			peace = true
			break
	assert_true(peace, "exhausted kingdoms make peace")
	var p := sim.realm.pair(ka.id, kb.id)
	assert_eq(int(p["last_peace"]) > 0, true)


func test_rebellion_splits_a_kingdom_and_starts_a_war() -> void:
	var sim := TestWorlds.flat(160)
	var band := TestWorlds.add_band(sim, 30.5, 30.5, 10)
	var c := sim.civ.found_city(band[0], sim.world.idx(30, 30), [])
	var k: Kingdom = sim.kingdoms[c.kingdom]
	var far := TestWorlds.add_band(sim, 120.5, 120.5, 10)
	for s in far:
		sim.civ.settler_origin[sim.units.id[s]] = k.id
	var province := sim.civ.found_city(far[0], sim.world.idx(120, 120), [])
	var r := sim.apply_command({"op": "rebel", "city": province.id})
	assert_true(r["ok"], str(r["msg"]))
	assert_eq(sim.kingdoms.size(), 2, "a new kingdom broke away")
	assert_ne(province.kingdom, k.id)
	assert_true(sim.realm.at_war(k.id, province.kingdom), "the crown fights the rebels")
	assert_no_violations(sim, "after rebellion")


func test_war_law_prevents_declarations() -> void:
	var sim := _two_realms(24)
	sim.laws.set_law("wars", false)
	for p: Dictionary in sim.realm.pairs.values():
		p["opinion"] = -100.0
	var ks := _kingdoms(sim)
	var p2 := sim.realm.pair((ks[0] as Kingdom).id, (ks[1] as Kingdom).id)
	p2["last_peace"] = -100000
	p2["grievance"] = 80.0
	run_ticks(sim, SimConst.TICKS_PER_YEAR * 2)
	assert_false(sim.realm.at_war((ks[0] as Kingdom).id, (ks[1] as Kingdom).id), "no war while the law is off")


func test_bitter_neighbours_eventually_declare_war() -> void:
	var sim := _two_realms(24)
	var ks := _kingdoms(sim)
	var p := sim.realm.pair((ks[0] as Kingdom).id, (ks[1] as Kingdom).id)
	p["last_peace"] = -100000
	p["grievance"] = 80.0
	var war := false
	for m in 60:
		run_ticks(sim, SimConst.TICKS_PER_MONTH)
		p["grievance"] = maxf(float(p["grievance"]), 60.0)
		if sim.realm.at_war((ks[0] as Kingdom).id, (ks[1] as Kingdom).id):
			war = true
			break
	assert_true(war, "deep grievances between neighbours lead to war")


func test_mid_war_clone_evolves_identically() -> void:
	var sim := _two_realms(26)
	var ks := _kingdoms(sim)
	sim.realm.declare_war(ks[0], ks[1], [])
	run_ticks(sim, 400)
	var copy := sim.clone()
	run_ticks(sim, 500)
	run_ticks(copy, 500)
	assert_eq(copy.state_hash(), sim.state_hash(), "war state saves and reloads exactly")


func test_freshly_conquered_city_does_not_rebel_during_occupation() -> void:
	var sim := TestWorlds.flat(160)
	var band := TestWorlds.add_band(sim, 30.5, 30.5, 10)
	var c := sim.civ.found_city(band[0], sim.world.idx(30, 30), [])
	var k: Kingdom = sim.kingdoms[c.kingdom]
	var far := TestWorlds.add_band(sim, 130.5, 130.5, 12)
	for s in far:
		sim.civ.settler_origin[sim.units.id[s]] = k.id
	var province := sim.civ.found_city(far[0], sim.world.idx(130, 130), [])
	province.joined_tick = sim.tick
	province.loyalty = 0.0
	for m in 24:
		province.loyalty = 0.0
		sim.realm._rebellions()
	assert_eq(province.kingdom, k.id, "no uprising inside the occupation grace period")
	sim.tick += int(KingdomSystem.OCCUPATION_GRACE_YEARS * SimConst.TICKS_PER_YEAR) + 1
	var rebelled := false
	for m in 200:
		province.loyalty = 0.0
		sim.realm._rebellions()
		if province.kingdom != k.id:
			rebelled = true
			break
	assert_true(rebelled, "a hostile province rebels once the grace period ends")


func test_long_stalemate_ends_in_truce() -> void:
	var sim := _two_realms(90)
	var ks := _kingdoms(sim)
	sim.realm.declare_war(ks[0], ks[1], [])
	var p := sim.realm.pair((ks[0] as Kingdom).id, (ks[1] as Kingdom).id)
	p["war_start"] = sim.tick - int(KingdomSystem.STALEMATE_YEARS * SimConst.TICKS_PER_YEAR) - 1
	var peace := false
	for m in 200:
		(ks[0] as Kingdom).exhaustion = 0.0
		(ks[1] as Kingdom).exhaustion = 0.0
		sim.realm._war_month(p, ks[0], ks[1])
		if not p["war"]:
			peace = true
			break
	assert_true(peace, "a war with no gains ends in a truce even without exhaustion")
