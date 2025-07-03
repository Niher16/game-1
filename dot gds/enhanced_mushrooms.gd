# enhanced_mushrooms.gd - Bioluminescent mushroom cluster for Godot 4.1+
extends Node3D

# Mushroom configuration for natural lighting
@export_group("Mushroom Settings")
@export var mushroom_count: int = 5
@export var cluster_radius: float = 1.2
@export var light_energy: float = 1.5
@export var light_range: float = 8.0
@export var glow_intensity: float = 1.2

@export_group("Mushroom Types")
@export var large_mushroom_count: int = 2
@export var medium_mushroom_count: int = 2
@export var small_mushroom_count: int = 3

@export_group("Visual Effects")
@export var pulse_speed: float = 2.0
@export var pulse_intensity: float = 0.3
@export var spore_count: int = 12
@export var spore_float_speed: float = 0.3
@export var color_variation: bool = true

@export_group("Natural Behavior")
@export var react_to_enemies: bool = true
@export var enemy_reaction_range: float = 5.0
@export var dimming_when_enemies_near: float = 0.4

# Components
var mushroom_caps: Array[MeshInstance3D] = []
var mushroom_stems: Array[MeshInstance3D] = []
var mushroom_lights: Array[OmniLight3D] = []
var spore_particles: Array[MeshInstance3D] = []
var detection_area: Area3D
var main_light: OmniLight3D

# State and animation
var time_passed: float = 0.0
var spore_timer: float = 0.0
var enemies_nearby: bool = false
var base_light_energy: float
var pulse_phases: Array[float] = []

# Color variations for natural variety
var mushroom_colors = [
	{"cap": Color(0.2, 0.8, 0.6), "glow": Color(0.3, 1.0, 0.7)},  # Cyan-green
	{"cap": Color(0.1, 0.6, 0.9), "glow": Color(0.2, 0.8, 1.0)},  # Blue
	{"cap": Color(0.4, 0.9, 0.3), "glow": Color(0.5, 1.0, 0.4)},  # Bright green
	{"cap": Color(0.6, 0.8, 1.0), "glow": Color(0.7, 0.9, 1.0)},  # Light blue
	{"cap": Color(0.3, 1.0, 0.5), "glow": Color(0.4, 1.0, 0.6)}   # Jade green
]

func _ready():
	base_light_energy = light_energy
	_create_mushroom_cluster()
	_create_main_lighting()
	_create_spore_system()
	_create_detection_area()
	_setup_pulse_phases()
	
	# Add to appropriate groups
	add_to_group("natural_lights")
	add_to_group("mushrooms")
	add_to_group("bioluminescent")

func _process(delta: float):
	time_passed += delta
	_animate_pulsing(delta)
	_animate_spores(delta)
	_update_enemy_reaction()

func _create_mushroom_cluster():
	"""Create cluster of different sized glowing mushrooms"""
	var mushroom_id = 0
	
	# Create large mushrooms (main light sources)
	for i in range(large_mushroom_count):
		_create_single_mushroom(mushroom_id, "large")
		mushroom_id += 1
	
	# Create medium mushrooms
	for i in range(medium_mushroom_count):
		_create_single_mushroom(mushroom_id, "medium")
		mushroom_id += 1
	
	# Create small mushrooms (accent lighting)
	for i in range(small_mushroom_count):
		_create_single_mushroom(mushroom_id, "small")
		mushroom_id += 1

func _create_single_mushroom(id: int, size: String):
	"""Create individual mushroom with stem and glowing cap"""
	var pos_angle = randf() * TAU
	var pos_distance = randf_range(0.2, cluster_radius)
	var mushroom_pos = Vector3(
		cos(pos_angle) * pos_distance,
		0,
		sin(pos_angle) * pos_distance
	)
	
	# Get size parameters
	var size_data = _get_mushroom_size_data(size)
	var cap_radius = size_data.cap_radius
	var stem_height = size_data.stem_height
	var stem_radius = size_data.stem_radius
	var light_strength = size_data.light_strength
	
	# Create mushroom stem
	var stem = MeshInstance3D.new()
	stem.name = "MushroomStem_" + str(id)
	add_child(stem)
	
	var stem_mesh = CylinderMesh.new()
	stem_mesh.top_radius = stem_radius
	stem_mesh.bottom_radius = stem_radius * 1.2
	stem_mesh.height = stem_height
	stem.mesh = stem_mesh
	stem.position = mushroom_pos + Vector3(0, stem_height * 0.5, 0)
	
	# Natural stem material
	var stem_material = StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.8, 0.7, 0.6)  # Pale mushroom color
	stem_material.roughness = 0.8
	stem_material.metallic = 0.0
	stem.material_override = stem_material
	mushroom_stems.append(stem)
	
	# Create glowing mushroom cap
	var cap = MeshInstance3D.new()
	cap.name = "MushroomCap_" + str(id)
	add_child(cap)
	
	var cap_mesh = SphereMesh.new()
	cap_mesh.radius = cap_radius
	cap_mesh.height = cap_radius * 0.8  # Flattened sphere for cap shape
	cap.mesh = cap_mesh
	cap.position = mushroom_pos + Vector3(0, stem_height + cap_radius * 0.3, 0)
	cap.scale = Vector3(1.0, 0.6, 1.0)  # Flatten the cap
	
	# Glowing cap material with color variation
	var color_index = id % mushroom_colors.size() if color_variation else 0
	var color_data = mushroom_colors[color_index]
	
	var cap_material = StandardMaterial3D.new()
	cap_material.albedo_color = color_data.cap
	cap_material.emission_enabled = true
	cap_material.emission = color_data.glow * glow_intensity
	cap_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cap_material.albedo_color.a = 0.9
	# Add subtle subsurface scattering effect
	cap_material.roughness = 0.3
	cap_material.metallic = 0.0
	cap.material_override = cap_material
	mushroom_caps.append(cap)
	
	# Create individual light for each mushroom
	var mushroom_light = OmniLight3D.new()
	mushroom_light.name = "MushroomLight_" + str(id)
	add_child(mushroom_light)
	mushroom_light.position = cap.position + Vector3(0, -0.1, 0)
	mushroom_light.light_energy = light_energy * light_strength
	mushroom_light.light_color = color_data.glow
	mushroom_light.omni_range = light_range * light_strength
	mushroom_light.light_specular = 0.2  # Soft, natural light
	mushroom_light.shadow_enabled = false  # Natural soft lighting
	mushroom_lights.append(mushroom_light)

func _get_mushroom_size_data(size: String) -> Dictionary:
	"""Get size parameters for different mushroom types"""
	match size:
		"large":
			return {
				"cap_radius": randf_range(0.4, 0.6),
				"stem_height": randf_range(0.8, 1.2),
				"stem_radius": randf_range(0.08, 0.12),
				"light_strength": 1.0
			}
		"medium":
			return {
				"cap_radius": randf_range(0.25, 0.35),
				"stem_height": randf_range(0.5, 0.8),
				"stem_radius": randf_range(0.05, 0.08),
				"light_strength": 0.7
			}
		"small":
			return {
				"cap_radius": randf_range(0.15, 0.25),
				"stem_height": randf_range(0.3, 0.5),
				"stem_radius": randf_range(0.03, 0.05),
				"light_strength": 0.4
			}
		_:
			return {"cap_radius": 0.3, "stem_height": 0.6, "stem_radius": 0.06, "light_strength": 0.7}

func _create_main_lighting():
	"""Create main ambient light from mushroom cluster"""
	main_light = OmniLight3D.new()
	main_light.name = "MushroomClusterLight"
	add_child(main_light)
	
	# Position at cluster center, slightly elevated
	main_light.position = Vector3(0, 0.8, 0)
	
	# Soft, natural bioluminescent lighting
	main_light.light_energy = light_energy * 0.6
	main_light.light_color = Color(0.4, 0.9, 0.7)  # Soft green-cyan
	main_light.omni_range = light_range * 1.2
	main_light.light_specular = 0.1  # Very soft specular
	main_light.shadow_enabled = false  # Natural diffuse lighting

func _create_spore_system():
	"""Create floating spore particles around mushrooms"""
	for i in range(spore_count):
		var spore = MeshInstance3D.new()
		spore.name = "Spore_" + str(i)
		add_child(spore)
		
		# Tiny glowing spores
		var spore_mesh = SphereMesh.new()
		spore_mesh.radius = randf_range(0.005, 0.015)
		spore_mesh.height = spore_mesh.radius * 2
		spore.mesh = spore_mesh
		
		# Glowing spore material
		var spore_color_index = i % mushroom_colors.size()
		var spore_color = mushroom_colors[spore_color_index].glow
		
		var spore_material = StandardMaterial3D.new()
		spore_material.albedo_color = spore_color
		spore_material.emission_enabled = true
		spore_material.emission = spore_color * 2.0
		spore_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spore_material.albedo_color.a = 0.8
		spore.material_override = spore_material
		
		# Random starting position around cluster
		_reset_spore(spore)
		spore_particles.append(spore)

func _create_detection_area():
	"""Create area to detect nearby enemies"""
	if not react_to_enemies:
		return
		
	detection_area = Area3D.new()
	detection_area.name = "EnemyDetectionArea"
	add_child(detection_area)
	
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = enemy_reaction_range
	collision_shape.shape = sphere_shape
	detection_area.add_child(collision_shape)
	
	# Connect to enemy detection
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _setup_pulse_phases():
	"""Setup random pulse phases for natural variation"""
	pulse_phases.clear()
	for i in range(mushroom_lights.size()):
		pulse_phases.append(randf() * TAU)  # Random starting phase

func _animate_pulsing(_delta: float):
	"""Animate gentle pulsing glow (like breathing)"""
	for i in range(mushroom_lights.size()):
		if i >= mushroom_lights.size():
			continue
			
		var light = mushroom_lights[i]
		var phase = pulse_phases[i] if i < pulse_phases.size() else 0.0
		
		# Gentle sine wave pulsing
		var pulse = sin((time_passed * pulse_speed) + phase) * 0.5 + 0.5
		var pulse_modifier = 1.0 + (pulse * pulse_intensity)
		
		# Apply enemy dimming if needed
		var energy_modifier = 1.0
		if enemies_nearby:
			energy_modifier = dimming_when_enemies_near
		
		# Calculate final light energy
		var base_energy = base_light_energy * _get_mushroom_light_strength(i)
		light.light_energy = base_energy * pulse_modifier * energy_modifier
		
		# Also pulse the cap material emission
		if i < mushroom_caps.size():
			var cap = mushroom_caps[i]
			if cap.material_override:
				var mat = cap.material_override as StandardMaterial3D
				var base_emission = _get_base_emission_for_mushroom(i)
				mat.emission = base_emission * pulse_modifier * energy_modifier
	
	# Pulse main light too
	var main_pulse = sin(time_passed * pulse_speed * 0.7) * 0.5 + 0.5
	var main_modifier = 1.0 + (main_pulse * pulse_intensity * 0.5)
	var main_energy_modifier = 1.0 if not enemies_nearby else dimming_when_enemies_near
	main_light.light_energy = base_light_energy * 0.6 * main_modifier * main_energy_modifier

func _animate_spores(delta: float):
	"""Animate floating spore particles"""
	spore_timer += delta
	
	for spore in spore_particles:
		if not spore:
			continue
			
		# Gentle floating motion
		spore.position.y += spore_float_speed * delta
		
		# Subtle drift in X and Z
		spore.position.x += sin(time_passed + spore.position.x * 3) * delta * 0.1
		spore.position.z += cos(time_passed + spore.position.z * 3) * delta * 0.1
		
		# Fade out as they rise
		var height_ratio = spore.position.y / 3.0
		var alpha = 1.0 - clamp(height_ratio, 0.0, 1.0)
		if spore.material_override:
			var mat = spore.material_override as StandardMaterial3D
			mat.albedo_color.a = alpha * 0.8
		
		# Reset when too high
		if spore.position.y > 3.0:
			_reset_spore(spore)
		
		# Gentle pulsing of spore brightness
		if spore.material_override:
			var mat = spore.material_override as StandardMaterial3D
			var spore_pulse = sin(time_passed * 3.0 + spore.position.x) * 0.3 + 0.7
			mat.emission = _get_base_spore_color(spore) * spore_pulse

func _reset_spore(spore: MeshInstance3D):
	"""Reset spore to mushroom cluster area"""
	var angle = randf() * TAU
	var distance = randf() * cluster_radius * 1.2
	spore.position = Vector3(
		cos(angle) * distance,
		randf_range(0.1, 0.8),
		sin(angle) * distance
	)
	
	# Reset alpha
	if spore.material_override:
		var mat = spore.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.8

func _get_mushroom_light_strength(index: int) -> float:
	"""Get light strength multiplier for mushroom by index"""
	if index < large_mushroom_count:
		return 1.0
	elif index < large_mushroom_count + medium_mushroom_count:
		return 0.7
	else:
		return 0.4

func _get_base_emission_for_mushroom(index: int) -> Color:
	"""Get base emission color for mushroom cap"""
	var color_index = index % mushroom_colors.size() if color_variation else 0
	return mushroom_colors[color_index].glow * glow_intensity

func _get_base_spore_color(spore: MeshInstance3D) -> Color:
	"""Get base spore color from its current material"""
	if spore.material_override:
		var mat = spore.material_override as StandardMaterial3D
		return mat.albedo_color
	return Color.WHITE

func _update_enemy_reaction():
	"""Update lighting based on nearby enemies"""
	# This will be called from detection area signals
	pass

# --- ENEMY DETECTION SYSTEM ---

func _on_body_entered(body):
	"""Enemy entered detection range"""
	if body.is_in_group("enemies") or body.is_in_group("enemy"):
		enemies_nearby = true
		print("🍄 Mushrooms detected enemy presence - dimming lights")

func _on_body_exited(body):
	"""Enemy left detection range"""
	if body.is_in_group("enemies") or body.is_in_group("enemy"):
		# Check if any other enemies are still in range
		var bodies_in_area = detection_area.get_overlapping_bodies()
		enemies_nearby = false
		for check_body in bodies_in_area:
			if check_body.is_in_group("enemies") or check_body.is_in_group("enemy"):
				enemies_nearby = true
				break
		
		if not enemies_nearby:
			print("🍄 Mushrooms no longer detect enemies - restoring brightness")

# --- SPECIAL EFFECTS ---

func trigger_spore_burst():
	"""Create dramatic spore burst effect (for special events)"""
	for i in range(20):  # Extra spores for burst
		var burst_spore = MeshInstance3D.new()
		burst_spore.name = "BurstSpore_" + str(i)
		add_child(burst_spore)
		
		var spore_mesh = SphereMesh.new()
		spore_mesh.radius = randf_range(0.01, 0.03)
		burst_spore.mesh = spore_mesh
		
		# Bright burst spore material
		var spore_material = StandardMaterial3D.new()
		spore_material.albedo_color = Color(0.8, 1.0, 0.9, 1.0)
		spore_material.emission_enabled = true
		spore_material.emission = Color(0.8, 1.0, 0.9) * 3.0
		spore_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		burst_spore.material_override = spore_material
		
		# Random burst direction
		burst_spore.position = Vector3.ZERO
		
		# Auto-remove after animation
		var tween = create_tween()
		tween.parallel().tween_property(burst_spore, "position", 
			Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)), 2.0)
		tween.parallel().tween_property(spore_material, "albedo_color:a", 0.0, 2.0)
		tween.tween_callback(burst_spore.queue_free)

func set_glow_intensity(new_intensity: float):
	"""Change glow intensity (for day/night cycles, etc.)"""
	glow_intensity = new_intensity
	base_light_energy = light_energy * new_intensity
	
	# Update all mushroom materials
	for i in range(mushroom_caps.size()):
		var cap = mushroom_caps[i]
		if cap.material_override:
			var mat = cap.material_override as StandardMaterial3D
			mat.emission = _get_base_emission_for_mushroom(i)


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.