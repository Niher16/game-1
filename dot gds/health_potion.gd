# health_potion.gd - Fixed version with proper color and healing
extends Area3D

# Health potion settings
@export var heal_amount: int = 30
@export var pickup_range: float = 2.0
@export var vacuum_speed: float = 6.0
@export var collection_range: float = 0.7

# Visual settings
@export var glow_intensity: float = 1.5
@export var pulse_speed: float = 4.0
@export var rotation_speed: float = 20.0

# Internal variables
var player: Node3D
var is_being_collected: bool = false
var is_vacuuming: bool = false
var time_alive: float = 0.0

# Visual components
var mesh_instance: MeshInstance3D
var potion_material: StandardMaterial3D

func _ready():
	print("🧪 Health Potion: Creating red glowing potion bottle...")
	add_to_group("health_potion")
	set_meta("heal_amount", heal_amount)
	collision_layer = 4
	collision_mask = 1
	# Create bottle asynchronously to avoid material timing issues
	await _create_simple_bottle()
	call_deferred("_find_player")
	get_tree().create_timer(45.0).timeout.connect(queue_free)
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Update visual state if player is at full health
	if player and player.has_method("can_heal"):
		set_meta("pickup_disabled", not player.can_heal())
		_update_visual_state()

# FIXED: Enhanced bottle creation with guaranteed red color
func _create_simple_bottle():
	# Create MeshInstance3D first
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PotionMesh"
	add_child(mesh_instance)
	
	# Create and assign mesh FIRST
	var bottle_mesh = CapsuleMesh.new()
	bottle_mesh.radius = 0.12
	bottle_mesh.height = 0.4
	mesh_instance.mesh = bottle_mesh
	
	# WAIT for next frame before setting materials
	await get_tree().process_frame
	
	# NOW create and set materials safely with BRIGHT RED color
	potion_material = StandardMaterial3D.new()
	potion_material.albedo_color = Color(1.0, 0.1, 0.1, 0.9)  # Brighter red, less transparent
	potion_material.emission_enabled = true
	potion_material.emission = Color(1.0, 0.0, 0.0) * glow_intensity  # Pure red emission
	potion_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	potion_material.roughness = 0.2  # More shiny
	potion_material.metallic = 0.0   # Less metallic for clearer color
	
	# Force material application with safety checks
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.material_override = potion_material
		print("✅ Red material applied to health potion")
	
	# Create cork (brown top)
	var cork = MeshInstance3D.new()
	cork.name = "Cork"
	mesh_instance.add_child(cork)
	var cork_mesh = CylinderMesh.new()
	cork_mesh.top_radius = 0.06
	cork_mesh.bottom_radius = 0.06
	cork_mesh.height = 0.08
	cork.mesh = cork_mesh
	cork.position = Vector3(0, 0.23, 0)
	var cork_material = StandardMaterial3D.new()
	cork_material.albedo_color = Color(0.4, 0.25, 0.1)
	cork_material.roughness = 0.8
	cork.material_override = cork_material
	
	# Create collision shape
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.15
	capsule_shape.height = 0.5
	collision.position = Vector3(0, 0.03, 0)
	collision.shape = capsule_shape
	add_child(collision)

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		get_tree().create_timer(0.5).timeout.connect(_find_player)
	else:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		set_meta("pickup_disabled", not player.can_heal())
		_update_visual_state()

func _on_player_health_changed(_current_health: int, _max_health: int):
	if player and player.has_method("can_heal"):
		set_meta("pickup_disabled", not player.can_heal())
		_update_visual_state()

func _process(delta):
	if is_being_collected:
		return
	time_alive += delta
	_animate_potion(delta)
	var pickup_disabled = get_meta("pickup_disabled", false)
	if not pickup_disabled:
		_check_vacuum_effect(delta)

func _animate_potion(delta):
	if not mesh_instance or not potion_material:
		return
	mesh_instance.rotation_degrees.y += rotation_speed * delta
	var pulse = (sin(time_alive * pulse_speed) + 1.0) / 2.0
	var glow_multiplier = 0.6 + (pulse * 0.8)
	if get_meta("pickup_disabled", false):
		glow_multiplier *= 0.4
	# Maintain bright red glow
	potion_material.emission = Color(1.0, 0.0, 0.0) * glow_intensity * glow_multiplier
	var alpha_pulse = 0.8 + (sin(time_alive * pulse_speed * 1.5) * 0.15)
	potion_material.albedo_color.a = alpha_pulse

func _check_vacuum_effect(delta):
	if not player or is_being_collected:
		return
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= pickup_range and not is_vacuuming:
		is_vacuuming = true
		print("🧪 Health Potion: Starting vacuum toward player!")
	if is_vacuuming:
		_move_toward_player(delta)
	if distance_to_player <= collection_range:
		_collect_potion()

func _move_toward_player(delta):
	if not player or is_being_collected:
		return
	var direction_to_player = (player.global_position - global_position).normalized()
	global_position += direction_to_player * vacuum_speed * delta

# FIXED: Actually heal the player when collected
func _collect_potion():
	if is_being_collected:
		return
	is_being_collected = true
	print("🧪 Health Potion: Collected! Healing for ", heal_amount, " HP!")
	
	# FIX: Actually heal the player here!
	if player and player.has_method("take_damage"):  # Player exists and has damage system
		if player.health_component and player.health_component.has_method("heal"):
			player.health_component.heal(heal_amount)  # Actually heal the player!
			print("✅ Player healed for ", heal_amount, " HP!")
		else:
			print("❌ Player health_component not found!")
	else:
		print("❌ Player not found or missing take_damage method!")
	
	_create_collection_effect()
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _create_collection_effect():
	if not mesh_instance:
		return
	var tween = create_tween()
	tween.set_parallel(true)
	if potion_material:
		tween.tween_property(potion_material, "emission", Color(0.2, 1.0, 0.2) * glow_intensity * 3.0, 0.1)
		tween.tween_property(potion_material, "albedo_color", Color(0.2, 1.0, 0.2, 0.0), 0.15)
	tween.tween_property(mesh_instance, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
	tween.tween_property(mesh_instance, "scale", Vector3(0.1, 0.1, 0.1), 0.12).set_delay(0.08)

func _create_pickup_delay_effect(delay_time: float):
	print("🧪 Health Potion: Creating pickup delay effect for ", delay_time, " seconds")
	if potion_material:
		var tween = create_tween()
		tween.set_loops(int(delay_time * 2))
		var dim_emission = Color(1.0, 0.0, 0.0) * (glow_intensity * 0.3)  # Keep red
		var normal_emission = Color(1.0, 0.0, 0.0) * (glow_intensity * 0.7)  # Keep red
		tween.tween_property(potion_material, "emission", dim_emission, 0.25)
		tween.tween_property(potion_material, "emission", normal_emission, 0.25)

func set_heal_amount(amount: int):
	heal_amount = amount
	set_meta("heal_amount", amount)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.can_heal():
			_collect_potion()
		else:
			# Show feedback for full health
			if body.has_method("show_message"):
				body.show_message("Already at full health!")

# Utility: Get or create StandardMaterial3D for a MeshInstance3D
func get_or_create_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	if not mesh or not mesh.mesh:
		return null
	if mesh.mesh.get_surface_count() == 0:
		return null
	var mat = mesh.get_active_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, mat)
	elif mat is StandardMaterial3D:
		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)
	else:
		mat = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, mat)
	return mat

func _update_visual_state():
	if mesh_instance:
		var mat = get_or_create_material(mesh_instance)
		if mat:
			if get_meta("pickup_disabled", false):
				mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5) # Greyed out, semi-transparent
			else:
				mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9) # Bright red

static func safe_set_material(mesh_target: MeshInstance3D, material: Material) -> bool:
	if not mesh_target:
		push_warning("🚨 Mesh instance is null")
		return false
	if not mesh_target.mesh:
		push_warning("🚨 Mesh is null")
		return false
	if mesh_target.mesh.get_surface_count() == 0:
		push_warning("🚨 Mesh has no surfaces")
		return false
	if not material:
		push_warning("🚨 Material is null - creating default")
		material = StandardMaterial3D.new()
	mesh_target.material_override = material
	return true
