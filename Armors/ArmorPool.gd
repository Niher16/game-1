extends Node

# ArmorPool is an autoload singleton that manages pools of armor pieces by rarity.
# It loads all .tres armor resources from the "Armors" folder and provides random selection.

# Dictionary to store armor pools by rarity
var armor_pools: Dictionary = {
	"common": [],
	"uncommon": [],
	"rare": [],
	"legendary": []
}

# Spawn chances by pool (adjust these for balance)
var pool_weights = {
	"common": 60,
	"uncommon": 25,
	"rare": 12,
	"legendary": 3
}

# Track armors found this run (for variety)
var armors_found_this_run: Array[String] = []
var avoid_duplicates = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("🛡️ ArmorPool: Initializing armor database...")
	_load_all_armors()

# Loads all .tres armor resources from the Armors folder and organizes them by rarity.
func _load_all_armors() -> void:
	# Clear pools
	armor_pools = {
		"common": [],
		"uncommon": [],
		"rare": [],
		"legendary": []
	}
	var dir = DirAccess.open("res://Armors")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				_add_armor_to_pool("res://Armors/%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		print("✅ ArmorPool: Loaded armors - Common: ", armor_pools["common"].size(),
			  ", Uncommon: ", armor_pools["uncommon"].size(),
			  ", Rare: ", armor_pools["rare"].size(), 
			  ", Legendary: ", armor_pools["legendary"].size())
	else:
		push_warning("Could not open Armors directory.")

func _add_armor_to_pool(armor_path: String):
	"""Add an armor resource to the specified pool by its rarity property"""
	if ResourceLoader.exists(armor_path):
		var armor = load(armor_path)
		if armor and armor.has_property("armor_name") and armor.has_property("armor_type"):
			var rarity = "common"
			if armor.has_property("rarity"):
				rarity = armor.rarity
			elif armor.has_method("get_rarity"):
				rarity = armor.get_rarity()
			if armor_pools.has(rarity):
				armor_pools[rarity].append(armor)
				print("📦 Added ", armor.armor_name, " to ", rarity, " pool")
	else:
		print("⚠️ Armor not found: ", armor_path)

# Returns a random armor resource from the specified rarity pool.
# If no rarity is specified, chooses from all pools.
func get_random_armor(avoid_recent: bool = true):
	"""Get a random armor, optionally avoiding recently found ones"""
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
	# Get armors from chosen pool
	var available_armors = armor_pools[chosen_pool]
	# Filter out recently found armors if requested
	if avoid_recent and avoid_duplicates:
		var filtered_armors = []
		for armor in available_armors:
			if armor.armor_name not in armors_found_this_run:
				filtered_armors.append(armor)
		# Use filtered list if it's not empty
		if filtered_armors.size() > 0:
			available_armors = filtered_armors
	# Return random armor from available pool
	if available_armors.size() > 0:
		var chosen_armor = available_armors[randi() % available_armors.size()]
		# Track this armor as found
		if chosen_armor.armor_name not in armors_found_this_run:
			armors_found_this_run.append(chosen_armor.armor_name)
		print("🎲 ArmorPool: Selected ", chosen_armor.armor_name, " from ", chosen_pool, " pool")
		return chosen_armor
	# Fallback - return any armor if pools are empty
	return _get_any_armor()

func _get_any_armor():
	"""Fallback method to get any available armor"""
	for pool in armor_pools.values():
		if pool.size() > 0:
			return pool[0]
	print("⚠️ ArmorPool: No armors available!")
	return null

func get_armor_by_name(armor_name: String):
	"""Get a specific armor by name"""
	for pool in armor_pools.values():
		for armor in pool:
			if armor.armor_name == armor_name:
				return armor
	return null

func get_armors_by_rarity(rarity: String) -> Array:
	"""Get all armors of a specific rarity"""
	return armor_pools.get(rarity, [])

func reset_found_armors():
	"""Reset the list of found armors (call when starting new run)"""
	armors_found_this_run.clear()
	print("🔄 ArmorPool: Reset found armors list")

func print_armor_stats():
	"""Print current armor pool statistics"""
	print("=== ARMOR POOL STATS ===")
	for pool_name in armor_pools.keys():
		print(pool_name.capitalize(), ": ", armor_pools[pool_name].size(), " armors")
		for armor in armor_pools[pool_name]:
			print("  - ", armor.armor_name, " (", armor.protection_amount, " prot)")
	print("Found this run: ", armors_found_this_run)
	print("==========================")
