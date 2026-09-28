class_name Powers
extends RefCounted
## Player god powers shown in the toolbar. Only powers that actually work are listed.
## repeat: seconds between applications while the mouse is held (0 = click only).

const CATEGORIES := [
	{"id": "inspect", "name": "Inspect", "icon": "inspect", "powers": ["inspect"]},
	{"id": "terrain", "name": "Terrain", "icon": "raise", "powers": ["raise", "lower", "paint_grass", "paint_soil", "paint_sand", "paint_forest", "paint_hills", "paint_mountain", "paint_snow", "paint_desert", "paint_swamp", "paint_ash", "paint_mystic", "paint_shallow", "paint_ocean", "paint_deep"]},
	{"id": "life", "name": "Life", "icon": "spawn_human", "powers": ["spawn_human", "spawn_sheep"]},
	{"id": "divine", "name": "Divine", "icon": "smite", "powers": ["smite", "bless"]},
	{"id": "disasters", "name": "Disasters", "icon": "fire", "powers": ["fire", "rain", "meteor", "earthquake", "volcano", "plague"]},
	{"id": "diplomacy", "name": "Diplomacy", "icon": "crown", "powers": ["incite_war", "forge_peace", "spark_rebellion"]},
]

const DEFS := {
	"inspect": {"name": "Inspect", "desc": "Click a creature, building or territory to see who they are and why things happen.", "brush": false, "repeat": 0.0},
	"raise": {"name": "Raise Land", "desc": "Lifts the ground. Seas become shores, plains become hills and peaks.", "brush": true, "repeat": 0.06},
	"lower": {"name": "Lower Land", "desc": "Sinks the ground. Enough lowering floods land into sea.", "brush": true, "repeat": 0.06},
	"paint_grass": {"name": "Grassland", "desc": "Fertile meadow. Grazers feed here and farmers love it.", "brush": true, "repeat": 0.04},
	"paint_soil": {"name": "Soil", "desc": "Rich bare earth, ready to be farmed.", "brush": true, "repeat": 0.04},
	"paint_sand": {"name": "Sand", "desc": "Beach sand. Poor for crops.", "brush": true, "repeat": 0.04},
	"paint_forest": {"name": "Forest", "desc": "Trees provide timber for houses and slowly spread.", "brush": true, "repeat": 0.04},
	"paint_hills": {"name": "Hills", "desc": "Rolling hills. Slow to cross; quarriers cut stone here.", "brush": true, "repeat": 0.04},
	"paint_mountain": {"name": "Mountain", "desc": "Impassable rock. Walls in peoples and herds.", "brush": true, "repeat": 0.04},
	"paint_snow": {"name": "Snowfield", "desc": "Frozen ground. Almost nothing grows.", "brush": true, "repeat": 0.04},
	"paint_desert": {"name": "Desert", "desc": "Dry dunes with sparse forage.", "brush": true, "repeat": 0.04},
	"paint_swamp": {"name": "Swamp", "desc": "Boggy land. Slow going, modest fertility.", "brush": true, "repeat": 0.04},
	"paint_ash": {"name": "Ashlands", "desc": "Scorched volcanic ground.", "brush": true, "repeat": 0.04},
	"paint_mystic": {"name": "Glimmerwood", "desc": "A strange luminous grove. Fertile and wooded.", "brush": true, "repeat": 0.04},
	"paint_shallow": {"name": "Shallows", "desc": "Shallow water. Creatures cannot walk here.", "brush": true, "repeat": 0.04},
	"paint_ocean": {"name": "Ocean", "desc": "Open sea. Drowns whatever stands on it.", "brush": true, "repeat": 0.04},
	"paint_deep": {"name": "Deep Ocean", "desc": "The abyss.", "brush": true, "repeat": 0.04},
	"spawn_human": {"name": "Humans", "desc": "Place a band of wanderers. Given room and food they will found a settlement.", "brush": true, "repeat": 0.25},
	"spawn_sheep": {"name": "Woolbacks", "desc": "Place grazing herd animals. They breed where grass is plentiful.", "brush": true, "repeat": 0.25},
	"smite": {"name": "Smite", "desc": "Strike every creature under the brush with lightning.", "brush": true, "repeat": 0.3},
	"bless": {"name": "Blessing", "desc": "Fully heal and feed every creature under the brush.", "brush": true, "repeat": 0.3},
	"fire": {"name": "Wildfire", "desc": "Set the land ablaze. Forests burn fiercely, grass less so; flames leave scorched ground that slowly regrows.", "brush": true, "repeat": 0.2},
	"rain": {"name": "Rain", "desc": "Douse fires, cool lava and green the land under the brush.", "brush": true, "repeat": 0.15},
	"meteor": {"name": "Meteor", "desc": "Call down a falling star. Leaves a smoking crater of lava.", "brush": true, "repeat": 0.8},
	"earthquake": {"name": "Earthquake", "desc": "Shake the ground: buildings collapse and a fissure tears open.", "brush": true, "repeat": 0.0},
	"volcano": {"name": "Volcano", "desc": "Raise a volcano that spews lava downhill. Lava cools into ashlands.", "brush": true, "repeat": 0.0},
	"plague": {"name": "Plague", "desc": "Infect creatures under the brush. Sickness spreads to neighbours; survivors become immune.", "brush": true, "repeat": 0.4},
	"incite_war": {"name": "Incite War", "desc": "Click a city: its kingdom declares war on its nearest neighbouring kingdom.", "brush": false, "repeat": 0.0},
	"forge_peace": {"name": "Forge Peace", "desc": "Click a city: its kingdom makes peace with all its enemies.", "brush": false, "repeat": 0.0},
	"spark_rebellion": {"name": "Spark Rebellion", "desc": "Click a city of a larger kingdom: it rises up and breaks away.", "brush": false, "repeat": 0.0},
}

const HOTKEYS := {"inspect": KEY_Q, "raise": KEY_R, "lower": KEY_F, "spawn_human": KEY_H, "spawn_sheep": KEY_J, "smite": KEY_X}


static func category_of(power: String) -> String:
	for c: Dictionary in CATEGORIES:
		if power in c["powers"]:
			return c["id"]
	return "inspect"


static func effect_kind(power: String) -> String:
	if power == "smite":
		return "smite"
	if power == "bless":
		return "bless"
	if power.begins_with("spawn"):
		return "spawn"
	if power in ["incite_war", "forge_peace", "spark_rebellion"]:
		return "diplomacy"
	if power in ["fire", "rain", "meteor", "earthquake", "volcano", "plague"]:
		return "disaster"
	return "terrain"


static func brush_color(power: String) -> Color:
	match effect_kind(power):
		"smite":
			return Color(1.0, 0.45, 0.35, 0.95)
		"bless":
			return Color(1.0, 0.9, 0.45, 0.95)
		"spawn":
			return Color(0.55, 1.0, 0.6, 0.95)
		"disaster":
			return Color(0.6, 0.9, 1.0, 0.95) if power == "rain" else (Color(0.6, 0.95, 0.35, 0.95) if power == "plague" else Color(1.0, 0.55, 0.2, 0.95))
	return Color(1.0, 0.95, 0.75, 0.9)
