# simple_room_generator.gd - ENHANCED: Protected boundary walls that can NEVER be deleted!
extends Node3D

signal terrain_generated
signal new_room_generated(room_rect: Rect2)

@export var map_size = Vector2(60, 60)
@export var base_room_size = Vector2(6, 6)
@export var corridor_width = 3
@export var wall_height = 3.0
@export var auto_generate_on_start = true
@export var max_rooms := 10
@export var weapon_spawn_chance = 0.3  # 30% chance per room

# NEW: Boundary protection settings
@export var boundary_thickness = 2  # How many tiles thick the protected boundary is
@export var safe_zone_margin = 4    # Extra margin inside the boundary for room placement

# Recruiter spawn configuration
@export var recruiter_base_chance: float = 0.25  # 25% base chance
@export var recruiter_chance_increase: float = 0.1  # Increases per room
@export var recruiter_max_chance: float = 0.8  # Max 80% chance

enum TileType { WALL, FLOOR, CORRIDOR }

# NEW: Room shape types
enum RoomShape { 
	SQUARE, RECTANGLE, L_SHAPE, T_SHAPE, PLUS_SHAPE, U_SHAPE, LONG_HALL, SMALL_SQUARE
}

var terrain_grid: Array = []
var rooms: Array = []
var weapon_pickup_scene: PackedScene
var room_shapes: Array = []
var corridors: Array = []
var generated_objects: Array = []
var current_room_count = 0

# Wall tracking with boundary protection
var wall_lookup: Dictionary = {}
var boundary_walls: Dictionary = {}  # NEW: Track which walls are permanent boundary walls

# Materials
var wall_material: StandardMaterial3D
var boundary_wall_material: StandardMaterial3D  # NEW: Special material for boundary walls
var floor_material: StandardMaterial3D

# References
var enemy_spawner: Node3D
var player: Node3D

# Change preload to regular variables
@export var crate_scene: PackedScene
@export var barrel_scene: PackedScene

var torch_to_wall_map = {}  # Maps torch instances to their wall grid keys

func _ready():
	add_to_group("terrain")
	print("🛡️ Protected Boundary Room Generator: Starting with INDESTRUCTIBLE perimeter! 🛡️")
	
	_create_materials()
	_find_references()
	# _setup_lighting()  # DISABLED - conflicting with main_scene_setup lighting
	print("🔆 Lighting handled by main_scene_setup.gd")
	
	# Treasure chests removed - using crates and barrels for loot instead
	print("🗑️ Treasure chests disabled - cleaner dungeon generation")

	# Add loading for destructible objects
	if ResourceLoader.exists("res://Scenes/DestructibleCrate.tscn"):
		crate_scene = load("res://Scenes/DestructibleCrate.tscn")
		print("✅ Loaded destructible crate scene")
	else:
		print("⚠️ Destructible crate scene not found")

	if ResourceLoader.exists("res://Scenes/destructible_barrel.tscn"):
		barrel_scene = load("res://Scenes/destructible_barrel.tscn")
		print("✅ Loaded destructible barrel scene")
	else:
		print("⚠️ Destructible barrel scene not found")

	# Load weapon pickup scene
	if ResourceLoader.exists("res://Scenes/weapon_pickup.tscn"):
		weapon_pickup_scene = load("res://Scenes/weapon_pickup.tscn")
		print("✅ Loaded weapon pickup scene")
	else:
		print("⚠️ Weapon pickup scene not found")
	
	# Debug: Check WeaponPool autoload
	if typeof(WeaponPool) == TYPE_NIL:
		print("❌ WeaponPool autoload is NOT available!")
	else:
		print("✅ WeaponPool autoload is available")
	
	if auto_generate_on_start:
		call_deferred("generate_starting_room")

func _create_materials():
	# Regular wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.4, 0.4, 0.45)
	wall_material.roughness = 0.9

	# NEW: Special boundary wall material (darker, more imposing)
	boundary_wall_material = StandardMaterial3D.new()
	boundary_wall_material.albedo_color = Color(0.2, 0.2, 0.25)  # Darker
	boundary_wall_material.roughness = 0.95
	boundary_wall_material.metallic = 0.3  # Slightly metallic
	boundary_wall_material.emission_enabled = true
	boundary_wall_material.emission = Color(0.1, 0.1, 0.15) * 0.3  # Slight glow

	# Floor material
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.8, 0.8, 0.85)
	floor_material.roughness = 0.8

func _find_references():
	player = get_tree().get_first_node_in_group("player")
	enemy_spawner = get_tree().get_first_node_in_group("spawner")
	
	if enemy_spawner and enemy_spawner.has_signal("wave_completed"):
		enemy_spawner.wave_completed.connect(_on_wave_completed)
		print("Protected Boundary Generator: ✅ Connected to wave system")

func generate_starting_room():
	"""Generate the first room with protected boundaries"""
	print("🛡️ Creating starting room with PROTECTED BOUNDARY...")
	
	_clear_everything()
	_fill_with_walls()
	_mark_boundary_walls()  # NEW: Mark which walls are permanent boundaries
	
	# Create starting room in center (well within safe zone)
	var safe_area_start = boundary_thickness + safe_zone_margin
	var safe_area_size = map_size - Vector2(safe_area_start * 2, safe_area_start * 2)
	
	var room_pos = Vector2(
		safe_area_start + (safe_area_size.x - base_room_size.x) / 2,
		safe_area_start + (safe_area_size.y - base_room_size.y) / 2
	)
	var starting_room = Rect2(room_pos, base_room_size)
	
	print("🛡️ Starting room positioned safely at: ", starting_room)
	print("🛡️ Boundary zone: 0-", boundary_thickness, " and ", map_size.x - boundary_thickness, "-", map_size.x)
	
	# Carve out the room
	_carve_room_shape(starting_room, RoomShape.SQUARE)
	rooms.append(starting_room)
	room_shapes.append(RoomShape.SQUARE)
	current_room_count = 1
	
	# Generate walls (boundary walls will be marked as permanent)
	_generate_all_walls_with_boundary_protection()
	
	# Move player to room center
	_move_player_to_room(starting_room)
	
	# 🗑️ Treasure chests disabled - cleaner dungeon generation
	_spawn_destructible_objects_in_room(starting_room)  # NEW: Spawn destructibles

	# --- TORCH PLACEMENT LOGIC (FIXED) ---
	_spawn_torches_in_room(starting_room)
	# --- END TORCH PLACEMENT ---

	print("🛡️ Starting room created with PROTECTED BOUNDARIES!")
	terrain_generated.emit()


func _clear_everything():
	"""Clear all generated content"""
	for obj in generated_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	generated_objects.clear()
	wall_lookup.clear()
	boundary_walls.clear()  # NEW: Clear boundary tracking
	torch_to_wall_map.clear()

func _fill_with_walls():
	"""Fill entire map with walls"""
	terrain_grid.clear()
	for x in range(map_size.x):
		terrain_grid.append([])
		for y in range(map_size.y):
			terrain_grid[x].append(TileType.WALL)

func _mark_boundary_walls():
	"""NEW: Mark which grid positions are permanent boundary walls"""
	boundary_walls.clear()
	
	for x in range(map_size.x):
		for y in range(map_size.y):
			# Check if this position is in the boundary zone
			if _is_boundary_position(x, y):
				var grid_key = str(x) + "," + str(y)
				boundary_walls[grid_key] = true
	
	print("🛡️ Marked ", boundary_walls.size(), " boundary wall positions as PERMANENT")

func _is_boundary_position(x: int, y: int) -> bool:
	"""NEW: Check if a grid position is in the protected boundary zone"""
	return (x < boundary_thickness or 
			x >= map_size.x - boundary_thickness or 
			y < boundary_thickness or 
			y >= map_size.y - boundary_thickness)

func _generate_all_walls_with_boundary_protection():
	"""Generate wall objects with boundary protection"""
	var walls_created = 0
	var boundary_walls_created = 0
	wall_lookup.clear()
	var non_boundary_walls = []
	for x in range(map_size.x):
		for y in range(map_size.y):
			if terrain_grid[x][y] == TileType.WALL:
				var wall = _create_wall_at(x, y)
				if wall:
					var grid_key = str(x) + "," + str(y)
					wall_lookup[grid_key] = wall
					walls_created += 1
					
					# Check if this is a boundary wall
					if boundary_walls.has(grid_key):
						boundary_walls_created += 1
					else:
						non_boundary_walls.append(wall)
	print("🛡️ Created ", walls_created, " total walls (", boundary_walls_created, " are PROTECTED boundary walls)")
	# Apply random damage to a random 20-40% of non-boundary walls
	var damage_count = int(non_boundary_walls.size() * randf_range(0.2, 0.4))
	var shuffled = non_boundary_walls.duplicate()
	shuffled.shuffle()
	for i in range(damage_count):
		_apply_random_wall_damage(shuffled[i])

func _apply_random_wall_damage(wall: StaticBody3D):
	# Applies random damage: reduce height, darken color, increase roughness, add slight emission
	if not wall or not wall.get_child_count():
		return
	var mesh = null
	for child in wall.get_children():
		if child is MeshInstance3D:
			mesh = child
			break
	if not mesh:
		return
	# Only apply to non-boundary walls
	if wall.get_meta("is_boundary"):
		return
	# Randomly reduce height by 10-30%
	var original_size = mesh.mesh.size
	var reduction = randf_range(0.1, 0.3)
	var new_height = original_size.y * (1.0 - reduction)
	mesh.mesh.size = Vector3(original_size.x, new_height, original_size.z)
	# Darken color and increase roughness
	var mat = mesh.material_override.duplicate()
	mat.albedo_color = mat.albedo_color.darkened(randf_range(0.1, 0.3))
	mat.roughness = clamp(mat.roughness + randf_range(0.05, 0.15), 0.0, 1.0)
	# Add slight emission for 'age glow'
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * randf_range(0.05, 0.15)
	mesh.material_override = mat
	# Lower wall position to match new height
	var y_offset = (mesh.mesh.size.y) / 2
	wall.global_position.y = y_offset

func _create_wall_at(grid_x: int, grid_y: int) -> StaticBody3D:
	"""Create a wall at grid position (boundary walls get special treatment)"""
	var wall = StaticBody3D.new()
	var grid_key = str(grid_x) + "," + str(grid_y)
	var is_boundary = boundary_walls.has(grid_key)
	
	if is_boundary:
		wall.name = "BoundaryWall"  # Special name for boundary walls
		wall.set_meta("is_boundary", true)
	else:
		wall.name = "Wall"
		wall.set_meta("is_boundary", false)
	
	wall.set_meta("grid_x", grid_x)
	wall.set_meta("grid_y", grid_y)
	
	# Mesh (boundary walls are slightly taller and use special material)
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	
	if is_boundary:
		mesh.mesh.size = Vector3(2.0, wall_height * 1.2, 2.0)  # Slightly smaller to avoid overlap
		mesh.material_override = boundary_wall_material
	else:
		mesh.mesh.size = Vector3(2.0, wall_height, 2.0)  # Slightly smaller to avoid overlap
		mesh.material_override = wall_material
	
	wall.add_child(mesh)
	
	# Collision
	var coll = CollisionShape3D.new()
	coll.shape = BoxShape3D.new()
	coll.shape.size = mesh.mesh.size  # Match collision shape to mesh size
	wall.add_child(coll)
	
	# Position
	add_child(wall)
	var y_offset = (mesh.mesh.size.y) / 2
	wall.global_position = Vector3(
		(grid_x - map_size.x / 2) * 2.0,
		y_offset,
		(grid_y - map_size.y / 2) * 2.0
	)
	
	generated_objects.append(wall)
	return wall

func _carve_room_shape(room_rect: Rect2, shape: RoomShape):
	"""Carve out different room shapes (with boundary protection)"""
	var start_x = int(room_rect.position.x)
	var start_y = int(room_rect.position.y)
	var width = int(room_rect.size.x)
	var height = int(room_rect.size.y)
	
	print("🛡️ Carving ", RoomShape.keys()[shape], " room at ", room_rect, " (protected from boundary)")
	
	match shape:
		RoomShape.SQUARE:
			_carve_square_protected(start_x, start_y, width, height)
		RoomShape.RECTANGLE:
			_carve_rectangle_protected(start_x, start_y, width, height)
		RoomShape.L_SHAPE:
			_carve_l_shape_protected(start_x, start_y, width, height)
		RoomShape.T_SHAPE:
			_carve_t_shape_protected(start_x, start_y, width, height)
		RoomShape.PLUS_SHAPE:
			_carve_plus_shape_protected(start_x, start_y, width, height)
		RoomShape.U_SHAPE:
			_carve_u_shape_protected(start_x, start_y, width, height)
		RoomShape.LONG_HALL:
			_carve_long_hall_protected(start_x, start_y, width, height)
		RoomShape.SMALL_SQUARE:
			_carve_small_square_protected(start_x, start_y, width, height)

func _carve_square_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected square carving - never touches boundary"""
	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_rectangle_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected rectangle carving"""
	var actual_width = width + randi_range(2, 4)
	var actual_height = height
	
	for x in range(start_x, start_x + actual_width):
		for y in range(start_y, start_y + actual_height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_l_shape_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected L-shape carving"""
	# Main rectangle
	var main_width = width
	var main_height = height - 2
	
	for x in range(start_x, start_x + main_width):
		for y in range(start_y, start_y + main_height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Extension
	var ext_width = width - 3
	var ext_height = 3
	
	for x in range(start_x, start_x + ext_width):
		for y in range(start_y + main_height, start_y + main_height + ext_height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_t_shape_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected T-shape carving"""
	# Horizontal bar
	var bar_width = width
	var bar_height = 2
	
	for x in range(start_x, start_x + bar_width):
		for y in range(start_y + height - bar_height, start_y + height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Vertical stem
	var stem_width = 3
	var stem_height = height - bar_height
	var stem_start_x = int(start_x + (width - stem_width) / 2.0)
	
	for x in range(stem_start_x, stem_start_x + stem_width):
		for y in range(start_y, start_y + stem_height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_plus_shape_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected plus-shape carving"""
	var center_x = int(start_x + width / 2.0)
	var center_y = int(start_y + height / 2.0)
	var arm_thickness = 2
	
	# Horizontal bar
	for x in range(start_x, start_x + width):
		@warning_ignore("integer_division")
		for y in range(center_y - arm_thickness/2, center_y + arm_thickness/2 + 1):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Vertical bar
	@warning_ignore("integer_division")
	for x in range(center_x - arm_thickness/2, center_x + arm_thickness/2 + 1):
		for y in range(start_y, start_y + height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_u_shape_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected U-shape carving"""
	# Carve entire area first
	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Put back walls to create U shape
	var block_width = width - 4
	var block_height = height - 3
	var block_start_x = start_x + 2
	var block_start_y = start_y + 3
	
	for x in range(block_start_x, block_start_x + block_width):
		for y in range(block_start_y, block_start_y + block_height):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.WALL

func _carve_long_hall_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected long hall carving"""
	var hall_width = 3
	var hall_length = width + 4
	
	var v_offset = int((height - hall_width) / 2.0)
	
	for x in range(start_x, start_x + hall_length):
		for y in range(start_y + v_offset, start_y + v_offset + hall_width):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_small_square_protected(start_x: int, start_y: int, width: int, height: int):
	"""Protected small square carving"""
	var small_size = 4
	var center_x = int(start_x + (width - small_size) / 2.0)
	var center_y = int(start_y + (height - small_size) / 2.0)
	
	for current_x in range(center_x, center_x + small_size):
		for current_y in range(center_y, center_y + small_size):
			if _is_valid_carve_position(current_x, current_y):
				terrain_grid[current_x][current_y] = TileType.FLOOR

func _is_valid_carve_position(x: int, y: int) -> bool:
	# Check if the carve position is inside the map and not in the boundary
	if not _is_valid_pos(x, y):
		return false
	if boundary_walls.has(str(x) + "," + str(y)):
		return false
	return true

func _is_valid_pos(x: int, y: int) -> bool:
	"""Check if the position is within the map bounds"""
	return x >= 0 and x < map_size.x and y >= 0 and y < map_size.y

func _find_new_room_position(existing_room: Rect2, room_size: Vector2) -> Rect2:
	"""Improved: Try many possible positions around the last room, not just 4 directions"""
	var distance = 4  # Distance between rooms
	var min_pos = boundary_thickness + safe_zone_margin
	var max_pos_x = map_size.x - boundary_thickness - safe_zone_margin - room_size.x
	var max_pos_y = map_size.y - boundary_thickness - safe_zone_margin - room_size.y

	print("🛡️ Safe room placement zone: (", min_pos, ",", min_pos, ") to (", max_pos_x, ",", max_pos_y, ")")

	# Try many offsets around the last room (cardinals, diagonals, and larger steps)
	var offsets = [
		Vector2(existing_room.size.x + distance, 0),
		Vector2(0, existing_room.size.y + distance),
		Vector2(-room_size.x - distance, 0),
		Vector2(0, -room_size.y - distance),
		Vector2(existing_room.size.x + distance, existing_room.size.y + distance),
		Vector2(-room_size.x - distance, existing_room.size.y + distance),
		Vector2(existing_room.size.x + distance, -room_size.y - distance),
		Vector2(-room_size.x - distance, -room_size.y - distance),
	]

	# Try all offsets from the last room's position
	for offset in offsets:
		var pos = existing_room.position + offset
		var test_room = Rect2(pos, room_size)
		if _is_room_position_safe(test_room, min_pos, max_pos_x, max_pos_y):
			print("🛡️ Found safe room position: ", test_room)
			return test_room

	# As a fallback, try a grid search in the safe area
	for x in range(int(min_pos), int(max_pos_x), 2):
		for y in range(int(min_pos), int(max_pos_y), 2):
			var pos = Vector2(x, y)
			var test_room = Rect2(pos, room_size)
			if _is_room_position_safe(test_room, min_pos, max_pos_x, max_pos_y):
				print("🛡️ Fallback found safe room position: ", test_room)
				return test_room

	print("🛡️ No safe room position found - all would be too close to boundary!")
	return Rect2()  # Failed

func _is_room_position_safe(room: Rect2, min_pos: float, max_pos_x: float, max_pos_y: float) -> bool:
	"""NEW: Enhanced safety check with boundary protection"""
	# Check strict safe boundaries
	if (room.position.x < min_pos or room.position.y < min_pos or
		room.position.x > max_pos_x or room.position.y > max_pos_y):
		print("🛡️ Room position rejected - too close to boundary: ", room)
		return false
	
	# Check overlap with existing rooms
	for existing_room in rooms:
		if room.intersects(existing_room):
			return false
	
	return true

func _move_player_to_room(room: Rect2):
	"""Move player to room center"""
	if not player:
		return
	
	var room_center_world = Vector3(
		(room.get_center().x - map_size.x / 2) * 2.0,
		1.5,
		(room.get_center().y - map_size.y / 2) * 2.0
	)
	player.global_position = room_center_world
	print("🛡️ Moved player to safe room center: ", room_center_world)

func _on_wave_completed(wave_number: int):
	"""Create new room when wave completes and tell spawner to use it"""
	print("🛡️ Wave ", wave_number, " completed! Creating new protected room...")
	var new_room = create_connected_room()
	if new_room != null:
		# Tell the enemy spawner to use this new room for the next wave
		if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
			enemy_spawner.set_newest_spawning_room(new_room)
		# 🗑️ Treasure chests disabled - cleaner dungeon generation
		_spawn_destructible_objects_in_room(new_room)
		_spawn_torches_in_room(new_room)
		print("🛡️ New room generated and set as spawning area!")
	else:
		print("🛡️ Room generation failed - no valid position found")

func create_connected_room():
	"""Create a new room with boundary protection"""
	if rooms.is_empty():
		print("🛡️ No existing rooms!")
		return null
	
	var last_room = rooms[rooms.size() - 1]
	print("🛡️ Connecting to room: ", last_room)
	
	var new_shape = _choose_room_shape()
	var room_size = _get_size_for_shape(new_shape)
	var new_room = _find_new_room_position(last_room, room_size)
	if new_room == Rect2():
		print("🛡️ Could not place new room safely within boundaries!")
		return null
	
	print("🛡️ Creating new ", RoomShape.keys()[new_shape], " room: ", new_room)
	_carve_room_shape(new_room, new_shape)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(new_shape)
	current_room_count += 1
	print("🛡️ New ", RoomShape.keys()[new_shape], " room created safely! Total: ", rooms.size())
	new_room_generated.emit(new_room)

	_spawn_destructible_objects_in_room(new_room)  # NEW: Spawn destructibles

	# --- RANDOM RECRUITER NPC SPAWN ---
	# Calculate spawn chance based on room progression
	var spawn_chance = min(recruiter_base_chance + (current_room_count * recruiter_chance_increase), recruiter_max_chance)
	if randf() < spawn_chance:
		# Check if recruiter already exists
		var existing_recruiter = get_tree().get_first_node_in_group("recruiters")
		if existing_recruiter:
			print("👤 Recruiter already exists, skipping spawn")
			return
		var recruiter_npc_scene = load("res://Scenes/recruiter_npc.tscn")
		if recruiter_npc_scene:
			var recruiter_npc_instance = recruiter_npc_scene.instantiate()
			add_child(recruiter_npc_instance)
			# Find safe spawn position away from objects
			var safe_position = _find_safe_recruiter_position(new_room)
			if safe_position != Vector3.ZERO:
				recruiter_npc_instance.global_position = safe_position
			print("👤 Recruiter NPC spawned in new room!")
			# Connect signal for recruiter to disappear after recruiting
			if recruiter_npc_instance.has_method("connect_recruit_signal"):
				recruiter_npc_instance.connect_recruit_signal()
		else:
			print("⚠️ Recruiter NPC scene not loaded, cannot spawn recruiter!")
	# --- END RANDOM RECRUITER NPC SPAWN ---

	return new_room

func _remove_walls_by_grid_lookup():
	# Build list of wall grid keys to remove
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
			continue  # Never remove boundary walls
		if terrain_grid[x][y] != TileType.WALL:
			to_remove_keys.append(grid_key)
	# Remove the walls
	for grid_key in to_remove_keys:
		if wall_lookup.has(grid_key):
			var wall = wall_lookup[grid_key]
			if is_instance_valid(wall):
				wall.queue_free()
			wall_lookup.erase(grid_key)

	# Remove torches attached to deleted walls using direct mapping
	var torches_to_remove = []
	for torch in torch_to_wall_map.keys():
		if not is_instance_valid(torch):
			torches_to_remove.append(torch)
			continue
		var wall_key = torch_to_wall_map[torch]
		if wall_key in to_remove_keys:
			torch.queue_free()
			generated_objects.erase(torch)
			torches_to_remove.append(torch)

	# Clean up the mapping
	for torch in torches_to_remove:
		torch_to_wall_map.erase(torch)

func _create_simple_corridor_protected(room_a: Rect2, room_b: Rect2):
	"""Create corridor with boundary protection"""
	var start = room_a.get_center()
	var end = room_b.get_center()
	
	@warning_ignore("integer_division")
	var half_width = int(corridor_width / 2)
	
	# Horizontal segment (protected)
	var h_start = int(min(start.x, end.x))
	var h_end = int(max(start.x, end.x))
	
	for x in range(h_start, h_end + 1):
		for w in range(-half_width, half_width + 1):
			var y = int(start.y + w)
			if _is_valid_carve_position(x, y):  # Uses boundary protection
				terrain_grid[x][y] = TileType.CORRIDOR
	
	# Vertical segment (protected)
	var v_start = int(min(start.y, end.y))
	var v_end = int(max(start.y, end.y))
	
	for y in range(v_start, v_end + 1):
		for w in range(-half_width, half_width + 1):
			var x = int(end.x + w)
			if _is_valid_carve_position(x, y):  # Uses boundary protection
				terrain_grid[x][y] = TileType.CORRIDOR

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
func get_current_room_count() -> int:
	return current_room_count

func force_generate_new_room():
	"""Manual room generation"""
	create_connected_room()

func get_boundary_info() -> Dictionary:
	"""NEW: Get information about boundary protection"""
	return {
		"boundary_thickness": boundary_thickness,
		"safe_zone_margin": safe_zone_margin,
		"total_boundary_walls": boundary_walls.size(),
		"map_size": map_size,
		"safe_zone_size": map_size - Vector2((boundary_thickness + safe_zone_margin) * 2, (boundary_thickness + safe_zone_margin) * 2)
	}

func _spawn_destructible_objects_in_room(room: Rect2):
	"""Spawn destructible crates and barrels in room with no overlap with each other or chests"""
	# Add null checks for scenes
	if not crate_scene and not barrel_scene:
		print("⚠️ No destructible object scenes available to spawn")
		return

	var object_count = randi_range(1, 2)
	var placed_positions: Array = []
	var min_distance = 2.0  # Minimum distance between objects

	# Gather crate and barrel positions in this room to avoid overlap
	for child in get_children():
		if child.name.begins_with("Crate") or child.is_in_group("crate") or child.name.begins_with("Barrel") or child.is_in_group("barrel"):
			if room.has_point(_world_to_grid(child.global_position)):
				placed_positions.append(child.global_position)

	for i in range(object_count):
		var pos = _find_safe_object_position_no_overlap(room, placed_positions, min_distance)
		if pos == Vector3.ZERO:
			continue

		var is_crate = randf() < 0.6
		var object_scene = crate_scene if (is_crate and crate_scene) else barrel_scene
		# Final null check before instantiation
		if not object_scene:
			continue

		var object = object_scene.instantiate()
		add_child(object)
		object.global_position = pos
		generated_objects.append(object)
		placed_positions.append(pos)
		print("🗃️ Spawned ", "crate" if is_crate else "barrel", " at ", pos)

func _find_safe_object_position_no_overlap(room: Rect2, placed_positions: Array, min_distance: float) -> Vector3:
	"""Find position for destructible that doesn't overlap with others or chests"""
	var attempts = 15
	while attempts > 0:
		var rx = randf_range(room.position.x + 1, room.position.x + room.size.x - 1)
		var ry = randf_range(room.position.y + 1, room.position.y + room.size.y - 1)
		var pos = Vector3(
			(rx - map_size.x / 2) * 2.0,
			0.5, # Height off ground
			(ry - map_size.y / 2) * 2.0
		)

		# Check overlap with already placed objects/chests
		var is_safe = true
		for other_pos in placed_positions:
			if pos.distance_to(other_pos) < min_distance:
				is_safe = false
				break

		if is_safe:
			return pos

		attempts -= 1
	return Vector3.ZERO

func _world_to_grid(world_pos: Vector3) -> Vector2:
	"""Convert world position to grid position"""
	return Vector2(
		int((world_pos.x / 2.0) + (map_size.x / 2)),
		int((world_pos.z / 2.0) + (map_size.y / 2))
	)

func _spawn_torches_in_room(room: Rect2):
	"""Spawns 4-8 torches around the given room's walls, using wall placement, rotation, and collision logic."""
	var torch_scene = load("res://Scenes/torch.tscn")
	if torch_scene:
		# Doubled the amount: was randi_range(2, 4), now randi_range(4, 8)
		var num_torches = randi_range(4, 8)
		var placed_torches = 0
		var tries = 0
		print("[TORCH DEBUG] Attempting to place %d torches in room %s" % [num_torches, str(room)])
		while placed_torches < num_torches and tries < 30:
			tries += 1
			# Randomly pick a wall (0=left, 1=right, 2=top, 3=bottom)
			var wall = randi() % 4
			var t = randf_range(0.2, 0.8) # Avoid corners more
			var pos = Vector2()
			var wall_grid_pos = Vector2()
			if wall == 0:
				pos = Vector2(room.position.x - 1, lerp(room.position.y, room.position.y + room.size.y - 1, t))
				wall_grid_pos = Vector2(room.position.x - 1, int(pos.y))
			elif wall == 1:
				pos = Vector2(room.position.x + room.size.x, lerp(room.position.y, room.position.y + room.size.y - 1, t))
				wall_grid_pos = Vector2(room.position.x + room.size.x, int(pos.y))
			elif wall == 2:
				pos = Vector2(lerp(room.position.x, room.position.x + room.size.x - 1, t), room.position.y - 1)
				wall_grid_pos = Vector2(int(pos.x), room.position.y - 1)
			else:
				pos = Vector2(lerp(room.position.x, room.position.x + room.size.x - 1, t), room.position.y + room.size.y)
				wall_grid_pos = Vector2(int(pos.x), room.position.y + room.size.y)

			var grid_x = int(wall_grid_pos.x)
			var grid_y = int(wall_grid_pos.y)
			if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
				print("[TORCH DEBUG] Rejected: Wall position outside map bounds")
				continue
			if terrain_grid[grid_x][grid_y] != TileType.WALL:
				print("[TORCH DEBUG] Rejected: No wall at grid position (%d, %d)" % [grid_x, grid_y])
				continue
			var room_side_pos = Vector2()
			if wall == 0:
				room_side_pos = Vector2(room.position.x, pos.y)
			elif wall == 1:
				room_side_pos = Vector2(room.position.x + room.size.x - 1, pos.y)
			elif wall == 2:
				room_side_pos = Vector2(pos.x, room.position.y)
			else:
				room_side_pos = Vector2(pos.x, room.position.y + room.size.y - 1)
			var torch_grid_pos = (wall_grid_pos + room_side_pos) * 0.5
			var world_pos = Vector3(
				(torch_grid_pos.x - map_size.x / 2) * 2.0,
				1.5,
				(torch_grid_pos.y - map_size.y / 2) * 2.0
			)
			# Add small offset toward room center
			if wall == 0:
				world_pos.x += 0.3
			elif wall == 1:
				world_pos.x -= 0.3
			elif wall == 2:
				world_pos.z += 0.3
			elif wall == 3:
				world_pos.z -= 0.3
			var safe = true
			var room_center_world = Vector3(
				(room.get_center().x - map_size.x / 2) * 2.0,
				1.2,
				(room.get_center().y - map_size.y / 2) * 2.0
			)
			if world_pos.distance_to(room_center_world) < 3.0:
				print("[TORCH DEBUG] Rejected: Too close to player spawn")
				safe = false
			for obj in generated_objects:
				if is_instance_valid(obj) and obj is StaticBody3D and obj.name.begins_with("Torch"):
					if obj.global_position.distance_to(world_pos) < 3.0:
						print("[TORCH DEBUG] Rejected: Too close to another torch")
						safe = false
						break
			if safe:
				var torch = torch_scene.instantiate()
				match wall:
					0:
						torch.rotation_degrees = Vector3(0, 90, 0)
					1:
						torch.rotation_degrees = Vector3(0, -90, 0)
					2:
						torch.rotation_degrees = Vector3(0, 0, 0)
					3:
						torch.rotation_degrees = Vector3(0, 180, 0)
				torch.name = "Torch_%d" % placed_torches
				add_child(torch)
				torch.global_position = world_pos
				generated_objects.append(torch)
				# Track which wall this torch is attached to
				var wall_key = str(grid_x) + "," + str(grid_y)
				torch_to_wall_map[torch] = wall_key
				placed_torches += 1
		if placed_torches == 0:
			print("[TORCH DEBUG] ❌ No torches placed after %d tries!" % tries)
		else:
			print("[TORCH DEBUG] ✅ Successfully placed %d torches" % placed_torches)

func _get_torch_grid_position(torch_world_pos: Vector3) -> Vector2:
	# Converts a torch's world position back to grid coordinates
	return Vector2(int((torch_world_pos.x / 2.0) + (map_size.x / 2)), int((torch_world_pos.z / 2.0) + (map_size.y / 2)))

# --- Lighting setup: simple dark directional light and environment ---
# func _setup_lighting():
# 	"""Create simple dark lighting"""
# 	var main_light = DirectionalLight3D.new()
# 	main_light.name = "MainLight"
# 	main_light.shadow_enabled = true
# 	main_light.light_energy = 0.6
# 	main_light.light_color = Color(0.9, 0.95, 1.0)  # Slight blue tint
# 	main_light.rotation_degrees = Vector3(-45, 30, 0)  # Fixed angle
# 	add_child(main_light)
#
# 	var env = Environment.new()
# 	env.background_mode = Environment.BG_SKY
# 	env.ambient_light_energy = 0.1  # Very dark
# 	env.ambient_light_color = Color(0.2, 0.2, 0.3)
#
# 	var world_environment = WorldEnvironment.new()
# 	world_environment.environment = env
# 	add_child(world_environment)

func _setup_lighting():
	print("🔆 Lighting handled by main_scene_setup.gd")

func _find_safe_recruiter_position(room: Rect2) -> Vector3:
	var attempts = 10
	while attempts > 0:
		var center = room.get_center()
		var offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		var test_pos = Vector3(
			(center.x - map_size.x / 2) * 2.0 + offset.x,
			0.5,
			(center.y - map_size.y / 2) * 2.0 + offset.y
		)
		# Check distance from other objects
		var is_safe = true
		for child in get_children():
			if child.has_method("get_global_position"):
				var child_pos = child.get_global_position()
				if child_pos.distance_to(test_pos) < 2.0:
					is_safe = false
					break
			elif child.has_method("global_position"):
				if child.global_position.distance_to(test_pos) < 2.0:
					is_safe = false
					break
		if is_safe:
			return test_pos
		attempts -= 1
	# Fallback to room center
	var fallback_center = room.get_center()
	return Vector3((fallback_center.x - map_size.x / 2) * 2.0, 0.5, (fallback_center.y - map_size.y / 2) * 2.0)
