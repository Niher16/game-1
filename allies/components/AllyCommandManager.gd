extends Node
class_name AllyCommandManager

signal command_issued(command_type: String, position: Vector3)

# --- References ---
var player_ref: CharacterBody3D
var camera_ref: Camera3D

# --- Command Settings ---
var command_range := 30.0  # Maximum command distance
var visual_feedback_enabled := true

# --- Visual Feedback ---
var command_marker: MeshInstance3D
var command_effect_timer := 0.0
var command_effect_duration := 2.0

func _ready():
	# Find player and camera references
	call_deferred("_find_references")
	_create_command_marker()

func _find_references():
	"""Find player and camera references"""
	player_ref = get_tree().get_first_node_in_group("player")
	camera_ref = get_tree().get_first_node_in_group("camera")

func _input(event):
	if not player_ref or not camera_ref:
		return
	
	# Handle "1" key for move command
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_issue_move_command()
		elif event.keycode == KEY_3:
			_issue_patrol_command()

func _issue_move_command():
	"""Issue move-to-position command at mouse location"""
	var mouse_world_pos = _get_mouse_world_position()
	
	if mouse_world_pos == Vector3.ZERO:
		return
	
	# Check if position is within command range
	var distance_to_player = mouse_world_pos.distance_to(player_ref.global_position)
	if distance_to_player > command_range:
		return
	
	# Command all allies to move to position
	var allies = get_tree().get_nodes_in_group("allies")
	var commanded_count = 0
	for ally in allies:
		if not _is_valid_ally(ally):
			continue
		var ai_component = ally.get_node_or_null("AIComponent")
		if not ai_component:
			continue
		if not ai_component.has_method("command_move_to_position"):
			continue
		ai_component.command_move_to_position(mouse_world_pos)
		commanded_count += 1
	
	if commanded_count > 0:
		_show_command_feedback(mouse_world_pos)
		command_issued.emit("move_to_position", mouse_world_pos)

func _issue_patrol_command():
	"""Issue patrol-at-point command at mouse location"""
	var mouse_world_pos = _get_mouse_world_position()
	
	if mouse_world_pos == Vector3.ZERO:
		return
	
	# Check if position is within command range
	var distance_to_player = mouse_world_pos.distance_to(player_ref.global_position)
	if distance_to_player > command_range:
		return
	
	# Command all allies to patrol at position
	var allies = get_tree().get_nodes_in_group("allies")
	var commanded_count = 0
	for ally in allies:
		if not _is_valid_ally(ally):
			continue
		var ai_component = ally.get_node_or_null("AIComponent")
		if not ai_component:
			continue
		if not ai_component.has_method("command_patrol_at_point"):
			continue
		ai_component.command_patrol_at_point(mouse_world_pos)
		commanded_count += 1
	
	if commanded_count > 0:
		_show_command_feedback(mouse_world_pos)
		command_issued.emit("patrol_at_point", mouse_world_pos)

func _get_mouse_world_position() -> Vector3:
	# Raycast from camera to mouse position onto the XZ plane (y=0)
	if not camera_ref:
		return Vector3.ZERO

	var viewport = get_viewport()
	if not viewport:
		return Vector3.ZERO

	var mouse_pos = viewport.get_mouse_position()
	var from = camera_ref.project_ray_origin(mouse_pos)
	var dir = camera_ref.project_ray_normal(mouse_pos)

	# Intersect with XZ plane at y=0
	if abs(dir.y) < 0.0001:
		return Vector3.ZERO  # Avoid division by zero
	var t = -from.y / dir.y
	if t < 0:
		return Vector3.ZERO  # Don't allow points behind the camera
	var hit_pos = from + dir * t
	return hit_pos

func _is_valid_ally(ally) -> bool:
	return ally and ally.is_inside_tree() and ally.has_method("get_node_or_null")

func _create_command_marker():
	# Optional: create a visual marker for command feedback
	pass

func _show_command_feedback(_position: Vector3):
	# Optional: show a marker or effect at the command position
	pass
