extends Node
class_name AllyAI

enum State { FOLLOWING, MOVING_TO_TARGET, ATTACKING, RETREATING, PATROLLING, EXPLORING, POSITIONING, WAITING, INVESTIGATING }

var ally_ref
var current_state := State.FOLLOWING
var player_target
var enemy_target
var state_update_timer := 0.0
var state_update_interval := 0.1
var attack_delay_timer := 0.0
var attack_delay := 0.0
var retreat_timer := 0.0

# Ally modes
var mode = null

var first_names = [
	"Aiden", "Luna", "Kai", "Mira", "Rowan", "Zara", "Finn", "Nova", "Ezra", "Lyra",
	"Orin", "Sage", "Rhea", "Jax", "Vera", "Theo", "Ivy", "Dax", "Nia", "Kian",
	"Tara", "Milo", "Suri", "Riven", "Elara", "Bryn", "Juno", "Vale", "Niko", "Sable",
	"Astra", "Corin", "Eira", "Lira", "Marek", "Nyx", "Oryn", "Pax", "Quill", "Rivena",
	"Soren", "Talon", "Vesper", "Wyn", "Xara", "Yara", "Zarek", "Aeliana", "Balen", "Cael",
	"Darian", "Elys", "Faelan", "Galen", "Halyn", "Isen", "Jarek", "Kael", "Lirael", "Mirael",
	"Neris", "Orin", "Pyria", "Quorin", "Rylin", "Sylas", "Tirian", "Uriel", "Vael", "Weylin",
	"Xyra", "Yalen", "Zyra", "Aeris", "Briar", "Caius", "Darian", "Elowen", "Fira", "Galen",
	"Hale", "Iria", "Jace", "Kira", "Lira", "Mira", "Nira", "Orin", "Pax", "Quin", "Ryn"
]
var last_names = [
	"Stormrider", "Dawnbringer", "Nightshade", "Ironwood", "Starfall", "Ashwalker", "Frostwind", "Shadowmere",
	"Brightblade", "Moonwhisper", "Stonehelm", "Swiftarrow", "Emberforge", "Mistvale", "Oakenshield", "Riversong",
	"Wolfbane", "Sunstrider", "Duskwalker", "Windrider", "Firebrand", "Silverleaf", "Darkwater", "Goldheart",
	"Hawthorne", "Stormwatch", "Ironfist", "Lightfoot", "Shadowfox", "Winterborn", "Amberfall", "Blackswan",
	"Cinderfell", "Duskwhisper", "Eaglecrest", "Flintlock", "Grimward", "Hollowbrook", "Ironvale", "Jadeblade",
	"Kingsley", "Larkspur", "Moonshadow", "Nightriver", "Oakheart", "Pinecrest", "Quickwater", "Ravencrest",
	"Stormvale", "Thornfield", "Umbermoor", "Valebrook", "Westwood", "Yewbranch", "Zephyrwind", "Ashenford",
	"Briarwood", "Cloudspire", "Dawnforge", "Ebonwood", "Frostvale", "Glimmerstone", "Hawkwing", "Ivoryspire",
	"Jasperfield", "Kestrel", "Lionshade", "Mistwood", "Northwind", "Oakenfield", "Pinevale", "Quicksilver",
	"Ridgewood", "Stonevale", "Thornbush", "Umberfield", "Violetmoor", "Willowisp", "Yarrow", "Zephyrfield"
]

func _ready():
	# No need to pad name lists; use only the names provided in the arrays
	pass

func generate_random_name() -> String:
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

var patrol_point: Vector3 = Vector3.ZERO
var is_patrolling := false
var moving_to_patrol_point := false
var patrol_radius := 3.0
var patrol_timer := 0.0
var patrol_wait_time := 0.0

func command_patrol_at_point(position: Vector3):
	print("[DEBUG] Patrol command received at position: ", position)
	patrol_point = position
	is_patrolling = true
	moving_to_patrol_point = true
	current_state = State.PATROLLING
	patrol_timer = 0.0
	patrol_wait_time = 0.0
	print("[DEBUG] Ally ", ally_ref.name, " is now patrolling at ", patrol_point)

func set_mode(new_mode):
	mode = new_mode
	if current_state == State.PATROLLING:
		print("[DEBUG] Patrol cancelled by mode change to ", new_mode)
		is_patrolling = false
		moving_to_patrol_point = false
		patrol_point = Vector3.ZERO
		if mode == 1 or mode == 2:
			current_state = State.FOLLOWING
			print("[DEBUG] Ally ", ally_ref.name, " returning to FOLLOWING mode")

func set_player_target(player):
	player_target = player

# Add reference to personality
var personality: AllyPersonality = null

func setup(ally):
	ally_ref = ally
	if not ally_ref.has_meta("display_name"):
		var random_name = generate_random_name()
		ally_ref.set_meta("display_name", random_name)
		ally_ref.name = random_name
	# Get personality reference
	if ally_ref.has_node("PersonalityComponent"):
		personality = ally_ref.get_node("PersonalityComponent")

func _process(delta):
	state_update_timer += delta
	if state_update_timer >= state_update_interval:
		_update_ai_state()
		state_update_timer = 0.0
	_execute_current_state(delta)

func _update_ai_state():
	if not player_target:
		return
	if is_patrolling and current_state == State.PATROLLING:
		# Stay in PATROLLING until cancelled
		return
	# Use LOS-aware enemy search
	enemy_target = find_nearest_enemy_with_los()
	var _previous_state = current_state
	if mode == null:
		mode = 1 # fallback to ATTACK
	if mode == 2: # PASSIVE
		current_state = State.FOLLOWING
		return
	if ally_ref.health_component.current_health < ally_ref.max_health * 0.25 and enemy_target:
		current_state = State.RETREATING
		retreat_timer = 1.0 + randf() * 1.5
		return
	if enemy_target:
		var distance_to_enemy = ally_ref.global_position.distance_to(enemy_target.global_position)
		if mode == 1: # ATTACK (charge far)
			if distance_to_enemy <= ally_ref.combat_component.detection_range:
				current_state = State.ATTACKING
			else:
				current_state = State.MOVING_TO_TARGET
	else:
		current_state = State.FOLLOWING

# Helper: Only returns enemies with line of sight
func find_nearest_enemy_with_los() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		if not ally_ref._has_line_of_sight_to_target(enemy):
			continue
		var distance = ally_ref.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= ally_ref.combat_component.detection_range:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func _execute_current_state(delta: float):
	match current_state:
		State.FOLLOWING:
			_handle_following(delta)
		State.MOVING_TO_TARGET:
			_handle_moving_to_target(delta)
		State.ATTACKING:
			_handle_attacking(delta)
		State.RETREATING:
			_handle_retreating(delta)
		State.PATROLLING:
			_handle_patrolling(delta)
		State.EXPLORING:
			_handle_exploring(delta)
		State.POSITIONING:
			_handle_positioning(delta)
		State.WAITING:
			_handle_waiting(delta)
		State.INVESTIGATING:
			_handle_investigating(delta)

func _handle_following(delta: float):
	if not player_target:
		return
	var distance_to_player = ally_ref.global_position.distance_to(player_target.global_position)
	if distance_to_player > ally_ref.movement_component.follow_distance:
		ally_ref.movement_component.move_towards_target(player_target.global_position, delta)
	else:
		ally_ref.movement_component.orbit_around_player(player_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_moving_to_target(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	ally_ref.movement_component.strafe_around_target(enemy_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_attacking(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	# Check if using a bow
	var is_bow = false
	if ally_ref.current_weapon and ally_ref.current_weapon.weapon_type == WeaponResource.WeaponType.BOW:
		is_bow = true
	# Ensure ally faces the enemy before attacking
	var ally_pos = ally_ref.global_position
	var enemy_pos = enemy_target.global_position
	ally_ref.look_at(Vector3(enemy_pos.x, ally_pos.y, enemy_pos.z), Vector3.UP)
	if is_bow:
		# Stand still and shoot if in range
		var dist = ally_pos.distance_to(enemy_pos)
		if dist > ally_ref.combat_component.detection_range:
			# Move closer if too far
			ally_ref.movement_component.move_toward_target(enemy_target.global_position, delta)
		else:
			ally_ref.velocity = Vector3.ZERO
			if attack_delay_timer > 0:
				attack_delay_timer -= delta
				return
			if randf() < 0.1:
				attack_delay = 0.1 + randf() * 0.3
				attack_delay_timer = attack_delay
				return
			ally_ref.combat_component.attack_target(enemy_target)
		return
	# --- Move while attacking: strafe around the enemy (melee only) ---
	ally_ref.movement_component.strafe_around_target(enemy_target, delta)
	ally_ref.movement_component.apply_separation(delta)
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
		return
	if randf() < 0.1:
		attack_delay = 0.1 + randf() * 0.3
		attack_delay_timer = attack_delay
		return
	ally_ref.combat_component.attack_target(enemy_target)

func _handle_retreating(delta: float):
	if retreat_timer > 0:
		retreat_timer -= delta
		if enemy_target:
			ally_ref.movement_component.move_away_from_target(enemy_target.global_position, delta)
		return
	current_state = State.FOLLOWING

func _handle_patrolling(delta: float):
	if not is_patrolling:
		print("[DEBUG] Patrol ended, switching to FOLLOWING")
		current_state = State.FOLLOWING
		return
	if moving_to_patrol_point:
		var dist = ally_ref.global_position.distance_to(patrol_point)
		if dist > 25.0:
			print("[DEBUG] Ally ", ally_ref.name, " moving directly to patrol point ", patrol_point, " (distance: ", dist, ")")
			ally_ref.movement_component.move_towards_target(patrol_point, delta)
			ally_ref.movement_component.apply_separation(delta)
			return
		else:
			print("[DEBUG] Ally ", ally_ref.name, " arrived at patrol point (within 25.0 units), starting patrol.")
			moving_to_patrol_point = false
			ally_ref.velocity.x = 0
			ally_ref.velocity.z = 0
	# Engage enemy if found
	enemy_target = ally_ref.combat_component.find_nearest_enemy()
	if enemy_target and ally_ref.global_position.distance_to(enemy_target.global_position) < ally_ref.combat_component.detection_range:
		print("[DEBUG] Ally ", ally_ref.name, " found enemy while patrolling, switching to ATTACKING")
		current_state = State.ATTACKING
		return
	# Wander around patrol point
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		var angle = randf() * TAU
		var dist = randf() * patrol_radius
		var offset = Vector3(cos(angle), 0, sin(angle)) * dist
		var target = patrol_point + offset
		print("[DEBUG] Ally ", ally_ref.name, " patrolling to ", target)
		ally_ref.movement_component.move_towards_target(target, delta)
		patrol_wait_time = 0.5 + randf() * 1.5
		patrol_timer = patrol_wait_time
	else:
		ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, ally_ref.speed * 2 * delta)
		ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, ally_ref.speed * 2 * delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_exploring(delta: float):
	# Personality-driven exploration
	if personality and randf() < personality.curiosity * 0.05:
		var explore_angle = randf() * TAU
		var explore_dist = lerp(2.0, 6.0, personality.curiosity)
		var offset = Vector3(cos(explore_angle), 0, sin(explore_angle)) * explore_dist
		var explore_target = ally_ref.global_position + offset
		ally_ref.movement_component.move_with_navigation(explore_target)
		ally_ref.movement_component.apply_separation(delta)

func _handle_positioning(delta: float):
	# Smart formation positioning (stub, expand as needed)
	if player_target and personality:
		var formation_offset = Vector3(lerp(-2,2,personality.loyalty), 0, lerp(-2,2,personality.boldness))
		var pos_target = player_target.global_position + formation_offset
		ally_ref.movement_component.move_with_navigation(pos_target)
		ally_ref.movement_component.apply_separation(delta)

func _handle_waiting(_delta: float):
	# Idle with personality-based quirks
	if personality and randf() < 0.01 + personality.caution * 0.05:
		# Play idle animation or look around
		pass

func _handle_investigating(delta: float):
	# Investigate points of interest
	if personality and randf() < personality.curiosity * 0.1:
		# Move to a random nearby point
		var angle = randf() * TAU
		var dist = lerp(1.0, 4.0, personality.curiosity)
		var offset = Vector3(cos(angle), 0, sin(angle)) * dist
		var target = ally_ref.global_position + offset
		ally_ref.movement_component.move_with_navigation(target)
		ally_ref.movement_component.apply_separation(delta)

func command_move_to_position(position: Vector3):
	ally_ref.movement_component.move_towards_target(position, 0.1)

func get_mode_description() -> String:
	match mode:
		1:
			return "ATTACK"
		2:
			return "PASSIVE"
		_:
			return "UNKNOWN"
