# demolition_king_boss.gd - FIXED VERSION with proper wall breaking and debugging
extends CharacterBody3D

# === SIGNALS ===
signal boss_died

# === BOSS STATS ===
@export var max_health: int = 200
@export var speed: float = 4.0
@export var charge_speed: float = 8.0
@export var wall_break_radius: float = 3.0

# === BOSS STATES ===
enum BossState { 
	SPAWNING,        # Safe spawn state - clear area
	POSITIONING,     # Move to safe position
	IDLE,           # Normal behavior
	CHARGING,       # Attack state
	DYING
}
var current_state: BossState = BossState.SPAWNING

# === CORE PROPERTIES ===
var health: int
var state_timer: float = 0.0

# === CHARGE ATTACK ===
var charge_direction: Vector3
var is_charging: bool = false
var charge_timer: float = 0.0

# === SCENE REFERENCES ===
var player: CharacterBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_scale: Vector3

# === VISUAL EFFECTS ===
var boss_material: StandardMaterial3D

# === PHYSICS & SAFETY ===
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var spawn_position: Vector3
var safe_ground_level: float
var last_safe_position: Vector3

# === DEBUGGING ===
var debug_enabled: bool = true
var walls_broken_this_frame: int = 0
var debug_collision_timer: float = 0.0

func _ready() -> void:
	health = max_health
	_setup_boss()
	_setup_physics_layers()
	call_deferred("_find_safe_spawn")
	
	if debug_enabled:
		print("🤖 BOSS: Spawning Demolition King Boss")
		print("🤖 BOSS: Health: ", health, "/", max_health)

func _physics_process(delta: float) -> void:
	state_timer += delta
	debug_collision_timer += delta
	walls_broken_this_frame = 0
	
	_handle_boss_state(delta)
	_apply_safe_physics(delta)
	
	# Store last position before moving
	if is_on_floor():
		last_safe_position = global_position
	
	move_and_slide()
	_check_wall_collisions()
	_safety_checks()
	
	# Debug output every 2 seconds
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
		push_error("❌ BOSS: No player found!")
		if debug_enabled:
			print("❌ BOSS: Player not found in scene tree")

func _setup_physics_layers() -> void:
	"""Set up proper physics layers for boss collision detection"""
	# Boss collision layer: 4 (layer 3, bit 2)
	collision_layer = 1 << 2  # Boss layer
	
	# Boss collision mask: walls (layer 2) + world (layer 1) + players (layer 3)
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2)  # World + Walls + Players
	
	# Add to groups
	add_to_group("bosses")
	add_to_group("enemies")
	
	if debug_enabled:
		print("🤖 BOSS: Physics setup - Layer: ", collision_layer, " Mask: ", collision_mask)

func _setup_boss_material() -> void:
	"""Create distinctive boss material"""
	boss_material = StandardMaterial3D.new()
	boss_material.albedo_color = Color.RED
	boss_material.emission_enabled = true
	boss_material.emission = Color.RED * 0.2
	boss_material.roughness = 0.3
	
	if mesh_instance:
		mesh_instance.material_override = boss_material

func _find_safe_spawn() -> void:
	"""Find and clear a safe spawn area for the boss"""
	spawn_position = global_position
	safe_ground_level = global_position.y - 5.0
	last_safe_position = global_position
	
	if debug_enabled:
		print("🤖 BOSS: Initial spawn position: ", spawn_position)
		print("🤖 BOSS: Safe ground level set to: ", safe_ground_level)
		print("🤖 BOSS: Boss is spawning high and will fall down")
	
	# Clear spawn area immediately
	_force_break_nearby_walls()
	
	# Start the spawning process
	current_state = BossState.SPAWNING
	state_timer = 0.0

func _handle_boss_state(delta: float) -> void:
	match current_state:
		BossState.SPAWNING:
			_handle_spawning()
		BossState.POSITIONING:
			_handle_positioning()
		BossState.IDLE:
			_handle_idle_state()
		BossState.CHARGING:
			_handle_charging(delta)
		BossState.DYING:
			_handle_death_sequence(delta)

func _handle_spawning() -> void:
	"""Wait for boss to fall and land properly"""
	# Clear walls immediately when spawning starts
	if state_timer <= 0.1:
		_force_break_nearby_walls()
		if debug_enabled:
			print("🤖 BOSS: Starting spawn, clearing area")
	
	# Wait for boss to land before proceeding
	if is_on_floor() and state_timer >= 1.0:
		if debug_enabled:
			print("🤖 BOSS: Landed! Position: ", global_position)
		current_state = BossState.POSITIONING
		state_timer = 0.0
	elif state_timer >= 5.0:
		# Force landing if taking too long
		if debug_enabled:
			print("🤖 BOSS: Forcing landing after 5 seconds")
		current_state = BossState.POSITIONING
		state_timer = 0.0

func _handle_positioning() -> void:
	"""Give boss time to settle and clear more walls if needed"""
	# Break walls around boss periodically during positioning
	if int(state_timer * 4) % 2 == 0:  # Every 0.5 seconds
		_force_break_nearby_walls()
	
	# Finish positioning after 3 seconds
	if state_timer >= 3.0:
		current_state = BossState.IDLE
		state_timer = 0.0
		
		if debug_enabled:
			print("🤖 BOSS: Positioning complete, starting normal behavior")

func _handle_idle_state() -> void:
	if not player:
		if debug_enabled:
			print("🤖 BOSS IDLE: No player found!")
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Debug output every 2 seconds in idle
	if debug_enabled and int(state_timer * 2) % 4 == 0:
		print("🤖 BOSS IDLE: Distance to player: ", distance_to_player)
		print("🤖 BOSS IDLE: On floor: ", is_on_floor(), " Velocity: ", velocity.length())
	
	# Don't try to move if boss is falling or unstable
	if not is_on_floor() or velocity.y < -2.0:
		if debug_enabled:
			print("🤖 BOSS: Waiting for stability - on_floor: ", is_on_floor(), " velocity.y: ", velocity.y)
		return
	
	# Always try to break walls if we're close to player but not moving
	if distance_to_player < 8.0 and velocity.length() < 0.1:
		if debug_enabled:
			print("🤖 BOSS: Close to player but not moving, breaking walls")
		_force_break_nearby_walls()
	
	# Try to move toward player when stable
	_move_toward_player()
	
	# Charge attack every 6 seconds if close enough
	if state_timer >= 6.0 and distance_to_player < 12.0:
		_start_charge_attack()

func _move_toward_player() -> void:
	"""Make boss carefully move toward player"""
	if not player or not is_on_floor():
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if debug_enabled and int(state_timer * 4) % 8 == 0:  # Every 2 seconds
		print("🤖 BOSS MOVE: Direction: ", direction_to_player, " Distance: ", distance_to_player)
	
	# Move toward player at reasonable speed
	var move_speed = speed * 0.8  # 80% speed for stability
	velocity.x = direction_to_player.x * move_speed
	velocity.z = direction_to_player.z * move_speed
	
	# If very close, stop moving but still try to attack
	if distance_to_player < 2.5:
		velocity.x = 0
		velocity.z = 0
		if debug_enabled:
			print("🤖 BOSS: Very close to player, stopping movement")
	
	# Break walls while moving if we detect resistance
	if velocity.length() > 0.1:
		_break_walls_in_movement_direction()

func _break_walls_in_movement_direction() -> void:
	"""Break walls in the direction the boss is trying to move"""
	var movement_direction = Vector3(velocity.x, 0, velocity.z).normalized()
	var check_position = global_position + movement_direction * 2.0
	
	# Use a smaller, focused area for movement-based wall breaking
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 1.5  # Smaller radius for movement
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = check_position
	query.collision_mask = 1 << 1  # Only check wall layer (layer 2)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)

func _start_charge_attack() -> void:
	if not player:
		return
		
	current_state = BossState.CHARGING
	
	# Calculate direction to player
	charge_direction = (player.global_position - global_position).normalized()
	is_charging = true
	charge_timer = 0.0
	state_timer = 0.0
	
	if debug_enabled:
		print("🤖 BOSS: Starting charge attack toward player")

func _handle_charging(delta: float) -> void:
	charge_timer += delta
	
	# Actually charge forward at full speed
	velocity.x = charge_direction.x * charge_speed
	velocity.z = charge_direction.z * charge_speed
	
	# Break walls continuously while charging
	if int(charge_timer * 5) % 2 == 0:  # Every 0.4 seconds
		_force_break_nearby_walls()
	
	# Stop charging after 3 seconds or if we're close to player
	var distance_to_player = global_position.distance_to(player.global_position)
	if charge_timer >= 3.0 or distance_to_player < 2.0:
		_end_charge()

func _end_charge() -> void:
	is_charging = false
	velocity.x = 0
	velocity.z = 0
	current_state = BossState.IDLE
	state_timer = 0.0
	charge_timer = 0.0
	
	if debug_enabled:
		print("🤖 BOSS: Charge attack ended")

# === IMPROVED WALL BREAKING ===
func _check_wall_collisions() -> void:
	"""Check for wall collisions during movement and break them"""
	# Only check collisions when moving
	if velocity.length() < 0.1:
		return
		
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		
		if collider and _is_wall(collider):
			_break_wall(collider)
			if debug_enabled:
				print("🤖 BOSS: Breaking wall from collision: ", collider.name)

func _force_break_nearby_walls() -> void:
	"""Break walls in radius around boss - IMPROVED VERSION"""
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = wall_break_radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = global_position
	# FIXED: Use proper collision mask for walls (layer 2)
	query.collision_mask = 1 << 1  # Wall layer only
	
	var results = space_state.intersect_shape(query)
	
	var walls_found = 0
	for result in results:
		var obj = result.collider
		walls_found += 1
		if _is_wall(obj):
			_break_wall(obj)
			walls_broken_this_frame += 1
	
	if debug_enabled and walls_broken_this_frame > 0:
		print("🤖 BOSS: Found ", walls_found, " objects, broke ", walls_broken_this_frame, " walls")

func _is_wall(obj: Node) -> bool:
	"""IMPROVED wall detection with better debugging"""
	if not obj:
		return false
	
	var name_lower = obj.name.to_lower()
	var parent_name_lower = obj.get_parent().name.to_lower() if obj.get_parent() else ""
	
	# ABSOLUTELY NEVER BREAK THESE
	var never_break = (
		# Floor/Ground objects
		name_lower.contains("floor") or
		name_lower.contains("ground") or
		name_lower.contains("terrain") or
		name_lower.contains("platform") or
		# Important game objects
		name_lower.contains("player") or
		name_lower.contains("boss") or
		name_lower.contains("enemy") or
		name_lower.contains("coin") or
		name_lower.contains("pickup") or
		name_lower.contains("orb") or
		name_lower.contains("potion") or
		# Groups to preserve
		obj.is_in_group("player") or
		obj.is_in_group("bosses") or
		obj.is_in_group("enemies") or
		obj.is_in_group("floor") or
		obj.is_in_group("ground") or
		obj.is_in_group("terrain")
	)
	
	if never_break:
		if debug_enabled and int(debug_collision_timer * 3) % 6 == 0:  # Occasional debug
			print("🤖 BOSS: Skipping protected object: ", obj.name)
		return false
	
	# Check if it's a boundary wall (unbreakable)
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_is_boundary_wall"):
		var obj_grid_pos = _world_to_grid_position(obj.global_position, terrain)
		if terrain._is_boundary_wall(obj_grid_pos.x, obj_grid_pos.y):
			if debug_enabled:
				print("🤖 BOSS: Skipping boundary wall: ", obj.name)
			return false
	
	# ONLY break objects that are clearly walls
	var is_definitely_wall = (
		name_lower.contains("wall") or
		parent_name_lower.contains("wall") or
		obj.is_in_group("walls") or
		obj.is_in_group("wall")
	)
	
	if is_definitely_wall:
		return true
	
	# For StaticBody3D objects on wall layer, be more careful
	if obj is StaticBody3D:
		# Check if it's on the wall layer (layer 2)
		if obj.collision_layer & (1 << 1):  # Wall layer check
			var obj_y = obj.global_position.y
			var boss_y = global_position.y
			
			# Only break if object is at similar height to boss (not floor below)
			if abs(obj_y - boss_y) < 2.0 and obj_y > boss_y - 3.0:
				return true
		
		if debug_enabled and int(debug_collision_timer * 2) % 8 == 0:  # Occasional debug
			print("🤖 BOSS: StaticBody3D not on wall layer: ", obj.name, " Layer: ", obj.collision_layer)
	
	return false

func _world_to_grid_position(world_pos: Vector3, terrain: Node) -> Vector2i:
	"""Convert world position to grid coordinates"""
	var map_size = terrain.map_size if "map_size" in terrain else Vector2(60, 60)
	var grid_x = int((world_pos.x / 2.0) + (map_size.x / 2))
	var grid_y = int((world_pos.z / 2.0) + (map_size.y / 2))
	return Vector2i(grid_x, grid_y)

func _break_wall(wall: Node) -> void:
	"""Break a wall safely with improved methods"""
	if not wall or not is_instance_valid(wall):
		return
	
	if debug_enabled:
		print("🤖 BOSS: Breaking wall: ", wall.name, " at ", wall.global_position)
	
	# Try different breaking methods
	if wall.has_method("break_wall"):
		wall.break_wall()
	elif wall.has_method("destroy"):
		wall.destroy()
	elif wall.has_method("queue_free"):
		# Standard removal
		if wall.has_method("set_visible"):
			wall.set_visible(false)
		if wall.has_method("set_collision_layer"):
			wall.set_collision_layer(0)
		if wall.has_method("set_collision_mask"):
			wall.set_collision_mask(0)
		
		# Remove from wall lookup if terrain has this feature
		var terrain = get_tree().get_first_node_in_group("terrain")
		if terrain and terrain.has_method("_remove_wall_from_lookup"):
			var grid_pos = _world_to_grid_position(wall.global_position, terrain)
			terrain._remove_wall_from_lookup(grid_pos.x, grid_pos.y)
		
		wall.queue_free()
	else:
		push_warning("🤖 BOSS: Wall has no breaking method: " + wall.name)

# === SAFETY SYSTEMS ===
func _safety_checks() -> void:
	"""Prevent boss from dying or falling off world"""
	
	# Check if boss fell below world
	if global_position.y < safe_ground_level - 10.0:
		if debug_enabled:
			print("🤖 BOSS: Fell below world! Resetting to: ", last_safe_position)
		global_position = last_safe_position
		velocity = Vector3.ZERO
	
	# Check if boss is taking damage from unknown source
	if health < max_health and current_state != BossState.DYING:
		if debug_enabled and int(debug_collision_timer * 2) % 6 == 0:  # Every 3 seconds
			_debug_damage_sources()

func _debug_damage_sources() -> void:
	"""Debug what might be damaging the boss"""
	print("🤖 BOSS DEBUG: Health: ", health, "/", max_health)
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = global_position
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	
	var results = space_state.intersect_shape(query)
	
	print("🤖 BOSS DEBUG: Objects near boss:")
	for result in results:
		var obj = result.collider
		var layer_info = obj.collision_layer if obj.has_method("get") else "N/A"
		print("  - ", obj.name, " (", obj.get_class(), ") Layer: ", layer_info)

func _debug_status() -> void:
	"""Print current boss status for debugging"""
	var state_name = ["SPAWNING", "POSITIONING", "IDLE", "CHARGING", "DYING"][current_state]
	print("🤖 BOSS STATUS: State=", state_name, " Health=", health, "/", max_health, 
		  " Pos=", global_position, " OnFloor=", is_on_floor(), " Velocity=", velocity.length())

func _apply_safe_physics(delta: float) -> void:
	"""Apply physics safely - prevent falling through world"""
	
	# Apply gravity when not on floor (FIXED: Allow falling during spawning)
	if not is_on_floor():
		velocity.y -= gravity * delta
		
		# Cap falling speed to prevent clipping through ground
		velocity.y = max(velocity.y, -15.0)
		
		if debug_enabled and current_state == BossState.SPAWNING:
			print("🤖 BOSS: Falling during spawn - Y velocity: ", velocity.y, " Position: ", global_position.y)

# === DAMAGE SYSTEM ===
func take_damage(amount: int, source = null) -> void:
	if current_state == BossState.DYING:
		return
	
	health -= amount
	
	if debug_enabled:
		var source_name = source.name if source else "Unknown"
		print("🤖 BOSS: Took ", amount, " damage from ", source_name, " | Health: ", health, "/", max_health)
	
	if health <= 0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	current_state = BossState.DYING
	
	if debug_enabled:
		print("🤖 BOSS: Starting death sequence")
	
	boss_died.emit()

func _handle_death_sequence(delta: float) -> void:
	# Slow death animation
	if mesh_instance:
		mesh_instance.scale = mesh_instance.scale.lerp(Vector3.ZERO, 1.0 * delta)
	
	if state_timer >= 4.0:
		if debug_enabled:
			print("🤖 BOSS: Death sequence complete, removing boss")
		queue_free()
