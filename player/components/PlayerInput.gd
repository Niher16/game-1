extends Node

class_name PlayerInput

# Handles all player input
var move_vector := Vector2.ZERO
var look_vector := Vector2.ZERO
@export var controller: CharacterBody3D  # Properly typed controller reference

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:
		push_error("PlayerInput: Controller cannot be null")
		return
	controller = new_controller
	print("✅ PlayerInput: Controller initialized successfully")

func _unhandled_input(event):
	# Keyboard movement
	move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_vector.length() < 0.2:
		move_vector = Vector2.ZERO
	# Mouse/controller look
	look_vector.x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
	look_vector.y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	if look_vector.length() < 0.2:
		look_vector = Vector2.ZERO
	# Example: pass input to state machine if needed
	if controller and controller.state_machine:
		controller.state_machine.handle_input(event, move_vector, look_vector)
	# Process input events and update move_vector, look_vector
	pass
