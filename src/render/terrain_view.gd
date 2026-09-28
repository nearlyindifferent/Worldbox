class_name TerrainView
extends Node2D
## Observes WorldGrid and mirrors it into GPU data textures. Only chunks whose
## revision changed are re-encoded, and uploads are throttled, so cost scales with
## change rate rather than world size. Never writes simulation state.

enum Overlay { NONE, FERTILITY, TEMPERATURE, MOISTURE, ELEVATION, VEGETATION, BIOME_ID, OWNERSHIP }
const OVERLAY_NAMES := ["None", "Fertility", "Temperature", "Moisture", "Elevation", "Vegetation", "Biome ID", "Ownership"]
const REFRESH_SEC := 0.12
const MAX_CHUNKS_PER_REFRESH := 96

var sim: Simulation
var overlay: int = Overlay.NONE
var _sprite := Sprite2D.new()
var _mat := ShaderMaterial.new()
var _data := PackedByteArray()
var _owner := PackedByteArray()
var _data_img: Image
var _owner_img: Image
var _data_tex: ImageTexture
var _owner_tex: ImageTexture
var _overlay_tex: ImageTexture
var _seen := PackedInt32Array()
var _timer := 0.0
var _overlay_timer := 0.0
var _anim := 0.0
var chunks_updated_total: int = 0


func _ready() -> void:
	_mat.shader = load("res://src/render/shaders/terrain.gdshader")
	_sprite.material = _mat
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	var atlas := ImageTexture.create_from_image(AssetForge.build_tile_atlas_cached())
	_mat.set_shader_parameter("atlas", atlas)
	var pal := Image.create(AssetForge.CITY_COLORS.size(), 1, false, Image.FORMAT_RGBA8)
	for k in AssetForge.CITY_COLORS.size():
		pal.set_pixel(k, 0, Color(AssetForge.CITY_COLORS[k]))
	_mat.set_shader_parameter("city_palette", ImageTexture.create_from_image(pal))
	_mat.set_shader_parameter("farmland_index", Defs.farmland_index)
	_mat.set_shader_parameter("forest_index", Defs.forest_index)
	_mat.set_shader_parameter("grass_index", Defs.grassland_index)
	_mat.set_shader_parameter("lava_index", Defs.biome_index("lava"))
	_mat.set_shader_parameter("chunk_size", float(SimConst.CHUNK))


func bind(p_sim: Simulation) -> void:
	sim = p_sim
	var w := sim.world
	_data.resize(w.size * 4)
	_owner.resize(w.size * 4)
	for c in w.chunks_x * w.chunks_y:
		_encode_chunk(c)
	_seen = w.chunk_rev.duplicate()
	_data_img = Image.create_from_data(w.width, w.height, false, Image.FORMAT_RGBA8, _data)
	_owner_img = Image.create_from_data(w.width, w.height, false, Image.FORMAT_RGBA8, _owner)
	_data_tex = ImageTexture.create_from_image(_data_img)
	_owner_tex = ImageTexture.create_from_image(_owner_img)
	var blank := Image.create(w.width, w.height, false, Image.FORMAT_RGBA8)
	_overlay_tex = ImageTexture.create_from_image(blank)
	_sprite.texture = _data_tex
	_sprite.scale = Vector2(AssetForge.TILE, AssetForge.TILE)
	_mat.set_shader_parameter("data_tex", _data_tex)
	_mat.set_shader_parameter("owner_tex", _owner_tex)
	_mat.set_shader_parameter("overlay_tex", _overlay_tex)
	_mat.set_shader_parameter("world_size", Vector2(w.width, w.height))
	set_overlay(overlay)


func world_pixel_size() -> Vector2:
	return Vector2(sim.world.width, sim.world.height) * AssetForge.TILE


func _process(delta: float) -> void:
	if sim == null:
		return
	_anim += delta
	_mat.set_shader_parameter("anim_time", _anim)
	_timer += delta
	if _timer >= REFRESH_SEC:
		_timer = 0.0
		refresh()
	if overlay != Overlay.NONE:
		_overlay_timer += delta
		if _overlay_timer > 1.0:
			_overlay_timer = 0.0
			_build_overlay()


## Re-encodes changed chunks and uploads textures. Returns chunks updated.
func refresh(force_all: bool = false) -> int:
	var w := sim.world
	var n := 0
	for c in w.chunk_rev.size():
		if force_all or w.chunk_rev[c] != _seen[c]:
			_seen[c] = w.chunk_rev[c]
			_encode_chunk(c)
			n += 1
			if n >= MAX_CHUNKS_PER_REFRESH and not force_all:
				break
	if n > 0:
		_data_img.set_data(w.width, w.height, false, Image.FORMAT_RGBA8, _data)
		_owner_img.set_data(w.width, w.height, false, Image.FORMAT_RGBA8, _owner)
		_data_tex.update(_data_img)
		_owner_tex.update(_owner_img)
		chunks_updated_total += n
	return n


func _encode_chunk(c: int) -> void:
	var w := sim.world
	var x0 := (c % w.chunks_x) * SimConst.CHUNK
	var y0 := (c / w.chunks_x) * SimConst.CHUNK
	var x1 := mini(x0 + SimConst.CHUNK, w.width)
	var y1 := mini(y0 + SimConst.CHUNK, w.height)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * w.width + x
			var k := i * 4
			var b := w.biome[i]
			_data[k] = b
			_data[k + 1] = (w.variant[i] & 3) | ((w.vegetation[i] >> 6) << 2) | ((w.wood[i] >> 6) << 4)
			var e := w.elevation[i]
			var enw := w.elevation[i - w.width - 1] if x > 0 and y > 0 else e
			_data[k + 2] = int(clampf(0.5 + (e - enw) * 7.0, 0.0, 1.0) * 255.0)
			var o := w.owner[i]
			if o == SimConst.CITY_NONE or not sim.cities.has(o):
				_owner[k] = 0
				_owner[k + 1] = 0
				_owner[k + 2] = 0
				_owner[k + 3] = 0
			else:
				var oc: City = sim.cities[o]
				_owner[k] = o & 255
				_owner[k + 1] = (o >> 8) & 255
				_owner[k + 2] = oc.color_index + 1
				_owner[k + 3] = (oc.kingdom * 37) & 255
			_data[k + 3] = 255 if sim.disasters.on_fire[i] == 1 else 0


func set_territory_visible(on: bool) -> void:
	_mat.set_shader_parameter("show_territory", on)


## Stronger territory fill when zoomed out so the political map reads at a glance.
func set_zoom_hint(zoom: float) -> void:
	_mat.set_shader_parameter("territory_fill", clampf(0.55 - zoom * 0.3, 0.14, 0.45))


func set_chunks_visible(on: bool) -> void:
	_mat.set_shader_parameter("show_chunks", on)


func set_overlay(mode: int) -> void:
	overlay = mode
	_mat.set_shader_parameter("overlay_alpha", 0.0 if mode == Overlay.NONE else 0.85)
	if mode != Overlay.NONE and sim != null:
		_build_overlay()


func _build_overlay() -> void:
	var w := sim.world
	var bytes := PackedByteArray()
	bytes.resize(w.size * 4)
	for i in w.size:
		var c := _overlay_color(i)
		var k := i * 4
		bytes[k] = int(c.r * 255)
		bytes[k + 1] = int(c.g * 255)
		bytes[k + 2] = int(c.b * 255)
		bytes[k + 3] = int(c.a * 255)
	_overlay_tex.update(Image.create_from_data(w.width, w.height, false, Image.FORMAT_RGBA8, bytes))


func _overlay_color(i: int) -> Color:
	var w := sim.world
	match overlay:
		Overlay.FERTILITY:
			return _ramp(w.fertility(i)) if w.is_walkable(i) else Color(0, 0, 0, 0)
		Overlay.TEMPERATURE:
			return _ramp(clampf((w.temperature[i] + 10.0) / 45.0, 0.0, 1.0))
		Overlay.MOISTURE:
			return _ramp(w.moisture[i])
		Overlay.ELEVATION:
			return _ramp(w.elevation[i])
		Overlay.VEGETATION:
			return _ramp(w.vegetation[i] / 255.0) if w.is_walkable(i) else Color(0, 0, 0, 0)
		Overlay.BIOME_ID:
			var h := float((w.biome[i] * 37) % 16) / 16.0
			return Color.from_hsv(h, 0.7, 0.9, 1.0)
		Overlay.OWNERSHIP:
			var o := w.owner[i]
			return Color.from_hsv(float((o * 53) % 97) / 97.0, 0.8, 0.9, 1.0) if o != SimConst.CITY_NONE else Color(0, 0, 0, 0.6)
	return Color(0, 0, 0, 0)


static func _ramp(v: float) -> Color:
	# Blue → green → yellow → red perceptual-ish ramp.
	v = clampf(v, 0.0, 1.0)
	if v < 0.33:
		return Color(0.15, 0.25 + v * 1.5, 0.75 - v, 1.0)
	if v < 0.66:
		return Color((v - 0.33) * 2.6, 0.75, 0.2, 1.0)
	return Color(0.9, 0.75 - (v - 0.66) * 1.9, 0.15, 1.0)
