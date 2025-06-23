extends Node

class_name loot_manager

@export var weapon_pickup_scene: PackedScene = preload("res://Scenes/weapon_pickup.tscn")
@export var armor_pickup_scene: PackedScene = preload("res://Scenes/armor_pickup.tscn")
@export var health_potion_scene: PackedScene = preload("res://Scenes/health_potion.tscn")

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

func _launch_with_physics(loot_item: Node, spawn_position: Vector3):
	# Safety checks
	if not loot_item:
		print("⚠️ loot_item is null in _launch_with_physics!")
		return
	loot_item.global_transform.origin = spawn_position
	# If loot_item has a RigidBody3D, apply impulse for physics effect
	if loot_item.has_node("RigidBody3D"):
		var body = loot_item.get_node("RigidBody3D")
		body.global_transform.origin = spawn_position
		var impulse = Vector3(randf_range(-2,2), randf_range(4,7), randf_range(-2,2))
		body.apply_impulse(Vector3.ZERO, impulse)
	else:
		print("⚠️ loot_item has no RigidBody3D for physics!")

func _drop_weapon_with_physics(position: Vector3, parent: Node):
	if not weapon_pickup_scene:
		print("⚠️ No weapon pickup scene available!")
		return
	if not WeaponPool:
		print("⚠️ WeaponPool not available!")
		return
	var weapon_resource = WeaponPool.get_random_weapon()
	if not weapon_resource:
		print("⚠️ No weapon available from pool!")
		return
	var weapon_pickup_instance = weapon_pickup_scene.instantiate()
	if not weapon_pickup_instance:
		print("⚠️ Failed to instantiate weapon pickup!")
		return
	parent.add_child(weapon_pickup_instance)
	weapon_pickup_instance.set_weapon_resource(weapon_resource)
	weapon_pickup_instance.set_meta("from_physics", true)
	_launch_with_physics(weapon_pickup_instance, position)
	print("🗡️ Dropped weapon with physics: ", weapon_resource.weapon_name)

func drop_enemy_loot(position: Vector3, _enemy_node: Node = null):
	var config = enemy_loot_config
	var parent_node = _get_drop_parent()
	# Coins
	if randf() <= config["coin"]["drop_chance"]:
		var coin_amount = randi_range(config["coin"]["amount_min"], config["coin"]["amount_max"])
		_get_node("coin_manager").add_coins(coin_amount)
		print("💰 Dropped coins: ", coin_amount)

	# Health Potion
	if randf() <= config["health_potion"]["drop_chance"]:
		_drop_health_potion(position, parent_node)

	# XP Orb
	if randf() <= config["xp_orb"]["drop_chance"]:
		var xp_amount = randi_range(config["xp_orb"]["xp_amount_min"], config["xp_orb"]["xp_amount_max"])
		_get_node("xp_manager").add_xp(xp_amount)
		print("✨ Dropped XP Orb: ", xp_amount)

	# Weapon
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)

func drop_chest_loot(position: Vector3, _chest_node: Node = null):
	var config = chest_loot_config
	var parent_node = _get_drop_parent()
	# Coins
	if randf() <= config["coin"]["drop_chance"]:
		var coin_amount = randi_range(config["coin"]["amount_min"], config["coin"]["amount_max"])
		_get_node("coin_manager").add_coins(coin_amount)
		print("💰 Dropped coins: ", coin_amount)

	# Health Potion
	if randf() <= config["health_potion"]["drop_chance"]:
		_drop_health_potion(position, parent_node)

	# XP Orb
	if randf() <= config["xp_orb"]["drop_chance"]:
		var xp_amount = randi_range(config["xp_orb"]["xp_amount_min"], config["xp_orb"]["xp_amount_max"])
		_get_node("xp_manager").add_xp(xp_amount)
		print("✨ Dropped XP Orb: ", xp_amount)

	# Weapon
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)

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
	var armor_pickup_instance = armor_pickup_scene.instantiate()
	if not armor_pickup_instance:
		print("⚠️ Failed to instantiate armor pickup!")
		return
	parent.add_child(armor_pickup_instance)
	# Set the armor resource immediately
	armor_pickup_instance.set_armor_resource(armor_resource)
	# Mark as coming from physics for pickup delay
	armor_pickup_instance.set_meta("from_physics", true)
	# Apply physics launch
	_launch_with_physics(armor_pickup_instance, position)
	print("🛡️ Dropped armor with physics: ", armor_resource.armor_name)

func _get_drop_parent() -> Node:
	# Returns the node to which loot should be added. Defaults to self if not overridden.
	return self

func _get_node(node_name: String) -> Node:
	# Helper to get a child node by name, with error handling
	if has_node(node_name):
		return get_node(node_name)
	print("⚠️ Node not found: ", node_name)
	return null

func _drop_health_potion(position: Vector3, parent: Node):
	if not health_potion_scene:
		print("⚠️ No health potion scene available!")
		return
	var potion_instance = health_potion_scene.instantiate()
	if not potion_instance:
		print("⚠️ Failed to instantiate health potion!")
		return
	parent.add_child(potion_instance)
	potion_instance.global_transform.origin = position
	# Optionally, add physics or animation here
	print("🧪 Dropped health potion at ", position)
