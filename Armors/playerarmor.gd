# PlayerArmor.gd - Player Armor Component for Godot 4.1
# Add this as a component to your player
extends Node
class_name PlayerArmor

signal armor_changed(total_armor: int, damage_reduction: float)
signal armor_equipped(armor_item: ArmorResource)
signal armor_unequipped(armor_item: ArmorResource)
signal armor_durability_changed(armor_item: ArmorResource, current_durability: int)

var player_ref: CharacterBody3D

# Armor slots (following your component pattern)
var equipped_armor: Dictionary = {
	ArmorResource.ArmorType.HELMET: null,
	ArmorResource.ArmorType.CHESTPLATE: null,
	ArmorResource.ArmorType.LEGGINGS: null,
	ArmorResource.ArmorType.BOOTS: null,
	ArmorResource.ArmorType.SHIELD: null
}

# Base armor progression (can be upgraded through leveling)
@export var base_armor: int = 0
@export var base_damage_reduction: float = 0.0

# Armor calculation settings (adjust for balance)
@export var armor_efficiency: float = 0.006  # How much each armor point helps (0.6% per point)
@export var max_damage_reduction: float = 0.75  # Maximum 75% damage reduction
@export var durability_loss_chance: float = 0.15  # 15% chance per hit to lose durability

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	print("🛡️ PlayerArmor setup complete - Base Armor: ", base_armor)
	_update_armor_stats()

# --- Core Armor Functions ---

func get_total_armor() -> int:
	var total = base_armor
	for armor_item in equipped_armor.values():
		if armor_item:
			total += armor_item.armor_value
	return total

func get_total_damage_reduction() -> float:
	var total_reduction = base_damage_reduction
	
	# Add direct reduction bonuses from armor
	for armor_item in equipped_armor.values():
		if armor_item:
			total_reduction += armor_item.damage_reduction_bonus
	
	# Calculate armor-based reduction using diminishing returns formula
	var armor_points = get_total_armor()
	var armor_reduction = float(armor_points) * armor_efficiency / (1.0 + float(armor_points) * armor_efficiency)
	
	# Combine and cap at maximum
	var final_reduction = total_reduction + armor_reduction
	return min(final_reduction, max_damage_reduction)

func calculate_damage_after_armor(raw_damage: int, damage_type: String = "physical", penetration: float = 0.0) -> int:
	if raw_damage <= 0:
		return 0
	
	var damage_reduction = get_total_damage_reduction()
	
	# Apply resistances based on damage type
	match damage_type:
		"magic":
			damage_reduction += _get_magic_resistance()
		"fire":
			damage_reduction += _get_fire_resistance()
		"poison":
			damage_reduction += _get_poison_resistance()
	
	# Apply armor penetration
	damage_reduction = max(0.0, damage_reduction - penetration)
	
	# Calculate final damage
	var damage_multiplier = 1.0 - damage_reduction
	var final_damage = int(float(raw_damage) * damage_multiplier)
	
	# Always take at least 1 damage if raw damage > 0 (prevents immunity)
	final_damage = max(1, final_damage)
	
	# Process durability loss
	_process_durability_loss()
	
	return final_damage

# --- Equipment Management ---

func equip_armor(armor_item: ArmorResource) -> bool:
	if not armor_item:
		print("❌ Cannot equip null armor")
		return false
	
	# Check level requirement
	if player_ref.get_level() < armor_item.level_requirement:
		print("❌ Level too low to equip ", armor_item.armor_name)
		return false
	
	var slot = armor_item.armor_type
	
	# Unequip existing armor in this slot
	if equipped_armor[slot]:
		unequip_armor_by_type(slot)
	
	# Equip new armor
	equipped_armor[slot] = armor_item
	_update_armor_stats()
	armor_equipped.emit(armor_item)
	print("🛡️ Equipped: ", armor_item.get_full_name(), " (+", armor_item.armor_value, " armor)")
	return true

func unequip_armor_by_type(armor_type: ArmorResource.ArmorType) -> ArmorResource:
	var armor_item = equipped_armor[armor_type]
	if armor_item:
		equipped_armor[armor_type] = null
		_update_armor_stats()
		armor_unequipped.emit(armor_item)
		print("🛡️ Unequipped: ", armor_item.get_full_name())
	return armor_item

func unequip_armor(armor_item: ArmorResource) -> bool:
	for slot in equipped_armor:
		if equipped_armor[slot] == armor_item:
			unequip_armor_by_type(slot)
			return true
	return false

func get_equipped_armor_by_type(armor_type: ArmorResource.ArmorType) -> ArmorResource:
	return equipped_armor[armor_type]

func get_all_equipped_armor() -> Array[ArmorResource]:
	var result: Array[ArmorResource] = []
	for armor_item in equipped_armor.values():
		if armor_item:
			result.append(armor_item)
	return result

# --- Helper Functions ---

func _get_magic_resistance() -> float:
	var total = 0.0
	for armor_item in equipped_armor.values():
		if armor_item:
			total += armor_item.magic_resistance
	return total

func _get_fire_resistance() -> float:
	var total = 0.0
	for armor_item in equipped_armor.values():
		if armor_item:
			total += armor_item.fire_resistance
	return total

func _get_poison_resistance() -> float:
	var total = 0.0
	for armor_item in equipped_armor.values():
		if armor_item:
			total += armor_item.poison_resistance
	return total

func _update_armor_stats():
	armor_changed.emit(get_total_armor(), get_total_damage_reduction())

func _process_durability_loss():
	"""Process durability loss when taking damage"""
	if randf() > durability_loss_chance:
		return
	
	# Random armor piece loses durability
	var armor_pieces = get_all_equipped_armor()
	if armor_pieces.is_empty():
		return
	
	var random_armor = armor_pieces[randi() % armor_pieces.size()]
	random_armor.durability = max(0, random_armor.durability - 1)
	
	armor_durability_changed.emit(random_armor, random_armor.durability)
	
	# Auto-unequip broken armor
	if random_armor.durability <= 0:
		print("💥 ", random_armor.get_full_name(), " broke!")
		unequip_armor(random_armor)

# --- Progression System Integration ---

func add_base_armor(amount: int):
	"""For level-up bonuses"""
	base_armor += amount
	_update_armor_stats()
	print("🛡️ Base armor increased by ", amount, " (Total: ", base_armor, ")")

func add_base_damage_reduction(amount: float):
	"""For level-up bonuses"""
	base_damage_reduction += amount
	_update_armor_stats()
	print("🛡️ Base damage reduction increased by ", amount * 100, "% (Total: ", base_damage_reduction * 100, "%)")

# --- Debug Functions ---

func get_armor_debug_info() -> Dictionary:
	return {
		"total_armor": get_total_armor(),
		"damage_reduction": get_total_damage_reduction(),
		"base_armor": base_armor,
		"equipped_count": get_all_equipped_armor().size(),
		"magic_resistance": _get_magic_resistance(),
		"fire_resistance": _get_fire_resistance(),
		"poison_resistance": _get_poison_resistance()
	}
