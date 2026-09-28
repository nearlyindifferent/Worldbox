class_name SpriteBatch
extends MultiMeshInstance2D
## One draw call for thousands of palette-resolved sprites. Callers fill a flat
## float buffer (16 floats/instance: 2D transform, color, custom) once per frame.

const FLOATS := 16

var _buf := PackedFloat32Array()
var _n := 0
var _frame_size: Vector2


func setup(atlas: Image, frame_size: Vector2, cols: int) -> void:
	_frame_size = frame_size
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(frame_size.x, 0), Vector2(frame_size.x, frame_size.y), Vector2(0, frame_size.y)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 0
	# Instances move every frame; a stale automatic AABB made whole batches get culled.
	multimesh.custom_aabb = AABB(Vector3(-1.0e6, -1.0e6, -1.0), Vector3(2.0e6, 2.0e6, 2.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/render/shaders/sprite.gdshader")
	var tex := ImageTexture.create_from_image(atlas)
	mat.set_shader_parameter("atlas", tex)
	mat.set_shader_parameter("frame_px", frame_size)
	mat.set_shader_parameter("atlas_cols", float(cols))
	mat.set_shader_parameter("atlas_px", Vector2(atlas.get_size()))
	mat.set_shader_parameter("skins", _colors(AssetForge.SKINS))
	mat.set_shader_parameter("hairs", _colors(AssetForge.HAIRS))
	mat.set_shader_parameter("wools", _colors(AssetForge.WOOLS))
	var mats := PackedColorArray()
	mats.resize(24)
	for k in 24:
		mats[k] = Color(AssetForge.MAT_COLORS.get(k, "#ff00ff"))
	mat.set_shader_parameter("mats", mats)
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _colors(arr: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for c: String in arr:
		out.append(Color(c))
	return out


func begin(capacity_hint: int) -> void:
	_n = 0
	if _buf.size() < capacity_hint * FLOATS:
		_buf.resize(maxi(capacity_hint, 64) * FLOATS)


## Adds one sprite whose top-left is at `pos` (world pixels) with uniform `scale_f`.
func add(pos: Vector2, scale_f: float, tint: Color, frame: int, a: float, b: float, flags: int) -> void:
	var k := _n * FLOATS
	if k + FLOATS > _buf.size():
		_buf.resize(_buf.size() * 2)
	_buf[k] = scale_f
	_buf[k + 1] = 0.0
	_buf[k + 2] = 0.0
	_buf[k + 3] = pos.x
	_buf[k + 4] = 0.0
	_buf[k + 5] = scale_f
	_buf[k + 6] = 0.0
	_buf[k + 7] = pos.y
	_buf[k + 8] = tint.r
	_buf[k + 9] = tint.g
	_buf[k + 10] = tint.b
	_buf[k + 11] = tint.a
	_buf[k + 12] = float(frame)
	_buf[k + 13] = a
	_buf[k + 14] = b
	_buf[k + 15] = float(flags)
	_n += 1


func commit() -> void:
	var mm := multimesh
	if mm.instance_count < _n or mm.instance_count > _n * 4 + 256:
		mm.instance_count = maxi(64, nearest_po2(_n))
	mm.visible_instance_count = _n
	if _n > 0:
		var needed := mm.instance_count * FLOATS
		if _buf.size() < needed:
			_buf.resize(needed)
		mm.buffer = _buf.slice(0, needed) if _buf.size() > needed else _buf


func count() -> int:
	return _n
