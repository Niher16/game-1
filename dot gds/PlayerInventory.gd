extends Node
class_name PlayerInventoryComponent

signal item_added(item)
signal item_removed(item)

# Component configuration
@export var max_items: int = 32
@export var auto_equip: bool = true

# Inventory data
var items: Array = []

# References (set by parent or via setup)
@export var player_ref: Node = null
@export var weapon_attach_point: Node = null

# Weapon system variables
var equipped_weapon_mesh: MeshInstance3D = null
var sword_node: MeshInstance3D = null
var base_attack_damage: int = 10
var base_attack_range: float = 2.0
var base_attack_cooldown: float = 1.0
var base_attack_cone_angle: float = 90.0

# Equipment slots for armor
var equipped_armor: Dictionary = {
	0: null, # ArmorItem.ArmorType.HELM
	1: null, # CHEST
	2: null, # LEGS
	3: null, # BOOTS
	4: null  # GLOVES
}

# Armor attach points
@export var helm_attach_point: Node3D = null
# Add more attach points for other armor types as needed

func _ready():
	if player_ref == null:
		player_ref = get_parent()
	if player_ref == null:
		push_error("PlayerInventory: No player_ref set or found as parent.")
	if weapon_attach_point == null and player_ref:
		weapon_attach_point = player_ref.get_node_or_null("WeaponAttachPoint")
	if weapon_attach_point == null:
		push_warning("PlayerInventory: No weapon_attach_point set or found.")
# 	else:
# 		print("[PlayerInventory] WeaponAttachPoint found: ", weapon_attach_point.get_path())
	# Ensure player_ref.weapon_attach_point is set
	if player_ref and player_ref.weapon_attach_point != weapon_attach_point:
		player_ref.weapon_attach_point = weapon_attach_point

func add_item(item) -> bool:
	if item == null:
		push_warning("Tried to add null item to inventory.")
		return false
	if items.size() >= max_items:
		push_warning("Inventory is full.")
		return false
	items.append(item)
	item_added.emit(item)
	if auto_equip:
		_try_auto_equip(item)
	return true

func remove_item(item) -> bool:
	if item == null:
		push_warning("Tried to remove null item from inventory.")
		return false
	if item in items:
		items.erase(item)
		item_removed.emit(item)
		return true
	else:
		push_warning("Tried to remove item not in inventory.")
		return false

func get_item(index: int):
	if index < 0 or index >= items.size():
		push_warning("Index out of bounds in get_item.")
		return null
	return items[index]

func get_items() -> Array:
	return items.duplicate()

func _try_auto_equip(item):
	# Placeholder for auto-equip logic, can be extended
	if weapon_attach_point and item.has("mesh"):
		weapon_attach_point.add_child(item.mesh)
		# Optionally set equipped_weapon_mesh
		# equipped_weapon_mesh = item.mesh

# Armor equipment functions
func equip_armor(armor_item) -> bool:
	if armor_item == null:
		push_warning("Tried to equip null armor item.")
		return false
	var slot = int(armor_item.armor_type)
	# Unequip current armor in slot if any
	if equipped_armor[slot]:
		unequip_armor(slot)
	# Attach mesh to correct point
	var mesh_instance = null
	if armor_item.mesh_scene:
		mesh_instance = armor_item.mesh_scene.instantiate()
		match slot:
			0:
				if helm_attach_point:
					helm_attach_point.add_child(mesh_instance)
			# Add cases for other armor types
	equipped_armor[slot] = {
		"item": armor_item,
		"mesh": mesh_instance
	}
	# Optionally emit signal for UI update
	return true

func unequip_armor(armor_type: int) -> bool:
	var slot = int(armor_type)
	var equipped = equipped_armor[slot]
	if equipped and equipped.mesh:
		equipped.mesh.queue_free()
	equipped_armor[slot] = null
	# Optionally emit signal for UI update
	return true

func get_total_defense() -> int:
	var total = 0
	for slot in equipped_armor.values():
		if slot and slot.item:
			total += slot.item.defense_value
	return total

# Example signal connection usage
func connect_signals(target: Object):
	if not is_instance_valid(target):
		push_warning("Target for signal connection is not valid.")
		return
	item_added.connect(target._on_item_added)
	item_removed.connect(target._on_item_removed)
