# enemy_spawner.gd - ENHANCED: Boss fight integration for wave 10
extends Node3D

# === SIGNALS FOR INTEGRATION ===
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D)  # NEW: Boss spawn signal
signal boss_fight_started
signal boss_fight_completed

# === WAVE CONFIGURATION ===
@export var max_waves: int = 10
@export var base_enemies_per_wave: int = 3
@export var enemy_increase_per_wave: int = 2
@export var wave_delay: float = 3.0
@export var boss_wave: int = 10  # Wave where boss spawns

# === ENEMY SETTINGS ===
@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene  # NEW: Boss scene
@export var spawn_distance_min: float = 4.0
@export var spawn_distance_max: float = 8.0
@export var spawn_attempts: int = 20

# === CURRENT STATE ===
var current_wave: int = 0
var enemies_alive: Array[Node3D] = []
var wave_active: bool = false
var spawning_active: bool = false
var is_boss_spawned: bool = false  # NEW: Track if boss is spawned
var boss_instance: Node3D = null  # NEW: Reference to boss

# === REFERENCES ===
var player: Node3D
var current_spawning_room: Rect2
var map_size: Vector2 = Vector2(60, 60)

# === TIMERS ===
var wave_delay_timer: Timer

func _ready():
	name = "EnemySpawner"
	add_to_group("spawner")
	
	_setup_system()

func _setup_system():
	"""Initialize the wave system"""
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Load enemy scene if not set
	if not enemy_scene:
		if ResourceLoader.exists("res://Scenes/enemy.tscn"):
			enemy_scene = load("res://Scenes/enemy.tscn")
		else:
			return
	
	# Load boss scene if not set
	if not boss_scene:
		if ResourceLoader.exists("res://Scenes/boss_slime.tscn"):
			boss_scene = load("res://Scenes/boss_slime.tscn")
		else:
			# Create boss scene reference from enemy scene with boss script
			boss_scene = enemy_scene  # Fallback - will be enhanced by boss script
	
	# Setup wave delay timer
	wave_delay_timer = Timer.new()
	wave_delay_timer.wait_time = wave_delay
	wave_delay_timer.one_shot = true
	wave_delay_timer.timeout.connect(_start_next_wave)
	add_child(wave_delay_timer)
	

# === MAIN WAVE SYSTEM ===
func start_wave_system():
	"""PUBLIC: Start the entire wave system"""
	if current_wave == 0:
		current_wave = 1
		_start_current_wave()

func set_newest_spawning_room(room_rect: Rect2):
	"""PUBLIC: Set the room where enemies should spawn"""
	current_spawning_room = room_rect
	
	# If we haven't started waves yet, start now
	if current_wave == 0:
		start_wave_system()

func _start_current_wave():
	"""Start the current wave (ENHANCED: Boss logic for wave 10)"""
	if wave_active:
		return
	
	# Check if this is the boss wave
	if current_wave == boss_wave:
		_start_boss_wave()
		return
	
	# Normal wave logic
	wave_active = true
	spawning_active = true
	enemies_alive.clear()
	
	# Calculate enemies for this wave
	var total_enemies = base_enemies_per_wave + (current_wave - 1) * enemy_increase_per_wave
	
	# Spawn all enemies for this wave
	for i in range(total_enemies):
		var enemy = _spawn_single_enemy()
		if enemy:
			enemies_alive.append(enemy)
			enemy_spawned.emit(enemy)
	
	spawning_active = false

func _start_boss_wave():
	"""NEW: Start the epic boss wave"""
	wave_active = true
	spawning_active = true
	enemies_alive.clear()
	is_boss_spawned = false
	
	# Announce boss fight
	boss_fight_started.emit()
	
	# Spawn the boss with dramatic entrance
	var boss = _spawn_boss()
	if boss:
		boss_instance = boss
		is_boss_spawned = true
		enemies_alive.append(boss)
		boss_spawned.emit(boss)
		
		# Connect boss death signal
		if boss.has_signal("boss_defeated"):
			boss.boss_defeated.connect(_on_boss_defeated)
		elif boss.has_signal("enemy_died"):
			boss.enemy_died.connect(_on_enemy_died.bind(boss))
	
	spawning_active = false

func _spawn_boss() -> Node3D:
	"""NEW: Spawn the boss with special positioning"""
	var spawn_position = _find_boss_spawn_position()
	if spawn_position == Vector3.ZERO:
		return null
	
	var boss: Node3D
	
	# Check if we have a proper boss scene
	if boss_scene and boss_scene != enemy_scene:
		# Use the dedicated boss scene
		boss = boss_scene.instantiate()
	else:
		# Create boss from scratch since enemy scene won't work
		boss = _create_boss_from_scratch()
	
	if not boss:
		return null
	
	get_parent().add_child(boss)
	boss.global_position = spawn_position + Vector3(0, 20, 0)  # Start high for dramatic entry
	
	return boss

func _create_boss_from_scratch() -> CharacterBody3D:
	"""Create a boss node manually with correct structure"""
	# Create the main CharacterBody3D node
	var boss = CharacterBody3D.new()
	boss.name = "DemolitionKingBoss"
	
	# Add MeshInstance3D for visuals
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	boss.add_child(mesh_instance)
	
	# Create a simple box mesh (you can replace this with your boss model)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 3, 2)  # Make it bigger than regular enemies
	mesh_instance.mesh = box_mesh
	
	# Add collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	boss.add_child(collision_shape)
	
	# Create collision shape to match the mesh
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 3, 2)
	collision_shape.shape = shape
	
	# Attach the boss script
	var boss_script = load("res://Bosses/DemolitionKingBoss.gd")
	boss.set_script(boss_script)
	
	# Set up groups and physics layers
	boss.add_to_group("bosses")
	boss.add_to_group("enemies")
	boss.collision_layer = 4  # Boss layer
	boss.collision_mask = 1 | 8  # World + walls

	return boss

func _find_boss_spawn_position() -> Vector3:
	"""NEW: Find optimal spawn position for boss (near player but safe)"""
	var spawn_center = _get_spawn_center()
	
	# Boss spawns closer to player for dramatic effect
	var boss_distance_min = 6.0
	var boss_distance_max = 10.0
	
	# Try multiple positions around the spawn center
	for attempt in range(spawn_attempts):
		var angle = randf() * TAU
		var distance = randf_range(boss_distance_min, boss_distance_max)
		
		var test_position = spawn_center + Vector3(
			cos(angle) * distance,
			0.0,  # Ground level (boss will fall from sky)
			sin(angle) * distance
		)
		
		if _is_valid_spawn_position(test_position):
			return test_position
	
	return spawn_center + Vector3(randf_range(-8, 8), 0.0, randf_range(-8, 8))

func _spawn_single_enemy() -> Node3D:
	"""Spawn one regular enemy in the current room"""
	var spawn_position = _find_spawn_position()
	if spawn_position == Vector3.ZERO:
		return null
	
	# Create enemy
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	
	# Scale enemy for current wave
	_scale_enemy_for_wave(enemy)
	
	# Connect death signal
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	
	return enemy

func _find_spawn_position() -> Vector3:
	"""Find a valid spawn position for regular enemies"""
	var spawn_center = _get_spawn_center()
	
	# Try multiple positions around the spawn center
	for attempt in range(spawn_attempts):
		var angle = randf() * TAU
		var distance = randf_range(spawn_distance_min, spawn_distance_max)
		
		var test_position = spawn_center + Vector3(
			cos(angle) * distance,
			2.0,  # Always spawn at ground level
			sin(angle) * distance
		)
		
		if _is_valid_spawn_position(test_position):
			return test_position
	
	return spawn_center + Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3))

func _get_spawn_center() -> Vector3:
	"""Get the center point for spawning"""
	if current_spawning_room != Rect2():
		# Use room center
		var room_center = current_spawning_room.get_center()
		return Vector3(
			(room_center.x - map_size.x / 2) * 2.0,
			2.0,
			(room_center.y - map_size.y / 2) * 2.0
		)
	else:
		# Fallback to player position
		return player.global_position

func _is_valid_spawn_position(pos: Vector3) -> bool:
	"""Check if spawn position is valid"""
	# Check distance from player
	var player_distance = pos.distance_to(player.global_position)
	if player_distance < 2.0 or player_distance > 15.0:
		return false
	
	# Check for enemy overlap
	for enemy in enemies_alive:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) < 2.0:
			return false
	
	# Check terrain if available
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_is_valid_pos"):
		var grid_x = int((pos.x / 2.0) + (map_size.x / 2))
		var grid_y = int((pos.z / 2.0) + (map_size.y / 2))
		return terrain._is_valid_pos(grid_x, grid_y)
	
	return true

func _scale_enemy_for_wave(enemy: Node3D):
	"""Make enemies stronger each wave"""
	if not enemy:
		return
	
	# Scale health, damage, and speed based on wave
	var health_scale = 1.0 + (current_wave - 1) * 0.3  # +30% health per wave
	var damage_scale = 1.0 + (current_wave - 1) * 0.2  # +20% damage per wave
	var speed_scale = 1.0 + (current_wave - 1) * 0.1   # +10% speed per wave
	
	if "max_health" in enemy:
		enemy.max_health = int(enemy.max_health * health_scale)
		enemy.health = enemy.max_health
	
	if "attack_damage" in enemy:
		enemy.attack_damage = int(enemy.attack_damage * damage_scale)
	
	if "speed" in enemy:
		enemy.speed = enemy.speed * speed_scale

# === WAVE COMPLETION SYSTEM ===
func _on_enemy_died(enemy: Node3D):
	"""Called when an enemy dies"""
	enemies_alive.erase(enemy)
	
	# Check if wave is complete
	if enemies_alive.size() == 0 and wave_active:
		_complete_wave()

func _on_boss_defeated():
	"""NEW: Called when boss is defeated"""
	
	# Remove boss from enemies list
	if boss_instance and boss_instance in enemies_alive:
		enemies_alive.erase(boss_instance)
	
	boss_fight_completed.emit()
	
	# Complete the wave
	if enemies_alive.size() == 0 and wave_active:
		_complete_wave()

func _complete_wave():
	"""Complete the current wave"""
	wave_active = false
	
	if current_wave == boss_wave:
		pass
	else:
		print("🎉 WAVE ", current_wave, " COMPLETED!")
	
	# Emit signal for room generation
	wave_completed.emit(current_wave)
	
	# Check if all waves are done
	if current_wave >= max_waves:
		all_waves_completed.emit()
		return
	
	# Start delay for next wave (unless it's boss wave - that's the end)
	if current_wave < max_waves:
		wave_delay_timer.start()

func _start_next_wave():
	"""Start the next wave after delay"""
	current_wave += 1
	_start_current_wave()

# === PUBLIC API FOR UI AND OTHER SYSTEMS ===
func get_wave_info() -> Dictionary:
	"""Get current wave information for UI (ENHANCED: Boss info)"""
	var total_enemies_for_wave
	
	if current_wave == boss_wave:
		total_enemies_for_wave = 1  # Just the boss
	else:
		total_enemies_for_wave = base_enemies_per_wave + (current_wave - 1) * enemy_increase_per_wave
	
	return {
		"current_wave": current_wave,
		"max_waves": max_waves,
		"current_enemies": enemies_alive.size(),
		"enemies_spawned": total_enemies_for_wave if wave_active else 0,
		"total_enemies_for_wave": total_enemies_for_wave,
		"wave_active": wave_active,
		"is_spawning": spawning_active,
		"is_boss_wave": current_wave == boss_wave,  # NEW
		"boss_spawned": is_boss_spawned,  # NEW
		"boss_health": _get_boss_health()  # NEW
	}

func _get_boss_health() -> float:
	"""NEW: Get boss health percentage for UI"""
	if boss_instance and is_instance_valid(boss_instance):
		if "health" in boss_instance and "max_health" in boss_instance:
			return float(boss_instance.health) / float(boss_instance.max_health)
	return 0.0
