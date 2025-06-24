extends Node

class_name PlayerEffects

# Handles player visual/audio effects (e.g., blinking, knockback, etc.)
signal effect_triggered(effect_name)

@export var controller: CharacterBody3D  # Properly typed controller reference

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:
		push_error("PlayerEffects: Controller cannot be null")
		return
	controller = new_controller
	print("✅ PlayerEffects: Controller initialized successfully")

func trigger_effect(effect_name: String):
	effect_triggered.emit(effect_name)
	# Add effect logic here (e.g., play animation, sound, etc.)
