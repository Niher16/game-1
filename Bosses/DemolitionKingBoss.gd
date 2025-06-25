# demolition_king_boss.gd - The Demolition King Boss Fight
# Fixed following Godot 4.1 best practices for unused parameters
extends CharacterBody3D

signal boss_died
signal phase_changed(new_phase: int)
signal wall_destroyed(position: Vector3)

# === BOSS STATS ===
@export var max_health = 200
@export var health = 200
@export var speed = 4.0
@export var charge_speed = 12.0
@export var jump_force = 8.0
@export var attack_damage = 15

# === PHASE MANAGEMENT ===
enum BossPhase { ENTRANCE, PHASE_1, PHASE_2, DEATH }
var current_phase = BossPhase.ENTRANCE
var phase_1_threshold = 0.5  # 50% health

# === BOSS STATES ===
enum BossState { 
	ENTRANCE_JUMPING, 
	IDLE, 
	TELEGRAPH_CHARGE, 
	CHARGING, 
	TELEGRAPH_JUMP, 
	JUMPING, 
	SPAWNING_SLIMES,
	THROWING_CHUNKS,
	STUNNED,
	DYING
}
var current_state = BossState.ENTRANCE_JUMPING

# === ATTACK SYSTEMS ===
var telegraph_timer = 0.0
var attack_cooldown_timer = 0.0
var state_timer = 0.0

# Telegraph durations
const CHARGE_TELEGRAPH_TIME = 1.5
const JUMP_TELEGRAPH_TIME = 1.2
const SPAWN_TELEGRAPH_TIME = 2.0

# Attack cooldowns
const CHARGE_COOLDOWN = 3.0
const JUMP_COOLDOWN = 4.0
const SPAWN_COOLDOWN = 6.0
const THROW_COOLDOWN = 2.0

# === ENTRANCE SEQUENCE ===
var entrance_jumps_completed = 0
var entrance_jump_targets = []
var entrance_jump_timer = 0.0
var entrance_complete = false

# === CHARGE ATTACK ===
var charge_start_pos = Vector3.ZERO
var charge_target_pos = Vector3.ZERO
var charge_direction = Vector3.ZERO
var is_charging = false
var charge_distance = 0.0

# === JUMP ATTACK ===
var jump_start_pos = Vector3.ZERO
var jump_target_pos = Vector3.ZERO
var jump_timer = 0.0
var jump_duration = 1.0
var is_jumping = false

# === WALL BREAKING ===
var walls_to_break = []
var wall_break_radius = 3.0
var charge_wall_break_width = 4.0

# === SLIME SPAWNING (Phase 2) ===
var slime_spawn_positions = []
var slimes_spawned_this_wave = 0
var max_slimes_per_wave = 3
var active_slimes = []

# === PROJECTILE SYSTEM (Phase 2) ===
var wall_chunks = []
var chunk_throw_force = 15.0

# === EXPORT VARIABLES (These create the Inspector fields) ===
@export var slime_scene: PackedScene
@export var wall_chunk_scene: PackedScene

# === SCENE REFERENCES ===
var player: CharacterBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_scale: Vector3

# === VISUAL EFFECTS ===
var boss_material: StandardMaterial3D
var flash_timer = 0.0
var telegraph_intensity = 0.0

# === PHYSICS ===
var knockback_velocity = Vector3.ZERO
var is_on_ground = true

func _ready():
	print("👑 DEMOLITION KING: Awakening...")
	_setup_boss()
	_setup_entrance_sequence()
	call_deferred("_start_boss_fight")

func _setup_boss():
	# Get scene components
	mesh_instance = get_node("MeshInstance3D")
	collision_shape = get_node("CollisionShape3D")
	
	if mesh_instance:
		original_scale = mesh_instance.scale
		_setup_boss_material()
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Physics setup
	add_to_group("bosses")
	add_to_group("enemies")
	collision_layer = 4  # Boss layer
	collision_mask = 1 | 8  # World + walls

func _setup_boss_material():
	boss_material = StandardMaterial3D.new()
	boss_material.albedo_color = Color(0.8, 0.2, 0.1, 1.0)  # Menacing red
	boss_material.metallic = 0.2
	boss_material.roughness = 0.4
	boss_material.emission_enabled = true
	boss_material.emission = Color(0.3, 0.1, 0.0)
	mesh_instance.material_override = boss_material

func _setup_entrance_sequence():
	# Calculate dramatic entrance jump positions
	if player:
		var arena_center = player.global_position
		
		# Create 3 jump positions leading to center
		entrance_jump_targets = [
			arena_center + Vector3(12, 0, 8),   # Back-right
			arena_center + Vector3(-8, 0, 6),   # Back-left  
			arena_center + Vector3(4, 0, -10),  # Front-right
			arena_center                        # Final landing
		]
		
		# Start at first position, elevated
		global_position = entrance_jump_targets[0] + Vector3(0, 15, 0)

func _start_boss_fight():
	print("🎬 DEMOLITION KING: ENTRANCE BEGINS!")
	current_state = BossState.ENTRANCE_JUMPING
	_begin_entrance_jump()

func _physics_process(delta):
	_update_timers(delta)
	_handle_boss_state(delta)
	_update_visual_effects()  # FIXED: Removed delta parameter
	_apply_physics(delta)
	
	move_and_slide()

func _update_timers(delta):
	if telegraph_timer > 0:
		telegraph_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if flash_timer > 0:
		flash_timer -= delta
	
	state_timer += delta

func _handle_boss_state(delta):
	match current_state:
		BossState.ENTRANCE_JUMPING:
			_handle_entrance_sequence(delta)
		BossState.IDLE:
			_handle_idle_state()  # FIXED: Removed unused delta parameter
		BossState.TELEGRAPH_CHARGE:
			_handle_charge_telegraph()  # FIXED: Removed unused delta parameter
		BossState.CHARGING:
			_handle_charge_attack()  # FIXED: Removed unused delta parameter
		BossState.TELEGRAPH_JUMP:
			_handle_jump_telegraph()  # FIXED: Removed unused delta parameter
		BossState.JUMPING:
			_handle_jump_attack(delta)
		BossState.SPAWNING_SLIMES:
			_handle_slime_spawning()  # FIXED: Removed unused delta parameter
		BossState.THROWING_CHUNKS:
			_handle_chunk_throwing()  # FIXED: Removed unused delta parameter
		BossState.STUNNED:
			_handle_stunned_state()  # FIXED: Removed unused delta parameter
		BossState.DYING:
			_handle_death_sequence(delta)

# === ENTRANCE SEQUENCE ===
func _handle_entrance_sequence(delta):
	entrance_jump_timer += delta
	
	# Dramatic falling jump with wall breaking
	if entrance_jump_timer >= 1.0:  # Each jump takes 1 second
		_complete_entrance_jump()
		entrance_jumps_completed += 1
		entrance_jump_timer = 0.0
		
		if entrance_jumps_completed < entrance_jump_targets.size():
			_begin_entrance_jump()
		else:
			_complete_entrance_sequence()

func _begin_entrance_jump():
	var target_pos = entrance_jump_targets[entrance_jumps_completed]
	
	# Set jump trajectory
	jump_start_pos = global_position
	jump_target_pos = target_pos
	jump_timer = 0.0
	is_jumping = true
	
	print("💥 Entrance jump ", entrance_jumps_completed + 1)

func _complete_entrance_jump():
	is_jumping = false
	global_position = jump_target_pos
	
	# Break walls at landing site
	_break_walls_at_position(global_position, wall_break_radius)
	_create_landing_impact()
	
	print("🔥 WALL SMASH at: ", global_position)

func _complete_entrance_sequence():
	print("👑 DEMOLITION KING: I HAVE ARRIVED!")
	entrance_complete = true
	current_phase = BossPhase.PHASE_1
	current_state = BossState.IDLE
	phase_changed.emit(1)

# === PHASE 1: CHARGE & JUMP ATTACKS ===
func _handle_idle_state():  # FIXED: Removed unused delta parameter
	if not player:
		return
	
	# Phase transition check
	if health <= max_health * phase_1_threshold and current_phase == BossPhase.PHASE_1:
		_transition_to_phase_2()
		return
	
	# Attack decision making
	if attack_cooldown_timer <= 0:
		_choose_next_attack()

func _choose_next_attack():
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if current_phase == BossPhase.PHASE_1:
		# Phase 1: Charge and Jump attacks
		if distance_to_player > 8.0 and randf() < 0.7:
			_start_charge_attack()
		else:
			_start_jump_attack()
	
	elif current_phase == BossPhase.PHASE_2:
		# Phase 2: Spawning and throwing
		if len(active_slimes) < max_slimes_per_wave and randf() < 0.6:
			_start_slime_spawning()
		else:
			_start_chunk_throwing()

# === CHARGE ATTACK ===
func _start_charge_attack():
	print("⚡ Boss charging up CHARGE ATTACK!")
	current_state = BossState.TELEGRAPH_CHARGE
	telegraph_timer = CHARGE_TELEGRAPH_TIME
	
	# Calculate charge path
	charge_start_pos = global_position
	charge_target_pos = player.global_position
	charge_direction = (charge_target_pos - charge_start_pos).normalized()
	
	# Extend charge to hit walls
	charge_target_pos = charge_start_pos + charge_direction * 20.0
	
	_face_direction(charge_direction)

func _handle_charge_telegraph():  # FIXED: Removed unused delta parameter
	# Visual telegraph - grow larger and glow red
	telegraph_intensity = sin((CHARGE_TELEGRAPH_TIME - telegraph_timer) * 8.0) * 0.3 + 0.7
	
	if mesh_instance:
		var scale_mult = 1.0 + telegraph_intensity * 0.4
		mesh_instance.scale = original_scale * scale_mult
	
	if boss_material:
		boss_material.emission = Color(0.8, 0.1, 0.0) * telegraph_intensity
	
	if telegraph_timer <= 0:
		_execute_charge_attack()

func _execute_charge_attack():
	print("💨 CHARGE ATTACK EXECUTING!")
	current_state = BossState.CHARGING
	is_charging = true
	velocity = charge_direction * charge_speed
	
	# Reset visual
	if mesh_instance:
		mesh_instance.scale = original_scale
	if boss_material:
		boss_material.emission = Color(0.3, 0.1, 0.0)

func _handle_charge_attack():  # FIXED: Removed unused delta parameter
	if not is_charging:
		return
	
	# Check for wall collisions during charge
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		
		# Hit wall - break it!
		if collider and collider.is_in_group("walls"):
			_break_walls_along_charge_path()
			_end_charge_attack()
			return
		
		# Hit player
		elif collider and collider.is_in_group("player"):
			_damage_player()
			_end_charge_attack()
			return
	
	# Check if charge distance completed
	var distance_traveled = global_position.distance_to(charge_start_pos)
	if distance_traveled >= 20.0:
		_end_charge_attack()

func _break_walls_along_charge_path():
	# Break walls in a line along the charge
	var steps = int(charge_distance / 2.0)
	for i in range(steps):
		var pos = charge_start_pos.lerp(global_position, float(i) / steps)
		_break_walls_at_position(pos, charge_wall_break_width)

func _end_charge_attack():
	print("🛑 Charge attack ended")
	is_charging = false
	velocity = Vector3.ZERO
	current_state = BossState.STUNNED
	state_timer = 0.0
	attack_cooldown_timer = CHARGE_COOLDOWN

# === JUMP ATTACK ===
func _start_jump_attack():
	print("🦘 Boss preparing JUMP ATTACK!")
	current_state = BossState.TELEGRAPH_JUMP
	telegraph_timer = JUMP_TELEGRAPH_TIME
	
	jump_target_pos = player.global_position
	_face_direction((jump_target_pos - global_position).normalized())

func _handle_jump_telegraph():  # FIXED: Removed unused delta parameter
	# Crouch and glow for jump
	telegraph_intensity = sin((JUMP_TELEGRAPH_TIME - telegraph_timer) * 6.0) * 0.5 + 0.5
	
	if mesh_instance:
		var crouch_scale = original_scale
		crouch_scale.y *= 0.7 + telegraph_intensity * 0.3
		crouch_scale.x *= 1.2 - telegraph_intensity * 0.2
		crouch_scale.z *= 1.2 - telegraph_intensity * 0.2
		mesh_instance.scale = crouch_scale
	
	if telegraph_timer <= 0:
		_execute_jump_attack()

func _execute_jump_attack():
	print("🚀 JUMP ATTACK EXECUTING!")
	current_state = BossState.JUMPING
	is_jumping = true
	jump_timer = 0.0
	jump_start_pos = global_position
	
	# Reset visual
	if mesh_instance:
		mesh_instance.scale = original_scale

func _handle_jump_attack(delta):
	jump_timer += delta
	var progress = jump_timer / jump_duration
	
	if progress >= 1.0:
		_complete_jump_attack()
		return
	
	# Arc trajectory
	var horizontal = jump_start_pos.lerp(jump_target_pos, progress)
	var height = jump_start_pos.y + (8.0 * sin(progress * PI))
	global_position = Vector3(horizontal.x, height, horizontal.z)

func _complete_jump_attack():
	is_jumping = false
	global_position = Vector3(jump_target_pos.x, jump_start_pos.y, jump_target_pos.z)
	
	# Massive ground impact!
	_break_walls_at_position(global_position, wall_break_radius * 1.5)
	_create_ground_crack_effect()
	_damage_nearby_targets()
	
	current_state = BossState.STUNNED
	state_timer = 0.0
	attack_cooldown_timer = JUMP_COOLDOWN
	
	print("💥 MASSIVE GROUND IMPACT!")

# === PHASE 2: SPAWNING & THROWING ===
func _transition_to_phase_2():
	print("👑 DEMOLITION KING: PHASE 2 - I'M GETTING ANGRY!")
	current_phase = BossPhase.PHASE_2
	current_state = BossState.IDLE
	phase_changed.emit(2)
	
	# Visual change - make boss look more damaged/angry
	if boss_material:
		boss_material.albedo_color = Color(0.9, 0.1, 0.1)  # Angrier red
		boss_material.emission = Color(0.5, 0.0, 0.0)

func _start_slime_spawning():
	print("🟢 Boss spawning slimes!")
	current_state = BossState.SPAWNING_SLIMES
	telegraph_timer = SPAWN_TELEGRAPH_TIME
	_calculate_spawn_positions()

func _calculate_spawn_positions():
	slime_spawn_positions.clear()
	
	# Spawn slimes around the arena
	for i in range(max_slimes_per_wave):
		var angle = (PI * 2.0 / max_slimes_per_wave) * i
		var spawn_pos = global_position + Vector3(
			cos(angle) * 8.0,
			0,
			sin(angle) * 8.0
		)
		slime_spawn_positions.append(spawn_pos)

func _handle_slime_spawning():  # FIXED: Removed unused delta parameter
	# Telegraph where slimes will spawn
	telegraph_intensity = sin((SPAWN_TELEGRAPH_TIME - telegraph_timer) * 4.0) * 0.5 + 0.5
	
	if telegraph_timer <= 0:
		_execute_slime_spawning()

func _execute_slime_spawning():
	print("🌟 Spawning slimes now!")
	
	for pos in slime_spawn_positions:
		if slime_scene:
			var new_slime = slime_scene.instantiate()
			get_tree().current_scene.add_child(new_slime)
			new_slime.global_position = pos
			active_slimes.append(new_slime)
			
			# Connect death signal to track active slimes
			if new_slime.has_signal("enemy_died"):
				new_slime.enemy_died.connect(_on_slime_died.bind(new_slime))
	
	current_state = BossState.IDLE
	attack_cooldown_timer = SPAWN_COOLDOWN

func _on_slime_died(slime):
	if slime in active_slimes:
		active_slimes.erase(slime)

func _start_chunk_throwing():
	print("🪨 Boss throwing wall chunks!")
	current_state = BossState.THROWING_CHUNKS
	_throw_wall_chunk()

func _handle_chunk_throwing():  # FIXED: Removed unused delta parameter
	# Simple state - just wait for animation to complete
	if state_timer >= 1.0:
		current_state = BossState.IDLE
		attack_cooldown_timer = THROW_COOLDOWN

func _throw_wall_chunk():
	if not player or not wall_chunk_scene:
		return
	
	var chunk = wall_chunk_scene.instantiate()
	get_tree().current_scene.add_child(chunk)
	chunk.global_position = global_position + Vector3(0, 2, 0)
	
	# Calculate trajectory to player
	var direction = (player.global_position - chunk.global_position).normalized()
	if chunk.has_method("throw"):
		chunk.throw(direction * chunk_throw_force)
	elif chunk is RigidBody3D:
		chunk.linear_velocity = direction * chunk_throw_force

# === WALL BREAKING SYSTEM ===
func _break_walls_at_position(pos: Vector3, radius: float):
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = pos
	query.collision_mask = 8  # Wall layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var wall = result.collider
		if wall and wall.is_in_group("walls"):
			_destroy_wall(wall)

func _destroy_wall(wall: Node):
	print("💥 WALL DESTROYED!")
	wall_destroyed.emit(wall.global_position)
	
	# Simple wall destruction - just hide it
	if wall.has_method("break_wall"):
		wall.break_wall()
	else:
		wall.queue_free()

# === VISUAL EFFECTS ===
func _create_landing_impact():
	# Create screen shake or particle effect here
	# For now, just a simple print
	print("💥 GROUND IMPACT EFFECT!")

func _create_ground_crack_effect():
	# Create floor crack visual effect
	print("🌍 GROUND CRACKS APPEAR!")

# === DAMAGE & HEALTH ===
func take_damage(amount: int, _source = null):  # FIXED: Prefixed unused parameter with underscore
	if current_state == BossState.DYING:
		return
	
	health -= amount
	flash_timer = 0.5
	
	print("👑 Boss took ", amount, " damage! Health: ", health)
	
	# Flash red when damaged
	if boss_material:
		boss_material.albedo_color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if boss_material:
			boss_material.albedo_color = Color(0.8, 0.2, 0.1)
	
	if health <= 0:
		_start_death_sequence()

func _damage_player():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

func _damage_nearby_targets():
	var nearby = _get_nearby_targets(4.0)
	for target in nearby:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, self)

func _get_nearby_targets(radius: float) -> Array:
	var targets = []
	
	# Simple implementation - just check for player
	if player and global_position.distance_to(player.global_position) <= radius:
		targets.append(player)
	
	return targets

# === DEATH SEQUENCE ===
func _start_death_sequence():
	print("💀 DEMOLITION KING: NOOOOO!")
	current_state = BossState.DYING
	
	# Final explosion of wall breaking
	_break_walls_at_position(global_position, wall_break_radius * 2.0)
	
	boss_died.emit()

func _handle_death_sequence(delta):
	# Simple death animation
	if mesh_instance:
		mesh_instance.scale = mesh_instance.scale.lerp(Vector3.ZERO, 2.0 * delta)
	
	if state_timer >= 3.0:
		queue_free()

# === UTILITY FUNCTIONS ===
func _handle_stunned_state():  # FIXED: Removed unused delta parameter
	# Brief recovery period after attacks
	if state_timer >= 1.0:
		current_state = BossState.IDLE
		state_timer = 0.0

func _update_visual_effects():  # FIXED: Removed unused delta parameter
	# Handle damage flash
	if flash_timer > 0 and boss_material:
		var flash_intensity = sin(flash_timer * 20.0) * 0.5 + 0.5
		boss_material.emission = Color(1.0, 0.3, 0.3) * flash_intensity

func _face_direction(direction: Vector3):
	if direction.length() < 0.1:
		return
	var target_rotation = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

func _apply_physics(delta):
	# Apply gravity when not jumping
	if not is_jumping and not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	# Apply knockback
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 5.0 * delta)
