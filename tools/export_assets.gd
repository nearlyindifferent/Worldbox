extends SceneTree
## Exports every procedural atlas (materials resolved with sample colors) to
## tools/out/assets_*.png at 4x scale for visual review.
func _init() -> void:
	Defs.ensure_loaded()
	var scale := 4
	var tiles := AssetForge.build_tile_atlas()
	_save(tiles, "tiles", scale)
	var units := AssetForge.build_unit_atlas()
	var ru := Image.create(units.get_width(), units.get_height(), false, Image.FORMAT_RGBA8)
	for y in units.get_height():
		for x in units.get_width():
			var c := units.get_pixel(x, y)
			if c.a > 0: ru.set_pixel(x, y, AssetForge._resolve_mat(c, Color(AssetForge.CITY_COLORS[1])))
	_save(ru, "units", scale * 2)
	var b := AssetForge.build_building_atlas()
	var rb := Image.create(b.get_width(), b.get_height(), false, Image.FORMAT_RGBA8)
	rb.fill(Color("#57983a"))
	for y in b.get_height():
		for x in b.get_width():
			var c := b.get_pixel(x, y)
			if c.a > 0: rb.set_pixel(x, y, AssetForge._resolve_mat(c, Color(AssetForge.CITY_COLORS[0])))
	_save(rb, "buildings", scale)
	var icons := AssetForge.build_icon_atlas()
	var bg := Image.create(icons.get_width(), icons.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color("#3a2c26"))
	bg.blend_rect(icons, Rect2i(Vector2i.ZERO, icons.get_size()), Vector2i.ZERO)
	_save(bg, "icons", scale)
	quit()

func _save(img: Image, name: String, scale: int) -> void:
	var c := img.duplicate() as Image
	c.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	c.save_png("res://tools/out/assets_%s.png" % name)
	print("saved ", name, " ", c.get_size())
