extends Resource

# Armor type enum
enum ArmorType { HELM, CHEST, SHOULDERS, BOOTS }
# Rarity enum
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var armor_name: String
@export var armor_type: ArmorType
@export var durability: int
@export var protection_amount: int
@export var armor_mesh: Resource
@export var rarity: Rarity
