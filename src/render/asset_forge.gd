class_name AssetForge
extends RefCounted
## Procedural placeholder pixel art. Everything is generated deterministically at
## startup (and can be exported with tools/export_assets.gd) so no external or
## proprietary art is used.
##
## Sprites for units/buildings are "material maps": the R channel stores a material
## id and G a shade factor (128 = 1.0). The sprite shader resolves materials to
## real colors, which lets one atlas serve every skin/hair/city color combination.

const TILE := 8
const TILE_COLS := 8
const UNIT_FRAME := 8
const BLD_W := 16
const BLD_H := 24
const ICON := 16

enum Mat { NONE, OUTLINE, SKIN, CLOTHES, HAIR, WOOL, WHITE, FACE, LEG, WALL = 10, WALL_SHADE, ROOF, ROOF_SHADE, WOOD, WINDOW, STONE, STONE_SHADE, BANNER, DIRT, WOOD_LIGHT }

## Fixed material colors; instance-driven ones (skin, clothes, hair, wool, roof, banner) are placeholders.
const MAT_COLORS := {
	Mat.OUTLINE: "#1c1418", Mat.WHITE: "#f4f0e8", Mat.FACE: "#3a302a", Mat.LEG: "#2e2428",
	Mat.WALL: "#c9a26b", Mat.WALL_SHADE: "#9c7a4e", Mat.WOOD: "#5a3a22", Mat.WINDOW: "#f2d27a",
	Mat.STONE: "#9a948c", Mat.STONE_SHADE: "#66605c", Mat.DIRT: "#6b4a30", Mat.WOOD_LIGHT: "#8f6440",
}

## Unit atlas frame indices.
enum UF { MAN_IDLE, MAN_WALK_A, MAN_WALK_B, MAN_WORK, WOMAN_IDLE, WOMAN_WALK_A, WOMAN_WALK_B, WOMAN_WORK, SHEEP_A, SHEEP_B, SHEEP_EAT, CARRY_FOOD, CARRY_WOOD, CARRY_STONE, SHADOW }
const UNIT_ATLAS_COLS := 8
## Building atlas frame indices.
enum BF { TOWN_HALL, HOUSE, GRANARY, SITE, FRAME, HOUSE_B, HOUSE_C, HOUSE_D }
const BLD_ATLAS_COLS := 8

## City banner colors (index = City.color_index). Hand-picked, distinct hues.
const CITY_COLORS := ["#c8463c", "#3c6ec8", "#e0b43c", "#3ca05a", "#9a4cc0", "#e07a2c", "#2cb4b4", "#d85a9a",
	"#8a6a3a", "#5a7a2c", "#4c4cb0", "#b03c5a", "#2c8a8a", "#c0a078", "#7a3ca0", "#60a0e0"]
const SKINS := ["#f0c8a0", "#d8a478", "#b07850", "#7c5034"]
const HAIRS := ["#2a1a10", "#5c3a1c", "#a87838", "#d8c890", "#8a2c1c"]
const WOOLS := ["#ece8dc", "#d4ccb8", "#b8ae9c"]
const NOMAD_CLOTHES := "#8c7a64"


static func mat_color(id: int, shade: int = 128) -> Color:
	return Color8(id, shade, 0, 255)


# ---------------------------------------------------------------- terrain

static func build_tile_atlas() -> Image:
	Defs.ensure_loaded()
	var rows := Defs.biomes.size()
	var img := Image.create(TILE_COLS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for b: Defs.BiomeDef in Defs.biomes:
		for v in TILE_COLS:
			var rng := RandomNumberGenerator.new()
			rng.seed = b.index * 131 + v * 17 + 7
			_draw_tile(img, b, v, v * TILE, b.index * TILE, rng)
	return img


static func _draw_tile(img: Image, b: Defs.BiomeDef, v: int, ox: int, oy: int, rng: RandomNumberGenerator) -> void:
	var c := b.colors
	var dark := c[0]
	var base := c[1]
	var light := c[2]
	var acc := c[3]
	_fill(img, ox, oy, TILE, TILE, base)
	match b.pattern:
		"deep_water", "water", "shallow":
			for k in 3:
				var x := rng.randi_range(0, 5)
				var y := rng.randi_range(0, 7)
				_hline(img, ox + x, oy + y, 2, light if b.pattern != "shallow" else acc)
			if rng.randf() < 0.6:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), dark)
		"sand":
			for k in 7:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light if k % 2 == 0 else acc)
		"soil":
			for k in 3:
				_hline(img, ox + rng.randi_range(0, 5), oy + rng.randi_range(0, 7), 2, dark)
			for k in 3:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light)
		"grass":
			for k in 8:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), dark)
			for k in 3:
				var x := rng.randi_range(0, 7)
				var y := rng.randi_range(1, 7)
				_px(img, ox + x, oy + y, light)
				_px(img, ox + x, oy + y - 1, acc)
		"forest":
			var ground: Color = (Defs.biomes[Defs.grassland_index] as Defs.BiomeDef).colors[0]
			_fill(img, ox, oy, TILE, TILE, ground)
			for k in 5:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), dark)
			if v == 4:
				_stump(img, ox + 2, oy + 4, acc, dark)
				_px(img, ox + 6, oy + 2, light)
			elif v == 5:
				_tree(img, ox + 1, oy + 1, 2, dark, base, light, acc)
			elif v == 3:
				_tree(img, ox - 1, oy - 1, 2, dark, base, light, acc)
				_tree(img, ox + 3, oy + 2, 2, dark, base, light, acc)
			else:
				_tree(img, ox + (v % 2), oy + (v / 2), 3, dark, base, light, acc)
		"hills":
			for k in 4:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), dark)
			var hx := rng.randi_range(-1, 3)
			var hy := rng.randi_range(-1, 2)
			var w5 := rng.randi_range(4, 6)
			if v != 2:
				_hline(img, ox + hx + 1, oy + hy + 1, w5 - 2, light)
				_hline(img, ox + hx, oy + hy + 2, w5, light)
				_hline(img, ox + hx, oy + hy + 3, w5, base)
				_hline(img, ox + hx, oy + hy + 4, w5, acc)
				_hline(img, ox + hx + 1, oy + hy + 5, w5 - 2, acc)
			for k in 3:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light)
		"mountain":
			var bx := rng.randi_range(-1, 1)
			for y in 8:
				var half := y / 2 + 1
				for x in range(4 - half, 4 + half):
					var col := light if x < 4 else dark
					if y <= 1 and v % 2 == 0:
						col = acc if x < 4 else light
					_px(img, ox + x + bx, oy + y, col)
			_px(img, ox + 3 + bx, oy, acc)
		"snow":
			for k in 5:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light)
			for k in 3:
				_hline(img, ox + rng.randi_range(0, 5), oy + rng.randi_range(0, 7), 2, dark)
		"dunes":
			var off := rng.randi_range(0, 3)
			for x in 8:
				var y1 := (x + off) % 8 / 3 + 1
				_px(img, ox + x, oy + y1, light)
				_px(img, ox + x, oy + y1 + 4, dark)
		"swamp":
			var pool := Color("#22403a")
			for k in 2:
				var x := rng.randi_range(0, 5)
				var y := rng.randi_range(0, 6)
				_hline(img, ox + x, oy + y, 3, pool)
				_hline(img, ox + x + 1, oy + y + 1, 2, pool)
			for k in 3:
				var x := rng.randi_range(0, 7)
				var y := rng.randi_range(1, 7)
				_px(img, ox + x, oy + y, acc)
				_px(img, ox + x, oy + y - 1, light)
		"volcanic":
			for k in 6:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light)
			var x := rng.randi_range(0, 4)
			var y := rng.randi_range(0, 5)
			for k in 4:
				_px(img, ox + x + k, oy + y + (k % 2), acc)
		"mystic":
			for k in 6:
				_px(img, ox + rng.randi_range(0, 7), oy + rng.randi_range(0, 7), light)
			var x := rng.randi_range(1, 6)
			var y := rng.randi_range(2, 6)
			_px(img, ox + x, oy + y, acc)
			_px(img, ox + x, oy + y - 1, acc)
			_px(img, ox + x, oy + y - 2, Color.WHITE)
			_px(img, ox + x + 1, oy + y, dark)
		"farmland":
			for y in [1, 3, 5, 7]:
				_hline(img, ox, oy + y, 8, dark)
			var stage := maxi(0, v - 4)
			if v >= 4 and stage > 0:
				for y in [0, 2, 4, 6]:
					for x in range(1, 8, 2):
						match stage:
							1:
								_px(img, ox + x, oy + y + 1, Color("#6a9a3a"))
							2:
								_px(img, ox + x, oy + y, Color("#6aa83c"))
								_px(img, ox + x, oy + y + 1, Color("#3e7428"))
							3:
								_px(img, ox + x, oy + y, acc)
								_px(img, ox + x, oy + y + 1, Color("#a88a2c"))


static func _tree(img: Image, x: int, y: int, r: int, dark: Color, base: Color, light: Color, trunk: Color) -> void:
	var cx := x + r
	var cy := y + r
	_px(img, cx, cy + r + 1, trunk)
	_px(img, cx, cy + r, trunk)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := dx * dx + dy * dy
			if d > r * r + 1:
				continue
			var col := base
			if d >= r * r - 1 or dx + dy > r - 1:
				col = dark
			elif dx < 0 and dy < 0:
				col = light
			_px(img, cx + dx, cy + dy, col)


static func _stump(img: Image, x: int, y: int, wood: Color, dark: Color) -> void:
	_hline(img, x, y, 2, wood)
	_hline(img, x, y + 1, 2, dark)


# ---------------------------------------------------------------- units

static func build_unit_atlas() -> Image:
	var rows := 2
	var img := Image.create(UNIT_ATLAS_COLS * UNIT_FRAME, rows * UNIT_FRAME, false, Image.FORMAT_RGBA8)
	for f in UF.size():
		var ox := (f % UNIT_ATLAS_COLS) * UNIT_FRAME
		@warning_ignore("integer_division")
		var oy := (f / UNIT_ATLAS_COLS) * UNIT_FRAME
		_draw_unit_frame(img, f, ox, oy)
	return img


static func _m(img: Image, x: int, y: int, id: int, shade: int = 128) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, mat_color(id, shade))


static func _draw_unit_frame(img: Image, f: int, ox: int, oy: int) -> void:
	match f:
		UF.MAN_IDLE, UF.MAN_WALK_A, UF.MAN_WALK_B, UF.MAN_WORK, UF.WOMAN_IDLE, UF.WOMAN_WALK_A, UF.WOMAN_WALK_B, UF.WOMAN_WORK:
			var female := f >= UF.WOMAN_IDLE
			var pose := f - (UF.WOMAN_IDLE if female else UF.MAN_IDLE)
			var x0 := ox + 2
			# hair / head
			for x in range(1, 4):
				_m(img, x0 + x, oy + 0, Mat.HAIR)
			_m(img, x0 + 0, oy + 1, Mat.HAIR if female else Mat.OUTLINE)
			_m(img, x0 + 4, oy + 1, Mat.HAIR if female else Mat.OUTLINE)
			for x in range(1, 4):
				_m(img, x0 + x, oy + 1, Mat.SKIN)
			_m(img, x0 + 1, oy + 2, Mat.SKIN)
			_m(img, x0 + 2, oy + 2, Mat.SKIN, 110)
			_m(img, x0 + 3, oy + 2, Mat.SKIN)
			if female:
				_m(img, x0 + 0, oy + 2, Mat.HAIR, 100)
				_m(img, x0 + 4, oy + 2, Mat.HAIR, 100)
			# torso
			for x in range(0, 5):
				_m(img, x0 + x, oy + 3, Mat.CLOTHES, 150 if x == 1 else 128)
			for x in range(1, 4):
				_m(img, x0 + x, oy + 4, Mat.CLOTHES, 110 if x == 3 else 128)
				_m(img, x0 + x, oy + 5, Mat.CLOTHES, 90)
			if female:
				_m(img, x0 + 0, oy + 5, Mat.CLOTHES, 90)
				_m(img, x0 + 4, oy + 5, Mat.CLOTHES, 90)
			# arms
			if pose == 3:
				_m(img, x0 + 4, oy + 2, Mat.SKIN)
				_m(img, x0 + 5, oy + 1, Mat.WOOD_LIGHT)
				_m(img, x0 + 0, oy + 4, Mat.SKIN)
			else:
				_m(img, x0 + 0, oy + 4, Mat.SKIN)
				_m(img, x0 + 4, oy + 4, Mat.SKIN)
			# legs
			match pose:
				1:
					_m(img, x0 + 1, oy + 6, Mat.LEG)
					_m(img, x0 + 0, oy + 7, Mat.OUTLINE)
					_m(img, x0 + 3, oy + 6, Mat.LEG)
					_m(img, x0 + 3, oy + 7, Mat.OUTLINE)
				2:
					_m(img, x0 + 1, oy + 6, Mat.LEG)
					_m(img, x0 + 1, oy + 7, Mat.OUTLINE)
					_m(img, x0 + 3, oy + 6, Mat.LEG)
					_m(img, x0 + 4, oy + 7, Mat.OUTLINE)
				_:
					_m(img, x0 + 1, oy + 6, Mat.LEG)
					_m(img, x0 + 3, oy + 6, Mat.LEG)
					_m(img, x0 + 1, oy + 7, Mat.OUTLINE)
					_m(img, x0 + 3, oy + 7, Mat.OUTLINE)
		UF.SHEEP_A, UF.SHEEP_B, UF.SHEEP_EAT:
			var eat := f == UF.SHEEP_EAT
			for x in range(1, 6):
				_m(img, ox + x, oy + 3, Mat.WOOL, 150)
			for x in range(0, 6):
				_m(img, ox + x, oy + 4, Mat.WOOL)
			for x in range(0, 6):
				_m(img, ox + x, oy + 5, Mat.WOOL, 100 if x > 3 else 118)
			var hy := 5 if eat else 3
			_m(img, ox + 6, oy + hy, Mat.FACE)
			_m(img, ox + 7, oy + hy, Mat.FACE)
			_m(img, ox + 6, oy + hy + 1, Mat.FACE)
			_m(img, ox + 6, oy + hy - 1, Mat.WOOL, 150)
			var spread := f == UF.SHEEP_B
			_m(img, ox + (0 if spread else 1), oy + 6, Mat.LEG)
			_m(img, ox + 2, oy + 6, Mat.LEG)
			_m(img, ox + 4, oy + 6, Mat.LEG)
			_m(img, ox + (6 if spread else 5), oy + 6, Mat.LEG)
		UF.CARRY_FOOD:
			for x in range(2, 6):
				_m(img, ox + x, oy + 5, Mat.WALL)
				_m(img, ox + x, oy + 6, Mat.WALL_SHADE)
			_m(img, ox + 3, oy + 4, Mat.WINDOW)
			_m(img, ox + 4, oy + 4, Mat.WINDOW, 90)
		UF.CARRY_WOOD:
			for x in range(1, 7):
				_m(img, ox + x, oy + 5, Mat.WOOD_LIGHT)
				_m(img, ox + x, oy + 6, Mat.WOOD)
			_m(img, ox + 1, oy + 5, Mat.WALL)
		UF.CARRY_STONE:
			for x in range(2, 6):
				_m(img, ox + x, oy + 5, Mat.STONE, 150 if x == 2 else 128)
				_m(img, ox + x, oy + 6, Mat.STONE_SHADE)
		UF.SHADOW:
			for x in range(1, 7):
				_m(img, ox + x, oy + 7, Mat.OUTLINE, 60)
			for x in range(2, 6):
				_m(img, ox + x, oy + 6, Mat.OUTLINE, 60)


# ---------------------------------------------------------------- buildings

static func build_building_atlas() -> Image:
	var img := Image.create(BLD_ATLAS_COLS * BLD_W, BLD_H, false, Image.FORMAT_RGBA8)
	_house(img, BF.HOUSE * BLD_W, false)
	_house(img, BF.HOUSE_B * BLD_W, true)
	_town_hall(img, BF.TOWN_HALL * BLD_W)
	_granary(img, BF.GRANARY * BLD_W)
	_site(img, BF.SITE * BLD_W, false)
	_site(img, BF.FRAME * BLD_W, true)
	_cottage(img, BF.HOUSE_C * BLD_W)
	_longhouse(img, BF.HOUSE_D * BLD_W)
	return img


## Stone cottage with a hipped roof, dormer and flower box.
static func _cottage(img: Image, ox: int) -> void:
	_rect_m(img, ox + 3, 14, 10, 9, Mat.STONE)
	_rect_m(img, ox + 10, 14, 3, 9, Mat.STONE_SHADE)
	for x in range(3, 13, 3):
		_m(img, ox + x, 17, Mat.STONE_SHADE)
		_m(img, ox + x + 1, 20, Mat.STONE_SHADE)
	for y in range(14, 23):
		_m(img, ox + 2, y, Mat.OUTLINE)
		_m(img, ox + 13, y, Mat.OUTLINE)
	for x in range(2, 14):
		_m(img, ox + x, 23, Mat.OUTLINE)
	_rect_m(img, ox + 5, 18, 2, 5, Mat.WOOD)
	_rect_m(img, ox + 9, 16, 2, 2, Mat.WINDOW)
	_m(img, ox + 9, 18, Mat.BANNER, 120)
	_m(img, ox + 10, 18, Mat.BANNER, 90)
	_roof(img, ox, 7, 13, 1, 14, 6)
	_rect_m(img, ox + 6, 8, 3, 3, Mat.WALL)
	_m(img, ox + 7, 9, Mat.WINDOW)
	_m(img, ox + 5, 8, Mat.OUTLINE)
	_m(img, ox + 9, 8, Mat.OUTLINE)


## Low timber longhouse with a thatched roof and log pile.
static func _longhouse(img: Image, ox: int) -> void:
	_rect_m(img, ox + 1, 16, 14, 7, Mat.WOOD_LIGHT)
	for x in range(1, 15, 2):
		for y in range(16, 23):
			_m(img, ox + x, y, Mat.WOOD_LIGHT, 105)
	for y in range(16, 23):
		_m(img, ox + 0, y, Mat.OUTLINE)
		_m(img, ox + 15, y, Mat.OUTLINE)
	for x in range(0, 16):
		_m(img, ox + x, 23, Mat.OUTLINE)
	_rect_m(img, ox + 9, 18, 2, 5, Mat.WOOD)
	_rect_m(img, ox + 3, 18, 2, 2, Mat.WINDOW, 110)
	_roof(img, ox, 9, 15, 0, 15, 12)
	for x in range(1, 15, 3):
		_m(img, ox + x, 11, Mat.ROOF, 90)
		_m(img, ox + x + 1, 13, Mat.ROOF, 90)
	_m(img, ox + 13, 21, Mat.WOOD)
	_m(img, ox + 14, 21, Mat.WOOD_LIGHT)
	_m(img, ox + 13, 22, Mat.WOOD_LIGHT)
	_m(img, ox + 14, 22, Mat.WOOD)


static func _rect_m(img: Image, x: int, y: int, w: int, h: int, id: int, shade: int = 128) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_m(img, xx, yy, id, shade)


static func _roof(img: Image, ox: int, top: int, bottom: int, left: int, right: int, apex_w: int) -> void:
	var rows := bottom - top + 1
	for r in rows:
		var t := float(r) / maxf(1.0, rows - 1)
		var half_w := lerpf(apex_w / 2.0, (right - left + 1) / 2.0, t)
		var cx := (left + right + 1) / 2.0
		var x0 := int(round(cx - half_w))
		var x1 := int(round(cx + half_w)) - 1
		for x in range(x0, x1 + 1):
			var shade := 150 if x < cx - 1 else (100 if x > cx + 1 else 128)
			if r == rows - 1:
				shade = 80
			_m(img, ox + x, top + r, Mat.ROOF, shade)
		_m(img, ox + x0 - 1, top + r, Mat.OUTLINE)
		_m(img, ox + x1 + 1, top + r, Mat.OUTLINE)
	for x in range(left - 1, right + 2):
		_m(img, ox + x, bottom + 1, Mat.OUTLINE, 110)


static func _house(img: Image, ox: int, alt: bool) -> void:
	_rect_m(img, ox + 2, 13, 12, 10, Mat.WALL)
	_rect_m(img, ox + 11, 13, 3, 10, Mat.WALL_SHADE)
	for y in range(13, 23):
		_m(img, ox + 1, y, Mat.OUTLINE)
		_m(img, ox + 14, y, Mat.OUTLINE)
	for x in range(1, 15):
		_m(img, ox + x, 23, Mat.OUTLINE)
	_rect_m(img, ox + 7, 18, 2, 5, Mat.WOOD)
	_m(img, ox + 8, 20, Mat.WINDOW, 90)
	_rect_m(img, ox + 3, 15, 2, 2, Mat.WINDOW)
	_rect_m(img, ox + 11, 15, 2, 2, Mat.WINDOW, 100)
	if alt:
		_roof(img, ox, 5, 12, 1, 14, 10)
	else:
		_roof(img, ox, 4, 12, 0, 15, 2)
		_rect_m(img, ox + 11, 4, 2, 4, Mat.STONE)
		_m(img, ox + 12, 4, Mat.STONE_SHADE)


static func _town_hall(img: Image, ox: int) -> void:
	_rect_m(img, ox + 1, 12, 14, 11, Mat.STONE)
	_rect_m(img, ox + 11, 12, 4, 11, Mat.STONE_SHADE)
	for y in range(12, 23):
		_m(img, ox + 0, y, Mat.OUTLINE)
		_m(img, ox + 15, y, Mat.OUTLINE)
	for x in range(0, 16):
		_m(img, ox + x, 23, Mat.OUTLINE)
	for x in range(1, 15, 3):
		_m(img, ox + x, 16, Mat.STONE_SHADE)
		_m(img, ox + x + 1, 19, Mat.STONE_SHADE)
	_rect_m(img, ox + 6, 17, 4, 6, Mat.WOOD)
	_m(img, ox + 7, 17, Mat.OUTLINE)
	_m(img, ox + 8, 17, Mat.OUTLINE)
	_rect_m(img, ox + 2, 14, 2, 2, Mat.WINDOW)
	_rect_m(img, ox + 12, 14, 2, 2, Mat.WINDOW, 100)
	_roof(img, ox, 6, 11, 0, 15, 6)
	# banner pole
	for y in range(0, 7):
		_m(img, ox + 8, y, Mat.WOOD)
	_rect_m(img, ox + 9, 0, 4, 3, Mat.BANNER)
	_m(img, ox + 12, 2, Mat.BANNER, 90)


static func _granary(img: Image, ox: int) -> void:
	for y in range(11, 23):
		for x in range(3, 13):
			var edge := x == 3 or x == 12
			var sh := 150 if x < 6 else (95 if x > 9 else 128)
			_m(img, ox + x, y, Mat.OUTLINE if edge else Mat.STONE, sh)
	for x in range(3, 13):
		_m(img, ox + x, 23, Mat.OUTLINE)
	for x in range(4, 12, 2):
		_m(img, ox + x, 15, Mat.STONE_SHADE)
		_m(img, ox + x + 1, 19, Mat.STONE_SHADE)
	_rect_m(img, ox + 7, 18, 2, 5, Mat.WOOD)
	_roof(img, ox, 4, 10, 2, 13, 1)


static func _site(img: Image, ox: int, framed: bool) -> void:
	_rect_m(img, ox + 1, 19, 14, 4, Mat.DIRT)
	for x in range(1, 15, 2):
		_m(img, ox + x, 22, Mat.DIRT, 90)
	for x in [1, 14]:
		_m(img, ox + x, 18, Mat.STONE)
	if framed:
		for x in [2, 7, 13]:
			for y in range(9, 19):
				_m(img, ox + x, y, Mat.WOOD_LIGHT)
		for x in range(2, 14):
			_m(img, ox + x, 9, Mat.WOOD)
			_m(img, ox + x, 14, Mat.WOOD_LIGHT, 100)
		_rect_m(img, ox + 3, 15, 4, 4, Mat.WALL, 110)
	else:
		for x in range(3, 13, 3):
			_m(img, ox + x, 18, Mat.WOOD_LIGHT)
			_m(img, ox + x + 1, 18, Mat.WOOD)


# ---------------------------------------------------------------- icons

## Icon ids, laid out left-to-right in the icon atlas.
const ICON_IDS := ["inspect", "raise", "lower", "paint_grass", "paint_soil", "paint_sand", "paint_shallow",
	"paint_ocean", "paint_deep", "paint_mountain", "paint_hills", "paint_forest", "paint_desert", "paint_snow",
	"paint_swamp", "paint_ash", "paint_mystic", "spawn_human", "spawn_sheep", "smite", "bless", "undo",
	"pause", "play", "fast", "faster", "fastest", "save", "load", "history", "admin", "close", "plus", "minus",
	"people", "city", "food", "wood", "stone", "house", "star", "skull", "heart", "perf", "world", "follow"]


static func icon_index(id: String) -> int:
	return ICON_IDS.find(id)


static func build_icon_atlas() -> Image:
	Defs.ensure_loaded()
	var img := Image.create(ICON_IDS.size() * ICON, ICON, false, Image.FORMAT_RGBA8)
	for k in ICON_IDS.size():
		_draw_icon(img, ICON_IDS[k], k * ICON)
	return img


static func _draw_icon(img: Image, id: String, ox: int) -> void:
	var ink := Color("#241a16")
	var paper := Color("#f0e2c0")
	var gold := Color("#e8b84a")
	if id.begins_with("paint_"):
		_paint_icon(img, id, ox)
		return
	match id:
		"inspect":
			_circle(img, ox + 6, 6, 4, ink, false)
			_circle(img, ox + 6, 6, 3, Color("#9cd4f0"), true)
			_px(img, ox + 5, 5, Color.WHITE)
			for k in 4:
				_px(img, ox + 9 + k, 9 + k, ink)
				_px(img, ox + 10 + k, 9 + k, Color("#6a4a2a"))
		"raise", "lower":
			_mound(img, ox, id == "raise")
		"spawn_human":
			var u := build_unit_atlas_cached()
			_blit_scaled_unit(img, u, UF.MAN_IDLE, ox, Color("#3c6ec8"))
		"spawn_sheep":
			var u2 := build_unit_atlas_cached()
			_blit_scaled_unit(img, u2, UF.SHEEP_A, ox, Color.WHITE)
		"smite":
			var pts := [Vector2i(9, 1), Vector2i(8, 2), Vector2i(7, 3), Vector2i(6, 4), Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(7, 7), Vector2i(6, 8), Vector2i(5, 9), Vector2i(4, 10), Vector2i(3, 11), Vector2i(2, 12)]
			for p: Vector2i in pts:
				_px(img, ox + p.x, p.y, Color("#fff2a0"))
				_px(img, ox + p.x + 1, p.y, gold)
				_px(img, ox + p.x + 2, p.y, ink)
		"bless", "heart":
			var heart := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
			_pattern(img, ox + 4, 4, heart, Color("#e05a6a") if id == "heart" else Color("#f0d060"))
			_px(img, ox + 5, 5, Color.WHITE)
			if id == "bless":
				_px(img, ox + 2, 2, Color.WHITE)
				_px(img, ox + 13, 3, Color.WHITE)
				_px(img, ox + 12, 12, Color.WHITE)
		"undo":
			_circle(img, ox + 8, 8, 5, paper, false)
			for y in range(8, 14):
				for x in range(2, 8):
					img.set_pixel(ox + x, y, Color(0, 0, 0, 0))
			_pattern(img, ox + 1, 5, ["#####", ".###.", "..#.."], paper)
		"pause":
			_rect(img, ox + 4, 3, 3, 10, paper)
			_rect(img, ox + 9, 3, 3, 10, paper)
		"play", "fast", "faster", "fastest":
			var n: int = {"play": 1, "fast": 2, "faster": 3, "fastest": 4}[id]
			@warning_ignore("integer_division")
			var w: int = 12 / n
			for k in n:
				_triangle(img, ox + 2 + k * w, 3, w, 10, paper if k < 3 else gold)
		"save":
			_rect(img, ox + 2, 2, 12, 12, Color("#5a7ab0"))
			_rect(img, ox + 4, 2, 8, 5, paper)
			_rect(img, ox + 4, 9, 8, 5, Color("#2c3c5a"))
			_frame(img, ox + 2, 2, 12, 12, ink)
		"load":
			_rect(img, ox + 1, 5, 14, 9, Color("#c8963c"))
			_rect(img, ox + 1, 3, 6, 3, Color("#c8963c"))
			_hline(img, ox + 2, 7, 12, Color("#e8b85c"))
			_frame(img, ox + 1, 5, 14, 9, ink)
		"history":
			_rect(img, ox + 3, 2, 10, 12, Color("#8a3c2c"))
			_rect(img, ox + 5, 3, 7, 10, paper)
			for y in [5, 7, 9, 11]:
				_hline(img, ox + 6, y, 5, Color("#8a7a6a"))
			_frame(img, ox + 3, 2, 10, 12, ink)
		"admin":
			_circle(img, ox + 8, 8, 5, Color("#9aa4ac"), true)
			_circle(img, ox + 8, 8, 2, Color("#3a3e44"), true)
			for d: Vector2i in [Vector2i(0, -6), Vector2i(0, 6), Vector2i(-6, 0), Vector2i(6, 0)]:
				_rect(img, ox + 7 + d.x, 7 + d.y, 2, 2, Color("#9aa4ac"))
		"close":
			for k in 10:
				_px(img, ox + 3 + k, 3 + k, paper)
				_px(img, ox + 12 - k, 3 + k, paper)
				_px(img, ox + 4 + k, 3 + k, paper)
				_px(img, ox + 13 - k, 3 + k, paper)
		"plus":
			_rect(img, ox + 7, 3, 2, 10, paper)
			_rect(img, ox + 3, 7, 10, 2, paper)
		"minus":
			_rect(img, ox + 3, 7, 10, 2, paper)
		"people":
			var u3 := build_unit_atlas_cached()
			_blit_unit(img, u3, UF.MAN_IDLE, ox + 0, 4, Color("#c8463c"))
			_blit_unit(img, u3, UF.WOMAN_IDLE, ox + 7, 5, Color("#3ca05a"))
		"city", "house":
			var bld := build_building_atlas_cached()
			var frame := BF.TOWN_HALL if id == "city" else BF.HOUSE
			for y in 16:
				for x in 16:
					var c := bld.get_pixel(frame * BLD_W + x, 8 + y)
					if c.a > 0.0:
						img.set_pixel(ox + x, y, _resolve_mat(c, Color("#c8463c")))
		"food":
			_pattern(img, ox + 3, 2, ["...#.....", "..#.#....", "..###.#..", ".#####...", "#######..", "#######..", ".#####...", "..###...."], gold)
			_px(img, ox + 6, 2, Color("#6aa83c"))
		"wood":
			for k in 3:
				_rect(img, ox + 1 + k * 1, 4 + k * 3, 12, 3, Color("#8f6440"))
				_px(img, ox + 1 + k, 5 + k * 3, Color("#d8b070"))
				_hline(img, ox + 1 + k, 6 + k * 3, 12, Color("#5a3a22"))
		"stone":
			_circle(img, ox + 7, 9, 5, Color("#9a948c"), true)
			_circle(img, ox + 6, 8, 2, Color("#c8c0b4"), true)
			_hline(img, ox + 3, 13, 9, Color("#66605c"))
		"star":
			_pattern(img, ox + 2, 2, ["....#....", "...###...", "#########", ".#######.", "..#####..", ".###.###.", ".##...##."], gold)
		"skull":
			_pattern(img, ox + 3, 2, [".#####.", "#######", "#.###.#", "#######", ".##.##.", ".#####.", ".#.#.#."], paper)
		"perf":
			for k in 4:
				var h: int = [4, 8, 6, 11][k]
				_rect(img, ox + 2 + k * 3, 14 - h, 2, h, Color("#6ac87a"))
		"world":
			_circle(img, ox + 8, 8, 6, Color("#3a7ac0"), true)
			_pattern(img, ox + 4, 4, [".##..", "####.", ".###.", "..#.#", "...##"], Color("#6aa83c"))
		"follow":
			_circle(img, ox + 8, 8, 5, paper, false)
			_circle(img, ox + 8, 8, 1, gold, true)
			_hline(img, ox + 0, 8, 3, paper)
			_hline(img, ox + 13, 8, 3, paper)


## Biome brush icon: a framed ground swatch plus a distinct pictogram so similar
## colours (forest/hills/swamp, shallow/ocean/deep) remain distinguishable.
static func _paint_icon(img: Image, id: String, ox: int) -> void:
	var ink := Color("#241a16")
	var b := Defs.biome(TerrainEditor.PAINT[id])
	var c := b.colors
	for y in 12:
		for x in 12:
			var dither := (x + y) % 4 == 0
			img.set_pixel(ox + 2 + x, 2 + y, c[0] if dither else c[1])
	_frame(img, ox + 1, 1, 14, 14, ink)
	var o := ox + 2
	match TerrainEditor.PAINT[id]:
		"grassland":
			for p: Vector2i in [Vector2i(2, 8), Vector2i(5, 5), Vector2i(8, 9), Vector2i(9, 4)]:
				_px(img, o + p.x, 2 + p.y, c[3])
				_px(img, o + p.x - 1, 2 + p.y + 1, c[2])
				_px(img, o + p.x + 1, 2 + p.y + 1, c[2])
				_px(img, o + p.x, 2 + p.y + 1, c[2])
		"soil":
			for y in [3, 6, 9]:
				_hline(img, o + 1, 2 + y, 10, c[0])
				_hline(img, o + 2, 2 + y + 1, 8, c[2])
		"beach":
			for p: Vector2i in [Vector2i(2, 3), Vector2i(7, 2), Vector2i(4, 7), Vector2i(9, 8), Vector2i(2, 10), Vector2i(6, 10)]:
				_px(img, o + p.x, 2 + p.y, c[2])
			_pattern(img, o + 6, 2 + 4, [".##.", "####"], Color("#e8d8b8"))
		"forest":
			_tree(img, o + 1, 2 + 1, 4, Color("#16381a"), c[1], c[2], c[3])
		"hills":
			_pattern(img, o + 1, 2 + 4, ["..####....", ".######...", "########..", "#########."], c[2])
			_pattern(img, o + 1, 2 + 7, [".......##.", "......####"], c[3])
		"mountain":
			_pattern(img, o + 1, 2 + 1, [".....#....", "....###...", "...##.##..", "..###.###.", ".####.####", "#####.####"], c[2])
			_pattern(img, o + 1, 2 + 1, [".....#....", "....###..."], Color("#f4f8ff"))
			for y in range(3, 7):
				_px(img, o + 6, 2 + y, c[0])
		"snow":
			_pattern(img, o + 2, 2 + 2, ["...#...", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "...#..."], Color("#ffffff"))
		"desert":
			for x in 10:
				_px(img, o + 1 + x, 2 + 5 + int(round(sin(x * 0.7) * 1.5)), c[2])
				_px(img, o + 1 + x, 2 + 9 + int(round(sin(x * 0.7 + 1.5) * 1.5)), c[3])
			_circle(img, o + 9, 2 + 2, 1, Color("#fff0a0"), true)
		"swamp":
			_rect(img, o + 1, 2 + 7, 10, 3, Color("#22403a"))
			for x in [2, 5, 8]:
				for y in range(2, 8):
					_px(img, o + x, 2 + y, c[3])
				_px(img, o + x, 2 + 2, Color("#8a5a2a"))
		"volcanic":
			_pattern(img, o + 1, 2 + 1, ["....##....", "...####...", "..#.##.#..", "...####...", "..######..", ".########."], Color("#2a2224"))
			_pattern(img, o + 1, 2 + 1, ["....##....", ".....#....", "..........", "....#....."], c[3])
			_px(img, o + 3, 2 + 10, c[3])
			_px(img, o + 8, 2 + 9, c[3])
		"mystic":
			_pattern(img, o + 3, 2 + 1, ["..#...", ".###..", ".###.#", "#####.", ".###..", "..#..."], c[3])
			_px(img, o + 4, 2 + 2, Color.WHITE)
			_px(img, o + 9, 2 + 8, Color.WHITE)
			_px(img, o + 1, 2 + 9, Color.WHITE)
		"shallow", "ocean", "deep_ocean":
			var waves: int = {"shallow": 1, "ocean": 2, "deep_ocean": 3}[TerrainEditor.PAINT[id]]
			for k in waves:
				var y: int = 3 + k * 3
				for x in 10:
					if (x + k) % 4 != 3:
						_px(img, o + 1 + x, 2 + y + (1 if (x + k) % 4 == 2 else 0), c[3] if waves == 1 else c[2])
			if waves == 1:
				_pattern(img, o + 1, 2 + 9, ["###.......", "#####....."], Color("#d8bc78"))


static var _tile_cache: Image
static var _unit_cache: Image
static var _bld_cache: Image


static func build_tile_atlas_cached() -> Image:
	if _tile_cache == null:
		_tile_cache = build_tile_atlas()
	return _tile_cache


static func build_unit_atlas_cached() -> Image:
	if _unit_cache == null:
		_unit_cache = build_unit_atlas()
	return _unit_cache


static func build_building_atlas_cached() -> Image:
	if _bld_cache == null:
		_bld_cache = build_building_atlas()
	return _bld_cache


## CPU equivalent of the sprite shader's material resolution (used for icons/portraits).
static func _resolve_mat(c: Color, tint: Color, skin: Color = Color(SKINS[1]), hair: Color = Color(HAIRS[1]), wool: Color = Color(WOOLS[0])) -> Color:
	var id := int(round(c.r * 255.0))
	var shade := c.g * 255.0 / 128.0
	var base := Color.MAGENTA
	match id:
		Mat.SKIN:
			base = skin
		Mat.CLOTHES, Mat.ROOF, Mat.BANNER:
			base = tint
		Mat.HAIR:
			base = hair
		Mat.WOOL:
			base = wool
		_:
			base = Color(MAT_COLORS.get(id, "#ff00ff"))
	var out := Color(base.r * shade, base.g * shade, base.b * shade, c.a)
	return out


static func unit_portrait(frame: int, tint: Color, skin: Color, hair: Color, wool: Color) -> Image:
	var atlas := build_unit_atlas_cached()
	var img := Image.create(UNIT_FRAME, UNIT_FRAME, false, Image.FORMAT_RGBA8)
	var fx := (frame % UNIT_ATLAS_COLS) * UNIT_FRAME
	@warning_ignore("integer_division")
	var fy := (frame / UNIT_ATLAS_COLS) * UNIT_FRAME
	for y in UNIT_FRAME:
		for x in UNIT_FRAME:
			var c := atlas.get_pixel(fx + x, fy + y)
			if c.a > 0.0:
				img.set_pixel(x, y, _resolve_mat(c, tint, skin, hair, wool))
	return img


static func _blit_unit(img: Image, atlas: Image, frame: int, ox: int, oy: int, tint: Color) -> void:
	var fx := (frame % UNIT_ATLAS_COLS) * UNIT_FRAME
	@warning_ignore("integer_division")
	var fy := (frame / UNIT_ATLAS_COLS) * UNIT_FRAME
	for y in UNIT_FRAME:
		for x in UNIT_FRAME:
			var c := atlas.get_pixel(fx + x, fy + y)
			if c.a > 0.0 and ox + x < img.get_width() and oy + y < img.get_height():
				img.set_pixel(ox + x, oy + y, _resolve_mat(c, tint))


static func _blit_scaled_unit(img: Image, atlas: Image, frame: int, ox: int, tint: Color) -> void:
	var fx := (frame % UNIT_ATLAS_COLS) * UNIT_FRAME
	@warning_ignore("integer_division")
	var fy := (frame / UNIT_ATLAS_COLS) * UNIT_FRAME
	for y in 16:
		for x in 16:
			var c := atlas.get_pixel(fx + x / 2, fy + y / 2)
			if c.a > 0.0:
				img.set_pixel(ox + x, y, _resolve_mat(c, tint))


# ---------------------------------------------------------------- primitives

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	for k in w:
		_px(img, x + k, y, c)


static func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _frame(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for k in w:
		_px(img, x + k, y, c)
		_px(img, x + k, y + h - 1, c)
	for k in h:
		_px(img, x, y + k, c)
		_px(img, x + w - 1, y + k, c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color, filled: bool) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := x * x + y * y
			if filled and d <= r * r + r:
				_px(img, cx + x, cy + y, c)
			elif not filled and d <= r * r + r and d >= (r - 1) * (r - 1) + (r - 1):
				_px(img, cx + x, cy + y, c)


static func _pattern(img: Image, ox: int, oy: int, rows: Array, c: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				_px(img, ox + x, oy + y, c)


static func _triangle(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in h:
		var t := 1.0 - absf(float(yy) - (h - 1) / 2.0) / ((h - 1) / 2.0)
		var len := int(round(t * w))
		_hline(img, x, y + yy, maxi(1, len), c)


static func _mound(img: Image, ox: int, up: bool) -> void:
	var dirt := Color("#8a6040")
	var grass := Color("#6aa83c")
	for x in 16:
		var hgt := int(5.0 * sin(PI * x / 15.0)) if up else 0
		for y in range(14 - hgt, 16):
			_px(img, ox + x, y, dirt)
		_px(img, ox + x, 14 - hgt, grass)
	if not up:
		for x in range(4, 12):
			var d := int(3.0 * sin(PI * (x - 4) / 7.0))
			for y in range(14, 14 + d):
				_px(img, ox + x, y, Color("#3a2818"))
	var c := Color("#f0e2c0")
	if up:
		_pattern(img, ox + 4, 1, ["...##...", "..####..", ".######.", "########", "...##...", "...##..."], c)
	else:
		_pattern(img, ox + 4, 1, ["...##...", "...##...", "########", ".######.", "..####..", "...##..."], c)
