# dungeon_lighting_manager.gd - Godot 4.1+ Best Practices
# Purpose: Manages atmospheric dungeon lighting with torch effects and special room lighting
# Author: Thane
# Godot Version: 4.1+
#
# Attach this script to a DirectionalLight3D node in your scene
extends DirectionalLight3D

# --- CONFIGURATION GROUPS (Godot 4.1+ @export_group pattern) ---
@export_group("Dungeon Atmosphere")
@export var enable_fog: bool = true
@export var fog_density: float = 0.02
@export var ambient_light_energy: float = 0.08
@export var main_light_energy: float = 0.3

@export_group("Torch Settings") 
@export var torch_energy: float = 1.2
@export var torch_range: float = 8.0
@export var torch_flicker_intensity: float = 0.3

@export_group("Special Room Lighting")
@export var weapon_room_magic_energy: float = 2.0
@export var weapon_room_accent_count: int = 4

@export_group("Player Lighting")
@export var enable_player_light: bool = true
@export var player_light_energy: float = 0.7
@export var player_light_range: float = 4.0

@export_group("Debug")
@export var debug_mode: bool = false

# --- INTERNAL VARIABLES ---
var world_environment: WorldEnvironment
var torch_lights: Array[OmniLight3D] = []
var special_lights: Array[OmniLight3D] = []
var player_light: OmniLight3D
var player_node: Node3D
var room_generator: Node3D

# Lighting organization nodes
var lighting_root: Node3D
var torch_group: Node3D
var special_group: Node3D

# Component state
var _is_initialized: bool = false
var _connections_made: bool = false

# --- INITIALIZATION (Godot 4.1+ pattern with safety checks) ---
func _ready() -> void:
	name = "DungeonLightingManager"
	add_to_group("lighting_manager")
	
	# Safety check - ensure this is actually attached to DirectionalLight3D
	if not self is DirectionalLight3D:
		push_error("❌ This script must be attached to a DirectionalLight3D node!")
		return
	
	# Initialize step by step with proper error handling
	_setup_main_light()
	
	# Use call_deferred for scene setup (Godot 4.1+ best practice)
	call_deferred("_initialize_lighting_system")

func _initialize_lighting_system() -> void:
	"""Initialize lighting system in proper order"""
	if _is_initialized:
		return
		
	# Step 1: Setup environment
	_setup_dungeon_environment()
	
	# Step 2: Create organization structure  
	_create_lighting_groups()
	
	# Step 3: Find scene nodes
	_find_scene_nodes()
	
	# Step 4: Setup player lighting
	if enable_player_light and player_node:
		_setup_player_light()
	
	# Step 5: Connect to room generator
	_connect_to_room_generator()
	
	_is_initialized = true
	if debug_mode:
		print("✅ Dungeon Lighting Manager initialized successfully")

# --- MAIN LIGHT SETUP (Following project patterns) ---
func _setup_main_light() -> void:
	"""Configure the DirectionalLight3D this script is attached to"""
	# Godot 4.1+ properties (some were renamed from Godot 3.x)
	light_energy = main_light_energy
	light_color = Color(0.7, 0.6, 0.9)  # Cool moonlight color
	
	# Mysterious atmosphere angle
	rotation_degrees = Vector3(-45, -30, 0)
	
	# Enable shadows with Godot 4.1+ optimized settings
	shadow_enabled = true
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	directional_shadow_max_distance = 50.0

func _setup_dungeon_environment() -> void:
	"""Create atmospheric environment using Godot 4.1+ Environment features"""
	# Remove existing environment (safety check)
	var existing_env = get_tree().get_first_node_in_group("world_environment")
	if existing_env and existing_env != world_environment:
		existing_env.queue_free()
		await get_tree().process_frame
	
	# Create new environment
	world_environment = WorldEnvironment.new()
	world_environment.name = "DungeonEnvironment"
	world_environment.add_to_group("world_environment")
	
	var environment = Environment.new()
	
	# Dark atmospheric background
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.08, 0.12)  # Deep blue-black
	
	# Ambient lighting (Godot 4.1+ uses ambient_light_source)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = ambient_light_energy
	environment.ambient_light_color = Color(0.3, 0.25, 0.4)  # Cool purple tint
	
	# Atmospheric fog (Godot 4.1+ fog system)
	if enable_fog:
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.4, 0.3, 0.2)  # Warm torch-like fog
		environment.fog_light_energy = 0.5
		environment.fog_sun_scatter = 0.1
		environment.fog_density = fog_density
		
		# Godot 4.1+ volumetric fog (if you want more advanced fog)
		environment.volumetric_fog_enabled = false  # Set to true for advanced fog
	
	# Glow for magical effects (Godot 4.1+ glow system)
	environment.glow_enabled = true
	environment.glow_normalized = true  # Godot 4.1+ normalized glow
	environment.glow_intensity = 0.4
	environment.glow_strength = 0.8
	environment.glow_bloom = 0.3
	environment.glow_hdr_threshold = 0.8
	
	world_environment.environment = environment
	get_tree().current_scene.add_child(world_environment)

func _create_lighting_groups() -> void:
	"""Create organized structure for lights"""
	lighting_root = Node3D.new()
	lighting_root.name = "LightingSystem"
	add_child(lighting_root)
	
	torch_group = Node3D.new()
	torch_group.name = "TorchLights"
	lighting_root.add_child(torch_group)
	
	special_group = Node3D.new()
	special_group.name = "SpecialLights"
	lighting_root.add_child(special_group)

# --- NODE FINDING (Following project safety patterns) ---
func _find_scene_nodes() -> void:
	"""Find required nodes using safe patterns from project"""
	# Find player using multiple methods (following project pattern)
	player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		for player_name in ["Player", "player", "Character"]:
			player_node = get_tree().current_scene.find_child(player_name, true, false)
			if player_node:
				break
	
	if debug_mode:
		if player_node:
			print("👤 Player found: ", player_node.name)
		else:
			print("⚠️ Player not found - player lighting disabled")

func _connect_to_room_generator() -> void:
	"""Connect to room generator using safe connection pattern"""
	if _connections_made:
		return
		
	# Find room generator
	room_generator = get_tree().get_first_node_in_group("room_generator")
	if not room_generator:
		room_generator = get_tree().current_scene.find_child("SimpleRoomGenerator", true, false)
	
	if not room_generator:
		if debug_mode:
			print("⚠️ Room generator not found - manual lighting only")
		return
	
	# Connect signals safely (following project pattern)
	_connect_signal_safely(room_generator, "new_room_generated", _on_room_generated)
	_connect_signal_safely(room_generator, "weapon_room_generated", _on_weapon_room_generated)
	
	_connections_made = true
	
	# Add lights to existing rooms
	call_deferred("_add_lights_to_existing_rooms")

# --- SAFE SIGNAL CONNECTION (Following project pattern) ---
func _connect_signal_safely(object: Node, signal_name: String, callable: Callable) -> void:
	"""Safely connect signals with error checking"""
	if not object or not object.has_signal(signal_name):
		if debug_mode:
			print("⚠️ Signal not found: ", signal_name, " on ", object.name if object else "null")
		return
		
	if object.is_connected(signal_name, callable):
		if debug_mode:
			print("⚠️ Signal already connected: ", signal_name)
		return
		
	var error = object.connect(signal_name, callable)
	if error != OK:
		push_error("Failed to connect signal: " + signal_name + " Error: " + str(error))
	elif debug_mode:
		print("✅ Connected signal: ", signal_name)

# --- TORCH LIGHTING SYSTEM ---
func create_torch_light(pos: Vector3, parent_group: Node3D = null) -> OmniLight3D:
	"""Create a flickering torch light at specified position"""
	var torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	
	# Godot 4.1+ OmniLight3D properties
	torch_light.light_color = Color(1.0, 0.7, 0.4)  # Warm orange flame
	torch_light.light_energy = torch_energy
	torch_light.omni_range = torch_range
	torch_light.omni_attenuation = 2.0  # Realistic falloff
	
	# Shadows (Godot 4.1+ shadow settings)
	torch_light.shadow_enabled = true
	torch_light.shadow_bias = 0.15
	
	torch_light.position = pos
	
	# Add to scene
	var target_parent = parent_group if parent_group else torch_group
	target_parent.add_child(torch_light)
	
	# Add flickering effect
	_add_torch_flicker(torch_light)
	
	torch_lights.append(torch_light)
	return torch_light

func _add_torch_flicker(light: OmniLight3D) -> void:
	"""Add realistic flickering using Godot 4.1+ Timer"""
	var base_energy = light.light_energy
	
	# Create flicker timer
	var flicker_timer = Timer.new()
	flicker_timer.wait_time = randf_range(0.1, 0.3)
	flicker_timer.one_shot = false
	flicker_timer.autostart = true
	light.add_child(flicker_timer)
	
	# Connect using Godot 4.1+ lambda syntax
	flicker_timer.timeout.connect(func():
		if not is_instance_valid(light):
			return
		var flicker_amount = randf_range(-torch_flicker_intensity, torch_flicker_intensity)
		light.light_energy = max(0.1, base_energy + flicker_amount)  # Prevent negative energy
		flicker_timer.wait_time = randf_range(0.1, 0.3)
	)

# --- ROOM LIGHTING FUNCTIONS ---
func add_room_lighting(room_rect: Rect2, map_size: Vector2 = Vector2(60, 60)) -> void:
	"""Add lighting to a standard room"""
	var room_center_world = Vector3(
		(room_rect.get_center().x - map_size.x / 2) * 2.0,
		0.0,
		(room_rect.get_center().y - map_size.y / 2) * 2.0
	)
	
	# Main ceiling torch
	create_torch_light(room_center_world + Vector3(0, 4, 0))
	
	# Add corner torches for larger rooms
	if room_rect.size.x > 6 or room_rect.size.y > 6:
		var corners = [
			room_center_world + Vector3(-room_rect.size.x * 0.8, 2.5, -room_rect.size.y * 0.8),
			room_center_world + Vector3(room_rect.size.x * 0.8, 2.5, -room_rect.size.y * 0.8),
			room_center_world + Vector3(-room_rect.size.x * 0.8, 2.5, room_rect.size.y * 0.8),
			room_center_world + Vector3(room_rect.size.x * 0.8, 2.5, room_rect.size.y * 0.8)
		]
		
		for corner in corners:
			var corner_torch = create_torch_light(corner)
			corner_torch.light_energy = torch_energy * 0.4
			corner_torch.omni_range = torch_range * 0.6
	
	if debug_mode:
		print("🕯️ Room lighting added at: ", room_center_world)

func add_weapon_room_lighting(room_rect: Rect2, map_size: Vector2 = Vector2(60, 60)) -> void:
	"""Add special magical lighting to weapon rooms"""
	var room_center_world = Vector3(
		(room_rect.get_center().x - map_size.x / 2) * 2.0,
		3.0,
		(room_rect.get_center().y - map_size.y / 2) * 2.0
	)
	
	# Central magical light
	var magic_light = OmniLight3D.new()
	magic_light.name = "WeaponRoomMagicLight"
	magic_light.light_energy = weapon_room_magic_energy
	magic_light.light_color = Color(1.0, 0.9, 0.6)  # Golden magic
	magic_light.omni_range = 12.0
	magic_light.omni_attenuation = 1.5
	magic_light.position = room_center_world
	
	special_group.add_child(magic_light)
	special_lights.append(magic_light)
	
	# Add magical pulsing using Godot 4.1+ Tween
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(magic_light, "light_energy", weapon_room_magic_energy * 0.7, 1.0)
	tween.tween_property(magic_light, "light_energy", weapon_room_magic_energy * 1.2, 1.0)
	
	# Add mystical accent lights
	for i in range(weapon_room_accent_count):
		var accent_light = OmniLight3D.new()
		accent_light.name = "WeaponRoomAccent"
		accent_light.light_energy = 0.6
		accent_light.light_color = Color(0.4, 0.6, 1.0)  # Mystical blue
		accent_light.omni_range = 6.0
		
		var angle = i * (2.0 * PI / weapon_room_accent_count)
		var radius = max(room_rect.size.x, room_rect.size.y) * 0.7
		var accent_pos = room_center_world + Vector3(
			cos(angle) * radius,
			1.5,
			sin(angle) * radius
		)
		accent_light.position = accent_pos
		
		special_group.add_child(accent_light)
		special_lights.append(accent_light)
	
	if debug_mode:
		print("✨ Weapon room lighting added with magical effects")

# --- PLAYER LIGHTING ---
func _setup_player_light() -> void:
	"""Create player lantern using Godot 4.1+ best practices"""
	if not player_node:
		if debug_mode:
			print("⚠️ Cannot setup player light - player not found")
		return
	
	player_light = OmniLight3D.new()
	player_light.name = "PlayerLantern"
	
	# Personal lantern settings
	player_light.light_color = Color(1.0, 0.8, 0.6)
	player_light.light_energy = player_light_energy
	player_light.omni_range = player_light_range
	player_light.omni_attenuation = 2.5
	
	# Position relative to player
	player_light.position = Vector3(0, 1.5, 0.5)
	
	player_node.add_child(player_light)
	
	if debug_mode:
		print("🏮 Player lantern created")

func _process(_delta: float) -> void:
	"""Update player light flickering (Godot 4.1+ _process signature)"""
	if not player_light or not is_instance_valid(player_light):
		return
		
	# Subtle lantern flicker using Time singleton (Godot 4.1+)
	var flicker = sin(Time.get_ticks_msec() * 0.008) * 0.1
	player_light.light_energy = player_light_energy + flicker

# --- SIGNAL HANDLERS ---
func _on_room_generated(room_rect: Rect2) -> void:
	"""Handle new room generation"""
	var map_size = Vector2(60, 60)  # Default
	if room_generator and "map_size" in room_generator:
		map_size = room_generator.map_size
	
	add_room_lighting(room_rect, map_size)

func _on_weapon_room_generated(room_rect: Rect2) -> void:
	"""Handle weapon room generation"""
	var map_size = Vector2(60, 60)  # Default
	if room_generator and "map_size" in room_generator:
		map_size = room_generator.map_size
	
	add_weapon_room_lighting(room_rect, map_size)

# --- UTILITY FUNCTIONS ---
func _add_lights_to_existing_rooms() -> void:
	"""Add lights to existing rooms (called after connection)"""
	if not room_generator:
		return
		
	# Get existing rooms safely
	var existing_rooms: Array = []
	if "rooms" in room_generator:
		existing_rooms = room_generator.rooms
	elif room_generator.has_method("get_rooms"):
		existing_rooms = room_generator.get_rooms()
	
	if existing_rooms.is_empty():
		return
		
	var map_size = Vector2(60, 60)
	if "map_size" in room_generator:
		map_size = room_generator.map_size
	
	if debug_mode:
		print("🔍 Adding lights to ", existing_rooms.size(), " existing rooms")
	
	for i in range(existing_rooms.size()):
		var room = existing_rooms[i]
		
		# Check if it's a weapon room
		var is_weapon_room = false
		if "room_types" in room_generator:
			var room_types = room_generator.room_types
			if i < room_types.size() and room_types[i] == 1:  # WEAPON room type
				is_weapon_room = true
		
		# Add appropriate lighting
		if is_weapon_room:
			add_weapon_room_lighting(room, map_size)
		else:
			add_room_lighting(room, map_size)

# --- CLEANUP AND UTILITY ---
func clear_all_dynamic_lights() -> void:
	"""Remove all generated lights"""
	for light in torch_lights:
		if is_instance_valid(light):
			light.queue_free()
	
	for light in special_lights:
		if is_instance_valid(light):
			light.queue_free()
	
	torch_lights.clear()
	special_lights.clear()
	
	if debug_mode:
		print("🧹 All dynamic lights cleared")

func set_ambient_brightness(brightness: float) -> void:
	"""Adjust ambient lighting"""
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_energy = brightness
		ambient_light_energy = brightness

func set_fog_density(density: float) -> void:
	"""Adjust fog thickness"""
	if world_environment and world_environment.environment:
		world_environment.environment.fog_density = density
		fog_density = density

# --- MANUAL FUNCTIONS (for debugging/testing) ---
func manually_add_torch(world_position: Vector3) -> OmniLight3D:
	"""Manually add a torch at world position"""
	return create_torch_light(world_position)

func test_lighting_near_player() -> void:
	"""Test function - add torch near player"""
	if not player_node:
		push_warning("Cannot test lighting - player not found")
		return
		
	var test_pos = player_node.global_position + Vector3(5, 2, 5)
	create_torch_light(test_pos)
	
	if debug_mode:
		print("🔥 Test torch added at: ", test_pos)

# --- DEBUG FUNCTIONS ---
func print_lighting_status() -> void:
	"""Print current lighting system status"""
	print("=== LIGHTING MANAGER STATUS ===")
	print("Initialized: ", _is_initialized)
	print("Connections made: ", _connections_made)
	print("Player found: ", player_node != null)
	print("Room generator found: ", room_generator != null)
	print("Torch lights: ", torch_lights.size())
	print("Special lights: ", special_lights.size())
	print("Player light active: ", player_light != null and is_instance_valid(player_light))
	print("===============================")
