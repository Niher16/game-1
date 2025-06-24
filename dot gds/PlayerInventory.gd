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

func _ready():
	if player_ref == null:
		player_ref = get_parent()
	if player_ref == null:
		push_error("PlayerInventory: No player_ref set or found as parent.")
	if weapon_attach_point == null and player_ref:
		weapon_attach_point = player_ref.get_node_or_null("WeaponAttachPoint")
	if weapon_attach_point == null:
		push_warning("PlayerInventory: No weapon_attach_point set or found.")
	else:
		print("[PlayerInventory] WeaponAttachPoint found: ", weapon_attach_point.get_path())
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

# Example signal connection usage
func connect_signals(target: Object):
	if not is_instance_valid(target):
		push_warning("Target for signal connection is not valid.")
		return
	item_added.connect(target._on_item_added)
	item_removed.connect(target._on_item_removed)
