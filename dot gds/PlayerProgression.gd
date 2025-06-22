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
	print("💰 PlayerProgression: Emitting coin_collected signal with amount: ", amount)
	coin_collected.emit(amount)  # ← Changed from currency to amount

func add_xp(amount: int):
	if not player_ref:
		push_error("PlayerProgression: No valid player reference")
		return
	xp += amount
	print("⭐ PlayerProgression: Emitting xp_changed signal - XP: ", xp, "/", xp_to_next_level, " Level: ", level)
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
	return [
		{"title": "💪 Health Boost", "description": "+20 Max Health", "type": "health", "value": 20},
		{"title": "⚔️ Damage Up", "description": "+5 Attack Damage", "type": "damage", "value": 5},
		{"title": "💨 Speed Boost", "description": "+1.0 Movement Speed", "type": "speed", "value": 1.0}
	]

func apply_upgrade(upgrade_data: Dictionary):
	print("🔧 PlayerProgression: apply_upgrade called with: ", upgrade_data)
	match upgrade_data.type:
		"health":
			print("🔧 Emitting level_up_stats signal with health increase: ", upgrade_data.value)
			level_up_stats.emit(upgrade_data.value, 0)
		"damage":
			print("🔧 Applying damage increase: ", upgrade_data.value)
			player_ref.attack_damage += upgrade_data.value
		"speed":
			print("🔧 Applying speed increase: ", upgrade_data.value)
			player_ref.speed += upgrade_data.value
	print("🔧 Unpausing game...")
	get_tree().paused = false
	xp_changed.emit(xp, xp_to_next_level, level)
