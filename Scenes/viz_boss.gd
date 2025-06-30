# boss_debug_visualizer.gd - Add this to a Node3D in your scene to visualize boss behavior
extends Node3D

@export var show_boss_info: bool = true
@export var show_wall_detection: bool = true
@export var show_movement_path: bool = true

var boss: CharacterBody3D
var player: CharacterBody3D
var label_3d: Label3D

func _ready():
	_setup_debug_label()
	call_deferred("_find_references")

func _setup_debug_label():
	"""Create floating debug label"""
	label_3d = Label3D.new()
	label_3d.text = "Boss Debug Info"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 16
	add_child(label_3d)

func _find_references():
	boss = get_tree().get_first_node_in_group("bosses")
	player = get_tree().get_first_node_in_group("player")
	
	if boss:
		# Position debug label above boss
		global_position = boss.global_position + Vector3(0, 4, 0)
	else:
		print("🔍 DEBUG: No boss found in scene")

func _process(_delta):
	if not boss or not is_instance_valid(boss):
		_find_references()
		return
	
	# Update label position
	global_position = boss.global_position + Vector3(0, 4, 0)
	
	# Update debug text
	if show_boss_info:
		_update_debug_text()

func _update_debug_text():
	if not label_3d or not boss:
		return
	
	var state_names = ["SPAWNING", "POSITIONING", "IDLE", "CHARGING", "DYING"]
	var current_state_name = state_names[boss.current_state] if boss.current_state < state_names.size() else "UNKNOWN"
	
	var debug_text = "BOSS DEBUG\n"
	debug_text += "State: " + current_state_name + "\n"
	debug_text += "Health: " + str(boss.health) + "/" + str(boss.max_health) + "\n"
	debug_text += "On Floor: " + str(boss.is_on_floor()) + "\n"
	debug_text += "Velocity: " + str(boss.velocity.length()).pad_decimals(1) + "\n"
	
	if player:
		var distance = boss.global_position.distance_to(player.global_position)
		debug_text += "Distance to Player: " + str(distance).pad_decimals(1) + "\n"
	
	# Check for walls nearby
	if show_wall_detection:
		var walls_nearby = _count_walls_nearby()
		debug_text += "Walls Nearby: " + str(walls_nearby) + "\n"
	
	label_3d.text = debug_text

func _count_walls_nearby() -> int:
	if not boss:
		return 0
	
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = boss.global_position
	query.collision_mask = 1 << 1  # Wall layer
	
	var results = space_state.intersect_shape(query)
	
	var wall_count = 0
	for result in results:
		var obj = result.collider
		if _is_likely_wall(obj):
			wall_count += 1
	
	return wall_count

func _is_likely_wall(obj: Node) -> bool:
	if not obj:
		return false
	
	var name_lower = obj.name.to_lower()
	return (
		name_lower.contains("wall") or
		obj.is_in_group("walls") or
		obj.is_in_group("wall") or
		(obj is StaticBody3D and obj.collision_layer & (1 << 1))
	)

func _draw():
	# Visual debugging in 3D space
	if not show_movement_path or not boss or not player:
		return
	
	# This would require a custom draw method or debug shapes
	# For now, we'll use the console output from the boss script

# This script was removed as part of project cleanup (debug/test/print code, unused systems, and redundant comments).
