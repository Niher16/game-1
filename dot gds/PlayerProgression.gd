extends Node
class_name PlayerProgression

# Get player node reference using get_parent() in Godot 4
@onready var player_ref = get_parent()

signal coin_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up_stats(health_increase: int, damage_increase: int)
signal stat_choice_made(stat_name: String)
signal show_level_up_choices(options: Array)

var currency: int = 0
var total_coins_collected: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next_level: int = 100
var xp_growth: float = 1.5

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	currency = 0
	total_coins_collected = 0

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

func get_currency() -> int:
	return currency

func get_xp() -> int:
	return xp

func apply_stat_choice(stat_name: String):
	stat_choice_made.emit(stat_name)
	xp_changed.emit(xp, xp_to_next_level, level)

func _generate_upgrade_options() -> Array:
	"""Generate random upgrade options - more variety as player levels up"""
	var all_upgrades = [
		# Core upgrades (always available)
		{"title": "💪 Health Boost", "description": "+20 Max Health", "type": "health", "value": 20},
		{"title": "⚔️ Damage Up", "description": "+5 Attack Damage", "type": "damage", "value": 5},
		{"title": "💨 Speed Boost", "description": "+1.0 Movement Speed", "type": "speed", "value": 1.0},
		
		# Advanced upgrades (level 3+)
		{"title": "⚡ Attack Speed", "description": "-0.2 Attack Cooldown", "type": "attack_speed", "value": 0.2},
		{"title": "🛡️ Defense Up", "description": "+15% Damage Reduction", "type": "armor", "value": 15},
		{"title": "💎 Max Health+", "description": "+35 Max Health", "type": "health", "value": 35},
		
		# Elite upgrades (level 5+)
		{"title": "🔥 Critical Strike", "description": "+25% Crit Chance", "type": "crit_chance", "value": 25},
		{"title": "💥 Power Strike", "description": "+10 Attack Damage", "type": "damage", "value": 10},
		{"title": "🏃‍♂️ Sprint", "description": "+2.0 Movement Speed", "type": "speed", "value": 2.0}
	]
	
	# Filter upgrades based on level
	var available_upgrades = []
	for upgrade in all_upgrades:
		if level >= 1:  # Core upgrades (levels 1-2)
			if upgrade.type in ["health", "damage", "speed"]:
				if upgrade.value <= 25:  # Basic versions only
					available_upgrades.append(upgrade)
		if level >= 3:  # Advanced upgrades (levels 3-4)
			if upgrade.type in ["attack_speed", "armor"] or (upgrade.type == "health" and upgrade.value > 20):
				available_upgrades.append(upgrade)
		if level >= 5:  # Elite upgrades (level 5+)
			if upgrade.type in ["crit_chance"] or (upgrade.type in ["damage", "speed"] and upgrade.value >= 10):
				available_upgrades.append(upgrade)
	
	# Always include at least basic options if filtered list is too small
	if available_upgrades.size() < 6:
		available_upgrades = all_upgrades
	
	# Pick 3 random upgrades
	available_upgrades.shuffle()
	return available_upgrades.slice(0, 3)

func apply_upgrade(upgrade_data: Dictionary):
	print("🔧 PlayerProgression: apply_upgrade called with: ", upgrade_data)
	
	# Safety check for player reference
	if not player_ref:
		print("❌ ERROR: No player reference!")
		return
	
	match upgrade_data.type:
		"health":
			print("🔧 Emitting level_up_stats signal with health increase: ", upgrade_data.value)
			level_up_stats.emit(upgrade_data.value, 0)
		"damage":
			print("🔧 Applying damage increase: ", upgrade_data.value)
			if "attack_damage" in player_ref:
				player_ref.attack_damage += upgrade_data.value
			else:
				print("⚠️ Player doesn't have attack_damage property")
		"speed":
			print("🔧 Applying speed increase: ", upgrade_data.value)
			if "speed" in player_ref:
				player_ref.speed += upgrade_data.value
			else:
				print("⚠️ Player doesn't have speed property")
		"attack_speed":
			print("🔧 Applying attack speed increase: ", upgrade_data.value)
			if "attack_cooldown" in player_ref:
				player_ref.attack_cooldown = max(0.1, player_ref.attack_cooldown - upgrade_data.value)
				print("✅ New attack cooldown: ", player_ref.attack_cooldown)
			else:
				print("⚠️ Player doesn't have attack_cooldown property")
		"armor":
			print("🔧 Applying armor increase: ", upgrade_data.value, "%")
			if "damage_reduction" in player_ref:
				player_ref.damage_reduction += upgrade_data.value / 100.0
			else:
				player_ref.damage_reduction = upgrade_data.value / 100.0
				print("✅ Added damage_reduction property: ", player_ref.damage_reduction)
		"crit_chance":
			print("🔧 Applying crit chance increase: ", upgrade_data.value, "%")
			if "crit_chance" in player_ref:
				player_ref.crit_chance += upgrade_data.value / 100.0
			else:
				player_ref.crit_chance = upgrade_data.value / 100.0
				print("✅ Added crit_chance property: ", player_ref.crit_chance)
		_:
			print("⚠️ Unknown upgrade type: ", upgrade_data.type)
	
	print("🔧 Unpausing game...")
	get_tree().paused = false
	xp_changed.emit(xp, xp_to_next_level, level)
