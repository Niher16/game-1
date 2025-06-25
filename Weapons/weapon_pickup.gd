# weapon_pickup.gd - Enhanced weapon pickup with better visuals
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

# Preloaded mesh constants
const SWORD_MESH = preload("res://3d Models/Sword/broadsword.obj")
const BOW_MESH = preload("res://3d Models/Bow/bow_01.obj")

# Weapon resource assigned to this pickup
@export var weapon_resource: WeaponResource = null

# Enhanced visual settings
@export var glow_intensity: float = 1.5
@export var rotation_speed: float = 30.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

# References to scene nodes
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Floating text and interaction
var floating_text: Label3D = null
var player_in_range: bool = false
var player: Node3D = null
var weapon_material: StandardMaterial3D
var time_alive: float = 0.0

# For composite weapons (multiple mesh parts)
var weapon_parts: Array[MeshInstance3D] = []

func _ready():
	print("🗡️ Weapon Pickup Ready - weapon_resource: ", weapon_resource)
	if weapon_resource:
		print("🗡️ Weapon name: ", weapon_resource.weapon_name)
		print("🗡️ Weapon type: ", weapon_resource.weapon_type)
	else:
		print("❌ No weapon_resource assigned!")
	# Print scene node structure and mesh_instance existence
	print("🗡️ Node children: ", get_children())
	print("🗡️ mesh_instance exists: ", mesh_instance != null)
	print("🗡️ mesh_instance path: ", str(mesh_instance.get_path()) if mesh_instance else "None")
	
	print("🗡️ Enhanced Weapon Pickup: Setting up...")
	add_to_group("weapon_pickup")
	collision_layer = 4
	collision_mask = 1
	
	# Set pickup disabled initially if this came from physics
	if get_meta("from_physics", false):
		set_meta("pickup_disabled", true)
		_create_pickup_delay_effect(0.2)
	
	_find_player()
	_create_floating_text()
	# Defer visual setup to ensure scene is fully loaded
	call_deferred("_deferred_setup_visual")
	call_deferred("validate_scene_materials")

func validate_scene_materials():
	var mesh_nodes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		if not mesh_node.material_override:
			print("⚠️ Found MeshInstance3D without material: ", mesh_node.name)
			var default_mat = StandardMaterial3D.new()
			default_mat.albedo_color = Color.WHITE
			mesh_node.material_override = default_mat

func _deferred_setup_visual():
	print("🗡️ _deferred_setup_visual called")
	if weapon_resource:
		print("🗡️ _deferred_setup_visual: weapon_resource present, calling _setup_enhanced_visual")
		_setup_enhanced_visual()
	else:
		print("🗡️ _deferred_setup_visual: weapon_resource is null, calling _create_default_sword_visual")
		_create_default_sword_visual()

func _setup_enhanced_visual():
	print("🗡️ _setup_enhanced_visual called")
	"""Create enhanced weapon pickup visual"""
	# FIRST: Clear the original mesh to get rid of the white ball
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null

	if not weapon_resource:
		print("🗡️ _setup_enhanced_visual: weapon_resource is null, calling _create_default_sword_visual")
		_create_default_sword_visual()
		return

	# Clear any existing parts
	_clear_weapon_parts()

	# Debug: Print the actual weapon_type value and enum mapping
	print("🗡️ weapon_resource.weapon_type value: ", weapon_resource.weapon_type)
	print("🗡️ WeaponType.SWORD: ", int(WeaponResource.WeaponType.SWORD))
	print("🗡️ WeaponType.BOW: ", int(WeaponResource.WeaponType.BOW))
	print("🗡️ WeaponType.STAFF: ", int(WeaponResource.WeaponType.STAFF))

	# Use integer values for matching
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			print("🗡️ _setup_enhanced_visual: Creating enhanced sword visual")
			_create_enhanced_sword()
		int(WeaponResource.WeaponType.BOW):
			print("🗡️ _setup_enhanced_visual: Using simple bow visual")
			_create_simple_bow_visual()
		# int(WeaponResource.WeaponType.STAFF):
		# 	print("🗡️ _setup_enhanced_visual: Creating enhanced staff visual")
		# 	_create_enhanced_staff()
		int(WeaponResource.WeaponType.STAFF):
			print("🗡️ Staff pickup temporarily disabled!")
			_create_default_sword_visual()
		_:
			print("🗡️ _setup_enhanced_visual: Unknown type, calling _create_default_sword_visual")
			_create_default_sword_visual()

	# Create collision shape
	var collision = SphereShape3D.new()
	collision.radius = 0.8
	collision_shape.shape = collision


func _clear_weapon_parts():
	"""Clear existing weapon parts"""
	for part in weapon_parts:
		if is_instance_valid(part) and part != mesh_instance:  # Don't delete the scene's original mesh_instance
			part.queue_free()
	weapon_parts.clear()
	
	# Always clear the original mesh_instance content but keep the node
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null

func _create_enhanced_sword():
	"""Create a visually detailed sword pickup using a single imported mesh, with special effects for enchanted and shiny swords"""
	_clear_weapon_parts()
	# Create a MeshInstance3D for the broadsword
	var sword_mesh_instance = MeshInstance3D.new()
	# Use preloaded mesh constant
	sword_mesh_instance.mesh = SWORD_MESH

	# Default material (bluish, shiny)
	var sword_material = StandardMaterial3D.new()
	# Check weapon name for special visuals
	var sword_name = ""
	if weapon_resource and "weapon_name" in weapon_resource:
		sword_name = weapon_resource.weapon_name
	if sword_name.to_lower().find("enchanted") != -1:
		# Enchanted sword: magical color, strong emission, floating runes
		sword_material.albedo_color = Color(0.5, 0.7, 1.0)
		sword_material.metallic = 0.8
		sword_material.roughness = 0.1
		sword_material.emission_enabled = true
		sword_material.emission = Color(0.3, 0.7, 1.0) * glow_intensity
		sword_material.rim_enabled = true
		sword_material.rim = 0.8
		# Validate material before assignment
		if sword_material and sword_mesh_instance:
			safe_set_material(sword_mesh_instance, sword_material)
		else:
			print("❌ Sword material or mesh is null, creating fallback")
			var fallback = StandardMaterial3D.new()
			fallback.albedo_color = Color.SILVER
			safe_set_material(sword_mesh_instance, fallback)
		# Add magical floating runes
		_create_floating_runes(sword_mesh_instance)
	elif sword_name.to_lower().find("steel") != -1 or sword_name.to_lower().find("iron") != -1:
		# Steel/Iron sword: gold/silver, extra shiny
		sword_material.albedo_color = Color(0.9, 0.9, 0.7) # pale gold
		sword_material.metallic = 1.0
		sword_material.roughness = 0.03
		sword_material.emission_enabled = true
		sword_material.emission = Color(1.0, 0.95, 0.7) * 0.2
		sword_material.rim_enabled = true
		sword_material.rim = 0.9
		if sword_material and sword_mesh_instance:
			safe_set_material(sword_mesh_instance, sword_material)
		else:
			print("❌ Sword material or mesh is null, creating fallback")
			var fallback = StandardMaterial3D.new()
			fallback.albedo_color = Color.SILVER
			safe_set_material(sword_mesh_instance, fallback)
	else:
		# Default sword (bluish, shiny)
		sword_material.albedo_color = Color(0.85, 0.9, 1.0)
		sword_material.metallic = 1.0
		sword_material.roughness = 0.07
		sword_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		sword_material.emission_enabled = true
		sword_material.emission = Color(0.7, 0.85, 1.0) * glow_intensity * 0.25
		sword_material.rim_enabled = true
		sword_material.rim = 0.7
		if sword_material and sword_mesh_instance:
			safe_set_material(sword_mesh_instance, sword_material)
		else:
			print("❌ Sword material or mesh is null, creating fallback")
			var fallback = StandardMaterial3D.new()
			fallback.albedo_color = Color.SILVER
			safe_set_material(sword_mesh_instance, fallback)

	# Position and scale for pickup (tweak as needed for your mesh)
	sword_mesh_instance.position = Vector3(0, 0.5, 0)
	sword_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(sword_mesh_instance)
	weapon_parts.append(sword_mesh_instance)


func _create_simple_bow_visual():
	"""Create a bow pickup using the imported bow mesh"""
	_clear_weapon_parts()
	# Create a MeshInstance3D for the bow
	var bow_mesh_instance = MeshInstance3D.new()
	# Use preloaded mesh constant
	bow_mesh_instance.mesh = BOW_MESH
	# Optionally tweak material for glow, color, etc.
	var bow_material = StandardMaterial3D.new()
	bow_material.albedo_color = Color(0.7, 0.5, 0.3)
	bow_material.metallic = 0.2
	bow_material.roughness = 0.5
	bow_material.emission_enabled = true
	bow_material.emission = Color(0.3, 0.6, 0.2) * glow_intensity * 0.2
	# Validate material before assignment
	if bow_material and bow_mesh_instance:
		safe_set_material(bow_mesh_instance, bow_material)
	else:
		print("❌ Bow material or mesh is null, creating fallback")
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.7, 0.5, 0.3)
		safe_set_material(bow_mesh_instance, fallback)
	# Raise the bow even higher above the ground
	bow_mesh_instance.position = Vector3(0, 1.0, 0) # was 0.6
	bow_mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
	add_child(bow_mesh_instance)
	weapon_parts.append(bow_mesh_instance)


func _create_enhanced_staff():
	"""Create detailed staff pickup visual"""
	_clear_weapon_parts()
	# Main staff shaft
	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.025
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = 1.0
	shaft.mesh = shaft_mesh
	var shaft_material = StandardMaterial3D.new()
	shaft_material.albedo_color = Color(0.4, 0.25, 0.1)
	shaft_material.roughness = 0.8
	if shaft_material and shaft:
		safe_set_material(shaft, shaft_material)
	else:
		print("❌ Staff shaft material or mesh is null, creating fallback")
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.4, 0.25, 0.1)
		safe_set_material(shaft, fallback)
	add_child(shaft)
	weapon_parts.append(shaft)
	# Ornate top section
	var ornate_top = MeshInstance3D.new()
	var ornate_mesh = CylinderMesh.new()
	ornate_mesh.top_radius = 0.05
	ornate_mesh.bottom_radius = 0.03
	ornate_mesh.height = 0.15
	ornate_top.mesh = ornate_mesh
	ornate_top.position = Vector3(0, 0.4, 0)
	var ornate_material = StandardMaterial3D.new()
	ornate_material.albedo_color = Color(0.8, 0.6, 0.2)
	ornate_material.metallic = 0.9
	ornate_material.roughness = 0.2
	ornate_material.emission_enabled = true
	ornate_material.emission = Color(0.6, 0.4, 0.1) * 0.5
	if ornate_material and ornate_top:
		safe_set_material(ornate_top, ornate_material)
	else:
		print("❌ Ornate material or mesh is null, creating fallback")
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.8, 0.6, 0.2)
		safe_set_material(ornate_top, fallback)
	shaft.add_child(ornate_top)
	weapon_parts.append(ornate_top)
	# Crystal orb at top
	var orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.12
	orb_mesh.height = 0.15
	orb.mesh = orb_mesh
	orb.position = Vector3(0, 0.55, 0)
	var orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color(0.3, 0.5, 1.0, 0.8)
	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.emission_enabled = true
	orb_material.emission = Color(0.4, 0.6, 1.0) * glow_intensity
	orb_material.rim_enabled = true
	orb_material.rim = 0.8
	orb.material_override = orb_material
	shaft.add_child(orb)
	weapon_parts.append(orb)
	# Floating runes around the orb
	_create_floating_runes(orb)


func _create_floating_runes(parent: MeshInstance3D):
	"""Create floating magical runes around staff orb"""
	var rune_count = 4
	for i in range(rune_count):
		var rune = MeshInstance3D.new()
		var rune_mesh = BoxMesh.new()
		rune_mesh.size = Vector3(0.03, 0.03, 0.01)
		rune.mesh = rune_mesh
		
		# Position runes in circle around orb
		var angle = (i / float(rune_count)) * TAU
		var radius = 0.2
		rune.position = Vector3(
			cos(angle) * radius,
			sin(angle * 0.5) * 0.05,  # Slight vertical offset
			sin(angle) * radius
		)
		
		var rune_material = StandardMaterial3D.new()
		rune_material.albedo_color = Color(1.0, 0.8, 0.3)
		rune_material.emission_enabled = true
		rune_material.emission = Color(1.0, 0.8, 0.3) * 2.0
		rune_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		rune.material_override = rune_material
		
		parent.add_child(rune)
		weapon_parts.append(rune)

func _create_default_sword_visual():
	print("🗡️ _create_default_sword_visual called: Creating default sword visual")
	"""Create a default sword visual if weapon_resource is null"""
	_clear_weapon_parts()
	_create_enhanced_sword()


func _create_default_visual():
	"""Create enhanced default pickup visual"""
	if not mesh_instance:
		print("❌ mesh_instance is null, cannot create default visual")
		return
	var default_mesh = SphereMesh.new()
	default_mesh.radius = 0.25
	default_mesh.height = 0.35
	mesh_instance.mesh = default_mesh
	
	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.7, 0.7, 0.8)
	weapon_material.emission_enabled = true
	weapon_material.emission = Color.WHITE * 0.8
	weapon_material.rim_enabled = true
	weapon_material.rim = 0.5
	mesh_instance.material_override = weapon_material
	
	weapon_parts.append(mesh_instance)

func _create_floating_text():
	"""Create floating interaction text"""
	floating_text = Label3D.new()
	floating_text.name = "FloatingText"
	floating_text.text = "Press E to Pick Up"
	floating_text.position = Vector3(0, 1.5, 0)
	floating_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_text.no_depth_test = true
	floating_text.modulate = Color(1.0, 1.0, 0.4, 0.9)
	floating_text.outline_modulate = Color(0.2, 0.2, 0.0, 1.0)
	floating_text.font_size = 36
	floating_text.outline_size = 6
	floating_text.visible = false
	add_child(floating_text)

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	"""Handle enhanced animations"""
	time_alive += delta
	
	# Animate all weapon parts together
	var bob_offset = sin(time_alive * bob_speed) * bob_height
	var base_y_offset = 1.0 # Raise all weapon parts higher above the ground
	var rotation_y = rotation_speed * delta
	
	for part in weapon_parts:
		if is_instance_valid(part) and part.get_parent() == self:  # Only animate top-level parts
			part.rotation_degrees.y += rotation_y
			part.position.y = base_y_offset + bob_offset
	
	# Enhanced glow pulsing for magical weapons
	if weapon_resource and weapon_resource.weapon_type == WeaponResource.WeaponType.STAFF:
		_animate_staff_effects(delta)

func _animate_staff_effects(delta):
	"""Special animations for staff weapons"""
	# Animate floating runes
	for part in weapon_parts:
		if part.name.begins_with("Rune") or part.get_parent().name.contains("orb"):
			var float_offset = sin(time_alive * 3.0 + part.position.x * 10) * 0.02
			part.position.y += float_offset * delta * 10
			
			# Rune rotation
			if part.material_override and part.material_override.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
				part.rotation_degrees.z += 45 * delta

func _input(_event):
	if Input.is_action_just_pressed("interaction") and player_in_range and not get_meta("pickup_disabled", false):
		_interact_with_weapon()

func _on_area_entered(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = true
		_update_interaction_text()
		if floating_text:
			floating_text.visible = true
		print("🗡️ Player near weapon: ", weapon_resource.weapon_name if weapon_resource else "Unknown")

func _on_area_exited(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = false
		if floating_text:
			floating_text.visible = false

func _update_interaction_text():
	if not weapon_resource or not floating_text:
		return

	var weapon_name = weapon_resource.weapon_name
	var player_has_weapon = WeaponManager.is_weapon_equipped()
	
	if player_has_weapon:
		floating_text.text = "Press E to Swap for %s" % weapon_name
		floating_text.modulate = Color(0.8, 0.8, 1.0, 0.9)
	else:
		floating_text.text = "Press E to Pick Up %s" % weapon_name
		floating_text.modulate = Color(0.3, 1.0, 0.3, 0.9)

func _interact_with_weapon():
	if not weapon_resource:
		return
	
	print("🗡️ Interacting with weapon: ", weapon_resource.weapon_name)
	
	if WeaponManager.is_weapon_equipped():
		_swap_weapons()
	else:
		_pickup_weapon()

func _pickup_weapon():
	WeaponManager.equip_weapon(weapon_resource)
	print("🗡️ Picked up: ", weapon_resource.weapon_name)
	queue_free()

func _swap_weapons():
	var old_weapon = WeaponManager.get_current_weapon()
	WeaponManager.equip_weapon(weapon_resource)
	print("🗡️ Swapped to: ", weapon_resource.weapon_name)
	if old_weapon:
		set_weapon_resource(old_weapon)
		print("🗡️ Dropped: ", old_weapon.weapon_name)
	else:
		queue_free()

func set_weapon_resource(new_resource: WeaponResource):
	print("🗡️ set_weapon_resource called with: ", new_resource)
	weapon_resource = new_resource
	if weapon_resource and "weapon_name" in weapon_resource:
		set_meta("weapon_name", weapon_resource.weapon_name)
	# Always setup visual when resource is set, using deferred call for consistency
	if is_inside_tree():
		print("🗡️ Setting up visuals for weapon_resource: ", weapon_resource)
		call_deferred("_deferred_setup_visual")
		if player_in_range:
			_update_interaction_text()

func _create_pickup_delay_effect(delay_time: float):
	"""Create visual effect during pickup delay"""
	print("🗡️ Weapon pickup delay effect for ", delay_time, " seconds")
	# Dim the weapon during delay
	for part in weapon_parts:
		if is_instance_valid(part) and part.material_override:
			var material = part.material_override as StandardMaterial3D
			if material and material.emission_enabled:
				var tween = create_tween()
				tween.set_loops(int(delay_time * 2))
				var dim_emission = material.emission * 0.3
				var normal_emission = material.emission
				tween.tween_property(material, "emission", dim_emission, 0.25)
				tween.tween_property(material, "emission", normal_emission, 0.25)
