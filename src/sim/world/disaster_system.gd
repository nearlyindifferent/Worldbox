class_name DisasterSystem
extends RefCounted
## Fire, lava, earthquakes, meteors and plague: the destructive half of the sandbox.
##
## Fire is a sparse cellular automaton. `burning` lists the tiles on fire in
## ignition order (deterministic iteration) with their remaining `fuel`; `on_fire`
## is a dense derived lookup rebuilt on load. Every FIRE_STEP ticks each fire
## burns one unit of fuel, scorches creatures standing in it, may destroy the
## building it sits on and may spread to neighbours depending on their biome,
## vegetation and moisture. Burnt-out wild land becomes Scorched ground, which
## regrows into grassland (see VegetationSystem).
##
## Lava tiles are impassable, ignite neighbours, flow a few tiles downhill and
## cool into Ashlands. Earthquakes run for a short time, collapsing buildings and
## opening a fissure. Plague lives on units (UnitStore.disease): the sick slowly
## lose health, infect neighbours of their species and either die or recover
## with lifelong immunity.

const FIRE_STEP := 3
const MAX_BURNING := 8000
const FIRE_DAMAGE := 7.0              ## health per fire step to a creature standing in flames
const BUILDING_BURN_CHANCE := 0.12    ## per fire step on a building tile
const FLEE_DISTANCE := 6
const LAVA_COOL_STEPS := 80
const LAVA_DAMAGE := 40.0
const LAVA_IGNITE_CHANCE := 0.3
const QUAKE_TICKS := 60
const QUAKE_COLLAPSE_CHANCE := 0.35
const PLAGUE_TICKS := 120             ## how long an infection lasts
const PLAGUE_SPREAD_EVERY := 6
const PLAGUE_SPREAD_RADIUS := 1.6
const PLAGUE_SPREAD_CHANCE := 0.09
const PLAGUE_DAMAGE := 0.7            ## base health per tick, scaled by a per-person frailty
const NATURAL_FIRE_CHANCE := 0.035    ## per month, world-wide, scaled by world size
const NATURAL_PLAGUE_CHANCE := 0.012  ## per month, world-wide (about one outbreak in 7 years)
const PLAGUE_MIN_POP := 40
const RECORD_GAP_TICKS := 90          ## chronicle rate limit per event key

## Base spread chance per fire step into a tile of each biome (by biome id).
const FLAMMABILITY := {"grassland": 0.05, "forest": 0.3, "hills": 0.06, "swamp": 0.04, "mystic": 0.22,
	"farmland": 0.1, "beach": 0.02, "soil": 0.03, "desert": 0.02, "snow": 0.0, "scorched": 0.0, "volcanic": 0.01}
## Fire steps a tile of each biome burns for.
const FUEL := {"grassland": 3, "forest": 12, "hills": 5, "swamp": 5, "mystic": 9, "farmland": 3, "beach": 2,
	"soil": 2, "desert": 2, "volcanic": 2}

var sim: Simulation
var burning := PackedInt32Array()
var fuel := PackedInt32Array()
var lava := PackedInt32Array()
var lava_t := PackedInt32Array()
var lava_flow := PackedInt32Array()
var quakes: Array = []            ## [{"x", "y", "r", "left"}]
var last_record: Dictionary = {}  ## event key -> tick of its last chronicle entry
## Derived: 1 where a tile is burning.
var on_fire := PackedByteArray()
var _flam := PackedFloat32Array()
var _fuel := PackedInt32Array()
var _scorched: int = -1
var _lava_b: int = -1
var _ash: int = -1


func _init(p_sim: Simulation) -> void:
	sim = p_sim
	on_fire.resize(sim.world.size)
	_flam.resize(Defs.biomes.size())
	_fuel.resize(Defs.biomes.size())
	for b: Defs.BiomeDef in Defs.biomes:
		_flam[b.index] = float(FLAMMABILITY.get(b.id, 0.0))
		_fuel[b.index] = int(FUEL.get(b.id, 0))
	_scorched = Defs.biome_index("scorched")
	_lava_b = Defs.biome_index("lava")
	_ash = Defs.biome_index("volcanic")


func is_burning(i: int) -> bool:
	return on_fire[i] == 1


func can_burn(i: int) -> bool:
	return _fuel[sim.world.biome[i]] > 0 and on_fire[i] == 0


# ------------------------------------------------------------------ tick

func update() -> void:
	if sim.tick % FIRE_STEP == 0 and (burning.size() > 0 or lava.size() > 0):
		_fire_step()
		_lava_step()
	if not quakes.is_empty():
		_quake_tick()
	if sim.tick % PLAGUE_SPREAD_EVERY == 0:
		_plague_spread()


func monthly() -> void:
	if not sim.laws.is_on("natural_disasters"):
		return
	var scale := float(sim.world.size) / 65536.0
	if sim.rng.chance(minf(0.5, NATURAL_FIRE_CHANCE * scale)):
		var i := _dry_fuel_tile()
		if i >= 0:
			ignite(i)
			record("wildfire", HistoryLog.Kind.DISASTER, "Lightning set the land ablaze near %s." % place_name(i), i)
	# Plague is a rare world event that strikes a crowded town (bigger towns are likelier).
	if sim.rng.chance(NATURAL_PLAGUE_CHANCE):
		var total := 0
		for c: City in sim.cities.values():
			if c.population() >= PLAGUE_MIN_POP:
				total += c.population()
		if total > 0:
			var pick := sim.rng.randi_range(0, total - 1)
			for c: City in sim.cities.values():
				if c.population() < PLAGUE_MIN_POP:
					continue
				pick -= c.population()
				if pick >= 0:
					continue
				var n := 0
				for mid in c.members:
					var s := sim.units.slot_for(mid)
					if s >= 0 and infect(s):
						n += 1
					if n >= 2:
						break
				if n > 0:
					record("plague:%d" % c.id, HistoryLog.Kind.DISASTER, "Plague broke out in %s." % c.name, c.center, SimConst.TICKS_PER_YEAR * 5)
				break


func _dry_fuel_tile() -> int:
	var w := sim.world
	for attempt in 60:
		var i := sim.rng.randi_range(0, w.size - 1)
		var b := w.biome[i]
		if (b == Defs.forest_index or b == Defs.grassland_index) and w.moisture[i] < 0.55 and w.vegetation[i] > 120:
			return i
	return -1


# ------------------------------------------------------------------ fire

func ignite(i: int) -> bool:
	if i < 0 or i >= sim.world.size or not can_burn(i) or burning.size() >= MAX_BURNING:
		return false
	burning.append(i)
	fuel.append(_fuel[sim.world.biome[i]])
	on_fire[i] = 1
	sim.world.mark_dirty(i)
	return true


func extinguish_area(x: int, y: int, r: int) -> int:
	var w := sim.world
	var n := 0
	var keep_b := PackedInt32Array()
	var keep_f := PackedInt32Array()
	for k in burning.size():
		var i := burning[k]
		if Vector2(i % w.width - x, i / w.width - y).length() <= r + 0.5:
			on_fire[i] = 0
			w.mark_dirty(i)
			n += 1
		else:
			keep_b.append(i)
			keep_f.append(fuel[k])
	burning = keep_b
	fuel = keep_f
	for k in range(lava.size() - 1, -1, -1):
		var li := lava[k]
		if Vector2(li % w.width - x, li / w.width - y).length() <= r + 0.5:
			lava_t[k] = 0
	return n


func _fire_step() -> void:
	var w := sim.world
	var width := w.width
	var n := burning.size()
	var next_b := PackedInt32Array()
	var next_f := PackedInt32Array()
	var ignite_list := PackedInt32Array()
	var dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for k in n:
		var i := burning[k]
		var x := i % width
		var y := i / width
		# Buildings burn down.
		var bid := w.building[i]
		if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid) and sim.rng.chance(BUILDING_BURN_CHANCE):
			sim.civ.destroy_building(bid, "burned down")
		# Spread.
		for d: Vector2i in dirs:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= width or ny >= w.height:
				continue
			var j := ny * width + nx
			if on_fire[j] == 1:
				continue
			var p := _flam[w.biome[j]]
			if p <= 0.0:
				continue
			if w.biome[j] == Defs.grassland_index or w.biome[j] == Defs.farmland_index:
				p *= 0.35 + 0.65 * float(w.vegetation[j]) / 255.0
			p *= 1.0 - 0.8 * w.moisture[j]
			if w.building[j] != SimConst.BUILDING_ID_NONE:
				p += 0.15
			if d.x != 0 and d.y != 0:
				p *= 0.5
			if sim.rng.chance(p):
				ignite_list.append(j)
		var f := fuel[k] - 1
		if f > 0:
			next_b.append(i)
			next_f.append(f)
		else:
			_burn_out(i)
	burning = next_b
	fuel = next_f
	for j in ignite_list:
		ignite(j)
	_fire_units()


func _burn_out(i: int) -> void:
	var w := sim.world
	on_fire[i] = 0
	var b := w.biome[i]
	if b == Defs.farmland_index:
		w.vegetation[i] = 0
	elif b != _scorched and b != _ash and Defs.biome_walkable[b] == 1 and b != Defs.biome_index("snow"):
		w.set_biome(i, _scorched)
		w.vegetation[i] = 0
		sim.pathfinder.refresh_tile_cost(i)
	else:
		w.vegetation[i] = 0
	w.mark_dirty(i)


## Creatures in flames are hurt; those in or next to flames run away from them.
func _fire_units() -> void:
	var u := sim.units
	var w := sim.world
	var width := w.width
	var dead := PackedInt32Array()
	for s in u.capacity:
		if u.alive[s] == 0:
			continue
		var x := int(u.x[s])
		var y := int(u.y[s])
		var i := y * width + x
		var heat := Vector2.ZERO
		var near := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= width or ny >= w.height:
					continue
				if on_fire[ny * width + nx] == 1:
					near = true
					heat += Vector2(dx, dy)
		if not near:
			continue
		if on_fire[i] == 1 and not u.has_flag(s, UnitStore.Flag.INVULNERABLE):
			u.health[s] -= FIRE_DAMAGE
			if u.health[s] <= 0.0:
				dead.append(s)
				continue
		if u.has_flag(s, UnitStore.Flag.FROZEN) or u.task[s] == UnitStore.Task.FLEE:
			continue
		var away := -heat.normalized() if heat.length() > 0.01 else Vector2(1, 0)
		var tx := clampi(int(u.x[s] + away.x * FLEE_DISTANCE), 0, width - 1)
		var ty := clampi(int(u.y[s] + away.y * FLEE_DISTANCE), 0, w.height - 1)
		var t := w.nearest_walkable(tx, ty, 3)
		if t >= 0 and on_fire[t] == 0:
			sim.movement.stop(s)
			if sim.movement.go_to(s, t, false) == MovementSystem.Plan.OK:
				u.task[s] = UnitStore.Task.FLEE
				u.next_think[s] = sim.tick + 15
	for s in dead:
		sim.kill_unit(s, "fire")


# ------------------------------------------------------------------ lava

func add_lava(i: int, flow: int, cool: int = LAVA_COOL_STEPS) -> void:
	var w := sim.world
	if i < 0 or i >= w.size or Defs.biome_water[w.biome[i]] == 1:
		return
	if w.biome[i] == _lava_b:
		return
	var bid := w.building[i]
	if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid):
		sim.civ.destroy_building(bid, "swallowed by lava")
	if on_fire[i] == 1:
		on_fire[i] = 0
		var k := burning.find(i)
		if k >= 0:
			burning.remove_at(k)
			fuel.remove_at(k)
	w.set_biome(i, _lava_b)
	w.vegetation[i] = 0
	sim.pathfinder.refresh_tile_cost(i)
	lava.append(i)
	lava_t.append(cool)
	lava_flow.append(flow)


func _lava_step() -> void:
	var w := sim.world
	var width := w.width
	var new_lava := PackedInt32Array()
	var new_flow := PackedInt32Array()
	for k in range(lava.size() - 1, -1, -1):
		var i := lava[k]
		var x := i % width
		var y := i / width
		lava_t[k] -= 1
		if w.biome[i] != _lava_b or lava_t[k] <= 0:
			if w.biome[i] == _lava_b:
				w.set_biome(i, _ash)
				sim.pathfinder.refresh_tile_cost(i)
			lava.remove_at(k)
			lava_t.remove_at(k)
			lava_flow.remove_at(k)
			continue
		var best := -1
		var best_e := w.elevation[i]
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= width or ny >= w.height:
				continue
			var j := ny * width + nx
			if _flam[w.biome[j]] > 0.0 and sim.rng.chance(LAVA_IGNITE_CHANCE):
				ignite(j)
			if lava_flow[k] > 0 and w.biome[j] != _lava_b and Defs.biome_water[w.biome[j]] == 0 and w.elevation[j] <= best_e + 0.01:
				best_e = w.elevation[j]
				best = j
		if best >= 0 and lava_flow[k] > 0 and sim.rng.chance(0.5):
			new_lava.append(best)
			new_flow.append(lava_flow[k] - 1)
			lava_flow[k] = 0
	for k in new_lava.size():
		add_lava(new_lava[k], new_flow[k])


# ------------------------------------------------------------------ god powers

func meteor(x: int, y: int, r: int) -> Dictionary:
	var w := sim.world
	var radius := maxf(3.0, float(r) + 2.0)
	var killed := 0
	var u := sim.units
	for s in sim.spatial.query_radius(u, x + 0.5, y + 0.5, radius):
		if u.has_flag(s, UnitStore.Flag.INVULNERABLE):
			continue
		var d := Vector2(u.x[s] - x - 0.5, u.y[s] - y - 0.5).length()
		if d <= radius * 0.6:
			sim.kill_unit(s, "meteor")
			killed += 1
		else:
			u.health[s] -= u.max_health[s] * 0.5
			if u.health[s] <= 0.0:
				sim.kill_unit(s, "meteor")
				killed += 1
	var ri := int(ceil(radius))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var tx := x + dx
			var ty := y + dy
			if not w.in_bounds(tx, ty):
				continue
			var d := Vector2(dx, dy).length()
			if d > radius:
				continue
			var i := w.idx(tx, ty)
			var bid := w.building[i]
			if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid) and d <= radius * 0.85:
				sim.civ.destroy_building(bid, "flattened by a meteor")
			w.elevation[i] = clampf(w.elevation[i] - 0.12 * (1.0 - d / radius), 0.0, 1.0)
			if Defs.biome_water[w.biome[i]] == 1:
				continue
			if d <= radius * 0.3:
				add_lava(i, 1, LAVA_COOL_STEPS / 2)
			elif d <= radius * 0.75:
				if w.biome[i] != _lava_b:
					w.set_biome(i, _scorched if Defs.biome_walkable[w.biome[i]] == 1 else _ash)
					w.vegetation[i] = 0
					sim.pathfinder.refresh_tile_cost(i)
			else:
				ignite(i)
			w.mark_dirty(i)
	sim.spatial.rebuild(sim.units)
	sim.push_fx("meteor", w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1)), {"r": radius})
	record("meteor", HistoryLog.Kind.DISASTER, "A meteor struck near %s%s." % [place_name(w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1))), (", killing %d" % killed) if killed > 0 else ""], w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1)), 0)
	return {"killed": killed}


func earthquake(x: int, y: int, r: int) -> void:
	var w := sim.world
	var radius := maxi(8, r * 2 + 6)
	quakes.append({"x": x, "y": y, "r": radius, "left": QUAKE_TICKS})
	# A fissure opens through the epicentre.
	var ang := sim.rng.randf() * TAU
	var dir := Vector2(cos(ang), sin(ang))
	for k in range(-radius, radius + 1):
		var p := Vector2(x, y) + dir * k + Vector2(sim.rng.randf_range(-0.6, 0.6), sim.rng.randf_range(-0.6, 0.6))
		var tx := int(p.x)
		var ty := int(p.y)
		if not w.in_bounds(tx, ty):
			continue
		var i := w.idx(tx, ty)
		var bid := w.building[i]
		if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid):
			sim.civ.destroy_building(bid, "swallowed by an earthquake")
		w.elevation[i] = clampf(w.elevation[i] - 0.05, 0.0, 1.0)
		if Defs.biome_water[w.biome[i]] == 0 and absi(k) < radius / 3 and sim.rng.chance(0.25):
			add_lava(i, 0, LAVA_COOL_STEPS / 2)
		elif Defs.biome_walkable[w.biome[i]] == 1 and w.biome[i] != _lava_b:
			w.set_biome(i, Defs.biome_index("soil"))
			sim.pathfinder.refresh_tile_cost(i)
		w.mark_dirty(i)
	var at := w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1))
	sim.push_fx("quake", at, {"r": radius, "dur": float(QUAKE_TICKS) / SimConst.TICKS_PER_SECOND})
	record("quake", HistoryLog.Kind.DISASTER, "The earth shook near %s." % place_name(at), at, 0)


func _quake_tick() -> void:
	var w := sim.world
	var u := sim.units
	for q: Dictionary in quakes:
		var qx: int = q["x"]
		var qy: int = q["y"]
		var r: int = q["r"]
		# Damage concentrates near the epicentre.
		for k in 5:
			var dist := float(r) * pow(sim.rng.randf(), 1.5)
			var ang := sim.rng.randf() * TAU
			var tx := qx + int(round(cos(ang) * dist))
			var ty := qy + int(round(sin(ang) * dist))
			if not w.in_bounds(tx, ty):
				continue
			var i := w.idx(tx, ty)
			var bid := w.building[i]
			if bid != SimConst.BUILDING_ID_NONE and sim.buildings.has(bid) and sim.rng.chance(QUAKE_COLLAPSE_CHANCE):
				sim.civ.destroy_building(bid, "collapsed in an earthquake")
			w.elevation[i] = clampf(w.elevation[i] + sim.rng.randf_range(-0.01, 0.01), 0.0, 1.0)
		if int(q["left"]) % 10 == 0:
			var dead := PackedInt32Array()
			for s in sim.spatial.query_radius(u, qx + 0.5, qy + 0.5, r):
				if not u.has_flag(s, UnitStore.Flag.INVULNERABLE) and sim.rng.chance(0.3):
					u.health[s] -= 8.0
					if u.health[s] <= 0.0:
						dead.append(s)
			for s in dead:
				sim.kill_unit(s, "earthquake")
		q["left"] = int(q["left"]) - 1
	quakes = quakes.filter(func(q: Dictionary) -> bool: return int(q["left"]) > 0)


func volcano(x: int, y: int, r: int) -> void:
	var w := sim.world
	var radius := maxi(3, r + 2)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tx := x + dx
			var ty := y + dy
			if not w.in_bounds(tx, ty):
				continue
			var d := Vector2(dx, dy).length()
			if d > radius:
				continue
			var i := w.idx(tx, ty)
			w.elevation[i] = clampf(w.elevation[i] + 0.1 * (1.0 - d / radius), 0.0, 1.0)
			if Defs.biome_water[w.biome[i]] == 1 and d > radius * 0.4:
				continue
			if d <= radius * 0.4:
				add_lava(i, 6 if d <= 1.0 else 2)
			elif w.biome[i] != _lava_b:
				w.set_biome(i, _ash)
				sim.pathfinder.refresh_tile_cost(i)
			w.mark_dirty(i)
	var at := w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1))
	sim.push_fx("quake", at, {"r": radius, "dur": 1.0})
	record("volcano", HistoryLog.Kind.DISASTER, "A volcano erupted near %s." % place_name(at), at, 0)


func rain(x: int, y: int, r: int) -> int:
	var w := sim.world
	var n := extinguish_area(x, y, r + 1)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tx := x + dx
			var ty := y + dy
			if not w.in_bounds(tx, ty) or dx * dx + dy * dy > r * r + r:
				continue
			var i := w.idx(tx, ty)
			w.moisture[i] = minf(1.0, w.moisture[i] + 0.02)
			if Defs.biome_walkable[w.biome[i]] == 1 and w.biome[i] != Defs.farmland_index:
				w.vegetation[i] = mini(Defs.biome_veg_max[w.biome[i]], w.vegetation[i] + 20)
			w.mark_dirty(i)
	return n


# ------------------------------------------------------------------ plague

## Infects a creature unless it is already sick or immune. Returns true if infected.
func infect(s: int) -> bool:
	var u := sim.units
	if u.alive[s] == 0 or u.disease[s] > 0 or u.has_flag(s, UnitStore.Flag.IMMUNE) or u.has_flag(s, UnitStore.Flag.INVULNERABLE):
		return false
	u.disease[s] = PLAGUE_TICKS
	return true


## Per-person frailty in [0.4, 1.6] from the unit id: some shrug the plague off, some die.
static func frailty(uid: int) -> float:
	return 0.4 + float((uid * 2654435761) % 1000) / 1000.0 * 1.2


func _plague_spread() -> void:
	var u := sim.units
	var dead := PackedInt32Array()
	var newly := PackedInt32Array()
	for s in u.capacity:
		if u.alive[s] == 0 or u.disease[s] <= 0:
			continue
		u.disease[s] = maxi(0, u.disease[s] - PLAGUE_SPREAD_EVERY)
		u.health[s] -= PLAGUE_DAMAGE * PLAGUE_SPREAD_EVERY * frailty(u.id[s]) * (1.6 if Traits.has(u.traits[s], Traits.SICKLY) else 1.0)
		if u.health[s] <= 0.0:
			dead.append(s)
			continue
		if u.disease[s] == 0:
			u.set_flag(s, UnitStore.Flag.IMMUNE, true)
			continue
		for o in sim.spatial.query_radius(u, u.x[s], u.y[s], PLAGUE_SPREAD_RADIUS, u.species[s], 6):
			if o != s and u.disease[o] == 0 and not u.has_flag(o, UnitStore.Flag.IMMUNE) and sim.rng.chance(PLAGUE_SPREAD_CHANCE):
				newly.append(o)
	for s in dead:
		sim.kill_unit(s, "plague")
	for o in newly:
		if u.alive[o] == 1:
			infect(o)


func plague_power(x: int, y: int, r: int) -> int:
	var n := 0
	for s in sim.spatial.query_radius(sim.units, x + 0.5, y + 0.5, maxf(1.0, r)):
		if infect(s):
			n += 1
	if n > 0:
		var w := sim.world
		var at := w.idx(clampi(x, 0, w.width - 1), clampi(y, 0, w.height - 1))
		record("plague_power", HistoryLog.Kind.GOD_ACT, "The gods sent a plague upon %s." % place_name(at), at)
	return n


func sick_count() -> int:
	var n := 0
	for s in sim.units.capacity:
		if sim.units.alive[s] == 1 and sim.units.disease[s] > 0:
			n += 1
	return n


# ------------------------------------------------------------------ chronicle

## Records a chronicle entry unless the same key was recorded within `gap` ticks.
func record(key: String, kind: int, text: String, tile: int = -1, gap: int = RECORD_GAP_TICKS) -> void:
	if gap > 0 and sim.tick - int(last_record.get(key, -1000000)) < gap:
		return
	last_record[key] = sim.tick
	var data := {}
	if tile >= 0:
		var c: City = sim.city_at_tile(tile)
		if c != null:
			data["city"] = c.id
	sim.history.record(sim.tick, kind, text, data, tile)


func place_name(i: int) -> String:
	var c: City = sim.city_at_tile(i)
	if c != null:
		return c.name
	var w := sim.world.width
	var best: City = null
	var best_d := 30.0
	for oc: City in sim.cities.values():
		var d := Vector2(oc.center % w - i % w, oc.center / w - i / w).length()
		if d < best_d:
			best_d = d
			best = oc
	return best.name if best != null else "the wilds"


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	return {"burning": burning, "fuel": fuel, "lava": lava, "lava_t": lava_t, "lava_flow": lava_flow,
		"quakes": quakes.duplicate(true), "last_record": last_record.duplicate()}


func from_dict(d: Dictionary) -> void:
	burning = d["burning"]
	fuel = d["fuel"]
	lava = d["lava"]
	lava_t = d["lava_t"]
	lava_flow = d["lava_flow"]
	quakes = (d["quakes"] as Array).duplicate(true)
	last_record = (d["last_record"] as Dictionary).duplicate()
	on_fire.fill(0)
	for i in burning:
		on_fire[i] = 1
