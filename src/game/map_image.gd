class_name MapImage
extends RefCounted
## CPU-rendered political/biome map used for save thumbnails (works headless).


static func render(sim: Simulation, max_px: int = 256) -> Image:
	var w := sim.world
	var img := Image.create(w.width, w.height, false, Image.FORMAT_RGB8)
	var pal: Array[Color] = []
	for b: Defs.BiomeDef in Defs.biomes:
		pal.append(b.colors[1])
	for y in w.height:
		for x in w.width:
			var i := y * w.width + x
			var c := pal[w.biome[i]]
			var o := w.owner[i]
			if o != SimConst.CITY_NONE and sim.cities.has(o):
				c = c.lerp(Color(AssetForge.CITY_COLORS[(sim.cities[o] as City).color_index]), 0.45)
			if w.building[i] != SimConst.BUILDING_ID_NONE:
				c = Color("#e8d8b0")
			img.set_pixel(x, y, c)
	var s := float(max_px) / maxf(w.width, w.height)
	img.resize(maxi(1, int(w.width * s)), maxi(1, int(w.height * s)), Image.INTERPOLATE_NEAREST)
	return img
