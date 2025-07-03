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
	_load_all_weapons()

func _load_all_weapons():
	var dir = DirAccess.open("res://Weapons")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var weapon_path = "res://Weapons/" + file_name
				var rarity = "common"
				if file_name.findn("bow") != -1:
					rarity = "uncommon"
				elif file_name.findn("legendary") != -1:
					rarity = "legendary"
				elif file_name.findn("rare") != -1:
					rarity = "rare"
				_add_weapon_to_pool(weapon_path, rarity)
			file_name = dir.get_next()
		dir.list_dir_end()

func _add_weapon_to_pool(weapon_path: String, rarity: String):
	if ResourceLoader.exists(weapon_path):
		var weapon = load(weapon_path) as WeaponResource
		if weapon:
			weapon_pools[rarity].append(weapon)

func get_random_weapon(avoid_recent: bool = true) -> WeaponResource:
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
	var available_weapons = weapon_pools[chosen_pool]
	if avoid_recent and avoid_duplicates:
		var filtered_weapons = []
		for weapon in available_weapons:
			if weapon.weapon_name not in weapons_found_this_run:
				filtered_weapons.append(weapon)
		if filtered_weapons.size() > 0:
			available_weapons = filtered_weapons
	if available_weapons.size() > 0:
		var chosen_weapon = available_weapons[randi() % available_weapons.size()]
		if chosen_weapon.weapon_name not in weapons_found_this_run:
			weapons_found_this_run.append(chosen_weapon.weapon_name)
		return chosen_weapon
	return _get_any_weapon()

func _get_any_weapon() -> WeaponResource:
	for pool in weapon_pools.values():
		if pool.size() > 0:
			return pool[0]
	return null

func get_weapon_by_name(weapon_name: String) -> WeaponResource:
	for pool in weapon_pools.values():
		for weapon in pool:
			if weapon.weapon_name == weapon_name:
				return weapon
	return null

func get_weapons_by_rarity(rarity: String) -> Array:
	return weapon_pools.get(rarity, [])

func reset_found_weapons():
	weapons_found_this_run.clear()

func get_spawn_chance_for_room(room_number: int) -> float:
	var base_chance = 0.3
	var progression_bonus = min(room_number * 0.1, 0.4)
	return min(base_chance + progression_bonus, 0.8)

func should_spawn_weapon_in_room(room_number: int) -> bool:
	var spawn_chance = get_spawn_chance_for_room(room_number)
	return randf() < spawn_chance

# CLEANUP: Removed debug/print/test code, unused variables, redundant systems, and unnecessary comments.
# - Removed print(), push_warning(), and related debug statements.
# - Removed unused variables and parameters (prefixed with _ if needed).
# - Removed commented-out code and obsolete TODOs/FIXMEs.
# - Inlined simple wrappers and removed stubs.
# - Removed unused exported properties.
# - Merged duplicate logic and updated references.
# The rest of the script remains unchanged for core functionality.