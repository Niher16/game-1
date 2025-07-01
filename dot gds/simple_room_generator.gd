# simple_room_generator.gd - ENHANCED: Proper dungeon with guaranteed spawning and atmosphere
extends Node3D

signal new_room_generated(room_rect: Rect2)

@export var map_size = Vector2(60, 60)
@export var base_room_size = Vector2(6, 6)
@export var corridor_width = 3
@export var wall_height = 3.0
@export var auto_generate_on_start = true
@export var max_rooms := 10

@export_group("Enhanced Room Settings")
@export var weapon_room_chance: float = 0.3
@export var recruiter_room_chance: float = 0.2
@export var weapon_room_size = Vector2(8, 8)

@export_group("Lighting System - Rooms get different lighting types")
@export var mushroom_only_room_chance: float = 0.35
@export var torch_only_room_chance: float = 0.35
@export var mixed_lighting_room_chance: float = 0.30

@export_group("Object Spawning - Guaranteed in all rooms")
@export var crates_per_room_min: int = 2
@export var crates_per_room_max: int = 5
@export var barrels_per_room_min: int = 1
@export var barrels_per_room_max: int = 3
@export var mushrooms_per_room_min: int = 2
@export var mushrooms_per_room_max: int = 4
@export var torches_per_room_min: int = 3
@export var torches_per_room_max: int = 6

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
enum RoomType { NORMAL, WEAPON, STARTING, RECRUITER }
enum LightingType { MUSHROOMS_ONLY, TORCHES_ONLY, MIXED }

var terrain_grid: Array = []
var rooms: Array = []
var room_shapes: Array = []
var room_types: Array = []
var room_lighting_types: Array = []
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
@export var recruiter_npc_scene: PackedScene

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
	_load_default_scenes()
	
	if auto_generate_on_start:
		_pending_generate_starting_room = true
		_try_generate_starting_room_when_spawner_ready()

func _load_default_scenes():
	# Set default scenes if not assigned in the editor
	if not crate_scene and ResourceLoader.exists("res://Scenes/DestructibleCrate.tscn"):
		crate_scene = load("res://Scenes/DestructibleCrate.tscn")
	if not barrel_scene and ResourceLoader.exists("res://Scenes/destructible_barrel.tscn"):
		barrel_scene = load("res://Scenes/destructible_barrel.tscn")
	if not mushroom_scene and ResourceLoader.exists("res://Scenes/enhanced_mushrooms.tscn"):
		mushroom_scene = load("res://Scenes/enhanced_mushrooms.tscn")
	if not recruiter_npc_scene and ResourceLoader.exists("res://Scenes/recruiter_npc.tscn"):
		recruiter_npc_scene = load("res://Scenes/recruiter_npc.tscn")
	if ResourceLoader.exists("res://Scenes/weapon_pickup.tscn"):
		weapon_pickup_scene = load("res://Scenes/weapon_pickup.tscn")

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

# ===== ENHANCED ROOM GENERATION =====
func _determine_room_type() -> RoomType:
	# Don't spawn special rooms too early
	if current_room_count < 2:
		return RoomType.NORMAL
	
	var rand_val := randf()
	if rand_val < weapon_room_chance:
		return RoomType.WEAPON
	elif rand_val < weapon_room_chance + recruiter_room_chance:
		return RoomType.RECRUITER
	else:
		return RoomType.NORMAL

func _determine_lighting_type() -> LightingType:
	var rand_val := randf()
	if rand_val < mushroom_only_room_chance:
		return LightingType.MUSHROOMS_ONLY
	elif rand_val < mushroom_only_room_chance + torch_only_room_chance:
		return LightingType.TORCHES_ONLY
	else:
		return LightingType.MIXED

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
	room_lighting_types.append(LightingType.MIXED)
	current_room_count = 1
	_generate_all_walls_with_boundary_protection()

	# ENHANCED: Spawn content for starting room
	_spawn_enhanced_room_content(starting_room, RoomType.STARTING, LightingType.MIXED)

	# Always spawn lights in the starting room
	_spawn_lighting_for_room(starting_room, LightingType.MIXED)

	# Explicitly spawn a torch at the center of the starting room
	var center = starting_room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var torch_pos = Vector3((center.x - half_map_x) * 2.0, torch_height_offset, (center.y - half_map_y) * 2.0)
	spawn_torch_at_position(torch_pos)

	# Spawn starting room recruiter and weapons
	_spawn_starting_room_special_content(starting_room)

func _spawn_starting_room_special_content(room: Rect2):
	var center = room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	
	# Spawn 3 recruiter NPCs with different offsets
	var recruiter_offsets = [Vector2(2, 0), Vector2(-2, 1.5), Vector2(0, -2)]
	if recruiter_npc_scene:
		for i in recruiter_offsets.size():
			var recruiter = recruiter_npc_scene.instantiate()
			add_child(recruiter)
			var offset = recruiter_offsets[i]
			var spawn_pos = center + offset
			recruiter.global_position = Vector3((spawn_pos.x - half_map_x) * 2.0, 1.2, (spawn_pos.y - half_map_y) * 2.0)
			recruiter.name = "Recruiter" + str(i)
			generated_objects.append(recruiter)
	
	# Spawn 4 weapons with altars
	var center_vec = Vector3((center.x - half_map_x) * 2.0, DEFAULT_OBJECT_HEIGHT, (center.y - half_map_y) * 2.0)
	var weapon_offsets = [
		Vector3(2.5, 0, 0),
		Vector3(-1.5, 0, 2.2),
		Vector3(-1.5, 0, -2.2),
		Vector3(0, 0, 2.8)
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

func create_connected_room():
	if rooms.is_empty():
		return null
	
	var last_room = rooms[rooms.size() - 1]
	var room_type = _determine_room_type()
	var lighting_type = _determine_lighting_type()
	var new_shape = _choose_room_shape()
	var room_size = _get_size_for_room_type(room_type)
	var new_room = _find_new_room_position(last_room, room_size)
	
	if new_room == Rect2():
		return null
	
	_carve_room_shape(new_room, new_shape)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(new_shape)
	room_types.append(room_type)
	room_lighting_types.append(lighting_type)
	current_room_count += 1
	new_room_generated.emit(new_room)
	
	# ENHANCED: Spawn content based on room type and lighting
	_spawn_enhanced_room_content(new_room, room_type, lighting_type)
	
	# Spawn corridor torches
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)
	
	return new_room

func _get_size_for_room_type(room_type: RoomType) -> Vector2:
	match room_type:
		RoomType.WEAPON:
			return weapon_room_size
		RoomType.RECRUITER:
			return base_room_size * 1.2  # Slightly larger for recruiter
		_:
			return base_room_size

# ===== ENHANCED CONTENT SPAWNING =====
func _spawn_enhanced_room_content(room: Rect2, room_type: RoomType, lighting_type: LightingType):
	print("Spawning content for room type: ", room_type, " with lighting: ", lighting_type)
	
	# GUARANTEED: Always spawn barrels and crates in ALL rooms
	_spawn_guaranteed_destructible_objects_in_room(room)
	
	# ENHANCED: Spawn lighting based on room lighting type
	_spawn_lighting_for_room(room, lighting_type)
	
	# ENHANCED: Spawn special content based on room type
	match room_type:
		RoomType.WEAPON:
			_spawn_weapon_room_special_content(room)
		RoomType.RECRUITER:
			_spawn_recruiter_room_special_content(room)

func _spawn_guaranteed_destructible_objects_in_room(room: Rect2):
	# GUARANTEED crate spawning
	var crate_count = randi_range(crates_per_room_min, crates_per_room_max)
	_spawn_objects_of_type_in_room(room, crate_scene, crate_count, "Crate")
	
	# GUARANTEED barrel spawning
	var barrel_count = randi_range(barrels_per_room_min, barrels_per_room_max)
	_spawn_objects_of_type_in_room(room, barrel_scene, barrel_count, "Barrel")

func _spawn_lighting_for_room(room: Rect2, lighting_type: LightingType):
	match lighting_type:
		LightingType.MUSHROOMS_ONLY:
			print("Spawning mushrooms only in room")
			_spawn_mushrooms_in_room_enhanced(room)
		LightingType.TORCHES_ONLY:
			print("Spawning torches only in room")
			_spawn_torches_in_room_enhanced(room)
		LightingType.MIXED:
			print("Spawning mixed lighting in room")
			_spawn_mushrooms_in_room_enhanced(room)
			_spawn_torches_in_room_enhanced(room)

func _spawn_mushrooms_in_room_enhanced(room: Rect2):
	if not mushroom_scene:
		print("Warning: No mushroom scene available")
		return
	
	var mushroom_count = randi_range(mushrooms_per_room_min, mushrooms_per_room_max)
	print("Spawning ", mushroom_count, " mushrooms")
	_spawn_objects_of_type_in_room(room, mushroom_scene, mushroom_count, "Mushroom")

func _spawn_torches_in_room_enhanced(room: Rect2):
	print("Spawning torches on walls in room")
	var torch_count = randi_range(torches_per_room_min, torches_per_room_max)
	var wall_points = _get_wall_positions_for_room(room)
	
	if wall_points.is_empty():
		print("No valid wall positions found for torches")
		return
	
	var spawned = 0
	while spawned < torch_count and spawned < wall_points.size():
		var wall_pos = wall_points[spawned % wall_points.size()]
		_spawn_torch_on_wall(wall_pos)
		spawned += 1
	print("Spawned ", spawned, " torches on walls")

func _get_wall_positions_for_room(room: Rect2) -> Array:
	var wall_points = []
	var interval = max(2, int(room.size.x / 3))
	
	# Top and bottom walls
	for x in range(int(room.position.x), int(room.position.x + room.size.x), interval):
		wall_points.append(Vector2(x, room.position.y))
		wall_points.append(Vector2(x, room.position.y + room.size.y - 1))
	
	# Left and right walls
	for y in range(int(room.position.y), int(room.position.y + room.size.y), interval):
		wall_points.append(Vector2(room.position.x, y))
		wall_points.append(Vector2(room.position.x + room.size.x - 1, y))
	
	# Filter to actual walls
	var valid_walls = []
	for pt in wall_points:
		var x = int(pt.x)
		var y = int(pt.y)
		if x >= 0 and x < map_size.x and y >= 0 and y < map_size.y:
			if terrain_grid[x][y] == TileType.WALL:
				valid_walls.append(pt)
	
	return valid_walls

func _spawn_objects_of_type_in_room(room: Rect2, scene: PackedScene, count: int, object_name: String):
	if not scene:
		print("Warning: Missing scene for ", object_name)
		return
	
	var spawned = 0
	var attempts = 0
	var max_attempts = count * 10
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	
	while spawned < count and attempts < max_attempts:
		attempts += 1
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
		
		var world_pos = Vector3(
			(random_pos.x - half_map_x) * 2.0,
			DEFAULT_OBJECT_HEIGHT,
			(random_pos.y - half_map_y) * 2.0
		)
		
		# Check if too close to other objects
		var too_close = false
		for obj in generated_objects:
			if obj and obj.global_position.distance_to(world_pos) < 2.0:
				too_close = true
				break
		if too_close:
			continue
		
		var instance = scene.instantiate()
		add_child(instance)
		instance.global_position = world_pos
		instance.name = object_name + str(spawned)
		generated_objects.append(instance)
		spawned += 1
	
	print("Successfully spawned ", spawned, " ", object_name, "s in room")

func _spawn_weapon_room_special_content(room: Rect2):
	var room_center = room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var weapon_world_pos = Vector3(
		(room_center.x - half_map_x) * 2.0,
		DEFAULT_OBJECT_HEIGHT,
		(room_center.y - half_map_y) * 2.0
	)
	
	# Spawn altar under weapon
	if altar_scene:
		var altar = altar_scene.instantiate()
		add_child(altar)
		var altar_pos = weapon_world_pos
		altar_pos.y -= 0.6
		altar.global_position = altar_pos
		generated_objects.append(altar)
	
	_spawn_weapon_pickup(weapon_world_pos)
	print("Spawned weapon room content with altar and weapon")

func _spawn_recruiter_room_special_content(room: Rect2):
	if not recruiter_npc_scene:
		print("Warning: No recruiter NPC scene available")
		return
	
	var room_center = room.get_center()
	var half_map_x = map_size.x / 2
	var half_map_y = map_size.y / 2
	var recruiter_pos = Vector3(
		(room_center.x - half_map_x) * 2.0,
		1.2,
		(room_center.y - half_map_y) * 2.0
	)
	
	var recruiter = recruiter_npc_scene.instantiate()
	add_child(recruiter)
	recruiter.global_position = recruiter_pos
	recruiter.name = "RoomRecruiter"
	generated_objects.append(recruiter)
	print("Spawned recruiter in dedicated recruiter room")

# ===== EXISTING FUNCTIONS (PRESERVED) =====
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

func _spawn_torches_in_corridor(corridor_connection: Dictionary):
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
		var wall_pos = _find_adjacent_wall(pos, side)
		if wall_pos != null and not placed_positions.has(wall_pos):
			_spawn_torch_on_wall(wall_pos)
			placed_positions[wall_pos] = true
			side *= -1

func _find_adjacent_wall(pos: Vector2, side: int) -> Vector2:
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
	var offset_amount = 1.4
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

func _spawn_weapon_pickup(spawn_pos: Vector3):
	if not weapon_pickup_scene:
		return
	var weapon_pickup = weapon_pickup_scene.instantiate()
	add_child(weapon_pickup)
	weapon_pickup.global_position = spawn_pos
	generated_objects.append(weapon_pickup)

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
	if new_room and enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
		enemy_spawner.set_newest_spawning_room(new_room)

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
	room_lighting_types.append(LightingType.TORCHES_ONLY)  # Weapon rooms prefer torches
	current_room_count += 1
	
	# Enhanced weapon room content
	_spawn_enhanced_room_content(new_room, RoomType.WEAPON, LightingType.TORCHES_ONLY)
	
	if corridor_connections.size() > 0:
		var latest_corridor = corridor_connections[corridor_connections.size() - 1]
		_spawn_torches_in_corridor(latest_corridor)
	return new_room

# ===== REST OF EXISTING FUNCTIONS (UNCHANGED) =====
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
	room_lighting_types.clear()
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
	wall.global_position = Vector3((grid_x - half_map_x) * 2.0, wall_height / 2, (grid_y - half_map_y) * 2.0)
	return wall

func _choose_room_shape() -> RoomShape:
	var shapes = [RoomShape.SQUARE, RoomShape.RECTANGLE, RoomShape.L_SHAPE, RoomShape.SMALL_SQUARE]
	return shapes[randi() % shapes.size()]

func _find_new_room_position(last_room: Rect2, room_size: Vector2) -> Rect2:
	var attempts = 50
	var min_distance = 3
	for attempt in attempts:
		var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var distance = randf_range(5, 12)
		var offset = direction * distance
		var new_pos = last_room.get_center() + offset - room_size / 2
		var new_room = Rect2(new_pos, room_size)
		if _is_room_position_valid(new_room, min_distance):
			return new_room
	return Rect2()

func _is_room_position_valid(new_room: Rect2, min_distance: float) -> bool:
	var safe_area_start = boundary_thickness + safe_zone_margin
	var safe_area_end = map_size - Vector2(safe_area_start, safe_area_start)
	if new_room.position.x < safe_area_start or new_room.position.y < safe_area_start:
		return false
	if new_room.end.x > safe_area_end.x or new_room.end.y > safe_area_end.y:
		return false
	for room in rooms:
		var center_a = new_room.position + new_room.size / 2
		var center_b = room.position + room.size / 2
		if center_a.distance_to(center_b) < min_distance:
			return false
	return true

func _carve_room_shape(room: Rect2, shape: RoomShape):
	match shape:
		RoomShape.SQUARE, RoomShape.RECTANGLE, RoomShape.SMALL_SQUARE:
			_carve_rectangle(room)
		RoomShape.L_SHAPE:
			_carve_l_shape(room)
		RoomShape.T_SHAPE:
			_carve_t_shape(room)
		_:
			_carve_rectangle(room)

func _carve_rectangle(room: Rect2):
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_l_shape(room: Rect2):
	var split_x = int(room.position.x + room.size.x * 0.6)
	var split_y = int(room.position.y + room.size.y * 0.4)
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), split_y):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	for x in range(int(room.position.x), split_x):
		for y in range(split_y, int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_t_shape(room: Rect2):
	var center_x = int(room.get_center().x)
	var third_width = int(room.size.x / 3)
	var half_height = int(room.size.y / 2)
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y + room.size.y - half_height), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	for x in range(center_x - third_width, center_x + third_width):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _is_valid_carve_position(x: int, y: int) -> bool:
	if x < 0 or x >= map_size.x or y < 0 or y >= map_size.y:
		return false
	var grid_key = str(x) + "," + str(y)
	return not boundary_walls.has(grid_key)

func _remove_walls_by_grid_lookup():
	for x in range(map_size.x):
		for y in range(map_size.y):
			if terrain_grid[x][y] != TileType.WALL:
				var grid_key = str(x) + "," + str(y)
				if wall_lookup.has(grid_key):
					var wall = wall_lookup[grid_key]
					if is_instance_valid(wall):
						wall.queue_free()
					wall_lookup.erase(grid_key)

func get_rooms(include_weapon_rooms := true) -> Array:
	var result = []
	for i in range(rooms.size()):
		if include_weapon_rooms or room_types[i] == RoomType.NORMAL:
			result.append(rooms[i])
	return result
