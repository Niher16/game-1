extends CharacterBody3D
class_name Ally
signal ally_died

# Main ally controller that coordinates all components
# Export stats for easy tweaking in editor
@export_group("Ally Stats")
@export var max_health := 80
@export var speed := 3.5
@export var attack_damage := 20
@export var detection_range := 8.0

# Component references
@onready var health_component: AllyHealth = $HealthComponent
@onready var movement_component: AllyMovement = $MovementComponent
@onready var combat_component: AllyCombat = $CombatComponent
@onready var ai_component: AllyAI = $AIComponent

# Visual references
@onready var mesh_instance := $MeshInstance3D
@onready var left_hand_anchor := $LeftHandAnchor
@onready var right_hand_anchor := $RightHandAnchor
@onready var weapon_animation_player: AnimationPlayer = $WeaponAnimationPlayer

# Foot animation references - no strict typing to avoid crashes
var left_foot
var right_foot
var left_foot_original_pos: Vector3
var right_foot_original_pos: Vector3
var animation_time: float = 0.0
# Simple body animation variables
var body_node
var body_original_pos: Vector3
var body_waddle_time: float = 0.0

var player_ref: CharacterBody3D

# Knockback system
var knockback_velocity := Vector3.ZERO
var knockback_timer := 0.0
var knockback_duration := 0.4
var is_being_knocked_back := false

# Default ally color for flash restorataion
const DEFAULT_ALLY_COLOR = Color(0.9, 0.7, 0.6)  # Default skin tone

var last_valid_position: Vector3

# Ally modes
enum Mode { ATTACK = 1, PASSIVE }
var mode: Mode = Mode.ATTACK

var current_weapon: WeaponResource = null

func _ready():
	add_to_group("allies")
	_setup_components()
	_ensure_hands_visible()
	_find_player()
	if ai_component:
		ai_component.set_mode(mode)
	# Connect to attack_started signal to reset animation state
	if combat_component:
		combat_component.attack_started.connect(_on_ally_attack_started)
	# Connect health component death signal
	if health_component:
		health_component.health_depleted.connect(_on_health_depleted)
	# Initialize body animation after movement setup
	if movement_component:
		movement_component.initialize_body_animation()
	# 🔧 FIXED: Initialize last valid position
	last_valid_position = global_position
	# --- Ally UI and Name ---
	# Name assignment is now handled by AllyAI component in its setup()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				mode = Mode.ATTACK
				if ai_component:
					ai_component.set_mode(mode)
				print("Ally mode: ATTACK")
			KEY_2:
				mode = Mode.PASSIVE
				if ai_component:
					ai_component.set_mode(mode)
				print("Ally mode: PASSIVE")

func _setup_components() -> void:
	# Initialize each component with needed references
	health_component.setup(self, max_health)
	movement_component.setup(self, speed)
	combat_component.setup(self, attack_damage, detection_range)
	ai_component.setup(self)
	health_component.ally_died.connect(_on_ally_died)
	_create_character_appearance()
	# Setup foot references after character appearance is created
	await _setup_foot_references()
	# Make hands visible by default
	_ensure_hands_visible()
	# 🔧 FIXED: Configure collision layers properly
	collision_layer = 1 << 3  # Layer 4 (Ally)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 4) | (1 << 3)  # Collide with World, Walls, Player, Boss, Ally

func _create_character_appearance():
	# Generate random character appearance with varied skin tones
	var config = CharacterGenerator.generate_random_character_config()
	# Don't override skin_tone - let it use the random one from generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	print("[DEBUG] Called create_player_appearance for ", self.name, " in ally.gd")
	print("[DEBUG] Config used: ", config)
	# --- Debug: Log assigned skin tone ---
	var skin_tone = config.get("skin_tone", null)
	if skin_tone != null:
		print("🎨 Assigned skin tone: ", skin_tone)
	else:
		print("⚠️ Skin tone not found in config")

func _setup_foot_references() -> void:
	# Wait multiple frames to ensure nodes are fully created
	await get_tree().process_frame
	await get_tree().process_frame

	# Look for feet by name (they might have numbers appended like LeftFoot2, RightFoot2)
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")
	
	# If not found, look for numbered versions
	if not left_foot:
		for child in get_children():
			if child is MeshInstance3D and child.name.begins_with("LeftFoot"):
				left_foot = child
				break
	
	if not right_foot:
		for child in get_children():
			if child is MeshInstance3D and child.name.begins_with("RightFoot"):
				right_foot = child
				break

	if left_foot and right_foot:
		left_foot_original_pos = left_foot.position
		right_foot_original_pos = right_foot.position
	else:
		print("❌ Could not find both feet")
		if left_foot:
			print("   - Found LeftFoot: ", left_foot.name)
		if right_foot:
			print("   - Found RightFoot: ", right_foot.name)
	# Find body node (MeshInstance3D with 'Body' in name)
	body_node = null
	var mesh_children = []
	for child in get_children():
		if child is MeshInstance3D:
			mesh_children.append(child)
	# Try to find by 'Body', 'Torso', 'Chest'
	# Use 'body_name' to avoid shadowing base class property
	for body_name in ["Body", "Torso", "Chest"]:
		for child in mesh_children:
			if body_name in child.name:
				body_node = child
				body_original_pos = body_node.position
				break
		if body_node:
			break
	# Fallback: use mesh_instance or first MeshInstance3D
	if not body_node:
		if mesh_instance:
			body_node = mesh_instance
			body_original_pos = body_node.position
		elif mesh_children.size() > 0:
			body_node = mesh_children[0]
			body_original_pos = body_node.position
	if not body_node:
		print("❌ Could not find body node")

func _find_player():
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		ai_component.set_player_target(player_ref)

func _prevent_wall_clipping():
	"""Prevent allies from being pushed through walls - similar to enemy system"""
	var terrain = get_tree().get_first_node_in_group("terrain")
	var map_size = Vector2(60, 60)
	if terrain and "map_size" in terrain:
		map_size = terrain.map_size
	var grid_x = int((global_position.x / 2.0) + (map_size.x / 2))
	var grid_y = int((global_position.z / 2.0) + (map_size.y / 2))
	var is_valid = terrain._is_valid_pos(grid_x, grid_y) if terrain and terrain.has_method("_is_valid_pos") else true
	if is_valid:
		last_valid_position = global_position
	else:
		# Try to find a valid nearby position
		var try_offsets = [
			Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1),
			Vector3(1,0,1), Vector3(-1,0,1), Vector3(1,0,-1), Vector3(-1,0,-1),
			Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2), Vector3(0,0,-2)
		]
		var found = false
		for offset in try_offsets:
			if found:
				break
			for dist in [0.5, 1.0, 1.5, 2.0]:
				var test_pos = global_position + offset.normalized() * dist
				var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
				var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
				if terrain and terrain.has_method("_is_valid_pos") and terrain._is_valid_pos(test_grid_x, test_grid_y):
					global_position = test_pos
					last_valid_position = test_pos
					found = true
					break
		if not found:
			# Last resort: return to last known valid position
			global_position = last_valid_position
		# Stop movement when hitting walls
		velocity.x = 0
		velocity.z = 0
		knockback_velocity = Vector3.ZERO
	# Prevent falling through floor
	if global_position.y < 0.8:
		global_position.y = 0.8
		velocity.y = max(0, velocity.y)

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	# Prevent being pushed into the ground
	if is_on_floor() and velocity.y < 0:
		velocity.y = 0
	# Apply knockback if active
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		# Decay knockback
		var decay = knockback_timer / knockback_duration
		knockback_velocity.x *= decay
		knockback_velocity.z *= decay
		is_being_knocked_back = true
		if knockback_timer <= 0.0:
			knockback_velocity = Vector3.ZERO
			is_being_knocked_back = false
	# 🔧 FIXED: Apply movement with proper collision detection
	move_and_slide()
	# 🔧 FIXED: Prevent wall clipping after movement
	_prevent_wall_clipping()
	# Animate feet based on movement (with safety checks)
	animation_time += delta
	if left_foot and right_foot and left_foot is MeshInstance3D and right_foot is MeshInstance3D:
		CharacterAppearanceManager.animate_feet_walk(
			left_foot, right_foot, 
			left_foot_original_pos, right_foot_original_pos,
			animation_time, velocity, delta
		)
	elif animation_time > 1.0:  # Only try to find feet after 1 second
		# Try to find feet again if they weren't found initially
		if not left_foot:
			left_foot = get_node_or_null("LeftFoot")
			if left_foot and left_foot is MeshInstance3D:
				left_foot_original_pos = left_foot.position
		if not right_foot:
			right_foot = get_node_or_null("RightFoot")
			if right_foot and right_foot is MeshInstance3D:
				right_foot_original_pos = right_foot.position
				print("🦶 Found RightFoot late!")
	# Very subtle sway and bob (no idle reset)
	if body_node and velocity.length() > 0.1:
		body_waddle_time += delta * 5.0
		var sway = sin(body_waddle_time) * 0.025  # Very subtle left-right movement
		var bob = sin(body_waddle_time * 2.0) * 0.06  # Very subtle up-down bobbing
		var forward_lean = sin(body_waddle_time * 0.5) * 0.01  # Minimal lean
		body_node.position = body_original_pos + Vector3(sway, bob, forward_lean)

func take_damage(amount: int, _source = null):
	if health_component:
		health_component.take_damage(amount, _source)
		_flash_red()
	else:
		# fallback: just flash and show damage
		if get_tree().get_first_node_in_group("damage_numbers"):
			get_tree().get_first_node_in_group("damage_numbers").show_damage(amount, self, "massive")
		_flash_red()



	if health_component:
		health_component.take_damage(amount, _source)

func _on_health_depleted():
	ally_died.emit()

func _on_ally_died():
	print("💀 Ally died!")
	# Disable collision and hide
	collision_layer = 0
	collision_mask = 0
	mesh_instance.visible = false
	# Clean up after delay
	get_tree().create_timer(1.0).timeout.connect(queue_free)

# Helper to ensure hands are always visible
func _ensure_hands_visible():
	# Make sure ally hands are visible
	var left_hand = left_hand_anchor.get_node_or_null("LeftHand")
	var right_hand = right_hand_anchor.get_node_or_null("RightHand")
	
	if left_hand:
		left_hand.visible = true
	else:
		print("⚠️ LeftHand not found for ally")
	
	if right_hand:
		right_hand.visible = true
	else:
		print("⚠️ RightHand not found for ally")

# Flash the ally red briefly when taking damage
func _flash_red():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	if not mesh_instance.material_override:
		return
	mesh_instance.material_override.albedo_color = Color(1,0,0)
	# Use modern Godot 4.1 approach with create_timer
	get_tree().create_timer(0.5).timeout.connect(func():
		if mesh_instance and is_instance_valid(mesh_instance) and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = DEFAULT_ALLY_COLOR
	)


func _on_body_entered(body):
	if body.is_in_group("enemies"):
		# Use MCP server or local logic to apply damage
		if has_node("/root/MCPServer"):
			# Example: send a message to MCP server (pseudo-code, adapt as needed)
			var mcp = get_node("/root/MCPServer")
			mcp.request_ally_take_damage(self, body.attack_damage)
		else:
			take_damage(body.attack_damage, body)

func apply_knockback_from_attacker(attacker):
	if not attacker or not attacker.has_method("get_global_position"):
		return
	var direction = global_position - attacker.global_position
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		knockback_velocity = direction * 8.0
		knockback_timer = knockback_duration
		is_being_knocked_back = true

# Add function for safe knockback
func apply_knockback(force: Vector3, duration: float = 0.4):
	"""Apply knockback with wall collision prevention"""
	var knockback_dir = Vector3(force.x, 0, force.z).normalized()
	# Check if knockback would push into wall
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_is_valid_pos"):
		var map_size = Vector2(60, 60)
		if "map_size" in terrain:
			map_size = terrain.map_size
		var test_pos = global_position + knockback_dir * 1.5
		var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
		var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
		# If knockback would hit wall, reduce force or redirect
		if not terrain._is_valid_pos(test_grid_x, test_grid_y):
			force *= 0.3  # Reduce knockback force near walls
			# Try perpendicular directions
			var perpendicular = Vector3(-knockback_dir.z, 0, knockback_dir.x)
			test_pos = global_position + perpendicular * 1.0
			test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
			test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
			if terrain._is_valid_pos(test_grid_x, test_grid_y):
				force = perpendicular * force.length() * 0.5
	knockback_velocity = force
	knockback_timer = duration
	is_being_knocked_back = true

func equip_weapon(weapon_resource: WeaponResource) -> void:
	current_weapon = weapon_resource
	if combat_component:
		combat_component.equip_weapon(weapon_resource)
	# Attach weapon mesh to right hand (as child of hand mesh)
	if right_hand_anchor:
		var right_hand = right_hand_anchor.get_node_or_null("RightHand")
		if not right_hand:
			print("⚠️ RightHand mesh not found! Weapon will not be visible.")
			return
		for child in right_hand.get_children():
			if child is MeshInstance3D and child.name.begins_with("WeaponMesh"):
				right_hand.remove_child(child)
		if weapon_resource and weapon_resource.visual_scene_path != "":
			var mesh_resource = load(weapon_resource.visual_scene_path)
			if mesh_resource:
				var weapon_mesh_instance = MeshInstance3D.new()
				weapon_mesh_instance.mesh = mesh_resource
				weapon_mesh_instance.name = "WeaponMesh"
				# Adjust transform for weapon type
				match weapon_resource.weapon_type:
					WeaponResource.WeaponType.SWORD:
						weapon_mesh_instance.rotation_degrees = Vector3(0, 180, 90)
						weapon_mesh_instance.position = Vector3(0, 0, 0)
					WeaponResource.WeaponType.BOW:
						weapon_mesh_instance.rotation_degrees = Vector3(0, 90, 0)
						weapon_mesh_instance.position = Vector3(0, 0, 0)
					_:
						weapon_mesh_instance.rotation_degrees = Vector3.ZERO
						weapon_mesh_instance.position = Vector3.ZERO
				right_hand.add_child(weapon_mesh_instance)

# Call this when the ally attacks
func play_weapon_attack_animation():
	if current_weapon and weapon_animation_player:
		var animation_name = ""
		match current_weapon.weapon_type:
			WeaponResource.WeaponType.SWORD:
				animation_name = "sword_slash"
			WeaponResource.WeaponType.BOW:
				animation_name = "Bow"
			WeaponResource.WeaponType.STAFF:
				animation_name = "staff_cast"
			_:
				animation_name = "punch"
		if weapon_animation_player.has_animation(animation_name):
			weapon_animation_player.play(animation_name)
		else:
			weapon_animation_player.play("punch")

func _on_ally_attack_started():
	# Reset animation state so ally can attack again
	if weapon_animation_player:
		weapon_animation_player.stop()
