extends Node

# ArmorManager is an autoload singleton that manages equipped armor and intercepts damage.
# Godot 4.1+ best practices and beginner-friendly comments included.

# Dictionary to store equipped armor by slot
var equipped_armor: Dictionary = {
	"HELM": null,
	"CHEST": null,
	"SHOULDERS": null,
	"BOOTS": null
}

# Reference to the player's health component (assumed to be autoload or set externally)
var player_health: Node = null

# Equip an armor resource to a specific slot
func equip_armor(armor_resource: Resource, slot: String) -> void:
	if not equipped_armor.has(slot):
		push_warning("Invalid armor slot: %s" % slot)
		return
	equipped_armor[slot] = armor_resource
	print("Equipped armor in slot %s." % slot)

# Intercept damage and block it if armor exists for the hit slot
# This function should be called before health is reduced
func intercept_damage(amount: int, slot: String, _from_node: Node = null) -> int:
	var armor = equipped_armor.get(slot, null)
	if armor:
		# Optional: Check for durability or special effects here
		print("Armor in slot %s blocked %d damage." % [slot, amount])
		return max(amount - armor.protection_amount, 0)  # Block by protection_amount
	return amount  # No armor, full damage goes through

# Connect to PlayerHealth to intercept damage before health loss
func connect_to_player_health(health_node: Node) -> void:
	if health_node == null:
		push_warning("PlayerHealth node is null.")
		return
	player_health = health_node
	# Patch PlayerHealth.take_damage to intercept damage
	if player_health.has_method("take_damage"):
		var original_take_damage = player_health.take_damage
		player_health.take_damage = func(amount: int, slot: String = "CHEST", from_node: Node = null):
			var intercepted = intercept_damage(amount, slot, from_node)
			if intercepted > 0:
				original_take_damage.call(intercepted, slot, from_node)
			else:
				print("All damage blocked by armor in slot %s." % slot)
		print("ArmorManager connected to PlayerHealth's take_damage method.")
	else:
		push_warning("PlayerHealth does not have a 'take_damage' method.")

# Optional: Auto-connect to PlayerHealth if it's a sibling node
func _ready() -> void:
	var sibling_health = null
	if get_parent() != null:
		sibling_health = get_parent().get_node_or_null("PlayerHealth")
		if sibling_health:
			connect_to_player_health(sibling_health)
