extends Node

class_name loot_manager

@export var weapon_pickup_scene: PackedScene = preload("res://Scenes/weapon_pickup.tscn")
@export var armor_pickup_scene: PackedScene = preload("res://Scenes/armor_pickup.tscn")
@export var health_potion_scene: PackedScene = preload("res://Scenes/health_potion.tscn")
@export var coin_scene: PackedScene = preload("res://Scenes/coin.tscn")
@export var xp_orb_scene: PackedScene = preload("res://Scenes/xp_orb.tscn")

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

# --- XP Manager Safe Reference System ---
# (Removed problematic @onready var xp_manager_node line)
@onready var xp_manager = null

var launch_force_min = 10.0
var launch_force_max = 20.0
var upward_force = 5.0
var pickup_delay = 0.5 # Delay before pickup is available

func _launch_with_physics(loot_item: Node, spawn_position: Vector3):
	"""FIXED: Convert item to RigidBody3D safely, launch it, then convert back"""
	# Validate inputs first
	if not is_instance_valid(loot_item) or not loot_item.get_parent():
		push_error("Invalid loot_item passed to _launch_with_physics")
		return

	# Store ALL original data before modification
	var original_data = {
		"scene_file": loot_item.scene_file_path if loot_item.has_method("get_scene_file_path") else "",
		"groups": loot_item.get_groups(),
		"position": loot_item.global_position,
		"metadata": {}
	}

	# Store all metadata
	for meta_key in loot_item.get_meta_list():
		original_data.metadata[meta_key] = loot_item.get_meta(meta_key)

	# Get visual components safely
	var mesh_node = loot_item.get_node_or_null("MeshInstance3D")
	if not mesh_node:
		mesh_node = loot_item.get_children().filter(func(child): return child is MeshInstance3D).front()

	if mesh_node:
		original_data["mesh"] = mesh_node.mesh
		original_data["material"] = mesh_node.material_override
		original_data["scale"] = mesh_node.scale

	# Create physics version
	var physics_body = _create_safe_physics_body(original_data, spawn_position)
	if not physics_body:
		return

	# Replace original with physics body
	var parent = loot_item.get_parent()
	loot_item.queue_free()
	parent.add_child(physics_body)

	# Apply launch forces
	var direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var force = randf_range(launch_force_min, launch_force_max)
	physics_body.linear_velocity = direction * force + Vector3(0, upward_force, 0)

	# Convert back after settling
	_wait_for_settle_and_convert(physics_body, original_data)

func _create_physics_coin(position: Vector3, parent: Node, amount: int):
	if not coin_scene:
		push_error("No coin scene available!")
		return
	if not parent:
		push_error("No parent node for coin spawn!")
		return
	
	var coin_instance = coin_scene.instantiate()
	if not coin_instance:
		push_error("Failed to instantiate coin!")
		return
	
	parent.add_child(coin_instance)
	
	# Set coin value safely
	if coin_instance.has_method("set_coin_value"):
		coin_instance.set_coin_value(amount)
		print("[DEBUG] set_coin_value method used for coin:", amount)
	else:
		coin_instance.set_meta("coin_value", amount)
		print("[DEBUG] set_meta fallback for coin_value:", amount)
	
	print("💰 Spawned coin pickup:", amount)
	
	# Apply physics launch
	_launch_with_physics(coin_instance, position)

func _drop_weapon_with_physics(position: Vector3, parent: Node):
	if not weapon_pickup_scene:
		push_error("No weapon pickup scene available!")
		return
	if not WeaponPool:
		push_error("WeaponPool not available!")
		return
	var weapon_resource = WeaponPool.get_random_weapon()
	if not weapon_resource:
		push_error("No weapon available from pool!")
		return
	var weapon_pickup_instance = weapon_pickup_scene.instantiate()
	if not weapon_pickup_instance:
		push_error("Failed to instantiate weapon pickup!")
		return
	parent.add_child(weapon_pickup_instance)
	weapon_pickup_instance.set_weapon_resource(weapon_resource)
	weapon_pickup_instance.set_meta("from_physics", true)
	_launch_with_physics(weapon_pickup_instance, position)
	print("🗡️ Dropped weapon with physics: ", weapon_resource.weapon_name)

func drop_enemy_loot(position: Vector3, _enemy_node: Node = null):
	var config = enemy_loot_config
	var parent_node = _get_drop_parent()
	if not parent_node:
		push_error("No parent node for enemy loot drop!")
		return
	# Coins
	if randf() <= config["coin"]["drop_chance"]:
		var coin_amount = randi_range(config["coin"]["amount_min"], config["coin"]["amount_max"])
		_create_physics_coin(position, parent_node, coin_amount)
	# Health Potion
	if randf() <= config["health_potion"]["drop_chance"]:
		_drop_health_potion(position, parent_node)
	# XP Orb
	if randf() <= config["xp_orb"]["drop_chance"]:
		var xp_amount = randi_range(config["xp_orb"]["xp_amount_min"], config["xp_orb"]["xp_amount_max"])
		_create_physics_xp_orb({"xp_amount_min": xp_amount, "xp_amount_max": xp_amount}, position, parent_node)
	# Weapon
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)

func drop_chest_loot(position: Vector3, _chest_node: Node = null):
	var config = chest_loot_config
	var parent_node = _get_drop_parent()
	if not parent_node:
		push_error("No parent node for chest loot drop!")
		return
	if not coin_scene or not health_potion_scene or not weapon_pickup_scene or not armor_pickup_scene:
		push_error("One or more loot scenes are missing! Loot drop aborted.")
		return
	# Coins
	if randf() <= config["coin"]["drop_chance"]:
		var coin_amount = randi_range(config["coin"]["amount_min"], config["coin"]["amount_max"])
		_create_physics_coin(position, parent_node, coin_amount)
	# Health Potion
	if randf() <= config["health_potion"]["drop_chance"]:
		_drop_health_potion(position, parent_node)
	# XP Orb
	if randf() <= config["xp_orb"]["drop_chance"]:
		var xp_amount = randi_range(config["xp_orb"]["xp_amount_min"], config["xp_orb"]["xp_amount_max"])
		_create_physics_xp_orb({"xp_amount_min": xp_amount, "xp_amount_max": xp_amount}, position, parent_node)
	# Weapon
	if randf() <= config["weapon"]["drop_chance"]:
		_drop_weapon_with_physics(position, parent_node)
	if randf() <= config["armor"]["drop_chance"]:
		_drop_armor_with_physics(position, parent_node)

func _drop_armor_with_physics(position: Vector3, parent: Node):
	if not armor_pickup_scene:
		push_error("No armor pickup scene available!")
		return
	# --- Armor Pool Empty Protection ---
	if not ArmorPool:
		push_error("ArmorPool not available!")
		return
	if not ArmorPool.has_method("get_random_armor"):
		push_error("ArmorPool missing get_random_armor() method!")
		return
	if ArmorPool.get_armor_count and ArmorPool.get_armor_count() == 0:
		push_error("[ERROR] ArmorPool is empty! No armor to drop.")
		return
	var armor_resource = ArmorPool.get_random_armor()
	if not armor_resource:
		push_error("No armor available from pool!")
		return
	var armor_pickup_instance = armor_pickup_scene.instantiate()
	if not armor_pickup_instance:
		push_error("Failed to instantiate armor pickup!")
		return
	parent.add_child(armor_pickup_instance)
	armor_pickup_instance.set_armor_resource(armor_resource)
	armor_pickup_instance.set_meta("from_physics", true)
	_launch_with_physics(armor_pickup_instance, position)
	print("🛡️ Dropped armor with physics: ", armor_resource.armor_name)

func _get_drop_parent() -> Node:
	# Try to find the main scene or current scene first
	var main_scene = get_tree().current_scene
	if main_scene:
		return main_scene
	# Fallback to self if no scene found
	return self

# Step 5: Health potion with physics
func _drop_health_potion(position: Vector3, parent: Node):
	if not health_potion_scene:
		push_error("No health potion scene available!")
		return
	if not parent:
		push_error("No parent node for health potion!")
		return
	
	var potion_instance = health_potion_scene.instantiate()
	if not potion_instance:
		push_error("Failed to instantiate health potion!")
		return
	
	parent.add_child(potion_instance)
	
	# Set heal amount if method exists
	if potion_instance.has_method("set_heal_amount"):
		potion_instance.set_heal_amount(75)  # Default chest heal amount
	
	print("🧪 Dropped health potion at ", position)
	
	# Apply physics launch
	_launch_with_physics(potion_instance, position)


# Helper: Create a RigidBody3D with loot visuals and metadata
func _create_safe_physics_body(original_data: Dictionary, spawn_position: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.global_position = spawn_position
	body.name = "LootPhysicsBody"
	
	# Set collision layers
	body.collision_layer = 1 << 7  # Layer 8
	body.collision_mask = 1 << 0   # Terrain layer
	
	# Physics properties
	body.mass = 0.1
	body.gravity_scale = 1.0
	body.linear_damp = 0.5
	body.angular_damp = 0.8
	
	# Create visual mesh
	if original_data.has("mesh") and original_data["mesh"]:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = original_data["mesh"]
		if original_data.has("material") and original_data["material"]:
			mesh_instance.material_override = original_data["material"]
		if original_data.has("scale"):
			mesh_instance.scale = original_data["scale"]
		body.add_child(mesh_instance)
	
	# CRITICAL: Create collision shape (this was missing!)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	collision.shape = shape
	body.add_child(collision)
	
	# Restore groups and metadata
	for group in original_data.get("groups", []):
		body.add_to_group(group)
	for meta_key in original_data.get("metadata", {}).keys():
		body.set_meta(meta_key, original_data["metadata"][meta_key])
	
	# Store original data for conversion back
	body.set_meta("original_data", original_data)
	
	return body

# Helper: Wait for settle, then convert back to original loot
func _wait_for_settle_and_convert(physics_body: RigidBody3D, original_data: Dictionary):
	# Wait for physics to settle
	await get_tree().create_timer(0.8).timeout
	# Check if body still exists
	if not is_instance_valid(physics_body):
		return
	# Convert back using the proper conversion function
	_convert_to_pickup_item(physics_body, original_data)

# Convert physics body back to working pickup item
func _convert_to_pickup_item(physics_body: RigidBody3D, data: Dictionary):
	"""Convert physics body back to working pickup item"""
	if not is_instance_valid(physics_body):
		return
	var final_position = physics_body.global_position
	var parent = physics_body.get_parent()
	var pickup_item: Area3D = null
	var item_type = ""
	# Better type detection - check metadata first, then groups
	if data.get("metadata", {}).has("coin_value"):
		item_type = "coin"
	elif data.get("metadata", {}).has("xp_value"):
		item_type = "xp_orb"
	elif data.get("metadata", {}).has("heal_amount"):
		item_type = "health_potion"
	else:
		# Fallback to group checking
		for group in data.get("groups", []):
			if group == "currency" or group == "coin":
				item_type = "coin"
				break
			elif group == "xp_orb":
				item_type = "xp_orb"
				break
			elif group == "health_potion":
				item_type = "health_potion"
				break
	# Create appropriate pickup item
	match item_type:
		"coin":
			pickup_item = coin_scene.instantiate()
			var coin_value = data.get("metadata", {}).get("coin_value", 10)
			if pickup_item.has_method("set_coin_value"):
				pickup_item.set_coin_value(coin_value)
		"xp_orb":
			pickup_item = xp_orb_scene.instantiate()
			var xp_value = data.get("metadata", {}).get("xp_value", 10)
			if pickup_item.has_method("set_xp_value"):
				pickup_item.set_xp_value(xp_value)
		"health_potion":
			pickup_item = health_potion_scene.instantiate()
			var heal_amount = data.get("metadata", {}).get("heal_amount", 30)
			if pickup_item.has_method("set_heal_amount"):
				pickup_item.set_heal_amount(heal_amount)
	if pickup_item:
		# Remove physics body and add pickup
		physics_body.queue_free()
		parent.add_child(pickup_item)
		pickup_item.global_position = final_position
		# Brief pickup delay
		pickup_item.set_meta("pickup_disabled", true)
		await get_tree().create_timer(pickup_delay).timeout
		if is_instance_valid(pickup_item):
			pickup_item.set_meta("pickup_disabled", false)
			print("✅ ", item_type, " ready for pickup!")

# Godot 4.1+ compatibility wrapper for safe property/method setting
func safe_set_property(object: Node, method_name: String, value) -> bool:
	if object and is_instance_valid(object) and object.has_method(method_name):
		object.call(method_name, value)
		return true
	return false

# Add this function to safely find XP manager
func _get_xp_manager():
	if not xp_manager:
		# Try multiple ways to find XP manager
		xp_manager = get_node_or_null("/root/XPManager")
		if not xp_manager:
			xp_manager = get_tree().get_first_node_in_group("xp_manager")
		if not xp_manager:
			# Look for ProgressionComponent on player
			var player = get_tree().get_first_node_in_group("player")
			if player:
				xp_manager = player.get_node_or_null("ProgressionComponent")
	return xp_manager

func _create_physics_xp_orb(loot_data: Dictionary, position: Vector3, parent: Node):
	"""Create XP orb with proper XP value"""
	if not xp_orb_scene:
		push_error("XP orb scene not loaded!")
		return
	var orb = xp_orb_scene.instantiate()
	parent.add_child(orb)
	# Set XP value more reliably
	var xp_amount = randi_range(loot_data.get("xp_amount_min", 10), loot_data.get("xp_amount_max", 10))
	if orb.has_method("set_xp_value"):
		orb.set_xp_value(xp_amount)
	else:
		# Fallback: set as metadata
		orb.set_meta("xp_value", xp_amount)
	print("✅ Created XP orb with ", xp_amount, " XP")
	# Apply physics launch
	_launch_with_physics(orb, position)
