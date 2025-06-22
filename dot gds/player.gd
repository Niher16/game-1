extends CharacterBody3D

# --- Inspector Properties ---
@export_group("Movement")
@export var speed := 5.0
@export var dash_distance := 4.0
@export var dash_duration := 0.3
@export var dash_cooldown := 5.0

@export_group("Combat")
@export var attack_range := 2.0
@export var attack_damage := 10
@export var attack_cooldown := 1.0
@export var attack_cone_angle := 90.0

@export_group("Health")
@export var health_regen_rate := 2.0
@export var health_regen_delay := 3.0

@export_group("Knockback")
@export var knockback_force := 12.0
@export var knockback_duration := 0.6

@export_group("Dash")
@export var max_dash_charges := 1

@export_group("Experience")

@export_group("Animation")
@export var body_lean_strength: float = 0.15
@export var body_sway_strength: float = 0.50
@export var hand_swing_strength: float = 1.0
@export var foot_step_strength: float = 0.10
@export var side_step_modifier: float = 0.4

# --- Node References (using @onready for caching) ---
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D

@onready var movement_component: PlayerMovement = $PlayerMovement
@onready var combat_component: PlayerCombat = $CombatComponent
@onready var health_component = $HealthComponent
@onready var progression_component = $ProgressionComponent
@onready var inventory_component: PlayerInventoryComponent = get_node_or_null("InventoryComponent")
@onready var stats_component: PlayerStats = get_node_or_null("PlayerStats")
@onready var ui = get_tree().get_root().find_child("HealthUI", true, false)
@onready var ally_command_manager = preload("res://allies/components/AllyCommandManager.gd").new()

# Player state
var is_dead := false
var nearby_weapon_pickup = null
@onready var death_timer: Timer

# --- Health System Component ---
# Removed duplicate declaration of health_component

# Mouse look system
var camera: Camera3D = null
var mouse_position_3d: Vector3

# Visual components
var mesh_instance: MeshInstance3D

# --- FEET ANIMATION SYSTEM ---
var left_foot_original_pos: Vector3
var right_foot_original_pos: Vector3
var left_foot_planted_pos: Vector3
var right_foot_planted_pos: Vector3
var left_foot_is_moving := false
var right_foot_is_moving := false
var left_foot_step_progress := 1.0
var right_foot_step_progress := 1.0

# Visual effects
# var invulnerability_timer := 0.0
# const INVULNERABILITY_DURATION := 0.5

# Node references (cached in _ready)
var attack_area: Area3D

# Constants
const FRICTION_MULTIPLIER := 3.0
const MOVEMENT_THRESHOLD := 0.1

# Signals
signal dash_charges_changed(current_charges: int, max_charges: int)

# --- Eye Blinking System ---
var blink_timer := 0.0
var blink_interval := 0.0
const BLINK_MIN_INTERVAL := 2.0
const BLINK_MAX_INTERVAL := 6.0
const BLINK_DURATION := 0.12
var is_blinking := false
var next_blink_time := 0.0

func _on_dash_charges_changed(current_charges: int, max_charges: int):
	dash_charges_changed.emit(current_charges, max_charges)  # Re-emit for UI

func _ready():
	# --- Safety checks for required components (Godot 4.1+ best practice) ---
	if not health_component:
		push_error("❌ HealthComponent not found! Player won't work properly.")
		return
	if not movement_component:
		push_warning("⚠️ MovementComponent not found! Movement may not work.")

	# Setup health component ONCE
	if health_component:
		health_component.setup(self, 100)
		print("🔧 Health component initialized")

	# Initialize other components...
	if movement_component and movement_component.has_method("initialize"):
		movement_component.initialize(self)
	if combat_component and combat_component.has_method("initialize"):
		combat_component.initialize(self, movement_component)
	if stats_component and stats_component.has_method("setup"):
		stats_component.setup(self)
	if inventory_component and inventory_component.has_method("setup"):
		inventory_component.setup(self)
	if movement_component and movement_component.has_method("set_animation_settings"):
		movement_component.set_animation_settings({
			"body_lean_strength": body_lean_strength,
			"body_sway_strength": body_sway_strength,
			"hand_swing_strength": hand_swing_strength,
			"foot_step_strength": foot_step_strength,
			"side_step_modifier": side_step_modifier
		})

	# Connect signals ONCE at the end
	if health_component:
		if health_component.has_signal("health_changed"):
			_connect_signal_safely(health_component, "health_changed", _on_health_changed)
			print("✅ Health signal connected successfully")
		else:
			print("❌ Health component missing health_changed signal!")
		_connect_signal_safely(health_component, "player_died", _on_player_died)
		_connect_signal_safely(health_component, "health_depleted", _on_health_depleted)
		print("✅ All health signals connected")

	if movement_component:
		_connect_signal_safely(movement_component, "dash_charges_changed", _on_dash_charges_changed)
		_connect_signal_safely(movement_component, "hand_animation_update", _on_hand_animation_update)
		_connect_signal_safely(movement_component, "foot_animation_update", _on_foot_animation_update)
		_connect_signal_safely(movement_component, "animation_state_changed", _on_animation_state_changed)
		_connect_signal_safely(movement_component, "body_animation_update", _on_body_animation_update)
	if combat_component:
		_connect_signal_safely(combat_component, "attack_state_changed", _on_combat_attack_state_changed)
	if progression_component:
		_connect_signal_safely(progression_component, "show_level_up_choices", Callable(self, "_on_show_level_up_choices"))
		_connect_signal_safely(progression_component, "stat_choice_made", Callable(self, "_on_stat_choice_made"))
		_connect_signal_safely(progression_component, "xp_changed", Callable(self, "_on_xp_changed"))
		_connect_signal_safely(progression_component, "coin_collected", Callable(self, "_on_coin_collected"))
		_connect_signal_safely(progression_component, "level_up_stats", Callable(self, "_on_level_up_stats"))
		
		# ADD THIS LINE TO DEBUG CONNECTIONS
		_verify_signal_connections()

	# Add verification after signal connections
	call_deferred("verify_signal_methods")

	_reset_blink_timer()
	var config = CharacterGenerator.generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	print("🎨 Player skin tone: ", config["skin_tone"])
	movement_component.reinitialize_feet()
	Input.joy_connection_changed.connect(_on_controller_connection_changed)
	_check_initial_controllers()
	_setup_ally_command_manager()

	# Setup death timer
	death_timer = Timer.new()
	death_timer.wait_time = 2.0
	death_timer.one_shot = true
	add_child(death_timer)
	death_timer.timeout.connect(_restart_scene)

func _setup_player():
	add_to_group("player")
	_configure_collision()
	_create_visual()
	_setup_attack_system()
	_setup_hand_references()
	_setup_weapon_attach_point()
	# Ensure WeaponAnimationPlayer exists
	if not has_node("WeaponAnimationPlayer"):
		var weapon_anim_player = AnimationPlayer.new()
		weapon_anim_player.name = "WeaponAnimationPlayer"
		add_child(weapon_anim_player)
		print("✅ Created WeaponAnimationPlayer node")
	else:
		print("✅ WeaponAnimationPlayer node already exists")
	_create_arrow_system()

func _configure_collision():
	collision_layer = 1
	collision_mask = 1

func _create_visual():
	var existing_mesh = get_node_or_null("MeshInstance3D")
	if not existing_mesh:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		print("🎨 Created MeshInstance3D node for player")
	else:
		mesh_instance = existing_mesh
		print("🎨 Using existing MeshInstance3D node")
	# Ensure material_override is set so _flash_red works
	if not mesh_instance.material_override:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.7, 0.6) # Default skin tone
		mesh_instance.material_override = mat
	print("✅ Player visual created successfully!")

func _setup_attack_system():
	attack_area = Area3D.new()
	attack_area.name = "AttackArea"
	add_child(attack_area)
	var attack_collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = attack_range
	attack_collision.shape = sphere_shape
	attack_area.add_child(attack_collision)
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	if not attack_area.is_connected("area_entered", _on_area_pickup_entered):
		attack_area.area_entered.connect(_on_area_pickup_entered)

func _setup_hand_references():
	# --- FEET (find them after character creation) ---
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")
	if left_foot:
		left_foot_original_pos = left_foot.position
		left_foot_planted_pos = left_foot.position
		print("✅ Found LeftFoot at: ", left_foot.get_path())
	else:
		print("❌ LeftFoot not found!")
	if right_foot:
		right_foot_original_pos = right_foot.position
		right_foot_planted_pos = right_foot.position
		print("✅ Found RightFoot at: ", right_foot.get_path())
	else:
		print("❌ RightFoot not found!")

func _setup_weapon_attach_point():
	if not has_node("WeaponAttachPoint"):
		var attach_point = Node3D.new()
		attach_point.name = "WeaponAttachPoint"
		add_child(attach_point)
		weapon_attach_point = attach_point
		print("✅ Created WeaponAttachPoint node")
	else:
		weapon_attach_point = get_node("WeaponAttachPoint")
		print("✅ Found existing WeaponAttachPoint node")

var weapon_attach_point: Node3D = null

# --- Removed old weapon management functions ---
# func _connect_weapon_manager_signals():
# func _on_weapon_equipped(weapon_resource):
# func _on_weapon_unequipped():
# func _show_weapon_visual(weapon_resource):
# func _hide_weapon_visual():
# func _create_simple_sword_mesh() -> MeshInstance3D:
# func _create_simple_staff_mesh() -> MeshInstance3D:

# Coin/XP pickup system
func _on_area_pickup_entered(area: Area3D):
	if area.is_in_group("health_potion"):
		_pickup_health_potion(area)
	elif area.is_in_group("xp_orb"):
		_pickup_xp_orb(area)
	elif area.is_in_group("currency"):
		_pickup_coin(area)

func _pickup_coin(area: Area3D):
	var coin_value = area.get_meta("coin_value") if area.has_meta("coin_value") else 10
	progression_component.add_currency(coin_value)
	# coin_collected.emit(coin_value)  # Now handled by PlayerProgression
	if is_instance_valid(area):
		area.queue_free()

func can_heal() -> bool:
	return health_component.get_health() < health_component.get_max_health()

func _pickup_health_potion(area: Area3D):
	print("🧪 Attempting to pickup health potion - Current health: ", health_component.get_health(), "/", health_component.get_max_health())
	if not can_heal():
		print("🧪 Already at full health - skipping heal")
		return
	var heal_amount = health_component.heal_amount_from_potion
	print("🧪 Healing for: ", heal_amount, " HP")
	health_component.heal(heal_amount)
	print("🧪 Health after heal: ", health_component.get_health(), "/", health_component.get_max_health())
	if is_instance_valid(area):
		area.queue_free()

func _pickup_xp_orb(area: Area3D):
	var xp_value = area.get_meta("xp_value") if area.has_meta("xp_value") else 10
	print("🔧 Player: _pickup_xp_orb called with value: ", xp_value)
	print("🔧 progression_component exists: ", progression_component != null)
	
	if progression_component:
		print("🔧 Calling progression_component.add_xp(", xp_value, ")")
		progression_component.add_xp(xp_value)
	else:
		print("❌ ERROR: progression_component is null!")
	
	if is_instance_valid(area):
		area.queue_free()

# --- Health System Component Handlers ---
func _on_health_changed(current_health: int, max_health: int):
	print('🔧 Health changed - Current: ', current_health, ' Max: ', max_health)
	print("🔧 Calling UI group with health update")  # ← Add this line
	get_tree().call_group("UI", "_on_player_health_changed", current_health, max_health)  # Direct connection now

func _on_health_depleted():
	# Handle logic when health reaches zero (game over, respawn, etc.)
	pass

# Update max health through health component and heal player
func _on_level_up_stats(health_increase: int, _damage_increase: int):
	print("🔧 Player: _on_level_up_stats called with health_increase: ", health_increase)
	# Get current values
	var current_max = health_component.get_max_health()
	var new_max_health = current_max + health_increase
	
	print("🔧 Current max health: ", current_max, " -> New max health: ", new_max_health)
	# Set new max health
	health_component.set_max_health(new_max_health)
	# Heal player by the health increase amount
	health_component.heal(health_increase)
	print("✅ Max health increased by ", health_increase, " to: ", new_max_health)
	print("✅ Current health after heal: ", health_component.get_health())

func _on_xp_changed(xp: int, xp_to_next: int, level: int):
	print("🔧 Player: XP signal received - ", xp, "/", xp_to_next, " Level: ", level)
	get_tree().call_group("UI", "_on_player_xp_changed", xp, xp_to_next, level)

func _on_coin_collected(total_currency: int):
	print("🔧 Player: Coin signal received - Total: ", total_currency)
	get_tree().call_group("UI", "_on_player_coin_collected", total_currency)

# Animation signal handlers for movement component
func _on_hand_animation_update(left_pos: Vector3, right_pos: Vector3, left_rot: Vector3, right_rot: Vector3) -> void:
	var left_hand = get_node_or_null("LeftHandAnchor/LeftHand")
	if left_hand:
		left_hand.position = left_pos
		left_hand.rotation_degrees = left_rot
	var right_hand = get_node_or_null("RightHandAnchor/RightHand")
	if right_hand:
		right_hand.position = right_pos
		right_hand.rotation_degrees = right_rot

func _on_foot_animation_update(left_pos: Vector3, right_pos: Vector3) -> void:
	if left_foot:
		left_foot.position = left_pos
	if right_foot:
		right_foot.position = right_pos

func _on_animation_state_changed(_is_idle: bool) -> void:
	# Handle animation state changes if needed
	pass

func _on_body_animation_update(body_pos: Vector3, body_rot: Vector3) -> void:
	if mesh_instance:
		mesh_instance.position = body_pos
		mesh_instance.rotation_degrees = body_rot

func _on_combat_attack_state_changed(_state: int) -> void:
	# Handle combat state changes if needed
	pass

func _process(_delta):
	pass

func _schedule_next_blink():
	blink_interval = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	blink_timer = blink_interval

func _handle_advanced_blinking(delta: float):
	if is_dead or is_blinking:
		return

	blink_timer += delta
	if blink_timer >= next_blink_time:
		# 20% chance for double blink
		if randf() < 0.2:
			_do_double_blink()
		else:
			_do_single_blink()

func _do_single_blink():
	CharacterAppearanceManager.blink_eyes(self, 0.15)
	_reset_blink_timer()

func _do_double_blink():
	CharacterAppearanceManager.blink_eyes(self, 0.1)
	get_tree().create_timer(0.2).timeout.connect(
		func(): CharacterAppearanceManager.blink_eyes(self, 0.1)
	)
	_reset_blink_timer()

func _reset_blink_timer():
	is_blinking = true
	blink_timer = 0.0
	next_blink_time = randf_range(2.0, 7.0)
	get_tree().create_timer(0.3).timeout.connect(
		func(): is_blinking = false
	)

# --- Mouth Expression Test System ---
var _mouth_expression_timer: Timer = null
var _mouth_expression_index := 0
var _mouth_expressions := [
	"neutral",
	"smile",
	"frown",
	"surprise"
]

func _start_mouth_expression_test():
	if not mesh_instance:
		return
	if not _mouth_expression_timer:
		_mouth_expression_timer = Timer.new()
		_mouth_expression_timer.wait_time = 2.0
		_mouth_expression_timer.one_shot = false
		_mouth_expression_timer.autostart = true
		add_child(_mouth_expression_timer)
		_mouth_expression_timer.timeout.connect(_cycle_mouth_expression)
	_mouth_expression_index = 0
	_set_mouth_expression(_mouth_expressions[_mouth_expression_index])

func _cycle_mouth_expression():
	_mouth_expression_index = (_mouth_expression_index + 1) % _mouth_expressions.size()
	_set_mouth_expression(_mouth_expressions[_mouth_expression_index])

func _set_mouth_expression(expr: String):
	if not mesh_instance:
		return
	match expr:
		"neutral":
			CharacterAppearanceManager.set_mouth_neutral(mesh_instance)
		"smile":
			CharacterAppearanceManager.set_mouth_smile(mesh_instance)
		"frown":
			CharacterAppearanceManager.set_mouth_frown(mesh_instance)
		"surprise":
			CharacterAppearanceManager.set_mouth_surprise(mesh_instance)
		_:
			CharacterAppearanceManager.set_mouth_neutral(mesh_instance)

# --- Controller/Keyboard Movement Input ---
func get_movement_input() -> Vector2:
	# Use Godot's built-in input vector normalization
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() < 0.2:
		input_vector = Vector2.ZERO
	return input_vector

# --- Look Input Variables ---
@export_group("Look")
@export var look_sensitivity: float = 2.0
var current_look_direction: Vector3 = Vector3.ZERO

# --- Controller/Keyboard Look Input ---
func get_look_input() -> Vector2:
	var look_vector = Vector2.ZERO
	look_vector.x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	look_vector.y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	if look_vector.length() < 0.2:
		look_vector = Vector2.ZERO
	return look_vector

# --- Controller Detection ---
# (Controller detection logic moved into the main _ready() function above)
# ...existing code...

func _check_initial_controllers():
	var connected_controllers = Input.get_connected_joypads()
	if connected_controllers.size() > 0:
		print("Controllers detected: ", connected_controllers.size())

func _on_controller_connection_changed(device_id: int, connected: bool):
	if connected:
		print("Controller ", device_id, " connected")
		var controller_name = Input.get_joy_name(device_id)
		print("Controller name: ", controller_name)
	else:
		print("Controller ", device_id, " disconnected")

# --- Optional: Controller Vibration Feedback ---
func add_controller_feedback(strength: float = 0.5, duration: float = 0.2):
	var connected_controllers = Input.get_connected_joypads()
	for controller_id in connected_controllers:
		Input.start_joy_vibration(controller_id, strength, strength, duration)

func _input(_event):
	# Enhanced input checking for controller/keyboard
	if Input.is_action_just_pressed("attack"):
		if combat_component and combat_component.has_method("perform_attack"):
			combat_component.perform_attack()
	if Input.is_action_just_pressed("dash"):
		if movement_component and movement_component.has_method("perform_dash"):
			movement_component.perform_dash()
	if Input.is_action_just_pressed("interaction"):
		if has_method("interact_with_nearest"):
			interact_with_nearest()
	# DEBUG: Spawn ally with F6
	if Input.is_key_pressed(KEY_F6):
		print("[Debug] is_inside_tree(): ", is_inside_tree())
		_spawn_debug_ally()
	# DEBUG: Test damage numbers with ENTER (ui_accept)
	# Disabled to prevent confusion: only real damage will show numbers now
	# if Input.is_action_just_pressed("ui_accept"):
	# 	for node in get_tree().get_nodes_in_group("damage_numbers"):
	# 		if node.has_method("call_show_damage"):
	# 			node.call_show_damage(25, self, "normal")

func _spawn_debug_ally():
	# Check if node is NOT in scene tree before proceeding
	if not is_inside_tree():
		print("[Debug] Cannot spawn ally - not in scene tree")
		return Transform3D()

	# Load ally scene safely with error checking
	var ally_scene = preload("res://allies/Ally.tscn")
	if not ally_scene:
		print("[Error] Failed to load ally scene")
		return Transform3D()

	# Create instance and verify it was created
	var ally_instance = ally_scene.instantiate()
	if not ally_instance:
		print("[Error] Failed to instantiate ally")
		return Transform3D()

	# Set spawn position (adjust offset as needed)
	var spawn_offset = Vector3(2, 0, 0)
	ally_instance.global_transform.origin = global_transform.origin + spawn_offset

	# Add to scene tree
	get_tree().current_scene.add_child(ally_instance)

	# Update UI for ally count
	get_tree().call_group("UI", "_update_units", get_tree().get_nodes_in_group("allies").size())

	print("[Debug] Spawned ally at ", ally_instance.global_transform.origin)
	return ally_instance.global_transform


func _physics_process(delta):
	if is_dead:
		return

	# --- Controller Look Input Handling ---

	# Always let movement component handle look (controller or mouse)
	movement_component.handle_mouse_look()

	if movement_component.is_being_knocked_back:
		movement_component.handle_knockback(delta)
		movement_component.apply_gravity(delta)
		move_and_slide()
		return

	movement_component.handle_movement_and_dash(delta)
	combat_component.handle_attack_input()
	movement_component.handle_dash_cooldown(delta)
	_handle_advanced_blinking(delta)

func set_character_appearance(config: Dictionary):
	if mesh_instance and CharacterAppearanceManager:
		CharacterAppearanceManager.create_player_appearance(self, config)

func randomize_character():
	if mesh_instance and CharacterAppearanceManager:
		var config = CharacterGenerator.generate_random_character_config()
		set_character_appearance(config)

func get_character_seed_config(seed_value: int):
	return CharacterGenerator.generate_character_with_seed(seed_value)

func _create_arrow_system():
	# We'll create arrows on-demand instead of a particle system
	print("🏹 Simple arrow system ready!")

# Change the player's skin tone at runtime
func change_player_skin_tone(skin_color: Color):
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = skin_color
	# Update hands and feet
	for part in ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var node = get_node_or_null(part)
		if node and node.material_override:
			node.material_override.albedo_color = skin_color
	print("✅ Player skin tone updated to: ", skin_color)
# Disabled staff logic for now
# case int(WeaponResource.WeaponType.STAFF):
# ...existing code...


# === FIXED UI ACCESS METHODS ===
# Use progression_component directly since that's where the data and signals are

func get_health() -> int:
	return health_component.get_health() if health_component else 0

func get_max_health() -> int:
	return health_component.get_max_health() if health_component else 100

func get_currency() -> int:
	return progression_component.get_currency() if progression_component else 0

func get_xp() -> int:
	# FIX: Use progression_component directly, not stats_component
	return progression_component.get_xp() if progression_component else 0

func get_level() -> int:
	# FIX: Use progression_component directly, not stats_component  
	return progression_component.level if progression_component else 1

func get_xp_to_next_level() -> int:
	# FIX: Use progression_component directly, not stats_component
	return progression_component.xp_to_next_level if progression_component else 100

func get_dash_charges() -> int:
	return movement_component.current_dash_charges if movement_component else 1

func get_max_dash_charges() -> int:
	return max_dash_charges if "max_dash_charges" in self else 1

# Debug method to verify all components exist
func debug_components():
	print("🔍 Player Components Debug:")
	print("  - health_component: ", health_component != null)
	print("  - progression_component: ", progression_component != null)
	print("  - movement_component: ", movement_component != null)
	print("  - combat_component: ", combat_component != null)
	print("  - stats_component: ", stats_component != null if "stats_component" in self else false)
	if health_component:
		print("  - Current Health: ", health_component.get_health())
		print("  - Max Health: ", health_component.get_max_health())
	if progression_component:
		print("  - Currency: ", progression_component.get_currency())
		print("  - XP: ", progression_component.get_xp())
		print("  - Level: ", progression_component.level)
		print("  - XP to Next: ", progression_component.xp_to_next_level)
	print("🔍 Testing UI access methods:")
	print("  - get_currency(): ", get_currency())
	print("  - get_xp(): ", get_xp())
	print("  - get_level(): ", get_level())
	print("  - get_health(): ", get_health())
# ...existing code...

func _verify_signal_connections():
	print("🔍 SIGNAL CONNECTION DEBUG:")
	if progression_component:
		print("✅ ProgressionComponent found: ", progression_component)
		print("🔗 xp_changed signal connections: ", progression_component.get_signal_connection_list("xp_changed"))
		print("🔗 coin_collected signal connections: ", progression_component.get_signal_connection_list("coin_collected"))
	else:
		print("❌ ProgressionComponent not found!")


func test_skin_tones():
	print("=== TESTING SKIN TONES ===")
	for i in range(5):
		var config = CharacterGenerator.generate_random_character_config()
		print("Test ", i, " skin tone: ", config["skin_tone"])

func take_damage(amount: int, from: Node3D = null):
	print("🩸 Player: take_damage called with amount: ", amount, " from: ", from)
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount, from)
		# Apply knockback if movement_component exists
		if movement_component and movement_component.has_method("apply_knockback_from_enemy") and from:
			movement_component.apply_knockback_from_enemy(from)
		# Flash red when taking damage
		_flash_red()
	else:
		print("❌ ERROR: health_component not found or missing take_damage method!")



	print("🩸 Player: take_damage called with amount: ", amount, " from: ", from)
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount, from)
		# Apply knockback if movement_component exists
		if movement_component and movement_component.has_method("apply_knockback_from_enemy") and from:
			movement_component.apply_knockback_from_enemy(from)
		# Flash red when taking damage
		_flash_red()
	else:
		print("❌ ERROR: health_component not found or missing take_damage method!")



	print("🩸 Player: take_damage called with amount: ", amount, " from: ", from)
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount, from)
		# Apply knockback if movement_component exists
		if movement_component and movement_component.has_method("apply_knockback_from_enemy") and from:
			movement_component.apply_knockback_from_enemy(from)
	else:
		print("❌ ERROR: health_component not found or missing take_damage method!")

func interact_with_nearest():
	# Implement interaction logic here or leave as a stub for now
	print("Player: interact_with_nearest() called (stub)")

func _setup_ally_command_manager():
	"""Setup the ally command system"""
	add_child(ally_command_manager)
	# Connect signals if needed
	if ally_command_manager.has_signal("command_issued"):
		ally_command_manager.command_issued.connect(_on_ally_command_issued)
	print("🎮 Ally command system initialized! Press '1' to command allies")

func _on_ally_command_issued(command_type: String, cmd_position: Vector3):
	"""Handle ally command feedback"""
	match command_type:
		"move_to_position":
			print("✅ Command issued: Move allies to search at ", cmd_position)
			# You can add sound effects, UI feedback, etc. here

# If you want to add controller vibration feedback for commands
func _add_command_feedback():
	"""Add controller feedback when commanding allies"""
	if has_method("add_controller_feedback"):
		add_controller_feedback(0.3, 0.1) # Light vibration

func _on_player_died():
	if is_dead:
		return
	is_dead = true
	print("💀 Player died - restarting in 2 seconds...")
	# Step 4: Clear all damage numbers before respawn
	for node in get_tree().get_nodes_in_group("damage_numbers"):
		if node.has_method("_clear_all_labels"):
			print("[Player] Calling damage number cleanup on ", node)
			node._clear_all_labels()
	set_process_input(false)
	if movement_component:
		movement_component.set_physics_process(false)
	if combat_component:
		combat_component.set_physics_process(false)
	death_timer.start()

func _restart_scene():
	var error = get_tree().reload_current_scene()
	if error != OK:
		print("❌ Failed to restart scene: ", error)

func _connect_signal_safely(source_object, signal_name: String, target_callable: Callable):
	if source_object and source_object.has_signal(signal_name):
		if not source_object.is_connected(signal_name, target_callable):
			source_object.connect(signal_name, target_callable)
			print("✅ Connected signal: ", signal_name)
		else:
			print("⚠️ Signal already connected: ", signal_name)


func _connect_component_signals():
	# Connect directly to UI instead of using call_group
	var ui_node = get_tree().get_first_node_in_group('UI')
	if ui_node:
		print('✅ Found UI node, connecting direct signals')
		if health_component and health_component.has_signal('health_changed'):
			if not health_component.health_changed.is_connected(ui_node._on_player_health_changed):
				health_component.health_changed.connect(ui_node._on_player_health_changed)
				print('✅ Connected health_changed directly to UI')
		if progression_component:
			if progression_component.has_signal('xp_changed'):
				if not progression_component.xp_changed.is_connected(ui_node._on_player_xp_changed):
					progression_component.xp_changed.connect(ui_node._on_player_xp_changed)
					print('✅ Connected xp_changed directly to UI')
			if progression_component.has_signal('coin_collected'):
				if not progression_component.coin_collected.is_connected(ui_node._on_player_coin_collected):
					progression_component.coin_collected.connect(ui_node._on_player_coin_collected)
					print('✅ Connected coin_collected directly to UI')
	else:
		print('❌ UI node not found for direct connection!')

func _flash_red():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	if not mesh_instance.material_override:
		return
	mesh_instance.material_override.albedo_color = Color(1,0,0)
	get_tree().create_timer(0.5).timeout.connect(func():
		if mesh_instance and is_instance_valid(mesh_instance) and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = Color(0.9, 0.7, 0.6) # Default skin tone
	)

func _on_show_level_up_choices(options: Array):
	print("🎮 Player: Received level up choices signal with ", options.size(), " options")
	print("🔍 Looking for levelupui node...")
	var level_up_ui = get_tree().get_first_node_in_group("levelupui")
	if level_up_ui:
		print("✅ Found LevelUpUI node: ", level_up_ui.name)
		level_up_ui.show_upgrade_choices(options)
	else:
		print("❌ ERROR: LevelUpUI node not found in group 'levelupui'!")

func _on_stat_choice_made():
	print("[Signal] _on_stat_choice_made called (stub)")
	# TODO: Implement stat choice logic here

func verify_signal_methods():
	var required_methods = [
		"_on_show_level_up_choices",
		"_on_stat_choice_made",
		"_on_xp_changed",
		"_on_coin_collected",
		"_on_level_up_stats"
	]
	for method in required_methods:
		if has_method(method):
			print("✅ Found method: ", method)
		else:
			print("❌ MISSING method: ", method)
