# simple_room_generator.gd - ENHANCED: Fixed torch spawning in corridors
extends Node3D

signal new_room_generated(room_rect: Rect2)

@export var map_size = Vector2(60, 60)
@export var base_room_size = Vector2(6, 6)
@export var corridor_width = 3
@export var wall_height = 3.0
@export var auto_generate_on_start = true
@export var max_rooms := 10

@export_group("Weapon Room Settings")
@export var weapon_room_chance: float = 0.4
@export var weapon_room_size = Vector2(8, 8)

@export_group("Boundary Protection")
@export var boundary_thickness = 2
@export var safe_zone_margin = 4

@export_group("Torch Settings")
@export var torch_spacing_in_corridors: float = 8.0
@export var torch_height_offset: float = 1.5
@export var corridor_torch_side_offset: float = 0.8
@export var max_torches_per_corridor: int = 4

enum TileType { WALL, FLOOR, CORRIDOR }
enum RoomShape { SQUARE, RECTANGLE, L_SHAPE, T_SHAPE, PLUS_SHAPE, U_SHAPE, LONG_HALL, SMALL_SQUARE }
enum RoomType { NORMAL, WEAPON, STARTING }

var terrain_grid: Array = []
var rooms: Array = []
var room_shapes: Array = []
var room_types: Array = []
var corridors: Array = []
var generated_objects: Array = []
var current_room_count = 0
var corridor_connections: Array = []
var wall_lookup: Dictionary = {}
var boundary_walls: Dictionary = {}
var wall_material: StandardMaterial3D
var boundary_wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var weapon_room_floor_material: StandardMaterial3D
var enemy_spawner: Node3D
var player: Node3D
var weapon_pickup_scene: PackedScene
@export var crate_scene: PackedScene
@export var barrel_scene: PackedScene
@export var altar_scene: PackedScene
@export var mushroom_scene: PackedScene

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
	terrain_grid = []
	for x in range(map_size.x):
		var col = []
		for y in range(map_size.y):
			col.append(TileType.WALL)
		terrain_grid.append(col)
	_create_materials()
	_find_references()
	# Set default crate and barrel scenes if not assigned in the editor
	if not crate_scene and ResourceLoader.exists("res://Scenes/DestructibleCrate.tscn"):
		crate_scene = load("res://Scenes/DestructibleCrate.tscn")
	if not barrel_scene and ResourceLoader.exists("res://Scenes/destructible_barrel.tscn"):
		barrel_scene = load("res://Scenes/destructible_barrel.tscn")
	if ResourceLoader.exists("res://Scenes/weapon_pickup.tscn"):
		weapon_pickup_scene = load("res://Scenes/weapon_pickup.tscn")
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
			_find_references()
			await get_tree().create_timer(_SPAWNER_RETRY_DELAY).timeout
			_try_generate_starting_room_when_spawner_ready()

func _create_materials():
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.4, 0.4, 0.45)
	wall_material.roughness = 0.9
	boundary_wall_material = StandardMaterial3D.new()
	boundary_wall_material.albedo_color = Color(0.2, 0.2, 0.3)
	boundary_wall_material.roughness = 0.8
	boundary_wall_material.metallic = 0.1
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.6, 0.5, 0.4)
	floor_material.roughness = 0.7
	weapon_room_floor_material = StandardMaterial3D.new()
	weapon_room_floor_material.albedo_color = Color(0.8, 0.7, 0.3)
	weapon_room_floor_material.metallic = 0.3
	weapon_room_floor_material.roughness = 0.4

func _find_references():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	enemy_spawner = get_node_or_null("../EnemySpawner")
	if not enemy_spawner:
		var spawners = get_tree().get_nodes_in_group("spawner")
		if spawners.size() > 0:
			enemy_spawner = spawners[0]
	if enemy_spawner and enemy_spawner.has_signal("wave_completed"):
		if not enemy_spawner.wave_completed.is_connected(_on_wave_completed):
			enemy_spawner.wave_completed.connect(_on_wave_completed)

func _create_simple_corridor_protected(room_a: Rect2, room_b: Rect2):
	var start = room_a.get_center()
	var end = room_b.get_center()
	@warning_ignore("integer_division")
	var half_width = int(corridor_width / 2)
	var corridor_bounds = Rect2()
	var corridor_path = []
	var h_start = int(min(start.x, end.x))
	var h_end = int(max(start.x, end.x))
	for x in range(h_start, h_end + 1):
		for w in range(-half_width, half_width + 1):
			var y = int(start.y + w)
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR
				corridor_path.append(Vector2(x, y))
	var v_start = int(min(start.y, end.y))
	var v_end = int(max(start.y, end.y))
	for y in range(v_start, v_end + 1):
		for w in range(-half_width, half_width + 1):
			var x = int(end.x + w)
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR
				corridor_path.append(Vector2(x, y))
	corridor_bounds = Rect2(
		Vector2(min(h_start, int(end.x)) - half_width, min(v_start, int(start.y)) - half_width),
		Vector2(max(h_end, int(end.x)) - min(h_start, int(end.x)) + corridor_width, 
				max(v_end, int(start.y)) - min(v_start, int(start.y)) + corridor_width)
	)
	corridors.append(corridor_bounds)
	corridor_connections.append({
		"start_room": room_a,
		"end_room": room_b,
		"corridor_rect": corridor_bounds,
		"corridor_path": corridor_path
	})

func spawn_torch_at_position(pos: Vector3):
	var torch_scene = preload("res://Scenes/EnhancedTorch.tscn")
	var torch = torch_scene.instantiate()
	add_child(torch)
	torch.global_position = pos
	generated_objects.append(torch)

# --- TORCH SPAWNING: DUNGEON STYLE ---

func _spawn_torches_in_corridor(corridor_connection: Dictionary):
	# Place torches at regular intervals on corridor walls, alternating sides
	var path = corridor_connection.corridor_path
	if path.size() < 2:
		return
	var interval = int(torch_spacing_in_corridors)
	if interval < 2:
		interval = 2
	var side = 1
	var placed_positions = {}
	for i in range(0, path.size(), interval):
		var pos = path[i]
		# Find wall tile adjacent to corridor tile
		var wall_pos = _find_adjacent_wall(pos, side)
		if wall_pos != null and not placed_positions.has(wall_pos):
			_spawn_torch_on_wall(wall_pos)
			placed_positions[wall_pos] = true
			side *= -1  # Alternate sides

func _find_adjacent_wall(pos: Vector2, side: int) -> Vector2:
	# Check 4 directions, prefer left/right for horizontal, up/down for vertical
	var dirs = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	for dir in dirs:
		var check = pos + dir * side
		var x = int(check.x)
		var y = int(check.y)
		if x >= 0 and x < map_size.x and y >= 0 and y < map_size.y:
			if terrain_grid[x][y] == TileType.WALL:
				return Vector2(x, y)
	return Vector2()

func _spawn_torch_on_wall(wall_grid_pos: Vector2):
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var world_pos = Vector3(
		(wall_grid_pos.x - half_map_x) * 2.0,
		torch_height_offset,
		(wall_grid_pos.y - half_map_y) * 2.0
	)
	# Offset torch away from wall into room/corridor
	var offset_amount = 1.4  # Increased offset for more pronounced placement
	# Determine wall normal by checking adjacent floor/corridor tile
	var normal = Vector3.ZERO
	var dirs = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
	for dir in dirs:
		var x = int(wall_grid_pos.x + dir.x)
		var y = int(wall_grid_pos.y + dir.y)
		if x >= 0 and x < map_size.x and y >= 0 and y < map_size.y:
			if terrain_grid[x][y] == TileType.FLOOR or terrain_grid[x][y] == TileType.CORRIDOR:
				normal = Vector3(dir.x, 0, dir.y)
				break
	if normal != Vector3.ZERO:
		world_pos += normal * offset_amount
	spawn_torch_at_position(world_pos)

func _spawn_torches_in_room(room: Rect2):
	# Place torches near entrances/exits and at intervals along the room's walls
	var wall_points = []
	var interval = max(2, int(room.size.x / 2))
	# Top and bottom walls
	for x in range(int(room.position.x), int(room.position.x + room.size.x), interval):
		wall_points.append(Vector2(x, room.position.y))
		wall_points.append(Vector2(x, room.position.y + room.size.y - 1))
	# Left and right walls
	for y in range(int(room.position.y), int(room.position.y + room.size.y), interval):
		wall_points.append(Vector2(room.position.x, y))
		wall_points.append(Vector2(room.position.x + room.size.x - 1, y))
	# Place torches only if wall is present
	var placed = {}
	for pt in wall_points:
		var x = int(pt.x)
		var y = int(pt.y)
		if x >= 0 and x < map_size.x and y >= 0 and y < map_size.y:
			if terrain_grid[x][y] == TileType.WALL and not placed.has(pt):
				_spawn_torch_on_wall(pt)
				placed[pt] = true

func generate_starting_room():
	_clear_everything()
	_fill_with_walls()
	_mark_boundary_walls()
	var safe_area_start = boundary_thickness + safe_zone_margin
	var safe_area_size = map_size - Vector2(safe_area_start * 2, safe_area_start * 2)
	var room_pos = Vector2(
		safe_area_start + (safe_area_size.x - base_room_size.x) / 2,
		safe_area_start + (safe_area_size.y - base_room_size.y) / 2
	)
	var starting_room = Rect2(room_pos, base_room_size)
	_carve_room_shape(starting_room, RoomShape.SQUARE)
	rooms.append(starting_room)
	room_shapes.append(RoomShape.SQUARE)
	room_types.append(RoomType.STARTING)
	current_room_count = 1
	_generate_all_walls_with_boundary_protection()
	_spawn_destructible_objects_in_room(starting_room)
	_spawn_mushrooms_in_room(starting_room)
	_spawn_torches_in_room(starting_room)

	# Ensure at least one torch in starter room
	var torch_found := false
	var torch_script = preload("res://dot gds/enhanced_torch.gd")
	for obj in generated_objects:
		if obj.get_script() == torch_script:
			torch_found = true
			break
	if not torch_found:
		# Spawn a torch at the center of the room
		var center_torch = starting_room.position + starting_room.size / 2
		var half_map_x_torch = map_size.x / 2
		var half_map_y_torch = map_size.y / 2
		var center_pos = Vector3((center_torch.x - half_map_x_torch) * 2.0, torch_height_offset, (center_torch.y - half_map_y_torch) * 2.0)
		spawn_torch_at_position(center_pos)

	# --- Spawn recruiter NPC in the center of the first room (with offset) ---
	var recruiter_scene = preload("res://Scenes/recruiter_npc.tscn")
	var recruiter = recruiter_scene.instantiate()
	add_child(recruiter)
	var center = starting_room.position + starting_room.size / 2
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var offset = Vector2(2, 0) # Offset by +2 units on X axis
	var spawn_pos = center + offset
	recruiter.global_position = Vector3((spawn_pos.x - half_map_x) * 2.0, 1.2, (spawn_pos.y - half_map_y) * 2.0)

	# --- Spawn 4 weapons in the starter room, each with an altar below ---
	var center_vec = Vector3((center.x - half_map_x) * 2.0, DEFAULT_OBJECT_HEIGHT, (center.y - half_map_y) * 2.0)
	var weapon_offsets = [
		Vector3(2.5, 0, 0),
		Vector3(-1.5, 0, 2.2),
		Vector3(-1.5, 0, -2.2),
		Vector3(0, 0, 2.8) # New weapon offset
	]
	for weapon_offset in weapon_offsets:
		var weapon_pos = center_vec + weapon_offset
		# Spawn altar under weapon
		if altar_scene:
			var altar = altar_scene.instantiate()
			add_child(altar)
			var altar_pos = weapon_pos
			altar_pos.y -= 0.6
			altar.global_position = altar_pos
			generated_objects.append(altar)
		_spawn_weapon_pickup(weapon_pos)

	# --- Spawn 2 cages in the starter room at random valid positions ---
	if preload("res://Scenes/recruiter_npc.tscn"):
		var cage_scene = preload("res://Scenes/recruiter_npc.tscn")
		var cages_spawned = 0
		var attempts = 0
		var max_attempts = 20
		while cages_spawned < 2 and attempts < max_attempts:
			attempts += 1
			var random_pos = Vector2(
				starting_room.position.x + randf() * starting_room.size.x,
				starting_room.position.y + randf() * starting_room.size.y
			)
			var grid_x = int(random_pos.x)
			var grid_y = int(random_pos.y)
			if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
				continue
			if terrain_grid[grid_x][grid_y] != TileType.FLOOR:
				continue
			var world_pos = Vector3(
				(random_pos.x - half_map_x) * 2.0,
				DEFAULT_OBJECT_HEIGHT,
				(random_pos.y - half_map_y) * 2.0
			)
			var too_close = false
			for obj in generated_objects:
				if obj and obj.global_position.distance_to(world_pos) < 2.0:
					too_close = true
					break
			if too_close:
				continue
			_spawn_object(cage_scene, world_pos, "Cage")
			cages_spawned += 1

	if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
		var first_wave_room = create_connected_room()
		if first_wave_room != null:
			enemy_spawner.set_newest_spawning_room(first_wave_room)
			_spawn_torches_in_room(first_wave_room)
			if corridor_connections.size() > 0:
				var latest_corridor = corridor_connections[corridor_connections.size() - 1]
				_spawn_torches_in_corridor(latest_corridor)

func create_connected_room():
	if rooms.is_empty():
		return null
	var last_room = rooms[rooms.size() - 1]
	var new_shape = _choose_room_shape()
	var room_size = _get_size_for_shape(new_shape)
	var new_room = _find_new_room_position(last_room, room_size)
	if new_room == Rect2():
		return null
	_carve_room_shape(new_room, new_shape)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(new_shape)
	room_types.append(RoomType.NORMAL)
	current_room_count += 1
	new_room_generated.emit(new_room)
	_spawn_destructible_objects_in_room(new_room)
	_spawn_mushrooms_in_room(new_room)
	_spawn_torches_in_room(new_room)
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)
	return new_room

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
	corridor_connections.clear()
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
	boundary_walls.clear()
	for x in range(map_size.x):
		for y in range(map_size.y):
			if (x < boundary_thickness or x >= map_size.x - boundary_thickness or 
				y < boundary_thickness or y >= map_size.y - boundary_thickness):
				var grid_key = str(x) + "," + str(y)
				boundary_walls[grid_key] = true

func _generate_all_walls_with_boundary_protection():
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
	if x < 0 or x >= map_size.x or y < 0 or y >= map_size.y:
		return false
	var grid_key = str(x) + "," + str(y)
	if boundary_walls.has(grid_key):
		return false
	return true

func _is_valid_torch_position(grid_pos: Vector2, room: Rect2) -> bool:
	var grid_x = int(grid_pos.x)
	var grid_y = int(grid_pos.y)
	if grid_x < 0 or grid_x >= terrain_grid.size():
		return false
	if grid_y < 0 or grid_y >= terrain_grid[grid_x].size():
		return false
	if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
		return false
	if not room.has_point(Vector2(grid_x, grid_y)):
		return false
	return terrain_grid[grid_x][grid_y] == TileType.FLOOR

func _carve_room_shape(room: Rect2, shape: RoomShape):
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
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _choose_room_shape() -> RoomShape:
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

func _find_new_room_position(last_room: Rect2, room_size: Vector2) -> Rect2:
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
	return Rect2()

func _is_room_position_safe(room: Rect2, min_pos: float, max_pos_x: float, max_pos_y: float) -> bool:
	if (room.position.x < min_pos or room.position.y < min_pos or
		room.position.x > max_pos_x or room.position.y > max_pos_y):
		return false
	for existing_room in rooms:
		if room.intersects(existing_room):
			return false
	return true

func _move_player_to_room(room: Rect2):
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

func _spawn_object(scene: PackedScene, world_pos: Vector3, object_name: String = "") -> Node3D:
	if not scene:
		push_warning("Missing scene for " + object_name)
		return null
	var instance = scene.instantiate()
	add_child(instance)
	instance.global_position = world_pos
	if object_name:
		instance.name = object_name
	generated_objects.append(instance)
	return instance

func _spawn_destructible_objects_in_room(room: Rect2):
	# Ensure crate and barrel scenes are always loaded
	if not crate_scene and ResourceLoader.exists("res://Scenes/DestructibleCrate.tscn"):
		crate_scene = load("res://Scenes/DestructibleCrate.tscn")
	if not barrel_scene and ResourceLoader.exists("res://Scenes/destructible_barrel.tscn"):
		barrel_scene = load("res://Scenes/destructible_barrel.tscn")
	var objects_to_spawn = randi_range(2, 4)
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var attempts = 0
	var max_attempts = 20
	var spawned = 0
	while spawned < objects_to_spawn and attempts < max_attempts:
		attempts += 1
		var object_scene = crate_scene if randf() < 0.6 else barrel_scene
		if not object_scene:
			push_warning("Missing crate or barrel scene")
			continue
		var random_pos = Vector2(
			room.position.x + randf() * room.size.x,
			room.position.y + randf() * room.size.y
		)
		var grid_x = int(random_pos.x)
		var grid_y = int(random_pos.y)
		if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
			continue
		if terrain_grid[grid_x][grid_y] != TileType.FLOOR:
			continue
		# Avoid overlapping with other objects
		var world_pos = Vector3(
			(random_pos.x - half_map_x) * 2.0,
			DEFAULT_OBJECT_HEIGHT, # Reverted to DEFAULT_OBJECT_HEIGHT for crate/barrel spawn height
			(random_pos.y - half_map_y) * 2.0
		)
		var too_close = false
		for obj in generated_objects:
			if obj and obj.global_position.distance_to(world_pos) < 2.0:
				too_close = true
				break
		if too_close:
			continue
		_spawn_object(object_scene, world_pos)
		spawned += 1

func _spawn_mushrooms_in_room(room: Rect2):
	if not mushroom_scene:
		return
	var mushrooms_to_spawn = randi_range(2, 4)
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	for i in range(mushrooms_to_spawn):
		var mushroom_instance = mushroom_scene.instantiate()
		add_child(mushroom_instance)
		var random_pos = Vector2(
			room.position.x + randf() * room.size.x,
			room.position.y + randf() * room.size.y
		)
		var world_pos = Vector3(
			(random_pos.x - half_map_x) * 2.0,
			DEFAULT_OBJECT_HEIGHT,
			(random_pos.y - half_map_y) * 2.0
		)
		mushroom_instance.global_position = world_pos
		generated_objects.append(mushroom_instance)

func _on_wave_completed(wave_number: int):
	if randf() < 0.5:
		var weapon_room = _create_weapon_room()
		if weapon_room != Rect2():
			if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
				enemy_spawner.set_newest_spawning_room(weapon_room)
		else:
			_create_normal_room_after_wave(wave_number)
	else:
		_create_normal_room_after_wave(wave_number)

func _create_normal_room_after_wave(_wave_number: int):
	var new_room = create_connected_room()
	if new_room != null:
		if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
			enemy_spawner.set_newest_spawning_room(new_room)

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
	if rooms.is_empty():
		return Rect2()
	var last_room = rooms[rooms.size() - 1]
	var new_room = _find_new_room_position(last_room, weapon_room_size)
	if new_room == Rect2():
		return Rect2()
	_carve_room_shape(new_room, RoomShape.SQUARE)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(RoomShape.SQUARE)
	room_types.append(RoomType.WEAPON)
	current_room_count += 1
	_spawn_weapon_room_content(new_room)
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)
	return new_room

func _spawn_weapon_room_content(room: Rect2):
	var room_center = room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var weapon_world_pos = Vector3(
		(room_center.x - half_map_x) * 2.0,
		DEFAULT_OBJECT_HEIGHT,
		(room_center.y - half_map_y) * 2.0
	)
	# Spawn altar/slab under weapon, slightly lower for visibility
	if altar_scene:
		var altar = altar_scene.instantiate()
		add_child(altar)
		var altar_pos = weapon_world_pos
		altar_pos.y -= 0.6
		altar.global_position = altar_pos
		generated_objects.append(altar)
	_spawn_weapon_pickup(weapon_world_pos)
	# Spawn torches in weapon room just like other rooms
	_spawn_torches_in_room(room)

func _spawn_weapon_pickup(spawn_pos: Vector3):
	if not weapon_pickup_scene:
		return
	var weapon_pickup = weapon_pickup_scene.instantiate()
	add_child(weapon_pickup)
	weapon_pickup.global_position = spawn_pos
	generated_objects.append(weapon_pickup)

func _spawn_torch_circle_around_weapon(center_pos: Vector3, room: Rect2):
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

func _world_to_grid_position(world_pos: Vector3) -> Vector2:
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	return Vector2(
		round(world_pos.x / 2.0 + half_map_x),
		round(world_pos.z / 2.0 + half_map_y)
	)

func get_rooms(include_weapon_rooms := true) -> Array:
	var result = []
	for i in range(rooms.size()):
		if include_weapon_rooms or room_types[i] == RoomType.NORMAL:
			result.append(rooms[i])
	return result
