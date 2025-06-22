# Clean Camera Script for Godot 4.1+ with Smooth Momentum
# Purpose: Smooth rotation and zoom camera with momentum and easing (no floor clipping)
# Author: Thane
# Date: 2025-06-20
#
# Controls:
# - Right Mouse Button: Rotate camera around player (with smooth momentum)
# - Mouse Wheel: Zoom in/out (with smooth transitions)
# - R Key: Reset camera rotation
# - Camera maintains safe height and has phone-like smooth momentum
#
extends Camera3D

# --- Camera Following Settings ---
@export_group("Following")
@export var follow_speed: float = 5.0  ## How fast camera follows player (higher = snappier)
@export var camera_height: float = 8.0  ## Fixed height above player (prevents floor clipping)
@export var min_height: float = 3.0  ## Minimum height to prevent floor clipping

# --- Camera Zoom Settings ---
@export_group("Zoom")
@export var min_zoom_distance: float = 1.0  ## Closest zoom distance (was 5.0)
@export var max_zoom_distance: float = 30.0  ## Farthest zoom distance (was 20.0)
@export var zoom_speed: float = 2.0  ## How fast zoom responds to mouse wheel
@export var current_zoom: float = 12.0  ## Starting zoom distance

# --- Camera Rotation Settings ---
@export_group("Rotation") 
@export var rotation_speed: float = 1.0  ## Mouse sensitivity for camera rotation (lower = slower)
@export var max_vertical_angle: float = 60.0  ## Limits how high/low camera can look (prevents floor clipping)

# --- Smooth Momentum & Easing Settings ---
@export_group("Momentum & Smoothing")
@export var rotation_smoothing: float = 8.0  ## How smoothly rotation follows input (higher = snappier)
@export var zoom_smoothing: float = 6.0  ## How smoothly zoom transitions (higher = faster)
@export var momentum_decay: float = 0.92  ## How long momentum lasts after stopping mouse (0.9 = longer, 0.95 = shorter)
@export var momentum_strength: float = 0.3  ## How strong the momentum effect is (0 = none, 1 = very strong)
@export var rotation_acceleration: float = 3.0  ## How fast rotation builds up speed

# --- Private Variables (Don't touch these in editor) ---
var player: Node3D  # Reference to the player we're following
var is_rotating: bool = false  # True when right mouse button is held
var rotation_x: float = deg_to_rad(+10.0)  # Current vertical rotation (default: -10 degrees for less top-down)
var rotation_y: float = 0.0  # Current horizontal rotation

# --- Smooth Momentum Variables ---
var target_rotation_x: float = deg_to_rad(+10.0)  # Where rotation_x wants to be (default: -10 degrees)
var target_rotation_y: float = 0.0  # Where rotation_y wants to be
var rotation_velocity_x: float = 0.0  # Current rotation speed for momentum
var rotation_velocity_y: float = 0.0  # Current rotation speed for momentum
var target_zoom: float = 12.0  # Where zoom wants to be (smooth transitions)
var zoom_velocity: float = 0.0  # For smooth zoom momentum

# --- Built-in Godot Functions ---
func _ready() -> void:
	"""Called when camera is added to scene - finds the player and sets up initial position"""
	print("Camera: Starting up...")
	
	# Find the player node safely
	_find_player()
	
	# Set initial zoom distance
	current_zoom = 12.0
	target_zoom = current_zoom
	
	# Make sure we're in the camera group for easy finding
	add_to_group("camera")

func _find_player() -> void:
	"""Safely finds the player node in the scene"""
	# Look for a node in the "player" group
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0:
		player = players[0] as Node3D
		print("Camera: Found player at ", player.global_position)
		_update_camera_position()
	else:
		print("Camera: Player not found, retrying in 0.5 seconds...")
		# Try again after a short delay
		get_tree().create_timer(0.5).timeout.connect(_find_player)

# Handles all input for camera control (Middle Mouse rotates, Right Click does nothing)
func _input(event: InputEvent) -> void:
	# Middle mouse button for camera rotation ONLY
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_rotating = event.pressed
			if is_rotating:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Mouse wheel for zooming
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(zoom_speed)
		# Ignore right mouse button (do nothing)
	# Mouse movement for rotation (only when middle mouse held)
	elif event is InputEventMouseMotion and is_rotating:
		_rotate_camera(event.relative)
	# Keyboard shortcuts
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_reset_camera_rotation()
			print("Camera: Rotation reset!")

func _process(delta: float) -> void:
	"""Called every frame - updates camera with smooth momentum and transitions"""
	
	# Don't do anything if we don't have a valid player
	if not player or not is_instance_valid(player):
		return
	
	# --- Smooth Zoom Transitions ---
	current_zoom = lerp(current_zoom, target_zoom, zoom_smoothing * delta)
	
	# --- Smooth Rotation with Momentum ---
	if is_rotating:
		# While actively rotating, smoothly follow targets
		rotation_x = lerp(rotation_x, target_rotation_x, rotation_smoothing * delta)
		rotation_y = lerp(rotation_y, target_rotation_y, rotation_smoothing * delta)
	else:
		# When not actively rotating, apply momentum (like phone cameras)
		_apply_rotation_momentum(delta)
		
		# Still smoothly approach targets but slower
		rotation_x = lerp(rotation_x, target_rotation_x, rotation_smoothing * 0.5 * delta)
		rotation_y = lerp(rotation_y, target_rotation_y, rotation_smoothing * 0.5 * delta)
	
	# Update camera position to follow player smoothly
	_update_camera_position(delta)

# --- Custom Camera Functions ---
func _update_camera_position(delta: float = 1.0) -> void:
	"""Smoothly moves camera to follow the player"""
	
	if not player:
		return
	
	# Calculate where the camera should be based on player position and our rotation
	var desired_position = _calculate_camera_position()
	
	# Smoothly move to the desired position
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Always look at the player
	look_at(player.global_position, Vector3.UP)

func _apply_rotation_momentum(_delta: float) -> void:
	"""Applies phone-like momentum when not actively rotating"""
	
	# Continue rotating based on stored velocity (momentum effect)
	target_rotation_x += rotation_velocity_x * momentum_strength
	target_rotation_y += rotation_velocity_y * momentum_strength
	
	# Gradually slow down the momentum (decay)
	rotation_velocity_x *= momentum_decay
	rotation_velocity_y *= momentum_decay
	
	# Stop very small movements to prevent infinite tiny rotations
	if abs(rotation_velocity_x) < 0.001:
		rotation_velocity_x = 0.0
	if abs(rotation_velocity_y) < 0.001:
		rotation_velocity_y = 0.0
	
	# Clamp target rotation to stay in bounds
	target_rotation_x = clamp(target_rotation_x, 
		deg_to_rad(-max_vertical_angle), 
		deg_to_rad(max_vertical_angle))

func _calculate_camera_position() -> Vector3:
	"""Calculates where the camera should be positioned based on current settings"""
	# Start with player position at fixed safe height
	var target_position = player.global_position
	# Lower the camera height as we zoom in for less top-down effect
	var _dynamic_height = camera_height * (current_zoom / max_zoom_distance)
	target_position.y += lerp(camera_height * 0.5, camera_height, current_zoom / max_zoom_distance)

	# Calculate horizontal distance based on zoom and vertical angle
	var horizontal_distance = current_zoom * cos(rotation_x)
	var height_offset = current_zoom * sin(rotation_x)

	# Apply horizontal rotation around player
	var offset = Vector3(
		sin(rotation_y) * horizontal_distance,
		height_offset,
		cos(rotation_y) * horizontal_distance
	)

	# Ensure minimum height above ground
	var final_position = target_position + offset
	final_position.y = max(final_position.y, player.global_position.y + min_height)

	return final_position

func _rotate_camera(mouse_delta: Vector2) -> void:
	"""Handles camera rotation with smooth acceleration and momentum"""
	# Only rotate horizontally (left/right) with mouse X movement
	var rotation_input_x = 0.0  # No vertical rotation on right click
	var rotation_input_y = -mouse_delta.x * rotation_speed * 0.005  # Horizontal only

	# Apply acceleration to build up rotation speed gradually
	rotation_velocity_x = lerp(rotation_velocity_x, rotation_input_x, rotation_acceleration * get_process_delta_time())
	rotation_velocity_y = lerp(rotation_velocity_y, rotation_input_y, rotation_acceleration * get_process_delta_time())

	# Update target rotations (what we want to achieve)
	target_rotation_y += rotation_velocity_y
	# No change to target_rotation_x (vertical) when rotating

	# Clamp vertical rotation to prevent camera flipping
	target_rotation_x = clamp(target_rotation_x, 
		deg_to_rad(-max_vertical_angle), 
		deg_to_rad(max_vertical_angle))

func _zoom_camera(zoom_change: float) -> void:
	"""Changes camera zoom with smooth transitions"""
	
	# Update target zoom instead of current zoom for smooth transitions
	target_zoom += zoom_change
	target_zoom = clamp(target_zoom, min_zoom_distance, max_zoom_distance)
	
	print("Camera: Target zoom = ", target_zoom)

func _reset_camera_rotation() -> void:
	"""Resets camera rotation to default position with smooth transition"""
	# Reset targets for smooth transition to default (less top-down)
	target_rotation_x = deg_to_rad(-30.0)
	target_rotation_y = 0.0
	# Clear any momentum
	rotation_velocity_x = 0.0
	rotation_velocity_y = 0.0

# --- Public Functions (Can be called by other scripts) ---
func set_follow_target(new_target: Node3D) -> void:
	"""Changes which player the camera follows"""
	
	if new_target and is_instance_valid(new_target):
		player = new_target
		print("Camera: Now following ", player.name)
	else:
		print("Camera: Invalid target provided")

func get_follow_target() -> Node3D:
	"""Returns the current player being followed"""
	
	return player

# --- Debug Functions ---
func _on_debug_requested() -> void:
	"""Prints debug information about camera state including momentum"""
	
	print("=== Camera Debug Info ===")
	@warning_ignore("incompatible_ternary")
	print("Player: ", player.name if player != null else "None")
	print("Position: ", global_position)
	print("Current Zoom: ", current_zoom, " | Target: ", target_zoom)
	print("Current Rotation X: ", rad_to_deg(rotation_x), " | Target: ", rad_to_deg(target_rotation_x))
	print("Current Rotation Y: ", rad_to_deg(rotation_y), " | Target: ", rad_to_deg(target_rotation_y))
	print("Momentum X: ", rotation_velocity_x, " | Y: ", rotation_velocity_y)
	print("Is Rotating: ", is_rotating)
	print("========================")
