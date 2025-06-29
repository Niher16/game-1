# enhanced_torch.gd - Beautiful torch with fire effects for Godot 4.1
extends Node3D

# Torch configuration
@export_group("Torch Settings")
@export var torch_height: float = 1.2
@export var torch_radius: float = 0.08
@export var flame_intensity: float = 1.5
@export var light_energy: float = 2.0
@export var light_range: float = 12.0

@export_group("Visual Effects")
@export var flame_flicker_speed: float = 3.0
@export var flame_height_variation: float = 0.3
@export var ember_count: int = 8
@export var smoke_enabled: bool = true

# Components
var torch_handle: MeshInstance3D
var flame_core: MeshInstance3D
var flame_outer: MeshInstance3D
var torch_light: OmniLight3D
var ember_particles: Array[MeshInstance3D] = []
var smoke_particles: Array[MeshInstance3D] = []

# Animation variables
var time_passed: float = 0.0
var flame_base_height: float = 0.4
var ember_timer: float = 0.0

func _ready():
	_create_torch_handle()
	_create_flame_system()
	_create_lighting()
	_create_ember_system()
	if smoke_enabled:
		_create_smoke_system()

func _process(delta: float):
	time_passed += delta
	_animate_flame(delta)
	_animate_embers(delta)
	if smoke_enabled:
		_animate_smoke(delta)
	_flicker_light(delta)

func _create_torch_handle():
	"""Create the wooden torch handle with realistic materials"""
	torch_handle = MeshInstance3D.new()
	torch_handle.name = "TorchHandle"
	add_child(torch_handle)
	
	# Move the stick (handle) further down
	torch_handle.position = Vector3(0, -0.6, 0)
	
	# Create cylinder mesh for handle
	var handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = torch_radius
	handle_mesh.bottom_radius = torch_radius * 1.2  # Slightly wider at bottom
	handle_mesh.height = torch_height
	torch_handle.mesh = handle_mesh
	
	# Wooden material with subtle glow (like your weapon pickups)
	var wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.4, 0.25, 0.15) # Dark brown wood
	wood_material.roughness = 0.8
	wood_material.metallic = 0.0
	wood_material.emission_enabled = true
	wood_material.emission = Color(0.3, 0.2, 0.1) * 0.2  # Subtle warm glow
	torch_handle.material_override = wood_material
	
	# Add torch top (where flame sits)
	var torch_top = MeshInstance3D.new()
	torch_top.name = "TorchTop"
	torch_handle.add_child(torch_top)
	
	var top_mesh = CylinderMesh.new()
	top_mesh.top_radius = torch_radius * 1.5
	top_mesh.bottom_radius = torch_radius * 1.2
	top_mesh.height = 0.15
	torch_top.mesh = top_mesh
	torch_top.position = Vector3(0, torch_height * 0.45 - 0.6, 0)
	
	# Metal material for torch top
	var metal_material = StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.3, 0.3, 0.3)
	metal_material.metallic = 0.9
	metal_material.roughness = 0.3
	torch_top.material_override = metal_material

func _create_flame_system():
	"""Create beautiful layered flame effect"""
	# Inner flame core (bright, intense)
	flame_core = MeshInstance3D.new()
	flame_core.name = "FlameCore"
	add_child(flame_core)
	
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = flame_base_height
	flame_core.mesh = core_mesh
	flame_core.position = Vector3(0, torch_height * 0.5 + flame_base_height * 0.5 - 0.9, 0)
	
	# Bright orange/yellow core material
	var core_material = StandardMaterial3D.new()
	core_material.albedo_color = Color(1.0, 0.8, 0.3, 0.9)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.6, 0.2) * flame_intensity * 2.0
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame_core.material_override = core_material
	
	# Outer flame (softer, larger)
	flame_outer = MeshInstance3D.new()
	flame_outer.name = "FlameOuter"
	add_child(flame_outer)
	
	var outer_mesh = SphereMesh.new()
	outer_mesh.radius = 0.25
	outer_mesh.height = flame_base_height * 1.3
	flame_outer.mesh = outer_mesh
	flame_outer.position = Vector3(0, torch_height * 0.5 + flame_base_height * 0.6 - 0.9, 0)
	
	# Orange/red outer flame material
	var outer_material = StandardMaterial3D.new()
	outer_material.albedo_color = Color(1.0, 0.4, 0.1, 0.6)
	outer_material.emission_enabled = true
	outer_material.emission = Color(1.0, 0.3, 0.1) * flame_intensity
	outer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame_outer.material_override = outer_material

func _create_lighting():
	"""Create dynamic torch lighting (following your lighting patterns)"""
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	add_child(torch_light)
	
	# Position light at flame location
	torch_light.position = Vector3(0, torch_height * 0.5 + flame_base_height * 0.5 - 0.9, 0)
	
	# Warm, flickering light settings (like your weapon room lighting)
	torch_light.light_energy = light_energy
	torch_light.light_color = Color(1.0, 0.7, 0.4) # Warm orange
	torch_light.omni_range = light_range  # Godot 4.1 uses omni_range
	torch_light.light_specular = 0.8
	
	# Add subtle shadow for atmosphere
	torch_light.shadow_enabled = true
	torch_light.shadow_bias = 0.1

func _create_ember_system():
	"""Create floating embers around the flame"""
	for i in range(ember_count):
		var ember = MeshInstance3D.new()
		ember.name = "Ember_" + str(i)
		add_child(ember)
		
		# Small sphere for ember
		var ember_mesh = SphereMesh.new()
		ember_mesh.radius = randf_range(0.02, 0.05)
		ember_mesh.height = ember_mesh.radius * 2
		ember.mesh = ember_mesh
		
		# Glowing ember material (following your XP orb pattern)
		var ember_material = StandardMaterial3D.new()
		ember_material.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
		ember_material.emission_enabled = true
		ember_material.emission = Color(1.0, 0.4, 0.1) * 1.5
		ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ember.material_override = ember_material
		
		# Random starting position around flame
		_reset_ember(ember, i)
		ember_particles.append(ember)

func _create_smoke_system():
	"""Create subtle smoke particles rising from flame"""
	for i in range(4):
		var smoke = MeshInstance3D.new()
		smoke.name = "Smoke_" + str(i)
		add_child(smoke)
		
		# Small sphere for smoke particle
		var smoke_mesh = SphereMesh.new()
		smoke_mesh.radius = randf_range(0.08, 0.15)
		smoke_mesh.height = smoke_mesh.radius * 2
		smoke.mesh = smoke_mesh
		
		# Translucent gray smoke material
		var smoke_material = StandardMaterial3D.new()
		smoke_material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smoke.material_override = smoke_material
		
		# Start at flame top
		smoke.position = Vector3(
			randf_range(-0.1, 0.1),
			torch_height * 0.5 + flame_base_height - 0.9,
			randf_range(-0.1, 0.1)
		)
		smoke_particles.append(smoke)

func _animate_flame(_delta: float):
	"""Animate flame flickering and movement"""
	if not flame_core or not flame_outer:
		return
		
	# Flicker flame size and position
	var flicker = sin(time_passed * flame_flicker_speed) * 0.5 + 0.5
	var height_variation = sin(time_passed * flame_flicker_speed * 1.3) * flame_height_variation
	
	# Animate core flame
	var core_scale = 1.0 + (flicker * 0.3)
	flame_core.scale = Vector3(core_scale, core_scale + height_variation, core_scale)
	
	# Animate outer flame (slightly different timing)
	var outer_flicker = sin(time_passed * flame_flicker_speed * 0.8) * 0.5 + 0.5
	var outer_scale = 1.0 + (outer_flicker * 0.2)
	flame_outer.scale = Vector3(outer_scale, outer_scale + height_variation * 0.7, outer_scale)
	
	# Subtle position sway
	var sway_x = sin(time_passed * 2.0) * 0.02
	var sway_z = cos(time_passed * 1.5) * 0.02
	flame_core.position.x = sway_x
	flame_core.position.z = sway_z
	flame_outer.position.x = sway_x * 0.8
	flame_outer.position.z = sway_z * 0.8

func _animate_embers(_delta: float):
	"""Animate floating embers around flame"""
	ember_timer += _delta
	
	for i in range(ember_particles.size()):
		if i >= ember_particles.size():
			break
			
		var ember = ember_particles[i]
		if not is_instance_valid(ember):
			continue
			
		# Move ember upward and slightly outward
		ember.position.y += _delta * randf_range(0.5, 1.0)
		ember.position.x += sin(time_passed + i) * _delta * 0.2
		ember.position.z += cos(time_passed + i) * _delta * 0.2
		
		# Fade ember as it rises
		var material = ember.material_override as StandardMaterial3D
		if material:
			var height_from_flame = ember.position.y - (torch_height * 0.5)
			var fade_factor = 1.0 - clamp(height_from_flame / 2.0, 0.0, 1.0)
			material.albedo_color.a = fade_factor * 0.8
		
		# Reset ember when it gets too high or faded
		if ember.position.y > torch_height + 2.0 or (material and material.albedo_color.a < 0.1):
			_reset_ember(ember, i)

func _animate_smoke(_delta: float):
	"""Animate smoke particles rising and fading"""
	for i in range(smoke_particles.size()):
		if i >= smoke_particles.size():
			break
			
		var smoke = smoke_particles[i]
		if not is_instance_valid(smoke):
			continue
			
		# Move smoke upward and spread out
		smoke.position.y += _delta * 0.3
		smoke.position.x += sin(time_passed * 0.5 + i) * _delta * 0.1
		smoke.position.z += cos(time_passed * 0.7 + i) * _delta * 0.1
		
		# Expand and fade smoke
		var age = smoke.position.y - (torch_height * 0.5 + flame_base_height)
		var scale_factor = 1.0 + age * 0.5
		smoke.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		var material = smoke.material_override as StandardMaterial3D
		if material:
			var fade_factor = 1.0 - clamp(age / 1.5, 0.0, 1.0)
			material.albedo_color.a = fade_factor * 0.3
		
		# Reset smoke when it's too high or faded
		if age > 1.5:
			smoke.position = Vector3(
				randf_range(-0.1, 0.1),
				torch_height * 0.5 + flame_base_height - 0.9,
				randf_range(-0.1, 0.1)
			)
			smoke.scale = Vector3.ONE

func _flicker_light(_delta: float):
	"""Add realistic light flickering"""
	if not torch_light:
		return
		
	# Flicker light intensity
	var flicker_factor = sin(time_passed * 4.0) * 0.2 + sin(time_passed * 7.0) * 0.1
	torch_light.light_energy = light_energy + (flicker_factor * 0.5)
	
	# Slightly vary light color temperature
	var color_variation = sin(time_passed * 3.0) * 0.05
	torch_light.light_color = Color(
		1.0,
		0.7 + color_variation,
		0.4 + color_variation * 0.5
	)

func _reset_ember(ember: MeshInstance3D, _index: int):
	"""Reset ember to flame base with random properties"""
	if not ember:
		return
		
	# Position near flame base
	ember.position = Vector3(
		randf_range(-0.15, 0.15),
		torch_height * 0.5 + randf_range(0.0, 0.2) - 0.9,
		randf_range(-0.15, 0.15)
	)
	
	# Reset material properties
	var material = ember.material_override as StandardMaterial3D
	if material:
		material.albedo_color.a = randf_range(0.6, 0.9)
	
	# Random scale
	var ember_scale = randf_range(0.8, 1.2)
	ember.scale = Vector3(ember_scale, ember_scale, ember_scale)

# Public methods for interaction
func set_flame_intensity(intensity: float):
	"""Adjust flame intensity (useful for different torch states)"""
	flame_intensity = intensity
	if flame_core and flame_core.material_override:
		var material = flame_core.material_override as StandardMaterial3D
		material.emission = Color(1.0, 0.6, 0.2) * flame_intensity * 2.0
	if flame_outer and flame_outer.material_override:
		var material = flame_outer.material_override as StandardMaterial3D
		material.emission = Color(1.0, 0.3, 0.1) * flame_intensity

func extinguish_torch():
	"""Gradually extinguish the torch"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(set_flame_intensity, flame_intensity, 0.0, 2.0)
	tween.tween_property(torch_light, "light_energy", 0.0, 2.0)
	tween.tween_callback(func(): print("🔥 Torch extinguished"))

func ignite_torch():
	"""Re-ignite the torch"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(set_flame_intensity, 0.0, 1.5, 1.0)
	tween.tween_property(torch_light, "light_energy", light_energy, 1.0)
	tween.tween_callback(func(): print("🔥 Torch ignited"))
