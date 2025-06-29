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
	dash_charges_changed.emit(current_charges, max_charges)

func _ready():
	if not health_component:
		return
	if not movement_component:
		return
	if health_component:
		health_component.setup(self, 100)
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
	if health_component:
		if health_component.has_signal("health_changed"):
			_connect_signal_safely(health_component, "health_changed", _on_health_changed)
		_connect_signal_safely(health_component, "player_died", _on_player_died)
		_connect_signal_safely(health_component, "health_depleted", _on_health_depleted)
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
	_reset_blink_timer()
	var config = CharacterGenerator.generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	movement_component.reinitialize_feet()
	Input.joy_connection_changed.connect(_on_controller_connection_changed)
	_check_initial_controllers()
	_setup_ally_command_manager()
	death_timer = Timer.new()
	death_timer.wait_time = 2.0
	death_timer.one_shot = true
	add_child(death_timer)
	death_timer.timeout.connect(_restart_scene)
	_setup_player()

func _setup_player():
	add_to_group("player")
	_configure_collision()
	_setup_attack_system()
	_setup_hand_references()
	_setup_weapon_attach_point()
	if not has_node("WeaponAnimationPlayer"):
		var weapon_anim_player = AnimationPlayer.new()
		weapon_anim_player.name = "WeaponAnimationPlayer"
		add_child(weapon_anim_player)

func _configure_collision():
	collision_layer = 4
	collision_mask = (1 << 0) | (1 << 1) | (1 << 3) | (1 << 4)

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
	attack_area.collision_mask = 1 << 4
	if not attack_area.is_connected("area_entered", _on_area_pickup_entered):
		attack_area.area_entered.connect(_on_area_pickup_entered)

func _setup_hand_references():
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")
	if left_foot:
		left_foot_original_pos = left_foot.position
		left_foot_planted_pos = left_foot.position
	if right_foot:
		right_foot_original_pos = right_foot.position
		right_foot_planted_pos = right_foot.position

func _setup_weapon_attach_point():
	if not has_node("WeaponAttachPoint"):
		var attach_point = Node3D.new()
		attach_point.name = "WeaponAttachPoint"
		add_child(attach_point)
		weapon_attach_point = attach_point
	else:
		weapon_attach_point = get_node("WeaponAttachPoint")

var weapon_attach_point: Node3D = null

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
	if is_instance_valid(area):
		area.queue_free()

func can_heal() -> bool:
	return health_component.get_health() < health_component.get_max_health()

func _pickup_health_potion(area: Area3D):
	if not can_heal():
		return
	var heal_amount = health_component.heal_amount_from_potion
	health_component.heal(heal_amount)
	if is_instance_valid(area):
		area.queue_free()

func _pickup_xp_orb(area: Area3D):
	var xp_value = area.get_meta("xp_value") if area.has_meta("xp_value") else 10
	if progression_component:
		progression_component.add_xp(xp_value)
	if is_instance_valid(area):
		area.queue_free()

func _on_health_changed(current_health: int, max_health: int):
	get_tree().call_group("UI", "_on_player_health_changed", current_health, max_health)

func _on_health_depleted():
	pass

func _on_level_up_stats(health_increase: int, _damage_increase: int):
	var current_max = health_component.get_max_health()
	var new_max_health = current_max + health_increase
	health_component.set_max_health(new_max_health)
	health_component.heal(health_increase)

func _on_xp_changed(xp: int, xp_to_next: int, level: int):
	get_tree().call_group("UI", "_on_player_xp_changed", xp, xp_to_next, level)

func _on_coin_collected(total_currency: int):
	get_tree().call_group("UI", "_on_player_coin_collected", total_currency)

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
	pass

func _on_body_animation_update(body_pos: Vector3, body_rot: Vector3) -> void:
	if mesh_instance:
		mesh_instance.position = body_pos
		mesh_instance.rotation_degrees = body_rot

func _on_combat_attack_state_changed(_state: int) -> void:
	pass

var _last_position: Vector3 = Vector3.ZERO

func _process(_delta):
	if global_position != _last_position:
		_last_position = global_position
	pass

func _schedule_next_blink():
	blink_interval = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
	blink_timer = blink_interval

func _handle_advanced_blinking(delta: float):
	if is_dead or is_blinking:
		return
	blink_timer += delta
	if blink_timer >= next_blink_time:
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

# --- Controller/Keyboard Movement Input ---
func get_movement_input() -> Vector2:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() < 0.2:
		input_vector = Vector2.ZERO
	return input_vector

@export_group("Look")
@export var look_sensitivity: float = 2.0

func get_look_input() -> Vector2:
	var look_vector = Vector2.ZERO
	look_vector.x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	look_vector.y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	if look_vector.length() < 0.2:
		look_vector = Vector2.ZERO
	return look_vector

func _check_initial_controllers():
	var connected_controllers = Input.get_connected_joypads()
	if connected_controllers.size() > 0:
		pass

func _on_controller_connection_changed(device_id: int, connected: bool):
	if connected:
		var _controller_name = Input.get_joy_name(device_id)
	else:
		pass

func add_controller_feedback(strength: float = 0.5, duration: float = 0.2):
	var connected_controllers = Input.get_connected_joypads()
	for controller_id in connected_controllers:
		Input.start_joy_vibration(controller_id, strength, strength, duration)

func _input(_event):
	if Input.is_action_just_pressed("attack"):
		if combat_component and combat_component.has_method("perform_attack"):
			combat_component.perform_attack()
	if Input.is_action_just_pressed("dash"):
		if movement_component and movement_component.has_method("perform_dash"):
			movement_component.perform_dash()
	if Input.is_action_just_pressed("interaction"):
		if has_method("interact_with_nearest"):
			interact_with_nearest()

func _physics_process(delta):
	if is_dead:
		return
	movement_component.handle_mouse_look()
	if movement_component.is_being_knocked_back:
		movement_component.handle_knockback(delta)
		movement_component.apply_gravity(delta)
		move_and_slide()
		if is_on_floor() and velocity.y < 0:
			velocity.y = 0
		return
	movement_component.handle_movement_and_dash(delta)
	combat_component.handle_attack_input()
	movement_component.handle_dash_cooldown(delta)
	_handle_advanced_blinking(delta)
	if is_on_floor() and velocity.y < 0:
		velocity.y = 0

func set_character_appearance(config: Dictionary):
	if mesh_instance and CharacterAppearanceManager:
		CharacterAppearanceManager.create_player_appearance(self, config)

func get_health() -> int:
	return health_component.get_health() if health_component else 0

func get_max_health() -> int:
	return health_component.get_max_health() if health_component else 100

func get_currency() -> int:
	return progression_component.get_currency() if progression_component else 0

func get_xp() -> int:
	return progression_component.get_xp() if progression_component else 0

func get_level() -> int:
	return progression_component.level if progression_component else 1

func get_xp_to_next_level() -> int:
	return progression_component.xp_to_next_level if progression_component else 100

func get_dash_charges() -> int:
	return movement_component.current_dash_charges if movement_component else 1

func get_max_dash_charges() -> int:
	return max_dash_charges

func take_damage(amount: int, from: Node3D = null):
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount, from)
		if movement_component and movement_component.has_method("apply_knockback_from_enemy") and from:
			movement_component.apply_knockback_from_enemy(from)

func interact_with_nearest():
	pass

func _setup_ally_command_manager():
	add_child(ally_command_manager)
	if ally_command_manager.has_signal("command_issued"):
		ally_command_manager.command_issued.connect(_on_ally_command_issued)

func _on_ally_command_issued(command_type: String, _cmd_position: Vector3):
	match command_type:
		"move_to_position":
			pass

func _on_player_died():
	if is_dead:
		return
	is_dead = true
	set_process_input(false)
	if movement_component:
		movement_component.set_physics_process(false)
	if combat_component:
		combat_component.set_physics_process(false)
	death_timer.start()

func _restart_scene():
	var _error = get_tree().reload_current_scene()

func _connect_signal_safely(source_object, signal_name: String, target_callable: Callable):
	if source_object and source_object.has_signal(signal_name):
		if not source_object.is_connected(signal_name, target_callable):
			source_object.connect(signal_name, target_callable)

func _on_show_level_up_choices(options: Array):
	var level_up_ui = get_tree().get_first_node_in_group("levelupui")
	if level_up_ui:
		level_up_ui.show_upgrade_choices(options)

func _on_stat_choice_made():
	pass

func show_message(_text: String):
	pass
