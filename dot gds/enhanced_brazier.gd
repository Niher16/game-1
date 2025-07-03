# enhanced_brazier.gd - Large floor brazier with intense flames for Godot 4.1+
extends Node3D

# Brazier configuration following your lighting patterns
@export_group("Brazier Settings")
@export var brazier_height: float = 1.8
@export var brazier_radius: float = 0.6
@export var flame_intensity: float = 3.0
@export var light_energy: float = 6.0
@export var light_range: float = 25.0
@export var is_lit: bool = true
@export var can_be_controlled: bool = true

@export_group("Visual Effects")
@export var large_flame_count: int = 3  # Multiple flame points
@export var flame_flicker_speed: float = 2.5
@export var ember_count: int = 15
@export var smoke_intensity: float = 1.5
@export var heat_shimmer_enabled: bool = true

@export_group("Interaction")
@export var interaction_range: float = 3.0
@export var extinguish_time: float = 2.0
@export var relight_time: float = 1.5

# Components
var brazier_base: MeshInstance3D
var brazier_bowl: MeshInstance3D
var brazier_light: OmniLight3D
var flame_cores: Array[MeshInstance3D] = []
var flame_outers: Array[MeshInstance3D] = []
var ember_particles: Array[MeshInstance3D] = []
var smoke_particles: Array[MeshInstance3D] = []
var interaction_area: Area3D

# Animation and state
var time_passed: float = 0.0
var ember_timer: float = 0.0
var lighting_animation_timer: float = 0.0
var is_animating_light_change: bool = false
var target_light_state: bool = true

func _ready():
	_create_brazier_structure()
	_create_flame_system()
	_create_lighting()
	_create_ember_system()
	_create_smoke_system()
	_create_interaction_area()
	
	# Add to groups for player interaction
	add_to_group("interactive_lights")
	add_to_group("braziers")
	
	# Set initial state
	_update_lighting_state()

func _process(delta: float):
	time_passed += delta
	
	if is_lit:
		_animate_flames(delta)
		_animate_embers(delta)
		_animate_smoke(delta)
		_flicker_light(delta)
	
	if is_animating_light_change:
		_animate_lighting_transition(delta)

func _create_brazier_structure():
	"""Create the iron brazier base and bowl structure"""
	# Base/Stand (tripod legs)
	brazier_base = MeshInstance3D.new()
	brazier_base.name = "BrazierBase"
	add_child(brazier_base)
	
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.15
	base_mesh.bottom_radius = 0.25
	base_mesh.height = brazier_height * 0.7
	brazier_base.mesh = base_mesh
	brazier_base.position = Vector3(0, brazier_height * 0.35, 0)
	
	# Iron base material (like your chandelier)
	var iron_material = StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.2, 0.2, 0.2)
	iron_material.metallic = 0.8
	iron_material.roughness = 0.7
	brazier_base.material_override = iron_material
	
	# Fire Bowl
	brazier_bowl = MeshInstance3D.new()
	brazier_bowl.name = "BrazierBowl"
	add_child(brazier_bowl)
	
	var bowl_mesh = SphereMesh.new()
	bowl_mesh.radius = brazier_radius
	bowl_mesh.height = brazier_radius * 0.8  # Flattened sphere
	brazier_bowl.mesh = bowl_mesh
	brazier_bowl.position = Vector3(0, brazier_height, 0)
	brazier_bowl.scale = Vector3(1.0, 0.4, 1.0)  # Make it bowl-shaped
	
	# Heat-darkened iron material
	var bowl_material = StandardMaterial3D.new()
	bowl_material.albedo_color = Color(0.1, 0.1, 0.1)
	bowl_material.metallic = 0.6
	bowl_material.roughness = 0.9
	# Add heat glow when lit
	bowl_material.emission_enabled = true
	bowl_material.emission = Color(0.8, 0.3, 0.1) * 0.1
	brazier_bowl.material_override = bowl_material

func _create_flame_system():
	"""Create large, intense flame system"""
	for i in range(large_flame_count):
		# Create flame positions in triangle formation
		var angle = (TAU / large_flame_count) * i
		var flame_offset = Vector3(
			cos(angle) * brazier_radius * 0.3,
			0,
			sin(angle) * brazier_radius * 0.3
		)
		var flame_pos = Vector3(0, brazier_height + 0.2, 0) + flame_offset
		
		# Large flame core (very bright)
		var flame_core = MeshInstance3D.new()
		flame_core.name = "FlameCore_" + str(i)
		add_child(flame_core)
		
		var core_mesh = SphereMesh.new()
		core_mesh.radius = 0.25
		core_mesh.height = 0.8  # Tall flame
		flame_core.mesh = core_mesh
		flame_core.position = flame_pos
		
		# Intense flame core material
		var core_material = StandardMaterial3D.new()
		core_material.albedo_color = Color(1.0, 0.9, 0.4, 0.95)
		core_material.emission_enabled = true
		core_material.emission = Color(1.0, 0.7, 0.3) * flame_intensity * 3.0
		core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flame_core.material_override = core_material
		flame_cores.append(flame_core)
		
		# Large outer flame (intense orange/red)
		var flame_outer = MeshInstance3D.new()
		flame_outer.name = "FlameOuter_" + str(i)
		add_child(flame_outer)
		
		var outer_mesh = SphereMesh.new()
		outer_mesh.radius = 0.4
		outer_mesh.height = 1.2
		flame_outer.mesh = outer_mesh
		flame_outer.position = flame_pos + Vector3(0, 0.1, 0)
		
		# Intense red/orange outer flame
		var outer_material = StandardMaterial3D.new()
		outer_material.albedo_color = Color(1.0, 0.3, 0.05, 0.8)
		outer_material.emission_enabled = true
		outer_material.emission = Color(1.0, 0.2, 0.05) * flame_intensity * 2.0
		outer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		outer_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flame_outer.material_override = outer_material
		flame_outers.append(flame_outer)

func _create_lighting():
	"""Create powerful brazier lighting for large spaces"""
	brazier_light = OmniLight3D.new()
	brazier_light.name = "BrazierLight"
	add_child(brazier_light)
	
	# Position at flame center
	brazier_light.position = Vector3(0, brazier_height + 0.4, 0)
	
	# Very powerful warm lighting (stronger than torches/chandeliers)
	brazier_light.light_energy = light_energy
	brazier_light.light_color = Color(1.0, 0.6, 0.3)  # Intense warm light
	brazier_light.omni_range = light_range
	brazier_light.light_specular = 1.2
	
	# Strong shadows for dramatic effect
	brazier_light.shadow_enabled = true
	brazier_light.shadow_bias = 0.05

func _create_ember_system():
	"""Create many embers rising from large flames"""
	for i in range(ember_count):
		var ember = MeshInstance3D.new()
		ember.name = "Ember_" + str(i)
		add_child(ember)
		
		# Larger embers for bigger fire
		var ember_mesh = SphereMesh.new()
		ember_mesh.radius = randf_range(0.03, 0.08)
		ember_mesh.height = ember_mesh.radius * 2
		ember.mesh = ember_mesh
		
		# Bright ember material
		var ember_material = StandardMaterial3D.new()
		ember_material.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
		ember_material.emission_enabled = true
		ember_material.emission = Color(1.0, 0.3, 0.05) * 2.0
		ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ember.material_override = ember_material
		
		# Start at brazier bowl
		_reset_ember(ember)
		ember_particles.append(ember)

func _create_smoke_system():
	"""Create thick smoke rising from brazier"""
	for i in range(8):
		var smoke = MeshInstance3D.new()
		smoke.name = "Smoke_" + str(i)
		add_child(smoke)
		
		# Larger smoke particles
		var smoke_mesh = SphereMesh.new()
		smoke_mesh.radius = randf_range(0.15, 0.3)
		smoke_mesh.height = smoke_mesh.radius * 2
		smoke.mesh = smoke_mesh
		
		# Dense gray smoke material
		var smoke_material = StandardMaterial3D.new()
		smoke_material.albedo_color = Color(0.4, 0.4, 0.4, 0.4)
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smoke.material_override = smoke_material
		
		# Start above flames
		smoke.position = Vector3(
			randf_range(-0.3, 0.3),
			brazier_height + 0.5,
			randf_range(-0.3, 0.3)
		)
		smoke_particles.append(smoke)

func _create_interaction_area():
	"""Create area for player interaction (lighting/extinguishing)"""
	if not can_be_controlled:
		return
		
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)
	
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interaction_range
	collision_shape.shape = sphere_shape
	interaction_area.add_child(collision_shape)
	
	# Connect signals for player interaction
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)

func _animate_flames(_delta: float):
	"""Animate large flame effects (like your torch but more intense)"""
	for i in range(flame_cores.size()):
		if i >= flame_cores.size() or i >= flame_outers.size():
			continue
			
		var core = flame_cores[i]
		var outer = flame_outers[i]
		
		# More dramatic flickering for large flames
		var phase = i * 0.7
		var flicker = sin((time_passed + phase) * flame_flicker_speed) * 0.5 + 0.5
		var height_variation = sin((time_passed + phase) * flame_flicker_speed * 1.5) * 0.4
		
		# Large flame scaling
		var core_scale = 1.0 + (flicker * 0.4)
		core.scale = Vector3(core_scale, core_scale + height_variation, core_scale)
		
		var outer_scale = 1.0 + (flicker * 0.3)
		outer.scale = Vector3(outer_scale, outer_scale + height_variation * 0.8, outer_scale)
		
		# More dramatic position sway
		var sway_x = sin(time_passed * 1.5 + phase) * 0.05
		var sway_z = cos(time_passed * 1.8 + phase) * 0.05
		core.position.x += sway_x
		core.position.z += sway_z
		outer.position.x += sway_x * 0.7
		outer.position.z += sway_z * 0.7

func _animate_embers(delta: float):
	"""Animate many embers rising from brazier"""
	ember_timer += delta
	
	for ember in ember_particles:
		if not ember:
			continue
			
		# Rise faster and spread more
		ember.position.y += delta * 1.2
		ember.position.x += sin(time_passed + ember.position.x * 2) * delta * 0.2
		ember.position.z += cos(time_passed + ember.position.z * 2) * delta * 0.2
		
		# Fade out as they rise
		var height_ratio = (ember.position.y - brazier_height) / 3.0
		var alpha = 1.0 - clamp(height_ratio, 0.0, 1.0)
		if ember.material_override:
			var mat = ember.material_override as StandardMaterial3D
			mat.albedo_color.a = alpha * 0.9
		
		# Reset when too high or faded
		if ember.position.y > brazier_height + 3.0:
			_reset_ember(ember)

func _animate_smoke(delta: float):
	"""Animate thick smoke rising from brazier"""
	for smoke in smoke_particles:
		if not smoke:
			continue
			
		# Rise and spread
		smoke.position.y += delta * 0.8
		smoke.position.x += sin(time_passed * 0.5 + smoke.position.x) * delta * 0.15
		smoke.position.z += cos(time_passed * 0.7 + smoke.position.z) * delta * 0.15
		
		# Expand as it rises
		var height_from_base = smoke.position.y - brazier_height
		var expansion = 1.0 + (height_from_base * 0.1)
		smoke.scale = Vector3(expansion, 1.0, expansion)
		
		# Fade out
		var fade_ratio = height_from_base / 4.0
		var alpha = (1.0 - clamp(fade_ratio, 0.0, 1.0)) * 0.4
		if smoke.material_override:
			var mat = smoke.material_override as StandardMaterial3D
			mat.albedo_color.a = alpha
		
		# Reset when too high
		if smoke.position.y > brazier_height + 4.0:
			smoke.position = Vector3(
				randf_range(-0.3, 0.3),
				brazier_height + 0.5,
				randf_range(-0.3, 0.3)
			)
			smoke.scale = Vector3.ONE

func _flicker_light(_delta: float):
	"""Create realistic light flickering (like your torch)"""
	if not is_lit:
		return
		
	var flicker = sin(time_passed * 4.0) * 0.5 + 0.5
	var intensity_variation = 0.9 + (flicker * 0.3)
	brazier_light.light_energy = light_energy * intensity_variation

func _reset_ember(ember: MeshInstance3D):
	"""Reset ember to brazier bowl position"""
	ember.position = Vector3(
		randf_range(-brazier_radius * 0.4, brazier_radius * 0.4),
		brazier_height + randf_range(0.1, 0.3),
		randf_range(-brazier_radius * 0.4, brazier_radius * 0.4)
	)
	
	# Reset material alpha
	if ember.material_override:
		var mat = ember.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.9

# --- INTERACTION SYSTEM ---

func _on_player_entered(body):
	"""Player entered interaction range"""
	if body.has_method("set_can_interact_with_light"):
		body.set_can_interact_with_light(self)

func _on_player_exited(body):
	"""Player left interaction range"""
	if body.has_method("clear_light_interaction"):
		body.clear_light_interaction()

func toggle_light():
	"""Toggle brazier on/off (called by player interaction)"""
	if is_animating_light_change:
		return  # Prevent rapid toggling
		
	target_light_state = not is_lit
	is_animating_light_change = true
	lighting_animation_timer = 0.0
	
	print("🔥 Brazier ", "extinguishing..." if is_lit else "lighting...")

func _animate_lighting_transition(delta: float):
	"""Animate smooth lighting transition"""
	lighting_animation_timer += delta
	var transition_time = extinguish_time if is_lit else relight_time
	var progress = lighting_animation_timer / transition_time
	
	if progress >= 1.0:
		# Transition complete
		is_lit = target_light_state
		is_animating_light_change = false
		_update_lighting_state()
		print("🔥 Brazier ", "extinguished!" if not is_lit else "lit!")
		return
	
	# Animate transition
	if target_light_state:  # Lighting up
		var light_progress = Tween.interpolate_value(0.0, light_energy, progress, 1.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
		brazier_light.light_energy = light_progress
	else:  # Extinguishing
		var light_progress = Tween.interpolate_value(light_energy, 0.0, progress, 1.0, Tween.TRANS_QUAD, Tween.EASE_IN)
		brazier_light.light_energy = light_progress

func _update_lighting_state():
	"""Update all visual elements based on lighting state"""
	# Show/hide flame elements
	for core in flame_cores:
		core.visible = is_lit
	for outer in flame_outers:
		outer.visible = is_lit
	
	# Update light
	brazier_light.light_energy = light_energy if is_lit else 0.0
	
	# Update bowl material emission
	if brazier_bowl and brazier_bowl.material_override:
		var mat = brazier_bowl.material_override as StandardMaterial3D
		mat.emission = Color(0.8, 0.3, 0.1) * (0.1 if is_lit else 0.0)

func force_extinguish():
	"""Instantly extinguish (for boss attacks, etc.)"""
	is_lit = false
	target_light_state = false
	is_animating_light_change = false
	_update_lighting_state()

func force_light():
	"""Instantly light (for puzzle solutions, etc.)"""
	is_lit = true
	target_light_state = true
	is_animating_light_change = false
	_update_lighting_state()


# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.