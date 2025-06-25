extends Node
# PlayerCombat.gd
# COORDINATE SYSTEM NOTE:
# - Player faces POSITIVE Z direction (forward)
# - All attack animations should use POSITIVE Z for forward movement
# - Negative Z = backwards, Positive Z = forwards
class_name PlayerCombat

# Signals for combat events and animation coordination
signal attack_started(combo_index: int)
signal attack_finished(combo_index: int)
signal enemy_hit(enemy: Node, damage: int, combo_index: int)
signal attack_state_changed(state: int) # For animation handoff
signal punch_animation_changed(is_animating: bool)

# Combat state enum (expanded)
enum CombatState { IDLE, ATTACKING, COMBO, BLOCKING, COOLDOWN }
var state: CombatState = CombatState.IDLE

# References
var player: CharacterBody3D = null
var weapon: WeaponResource = null
var movement_component: Node = null # Reference to PlayerMovement
var weapon_animation_player: AnimationPlayer = null # Reference to WeaponAnimationPlayer

# Hand animation references
var left_hand: MeshInstance3D = null
var right_hand: MeshInstance3D = null
var right_hand_original_pos: Vector3 = Vector3.ZERO
var right_hand_original_rot: Vector3 = Vector3.ZERO # <-- Add this line
var is_punch_animating: bool = false

# Attack/combo system
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.0
var combo_index: int = 0
var combo_max: int = 3
var combo_reset_time: float = 1.0
var last_combo_time: float = 0.0

var attack_timer: Timer = null

# --- Audio references ---
var punch_sounds = []
var whoosh_sound = null
var impact_sound = null

# Track if attack button is held
var attack_button_held: bool = false

func initialize(player_ref: CharacterBody3D, movement_ref: Node = null):
	player = player_ref
	movement_component = movement_ref
	state = CombatState.IDLE
	weapon = null
	last_attack_time = 0.0
	combo_index = 0
	last_combo_time = 0.0
	attack_cooldown = player.attack_cooldown if "attack_cooldown" in player else 1.0
	weapon_animation_player = player.get_node('WeaponAnimationPlayer')
	if weapon_animation_player:
		if not weapon_animation_player.is_connected("animation_finished", _on_animation_finished):
			weapon_animation_player.animation_finished.connect(_on_animation_finished)
	_setup_hand_references()
	# --- Audio setup ---
	punch_sounds = []
	for i in range(3):
		var node_name = "PunchSound%d" % i
		if player.has_node(node_name):
			punch_sounds.append(player.get_node(node_name))
	whoosh_sound = player.get_node_or_null("WhooshSound")
	impact_sound = player.get_node_or_null("ImpactSound")
	# Connect punch animation signal to movement for hand animation blocking
	if movement_component and movement_component.has_method("set_punch_animating"):
		punch_animation_changed.connect(
			func(is_animating):
				if movement_component and movement_component.has_method("set_punch_animating"):
					movement_component.set_punch_animating(is_animating)
					print("[Combat] punch_animation_changed signal delivered to movement_component: ", is_animating)
				else:
					print("[Combat] movement_component missing set_punch_animating()")
		)
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.one_shot = true
		attack_timer.wait_time = 0.01 # Minimum valid timer duration
		if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
			attack_timer.timeout.connect(_on_attack_timer_timeout)
		add_child(attack_timer)

func _setup_hand_references():
	left_hand = player.get_node_or_null("LeftHandAnchor/LeftHand")
	right_hand = player.get_node_or_null("RightHandAnchor/RightHand")
	if right_hand:
		right_hand_original_pos = right_hand.position
		right_hand_original_rot = right_hand.rotation # <-- Store original rotation
		print("✅ Combat: Found RightHand!")
	else:
		print("⚠️ Combat: RightHand not found!")
	if left_hand:
		print("✅ Combat: Found LeftHand!")
	else:
		print("⚠️ Combat: LeftHand not found!")


func set_weapon(_new_weapon: WeaponResource):
	# No longer needed; always get weapon from WeaponManager
	pass

func can_attack() -> bool:
	if movement_component and (
		movement_component.is_dashing or movement_component.is_being_knocked_back
	):
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Attack blocked: dashing or knocked back")
		return false
	# Timer is stopped when ready to attack, running when on cooldown
	return state == CombatState.IDLE and _attack_cooldown_ready()

func _attack_cooldown_ready() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	# Always get current cooldown from player (updated by WeaponManager)
	var current_cooldown = player.attack_cooldown if "attack_cooldown" in player else 1.0
	if attack_timer == null:
		return true
	return (now - last_attack_time) >= current_cooldown or attack_timer.is_stopped()

func handle_attack_input():
	# This is now handled by _input/_process for hold-to-attack
	pass

func _input(event):
	if event.is_action_pressed("attack"):
		attack_button_held = true
	elif event.is_action_released("attack"):
		attack_button_held = false

func _process(_delta):
	if attack_button_held:
		if can_attack():
			try_attack()

func try_attack():
	if not can_attack():
		return
	_start_attack_sequence()

func _start_attack_sequence():
	# Prevent overlapping attacks
	if state != CombatState.IDLE:
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Attack blocked: not IDLE (state=", state, ")")
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_combo_time > combo_reset_time:
		combo_index = 0
	else:
		combo_index = (combo_index + 1) % combo_max
	last_combo_time = now
	last_attack_time = now
	state = CombatState.ATTACKING
	print("[Combat][", now, "] State -> ATTACKING (combo ", combo_index, ")")
	attack_state_changed.emit(state)
	attack_started.emit(combo_index)
	_play_attack_animation(combo_index)
	# Windup phase
	attack_timer.stop()
	attack_timer.wait_time = 0.12
	attack_timer.start()
	# Use current player cooldown (includes weapon modifications)
	var current_cooldown = player.attack_cooldown if "attack_cooldown" in player else 1.0
	attack_timer.wait_time = current_cooldown

func _on_attack_timer_timeout():
	if state != CombatState.ATTACKING:
		print("[Combat][", Time.get_ticks_msec()/1000.0, "] Timer fired but not in ATTACKING state")
		return
	# Hit phase
	_damage_enemies_in_cone(combo_index)
	state = CombatState.COOLDOWN
	print("[Combat][", Time.get_ticks_msec()/1000.0, "] State -> COOLDOWN (combo ", combo_index, ")")
	attack_state_changed.emit(state)
	attack_finished.emit(combo_index)
	# Recovery/cooldown phase
	attack_timer.wait_time = attack_cooldown
	attack_timer.start()
	# After cooldown, reset to idle
	attack_timer.timeout.disconnect(_on_attack_timer_timeout)
	attack_timer.timeout.connect(_on_attack_cooldown_finished, CONNECT_ONE_SHOT)

func _on_attack_cooldown_finished():
	state = CombatState.IDLE
	print("[Combat][", Time.get_ticks_msec()/1000.0, "] State -> IDLE")
	attack_state_changed.emit(state)
	# Reconnect for next attack
	if attack_timer.timeout.is_connected(_on_attack_cooldown_finished):
		attack_timer.timeout.disconnect(_on_attack_cooldown_finished)
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func _play_attack_animation(combo_idx: int):
	# Handles hand animation for attacks (punch, sword, etc.)
	var current_weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	# 🗡️ DEBUG CODE:
	print("🗡️ DEBUG: Has weapon = ", current_weapon != null)
	if current_weapon:
		print("🗡️ DEBUG: Weapon name = ", current_weapon.weapon_name)
		print("🗡️ DEBUG: weapon_attach_point exists = ", player.weapon_attach_point != null)
		if player.weapon_attach_point:
			print("🗡️ DEBUG: weapon_attach_point path = ", player.weapon_attach_point.get_path())
	if not current_weapon:
		# Unarmed: play punch animation on hand
		print("🥊 No weapon - calling _play_punch_animation")
		if right_hand:
			_play_punch_animation(combo_idx)
	else:
		# Armed: play weapon animation using player reference (NOT weapon_attach_point!)
		if player.weapon_attach_point and is_instance_valid(player.weapon_attach_point):
			print("✅ Using player's weapon_attach_point reference: ", player.weapon_attach_point.get_path())
			WeaponAnimationManager.play_attack_animation(current_weapon, player)
		else:
			print("❌ Player weapon_attach_point is null or invalid!")
			WeaponAnimationManager.play_attack_animation(current_weapon, player)
	# Combo feedback (debug only, replace with real effects as needed)
	# --- Combo particle effects ---
	_spawn_combo_particles(combo_idx)
	_update_combo_ui(combo_idx)
	# --- Play punch sound ---
	_play_punch_sound(combo_idx)
	if combo_idx == 0:
		print("[Combat] Combo 1: light punch")
	elif combo_idx == 1:
		print("[Combat] Combo 2: medium punch, particles")
	elif combo_idx == 2:
		print("[Combat] Combo 3: heavy punch, big particles")


func _spawn_combo_particles(combo_idx: int):
	# Spawn different particles for each combo level
	var particle_name = "ComboParticles%d" % combo_idx
	if player.has_node(particle_name):
		var particles = player.get_node(particle_name)
		particles.restart()

func _update_combo_ui(combo_idx: int):
	# Update combo counter UI if available
	if has_node("/root/ComboUI"):
		get_node("/root/ComboUI").show_combo(combo_idx + 1)

func _play_punch_sound(combo_idx: int):
	if combo_idx < punch_sounds.size():
		punch_sounds[combo_idx].play()
	elif whoosh_sound:
		whoosh_sound.play()

func _play_impact_sound():
	if impact_sound:
		impact_sound.play()

func _play_punch_animation(combo_idx := 0):
	print("🥊 COORDINATE DEBUG:")
	print("  - Player facing direction: ", player.get_facing_direction() if player.has_method("get_facing_direction") else "unknown")
	print("  - Player transform.basis.z: ", player.transform.basis.z)
	print("  - Right hand path: ", right_hand.get_path())
	print("  - Right hand global position: ", right_hand.global_position)
	print("  - Player global position: ", player.global_position)
	print("🥊 _play_punch_animation called - right_hand: ", right_hand != null, " original_pos: ", right_hand_original_pos, " is_animating: ", is_punch_animating)
	if not right_hand or is_punch_animating:
		return
	is_punch_animating = true
	punch_animation_changed.emit(true)
	# Play punch animation using AnimationPlayer
	weapon_animation_player.play('punch')

	# Anchor-based punch animation vectors
	var anticipation_factor = 0.25
	var punch_distance = Vector3(0, 0.05, 0.6)
	var _anticipation_distance = punch_distance * -anticipation_factor

	# Combo feedback (debug only, replace with real effects as needed)
	# --- Play punch sound ---
	_play_punch_sound(combo_idx)
	if combo_idx == 0:
		print("[Combat] Combo 1: light punch")
	elif combo_idx == 1:
		print("[Combat] Combo 2: medium punch, particles")
	elif combo_idx == 2:
		print("[Combat] Combo 3: heavy punch, big particles")


func _on_animation_finished(anim_name: StringName):
	if anim_name == 'punch':
		_on_punch_animation_finished()

func _on_punch_animation_finished():
	is_punch_animating = false
	punch_animation_changed.emit(false)

func _damage_enemies_in_cone(combo_idx: int):
	# Always get weapon from WeaponManager
	var current_weapon = WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null
	
	# For bow weapons, ONLY spawn arrow - arrow handles its own damage
	if current_weapon and current_weapon.weapon_type == WeaponResource.WeaponType.BOW:
		print("🏹 BOW ATTACK: Spawning arrow projectile...")
		var player_forward = -player.transform.basis.z.normalized()
		_spawn_arrow_effect(player_forward)
		return  # Arrow handles its own collision and damage
	
	# MELEE WEAPONS ONLY: Use cone-based instant damage  
	var dmg = player.attack_damage  # Always use player's modified stats (includes weapon bonuses)
	var rng = player.attack_range  # Use player's modified range
	var cone = player.attack_cone_angle  # Use player's modified cone
	var enemies = get_tree().get_nodes_in_group("enemies")
	var player_facing = player.get_facing_direction() if player.has_method("get_facing_direction") else -player.transform.basis.z
	
	var hit_any = false
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance <= rng:
			var direction_to_enemy = (enemy.global_position - player.global_position).normalized()
			direction_to_enemy.y = 0
			var angle_to_enemy = rad_to_deg(player_facing.angle_to(direction_to_enemy))
			if abs(angle_to_enemy) <= cone / 2:
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg)
				enemy_hit.emit(enemy, dmg, combo_idx)
				_spawn_impact_effect(enemy.global_position, current_weapon)
				_play_impact_sound()
				hit_any = true
				_spawn_weapon_trail(current_weapon)
	# Play whoosh if no enemy hit (melee only)
	if not hit_any:
		if whoosh_sound:
			whoosh_sound.play()

func _spawn_impact_effect(pos: Vector3, weapon_param):
	# Show impact particles at pos, different for weapon type
	var effect_name = "ImpactParticles"
	if weapon_param and "impact_particles" in weapon_param:
		effect_name = weapon_param.impact_particles
	if player.has_node(effect_name):
		var effect = player.get_node(effect_name)
		effect.global_position = pos
		effect.restart()

func _spawn_weapon_trail(weapon_param):
	# Show weapon trail effect if weapon has one
	if weapon_param and "trail_particles" in weapon_param:
		var trail_name = weapon_param.trail_particles
		if player.has_node(trail_name):
			var trail = player.get_node(trail_name)
			trail.restart()

func _create_arrow_trail(arrow: MeshInstance3D):
	"""Create a fading trail behind the flying arrow"""
	var trail_segments = 8
	var trail_timer = Timer.new()
	trail_timer.wait_time = 0.05
	trail_timer.one_shot = false
	arrow.add_child(trail_timer)

	var trail_parts = []

	trail_timer.timeout.connect(func():
		if not is_instance_valid(arrow) or not arrow.is_inside_tree():
			trail_timer.queue_free()
			return

		# Create new trail segment
		var trail_segment = MeshInstance3D.new()
		var segment_mesh = CylinderMesh.new()
		segment_mesh.top_radius = 0.01
		segment_mesh.bottom_radius = 0.01
		segment_mesh.height = 0.15
		trail_segment.mesh = segment_mesh

		# Fading trail material
		var trail_material = StandardMaterial3D.new()
		trail_material.albedo_color = Color(0.8, 0.6, 0.4, 0.6)
		trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trail_segment.material_override = trail_material

		# Position at arrow's current location
		if is_instance_valid(arrow) and arrow.is_inside_tree():
			trail_segment.global_position = arrow.global_position
			trail_segment.global_rotation = arrow.global_rotation
			arrow.get_parent().add_child(trail_segment)
			trail_parts.append(trail_segment)

			# Fade out trail segment
			var fade_tween = trail_segment.create_tween()
			fade_tween.tween_property(trail_material, "albedo_color:a", 0.0, 0.4)
			fade_tween.tween_callback(trail_segment.queue_free)

			# Keep only recent trail segments
			if trail_parts.size() > trail_segments:
				var old_segment = trail_parts.pop_front()
				if is_instance_valid(old_segment):
					old_segment.queue_free()
	)

	trail_timer.start()

func _spawn_arrow_effect(_direction: Vector3):
	print("\ud83c\udff9 SPAWNING ARROW...")
	
	# Create arrow as MeshInstance3D (no physics collision)
	var arrow = MeshInstance3D.new()
	arrow.name = "Arrow"
	
	# Add to scene first
	player.get_parent().add_child(arrow)
	
	# Create arrow shaft
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.02
	cylinder.bottom_radius = 0.02
	cylinder.height = 0.6
	arrow.mesh = cylinder
	
	# Arrow material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.25, 0.1)
	material.roughness = 0.8
	arrow.material_override = material
	
	# Arrow tip (pointy end)
	var tip = MeshInstance3D.new()
	var tip_mesh = CylinderMesh.new()
	tip_mesh.top_radius = 0.005
	tip_mesh.bottom_radius = 0.02
	tip_mesh.height = 0.1
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.35, 0)  # Front of arrow
	
	var tip_material = StandardMaterial3D.new()
	tip_material.albedo_color = Color(0.7, 0.7, 0.8)
	tip_material.metallic = 0.9
	tip.material_override = tip_material
	arrow.add_child(tip)
	
	# Fletching (back of arrow)
	var fletching = MeshInstance3D.new()
	var fletch_mesh = BoxMesh.new()
	fletch_mesh.size = Vector3(0.08, 0.02, 0.1)
	fletching.mesh = fletch_mesh
	fletching.position = Vector3(0, -0.25, 0)  # Back of arrow
	
	var fletch_material = StandardMaterial3D.new()
	fletch_material.albedo_color = Color(0.9, 0.8, 0.7)
	fletch_material.roughness = 0.9
	fletching.material_override = fletch_material
	arrow.add_child(fletching)
	
	# Position arrow at hand/bow
	var start_pos = player.global_position + Vector3(0, 0.5, 0)
	var right_hand_anchor = player.get_node_or_null("RightHandAnchor")
	if right_hand_anchor:
		start_pos = right_hand_anchor.global_position
	
	arrow.global_position = start_pos
	
	# SIMPLE FIX: Make arrow look in travel direction with tip first
	# The tip is at positive Y, so we want +Y to point toward the target
	var target_point = start_pos + _direction * 10.0
	arrow.look_at(target_point, Vector3.UP)
	# Rotate 90 degrees around X so the tip (Y+) points forward instead of up
	arrow.rotate_object_local(Vector3(1, 0, 0), -PI/2)
	
	# Store movement data
	arrow.set_meta("velocity", _direction * 15.0)
	arrow.set_meta("stuck", false)
	arrow.set_meta("stuck_to", null)
	
	# Set up movement and collision checking
	var update_timer = Timer.new()
	update_timer.wait_time = 0.02  # 50 FPS
	update_timer.one_shot = false
	update_timer.timeout.connect(_update_arrow.bind(arrow))
	arrow.add_child(update_timer)
	update_timer.start()
	
	# Set up auto-despawn
	var despawn_timer = Timer.new()
	despawn_timer.wait_time = 60.0  # 1 minute
	despawn_timer.one_shot = true
	despawn_timer.timeout.connect(_on_arrow_despawn.bind(arrow))
	arrow.add_child(despawn_timer)
	despawn_timer.start()
	
	print("\ud83c\udff9 Arrow launched in direction: ", _direction)

func _update_arrow(arrow: MeshInstance3D):
	if not is_instance_valid(arrow):
		return
	
	# If stuck, don't move independently (let parent handle movement)
	if arrow.get_meta("stuck", false):
		return
	
	var velocity = arrow.get_meta("velocity", Vector3.ZERO)
	var delta = 0.02  # Timer interval
	
	# Apply gravity
	velocity.y -= 9.8 * delta * 0.3  # Light gravity
	arrow.set_meta("velocity", velocity)
	
	# Move arrow
	var old_pos = arrow.global_position
	var new_pos = old_pos + velocity * delta
	arrow.global_position = new_pos
	
	# Check for collisions
	_check_arrow_collisions(arrow, old_pos, new_pos)

func _check_arrow_collisions(arrow: MeshInstance3D, old_pos: Vector3, new_pos: Vector3):
	# Check enemy collisions
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or ("is_dead" in enemy and enemy.is_dead):
			continue
		
		var distance = new_pos.distance_to(enemy.global_position)
		if distance <= 1.0:
			print("\ud83c\udff9 Arrow hit enemy: ", enemy.name)
			_stick_arrow_to_enemy(arrow, enemy)
			return
	
	# Check wall collisions with raycast
	var space_state = arrow.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(old_pos, new_pos)
	query.collision_mask = 1  # Only walls/static bodies
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		print("\ud83c\udff9 Arrow hit wall: ", result.collider.name)
		_stick_arrow_to_wall(arrow, result.position, result.collider)

func _stick_arrow_to_enemy(arrow: MeshInstance3D, enemy: Node3D):
	# Damage the enemy
	# Use player's modified stats (base + weapon bonuses)
	var dmg = player.attack_damage  # Use player's modified stats (base + weapon bonuses)
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg)
	enemy_hit.emit(enemy, dmg, combo_index)
	_spawn_impact_effect(enemy.global_position, WeaponManager.get_current_weapon() if WeaponManager.is_weapon_equipped() else null)
	_play_impact_sound()
	
	# Position arrow at enemy surface (keep current orientation!)
	var hit_direction = (enemy.global_position - arrow.global_position).normalized()
	arrow.global_position = enemy.global_position - hit_direction * 0.5
	
	# REPARENT arrow to enemy so it moves with the enemy
	var world_transform = arrow.global_transform
	arrow.get_parent().remove_child(arrow)
	enemy.add_child(arrow)
	arrow.global_transform = world_transform  # Restore position AND orientation
	
	# Mark as stuck
	arrow.set_meta("stuck", true)
	arrow.set_meta("stuck_to", enemy)
	
	# Stop update timer
	var update_timer = arrow.get_node_or_null("Timer")
	if update_timer:
		update_timer.queue_free()
	
	print("\ud83c\udff9 Arrow stuck to enemy and will move with it")

func _stick_arrow_to_wall(arrow: MeshInstance3D, hit_position: Vector3, wall: Node):
	# Position arrow at hit point (keep current orientation!)
	arrow.global_position = hit_position
	
	# Mark as stuck
	arrow.set_meta("stuck", true)
	arrow.set_meta("stuck_to", wall)
	
	# Stop update timer
	var update_timer = arrow.get_node_or_null("Timer")
	if update_timer:
		update_timer.queue_free()
	
	print("\ud83c\udff9 Arrow stuck in wall: ", wall.name)

func _on_arrow_despawn(arrow: MeshInstance3D):
	if is_instance_valid(arrow):
		print("\ud83c\udff9 Arrow despawning after timeout")
		arrow.queue_free()

func _ready():
	if not player:
		player = get_parent()
	weapon_animation_player = player.get_node_or_null("WeaponAnimationPlayer") if player else null
	if not weapon_animation_player:
		push_error("[PlayerCombat] WeaponAnimationPlayer node not found on player!")
	else:
		print("[PlayerCombat] WeaponAnimationPlayer node found.")
	set_process(true)
