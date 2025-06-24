# PlayerHealth.gd - Clean health system for Godot 4.1
extends Node
class_name PlayerHealth

## Emitted when health changes (current_health, max_health)
signal health_changed(current_health: int, max_health: int)

## Emitted when player dies
signal player_died

# Health values
var current_health: int = 100
var max_health: int = 100

# Damage protection
var invulnerable_time: float = 0.0
const INVULNERABLE_DURATION: float = 0.5

# Reference to player
var player: CharacterBody3D

func _ready():
	print("💖 PlayerHealth system ready")

func setup(player_ref: CharacterBody3D, starting_health: int = 100):
	"""Initialize the health system"""
	player = player_ref
	max_health = starting_health
	current_health = starting_health
	invulnerable_time = 0.0
	
	print("💖 Health system setup - Max: ", max_health, " Current: ", current_health)
	health_changed.emit(current_health, max_health)

func _process(delta):
	"""Update invulnerability timer"""
	if invulnerable_time > 0:
		invulnerable_time -= delta

func get_health() -> int:
	"""Returns current health"""
	return current_health

func get_max_health() -> int:
	"""Returns maximum health"""
	return max_health

func set_max_health(new_max: int):
	"""Sets new maximum health"""
	max_health = new_max
	# Don't exceed new max
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health, max_health)
	print("💖 Max health set to: ", max_health)

func can_heal() -> bool:
	"""Returns true if player can be healed"""
	return current_health < max_health and current_health > 0

func _update_health_ui(current: int, health_max: int):
	# Update UI if possible
	if player and player.has_method("update_health_ui"):
		player.update_health_ui(current, health_max)
	# Optionally, call UI group directly if needed
	get_tree().call_group("UI", "_on_player_health_changed", current, health_max)

func heal(amount: int):
	"""Heals the player by specified amount"""
	if current_health <= 0:
		print("💀 Cannot heal - player is dead")
		return
	if current_health >= max_health:
		print("💚 Already at full health")
		return
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	print("💖 Healed for ", amount, " HP (", old_health, " -> ", current_health, ")")
	health_changed.emit(current_health, max_health)
	_update_health_ui(current_health, max_health)
	# Visual feedback
	_show_heal_effect(amount)

func take_damage(amount: int, _from_source: Node = null):
	"""Damages the player by specified amount"""
	# Check invulnerability
	if invulnerable_time > 0:
		print("🛡️ Damage blocked - still invulnerable")
		return
	if current_health <= 0:
		print("💀 Already dead - no more damage")
		return
	var old_health = current_health
	current_health = max(current_health - amount, 0)
	invulnerable_time = INVULNERABLE_DURATION
	print("💔 Took ", amount, " damage (", old_health, " -> ", current_health, ")")
	health_changed.emit(current_health, max_health)
	_update_health_ui(current_health, max_health)
	# Check for death
	if current_health <= 0:
		_handle_death()
	else:
		_show_damage_effect(amount)

func _handle_death():
	"""Handles player death"""
	print("💀 Player died!")
	player_died.emit()
	
	# Add death effects here
	if player and player.has_method("_on_death"):
		player._on_death()

func _show_heal_effect(amount: int):
	"""Shows visual feedback for healing"""
	print("✨ Heal effect: +", amount, " HP")
	
	# Try to show floating text if system exists
	if player and player.has_method("show_floating_text"):
		player.show_floating_text("+" + str(amount), Color.GREEN)
	
	# Flash green if possible
	if player and player.has_node("MeshInstance3D"):
		var mesh = player.get_node("MeshInstance3D")
		if mesh.material_override:
			var tween = create_tween()
			var original_color = mesh.material_override.albedo_color
			tween.tween_property(mesh.material_override, "albedo_color", Color.GREEN, 0.1)
			tween.tween_property(mesh.material_override, "albedo_color", original_color, 0.2)

func _show_damage_effect(amount: int):
	"""Shows visual feedback for damage"""
	print("💥 Damage effect: -", amount, " HP")
	
	# Try to show floating text if system exists
	if player and player.has_method("show_floating_text"):
		player.show_floating_text("-" + str(amount), Color.RED)
	
	# Flash red if possible
	if player and player.has_node("MeshInstance3D"):
		var mesh = player.get_node("MeshInstance3D")
		if mesh.material_override:
			var tween = create_tween()
			var original_color = mesh.material_override.albedo_color
			tween.tween_property(mesh.material_override, "albedo_color", Color.RED, 0.1)
			tween.tween_property(mesh.material_override, "albedo_color", original_color, 0.3)

func is_invulnerable() -> bool:
	"""Returns true if player is currently invulnerable"""
	return invulnerable_time > 0

func get_health_percentage() -> float:
	"""Returns health as percentage (0.0 to 1.0)"""
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)
