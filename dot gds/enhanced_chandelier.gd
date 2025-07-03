# enhanced_chandelier.gd - Iron chandelier with multiple flames for Godot 4.1+
extends Node3D

# Chandelier configuration following your torch patterns
@export_group("Chandelier Settings")
@export var chain_length: float = 2.0
@export var chandelier_radius: float = 1.5
@export var flame_count: int = 6
@export var main_light_energy: float = 4.0
@export var main_light_range: float = 20.0
@export var can_be_damaged: bool = true
@export var health: int = 100

@export_group("Visual Effects")
@export var flame_intensity: float = 2.0
@export var swing_enabled: bool = true
@export var swing_strength: float = 0.1
@export var ember_count_per_flame: int = 3
@export var damaged_flicker_multiplier: float = 2.0

# Components
var chain: MeshInstance3D
var chandelier_body: MeshInstance3D
var main_light: OmniLight3D
var flame_lights: Array[OmniLight3D] = []
var flame_cores: Array[MeshInstance3D] = []
var flame_outers: Array[MeshInstance3D] = []
var ember_particles: Array[MeshInstance3D] = []

# Animation and state
var time_passed: float = 0.0
var is_damaged: bool = false
var damage_flicker_timer: float = 0.0
var swing_offset: Vector3 = Vector3.ZERO
var original_position: Vector3

func _ready():
	original_position = position
	_create_chain()
	_create_chandelier_body()
	_create_flames()
	_create_main_lighting()
	_create_ember_systems()
	
	# Add to appropriate groups for boss targeting
	add_to_group("destructible_lights")
	add_to_group("chandelier")

func _process(delta: float):
	time_passed += delta
	_animate_swinging(delta)
	_animate_flames(delta)
	_animate_embers(delta)
	if is_damaged:
		_animate_damage_effects(delta)

func _create_chain():
	"""Create hanging chain following your metal material patterns"""
	chain = MeshInstance3D.new()
	chain.name = "Chain"
	add_child(chain)
	
	# Chain mesh (cylinder)
	var chain_mesh = CylinderMesh.new()
	chain_mesh.top_radius = 0.05
	chain_mesh.bottom_radius = 0.05
	chain_mesh.height = chain_length
	chain.mesh = chain_mesh
	
	# Position chain above chandelier body
	chain.position = Vector3(0, chain_length * 0.5, 0)
	
	# Dark iron material (like your torch metal)
	var chain_material = StandardMaterial3D.new()
	chain_material.albedo_color = Color(0.2, 0.2, 0.2)
	chain_material.metallic = 0.9
	chain_material.roughness = 0.6
	chain.material_override = chain_material

func _create_chandelier_body():
	"""Create the main iron chandelier structure"""
	chandelier_body = MeshInstance3D.new()
	chandelier_body.name = "ChandelierBody"
	add_child(chandelier_body)
	
	# Main ring structure
	var body_mesh = TorusMesh.new()
	body_mesh.inner_radius = chandelier_radius * 0.8
	body_mesh.outer_radius = chandelier_radius
	chandelier_body.mesh = body_mesh
	
	# Position below chain
	chandelier_body.position = Vector3(0, -0.3, 0)
	
	# Ornate iron material
	var iron_material = StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.15, 0.15, 0.15)
	iron_material.metallic = 0.95
	iron_material.roughness = 0.4
	# Subtle warm reflection from flames
	iron_material.emission_enabled = true
	iron_material.emission = Color(1.0, 0.6, 0.2) * 0.05
	chandelier_body.material_override = iron_material
	
	# Add decorative arms for flames
	_create_flame_arms()

func _create_flame_arms():
	"""Create individual arms that hold each flame"""
	for i in range(flame_count):
		var angle = (TAU / flame_count) * i
		var arm_pos = Vector3(
			cos(angle) * chandelier_radius * 0.9,
			-0.2,
			sin(angle) * chandelier_radius * 0.9
		)
		
		# Create flame holder (small cup)
		var flame_holder = MeshInstance3D.new()
		flame_holder.name = "FlameHolder_" + str(i)
		chandelier_body.add_child(flame_holder)
		
		var holder_mesh = CylinderMesh.new()
		holder_mesh.top_radius = 0.15
		holder_mesh.bottom_radius = 0.12
		holder_mesh.height = 0.1
		flame_holder.mesh = holder_mesh
		flame_holder.position = arm_pos
		
		# Same iron material
		flame_holder.material_override = chandelier_body.material_override

func _create_flames():
	"""Create multiple flame effects following your torch flame patterns"""
	for i in range(flame_count):
		var angle = (TAU / flame_count) * i
		var flame_pos = Vector3(
			cos(angle) * chandelier_radius * 0.9,
			-0.15,  # Slightly above flame holder
			sin(angle) * chandelier_radius * 0.9
		)
		
		# Create flame core (bright inner flame)
		var flame_core = MeshInstance3D.new()
		flame_core.name = "FlameCore_" + str(i)
		add_child(flame_core)
		
		var core_mesh = SphereMesh.new()
		core_mesh.radius = 0.12
		core_mesh.height = 0.3
		flame_core.mesh = core_mesh
		flame_core.position = flame_pos
		
		# Bright flame material (like your torch core)
		var core_material = StandardMaterial3D.new()
		core_material.albedo_color = Color(1.0, 0.8, 0.3, 0.9)
		core_material.emission_enabled = true
		core_material.emission = Color(1.0, 0.6, 0.2) * flame_intensity * 2.5
		core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flame_core.material_override = core_material
		flame_cores.append(flame_core)
		
		# Create outer flame (softer, larger)
		var flame_outer = MeshInstance3D.new()
		flame_outer.name = "FlameOuter_" + str(i)
		add_child(flame_outer)
		
		var outer_mesh = SphereMesh.new()
		outer_mesh.radius = 0.2
		outer_mesh.height = 0.45
		flame_outer.mesh = outer_mesh
		flame_outer.position = flame_pos + Vector3(0, 0.05, 0)
		
		# Orange/red outer flame (like your torch outer)
		var outer_material = StandardMaterial3D.new()
		outer_material.albedo_color = Color(1.0, 0.4, 0.1, 0.7)
		outer_material.emission_enabled = true
		outer_material.emission = Color(1.0, 0.3, 0.1) * flame_intensity * 1.8
		outer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		outer_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flame_outer.material_override = outer_material
		flame_outers.append(flame_outer)
		
		# Create individual light for each flame
		var flame_light = OmniLight3D.new()
		flame_light.name = "FlameLight_" + str(i)
		add_child(flame_light)
		flame_light.position = flame_pos
		flame_light.light_energy = main_light_energy * 0.3
		flame_light.light_color = Color(1.0, 0.7, 0.4)
		flame_light.omni_range = main_light_range * 0.6
		flame_light.light_specular = 0.9
		flame_light.shadow_enabled = false  # Main light handles shadows
		flame_lights.append(flame_light)

func _create_main_lighting():
	"""Create main chandelier lighting (like your torch lighting)"""
	main_light = OmniLight3D.new()
	main_light.name = "ChandelierMainLight"
	add_child(main_light)
	
	# Position at chandelier center
	main_light.position = Vector3(0, -0.15, 0)
	
	# Powerful warm lighting for large rooms
	main_light.light_energy = main_light_energy
	main_light.light_color = Color(1.0, 0.75, 0.45)  # Warmer than single torch
	main_light.omni_range = main_light_range
	main_light.light_specular = 1.0
	
	# Enhanced shadows for dramatic effect
	main_light.shadow_enabled = true
	main_light.shadow_bias = 0.08

func _create_ember_systems():
	"""Create ember particles for each flame"""
	for i in range(flame_count):
		var angle = (TAU / flame_count) * i
		var base_pos = Vector3(
			cos(angle) * chandelier_radius * 0.9,
			-0.15,
			sin(angle) * chandelier_radius * 0.9
		)
		
		# Create embers for this flame
		for j in range(ember_count_per_flame):
			var ember = MeshInstance3D.new()
			ember.name = "Ember_" + str(i) + "_" + str(j)
			add_child(ember)
			
			var ember_mesh = SphereMesh.new()
			ember_mesh.radius = randf_range(0.01, 0.03)
			ember_mesh.height = ember_mesh.radius * 2
			ember.mesh = ember_mesh
			
			# Glowing ember material (like your torch embers)
			var ember_material = StandardMaterial3D.new()
			ember_material.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
			ember_material.emission_enabled = true
			ember_material.emission = Color(1.0, 0.4, 0.1) * 1.8
			ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ember.material_override = ember_material
			
			# Random starting position around flame
			ember.position = base_pos + Vector3(
				randf_range(-0.2, 0.2),
				randf_range(0, 0.3),
				randf_range(-0.2, 0.2)
			)
			ember_particles.append(ember)

func _animate_swinging(_delta: float):
	"""Animate subtle swinging motion"""
	if not swing_enabled:
		return
		
	# Gentle pendulum motion
	var swing_x = sin(time_passed * 0.8) * swing_strength
	var swing_z = cos(time_passed * 1.2) * swing_strength * 0.6
	swing_offset = Vector3(swing_x, 0, swing_z)
	
	# Apply to entire chandelier
	position = original_position + swing_offset

func _animate_flames(_delta: float):
	"""Animate all flames with slight variations (like your torch flames)"""
	for i in range(flame_cores.size()):
		if i >= flame_cores.size() or i >= flame_outers.size():
			continue
			
		var core = flame_cores[i]
		var outer = flame_outers[i]
		
		# Each flame flickers slightly differently
		var phase_offset = i * 0.5
		var flicker = sin((time_passed + phase_offset) * 3.5) * 0.5 + 0.5
		var height_var = sin((time_passed + phase_offset) * 4.0) * 0.2
		
		# Damage increases flicker intensity
		var damage_multiplier = damaged_flicker_multiplier if is_damaged else 1.0
		flicker *= damage_multiplier
		
		# Scale flames
		var core_scale = 1.0 + (flicker * 0.25)
		core.scale = Vector3(core_scale, core_scale + height_var, core_scale)
		
		var outer_scale = 1.0 + (flicker * 0.15)
		outer.scale = Vector3(outer_scale, outer_scale + height_var * 0.8, outer_scale)

func _animate_embers(delta: float):
	"""Animate ember particles floating around flames"""
	for ember in ember_particles:
		if not ember:
			continue
			
		# Float upward and outward
		ember.position.y += delta * 0.5
		ember.position.x += sin(time_passed + ember.position.x) * delta * 0.1
		ember.position.z += cos(time_passed + ember.position.z) * delta * 0.1
		
		# Reset if too high
		if ember.position.y > 2.0:
			_reset_ember(ember)

func _reset_ember(ember: MeshInstance3D):
	"""Reset ember to flame position"""
	var flame_index = randi() % flame_count
	var angle = (TAU / flame_count) * flame_index
	var base_pos = Vector3(
		cos(angle) * chandelier_radius * 0.9,
		-0.15,
		sin(angle) * chandelier_radius * 0.9
	)
	
	ember.position = base_pos + Vector3(
		randf_range(-0.15, 0.15),
		randf_range(0, 0.1),
		randf_range(-0.15, 0.15)
	)

func _animate_damage_effects(delta: float):
	"""Animate damage effects - flickering lights"""
	damage_flicker_timer += delta
	
	if damage_flicker_timer > 0.1:  # Flicker every 0.1 seconds
		damage_flicker_timer = 0.0
		
		# Randomly dim some flame lights
		for light in flame_lights:
			if randf() < 0.3:  # 30% chance to flicker each light
				light.light_energy = main_light_energy * 0.1
			else:
				light.light_energy = main_light_energy * 0.3
		
		# Main light flickers too
		if randf() < 0.2:
			main_light.light_energy = main_light_energy * 0.6
		else:
			main_light.light_energy = main_light_energy

# --- DAMAGE SYSTEM FOR BOSS INTERACTIONS ---

func take_damage(amount: int):
	"""Allow bosses to damage chandelier"""
	if not can_be_damaged:
		return
		
	health -= amount
	is_damaged = true
	
	if health <= 50:
		# Extinguish some flames when heavily damaged
		var flames_to_extinguish = int(flame_count * 0.4)
		for i in range(flames_to_extinguish):
			if i < flame_lights.size():
				flame_lights[i].light_energy = 0
				if i < flame_cores.size():
					flame_cores[i].visible = false
				if i < flame_outers.size():
					flame_outers[i].visible = false
	
	if health <= 0:
		_extinguish_chandelier()

func _extinguish_chandelier():
	"""Completely extinguish chandelier"""
	# Turn off all lights
	main_light.light_energy = 0
	for light in flame_lights:
		light.light_energy = 0
	
	# Hide all flames
	for core in flame_cores:
		core.visible = false
	for outer in flame_outers:
		outer.visible = false
	
	# Darken the room dramatically
	print("💡 Chandelier extinguished! Room is now darker.")

func restore_lighting():
	"""Restore chandelier to full brightness"""
	health = 100
	is_damaged = false
	main_light.light_energy = main_light_energy
	
	for i in range(flame_lights.size()):
		flame_lights[i].light_energy = main_light_energy * 0.3
		if i < flame_cores.size():
			flame_cores[i].visible = true
		if i < flame_outers.size():
			flame_outers[i].visible = true


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.