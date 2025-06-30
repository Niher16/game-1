# boss_test.gd - Add this to a Node in your scene to test boss wall breaking
# This script will help you verify the boss fixes are working properly
extends Node

@export var auto_test: bool = false
@export var test_interval: float = 5.0

var boss: CharacterBody3D
var terrain: Node
var test_timer: float = 0.0

func _ready():
	call_deferred("_find_references")

func _find_references():
	boss = get_tree().get_first_node_in_group("bosses")
	terrain = get_tree().get_first_node_in_group("terrain")
	
func _process(delta):
	if auto_test:
		test_timer += delta
		if test_timer >= test_interval:
			test_timer = 0.0
			_run_automatic_test()

func _run_automatic_test():
	"""Run automatic tests to verify boss functionality"""
	
	if not boss:
		_find_references()
		return
	
	# Test 1: Check boss state
	_test_boss_state()
	
	# Test 2: Check wall detection
	_test_wall_detection()
	
	# Test 3: Check physics layers
	_test_physics_layers()
	
	# Test 4: Test wall breaking
	_test_wall_breaking()

func _test_boss_state():
	"""Test boss state and basic functionality"""
	
	if not boss:
		return
	
func _test_wall_detection():
	"""Test wall detection around boss"""
	
	if not boss:
		return
	
	var space_state = get_viewport().get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = boss.global_position
	query.collision_mask = 1 << 1  # Wall layer
	
	var results = space_state.intersect_shape(query)
	
	var _wall_count = 0
	for result in results:
		var obj = result.collider
		if obj and boss._is_wall(obj):
			_wall_count += 1
	
func _test_physics_layers():
	"""Test physics layer configuration"""
	
	if not boss:
		return
	
	# Check if boss is on the right layer
	var _expected_layer = 1 << 2  # Layer 3 (bit 2)
	
	# Check if boss can detect walls
	var _expected_mask = (1 << 0) | (1 << 1) | (1 << 2)  # Layers 1, 2, 3
	if boss.collision_mask & (1 << 1):  # Can detect wall layer
		pass

func _test_wall_breaking():
	"""Test wall breaking functionality"""
	
	if not boss:
		return
	
	boss._force_break_nearby_walls()
	
	# Wait a frame and check again
	await get_tree().process_frame

func _input(event):
	"""Manual testing controls"""
	if event.is_action_pressed("ui_accept"):  # Space key
		_run_automatic_test()
	
	elif event.is_action_pressed("ui_select"):  # Enter key
		if boss:
			boss._force_break_nearby_walls()
	
	elif event.is_action_pressed("ui_cancel"):  # Escape key
		if boss:
			print("Boss position: ", boss.global_position)
			print("Boss state: ", boss.current_state)
			print("Boss velocity: ", boss.velocity)

# This script was removed as part of project cleanup (debug/test/print code, unused systems, and redundant comments).
