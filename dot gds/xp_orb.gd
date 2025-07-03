extends Area3D

# XP orb settings
@export var xp_value: int = 10
@export var pickup_range: float = 3.0
@export var vacuum_speed: float = 8.0
@export var collection_range: float = 0.8

# Visual settings
@export var glow_intensity: float = 1.8
@export var rotation_speed: float = 25.0
@export var pulse_speed: float = 0.002  # Much slower blinking
@export var bob_height: float = 0.1
@export var bob_speed: float = 2.0

# Collision settings
@export var xp_collision_layer: int = 4
@export var xp_collision_mask: int = 3 # 1 (walls) | 2 (floor)

# Internal variables
var player: Node3D
var is_being_collected: bool = false
var is_vacuuming: bool = false
var time_alive: float = 0.0

# Visual components
var mesh_instance: MeshInstance3D
var orb_material: StandardMaterial3D
var inner_core: MeshInstance3D

func _ready():
	add_to_group("xp_orb")
	set_meta("xp_value", xp_value)
	
	collision_layer = xp_collision_layer
	collision_mask = xp_collision_mask
	
	_create_glowing_sphere()
	call_deferred("_find_player")
	
	# Auto-cleanup after 60 seconds
	get_tree().create_timer(60.0).timeout.connect(queue_free)

func _create_glowing_sphere():
	"""Create a beautiful glowing blue sphere with inner core"""
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "OrbMesh"
	add_child(mesh_instance)
	
	# Create sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.12  # Was 0.16
	sphere_mesh.height = 0.24  # Was 0.32
	mesh_instance.mesh = sphere_mesh
	
	# Create beautiful glowing blue material
	orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color(0.4, 0.8, 1.0, 0.85)
	orb_material.emission_enabled = true
	orb_material.emission = Color(0.3, 0.7, 1.0) * glow_intensity
	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.roughness = 0.1
	orb_material.metallic = 0.3
	
	mesh_instance.material_override = orb_material
	
	# Add inner core for depth
	inner_core = MeshInstance3D.new()
	inner_core.name = "InnerCore"
	mesh_instance.add_child(inner_core)
	
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.06  # Was 0.08
	core_mesh.height = 0.12  # Was 0.16
	inner_core.mesh = core_mesh
	
	var core_material = StandardMaterial3D.new()
	core_material.albedo_color = Color(0.8, 0.95, 1.0, 0.6)
	core_material.emission_enabled = true
	core_material.emission = Color(0.6, 0.9, 1.0) * glow_intensity * 1.5
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.roughness = 0.0
	inner_core.material_override = core_material
	
	# Create collision shape
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.14  # Was 0.18
	collision.shape = sphere_shape
	add_child(collision)

func _find_player():
	"""Find the player node"""
	player = get_tree().get_first_node_in_group("player")
	if not player:
		get_tree().create_timer(0.5).timeout.connect(_find_player)

func _process(delta):
	if is_being_collected:
		return
	
	time_alive += delta
	_animate_orb(delta)
	
	# Cache pickup_disabled for this frame
	var pickup_disabled = get_meta("pickup_disabled", false)
	if not pickup_disabled:
		_check_vacuum_effect(delta)

func _animate_orb(delta):
	"""Create smooth rotation, gentle bobbing, and subtle pulsing glow"""
	if not mesh_instance or not orb_material or not inner_core:
		return
	
	# Smooth rotation on multiple axes
	mesh_instance.rotation_degrees.y += rotation_speed * delta
	mesh_instance.rotation_degrees.x += rotation_speed * 0.3 * delta
	mesh_instance.rotation_degrees.z += rotation_speed * 0.1 * delta
	
	# Gentle bobbing motion
	var bob_offset = sin(time_alive * bob_speed) * bob_height
	mesh_instance.position.y = bob_offset
	
	# Subtle pulsing glow effect
	if orb_material:
		var pulse = (sin(time_alive * pulse_speed) + 1.0) / 2.0
		var glow_multiplier = 0.8 + (pulse * 0.3)
		
		# Dim the glow during pickup delay
		if get_meta("pickup_disabled", false):
			glow_multiplier *= 0.5
		
		orb_material.emission = Color(0.3, 0.7, 1.0) * glow_intensity * glow_multiplier
		
		# Very subtle transparency change
		var alpha_pulse = 0.82 + (sin(time_alive * pulse_speed * 0.2) * 0.08)  # Even slower alpha pulse
		orb_material.albedo_color.a = alpha_pulse
	
	# Animate inner core with different timing
	if inner_core and inner_core.material_override:
		# Make core pulse even slower
		var core_pulse = (sin(time_alive * pulse_speed * 0.15) + 1.0) / 2.0  # Slower than before (was 0.3)
		var core_glow = 0.9 + (core_pulse * 0.2)
		inner_core.material_override.emission = Color(0.6, 0.9, 1.0) * glow_intensity * 1.5 * core_glow
		
		# Counter-rotate the core for cool effect
		inner_core.rotation_degrees.y -= rotation_speed * 0.8 * delta

func _check_vacuum_effect(delta):
	"""Check if player is close enough to start vacuum effect"""
	if not player or is_being_collected:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Start vacuum effect
	if distance_to_player <= pickup_range and not is_vacuuming:
		is_vacuuming = true
	
	# Move toward player
	if is_vacuuming:
		_move_toward_player(delta)
	
	# Collect when close enough
	if distance_to_player <= collection_range:
		_collect_orb()

func _move_toward_player(delta):
	"""Move orb toward player"""
	if not player or is_being_collected:
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var move_vector = direction_to_player * vacuum_speed * delta
	global_position += move_vector

func _collect_orb():
	"""Handle orb collection"""
	if is_being_collected:
		return

	is_being_collected = true

	# --- DEBUG: Connect XP to player progression ---
	var player_ref = get_tree().get_first_node_in_group("player")
	if player_ref and player_ref.progression_component:
		player_ref.progression_component.add_xp(xp_value)

	_create_collection_effect()

	await get_tree().create_timer(0.2).timeout
	queue_free()

func _create_collection_effect():
	"""Create beautiful sparkly collection effect"""
	if not mesh_instance:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Bright flash on main orb
	if orb_material:
		tween.tween_property(orb_material, "emission", Color(0.8, 1.0, 1.0) * glow_intensity * 2.5, 0.1)
		tween.tween_property(orb_material, "albedo_color:a", 0.0, 0.15)
	
	# Flash inner core
	if inner_core and inner_core.material_override:
		tween.tween_property(inner_core.material_override, "emission", Color(1.0, 1.0, 1.0) * glow_intensity * 3.0, 0.08)
		tween.tween_property(inner_core.material_override, "albedo_color:a", 0.0, 0.12)
	
	# Elegant scale animation
	tween.tween_property(mesh_instance, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
	tween.tween_property(mesh_instance, "scale", Vector3(0.1, 0.1, 0.1), 0.12).set_delay(0.08)

func _create_pickup_delay_effect(delay_time: float):
	"""Create visual effect during pickup delay"""
	if orb_material:
		# Very gentle pulse during delay
		var tween = create_tween()
		tween.set_loops(int(delay_time * 1.5))  # Slower pulsing
		
		var dim_emission = Color(0.3, 0.7, 1.0) * (glow_intensity * 0.5)
		var normal_emission = Color(0.3, 0.7, 1.0) * (glow_intensity * 0.8)
		
		tween.tween_property(orb_material, "emission", dim_emission, 0.33)
		tween.tween_property(orb_material, "emission", normal_emission, 0.33)

func set_xp_value(value: int):
	"""Set the XP value this orb gives"""
	xp_value = value
	set_meta("xp_value", value)


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.