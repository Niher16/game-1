extends CharacterBody3D

class_name PlayerController

# Main hub for player systems
@onready var input: PlayerInput = $PlayerInput
@onready var state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var stats: PlayerStats = $PlayerStats
@onready var component_manager: PlayerComponentManager = $PlayerComponentManager
@onready var health: PlayerHealth = $PlayerHealth
@onready var combat: PlayerCombat = $PlayerCombat
@onready var inventory: PlayerInventory = $PlayerInventory
@onready var progression: PlayerProgression = $PlayerProgression
@onready var effects: PlayerEffects = $PlayerEffects
@onready var interaction: PlayerInteraction = $PlayerInteraction

func _ready():
	# Ensure correct initialization order
	stats.initialize(self)
	component_manager.initialize(self)
	component_manager.register_component("health", health)
	component_manager.register_component("combat", combat)
	component_manager.register_component("inventory", inventory)
	component_manager.register_component("progression", progression)
	component_manager.register_component("effects", effects)
	component_manager.register_component("interaction", interaction)
	component_manager.initialize_all()
	state_machine.initialize(self)
	input.initialize(self)
	print("PlayerController initialized.")

func get_stat(stat: String):
	return stats.get_stat(stat)

func set_stat(stat: String, value):
	stats.set_stat(stat, value)

func upgrade_stat(stat: String, value):
	stats.upgrade_stat(stat, value)

func register_component(component_name: String, component):
	component_manager.register_component(component_name, component)

func get_component(component_name: String):
	return component_manager.get_component(component_name)

func _on_health_changed(current_health, max_health):
	print("Health changed:", current_health, "/", max_health)
	# Update UI or other systems here

func _on_player_died():
	print("Player died!")
	# Handle player death logic here

func _on_attack_performed():
	print("Attack performed!")
	# Handle attack logic, spawn hitboxes, etc.

func _on_item_added(item):
	print("Item added to inventory:", item)
	# Update UI or other systems here

func _on_item_removed(item):
	print("Item removed from inventory:", item)
	# Update UI or other systems here

func _on_xp_changed(xp, xp_to_next, level):
	print("XP changed:", xp, "/", xp_to_next, "Level:", level)
	# Update UI or other systems here

func _on_coin_collected(total_currency):
	print("Currency changed:", total_currency)
	# Update UI or other systems here

func _on_level_up(level):
	print("Level up! New level:", level)
	# Handle level up logic here

func _on_effect_triggered(effect_name):
	print("Effect triggered:", effect_name)
	# Play VFX, SFX, or other feedback here

func _on_interacted(target):
	print("Interacted with:", target)
	# Handle interaction logic here
