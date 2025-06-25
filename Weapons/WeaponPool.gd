# WeaponPool.gd - Autoload for managing weapon spawning
extends Node

# Weapon pool organized by rarity/power level
var weapon_pools = {
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

# Track weapons found this run (for variety)
var weapons_found_this_run: Array[String] = []
var avoid_duplicates = true

func _ready():
	print("🗡️ WeaponPool: Initializing weapon database...")
	_load_all_weapons()

func _load_all_weapons():
	"""Load all weapon resources from the Weapons folder"""
	# Common weapons (starting tier)
	_add_weapon_to_pool("res://Weapons/iron_sword.tres", "common")
	_add_weapon_to_pool("res://Weapons/wooden_bow.tres", "common")
	
	# Uncommon weapons (mid-tier)
	_add_weapon_to_pool("res://Weapons/steel_sword.tres", "uncommon")
	_add_weapon_to_pool("res://Weapons/mage_staff.tres", "uncommon")
	
	# Rare weapons (high-tier)
	_add_weapon_to_pool("res://Weapons/enchanted_blade.tres", "rare")
	
	# Add legendary weapons as you create them:
	# _add_weapon_to_pool("res://Weapons/excalibur.tres", "legendary")
	
	print("✅ WeaponPool: Loaded weapons - Common: ", weapon_pools["common"].size(),
		  ", Uncommon: ", weapon_pools["uncommon"].size(),
		  ", Rare: ", weapon_pools["rare"].size(), 
		  ", Legendary: ", weapon_pools["legendary"].size())

func _add_weapon_to_pool(weapon_path: String, rarity: String):
	"""Add a weapon resource to the specified pool"""
	if ResourceLoader.exists(weapon_path):
		var weapon = load(weapon_path) as WeaponResource
		if weapon:
			weapon_pools[rarity].append(weapon)
			print("📦 Added ", weapon.weapon_name, " to ", rarity, " pool")
	else:
		print("⚠️ Weapon not found: ", weapon_path)

func get_random_weapon(avoid_recent: bool = true) -> WeaponResource:
	"""Get a random weapon, optionally avoiding recently found ones"""
	
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
	
	# Get weapons from chosen pool
	var available_weapons = weapon_pools[chosen_pool]
	
	# Filter out recently found weapons if requested
	if avoid_recent and avoid_duplicates:
		var filtered_weapons = []
		for weapon in available_weapons:
			if weapon.weapon_name not in weapons_found_this_run:
				filtered_weapons.append(weapon)
		
		# Use filtered list if it's not empty
		if filtered_weapons.size() > 0:
			available_weapons = filtered_weapons
	
	# Return random weapon from available pool
	if available_weapons.size() > 0:
		var chosen_weapon = available_weapons[randi() % available_weapons.size()]
		
		# Track this weapon as found
		if chosen_weapon.weapon_name not in weapons_found_this_run:
			weapons_found_this_run.append(chosen_weapon.weapon_name)
		
		print("🎲 WeaponPool: Selected ", chosen_weapon.weapon_name, " from ", chosen_pool, " pool")
		return chosen_weapon
	
	# Fallback - return any weapon if pools are empty
	return _get_any_weapon()

func _get_any_weapon() -> WeaponResource:
	"""Fallback method to get any available weapon"""
	for pool in weapon_pools.values():
		if pool.size() > 0:
			return pool[0]
	
	print("⚠️ WeaponPool: No weapons available!")
	return null

func get_weapon_by_name(weapon_name: String) -> WeaponResource:
	"""Get a specific weapon by name"""
	for pool in weapon_pools.values():
		for weapon in pool:
			if weapon.weapon_name == weapon_name:
				return weapon
	return null

func get_weapons_by_rarity(rarity: String) -> Array:
	"""Get all weapons of a specific rarity"""
	return weapon_pools.get(rarity, [])

func reset_found_weapons():
	"""Reset the list of found weapons (call when starting new run)"""
	weapons_found_this_run.clear()
	print("🔄 WeaponPool: Reset found weapons list")

func get_spawn_chance_for_room(room_number: int) -> float:
	"""Calculate spawn chance based on room progression"""
	# Higher chance in later rooms
	var base_chance = 0.3  # 30% base chance
	var progression_bonus = min(room_number * 0.1, 0.4)  # Up to 40% bonus
	return min(base_chance + progression_bonus, 0.8)  # Max 80% chance

func should_spawn_weapon_in_room(room_number: int) -> bool:
	"""Determine if a weapon should spawn in this room"""
	var spawn_chance = get_spawn_chance_for_room(room_number)
	return randf() < spawn_chance

# Debug methods
func print_weapon_stats():
	"""Print current weapon pool statistics"""
	print("=== WEAPON POOL STATS ===")
	for pool_name in weapon_pools.keys():
		print(pool_name.capitalize(), ": ", weapon_pools[pool_name].size(), " weapons")
		for weapon in weapon_pools[pool_name]:
			print("  - ", weapon.weapon_name, " (", weapon.attack_damage, " dmg)")
	print("Found this run: ", weapons_found_this_run)
	print("==========================")


# ...existing code...
# Disabled staff in weapon pool for now
# _add_weapon_to_pool("res://Weapons/mage_staff.tres", "uncommon")
# ...existing code...