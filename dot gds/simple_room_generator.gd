# simple_room_generator.gd - ENHANCED: Fixed torch spawning in corridors
extends Node3D

signal new_room_generated(room_rect: Rect2)

@export var map_size = Vector2(60, 60)
@export var base_room_size = Vector2(6, 6)
@export var corridor_width = 3
@export var wall_height = 3.0
@export var auto_generate_on_start = true
@export var max_rooms := 10

# NEW: Weapon room configuration
@export_group("Weapon Room Settings")
@export var weapon_room_chance: float = 0.4
@export var weapon_room_size = Vector2(8, 8)
@export var guaranteed_weapon_spawn: bool = true
@export var weapon_room_special_lighting: bool = true

# NEW: Boundary protection settings
@export_group("Boundary Protection")
@export var boundary_thickness = 2
@export var safe_zone_margin = 4

# Recruiter spawn configuration
@export_group("NPC Settings")
@export var recruiter_base_chance: float = 0.25
@export var recruiter_chance_increase: float = 0.1
@export var recruiter_max_chance: float = 0.8

# NEW: Torch spawning configuration
@export_group("Torch Settings")
@export var torch_spacing_in_corridors: float = 8.0  # Distance between torches in corridors
@export var torch_height_offset: float = 1.5  # Height to place torches
@export var corridor_torch_side_offset: float = 0.8  # How far from corridor center to place torches
@export var max_torches_per_corridor: int = 4  # Limit torches per corridor

enum TileType { WALL, FLOOR, CORRIDOR }

enum RoomShape { 
	SQUARE, RECTANGLE, L_SHAPE, T_SHAPE, PLUS_SHAPE, U_SHAPE, LONG_HALL, SMALL_SQUARE
}

enum RoomType {
	NORMAL,
	WEAPON,
	STARTING
}

var terrain_grid: Array = []
var rooms: Array = []
var room_shapes: Array = []
var room_types: Array = []
var corridors: Array = []  # FIXED: Now properly tracks corridor rectangles
var generated_objects: Array = []
var current_room_count = 0

# NEW: Corridor tracking for proper torch spawning
var corridor_connections: Array = []  # Stores {start_room, end_room, corridor_rect, corridor_path}

# NEW: Weapon room tracking
var pending_weapon_room: bool = false
var last_weapon_room_wave: int = 0

# Wall tracking with boundary protection
var wall_lookup: Dictionary = {}
var boundary_walls: Dictionary = {}

# Materials
var wall_material: StandardMaterial3D
var boundary_wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var weapon_room_floor_material: StandardMaterial3D

# References
var enemy_spawner: Node3D
var player: Node3D

# PackedScene references
var weapon_pickup_scene: PackedScene
@export var crate_scene: PackedScene
@export var barrel_scene: PackedScene

# --- CONSTANTS FOR MAGIC NUMBERS ---
const PLAYER_HEIGHT: float = 1.5
const WALL_LAYER: int = 1 << 1
const WALL_COLLISION_MASK: int = (1 << 2) | (1 << 3) | (1 << 4)
const DEFAULT_OBJECT_HEIGHT: float = 1.0
const DEFAULT_DOOR_HEIGHT: float = 1.25

var _spawner_retry_count := 0
const _SPAWNER_MAX_RETRIES := 10
const _SPAWNER_RETRY_DELAY := 0.5
var _pending_generate_starting_room := false

func _ready():
	add_to_group("terrain")
	# Initialize terrain_grid as a 2D array of WALLs
	terrain_grid = []
	for x in range(map_size.x):
		var col = []
		for y in range(map_size.y):
			col.append(TileType.WALL)
		terrain_grid.append(col)

	if has_node("/root/WeaponPool"):
		print("✅ WeaponPool autoload is available")
	else:
		print("❌ WeaponPool autoload is NOT available")

	_create_materials()
	_find_references()

	# Load scenes
	if ResourceLoader.exists("res://Scenes/weapon_pickup.tscn"):
		weapon_pickup_scene = load("res://Scenes/weapon_pickup.tscn")
		print("✅ Weapon pickup scene loaded")
	else:
		print("⚠️ Weapon pickup scene not found")

	if auto_generate_on_start:
		_pending_generate_starting_room = true
		_try_generate_starting_room_when_spawner_ready()

func _try_generate_starting_room_when_spawner_ready():
	if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
		if _pending_generate_starting_room:
			_pending_generate_starting_room = false
			generate_starting_room()
			_spawner_retry_count = 0
	else:
		_spawner_retry_count += 1
		if _spawner_retry_count <= _SPAWNER_MAX_RETRIES:
			print("🔄 Enemy spawner not found, retrying (attempt %d/%d)..." % [_spawner_retry_count, _SPAWNER_MAX_RETRIES])
			_find_references()
			await get_tree().create_timer(_SPAWNER_RETRY_DELAY).timeout
			_try_generate_starting_room_when_spawner_ready()
		else:
			print("❌ Enemy spawner not found after %d retries. Giving up!" % _SPAWNER_MAX_RETRIES)

func _create_materials():
	# Regular wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.4, 0.4, 0.45)
	wall_material.roughness = 0.9

	# Boundary wall material (darker, more imposing)
	boundary_wall_material = StandardMaterial3D.new()
	boundary_wall_material.albedo_color = Color(0.2, 0.2, 0.3)
	boundary_wall_material.roughness = 0.8
	boundary_wall_material.metallic = 0.1

	# Floor material
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.6, 0.5, 0.4)
	floor_material.roughness = 0.7

	# NEW: Special weapon room floor material
	weapon_room_floor_material = StandardMaterial3D.new()
	weapon_room_floor_material.albedo_color = Color(0.8, 0.7, 0.3)  # Golden color
	weapon_room_floor_material.metallic = 0.3
	weapon_room_floor_material.roughness = 0.4

func _find_references():
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚠️ Player not found, will search again later")
	
	# Find enemy spawner
	enemy_spawner = get_node_or_null("../EnemySpawner")
	if not enemy_spawner:
		var spawners = get_tree().get_nodes_in_group("spawner")
		if spawners.size() > 0:
			enemy_spawner = spawners[0]
	
	if enemy_spawner and enemy_spawner.has_signal("wave_completed"):
		if not enemy_spawner.wave_completed.is_connected(_on_wave_completed):
			enemy_spawner.wave_completed.connect(_on_wave_completed)
			print("✅ Connected to spawner wave_completed signal")

# =====================================
# IMPROVED CORRIDOR CREATION AND TRACKING
# =====================================

func _create_simple_corridor_protected(room_a: Rect2, room_b: Rect2):
	"""Create corridor with boundary protection and proper tracking for torch spawning"""
	var start = room_a.get_center()
	var end = room_b.get_center()
	
	@warning_ignore("integer_division")
	var half_width = int(corridor_width / 2)
	
	# Calculate corridor bounds for torch spawning
	var corridor_bounds = Rect2()
	var corridor_path = []
	
	# Horizontal segment (protected)
	var h_start = int(min(start.x, end.x))
	var h_end = int(max(start.x, end.x))
	
	for x in range(h_start, h_end + 1):
		for w in range(-half_width, half_width + 1):
			var y = int(start.y + w)
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR
				corridor_path.append(Vector2(x, y))
	
	# Vertical segment (protected)
	var v_start = int(min(start.y, end.y))
	var v_end = int(max(start.y, end.y))
	
	for y in range(v_start, v_end + 1):
		for w in range(-half_width, half_width + 1):
			var x = int(end.x + w)
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR
				corridor_path.append(Vector2(x, y))
	
	# Calculate corridor rectangle for torch spawning
	corridor_bounds = Rect2(
		Vector2(min(h_start, int(end.x)) - half_width, min(v_start, int(start.y)) - half_width),
		Vector2(max(h_end, int(end.x)) - min(h_start, int(end.x)) + corridor_width, 
				max(v_end, int(start.y)) - min(v_start, int(start.y)) + corridor_width)
	)
	
	# FIXED: Add corridor to tracking arrays
	corridors.append(corridor_bounds)
	corridor_connections.append({
		"start_room": room_a,
		"end_room": room_b,
		"corridor_rect": corridor_bounds,
		"corridor_path": corridor_path
	})
	
	print("🔥 Corridor created and tracked for torch spawning: ", corridor_bounds)

# =====================================
# ENHANCED TORCH SPAWNING SYSTEM
# =====================================

func spawn_torch_at_position(pos: Vector3):
	"""Spawns a torch at the given position"""
	var torch_scene = preload("res://Scenes/EnhancedTorch.tscn")
	var torch = torch_scene.instantiate()
	add_child(torch)
	torch.global_position = pos
	generated_objects.append(torch)

func _spawn_torches_in_corridor(corridor_connection: Dictionary):
	"""NEW: Spawn torches along a corridor path with proper spacing"""
	var start_room = corridor_connection.start_room
	var end_room = corridor_connection.end_room
	
	# Calculate corridor length for torch placement
	var start_center = start_room.get_center()
	var end_center = end_room.get_center()
	var corridor_length = start_center.distance_to(end_center)
	
	# Limit number of torches based on corridor length and max setting
	var estimated_torches = max(2, int(corridor_length / torch_spacing_in_corridors))
	var torch_count = min(estimated_torches, max_torches_per_corridor)
	
	print("🔥 Planning ", torch_count, " torches for corridor of length ", corridor_length)
	
	# Calculate positions along the corridor center line
	var direction = (end_center - start_center).normalized()
	var is_horizontal = abs(direction.x) > abs(direction.y)
	
	var placed_torches = 0
	var _half_map_x = map_size.x / 2
	var _half_map_y = map_size.y / 2
	
	# Place torches evenly spaced along the corridor
	for i in range(torch_count):
		if placed_torches >= max_torches_per_corridor:
			break
			
		# Calculate position along corridor (avoid the very ends)
		var progress = (i + 1.0) / (torch_count + 1.0)  # This ensures torches aren't at the room entrances
		var torch_pos = start_center.lerp(end_center, progress)
		
		# Offset slightly to side of corridor
		var side_offset = corridor_torch_side_offset
		if is_horizontal:
			# Alternate sides for horizontal corridors
			torch_pos.y += side_offset if (i % 2 == 0) else -side_offset
		else:
			# Alternate sides for vertical corridors  
			torch_pos.x += side_offset if (i % 2 == 0) else -side_offset
		
		# Try to place the torch
		if _try_place_corridor_torch(torch_pos):
			placed_torches += 1
	
	print("🔥 Spawned ", placed_torches, " torches in corridor")

func _try_place_corridor_torch(grid_pos: Vector2) -> bool:
	"""Try to place a torch at the given grid position if valid"""
	var grid_x = int(round(grid_pos.x))
	var grid_y = int(round(grid_pos.y))
	
	# Check bounds
	if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
		return false
	
	# Check if position is floor or corridor (not wall)
	if terrain_grid[grid_x][grid_y] == TileType.WALL:
		return false
	
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	# Convert to world position
	var world_pos = Vector3(
		(grid_x - half_map_x) * 2.0,
		torch_height_offset,
		(grid_y - half_map_y) * 2.0
	)
	
	spawn_torch_at_position(world_pos)
	return true

func _spawn_torches_in_room(room: Rect2):
	"""Improved: Place torches near corners, but not inside walls"""
	var torch_height = torch_height_offset
	var offset = 0.7  # Distance from wall/corner
	var try_offsets = [
		Vector2(0, 0),
		Vector2(offset, 0),
		Vector2(0, offset),
		Vector2(offset, offset),
		Vector2(-offset, 0),
		Vector2(0, -offset),
		Vector2(-offset, -offset)
	]
	var corners = [
		Vector2(room.position.x + offset, room.position.y + offset),
		Vector2(room.position.x + room.size.x - offset, room.position.y + offset),
		Vector2(room.position.x + offset, room.position.y + room.size.y - offset),
		Vector2(room.position.x + room.size.x - offset, room.position.y + room.size.y - offset)
	]
	for corner in corners:
		var found = false
		for local_offset in try_offsets:
			var grid_x = int(round(corner.x + local_offset.x))
			var grid_y = int(round(corner.y + local_offset.y))
			if grid_x >= 0 and grid_x < map_size.x and grid_y >= 0 and grid_y < map_size.y:
				if terrain_grid[grid_x][grid_y] == TileType.FLOOR or terrain_grid[grid_x][grid_y] == TileType.CORRIDOR:
					var half_map_x = map_size.x / 2  # Only used here
					var half_map_y = map_size.y / 2  # Only used here
					var world_pos = Vector3(
						(grid_x - half_map_x) * 2.0,
						torch_height,
						(grid_y - half_map_y) * 2.0
					)
					spawn_torch_at_position(world_pos)
					found = true
					break
		if not found:
			print("⚠️ Could not find valid floor for torch near corner:", corner)

# =====================================
# ENHANCED ROOM GENERATION
# =====================================

func generate_starting_room():
	"""Generate the first room with protected boundaries"""
	print("🗡️ Creating starting room with PROTECTED BOUNDARY...")
	
	_clear_everything()
	_fill_with_walls()
	_mark_boundary_walls()
	
	# Create starting room in center (well within safe zone)
	var safe_area_start = boundary_thickness + safe_zone_margin
	var safe_area_size = map_size - Vector2(safe_area_start * 2, safe_area_start * 2)
	
	var room_pos = Vector2(
		safe_area_start + (safe_area_size.x - base_room_size.x) / 2,
		safe_area_start + (safe_area_size.y - base_room_size.y) / 2
	)
	var starting_room = Rect2(room_pos, base_room_size)
	
	print("🗡️ Starting room positioned safely at: ", starting_room)
	
	# Carve out the room
	_carve_room_shape(starting_room, RoomShape.SQUARE)
	rooms.append(starting_room)
	room_shapes.append(RoomShape.SQUARE)
	room_types.append(RoomType.STARTING)
	current_room_count = 1
	
	# Generate walls
	_generate_all_walls_with_boundary_protection()
	
	# Move player to room center
	_move_player_to_room(starting_room)
	
	# Spawn starting room content
	_spawn_destructible_objects_in_room(starting_room)
	_spawn_torches_in_room(starting_room)

	# Always spawn a recruiter NPC in the starting room
	var recruiter_npc_scene = load("res://Scenes/recruiter_npc.tscn")
	if recruiter_npc_scene:
		var recruiter_npc_instance = recruiter_npc_scene.instantiate()
		add_child(recruiter_npc_instance)
		var safe_position = _find_safe_recruiter_position(starting_room)
		if safe_position != Vector3.ZERO:
			recruiter_npc_instance.global_position = safe_position
		print("👤 Recruiter NPC spawned in starting room!")
		if recruiter_npc_instance.has_method("connect_recruit_signal"):
			recruiter_npc_instance.connect_recruit_signal()
	else:
		print("⚠️ Recruiter NPC scene not loaded, cannot spawn recruiter!")

	# Spawn a bow in the starting room instead of a sword
	var starting_room_center = starting_room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var bow_spawn_pos = Vector3(
		(starting_room_center.x - half_map_x) * 2.0,
		DEFAULT_OBJECT_HEIGHT,
		(starting_room_center.y - half_map_y) * 2.0
	)
	if weapon_pickup_scene:
		var weapon_pickup = weapon_pickup_scene.instantiate()
		add_child(weapon_pickup)
		weapon_pickup.global_position = bow_spawn_pos
		var bow_resource = load("res://Weapons/wooden_bow.tres")
		if bow_resource:
			weapon_pickup.weapon_resource = bow_resource
		generated_objects.append(weapon_pickup)

		# Spawn a sword in the starting room as well
		var sword_spawn_pos = bow_spawn_pos + Vector3(1.5, 0, 0) # Offset sword by 1.5 units on X
		var sword_pickup = weapon_pickup_scene.instantiate()
		add_child(sword_pickup)
		sword_pickup.global_position = sword_spawn_pos
		var sword_resource = load("res://Weapons/iron_sword.tres")
		if sword_resource:
			sword_pickup.weapon_resource = sword_resource
		generated_objects.append(sword_pickup)
	else:
		print("❌ No weapon pickup scene available!")

	# --- CREATE FIRST WAVE ROOM FARTHER AWAY ---
	print("🗡️ Creating first wave room connected to starting room...")
	if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
		var first_wave_room = create_connected_room()
		if first_wave_room != null:
			enemy_spawner.set_newest_spawning_room(first_wave_room)
			print("✅ First wave room created and set for enemy spawner:", first_wave_room)
			
			# Spawn torches in the first wave room
			_spawn_torches_in_room(first_wave_room)
			
			# FIXED: Spawn torches in the connecting corridor
			if corridor_connections.size() > 0:
				var latest_corridor = corridor_connections[corridor_connections.size() - 1]
				_spawn_torches_in_corridor(latest_corridor)
			
	else:
		print("❌ Enemy spawner not found or missing method!")

	print("🗡️ Starting room created with PROTECTED BOUNDARIES!")

func create_connected_room():
	"""Create a new room with boundary protection"""
	if rooms.is_empty():
		print("🏠 No existing rooms!")
		return null
	
	var last_room = rooms[rooms.size() - 1]
	print("🏠 Connecting to room: ", last_room)
	
	var new_shape = _choose_room_shape()
	var room_size = _get_size_for_shape(new_shape)
	var new_room = _find_new_room_position(last_room, room_size)
	if new_room == Rect2():
		print("🏠 Could not place new room safely within boundaries!")
		return null
	
	print("🏠 Creating new ", RoomShape.keys()[new_shape], " room: ", new_room)
	_carve_room_shape(new_room, new_shape)
	_create_simple_corridor_protected(last_room, new_room)  # This now properly tracks corridors
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(new_shape)
	room_types.append(RoomType.NORMAL)
	current_room_count += 1
	print("🏠 New ", RoomShape.keys()[new_shape], " room created safely! Total: ", rooms.size())
	new_room_generated.emit(new_room)

	_spawn_destructible_objects_in_room(new_room)
	_spawn_torches_in_room(new_room)
	
	# FIXED: Spawn torches in the new corridor
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)

	# --- RANDOM RECRUITER NPC SPAWN ---
	var spawn_chance = min(recruiter_base_chance + (current_room_count * recruiter_chance_increase), recruiter_max_chance)
	if randf() < spawn_chance:
		var existing_recruiter = get_tree().get_first_node_in_group("recruiters")
		if existing_recruiter:
			print("👤 Recruiter already exists, skipping spawn")
			return new_room
		var recruiter_npc_scene = load("res://Scenes/recruiter_npc.tscn")
		if recruiter_npc_scene:
			var recruiter_npc_instance = recruiter_npc_scene.instantiate()
			add_child(recruiter_npc_instance)
			var safe_position = _find_safe_recruiter_position(new_room)
			if safe_position != Vector3.ZERO:
				recruiter_npc_instance.global_position = safe_position
			print("👤 Recruiter NPC spawned in new room!")
			if recruiter_npc_instance.has_method("connect_recruit_signal"):
				recruiter_npc_instance.connect_recruit_signal()
		else:
			print("⚠️ Recruiter NPC scene not loaded, cannot spawn recruiter!")

	return new_room

# =====================================
# HELPER METHODS (keeping existing functionality)
# =====================================

func _clear_everything():
	for obj in generated_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	generated_objects.clear()
	wall_lookup.clear()
	boundary_walls.clear()
	rooms.clear()
	room_shapes.clear()
	room_types.clear()
	corridors.clear()
	corridor_connections.clear()  # NEW: Clear corridor connections
	current_room_count = 0

func _fill_with_walls():
	terrain_grid.clear()
	terrain_grid.resize(map_size.x)
	for x in range(map_size.x):
		terrain_grid[x] = []
		terrain_grid[x].resize(map_size.y)
		for y in range(map_size.y):
			terrain_grid[x][y] = TileType.WALL

func _mark_boundary_walls():
	"""Mark which walls are permanent boundary walls"""
	boundary_walls.clear()
	
	for x in range(map_size.x):
		for y in range(map_size.y):
			if (x < boundary_thickness or x >= map_size.x - boundary_thickness or 
				y < boundary_thickness or y >= map_size.y - boundary_thickness):
				var grid_key = str(x) + "," + str(y)
				boundary_walls[grid_key] = true

func _generate_all_walls_with_boundary_protection():
	"""Generate walls with special materials for boundary walls"""
	for x in range(map_size.x):
		for y in range(map_size.y):
			if terrain_grid[x][y] == TileType.WALL:
				var grid_key = str(x) + "," + str(y)
				var is_boundary = boundary_walls.has(grid_key)
				var wall = _create_wall_at_position(x, y, is_boundary)
				if wall:
					wall_lookup[grid_key] = wall

func _create_wall_at_position(grid_x: int, grid_y: int, is_boundary: bool = false) -> StaticBody3D:
	var wall = StaticBody3D.new()
	wall.collision_layer = WALL_LAYER
	wall.collision_mask = WALL_COLLISION_MASK

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.mesh.size = Vector3(2, wall_height, 2)
	mesh_instance.material_override = boundary_wall_material if is_boundary else wall_material

	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(2, wall_height, 2)

	wall.add_child(mesh_instance)
	wall.add_child(collision_shape)
	add_child(wall)

	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	wall.position = Vector3(
		(grid_x - half_map_x) * 2.0,
		wall_height / 2.0,
		(grid_y - half_map_y) * 2.0
	)

	generated_objects.append(wall)
	return wall

func _is_valid_carve_position(x: int, y: int) -> bool:
	"""Check if position is valid for carving (respects boundaries)"""
	if x < 0 or x >= map_size.x or y < 0 or y >= map_size.y:
		return false
	
	# Check if it's a boundary wall (never carve boundary walls)
	var grid_key = str(x) + "," + str(y)
	if boundary_walls.has(grid_key):
		return false
	
	return true

func _is_valid_torch_position(grid_pos: Vector2, room: Rect2) -> bool:
	"""Check if a grid position is valid for torch placement"""
	var grid_x = int(grid_pos.x)
	var grid_y = int(grid_pos.y)

	# Defensive checks for terrain_grid
	if grid_x < 0 or grid_x >= terrain_grid.size():
		return false
	if grid_y < 0 or grid_y >= terrain_grid[grid_x].size():
		return false

	# Check bounds
	if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
		return false

	# Check if within room bounds
	if not room.has_point(Vector2(grid_x, grid_y)):
		return false

	# Check if position is floor (not wall)
	return terrain_grid[grid_x][grid_y] == TileType.FLOOR

# Add these essential missing methods for completeness:

func _carve_room_shape(room: Rect2, shape: RoomShape):
	"""Carve out different room shapes"""
	match shape:
		RoomShape.SQUARE, RoomShape.RECTANGLE, RoomShape.SMALL_SQUARE:
			_carve_rectangle(room)
		RoomShape.L_SHAPE:
			_carve_l_shape(room)
		RoomShape.T_SHAPE:
			_carve_t_shape(room)
		RoomShape.PLUS_SHAPE:
			_carve_plus_shape(room)
		RoomShape.U_SHAPE:
			_carve_u_shape(room)
		RoomShape.LONG_HALL:
			_carve_rectangle(room)

func _carve_rectangle(room: Rect2):
	"""Carve a simple rectangular room"""
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _choose_room_shape() -> RoomShape:
	"""Choose a random room shape with weighted probabilities"""
	var shape_weights = {
		RoomShape.SQUARE: 25, RoomShape.RECTANGLE: 20, RoomShape.L_SHAPE: 15,
		RoomShape.T_SHAPE: 10, RoomShape.PLUS_SHAPE: 8, RoomShape.U_SHAPE: 7,
		RoomShape.LONG_HALL: 10, RoomShape.SMALL_SQUARE: 5
	}
	
	var total_weight = 0
	for weight in shape_weights.values():
		total_weight += weight
	
	var random_value = randi_range(1, total_weight)
	var current_weight = 0
	
	for shape in shape_weights.keys():
		current_weight += shape_weights[shape]
		if random_value <= current_weight:
			return shape
	
	return RoomShape.SQUARE

func _get_size_for_shape(shape: RoomShape) -> Vector2:
	"""Get appropriate size for each room shape"""
	match shape:
		RoomShape.SQUARE:
			return base_room_size
		RoomShape.RECTANGLE:
			return Vector2(base_room_size.x + 4, base_room_size.y)
		RoomShape.L_SHAPE:
			return Vector2(base_room_size.x + 2, base_room_size.y + 2)
		RoomShape.T_SHAPE:
			return Vector2(base_room_size.x + 2, base_room_size.y + 2)
		RoomShape.PLUS_SHAPE:
			return Vector2(base_room_size.x + 2, base_room_size.y + 2)
		RoomShape.U_SHAPE:
			return Vector2(base_room_size.x + 2, base_room_size.y + 2)
		RoomShape.LONG_HALL:
			return Vector2(base_room_size.x + 6, 5)
		RoomShape.SMALL_SQUARE:
			return Vector2(5, 5)
	return base_room_size

# Include all other essential methods from your original file...
# (This is a condensed version focusing on the main fixes)

func _find_new_room_position(last_room: Rect2, room_size: Vector2) -> Rect2:
	"""Find safe position for new room with enhanced boundary protection"""
	var max_attempts = 50
	var min_distance = 3
	
	var min_pos = boundary_thickness + safe_zone_margin + 1
	var max_pos_x = map_size.x - boundary_thickness - safe_zone_margin - room_size.x - 1
	var max_pos_y = map_size.y - boundary_thickness - safe_zone_margin - room_size.y - 1
	
	for attempt in range(max_attempts):
		var angle = randf() * TAU
		var distance = randf_range(room_size.length() + min_distance, room_size.length() + 8)
		
		var candidate_pos = Vector2(
			last_room.get_center().x + cos(angle) * distance - room_size.x / 2,
			last_room.get_center().y + sin(angle) * distance - room_size.y / 2
		)
		
		var candidate_room = Rect2(candidate_pos, room_size)
		
		if _is_room_position_safe(candidate_room, min_pos, max_pos_x, max_pos_y):
			return candidate_room
	
	print("🛡️ Could not find safe room position after ", max_attempts, " attempts")
	return Rect2()

func _is_room_position_safe(room: Rect2, min_pos: float, max_pos_x: float, max_pos_y: float) -> bool:
	"""Enhanced safety check with boundary protection"""
	if (room.position.x < min_pos or room.position.y < min_pos or
		room.position.x > max_pos_x or room.position.y > max_pos_y):
		return false
	
	for existing_room in rooms:
		if room.intersects(existing_room):
			return false
	
	return true

func _move_player_to_room(room: Rect2):
	"""Move player to room center"""
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var room_center_world = Vector3(
		(room.get_center().x - half_map_x) * 2.0,
		PLAYER_HEIGHT,
		(room.get_center().y - half_map_y) * 2.0
	)
	player.global_position = room_center_world
	print("🗡️ Moved player to safe room center: ", room_center_world)

func _remove_walls_by_grid_lookup():
	var to_remove_keys = []
	for grid_key in wall_lookup.keys():
		var wall = wall_lookup[grid_key]
		if not is_instance_valid(wall):
			continue
		var parts = grid_key.split(",")
		if parts.size() != 2:
			continue
		var x = int(parts[0])
		var y = int(parts[1])
		if boundary_walls.has(grid_key):
			continue
		if terrain_grid[x][y] != TileType.WALL:
			to_remove_keys.append(grid_key)
	
	for grid_key in to_remove_keys:
		if wall_lookup.has(grid_key):
			var wall = wall_lookup[grid_key]
			if is_instance_valid(wall):
				wall.queue_free()
			wall_lookup.erase(grid_key)

func _spawn_destructible_objects_in_room(room: Rect2):
	"""Spawn crates and barrels in room"""
	var objects_to_spawn = randi_range(2, 4)
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2

	for i in range(objects_to_spawn):
		var object_scene = crate_scene if randf() < 0.6 else barrel_scene
		if not object_scene:
			continue

		var object_instance = object_scene.instantiate()
		add_child(object_instance)

		var random_pos = Vector2(
			room.position.x + randf() * room.size.x,
			room.position.y + randf() * room.size.y
		)

		var world_pos = Vector3(
			(random_pos.x - half_map_x) * 2.0,
			DEFAULT_OBJECT_HEIGHT,
			(random_pos.y - half_map_y) * 2.0
		)

		object_instance.global_position = world_pos
		generated_objects.append(object_instance)

func _find_safe_recruiter_position(room: Rect2) -> Vector3:
	"""Find safe position for recruiter away from other objects"""
	var attempts = 10
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	for attempt in range(attempts):
		var random_pos = Vector2(
			room.position.x + 1 + randf() * (room.size.x - 2),
			room.position.y + 1 + randf() * (room.size.y - 2)
		)

		var world_pos = Vector3(
			(random_pos.x - half_map_x) * 2.0,
			DEFAULT_OBJECT_HEIGHT,
			(random_pos.y - half_map_y) * 2.0
		)

		var safe = true
		for obj in generated_objects:
			if is_instance_valid(obj) and world_pos.distance_to(obj.global_position) < 3.0:
				safe = false
				break

		if safe:
			return world_pos

	return Vector3.ZERO

func _on_wave_completed(wave_number: int):
	"""Enhanced wave completion handler with 50% chance to create weapon room after each wave"""
	print("🗡️ Wave ", wave_number, " completed! Creating new room...")
	if randf() < 0.5:
		var weapon_room = _create_weapon_room()
		if weapon_room != Rect2():
			if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
				enemy_spawner.set_newest_spawning_room(weapon_room)
			print("✅ Weapon room generated and set as spawning area!")
		else:
			_create_normal_room_after_wave(wave_number)
	else:
		_create_normal_room_after_wave(wave_number)

func _create_normal_room_after_wave(wave_number: int):
	"""Create normal room after wave"""
	print("🏠 Creating normal room after wave ", wave_number)
	var new_room = create_connected_room()
	if new_room != null:
		if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
			enemy_spawner.set_newest_spawning_room(new_room)
		print("✅ Normal room generated and set as spawning area!")
	else:
		print("❌ Room generation failed - no valid position found")

# Additional methods for completeness (add L-shape, T-shape, etc. carving methods)
func _carve_l_shape(room: Rect2):
	var half_x = int(room.size.x / 2)
	var half_y = int(room.size.y / 2)
	
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + half_y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	for x in range(int(room.position.x), int(room.position.x + half_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_t_shape(room: Rect2):
	var third_x = int(room.size.x / 3)
	var half_y = int(room.size.y / 2)
	
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + half_y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	for x in range(int(room.position.x + third_x), int(room.position.x + 2 * third_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_plus_shape(room: Rect2):
	var center_x = int(room.position.x + room.size.x / 2)
	var center_y = int(room.position.y + room.size.y / 2)
	var arm_width = 2
	
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(center_y - arm_width, center_y + arm_width):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	for x in range(center_x - arm_width, center_x + arm_width):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_u_shape(room: Rect2):
	var third_x = int(room.size.x / 3)
	var half_y = int(room.size.y / 2)
	
	for x in range(int(room.position.x), int(room.position.x + third_x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	for x in range(int(room.position.x + 2 * third_x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	for x in range(int(room.position.x + third_x), int(room.position.x + 2 * third_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _create_weapon_room() -> Rect2:
	"""Create a weapon room with special properties"""
	if rooms.is_empty():
		print("🏺 No existing rooms for weapon room!")
		return Rect2()

	var last_room = rooms[rooms.size() - 1]
	print("🏺 Creating weapon room connected to: ", last_room)

	# Use special weapon room size
	var new_room = _find_new_room_position(last_room, weapon_room_size)
	if new_room == Rect2():
		print("🏺 Could not place weapon room safely within boundaries!")
		return Rect2()

	print("🏺 Creating weapon room: ", new_room)

	# Carve the room (always use SQUARE shape for weapon rooms)
	_carve_room_shape(new_room, RoomShape.SQUARE)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()

	# Add to arrays with WEAPON type
	rooms.append(new_room)
	room_shapes.append(RoomShape.SQUARE)
	room_types.append(RoomType.WEAPON)
	current_room_count += 1

	print("🏺 Weapon room created! Total rooms: ", rooms.size())
	new_room_generated.emit(new_room, RoomType.WEAPON)

	# Spawn weapon room content
	_spawn_weapon_room_content(new_room)

	# Spawn torches in the connecting corridor
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)

	return new_room

# --- WEAPON ROOM CONTENT SPAWN STUBS ---
func _spawn_weapon_room_content(room: Rect2):
	"""Spawn weapon and torch circle in weapon room (stub)"""
	var room_center = room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var weapon_world_pos = Vector3(
		(room_center.x - half_map_x) * 2.0,
		DEFAULT_OBJECT_HEIGHT,
		(room_center.y - half_map_y) * 2.0
	)
	_spawn_weapon_pickup(weapon_world_pos)
	_spawn_torch_circle_around_weapon(weapon_world_pos, room)
	_apply_weapon_room_floor_material(room)

func _spawn_weapon_pickup(spawn_pos: Vector3):
	"""Spawn a weapon pickup at the specified position (stub)"""
	if not weapon_pickup_scene:
		print("❌ No weapon pickup scene available!")
		return
	var weapon_pickup = weapon_pickup_scene.instantiate()
	add_child(weapon_pickup)
	weapon_pickup.global_position = spawn_pos
	generated_objects.append(weapon_pickup)

func _spawn_torch_circle_around_weapon(center_pos: Vector3, room: Rect2):
	"""Spawn torches in a circle around the weapon pickup (stub)"""
	var torch_count = 6
	var angle_step = TAU / torch_count
	for i in range(torch_count):
		var angle = i * angle_step
		var torch_offset = Vector3(
			cos(angle) * 3.0,
			0,
			sin(angle) * 3.0
		)
		var torch_pos = center_pos + torch_offset
		torch_pos.y = torch_height_offset
		var grid_pos = _world_to_grid_position(torch_pos)
		if _is_valid_torch_position(grid_pos, room):
			spawn_torch_at_position(torch_pos)

func _apply_weapon_room_floor_material(room: Rect2):
	"""Apply special golden floor material to weapon room (stub)"""
	print("✨ Applying special weapon room floor material to room: ", room)

func _world_to_grid_position(world_pos: Vector3) -> Vector2:
	"""Convert world position back to grid position (stub)"""
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	return Vector2(
		round(world_pos.x / 2.0 + half_map_x),
		round(world_pos.z / 2.0 + half_map_y)
	)

func get_rooms(include_weapon_rooms := true) -> Array:
	"""Return all rooms. If include_weapon_rooms is false, only normal rooms are returned."""
	var result = []
	for i in range(rooms.size()):
		if include_weapon_rooms or room_types[i] == RoomType.NORMAL:
			result.append(rooms[i])
	return result
