# GDScript Template
# Purpose: [Describe what this script does]
# Author: Thane
# Last Modified: [YYYY-MM-DD]
#
# Godot Version: 4.x
#
# ---
# Exported Variables (visible in editor)
@export var example_exported_var: int = 0 # Example exported variable

# Private Variables (not visible in editor)
var _example_private_var: int = 0 # Example private variable

# ---
# Built-in Godot Functions
func _ready() -> void:
	# Called when the node is added to the scene
	# ...existing code...
	_example_private_var += 1 # Example usage to avoid unused variable warning
	pass

# ---
# Custom Functions
# Each function should have a single responsibility and clear comments
func example_function() -> void:
	# Explain what and why
	pass

# ---
# Error Handling Example (for scripts that extend Node)
# The following function ONLY works if your script extends Node, Node2D, Node3D, etc.
# If your script does NOT extend Node, do not use this function (or comment it out).
#
# func safe_get_node(node_path: NodePath) -> Node:
# 	# Returns the node if it exists, else null
# 	if has_node(node_path):
# 		return get_node(node_path)
# 	return null

# ---
# Notes:
# - Use descriptive variable names
# - Break complex logic into smaller functions
# - Use signals for loose coupling
# - Always check if nodes/resources exist before using them
# - Handle edge cases
# - Add comments explaining Godot-specific concepts
