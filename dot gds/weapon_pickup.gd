# weapon_pickup.gd - Enhanced weapon pickup with better visuals
extends Area3D

static func safe_set_material(mesh_target: MeshInstance3D, material: Material) -> bool:
	if not mesh_target:
		return false
	if not material:
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

# Delays pickup for a short time (e.g., after spawning from physics)
func _create_pickup_delay_effect(delay: float) -> void:
	set_meta("pickup_disabled", true)
	await get_tree().create_timer(delay).timeout
	set_meta("pickup_disabled", false)

# Floating text and interaction
var floating_text: Label3D = null
var player_in_range: bool = false
var player: Node3D = null
var weapon_material: StandardMaterial3D
var time_alive: float = 0.0

# For composite weapons (multiple mesh parts)
var weapon_parts: Array[MeshInstance3D] = []

func _ready():
	# CRITICAL: Set up proper collision layers for weapon pickup Area3D
	collision_layer = 8  # Layer 4 (weapon pickups)
	collision_mask = 4   # Detect layer 3 (player) - binary 100 = 4
	
	# Connect signals properly (these are the correct signal names for Area3D)
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))
	
	# Continue with rest of setup
	add_to_group("weapon_pickup")
	
	if get_meta("from_physics", false):
		set_meta("pickup_disabled", true)
		_create_pickup_delay_effect(0.2)
	
	_find_player()
	_create_floating_text()
	call_deferred("_deferred_setup_visual")
	call_deferred("validate_scene_materials")
	_setup_collision_shape()
	call_deferred("_auto_assign_weapon_if_missing")

# NEW FUNCTION: Auto-assign weapon if none exists
func _auto_assign_weapon_if_missing():
	"""Automatically assign a weapon resource if none exists"""
	if not weapon_resource:
		print("⚠️ No weapon resource found, auto-assigning...")
		if WeaponPool and WeaponPool.has_method("get_random_weapon"):
			var auto_weapon = WeaponPool.get_random_weapon()
			if auto_weapon:
				set_weapon_resource(auto_weapon)
				print("✅ Auto-assigned weapon: ", auto_weapon.weapon_name)
			else:
				print("❌ WeaponPool returned null weapon!")
		else:
			# Fallback: create a basic sword
			print("⚠️ WeaponPool not available, creating fallback weapon...")
			_create_fallback_weapon()

# NEW FUNCTION: Create a basic weapon as fallback
func _create_fallback_weapon():
	"""Create a basic weapon resource as fallback"""
	var fallback_weapon = WeaponResource.new()
	fallback_weapon.weapon_name = "Iron Sword"
	fallback_weapon.weapon_type = WeaponResource.WeaponType.SWORD
	fallback_weapon.attack_damage = 25
	fallback_weapon.attack_range = 2.5
	fallback_weapon.attack_cooldown = 0.8
	set_weapon_resource(fallback_weapon)
	print("✅ Created fallback weapon: ", fallback_weapon.weapon_name)

func validate_scene_materials():
	var mesh_nodes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_nodes:
		if not mesh_node.material_override:
			print("⚠️ Found MeshInstance3D without material: ", mesh_node.name)
			var default_mat = StandardMaterial3D.new()
			default_mat.albedo_color = Color.WHITE
			mesh_node.material_override = default_mat

func _deferred_setup_visual():
	if weapon_resource:
		_setup_enhanced_visual()
	else:
		_create_default_sword_visual()

func _setup_enhanced_visual():
	"""Create enhanced weapon pickup visual"""
	# FIRST: Clear the original mesh to get rid of the white ball
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null

	if not weapon_resource:
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
			_create_enhanced_sword()
		int(WeaponResource.WeaponType.BOW):
			_create_simple_bow_visual()
		# int(WeaponResource.WeaponType.STAFF):
		# 	print("🗡️ _setup_enhanced_visual: Creating enhanced staff visual")
		# 	_create_enhanced_staff()
		int(WeaponResource.WeaponType.STAFF):
			_create_default_sword_visual()
		_:
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

	# Iron sword material
	var iron_material = StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.6, 0.6, 0.65) # iron gray
	iron_material.metallic = 0.85
	iron_material.roughness = 0.25
	iron_material.emission_enabled = false
	safe_set_material(sword_mesh_instance, iron_material)

	# Position and scale for pickup (tweak as needed for your mesh)
	sword_mesh_instance.position = Vector3(0, -4.9, 0) # Lowered from -4.5 to -4.9
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
	bow_mesh_instance.position = Vector3(0, -4.4, 0) # Lowered from -4.0 to -4.4
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
	ornate_top.position = Vector3(0, -4.6, 0)
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
	orb.position = Vector3(0, -4.45, 0)
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
	_clear_weapon_parts()
	_create_enhanced_sword()


func _create_default_visual():
	"""Create enhanced default pickup visual"""
	if not mesh_instance:
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

func _animate_staff_effects(_delta):
	"""Special animations for staff weapons"""
	# Animate floating runes
	for part in weapon_parts:
		if part.name.begins_with("Rune") or part.get_parent().name.contains("orb"):
			var float_offset = sin(time_alive * 3.0 + part.position.x * 10) * 0.02
			part.position.y += float_offset * _delta * 10
			
			# Rune rotation
			if part.material_override and part.material_override.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
				part.rotation_degrees.z += 45 * _delta

# Copilot: Create sphere collision shape for weapon pickup area
func _setup_collision_shape():
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
	if not collision_shape.shape or not collision_shape.shape is SphereShape3D:
		var sphere = SphereShape3D.new()
		sphere.radius = 1.5
		collision_shape.shape = sphere

# Copilot: Handle E key interaction for weapon pickup
func _input(event):
	if event.is_action_pressed("interaction") and player_in_range and not get_meta("pickup_disabled", false):
		_interact_with_weapon()

# Copilot: Handle player entering weapon pickup area
func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = true
		_update_interaction_text()
		if floating_text:
			floating_text.visible = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = false
		if floating_text:
			floating_text.visible = false

# Copilot: Create 3D weapon visual based on WeaponResource type
func _create_weapon_visual():
	if not weapon_resource:
		_create_default_sword_visual()
		return
	_clear_weapon_parts()
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			_create_enhanced_sword()
		int(WeaponResource.WeaponType.BOW):
			_create_simple_bow_visual()
		int(WeaponResource.WeaponType.STAFF):
			_create_enhanced_staff()
		_:
			_create_default_sword_visual()

# Copilot: Add floating rotation and bob animation to weapon mesh
# (Already handled in _process, but ensure all weapon_parts animate)
# ...existing code...

# Copilot: Handle weapon pickup and swap logic with WeaponManager
# (Already handled in _interact_with_weapon, but ensure logic is robust)
# ...existing code...

# Copilot: Create complete weapon pickup scene setup
# (Scene structure is Area3D root, CollisionShape3D, MeshInstance3D children)
# ...existing code...

# Copilot: Create diagnostic function for weapon pickup debugging
func _run_weapon_pickup_diagnostic():
	print("[WeaponPickup Diagnostic]")
	print("Collision Layer:", collision_layer)
	print("Collision Mask:", collision_mask)
	var found_player = get_tree().get_first_node_in_group("player")
	print("Player found:", found_player)
	var pickups = get_tree().get_nodes_in_group("weapon_pickup")
	print("Weapon pickups in scene:", pickups.size())
	for p in pickups:
		print("- Pickup:", p, "Resource:", p.weapon_resource if "weapon_resource" in p else "None")

# Copilot: Assign weapon resource and update pickup visuals
func set_weapon_resource(new_resource: WeaponResource):
	weapon_resource = new_resource
	if weapon_resource and "weapon_name" in weapon_resource:
		set_meta("weapon_name", weapon_resource.weapon_name)
	if is_inside_tree():
		call_deferred("_create_weapon_visual")
		if player_in_range:
			_update_interaction_text()

# Copilot: Add emission glow effect to weapon pickup materials
func _add_glow_effect():
	for part in weapon_parts:
		if part.material_override and part.material_override is StandardMaterial3D:
			var mat = part.material_override
			mat.emission_enabled = true
			match int(weapon_resource.weapon_type):
				int(WeaponResource.WeaponType.SWORD):
					mat.emission = Color(0.7, 0.85, 1.0) * glow_intensity
				int(WeaponResource.WeaponType.BOW):
					mat.emission = Color(0.3, 0.6, 0.2) * glow_intensity
				int(WeaponResource.WeaponType.STAFF):
					mat.emission = Color(0.4, 0.6, 1.0) * glow_intensity
				_:
					mat.emission = Color.WHITE * glow_intensity

# Copilot: Update the floating interaction text based on weapon_resource
func _update_interaction_text():
	if not floating_text:
		return
	if weapon_resource and weapon_resource.weapon_name != "":
		var weapon_name = weapon_resource.weapon_name
		floating_text.text = "Press E to Pick Up " + str(weapon_name)
	else:
		floating_text.text = "Press E to Pick Up"

# Debug function to inspect weapon resource and WeaponPool
func debug_weapon_resource():
	print("🔍 WEAPON PICKUP DEBUG:")
	print("  - weapon_resource exists: ", weapon_resource != null)
	if weapon_resource:
		print("  - weapon_name: '", weapon_resource.weapon_name, "'")
		print("  - weapon_type: ", weapon_resource.weapon_type)
		print("  - attack_damage: ", weapon_resource.attack_damage)
	else:
		print("  - NO WEAPON RESOURCE ASSIGNED!")
	
	# Test WeaponPool
	if WeaponPool:
		print("  - WeaponPool exists: ✅")
		var test_weapon = WeaponPool.get_random_weapon()
		if test_weapon:
			print("  - WeaponPool test weapon: '", test_weapon.weapon_name, "'")
		else:
			print("  - WeaponPool returned null!")
	else:
		print("  - WeaponPool missing: ❌")

# Create a test function to manually assign a weapon
func assign_test_weapon():
	print("🧪 Assigning test weapon...")
	if WeaponPool:
		var test_weapon = WeaponPool.get_random_weapon()
		if test_weapon:
			set_weapon_resource(test_weapon)
			print("✅ Test weapon assigned: ", test_weapon.weapon_name)
		else:
			print("❌ WeaponPool returned null weapon!")
	else:
		print("❌ WeaponPool not found!")

# Copilot: Implement weapon pickup interaction logic
func _interact_with_weapon():
	print("🗡️ WEAPON INTERACTION TRIGGERED")
	
	# Prevent pickup if already disabled
	if get_meta("pickup_disabled", false):
		print("❌ Pickup disabled, ignoring interaction")
		return
	
	if not weapon_resource:
		print("❌ No weapon resource assigned!")
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			print("❌ No player found!")
			return
	
	print("✅ Attempting weapon pickup: ", weapon_resource.weapon_name)
	
	# Check if player has pickup_weapon method
	if player.has_method("pickup_weapon"):
		player.pickup_weapon(weapon_resource)
		print("✅ Weapon given to player via pickup_weapon()")
	else:
		# Fallback: try to equip directly via WeaponManager
		if WeaponManager:
			# Copilot: Drop currently equipped weapon as a pickup if player has one
			if WeaponManager.get_current_weapon() != null:
				var old_weapon = WeaponManager.get_current_weapon()
				if old_weapon != weapon_resource:
					var pickup_scene = preload("res://Scenes/weapon_pickup.tscn")
					var dropped_pickup = pickup_scene.instantiate()
					if player.is_inside_tree() and dropped_pickup.is_inside_tree():
						# Safe to set global_position
						dropped_pickup.global_position = player.global_position + Vector3(1, 0, 0) # Offset to avoid overlap
					else:
						# Fallback: set position after adding to tree
						get_tree().current_scene.add_child(dropped_pickup)
						await get_tree().process_frame
						dropped_pickup.global_position = player.global_position + Vector3(1, 0, 0)
					dropped_pickup.set_weapon_resource(old_weapon)
					if not dropped_pickup.is_inside_tree():
						get_tree().current_scene.add_child(dropped_pickup)
			
			WeaponManager.equip_weapon(weapon_resource)
			print("✅ Weapon equipped via WeaponManager fallback")
		else:
			print("❌ No pickup method available!")
			return
	
	# Disable pickup and cleanup
	set_meta("pickup_disabled", true)
	visible = false
	if floating_text:
		floating_text.visible = false
	
	# Cleanup after short delay
	await get_tree().create_timer(0.2).timeout
	queue_free()

# Call this in your scene to test the pickup system
func test_pickup_system():
	print("🧪 TESTING WEAPON PICKUP SYSTEM")
	_run_weapon_pickup_diagnostic()
	
	# Test interaction if player is nearby
	var test_player = get_tree().get_first_node_in_group("player")
	if test_player and global_position.distance_to(test_player.global_position) < 3.0:
		print("🧪 Player nearby, testing interaction...")
		player_in_range = true
		_interact_with_weapon()
