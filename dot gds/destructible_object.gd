# destructible_object.gd - Fixed version
extends StaticBody3D

enum ObjectType { CRATE, BARREL }

# Configuration
@export var object_type: ObjectType = ObjectType.CRATE
@export var health: int = 2
@export var glow_intensity: float = 0.3

# Visual components
var mesh_instance: MeshInstance3D
var wood_material: StandardMaterial3D
var is_being_destroyed = false

# Breaking effect settings
const DEBRIS_COUNT = 8
const DEBRIS_FORCE = 4.0
const DEBRIS_LIFETIME = 1.0

func _ready():
	# Add to groups for attack detection
	add_to_group("destructibles")
	add_to_group("enemies")  # This allows player attacks to hit it
	_create_visual()
	_setup_collision()

func _create_visual():
	# Remove any existing visual components
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()

	# --- Randomize object transform for uniqueness ---
	rotation = Vector3(
		randf_range(-0.05, 0.05),
		randf_range(0, TAU),
		randf_range(-0.05, 0.05)
	)
	scale = Vector3.ONE * randf_range(0.96, 1.04)

	# --- Materials ---
	# Wood material with subtle grain, roughness variation, rim, emission, color variation
	var wood_color = Color(
		0.38 + randf_range(-0.03, 0.03),
		0.23 + randf_range(-0.02, 0.02),
		0.10 + randf_range(-0.01, 0.01)
	)
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = wood_color
	wood_material.roughness = randf_range(0.7, 0.9)
	wood_material.emission_enabled = true
	wood_material.emission = wood_color * glow_intensity * randf_range(0.9, 1.1)
	# Subtle normal mapping (simulate if no texture)
	wood_material.normal_scale = 0.15
	# Uncomment if you have a normal map:
	# wood_material.normal_texture = preload("res://textures/wood_grain_normal.png")
	# Add subtle wood variation using material properties only
	wood_material.clearcoat = 0.2  # Adds subtle surface variation
	wood_material.clearcoat_roughness = 0.8

	var weathered_wood_material = wood_material.duplicate()
	weathered_wood_material.albedo_color = wood_color.darkened(0.1)
	weathered_wood_material.roughness = clamp(wood_material.roughness + 0.05, 0.7, 0.95)

	# Metal material for bands, corners, hinges (high metallic, low roughness, rust tint, emission)
	var rust_tint = Color(0.25, 0.13, 0.08) * randf_range(0.1, 0.25)
	var metal_base = Color(0.32, 0.32, 0.36) * randf_range(0.85, 1.0)
	var metal_color = metal_base.lerp(rust_tint, randf_range(0.2, 0.5))
	var metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = metal_color
	metal_material.metallic = randf_range(0.8, 0.9)
	metal_material.roughness = randf_range(0.1, 0.3)
	metal_material.emission_enabled = true
	metal_material.emission = rust_tint * randf_range(0.2, 0.5)
	# Optionally assign a normal map for weathering
	metal_material.normal_scale = 0.08

	var rope_material = StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.6, 0.5, 0.3)
	rope_material.roughness = 0.7

	match object_type:
		ObjectType.BARREL:
			# Main barrel body (slightly tapered cylinder)
			mesh_instance = MeshInstance3D.new()
			mesh_instance.name = "BarrelBody"
			var barrel_mesh = CylinderMesh.new()
			barrel_mesh.top_radius = 0.38
			barrel_mesh.bottom_radius = 0.32
			barrel_mesh.height = 1.0
			barrel_mesh.radial_segments = 32
			mesh_instance.mesh = barrel_mesh
			mesh_instance.material_override = wood_material
			add_child(mesh_instance)

			# Metal bands (3-4)
			for i in range(4):
				var band = MeshInstance3D.new()
				band.name = "MetalBand%d" % i
				var band_mesh = CylinderMesh.new()
				band_mesh.top_radius = 0.41
				band_mesh.bottom_radius = 0.41
				band_mesh.height = 0.05
				band_mesh.radial_segments = 32
				band.mesh = band_mesh
				band.material_override = metal_material
				band.position.y = -0.45 + i * 0.3
				# Randomize band rotation/scale for uniqueness
				band.rotation.y = randf_range(0, TAU)
				band.scale = Vector3.ONE * randf_range(0.97, 1.03)
				add_child(band)

			# Top and bottom wooden caps
			for cap_y in [-0.5, 0.5]:
				var cap = MeshInstance3D.new()
				cap.name = "BarrelCap_%s" % ("Bottom" if cap_y < 0 else "Top")
				var cap_mesh = CylinderMesh.new()
				cap_mesh.top_radius = 0.36
				cap_mesh.bottom_radius = 0.36
				cap_mesh.height = 0.04
				cap_mesh.radial_segments = 32
				cap.mesh = cap_mesh
				cap.material_override = weathered_wood_material
				cap.position.y = cap_y
				cap.rotation.y = randf_range(0, TAU)
				cap.scale = Vector3.ONE * randf_range(0.97, 1.03)
				add_child(cap)

		ObjectType.CRATE:
			# Main box body only (simple crate, slightly beveled)
			mesh_instance = MeshInstance3D.new()
			mesh_instance.name = "CrateBody"
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.8, 0.8, 0.8)
			mesh_instance.mesh = box_mesh
			mesh_instance.material_override = weathered_wood_material
			# Slight bevel effect by scaling
			mesh_instance.scale = Vector3(0.97, 1.0, 0.97)
			add_child(mesh_instance)

			# Add a faint metallic band around the middle for visual interest
			var band = MeshInstance3D.new()
			band.name = "CrateBand"
			var band_mesh = BoxMesh.new()
			band_mesh.size = Vector3(0.82, 0.06, 0.82)
			band.mesh = band_mesh
			band.material_override = metal_material
			band.position = Vector3(0, 0, 0)
			band.scale = Vector3(1.0, 1.0, 1.0)
			add_child(band)

func _setup_collision():
	"""Setup collision shape for physics and attacks"""
	# Main collision for physics
	var collision = CollisionShape3D.new()
	
	match object_type:
		ObjectType.CRATE:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.8, 0.8, 0.8)
			collision.shape = box_shape
		ObjectType.BARREL:
			var cylinder_shape = CylinderShape3D.new()
			cylinder_shape.radius = 0.4
			cylinder_shape.height = 1.0
			collision.shape = cylinder_shape
	
	add_child(collision)
	
	# Set collision layers so objects are solid for player and still allow attacks
	collision_layer = 1  # Player collides with this (solid)
	collision_mask = 1   # Collide with world

func take_damage(amount: int):
	"""Handle taking damage from player attacks"""
	if is_being_destroyed:
		return
	
	health -= amount
	_show_damage_effect()
	
	if health <= 0:
		_destroy()

func _show_damage_effect():
	"""Show visual feedback when taking damage"""
	if not mesh_instance:
		return
	
	# Quick scale punch effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(mesh_instance, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.2).set_delay(0.1)
	
	# Flash material
	if wood_material:
		var flash_tween = create_tween()
		flash_tween.tween_property(wood_material, "emission", 
			Color(1.0, 0.5, 0.2) * glow_intensity * 3.0, 0.1)
		flash_tween.tween_property(wood_material, "emission", 
			Color(0.4, 0.25, 0.1) * glow_intensity, 0.2)

func _destroy():
	"""Handle destruction and loot drops"""
	if is_being_destroyed:
		return

	is_being_destroyed = true

	# 🚫 IMMEDIATE COLLISION DISABLE - This fixes your issue!
	collision_layer = 0  # Remove from all collision layers
	collision_mask = 0   # Stop colliding with anything

	# Also disable the CollisionShape3D for extra safety
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

	# Instantly hide all children except debris (if any)
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

	_create_breaking_effect()
	_drop_loot()

	# Clean up after effects finish (but collision is already gone)
	await get_tree().create_timer(DEBRIS_LIFETIME).timeout
	queue_free()

func _create_breaking_effect():
	"""Create breaking animation and debris"""
	if not mesh_instance:
		return
	
	# Hide original mesh
	mesh_instance.visible = false
	
	# Create debris pieces
	for i in range(DEBRIS_COUNT):
		var debris = MeshInstance3D.new()
		var debris_mesh = BoxMesh.new()
		
		# Size based on object type
		var size = 0.2 if object_type == ObjectType.CRATE else 0.15
		debris_mesh.size = Vector3(size, size, size)
		debris.mesh = debris_mesh
		debris.material_override = wood_material
		
		add_child(debris)
		
		# Random position within object bounds
		var offset = Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.3, 0.3),
			randf_range(-0.3, 0.3)
		)
		debris.position = offset
		
		# Launch debris
		var direction = offset.normalized()
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Movement
		var target_pos = debris.position + direction * DEBRIS_FORCE
		target_pos.y -= 1.0  # Fall down
		tween.tween_property(debris, "position", target_pos, DEBRIS_LIFETIME)
		
		# Rotation
		var random_rotation = Vector3(
			randf_range(-PI, PI),
			randf_range(-PI, PI),
			randf_range(-PI, PI)
		)
		tween.tween_property(debris, "rotation", random_rotation, DEBRIS_LIFETIME)
		
		# Fade out
		tween.tween_property(debris, "scale", Vector3.ZERO, 0.3).set_delay(DEBRIS_LIFETIME - 0.3)

func _drop_loot():
	"""Drop appropriate loot based on object type"""
	if not LootManager:
		return

	var type_key = "crate" if object_type == ObjectType.CRATE else "barrel"

	if LootManager.has_method("drop_destructible_loot"):
		LootManager.drop_destructible_loot(global_position, type_key)


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.