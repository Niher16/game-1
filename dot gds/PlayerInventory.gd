extends Node

class_name PlayerInventory

# Handles player inventory logic
signal item_added(item)
signal item_removed(item)

var items := []

func initialize(controller):
	self.controller = controller

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
