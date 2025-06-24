extends Node

class_name PlayerEffects

# Handles player visual/audio effects (e.g., blinking, knockback, etc.)
signal effect_triggered(effect_name)

func initialize(controller):
	self.controller = controller

func trigger_effect(effect_name: String):
	effect_triggered.emit(effect_name)
	# Add effect logic here (e.g., play animation, sound, etc.)
