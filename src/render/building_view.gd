class_name BuildingView
extends Node2D
## Draws buildings (roofs tinted by city color) with one MultiMesh, y-sorted.

var sim: Simulation
var _batch := SpriteBatch.new()
var visible_count: int = 0


func _ready() -> void:
	_batch.setup(AssetForge.build_building_atlas_cached(), Vector2(AssetForge.BLD_W, AssetForge.BLD_H), AssetForge.BLD_ATLAS_COLS)
	add_child(_batch)


func update_view(view_rect_tiles: Rect2) -> void:
	if sim == null:
		return
	var list: Array[Building] = []
	var r := view_rect_tiles.grow(3.0)
	for b: Building in sim.buildings.values():
		if r.has_point(Vector2(b.x, b.y)):
			list.append(b)
	list.sort_custom(func(a: Building, c: Building) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	_batch.begin(list.size())
	for b in list:
		var def := b.def()
		var frame := _frame_for(b)
		var city: City = sim.cities.get(b.city, null)
		var tint := Color(AssetForge.CITY_COLORS[city.color_index]) if city != null else Color.GRAY
		# Footprint is size x size tiles; sprite is 16x24 with its base on the footprint bottom.
		var pos := Vector2(b.x, b.y) * AssetForge.TILE + Vector2(0, def.size * AssetForge.TILE - AssetForge.BLD_H)
		_batch.add(pos, 1.0, tint, frame, 0, 0, 0)
	_batch.commit()
	visible_count = list.size()


static func _frame_for(b: Building) -> int:
	if not b.complete:
		return AssetForge.BF.FRAME if b.paid and b.progress > b.def().work * 0.3 else AssetForge.BF.SITE
	match b.def().id:
		"town_hall":
			return AssetForge.BF.TOWN_HALL
		"granary":
			return AssetForge.BF.GRANARY
		_:
			return [AssetForge.BF.HOUSE, AssetForge.BF.HOUSE_B, AssetForge.BF.HOUSE_C, AssetForge.BF.HOUSE_D][(b.id * 7 + b.x) % 4]
