# TimeOfDayManager_Enhanced.gd
# ENHANCED VERSION - More visually appealing time of day system
# Adds weather, better sky, particles, and improved visual effects

extends Node3D
class_name EnhancedTimeOfDayManager

# ===== SIGNALS =====
signal time_of_day_changed(new_time: String)
signal lighting_mode_changed(is_day_mode: bool)
signal weather_changed(weather_type: String)

# ===== LIGHTING REFERENCES =====
var main_light: DirectionalLight3D
var world_environment: WorldEnvironment
var original_environment: Environment

# ===== NEW VISUAL ENHANCEMENT NODES =====
var sky_material: ProceduralSkyMaterial
var particle_system: GPUParticles3D  # For rain/snow effects
var fog_volume: FogVolume  # For localized fog effects
var god_rays_quad: MeshInstance3D  # For god ray effects

# ===== MODE SETTINGS =====
@export var start_in_day_mode: bool = true
var is_day_lighting_active: bool = false

# ===== TIME OF DAY SETTINGS =====
var current_time_index: int = 0
var time_periods: Array[Dictionary] = []

# ===== ENHANCED VISUAL SETTINGS =====
@export_group("Visual Enhancements")
@export var enable_dynamic_clouds: bool = true
@export var enable_weather_effects: bool = true
@export var enable_god_rays: bool = true
@export var enable_color_grading: bool = true
@export var cloud_speed: float = 0.02
@export var weather_chance: float = 0.3  # 30% chance of weather per time change

# ===== WEATHER SYSTEM =====
enum WeatherType { CLEAR, CLOUDY, RAIN, FOG, SNOW }
var current_weather: WeatherType = WeatherType.CLEAR
var weather_intensity: float = 0.0

# ===== TRANSITION SETTINGS =====
@export var transition_duration: float = 3.0  # Slightly longer for better effect
@export var auto_change_enabled: bool = false
@export var auto_change_interval: float = 45.0  # Longer intervals
var auto_timer: Timer

# ===== SOUND INTEGRATION =====
var ambient_audio: AudioStreamPlayer3D
var weather_audio: AudioStreamPlayer3D

func _ready():
	print("🌅 Enhanced TimeOfDayManager initializing...")
	
	# Setup enhanced time periods with more detailed settings
	_setup_enhanced_time_periods()
	
	# Wait for scene to initialize
	await get_tree().create_timer(0.1).timeout
	
	# Store original lighting
	_store_original_lighting()
	
	# Setup all lighting components
	await _setup_enhanced_lighting_components()
	
	# Setup visual enhancement systems
	_setup_visual_enhancements()
	
	# Setup audio systems
	_setup_audio_systems()
	
	# Setup auto timer
	if auto_change_enabled:
		_setup_auto_timer()
	
	# Start in appropriate mode
	if start_in_day_mode:
		enable_time_of_day_lighting()
		set_random_time_of_day()
	else:
		disable_time_of_day_lighting()
	
	print("✅ Enhanced TimeOfDayManager ready!")

func _setup_enhanced_time_periods():
	"""Setup time periods with enhanced visual data"""
	time_periods = [
		{
			"name": "Early Dawn",
			"sun_energy": 0.8,
			"sun_color": Color(1.0, 0.7, 0.5),
			"sun_rotation": Vector3(-85, 45, 0),
			"ambient_energy": 0.6,
			"ambient_color": Color(0.5, 0.6, 0.9),
			"sky_top_color": Color(0.2, 0.3, 0.6),
			"sky_horizon_color": Color(1.0, 0.5, 0.3),
			"fog_enabled": true,
			"fog_density": 0.08,
			"fog_color": Color(0.8, 0.6, 0.5),
			"cloud_coverage": 0.3,
			"wind_strength": 0.2,
			"temperature": "cool",
			"ambient_sound": "dawn_birds"
		},
		{
			"name": "Sunrise",
			"sun_energy": 1.2,
			"sun_color": Color(1.0, 0.9, 0.7),
			"sun_rotation": Vector3(-70, 60, 0),
			"ambient_energy": 0.8,
			"ambient_color": Color(0.9, 0.8, 1.0),
			"sky_top_color": Color(0.4, 0.6, 1.0),
			"sky_horizon_color": Color(1.0, 0.7, 0.4),
			"fog_enabled": true,
			"fog_density": 0.05,
			"fog_color": Color(1.0, 0.8, 0.6),
			"cloud_coverage": 0.2,
			"wind_strength": 0.3,
			"temperature": "mild",
			"ambient_sound": "morning_nature"
		},
		{
			"name": "Mid Morning",
			"sun_energy": 2.0,
			"sun_color": Color(1.0, 1.0, 0.9),
			"sun_rotation": Vector3(-45, 75, 0),
			"ambient_energy": 1.2,
			"ambient_color": Color(1.0, 1.0, 1.0),
			"sky_top_color": Color(0.3, 0.6, 1.0),
			"sky_horizon_color": Color(0.6, 0.8, 1.0),
			"fog_enabled": false,
			"fog_density": 0.0,
			"fog_color": Color.WHITE,
			"cloud_coverage": 0.4,
			"wind_strength": 0.4,
			"temperature": "warm",
			"ambient_sound": "day_activity"
		},
		{
			"name": "Noon",
			"sun_energy": 2.5,
			"sun_color": Color(1.0, 1.0, 1.0),
			"sun_rotation": Vector3(-15, 0, 0),
			"ambient_energy": 1.5,
			"ambient_color": Color(1.0, 1.0, 1.0),
			"sky_top_color": Color(0.2, 0.5, 1.0),
			"sky_horizon_color": Color(0.4, 0.7, 1.0),
			"fog_enabled": false,
			"fog_density": 0.0,
			"fog_color": Color.WHITE,
			"cloud_coverage": 0.3,
			"wind_strength": 0.5,
			"temperature": "hot",
			"ambient_sound": "midday_activity"
		},
		{
			"name": "Afternoon",
			"sun_energy": 2.2,
			"sun_color": Color(1.0, 0.95, 0.8),
			"sun_rotation": Vector3(-45, -75, 0),
			"ambient_energy": 1.3,
			"ambient_color": Color(1.0, 0.9, 0.8),
			"sky_top_color": Color(0.3, 0.6, 1.0),
			"sky_horizon_color": Color(0.8, 0.7, 0.6),
			"fog_enabled": false,
			"fog_density": 0.0,
			"fog_color": Color.WHITE,
			"cloud_coverage": 0.5,
			"wind_strength": 0.4,
			"temperature": "warm",
			"ambient_sound": "afternoon_breeze"
		},
		{
			"name": "Golden Hour",
			"sun_energy": 1.8,
			"sun_color": Color(1.0, 0.7, 0.3),
			"sun_rotation": Vector3(-70, -60, 0),
			"ambient_energy": 1.0,
			"ambient_color": Color(1.0, 0.8, 0.6),
			"sky_top_color": Color(0.5, 0.4, 0.7),
			"sky_horizon_color": Color(1.0, 0.6, 0.3),
			"fog_enabled": true,
			"fog_density": 0.03,
			"fog_color": Color(1.0, 0.7, 0.4),
			"cloud_coverage": 0.4,
			"wind_strength": 0.3,
			"temperature": "mild",
			"ambient_sound": "evening_calm"
		},
		{
			"name": "Dusk",
			"sun_energy": 1.0,
			"sun_color": Color(1.0, 0.5, 0.2),
			"sun_rotation": Vector3(-80, -45, 0),
			"ambient_energy": 0.8,
			"ambient_color": Color(0.7, 0.5, 0.8),
			"sky_top_color": Color(0.3, 0.2, 0.5),
			"sky_horizon_color": Color(0.8, 0.3, 0.4),
			"fog_enabled": true,
			"fog_density": 0.08,
			"fog_color": Color(0.8, 0.4, 0.6),
			"cloud_coverage": 0.6,
			"wind_strength": 0.2,
			"temperature": "cool",
			"ambient_sound": "evening_crickets"
		},
		{
			"name": "Night",
			"sun_energy": 0.1,  # Very dim moon light
			"sun_color": Color(0.7, 0.8, 1.0),
			"sun_rotation": Vector3(-85, 0, 0),
			"ambient_energy": 0.3,
			"ambient_color": Color(0.3, 0.4, 0.8),
			"sky_top_color": Color(0.05, 0.05, 0.2),
			"sky_horizon_color": Color(0.1, 0.1, 0.3),
			"fog_enabled": true,
			"fog_density": 0.12,
			"fog_color": Color(0.4, 0.5, 0.8),
			"cloud_coverage": 0.7,
			"wind_strength": 0.1,
			"temperature": "cold",
			"ambient_sound": "night_ambience"
		}
	]

func _setup_enhanced_lighting_components():
	"""Setup enhanced lighting components with better quality"""
	
	# Create DirectionalLight3D with enhanced settings
	if not main_light:
		main_light = DirectionalLight3D.new()
		main_light.name = "EnhancedSunLight"
		main_light.light_energy = 1.0
		main_light.visible = false
		
		# Enhanced shadow settings
		main_light.shadow_enabled = true
		main_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		main_light.directional_shadow_max_distance = 100.0
		main_light.directional_shadow_split_1 = 0.1
		main_light.directional_shadow_split_2 = 0.2
		main_light.directional_shadow_split_3 = 0.5
		main_light.directional_shadow_fade_start = 0.8
		
		add_child(main_light)
		main_light.add_to_group("enhanced_sun_light")
		print("✅ Created Enhanced DirectionalLight3D")
	
	# Find or create WorldEnvironment with enhanced settings
	if not world_environment:
		world_environment = get_tree().get_first_node_in_group("world_environment")
		
		if not world_environment:
			print("🌅 Creating enhanced WorldEnvironment...")
			world_environment = WorldEnvironment.new()
			world_environment.name = "EnhancedEnvironment"
			world_environment.environment = Environment.new()
			add_child(world_environment)
			world_environment.add_to_group("world_environment")
		
		# Setup enhanced environment settings
		var env = world_environment.environment
		
		# Enhanced sky setup
		env.background_mode = Environment.BG_SKY
		env.sky = Sky.new()
		sky_material = ProceduralSkyMaterial.new()
		env.sky.sky_material = sky_material
		
		# Better ambient occlusion
		env.ao_enabled = true
		env.ao_radius = 1.0
		env.ao_intensity = 0.3
		
		# Enhanced volumetric fog
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.05
		env.volumetric_fog_albedo = Color.WHITE
		env.volumetric_fog_length = 64.0
		
		# Screen space effects
		env.ssr_enabled = true
		env.ssr_max_steps = 64
		env.ssao_enabled = true
		env.ssil_enabled = true
		
		# Enhanced glow/bloom
		env.glow_enabled = true
		env.glow_intensity = 0.4
		env.glow_strength = 1.2
		env.glow_bloom = 0.3
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		
		print("✅ Enhanced Environment ready!")

func _setup_visual_enhancements():
	"""Setup additional visual enhancement systems"""
	
	# Setup particle system for weather effects
	if enable_weather_effects:
		particle_system = GPUParticles3D.new()
		particle_system.name = "WeatherParticles"
		particle_system.emitting = false
		particle_system.amount = 1000
		particle_system.lifetime = 5.0
		particle_system.visibility_aabb = AABB(Vector3(-50, 0, -50), Vector3(100, 50, 100))
		add_child(particle_system)
		
		# Setup rain material
		var rain_material = ParticleProcessMaterial.new()
		rain_material.direction = Vector3(0, -1, 0.1)
		rain_material.initial_velocity_min = 8.0
		rain_material.initial_velocity_max = 12.0
		rain_material.gravity = Vector3(0, -9.8, 0)
		rain_material.scale_min = 0.1
		rain_material.scale_max = 0.3
		particle_system.process_material = rain_material
		
		print("✅ Weather particle system ready!")
	
	# Setup fog volume for localized effects
	fog_volume = FogVolume.new()
	fog_volume.name = "DynamicFog"
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_volume.size = Vector3(100, 20, 100)
	fog_volume.material = FogMaterial.new()
	add_child(fog_volume)
	
	print("✅ Visual enhancements ready!")

func _setup_audio_systems():
	"""Setup ambient and weather audio"""
	
	# Ambient sound player
	ambient_audio = AudioStreamPlayer3D.new()
	ambient_audio.name = "AmbientAudio"
	ambient_audio.max_distance = 50.0
	ambient_audio.autoplay = false
	add_child(ambient_audio)
	
	# Weather sound player
	weather_audio = AudioStreamPlayer3D.new()
	weather_audio.name = "WeatherAudio"
	weather_audio.max_distance = 30.0
	weather_audio.autoplay = false
	add_child(weather_audio)
	
	print("✅ Audio systems ready!")

func _store_original_lighting():
	"""Store original environment for dark mode"""
	world_environment = get_tree().get_first_node_in_group("world_environment")
	if world_environment and world_environment.environment:
		original_environment = world_environment.environment.duplicate()
		print("✅ Original environment stored")

func enable_time_of_day_lighting():
	"""Enable enhanced time of day lighting"""
	if is_day_lighting_active:
		return
	
	print("🌅 Enabling enhanced time of day lighting...")
	is_day_lighting_active = true
	
	if main_light:
		main_light.visible = true
	
	# Start auto timer if enabled
	if auto_timer and auto_change_enabled:
		auto_timer.start()
	
	lighting_mode_changed.emit(true)

func disable_time_of_day_lighting():
	"""Disable and return to dark mode"""
	if not is_day_lighting_active:
		return
	
	print("🌑 Disabling enhanced time of day lighting...")
	is_day_lighting_active = false
	
	if main_light:
		main_light.visible = false
	
	# Stop weather effects
	_stop_weather_effects()
	
	# Restore original environment
	if world_environment and original_environment:
		world_environment.environment = original_environment.duplicate()
	
	if auto_timer:
		auto_timer.stop()
	
	lighting_mode_changed.emit(false)

func set_time_of_day(time_index: int):
	"""Set specific time with enhanced effects"""
	if not is_day_lighting_active:
		print("⚠️ Enhanced day lighting not active!")
		return
	
	if time_index < 0 or time_index >= time_periods.size():
		push_error("❌ Invalid time index: " + str(time_index))
		return
	
	if not main_light or not world_environment:
		push_error("❌ Enhanced lighting components not ready!")
		return
	
	current_time_index = time_index
	var time_data = time_periods[time_index]
	
	print("🌅 Enhanced transition to: ", time_data.name)
	
	# Maybe add weather
	if enable_weather_effects and randf() < weather_chance:
		_add_random_weather(time_data)
	else:
		_set_clear_weather()
	
	# Apply all enhanced settings
	_apply_enhanced_lighting(time_data)
	_apply_weather_effects(time_data)
	_apply_audio_effects(time_data)
	
	time_of_day_changed.emit(time_data.name)

func _apply_enhanced_lighting(time_data: Dictionary):
	"""Apply enhanced lighting with better transitions"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Enhanced sun lighting
	tween.tween_property(main_light, "light_energy", time_data.sun_energy, transition_duration)
	tween.tween_property(main_light, "light_color", time_data.sun_color, transition_duration)
	tween.tween_property(main_light, "rotation_degrees", time_data.sun_rotation, transition_duration)
	
	var env = world_environment.environment
	
	# Enhanced ambient lighting
	tween.tween_property(env, "ambient_light_energy", time_data.ambient_energy, transition_duration)
	tween.tween_property(env, "ambient_light_color", time_data.ambient_color, transition_duration)
	
	# Enhanced sky with better colors
	if sky_material:
		tween.tween_property(sky_material, "sky_top_color", time_data.sky_top_color, transition_duration)
		tween.tween_property(sky_material, "sky_horizon_color", time_data.sky_horizon_color, transition_duration)
		tween.tween_property(sky_material, "ground_bottom_color", time_data.sky_top_color.darkened(0.5), transition_duration)
		
		# Animate clouds if enabled
		if enable_dynamic_clouds:
			tween.tween_property(sky_material, "sky_cover", time_data.cloud_coverage, transition_duration)
			sky_material.sky_cover_modulate = Color.WHITE.lerp(Color.GRAY, time_data.cloud_coverage)
	
	# Enhanced fog effects
	if time_data.fog_enabled:
		env.fog_enabled = true
		tween.tween_property(env, "fog_light_color", time_data.fog_color, transition_duration)
		tween.tween_property(env, "fog_density", time_data.fog_density, transition_duration)
		
		# Volumetric fog
		if env.volumetric_fog_enabled:
			tween.tween_property(env, "volumetric_fog_density", time_data.fog_density * 0.5, transition_duration)
	else:
		tween.tween_property(env, "fog_density", 0.0, transition_duration)
		tween.tween_property(env, "volumetric_fog_density", 0.0, transition_duration)
		tween.tween_callback(func(): env.fog_enabled = false).set_delay(transition_duration)

func _apply_weather_effects(time_data: Dictionary):
	"""Apply weather particle effects"""
	if not enable_weather_effects or not particle_system:
		return
	
	match current_weather:
		WeatherType.RAIN:
			_setup_rain_particles()
			particle_system.emitting = true
		WeatherType.SNOW:
			_setup_snow_particles()
			particle_system.emitting = true
		WeatherType.FOG:
			if fog_volume:
				fog_volume.material.density = 0.8
				fog_volume.material.albedo = time_data.fog_color
		_:
			particle_system.emitting = false
			if fog_volume:
				fog_volume.material.density = 0.0

func _setup_rain_particles():
	"""Configure particles for rain"""
	if not particle_system.process_material:
		return
	
	var rain_mat = particle_system.process_material as ParticleProcessMaterial
	rain_mat.direction = Vector3(0, -1, 0.2)
	rain_mat.initial_velocity_min = 15.0
	rain_mat.initial_velocity_max = 25.0
	rain_mat.scale_min = 0.05
	rain_mat.scale_max = 0.1

func _setup_snow_particles():
	"""Configure particles for snow"""
	if not particle_system.process_material:
		return
	
	var snow_mat = particle_system.process_material as ParticleProcessMaterial
	snow_mat.direction = Vector3(0, -1, 0)
	snow_mat.initial_velocity_min = 2.0
	snow_mat.initial_velocity_max = 5.0
	snow_mat.scale_min = 0.2
	snow_mat.scale_max = 0.5

func _apply_audio_effects(time_data: Dictionary):
	"""Apply ambient audio for the time period"""
	if not ambient_audio:
		return
	
	# Note: You'll need to add actual audio files to your project
	# For now, this shows the structure
	var _audio_file = "res://audio/ambient/" + time_data.ambient_sound + ".ogg"
	
	# In a real implementation, you'd load and play the audio:
	# var stream = load(audio_file) as AudioStream
	# if stream:
	#     ambient_audio.stream = stream
	#     ambient_audio.play()

func _add_random_weather(time_data: Dictionary):
	"""Add random weather appropriate for the time"""
	var possible_weather = []
	
	# Different weather types based on time and temperature
	match time_data.temperature:
		"cold":
			possible_weather = [WeatherType.FOG, WeatherType.SNOW]
		"cool":
			possible_weather = [WeatherType.FOG, WeatherType.CLOUDY]
		"mild":
			possible_weather = [WeatherType.CLOUDY, WeatherType.RAIN]
		"warm", "hot":
			possible_weather = [WeatherType.CLOUDY]
	
	if possible_weather.size() > 0:
		current_weather = possible_weather[randi() % possible_weather.size()]
		weather_intensity = randf_range(0.3, 0.8)
		print("🌧️ Adding weather: ", WeatherType.keys()[current_weather])
		weather_changed.emit(WeatherType.keys()[current_weather])

func _set_clear_weather():
	"""Set clear weather"""
	current_weather = WeatherType.CLEAR
	weather_intensity = 0.0

func _stop_weather_effects():
	"""Stop all weather effects"""
	if particle_system:
		particle_system.emitting = false
	if fog_volume:
		fog_volume.material.density = 0.0
	_set_clear_weather()

func toggle_lighting_mode():
	"""Toggle between enhanced day and dark lighting"""
	if is_day_lighting_active:
		disable_time_of_day_lighting()
	else:
		enable_time_of_day_lighting()
		set_random_time_of_day()

func set_random_time_of_day():
	"""Set random time with enhanced effects"""
	if not is_day_lighting_active:
		return
	
	var random_index = randi() % time_periods.size()
	set_time_of_day(random_index)

func _setup_auto_timer():
	"""Setup automatic time changing"""
	auto_timer = Timer.new()
	auto_timer.wait_time = auto_change_interval
	auto_timer.one_shot = false
	auto_timer.autostart = false
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)

func _on_auto_timer_timeout():
	"""Auto change time with weather chances"""
	if is_day_lighting_active:
		set_random_time_of_day()

# Update the cloud animation continuously
func _process(_delta):
	if enable_dynamic_clouds and sky_material and is_day_lighting_active:
		# Animate cloud movement
		var time = Time.get_unix_time_from_system()
		sky_material.sky_curve = sin(time * cloud_speed) * 0.1 + 0.5

# ===== INPUT HANDLING (Same as before but with enhanced feedback) =====
func _input(event):
	"""Enhanced input handling with better feedback"""
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_L:
			print("🎲 Enhanced random time change!")
			if is_day_lighting_active:
				set_random_time_of_day()
			else:
				enable_time_of_day_lighting()
				set_random_time_of_day()
		
		KEY_T:
			print("🔄 Enhanced lighting mode toggle...")
			toggle_lighting_mode()
		
		KEY_W:  # New: Force weather toggle
			if is_day_lighting_active:
				if current_weather == WeatherType.CLEAR:
					_add_random_weather(time_periods[current_time_index])
				else:
					_stop_weather_effects()
					print("☀️ Weather cleared")
		
		KEY_1: _set_time_if_active(0)
		KEY_2: _set_time_if_active(1)
		KEY_3: _set_time_if_active(2)
		KEY_4: _set_time_if_active(3)
		KEY_5: _set_time_if_active(4)
		KEY_6: _set_time_if_active(5)
		KEY_7: _set_time_if_active(6)
		KEY_8: _set_time_if_active(7)

func _set_time_if_active(index: int):
	"""Set specific time with enhanced effects"""
	if is_day_lighting_active:
		set_time_of_day(index)
	else:
		enable_time_of_day_lighting()
		await get_tree().create_timer(0.1).timeout
		set_time_of_day(index)

# ===== UTILITY FUNCTIONS =====
func get_current_time_name() -> String:
	"""Get current time name with weather info"""
	if not is_day_lighting_active:
		return "Dark Mode"
	
	var time_name = "Unknown"
	if current_time_index >= 0 and current_time_index < time_periods.size():
		time_name = time_periods[current_time_index].name
	
	if current_weather != WeatherType.CLEAR:
		time_name += " (" + WeatherType.keys()[current_weather] + ")"
	
	return time_name

func get_lighting_status() -> String:
	"""Get detailed lighting status"""
	if is_day_lighting_active:
		return "Enhanced Time of Day: " + get_current_time_name()
	else:
		return "Dark Atmospheric Lighting"

func print_enhanced_controls():
	"""Print enhanced control instructions"""
	print("=== ENHANCED TIME OF DAY CONTROLS ===")
	print("L = Random time of day")
	print("T = Toggle enhanced/dark lighting")
	print("W = Toggle weather effects")
	print("1-8 = Specific times of day")
	print("Current status: ", get_lighting_status())

# ===== DEBUG FUNCTIONS =====
func get_performance_info() -> Dictionary:
	"""Get performance information for debugging"""
	return {
		"active_particles": particle_system.emitting if particle_system else false,
		"fog_enabled": world_environment.environment.fog_enabled if world_environment else false,
		"volumetric_fog": world_environment.environment.volumetric_fog_enabled if world_environment else false,
		"current_weather": WeatherType.keys()[current_weather],
		"weather_intensity": weather_intensity
	}
