extends Node

class_name PlayerStateMachine

# Handles player state transitions
var current_state := "idle"

func initialize(_controller):
	# Reference to PlayerController if needed
	pass

func set_state(new_state: String):
	current_state = new_state
	# Handle state entry/exit logic
	pass

func handle_input(event, move_vector, _look_vector):
	# Example: basic state transitions
	if event.is_action_pressed("attack"):
		set_state("attacking")
	elif event.is_action_pressed("dash"):
		set_state("dashing")
	elif move_vector.length() > 0.1:
		set_state("moving")
	else:
		set_state("idle")

func _enter_state(_state):
	# Add logic for entering a state
	pass

func _exit_state(_state):
	# Add logic for exiting a state
	pass
