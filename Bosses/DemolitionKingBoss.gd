# demolition_king_boss.gd - SAFE VERSION with debug info
extends CharacterBody3D

# === SIGNALS ===
signal boss_died
signal wall_destroyed(position: Vector3)

# === BOSS STATS ===
@export var max_health: int = 200
@export var speed: float = 4.0
@export var charge_speed: float = 8.0  # Slower for testing

# === BOSS STATES ===
enum BossState { 
	SPAWNING,        # Safe spawn state
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

func _ready() -> void:
	print("👑 DEMOLITION KING: SAFE SPAWN VERSION!")
	health = max_health
	_setup_boss()
	call_deferred("_find_safe_spawn")

func _physics_process(delta: float) -> void:
	state_timer += delta
	_debug_boss_status()
	_handle_boss_state(delta)
	_apply_safe_physics(delta)
	
	# Store last position before moving
	if is_on_floor():
		last_safe_position = global_position
	
	move_and_slide()
	_check_wall_collisions()
	_safety_checks()

func _setup_boss() -> void:
	# Get scene components
	mesh_instance = get_node("MeshInstance3D")
	collision_shape = get_node("CollisionShape3D")
	
	if mesh_instance:
		original_scale = mesh_instance.scale
		_setup_boss_material()
		print("✅ Boss visuals setup complete")
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("❌ No player found!")
		return
	
	print("✅ Found player at: ", player.global_position)
	
	# Setup groups and collision
	add_to_group("bosses")
	add_to_group("enemies")
	collision_layer = 4  # Boss layer
	collision_mask = 1   # Collide with world
	
	print("✅ Boss collision setup: layer=", collision_layer, " mask=", collision_mask)

func _setup_boss_material() -> void:
	boss_material = StandardMaterial3D.new()
	boss_material.albedo_color = Color(0.8, 0.2, 0.1, 1.0)
	boss_material.metallic = 0.3
	boss_material.roughness = 0.4
	boss_material.emission_enabled = true
	boss_material.emission = Color(0.3, 0.1, 0.0)  # More visible
	mesh_instance.material_override = boss_material

func _find_safe_spawn() -> void:
	if not player:
		return
	
	print("🔍 Finding safe spawn position near player...")
	
	# Find ground level near player
	safe_ground_level = _find_ground_level(player.global_position)
	print("🌍 Ground level detected at Y: ", safe_ground_level)
	
	# Position boss on safe ground, a bit away from player
	var safe_offset = Vector3(8, 0, 8)  # 8 units away
	spawn_position = Vector3(
		player.global_position.x + safe_offset.x,
		safe_ground_level + 2.0,  # 2 units above ground
		player.global_position.z + safe_offset.z
	)
	
	# Set position and mark as safe
	global_position = spawn_position
	last_safe_position = spawn_position
	
	print("🎯 Boss spawned at SAFE position: ", global_position)
	print("🦶 Is on floor: ", is_on_floor())
	
	current_state = BossState.POSITIONING

func _find_ground_level(reference_pos: Vector3) -> float:
	"""Find the ground level near a reference position"""
	var space_state = get_world_3d().direct_space_state
	
	# Cast ray downward from high above reference position
	var ray_start = reference_pos + Vector3(0, 20, 0)
	var ray_end = reference_pos + Vector3(0, -20, 0)
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1  # World collision
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("🎯 Ground raycast hit: ", result.collider.name, " at Y: ", result.position.y)
		return result.position.y
	else:
		print("⚠️ No ground found, using player Y level")
		return reference_pos.y

# === STATE MANAGEMENT ===
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
	# Just wait a moment to ensure everything is loaded
	if state_timer >= 0.5:
		print("✅ Spawn complete, moving to positioning")
		current_state = BossState.POSITIONING
		state_timer = 0.0

func _handle_positioning() -> void:
	# Only break walls once at the start, then let him settle
	if state_timer >= 0.5 and state_timer < 1.0:
		print("🔨 Initial wall break to clear immediate area...")
		_force_break_nearby_walls()
	
	# Wait for boss to settle, then start normal behavior
	if state_timer >= 2.0:
		print("👑 DEMOLITION KING: READY FOR BATTLE!")
		current_state = BossState.IDLE
		state_timer = 0.0

func _break_walls_around_spawn() -> void:
	"""Break walls around boss spawn to create some arena space"""
	print("🔨 Creating spawn arena...")
	_force_break_nearby_walls()

func _handle_idle_state() -> void:
	if not player:
		return
	
	# Don't try to move if boss is falling or unstable
	if not is_on_floor() or velocity.y < -2.0:
		print("⏸️ Boss not stable - waiting to land")
		return
	
	# Check if boss is stuck (not moving for a while on stable ground)
	if state_timer >= 3.0 and velocity.length() < 0.1 and is_on_floor():
		print("🚫 BOSS APPEARS STUCK! Breaking nearby walls")
		_force_break_nearby_walls()
	
	# Try to move toward player only when stable
	_move_toward_player()
	
	# Charge attack every 5 seconds
	if state_timer >= 5.0:
		_start_charge_attack()

func _move_toward_player() -> void:
	"""Make boss carefully move toward player"""
	if not player or not is_on_floor():
		return
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	print("🎯 Moving toward player: distance=", distance_to_player, " direction=", direction_to_player)
	
	# Move toward player at conservative speed
	var move_speed = speed * 0.5  # Half speed for safety
	velocity.x = direction_to_player.x * move_speed
	velocity.z = direction_to_player.z * move_speed
	
	# If very close, stop moving
	if distance_to_player < 4.0:
		velocity.x = 0
		velocity.z = 0
		print("✋ Close enough to player, stopping movement")

func _start_charge_attack() -> void:
	if not player:
		return
		
	print("⚡ DEMOLITION KING: STARTING CHARGE!")
	current_state = BossState.CHARGING
	
	# Calculate direction to player
	charge_direction = (player.global_position - global_position).normalized()
	is_charging = true
	charge_timer = 0.0
	state_timer = 0.0
	
	print("🎯 Charging toward: ", player.global_position)

func _handle_charging(delta: float) -> void:
	charge_timer += delta
	
	# Actually charge forward at full speed
	velocity.x = charge_direction.x * charge_speed
	velocity.z = charge_direction.z * charge_speed
	
	print("🏃 Boss charging: velocity=(", velocity.x, ", ", velocity.z, ") toward player")
	
	# Break walls continuously while charging
	if int(charge_timer * 10) % 3 == 0:  # Every 0.3 seconds
		_force_break_nearby_walls()
	
	# Stop charging after 3 seconds or if we've moved far enough
	var distance_traveled = global_position.distance_to(player.global_position)
	if charge_timer >= 3.0 or distance_traveled < 2.0:
		_end_charge()

func _end_charge() -> void:
	print("🛑 Charge ended")
	is_charging = false
	velocity.x = 0
	velocity.z = 0
	current_state = BossState.IDLE
	state_timer = 0.0
	charge_timer = 0.0

# === WALL BREAKING ===
func _check_wall_collisions() -> void:
	# Only check collisions when moving
	if velocity.length() < 0.1:
		return
		
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		
		if collider and _is_wall(collider):
			print("💥 Boss charged through wall: ", collider.name)
			_break_wall(collider)

func _force_break_nearby_walls() -> void:
	"""Break walls in radius around boss"""
	print("💪 Force breaking walls around: ", global_position)
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 4.0  # Smaller radius for testing
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = global_position
	query.collision_mask = 1
	
	var results = space_state.intersect_shape(query)
	print("🔍 Found ", results.size(), " objects in break radius")
	
	var walls_broken = 0
	for result in results:
		var obj = result.collider
		if _is_wall(obj):
			_break_wall(obj)
			walls_broken += 1
	
	print("🧱 Broke ", walls_broken, " walls")

func _is_wall(obj: Node) -> bool:
	"""MUCH SMARTER wall detection - never break floors or important objects"""
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
		print("🛡️ PROTECTED OBJECT (never break): ", obj.name)
		return false
	
	# ONLY break objects that are clearly walls
	var is_definitely_wall = (
		name_lower.contains("wall") or
		parent_name_lower.contains("wall") or
		obj.is_in_group("walls") or
		obj.is_in_group("wall")
	)
	
	if is_definitely_wall:
		print("💥 CONFIRMED WALL: ", obj.name, " - safe to break")
		return true
	
	# For anything else (like random StaticBody3D), be more careful
	# Only break if it's clearly blocking and above ground level
	if obj is StaticBody3D and obj.collision_layer == 1:
		var obj_y = obj.global_position.y
		var boss_y = global_position.y
		
		# Only break if object is at similar height to boss (not floor below)
		if abs(obj_y - boss_y) < 1.0 and obj_y > boss_y - 2.0:
			print("💥 OBSTACLE: ", obj.name, " at similar height - breaking")
			return true
		else:
			print("🛡️ GROUND LEVEL: ", obj.name, " below boss - preserving")
			return false
	
	print("❌ UNKNOWN OBJECT: ", obj.name, " - not breaking")
	return false

func _break_wall(wall: Node) -> void:
	"""Break a wall safely"""
	if not wall or not is_instance_valid(wall):
		return
	
	print("💥 BREAKING WALL: ", wall.name, " at ", wall.global_position)
	wall_destroyed.emit(wall.global_position)
	
	# Try different breaking methods
	if wall.has_method("break_wall"):
		wall.break_wall()
	elif wall.has_method("destroy"):
		wall.destroy()
	else:
		# Simple removal
		if wall.has_method("set_visible"):
			wall.set_visible(false)
		if wall.has_method("set_collision_layer"):
			wall.set_collision_layer(0)
		wall.queue_free()

# === SAFETY SYSTEMS ===
func _safety_checks() -> void:
	"""Prevent boss from dying or falling off world"""
	
	# Check if boss fell below world
	if global_position.y < safe_ground_level - 10.0:
		print("🚨 BOSS FALLING! Teleporting to safety")
		global_position = last_safe_position
		velocity = Vector3.ZERO
	
	# Check if boss is taking damage from unknown source
	if health < max_health and current_state != BossState.DYING:
		print("🩸 Boss is taking damage! Health: ", health, "/", max_health)
		# For debugging - let's see what might be hurting him
		_debug_damage_sources()

func _debug_damage_sources() -> void:
	"""Debug what might be damaging the boss"""
	print("🔍 Checking for damage sources around boss...")
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = global_position
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	
	var results = space_state.intersect_shape(query)
	print("🔍 Objects near boss that might cause damage:")
	
	for result in results:
		var obj = result.collider
		print("  - ", obj.name, " (", obj.get_class(), ") Layer: ", obj.collision_layer if obj.has_method("get") else "N/A")

func _apply_safe_physics(delta: float) -> void:
	"""Apply physics safely - prevent falling through world"""
	
	# Apply gravity only when appropriate
	if not is_on_floor() and current_state != BossState.SPAWNING:
		velocity.y -= gravity * delta
		
		# Cap falling speed to prevent clipping through ground
		velocity.y = max(velocity.y, -15.0)

func _debug_boss_status() -> void:
	"""Print debug info every few seconds"""
	if int(state_timer) % 3 == 0 and state_timer - int(state_timer) < 0.1:  # Every 3 seconds
		print("📊 BOSS STATUS:")
		print("  Position: ", global_position)
		print("  State: ", BossState.keys()[current_state])
		print("  Health: ", health, "/", max_health)
		print("  On Floor: ", is_on_floor())
		print("  Velocity: ", velocity)

# === DAMAGE SYSTEM ===
func take_damage(amount: int, source = null) -> void:
	if current_state == BossState.DYING:
		return
	
	print("👑 Boss took ", amount, " damage from ", source if source else "unknown")
	print("  Health before: ", health, "/", max_health)
	
	health -= amount
	
	print("  Health after: ", health, "/", max_health)
	
	if health <= 0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	print("💀 DEMOLITION KING: PROPERLY DEFEATED!")
	current_state = BossState.DYING
	boss_died.emit()

func _handle_death_sequence(delta: float) -> void:
	# Slow death animation
	if mesh_instance:
		mesh_instance.scale = mesh_instance.scale.lerp(Vector3.ZERO, 1.0 * delta)
	
	if state_timer >= 4.0:
		print("👑 Boss death sequence complete")
		queue_free()

# === DEBUG FUNCTIONS ===
func debug_status() -> void:
	"""Print comprehensive debug info"""
	print("=== BOSS DEBUG STATUS ===")
	print("Position: ", global_position)
	print("Health: ", health, "/", max_health)
	print("State: ", BossState.keys()[current_state])
	print("On Floor: ", is_on_floor())
	print("Velocity: ", velocity)
	print("Last Safe Position: ", last_safe_position)
	print("Ground Level: ", safe_ground_level)

func force_break_test() -> void:
	"""Force test wall breaking"""
	print("🧪 MANUAL WALL BREAK TEST!")
	_force_break_nearby_walls()
