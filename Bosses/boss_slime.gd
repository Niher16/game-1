# boss_slime.gd - Epic Boss Fight for Wave 10
# Extends your existing enemy.gd but adds boss-specific mechanics
extends "res://dot gds/enemy.gd"

signal boss_defeated
signal boss_charge_attack_started
signal boss_landed
signal wall_broken_by_boss(grid_x: int, grid_y: int)

# Boss-specific stats (much stronger than regular slimes)
@export var boss_max_health: int = 200
@export var boss_attack_damage: int = 15
@export var boss_speed: float = 1.5  # Slower but more deliberate
@export var boss_size_multiplier: float = 2.5

# Landing/Entry mechanics
var is_landing: bool = false
var landing_target: Vector3
var landing_start_pos: Vector3
var landing_timer: float = 0.0
var landing_duration: float = 2.0
var has_landed: bool = false
var landing_shockwave_radius: float = 6.0

# Charge attack mechanics
var is_charging: bool = false
var charge_target: Vector3
var charge_start_pos: Vector3
var charge_timer: float = 0.0
var charge_duration: float = 1.5
var charge_telegraph_duration: float = 1.0
var charge_cooldown: float = 8.0
var last_charge_time: float = 0.0
var charge_indicator: MeshInstance3D
var charge_speed: float = 12.0

# Spawning mechanics
var slimes_to_spawn: int = 0
var spawn_delay_timer: float = 0.0
var spawn_delay_interval: float = 0.3

# Boss phases
enum BossPhase { ENTERING, NORMAL, SPECIAL_ATTACK, DEFEATED }
var current_phase: BossPhase = BossPhase.ENTERING

# Visual enhancements
var boss_material: StandardMaterial3D
var boss_original_color: Color = Color(0.8, 0.2, 0.2, 0.95)  # Dark red boss color
var boss_charge_color: Color = Color(1.0, 0.3, 0.1, 1.0)    # Bright red when charging

# Scene references
var terrain_generator: Node3D
var regular_slime_scene: PackedScene

func _ready():
	print("👹 BOSS SLIME: Initializing epic boss fight...")
	_initialize_boss()
	super._ready()  # Call parent ready

func _initialize_boss():
	"""Initialize boss when script is dynamically attached"""
	print("👹 BOSS: Starting manual initialization...")
	
	# Ensure we have player reference (critical for landing position)
	if not player:
		player = get_tree().get_first_node_in_group("player")
		print("👹 BOSS: Found player = ", player)
	
	# Load regular slime scene for spawning
	regular_slime_scene = load("res://Scenes/enemy.tscn")
	
	# Override base enemy stats with boss stats
	max_health = boss_max_health
	health = boss_max_health
	attack_damage = boss_attack_damage
	speed = boss_speed
	
	# Make boss much larger
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * boss_size_multiplier
		base_scale = mesh_instance.scale
		slime_scale = base_scale
		print("👹 BOSS: Scaled to ", mesh_instance.scale)
	
	# Setup boss-specific visuals
	_setup_boss_material()
	_create_charge_indicator()
	
	# Find terrain generator for wall breaking
	terrain_generator = get_tree().get_first_node_in_group("terrain")
	
	# Start dramatic entry sequence
	call_deferred("_start_boss_entry")

func _setup_boss_material():
	"""Create special boss material"""
	boss_material = StandardMaterial3D.new()
	boss_material.albedo_color = boss_original_color
	boss_material.metallic = 0.2
	boss_material.roughness = 0.4
	boss_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boss_material.emission_enabled = true
	boss_material.emission = boss_original_color * 0.3
	
	if mesh_instance:
		mesh_instance.material_override = boss_material

func _create_charge_indicator():
	"""Create visual indicator for charge attacks"""
	charge_indicator = MeshInstance3D.new()
	charge_indicator.name = "ChargeIndicator"
	
	# Create a cylinder mesh for the charge indicator (FIX: Use top_radius and bottom_radius)
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.1
	charge_indicator.mesh = cylinder
	
	# Create warning material
	var indicator_material = StandardMaterial3D.new()
	indicator_material.albedo_color = Color(1.0, 1.0, 0.0, 0.7)  # Yellow warning
	indicator_material.emission_enabled = true
	indicator_material.emission = Color(1.0, 0.8, 0.0) * 2.0
	indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	charge_indicator.material_override = indicator_material
	
	add_child(charge_indicator)
	charge_indicator.visible = false

func _start_boss_entry():
	"""Start the dramatic boss entry sequence"""
	print("👹 BOSS ENTRY: Starting dramatic leap into arena!")
	print("👹 BOSS: Player position = ", player.global_position if player else "NO PLAYER")
	
	current_phase = BossPhase.ENTERING
	is_landing = true
	enabled = false  # Disable normal AI during entry
	
	# Find a safe landing spot near player (but not too close)
	var safe_distance = randf_range(4.0, 7.0)
	var angle = randf() * TAU
	var player_pos = player.global_position if player else Vector3.ZERO
	landing_target = player_pos + Vector3(
		cos(angle) * safe_distance,
		0.0,
		sin(angle) * safe_distance
	)
	
	# Start high in the air
	landing_start_pos = landing_target + Vector3(0, 20.0, 0)
	global_position = landing_start_pos
	
	print("👹 BOSS: Landing target = ", landing_target)
	print("👹 BOSS: Starting position = ", landing_start_pos)
	print("👹 BOSS: Current position = ", global_position)
	print("👹 BOSS: is_landing = ", is_landing)

func _physics_process(delta):
	if is_landing:
		print("👹 BOSS: In landing state")
		_handle_boss_landing(delta)
	elif is_charging:
		print("👹 BOSS: In charging state")
		_handle_charge_attack(delta)
	elif slimes_to_spawn > 0:
		print("👹 BOSS: Spawning slimes")
		_handle_slime_spawning(delta)
	else:
		# Only run normal enemy behavior if not in special states
		if has_landed and current_phase != BossPhase.DEFEATED:
			_boss_ai_behavior(delta)
			super._physics_process(delta)

func _handle_boss_landing(delta):
	"""Handle the dramatic landing sequence"""
	landing_timer += delta
	var progress = landing_timer / landing_duration
	
	print("👹 BOSS LANDING: Progress = ", progress, " Position = ", global_position)
	
	if progress >= 1.0:
		# IMPACT!
		global_position = landing_target
		_create_landing_impact()
		is_landing = false
		has_landed = true
		enabled = true
		current_phase = BossPhase.NORMAL
		boss_landed.emit()
		print("👹 BOSS LANDED: Starting boss fight!")
	else:
		# Smooth landing animation with easing
		var eased_progress = smoothstep(0.0, 1.0, progress)
		global_position = landing_start_pos.lerp(landing_target, eased_progress)
		print("👹 BOSS: Falling... ", global_position.y)

func _create_landing_impact():
	"""Create shockwave and break walls on landing"""
	print("💥 BOSS IMPACT: Creating shockwave and breaking walls!")
	
	# Break walls in radius around landing point
	_break_walls_in_radius(global_position, landing_shockwave_radius)
	
	# Create visual shockwave effect
	_spawn_shockwave_effect()
	
	# Camera shake effect (if you have one)
	if get_tree().has_group("camera"):
		var camera = get_tree().get_first_node_in_group("camera")
		if camera.has_method("add_trauma"):
			camera.add_trauma(0.8)

func _break_walls_in_radius(center: Vector3, radius: float):
	"""Break walls in a circular radius"""
	if not terrain_generator:
		print("⚠️ No terrain generator found for wall breaking!")
		return
	
	var map_size = terrain_generator.map_size if "map_size" in terrain_generator else Vector2(60, 60)
	var walls_broken = 0
	
	# Convert world position to grid coordinates
	var center_grid_x = int((center.x / 2.0) + (map_size.x / 2))
	var center_grid_y = int((center.z / 2.0) + (map_size.y / 2))
	
	# Check all positions in radius
	var grid_radius = int(radius / 2.0) + 1
	for x in range(center_grid_x - grid_radius, center_grid_x + grid_radius + 1):
		for y in range(center_grid_y - grid_radius, center_grid_y + grid_radius + 1):
			# Check if position is within radius
			var world_pos = Vector3(
				(x - map_size.x / 2) * 2.0,
				0,
				(y - map_size.y / 2) * 2.0
			)
			
			if center.distance_to(world_pos) <= radius:
				if _break_wall_at_grid(x, y):
					walls_broken += 1
	
	print("💥 BOSS LANDING: Broke ", walls_broken, " walls!")

func _break_wall_at_grid(grid_x: int, grid_y: int) -> bool:
	"""Break a wall at specific grid coordinates"""
	if not terrain_generator:
		return false
	
	# Check if position is valid and has a wall
	if not terrain_generator.has_method("_is_valid_grid_pos"):
		return false
	
	var map_size = terrain_generator.map_size if "map_size" in terrain_generator else Vector2(60, 60)
	if grid_x < 0 or grid_x >= map_size.x or grid_y < 0 or grid_y >= map_size.y:
		return false
	
	# Check if this is a boundary wall (protected)
	var grid_key = str(grid_x) + "," + str(grid_y)
	if "boundary_walls" in terrain_generator and terrain_generator.boundary_walls.has(grid_key):
		return false  # Never break boundary walls
	
	# Check if there's a wall here
	if "terrain_grid" in terrain_generator:
		var terrain_grid = terrain_generator.terrain_grid
		if terrain_grid[grid_x][grid_y] == 0:  # TileType.WALL = 0
			# Change to floor and remove wall object
			terrain_grid[grid_x][grid_y] = 1  # TileType.FLOOR = 1
			
			# Remove wall object if it exists
			if "wall_lookup" in terrain_generator:
				var wall_lookup = terrain_generator.wall_lookup
				if wall_lookup.has(grid_key):
					var wall = wall_lookup[grid_key]
					if is_instance_valid(wall):
						wall.queue_free()
					wall_lookup.erase(grid_key)
			
			wall_broken_by_boss.emit(grid_x, grid_y)
			return true
	
	return false

func _spawn_shockwave_effect():
	"""Create visual shockwave effect"""
	# Create expanding ring effect
	var shockwave = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.1
	ring_mesh.outer_radius = 1.0
	shockwave.mesh = ring_mesh
	
	# Shockwave material
	var shockwave_material = StandardMaterial3D.new()
	shockwave_material.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
	shockwave_material.emission_enabled = true
	shockwave_material.emission = Color(1.0, 0.3, 0.0) * 3.0
	shockwave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.material_override = shockwave_material
	
	get_parent().add_child(shockwave)
	shockwave.global_position = global_position + Vector3(0, 0.1, 0)
	
	# Animate shockwave expanding and fading
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector3.ONE * landing_shockwave_radius, 1.0)
	tween.tween_property(shockwave_material, "albedo_color", Color(1.0, 0.5, 0.0, 0.0), 1.0)
	tween.tween_callback(shockwave.queue_free).set_delay(1.0)

func _boss_ai_behavior(delta):
	"""Enhanced AI behavior for boss"""
	if current_phase == BossPhase.DEFEATED:
		return
	
	var time = Time.get_ticks_msec() / 1000.0
	
	# Check if we should do a special charge attack
	if current_phase == BossPhase.NORMAL and time - last_charge_time > charge_cooldown:
		if randf() < 0.3:  # 30% chance to charge attack
			_start_charge_attack()
			return
	
	# Normal boss behavior (enhanced slime AI)
	# Boss is more aggressive and has longer attack range
	if _is_player_valid():
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player < attack_range * 1.5:  # Boss has longer range
			# Enhanced attack pattern
			if time - last_attack_time > attack_cooldown * 0.7:  # Boss attacks faster
				_boss_attack()

func _start_charge_attack():
	"""Start the special charge attack"""
	print("👹 BOSS CHARGE: Starting special charge attack!")
	
	current_phase = BossPhase.SPECIAL_ATTACK
	is_telegraphing = true
	telegraph_timer = 0.0
	
	# Set charge target to player position
	charge_target = player.global_position
	charge_start_pos = global_position
	
	# Show charge indicator
	if charge_indicator:
		charge_indicator.visible = true
		charge_indicator.global_position = charge_target + Vector3(0, 0.1, 0)
		
		# Scale indicator to show impact area
		charge_indicator.scale = Vector3(3.0, 1.0, 3.0)
	
	# Change boss color during telegraph
	if boss_material:
		var tween = create_tween()
		tween.tween_property(boss_material, "albedo_color", boss_charge_color, charge_telegraph_duration)
	
	boss_charge_attack_started.emit()

func _handle_charge_attack(delta):
	"""Handle the charge attack sequence"""
	if is_telegraphing:
		telegraph_timer += delta
		
		# Pulsing indicator effect
		if charge_indicator:
			var pulse = 1.0 + sin(telegraph_timer * 10.0) * 0.2
			charge_indicator.scale = Vector3(3.0 * pulse, 1.0, 3.0 * pulse)
		
		if telegraph_timer >= charge_telegraph_duration:
			# Start actual charge
			is_telegraphing = false
			is_charging = true
			charge_timer = 0.0
			charge_indicator.visible = false
			print("👹 BOSS: CHARGE ATTACK EXECUTING!")
	
	elif is_charging:
		charge_timer += delta
		var progress = charge_timer / charge_duration
		
		if progress >= 1.0:
			# Charge finished - check for wall collision
			_handle_charge_impact()
			is_charging = false
			current_phase = BossPhase.NORMAL
			last_charge_time = Time.get_ticks_msec() / 1000.0
			
			# Reset boss color
			if boss_material:
				var tween = create_tween()
				tween.tween_property(boss_material, "albedo_color", boss_original_color, 0.5)
		else:
			# Move boss during charge with easing
			var eased_progress = smoothstep(0.0, 1.0, progress)
			global_position = charge_start_pos.lerp(charge_target, eased_progress)

func _handle_charge_impact():
	"""Handle what happens when charge attack hits something"""
	print("💥 BOSS CHARGE IMPACT!")
	
	# Check if we hit any walls
	var hit_wall = _check_charge_wall_collision()
	
	if hit_wall:
		print("👹 BOSS: Charge hit wall! Breaking walls and spawning slimes!")
		
		# Break walls around impact point
		_break_walls_in_radius(global_position, 3.0)
		
		# Spawn 1-5 regular slimes
		slimes_to_spawn = randi_range(1, 5)
		spawn_delay_timer = 0.0
		
		# Visual impact effect
		_spawn_charge_impact_effect()

func _check_charge_wall_collision() -> bool:
	"""Check if charge attack hit a wall"""
	if not terrain_generator:
		return false
	
	var map_size = terrain_generator.map_size if "map_size" in terrain_generator else Vector2(60, 60)
	var grid_x = int((global_position.x / 2.0) + (map_size.x / 2))
	var grid_y = int((global_position.z / 2.0) + (map_size.y / 2))
	
	# Check nearby positions for walls
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var check_x = grid_x + x_offset
			var check_y = grid_y + y_offset
			
			if "terrain_grid" in terrain_generator:
				var terrain_grid = terrain_generator.terrain_grid
				if check_x >= 0 and check_x < map_size.x and check_y >= 0 and check_y < map_size.y:
					if terrain_grid[check_x][check_y] == 0:  # TileType.WALL
						return true
	
	return false

func _spawn_charge_impact_effect():
	"""Create visual effect for charge impact"""
	# Similar to landing effect but smaller
	var impact = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	impact.mesh = sphere_mesh
	
	var impact_material = StandardMaterial3D.new()
	impact_material.albedo_color = Color(1.0, 0.3, 0.1, 0.8)
	impact_material.emission_enabled = true
	impact_material.emission = Color(1.0, 0.5, 0.0) * 4.0
	impact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impact.material_override = impact_material
	
	get_parent().add_child(impact)
	impact.global_position = global_position
	
	# Animate impact effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector3.ONE * 5.0, 0.5)
	tween.tween_property(impact_material, "albedo_color", Color(1.0, 0.3, 0.1, 0.0), 0.5)
	tween.tween_callback(impact.queue_free).set_delay(0.5)

func _handle_slime_spawning(delta):
	"""Handle spawning regular slimes after charge impact"""
	spawn_delay_timer += delta
	
	if spawn_delay_timer >= spawn_delay_interval and slimes_to_spawn > 0:
		_spawn_regular_slime()
		slimes_to_spawn -= 1
		spawn_delay_timer = 0.0

func _spawn_regular_slime():
	"""Spawn a regular slime near the boss"""
	if not regular_slime_scene:
		print("⚠️ No regular slime scene to spawn!")
		return
	
	var slime = regular_slime_scene.instantiate()
	get_parent().add_child(slime)
	
	# Position randomly around boss
	var angle = randf() * TAU
	var distance = randf_range(2.0, 4.0)
	var spawn_pos = global_position + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	slime.global_position = spawn_pos
	
	print("👹 BOSS: Spawned reinforcement slime at ", spawn_pos)

func _boss_attack():
	"""Enhanced boss attack"""
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Boss does more damage and has special effects
	if _is_player_valid():
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range * 1.5:
			print("👹 BOSS ATTACK: Dealing ", attack_damage, " damage!")
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
			
			# Special boss attack effect
			_spawn_boss_attack_effect()

func _spawn_boss_attack_effect():
	"""Create special attack effect for boss"""
	var effect = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 2.0
	effect.mesh = ring_mesh
	
	var effect_material = StandardMaterial3D.new()
	effect_material.albedo_color = Color(0.8, 0.2, 0.2, 0.9)
	effect_material.emission_enabled = true
	effect_material.emission = Color(1.0, 0.1, 0.1) * 2.0
	effect_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect.material_override = effect_material
	
	get_parent().add_child(effect)
	effect.global_position = global_position + Vector3(0, 0.5, 0)
	
	# Animate attack effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * 3.0, 0.3)
	tween.tween_property(effect_material, "albedo_color", Color(0.8, 0.2, 0.2, 0.0), 0.3)
	tween.tween_callback(effect.queue_free).set_delay(0.3)

func take_damage(amount: int, _attacker = null):
	"""Override take_damage to add boss-specific behavior"""
	super.take_damage(amount)  # Parent only takes 1 argument
	
	# Boss-specific damage reactions
	if health > 0:
		# Flash red when damaged
		if boss_material:
			var flash_tween = create_tween()
			flash_tween.tween_property(boss_material, "emission", Color(1.0, 0.0, 0.0) * 2.0, 0.1)
			flash_tween.tween_property(boss_material, "emission", boss_original_color * 0.3, 0.2)
		
		# Chance to trigger charge attack when damaged
		if randf() < 0.2 and current_phase == BossPhase.NORMAL:  # 20% chance
			var time = Time.get_ticks_msec() / 1000.0
			if time - last_charge_time > charge_cooldown * 0.5:  # Reduced cooldown when damaged
				_start_charge_attack()

func die():
	"""Override die to add boss defeat behavior"""
	print("👹 BOSS DEFEATED: Epic victory!")
	
	current_phase = BossPhase.DEFEATED
	is_charging = false
	is_telegraphing = false
	
	if charge_indicator:
		charge_indicator.visible = false
	
	# Epic death effect
	_spawn_boss_death_effect()
	
	# Emit boss defeated signal
	boss_defeated.emit()
	
	# Call parent die with delay for effect
	var death_timer = Timer.new()
	death_timer.wait_time = 2.0
	death_timer.one_shot = true
	add_child(death_timer)
	death_timer.timeout.connect(func(): super.die())
	death_timer.start()

func _spawn_boss_death_effect():
	"""Create epic death effect for boss"""
	# Multiple expanding rings
	for i in range(3):
		var ring = MeshInstance3D.new()
		var ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = 1.0
		ring_mesh.outer_radius = 2.0
		ring.mesh = ring_mesh
		
		var ring_material = StandardMaterial3D.new()
		ring_material.albedo_color = Color(1.0, 0.0, 0.0, 0.8)
		ring_material.emission_enabled = true
		ring_material.emission = Color(1.0, 0.2, 0.0) * 5.0
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = ring_material
		
		get_parent().add_child(ring)
		ring.global_position = global_position + Vector3(0, i * 0.5, 0)
		
		# Animate each ring with different timing
		var tween = create_tween()
		tween.set_parallel(true)
		var delay = i * 0.3
		tween.tween_property(ring, "scale", Vector3.ONE * 8.0, 1.5).set_delay(delay)
		tween.tween_property(ring_material, "albedo_color", Color(1.0, 0.0, 0.0, 0.0), 1.5).set_delay(delay)
		tween.tween_callback(ring.queue_free).set_delay(1.5 + delay)
