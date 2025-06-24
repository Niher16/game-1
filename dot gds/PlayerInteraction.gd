extends Node

class_name PlayerInteraction

# Handles player interaction logic (e.g., picking up items, talking to NPCs)
signal interacted(target)

func initialize(controller):
	self.controller = controller

func interact_with(target):
	# Implement interaction logic here
	interacted.emit(target)
