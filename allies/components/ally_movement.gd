extends Node
class_name AllyMovement

# Handles movement for the ally

var ally_ref
var speed: float
var follow_distance := 4.0
var separation_distance := 1.5
var orbit_radius := 2.5
var orbit_angle: float

# Body animation variables
var body_origin: Vector3
var current_body_sway: Vector3 = Vector3.ZERO
var target_body_sway: Vector3 = Vector3.ZERO
var body_sway_strength: float = 0.03  # Very subtle sway
var body_lean_strength: float = 0.07  # Very subtle leaning
var interpolation_speed: float = 8.0  # Smoother animation transitions
var walk_cycle_time: float = 0.0
var personality_offset: float = 0.0
var body_node

var navigation_agent: NavigationAgent3D = null
var personality: AllyPersonality = null

func setup(ally, move_speed: float):
	ally_ref = ally
	speed = move_speed
	orbit_angle = randf() * TAU  # Random starting orbit position
	initialize_body_animation()

func initialize_body_animation():
	# Find the body node (MeshInstance3D with 'Body', 'Torso', or 'Chest' in name)
	body_node = null
	var mesh_children = []
	for child in ally_ref.get_children():
		if child is MeshInstance3D:
			mesh_children.append(child)
	# Use 'body_name' to avoid shadowing base class property
	for body_name in ["Body", "Torso", "Chest"]:
		for child in mesh_children:
			if body_name in child.name:
				body_node = child
				break
		if body_node:
			break
	if not body_node and ally_ref.mesh_instance:
		body_node = ally_ref.mesh_instance
	if body_node:
		body_origin = body_node.position
	else:
		body_origin = Vector3.ZERO
	personality_offset = randf_range(-0.1, 0.1)
	current_body_sway = Vector3.ZERO
	target_body_sway = Vector3.ZERO

# Always check if personality is not null before using its properties
func setup_navigation(agent: NavigationAgent3D, move_speed: float, personality_ref = null):
	navigation_agent = agent
	speed = move_speed
	if personality_ref:
		personality = personality_ref
	if personality:
		navigation_agent.path_desired_distance = lerp(0.3, 1.0, personality.caution)
		navigation_agent.max_speed = lerp(2.0, 5.0, personality.boldness)
	else:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.max_speed = speed
	navigation_agent.target_desired_distance = 0.3
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

func move_with_navigation(target_pos: Vector3):
	if navigation_agent:
		navigation_agent.set_target_position(target_pos)

func _on_velocity_computed(safe_velocity: Vector3):
	if ally_ref:
		ally_ref.velocity.x = safe_velocity.x
		ally_ref.velocity.z = safe_velocity.z

func move_towards_target(target_pos: Vector3, delta: float):
	var direction = (target_pos - ally_ref.global_position)
	direction.y = 0  # Keep on ground
	
	if direction.length() > 0.1:
		direction = direction.normalized()
		ally_ref.velocity.x = direction.x * speed
		ally_ref.velocity.z = direction.z * speed
		_face_direction(direction)
	else:
		# Stop when close enough
		ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, speed * 2 * delta)
		ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, speed * 2 * delta)
	
	# Call body animation update after velocity is set
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)
	# 🔧 FIX: Add missing foot animation call (matching combat behavior)
	if ally_ref.has_method("animate_feet_if_possible"):
		ally_ref.animate_feet_if_possible(delta)

func move_toward_target(target_pos: Vector3, delta: float):
	# Move directly toward the target position (used for ranged AI)
	var direction = (target_pos - ally_ref.global_position)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		ally_ref.velocity.x = direction.x * speed
		ally_ref.velocity.z = direction.z * speed
		_face_direction(direction)
		if body_node:
			_update_ally_body_animation(delta, ally_ref.velocity)

func _update_ally_body_animation(delta: float, velocity: Vector3):
	if not body_node:
		return
	if velocity.length() > 0.1:
		walk_cycle_time += delta * 5.0
		var vel_scale = clamp(velocity.length() / 3.5, 0.3, 1.0)
		var vertical_bob = sin(walk_cycle_time * 2.0 + personality_offset) * 0.07 * vel_scale  # Very subtle bobbing
		var horizontal_sway = sin(walk_cycle_time + personality_offset) * 0.02 * vel_scale  # Very subtle sway
		var wiggle = sin(walk_cycle_time * 2.0 + personality_offset) * 0.02 * vel_scale  # Minimal wiggle
		target_body_sway = Vector3(horizontal_sway, vertical_bob, wiggle)
		current_body_sway = lerp(current_body_sway, target_body_sway, interpolation_speed * delta)
		body_node.position = body_origin + current_body_sway
	else:
		walk_cycle_time = 0.0
		current_body_sway = lerp(current_body_sway, Vector3.ZERO, interpolation_speed * delta)
		body_node.position = body_origin + current_body_sway

func orbit_around_player(player: Node3D, delta: float):
	if not player:
		return
	
	# Update orbit angle
	orbit_angle += delta * 0.8
	if orbit_angle > TAU:
		orbit_angle -= TAU
	
	# --- Avoidance buffer: adjust orbit_angle if allies are too close ---
	var avoidance_radius = 2.0
	var angle_adjust = 0.0
	var allies = get_tree().get_nodes_in_group("allies")
	for other_ally in allies:
		if other_ally == ally_ref or not is_instance_valid(other_ally):
			continue
		var dist = ally_ref.global_position.distance_to(other_ally.global_position)
		if dist < avoidance_radius:
			# Try to find clear space by nudging angle
			if angle_adjust == 0.0:
				angle_adjust = 0.5 if randi() % 2 == 0 else -0.5
	if angle_adjust != 0.0:
		orbit_angle += angle_adjust
	
	# Calculate orbit position
	var orbit_offset = Vector3(
		cos(orbit_angle) * orbit_radius,
		0,
		sin(orbit_angle) * orbit_radius
	)
	var target_pos = player.global_position + orbit_offset
	
	# Move towards orbit position
	var distance_to_player = ally_ref.global_position.distance_to(player.global_position)
	if distance_to_player > follow_distance:
		move_towards_target(target_pos, delta)

# Add helper function to check for walls
func _would_hit_wall(pos: Vector3, dir: Vector3) -> bool:
	"""Check if moving in direction would hit a wall"""
	var terrain = get_tree().get_first_node_in_group("terrain")
	if not terrain or not terrain.has_method("_is_valid_pos"):
		return false
	var map_size = Vector2(60, 60)
	if terrain and "map_size" in terrain:
		map_size = terrain.map_size
	var test_pos = pos + dir.normalized() * 0.7  # Test a bit ahead
	var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
	var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
	return not terrain._is_valid_pos(test_grid_x, test_grid_y)

func apply_separation(delta: float):
	var allies = get_tree().get_nodes_in_group("allies")
	var separation_force = Vector3.ZERO
	for other_ally in allies:
		if other_ally == ally_ref or not is_instance_valid(other_ally):
			continue
		var distance = ally_ref.global_position.distance_to(other_ally.global_position)
		if distance < separation_distance and distance > 0:
			var away_dir = (ally_ref.global_position - other_ally.global_position).normalized()
			away_dir.y = 0
			# 🔧 FIXED: Only apply separation if it won't push into walls
			if not _would_hit_wall(ally_ref.global_position, away_dir):
				# Exponential falloff for stronger repulsion
				var force_strength = pow((separation_distance - distance) / separation_distance, 2) * 3.0
				separation_force += away_dir * force_strength
	# 🔧 FIXED: Limit separation force and validate against walls
	var max_separation_force = speed * 0.8
	separation_force.x = clamp(separation_force.x, -max_separation_force, max_separation_force)
	separation_force.z = clamp(separation_force.z, -max_separation_force, max_separation_force)
	# Apply separation to velocity only if safe
	var intended_velocity = Vector3(
		ally_ref.velocity.x + separation_force.x * speed * delta,
		ally_ref.velocity.y,
		ally_ref.velocity.z + separation_force.z * speed * delta
	)
	# Final wall check for the intended movement
	var movement_dir = Vector3(intended_velocity.x, 0, intended_velocity.z).normalized()
	if movement_dir.length() > 0.1 and not _would_hit_wall(ally_ref.global_position, movement_dir):
		ally_ref.velocity.x = intended_velocity.x
		ally_ref.velocity.z = intended_velocity.z

func _face_direction(direction: Vector3):
	if direction.length() < 0.1:
		return
	
	var target_rotation = atan2(-direction.x, -direction.z)
	ally_ref.rotation.y = lerp_angle(ally_ref.rotation.y, target_rotation, 0.1)


func strafe_around_target(target: Node3D, delta: float):
	if not target:
		return
	# Calculate direction to enemy and perpendicular strafe direction
	var to_enemy = (target.global_position - ally_ref.global_position)
	to_enemy.y = 0
	if to_enemy.length() < 0.1:
		return
	to_enemy = to_enemy.normalized()
	var strafe_dir = Vector3(-to_enemy.z, 0, to_enemy.x)  # Perpendicular
	# Mix forward and strafe for circling
	var move_dir = (to_enemy + strafe_dir * (randf() * 1.2 - 0.6)).normalized()
	ally_ref.velocity.x = move_dir.x * speed
	ally_ref.velocity.z = move_dir.z * speed
	_face_direction(to_enemy)
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)
	# --- Ensure foot animation is triggered during strafe movement ---
	if ally_ref.has_method("animate_feet_if_possible"):
		ally_ref.animate_feet_if_possible(delta)

func move_away_from_target(target_pos: Vector3, delta: float):
	var direction = (ally_ref.global_position - target_pos)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		ally_ref.velocity.x = direction.x * speed
		ally_ref.velocity.z = direction.z * speed
		_face_direction(-direction)
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)
	# 🔧 FIX: Add missing foot animation call here too
	if ally_ref.has_method("animate_feet_if_possible"):
		ally_ref.animate_feet_if_possible(delta)

# Always check if personality is not null before using its properties
func move_with_formation(player: Node3D):
	var offset = Vector3.ZERO
	if personality:
		offset = Vector3(lerp(-2,2,personality.loyalty), 0, lerp(-2,2,personality.boldness))
	else:
		offset = Vector3.ZERO
	var target_pos = player.global_position + offset
	move_with_navigation(target_pos)

func _exit_tree():
	# Safely disconnect signal to avoid calling on freed object
	if navigation_agent and navigation_agent.velocity_computed.is_connected(_on_velocity_computed):
		navigation_agent.velocity_computed.disconnect(_on_velocity_computed)
