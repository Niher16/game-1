# ArmorResource.gd - Armor item resource for Godot 4.1
# Create this in res://dot gds/ArmorResource.gd
class_name ArmorResource
extends Resource

enum ArmorType {
	HELMET = 0,
	CHESTPLATE = 1,
	LEGGINGS = 2,
	BOOTS = 3,
	SHIELD = 4
}

enum ArmorMaterial {
	LEATHER = 0,
	IRON = 1,
	STEEL = 2,
	MITHRIL = 3,
	DRAGON_SCALE = 4
}

# Basic Properties
@export var armor_name: String = "Basic Armor"
@export var armor_type: ArmorType = ArmorType.CHESTPLATE
@export var armor_material: ArmorMaterial = ArmorMaterial.LEATHER

# Stats
@export var armor_value: int = 10 # Raw armor points
@export var damage_reduction_bonus: float = 0.05 # Direct % reduction (0.05 = 5%)
@export var durability: int = 100 # Max durability
@export var weight: float = 1.0 # Affects movement speed

# Special Properties
@export var magic_resistance: float = 0.0 # Resistance to magic damage
@export var fire_resistance: float = 0.0 # Resistance to fire damage
@export var poison_resistance: float = 0.0 # Resistance to poison damage

# Visual and Gameplay
@export var visual_scene_path: String = "" # Path to 3D model
@export var description: String = "A piece of protective armor"
@export var rarity: int = 1 # 1=Common, 2=Uncommon, 3=Rare, 4=Legendary

# Economy
@export var value: int = 50 # Coin value when sold
@export var level_requirement: int = 1 # Minimum level to equip

func get_armor_type_name() -> String:
	match armor_type:
		ArmorType.HELMET:
			return "Helmet"
		ArmorType.CHESTPLATE:
			return "Chestplate"
		ArmorType.LEGGINGS:
			return "Leggings"
		ArmorType.BOOTS:
			return "Boots"
		ArmorType.SHIELD:
			return "Shield"
		_:
			return "Unknown"

func get_material_name() -> String:
	match armor_material:
		ArmorMaterial.LEATHER:
			return "Leather"
		ArmorMaterial.IRON:
			return "Iron"
		ArmorMaterial.STEEL:
			return "Steel"
		ArmorMaterial.MITHRIL:
			return "Mithril"
		ArmorMaterial.DRAGON_SCALE:
			return "Dragon Scale"
		_:
			return "Unknown"

func get_rarity_name() -> String:
	match rarity:
		1:
			return "Common"
		2:
			return "Uncommon"
		3:
			return "Rare"
		4:
			return "Legendary"
		_:
			return "Common"

func get_full_name() -> String:
	return get_material_name() + " " + get_armor_type_name()

func get_tooltip_text() -> String:
	var tooltip = "[b]" + get_full_name() + "[/b]\n"
	tooltip += get_rarity_name() + " " + get_armor_type_name() + "\n\n"
	tooltip += "Armor: +" + str(armor_value) + "\n"
	
	if damage_reduction_bonus > 0:
		tooltip += "Damage Reduction: +" + str(damage_reduction_bonus * 100) + "%\n"
	
	if magic_resistance > 0:
		tooltip += "Magic Resistance: +" + str(magic_resistance * 100) + "%\n"
	
	if fire_resistance > 0:
		tooltip += "Fire Resistance: +" + str(fire_resistance * 100) + "%\n"
	
	if weight != 1.0:
		tooltip += "Weight: " + str(weight) + "\n"
	
	tooltip += "\n" + description
	
	if level_requirement > 1:
		tooltip += "\n\nRequires Level " + str(level_requirement)
	
	return tooltip
