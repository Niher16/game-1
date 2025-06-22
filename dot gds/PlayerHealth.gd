# PlayerHealth.gd - FIXED VERSION with working red damage flash
extends Node
class_name PlayerHealth

signal health_changed(current_health: int, max_health: int)
signal player_died
signal health_depleted

var current_health: int
var max_health: int
var last_damage_time: float
var invulnerability_timer: float

# 🔧 NEW: Variables for damage flash effect
var original_color: Color = Color.WHITE
var is_flashing: bool = false
var flash_timer: float = 0.0
# Flash effect variables
var flash_count: int = 0
const MAX_FLASHES: int = 3
const FLASH_ON_COLOR: Color = Color(1.0, 0.2, 0.2, 1.0)
const FLASH_OFF_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0) # fallback, not used
const FLASH_TOTAL_DURATION: float = 0.5
const FLASH_INTERVAL: float = FLASH_TOTAL_DURATION / (MAX_FLASHES * 2)
const INVULNERABILITY_DURATION := 0.5
const heal_amount_from_potion := 30

var player_ref: CharacterBody3D

# Utility to get the mesh node safely
func _get_mesh_instance() -> MeshInstance3D:
	if player_ref:
		return player_ref.get_node_or_null("MeshInstance3D")
	return null

func setup(player_ref_in: CharacterBody3D, starting_health: int):
	player_ref = player_ref_in
	max_health = starting_health
	current_health = starting_health
	last_damage_time = 0.0
	invulnerability_timer = 0.0
	flash_timer = 0.0
	is_flashing = false
	# Store the original color for resetting later
	var mesh = _get_mesh_instance()
	if mesh and mesh.material_override:
		original_color = mesh.material_override.albedo_color
		print("🎨 Stored original player color: ", original_color)
	print("🔧 PlayerHealth setup complete - Max: ", max_health, " Current: ", current_health)
	health_changed.emit(current_health, max_health)

func take_damage(amount: int, _from: Node3D = null):
	print("🔧 PlayerHealth: take_damage called - amount: ", amount, " current_health: ", current_health, " invuln_timer: ", invulnerability_timer)
	if current_health <= 0 or invulnerability_timer > 0:
		print("🔧 Damage blocked - health: ", current_health, " invuln: ", invulnerability_timer)
		return
	var old_health = current_health
	current_health = max(current_health - amount, 0)
	last_damage_time = Time.get_ticks_msec() / 1000.0
	invulnerability_timer = INVULNERABILITY_DURATION
	print("🔧 Health changed from ", old_health, " to ", current_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_handle_player_death()
	if current_health != old_health:
		_show_damage_feedback(amount)

func heal(heal_amount: int):
	print('🩹 HEAL DEBUG: Attempting to heal for ', heal_amount, ' HP')
	print('🩹 Current health before: ', current_health, '/', max_health)
	if current_health <= 0 or current_health >= max_health:
		print('🩹 Already at full health, no healing needed')
		return
	var old_health = current_health
	current_health = min(current_health + heal_amount, max_health)
	print('🩹 Health after healing: ', current_health, '/', max_health)
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		_show_heal_feedback(heal_amount)

func update_invulnerability(delta: float):
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		# Return true if still invulnerable, false if finished
		return invulnerability_timer > 0
	return false

# 🔧 FIXED: Enhanced damage flash with proper timer and reset
func _show_damage_feedback(damage_amount: int):
	print("DEBUG: _show_damage_feedback called with:", damage_amount, " stack:", get_stack())
	var mesh = _get_mesh_instance()
	if not player_ref or not is_instance_valid(player_ref):
		print("⚠️ Player reference invalid - can't show damage flash")
		return
	if not mesh or not is_instance_valid(mesh):
		print("⚠️ Player MeshInstance3D invalid - can't show damage flash")
		return
	if not mesh.material_override:
		print("⚠️ Player material_override missing - can't show damage flash")
		return
	if is_flashing:
		return
	# Always update original_color to current mesh color before flashing
	original_color = mesh.material_override.albedo_color
	is_flashing = true
	flash_count = 0
	flash_timer = FLASH_INTERVAL
	mesh.material_override.albedo_color = FLASH_ON_COLOR
	# Optional: Add slight scale punch for extra feedback
	var scale_tween = create_tween()
	scale_tween.set_parallel(true)
	scale_tween.tween_property(mesh, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
	scale_tween.tween_property(mesh, "scale", Vector3.ONE, 0.1).set_delay(0.1)
	# Show damage numbers if the damage system exists
	var tree = player_ref.get_tree() if player_ref else null
	if tree:
		var damage_nodes = tree.get_nodes_in_group("damage_numbers")
		print("DEBUG: damage_numbers group count: ", damage_nodes.size())
		if damage_nodes.size() > 0 and damage_nodes[0].has_method("show_damage"):
			damage_nodes[0].show_damage(damage_amount, player_ref, "massive")
	if player_ref.has_node("DamageSound"):
		var damage_sound = player_ref.get_node("DamageSound")
		if damage_sound and damage_sound.has_method("play"):
			damage_sound.play()

# 🔧 FIXED: Enhanced heal flash with proper timer
func _show_heal_feedback(heal_amount: int):
	var mesh = _get_mesh_instance()
	if not player_ref or not mesh or not mesh.material_override:
		return
	# Always update original_color to current mesh color before flashing
	original_color = mesh.material_override.albedo_color
	mesh.material_override.albedo_color = Color(0.3, 1.0, 0.3, 1.0)
	# Reset color after brief delay
	get_tree().create_timer(0.2).timeout.connect(func():
		var mesh2 = _get_mesh_instance()
		if mesh2 and mesh2.material_override:
			mesh2.material_override.albedo_color = original_color
	)
	# Show heal numbers
	var tree = player_ref.get_tree() if player_ref else null
	if tree:
		var heal_system = tree.get_first_node_in_group("damage_numbers")
		if heal_system and heal_system.has_method("show_heal"):
			heal_system.show_heal(heal_amount, player_ref)

# 🔧 NEW: Process function to handle flash timer
func _process(delta: float):
	update_invulnerability(delta)
	# Handle damage flash timer
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			var mesh = _get_mesh_instance()
			if mesh and mesh.material_override:
				if flash_count % 2 == 0:
					mesh.material_override.albedo_color = original_color
				else:
					mesh.material_override.albedo_color = FLASH_ON_COLOR
				flash_count += 1
				if flash_count < MAX_FLASHES * 2:
					flash_timer = FLASH_INTERVAL
				else:
					_reset_player_color()

# 🔧 NEW: Function to reset player color back to original
func _reset_player_color():
	if not is_flashing:
		return
	is_flashing = false
	flash_timer = 0.0
	var mesh = _get_mesh_instance()
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = original_color
		print("🎨 Reset player color back to: ", original_color)

# 🔧 EXISTING FUNCTIONS (unchanged)
func _handle_player_death():
	print("💀 Player death triggered! Emitting signals...")
	health_depleted.emit()
	player_died.emit()

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func set_max_health(new_max_health: int):
	max_health = new_max_health
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _setup_health_system():
	current_health = max_health
	last_damage_time = 0.0
	health_changed.emit(current_health, max_health)

func _initialize_base_stats():
	# Add health-related base stat initialization if needed
	pass
