class_name UnitView
extends Node2D
## Draws visible creatures with one MultiMesh. Positions are interpolated between
## the previous and current tick for smooth motion at any simulation speed.
## Distance-based simplification: when zoomed far out, sprites are hidden and the
## political map carries the view instead.

const HIDE_BELOW_ZOOM := 0.32
const CARRY_OFFSET := Vector2(0, -6)

var sim: Simulation
var alpha: float = 1.0          ## interpolation factor supplied by the game loop
var selected_id: int = -1
var visible_count: int = 0
var _body := SpriteBatch.new()
var _items := SpriteBatch.new()
var _anim_t := 0.0
var _soldier_job: int = -1


func _ready() -> void:
	_soldier_job = Defs.job_by_id("soldier").index
	var atlas := AssetForge.build_unit_atlas_cached()
	var fs := Vector2(AssetForge.UNIT_FRAME, AssetForge.UNIT_FRAME)
	_body.setup(atlas, fs, AssetForge.UNIT_ATLAS_COLS)
	_items.setup(atlas, fs, AssetForge.UNIT_ATLAS_COLS)
	add_child(_body)
	add_child(_items)


func update_view(view_rect_tiles: Rect2, zoom: float, delta: float) -> void:
	_anim_t += delta
	if sim == null or zoom < HIDE_BELOW_ZOOM:
		_body.begin(0)
		_body.commit()
		_items.begin(0)
		_items.commit()
		visible_count = 0
		return
	var u := sim.units
	var slots := sim.spatial.slots_in_rect(view_rect_tiles.grow(1.0))
	_body.begin(slots.size() * 2)
	_items.begin(64)
	var clothes_by_city := {}
	var nomad := Color(AssetForge.NOMAD_CLOTHES)
	var step := int(_anim_t * 6.0)
	for s in slots:
		if u.alive[s] == 0:
			continue
		var px := lerpf(u.prev_x[s], u.x[s], alpha)
		var py := lerpf(u.prev_y[s], u.y[s], alpha)
		if not view_rect_tiles.has_point(Vector2(px, py)):
			continue
		var moving := u.state[s] == UnitStore.State.MOVING
		var working := u.state[s] == UnitStore.State.WORKING
		var flip := 1 if (u.x[s] - u.prev_x[s]) < -0.001 else 0
		var flags := flip | (2 if u.id[s] == selected_id else 0)
		var look := u.look[s]
		var pos := Vector2(px, py) * AssetForge.TILE - Vector2(4, 7)
		var frame: int
		var scale_f := 1.0
		var tint := Color.WHITE
		var ga := 0.0
		var gb := 0.0
		if u.species[s] == sim.human_species:
			var female := u.sex[s] == UnitStore.SEX_FEMALE
			var base := AssetForge.UF.WOMAN_IDLE if female else AssetForge.UF.MAN_IDLE
			if u.job[s] == _soldier_job:
				base = AssetForge.UF.SOLDIER_IDLE
			frame = base
			if working:
				frame = base + (3 if (step + s) % 2 == 0 else 0)
			elif moving:
				frame = base + 1 + ((step + s) % 2)
			var c := u.city[s]
			if c != SimConst.CITY_NONE and sim.cities.has(c):
				if not clothes_by_city.has(c):
					clothes_by_city[c] = Color(AssetForge.CITY_COLORS[(sim.cities[c] as City).color_index])
				tint = clothes_by_city[c]
			else:
				tint = nomad
			ga = look & 3
			gb = (look >> 4) % 5
			var age := u.age_years(s, sim.tick)
			if age < 14.0:
				scale_f = 0.6 + 0.4 * age / 14.0
				pos += Vector2(4, 7) * (1.0 - scale_f)
			if u.carry_amount[s] > 0.0:
				var cf := AssetForge.UF.CARRY_FOOD + u.carry_type[s] - 1
				_items.add(pos + CARRY_OFFSET * scale_f, scale_f, Color.WHITE, cf, 0, 0, 0)
		else:
			frame = AssetForge.UF.SHEEP_EAT if working else (AssetForge.UF.SHEEP_A + ((step + s) % 2 if moving else 0))
			gb = (look >> 8) % 3
			var age_s := u.age_years(s, sim.tick)
			if age_s < 1.0:
				scale_f = 0.65 + 0.35 * age_s
				pos += Vector2(4, 7) * (1.0 - scale_f)
		_body.add(pos + Vector2(0, 1), scale_f, Color.WHITE, AssetForge.UF.SHADOW, 0, 0, 0)
		_body.add(pos, scale_f, tint, frame, ga, gb, flags)
	_body.commit()
	_items.commit()
	@warning_ignore("integer_division")
	visible_count = _body.count() / 2
