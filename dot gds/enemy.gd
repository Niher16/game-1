# enemy.gd - Natural Slime Enemy with Telegraph Attack System
extends CharacterBody3D

signal enemy_died

@export var health = 30
@export var max_health = 30
@export var speed = 2.0
@export var chase_range = 100.0
@export var attack_range = 1.5
@export var attack_damage = 5
@export var attack_cooldown = 2.0
@export var slide_force = 1.5
@export var separation_distance = 1.2
@export var max_slide_speed = 2.0
@export var slide_damping = 0.85
@export var knockback_force = 15.0
@export var knockback_duration = 0.8
var knockback_velocity = Vector3.ZERO
var knockback_timer = 0.0
var is_being_knocked_back = false

var slime_scale = Vector3.ONE
var base_scale = Vector3.ONE
var animation_timer = 0.0
var damage_flash_timer = 0.0
var movement_intensity = 0.0

enum AnimState { IDLE, MOVING, ATTACKING, DAMAGED, SPAWNING, TELEGRAPHING }
var current_anim_state = AnimState.SPAWNING

var is_telegraphing = false
var telegraph_timer = 0.0
const TELEGRAPH_DURATION = 1.0
var telegraph_start_scale = Vector3.ONE
var telegraph_start_color = Color.WHITE

var spawn_timer = 0.0
var is_spawn_complete = false
const SPAWN_DURATION = 0.8

var player: CharacterBody3D
var last_attack_time = 0.0
var is_dead = false
var is_jumping = false

var jump_start_pos = Vector3.ZERO
var jump_target_pos = Vector3.ZERO
var jump_timer = 0.0
var jump_duration = 0.6
var is_anticipating_jump = false

enum AIState { SPAWNING, IDLE, PATROL, CHASE, TELEGRAPH, ATTACK }
var current_state = AIState.SPAWNING
var state_timer = 0.0
var patrol_target = Vector3.ZERO
var home_position = Vector3.ZERO

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_mesh_scale: Vector3

const DEFAULT_SLIME_COLOR = Color(0.2, 0.7, 0.2, 0.95)
var slime_material: StandardMaterial3D

var player_check_timer = 0.0
const PLAYER_CHECK_INTERVAL = 0.2
var cached_distance = 999.0
var cached_player_pos = Vector3.ZERO

var slide_velocity = Vector3.ZERO
var last_valid_position = Vector3.ZERO

@export var enabled := true

func _ready():
	_connect_to_scene_nodes()
	_setup_physics()
	_setup_slime_material()
	call_deferred("_delayed_init")

func _connect_to_scene_nodes():
	mesh_instance = get_node("MeshInstance3D")
	collision_shape = get_node("CollisionShape3D")
	
	if mesh_instance and is_instance_valid(mesh_instance):
		original_mesh_scale = mesh_instance.scale
		base_scale = original_mesh_scale
		slime_scale = original_mesh_scale
		mesh_instance.visible = true
		# Ensure the mesh casts shadows
		mesh_instance.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
		# Try double sided shadow if mesh is single sided
		if mesh_instance.has_method("set_cast_shadows_setting"):
			mesh_instance.set_cast_shadows_setting(MeshInstance3D.SHADOW_CASTING_SETTING_ON)
	else:
		base_scale = Vector3.ONE
		slime_scale = Vector3.ONE
	
	if collision_shape and is_instance_valid(collision_shape):
		pass

func _setup_slime_material():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	
	slime_material = StandardMaterial3D.new()
	slime_material.albedo_color = DEFAULT_SLIME_COLOR
	slime_material.metallic = 0.0
	slime_material.roughness = 0.3
	# Disable transparency for shadow casting
	slime_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mesh_instance.material_override = slime_material

func _setup_physics():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2 | 8  # Enemies detect allies (layer 8)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	max_health = health
	velocity = Vector3.ZERO

func _delayed_init():
	await get_tree().process_frame
	_find_player()
	_correct_spawn_position()
	_set_home()

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if player:
		cached_player_pos = player.global_position

func _correct_spawn_position():
	if global_position.y < 1.0:
		global_position.y = 2.0
	velocity.y = 0
	for i in range(10):
		_apply_gravity(get_physics_process_delta_time())
		move_and_slide()
		if is_on_floor():
			break

func _set_home():
	await get_tree().create_timer(0.5).timeout
	home_position = global_position
	patrol_target = home_position

func _physics_process(delta):
	if not enabled:
		velocity = Vector3.ZERO
		if mesh_instance and is_instance_valid(mesh_instance):
			mesh_instance.visible = false
		return

	_update_cache(delta)

	if not is_spawn_complete:
		_handle_spawn_animation(delta)
	else:
		_handle_ai(delta)
		_handle_slime_animation(delta)
		_process_telegraph(delta)  # Critical for telegraph system!

	_handle_knockback(delta)
	_handle_enemy_separation(delta)
	_apply_sliding(delta)
	_apply_gravity(delta)
	_handle_jump_movement(delta)

	move_and_slide()
	_prevent_wall_clipping()

	# Player collision damage (but not during telegraph!)
	if _is_player_valid() and not is_dead and not is_jumping and not is_being_knocked_back and not is_telegraphing:
		var player_dist = global_position.distance_to(player.global_position)
		if player_dist <= 1.2:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage, self)

func _process_telegraph(delta):
	"""Handle telegraph animation - this is the key function that was missing!"""
	if is_telegraphing:
		telegraph_timer -= delta
		
		# Pulse effect - makes slime bigger and redder
		var pulse = sin((TELEGRAPH_DURATION - telegraph_timer) * 15.0) * 0.2 + 1.0
		slime_scale = telegraph_start_scale * pulse
		if mesh_instance:
			mesh_instance.scale = slime_scale
		
		# Red warning color
		if slime_material:
			var red_intensity = 1.0 - (telegraph_timer / TELEGRAPH_DURATION)
			slime_material.albedo_color = Color.RED.lerp(telegraph_start_color, red_intensity)
		
		# Telegraph finished - now attack!
		if telegraph_timer <= 0.0:
			is_telegraphing = false
			slime_scale = telegraph_start_scale
			if slime_material:
				slime_material.albedo_color = telegraph_start_color
			_execute_actual_attack()

func start_attack_telegraph(target: Node3D):
	"""Begins the attack warning phase - gives player time to react"""
	is_telegraphing = true
	telegraph_timer = TELEGRAPH_DURATION
	current_anim_state = AnimState.TELEGRAPHING
	current_state = AIState.TELEGRAPH
	
	# Store original values
	telegraph_start_scale = slime_scale
	telegraph_start_color = slime_material.albedo_color if slime_material else Color.WHITE
	
	# Optional: Play warning sound if AudioStreamPlayer3D exists
	var audio_player = get_node_or_null("AttackWarningSound")
	if audio_player:
		audio_player.play()

	# Face the target
	_face_target(target)

func _execute_actual_attack():
	"""Actually performs the attack after telegraph warning"""
	current_anim_state = AnimState.ATTACKING
	current_state = AIState.ATTACK
	
	# Now do the actual jump/damage
	var target = _find_nearest_target()
	_perform_jump_attack(target)
	
	# Start recovery after attack
	_start_attack_recovery()

func _perform_jump_attack(target: Node3D):
	"""Bridge function - called by _execute_actual_attack"""
	if not target or is_jumping:
		return
	
	is_jumping = true
	jump_timer = 0.0
	jump_start_pos = global_position
	jump_target_pos = target.global_position
	
	# Face the target during jump
	_face_target(target)

func _start_attack_recovery():
	"""After attack, enter recovery phase (vulnerable)"""
	await get_tree().create_timer(0.5).timeout
	current_state = AIState.IDLE
	current_anim_state = AnimState.IDLE

func _handle_slime_animation(delta):
	animation_timer += delta
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
	
	# Update movement intensity based on velocity
	var target_intensity = min(velocity.length() / speed, 1.0)
	movement_intensity = lerp(movement_intensity, target_intensity, 5.0 * delta)
	
	# Determine current animation state
	_update_animation_state()
	
	# Apply subtle slime deformation
	_apply_slime_deformation(delta)

func _update_animation_state():
	if is_telegraphing:
		current_anim_state = AnimState.TELEGRAPHING
	elif is_anticipating_jump:
		current_anim_state = AnimState.ATTACKING
	elif damage_flash_timer > 0.0:
		current_anim_state = AnimState.DAMAGED
	elif velocity.length() > 0.3:
		current_anim_state = AnimState.MOVING
	else:
		current_anim_state = AnimState.IDLE

func _apply_slime_deformation(delta):
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	
	var target_scale = base_scale
	
	match current_anim_state:
		AnimState.IDLE:
			# Gentle breathing animation
			var breathing = sin(animation_timer * 1.5) * 0.03 + 1.0
			target_scale.y = base_scale.y * breathing
			target_scale.x = base_scale.x * (2.0 - breathing) * 0.15 + base_scale.x * 0.85
			target_scale.z = base_scale.z * (2.0 - breathing) * 0.15 + base_scale.z * 0.85
		
		AnimState.MOVING:
			# Subtle bouncy movement
			var bounce_freq = 6.0 + movement_intensity * 4.0
			var bounce = sin(animation_timer * bounce_freq) * 0.06 * movement_intensity + 1.0
			target_scale.y = base_scale.y * bounce
			target_scale.x = base_scale.x * (2.0 - bounce) * 0.2 + base_scale.x * 0.8
			target_scale.z = base_scale.z * (2.0 - bounce) * 0.2 + base_scale.z * 0.8
		
		AnimState.ATTACKING:
			# Slight crouch before attack
			var crouch = sin(animation_timer * 8.0) * 0.05 + 0.9
			target_scale.y = base_scale.y * crouch
			target_scale.x = base_scale.x * (2.0 - crouch) * 0.3 + base_scale.x * 0.7
			target_scale.z = base_scale.z * (2.0 - crouch) * 0.3 + base_scale.z * 0.7
		
		AnimState.DAMAGED:
			# Quick squash when damaged
			var damage_squash = sin(damage_flash_timer * 20.0) * 0.1 + 0.9
			target_scale.y = base_scale.y * damage_squash
			target_scale.x = base_scale.x * (2.0 - damage_squash) * 0.4 + base_scale.x * 0.6
			target_scale.z = base_scale.z * (2.0 - damage_squash) * 0.4 + base_scale.z * 0.6
		
		AnimState.TELEGRAPHING:
			# Special telegraph animation (handled in _process_telegraph)
			pass
	
	# Smooth interpolation (but skip during telegraph - that's handled separately)
	if not is_telegraphing:
		slime_scale = slime_scale.lerp(target_scale, 8.0 * delta)
		mesh_instance.scale = slime_scale

func _handle_spawn_animation(delta):
	spawn_timer += delta
	velocity = Vector3.ZERO
	
	if mesh_instance and is_instance_valid(mesh_instance):
		var progress = min(spawn_timer / SPAWN_DURATION, 1.0)
		var scale_factor = smoothstep(0.0, 1.0, progress)
		
		# Slime grows from a flat puddle
		var spawn_scale = base_scale * scale_factor
		spawn_scale.y *= (0.3 + 0.7 * progress)
		
		# Add slight spawn wobble
		if progress > 0.4:
			var wobble = sin(spawn_timer * 8.0) * 0.03 * (1.0 - progress)
			spawn_scale.y += wobble
		
		mesh_instance.scale = spawn_scale
	
	if spawn_timer >= SPAWN_DURATION:
		is_spawn_complete = true
		current_state = AIState.IDLE
		if mesh_instance:
			mesh_instance.scale = base_scale

func _handle_knockback(delta):
	if knockback_timer > 0:
		knockback_timer -= delta
		var decay_factor = knockback_timer / knockback_duration
		velocity.x = knockback_velocity.x * decay_factor
		velocity.z = knockback_velocity.z * decay_factor
		if knockback_timer <= 0:
			knockback_velocity = Vector3.ZERO
			is_being_knocked_back = false

func _apply_knockback_from_player():
	if not _is_player_valid():
		return
	var direction = (global_position - player.global_position)
	direction.y = 0
	direction = direction.normalized() if direction.length() > 0.1 else Vector3.RIGHT
	knockback_velocity = direction * knockback_force
	knockback_timer = knockback_duration
	is_being_knocked_back = true
	current_state = AIState.IDLE

func _handle_enemy_separation(delta):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var separation_force = Vector3.ZERO
	var terrain = get_tree().get_first_node_in_group("terrain")
	var map_size = Vector2(60, 60)
	if terrain and "map_size" in terrain:
		map_size = terrain.map_size
	
	for other in enemies:
		if other == self or not _is_valid_instance(other): continue
		if "is_dead" in other and other.is_dead: continue
		var distance = global_position.distance_to(other.global_position)
		if distance < separation_distance and distance > 0.1:
			var direction = (global_position - other.global_position)
			direction.y = 0
			direction = direction.normalized()
			var force_strength = (separation_distance - distance) * 0.5
			var force = direction * force_strength
			if not _would_hit_wall(global_position, direction, map_size, terrain):
				separation_force += force
	
	slide_velocity += separation_force * slide_force * delta * 0.3
	var max_slide = max_slide_speed * 0.7
	slide_velocity.x = clamp(slide_velocity.x, -max_slide, max_slide)
	slide_velocity.z = clamp(slide_velocity.z, -max_slide, max_slide)

func _would_hit_wall(pos: Vector3, dir: Vector3, map_size: Vector2, terrain) -> bool:
	if not terrain or not terrain.has_method("_is_valid_pos"):
		return false
	var test_pos = pos + dir.normalized() * 0.5
	var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
	var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
	return not terrain._is_valid_pos(test_grid_x, test_grid_y)

func _apply_sliding(delta):
	velocity.x += slide_velocity.x * delta
	velocity.z += slide_velocity.z * delta
	slide_velocity *= slide_damping
	if slide_velocity.length() < 0.1:
		slide_velocity = Vector3.ZERO

func _prevent_wall_clipping():
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
		var try_offsets = [
			Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1),
			Vector3(1,0,1), Vector3(-1,0,1), Vector3(1,0,-1), Vector3(-1,0,-1),
			Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2), Vector3(0,0,-2)
		]
		var found = false
		for offset in try_offsets:
			if found: break
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
			global_position = last_valid_position
		velocity = Vector3.ZERO
		slide_velocity = Vector3.ZERO
	
	if global_position.y < 0.8:
		global_position.y = 0.8
		velocity.y = max(0, velocity.y)
		slide_velocity = Vector3.ZERO

func _update_cache(delta):
	player_check_timer += delta
	if player_check_timer >= PLAYER_CHECK_INTERVAL and _is_player_valid():
		cached_player_pos = player.global_position
		cached_distance = global_position.distance_to(player.global_position)
		player_check_timer = 0.0

func _is_player_valid() -> bool:
	return player and is_instance_valid(player) and not ("is_dead" in player and player.is_dead)

func _find_nearest_target() -> Node3D:
	var closest_target: Node3D = null
	var closest_distance = 999.0
	
	# Check player first
	if _is_player_valid():
		closest_distance = global_position.distance_to(player.global_position)
		closest_target = player
	
	# Check all allies
	var allies = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		if "health_component" in ally and ally.health_component and "current_health" in ally.health_component and ally.health_component.current_health <= 0:
			continue
		var distance = global_position.distance_to(ally.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = ally
	
	return closest_target

func _is_valid_instance(node):
	return node and is_instance_valid(node)

func _handle_ai(delta):
	state_timer += delta
	match current_state:
		AIState.IDLE:
			velocity = Vector3.ZERO
			if cached_distance <= chase_range:
				current_state = AIState.CHASE
			elif state_timer >= 2.0:
				current_state = AIState.PATROL
				_set_patrol_target()
				# Add idle fidgeting
				if randf() < 0.1 * delta:
					velocity.x = randf_range(-0.5, 0.5)
					velocity.z = randf_range(-0.5, 0.5)

		AIState.PATROL:
			if cached_distance <= chase_range:
				current_state = AIState.CHASE
			else:
				_move_to_target(patrol_target, speed * 0.5)
				# Add random pauses and direction changes
				if randf() < 0.05 * delta:
					_set_patrol_target()
				if global_position.distance_to(patrol_target) < 1.0 or state_timer > 4.0:
					_set_patrol_target()
					state_timer = 0.0

		AIState.CHASE:
			_handle_chase_state_natural(delta)

		AIState.ATTACK:
			_handle_attack_state_natural(delta)
		
		AIState.TELEGRAPH:
			# During telegraph, just stay still and let _process_telegraph handle visuals
			velocity = Vector3.ZERO

func _set_patrol_target():
	var angle = randf() * TAU
	var distance = randf_range(1.0, 3.0)
	patrol_target = home_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

func _move_to_target(target: Vector3, move_speed: float):
	var direction = (target - global_position)
	direction.y = 0
	if direction.length() > 0.8:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity = Vector3.ZERO

func _face_target(target: Node3D):
	if not target or is_being_knocked_back:
		return
	var direction_to_target = (target.global_position - global_position)
	direction_to_target.y = 0
	if direction_to_target.length() > 0.1:
		direction_to_target = direction_to_target.normalized()
		var target_rotation_y = atan2(direction_to_target.x, direction_to_target.z)
		var rotation_speed = 6.0
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * get_physics_process_delta_time())

func _handle_chase_state_natural(delta):
	var target = _find_nearest_target()
	if not target:
		current_state = AIState.PATROL
		return

	cached_distance = global_position.distance_to(target.global_position)
	if cached_distance <= attack_range:
		current_state = AIState.ATTACK
		return

	if cached_distance > chase_range:
		current_state = AIState.PATROL
		return

	# Add zig-zag and hesitation to movement
	var direction = (target.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.8:
		direction = direction.normalized()
		# Zig-zag offset using Time.get_ticks_msec()
		var t = Time.get_ticks_msec() * 0.001
		var zigzag = Vector3(
			sin(t * randf_range(2.0, 3.5)) * 0.5,
			0,
			cos(t * randf_range(2.0, 3.5)) * 0.5
		)
		var hesitation = randf() < 0.05 * delta
		if hesitation:
			velocity = Vector3.ZERO
		else:
			velocity.x = direction.x * speed + zigzag.x
			velocity.z = direction.z * speed + zigzag.z
	_face_target(target)

func _handle_attack_state_natural(_delta):
	var target = _find_nearest_target()
	if not target:
		current_state = AIState.IDLE
		return

	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range * 1.2:
		current_state = AIState.CHASE
		return

	# Only start telegraph if not already telegraphing and cooldown ready
	if not is_telegraphing and not is_jumping and Time.get_unix_time_from_system() - last_attack_time >= attack_cooldown:
		start_attack_telegraph(target)
		last_attack_time = Time.get_unix_time_from_system()

func _handle_jump_movement(delta):
	if not is_jumping:
		return
	
	jump_timer += delta
	var progress = jump_timer / jump_duration
	
	if progress >= 1.0:
		_complete_slime_jump_attack()
		return
	
	# Simple arc trajectory
	var horizontal = jump_start_pos.lerp(jump_target_pos, progress)
	var height = jump_start_pos.y + (2.5 * sin(progress * PI))
	global_position = Vector3(horizontal.x, height, horizontal.z)

func _complete_slime_jump_attack():
	is_jumping = false
	jump_timer = 0.0
	global_position = Vector3(jump_target_pos.x, jump_start_pos.y, jump_target_pos.z)
	
	# Damage nearby targets
	var target = _find_nearest_target()
	if target and global_position.distance_to(target.global_position) <= attack_range * 1.5:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, self)
		elif "health_component" in target and target.health_component.has_method("take_damage"):
			target.health_component.take_damage(attack_damage, self)
	
	current_state = AIState.IDLE

func _apply_gravity(delta):
	if not is_on_floor() and not is_jumping:
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	# Prevent being pushed into the ground
	if is_on_floor() and velocity.y < 0:
		velocity.y = 0

func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	damage_flash_timer = 0.3
	_flash_damage()
	_apply_knockback_from_player()
	
	if health <= 0:
		die()

func _flash_damage():
	if not slime_material:
		return
	
	# Brief red flash
	slime_material.albedo_color = Color(0.8, 0.2, 0.2, 0.95)
	await get_tree().create_timer(0.1).timeout
	
	if slime_material:
		slime_material.albedo_color = DEFAULT_SLIME_COLOR

func die():
	if is_dead:
		return
	is_dead = true

	# Simple death animation
	if mesh_instance and is_instance_valid(mesh_instance):
		var tween = create_tween()
		tween.parallel().tween_property(mesh_instance, "scale:y", 0.2, 0.4)
		tween.parallel().tween_property(mesh_instance, "scale:x", base_scale.x * 1.5, 0.4)
		tween.parallel().tween_property(mesh_instance, "scale:z", base_scale.z * 1.5, 0.4)
		if slime_material:
			tween.parallel().tween_property(slime_material, "albedo_color:a", 0.0, 0.6)

	# Drop loot
	if LootManager:
		LootManager.drop_enemy_loot(global_position, self)

	# 30% chance to spawn a health potion (new logic)
	on_enemy_death()

	if randf() < 0.05:
		_drop_weapon()

	enemy_died.emit()

	await get_tree().create_timer(0.3).timeout
	queue_free()

# Remove or comment out any old health potion drop logic elsewhere in this script

func _drop_weapon():
	if LootManager and LootManager.has_method("drop_weapon"):
		if "weapon_resource" in self and self.weapon_resource:
			LootManager.drop_weapon(global_position, self.weapon_resource)
		else:
			LootManager.drop_weapon(global_position)

# Utility: Call this on enemy death to possibly spawn a health potion
func on_enemy_death():
	if randf() < 0.3:  # 30% chance
		if LootManager and LootManager.has_method("spawn_health_potion"):
			LootManager.spawn_health_potion(global_position)
