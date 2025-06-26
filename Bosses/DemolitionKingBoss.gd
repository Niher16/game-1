# enhanced_demolition_king_boss.gd - Enhanced version with more attacks and movement
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
@export var slam_damage: int = 30
@export var chunk_throw_force: float = 15.0

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

# === SCENE REFERENCES ===
var player: CharacterBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_scale: Vector3

# === VISUAL EFFECTS ===
var boss_material: StandardMaterial3D
var original_color: Color
var wind_up_tween: Tween
var is_showing_tell: bool = false

# === PHYSICS & SAFETY ===
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var spawn_position: Vector3
var safe_ground_level: float
var last_safe_position: Vector3
var ground_normal: Vector3 = Vector3.UP

# === DEBUGGING ===
var debug_enabled: bool = true
var walls_broken_this_frame: int = 0
var debug_collision_timer: float = 0.0

func _ready() -> void:
	health = max_health
	_setup_boss()
	_setup_physics_layers()
	call_deferred("_find_safe_spawn")
	
	# Load wall chunk scene
	if ResourceLoader.exists("res://Bosses/wall_chunk.tscn"):
		wall_chunk_scene = load("res://Bosses/wall_chunk.tscn")
		if debug_enabled:
			print("🪨 BOSS: Wall chunk scene loaded successfully!")
	else:
		if debug_enabled:
			print("🪨 BOSS: Wall chunk scene not found at res://Bosses/wall_chunk.tscn")
	
	if debug_enabled:
		print("🤖 ENHANCED BOSS: Spawning Enhanced Demolition King")
		print("🤖 ENHANCED BOSS: Health: ", health, "/", max_health)

func _physics_process(delta: float) -> void:
	state_timer += delta
	debug_collision_timer += delta
	walls_broken_this_frame = 0
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	_handle_boss_state(delta)
	_apply_safe_physics(delta)
	
	# Store last position before moving
	if is_on_floor():
		last_safe_position = global_position
	
	move_and_slide()
	_check_wall_collisions()
	_safety_checks()
	
	# Debug output
	if debug_enabled and debug_collision_timer >= 2.0:
		_debug_status()
		debug_collision_timer = 0.0

func _setup_boss() -> void:
	# Get scene components
	mesh_instance = get_node_or_null("MeshInstance3D")
	collision_shape = get_node_or_null("CollisionShape3D")
	
	if mesh_instance:
		original_scale = mesh_instance.scale
		_setup_boss_material()
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("❌ ENHANCED BOSS: No player found!")

func _setup_boss_material() -> void:
	"""Setup visual effects for the boss"""
	if not mesh_instance:
		return
	
	var material = mesh_instance.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	
	boss_material = material
	original_color = boss_material.albedo_color

func _setup_physics_layers() -> void:
	"""Setup collision layers properly"""
	collision_layer = 1 << 2  # Boss on layer 3 (bit 2)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2)  # Detect ground, walls, enemies

func _handle_boss_state(delta: float) -> void:
	"""Enhanced state machine with more attack patterns"""
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

func _handle_enhanced_idle_state() -> void:
	"""Enhanced idle with attack selection"""
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Don't attack while falling or unstable
	if not is_on_floor() or velocity.y < -2.0:
		if debug_enabled:
			print("🤖 BOSS: Not stable - on_floor: ", is_on_floor(), " velocity.y: ", velocity.y)
		return
	
	# Break walls if stuck
	if distance_to_player < 8.0 and velocity.length() < 0.1:
		_force_break_nearby_walls()
	
	# Choose attack based on distance and cooldown
	if attack_cooldown <= 0 and state_timer >= 1.0:  # Reduced from 2.0 to 1.0
		if debug_enabled:
			print("🤖 BOSS: Choosing attack! Distance: ", distance_to_player)
		_choose_attack(distance_to_player)
	else:
		# Move strategically while waiting for cooldown
		if debug_enabled and attack_cooldown > 0:
			print("🤖 BOSS: Attack on cooldown: ", attack_cooldown)
		_transition_to_movement()

func _choose_attack(distance: float) -> void:
	"""Intelligently choose which attack to use"""
	var attack_choice: int
	
	if debug_enabled:
		print("🤖 BOSS: Choosing attack for distance: ", distance)
	
	if distance > 15.0:
		# Far away - leap or charge
		attack_choice = randi() % 2
		if attack_choice == 0:
			_start_leap_attack()
		else:
			_start_charge_attack()
	elif distance > 8.0:
		# Medium range - all attacks available!
		attack_choice = randi() % 4
		match attack_choice:
			0: _start_charge_attack()
			1: _start_leap_attack()
			2: _start_slam_attack()
			3: _start_wall_throw_attack()  # Re-enabled!
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
	"""More intelligent movement patterns"""
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Update movement target if player moved significantly
	if last_player_position.distance_to(player.global_position) > 3.0:
		_set_movement_target()
		last_player_position = player.global_position
	
	# Move toward target
	_move_toward_target()
	
	# Return to idle after moving for a bit
	if state_timer >= 3.0 or global_position.distance_to(movement_target) < 2.0:
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

# === NEW ATTACK: LEAP ATTACK ===
func _start_leap_attack() -> void:
	"""Begin leap attack with wind-up"""
	current_state = BossState.LEAP_WIND_UP
	state_timer = 0.0
	attack_cooldown = 4.0
	
	# Set leap target behind player
	if player:
		var player_forward = -player.get_global_transform().basis.z
		leap_target = player.global_position + player_forward * 5.0
		leap_target.y = global_position.y
	
	_show_attack_tell("leap")
	boss_attack_started.emit("leap")
	
	if debug_enabled:
		print("🦘 BOSS: Starting leap attack wind-up")

func _handle_leap_wind_up() -> void:
	"""Wind-up for leap attack"""
	velocity = Vector3.ZERO  # Stop moving during wind-up
	
	if state_timer >= 1.5:  # 1.5 second wind-up
		_execute_leap()

func _execute_leap() -> void:
	"""Execute the leap"""
	current_state = BossState.LEAPING
	state_timer = 0.0
	is_leaping = true
	
	# Calculate leap velocity
	var leap_direction = (leap_target - global_position).normalized()
	velocity.x = leap_direction.x * jump_speed
	velocity.z = leap_direction.z * jump_speed
	velocity.y = jump_speed * 0.8  # Upward component
	
	_clear_attack_tell()
	
	if debug_enabled:
		print("🦘 BOSS: Executing leap!")

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
	
	if debug_enabled:
		print("🦘 BOSS: Landed from leap!")

# === NEW ATTACK: SLAM ATTACK ===
func _start_slam_attack() -> void:
	"""Begin slam attack"""
	current_state = BossState.SLAM_WIND_UP
	state_timer = 0.0
	attack_cooldown = 5.0
	
	slam_position = global_position
	velocity = Vector3.ZERO
	
	_show_attack_tell("slam")
	boss_attack_started.emit("slam")
	
	if debug_enabled:
		print("💥 BOSS: Starting slam attack wind-up")

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
	wall_break_radius *= 1.5
	_force_break_nearby_walls()
	wall_break_radius /= 1.5  # Reset radius
	
	# Damage player if close
	if player and global_position.distance_to(player.global_position) < 6.0:
		if player.has_method("take_damage"):
			player.take_damage(slam_damage, self)
	
	_screen_shake(0.5)
	
	# Stun after slam
	current_state = BossState.STUNNED
	state_timer = 0.0
	
	if debug_enabled:
		print("💥 BOSS: SLAM IMPACT!")

# === NEW ATTACK: WALL THROW ===
func _start_wall_throw_attack() -> void:
	"""Begin wall throwing attack"""
	current_state = BossState.THROW_WIND_UP
	state_timer = 0.0
	attack_cooldown = 3.0
	
	chunks_to_throw = 3 + randi() % 3  # 3-5 chunks
	throw_timer = 0.0
	velocity = Vector3.ZERO
	
	_show_attack_tell("throw")
	boss_attack_started.emit("throw")
	
	if debug_enabled:
		print("🪨 BOSS: Starting wall throw wind-up, chunks: ", chunks_to_throw)

func _handle_throw_wind_up() -> void:
	"""Wind-up for throw attack"""
	velocity = Vector3.ZERO
	
	if state_timer >= 1.0:  # 1 second wind-up
		current_state = BossState.THROWING
		state_timer = 0.0
		_clear_attack_tell()

func _handle_throwing(delta: float) -> void:
	"""Handle throwing wall chunks"""
	throw_timer += delta
	
	# Throw chunks every 0.4 seconds
	if throw_timer >= 0.4 and chunks_to_throw > 0:
		_throw_wall_chunk()
		chunks_to_throw -= 1
		throw_timer = 0.0
	
	# Finish throwing
	if chunks_to_throw <= 0:
		current_state = BossState.STUNNED
		state_timer = 0.0

func _throw_wall_chunk() -> void:
	"""Throw a wall chunk at the player"""
	if not wall_chunk_scene:
		if debug_enabled:
			print("🪨 BOSS: No wall chunk scene loaded, skipping throw")
		return
	
	if not player:
		return
	
	var chunk = wall_chunk_scene.instantiate()
	get_tree().current_scene.add_child(chunk)
	
	# Position chunk above boss
	chunk.global_position = global_position + Vector3(0, 2, 0)
	
	# Calculate throw direction with some prediction
	var player_velocity = Vector3.ZERO
	if player.has_method("get_velocity"):
		player_velocity = player.get_velocity()
	
	var predicted_position = player.global_position + player_velocity * 0.5
	var throw_direction = (predicted_position - chunk.global_position).normalized()
	var throw_force = throw_direction * chunk_throw_force
	
	# Add some upward arc
	throw_force.y += chunk_throw_force * 0.3
	
	chunk.throw(throw_force)
	
	if debug_enabled:
		print("🪨 BOSS: Threw wall chunk!")

# === VISUAL TELLS ===
func _show_attack_tell(attack_type: String) -> void:
	"""Show visual wind-up for attacks"""
	if not boss_material or is_showing_tell:
		return
	
	is_showing_tell = true
	
	# Create tween for visual effects
	if wind_up_tween:
		wind_up_tween.kill()
	wind_up_tween = create_tween()
	wind_up_tween.set_loops()
	
	# Color and scale effects based on attack type
	match attack_type:
		"leap":
			# Blue pulsing for leap
			wind_up_tween.tween_method(_set_boss_color, original_color, Color.CYAN, 0.3)
			wind_up_tween.tween_method(_set_boss_color, Color.CYAN, original_color, 0.3)
		"slam":
			# Red pulsing for slam
			wind_up_tween.tween_method(_set_boss_color, original_color, Color.RED, 0.4)
			wind_up_tween.tween_method(_set_boss_color, Color.RED, original_color, 0.4)
		"throw":
			# Yellow pulsing for throw
			wind_up_tween.tween_method(_set_boss_color, original_color, Color.YELLOW, 0.2)
			wind_up_tween.tween_method(_set_boss_color, Color.YELLOW, original_color, 0.2)
		"charge":
			# Orange pulsing for charge
			wind_up_tween.tween_method(_set_boss_color, original_color, Color.ORANGE, 0.25)
			wind_up_tween.tween_method(_set_boss_color, Color.ORANGE, original_color, 0.25)

func _set_boss_color(color: Color) -> void:
	"""Set boss material color"""
	if boss_material:
		boss_material.albedo_color = color

func _clear_attack_tell() -> void:
	"""Clear visual wind-up effects"""
	is_showing_tell = false
	
	if wind_up_tween:
		wind_up_tween.kill()
	
	if boss_material:
		boss_material.albedo_color = original_color

func _handle_stunned() -> void:
	"""Handle brief stun period after attacks"""
	velocity = Vector3.ZERO
	
	if state_timer >= 1.0:  # 1 second stun
		current_state = BossState.IDLE
		state_timer = 0.0

func _screen_shake(intensity: float) -> void:
	"""Create screen shake effect"""
	# This would connect to your camera shake system
	# For now, just print debug
	if debug_enabled:
		print("📳 SCREEN SHAKE: ", intensity)

# === ENHANCED CHARGE ATTACK ===
func _start_charge_attack() -> void:
	"""Enhanced charge attack with wind-up"""
	current_state = BossState.CHARGING
	attack_cooldown = 4.0
	
	if player:
		charge_direction = (player.global_position - global_position).normalized()
	
	is_charging = false  # Start with wind-up
	charge_timer = 0.0
	state_timer = 0.0
	velocity = Vector3.ZERO
	
	_show_attack_tell("charge")
	boss_attack_started.emit("charge")
	
	if debug_enabled:
		print("⚡ BOSS: Starting enhanced charge attack")

func _handle_charging(delta: float) -> void:
	"""Enhanced charge with wind-up phase"""
	charge_timer += delta
	
	# Wind-up phase (1 second)
	if charge_timer < 1.0:
		velocity = Vector3.ZERO
		return
	
	# Start actual charge
	if not is_charging:
		is_charging = true
		_clear_attack_tell()
		if debug_enabled:
			print("⚡ BOSS: CHARGE EXECUTION!")
	
	# Execute charge
	velocity.x = charge_direction.x * charge_speed
	velocity.z = charge_direction.z * charge_speed
	
	# Break walls while charging
	if int(charge_timer * 5) % 2 == 0:
		_force_break_nearby_walls()
	
	# End charge
	var distance_to_player = 999.0
	if player:
		distance_to_player = global_position.distance_to(player.global_position)
	
	if charge_timer >= 4.0 or distance_to_player < 2.0:
		_end_charge()

func _end_charge() -> void:
	"""End charge attack"""
	is_charging = false
	velocity = Vector3.ZERO
	current_state = BossState.STUNNED
	state_timer = 0.0
	charge_timer = 0.0
	
	_clear_attack_tell()
	
	if debug_enabled:
		print("⚡ BOSS: Charge attack ended")

# === KEEP ALL ORIGINAL WALL BREAKING CODE ===
func _find_safe_spawn() -> void:
	"""Find safe spawn position and clear area"""
	spawn_position = global_position
	safe_ground_level = global_position.y
	last_safe_position = global_position
	
	# Clear walls around spawn
	_force_break_nearby_walls()
	
	if debug_enabled:
		print("🤖 BOSS: Safe spawn found at: ", spawn_position)

func _handle_spawning() -> void:
	"""Handle safe spawning state"""
	velocity = Vector3.ZERO
	
	# Break walls every second during spawn
	if int(state_timer * 2) % 2 == 0:
		_force_break_nearby_walls()
	
	if is_on_floor() and state_timer >= 2.0:
		if debug_enabled:
			print("🤖 BOSS: Spawning complete, moving to positioning")
		current_state = BossState.POSITIONING
		state_timer = 0.0
	elif state_timer >= 5.0:
		if debug_enabled:
			print("🤖 BOSS: Forcing spawn completion")
		current_state = BossState.POSITIONING
		state_timer = 0.0

func _handle_positioning() -> void:
	"""Position boss and clear area"""
	if int(state_timer * 4) % 2 == 0:
		_force_break_nearby_walls()
	
	if state_timer >= 3.0:
		current_state = BossState.IDLE
		state_timer = 0.0
		
		if debug_enabled:
			print("🤖 BOSS: Positioning complete")

func _apply_safe_physics(delta: float) -> void:
	"""Apply gravity safely"""
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

func _check_wall_collisions() -> void:
	"""Check for wall collisions during movement"""
	if velocity.length() < 0.1:
		return
		
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		
		if collider and _is_wall(collider):
			_break_wall(collider)

func _force_break_nearby_walls() -> void:
	"""Break walls in radius around boss"""
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = wall_break_radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = global_position
	query.collision_mask = 1 << 1  # Wall layer only
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)
			walls_broken_this_frame += 1

func _break_walls_in_movement_direction() -> void:
	"""Break walls in movement direction"""
	var movement_direction = Vector3(velocity.x, 0, velocity.z).normalized()
	var check_position = global_position + movement_direction * 2.0
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 1.5
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = check_position
	query.collision_mask = 1 << 1
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)

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

func take_damage(amount: int, _source: Node = null) -> void:
	"""Take damage"""
	health -= amount
	
	if debug_enabled:
		print("🤖 BOSS: Took ", amount, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		current_state = BossState.DYING

func _debug_status() -> void:
	"""Debug output"""
	if not debug_enabled:
		return
	
	var state_names = ["SPAWNING", "POSITIONING", "IDLE", "MOVING", "CHARGING", 
					   "LEAP_WIND_UP", "LEAPING", "SLAM_WIND_UP", "SLAMMING", 
					   "THROW_WIND_UP", "THROWING", "STUNNED", "DYING"]
	var state_name = state_names[current_state] if current_state < state_names.size() else "UNKNOWN"
	
	print("🤖 ENHANCED BOSS STATUS:")
	print("  State: ", state_name, " Timer: ", state_timer)
	print("  Health: ", health, "/", max_health)
	print("  Attack Cooldown: ", attack_cooldown)
	print("  Position: ", global_position)
	print("  On Floor: ", is_on_floor())
	
	if player:
		var distance = global_position.distance_to(player.global_position)
		print("  Distance to Player: ", distance)
