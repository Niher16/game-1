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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_all_armors()

# Loads all .tres armor resources from the Armors folder and organizes them by rarity.
func _load_all_armors() -> void:
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
				var armor_res = load("res://Armors/%s" % file_name)
				if armor_res and armor_res.has_method("get_rarity"):
					var rarity = armor_res.get_rarity()
					if armor_pools.has(rarity):
						armor_pools[rarity].append(armor_res)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("Could not open Armors directory.")

# Returns a random armor resource from the specified rarity pool.
# If no rarity is specified, chooses from all pools.
func get_random_armor(rarity: String = ""):
	var pool = []
	if rarity != "" and armor_pools.has(rarity):
		pool = armor_pools[rarity]
	else:
		# Combine all pools if no rarity specified
		for key in armor_pools.keys():
			pool += armor_pools[key]
	if pool.size() == 0:
		push_warning("No armor pieces found in the selected pool.")
		return null
	return pool[randi() % pool.size()]
