extends SceneTree
## Dumps biome maps for several seeds/shapes to tools/out for visual calibration.
func _init() -> void:
	Defs.ensure_loaded()
	for shape in WorldGen.SHAPES:
		for s in [1, 2, 3]:
			var t := Time.get_ticks_msec()
			var g := WorldGen.generate(s, 256, 256, shape)
			var img := Image.create(g.width, g.height, false, Image.FORMAT_RGB8)
			var counts := {}
			for y in g.height:
				for x in g.width:
					var b: int = g.biome[g.idx(x, y)]
					img.set_pixel(x, y, (Defs.biomes[b] as Defs.BiomeDef).colors[1])
					counts[b] = counts.get(b, 0) + 1
			img.save_png("res://tools/out/gen_%s_%d.png" % [shape, s])
			var land := 0
			for b in counts: if Defs.biome_walkable[b]: land += counts[b]
			print(shape, " seed ", s, " ms=", Time.get_ticks_msec() - t, " walkable%=", 100.0 * land / g.size, " ", counts)
	quit()
