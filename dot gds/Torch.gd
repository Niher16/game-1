# Torch scene for dungeon rooms
extends OmniLight3D

@export var base_energy: float = 2.5 # Brighter light
@export var base_color: Color = Color(1.0, 0.85, 0.6, 1.0)
@export var torch_range: float = 10.0
@export var stick_height: float = 0.5 # 1/4 the previous height
@export var stick_radius: float = 0.1

func _ready():
	light_energy = base_energy
	light_color = base_color
	omni_range = torch_range
	_create_stick()

func _create_stick():
	var stick = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.height = stick_height
	cyl.top_radius = stick_radius
	cyl.bottom_radius = stick_radius
	stick.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.15, 0.05)
	mat.roughness = 0.7
	stick.material_override = mat
	stick.position = Vector3(0, stick_height/2, 0)
	add_child(stick)
