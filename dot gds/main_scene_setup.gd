# main_scene_setup.gd - FIXED: Prevents double spawning issue
extends Node3D

# Remove time of day system and use fixed lighting
var main_light: DirectionalLight3D
var world_environment: WorldEnvironment

func _ready():
	print("🎮 Main Scene: Starting (torch-only lighting)...")
	
	# Add LevelUpUI to scene
	var levelup_ui_scene = load("res://Scenes/LevelUpUI.gd.tscn")
	if levelup_ui_scene:
		var levelup_ui = levelup_ui_scene.instantiate()
		get_tree().current_scene.add_child(levelup_ui)
		print("✅ LevelUpUI instantiated and added to scene")
	else:
		print("❌ Could not load LevelUpUI scene!")
	
	# Instantiate enemy spawner from scene early
	var spawner_scene = load("res://Scenes/spawner.tscn")
	if spawner_scene:
		var spawner = spawner_scene.instantiate()
		spawner.name = "EnemySpawner"
		add_child(spawner)
		spawner.add_to_group("spawner")
		print("✅ Enemy spawner instantiated from Scenes/spawner.tscn")
	else:
		print("❌ Could not load Scenes/spawner.tscn!")

	# Remove any existing WorldEnvironment nodes first
	var existing_env = get_tree().get_first_node_in_group("world_environment") 
	if existing_env:
		existing_env.queue_free()
		print("🗑️ Removed conflicting WorldEnvironment")

	# --- DARK ATMOSPHERIC LIGHTING (SINGLE SOURCE) ---
	var world_env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.10, 0.05)  # Slightly warmer
	environment.ambient_light_energy = 0.13  # Brighter ambient
	environment.ambient_light_color = Color(0.38, 0.22, 0.10)  # Even warmer

	# Add subtle bloom effect for glowing torches and highlights
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.glow_strength = 0.7
	environment.glow_bloom = 0.5
	world_env.environment = environment
	add_child(world_env)

	# NO directional light - torches only!
	print("🌙 Dark atmosphere with torch-only lighting active")

	# Create systems step by step
	call_deferred("_create_simple_systems")

func _create_simple_systems():
	"""Create simple reliable systems"""
	# Step 1: Wait for existing main.tscn systems to be ready
	await get_tree().create_timer(1.0).timeout
	
	# Step 2: Create simple room generator
	var room_generator = _create_simple_room_generator()
	if not room_generator:
		print("❌ Failed to create room generator!")
		return
	
	# Step 3: Wait for spawner to initialize (no longer created here)
	await get_tree().create_timer(2.0).timeout
	
	# Step 4: Setup spawner for rooms
	var spawner = get_node_or_null("EnemySpawner")
	if spawner:
		_setup_spawner_for_rooms(spawner, room_generator)
		print("✅ Enemy spawner ready!")
	else:
		print("❌ Enemy spawner not found in scene!")
	
	await get_tree().create_timer(5.0).timeout
	_check_system_status()

func _create_simple_room_generator() -> Node3D:
	"""Create the simple room generator using separate script file"""
	var room_gen = Node3D.new()
	room_gen.name = "SimpleRoomGenerator"
	
	# Load the separate script file
	var room_script = load("res://dot gds/simple_room_generator.gd")
	if room_script:
		room_gen.script = room_script
		add_child(room_gen)
		print("✅ Simple room generator created from separate file")
		return room_gen
	else:
		print("❌ Could not load dot gds/simple_room_generator.gd!")
		return null

func _setup_spawner_for_rooms(spawner: Node3D, room_generator: Node3D):
	"""Connect spawner to room system"""
	await get_tree().create_timer(1.0).timeout
	
	print("🔗 Connecting wave system to room generator...")
	
	# ✅ FIXED: Check if signal is already connected before connecting
	if spawner.has_signal("wave_completed") and room_generator.has_method("_on_wave_completed"):
		if not spawner.wave_completed.is_connected(room_generator._on_wave_completed):
			spawner.wave_completed.connect(room_generator._on_wave_completed)
			print("✅ Connected wave_completed signal!")
		else:
			print("ℹ️ wave_completed signal already connected, skipping...")
	
	# Give spawner the starting room
	if room_generator.has_method("get_rooms"):
		var rooms = room_generator.get_rooms()
		if rooms.size() > 0:
			spawner.set_newest_spawning_room(rooms[0])
			print("🏠 Set starting room for spawner")
	
	print("✅ Wave system integration complete!")
	
	# Start the wave system
	if spawner.has_method("start_wave_system"):
		spawner.start_wave_system()
		print("🚀 Started wave progression system!")

func _check_system_status():
	var room_gen = get_node_or_null("SimpleRoomGenerator")
	var spawner = get_node_or_null("EnemySpawner")
	var player = get_tree().get_first_node_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	if not room_gen:
		print("❌ No room generator found!")
	if not spawner:
		print("❌ No spawner found!")
	if not player:
		print("❌ No player found!")
	if spawner and spawner.has_method("get_wave_info"):
		var wave_info = spawner.get_wave_info()
		var is_spawning = wave_info.get("is_spawning", false)
		var wave_active = wave_info.get("wave_active", false)
		if not is_spawning and not wave_active and enemies.size() == 0:
			print("🚨 Spawner exists but isn't working!")
	else:
		print("🚨 Spawner missing methods!")
