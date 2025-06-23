extends Node

class_name loot_manager

# ...existing code...
@export var armor_pickup_scene: PackedScene = preload("res://Scenes/armor_pickup.tscn")
# ...existing code...
@export var enemy_loot_config = {
	"coin": {
		"drop_chance": 0.7,
		"amount_min": 8,
		"amount_max": 15
	},
	"health_potion": {
		"drop_chance": 0.2,
		"heal_amount": 30
	},
	"xp_orb": {
		"drop_chance": 1.0,
		"xp_amount_min": 8,
		"xp_amount_max": 15
	},
	"weapon": {
		"drop_chance": 0.05,
		"avoid_duplicates": true
	},
	"armor": {
		"drop_chance": 0.03,
		"avoid_duplicates": true
	}
}

@export var chest_loot_config = {
	"coin": {
		"drop_chance": 1.0,
		"amount_min": 200,
		"amount_max": 500
	},
	"health_potion": {
		"drop_chance": 1.0,
		"heal_amount": 75
	},
	"xp_orb": {
		"drop_chance": 1.0,
		"xp_amount_min": 150,
		"xp_amount_max": 300
	},
	"weapon": {
		"drop_chance": 0.8,
		"avoid_duplicates": true
	},
	"armor": {
		"drop_chance": 0.5,
		"avoid_duplicates": true
	}
}
# ...existing code...
func _drop_armor_with_physics(position: Vector3, parent: Node):
	"""Drop an armor piece with physics like weapons"""
	if not armor_pickup_scene:
		print("⚠️ No armor pickup scene available!")
		return

	if not ArmorPool:
		print("⚠️ ArmorPool not available!")
		return

	# Get random armor from pool
	var armor_resource = ArmorPool.get_random_armor()
	if not armor_resource:
		print("⚠️ No armor available from pool!")
		return

	# Create armor pickup
	var armor_pickup = armor_pickup_scene.instantiate()
	parent.add_child(armor_pickup)

	# Set the armor resource immediately
	armor_pickup.set_armor_resource(armor_resource)
	# Mark as coming from physics for pickup delay
	armor_pickup.set_meta("from_physics", true)

	# Apply physics launch
	_launch_with_physics(armor_pickup, position)

	print("🛡️ Dropped armor with physics: ", armor_resource.armor_name)
# ...existing code...
func drop_enemy_loot(position: Vector3, enemy_node: Node = null):
	# ...existing code...
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)
	# ...existing code...
func drop_chest_loot(position: Vector3, chest_node: Node = null):
	# ...existing code...
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)
	# ...existing code...
# ...existing code...
