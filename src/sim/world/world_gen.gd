class_name WorldGen
extends RefCounted
## Seeded world generation. Pure function of (settings) -> WorldGrid.

const SEA_LEVEL := 0.40
const SHAPES := ["island", "archipelago", "continents"]
const SIZE_PRESETS := {
	"tiny": Vector2i(128, 128),
	"small": Vector2i(192, 192),
	"medium": Vector2i(256, 256),
	"large": Vector2i(384, 384),
	"huge": Vector2i(512, 512),
}


static func generate(seed_value: int, w: int, h: int, shape: String = "island") -> WorldGrid:
	Defs.ensure_loaded()
	var g := WorldGrid.new(w, h)
	var rng := SimRng.new(seed_value ^ 0x5eed)

	# Larger maps get more (not just bigger) features: frequency falls with sqrt(size).
	var span := float(maxi(w, h))
	var feat := 256.0 * sqrt(span / 256.0)
	var elev_noise := FastNoiseLite.new()
	elev_noise.seed = seed_value
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elev_noise.fractal_octaves = 5
	elev_noise.frequency = 3.2 / feat

	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = seed_value + 101
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.fractal_octaves = 3
	ridge_noise.frequency = 2.4 / feat

	var moist_noise := FastNoiseLite.new()
	moist_noise.seed = seed_value + 202
	moist_noise.fractal_octaves = 4
	moist_noise.frequency = 4.0 / feat

	var temp_noise := FastNoiseLite.new()
	temp_noise.seed = seed_value + 303
	temp_noise.frequency = 2.0 / feat

	var centers := _shape_centers(shape, rng)

	for y in h:
		for x in w:
			var i := y * w + x
			var nx := float(x) / w
			var ny := float(y) / h
			var base := elev_noise.get_noise_2d(x, y) * 0.5 + 0.5
			var ridge := ridge_noise.get_noise_2d(x, y) * 0.5 + 0.5
			var mask := _shape_mask(shape, nx, ny, centers)
			var e := base * 0.6 + ridge * ridge * 0.38 + 0.1
			e = e * (0.5 + 0.75 * mask) - (1.0 - mask) * 0.22
			g.elevation[i] = clampf(e, 0.0, 1.0)
			g.moisture[i] = clampf(moist_noise.get_noise_2d(x, y) * 0.6 + 0.5, 0.0, 1.0)
			var lat := absf(ny - 0.5) * 2.0
			g.temperature[i] = 27.0 - lat * 30.0 - maxf(0.0, g.elevation[i] - SEA_LEVEL) * 45.0 + temp_noise.get_noise_2d(x, y) * 6.0
			g.variant[i] = rng.randi_range(0, 255)

	for i in g.size:
		var b := classify(g.elevation[i], g.moisture[i], g.temperature[i])
		g.biome[i] = b
		var def: Defs.BiomeDef = Defs.biomes[b]
		g.wood[i] = def.wood
		g.vegetation[i] = int(def.veg_max * clampf(0.4 + 0.6 * g.moisture[i], 0.0, 1.0))
	_place_special_biomes(g, rng)
	for i in g.size:
		var def2: Defs.BiomeDef = Defs.biomes[g.biome[i]]
		g.wood[i] = def2.wood
		g.vegetation[i] = mini(g.vegetation[i], def2.veg_max) if def2.veg_max > 0 else 0
	return g


## Rare landmarks: ashlands around some high peaks and luminous groves in forests.
static func _place_special_biomes(g: WorldGrid, rng: SimRng) -> void:
	var ash := Defs.biome_index("volcanic")
	var mystic := Defs.biome_index("mystic")
	var count := maxi(1, g.size / 40000)
	for k in count:
		# Ashlands: pick the highest of several mountain samples.
		var best := -1
		for tries in 200:
			var i := rng.randi_range(0, g.size - 1)
			if g.biome[i] == Defs.mountain_index and (best < 0 or g.elevation[i] > g.elevation[best]):
				best = i
		if best >= 0 and rng.chance(0.7):
			_blob(g, best, rng.randi_range(4, 8), ash, rng, true)
		# Glimmerwood: inside an existing forest.
		for tries in 200:
			var j := rng.randi_range(0, g.size - 1)
			if g.biome[j] == Defs.forest_index:
				if rng.chance(0.6):
					_blob(g, j, rng.randi_range(3, 6), mystic, rng, false)
				break


static func _blob(g: WorldGrid, center: int, r: int, b: int, rng: SimRng, over_mountain: bool) -> void:
	var cx := center % g.width
	var cy := center / g.width
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := sqrt(float(dx * dx + dy * dy)) + rng.randf() * 1.5
			if d > r or not g.in_bounds(cx + dx, cy + dy):
				continue
			var i := g.idx(cx + dx, cy + dy)
			if g.is_water(i) or (g.biome[i] == Defs.mountain_index and not over_mountain) or g.biome[i] == Defs.biome_index("snow"):
				continue
			if g.biome[i] == Defs.mountain_index and d < r * 0.4:
				continue
			g.biome[i] = b


static func _shape_centers(shape: String, rng: SimRng) -> Array[Vector3]:
	var out: Array[Vector3] = []
	match shape:
		"archipelago":
			for n in rng.randi_range(6, 9):
				out.append(Vector3(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85), rng.randf_range(0.12, 0.20)))
		"continents":
			for n in 2:
				out.append(Vector3(0.28 + 0.44 * n + rng.randf_range(-0.05, 0.05), rng.randf_range(0.4, 0.6), rng.randf_range(0.30, 0.36)))
		_:
			out.append(Vector3(0.5, 0.5, 0.46))
	return out


## Returns 0..1 land likelihood: 1 near a landmass center, 0 in open sea.
static func _shape_mask(_shape: String, nx: float, ny: float, centers: Array[Vector3]) -> float:
	var m := 0.0
	for c in centers:
		var d := Vector2(nx - c.x, ny - c.y).length() / c.z
		m = maxf(m, clampf(1.0 - d * d * d, 0.0, 1.0))
	var edge := minf(minf(nx, 1.0 - nx), minf(ny, 1.0 - ny))
	return m * clampf(edge * 12.0, 0.0, 1.0)


static func classify(e: float, m: float, t: float) -> int:
	if e < 0.22:
		return Defs.biome_index("deep_ocean")
	if e < 0.34:
		return Defs.biome_index("ocean")
	if e < SEA_LEVEL:
		return Defs.biome_index("shallow")
	if e < 0.425:
		return Defs.biome_index("snow") if t < -4.0 else Defs.biome_index("beach")
	if e > 0.88:
		return Defs.biome_index("snow")
	if e > 0.76:
		return Defs.biome_index("mountain")
	if t < -3.0:
		return Defs.biome_index("snow")
	if e > 0.66:
		return Defs.biome_index("hills")
	if t > 22.0 and m < 0.36:
		return Defs.biome_index("desert")
	if m > 0.74 and e < 0.5:
		return Defs.biome_index("swamp")
	if m > 0.56:
		return Defs.biome_index("forest")
	if m > 0.50 and e < 0.47:
		return Defs.biome_index("soil")
	return Defs.biome_index("grassland")
