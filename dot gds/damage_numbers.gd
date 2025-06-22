# damage_numbers.gd - Godot 4.1+ FIXED VERSION
extends Node

@export var damage_font_size = 24
@export var float_height = 1.5
@export var fade_duration = 1.0
@export var combine_window := 0.5

const MAX_LABELS = 32
const MIN_FPS = 30

const DAMAGE_COLORS = {
	"normal": Color.WHITE,
	"high": Color.YELLOW,
	"critical": Color.ORANGE,
	"massive": Color.RED,
	"heal": Color.GREEN
}

var floating_labels: Dictionary = {}
var label_last_position: Dictionary = {}
var label_timers: Dictionary = {}
var label_fading: Dictionary = {}
var label_pool: Array = []

var current_scene: Node
var camera: Camera3D
var health_monitor_timer: Timer
var _previous_scene = null

# FIXED: Single clean initialization
func _ready():
	add_to_group("damage_numbers")
	_update_scene_references()
	
	# Track scene changes
	if get_tree():
		get_tree().tree_changed.connect(_on_scene_changed)
		_previous_scene = get_tree().current_scene
	
	# Health monitor setup
	health_monitor_timer = Timer.new()
	health_monitor_timer.wait_time = 30.0
	health_monitor_timer.one_shot = false
	health_monitor_timer.timeout.connect(_report_health_status)
	add_child(health_monitor_timer)
	health_monitor_timer.start()
	
	print("✅ DamageNumbers: System initialized")

# FIXED: Simplified scene and camera detection
func _update_scene_references():
	# Get current scene
	if get_tree():
		current_scene = get_tree().current_scene
	else:
		current_scene = null
	
	# Get camera - prioritize viewport camera
	camera = null
	if get_viewport():
		camera = get_viewport().get_camera_3d()
	
	# Fallback: search for active camera in scene
	if not is_instance_valid(camera) and is_instance_valid(current_scene):
		camera = _find_active_camera(current_scene)
	
	# Final fallback: any camera in groups
	if not is_instance_valid(camera) and get_tree():
		var cameras = get_tree().get_nodes_in_group("cameras")
		if cameras.size() > 0:
			camera = cameras[0]
	
	if not is_instance_valid(camera):
		print("⚠️ DamageNumbers: No valid camera found!")
	else:
		print("✅ DamageNumbers: Camera found: ", camera.name)

func _find_active_camera(node: Node) -> Camera3D:
	if node is Camera3D and node.is_current():
		return node
	for child in node.get_children():
		var found = _find_active_camera(child)
		if found:
			return found
	return null

func _on_scene_changed():
	var new_scene = get_tree().current_scene if get_tree() else null
	if new_scene != _previous_scene:
		print("DamageNumbers: Scene changed, clearing labels")
		_clear_all_labels()
		_previous_scene = new_scene
		call_deferred("_update_scene_references")

func _clear_all_labels():
	print("DamageNumbers: Clearing ", floating_labels.size(), " labels")
	# Clean up floating labels
	for entity in floating_labels.keys():
		var label = floating_labels[entity]
		if is_instance_valid(label):
			label.queue_free()
	# Clean up pooled labels
	for label in label_pool:
		if is_instance_valid(label):
			label.queue_free()
	# Clear all data structures
	label_pool.clear()
	floating_labels.clear()
	label_last_position.clear()
	label_timers.clear()
	label_fading.clear()

func _process(_delta):
	# Performance check
	if Engine.get_frames_per_second() < MIN_FPS:
		return

	var now_time = Time.get_ticks_msec() / 1000.0

	# Update all floating labels
	for id in floating_labels.keys().duplicate():
		var label = floating_labels[id] as Label
		var entity = instance_from_id(id)

		if not is_instance_valid(label):
			_clear_entity_data(id)
			continue

		# Update position if entity is valid
		if is_instance_valid(entity):
			_update_label_position(label, entity)
			label_last_position[id] = entity.global_position
		elif id in label_last_position:
			# Use last known position if entity is gone
			var world_pos = label_last_position[id] + Vector3(0, float_height, 0)
			var screen_pos = _world_to_screen(world_pos)
			if screen_pos != Vector2(-1, -1):
				label.position = screen_pos - (label.size / 2)
				label.visible = true
			else:
				label.visible = false
		else:
			_clear_entity_data(id)
			continue

		# Handle fading
		if id in label_timers and is_instance_valid(label):
			var time_since_last = now_time - label_timers[id]
			if not label_fading.get(id, false) and time_since_last > combine_window:
				label_fading[id] = true
				_start_fade(label, id)

# Main API function - call this to show damage
func show_damage(damage_amount: int, entity: Node3D, damage_type: String = "normal"):
	if not is_instance_valid(entity):
		push_error("DamageNumbers: Entity is not valid!")
		return

	# Detect if entity is an ally and override color to red
	var is_ally = entity.is_in_group("allies")
	var color_type = damage_type
	if is_ally:
		color_type = "massive"  # Use red for allies

	print("DamageNumbers: Showing damage ", damage_amount, " on ", entity.name)
	_create_or_update_label(entity, str(damage_amount), color_type)



	if not is_instance_valid(entity):
		push_error("DamageNumbers: Entity is not valid!")
		return
	
	print("DamageNumbers: Showing damage ", damage_amount, " on ", entity.name)
	_create_or_update_label(entity, str(damage_amount), damage_type)

# Call this for healing numbers
func show_heal(heal_amount: int, entity: Node3D):
	if not is_instance_valid(entity):
		push_error("DamageNumbers: Entity is not valid!")
		return
	
	_create_or_update_label(entity, "+" + str(heal_amount), "heal")

# Group-callable wrapper for easy access
func call_show_damage(amount: int, entity: Node3D, damage_type: String = "normal"):
	show_damage(amount, entity, damage_type)

func _create_or_update_label(entity: Node3D, text: String, damage_type: String):
	var id = entity.get_instance_id()

	# Check label limit
	if floating_labels.size() >= MAX_LABELS:
		print("⚠️ DamageNumbers: Max labels reached, skipping")
		return

	# Ensure scene is valid
	if not is_instance_valid(current_scene):
		print("⚠️ DamageNumbers: No valid scene, updating references")
		_update_scene_references()
		if not is_instance_valid(current_scene):
			print("❌ DamageNumbers: Still no valid scene!")
			return

	var damage_label: Label
	var now_time = Time.get_ticks_msec() / 1000.0

	# Update existing label if present
	if id in floating_labels:
		damage_label = floating_labels[id] as Label
		if is_instance_valid(damage_label):
			_update_existing_label(damage_label, text)
			label_timers[id] = now_time
			label_fading[id] = false
			damage_label.modulate.a = 1.0
			return
		else:
			_clear_entity_data(id)

	# Create new label
	damage_label = _get_label_from_pool(text, damage_type)
	floating_labels[id] = damage_label

	# Remove from previous parent if needed
	if damage_label.get_parent():
		damage_label.get_parent().remove_child(damage_label)

	# Add to scene
	current_scene.add_child(damage_label)

	# Position and initialize
	_update_label_position(damage_label, entity)
	label_last_position[id] = entity.global_position
	label_timers[id] = now_time
	label_fading[id] = false

func _create_label(text: String, damage_type: String) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(120, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 100
	
	# Styling
	label.add_theme_font_size_override("font_size", damage_font_size)
	label.add_theme_color_override("font_color", DAMAGE_COLORS.get(damage_type, DAMAGE_COLORS["normal"]))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	return label

func _get_label_from_pool(text: String, damage_type: String) -> Label:
	# Reuse from pool if available
	if label_pool.size() > 0:
		var label = label_pool.pop_back()
		label.text = text
		label.modulate.a = 1.0
		label.visible = true
		label.add_theme_color_override("font_color", DAMAGE_COLORS.get(damage_type, DAMAGE_COLORS["normal"]))
		return label
	
	# Create new if pool is empty
	return _create_label(text, damage_type)

func _update_existing_label(label: Label, new_text: String):
	if is_instance_valid(label):
		var current_value = label.text.to_int()
		var new_value = new_text.to_int()
		var combined_value = current_value + new_value
		label.text = str(combined_value)

func _update_label_position(label: Label, entity: Node3D):
	if not is_instance_valid(label) or not is_instance_valid(entity):
		return
	
	var world_pos = entity.global_position + Vector3(0, float_height, 0)
	var screen_pos = _world_to_screen(world_pos)
	
	if screen_pos != Vector2(-1, -1):
		label.position = screen_pos - (label.size / 2)
		label.visible = true
	else:
		label.visible = false

func _world_to_screen(world_pos: Vector3) -> Vector2:
	if not is_instance_valid(camera):
		_update_scene_references()
		if not is_instance_valid(camera):
			return Vector2(-1, -1)
	
	var screen_pos = camera.unproject_position(world_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Check if on screen
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return Vector2(-1, -1)
	
	return screen_pos

func _start_fade(label: Label, id: int):
	if not is_instance_valid(label):
		return
	if not label.is_inside_tree():
		return

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)
	tween.tween_property(label, "position:y", label.position.y - 50, fade_duration)
	# Bind the entity (dictionary key) instead of the label
	tween.tween_callback(Callable(self, "_remove_label").bind(id)).set_delay(fade_duration)

func _remove_label(id: int):
	if id in floating_labels:
		var label = floating_labels[id]
		if is_instance_valid(label):
			label.visible = false
			label_pool.append(label)
		_clear_entity_data(id)

func _clear_entity_data(id: int):
	if id in floating_labels:
		var label = floating_labels[id]
		if is_instance_valid(label):
			label.visible = false
			label_pool.append(label)
		floating_labels.erase(id)
	label_last_position.erase(id)
	label_timers.erase(id)
	label_fading.erase(id)

func _report_health_status():
	var cam_status = is_instance_valid(camera)
	var scene_status = is_instance_valid(current_scene)
	print("[DamageNumbers Health] Camera: ", cam_status, " Scene: ", scene_status, " Labels: ", floating_labels.size())
	
	if not cam_status or not scene_status:
		print("[DamageNumbers Health] Attempting recovery...")
		_update_scene_references()
