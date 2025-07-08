# boss_test.gd - Add this to a Node in your scene to test boss wall breaking
# This script will help you verify the boss fixes are working properly
extends Node

@export var auto_test: bool = false
@export var test_interval: float = 5.0

var boss: CharacterBody3D
var terrain: Node
var test_timer: float = 0.0

func _ready():
	print("🧪 BOSS TEST: Test script loaded")
	call_deferred("_find_references")

func _find_references():
	boss = get_tree().get_first_node_in_group("bosses")
	terrain = get_tree().get_first_node_in_group("terrain")
	
	if boss:
		print("✅ BOSS TEST: Found boss at position: ", boss.global_position)
	else:
		print("❌ BOSS TEST: No boss found")
	
	if terrain:
		print("✅ BOSS TEST: Found terrain generator")
	else:
		print("❌ BOSS TEST: No terrain found")

func _process(delta):
	if auto_test:
		test_timer += delta
		if test_timer >= test_interval:
			test_timer = 0.0
			_run_automatic_test()

func _run_automatic_test():
	"""Run automatic tests to verify boss functionality"""
	print("\n🧪 BOSS TEST: Running automatic test...")
	
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
	
	print("🧪 BOSS TEST: Automatic test complete\n")

func _test_boss_state():
	"""Test boss state and basic functionality"""
	print("📋 Testing boss state...")
	
	if not boss:
		print("❌ Boss not found")
		return
	
	print("✅ Boss health: ", boss.health, "/", boss.max_health)
	print("✅ Boss state: ", boss.current_state)
	print("✅ Boss on floor: ", boss.is_on_floor())
	print("✅ Boss velocity: ", boss.velocity.length())

func _test_wall_detection():
	"""Test wall detection around boss"""
	print("🧱 Testing wall detection...")
	
	if not boss:
		print("❌ Boss not found")
		return
	
	var space_state = get_viewport().get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = boss.global_position
	query.collision_mask = 1 << 1  # Wall layer
	
	var results = space_state.intersect_shape(query)
	
	print("✅ Objects detected near boss: ", results.size())
	
	var wall_count = 0
	for result in results:
		var obj = result.collider
		if obj and boss._is_wall(obj):
			wall_count += 1
			print("  - Wall found: ", obj.name, " at ", obj.global_position)
	
	print("✅ Walls detected: ", wall_count)

func _test_physics_layers():
	"""Test physics layer configuration"""
	print("⚙️  Testing physics layers...")
	
	if not boss:
		print("❌ Boss not found")
		return
	
	print("✅ Boss collision layer: ", boss.collision_layer)
	print("✅ Boss collision mask: ", boss.collision_mask)
	
	# Check if boss is on the right layer
	var expected_layer = 1 << 2  # Layer 3 (bit 2)
	if boss.collision_layer == expected_layer:
		print("✅ Boss collision layer correct")
	else:
		print("⚠️  Boss collision layer incorrect. Expected: ", expected_layer, " Got: ", boss.collision_layer)
	
	# Check if boss can detect walls
	var _expected_mask = (1 << 0) | (1 << 1) | (1 << 2)  # Layers 1, 2, 3
	if boss.collision_mask & (1 << 1):  # Can detect wall layer
		print("✅ Boss can detect walls")
	else:
		print("⚠️  Boss cannot detect walls. Mask: ", boss.collision_mask)

func _test_wall_breaking():
	"""Test wall breaking functionality"""
	print("💥 Testing wall breaking...")
	
	if not boss:
		print("❌ Boss not found")
		return
	
	print("🔨 Triggering wall break test...")
	boss._force_break_nearby_walls()
	
	# Wait a frame and check again
	await get_tree().process_frame
	
	print("✅ Wall breaking test complete")

func _input(event):
	"""Manual testing controls"""
	if event.is_action_pressed("ui_accept"):  # Space key
		print("🧪 BOSS TEST: Running manual test (Space pressed)")
		_run_automatic_test()
	
	elif event.is_action_pressed("ui_select"):  # Enter key
		print("🔨 BOSS TEST: Manual wall break (Enter pressed)")
		if boss:
			boss._force_break_nearby_walls()
	
	elif event.is_action_pressed("ui_cancel"):  # Escape key
		print("📍 BOSS TEST: Boss position info (Escape pressed)")
		if boss:
			print("Boss position: ", boss.global_position)
			print("Boss state: ", boss.current_state)
			print("Boss velocity: ", boss.velocity)
