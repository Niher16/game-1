# ArmorPool.gd - Autoload for managing armor spawning (similar to WeaponPool.gd)
# Add this as an AutoLoad in Project Settings
extends Node

# Armor pool organized by rarity/power level
var armor_pools = {
	"common": [],
	"uncommon": [],
	"rare": [],
	"legendary": []
}

# Spawn chances by pool (adjust these for balance)
var pool_weights = {
	"common": 55,
	"uncommon": 30,
	"rare": 12,
	"legendary": 3
}

# Track armor found this run (for variety)
var armor_found_this_run: Array[String] = []
var avoid_duplicates = true

func _ready():
	print("🛡️ ArmorPool: Initializing armor database...")
	_load_all_armor()

func _load_all_armor():
	"""Load all armor resources from the Armors folder"""
	# Common armor (starting tier)
	_add_armor_to_pool("res://Armors/leather_helmet.tres", "common")
	_add_armor_to_pool("res://Armors/leather_boots.tres", "common")
	
	# Uncommon armor (mid-tier)
	_add_armor_to_pool("res://Armors/iron_chestplate.tres", "uncommon")
	_add_armor_to_pool("res://Armors/steel_boots.tres", "uncommon")
	_add_armor_to_pool("res://Armors/iron_helmet.tres", "uncommon")
	
	# Rare armor (high-tier)
	_add_armor_to_pool("res://Armors/mithril_shield.tres", "rare")
	_add_armor_to_pool("res://Armors/steel_chestplate.tres", "rare")
	
	# Legendary armor
	_add_armor_to_pool("res://Armors/dragon_scale_armor.tres", "legendary")
	
	print("✅ ArmorPool: Loaded armor pieces - Common: ", armor_pools["common"].size(),
		  ", Uncommon: ", armor_pools["uncommon"].size(),
		  ", Rare: ", armor_pools["rare"].size(), 
		  ", Legendary: ", armor_pools["legendary"].size())

func _add_armor_to_pool(armor_path: String, rarity: String):
	"""Add an armor resource to the specified pool"""
	if ResourceLoader.exists(armor_path):
		var armor = load(armor_path) as ArmorResource
		if armor:
			armor_pools[rarity].append(armor)
			print("📦 Added ", armor.armor_name, " to ", rarity, " pool")
	else:
		print("⚠️ Armor not found: ", armor_path)

func get_random_armor(avoid_recent: bool = true) -> ArmorResource:
	"""Get a random armor piece, optionally avoiding recently found ones"""
	
	# Choose rarity tier based on weights
	var total_weight = 0
	for weight in pool_weights.values():
		total_weight += weight
	
	var random_value = randi_range(1, total_weight)
	var current_weight = 0
	var chosen_pool = "common"
	
	for pool_name in pool_weights.keys():
		current_weight += pool_weights[pool_name]
		if random_value <= current_weight:
			chosen_pool = pool_name
			break
	
	# Get armor from chosen pool
	var pool = armor_pools[chosen_pool]
	if pool.is_empty():
		print("⚠️ No armor in ", chosen_pool, " pool, using common")
		pool = armor_pools["common"]
	
	if pool.is_empty():
		print("❌ No armor available in any pool!")
		return null
	
	# Filter out recently found armor if requested
	var available_armor = pool.duplicate()
	if avoid_recent and avoid_duplicates:
		for armor in pool:
			if armor.armor_name in armor_found_this_run:
				available_armor.erase(armor)
		
		# If all armor was filtered out, use original pool
		if available_armor.is_empty():
			available_armor = pool
	
	# Select random armor
	var selected_armor = available_armor[randi() % available_armor.size()]
	
	# Track selection
	if selected_armor.armor_name not in armor_found_this_run:
		armor_found_this_run.append(selected_armor.armor_name)
	
	print("🛡️ Selected ", selected_armor.armor_name, " from ", chosen_pool, " pool")
	return selected_armor

func get_armor_by_type(armor_type: ArmorResource.ArmorType, rarity: String = "") -> ArmorResource:
	"""Get a specific type of armor, optionally from specific rarity"""
	var search_pools = []
	
	if rarity.is_empty():
		# Search all pools
		for pool in armor_pools.values():
			search_pools.append_array(pool)
	else:
		# Search specific rarity
		if rarity in armor_pools:
			search_pools = armor_pools[rarity]
	
	# Find armor of specified type
	for armor in search_pools:
		if armor.armor_type == armor_type:
			return armor
	
	print("⚠️ No armor found for type: ", armor_type)
	return null

func get_armor_by_level(player_level: int) -> ArmorResource:
	"""Get armor appropriate for player level"""
	var suitable_armor = []
	
	# Collect all armor the player can use
	for pool in armor_pools.values():
		for armor in pool:
			if armor.level_requirement <= player_level:
				suitable_armor.append(armor)
	
	if suitable_armor.is_empty():
		print("⚠️ No suitable armor for level ", player_level)
		return get_random_armor(false)  # Fallback to any armor
	
	return suitable_armor[randi() % suitable_armor.size()]

func reset_found_armor():
	"""Reset the found armor list (call on new run/level)"""
	armor_found_this_run.clear()
	print("🔄 ArmorPool: Reset found armor list")

func get_pool_stats() -> Dictionary:
	"""Get statistics about armor pools"""
	return {
		"common_count": armor_pools["common"].size(),
		"uncommon_count": armor_pools["uncommon"].size(),
		"rare_count": armor_pools["rare"].size(),
		"legendary_count": armor_pools["legendary"].size(),
		"total_found": armor_found_this_run.size()
	}

# --- Integration with existing loot system ---

func add_armor_to_loot_drop(drop_position: Vector3, source: Node = null):
	"""Add armor to existing loot drops"""
	var armor = get_random_armor()
	if armor:
		_spawn_armor_pickup(armor, drop_position)

func _spawn_armor_pickup(armor: ArmorResource, position: Vector3):
	"""Spawn an armor pickup in the world"""
	# Check if armor pickup scene exists
	var armor_pickup_scene = load("res://Scenes/armor_pickup.tscn") if ResourceLoader.exists("res://Scenes/armor_pickup.tscn") else null
	
	if not armor_pickup_scene:
		print("⚠️ No armor_pickup.tscn found - creating simple armor pickup")
		_create_simple_armor_pickup(armor, position)
		return
	
	var pickup = armor_pickup_scene.instantiate()
	pickup.armor_resource = armor
	pickup.global_position = position
	
	# Add to scene
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		scene_tree.current_scene.add_child(pickup)
		print("🛡️ Spawned ", armor.armor_name, " pickup at ", position)

func _create_simple_armor_pickup(armor: ArmorResource, position: Vector3):
	"""Create a simple armor pickup if no scene exists"""
	var pickup = Area3D.new()
	pickup.name = "ArmorPickup_" + armor.armor_name
	pickup.position = position
	pickup.add_to_group("armor_pickups")
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	pickup.add_child(collision)
	
	# Add visual based on armor type
	var mesh_instance = MeshInstance3D.new()
	var material = StandardMaterial3D.new()
	material.albedo_color = _get_armor_color(armor)
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	
	match armor.armor_type:
		ArmorResource.ArmorType.HELMET:
			mesh_instance.mesh = SphereMesh.new()
		ArmorResource.ArmorType.CHESTPLATE:
			mesh_instance.mesh = BoxMesh.new()
		ArmorResource.ArmorType.BOOTS:
			var box = BoxMesh.new()
			box.size = Vector3(0.8, 0.4, 1.2)
			mesh_instance.mesh = box
		ArmorResource.ArmorType.SHIELD:
			mesh_instance.mesh = CylinderMesh.new()
		_:
			mesh_instance.mesh = BoxMesh.new()
	
	mesh_instance.material_override = material
	mesh_instance.position.y = 0.5
	pickup.add_child(mesh_instance)
	
	# Add pickup functionality
	pickup.body_entered.connect(_on_armor_pickup_entered.bind(pickup, armor))
	
	# Add to scene
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		scene_tree.current_scene.add_child(pickup)

func _get_armor_color(armor: ArmorResource) -> Color:
	"""Get color based on armor material and rarity"""
	var base_color = Color.WHITE
	
	match armor.armor_material:
		ArmorResource.ArmorMaterial.LEATHER:
			base_color = Color(0.6, 0.4, 0.2)
		ArmorResource.ArmorMaterial.IRON:
			base_color = Color(0.7, 0.7, 0.7)
		ArmorResource.ArmorMaterial.STEEL:
			base_color = Color(0.8, 0.8, 0.9)
		ArmorResource.ArmorMaterial.MITHRIL:
			base_color = Color(0.9, 0.9, 1.0)
		ArmorResource.ArmorMaterial.DRAGON_SCALE:
			base_color = Color(0.8, 0.2, 0.2)
	
	# Modify by rarity
	match armor.rarity:
		2:  # Uncommon
			base_color = base_color.lerp(Color.GREEN, 0.2)
		3:  # Rare
			base_color = base_color.lerp(Color.BLUE, 0.3)
		4:  # Legendary
			base_color = base_color.lerp(Color.GOLD, 0.4)
	
	return base_color

func _on_armor_pickup_entered(pickup: Area3D, armor: ArmorResource, body: Node3D):
	"""Handle armor pickup"""
	if body.is_in_group("player"):
		var player = body
		if player.has_method("get") and player.get("armor_component"):
			if player.armor_component.equip_armor(armor):
				print("✅ Player equipped ", armor.armor_name)
				pickup.queue_free()
			else:
				print("❌ Could not equip ", armor.armor_name)
		else:
			print("❌ Player has no armor component")
