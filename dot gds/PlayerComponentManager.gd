extends Node

class_name PlayerComponentManager

# Manages additional player components (inventory, effects, etc)
var components := {}

# Add a property to hold the controller reference
var _controller: CharacterBody3D

func initialize(controller):
	self._controller = controller

func register_component(component_name: String, component):
	components[component_name] = component

func get_component(component_name: String):
	return components.get(component_name, null)

func initialize_all():
	for component_name in components:
		var component = components[component_name]
		if component.has_method("initialize"):
			component.initialize(self._controller)
		# Connect health signals if PlayerHealth
		if component_name == "health":
			component.health_changed.connect(self._controller._on_health_changed)
			component.player_died.connect(self._controller._on_player_died)
		# Connect combat signals if PlayerCombat
		if component_name == "combat":
			component.attack_performed.connect(self._controller._on_attack_performed)
		# Connect inventory signals if PlayerInventory
		if component_name == "inventory":
			component.item_added.connect(self._controller._on_item_added)
			component.item_removed.connect(self._controller._on_item_removed)
		# Connect progression signals if PlayerProgression
		if component_name == "progression":
			component.xp_changed.connect(self._controller._on_xp_changed)
			component.coin_collected.connect(self._controller._on_coin_collected)
			component.level_up.connect(self._controller._on_level_up)
		# Connect effects signals if PlayerEffects
		if component_name == "effects":
			component.effect_triggered.connect(self._controller._on_effect_triggered)
		# Connect interaction signals if PlayerInteraction
		if component_name == "interaction":
			component.interacted.connect(self._controller._on_interacted)
