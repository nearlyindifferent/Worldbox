class_name KingdomSystem
extends RefCounted
## Kingdoms, diplomacy and war.
##
## Every city belongs to a kingdom. Colonies founded by settlers stay in their
## mother kingdom; bands of nomads found new kingdoms. Once a month the system:
##   1. refreshes rulers, capitals and city loyalty,
##   2. recomputes each pair's opinion from itemised factors (kept for the UI),
##   3. declares wars / makes peace from opinion, strength and war weariness,
##   4. resolves sieges (a city with enemy soldiers and no defenders falls),
##   5. lets disloyal provinces rebel into new kingdoms.
## Every decision is written to the DecisionLog with its numeric reasons.

const WAR_THRESHOLD := -28.0
const PEACE_EXHAUSTION := 45.0
const MAX_WAR_YEARS := 12.0
const MIN_YEARS_BETWEEN_WARS := 5.0
const BORDER_RANGE := 45.0
const SIEGE_RADIUS := 7.0
const SIEGE_MIN_ATTACKERS := 3
const REBEL_LOYALTY := 22.0
const REBEL_MIN_POP := 10
const REBEL_CHANCE := 0.05          ## monthly, scaled by how far loyalty is below REBEL_LOYALTY
const OCCUPATION_GRACE_YEARS := 4.0 ## no rebellion this soon after a city changes hands
const REBEL_JOIN_LOYALTY := 30.0
const REBEL_JOIN_RANGE := 20.0
const REBEL_MAX_JOINERS := 2
const STALEMATE_YEARS := 3.0        ## wars this old with no city taken lately may end in a truce
const STALEMATE_PEACE_CHANCE := 0.06
const INDEPENDENCE_YEARS := 5.0     ## a rebel realm that survives this long is recognised
const DECLARE_CHANCE := 0.25
const PEACE_CHANCE := 0.35
const GRIEVANCE_PER_DEATH := 2.0
const GRIEVANCE_DECAY := 0.97
const NEIGHBOUR_RANGE := 90.0
const PEACE_BONUS_CAP := 8.0
const COVET_RATIO := 1.4
const COVET_OPINION := -12.0

var sim: Simulation
## "min:max" -> diplomatic record between two kingdoms (see _new_pair).
var pairs: Dictionary = {}
## Derived: kingdom id -> ids it is at war with (rebuilt whenever a war starts/ends).
var _enemies: Dictionary = {}
## Derived: kingdom id -> fighting strength, cached for the current tick.
var _strength: Dictionary = {}
var _strength_tick: int = -1


func _init(p_sim: Simulation) -> void:
	sim = p_sim


# ------------------------------------------------------------------ queries

static func pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


func pair(a: int, b: int) -> Dictionary:
	var k := pair_key(a, b)
	if not pairs.has(k):
		pairs[k] = _new_pair(mini(a, b), maxi(a, b))
	return pairs[k]


func _new_pair(a: int, b: int) -> Dictionary:
	return {"a": a, "b": b, "opinion": 0.0, "grievance": 0.0, "war": false, "war_start": -1,
		"last_peace": sim.tick, "reasons": [], "casualties": [0, 0], "month_cas": [0, 0], "targets": [-1, -1],
		"cities_lost": [0, 0]}


func at_war(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0:
		return false
	var p: Dictionary = pairs.get(pair_key(a, b), {})
	return bool(p.get("war", false))


func enemies_of(k: int) -> PackedInt32Array:
	return _enemies.get(k, PackedInt32Array())


func _rebuild_enemies() -> void:
	_enemies.clear()
	for key: String in pairs:
		var p: Dictionary = pairs[key]
		if p["war"]:
			var a := int(p["a"])
			var b := int(p["b"])
			var ea: PackedInt32Array = _enemies.get(a, PackedInt32Array())
			ea.append(b)
			_enemies[a] = ea
			var eb: PackedInt32Array = _enemies.get(b, PackedInt32Array())
			eb.append(a)
			_enemies[b] = eb


func is_at_war(k: int) -> bool:
	return enemies_of(k).size() > 0


func kingdom_of_unit(s: int) -> int:
	var c: City = sim.cities.get(sim.units.city[s], null)
	return c.kingdom if c != null else -1


## City this kingdom's soldiers should march on in its war against `enemy`.
func war_target(k: int, enemy: int) -> int:
	var p: Dictionary = pairs.get(pair_key(k, enemy), {})
	if p.is_empty() or not p["war"]:
		return -1
	return int((p["targets"] as Array)[0 if int(p["a"]) == k else 1])


func ruler_aggression(k: Kingdom) -> float:
	var s := sim.units.slot_for(k.ruler_id)
	if s < 0:
		return 0.5
	var base := float((sim.units.look[s] >> 12) & 15) / 15.0
	return minf(1.0, base + 0.35) if Traits.has(sim.units.traits[s], Traits.WARLIKE) else base


func population(k: Kingdom) -> int:
	var n := 0
	for cid in k.cities:
		n += (sim.cities[cid] as City).population()
	return n


## Adults able to fight (all adult members); cached for the current tick.
func strength(k: Kingdom) -> int:
	if _strength_tick != sim.tick:
		_strength.clear()
		_strength_tick = sim.tick
	if not _strength.has(k.id):
		_strength[k.id] = _count_strength(k)
	return _strength[k.id]


func _count_strength(k: Kingdom) -> int:
	var u := sim.units
	var adult := float((Defs.species[sim.human_species] as Defs.SpeciesDef).adult_age)
	var n := 0
	for cid in k.cities:
		for mid in (sim.cities[cid] as City).members:
			var s := u.slot_for(mid)
			if s >= 0 and u.age_years(s, sim.tick) >= adult:
				n += 1
	return n


# ------------------------------------------------------------------ lifecycle

func create_for_city(c: City, parent: int, cause: String) -> Kingdom:
	var k := Kingdom.new()
	k.id = sim.next_kingdom_id
	sim.next_kingdom_id += 1
	k.species = c.species
	k.parent = parent
	k.founded_tick = sim.tick
	var rs := sim.units.slot_for(c.leader_id)
	k.name = NameGen.realm_name(Defs.species[c.species], sim.rng, c.name, sim.units.name[rs] if rs >= 0 else "")
	k.color_index = _free_color()
	k.capital = c.id
	k.ruler_id = c.leader_id
	sim.kingdoms[k.id] = k
	_attach(k, c)
	c.loyalty = 100.0
	sim.history.record(sim.tick, HistoryLog.Kind.KINGDOM_FOUNDED, "The %s arose (%s)." % [k.name, cause], {"kingdom": k.id, "city": c.id}, c.center)
	return k


## Least-used palette colour among living kingdoms (stable tie-break by index).
func _free_color() -> int:
	var used := {}
	for k: Kingdom in sim.kingdoms.values():
		used[k.color_index] = int(used.get(k.color_index, 0)) + 1
	var best := 0
	var best_n := 1 << 30
	for i in AssetForge.CITY_COLORS.size():
		var n: int = used.get(i, 0)
		if n < best_n:
			best_n = n
			best = i
	return best


func _attach(k: Kingdom, c: City) -> void:
	c.kingdom = k.id
	c.joined_tick = sim.tick
	if not k.cities.has(c.id):
		k.cities.append(c.id)
	c.color_index = k.color_index
	_mark_city_dirty(c)


func _mark_city_dirty(c: City) -> void:
	for i in c.territory:
		sim.world.mark_dirty(i)


func add_city(k: Kingdom, c: City) -> void:
	_attach(k, c)
	c.loyalty = 80.0


## Detaches a city from its kingdom (abandonment, conquest, rebellion).
func detach_city(c: City) -> void:
	var k: Kingdom = sim.kingdoms.get(c.kingdom, null)
	c.kingdom = -1
	if k == null:
		return
	var i := k.cities.find(c.id)
	if i >= 0:
		k.cities.remove_at(i)
	if k.cities.is_empty():
		_fall(k, "its last city was lost")
	elif k.capital == c.id:
		_choose_capital(k)


func _choose_capital(k: Kingdom) -> void:
	var best: City = null
	for cid in k.cities:
		var c: City = sim.cities[cid]
		if best == null or c.population() > best.population():
			best = c
	k.capital = best.id
	k.ruler_id = best.leader_id
	sim.history.record(sim.tick, HistoryLog.Kind.LEADER_CHANGED, "%s became the new capital of the %s." % [best.name, k.name], {"kingdom": k.id, "city": best.id}, best.center)


func _fall(k: Kingdom, reason: String) -> void:
	k.alive = false
	sim.kingdoms.erase(k.id)
	for key: String in pairs.keys():
		var p: Dictionary = pairs[key]
		if int(p["a"]) == k.id or int(p["b"]) == k.id:
			pairs.erase(key)
	_rebuild_enemies()
	sim.history.record(sim.tick, HistoryLog.Kind.KINGDOM_FALLEN, "The %s fell: %s." % [k.name, reason], {"kingdom": k.id})
	sim.decisions.record(sim.tick, "war", k.name, "fell", [["reason", reason]], {"kingdom": k.id})


func transfer_city(c: City, to: Kingdom, cause: String) -> void:
	var from: Kingdom = sim.kingdoms.get(c.kingdom, null)
	var from_name := from.name if from != null else "no one"
	var from_id := from.id if from != null else -1
	if from != null:
		from.exhaustion = minf(100.0, from.exhaustion + 15.0)
		var p: Dictionary = pairs.get(pair_key(from.id, to.id), {})
		if not p.is_empty():
			(p["cities_lost"] as Array)[0 if int(p["a"]) == from.id else 1] += 1
	detach_city(c)
	add_city(to, c)
	c.loyalty = 40.0
	var tp: Dictionary = pairs.get(pair_key(from_id, to.id), {})
	if not tp.is_empty():
		tp["last_capture"] = sim.tick
	sim.history.record(sim.tick, HistoryLog.Kind.CITY_CONQUERED, "%s was %s by the %s (from the %s)." % [c.name, cause, to.name, from_name], {"kingdom": to.id, "city": c.id, "from": from_id}, c.center)
	sim.push_fx("conquest", c.center)


# ------------------------------------------------------------------ monthly

func monthly() -> void:
	for k: Kingdom in sim.kingdoms.values():
		_update_ruler(k)
		_update_loyalty(k)
	if sim.laws.is_on("diplomacy"):
		_update_relations()
	_update_wars()
	_sieges()
	if sim.laws.is_on("rebellions"):
		_rebellions()


func _update_ruler(k: Kingdom) -> void:
	var cap: City = sim.cities.get(k.capital, null)
	if cap == null:
		if not k.cities.is_empty():
			_choose_capital(k)
		return
	if cap.leader_id != k.ruler_id and sim.units.is_alive_id(cap.leader_id):
		k.ruler_id = cap.leader_id
		# The capital's succession entry already names the new ruler.
		var s := sim.units.slot_for(k.ruler_id)
		sim.decisions.record(sim.tick, "succession", k.name, "is now ruled by %s" % sim.units.name[s], [["capital", cap.name]], {"kingdom": k.id})


func _update_loyalty(k: Kingdom) -> void:
	var cap: City = sim.cities.get(k.capital, null)
	if cap == null:
		return
	var w := sim.world.width
	var cp := Vector2(cap.center % w, cap.center / w)
	var rs := sim.units.slot_for(k.ruler_id)
	var temper := 0.0
	if rs >= 0:
		if Traits.has(sim.units.traits[rs], Traits.JUST):
			temper = 10.0
		elif Traits.has(sim.units.traits[rs], Traits.GREEDY):
			temper = -10.0
	for cid in k.cities:
		var c: City = sim.cities[cid]
		if c.id == k.capital:
			c.loyalty = 100.0
			continue
		var d := cp.distance_to(Vector2(c.center % w, c.center / w))
		var target := 100.0 - d * 0.9 - maxf(0.0, k.cities.size() - 3) * 3.0 - k.exhaustion * 0.4 + temper
		if sim.civ.has_building(c, "temple"):
			target += float(Defs.building_by_id("temple").raw.get("loyalty", 10))
		c.loyalty = clampf(c.loyalty + (clampf(target, 0.0, 100.0) - c.loyalty) * 0.1, 0.0, 100.0)


func _update_relations() -> void:
	var ks: Array = sim.kingdoms.values()
	var w := sim.world.width
	var centers := {}
	for k: Kingdom in ks:
		var pts: Array[Vector2] = []
		for cid in k.cities:
			var c: City = sim.cities[cid]
			pts.append(Vector2(c.center % w, c.center / w))
		centers[k.id] = pts
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			var a: Kingdom = ks[i]
			var b: Kingdom = ks[j]
			var dmin := INF
			for pa: Vector2 in centers[a.id]:
				for pb: Vector2 in centers[b.id]:
					dmin = minf(dmin, pa.distance_to(pb))
			# Distant realms with no shared history have no relations to track.
			if dmin > NEIGHBOUR_RANGE and not pairs.has(pair_key(a.id, b.id)):
				continue
			var p := pair(a.id, b.id)
			var reasons: Array = []
			var total := 0.0
			if dmin < BORDER_RANGE:
				var v := -30.0 * (BORDER_RANGE - dmin) / BORDER_RANGE
				reasons.append(["border tension", v])
				total += v
			var temper := -12.0 * (ruler_aggression(a) + ruler_aggression(b))
			reasons.append(["rulers' temperament", temper])
			total += temper
			p["grievance"] = float(p["grievance"]) * GRIEVANCE_DECAY
			if float(p["grievance"]) > 0.5:
				reasons.append(["grievances from bloodshed", -float(p["grievance"])])
				total -= float(p["grievance"])
			if not p["war"]:
				var peace_years := minf(PEACE_BONUS_CAP, 0.5 * float(sim.tick - int(p["last_peace"])) / SimConst.TICKS_PER_YEAR)
				reasons.append(["years of peace", peace_years])
				total += peace_years
			# A much stronger neighbour covets the weaker one's land.
			if dmin < BORDER_RANGE:
				var sa := strength(a)
				var sb := strength(b)
				if maxi(sa, sb) >= 8 and float(maxi(sa, sb)) / maxf(1.0, mini(sa, sb)) >= COVET_RATIO:
					reasons.append(["coveted land", COVET_OPINION])
					total += COVET_OPINION
			if a.parent == b.id or b.parent == a.id:
				reasons.append(["shared origin", 12.0])
				total += 12.0
			if _common_enemy(a.id, b.id):
				reasons.append(["common enemy", 15.0])
				total += 15.0
			p["opinion"] = total
			p["reasons"] = reasons


func _common_enemy(a: int, b: int) -> bool:
	var ea := enemies_of(a)
	for e in enemies_of(b):
		if ea.has(e):
			return true
	return false


func _update_wars() -> void:
	for key: String in pairs.keys():
		if not pairs.has(key):
			continue
		var p: Dictionary = pairs[key]
		var a: Kingdom = sim.kingdoms.get(int(p["a"]), null)
		var b: Kingdom = sim.kingdoms.get(int(p["b"]), null)
		if a == null or b == null:
			pairs.erase(key)
			_rebuild_enemies()
			continue
		if p["war"]:
			_war_month(p, a, b)
		elif sim.laws.is_on("wars"):
			_consider_war(p, a, b)
	for k: Kingdom in sim.kingdoms.values():
		if not is_at_war(k.id):
			k.exhaustion = maxf(0.0, k.exhaustion - 3.0)


func _consider_war(p: Dictionary, a: Kingdom, b: Kingdom) -> void:
	if float(p["opinion"]) >= WAR_THRESHOLD:
		return
	if float(sim.tick - int(p["last_peace"])) / SimConst.TICKS_PER_YEAR < MIN_YEARS_BETWEEN_WARS:
		return
	# The more aggressive ruler declares; one war at a time per aggressor.
	var att := a if ruler_aggression(a) >= ruler_aggression(b) else b
	var def := b if att == a else a
	if is_at_war(att.id):
		return
	var sa := strength(att)
	var sd := strength(def)
	if sa < maxi(4, int(sd * 0.8)):
		return
	if not sim.rng.chance(DECLARE_CHANCE):
		return
	var reasons: Array = (p["reasons"] as Array).duplicate(true)
	reasons.append(["opinion", float(p["opinion"])])
	reasons.append(["war threshold", WAR_THRESHOLD])
	reasons.append(["strength ratio", float(sa) / maxf(1.0, sd)])
	declare_war(att, def, reasons)


func declare_war(att: Kingdom, def: Kingdom, reasons: Array) -> void:
	var p := pair(att.id, def.id)
	if p["war"]:
		return
	p["war"] = true
	p["war_start"] = sim.tick
	_rebuild_enemies()
	p["casualties"] = [0, 0]
	p["cities_lost"] = [0, 0]
	_retarget(p)
	sim.history.record(sim.tick, HistoryLog.Kind.WAR_DECLARED, "The %s declared war on the %s." % [att.name, def.name], {"kingdom": att.id, "enemy": def.id}, _capital_tile(att))
	sim.decisions.record(sim.tick, "war", att.name, "declared war on the %s" % def.name, reasons, {"kingdom": att.id, "enemy": def.id})


func make_peace(a: Kingdom, b: Kingdom, reasons: Array) -> void:
	var p := pair(a.id, b.id)
	if not p["war"]:
		return
	p["war"] = false
	p["last_peace"] = sim.tick
	_rebuild_enemies()
	p["grievance"] = float(p["grievance"]) * 0.5
	p["targets"] = [-1, -1]
	sim.history.record(sim.tick, HistoryLog.Kind.PEACE, "The %s and the %s made peace after %.1f years of war." % [a.name, b.name, float(sim.tick - int(p["war_start"])) / SimConst.TICKS_PER_YEAR], {"kingdom": a.id, "enemy": b.id}, _capital_tile(a))
	sim.decisions.record(sim.tick, "war", a.name, "made peace with the %s" % b.name, reasons, {"kingdom": a.id, "enemy": b.id})


func _war_month(p: Dictionary, a: Kingdom, b: Kingdom) -> void:
	var mc: Array = p["month_cas"]
	a.exhaustion = minf(100.0, a.exhaustion + 1.0 + int(mc[0]) * 1.5)
	b.exhaustion = minf(100.0, b.exhaustion + 1.0 + int(mc[1]) * 1.5)
	p["month_cas"] = [0, 0]
	_retarget(p)
	var years := float(sim.tick - int(p["war_start"])) / SimConst.TICKS_PER_YEAR
	var tired := a.exhaustion >= PEACE_EXHAUSTION or b.exhaustion >= PEACE_EXHAUSTION
	var quiet_years := float(sim.tick - maxi(int(p["war_start"]), int(p.get("last_capture", -1000000)))) / SimConst.TICKS_PER_YEAR
	var stalemate := years >= STALEMATE_YEARS and quiet_years >= STALEMATE_YEARS * 0.5
	var rebel_war := a.parent == b.id or b.parent == a.id
	if rebel_war and years >= INDEPENDENCE_YEARS and sim.rng.chance(PEACE_CHANCE):
		stalemate = true
		tired = true
	if (tired and sim.rng.chance(PEACE_CHANCE)) or (stalemate and sim.rng.chance(STALEMATE_PEACE_CHANCE)) or years > MAX_WAR_YEARS:
		var cas: Array = p["casualties"]
		make_peace(a, b, [["war weariness (%s)" % a.name, a.exhaustion], ["war weariness (%s)" % b.name, b.exhaustion],
			["years at war", years], ["dead (%s)" % a.name, int(cas[0])], ["dead (%s)" % b.name, int(cas[1])]])


## Each side marches on the enemy city nearest its own capital.
func _retarget(p: Dictionary) -> void:
	var t := [-1, -1]
	for side in 2:
		var me: Kingdom = sim.kingdoms.get(int(p["a"] if side == 0 else p["b"]), null)
		var foe: Kingdom = sim.kingdoms.get(int(p["b"] if side == 0 else p["a"]), null)
		if me == null or foe == null:
			continue
		var from := _capital_tile(me)
		var w := sim.world.width
		var best := -1
		var best_d := INF
		for cid in foe.cities:
			var c: City = sim.cities[cid]
			var d := Vector2(c.center % w - from % w, c.center / w - from / w).length()
			if d < best_d:
				best_d = d
				best = cid
		t[side] = best
	p["targets"] = t


func _capital_tile(k: Kingdom) -> int:
	var c: City = sim.cities.get(k.capital, null)
	return c.center if c != null else -1


## Records a battle death for weariness, grudges and the chronicle.
func record_battle_death(victim_kingdom: int, killer_kingdom: int) -> void:
	if victim_kingdom < 0 or killer_kingdom < 0 or victim_kingdom == killer_kingdom:
		return
	var p := pair(victim_kingdom, killer_kingdom)
	var side := 0 if int(p["a"]) == victim_kingdom else 1
	(p["casualties"] as Array)[side] += 1
	(p["month_cas"] as Array)[side] += 1
	p["grievance"] = minf(80.0, float(p["grievance"]) + GRIEVANCE_PER_DEATH)


## A city with at least SIEGE_MIN_ATTACKERS enemy soldiers near its hall and no
## defending soldiers there falls to the kingdom with the most attackers present.
func _sieges() -> void:
	var soldier := Defs.job_by_id("soldier").index
	var u := sim.units
	var w := sim.world.width
	for c: City in sim.cities.values():
		if c.kingdom < 0 or not is_at_war(c.kingdom):
			continue
		var foes := enemies_of(c.kingdom)
		var attackers := {}
		var defenders := 0
		for o in sim.spatial.query_radius(u, c.center % w + 0.5, c.center / w + 0.5, SIEGE_RADIUS, sim.human_species):
			if u.job[o] != soldier:
				continue
			var ok := kingdom_of_unit(o)
			if ok == c.kingdom:
				defenders += 1
			elif foes.has(ok):
				attackers[ok] = int(attackers.get(ok, 0)) + 1
		# Watchtowers hold the walls like extra defenders.
		defenders += sim.civ.count_complete(c, "watchtower") * int(Defs.building_by_id("watchtower").raw.get("defenders", 3))
		if defenders > 0 or attackers.is_empty():
			continue
		var best := -1
		var best_n := 0
		for kid: int in attackers:
			if int(attackers[kid]) > best_n:
				best_n = attackers[kid]
				best = kid
		if best_n >= SIEGE_MIN_ATTACKERS and sim.kingdoms.has(best):
			var winner: Kingdom = sim.kingdoms[best]
			sim.decisions.record(sim.tick, "war", winner.name, "captured %s" % c.name,
				[["attacking soldiers at the hall", best_n], ["defending soldiers", defenders]], {"kingdom": winner.id, "city": c.id})
			transfer_city(c, winner, "conquered")


func _rebellions() -> void:
	for k: Kingdom in sim.kingdoms.values():
		if k.cities.size() < 2:
			continue
		for cid in k.cities.duplicate():
			var c: City = sim.cities.get(cid, null)
			if c == null or c.id == k.capital or c.loyalty >= REBEL_LOYALTY or c.population() < REBEL_MIN_POP:
				continue
			if sim.tick - c.joined_tick < int(OCCUPATION_GRACE_YEARS * SimConst.TICKS_PER_YEAR):
				continue
			if sim.rng.chance(REBEL_CHANCE * (REBEL_LOYALTY - c.loyalty) / REBEL_LOYALTY):
				rebel(c, [["loyalty", c.loyalty], ["rebellion threshold", REBEL_LOYALTY], ["war weariness of the crown", k.exhaustion]])
				return


func rebel(c: City, reasons: Array) -> Kingdom:
	var old: Kingdom = sim.kingdoms.get(c.kingdom, null)
	if old == null or old.cities.size() < 2:
		return null
	detach_city(c)
	var nk := create_for_city(c, old.id, "%s rebelled against the %s" % [c.name, old.name])
	c.loyalty = 100.0
	# Nearby disloyal provinces join the uprising.
	var w := sim.world.width
	var joined := 0
	for cid in old.cities.duplicate():
		if joined >= REBEL_MAX_JOINERS or old.cities.size() < 2:
			break
		var o: City = sim.cities.get(cid, null)
		if o == null or o.id == old.capital or o.loyalty >= REBEL_JOIN_LOYALTY:
			continue
		if Vector2(o.center % w - c.center % w, o.center / w - c.center / w).length() <= REBEL_JOIN_RANGE:
			detach_city(o)
			add_city(nk, o)
			joined += 1
	sim.history.record(sim.tick, HistoryLog.Kind.REBELLION, "%s rose in rebellion against the %s and founded the %s." % [c.name, old.name, nk.name], {"kingdom": nk.id, "city": c.id, "from": old.id}, c.center)
	sim.decisions.record(sim.tick, "rebellion", c.name, "rebelled against the %s" % old.name, reasons, {"kingdom": nk.id, "city": c.id})
	if sim.kingdoms.has(old.id) and sim.laws.is_on("wars"):
		declare_war(old, nk, [["cause", "rebellion"]])
	return nk


func to_dict() -> Dictionary:
	return {"pairs": pairs.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	pairs = d.get("pairs", {})
	_rebuild_enemies()
