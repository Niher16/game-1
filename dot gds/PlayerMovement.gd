extends Node
class_name PlayerMovement

@export var can_move: bool = true # Godot 4.1+ best practice: allows player.gd to enable/disable movement safely

# --- Material Safety Utilities ---
static func ensure_mesh_has_material(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance or not mesh_instance.mesh:
		return false
	if mesh_instance.mesh.get_surface_count() == 0:
		push_warning("🚨 Mesh has no surfaces - skipping material operations")
		return false
	if not mesh_instance.get_active_material(0):
		var default_material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, default_material)
	return true

static func safe_get_material(mesh_instance: MeshInstance3D) -> Material:
	"""Safely get material with null check - prevents material parameter errors"""
	if not mesh_instance:
		return null
	if not mesh_instance.mesh:
		return null
	var material = mesh_instance.get_active_material(0)
	if not material:
		# Create default material if none exists
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	return material

static func check_material_safely(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance or not mesh_instance.mesh:
		return false
	var material = mesh_instance.get_active_material(0)
	return material != null

# Player state enum for robust state management
enum PlayerState {
	IDLE,
	MOVING,
	ATTACKING,
	DASHING,
	KNOCKED_BACK,
	DEAD
}

# Movement direction enum for better animation control
enum MovementDirection {
	NONE,
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT,
	DIAGONAL_FL,  # Forward-Left
	DIAGONAL_FR,  # Forward-Right
	DIAGONAL_BL,  # Backward-Left
	DIAGONAL_BR   # Backward-Right
}

# Movement-related variables
var current_dash_charges := 1
var last_dash_time := 0.0
var is_dashing := false
var is_attacking := false
var knockback_velocity := Vector3.ZERO
var knockback_timer := 0.0
var is_being_knocked_back := false
var state := PlayerState.IDLE
var current_movement_direction := MovementDirection.NONE
var previous_movement_direction := MovementDirection.NONE

# Reference to player
var player: CharacterBody3D

# Walking animation variables
var walk_cycle_time := 0.0
var step_cycle_speed := 1.0
var personality_offset := 0.0
var is_hands_idle := true
var hand_animation_time := 0.0

# Idle transition system
var idle_transition_active := false
var idle_transition_time := 0.0
var idle_transition_duration := 0.4
var idle_transition_start := {}

# Animation node references and original positions
var left_hand_node: Node3D = null
var right_hand_node: Node3D = null
var left_foot_node: Node3D = null
var right_foot_node: Node3D = null
var body_node: Node3D = null

var left_hand_origin: Vector3 = Vector3.ZERO
var right_hand_origin: Vector3 = Vector3.ZERO
var left_foot_origin: Vector3 = Vector3.ZERO
var right_foot_origin: Vector3 = Vector3.ZERO
var body_origin: Vector3 = Vector3.ZERO
var body_origin_rotation: Vector3 = Vector3.ZERO

# Smooth interpolation variables for better animation
var current_body_lean := Vector3.ZERO
var target_body_lean := Vector3.ZERO
var current_body_sway := Vector3.ZERO
var target_body_sway := Vector3.ZERO
var interpolation_speed := 8.0

# Enhanced animation parameters
var body_lean_strength := 0.15
var body_sway_strength := 0.08
var hand_swing_strength := 0.3
var foot_step_strength := 0.18
var side_step_modifier := 1.4

var is_punch_animating := false

# Signals
signal dash_charges_changed(current_charges: int, max_charges: int)
signal walk_animation_update(speed: float, exaggeration: float)
signal movement_state_changed(is_moving: bool)
signal dash_ended()
signal knockback_started()
signal knockback_ended()
signal hand_animation_update(left_pos: Vector3, right_pos: Vector3, left_rot: Vector3, right_rot: Vector3)
signal foot_animation_update(left_pos: Vector3, right_pos: Vector3)
signal body_animation_update(body_pos: Vector3, body_rot: Vector3)
signal animation_state_changed(is_idle: bool)

# Add these variables at class level
var using_controller: bool = false
var controller_deadzone: float = 0.2

func _ready():
	randomize()
	await get_tree().process_frame
	current_dash_charges = get_safe_max_dash_charges()

# Easing functions for cartoony animation
func _ease_in_out_cubic(t: float) -> float:
	var _sign = 1.0
	if t < 0.0:
		_sign = -1.0
		t = -t
	if t < 0.5:
		return _sign * 4.0 * t * t * t
	else:
		return _sign * (1.0 - pow(-2.0 * t + 2.0, 3) / 2.0)

func _ease_out_back(t: float, s: float = 1.70158) -> float:
	var _sign = 1.0
	if t < 0.0:
		_sign = -1.0
		t = -t
	t = t - 1.0
	return _sign * (t * t * ((s + 1.0) * t + s) + 1.0)

func _ease_in_out_sine(t: float) -> float:
	return -(cos(PI * t) - 1.0) / 2.0

func initialize(player_ref: CharacterBody3D):
	player = player_ref
	# Set up camera reference
	player.camera = player.get_viewport().get_camera_3d()
	if not player.camera:
		var cameras = player.get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			player.camera = cameras[0]
	
	# Reset movement state
	last_dash_time = 0.0
	is_dashing = false
	is_attacking = false
	knockback_velocity = Vector3.ZERO
	knockback_timer = 0.0
	is_being_knocked_back = false
	state = PlayerState.IDLE
	current_movement_direction = MovementDirection.NONE
	previous_movement_direction = MovementDirection.NONE
	
	initialize_animations()

func initialize_animations():
	# Store a random personality offset for organic animation
	personality_offset = randf_range(-0.1, 0.1)

	# Debug: Print all children of player to see what's available
	print("🔍 Player children: ", player.get_children().map(func(c): return c.name))

	# Get limb node references
	left_hand_node = player.get_node_or_null("LeftHandAnchor/LeftHand")
	right_hand_node = player.get_node_or_null("RightHandAnchor/RightHand")
	left_foot_node = player.get_node_or_null("LeftFoot")
	right_foot_node = player.get_node_or_null("RightFoot")
	body_node = player.get_node_or_null("MeshInstance3D")
	
	# If feet not found, schedule a re-check after character creation
	if not left_foot_node or not right_foot_node:
		print("🦶 Feet not found yet - will re-check after character creation")
		_schedule_foot_recheck()

	# Try alternative paths if direct ones fail
	if not left_foot_node:
		left_foot_node = _find_node_recursive(player, "LeftFoot")
		if left_foot_node:
			print("🔍 Found LeftFoot via recursive search: ", left_foot_node.get_path())
	if not right_foot_node:
		right_foot_node = _find_node_recursive(player, "RightFoot")
		if right_foot_node:
			print("🔍 Found RightFoot via recursive search: ", right_foot_node.get_path())

	# Store original positions and rotations
	left_hand_origin = left_hand_node.position if left_hand_node else Vector3.ZERO
	right_hand_origin = right_hand_node.position if right_hand_node else Vector3.ZERO
	left_foot_origin = left_foot_node.position if left_foot_node else Vector3.ZERO
	right_foot_origin = right_foot_node.position if right_foot_node else Vector3.ZERO
	
	if body_node:
		body_origin = body_node.position
		body_origin_rotation = body_node.rotation_degrees
	
	# Initialize interpolation targets
	current_body_lean = Vector3.ZERO
	target_body_lean = Vector3.ZERO
	current_body_sway = Vector3.ZERO
	target_body_sway = Vector3.ZERO

	# Debug output
	var missing = []
	if not left_hand_node: missing.append("LeftHand")
	if not right_hand_node: missing.append("RightHand")
	if not left_foot_node: missing.append("LeftFoot")
	if not right_foot_node: missing.append("RightFoot")
	if not body_node: missing.append("MeshInstance3D (Body)")
	
	if missing.size() == 0:
		print("✅ All animation nodes found and positioned")
	else:
		print("⚠️ Missing animation nodes: ", missing)
	
	# 🦶 Extra foot debugging
	if left_foot_node and right_foot_node:
		print("🦶 FEET FOUND! Left: ", left_foot_node.get_path(), " Right: ", right_foot_node.get_path())
		print("🦶 Foot origins - Left: ", left_foot_origin, " Right: ", right_foot_origin)
	else:
		print("❌ FEET NOT FOUND! This is why foot animation isn't working!")
		if not left_foot_node:
			print("   - Missing LeftFoot node")
		if not right_foot_node:
			print("   - Missing RightFoot node")
	
	print("📍 Animation origins captured - Body: ", body_origin, ", Hands: [", left_hand_origin, ", ", right_hand_origin, "], Feet: [", left_foot_origin, ", ", right_foot_origin, "]")

func reinitialize_feet():
	"""Call this after character appearance is created to find the feet"""
	print("🦶 Reinitializing feet references...")
	left_foot_node = player.get_node_or_null("LeftFoot")
	right_foot_node = player.get_node_or_null("RightFoot")
	
	if left_foot_node and right_foot_node:
		left_foot_origin = left_foot_node.position
		right_foot_origin = right_foot_node.position
		print("✅ Feet reinitialized! Left: ", left_foot_node.get_path(), " Right: ", right_foot_node.get_path())
		print("🦶 Foot origins - Left: ", left_foot_origin, " Right: ", right_foot_origin)
	else:
		print("❌ Still can't find feet after reinitialization")
		if not left_foot_node:
			print("   - Missing LeftFoot")
		if not right_foot_node:
			print("   - Missing RightFoot")

func _schedule_foot_recheck():
	# Check for feet multiple times with delays to catch them after character creation
	get_tree().create_timer(0.1).timeout.connect(_recheck_feet)
	get_tree().create_timer(0.3).timeout.connect(_recheck_feet)  
	get_tree().create_timer(0.5).timeout.connect(_recheck_feet)

func _recheck_feet():
	if left_foot_node and right_foot_node:
		return  # Already found them
		
	print("🔍 Re-checking for feet...")
	left_foot_node = player.get_node_or_null("LeftFoot")
	right_foot_node = player.get_node_or_null("RightFoot")
	
	if left_foot_node and right_foot_node:
		left_foot_origin = left_foot_node.position
		right_foot_origin = right_foot_node.position
		print("🦶 SUCCESS! Found feet after recheck - Left: ", left_foot_node.get_path(), " Right: ", right_foot_node.get_path())
		print("🦶 Foot origins - Left: ", left_foot_origin, " Right: ", right_foot_origin)
	else:
		print("❌ Still no feet found in recheck")

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	return null

func get_movement_direction_type(input_dir: Vector3, facing_dir: Vector3) -> MovementDirection:
	if input_dir.length() < 0.1:
		return MovementDirection.NONE
	
	var input_normalized = input_dir.normalized()
	var facing_normalized = facing_dir.normalized()
	
	var forward_dot = input_normalized.dot(facing_normalized)
	var cross = facing_normalized.cross(input_normalized)
	var side_dot = cross.y
	
	var forward_threshold = 0.7
	var side_threshold = 0.7
	
	if abs(forward_dot) > forward_threshold:
		if forward_dot > 0:
			return MovementDirection.FORWARD
		else:
			return MovementDirection.BACKWARD
	elif abs(side_dot) > side_threshold:
		if side_dot > 0:
			return MovementDirection.LEFT
		else:
			return MovementDirection.RIGHT
	else:
		# Diagonal movement
		if forward_dot > 0:
			if side_dot > 0:
				return MovementDirection.DIAGONAL_FL
			else:
				return MovementDirection.DIAGONAL_FR
		else:
			if side_dot > 0:
				return MovementDirection.DIAGONAL_BL
			else:
				return MovementDirection.DIAGONAL_BR

func handle_movement_and_dash(delta):
	if Input.is_action_just_pressed("dash") and can_dash():
		perform_dash()
		return
	if is_dashing or is_attacking or is_being_knocked_back:
		apply_gravity(delta)
		player.move_and_slide()
		return
	# Use camera-relative movement
	var direction = get_camera_relative_movement()
	if direction.length() > 0:
		direction = direction.normalized()
	if not player or not player.stats_component:
		push_error("PlayerMovement: Missing player or stats_component reference!")
		return
	
	var move_speed = direction.length() * player.stats_component.get_speed()
	var is_moving = direction.length() > player.MOVEMENT_THRESHOLD
	
	# Update movement direction for animation
	previous_movement_direction = current_movement_direction
	if is_moving:
		var facing_direction = get_facing_direction()
		current_movement_direction = get_movement_direction_type(direction, facing_direction)
	else:
		current_movement_direction = MovementDirection.NONE
	
	if is_moving:
		move_player(direction)
		
		# Enhanced animation with direction awareness
		var anim_speed = clamp(move_speed / player.stats_component.get_speed() * 2.0, 1.0, 3.5)
		var exaggeration = clamp(move_speed / player.stats_component.get_speed() * 1.5, 1.0, 2.5)
		
		# Modify animation based on movement direction
		match current_movement_direction:
			MovementDirection.LEFT, MovementDirection.RIGHT:
				anim_speed *= side_step_modifier
				exaggeration *= side_step_modifier
		
		step_cycle_speed = anim_speed
		walk_cycle_time += delta * step_cycle_speed
		
		_update_walking_animations(delta, direction)
		_update_body_walking_animation(delta, direction)
		
		walk_animation_update.emit(anim_speed, exaggeration)
		
		if state != PlayerState.MOVING:
			state = PlayerState.MOVING
			movement_state_changed.emit(true)
			animation_state_changed.emit(false)
	else:
		apply_friction(delta)
		_update_idle_animations(delta)
		
		if state != PlayerState.IDLE:
			state = PlayerState.IDLE
			movement_state_changed.emit(false)
			animation_state_changed.emit(true)
			_start_idle_transition()
	
	apply_gravity(delta)
	player.move_and_slide()

func _start_idle_transition():
	idle_transition_active = true
	idle_transition_time = 0.0
	# Capture current positions as transition start
	if left_hand_node:
		idle_transition_start["left_hand"] = left_hand_node.position
	if right_hand_node:
		idle_transition_start["right_hand"] = right_hand_node.position
	# DON'T capture feet - let CharacterAppearanceManager handle them
	if body_node:
		idle_transition_start["body_pos"] = body_node.position
		idle_transition_start["body_rot"] = body_node.rotation_degrees

func _update_idle_animations(delta: float):
	var t = idle_transition_time / idle_transition_duration
	t = clamp(t, 0, 1)
	var ease_t = _ease_in_out_cubic(t)

	if idle_transition_active:
		idle_transition_time += delta
		if t >= 1.0:
			idle_transition_active = false
			# Reset animation phases for idle
			walk_cycle_time = 0.0
			hand_animation_time = 0.0
			current_body_lean = Vector3.ZERO
			target_body_lean = Vector3.ZERO
			current_body_sway = Vector3.ZERO
			target_body_sway = Vector3.ZERO

		# Interpolate hands only
		if left_hand_node:
			left_hand_node.position = idle_transition_start["left_hand"].lerp(left_hand_origin, ease_t)
		if right_hand_node:
			right_hand_node.position = idle_transition_start["right_hand"].lerp(right_hand_origin, ease_t)
		# DON'T touch feet - CharacterAppearanceManager handles them
		# Interpolate body
		if body_node:
			body_node.position = idle_transition_start["body_pos"].lerp(body_origin, ease_t)
			body_node.rotation_degrees = idle_transition_start["body_rot"].lerp(body_origin_rotation, ease_t)
	else:
		# After transition, ensure hands and body are at rest
		if left_hand_node:
			left_hand_node.position = left_hand_origin
		if right_hand_node:
			right_hand_node.position = right_hand_origin
		# DON'T reset feet - let CharacterAppearanceManager handle idle foot position
		if body_node:
			body_node.position = body_origin
			body_node.rotation_degrees = body_origin_rotation
	
	# 🦶 Handle feet during idle - keep them at origin
	if left_foot_node and right_foot_node:
		left_foot_node.position = left_foot_origin
		right_foot_node.position = right_foot_origin

func _update_body_walking_animation(delta: float, input_direction: Vector3):
	if not body_node:
		return
	
	# Calculate body lean based on movement direction
	var lean_intensity = input_direction.length() * body_lean_strength
	
	match current_movement_direction:
		MovementDirection.FORWARD:
			target_body_lean = Vector3(0, 0, lean_intensity * 0.5)
		MovementDirection.BACKWARD:
			target_body_lean = Vector3(0, 0, -lean_intensity * 0.7)
		MovementDirection.LEFT:
			target_body_lean = Vector3(0, lean_intensity * 1.2, 0)
		MovementDirection.RIGHT:
			target_body_lean = Vector3(0, -lean_intensity * 1.2, 0)
		MovementDirection.DIAGONAL_FL:
			target_body_lean = Vector3(0, lean_intensity * 0.6, lean_intensity * 0.3)
		MovementDirection.DIAGONAL_FR:
			target_body_lean = Vector3(0, -lean_intensity * 0.6, lean_intensity * 0.3)
		MovementDirection.DIAGONAL_BL:
			target_body_lean = Vector3(0, lean_intensity * 0.6, -lean_intensity * 0.3)
		MovementDirection.DIAGONAL_BR:
			target_body_lean = Vector3(0, -lean_intensity * 0.6, -lean_intensity * 0.3)
		_:
			target_body_lean = Vector3.ZERO
	
	# Body sway during walking cycle
	var sway_phase = walk_cycle_time + personality_offset
	var vertical_bob = sin(sway_phase * 2.0) * body_sway_strength * 0.5
	var horizontal_sway = sin(sway_phase) * body_sway_strength * 0.3
	
	# Side-stepping gets more pronounced sway
	if current_movement_direction == MovementDirection.LEFT or current_movement_direction == MovementDirection.RIGHT:
		horizontal_sway *= side_step_modifier
		vertical_bob *= 1.3
	
	target_body_sway = Vector3(horizontal_sway, vertical_bob, 0)
	
	# Smooth interpolation
	current_body_lean = current_body_lean.lerp(target_body_lean, interpolation_speed * delta)
	current_body_sway = current_body_sway.lerp(target_body_sway, interpolation_speed * delta)
	
	# Apply to body node
	var final_body_pos = body_origin + current_body_sway
	var final_body_rot = body_origin_rotation + current_body_lean
	
	body_node.position = final_body_pos
	body_node.rotation_degrees = final_body_rot
	
	body_animation_update.emit(final_body_pos, final_body_rot)

func _update_walking_animations(delta: float, input_direction: Vector3):
	if is_punch_animating:
		return
	
	# Advance walk cycle time based on movement speed and step cycle speed
	var move_speed = input_direction.length() * player.stats_component.get_speed()
	step_cycle_speed = max(4.0, move_speed / max(1.0, player.stats_component.get_speed()) * 5.0)
	walk_cycle_time += delta * step_cycle_speed * 2.0
	
	# Keep walk_cycle_time in [0, TAU]
	if walk_cycle_time > TAU:
		walk_cycle_time -= TAU

	# Direction-aware hand and foot animation
	var facing_direction = get_facing_direction()
	var movement_dot = 0.0
	if input_direction.length() > 0.01:
		movement_dot = input_direction.normalized().dot(facing_direction.normalized())
	
	# Enhanced hand animations based on movement direction
	var hand_phase = walk_cycle_time + personality_offset
	var foot_phase = hand_phase + PI
	
	# Adjust hand swing based on movement direction
	var hand_swing_modifier = hand_swing_strength
	var hand_lift_modifier = 1.0
	var hand_diag_blend = 0.0
	var hand_diag_offset = 0.0
	var hand_diag_phase = 0.0
	
	match current_movement_direction:
		MovementDirection.LEFT, MovementDirection.RIGHT:
			hand_swing_modifier *= side_step_modifier
			hand_lift_modifier *= 1.2
		MovementDirection.BACKWARD:
			hand_swing_modifier *= 0.7
		MovementDirection.DIAGONAL_FL, MovementDirection.DIAGONAL_FR, MovementDirection.DIAGONAL_BL, MovementDirection.DIAGONAL_BR:
			hand_diag_blend = 0.5
			hand_diag_offset = 0.18 if current_movement_direction in [MovementDirection.DIAGONAL_FL, MovementDirection.DIAGONAL_BL] else -0.18
			hand_swing_modifier *= 1.08
			hand_lift_modifier *= 1.1
			hand_diag_phase = 0.35

	# Calculate enhanced hand movements
	var hand_swing_forward = _ease_in_out_cubic(sin(hand_phase)) * hand_swing_modifier
	var hand_swing_side = _ease_in_out_cubic(cos(hand_phase + hand_diag_phase)) * hand_swing_modifier * 0.7
	var hand_swing = hand_swing_forward
	if hand_diag_blend > 0.0:
		hand_swing = lerp(hand_swing_forward, hand_swing_side, hand_diag_blend)
	var hand_lift = _ease_out_back(sin(hand_phase + PI/2)) * 0.07 * hand_lift_modifier
	
	var left_hand_pos = null
	var right_hand_pos = null
	if left_hand_origin != Vector3.ZERO:
		left_hand_pos = left_hand_origin + Vector3(-hand_swing + hand_diag_offset, hand_lift, 0)
	if right_hand_origin != Vector3.ZERO:
		right_hand_pos = right_hand_origin + Vector3(hand_swing + hand_diag_offset, -hand_lift, 0)

	var left_hand_rot = Vector3(0, 0, -hand_swing * 2.0)
	var right_hand_rot = Vector3(0, 0, hand_swing * 2.0)

	if left_hand_pos != null and right_hand_pos != null:
		hand_animation_update.emit(left_hand_pos, right_hand_pos, left_hand_rot, right_hand_rot)

	# Enhanced foot animations with crossed feet and diagonal blending
	var foot_direction_multiplier = 1.0
	var foot_swing_modifier = foot_step_strength
	var cross_step_offset = 0.0
	var is_side_stepping = false
	var is_diagonal = false
	
	match current_movement_direction:
		MovementDirection.FORWARD:
			foot_direction_multiplier = -1.0
		MovementDirection.BACKWARD:
			foot_direction_multiplier = 1.0
			foot_swing_modifier *= 0.8
		MovementDirection.LEFT:
			foot_direction_multiplier = 0.2
			foot_swing_modifier *= side_step_modifier
			cross_step_offset = 0.08
			is_side_stepping = true
		MovementDirection.RIGHT:
			foot_direction_multiplier = 0.2
			foot_swing_modifier *= side_step_modifier
			cross_step_offset = -0.08
			is_side_stepping = true
		MovementDirection.DIAGONAL_FL, MovementDirection.DIAGONAL_FR:
			foot_direction_multiplier = -0.7
			cross_step_offset = 0.15 if current_movement_direction == MovementDirection.DIAGONAL_FL else -0.15
			is_diagonal = true
		MovementDirection.DIAGONAL_BL, MovementDirection.DIAGONAL_BR:
			foot_direction_multiplier = 0.7
			cross_step_offset = 0.15 if current_movement_direction == MovementDirection.DIAGONAL_BL else -0.15
			is_diagonal = true
		_:
			foot_direction_multiplier = -1.0 if movement_dot >= 0 else 1.0

	var left_foot_swing = _ease_in_out_cubic(sin(foot_phase)) * foot_swing_modifier
	var right_foot_swing = _ease_in_out_cubic(sin(foot_phase + PI)) * foot_swing_modifier
	var left_foot_lift = max(0, _ease_out_back(sin(foot_phase + PI/2))) * 0.12
	var right_foot_lift = max(0, _ease_out_back(sin(foot_phase + PI + PI/2))) * 0.12

	var left_foot_pos = null
	var right_foot_pos = null
	
	if left_foot_origin != Vector3.ZERO and right_foot_origin != Vector3.ZERO:
		if is_side_stepping:
			# CROSSED FEET ANIMATION for side-stepping!
			var cross_multiplier = sin(foot_phase) * cross_step_offset
			var cross_lift_multiplier = abs(sin(foot_phase)) * 0.08
			left_foot_pos = left_foot_origin + Vector3(
				cross_multiplier,
				left_foot_lift + cross_lift_multiplier,
				left_foot_swing * foot_direction_multiplier
			)
			right_foot_pos = right_foot_origin + Vector3(
				-cross_multiplier,
				right_foot_lift + cross_lift_multiplier,
				right_foot_swing * foot_direction_multiplier
			)
		elif is_diagonal:
			# Diagonal: blend between forward and side
			var diag_cross = sin(foot_phase) * cross_step_offset
			var diag_lift = abs(sin(foot_phase)) * 0.05
			left_foot_pos = left_foot_origin + Vector3(
				diag_cross,
				left_foot_lift + diag_lift,
				left_foot_swing * foot_direction_multiplier
			)
			right_foot_pos = right_foot_origin + Vector3(
				-diag_cross,
				right_foot_lift + diag_lift,
				right_foot_swing * foot_direction_multiplier
			)
		else:
			# Normal foot animation for forward/backward
			left_foot_pos = left_foot_origin + Vector3(
				0,
				left_foot_lift,
				left_foot_swing * foot_direction_multiplier
			)
			right_foot_pos = right_foot_origin + Vector3(
				0,
				right_foot_lift,
				right_foot_swing * foot_direction_multiplier
			)

	# 🦶 DIRECT FOOT ANIMATION - Apply positions directly to foot nodes
	if left_foot_node and right_foot_node and left_foot_pos != null and right_foot_pos != null:
		left_foot_node.position = left_foot_pos
		right_foot_node.position = right_foot_pos
	elif not left_foot_node or not right_foot_node:
		print("❌ Can't animate feet - nodes missing! Left: ", left_foot_node != null, " Right: ", right_foot_node != null)

	# Emit signal for other systems that might need foot positions
	if left_foot_pos != null and right_foot_pos != null:
		foot_animation_update.emit(left_foot_pos, right_foot_pos)

# Defensive helper for dash charges
func get_safe_max_dash_charges() -> int:
	if player and is_instance_valid(player.stats_component):
		return player.stats_component.get_max_dash_charges()
	return 0

func can_dash() -> bool:
	return current_dash_charges > 0 and not is_dashing and not is_attacking and not is_being_knocked_back

func perform_dash():
	if not can_dash():
		return
	current_dash_charges -= 1
	last_dash_time = Time.get_ticks_msec() / 1000.0
	var max_charges = get_safe_max_dash_charges()
	dash_charges_changed.emit(current_dash_charges, max_charges)
	# Fix Vector2/Vector3 type mismatch in dash
	# get_movement_input returns Vector2, get_facing_direction returns Vector3
	# Need to handle both types properly and convert to consistent format
	# Don't set y=0 on Vector2 as that removes forward/backward movement
	var dash_direction_2d = get_movement_input()  # Vector2
	if dash_direction_2d.length() == 0:
		var facing_3d = get_facing_direction()  # Vector3
		dash_direction_2d = Vector2(facing_3d.x, facing_3d.z)  # Convert 3D to 2D properly
	dash_direction_2d = dash_direction_2d.normalized()
	# Convert Vector2 dash_direction to Vector3 for effects
	var dash_direction_3d = Vector3(dash_direction_2d.x, 0, dash_direction_2d.y)
	DashEffectsManager.play_dash_effects(player, dash_direction_3d)
	var dash_velocity = dash_direction_2d * (player.dash_distance / player.dash_duration)
	player.velocity.x = dash_velocity.x
	player.velocity.z = dash_velocity.y
	player.move_and_slide()
	await player.get_tree().create_timer(player.dash_duration).timeout
	is_dashing = false
	state = PlayerState.IDLE
	dash_ended.emit()

func handle_dash_cooldown(_delta: float):
	var max_charges = get_safe_max_dash_charges()
	if current_dash_charges >= max_charges:
		return
	var time_since_dash = Time.get_ticks_msec() / 1000.0 - last_dash_time
	if time_since_dash >= player.dash_cooldown:
		current_dash_charges = min(current_dash_charges + 1, max_charges)
		dash_charges_changed.emit(current_dash_charges, max_charges)

func get_movement_input() -> Vector2:
	var input_vector = Vector2.ZERO
	
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector.length() < 0.2:
		input_vector = Vector2.ZERO
	
	return input_vector

func move_player(direction: Vector3):
	player.velocity.x = direction.x * player.stats_component.get_speed()
	player.velocity.z = direction.z * player.stats_component.get_speed()

func apply_friction(delta: float):
	player.velocity.x = move_toward(player.velocity.x, 0, player.stats_component.get_speed() * player.FRICTION_MULTIPLIER * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, player.stats_component.get_speed() * player.FRICTION_MULTIPLIER * delta)

func apply_gravity(delta: float):
	if not player.is_on_floor():
		player.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

func handle_knockback(delta):
	if knockback_timer > 0:
		if state != PlayerState.KNOCKED_BACK:
			state = PlayerState.KNOCKED_BACK
			knockback_started.emit()
		knockback_timer -= delta
		var decay_factor = knockback_timer / player.knockback_duration
		player.velocity.x = knockback_velocity.x * decay_factor
		player.velocity.z = knockback_velocity.z * decay_factor
		if knockback_timer <= 0:
			knockback_velocity = Vector3.ZERO
			is_being_knocked_back = false
			state = PlayerState.IDLE
			knockback_ended.emit()

func apply_knockback_from_enemy(enemy: Node3D):
	if not enemy or not is_instance_valid(enemy):
		return
	var knockback_direction = (player.global_position - enemy.global_position)
	knockback_direction.y = 0
	if knockback_direction.length() < 0.1:
		knockback_direction = Vector3.RIGHT
	else:
		knockback_direction = knockback_direction.normalized()
	knockback_velocity = knockback_direction * player.knockback_force
	knockback_timer = player.knockback_duration
	is_being_knocked_back = true
	is_dashing = false
	is_attacking = false
	state = PlayerState.KNOCKED_BACK
	knockback_started.emit()

# Add this function to detect input device
func _detect_input_device():
	# Check for any controller input
	var controller_input = Vector2(
		Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
		Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	)
	if controller_input.length() > controller_deadzone:
		if not using_controller:
			using_controller = true
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif Input.get_last_mouse_velocity().length() > 0:
		if using_controller:
			using_controller = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func handle_mouse_look():
	# Camera-relative facing when rotating camera
	var camera = player.get_viewport().get_camera_3d()
	if camera and camera.has_method('get') and camera.get('is_rotating_camera'):
		# When camera is rotating, use movement direction for player facing
		var input_2d = get_movement_input()
		if input_2d.length() > 0.1:
			var camera_basis = camera.global_transform.basis
			var camera_forward = -camera_basis.z
			var camera_right = camera_basis.x
			camera_forward.y = 0
			camera_right.y = 0
			var facing_direction = (camera_forward * -input_2d.y) + (camera_right * input_2d.x)
			if facing_direction.length() > 0.1:
				player.look_at(player.global_position + facing_direction.normalized(), Vector3.UP)
		return
	# Don't process mouse look if camera is being rotated
	if camera and camera.has_method('get') and camera.get('is_rotating_camera'):
		return
	# Add safety check before existing mouse look code
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		return
	_detect_input_device()
	if not player.camera:
		return
	# Replace your mouse look code with this conditional version
	if not using_controller:
		# Only process mouse look when no controller input is detected
		# Your existing mouse look code here
		var mouse_pos = player.get_viewport().get_mouse_position()
		var from = player.camera.project_ray_origin(mouse_pos)
		var to = from + player.camera.project_ray_normal(mouse_pos) * 1000
		var ground_plane = Plane(Vector3.UP, player.global_position.y)
		var intersection = ground_plane.intersects_ray(from, to - from)
		if intersection:
			player.mouse_position_3d = intersection
			var direction_to_mouse = (player.mouse_position_3d - player.global_position).normalized()
			direction_to_mouse.y = 0
			if direction_to_mouse.length() > 0.1:
				player.look_at(player.global_position + direction_to_mouse, Vector3.UP)
	else:
		# Use controller look input instead
		var look_input = player.get_look_input() if player.has_method("get_look_input") else Vector2.ZERO
		if look_input.length() > controller_deadzone:
			var stick_direction = Vector3(-look_input.x, 0, -look_input.y)
			var target_rotation = atan2(stick_direction.x, stick_direction.z)
			var rotation_speed = 8.0
			player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * get_process_delta_time())
			player.current_look_direction = stick_direction.normalized()

func get_camera_relative_movement() -> Vector3:
	var input_2d = get_movement_input()
	if input_2d.length() < 0.1:
		return Vector3.ZERO
	var camera = player.get_viewport().get_camera_3d()
	if not camera:
		# Fallback to world-space if no camera
		return Vector3(input_2d.x, 0, input_2d.y).normalized()
	# Get camera directions (ground-projected)
	var camera_basis = camera.global_transform.basis
	var camera_forward = -camera_basis.z
	var camera_right = camera_basis.x
	# Remove Y component and normalize
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	# Calculate camera-relative direction
	var direction = (camera_forward * -input_2d.y) + (camera_right * input_2d.x)
	return direction.normalized()

func get_facing_direction() -> Vector3:
	return -player.transform.basis.z

func can_attack() -> bool:
	var time_since_last_attack = Time.get_ticks_msec() / 1000.0 - player.last_attack_time
	return time_since_last_attack >= player.attack_cooldown and not is_attacking

func set_punch_animating(value: bool):
	is_punch_animating = value

func set_animation_settings(settings: Dictionary) -> void:
	if "body_lean_strength" in settings:
		body_lean_strength = settings["body_lean_strength"]
	if "body_sway_strength" in settings:
		body_sway_strength = settings["body_sway_strength"]
	if "hand_swing_strength" in settings:
		hand_swing_strength = settings["hand_swing_strength"]
	if "foot_step_strength" in settings:
		foot_step_strength = settings["foot_step_strength"]
	if "side_step_modifier" in settings:
		side_step_modifier = settings["side_step_modifier"]
	print("✅ PlayerMovement animation settings applied: ", settings)

func interact_with_nearest():
	"""Handle interaction with nearby objects - delegates to player"""
	if player and player.has_method("interact_with_nearest"):
		player.interact_with_nearest()
	else:
		print("⚠️ No interaction method available")
