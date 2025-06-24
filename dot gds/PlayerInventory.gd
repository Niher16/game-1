extends Node

class_name PlayerInventory

# Handles player inventory logic
signal item_added(item)
signal item_removed(item)

var items := []

@export var controller: CharacterBody3D  # Properly typed controller reference

func initialize(new_controller: CharacterBody3D) -> void:
	if not new_controller:  # Null safety check
		push_error("PlayerInventory: Controller cannot be null")
		return
	controller = new_controller  # Now properly typed assignment
	print("✅ PlayerInventory: Controller initialized successfully")

func add_item(item):
	items.append(item)
	item_added.emit(item)

func remove_item(item):
	if item in items:
		items.erase(item)
		item_removed.emit(item)

func has_item(item):
	return item in items

func get_items():
	return items.duplicate()
