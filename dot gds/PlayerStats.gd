extends Node

class_name PlayerStats

# Stores and manages player stats
var health := 100
var speed := 5.0
var damage := 10

func initialize(_controller):
	# Reference to PlayerController if needed
	pass

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
