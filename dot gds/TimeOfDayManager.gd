# TimeOfDayManager.gd
# FIXED VERSION - Works with existing dark atmospheric lighting setup
# Toggles between dark torch-only lighting and time of day lighting

extends Node3D
class_name TimeOfDayManager

# ===== SIGNALS =====
signal time_of_day_changed(new_time: String)
signal lighting_mode_changed(is_day_mode: bool)

# ===== LIGHTING REFERENCES =====
var main_light: DirectionalLight3D
var world_environment: WorldEnvironment
var original_environment: Environment  # Store original dark setup

# ===== MODE SETTINGS =====
@export var start_in_day_mode: bool = true  # Start with time of day lighting
var is_day_lighting_active: bool = false

# ===== TIME OF DAY SETTINGS =====
var current_time_index: int = 0
var time_periods: Array[Dictionary] = []

# ===== TRANSITION SETTINGS =====
@export var transition_duration: float = 2.0
@export var auto_change_enabled: bool = false
@export var auto_change_interval: float = 30.0
var auto_timer: Timer

func _ready():
	print("🌅 TimeOfDayManager initializing...")
	
	# Setup time periods
	_setup_time_periods()
	
	# Wait a bit for other systems to initialize, then setup
	await get_tree().create_timer(0.1).timeout
	
	# Store original dark lighting settings
	_store_original_lighting()
	
	# Setup lighting components with retry
	await _setup_lighting_components_with_retry()
	
	# Setup auto timer
	if auto_change_enabled:
		_setup_auto_timer()
	
	# Start in appropriate mode
	if start_in_day_mode:
		enable_time_of_day_lighting()
		set_random_time_of_day()
	else:
		disable_time_of_day_lighting()
	
	print("✅ TimeOfDayManager ready!")

# ===== SETUP FUNCTIONS =====

func _store_original_lighting():
	"""Store the original dark atmospheric lighting settings"""
	var existing_env = get_tree().get_first_node_in_group("world_environment")
	if existing_env and existing_env.environment:
		original_environment = existing_env.environment.duplicate()
		print("🌑 Stored original dark lighting settings")
	else:
		# Create default dark settings if none exist
		original_environment = Environment.new()
		original_environment.background_mode = Environment.BG_COLOR
		original_environment.background_color = Color(0.13, 0.10, 0.05)
		original_environment.ambient_light_energy = 0.13
		original_environment.ambient_light_color = Color(0.38, 0.22, 0.10)
		original_environment.glow_enabled = true
		original_environment.glow_intensity = 0.18
		original_environment.glow_strength = 0.7
		original_environment.glow_bloom = 0.5
		print("🌑 Created default dark lighting settings")

func _setup_time_periods():
	"""Define all 8 time periods with BRIGHT, visible lighting"""
	time_periods = [
		{
			"name": "Dawn",
			"sun_energy": 1.2,  # Increased from 0.3
			"sun_color": Color(1.0, 0.7, 0.5),
			"sun_rotation": Vector3(-75, 45, 0),
			"ambient_energy": 0.8,  # Increased from 0.2
			"ambient_color": Color(0.8, 0.6, 0.9),
			"sky_color": Color(0.5, 0.3, 0.7),
			"fog_enabled": true,
			"fog_density": 0.1
		},
		{
			"name": "Early Morning",
			"sun_energy": 1.5,  # Increased from 0.8
			"sun_color": Color(1.0, 0.9, 0.7),
			"sun_rotation": Vector3(-60, 60, 0),
			"ambient_energy": 1.0,  # Increased from 0.4
			"ambient_color": Color(0.9, 0.8, 1.0),
			"sky_color": Color(0.7, 0.8, 1.0),
			"fog_enabled": true,
			"fog_density": 0.05
		},
		{
			"name": "Mid Morning",
			"sun_energy": 2.0,  # Increased from 1.2
			"sun_color": Color(1.0, 1.0, 0.9),
			"sun_rotation": Vector3(-45, 75, 0),
			"ambient_energy": 1.2,  # Increased from 0.6
			"ambient_color": Color(1.0, 1.0, 1.0),
			"sky_color": Color(0.4, 0.7, 1.0),
			"fog_enabled": false,
			"fog_density": 0.0
		},
		{
			"name": "Noon",
			"sun_energy": 2.5,  # Increased from 1.5
			"sun_color": Color(1.0, 1.0, 1.0),
			"sun_rotation": Vector3(-15, 0, 0),
			"ambient_energy": 1.5,  # Increased from 0.8
			"ambient_color": Color(1.0, 1.0, 1.0),
			"sky_color": Color(0.3, 0.6, 1.0),
			"fog_enabled": false,
			"fog_density": 0.0
		},
		{
			"name": "Afternoon",
			"sun_energy": 2.2,  # Increased from 1.3
			"sun_color": Color(1.0, 0.95, 0.8),
			"sun_rotation": Vector3(-45, -75, 0),
			"ambient_energy": 1.3,  # Increased from 0.7
			"ambient_color": Color(1.0, 0.9, 0.8),
			"sky_color": Color(0.5, 0.7, 1.0),
			"fog_enabled": false,
			"fog_density": 0.0
		},
		{
			"name": "Golden Hour",
			"sun_energy": 1.8,  # Increased from 0.9
			"sun_color": Color(1.0, 0.7, 0.3),
			"sun_rotation": Vector3(-70, -60, 0),
			"ambient_energy": 1.0,  # Increased from 0.5
			"ambient_color": Color(1.0, 0.8, 0.6),
			"sky_color": Color(1.0, 0.6, 0.4),
			"fog_enabled": true,
			"fog_density": 0.03
		},
		{
			"name": "Dusk",
			"sun_energy": 1.0,  # Increased from 0.4
			"sun_color": Color(1.0, 0.5, 0.2),
			"sun_rotation": Vector3(-80, -45, 0),
			"ambient_energy": 0.8,  # Increased from 0.3
			"ambient_color": Color(0.7, 0.5, 0.8),
			"sky_color": Color(0.8, 0.3, 0.5),
			"fog_enabled": true,
			"fog_density": 0.08
		},
		{
			"name": "Night",
			"sun_energy": 0.5,  # Increased from 0.05
			"sun_color": Color(0.7, 0.8, 1.0),
			"sun_rotation": Vector3(-85, 0, 0),
			"ambient_energy": 0.6,  # Increased from 0.15
			"ambient_color": Color(0.3, 0.4, 0.8),
			"sky_color": Color(0.1, 0.1, 0.3),
			"fog_enabled": true,
			"fog_density": 0.12
		}
	]

func _setup_lighting_components():
	"""Setup lighting components (always create new ones for time of day)"""
	
	# Create DirectionalLight3D for time of day system
	if not main_light:
		main_light = DirectionalLight3D.new()
		main_light.name = "TimeOfDayLight"
		main_light.light_energy = 1.0
		main_light.visible = false  # Start hidden
		add_child(main_light)
		main_light.add_to_group("time_of_day_light")
		print("✅ Created DirectionalLight3D")
	
	# Find existing WorldEnvironment or create new one
	if not world_environment:
		world_environment = get_tree().get_first_node_in_group("world_environment")
		
		if not world_environment:
			print("🌅 Creating new WorldEnvironment...")
			world_environment = WorldEnvironment.new()
			world_environment.name = "TimeOfDayEnvironment"
			world_environment.environment = Environment.new()
			add_child(world_environment)
			world_environment.add_to_group("world_environment")
		else:
			print("✅ Found existing WorldEnvironment")
	
	print("✅ Lighting components ready!")

func _setup_lighting_components_with_retry():
	"""Setup with retry mechanism"""
	var max_attempts = 5
	var attempt = 0
	
	while attempt < max_attempts:
		_setup_lighting_components()
		
		if main_light and world_environment:
			print("✅ All lighting components found!")
			return
		
		print("⚠️ Lighting components not ready, retrying... (", attempt + 1, "/", max_attempts, ")")
		await get_tree().create_timer(0.2).timeout
		attempt += 1
	
	if not main_light or not world_environment:
		push_error("❌ Failed to setup lighting components after " + str(max_attempts) + " attempts")

func _setup_auto_timer():
	"""Setup automatic time changing"""
	auto_timer = Timer.new()
	auto_timer.wait_time = auto_change_interval
	auto_timer.one_shot = false
	auto_timer.autostart = false  # Only start when day lighting is active
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)

# ===== MAIN FUNCTIONS =====

func enable_time_of_day_lighting():
	"""Switch to time of day lighting (from dark atmospheric)"""
	if is_day_lighting_active:
		return
	
	# Check if components are ready
	if not main_light or not world_environment:
		print("⚠️ Lighting components not ready yet...")
		return
	
	print("🌅 Enabling time of day lighting...")
	is_day_lighting_active = true
	
	# Enable the directional light
	if main_light:
		main_light.visible = true
	
	# Start auto timer if enabled
	if auto_timer and auto_change_enabled:
		auto_timer.start()
	
	lighting_mode_changed.emit(true)

func disable_time_of_day_lighting():
	"""Switch back to original dark atmospheric lighting"""
	if not is_day_lighting_active:
		return
	
	print("🌑 Disabling time of day lighting...")
	is_day_lighting_active = false
	
	# Hide the directional light
	if main_light:
		main_light.visible = false
	
	# Restore original dark environment
	if world_environment and original_environment:
		world_environment.environment = original_environment.duplicate()
	
	# Stop auto timer
	if auto_timer:
		auto_timer.stop()
	
	lighting_mode_changed.emit(false)

func toggle_lighting_mode():
	"""Toggle between day and dark lighting"""
	if is_day_lighting_active:
		disable_time_of_day_lighting()
	else:
		enable_time_of_day_lighting()
		set_random_time_of_day()

func set_random_time_of_day():
	"""Set a completely random time of day"""
	if not is_day_lighting_active:
		return
	
	var random_index = randi() % time_periods.size()
	set_time_of_day(random_index)

func set_time_of_day(time_index: int):
	"""Set specific time of day by index (0-7)"""
	if not is_day_lighting_active:
		print("⚠️ Day lighting not active - enable it first!")
		return
	
	if time_index < 0 or time_index >= time_periods.size():
		push_error("❌ Invalid time index: " + str(time_index))
		return
	
	# Check if lighting components are ready
	if not main_light or not world_environment:
		push_error("❌ Lighting components not ready! Try again in a moment.")
		return
	
	current_time_index = time_index
	var time_data = time_periods[time_index]
	
	print("🌅 Changing to: ", time_data.name)
	
	# Apply lighting changes
	_apply_lighting_settings(time_data)
	
	# Emit signal
	time_of_day_changed.emit(time_data.name)

func _apply_lighting_settings(time_data: Dictionary):
	"""Apply all lighting settings for the given time period"""
	# Double-check components before applying
	if not main_light:
		push_error("❌ Missing DirectionalLight3D! Cannot apply lighting.")
		return
	
	if not world_environment:
		push_error("❌ Missing WorldEnvironment! Cannot apply lighting.")
		return
	
	if not world_environment.environment:
		push_error("❌ Missing Environment resource! Cannot apply lighting.")
		return
	
	print("🌅 Applying lighting settings for: ", time_data.name)
	
	# Create smooth transition
	var tween = create_tween()
	tween.set_parallel(true)
	
	# === DIRECTIONAL LIGHT SETTINGS ===
	tween.tween_property(main_light, "light_energy", time_data.sun_energy, transition_duration)
	tween.tween_property(main_light, "light_color", time_data.sun_color, transition_duration)
	tween.tween_property(main_light, "rotation_degrees", time_data.sun_rotation, transition_duration)
	
	# === ENVIRONMENT SETTINGS ===
	var env = world_environment.environment
	
	# Animate ambient light
	tween.tween_property(env, "ambient_light_energy", time_data.ambient_energy, transition_duration)
	tween.tween_property(env, "ambient_light_color", time_data.ambient_color, transition_duration)
	
	# Set sky background
	env.background_mode = Environment.BG_SKY
	if not env.sky:
		env.sky = Sky.new()
		env.sky.sky_material = ProceduralSkyMaterial.new()
	
	var sky_material = env.sky.sky_material as ProceduralSkyMaterial
	if sky_material:
		tween.tween_property(sky_material, "sky_top_color", time_data.sky_color, transition_duration)
		tween.tween_property(sky_material, "sky_horizon_color", time_data.sky_color.lightened(0.3), transition_duration)
	
	# Handle fog
	if time_data.fog_enabled:
		env.fog_enabled = true
		tween.tween_property(env, "fog_light_color", time_data.sun_color, transition_duration)
		tween.tween_property(env, "fog_density", time_data.fog_density, transition_duration)
	else:
		tween.tween_property(env, "fog_density", 0.0, transition_duration)
		tween.tween_callback(func(): env.fog_enabled = false).set_delay(transition_duration)

# ===== INPUT HANDLING =====

func _input(event):
	"""Handle keyboard input"""
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_L:
			print("🎲 Random time change requested!")
			if is_day_lighting_active:
				set_random_time_of_day()
			else:
				enable_time_of_day_lighting()
				set_random_time_of_day()
		
		KEY_T:
			print("🔄 Toggling lighting mode...")
			toggle_lighting_mode()
		
		KEY_1:
			_set_time_if_active(0)
		KEY_2:
			_set_time_if_active(1)
		KEY_3:
			_set_time_if_active(2)
		KEY_4:
			_set_time_if_active(3)
		KEY_5:
			_set_time_if_active(4)
		KEY_6:
			_set_time_if_active(5)
		KEY_7:
			_set_time_if_active(6)
		KEY_8:
			_set_time_if_active(7)

func _set_time_if_active(index: int):
	"""Set specific time only if day lighting is active"""
	if is_day_lighting_active:
		set_time_of_day(index)
	else:
		enable_time_of_day_lighting()
		await get_tree().create_timer(0.1).timeout
		set_time_of_day(index)

# ===== UTILITY FUNCTIONS =====

func cycle_time_forward():
	"""Go to the next time of day"""
	if not is_day_lighting_active:
		enable_time_of_day_lighting()
		return
	
	var next_index = (current_time_index + 1) % time_periods.size()
	set_time_of_day(next_index)

func cycle_time_backward():
	"""Go to the previous time of day"""
	if not is_day_lighting_active:
		enable_time_of_day_lighting()
		return
	
	var prev_index = (current_time_index - 1) % time_periods.size()
	if prev_index < 0:
		prev_index = time_periods.size() - 1
	set_time_of_day(prev_index)

func get_current_time_name() -> String:
	"""Get the name of the current time period"""
	if not is_day_lighting_active:
		return "Dark Mode"
	if current_time_index >= 0 and current_time_index < time_periods.size():
		return time_periods[current_time_index].name
	return "Unknown"

func get_lighting_status() -> String:
	"""Get current lighting status"""
	if is_day_lighting_active:
		return "Time of Day: " + get_current_time_name()
	else:
		return "Dark Atmospheric Lighting"

# ===== CALLBACKS =====

func _on_auto_timer_timeout():
	"""Auto change time of day"""
	if is_day_lighting_active:
		set_random_time_of_day()

# ===== DEBUG FUNCTIONS =====

func print_controls():
	"""Print available controls to console"""
	print("=== TIME OF DAY CONTROLS ===")
	print("L = Random time of day")
	print("T = Toggle between day/dark lighting")
	print("1-8 = Specific times of day")
	print("Current status: ", get_lighting_status())
