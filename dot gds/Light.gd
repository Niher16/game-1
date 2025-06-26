extends DirectionalLight3D

# Simple dungeon lighting controller
# Attach this script to your DirectionalLight3D node for basic dungeon ambiance

@export var base_energy: float = 0.7 # Slightly dimmer for dungeons
@export var base_color: Color = Color(1.0, 0.8, 0.5, 1.0) # Warm torch-like color

func _ready():
	light_energy = base_energy
	light_color = base_color

# Optionally, you can add a function to reset to defaults
func set_default_dungeon_light():
	light_energy = base_energy
	light_color = base_color
