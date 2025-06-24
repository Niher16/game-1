extends Node

class_name PlayerStats

# Stores and manages player stats
var health := 100
var speed := 5.0
var damage := 10

@export var controller: CharacterBody3D  # Properly typed controller reference

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:
		push_error("PlayerStats: Controller cannot be null")
		return
	controller = new_controller
	print("✅ PlayerStats: Controller initialized successfully")

func upgrade_stat(stat: String, value):
	# Upgrade a stat by value
	if has_node(stat):
		self.set(stat, self.get(stat) + value)

func get_stat(stat: String):
	if has_node(stat):
		return self.get(stat)
	return null

func set_stat(stat: String, value):
	if has_node(stat):
		self.set(stat, value)
