# simple_room_generator.gd - ENHANCED: Added weapon rooms between waves - COMPLETE VERSION
extends Node3D

signal new_room_generated(room_rect: Rect2)
signal weapon_room_generated(room_rect: Rect2)  # NEW: Signal for weapon rooms

@export var map_size = Vector2(60, 60)
@export var base_room_size = Vector2(6, 6)
@export var corridor_width = 3
@export var wall_height = 3.0
@export var auto_generate_on_start = true
@export var max_rooms := 10

# NEW: Weapon room configuration
@export_group("Weapon Room Settings")
@export var weapon_room_chance: float = 0.4  # 40% chance for weapon room between waves
@export var weapon_room_size = Vector2(8, 8)  # Slightly larger than normal rooms
@export var guaranteed_weapon_spawn: bool = true  # Always spawn weapon in weapon rooms
@export var weapon_room_special_lighting: bool = true  # Add extra lighting to weapon rooms

# NEW: Boundary protection settings
@export_group("Boundary Protection")
@export var boundary_thickness = 2  # How many tiles thick the protected boundary is
@export var safe_zone_margin = 4    # Extra margin inside the boundary for room placement

# Recruiter spawn configuration
@export_group("NPC Settings")
@export var recruiter_base_chance: float = 0.25  # 25% base chance
@export var recruiter_chance_increase: float = 0.1  # Increases per room
@export var recruiter_max_chance: float = 0.8  # Max 80% chance

enum TileType { WALL, FLOOR, CORRIDOR }

# Room shape types
enum RoomShape { 
	SQUARE, RECTANGLE, L_SHAPE, T_SHAPE, PLUS_SHAPE, U_SHAPE, LONG_HALL, SMALL_SQUARE
}

# NEW: Room types
enum RoomType {
	NORMAL,     # Regular wave room
	WEAPON,     # Special weapon room
	STARTING    # Starting room
}

var terrain_grid: Array = []
var rooms: Array = []
var room_shapes: Array = []
var room_types: Array = []  # NEW: Track what type each room is
var corridors: Array = []
var generated_objects: Array = []
var current_room_count = 0

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
var weapon_room_floor_material: StandardMaterial3D  # NEW: Special floor for weapon rooms

# References
var enemy_spawner: Node3D
var player: Node3D

# PackedScene references
var weapon_pickup_scene: PackedScene
@export var crate_scene: PackedScene
@export var barrel_scene: PackedScene

func _ready():
	add_to_group("terrain")
	
	# Check if WeaponPool is available
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
		call_deferred("generate_starting_room")

func _create_materials():
	# Regular wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.4, 0.4, 0.45)
	wall_material.roughness = 0.9

	# Boundary wall material (darker, more imposing)
	boundary_wall_material = StandardMaterial3D.new()
	boundary_wall_material.albedo_color = Color(0.2, 0.2, 0.25)
	boundary_wall_material.roughness = 0.95
	boundary_wall_material.metallic = 0.3
	boundary_wall_material.emission_enabled = true
	boundary_wall_material.emission = Color(0.1, 0.1, 0.15) * 0.3

	# Floor material
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.8, 0.8, 0.85)
	floor_material.roughness = 0.8
	
	# NEW: Special weapon room floor material (slightly golden/magical)
	weapon_room_floor_material = StandardMaterial3D.new()
	weapon_room_floor_material.albedo_color = Color(0.9, 0.85, 0.7)  # Slightly golden
	weapon_room_floor_material.roughness = 0.6
	weapon_room_floor_material.metallic = 0.1
	weapon_room_floor_material.emission_enabled = true
	weapon_room_floor_material.emission = Color(0.3, 0.25, 0.1) * 0.05  # Subtle golden glow

func _find_references():
	player = get_tree().get_first_node_in_group("player")
	enemy_spawner = get_tree().get_first_node_in_group("spawner")
	
	if enemy_spawner and enemy_spawner.has_signal("wave_completed"):
		if not enemy_spawner.wave_completed.is_connected(_on_wave_completed):
			enemy_spawner.wave_completed.connect(_on_wave_completed)
			print("🗡️ Enhanced Generator: ✅ Connected to wave system")

# ========================
# NEW: WEAPON ROOM SYSTEM
# ========================

func _should_create_weapon_room(wave_number: int) -> bool:
	"""Determine if we should create a weapon room after this wave"""
	# Don't create weapon rooms too frequently
	if wave_number - last_weapon_room_wave < 2:
		return false
	
	# Roll for weapon room chance
	return randf() < weapon_room_chance

func _create_weapon_room() -> Rect2:
	"""Create a special weapon room with enhanced visuals"""
	print("🗡️ Creating WEAPON ROOM!")
	
	if rooms.is_empty():
		print("❌ No existing rooms for weapon room!")
		return Rect2()
	
	var last_room = rooms[rooms.size() - 1]
	var new_room = _find_new_room_position(last_room, weapon_room_size)
	
	if new_room == Rect2():
		print("❌ Could not place weapon room safely!")
		return Rect2()
	
	# Carve the weapon room
	_carve_room_shape(new_room, RoomShape.SQUARE)
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	
	# Add to tracking arrays
	rooms.append(new_room)
	room_shapes.append(RoomShape.SQUARE)
	room_types.append(RoomType.WEAPON)  # NEW: Mark as weapon room
	current_room_count += 1
	
	print("🗡️ Weapon room created at: ", new_room)
	
	# Generate special weapon room content
	call_deferred("_setup_weapon_room", new_room)
	
	# Update last weapon room wave
	if enemy_spawner and enemy_spawner.has_method("get_wave_info"):
		var wave_info = enemy_spawner.get_wave_info()
		last_weapon_room_wave = wave_info.get("current_wave", 0)
	
	# Emit special signal
	weapon_room_generated.emit(new_room)
	
	return new_room

func _setup_weapon_room(room: Rect2):
	"""Setup special weapon room with enhanced lighting and guaranteed weapon"""
	print("🗡️ Setting up weapon room contents...")
	
	# Apply special floor material to weapon room
	_apply_weapon_room_floor(room)
	
	# Add extra lighting if enabled
	if weapon_room_special_lighting:
		_add_weapon_room_lighting(room)
	
	# Spawn guaranteed weapon
	if guaranteed_weapon_spawn:
		_spawn_weapon_in_room(room)
	
	print("✅ Weapon room setup complete!")

func _create_floor_with_collision(room_center_world: Vector3, size: Vector2, material: Material) -> StaticBody3D:
	# Create a static body for the floor with collision
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1 # Layer 1 (Floor)
	floor_body.collision_mask = 0xFFFFFFFF # Collide with everything by default

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = PlaneMesh.new()
	mesh_instance.mesh.size = size
	mesh_instance.material_override = material
	mesh_instance.position = Vector3.ZERO
	floor_body.add_child(mesh_instance)

	var collision_shape = CollisionShape3D.new()
	var plane_shape = BoxShape3D.new()
	plane_shape.size = Vector3(size.x, 0.1, size.y) # Thin box for floor collision
	collision_shape.shape = plane_shape
	collision_shape.position = Vector3(0, -0.05, 0) # Slightly below mesh
	floor_body.add_child(collision_shape)

	floor_body.position = room_center_world
	add_child(floor_body)
	generated_objects.append(floor_body)
	return floor_body

func _apply_weapon_room_floor(room: Rect2):
	"""Apply special golden floor material to weapon room"""
	var room_center_world = Vector3(
		(room.get_center().x - map_size.x / 2) * 2.0,
		0.0,
		(room.get_center().y - map_size.y / 2) * 2.0
	)
	_create_floor_with_collision(room_center_world, Vector2(room.size.x * 2.0, room.size.y * 2.0), weapon_room_floor_material)

func _add_weapon_room_lighting(room: Rect2):
	"""Add special lighting to weapon room"""
	var room_center_world = Vector3(
		(room.get_center().x - map_size.x / 2) * 2.0,
		3.0,  # Higher up
		(room.get_center().y - map_size.y / 2) * 2.0
	)
	
	# Create central magical light
	var light = OmniLight3D.new()
	light.light_energy = 1.5
	light.light_color = Color(1.0, 0.9, 0.7)  # Warm golden light
	light.omni_range = 15.0  # FIXED: Godot 4 uses omni_range not light_range
	light.position = room_center_world
	add_child(light)
	generated_objects.append(light)
	
	# Add some sparkle effects around the room edges
	for i in range(4):
		var corner_light = OmniLight3D.new()
		corner_light.light_energy = 0.8
		corner_light.light_color = Color(0.7, 0.8, 1.0)  # Cooler blue light
		corner_light.omni_range = 8.0  # FIXED: Godot 4 uses omni_range not light_range
		
		var corner_pos = Vector3(
			room_center_world.x + (randf_range(-1, 1) * room.size.x),
			2.5,
			room_center_world.z + (randf_range(-1, 1) * room.size.y)
		)
		corner_light.position = corner_pos
		add_child(corner_light)
		generated_objects.append(corner_light)

func _spawn_weapon_in_room(room: Rect2):
	"""Spawn a guaranteed weapon in the weapon room"""
	print("🗡️ Spawning weapon in weapon room...")
	
	# Get weapon from pool
	var weapon_resource = null
	if has_node("/root/WeaponPool"):
		var weapon_pool = get_node("/root/WeaponPool")
		if weapon_pool.has_method("get_random_weapon"):
			weapon_resource = weapon_pool.get_random_weapon(true)
	
	if not weapon_resource:
		print("⚠️ Could not get weapon from pool, creating default")
		# Fallback - create a basic weapon
		if ResourceLoader.exists("res://Weapons/iron_sword.tres"):
			weapon_resource = load("res://Weapons/iron_sword.tres")
	
	# Create weapon pickup
	if weapon_pickup_scene and weapon_resource:
		var weapon_pickup = weapon_pickup_scene.instantiate()
		add_child(weapon_pickup)
		
		# Position in center of room, slightly elevated
		var spawn_pos = Vector3(
			(room.get_center().x - map_size.x / 2) * 2.0,
			2.0,  # Elevated position
			(room.get_center().y - map_size.y / 2) * 2.0
		)
		weapon_pickup.global_position = spawn_pos
		
		# Set the weapon resource
		if weapon_pickup.has_method("set_weapon_resource"):
			weapon_pickup.set_weapon_resource(weapon_resource)
		
		generated_objects.append(weapon_pickup)
		print("✅ Weapon spawned: ", weapon_resource.weapon_name if weapon_resource else "Unknown")
	else:
		print("❌ Could not spawn weapon - missing scene or resource")

func _on_wave_completed(wave_number: int):
	"""Enhanced wave completion with weapon room logic"""
	print("🗡️ Wave ", wave_number, " completed! Checking for weapon room...")
	
	# Check if we should create a weapon room
	if _should_create_weapon_room(wave_number):
		print("🗡️ Creating weapon room after wave ", wave_number)
		
		# Create weapon room first
		var weapon_room = _create_weapon_room()
		if weapon_room != Rect2():
			pending_weapon_room = false
			
			# Now create the next wave room connected to the weapon room
			await get_tree().create_timer(0.5).timeout  # Small delay for visual effect
			var next_wave_room = create_connected_room()
			
			if next_wave_room != null:
				# Tell spawner to use the new wave room (not the weapon room!)
				if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
					enemy_spawner.set_newest_spawning_room(next_wave_room)
				
				_spawn_destructible_objects_in_room(next_wave_room)
				print("🗡️ Created weapon room + next wave room!")
			else:
				print("❌ Failed to create next wave room after weapon room")
		else:
			print("❌ Failed to create weapon room, creating normal room")
			# Fallback to normal room creation
			_create_normal_room_after_wave(wave_number)
	else:
		print("🗡️ No weapon room this time, creating normal room")
		_create_normal_room_after_wave(wave_number)

func _create_normal_room_after_wave(wave_number: int):
	"""Create normal room after wave (original behavior)"""
	print("🏠 Creating normal room after wave ", wave_number)
	var new_room = create_connected_room()
	if new_room != null:
		# Tell the enemy spawner to use this new room for the next wave
		if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
			enemy_spawner.set_newest_spawning_room(new_room)
		_spawn_destructible_objects_in_room(new_room)
		_spawn_torches_in_room(new_room)
		print("✅ Normal room generated and set as spawning area!")
	else:
		print("❌ Room generation failed - no valid position found")

# =====================================
# EXISTING METHODS (keeping your current room generation logic)
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
	room_types.append(RoomType.STARTING)  # NEW: Mark as starting room
	current_room_count = 1
	
	# Generate walls
	_generate_all_walls_with_boundary_protection()
	
	# Move player to room center
	_move_player_to_room(starting_room)
	
	# Spawn starting room content
	_spawn_destructible_objects_in_room(starting_room)
	_spawn_torches_in_room(starting_room)

	# --- CREATE FIRST WAVE ROOM FARTHER AWAY ---
	if enemy_spawner and enemy_spawner.has_method("set_newest_spawning_room"):
		var first_wave_room = create_connected_room()
		if first_wave_room != null:
			enemy_spawner.set_newest_spawning_room(first_wave_room)
			print("✅ First wave room created and set for enemy spawner:", first_wave_room)
			# Spawn torches in the first wave room
			_spawn_torches_in_room(first_wave_room)
			# Also spawn torches in the corridor(s) between starting and first wave room
			for corridor_rect in corridors:
				_spawn_torches_in_room(corridor_rect)
		else:
			print("❌ Could not create first wave room!")

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
	_create_simple_corridor_protected(last_room, new_room)
	_remove_walls_by_grid_lookup()
	rooms.append(new_room)
	room_shapes.append(new_shape)
	room_types.append(RoomType.NORMAL)  # NEW: Mark as normal room
	current_room_count += 1
	print("🏠 New ", RoomShape.keys()[new_shape], " room created safely! Total: ", rooms.size())
	new_room_generated.emit(new_room)

	_spawn_destructible_objects_in_room(new_room)

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
# ALL EXISTING HELPER METHODS
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
	room_types.clear()  # NEW: Clear room types
	corridors.clear()
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
	wall.collision_layer = 1 << 1  # Layer 2 (Walls)
	wall.collision_mask = (1 << 2) | (1 << 3) | (1 << 4)  # Collide with Player, Ally, Boss
	
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
	
	wall.position = Vector3(
		(grid_x - map_size.x / 2) * 2.0,
		wall_height / 2.0,
		(grid_y - map_size.y / 2) * 2.0
	)
	
	generated_objects.append(wall)
	return wall

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

func _carve_l_shape(room: Rect2):
	"""Carve an L-shaped room"""
	var half_x = int(room.size.x / 2)
	var half_y = int(room.size.y / 2)
	
	# Horizontal part
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + half_y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Vertical part
	for x in range(int(room.position.x), int(room.position.x + half_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_t_shape(room: Rect2):
	"""Carve a T-shaped room"""
	var third_x = int(room.size.x / 3)
	var half_y = int(room.size.y / 2)
	
	# Horizontal top
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + half_y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Vertical stem
	for x in range(int(room.position.x + third_x), int(room.position.x + 2 * third_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_plus_shape(room: Rect2):
	"""Carve a plus-shaped room"""
	var center_x = int(room.position.x + room.size.x / 2)
	var center_y = int(room.position.y + room.size.y / 2)
	var arm_width = 2
	
	# Horizontal arm
	for x in range(int(room.position.x), int(room.position.x + room.size.x)):
		for y in range(center_y - arm_width, center_y + arm_width):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Vertical arm
	for x in range(center_x - arm_width, center_x + arm_width):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _carve_u_shape(room: Rect2):
	"""Carve a U-shaped room"""
	var third_x = int(room.size.x / 3)
	var half_y = int(room.size.y / 2)
	
	# Left wall
	for x in range(int(room.position.x), int(room.position.x + third_x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Right wall
	for x in range(int(room.position.x + 2 * third_x), int(room.position.x + room.size.x)):
		for y in range(int(room.position.y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR
	
	# Bottom connecting section
	for x in range(int(room.position.x + third_x), int(room.position.x + 2 * third_x)):
		for y in range(int(room.position.y + half_y), int(room.position.y + room.size.y)):
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.FLOOR

func _is_valid_carve_position(x: int, y: int) -> bool:
	"""Check if position is valid for carving (respects boundaries)"""
	if x < 0 or x >= map_size.x or y < 0 or y >= map_size.y:
		return false
	
	# Check if it's a boundary wall (never carve boundary walls)
	var grid_key = str(x) + "," + str(y)
	if boundary_walls.has(grid_key):
		return false
	
	return true

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
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR
	
	# Vertical segment (protected)
	var v_start = int(min(start.y, end.y))
	var v_end = int(max(start.y, end.y))
	
	for y in range(v_start, v_end + 1):
		for w in range(-half_width, half_width + 1):
			var x = int(end.x + w)
			if _is_valid_carve_position(x, y):
				terrain_grid[x][y] = TileType.CORRIDOR

func _find_new_room_position(last_room: Rect2, room_size: Vector2) -> Rect2:
	"""Find safe position for new room with enhanced boundary protection"""
	var max_attempts = 50
	var min_distance = 3  # Minimum distance between rooms
	
	# Define safe boundaries
	var min_pos = boundary_thickness + safe_zone_margin + 1
	var max_pos_x = map_size.x - boundary_thickness - safe_zone_margin - room_size.x - 1
	var max_pos_y = map_size.y - boundary_thickness - safe_zone_margin - room_size.y - 1
	
	for attempt in range(max_attempts):
		# Generate candidate position around the last room
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
	return Rect2()  # Failed

func _is_room_position_safe(room: Rect2, min_pos: float, max_pos_x: float, max_pos_y: float) -> bool:
	"""Enhanced safety check with boundary protection"""
	# Check strict safe boundaries
	if (room.position.x < min_pos or room.position.y < min_pos or
		room.position.x > max_pos_x or room.position.y > max_pos_y):
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
	print("🗡️ Moved player to safe room center: ", room_center_world)

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

func _spawn_destructible_objects_in_room(room: Rect2):
	"""Spawn crates and barrels in room"""
	var objects_to_spawn = randi_range(2, 4)
	
	for i in range(objects_to_spawn):
		var object_scene = crate_scene if randf() < 0.6 else barrel_scene
		if not object_scene:
			continue
		
		var object_instance = object_scene.instantiate()
		add_child(object_instance)
		
		# Random position in room
		var random_pos = Vector2(
			room.position.x + randf() * room.size.x,
			room.position.y + randf() * room.size.y
		)
		
		var world_pos = Vector3(
			(random_pos.x - map_size.x / 2) * 2.0,
			1.0,
			(random_pos.y - map_size.y / 2) * 2.0
		)
		
		object_instance.global_position = world_pos
		generated_objects.append(object_instance)

func _find_safe_recruiter_position(room: Rect2) -> Vector3:
	"""Find safe position for recruiter away from other objects"""
	var attempts = 10
	for attempt in range(attempts):
		var random_pos = Vector2(
			room.position.x + 1 + randf() * (room.size.x - 2),
			room.position.y + 1 + randf() * (room.size.y - 2)
		)
		
		var world_pos = Vector3(
			(random_pos.x - map_size.x / 2) * 2.0,
			1.0,
			(random_pos.y - map_size.y / 2) * 2.0
		)
		
		# Check distance from other objects
		var safe = true
		for obj in generated_objects:
			if is_instance_valid(obj) and world_pos.distance_to(obj.global_position) < 3.0:
				safe = false
				break
		
		if safe:
			return world_pos
	
	return Vector3.ZERO

# Spawns a torch at the given position
func spawn_torch_at_position(pos: Vector3):
	var torch_scene = preload("res://Scenes/EnhancedTorch.tscn")
	var torch = torch_scene.instantiate()
	add_child(torch)
	torch.global_position = pos
	# print("\ud83d\udd25 Torch spawned at: ", pos)  # Commented to reduce log spam

func _spawn_torches_in_room(room: Rect2):
	# Improved: Place torches near corners, but not inside walls
	var torch_height = 1.5
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
					var world_pos = Vector3(
						(grid_x - map_size.x / 2) * 2.0,
						torch_height,
						(grid_y - map_size.y / 2) * 2.0
					)
					spawn_torch_at_position(world_pos)
					found = true
					break
		if not found:
			print("⚠️ Could not find valid floor for torch near corner:", corner)

# =====================================
# NEW: PUBLIC API FOR UI AND DEBUGGING
# =====================================

func get_room_info() -> Dictionary:
	"""Get information about rooms for UI/debugging"""
	var weapon_rooms = 0
	var normal_rooms = 0
	
	for room_type in room_types:
		match room_type:
			RoomType.WEAPON:
				weapon_rooms += 1
			RoomType.NORMAL:
				normal_rooms += 1
	
	return {
		"total_rooms": rooms.size(),
		"weapon_rooms": weapon_rooms,
		"normal_rooms": normal_rooms,
		"last_weapon_room_wave": last_weapon_room_wave,
		"weapon_room_chance": weapon_room_chance
	}

func get_rooms() -> Array:
	"""Get all rooms for external systems"""
	return rooms

func get_current_room_count() -> int:
	return current_room_count

func force_generate_weapon_room():
	"""Debug: Force create a weapon room"""
	print("🗡️ DEBUG: Forcing weapon room creation...")
	_create_weapon_room()

func force_generate_new_room():
	"""Manual room generation"""
	create_connected_room()

func get_boundary_info() -> Dictionary:
	"""Get information about boundary protection"""
	return {
		"boundary_thickness": boundary_thickness,
		"safe_zone_margin": safe_zone_margin,
		"total_boundary_walls": boundary_walls.size(),
		"map_size": map_size,
		"safe_zone_size": map_size - Vector2((boundary_thickness + safe_zone_margin) * 2, (boundary_thickness + safe_zone_margin) * 2)
	}

# === BOSS SUPPORT METHODS ===
# Remove wall from tracking system when boss breaks it
func _remove_wall_from_lookup(grid_x: int, grid_y: int) -> void:
	var grid_key = str(grid_x) + "," + str(grid_y)
	if wall_lookup.has(grid_key):
		wall_lookup.erase(grid_key)
		# Also update the terrain grid if within bounds
		if grid_x >= 0 and grid_x < map_size.x and grid_y >= 0 and grid_y < map_size.y:
			terrain_grid[grid_x][grid_y] = TileType.FLOOR
		print("🌍 TERRAIN: Removed wall at grid position (", grid_x, ", ", grid_y, ")")

# Check if a wall position is a boundary wall (unbreakable)
func _is_boundary_wall(grid_x: int, grid_y: int) -> bool:
	var grid_key = str(grid_x) + "," + str(grid_y)
	return boundary_walls.has(grid_key)

# Get wall node at specific grid position
func get_wall_at_position(grid_x: int, grid_y: int) -> StaticBody3D:
	var grid_key = str(grid_x) + "," + str(grid_y)
	return wall_lookup.get(grid_key, null)

# Check if grid position is valid (not a wall)
func _is_valid_pos(grid_x: int, grid_y: int) -> bool:
	if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
		return false
	return terrain_grid[grid_x][grid_y] != TileType.WALL
