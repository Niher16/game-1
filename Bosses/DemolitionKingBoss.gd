# enhanced_demolition_king_boss.gd - Cleaned version
extends CharacterBody3D

# === SIGNALS ===
signal boss_died
signal boss_attack_started(attack_type: String)

# === BOSS STATS ===
@export var max_health: int = 200
@export var speed: float = 4.0
@export var charge_speed: float = 8.0
@export var jump_speed: float = 12.0
@export var wall_break_radius: float = 3.0

# === ATTACK PROPERTIES ===
@export var wall_chunk_scene: PackedScene
@export var red_slime_scene: PackedScene  # Scene for spawning red slimes
@export var slam_damage: int = 30
@export var touch_damage: int = 15  # Damage when boss touches player
@export var chunk_throw_force: float = 15.0
@export var boss_knockback_force: float = 20.0  # Knockback when boss touches player

# === ENHANCED BOSS STATES ===
enum BossState { 
	SPAWNING,        # Safe spawn state - clear area
	POSITIONING,     # Move to safe position
	IDLE,           # Normal behavior
	MOVING,         # Active movement
	CHARGING,       # Charge attack
	LEAP_WIND_UP,   # Preparing to jump
	LEAPING,        # In the air
	SLAM_WIND_UP,   # Preparing slam attack
	SLAMMING,       # Slam attack execution
	THROW_WIND_UP,  # Preparing to throw chunks
	THROWING,       # Throwing wall chunks
	STUNNED,        # Brief recovery after big attacks
	DYING
}
var current_state: BossState = BossState.SPAWNING

# === CORE PROPERTIES ===
var health: int
var state_timer: float = 0.0
var attack_cooldown: float = 0.0

# === ATTACK SYSTEM ===
var charge_direction: Vector3
var is_charging: bool = false
var charge_timer: float = 0.0
var leap_target: Vector3
var is_leaping: bool = false
var slam_position: Vector3
var chunks_to_throw: int = 0
var throw_timer: float = 0.0

# === MOVEMENT PATTERNS ===
var movement_target: Vector3
var circle_angle: float = 0.0
var last_player_position: Vector3
var min_idle_time: float = 1.5  # Minimum time to stay in IDLE before considering movement

# === SCENE REFERENCES ===
var player: CharacterBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_scale: Vector3

# === VISUAL EFFECTS ===
var boss_material: StandardMaterial3D
var original_color: Color = Color(0.8, 0.2, 0.2, 1.0)  # Red boss color
var wind_up_tween: Tween
var is_showing_tell: bool = false
var flash_tween: Tween

# === PHYSICS & SAFETY ===
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var spawn_position: Vector3
var safe_ground_level: float
var last_safe_position: Vector3
var ground_normal: Vector3 = Vector3.UP

func _ready() -> void:
	health = max_health
	_setup_boss()
	_setup_physics_layers()
	call_deferred("_find_safe_spawn")
	
	# Load wall chunk scene
	if ResourceLoader.exists("res://Bosses/wall_chunk.tscn"):
		wall_chunk_scene = load("res://Bosses/wall_chunk.tscn")
	
	# Load red slime scene (try multiple possible paths)
	var slime_paths = [
		"res://Scenes/enemy.tscn",
		"res://scenes/enemy.tscn", 
		"res://Enemy/enemy.tscn",
		"res://Enemies/slime.tscn"
	]
	for path in slime_paths:
		if ResourceLoader.exists(path):
			red_slime_scene = load(path)
			break

func _physics_process(delta: float) -> void:
	state_timer += delta
	if attack_cooldown > 0:
		attack_cooldown -= delta
	_handle_boss_state(delta)
	_apply_safe_physics(delta)
	if is_on_floor():
		last_safe_position = global_position
	move_and_slide()
	_check_wall_collisions()
	_check_player_collision()
	_safety_checks()

func _setup_boss() -> void:
	mesh_instance = get_node_or_null("MeshInstance3D")
	collision_shape = get_node_or_null("CollisionShape3D")
	if mesh_instance:
		original_scale = mesh_instance.scale
		_setup_boss_material()
	player = get_tree().get_first_node_in_group("player")

func _setup_boss_material() -> void:
	if not mesh_instance:
		return
	var material = mesh_instance.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	boss_material = material
	boss_material.albedo_color = original_color
	boss_material.metallic = 0.1
	boss_material.roughness = 0.7

func _setup_physics_layers() -> void:
	collision_layer = 1 << 2
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2)

func _handle_boss_state(delta: float) -> void:
	match current_state:
		BossState.SPAWNING:
			_handle_spawning()
		BossState.POSITIONING:
			_handle_positioning()
		BossState.IDLE:
			_handle_enhanced_idle_state()
		BossState.MOVING:
			_handle_strategic_movement()
		BossState.CHARGING:
			_handle_charging(delta)
		BossState.LEAP_WIND_UP:
			_handle_leap_wind_up()
		BossState.LEAPING:
			_handle_leaping()
		BossState.SLAM_WIND_UP:
			_handle_slam_wind_up()
		BossState.SLAMMING:
			_handle_slamming()
		BossState.THROW_WIND_UP:
			_handle_throw_wind_up()
		BossState.THROWING:
			_handle_throwing(delta)
		BossState.STUNNED:
			_handle_stunned()
		BossState.DYING:
			_handle_dying()

# === FIXED IDLE STATE LOGIC ===
func _handle_enhanced_idle_state() -> void:
	"""Enhanced idle with attack selection - FIXED VERSION"""
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Stop moving when in idle
	velocity.x = 0
	velocity.z = 0
	
	# Must stay in idle for minimum time to prevent rapid state switching
	if state_timer < min_idle_time:
		return
	
	# Don't attack while falling or unstable
	if not is_on_floor() or velocity.y < -2.0:
		_transition_to_movement()
		return
	
	# Break walls if too close and stuck
	if distance_to_player < 8.0 and velocity.length() < 0.1:
		_force_break_nearby_walls()
	
	# PRIORITY: Attack if conditions are met
	if attack_cooldown <= 0:
		_choose_attack(distance_to_player)
		return
	
	# If attack is on cooldown but we've been idle long enough, move strategically
	if attack_cooldown > 0 and state_timer >= min_idle_time + 1.0:
		_transition_to_movement()

func _choose_attack(distance: float) -> void:
	"""Intelligently choose which attack to use - FIXED VERSION"""
	
	var attack_choice: int
	
	# Set a base attack cooldown to prevent spam
	attack_cooldown = 3.0
	
	if distance > 15.0:
		# Far away - leap or charge
		attack_choice = randi() % 2
		if attack_choice == 0:
			_start_leap_attack()
		else:
			_start_charge_attack()
	elif distance > 8.0:
		# Medium range - all attacks available
		attack_choice = randi() % 4
		match attack_choice:
			0: _start_charge_attack()
			1: _start_leap_attack()
			2: _start_slam_attack()
			3: _start_wall_throw_attack()
	else:
		# Close range - slam or charge
		attack_choice = randi() % 2
		if attack_choice == 0:
			_start_slam_attack()
		else:
			_start_charge_attack()

# === ENHANCED MOVEMENT ===
func _transition_to_movement() -> void:
	"""Switch to strategic movement"""
	current_state = BossState.MOVING
	state_timer = 0.0
	_set_movement_target()
	
func _handle_strategic_movement() -> void:
	"""More intelligent movement patterns - FIXED VERSION"""
	if not player:
		return
	
	var _distance_to_player = global_position.distance_to(player.global_position)
	
	# Update movement target if player moved significantly
	if last_player_position.distance_to(player.global_position) > 3.0:
		_set_movement_target()
		last_player_position = player.global_position
	
	# Move toward target
	_move_toward_target()
	
	# Return to idle with clearer conditions
	var target_reached = global_position.distance_to(movement_target) < 2.0
	var been_moving_long_enough = state_timer >= 2.0  # Reduced from 3.0
	
	if target_reached or been_moving_long_enough:
		current_state = BossState.IDLE
		state_timer = 0.0

func _set_movement_target() -> void:
	"""Set strategic movement position"""
	if not player:
		return
	
	var player_pos = player.global_position
	var current_distance = global_position.distance_to(player_pos)
	
	# Choose movement strategy based on current distance
	if current_distance < 5.0:
		# Too close - back away while circling
		var away_direction = (global_position - player_pos).normalized()
		movement_target = player_pos + away_direction * 8.0
	elif current_distance > 15.0:
		# Too far - get closer
		var toward_direction = (player_pos - global_position).normalized()
		movement_target = global_position + toward_direction * 6.0
	else:
		# Good distance - circle around player
		circle_angle += PI / 4  # 45 degrees
		var circle_radius = 10.0
		var circle_offset = Vector3(cos(circle_angle), 0, sin(circle_angle)) * circle_radius
		movement_target = player_pos + circle_offset
	
	# Make sure target is on ground level
	movement_target.y = global_position.y

func _move_toward_target() -> void:
	"""Move toward the movement target"""
	var direction = (movement_target - global_position).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Break walls in movement direction
	if velocity.length() > 0.1:
		_break_walls_in_movement_direction()

# === ATTACK IMPLEMENTATIONS ===
func _start_charge_attack() -> void:
	"""Begin charge attack"""
	if not player:
		return
	
	current_state = BossState.CHARGING
	state_timer = 0.0
	is_charging = true
	charge_timer = 0.0
	
	# Set charge direction toward player
	charge_direction = (player.global_position - global_position).normalized()
	velocity = Vector3.ZERO
	
	_show_attack_tell("charge")
	boss_attack_started.emit("charge")

func _handle_charging(delta: float) -> void:
	"""Handle charge attack"""
	charge_timer += delta
	
	# Wind-up phase
	if charge_timer < 1.0:
		velocity = Vector3.ZERO  # Brief pause before charging
		return
	
	# Charge phase
	velocity.x = charge_direction.x * charge_speed
	velocity.z = charge_direction.z * charge_speed
	
	# Break walls during charge
	_break_walls_in_movement_direction()
	
	# End charge after 3 seconds total
	if charge_timer >= 3.0:
		_end_charge()

func _end_charge() -> void:
	"""End charge attack"""
	is_charging = false
	velocity = Vector3.ZERO
	_clear_attack_tell()
	
	# Brief stun after charge
	current_state = BossState.STUNNED
	state_timer = 0.0

func _start_leap_attack() -> void:
	"""Begin leap attack"""
	if not player:
		return
	
	current_state = BossState.LEAP_WIND_UP
	state_timer = 0.0
	is_leaping = false
	
	# Set leap target near player
	leap_target = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	velocity = Vector3.ZERO
	
	_show_attack_tell("leap")
	boss_attack_started.emit("leap")

func _handle_leap_wind_up() -> void:
	"""Wind-up for leap attack"""
	velocity = Vector3.ZERO
	
	if state_timer >= 1.5:  # 1.5 second wind-up
		_execute_leap()

func _execute_leap() -> void:
	"""Execute leap attack"""
	current_state = BossState.LEAPING
	state_timer = 0.0
	is_leaping = true
	
	# Calculate jump velocity toward target
	var direction = (leap_target - global_position).normalized()
	velocity.x = direction.x * speed * 2
	velocity.z = direction.z * speed * 2
	velocity.y = jump_speed
	
	_clear_attack_tell()
	
func _handle_leaping() -> void:
	"""Handle boss while in air"""
	# Break walls during leap
	_break_walls_in_movement_direction()
	
	# Land when hitting ground
	if is_on_floor() and velocity.y <= 0:
		_land_from_leap()

func _land_from_leap() -> void:
	"""Handle landing from leap"""
	is_leaping = false
	velocity = Vector3.ZERO
	
	# Create landing impact
	_force_break_nearby_walls()
	_screen_shake(0.3)
	
	# Brief stun after landing
	current_state = BossState.STUNNED
	state_timer = 0.0

func _start_slam_attack() -> void:
	"""Begin slam attack"""
	current_state = BossState.SLAM_WIND_UP
	state_timer = 0.0
	
	slam_position = global_position
	velocity = Vector3.ZERO
	
	_show_attack_tell("slam")
	boss_attack_started.emit("slam")

func _handle_slam_wind_up() -> void:
	"""Wind-up for slam attack"""
	velocity = Vector3.ZERO
	
	# Jump up during wind-up
	if state_timer >= 1.0 and state_timer < 1.1:
		velocity.y = jump_speed
	
	if state_timer >= 2.0:  # 2 second wind-up
		_execute_slam()

func _execute_slam() -> void:
	"""Execute slam attack"""
	current_state = BossState.SLAMMING
	state_timer = 0.0
	
	# Force downward velocity
	velocity.y = -jump_speed * 1.5
	
	_clear_attack_tell()

func _handle_slamming() -> void:
	"""Handle slam attack execution"""
	# Hit ground with force
	if is_on_floor():
		_slam_impact()

func _slam_impact() -> void:
	"""Create slam impact effects"""
	velocity = Vector3.ZERO
	
	# Break walls in larger radius
	var old_radius = wall_break_radius
	wall_break_radius *= 1.5
	_force_break_nearby_walls()
	wall_break_radius = old_radius  # Reset radius
	
	# Damage player if close
	if player and global_position.distance_to(player.global_position) < 6.0:
		if player.has_method("take_damage"):
			player.take_damage(slam_damage, self)
	
	_screen_shake(0.5)
	
	# Stun after slam
	current_state = BossState.STUNNED
	state_timer = 0.0

func _start_wall_throw_attack() -> void:
	"""Begin wall throwing attack"""
	if not wall_chunk_scene:
		_start_charge_attack()  # Fallback to charge
		return
	
	current_state = BossState.THROW_WIND_UP
	state_timer = 0.0
	chunks_to_throw = 3
	throw_timer = 0.0
	
	velocity = Vector3.ZERO
	
	_show_attack_tell("throw")
	boss_attack_started.emit("throw")

func _handle_throw_wind_up() -> void:
	"""Wind-up for throwing attack"""
	velocity = Vector3.ZERO
	
	if state_timer >= 1.0:  # 1 second wind-up
		_execute_throw()

func _execute_throw() -> void:
	"""Execute throwing attack"""
	current_state = BossState.THROWING
	state_timer = 0.0
	throw_timer = 0.0
	
	_clear_attack_tell()

func _handle_throwing(delta: float) -> void:
	"""Handle throwing wall chunks"""
	throw_timer += delta
	
	# Throw chunks every 0.5 seconds
	if throw_timer >= 0.5 and chunks_to_throw > 0:
		_throw_wall_chunk()
		chunks_to_throw -= 1
		throw_timer = 0.0
	
	# End attack when all chunks thrown
	if chunks_to_throw <= 0 and state_timer >= 2.0:
		current_state = BossState.STUNNED
		state_timer = 0.0
		
func _throw_wall_chunk() -> void:
	"""Throw a single wall chunk at player"""
	if not wall_chunk_scene or not player:
		return
	
	var chunk = wall_chunk_scene.instantiate()
	get_tree().current_scene.add_child(chunk)
	
	# Position chunk near boss
	chunk.global_position = global_position + Vector3(0, 1, 0)
	
	# Calculate throw direction with some prediction
	var target_pos = player.global_position + player.velocity * 0.5  # Lead target
	var throw_direction = (target_pos - chunk.global_position).normalized()
	var throw_force = throw_direction * chunk_throw_force
	
	# Add some arc to the throw
	throw_force.y += 5.0
	
	if chunk.has_method("throw"):
		chunk.throw(throw_force)

func _handle_stunned() -> void:
	"""Handle stun state after attacks"""
	velocity = Vector3.ZERO
	
	if state_timer >= 1.0:  # 1 second stun
		current_state = BossState.IDLE
		state_timer = 0.0

# === SPAWNING AND POSITIONING ===
func _find_safe_spawn() -> void:
	"""Find safe spawn position"""
	spawn_position = global_position
	safe_ground_level = global_position.y
	last_safe_position = global_position
	
	current_state = BossState.POSITIONING

func _handle_spawning() -> void:
	"""Handle spawning state"""
	velocity = Vector3.ZERO
	state_timer += get_physics_process_delta_time()
	
	if state_timer >= 2.0:
		current_state = BossState.POSITIONING
		state_timer = 0.0

func _handle_positioning() -> void:
	"""Handle positioning state"""
	if not is_on_floor():
		velocity.y -= gravity * get_physics_process_delta_time()
	else:
		velocity = Vector3.ZERO
		if state_timer >= 1.0:
			current_state = BossState.IDLE
			state_timer = 0.0

# === PHYSICS AND UTILITIES ===
func _apply_safe_physics(delta: float) -> void:
	"""Apply gravity and physics safely"""
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Prevent being pushed into the ground
	if is_on_floor() and velocity.y < 0:
		velocity.y = 0

func _break_walls_in_movement_direction() -> void:
	"""Break walls in front of boss movement"""
	if velocity.length() < 0.1:
		return
	
	var direction = velocity.normalized()
	var break_position = global_position + direction * 2.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.shape = SphereShape3D.new()
	query.shape.radius = wall_break_radius
	query.transform.origin = break_position
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)

func _force_break_nearby_walls() -> void:
	"""Force break all walls around boss"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.shape = SphereShape3D.new()
	query.shape.radius = wall_break_radius
	query.transform.origin = global_position
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)

func _check_wall_collisions() -> void:
	"""Check for wall collisions after movement"""
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if _is_wall(collider):
			_break_wall(collider)

func _is_wall(obj: Node) -> bool:
	"""Wall detection logic"""
	if not obj:
		return false
	
	var name_lower = obj.name.to_lower()
	var parent_name_lower = obj.get_parent().name.to_lower() if obj.get_parent() else ""
	
	# Never break these
	var never_break = (
		name_lower.contains("floor") or
		name_lower.contains("ground") or
		name_lower.contains("terrain") or
		name_lower.contains("player") or
		name_lower.contains("boss") or
		obj.is_in_group("player") or
		obj.is_in_group("bosses") or
		obj.is_in_group("floor")
	)
	
	if never_break:
		return false
	
	# Check if it's definitely a wall
	return (
		name_lower.contains("wall") or
		parent_name_lower.contains("wall") or
		obj.is_in_group("walls") or
		(obj is StaticBody3D and obj.collision_layer & (1 << 1))
	)

func _break_wall(wall: Node) -> void:
	"""Break wall safely"""
	if not wall or not is_instance_valid(wall):
		return
	
	if wall.has_method("break_wall"):
		wall.break_wall()
	elif wall.has_method("queue_free"):
		if wall.has_method("set_visible"):
			wall.set_visible(false)
		if wall.has_method("set_collision_layer"):
			wall.set_collision_layer(0)
		wall.queue_free()

func _safety_checks() -> void:
	"""Safety checks for boss"""
	if global_position.y < safe_ground_level - 10.0:
		global_position = last_safe_position
		velocity = Vector3.ZERO

func _handle_dying() -> void:
	"""Handle boss death"""
	velocity = Vector3.ZERO
	boss_died.emit()

# === VISUAL EFFECTS (ENHANCED IMPLEMENTATIONS) ===
func _show_attack_tell(_attack_type: String) -> void:
	"""Show visual tell for incoming attack with color flash"""
	is_showing_tell = true
	
	if not boss_material:
		return
	
	# Stop any existing flash
	if flash_tween:
		flash_tween.kill()
	
	# Flash yellow/orange before attack
	flash_tween = create_tween()
	flash_tween.set_loops()  # Infinite loop until cleared
	
	var warning_color = Color(1.0, 0.7, 0.2, 1.0)  # Bright orange/yellow
	flash_tween.tween_property(boss_material, "albedo_color", warning_color, 0.3)
	flash_tween.tween_property(boss_material, "albedo_color", original_color, 0.3)

func _clear_attack_tell() -> void:
	"""Clear attack tell and return to normal color"""
	is_showing_tell = false
	
	# Stop flashing
	if flash_tween:
		flash_tween.kill()
		flash_tween = null
	
	# Return to normal red color
	if boss_material:
		boss_material.albedo_color = original_color

func _screen_shake(intensity: float) -> void:
	"""Create screen shake effect"""
	# Try to find camera and shake it
	var camera = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(intensity)

# === DAMAGE AND HEALTH ===
func take_damage(amount: int, _source: Node = null) -> void:
	"""Take damage and spawn red slime"""
	health -= amount
	
	# Spawn red slime when hit
	_spawn_red_slime()
	
	if health <= 0:
		current_state = BossState.DYING

func _spawn_red_slime() -> void:
	"""Spawn a red slime when boss takes damage"""
	if not red_slime_scene:
		return
	
	var slime = red_slime_scene.instantiate()
	get_tree().current_scene.add_child(slime)
	
	# Position slime near boss but not on top
	var spawn_offset = Vector3(
		randf_range(-3.0, 3.0),
		1.0,
		randf_range(-3.0, 3.0)
	)
	slime.global_position = global_position + spawn_offset
	
	# Make slime red if it has material
	if slime.has_method("_setup_slime_material"):
		call_deferred("_make_slime_red", slime)

func _make_slime_red(slime: Node) -> void:
	"""Make the spawned slime red colored"""
	await get_tree().process_frame  # Wait for slime to be ready
	
	if not slime or not is_instance_valid(slime):
		return
	
	var slime_mesh_instance = slime.get_node_or_null("MeshInstance3D")
	if slime_mesh_instance and slime_mesh_instance.material_override:
		var material = slime_mesh_instance.material_override
		if material is StandardMaterial3D:
			material.albedo_color = Color(0.8, 0.1, 0.1, 0.95)  # Bright red

func _check_player_collision() -> void:
	"""Check if boss is touching player and deal damage"""
	if not player or current_state == BossState.DYING:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# If boss is close enough to touch player
	if distance_to_player <= 2.0:  # Adjust this range as needed
		if player.has_method("take_damage"):
			player.take_damage(touch_damage, self)
			
			# Apply knockback to player
			if player.has_method("apply_knockback_from_enemy") or player.get("movement_component"):
				var movement_comp = player.get("movement_component")
				if movement_comp and movement_comp.has_method("apply_knockback_from_enemy"):
					movement_comp.apply_knockback_from_enemy(self)
