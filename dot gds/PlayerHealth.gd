extends Node

class_name PlayerHealth

# Handles player health logic
var controller
var max_health := 100
var current_health := 100
signal health_changed(current_health, max_health)
signal player_died

func initialize(new_controller):
	self.controller = new_controller
	current_health = max_health

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		player_died.emit()

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func set_max_health(value: int):
	max_health = value
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health, max_health)

func get_health():
	return current_health

func get_max_health():
	return max_health
