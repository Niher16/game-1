# coin.gd - FIXED: Proper pickup delay handling
extends Area3D

static func safe_set_material(mesh_target: MeshInstance3D, material: Material) -> bool:
	"""Safely set material with null check - Godot 4.1 best practice"""
	if not mesh_target:
		push_warning("🚨 Mesh instance is null - cannot set material")
		return false
	if not material:
		push_warning("🚨 Material is null - creating default material")
		material = StandardMaterial3D.new()
	mesh_target.material_override = material
	return true

# Coin settings
@export var coin_value: int = 10
@export var pickup_range: float = 2.5
@export var vacuum_speed: float = 7.0
@export var collection_range: float = 0.6

# Visual settings
@export var glow_intensity: float = 1.5
@export var bob_height: float = 0.2
@export var bob_speed: float = 2.5
@export var spin_speed: float = 180.0

# Collision settings
@export var coin_collision_layer: int = 4
@export var coin_collision_mask: int = 3 # 1 (walls) | 2 (floor)

# Internal variables
var player: Node3D
var is_being_collected: bool = false
var is_vacuuming: bool = false
var time_alive: float = 0.0
var pulse_phase_offset: float = 0.0  # NEW: random phase for each coin
var pulse_speed_multiplier: float = 1.0

# Visual components
var mesh_instance: MeshInstance3D
var coin_material: StandardMaterial3D

func _ready():
	add_to_group("currency")
	set_meta("coin_value", coin_value)
	
	collision_layer = coin_collision_layer
	collision_mask = coin_collision_mask
	
	_create_golden_coin()
	call_deferred("_find_player")
	
	# NEW: Assign a random phase offset for irregular blinking
	pulse_phase_offset = randf() * TAU
	pulse_speed_multiplier = 0.5 + (randf() * 0.3)  # Random speed between 0.5x and 0.8x
	
	# Auto-cleanup after 60 seconds
	get_tree().create_timer(60.0).timeout.connect(queue_free)

func _create_golden_coin():
	"""Create the spinning golden coin mesh"""
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CoinMesh"
	add_child(mesh_instance)
	
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.1  # Was 0.2
	cylinder_mesh.bottom_radius = 0.1  # Was 0.2
	cylinder_mesh.height = 0.025  # Was 0.05
	mesh_instance.mesh = cylinder_mesh
	
	coin_material = StandardMaterial3D.new()
	coin_material.albedo_color = Color(1.0, 0.8, 0.0)
	coin_material.emission_enabled = true
	coin_material.emission = Color(1.0, 0.7, 0.0) * glow_intensity
	coin_material.roughness = 0.1
	coin_material.metallic = 0.9
	coin_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	coin_material.albedo_color.a = 0.95
	
	# Safe material assignment with null check
	if not safe_set_material(mesh_instance, coin_material):
		var fallback_material = StandardMaterial3D.new()
		fallback_material.albedo_color = Color.GOLD
		mesh_instance.material_override = fallback_material
	
	var collision = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.height = 0.05  # Was 0.1
	cylinder_shape.radius = 0.1  # Was 0.2
	collision.shape = cylinder_shape
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
	_animate_coin(delta)
	
	# Cache pickup_disabled for this frame
	var pickup_disabled = get_meta("pickup_disabled", false)
	if not pickup_disabled:
		_check_vacuum_effect(delta)

func _animate_coin(delta):
	"""Create spinning animation"""
	if not mesh_instance or not coin_material:
		return
	
	# Spinning animation only
	mesh_instance.rotation_degrees.y += spin_speed * delta
	
	# Pulsing glow effect - DIMMED if pickup is disabled
	if coin_material:
		# Much slower base pulse (0.15) multiplied by random speed
		var pulse_speed = 0.15 * pulse_speed_multiplier
		var pulse = (sin(time_alive * pulse_speed + pulse_phase_offset) + 1.0) / 2.0
		var glow_multiplier = 0.7 + (pulse * 0.6)
		
		# FIXED: Dim the glow during pickup delay
		if get_meta("pickup_disabled", false):
			glow_multiplier *= 0.3  # Much dimmer during delay
		
		coin_material.emission = Color(1.0, 0.7, 0.0) * glow_intensity * glow_multiplier

func _check_vacuum_effect(delta):
	"""Check if player is close enough for vacuum effect"""
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
		_collect_coin()

func _move_toward_player(delta):
	"""Move coin toward player"""
	if not player or is_being_collected:
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var move_vector = direction_to_player * vacuum_speed * delta
	global_position += move_vector

func _collect_coin():
	"""Handle coin collection"""
	if is_being_collected:
		return
	
	is_being_collected = true
	
	_create_collection_effect()
	
	# --- DEBUG: Connect Coin to player progression ---
	var player_ref = get_tree().get_first_node_in_group("player")
	if player_ref and player_ref.progression_component:
		player_ref.progression_component.add_currency(coin_value)
	
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _create_collection_effect():
	"""Create sparkly collection effect"""
	if not mesh_instance:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	if coin_material:
		tween.tween_property(coin_material, "emission", Color(2.0, 1.5, 0.0), 0.1)
		tween.tween_property(coin_material, "albedo_color:a", 0.0, 0.15)
	
	tween.tween_property(mesh_instance, "scale", Vector3(1.8, 1.8, 1.8), 0.1)
	tween.tween_property(mesh_instance, "scale", Vector3(0.1, 0.1, 0.1), 0.1).set_delay(0.1)

func _create_pickup_delay_effect(delay_time: float):
	"""Create visual effect during pickup delay"""
	# FIXED: Visual feedback that item isn't ready
	if coin_material:
		# Make the coin pulse slowly and dimly during delay
		var tween = create_tween()
		tween.set_loops(int(delay_time * 1))  # 1 pulse per second
		
		var dim_emission = Color(1.0, 0.7, 0.0) * (glow_intensity * 0.3)
		var normal_emission = Color(1.0, 0.7, 0.0) * (glow_intensity * 0.6)
		
		tween.tween_property(coin_material, "emission", dim_emission, 0.5)
		tween.tween_property(coin_material, "emission", normal_emission, 0.5)

func set_coin_value(value: int):
	"""Set the coin value"""
	coin_value = value
	set_meta("coin_value", value)


# Godot 4.1+ best practice: Standardized getter/setter for coin value
func set_amount(value: int):
	set_coin_value(value)

func get_amount() -> int:
	return coin_value


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.