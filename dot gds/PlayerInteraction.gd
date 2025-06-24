extends Node

class_name PlayerInteraction

# Handles player interaction logic (e.g., picking up items, talking to NPCs)
signal interacted(target)

@export var controller: CharacterBody3D  # Properly typed controller reference

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:
		push_error("PlayerInteraction: Controller cannot be null")
		return
	controller = new_controller
	print("✅ PlayerInteraction: Controller initialized successfully")

func interact_with(target):
	# Implement interaction logic here
	interacted.emit(target)
