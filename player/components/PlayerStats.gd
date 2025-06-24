extends Node
class_name PlayerStats

var player_ref: CharacterBody3D
var health_component: Node # Replace PlayerHealth with Node or the correct type if PlayerHealth is defined elsewhere.
var progression_component: PlayerProgression  
var inventory_component: PlayerInventoryComponent

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	health_component = player_ref.health_component
	progression_component = player_ref.progression_component
	inventory_component = player_ref.inventory_component

# --- Health API ---
func get_health() -> int:
	return health_component.get_health() if health_component else 0

func get_max_health() -> int:
	return health_component.get_max_health() if health_component else 100  # Return 100 as default, not 0

func get_health_percentage() -> float:
	return health_component.get_health_percentage() if health_component else 0.0

# --- Progression API ---
func get_currency() -> int:
	return progression_component.get_currency() if progression_component else 0

func get_xp() -> int:
	return progression_component.get_xp() if progression_component else 0

func get_level() -> int:
	return progression_component.level if progression_component else 1

func get_xp_to_next_level() -> int:
	return progression_component.xp_to_next_level if progression_component else 100

# --- Inventory API ---
func get_equipped_weapon() -> WeaponResource:
	return WeaponManager.get_current_weapon() if WeaponManager else null

func is_weapon_equipped() -> bool:
	return WeaponManager.is_weapon_equipped() if WeaponManager else false

# --- Combat Stats API (includes weapon bonuses) ---
func get_attack_damage() -> int:
	return player_ref.attack_damage if player_ref else 10

func get_attack_range() -> float:
	return player_ref.attack_range if player_ref else 2.0

func get_attack_cooldown() -> float:
	return player_ref.attack_cooldown if player_ref else 1.0

func get_attack_cone_angle() -> float:
	return player_ref.attack_cone_angle if player_ref else 90.0

# --- Movement Stats API ---
func get_speed() -> float:
	return player_ref.speed if player_ref else 5.0

func get_dash_charges() -> int:
	return player_ref.movement_component.current_dash_charges if player_ref and is_instance_valid(player_ref.movement_component) else 1

func get_max_dash_charges() -> int:
	return player_ref.max_dash_charges if player_ref else 1

# --- Complete Player State API ---
func get_all_stats() -> Dictionary:
	return {
		"health": get_health(),
		"max_health": get_max_health(),
		"health_percentage": get_health_percentage(),
		"currency": get_currency(),
		"xp": get_xp(),
		"level": get_level(),
		"xp_to_next": get_xp_to_next_level(),
		"equipped_weapon": get_equipped_weapon(),
		"attack_damage": get_attack_damage(),
		"attack_range": get_attack_range(),
		"attack_cooldown": get_attack_cooldown(),
		"speed": get_speed(),
		"dash_charges": get_dash_charges(),
		"max_dash_charges": get_max_dash_charges()
	}
