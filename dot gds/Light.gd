extends DirectionalLight3D

# Simple dungeon lighting controller
# Attach this script to your DirectionalLight3D node for basic dungeon ambiance

@export var base_energy: float = 0.7 # Slightly dimmer for dungeons
@export var base_color: Color = Color(1.0, 0.8, 0.5, 1.0) # Warm torch-like color

# 8 different times of day (no pitch black or super dark)
var time_of_day_settings = [
	{ "energy": 0.85, "color": Color(1.0, 0.95, 0.8) },   # Morning
	{ "energy": 1.0,  "color": Color(1.0, 1.0, 0.95) },  # Noon
	{ "energy": 0.9,  "color": Color(1.0, 0.9, 0.7) },   # Afternoon
	{ "energy": 0.8,  "color": Color(1.0, 0.8, 0.5) },   # Golden hour
	{ "energy": 0.7,  "color": Color(0.9, 0.7, 0.5) },   # Sunset
	{ "energy": 0.75, "color": Color(0.7, 0.8, 1.0) },   # Early evening
	{ "energy": 0.65, "color": Color(0.8, 0.85, 1.0) },  # Dusk
	{ "energy": 0.8,  "color": Color(0.95, 0.95, 1.0) }  # Overcast/soft daylight
]

func _ready():
	# Randomly pick a time of day
	var idx = randi() % time_of_day_settings.size()
	var setting = time_of_day_settings[idx]
	light_energy = setting["energy"]
	light_color = setting["color"]

# Optionally, you can add a function to reset to defaults
func set_default_dungeon_light():
	light_energy = base_energy
	light_color = base_color
