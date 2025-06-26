# manual_boss_spawn.gd - Add this to a Node in your scene for testing
extends Node

@export var boss_scene: PackedScene
var player: CharacterBody3D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	print("🧪 MANUAL BOSS SPAWN: Press 'B' to spawn boss near player")

func _input(event):
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_B):
		_spawn_test_boss()

func _spawn_test_boss():
	if not player:
		print("❌ No player found")
		return
	
	# Create boss manually
	var boss = _create_boss_from_scratch()
	if not boss:
		print("❌ Failed to create boss")
		return
	
	# Add to scene
	get_tree().current_scene.add_child(boss)
	
	# Position near player
	var spawn_pos = player.global_position + Vector3(5, 3, 5)  # 5 units away, 3 units up
	boss.global_position = spawn_pos
	
	print("🤖 MANUAL BOSS: Spawned at ", spawn_pos)

func _create_boss_from_scratch() -> CharacterBody3D:
	"""Create a boss manually for testing"""
	var boss = CharacterBody3D.new()
	boss.name = "DemolitionKingBoss"
	
	# Add MeshInstance3D for visuals
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	boss.add_child(mesh_instance)
	
	# Create a red box mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2, 3, 2)
	mesh_instance.mesh = box_mesh
	
	# Make it red so we can see it
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED * 0.3
	mesh_instance.material_override = material
	
	# Add collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	boss.add_child(collision_shape)
	
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 3, 2)
	collision_shape.shape = shape
	
	# Attach the boss script
	var boss_script = load("res://Bosses/DemolitionKingBoss.gd")
	boss.set_script(boss_script)
	
	# Set up groups and physics
	boss.add_to_group("bosses")
	boss.add_to_group("enemies")
	
	return boss
