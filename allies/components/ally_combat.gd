extends Node
class_name AllyCombat

signal attack_started
signal attack_hit(target: Node)

var ally_ref
var attack_damage: int
var attack_range := 2.5
var attack_cooldown := 1.2
var detection_range: float
var attack_timer := 0.0
var is_attacking := false
var pending_damage_target: Node3D = null
var current_weapon: WeaponResource = null

func setup(ally, damage: int, detect_range: float):
	ally_ref = ally
	attack_damage = damage
	detection_range = detect_range

func _process(delta):
	if attack_timer > 0:
		attack_timer -= delta

func can_attack() -> bool:
	return attack_timer <= 0 and not is_attacking

func find_nearest_enemy() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var distance = ally_ref.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= detection_range:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func attack_target(target: Node3D):
	if not can_attack() or not target:
		return
	var distance = ally_ref.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return
	is_attacking = true
	attack_timer = attack_cooldown
	attack_started.emit()
	# CRITICAL FIX: Validate ally before calling animation
	if ally_ref and ally_ref.is_inside_tree() and ally_ref.has_method("play_weapon_attack_animation"):
		ally_ref.play_weapon_attack_animation()
	else:
		push_warning("Cannot play ally animation - ally invalid or not in tree")
	if current_weapon and current_weapon.weapon_type == WeaponResource.WeaponType.BOW:
		_spawn_ally_arrow(target)
		pending_damage_target = null
		_setup_attack_finish_timer(0.4)
	else:
		# For melee weapons, set up damage delivery
		pending_damage_target = target
		_setup_damage_delivery_timer(0.2)
		_setup_attack_finish_timer(0.6)

# CRITICAL FIX: Use Timer nodes instead of lambda captures
func _setup_attack_finish_timer(delay: float):
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		is_attacking = false
		timer.queue_free()
	)
	timer.start()

func _setup_damage_delivery_timer(delay: float):
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		_execute_pending_damage()
		timer.queue_free()
	)
	timer.start()

# CRITICAL FIX: Safe arrow spawning and orientation
func _spawn_ally_arrow(target: Node3D):
	# Safe position calculation to avoid !is_inside_tree() error
	var start_pos: Vector3
	if ally_ref.right_hand_anchor and ally_ref.right_hand_anchor.is_inside_tree():
		start_pos = ally_ref.right_hand_anchor.global_position
	elif ally_ref.is_inside_tree():
		start_pos = ally_ref.global_position + Vector3(0.4, 0.5, 0)
	else:
		push_error("Ally not in scene tree when spawning arrow!")
		return
	# Spawn a simple arrow mesh and move it toward the target
	var arrow = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.02
	cylinder.bottom_radius = 0.02
	cylinder.height = 0.6
	arrow.mesh = cylinder
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.25, 0.1)
	material.roughness = 0.8
	arrow.material_override = material
	arrow.name = "AllyArrow"
	# Arrow tip
	var tip = MeshInstance3D.new()
	var tip_mesh = CylinderMesh.new()
	tip_mesh.top_radius = 0.005
	tip_mesh.bottom_radius = 0.02
	tip_mesh.height = 0.1
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.35, 0)
	var tip_material = StandardMaterial3D.new()
	tip_material.albedo_color = Color(0.7, 0.7, 0.8)
	tip_material.metallic = 0.9
	tip.material_override = tip_material
	arrow.add_child(tip)
	# Fletching
	var fletching = MeshInstance3D.new()
	var fletch_mesh = BoxMesh.new()
	fletch_mesh.size = Vector3(0.08, 0.02, 0.1)
	fletching.mesh = fletch_mesh
	fletching.position = Vector3(0, -0.25, 0)
	var fletch_material = StandardMaterial3D.new()
	fletch_material.albedo_color = Color(0.9, 0.8, 0.7)
	fletch_material.roughness = 0.9
	fletching.material_override = fletch_material
	arrow.add_child(fletching)
	# Set initial position (local, not global) before adding to tree
	arrow.position = start_pos
	# Add to scene - ensure we have valid parent
	var scene_root = ally_ref.get_tree().current_scene
	if scene_root:
		scene_root.add_child(arrow)
	else:
		ally_ref.get_parent().add_child(arrow)
	# Now safe to use look_at and global transforms
	var target_point = target.global_position
	arrow.global_position = start_pos # Ensure correct global position
	if not start_pos.is_equal_approx(target_point):
		arrow.look_at(target_point, Vector3.UP)
	else:
		print("[ALLY ARROW DEBUG] Arrow start and target positions are the same. Skipping look_at.")
	# Removed rotate_object_local to prevent sideways arrows
	# Calculate movement
	var direction = (target.global_position - start_pos).normalized()
	var arrow_speed = 15.0
	var travel_time = start_pos.distance_to(target.global_position) / arrow_speed
	var tween = create_tween()
	tween.tween_property(arrow, "global_position", target.global_position, travel_time)
	# Use safer damage delivery without lambda captures
	_setup_arrow_damage_delivery(arrow, target, travel_time)
	# Auto cleanup
	get_tree().create_timer(travel_time + 1.0).timeout.connect(func():
		if is_instance_valid(arrow):
			arrow.queue_free()
	)
	# Debug: Print arrow spawn information
	print("[ALLY ARROW DEBUG] Spawning arrow:")
	print("  Start position: ", start_pos)
	print("  Target position: ", target.global_position)
	print("  Direction: ", direction)
	print("  Ally facing: ", -ally_ref.transform.basis.z if ally_ref else "unknown")

# CRITICAL FIX: Separate damage delivery to avoid lambda capture issues
func _setup_arrow_damage_delivery(arrow: MeshInstance3D, target: Node3D, delay: float):
	var damage_timer = Timer.new()
	damage_timer.wait_time = delay
	damage_timer.one_shot = true
	arrow.add_child(damage_timer)
	damage_timer.timeout.connect(func():
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(attack_damage)
			attack_hit.emit(target)
		damage_timer.queue_free()
	)
	damage_timer.start()

func _execute_pending_damage():
	if pending_damage_target and is_instance_valid(pending_damage_target):
		_deal_damage(pending_damage_target)
	pending_damage_target = null

func _deal_damage(target: Node3D):
	if not is_instance_valid(target):
		return
	var distance = ally_ref.global_position.distance_to(target.global_position)
	if distance > attack_range * 1.2:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		attack_hit.emit(target)

func equip_weapon(weapon_resource: WeaponResource) -> void:
	current_weapon = weapon_resource
	if current_weapon:
		attack_damage = current_weapon.attack_damage
		attack_range = current_weapon.attack_range
		attack_cooldown = current_weapon.attack_cooldown
	else:
		# fallback to ally base stats
		attack_damage = ally_ref.attack_damage
		attack_range = ally_ref.detection_range * 0.3
		attack_cooldown = 1.2
