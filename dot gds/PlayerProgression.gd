# Enhanced PlayerProgression.gd - Expanded Level-Up Perks
extends Node
class_name PlayerProgression

# Get player node reference using get_parent() in Godot 4
@onready var player_ref = get_parent()

# Signals (keep existing ones)
signal coin_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up_stats(health_increase: int, damage_increase: int)
signal stat_choice_made(stat_name: String)
signal show_level_up_choices(options: Array)

# New signals for expanded perks
signal dash_charges_increased(new_max: int)
signal attack_speed_increased(new_cooldown: float)
signal minion_limit_increased(new_limit: int)

# Existing variables (keep these)
var currency: int = 0
var total_coins_collected: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next_level: int = 100
var xp_growth: float = 1.5

# New progression tracking variables
var perks_unlocked: Dictionary = {}
var total_perks_taken: int = 0

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	currency = 0
	total_coins_collected = 0
	_initialize_perk_tracking()  # Track which perks player has

func _initialize_perk_tracking():
	"""Initialize tracking for all perk types - prevents null errors"""
	perks_unlocked = {
		"health_boost": 0,
		"damage_boost": 0,
		"speed_boost": 0,
		"attack_speed": 0,
		"dash_charges": 0,
		"dash_cooldown": 0,
		"minion_count": 0,
		"health_regen": 0,
		"crit_chance": 0,
		"weapon_range": 0
	}

# Keep existing functions (add_currency, add_xp, _level_up, etc.)
func add_currency(amount: int):
	if not player_ref:
		push_error("PlayerProgression: No valid player reference")
		return
	currency += amount
	total_coins_collected += amount
	coin_collected.emit(currency)

func add_xp(amount: int):
	if not player_ref:
		push_error("PlayerProgression: No valid player reference")
		return
	xp += amount
	xp_changed.emit(xp, xp_to_next_level, level)
	if xp >= xp_to_next_level:
		_level_up()

func _level_up():
	print("🔥 LEVEL UP TRIGGERED - Current level: ", level)
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth)
	
	print("📊 Generating upgrade options...")
	var upgrade_options = _generate_upgrade_options()
	print("✅ Generated ", upgrade_options.size(), " options: ", upgrade_options)
	
	print("⏸️ Pausing game...")
	get_tree().paused = true
	
	print("📡 Emitting show_level_up_choices signal with options...")
	show_level_up_choices.emit(upgrade_options)
	print("✅ Signal emitted successfully")

# EXPANDED: Generate different upgrade options based on player level
func _generate_upgrade_options() -> Array:
	"""Generate 3 random upgrade options for level-up - Godot 4.1+ best practice"""
	var all_possible_upgrades = _get_all_available_upgrades()
	var selected_upgrades = []
	
	# Safety check - prevents crashes if no upgrades available
	if all_possible_upgrades.is_empty():
		print("⚠️ WARNING: No upgrades available, using defaults")
		return _get_default_upgrades()
	
	# Pick 3 random unique upgrades
	var temp_upgrades = all_possible_upgrades.duplicate()
	for i in range(min(3, temp_upgrades.size())):
		var random_index = randi() % temp_upgrades.size()
		selected_upgrades.append(temp_upgrades[random_index])
		temp_upgrades.remove_at(random_index)  # Prevent duplicates
	
	return selected_upgrades

func _get_all_available_upgrades() -> Array:
	"""Returns all possible upgrades - easier to modify and expand"""
	var upgrades = []
	
	# Basic stat upgrades (always available)
	upgrades.append_array([
		{"title": "💪 Health Boost", "description": "+25 Max Health", "type": "health", "value": 25},
		{"title": "⚔️ Damage Up", "description": "+8 Attack Damage", "type": "damage", "value": 8},
		{"title": "💨 Speed Boost", "description": "+1.2 Movement Speed", "type": "speed", "value": 1.2}
	])
	
	# Combat upgrades
	upgrades.append_array([
		{"title": "⚡ Attack Speed", "description": "-0.2s Attack Cooldown", "type": "attack_speed", "value": 0.2},
		{"title": "🎯 Weapon Range", "description": "+0.5 Attack Range", "type": "weapon_range", "value": 0.5},
		{"title": "💥 Critical Hit", "description": "+15% Crit Chance", "type": "crit_chance", "value": 15}
	])
	
	# Movement upgrades
	upgrades.append_array([
		{"title": "🚀 Extra Dash", "description": "+1 Dash Charge", "type": "dash_charges", "value": 1},
		{"title": "⚡ Dash Cooldown", "description": "-1s Dash Recharge", "type": "dash_cooldown", "value": 1.0}
	])
	
	# Support/Utility upgrades
	upgrades.append_array([
		{"title": "❤️ Health Regen", "description": "+1 HP/sec Regeneration", "type": "health_regen", "value": 1},
		{"title": "🤖 Extra Minion", "description": "+1 Max Ally", "type": "minion_count", "value": 1}
	])
	
	# Level-gated upgrades (unlock at higher levels)
	if level >= 5:
		upgrades.append({"title": "🔥 Berserker", "description": "Attack Speed +50% when low HP", "type": "berserker", "value": 1})
	
	if level >= 8:
		upgrades.append({"title": "🛡️ Shield Wall", "description": "Temporary Invincibility after Dash", "type": "dash_shield", "value": 1})
	
	if level >= 10:
		upgrades.append({"title": "👑 Alpha Command", "description": "+3 Max Allies", "type": "minion_count", "value": 3})
	
	return upgrades

func _get_default_upgrades() -> Array:
	"""Fallback upgrades if something goes wrong - prevents crashes"""
	return [
		{"title": "💪 Health Boost", "description": "+20 Max Health", "type": "health", "value": 20},
		{"title": "⚔️ Damage Up", "description": "+5 Attack Damage", "type": "damage", "value": 5},
		{"title": "💨 Speed Boost", "description": "+1.0 Movement Speed", "type": "speed", "value": 1.0}
	]

# EXPANDED: Apply different types of upgrades
func apply_upgrade(upgrade_data: Dictionary):
	"""Apply chosen upgrade to player - handles all perk types safely"""
	print("🔧 PlayerProgression: apply_upgrade called with: ", upgrade_data)
	
	# Safety check - prevents crashes from bad data
	if not upgrade_data.has("type") or not upgrade_data.has("value"):
		push_error("❌ Invalid upgrade data: missing type or value")
		return
	
	# Track the perk for statistics
	var perk_type = upgrade_data.type
	if perk_type in perks_unlocked:
		perks_unlocked[perk_type] += 1
	total_perks_taken += 1
	
	# Apply the upgrade based on type
	match upgrade_data.type:
		"health":
			_apply_health_upgrade(upgrade_data.value)
		"damage":
			_apply_damage_upgrade(upgrade_data.value)
		"speed":
			_apply_speed_upgrade(upgrade_data.value)
		"attack_speed":
			_apply_attack_speed_upgrade(upgrade_data.value)
		"dash_charges":
			_apply_dash_charges_upgrade(upgrade_data.value)
		"dash_cooldown":
			_apply_dash_cooldown_upgrade(upgrade_data.value)
		"weapon_range":
			_apply_weapon_range_upgrade(upgrade_data.value)
		"crit_chance":
			_apply_crit_chance_upgrade(upgrade_data.value)
		"health_regen":
			_apply_health_regen_upgrade(upgrade_data.value)
		"minion_count":
			_apply_minion_count_upgrade(upgrade_data.value)
		"berserker":
			_apply_berserker_upgrade()
		"dash_shield":
			_apply_dash_shield_upgrade()
		_:
			push_warning("⚠️ Unknown upgrade type: " + str(upgrade_data.type))
	
	print("🔧 Unpausing game...")
	get_tree().paused = false
	xp_changed.emit(xp, xp_to_next_level, level)

# INDIVIDUAL UPGRADE FUNCTIONS (easier to debug and modify)

func _apply_health_upgrade(value: int):
	"""Increase max health - includes safety checks"""
	print("🔧 Emitting level_up_stats signal with health increase: ", value)
	level_up_stats.emit(value, 0)

func _apply_damage_upgrade(value: int):
	"""Increase attack damage - includes safety checks"""
	print("🔧 Applying damage increase: ", value)
	if player_ref and "attack_damage" in player_ref:
		player_ref.attack_damage += value
	else:
		push_warning("⚠️ Cannot apply damage upgrade: player_ref invalid or missing attack_damage")

func _apply_speed_upgrade(value: float):
	"""Increase movement speed - includes safety checks"""
	print("🔧 Applying speed increase: ", value)
	if player_ref and "speed" in player_ref:
		player_ref.speed += value
	else:
		push_warning("⚠️ Cannot apply speed upgrade: player_ref invalid or missing speed")

func _apply_attack_speed_upgrade(value: float):
	"""Decrease attack cooldown (faster attacks) - includes safety checks"""
	print("🔧 Applying attack speed increase (cooldown reduction): ", value)
	if player_ref and "attack_cooldown" in player_ref:
		player_ref.attack_cooldown = max(0.1, player_ref.attack_cooldown - value)  # Minimum 0.1s cooldown
		attack_speed_increased.emit(player_ref.attack_cooldown)
	else:
		push_warning("⚠️ Cannot apply attack speed upgrade: player_ref invalid or missing attack_cooldown")

func _apply_dash_charges_upgrade(value: int):
	"""Increase max dash charges - includes safety checks"""
	print("🔧 Applying dash charges increase: ", value)
	if player_ref and "max_dash_charges" in player_ref:
		player_ref.max_dash_charges += value
		dash_charges_increased.emit(player_ref.max_dash_charges)
		# Also give the player the extra charge immediately
		if player_ref.has_method("refill_dash_charges"):
			player_ref.refill_dash_charges()
	else:
		push_warning("⚠️ Cannot apply dash charges upgrade: player_ref invalid or missing max_dash_charges")

func _apply_dash_cooldown_upgrade(value: float):
	"""Decrease dash cooldown - includes safety checks"""
	print("🔧 Applying dash cooldown reduction: ", value)
	if player_ref and "dash_cooldown" in player_ref:
		player_ref.dash_cooldown = max(1.0, player_ref.dash_cooldown - value)  # Minimum 1.0s cooldown
	else:
		push_warning("⚠️ Cannot apply dash cooldown upgrade: player_ref invalid or missing dash_cooldown")

func _apply_weapon_range_upgrade(value: float):
	"""Increase weapon attack range - includes safety checks"""
	print("🔧 Applying weapon range increase: ", value)
	if player_ref and "attack_range" in player_ref:
		player_ref.attack_range += value
		# Update attack area if it exists
		var attack_area = player_ref.get_node_or_null("AttackArea")
		if attack_area:
			var collision_shape = attack_area.get_node_or_null("CollisionShape3D")
			if collision_shape and collision_shape.shape is SphereShape3D:
				collision_shape.shape.radius = player_ref.attack_range
	else:
		push_warning("⚠️ Cannot apply weapon range upgrade: player_ref invalid or missing attack_range")

func _apply_crit_chance_upgrade(value: int):
	"""Increase critical hit chance - includes safety checks"""
	print("🔧 Applying crit chance increase: ", value, "%")
	# Add crit chance property if it doesn't exist
	if player_ref:
		if not "crit_chance" in player_ref:
			player_ref.set("crit_chance", 0)  # Initialize if missing
		player_ref.crit_chance += value
		player_ref.crit_chance = min(player_ref.crit_chance, 100)  # Cap at 100%

func _apply_health_regen_upgrade(value: int):
	"""Increase health regeneration rate - includes safety checks"""
	print("🔧 Applying health regen increase: ", value, " HP/sec")
	if player_ref and "health_regen_rate" in player_ref:
		player_ref.health_regen_rate += value
	else:
		push_warning("⚠️ Cannot apply health regen upgrade: player_ref invalid or missing health_regen_rate")

func _apply_minion_count_upgrade(value: int):
	"""Increase maximum ally/minion count - includes safety checks"""
	print("🔧 Applying minion count increase: ", value)
	if player_ref:
		# Try different ways to find ally manager
		var ally_manager = player_ref.get_node_or_null("AllyCommandManager") 
		if not ally_manager:
			ally_manager = player_ref.get("ally_command_manager")
		
		if ally_manager and "max_allies" in ally_manager:
			ally_manager.max_allies += value
			minion_limit_increased.emit(ally_manager.max_allies)
		else:
			# Create ally manager if it doesn't exist (for beginners)
			if not player_ref.has_method("get_max_allies"):
				player_ref.set("max_allies", 3 + value)  # Default 3 + upgrade
			else:
				var current_max = player_ref.call("get_max_allies")
				player_ref.set("max_allies", current_max + value)
			minion_limit_increased.emit(player_ref.get("max_allies"))

func _apply_berserker_upgrade():
	"""Special upgrade: faster attacks when low health - includes safety checks"""
	print("🔧 Applying berserker upgrade")
	if player_ref:
		player_ref.set("has_berserker", true)  # Flag for combat component to check

func _apply_dash_shield_upgrade():
	"""Special upgrade: temporary invincibility after dash - includes safety checks"""
	print("🔧 Applying dash shield upgrade")
	if player_ref:
		player_ref.set("has_dash_shield", true)  # Flag for movement component to check

# UTILITY FUNCTIONS FOR UI/STATS

func get_perk_count(perk_type: String) -> int:
	"""Get how many times a specific perk was taken"""
	return perks_unlocked.get(perk_type, 0)

func get_total_perks_taken() -> int:
	"""Get total number of perks chosen"""
	return total_perks_taken

func get_currency() -> int:
	return currency

func get_xp() -> int:
	return xp

# Keep existing signal functions
func apply_stat_choice(stat_name: String):
	stat_choice_made.emit(stat_name)
	xp_changed.emit(xp, xp_to_next_level, level)
